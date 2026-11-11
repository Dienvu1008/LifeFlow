// P03 T4 (ADR-0039): what a tracked task's periods give, from the stored
// rows and the pure domain rules (ADR-0036). Used by the commands (closing
// periods, re-evaluating a closed one) and by the reads, so both always
// agree. A task is tracked when it is a habit or has a target.
//
//   measured (a target)  one result per ended period: achieved / not
//                        achieved / no data, with the aggregate and a copy
//                        of the target (D8, D9)
//   unmeasured habit     one result per ended occurrence: done / missed
//                        (D6c); a one-off habit has one ("once")
//   neither              no results (a plain repeating task, D6b)
//
// Only periods that end on or after the tracking start get a result, so
// marking an old task as a habit does not invent a past of misses.
import 'dart:convert';

import 'package:application/application.dart' show DomainRejection;
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';
import 'execution_rows.dart';
import 'schedule_mapping.dart';

/// Results are derived at most this far back.
const maxTrackedDays = 1100;

/// The key of the one period of a non-repeating task.
const oncePeriodKey = 'once';

d.MeasurableTarget? targetOfRow(Task r) {
  final type = d.TargetType.values.where((t) => t.name == r.targetType).firstOrNull;
  if (type == null || r.unit == null) return null;
  return d.MeasurableTarget(
    type: type,
    min: r.targetMin,
    max: r.targetMax,
    unit: r.unit!,
    aggregation: d.TargetAggregation.values.where((a) => a.name == r.targetAggregation).firstOrNull ??
        d.TargetAggregation.sum,
  );
}

Map<String, Object?> targetJsonOf(d.MeasurableTarget t) =>
    {'type': t.type.name, 'min': t.min, 'max': t.max, 'unit': t.unit, 'aggregation': t.aggregation.name};

d.MeasurableTarget? targetOfJson(String? text) {
  if (text == null) return null;
  try {
    final m = (jsonDecode(text) as Map).cast<String, Object?>();
    final type = d.TargetType.values.byName(m['type'] as String);
    return d.MeasurableTarget(
      type: type,
      min: (m['min'] as num?)?.toDouble(),
      max: (m['max'] as num?)?.toDouble(),
      unit: m['unit'] as String? ?? '',
      aggregation: d.TargetAggregation.values.where((a) => a.name == m['aggregation']).firstOrNull ??
          d.TargetAggregation.sum,
    );
  } catch (_) {
    return null;
  }
}

d.Measurement measurementOfRow(MeasurementRow r) => d.Measurement(
      id: r.id,
      taskId: r.taskId,
      value: r.value,
      localDate: LocalDate.parse(r.localDate),
      recordedAt: Instant(r.recordedAt.toUtc()),
      source: d.MeasurementSource.values.where((s) => s.name == r.source).firstOrNull ?? d.MeasurementSource.manual,
      deviceId: r.deviceId,
      note: r.note,
      supersedesId: r.supersedesId,
      withdrawn: r.withdrawn,
    );

/// A period result: stored, or derived for an ended period not stored yet.
class TaskResult {
  const TaskResult({
    required this.id,
    required this.key,
    required this.kind,
    required this.outcome,
    this.value,
    this.target,
  });
  final String id;

  /// A date, or [oncePeriodKey].
  final String key;

  /// 'period' (measured) or 'occurrence' (unmeasured habit).
  final String kind;
  final d.HabitOutcome outcome;
  final double? value;
  final String? target; // JSON copy of the target used

  LocalDate? get keyDate => key == oncePeriodKey ? null : LocalDate.parse(key);
}

/// One tracked task, as stored.
class TrackedTask {
  TrackedTask._(this.row, this.spec, this.rule, this.exceptions, this.done, this.measurements, this.stored);

  final Task row;
  final tk.ScheduleSpec? spec;
  final tk.RecurrenceRule? rule;
  final Map<LocalDate, tk.ExceptionKind> exceptions;

  /// Original dates of the ticked occurrences.
  final Set<LocalDate> done;
  final List<d.Measurement> measurements;

  /// Stored results by id (live rows).
  final Map<String, PeriodResultRow> stored;

  static Future<TrackedTask?> load(AppDatabase db, String taskId) async {
    final row = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return null;
    tk.ScheduleSpec? spec;
    tk.RecurrenceRule? rule;
    final s = await (db.select(db.schedules)
          ..where((s) => s.id.equals(scheduleIdOf('task', taskId)) & s.deletedAt.isNull()))
        .getSingleOrNull();
    if (s != null) {
      try {
        (spec, rule) = readSchedule(s);
      } on BadScheduleRow {
        spec = null; // an unreadable schedule tracks like a one-off without dates
      }
    }
    final exceptions = {
      for (final e in await (db.select(db.occurrenceExceptions)
            ..where((e) => e.subjectType.equals('task') & e.subjectId.equals(taskId) & e.deletedAt.isNull()))
          .get())
        LocalDate.parse(e.originalDate): exceptionOf(e).kind,
    };
    final done = {
      for (final c in await (db.select(db.occurrenceCompletions)
            ..where((c) => c.taskId.equals(taskId) & c.deletedAt.isNull()))
          .get())
        LocalDate.parse(c.originalDate),
    };
    final measurements = [
      for (final m in await (db.select(db.measurements)
            ..where((m) => m.taskId.equals(taskId) & m.deletedAt.isNull()))
          .get())
        measurementOfRow(m),
    ];
    final stored = {
      for (final r in await (db.select(db.periodResults)
            ..where((r) => r.taskId.equals(taskId) & r.deletedAt.isNull()))
          .get())
        r.id: r,
    };
    return TrackedTask._(row, spec, rule, exceptions, done, measurements, stored);
  }

