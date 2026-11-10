// RecurrenceRule and the bounded occurrence window query
// (FR-PLAN-06..09, ADR-0007, ADR-0028, P02 plan D1–D4).
//
// Rules that keep a series stable:
//  - dates are counted from the series start, never from the queried window,
//    so any set of windows gives the same occurrences (GS-03, AC-06.1/06.2);
//  - an occurrence is identified by its ORIGINAL date (unique in a series,
//    LF-INV-PLAN-012); exceptions are keyed by it and applied after
//    generation, so they survive rule edits that keep that date
//    (LF-INV-PLAN-011);
//  - "after N" counts the rule's dates; exceptions do not change the count,
//    so skipping one occurrence never shifts the later ones;
//  - the month-end rule and the week start belong to the rule (stored with
//    the series), not to a device setting (owner decision D2/D3);
//  - every query is bounded (window length and result size, D1,
//    LF-INV-PLAN-010) and says when it was truncated.
import 'package:foundation/foundation.dart';

import 'schedule.dart';
import 'zones.dart';

enum Frequency { daily, weekly, monthly, yearly }

/// What a monthly or yearly series does in a month that has no such day
/// (the 29th–31st, or Feb 29 in a common year). Owner decision D2.
enum MonthEndRule {
  /// No occurrence that month or year (iCalendar, Google Calendar).
  skip,

  /// The last day of that month.
  lastDay,
}

sealed class RecurrenceEnd {
  const RecurrenceEnd();
}

final class EndsNever extends RecurrenceEnd {
  const EndsNever();
  @override
  bool operator ==(Object o) => o is EndsNever;
  @override
  int get hashCode => 0;
}

/// The last possible occurrence date (inclusive).
final class EndsOnDate extends RecurrenceEnd {
  const EndsOnDate(this.date);
  final LocalDate date;
  @override
  bool operator ==(Object o) => o is EndsOnDate && o.date == date;
  @override
  int get hashCode => date.hashCode;
}

/// Exactly [count] occurrences (counted on the rule's dates).
final class EndsAfterCount extends RecurrenceEnd {
  const EndsAfterCount(this.count);
  final int count;
  @override
  bool operator ==(Object o) => o is EndsAfterCount && o.count == count;
  @override
  int get hashCode => count.hashCode;
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.byWeekday,
    this.end = const EndsNever(),
    this.monthEndRule = MonthEndRule.skip,
    this.weekStart = Weekday.monday,
  });

  final Frequency frequency;

  /// Every [interval] days, weeks, months or years (1 = every).
  final int interval;

  /// Weekly only: the days of the week. Null = the weekday of the start.
  final Set<Weekday>? byWeekday;
  final RecurrenceEnd end;
  final MonthEndRule monthEndRule;

  /// Which day a week begins on, for "every N weeks" (owner decision D3).
  final Weekday weekStart;

  static const maxInterval = 999;
  static const maxCount = 10000;

  @override
  bool operator ==(Object o) =>
      o is RecurrenceRule &&
      o.frequency == frequency &&
      o.interval == interval &&
      _sameSet(o.byWeekday, byWeekday) &&
      o.end == end &&
      o.monthEndRule == monthEndRule &&
      o.weekStart == weekStart;
  @override
  int get hashCode => Object.hash(frequency, interval,
      Object.hashAllUnordered(byWeekday ?? const <Weekday>{}), end, monthEndRule, weekStart);

  static bool _sameSet(Set<Weekday>? a, Set<Weekday>? b) =>
      (a ?? const {}).length == (b ?? const {}).length &&
      (a ?? const {}).containsAll(b ?? const {});
}

enum RecurrenceError {
  intervalOutOfRange,
  countOutOfRange,
  weekdaysOnlyForWeekly,
  noWeekdays,
  endBeforeStart,
}

/// Checks [rule] for a series that starts on [start].
Result<RecurrenceRule, RecurrenceError> validateRule(RecurrenceRule rule, LocalDate start) {
  if (rule.interval < 1 || rule.interval > RecurrenceRule.maxInterval) {
    return const Err(RecurrenceError.intervalOutOfRange);
  }
  final wd = rule.byWeekday;
  if (wd != null && rule.frequency != Frequency.weekly) {
    return const Err(RecurrenceError.weekdaysOnlyForWeekly);
  }
  if (wd != null && wd.isEmpty) return const Err(RecurrenceError.noWeekdays);
  switch (rule.end) {
    case EndsAfterCount(:final count)
        when count < 1 || count > RecurrenceRule.maxCount:
      return const Err(RecurrenceError.countOutOfRange);
    case EndsOnDate(:final date) when date.isBefore(start):
      return const Err(RecurrenceError.endBeforeStart);
    default:
  }
  return Ok(rule);
}

