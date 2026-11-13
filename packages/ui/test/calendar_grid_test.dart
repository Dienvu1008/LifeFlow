// P03 UX U5 (ADR-0049): the time grid as pure functions: folded night
// hours (U-D5), taps to slots, items on days (midnight, DST), side by side.
import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/src/calendar_grid.dart';

final day = LocalDate(2026, 11, 12);
SchedulePointInput at(LocalDate d, int h, [int m = 0]) => SchedulePointInput.at(d, TimeOfDayValue(h, m), 'UTC');

void main() {
  group('hidden night hours', () {
    test('a range, a range over midnight, none', () {
      expect(hiddenSegments(0, 360), [(0, 360)]);
      expect(hiddenSegments(23 * 60, 7 * 60), [(0, 420), (1380, 1440)]);
      expect(hiddenSegments(22 * 60, 0), [(1320, 1440)]);
      expect(hiddenSegments(300, 300), isEmpty);
    });

    test('folded hours take a thin band; the rest is the hour height', () {
      final s = GridScale(hourHeight: 60, hidden: hiddenSegments(0, 360), foldedHeight: 30);
      expect(s.yOf(0), 0);
      expect(s.yOf(360), 30); // 00:00-06:00 in one 30 px band
      expect(s.yOf(420), 90); // then 60 px per hour
      expect(s.height, 30 + 18 * 60);
      final open = GridScale(hourHeight: 60);
      expect((open.yOf(360), open.height), (360, 1440));
    });

    test('positions grow with the minute, through every fold', () {
      final s = GridScale(hourHeight: 48, hidden: hiddenSegments(23 * 60, 7 * 60));
      var last = -1.0;
      for (var m = 0; m <= minutesPerDay; m += 5) {
        final y = s.yOf(m);
        expect(y, greaterThanOrEqualTo(last), reason: '$m');
        last = y;
      }
    });

    test('a tap means its slot; in a fold, the first hour after it', () {
      final s = GridScale(hourHeight: 60, hidden: hiddenSegments(0, 360), foldedHeight: 30);
      expect(s.minuteAt(10), 360);
      expect(s.minuteAt(30 + 60 * 3 + 50), 9 * 60 + 45); // 09:50 -> 09:45
      expect(s.minuteAt(1e6), minutesPerDay - slotMinutes);
      expect(s.foldAt(10), (0, 360));
      expect(s.foldAt(40), isNull);
      final open = GridScale(hourHeight: 60);
      for (final m in [0, 15, 600, 1425]) {
        expect(open.minuteAt(open.yOf(m)), m);
      }
      // A fold at the end of the day: its tap is the last slot.
      final late = GridScale(hourHeight: 60, hidden: hiddenSegments(22 * 60, 0));
      expect(late.minuteAt(late.yOf(23 * 60)), minutesPerDay - slotMinutes);
    });
  });

  group('an item on a day', () {
    test('within the day; without an end it draws 30 minutes', () {
      expect(daySpan('a', at(day, 9), at(day, 10, 30), day), const DaySpan('a', 540, 630));
      expect(daySpan('a', at(day, 9), null, day), const DaySpan('a', 540, 570));
      expect(daySpan('a', at(day, 9), at(day, 9, 10), day), const DaySpan('a', 540, 570));
      expect(daySpan('a', SchedulePointInput.date(day), null, day), isNull);
      expect(daySpan('a', at(day, 9), null, day.addDays(1)), isNull);
    });

    test('over midnight it is on both days; an end at 00:00 is not on the next', () {
      final next = day.addDays(1);
      expect(daySpan('a', at(day, 22), at(next, 2), day), const DaySpan('a', 1320, 1440));
      expect(daySpan('a', at(day, 22), at(next, 2), next), const DaySpan('a', 0, 120));
      expect(daySpan('a', at(day, 22), at(next, 0), next), isNull);
      expect(daySpan('a', at(day, 22), at(next, 0), day), const DaySpan('a', 1320, 1440));
      // Three days: the middle one is whole.
      expect(daySpan('a', at(day, 22), at(day.addDays(2), 1), next), const DaySpan('a', 0, 1440));
    });

    test('DST: 23 h and 25 h days are drawn as 24 wall-clock hours; an end that reads earlier still draws', () {
      // Device times come resolved from the kernel (device_time_test). On the
      // 25 h day an item 02:45 CEST -> 02:15 CET (30 real minutes) reads
      // backwards on the wall clock: it is drawn from its start.
      final fallBack = LocalDate(2026, 10, 25);
      expect(daySpan('a', at(fallBack, 2, 45), at(fallBack, 2, 15), fallBack), const DaySpan('a', 165, 195));
      // On the 23 h day 01:30 -> 03:30 (one real hour) spans two wall hours.
      final spring = LocalDate(2026, 3, 29);
      expect(daySpan('a', at(spring, 1, 30), at(spring, 3, 30), spring), const DaySpan('a', 90, 210));
      // Late in the day the drawn minimum stays inside the day.
      expect(daySpan('a', at(day, 23, 50), null, day), const DaySpan('a', 1410, 1440));
    });
  });

  group('side by side', () {
    String layout(List<DaySpan> s) => placeSpans(s).map((p) => p.toString()).join(' ');

    test('apart: full width; overlapping: shared; a chain shares one group', () {
      expect(layout([const DaySpan('a', 0, 60), const DaySpan('b', 60, 120)]), 'a:0/1 b:0/1');
      expect(layout([const DaySpan('a', 0, 60), const DaySpan('b', 30, 90)]), 'a:0/2 b:1/2');
      // a overlaps b, b overlaps c, a and c do not: c reuses a's column.
      expect(layout([const DaySpan('a', 0, 60), const DaySpan('b', 30, 120), const DaySpan('c', 90, 150)]),
          'a:0/2 b:1/2 c:0/2');
      // Three at once.
      expect(layout([const DaySpan('a', 0, 60), const DaySpan('b', 0, 60), const DaySpan('c', 10, 20)]),
          'a:0/3 b:1/3 c:2/3');
      // An item that starts when another ends reuses its column.
      expect(layout([const DaySpan('a', 0, 60), const DaySpan('b', 30, 90), const DaySpan('c', 60, 120)]),
          'a:0/2 b:1/2 c:0/2');
      // After a gap a new group starts with one column.
      expect(layout([const DaySpan('a', 0, 60), const DaySpan('b', 30, 90), const DaySpan('z', 200, 260)]),
          'a:0/2 b:1/2 z:0/1');
    });

    test('the order of the input does not change the layout', () {
      final s = [const DaySpan('a', 0, 60), const DaySpan('b', 30, 120), const DaySpan('c', 90, 150)];
      expect(layout(s.reversed.toList()), layout(s));
    });
  });

  test('the year view: a month as 6 weeks from the week start', () {
    final nov = yearMonthGrid(2026, 11, Weekday.monday);
    expect(nov, hasLength(6));
    expect(nov.first.take(7).toList(), [null, null, null, null, null, null, LocalDate(2026, 11, 1)]);
    expect(nov.expand((w) => w).whereType<LocalDate>(), hasLength(30));
    final sun = yearMonthGrid(2026, 11, Weekday.sunday);
    expect(sun.first.first, LocalDate(2026, 11, 1));
  });
}
