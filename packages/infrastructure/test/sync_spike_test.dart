// P04 spike S-04 (p04-plan.md): can outbox/inbox sync reconcile deliberate
// offline conflicts per type without data loss? Two or three real profile
// stores of one workspace (copies of one file, as after joining), a fake
// server with the semantics of the S-03 SQL functions, and the prototype
// engine in test/sync_spike/.
//   GS-17     offline changes survive sync; a lost answer is retried as the
//             same operations (LF-INV-SYNC-001, OUTBOX-001)
//   SYNC-002  a conflict is found by version, never by time
//   SYNC-003  per type (ADR-0015, D6/D7): task fields merge; a completion is
//             never lost; notes and schedules keep the other value for
//             review; measurements are append-only; delete beats edit and
//             the edit stays in the trash
//   GS-14     a tombstone syncs; a purge after retention reaches every device
//   property  random edits and syncs on three devices always converge, lose
//             no record and no completion
import 'dart:io';
import 'dart:math';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'sync_spike/fake_server.dart';
import 'sync_spike/replica.dart';
import 'sync_spike/resolve.dart';

class _Time implements DeviceTime {
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}

/// One device: its store, its services and its sync side.
class Device {
  Device(this.replica)
      : gw = DriftCommandGateway(replica.db, WorkspaceOwnerAuthorization(replica.db)) {
    tasks = DriftTaskService(replica.db, gw);
    overview = DriftOverviewService(replica.db, gw);
    scheduling = DriftTaskScheduling(replica.db, gw);
    habits = DriftHabitService(replica.db, gw, _Time(), deviceId: replica.name);
  }
  final Replica replica;
  final DriftCommandGateway gw;
  late final DriftTaskService tasks;
  late final DriftOverviewService overview;
  late final DriftTaskScheduling scheduling;
  late final DriftHabitService habits;
  AppDatabase get db => replica.db;
  Future<void> sync() => replica.sync();

  Future<Row> task(String id) async =>
      (await recordKindByName['task']!.readAll(db)).firstWhere((r) => r['id'] == id);
}

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

