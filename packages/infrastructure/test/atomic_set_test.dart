@Tags(['ff-arch-06'])
library;

// FF-ARCH-06 (LF-INV-GOV-003, GS-06/07): EVERY mutation command handler writes
// the atomic set (aggregate + audit + outbox + event log + dedupe) in ONE
// transaction. Table-driven over every handler operation, with fault
// injection after the handler ran: a failure must leave nothing behind.
//
// HANDLER REGISTRY: tools/fitness/ff_arch_06_09.dart fails CI if a class
// implementing CommandHandler under lib/ is missing from the list below, so a
// new handler cannot skip this test.
//   handlers covered: TaskCommandHandler, ProfileCommandHandler,
//                     ProfileRestoreHandler, EventCommandHandler,
//                     CalendarCommandHandler, FocusCommandHandler,
//                     MeasurementCommandHandler, PeriodCloseHandler,
//                     GoalCommandHandler, ListCommandHandler
import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

/// Runs the real handler, then fails: simulates a crash after the handler
/// wrote the aggregate but before the transaction committed.
class _FailAfterApply implements CommandHandler {
  _FailAfterApply(this.inner);
  final CommandHandler inner;
  @override
  String get entityType => inner.entityType;
  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) =>
      inner.currentVersion(tx, cmd);
  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version v) async {
    await inner.apply(tx, cmd, v);
    throw StateError('injected failure after apply');
  }
}

