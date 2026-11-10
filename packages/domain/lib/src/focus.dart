// P03 T1 (ADR-0036): focus sessions (execution-measurement.md §3/§5,
// owner decisions D1–D5). Pure: the caller passes the current instant.
//
// Time is never counted by a ticker. The focus time is derived from
// instants: (end or now) - start - paused time (LF-INV-EXEC-002,
// FR-FOCUS-04). A clock that jumps backwards never gives a negative time.
import 'package:foundation/foundation.dart';

enum FocusMode { pomodoro, stopwatch }

enum FocusState { running, paused, ended, cancelled, unrecoverable }

/// The longest pomodoro interval accepted.
const maxPomodoro = Duration(hours: 4);

/// The default pomodoro interval (D3).
const defaultPomodoro = Duration(minutes: 25);

class FocusSession {
  const FocusSession({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.state,
    this.taskId,
    this.occurrenceDate,
    this.planned,
    this.pausedTotal = Duration.zero,
    this.pausedAt,
    this.endedAt,
  });

  final String id;
  final FocusMode mode;
  final Instant startedAt;
  final FocusState state;

  /// The task worked on (D5: a session can be without a task).
  final String? taskId;

  /// For a repeating task: the occurrence (original date) worked on.
  final LocalDate? occurrenceDate;

  /// Pomodoro only: the planned interval.
  final Duration? planned;

  /// Time spent paused in pauses that have ended.
  final Duration pausedTotal;

  /// When the current pause began (state paused).
  final Instant? pausedAt;

  /// When the session ended or was cancelled.
  final Instant? endedAt;

  bool get isActive => state == FocusState.running || state == FocusState.paused;

  FocusSession _copy({FocusState? state, Duration? pausedTotal, Instant? pausedAt, bool clearPause = false, Instant? endedAt}) =>
      FocusSession(
        id: id,
        mode: mode,
        startedAt: startedAt,
        state: state ?? this.state,
        taskId: taskId,
        occurrenceDate: occurrenceDate,
        planned: planned,
        pausedTotal: pausedTotal ?? this.pausedTotal,
        pausedAt: clearPause ? null : (pausedAt ?? this.pausedAt),
        endedAt: endedAt ?? this.endedAt,
      );
}

/// The duration from [a] to [b], never negative (a clock may go back).
Duration _since(Instant a, Instant b) {
  final d = b.utc.difference(a.utc);
  return d.isNegative ? Duration.zero : d;
}

enum FocusError {
  notRunning,
  notPaused,
  notActive,
  plannedRequired,
  plannedOutOfRange,
  plannedOnlyForPomodoro,
  endBeforeStart,
}

/// What a counted session leaves behind: one execution record (D5).
class ExecutionRecordDraft {
  const ExecutionRecordDraft({
    required this.sessionId,
    required this.actualStart,
    required this.actualEnd,
    required this.focusTime,
    this.taskId,
    this.occurrenceDate,
  });
  final String sessionId;
  final Instant actualStart;
  final Instant actualEnd;

  /// Time focused, without the pauses.
  final Duration focusTime;
  final String? taskId;
  final LocalDate? occurrenceDate;
}

/// How a session found on start is brought back (D1).
sealed class Recovery {
  const Recovery();
}

/// Running or paused, as it was: continue (elapsed derived).
class ResumeAsItWas extends Recovery {
  const ResumeAsItWas(this.session);
  final FocusSession session;
}

/// A running pomodoro whose planned end passed while the app was closed:
/// ask "count until the planned end" (default), "count until now" or
/// "discard".
class AskPomodoroOverdue extends Recovery {
  const AskPomodoroOverdue(this.session, this.plannedEnd);
  final FocusSession session;
  final Instant plannedEnd;
}

/// The stored session cannot be trusted (for example it ends before it
/// starts): keep it as unrecoverable and show it; never drop it silently
/// (LF-INV-EXEC-003).
class Unrecoverable extends Recovery {
  const Unrecoverable(this.session, this.reason);
  final FocusSession session;
  final String reason;
}

class FocusSessionMachine {
  const FocusSessionMachine._();

