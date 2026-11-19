// P04 T3 (ADR-0056): the sync engine over real profile stores (copies of one
// workspace, as after joining), end-to-end sealed, with the in-memory server.
//   GS-17     offline changes on every device arrive; a lost answer is
//             retried as the same operations and stored once (SYNC-001)
//   SYNC-002  conflicts found by version; SYNC-003 merged per type: fields
//             both kept, a completion never lost, notes and schedules kept
//             for review, measurements append-only, delete beats edit
//   GS-14     a delete syncs as a tombstone; a purge reaches every device
//   failures  offline and signed out keep everything for the next try; a
//             record the server refuses is set aside and the rest syncs; a
//             page that cannot be applied is not half-applied
//   D10       a change this version cannot read stops the pull there
//   GOV       pulled changes go through the gateway as actor sync, which
//             may do nothing else
//   property  random edits and syncs on three devices converge, with no
//             record and no completion lost
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

class _Time implements DeviceTime {
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}

/// A server that refuses any push containing one of [refuse].
class _Picky implements RemoteGateway {
  _Picky(this.inner, this.refuse);
  final RemoteGateway inner;
  final Set<String> refuse;
  @override
  Future<PushResult> push(String w, String d, List<RecordPush> r, {String keyId = ''}) {
    if (r.any((x) => refuse.contains(x.id))) throw const RemoteFailure(RemoteFailureKind.refused, 'picky');
    return inner.push(w, d, r, keyId: keyId);
  }

  @override
  Future<List<SealedRecord>> pull(String w, int after, {int limit = maxPullPage}) => inner.pull(w, after, limit: limit);
  @override
  Future<int> purge(String w, DateTime before) => inner.purge(w, before);
  @override
  Future<List<RemoteWorkspace>> workspaces() => inner.workspaces();
  @override
  Future<void> createWorkspace(RemoteWorkspace w) => inner.createWorkspace(w);
  @override
  Future<void> updateWrappedKey(String w, Uint8List k, String u, Uint8List? s) => inner.updateWrappedKey(w, k, u, s);
  @override
  Future<void> deleteWorkspace(String w) => inner.deleteWorkspace(w);
}

