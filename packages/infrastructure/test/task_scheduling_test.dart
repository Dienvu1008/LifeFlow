// P02 T4 (ADR-0030): scheduling tasks on the real store, through the gateway.
//   AC-06.1  "after 10" gives exactly 10 across any windows (real store)
//   AC-06.2  regenerating is identical
//   AC-06.3  the number of stored rows does not grow with occurrences
//   AC-06.4 / LF-INV-PLAN-011  an exception survives a rule edit
//   D4       only this occurrence: skip / move / undo the change
//   D5       one occurrence done; the task stays open
//   Today / Upcoming in the device zone, overdue one-offs, trashed tasks
//   LF-INV-PLAN-010  truncation is reported
//   LF-INV-VER-001 / OUTBOX-001  the task version moves; each changed row
//            has an outbox row
import 'dart:async';
import 'dart:io';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'fake_auth.dart';
import 'profile_harness.dart';

class TestTime implements DeviceTime {
  TestTime(this.at, this.tz);
  Instant at;
  String tz;
  @override
  Instant now() => at;
  @override
  String zone() => tz;
}

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late DriftTaskScheduling scheduling;
  late DriftAgendaQueries agenda;
  late TestTime time;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_sched_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    scheduling = DriftTaskScheduling(host.db, gw);
    // Monday 2026-11-09, 08:00 in Ho Chi Minh City.
    time = TestTime(Instant(DateTime.utc(2026, 11, 9, 1)), 'Asia/Ho_Chi_Minh');
    agenda = DriftAgendaQueries(host.db, time);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  Future<String> task(String title) async => (await svc.tasks.create(title) as CommandOk).entityId;
  Future<Task> row(String id) => (host.db.select(host.db.tasks)..where((t) => t.id.equals(id))).getSingle();
  Future<List<LocalDate>> datesIn(LocalDate a, LocalDate b, [String? taskId]) async => [
        for (final i in (await agenda.range(a, b)).items)
          if (taskId == null || i.taskId == taskId) i.originalDate
      ];

  const monWed10 = RepeatInput(
    frequency: RepeatFrequency.weekly,
    weekdays: {Weekday.monday, Weekday.wednesday},
    end: RepeatTimes(10),
  );
  final expected10 = [
    d(2026, 11, 9), d(2026, 11, 11), d(2026, 11, 16), d(2026, 11, 18), d(2026, 11, 23),
    d(2026, 11, 25), d(2026, 11, 30), d(2026, 12, 2), d(2026, 12, 7), d(2026, 12, 9),
  ];

  group('set and clear a schedule', () {
    test('round trip; the task version moves; outbox rows for task and schedule', () async {
      final id = await task('Gym');
      final v0 = (await row(id)).version;
      final input = TaskScheduleInput(
        start: SchedulePointInput.at(d(2026, 11, 9), TimeOfDayValue(18, 0), 'Asia/Ho_Chi_Minh'),
        end: SchedulePointInput.at(d(2026, 11, 9), TimeOfDayValue(19, 0), 'Asia/Ho_Chi_Minh'),
        repeat: monWed10,
      );
      expect(await scheduling.setSchedule(id, input), isA<CommandOk>());
      final back = await scheduling.scheduleOf(id);
      expect(back!.start, input.start);
      expect(back.end, input.end);
      expect(back.repeat!.weekdays, {Weekday.monday, Weekday.wednesday});
      expect(back.repeat!.end, isA<RepeatTimes>());
      expect((await row(id)).version, v0 + 1);
      final db = host.db;
      final op = (await (db.select(db.auditLog)..where((a) => a.action.equals('SetTaskSchedule'))).getSingle())
          .operationId;
      final out = await (db.select(db.outbox)..where((o) => o.operationId.equals(op))).get();
      expect(out.map((o) => o.entityType).toSet(), {'task', 'schedule'});

      expect(await scheduling.setSchedule(id, null), isA<CommandOk>());
      expect(await scheduling.scheduleOf(id), isNull);
      // A tombstone, not a hard delete (SYNC-004).
      expect((await db.select(db.schedules).getSingle()).deletedAt, isNotNull);
      expect(await datesIn(d(2026, 11, 1), d(2026, 12, 31)), isEmpty);
      // Set again: the row comes back to life.
      await scheduling.setSchedule(id, input);
      expect(await datesIn(d(2026, 11, 1), d(2026, 12, 31)), expected10);
    });

    test('invalid input is returned, not thrown, and writes nothing', () async {
      final id = await task('Bad');
      final v0 = (await row(id)).version;
      for (final (input, why) in [
        (TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9)), end: SchedulePointInput.date(d(2026, 11, 8))),
            'end is before the start'),
        (TaskScheduleInput(start: SchedulePointInput.at(d(2026, 11, 9), TimeOfDayValue(9, 0), 'Nowhere/City')),
            'unknown time zone'),
        (const TaskScheduleInput(), 'set a start'),
        (TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9)),
            repeat: const RepeatInput(frequency: RepeatFrequency.daily, interval: 0)), 'repeat every'),
      ]) {
        final r = await scheduling.setSchedule(id, input);
        expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
        expect(r.reason, contains(why));
      }
      expect((await row(id)).version, v0);
      expect(await host.db.select(host.db.schedules).get(), isEmpty);
    });

    test('a tampered command payload is checked again by the handler', () async {
      final id = await task('Tampered');
      final t = await row(id);
      final p = (await ProfileStore(host.db).getActiveProfile())!;
      final fields = scheduleFieldsJson('task', id, tk.ScheduleSpec(start: tk.DatePoint(d(2026, 11, 9))), null)
        ..['lastDate'] = '2030-01-01'; // does not match the schedule
      final r = await DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db)).execute(
          Command(
            operationId: 'tamper-1',
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: 'SetTaskSchedule',
            payload: {'op': 'setSchedule', 'id': id, 'schedule': fields},
            expectedVersion: Version(t.version),
            issuedAt: Instant.now(),
          ),
          TaskCommandHandler());
      expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
      expect(await host.db.select(host.db.schedules).get(), isEmpty);
      expect((await row(id)).version, t.version); // rolled back
    });
  });

  group('AC-06.x on the real store', () {
    late String id;
    setUp(() async {
      id = await task('Practice');
      await scheduling.setSchedule(id, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9)), repeat: monWed10));
    });

    test('AC-06.1/06.2: exactly 10 across windows, identical when repeated', () async {
      final all = [
        ...await datesIn(d(2026, 11, 1), d(2026, 11, 15)),
        ...await datesIn(d(2026, 11, 16), d(2026, 11, 30)),
        ...await datesIn(d(2026, 12, 1), d(2027, 3, 1)),
      ];
      expect(all, expected10);
      expect(await datesIn(d(2026, 11, 1), d(2027, 3, 1)), expected10);
    });

    test('AC-06.3: one stored schedule row, however many occurrences', () async {
      expect(await host.db.select(host.db.schedules).get(), hasLength(1));
      await scheduling.setSchedule(id, TaskScheduleInput(
          start: SchedulePointInput.date(d(2026, 11, 9)), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      expect((await agenda.range(d(2026, 11, 9), d(2027, 11, 9))).items.length, greaterThan(300));
      expect(await host.db.select(host.db.schedules).get(), hasLength(1));
    });

    test('AC-06.4 / LF-INV-PLAN-011: a skip survives a rule edit that keeps its date', () async {
      expect(await scheduling.changeOccurrence(id, d(2026, 11, 16), const SkipThisOccurrence()), isA<CommandOk>());
      expect(await datesIn(d(2026, 11, 1), d(2026, 12, 31)), isNot(contains(d(2026, 11, 16))));
      // Edit: 12 times instead of 10.
      await scheduling.setSchedule(id, TaskScheduleInput(
          start: SchedulePointInput.date(d(2026, 11, 9)),
          repeat: const RepeatInput(frequency: RepeatFrequency.weekly,
              weekdays: {Weekday.monday, Weekday.wednesday}, end: RepeatTimes(12))));
      final dates = await datesIn(d(2026, 11, 1), d(2027, 1, 31));
      expect(dates, hasLength(11)); // 12 minus the skipped one
      expect(dates, isNot(contains(d(2026, 11, 16))));
    });
  });

  group('only this occurrence (D4)', () {
    late String id;
    setUp(() async {
      id = await task('Water plants');
      await scheduling.setSchedule(id, TaskScheduleInput(
          start: SchedulePointInput.at(d(2026, 11, 9), TimeOfDayValue(7, 0), 'Asia/Ho_Chi_Minh'),
          repeat: RepeatInput(frequency: RepeatFrequency.weekly, end: RepeatUntil(d(2026, 12, 31)))));
    });

    test('move one: it shows on the new date and time, even after the series ends', () async {
      final r = await scheduling.changeOccurrence(id, d(2026, 11, 30),
          MoveThisOccurrence(d(2027, 1, 20), toTime: TimeOfDayValue(9, 30)));
      expect(r, isA<CommandOk>(), reason: '$r');
      expect(await datesIn(d(2026, 11, 29), d(2026, 12, 1)), isEmpty);
      final there = (await agenda.range(d(2027, 1, 20), d(2027, 1, 20))).items.single;
      expect(there.originalDate, d(2026, 11, 30));
      expect(there.isMoved, isTrue);
      expect(there.start!.time, TimeOfDayValue(9, 30));
      // Undo the change.
      expect(await scheduling.changeOccurrence(id, d(2026, 11, 30), null), isA<CommandOk>());
      expect(await datesIn(d(2026, 11, 29), d(2026, 12, 1)), [d(2026, 11, 30)]);
      expect((await agenda.range(d(2027, 1, 20), d(2027, 1, 20))).items, isEmpty);
    });

    test('a date that is not an occurrence, or a task without a repeat, is refused', () async {
      final r = await scheduling.changeOccurrence(id, d(2026, 11, 10), const SkipThisOccurrence());
      expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
      expect(r.reason, contains('not an occurrence'));
      final once = await task('Once');
      await scheduling.setSchedule(once, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9))));
      final r2 = await scheduling.changeOccurrence(once, d(2026, 11, 9), const SkipThisOccurrence());
      expect((r2 as CommandFailure).reason, contains('does not repeat'));
      final r3 = await scheduling.changeOccurrence(id, d(2026, 11, 16), null);
      expect((r3 as CommandFailure).reason, contains('no change'));
    });

    test('a date-only task cannot move to a time', () async {
      final dateOnly = await task('Date only');
      await scheduling.setSchedule(dateOnly, TaskScheduleInput(
          start: SchedulePointInput.date(d(2026, 11, 9)), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      final r = await scheduling.changeOccurrence(dateOnly, d(2026, 11, 10),
          MoveThisOccurrence(d(2026, 11, 11), toTime: TimeOfDayValue(9, 0)));
      expect((r as CommandFailure).reason, contains('without a start time'));
    });
  });

  group('one occurrence done (D5)', () {
    test('done and open again; the task stays open; the agenda shows it', () async {
      final id = await task('Read');
      await scheduling.setSchedule(id, TaskScheduleInput(
          start: SchedulePointInput.date(d(2026, 11, 9)), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      expect(await scheduling.setOccurrenceDone(id, d(2026, 11, 10), done: true), isA<CommandOk>());
      final items = (await agenda.range(d(2026, 11, 9), d(2026, 11, 11))).items;
      expect(items.map((i) => i.isDone), [false, true, false]);
      expect((await row(id)).status, isNot('done'));
      // Twice is refused; open again works.
      expect(await scheduling.setOccurrenceDone(id, d(2026, 11, 10), done: true), isA<CommandFailure>());
      expect(await scheduling.setOccurrenceDone(id, d(2026, 11, 10), done: false), isA<CommandOk>());
      expect((await agenda.range(d(2026, 11, 10), d(2026, 11, 10))).items.single.isDone, isFalse);
      // A tombstone keeps the history for sync.
      expect((await host.db.select(host.db.occurrenceCompletions).getSingle()).deletedAt, isNotNull);
    });

    test('a one-off task is done when the task is done', () async {
      final id = await task('Once');
      await scheduling.setSchedule(id, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9))));
      await svc.tasks.complete(id, withDescendants: false);
      expect((await agenda.range(d(2026, 11, 9), d(2026, 11, 9))).items.single.isDone, isTrue);
      final r = await scheduling.setOccurrenceDone(id, d(2026, 11, 9), done: true);
      expect((r as CommandFailure).reason, contains('does not repeat'));
    });
  });

  group('Today and Upcoming (device zone)', () {
    test('today is the date in the device zone', () async {
      final id = await task('Late call');
      await scheduling.setSchedule(id, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 10))));
      // 2026-11-09 23:30 UTC is already the 10th in Ho Chi Minh City (UTC+7).
      time.at = Instant(DateTime.utc(2026, 11, 9, 23, 30));
      expect((await agenda.watchToday().first).items.map((i) => i.title), ['Late call']);
      time.tz = 'UTC';
      expect((await agenda.watchToday().first).items, isEmpty);
    });

    test('Today: today\'s occurrences plus overdue one-offs, first', () async {
      final daily = await task('Daily');
      await scheduling.setSchedule(daily, TaskScheduleInput(
          start: SchedulePointInput.date(d(2026, 11, 1)), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      final late = await task('Overdue report');
      await scheduling.setSchedule(late, TaskScheduleInput(end: SchedulePointInput.date(d(2026, 11, 5))));
      final finished = await task('Finished');
      await scheduling.setSchedule(finished, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 3))));
      await svc.tasks.complete(finished, withDescendants: false);
      final future = await task('Future');
      await scheduling.setSchedule(future, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 20))));

      final today = (await agenda.watchToday().first).items;
      expect(today.map((i) => (i.title, i.isOverdue)), [('Overdue report', true), ('Daily', false)]);
      final upcoming = (await agenda.watchUpcoming(days: 14).first).items;
      expect(upcoming.where((i) => i.title == 'Future'), hasLength(1));
      expect(upcoming.where((i) => i.title == 'Daily'), hasLength(14));
      expect(upcoming.any((i) => i.date == d(2026, 11, 9)), isFalse); // not today
    });

    test('timed items are ordered by time, untimed first', () async {
      for (final (title, h) in [('Lunch', 12), ('Standup', 9)]) {
        final id = await task(title);
        await scheduling.setSchedule(id, TaskScheduleInput(
            start: SchedulePointInput.at(d(2026, 11, 9), TimeOfDayValue(h, 0), 'Asia/Ho_Chi_Minh')));
      }
      final allDay = await task('All day');
      await scheduling.setSchedule(allDay, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9))));
      expect((await agenda.watchToday().first).items.map((i) => i.title), ['All day', 'Standup', 'Lunch']);
    });

    test('a trashed task leaves the agenda; the stream follows changes', () async {
      final id = await task('Temp');
      final seen = <int>[];
      final sub = agenda.watchToday().listen((a) => seen.add(a.items.length));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await scheduling.setSchedule(id, TaskScheduleInput(start: SchedulePointInput.date(d(2026, 11, 9))));
      await _untilCond(() => seen.isNotEmpty && seen.last == 1);
      await svc.tasks.trash(id);
      await _untilCond(() => seen.last == 0);
    });
  });

  test('LF-INV-PLAN-010: a too-long range reports truncation', () async {
    final id = await task('Daily');
    await scheduling.setSchedule(id, TaskScheduleInput(
        start: SchedulePointInput.date(d(2026, 1, 1)), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
    final a = await agenda.range(d(2026, 1, 1), d(2027, 12, 31));
    expect(a.truncated, isTrue);
    expect(a.items, hasLength(400));
    expect((await agenda.range(d(2026, 1, 1), d(2026, 1, 31))).truncated, isFalse);
  });

  group('T6a: task list, device settings, zones', () {
    test('watchTasks carries each task\'s live schedule', () async {
      final a = await task('Planned');
      final b = await task('Plain');
      final input = TaskScheduleInput(
        start: SchedulePointInput.at(d(2026, 11, 9), TimeOfDayValue(18, 0), 'Asia/Ho_Chi_Minh'),
        repeat: monWed10,
      );
      await scheduling.setSchedule(a, input);
      var list = await svc.queries.watchTasks().first;
      expect(list.map((t) => t.id), [a, b]); // order kept by the join
      final s = list.first.schedule!;
      expect(s.start, input.start);
      expect(s.repeat!.weekdays, monWed10.weekdays);
      expect(list.last.schedule, isNull);
      // A cleared schedule (tombstone) is not shown, and the task stays once.
      await scheduling.setSchedule(a, null);
      list = await svc.queries.watchTasks().first;
      expect(list.map((t) => t.id), [a, b]);
      expect(list.first.schedule, isNull);
    });

    test('planning settings: defaults, round trip, clamped, and the limits cache', () async {
      final settings = DirectorySettingsService(dir);
      expect(await settings.planningSettings(), const PlanningSettings());
      await settings.setPlanningSettings(const PlanningSettings(
          maxOccurrences: 99999,
          maxWindowDays: 1,
          defaultMonthEnd: MonthEndChoice.lastDay,
          firstDayOfWeek: Weekday.sunday));
      const stored = PlanningSettings(
          maxOccurrences: 5000,
          maxWindowDays: 31,
          defaultMonthEnd: MonthEndChoice.lastDay,
          firstDayOfWeek: Weekday.sunday);
      expect(settings.limitsCache.value, stored);
      // A new service (next start) reads the same values.
      final again = DirectorySettingsService(dir);
      expect(again.limitsCache.value, const PlanningSettings());
      expect(await again.planningSettings(), stored);
      expect(again.limitsCache.limits.maxWindowDays, 31);
    });

    test('the agenda uses the limits from the settings (D1)', () async {
      final settings = DirectorySettingsService(dir);
      final limited = DriftAgendaQueries(host.db, time, limits: () => settings.limitsCache.limits);
      final id = await task('Daily');
      await scheduling.setSchedule(id, TaskScheduleInput(
          start: SchedulePointInput.date(d(2026, 1, 1)), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      expect((await limited.range(d(2026, 1, 1), d(2026, 12, 31))).truncated, isFalse); // 365 < 400 days
      await settings.setPlanningSettings(const PlanningSettings(maxWindowDays: 100));
      final a = await limited.range(d(2026, 1, 1), d(2026, 12, 31));
      expect(a.truncated, isTrue);
      expect(a.items, hasLength(100));
      await settings.setPlanningSettings(const PlanningSettings(maxOccurrences: 150, maxWindowDays: 1100));
      expect((await limited.range(d(2026, 1, 1), d(2026, 12, 31))).items, hasLength(150));
    });

    test('device zone: a known name is kept (legacy aliases too), otherwise UTC', () {
      const zones = KernelZoneCatalog();
      expect(zones.deviceZoneOr('Asia/Ho_Chi_Minh'), 'Asia/Ho_Chi_Minh');
      expect(zones.deviceZoneOr('Asia/Saigon'), 'Asia/Saigon'); // what Windows reports
      expect(zones.deviceZoneOr('Nowhere/City'), 'UTC');
      expect(zones.deviceZoneOr(null), 'UTC');
      expect(zones.zoneNames(), contains('Europe/Berlin'));
      expect(zones.zoneNames(), orderedEquals([...zones.zoneNames()]..sort()));
    });
  });
}

Future<void> _wait() => Future<void>.delayed(const Duration(milliseconds: 20));

/// Waits (up to 2 s) for [cond] while the stream delivers.
Future<void> _untilCond(bool Function() cond) async {
  for (var i = 0; i < 100 && !cond(); i++) {
    await _wait();
  }
  expect(cond(), isTrue);
}
