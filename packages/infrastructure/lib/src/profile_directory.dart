// P01 T6c (SR-03, ADR-0023): one database file and one key per LocalProfile,
// plus a small encrypted device registry that lists the profiles.
//
// Layout under the app-private support directory:
//   lifeflow.registry.sqlite        key: lifeflow.registry.key.v1
//   profiles/<profileId>.sqlite     key: lifeflow.db.key.<profileId>
//   lifeflow.sqlite.pre-sr03        the pre-SR-03 shared database, kept
//                                   (still encrypted, old key kept) after a
//                                   verified migration
//
// Cross-store writes (ADR-0023): a profile's own store is the source of truth
// for its data AND its binding; its audit/outbox/dedupe live there (atomic
// set, LF-INV-GOV-003, per store). The registry is an index plus the "active
// profile" pointer. Before changing a profile store the registry records an
// intent (`pending_sync`); after the store commits, the registry is updated
// and the intent cleared. An interrupted change is reconciled on next open.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'local_store.dart';
import 'profile_export.dart';
import 'profile_store.dart';
import 'registry_database.dart';

/// Supplies the secure-storage slot for a named key.
typedef KeyStoreFor = DatabaseKeyStore Function(String keyName);

/// A profile as listed in the device registry.
class ProfileEntry {
  const ProfileEntry({
    required this.id,
    required this.displayName,
    required this.isActive,
    required this.createdAt,
    this.accountId,
    this.provider,
    this.signedOut = false,
  });

  final String id;
  final String displayName;
  final bool isActive;
  final DateTime createdAt;
  final String? accountId;
  final String? provider;

  /// ADR-0024: the account signed out; the profile opens again only after
  /// that account signs in.
  final bool signedOut;

  bool get isBound => accountId != null;
  bool get isLocked => isBound && signedOut;
}

/// What the one-time migration of the pre-SR-03 shared database did.
class LegacyMigrationReport {
  const LegacyMigrationReport(
      {required this.profiles, required this.unmappedGovernanceRows});
  final int profiles;

  /// Governance rows (audit/outbox/event log) that could not be attributed to
  /// any profile's workspace. They stay in the kept backup file.
  final int unmappedGovernanceRows;
}

class ProfileDirectory {
  ProfileDirectory._(this.baseDir, this.policy, this._keysFor, this._registry,
      this._background);

  static const registryFileName = 'lifeflow.registry.sqlite';
  static const registryKeyName = 'lifeflow.registry.key.v1';
  static const legacyFileName = 'lifeflow.sqlite';
  static const legacyKeyName = 'lifeflow.db.key.v1';
  static const legacyBackupSuffix = '.pre-sr03';
  static String profileKeyName(String profileId) => 'lifeflow.db.key.$profileId';

  static const _metaPending = 'pending_sync';
  static const _metaPendingDelete = 'pending_delete';
  static const _metaLegacyMigrated = 'legacy_migrated';
  static const _metaLegacyUnmapped = 'legacy_unmapped_rows';

  final Directory baseDir;
  final AtRestPolicy policy;
  final KeyStoreFor _keysFor;
  final RegistryDatabase _registry;
  final bool _background;

  /// The migration report, when the pre-SR-03 database was migrated on this
  /// open. Null otherwise.
  LegacyMigrationReport? get lastMigration => _lastMigration;
  LegacyMigrationReport? _lastMigration;