  d.MeasurableTarget? get target => targetOfRow(row);
  bool get isHabit => row.isHabit;
  bool get isTracked => isHabit || target != null;
  bool get isRepeating => spec != null && rule != null;

  /// The first day whose period counts.
  LocalDate get trackedSince {
    final s = row.trackedSince;
    if (s != null) {
      try {
        return LocalDate.parse(s);
      } catch (_) {}
    }
    final c = row.createdAt.toUtc();
    return LocalDate(c.year, c.month, c.day);
  }

  LocalDate get _anchor => (spec!.start ?? spec!.end ?? spec!.deadline)!.date;

  /// The window of the one-off task's single period.
  d.TaskPeriod get _oncePeriod => d.periodOf(spec: spec, date: trackedSince)!;

  /// The period whose key is [key] ([oncePeriodKey] or its first day).
  d.TaskPeriod? periodOfKey(String key) {
    if (key == oncePeriodKey) return isRepeating ? null : _oncePeriod;
    if (!isRepeating) return null;
    final date = LocalDate.parse(key);
    final w = tk.rulePeriodOf(rule!, spec!, date);
    return w == null || w.from != date ? null : d.TaskPeriod(key: w.from, from: w.from, to: w.to);
  }

  /// The period an occurrence or a measurement on [date] belongs to.
  d.TaskPeriod? periodOn(LocalDate date) =>
      isRepeating ? d.periodOf(spec: spec, rule: rule, date: date) : _oncePeriod;

  bool _occurs(LocalDate original) {
    final ex = exceptions[original];
    return ex is! tk.SkipOccurrence && ex is! tk.CancelOccurrence;
  }

  /// A measured period's result (ended periods only), by [target].
  TaskResult _measured(d.TaskPeriod p, d.MeasurableTarget target, LocalDate today) {
    final inPeriod = d.currentMeasurements(measurements).where((m) => p.contains(m.localDate));
    final value = d.aggregate(inPeriod, target.aggregation);
    final state = d.evaluate(target, value, periodEnded: true);
    final key = p.key?.toString() ?? oncePeriodKey;
    return TaskResult(
      id: periodResultIdOf(row.id, key, 'period'),
      key: key,
      kind: 'period',
      outcome: d.outcomeOf(state)!,
      value: value,
      target: jsonEncode(targetJsonOf(target)),
    );
  }

  TaskResult _occurrence(String key, bool ticked) => TaskResult(
        id: periodResultIdOf(row.id, key, 'occurrence'),
        key: key,
        kind: 'occurrence',
        outcome: ticked ? d.HabitOutcome.done : d.HabitOutcome.missed,
      );

  /// The results of every period that has ended by [today] since the
  /// tracking start, derived with the CURRENT target. Oldest first.
  List<TaskResult> endedResults(LocalDate today) {
    if (!isTracked) return const [];
    final t = target;
    final since = _laterOf(trackedSince, today.addDays(-maxTrackedDays));
    final out = <TaskResult>[];
    if (!isRepeating) {
      final p = _oncePeriod;
      if (!p.hasEndedOn(today) || p.to!.isBefore(since)) return const [];
      if (t != null) return [_measured(p, t, today)];
      return [_occurrence(oncePeriodKey, row.status == 'done')];
    }
    final first = _laterOf(_anchor, since);
    if (!today.isAfter(first)) return const [];
    if (t != null) {
      var p = tk.rulePeriodOf(rule!, spec!, first);
      var guard = 0;
      while (p != null && today.isAfter(p.to) && guard++ < maxTrackedDays + 1) {
        if (tk.ruleDatesIn(rule!, spec!, p).any(_occurs)) {
          out.add(_measured(d.TaskPeriod(key: p.from, from: p.from, to: p.to), t, today));
        }
        p = tk.rulePeriodOf(rule!, spec!, p.to.addDays(1));
      }
      return out;
    }
    // Unmeasured habit: each occurrence whose period has ended.
    for (final date in tk.ruleDatesIn(rule!, spec!, tk.DateWindow(first, today))) {
      if (!_occurs(date)) continue;
      final p = periodOn(date);
      if (p == null || !p.hasEndedOn(today)) continue;
      out.add(_occurrence('$date', done.contains(date)));
    }
    return out;
  }

