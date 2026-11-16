// P04 T5 (ADR-0058; p04-plan.md D6, D7, D8, D9): what the sync UI relies on.
//   reviews    a value that gave way is listed with the record's title and
//              both values; "keep" closes it; "take the other" puts it back
//              as a change that reaches the other device; a delete against
//              an edit can only be closed (restore from the trash)
//   status     watched: a sync running shows, a waiting edit counts
//   sync now   a second call while one runs waits for it
//   scheduler  Automatic syncs on start, after a change, again after a
//              failure (backoff); "Only Sync now" never does
import 'dart:async';
import 'dart:io';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show DataClassification;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart' show MemoryKeys, openDirectory;

class _Utc implements DeviceTime {
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}

class Device {
  Device(this.db, MemoryRemoteServer server)
      : gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)),
        remote = MemoryRemoteGateway(server, accountId: 'acc') {
    tasks = DriftTaskService(db, gw);
    sync = DriftSyncService(db: db, gateway: gw, remote: remote, keyring: WorkspaceKeyring(MemoryKeys().call));
  }
  final AppDatabase db;
  final DriftCommandGateway gw;
  final MemoryRemoteGateway remote;
  late final DriftTaskService tasks;
  late final DriftSyncService sync;

  Future<Map<String, dynamic>> task(String id) async => (await recordKindByName['task']!.readOne(db, id))!;
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
    dir = Directory.systemTemp.createTempSync('lifeflow_sync_review_');
    server = MemoryRemoteServer();
  });
  tearDown(() async {
    for (final db in open) {
      await db.close();
    }
    open.clear();
    dir.deleteSync(recursive: true);
  });

  Future<Device> device(String name) async {
    final db = AppDatabase(NativeDatabase(File('${dir.path}/$name.db')));
    open.add(db);
    await ProfileStore(db).ensureFirstProfile();
    return Device(db, server);
  }

  /// A and B sync one workspace (A started with a recovery key).
  Future<(Device, Device)> pair() async {
    final a = await device('a');
    final offer = await a.sync.offerRecoveryKey();
    final (p1, p2) = offer.check;
    expect((await a.sync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1]))).problem, isNull);
    final b = await device('b');
    expect((await b.sync.join(JoinChoice.mergeThisDevice, recoveryKey: offer.words.join(' '))).problem, isNull);
    return (a, b);
  }

  /// Both edit the notes of one task before syncing: B's sync makes a review.
  Future<(Device, Device, String, SyncReviewView)> notesConflict() async {
    final (a, b) = await pair();
    final id = ok(await a.tasks.create('Pay the rent'));
    await a.sync.syncNow();
    await b.sync.syncNow();
    ok(await a.tasks.setNotes(id, 'From A'));
    ok(await b.tasks.setNotes(id, 'From B'));
    await a.sync.syncNow();
    await b.sync.syncNow();
    final item = (await b.sync.reviews()).single;
    return (a, b, id, item);
  }

  test('a notes conflict is listed with the title and both values; keeping closes it', () async {
    final (a, b, id, item) = await notesConflict();
    expect((item.recordKind, item.recordId, item.field, item.reason, item.title), ('task', id, 'notes', SyncReviewKind.changedOnBoth, 'Pay the rent'));
    expect({item.kept, item.other}, {'From A', 'From B'});
    expect(item.canTakeOther, isTrue);
    final kept = (await b.task(id))['notes'];
    expect(kept, item.kept);
    expect((await b.sync.status()).reviews, 1);

    expect((await b.sync.resolveReview(item.id, takeOther: false)).problem, isNull);
    expect(await b.sync.reviews(), isEmpty);
    expect((await b.task(id))['notes'], kept, reason: 'nothing changes');
    expect((await b.sync.resolveReview(item.id, takeOther: false)).problem, SyncSetupProblem.reviewGone);
    expect(a, isNotNull);
  });

  test('taking the other value is a new change that reaches the other device', () async {
    final (a, b, id, item) = await notesConflict();
    final before = (await b.task(id))['version'] as int;
    expect((await b.sync.resolveReview(item.id, takeOther: true)).problem, isNull);
    final now = await b.task(id);
    expect((now['notes'], now['version']), (item.other, before + 1));
    expect((await b.sync.status()).pending, greaterThan(0), reason: 'waits to be sent');
    await b.sync.syncNow();
    await a.sync.syncNow();
    expect((await a.task(id))['notes'], item.other);
    expect(await a.sync.reviews(), isEmpty);
  });

  test('a whole value (the workspace\'s result policy) is put back as a whole', () async {
    final (a, b) = await pair();
    ok(await DriftHabitService(b.db, b.gw, _Utc()).setManualResults(ManualResults.tick));
    final ws = (await ProfileStore(b.db).getActiveProfile())!.activeWorkspaceId.value;
    // As the merge writes it (sync_apply_handler): the whole content.
    await b.db.into(b.db.syncReviews).insert(SyncReviewsCompanion.insert(
        id: 'r1', workspaceId: ws, kind: 'workspaceSettings', recordId: ws, field: '*',
        kept: '{"manualResults":"tick"}', other: '{"manualResults":"target"}',
        reason: 'changedOnBoth', createdAt: DateTime.utc(2026, 11, 16)));
    final item = (await b.sync.reviews()).single;
    expect((item.kept, item.other, item.canTakeOther), ('manualResults: tick', 'manualResults: target', true));
    expect((await b.sync.resolveReview('r1', takeOther: true)).problem, isNull);
    expect(await DriftHabitQueries(b.db, _Utc()).manualResults(), ManualResults.target);
    await b.sync.syncNow();
    await a.sync.syncNow();
    expect(await DriftHabitQueries(a.db, _Utc()).manualResults(), ManualResults.target);
  });
  test('a delete against an edit can only be closed: the edits are in the trash', () async {
    final (a, b) = await pair();
    final id = ok(await a.tasks.create('Old plan'));
    await a.sync.syncNow();
    await b.sync.syncNow();
    ok(await a.tasks.trash(id));
    ok(await b.tasks.rename(id, 'New plan'));
    await a.sync.syncNow();
    await b.sync.syncNow();
    final item = (await b.sync.reviews()).single;
    expect((item.reason, item.canTakeOther, item.kept, item.other), (SyncReviewKind.deletedAndEdited, false, '', ''));
    expect((await b.task(id))['title'], 'New plan', reason: 'the edit is on the record in the trash');
    expect((await b.sync.resolveReview(item.id, takeOther: true)).problem, SyncSetupProblem.reviewGone);
    expect((await b.sync.resolveReview(item.id, takeOther: false)).problem, isNull);
  });

  test('only a value changed on both devices can be taken back, even on a live record', () async {
    final (_, b) = await pair();
    final id = ok(await b.tasks.create('Restored later'));
    final ws = (await ProfileStore(b.db).getActiveProfile())!.activeWorkspaceId.value;
    for (final (rid, reason) in [('u1', 'unreadable'), ('d1', 'deletedAndEdited')]) {
      await b.db.into(b.db.syncReviews).insert(SyncReviewsCompanion.insert(
          id: rid, workspaceId: ws, kind: 'task', recordId: id, field: rid == 'u1' ? 'title' : 'deletedAt',
          kept: '"Restored later"', other: '"Something else"', reason: reason, createdAt: DateTime.utc(2026, 11, 16)));
      expect((await b.sync.resolveReview(rid, takeOther: true)).problem, SyncSetupProblem.reviewGone, reason: reason);
    }
    expect((await b.task(id))['title'], 'Restored later');
  });

  test('T6 finding: an occurrence moved and done (same id, two kinds) reaches the other device', () async {
    final (a, b) = await pair();
    final plan = DriftTaskScheduling(a.db, a.gw);
    final id = ok(await a.tasks.create('Run'));
    ok(await plan.setSchedule(id, TaskScheduleInput(
        start: SchedulePointInput.date(LocalDate(2026, 11, 9)), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
    // 'task:<id>@2026-11-10' is the id of both the exception and the completion.
    ok(await plan.changeOccurrence(id, LocalDate(2026, 11, 10), MoveThisOccurrence(LocalDate(2026, 11, 11))));
    ok(await plan.setOccurrenceDone(id, LocalDate(2026, 11, 10), done: true));
    expect((await a.sync.syncNow()).outcome, SyncOutcome.upToDate);
    final r = await b.sync.syncNow();
    expect(r.outcome, SyncOutcome.upToDate, reason: '$r');
    expect(await b.task(id), isNotNull);
    expect(await recordKindByName['exception']!.readOne(b.db, 'task:$id@2026-11-10'), isNotNull);
    expect(await recordKindByName['completion']!.readOne(b.db, 'task:$id@2026-11-10'), isNotNull);
  });

  test('an unexpected error is a failed sync with a log line, never an exception from Sync now', () async {
    final (a, _) = await pair();
    final lines = <String>[];
    final broken = DriftSyncService(
        db: a.db, gateway: a.gw, remote: _BrokenPull(a.remote), keyring: a.sync.keyring, log: lines.add);
    ok(await a.tasks.create('Still here'));
    final r = await broken.syncNow();
    expect((r.outcome, r.detail), (SyncOutcome.failed, 'error: StateError'));
    expect(lines.single, startsWith('[sync] SyncReport(failed'));
    expect(lines.single, isNot(contains('Still here')), reason: 'no content in the log');
    expect((await a.sync.status()).lastResult, SyncOutcome.failed);
    expect((await a.sync.syncNow()).outcome, SyncOutcome.upToDate, reason: 'the next sync goes on');
  });

  group('egress (ADR-0059, PRIV-001/003, FF-ARCH-08 prepared)', () {
    test('every record kind has a class; an unknown kind is Restricted', () {
      expect(kindClasses.keys.toSet(), {for (final k in recordKinds) k.name});
      expect(dataClassOf('somethingNew', const {}), DataClassification.restricted);
      expect(dataClassOf('task', const {}), DataClassification.confidential, reason: 'a task carries its notes');
    });

    test('a measurement from a health source never leaves the device; a typed one syncs', () async {
      final (a, b) = await pair();
      final habits = DriftHabitService(a.db, a.gw, _Utc());
      final id = ok(await a.tasks.create('Walk'));
      ok(await habits.setTarget(id, const TargetInput(kind: TargetKind.atLeast, min: 5000, unit: 'steps')));
      ok(await habits.recordMeasurement(id, 6000));
      final typed = (await recordKindByName['measurement']!.readAll(a.db)).single;
      // As a health import (P08) would write it: its own row and outbox row.
      final health = {...typed, 'id': 'm-health', 'source': 'healthConnect', 'value': 7000.0};
      await a.db.batch((x) => recordKindByName['measurement']!.upsert(x, a.db, [health]));
      await a.db.into(a.db.outbox).insert(OutboxCompanion.insert(
          operationId: 'op-health', entityId: 'm-health', entityType: 'measurement', workspaceId: typed['workspaceId'] as String,
          actorId: 'device', operationType: 'create', payload: '{}', createdAt: DateTime.utc(2026, 11, 16)));

      final r = await a.sync.syncNow();
      expect((r.outcome, r.withheld), (SyncOutcome.upToDate, 1));
      final ws = typed['workspaceId'] as String;
      final sid = await RecordSealer.of((await a.sync.keyring.keyOf(ws))!).then((s) => s.serverId('measurement', 'm-health'));
      expect(server.dump(ws).map((x) => x.id), isNot(contains(sid)), reason: 'not even sealed');
      final row = await (a.db.select(a.db.outbox)..where((o) => o.entityId.equals('m-health'))).getSingle();
      expect(row.status, 'local');
      expect((await a.sync.status()).pending, 0, reason: 'nothing waits for it');

      await b.sync.syncNow();
      final there = await recordKindByName['measurement']!.readAll(b.db);
      expect([for (final m in there) m['source']], ['manual']);
    });
  });

  test('the status is watched: a waiting edit and a running sync show', () async {
    final (a, _) = await pair();
    final seen = <SyncStatus>[];
    final sub = a.sync.watchStatus().listen(seen.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    ok(await a.tasks.create('Watched'));
    await pumpEventQueue();
    expect(seen.last.pending, greaterThan(0));
    await a.sync.syncNow();
    await pumpEventQueue();
    expect(seen.any((s) => s.syncing), isTrue);
    expect((seen.last.syncing, seen.last.pending, seen.last.lastResult), (false, 0, SyncOutcome.upToDate));
  });

  test('sync now while a sync runs waits for it: one sync, one report', () async {
    final (a, _) = await pair();
    ok(await a.tasks.create('Once'));
    final first = a.sync.syncNow();
    final second = a.sync.syncNow();
    expect(identical(await first, await second), isTrue);
  });

  test('settings: "When to sync" is a device setting, automatic by default', () async {
    final d = await openDirectory(Directory('${dir.path}/registry')..createSync(), MemoryKeys());
    addTearDown(d.close);
    final s = DirectorySettingsService(d);
    expect(await s.syncWhen(), SyncWhen.automatic);
    await s.setSyncWhen(SyncWhen.onlySyncNow);
    expect(await DirectorySettingsService(d).syncWhen(), SyncWhen.onlySyncNow);
  });

  group('scheduler', () {
    test('Automatic: syncs on start and a moment after a change', () async {
      final (a, b) = await pair();
      final s = SyncScheduler(service: a.sync, when: () async => SyncWhen.automatic, afterChange: const Duration(milliseconds: 50));
      addTearDown(s.stop);
      final id = ok(await a.tasks.create('Before start'));
      await s.start();
      await b.sync.syncNow();
      expect(await b.task(id), isNotNull, reason: 'the start synced it');
      final later = ok(await a.tasks.create('After a change'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect((await a.sync.status()).pending, 0, reason: 'sent by itself');
      await b.sync.syncNow();
      expect(await b.task(later), isNotNull);
    });

    test('"Only when I tap Sync now": nothing by itself', () async {
      final (a, _) = await pair();
      final s = SyncScheduler(service: a.sync, when: () async => SyncWhen.onlySyncNow, afterChange: const Duration(milliseconds: 20));
      addTearDown(s.stop);
      ok(await a.tasks.create('Waits'));
      await s.start();
      expect(await s.resumed(), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect((await a.sync.status()).pending, greaterThan(0));
      expect((await a.sync.syncNow()).outcome, SyncOutcome.upToDate, reason: 'Sync now works in both');
    });

    test('offline: tries again after the backoff, and resets when it works', () async {
      final (a, _) = await pair();
      final waits = <int>[];
      final s = SyncScheduler(
          service: a.sync,
          when: () async => SyncWhen.automatic,
          afterChange: const Duration(hours: 1),
          backoff: (n) {
            waits.add(n);
            return const Duration(milliseconds: 30);
          });
      addTearDown(s.stop);
      server.unavailable = true;
      ok(await a.tasks.create('Offline'));
      await s.start();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(waits.length, greaterThanOrEqualTo(2));
      expect(waits.take(2), [1, 2]);
      server.unavailable = false;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(s.failures, 0);
      expect((await a.sync.status()).pending, 0);
    });

    test('sync off on this profile: nothing runs, not even a call', () async {
      final a = await device('a');
      final s = SyncScheduler(service: a.sync, when: () async => SyncWhen.automatic);
      addTearDown(s.stop);
      await s.start();
      expect(await s.run(), isNull);
      expect(await s.resumed(), isNull);
    });

    test('stopped: nothing more runs', () async {
      final (a, _) = await pair();
      final s = SyncScheduler(service: a.sync, when: () async => SyncWhen.automatic, afterChange: const Duration(milliseconds: 20));
      await s.start();
      await s.stop();
      ok(await a.tasks.create('After stop'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect((await a.sync.status()).pending, greaterThan(0));
      expect(await s.run(), isNull);
    });
  });
}

/// The server, except that pulling fails with something unexpected.
class _BrokenPull implements RemoteGateway {
  _BrokenPull(this.inner);
  final RemoteGateway inner;
  @override
  Future<List<SealedRecord>> pull(String ws, int after, {int limit = 1000}) async =>
      throw StateError('unexpected');
  @override
  dynamic noSuchMethod(Invocation i) => Function.apply(
      switch (i.memberName) {
        #workspaces => inner.workspaces,
        #push => inner.push,
        #purge => inner.purge,
        _ => throw UnimplementedError('${i.memberName}'),
      },
      i.positionalArguments,
      i.namedArguments);
}
