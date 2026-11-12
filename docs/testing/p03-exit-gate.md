# P03 exit-gate evidence (MVP exit)

Maps each line of the P03 definition of done ([definition-of-done.md](definition-of-done.md)) and of the P03 plan ([p03-plan.md](../roadmap/p03-plan.md)) to the tests and checks that prove it. P03 completes the MVP (P01 → P02 → P03).

Status: **headless evidence complete; waiting for the owner's device pass and sign-off.** At the owner's request (2026-11-11), T6a, T6b and T6c were merged before their device checks, so that every P03 screen is checked in one pass (§"Device pass" below).

How to reproduce:
- `dart test` in `packages/foundation|time_kernel|domain|application|infrastructure`.
- `flutter test` in `packages/ui` and `apps/lifeflow_app`.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- CI runs the same on every push (`.github/workflows/ci.yml`).

`main` at the start of T7: `3f447b8` (T6c merged); the navigation drawer (ADR-0044) was merged during the review (`7c20d04`).

## Exit gate (DoD §P03)

| Line | Proof |
|---|---|
| Focus recovery within 1 s and one record per session (GS-13) | `infrastructure/test/focus_commands_test.dart`. **GS-13:** start, pause, resume, kill at minute 12, relaunch; elapsed within 1 s of the true time, pauses kept, the task untouched; after the end, one record, keyed `session:<id>`, and a second end is refused. **Kill at every step:** before and after the commit of start, pause, resume, pause and end, the last committed state recovers within 1 s. Session instants are exact milliseconds (ADR-0038), so pauses never add rounding. Domain: `domain/test/focus_test.dart`, a property over 500 random pause sequences: focus time = wall time − pauses, exactly; a clock jumping back never gives a negative time. App: `app_integration_test.dart` (`openSession` returns the session a kill left). |
| Goal progress derived with no write-back (GS-21) | `domain/test/goals_test.dart`: progress as a pure function, with milestones, tasks and habits; nothing to count gives no progress. `infrastructure/test/goals_test.dart` GS-21: tasks and a habit linked; progress follows their states; the same inputs give the same output; no task row is changed by any goal command or read; the trash keeps every task and a restore brings the links back. App: `app_integration_test.dart` (real stores: a link gives 0 %, a ticked milestone gives 100 %; after the trash the task is unchanged). |
| A measurable habit completes correctly (GS-01), with boundaries (GS-02), and "no data is not zero" on the manual path (GS-05) | **GS-02:** `domain/test/measurement_test.dart`, a 15-case table (inclusive bounds, min = max, open bounds, every type). **GS-01:** `infrastructure/test/habit_tracking_test.dart`, automatic completion achieved exactly at 5000 of 5000, undone by a correction, the status never written, ticks refused, the closed day stored as not achieved with its target. **GS-05 (manual path):** the manual policy shows progress while the tick stays the user's; a day without measurements closes as **no data** (value null, not 0), left out of the rate; the streak ends. App: `app_integration_test.dart` (habit, target, automatic completion and two measurements made in the UI; "Achieved"; Today's box is derived). |

## Invariants

| Invariant | Proof |
|---|---|
| LF-INV-EXEC-001 history kept | `measurement_test.dart` (corrections, chains, withdrawals; the current set leaves out the superseded); `habit_tracking_test.dart` EXEC-001 (a correction is a new row, the old one stays; corrected once; a withdrawal cannot be corrected); GS-20 round trip carries superseded measurements (`execution_storage_test.dart`) |
| LF-INV-EXEC-002 duration accurate within 1 s | `focus_test.dart` (property, clock jumps); `focus_commands_test.dart` (GS-13, kill at every step) |
| LF-INV-EXEC-003 recoverable after a crash | `focus_commands_test.dart` (kill before/after every commit; unrecoverable kept and shown, never dropped; two active sessions after a merge); `app_integration_test.dart` (recovery in `openSession`); UI `focus_flow_test.dart` (the D1 questions) |
| LF-INV-EXEC-004 one record per session | `focus_commands_test.dart` (keyed id; a second end refused; an existing record from a merge refuses the end with nothing kept); export validation of the keyed id (`execution_storage_test.dart`) |
| LF-INV-HEALTH-002 no data ≠ 0 | `measurement_test.dart` (no data for every type; a measured 0 is a value); `habit_tracking_test.dart` (closed as no data, value null, out of the rate) |
| LF-INV-HEALTH-004 provenance (manual path) | `habit_tracking_test.dart` (source `manual`, device and time kept); `app_integration_test.dart` (rows from the UI have `source = manual`) |
| LF-INV-TASK-010 measurable completion derived | `habit_tracking_test.dart` GS-01 (derived; never set by the data; manual ticks refused for automatic); UI `habit_flow_test.dart` (automatic boxes cannot be ticked) |
| LF-INV-GOAL-001 derived progress, no write-back | `goals_test.dart` (domain and infrastructure, GS-21) |
| LF-INV-GOAL-002 deleting keeps the tasks | `infrastructure/test/goals_test.dart`, app integration (trash keeps the task); the UI says so (`goal_flow_test.dart`) |
| LF-INV-GOAL-003 another workspace refused | `infrastructure/test/goals_test.dart` (a task in another workspace cannot be linked; nothing is written) |

