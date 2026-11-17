// Shared test harness for per-profile stores (SR-03, ADR-0023).
import 'dart:io';

import 'package:application/application.dart';
import 'package:infrastructure/infrastructure.dart';

/// In-memory stand-in for platform secure storage, one slot per key name.
class MemoryKeys {
  final values = <String, String>{};

  /// The next delete throws (secure storage failure).
  bool failNextDelete = false;
  DatabaseKeyStore call(String name) => _Slot(this, name);
}

class _Slot implements DatabaseKeyStore {
  _Slot(this._keys, this._name);
  final MemoryKeys _keys;
  final String _name;
  @override
  Future<String?> read() async => _keys.values[_name];
  @override
  Future<void> write(String key) async => _keys.values[_name] = key;
  @override
  Future<void> delete() async {
    if (_keys.failNextDelete) {
      _keys.failNextDelete = false;
      throw StateError('secure storage failed');
    }
    _keys.values.remove(_name);
  }
}

Future<ProfileDirectory> openDirectory(Directory base, MemoryKeys keys,
        {AtRestPolicy policy = AtRestPolicy.encrypt}) =>
    ProfileDirectory.open(
        baseDir: base, policy: policy, keysFor: keys.call, background: false);

/// Plays the app shell: keeps the active profile's store open and swaps it
/// when [activate] is called, like the real composition root.
class TestHost implements ProfileHost {
  TestHost(this.directory);
  final ProfileDirectory directory;
  OpenedStore? _current;
  String? currentId;
  final activations = <String>[];

  /// Whether the last activation asked for the profile chooser.
  bool lastShowProfiles = false;

  AppDatabase get db => _current!.db;

  Future<void> openActive() async {
    final id = (await directory.active())!.id;
    _current = await directory.openProfile(id);
    currentId = id;
  }

  @override
  Future<void> activate(String profileId, {bool showProfiles = false}) async {
    activations.add(profileId);
    lastShowProfiles = showProfiles;
    await _current?.db.close();
    _current = await directory.openProfile(profileId);
    currentId = profileId;
  }

  Future<void> close() async {
    await _current?.db.close();
    _current = null;
  }
}

/// Services bound to the host's CURRENT store. Rebuild after a switch, as the
/// app does by rebuilding its provider scope.
class Services {
  Services(this.host, this.auth) {
    final db = host.db;
    final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    tasks = DriftTaskService(db, gw);
    queries = DriftTaskQueries(db);
    profiles = DirectoryProfileService(host.directory, host);
    accounts = DriftAccountService(
        db: db, gateway: gw, auth: auth, directory: host.directory, host: host);
  }
  final TestHost host;
  final AuthGateway auth;
  late final DriftTaskService tasks;
  late final DriftTaskQueries queries;
  late final DirectoryProfileService profiles;
  late final DriftAccountService accounts;

  Future<List<String>> titles() async =>
      (await queries.watchTasks().first).map((t) => t.title).toList();
}

