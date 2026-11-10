// P02 T7: when a reminder fires. The kernel only computes trigger instants
// from a schedule and a reminder rule; it schedules nothing
// (planning-scheduling.md §10, ADR-0034).
//
// Anchor of an occurrence: its start, else its deadline, else its end.
//   - a timed point: its own wall clock in its own zone, resolved with the
//     DST rule of ADR-0028 (gap -> the transition instant, overlap -> the
//     earlier instant), so "10 minutes before 09:00 Berlin" is right in
//     every season;
//   - a date-only point (all-day): that date at [allDayTime] in the DEVICE
//     zone. A date is never an instant by itself (LF-INV-PLAN-004); this is
//     the one explicit, documented conversion, used only for reminders.
import 'package:foundation/foundation.dart';

import 'recurrence.dart';
import 'schedule.dart';
import 'zones.dart';

sealed class ReminderRule {
  const ReminderRule();
}

/// [minutes] before the anchor of each occurrence (0 = at the anchor).
final class RemindBefore extends ReminderRule {
  const RemindBefore(this.minutes);
  final int minutes;
  @override
  bool operator ==(Object o) => o is RemindBefore && o.minutes == minutes;
  @override
  int get hashCode => minutes.hashCode;
  @override
  String toString() => 'RemindBefore($minutes)';
}

/// Once, at an absolute instant.
final class RemindAt extends ReminderRule {
  const RemindAt(this.at);
  final Instant at;
  @override
  bool operator ==(Object o) => o is RemindAt && o.at.millis == at.millis;
  @override
  int get hashCode => at.millis.hashCode;
  @override
  String toString() => 'RemindAt(${at.utc.toIso8601String()})';
}

/// At most 28 days before.
const maxReminderOffsetMinutes = 28 * 24 * 60;

/// At most this many reminders on one task or event.
const maxRemindersPerItem = 5;

enum ReminderError { tooMany, offsetOutOfRange, duplicate }

/// Checks a reminder list (counts, ranges, duplicates).
Result<List<ReminderRule>, ReminderError> validateReminders(List<ReminderRule> rules) {
  if (rules.length > maxRemindersPerItem) return const Err(ReminderError.tooMany);
  for (final r in rules) {
    if (r is RemindBefore && (r.minutes < 0 || r.minutes > maxReminderOffsetMinutes)) {
      return const Err(ReminderError.offsetOutOfRange);
    }
  }
  if (rules.toSet().length != rules.length) return const Err(ReminderError.duplicate);
  return Ok(rules);
}

/// The instant reminders of [spec] count from, or null without a point.
Instant? reminderAnchor(ScheduleSpec spec, {required String deviceZone, required TimeOfDayValue allDayTime}) {
  final p = spec.start ?? spec.deadline ?? spec.end;
  return switch (p) {
    null => null,
    TimedPoint() => instantOf(p),
    DatePoint(:final date) => resolveWallClock(ZonedWallClock(date, allDayTime, deviceZone)),
  };
}

/// One reminder that will fire.
class ReminderTrigger {
  const ReminderTrigger({
    required this.seriesId,
    required this.ruleIndex,
    required this.at,
    this.occurrence,
  });
  final String seriesId;

  /// Position of the rule in the item's reminder list.
  final int ruleIndex;
  final Instant at;

  /// The occurrence it reminds of (null for an absolute reminder).
  final Occurrence? occurrence;

  /// Stable identity: `<series>#<rule>@<original date>` (or `@at` for an
  /// absolute reminder), so re-planning finds the same reminder again.
  String get key => occurrence == null
      ? '$seriesId#$ruleIndex@at'
      : '$seriesId#$ruleIndex@${occurrence!.originalDate}';

  @override
  String toString() => 'ReminderTrigger($key, ${at.utc.toIso8601String()})';
}

/// The reminders of one item that fire after [now] and at or before
/// [now] + [horizon], in time order. Cancelled occurrences, and those
/// [include] rejects (for example a done occurrence), never remind.
List<ReminderTrigger> remindersInHorizon({
  required String seriesId,
  required ScheduleSpec? spec,
  RecurrenceRule? rule,
  Iterable<OccurrenceException> exceptions = const [],
  required List<ReminderRule> reminders,
  required Instant now,
  required Duration horizon,
  required String deviceZone,
  required TimeOfDayValue allDayTime,
  bool Function(Occurrence o)? include,
}) {
  final end = Instant(now.utc.add(horizon));
  bool inHorizon(Instant t) => t.utc.isAfter(now.utc) && !t.utc.isAfter(end.utc);
  final out = <ReminderTrigger>[];

  for (var i = 0; i < reminders.length; i++) {
    final r = reminders[i];
    if (r is RemindAt && inHorizon(r.at)) {
      out.add(ReminderTrigger(seriesId: seriesId, ruleIndex: i, at: r.at));
    }
  }

  final before = [
    for (var i = 0; i < reminders.length; i++)
      if (reminders[i] case RemindBefore(:final minutes)) (i, minutes),
  ];
  if (spec != null && before.isNotEmpty) {
    final maxBefore = before.map((b) => b.$2).reduce((a, b) => a > b ? a : b);
    // Dates that can hold an anchor in (now, end + maxBefore]. A timed item
    // in another zone can be a day off the device date: widen by two days.
    final from = dateAt(now, deviceZone).addDays(-2);
    final to = dateAt(Instant(end.utc.add(Duration(minutes: maxBefore))), deviceZone).addDays(2);
    final r = occurrencesInWindow(
      seriesId: seriesId,
      spec: spec,
      rule: rule,
      exceptions: exceptions,
      window: DateWindow(from, to),
      // Bounded by the horizon, not by the user's view limits.
      limits: OccurrenceLimits(maxOccurrences: 5000, maxWindowDays: 1100),
    );
    for (final o in r.occurrences) {
      if (o.isCancelled || (include != null && !include(o))) continue;
      final anchor = reminderAnchor(o.schedule, deviceZone: deviceZone, allDayTime: allDayTime);
      if (anchor == null) continue;
      for (final (i, minutes) in before) {
        final t = Instant(anchor.utc.subtract(Duration(minutes: minutes)));
        if (inHorizon(t)) out.add(ReminderTrigger(seriesId: seriesId, ruleIndex: i, at: t, occurrence: o));
      }
    }
  }
  out.sort((a, b) {
    final c = a.at.utc.compareTo(b.at.utc);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return out;
}
