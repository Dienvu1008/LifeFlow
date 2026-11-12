// P02 T6a: how schedules read in the UI; plain functions so they are easy
// to test. P03 UX U1 (ADR-0045): weekday and month names come from `intl`
// in the current locale (English until another language exists); the
// remaining English phrases move to the ARB file with their screens.
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:intl/intl.dart';

/// A Monday (2024-01-01) plus [d]'s index: a date with that weekday.
DateTime _dayOf(Weekday d) => DateTime(2024, 1, 1 + d.index);

String weekdayShort(Weekday d) => DateFormat.E().format(_dayOf(d));
String weekdayLong(Weekday d) => DateFormat.EEEE().format(_dayOf(d));
String monthShort(int month) => DateFormat.MMM().format(DateTime(2024, month));

/// "Today", "Tomorrow", "Yesterday", otherwise "Mon 9 Nov" (with the year
/// when it is not [today]'s year).
String formatDate(LocalDate d, {required LocalDate today}) {
  final diff = today.daysUntil(d);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return formatDateLong(d, today: today);
}

/// "Mon 9 Nov" (plus the year when it differs from [today]'s).
String formatDateLong(LocalDate d, {required LocalDate today}) {
  final base = '${weekdayShort(d.weekday)} ${d.day} ${monthShort(d.month)}';
  return d.year == today.year ? base : '$base ${d.year}';
}

/// A date, plus its time; the zone is shown only when it is not the
/// device's (D10), so a trip abroad stays visible.
String formatPoint(SchedulePointInput p, {required LocalDate today, required String deviceZone}) {
  final date = formatDate(p.date, today: today);
  if (!p.isTimed) return date;
  final zone = p.zone == deviceZone ? '' : ' (${p.zone})';
  return '$date ${p.time}$zone';
}

/// Only the time (and a foreign zone), for rows already grouped by date.
String formatTimeOnly(SchedulePointInput p, {required String deviceZone}) {
  if (!p.isTimed) return '';
  return p.zone == deviceZone ? '${p.time}' : '${p.time} (${p.zone})';
}

String describeRepeat(RepeatInput r) {
  final n = r.interval;
  final unit = switch (r.frequency) {
    RepeatFrequency.daily => n == 1 ? 'day' : '$n days',
    RepeatFrequency.weekly => n == 1 ? 'week' : '$n weeks',
    RepeatFrequency.monthly => n == 1 ? 'month' : '$n months',
    RepeatFrequency.yearly => n == 1 ? 'year' : '$n years',
  };
  final buf = StringBuffer('Every $unit');
  final days = r.weekdays;
  if (r.frequency == RepeatFrequency.weekly && days != null && days.isNotEmpty) {
    final sorted = days.toList()..sort((a, b) => a.index.compareTo(b.index));
    buf.write(' on ${sorted.map(weekdayShort).join(', ')}');
  }
  switch (r.end) {
    case RepeatForever():
      break;
    case RepeatUntil(:final date):
      buf.write(', until $date');
    case RepeatTimes(:final count):
      buf.write(count == 1 ? ', once' : ', $count times');
  }
  return buf.toString();
}

/// One line for a task row: "Start Today 09:00 · Due Fri 13 Nov · Every week".
String describeSchedule(TaskScheduleInput s, {required LocalDate today, required String deviceZone}) {
  String f(SchedulePointInput p) => formatPoint(p, today: today, deviceZone: deviceZone);
  final parts = <String>[
    if (s.start != null && s.end != null && s.start!.date == s.end!.date &&
        s.start!.isTimed && s.start!.zone == s.end!.zone)
      '${f(s.start!)}–${s.end!.time}'
    else ...[
      if (s.start != null) 'Start ${f(s.start!)}',
      if (s.end != null) 'End ${f(s.end!)}',
    ],
    if (s.deadline != null) 'Due ${f(s.deadline!)}',
    if (s.repeat != null) describeRepeat(s.repeat!),
  ];
  return parts.join(' · ');
}

// --- reminders (P02 T7) -------------------------------------------------------

String _n(int n, String unit) => n == 1 ? '1 $unit' : '$n ${unit}s';

/// "10 minutes", "1 hour 30 minutes", "1 day", "2 days 3 hours", "1 week".
String describeOffset(int minutes) {
  if (minutes > 0 && minutes % (7 * 1440) == 0) return _n(minutes ~/ (7 * 1440), 'week');
  final d = minutes ~/ 1440, h = (minutes % 1440) ~/ 60, m = minutes % 60;
  final parts = [if (d > 0) _n(d, 'day'), if (h > 0) _n(h, 'hour'), if (m > 0) _n(m, 'minute')];
  return parts.isEmpty ? '0 minutes' : parts.join(' ');
}

/// The all-day reminder time, "09:00".
String get allDayReminderTimeText {
  const m = allDayReminderMinuteOfDay;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

/// How a reminder reads in an editor. [anchor] names the point it counts
/// from ('start', 'deadline' or 'end'); [allDay] when that point is a date.
String describeReminder(ReminderInput r, {required String anchor, required bool allDay, required LocalDate today}) {
  switch (r) {
    case RemindMinutesBefore(:final minutes):
      if (allDay) {
        final t = allDayReminderTimeText;
        if (minutes == 0) return 'On the day, $t';
        return minutes % 1440 == 0 ? '${describeOffset(minutes)} before, $t' : '${describeOffset(minutes)} before $t';
      }
      if (minutes == 0) return 'At the $anchor';
      return '${describeOffset(minutes)} before';
    case RemindAtInstant(:final at):
      final l = at.utc.toLocal();
      final date = formatDate(LocalDate(l.year, l.month, l.day), today: today);
      return '$date at ${TimeOfDayValue(l.hour, l.minute)}';
  }
}
