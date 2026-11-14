# P03 plan: Execution, Goals & Focus (MVP exit)

- Status: **Accepted by the owner 2026-11-10** (D1–D5 and D7–D12 as proposed; D6 revised by the owner; D6a–D6c as proposed)
- **Done (owner sign-off 2026-11-14): [p03-exit-gate.md](../testing/p03-exit-gate.md). The MVP is complete.**
- Follow-up (2026-11-11): UI foundation, Overview, Timeline and Calendar before the P03 exit: [p03-ux-plan.md](p03-ux-plan.md).
- Date: 2026-11-10
- Inputs: [definition-of-done.md §P03](../testing/definition-of-done.md), [phase-breakdown.md](phase-breakdown.md) (P03 = end of the MVP), [execution-measurement.md](../domains/execution-measurement.md), [goals-projects.md](../domains/goals-projects.md), [task-management.md](../domains/task-management.md), ADR-0005 (Goals/Projects in MVP), ADR-0006 (Habit = Task capability), ADR-0009, ADR-0011/0014, ADR-0025, ADR-0029/0030, invariant catalog (EXEC, GOAL, HEALTH-002/004, TASK-010), GS-01/02/05/13/21, FR-EXEC-01..05, FR-FOCUS-01..08, FR-HAB-01..10, FR-GOAL-01..06, UC-02/03/17/21
- Estimate (effort-estimation.md): 15–30 person-days

## 1. Goal and exit gate
Record what was actually done (focus sessions, execution records, measurements), evaluate measurable habits, and track goals and projects with derived progress. This completes the MVP (P01 → P02 → P03).

Exit gate (DoD §P03):
- Focus recovery within 1 s and one record per session (GS-13).
- Goal progress derived with no write-back (GS-21).
- A measurable habit completes correctly (GS-01), with boundaries (GS-02) and "no data is not zero" for manual entries (GS-05, manual path).

Invariants enforced and tested: LF-INV-EXEC-001/002/003/004, LF-INV-HEALTH-002/004 (manual path), LF-INV-TASK-010, LF-INV-GOAL-001/002/003. Fitness functions: the static set plus FF-ARCH-06/07/09 for the new handlers and dependencies.

Out of scope: health-sourced measurements and hybrid completion (P08), AI analytics (P06), shared goals (P04), "this and following" recurring edits (see D11).

## 2. Starting point (checked in code)
- `packages/domain/lib/src/task.dart` has `MeasurableTarget {type: atLeast|atMost|about, min?, max?, unit}` and `CompletionPolicy {manual, automatic, hybrid}`. **No `aggregation` and no `period`**, both required by task-management.md and FR-HAB-03. No unit rules.
- Table `tasks` has `targetType`, `targetMin`, `targetMax`, `unit` and `completionPolicy` (default manual). They are exported and restored, but **no command, query or screen sets, reads or shows them**.
- No FocusSession, ExecutionRecord, Measurement, Goal, Project, Milestone or link code, tables, commands or screens exist.
- Store schema is **v4** (P02). New tables mean v5, with a migration from a real v4 file and export/restore through the record registry (`record_kinds.dart`, ADR-0029).
- P02 gives: occurrences keyed by (task, original date), occurrence completions (D5), `DeviceTime` (clock and zone, injectable), `ReminderScheduler` (local notifications on both platforms, ADR-0034).
- Navigation is Tasks, Calendar, Profiles, Settings (P02 D9); Tasks has All / Today / Upcoming.
- No spike is assigned to P03 in the spike plan.

## 3. Owner decisions (accepted 2026-11-10)

