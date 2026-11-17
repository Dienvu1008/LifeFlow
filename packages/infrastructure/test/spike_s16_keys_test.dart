// P04b spike S-16 (p04b-plan.md B5, B7, B8; ADR-0052, ADR-0054): the keys of
// a shared space, with the library already in use (cryptography 2.9.0,
// VS-42: X25519, HKDF, AES-GCM in pure Dart). Throwaway: T10 turns what holds
// into infrastructure code.
//   account key   each account has an X25519 key pair; its private key is
//                 sealed with the account's personal workspace key, so every
//                 device of that account can open it (B5: sync must be on)
//   member wrap   the space key wrapped for one member: X25519 with a fresh
//                 key pair per wrap, HKDF, AES-256-GCM, the space id as
//                 associated data
//   join at once  the space key wrapped with a key made from the invitation
//                 code; the server keeps only a hash of the code (B7)
//   rotation      after a removal a new space key; nothing sealed with it
//                 opens with the old one (B8, LF-INV-SHARE-004)
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// An account's key pair, as its devices hold it.
class AccountKeyPair {
  AccountKeyPair(this.keyPair, this.publicKey);
  final SimpleKeyPair keyPair;
  final SimplePublicKey publicKey;
  static Future<AccountKeyPair> generate() async {
    final kp = await _x25519.newKeyPair();
    return AccountKeyPair(kp, await kp.extractPublicKey());
  }
}

/// The private key sealed with the personal workspace key (to the server's
/// `account_private_keys`), and opened again on another device.
Future<Uint8List> sealPrivate(AccountKeyPair a, SecretKey personalKey, String accountId) async {
  final kek = await _hkdf.deriveKey(secretKey: personalKey, info: utf8.encode('lifeflow account private key v1:$accountId'));
  final box = await _aes.encrypt(await a.keyPair.extractPrivateKeyBytes(), secretKey: kek, aad: utf8.encode(accountId));
  return box.concatenation();
}

Future<AccountKeyPair> openPrivate(Uint8List sealed, SecretKey personalKey, String accountId) async {
  final kek = await _hkdf.deriveKey(secretKey: personalKey, info: utf8.encode('lifeflow account private key v1:$accountId'));
  final clear = await _aes.decrypt(SecretBox.fromConcatenation(sealed, nonceLength: 12, macLength: 16),
      secretKey: kek, aad: utf8.encode(accountId));
  final kp = await _x25519.newKeyPairFromSeed(clear);
  return AccountKeyPair(kp, await kp.extractPublicKey());
}

/// 1 byte format, the sender's fresh public key (32), then the AES-GCM box.
Future<Uint8List> wrapForMember(SecretKey spaceKey, SimplePublicKey member, String spaceId) async {
  final eph = await _x25519.newKeyPair();
  final ephPub = await eph.extractPublicKey();
  final shared = await _x25519.sharedSecretKey(keyPair: eph, remotePublicKey: member);
  final kek = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: [...ephPub.bytes, ...member.bytes],
      info: utf8.encode('lifeflow space key v1:$spaceId'));
  final box = await _aes.encrypt(await spaceKey.extractBytes(), secretKey: kek, aad: utf8.encode(spaceId));
  return Uint8List.fromList([1, ...ephPub.bytes, ...box.concatenation()]);
}

Future<SecretKey> openAsMember(Uint8List wrapped, AccountKeyPair me, String spaceId) async {
  if (wrapped.isEmpty || wrapped[0] != 1) throw const SealBroken('unknown format');
  final ephPub = SimplePublicKey(wrapped.sublist(1, 33), type: KeyPairType.x25519);
  final shared = await _x25519.sharedSecretKey(keyPair: me.keyPair, remotePublicKey: ephPub);
  final kek = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: [...ephPub.bytes, ...me.publicKey.bytes],
      info: utf8.encode('lifeflow space key v1:$spaceId'));
  try {
    final clear = await _aes.decrypt(SecretBox.fromConcatenation(wrapped.sublist(33), nonceLength: 12, macLength: 16),
        secretKey: kek, aad: utf8.encode(spaceId));
    return SecretKey(clear);
  } on SecretBoxAuthenticationError {
    throw const SealBroken('not for this member, or another space');
  }
}

/// An invitation code: 16 random bytes as 26 base-32 letters.
String newInvitationCode([Random? r]) {
  final rnd = r ?? Random.secure();
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return [for (var i = 0; i < 26; i++) alphabet[rnd.nextInt(alphabet.length)]].join();
}

/// What the server keeps (the pgTAP spike's `pg_temp.hash`).
Future<String> invitationHash(String code) async =>
    [for (final b in (await Sha256().hash(utf8.encode('lifeflow invite v1:$code'))).bytes) b.toRadixString(16).padLeft(2, '0')]
        .join();

Future<SecretKey> _codeKey(String code, String spaceId) =>
    _hkdf.deriveKey(secretKey: SecretKey(utf8.encode(code)), info: utf8.encode('lifeflow invite key v1:$spaceId'));

Future<Uint8List> wrapForCode(SecretKey spaceKey, String code, String spaceId) async =>
    (await _aes.encrypt(await spaceKey.extractBytes(), secretKey: await _codeKey(code, spaceId), aad: utf8.encode(spaceId)))
        .concatenation();

