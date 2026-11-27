// P06c E1 (ADR-0095): the extra times of tasks and events, the data and the
// commands.
//   add        a one-off time outside the rule, for a task and for an event;
//              a day-long one; any number (no limit); not a repeat, not a
//              deadline, not without a start; refused on a trashed item
//   change     another day and hours; its tick stays
//   remove     gone, with a tombstone in the outbox
//   tick       a task's extra time on its own; not an event's; not on a task
//              whose completion is derived; once
//   item       moved forward by each command (the optimistic version), each
//              row has its outbox row; the same operation twice changes nothing
//   keeps      the series' own schedule and its changes are untouched
//   goes with  purge blanks and tombstones them; a space move takes them
//   files      an export keeps them; one of schema 19 reads with none
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const zone = 'Asia/Ho_Chi_Minh';
final day = LocalDate(2026, 11, 5);

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
  return (r as CommandOk).entityId;
}

SchedulePointInput at(LocalDate d, int h, int m) => SchedulePointInput.at(d, TimeOfDayValue(h, m), zone);

ExtraTimeInput slot(LocalDate d, int h1, int m1, int h2, int m2) => ExtraTimeInput(start: at(d, h1, m1), end: at(d, h2, m2));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late DriftTaskService tasks;
  late DriftTaskScheduling scheduling;
  late DriftEventService events;
  late DriftExtraTimes extras;
  late DriftShelfService shelf;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    await ProfileStore(db).ensureFirstProfile();
    tasks = DriftTaskService(db, gw);
    scheduling = DriftTaskScheduling(db, gw);
    events = DriftEventService(db, gw);
    extras = DriftExtraTimes(db, gw);
    shelf = DriftShelfService(db, gw);
  });
  tearDown(() => db.close());

  /// A task that studies every weekday 9:00-11:00 (the owner's example).
  Future<String> study() async {
    final t = ok(await tasks.create('Học về AI'));
    ok(await scheduling.setSchedule(
        t,
        TaskScheduleInput(
            start: at(day, 9, 0),
            end: at(day, 11, 0),
            repeat: RepeatInput(frequency: RepeatFrequency.weekly, weekdays: {Weekday.monday, Weekday.tuesday, Weekday.wednesday, Weekday.thursday, Weekday.friday}))));
    return t;
  }

  Future<int> versionOf(String kind, String id) async => (await recordKindByName[kind]!.readOne(db, id))!['version'] as int;

  Future<List<ExtraTimeView>> listed(ExtraTimeSubject s, String id) => extras.of(s, id);

  group('add', () {
    test('another time for a task that repeats: the series stays, the extra is its own', () async {
      final t = await study();
      final before = await scheduling.scheduleOf(t);
      final v = await versionOf('task', t);
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day.addDays(3), 13, 0, 15, 0)));
      final list = await listed(ExtraTimeSubject.task, t);
      expect(list, hasLength(1));
      expect((list.single.start, list.single.end, list.single.isDone), (at(day.addDays(3), 13, 0), at(day.addDays(3), 15, 0), false));
      final after = await scheduling.scheduleOf(t);
      expect((after!.start, after.end, after.repeat?.frequency), (before!.start, before.end, before.repeat?.frequency), reason: 'the series is untouched');
      expect(await versionOf('task', t), v + 1, reason: 'the task moves forward');
      expect((await db.select(db.extraTimes).get()).single.firstDate, '${day.addDays(3)}');
    });

    test('for an event, a day-long one, and several on one day; no limit', () async {
      final e = ok(await events.create(EventInput(title: 'Họp', start: at(day, 9, 0), end: at(day, 10, 0))));
      ok(await extras.add(ExtraTimeSubject.event, e, ExtraTimeInput(start: SchedulePointInput.date(day.addDays(1)))));
      ok(await extras.add(ExtraTimeSubject.event, e, slot(day, 14, 0, 15, 0)));
      ok(await extras.add(ExtraTimeSubject.event, e, slot(day, 14, 0, 15, 0))); // the same time twice is allowed
      final list = await listed(ExtraTimeSubject.event, e);
      expect(list.map((x) => x.start.isTimed), [true, true, false], reason: 'by date and time');
      for (var i = 0; i < 150; i++) {
        ok(await extras.add(ExtraTimeSubject.event, e, slot(day.addDays(2 + i), 8, 0, 9, 0)));
      }
      expect(await listed(ExtraTimeSubject.event, e), hasLength(153), reason: 'no limit');
    });

    test('refused: no start, an end before the start, a trashed or unknown item', () async {
      final t = ok(await tasks.create('Việc'));
      expect(await extras.add(ExtraTimeSubject.task, t, ExtraTimeInput(start: at(day, 10, 0), end: at(day, 9, 0))), isA<CommandFailure>());
      expect(await extras.add(ExtraTimeSubject.task, 'nope', slot(day, 9, 0, 10, 0)), isA<CommandFailure>());
      ok(await tasks.trash(t));
      expect(await extras.add(ExtraTimeSubject.task, t, slot(day, 9, 0, 10, 0)), isA<CommandFailure>());
      expect(await db.select(db.extraTimes).get(), isEmpty);
    });

    test('the command is checked again: a deadline or no start in the payload is refused', () async {
      final t = ok(await tasks.create('Việc'));
      final good = scheduleFieldsJson('task', t,
          specOfInput(TaskScheduleInput(start: at(day, 9, 0), end: at(day, 10, 0))), null);
      // A start with a deadline, and an end with no start: each read fine as a schedule.
      final deadline = scheduleFieldsJson('task', t,
          specOfInput(TaskScheduleInput(start: at(day, 9, 0), deadline: at(day.addDays(1), 9, 0))), null);
      final noStart = scheduleFieldsJson('task', t, specOfInput(TaskScheduleInput(end: at(day, 10, 0))), null);
      Future<CommandResult> send(Map<String, Object?> schedule, {String id = 'x1'}) async {
        final task = (await recordKindByName['task']!.readOne(db, t))!;
        return gw.execute(
            Command(
              operationId: 'op-$id-${schedule.hashCode}',
              actor: (await ProfileStore(db).commandContext())!.actor,
              workspaceId: (await ProfileStore(db).commandContext())!.workspaceId,
              type: 'AddTaskExtraTime',
              payload: {'op': 'addExtra', 'id': t, 'extraId': id, 'schedule': schedule},
              expectedVersion: Version(task['version'] as int),
              issuedAt: Instant.now(),
            ),
            TaskCommandHandler());
      }

      expect(await send(deadline, id: 'd'), isA<CommandFailure>());
      expect(await send(noStart, id: 'n'), isA<CommandFailure>());
      expect(await send({...good, 'startDate': null}, id: 'm'), isA<CommandFailure>());
      expect(await send({...good, 'firstDate': '2020-01-01'}, id: 'f'), isA<CommandFailure>(), reason: 'a range that does not match');
      expect(await send(good, id: 'ok'), isA<CommandOk>());
      expect(await db.select(db.extraTimes).get(), hasLength(1));
      // The same extra id again, by another operation: refused.
      expect(await send({...good, 'endTime': '11:00'}, id: 'ok'), isA<CommandFailure>(), reason: 'the extra time already exists');
      expect(await db.select(db.extraTimes).get(), hasLength(1));
    });
  });

  group('change, remove and tick', () {
    test('change moves it, keeping its tick; remove takes it away with a tombstone', () async {
      final t = await study();
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day.addDays(3), 13, 0, 15, 0)));
      final id = (await listed(ExtraTimeSubject.task, t)).single.id;
      ok(await extras.setDone(id, done: true));
      ok(await extras.change(id, slot(day.addDays(4), 16, 0, 17, 30)));
      final moved = (await listed(ExtraTimeSubject.task, t)).single;
      expect((moved.start, moved.end, moved.isDone), (at(day.addDays(4), 16, 0), at(day.addDays(4), 17, 30), true));
      expect((await db.select(db.extraTimes).getSingle()).firstDate, '${day.addDays(4)}');

      await db.customStatement('DELETE FROM outbox');
      ok(await extras.remove(id));
      expect(await listed(ExtraTimeSubject.task, t), isEmpty);
      final row = await db.select(db.extraTimes).getSingle();
      expect(row.deletedAt, isNotNull, reason: 'a tombstone (SYNC-004)');
      final out = await db.select(db.outbox).get();
      expect({for (final o in out) '${o.entityType}:${o.operationType}'}, {'task:update', 'extraTime:delete'});
      expect(await extras.remove(id), isA<CommandFailure>());
      expect(await extras.change(id, slot(day, 9, 0, 10, 0)), isA<CommandFailure>());
    });

    test('a task\'s extra time is ticked once and unticked; the task itself stays as it was', () async {
      final t = await study();
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day.addDays(3), 13, 0, 15, 0)));
      final id = (await listed(ExtraTimeSubject.task, t)).single.id;
      ok(await extras.setDone(id, done: true));
      expect((await listed(ExtraTimeSubject.task, t)).single.isDone, isTrue);
      expect(await extras.setDone(id, done: true), isA<CommandFailure>(), reason: 'already done');
      ok(await extras.setDone(id, done: false));
      expect(await extras.setDone(id, done: false), isA<CommandFailure>(), reason: 'not done');
      expect((await recordKindByName['task']!.readOne(db, t))!['status'], isNot('done'));
    });

    test('an event\'s extra time has no tick; a task whose completion is derived has none by hand', () async {
      final e = ok(await events.create(EventInput(title: 'Họp', start: at(day, 9, 0), end: at(day, 10, 0))));
      ok(await extras.add(ExtraTimeSubject.event, e, slot(day, 14, 0, 15, 0)));
      final id = (await listed(ExtraTimeSubject.event, e)).single.id;
      expect(await extras.setDone(id, done: true), isA<CommandFailure>());

      final t = ok(await tasks.create('Uống nước'));
      await (db.update(db.tasks)..where((x) => x.id.equals(t))).write(const TasksCompanion(completionPolicy: Value('automatic')));
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day, 9, 0, 9, 15)));
      final tid = (await listed(ExtraTimeSubject.task, t)).single.id;
      expect(await extras.setDone(tid, done: true), isA<CommandFailure>());
    });

    test('an extra time of another item is not changed through this one', () async {
      final a = ok(await tasks.create('A'));
      final b = ok(await tasks.create('B'));
      ok(await extras.add(ExtraTimeSubject.task, a, slot(day, 9, 0, 10, 0)));
      final id = (await listed(ExtraTimeSubject.task, a)).single.id;
      final ctx = (await ProfileStore(db).commandContext())!;
      final bv = await versionOf('task', b);
      final r = await gw.execute(
          Command(
            operationId: 'op-cross',
            actor: ctx.actor,
            workspaceId: ctx.workspaceId,
            type: 'RemoveTaskExtraTime',
            payload: {'op': 'removeExtra', 'id': b, 'extraId': id},
            expectedVersion: Version(bv),
            issuedAt: Instant.now(),
          ),
          TaskCommandHandler());
      expect(r, isA<CommandFailure>());
      expect(await listed(ExtraTimeSubject.task, a), hasLength(1));
      expect(await versionOf('task', b), bv, reason: 'nothing changed');
    });
  });

  group('commands', () {
    test('a stale version is refused, and the same operation twice changes nothing', () async {
      final t = ok(await tasks.create('Việc'));
      final ctx = (await ProfileStore(db).commandContext())!;
      final fields = scheduleFieldsJson('task', t, specOfInput(TaskScheduleInput(start: at(day, 9, 0), end: at(day, 10, 0))), null);
      Command cmd(int v, String op) => Command(
            operationId: op,
            actor: ctx.actor,
            workspaceId: ctx.workspaceId,
            type: 'AddTaskExtraTime',
            payload: {'op': 'addExtra', 'id': t, 'extraId': 'e-$op', 'schedule': fields},
            expectedVersion: Version(v),
            issuedAt: Instant.now(),
          );
      final v = await versionOf('task', t);
      expect(await gw.execute(cmd(v - 1, 'old'), TaskCommandHandler()), isA<CommandFailure>());
      expect(await gw.execute(cmd(v, 'once'), TaskCommandHandler()), isA<CommandOk>());
      expect(await gw.execute(cmd(v, 'once'), TaskCommandHandler()), isA<CommandFailure>(), reason: 'the same operation');
      expect(await db.select(db.extraTimes).get(), hasLength(1));
    });

    test('the series\' own changes are untouched: a skipped day stays skipped, a done day stays done', () async {
      final t = await study();
      ok(await scheduling.changeOccurrence(t, day, const SkipThisOccurrence()));
      ok(await scheduling.setOccurrenceDone(t, day.addDays(1), done: true));
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day.addDays(1), 13, 0, 15, 0)));
      expect((await db.select(db.occurrenceExceptions).get()).where((x) => x.deletedAt == null), hasLength(1));
      expect((await db.select(db.occurrenceCompletions).get()).where((x) => x.deletedAt == null), hasLength(1));
      ok(await scheduling.setSchedule(t, null)); // the series is cleared: the extra stays
      expect(await listed(ExtraTimeSubject.task, t), hasLength(1));
    });
  });

  test('an extra time must point to its task or event when it is pulled (sync)', () {
    expect(requiredRefsOf('extraTime', {'subjectType': 'event', 'subjectId': 'e1'}), [('event', 'e1')]);
    expect(sharedSpaceKinds, contains('extraTime'), reason: 'it syncs in a shared space too');
    expect(kindClasses['extraTime'], isNotNull);
  });

  group('goes with its item', () {
    test('deleted for good: its extra times are tombstoned (each in the outbox)', () async {
      final t = await study();
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day.addDays(3), 13, 0, 15, 0)));
      ok(await tasks.trash(t));
      await db.customStatement('DELETE FROM outbox');
      ok(await shelf.purge(ShelfKind.task, t));
      final row = await db.select(db.extraTimes).getSingle();
      expect(row.deletedAt, isNotNull);
      final out = {for (final o in await db.select(db.outbox).get()) '${o.entityType}:${o.entityId}'};
      expect(out, contains('extraTime:${row.id}'));
    });

    test('a task moved to a shared space takes its extra times', () async {
      // The personal store of the test has no shared space; the set a move
      // takes is read, which is what carries them.
      final t = await study();
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day.addDays(3), 13, 0, 15, 0)));
      final set = await moveSetOf(db, 'task', t);
      expect([for (final (k, _) in set.records) k], containsAllInOrder(['task', 'schedule', 'extraTime']));
    });
  });

  group('files', () {
    test('an export keeps them; a file of schema 19 reads with none', () async {
      final t = ok(await tasks.create('Việc'));
      ok(await extras.add(ExtraTimeSubject.task, t, slot(day, 9, 0, 10, 0)));
      final text = await ProfileExport.build(db);
      final parsed = ProfileExport.parse(text, currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect(parsed.records['extraTime'], hasLength(1));

      final old = ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>()..remove('extraTimes');
      final env = (jsonDecode(ProfileExport.seal(old, schemaVersion: 19)) as Map).cast<String, Object?>();
      env['counts'] = (env['counts'] as Map)..remove('extraTimes');
      final back = ProfileExport.parse(jsonEncode(env), currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect(back.records['extraTime'], isEmpty);
      expect(back.records['task'], hasLength(1));
    });
  });
}
