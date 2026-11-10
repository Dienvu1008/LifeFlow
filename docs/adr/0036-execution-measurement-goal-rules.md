# ADR-0036: Focus, measurement, habit and goal rules (P03 domain)

- Status: Accepted (P03 task T1, 2026-11-10; within the owner-accepted P03 plan, decisions D1–D12, D6 revised by the owner)
- Date: 2026-11-10
- Deciders: Project owner (plan), implementation
- Related: [execution-measurement.md](../domains/execution-measurement.md), [goals-projects.md](../domains/goals-projects.md), [ADR-0006](0006-habit-is-a-task-capability.md) (amended), [ADR-0028](0028-time-types-and-dst-resolution.md), [p03-plan.md](../roadmap/p03-plan.md)

## Decision
All rules below are pure Dart in `packages/domain` (and one kernel function). They have no storage and no clock: the caller passes the current instant or today's date.

**Focus sessions** (`focus.dart`, D1–D5):
- **Time:**
  - Focus time is derived as (end or now) − start − pauses, never counted by a ticker (LF-INV-EXEC-002).
  - A clock that jumps backwards never gives a negative time. An end before the start is refused (UC-17 E1).
- **Modes:**
  - A pomodoro needs a planned interval (0 < p ≤ 4 h; default 25 min). A stopwatch has none.
  - A pomodoro's planned end moves with its pauses.
- **End and cancel:**
  - Ending with "count" gives exactly one execution-record draft (start, end, focus time without pauses, task and occurrence if any).
  - A second end, or an end after a cancel, is refused (LF-INV-EXEC-004 at the domain level; the store keys it by session id in T3).
  - A session never completes a task.
- **Recovery** (D1, LF-INV-EXEC-003):
  - A stored running or paused session comes back as it was.
  - A running pomodoro whose planned end has passed asks: count to the planned end, count to now, or discard.
  - A stored session that cannot be trusted is `unrecoverable`, kept and shown.

**Targets** (`task.dart`, D7):
- `MeasurableTarget` gains `aggregation` (sum by default, max, latest, average).
- Validation:
  - atLeast needs min, atMost needs max, about needs both with min ≤ max;
  - bounds are finite and ≥ 0;
  - the unit is free text, not empty, at most 40 characters.
- `Task.isHabit` is the habit flag (D6, ADR-0006 amendment).

**Measurements and evaluation** (`measurement.dart`, D8–D10):
- **Values:** finite and ≥ 0. Each measurement keeps its source and device (LF-INV-HEALTH-004).
- **Corrections:**
  - A correction is a new measurement that supersedes the old one; a correction can also withdraw a value.
  - The current set leaves out superseded and withdrawn measurements. History is never changed (LF-INV-EXEC-001).
- **Aggregate:** over the current measurements of a period. **No current measurement = no data**: a null aggregate, never 0 (LF-INV-HEALTH-002). A measured 0 is a value.
- **Evaluation** (D8, bounds inclusive, GS-02):
  - atLeast is achieved as soon as the aggregate reaches min, otherwise not achieved once the period has ended.
  - atMost and about are judged only after the period has ended.
  - The state is recomputed from the measurements each time, never set by them (GS-01, LF-INV-TASK-010).

**Periods** (D6):
- **Repeating task:** the period is the rule's own unit, from the new kernel function `rulePeriodOf`:
  - daily = each day; every N days = N-day cycles from the start;
  - weekly = the week by the series' week start (P02 D3); every N weeks = N-week blocks;
  - monthly = from the start's day of the month to the day before it a month later, clamped at month ends; yearly likewise.

  The period's identity is its first day. Several occurrences can share one weekly period.
- **Non-repeating task:** one period with all its measurements. It ends after the task's last planned date (end, else deadline, else start), or never without a date.

**Habit tracking** (D6b/D6c):
- **Outcomes:** an unmeasured habit's occurrence is done when ticked, missed when its period ended unticked, and open otherwise. A measured period ends as achieved, not achieved or no data.
- **Completion rate:** successes / judged outcomes; "no data" counts neither way.
- **Current streak:** consecutive successes counted back from the newest. The open period is skipped, and a success in it counts. A miss or "no data" ends the streak (a streak needs proof; "no data" is still not a failure in the rate).

**Goal progress** (`goals.dart`, D11; LF-INV-GOAL-001):
- A pure function of the linked items' states.
- With milestones: done milestones / all milestones, completed by hand.
- Without milestones: linked tasks count 0 or 1, linked habits their rate since they were linked. Trashed or cancelled tasks, habits without an ended period, and events do not count.
- Nothing to count = no progress yet (not 0 %).

## Consequences
- Pro: every rule of the P03 exit gate is testable without a device or a store; T3–T5 only persist and wire them.
- Pro: periods come from the same tested recurrence engine as P02's occurrences, so habit results and calendar occurrences never disagree.
- Con: a monthly repeat "on the 15th" counts from the 15th to the 14th of the next month, not by calendar month. This is the engine's existing monthly period; it matches "each month" for a repeat on the 1st.
- Con: a streak ends on "no data". This is a choice; it can change without touching stored data, because streaks are derived.

## Verification
- `packages/domain/test/focus_test.dart` (13):
  - start rules (D3); pauses and the planned end;
  - a clock jumping back;
  - property: focus time = wall time − pauses, exactly, over 500 random sequences;
  - one record and a refused second end; cancel; ending while paused; an end before the start;
  - recovery: overdue pomodoro, planned end with pauses, a paused session, stopwatch, unrecoverable;
  - kill after any step gives the same time.
- `packages/domain/test/measurement_test.dart` (27):
  - D7 validation;
  - GS-02 table (15 boundary cases);
  - no data for every type; a measured 0 is a value;
  - aggregations; corrections, chains and withdrawals with history kept;
  - GS-01 (achieved exactly at 5000, undone by a correction, not achieved after the day);
  - periods of repeating and one-off tasks;
  - outcomes, rate and streak.
- `packages/domain/test/goals_test.dart` (4): milestones; links with exclusions; nothing to count; GS-21 purity.
- `packages/time_kernel/test/periods_test.dart` (5):
  - daily, N days, weekly with several weekdays and both week starts, N weeks, monthly and yearly with month ends;
  - before the first period and after the series end;
  - property over 300 random rules: periods tile the calendar with no gaps, and every rule date is inside its period.
- Mutations (13, all killed): atLeast boundary, about upper bound, no data turned into a failure, corrections ignored, no data judged in the rate, the open period breaking a streak, pauses not subtracted, negative times, the overdue question, a second end allowed, trashed tasks counted, atLeast without a minimum, period end off by one day.