  /// Stored results win over derived ones (they keep their target, D9).
  /// Newest first.
  List<(TaskResult, bool stored)> results(LocalDate today) {
    final byId = <String, (TaskResult, bool)>{
      for (final r in endedResults(today)) r.id: (r, false),
      for (final s in stored.values)
        if (_outcome(s.outcome) case final o?)
          s.id: (TaskResult(id: s.id, key: s.periodKey, kind: s.kind, outcome: o, value: s.value, target: s.target), true),
    };
    final list = byId.values.toList()
      ..sort((a, b) {
        final ka = a.$1.keyDate, kb = b.$1.keyDate;
        if (ka == null || kb == null) return 0;
        return kb.compareTo(ka);
      });
    return list;
  }

  /// The running period of a measurable task, or null.
  (d.TaskPeriod, double?, d.PeriodState)? current(LocalDate today) {
    final t = target;
    if (t == null) return null;
    final p = periodOn(today);
    if (p == null || p.hasEndedOn(today)) return null;
    final inPeriod = d.currentMeasurements(measurements).where((m) => p.contains(m.localDate));
    final value = d.aggregate(inPeriod, t.aggregation);
    return (p, value, d.evaluate(t, value, periodEnded: false));
  }

  /// Outcomes newest first, the open period(s) first (null = not done yet),
  /// for the streak (D6b).
  List<d.HabitOutcome?> streakInput(LocalDate today) {
    final open = <d.HabitOutcome?>[];
    final c = current(today);
    if (c != null) {
      open.add(c.$3 == d.PeriodState.achieved ? d.HabitOutcome.achieved : null);
    } else if (target == null && isHabit) {
      if (isRepeating) {
        final p = periodOn(today);
        if (p != null && !p.hasEndedOn(today)) {
          final from = _laterOf(p.from!, _anchor);
          if (!from.isAfter(today)) {
            for (final date in tk.ruleDatesIn(rule!, spec!, tk.DateWindow(from, today)).reversed) {
              if (_occurs(date)) open.add(done.contains(date) ? d.HabitOutcome.done : null);
            }
          }
        }
      } else if (!_oncePeriod.hasEndedOn(today)) {
        open.add(row.status == 'done' ? d.HabitOutcome.done : null);
      }
    }
    return [...open, for (final (r, _) in results(today)) r.outcome];
  }
}

LocalDate _laterOf(LocalDate a, LocalDate b) => a.isAfter(b) ? a : b;

d.HabitOutcome? _outcome(String s) => d.HabitOutcome.values.where((o) => o.name == s).firstOrNull;

/// Writes [outcome] (and [value]) into a stored result, as a new version
/// with its outbox row: a late tick or a measurement in a closed period
/// (D6c, D9). Returns whether it changed.
Future<bool> rewriteStoredResult(AppDatabase db, PeriodResultRow old, d.HabitOutcome outcome, double? value,
    {required String operationId, required String workspaceId, required String actor, required DateTime now}) async {
  if (old.outcome == outcome.name && old.value == value) return false;
  final next = old.copyWith(
      outcome: outcome.name, value: Value(value), version: old.version + 1, updatedAt: now, evaluatedAt: now);
  await (db.update(db.periodResults)..where((r) => r.id.equals(old.id))).write(next.toCompanion(false));
  await db.into(db.outbox).insert(OutboxCompanion.insert(
        operationId: operationId,
        entityId: old.id,
        entityType: 'periodResult',
        workspaceId: workspaceId,
        actorId: actor,
        operationType: 'update',
        baseVersion: Value(old.version),
        payload: jsonEncode({...next.toJson(), 'previousOutcome': old.outcome}),
        createdAt: now,
      ));
  return true;
}

/// Re-evaluates the stored measured result of the period of [date] with
/// the target it was stored with (D9). Returns whether it changed.
Future<bool> reevaluateClosedPeriod(AppDatabase db, String taskId, LocalDate date,
    {required String operationId, required String workspaceId, required String actor, required DateTime now}) async {
  final t = await TrackedTask.load(db, taskId);
  if (t == null) return false;
  final p = t.periodOn(date);
  if (p == null) return false;
  final key = p.key?.toString() ?? oncePeriodKey;
  final old = t.stored[periodResultIdOf(taskId, key, 'period')];
  if (old == null) return false;
  final target = targetOfJson(old.target);
  if (target == null) throw DomainRejection('the stored result has no readable target');
  final inPeriod = d.currentMeasurements(t.measurements).where((m) => p.contains(m.localDate));
  final value = d.aggregate(inPeriod, target.aggregation);
  final outcome = d.outcomeOf(d.evaluate(target, value, periodEnded: true))!;
  return rewriteStoredResult(db, old, outcome, value,
      operationId: operationId, workspaceId: workspaceId, actor: actor, now: now);
}
