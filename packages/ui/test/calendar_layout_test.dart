import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/src/calendar_layout.dart';

LocalDate d(int m, int day, [int y = 2026]) => LocalDate(y, m, day);
const z = 'Asia/Ho_Chi_Minh';

EventItem ev(String id, LocalDate date, {TimeOfDayValue? at, SchedulePointInput? end, String? title}) => EventItem(
      eventId: id,
      title: title ?? id,
      originalDate: date,
      start: at == null ? SchedulePointInput.date(date) : SchedulePointInput.at(date, at, z),
      end: end,
      isRepeating: false,
    );

void main() {
  test('week start follows the setting (D3)', () {
    expect(weekStartOf(d(11, 11), Weekday.monday), d(11, 9));
    expect(weekStartOf(d(11, 11), Weekday.sunday), d(11, 8));
    expect(weekStartOf(d(11, 8), Weekday.monday), d(11, 2)); // a Sunday
    expect(weekStartOf(d(11, 8), Weekday.sunday), d(11, 8));
  });

  test('ranges: a day, a week, six weeks for a month', () {
    expect(rangeOf(CalendarMode.day, d(11, 10), Weekday.monday), (from: d(11, 10), to: d(11, 10)));
    expect(rangeOf(CalendarMode.week, d(11, 10), Weekday.monday), (from: d(11, 9), to: d(11, 15)));
    // 1 Nov 2026 is a Sunday.
    expect(rangeOf(CalendarMode.month, d(11, 20), Weekday.monday), (from: d(10, 26), to: d(12, 6)));
    expect(rangeOf(CalendarMode.month, d(11, 20), Weekday.sunday), (from: d(11, 1), to: d(12, 12)));
  });

  test('stepping; a month step never lands on a missing day', () {
    expect(stepAnchor(CalendarMode.day, d(11, 30), 1), d(12, 1));
    expect(stepAnchor(CalendarMode.week, d(11, 10), -1), d(11, 3));
    expect(stepAnchor(CalendarMode.month, d(1, 31), 1), d(2, 1));
    expect(stepAnchor(CalendarMode.month, d(1, 15), -1), d(12, 1, 2025));
  });

  test('period titles', () {
    expect(periodTitle(CalendarMode.day, d(11, 10), Weekday.monday), 'Tue 10 Nov 2026');
    expect(periodTitle(CalendarMode.week, d(11, 10), Weekday.monday), '9 – 15 Nov 2026');
    expect(periodTitle(CalendarMode.week, d(12, 1), Weekday.monday), '30 Nov – 6 Dec 2026');
    expect(periodTitle(CalendarMode.week, d(12, 30), Weekday.monday), '28 Dec 2026 – 3 Jan 2027');
    expect(periodTitle(CalendarMode.month, d(11, 10), Weekday.monday), 'November 2026');
  });

  test('items on each day they cover; midnight belongs to the day before; clipped to the range', () {
    final range = CalendarRange(
      events: [
        ev('trip', d(11, 9), end: SchedulePointInput.date(d(11, 11))),
        ev('late', d(11, 9), at: TimeOfDayValue(22, 0), end: SchedulePointInput.at(d(11, 10), TimeOfDayValue(0, 0), z)),
        ev('night', d(11, 9), at: TimeOfDayValue(23, 0), end: SchedulePointInput.at(d(11, 10), TimeOfDayValue(1, 0), z)),
        ev('long', d(11, 1), end: SchedulePointInput.date(d(11, 30))),
      ],
      tasks: const [],
      conflicts: const [],
    );
    final by = entriesByDay(range, d(11, 9), d(11, 12));
    List<String> on(int day) => [for (final e in by[d(11, day)] ?? const <CalendarEntry>[]) e.title];
    // All-day first (by title), then by time.
    expect(on(9), ['long', 'trip', 'late', 'night']);
    expect(on(10), ['long', 'trip', 'night']);
    expect(on(11), ['long', 'trip']);
    expect(on(12), ['long']);
    expect(by.keys, everyElement(predicate<LocalDate>((x) => !x.isBefore(d(11, 9)) && !x.isAfter(d(11, 12)))));
  });

  test('tasks are entries too (D6), placed by start, else end, else deadline', () {
    final range = CalendarRange(
      events: const [],
      tasks: [
        AgendaItem(
            taskId: 't', title: 'Report', originalDate: d(11, 12),
            deadline: SchedulePointInput.date(d(11, 12)), isRepeating: false, isDone: false),
      ],
      conflicts: const [],
    );
    final e = entriesByDay(range, d(11, 9), d(11, 15))[d(11, 12)]!.single;
    expect(e.task, isNotNull);
    expect(e.key, 'task:t@2026-11-12');
  });

  test('conflict titles go both ways (D7)', () {
    final range = CalendarRange(
      events: [ev('a', d(11, 9), at: TimeOfDayValue(9, 0), title: 'Standup')],
      tasks: [
        AgendaItem(
            taskId: 't', title: 'Gym', originalDate: d(11, 9),
            start: SchedulePointInput.at(d(11, 9), TimeOfDayValue(9, 0), z), isRepeating: false, isDone: false),
      ],
      conflicts: [ConflictView(eventOccurrenceKey('a', d(11, 9)), taskOccurrenceKey('t', d(11, 9)))],
    );
    final c = conflictTitles(range);
    expect(c['event:a@2026-11-09'], ['Gym']);
    expect(c['task:t@2026-11-09'], ['Standup']);
  });

  test('entry times', () {
    String t(EventItem e) => entryTime(CalendarEntry.event(e), deviceZone: z);
    expect(t(ev('x', d(11, 9))), 'All day');
    expect(t(ev('x', d(11, 9), at: TimeOfDayValue(9, 0))), '09:00');
    expect(t(ev('x', d(11, 9), at: TimeOfDayValue(9, 0), end: SchedulePointInput.at(d(11, 9), TimeOfDayValue(10, 30), z))),
        '09:00–10:30');
    expect(t(ev('x', d(11, 9), at: TimeOfDayValue(22, 0), end: SchedulePointInput.at(d(11, 10), TimeOfDayValue(2, 0), z))),
        'From 22:00');
  });
}
