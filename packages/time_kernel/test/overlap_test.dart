// P02 T2 — conflicts and workload (FR-PLAN-11, UC-08 / AC-08.1/08.2,
// LF-INV-CAL-002, owner decision D7).
import 'dart:math';

import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

Instant at(int minute) => Instant.fromMillis(DateTime.utc(2026, 11, 9).millisecondsSinceEpoch + minute * 60000);
TimedItem item(String id, int from, int to) => TimedItem(id, at(from), at(to));

TimedPoint tp(int day, int h, int m) =>
    TimedPoint(ZonedWallClock(LocalDate(2026, 11, day), TimeOfDayValue(h, m), 'Europe/Berlin'));

/// Brute force: every pair, half-open intervals.
Set<Conflict> naive(List<TimedItem> items) => {
      for (var i = 0; i < items.length; i++)
        for (var j = i + 1; j < items.length; j++)
          if (items[i].id != items[j].id &&
              items[i].start.millis < items[j].end.millis &&
              items[j].start.millis < items[i].end.millis)
            items[i].id.compareTo(items[j].id) < 0
                ? Conflict(items[i].id, items[j].id)
                : Conflict(items[j].id, items[i].id),
    };

void main() {
  test('basic: overlap, touching, contained', () {
    final r = overlaps([
      item('a', 0, 60),
      item('b', 30, 90), // overlaps a
      item('c', 90, 120), // touches b: no conflict
      item('d', 100, 110), // inside c
    ]);
    expect(r, const [Conflict('a', 'b'), Conflict('c', 'd')]);
  });

  test('matches brute force and ignores input order (AC-08.1, property)', () {
    final rnd = Random(9);
    for (var run = 0; run < 400; run++) {
      final items = [
        for (var i = 0; i < rnd.nextInt(40); i++)
          () {
            final s = rnd.nextInt(600);
            return item('i$i', s, s + 1 + rnd.nextInt(120));
          }(),
      ];
      final expected = naive(items).toList()
        ..sort((x, y) => '${x.first} ${x.second}'.compareTo('${y.first} ${y.second}'));
      expect(overlaps(items), expected, reason: 'run $run');
      expect(overlaps(items.reversed.toList()), expected);
      expect(overlaps([...items]..shuffle(rnd)), expected);
    }
  });

  group('who takes part (LF-INV-CAL-002, D7)', () {
    test('all-day and date-only schedules never take part', () {
      expect(timedItemOf('x', ScheduleSpec(start: DatePoint(LocalDate(2026, 11, 9)))), isNull);
      expect(timedItemOf('x', ScheduleSpec(
          start: DatePoint(LocalDate(2026, 11, 9)), end: DatePoint(LocalDate(2026, 11, 10)))), isNull);
      expect(timedItemOf('x', ScheduleSpec(end: DatePoint(LocalDate(2026, 11, 9)))), isNull);
    });

    test('a timed point without an end does not take part', () {
      expect(timedItemOf('x', ScheduleSpec(start: tp(9, 9, 0))), isNull);
      expect(timedItemOf('x', ScheduleSpec(end: tp(9, 9, 0))), isNull);
    });

    test('a timed range does; a cancelled occurrence does not', () {
      final s = ScheduleSpec(start: tp(9, 9, 0), end: tp(9, 10, 0));
      final it = timedItemOf('x', s)!;
      expect(it.end.utc.difference(it.start.utc), const Duration(hours: 1));
      final cancelled = Occurrence(
          seriesId: 'e', originalDate: LocalDate(2026, 11, 9), schedule: s,
          isException: true, isCancelled: true);
      expect(timedItemOfOccurrence('x', cancelled), isNull);
    });

    test('occurrences of two series conflict on the days both happen', () {
      final w = DateWindow(LocalDate(2026, 11, 9), LocalDate(2026, 11, 15));
      final standup = occurrencesInWindow(
          seriesId: 'standup',
          spec: ScheduleSpec(start: tp(9, 9, 0), end: tp(9, 9, 30)),
          rule: const RecurrenceRule(frequency: Frequency.daily),
          window: w);
      final review = occurrencesInWindow(
          seriesId: 'review',
          spec: ScheduleSpec(start: tp(11, 9, 15), end: tp(11, 10, 0)), // Wednesday
          rule: const RecurrenceRule(frequency: Frequency.weekly),
          window: w);
      final items = [
        for (final o in [...standup.occurrences, ...review.occurrences])
          timedItemOfOccurrence('${o.seriesId}@${o.originalDate}', o),
      ].whereType<TimedItem>();
      expect(overlaps(items), const [Conflict('review@2026-11-11', 'standup@2026-11-11')]);
    });
  });

  test('workload sums planned time inside the range', () {
    final items = [item('a', 0, 60), item('b', 30, 90), item('c', 600, 700)];
    expect(workload(items, at(0), at(120)), const Duration(minutes: 120));
    expect(workload(items, at(45), at(60)), const Duration(minutes: 30));
    expect(workload(items, at(800), at(900)), Duration.zero);
  });

  test('a timed item must end after it starts', () {
    expect(() => item('x', 10, 10), throwsArgumentError);
  });
}
