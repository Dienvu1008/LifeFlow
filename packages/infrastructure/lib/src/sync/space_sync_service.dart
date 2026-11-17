// P04b T11 (ADR-0063; p04b-plan.md B2, B4, B5, B12): the sync of the shared
// spaces of the active profile's account.
//   refresh  what the server says about the account's spaces (roles, the
//            rules, who is in) goes to the store's cache (SHARE-003); a space
//            the account is an active member of gets its key on this device
//            and a sync state; one it is no longer in stops syncing here
//            (what happens to its data is the leaving rule, T12)
//   sync     the shown space, by the same engine as personal sync, as the
//            space's sync actor: owners and editors push and pull, viewers
//            only pull (SHARE-002); only the kinds a space holds (B2)
//   rotation the owner's device finishes a rotation it started: a full
//            sync, every record sealed again with the new key, then the old
//            key's rows dropped (ADR-0062)
// The automatic sync (SyncScheduler) runs it every minute while a shared
// space is shown (B12). Personal sync is DriftSyncService, unchanged.
// Needs the personal sync on (B5): the account's key pair is opened with the
// personal workspace key.
import 'dart:async';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, TableUpdateQuery, Value, Variable;

import '../app_database.dart' hide Workspace;
import '../command_gateway.dart';
import '../profile_store.dart';
import '../record_kinds.dart';
import 'sealing.dart';
import 'space_key_service.dart';
import 'space_leaving.dart';
import 'sync_engine.dart';
import 'sync_setup_handler.dart' show newSyncDeviceId;
import 'workspace_keyring.dart';

/// How often the shown shared space syncs while the app is open (B12; the
/// personal workspace keeps SyncScheduler's 5 minutes).
const spaceSyncEvery = Duration(minutes: 1);

class DriftSpaceSyncService implements SyncRunner {
  DriftSpaceSyncService({
    required this.db,
    required this.gateway,
    required this.remote,
    required this.spaces,
    required this.keyring,
    required this.keys,
    this.log,
  }) : _store = ProfileStore(db);

  final AppDatabase db;
  final DriftCommandGateway gateway;
  final RemoteGateway remote;
  final SpaceGateway spaces;
  final WorkspaceKeyring keyring;
  final SpaceKeyService keys;

  /// Every space sync that did not end up to date (counts and the kind of
  /// failure; never content or a key).
  final void Function(String line)? log;
  final ProfileStore _store;

  Future<SyncReport>? _running;
  final _changed = StreamController<void>.broadcast();

  Future<String?> _account() async {
    final p = await _store.getActiveProfile();
    if (p == null || p.signedOut) return null;
    return p.binding?.accountId;
  }

  Future<Set<String>> _sharedIds() async =>
      {for (final w in await (db.select(db.workspaces)..where((w) => w.kind.equals('shared'))).get()) w.id};

  /// The shown workspace, if it is a shared space.
  Future<String?> _shownSpace() async {
    final p = await _store.getActiveProfile();
    if (p == null) return null;
    final ws = p.activeWorkspaceId.value;
    return (await _sharedIds()).contains(ws) ? ws : null;
  }

  /// The personal workspace's key, which opens the account's key pair (B5).
  Future<bool> _ensureAccountKeys(String account) async {
    if (await keys.accountKeyPair(account) != null) return true;
    final shared = await _sharedIds();
    final personal = (await db.select(db.syncState).get()).where((s) => !shared.contains(s.workspaceId)).firstOrNull;
    if (personal == null) return false;
    final key = await keyring.keyOf(personal.workspaceId);
    if (key == null) return false;
    await keys.ensureAccountKeys(account, key);
    return true;
  }

