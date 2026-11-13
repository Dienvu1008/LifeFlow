// P03 T4 (ADR-0039): habits, targets, measurements and period results as
// the UI and the app see them (owner decisions D6–D10). `foundation` types
// only (FF-ARCH-04); every rule is applied below this port (AP-12).
import 'package:foundation/foundation.dart';

import 'command.dart';

enum TargetKind { atLeast, atMost, about }

enum TargetAggregationKind { sum, max, latest, average }

/// D8: manual (you tick) or automatic (derived from the measurements).
/// Hybrid waits for P08.
enum CompletionMode { manual, automatic }

/// A measurable target (D7).
class TargetInput {
  const TargetInput({
    required this.kind,
    this.min,
    this.max,
    required this.unit,
    this.aggregation = TargetAggregationKind.sum,
  });
  final TargetKind kind;
  final double? min;
  final double? max;
  final String unit;
  final TargetAggregationKind aggregation;

  @override
  bool operator ==(Object o) =>
      o is TargetInput && o.kind == kind && o.min == min && o.max == max && o.unit == unit && o.aggregation == aggregation;
  @override
  int get hashCode => Object.hash(kind, min, max, unit, aggregation);
  @override
  String toString() => 'TargetInput(${kind.name}, $min, $max, $unit, ${aggregation.name})';
}

/// Unit suggestions (D7: the unit is free text).
const unitSuggestions = ['minutes', 'hours', 'steps', 'km', 'pages', 'times', 'glasses', 'kg'];

/// The state of a period (D8).
enum PeriodProgress { inProgress, achieved, notAchieved, noData }

/// The result of an ended period or habit occurrence (D6b, D9).
enum PeriodOutcome { done, missed, achieved, notAchieved, noData }

extension PeriodOutcomeX on PeriodOutcome {
  bool get isSuccess => this == PeriodOutcome.done || this == PeriodOutcome.achieved;
}

/// The reason given when a change touches a closed period and was not
/// confirmed (D9). The UI asks, then repeats the call with `confirmClosed`.
const closedPeriodNeedsConfirmation = 'the period is closed: confirm to change its result';

/// One measurement, current or in history (D10, LF-INV-EXEC-001).
class MeasurementView {
  const MeasurementView({
    required this.id,
    required this.value,
    required this.date,
    required this.recordedAt,
    required this.source,
    this.deviceId,
    this.note,
    this.supersedesId,
    this.withdrawn = false,
    this.isCurrent = true,
  });
  final String id;
  final double value;
  final LocalDate date;
  final Instant recordedAt;
  final String source;
  final String? deviceId;
  final String? note;

  /// The measurement this one corrects.
  final String? supersedesId;

  /// A correction that removes the corrected value.
  final bool withdrawn;

  /// Counts in the totals (neither corrected nor a withdrawal).
  final bool isCurrent;
}

/// A stored result (D9), or a derived one for an ended period not stored yet.
class PeriodResultView {
  const PeriodResultView({
    required this.key,
    required this.isOccurrence,
    required this.outcome,
    this.value,
    this.target,
    this.stored = true,
  });

  /// The period's first day or the occurrence's original date; null for
  /// the one period of a non-repeating task.
  final LocalDate? key;

  /// An unmeasured habit's occurrence (done / missed).
  final bool isOccurrence;
  final PeriodOutcome outcome;

  /// The aggregate, when measured.
  final double? value;

  /// The target used (a copy, D9).
  final TargetInput? target;
  final bool stored;
}

/// The running (not ended) period of a measurable task.
class CurrentPeriodView {
  const CurrentPeriodView({this.from, this.to, this.value, required this.progress});
  final LocalDate? from;
  final LocalDate? to;
  final double? value;
  final PeriodProgress progress;
}

/// What a task tracks: habit, target, policy, the current period, history
/// and the statistics (D6b).
class TrackingView {
  const TrackingView({
    required this.taskId,
    required this.title,
    required this.isHabit,
    required this.isRepeating,
    this.target,
    this.completion = CompletionMode.manual,
    this.trackedSince,
    this.current,
    this.results = const [],
    this.measurements = const [],
    this.rate30,
    this.rateAll,
    this.streak = 0,
    this.isCompleteNow = false,
  });
  final String taskId;
  final String title;
  final bool isHabit;
  final bool isRepeating;
  final TargetInput? target;
  final CompletionMode completion;
  final LocalDate? trackedSince;

  /// Measurable tasks only.
  final CurrentPeriodView? current;

  /// Newest first.
  final List<PeriodResultView> results;

  /// Newest first, history included.
  final List<MeasurementView> measurements;

  /// Successes / judged results ("no data" excluded); null when nothing is
  /// judged yet. [rate30]: results of the last 30 days.
  final double? rate30;
  final double? rateAll;
  final int streak;

  /// Automatic policy: the current period is achieved (derived, D8).
  final bool isCompleteNow;

  bool get isMeasurable => target != null;
}

/// P03 UX U6 (owner decision U-D13): what is stored for a period of a
/// measured task completed by hand (manual policy): its target's judgement
/// (achieved / not achieved / no data, the default) or the tick (done /
/// missed). A profile setting (exported, later synced): every device stores
/// the same results. Periods closed after a change follow it; stored results
/// are never rewritten.
enum ManualResults { target, tick }

/// Habit and target commands; failures are returned, never thrown.
abstract interface class HabitService {
  /// U-D13: the profile's choice for measured tasks completed by hand.
  Future<CommandResult> setManualResults(ManualResults value);

  /// D6: the habit flag, independent of the repeat and the target.
  Future<CommandResult> setHabit(String taskId, {required bool isHabit});

  /// Sets (or with null, clears) the target. Clearing also makes the
  /// completion manual. Stored results keep the target they used (D9).
  Future<CommandResult> setTarget(String taskId, TargetInput? target);

  /// Automatic needs a target.
  Future<CommandResult> setCompletion(String taskId, CompletionMode mode);

  /// D10: a value ≥ 0 for [date] (default today; back-dating allowed, not
  /// the future). In a closed period: refused with
  /// [closedPeriodNeedsConfirmation] unless [confirmClosed].
  Future<CommandResult> recordMeasurement(String taskId, double value,
      {LocalDate? date, String? note, bool confirmClosed = false});

  /// A correction is a new measurement replacing [measurementId] in the
  /// totals; the old one stays in history. [value] null withdraws it.
  Future<CommandResult> correctMeasurement(String measurementId, double? value,
      {String? note, bool confirmClosed = false});

  /// Stores the results of the ended periods not stored yet (on app start
  /// and before a target change). Idempotent. Returns how many were stored.
  Future<int> closePeriods({String? taskId});
}

abstract interface class HabitQueries {
  /// U-D13: the active profile's choice (target by default).
  Future<ManualResults> manualResults();

  Future<TrackingView?> tracking(String taskId);

  /// One task's tracking, kept up to date (null when the task is gone).
  Stream<TrackingView?> watchTracking(String taskId);

  /// The habits of the active profile, kept up to date.
  Stream<List<TrackingView>> watchHabits();

  /// Every tracked task (a habit or a target), kept up to date: for the
  /// period states in the task lists and the agenda.
  Stream<List<TrackingView>> watchTracked();
}
