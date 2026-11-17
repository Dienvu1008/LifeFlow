// P04b T9 (ADR-0061): one contract for shared spaces on the sync server, run
// against the in-memory server (always) and against a local Supabase (when
// LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY are set;
// CI's supabase-db job does), so the two cannot drift apart.
//   keys        published, sealed again, seen only by people in a space
//   spaces      listed with the role, the key wrapped for the member and the
//               rules; never listed as a personal workspace
//   invitations "approve" (preview, accept, wait, approve) and "join at
//               once" (the key from the code, then forgotten); a code once
//   roles       viewers read and do not write (SHARE-002); owner-only
//               actions refused to others (SHARE-003); hand over
//   rules       set by the owner, seen by members with when they changed
//   removal     no access at once; a new key for exactly the active members
//   limits      10 members a space (counting those waiting), 10 spaces an
//               account (B13)
//   deletion    the space and everything in it goes
// The server-side cases one by one are in pgTAP (spaces.test.sql).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:http/http.dart' as http;
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

/// A gateway that is both ports (the implementations are).
abstract interface class Server implements RemoteGateway, SpaceGateway {}

class _Both implements Server {
  _Both(this.r, this.s);
  final RemoteGateway r;
  final SpaceGateway s;
  @override
  Future<List<RemoteWorkspace>> workspaces() => r.workspaces();
  @override
  Future<void> createWorkspace(RemoteWorkspace w) => r.createWorkspace(w);
  @override
  Future<void> updateWrappedKey(String w, Uint8List k, String u, Uint8List? salt) => r.updateWrappedKey(w, k, u, salt);
  @override
  Future<void> deleteWorkspace(String w) => r.deleteWorkspace(w);
  @override
  Future<PushResult> push(String w, String d, List<RecordPush> x) => r.push(w, d, x);
  @override
  Future<List<SealedRecord>> pull(String w, int after, {int limit = maxPullPage}) => r.pull(w, after, limit: limit);
  @override
  Future<int> purge(String w, DateTime before) => r.purge(w, before);
  @override
  Future<AccountKeys?> myKeys() => s.myKeys();
  @override
  Future<void> setMyKeys(AccountKeys keys) => s.setMyKeys(keys);
  @override
  Future<Map<String, Uint8List>> publicKeys(List<String> ids) => s.publicKeys(ids);
  @override
  Future<List<RemoteSpace>> spaces() => s.spaces();
  @override
  Future<void> createSpace(String w, Uint8List k, String id) => s.createSpace(w, k, id);
  @override
  Future<void> deleteSpace(String w) => s.deleteSpace(w);
  @override
  Future<List<RemoteMember>> members(String w) => s.members(w);
  @override
  Future<List<RemoteInvitation>> invitations(String w) => s.invitations(w);
  @override
  Future<void> invite(String w, String h, SpaceRole role, InviteKind kind,
          {Uint8List? wrappedKey, String keyId = '', int days = 7}) =>
      s.invite(w, h, role, kind, wrappedKey: wrappedKey, keyId: keyId, days: days);
  @override
  Future<void> cancelInvitation(String h) => s.cancelInvitation(h);
  @override
  Future<InvitationPreview> peekInvitation(String h) => s.peekInvitation(h);
  @override
  Future<AcceptedInvitation> acceptInvitation(String h) => s.acceptInvitation(h);
  @override
  Future<void> approveMember(String w, String a, Uint8List k, String id) => s.approveMember(w, a, k, id);
  @override
  Future<void> setMyWrappedKey(String w, Uint8List k, String id) => s.setMyWrappedKey(w, k, id);
  @override
  Future<void> removeMember(String w, String a) => s.removeMember(w, a);
  @override
  Future<void> leaveSpace(String w) => s.leaveSpace(w);
  @override
  Future<void> setRole(String w, String a, SpaceRole role) => s.setRole(w, a, role);
  @override
  Future<void> handOver(String w, String a) => s.handOver(w, a);
  @override
  Future<void> setRules(String w, SpaceRules rules) => s.setRules(w, rules);
  @override
  Future<void> rotateKey(String w, String id, Map<String, Uint8List> wraps) => s.rotateKey(w, id, wraps);
}

