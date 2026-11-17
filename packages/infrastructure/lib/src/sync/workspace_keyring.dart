// P04 T1b (p04-plan.md D12/D15, ADR-0052 §5): the workspace keys of this
// device, in platform secure storage (the same slots as the database keys,
// SR-02; never the database, plain files or logs, LF-INV-SEC-001).
//   set up   a new workspace key, wrapped by a new recovery key or by a
//            passphrase; kept only once the user confirmed the recovery key
//            (or chose an accepted passphrase), then uploaded wrapped (T4)
//   unlock   a second device unwraps the server's wrapped key with the
//            recovery key or the passphrase, and keeps the workspace key
//   rewrap   switch between recovery key and passphrase, or change either:
//            only the wrapping changes; no record is sealed again
//   reset    a new workspace key: what the server holds under the old key
//            can no longer be opened (T4 deletes and re-uploads)
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../local_store.dart' show DatabaseKeyStore;
import 'passphrase_policy.dart';
import 'recovery_key.dart';
import 'sealing.dart';

/// A passphrase below the minimum (passphrase_policy.dart).
class PassphraseRejected implements Exception {
  const PassphraseRejected(this.problem);
  final PassphraseProblem problem;
  @override
  String toString() => 'PassphraseRejected: ${problem.name}';
}

/// A new workspace key and how it will be unlocked, not kept yet.
class KeySetup {
  KeySetup._(this.workspaceKey, this.wrapped, this.recoveryKey);
  final SecretKey workspaceKey;
  final WrappedKey wrapped;

  /// For a recovery-key setup: to show (words, QR) and confirm.
  final RecoveryKey? recoveryKey;
}

class WorkspaceKeyring {
  WorkspaceKeyring(this._slotFor, {Random? random}) : _random = random ?? Random.secure();

  final DatabaseKeyStore Function(String name) _slotFor;
  final Random _random;

  DatabaseKeyStore _slot(String workspaceId) => _slotFor('lifeflow.sync.key.$workspaceId');

  /// This device's key of [workspaceId], or null when it has none.
  Future<SecretKey?> keyOf(String workspaceId) async {
    final s = await _slot(workspaceId).read();
    return s == null ? null : SecretKey(base64Decode(s));
  }

  Future<void> _keep(String workspaceId, SecretKey key) async =>
      _slot(workspaceId).write(base64Encode(await key.extractBytes()));

  /// A new workspace key unlocked by a new recovery key.
  Future<KeySetup> setUpWithRecoveryKey(String workspaceId) async {
    final key = await newWorkspaceKey();
    final recovery = RecoveryKey.generate(_random);
    return KeySetup._(key, await _wrapForRecovery(key, recovery, workspaceId), recovery);
  }

  /// A new workspace key unlocked by [passphrase]; throws [PassphraseRejected].
  Future<KeySetup> setUpWithPassphrase(String workspaceId, String passphrase) async {
    final key = await newWorkspaceKey();
    return KeySetup._(key, await _wrapForPassphrase(key, passphrase, workspaceId), null);
  }

  /// Keeps the key of a setup the user confirmed (the recovery key typed
  /// back, or an accepted passphrase). From here on this device seals with it.
  Future<void> keep(String workspaceId, KeySetup setup) => _keep(workspaceId, setup.workspaceKey);

  /// A second device: opens the server's [wrapped] key and keeps it. Throws
  /// [SealBroken] for a wrong recovery key or passphrase.
  Future<SecretKey> unlock(String workspaceId, WrappedKey wrapped, {RecoveryKey? recoveryKey, String? passphrase}) async {
    final SecretKey unlock = switch (wrapped.kind) {
      UnlockKind.recoveryKey when recoveryKey != null => await unlockFromRecoveryKey(recoveryKey.bytes),
      UnlockKind.passphrase when passphrase != null && wrapped.salt != null =>
        await unlockFromPassphrase(normalizePassphrase(passphrase), wrapped.salt!),
      _ => throw ArgumentError('this key is unlocked by its ${wrapped.kind.name}'),
    };
    final key = await unwrapWith(unlock, wrapped.bytes, workspaceId);
    await _keep(workspaceId, key);
    return key;
  }

  /// Wraps this device's key anew: by [recoveryKey] (a new one, confirmed by
  /// the user) or by [passphrase]. Nothing is sealed again.
  Future<WrappedKey> rewrap(String workspaceId, {RecoveryKey? recoveryKey, String? passphrase}) async {
    final key = await keyOf(workspaceId);
    if (key == null) throw StateError('this device has no key for the workspace');
    if ((recoveryKey == null) == (passphrase == null)) {
      throw ArgumentError('give a recovery key or a passphrase');
    }
    return recoveryKey != null
        ? _wrapForRecovery(key, recoveryKey, workspaceId)
        : _wrapForPassphrase(key, passphrase!, workspaceId);
  }

  /// Forgets this device's key (sync turned off, or the profile deleted),
  /// and the key before it.
  Future<void> forget(String workspaceId) async {
    await _slot(workspaceId).delete();
    await _previousSlot(workspaceId).delete();
  }

  // P04b T10 (ADR-0062): a shared space's key reaches the device wrapped for
  // its account (space_key_service.dart), not by a recovery key. After a
  // rotation the key before it is kept too, to read the rows still sealed
  // with it until they are sealed again.
  DatabaseKeyStore _previousSlot(String workspaceId) => _slotFor('lifeflow.sync.key.$workspaceId.previous');

  /// Keeps [key] as the workspace's key; with [keepPrevious] the key it
  /// replaces stays as the previous one.
  Future<void> keepKey(String workspaceId, SecretKey key, {bool keepPrevious = false}) async {
    final old = await keyOf(workspaceId);
    if (keepPrevious && old != null) {
      await _previousSlot(workspaceId).write(base64Encode(await old.extractBytes()));
    }
    await _keep(workspaceId, key);
  }

  /// The key before the current one, while a rotation is not finished.
  Future<SecretKey?> previousKeyOf(String workspaceId) async {
    final s = await _previousSlot(workspaceId).read();
    return s == null ? null : SecretKey(base64Decode(s));
  }

  Future<void> forgetPrevious(String workspaceId) => _previousSlot(workspaceId).delete();

  Future<WrappedKey> _wrapForRecovery(SecretKey key, RecoveryKey recovery, String workspaceId) async =>
      WrappedKey(await wrapWith(await unlockFromRecoveryKey(recovery.bytes), key, workspaceId), UnlockKind.recoveryKey);

  Future<WrappedKey> _wrapForPassphrase(SecretKey key, String passphrase, String workspaceId) async {
    final problem = checkPassphrase(passphrase);
    if (problem != null) throw PassphraseRejected(problem);
    final salt = Uint8List.fromList([for (var i = 0; i < 16; i++) _random.nextInt(256)]);
    return WrappedKey(
        await wrapWith(await unlockFromPassphrase(normalizePassphrase(passphrase), salt), key, workspaceId), UnlockKind.passphrase, salt);
  }
}
