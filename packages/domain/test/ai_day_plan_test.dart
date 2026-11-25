// P06 T6 (ADR-0086): the day plan's times are decided by code, not by the
// model (S-17: every small model overlapped an event).
//   kept, moved, left out, ignored; the step; "now"; lengths
//   property: whatever the model says, no overlap, within the hours, after
//   now, only the tasks asked about, each once
import 'dart:math';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

const day = DayInterval(8 * 60, 18 * 60);
int at(String hhmm) => parseDayMinute(hhmm)!;

void main() {
  final tasks = [for (final id in ['t1', 't2', 't3', 't4', 't5']) DayPlanTask(id)];
  final meeting = DayInterval(at('09:00'), at('10:30'));
  final lunch = DayInterval(at('12:00'), at('13:30'));

  test('kept where it fits; moved to the next free time when it does not (S-17 overlaps)', () {
    final fit = fitDayPlan(tasks: tasks, hours: day, busy: [meeting, lunch], wishes: [
      DayPlanWish('t1', start: at('08:00'), minutes: 60), // fits
      DayPlanWish('t2', start: at('09:15'), minutes: 15), // in the meeting
      DayPlanWish('t3', start: at('11:30'), minutes: 45), // runs into lunch
    ]);
    expect([for (final s in fit.slots) (s.taskId, formatDayMinute(s.start), s.minutes, s.moved)], [
      ('t1', '08:00', 60, false),
      ('t2', '10:30', 15, true),
      ('t3', '13:30', 45, true), // after its wish, past lunch
    ]);
  });

  test('no room after the wish: the first free time of the day; no room at all: left out', () {
    final full = [const DayInterval(8 * 60, 17 * 60 + 30)];
    final fit = fitDayPlan(tasks: tasks, hours: day, busy: full, wishes: [
      DayPlanWish('t1', start: at('17:45'), minutes: 30),
      DayPlanWish('t2', start: at('17:30'), minutes: 30),
      DayPlanWish('t3', minutes: 30),
    ]);
    expect([for (final s in fit.slots) (s.taskId, formatDayMinute(s.start))], [('t1', '17:30')]);
    expect(fit.unplaced, ['t2', 't3']);
  });

  test('unknown or repeated tasks are ignored, never placed', () {
    final fit = fitDayPlan(tasks: tasks, hours: day, wishes: [
      const DayPlanWish('t1', start: 600, minutes: 30),
      const DayPlanWish('t1', start: 700, minutes: 30),
      const DayPlanWish('other-space-task', start: 800, minutes: 30),
    ]);
    expect([for (final s in fit.slots) s.taskId], ['t1']);
    expect(fit.ignored, ['t1', 'other-space-task']);
  });

  test('lengths: the model\'s when sensible, else the task\'s estimate, else 30 minutes', () {
    final fit = fitDayPlan(
        tasks: const [DayPlanTask('a', minutes: 50), DayPlanTask('b'), DayPlanTask('c')],
        hours: day,
        wishes: const [DayPlanWish('a', minutes: 0), DayPlanWish('b', minutes: 9000), DayPlanWish('c', minutes: 20)]);
    expect([for (final s in fit.slots) s.minutes], [50, 30, 20]);
  });

  test('starts on the step; not before now; a start off the grid is moved onto it', () {
    final fit = fitDayPlan(tasks: tasks, hours: day, notBefore: at('13:02'), wishes: [
      DayPlanWish('t1', start: at('09:00'), minutes: 30), // in the past
      DayPlanWish('t2', start: at('15:07'), minutes: 30), // off the 5-minute grid
    ]);
    expect([for (final s in fit.slots) (formatDayMinute(s.start), s.moved)], [('13:05', true), ('15:10', true)]);
  });

  test('HH:MM parsing', () {
    expect(parseDayMinute('7:05'), 425);
    expect(parseDayMinute('23:59'), 1439);
    for (final bad in ['24:00', '12:60', 'noon', '', null, 14]) {
      expect(parseDayMinute(bad), isNull, reason: '$bad');
    }
    expect(formatDayMinute(425), '07:05');
  });

  test('property: whatever the model says, the plan is sound (2000 random plans)', () {
    final r = Random(17);
    for (var round = 0; round < 2000; round++) {
      final ids = [for (var i = 0; i < 1 + r.nextInt(8); i++) 't$i'];
      final busy = [
        for (var i = 0; i < r.nextInt(5); i++)
          () {
            final s = r.nextInt(24 * 60 - 30);
            return DayInterval(s, s + 15 + r.nextInt(120));
          }(),
      ];
      final hours = DayInterval(6 * 60 + r.nextInt(180), 16 * 60 + r.nextInt(360));
      final now = r.nextBool() ? r.nextInt(24 * 60) : null;
      final wishes = [
        for (var i = 0; i < r.nextInt(12); i++)
          DayPlanWish(r.nextInt(10) == 0 ? 'ghost' : ids[r.nextInt(ids.length)],
              start: r.nextInt(6) == 0 ? null : r.nextInt(26 * 60) - 60, minutes: r.nextInt(6) == 0 ? -5 : r.nextInt(200)),
      ];
      final fit = fitDayPlan(
          tasks: [for (final id in ids) DayPlanTask(id)], wishes: wishes, hours: hours, busy: busy, notBefore: now);
      final placed = <DayInterval>[];
      for (final s in fit.slots) {
        final i = DayInterval(s.start, s.end);
        expect(ids, contains(s.taskId));
        expect(s.start >= hours.start && s.end <= hours.end, isTrue, reason: '$s in $hours');
        if (now != null) expect(s.start, greaterThanOrEqualTo(now));
        expect(s.start % 5, 0);
        expect(s.minutes, inInclusiveRange(1, maxPlanMinutes));
        expect(busy.any(i.overlaps), isFalse, reason: '$s over $busy');
        expect(placed.any(i.overlaps), isFalse, reason: '$s over another task');
        placed.add(i);
      }
      final placedIds = [for (final s in fit.slots) s.taskId];
      expect(placedIds.toSet().length, placedIds.length, reason: 'each once');
      // Every wish is accounted for: placed, left out or ignored.
      expect(fit.slots.length + fit.unplaced.length + fit.ignored.length, wishes.length);
    }
  });
}
