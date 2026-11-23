import 'package:drift/drift.dart';

import 'order_backfill.dart';
import 'schema.dart';
import 'search_index.dart';

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
///   v9 (dogfooding F3) tasks.notes (ADR-0051)
///   v10 (P04 T1) workspace_settings (takes over profiles.manual_results),
///                sync_base, sync_state; outbox index by status (ADR-0053)
///   v11 (P04 T3) sync_reviews: Changes to review; sync_base.server_id (ADR-0056)
///   v12 (P04 T6) the outbox key gains the kind (ADR-0058)
///   v13 (P04b T8) shared spaces: workspaces name and rules, space_members,
///                tasks.assignee_id, changed_by on every record,
///                sync_base.workspace_id (ADR-0060)
///   v14 (P04b T12) workspace_settings.name, sync_base keyed by workspace,
///                sync_parked, workspaces.left_at/left_keep (ADR-0064)
///   v15 (P04b T13) member_cards: members' names in a space (ADR-0065)
///   v16 (P05a T2) documents, document_revisions, document_links; search by
///                the exact spelling (tasks_fts rebuilt, documents_fts, NFC by
///                search_pending), document_link_index (ADR-0067)
///   v17 (P05b T2) the text of this device's PDFs for search: pdf_text_fts,
///                pdf_text_state, document_file_index; device-only (ADR-0077)
@DriftDatabase(
  tables: [
    Profiles, Workspaces, TaskLists, Tasks, AuditLog, Outbox, EventLog,
    OpDedupe, RestoreSnapshots,
    Calendars, Events, Schedules, OccurrenceExceptions, OccurrenceCompletions,
    Reminders,
    FocusSessions, ExecutionRecords, Measurements, PeriodResults, Goals,
    Milestones, GoalLinks,
    WorkspaceSettings, SyncBase, SyncState, SyncReviews,
    SpaceMembers, SyncParked, MemberCards,
    Documents, DocumentRevisions, DocumentLinks, SearchPending, DocumentLinkIndex,
    DocumentFileIndex, PdfTextState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The schema this build writes (and the newest export it accepts).
  static const currentSchemaVersion = 17;

  /// The last schema that changed a synced record's shape: what a sealed
  /// record says it is (ADR-0056). v12 changed only the local outbox. v13
  /// (ADR-0060) adds `changedBy` to every record and `assigneeId` to tasks;
  /// a pulled record of v11 or v12 is read with both null. v14 (ADR-0064)
  /// adds a space's `name` to its settings and "moved away" changes. v15
  /// (ADR-0065) adds the member card kind. v16 (ADR-0067) adds documents,
  /// their revisions and their links. v17 (ADR-0077) changes only device
  /// tables (the text of PDFs).
  static const recordSchemaVersion = 16;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createSearchIndex(this);
          await createPdfTextIndex(this);
          await _createDocumentIndexes();
          await _createPlanningIndexes();
          await _createExecutionIndexes();
          await _createSyncIndexes();
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
          if (from < 9) await m.addColumn(tasks, tasks.notes);
          if (from < 10) {
            for (final TableInfo t in [workspaceSettings, syncBase, syncState]) {
              await m.createTable(t);
            }
            await _createSyncIndexes();
            await _moveManualResults();
          }
          if (from < 11) {
            await m.createTable(syncReviews);
            if (from == 10) await m.addColumn(syncBase, syncBase.serverId);
          }
          if (from < 12) {
            // P04 T6 (ADR-0058): the outbox key gains the kind; the rows are
            // copied as they are.
            await m.alterTable(TableMigration(outbox));
            await customStatement('DROP INDEX IF EXISTS outbox_status');
            await _createSyncIndexes();
          }
          if (from < 13) {
            // P04b T8 (ADR-0060): shared spaces in the store.
            for (final c in [workspaces.name, workspaces.leaveRule, workspaces.exportRule,
                workspaces.inviteDefault, workspaces.rulesChangedAt, workspaces.rulesSeenAt]) {
              await m.addColumn(workspaces, c);
            }
            await m.createTable(spaceMembers);
            await m.addColumn(tasks, tasks.assigneeId);
            // changed_by on every record table that existed before this
            // upgrade (the ones made by an earlier step above are already whole).
            final madeIn = <TableInfo, int>{
              taskLists: 1, tasks: 1,
              calendars: 4, events: 4, schedules: 4, occurrenceExceptions: 4, occurrenceCompletions: 4, reminders: 4,
              focusSessions: 5, executionRecords: 5, measurements: 5, periodResults: 5, goals: 5, milestones: 5,
              goalLinks: 5, workspaceSettings: 10,
            };
            for (final e in madeIn.entries) {
              if (from >= e.value) {
                await m.addColumn(e.key, (e.key.columnsByName['changed_by'] as GeneratedColumn));
              }
            }
            if (from >= 10) {
              await m.addColumn(syncBase, syncBase.workspaceId);
              // Until now only one workspace could be synced: the one in
              // sync_state, else the profile's.
              await customStatement(
                  'UPDATE sync_base SET workspace_id = COALESCE((SELECT workspace_id FROM sync_state LIMIT 1), '
                  '(SELECT active_workspace_id FROM profiles LIMIT 1), \'\')');
            }
          }
          if (from < 14) {
            // P04b T12 (ADR-0064): sharing commands.
            if (from >= 10) {
              await m.addColumn(workspaceSettings, workspaceSettings.name);
              // The last synced copies are kept per workspace (a new key).
              await m.alterTable(TableMigration(syncBase));
            }
            await m.addColumn(workspaces, workspaces.leftAt);
            await m.addColumn(workspaces, workspaces.leftKeep);
            await m.createTable(syncParked);
          }
          // P04b T13 (ADR-0065): members' names, a record of each space.
          if (from < 15) await m.createTable(memberCards);
          if (from < 16) {
            // P05a T2 (ADR-0067): documents; search by the exact spelling.
            for (final TableInfo t in [documents, documentRevisions, documentLinks, searchPending, documentLinkIndex]) {
              await m.createTable(t);
            }
            await _createDocumentIndexes();
            for (final t in ['tasks_ai', 'tasks_ad', 'tasks_au']) {
              await customStatement('DROP TRIGGER IF EXISTS $t');
            }
            await customStatement('DROP TABLE IF EXISTS tasks_fts');
            await createSearchIndex(this);
            await markAllForSearch(this);
          }
          if (from < 17) {
            // P05b T2 (ADR-0077): the text of this device's PDFs. The documents
            // are noted again, so their files are listed by the next catch-up.
            for (final TableInfo t in [documentFileIndex, pdfTextState]) {
              await m.createTable(t);
            }
            await createPdfTextIndex(this);
            if (from >= 16) await markAllForSearch(this);
          }
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

  /// Schema v10: the result policy moves from the profile to its workspace's
  /// settings, which sync (only 'tick' needs a row; no row is the default).
  Future<void> _moveManualResults() async {
    final now = DateTime.now().toUtc();
    for (final r in await customSelect(
        "SELECT id, active_workspace_id FROM profiles WHERE manual_results = 'tick'").get()) {
      final ws = r.read<String>('active_workspace_id');
      await into(workspaceSettings).insertOnConflictUpdate(WorkspaceSettingsCompanion.insert(
            id: ws,
            workspaceId: ws,
            ownerId: r.read<String>('id'),
            createdAt: now,
            updatedAt: now,
            manualResults: const Value('tick'),
          ));
    }
  }

  /// P04 T1: the push reads the pending outbox rows.
  Future<void> _createSyncIndexes() =>
      customStatement('CREATE INDEX outbox_status ON outbox (status, entity_type, entity_id)');

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

  /// P05a T2: the tree, the revisions of a document and its links.
  Future<void> _createDocumentIndexes() async {
    await customStatement('CREATE INDEX documents_parent ON documents (workspace_id, parent_id)');
    await customStatement('CREATE INDEX document_revisions_document ON document_revisions (document_id, document_version)');
    await customStatement('CREATE INDEX document_links_document ON document_links (document_id)');
    await customStatement('CREATE INDEX document_link_index_to ON document_link_index (to_document_id)');
  }

  /// Search over task titles (live ones) in a workspace, by the exact
  /// spelling (P05a C12, ADR-0067): what a person typed, not FTS5 syntax.
  Future<List<String>> searchTaskIds(String workspaceId, String typed) => searchTaskIdsIn(this, workspaceId, typed);

  /// The live documents of a workspace matching what was typed (title or text).
  Future<List<String>> searchDocumentIds(String workspaceId, String typed) => searchDocumentIdsIn(this, workspaceId, typed);

  /// The live documents of a workspace whose text links to [documentId] (C6).
  Future<List<String>> backlinkIds(String workspaceId, String documentId) => backlinkIdsIn(this, workspaceId, documentId);
}
