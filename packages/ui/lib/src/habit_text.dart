// P03 T6a (ADR-0041): how targets, values, period states and results read.
// Text only; every rule is below the ports (AP-12).
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

import 'schedule_text.dart';

/// 6000 -> "6000", 2.5 -> "2.5", 1/3 -> "0.33".
String formatValue(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

String aggregationLabel(TargetAggregationKind a) => switch (a) {
      TargetAggregationKind.sum => 'Total',
      TargetAggregationKind.max => 'Highest',
      TargetAggregationKind.latest => 'Latest',
      TargetAggregationKind.average => 'Average',
    };

String targetKindLabel(TargetKind k) => switch (k) {
      TargetKind.atLeast => 'At least',
      TargetKind.atMost => 'At most',
      TargetKind.about => 'Between',
    };

/// "At least 6000 steps", "Between 10 and 20 minutes", "At most 3 glasses";
/// the aggregation is added when it is not the total.
String describeTarget(TargetInput t) {
  final range = switch (t.kind) {
    TargetKind.atLeast => 'At least ${formatValue(t.min!)}',
    TargetKind.atMost => 'At most ${formatValue(t.max!)}',
    TargetKind.about => 'Between ${formatValue(t.min!)} and ${formatValue(t.max!)}',
  };
  final how = t.aggregation == TargetAggregationKind.sum ? '' : ' (${aggregationLabel(t.aggregation).toLowerCase()})';
  return '$range ${t.unit}$how';
}

String progressLabel(PeriodProgress p) => switch (p) {
      PeriodProgress.inProgress => 'In progress',
      PeriodProgress.achieved => 'Achieved',
      PeriodProgress.notAchieved => 'Not achieved',
      PeriodProgress.noData => 'No data yet',
    };

String outcomeLabel(PeriodOutcome o) => switch (o) {
      PeriodOutcome.done => 'Done',
      PeriodOutcome.missed => 'Missed',
      PeriodOutcome.achieved => 'Achieved',
      PeriodOutcome.notAchieved => 'Not achieved',
      PeriodOutcome.noData => 'No data',
    };

/// "68%" or "—" when nothing is judged yet.
String formatRate(double? r) => r == null ? '—' : '${(r * 100).round()}%';

/// The running period of a measured task in one line, e.g.
/// "4000 / 6000 steps · In progress" (no value: "No data yet").
String? currentPeriodLine(TrackingView v) {
  final t = v.target, c = v.current;
  if (t == null || c == null) return null;
  final goal = switch (t.kind) {
    TargetKind.atLeast => formatValue(t.min!),
    TargetKind.atMost => '≤ ${formatValue(t.max!)}',
    TargetKind.about => '${formatValue(t.min!)}–${formatValue(t.max!)}',
  };
  if (c.value == null) return 'No data yet · goal $goal ${t.unit}';
  return '${formatValue(c.value!)} / $goal ${t.unit} · ${progressLabel(c.progress)}';
}

/// The dates of the running period ("Today", "Mon 9 Nov – Sun 15 Nov").
String periodLabel(CurrentPeriodView c, LocalDate today) {
  if (c.from == null || c.to == null) return c.to == null ? 'Until it is done' : 'Until ${formatDate(c.to!, today: today)}';
  if (c.from == c.to) return formatDate(c.from!, today: today);
  return '${formatDate(c.from!, today: today)} – ${formatDate(c.to!, today: today)}';
}

/// A short summary of the statistics, e.g. "Streak 3 · 30 days 80% · all 75%".
String statsLine(TrackingView v) =>
    'Streak ${v.streak} · 30 days ${formatRate(v.rate30)} · all ${formatRate(v.rateAll)}';

/// Whether [date] falls in the running period of [v] (a measured task).
bool inCurrentPeriod(TrackingView v, LocalDate date) {
  final c = v.current;
  if (c == null) return false;
  return (c.from == null || !date.isBefore(c.from!)) && (c.to == null || !date.isAfter(c.to!));
}

/// Automatic completion (D8): an occurrence in the running period shows the
/// derived state; any other occurrence is shown as not done here (its
/// result is in the history).
bool isDoneAutomatically(TrackingView v, LocalDate date) => inCurrentPeriod(v, date) && v.isCompleteNow;
