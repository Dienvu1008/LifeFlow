// ScheduleSpec (FR-PLAN-01..04, ADR-0007, ADR-0010, ADR-0028).
//
// One schedule per owner (Task or Event). A point is either a calendar date
// (date-only / all-day) or a zoned wall clock (timed). The two kinds are
// different types, and only a timed point has a way to an instant, so a
// date-only schedule is never turned into an instant by accident
// (LF-INV-PLAN-004).
import 'package:foundation/foundation.dart';

import 'zones.dart';

/// A point of a schedule: a date ([DatePoint]) or a wall clock ([TimedPoint]).
sealed class SchedulePoint {
  const SchedulePoint();

  /// The calendar date of the point (for a timed point: its local date).
  LocalDate get date;
}

/// Date only: no time, no zone. Compared as a calendar date.
final class DatePoint extends SchedulePoint {
  const DatePoint(this.date);
  @override
  final LocalDate date;

  @override
  bool operator ==(Object o) => o is DatePoint && o.date == date;
  @override
  int get hashCode => date.hashCode;
  @override
  String toString() => '$date';
}

/// A local date and time in a zone. Resolved to an instant only through
/// [instantOf] (the DST rule of ADR-0010).
final class TimedPoint extends SchedulePoint {
  const TimedPoint(this.wallClock);
  final ZonedWallClock wallClock;

  @override
  LocalDate get date => wallClock.date;

  @override
  bool operator ==(Object o) => o is TimedPoint && o.wallClock == wallClock;
  @override
  int get hashCode => wallClock.hashCode;
  @override
  String toString() => '$wallClock';
}

/// The instant of a timed point. There is deliberately no overload for a
/// [DatePoint] (LF-INV-PLAN-004).
Instant instantOf(TimedPoint p) => resolveWallClock(p.wallClock);

/// The six shapes of FR-PLAN-01.
enum ScheduleShape {
  startDate,
  startDateTime,
  dateRange,
  dateTimeRange,
  endDate,
  endDateTime,
}

/// When something is planned (start and/or end) and, separately, when it is
/// due ([deadline], FR-PLAN-03). At least one of the three is set.
class ScheduleSpec {
  const ScheduleSpec({this.start, this.end, this.deadline});

  final SchedulePoint? start;
  final SchedulePoint? end;

  /// When it is due; independent of the planned time.
  final SchedulePoint? deadline;

  /// The FR-PLAN-01 shape of the planned part, or null when only a deadline
  /// is set (or the spec is invalid).
  ScheduleShape? get shape {
    final s = start, e = end;
    if (s is DatePoint && e == null) return ScheduleShape.startDate;
    if (s is TimedPoint && e == null) return ScheduleShape.startDateTime;
    if (s is DatePoint && e is DatePoint) return ScheduleShape.dateRange;
    if (s is TimedPoint && e is TimedPoint) return ScheduleShape.dateTimeRange;
    if (s == null && e is DatePoint) return ScheduleShape.endDate;
    if (s == null && e is TimedPoint) return ScheduleShape.endDateTime;
    return null;
  }

  /// All-day: the planned part uses dates only (FR-PLAN-04). All-day items
  /// never take part in timed conflicts (LF-INV-CAL-002).
  bool get isAllDay =>
      (start == null || start is DatePoint) &&
      (end == null || end is DatePoint) &&
      (start != null || end != null);

  /// Planned length of a timed range (null otherwise).
  Duration? get duration {
    final s = start, e = end;
    if (s is TimedPoint && e is TimedPoint) {
      return instantOf(e).utc.difference(instantOf(s).utc);
    }
    return null;
  }

  @override
  bool operator ==(Object o) =>
      o is ScheduleSpec && o.start == start && o.end == end && o.deadline == deadline;
  @override
  int get hashCode => Object.hash(start, end, deadline);
  @override
  String toString() => 'ScheduleSpec(start: $start, end: $end, deadline: $deadline)';
}

enum ScheduleError {
  /// Nothing is set.
  empty,

  /// Start and end are of different kinds (one date-only, one timed).
  mixedKinds,

  /// The end is before the start.
  endBeforeStart,

  /// A zone name is not in the zone database.
  unknownZone,
}

/// Checks a schedule (FR-PLAN-01..04). Pure.
Result<ScheduleSpec, ScheduleError> validateSchedule(ScheduleSpec spec) {
  final s = spec.start, e = spec.end, d = spec.deadline;
  if (s == null && e == null && d == null) return const Err(ScheduleError.empty);
  for (final p in [s, e, d]) {
    if (p is TimedPoint && !TimeZones.isKnown(p.wallClock.zone)) {
      return const Err(ScheduleError.unknownZone);
    }
  }
  if (s != null && e != null) {
    if (s.runtimeType != e.runtimeType) return const Err(ScheduleError.mixedKinds);
    final before = switch ((s, e)) {
      (DatePoint a, DatePoint b) => b.date.isBefore(a.date),
      (TimedPoint a, TimedPoint b) => instantOf(b).utc.isBefore(instantOf(a).utc),
      _ => false,
    };
    if (before) return const Err(ScheduleError.endBeforeStart);
  }
  return Ok(spec);
}
