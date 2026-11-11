// P02 T3 (ADR-0029): storage of schedules, exceptions, events, calendars,
// occurrence completions and reminders (schema v4).
//   mapping       ScheduleSpec / RecurrenceRule / exceptions <-> rows, both
//                 ways, every shape and rule option; malformed rows rejected
//   LF-INV-PLAN-004 a date-only schedule is stored as text dates, no instant
//   GS-20         export -> clean-install restore keeps all planning rows
//   SR-14         a file with dangling or invalid planning rows is rejected
//   restore       compare / merge / overwrite cover the new tables; a
//                 dependent row is never written without its task or event
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'fake_auth.dart';
import 'profile_harness.dart';

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);
tk.DatePoint dp(int y, int m, int day) => tk.DatePoint(d(y, m, day));
tk.TimedPoint tp(int y, int m, int day, int h, int min, [String zone = 'Europe/Berlin']) =>
    tk.TimedPoint(ZonedWallClock(d(y, m, day), TimeOfDayValue(h, min), zone));

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late String profileId;
  late String ws;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_planning_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    profileId = host.currentId!;
    ws = (await host.db.select(host.db.workspaces).getSingle()).id;
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  final t0 = DateTime.utc(2026, 11, 9, 8);

  /// The syncable columns every record row needs.
  T sync<T>(T Function({required String workspaceId, required String ownerId,
          required DateTime createdAt, required DateTime updatedAt}) make) =>
      make(workspaceId: ws, ownerId: profileId, createdAt: t0, updatedAt: t0);

  Future<void> putSchedule(String type, String id, tk.ScheduleSpec spec, [tk.RecurrenceRule? rule]) async {
    final f = scheduleFields(type, id, spec, rule);
    await host.db.into(host.db.schedules).insertOnConflictUpdate(f.copyWith(
        workspaceId: Value(ws), ownerId: Value(profileId),
        createdAt: Value(t0), updatedAt: Value(t0)));
  }

  Future<Schedule> scheduleRow(String type, String id) =>
      (host.db.select(host.db.schedules)..where((s) => s.id.equals(scheduleIdOf(type, id)))).getSingle();

  group('schedule rows <-> Time Kernel types', () {
    final specs = <tk.ScheduleSpec>[
      tk.ScheduleSpec(start: dp(2026, 11, 9)),
      tk.ScheduleSpec(start: tp(2026, 11, 9, 9, 0)),
      tk.ScheduleSpec(start: dp(2026, 11, 9), end: dp(2026, 11, 11)),
      tk.ScheduleSpec(start: tp(2026, 11, 9, 9, 0), end: tp(2026, 11, 9, 10, 30, 'America/New_York')),
      tk.ScheduleSpec(end: dp(2026, 11, 13)),
      tk.ScheduleSpec(end: tp(2026, 11, 13, 17, 0, 'Asia/Ho_Chi_Minh')),
      tk.ScheduleSpec(start: dp(2026, 11, 9), deadline: tp(2026, 11, 13, 17, 0)),
      tk.ScheduleSpec(deadline: dp(2026, 11, 13)),
    ];
    final rules = <tk.RecurrenceRule?>[
      null,
      const tk.RecurrenceRule(frequency: tk.Frequency.daily, interval: 3),
      tk.RecurrenceRule(
          frequency: tk.Frequency.weekly,
          byWeekday: const {Weekday.wednesday, Weekday.monday},
          end: tk.EndsOnDate(d(2027, 3, 1)),
          weekStart: Weekday.sunday),
      const tk.RecurrenceRule(
          frequency: tk.Frequency.monthly, end: tk.EndsAfterCount(12), monthEndRule: tk.MonthEndRule.lastDay),
      const tk.RecurrenceRule(frequency: tk.Frequency.yearly, interval: 2),
    ];

    test('every shape x every rule option round-trips exactly', () async {
      var n = 0;
      for (final spec in specs) {
        for (final rule in rules) {
          final id = 't${n++}';
          await putSchedule('task', id, spec, rule);
          final (back, backRule) = readSchedule(await scheduleRow('task', id));
          expect(back, spec, reason: '$id $spec');
          expect(backRule, rule, reason: '$id $rule');
        }
      }
    });

    test('the stored date range matches the series', () async {
      final spec = tk.ScheduleSpec(start: dp(2026, 1, 31), end: dp(2026, 2, 2));
      await putSchedule('task', 'a', spec,
          const tk.RecurrenceRule(frequency: tk.Frequency.monthly, end: tk.EndsAfterCount(3)));
      final r = await scheduleRow('task', 'a');
      // Jan 31, Mar 31, May 31 (skip months without a 31st); each spans 3 days.
      expect((r.firstDate, r.lastDate), ('2026-01-31', '2026-06-02'));
      await putSchedule('task', 'b', spec, const tk.RecurrenceRule(frequency: tk.Frequency.daily));
      expect((await scheduleRow('task', 'b')).lastDate, isNull); // open-ended
      await putSchedule('task', 'c', spec);
      expect((await scheduleRow('task', 'c')).lastDate, '2026-02-02');
    });

    test('LF-INV-PLAN-004: a date-only schedule is stored as text dates only', () async {
      await putSchedule('task', 'x', tk.ScheduleSpec(start: dp(2026, 11, 9), end: dp(2026, 11, 10)));
      final raw = await host.db.customSelect(
          "SELECT start_date, start_time, start_zone, end_date FROM schedules WHERE id = 'task:x'").getSingle();
      expect(raw.data, {'start_date': '2026-11-09', 'start_time': null, 'start_zone': null, 'end_date': '2026-11-10'});
    });

    test('exceptions round-trip, all four kinds', () async {
      final ex = [
        tk.OccurrenceException(d(2026, 11, 16), const tk.SkipOccurrence()),
        tk.OccurrenceException(d(2026, 11, 23), const tk.CancelOccurrence()),
        tk.OccurrenceException(d(2026, 11, 30), tk.MoveOccurrence(d(2026, 12, 1), toTime: TimeOfDayValue(14, 0))),
        tk.OccurrenceException(d(2026, 12, 7), const tk.EditOccurrence({'title': 'Longer'})),
      ];
      for (final e in ex) {
        await host.db.into(host.db.occurrenceExceptions).insert(exceptionFields('event', 'e1', e).copyWith(
            workspaceId: Value(ws), ownerId: Value(profileId), createdAt: Value(t0), updatedAt: Value(t0)));
      }
      final back = [for (final r in await host.db.select(host.db.occurrenceExceptions).get()) exceptionOf(r)]
        ..sort((a, b) => a.originalDate.compareTo(b.originalDate));
      expect(back.map((e) => e.originalDate), ex.map((e) => e.originalDate));
      expect(back[0].kind, isA<tk.SkipOccurrence>());
      expect(back[1].kind, isA<tk.CancelOccurrence>());
      final m = back[2].kind as tk.MoveOccurrence;
      expect((m.toDate, m.toTime), (d(2026, 12, 1), TimeOfDayValue(14, 0)));
      expect((back[3].kind as tk.EditOccurrence).patch, {'title': 'Longer'});
    });

    test('malformed or invalid rows are rejected, never half-read', () async {
      Schedule row(Map<String, Object?> change) {
        final good = scheduleFields('task', 'z', tk.ScheduleSpec(start: tp(2026, 11, 9, 9, 0)), null);
        final j = <String, Object?>{
          'id': good.id.value, 'workspaceId': ws, 'ownerId': profileId, 'version': 1,
          'createdAt': t0.millisecondsSinceEpoch, 'updatedAt': t0.millisecondsSinceEpoch,
          'deletedAt': null, 'deletedBy': null,
          'subjectType': 'task', 'subjectId': 'z',
          'startDate': '2026-11-09', 'startTime': '09:00', 'startZone': 'Europe/Berlin',
          'endDate': null, 'endTime': null, 'endZone': null,
          'deadlineDate': null, 'deadlineTime': null, 'deadlineZone': null,
          'firstDate': '2026-11-09', 'lastDate': '2026-11-09',
          'frequency': null, 'interval': 1, 'weekdays': null, 'endKind': null,
          'endDateRule': null, 'endCount': null, 'monthEndRule': 'skip', 'weekStart': 1,
          ...change,
        };
        return Schedule.fromJson(j);
      }

      expect(() => readSchedule(row({})), returnsNormally);
      for (final (why, change) in <(String, Map<String, Object?>)>[
        ('time without a zone', {'startZone': null}),
        ('unknown zone', {'startZone': 'Nowhere/City'}),
        ('bad date', {'startDate': '2026-02-30'}),
        ('bad time', {'startTime': '25:00'}),
        ('bad weekdays', {'frequency': 'weekly', 'weekdays': '1,9', 'lastDate': null}),
        ('weekdays on a daily rule', {'frequency': 'daily', 'weekdays': '1', 'lastDate': null}),
        ('bad frequency', {'frequency': 'hourly'}),
        ('id not matching subject', {'id': 'task:other'}),
        ('stale date range', {'lastDate': '2027-01-01'}),
        ('end before start', {'endDate': '2026-11-08', 'endTime': '09:00', 'endZone': 'Europe/Berlin'}),
      ]) {
        expect(() => readSchedule(row(change)), throwsA(isA<BadScheduleRow>()), reason: why);
      }
    });
  });

  // --- whole-profile round trip ---------------------------------------------

  /// A profile with planning data of every kind, written through the real
  /// task commands for the tasks and directly for the new tables (their
  /// commands come in T4/T5).
  Future<Map<String, String>> seedPlanning() async {
    final task = (await svc.tasks.create('Standup notes') as CommandOk).entityId;
    final other = (await svc.tasks.create('Pay rent') as CommandOk).entityId;
    final db = host.db;
    await db.into(db.calendars).insert(sync(({required workspaceId, required ownerId, required createdAt, required updatedAt}) =>
        CalendarsCompanion.insert(id: 'cal-1', workspaceId: workspaceId, ownerId: ownerId,
            createdAt: createdAt, updatedAt: updatedAt, name: 'Work', color: const Value(0xFF3F51B5))));
    await db.into(db.events).insert(sync(({required workspaceId, required ownerId, required createdAt, required updatedAt}) =>
        EventsCompanion.insert(id: 'ev-1', workspaceId: workspaceId, ownerId: ownerId,
            createdAt: createdAt, updatedAt: updatedAt, title: 'Team meeting', calendarId: const Value('cal-1'),
            location: const Value('Room 2'))));
    await putSchedule('event', 'ev-1', tk.ScheduleSpec(start: tp(2026, 11, 9, 9, 0), end: tp(2026, 11, 9, 9, 30)),
        const tk.RecurrenceRule(frequency: tk.Frequency.weekly, end: tk.EndsAfterCount(10)));
    await putSchedule('task', task, tk.ScheduleSpec(start: dp(2026, 11, 9)),
        const tk.RecurrenceRule(frequency: tk.Frequency.daily));
    await putSchedule('task', other, tk.ScheduleSpec(end: dp(2026, 11, 30)));
    await db.into(db.occurrenceExceptions).insert(exceptionFields('event', 'ev-1',
            tk.OccurrenceException(d(2026, 11, 16), tk.MoveOccurrence(d(2026, 11, 17))))
        .copyWith(workspaceId: Value(ws), ownerId: Value(profileId), createdAt: Value(t0), updatedAt: Value(t0)));
    await db.into(db.occurrenceCompletions).insert(sync(({required workspaceId, required ownerId, required createdAt, required updatedAt}) =>
        OccurrenceCompletionsCompanion.insert(
            id: completionIdOf(task, d(2026, 11, 9)), workspaceId: workspaceId, ownerId: ownerId,
            createdAt: createdAt, updatedAt: updatedAt, taskId: task, originalDate: '2026-11-09', completedAt: t0)));
    await db.into(db.reminders).insert(sync(({required workspaceId, required ownerId, required createdAt, required updatedAt}) =>
        RemindersCompanion.insert(id: 'rem-1', workspaceId: workspaceId, ownerId: ownerId,
            createdAt: createdAt, updatedAt: updatedAt, subjectType: 'event', subjectId: 'ev-1',
            offsetMinutes: const Value(10))));
    return {'task': task, 'other': other};
  }

  // The P02 planning kinds (P03 kinds have their own round trip in
  // execution_storage_test.dart).
  const planningKinds = {'calendar', 'event', 'schedule', 'exception', 'completion', 'reminder'};
  Future<Map<String, List<String>>> planningSnapshot(AppDatabase db) async => {
        for (final k in recordKinds)
          if (planningKinds.contains(k.name))
            k.name: [for (final r in await k.readAll(db)) jsonEncode(r)]..sort(),
      };

  test('GS-20: export -> clean install keeps every planning row', () async {
    await seedPlanning();
    final before = await planningSnapshot(host.db);
    expect(before.values.every((rows) => rows.isNotEmpty), isTrue);
    final file = await DriftDataTransferService(host.db, dir).exportActiveProfile();

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
    expect(await planningSnapshot(store.db), before);
    // And it still reads as the same schedules.
    for (final row in await store.db.select(store.db.schedules).get()) {
      expect(() => readSchedule(row), returnsNormally);
    }
  });

  group('untrusted planning rows in a file (SR-14)', () {
    late Map<String, Object?> payload;
    setUp(() async {
      await seedPlanning();
      final text = (await DriftDataTransferService(host.db, dir).exportActiveProfile()).contents;
      payload = ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
    });
    String reseal() => ProfileExport.seal(payload, schemaVersion: AppDatabase.currentSchemaVersion);
    void rejected(String why, {String? mentions}) {
      try {
        ProfileExport.parse(reseal(), currentSchemaVersion: AppDatabase.currentSchemaVersion);
        fail('expected rejection: $why');
      } on ExportRejected catch (e) {
        expect(e.kind, RestoreRejection.invalidContents, reason: why);
        if (mentions != null) expect(e.message, contains(mentions), reason: why);
      }
    }
    List<Map> rows(String key) => (payload[key] as List).cast<Map>();

    test('a schedule of an unknown task', () {
      rows('schedules').first
        ..['subjectId'] = 'ghost'
        ..['id'] = 'task:ghost';
      rejected('dangling schedule', mentions: 'unknown item');
    });
    test('an exception of an item without a schedule', () {
      rows('occurrenceExceptions').first
        ..['subjectType'] = 'task'
        ..['subjectId'] = rows('tasks').firstWhere((t) => t['title'] == 'Pay rent')['id']
        ..['id'] = 'whatever';
      rejected('exception without schedule');
    });
    test('an event in an unknown calendar', () {
      rows('events').first['calendarId'] = 'ghost';
      rejected('dangling calendar', mentions: 'calendar');
    });
    test('an invalid schedule (end before start)', () {
      rows('schedules').firstWhere((s) => s['subjectType'] == 'event')['endTime'] = '08:00';
      rejected('invalid schedule', mentions: 'invalid schedule');
    });
    test('a reminder of an unknown event', () {
      rows('reminders').first['subjectId'] = 'ghost';
      rejected('dangling reminder');
    });
    test('a duplicate event id', () {
      (payload['events'] as List).add(Map.of(rows('events').first));
      rejected('duplicate');
    });
  });

  test('a schema-3 file (before planning) still restores', () async {
    await svc.tasks.create('Old task');
    final text = (await DriftDataTransferService(host.db, dir).exportActiveProfile()).contents;
    final payload = ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
    for (final k in ['calendars', 'events', 'schedules', 'occurrenceExceptions', 'occurrenceCompletions', 'reminders']) {
      payload.remove(k);
    }
    // A v3 export had no counts for these tables either.
    final env = (jsonDecode(ProfileExport.seal(payload, schemaVersion: 3)) as Map).cast<String, Object?>();
    final counts = (env['counts'] as Map)..removeWhere((k, _) => !payload.containsKey(k));
    env['counts'] = counts;
    final parsed = ProfileExport.parse(jsonEncode(env), currentSchemaVersion: AppDatabase.currentSchemaVersion);
    expect(parsed.records['schedule'], isEmpty);
    expect(parsed.taskCount, 1);
  });

  group('restore into the same profile covers the new tables', () {
    late DriftDataTransferService transfer;
    setUp(() => transfer = DriftDataTransferService(host.db, dir));

    test('identical with planning data; a file-only event and its schedule '
        'are added by merge (b)', () async {
      await seedPlanning();
      final file = (await transfer.exportActiveProfile()).contents;
      expect(await transfer.inspect(file), isA<RestoreIdentical>());

      // The device loses the event (as if it were never created here).
      final db = host.db;
      await (db.delete(db.reminders)).go();
      await (db.delete(db.occurrenceExceptions)).go();
      await (db.delete(db.schedules)..where((s) => s.subjectType.equals('event'))).go();
      await (db.delete(db.events)).go();
      final p = await transfer.inspect(file) as RestoreDifferent;
      expect(p.diff.onlyInFile, 4); // event, its schedule, exception, reminder

      final r = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: true));
      expect((r as RestoredInto).added, 4);
      expect(await transfer.inspect(file), isA<RestoreIdentical>());
      // Sync sees every added row (LF-INV-OUTBOX-001).
      final types = (await db.select(db.outbox).get()).map((o) => o.entityType).toSet();
      expect(types, containsAll(['event', 'schedule', 'exception', 'reminder']));
    });

    test('a dependent row is not written without its item: merge (a) only',
        () async {
      final ids = await seedPlanning();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      // The device never had "Pay rent" (nor its schedule).
      await (db.delete(db.schedules)..where((s) => s.subjectId.equals(ids['other']!))).go();
      await (db.delete(db.tasks)..where((t) => t.id.equals(ids['other']!))).go();

      final r = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: false));
      expect(r, isA<RestoredInto>(), reason: '$r');
      final orphans = await (db.select(db.schedules)..where((s) => s.subjectId.equals(ids['other']!))).get();
      expect(orphans, isEmpty);
    });

    test('merge (a): a newer event pointing to a calendar that is only in the '
        'file keeps no calendar (no dangling reference)', () async {
      await seedPlanning();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      // On this device the event is older and has no calendar; the calendar
      // does not exist here.
      await (db.update(db.events)..where((e) => e.id.equals('ev-1'))).write(EventsCompanion(
          calendarId: const Value(null), updatedAt: Value(t0.subtract(const Duration(days: 1)))));
      await (db.delete(db.calendars)).go();

      final r = await transfer.restore(file,
          choice: const RestoreChoice.merge(takeNewer: true, addMissing: false));
      expect(r, isA<RestoredInto>(), reason: '$r');
      final ev = await (db.select(db.events)..where((e) => e.id.equals('ev-1'))).getSingle();
      expect(ev.title, 'Team meeting');
      expect(ev.calendarId, isNull);
      expect(await db.select(db.calendars).get(), isEmpty);
      // The store still exports as a valid file.
      final again = (await transfer.exportActiveProfile()).contents;
      expect(() => ProfileExport.parse(again, currentSchemaVersion: AppDatabase.currentSchemaVersion),
          returnsNormally);
    });

    test('overwrite trashes device-only planning rows (tombstones)', () async {
      await seedPlanning();
      final file = (await transfer.exportActiveProfile()).contents;
      final db = host.db;
      await db.into(db.events).insert(sync(({required workspaceId, required ownerId, required createdAt, required updatedAt}) =>
          EventsCompanion.insert(id: 'ev-device', workspaceId: workspaceId, ownerId: ownerId,
              createdAt: createdAt, updatedAt: updatedAt, title: 'Only here')));
      final r = await transfer.restore(file, choice: const RestoreChoice.overwrite());
      expect((r as RestoredInto).removed, 1);
      final gone = await (db.select(db.events)..where((e) => e.id.equals('ev-device'))).getSingle();
      expect(gone.deletedAt, isNotNull);
      // Undo brings it back.
      await transfer.undoLastRestore();
      final back = await (db.select(db.events)..where((e) => e.id.equals('ev-device'))).getSingle();
      expect(back.deletedAt, isNull);
    });
  });
}
