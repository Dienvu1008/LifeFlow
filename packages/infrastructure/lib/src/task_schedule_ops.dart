// P02 T4 (ADR-0030): schedule commands of a task, run by TaskCommandHandler
// inside the gateway transaction (ADR-0011/0014). The task is the aggregate:
// its version moves with every schedule change. Rows are written through
// [ScheduleRows] (shared with events, T5).
//
//   setSchedule        payload: id, schedule (JSON of the schedule columns)
//   clearSchedule      payload: id
//   setException       payload: id, originalDate, kind (skip|move),
//                      moveDate?, moveTime?
//   clearException     payload: id, originalDate
//   setOccurrenceDone  payload: id, originalDate, done
//   setReminders       payload: id, reminders (P02 T7, reminder_rows.dart)
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'package:domain/domain.dart' as d;

import 'app_database.dart';
import 'execution_rows.dart';
import 'habit_tracking.dart';
import 'reminder_rows.dart';
import 'schedule_mapping.dart';
import 'schedule_rows.dart';

const scheduleOps = {
  'setSchedule',
  'clearSchedule',
  'setException',
  'clearException',
  'setOccurrenceDone',
  'setReminders',
};

Future<HandlerOutcome> applyScheduleOp(
    AppDatabase db, Command cmd, Version newVersion, DateTime now) async {
  final op = cmd.payload['op'] as String;
  final taskId = cmd.payload['id'] as String;
  final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
  if (task == null || task.deletedAt != null) throw DomainRejection('task not found');
  final rows = ScheduleRows(db, cmd, 'task', taskId, task.ownerId, now);

  // The task (aggregate) moves forward with every schedule change.
  await (db.update(db.tasks)..where((t) => t.id.equals(taskId)))
      .write(TasksCompanion(version: Value(newVersion.value), updatedAt: Value(now)));

  switch (op) {
    case 'setReminders':
      // P02 T7 (ADR-0034): the reminders are part of the task.
      final n = await replaceReminders(rows, remindersOfPayload(cmd.payload['reminders']));
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'reminders': n},
        events: [DomainEvent('TaskRemindersChanged', {'id': taskId})],
      );

    case 'setSchedule':
      final (_, _, rule, previous) =
          await rows.write((cmd.payload['schedule'] as Map).cast<String, Object?>());
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'schedule': rows.scheduleId, 'repeats': rule != null},
        events: [
          DomainEvent('TaskScheduleChanged', {'id': taskId}),
          if (rule != null || previous?.frequency != null)
            DomainEvent('RecurringSeriesChanged', {'id': taskId}),
        ],
      );

    case 'clearSchedule':
      final live = await rows.live();
      if (live == null) throw DomainRejection('the task has no schedule');
      await rows.clear(live);
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'schedule': null},
        events: [DomainEvent('TaskScheduleChanged', {'id': taskId})],
      );

    case 'setException':
    case 'clearException':
      final (s, original) = await rows.occurrence();
      if (op == 'clearException') {
        await rows.clearException(original);
      } else {
        final tk.ExceptionKind kind = switch (cmd.payload['kind']) {
          'skip' => const tk.SkipOccurrence(),
          'move' => rows.move(s),
          _ => throw DomainRejection('a task occurrence can be skipped or moved'),
        };
        await rows.writeException(original, kind);
      }
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'occurrence': '$original', 'change': op == 'clearException' ? null : cmd.payload['kind']},
        events: [DomainEvent('OccurrenceExceptionAdded', {'id': taskId, 'originalDate': '$original'})],
      );

    case 'setOccurrenceDone':
      // P03 D8: automatic completion is derived, never ticked by hand.
      if (task.completionPolicy == 'automatic') {
        throw DomainRejection('the completion is derived from the measurements');
      }
      final (_, original) = await rows.occurrence();
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
      await rows.outbox('completion', id, done ? (existing == null ? 'create' : 'update') : 'delete',
          existing?.version, row.toJson());
      // P03 D6c: a tick after the occurrence's result was stored changes it
      // (missed -> done, or back), recorded as a new version.
      final stored = await (db.select(db.periodResults)
            ..where((r) => r.id.equals(periodResultIdOf(taskId, '$original', 'occurrence')) & r.deletedAt.isNull()))
          .getSingleOrNull();
      final changed = stored != null &&
          await rewriteStoredResult(db, stored, done ? d.HabitOutcome.done : d.HabitOutcome.missed, null,
              operationId: cmd.operationId, workspaceId: cmd.workspaceId, actor: cmd.actor.toString(), now: now);
      return HandlerOutcome(
        entityId: taskId,
        operationType: 'update',
        changeSet: {'id': taskId, 'occurrence': '$original', 'done': done, if (changed) 'closedResultChanged': true},
        events: [DomainEvent(done ? 'OccurrenceCompleted' : 'OccurrenceReopened',
            {'id': taskId, 'originalDate': '$original'})],
      );
  }
  throw DomainRejection('unknown op: $op');
}
