// P03 T4 (ADR-0039): habits, targets, measurements and closed periods on a
// real profile store.
//   GS-01     automatic: achieved exactly when the aggregate reaches the
//             target, undone by a correction; never set by the data
//             (LF-INV-TASK-010); the task status is never touched
//   GS-05     manual: measurements show progress; the tick is the user's
//   EXEC-001  a correction replaces a value in the totals, history is kept
//   HEALTH-002 a period without a measurement is "no data", not a failure
//   D6c       an unmeasured habit is ticked per occurrence; unticked ->
//             missed when its period ends; a late tick is recorded
//   D9        a closed period keeps its target; a change in it needs a
//             confirmation and re-evaluates it with that target
import 'dart:io';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'fake_auth.dart';
import 'profile_harness.dart';

class _Time implements DeviceTime {
  _Time(this.clock);
  final FixedClock clock;
  @override
  Instant now() => clock.now();
  @override
  String zone() => 'UTC';
}

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late FixedClock clock;
  late DriftHabitService habits;
  late DriftHabitQueries queries;
  late Services svc;
  late DriftCommandGateway gw;

  final day0 = LocalDate(2026, 11, 11);
  void toDay(int n) => clock.value = Instant(DateTime.utc(2026, 11, 11 + n, 10));

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_habit_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    clock = FixedClock(Instant(DateTime.utc(2026, 11, 11, 10)));
    gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    habits = DriftHabitService(host.db, gw, _Time(clock), clock: clock, deviceId: 'test-pc');
    queries = DriftHabitQueries(host.db, _Time(clock));
    svc = Services(host, FakeAuthGateway());
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  void ok(CommandResult r) =>
      expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
  void refused(CommandResult r, String mentions) {
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).reason, contains(mentions));
  }

  Future<String> task(String title) async => ((await svc.tasks.create(title)) as CommandOk).entityId;

  Future<void> repeat(String id, tk.Frequency f, {LocalDate? from}) async {
    final p = (await ProfileStore(host.db).getActiveProfile())!;
    final v = (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(id))).getSingle()).version;
    ok(await gw.execute(
        Command(
          operationId: 'sched-$id',
          actor: ActorRef(ActorKind.owner, p.profileId.value),
          workspaceId: p.activeWorkspaceId.value,
          type: 'SetTaskSchedule',
          payload: {
            'op': 'setSchedule',
            'id': id,
            'schedule': scheduleFieldsJson('task', id, tk.ScheduleSpec(start: tk.DatePoint(from ?? day0)),
                tk.RecurrenceRule(frequency: f)),
          },
          expectedVersion: Version(v),
          issuedAt: clock.now(),
        ),
        TaskCommandHandler()));
  }

  Future<String> statusOf(String id) async =>
      (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(id))).getSingle()).status;
  Future<TrackingView> view(String id) async => (await queries.tracking(id))!;
  Future<List<PeriodResultRow>> stored(String id) =>
      (host.db.select(host.db.periodResults)..where((r) => r.taskId.equals(id))).get();

  const steps = TargetInput(kind: TargetKind.atLeast, min: 5000, unit: 'steps');

  group('GS-01: automatic completion is derived', () {
    test('achieved exactly at the target, undone by a correction; the status never moves', () async {
      final walk = await task('Walk');
      await repeat(walk, tk.Frequency.daily);
      ok(await habits.setHabit(walk, isHabit: true));
      ok(await habits.setTarget(walk, steps));
      ok(await habits.setCompletion(walk, CompletionMode.automatic));

      ok(await habits.recordMeasurement(walk, 3000));
      var v = await view(walk);
      expect((v.current!.value, v.current!.progress, v.isCompleteNow), (3000.0, PeriodProgress.inProgress, false));
      ok(await habits.recordMeasurement(walk, 1999));
      expect((await view(walk)).current!.progress, PeriodProgress.inProgress, reason: '4999 < 5000');
      ok(await habits.recordMeasurement(walk, 1));
      v = await view(walk);
      expect((v.current!.value, v.current!.progress, v.isCompleteNow), (5000.0, PeriodProgress.achieved, true));

      // A correction takes it back: derived, not stored.
      final last = v.measurements.first;
      ok(await habits.correctMeasurement(last.id, 0));
      v = await view(walk);
      expect((v.current!.value, v.isCompleteNow), (4999.0, false));
      expect(await statusOf(walk), isNot('done'), reason: 'never set by the data (LF-INV-TASK-010)');

      // The tick is refused: the state is derived (D8).
      refused(await svc.tasks.complete(walk, withDescendants: false), 'derived');
      refused(await DriftTaskScheduling(host.db, gw).setOccurrenceDone(walk, day0, done: true), 'derived');

      // The next day the period closes as not achieved, with the target used.
      toDay(1);
      expect(await habits.closePeriods(), 1);
      final r = (await stored(walk)).single;
      expect((r.periodKey, r.kind, r.outcome, r.value), ('$day0', 'period', 'notAchieved', 4999.0));
      expect(targetOfJson(r.target), isNotNull);
      expect(await statusOf(walk), isNot('done'));
    });
  });

  test('GS-05: manual completion: measurements show progress, the tick is the user\'s', () async {
    final read = await task('Read 50 pages');
    ok(await habits.setTarget(read, const TargetInput(kind: TargetKind.atLeast, min: 50, unit: 'pages')));
    ok(await habits.recordMeasurement(read, 60));
    final v = await view(read);
    expect((v.isHabit, v.completion, v.current!.progress, v.isCompleteNow),
        (false, CompletionMode.manual, PeriodProgress.achieved, false));
    expect(await statusOf(read), isNot('done'));
    ok(await svc.tasks.complete(read, withDescendants: false));
    expect(await statusOf(read), 'done');
  });

  test('EXEC-001: a correction replaces the value in the totals; history is kept; provenance kept', () async {
    final t = await task('Water');
    ok(await habits.setTarget(t, const TargetInput(kind: TargetKind.atMost, max: 3, unit: 'glasses')));
    ok(await habits.recordMeasurement(t, 2, note: 'morning'));
    final first = (await view(t)).measurements.single;
    expect((first.source, first.deviceId, first.note, first.date), ('manual', 'test-pc', 'morning', day0));
    ok(await habits.correctMeasurement(first.id, 1));
    refused(await habits.correctMeasurement(first.id, 5), 'already corrected');
    var v = await view(t);
    expect(v.measurements, hasLength(2));
    expect(v.measurements.firstWhere((m) => m.id == first.id).isCurrent, isFalse);
    expect(v.current!.value, 1);
    // A withdrawal removes the value; a withdrawal cannot be corrected.
    final second = v.measurements.firstWhere((m) => m.isCurrent);
    ok(await habits.correctMeasurement(second.id, null));
    v = await view(t);
    expect((v.measurements.length, v.current!.value, v.current!.progress), (3, null, PeriodProgress.noData));
    refused(await habits.correctMeasurement(v.measurements.firstWhere((m) => m.withdrawn).id, 1), 'withdrawal');
    // Values >= 0, not in the future, only for a task with a target.
    refused(await habits.recordMeasurement(t, -1), '0 or more');
    refused(await habits.recordMeasurement(t, 1, date: day0.addDays(1)), 'future');
    refused(await habits.recordMeasurement(await task('Plain'), 1), 'no target');
  });

  test('HEALTH-002: a day without a measurement closes as no data; the rate leaves it out, the streak ends', () async {
    final walk = await task('Walk');
    await repeat(walk, tk.Frequency.daily);
    ok(await habits.setHabit(walk, isHabit: true));
    ok(await habits.setTarget(walk, steps));
    ok(await habits.recordMeasurement(walk, 6000)); // day 0 achieved
    toDay(1); // day 1: nothing
    toDay(2);
    ok(await habits.recordMeasurement(walk, 7000)); // day 2 achieved
    toDay(3);
    ok(await habits.recordMeasurement(walk, 100)); // day 3 still running
    expect(await habits.closePeriods(), 3);
    final v = await view(walk);
    expect([for (final r in v.results) r.outcome],
        [PeriodOutcome.achieved, PeriodOutcome.noData, PeriodOutcome.achieved]);
    expect(v.results[1].value, isNull, reason: 'no data, never 0');
    expect(v.rateAll, 1.0, reason: '2 of 2 judged');
    expect(v.streak, 1, reason: 'the open day is skipped; no data ends the streak');
    ok(await habits.recordMeasurement(walk, 6000)); // day 3 achieved: it counts
    expect((await view(walk)).streak, 2);
  });

  group('D9: closed periods', () {
    late String walk;
    setUp(() async {
      walk = await task('Walk');
      await repeat(walk, tk.Frequency.daily);
      ok(await habits.setHabit(walk, isHabit: true));
      ok(await habits.setTarget(walk, steps));
      ok(await habits.recordMeasurement(walk, 3000));
      toDay(1);
    });

    test('a target change keeps the stored result and its target', () async {
      ok(await habits.setTarget(walk, const TargetInput(kind: TargetKind.atLeast, min: 1000, unit: 'steps')));
      final r = (await stored(walk)).single; // closed before the change
      expect((r.outcome, targetOfJson(r.target)!.min), ('notAchieved', 5000.0));
      ok(await habits.recordMeasurement(walk, 1500));
      expect((await view(walk)).current!.progress, PeriodProgress.achieved, reason: 'the new target, today');
      expect((await view(walk)).results.single.outcome, PeriodOutcome.notAchieved);
      // A confirmed change in the closed day is judged by its stored target
      // (5000), not the new one (1000).
      ok(await habits.recordMeasurement(walk, 500, date: day0, confirmClosed: true));
      final again = (await stored(walk)).single;
      expect((again.outcome, again.value), ('notAchieved', 3500.0));
    });

    test('a measurement in a closed period needs a confirmation, then re-evaluates with the stored target', () async {
      expect(await habits.closePeriods(), 1);
      refused(await habits.recordMeasurement(walk, 2500, date: day0), closedPeriodNeedsConfirmation);
      expect((await view(walk)).measurements, hasLength(1));
      ok(await habits.recordMeasurement(walk, 2500, date: day0, confirmClosed: true));
      final r = (await stored(walk)).single;
      expect((r.outcome, r.value, r.version), ('achieved', 5500.0, 2));
      final outbox = await (host.db.select(host.db.outbox)..where((o) => o.entityId.equals(r.id))).get();
      expect(outbox.map((o) => o.operationType), ['create', 'update'], reason: 'the close, then the recorded change');
      // A correction in the closed period too.
      final m = (await view(walk)).measurements.firstWhere((m) => m.value == 2500);
      refused(await habits.correctMeasurement(m.id, 0), closedPeriodNeedsConfirmation);
      ok(await habits.correctMeasurement(m.id, 0, confirmClosed: true));
      expect((await stored(walk)).single.outcome, 'notAchieved');
    });

    test('closing is idempotent and never early', () async {
      expect(await habits.closePeriods(), 1);
      expect(await habits.closePeriods(), 0);
      final p = (await ProfileStore(host.db).getActiveProfile())!;
      Command close(String key, String op) => Command(
            operationId: op,
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: 'ClosePeriod',
            payload: {'op': 'close', 'id': periodResultIdOf(walk, key, 'period'), 'taskId': walk, 'today': '${day0.addDays(1)}'},
            issuedAt: clock.now(),
          );
      refused(await gw.execute(close('$day0', 'again'), const PeriodCloseHandler()), 'already closed');
      refused(await gw.execute(close('${day0.addDays(1)}', 'early'), const PeriodCloseHandler()), 'not ended');
    });
  });

  group('D6c: an unmeasured habit', () {
    test('ticked per occurrence; unticked becomes missed; a late tick is recorded', () async {
      final water = await task('Warm water');
      await repeat(water, tk.Frequency.daily);
      ok(await habits.setHabit(water, isHabit: true));
      final sched = DriftTaskScheduling(host.db, gw);
      ok(await sched.setOccurrenceDone(water, day0, done: true));
      toDay(2); // day 1 not ticked
      expect(await habits.closePeriods(), 2);
      var v = await view(water);
      expect([for (final r in v.results) (r.key, r.outcome)],
          [(day0.addDays(1), PeriodOutcome.missed), (day0, PeriodOutcome.done)]);
      expect((v.rateAll, v.streak), (0.5, 0));

      ok(await sched.setOccurrenceDone(water, day0.addDays(1), done: true)); // late tick
      final r = (await stored(water)).firstWhere((r) => r.periodKey == '${day0.addDays(1)}');
      expect((r.outcome, r.version), ('done', 2));
      ok(await sched.setOccurrenceDone(water, day0.addDays(2), done: true)); // today
      v = await view(water);
      expect((v.rateAll, v.streak), (1.0, 3));
      ok(await sched.setOccurrenceDone(water, day0.addDays(1), done: false));
      expect((await stored(water)).firstWhere((r) => r.periodKey == '${day0.addDays(1)}').outcome, 'missed');
    });

    test('a one-off habit: done or missed after its date; a late completion is recorded', () async {
      final once = await task('Call grandma');
      final p = (await ProfileStore(host.db).getActiveProfile())!;
      final v0 = (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(once))).getSingle()).version;
      ok(await gw.execute(
          Command(
            operationId: 'once',
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: 'SetTaskSchedule',
            payload: {
              'op': 'setSchedule',
              'id': once,
              'schedule': scheduleFieldsJson('task', once, tk.ScheduleSpec(start: tk.DatePoint(day0)), null),
            },
            expectedVersion: Version(v0),
            issuedAt: clock.now(),
          ),
          TaskCommandHandler()));
      ok(await habits.setHabit(once, isHabit: true));
      toDay(1);
      expect(await habits.closePeriods(), 1);
      expect((await stored(once)).single.outcome, 'missed');
      ok(await svc.tasks.complete(once, withDescendants: false));
      expect((await stored(once)).single.outcome, 'done');
    });

    test('U-D13: with "tick", a measured task completed by hand stores the tick; stored results stay', () async {
      expect(await queries.manualResults(), ManualResults.target);
      final walk = await task('Walk');
      await repeat(walk, tk.Frequency.daily);
      ok(await habits.setHabit(walk, isHabit: true));
      ok(await habits.setTarget(walk, steps));
      final scheduling = DriftTaskScheduling(host.db, gw);
      // Day 0: target reached, not ticked. Day 1: ticked, no measurement.
      ok(await habits.recordMeasurement(walk, 6000));
      toDay(1);
      ok(await scheduling.setOccurrenceDone(walk, day0.addDays(1), done: true));
      toDay(2);
      // By the target (the default): day 0 achieved, day 1 no data.
      final target = await view(walk);
      expect([for (final r in target.results) '${r.key}:${r.outcome.name}'],
          containsAll(['${day0.addDays(1)}:noData', '$day0:achieved']));
      // The profile chooses the tick: periods not stored yet follow it.
      ok(await habits.setManualResults(ManualResults.tick));
      expect(await queries.manualResults(), ManualResults.tick);
      refused(await habits.setManualResults(ManualResults.tick), 'already tick');
      expect(await habits.closePeriods(), 2);
      expect({for (final r in await stored(walk)) '${r.periodKey}:${r.kind}:${r.outcome}'},
          {'$day0:occurrence:missed', '${day0.addDays(1)}:occurrence:done'});
      // Back to the target: what is stored is not rewritten; day 2 is judged.
      ok(await habits.setManualResults(ManualResults.target));
      toDay(3);
      expect(await habits.closePeriods(), 1);
      expect({for (final r in await stored(walk)) '${r.periodKey}:${r.kind}:${r.outcome}'},
          {'$day0:occurrence:missed', '${day0.addDays(1)}:occurrence:done', '${day0.addDays(2)}:period:noData'});
    });

    test('U-D13: an automatic task is always judged by its target', () async {
      final walk = await task('Walk');
      await repeat(walk, tk.Frequency.daily);
      ok(await habits.setHabit(walk, isHabit: true));
      ok(await habits.setTarget(walk, steps));
      ok(await habits.setCompletion(walk, CompletionMode.automatic));
      ok(await habits.setManualResults(ManualResults.tick));
      ok(await habits.recordMeasurement(walk, 6000));
      toDay(1);
      expect(await habits.closePeriods(), 1);
      expect((await stored(walk)).single.outcome, 'achieved');
    });

    test('a plain repeating task (not a habit) records no results (D6b)', () async {
      final t = await task('Take out the bins');
      await repeat(t, tk.Frequency.daily);
      toDay(5);
      expect(await habits.closePeriods(), 0);
      expect(await stored(t), isEmpty);
    });

    test('tracking starts when it becomes a habit: no invented past', () async {
      final t = await task('Stretch');
      await repeat(t, tk.Frequency.daily, from: day0.addDays(-30));
      ok(await habits.setHabit(t, isHabit: true));
      expect((await view(t)).trackedSince, day0);
      toDay(1);
      expect(await habits.closePeriods(), 1, reason: 'only day 0, not the 30 days before');
      // Off again, without a target: not tracked; on again keeps nothing new.
      ok(await habits.setHabit(t, isHabit: false));
      expect((await view(t)).trackedSince, isNull);
      refused(await habits.setHabit(t, isHabit: false), 'not a habit');
    });
  });

  test('a skipped occurrence gives no result: no "missed" day, no empty week', () async {
    final water = await task('Warm water');
    await repeat(water, tk.Frequency.daily);
    ok(await habits.setHabit(water, isHabit: true));
    final sched = DriftTaskScheduling(host.db, gw);
    ok(await sched.changeOccurrence(water, day0, const SkipThisOccurrence()));
    final run = await task('Run');
    await repeat(run, tk.Frequency.weekly, from: day0); // one date a week
    ok(await habits.setTarget(run, const TargetInput(kind: TargetKind.atLeast, min: 1, unit: 'km')));
    ok(await sched.changeOccurrence(run, day0, const SkipThisOccurrence()));
    toDay(8);
    await habits.closePeriods();
    expect((await stored(water)).map((r) => r.periodKey), isNot(contains('$day0')));
    expect((await stored(water)), hasLength(7), reason: 'days 1..7');
    expect(await stored(run), isEmpty, reason: 'the only date of the first week was skipped');
  });

  test('a one-off habit done before its date ends: done', () async {
    final once = await task('Book the dentist');
    ok(await DriftTaskScheduling(host.db, gw).setSchedule(once, TaskScheduleInput(start: SchedulePointInput.date(day0))));
    ok(await habits.setHabit(once, isHabit: true));
    ok(await svc.tasks.complete(once, withDescendants: false));
    toDay(1);
    expect(await habits.closePeriods(), 1);
    expect((await stored(once)).single.outcome, 'done');
  });

  test('a confirmed change that does not change the result writes no new version', () async {
    final walk = await task('Walk');
    await repeat(walk, tk.Frequency.daily);
    ok(await habits.setTarget(walk, const TargetInput(kind: TargetKind.atLeast, min: 5000, unit: 'steps', aggregation: TargetAggregationKind.max)));
    ok(await habits.recordMeasurement(walk, 6000));
    toDay(1);
    await habits.closePeriods();
    ok(await habits.recordMeasurement(walk, 10, date: day0, confirmClosed: true)); // the max stays 6000
    final r = (await stored(walk)).single;
    expect((r.outcome, r.value, r.version), ('achieved', 6000.0, 1));
  });

  test('the rate of the last 30 days leaves out older results', () async {
    final water = await task('Warm water');
    await repeat(water, tk.Frequency.daily);
    ok(await habits.setHabit(water, isHabit: true));
    final sched = DriftTaskScheduling(host.db, gw);
    for (var i = 0; i < 5; i++) {
      ok(await sched.setOccurrenceDone(water, day0.addDays(i), done: true));
    }
    toDay(40);
    expect(await habits.closePeriods(), 40);
    final v = await view(water);
    expect((v.rate30, v.rateAll), (0.0, 5 / 40));
  });

  test('weekly measured periods use the repeat\'s week', () async {
    final run = await task('Run');
    await repeat(run, tk.Frequency.weekly, from: LocalDate(2026, 11, 9)); // Monday
    ok(await habits.setTarget(run, const TargetInput(kind: TargetKind.atLeast, min: 10, unit: 'km', aggregation: TargetAggregationKind.sum)));
    ok(await habits.recordMeasurement(run, 4, date: LocalDate(2026, 11, 11)));
    ok(await habits.recordMeasurement(run, 7));
    final v = await view(run);
    expect((v.current!.from, v.current!.to, v.current!.value), (LocalDate(2026, 11, 9), LocalDate(2026, 11, 15), 11.0));
    clock.value = Instant(DateTime.utc(2026, 11, 16, 10));
    expect(await habits.closePeriods(), 1);
    expect((await stored(run)).single.periodKey, '2026-11-09');
  });

  test('target and policy rules', () async {
    final t = await task('Meditate');
    refused(await habits.setTarget(t, const TargetInput(kind: TargetKind.about, min: 20, max: 10, unit: 'minutes')),
        'min <= max');
    refused(await habits.setTarget(t, const TargetInput(kind: TargetKind.atLeast, min: 5, unit: ' ')), 'unit');
    refused(await habits.setCompletion(t, CompletionMode.automatic), 'needs a target');
    ok(await habits.setTarget(t, const TargetInput(kind: TargetKind.about, min: 10, max: 20, unit: 'minutes')));
    ok(await habits.setCompletion(t, CompletionMode.automatic));
    expect((await view(t)).completion, CompletionMode.automatic);
    ok(await habits.setTarget(t, null));
    final v = await view(t);
    expect((v.target, v.completion, v.trackedSince), (null, CompletionMode.manual, null));
    final row = await (host.db.select(host.db.tasks)..where((x) => x.id.equals(t))).getSingle();
    expect((row.targetType, row.targetMin, row.targetMax, row.unit), (null, null, null, null));
  });

  test('watchHabits lists the habits and follows their measurements', () async {
    final walk = await task('Walk');
    await task('Not a habit');
    ok(await habits.setHabit(walk, isHabit: true));
    ok(await habits.setTarget(walk, steps));
    final stream = queries.watchHabits();
    final seen = <List<TrackingView>>[];
    final sub = stream.listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    ok(await habits.recordMeasurement(walk, 5200));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await sub.cancel();
    expect(seen.first.map((h) => h.title), ['Walk']);
    expect(seen.last.single.current!.progress, PeriodProgress.achieved);
  });
}
