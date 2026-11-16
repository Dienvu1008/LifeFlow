// P04 T4 (ADR-0057; p04-plan.md D4, D5, D11, D15): turning sync on, joining,
// undoing a join, turning it off and deleting the server copy, for the
// active profile's store. Keys stay in secure storage (WorkspaceKeyring);
// the server sees wrapped keys and sealed records only (ADR-0052).
import 'package:application/application.dart';
import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:drift/drift.dart' show Variable;
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../command_gateway.dart';
import '../profile_store.dart';
import '../record_kinds.dart';
import 'passphrase_policy.dart';
import 'recovery_key.dart';
import 'sealing.dart';
import 'sync_engine.dart';
import 'sync_setup_handler.dart';
import 'workspace_keyring.dart';

class DriftSyncService implements SyncService {
  DriftSyncService({
    required this.db,
    required this.gateway,
    required this.remote,
    required this.keyring,
    this.transfer,
  }) : _store = ProfileStore(db);

  final AppDatabase db;
  final DriftCommandGateway gateway;
  final RemoteGateway remote;
  final WorkspaceKeyring keyring;

  /// Saves this device's data before "use the account's data" (D5).
  final DataTransferService? transfer;
  final ProfileStore _store;

  /// The recovery key offered and not confirmed yet.
  (KeySetup, (int, int))? _offer;

  Future<(String profileId, String ws)> _active() async {
    final p = await _store.getActiveProfile();
    if (p == null) throw const SyncSetupException(SyncSetupProblem.failed);
    return (p.profileId.value, p.activeWorkspaceId.value);
  }

  Future<SyncStateRow?> _state() async => (await db.select(db.syncState).get()).firstOrNull;

  static SyncSetupProblem _problemOf(RemoteFailure e) => switch (e.kind) {
        RemoteFailureKind.unavailable => SyncSetupProblem.offline,
        RemoteFailureKind.signedOut => SyncSetupProblem.signedOut,
        RemoteFailureKind.notYours => SyncSetupProblem.notYours,
        RemoteFailureKind.refused => SyncSetupProblem.failed,
      };

  @override
  Future<SyncStatus> status() async {
    final s = await _state();
    final snap = await (db.select(db.restoreSnapshots)..where((x) => x.id.equals(syncJoinSnapshotId))).getSingleOrNull();
    if (s == null) return SyncStatus(on: false, canUndoJoin: snap != null);
    final pending = (await db.customSelect(
            "SELECT count(*) AS n FROM outbox WHERE status = 'pending' AND workspace_id = ? "
            "AND entity_type IN (${recordKinds.map((k) => "'${k.name}'").join(',')})",
            variables: [Variable<String>(s.workspaceId)]).getSingle())
        .read<int>('n');
    final reviews = (await (db.select(db.syncReviews)..where((r) => r.resolvedAt.isNull())).get()).length;
    return SyncStatus(
      on: true,
      lastResult: SyncOutcome.values.where((o) => o.name == s.lastResult).firstOrNull,
      lastSyncAt: s.lastSyncAt,
      pending: pending,
      reviews: reviews,
      canUndoJoin: snap != null,
    );
  }

  @override
  Future<SyncStart> prepare() async {
    if (await _state() != null) return const SyncStartAlreadyOn();
    final (_, ws) = await _active();
    final List<RemoteWorkspace> mine;
    try {
      mine = await remote.workspaces();
    } on RemoteFailure catch (e) {
      throw SyncSetupException(_problemOf(e));
    }
    if (mine.isEmpty) return const SyncStartFresh();
    final w = mine.firstWhere((w) => w.workspaceId == ws, orElse: () => mine.first);
    return SyncStartJoin(w.unlockKind == 'passphrase' ? SyncUnlock.passphrase : SyncUnlock.recoveryKey);
  }

  @override
  Future<RecoveryKeyOffer> offerRecoveryKey() async {
    final (_, ws) = await _active();
    final setup = await keyring.setUpWithRecoveryKey(ws);
    final check = RecoveryKey.checkPositions();
    _offer = (setup, check);
    return RecoveryKeyOffer(words: setup.recoveryKey!.words, qrText: setup.recoveryKey!.qrText, check: check);
  }