/// Accounts by role in the cases: 0 owner, 1 editor, 2 viewer, 3 waits for
/// approval, 4 joins at once, 5 a stranger without published keys, 6..11
/// fill a space, 12 makes many spaces.
const owner = 0, editor = 1, viewer = 2, waiting = 3, atOnce = 4, stranger = 5, many = 12;
const accountCount = 13;

typedef Accounts = ({List<Server> as, List<String> ids, Server signedOut});

final _rnd = Random();
String hex64() => [for (var i = 0; i < 32; i++) _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
final keyA = 'a' * 64, keyB = 'b' * 64;
Uint8List b(List<int> x) => Uint8List.fromList(x);
Uint8List publicKeyOf(int n) => b(List.filled(32, n + 1));

RecordPush rec(String rid) =>
    RecordPush(id: rid, base: null, version: 1, deleted: false, sealed: b(utf8.encode('sealed')), operationId: const Uuid().v4());

Future<void> expectFailure(Future<Object?> f, RemoteFailureKind kind) =>
    expectLater(f, throwsA(isA<RemoteFailure>().having((e) => e.kind, 'kind', kind)));

Future<void> expectRefusal(Future<Object?> f, SpaceRefusal reason) =>
    expectLater(f, throwsA(isA<SpaceFailure>().having((e) => e.reason, 'reason', reason)));

void contract(String name, Future<Accounts> Function() open) {
  group(name, () {
    late Accounts acc;
    late String ws;
    late int ownerNow;
    Server g(int n) => acc.as[n];
    String idOf(int n) => acc.ids[n];

    setUpAll(() async {
      acc = await open();
      for (var n = 0; n < accountCount; n++) {
        if (n != stranger) await g(n).setMyKeys(AccountKeys(publicKey: publicKeyOf(n), sealedPrivate: b([0x5e, n])));
      }
    });

    setUp(() async {
      ws = const Uuid().v4();
      ownerNow = owner;
      await g(owner).createSpace(ws, b([1, 0]), keyA);
    });

    tearDown(() async {
      try {
        await g(ownerNow).deleteSpace(ws);
      } on RemoteFailure {
        // The case deleted it already.
      }
    });

    /// [who] joins through an "approve" invitation, approved by the owner.
    Future<void> join(int who, {SpaceRole role = SpaceRole.editor}) async {
      final h = hex64();
      await g(ownerNow).invite(ws, h, role, InviteKind.approve);
      await g(who).acceptInvitation(h);
      await g(ownerNow).approveMember(ws, idOf(who), b([2, who]), keyA);
    }

    RemoteSpace? spaceOf(List<RemoteSpace> list) => list.where((s) => s.workspaceId == ws).firstOrNull;

    test('keys: published, sealed again, and seen only by people in a space with you', () async {
      final mine = (await g(owner).myKeys())!;
      expect([mine.publicKey, mine.sealedPrivate], [publicKeyOf(owner), [0x5e, owner]]);
      await g(owner).setMyKeys(AccountKeys(publicKey: publicKeyOf(owner), sealedPrivate: b([0x5e, 0x02])));
      expect((await g(owner).myKeys())!.sealedPrivate, [0x5e, 0x02], reason: 'sealed again after a reset');
      await g(owner).setMyKeys(AccountKeys(publicKey: publicKeyOf(owner), sealedPrivate: b([0x5e, owner])));
      expect(await g(stranger).myKeys(), isNull);
      await expectFailure(g(owner).setMyKeys(AccountKeys(publicKey: b([1]), sealedPrivate: b([1]))), RemoteFailureKind.refused);

      expect((await g(editor).publicKeys([idOf(owner), idOf(editor)])).keys, [idOf(editor)],
          reason: 'not yet in a space together');
      final h = hex64();
      await g(owner).invite(ws, h, SpaceRole.editor, InviteKind.approve);
      await g(editor).acceptInvitation(h);
      expect(await g(editor).publicKeys([idOf(owner)]), isEmpty, reason: 'waiting is not being in');
      expect(await g(owner).publicKeys([idOf(editor)]), {idOf(editor): publicKeyOf(editor)},
          reason: 'the owner wraps the key for someone waiting');
      await g(owner).approveMember(ws, idOf(editor), b([2]), keyA);
      expect((await g(editor).publicKeys([idOf(owner), idOf(editor), idOf(viewer)])).keys.toSet(),
          {idOf(owner), idOf(editor)});
      expect(await g(viewer).publicKeys([idOf(owner)]), isEmpty);
    });

    test('a space is listed with its role, key and rules, and never as a personal workspace', () async {
      final s = spaceOf(await g(owner).spaces())!;
      expect([s.role, s.status, s.wrappedKey, s.keyId, s.rules], [SpaceRole.owner, MemberStatus.active, [1, 0], keyA, const SpaceRules()]);
      expect(s.rulesChangedAt, isNotNull);
      expect((await g(owner).workspaces()).where((w) => w.workspaceId == ws), isEmpty);
      await expectFailure(g(owner).updateWrappedKey(ws, b([9]), 'recoveryKey', null), RemoteFailureKind.notYours);
      await expectFailure(g(owner).createSpace(ws, b([1]), keyA), RemoteFailureKind.refused);
      await expectRefusal(g(stranger).createSpace(const Uuid().v4(), b([1]), keyA), SpaceRefusal.noPublicKey);
      expect(spaceOf(await g(editor).spaces()), isNull);
    });

    test('"approve": the invitee sees the rules first, waits, and is let in by the owner; a code works once', () async {
      final h = hex64();
      await g(owner).invite(ws, h, SpaceRole.editor, InviteKind.approve);
      expect([for (final i in await g(owner).invitations(ws)) (i.codeHash, i.role, i.kind)],
          [(h, SpaceRole.editor, InviteKind.approve)]);
      expect(await g(editor).invitations(ws), isEmpty);
      final p = await g(editor).peekInvitation(h);
      expect((p.workspaceId, p.role, p.kind, p.leave, p.export),
          (ws, SpaceRole.editor, InviteKind.approve, LeaveRule.disappear, ExportRule.ownerOnly));
      await expectRefusal(g(editor).peekInvitation(hex64()), SpaceRefusal.noSuchInvitation);

      final a = await g(editor).acceptInvitation(h);
      expect((a.preview.kind, a.wrappedKey), (InviteKind.approve, null));
      final waitingRow = spaceOf(await g(editor).spaces())!;
      expect((waitingRow.status, waitingRow.rules, waitingRow.wrappedKey), (MemberStatus.pending, null, null));
      await expectFailure(g(editor).push(ws, 'e', [rec(hex64())]), RemoteFailureKind.notYours);
      expect(await g(editor).pull(ws, 0), isEmpty);
      await expectRefusal(g(editor).acceptInvitation(h), SpaceRefusal.noSuchInvitation);
      await expectRefusal(g(viewer).acceptInvitation(h), SpaceRefusal.noSuchInvitation);
      expect(await g(owner).invitations(ws), isEmpty, reason: 'a used invitation is no longer open');

      await expectFailure(g(editor).approveMember(ws, idOf(editor), b([2]), keyA), RemoteFailureKind.notYours);
      await expectRefusal(g(owner).approveMember(ws, idOf(editor), b([2]), keyB), SpaceRefusal.staleKey);
      await expectRefusal(g(owner).approveMember(ws, idOf(viewer), b([2]), keyA), SpaceRefusal.nobodyWaiting);
      await g(owner).approveMember(ws, idOf(editor), b([2, 1]), keyA);
      final in_ = spaceOf(await g(editor).spaces())!;
      expect([in_.role, in_.status, in_.wrappedKey, in_.keyId, in_.rules],
          [SpaceRole.editor, MemberStatus.active, [2, 1], keyA, const SpaceRules()]);
      expect([for (final m in await g(owner).members(ws)) (m.accountId, m.role, m.status)],
          [(idOf(owner), SpaceRole.owner, MemberStatus.active), (idOf(editor), SpaceRole.editor, MemberStatus.active)]);
      expect(await g(stranger).members(ws), isEmpty);

      final x = hex64(), y = hex64();
      await g(owner).push(ws, 'o', [rec(x)]);
      expect([for (final r in await g(editor).pull(ws, 0)) r.id], [x]);
      await g(editor).push(ws, 'e', [rec(y)]);
      expect([for (final r in await g(owner).pull(ws, 0)) (r.id, r.seq)], [(x, 1), (y, 2)]);
    });

    test('an invitation can be cancelled, by the owner only', () async {
      final h = hex64();
      await g(owner).invite(ws, h, SpaceRole.viewer, InviteKind.approve, days: 1);
      final week = hex64();
      await g(owner).invite(ws, week, SpaceRole.viewer, InviteKind.approve);
      final ends = {for (final i in await g(owner).invitations(ws)) i.codeHash: i.expiresAt};
      expect(ends[week]!.difference(ends[h]!).inHours, inInclusiveRange(143, 145), reason: '7 days against 1');
      await g(owner).cancelInvitation(week);
      await expectFailure(g(editor).cancelInvitation(h), RemoteFailureKind.notYours);
      await g(owner).cancelInvitation(h);
      await expectRefusal(g(viewer).acceptInvitation(h), SpaceRefusal.noSuchInvitation);
      await expectRefusal(g(owner).cancelInvitation(h), SpaceRefusal.noSuchInvitation);
      await expectFailure(g(owner).invite(ws, hex64(), SpaceRole.editor, InviteKind.approve, days: 8), RemoteFailureKind.refused);
      await expectFailure(g(owner).invite(ws, hex64(), SpaceRole.owner, InviteKind.approve), RemoteFailureKind.refused);
    });

    test('"join at once": in at once with the key the code carried, which the server then forgets', () async {
      await expectFailure(g(owner).invite(ws, hex64(), SpaceRole.viewer, InviteKind.joinAtOnce), RemoteFailureKind.refused);
      final h = hex64();
      await g(owner).invite(ws, h, SpaceRole.viewer, InviteKind.joinAtOnce, wrappedKey: b([9, 9]), keyId: keyA);
      final a = await g(atOnce).acceptInvitation(h);
      expect([a.preview.role, a.preview.kind, a.wrappedKey, a.keyId], [SpaceRole.viewer, InviteKind.joinAtOnce, [9, 9], keyA]);
      final s = spaceOf(await g(atOnce).spaces())!;
      expect([s.role, s.status, s.wrappedKey], [SpaceRole.viewer, MemberStatus.active, [9, 9]]);
      await g(atOnce).setMyWrappedKey(ws, b([5]), keyA);
      expect(spaceOf(await g(atOnce).spaces())!.wrappedKey, [5]);
      await expectFailure(g(atOnce).setMyWrappedKey(ws, b([5]), keyB), RemoteFailureKind.notYours);
      await expectFailure(g(stranger).setMyWrappedKey(ws, b([5]), keyA), RemoteFailureKind.notYours);

      await g(owner).push(ws, 'o', [rec(hex64())]);
      expect(await g(atOnce).pull(ws, 0), hasLength(1), reason: 'a viewer reads');
      await expectFailure(g(atOnce).push(ws, 'j', [rec(hex64())]), RemoteFailureKind.notYours);
      await expectFailure(g(atOnce).purge(ws, DateTime.now()), RemoteFailureKind.notYours);
    });

    test('owner-only actions are refused to others; roles change; the owner hands over', () async {
      await join(editor);
      await join(viewer, role: SpaceRole.viewer);
      final e = g(editor);
      await expectFailure(e.invite(ws, hex64(), SpaceRole.editor, InviteKind.approve), RemoteFailureKind.notYours);
      await expectFailure(e.removeMember(ws, idOf(viewer)), RemoteFailureKind.notYours);
      await expectFailure(e.setRole(ws, idOf(viewer), SpaceRole.editor), RemoteFailureKind.notYours);
      await expectFailure(e.setRules(ws, const SpaceRules(export: ExportRule.everyMember)), RemoteFailureKind.notYours);
      await expectFailure(e.rotateKey(ws, keyB, {}), RemoteFailureKind.notYours);
      await expectFailure(e.handOver(ws, idOf(editor)), RemoteFailureKind.notYours);
      await expectFailure(e.deleteSpace(ws), RemoteFailureKind.notYours);
      expect(await e.invitations(ws), isEmpty);

      await expectFailure(g(viewer).push(ws, 'v', [rec(hex64())]), RemoteFailureKind.notYours);
      await g(owner).setRole(ws, idOf(viewer), SpaceRole.editor);
      await g(viewer).push(ws, 'v', [rec(hex64())]);
      await expectFailure(g(owner).setRole(ws, idOf(viewer), SpaceRole.owner), RemoteFailureKind.refused);
      await expectRefusal(g(owner).setRole(ws, idOf(stranger), SpaceRole.viewer), SpaceRefusal.notAMember);

      await expectRefusal(g(owner).leaveSpace(ws), SpaceRefusal.ownerMustHandOver);
      await expectRefusal(g(owner).handOver(ws, idOf(stranger)), SpaceRefusal.notAMember);
      await g(owner).handOver(ws, idOf(editor));
      ownerNow = editor;
      expect(spaceOf(await g(editor).spaces())!.role, SpaceRole.owner);
      expect(spaceOf(await g(owner).spaces())!.role, SpaceRole.editor);
      await expectFailure(g(owner).removeMember(ws, idOf(viewer)), RemoteFailureKind.notYours);
      await g(owner).push(ws, 'o', [rec(hex64())]);
      await g(editor).removeMember(ws, idOf(viewer));
      expect([for (final m in await g(editor).members(ws)) (m.accountId, m.role)],
          [(idOf(owner), SpaceRole.editor), (idOf(editor), SpaceRole.owner)]);
    });

    test('rules: the owner sets them; members see them and when they changed; the same rules are no change', () async {
      await join(editor);
      final before = spaceOf(await g(editor).spaces())!.rulesChangedAt!;
      await g(owner).setRules(ws, const SpaceRules());
      expect(spaceOf(await g(editor).spaces())!.rulesChangedAt, before);
      const rules = SpaceRules(leave: LeaveRule.keepReadOnly, export: ExportRule.everyMember, inviteDefault: InviteKind.joinAtOnce);
      await g(owner).setRules(ws, rules);
      final after = spaceOf(await g(editor).spaces())!;
      expect(after.rules, rules);
      expect(after.rulesChangedAt!.isAfter(before), isTrue);
      final h = hex64();
      await g(owner).invite(ws, h, SpaceRole.viewer, InviteKind.approve);
      final p = await g(viewer).peekInvitation(h);
      expect((p.leave, p.export), (LeaveRule.keepReadOnly, ExportRule.everyMember), reason: 'shown before joining (SHARE-005)');
    });

    test('removal: no access at once; the new key goes to exactly the active members', () async {
      await join(editor);
      await join(viewer, role: SpaceRole.viewer);
      final hj = hex64();
      await g(owner).invite(ws, hj, SpaceRole.editor, InviteKind.joinAtOnce, wrappedKey: b([7]), keyId: keyA);
      await g(atOnce).acceptInvitation(hj);
      final hp = hex64();
      await g(owner).invite(ws, hp, SpaceRole.editor, InviteKind.approve);
      await g(waiting).acceptInvitation(hp);
      await g(owner).push(ws, 'o', [rec(hex64())]);

      await g(owner).removeMember(ws, idOf(editor));
      expect(await g(editor).pull(ws, 0), isEmpty);
      await expectFailure(g(editor).push(ws, 'e', [rec(hex64())]), RemoteFailureKind.notYours);
      expect(spaceOf(await g(editor).spaces()), isNull);
      await expectRefusal(g(owner).removeMember(ws, idOf(owner)), SpaceRefusal.notAMember);
      await expectRefusal(g(owner).removeMember(ws, idOf(editor)), SpaceRefusal.notAMember);

      final old = hex64();
      await g(owner).invite(ws, old, SpaceRole.editor, InviteKind.joinAtOnce, wrappedKey: b([7]), keyId: keyA);
      await expectRefusal(g(owner).rotateKey(ws, keyB, {idOf(owner): b([3])}), SpaceRefusal.wrongMembers);
      await expectRefusal(
          g(owner).rotateKey(ws, keyB, {for (final n in [owner, viewer, atOnce, editor]) idOf(n): b([3])}),
          SpaceRefusal.wrongMembers);
      await g(owner).rotateKey(ws, keyB, {for (final n in [owner, viewer, atOnce]) idOf(n): b([3, n])});
      for (final n in [owner, viewer, atOnce]) {
        final s = spaceOf(await g(n).spaces())!;
        expect([s.keyId, s.wrappedKey], [keyB, [3, n]], reason: 'account $n holds the new key');
      }
      await expectRefusal(g(stranger).peekInvitation(old), SpaceRefusal.noSuchInvitation);
      await expectFailure(g(atOnce).setMyWrappedKey(ws, b([5]), keyA), RemoteFailureKind.notYours);
      await expectRefusal(g(owner).approveMember(ws, idOf(waiting), b([4]), keyA), SpaceRefusal.staleKey);
      await g(owner).approveMember(ws, idOf(waiting), b([4]), keyB);
      expect(spaceOf(await g(waiting).spaces())!.status, MemberStatus.active);

      await g(viewer).leaveSpace(ws);
      expect(await g(viewer).pull(ws, 0), isEmpty);
      await expectRefusal(g(viewer).leaveSpace(ws), SpaceRefusal.notAMember);
      final hw = hex64();
      await g(owner).invite(ws, hw, SpaceRole.viewer, InviteKind.approve);
      await g(6).acceptInvitation(hw);
      await g(6).leaveSpace(ws);
      expect(spaceOf(await g(6).spaces()), isNull, reason: 'a request to join is withdrawn');
    });

    test('limits: 10 members a space, counting those waiting; 10 spaces an account (B13)', () async {
      await join(editor);
      final again = hex64();
      await g(owner).invite(ws, again, SpaceRole.viewer, InviteKind.approve);
      await expectRefusal(g(editor).acceptInvitation(again), SpaceRefusal.alreadyMember);
      for (final n in [viewer, waiting, atOnce, 6, 7, 8, 9, 10]) {
        final h = hex64();
        await g(owner).invite(ws, h, SpaceRole.viewer, InviteKind.approve);
        await g(n).acceptInvitation(h);
      }
      expect(await g(owner).members(ws), hasLength(maxSpaceMembers));
      final h = hex64();
      await g(owner).invite(ws, h, SpaceRole.viewer, InviteKind.approve);
      await expectRefusal(g(11).acceptInvitation(h), SpaceRefusal.spaceFull);
      await expectRefusal(g(stranger).acceptInvitation(h), SpaceRefusal.noPublicKey);

      final made = [for (var i = 0; i < maxSpacesPerAccount; i++) const Uuid().v4()];
      try {
        for (final w in made) {
          await g(many).createSpace(w, b([1]), keyA);
        }
        await expectRefusal(g(many).createSpace(const Uuid().v4(), b([1]), keyA), SpaceRefusal.tooManySpaces);
        final hm = hex64();
        await g(owner).removeMember(ws, idOf(10));
        await g(owner).invite(ws, hm, SpaceRole.viewer, InviteKind.approve);
        await expectRefusal(g(many).acceptInvitation(hm), SpaceRefusal.tooManySpaces);
      } finally {
        for (final w in made) {
          try {
            await g(many).deleteSpace(w);
          } on RemoteFailure {
            // Not made.
          }
        }
      }
    });

    test('a stranger reaches nothing; deleting the space deletes everything in it', () async {
      await join(editor);
      await g(owner).push(ws, 'o', [rec(hex64())]);
      await g(owner).invite(ws, hex64(), SpaceRole.viewer, InviteKind.approve);
      final s = g(stranger);
      expect(await s.pull(ws, 0), isEmpty);
      expect(spaceOf(await s.spaces()), isNull);
      expect(await s.members(ws), isEmpty);
      expect(await s.invitations(ws), isEmpty);
      await expectFailure(s.push(ws, 's', [rec(hex64())]), RemoteFailureKind.notYours);
      await expectFailure(s.purge(ws, DateTime.now()), RemoteFailureKind.notYours);
      await expectFailure(s.deleteSpace(ws), RemoteFailureKind.notYours);
      await expectFailure(s.removeMember(ws, idOf(editor)), RemoteFailureKind.notYours);
      await expectFailure(acc.signedOut.spaces(), RemoteFailureKind.signedOut);
      await expectFailure(acc.signedOut.peekInvitation(hex64()), RemoteFailureKind.signedOut);

      await g(owner).deleteSpace(ws);
      for (final n in [owner, editor]) {
        expect(spaceOf(await g(n).spaces()), isNull);
        expect(await g(n).pull(ws, 0), isEmpty);
        expect(await g(n).members(ws), isEmpty);
      }
      expect(await g(owner).invitations(ws), isEmpty);
      await expectFailure(g(owner).deleteSpace(ws), RemoteFailureKind.notYours);
    });

    test('a personal workspace is not a space: deleteSpace does not delete it', () async {
      final personal = const Uuid().v4();
      await g(many).createWorkspace(RemoteWorkspace(workspaceId: personal, wrappedKey: b([1]), unlockKind: 'recoveryKey'));
      try {
        await expectFailure(g(many).deleteSpace(personal), RemoteFailureKind.notYours);
        expect((await g(many).workspaces()).map((w) => w.workspaceId), contains(personal));
        await g(many).push(personal, 'pc', [rec(hex64())]);
        expect(await g(many).pull(personal, 0), hasLength(1));
      } finally {
        await g(many).deleteWorkspace(personal);
      }
    });
  });
}

void main() {
  contract('in memory', () async {
    // A clock that moves on at each look, so "changed later" is never a tie.
    var now = DateTime.utc(2026, 11, 17);
    final server = MemoryRemoteServer(clock: () => now = now.add(const Duration(seconds: 1)));
    final ids = [for (var i = 0; i < accountCount; i++) const Uuid().v4()];
    Server gw(String? a) {
      final m = MemoryRemoteGateway(server, accountId: a);
      return _Both(m, m);
    }

    return (as: [for (final a in ids) gw(a)], ids: ids, signedOut: gw(null));
  });

  test('in memory: an invitation expires after its days', () async {
    var now = DateTime.utc(2026, 11, 17);
    final server = MemoryRemoteServer(clock: () => now);
    final o = MemoryRemoteGateway(server, accountId: const Uuid().v4());
    final e = MemoryRemoteGateway(server, accountId: const Uuid().v4());
    for (final x in [o, e]) {
      await x.setMyKeys(AccountKeys(publicKey: publicKeyOf(1), sealedPrivate: b([1])));
    }
    final ws = const Uuid().v4();
    await o.createSpace(ws, b([1]), keyA);
    final h = hex64();
    await o.invite(ws, h, SpaceRole.editor, InviteKind.approve, days: 2);
    now = now.add(const Duration(days: 2));
    await expectRefusal(e.peekInvitation(h), SpaceRefusal.noSuchInvitation);
    await expectRefusal(e.acceptInvitation(h), SpaceRefusal.noSuchInvitation);
    expect(await o.invitations(ws), isEmpty);
  });

  final url = Platform.environment['LIFEFLOW_TEST_SUPABASE_URL'];
  final anon = Platform.environment['LIFEFLOW_TEST_SUPABASE_ANON_KEY'];
  if (url == null || anon == null) {
    test('local Supabase', () {}, skip: 'set LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY');
    return;
  }
  final client = http.Client();
  tearDownAll(client.close);

  /// A new account on the local stack: its access token and id.
  Future<(String, String)> signUp() async {
    final res = await client.post(Uri.parse('$url/auth/v1/signup'),
        headers: {'apikey': anon, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': 'space-${const Uuid().v4()}@example.test', 'password': 'correct horse battery staple'}));
    if (res.statusCode != 200) throw StateError('sign-up failed: ${res.statusCode} ${res.body}');
    final body = jsonDecode(res.body) as Map;
    return (body['access_token'] as String, (body['user'] as Map)['id'] as String);
  }

  Server gateway(String? token) {
    final h = HttpRemoteGateway(baseUrl: url, anonKey: anon, accessToken: () async => token, client: client);
    return _Both(h, h);
  }

  contract('local Supabase', () async {
    final accounts = [for (var i = 0; i < accountCount; i++) await signUp()];
    return (
      as: [for (final (t, _) in accounts) gateway(t)],
      ids: [for (final (_, id) in accounts) id],
      signedOut: gateway(null),
    );
  });
}