| # | Question | Proposal |
|---|---|---|
| D1 | Focus recovery (UC-17 A2, FR-FOCUS-05): the app was killed or closed during a session | On the next start the session comes back as it was (running or paused, time derived from the stored start and pauses). If a **pomodoro's planned end passed** while the app was closed, ask: **"Count until the planned end"** (default), "Count until now" or "Discard". A stopwatch session is offered as "Resume" or "End now". A record that cannot be read is kept as `unrecoverable` and shown, never silently dropped. |
| D2 | How many sessions at once | **One active session at a time** (for the whole profile). Starting another asks to end the current one first. |
| D3 | Focus modes | **Pomodoro** (one work interval, default 25 min, changeable per session; when it ends the app offers an optional break timer that is not recorded) and **stopwatch** (open-ended). Pomodoro cycles (4 × work + long break) are not in the MVP. |
| D4 | Focus across screens and the app closed (FR-FOCUS-06) | A **focus bar** above the navigation on every screen while a session runs (time, pause, end). When a pomodoro ends, a **local notification** fires even if the app is closed (reuses the P02 reminder adapter). |
| D5 | What a session records (FR-FOCUS-07/08, FR-EXEC-01) | Ending with "count" creates **one execution record** (start, end, focus time without pauses, note, the task and its occurrence date if any). It **never completes the task** by itself. A session can also be without a task. |
| D6 | What a habit is, and its periods (**revised by the owner 2026-11-10**) | Three **independent** properties of a task: **habit** (a flag you set), **repeat** (P02) and **measurable** (a target). Examples: "drink warm water every morning" = habit, repeating, not measured (only tracked: done or missed); "walk at least 6000 steps a day" = habit, repeating, measured; "read 50 pages" = measured, not a habit. This amends ADR-0006 ("habit = repeat + target"). **Periods** of any repeating task are its repeat: daily = each day; weekly = each week (the series' week start, P02); every N days = N-day cycles; monthly/yearly = the month/year. Identity = the occurrence's original date, as in P02. A non-repeating task has one period: the whole task. Open points D6a–D6c below. |
| D6a | A habit without a repeat | Proposal: **allowed**, but the editor suggests "every day" when you mark a task as a habit with no repeat. A habit without a repeat has one period, like any one-off task. |
| D6b | What "tracking" a habit gives (measured or not) | Proposal: each **ended period gets a result** (done / missed for unmeasured habits; achieved / not achieved / no data for measured ones, D8–D9). The habit shows its **history**, its **completion rate** (last 30 days and all time) and its **current streak**. A repeating task that is **not** a habit keeps today's P02 behaviour: no "missed" records. |
| D6c | Unmeasured habit: how it is done | Proposal: you **tick each occurrence** (P02 D5). An occurrence not ticked by the end of its period becomes **missed**; you can still tick a past period later (it then becomes done, with the change recorded, D9). |
| D7 | Target details | Add **aggregation** per target: **sum** (default), max, latest, average. **Unit: free text** with suggestions (minutes, steps, km, pages, times, …). Values must be **≥ 0** in the MVP. `about` needs min ≤ max; `atLeast` needs min; `atMost` needs max. |
| D8 | Completion policy (FR-HAB-04) | **manual** (you tick; measurements show progress) and **automatic** (derived from measurements). Hybrid waits for P08. Automatic: **atLeast** is achieved as soon as the period's aggregate reaches min. **atMost** and **about** can only be judged when the period ends. A period with no measurement is **no data**, never 0 or failed, until it ends (HEALTH-002). With automatic, the checkbox shows the derived state and cannot be ticked by hand. |
| D9 | Closed periods (OQ-EXEC-1, FR-HAB-07/08, UC-02 A1) | When a period ends, its **result is stored** with a copy of the target used (achieved / not achieved / no data). Editing the target later **does not change stored results**. Adding or correcting a measurement in a closed period **asks for confirmation**, then re-evaluates that period with its stored target and records the change. |
| D10 | Measurements (UC-03, FR-EXEC-02/05) | Entered by hand with a value, a **date** (default today in the device zone; back-dating allowed) and an optional note. The date is fixed when recorded; a later zone change does not move it. **A correction creates a new measurement that replaces the old one in the totals; the old one stays in history** (EXEC-001). Every measurement keeps `source = manual` and its device and time (HEALTH-004). |
| D11 | Goals and projects (OQ-GOAL-1, FR-GOAL-02/05, product scope) | **Goal** and **Project** share one model (a project also has a start date). Both can have **milestones** and **links** to tasks, habits and events. **Milestones are completed by hand** (OQ-GOAL-1: yes); they are never auto-completed in the MVP. **Progress**: with milestones, done milestones / all milestones; without milestones, done linked tasks / linked tasks, where a habit counts its achieved periods / ended periods since it was linked, and trashed or cancelled tasks do not count. Status: active, done, archived; plus trash and restore. Trashing a goal **keeps the linked items** (GOAL-002). |
| D12 | Navigation and the rest | A **5th tab "Goals"** (Tasks, Calendar, Goals, Profiles, Settings). **Habits** is a 4th filter in Tasks (All, Today, Upcoming, Habits). Focus starts from a task's row menu ("Focus…") or from the focus bar without a task. **"This and following"** stays deferred to after P03 (as recorded at the P02 exit; the docs index is corrected). Missed occurrences of plain repeating tasks are still not listed as overdue; for habits, ended periods show their result. |

## 4. Technical design choices (no owner input needed; ADR-0036 and later)
- **Domain** (`packages/domain`, pure Dart, FF-ARCH-01):
  - `FocusSession` and `FocusSessionMachine` (start, pause, resume, end, cancel, recover). Elapsed time is derived from instants (`now − start − paused`), never a counter (EXEC-002).
  - `Task` gains an **`isHabit`** flag (D6), independent of `target` and of the repeat; ADR-0006 is amended in T1. The Habits filter selects `isHabit` tasks.
  - `MeasurableTarget` gains `aggregation`. Pure functions `aggregate(measurements, policy)` and `evaluate(target, aggregate, periodEnded)` give achieved / not achieved / no data / in progress (GS-02 table). For an unmeasured habit, the period result is done / missed from the occurrence completion (D6c).
  - Habit statistics (D6b): completion rate and current streak, pure functions over the period results.
  - `GoalProgress`, a pure function of the linked items' states (GOAL-001).
  - Period boundaries come from the task's recurrence via `time_kernel` (occurrence dates and the next occurrence).
- **Storage** (schema **v5**, additive): `focus_sessions`, `execution_records`, `measurements` (with `supersedes_id`, `source`, `provenance`, `local_date`, occurrence key), `period_results` (for habits and measurable tasks; target snapshot when measured), `goals` (kind goal|project), `milestones`, `goal_links`; `tasks.is_habit`, `tasks.target_aggregation`. All are syncable records in export and restore (LF-INV-SEC-010), with a migration test from a real v4 file.
- **Writes**:
  - Through the gateway with audit, outbox and events (ADR-0011/0014).
  - `FocusCommandHandler`, `MeasurementCommandHandler` (record, correct), `GoalCommandHandler`, and target ops on `TaskCommandHandler` (set target, completion policy).
  - The atomic-set test covers every new op (FF-ARCH-06).
- **Session persistence**: the session row is written in the same transaction at start and on every transition, so a kill at any point leaves a recoverable row (EXEC-003). Ending is keyed by session id, so a second end is a no-op (EXEC-004).
- **Reads**:
  - `FocusQueries` (active session, recoverable sessions).
  - `ExecutionSummary(task, window)`: planned vs actual, focus minutes.
  - `MeasurementSeries(task, periods)`: aggregate, state and history per period.
  - `HabitQueries` (habits with the current period state).
  - `GoalQueries` (list, detail, progress, "part of" for a task).
- **Period close**: a closed period's result is written by a system command when it is first read after its end, or on app start, keyed by (task, original date). It is idempotent, so a result is never written twice.
- **UI**: business rules stay out of widgets (AP-12, FF-ARCH-04); the focus bar reads a stream of the active session.

## 5. Tasks
One branch per task; merge after the headless tests pass and, where marked, the owner checks the devices (same rules as P01/P02).

| Task | Content | Main proof | Device check | Est. (pd) |
|---|---|---|---|---|
| **T1** Domain rules | Focus machine and recovery; target evaluation and aggregation; period boundaries from the repeat; goal progress. All pure. | GS-02 table (min == max, open bounds); EXEC-002 property tests (pauses, clock changes); HEALTH-002 (no data ≠ 0); progress as a pure function (GOAL-001) | no | 2–3 |
| **T2** Storage v5 | New tables, `target_aggregation`, migration v4 → v5, export/restore of the new tables. | migration test on a real v4 file; export guard; GS-20 round trip with sessions, measurements, results, goals | no | 2 |
| **T3** Focus commands | Start, pause, resume, end (count / don't), cancel, recover on launch (D1), one active session (D2), records (D5). | GS-13 headless (kill at any step, relaunch, elapsed within 1 s, one record); FF-ARCH-06/09 | no | 2–3 |
| **T4** Targets, measurements, habits | Mark or unmark a habit (D6); set target and policy; record and correct measurements (D10); period evaluation and closed results for habits and measurable tasks, done / missed for unmeasured habits (D6–D9, D6c); automatic completion derived. | GS-01 (achieved exactly when the aggregate crosses the target, never set by the data); GS-05 manual path; EXEC-001 (history kept); TASK-010 | no | 3–4 |
| **T5** Goals and projects | Goals/projects, milestones, links, progress, archive and trash (D11). | GS-21 (pure progress; trashing keeps tasks); GOAL-003 (other-workspace link refused) | no | 2 |
| **T6a** UI: habits | "Habit" switch and target editor in the task editor, Habits filter, measurement entry, history and corrections, habit history, rate and streak (D6b), period states in Today and the calendar. | widget tests; app integration test on real stores | **yes** | 2–3 |
| **T6b** UI: focus | Focus screen, focus bar on every screen, end notification, recovery dialog (D1, D4). | widget tests; kill and relaunch on both devices | **yes** | 2–3 |
| **T6c** UI: goals | Goals tab: list, detail, milestones, links, progress, "part of" on tasks. | widget tests; app integration test | **yes** | 2 |
| **T7** MVP exit gate | p03-exit-gate.md (DoD line → proof), ADRs, risk register, invariant matrix; MVP review with the owner. | all suites, CI | yes | 1 |

Order: T1 → T2 → T3 → T4 → T5 → T6a → T6b → T6c → T7. Total about 18–24 person-days, inside the roadmap range.

## 6. Risks
- **R-DATA-LOSS (focus recovery)**: a kill between steps loses a session or records it twice. Mitigation: persist on every transition in one transaction; end keyed by session id; kill tests at every step (GS-13); device kill checks in T6b.
- **R-SCOPE**: P03 is the MVP end and the UI is new on three fronts. Mitigation: decisions D3/D8/D11 keep each feature small; T6 split in three for device review.
- **Clock and zone changes during a session**: Mitigation: instants only (UTC), elapsed derived; a negative duration is refused (UC-17 E1).
- **Period edge cases** (DST days, week start, month ends): Mitigation: periods come from the tested P02 recurrence engine; table tests across DST and month ends.
