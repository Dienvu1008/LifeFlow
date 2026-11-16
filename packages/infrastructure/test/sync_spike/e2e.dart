// P04 spike S-15 (p04-plan.md D12, D15): end-to-end encryption of synced
// records. Prototype for T1b.
//   workspace key   random 256-bit key of the synced workspace; it seals the
//                   records and derives the opaque server ids. It reaches
//                   the server only wrapped.
//   unlock key      wraps the workspace key: either the recovery key itself
//                   (256 random bits, shown as 24 words, BIP-39 encoding) or
//                   Argon2id(passphrase, salt). Changing it only re-wraps
//                   the workspace key; no record is sealed again.
//   sealed record   AES-256-GCM, a fresh 96-bit nonce each time, the server
//                   id and version as associated data: a record cannot be
//                   moved to another id or replayed as another version.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// The opened content was not sealed with this key for this id and version.
class SealBroken implements Exception {
  const SealBroken(this.why);
  final String why;
  @override
  String toString() => 'SealBroken: $why';
}

Future<SecretKey> newWorkspaceKey() => _aes.newSecretKey();

class RecordSealer {
  RecordSealer._(this._seal, this._ids);
  final SecretKey _seal;
  final SecretKey _ids;

  static Future<RecordSealer> of(SecretKey workspaceKey) async => RecordSealer._(
        await _hkdf.deriveKey(secretKey: workspaceKey, info: utf8.encode('lifeflow sync seal v1')),
        await _hkdf.deriveKey(secretKey: workspaceKey, info: utf8.encode('lifeflow sync ids v1')),
      );

  /// The server's id of a local record: a keyed hash, so the server learns
  /// neither the kind, nor the local id, nor which records belong together.
  Future<String> serverId(String kind, String localId) async {
    final mac = await Hmac.sha256().calculateMac(utf8.encode('$kind:$localId'), secretKey: _ids);
    return [for (final b in mac.bytes) b.toRadixString(16).padLeft(2, '0')].join();
  }

  List<int> _aad(String serverId, int version) => utf8.encode('$serverId:$version');

  Future<Uint8List> seal(String serverId, int version, Map<String, Object?> content) async {
    final box = await _aes.encrypt(utf8.encode(jsonEncode(content)),
        secretKey: _seal, aad: _aad(serverId, version));
    return box.concatenation();
  }

  Future<Map<String, dynamic>> open(String serverId, int version, List<int> sealed) async {
    try {
      final box = SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16, copy: true);
      final clear = await _aes.decrypt(box, secretKey: _seal, aad: _aad(serverId, version));
      return (jsonDecode(utf8.decode(clear)) as Map).cast<String, dynamic>();
    } on SecretBoxAuthenticationError {
      throw const SealBroken('wrong key, another id or version, or changed bytes');
    }
  }
}

/// Wraps the workspace key for the server (account_workspaces.wrapped_key).
Future<Uint8List> wrapKey(SecretKey unlock, SecretKey workspaceKey, String workspaceId) async {
  final box = await _aes.encrypt(await workspaceKey.extractBytes(),
      secretKey: unlock, aad: utf8.encode('lifeflow workspace key v1:$workspaceId'));
  return box.concatenation();
}

Future<SecretKey> unwrapKey(SecretKey unlock, List<int> wrapped, String workspaceId) async {
  try {
    final box = SecretBox.fromConcatenation(wrapped, nonceLength: 12, macLength: 16, copy: true);
    return SecretKey(await _aes.decrypt(box,
        secretKey: unlock, aad: utf8.encode('lifeflow workspace key v1:$workspaceId')));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('wrong recovery key or passphrase');
  }
}

// --- Recovery key: 256 random bits as 24 BIP-39 words ------------------------

List<String>? _words;
List<String> get bip39 =>
    _words ??= File('test/sync_spike/bip39_english.txt').readAsLinesSync().where((w) => w.isNotEmpty).toList();

Uint8List newRecoveryKey() {
  final r = Random.secure();
  return Uint8List.fromList([for (var i = 0; i < 32; i++) r.nextInt(256)]);
}

/// 256 bits + an 8-bit checksum (the first byte of their SHA-256) = 24 × 11.
List<String> toWords(List<int> key) {
  assert(key.length == 32);
  final bits = StringBuffer();
  for (final b in [...key, hash.sha256.convert(key).bytes.first]) {
    bits.write(b.toRadixString(2).padLeft(8, '0'));
  }
  final s = bits.toString();
  return [for (var i = 0; i < 24; i++) bip39[int.parse(s.substring(i * 11, i * 11 + 11), radix: 2)]];
}

/// Back from the words; a wrong or misspelt word is refused (the checksum
/// catches most swaps of one word for another).
Uint8List fromWords(List<String> words) {
  if (words.length != 24) throw const FormatException('a recovery key has 24 words');
  final bits = StringBuffer();
  for (final w in words) {
    final i = bip39.indexOf(w.trim().toLowerCase());
    if (i < 0) throw FormatException('"$w" is not a recovery-key word');
    bits.write(i.toRadixString(2).padLeft(11, '0'));
  }
  final s = bits.toString();
  final bytes = [for (var i = 0; i < 33; i++) int.parse(s.substring(i * 8, i * 8 + 8), radix: 2)];
  final key = Uint8List.fromList(bytes.sublist(0, 32));
  if (hash.sha256.convert(key).bytes.first != bytes[32]) {
    throw const FormatException('these words are not a recovery key (check each word)');
  }
  return key;
}

Future<SecretKey> unlockFromRecoveryKey(List<int> key) =>
    _hkdf.deriveKey(secretKey: SecretKey(key), info: utf8.encode('lifeflow unlock recovery v1'));

/// OWASP's minimum for Argon2id: 19 MiB, 2 passes, 1 lane.
final argon2id = Argon2id(memory: 19 * 1024, iterations: 2, parallelism: 1, hashLength: 32);

Future<SecretKey> unlockFromPassphrase(String passphrase, List<int> salt) =>
    argon2id.deriveKeyFromPassword(password: passphrase, nonce: salt);
