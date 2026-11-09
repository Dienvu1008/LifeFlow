// P02 T1 — ScheduleSpec (FR-PLAN-01..04) and LF-INV-PLAN-004.
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

DatePoint date(int y, int m, int d) => DatePoint(LocalDate(y, m, d));
TimedPoint timed(int y, int m, int d, int h, int min, [String zone = 'Europe/Berlin']) =>
    TimedPoint(ZonedWallClock(LocalDate(y, m, d), TimeOfDayValue(h, min), zone));

ScheduleError? errorOf(ScheduleSpec s) => switch (validateSchedule(s)) {
      Ok() => null,
      Err(:final error) => error,
    };

void main() {
  group('the six shapes (FR-PLAN-01)', () {
    final cases = <(ScheduleSpec, ScheduleShape, bool)>[
      (ScheduleSpec(start: date(2026, 11, 9)), ScheduleShape.startDate, true),
      (ScheduleSpec(start: timed(2026, 11, 9, 9, 0)), ScheduleShape.startDateTime, false),
      (ScheduleSpec(start: date(2026, 11, 9), end: date(2026, 11, 11)), ScheduleShape.dateRange, true),
      (ScheduleSpec(start: timed(2026, 11, 9, 9, 0), end: timed(2026, 11, 9, 10, 30)), ScheduleShape.dateTimeRange, false),
      (ScheduleSpec(end: date(2026, 11, 13)), ScheduleShape.endDate, true),
      (ScheduleSpec(end: timed(2026, 11, 13, 17, 0)), ScheduleShape.endDateTime, false),
    ];
    for (final (spec, shape, allDay) in cases) {
      test('${shape.name} is valid; all-day = $allDay', () {
        expect(errorOf(spec), isNull);
        expect(spec.shape, shape);
        expect(spec.isAllDay, allDay);
      });
    }
  });

  test('a deadline is separate from the planned time (FR-PLAN-03)', () {
    final s = ScheduleSpec(start: date(2026, 11, 9), deadline: timed(2026, 11, 13, 17, 0));
    expect(errorOf(s), isNull);
    expect(s.shape, ScheduleShape.startDate);
    final onlyDeadline = ScheduleSpec(deadline: date(2026, 11, 13));
    expect(errorOf(onlyDeadline), isNull);
    expect(onlyDeadline.shape, isNull);
    expect(onlyDeadline.isAllDay, isFalse); // nothing planned
  });

  group('rejected', () {
    test('nothing set', () => expect(errorOf(const ScheduleSpec()), ScheduleError.empty));
    test('end before start (dates)', () {
      expect(errorOf(ScheduleSpec(start: date(2026, 11, 9), end: date(2026, 11, 8))),
          ScheduleError.endBeforeStart);
      // Same day is a one-day range, fine.
      expect(errorOf(ScheduleSpec(start: date(2026, 11, 9), end: date(2026, 11, 9))), isNull);
    });
    test('end before start (timed, compared as instants)', () {
      expect(errorOf(ScheduleSpec(start: timed(2026, 11, 9, 10, 0), end: timed(2026, 11, 9, 9, 0))),
          ScheduleError.endBeforeStart);
      // 09:00 in New York is after 10:00 in Berlin.
      expect(
          errorOf(ScheduleSpec(
              start: timed(2026, 11, 9, 10, 0, 'Europe/Berlin'),
              end: timed(2026, 11, 9, 9, 0, 'America/New_York'))),
          isNull);
    });
    test('date start with timed end', () {
      expect(errorOf(ScheduleSpec(start: date(2026, 11, 9), end: timed(2026, 11, 9, 9, 0))),
          ScheduleError.mixedKinds);
    });
    test('unknown zone', () {
      expect(errorOf(ScheduleSpec(start: timed(2026, 11, 9, 9, 0, 'Nowhere/City'))),
          ScheduleError.unknownZone);
      expect(errorOf(ScheduleSpec(deadline: timed(2026, 11, 9, 9, 0, 'Nowhere/City'))),
          ScheduleError.unknownZone);
    });
  });

  test('duration of a timed range, across a DST change (Berlin, 29 Mar)', () {
    final s = ScheduleSpec(start: timed(2026, 3, 29, 1, 0), end: timed(2026, 3, 29, 4, 0));
    expect(s.duration, const Duration(hours: 2)); // one hour does not exist
    expect(ScheduleSpec(start: date(2026, 1, 1), end: date(2026, 1, 2)).duration, isNull);
  });

  test('LF-INV-PLAN-004: a date-only point has no instant and stays a date '
      'whatever the zone', () {
    final SchedulePoint p = DatePoint(_d);
    // instantOf only accepts a TimedPoint; a DatePoint has no instant API.
    expect(p, isNot(isA<TimedPoint>()));
    expect(p.date, _d);
    // The date of a timed point is its LOCAL date, not the UTC date.
    final late = timed(2026, 11, 9, 23, 30, 'Asia/Ho_Chi_Minh');
    expect(late.date, LocalDate(2026, 11, 9));
    expect(instantOf(late).utc.day, 9); // 16:30Z
  });
}

final _d = LocalDate(2026, 11, 9);
