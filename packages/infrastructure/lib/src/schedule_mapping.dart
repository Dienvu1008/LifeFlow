// Mapping between stored schedule rows and the Time Kernel types
// (P02 T3, ADR-0029). Dates are ISO text and times `HH:MM`; a timed point
// stores its zone. Rows are checked on the way in: an export file is
// untrusted (SR-14), so a malformed or invalid schedule is rejected, never
// half-read.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'app_database.dart';

/// Stored schedule rows that cannot be read.
class BadScheduleRow implements Exception {
  const BadScheduleRow(this.why);
  final String why;
  @override
  String toString() => 'BadScheduleRow($why)';
}

String scheduleIdOf(String subjectType, String subjectId) => '$subjectType:$subjectId';
String exceptionIdOf(String subjectType, String subjectId, LocalDate original) =>
    '$subjectType:$subjectId@$original';
String completionIdOf(String taskId, LocalDate original) => 'task:$taskId@$original';

LocalDate? _date(String? s) {
  if (s == null) return null;
  try {
    return LocalDate.parse(s);
  } catch (_) {
    throw BadScheduleRow('bad date "$s"');
  }
}

TimeOfDayValue? _time(String? s) {
  if (s == null) return null;
  try {
    return TimeOfDayValue.parse(s);
  } catch (_) {
    throw BadScheduleRow('bad time "$s"');
  }
}

tk.SchedulePoint? _point(String? date, String? time, String? zone) {
  final d = _date(date);
  if (d == null) {
    if (time != null || zone != null) throw const BadScheduleRow('time without a date');
    return null;
  }
  final t = _time(time);
  if (t == null) {
    if (zone != null) throw const BadScheduleRow('zone without a time');
    return tk.DatePoint(d);
  }
  if (zone == null) throw const BadScheduleRow('time without a zone');
  return tk.TimedPoint(ZonedWallClock(d, t, zone));
}

({String? date, String? time, String? zone}) _fields(tk.SchedulePoint? p) => switch (p) {
      null => (date: null, time: null, zone: null),
      tk.DatePoint(:final date) => (date: '$date', time: null, zone: null),
      tk.TimedPoint(:final wallClock) =>
        (date: '${wallClock.date}', time: '${wallClock.time}', zone: wallClock.zone),
    };

/// The schedule of a row. Throws [BadScheduleRow].
tk.ScheduleSpec specOf(Schedule r) => tk.ScheduleSpec(
      start: _point(r.startDate, r.startTime, r.startZone),
      end: _point(r.endDate, r.endTime, r.endZone),
      deadline: _point(r.deadlineDate, r.deadlineTime, r.deadlineZone),
    );

/// The repeat rule of a row, or null. Throws [BadScheduleRow].
tk.RecurrenceRule? ruleOf(Schedule r) {
  final f = r.frequency;
  if (f == null) return null;
  final frequency = tk.Frequency.values.where((x) => x.name == f).firstOrNull ??
      (throw BadScheduleRow('bad frequency "$f"'));
  Set<Weekday>? days;
  final w = r.weekdays;
  if (w != null && w.isNotEmpty) {
    try {
      days = {for (final n in w.split(',')) Weekday.fromIso(int.parse(n))};
    } catch (_) {
      throw BadScheduleRow('bad weekdays "$w"');
    }
  }
  final tk.RecurrenceEnd end = switch (r.endKind) {
    null || 'never' => const tk.EndsNever(),
    'onDate' => tk.EndsOnDate(_date(r.endDateRule) ?? (throw const BadScheduleRow('end date missing'))),
    'afterCount' => tk.EndsAfterCount(r.endCount ?? (throw const BadScheduleRow('end count missing'))),
    final other => throw BadScheduleRow('bad end kind "$other"'),
  };
  final monthEnd = tk.MonthEndRule.values.where((x) => x.name == r.monthEndRule).firstOrNull ??
      (throw BadScheduleRow('bad month-end rule "${r.monthEndRule}"'));
  final Weekday weekStart;
  try {
    weekStart = Weekday.fromIso(r.weekStart);
  } catch (_) {
    throw BadScheduleRow('bad week start ${r.weekStart}');
  }
  return tk.RecurrenceRule(
    frequency: frequency,
    interval: r.interval,
    byWeekday: days,
    end: end,
    monthEndRule: monthEnd,
    weekStart: weekStart,
  );
}

/// Reads and fully validates a stored schedule. Throws [BadScheduleRow].
(tk.ScheduleSpec, tk.RecurrenceRule?) readSchedule(Schedule r) {
  final spec = specOf(r);
  if (tk.validateSchedule(spec) case Err(:final error)) {
    throw BadScheduleRow('invalid schedule (${error.name})');
  }
  final rule = ruleOf(r);
  final anchor = (spec.start ?? spec.end ?? spec.deadline)!.date;
  if (rule != null) {
    if (tk.validateRule(rule, anchor) case Err(:final error)) {
      throw BadScheduleRow('invalid repeat (${error.name})');
    }
  }
  if (r.id != scheduleIdOf(r.subjectType, r.subjectId)) {
    throw const BadScheduleRow('schedule id does not match its subject');
  }
  final range = dateRangeOf(spec, rule);
  if (r.firstDate != '${range.first}' || r.lastDate != range.last?.toString()) {
    throw const BadScheduleRow('stored date range does not match the schedule');
  }
  return (spec, rule);
}

