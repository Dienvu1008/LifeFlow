# ADR-0041: Habits in the UI (Habits filter, habit page, period states)

- Status: Accepted (P03 task T6a, 2026-11-11; within the owner-accepted P03 plan, decisions D6–D10, D12); device check by the owner pending
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0039](0039-habits-targets-measurements-period-results.md) (the commands and reads), [ADR-0019](0019-ui-state-management-and-navigation.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T4 gave the habit, target and measurement commands and the tracking reads. T6a puts them in front of the user.

## Decision
**Ports and streams:**
- `HabitQueries` gains `watchTracking(taskId)` and `watchTracked()`. Screens follow changes without being refreshed by hand; both re-read on changes to tasks, schedules, exceptions, completions, measurements and period results.
- UI providers: `habitServiceProvider`, `habitQueriesProvider`, `habitsProvider`, `trackedProvider` (task id → `TrackingView`) and `trackingProvider(taskId)`.
- When the habit ports are not wired (older test setups), the lists still work without period states (`valueOrNull`).

**Habits filter (D12):** the 4th segment of Tasks. Its icons are shown only from 560 logical px, so the four labels fit a phone with a large font.
- Each habit shows its running period ("4000 / 6000 steps · In progress"), "No repeat" when it has none, and "Streak · 30 days · all".
- A tap opens the habit page. A measured habit has a quick "add a measurement" button.
- A task added in this filter becomes a habit that repeats every day from today (D6a). Both can be changed later.

**Habit page** (task menu "Habit and target…", or a tap in Habits). One full-screen page, and every control applies at once as one command:
- **Habit switch.** A habit without a repeat is offered "Every day", which keeps the existing dates.
- **Target** (D7): a dialog with type, minimum and/or maximum, a free-text unit with suggestions, and the aggregation ("each period counts the total / highest / latest / average"). Missing fields are explained in the dialog; the command's own refusals (for example min > max) show as a message. There is also "Remove target".
- **Completion** (D8): "I tick it" or "From measurements", shown only with a target.
- **This period:** value against the goal, its state, and "Add".
- **Statistics:** streak, last 30 days, all time. Each figure is one labelled semantics node.
- **History:** newest first, with outcome, value and "target then" when the target has changed since.
- **Measurements:** history included. Corrected values are struck through, and corrections and withdrawals are marked. Only a current value offers "Correct…" and "Withdraw".

**Measurement entry** (D10): value (digits only), the day it counts for (date picker up to today, never the future), and an optional note. In a closed period the command's `closedPeriodNeedsConfirmation` opens a dialog ("Change a closed period?"). The same call is then repeated with the confirmation (D9).

**Period states in the lists:**
- Task rows (All) and agenda rows (Today, Upcoming, and the calendar's lists, which use the same tile) show the running period of a measured task.
- **Automatic completion** (D8): the checkbox shows the derived state (done when the running period is achieved) and is disabled, labelled "Done from measurements: …" or "Not reached yet: …". Manual habits are ticked as before.
- No rule is computed in a widget; everything comes from `TrackingView` (AP-12).

## Consequences
- Strings are English, like the rest of the app (localization later).
- The monthly calendar grid shows no habit state; the day lists do.

## Verification
- `packages/ui/test/habit_flow_test.dart` (13 widget tests):
  - the Habits filter: list, empty state, quick add, adding a daily habit, a phone width with a large font;
  - the habit switch and the "Every day" offer;
  - the target editor (validation, unit chip, aggregation, between, a refusal, removal) and completion;
  - the closed-period confirmation; a bad value; a past date only;
  - statistics, history, corrections and withdrawals;
  - automatic and manual boxes in Today and All.
- `apps/lifeflow_app/test/app_integration_test.dart` (real stores): a habit made in the Habits filter gets a target, automatic completion and two measurements. The page shows "Achieved", Today's box is derived, and the store has the rows and audit actions.
- UI mutations: 12/13 killed. The survivor is the negative check in the measurement dialog, which cannot be reached: the field accepts only digits, "." and ",". The command refuses negatives anyway (ADR-0039).
- Device check (Windows, Android): pending, by the owner.