  static Result<FocusSession, FocusError> start({
    required String id,
    required FocusMode mode,
    required Instant now,
    Duration? planned,
    String? taskId,
    LocalDate? occurrenceDate,
  }) {
    if (mode == FocusMode.pomodoro) {
      if (planned == null) return const Err(FocusError.plannedRequired);
      if (planned <= Duration.zero || planned > maxPomodoro) return const Err(FocusError.plannedOutOfRange);
    } else if (planned != null) {
      return const Err(FocusError.plannedOnlyForPomodoro);
    }
    return Ok(FocusSession(
      id: id,
      mode: mode,
      startedAt: now,
      state: FocusState.running,
      planned: planned,
      taskId: taskId,
      occurrenceDate: occurrenceDate,
    ));
  }

  static Result<FocusSession, FocusError> pause(FocusSession s, Instant now) {
    if (s.state != FocusState.running) return const Err(FocusError.notRunning);
    return Ok(s._copy(state: FocusState.paused, pausedAt: now));
  }

  static Result<FocusSession, FocusError> resume(FocusSession s, Instant now) {
    if (s.state != FocusState.paused) return const Err(FocusError.notPaused);
    return Ok(s._copy(
        state: FocusState.running, pausedTotal: s.pausedTotal + _since(s.pausedAt ?? now, now), clearPause: true));
  }

  /// Time spent paused up to [at], including a pause still going on.
  static Duration pausedUntil(FocusSession s, Instant at) {
    final current = s.state == FocusState.paused && s.pausedAt != null ? _since(s.pausedAt!, at) : Duration.zero;
    return s.pausedTotal + current;
  }

  /// Focus time up to [now] (or up to the end of an ended session).
  static Duration focusTime(FocusSession s, Instant now) {
    final until = s.endedAt ?? now;
    final total = _since(s.startedAt, until) - pausedUntil(s, until);
    return total.isNegative ? Duration.zero : total;
  }

  /// Pomodoro: when the planned interval is over, counting pauses so far.
  static Instant? plannedEnd(FocusSession s, Instant now) {
    final p = s.planned;
    if (s.mode != FocusMode.pomodoro || p == null) return null;
    return Instant(s.startedAt.utc.add(p + pausedUntil(s, now)));
  }

  /// Pomodoro: time left (never negative).
  static Duration? remaining(FocusSession s, Instant now) {
    final p = s.planned;
    if (s.mode != FocusMode.pomodoro || p == null) return null;
    final left = p - focusTime(s, now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Ends at [at] (now, or the planned end when recovering, D1). With
  /// [count], gives the one execution record of the session (D5). A paused
  /// session ends at [at] with the pause counted as paused.
  static Result<(FocusSession, ExecutionRecordDraft?), FocusError> end(FocusSession s, Instant at,
      {required bool count}) {
    if (!s.isActive) return const Err(FocusError.notActive);
    if (at.utc.isBefore(s.startedAt.utc)) return const Err(FocusError.endBeforeStart);
    final paused = pausedUntil(s, at);
    final ended = s._copy(state: FocusState.ended, pausedTotal: paused, clearPause: true, endedAt: at);
    if (!count) return Ok((ended, null));
    return Ok((
      ended,
      ExecutionRecordDraft(
        sessionId: s.id,
        actualStart: s.startedAt,
        actualEnd: at,
        focusTime: focusTime(ended, at),
        taskId: s.taskId,
        occurrenceDate: s.occurrenceDate,
      ),
    ));
  }

  static Result<FocusSession, FocusError> cancel(FocusSession s, Instant now) {
    if (!s.isActive) return const Err(FocusError.notActive);
    return Ok(s._copy(state: FocusState.cancelled, endedAt: now, clearPause: true));
  }

  /// What to do with an active session found on start (D1).
  static Recovery recover(FocusSession s, Instant now) {
    final problem = _problem(s);
    if (problem != null) return Unrecoverable(s, problem);
    if (s.state == FocusState.running && s.mode == FocusMode.pomodoro) {
      final end = plannedEnd(s, now)!;
      if (!end.utc.isAfter(now.utc)) return AskPomodoroOverdue(s, end);
    }
    return ResumeAsItWas(s);
  }

  static String? _problem(FocusSession s) {
    if (!s.isActive) return 'the session is not active';
    if (s.pausedTotal.isNegative) return 'negative paused time';
    if (s.state == FocusState.paused && s.pausedAt == null) return 'paused without a pause time';
    if (s.pausedAt != null && s.pausedAt!.utc.isBefore(s.startedAt.utc)) return 'paused before it started';
    if (s.mode == FocusMode.pomodoro && (s.planned == null || s.planned! <= Duration.zero)) {
      return 'a pomodoro without a planned interval';
    }
    return null;
  }
}