Future<SecretKey> openWithCode(Uint8List wrapped, String code, String spaceId) async {
  try {
    return SecretKey(await _aes.decrypt(SecretBox.fromConcatenation(wrapped, nonceLength: 12, macLength: 16),
        secretKey: await _codeKey(code, spaceId), aad: utf8.encode(spaceId)));
  } on SecretBoxAuthenticationError {
    throw const SealBroken('another code or space');
  }
}

void main() {
  const space = '20000000-0000-4000-8000-0000000000f1';

  test('a member\'s private key reaches their other devices through the personal workspace key only', () async {
    final lan = await AccountKeyPair.generate();
    final personal = await newWorkspaceKey();
    final sealed = await sealPrivate(lan, personal, 'lan');
    final onPhone = await openPrivate(sealed, personal, 'lan');
    expect(onPhone.publicKey.bytes, lan.publicKey.bytes);
    await expectLater(openPrivate(sealed, await newWorkspaceKey(), 'lan'), throwsA(isA<SecretBoxAuthenticationError>()));
    await expectLater(openPrivate(sealed, personal, 'minh'), throwsA(isA<SecretBoxAuthenticationError>()),
        reason: 'bound to the account');
  });

  test('the space key wrapped for one member opens for that member only, in that space only', () async {
    final owner = await AccountKeyPair.generate();
    final lan = await AccountKeyPair.generate();
    final minh = await AccountKeyPair.generate();
    final key = await newWorkspaceKey();
    final forLan = await wrapForMember(key, lan.publicKey, space);
    expect(forLan.length, 1 + 32 + 12 + 32 + 16);
    expect(await (await openAsMember(forLan, lan, space)).extractBytes(), await key.extractBytes());
    await expectLater(openAsMember(forLan, minh, space), throwsA(isA<SealBroken>()), reason: 'another member');
    await expectLater(openAsMember(forLan, owner, space), throwsA(isA<SealBroken>()), reason: 'even the owner');
    await expectLater(openAsMember(forLan, lan, '20000000-0000-4000-8000-0000000000f2'), throwsA(isA<SealBroken>()),
        reason: 'moved to another space');
    final changed = Uint8List.fromList(forLan)..[40] ^= 1;
    await expectLater(openAsMember(changed, lan, space), throwsA(isA<SealBroken>()), reason: 'a changed byte');
    final again = await wrapForMember(key, lan.publicKey, space);
    expect(again, isNot(forLan), reason: 'a fresh key pair per wrap');
  });

  test('join at once: the code opens the key; its hash, which the server keeps, does not', () async {
    final key = await newWorkspaceKey();
    final code = newInvitationCode();
    expect(code, matches(RegExp(r'^[A-Z2-9]{26}$')));
    final wrapped = await wrapForCode(key, code, space);
    expect(await (await openWithCode(wrapped, code, space)).extractBytes(), await key.extractBytes());
    final hash = await invitationHash(code);
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    await expectLater(openWithCode(wrapped, hash, space), throwsA(isA<SealBroken>()), reason: 'the hash is not the code');
    await expectLater(openWithCode(wrapped, newInvitationCode(), space), throwsA(isA<SealBroken>()));
    // Joined: the device wraps the key again for its own account.
    final joiner = await AccountKeyPair.generate();
    final mine = await wrapForMember(await openWithCode(wrapped, code, space), joiner.publicKey, space);
    expect(await (await openAsMember(mine, joiner, space)).extractBytes(), await key.extractBytes());
  });

  test('rotation: a removed member\'s old key opens nothing sealed after the removal; ids change too', () async {
    final oldKey = await newWorkspaceKey();
    final removed = await AccountKeyPair.generate();
    final stays = await AccountKeyPair.generate();
    final removedHad = await openAsMember(await wrapForMember(oldKey, removed.publicKey, space), removed, space);
    final newKey = await newWorkspaceKey();
    final forStays = await wrapForMember(newKey, stays.publicKey, space);
    final now = await RecordSealer.of(await openAsMember(forStays, stays, space));
    final before = await RecordSealer.of(removedHad);
    final sid = await now.serverId('task', 't1');
    final sealed = await now.seal(sid, 2, {'kind': 'task', 'id': 't1', 'row': {'title': 'After the removal'}});
    await expectLater(before.open(sid, 2, sealed), throwsA(isA<SealBroken>()));
    expect(await before.serverId('task', 't1'), isNot(sid), reason: 'the old key cannot even find the record');
    expect(before.keyId, isNot(now.keyId), reason: 'the devices see that the key changed');
  });

  test('speed: wrapping for 10 members and opening on a member device', () async {
    final members = [for (var i = 0; i < 10; i++) await AccountKeyPair.generate()];
    final key = await newWorkspaceKey();
    final sw = Stopwatch()..start();
    final wraps = [for (final m in members) await wrapForMember(key, m.publicKey, space)];
    final wrapMs = sw.elapsedMilliseconds;
    sw.reset();
    for (final (i, m) in members.indexed) {
      await openAsMember(wraps[i], m, space);
    }
    final openMs = sw.elapsedMilliseconds;
    printOnFailure('wrap x10: $wrapMs ms, open x10: $openMs ms');
    // ignore: avoid_print
    print('S-16 speed (desktop, pure Dart): wrap for 10 members $wrapMs ms; open 10 times $openMs ms');
    expect(wrapMs + openMs, lessThan(5000));
  });
}