  /// Brings the cache of the account's spaces up to date with the server.
  /// Returns null when done, or why it could not.
  Future<SyncOutcome?> refresh() async {
    final account = await _account();
    if (account == null) return SyncOutcome.signedOut;
    if (!await _ensureAccountKeys(account)) return SyncOutcome.notOn;
    final mine = await spaces.spaces();
    final here = await (db.select(db.workspaces)..where((w) => w.kind.equals('shared'))).get();
    final names = {for (final w in here) w.id: w.name ?? ''};
    for (final s in mine) {
      final members = s.status == MemberStatus.active ? await spaces.members(s.workspaceId) : const <RemoteMember>[];
      final owner = members.where((m) => m.role == SpaceRole.owner).firstOrNull?.accountId ?? '';
      final rules = s.rules;
      final before = here.where((w) => w.id == s.workspaceId).firstOrNull;
      await _store.cacheSpace(SpaceSnapshot(
        workspaceId: s.workspaceId,
        ownerAccountId: owner,
        name: names[s.workspaceId] ?? '',
        members: [
          if (members.isEmpty) SpaceMemberSnapshot(accountId: account, role: s.role.name, status: s.status.name),
          for (final m in members) SpaceMemberSnapshot(accountId: m.accountId, role: m.role.name, status: m.status.name),
        ],
        leaveRule: (rules ?? const SpaceRules()).leave.name,
        exportRule: (rules ?? const SpaceRules()).export.name,
        inviteDefault: (rules ?? const SpaceRules()).inviteDefault.name,
        rulesChangedAt: s.rulesChangedAt,
      ));
      // P04b T12: the rules first become known when the owner approves; the
      // person saw them before asking to join (SHARE-005), so that is no
      // notice. A change after that is.
      if (before != null && before.rulesChangedAt == null && before.rulesSeenAt != null && s.rulesChangedAt != null) {
        await (db.update(db.workspaces)..where((w) => w.id.equals(s.workspaceId)))
            .write(WorkspacesCompanion(rulesSeenAt: Value(s.rulesChangedAt)));
      }
      if (s.status != MemberStatus.active) continue;
      try {
        await keys.openSpaceKey(account, s);
      } on SpaceKeyException catch (e) {
        log?.call('[space sync] ${s.workspaceId}: ${e.problem.name}');
        continue;
      } on SealBroken {
        log?.call('[space sync] ${s.workspaceId}: the key does not open');
        continue;
      }
      await db.into(db.syncState).insertOnConflictUpdate(SyncStateCompanion.insert(
            workspaceId: s.workspaceId,
            deviceId: (await _stateOf(s.workspaceId))?.deviceId ?? newSyncDeviceId(),
            cursor: Value((await _stateOf(s.workspaceId))?.cursor ?? 0),
          ));
    }
    // No longer in it (removed, left, or deleted): it stops syncing here,
    // nobody acts in it as a member, and what stays is its leaving rule's
    // (B8, ADR-0064).
    final still = {for (final s in mine) s.workspaceId};
    for (final w in here) {
      if (still.contains(w.id)) continue;
      await leaveSpaceHere(db, gateway, keyring, w.id);
    }
    _changed.add(null);
    return null;
  }

  Future<SyncStateRow?> _stateOf(String ws) =>
      (db.select(db.syncState)..where((s) => s.workspaceId.equals(ws))).getSingleOrNull();

  /// The account's role in [ws], as just cached.
  Future<SpaceMemberRow?> _me(String ws, String account) => (db.select(db.spaceMembers)
        ..where((m) => m.workspaceId.equals(ws) & m.accountId.equals(account)))
      .getSingleOrNull();