void main() {
  // Several devices' stores in one test, on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late FakeServer server;
  final open = <AppDatabase>[];

  /// [n] devices of one workspace: copies of one store, synced once.
  Future<List<Device>> devices(int n, {Future<void> Function(Device first)? seed}) async {
    final first = File('${dir.path}/d0.db');
    final db0 = AppDatabase(NativeDatabase(first));
    await ProfileStore(db0).ensureFirstProfile();
    final d0 = Device(Replica('d0', db0, server));
    if (seed != null) await seed(d0);
    await d0.sync();
    await db0.close();
    final out = <Device>[];
    for (var i = 0; i < n; i++) {
      final f = i == 0 ? first : first.copySync('${dir.path}/d$i.db');
      final db = AppDatabase(NativeDatabase(f));
      open.add(db);
      final r = Replica('d$i', db, server);
      // A joined device starts from the synced state: same base and cursor.
      r.base.addAll(d0.replica.base);
      r.cursor = d0.replica.cursor;
      out.add(Device(r));
    }
    return out;
  }

  Future<void> syncAll(List<Device> ds) async {
    for (var round = 0; round < 3; round++) {
      for (final d in ds) {
        await d.sync();
      }
    }
  }

  Future<void> expectConverged(List<Device> ds) async {
    final first = await ds.first.replica.snapshot();
    for (final d in ds.skip(1)) {
      expect(await d.replica.snapshot(), first, reason: '${d.replica.name} differs from d0');
      expect(await d.replica.pendingOutbox(), 0, reason: '${d.replica.name} has unsent changes');
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lifeflow_sync_spike_');
    server = FakeServer();
  });
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  test('GS-17: offline changes on both devices all arrive; a lost answer is retried once', () async {
    final [a, b] = await devices(2);
    final t1 = ok(await a.tasks.create('Call the bank'));
    ok(await a.tasks.rename(t1, 'Call the bank today'));
    final t2 = ok(await b.tasks.create('Buy milk'));
    ok(await b.tasks.setNotes(t2, 'oat'));

    server.loseNextAnswer = true;
    await expectLater(a.replica.push(), throwsStateError);
    final stored = server.lastSeq;
    await a.sync(); // the retry is the same operation: accepted, not stored again
    expect(server.lastSeq, stored, reason: 'a replay gives out no new change number (SYNC-001)');
    expect(a.replica.conflictsSeen, 0);

    server.failNextPush = true;
    await expectLater(b.replica.push(), throwsStateError);
    await syncAll([a, b]);
    expect((await b.task(t1))['title'], 'Call the bank today');
    expect((await a.task(t2))['notes'], 'oat');
    await expectConverged([a, b]);
  });

  test('SYNC-003: different fields of one task both survive; the same field converges on one value', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Report')));
    ok(await a.tasks.rename(t, 'Quarterly report'));
    ok(await b.overview.setTaskColor(t, 4));
    await syncAll([a, b]);
    expect(((await a.task(t))['title'], (await a.task(t))['colorIndex']), ('Quarterly report', 4));
    expect(a.replica.conflictsSeen + b.replica.conflictsSeen, 1, reason: 'found by version (SYNC-002)');
    await expectConverged([a, b]);

    ok(await a.tasks.rename(t, 'From A'));
    ok(await b.tasks.rename(t, 'From B'));
    await syncAll([a, b]);
    expect(['From A', 'From B'], contains((await a.task(t))['title']));
    await expectConverged([a, b]);
  });

  test('a completion is never lost to a concurrent edit', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Pay rent')));
    ok(await a.tasks.complete(t, withDescendants: false));
    ok(await b.tasks.rename(t, 'Pay the rent'));
    ok(await b.tasks.setNotes(t, 'by transfer'));
    await syncAll([b, a]);
    final row = await a.task(t);
    expect((row['status'], row['title'], row['notes']), ('done', 'Pay the rent', 'by transfer'));
    await expectConverged([a, b]);
  });

  test('notes changed on both devices: one is kept, the other is kept for review', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Trip')));
    ok(await a.tasks.setNotes(t, 'Train at 8'));
    ok(await b.tasks.setNotes(t, 'Bus at 9'));
    await a.sync();
    await b.sync(); // b merges
    await syncAll([a, b]);
    final kept = (await a.task(t))['notes'];
    final reviews = [...a.replica.reviews, ...b.replica.reviews].where((r) => r.field == 'notes');
    expect(reviews, hasLength(1));
    expect({kept, reviews.single.other}, {'Train at 8', 'Bus at 9'}, reason: 'no text is lost');
    await expectConverged([a, b]);
  });

  test('D7: delete beats edit; the edit stays on the item in the trash, with a review', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Old idea')));
    ok(await a.tasks.trash(t));
    ok(await b.tasks.rename(t, 'Old idea, revised'));
    await a.sync();
    await b.sync();
    await syncAll([a, b]);
    final row = await a.task(t);
    expect(row['deletedAt'], isNotNull);
    expect(row['title'], 'Old idea, revised');
    expect(b.replica.reviews.where((r) => r.field == 'deletedAt'), hasLength(1));
    await expectConverged([a, b]);
  });

  test('a schedule is one value: the newer one wins and the other is kept for review', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Dentist')));
    ok(await a.scheduling.setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 1)))));
    ok(await b.scheduling.setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 3)))));
    await a.sync();
    await b.sync();
    await syncAll([a, b]);
    final schedules = await recordKindByName['schedule']!.readAll(a.db);
    expect(schedules, hasLength(1));
    expect(b.replica.reviews.where((r) => r.kind == 'schedule'), hasLength(1));
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
    final values = [for (final m in await recordKindByName['measurement']!.readAll(a.db)) m['value']];
    expect(values, unorderedEquals([20.0, 35.0]));
    expect(a.replica.conflictsSeen + b.replica.conflictsSeen, 0, reason: 'new rows never conflict');
    await expectConverged([a, b]);
  });

  test('pure rules: an occurrence ticked on one device and unticked on the other stays done; status never goes down', () {
    final base = {'id': 'task:t@2026-11-09', 'version': 1, 'updatedAt': 1, 'deletedAt': null, 'deletedBy': null, 'taskId': 't'};
    final done = {...base, 'version': 2, 'updatedAt': 5};
    final undone = {...base, 'version': 2, 'updatedAt': 9, 'deletedAt': 9, 'deletedBy': 'x'};
    for (final (l, r) in [(done, undone), (undone, done)]) {
      final res = resolve('completion', base, l, r, localDevice: 'a', remoteDevice: 'b');
      expect(res.row['deletedAt'], isNull);
      expect(res.row['version'], 3);
    }
    final t0 = {'id': 't', 'version': 1, 'updatedAt': 1, 'deletedAt': null, 'deletedBy': null, 'status': 'todo', 'title': 'x'};
    final res = resolve('task', t0, {...t0, 'version': 2, 'updatedAt': 2, 'status': 'done'},
        {...t0, 'version': 2, 'updatedAt': 9, 'status': 'inProgress'},
        localDevice: 'a', remoteDevice: 'b');
    expect(res.row['status'], 'done');
  });

  test('GS-14: a delete syncs as a tombstone; a purge after retention reaches every device', () async {
    late String t;
    final [a, b] = await devices(2, seed: (d) async => t = ok(await d.tasks.create('Temporary')));
    ok(await a.tasks.trash(t));
    await syncAll([a, b]);
    expect((await b.task(t))['deletedAt'], isNotNull, reason: 'the tombstone arrived');
    expect(server.purge(DateTime.now().add(const Duration(seconds: 1))), greaterThan(0));
    await syncAll([a, b]);
    for (final d in [a, b]) {
      expect((await recordKindByName['task']!.readAll(d.db)).where((r) => r['id'] == t), isEmpty,
          reason: '${d.replica.name} purged it');
    }
    expect(server.records[opaqueId('task', t)]!.deleted, isTrue, reason: 'the tombstone stays on the server');
  });

  test('finding for T1: which record kinds change without an outbox row of their own', () async {
    final [a] = await devices(1);
    final before = await a.replica.snapshot();
    final t = ok(await a.tasks.create('Write'));
    ok(await a.tasks.setNotes(t, 'draft'));
    ok(await a.habits.setTarget(t, const TargetInput(kind: TargetKind.atLeast, min: 1, unit: 'pages')));
    ok(await a.habits.recordMeasurement(t, 2));
    ok(await a.scheduling.setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 1)))));
    final focus = DriftFocusService(a.db, a.gw);
    final s = ok(await focus.start(mode: FocusSessionMode.stopwatch, taskId: t));
    ok(await focus.end(s, count: true));
    final after = await a.replica.snapshot();
    final outboxed = {
      for (final r in await a.db.customSelect('SELECT entity_type, entity_id FROM outbox').get())
        '${r.read<String>('entity_type')}|${r.read<String>('entity_id')}'
    };
    final missing = [
      for (final kind in after.keys)
        for (final id in after[kind]!.keys)
          if (before[kind]![id] == null || before[kind]![id]!['version'] != after[kind]![id]!['version'])
            if (!outboxed.contains('$kind|$id')) kind,
    ];
    // Spike S-04 found the execution record of an ended session without an
    // outbox row of its own; P04 T1 fixed it (ADR-0053).
    expect(missing, isEmpty);
  });

  test('property: random edits and syncs on three devices converge, with no record and no completion lost',
      () async {
    for (var seedNo = 1; seedNo <= 12; seedNo++) {
      final rnd = Random(seedNo);
      final ds = await devices(3);
      final created = <String>{};
      final completed = <String>{};
      for (var step = 0; step < 40; step++) {
        final d = ds[rnd.nextInt(3)];
        final live = [for (final r in await recordKindByName['task']!.readAll(d.db)) if (r['deletedAt'] == null) r['id'] as String];
        final op = rnd.nextInt(7);
        if (op == 0 || live.isEmpty) {
          created.add(ok(await d.tasks.create('T$step')));
        } else {
          final t = live[rnd.nextInt(live.length)];
          final r = switch (op) {
            1 => await d.tasks.rename(t, 'R$step'),
            2 => await d.overview.setTaskColor(t, rnd.nextInt(12)),
            3 => await d.tasks.setNotes(t, 'N$step'),
            4 => await d.tasks.complete(t, withDescendants: false),
            5 => rnd.nextInt(4) == 0 ? await d.tasks.trash(t) : await d.tasks.rename(t, 'S$step'),
            _ => await d.sync().then((_) => const CommandOk('', Version(0), [])),
          };
          if (op == 4 && r is CommandOk) completed.add(t);
        }
      }
      await syncAll(ds);
      await expectConverged(ds);
      final rows = {for (final r in await recordKindByName['task']!.readAll(ds.first.db)) r['id']: r};
      expect(rows.keys.toSet().containsAll(created), isTrue, reason: 'seed $seedNo: a task was lost');
      for (final t in completed) {
        expect(rows[t]!['status'], 'done', reason: 'seed $seedNo: a completion of $t was lost');
      }
      for (final db in open) {
        await db.close();
      }
      open.clear();
      server = FakeServer();
      dir.deleteSync(recursive: true);
      dir = Directory.systemTemp.createTempSync('lifeflow_sync_spike_');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
