// P06c E2 (ADR-0096): extra times show wherever the plan is read.
//   agenda     a task's extra time is an item of its own (own extraId, own key),
//              next to the series; two on one day stay two; outside the window
//              it is absent; a task without a schedule shows it; a done tick
//              (or a done task) shows done; a trashed task shows nothing
//   calendar   an event's extra time is an event item; a cancelled event's is
//              marked cancelled and has no conflict; an extra overlapping a
//              series occurrence is a conflict under its own key
//   today      the Today agenda has the extra of today (not as overdue)
//   reminders  an extra time reminds like its item, under its own key; a done
//              one reminds of nothing
//   live       a stream refreshes when an extra time is added
import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const zone = 'Asia/Ho_Chi_Minh';
const _zone = zone;

class _Time implements DeviceTime {
  _Time(this.at);
  Instant at;
  @override
  Instant now() => at;
  @override
  String zone() => _zone;
}

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
  return (r as CommandOk).entityId;
}

SchedulePointInput at(LocalDate d, int h, int m) => SchedulePointInput.at(d, TimeOfDayValue(h, m), zone);
ExtraTimeInput slot(LocalDate d, int h1, int m1, int h2, int m2) => ExtraTimeInput(start: at(d, h1, m1), end: at(d, h2, m2));

// Monday 2026-11-09, 08:00 in Ho Chi Minh City.
final mon = LocalDate(2026, 11, 9);
final sat = mon.addDays(5);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late DriftTaskService tasks;
  late DriftTaskScheduling scheduling;
  late DriftEventService events;
  late DriftExtraTimes extras;
  late DriftReminderService reminders;
  late DriftAgendaQueries agenda;
  late DriftCalendarQueries cal;
  late DriftReminderPlanner planner;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    await ProfileStore(db).ensureFirstProfile();
    tasks = DriftTaskService(db, gw);
    scheduling = DriftTaskScheduling(db, gw);
    events = DriftEventService(db, gw);
    extras = DriftExtraTimes(db, gw);
    reminders = DriftReminderService(db, gw);
    final time = _Time(Instant(DateTime.utc(2026, 11, 9, 1)));
    agenda = DriftAgendaQueries(db, time);
    cal = DriftCalendarQueries(db, agenda);
    planner = DriftReminderPlanner(db, time);
  });
  tearDown(() => db.close());

  /// Study 9:00-11:00 on weekdays (the owner's example).
  Future<String> study() async {
    final t = ok(await tasks.create('Study AI'));
    ok(await scheduling.setSchedule(
        t,
        TaskScheduleInput(
            start: at(mon, 9, 0),
            end: at(mon, 11, 0),
            repeat: RepeatInput(frequency: RepeatFrequency.weekly, weekdays: {
              Weekday.monday, Weekday.tuesday, Weekday.wednesday, Weekday.thursday, Weekday.friday
            }))));
    return t;
  }

  Future<String> addExtra(ExtraTimeSubject s, String id, ExtraTimeInput i) async {
    ok(await extras.add(s, id, i));
    final list = await extras.of(s, id);
    return list.firstWhere((x) => x.start == i.start).id;
  }

  group('agenda', () {
    test('an extra time is an item of its own, next to the series', () async {
      final t = await study();
      final x = await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      final a = await agenda.range(mon, sat);
      final onSat = a.items.where((i) => i.date == sat).toList();
      expect(onSat, hasLength(1), reason: 'the rule has no Saturday: only the extra');
      expect((onSat.single.extraId, onSat.single.taskId, onSat.single.isExtra), (x, t, true));
      expect((onSat.single.deviceStart, onSat.single.deviceEnd), (at(sat, 13, 0), at(sat, 15, 0)));
      expect(onSat.single.isRepeating, isFalse);
      expect(a.items.where((i) => !i.isExtra), hasLength(5), reason: 'the series: Mon-Fri');
      expect(a.items.where((i) => !i.isExtra).every((i) => i.extraId == null), isTrue);
    });

    test('two extra times on one day stay two, and one on a rule day is not the occurrence', () async {
      final t = await study();
      final a1 = await addExtra(ExtraTimeSubject.task, t, slot(mon, 13, 0, 15, 0));
      final a2 = await addExtra(ExtraTimeSubject.task, t, slot(mon, 16, 0, 17, 0));
      final onMon = (await agenda.range(mon, mon)).items;
      expect(onMon.map((i) => i.extraId), [null, a1, a2], reason: 'by time: 9:00, 13:00, 16:00');
      expect(onMon.map((i) => i.originalDate).toSet(), {mon});
    });

    test('two extra times at the same time keep one order', () async {
      final t = ok(await tasks.create('Read'));
      final ids = [await addExtra(ExtraTimeSubject.task, t, slot(sat, 8, 0, 9, 0))];
      ok(await extras.add(ExtraTimeSubject.task, t, slot(sat, 8, 0, 9, 0)));
      final both = (await agenda.range(sat, sat)).items.map((i) => i.extraId!).toList();
      expect(both, hasLength(2));
      expect(both, [...both]..sort(), reason: 'by id, so the order never flips');
      expect(both, contains(ids.single));
    });

    test('outside the window it is absent; a window that touches it shows it', () async {
      final t = await study();
      await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      expect((await agenda.range(mon, sat.addDays(-1))).items.any((i) => i.isExtra), isFalse);
      expect((await agenda.range(sat.addDays(1), sat.addDays(9))).items.any((i) => i.isExtra), isFalse);
      expect((await agenda.range(sat, sat)).items.single.isExtra, isTrue);
    });

    test('a task without a schedule shows its extra time', () async {
      final t = ok(await tasks.create('Read'));
      final x = await addExtra(ExtraTimeSubject.task, t, slot(sat, 8, 0, 9, 0));
      final a = (await agenda.range(sat, sat)).items;
      expect(a.map((i) => (i.taskId, i.extraId)), [(t, x)]);
    });

    test('its own tick shows; a done task shows all its times done', () async {
      final t = await study();
      final x = await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      final y = await addExtra(ExtraTimeSubject.task, t, slot(sat.addDays(1), 13, 0, 15, 0));
      ok(await extras.setDone(x, done: true));
      var a = (await agenda.range(sat, sat.addDays(1))).items;
      expect({for (final i in a) i.extraId: i.isDone}, {x: true, y: false});
      ok(await tasks.complete(t, withDescendants: false));
      a = (await agenda.range(sat, sat.addDays(1))).items;
      expect({for (final i in a) i.extraId: i.isDone}, {x: true, y: true});
    });

    test('a trashed task, a removed extra time: nothing', () async {
      final t = await study();
      final x = await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      ok(await extras.remove(x));
      expect((await agenda.range(sat, sat)).items, isEmpty);
      await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      ok(await tasks.trash(t));
      expect((await agenda.range(mon, sat)).items, isEmpty);
    });

    test('Today has the extra time of today, in time order, and it is not overdue', () async {
      final t = ok(await tasks.create('Gym'));
      final x = await addExtra(ExtraTimeSubject.task, t, slot(mon, 18, 0, 19, 0));
      final today = (await agenda.watchToday().first).items;
      expect(today.map((i) => (i.extraId, i.isOverdue)), [(x, false)]);
      // An extra time of yesterday is past, not overdue.
      await addExtra(ExtraTimeSubject.task, t, slot(mon.addDays(-1), 18, 0, 19, 0));
      expect((await agenda.watchToday().first).items.where((i) => i.isOverdue), isEmpty);
    });

    test('the stream refreshes when an extra time is added', () async {
      final t = ok(await tasks.create('Gym'));
      final seen = <int>[];
      final sub = agenda.watchRange(sat, sat).listen((a) => seen.add(a.items.length));
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await addExtra(ExtraTimeSubject.task, t, slot(sat, 8, 0, 9, 0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(seen, [0, 1]);
    });
  });

  group('calendar', () {
    test('an event extra time is an event item with its own id; the rule is untouched', () async {
      final e = ok(await events.create(EventInput(
          title: 'Class', start: at(mon, 9, 0), end: at(mon, 10, 0),
          repeat: RepeatInput(frequency: RepeatFrequency.weekly, weekdays: {Weekday.monday}))));
      final x = await addExtra(ExtraTimeSubject.event, e, slot(sat, 10, 0, 12, 0));
      final r = await cal.range(mon, sat);
      final extra = r.events.where((i) => i.isExtra).single;
      expect((extra.extraId, extra.eventId, extra.isRepeating, extra.isCancelled), (x, e, false, false));
      expect((extra.title, extra.deviceStart, extra.deviceEnd), ('Class', at(sat, 10, 0), at(sat, 12, 0)));
      expect(r.events.where((i) => !i.isExtra), hasLength(1));
    });

    test('a cancelled event: its extra time is cancelled and has no conflict', () async {
      final e = ok(await events.create(EventInput(title: 'A', start: at(mon, 9, 0), end: at(mon, 10, 0))));
      final t = ok(await tasks.create('B'));
      ok(await scheduling.setSchedule(t, TaskScheduleInput(start: at(sat, 9, 0), end: at(sat, 10, 0))));
      await addExtra(ExtraTimeSubject.event, e, slot(sat, 9, 30, 10, 30));
      expect((await cal.range(sat, sat)).conflicts, hasLength(1), reason: 'the extra overlaps the task');
      ok(await events.setCancelled(e, cancelled: true));
      final r = await cal.range(sat, sat);
      expect(r.events.single.isCancelled, isTrue);
      expect(r.conflicts, isEmpty);
    });

    test('an extra time overlapping a series occurrence is a conflict under its own key', () async {
      final t = await study();
      final x = await addExtra(ExtraTimeSubject.task, t, slot(mon, 10, 0, 12, 0));
      final r = await cal.range(mon, mon);
      expect(r.conflicts, [ConflictView('task:$t#$x@$mon', taskOccurrenceKey(t, mon))]);
      expect(r.tasks.where((i) => i.isExtra).single.extraId, x);
    });

    test('two extra times of one event overlapping one task are two conflicts, each under its own key', () async {
      final e = ok(await events.create(EventInput(title: 'A', start: at(mon, 9, 0), end: at(mon, 10, 0))));
      final t = ok(await tasks.create('B'));
      ok(await scheduling.setSchedule(t, TaskScheduleInput(start: at(sat, 9, 0), end: at(sat, 12, 0))));
      final x = await addExtra(ExtraTimeSubject.event, e, slot(sat, 9, 0, 10, 0));
      final y = await addExtra(ExtraTimeSubject.event, e, slot(sat, 11, 0, 12, 0));
      final keys = {for (final c in (await cal.range(sat, sat)).conflicts) c.first, for (final c in (await cal.range(sat, sat)).conflicts) c.second};
      expect(keys, containsAll(['event:$e#$x@$sat', 'event:$e#$y@$sat']));
    });

    test('a done extra time is no conflict', () async {
      final t = await study();
      final x = await addExtra(ExtraTimeSubject.task, t, slot(mon, 10, 0, 12, 0));
      ok(await extras.setDone(x, done: true));
      expect((await cal.range(mon, mon)).conflicts, isEmpty);
    });
  });

  group('reminders', () {
    test('an extra time reminds like its item, under its own key', () async {
      final t = ok(await tasks.create('Gym'));
      ok(await scheduling.setSchedule(t, TaskScheduleInput(start: at(mon.addDays(1), 9, 0))));
      final x = await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      ok(await reminders.setReminders(ReminderSubject.task, t, [const RemindMinutesBefore(10)]));
      final p = await planner.plan();
      expect(p.map((r) => r.at.utc), [DateTime.utc(2026, 11, 10, 1, 50), DateTime.utc(2026, 11, 14, 5, 50)]);
      expect(p.last.key, 'task:$t/$x#0@${sat}');
      expect(p.last.title, 'Gym');
      expect(p.last.body, 'Starts Sat 14 Nov, 13:00');
      expect(p.map((r) => r.id).toSet(), hasLength(2));
    });

    test('a done extra time, a done task and a cancelled event remind of nothing', () async {
      final t = ok(await tasks.create('Gym'));
      final x = await addExtra(ExtraTimeSubject.task, t, slot(sat, 13, 0, 15, 0));
      ok(await reminders.setReminders(ReminderSubject.task, t, [const RemindMinutesBefore(10)]));
      expect(await planner.plan(), hasLength(1));
      ok(await extras.setDone(x, done: true));
      expect(await planner.plan(), isEmpty);
      ok(await extras.setDone(x, done: false));
      ok(await tasks.complete(t, withDescendants: false));
      expect(await planner.plan(), isEmpty);

      final e = ok(await events.create(EventInput(title: 'A', start: at(mon, 9, 0), end: at(mon, 10, 0))));
      await addExtra(ExtraTimeSubject.event, e, slot(sat, 9, 0, 10, 0));
      ok(await reminders.setReminders(ReminderSubject.event, e, [const RemindMinutesBefore(5)]));
      expect(await planner.plan(), hasLength(2), reason: 'Monday 9:00 and the extra time on Saturday');
      ok(await events.setCancelled(e, cancelled: true));
      expect(await planner.plan(), isEmpty);
    });
  });
}