  /// One sync of [workspaceId] (a space this device syncs).
  Future<SyncReport> syncSpace(String workspaceId) async {
    final account = await _account();
    if (account == null) return SyncReport(SyncOutcome.signedOut);
    final state = await _stateOf(workspaceId);
    final key = await keyring.keyOf(workspaceId);
    final me = await _me(workspaceId, account);
    if (state == null || key == null || me == null || me.status != 'active') return SyncReport(SyncOutcome.notOn);
    final sealer = await RecordSealer.of(key);
    final previousKey = await keyring.previousKeyOf(workspaceId);
    final previous = previousKey == null ? null : await RecordSealer.of(previousKey);
    Future<String?> currentKeyId() async =>
        (await spaces.spaces()).where((s) => s.workspaceId == workspaceId).firstOrNull?.keyId;
    final engine = SyncEngine(
      db: db,
      gateway: gateway,
      remote: remote,
      sealer: sealer,
      workspaceId: workspaceId,
      deviceId: state.deviceId,
      space: SpaceSyncMode(
        check: () async {
          final s = (await spaces.spaces()).where((s) => s.workspaceId == workspaceId).firstOrNull;
          if (s == null || s.status != MemberStatus.active) return SyncOutcome.workspaceGone;
          if (s.keyId != sealer.keyId) return SyncOutcome.keyChanged;
          return null;
        },
        currentKeyId: currentKeyId,
        previous: previous,
        canPush: me.role == 'owner' || me.role == 'editor',
      ),
    );
    var report = await engine.sync();
    // The owner's device finishes a rotation it started (ADR-0062): after a
    // full sync, everything sealed again, then the old rows dropped.
    if (report.outcome == SyncOutcome.upToDate && previous != null && me.role == 'owner') {
      try {
        await engine.resealAll();
        await keys.finishRotation(workspaceId);
      } on RemoteFailure catch (e) {
        report = SyncReport(SyncOutcome.failed, pushed: report.pushed, pulled: report.pulled, detail: 'rotation: $e');
      }
    }
    return report;
  }

  @override
  Future<SyncReport> syncNow() {
    final running = _running;
    if (running != null) return running;
    final next = _syncOnce();
    _running = next;
    _changed.add(null);
    return next.whenComplete(() {
      _running = null;
      _changed.add(null);
    });
  }

  Future<SyncReport> _syncOnce() async {
    SyncReport r;
    try {
      final stop = await refresh();
      if (stop != null) {
        r = SyncReport(stop);
      } else {
        final shown = await _shownSpace();
        // A rotation between the refresh and this sync ends it as keyChanged;
        // the next run's refresh fetches the new key.
        r = shown == null ? SyncReport(SyncOutcome.notOn) : await syncSpace(shown);
      }
    } on RemoteFailure catch (e) {
      r = SyncReport(switch (e.kind) {
        RemoteFailureKind.unavailable => SyncOutcome.offline,
        RemoteFailureKind.signedOut => SyncOutcome.signedOut,
        RemoteFailureKind.notYours => SyncOutcome.notYours,
        RemoteFailureKind.refused => SyncOutcome.failed,
      }, detail: e.detail);
    } catch (e) {
      r = SyncReport(SyncOutcome.failed, detail: 'error: ${e.runtimeType}');
    }
    if (r.outcome != SyncOutcome.upToDate && r.outcome != SyncOutcome.notOn) log?.call('[space sync] $r');
    return r;
  }

  /// On while a shared space is shown (its sync state is made by the first
  /// sync's refresh).
  @override
  Future<SyncStatus> status() async {
    final ws = await _shownSpace();
    if (ws == null) return const SyncStatus(on: false);
    final s = await _stateOf(ws);
    final kinds = recordKinds.map((k) => "'${k.name}'").join(',');
    final pending = (await db.customSelect(
            "SELECT count(*) AS n FROM outbox WHERE status = 'pending' AND workspace_id = ? AND entity_type IN ($kinds)",
            variables: [Variable<String>(ws)]).getSingle())
        .read<int>('n');
    final reviews = (await (db.select(db.syncReviews)
              ..where((r) => r.resolvedAt.isNull() & r.workspaceId.equals(ws)))
            .get())
        .length;
    return SyncStatus(
      on: true,
      lastResult: SyncOutcome.values.where((o) => o.name == s?.lastResult).firstOrNull,
      lastSyncAt: s?.lastSyncAt,
      pending: pending,
      reviews: reviews,
      syncing: _running != null,
    );
  }

  @override
  Stream<SyncStatus> watchStatus() {
    final subs = <StreamSubscription<void>>[];
    late final StreamController<SyncStatus> out;
    var chain = Future<void>.value();
    void emit() => chain = chain.then((_) async {
          final s = await status();
          if (!out.isClosed) out.add(s);
        }).catchError((Object _) {});
    out = StreamController<SyncStatus>(
      onListen: () {
        emit();
        subs
          ..add(_changed.stream.listen((_) => emit()))
          ..add(db
              .tableUpdates(TableUpdateQuery.onAllTables([db.outbox, db.syncState, db.syncReviews, db.profiles]))
              .listen((_) => emit()));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }
}
