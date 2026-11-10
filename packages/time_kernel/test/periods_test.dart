// P03 T1 (owner decision D6, ADR-0036): the period of a rule that contains a
// date. Habit and measurable-target results are evaluated per period.
import 'dart:math';

import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);
ScheduleSpec onDate(LocalDate x) => ScheduleSpec(start: DatePoint(x));
(LocalDate, LocalDate)? p(RecurrenceRule r, LocalDate start, LocalDate x) {
  final w = rulePeriodOf(r, onDate(start), x);
  return w == null ? null : (w.from, w.to);
}

void main() {
  test('daily: each day; every 3 days: 3-day cycles from the start', () {
    const daily = RecurrenceRule(frequency: Frequency.daily);
    expect(p(daily, d(2026, 11, 9), d(2026, 11, 12)), (d(2026, 11, 12), d(2026, 11, 12)));
    const every3 = RecurrenceRule(frequency: Frequency.daily, interval: 3);
    expect(p(every3, d(2026, 11, 9), d(2026, 11, 9)), (d(2026, 11, 9), d(2026, 11, 11)));
    expect(p(every3, d(2026, 11, 9), d(2026, 11, 13)), (d(2026, 11, 12), d(2026, 11, 14)));
  });

  test('weekly: the week by the series\' week start (D3), several weekdays share it', () {
    const monWedFri = RecurrenceRule(
        frequency: Frequency.weekly, byWeekday: {Weekday.monday, Weekday.wednesday, Weekday.friday});
    // Mon 9 Nov 2026 .. Sun 15 Nov.
    expect(p(monWedFri, d(2026, 11, 9), d(2026, 11, 13)), (d(2026, 11, 9), d(2026, 11, 15)));
    final w = rulePeriodOf(monWedFri, onDate(d(2026, 11, 9)), d(2026, 11, 11))!;
    expect(ruleDatesIn(monWedFri, onDate(d(2026, 11, 9)), w), [d(2026, 11, 9), d(2026, 11, 11), d(2026, 11, 13)]);
    const sundayWeeks = RecurrenceRule(frequency: Frequency.weekly, weekStart: Weekday.sunday);
    expect(p(sundayWeeks, d(2026, 11, 11), d(2026, 11, 14)), (d(2026, 11, 8), d(2026, 11, 14)));
    const every2 = RecurrenceRule(frequency: Frequency.weekly, interval: 2);
    expect(p(every2, d(2026, 11, 9), d(2026, 11, 20)), (d(2026, 11, 9), d(2026, 11, 22)));
  });

  test('monthly and yearly: from the start\'s day to the day before it later; clamped at month ends', () {
    const monthly = RecurrenceRule(frequency: Frequency.monthly);
    expect(p(monthly, d(2026, 1, 15), d(2026, 2, 20)), (d(2026, 2, 15), d(2026, 3, 14)));
    expect(p(monthly, d(2026, 1, 31), d(2026, 2, 28)), (d(2026, 2, 28), d(2026, 3, 30)));
    const yearly = RecurrenceRule(frequency: Frequency.yearly);
    expect(p(yearly, d(2024, 2, 29), d(2025, 6, 1)), (d(2025, 2, 28), d(2026, 2, 27)));
  });

  test('before the first period: none; after the series ended: periods still exist, without dates', () {
    const daily = RecurrenceRule(frequency: Frequency.daily, end: EndsAfterCount(3));
    expect(p(daily, d(2026, 11, 9), d(2026, 11, 8)), isNull);
    final after = rulePeriodOf(daily, onDate(d(2026, 11, 9)), d(2026, 11, 20))!;
    expect(ruleDatesIn(daily, onDate(d(2026, 11, 9)), after), isEmpty);
  });

  test('property: periods tile the calendar and each rule date is in its own period', () {
    final rnd = Random(36);
    for (var i = 0; i < 300; i++) {
      final f = Frequency.values[rnd.nextInt(4)];
      final r = RecurrenceRule(
        frequency: f,
        interval: 1 + rnd.nextInt(3),
        byWeekday: f == Frequency.weekly && rnd.nextBool()
            ? {Weekday.values[rnd.nextInt(7)], Weekday.values[rnd.nextInt(7)]}
            : null,
        weekStart: rnd.nextBool() ? Weekday.monday : Weekday.sunday,
        monthEndRule: rnd.nextBool() ? MonthEndRule.skip : MonthEndRule.lastDay,
      );
      final start = d(2026, 1, 1).addDays(rnd.nextInt(400));
      final spec = onDate(start);
      var w = rulePeriodOf(r, spec, start.addDays(rnd.nextInt(30)))!;
      for (var j = 0; j < 12; j++) {
        // Each day of the period maps back to the same period.
        for (var x = w.from; !x.isAfter(w.to); x = x.addDays(1)) {
          final again = rulePeriodOf(r, spec, x)!;
          expect((again.from, again.to), (w.from, w.to), reason: '$r $start $x');
        }
        for (final rd in ruleDatesIn(r, spec, w)) {
          expect(!rd.isBefore(w.from) && !rd.isAfter(w.to), isTrue);
        }
        final next = rulePeriodOf(r, spec, w.to.addDays(1))!;
        expect(next.from, w.to.addDays(1), reason: 'no gap after ${w.to} for $r');
        w = next;
      }
    }
  });
}
