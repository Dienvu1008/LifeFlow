// P02 T7 (ADR-0034): reminder trigger times.
//   - timed anchors in their own zone, across DST (Berlin 29 Mar / 25 Oct
//     2026; New York 8 Mar 2026), gap and overlap per ADR-0028
//   - date-only anchors at the all-day time in the DEVICE zone
//   - horizon bounds, cancelled and excluded occurrences, absolute reminders
//   - validation: count, range, duplicates
import 'package:foundation/foundation.dart';
import 'package:test/test.dart';
import 'package:time_kernel/time_kernel.dart';

LocalDate d(int y, int m, int day) => LocalDate(y, m, day);
TimeOfDayValue t(int h, [int m = 0]) => TimeOfDayValue(h, m);
Instant utc(int y, int m, int day, int h, [int min = 0]) => Instant(DateTime.utc(y, m, day, h, min));
TimedPoint at(LocalDate date, TimeOfDayValue time, String zone) => TimedPoint(ZonedWallClock(date, time, zone));

final nine = t(9);
const berlin = 'Europe/Berlin';
const hcm = 'Asia/Ho_Chi_Minh';

List<ReminderTrigger> plan({
  required ScheduleSpec? spec,
  RecurrenceRule? rule,
  List<OccurrenceException> exceptions = const [],
  required List<ReminderRule> reminders,
  required Instant now,
  Duration horizon = const Duration(days: 14),
  String deviceZone = hcm,
  bool Function(Occurrence)? include,
}) =>
    remindersInHorizon(
      seriesId: 's',
      spec: spec,
      rule: rule,
      exceptions: exceptions,
      reminders: reminders,
      now: now,
      horizon: horizon,
      deviceZone: deviceZone,
      allDayTime: nine,
      include: include,
    );

