// P02 T4: application schedule inputs <-> Time Kernel types (ADR-0030).
import 'package:application/application.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:foundation/foundation.dart';

tk.SchedulePoint? pointOf(SchedulePointInput? p) {
  if (p == null) return null;
  if (!p.isTimed) return tk.DatePoint(p.date);
  return tk.TimedPoint(ZonedWallClock(p.date, p.time!, p.zone!));
}

SchedulePointInput? inputOf(tk.SchedulePoint? p) => switch (p) {
      null => null,
      tk.DatePoint(:final date) => SchedulePointInput.date(date),
      tk.TimedPoint(:final wallClock) =>
        SchedulePointInput.at(wallClock.date, wallClock.time, wallClock.zone),
    };

tk.ScheduleSpec specOfInput(TaskScheduleInput s) =>
    tk.ScheduleSpec(start: pointOf(s.start), end: pointOf(s.end), deadline: pointOf(s.deadline));

tk.RecurrenceRule? ruleOfInput(RepeatInput? r) => r == null
    ? null
    : tk.RecurrenceRule(
        frequency: tk.Frequency.values.byName(r.frequency.name),
        interval: r.interval,
        byWeekday: r.weekdays,
        end: switch (r.end) {
          RepeatForever() => const tk.EndsNever(),
          RepeatUntil(:final date) => tk.EndsOnDate(date),
          RepeatTimes(:final count) => tk.EndsAfterCount(count),
        },
        monthEndRule: tk.MonthEndRule.values.byName(r.monthEnd.name),
        weekStart: r.weekStart,
      );

RepeatInput? repeatOf(tk.RecurrenceRule? r) => r == null
    ? null
    : RepeatInput(
        frequency: RepeatFrequency.values.byName(r.frequency.name),
        interval: r.interval,
        weekdays: r.byWeekday,
        end: switch (r.end) {
          tk.EndsNever() => const RepeatForever(),
          tk.EndsOnDate(:final date) => RepeatUntil(date),
          tk.EndsAfterCount(:final count) => RepeatTimes(count),
        },
        monthEnd: MonthEndChoice.values.byName(r.monthEndRule.name),
        weekStart: r.weekStart,
      );

TaskScheduleInput scheduleInputOf(tk.ScheduleSpec s, tk.RecurrenceRule? r) => TaskScheduleInput(
    start: inputOf(s.start), end: inputOf(s.end), deadline: inputOf(s.deadline), repeat: repeatOf(r));

/// Why a schedule input is refused (shown to the user).
String? scheduleInputError(TaskScheduleInput s) {
  for (final p in [s.start, s.end, s.deadline]) {
    if (p != null && p.isTimed != (p.zone != null)) return 'a time needs a time zone';
  }
  final spec = specOfInput(s);
  switch (tk.validateSchedule(spec)) {
    case Err(:final error):
      return switch (error) {
        tk.ScheduleError.empty => 'set a start, an end or a deadline',
        tk.ScheduleError.mixedKinds => 'start and end must both have a time, or neither',
        tk.ScheduleError.endBeforeStart => 'the end is before the start',
        tk.ScheduleError.unknownZone => 'unknown time zone',
      };
    case Ok():
  }
  final rule = ruleOfInput(s.repeat);
  if (rule != null) {
    final anchor = (spec.start ?? spec.end ?? spec.deadline)!.date;
    if (tk.validateRule(rule, anchor) case Err(:final error)) {
      return switch (error) {
        tk.RecurrenceError.intervalOutOfRange => 'repeat every 1 to ${tk.RecurrenceRule.maxInterval}',
        tk.RecurrenceError.countOutOfRange => 'repeat 1 to ${tk.RecurrenceRule.maxCount} times',
        tk.RecurrenceError.weekdaysOnlyForWeekly => 'weekdays are only for weekly repeats',
        tk.RecurrenceError.noWeekdays => 'choose at least one weekday',
        tk.RecurrenceError.endBeforeStart => 'the repeat ends before it starts',
      };
    }
  }
  return null;
}