  @override
  Future<SyncSetupResult> startWithRecoveryKey((String, String) answers) async {
    final offer = _offer;
    if (offer == null) return const SyncSetupResult.failed(SyncSetupProblem.recoveryKeyNotConfirmed);
    if (!offer.$1.recoveryKey!.confirms(offer.$2, answers)) {
      return const SyncSetupResult.failed(SyncSetupProblem.recoveryKeyNotConfirmed);
    }
    final r = await _start(offer.$1);
    if (r.ok) _offer = null;
    return r;
  }

  @override
  Future<SyncSetupResult> startWithPassphrase(String passphrase) async {
    final (_, ws) = await _active();
    try {
      return await _start(await keyring.setUpWithPassphrase(ws, passphrase));
    } on PassphraseRejected catch (e) {
      return SyncSetupResult.failed(
          e.problem == PassphraseProblem.tooShort ? SyncSetupProblem.passphraseTooShort : SyncSetupProblem.passphraseTooCommon);
    }
  }

  /// The first device: the server workspace, the key kept, sync on, the
  /// first upload.
  Future<SyncSetupResult> _start(KeySetup setup) async {
    if (await _state() != null) return const SyncSetupResult.failed(SyncSetupProblem.alreadyOn);
    final (_, ws) = await _active();
    final sealer = await RecordSealer.of(setup.workspaceKey);
    try {
      final mine = await remote.workspaces();
      if (mine.isNotEmpty) return const SyncSetupResult.failed(SyncSetupProblem.alreadyOn, 'the account already syncs');
      await remote.createWorkspace(RemoteWorkspace(
        workspaceId: ws,
        wrappedKey: setup.wrapped.bytes,
        unlockKind: setup.wrapped.kind.name,
        unlockSalt: setup.wrapped.salt,
        keyId: sealer.keyId,
      ));
    } on RemoteFailure catch (e) {
      return SyncSetupResult.failed(_problemOf(e));
    }
    await keyring.keep(ws, setup);
    final r = await _command(turnSyncOnAction, {'op': 'turnOn', 'id': ws, 'deviceId': newSyncDeviceId()});
    if (r is! CommandOk) return SyncSetupResult.failed(SyncSetupProblem.failed, '$r');
    return SyncSetupResult(firstSync: await syncNow());
  }

