// P03 T1 (ADR-0036): targets, measurements, periods and habit tracking.
//   GS-02            target boundaries, table-driven (min == max, open bounds)
//   GS-01            achieved exactly when the aggregate crosses the target;
//                    derived, never set by the data
//   LF-INV-HEALTH-002 no current measurement = no data, not zero
//   LF-INV-EXEC-001  a correction supersedes; history is kept
//   D6–D9            periods from the repeat, outcomes, rate and streak
import 'package:domain/domain.dart';
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

LocalDate d(int m, int day) => LocalDate(2026, m, day);
final t0 = Instant(DateTime.utc(2026, 11, 10, 1));
Measurement m(String id, double v, {LocalDate? on, int minute = 0, String? supersedes, bool withdrawn = false}) =>
    Measurement(
      id: id,
      taskId: 't',
      value: v,
      localDate: on ?? d(11, 10),
      recordedAt: Instant(t0.utc.add(Duration(minutes: minute))),
      supersedesId: supersedes,
      withdrawn: withdrawn,
    );

MeasurableTarget atLeast(double min) => MeasurableTarget(type: TargetType.atLeast, min: min, unit: 'steps');
MeasurableTarget atMost(double max) => MeasurableTarget(type: TargetType.atMost, max: max, unit: 'cups');
MeasurableTarget about(double min, double max) => MeasurableTarget(type: TargetType.about, min: min, max: max, unit: 'h');

