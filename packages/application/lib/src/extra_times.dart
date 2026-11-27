// P06c (ADR-0095; the owner's "Add another time"): a time of a task or an
// event outside its rule. An extra time belongs to its item (its title, list,
// colour and reminders), has an id of its own, and is independent of the
// item's schedule: changing the whole repeat leaves it where it is. A task's
// extra time has its own tick.
import 'package:foundation/foundation.dart';

import 'calendar.dart';
import 'command.dart';
import 'planning.dart';

enum ExtraTimeSubject { task, event }

/// The time to give: a start (a day, with or without hours), an optional end,
/// and (ADR-0097) an optional repeat of its own. No deadline.
class ExtraTimeInput {
  const ExtraTimeInput({required this.start, this.end, this.repeat});
  final SchedulePointInput start;
  final SchedulePointInput? end;
  final RepeatInput? repeat;
}

/// An extra time as listed.
class ExtraTimeView {
  const ExtraTimeView({
    required this.id,
    required this.subject,
    required this.subjectId,
    required this.start,
    this.end,
    this.isDone = false,
    this.repeat,
  });
  final String id;
  final ExtraTimeSubject subject;
  final String subjectId;
  final SchedulePointInput start;
  final SchedulePointInput? end;

  /// A task's extra time that was ticked (one that does not repeat; a repeating
  /// one is ticked one time at a time).
  final bool isDone;

  /// Its own repeat, or null for one time.
  final RepeatInput? repeat;
  bool get isRepeating => repeat != null;
}

abstract interface class ExtraTimes {
  /// Gives [subjectId] another time. The command's entity is the task or
  /// the event; the new time's id is in the item's [ExtraTimes.of].
  Future<CommandResult> add(ExtraTimeSubject subject, String subjectId, ExtraTimeInput time);

  /// Moves an extra time to another day and hours.
  Future<CommandResult> change(String extraId, ExtraTimeInput time);

  /// Removes an extra time (it is gone, not hidden).
  Future<CommandResult> remove(String extraId);

  /// Ticks or unticks a task's extra time.
  Future<CommandResult> setDone(String extraId, {required bool done});

  /// One time of a repeating extra time of a task: skipped or moved; null
  /// undoes an earlier change.
  Future<CommandResult> changeTaskOccurrence(String extraId, LocalDate originalDate, OccurrenceChange? change);

  /// The same for an event: skip, cancel, move or rename; null undoes.
  Future<CommandResult> changeEventOccurrence(String extraId, LocalDate originalDate, EventOccurrenceChange? change);

  /// Ticks or unticks one time of a repeating extra time of a task.
  Future<CommandResult> setOccurrenceDone(String extraId, LocalDate originalDate, {required bool done});

  /// The live extra times of an item, by date and time.
  Future<List<ExtraTimeView>> of(ExtraTimeSubject subject, String subjectId);
}