// --- exceptions ---------------------------------------------------------------

sealed class ExceptionKind {
  const ExceptionKind();
}

/// The occurrence is not shown.
final class SkipOccurrence extends ExceptionKind {
  const SkipOccurrence();
}

/// The occurrence is shown as cancelled (an event that will not happen).
final class CancelOccurrence extends ExceptionKind {
  const CancelOccurrence();
}

/// The occurrence happens on another date (and, for timed items, optionally
/// at another time; its planned length is kept).
final class MoveOccurrence extends ExceptionKind {
  const MoveOccurrence(this.toDate, {this.toTime});
  final LocalDate toDate;
  final TimeOfDayValue? toTime;
}

/// The occurrence has different details. The patch belongs to the owner
/// (Task or Event); the kernel only carries it.
final class EditOccurrence extends ExceptionKind {
  const EditOccurrence(this.patch);
  final Map<String, Object?> patch;
}

/// A change to one occurrence, keyed by its original date (FR-PLAN-08).
class OccurrenceException {
  const OccurrenceException(this.originalDate, this.kind);
  final LocalDate originalDate;
  final ExceptionKind kind;
}

// --- occurrences ---------------------------------------------------------------

class Occurrence {
  const Occurrence({
    required this.seriesId,
    required this.originalDate,
    required this.schedule,
    this.isException = false,
    this.isCancelled = false,
    this.patch,
  });

  final String seriesId;

  /// The date the rule gave this occurrence; its identity in the series.
  final LocalDate originalDate;

  /// The schedule of this occurrence (shifted, and moved if an exception
  /// says so). Its points keep the kinds of the series' schedule.
  final ScheduleSpec schedule;
  final bool isException;
  final bool isCancelled;
  final Map<String, Object?>? patch;

  /// First and last calendar date the occurrence covers.
  LocalDate get firstDate => (schedule.start ?? schedule.end ?? schedule.deadline)!.date;
  LocalDate get lastDate => (schedule.end ?? schedule.start ?? schedule.deadline)!.date;

  @override
  String toString() => 'Occurrence($seriesId, $originalDate, $schedule'
      '${isException ? ', exception' : ''}${isCancelled ? ', cancelled' : ''})';
}

/// Bounds of one query (owner decision D1). Values outside the hard bounds
/// are clamped, so a query is always bounded (LF-INV-PLAN-010).
class OccurrenceLimits {
  const OccurrenceLimits._(this.maxOccurrences, this.maxWindowDays);

  factory OccurrenceLimits({int maxOccurrences = defaultMaxOccurrences, int maxWindowDays = defaultMaxWindowDays}) =>
      OccurrenceLimits._(
        maxOccurrences.clamp(minMaxOccurrences, hardMaxOccurrences),
        maxWindowDays.clamp(minMaxWindowDays, hardMaxWindowDays),
      );

  static const defaultMaxOccurrences = 1000;
  static const defaultMaxWindowDays = 400;
  static const minMaxOccurrences = 100;
  static const hardMaxOccurrences = 5000;
  static const minMaxWindowDays = 31;
  static const hardMaxWindowDays = 1100;

  static const standard = OccurrenceLimits._(defaultMaxOccurrences, defaultMaxWindowDays);

  final int maxOccurrences;
  final int maxWindowDays;
}

/// A date range, both ends inclusive.
class DateWindow {
  DateWindow(this.from, this.to) {
    if (to.isBefore(from)) throw ArgumentError('window ends before it starts');
  }
  final LocalDate from;
  final LocalDate to;
  int get days => from.daysUntil(to) + 1;
  bool overlaps(LocalDate a, LocalDate b) => !b.isBefore(from) && !a.isAfter(to);
}

class OccurrenceWindowResult {
  const OccurrenceWindowResult(this.occurrences, {required this.truncated, required this.coveredTo});
  final List<Occurrence> occurrences;

  /// The window was too long or had too many occurrences; the caller shows a
  /// notice (LF-INV-PLAN-010, UC-06 E1).
  final bool truncated;

  /// The last date the result is complete for.
  final LocalDate coveredTo;
}

LocalDate _anchor(ScheduleSpec s) => (s.start ?? s.end ?? s.deadline)!.date;

SchedulePoint? _shift(SchedulePoint? p, int days) => switch (p) {
      null => null,
      DatePoint(:final date) => DatePoint(date.addDays(days)),
      TimedPoint(:final wallClock) => TimedPoint(wallClock.onDate(wallClock.date.addDays(days))),
    };

