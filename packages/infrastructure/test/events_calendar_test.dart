// P02 T5 (ADR-0031): events, calendars and conflicts on the real store.
//   LF-INV-CAL-001  an event never shares the id of a task
//   LF-INV-CAL-002  all-day items never conflict (D7)
//   FR-PLAN-11 / AC-08.1  conflicts are deterministic and symmetric
//   D4  only this occurrence: skip, cancel, move, edit
//   D6  tasks stay tasks in the calendar
//   LF-INV-PLAN-013  a repeating event keeps its wall clock across DST
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
SchedulePointInput at(LocalDate day, int h, int m, [String zone = 'Asia/Ho_Chi_Minh']) =>
    SchedulePointInput.at(day, TimeOfDayValue(h, m), zone);

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late DriftEventService events;
  late DriftCalendarService calendars;
  late DriftTaskScheduling scheduling;
  late DriftCalendarQueries cal;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_events_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    final db = host.db;
    final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    events = DriftEventService(db, gw);
    calendars = DriftCalendarService(db, gw);
    scheduling = DriftTaskScheduling(db, gw);
    final agenda = DriftAgendaQueries(db, TestTime(Instant(DateTime.utc(2026, 11, 9, 1)), 'Asia/Ho_Chi_Minh'));
    cal = DriftCalendarQueries(db, agenda);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  Future<String> newEvent(EventInput input) async {
    final r = await events.create(input);
    expect(r, isA<CommandOk>(), reason: '$r');
    return (r as CommandOk).entityId;
  }

  final mon = d(2026, 11, 9);

  group('events', () {
    test('create, read back, update; outbox rows for event and schedule', () async {
      final c = (await calendars.create('Work', color: 0xFF3F51B5) as CommandOk).entityId;
      final id = await newEvent(EventInput(
        title: 'Team meeting',
        start: at(mon, 9, 0),
        end: at(mon, 10, 0),
        location: 'Room 2',
        calendarId: c,
        repeat: const RepeatInput(frequency: RepeatFrequency.weekly, end: RepeatTimes(4)),
      ));
      final back = (await events.details(id))!;
      expect(back.input.title, 'Team meeting');
      expect(back.input.start, at(mon, 9, 0));
      expect(back.input.location, 'Room 2');
      expect(back.input.calendarId, c);
      expect((back.input.repeat!.end as RepeatTimes).count, 4);

      final db = host.db;
      final op = (await (db.select(db.auditLog)..where((a) => a.action.equals('CreateEvent'))).getSingle()).operationId;
      expect((await (db.select(db.outbox)..where((o) => o.operationId.equals(op))).get()).map((o) => o.entityType).toSet(),
          {'event', 'schedule'});

      expect(await events.update(id, EventInput(title: 'Team sync', start: at(mon, 9, 30), end: at(mon, 10, 0))),
          isA<CommandOk>());
      final after = (await events.details(id))!;
      expect(after.input.title, 'Team sync');
      expect(after.input.repeat, isNull);
      expect(after.input.calendarId, isNull);
    });

    test('invalid input is returned with a message; nothing written', () async {
      for (final (input, why) in [
        (EventInput(title: '  ', start: at(mon, 9, 0)), 'title'),
        (EventInput(title: 'x', start: at(mon, 10, 0), end: at(mon, 9, 0)), 'end is before the start'),
        (EventInput(title: 'x', start: at(mon, 9, 0), calendarId: 'ghost'), 'unknown calendar'),
        (EventInput(title: 'x', start: SchedulePointInput.date(mon), end: at(mon, 9, 0)), 'both have a time'),
      ]) {
        final r = await events.create(input);
        expect((r as CommandFailure).reason, contains(why), reason: why);
      }
      expect(await host.db.select(host.db.events).get(), isEmpty);
      expect(await host.db.select(host.db.schedules).get(), isEmpty);
    });

    test('LF-INV-CAL-001: an event cannot take the id of a task; a deadline is refused', () async {
      final taskId = (await svc.tasks.create('A task') as CommandOk).entityId;
      final p = (await ProfileStore(host.db).getActiveProfile())!;
      Future<CommandResult> raw(String id, Map<String, Object?> schedule) =>
          DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db)).execute(
              Command(
                operationId: 'raw-$id-${schedule.length}',
                actor: ActorRef(ActorKind.owner, p.profileId.value),
                workspaceId: p.activeWorkspaceId.value,
                type: 'CreateEvent',
                payload: {'op': 'create', 'id': id, 'title': 'Sneaky', 'schedule': schedule},
                issuedAt: Instant.now(),
              ),
              const EventCommandHandler());
      final fields = scheduleFieldsJson('event', taskId, tk.ScheduleSpec(start: tk.DatePoint(mon)), null);
      final r = await raw(taskId, fields);
      expect((r as CommandFailure).reason, contains('id of a task'));
      final withDeadline = scheduleFieldsJson('event', 'ev-x',
          tk.ScheduleSpec(start: tk.DatePoint(mon), deadline: tk.DatePoint(mon)), null);
      final r2 = await raw('ev-x', withDeadline);
      expect((r2 as CommandFailure).reason, contains('no deadline'));
      expect(await host.db.select(host.db.events).get(), isEmpty);
    });

    test('only this occurrence (D4): skip, cancel, move, edit, and undo', () async {
      final id = await newEvent(EventInput(
          title: 'Standup', start: at(mon, 9, 0), end: at(mon, 9, 15), location: 'Room 1',
          repeat: const RepeatInput(frequency: RepeatFrequency.daily, end: RepeatTimes(5))));
      expect(await events.changeOccurrence(id, d(2026, 11, 10), const SkipEventOccurrence()), isA<CommandOk>());
      expect(await events.changeOccurrence(id, d(2026, 11, 11), const CancelEventOccurrence()), isA<CommandOk>());
      expect(await events.changeOccurrence(id, d(2026, 11, 12),
          MoveEventOccurrence(d(2026, 11, 20), toTime: TimeOfDayValue(14, 0))), isA<CommandOk>());
      expect(await events.changeOccurrence(id, d(2026, 11, 13),
          const EditEventOccurrence(title: 'Standup (demo)', location: 'Hall')), isA<CommandOk>());

      final r = await cal.range(d(2026, 11, 9), d(2026, 11, 30));
      final byOriginal = {for (final e in r.events) e.originalDate: e};
      expect(byOriginal.keys, unorderedEquals([d(2026, 11, 9), d(2026, 11, 11), d(2026, 11, 12), d(2026, 11, 13)]));
      expect(byOriginal[d(2026, 11, 11)]!.isCancelled, isTrue);
      expect(byOriginal[d(2026, 11, 12)]!.date, d(2026, 11, 20));
      expect(byOriginal[d(2026, 11, 12)]!.start.time, TimeOfDayValue(14, 0));
      expect(byOriginal[d(2026, 11, 12)]!.end!.time, TimeOfDayValue(14, 15)); // length kept
      expect(byOriginal[d(2026, 11, 13)]!.title, 'Standup (demo)');
      expect(byOriginal[d(2026, 11, 13)]!.location, 'Hall');
      expect(byOriginal[d(2026, 11, 9)]!.location, 'Room 1');

      expect(await events.changeOccurrence(id, d(2026, 11, 10), null), isA<CommandOk>());
      expect((await cal.range(d(2026, 11, 10), d(2026, 11, 10))).events, hasLength(1));
      final bad = await events.changeOccurrence(id, d(2026, 12, 1), const SkipEventOccurrence());
      expect((bad as CommandFailure).reason, contains('not an occurrence'));
    });

    test('cancel the whole event, trash and restore', () async {
      final id = await newEvent(EventInput(title: 'Gym', start: at(mon, 18, 0), end: at(mon, 19, 0),
          repeat: const RepeatInput(frequency: RepeatFrequency.weekly)));
      expect(await events.setCancelled(id, cancelled: true), isA<CommandOk>());
      expect((await cal.range(mon, d(2026, 11, 30))).events.every((e) => e.isCancelled), isTrue);
      expect(await events.setCancelled(id, cancelled: true), isA<CommandFailure>());
      expect(await events.setCancelled(id, cancelled: false), isA<CommandOk>());
      expect(await events.trash(id), isA<CommandOk>());
      expect((await cal.range(mon, d(2026, 11, 30))).events, isEmpty);
      expect(await events.details(id), isNull);
      expect(await events.restore(id), isA<CommandOk>());
      expect((await cal.range(mon, d(2026, 11, 30))).events, hasLength(4));
    });

    test('LF-INV-PLAN-013: a daily 09:00 event in Berlin stays 09:00 across DST', () async {
      await newEvent(EventInput(
          title: 'Call', start: at(d(2026, 3, 27), 9, 0, 'Europe/Berlin'), end: at(d(2026, 3, 27), 9, 30, 'Europe/Berlin'),
          repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      final r = await cal.range(d(2026, 3, 27), d(2026, 3, 31));
      expect(r.events.map((e) => e.start.time), everyElement(TimeOfDayValue(9, 0)));
      final utcHours = [
        for (final e in r.events)
          tk.resolveWallClock(ZonedWallClock(e.start.date, e.start.time!, e.start.zone!)).utc.hour
      ];
      expect(utcHours, [8, 8, 7, 7, 7]);
    });
  });

  group('calendars', () {
    test('list, rename; trashing keeps its events without a calendar', () async {
      final work = (await calendars.create('Work') as CommandOk).entityId;
      await calendars.create('Family');
      expect((await calendars.watchCalendars().first).map((c) => c.name), ['Family', 'Work']);
      expect(await calendars.update(work, name: 'Office', color: 0xFF000000), isA<CommandOk>());
      final id = await newEvent(EventInput(title: 'Review', start: at(mon, 15, 0), calendarId: work));

      expect(await calendars.trash(work), isA<CommandOk>());
      expect((await calendars.watchCalendars().first).map((c) => c.name), ['Family']);
      final e = (await events.details(id))!;
      expect(e.input.calendarId, isNull);
      final db = host.db;
      final op = (await (db.select(db.auditLog)..where((a) => a.action.equals('TrashCalendar'))).getSingle()).operationId;
      expect((await (db.select(db.outbox)..where((o) => o.operationId.equals(op))).get()).map((o) => o.entityType).toSet(),
          {'calendar', 'event'});
      expect((await calendars.create(' ') as CommandFailure).reason, contains('name'));
    });
  });

  group('conflicts (D7, FR-PLAN-11)', () {
    test('events and tasks; only timed, open, overlapping ones; deterministic', () async {
      final meeting = await newEvent(EventInput(title: 'Meeting', start: at(mon, 9, 0), end: at(mon, 10, 0),
          repeat: const RepeatInput(frequency: RepeatFrequency.weekly)));
      // A task 09:30–10:00 on Monday only: conflicts with the meeting that day.
      final call = (await svc.tasks.create('Client call') as CommandOk).entityId;
      await scheduling.setSchedule(call, TaskScheduleInput(start: at(mon, 9, 30), end: at(mon, 10, 0)));
      // Touching (10:00–11:00): no conflict.
      final next = (await svc.tasks.create('Next') as CommandOk).entityId;
      await scheduling.setSchedule(next, TaskScheduleInput(start: at(mon, 10, 0), end: at(mon, 11, 0)));
      // All-day event that day: never a conflict (LF-INV-CAL-002).
      await newEvent(EventInput(title: 'Holiday', start: SchedulePointInput.date(mon)));
      // A done task in the same slot: no conflict.
      final done = (await svc.tasks.create('Done thing') as CommandOk).entityId;
      await scheduling.setSchedule(done, TaskScheduleInput(start: at(mon, 9, 0), end: at(mon, 9, 45)));
      await svc.tasks.complete(done, withDescendants: false);

      final r = await cal.range(mon, d(2026, 11, 22));
      expect(r.conflicts, [_sorted(ConflictView(eventOccurrenceKey(meeting, mon), taskOccurrenceKey(call, mon)))]);
      expect(r.tasks.map((t) => t.title), containsAll(['Client call', 'Next', 'Done thing'])); // D6: tasks shown
      expect(r.events.where((e) => e.title == 'Meeting'), hasLength(2));
      // Same answer every time (AC-08.1).
      final again = await cal.range(mon, d(2026, 11, 22));
      expect(again.conflicts, r.conflicts);
    });

    test('a cancelled occurrence or event never conflicts', () async {
      final a = await newEvent(EventInput(title: 'A', start: at(mon, 9, 0), end: at(mon, 10, 0),
          repeat: const RepeatInput(frequency: RepeatFrequency.daily, end: RepeatTimes(2))));
      final b = await newEvent(EventInput(title: 'B', start: at(mon, 9, 30), end: at(mon, 10, 30),
          repeat: const RepeatInput(frequency: RepeatFrequency.daily, end: RepeatTimes(2))));
      expect((await cal.range(mon, d(2026, 11, 10))).conflicts, hasLength(2));
      await events.changeOccurrence(a, mon, const CancelEventOccurrence());
      expect((await cal.range(mon, d(2026, 11, 10))).conflicts, hasLength(1));
      await events.setCancelled(b, cancelled: true);
      expect((await cal.range(mon, d(2026, 11, 10))).conflicts, isEmpty);
    });

    test('the stream follows changes', () async {
      final seen = <int>[];
      final sub = cal.watchRange(mon, mon).listen((r) => seen.add(r.events.length));
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await newEvent(EventInput(title: 'New', start: at(mon, 8, 0)));
      for (var i = 0; i < 100 && (seen.isEmpty || seen.last != 1); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(seen.last, 1);
    });
  });
}

/// The ConflictView with its keys in order (the query sorts them).
ConflictView _sorted(ConflictView c) =>
    c.first.compareTo(c.second) <= 0 ? c : ConflictView(c.second, c.first);
