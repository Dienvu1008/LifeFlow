// P04b T10 (ADR-0062): the keys of shared spaces on devices, end to end on
// the in-memory server (the server's side is in remote_spaces_contract_test
// and pgTAP). Each device has its own secure storage; each account its
// personal workspace key.
//   account keys  published, opened on another device, sealed again after a
//                 reset of the personal key, replaced only when lost
//   approve       only a member opens the space; the account's other
//                 devices too; someone waiting has no key
//   join at once  the key from the code, wrapped again for the account
//                 (and wrapped again when that did not reach the server)
//   rotation      after a removal the removed member opens nothing sealed
//                 afterwards (SHARE-004); old-key pushes are refused; the old
//                 rows and the old key go when the rotation is finished
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:cryptography/cryptography.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'profile_harness.dart';

/// One device of an account.
class Device {
  Device(MemoryRemoteServer server, this.account, this.personal)
      : remote = MemoryRemoteGateway(server, accountId: account) {
    keyring = WorkspaceKeyring(slots.call);
    keys = SpaceKeyService(server: remote, keyring: keyring, slots: slots.call);
  }
  final String account;
  SecretKey personal;
  final MemoryRemoteGateway remote;
  final slots = MemoryKeys();
  late final WorkspaceKeyring keyring;
  late final SpaceKeyService keys;

  Future<AccountKeysOutcome> start() => keys.ensureAccountKeys(account, personal);
  Future<RemoteSpace> space(String id) async => (await remote.spaces()).singleWhere((s) => s.workspaceId == id);
  Future<SecretKey> open(String id) async => keys.openSpaceKey(account, await space(id));
}

Future<List<int>> bytes(SecretKey k) => k.extractBytes();

