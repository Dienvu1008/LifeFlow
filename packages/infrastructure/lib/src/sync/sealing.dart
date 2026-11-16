// P04 T1b (ADR-0052 §5, spike S-15): end-to-end encryption of synced
// records. Nothing leaves the device unsealed (p04-plan.md D12).
//   workspace key  random 256 bits; seals records and keys the server ids;
//                  reaches the server only wrapped (WrappedKey)
//   sealed record  AES-256-GCM with a fresh 96-bit nonce, the server id and
//                  version as associated data, so a record cannot be moved
//                  to another id or replayed as another version
//   server id      HMAC-SHA-256 of kind and local id: 64 hex characters that
//                  say nothing about the record
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// The bytes were not sealed with this key, for this id and version, or were
/// changed. Safe to show: it never contains the content.
class SealBroken implements Exception {
  const SealBroken(this.why);
  final String why;
  @override
  String toString() => 'SealBroken: $why';
}

String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

/// A new random workspace key.
Future<SecretKey> newWorkspaceKey() => _aes.newSecretKey();

/// Seals and opens the records of one workspace.
class RecordSealer {
  RecordSealer._(this._seal, this._ids, this.keyId);
  final SecretKey _seal;
  final SecretKey _ids;

  /// A fingerprint of the workspace key (64 hex characters), kept with the
  /// workspace on the server: it tells a device whether its key is the one
  /// the records are sealed with (ADR-0057), and reveals nothing of the key.
  final String keyId;

  static Future<RecordSealer> of(SecretKey workspaceKey) async => RecordSealer._(
        await _hkdf.deriveKey(secretKey: workspaceKey, info: utf8.encode('lifeflow sync seal v1')),
        await _hkdf.deriveKey(secretKey: workspaceKey, info: utf8.encode('lifeflow sync ids v1')),
        _hex(await (await _hkdf.deriveKey(secretKey: workspaceKey, info: utf8.encode('lifeflow sync key id v1')))
            .extractBytes()),
      );

  /// The server's id of a local record (the S-03 format: 64 hex characters).
  Future<String> serverId(String kind, String localId) async =>
      _hex((await Hmac.sha256().calculateMac(utf8.encode('$kind:$localId'), secretKey: _ids)).bytes);

  List<int> _aad(String serverId, int version) => utf8.encode('$serverId:$version');

  Future<Uint8List> seal(String serverId, int version, Map<String, Object?> content) async {
    final box = await _aes.encrypt(utf8.encode(jsonEncode(content)), secretKey: _seal, aad: _aad(serverId, version));
    return box.concatenation();
  }

  Future<Map<String, dynamic>> open(String serverId, int version, List<int> sealed) async {
    try {
      final box = SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16, copy: true);
      final clear = await _aes.decrypt(box, secretKey: _seal, aad: _aad(serverId, version));
      return (jsonDecode(utf8.decode(clear)) as Map).cast<String, dynamic>();
    } on SecretBoxAuthenticationError {
      throw const SealBroken('wrong key, another id or version, or changed bytes');
    } on FormatException {
      throw const SealBroken('not a sealed record');
    } on ArgumentError {
      throw const SealBroken('not a sealed record');
    }
  }
}

/// How a workspace key is unlocked on a new device (p04-plan.md D15).
enum UnlockKind { recoveryKey, passphrase }

/// The workspace key as the server keeps it (account_workspaces):
/// `bytes` = format byte 1, then AES-256-GCM of the key under the unlock key
/// with the workspace id as associated data; `salt` only for a passphrase.
class WrappedKey {
  const WrappedKey(this.bytes, this.kind, [this.salt]);
  final Uint8List bytes;
  final UnlockKind kind;
  final Uint8List? salt;
}

/// The only wrapping format so far: AES-256-GCM; for a passphrase, Argon2id
/// with 19 MiB, 2 passes and 1 lane (OWASP's minimum).
const wrapFormat = 1;

List<int> _wrapAad(String workspaceId) => utf8.encode('lifeflow workspace key v1:$workspaceId');

Future<Uint8List> wrapWith(SecretKey unlock, SecretKey workspaceKey, String workspaceId) async {
  final box = await _aes.encrypt(await workspaceKey.extractBytes(), secretKey: unlock, aad: _wrapAad(workspaceId));
  return Uint8List.fromList([wrapFormat, ...box.concatenation()]);
}

Future<SecretKey> unwrapWith(SecretKey unlock, List<int> wrapped, String workspaceId) async {
  if (wrapped.isEmpty || wrapped.first != wrapFormat) {
    throw const SealBroken('a key wrapped by a newer version of LifeFlow');
  }
  try {
    final box = SecretBox.fromConcatenation(wrapped.sublist(1), nonceLength: 12, macLength: 16, copy: true);
    return SecretKey(await _aes.decrypt(box, secretKey: unlock, aad: _wrapAad(workspaceId)));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('wrong recovery key or passphrase');
  } on ArgumentError {
    throw const SealBroken('not a wrapped key');
  }
}

/// The unlock key of a recovery key (already 256 random bits).
Future<SecretKey> unlockFromRecoveryKey(List<int> recoveryKey) =>
    _hkdf.deriveKey(secretKey: SecretKey(recoveryKey), info: utf8.encode('lifeflow unlock recovery v1'));

final _argon2id = Argon2id(memory: 19 * 1024, iterations: 2, parallelism: 1, hashLength: 32);

/// The unlock key of a passphrase (Argon2id; [salt] is 16 random bytes kept
/// with the wrapped key).
Future<SecretKey> unlockFromPassphrase(String passphrase, List<int> salt) =>
    _argon2id.deriveKeyFromPassword(password: passphrase, nonce: salt);
