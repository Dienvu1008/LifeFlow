# ADR-0039: Habits, targets, measurements and closed periods (schema v6)

- Status: Accepted (P03 task T4, 2026-11-11; within the owner-accepted P03 plan, decisions D6–D10)
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0036](0036-execution-measurement-goal-rules.md) (the rules), [ADR-0037](0037-storage-v5-execution-measurement-goals.md) (the tables), [ADR-0006](0006-habit-is-a-task-capability.md) (amended by ADR-0036), [ADR-0011](0011-command-gateway-single-mutation-path.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T1 gave the pure rules (aggregate, evaluate, periods, outcomes, rate, streak) and T2 the tables. T4 lets the user mark a habit, set a target and a completion policy, and record and correct measurements. It also stores each ended period's result, so history and statistics do not change when the target changes (D9).

## Decision
**Ports** (`application/habits.dart`, `foundation` types only): `HabitService` and `HabitQueries`, kept separate from `TaskService` so the existing UI fakes stay valid. The read model is `TrackingView`. It holds the target, the policy, the tracking start, the running period, the results (newest first), the measurements with their history, the 30-day and all-time rate, the streak and `isCompleteNow`.

**Commands** (all through the gateway, FF-ARCH-06):

| Command | Handler / op | Rule |
|---|---|---|
| SetTaskHabit | task / setHabit | D6: a flag of its own. |
| SetTaskTarget, ClearTaskTarget | task / setTarget | D7 validation: only the bounds the type uses are kept. Clearing makes the completion manual. The service closes the ended periods first (D9). |
| SetTaskCompletion | task / setCompletion | manual or automatic. Automatic needs a target. Hybrid is refused until P08. |
| RecordMeasurement | measurement / record | Value ≥ 0, a date not in the future (back-dating allowed), a task with a target. Provenance is kept: `source = manual` plus the device (LF-INV-HEALTH-004). |
| CorrectMeasurement, WithdrawMeasurement | measurement / correct | A new row that supersedes the old one, which stays (LF-INV-EXEC-001). The date is the old one's (D10). A measurement can be corrected once; a withdrawal cannot be corrected. |
| ClosePeriod | periodResult / close | Stores an ended period's result. The outcome is derived in the handler from the stored rows, never taken from the caller. It is refused when the period is not over or already stored. |

**Automatic completion is derived** (D8, LF-INV-TASK-010, GS-01):
- With automatic, ticking is refused: `complete`, and `setOccurrenceDone` for a repeating task.
- `isCompleteNow` is the current period's state, computed on every read.
- The task status is never written by the data.

**Closed periods** (D9):
- **Change in a closed period:** a measurement whose period has ended is refused with `closedPeriodNeedsConfirmation` unless confirmed. Once confirmed, the stored result is re-evaluated with the target it was stored with. A new version and an outbox row are written only when the outcome or the value changes.
- **Late tick:** ticking or unticking an unmeasured habit's occurrence after its result was stored changes it between done and missed (D6c), recorded the same way. A one-off habit's completion and reopening do the same.
- **When periods close:** results are written on app start (`openSession`) and before a target change. Reads derive the same outcome for an ended period that is not stored yet, so the screen never waits for a close.

**What gets results:**
- **Measured tasks** (habit or not): one result per ended period, with the aggregate and a JSON copy of the target. A period whose occurrences were all skipped or cancelled gets none.
- **Unmeasured habits:** one result per ended occurrence (done / missed). A one-off habit has one result, keyed `once`.
- **Plain repeating tasks** get none (D6b).

**Tracking start (schema v6):**
- `tasks.trackedSince` is the device's date when the task first became a habit or got a target. It is cleared when it is neither.
- Only periods ending on or after it get a result, so marking an old task as a habit does not invent months of "missed".
- Older rows without it fall back to the task's creation date. Results are derived at most 1100 days back.
- Upgrade: `from < 6` adds the column. Export files from schema 1–5 get `trackedSince: null`. An untrusted file with a bad date is refused (SR-14).

**"Today"** is the device's date in its zone (`DeviceTime`), carried in the command payload; the store never guesses a zone.

**Statistics:**
- The 30-day rate counts results whose key (the period's first day or the occurrence date) is within the last 30 days.
- The streak puts the open period(s) first: a success there counts, and an open period that has not succeeded yet is skipped.

## Consequences
- T6 shows the Habits filter (`watchHabits`), the tracking screen, the confirmation for closed periods, and the derived checkbox for automatic tasks. The agenda's checkbox for automatic tasks is wired in T6 from `TrackingView`.
- For a measured task under the **manual** policy, the stored result is still the target's judgement (achieved / not achieved / no data). The tick stays the P02 completion of the task or occurrence.
- Closing writes one command per ended period, each audited. A daily habit adds one small command per day.

## Verification
- `packages/infrastructure/test/habit_tracking_test.dart` (18 tests):
  - GS-01 and GS-05;
  - EXEC-001 (history, withdrawal, provenance); HEALTH-002 (no data, rate, streak);
  - D9: target change, confirmation, re-evaluation with the stored target, a no-op change, idempotent and never-early close;
  - D6c: per-occurrence ticks, late tick and untick, one-off habit, no results for a plain repeat, no invented past;
  - skipped occurrences; weekly periods; the 30-day rate; target and policy rules; `watchHabits`.
- `atomic_set_test.dart`: eight new steps.
- `execution_storage_test.dart`: a bad tracking start is refused.
- `profile_directory_test.dart`: upgrades from v2–v5.
- `app_integration_test.dart`: `openSession` closes a habit's ended days.
- Mutations: 30/31 killed. The survivor is equivalent: without the "already stored" skip in `closePeriods`, the close command is refused and writes nothing.

- **Amended by [ADR-0050](0050-navigation-habits-and-manual-results.md) (2026-11-13, U-D13):** for a measured task under the manual policy, the profile chooses the stored result: the target's judgement (default) or the tick.
