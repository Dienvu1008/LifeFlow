// P04b T10 (ADR-0062): the key primitives of shared spaces (space_keys.dart),
// from spike S-16's cases.
//   account key   opens only with the personal key it was sealed with, and
//                 only for its account
//   member wrap   opens for that member only, in that space only; a fresh
//                 sender key per wrap; a changed byte is refused
//   join at once  the code opens the key; the hash the server keeps does not
//   rotation      the old key opens nothing sealed with the new one, and
//                 cannot even find the records (ids are keyed)
//   codes         26 letters, grouped, as a link; typed or pasted back
import 'dart:math';
import 'dart:typed_data';

import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const space = '20000000-0000-4000-8000-0000000000f1';

void main() {
  test('an account\'s private key opens only with the personal key it was sealed with, for that account', () async {
    final lan = await AccountKeyPair.generate();
    final personal = await newWorkspaceKey();
    final sealed = await sealAccountPrivate(lan, personal, 'lan');
    expect(sealed.first, spaceKeyFormat);
    final onPhone = await openAccountPrivate(sealed, personal, 'lan');
    expect(onPhone.publicKey, lan.publicKey);
    expect(onPhone.seed, lan.seed);
    await expectLater(openAccountPrivate(sealed, await newWorkspaceKey(), 'lan'), throwsA(isA<SealBroken>()),
        reason: 'the personal key was reset');
    await expectLater(openAccountPrivate(sealed, personal, 'minh'), throwsA(isA<SealBroken>()), reason: 'bound to the account');
    await expectLater(openAccountPrivate(Uint8List.fromList([2, ...sealed.sublist(1)]), personal, 'lan'),
        throwsA(isA<SealBroken>()), reason: 'a newer format');
    await expectLater(AccountKeyPair.fromSeed([1, 2, 3]), throwsA(isA<SealBroken>()));
  });

  test('a space key wrapped for one member opens for that member only, in that space only', () async {
    final owner = await AccountKeyPair.generate();
    final lan = await AccountKeyPair.generate();
    final minh = await AccountKeyPair.generate();
    final key = await newWorkspaceKey();
    final forLan = await wrapForMember(key, lan.publicKey, space);
    expect(forLan.length, 1 + 32 + 12 + 32 + 16, reason: '93 bytes (S-16)');
    expect(await (await openForMember(forLan, lan, space)).extractBytes(), await key.extractBytes());
    await expectLater(openForMember(forLan, minh, space), throwsA(isA<SealBroken>()), reason: 'another member');
    await expectLater(openForMember(forLan, owner, space), throwsA(isA<SealBroken>()), reason: 'even the owner');
    await expectLater(openForMember(forLan, lan, '20000000-0000-4000-8000-0000000000f2'), throwsA(isA<SealBroken>()),
        reason: 'moved to another space');
    for (final at in [5, 40, 60, 92]) {
      final changed = Uint8List.fromList(forLan)..[at] ^= 1;
      await expectLater(openForMember(changed, lan, space), throwsA(isA<SealBroken>()), reason: 'byte $at changed');
    }
    await expectLater(openForMember(forLan.sublist(0, 20), lan, space), throwsA(isA<SealBroken>()), reason: 'cut short');
    expect(await wrapForMember(key, lan.publicKey, space), isNot(forLan), reason: 'a fresh sender key per wrap');
    expect(() => wrapForMember(key, [1, 2], space), throwsArgumentError);
  });

  test('join at once: the code opens the key; the hash the server keeps does not', () async {
    final key = await newWorkspaceKey();
    final code = newInvitationCode();
    final wrapped = await wrapForCode(key, code, space);
    expect(await (await openWithCode(wrapped, code, space)).extractBytes(), await key.extractBytes());
    final hash = await invitationHash(code);
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    await expectLater(openWithCode(wrapped, hash, space), throwsA(isA<SealBroken>()), reason: 'the hash is not the code');
    await expectLater(openWithCode(wrapped, newInvitationCode(), space), throwsA(isA<SealBroken>()));
    await expectLater(openWithCode(wrapped, code, '20000000-0000-4000-8000-0000000000f2'), throwsA(isA<SealBroken>()));
  });

  test('rotation: the old key opens nothing sealed with the new one, and cannot find the records', () async {
    final before = await RecordSealer.of(await newWorkspaceKey());
    final now = await RecordSealer.of(await newWorkspaceKey());
    final sid = await now.serverId('task', 't1');
    final sealed = await now.seal(sid, 2, {'kind': 'task', 'id': 't1', 'row': {'title': 'After the removal'}});
    await expectLater(before.open(sid, 2, sealed), throwsA(isA<SealBroken>()));
    expect(await before.serverId('task', 't1'), isNot(sid));
    expect(before.keyId, isNot(now.keyId));
  });

  test('codes: 26 letters without look-alikes, grouped, as a link, and read back from what was typed', () {
    final code = newInvitationCode(Random(7));
    expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{26}$')));
    expect(formatInvitationCode(code), matches(RegExp(r'^([A-Z2-9]{5}-){5}[A-Z2-9]$')));
    expect(invitationLink(code), 'lifeflow://join/$code');
    for (final typed in [
      code,
      code.toLowerCase(),
      formatInvitationCode(code),
      ' ${formatInvitationCode(code).replaceAll('-', ' ')} ',
      invitationLink(code),
      'LIFEFLOW://JOIN/${formatInvitationCode(code)}',
    ]) {
      expect(parseInvitation(typed), code, reason: typed);
    }
    for (final bad in ['', code.substring(1), '${code}A', code.replaceRange(0, 1, 'O'), code.replaceRange(3, 4, '1'),
        'https://example.com/join/$code']) {
      expect(parseInvitation(bad), isNull, reason: bad);
    }
    expect({for (var i = 0; i < 200; i++) newInvitationCode()}.length, 200);
  });

  test('speed: wrapping for 10 members and opening on a member device', () async {
    final members = [for (var i = 0; i < 10; i++) await AccountKeyPair.generate()];
    final key = await newWorkspaceKey();
    final sw = Stopwatch()..start();
    final wraps = [for (final m in members) await wrapForMember(key, m.publicKey, space)];
    for (final (i, m) in members.indexed) {
      await openForMember(wraps[i], m, space);
    }
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });
}
