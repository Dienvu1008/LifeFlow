// P03 T1 (ADR-0036): measurements, period evaluation and habit tracking.
// Pure functions; owner decisions D6–D10.
//
//   - A correction is a new measurement that supersedes the old one; the
//     old one stays in history and leaves the totals (LF-INV-EXEC-001).
//   - A period without a current measurement is "no data", never 0 or
//     "not achieved" (LF-INV-HEALTH-002).
//   - Completion is derived from the measurements, never set by them
//     (LF-INV-TASK-010, GS-01).
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart';

import 'task.dart';

enum MeasurementSource { manual, focusSession, import }

class Measurement {
  const Measurement({
    required this.id,
    required this.taskId,
    required this.value,
    required this.localDate,
    required this.recordedAt,
    this.source = MeasurementSource.manual,
    this.deviceId,
    this.note,
    this.supersedesId,
    this.withdrawn = false,
  });

  final String id;
  final String taskId;
  final double value;

  /// The day it counts for, fixed when recorded (D10).
  final LocalDate localDate;
  final Instant recordedAt;

  /// Provenance (LF-INV-HEALTH-004).
  final MeasurementSource source;
  final String? deviceId;
  final String? note;

  /// The measurement this one corrects.
  final String? supersedesId;

  /// A correction that removes the superseded value without a new one.
  final bool withdrawn;
}

/// Why a measurement value is refused (D7: values >= 0, finite).
String? measurementValueError(double value) =>
    !value.isFinite || value < 0 ? 'a measurement must be 0 or more' : null;

/// The measurements that count: neither superseded nor withdrawn. History
/// (the superseded ones) is kept by the caller (LF-INV-EXEC-001).
List<Measurement> currentMeasurements(Iterable<Measurement> all) {
  final list = all.toList();
  final superseded = list.map((m) => m.supersedesId).nonNulls.toSet();
  return [for (final m in list) if (!superseded.contains(m.id) && !m.withdrawn) m];
}

