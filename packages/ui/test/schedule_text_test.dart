import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/src/schedule_text.dart';

void main() {
  final today = LocalDate(2026, 11, 9);

  test('relative dates near today, the year only when it differs', () {
    expect(formatDate(today, today: today), 'Today');
    expect(formatDate(today.addDays(1), today: today), 'Tomorrow');
    expect(formatDate(today.addDays(-1), today: today), 'Yesterday');
    expect(formatDate(today.addDays(2), today: today), 'Wed 11 Nov');
    expect(formatDate(LocalDate(2027, 1, 4), today: today), 'Mon 4 Jan 2027');
  });

  test('repeats', () {
    expect(describeRepeat(const RepeatInput(frequency: RepeatFrequency.daily)), 'Every day');
    expect(describeRepeat(const RepeatInput(frequency: RepeatFrequency.daily, interval: 3)), 'Every 3 days');
    expect(
        describeRepeat(const RepeatInput(
            frequency: RepeatFrequency.weekly,
            interval: 2,
            weekdays: {Weekday.friday, Weekday.monday})),
        'Every 2 weeks on Mon, Fri');
    expect(describeRepeat(RepeatInput(frequency: RepeatFrequency.monthly, end: RepeatUntil(LocalDate(2027, 6, 30)))),
        'Every month, until 2027-06-30');
    expect(describeRepeat(const RepeatInput(frequency: RepeatFrequency.yearly, end: RepeatTimes(1))),
        'Every year, once');
    expect(describeRepeat(const RepeatInput(frequency: RepeatFrequency.yearly, end: RepeatTimes(4))),
        'Every year, 4 times');
  });

  test('a schedule line; the zone only when it is not the device zone', () {
    String d(TaskScheduleInput s) => describeSchedule(s, today: today, deviceZone: 'Asia/Ho_Chi_Minh');
    expect(
        d(TaskScheduleInput(
            start: SchedulePointInput.at(today, TimeOfDayValue(9, 0), 'Asia/Ho_Chi_Minh'),
            end: SchedulePointInput.at(today, TimeOfDayValue(10, 30), 'Asia/Ho_Chi_Minh'))),
        'Today 09:00–10:30');
    expect(
        d(TaskScheduleInput(
            start: SchedulePointInput.date(today),
            end: SchedulePointInput.date(today.addDays(3)),
            deadline: SchedulePointInput.at(today.addDays(4), TimeOfDayValue(17, 0), 'UTC'))),
        'Start Today · End Thu 12 Nov · Due Fri 13 Nov 17:00 (UTC)');
  });
}
