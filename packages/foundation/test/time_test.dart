// P02 T1: time primitives (ADR-0010, ADR-0028). Date arithmetic is checked
// against Dart's own UTC calendar over a wide range (property style).
import 'dart:math';

import 'package:foundation/foundation.dart';
import 'package:test/test.dart';

DateTime _utc(LocalDate d) => DateTime.utc(d.year, d.month, d.day);

void main() {
  group('LocalDate', () {
    test('rejects dates that do not exist', () {
      expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
      expect(() => LocalDate(2026, 4, 31), throwsArgumentError);
      expect(() => LocalDate(2026, 13, 1), throwsArgumentError);
      expect(() => LocalDate(2026, 0, 1), throwsArgumentError);
      expect(() => LocalDate(2026, 1, 0), throwsArgumentError);
      expect(LocalDate(2024, 2, 29).day, 29); // leap
      expect(() => LocalDate(1900, 2, 29), throwsArgumentError); // not leap
      expect(LocalDate(2000, 2, 29).day, 29); // leap (div by 400)
    });

    test('epoch day and weekday match the Gregorian calendar (random dates)',
        () {
      final r = Random(20261107);
      for (var i = 0; i < 20000; i++) {
        final dt = DateTime.utc(1970).add(Duration(days: r.nextInt(200000) - 100000));
        final d = LocalDate(dt.year, dt.month, dt.day);
        expect(d.epochDay, dt.millisecondsSinceEpoch ~/ 86400000, reason: '$d');
        expect(d.weekday.isoNumber, dt.weekday, reason: '$d');
        expect(LocalDate.fromEpochDay(d.epochDay), d);
      }
    });

    test('known weekdays', () {
      expect(LocalDate(1970, 1, 1).weekday, Weekday.thursday);
      expect(LocalDate(2026, 11, 7).weekday, Weekday.saturday);
      expect(LocalDate(2026, 3, 29).weekday, Weekday.sunday);
    });

    test('addDays and daysUntil agree with DateTime', () {
      final r = Random(7);
      for (var i = 0; i < 5000; i++) {
        final a = LocalDate.fromEpochDay(r.nextInt(40000) - 20000);
        final n = r.nextInt(2000) - 1000;
        final b = a.addDays(n);
        final expected = _utc(a).add(Duration(days: n));
        expect(_utc(b), expected);
        expect(a.daysUntil(b), n);
      }
    });

    test('months: exact (null when the day is missing) and clamped', () {
      final jan31 = LocalDate(2026, 1, 31);
      expect(jan31.addMonthsExact(1), isNull); // no Feb 31
      expect(jan31.addMonthsExact(2), LocalDate(2026, 3, 31));
      expect(jan31.addMonthsClamped(1), LocalDate(2026, 2, 28));
      expect(LocalDate(2024, 1, 31).addMonthsClamped(1), LocalDate(2024, 2, 29));
      expect(LocalDate(2026, 12, 15).addMonthsExact(1), LocalDate(2027, 1, 15));
      expect(LocalDate(2026, 1, 15).addMonthsExact(-1), LocalDate(2025, 12, 15));
      expect(LocalDate(2024, 2, 29).addMonthsExact(12), isNull); // 2025 not leap
      expect(LocalDate(2024, 2, 29).addMonthsClamped(12), LocalDate(2025, 2, 28));
      expect(LocalDate(2024, 2, 29).addMonthsExact(48), LocalDate(2028, 2, 29));
    });

    test('order, equality and ISO text', () {
      final a = LocalDate(2026, 3, 9);
      final b = LocalDate(2026, 3, 10);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect([b, a]..sort(), [a, b]);
      expect(a.toString(), '2026-03-09');
      expect(LocalDate.parse('2026-03-09'), a);
      expect(() => LocalDate.parse('2026-3-9'), throwsFormatException);
      expect(() => LocalDate.parse('2026-02-30'), throwsArgumentError);
    });
  });

  group('TimeOfDayValue', () {
    test('range, order and text', () {
      expect(() => TimeOfDayValue(24, 0), throwsArgumentError);
      expect(() => TimeOfDayValue(0, 60), throwsArgumentError);
      final t = TimeOfDayValue(9, 5);
      expect(t.toString(), '09:05');
      expect(TimeOfDayValue.parse('09:05'), t);
      expect(t.minuteOfDay, 545);
      expect(TimeOfDayValue(8, 59).compareTo(t), lessThan(0));
    });
  });

  group('ZonedWallClock', () {
    test('needs a zone name; keeps the wall clock on another date', () {
      expect(() => ZonedWallClock(LocalDate(2026, 1, 1), TimeOfDayValue(9, 0), ' '),
          throwsArgumentError);
      final w = ZonedWallClock(LocalDate(2026, 3, 28), TimeOfDayValue(9, 0), 'Europe/Berlin');
      final next = w.onDate(LocalDate(2026, 3, 29));
      expect(next.time, w.time);
      expect(next.zone, w.zone);
      expect(next.toString(), '2026-03-29T09:00[Europe/Berlin]');
    });
  });

  group('Weekday', () {
    test('ISO numbers', () {
      expect(Weekday.monday.isoNumber, 1);
      expect(Weekday.sunday.isoNumber, 7);
      expect(Weekday.fromIso(3), Weekday.wednesday);
      expect(() => Weekday.fromIso(0), throwsRangeError);
    });
  });

  test('FixedClock is settable', () {
    final c = FixedClock(Instant.fromMillis(0));
    expect(c.now().millis, 0);
    c.value = Instant.fromMillis(1000);
    expect(c.now().millis, 1000);
  });
}
