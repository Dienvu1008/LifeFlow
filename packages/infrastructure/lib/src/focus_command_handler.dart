// P03 T3 (ADR-0038): focus session commands (owner decisions D1–D5).
// The session row is written in the gateway's one transaction at start and
// on every transition, so a kill at any point leaves the last committed
// state, which is recoverable (LF-INV-EXEC-003). The execution record is
// keyed by the session id, so a session has at most one (LF-INV-EXEC-004).
//
// Times come from the injected clock. The session's instants are stored as
// exact UTC milliseconds, so what is derived after a relaunch is what was
// derived before it (LF-INV-EXEC-002).
import 'package:application/application.dart';
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'execution_rows.dart';

/// The domain session of a stored row, or null when the row cannot be read
/// (an unknown mode or state, a bad date).
d.FocusSession? focusSessionOfRow(FocusSessionRow r) {
  final mode = d.FocusMode.values.where((m) => m.name == r.mode).firstOrNull;
  final state = d.FocusState.values.where((s) => s.name == r.state).firstOrNull;
  if (mode == null || state == null) return null;
  LocalDate? occurrence;
  if (r.occurrenceDate != null) {
    try {
      occurrence = LocalDate.parse(r.occurrenceDate!);
    } catch (_) {
      return null;
    }
  }
  return d.FocusSession(
    id: r.id,
    mode: mode,
    startedAt: Instant.fromMillis(r.startedAt),
    state: state,
    taskId: r.taskId,
    occurrenceDate: occurrence,
    planned: r.plannedMs == null ? null : Duration(milliseconds: r.plannedMs!),
    pausedTotal: Duration(milliseconds: r.pausedMs),
    pausedAt: r.pausedAt == null ? null : Instant.fromMillis(r.pausedAt!),
    endedAt: r.endedAt == null ? null : Instant.fromMillis(r.endedAt!),
  );
}

const activeFocusStates = ['running', 'paused'];

String _message(d.FocusError e) => switch (e) {
      d.FocusError.notRunning => 'the session is not running',
      d.FocusError.notPaused => 'the session is not paused',
      d.FocusError.notActive => 'the session has already ended',
      d.FocusError.plannedRequired => 'a pomodoro needs a planned interval',
      d.FocusError.plannedOutOfRange => 'the interval must be more than 0 and at most 4 hours',
      d.FocusError.plannedOnlyForPomodoro => 'only a pomodoro has a planned interval',
      d.FocusError.endBeforeStart => 'the end is before the start',
    };

T _ok<T>(Result<T, d.FocusError> r) => switch (r) {
      Ok(:final value) => value,
      Err(:final error) => throw DomainRejection(_message(error)),
    };

class FocusCommandHandler implements CommandHandler {
  const FocusCommandHandler({this.clock = const SystemClock()});

  final Clock clock;