void main() {
  group('anchor', () {
    test('a timed start in its own zone', () {
      final a = reminderAnchor(ScheduleSpec(start: at(d(2026, 11, 9), t(9), berlin)),
          deviceZone: hcm, allDayTime: nine);
      expect(a!.utc, DateTime.utc(2026, 11, 9, 8)); // 09:00 CET = 08:00 UTC
    });

    test('a date-only item: the all-day time in the device zone', () {
      final a = reminderAnchor(ScheduleSpec(start: DatePoint(d(2026, 11, 9))), deviceZone: hcm, allDayTime: nine);
      expect(a!.utc, DateTime.utc(2026, 11, 9, 2)); // 09:00 at UTC+7
      final b = reminderAnchor(ScheduleSpec(start: DatePoint(d(2026, 11, 9))), deviceZone: berlin, allDayTime: nine);
      expect(b!.utc, DateTime.utc(2026, 11, 9, 8));
    });

    test('start, else deadline, else end', () {
      final due = ScheduleSpec(deadline: at(d(2026, 11, 13), t(17), hcm));
      expect(reminderAnchor(due, deviceZone: hcm, allDayTime: nine)!.utc, DateTime.utc(2026, 11, 13, 10));
      final both = ScheduleSpec(start: at(d(2026, 11, 9), t(8), hcm), deadline: at(d(2026, 11, 13), t(17), hcm));
      expect(reminderAnchor(both, deviceZone: hcm, allDayTime: nine)!.utc, DateTime.utc(2026, 11, 9, 1));
      final endOnly = ScheduleSpec(end: DatePoint(d(2026, 11, 20)));
      expect(reminderAnchor(endOnly, deviceZone: hcm, allDayTime: nine)!.utc, DateTime.utc(2026, 11, 20, 2));
    });
  });

  group('across DST (LF-INV-PLAN-013)', () {
    final daily0930 = ScheduleSpec(start: at(d(2026, 3, 27), t(9, 30), berlin));
    const daily = RecurrenceRule(frequency: Frequency.daily);

    test('a daily 09:30 Berlin item reminds at 09:20 local before and after the change', () {
      final r = plan(
          spec: daily0930, rule: daily, reminders: const [RemindBefore(10)], now: utc(2026, 3, 27, 0),
          horizon: const Duration(days: 3), deviceZone: berlin);
      // 27 and 28 Mar: CET (UTC+1); 29 Mar onwards: CEST (UTC+2).
      expect(r.map((x) => x.at.utc), [
        DateTime.utc(2026, 3, 27, 8, 20),
        DateTime.utc(2026, 3, 28, 8, 20),
        DateTime.utc(2026, 3, 29, 7, 20),
      ]);
      expect(r.map((x) => x.key), ['s#0@2026-03-27', 's#0@2026-03-28', 's#0@2026-03-29']);
    });

    test('a start in the spring gap resolves to the transition, then the offset applies', () {
      // 02:30 on 29 Mar 2026 does not exist in Berlin -> 03:00 CEST = 01:00 UTC.
      final r = plan(
          spec: ScheduleSpec(start: at(d(2026, 3, 29), t(2, 30), berlin)),
          reminders: const [RemindBefore(15)],
          now: utc(2026, 3, 28, 0));
      expect(r.single.at.utc, DateTime.utc(2026, 3, 29, 0, 45));
    });

    test('a start in the autumn overlap takes the earlier instant', () {
      // 02:30 on 25 Oct 2026 happens twice in Berlin; earlier = 02:30 CEST = 00:30 UTC.
      final r = plan(
          spec: ScheduleSpec(start: at(d(2026, 10, 25), t(2, 30), berlin)),
          reminders: const [RemindBefore(0)],
          now: utc(2026, 10, 24, 0));
      expect(r.single.at.utc, DateTime.utc(2026, 10, 25, 0, 30));
    });

    test('a "1 day before" reminder over the US spring change is 24 hours of wall clock, not of UTC', () {
      // 9 Mar 2026 09:00 New York (EDT, UTC-4) = 13:00 UTC; one day = 1440 min before = 13:00 UTC on 8 Mar
      // (08:00 EST local on 8 Mar is 13:00 UTC too: before the 02:00 change). The rule is minutes before.
      final r = plan(
          spec: ScheduleSpec(start: at(d(2026, 3, 9), t(9), 'America/New_York')),
          reminders: const [RemindBefore(1440)],
          now: utc(2026, 3, 1, 0));
      expect(r.single.at.utc, DateTime.utc(2026, 3, 8, 13));
    });
  });

  group('horizon', () {
    final weekly = ScheduleSpec(start: at(d(2026, 11, 9), t(18), hcm));
    const everyWeek = RecurrenceRule(frequency: Frequency.weekly);

    test('only reminders after now and inside the horizon', () {
      // now = Mon 9 Nov 17:55 local (10:55 UTC); the 18:00 reminder at 0 min is ahead.
      final r = plan(
          spec: weekly, rule: everyWeek, reminders: const [RemindBefore(0), RemindBefore(10)],
          now: utc(2026, 11, 9, 10, 55));
      // 17:50 today has passed; 18:00 today; both on the 16th; on the 23rd
      // only 17:50 (10:50 UTC): the horizon ends at 10:55 UTC, before 18:00.
      expect(r.map((x) => x.key), [
        's#0@2026-11-09',
        's#1@2026-11-16', 's#0@2026-11-16',
        's#1@2026-11-23',
      ]);
      expect(r.every((x) => !x.at.utc.isAfter(DateTime.utc(2026, 11, 23, 10, 55))), isTrue);
    });

    test('a reminder a week before an occurrence well past the horizon is found', () {
      // Occurrence on 7 Dec 09:00 local (02:00 UTC), a week after the horizon
      // ends (30 Nov 03:00 UTC); "7 days before" fires 30 Nov 02:00 UTC.
      final r = plan(
          spec: ScheduleSpec(start: at(d(2026, 12, 7), t(9), hcm)),
          reminders: const [RemindBefore(7 * 1440)],
          now: utc(2026, 11, 9, 3),
          horizon: const Duration(days: 21));
      expect(r.single.at.utc, DateTime.utc(2026, 11, 30, 2));
    });

    test('a reminder days before an occurrence just past the horizon is still found', () {
      // Occurrence on 25 Nov; "3 days before" fires 22 Nov, inside a 14-day horizon from 9 Nov.
      final r = plan(
          spec: ScheduleSpec(start: at(d(2026, 11, 25), t(9), hcm)),
          reminders: const [RemindBefore(3 * 1440)],
          now: utc(2026, 11, 9, 0));
      expect(r.single.at.utc, DateTime.utc(2026, 11, 22, 2));
    });

    test('cancelled, skipped and excluded occurrences never remind', () {
      final r = plan(
        spec: weekly,
        rule: everyWeek,
        exceptions: [
          OccurrenceException(d(2026, 11, 16), const CancelOccurrence()),
          OccurrenceException(d(2026, 11, 23), const SkipOccurrence()),
        ],
        reminders: const [RemindBefore(0)],
        now: utc(2026, 11, 9, 0),
        horizon: const Duration(days: 22), // to 1 Dec 00:00 UTC: 30 Nov 18:00 local is inside
        include: (o) => o.originalDate != d(2026, 11, 9), // e.g. done
      );
      expect(r.map((x) => x.key), ['s#0@2026-11-30']);
    });

    test('a moved occurrence reminds at its new time, keyed by its original date', () {
      final r = plan(
        spec: weekly,
        rule: everyWeek,
        exceptions: [OccurrenceException(d(2026, 11, 16), MoveOccurrence(d(2026, 11, 17), toTime: t(7)))],
        reminders: const [RemindBefore(0)],
        now: utc(2026, 11, 10, 0),
        horizon: const Duration(days: 8),
      );
      expect(r.single.key, 's#0@2026-11-16');
      expect(r.single.at.utc, DateTime.utc(2026, 11, 17, 0)); // 07:00 local
    });

    test('an absolute reminder fires once, schedule or not', () {
      final r = plan(spec: null, reminders: [RemindAt(utc(2026, 11, 10, 3))], now: utc(2026, 11, 9, 0));
      expect(r.single.key, 's#0@at');
      expect(plan(spec: null, reminders: [RemindAt(utc(2026, 11, 8, 3))], now: utc(2026, 11, 9, 0)), isEmpty);
      expect(plan(spec: null, reminders: [RemindAt(utc(2026, 12, 30, 3))], now: utc(2026, 11, 9, 0)), isEmpty);
    });

    test('the result is the same for the same input (re-planning is stable)', () {
      List<String> keys() => plan(
              spec: weekly, rule: everyWeek, reminders: const [RemindBefore(30), RemindBefore(0)],
              now: utc(2026, 11, 9, 0))
          .map((x) => '${x.key} ${x.at.millis}')
          .toList();
      expect(keys(), keys());
    });
  });

  test('validation', () {
    expect(validateReminders(const [RemindBefore(0), RemindBefore(15)]), isA<Ok>());
    expect((validateReminders(List.generate(6, (i) => RemindBefore(i))) as Err).error, ReminderError.tooMany);
    expect((validateReminders(const [RemindBefore(-1)]) as Err).error, ReminderError.offsetOutOfRange);
    expect((validateReminders(const [RemindBefore(maxReminderOffsetMinutes + 1)]) as Err).error,
        ReminderError.offsetOutOfRange);
    expect((validateReminders(const [RemindBefore(10), RemindBefore(10)]) as Err).error, ReminderError.duplicate);
  });
}
