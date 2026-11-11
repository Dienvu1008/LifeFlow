# ADR-0038: Focus commands, recovery on launch and exact session times

- Status: Accepted (P03 task T3, 2026-11-11; within the owner-accepted P03 plan, decisions D1–D5)
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0036](0036-execution-measurement-goal-rules.md) (the focus rules), [ADR-0037](0037-storage-v5-execution-measurement-goals.md) (amended: session instants), [ADR-0011](0011-command-gateway-single-mutation-path.md), [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md), [execution-measurement.md](../domains/execution-measurement.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T1 gave the pure focus machine and T2 the tables. T3 adds the commands that move a session, the recovery when a profile opens, and the proof that a kill at any point loses nothing and records nothing twice (GS-13).

## Decision
**One handler, one transaction per transition.** `FocusCommandHandler` (entity `focusSession`) runs through the gateway like every write, so each transition commits the session row with its audit, outbox, event log and dedupe rows, or nothing (FF-ARCH-06). Ops and command types:

| op | Command | Rule |
|---|---|---|
| start | StartFocusSession | D2: refused while another session of the workspace is running or paused. A pomodoro needs 0 < planned ≤ 4 h (D3). The task, if any, is in this workspace, not in the trash, not done or cancelled. An occurrence date needs a repeating task. |
| pause / resume | Pause/ResumeFocusSession | Only from running / paused. Refused when the clock is before the session start. |
| end | EndFocusSession | `count` gives the one execution record, id `session:<id>` (D5, LF-INV-EXEC-004). An existing record (for example from a restore merge) refuses the end; nothing is kept. `at: plannedEnd` is only for a running pomodoro whose planned end has passed (D1). |
| cancel | CancelFocusSession | No record. |
| markUnrecoverable | MarkFocusSessionUnrecoverable | `untrusted`: only when the domain recovery says so, or the row cannot be read. `superseded`: only when a newer session is active. The row is kept and shown, never deleted (LF-INV-EXEC-003). |

A session never changes its task (D5). Events: FocusSessionStarted, -Paused, -Resumed, -Ended, -Cancelled, -Unrecoverable, ExecutionRecorded.

**"Now" is injected.** The handler and `DriftFocusService` take a `Clock` (system clock by default), so tests drive time and kills.

**Recovery on launch** (`FocusService.recoverOnLaunch`, called by the app's `openSession` after the pending events are dispatched; the result is `AppWiring.focusLaunch`):
- No running or paused session: `NoActiveFocus`.
- Running or paused: `FocusResumed`, as it was; elapsed is derived.
- A running pomodoro past its planned end: `FocusOverdue` with the planned end. The user answers with `resolveOverdue`: count to the planned end (default), count to now, or discard (cancel).
- A session the domain cannot trust, or a row that cannot be read: marked unrecoverable and returned as `FocusUnrecoverable`. It does not block a new start.
- More than one active session (only possible after a restore merge): the newest continues; the others are marked unrecoverable ("another session was active") first, while the newest is still active.

**Exact session instants (amends ADR-0037).** Drift keeps DateTime columns to the whole second here. Each pause and resume would add its own rounding, and several pauses could drift past 1 s (LF-INV-EXEC-002). So `focus_sessions.startedAt`, `pausedAt` and `endedAt` are integer UTC milliseconds. The export format is unchanged (DateTime was already exported as milliseconds). Schema v5 had not reached any device, so no migration is needed. Execution records keep DateTime start and end; their `focusMs` is exact.

**Read side.** `FocusQueries.watchActive()` streams the running or paused session with its task title; `unrecoverable()` lists the kept ones. `FocusSessionView` uses `foundation` types only (FF-ARCH-04). Its derived times (`focusTimeAt`, `remainingAt`, `plannedEndAt`) call the domain rules, so no widget computes them (AP-12).

## Consequences
- T6 shows the focus bar from `watchActive`, asks the overdue question from `AppWiring.focusLaunch`, and lists unrecoverable sessions.
- The pomodoro-end notification (D4) is T6b; it reads `plannedEndAt`.
- A command that throws a storage error inside the transaction still rolls back the whole set, but known conflicts are refused as rule failures first.

## Verification
- `packages/infrastructure/test/focus_commands_test.dart` (17 tests):
  - GS-13: kill at minute 12, relaunch. The session comes back with the elapsed time within 1 s, the pauses kept, one record, and the task untouched.
  - Kill before and after the commit of every step (start, pause, resume, pause, end). The last committed state recovers, within 1 s.
  - D1: the three overdue answers; the planned end is refused early; a paused or not-yet-finished pomodoro continues.
  - D2: a second start is refused; two active sessions after a merge.
  - Unrecoverable kept and shown; a trustworthy session is never marked.
  - Transitions, the subject task rules, an existing record, the clock before the start, the audit and events.
- `atomic_set_test.dart` (FF-ARCH-06): eight focus steps (start, pause, resume, end, pomodoro start, cancel, start, markUnrecoverable).
- `app_integration_test.dart`: `openSession` returns `FocusResumed` for a session a kill left.
- Mutations: 21/21 killed.
