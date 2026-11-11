// P03 T4 (ADR-0039): habit, target and completion-policy commands of a
// task, run by TaskCommandHandler in the gateway transaction.
//
//   setHabit       payload: id, isHabit, today
//   setTarget      payload: id, target ({type, min, max, unit, aggregation}
//                  or null), today
//   setCompletion  payload: id, policy (manual | automatic)
//
// The tracking start (trackedSince) is set when a task first becomes
// tracked (a habit or a target) and cleared when it is neither.
import 'package:application/application.dart';
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';

const targetOps = {'setHabit', 'setTarget', 'setCompletion'};

LocalDate _today(Command cmd) {
  try {
    return LocalDate.parse(cmd.payload['today'] as String);
  } catch (_) {
    throw DomainRejection('today is missing');
  }
}

/// The target of a payload, validated (D7), or null.
d.MeasurableTarget? targetOfPayload(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) throw DomainRejection('bad target');
  final type = d.TargetType.values.where((t) => t.name == raw['type']).firstOrNull;
  if (type == null) throw DomainRejection('unknown target type');
  final aggregation = d.TargetAggregation.values.where((a) => a.name == (raw['aggregation'] ?? 'sum')).firstOrNull;
  if (aggregation == null) throw DomainRejection('unknown aggregation');
  double? number(Object? v) => v == null ? null : (v is num ? v.toDouble() : throw DomainRejection('bad target value'));
  final t = d.MeasurableTarget(
    type: type,
    min: number(raw['min']),
    max: number(raw['max']),
    unit: (raw['unit'] as String? ?? '').trim(),
    aggregation: aggregation,
  );
  final error = t.validate();
  if (error != null) throw DomainRejection(error);
  // Only the bounds the type uses are kept.
  return d.MeasurableTarget(
    type: type,
    min: type == d.TargetType.atMost ? null : t.min,
    max: type == d.TargetType.atLeast ? null : t.max,
    unit: t.unit,
    aggregation: aggregation,
  );
}

Future<HandlerOutcome> applyTargetOp(AppDatabase db, Command cmd, Version newVersion, DateTime now) async {
  final op = cmd.payload['op'] as String;
  final id = cmd.payload['id'] as String;
  final task = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (task == null || task.deletedAt != null || task.workspaceId != cmd.workspaceId) {
    throw DomainRejection('task not found');
  }

  HandlerOutcome outcome(Map<String, Object?> change, String event) => HandlerOutcome(
      entityId: id, operationType: 'update', changeSet: {'id': id, ...change}, events: [DomainEvent(event, {'id': id})]);

  switch (op) {
    case 'setHabit':
      final on = cmd.payload['isHabit'] == true;
      if (task.isHabit == on) throw DomainRejection(on ? 'the task is already a habit' : 'the task is not a habit');
      final tracked = on || task.targetType != null;
      final since = tracked ? (task.trackedSince ?? '${_today(cmd)}') : null;
      await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
          isHabit: Value(on), trackedSince: Value(since), version: Value(newVersion.value), updatedAt: Value(now)));
      return outcome({'isHabit': on, 'trackedSince': since}, 'TaskHabitChanged');

    case 'setTarget':
      final t = targetOfPayload(cmd.payload['target']);
      final tracked = t != null || task.isHabit;
      final since = tracked ? (task.trackedSince ?? '${_today(cmd)}') : null;
      await (db.update(db.tasks)..where((r) => r.id.equals(id))).write(TasksCompanion(
        targetType: Value(t?.type.name),
        targetMin: Value(t?.min),
        targetMax: Value(t?.max),
        unit: Value(t?.unit),
        targetAggregation: Value((t?.aggregation ?? d.TargetAggregation.sum).name),
        // Without a target, completion can only be manual (D8).
        completionPolicy: t == null ? const Value('manual') : const Value.absent(),
        trackedSince: Value(since),
        version: Value(newVersion.value),
        updatedAt: Value(now),
      ));
      return outcome({
        'target': t == null
            ? null
            : {'type': t.type.name, 'min': t.min, 'max': t.max, 'unit': t.unit, 'aggregation': t.aggregation.name},
        'trackedSince': since,
      }, 'TaskTargetChanged');

    case 'setCompletion':
      final policy = cmd.payload['policy'];
      if (policy == 'hybrid') throw DomainRejection('hybrid completion comes later (P08)');
      if (policy != 'manual' && policy != 'automatic') throw DomainRejection('unknown completion policy');
      if (policy == 'automatic' && task.targetType == null) {
        throw DomainRejection('automatic completion needs a target');
      }
      if (task.completionPolicy == policy) throw DomainRejection('the completion is already $policy');
      await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
          completionPolicy: Value(policy as String), version: Value(newVersion.value), updatedAt: Value(now)));
      return outcome({'completionPolicy': policy}, 'TaskCompletionPolicyChanged');
  }
  throw DomainRejection('unknown op: $op');
}