/// Turns a current profile store back into what a build with schema [version]
/// wrote (for migration tests). Data in the tables that remain is kept.
Future<void> rewindProfileStore(AppDatabase db, int version) async {
  if (version < 15) {
    // P04b T13 (ADR-0065): no members' names.
    await db.customStatement('DROP TABLE member_cards');
  }
  if (version < 14) {
    // P04b T12 (ADR-0064): no space names, last synced copies keyed by
    // record only, nothing kept aside, nothing left of a left space.
    await db.customStatement('DROP TABLE sync_parked');
    for (final c in ['left_at', 'left_keep']) {
      await db.customStatement('ALTER TABLE workspaces DROP COLUMN $c');
    }
    await db.customStatement('ALTER TABLE workspace_settings DROP COLUMN name');
    final ddl = (await db.customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'sync_base'").getSingle())
        .read<String>('sql');
    final old = ddl.replaceFirst(
        RegExp(r'PRIMARY KEY\s*\(\s*"?workspace_id"?\s*,\s*"?kind"?\s*,\s*"?record_id"?\s*\)'), 'PRIMARY KEY (kind, record_id)');
    if (old == ddl) throw StateError('the v14 sync_base key was not found: $ddl');
    await db.customStatement('ALTER TABLE sync_base RENAME TO sync_base_v14');
    await db.customStatement(old);
    await db.customStatement('INSERT OR IGNORE INTO sync_base SELECT * FROM sync_base_v14');
    await db.customStatement('DROP TABLE sync_base_v14');
  }
  if (version < 13) {
    // P04b T8 (ADR-0060): no shared spaces, no changed_by, no assignee.
    await db.customStatement('DROP TABLE space_members');
    for (final c in ['name', 'leave_rule', 'export_rule', 'invite_default', 'rules_changed_at', 'rules_seen_at']) {
      await db.customStatement('ALTER TABLE workspaces DROP COLUMN $c');
    }
    await db.customStatement('ALTER TABLE tasks DROP COLUMN assignee_id');
    for (final k in recordKinds) {
      if (k.name == 'memberCard') continue; // v15, already gone
      await db.customStatement('ALTER TABLE ${k.tableName} DROP COLUMN changed_by');
    }
    await db.customStatement('ALTER TABLE sync_base DROP COLUMN workspace_id');
  }
  if (version < 12) {
    // The outbox key without the kind (v1-v11).
    final ddl = (await db.customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'outbox'").getSingle())
        .read<String>('sql');
    final old = ddl.replaceFirst(
        RegExp(r'PRIMARY KEY\s*\(\s*"?operation_id"?\s*,\s*"?entity_type"?\s*,\s*"?entity_id"?\s*\)'),
        'PRIMARY KEY (operation_id, entity_id)');
    if (old == ddl) throw StateError('the v12 outbox key was not found: $ddl');
    await db.customStatement('ALTER TABLE outbox RENAME TO outbox_v12');
    await db.customStatement(old);
    await db.customStatement('INSERT INTO outbox SELECT * FROM outbox_v12');
    await db.customStatement('DROP TABLE outbox_v12');
    await db.customStatement('CREATE INDEX outbox_status ON outbox (status, entity_type, entity_id)');
  }
  if (version < 11) {
    await db.customStatement('DROP TABLE sync_reviews');
    await db.customStatement('ALTER TABLE sync_base DROP COLUMN server_id');
  }
  if (version < 10) {
    for (final t in ['workspace_settings', 'sync_base', 'sync_state']) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('DROP INDEX outbox_status');
  }
  if (version < 9) await db.customStatement('ALTER TABLE tasks DROP COLUMN notes');
  if (version < 8) await db.customStatement('ALTER TABLE profiles DROP COLUMN manual_results');
  if (version < 7) {
    for (final (table, column) in const [
      ('task_lists', 'color_index'), ('task_lists', 'order_key'), ('tasks', 'color_index'),
      ('tasks', 'order_key'), ('events', 'list_id'), ('events', 'color_index'), ('events', 'order_key'),
    ]) {
      await db.customStatement('ALTER TABLE $table DROP COLUMN $column');
    }
  }
  if (version < 6) await db.customStatement('ALTER TABLE tasks DROP COLUMN tracked_since');
  if (version < 5) {
    for (final t in ['focus_sessions', 'execution_records', 'measurements', 'period_results',
        'goals', 'milestones', 'goal_links']) {
      await db.customStatement('DROP TABLE $t'); // drops its indexes too
    }
    await db.customStatement('ALTER TABLE tasks DROP COLUMN target_aggregation');
    await db.customStatement('ALTER TABLE tasks DROP COLUMN is_habit');
  }
  if (version < 4) {
    for (final t in ['calendars', 'events', 'schedules', 'occurrence_exceptions',
        'occurrence_completions', 'reminders']) {
      await db.customStatement('DROP TABLE $t'); // drops its indexes too
    }
  }
  if (version < 3) await db.customStatement('DROP TABLE restore_snapshots');
  if (version < 2) await db.customStatement('ALTER TABLE profiles DROP COLUMN signed_out');
  await db.customStatement('PRAGMA user_version = $version');
}