ScheduleSpec _shiftSpec(ScheduleSpec s, int days) =>
    ScheduleSpec(start: _shift(s.start, days), end: _shift(s.end, days), deadline: _shift(s.deadline, days));

ScheduleSpec _moved(ScheduleSpec base, LocalDate original, MoveOccurrence m) {
  final shifted = _shiftSpec(base, original.daysUntil(m.toDate));
  final t = m.toTime;
  final s = shifted.start;
  if (t == null || s is! TimedPoint) return shifted;
  final newStart = TimedPoint(ZonedWallClock(s.wallClock.date, t, s.wallClock.zone));
  final e = shifted.end;
  SchedulePoint? newEnd = e;
  if (e is TimedPoint) {
    final length = instantOf(e).utc.difference(instantOf(s).utc);
    newEnd = TimedPoint(wallClockAt(Instant(instantOf(newStart).utc.add(length)), e.wallClock.zone));
  }
  return ScheduleSpec(start: newStart, end: newEnd, deadline: shifted.deadline);
}

int _monthsOf(RecurrenceRule r, int k) =>
    k * r.interval * (r.frequency == Frequency.yearly ? 12 : 1);

/// The first day of the week (by the rule's week start) containing [d].
LocalDate _weekOf(RecurrenceRule r, LocalDate d) =>
    d.addDays(-((d.weekday.isoNumber - r.weekStart.isoNumber + 7) % 7));

/// The first calendar day of period number [k]. Always a real date.
LocalDate _periodStart(RecurrenceRule r, LocalDate anchor, int k) => switch (r.frequency) {
      Frequency.daily => anchor.addDays(k * r.interval),
      Frequency.weekly => _weekOf(r, anchor).addDays(k * r.interval * 7),
      Frequency.monthly || Frequency.yearly => anchor.addMonthsClamped(_monthsOf(r, k)),
    };

/// Rule dates of one period (day, week, month or year number [k]), sorted.
List<LocalDate> _datesOfPeriod(RecurrenceRule r, LocalDate anchor, int k) {
  switch (r.frequency) {
    case Frequency.daily:
      return [anchor.addDays(k * r.interval)];
    case Frequency.weekly:
      final days = r.byWeekday ?? {anchor.weekday};
      final base = _periodStart(r, anchor, k);
      final offsets = [for (final d in days) (d.isoNumber - r.weekStart.isoNumber + 7) % 7]..sort();
      return [for (final o in offsets) base.addDays(o)];
    case Frequency.monthly:
    case Frequency.yearly:
      final months = _monthsOf(r, k);
      final d = r.monthEndRule == MonthEndRule.skip
          ? anchor.addMonthsExact(months)
          : anchor.addMonthsClamped(months);
      return d == null ? const [] : [d];
  }
}

/// A period number safely before [date] (only used when the series has no
/// count, so periods can be skipped without counting them).
int _periodBefore(RecurrenceRule r, LocalDate anchor, LocalDate date) {
  final days = anchor.daysUntil(date);
  if (days <= 0) return 0;
  final k = switch (r.frequency) {
    Frequency.daily => days ~/ r.interval,
    Frequency.weekly => days ~/ (7 * r.interval),
    Frequency.monthly => ((date.year - anchor.year) * 12 + date.month - anchor.month) ~/ r.interval,
    Frequency.yearly => (date.year - anchor.year) ~/ r.interval,
  };
  return k > 1 ? k - 1 : 0;
}

/// The rule's dates (original dates) from [from] to [to] inclusive, in order.
/// Dates before the series start never count. Bounded by [to].
Iterable<LocalDate> _ruleDates(RecurrenceRule r, LocalDate anchor, LocalDate from, LocalDate to) sync* {
  final count = switch (r.end) { EndsAfterCount(:final count) => count, _ => null };
  final until = switch (r.end) { EndsOnDate(:final date) => date, _ => null };
  var k = count == null ? _periodBefore(r, anchor, from) : 0;
  var produced = 0;
  while (true) {
    // Periods only move forward: once one starts after [to], stop. This also
    // bounds months that have no occurrence (month-end rule "skip").
    if (_periodStart(r, anchor, k).isAfter(to)) return;
    for (final d in _datesOfPeriod(r, anchor, k)) {
      if (d.isBefore(anchor)) continue;
      if (until != null && d.isAfter(until)) return;
      if (count != null && produced >= count) return;
      produced++;
      if (d.isAfter(to)) return;
      if (!d.isBefore(from)) yield d;
    }
    k++;
  }
}

