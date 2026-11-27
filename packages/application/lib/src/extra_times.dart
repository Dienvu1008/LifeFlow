// P06c (ADR-0095; the owner's "Add another time"): a time of a task or an
// event outside its rule. An extra time belongs to its item (its title, list,
// colour and reminders), has an id of its own, and is independent of the
// item's schedule: changing the whole repeat leaves it where it is. A task's
// extra time has its own tick.
import 'command.dart';
import 'planning.dart';

enum ExtraTimeSubject { task, event }

/// The time to give: a start (a day, with or without hours) and an optional
/// end. No repeat, no deadline.
class ExtraTimeInput {
  const ExtraTimeInput({required this.start, this.end});
  final SchedulePointInput start;
  final SchedulePointInput? end;
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
  });
  final String id;
  final ExtraTimeSubject subject;
  final String subjectId;
  final SchedulePointInput start;
  final SchedulePointInput? end;

  /// A task's extra time that was ticked.
  final bool isDone;
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

  /// The live extra times of an item, by date and time.
  Future<List<ExtraTimeView>> of(ExtraTimeSubject subject, String subjectId);
}