/// The period's aggregate, or null when it has no current measurement
/// (no data, not zero).
double? aggregate(Iterable<Measurement> current, TargetAggregation how) {
  final list = current.toList();
  if (list.isEmpty) return null;
  switch (how) {
    case TargetAggregation.sum:
      return list.fold<double>(0, (a, m) => a + m.value);
    case TargetAggregation.max:
      return list.map((m) => m.value).reduce((a, b) => a > b ? a : b);
    case TargetAggregation.latest:
      list.sort((a, b) {
        final c = a.recordedAt.utc.compareTo(b.recordedAt.utc);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      return list.last.value;
    case TargetAggregation.average:
      return list.fold<double>(0, (a, m) => a + m.value) / list.length;
  }
}

enum PeriodState {
  /// Not decided yet: the period is still running.
  inProgress,
  achieved,
  notAchieved,

  /// No current measurement (not zero, not failed; D8, HEALTH-002).
  noData,
}

/// D8: "at least" is achieved as soon as the aggregate reaches the minimum;
/// "at most" and "about" are judged when the period has ended. Bounds are
/// inclusive (GS-02).
PeriodState evaluate(MeasurableTarget target, double? value, {required bool periodEnded}) {
  if (value == null) return PeriodState.noData;
  switch (target.type) {
    case TargetType.atLeast:
      if (value >= target.min!) return PeriodState.achieved;
      return periodEnded ? PeriodState.notAchieved : PeriodState.inProgress;
    case TargetType.atMost:
      if (!periodEnded) return PeriodState.inProgress;
      return value <= target.max! ? PeriodState.achieved : PeriodState.notAchieved;
    case TargetType.about:
      if (!periodEnded) return PeriodState.inProgress;
      return value >= target.min! && value <= target.max! ? PeriodState.achieved : PeriodState.notAchieved;
  }
}

/// A period of a task: the dates whose measurements count, its identity
/// and whether it has ended on [today].
class TaskPeriod {
  const TaskPeriod({required this.key, this.from, this.to});

  /// Identity: the first day of the period, or null for the one period of
  /// a non-repeating task.
  final LocalDate? key;

  /// First and last day (inclusive). Null = open on that side (a one-off
  /// task: all its measurements count).
  final LocalDate? from;
  final LocalDate? to;

  bool contains(LocalDate d) => (from == null || !d.isBefore(from!)) && (to == null || !d.isAfter(to!));

  /// Ended once [today] is after its last day. A period without a last day
  /// never ends by itself.
  bool hasEndedOn(LocalDate today) => to != null && today.isAfter(to!);
}

/// D6: the period of [date]. A repeating task: the rule's period (kernel
/// `rulePeriodOf`). A non-repeating task: one period, ending after its last
/// planned date (end, else deadline, else start), or never without one.
/// Null before a repeating task's first period.
TaskPeriod? periodOf({ScheduleSpec? spec, RecurrenceRule? rule, required LocalDate date}) {
  if (spec != null && rule != null) {
    final w = rulePeriodOf(rule, spec, date);
    return w == null ? null : TaskPeriod(key: w.from, from: w.from, to: w.to);
  }
  final last = spec == null ? null : (spec.end ?? spec.deadline ?? spec.start)?.date;
  return TaskPeriod(key: null, to: last);
}

/// The state of [period] for a measurable task.
PeriodState periodState(MeasurableTarget target, TaskPeriod period, Iterable<Measurement> all, LocalDate today) {
  final inPeriod = currentMeasurements(all).where((m) => period.contains(m.localDate));
  return evaluate(target, aggregate(inPeriod, target.aggregation), periodEnded: period.hasEndedOn(today));
}

// --- habit tracking (D6b/D6c) --------------------------------------------------

/// The result of an ended period (measured) or occurrence (unmeasured).
enum HabitOutcome { done, missed, achieved, notAchieved, noData }

extension HabitOutcomeX on HabitOutcome {
  bool get isSuccess => this == HabitOutcome.done || this == HabitOutcome.achieved;

  /// "no data" is not a judgement: it counts neither for nor against.
  bool get isJudged => this != HabitOutcome.noData;
}

/// An unmeasured habit's occurrence (D6c): done when ticked; missed when its
/// period ended without a tick; null while still open.
HabitOutcome? occurrenceOutcome({required bool ticked, required bool periodEnded}) =>
    ticked ? HabitOutcome.done : (periodEnded ? HabitOutcome.missed : null);

/// A measured period's state as a stored outcome (D9), or null while open.
HabitOutcome? outcomeOf(PeriodState s) => switch (s) {
      PeriodState.achieved => HabitOutcome.achieved,
      PeriodState.notAchieved => HabitOutcome.notAchieved,
      PeriodState.noData => HabitOutcome.noData,
      PeriodState.inProgress => null,
    };

class CompletionRate {
  const CompletionRate(this.successes, this.judged);
  final int successes;

  /// Outcomes that are a judgement (no data excluded).
  final int judged;

  /// Null when nothing has been judged yet.
  double? get ratio => judged == 0 ? null : successes / judged;
}

CompletionRate completionRate(Iterable<HabitOutcome> outcomes) {
  var s = 0, j = 0;
  for (final o in outcomes) {
    if (!o.isJudged) continue;
    j++;
    if (o.isSuccess) s++;
  }
  return CompletionRate(s, j);
}

/// The current streak: consecutive successes counted back from the newest.
/// [newestFirst] may start with the open period (null): it is skipped, so
/// today's not-yet-done habit does not break the streak; a success in the
/// open period counts. "No data" ends a streak (a streak needs proof), but
/// is never counted as a failure in the rate.
int currentStreak(List<HabitOutcome?> newestFirst) {
  var n = 0;
  for (var i = 0; i < newestFirst.length; i++) {
    final o = newestFirst[i];
    if (o == null) {
      if (i == 0) continue;
      break;
    }
    if (!o.isSuccess) break;
    n++;
  }
  return n;
}
