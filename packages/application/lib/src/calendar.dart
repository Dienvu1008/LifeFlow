// P02 T5 (ADR-0031): events, calendars and the calendar view, as the UI sees
// them. `foundation` types only (FF-ARCH-04). An event is never a task and a
// task is never an event (LF-INV-CAL-001, owner decision D6).
import 'package:foundation/foundation.dart';

import 'command.dart';
import 'planning.dart';

class CalendarView {
  const CalendarView({required this.id, required this.name, required this.color});
  final String id;
  final String name;

  /// ARGB, for example 0xFF009688.
  final int color;
}

/// What the user enters for an event. An event always has a start; the end
/// is optional; an all-day event uses dates without times.
class EventInput {
  const EventInput({
    required this.title,
    required this.start,
    this.end,
    this.location,
    this.calendarId,
    this.repeat,
    this.listId,
  });
  final String title;
  final SchedulePointInput start;
  final SchedulePointInput? end;
  final String? location;
  final String? calendarId;
  final RepeatInput? repeat;

  /// P03 UX U2: the list a NEW event goes to (null: none). Read on create
  /// only; an event changes list through OverviewService.moveEvent.
  final String? listId;
}

class EventDetails {
  const EventDetails({
    required this.id,
    required this.input,
    required this.isCancelled,
  });
  final String id;
  final EventInput input;

  /// The whole event (all occurrences) is cancelled.
  final bool isCancelled;
}

/// What happens to one occurrence of a repeating event (owner decision D4).
sealed class EventOccurrenceChange {
  const EventOccurrenceChange();
}

class SkipEventOccurrence extends EventOccurrenceChange {
  const SkipEventOccurrence();
}

/// Shown, but marked cancelled.
class CancelEventOccurrence extends EventOccurrenceChange {
  const CancelEventOccurrence();
}

class MoveEventOccurrence extends EventOccurrenceChange {
  const MoveEventOccurrence(this.toDate, {this.toTime});
  final LocalDate toDate;
  final TimeOfDayValue? toTime;
}

/// Another title or location for this occurrence only.
class EditEventOccurrence extends EventOccurrenceChange {
  const EditEventOccurrence({this.title, this.location});
  final String? title;
  final String? location;
}

abstract interface class EventService {
  Future<CommandResult> create(EventInput input);
  Future<CommandResult> update(String eventId, EventInput input);

  /// Cancels (or un-cancels) the whole event.
  Future<CommandResult> setCancelled(String eventId, {required bool cancelled});
  Future<CommandResult> trash(String eventId);
  Future<CommandResult> restore(String eventId);

  /// Changes one occurrence; null removes an earlier change.
  Future<CommandResult> changeOccurrence(String eventId, LocalDate originalDate, EventOccurrenceChange? change);
  Future<EventDetails?> details(String eventId);
}

abstract interface class CalendarService {
  Future<CommandResult> create(String name, {int color});
  Future<CommandResult> update(String calendarId, {String? name, int? color});

  /// Moves the calendar to the trash; its events stay, without a calendar.
  Future<CommandResult> trash(String calendarId);
  Stream<List<CalendarView>> watchCalendars();
}

/// One occurrence of an event in a range.
class EventItem {
  const EventItem({
    required this.eventId,
    required this.title,
    required this.originalDate,
    required this.start,
    this.end,
    this.location,
    this.calendarId,
    required this.isRepeating,
    this.isCancelled = false,
    this.isMoved = false,
    this.deviceStart,
    this.deviceEnd,
  });
  final String eventId;
  final String title;
  final LocalDate originalDate;
  final SchedulePointInput start;
  final SchedulePointInput? end;
  final String? location;
  final String? calendarId;
  final bool isRepeating;
  final bool isCancelled;
  final bool isMoved;

  /// P03 UX U5: the timed start and end in the DEVICE's zone (Time Kernel),
  /// for the time grid; null when date-only.
  final SchedulePointInput? deviceStart;
  final SchedulePointInput? deviceEnd;

  LocalDate get date => start.date;
  bool get isAllDay => !start.isTimed;
}

/// Two timed items that overlap (owner decision D7: only shown). Keys are
/// `task:<id>@<originalDate>` or `event:<id>@<originalDate>`.
class ConflictView {
  const ConflictView(this.first, this.second);
  final String first;
  final String second;
  @override
  bool operator ==(Object o) => o is ConflictView && o.first == first && o.second == second;
  @override
  int get hashCode => Object.hash(first, second);
  @override
  String toString() => 'ConflictView($first, $second)';
}

String taskOccurrenceKey(String taskId, LocalDate originalDate) => 'task:$taskId@$originalDate';
String eventOccurrenceKey(String eventId, LocalDate originalDate) => 'event:$eventId@$originalDate';

/// Everything the calendar shows for a range: events, scheduled tasks
/// (owner decision D6: tasks stay tasks) and their conflicts.
class CalendarRange {
  const CalendarRange({
    required this.events,
    required this.tasks,
    required this.conflicts,
    this.truncated = false,
  });
  final List<EventItem> events;
  final List<AgendaItem> tasks;
  final List<ConflictView> conflicts;
  final bool truncated;
}

abstract interface class CalendarQueries {
  Stream<CalendarRange> watchRange(LocalDate from, LocalDate to);
}
