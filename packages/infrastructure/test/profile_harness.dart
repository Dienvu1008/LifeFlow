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
