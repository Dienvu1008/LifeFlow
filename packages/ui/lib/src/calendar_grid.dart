// P03 UX U5 (ADR-0049): the day and week time grid as pure functions:
// where a minute of the day is drawn (with the night hours folded, U-D5),
// which minute a tap means, where a timed item sits on a day, and how
// overlapping items share the width. Times are the DEVICE's wall clock,
// already resolved by the Time Kernel (EventItem/AgendaItem.deviceStart), so
// a 23 h or 25 h DST day is still drawn as 00:00-24:00 of wall-clock time.
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

const minutesPerDay = 24 * 60;

/// Taps snap to this many minutes.
const slotMinutes = 15;

/// The shortest an item is drawn (an item without an end, or of a few
/// minutes, stays readable and tappable).
const minDrawnMinutes = 30;

/// Zoom limits: the height of one hour.
const minHourHeight = 24.0;
const maxHourHeight = 160.0;
const defaultHourHeight = 48.0;

/// The hidden part of the day as sorted, non-overlapping [from, to)
/// segments. [from] > [to] wraps past midnight; equal hides nothing.
List<(int, int)> hiddenSegments(int from, int to) {
  final f = from.clamp(0, minutesPerDay), t = to.clamp(0, minutesPerDay);
  if (f == t) return const [];
  if (f < t) return [(f, t)];
  return [if (t > 0) (0, t), if (f < minutesPerDay) (f, minutesPerDay)];
}

/// Vertical positions on the grid. A hidden segment is folded into a band
/// of [foldedHeight]; everything else is [hourHeight] per hour.
class GridScale {
  GridScale({required this.hourHeight, this.hidden = const [], this.foldedHeight = 28});
  final double hourHeight;
  final List<(int, int)> hidden;
  final double foldedHeight;

  double get _perMinute => hourHeight / 60;

  /// The top of [minute] (0..1440).
  double yOf(int minute) {
    final m = minute.clamp(0, minutesPerDay);
    var y = 0.0;
    var at = 0;
    for (final (from, to) in hidden) {
      if (m <= from) break;
      y += (from - at) * _perMinute;
      if (m < to) return y + foldedHeight * (m - from) / (to - from);
      y += foldedHeight;
      at = to;
    }
    return y + (m - at) * _perMinute;
  }

  double get height => yOf(minutesPerDay);

  /// The hidden segment drawn at [y], if any.
  (int, int)? foldAt(double y) {
    for (final s in hidden) {
      if (y >= yOf(s.$1) && y < yOf(s.$2)) return s;
    }
    return null;
  }

  /// The slot a tap at [y] means: snapped down to [slotMinutes]; in a fold,
  /// its first visible minute.
  int minuteAt(double y) {
    final fold = foldAt(y);
    if (fold != null) return fold.$2 >= minutesPerDay ? minutesPerDay - slotMinutes : fold.$2;
    var lo = 0, hi = minutesPerDay;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (yOf(mid) <= y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final snapped = lo - lo % slotMinutes;
    return snapped.clamp(0, minutesPerDay - slotMinutes);
  }
}

/// One timed item on one day, in minutes of that day.
class DaySpan {
  const DaySpan(this.key, this.start, this.end);
  final String key;
  final int start;
  final int end;
  @override
  bool operator ==(Object o) => o is DaySpan && o.key == key && o.start == start && o.end == end;
  @override
  int get hashCode => Object.hash(key, start, end);
  @override
  String toString() => 'DaySpan($key, $start-$end)';
}

/// Where a timed item with device-zone [start] and [end] sits on [day], or
/// null when it is not on that day or not timed. A span over midnight is on
/// each day it touches (to 24:00, from 00:00); an end at 00:00 does not put
/// it on that day. A missing end, or an end not after the start on the same
/// day (a DST overlap can do that), draws [minDrawnMinutes].
DaySpan? daySpan(String key, SchedulePointInput? start, SchedulePointInput? end, LocalDate day) {
  if (start == null || !start.isTimed) return null;
  final sDate = start.date, sMin = start.time!.minuteOfDay;
  final e = end != null && end.isTimed ? end : null;
  var eDate = e?.date ?? sDate;
  var eMin = e == null ? sMin + minDrawnMinutes : e.time!.minuteOfDay;
  if (e != null && eDate.isAfter(sDate) && eMin == 0) {
    eDate = eDate.addDays(-1);
    eMin = minutesPerDay;
  }
  if (day.isBefore(sDate) || day.isAfter(eDate)) return null;
  var s = day == sDate ? sMin : 0;
  var en = day == eDate ? eMin : minutesPerDay;
  if (en - s < minDrawnMinutes) en = s + minDrawnMinutes;
  if (en > minutesPerDay) {
    en = minutesPerDay;
    if (s > minutesPerDay - minDrawnMinutes) s = minutesPerDay - minDrawnMinutes;
  }
  return DaySpan(key, s, en);
}
/// A span with its place across the width: column [column] of [columns].
class PlacedSpan {
  const PlacedSpan(this.span, this.column, this.columns);
  final DaySpan span;
  final int column;
  final int columns;
  @override
  String toString() => '${span.key}:$column/$columns';
}

/// Overlapping spans share the width side by side: each group of spans that
/// overlap (directly or through others) gets as many columns as it needs;
/// each span takes the first free column. Deterministic: by start, longer
/// first, then key.
List<PlacedSpan> placeSpans(List<DaySpan> spans) {
  final sorted = [...spans]..sort((a, b) {
      final c = a.start.compareTo(b.start);
      if (c != 0) return c;
      final l = (b.end - b.start).compareTo(a.end - a.start);
      return l != 0 ? l : a.key.compareTo(b.key);
    });
  final out = <PlacedSpan>[];
  var group = <(DaySpan, int)>[];
  var groupEnd = -1;
  void flush() {
    final n = group.fold(0, (m, g) => g.$2 + 1 > m ? g.$2 + 1 : m);
    out.addAll([for (final (s, c) in group) PlacedSpan(s, c, n)]);
    group = [];
  }

  final columnEnds = <int>[];
  for (final s in sorted) {
    if (s.start >= groupEnd && group.isNotEmpty) {
      flush();
      columnEnds.clear();
    }
    var col = columnEnds.indexWhere((end) => end <= s.start);
    if (col < 0) {
      col = columnEnds.length;
      columnEnds.add(s.end);
    } else {
      columnEnds[col] = s.end;
    }
    group.add((s, col));
    if (s.end > groupEnd) groupEnd = s.end;
  }
  if (group.isNotEmpty) flush();
  return out;
}

/// The 12 months of the year view: each month's grid of 6 weeks from
/// [first] (dates outside the month are null).
List<List<LocalDate?>> yearMonthGrid(int year, int month, Weekday first) {
  final start = LocalDate(year, month, 1);
  final lead = (start.weekday.index - first.index + 7) % 7;
  final days = LocalDate.daysInMonth(year, month);
  return [
    for (var w = 0; w < 6; w++)
      [
        for (var i = 0; i < 7; i++)
          () {
            final n = w * 7 + i - lead + 1;
            return n < 1 || n > days ? null : LocalDate(year, month, n);
          }(),
      ],
  ];
}