  /// Opens the directory: registry, one-time migration of the shared database,
  /// recovery of an interrupted change, and first-launch guest creation
  /// (ADR-0008). Afterwards exactly one profile is active.
  static Future<ProfileDirectory> open({
    required Directory baseDir,
    required AtRestPolicy policy,
    required KeyStoreFor keysFor,
    bool background = true,
    String guestDisplayName = '',
  }) async {
    await Directory(_join(baseDir.path, 'profiles')).create(recursive: true);
    final registry = await openRegistryStore(
      file: File(_join(baseDir.path, registryFileName)),
      policy: policy,
      keys: keysFor(registryKeyName),
      background: background,
    );
    final dir = ProfileDirectory._(baseDir, policy, keysFor, registry, background);
    try {
      await dir._migrateLegacyIfNeeded();
      await dir._finishPendingDelete();
      await dir._recoverPending();
      final active = await dir.active();
      if (active == null || active.isLocked) {
        // First launch, or the app stopped right after a sign-out: never
        // open a locked profile; fall back to a guest (ADR-0008, ADR-0024).
        await dir.activateGuest(displayName: guestDisplayName);
      }
    } catch (_) {
      await registry.close();
      rethrow;
    }
    return dir;
  }

  File profileFile(String profileId) =>
      File(_join(baseDir.path, 'profiles', '$profileId.sqlite'));

  File get legacyFile => File(_join(baseDir.path, legacyFileName));
  File get legacyBackupFile =>
      File(_join(baseDir.path, '$legacyFileName$legacyBackupSuffix'));

  Future<List<ProfileEntry>> list() async {
    final rows = await (_registry.select(_registry.registryProfiles)
          ..orderBy([(p) => OrderingTerm(expression: p.createdAt)]))
        .get();
    return rows.map(_entry).toList();
  }

