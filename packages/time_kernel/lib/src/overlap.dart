// Overlap (conflict) detection and workload (FR-PLAN-11, UC-08,
// LF-INV-CAL-002, P02 plan D7). Deterministic and AI-free.
//
//  - Only TIMED items with both a start and an end take part. All-day and
//    date-only items never do (LF-INV-CAL-002, D7), and neither do timed
//    items without an end (a point in time has no length).
//  - Intervals are half-open [start, end): 09:00–10:00 and 10:00–11:00 do
//    not conflict.
//  - The result does not depend on the input order: each pair once, with the
//    smaller id first, sorted.
import 'package:foundation/foundation.dart';

import 'recurrence.dart';
import 'schedule.dart';

/// Something with a known time range, for conflict and workload math.
class TimedItem {
  TimedItem(this.id, this.start, this.end) {
    if (!end.utc.isAfter(start.utc)) {
      throw ArgumentError('a timed item must end after it starts ($id)');
    }
  }
  final String id;
  final Instant start;
  final Instant end;
}

/// The timed range of a schedule, or null when it does not take part in
/// conflicts (all-day, date-only, no end, cancelled, zero length).
/// [id] identifies it in the result (for example "task:<id>@2026-11-09").
TimedItem? timedItemOf(String id, ScheduleSpec s) {
  final a = s.start, b = s.end;
  if (a is! TimedPoint || b is! TimedPoint) return null;
  final start = instantOf(a), end = instantOf(b);
  if (!end.utc.isAfter(start.utc)) return null;
  return TimedItem(id, start, end);
}

/// The timed range of an occurrence (cancelled ones never conflict).
TimedItem? timedItemOfOccurrence(String id, Occurrence o) =>
    o.isCancelled ? null : timedItemOf(id, o.schedule);

class Conflict {
  const Conflict(this.first, this.second);

  /// Ids in order: [first] < [second].
  final String first;
  final String second;

  @override
  bool operator ==(Object o) => o is Conflict && o.first == first && o.second == second;
  @override
  int get hashCode => Object.hash(first, second);
  @override
  String toString() => 'Conflict($first, $second)';
}

/// Every overlapping pair among [items]. O(n log n + conflicts).
List<Conflict> overlaps(Iterable<TimedItem> items) {
  final sorted = items.toList()
    ..sort((a, b) {
      final c = a.start.millis.compareTo(b.start.millis);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final out = <Conflict>{};
  final active = <TimedItem>[];
  for (final it in sorted) {
    active.removeWhere((a) => a.end.millis <= it.start.millis);
    for (final a in active) {
      if (a.id == it.id) continue;
      out.add(a.id.compareTo(it.id) < 0 ? Conflict(a.id, it.id) : Conflict(it.id, a.id));
    }
    active.add(it);
  }
  return out.toList()
    ..sort((x, y) {
      final c = x.first.compareTo(y.first);
      return c != 0 ? c : x.second.compareTo(y.second);
    });
}

/// Planned time of [items] inside [from, to) (overlapping time is counted
/// once per item, as planned work, not as wall time).
Duration workload(Iterable<TimedItem> items, Instant from, Instant to) {
  var ms = 0;
  for (final it in items) {
    final s = it.start.millis > from.millis ? it.start.millis : from.millis;
    final e = it.end.millis < to.millis ? it.end.millis : to.millis;
    if (e > s) ms += e - s;
  }
  return Duration(milliseconds: ms);
}
