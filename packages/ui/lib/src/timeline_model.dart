// P03 UX U4 (ADR-0048): the Timeline as pure data. Days around an anchor
// date, loaded in windows of [timelineWindowDays] so every query stays
// bounded (LF-INV-PLAN-010); each day lists its events and task
// occurrences, all-day first, then by time. Overdue one-off tasks go in a
// group at the top of today (U-D3).
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

/// Days per query window.
const timelineWindowDays = 21;

/// The most windows loaded on each side of the anchor (about 18 months).
const timelineMaxWindows = 26;

/// The window [index] (0 = starting at [anchor]; negative = before it).
({LocalDate from, LocalDate to}) timelineWindow(LocalDate anchor, int index) {
  final from = anchor.addDays(index * timelineWindowDays);
  return (from: from, to: from.addDays(timelineWindowDays - 1));
}

/// One row of a day.
sealed class TimelineEntry {
  const TimelineEntry();
  LocalDate get date;
  SchedulePointInput? get start;

  /// `task:<id>@<date>` or `event:<id>@<date>` (as in [ConflictView]).
  String get key;
  String get title;
}

class TaskEntry extends TimelineEntry {
  const TaskEntry(this.item);
  final AgendaItem item;
  @override
  LocalDate get date => item.date;
  @override
  SchedulePointInput? get start => item.start ?? item.end ?? item.deadline;
  @override
  String get key => taskOccurrenceKey(item.taskId, item.originalDate);
  @override
  String get title => item.title;
}

class EventEntry extends TimelineEntry {
  const EventEntry(this.item);
  final EventItem item;
  @override
  LocalDate get date => item.date;
  @override
  SchedulePointInput? get start => item.start;
  @override
  String get key => eventOccurrenceKey(item.eventId, item.originalDate);
  @override
  String get title => item.title;
}

/// All-day (no time) first, then by time, then by title.
int compareEntries(TimelineEntry a, TimelineEntry b) {
  final ta = a.start?.time, tb = b.start?.time;
  if ((ta == null) != (tb == null)) return ta == null ? -1 : 1;
  if (ta != null && tb != null) {
    final c = ta.compareTo(tb);
    if (c != 0) return c;
  }
  return a.title.compareTo(b.title);
}

class TimelineData {
  const TimelineData({
    required this.days,
    required this.overdue,
    required this.conflicts,
    required this.truncated,
    required this.from,
    required this.to,
  });

  /// Entries by day, each day sorted ([compareEntries]).
  final Map<LocalDate, List<TimelineEntry>> days;

  /// Overdue one-off tasks (shown at the top of today).
  final List<AgendaItem> overdue;

  /// For each entry key, the titles it overlaps (D7: shown, not resolved).
  final Map<String, List<String>> conflicts;
  final bool truncated;

  /// The loaded range.
  final LocalDate from;
  final LocalDate to;

  /// The days to show: those with entries, plus [anchor] and, when loaded,
  /// [today] (so the user always sees where they are), in order.
  List<LocalDate> visibleDays(LocalDate anchor, LocalDate today) {
    final out = {...days.keys, anchor};
    if (!today.isBefore(from) && !today.isAfter(to)) out.add(today);
    return out.toList()..sort();
  }
}

/// Merges the loaded windows and today's agenda. Each window keeps only the
/// items that start inside it, so overlapping answers never double an item;
/// today's agenda adds its overdue tasks and any of today's occurrences the
/// windows do not have (deduplicated by occurrence).
TimelineData buildTimeline({
  required List<(({LocalDate from, LocalDate to}), CalendarRange?)> windows,
  required Agenda? todayAgenda,
  required LocalDate today,
}) {
  final days = <LocalDate, List<TimelineEntry>>{};
  final seen = <String>{};
  final titles = <String, String>{};
  final pairs = <ConflictView>{};
  var truncated = todayAgenda?.truncated ?? false;
  LocalDate? from, to;

  void add(TimelineEntry e) {
    if (!seen.add(e.key)) return;
    days.putIfAbsent(e.date, () => []).add(e);
    titles[e.key] = e.title;
  }

  for (final (w, range) in windows) {
    if (from == null || w.from.isBefore(from)) from = w.from;
    if (to == null || w.to.isAfter(to)) to = w.to;
    if (range == null) continue;
    truncated = truncated || range.truncated;
    bool inside(LocalDate d) => !d.isBefore(w.from) && !d.isAfter(w.to);
    for (final e in range.events) {
      if (inside(e.date)) add(EventEntry(e));
    }
    for (final t in range.tasks) {
      if (inside(t.date)) add(TaskEntry(t));
    }
    pairs.addAll(range.conflicts);
  }
  final overdue = <AgendaItem>[];
  for (final i in todayAgenda?.items ?? const <AgendaItem>[]) {
    if (i.isOverdue) {
      overdue.add(i);
    } else {
      add(TaskEntry(i));
    }
  }
  for (final list in days.values) {
    list.sort(compareEntries);
  }
  final conflicts = <String, List<String>>{};
  for (final c in pairs) {
    final a = titles[c.first], b = titles[c.second];
    if (a == null || b == null) continue;
    conflicts.putIfAbsent(c.first, () => []).add(b);
    conflicts.putIfAbsent(c.second, () => []).add(a);
  }
  return TimelineData(
    days: days,
    overdue: overdue,
    conflicts: conflicts,
    truncated: truncated,
    from: from ?? today,
    to: to ?? today,
  );
}
