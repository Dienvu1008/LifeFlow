// P02 T2 — recurrence and the window query.
//   GS-03 / AC-06.1/06.2   exactly N across any windows, no duplicates, no
//                          gaps, regenerating is identical
//   LF-INV-PLAN-010        bounded (window and result size) and deterministic
//   LF-INV-PLAN-011        exceptions survive rule edits that keep the date
//   LF-INV-PLAN-012        no duplicate occurrences
//   LF-INV-PLAN-013        a timed series keeps its wall clock across DST
//   D1 limits, D2 month-end rule, D3 week start (owner decisions)
import 'dart:math';

import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);
ScheduleSpec onDate(LocalDate x) => ScheduleSpec(start: DatePoint(x));
DateWindow win(LocalDate a, LocalDate b) => DateWindow(a, b);

List<LocalDate> dates(OccurrenceWindowResult r) => [for (final o in r.occurrences) o.originalDate];

OccurrenceWindowResult q(ScheduleSpec spec, RecurrenceRule? rule, DateWindow w,
        {List<OccurrenceException> ex = const [], OccurrenceLimits? limits}) =>
    occurrencesInWindow(
        seriesId: 's', spec: spec, rule: rule, exceptions: ex, window: w,
        limits: limits ?? OccurrenceLimits.standard);

/// Reference: a day-by-day check written from the definitions, independent
/// of the engine's period arithmetic.
List<LocalDate> reference(RecurrenceRule r, LocalDate anchor, LocalDate from, LocalDate to) {
  LocalDate weekOf(LocalDate x) =>
      x.addDays(-((x.weekday.isoNumber - r.weekStart.isoNumber + 7) % 7));
  bool matches(LocalDate x) {
    if (x.isBefore(anchor)) return false;
    final monthsDiff = (x.year - anchor.year) * 12 + x.month - anchor.month;
    bool dayMatches() {
      final wanted = r.monthEndRule == MonthEndRule.lastDay
          ? min(anchor.day, LocalDate.daysInMonth(x.year, x.month))
          : anchor.day;
      return x.day == wanted;
    }

    switch (r.frequency) {
      case Frequency.daily:
        return anchor.daysUntil(x) % r.interval == 0;
      case Frequency.weekly:
        final days = r.byWeekday ?? {anchor.weekday};
        final weeks = weekOf(anchor).daysUntil(weekOf(x)) ~/ 7;
        return days.contains(x.weekday) && weeks % r.interval == 0;
      case Frequency.monthly:
        return monthsDiff % r.interval == 0 && dayMatches();
      case Frequency.yearly:
        return x.month == anchor.month &&
            (x.year - anchor.year) % r.interval == 0 &&
            dayMatches();
    }
  }

  final out = <LocalDate>[];
  var produced = 0;
  for (var x = anchor; !x.isAfter(to); x = x.addDays(1)) {
    if (!matches(x)) continue;
    if (r.end case EndsOnDate(:final date) when x.isAfter(date)) break;
    if (r.end case EndsAfterCount(:final count) when produced >= count) break;
    produced++;
    if (!x.isBefore(from)) out.add(x);
  }
  return out;
}