  @override
  String get entityType => 'focusSession';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.focusSessions)..where((s) => s.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  Future<List<FocusSessionRow>> _active(AppDatabase db, String ws) => (db.select(db.focusSessions)
        ..where((s) => s.workspaceId.equals(ws) & s.state.isIn(activeFocusStates) & s.deletedAt.isNull()))
      .get();

  /// The task a session is for: in this workspace, not in the trash, not
  /// done or cancelled. An occurrence needs a repeating task.
  Future<(String?, LocalDate?)> _subject(AppDatabase db, Command cmd) async {
    final taskId = cmd.payload['taskId'] as String?;
    final rawDate = cmd.payload['occurrenceDate'] as String?;
    if (taskId == null) {
      if (rawDate != null) throw DomainRejection('an occurrence needs its task');
      return (null, null);
    }
    final t = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (t == null || t.deletedAt != null || t.workspaceId != cmd.workspaceId) throw DomainRejection('task not found');
    if (t.status == 'done' || t.status == 'cancelled') throw DomainRejection('the task is ${t.status}');
    if (rawDate == null) return (taskId, null);
    final LocalDate date;
    try {
      date = LocalDate.parse(rawDate);
    } catch (_) {
      throw DomainRejection('bad occurrence date');
    }
    final repeat = await (db.select(db.schedules)
          ..where((s) =>
              s.subjectType.equals('task') & s.subjectId.equals(taskId) & s.deletedAt.isNull() & s.frequency.isNotNull()))
        .getSingleOrNull();
    if (repeat == null) throw DomainRejection('only a repeating task has occurrences');
    return (taskId, date);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = clock.now();
    final row = await (db.select(db.focusSessions)..where((s) => s.id.equals(id))).getSingleOrNull();

    HandlerOutcome outcome(String type, Map<String, Object?> change, List<DomainEvent> events) =>
        HandlerOutcome(entityId: id, operationType: type, changeSet: {'id': id, ...change}, events: events);

    Future<void> write(d.FocusSession s) =>
        (db.update(db.focusSessions)..where((r) => r.id.equals(id))).write(FocusSessionsCompanion(
          state: Value(s.state.name),
          pausedMs: Value(s.pausedTotal.inMilliseconds),
          pausedAt: Value(s.pausedAt?.millis),
          endedAt: Value(s.endedAt?.millis),
          version: Value(newVersion.value),
          updatedAt: Value(now.utc),
        ));

    if (op == 'start') {
      if (row != null) throw DomainRejection('the session already exists');
      // D2: one running or paused session per profile.
      if ((await _active(db, cmd.workspaceId)).isNotEmpty) throw DomainRejection('another focus session is active');
      final mode = d.FocusMode.values.where((m) => m.name == cmd.payload['mode']).firstOrNull;
      if (mode == null) throw DomainRejection('unknown focus mode');
      final plannedMs = cmd.payload['plannedMs'] as int?;
      final (taskId, occurrence) = await _subject(db, cmd);
      final s = _ok(d.FocusSessionMachine.start(
        id: id,
        mode: mode,
        now: now,
        planned: plannedMs == null ? null : Duration(milliseconds: plannedMs),
        taskId: taskId,
        occurrenceDate: occurrence,
      ));
      await db.into(db.focusSessions).insert(FocusSessionsCompanion.insert(
            id: id,
            workspaceId: cmd.workspaceId,
            ownerId: cmd.actor.id,
            createdAt: now.utc,
            updatedAt: now.utc,
            taskId: Value(taskId),
            occurrenceDate: Value(occurrence?.toString()),
            mode: mode.name,
            state: s.state.name,
            startedAt: s.startedAt.millis,
            plannedMs: Value(s.planned?.inMilliseconds),
            version: Value(newVersion.value),
          ));
      return outcome('create', {'mode': mode.name, 'taskId': taskId, 'startedAt': now.millis},
          [DomainEvent('FocusSessionStarted', {'id': id, 'taskId': taskId, 'mode': mode.name})]);
    }

    if (row == null || row.deletedAt != null || row.workspaceId != cmd.workspaceId) {
      throw DomainRejection('focus session not found');
    }
    final s = focusSessionOfRow(row);

    if (op == 'markUnrecoverable') {
      // Kept and shown, never dropped (LF-INV-EXEC-003).
      if (!activeFocusStates.contains(row.state)) throw DomainRejection('the session is not active');
      final String reason;
      switch (cmd.payload['cause']) {
        case 'untrusted':
          if (s == null) {
            reason = 'the session cannot be read';
          } else if (d.FocusSessionMachine.recover(s, now) case d.Unrecoverable(reason: final r)) {
            reason = r;
          } else {
            throw DomainRejection('the session can be recovered');
          }
        case 'superseded':
          // D2: a newer session is active; this one cannot continue.
          final newer = (await _active(db, cmd.workspaceId))
              .where((o) => o.id != id && o.startedAt >= row.startedAt);
          if (newer.isEmpty) throw DomainRejection('no newer session is active');
          reason = 'another session was active';
        default:
          throw DomainRejection('unknown cause');
      }
      await (db.update(db.focusSessions)..where((r) => r.id.equals(id))).write(FocusSessionsCompanion(
          state: const Value('unrecoverable'), version: Value(newVersion.value), updatedAt: Value(now.utc)));
      return outcome('update', {'state': 'unrecoverable', 'reason': reason},
          [DomainEvent('FocusSessionUnrecoverable', {'id': id, 'reason': reason})]);
    }

    if (s == null) throw DomainRejection('the session cannot be read');
    switch (op) {
      case 'pause':
      case 'resume':
        if (now.utc.isBefore(s.startedAt.utc)) throw DomainRejection('the clock is before the session start');
        final next = _ok(op == 'pause' ? d.FocusSessionMachine.pause(s, now) : d.FocusSessionMachine.resume(s, now));
        await write(next);
        return outcome('update', {'state': next.state.name, 'pausedMs': next.pausedTotal.inMilliseconds},
            [DomainEvent(op == 'pause' ? 'FocusSessionPaused' : 'FocusSessionResumed', {'id': id})]);

      case 'cancel':
        final next = _ok(d.FocusSessionMachine.cancel(s, now));
        await write(next);
        return outcome('update', {'state': next.state.name}, [DomainEvent('FocusSessionCancelled', {'id': id})]);

      case 'end':
        final count = cmd.payload['count'] == true;
        var at = now;
        if (cmd.payload['at'] == 'plannedEnd') {
          // D1: an overdue pomodoro counted until its planned end.
          if (s.mode != d.FocusMode.pomodoro || s.state != d.FocusState.running) {
            throw DomainRejection('only a running pomodoro ends at its planned end');
          }
          final planned = d.FocusSessionMachine.plannedEnd(s, now)!;
          if (planned.utc.isAfter(now.utc)) throw DomainRejection('the pomodoro is not over yet');
          at = planned;
        } else if (cmd.payload['at'] != null && cmd.payload['at'] != 'now') {
          throw DomainRejection('unknown end time');
        }
        final (ended, draft) = _ok(d.FocusSessionMachine.end(s, at, count: count));
        await write(ended);
        final events = [
          DomainEvent('FocusSessionEnded', {'id': id, 'counted': count})
        ];
        if (draft != null) {
          final recordId = executionRecordIdOf(id);
          final existing =
              await (db.select(db.executionRecords)..where((r) => r.id.equals(recordId))).getSingleOrNull();
          if (existing != null) throw DomainRejection('the session already has a record');
          await db.into(db.executionRecords).insert(ExecutionRecordsCompanion.insert(
                id: recordId,
                workspaceId: cmd.workspaceId,
                ownerId: row.ownerId,
                createdAt: now.utc,
                updatedAt: now.utc,
                sessionId: Value(id),
                taskId: Value(draft.taskId),
                occurrenceDate: Value(draft.occurrenceDate?.toString()),
                actualStart: draft.actualStart.utc,
                actualEnd: draft.actualEnd.utc,
                focusMs: draft.focusTime.inMilliseconds,
              ));
          events.add(DomainEvent('ExecutionRecorded',
              {'id': recordId, 'sessionId': id, 'taskId': draft.taskId, 'focusMs': draft.focusTime.inMilliseconds}));
        }
        return outcome('update', {'state': 'ended', 'counted': count, 'endedAt': at.millis}, events);
    }
    throw DomainRejection('unknown op: $op');
  }
}
