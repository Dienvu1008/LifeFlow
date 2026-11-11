// P03 T3 (ADR-0038): focus sessions as the UI and the app see them
// (execution-measurement.md §3, owner decisions D1–D5). The read model uses
// `foundation` types only (FF-ARCH-04); the derived times come from the
// domain rules, never from a widget (AP-12).
import 'package:domain/domain.dart' as d;
import 'package:foundation/foundation.dart';

import 'command.dart';

enum FocusSessionMode { pomodoro, stopwatch }

enum FocusSessionStatus { running, paused, ended, cancelled, unrecoverable }

/// The default pomodoro interval (D3).
const defaultPomodoroInterval = d.defaultPomodoro;

/// The longest pomodoro interval accepted.
const maxPomodoroInterval = d.maxPomodoro;

/// One focus session. Times are UTC instants, stored to the whole second.
class FocusSessionView {
  const FocusSessionView({
    required this.id,
    required this.mode,
    required this.status,
    required this.startedAt,
    this.taskId,
    this.taskTitle,
    this.occurrenceDate,
    this.planned,
    this.pausedTotal = Duration.zero,
    this.pausedAt,
    this.endedAt,
  });

  final String id;
  final FocusSessionMode mode;
  final FocusSessionStatus status;
  final Instant startedAt;
  final String? taskId;

  /// The task's title when the task still exists.
  final String? taskTitle;
  final LocalDate? occurrenceDate;

  /// Pomodoro only.
  final Duration? planned;

  /// Time paused in pauses that have ended.
  final Duration pausedTotal;

  /// When the current pause began (paused only).
  final Instant? pausedAt;
  final Instant? endedAt;

  bool get isActive => status == FocusSessionStatus.running || status == FocusSessionStatus.paused;

  d.FocusSession get _domain => d.FocusSession(
        id: id,
        mode: d.FocusMode.values.byName(mode.name),
        startedAt: startedAt,
        state: d.FocusState.values.byName(status.name),
        taskId: taskId,
        occurrenceDate: occurrenceDate,
        planned: planned,
        pausedTotal: pausedTotal,
        pausedAt: pausedAt,
        endedAt: endedAt,
      );

  /// Time focused up to [now], without the pauses (LF-INV-EXEC-002).
  Duration focusTimeAt(Instant now) => d.FocusSessionMachine.focusTime(_domain, now);

  /// Pomodoro: time left at [now], never negative.
  Duration? remainingAt(Instant now) => d.FocusSessionMachine.remaining(_domain, now);

  /// Pomodoro: when the interval is over, counting the pauses so far.
  Instant? plannedEndAt(Instant now) => d.FocusSessionMachine.plannedEnd(_domain, now);

  @override
  String toString() => 'FocusSessionView($id, ${mode.name}, ${status.name})';
}

/// What was found when the profile opened (D1).
sealed class FocusLaunch {
  const FocusLaunch();
}

/// No session was running or paused.
class NoActiveFocus extends FocusLaunch {
  const NoActiveFocus();
}

/// A running or paused session continues as it was.
class FocusResumed extends FocusLaunch {
  const FocusResumed(this.session);
  final FocusSessionView session;
}

/// A running pomodoro whose planned end passed while the app was closed.
/// The user chooses with [FocusService.resolveOverdue].
class FocusOverdue extends FocusLaunch {
  const FocusOverdue(this.session, this.plannedEnd);
  final FocusSessionView session;
  final Instant plannedEnd;
}

/// The stored session could not be trusted. It is kept as unrecoverable
/// and shown, never dropped (LF-INV-EXEC-003).
class FocusUnrecoverable extends FocusLaunch {
  const FocusUnrecoverable(this.session, this.reason);
  final FocusSessionView session;
  final String reason;
}

/// The choices for an overdue pomodoro (D1). The default is
/// [countToPlannedEnd].
enum OverdueChoice { countToPlannedEnd, countToNow, discard }

/// Focus commands. Every change is one command on the session (audit,
/// outbox, events); failures are returned, never thrown.
abstract interface class FocusService {
  /// Starts a session. Only one session can be running or paused (D2).
  /// A pomodoro needs [planned] (0 < planned ≤ 4 h); a stopwatch has none.
  /// [occurrenceDate] (the original date) is for a repeating task.
  Future<CommandResult> start({
    required FocusSessionMode mode,
    Duration? planned,
    String? taskId,
    LocalDate? occurrenceDate,
  });

  Future<CommandResult> pause(String id);

  Future<CommandResult> resume(String id);

  /// Ends now. With [count], the session leaves its one execution record
  /// (D5, LF-INV-EXEC-004). The task is never completed by a session.
  Future<CommandResult> end(String id, {required bool count});

  /// Stops without a record.
  Future<CommandResult> cancel(String id);

  /// Brings back the active session when the profile opens (D1). A session
  /// that cannot be trusted is marked unrecoverable here.
  Future<FocusLaunch> recoverOnLaunch();

  /// Settles an overdue pomodoro ([FocusOverdue]).
  Future<CommandResult> resolveOverdue(String id, OverdueChoice choice);
}

abstract interface class FocusQueries {
  /// The running or paused session, or null.
  Stream<FocusSessionView?> watchActive();

  /// Sessions kept as unrecoverable, newest first.
  Future<List<FocusSessionView>> unrecoverable();
}