void main() {
  group('GS-03: weekly Mon+Wed, after 10 occurrences', () {
    final start = d(2026, 11, 9); // Monday
    const rule = RecurrenceRule(
      frequency: Frequency.weekly,
      byWeekday: {Weekday.monday, Weekday.wednesday},
      end: EndsAfterCount(10),
    );
    final expected = [
      d(2026, 11, 9), d(2026, 11, 11), d(2026, 11, 16), d(2026, 11, 18),
      d(2026, 11, 23), d(2026, 11, 25), d(2026, 11, 30), d(2026, 12, 2),
      d(2026, 12, 7), d(2026, 12, 9),
    ];

    test('one big window: exactly the 10 expected dates', () {
      final r = q(onDate(start), rule, win(d(2026, 6, 1), d(2027, 6, 30)));
      expect(dates(r), expected);
      expect(r.truncated, isFalse);
    });

    test('any split into windows gives the same 10, no duplicates, no gaps '
        '(property, 500 random splits)', () {
      final rnd = Random(3);
      for (var run = 0; run < 500; run++) {
        // Random cut points between 2026-11-01 and 2027-01-31.
        final cuts = <int>{0, 91};
        while (cuts.length < 2 + rnd.nextInt(8)) {
          cuts.add(rnd.nextInt(91));
        }
        final sorted = cuts.toList()..sort();
        final all = <LocalDate>[];
        for (var i = 0; i + 1 < sorted.length; i++) {
          final a = d(2026, 11, 1).addDays(sorted[i]);
          final b = d(2026, 11, 1).addDays(sorted[i + 1] - 1);
          if (b.isBefore(a)) continue;
          all.addAll(dates(q(onDate(start), rule, win(a, b))));
        }
        expect(all, expected, reason: 'cuts $sorted');
      }
    });

    test('regenerating a window is identical (AC-06.2)', () {
      final w = win(d(2026, 11, 10), d(2026, 12, 3));
      final a = q(onDate(start), rule, w).occurrences.map((o) => '$o').toList();
      final b = q(onDate(start), rule, w).occurrences.map((o) => '$o').toList();
      expect(a, b);
      expect(a, isNotEmpty);
    });
  });

  test('engine = reference on random rules and windows (LF-INV-PLAN-010/012)',
      () {
    final rnd = Random(20261107);
    for (var run = 0; run < 1500; run++) {
      final anchor = d(2024, 1, 1).addDays(rnd.nextInt(1200));
      final freq = Frequency.values[rnd.nextInt(4)];
      final weekdays = freq == Frequency.weekly && rnd.nextBool()
          ? {for (var i = 0; i < 1 + rnd.nextInt(4); i++) Weekday.values[rnd.nextInt(7)]}
          : null;
      final end = switch (rnd.nextInt(3)) {
        0 => const EndsNever(),
        1 => EndsAfterCount(1 + rnd.nextInt(30)),
        _ => EndsOnDate(anchor.addDays(rnd.nextInt(900))),
      };
      final rule = RecurrenceRule(
        frequency: freq,
        interval: 1 + rnd.nextInt(freq == Frequency.daily ? 10 : 4),
        byWeekday: weekdays,
        end: end,
        monthEndRule: MonthEndRule.values[rnd.nextInt(2)],
        weekStart: rnd.nextBool() ? Weekday.monday : Weekday.sunday,
      );
      final from = anchor.addDays(rnd.nextInt(700) - 100);
      final to = from.addDays(rnd.nextInt(390));
      final got = dates(q(onDate(anchor), rule, win(from, to)));
      final want = reference(rule, anchor, from, to);
      expect(got, want, reason: 'run $run: $freq/${rule.interval} $weekdays $end '
          '${rule.monthEndRule} ws=${rule.weekStart} anchor $anchor window $from..$to');
      expect(got.toSet().length, got.length, reason: 'duplicates in run $run');
    }
  });

  group('month-end rule (D2)', () {
    test('monthly on the 31st: skip vs last day', () {
      final w = win(d(2026, 1, 1), d(2026, 6, 30));
      const skip = RecurrenceRule(frequency: Frequency.monthly);
      const last = RecurrenceRule(frequency: Frequency.monthly, monthEndRule: MonthEndRule.lastDay);
      expect(dates(q(onDate(d(2026, 1, 31)), skip, w)),
          [d(2026, 1, 31), d(2026, 3, 31), d(2026, 5, 31)]);
      expect(dates(q(onDate(d(2026, 1, 31)), last, w)), [
        d(2026, 1, 31), d(2026, 2, 28), d(2026, 3, 31), d(2026, 4, 30),
        d(2026, 5, 31), d(2026, 6, 30),
      ]);
    });

    test('yearly on Feb 29: skip vs last day', () {
      // Six years: queried in windows of the maximum size, as a caller would.
      List<LocalDate> years(RecurrenceRule r) => [
            for (var y = 2024; y <= 2029; y++)
              ...dates(q(onDate(d(2024, 2, 29)), r, win(d(y, 1, 1), d(y, 12, 31)))),
          ];
      const skip = RecurrenceRule(frequency: Frequency.yearly);
      const last = RecurrenceRule(frequency: Frequency.yearly, monthEndRule: MonthEndRule.lastDay);
      expect(years(skip), [d(2024, 2, 29), d(2028, 2, 29)]);
      expect(years(last), [
        d(2024, 2, 29), d(2025, 2, 28), d(2026, 2, 28), d(2027, 2, 28),
        d(2028, 2, 29), d(2029, 2, 28),
      ]);
    });

    test('"after N" counts only real dates under "skip"', () {
      const rule = RecurrenceRule(frequency: Frequency.monthly, end: EndsAfterCount(3));
      expect(dates(q(onDate(d(2026, 1, 31)), rule, win(d(2026, 1, 1), d(2026, 12, 31)))),
          [d(2026, 1, 31), d(2026, 3, 31), d(2026, 5, 31)]);
    });
  });

  test('week start changes which weeks "every 2 weeks" uses (D3)', () {
    final start = d(2026, 11, 8); // Sunday
    final w = win(d(2026, 11, 1), d(2026, 11, 30));
    RecurrenceRule every2(Weekday ws) => RecurrenceRule(
        frequency: Frequency.weekly, interval: 2,
        byWeekday: const {Weekday.sunday, Weekday.monday}, weekStart: ws);
    expect(dates(q(onDate(start), every2(Weekday.monday), w)),
        [d(2026, 11, 8), d(2026, 11, 16), d(2026, 11, 22), d(2026, 11, 30)]);
    expect(dates(q(onDate(start), every2(Weekday.sunday), w)),
        [d(2026, 11, 8), d(2026, 11, 9), d(2026, 11, 22), d(2026, 11, 23)]);
  });

  group('exceptions (FR-PLAN-08)', () {
    final start = d(2026, 11, 9);
    const weekly = RecurrenceRule(frequency: Frequency.weekly);
    final w = win(d(2026, 11, 1), d(2026, 12, 31));

    test('skip hides one; cancel shows it as cancelled; edit carries a patch', () {
      final r = q(onDate(start), weekly, w, ex: [
        OccurrenceException(d(2026, 11, 16), const SkipOccurrence()),
        OccurrenceException(d(2026, 11, 23), const CancelOccurrence()),
        OccurrenceException(d(2026, 11, 30), const EditOccurrence({'title': 'Longer'})),
      ]);
      expect(dates(r), isNot(contains(d(2026, 11, 16))));
      final cancelled = r.occurrences.firstWhere((o) => o.originalDate == d(2026, 11, 23));
      expect(cancelled.isCancelled, isTrue);
      final edited = r.occurrences.firstWhere((o) => o.originalDate == d(2026, 11, 30));
      expect(edited.patch, {'title': 'Longer'});
      expect(edited.isException, isTrue);
    });

    test('a skip does not change "after N": later dates stay put', () {
      const rule = RecurrenceRule(frequency: Frequency.weekly, end: EndsAfterCount(5));
      final plain = dates(q(onDate(start), rule, w));
      final skipped = dates(q(onDate(start), rule, w,
          ex: [OccurrenceException(d(2026, 11, 16), const SkipOccurrence())]));
      expect(plain.length, 5);
      expect(skipped, plain.where((x) => x != d(2026, 11, 16)).toList());
      expect(skipped.last, plain.last);
    });

    test('a move goes to its new date, into and out of the window', () {
      final ex = [OccurrenceException(d(2026, 11, 16), MoveOccurrence(d(2026, 12, 20)))];
      // Window of the original date: it is gone from there.
      expect(dates(q(onDate(start), weekly, win(d(2026, 11, 15), d(2026, 11, 17)), ex: ex)), isEmpty);
      // Window of the target date: it is there, still identified by its original date.
      final there = q(onDate(start), weekly, win(d(2026, 12, 20), d(2026, 12, 20)), ex: ex);
      expect(there.occurrences.single.originalDate, d(2026, 11, 16));
      expect(there.occurrences.single.firstDate, d(2026, 12, 20));
      // A window with both its original and its target: exactly once.
      final both = q(onDate(start), weekly, w, ex: ex);
      expect(both.occurrences.where((o) => o.originalDate == d(2026, 11, 16)), hasLength(1));
    });

    test('a timed move to another time keeps the planned length', () {
      final spec = ScheduleSpec(
        start: TimedPoint(ZonedWallClock(start, TimeOfDayValue(9, 0), 'Europe/Berlin')),
        end: TimedPoint(ZonedWallClock(start, TimeOfDayValue(10, 30), 'Europe/Berlin')),
      );
      final r = q(spec, weekly, w, ex: [
        OccurrenceException(d(2026, 11, 16), MoveOccurrence(d(2026, 11, 17), toTime: TimeOfDayValue(14, 0))),
      ]);
      final moved = r.occurrences.firstWhere((o) => o.originalDate == d(2026, 11, 16));
      expect((moved.schedule.start! as TimedPoint).wallClock,
          ZonedWallClock(d(2026, 11, 17), TimeOfDayValue(14, 0), 'Europe/Berlin'));
      expect((moved.schedule.end! as TimedPoint).wallClock.time, TimeOfDayValue(15, 30));
      expect(moved.schedule.duration, const Duration(minutes: 90));
    });

    test('LF-INV-PLAN-011: exceptions survive a rule edit that keeps their date', () {
      final ex = [
        OccurrenceException(d(2026, 11, 16), const SkipOccurrence()),
        OccurrenceException(d(2026, 11, 23), const EditOccurrence({'title': 'x'})),
      ];
      // Edit the rule: add Wednesdays and end after 12. Mondays stay rule dates.
      const edited = RecurrenceRule(
          frequency: Frequency.weekly,
          byWeekday: {Weekday.monday, Weekday.wednesday},
          end: EndsAfterCount(12));
      final r = q(onDate(start), edited, w, ex: ex);
      expect(dates(r), isNot(contains(d(2026, 11, 16))));
      expect(r.occurrences.firstWhere((o) => o.originalDate == d(2026, 11, 23)).patch, {'title': 'x'});
      // A rule that no longer has that date ignores the exception (no ghost).
      const fridays = RecurrenceRule(frequency: Frequency.weekly, byWeekday: {Weekday.friday});
      final f = q(onDate(start), fridays, w, ex: [
        OccurrenceException(d(2026, 11, 16), MoveOccurrence(d(2026, 11, 18))),
      ]);
      expect(f.occurrences.every((o) => !o.isException), isTrue);
    });

    test('for one date the last exception wins', () {
      final r = q(onDate(start), weekly, w, ex: [
        OccurrenceException(d(2026, 11, 16), const SkipOccurrence()),
        OccurrenceException(d(2026, 11, 16), const CancelOccurrence()),
      ]);
      expect(r.occurrences.firstWhere((o) => o.originalDate == d(2026, 11, 16)).isCancelled, isTrue);
    });
  });

  group('bounds (LF-INV-PLAN-010, D1)', () {
    const daily = RecurrenceRule(frequency: Frequency.daily);

    test('a window longer than the limit is cut and says so', () {
      final r = q(onDate(d(2026, 1, 1)), daily, win(d(2026, 1, 1), d(2027, 12, 31)));
      expect(r.truncated, isTrue);
      expect(r.coveredTo, d(2026, 1, 1).addDays(399));
      expect(r.occurrences, hasLength(400));
    });

    test('more occurrences than the limit are cut, in order, and say so', () {
      final spec = ScheduleSpec(
        start: TimedPoint(ZonedWallClock(d(2026, 1, 1), TimeOfDayValue(9, 0), 'UTC')),
      );
      const hourlyish = RecurrenceRule(frequency: Frequency.daily);
      final r = q(spec, hourlyish, win(d(2026, 1, 1), d(2026, 12, 31)),
          limits: OccurrenceLimits(maxOccurrences: 100, maxWindowDays: 400));
      expect(r.truncated, isTrue);
      expect(r.occurrences, hasLength(100));
      expect(r.occurrences.last.originalDate, d(2026, 1, 1).addDays(99));
    });

    test('settings outside the hard bounds are clamped', () {
      final low = OccurrenceLimits(maxOccurrences: 1, maxWindowDays: 1);
      expect((low.maxOccurrences, low.maxWindowDays), (100, 31));
      final high = OccurrenceLimits(maxOccurrences: 1 << 30, maxWindowDays: 1 << 30);
      expect((high.maxOccurrences, high.maxWindowDays), (5000, 1100));
    });

    test('an old daily series queried far in the future stays fast and exact',
        () {
      final r = q(onDate(d(1990, 1, 1)), const RecurrenceRule(frequency: Frequency.daily, interval: 3),
          win(d(2026, 11, 1), d(2026, 11, 10)));
      expect(dates(r), reference(const RecurrenceRule(frequency: Frequency.daily, interval: 3),
          d(1990, 1, 1), d(2026, 11, 1), d(2026, 11, 10)));
    });
  });

  test('LF-INV-PLAN-013: a daily 09:00 series keeps 09:00 across DST', () {
    final spec = ScheduleSpec(
      start: TimedPoint(ZonedWallClock(d(2026, 3, 27), TimeOfDayValue(9, 0), 'Europe/Berlin')),
      end: TimedPoint(ZonedWallClock(d(2026, 3, 27), TimeOfDayValue(9, 30), 'Europe/Berlin')),
    );
    final r = q(spec, const RecurrenceRule(frequency: Frequency.daily), win(d(2026, 3, 27), d(2026, 3, 31)));
    final utcHours = [for (final o in r.occurrences) instantOf(o.schedule.start! as TimedPoint).utc.hour];
    expect(utcHours, [8, 8, 7, 7, 7]);
    for (final o in r.occurrences) {
      expect((o.schedule.start! as TimedPoint).wallClock.time, TimeOfDayValue(9, 0));
      expect(o.schedule.duration, const Duration(minutes: 30));
    }
  });

  test('multi-day occurrences that started before the window are included', () {
    final spec = ScheduleSpec(start: DatePoint(d(2026, 11, 2)), end: DatePoint(d(2026, 11, 4)));
    final r = q(spec, const RecurrenceRule(frequency: Frequency.weekly), win(d(2026, 11, 10), d(2026, 11, 10)));
    expect(r.occurrences.single.originalDate, d(2026, 11, 9));
    expect((r.occurrences.single.firstDate, r.occurrences.single.lastDate),
        (d(2026, 11, 9), d(2026, 11, 11)));
  });

  test('without a rule there is one occurrence, in or out of the window', () {
    final spec = onDate(d(2026, 11, 9));
    expect(dates(q(spec, null, win(d(2026, 11, 1), d(2026, 11, 30)))), [d(2026, 11, 9)]);
    expect(dates(q(spec, null, win(d(2026, 12, 1), d(2026, 12, 30)))), isEmpty);
  });

  group('validateRule', () {
    RecurrenceError? err(RecurrenceRule r) => switch (validateRule(r, d(2026, 11, 9))) {
          Ok() => null,
          Err(:final error) => error,
        };
    test('rejects bad rules', () {
      expect(err(const RecurrenceRule(frequency: Frequency.daily, interval: 0)), RecurrenceError.intervalOutOfRange);
      expect(err(const RecurrenceRule(frequency: Frequency.daily, end: EndsAfterCount(0))), RecurrenceError.countOutOfRange);
      expect(err(const RecurrenceRule(frequency: Frequency.monthly, byWeekday: {Weekday.monday})),
          RecurrenceError.weekdaysOnlyForWeekly);
      expect(err(const RecurrenceRule(frequency: Frequency.weekly, byWeekday: {})), RecurrenceError.noWeekdays);
      expect(err(RecurrenceRule(frequency: Frequency.daily, end: EndsOnDate(d(2026, 11, 1)))),
          RecurrenceError.endBeforeStart);
      expect(err(const RecurrenceRule(frequency: Frequency.weekly, byWeekday: {Weekday.friday})), isNull);
    });
  });
}