void main() {
  late AppDatabase db;
  late DriftCommandGateway gw;
  late String profileId;
  late String wsId;
  late String emptyExport; // the profile before any task: restoring it trashes them
  var n = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    final p = await ProfileStore(db).ensureFirstProfile();
    profileId = p.profileId.value;
    wsId = p.activeWorkspaceId.value;
    emptyExport = await ProfileExport.build(db);
    n = 0;
  });
  tearDown(() => db.close());

  Future<int> count(Iterable<Future<List<Object?>>> parts) async {
    var total = 0;
    for (final p in parts) {
      total += (await p).length;
    }
    return total;
  }

  Future<List<int>> governance(String? opId) async {
    Future<int> c(Future<List<Object?>> f) async => (await f).length;
    return [
      await c(opId == null
          ? db.select(db.auditLog).get()
          : (db.select(db.auditLog)..where((r) => r.operationId.equals(opId))).get()),
      await c(opId == null
          ? db.select(db.outbox).get()
          : (db.select(db.outbox)..where((r) => r.operationId.equals(opId))).get()),
      await c(opId == null
          ? db.select(db.eventLog).get()
          : (db.select(db.eventLog)..where((r) => r.operationId.equals(opId))).get()),
      await c(opId == null
          ? db.select(db.opDedupe).get()
          : (db.select(db.opDedupe)..where((r) => r.operationId.equals(opId))).get()),
    ];
  }

  Future<String> aggregates() async => [
        for (final r in await db.select(db.tasks).get()) r.toJson(),
        for (final r in await db.select(db.profiles).get()) r.toJson(),
        for (final r in await db.select(db.restoreSnapshots).get()) r.toJson(),
        for (final k in recordKinds) ...await k.readAll(db),
      ].toString();

  final eventSchedule = scheduleFieldsJson('event', 'e1',
      tk.ScheduleSpec(
          start: tk.TimedPoint(ZonedWallClock(LocalDate(2026, 11, 9), TimeOfDayValue(9, 0), 'UTC')),
          end: tk.TimedPoint(ZonedWallClock(LocalDate(2026, 11, 9), TimeOfDayValue(10, 0), 'UTC'))),
      const tk.RecurrenceRule(frequency: tk.Frequency.weekly));

  final weeklySchedule = scheduleFieldsJson('task', 't1',
      tk.ScheduleSpec(start: tk.DatePoint(LocalDate(2026, 11, 9))),
      const tk.RecurrenceRule(frequency: tk.Frequency.weekly));

  Future<int> versionOf(String table, String id) async => switch (table) {
        'task' => (await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle()).version,
        'event' => (await (db.select(db.events)..where((t) => t.id.equals(id))).getSingle()).version,
        'calendar' => (await (db.select(db.calendars)..where((t) => t.id.equals(id))).getSingle()).version,
        'focusSession' => (await (db.select(db.focusSessions)..where((t) => t.id.equals(id))).getSingle()).version,
        'goal' => (await (db.select(db.goals)..where((t) => t.id.equals(id))).getSingle()).version,
        'taskList' => (await (db.select(db.taskLists)..where((t) => t.id.equals(id))).getSingle()).version,
        _ => (await (db.select(db.profiles)..where((t) => t.id.equals(id))).getSingle()).version,
      };

  /// One handler operation: how to build its command.
  final taskHandler = TaskCommandHandler();
  const profileHandler = ProfileCommandHandler();
  const restoreHandler = ProfileRestoreHandler();
  const eventHandler = EventCommandHandler();
  const calendarHandler = CalendarCommandHandler();
  const focusHandler = FocusCommandHandler();
  const listHandler = ListCommandHandler();
  const measurementHandler = MeasurementCommandHandler();
  const closeHandler = PeriodCloseHandler();
  const goalHandler = GoalCommandHandler();

  Command command(String type, Map<String, Object?> payload,
          {String? opId, Version? expected}) =>
      Command(
        operationId: opId ?? 'op-${n++}',
        actor: ActorRef(ActorKind.owner, profileId),
        workspaceId: wsId,
        type: type,
        payload: payload,
        expectedVersion: expected,
        issuedAt: Instant.now(),
      );

  // Each step: [label, handler, entity table, entity id, builder(version)].
  // Steps run in order against one database; every one is run twice: first
  // with an injected failure (must leave nothing), then for real (must write
  // the full set).
  late List<(String, CommandHandler, String, String, Command Function(Version?, String))> steps;
  setUp(() {
    steps = [
      ('task.create', taskHandler, 'task', 't1',
          (v, op) => command('CreateTask', {'op': 'create', 'id': 't1', 'title': 'A'}, opId: op, expected: v)),
      ('task.create(sub)', taskHandler, 'task', 't2',
          (v, op) => command('CreateTask', {'op': 'create', 'id': 't2', 'title': 'B', 'parentId': 't1'}, opId: op, expected: v)),
      ('task.rename', taskHandler, 'task', 't1',
          (v, op) => command('RenameTask', {'op': 'rename', 'id': 't1', 'title': 'A2'}, opId: op, expected: v)),
      ('task.reparent', taskHandler, 'task', 't2',
          (v, op) => command('ReparentTask', {'op': 'reparent', 'id': 't2', 'newParentId': null}, opId: op, expected: v)),
      ('task.complete', taskHandler, 'task', 't1',
          (v, op) => command('CompleteTaskOnly', {'op': 'complete', 'id': 't1', 'cascade': 'parentOnly'}, opId: op, expected: v)),
      ('task.reopen', taskHandler, 'task', 't1',
          (v, op) => command('ReopenTask', {'op': 'reopen', 'id': 't1'}, opId: op, expected: v)),
      ('task.create(sub2)', taskHandler, 'task', 't3',
          (v, op) => command('CreateTask', {'op': 'create', 'id': 't3', 'title': 'C', 'parentId': 't1'}, opId: op, expected: v)),
      ('task.complete(all)', taskHandler, 'task', 't1',
          (v, op) => command('CompleteTaskWithDescendants', {'op': 'complete', 'id': 't1', 'cascade': 'all'}, opId: op, expected: v)),
      // P02 T4: schedule ops on t1 (weekly from 2026-11-09).
      ('task.setSchedule', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskSchedule', {'op': 'setSchedule', 'id': 't1', 'schedule': weeklySchedule}, opId: op, expected: v)),
      ('task.setException', taskHandler, 'task', 't1',
          (v, op) => command('SkipOccurrence', {'op': 'setException', 'id': 't1', 'originalDate': '2026-11-16', 'kind': 'skip'}, opId: op, expected: v)),
      ('task.clearException', taskHandler, 'task', 't1',
          (v, op) => command('ClearOccurrenceChange', {'op': 'clearException', 'id': 't1', 'originalDate': '2026-11-16'}, opId: op, expected: v)),
      ('task.setOccurrenceDone', taskHandler, 'task', 't1',
          (v, op) => command('CompleteOccurrence', {'op': 'setOccurrenceDone', 'id': 't1', 'originalDate': '2026-11-23', 'done': true}, opId: op, expected: v)),
      // P03 T4: habit, target, completion, measurements and a closed period
      // (t1 repeats weekly from Monday 2026-11-09).
      ('task.setHabit', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskHabit', {'op': 'setHabit', 'id': 't1', 'isHabit': true, 'today': '2026-11-11'}, opId: op, expected: v)),
      ('task.setTarget', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskTarget', {'op': 'setTarget', 'id': 't1', 'target': {'type': 'atLeast', 'min': 3, 'unit': 'times'}, 'today': '2026-11-11'}, opId: op, expected: v)),
      ('task.setCompletion', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskCompletion', {'op': 'setCompletion', 'id': 't1', 'policy': 'automatic'}, opId: op, expected: v)),
      ('measurement.record', measurementHandler, 'measurement', 'm1',
          (v, op) => command('RecordMeasurement', {'op': 'record', 'id': 'm1', 'taskId': 't1', 'value': 2, 'date': '2026-11-10', 'today': '2026-11-11'}, opId: op, expected: v)),
      ('measurement.correct', measurementHandler, 'measurement', 'm2',
          (v, op) => command('CorrectMeasurement', {'op': 'correct', 'id': 'm2', 'supersedesId': 'm1', 'value': 4, 'today': '2026-11-11'}, opId: op, expected: v)),
      ('period.close', closeHandler, 'periodResult', 'task:t1@2026-11-09#period',
          (v, op) => command('ClosePeriod', {'op': 'close', 'id': 'task:t1@2026-11-09#period', 'taskId': 't1', 'today': '2026-11-20'}, opId: op, expected: v)),
      ('measurement.record(closed)', measurementHandler, 'measurement', 'm3',
          (v, op) => command('RecordMeasurement', {'op': 'record', 'id': 'm3', 'taskId': 't1', 'value': 1, 'date': '2026-11-12', 'today': '2026-11-20', 'confirmClosed': true}, opId: op, expected: v)),
      ('task.setCompletion(manual)', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskCompletion', {'op': 'setCompletion', 'id': 't1', 'policy': 'manual'}, opId: op, expected: v)),
      // P02 T7: reminders (two, then one: writes and a tombstone).
      ('task.setReminders', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskReminders', {'op': 'setReminders', 'id': 't1', 'reminders': [{'before': 10}, {'before': 60}]}, opId: op, expected: v)),
      ('task.setReminders(shrink)', taskHandler, 'task', 't1',
          (v, op) => command('SetTaskReminders', {'op': 'setReminders', 'id': 't1', 'reminders': [{'at': 1794000000000}]}, opId: op, expected: v)),
      ('task.clearSchedule', taskHandler, 'task', 't1',
          (v, op) => command('ClearTaskSchedule', {'op': 'clearSchedule', 'id': 't1'}, opId: op, expected: v)),
      // P02 T5: calendars and events.
      ('calendar.create', calendarHandler, 'calendar', 'c1',
          (v, op) => command('CreateCalendar', {'op': 'create', 'id': 'c1', 'name': 'Work'}, opId: op, expected: v)),
      ('calendar.update', calendarHandler, 'calendar', 'c1',
          (v, op) => command('UpdateCalendar', {'op': 'update', 'id': 'c1', 'name': 'Office'}, opId: op, expected: v)),
      ('event.create', eventHandler, 'event', 'e1',
          (v, op) => command('CreateEvent', {'op': 'create', 'id': 'e1', 'title': 'Meet', 'calendarId': 'c1', 'schedule': eventSchedule}, opId: op, expected: v)),
      ('event.update', eventHandler, 'event', 'e1',
          (v, op) => command('UpdateEvent', {'op': 'update', 'id': 'e1', 'title': 'Meet 2', 'calendarId': 'c1', 'schedule': eventSchedule}, opId: op, expected: v)),
      ('event.setException', eventHandler, 'event', 'e1',
          (v, op) => command('CancelEventOccurrence', {'op': 'setException', 'id': 'e1', 'originalDate': '2026-11-16', 'kind': 'cancel'}, opId: op, expected: v)),
      ('event.clearException', eventHandler, 'event', 'e1',
          (v, op) => command('ClearEventOccurrenceChange', {'op': 'clearException', 'id': 'e1', 'originalDate': '2026-11-16'}, opId: op, expected: v)),
      ('event.setReminders', eventHandler, 'event', 'e1',
          (v, op) => command('SetEventReminders', {'op': 'setReminders', 'id': 'e1', 'reminders': [{'before': 15}]}, opId: op, expected: v)),
      ('event.setCancelled', eventHandler, 'event', 'e1',
          (v, op) => command('CancelEvent', {'op': 'setCancelled', 'id': 'e1', 'cancelled': true}, opId: op, expected: v)),
      ('event.trash', eventHandler, 'event', 'e1',
          (v, op) => command('TrashEvent', {'op': 'trash', 'id': 'e1'}, opId: op, expected: v)),
      ('event.restore', eventHandler, 'event', 'e1',
          (v, op) => command('RestoreEvent', {'op': 'restore', 'id': 'e1'}, opId: op, expected: v)),
      // P03 T5: goals, milestones and links (t1 and e1 are live here).
      ('goal.create', goalHandler, 'goal', 'g1',
          (v, op) => command('CreateProject', {'op': 'create', 'id': 'g1', 'kind': 'project', 'title': 'Move', 'startDate': '2026-11-01'}, opId: op, expected: v)),
      ('goal.update', goalHandler, 'goal', 'g1',
          (v, op) => command('UpdateGoal', {'op': 'update', 'id': 'g1', 'title': 'Move house', 'targetDate': '2026-12-31'}, opId: op, expected: v)),
      ('goal.addMilestone', goalHandler, 'goal', 'g1',
          (v, op) => command('AddMilestone', {'op': 'addMilestone', 'id': 'g1', 'milestoneId': 'ms1', 'title': 'Pack'}, opId: op, expected: v)),
      ('goal.updateMilestone', goalHandler, 'goal', 'g1',
          (v, op) => command('UpdateMilestone', {'op': 'updateMilestone', 'id': 'g1', 'milestoneId': 'ms1', 'title': 'Pack all'}, opId: op, expected: v)),
      ('goal.setMilestoneDone', goalHandler, 'goal', 'g1',
          (v, op) => command('CompleteMilestone', {'op': 'setMilestoneDone', 'id': 'g1', 'milestoneId': 'ms1', 'done': true}, opId: op, expected: v)),
      ('goal.link(task)', goalHandler, 'goal', 'g1',
          (v, op) => command('LinkToGoal', {'op': 'link', 'id': 'g1', 'itemType': 'task', 'itemId': 't1'}, opId: op, expected: v)),
      ('goal.link(event)', goalHandler, 'goal', 'g1',
          (v, op) => command('LinkToGoal', {'op': 'link', 'id': 'g1', 'itemType': 'event', 'itemId': 'e1'}, opId: op, expected: v)),
      ('goal.unlink', goalHandler, 'goal', 'g1',
          (v, op) => command('UnlinkFromGoal', {'op': 'unlink', 'id': 'g1', 'itemType': 'event', 'itemId': 'e1'}, opId: op, expected: v)),
      ('goal.removeMilestone', goalHandler, 'goal', 'g1',
          (v, op) => command('RemoveMilestone', {'op': 'removeMilestone', 'id': 'g1', 'milestoneId': 'ms1'}, opId: op, expected: v)),
      ('goal.setStatus', goalHandler, 'goal', 'g1',
          (v, op) => command('SetGoalStatus', {'op': 'setStatus', 'id': 'g1', 'status': 'archived'}, opId: op, expected: v)),
      ('goal.trash', goalHandler, 'goal', 'g1',
          (v, op) => command('TrashGoal', {'op': 'trash', 'id': 'g1'}, opId: op, expected: v)),
      ('goal.restore', goalHandler, 'goal', 'g1',
          (v, op) => command('RestoreGoal', {'op': 'restore', 'id': 'g1'}, opId: op, expected: v)),
      // P03 T3: focus sessions (s3 is made untrustworthy before it is marked).
      ('focus.start', focusHandler, 'focusSession', 's1',
          (v, op) => command('StartFocusSession', {'op': 'start', 'id': 's1', 'mode': 'stopwatch'}, opId: op, expected: v)),
      ('focus.pause', focusHandler, 'focusSession', 's1',
          (v, op) => command('PauseFocusSession', {'op': 'pause', 'id': 's1'}, opId: op, expected: v)),
      ('focus.resume', focusHandler, 'focusSession', 's1',
          (v, op) => command('ResumeFocusSession', {'op': 'resume', 'id': 's1'}, opId: op, expected: v)),
      ('focus.end(count)', focusHandler, 'focusSession', 's1',
          (v, op) => command('EndFocusSession', {'op': 'end', 'id': 's1', 'count': true}, opId: op, expected: v)),
      ('focus.start(pomodoro)', focusHandler, 'focusSession', 's2',
          (v, op) => command('StartFocusSession', {'op': 'start', 'id': 's2', 'mode': 'pomodoro', 'plannedMs': 1500000}, opId: op, expected: v)),
      ('focus.cancel', focusHandler, 'focusSession', 's2',
          (v, op) => command('CancelFocusSession', {'op': 'cancel', 'id': 's2'}, opId: op, expected: v)),
      ('focus.start(s3)', focusHandler, 'focusSession', 's3',
          (v, op) => command('StartFocusSession', {'op': 'start', 'id': 's3', 'mode': 'stopwatch'}, opId: op, expected: v)),
      ('focus.markUnrecoverable', focusHandler, 'focusSession', 's3',
          (v, op) => command('MarkFocusSessionUnrecoverable', {'op': 'markUnrecoverable', 'id': 's3', 'cause': 'untrusted'}, opId: op, expected: v)),
      // P03 UX U2: lists, moves and colours (t2 is top-level, e1 live).
      ('list.create', listHandler, 'taskList', 'l1',
          (v, op) => command('CreateList', {'op': 'create', 'id': 'l1', 'title': 'Work', 'colorIndex': 1}, opId: op, expected: v)),
      ('list2.create', listHandler, 'taskList', 'l2',
          (v, op) => command('CreateList', {'op': 'create', 'id': 'l2', 'title': 'Home'}, opId: op, expected: v)),
      ('list.rename', listHandler, 'taskList', 'l1',
          (v, op) => command('RenameList', {'op': 'rename', 'id': 'l1', 'title': 'Office'}, opId: op, expected: v)),
      ('list.setColor', listHandler, 'taskList', 'l1',
          (v, op) => command('SetListColor', {'op': 'setColor', 'id': 'l1', 'colorIndex': 4}, opId: op, expected: v)),
      ('list.move', listHandler, 'taskList', 'l2',
          (v, op) => command('MoveList', {'op': 'move', 'id': 'l2', 'afterId': null}, opId: op, expected: v)),
      ('task.move', taskHandler, 'task', 't2',
          (v, op) => command('MoveTask', {'op': 'move', 'id': 't2', 'listId': 'l1'}, opId: op, expected: v)),
      ('task.setNotes', taskHandler, 'task', 't2',
          (v, op) => command('SetTaskNotes', {'op': 'setNotes', 'id': 't2', 'notes': 'Bring the forms'}, opId: op, expected: v)),
      ('task.setColor', taskHandler, 'task', 't2',
          (v, op) => command('SetTaskColor', {'op': 'setColor', 'id': 't2', 'colorIndex': 9}, opId: op, expected: v)),
      ('event.move', eventHandler, 'event', 'e1',
          (v, op) => command('MoveEvent', {'op': 'move', 'id': 'e1', 'listId': 'l1', 'afterId': 't2'}, opId: op, expected: v)),
      ('event.setColor', eventHandler, 'event', 'e1',
          (v, op) => command('SetEventColor', {'op': 'setColor', 'id': 'e1', 'colorIndex': 0}, opId: op, expected: v)),
      ('list.trash', listHandler, 'taskList', 'l1',
          (v, op) => command('TrashList', {'op': 'trash', 'id': 'l1'}, opId: op, expected: v)),
      ('list.restore', listHandler, 'taskList', 'l1',
          (v, op) => command('RestoreList', {'op': 'restore', 'id': 'l1'}, opId: op, expected: v)),
      ('calendar.trash', calendarHandler, 'calendar', 'c1',
          (v, op) => command('TrashCalendar', {'op': 'trash', 'id': 'c1'}, opId: op, expected: v)),
      ('task.trash', taskHandler, 'task', 't2',
          (v, op) => command('TrashTask', {'op': 'trash', 'id': 't2'}, opId: op, expected: v)),
      ('task.trash(all)', taskHandler, 'task', 't1',
          (v, op) => command('TrashTaskWithSubtasks', {'op': 'trash', 'id': 't1', 'cascade': 'all'}, opId: op, expected: v)),
      ('profile.restore', restoreHandler, 'profile', profileId,
          (v, op) => command('RestoreProfile', {'op': 'restore', 'id': profileId, 'text': emptyExport, 'mode': 'overwrite'}, opId: op, expected: v)),
      ('profile.undoRestore', restoreHandler, 'profile', profileId,
          (v, op) => command('UndoRestoreProfile', {'op': 'undo', 'id': profileId}, opId: op, expected: v)),
      ('profile.bind', profileHandler, 'profile', profileId,
          (v, op) => command('BindAccount', {'op': 'bind', 'id': profileId, 'accountId': 'acc', 'provider': 'github', 'hasData': false, 'moveData': true}, opId: op, expected: v)),
      ('profile.signOut', profileHandler, 'profile', profileId,
          (v, op) => command('SignOut', {'op': 'signOut', 'id': profileId}, opId: op, expected: v)),
      ('profile.resume', profileHandler, 'profile', profileId,
          (v, op) => command('ResumeSession', {'op': 'resume', 'id': profileId, 'accountId': 'acc'}, opId: op, expected: v)),
      // P03 UX U6 (U-D13).
      ('profile.setManualResults', profileHandler, 'profile', profileId,
          (v, op) => command('SetManualResults', {'op': 'setManualResults', 'id': profileId, 'value': 'tick'}, opId: op, expected: v)),
    ];
  });

  test('every handler operation writes the whole atomic set, and a failure '
      'after the handler leaves nothing (FF-ARCH-06, GS-06/07)', () async {
    for (final (label, handler, table, id, build) in steps) {
      if (label == 'focus.markUnrecoverable') {
        // A stored row that cannot be trusted: paused without a pause time.
        await (db.update(db.focusSessions)..where((s) => s.id.equals('s3')))
            .write(const FocusSessionsCompanion(state: Value('paused')));
      }
      final current = label.endsWith('.create') ||
              label.startsWith('task.create') ||
              label.startsWith('focus.start') ||
              label.startsWith('measurement.') ||
              label == 'period.close'
          ? null
          : Version(await versionOf(table, id));

      // 1) Failure injected after the handler ran -> total rollback.
      final govBefore = await governance(null);
      final aggBefore = await aggregates();
      final failOp = 'fail-${n++}';
      await expectLater(
          gw.execute(build(current, failOp), _FailAfterApply(handler)),
          throwsA(isA<StateError>()),
          reason: '$label: the injected failure should surface');
      expect(await governance(null), govBefore,
          reason: '$label: a failed command left governance rows behind');
      expect(await aggregates(), aggBefore,
          reason: '$label: a failed command changed the aggregate');

      // 2) The real run -> the FULL set, in the same commit.
      final okOp = 'ok-${n++}';
      final r = await gw.execute(build(current, okOp), handler);
      expect(r, isA<CommandOk>(), reason: '$label: $r');
      final set = await governance(okOp);
      expect(set[0], 1, reason: '$label: audit row missing');
      expect(set[1], greaterThanOrEqualTo(1), reason: '$label: outbox row missing');
      expect(set[2], greaterThanOrEqualTo(1), reason: '$label: event-log row missing');
      expect(set[3], 1, reason: '$label: dedupe row missing');
    }
  });

  test('a duplicate operation changes nothing (idempotent atomic set)',
      () async {
    final a = command('CreateTask', {'op': 'create', 'id': 'd1', 'title': 'Once'}, opId: 'dup-1');
    expect(await gw.execute(a, taskHandler), isA<CommandOk>());
    final gov = await governance(null);
    final dup = await gw.execute(a, taskHandler);
    expect((dup as CommandFailure).kind, CommandFailureKind.duplicateOperation);
    expect(await governance(null), gov);
    expect(await count([db.select(db.tasks).get()]), 1);
  });
}
