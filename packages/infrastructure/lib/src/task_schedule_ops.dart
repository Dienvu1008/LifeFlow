// P02 T4 (ADR-0030): schedule commands of a task, run by TaskCommandHandler
// inside the gateway transaction (ADR-0011/0014). The task is the aggregate:
// its version moves with every schedule change. The schedule, exception and
// completion rows get their own version and an outbox row each
// (LF-INV-VER-001, LF-INV-OUTBOX-001). Nothing is hard-deleted: clearing
// writes a tombstone (SYNC-004).
//
//   setSchedule        payload: id, schedule (JSON of the schedule columns)
//   clearSchedule      payload: id
//   setException       payload: id, originalDate, kind (skip|move),
//                      moveDate?, moveTime?
//   clearException     payload: id, originalDate
//   setOccurrenceDone  payload: id, originalDate, done
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';
import 'schedule_mapping.dart';

const scheduleOps = {
  'setSchedule',
  'clearSchedule',
  'setException',
  'clearException',
  'setOccurrenceDone',
};

Future<HandlerOutcome> applyScheduleOp(
    AppDatabase db, Command cmd, Version newVersion, DateTime now) async {
  final op = cmd.payload['op'] as String;
  final taskId = cmd.payload['id'] as String;
  final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
  if (task == null || task.deletedAt != null) throw DomainRejection('task not found');

  final scheduleId = scheduleIdOf('task', taskId);
  final current = await (db.select(db.schedules)..where((s) => s.id.equals(scheduleId))).getSingleOrNull();
  final live = current != null && current.deletedAt == null ? current : null;

  // The task (aggregate) moves forward with every schedule change.
  await (db.update(db.tasks)..where((t) => t.id.equals(taskId)))
      .write(TasksCompanion(version: Value(newVersion.value), updatedAt: Value(now)));

  Future<void> outbox(String entityType, String entityId, String opType, int? base, Object row) =>
      db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: entityId,
            entityType: entityType,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: opType,
            baseVersion: Value(base),
            payload: jsonEncode(row),
            createdAt: now,
          ));

  /// The repeating schedule the occurrence belongs to, and its original date.
  Future<(Schedule, LocalDate)> occurrence() async {
    if (live == null) throw DomainRejection('the task has no schedule');
    final (spec, rule) = _read(live);
    if (rule == null) throw DomainRejection('the task does not repeat');
    final LocalDate original;
    try {
      original = LocalDate.parse(cmd.payload['originalDate'] as String);
    } catch (_) {
      throw DomainRejection('bad occurrence date');
    }
    if (!tk.isRuleDate(rule, spec, original)) {
      throw DomainRejection('$original is not an occurrence of this task');
    }
    return (live, original);
  }

  switch (op) {
    case 'setSchedule':
      final fields = (cmd.payload['schedule'] as Map).cast<String, Object?>();
      final version = (current?.version ?? 0) + 1;
      final row = <String, Object?>{
        ...fields,
        'id': scheduleId,
        'subjectType': 'task',
        'subjectId': taskId,
        'workspaceId': cmd.workspaceId,
        'ownerId': task.ownerId,
        'version': version,
        'createdAt': (current?.createdAt ?? now).millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
        'deletedAt': null,
        'deletedBy': null,
      };
      final Schedule schedule;
      try {
        schedule = Schedule.fromJson(row);
      } catch (_) {
        throw DomainRejection('the schedule cannot be read');
      }
      final (_, rule) = _read(schedule); // the payload is untrusted: full check
      await db.into(db.schedules).insertOnConflictUpdate(schedule.toCompanion(false));
      await outbox('schedule', scheduleId, current == null ? 'create' : 'update', current?.version,
          schedule.toJson());
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'schedule': scheduleId, 'repeats': rule != null},
        events: [
          DomainEvent('TaskScheduleChanged', {'id': taskId}),
          if (rule != null || current?.frequency != null)
            DomainEvent('RecurringSeriesChanged', {'id': taskId}),
        ],
      );

    case 'clearSchedule':
      if (live == null) throw DomainRejection('the task has no schedule');
      final cleared = live.copyWith(
          deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()),
          version: live.version + 1, updatedAt: now);
      await db.into(db.schedules).insertOnConflictUpdate(cleared.toCompanion(false));
      await outbox('schedule', scheduleId, 'delete', live.version, cleared.toJson());
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'schedule': null},
        events: [DomainEvent('TaskScheduleChanged', {'id': taskId})],
      );

    case 'setException':
    case 'clearException':
      final (s, original) = await occurrence();
      final id = exceptionIdOf('task', taskId, original);
      final existing = await (db.select(db.occurrenceExceptions)..where((e) => e.id.equals(id))).getSingleOrNull();
      if (op == 'clearException') {
        if (existing == null || existing.deletedAt != null) {
          throw DomainRejection('this occurrence has no change to remove');
        }
        final cleared = existing.copyWith(
            deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()),
            version: existing.version + 1, updatedAt: now);
        await db.into(db.occurrenceExceptions).insertOnConflictUpdate(cleared.toCompanion(false));
        await outbox('exception', id, 'delete', existing.version, cleared.toJson());
      } else {
        final tk.ExceptionKind kind;
        switch (cmd.payload['kind']) {
          case 'skip':
            kind = const tk.SkipOccurrence();
          case 'move':
            final LocalDate to;
            TimeOfDayValue? at;
            try {
              to = LocalDate.parse(cmd.payload['moveDate'] as String);
              final t = cmd.payload['moveTime'] as String?;
              at = t == null ? null : TimeOfDayValue.parse(t);
            } catch (_) {
              throw DomainRejection('bad move date or time');
            }
            if (at != null && s.startTime == null) {
              throw DomainRejection('a task without a start time cannot move to a time');
            }
            kind = tk.MoveOccurrence(to, toTime: at);
          default:
            throw DomainRejection('a task occurrence can be skipped or moved');
        }
        final fields = exceptionFields('task', taskId, tk.OccurrenceException(original, kind));
        final row = OccurrenceException(
          id: id,
          workspaceId: cmd.workspaceId,
          ownerId: task.ownerId,
          version: (existing?.version ?? 0) + 1,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          subjectType: 'task',
          subjectId: taskId,
          originalDate: '$original',
          kind: fields.kind.value,
          moveDate: fields.moveDate.value,
          moveTime: fields.moveTime.value,
          patch: fields.patch.value,
        );
        await db.into(db.occurrenceExceptions).insertOnConflictUpdate(row.toCompanion(false));
        await outbox('exception', id, existing == null ? 'create' : 'update', existing?.version, row.toJson());
      }
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'occurrence': '$original', 'change': op == 'clearException' ? null : cmd.payload['kind']},
        events: [DomainEvent('OccurrenceExceptionAdded', {'id': taskId, 'originalDate': '$original'})],
      );

    case 'setOccurrenceDone':
      final (_, original) = await occurrence();
      final done = cmd.payload['done'] == true;
      final id = completionIdOf(taskId, original);
      final existing = await (db.select(db.occurrenceCompletions)..where((c) => c.id.equals(id))).getSingleOrNull();
      final isDone = existing != null && existing.deletedAt == null;
      if (done == isDone) {
        throw DomainRejection(done ? 'this occurrence is already done' : 'this occurrence is not done');
      }
      final row = OccurrenceCompletion(
        id: id,
        workspaceId: cmd.workspaceId,
        ownerId: task.ownerId,
        version: (existing?.version ?? 0) + 1,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: done ? null : now,
        deletedBy: done ? null : cmd.actor.toString(),
        taskId: taskId,
        originalDate: '$original',
        completedAt: done ? now : existing!.completedAt,
      );
      await db.into(db.occurrenceCompletions).insertOnConflictUpdate(row.toCompanion(false));
      await outbox('completion', id, done ? (existing == null ? 'create' : 'update') : 'delete',
          existing?.version, row.toJson());
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'occurrence': '$original', 'done': done},
        events: [DomainEvent(done ? 'OccurrenceCompleted' : 'OccurrenceReopened',
            {'id': taskId, 'originalDate': '$original'})],
      );
  }
  throw DomainRejection('unknown op: $op');
}

(tk.ScheduleSpec, tk.RecurrenceRule?) _read(Schedule s) {
  try {
    return readSchedule(s);
  } on BadScheduleRow catch (e) {
    throw DomainRejection('invalid schedule (${e.why})');
  }
}
