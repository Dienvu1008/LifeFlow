import 'package:drift/drift.dart';

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
@DriftDatabase(
  tables: [
    Profiles, Workspaces, TaskLists, Tasks, AuditLog, Outbox, EventLog,
    OpDedupe, RestoreSnapshots,
    Calendars, Events, Schedules, OccurrenceExceptions, OccurrenceCompletions,
    Reminders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The schema this build writes (and the newest export it accepts).
  static const currentSchemaVersion = 4;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createTaskTitleFts();
          await _createPlanningIndexes();
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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
