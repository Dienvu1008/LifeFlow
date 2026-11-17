// P04b T10 (ADR-0062, from spike S-16): the keys of shared spaces, with the
// library already in use (cryptography 2.9.0: X25519, HKDF-SHA-256 and
// AES-256-GCM in pure Dart).
//   account key   each account has an X25519 key pair; its private key is
//                 sealed with the account's personal workspace key, so every
//                 device of the account opens it (B5: sync must be on)
//   member wrap   a space key wrapped for one member: X25519 with a fresh key
//                 pair per wrap, HKDF, AES-256-GCM, the space id bound in
//   join at once  a space key wrapped with a key made from the invitation
//                 code; the server keeps only a hash of the code (B7)
//   code          16 random bytes' worth of letters (26 of a 32-letter
//                 alphabet, 130 bits), also as a lifeflow://join/ link (B6)
// A space key is a workspace key (sealing.dart): RecordSealer seals the
// space's records with it, and its keyId names it on the server.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'sealing.dart';

final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// The format byte of every wrapping made here.
const spaceKeyFormat = 1;

/// An account's X25519 key pair, as its devices hold it.
class AccountKeyPair {
  AccountKeyPair._(this._pair, this.publicKey, this._seed);
  final SimpleKeyPair _pair;
  final Uint8List publicKey;
  final List<int> _seed;

  static Future<AccountKeyPair> generate() async {
    final pair = await _x25519.newKeyPair();
    return AccountKeyPair._(
        pair, Uint8List.fromList((await pair.extractPublicKey()).bytes), await pair.extractPrivateKeyBytes());
  }

  /// From the 32 private bytes (as kept in secure storage or opened from the
  /// server).
  static Future<AccountKeyPair> fromSeed(List<int> seed) async {
    if (seed.length != 32) throw const SealBroken('not an account key');
    final pair = await _x25519.newKeyPairFromSeed(seed);
    return AccountKeyPair._(pair, Uint8List.fromList((await pair.extractPublicKey()).bytes), List.of(seed));
  }

  /// The private bytes, for this device's secure storage only.
  List<int> get seed => List.unmodifiable(_seed);
}

List<int> _privateAad(String accountId) => utf8.encode('lifeflow account private key v1:$accountId');

Future<SecretKey> _privateKek(SecretKey personalKey, String accountId) =>
    _hkdf.deriveKey(secretKey: personalKey, info: _privateAad(accountId));

/// The private key sealed with the account's personal workspace key, for the
/// server's account_private_keys: format byte, then the AES-GCM box.
Future<Uint8List> sealAccountPrivate(AccountKeyPair pair, SecretKey personalKey, String accountId) async {
  final box = await _aes.encrypt(pair.seed, secretKey: await _privateKek(personalKey, accountId), aad: _privateAad(accountId));
  return Uint8List.fromList([spaceKeyFormat, ...box.concatenation()]);
}

/// Opens [sealed] on another device of the account. Throws [SealBroken] for
/// another personal key (it was reset) or another account.
Future<AccountKeyPair> openAccountPrivate(List<int> sealed, SecretKey personalKey, String accountId) async {
  final box = _box(sealed, 'not a sealed account key');
  try {
    return await AccountKeyPair.fromSeed(
        await _aes.decrypt(box, secretKey: await _privateKek(personalKey, accountId), aad: _privateAad(accountId)));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('another personal key or account');
  }
}

SecretBox _box(List<int> wrapped, String what, [int skip = 0]) {
  if (wrapped.isEmpty || wrapped.first != spaceKeyFormat) {
    throw const SealBroken('a key wrapped by a newer version of LifeFlow');
  }
  try {
    return SecretBox.fromConcatenation(wrapped.sublist(1 + skip), nonceLength: 12, macLength: 16, copy: true);
  } on ArgumentError {
    // RangeError too: cut short.
    throw SealBroken(what);
  }
}

List<int> _spaceAad(String spaceId) => utf8.encode('lifeflow space key v1:$spaceId');

Future<SecretKey> _memberKek(SecretKey shared, List<int> ephemeral, List<int> member, String spaceId) =>
    _hkdf.deriveKey(secretKey: shared, nonce: [...ephemeral, ...member], info: _spaceAad(spaceId));

/// [spaceKey] wrapped for the member with [memberPublicKey]: format byte,
/// the fresh sender public key (32 bytes), then the AES-GCM box (93 bytes).
Future<Uint8List> wrapForMember(SecretKey spaceKey, List<int> memberPublicKey, String spaceId) async {
  if (memberPublicKey.length != 32) throw ArgumentError('a public key is 32 bytes');
  final member = SimplePublicKey(memberPublicKey, type: KeyPairType.x25519);
  final eph = await _x25519.newKeyPair();
  final ephPub = (await eph.extractPublicKey()).bytes;
  final shared = await _x25519.sharedSecretKey(keyPair: eph, remotePublicKey: member);
  final box = await _aes.encrypt(await spaceKey.extractBytes(),
      secretKey: await _memberKek(shared, ephPub, memberPublicKey, spaceId), aad: _spaceAad(spaceId));
  return Uint8List.fromList([spaceKeyFormat, ...ephPub, ...box.concatenation()]);
}