class Device {
  Device(this.name, this.db, this.remote, this.sealer, this.ws)
      : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)) {
    tasks = DriftTaskService(db, gw);
    overview = DriftOverviewService(db, gw);
    scheduling = DriftTaskScheduling(db, gw);
    habits = DriftHabitService(db, gw, _Time(), deviceId: name);
    engine = SyncEngine(db: db, gateway: gw, remote: remote, sealer: sealer, workspaceId: ws, deviceId: name);
  }
  final String name;
  final AppDatabase db;
  RemoteGateway remote;
  final RecordSealer sealer;
  final String ws;
  final DriftCommandGateway gw;
  late final DriftTaskService tasks;
  late final DriftOverviewService overview;
  late final DriftTaskScheduling scheduling;
  late final DriftHabitService habits;
  late SyncEngine engine;

  void useRemote(RemoteGateway r, {int pageSize = maxPullPage}) {
    remote = r;
    engine = SyncEngine(db: db, gateway: gw, remote: r, sealer: sealer, workspaceId: ws, deviceId: name, pageSize: pageSize);
  }

  Future<SyncReport> sync() => engine.sync();
  Future<Map<String, dynamic>> task(String id) async => (await recordKindByName['task']!.readOne(db, id))!;
  Future<int> cursor() async => (await db.select(db.syncState).getSingle()).cursor;
}

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late MemoryRemoteServer server;
  final open = <AppDatabase>[];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lifeflow_sync_engine_');
    server = MemoryRemoteServer();
  });
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  /// [n] devices of one workspace: device 0 seeds and turns sync on (its
  /// first sync uploads everything), the others are copies that sync next.
  Future<List<Device>> devices(int n, {Future<void> Function(Device d0)? seed}) async {
    final f0 = File('${dir.path}/d0.db');
    final db0 = AppDatabase(NativeDatabase(f0));
    final ws = (await ProfileStore(db0).ensureFirstProfile()).activeWorkspaceId.value;
    final key = await newWorkspaceKey();
    final sealer = await RecordSealer.of(key);
    await MemoryRemoteGateway(server, accountId: 'acc')
        .createWorkspace(RemoteWorkspace(workspaceId: ws, wrappedKey: Uint8List(1), unlockKind: 'recoveryKey'));
    await db0.into(db0.syncState).insert(SyncStateCompanion.insert(workspaceId: ws, deviceId: 'd0'));
    final d0 = Device('d0', db0, MemoryRemoteGateway(server, accountId: 'acc'), sealer, ws);
    if (seed != null) await seed(d0);
    expect((await d0.sync()).outcome, SyncOutcome.upToDate);
    await db0.close();
    final out = <Device>[];
    for (var i = 0; i < n; i++) {
      final f = i == 0 ? f0 : f0.copySync('${dir.path}/d$i.db');
      final db = AppDatabase(NativeDatabase(f));
      open.add(db);
      if (i > 0) {
        await (db.update(db.syncState)..where((s) => s.workspaceId.equals(ws)))
            .write(SyncStateCompanion(deviceId: Value('d$i')));
      }
      out.add(Device('d$i', db, MemoryRemoteGateway(server, accountId: 'acc'), sealer, ws));
    }
    return out;
  }

  Future<void> syncAll(List<Device> ds) async {
    for (var round = 0; round < 3; round++) {
      for (final d in ds) {
        final r = await d.sync();
        expect(r.outcome, SyncOutcome.upToDate, reason: '${d.name}: $r');
      }
    }
  }

  Future<Map<String, Map<String, Map<String, dynamic>>>> snapshot(Device d) async => {
        for (final k in recordKinds)
          k.name: {for (final r in await k.readAll(d.db)) r['id'] as String: r},
      };

  Future<void> expectConverged(List<Device> ds) async {
    final first = await snapshot(ds.first);
    for (final d in ds.skip(1)) {
      expect(await snapshot(d), first, reason: '${d.name} differs from ${ds.first.name}');
    }
    for (final d in ds) {
      final n = (await d.db.customSelect("SELECT count(*) AS n FROM outbox WHERE status = 'pending'").getSingle())
          .read<int>('n');
      expect(n, 0, reason: '${d.name} has unsent changes');
    }
  }

  test('GS-17: offline changes on both devices arrive; a lost answer is retried and stored once', () async {
    final [a, b] = await devices(2);
    final t1 = ok(await a.tasks.create('Call the bank'));
    ok(await a.tasks.rename(t1, 'Call the bank today'));
    final t2 = ok(await b.tasks.create('Buy milk'));
    ok(await b.tasks.setNotes(t2, 'oat'));

    server.loseNextAnswer = true;
    expect((await a.sync()).outcome, SyncOutcome.offline);
    int lastSeq() => server.dump(a.ws).map((x) => x.seq).reduce(max);
    final stored = (server.dump(a.ws).length, lastSeq());
    final r = await a.sync();
    expect((r.outcome, r.merged), (SyncOutcome.upToDate, 0));
    expect((server.dump(a.ws).length, lastSeq()), stored, reason: 'the retry is the same operation, stored once (SYNC-001)');

    await syncAll([a, b]);
    expect((await b.task(t1))['title'], 'Call the bank today');
    expect((await a.task(t2))['notes'], 'oat');
    await expectConverged([a, b]);
  });

  test('the server sees no content: ids are opaque, records are sealed', () async {
    final [a] = await devices(1);
    final t = ok(await a.tasks.create('Call the bank'));
    ok(await a.tasks.setNotes(t, 'account 12-345'));
    await a.sync();
    for (final r in server.dump(a.ws)) {
      expect(r.id, matches(RegExp(r'^[0-9a-f]{64}$')));
      final text = latin1.decode(r.sealed!);
      for (final secret in ['Call the bank', '12-345', t, 'task', 'title', a.ws]) {
        expect(text.contains(secret), isFalse, reason: '"$secret" readable on the server');
      }
    }
  });

  test('SYNC-003: different fields both kept; a completion is never lost; the same field converges', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Report')));
    ok(await a.tasks.rename(t, 'Quarterly report'));
    ok(await b.overview.setTaskColor(t, 4));
    ok(await b.tasks.complete(t, withDescendants: false));
    await syncAll([a, b]);
    final row = await a.task(t);
    expect((row['title'], row['colorIndex'], row['status']), ('Quarterly report', 4, 'done'));
    await expectConverged([a, b]);

    ok(await a.tasks.rename(t, 'From A'));
    ok(await b.tasks.rename(t, 'From B'));
    await syncAll([a, b]);
    expect(['From A', 'From B'], contains((await a.task(t))['title']));
    await expectConverged([a, b]);
  });

  test('notes and schedules changed on both: one kept, the other in Changes to review', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Trip')));
    ok(await a.tasks.setNotes(t, 'Train at 8'));
    ok(await b.tasks.setNotes(t, 'Bus at 9'));
    ok(await a.scheduling.setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 1)))));
    ok(await b.scheduling.setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 3)))));
    await syncAll([a, b]);
    final reviews = [...await a.db.select(a.db.syncReviews).get(), ...await b.db.select(b.db.syncReviews).get()];
    final notes = reviews.where((r) => r.field == 'notes').single;
    expect({(await a.task(t))['notes'], jsonDecode(notes.other)}, {'Train at 8', 'Bus at 9'}, reason: 'no text is lost');
    expect(reviews.where((r) => r.kind == 'schedule' && r.reason == 'changedOnBoth'), hasLength(1));
    await expectConverged([a, b]);
  });

  test('D7: delete beats edit; the edit stays on the item in the trash, with a review', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Old idea')));
    ok(await a.tasks.trash(t));
    ok(await b.tasks.rename(t, 'Old idea, revised'));
    await syncAll([a, b]);
    final row = await a.task(t);
    expect((row['deletedAt'] != null, row['title']), (true, 'Old idea, revised'));
    expect((await b.db.select(b.db.syncReviews).get()).where((r) => r.reason == 'deletedAndEdited'), hasLength(1));
    await expectConverged([a, b]);
  });

  test('measurements are append-only: both devices\' entries count', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async {
      t = ok(await d.tasks.create('Read'));
      ok(await d.habits.setTarget(t, const TargetInput(kind: TargetKind.atLeast, min: 50, unit: 'pages')));
    });
    ok(await a.habits.recordMeasurement(t, 20));
    ok(await b.habits.recordMeasurement(t, 35));
    await syncAll([a, b]);
    expect([for (final m in await recordKindByName['measurement']!.readAll(a.db)) m['value']], unorderedEquals([20.0, 35.0]));
    await expectConverged([a, b]);
  });

  test('GS-14: a delete syncs as a tombstone; a purge after retention reaches every device', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Temporary')));
    ok(await a.tasks.trash(t));
    await syncAll([a, b]);
    expect((await b.task(t))['deletedAt'], isNotNull);
    final sid = await a.sealer.serverId('task', t);
    server.age(a.ws, sid, const Duration(days: 100));
    await syncAll([a, b]);
    for (final d in [a, b]) {
      expect(await recordKindByName['task']!.readOne(d.db, t), isNull, reason: '${d.name} purged it');
      expect(await (d.db.select(d.db.syncBase)..where((x) => x.recordId.equals(t))).get(), isEmpty);
    }
    expect(server.dump(a.ws).singleWhere((r) => r.id == sid).deleted, isTrue, reason: 'the tombstone stays');
  });

  test('offline or signed out: nothing is lost; the next sync sends it', () async {
    final [a, b] = await devices(2);
    final t = ok(await a.tasks.create('Offline task'));
    server.unavailable = true;
    expect((await a.sync()).outcome, SyncOutcome.offline);
    server.unavailable = false;
    final signedOut = MemoryRemoteGateway(server);
    a.useRemote(signedOut);
    expect((await a.sync()).outcome, SyncOutcome.signedOut);
    expect((await a.db.select(a.db.syncState).getSingle()).lastResult, 'signedOut');
    a.useRemote(MemoryRemoteGateway(server, accountId: 'acc'));
    await syncAll([a, b]);
    expect((await b.task(t))['title'], 'Offline task');
  });

  test('a record the server refuses is set aside; the rest still syncs', () async {
    final [a, b] = await devices(2);
    final bad = ok(await a.tasks.create('Refused'));
    final good = ok(await a.tasks.create('Fine'));
    a.useRemote(_Picky(MemoryRemoteGateway(server, accountId: 'acc'), {await a.sealer.serverId('task', bad)}));
    final r = await a.sync();
    expect((r.outcome, r.failedRecords), (SyncOutcome.upToDate, 1));
    final failed = await a.db.customSelect("SELECT entity_id FROM outbox WHERE status = 'failed'").get();
    expect({for (final f in failed) f.read<String>('entity_id')}, {bad});
    await b.sync();
    expect((await b.task(good))['title'], 'Fine');
    expect(await recordKindByName['task']!.readOne(b.db, bad), isNull);
  });

  test('many changes come in pages', () async {
    final [a, b] = await devices(2);
    final ids = [for (var i = 0; i < 25; i++) ok(await a.tasks.create('T$i'))];
    await a.sync();
    b.useRemote(MemoryRemoteGateway(server, accountId: 'acc'), pageSize: 4);
    final r = await b.sync();
    expect((r.outcome, r.pulled), (SyncOutcome.upToDate, 25));
    for (final id in ids) {
      expect(await recordKindByName['task']!.readOne(b.db, id), isNotNull);
    }
    expect(await b.cursor(), server.dump(a.ws).map((x) => x.seq).reduce(max));
  });

  test('D10: a change this version cannot read stops the pull there; the rest waits', () async {
    final [a, b] = await devices(2);
    final first = ok(await a.tasks.create('Before'));
    await a.sync();
    // A newer app version's change: a kind this one does not know.
    final sid = await a.sealer.serverId('newKind', 'x');
    final sealed = await a.sealer.seal(sid, 1, {'kind': 'newKind', 'id': 'x', 'schemaVersion': 99, 'row': {}});
    await MemoryRemoteGateway(server, accountId: 'acc').push(a.ws, 'future', [
      RecordPush(id: sid, base: null, version: 1, deleted: false, sealed: sealed, operationId: 'op-future'),
    ]);
    final after = ok(await a.tasks.create('After'));
    await a.sync();
    final r = await b.sync();
    expect(r.outcome, SyncOutcome.updateNeeded);
    expect(await recordKindByName['task']!.readOne(b.db, first), isNotNull);
    expect(await recordKindByName['task']!.readOne(b.db, after), isNull, reason: 'waits behind the unknown change');
    expect(await b.cursor(), lessThan(server.dump(a.ws).singleWhere((x) => x.id == sid).seq));
  });

  test('a page that cannot be applied is not half-applied, and the cursor stays', () async {
    final [a, b] = await devices(2);
    final t = ok(await a.tasks.create('Good'));
    await a.sync();
    // A sealed record of another workspace (a bug elsewhere): refused whole.
    final row = {...(await a.task(t)), 'id': 'stray', 'workspaceId': 'another'};
    final sid = await a.sealer.serverId('task', 'stray');
    await MemoryRemoteGateway(server, accountId: 'acc').push(a.ws, 'x', [
      RecordPush(
          id: sid, base: null, version: 1, deleted: false, operationId: 'op-stray',
          sealed: await a.sealer.seal(sid, 1, {'kind': 'task', 'id': 'stray', 'schemaVersion': 11, 'row': row})),
    ]);
    final before = await b.cursor();
    expect((await b.sync()).outcome, SyncOutcome.failed);
    expect(await b.cursor(), before);
    expect(await recordKindByName['task']!.readOne(b.db, t), isNull, reason: 'not half of the page');
  });

  test('pulled changes go through the gateway as actor sync, which may do nothing else', () async {
    final [a, b] = await devices(2);
    ok(await a.tasks.create('Audited'));
    await a.sync();
    await b.sync();
    final audit = await (b.db.select(b.db.auditLog)..where((x) => x.action.equals(syncApplyAction))).get();
    expect(audit, isNotEmpty);
    expect(audit.first.actor, ActorRef(ActorKind.sync, 'd1').toString());
    Command as(ActorRef actor, String type, Map<String, Object?> payload) => Command(
        operationId: 'op-${actor.kind.name}-$type', actor: actor, workspaceId: b.ws, type: type, payload: payload,
        issuedAt: Instant.now());
    final other = await b.gw.execute(as(const ActorRef(ActorKind.sync, 'd1'), 'CreateTask', {'op': 'create', 'id': 'x', 'title': 'no'}),
        TaskCommandHandler());
    expect((other as CommandFailure).kind, CommandFailureKind.unauthorized);
    final stranger = await b.gw.execute(
        as(const ActorRef(ActorKind.sync, 'someone-else'), syncApplyAction, {'op': 'apply', 'id': b.ws, 'cursor': 0}),
        const SyncApplyHandler());
    expect((stranger as CommandFailure).kind, CommandFailureKind.unauthorized);
  });

  test('property: random edits and syncs on three devices converge, no record and no completion lost', () async {
    for (var seed = 1; seed <= 8; seed++) {
      final rnd = Random(seed);
      final ds = await devices(3);
      final created = <String>{};
      final completed = <String>{};
      for (var step = 0; step < 40; step++) {
        final d = ds[rnd.nextInt(3)];
        final live = [for (final r in await recordKindByName['task']!.readAll(d.db)) if (r['deletedAt'] == null) r['id'] as String];
        final op = rnd.nextInt(7);
        if (op == 0 || live.isEmpty) {
          created.add(ok(await d.tasks.create('T$step')));
          continue;
        }
        final t = live[rnd.nextInt(live.length)];
        switch (op) {
          case 1:
            await d.tasks.rename(t, 'R$step');
          case 2:
            await d.overview.setTaskColor(t, rnd.nextInt(12));
          case 3:
            await d.tasks.setNotes(t, 'N$step');
          case 4:
            if (await d.tasks.complete(t, withDescendants: false) is CommandOk) completed.add(t);
          case 5:
            await (rnd.nextInt(4) == 0 ? d.tasks.trash(t) : d.tasks.rename(t, 'S$step'));
          default:
            await d.sync();
        }
      }
      await syncAll(ds);
      await expectConverged(ds);
      final rows = {for (final r in await recordKindByName['task']!.readAll(ds.first.db)) r['id']: r};
      expect(rows.keys.toSet().containsAll(created), isTrue, reason: 'seed $seed: a task was lost');
      for (final t in completed) {
        expect(rows[t]!['status'], 'done', reason: 'seed $seed: a completion of $t was lost');
      }
      for (final db in open) {
        await db.close();
      }
      open.clear();
      server = MemoryRemoteServer();
      dir.deleteSync(recursive: true);
      dir = Directory.systemTemp.createTempSync('lifeflow_sync_engine_');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('P05a T4: documents (ADR-0069)', () {
    DriftDocumentService docsOf(Device d) => DriftDocumentService(d.db, d.gw, deviceId: d.name);
    DocumentBody body(String s) => DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun(s)])]);
    Future<List<String>> revisionTexts(Device d, String id) async => [
          for (final r in await DriftDocumentQueries(d.db).revisions(id))
            (await DriftDocumentQueries(d.db).revisionContent(r.id))!.$2.plainText(),
        ];
    Future<String> bodyOf(Device d, String id) async => (await DriftDocumentQueries(d.db).document(id))!.body.plainText();

    test('GS-08 / DOC-005: changed on both offline: both saves are revisions everywhere, one review; "Take the other" syncs',
        () async {
      late String id;
      final [a, b] = await devices(2, seed: (d) async {
        id = ok(await docsOf(d).create('Kế hoạch'));
        ok(await docsOf(d).save(id, title: 'Kế hoạch', body: body('Bản đầu')));
      });
      ok(await docsOf(a).save(id, title: 'Kế hoạch', body: body('Của máy A')));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      ok(await docsOf(b).save(id, title: 'Kế hoạch', body: body('Của máy B')));
      await syncAll([a, b]);
      for (final d in [a, b]) {
        expect(await bodyOf(d, id), 'Của máy B', reason: '${d.name}: the newer save');
        expect(await revisionTexts(d, id), containsAll(['Bản đầu', 'Của máy A', 'Của máy B', '']),
            reason: '${d.name}: no content lost (DOC-005)');
      }
      final items = await b.db.select(b.db.syncReviews).get();
      expect([for (final i in items) (i.kind, i.recordId, i.field)], [('document', id, 'body')]);
      expect(await a.db.select(a.db.syncReviews).get(), isEmpty);
      final view = await syncReviewViewOf(b.db, items.single);
      expect({view.kept, view.other}, {'Của máy A', 'Của máy B'}, reason: 'shown as text, not as the stored form');

      final take = await b.gw.execute(
          Command(
              operationId: 'op-take',
              actor: ActorRef(ActorKind.owner, (await ProfileStore(b.db).getActiveProfile())!.profileId.value),
              workspaceId: b.ws,
              type: resolveSyncReviewAction,
              payload: {'op': 'resolve', 'id': items.single.id, 'take': 'other'},
              issuedAt: Instant.now()),
          const SyncReviewHandler());
      expect(take, isA<CommandOk>(), reason: '$take');
      await syncAll([a, b]);
      for (final d in [a, b]) {
        expect(await bodyOf(d, id), 'Của máy A', reason: '${d.name}: taken back everywhere');
        final h = await DriftDocumentQueries(d.db).revisions(id);
        expect(h.first.reason, RevisionReason.conflict, reason: '${d.name}: the change taken back is a revision too');
      }
      // Revisions are the same facts on both devices, byte for byte.
      Future<List<String>> rows(Device d) async =>
          [for (final r in await recordKindByName['documentRevision']!.readAll(d.db)) jsonEncode({...r}..remove('updatedAt'))]
            ..sort();
      expect(await rows(a), await rows(b));
    });

    test('a title changed on one device and the body on the other: both kept, nothing to review', () async {
      late String id;
      final [a, b] = await devices(2, seed: (d) async => id = ok(await docsOf(d).create('Cũ')));
      ok(await docsOf(a).rename(id, 'Mới'));
      ok(await docsOf(b).save(id, title: 'Cũ', body: body('Nội dung')));
      await syncAll([a, b]);
      for (final d in [a, b]) {
        final v = (await DriftDocumentQueries(d.db).document(id))!;
        expect((v.title, v.body.plainText()), ('Mới', 'Nội dung'), reason: d.name);
        expect(await d.db.select(d.db.syncReviews).get(), isEmpty);
      }
    });

    test('two moves that merge into a loop: both documents still shown, in the same order on every device', () async {
      late String x, y;
      final [a, b] = await devices(2, seed: (d) async {
        x = ok(await docsOf(d).create('X'));
        y = ok(await docsOf(d).create('Y'));
      });
      ok(await docsOf(a).move(x, parentId: y));
      ok(await docsOf(b).move(y, parentId: x));
      await syncAll([a, b]);
      final trees = [for (final d in [a, b]) [for (final n in await DriftDocumentQueries(d.db).watchTree().first) n.id]];
      expect(trees[0], unorderedEquals([x, y]));
      expect(trees[1], trees[0]);
    });
  });
}
