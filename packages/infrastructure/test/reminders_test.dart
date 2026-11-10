// P02 T7 (ADR-0034): reminders on the real store.
//   - set / read / replace through the task and event commands; the item's
//     version moves; outbox rows; tombstones; unchanged rows untouched;
//     invalid lists refused with nothing written
//   - the planner: active profile only, rolling horizon, at most N, trashed,
//     done, cancelled items and done occurrences never remind; stable ids
//   - the sync: on start, after a change, not after stop; trash removes
import 'dart:async';
import 'dart:io';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

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

class FakeScheduler implements ReminderScheduler {
  final syncs = <List<PlannedReminder>>[];
  @override
  Future<void> sync(List<PlannedReminder> planned) async => syncs.add(planned);
  @override
  Future<ReminderStatus> status() async => const ReminderStatus(supported: true, allowed: true);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> requestExact() async {}
}

const zone = 'Asia/Ho_Chi_Minh';
LocalDate d(int m, int day) => LocalDate(2026, m, day);

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late Services svc;
  late DriftTaskScheduling scheduling;
  late DriftEventService events;
  late DriftReminderService reminders;
  late DriftReminderPlanner planner;
  late TestTime time;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_rem_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    svc = Services(host, FakeAuthGateway());
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    scheduling = DriftTaskScheduling(host.db, gw);
    events = DriftEventService(host.db, gw);
    reminders = DriftReminderService(host.db, gw);
    // Monday 2026-11-09 08:00 in Ho Chi Minh City (UTC+7).
    time = TestTime(Instant(DateTime.utc(2026, 11, 9, 1)), zone);
    planner = DriftReminderPlanner(host.db, time);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  Future<String> task(String title, {TaskScheduleInput? schedule}) async {
    final id = (await svc.tasks.create(title) as CommandOk).entityId;
    if (schedule != null) expect(await scheduling.setSchedule(id, schedule), isA<CommandOk>());
    return id;
  }

  SchedulePointInput at(LocalDate day, int h, [int m = 0]) => SchedulePointInput.at(day, TimeOfDayValue(h, m), zone);
  Future<int> taskVersion(String id) async =>
      (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(id))).getSingle()).version;
  Future<List<Reminder>> rows() => host.db.select(host.db.reminders).get();

  group('commands', () {
    test('set, read back, replace; the task version moves; outbox rows; tombstones', () async {
      final id = await task('Call', schedule: TaskScheduleInput(start: at(d(11, 10), 9)));
      final v0 = await taskVersion(id);
      final at1 = Instant(DateTime.utc(2026, 11, 12, 3));
      final r = await reminders.setReminders(
          ReminderSubject.task, id, [const RemindMinutesBefore(10), RemindAtInstant(at1)]);
      expect(r, isA<CommandOk>(), reason: '$r');
      expect(await reminders.remindersOf(ReminderSubject.task, id), [const RemindMinutesBefore(10), RemindAtInstant(at1)]);
      expect(await taskVersion(id), v0 + 1);
      final op = (await (host.db.select(host.db.auditLog)..where((a) => a.action.equals('SetTaskReminders'))).getSingle())
          .operationId;
      final out = await (host.db.select(host.db.outbox)..where((o) => o.operationId.equals(op))).get();
      expect(out.where((o) => o.entityType == 'reminder'), hasLength(2));

      // Keep the first, drop the second: one tombstone, the first untouched.
      final first = (await rows()).firstWhere((x) => x.id.endsWith('#0'));
      await reminders.setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(10)]);
      final after = {for (final x in await rows()) x.id: x};
      expect(after['task:$id#0']!.version, first.version); // unchanged: no new version
      expect(after['task:$id#1']!.deletedAt, isNotNull);
      expect(await reminders.remindersOf(ReminderSubject.task, id), [const RemindMinutesBefore(10)]);

      // None at all.
      await reminders.setReminders(ReminderSubject.task, id, const []);
      expect(await reminders.remindersOf(ReminderSubject.task, id), isEmpty);
      expect((await rows()).every((x) => x.deletedAt != null), isTrue);
    });

    test('events have reminders too; their version moves', () async {
      final r = await events.create(EventInput(title: 'Standup', start: at(d(11, 10), 9), end: at(d(11, 10), 9, 15)));
      final id = (r as CommandOk).entityId;
      final v0 = (await events.details(id))!;
      expect(await reminders.setReminders(ReminderSubject.event, id, [const RemindMinutesBefore(5)]), isA<CommandOk>());
      expect(await reminders.remindersOf(ReminderSubject.event, id), [const RemindMinutesBefore(5)]);
      final ev = await (host.db.select(host.db.events)..where((e) => e.id.equals(id))).getSingle();
      expect(ev.version, greaterThan(1));
      expect(v0.id, id);
    });

    test('a bad list is refused and writes nothing', () async {
      final id = await task('X');
      final v0 = await taskVersion(id);
      for (final (list, why) in [
        (List.generate(6, (i) => RemindMinutesBefore(i)), 'at most 5'),
        ([const RemindMinutesBefore(28 * 24 * 60 + 1)], 'at most 28 days'),
        ([const RemindMinutesBefore(-5)], 'at most 28 days'),
        ([const RemindMinutesBefore(10), const RemindMinutesBefore(10)], 'twice'),
      ]) {
        final r = await reminders.setReminders(ReminderSubject.task, id, list);
        expect((r as CommandFailure).kind, CommandFailureKind.validationFailed);
        expect(r.reason, contains(why));
      }
      expect(await rows(), isEmpty);
      expect(await taskVersion(id), v0);
      final missing = await reminders.setReminders(ReminderSubject.event, 'nope', const []);
      expect((missing as CommandFailure).kind, CommandFailureKind.notFound);
    });
  });

  group('planner', () {
    test('a timed task: 10 minutes before, with a readable text and a stable id', () async {
      final id = await task('Call the bank', schedule: TaskScheduleInput(start: at(d(11, 10), 9)));
      await reminders.setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(10)]);
      final p = await planner.plan();
      expect(p, hasLength(1));
      expect(p.single.at.utc, DateTime.utc(2026, 11, 10, 1, 50)); // 08:50 local
      expect(p.single.title, 'Call the bank');
      expect(p.single.body, 'Starts Tue 10 Nov, 09:00');
      expect(p.single.key, 'task:$id#0@2026-11-10');
      expect(p.single.id, notificationIdOf(p.single.key));
      expect((await planner.plan()).single, p.single); // the same next time
    });

    test('all-day and deadline items; another zone is named', () async {
      final a = await task('Pay rent', schedule: TaskScheduleInput(deadline: SchedulePointInput.date(d(11, 12))));
      final b = await task('Call Berlin',
          schedule: TaskScheduleInput(start: SchedulePointInput.at(d(11, 11), TimeOfDayValue(9, 0), 'Europe/Berlin')));
      await reminders.setReminders(ReminderSubject.task, a, [const RemindMinutesBefore(24 * 60)]);
      await reminders.setReminders(ReminderSubject.task, b, [const RemindMinutesBefore(0)]);
      final p = await planner.plan();
      // All-day: 09:00 device time on the 12th, one day before = 11 Nov 02:00 UTC.
      expect(p.map((x) => (x.title, x.at.utc, x.body)), [
        ('Pay rent', DateTime.utc(2026, 11, 11, 2), 'Due Thu 12 Nov'),
        ('Call Berlin', DateTime.utc(2026, 11, 11, 8), 'Starts Wed 11 Nov, 09:00 (Europe/Berlin)'),
      ]);
    });

    test('repeating: done occurrences are skipped; the horizon rolls', () async {
      final id = await task('Water plants',
          schedule: TaskScheduleInput(
              start: at(d(11, 9), 18), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      await reminders.setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(0)]);
      expect(await planner.plan(), hasLength(14)); // 9..22 Nov, inside 14 days
      await scheduling.setOccurrenceDone(id, d(11, 10), done: true);
      final keys = (await planner.plan()).map((x) => x.key).toList();
      expect(keys, isNot(contains('task:$id#0@2026-11-10')));
      expect(keys, hasLength(13));
      time.at = Instant(DateTime.utc(2026, 11, 20, 1)); // 11 days later
      final later = await planner.plan();
      expect(later.first.key, 'task:$id#0@2026-11-20');
      expect(later.last.key, 'task:$id#0@2026-12-03');
    });

    test('at most maxPending, earliest first', () async {
      final small = DriftReminderPlanner(host.db, time, maxPending: 5);
      final id = await task('Hourly-ish',
          schedule: TaskScheduleInput(
              start: at(d(11, 9), 20), repeat: const RepeatInput(frequency: RepeatFrequency.daily)));
      await reminders.setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(0), const RemindMinutesBefore(30)]);
      final p = await small.plan();
      expect(p, hasLength(5));
      expect(p.map((x) => x.at.utc), orderedEquals([...p.map((x) => x.at.utc)]..sort()));
      expect(p.map((x) => x.id).toSet(), hasLength(5)); // unique platform ids
    });

    test('done, trashed and cancelled items never remind', () async {
      final once = await task('Once', schedule: TaskScheduleInput(start: at(d(11, 10), 9)));
      final gone = await task('Gone', schedule: TaskScheduleInput(start: at(d(11, 10), 10)));
      final ev = ((await events.create(EventInput(title: 'Party', start: at(d(11, 11), 20)))) as CommandOk).entityId;
      for (final (s, id) in [(ReminderSubject.task, once), (ReminderSubject.task, gone), (ReminderSubject.event, ev)]) {
        await reminders.setReminders(s, id, [const RemindMinutesBefore(15)]);
      }
      expect(await planner.plan(), hasLength(3));
      await svc.tasks.complete(once, withDescendants: false);
      await svc.tasks.trash(gone);
      await events.setCancelled(ev, cancelled: true);
      expect(await planner.plan(), isEmpty);
      // Back again: reopened / restored / un-cancelled items remind again.
      await svc.tasks.reopen(once);
      await events.setCancelled(ev, cancelled: false);
      expect((await planner.plan()).map((x) => x.title), ['Once', 'Party']);
    });

    test('a cancelled occurrence of an event does not remind; the others do', () async {
      final ev = ((await events.create(EventInput(
              title: 'Class',
              start: at(d(11, 9), 18),
              repeat: const RepeatInput(frequency: RepeatFrequency.weekly)))) as CommandOk)
          .entityId;
      await reminders.setReminders(ReminderSubject.event, ev, [const RemindMinutesBefore(60)]);
      await events.changeOccurrence(ev, d(11, 16), const CancelEventOccurrence());
      expect((await planner.plan()).map((x) => x.key), ['event:$ev#0@2026-11-09']);
    });

    test('an absolute reminder needs no schedule', () async {
      final id = await task('Think about it');
      await reminders.setReminders(ReminderSubject.task, id, [RemindAtInstant(Instant(DateTime.utc(2026, 11, 9, 5)))]);
      final p = await planner.plan();
      expect(p.single.key, 'task:$id#0@at');
      expect(p.single.body, 'Reminder');
    });

    test('only the ACTIVE profile reminds (switch and sign-out lock replace the set)', () async {
      final id = await task('Mine', schedule: TaskScheduleInput(start: at(d(11, 10), 9)));
      await reminders.setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(10)]);
      expect(await planner.plan(), hasLength(1));
      // Another profile's store has its own plan (empty here).
      final other = await dir.createProfile(displayName: 'Work');
      final store = await dir.openProfile(other.id);
      addTearDown(store.db.close);
      expect(await DriftReminderPlanner(store.db, time).plan(), isEmpty);
    });
  });

  group('sync', () {
    test('on start, after a change (debounced), never after stop; trash removes', () async {
      final fake = FakeScheduler();
      final sync = ReminderSync(host.db, planner, fake, debounce: const Duration(milliseconds: 20));
      await sync.start();
      expect(fake.syncs.single, isEmpty);
      final id = await task('Call', schedule: TaskScheduleInput(start: at(d(11, 10), 9)));
      await reminders.setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(10)]);
      await _until(() => fake.syncs.isNotEmpty && fake.syncs.last.length == 1);
      await svc.tasks.trash(id);
      await _until(() => fake.syncs.last.isEmpty);
      await sync.stop();
      final n = fake.syncs.length;
      await svc.tasks.create('After stop');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(fake.syncs, hasLength(n));
    });

    test('a failing device is reported, not thrown, and the next change retries', () async {
      final errors = <Object>[];
      final broken = _BrokenScheduler();
      final sync = ReminderSync(host.db, planner, broken, debounce: const Duration(milliseconds: 20), onError: errors.add);
      await sync.start();
      expect(errors, hasLength(1));
      broken.fail = false;
      await svc.tasks.create('Change');
      await _until(() => broken.ok > 0);
      await sync.stop();
    });
  });
}

class _BrokenScheduler extends FakeScheduler {
  bool fail = true;
  int ok = 0;
  @override
  Future<void> sync(List<PlannedReminder> planned) async {
    if (fail) throw StateError('no notifications');
    ok++;
  }
}

Future<void> _until(bool Function() cond) async {
  for (var i = 0; i < 100 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(cond(), isTrue);
}
