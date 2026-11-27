// P06c E3 (ADR-0097): an extra time may repeat on its own rule, beside the
// item's own (the owner's choice B: Tuesday 9-11 by the rule, and Thursday
// 13-15 for four weeks as an extra time).
//   rule     stored with its own range; the item's rule is untouched; open end
//   shown    each time is an item with the extra's id and its own date
//   change   skip, move (task); skip, cancel, move, rename (event); undo; only
//            on a date of the rule; not on a time that does not repeat
//   tick     one time at a time, never the task's own time of that day; the
//            tick of a one-off extra stays its own; the habit does not see it
//   remind   a skipped or done time reminds of nothing
//   goes     remove and purge take its changes and ticks along
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const zone = 'Asia/Ho_Chi_Minh';

class _Time implements DeviceTime {
  _Time(this.at);
  Instant at;
  @override
  Instant now() => at;
  @override
  String zone() => _zone;
}

const _zone = zone;

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
  return (r as CommandOk).entityId;
}

SchedulePointInput at(LocalDate d, int h, int m) => SchedulePointInput.at(d, TimeOfDayValue(h, m), zone);

// Monday 2026-11-09. The extra time: Thursdays 13-15, four times.
final mon = LocalDate(2026, 11, 9);
final thu = mon.addDays(3);
ExtraTimeInput thursdays({RepeatEnd end = const RepeatTimes(4)}) => ExtraTimeInput(
      start: at(thu, 13, 0),
      end: at(thu, 15, 0),
      repeat: RepeatInput(frequency: RepeatFrequency.weekly, weekdays: {Weekday.thursday}, end: end),
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late DriftTaskService tasks;
  late DriftTaskScheduling scheduling;
  late DriftEventService events;
  late DriftExtraTimes extras;
  late DriftReminderService reminders;
  late DriftShelfService shelf;
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
    shelf = DriftShelfService(db, gw);
    final time = _Time(Instant(DateTime.utc(2026, 11, 9, 1)));
    agenda = DriftAgendaQueries(db, time);
    cal = DriftCalendarQueries(db, agenda);
    planner = DriftReminderPlanner(db, time, horizon: const Duration(days: 60)); // all four Thursdays
  });
  tearDown(() => db.close());

  /// Study: Tuesdays 9-11 by the rule, Thursdays 13-15 four times by an extra.
  Future<(String, String)> study({RepeatEnd end = const RepeatTimes(4)}) async {
    final t = ok(await tasks.create('Study AI'));
    ok(await scheduling.setSchedule(
        t,
        TaskScheduleInput(
            start: at(mon.addDays(1), 9, 0),
            end: at(mon.addDays(1), 11, 0),
            repeat: const RepeatInput(frequency: RepeatFrequency.weekly, weekdays: {Weekday.tuesday}))));
    ok(await extras.add(ExtraTimeSubject.task, t, thursdays(end: end)));
    return (t, (await extras.of(ExtraTimeSubject.task, t)).single.id);
  }

  Future<List<AgendaItem>> items(LocalDate from, LocalDate to) async => (await agenda.range(from, to)).items;

  group('the rule', () {
    test('its own range; the item\'s rule is untouched; the extra reads back with its repeat', () async {
      final (t, x) = await study();
      final row = await (db.select(db.extraTimes)).getSingle();
      expect((row.frequency, row.firstDate, row.lastDate), ('weekly', '$thu', '${thu.addDays(21)}'));
      final back = (await extras.of(ExtraTimeSubject.task, t)).single;
      expect((back.id, back.isRepeating, back.repeat!.end is RepeatTimes), (x, true, true));
      final own = await scheduling.scheduleOf(t);
      expect(own!.start, at(mon.addDays(1), 9, 0));
      expect(own.repeat!.weekdays, {Weekday.tuesday});
    });

    test('open ended: a window far away still has it; before its first day it has not', () async {
      final (_, x) = await study(end: const RepeatForever());
      expect((await db.select(db.extraTimes).getSingle()).lastDate, isNull);
      final far = thu.addDays(7 * 60);
      expect((await items(far, far)).map((i) => i.extraId), [x]);
      expect((await items(mon, mon.addDays(2))).where((i) => i.isExtra), isEmpty);
    });

    test('a bad rule is refused and nothing is stored (an end before the start, a weekday off the rule)', () async {
      final t = ok(await tasks.create('X'));
      final r = await extras.add(
          ExtraTimeSubject.task,
          t,
          ExtraTimeInput(
              start: at(thu, 13, 0),
              repeat: RepeatInput(frequency: RepeatFrequency.daily, end: RepeatUntil(thu.addDays(-1)))));
      expect(r, isA<CommandFailure>());
      expect(await db.select(db.extraTimes).get(), isEmpty);
    });
  });

  group('shown', () {
    test('four Thursdays beside the Tuesdays; each with the extra\'s id and its own date', () async {
      final (_, x) = await study();
      final a = await items(mon, mon.addDays(35));
      final ex = a.where((i) => i.isExtra).toList();
      expect(ex.map((i) => i.originalDate), [for (var w = 0; w < 4; w++) thu.addDays(7 * w)]);
      expect(ex.every((i) => i.extraId == x && i.isRepeating && !i.isDone), isTrue);
      expect(a.where((i) => !i.isExtra), hasLength(5), reason: 'the rule: Tuesdays 10, 17, 24 Nov, 1, 8 Dec');
    });

    test('the Calendar keys each time apart (the extra, the date)', () async {
      final (t, x) = await study();
      final r = await cal.range(thu, thu.addDays(7));
      final keys = r.tasks.where((i) => i.isExtra).map((i) => taskOccurrenceKey(i.taskId, i.originalDate, extraId: i.extraId));
      expect(keys, ['task:$t#$x@$thu', 'task:$t#$x@${thu.addDays(7)}']);
    });
  });

  group('change one time', () {
    test('a task: skip, move, undo; only on a date of the rule', () async {
      final (_, x) = await study();
      final second = thu.addDays(7);
      ok(await extras.changeTaskOccurrence(x, second, const SkipThisOccurrence()));
      var a = (await items(thu, thu.addDays(28))).where((i) => i.isExtra).map((i) => i.originalDate).toList();
      expect(a, [thu, thu.addDays(14), thu.addDays(21)]);
      ok(await extras.changeTaskOccurrence(x, thu, MoveThisOccurrence(thu.addDays(2))));
      final moved = (await items(thu, thu.addDays(2))).where((i) => i.isExtra).single;
      expect((moved.originalDate, moved.date, moved.isMoved), (thu, thu.addDays(2), true));
      ok(await extras.changeTaskOccurrence(x, second, null));
      ok(await extras.changeTaskOccurrence(x, thu, null));
      a = (await items(thu, thu.addDays(28))).where((i) => i.isExtra).map((i) => i.originalDate).toList();
      expect(a, hasLength(4));
      expect(await extras.changeTaskOccurrence(x, thu.addDays(1), const SkipThisOccurrence()), isA<CommandFailure>(),
          reason: 'Friday is not a time of it');
      expect(await extras.changeTaskOccurrence(x, thu.addDays(28), const SkipThisOccurrence()), isA<CommandFailure>(),
          reason: 'after its last time');
      expect(await extras.changeTaskOccurrence(x, thu, null), isA<CommandFailure>(), reason: 'nothing to undo');
    });

    test('moved out of the window it left: found where it went', () async {
      final (_, x) = await study();
      final far = thu.addDays(100);
      ok(await extras.changeTaskOccurrence(x, thu, MoveThisOccurrence(far)));
      expect((await items(far, far)).where((i) => i.isExtra).map((i) => (i.originalDate, i.date)), [(thu, far)]);
    });

    test('a time that does not repeat has no one-time changes; the task\'s own exceptions are separate', () async {
      final t = ok(await tasks.create('X'));
      ok(await extras.add(ExtraTimeSubject.task, t, ExtraTimeInput(start: at(thu, 13, 0), end: at(thu, 14, 0))));
      final x = (await extras.of(ExtraTimeSubject.task, t)).single.id;
      expect(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()), isA<CommandFailure>());
      expect(await extras.setOccurrenceDone(x, thu, done: true), isA<CommandFailure>());
      expect(await extras.changeEventOccurrence(x, thu, const SkipEventOccurrence()), isA<CommandFailure>(),
          reason: 'it is a task\'s');
    });

    test('an event: skip, cancel, rename, move, undo', () async {
      final e = ok(await events.create(EventInput(title: 'Class', start: at(mon, 9, 0), end: at(mon, 10, 0))));
      ok(await extras.add(ExtraTimeSubject.event, e, thursdays()));
      final x = (await extras.of(ExtraTimeSubject.event, e)).single.id;
      ok(await extras.changeEventOccurrence(x, thu, const SkipEventOccurrence()));
      ok(await extras.changeEventOccurrence(x, thu.addDays(7), const CancelEventOccurrence()));
      ok(await extras.changeEventOccurrence(x, thu.addDays(14), const EditEventOccurrence(title: 'Exam')));
      ok(await extras.changeEventOccurrence(x, thu.addDays(21), MoveEventOccurrence(thu.addDays(22))));
      final r = (await cal.range(thu, thu.addDays(30))).events.where((i) => i.isExtra).toList();
      expect(r.map((i) => (i.originalDate, i.title, i.isCancelled, i.isMoved)), [
        (thu.addDays(7), 'Class', true, false),
        (thu.addDays(14), 'Exam', false, false),
        (thu.addDays(21), 'Class', false, true),
      ]);
      expect(r.every((i) => i.extraId == x && i.isRepeating), isTrue);
      expect((await cal.range(thu, thu)).events.where((i) => i.isExtra), isEmpty, reason: 'skipped');
      ok(await extras.changeEventOccurrence(x, thu, null));
      expect((await cal.range(thu, thu)).events.where((i) => i.isExtra), hasLength(1), reason: 'the skip is undone');
    });

    test('a task cannot cancel or rename a time, and a time off the rule is refused', () async {
      final (_, x) = await study();
      expect(await extras.changeEventOccurrence(x, thu, const CancelEventOccurrence()), isA<CommandFailure>());
    });
  });

  group('more', () {
    test('a day-long time cannot move to hours', () async {
      final t = ok(await tasks.create('Day'));
      ok(await extras.add(ExtraTimeSubject.task, t,
          ExtraTimeInput(start: SchedulePointInput.date(thu), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
      final x = (await extras.of(ExtraTimeSubject.task, t)).single.id;
      expect(await extras.changeTaskOccurrence(x, thu, MoveThisOccurrence(thu.addDays(1), toTime: TimeOfDayValue(9, 0))),
          isA<CommandFailure>());
      ok(await extras.changeTaskOccurrence(x, thu, MoveThisOccurrence(thu.addDays(1))));
    });

    test('an event: an open-ended extra time far away, and one moved out of its range', () async {
      final e = ok(await events.create(EventInput(title: 'Class', start: at(mon, 9, 0), end: at(mon, 10, 0))));
      ok(await extras.add(ExtraTimeSubject.event, e, thursdays(end: const RepeatForever())));
      final x = (await extras.of(ExtraTimeSubject.event, e)).single.id;
      final far = thu.addDays(7 * 60);
      expect((await cal.range(far, far)).events.where((i) => i.isExtra).map((i) => i.extraId), [x]);
      final out = thu.addDays(7 * 200);
      ok(await extras.changeEventOccurrence(x, thu.addDays(14), MoveEventOccurrence(out)));
      // An extra time with an end, moved past it.
      ok(await extras.remove(x));
      ok(await extras.add(ExtraTimeSubject.event, e, thursdays()));
      final y = (await extras.of(ExtraTimeSubject.event, e)).single.id;
      ok(await extras.changeEventOccurrence(y, thu, MoveEventOccurrence(out)));
      expect((await cal.range(out, out)).events.where((i) => i.isExtra).map((i) => (i.extraId, i.originalDate)), [(y, thu)]);
    });

    test('a file without the extra time drops its ticks and changes, as a restore would', () async {
      final rows = <String, List<Row>>{
        'task': [
          {'id': 't'}
        ],
        'extraTime': [],
        'completion': [
          {'id': 'extra:x@2026-11-12', 'taskId': 't', 'extraId': 'x'},
          {'id': 'task:t@2026-11-12', 'taskId': 't', 'extraId': null},
        ],
        'exception': [
          {'id': 'extraTime:x@2026-11-12', 'subjectType': 'extraTime', 'subjectId': 'x'},
        ],
      };
      final kept = withinFile(rows);
      expect([for (final c in kept['completion']!) c['id']], ['task:t@2026-11-12']);
      expect(kept['exception'], isEmpty);
    });
  });

  group('ticks', () {
    test('one time at a time; the task\'s own time of that day stays as it was', () async {
      final t = ok(await tasks.create('Study'));
      ok(await scheduling.setSchedule(
          t, TaskScheduleInput(start: at(thu, 9, 0), end: at(thu, 11, 0), repeat: const RepeatInput(frequency: RepeatFrequency.weekly, weekdays: {Weekday.thursday}))));
      ok(await extras.add(ExtraTimeSubject.task, t, thursdays()));
      final x = (await extras.of(ExtraTimeSubject.task, t)).single.id;
      ok(await extras.setOccurrenceDone(x, thu, done: true));
      var a = await items(thu, thu.addDays(7));
      expect({for (final i in a) '${i.extraId == null ? 'rule' : 'extra'}@${i.originalDate}': i.isDone}, {
        'rule@$thu': false,
        'extra@$thu': true,
        'rule@${thu.addDays(7)}': false,
        'extra@${thu.addDays(7)}': false,
      });
      expect(await extras.setOccurrenceDone(x, thu, done: true), isA<CommandFailure>(), reason: 'already done');
      ok(await extras.setOccurrenceDone(x, thu, done: false));
      expect(await extras.setOccurrenceDone(x, thu, done: false), isA<CommandFailure>(), reason: 'not done');
      ok(await scheduling.setOccurrenceDone(t, thu, done: true));
      a = await items(thu, thu);
      expect({for (final i in a) i.extraId == null: i.isDone}, {true: true, false: false});
    });

    test('a repeating time is ticked only by its occurrence; a done task has every time done', () async {
      final (t, x) = await study();
      expect(await extras.setDone(x, done: true), isA<CommandFailure>());
      ok(await tasks.complete(t, withDescendants: false));
      expect((await items(thu, thu.addDays(21))).where((i) => i.isExtra).every((i) => i.isDone), isTrue);
    });

    test('the habit does not see the ticks of an extra time', () async {
      final t = ok(await tasks.create('Run'));
      ok(await extras.add(ExtraTimeSubject.task, t, thursdays()));
      final x = (await extras.of(ExtraTimeSubject.task, t)).single.id;
      ok(await extras.setOccurrenceDone(x, thu, done: true));
      final done = await (db.select(db.occurrenceCompletions)).get();
      expect((done.single.taskId, done.single.extraId, done.single.id), (t, x, 'extra:$x@$thu'));
    });
  });

  group('reminders', () {
    test('every time reminds; a skipped, a done time, and a done task do not', () async {
      final t = ok(await tasks.create('Gym'));
      ok(await extras.add(ExtraTimeSubject.task, t, thursdays()));
      final x = (await extras.of(ExtraTimeSubject.task, t)).single.id;
      ok(await reminders.setReminders(ReminderSubject.task, t, [const RemindMinutesBefore(10)]));
      var p = await planner.plan();
      expect(p.map((r) => r.key), [for (var w = 0; w < 4; w++) 'task:$t/$x#0@${thu.addDays(7 * w)}']);
      expect(p.first.body, 'Starts Thu 12 Nov, 13:00');
      ok(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()));
      ok(await extras.setOccurrenceDone(x, thu.addDays(7), done: true));
      p = await planner.plan();
      expect(p.map((r) => r.key), ['task:$t/$x#0@${thu.addDays(14)}', 'task:$t/$x#0@${thu.addDays(21)}']);
      ok(await tasks.complete(t, withDescendants: false));
      expect(await planner.plan(), isEmpty);
    });
  });

  group('goes with it', () {
    test('removing the extra time takes its changes and ticks along (tombstones, with outbox rows)', () async {
      final (t, x) = await study();
      ok(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()));
      ok(await extras.setOccurrenceDone(x, thu.addDays(7), done: true));
      await db.customStatement('DELETE FROM outbox');
      ok(await extras.remove(x));
      expect((await db.select(db.occurrenceExceptions).get()).every((e) => e.deletedAt != null), isTrue);
      expect((await db.select(db.occurrenceCompletions).get()).every((c) => c.deletedAt != null), isTrue);
      final out = await db.select(db.outbox).get();
      expect({for (final o in out) o.entityType}, containsAll(['extraTime', 'exception', 'completion']));
      expect(out.where((o) => o.entityType != 'task').every((o) => o.operationType == 'delete'), isTrue);
      expect((await items(thu, thu.addDays(28))).where((i) => i.isExtra), isEmpty);
      expect(t, isNotEmpty);
    });

    test('purging the task blanks the changes of its extra time, and its ticks', () async {
      final (t, x) = await study();
      ok(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()));
      ok(await extras.setOccurrenceDone(x, thu.addDays(7), done: true));
      ok(await tasks.trash(t));
      ok(await shelf.purge(ShelfKind.task, t));
      expect((await db.select(db.occurrenceExceptions).get()).every((e) => e.deletedAt != null), isTrue);
      expect((await db.select(db.occurrenceCompletions).get()).every((c) => c.deletedAt != null), isTrue);
      expect((await db.select(db.extraTimes).get()).every((e) => e.deletedAt != null), isTrue);
    });
  });

  group('files and spaces', () {
    test('a move to a shared space takes the changes of its extra time and the ticks', () async {
      final (t, x) = await study();
      ok(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()));
      ok(await extras.setOccurrenceDone(x, thu.addDays(7), done: true));
      final set = await moveSetOf(db, 'task', t);
      final kinds = [for (final (k, _) in set.records) k];
      expect(kinds, containsAllInOrder(['task', 'schedule', 'extraTime', 'exception', 'completion']));
      final skip = (await db.select(db.occurrenceExceptions).get()).single.id;
      expect([for (final (k, id) in set.records) if (k == 'exception') id], [skip]);
    });

    test('an export keeps them; a file of schema 20 reads with a time that does not repeat', () async {
      final (_, x) = await study();
      ok(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()));
      ok(await extras.setOccurrenceDone(x, thu.addDays(7), done: true));
      final text = await ProfileExport.build(db);
      final parsed = ProfileExport.parse(text, currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect(parsed.records['extraTime']!.single['frequency'], 'weekly');
      expect(parsed.records['exception'], hasLength(1));
      expect(parsed.records['completion']!.single['extraId'], x);

      // A file of schema 20 knew none of the new fields.
      final old = ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
      for (final r in (old['extraTimes'] as List).cast<Map>()) {
        r['lastDate'] = r['firstDate']; // schema 20: one time, one day
        for (final k in ['frequency', 'interval', 'weekdays', 'endKind', 'endDateRule', 'endCount', 'monthEndRule', 'weekStart']) {
          r.remove(k);
        }
      }
      old['occurrenceExceptions'] = [];
      old['occurrenceCompletions'] = [for (final c in (old['occurrenceCompletions'] as List).cast<Map>().where((c) => c['extraId'] == null)) c];
      final env = (jsonDecode(ProfileExport.seal(old, schemaVersion: 20)) as Map).cast<String, Object?>();
      final back = ProfileExport.parse(jsonEncode(env), currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect(back.records['extraTime']!.single['interval'], 1);
      expect(back.records['extraTime']!.single['frequency'], isNull);
    });

    test('a file whose change or tick points to no extra time, or whose id is not its date, is refused', () async {
      final (_, x) = await study();
      ok(await extras.changeTaskOccurrence(x, thu, const SkipThisOccurrence()));
      ok(await extras.setOccurrenceDone(x, thu.addDays(7), done: true));
      final text = await ProfileExport.build(db);
      Map<String, Object?> payload() => ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
      void refused(Map<String, Object?> p, String why) {
        expect(() => ProfileExport.parse(ProfileExport.seal(p, schemaVersion: AppDatabase.currentSchemaVersion), currentSchemaVersion: AppDatabase.currentSchemaVersion),
            throwsA(anything), reason: why);
      }

      var p = payload()..['extraTimes'] = [];
      refused(p, 'the extra time is missing');
      p = payload();
      ((p['occurrenceCompletions'] as List).single as Map)['extraId'] = 'nope';
      refused(p, 'a tick of no extra time');
      p = payload();
      ((p['occurrenceCompletions'] as List).single as Map)['originalDate'] = '${thu.addDays(14)}';
      refused(p, 'a tick whose id is another date');
      p = payload();
      ((p['extraTimes'] as List).single as Map)['lastDate'] = '2030-01-01';
      refused(p, 'a stored range that does not match the rule');
    });
  });
}