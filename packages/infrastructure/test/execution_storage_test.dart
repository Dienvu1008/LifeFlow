// P03 T2 (ADR-0037): storage of focus sessions, execution records,
// measurements, period results, goals, milestones and goal links (schema v5).
//   GS-20     export -> clean-install restore keeps every P03 row, and the
//             task's habit flag and aggregation; history is kept
//             (LF-INV-EXEC-001: superseded measurements travel too)
//   upgrade   a schema-4 file restores, tasks get the defaults
//   SR-14     a file with dangling or malformed P03 rows is rejected
//   restore   a row is never written without the records it needs; an
//             optional reference to a missing record is cleared, the row kept
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late String profileId;
  late String ws;
  late DriftDataTransferService transfer;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_exec_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    profileId = host.currentId!;
    ws = (await host.db.select(host.db.workspaces).getSingle()).id;
    transfer = DriftDataTransferService(host.db, dir);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  final t0 = DateTime.utc(2026, 11, 10, 1);
  const p03Kinds = ['focusSession', 'executionRecord', 'measurement', 'periodResult', 'goal', 'milestone', 'goalLink'];

  /// Every P03 kind, written directly (the commands come in T3–T5).
  Future<Map<String, String>> seed() async {
    final db = host.db;
    final walk = (await svc.tasks.create('Walk 6000 steps') as CommandOk).entityId;
    final water = (await svc.tasks.create('Warm water') as CommandOk).entityId;
    await (db.update(db.tasks)..where((t) => t.id.equals(walk))).write(TasksCompanion(
        isHabit: const Value(true), targetType: const Value('atLeast'), targetMin: const Value(6000),
        unit: const Value('steps'), targetAggregation: const Value('max'), completionPolicy: const Value('automatic')));
    await (db.update(db.tasks)..where((t) => t.id.equals(water))).write(const TasksCompanion(isHabit: Value(true)));
    await db.into(db.events).insert(EventsCompanion.insert(
        id: 'ev-1', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0, title: 'Gym class'));
    await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
        id: 's1', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        taskId: Value(walk), mode: 'pomodoro', state: 'ended', startedAt: t0.millisecondsSinceEpoch + 250,
        plannedMs: const Value(25 * 60000), pausedMs: const Value(60000),
        endedAt: Value(t0.add(const Duration(minutes: 26)).millisecondsSinceEpoch + 250)));
    await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
        id: 's2', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        mode: 'stopwatch', state: 'paused', startedAt: t0.millisecondsSinceEpoch,
        pausedAt: Value(t0.add(const Duration(minutes: 3)).millisecondsSinceEpoch)));
    await db.into(db.executionRecords).insert(ExecutionRecordsCompanion.insert(
        id: executionRecordIdOf('s1'), workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        sessionId: const Value('s1'), taskId: Value(walk), occurrenceDate: const Value('2026-11-10'),
        actualStart: t0, actualEnd: t0.add(const Duration(minutes: 26)), focusMs: 25 * 60000, note: const Value('ok')));
    await db.into(db.measurements).insert(MeasurementsCompanion.insert(
        id: 'm1', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        taskId: walk, value: 4000, localDate: '2026-11-10', recordedAt: t0, source: 'manual', deviceId: const Value('pc')));
    await db.into(db.measurements).insert(MeasurementsCompanion.insert(
        id: 'm2', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        taskId: walk, value: 6500, localDate: '2026-11-10', recordedAt: t0.add(const Duration(hours: 1)),
        source: 'manual', supersedesId: const Value('m1'), recordId: Value(executionRecordIdOf('s1'))));
    await db.into(db.periodResults).insert(PeriodResultsCompanion.insert(
        id: periodResultIdOf(walk, '2026-11-09', 'period'), workspaceId: ws, ownerId: profileId,
        createdAt: t0, updatedAt: t0, taskId: walk, periodKey: '2026-11-09', kind: 'period',
        outcome: 'achieved', value: const Value(7000), target: const Value('{"type":"atLeast","min":6000}'), evaluatedAt: t0));
    await db.into(db.periodResults).insert(PeriodResultsCompanion.insert(
        id: periodResultIdOf(water, '2026-11-09', 'occurrence'), workspaceId: ws, ownerId: profileId,
        createdAt: t0, updatedAt: t0, taskId: water, periodKey: '2026-11-09', kind: 'occurrence',
        outcome: 'missed', evaluatedAt: t0));
    await db.into(db.goals).insert(GoalsCompanion.insert(
        id: 'g1', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        kind: 'goal', title: 'Get fit', targetDate: const Value('2026-12-31')));
    await db.into(db.goals).insert(GoalsCompanion.insert(
        id: 'p1', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        kind: 'project', title: 'Move house', startDate: const Value('2026-11-01'), status: const Value('archived')));
    await db.into(db.milestones).insert(MilestonesCompanion.insert(
        id: 'ms1', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
        goalId: 'g1', title: 'Run 5 km', isCompleted: const Value(true), completedAt: Value(t0), sortOrder: const Value(1)));
    for (final (type, id) in [('task', walk), ('event', 'ev-1')]) {
      await db.into(db.goalLinks).insert(GoalLinksCompanion.insert(
          id: goalLinkIdOf('g1', type, id), workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0,
          goalId: 'g1', itemType: type, itemId: id));
    }
    return {'walk': walk, 'water': water};
  }

  Future<Map<String, List<String>>> snapshot(AppDatabase db) async => {
        for (final k in recordKinds)
          if (p03Kinds.contains(k.name)) k.name: [for (final r in await k.readAll(db)) jsonEncode(r)]..sort(),
      };

  test('a new store has the v5 tables; tasks default to sum and not a habit', () async {
    expect(AppDatabase.currentSchemaVersion, 6);
    final id = (await svc.tasks.create('Plain') as CommandOk).entityId;
    final t = await (host.db.select(host.db.tasks)..where((x) => x.id.equals(id))).getSingle();
    expect((t.targetAggregation, t.isHabit), ('sum', false));
    final indexes = (await host.db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(
        indexes,
        containsAll(['measurements_task_date', 'focus_sessions_state', 'execution_records_task',
            'period_results_task', 'milestones_goal', 'goal_links_goal', 'goal_links_item']));
  });

  test('GS-20: export -> clean install keeps every P03 row, the habit flag and the aggregation', () async {
    final ids = await seed();
    final before = await snapshot(host.db);
    expect(before.values.every((rows) => rows.isNotEmpty), isTrue);
    final file = await transfer.exportActiveProfile();

    final b = Directory.systemTemp.createTempSync('lifeflow_clean_');
    final clean = await openDirectory(b, MemoryKeys());
    addTearDown(() async {
      await clean.close();
      b.deleteSync(recursive: true);
    });
    final h = TestHost(clean);
    await h.openActive();
    addTearDown(h.close);
    final r = await DriftDataTransferService(h.db, clean).restore(file.contents);
    expect(r, isA<Restored>(), reason: '$r');
    final store = await clean.openProfile(profileId);
    addTearDown(store.db.close);
    expect(await snapshot(store.db), before);
    final walk = await (store.db.select(store.db.tasks)..where((t) => t.id.equals(ids['walk']!))).getSingle();
    expect((walk.isHabit, walk.targetAggregation, walk.completionPolicy), (true, 'max', 'automatic'));
    // The corrected measurement (history) is there too.
    expect((await store.db.select(store.db.measurements).get()).map((m) => m.id).toSet(), {'m1', 'm2'});
  });

  test('a schema-4 file (before P03) restores; its tasks get the defaults', () async {
    await svc.tasks.create('Old task');
    final text = (await transfer.exportActiveProfile()).contents;
    final payload = ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
    for (final k in ['focusSessions', 'executionRecords', 'measurements', 'periodResults', 'goals', 'milestones', 'goalLinks']) {
      payload.remove(k);
    }
    for (final t in (payload['tasks'] as List).cast<Map>()) {
      t
        ..remove('targetAggregation')
        ..remove('isHabit');
    }
    final env = (jsonDecode(ProfileExport.seal(payload, schemaVersion: 4)) as Map).cast<String, Object?>();
    final counts = (env['counts'] as Map)..removeWhere((k, _) => !payload.containsKey(k));
    env['counts'] = counts;
    final parsed = ProfileExport.parse(jsonEncode(env), currentSchemaVersion: AppDatabase.currentSchemaVersion);
    expect(parsed.records['measurement'], isEmpty);
    expect(parsed.records['task']!.single['isHabit'], false);
    expect(parsed.records['task']!.single['targetAggregation'], 'sum');
  });

  group('untrusted P03 rows in a file (SR-14)', () {
    late Map<String, Object?> payload;
    setUp(() async {
      await seed();
      payload = ((jsonDecode((await transfer.exportActiveProfile()).contents) as Map)['payload'] as Map)
          .cast<String, Object?>();
    });
    List<Map<String, dynamic>> rows(String key) => (payload[key] as List).cast<Map<String, dynamic>>();
    void rejected(String why, {String? mentions}) {
      try {
        ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion),
            currentSchemaVersion: AppDatabase.currentSchemaVersion);
        fail('expected rejection: $why');
      } on ExportRejected catch (e) {
        expect(e.kind, RestoreRejection.invalidContents, reason: why);
        if (mentions != null) expect(e.message, contains(mentions), reason: why);
      }
    }

    final cases = <(String, void Function(Map<String, Object?>), String)>[
      ('a measurement of an unknown task', (p) => (p['measurements'] as List).first['taskId'] = 'nope', 'measurement points to an unknown item'),
      ('a negative measurement', (p) => (p['measurements'] as List).first['value'] = -1, '0 or more'),
      ('a measurement with a bad date', (p) => (p['measurements'] as List).first['localDate'] = '2026-02-30', 'bad date'),
      ('a correction of an unknown measurement', (p) => (p['measurements'] as List).last['supersedesId'] = 'zz', 'correction'),
      ('a measurement of an unknown record', (p) => (p['measurements'] as List).last['recordId'] = 'zz', 'unknown executionRecord'),
      ('a record id that is not its session\'s', (p) {
        (p['executionRecords'] as List).first['id'] = 'other';
        (p['measurements'] as List).last['recordId'] = 'other'; // keep the reference valid
      }, 'does not match its session'),
      ('a record of an unknown session', (p) {
        final r = (p['executionRecords'] as List).first;
        r['sessionId'] = 'zz';
        r['id'] = 'session:zz';
      }, 'unknown focusSession'),
      ('a record ending before it starts', (p) {
        final r = (p['executionRecords'] as List).first;
        r['actualEnd'] = (r['actualStart'] as int) - 1;
      }, 'ends before'),
      ('a pomodoro without a planned interval', (p) => (p['focusSessions'] as List).first['plannedMs'] = null, 'planned'),
      ('an unknown focus state', (p) => (p['focusSessions'] as List).first['state'] = 'flying', 'unknown state'),
      ('a result id that is not its period\'s', (p) => (p['periodResults'] as List).first['id'] = 'x', 'does not match'),
      ('an unknown outcome', (p) => (p['periodResults'] as List).first['outcome'] = 'great', 'unknown outcome'),
      ('a milestone of an unknown goal', (p) => (p['milestones'] as List).first['goalId'] = 'nope', 'milestone points'),
      ('a link to an unknown goal', (p) {
        final l = (p['goalLinks'] as List).first;
        l['goalId'] = 'nope';
        l['id'] = goalLinkIdOf('nope', l['itemType'] as String, l['itemId'] as String);
      }, 'goalLink points'),
      ('a link to an unknown item', (p) {
        final l = (p['goalLinks'] as List).last;
        l['itemId'] = 'nope';
        l['id'] = goalLinkIdOf('g1', 'event', 'nope');
      }, 'goalLink points'),
      ('a link id that is not its pair\'s', (p) => (p['goalLinks'] as List).first['id'] = 'g1|task:other', 'does not match'),
      ('an unknown goal status', (p) => (p['goals'] as List).first['status'] = 'paused', 'unknown status'),
      ('an unknown aggregation', (p) => (p['tasks'] as List).first['targetAggregation'] = 'median', 'aggregation'),
      ('a bad tracking start', (p) => (p['tasks'] as List).first['trackedSince'] = '2026-13-01', 'tracking start'),
    ];
    for (final (why, tamper, mentions) in cases) {
      test(why, () {
        tamper(payload);
        rejected(why, mentions: mentions);
      });
    }

    test('the untouched file is accepted', () {
      expect(rows('goals'), hasLength(2));
      expect(
          () => ProfileExport.parse(ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion),
              currentSchemaVersion: AppDatabase.currentSchemaVersion),
          returnsNormally);
    });
  });

  group('restore into the same profile', () {
    test('identical with P03 data', () async {
      await seed();
      final file = (await transfer.exportActiveProfile()).contents;
      expect(await transfer.inspect(file), isA<RestoreIdentical>());
    });

    test('merge (a) only: a goal only in the file is not added, nor its milestone and links', () async {
      await seed();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      await (db.delete(db.goalLinks)).go();
      await (db.delete(db.milestones)).go();
      await (db.delete(db.goals)..where((g) => g.id.equals('g1'))).go();

      final r = await transfer.restore(file, choice: const RestoreChoice.merge(takeNewer: true, addMissing: false));
      expect(r, isA<RestoredInto>(), reason: '$r');
      expect(await db.select(db.milestones).get(), isEmpty);
      expect(await db.select(db.goalLinks).get(), isEmpty);
      final again = (await transfer.exportActiveProfile()).contents;
      expect(() => ProfileExport.parse(again, currentSchemaVersion: AppDatabase.currentSchemaVersion), returnsNormally);
    });

    test('merge (a): a newer session pointing to a task only in the file keeps the session, without the task', () async {
      final ids = await seed();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      // On this device: the walk task never existed, and session s1 is older.
      await (db.delete(db.measurements)).go();
      await (db.delete(db.periodResults)..where((p) => p.taskId.equals(ids['walk']!))).go();
      await (db.delete(db.executionRecords)).go();
      await (db.delete(db.goalLinks)..where((l) => l.itemId.equals(ids['walk']!))).go();
      await (db.delete(db.tasks)..where((t) => t.id.equals(ids['walk']!))).go();
      await (db.update(db.focusSessions)..where((s) => s.id.equals('s1'))).write(FocusSessionsCompanion(
          taskId: const Value(null), updatedAt: Value(t0.subtract(const Duration(days: 1)))));

      final r = await transfer.restore(file, choice: const RestoreChoice.merge(takeNewer: true, addMissing: false));
      expect(r, isA<RestoredInto>(), reason: '$r');
      final s1 = await (db.select(db.focusSessions)..where((s) => s.id.equals('s1'))).getSingle();
      expect(s1.state, 'ended'); // the newer session from the file
      expect(s1.taskId, isNull); // its task is not on this device
      expect(await db.select(db.measurements).get(), isEmpty); // not written without their task
      final again = (await transfer.exportActiveProfile()).contents;
      expect(() => ProfileExport.parse(again, currentSchemaVersion: AppDatabase.currentSchemaVersion), returnsNormally);
    });

    test('merge (a): a newer correction is not written when the measurement it corrects is not added', () async {
      await seed();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      // On this device: m1 never arrived, and m2 is an older plain entry.
      await (db.delete(db.measurements)..where((m) => m.id.equals('m1'))).go();
      await (db.update(db.measurements)..where((m) => m.id.equals('m2'))).write(MeasurementsCompanion(
          supersedesId: const Value(null), updatedAt: Value(t0.subtract(const Duration(days: 1)))));

      final r = await transfer.restore(file, choice: const RestoreChoice.merge(takeNewer: true, addMissing: false));
      expect(r, isA<RestoredInto>(), reason: '$r');
      final m2 = await (db.select(db.measurements)..where((m) => m.id.equals('m2'))).getSingle();
      expect(m2.supersedesId, isNull); // never a correction of nothing
      final again = (await transfer.exportActiveProfile()).contents;
      expect(() => ProfileExport.parse(again, currentSchemaVersion: AppDatabase.currentSchemaVersion), returnsNormally);
    });

    test('overwrite trashes device-only P03 rows (tombstones, never deleted)', () async {
      await seed();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      await db.into(db.goals).insert(GoalsCompanion.insert(
          id: 'g-device', workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0, kind: 'goal', title: 'Only here'));
      final r = await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect((r as RestoredInto).removed, 1);
      final gone = await (db.select(db.goals)..where((g) => g.id.equals('g-device'))).getSingle();
      expect(gone.deletedAt, isNotNull);
    });
  });
}