  @override
  Future<SyncSetupResult> join(JoinChoice choice, {String? recoveryKey, String? passphrase}) async {
    if (await _state() != null) return const SyncSetupResult.failed(SyncSetupProblem.alreadyOn);
    final (_, ws) = await _active();
    final RemoteWorkspace target;
    try {
      final mine = await remote.workspaces();
      if (mine.isEmpty) return const SyncSetupResult.failed(SyncSetupProblem.notYours, 'nothing to join');
      target = mine.firstWhere((w) => w.workspaceId == ws, orElse: () => mine.first);
    } on RemoteFailure catch (e) {
      return SyncSetupResult.failed(_problemOf(e));
    }
    final wrapped = WrappedKey(target.wrappedKey,
        target.unlockKind == 'passphrase' ? UnlockKind.passphrase : UnlockKind.recoveryKey, target.unlockSalt);
    final usesPassphrase = wrapped.kind == UnlockKind.passphrase;
    RecoveryKey? rk;
    if (!usesPassphrase) {
      try {
        rk = RecoveryKey.parse(recoveryKey ?? '');
      } on RecoveryKeyInvalid catch (e) {
        return SyncSetupResult.failed(SyncSetupProblem.recoveryKeyInvalid, e.message);
      }
    } else if (passphrase == null) {
      return const SyncSetupResult.failed(SyncSetupProblem.wrongPassphrase);
    }
    final SecretKey key;
    try {
      key = await keyring.unlock(target.workspaceId, wrapped, recoveryKey: rk, passphrase: usesPassphrase ? passphrase : null);
    } on SealBroken {
      return SyncSetupResult.failed(usesPassphrase ? SyncSetupProblem.wrongPassphrase : SyncSetupProblem.wrongRecoveryKey);
    }
    final sealer = await RecordSealer.of(key);
    if (target.keyId.isNotEmpty && target.keyId != sealer.keyId) {
      await keyring.forget(target.workspaceId);
      return const SyncSetupResult.failed(SyncSetupProblem.failed, 'the key does not match the workspace');
    }

    ExportFile? export;
    if (choice == JoinChoice.useAccountOnly) {
      final t = transfer;
      if (t == null) return const SyncSetupResult.failed(SyncSetupProblem.failed, 'cannot save this device\'s data first');
      export = await t.exportActiveProfile();
    }
    final deviceId = newSyncDeviceId();
    final CommandResult r;
    if (target.workspaceId == ws) {
      // This device made the workspace (a start cut off before it finished):
      // nothing moves.
      r = await _command(turnSyncOnAction, {'op': 'turnOn', 'id': ws, 'deviceId': deviceId});
    } else {
      r = await _command(joinSyncAction, {
        'op': 'join',
        'id': ws,
        'accountWorkspaceId': target.workspaceId,
        'deviceId': deviceId,
        'mode': choice == JoinChoice.mergeThisDevice ? 'merge' : 'replace',
      });
    }
    if (r is! CommandOk) {
      await keyring.forget(target.workspaceId);
      return SyncSetupResult.failed(SyncSetupProblem.failed, '$r');
    }
    return SyncSetupResult(firstSync: await syncNow(), export: export);
  }

  @override
  Future<SyncSetupResult> undoJoin() async {
    final s = await _state();
    final (_, ws) = await _active();
    final r = await _command(undoSyncJoinAction, {'op': 'undoJoin', 'id': ws});
    if (r is! CommandOk) return const SyncSetupResult.failed(SyncSetupProblem.nothingToUndo);
    if (s != null) await keyring.forget(s.workspaceId);
    return const SyncSetupResult();
  }

  @override
  Future<SyncReport> syncNow() async {
    final s = await _state();
    if (s == null) return SyncReport(SyncOutcome.notOn);
    final key = await keyring.keyOf(s.workspaceId);
    if (key == null) return SyncReport(SyncOutcome.keyChanged, detail: 'no key on this device');
    final engine = SyncEngine(
      db: db,
      gateway: gateway,
      remote: remote,
      sealer: await RecordSealer.of(key),
      workspaceId: s.workspaceId,
      deviceId: s.deviceId,
    );
    return engine.sync();
  }

  @override
  Future<SyncSetupResult> turnOff() async {
    final s = await _state();
    if (s == null) return const SyncSetupResult.failed(SyncSetupProblem.notOn);
    final r = await _command(turnSyncOffAction, {'op': 'turnOff', 'id': s.workspaceId});
    if (r is! CommandOk) return SyncSetupResult.failed(SyncSetupProblem.failed, '$r');
    await keyring.forget(s.workspaceId);
    return const SyncSetupResult();
  }

  @override
  Future<SyncSetupResult> deleteServerData() async {
    final s = await _state();
    if (s == null) return const SyncSetupResult.failed(SyncSetupProblem.notOn);
    try {
      await remote.deleteWorkspace(s.workspaceId);
    } on RemoteFailure catch (e) {
      if (e.kind != RemoteFailureKind.notYours) return SyncSetupResult.failed(_problemOf(e));
      // Already gone from the server: turning off here is all that is left.
    }
    return turnOff();
  }

  Future<CommandResult> _command(String type, Map<String, Object?> payload) async {
    final p = (await _store.getActiveProfile())!;
    return gateway.execute(
      Command(
        operationId: const Uuid().v7(),
        actor: ActorRef(ActorKind.owner, p.profileId.value),
        workspaceId: p.activeWorkspaceId.value,
        type: type,
        payload: payload,
        issuedAt: Instant.now(),
      ),
      const SyncSetupHandler(),
    );
  }
}
