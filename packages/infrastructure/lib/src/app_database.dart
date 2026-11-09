import 'package:drift/drift.dart';

import 'schema.dart';

part 'app_database.g.dart';

/// The local Drift database (P01). Executor is injected so the same class runs
/// native (plain or encrypted, T5), in-memory (tests), or web later.
/// Migrations are guided (VS-04), additive only; no destructive migrations.
///   v1 (P01 T1)  initial schema
///   v2 (P01 T6c) profiles.signed_out — sign-out locks the profile, binding kept
///   v3 (P01 T7b) restore_snapshots — undo of the last restore (ADR-0025)
@DriftDatabase(
  tables: [
    Profiles, Workspaces, TaskLists, Tasks, AuditLog, Outbox, EventLog,
    OpDedupe, RestoreSnapshots,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createTaskTitleFts();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(profiles, profiles.signedOut);
          if (from < 3) await m.createTable(restoreSnapshots);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