void main() {
  late MemoryRemoteServer server;
  late String ws;
  Future<Device> device(String account, [SecretKey? personal]) async =>
      Device(server, account, personal ?? await newWorkspaceKey());

  setUp(() {
    server = MemoryRemoteServer();
    ws = const Uuid().v4();
  });

  test('account keys: published once, opened on another device, sealed again after a reset, replaced only when lost',
      () async {
    final pc = await device('lan');
    expect(await pc.start(), AccountKeysOutcome.published);
    final published = (await pc.remote.myKeys())!.publicKey;
    expect((await pc.keys.accountKeyPair('lan'))!.publicKey, published);
    expect(await pc.start(), AccountKeysOutcome.opened, reason: 'again: nothing changes');

    final phone = await device('lan', pc.personal);
    expect(await phone.keys.accountKeyPair('lan'), isNull);
    expect(await phone.start(), AccountKeysOutcome.opened);
    expect((await phone.keys.accountKeyPair('lan'))!.seed, (await pc.keys.accountKeyPair('lan'))!.seed);

    // The personal key is reset on the PC (P04a's reset): the same pair,
    // sealed with the new key, so the phone opens it with the new key.
    pc.personal = await newWorkspaceKey();
    expect(await pc.start(), AccountKeysOutcome.resealed);
    expect((await pc.remote.myKeys())!.publicKey, published);
    final tablet = await device('lan', pc.personal);
    expect(await tablet.start(), AccountKeysOutcome.opened);
    expect((await tablet.keys.accountKeyPair('lan'))!.publicKey, published);

    // A device with neither the pair nor the personal key it was sealed with.
    final lost = await device('lan');
    expect(await lost.start(), AccountKeysOutcome.replaced);
    expect((await lost.remote.myKeys())!.publicKey, isNot(published));
  });

  test('"approve": only members open the space, on every device of their account; someone waiting has no key', () async {
    final owner = await device('owner');
    final lan = await device('lan');
    final stranger = await device('stranger');
    for (final d in [owner, lan, stranger]) {
      await d.start();
    }
    final keyId = await owner.keys.createSpace('owner', ws);
    final key = (await owner.keyring.keyOf(ws))!;
    expect((await RecordSealer.of(key)).keyId, keyId);
    expect(await bytes(await owner.open(ws)), await bytes(key), reason: 'the owner opens what was wrapped for them');

    final invitation = await owner.keys.invite(ws, SpaceRole.editor, InviteKind.approve);
    expect(parseInvitation(invitation.link), invitation.code);
    final preview = await lan.keys.peek(invitation.code);
    expect((preview.workspaceId, preview.role, preview.leave), (ws, SpaceRole.editor, LeaveRule.disappear));
    final accepted = await lan.keys.accept('lan', invitation.code);
    expect((accepted.preview.kind, accepted.wrappedKey), (InviteKind.approve, null));
    await expectLater(lan.open(ws),
        throwsA(isA<SpaceKeyException>().having((e) => e.problem, 'problem', SpaceKeyProblem.waiting)));
    expect(await lan.keyring.keyOf(ws), isNull);

    await owner.keys.approve(ws, 'lan');
    expect(await bytes(await lan.open(ws)), await bytes(key));
    final lanPhone = await device('lan', lan.personal);
    await lanPhone.start();
    expect(await bytes(await lanPhone.open(ws)), await bytes(key), reason: 'the account\'s other device opens it');

    final forLan = (await lan.space(ws)).wrappedKey!;
    await expectLater(openForMember(forLan, (await stranger.keys.accountKeyPair('stranger'))!, ws),
        throwsA(isA<SealBroken>()), reason: 'a wrapping for Lan opens for nobody else');
    await expectLater(stranger.keys.approve(ws, 'lan'),
        throwsA(isA<SpaceKeyException>().having((e) => e.problem, 'problem', SpaceKeyProblem.noSpaceKey)));
  });

  test('"join at once": the key comes with the code, is checked, and is wrapped again for the account', () async {
    final owner = await device('owner');
    final jo = await device('jo');
    await owner.start();
    await jo.start();
    await owner.keys.createSpace('owner', ws);
    final key = (await owner.keyring.keyOf(ws))!;
    final invitation = await owner.keys.invite(ws, SpaceRole.viewer, InviteKind.joinAtOnce);
    // Typed back grouped and in small letters.
    final typed = parseInvitation(invitation.grouped.toLowerCase())!;
    final accepted = await jo.keys.accept('jo', typed);
    expect(accepted.preview.kind, InviteKind.joinAtOnce);
    expect(await bytes((await jo.keyring.keyOf(ws))!), await bytes(key));
    final mine = (await jo.space(ws)).wrappedKey!;
    expect(await bytes(await openForMember(mine, (await jo.keys.accountKeyPair('jo'))!, ws)), await bytes(key),
        reason: 'the server now holds the key wrapped for Jo\'s account, not for the code');
    final joPhone = await device('jo', jo.personal);
    await joPhone.start();
    expect(await bytes(await joPhone.open(ws)), await bytes(key));
  });

  test('a device holding the key wraps it again for its account when the server\'s wrapping does not open', () async {
    final owner = await device('owner');
    final jo = await device('jo');
    final other = await device('other');
    for (final d in [owner, jo, other]) {
      await d.start();
    }
    await owner.keys.createSpace('owner', ws);
    final key = (await owner.keyring.keyOf(ws))!;
    final invitation = await owner.keys.invite(ws, SpaceRole.editor, InviteKind.joinAtOnce);
    await jo.keys.accept('jo', invitation.code);
    // As if Jo's re-wrap had not reached the server: a wrapping Jo cannot open.
    final keyId = (await RecordSealer.of(key)).keyId;
    await jo.remote.setMyWrappedKey(ws, await wrapForMember(key, (await other.keys.accountKeyPair('other'))!.publicKey, ws), keyId);
    final joPhone = await device('jo', jo.personal);
    await joPhone.start();
    await expectLater(joPhone.open(ws), throwsA(isA<SealBroken>()));
    expect(await bytes(await jo.open(ws)), await bytes(key), reason: 'the device with the key repairs the wrapping');
    expect(await bytes(await joPhone.open(ws)), await bytes(key));
  });

  test('a published public key that is not the sealed private key\'s is not taken as the account\'s', () async {
    final pc = await device('lan');
    await pc.start();
    final real = (await pc.remote.myKeys())!;
    final other = await AccountKeyPair.generate();
    // The server says another public key next to the real sealed private key.
    await pc.remote.setMyKeys(AccountKeys(publicKey: other.publicKey, sealedPrivate: real.sealedPrivate));
    final phone = await device('lan', pc.personal);
    expect(await phone.start(), isNot(AccountKeysOutcome.opened));
    final kept = (await phone.keys.accountKeyPair('lan'))!;
    expect(kept.publicKey, (await phone.remote.myKeys())!.publicKey, reason: 'the device holds the pair it published');
  });

  test('"join at once" with a key that is not the one the invitation names: refused, nothing kept', () async {
    final owner = await device('owner');
    final jo = await device('jo');
    await owner.start();
    await jo.start();
    await owner.keys.createSpace('owner', ws);
    final key = (await owner.keyring.keyOf(ws))!;
    final code = newInvitationCode();
    await owner.remote.invite(ws, await invitationHash(code), SpaceRole.editor, InviteKind.joinAtOnce,
        wrappedKey: await wrapForCode(key, code, ws), keyId: 'f' * 64);
    await expectLater(jo.keys.accept('jo', code),
        throwsA(isA<SpaceKeyException>().having((e) => e.problem, 'problem', SpaceKeyProblem.keyMismatch)));
    expect(await jo.keyring.keyOf(ws), isNull);
  });

  test('a key that does not match the id the server names is not used', () async {
    final owner = await device('owner');
    await owner.start();
    await owner.keys.createSpace('owner', ws);
    final real = await owner.space(ws);
    final fresh = await device('owner', owner.personal);
    await fresh.start();
    final lie = RemoteSpace(
        workspaceId: ws, role: real.role, status: real.status, wrappedKey: real.wrappedKey, keyId: 'f' * 64);
    await expectLater(fresh.keys.openSpaceKey('owner', lie),
        throwsA(isA<SpaceKeyException>().having((e) => e.problem, 'problem', SpaceKeyProblem.keyMismatch)));
    expect(await fresh.keyring.keyOf(ws), isNull);
  });

  test('rotation: a removed member opens nothing sealed afterwards (SHARE-004); old rows and the old key go at the end',
      () async {
    final owner = await device('owner');
    final ed = await device('ed');
    final vi = await device('vi');
    for (final d in [owner, ed, vi]) {
      await d.start();
    }
    await owner.keys.createSpace('owner', ws);
    for (final (d, role) in [(ed, SpaceRole.editor), (vi, SpaceRole.viewer)]) {
      final inv = await owner.keys.invite(ws, role, InviteKind.approve);
      await d.keys.accept(d.account, inv.code);
      await owner.keys.approve(ws, d.account);
      await d.open(ws);
    }
    final oldKey = (await owner.keyring.keyOf(ws))!;
    final oldSealer = await RecordSealer.of(oldKey);
    final before = await oldSealer.serverId('task', 't0');
    await ed.remote.push(ws, 'ed', [
      RecordPush(id: before, base: null, version: 1, deleted: false,
          sealed: await oldSealer.seal(before, 1, {'title': 'before'}), operationId: const Uuid().v4())
    ], keyId: oldSealer.keyId);

    await owner.remote.removeMember(ws, 'vi');
    final newKeyId = await owner.keys.rotate(ws);
    expect(newKeyId, isNot(oldSealer.keyId));
    expect(await bytes((await owner.keyring.previousKeyOf(ws))!), await bytes(oldKey),
        reason: 'the old key stays until the records are sealed again');

    final edKey = await ed.open(ws);
    final edSealer = await RecordSealer.of(edKey);
    expect(edSealer.keyId, newKeyId);
    expect(await bytes((await ed.keyring.previousKeyOf(ws))!), await bytes(oldKey));

    await expectLater(
        ed.remote.push(ws, 'ed', [
          RecordPush(id: await oldSealer.serverId('task', 't1'), base: null, version: 1, deleted: false,
              sealed: await oldSealer.seal(await oldSealer.serverId('task', 't1'), 1, {'title': 'late'}),
              operationId: const Uuid().v4())
        ], keyId: oldSealer.keyId),
        throwsA(isA<SpaceFailure>().having((e) => e.reason, 'reason', SpaceRefusal.staleKey)));
    final after = await edSealer.serverId('task', 't1');
    final sealedAfter = await edSealer.seal(after, 1, {'title': 'after the removal'});
    await ed.remote.push(ws, 'ed',
        [RecordPush(id: after, base: null, version: 1, deleted: false, sealed: sealedAfter, operationId: const Uuid().v4())],
        keyId: newKeyId);

    // The removed viewer: no access, and the key they had opens nothing new.
    expect(await vi.remote.pull(ws, 0), isEmpty);
    final viKey = (await vi.keyring.keyOf(ws))!;
    expect(await bytes(viKey), await bytes(oldKey));
    await expectLater((await RecordSealer.of(viKey)).open(after, 1, sealedAfter), throwsA(isA<SealBroken>()));
    await expectLater(vi.open(ws), throwsA(anything), reason: 'no wrapping for them any more');

    expect([for (final r in await ed.remote.pull(ws, 0)) r.keyId], [oldSealer.keyId, newKeyId]);
    await expectLater(ed.keys.finishRotation(ws), throwsA(isA<RemoteFailure>()), reason: 'the owner finishes it');
    expect(await owner.keys.finishRotation(ws), 1);
    expect([for (final r in await ed.remote.pull(ws, 0)) r.id], [after]);
    expect(await owner.keyring.previousKeyOf(ws), isNull);
  });

  test('a rotation needs every active member\'s public key', () async {
    final owner = await device('owner');
    final ed = await device('ed');
    await owner.start();
    await ed.start();
    await owner.keys.createSpace('owner', ws);
    final inv = await owner.keys.invite(ws, SpaceRole.editor, InviteKind.approve);
    await ed.keys.accept('ed', inv.code);
    await owner.keys.approve(ws, 'ed');
    final keyId = (await owner.space(ws)).keyId;
    // As if Ed's public key were not visible (the server's policy hides it).
    final blind = SpaceKeyService(server: _NoKeysOf(owner.remote, 'ed'), keyring: owner.keyring, slots: owner.slots.call);
    await expectLater(blind.rotate(ws),
        throwsA(isA<SpaceKeyException>().having((e) => e.problem, 'problem', SpaceKeyProblem.noMemberKey)));
    expect((await owner.space(ws)).keyId, keyId, reason: 'nothing rotated');
  });

  test('without the account\'s keys on this device nothing is made or joined', () async {
    final owner = await device('owner');
    await expectLater(owner.keys.createSpace('owner', ws),
        throwsA(isA<SpaceKeyException>().having((e) => e.problem, 'problem', SpaceKeyProblem.noAccountKey)));
    expect(await owner.remote.spaces(), isEmpty);
  });
}

/// The server, except that one account's public key is not visible.
class _NoKeysOf implements SpaceGateway {
  _NoKeysOf(this.inner, this.hidden);
  final MemoryRemoteGateway inner;
  final String hidden;
  @override
  Future<Map<String, Uint8List>> publicKeys(List<String> ids) async =>
      {...await inner.publicKeys(ids)}..remove(hidden);
  @override
  dynamic noSuchMethod(Invocation i) => Function.apply(
      switch (i.memberName) {
        #members => inner.members,
        #rotateKey => inner.rotateKey,
        _ => throw UnimplementedError('${i.memberName}'),
      },
      i.positionalArguments,
      i.namedArguments);
}
