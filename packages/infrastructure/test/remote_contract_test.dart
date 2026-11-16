// P04 T2 (ADR-0055): one contract for the sync server, run against the
// in-memory server (always) and against a local Supabase (when
// LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY are set;
// CI's supabase-db job does), so the two cannot drift apart.
//   workspaces  created, listed with the wrapped key, re-wrapped, deleted
//               with all their records ("Delete my data from the server")
//   isolation   another account sees, pushes, re-wraps and deletes nothing
//   push        change numbers in order; a replay accepted once; a stale
//               base is a conflict naming the server's version
//   refused     a version that does not go up, a readable id, a batch over
//               500, an unknown unlock kind, a workspace id taken
//   pull        in order, after a cursor, in pages; sealed bytes intact
//   purge       nothing within the 90-day retention; afterwards the content
//               goes and the tombstone stays (memory; the SQL is in pgTAP)
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:http/http.dart' as http;
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

typedef Accounts = ({RemoteGateway a, RemoteGateway b, RemoteGateway signedOut});

final _rnd = Random();
String id(int n) => n.toRadixString(16).padLeft(64, '0');
String randomId() => [for (var i = 0; i < 32; i++) _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

RecordPush rec(String rid, {int? base, int version = 1, bool deleted = false, String? op, String body = 'sealed'}) =>
    RecordPush(
      id: rid,
      base: base,
      version: version,
      deleted: deleted,
      sealed: bytes(body),
      operationId: op ?? const Uuid().v4(),
    );

Future<void> expectFailure(Future<Object?> f, RemoteFailureKind kind) =>
    expectLater(f, throwsA(isA<RemoteFailure>().having((e) => e.kind, 'kind', kind)));

void contract(String name, Future<Accounts> Function() open) {
  group(name, () {
    late Accounts acc;
    late String ws;
    setUp(() async {
      acc = await open();
      ws = const Uuid().v4();
      await acc.a.createWorkspace(RemoteWorkspace(
          workspaceId: ws, wrappedKey: Uint8List.fromList([1, 2, 3, 250]), unlockKind: 'passphrase',
          unlockSalt: Uint8List.fromList(List.filled(16, 7)), keyId: id(77)));
    });

    test('a workspace is listed with its wrapped key; re-wrapping changes only the key', () async {
      final w = (await acc.a.workspaces()).singleWhere((w) => w.workspaceId == ws);
      expect([w.wrappedKey, w.unlockKind, w.unlockSalt, w.lastSeq], [[1, 2, 3, 250], 'passphrase', List.filled(16, 7), 0]);
      await acc.a.updateWrappedKey(ws, Uint8List.fromList([1, 9]), 'recoveryKey', null);
      final again = (await acc.a.workspaces()).singleWhere((w) => w.workspaceId == ws);
      expect([again.wrappedKey, again.unlockKind, again.unlockSalt], [[1, 9], 'recoveryKey', null]);
      expect((w.keyId, again.keyId), (id(77), id(77)), reason: 're-wrapping keeps the key id');
      await expectFailure(
          acc.a.createWorkspace(RemoteWorkspace(
              workspaceId: const Uuid().v4(), wrappedKey: Uint8List(1), unlockKind: 'recoveryKey', keyId: 'not hex')),
          RemoteFailureKind.refused);
      await expectFailure(acc.a.updateWrappedKey(ws, Uint8List.fromList([1]), 'pin', null), RemoteFailureKind.refused);
    });

    test('push gives change numbers in order; pull returns them after a cursor, in pages, intact', () async {
      final ids = [for (var i = 0; i < 5; i++) randomId()];
      final r = await acc.a.push(ws, 'pc', [for (final (i, x) in ids.indexed) rec(x, body: 'body $i')]);
      expect(r.conflicts, isEmpty);
      expect([for (final x in ids) r.accepted[x]], [1, 2, 3, 4, 5]);
      final all = await acc.a.pull(ws, 0);
      expect([for (final s in all) s.id], ids);
      expect(utf8.decode(all[3].sealed!), 'body 3');
      expect((all.first.version, all.first.deleted, all.first.deviceId), (1, false, 'pc'));
      expect([for (final s in await acc.a.pull(ws, 3)) s.seq], [4, 5]);
      expect([for (final s in await acc.a.pull(ws, 0, limit: 2)) s.seq], [1, 2]);
      expect((await acc.a.workspaces()).singleWhere((w) => w.workspaceId == ws).lastSeq, 5);
    });

    test('T6 finding: a record of real size (several KB of any bytes) comes back exactly', () async {
      final x = randomId();
      final big = Uint8List.fromList([for (var i = 0; i < 5000; i++) _rnd.nextInt(256)]);
      await acc.a.push(ws, 'pc', [
        RecordPush(id: x, base: null, version: 1, deleted: false, sealed: big, operationId: const Uuid().v4())
      ]);
      expect((await acc.a.pull(ws, 0)).single.sealed, big);
    });

    test('a replay is accepted once; a stale base is a conflict naming the server\'s version', () async {
      final x = randomId();
      final first = rec(x, op: const Uuid().v4());
      expect((await acc.a.push(ws, 'pc', [first])).accepted[x], 1);
      expect((await acc.a.push(ws, 'pc', [first])).accepted[x], 1, reason: 'replay (SYNC-001)');
      final stale = await acc.a.push(ws, 'phone', [rec(x)]);
      expect(stale.accepted, isEmpty);
      expect(stale.conflicts, {x: 1}, reason: 'new over existing');
      expect((await acc.a.push(ws, 'phone', [rec(x, base: 1, version: 2)])).accepted[x], 2);
      expect((await acc.a.push(ws, 'pc', [rec(x, base: 1, version: 2)])).conflicts[x], 2, reason: 'by version (SYNC-002)');
      final y = randomId();
      expect((await acc.a.push(ws, 'pc', [rec(y, base: 3, version: 4)])).conflicts, {y: null}, reason: 'not on the server');
      expect([for (final s in await acc.a.pull(ws, 0)) (s.id, s.version)], [(x, 2)]);
    });

    test('malformed pushes are refused and change nothing', () async {
      final x = randomId();
      await expectFailure(acc.a.push(ws, 'pc', [rec(x, version: 0)]), RemoteFailureKind.refused);
      await expectFailure(acc.a.push(ws, 'pc', [rec('task-1')]), RemoteFailureKind.refused);
      await expectFailure(acc.a.push(ws, 'pc', [for (var i = 0; i < 501; i++) rec(id(i + 1))]), RemoteFailureKind.refused);
      expect(await acc.a.pull(ws, 0), isEmpty);
      await acc.a.push(ws, 'pc', [rec(x)]);
      // One bad record refuses the whole batch: the good one is not written.
      await expectFailure(acc.a.push(ws, 'pc', [rec(randomId()), rec(x, base: 1, version: 1)]), RemoteFailureKind.refused);
      expect([for (final s in await acc.a.pull(ws, 0)) s.id], [x], reason: 'a refused batch writes nothing');
    });

    test('another account sees and changes nothing of the workspace', () async {
      final x = randomId();
      await acc.a.push(ws, 'pc', [rec(x)]);
      expect((await acc.b.workspaces()).where((w) => w.workspaceId == ws), isEmpty);
      expect(await acc.b.pull(ws, 0), isEmpty);
      await expectFailure(acc.b.push(ws, 'b', [rec(randomId())]), RemoteFailureKind.notYours);
      await expectFailure(acc.b.updateWrappedKey(ws, Uint8List.fromList([1]), 'recoveryKey', null), RemoteFailureKind.notYours);
      await expectFailure(acc.b.deleteWorkspace(ws), RemoteFailureKind.notYours);
      await expectFailure(acc.b.purge(ws, DateTime.now()), RemoteFailureKind.notYours);
      await expectFailure(
          acc.b.createWorkspace(RemoteWorkspace(workspaceId: ws, wrappedKey: Uint8List.fromList([1]), unlockKind: 'recoveryKey')),
          RemoteFailureKind.refused);
      expect((await acc.a.pull(ws, 0)).single.id, x, reason: 'A\'s data is untouched');
      expect((await acc.a.workspaces()).singleWhere((w) => w.workspaceId == ws).wrappedKey, [1, 2, 3, 250]);
    });

    test('without a session nothing is reachable', () async {
      await expectFailure(acc.signedOut.workspaces(), RemoteFailureKind.signedOut);
      await expectFailure(acc.signedOut.push(ws, 'x', [rec(randomId())]), RemoteFailureKind.signedOut);
      await expectFailure(acc.signedOut.pull(ws, 0), RemoteFailureKind.signedOut);
    });

    test('a delete is a tombstone; nothing is purged within the retention', () async {
      final x = randomId();
      await acc.a.push(ws, 'pc', [rec(x)]);
      await acc.a.push(ws, 'pc', [rec(x, base: 1, version: 2, deleted: true)]);
      expect(await acc.a.purge(ws, DateTime.now().add(const Duration(days: 1))), 0);
      final s = (await acc.a.pull(ws, 0)).single;
      expect((s.deleted, s.sealed != null, s.seq), (true, true, 2));
    });

    test('deleting the workspace deletes its records', () async {
      await acc.a.push(ws, 'pc', [rec(randomId()), rec(randomId())]);
      await acc.a.deleteWorkspace(ws);
      expect((await acc.a.workspaces()).where((w) => w.workspaceId == ws), isEmpty);
      expect(await acc.a.pull(ws, 0), isEmpty);
      await expectFailure(acc.a.push(ws, 'pc', [rec(randomId())]), RemoteFailureKind.notYours);
    });
  });
}

void main() {
  late MemoryRemoteServer server;
  contract('in memory', () async {
    server = MemoryRemoteServer();
    return (
      a: MemoryRemoteGateway(server, accountId: 'account-a') as RemoteGateway,
      b: MemoryRemoteGateway(server, accountId: 'account-b') as RemoteGateway,
      signedOut: MemoryRemoteGateway(server) as RemoteGateway,
    );
  });

  test('in memory: after the retention a purge drops the content and keeps the tombstone (GS-14)', () async {
    var now = DateTime.utc(2026, 11, 14);
    final s = MemoryRemoteServer(clock: () => now);
    final a = MemoryRemoteGateway(s, accountId: 'a');
    const ws = 'w';
    await a.createWorkspace(RemoteWorkspace(workspaceId: ws, wrappedKey: Uint8List(1), unlockKind: 'recoveryKey'));
    final x = id(1), y = id(2);
    await a.push(ws, 'pc', [rec(x), rec(y)]);
    await a.push(ws, 'pc', [rec(x, base: 1, version: 2, deleted: true), rec(y, base: 1, version: 2, deleted: true)]);
    now = now.add(const Duration(days: 80));
    expect(await a.purge(ws, now), 0, reason: 'within 90 days');
    s.age(ws, x, const Duration(days: 20));
    expect(await a.purge(ws, now), 1);
    final pulled = {for (final r in await a.pull(ws, 4)) r.id: r};
    expect((pulled[x]!.sealed, pulled[x]!.deleted, pulled[x]!.seq), (null, true, 5));
    expect(pulled.containsKey(y), isFalse);
    s.unavailable = true;
    await expectFailure(a.pull(ws, 0), RemoteFailureKind.unavailable);
  });

  final url = Platform.environment['LIFEFLOW_TEST_SUPABASE_URL'];
  final anon = Platform.environment['LIFEFLOW_TEST_SUPABASE_ANON_KEY'];
  if (url == null || anon == null) {
    test('local Supabase', () {}, skip: 'set LIFEFLOW_TEST_SUPABASE_URL and LIFEFLOW_TEST_SUPABASE_ANON_KEY');
    return;
  }
  final client = http.Client();
  tearDownAll(client.close);

  /// A new account on the local stack (email sign-up confirms at once there).
  Future<String> signUp() async {
    final res = await client.post(Uri.parse('$url/auth/v1/signup'),
        headers: {'apikey': anon, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': 'sync-${const Uuid().v4()}@example.test', 'password': 'correct horse battery staple'}));
    if (res.statusCode != 200) throw StateError('sign-up failed: ${res.statusCode}');
    return (jsonDecode(res.body) as Map)['access_token'] as String;
  }

  RemoteGateway gateway(String? token) =>
      HttpRemoteGateway(baseUrl: url, anonKey: anon, accessToken: () async => token, client: client);

  contract('local Supabase', () async {
    final a = await signUp();
    final b = await signUp();
    return (a: gateway(a), b: gateway(b), signedOut: gateway(null));
  });

  test('local Supabase: an expired or forged token counts as signed out', () async {
    await expectFailure(gateway('not-a-token').workspaces(), RemoteFailureKind.signedOut);
  });
}