void main() {
  group('target validation (D7)', () {
    test('which bounds each type needs; values >= 0 and finite; a unit', () {
      expect(atLeast(5000).validate(), isNull);
      expect(atMost(3).validate(), isNull);
      expect(about(7, 8).validate(), isNull);
      expect(about(7, 7).validate(), isNull); // min == max
      expect(const MeasurableTarget(type: TargetType.atLeast, unit: 'x').validate(), contains('minimum'));
      expect(const MeasurableTarget(type: TargetType.atMost, unit: 'x').validate(), contains('maximum'));
      expect(const MeasurableTarget(type: TargetType.about, min: 1, unit: 'x').validate(), contains('minimum and a maximum'));
      expect(about(8, 7).validate(), isNotNull);
      expect(atLeast(-1).validate(), contains('0 or more'));
      expect(atLeast(double.infinity).validate(), contains('0 or more'));
      expect(const MeasurableTarget(type: TargetType.atLeast, min: 1, unit: '  ').validate(), contains('unit'));
      expect(MeasurableTarget(type: TargetType.atLeast, min: 1, unit: 'x' * 41).validate(), contains('too long'));
    });

    test('a measurement value is >= 0 and finite', () {
      expect(measurementValueError(0), isNull);
      expect(measurementValueError(-0.5), isNotNull);
      expect(measurementValueError(double.nan), isNotNull);
    });
  });

  group('GS-02: boundaries, inclusive', () {
    final cases = <(String, MeasurableTarget, double, bool, PeriodState)>[
      ('atLeast below, open', atLeast(5000), 4999, false, PeriodState.inProgress),
      ('atLeast below, ended', atLeast(5000), 4999, true, PeriodState.notAchieved),
      ('atLeast exactly, open', atLeast(5000), 5000, false, PeriodState.achieved),
      ('atLeast above, ended', atLeast(5000), 9000, true, PeriodState.achieved),
      ('atLeast 0 (no upper bound)', atLeast(0), 0, false, PeriodState.achieved),
      ('atMost open is not judged', atMost(3), 1, false, PeriodState.inProgress),
      ('atMost exactly', atMost(3), 3, true, PeriodState.achieved),
      ('atMost above', atMost(3), 3.01, true, PeriodState.notAchieved),
      ('atMost 0 (no lower bound)', atMost(0), 0, true, PeriodState.achieved),
      ('about at min', about(7, 8), 7, true, PeriodState.achieved),
      ('about at max', about(7, 8), 8, true, PeriodState.achieved),
      ('about below', about(7, 8), 6.99, true, PeriodState.notAchieved),
      ('about above', about(7, 8), 8.01, true, PeriodState.notAchieved),
      ('about min == max', about(7, 7), 7, true, PeriodState.achieved),
      ('about open is not judged', about(7, 8), 7.5, false, PeriodState.inProgress),
    ];
    for (final (name, target, value, ended, want) in cases) {
      test(name, () => expect(evaluate(target, value, periodEnded: ended), want));
    }

    test('no value is no data, open or ended, for every type (LF-INV-HEALTH-002)', () {
      for (final t in [atLeast(1), atMost(1), about(1, 2)]) {
        expect(evaluate(t, null, periodEnded: false), PeriodState.noData);
        expect(evaluate(t, null, periodEnded: true), PeriodState.noData);
      }
    });

    test('a measured 0 is a value, not no data', () {
      expect(evaluate(atLeast(1), 0, periodEnded: true), PeriodState.notAchieved);
      expect(aggregate([m('a', 0)], TargetAggregation.sum), 0);
    });
  });

  group('aggregation and corrections (LF-INV-EXEC-001)', () {
    test('sum, max, latest (by time recorded), average', () {
      final list = [m('a', 3000, minute: 1), m('b', 1000, minute: 5), m('c', 2000, minute: 3)];
      expect(aggregate(list, TargetAggregation.sum), 6000);
      expect(aggregate(list, TargetAggregation.max), 3000);
      expect(aggregate(list, TargetAggregation.latest), 1000);
      expect(aggregate(list, TargetAggregation.average), 2000);
      expect(aggregate(const [], TargetAggregation.sum), isNull);
    });

    test('a correction replaces the old value in the totals; the old one stays in the list', () {
      final history = [m('a', 3000), m('b', 2000), m('a2', 300, minute: 9, supersedes: 'a')];
      final current = currentMeasurements(history);
      expect(current.map((x) => x.id), ['b', 'a2']);
      expect(aggregate(current, TargetAggregation.sum), 2300);
      expect(history, hasLength(3)); // nothing removed from history
      // A chain of corrections; and a withdrawal removes the value.
      final chain = [...history, m('a3', 30, minute: 10, supersedes: 'a2'), m('bx', 0, supersedes: 'b', withdrawn: true)];
      expect(currentMeasurements(chain).map((x) => x.id), ['a3']);
    });
  });

  group('GS-01: walk at least 5000 steps a day', () {
    test('achieved exactly when the day\'s sum crosses 5000; a derived state, recomputed each time', () {
      final target = atLeast(5000);
      final day = periodOf(
          spec: ScheduleSpec(start: DatePoint(d(11, 1))),
          rule: const RecurrenceRule(frequency: Frequency.daily),
          date: d(11, 10))!;
      final today = d(11, 10);
      final entries = <Measurement>[];
      PeriodState now() => periodState(target, day, entries, today);
      expect(now(), PeriodState.noData);
      entries.add(m('1', 2000));
      expect(now(), PeriodState.inProgress);
      entries.add(m('2', 2999));
      expect(now(), PeriodState.inProgress);
      entries.add(m('3', 1));
      expect(now(), PeriodState.achieved); // exactly 5000
      entries.add(m('4', 9000, on: d(11, 11))); // another day does not count here
      expect(aggregate(currentMeasurements(entries).where((x) => day.contains(x.localDate)), TargetAggregation.sum), 5000);
      // Correcting an entry down un-achieves it: the state is never stored by the data.
      entries.add(m('3b', 0, supersedes: '3', minute: 30));
      expect(now(), PeriodState.inProgress);
      // After the day ends: not achieved.
      expect(periodState(target, day, entries, d(11, 11)), PeriodState.notAchieved);
    });
  });

  group('periods (D6)', () {
    test('a repeating task: the rule period; identity = its first day', () {
      final weekly = periodOf(
          spec: ScheduleSpec(start: DatePoint(d(11, 9))),
          rule: const RecurrenceRule(frequency: Frequency.weekly),
          date: d(11, 12))!;
      expect((weekly.key, weekly.from, weekly.to), (d(11, 9), d(11, 9), d(11, 15)));
      expect(weekly.hasEndedOn(d(11, 15)), isFalse);
      expect(weekly.hasEndedOn(d(11, 16)), isTrue);
      expect(
          periodOf(
              spec: ScheduleSpec(start: DatePoint(d(11, 9))),
              rule: const RecurrenceRule(frequency: Frequency.daily),
              date: d(11, 8)),
          isNull);
    });

    test('a one-off task: one period, all its measurements, ending after its last date', () {
      final p = periodOf(
          spec: ScheduleSpec(start: DatePoint(d(11, 1)), deadline: DatePoint(d(11, 20))), date: d(11, 5))!;
      expect((p.key, p.from, p.to), (null, null, d(11, 20)));
      expect(p.contains(d(1, 1)), isTrue);
      expect(p.hasEndedOn(d(11, 21)), isTrue);
      final unplanned = periodOf(date: d(11, 5))!;
      expect(unplanned.hasEndedOn(d(12, 31)), isFalse); // never ends by itself
    });
  });

  group('habit tracking (D6b/D6c)', () {
    test('unmeasured: done when ticked, missed when the period ended unticked, open otherwise', () {
      expect(occurrenceOutcome(ticked: true, periodEnded: false), HabitOutcome.done);
      expect(occurrenceOutcome(ticked: false, periodEnded: true), HabitOutcome.missed);
      expect(occurrenceOutcome(ticked: false, periodEnded: false), isNull);
      expect(outcomeOf(PeriodState.inProgress), isNull);
      expect(outcomeOf(PeriodState.noData), HabitOutcome.noData);
    });

    test('rate: successes over judged periods; no data counts neither way', () {
      final r = completionRate(
          [HabitOutcome.done, HabitOutcome.missed, HabitOutcome.noData, HabitOutcome.achieved, HabitOutcome.notAchieved]);
      expect((r.successes, r.judged, r.ratio), (2, 4, 0.5));
      expect(completionRate([HabitOutcome.noData]).ratio, isNull);
    });

    test('streak: back from the newest; the open period is skipped; a miss or no data ends it', () {
      expect(currentStreak([null, HabitOutcome.done, HabitOutcome.done, HabitOutcome.missed, HabitOutcome.done]), 2);
      expect(currentStreak([HabitOutcome.done, HabitOutcome.achieved, HabitOutcome.noData, HabitOutcome.done]), 2);
      expect(currentStreak([HabitOutcome.missed, HabitOutcome.done]), 0);
      expect(currentStreak(const []), 0);
    });
  });
}
