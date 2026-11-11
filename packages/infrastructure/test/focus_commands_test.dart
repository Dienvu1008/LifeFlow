// P03 T3 (ADR-0038): focus commands on a real profile store.
//   GS-13   start, kill at minute 12, relaunch: the session is back with the
//           elapsed time within 1 s, the pauses kept, at most one record, and
//           the task's status untouched (LF-INV-EXEC-002/003/004)
//   kill    a kill before or after the commit of every step leaves the last
//           committed state, which recovers (LF-INV-EXEC-003)
//   D1      an overdue pomodoro asks; each of the three answers
//   D2      one running or paused session; two found after a merge
//   D5      a counted session gives one record; a session never completes
//           its task; a session can be without a task
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
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

class _Device implements ReminderScheduler {
  final plans = <List<PlannedReminder>>[];
  @override
  Future<void> sync(List<PlannedReminder> planned) async => plans.add(planned);
  @override
  Future<ReminderStatus> status() async => const ReminderStatus(supported: true, allowed: true);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> requestExact() async {}
}

/// Runs the real handler, then fails before the commit: a kill mid-step.
class _KilledBeforeCommit implements CommandHandler {
  _KilledBeforeCommit(this.inner);
  final CommandHandler inner;
  @override
  String get entityType => inner.entityType;
  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) => inner.currentVersion(tx, cmd);
  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version v) async {
    await inner.apply(tx, cmd, v);
    throw StateError('killed before the commit');
  }
}

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late FixedClock clock;

  // 0.7 s past the minute: DateTime columns keep whole seconds, the
  // session's instants must not.
  final t0 = Instant(DateTime.utc(2026, 11, 11, 8, 0, 0, 700));
  void advance(Duration d) => clock.value = Instant(clock.value.utc.add(d));

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_focus_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    clock = FixedClock(t0);
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  DriftCommandGateway gateway() => DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
  DriftFocusService focus() => DriftFocusService(host.db, gateway(), clock: clock);
  DriftFocusQueries queries() => DriftFocusQueries(host.db);
  Services svc() => Services(host, FakeAuthGateway());

  /// The process dies and the app opens the same profile again.
  Future<void> relaunch() async {
    await host.close();
    await host.openActive();
  }

  String idOf(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  Future<FocusSessionRow?> row(String id) =>
      (host.db.select(host.db.focusSessions)..where((s) => s.id.equals(id))).getSingleOrNull();
  Future<List<ExecutionRecordRow>> records() => host.db.select(host.db.executionRecords).get();
  Future<String> statusOf(String taskId) async =>
      (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(taskId))).getSingle()).status;

  void within1s(Duration actual, Duration expected, String why) =>
      expect((actual - expected).abs(), lessThan(const Duration(seconds: 1)), reason: '$why: $actual vs $expected');

  void rejected(CommandResult r, String mentions) {
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).kind, CommandFailureKind.validationFailed, reason: '$r');
    expect(r.reason, contains(mentions));
  }

  test('GS-13: kill at minute 12, relaunch: elapsed within 1 s, pauses kept, one record, task untouched', () async {
    final task = idOf(await svc().tasks.create('Write the report'));
    final statusBefore = await statusOf(task);
    final id = idOf(await focus().start(mode: FocusSessionMode.stopwatch, taskId: task));
    advance(const Duration(minutes: 5));
    idOf(await focus().pause(id));
    advance(const Duration(minutes: 2));
    idOf(await focus().resume(id));
    advance(const Duration(minutes: 5));

    await relaunch(); // killed at minute 12
    final launch = await focus().recoverOnLaunch();
    expect(launch, isA<FocusResumed>(), reason: '$launch');
    final s = (launch as FocusResumed).session;
    expect((s.status, s.taskId, s.taskTitle, s.pausedTotal), (FocusSessionStatus.running, task, 'Write the report', const Duration(minutes: 2)));
    within1s(s.focusTimeAt(clock.now()), const Duration(minutes: 10), 'elapsed after the relaunch');
    expect(await queries().watchActive().first, isA<FocusSessionView>().having((v) => v.id, 'id', id));

    advance(const Duration(seconds: 30));
    idOf(await focus().end(id, count: true));
    final rs = await records();
    expect(rs, hasLength(1));
    expect((rs.single.id, rs.single.sessionId, rs.single.taskId), (executionRecordIdOf(id), id, task));
    within1s(Duration(milliseconds: rs.single.focusMs), const Duration(minutes: 10, seconds: 30), 'recorded focus time');
    expect(await statusOf(task), statusBefore, reason: 'a session never completes its task (D5)');

    await relaunch();
    expect(await focus().recoverOnLaunch(), isA<NoActiveFocus>());
    rejected(await focus().end(id, count: true), 'already ended');
    expect(await records(), hasLength(1), reason: 'LF-INV-EXEC-004');
    expect(await queries().watchActive().first, isNull);
  });

  test('kill before or after the commit of every step: the last committed state recovers', () async {
    // The true start (when the start commits), with its sub-second part.
    var trueStart = clock.now();
    var paused = Duration.zero;
    String? id;
    var state = 'none';

    Future<void> expectRecovered(String step) async {
      final launch = await focus().recoverOnLaunch();
      if (state == 'none' || state == 'ended') {
        expect(launch, isA<NoActiveFocus>(), reason: step);
        return;
      }
      expect(launch, isA<FocusResumed>(), reason: '$step: $launch');
      final s = (launch as FocusResumed).session;
      expect(s.status.name, state, reason: step);
      var pausedNow = paused;
      if (state == 'paused') pausedNow += clock.now().utc.difference(s.pausedAt!.utc);
      within1s(s.focusTimeAt(clock.now()), clock.now().utc.difference(trueStart.utc) - pausedNow, step);
    }

    // Each step: the command type and payload, and the state it leads to.
    final steps = <(String, Map<String, Object?> Function(), String)>[
      ('StartFocusSession', () => {'op': 'start', 'id': 'k1', 'mode': 'stopwatch'}, 'running'),
      ('PauseFocusSession', () => {'op': 'pause', 'id': 'k1'}, 'paused'),
      ('ResumeFocusSession', () => {'op': 'resume', 'id': 'k1'}, 'running'),
      ('PauseFocusSession', () => {'op': 'pause', 'id': 'k1'}, 'paused'),
      ('EndFocusSession', () => {'op': 'end', 'id': 'k1', 'count': true}, 'ended'),
    ];
    var pausedAt = clock.now();
    var n = 0;
    for (final (type, payload, next) in steps) {
      n++;
      final profile = (await ProfileStore(host.db).getActiveProfile())!;
      final r = id == null ? null : await row(id);
      Command cmd(String op) => Command(
            operationId: op,
            actor: ActorRef(ActorKind.owner, profile.profileId.value),
            workspaceId: profile.activeWorkspaceId.value,
            type: type,
            payload: payload(),
            expectedVersion: r == null ? null : Version(r.version),
            issuedAt: clock.now(),
          );

      // Killed before the commit: nothing of the step is kept.
      await expectLater(gateway().execute(cmd('kill-$n'), _KilledBeforeCommit(FocusCommandHandler(clock: clock))),
          throwsA(isA<StateError>()));
      await relaunch();
      expect((await row('k1'))?.version, r?.version, reason: '$type: a killed step left a change');
      advance(const Duration(seconds: 1));
      await expectRecovered('$type killed before the commit');

      // Committed, then killed: the step is kept.
      final ok = await gateway().execute(cmd('ok-$n'), FocusCommandHandler(clock: clock));
      id = idOf(ok);
      if (type == 'StartFocusSession') trueStart = clock.now();
      if (next == 'paused') pausedAt = clock.now();
      if (state == 'paused' && next != 'paused') paused += clock.now().utc.difference(pausedAt.utc);
      state = next;
      await relaunch();
      advance(const Duration(minutes: 3, milliseconds: 400));
      await expectRecovered('$type committed, then killed');
    }
    expect(await records(), hasLength(1));
  });

  group('D1: a running pomodoro whose planned end passed', () {
    late String id;
    setUp(() async {
      id = idOf(await focus().start(mode: FocusSessionMode.pomodoro, planned: defaultPomodoroInterval));
      advance(const Duration(minutes: 40));
      await relaunch();
    });

    Future<FocusOverdue> overdue() async {
      final launch = await focus().recoverOnLaunch();
      expect(launch, isA<FocusOverdue>(), reason: '$launch');
      final o = launch as FocusOverdue;
      expect(o.plannedEnd, Instant(t0.utc.add(const Duration(minutes: 25))));
      return o;
    }

    test('counted to the planned end (the default)', () async {
      await overdue();
      idOf(await focus().resolveOverdue(id, OverdueChoice.countToPlannedEnd));
      final r = (await records()).single;
      expect(Duration(milliseconds: r.focusMs), const Duration(minutes: 25));
      // The record's instants are kept to the second; its focus time is exact.
      within1s(r.actualEnd.difference(t0.utc), const Duration(minutes: 25), 'record end');
      expect((await row(id))!.state, 'ended');
    });

    test('counted to now', () async {
      await overdue();
      idOf(await focus().resolveOverdue(id, OverdueChoice.countToNow));
      within1s(Duration(milliseconds: (await records()).single.focusMs), const Duration(minutes: 40), 'to now');
    });

    test('discarded: no record', () async {
      await overdue();
      idOf(await focus().resolveOverdue(id, OverdueChoice.discard));
      expect(await records(), isEmpty);
      expect((await row(id))!.state, 'cancelled');
      expect(await focus().recoverOnLaunch(), isA<NoActiveFocus>());
    });

    test('the planned end is refused before it is reached', () async {
      final early = idOf(await focus().resolveOverdue(id, OverdueChoice.discard));
      expect(early, id);
      final next = idOf(await focus().start(mode: FocusSessionMode.pomodoro, planned: defaultPomodoroInterval));
      advance(const Duration(minutes: 10));
      rejected(await focus().resolveOverdue(next, OverdueChoice.countToPlannedEnd), 'not over');
    });
  });

  test('D1: a paused or not yet finished pomodoro continues as it was', () async {
    final a = idOf(await focus().start(mode: FocusSessionMode.pomodoro, planned: const Duration(minutes: 25)));
    advance(const Duration(minutes: 10));
    await relaunch();
    final launch = await focus().recoverOnLaunch();
    expect(launch, isA<FocusResumed>());
    expect((launch as FocusResumed).session.remainingAt(clock.now()), const Duration(minutes: 15));
    idOf(await focus().pause(a));
    advance(const Duration(hours: 1));
    await relaunch();
    final again = await focus().recoverOnLaunch();
    expect(again, isA<FocusResumed>(), reason: 'a paused pomodoro is not overdue');
    final s = (again as FocusResumed).session;
    expect((s.status, s.remainingAt(clock.now())), (FocusSessionStatus.paused, const Duration(minutes: 15)));
  });

  group('D2: one running or paused session', () {
    test('a second start is refused until the first ends', () async {
      final a = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
      rejected(await focus().start(mode: FocusSessionMode.stopwatch), 'another focus session is active');
      idOf(await focus().pause(a));
      rejected(await focus().start(mode: FocusSessionMode.pomodoro, planned: defaultPomodoroInterval), 'another');
      idOf(await focus().cancel(a));
      idOf(await focus().start(mode: FocusSessionMode.stopwatch));
    });

    test('two active sessions found (after a merge): the newest continues, the other is kept as unrecoverable',
        () async {
      final db = host.db;
      final p = (await ProfileStore(db).getActiveProfile())!;
      for (final (id, minutes) in [('old', 0), ('new', 5)]) {
        final at = t0.utc.add(Duration(minutes: minutes));
        await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
            id: id, workspaceId: p.activeWorkspaceId.value, ownerId: p.profileId.value, createdAt: at, updatedAt: at,
            mode: 'stopwatch', state: 'running', startedAt: at.millisecondsSinceEpoch));
      }
      advance(const Duration(minutes: 10));
      final launch = await focus().recoverOnLaunch();
      expect(launch, isA<FocusResumed>().having((l) => l.session.id, 'id', 'new'));
      expect((await row('old'))!.state, 'unrecoverable');
      expect((await queries().unrecoverable()).map((s) => s.id), ['old']);
    });
  });

  test('a stored session that cannot be trusted is kept as unrecoverable and shown; a new one can start', () async {
    final db = host.db;
    final p = (await ProfileStore(db).getActiveProfile())!;
    await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
        id: 'bad', workspaceId: p.activeWorkspaceId.value, ownerId: p.profileId.value, createdAt: t0.utc,
        updatedAt: t0.utc, mode: 'stopwatch', state: 'paused', startedAt: t0.millis)); // paused, no pause time
    final launch = await focus().recoverOnLaunch();
    expect(launch, isA<FocusUnrecoverable>().having((l) => l.reason, 'reason', contains('pause time')));
    expect((launch as FocusUnrecoverable).session.status, FocusSessionStatus.unrecoverable);
    expect((await row('bad'))!.state, 'unrecoverable');
    expect((await queries().unrecoverable()).single.id, 'bad');
    expect(await records(), isEmpty);
    final next = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
    expect((await queries().watchActive().first)!.id, next);
    // A trustworthy session is never marked.
    rejected(
        await gateway().execute(
            Command(
                operationId: 'mark-ok',
                actor: ActorRef(ActorKind.owner, p.profileId.value),
                workspaceId: p.activeWorkspaceId.value,
                type: 'MarkFocusSessionUnrecoverable',
                payload: {'op': 'markUnrecoverable', 'id': next, 'cause': 'untrusted'},
                issuedAt: clock.now()),
            FocusCommandHandler(clock: clock)),
        'can be recovered');
  });

  group('transitions and their subject', () {
    test('only valid transitions; a session without a task; pauses not counted', () async {
      final id = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
      rejected(await focus().resume(id), 'not paused');
      idOf(await focus().pause(id));
      rejected(await focus().pause(id), 'not running');
      advance(const Duration(minutes: 3));
      idOf(await focus().resume(id));
      advance(const Duration(minutes: 7));
      idOf(await focus().end(id, count: true));
      rejected(await focus().cancel(id), 'already ended');
      final r = (await records()).single;
      expect((r.taskId, Duration(milliseconds: r.focusMs)), (null, const Duration(minutes: 7)));
    });

    test('a record that already exists (from a restore merge) is never written twice', () async {
      final id = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
      final db = host.db;
      final p = (await ProfileStore(db).getActiveProfile())!;
      await db.into(db.executionRecords).insert(ExecutionRecordsCompanion.insert(
          id: executionRecordIdOf(id), workspaceId: p.activeWorkspaceId.value, ownerId: p.profileId.value,
          createdAt: t0.utc, updatedAt: t0.utc, sessionId: Value(id), actualStart: t0.utc, actualEnd: t0.utc, focusMs: 0));
      advance(const Duration(minutes: 5));
      rejected(await focus().end(id, count: true), 'already has a record');
      expect((await row(id))!.state, 'running', reason: 'nothing of the end is kept');
      expect(await records(), hasLength(1));
    });

    test('ended without counting: no record', () async {
      final id = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
      advance(const Duration(minutes: 4));
      idOf(await focus().end(id, count: false));
      expect((await row(id))!.state, 'ended');
      expect(await records(), isEmpty);
    });

    test('a pomodoro needs a planned interval of at most 4 hours; a stopwatch has none', () async {
      rejected(await focus().start(mode: FocusSessionMode.pomodoro), 'planned interval');
      rejected(await focus().start(mode: FocusSessionMode.pomodoro, planned: const Duration(hours: 5)), 'at most 4 hours');
      rejected(await focus().start(mode: FocusSessionMode.stopwatch, planned: const Duration(minutes: 5)), 'only a pomodoro');
    });

    test('the clock before the start: a pause and an end are refused', () async {
      final id = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
      advance(const Duration(minutes: -5));
      rejected(await focus().pause(id), 'before the session start');
      rejected(await focus().end(id, count: true), 'before the start');
      expect(await records(), isEmpty);
    });

    test('the task: not in the trash, not done; an occurrence needs a repeating task', () async {
      final s = svc();
      final trashed = idOf(await s.tasks.create('Gone'));
      idOf(await s.tasks.trash(trashed));
      rejected(await focus().start(mode: FocusSessionMode.stopwatch, taskId: trashed), 'task not found');
      rejected(await focus().start(mode: FocusSessionMode.stopwatch, taskId: 'nope'), 'task not found');
      final done = idOf(await s.tasks.create('Done'));
      idOf(await s.tasks.complete(done, withDescendants: false));
      rejected(await focus().start(mode: FocusSessionMode.stopwatch, taskId: done), 'the task is done');

      final plain = idOf(await s.tasks.create('Once'));
      rejected(
          await focus().start(mode: FocusSessionMode.stopwatch, taskId: plain, occurrenceDate: LocalDate(2026, 11, 11)),
          'only a repeating task');
      rejected(await focus().start(mode: FocusSessionMode.stopwatch, occurrenceDate: LocalDate(2026, 11, 11)),
          'needs its task');

      final daily = idOf(await s.tasks.create('Walk'));
      final p = (await ProfileStore(host.db).getActiveProfile())!;
      final v = (await (host.db.select(host.db.tasks)..where((t) => t.id.equals(daily))).getSingle()).version;
      idOf(await gateway().execute(
          Command(
            operationId: 'sched',
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: 'SetTaskSchedule',
            payload: {
              'op': 'setSchedule',
              'id': daily,
              'schedule': scheduleFieldsJson('task', daily, tk.ScheduleSpec(start: tk.DatePoint(LocalDate(2026, 11, 1))),
                  const tk.RecurrenceRule(frequency: tk.Frequency.daily)),
            },
            expectedVersion: Version(v),
            issuedAt: clock.now(),
          ),
          TaskCommandHandler()));
      final id = idOf(
          await focus().start(mode: FocusSessionMode.stopwatch, taskId: daily, occurrenceDate: LocalDate(2026, 11, 11)));
      advance(const Duration(minutes: 20));
      idOf(await focus().end(id, count: true));
      final r = (await records()).single;
      expect((r.taskId, r.occurrenceDate), (daily, '2026-11-11'));
    });
  });

  test('D4: a running pomodoro reminds at its planned end; a pause moves it, a paused or ended one reminds of nothing',
      () async {
    final task = idOf(await svc().tasks.create('Write the report'));
    final planner = DriftReminderPlanner(host.db, _Time(clock));
    Future<List<PlannedReminder>> focusPlan() async =>
        [for (final p in await planner.plan()) if (p.key.startsWith('focus:')) p];

    final id = idOf(await focus().start(mode: FocusSessionMode.pomodoro, planned: defaultPomodoroInterval, taskId: task));
    var plan = await focusPlan();
    expect(plan.single.key, 'focus:$id');
    expect(plan.single.at, Instant(t0.utc.add(const Duration(minutes: 25))));
    expect(plan.single.body, contains('Write the report'));

    advance(const Duration(minutes: 5));
    idOf(await focus().pause(id));
    expect(await focusPlan(), isEmpty, reason: 'paused');
    advance(const Duration(minutes: 3));
    idOf(await focus().resume(id));
    plan = await focusPlan();
    expect(plan.single.at, Instant(t0.utc.add(const Duration(minutes: 28))), reason: 'moved by the pause');
    expect(plan.single.id, notificationIdOf('focus:$id'), reason: 'the same notification, rescheduled');

    advance(const Duration(minutes: 30));
    expect(await focusPlan(), isEmpty, reason: 'the end is past');
    idOf(await focus().end(id, count: true));
    expect(await focusPlan(), isEmpty);
    // A stopwatch never reminds.
    idOf(await focus().start(mode: FocusSessionMode.stopwatch));
    expect(await focusPlan(), isEmpty);
  });

  test('D4: the reminder sync hands the pomodoro end to the device when a session starts', () async {
    final device = _Device();
    final sync = ReminderSync(host.db, DriftReminderPlanner(host.db, _Time(clock)), device,
        debounce: const Duration(milliseconds: 10));
    await sync.start();
    expect(device.plans.last, isEmpty);
    final id = idOf(await focus().start(mode: FocusSessionMode.pomodoro, planned: defaultPomodoroInterval));
    for (var i = 0; i < 100 && !(device.plans.lastOrNull?.any((p) => p.key == 'focus:$id') ?? false); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(device.plans.last.single.key, 'focus:$id');
    await sync.stop();
  });

  test('every change is audited with its command and events (ADR-0011/0014)', () async {
    final id = idOf(await focus().start(mode: FocusSessionMode.stopwatch));
    idOf(await focus().end(id, count: true));
    final audit = await host.db.select(host.db.auditLog).get();
    expect(audit.where((a) => a.resourceId == id).map((a) => a.action), ['StartFocusSession', 'EndFocusSession']);
    final events = (await host.db.select(host.db.eventLog).get()).map((e) => e.eventType).toList();
    expect(events, containsAll(['FocusSessionStarted', 'FocusSessionEnded', 'ExecutionRecorded']));
  });
}
