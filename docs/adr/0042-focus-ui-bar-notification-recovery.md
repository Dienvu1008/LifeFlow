# ADR-0042: Focus in the UI: the focus bar, the pomodoro-end notification and the recovery question

- Status: Accepted (P03 task T6b, 2026-11-11; within the owner-accepted P03 plan, decisions D1–D5, D12). The device check is in the owner's single pass over the P03 screens before T7.
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0038](0038-focus-commands-and-recovery.md) (commands, recovery), [ADR-0034](0034-reminders.md) (the notification adapter), [ADR-0041](0041-habits-ui.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T3 gave the focus commands, the recovery on launch and `FocusSessionView`. T6b shows them: start, the running time, pause, end, cancel, the bar on every screen (D4), the notification when a pomodoro ends (D4), and the question about a session found at start (D1).

## Decision
**Starting** (D3, D12):
- **Where from:** "Focus…" in the menu of an open task (Tasks), or of an open occurrence (Today, Upcoming and the calendar's lists). The occurrence's original date is passed for a repeating task. The timer button in the Tasks bar starts a session without a task.
- **Dialog:** pomodoro (default 25 minutes, 1–240) or stopwatch.
- **One session at a time** (D2): with a session running, starting offers to open it instead.

**Focus page:**
- It shows the task (or "Focus without a task"), the mode, and the time. A pomodoro counts down and shows "Time is up" when its interval is over; a stopwatch counts up.
- Pause / Resume, End and Cancel session (which asks first: nothing is recorded).
- **End** asks "Save" (the one execution record) or "Don't save". The dialog says that saving does not complete the task (D5).

**Focus bar** (D4): under the content and above the navigation, on every screen of both layouts, while a session is running or paused (`AdaptiveScaffold.focusBar`). It shows the time, the task and "paused", with Pause/Resume and End buttons; a tap opens the page. It is a single line that ellipsizes on a phone with a large font. Each figure has a spoken label ("Focus: Write, 19:57. Open"; "12 minutes left").

**The time is derived, the display only ticks.** `FocusTicking` redraws on `focusTickerProvider` (a new one-second stream per display, cancelled with it) with "now" from `focusClockProvider`. The value is computed by `FocusSessionView` from the stored instants (LF-INV-EXEC-002, AP-12). Tests replace both providers, so no timer is left running.

**Pomodoro-end notification** (D4): `DriftReminderPlanner` adds the planned end of the running pomodoro (key `focus:<id>`) to the device plan. The existing adapter therefore delivers it with the app closed, on Windows and Android (ADR-0034).
- A pause removes it, and a resume schedules it again at the moved end, with the same notification id.
- Ending or cancelling removes it. A stopwatch never notifies.
- `ReminderSync` also watches the `focus_sessions` table.

**The question at start** (D1, `FocusLaunchPrompt`, asked once per opened profile from `AppWiring.focusLaunch`):

| Found | Question |
|---|---|
| overdue pomodoro | "Count until it ended" (default), "Count until now", "Discard" |
| running or paused stopwatch | "Resume" or "End now" (then the save question) |
| running pomodoro not over | none: it continues, the bar shows it |
| unrecoverable | explained: kept as stored, nothing recorded, a new session can start |

## Consequences
- The device check (a kill and relaunch on both devices, and the notification with the app closed) is in the owner's pass before T7.
- The optional, unrecorded break after a pomodoro (D3) is not built. Only "Time is up" is shown. It can be added without data changes.
- The list of unrecoverable sessions (`FocusQueries.unrecoverable`) has no screen yet. They are explained once at start.

## Verification
- `packages/ui/test/focus_flow_test.dart` (11 widget tests):
  - pomodoro countdown, pause and resume, the bar on two tabs, "Time is up";
  - a stopwatch without a task; save and don't save; cancel with its question;
  - D2; the length check; no focus on a done task or a done occurrence; a repeating occurrence's date;
  - the D1 questions (three overdue answers with the default, stopwatch resume and end now, a pomodoro without a question, unrecoverable);
  - the bar at a phone width with a large font.
- `packages/infrastructure/test/focus_commands_test.dart`: the pomodoro end in the device plan (a pause moves it, a pause, end or past end removes it, a stopwatch has none), and the reminder sync re-plans when a session starts.
- `apps/lifeflow_app/test/app_integration_test.dart` (real stores): a session started from a task shows in the bar, the device gets the pomodoro end, and saving removes it. The store has one ended session and one record; the task is not done.
- Mutations: 14/14 killed.
