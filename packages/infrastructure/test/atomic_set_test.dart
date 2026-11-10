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
//                     CalendarCommandHandler
import 'package:application/application.dart';
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
        _ => (await (db.select(db.profiles)..where((t) => t.id.equals(id))).getSingle()).version,
      };

  /// One handler operation: how to build its command.
  final taskHandler = TaskCommandHandler();
  const profileHandler = ProfileCommandHandler();
  const restoreHandler = ProfileRestoreHandler();
  const eventHandler = EventCommandHandler();
  const calendarHandler = CalendarCommandHandler();

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
    ];
  });

  test('every handler operation writes the whole atomic set, and a failure '
      'after the handler leaves nothing (FF-ARCH-06, GS-06/07)', () async {
    for (final (label, handler, table, id, build) in steps) {
      final current = label.endsWith('.create') || label.startsWith('task.create')
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
