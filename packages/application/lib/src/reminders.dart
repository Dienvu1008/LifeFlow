// P02 T7 (ADR-0034): reminders as the UI and the app see them. A reminder
// is a capability of its task or event (planning-scheduling.md §10). The
// device scheduling is behind [ReminderScheduler]; the app supplies the
// platform adapter. `foundation` types only (FF-ARCH-04).
import 'package:foundation/foundation.dart';

import 'command.dart';

sealed class ReminderInput {
  const ReminderInput();
}

/// [minutes] before the start (or the deadline, or the end) of each
/// occurrence. For an all-day item: before the all-day reminder time.
class RemindMinutesBefore extends ReminderInput {
  const RemindMinutesBefore(this.minutes);
  final int minutes;
  @override
  bool operator ==(Object o) => o is RemindMinutesBefore && o.minutes == minutes;
  @override
  int get hashCode => minutes.hashCode;
}

/// Once, at [at].
class RemindAtInstant extends ReminderInput {
  RemindAtInstant(this.at);
  final Instant at;
  @override
  bool operator ==(Object o) => o is RemindAtInstant && o.at.millis == at.millis;
  @override
  int get hashCode => at.millis.hashCode;
}

enum ReminderSubject { task, event }

/// An all-day (date-only) item reminds relative to this time of its day,
/// in the device zone (ADR-0034): 09:00.
const allDayReminderMinuteOfDay = 9 * 60;

/// Reminders are scheduled this far ahead each time the app runs.
const reminderHorizonDays = 14;

/// Reminders of tasks and events. Every change is a command on the task or
/// event (its version moves); failures are returned, never thrown.
abstract interface class ReminderService {
  /// Replaces the reminders of the item with [reminders] (empty = none).
  Future<CommandResult> setReminders(ReminderSubject subject, String id, List<ReminderInput> reminders);

  Future<List<ReminderInput>> remindersOf(ReminderSubject subject, String id);
}

/// One notification the device should show.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.key,
    required this.at,
    required this.title,
    required this.body,
  });

  /// Platform notification id (stable for the same [key]).
  final int id;

  /// `task:<id>#<n>@<date>`-style identity of the reminder.
  final String key;
  final Instant at;
  final String title;
  final String body;

  @override
  bool operator ==(Object o) =>
      o is PlannedReminder && o.id == id && o.key == key && o.at.millis == at.millis && o.title == title && o.body == body;
  @override
  int get hashCode => Object.hash(id, key, at.millis, title, body);
  @override
  String toString() => 'PlannedReminder($id, $key, ${at.utc.toIso8601String()}, $title)';
}

/// What the device allows.
class ReminderStatus {
  const ReminderStatus({required this.supported, required this.allowed, this.exactAllowed, this.canAsk = true});

  /// This platform can show scheduled notifications at all.
  final bool supported;

  /// The user allows LifeFlow's notifications.
  final bool allowed;

  /// Android: reminders at the exact minute (null where it does not apply).
  /// Without it, Android may deliver a reminder some minutes late.
  final bool? exactAllowed;

  /// The app can turn notifications on by asking ([ReminderScheduler.
  /// requestPermission]). False when only the user can, in the system
  /// settings (Windows: they turned LifeFlow off there).
  final bool canAsk;
}

/// The device's scheduled notifications (adapter in the app).
abstract interface class ReminderScheduler {
  /// Makes the pending reminders exactly [planned] (cancels the others).
  Future<void> sync(List<PlannedReminder> planned);

  Future<ReminderStatus> status();

  /// Asks the user to allow notifications. Returns whether they are allowed.
  Future<bool> requestPermission();

  /// Android: opens the setting for exact reminders.
  Future<void> requestExact();
}
