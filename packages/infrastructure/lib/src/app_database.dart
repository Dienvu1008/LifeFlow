import 'package:drift/drift.dart';

import 'schema.dart';

part 'app_database.g.dart';

/// The local Drift database (P01). Executor is injected so the same class runs
/// native (plain or encrypted, T5), in-memory (tests), or web later.
/// Schema version 1. Migrations are guided (VS-04); no destructive migrations.
@DriftDatabase(
  tables: [Profiles, Workspaces, TaskLists, Tasks, AuditLog, Outbox, EventLog, OpDedupe],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createTaskTitleFts();
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

  /// Reports the active at-rest cipher, or null if the DB is plain (T5,
  /// LF-INV-SEC-011). On an encrypted SQLite3MultipleCiphers build `PRAGMA
  /// cipher` returns the cipher name; on a plain SQLite it returns no row / an
  /// empty value. Used by StorageSecurity.evaluate as the CipherProbe.
  Future<String?> activeCipher() async {
    try {
      final rows = await customSelect('PRAGMA cipher').get();
      if (rows.isEmpty) return null;
      final value = rows.first.data.values.first;
      final s = value?.toString() ?? '';
      return s.isEmpty ? null : s;
    } catch (_) {
      // Plain SQLite does not know this pragma; treat as not encrypted.
      return null;
    }
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
