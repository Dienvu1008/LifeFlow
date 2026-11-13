import 'package:drift/drift.dart';

import 'order_backfill.dart';
import 'schema.dart';

part 'app_database.g.dart';

/// The local Drift database (P01). Executor is injected so the same class runs
/// native (plain or encrypted, T5), in-memory (tests), or web later.
/// Migrations are guided (VS-04), additive only; no destructive migrations.
///   v1 (P01 T1)  initial schema
///   v2 (P01 T6c) profiles.signed_out — sign-out locks the profile, binding kept
///   v3 (P01 T7b) restore_snapshots — undo of the last restore (ADR-0025)
///   v4 (P02 T3)  calendars, events, schedules, occurrence_exceptions,
///                occurrence_completions, reminders (ADR-0029)
///   v5 (P03 T2)  focus_sessions, execution_records, measurements,
///                period_results, goals, milestones, goal_links;
///                tasks.target_aggregation, tasks.is_habit (ADR-0037)
///   v6 (P03 T4)  tasks.tracked_since (ADR-0039)
///   v7 (P03 UX U2) color_index and order_key on task_lists, tasks and events;
///                events.list_id; order keys backfilled (ADR-0046)
///   v8 (P03 UX U6) profiles.manual_results (ADR-0050)
@DriftDatabase(
  tables: [
    Profiles, Workspaces, TaskLists, Tasks, AuditLog, Outbox, EventLog,
    OpDedupe, RestoreSnapshots,
    Calendars, Events, Schedules, OccurrenceExceptions, OccurrenceCompletions,
    Reminders,
    FocusSessions, ExecutionRecords, Measurements, PeriodResults, Goals,
    Milestones, GoalLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The schema this build writes (and the newest export it accepts).
  static const currentSchemaVersion = 8;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createTaskTitleFts();
          await _createPlanningIndexes();
          await _createExecutionIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(profiles, profiles.signedOut);
          if (from < 3) await m.createTable(restoreSnapshots);
          if (from < 4) {
            for (final TableInfo t in [calendars, events, schedules,
                occurrenceExceptions, occurrenceCompletions, reminders]) {
              await m.createTable(t);
            }
            await _createPlanningIndexes();
          }
          if (from < 5) {
            await m.addColumn(tasks, tasks.targetAggregation);
            await m.addColumn(tasks, tasks.isHabit);
            for (final TableInfo t in [focusSessions, executionRecords, measurements,
                periodResults, goals, milestones, goalLinks]) {
              await m.createTable(t);
            }
            await _createExecutionIndexes();
          }
          if (from < 6) await m.addColumn(tasks, tasks.trackedSince);
          if (from < 7) {
            // P03 UX U2 (ADR-0046): lists, colours and order keys.
            await m.addColumn(taskLists, taskLists.colorIndex);
            await m.addColumn(taskLists, taskLists.orderKey);
            await m.addColumn(tasks, tasks.colorIndex);
            await m.addColumn(tasks, tasks.orderKey);
            if (from >= 4) {
              // Before v4 the events table was just created, already whole.
              await m.addColumn(events, events.listId);
              await m.addColumn(events, events.colorIndex);
              await m.addColumn(events, events.orderKey);
            }
            await _backfillOrderKeys();
          }
          if (from < 8) await m.addColumn(profiles, profiles.manualResults);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Schema v7: every existing list, task and event gets an order key that
  /// keeps the order shown so far (creation, then rowid). Trashed rows too,
  /// so a restore puts them back in place.
  Future<void> _backfillOrderKeys() async {
    final rows = <UnkeyedRow>[];
    for (final (kind, sql) in const [
      ('taskList', 'SELECT id, workspace_id, created_at, NULL AS parent, NULL AS list FROM task_lists ORDER BY rowid'),
      ('task', 'SELECT id, workspace_id, created_at, parent_task_id AS parent, task_list_id AS list FROM tasks ORDER BY rowid'),
      ('event', 'SELECT id, workspace_id, created_at, NULL AS parent, list_id AS list FROM events ORDER BY rowid'),
    ]) {
      for (final r in await customSelect(sql).get()) {
        rows.add(UnkeyedRow(
          kind: kind,
          id: r.read<String>('id'),
          workspaceId: r.read<String>('workspace_id'),
          createdAt: r.read<int>('created_at'),
          parentTaskId: r.readNullable<String>('parent'),
          listId: r.readNullable<String>('list'),
        ));
      }
    }
    final keys = backfillOrderKeys(rows);
    for (final r in rows) {
      final table = switch (r.kind) { 'taskList' => 'task_lists', 'task' => 'tasks', _ => 'events' };
      await customStatement('UPDATE $table SET order_key = ? WHERE id = ?', [keys[r.id], r.id]);
    }
  }

  /// Range pre-filter for window queries (only rows whose series can touch
  /// the window are expanded), and lookups by subject.
  Future<void> _createPlanningIndexes() async {
    await customStatement(
        'CREATE INDEX schedules_range ON schedules (workspace_id, first_date, last_date)');
    await customStatement(
        'CREATE INDEX exceptions_subject ON occurrence_exceptions (subject_type, subject_id)');
    await customStatement(
        'CREATE INDEX completions_task ON occurrence_completions (task_id)');
    await customStatement(
        'CREATE INDEX reminders_subject ON reminders (subject_type, subject_id)');
  }

  /// P03: lookups by task, by period, by state and by goal.
  Future<void> _createExecutionIndexes() async {
    await customStatement('CREATE INDEX measurements_task_date ON measurements (task_id, local_date)');
    await customStatement('CREATE INDEX focus_sessions_state ON focus_sessions (state)');
    await customStatement('CREATE INDEX execution_records_task ON execution_records (task_id)');
    await customStatement('CREATE INDEX period_results_task ON period_results (task_id, period_key)');
    await customStatement('CREATE INDEX milestones_goal ON milestones (goal_id)');
    await customStatement('CREATE INDEX goal_links_goal ON goal_links (goal_id)');
    await customStatement('CREATE INDEX goal_links_item ON goal_links (item_type, item_id)');
  }

  /// FTS5 index over task titles (external-content). Kept in sync by triggers.
  Future<void> _createTaskTitleFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE tasks_fts USING fts5"
      "(title, content='tasks', content_rowid='rowid')",
    );
    await customStatement(
      "CREATE TRIGGER tasks_ai AFTER INSERT ON tasks BEGIN "
      "INSERT INTO tasks_fts(rowid, title) VALUES (new.rowid, new.title); END",
    );
    await customStatement(
      "CREATE TRIGGER tasks_ad AFTER DELETE ON tasks BEGIN "
      "INSERT INTO tasks_fts(tasks_fts, rowid, title) VALUES('delete', old.rowid, old.title); END",
    );
    await customStatement(
      "CREATE TRIGGER tasks_au AFTER UPDATE ON tasks BEGIN "
      "INSERT INTO tasks_fts(tasks_fts, rowid, title) VALUES('delete', old.rowid, old.title); "
      "INSERT INTO tasks_fts(rowid, title) VALUES (new.rowid, new.title); END",
    );
  }

  /// Full-text search over task titles (active, non-deleted) in a workspace.
  Future<List<String>> searchTaskIds(String workspaceId, String query) async {
    final rows = await customSelect(
      "SELECT t.id AS id FROM tasks_fts f "
      "JOIN tasks t ON t.rowid = f.rowid "
      "WHERE f.title MATCH ? AND t.workspace_id = ? AND t.deleted_at IS NULL "
      "ORDER BY rank",
      variables: [Variable(query), Variable(workspaceId)],
      readsFrom: {tasks},
    ).get();
    return rows.map((r) => r.data['id'] as String).toList();
  }
}
