// P02 T4 (ADR-0030): what the UI may see and ask about schedules of tasks.
// Plain data with `foundation` types only, so the UI never depends on the
// Time Kernel (FF-ARCH-04). Infrastructure maps these to and from the kernel.
import 'package:foundation/foundation.dart';

import 'command.dart';

/// A point of a schedule as the user enters or sees it: a date, optionally a
/// time in a named zone. A date without a time is date-only and never
/// becomes an instant (LF-INV-PLAN-004).
class SchedulePointInput {
  const SchedulePointInput.date(this.date)
      : time = null,
        zone = null;
  SchedulePointInput.at(this.date, TimeOfDayValue this.time, String this.zone);

  final LocalDate date;
  final TimeOfDayValue? time;
  final String? zone;

  bool get isTimed => time != null;

  @override
  bool operator ==(Object o) =>
      o is SchedulePointInput && o.date == date && o.time == time && o.zone == zone;
  @override
  int get hashCode => Object.hash(date, time, zone);
  @override
  String toString() => isTimed ? '${date}T$time[$zone]' : '$date';
}

enum RepeatFrequency { daily, weekly, monthly, yearly }

/// Owner decision D2: what a monthly/yearly repeat does in a month without
/// that day.
enum MonthEndChoice { skip, lastDay }

sealed class RepeatEnd {
  const RepeatEnd();
}

class RepeatForever extends RepeatEnd {
  const RepeatForever();
}

class RepeatUntil extends RepeatEnd {
  const RepeatUntil(this.date);
  final LocalDate date;
}

class RepeatTimes extends RepeatEnd {
  const RepeatTimes(this.count);
  final int count;
}

class RepeatInput {
  const RepeatInput({
    required this.frequency,
    this.interval = 1,
    this.weekdays,
    this.end = const RepeatForever(),
    this.monthEnd = MonthEndChoice.skip,
    this.weekStart = Weekday.monday,
  });
  final RepeatFrequency frequency;
  final int interval;
  final Set<Weekday>? weekdays;
  final RepeatEnd end;
  final MonthEndChoice monthEnd;
  final Weekday weekStart;
}

/// The schedule of a task: planned start and/or end, a deadline, a repeat.
class TaskScheduleInput {
  const TaskScheduleInput({this.start, this.end, this.deadline, this.repeat});
  final SchedulePointInput? start;
  final SchedulePointInput? end;
  final SchedulePointInput? deadline;
  final RepeatInput? repeat;
}

/// What happens to one occurrence of a repeating task.
sealed class OccurrenceChange {
  const OccurrenceChange();
}

/// Not this time.
class SkipThisOccurrence extends OccurrenceChange {
  const SkipThisOccurrence();
}

/// On another date (and, for a timed task, optionally at another time).
class MoveThisOccurrence extends OccurrenceChange {
  const MoveThisOccurrence(this.toDate, {this.toTime});
  final LocalDate toDate;
  final TimeOfDayValue? toTime;
}

/// Schedule commands for tasks. Like [TaskService], everything goes through
/// the command gateway; failures are returned, never thrown.
abstract interface class TaskScheduling {
  /// Sets (or replaces) the schedule of a task. Null clears it.
  Future<CommandResult> setSchedule(String taskId, TaskScheduleInput? schedule);

  /// Changes one occurrence of a repeating task (owner decision D4: "only
  /// this occurrence"). Null removes an earlier change.
  Future<CommandResult> changeOccurrence(String taskId, LocalDate originalDate, OccurrenceChange? change);

  /// Marks one occurrence of a repeating task done, or open again (owner
  /// decision D5). The task itself stays open.
  Future<CommandResult> setOccurrenceDone(String taskId, LocalDate originalDate, {required bool done});

  /// The stored schedule of a task, or null.
  Future<TaskScheduleInput?> scheduleOf(String taskId);
}

/// One occurrence of a scheduled task, for Today, Upcoming and the calendar.
class AgendaItem {
  const AgendaItem({
    required this.taskId,
    required this.title,
    required this.originalDate,
    this.start,
    this.end,
    this.deadline,
    required this.isRepeating,
    required this.isDone,
    this.isMoved = false,
    this.isOverdue = false,
    this.deviceStart,
    this.deviceEnd,
  });

  final String taskId;
  final String title;

  /// Identity of the occurrence within its series.
  final LocalDate originalDate;
  final SchedulePointInput? start;
  final SchedulePointInput? end;
  final SchedulePointInput? deadline;
  final bool isRepeating;

  /// This occurrence is done (repeating) or the task is done (one-off).
  final bool isDone;
  final bool isMoved;

  /// A one-off task planned before today and still open (shown in Today).
  final bool isOverdue;

  /// P03 UX U5: the timed start and end in the DEVICE's zone, resolved by the
  /// Time Kernel (DST gaps and overlaps), for placing it on a time grid.
  /// Null when date-only (or no such point).
  final SchedulePointInput? deviceStart;
  final SchedulePointInput? deviceEnd;

  /// The first date the item is on.
  LocalDate get date => (start ?? end ?? deadline)!.date;
}

class Agenda {
  const Agenda(this.items, {this.truncated = false});
  final List<AgendaItem> items;

  /// The range was too long or had too many occurrences; show a notice
  /// (LF-INV-PLAN-010, UC-06 E1).
  final bool truncated;
}

/// Read side of scheduled tasks for the ACTIVE profile.
abstract interface class AgendaQueries {
  /// "Today" in the device's zone: today's occurrences and one-off tasks
  /// that are overdue (planned or due before today, still open).
  Stream<Agenda> watchToday();

  /// The days after today ([days] days, default 14).
  Stream<Agenda> watchUpcoming({int days = 14});

  /// Occurrences touching [from]..[to] (inclusive), for the calendar.
  Stream<Agenda> watchRange(LocalDate from, LocalDate to);
}

/// The device's clock and time zone (IANA name), injected so time-dependent
/// queries are testable.
abstract interface class DeviceTime {
  Instant now();
  String zone();
}