/// First date of the series and its last possible date (null = open-ended),
/// stored for range pre-filtering. Moved occurrences are found through
/// their exception rows, not through this range.
({LocalDate first, LocalDate? last}) dateRangeOf(tk.ScheduleSpec spec, tk.RecurrenceRule? rule) {
  final first = (spec.start ?? spec.end ?? spec.deadline)!.date;
  final lastPoint = (spec.end ?? spec.start ?? spec.deadline)!.date;
  final span = first.daysUntil(lastPoint);
  if (rule == null) return (first: first, last: lastPoint);
  final lastRule = tk.lastRuleDate(spec, rule);
  return (first: first, last: lastRule?.addDays(span));
}

/// The columns of a schedule row for [spec] and [rule]; the caller adds the
/// syncable columns (id, workspace, owner, version, timestamps).
SchedulesCompanion scheduleFields(String subjectType, String subjectId,
    tk.ScheduleSpec spec, tk.RecurrenceRule? rule) {
  final s = _fields(spec.start), e = _fields(spec.end), d = _fields(spec.deadline);
  final range = dateRangeOf(spec, rule);
  final end = rule?.end;
  return SchedulesCompanion(
    id: Value(scheduleIdOf(subjectType, subjectId)),
    subjectType: Value(subjectType),
    subjectId: Value(subjectId),
    startDate: Value(s.date), startTime: Value(s.time), startZone: Value(s.zone),
    endDate: Value(e.date), endTime: Value(e.time), endZone: Value(e.zone),
    deadlineDate: Value(d.date), deadlineTime: Value(d.time), deadlineZone: Value(d.zone),
    firstDate: Value('${range.first}'),
    lastDate: Value(range.last?.toString()),
    frequency: Value(rule?.frequency.name),
    interval: Value(rule?.interval ?? 1),
    weekdays: Value(rule?.byWeekday == null
        ? null
        : ([for (final w in rule!.byWeekday!) w.isoNumber]..sort()).join(',')),
    endKind: Value(switch (end) {
      null => null,
      tk.EndsNever() => 'never',
      tk.EndsOnDate() => 'onDate',
      tk.EndsAfterCount() => 'afterCount',
    }),
    endDateRule: Value(end is tk.EndsOnDate ? '${end.date}' : null),
    endCount: Value(end is tk.EndsAfterCount ? end.count : null),
    monthEndRule: Value((rule?.monthEndRule ?? tk.MonthEndRule.skip).name),
    weekStart: Value((rule?.weekStart ?? Weekday.monday).isoNumber),
  );
}

/// The kernel exception of a stored row. Throws [BadScheduleRow].
tk.OccurrenceException exceptionOf(OccurrenceException r) {
  final original = _date(r.originalDate)!;
  if (r.id != exceptionIdOf(r.subjectType, r.subjectId, original)) {
    throw const BadScheduleRow('exception id does not match its subject and date');
  }
  final tk.ExceptionKind kind = switch (r.kind) {
    'skip' => const tk.SkipOccurrence(),
    'cancel' => const tk.CancelOccurrence(),
    'move' => tk.MoveOccurrence(
        _date(r.moveDate) ?? (throw const BadScheduleRow('move without a date')),
        toTime: _time(r.moveTime)),
    'edit' => tk.EditOccurrence(() {
        try {
          return (jsonDecode(r.patch ?? '{}') as Map).cast<String, Object?>();
        } catch (_) {
          throw const BadScheduleRow('bad edit patch');
        }
      }()),
    final other => throw BadScheduleRow('bad exception kind "$other"'),
  };
  return tk.OccurrenceException(original, kind);
}

/// The columns of an exception row; the caller adds the syncable columns.
OccurrenceExceptionsCompanion exceptionFields(
    String subjectType, String subjectId, tk.OccurrenceException e) {
  final k = e.kind;
  return OccurrenceExceptionsCompanion(
    id: Value(exceptionIdOf(subjectType, subjectId, e.originalDate)),
    subjectType: Value(subjectType),
    subjectId: Value(subjectId),
    originalDate: Value('${e.originalDate}'),
    kind: Value(switch (k) {
      tk.SkipOccurrence() => 'skip',
      tk.CancelOccurrence() => 'cancel',
      tk.MoveOccurrence() => 'move',
      tk.EditOccurrence() => 'edit',
    }),
    moveDate: Value(k is tk.MoveOccurrence ? '${k.toDate}' : null),
    moveTime: Value(k is tk.MoveOccurrence ? k.toTime?.toString() : null),
    patch: Value(k is tk.EditOccurrence ? jsonEncode(k.patch) : null),
  );
}