All ten also appear in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md).

## Plan items (p03-plan.md §5)

| Task | Proof | ADR |
|---|---|---|
| T1 Domain rules | `focus_test.dart` 13, `measurement_test.dart` 27, `goals_test.dart`, kernel `periods_test.dart` | 0036 |
| T2 Storage v5 | `execution_storage_test.dart` 28: GS-20, schema-4 file, 19 SR-14 refusals, restore into a profile; upgrades from v2–v5 (`profile_directory_test.dart`) | 0037 |
| T3 Focus commands | `focus_commands_test.dart` 19, atomic-set steps | 0038 |
| T4 Targets, measurements, habits | `habit_tracking_test.dart` 18, atomic-set steps; schema v6 `tasks.trackedSince` | 0039 |
| T5 Goals and projects | `infrastructure/test/goals_test.dart` 8, atomic-set steps | 0040 |
| T6a UI habits | `ui/test/habit_flow_test.dart` 13, app integration | 0041 |
| T6b UI focus | `ui/test/focus_flow_test.dart` 11, pomodoro-end notification and sync tests, app integration | 0042 |
| T6c UI goals | `ui/test/goal_flow_test.dart` 8, `shell_test.dart` order, app integration | 0043 |
| Navigation drawer on phones (owner request during the exit review) | `ui/test/shell_test.dart` drawer tests; phone-width flows through the drawer | 0044 |

Mutation checks: each task's key rules were mutated one at a time (T1 13/13, T2 20/20, T3 21/21, T4 30/31, T5 17/17, T6a 12/13, T6b 14/14, T6c 10/10).
- The two survivors are recorded in their ADRs and cannot be killed: one would only remove an optimisation, the other is a UI check that the input field already makes unreachable.
- In T2 the kill detector was found to report false kills, and was fixed. T1 and P02 T7 were re-run with the fixed detector (T1 13/13; P02 T7 two equivalent survivors, behaviour unchanged).

## Fitness functions and governance

| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | `tools/fitness/ff_arch_01_pure_domain.dart` (the new domain files `focus.dart`, `measurement.dart` and `goals.dart` import only `foundation` and `time_kernel`) |
| FF-ARCH-04 UI isolation | `tools/fitness/ff_arch_04_ui_isolation.dart` (the habit, focus and goal screens use application ports and `foundation` types only) |
| FF-ARCH-06 atomic set for the new handlers | `atomic_set_test.dart` with fault injection over every new operation. **Focus:** start, pause, resume, end, cancel, markUnrecoverable. **Task:** setHabit, setTarget, setCompletion. **Measurement:** record, correct, record in a closed period. **Period close.** **Goal:** create, update, the four milestone ops, link, unlink, setStatus, trash, restore. Guard 1 of `ff_arch_06_09.dart` lists `FocusCommandHandler`, `MeasurementCommandHandler`, `PeriodCloseHandler` and `GoalCommandHandler`. |
| FF-ARCH-07 license scan | `ff_arch_07_licenses.dart` + self-test; P03 added no dependency (no `pubspec` change since T1); 125 shipped packages and libraries, all accepted |
| FF-ARCH-09 authorize before domain | `ff_arch_06_09.dart` + `authorization_gate_test.dart` (the single apply site is unchanged; the new handlers run through the same gateway) |
| Single mutation path | every focus, habit, target, measurement, period-result and goal change is a gateway command with audit, outbox and events. A late tick and a re-evaluation of a closed period write their own outbox rows. |
| Export and restore cover the new tables (LF-INV-SEC-010) | `execution_storage_test.dart`: GS-20 round trip with every P03 kind, untrusted rows refused (SR-14), schema 1–5 files restore, restore into the same profile (identical, merge, overwrite with tombstones) |

## Universal DoD

| Line | Status |
|---|---|
| Build passes on Windows and Android; analyze clean | Windows debug build at T6a, T6b and T6c (last on `8ccdca4`); `dart analyze` / `flutter analyze` clean in every package. The Android build and both device runs are part of the owner's device pass. CI does not build for devices (as in P01/P02). |
| Static fitness functions | FF-ARCH-01, 04 and 07 green in CI. FF-ARCH-02, 03 and 05 have no scripts yet, as at the P01 and P02 exits. |
| All phase tests pass | foundation 13, time_kernel 92, domain 61, application 3, infrastructure 299, ui 186, app 25 (local and CI on the T6c branch), plus the FF-ARCH-07 self-test |
| Every P03 invariant has a passing verification row | see "Invariants" above and the matrix |
| New dependencies have a verified license | none added in P03 |
| ADRs for decisions with trade-offs | ADR-0036 (rules; ADR-0006 amended: habit is its own flag), 0037 (schema v5), 0038 (focus commands, exact instants), 0039 (habits, targets, measurements, closed results; schema v6), 0040 (goals), 0041 (habits UI), 0042 (focus UI, notification, recovery), 0043 (goals UI); owner decisions D1–D12 in p03-plan.md |