/// The last original date of a series, or null when it never ends. Used to
/// store a date range for pre-filtering window queries (ADR-0029).
LocalDate? lastRuleDate(ScheduleSpec spec, RecurrenceRule rule) {
  final anchor = _anchor(spec);
  final LocalDate bound;
  switch (rule.end) {
    case EndsNever():
      return null;
    case EndsOnDate(:final date):
      bound = date;
    case EndsAfterCount():
      // The count stops the walk; the bound only has to be far enough.
      bound = LocalDate.fromEpochDay(anchor.epochDay + 3660000);
  }
  LocalDate? last;
  for (final d in _ruleDates(rule, anchor, anchor, bound)) {
    last = d;
  }
  return last ?? anchor;
}

/// Whether [date] is one of the rule's dates.
bool isRuleDate(RecurrenceRule rule, ScheduleSpec spec, LocalDate date) =>
    _ruleDates(rule, _anchor(spec), date, date).isNotEmpty;

/// The occurrences of a series that touch [window] (FR-PLAN-07/08/09).
/// Pure and deterministic. A spec without a rule has one occurrence.
/// Exceptions are keyed by original date; for one date the last one wins;
/// exceptions on dates that are not rule dates are ignored.
OccurrenceWindowResult occurrencesInWindow({
  required String seriesId,
  required ScheduleSpec spec,
  RecurrenceRule? rule,
  Iterable<OccurrenceException> exceptions = const [],
  required DateWindow window,
  OccurrenceLimits limits = OccurrenceLimits.standard,
}) {
  var truncated = false;
  var to = window.to;
  if (window.days > limits.maxWindowDays) {
    truncated = true;
    to = window.from.addDays(limits.maxWindowDays - 1);
  }
  final w = DateWindow(window.from, to);
  final anchor = _anchor(spec);
  final span = anchor.daysUntil(((spec.end ?? spec.start ?? spec.deadline)!).date);

  final out = <Occurrence>[];
  if (rule == null) {
    final o = Occurrence(seriesId: seriesId, originalDate: anchor, schedule: spec);
    if (w.overlaps(o.firstDate, o.lastDate)) out.add(o);
    return OccurrenceWindowResult(out, truncated: truncated, coveredTo: to);
  }

  // Later exceptions for the same original date replace earlier ones.
  final byDate = <LocalDate, OccurrenceException>{
    for (final e in exceptions) e.originalDate: e,
  };

  Occurrence build(LocalDate original) {
    final base = _shiftSpec(spec, anchor.daysUntil(original));
    final ex = byDate[original];
    return switch (ex?.kind) {
      null || SkipOccurrence() => Occurrence(seriesId: seriesId, originalDate: original, schedule: base),
      CancelOccurrence() => Occurrence(
          seriesId: seriesId, originalDate: original, schedule: base, isException: true, isCancelled: true),
      // [spec] sits on the anchor date, so moving it from the anchor to the
      // target date gives the moved occurrence.
      final MoveOccurrence m => Occurrence(
          seriesId: seriesId, originalDate: original, schedule: _moved(spec, anchor, m), isException: true),
      EditOccurrence(:final patch) => Occurrence(
          seriesId: seriesId, originalDate: original, schedule: base, isException: true, patch: patch),
    };
  }

  final seen = <LocalDate>{};
  void consider(LocalDate original) {
    if (!seen.add(original)) return; // one occurrence per original date
    if (byDate[original]?.kind is SkipOccurrence) return;
    final o = build(original);
    if (w.overlaps(o.firstDate, o.lastDate)) out.add(o);
  }

  // Rule dates whose (unmoved) occurrence can touch the window.
  for (final d in _ruleDates(rule, anchor, w.from.addDays(-span), w.to)) {
    consider(d);
  }
  // Occurrences moved INTO the window from elsewhere.
  for (final e in byDate.values) {
    if (e.kind is MoveOccurrence && !seen.contains(e.originalDate) &&
        isRuleDate(rule, spec, e.originalDate)) {
      consider(e.originalDate);
    }
  }

  out.sort(_byEffectiveStart);
  if (out.length > limits.maxOccurrences) {
    truncated = true;
    out.removeRange(limits.maxOccurrences, out.length);
  }
  return OccurrenceWindowResult(out, truncated: truncated, coveredTo: to);
}

int _byEffectiveStart(Occurrence a, Occurrence b) {
  final c = a.firstDate.compareTo(b.firstDate);
  if (c != 0) return c;
  int minute(Occurrence o) => switch (o.schedule.start ?? o.schedule.end) {
        TimedPoint(:final wallClock) => wallClock.time.minuteOfDay,
        _ => -1,
      };
  final t = minute(a).compareTo(minute(b));
  return t != 0 ? t : a.originalDate.compareTo(b.originalDate);
}