/// Opens a key wrapped for [me]. Throws [SealBroken] when it was wrapped for
/// someone else, for another space, or changed.
Future<SecretKey> openForMember(List<int> wrapped, AccountKeyPair me, String spaceId) async {
  if (wrapped.length < 1 + 32) throw const SealBroken('not a wrapped space key');
  final box = _box(wrapped, 'not a wrapped space key', 32);
  final ephPub = wrapped.sublist(1, 33);
  final shared = await _x25519.sharedSecretKey(
      keyPair: me._pair, remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519));
  try {
    return SecretKey(await _aes.decrypt(box,
        secretKey: await _memberKek(shared, ephPub, me.publicKey, spaceId), aad: _spaceAad(spaceId)));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('not for this member, or another space');
  }
}

// --- A name for one account (P04b T13, ADR-0065) ----------------------------

List<int> _nameAad(String spaceId, String fromAccount) => utf8.encode('lifeflow member name v1:$spaceId:$fromAccount');

/// [name] sealed for the account with [publicKey] (the space's owner), by
/// [fromAccount] asking to join [spaceId]: the same construction as a
/// member wrap, bound to both.
Future<Uint8List> sealNameFor(String name, List<int> publicKey, String spaceId, String fromAccount) async {
  if (publicKey.length != 32) throw ArgumentError('a public key is 32 bytes');
  final eph = await _x25519.newKeyPair();
  final ephPub = (await eph.extractPublicKey()).bytes;
  final shared = await _x25519.sharedSecretKey(
      keyPair: eph, remotePublicKey: SimplePublicKey(publicKey, type: KeyPairType.x25519));
  final aad = _nameAad(spaceId, fromAccount);
  final kek = await _hkdf.deriveKey(secretKey: shared, nonce: [...ephPub, ...publicKey], info: aad);
  final box = await _aes.encrypt(utf8.encode(name), secretKey: kek, aad: aad);
  return Uint8List.fromList([spaceKeyFormat, ...ephPub, ...box.concatenation()]);
}

/// The name [fromAccount] sealed for [me]. Throws [SealBroken].
Future<String> openNameAs(List<int> sealed, AccountKeyPair me, String spaceId, String fromAccount) async {
  if (sealed.length < 1 + 32) throw const SealBroken('not a sealed name');
  final box = _box(sealed, 'not a sealed name', 32);
  final ephPub = sealed.sublist(1, 33);
  final shared = await _x25519.sharedSecretKey(
      keyPair: me._pair, remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519));
  final aad = _nameAad(spaceId, fromAccount);
  try {
    final kek = await _hkdf.deriveKey(secretKey: shared, nonce: [...ephPub, ...me.publicKey], info: aad);
    return utf8.decode(await _aes.decrypt(box, secretKey: kek, aad: aad));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('not for this account, or from someone else');
  } on FormatException {
    throw const SealBroken('not a name');
  }
}

// --- Invitations (B6, B7) ---------------------------------------------------

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// The length of an invitation code: 26 letters of 32, 130 bits.
const invitationCodeLength = 26;

/// What a link to an invitation starts with.
const invitationLinkPrefix = 'lifeflow://join/';

/// A new invitation code.
String newInvitationCode([Random? random]) {
  final r = random ?? Random.secure();
  return [for (var i = 0; i < invitationCodeLength; i++) _alphabet[r.nextInt(_alphabet.length)]].join();
}

/// The code grouped for reading aloud or typing: ABCDE-FGHJK-…
String formatInvitationCode(String code) =>
    [for (var i = 0; i < code.length; i += 5) code.substring(i, min(i + 5, code.length))].join('-');

String invitationLink(String code) => '$invitationLinkPrefix$code';

/// The code in what someone typed, pasted or scanned: the code itself (any
/// case, with spaces or dashes) or a lifeflow://join/ link. The alphabet has
/// no O, 0, I or 1, and look-alikes are not guessed. Null when it is not a
/// code.
String? parseInvitation(String text) {
  var t = text.trim();
  if (t.toLowerCase().startsWith(invitationLinkPrefix)) t = t.substring(invitationLinkPrefix.length);
  t = t.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
  if (t.length != invitationCodeLength) return null;
  for (final c in t.split('')) {
    if (!_alphabet.contains(c)) return null;
  }
  return t;
}

/// What the server keeps of a code: SHA-256 of 'lifeflow invite v1:' + code.
Future<String> invitationHash(String code) async => [
      for (final b in (await Sha256().hash(utf8.encode('lifeflow invite v1:$code'))).bytes) b.toRadixString(16).padLeft(2, '0')
    ].join();

Future<SecretKey> _codeKey(String code, String spaceId) =>
    _hkdf.deriveKey(secretKey: SecretKey(utf8.encode(code)), info: utf8.encode('lifeflow invite key v1:$spaceId'));

/// [spaceKey] wrapped with a key made from [code] ("join at once").
Future<Uint8List> wrapForCode(SecretKey spaceKey, String code, String spaceId) async {
  final box = await _aes.encrypt(await spaceKey.extractBytes(),
      secretKey: await _codeKey(code, spaceId), aad: _spaceAad(spaceId));
  return Uint8List.fromList([spaceKeyFormat, ...box.concatenation()]);
}

Future<SecretKey> openWithCode(List<int> wrapped, String code, String spaceId) async {
  final box = _box(wrapped, 'not a wrapped space key');
  try {
    return SecretKey(await _aes.decrypt(box, secretKey: await _codeKey(code, spaceId), aad: _spaceAad(spaceId)));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('another code or space');
  }
}