  Future<ProfileEntry?> active() async {
    final row = await (_registry.select(_registry.registryProfiles)
          ..where((p) => p.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  /// The profile bound to [accountId], if any (one account, one profile).
  Future<ProfileEntry?> findByAccount(String accountId) async {
    final row = await (_registry.select(_registry.registryProfiles)
          ..where((p) => p.accountId.equals(accountId))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  /// Activates a guest (unbound) profile, creating one if the device has none
  /// (ADR-0008: the app is always usable without an account). Returns it.
  Future<ProfileEntry> activateGuest({String displayName = ''}) async {
    final guest = (await list()).where((e) => !e.isBound).firstOrNull ??
        await createProfile(displayName: displayName);
    await setActive(guest.id);
    return (await _get(guest.id))!;
  }

  /// Makes [profileId] the active profile (device-level; not profile data).
  /// A locked (signed-out) profile cannot become active (ADR-0024); its
  /// account must sign in first.
  Future<void> setActive(String profileId) async {
    await _registry.transaction(() async {
      final exists = await (_registry.select(_registry.registryProfiles)
            ..where((p) => p.id.equals(profileId)))
          .getSingleOrNull();
      if (exists == null) throw StateError('unknown profile: $profileId');
      if (exists.accountId != null && exists.signedOut) {
        throw StateError('profile $profileId is signed out; sign in to open it');
      }
      await _registry
          .update(_registry.registryProfiles)
          .write(const RegistryProfilesCompanion(isActive: Value(false)));
      await (_registry.update(_registry.registryProfiles)
            ..where((p) => p.id.equals(profileId)))
          .write(const RegistryProfilesCompanion(isActive: Value(true)));
    });
  }

  /// Opens the store of a profile listed in the registry. A missing file is
  /// reported, never silently replaced by an empty database.
  Future<OpenedStore> openProfile(String profileId) async {
    final file = profileFile(profileId);
    if (!file.existsSync()) {
      throw const StoreUnavailable('the data file of this profile is missing');
    }
    return _openStore(profileId);
  }

  /// Creates a new profile: its own file, its own key, one Personal Workspace
  /// (WA-001), and a registry entry (inactive). [profileId]/[workspaceId] let
  /// a "new space" use the ids [ProfileBinder] decided.
  Future<ProfileEntry> createProfile({
    String displayName = '',
    EntityId? profileId,
    EntityId? workspaceId,
  }) async {
    final id = profileId ?? EntityId.generate();
    final ws = workspaceId ?? EntityId.generate();
    if (profileFile(id.value).existsSync()) {
      throw StateError('a store already exists for profile ${id.value}');
    }
    final store = await _openStore(id.value);
    final DateTime createdAt;
    try {
      await ProfileStore(store.db)
          .createProfile(profileId: id, workspaceId: ws, displayName: displayName);
      createdAt = (await store.db.select(store.db.profiles).getSingle()).createdAt;
    } finally {
      await store.db.close();
    }
    await _registry.into(_registry.registryProfiles).insert(
        RegistryProfilesCompanion.insert(
            id: id.value, displayName: Value(displayName), createdAt: createdAt));
    return (await _get(id.value))!;
  }

  /// Restores a validated export of a profile that is NOT on this device as a
  /// new profile with its ORIGINAL ids, its own file and key (ADR-0025;
  /// clean-install round trip, GS-20, LF-INV-ID-001). A profile that is on
  /// this device is restored INTO its own store instead (profile_restore.dart),
  /// never as a second profile, so this refuses it.
  /// The restored profile is inactive and unbound. On any failure the partly
  /// written file is removed and the registry is unchanged.
  Future<ProfileEntry> restoreFromExport(ParsedExport parsed) async {
    final data = parsed;
    final id = data.profileId;
    if (await _get(id) != null || profileFile(id).existsSync()) {
      throw StateError('profile $id is already on this device');
    }
    final file = profileFile(id);
    try {
      final store = await _openStore(id);
      try {
        await ProfileExport.writeInto(store.db, data);
      } finally {
        await store.db.close();
      }
      await _registry.into(_registry.registryProfiles).insert(
          RegistryProfilesCompanion.insert(
              id: id,
              displayName: Value(data.displayName),
              createdAt: data.profile.createdAt));
    } catch (_) {
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('${file.path}$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      rethrow;
    }
    return (await _get(id))!;
  }

  /// Deletes a profile from this device for good (ADR-0027): its registry
  /// entry, its database file and its key. The ACTIVE profile cannot be
  /// deleted (its store is open; switch first), so one profile always
  /// remains. Order: intent -> registry row -> files -> key -> clear intent.
  /// An interrupted delete is finished on the next open. Once the registry
  /// row is gone the profile is never listed or opened again.
  Future<void> deleteProfile(String profileId) async {
    final entry = await _get(profileId);
    if (entry == null) throw StateError('unknown profile: $profileId');
    if (entry.isActive) {
      throw StateError('the open profile cannot be deleted; switch first');
    }
    await _registry.transaction(() async {
      await _setMeta(_metaPendingDelete, profileId);
      await (_registry.delete(_registry.registryProfiles)
            ..where((p) => p.id.equals(profileId)))
          .go();
    });
    await _wipe(profileId);
  }

  Future<void> _wipe(String profileId) async {
    final file = profileFile(profileId);
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${file.path}$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    await _keysFor(profileKeyName(profileId)).delete();
    if (await _getMeta(_metaPending) == profileId) await _clearMeta(_metaPending);
    await _clearMeta(_metaPendingDelete);
  }

  Future<void> _finishPendingDelete() async {
    final id = await _getMeta(_metaPendingDelete);
    if (id == null) return;
    await (_registry.delete(_registry.registryProfiles)
          ..where((p) => p.id.equals(id)))
        .go();
    await _wipe(id);
  }

  /// Records the intent to change [profileId]'s store (ADR-0023). Call before
  /// a command that changes registry-mirrored fields (binding, name).
  Future<void> beginStoreChange(String profileId) =>
      _setMeta(_metaPending, profileId);

  /// Copies the registry-mirrored fields from the profile's own store (the
  /// source of truth) and clears a matching pending intent.
  Future<void> syncFromStore(String profileId, AppDatabase db) async {
    final row = await (db.select(db.profiles)..where((p) => p.id.equals(profileId)))
        .getSingleOrNull();
    if (row == null) return;
    await _registry.transaction(() async {
      await (_registry.update(_registry.registryProfiles)
            ..where((p) => p.id.equals(profileId)))
          .write(RegistryProfilesCompanion(
        displayName: Value(row.displayName),
        accountId: Value(row.accountId),
        accountProvider: Value(row.accountProvider),
        signedOut: Value(row.signedOut),
      ));
      if (await _getMeta(_metaPending) == profileId) {
        await (_registry.delete(_registry.registryMeta)
              ..where((m) => m.key.equals(_metaPending)))
            .go();
      }
    });
  }

  /// Device-level app settings (not profile data): kept in the encrypted
  /// registry, never exported or synced. Keys are prefixed `setting.`.
  Future<String?> readSetting(String key) => _getMeta('setting.$key');
  Future<void> writeSetting(String key, String value) =>
      _setMeta('setting.$key', value);

  Future<void> close() => _registry.close();

  // --- internals ------------------------------------------------------------

  Future<OpenedStore> _openStore(String profileId) => openLocalStore(
        file: profileFile(profileId),
        policy: policy,
        keys: _keysFor(profileKeyName(profileId)),
        background: _background,
      );

  Future<void> _recoverPending() async {
    final id = await _getMeta(_metaPending);
    if (id == null) return;
    if (await _get(id) == null || !profileFile(id).existsSync()) {
      await _clearMeta(_metaPending);
      return;
    }
    final store = await openProfile(id);
    try {
      await syncFromStore(id, store.db);
    } finally {
      await store.db.close();
    }
  }

  Future<void> _migrateLegacyIfNeeded() async {
    final legacy = legacyFile;
    if (await _getMeta(_metaLegacyMigrated) == 'true') {
      // Migrated, but the rename did not happen yet (interrupted).
      if (legacy.existsSync()) _moveLegacyToBackup();
      return;
    }
    if (!legacy.existsSync()) return;

    final source = await openLocalStore(
      file: legacy,
      policy: policy,
      keys: _keysFor(legacyKeyName),
      background: false,
    );
    try {
      final src = source.db;
      final profiles = await src.select(src.profiles).get();
      final entries = <RegistryProfilesCompanion>[];
      var mappedGovernance = 0;
      String? activeId;

      for (final p in profiles) {
        // A partial copy from an interrupted earlier attempt is redone from
        // the legacy source, which is still intact.
        final target = profileFile(p.id);
        for (final f in [target, File('${target.path}-wal'), File('${target.path}-shm')]) {
          if (f.existsSync()) f.deleteSync();
        }
        mappedGovernance += await _copyProfile(src, p);
        entries.add(RegistryProfilesCompanion.insert(
          id: p.id,
          displayName: Value(p.displayName),
          accountId: Value(p.accountId),
          accountProvider: Value(p.accountProvider),
          signedOut: Value(p.signedOut),
          isActive: Value(p.isActive && activeId == null),
          createdAt: p.createdAt,
        ));
        if (p.isActive && activeId == null) activeId = p.id;
      }

      final governanceTotal = (await src.select(src.auditLog).get()).length +
          (await src.select(src.outbox).get()).length +
          (await src.select(src.eventLog).get()).length;
      final unmapped = governanceTotal - mappedGovernance;

      await _registry.transaction(() async {
        for (final e in entries) {
          await _registry.into(_registry.registryProfiles).insertOnConflictUpdate(e);
        }
        await _setMeta(_metaLegacyUnmapped, '$unmapped');
        await _setMeta(_metaLegacyMigrated, 'true');
      });
      _lastMigration = LegacyMigrationReport(
          profiles: profiles.length, unmappedGovernanceRows: unmapped);
    } finally {
      await source.db.close();
    }
    _moveLegacyToBackup();
  }

  /// Copies one profile's rows into its own new store and verifies the counts.
  /// Returns the number of governance rows copied.
  Future<int> _copyProfile(AppDatabase src, Profile p) async {
    final workspaces = await (src.select(src.workspaces)
          ..where((w) => w.ownerId.equals(p.id)))
        .get();
    final wsIds = workspaces.map((w) => w.id).toList();
    final lists = await (src.select(src.taskLists)
          ..where((t) => t.workspaceId.isIn(wsIds)))
        .get();
    final tasks = await (src.select(src.tasks)
          ..where((t) => t.workspaceId.isIn(wsIds)))
        .get();
    final dedupe = await (src.select(src.opDedupe)
          ..where((d) => d.workspaceId.isIn(wsIds)))
        .get();
    final ops = dedupe.map((d) => d.operationId).toList();
    final audit = await (src.select(src.auditLog)
          ..where((a) => a.operationId.isIn(ops)))
        .get();
    final outbox = await (src.select(src.outbox)
          ..where((o) => o.operationId.isIn(ops)))
        .get();
    final events = await (src.select(src.eventLog)
          ..where((e) => e.operationId.isIn(ops)))
        .get();

    final dst = (await _openStore(p.id)).db;
    try {
      await dst.batch((b) {
        // Inside its own store the profile is, by definition, the active one.
        b.insertAll(dst.profiles, [p.copyWith(isActive: true)]);
        b.insertAll(dst.workspaces, workspaces);
        b.insertAll(dst.taskLists, lists);
        b.insertAll(dst.tasks, tasks); // FTS triggers index the titles
        b.insertAll(dst.opDedupe, dedupe);
        b.insertAll(dst.auditLog, audit);
        b.insertAll(dst.outbox, outbox);
        b.insertAll(dst.eventLog, events);
      });

      Future<void> check(String name, int expected, Future<int> actual) async {
        final n = await actual;
        if (n != expected) {
          throw StoreUnavailable(
              'migration check failed for $name ($n of $expected rows)');
        }
      }

      Future<int> count(TableInfo t) async =>
          (await dst.select(t).get()).length;
      await check('profiles', 1, count(dst.profiles));
      await check('workspaces', workspaces.length, count(dst.workspaces));
      await check('task lists', lists.length, count(dst.taskLists));
      await check('tasks', tasks.length, count(dst.tasks));
      await check('dedupe', dedupe.length, count(dst.opDedupe));
      await check('audit', audit.length, count(dst.auditLog));
      await check('outbox', outbox.length, count(dst.outbox));
      await check('events', events.length, count(dst.eventLog));
    } finally {
      await dst.close();
    }
    return audit.length + outbox.length + events.length;
  }

  void _moveLegacyToBackup() {
    final legacy = legacyFile;
    final backup = legacyBackupFile;
    if (backup.existsSync()) backup.deleteSync(); // an older kept copy
    legacy.renameSync(backup.path);
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('${legacy.path}$suffix');
      if (f.existsSync()) f.renameSync('${backup.path}$suffix');
    }
  }

  Future<ProfileEntry?> _get(String id) async {
    final row = await (_registry.select(_registry.registryProfiles)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _entry(row);
  }

  Future<String?> _getMeta(String key) async => (await (_registry
                  .select(_registry.registryMeta)
                ..where((m) => m.key.equals(key)))
              .getSingleOrNull())
          ?.value;

  Future<void> _setMeta(String key, String value) => _registry
      .into(_registry.registryMeta)
      .insertOnConflictUpdate(RegistryMetaCompanion.insert(key: key, value: value));

  Future<void> _clearMeta(String key) =>
      (_registry.delete(_registry.registryMeta)..where((m) => m.key.equals(key)))
          .go();

  ProfileEntry _entry(RegistryProfile r) => ProfileEntry(
        id: r.id,
        displayName: r.displayName,
        isActive: r.isActive,
        createdAt: r.createdAt,
        accountId: r.accountId,
        provider: r.accountProvider,
        signedOut: r.signedOut,
      );

  static String _join(String a, String b, [String? c]) {
    final sep = Platform.pathSeparator;
    return c == null ? '$a$sep$b' : '$a$sep$b$sep$c';
  }
}
