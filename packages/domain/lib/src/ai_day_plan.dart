// P06 T6 (ADR-0086; the determinism boundary, ai-action-governance.md; S-17:
// every small model overlapped times): the model proposes an order and a
// slot for each task; this code decides the times. Pure.
//   kept     a task keeps the model's start when it fits there
//   moved    else the first free time after it that fits, else the first
//            free time of the day: never over a fixed event, another timed
//            item or another task of the plan, never outside the hours,
//            never before "now" on today
//   left     a task that does not fit anywhere is left out, and said so
//   checked  only the tasks asked about, each once; a length the model
//            invents is replaced by the task's own estimate (or 30 minutes)

/// A minute range of one day: [start, end).
class DayInterval {
  const DayInterval(this.start, this.end);
  final int start;
  final int end;
  bool overlaps(DayInterval o) => start < o.end && o.start < end;
  @override
  bool operator ==(Object o) => o is DayInterval && o.start == start && o.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => 'DayInterval($start, $end)';
}

/// A task the plan may place, with the length the app knows for it.
class DayPlanTask {
  const DayPlanTask(this.taskId, {this.minutes});
  final String taskId;

  /// The task's own estimate, if it has one.
  final int? minutes;
}

/// What the model suggested for one task: a start (minutes of the day) and
/// a length, either may be missing or wrong.
class DayPlanWish {
  const DayPlanWish(this.taskId, {this.start, this.minutes});
  final String taskId;
  final int? start;
  final int? minutes;
}

class DayPlanSlot {
  const DayPlanSlot(this.taskId, this.start, this.minutes, {required this.moved});
  final String taskId;
  final int start;
  final int minutes;

  /// Not where the model put it (it did not fit there).
  final bool moved;
  int get end => start + minutes;
  @override
  String toString() => 'DayPlanSlot($taskId, $start+$minutes${moved ? ', moved' : ''})';
}

class DayPlanFit {
  const DayPlanFit(this.slots, {this.unplaced = const [], this.ignored = const []});

  /// In the model's order.
  final List<DayPlanSlot> slots;

  /// Asked about and suggested, but no room for it.
  final List<String> unplaced;

  /// Suggested but not a task of the plan, or suggested twice (dropped).
  final List<String> ignored;
}

/// The longest a planned task may be, and the default length.
const maxPlanMinutes = 8 * 60;
const defaultPlanMinutes = 30;

/// Fits the model's [wishes] for [tasks] into the day [hours], around
/// [busy], with starts on a [step]-minute grid, not before [notBefore].
DayPlanFit fitDayPlan({
  required List<DayPlanTask> tasks,
  required List<DayPlanWish> wishes,
  required DayInterval hours,
  List<DayInterval> busy = const [],
  int? notBefore,
  int step = 5,
}) {
  if (step <= 0 || hours.end <= hours.start) throw ArgumentError('bad hours or step');
  final known = {for (final t in tasks) t.taskId: t};
  final taken = <DayInterval>[...busy];
  final slots = <DayPlanSlot>[];
  final unplaced = <String>[];
  final ignored = <String>[];
  final seen = <String>{};
  final earliest = _up(notBefore == null || notBefore < hours.start ? hours.start : notBefore, step);

  bool free(DayInterval i) => i.start >= earliest && i.end <= hours.end && !taken.any(i.overlaps);

  /// The first start from [from] on the grid where [minutes] fits.
  int? firstFit(int from, int minutes) {
    for (var s = _up(from < earliest ? earliest : from, step); s + minutes <= hours.end; s += step) {
      if (free(DayInterval(s, s + minutes))) return s;
    }
    return null;
  }

  for (final w in wishes) {
    final task = known[w.taskId];
    if (task == null || !seen.add(w.taskId)) {
      ignored.add(w.taskId);
      continue;
    }
    final minutes = switch (w.minutes) {
      final int m when m > 0 && m <= maxPlanMinutes => m,
      _ => task.minutes != null && task.minutes! > 0 && task.minutes! <= maxPlanMinutes ? task.minutes! : defaultPlanMinutes,
    };
    final wanted = w.start;
    final exact = wanted != null && wanted % step == 0 && free(DayInterval(wanted, wanted + minutes));
    final start = exact ? wanted : (firstFit(wanted ?? earliest, minutes) ?? firstFit(earliest, minutes));
    if (start == null) {
      unplaced.add(w.taskId);
      continue;
    }
    taken.add(DayInterval(start, start + minutes));
    slots.add(DayPlanSlot(w.taskId, start, minutes, moved: !exact));
  }
  return DayPlanFit(slots, unplaced: unplaced, ignored: ignored);
}

int _up(int m, int step) => (m + step - 1) ~/ step * step;

/// "HH:MM" as minutes of the day, or null.
int? parseDayMinute(Object? text) {
  if (text is! String) return null;
  final m = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(text.trim());
  if (m == null) return null;
  return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

/// Minutes of the day as "HH:MM".
String formatDayMinute(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
