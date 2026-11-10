// P02 T6b: what the calendar views show where. Plain functions over the
// calendar range (no widgets), so they are easy to test.
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

import 'schedule_text.dart';

enum CalendarMode { day, week, month }

/// The first day of the week containing [d], with weeks starting on [first]
/// (owner decision D3).
LocalDate weekStartOf(LocalDate d, Weekday first) => d.addDays(-((d.weekday.index - first.index + 7) % 7));

/// The dates a view shows: one day, one week, or the six weeks of a month
/// grid (always 42 days, so the grid never changes height).
({LocalDate from, LocalDate to}) rangeOf(CalendarMode mode, LocalDate anchor, Weekday first) {
  switch (mode) {
    case CalendarMode.day:
      return (from: anchor, to: anchor);
    case CalendarMode.week:
      final s = weekStartOf(anchor, first);
      return (from: s, to: s.addDays(6));
    case CalendarMode.month:
      final s = weekStartOf(LocalDate(anchor.year, anchor.month, 1), first);
      return (from: s, to: s.addDays(41));
  }
}

/// The anchor one period earlier ([by] = -1) or later (+1).
LocalDate stepAnchor(CalendarMode mode, LocalDate anchor, int by) => switch (mode) {
      CalendarMode.day => anchor.addDays(by),
      CalendarMode.week => anchor.addDays(7 * by),
      CalendarMode.month => LocalDate(anchor.year, anchor.month, 1).addMonthsClamped(by),
    };

const _monthLong = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November',
  'December'
];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Tue 10 Nov 2026", "9 – 15 Nov 2026", "30 Nov – 6 Dec 2026", "November 2026".
String periodTitle(CalendarMode mode, LocalDate anchor, Weekday first) {
  switch (mode) {
    case CalendarMode.day:
      return '${weekdayShort(anchor.weekday)} ${anchor.day} ${_monthShort[anchor.month - 1]} ${anchor.year}';
    case CalendarMode.week:
      final r = rangeOf(mode, anchor, first);
      final a = r.from, b = r.to;
      if (a.year != b.year) {
        return '${a.day} ${_monthShort[a.month - 1]} ${a.year} – ${b.day} ${_monthShort[b.month - 1]} ${b.year}';
      }
      if (a.month != b.month) {
        return '${a.day} ${_monthShort[a.month - 1]} – ${b.day} ${_monthShort[b.month - 1]} ${b.year}';
      }
      return '${a.day} – ${b.day} ${_monthShort[b.month - 1]} ${b.year}';
    case CalendarMode.month:
      return '${_monthLong[anchor.month - 1]} ${anchor.year}';
  }
}

/// One thing on a calendar day: an event occurrence or a task occurrence
/// (D6: a task stays a task, shown with its own row and actions).
class CalendarEntry {
  CalendarEntry.event(EventItem this.event)
      : task = null,
        key = eventOccurrenceKey(event.eventId, event.originalDate),
        title = event.title,
        start = event.start,
        end = event.end;

  CalendarEntry.task(AgendaItem this.task)
      : event = null,
        key = taskOccurrenceKey(task.taskId, task.originalDate),
        title = task.title,
        start = task.start ?? task.end ?? task.deadline!,
        end = task.start == null ? null : task.end;

  final EventItem? event;
  final AgendaItem? task;

  /// The same key as in [ConflictView].
  final String key;
  final String title;
  final SchedulePointInput start;
  final SchedulePointInput? end;

  bool get isAllDay => !start.isTimed;
  bool get isCancelled => event?.isCancelled ?? false;

  /// The last day it is on: an end at midnight belongs to the day before.
  LocalDate get lastDay {
    final e = end;
    if (e == null || !e.date.isAfter(start.date)) return start.date;
    if (e.isTimed && e.time!.minuteOfDay == 0) return e.date.addDays(-1);
    return e.date;
  }
}

/// Entries per day of [from]..[to]; an item spanning days is on each of
/// them. Per day: all-day first, then by start time, then title.
Map<LocalDate, List<CalendarEntry>> entriesByDay(CalendarRange range, LocalDate from, LocalDate to) {
  final out = <LocalDate, List<CalendarEntry>>{};
  void add(CalendarEntry e) {
    var d = e.start.date.isBefore(from) ? from : e.start.date;
    final last = e.lastDay.isAfter(to) ? to : e.lastDay;
    for (; !d.isAfter(last); d = d.addDays(1)) {
      out.putIfAbsent(d, () => []).add(e);
    }
  }

  for (final e in range.events) {
    add(CalendarEntry.event(e));
  }
  for (final t in range.tasks) {
    if (t.start == null && t.end == null && t.deadline == null) continue;
    add(CalendarEntry.task(t));
  }
  for (final list in out.values) {
    list.sort((a, b) {
      if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
      final m = (a.start.time?.minuteOfDay ?? -1).compareTo(b.start.time?.minuteOfDay ?? -1);
      if (m != 0) return m;
      final t = a.title.compareTo(b.title);
      return t != 0 ? t : a.key.compareTo(b.key);
    });
  }
  return out;
}

/// For each entry key, the titles of the entries it overlaps (D7).
Map<String, List<String>> conflictTitles(CalendarRange range) {
  final titles = <String, String>{
    for (final e in range.events) eventOccurrenceKey(e.eventId, e.originalDate): e.title,
    for (final t in range.tasks) taskOccurrenceKey(t.taskId, t.originalDate): t.title,
  };
  final out = <String, List<String>>{};
  for (final c in range.conflicts) {
    out.putIfAbsent(c.first, () => []).add(titles[c.second] ?? '?');
    out.putIfAbsent(c.second, () => []).add(titles[c.first] ?? '?');
  }
  return out;
}

/// "09:00–10:30", "All day", "From 22:00" (spans days), with a foreign zone.
String entryTime(CalendarEntry e, {required String deviceZone}) {
  final s = e.start, end = e.end;
  if (!s.isTimed) return 'All day';
  final from = formatTimeOnly(s, deviceZone: deviceZone);
  if (end == null || !end.isTimed) return from;
  if (end.date == s.date && end.zone == s.zone) return '$from–${end.time}';
  return 'From $from';
}