## Owner decisions applied
D1–D5 and D7–D12 as proposed. D6 revised by the owner (habit, repeat and measurable are three independent properties), with D6a–D6c as proposed. The proofs are listed in the ADRs.

One question is left open for the owner (ADR-0039): under the **manual** policy, a measured period's stored result is the target's judgement (achieved / not achieved / no data), and the tick is the P02 completion. If the tick should be the period's result instead, this is a small change, best made before or with the device pass.

## Device pass (owner, one pass over all P03 screens)
Run on Windows and on Android (`flutter run -d windows …`, `flutter run -d RF8M90JH9JA …`, same `--dart-define` values as before). Each line is a pass/fail; anything found is fixed before sign-off.

**Habits (T6a)**
- [ ] Tasks → Habits → "+" adds "Walk": it appears as a habit that repeats every day.
- [ ] Open it → Set target: at least 6000 steps (unit chip "steps") → "From measurements".
- [ ] Add 4000 and 2500: the period shows "6500 / 6000 steps · Achieved"; in Today the box is ticked and cannot be changed.
- [ ] Correct a value, and withdraw one: both are in the history, struck through or marked.
- [ ] A measurement for a past day whose period has ended asks "Change a closed period?".
- [ ] An unmeasured habit ("Warm water") is ticked in Today. After a day without a tick, its History shows "Missed" (on the next app start).
- [ ] Phone with a large system font: the four filters and the habit page fit.

**Focus (T6b)**
- [ ] "Focus…" on a task → pomodoro 25 min: the page counts down; the bar shows on every tab; pause and resume work.
- [ ] With the app **closed**, the pomodoro-end notification appears at the planned end (Windows and Android).
- [ ] Kill the app during a pomodoro and reopen **before** its end: it continues, with the right time.
- [ ] Kill during a pomodoro and reopen **after** its end: the three choices are offered; "Count until it ended" records the planned length.
- [ ] Kill during a stopwatch and reopen: "Resume" or "End now".
- [ ] End and save: the bar disappears; the task is not completed.
- [ ] Starting a second session offers to open the running one.

**Goals (T6c)**
- [ ] Goals (5th tab; on a phone in the navigation drawer): "+" makes a project with a start and target date.
- [ ] Link a task and a habit; complete the task: the progress changes. Add a milestone: progress counts the milestones.
- [ ] A task's "Goals…" shows the goal ticked; unticking unlinks it.
- [ ] Archive (read only), then unarchive. Move to trash (the task is still in Tasks), then restore from Trash.
- [ ] Phone width: the goal page fits.

**Navigation on a phone (ADR-0044)**
- [ ] No bottom bar; the menu button (or a swipe from the left edge) opens the drawer.
- [ ] The drawer starts with the profile (picture with initials, name, status); a tap opens Profiles.
- [ ] Tasks, Calendar, Goals, Settings switch tabs and close the drawer; the current tab is marked.
- [ ] Windows and a wide window keep the rail with all five destinations.

**Regression (P01/P02 on the same build)**
- [ ] Tasks, subtasks, schedule, Today/Upcoming, Calendar and events, reminders with the app closed, export/restore, profile switch.

## Known limits carried out of P03
- The optional, unrecorded break after a pomodoro (D3) is not built; "Time is up" is shown (ADR-0042).
- There is no screen listing unrecoverable focus sessions; they are explained once at start (ADR-0042).
- An event cannot be linked to a goal from the event editor, only from the goal page (ADR-0043).
- The monthly calendar grid shows no habit state; the day lists do (ADR-0041).
- Periods close when the app starts and before a target change. While the app stays open over midnight, an ended period is shown as derived until the next start (ADR-0039).
- Results are derived at most 1100 days back; the 30-day rate counts results by their key date (ADR-0039).
- Strings are English only (localization later).
- Carried from P02: "this and following" edits of a repeat; the 14-day reminder horizon; no sync between two devices (P04).

## Risks
- **R-DATA-LOSS (focus recovery):** mitigated and validated headless (GS-13 kill at every step, exact instants); the device kill checks are in the device pass.
- **R-SCOPE:** P03 stayed inside ADR-0005 and decisions D1–D12. Hybrid completion and health sources stay with P08, AI with P06, sharing with P04.
- **R-WINDOWS-ANDROID / R-BACKGROUND:** the pomodoro-end notification reuses the P02 adapter, which already passed S-05 and the P02 T7 checks on both platforms. It is re-checked in the device pass.
- New: **R-UNCHECKED-UI**: three UI tasks merged before their device checks (owner's choice, to check them together). Mitigation: the device pass above blocks the P03 sign-off.

## Owner sign-off
- [ ] Device pass done on Windows and Android, and fixes merged.
- [ ] Open question (manual policy and period results, ADR-0039) answered.
- [ ] CI green on the T7 branch.
- [ ] Owner approves P03 as done, which closes the MVP.
