# Personas and Use Cases

- Status: Draft (Batch 1)
- Date: 2026-11-04
- Related: [product-scope.md](product-scope.md), [requirements.md](requirements.md)

Invariant IDs below (`LF-INV-*`) and domain event names are **provisional**: they name the rule being relied on. The invariant catalog and domain model (later batches) define them formally. [Proposal]

## 1. Personas

| ID | Persona | Description | Needs | MVP relevance |
|---|---|---|---|---|
| PER-1 | Solo power user (primary) | Plans own day and habits across Windows laptop and Android phone; works offline; wants accurate records of what actually happened | Fast capture, trustworthy schedule, habits with targets, focus timer | Full |
| PER-2 | Small-team member | Shares a few lists/tasks/calendars with colleagues or family; keeps personal data private | Explicit sharing, assignments, no accidental exposure | Deferred (P04) |
| PER-3 | Learner | Reads documents and PDFs, looks up words, reviews flashcards | Fast lookup, spaced review, learning plan | Deferred (P05, P07, P09) |

## 2. Use case index

| ID | Use case | Persona | Phase | Detail level |
|---|---|---|---|---|
| UC-01 | Create Task and Subtask | PER-1 | MVP | Full |
| UC-02 | Create Measurable Habit | PER-1 | MVP | Full |
| UC-03 | Set a 5,000 steps/day target and record steps manually | PER-1 | MVP (manual entry) | Full |
| UC-04 | Health Connect syncs steps and goal is evaluated | PER-1 | P08 | Stub |
| UC-05 | Health data missing or late | PER-1 | P08 (MVP covers the "no measurement is not zero" rule for manual entry) | Stub |
| UC-06 | Create Recurring Task with limited repetitions | PER-1 | MVP | Full |
| UC-07 | AI plans the day from workload and calendar | PER-1 | P06 | Stub |
| UC-08 | Detect conflicts and propose reschedule (deterministic detection in MVP; AI proposal in P06) | PER-1 | MVP (detection), P06 (AI) | Medium |
| UC-09 | Read a document and save a word | PER-3 | P05, P07 | Stub |
| UC-10 | Look up a word while reading a PDF | PER-3 | P05, P07 | Stub |
| UC-11 | Create flashcards and review schedule | PER-3 | P07 | Stub |
| UC-12 | Create Learning Course and generate Tasks | PER-3 | P09 | Stub |
| UC-13 | Share a Task with another workspace | PER-2 | P04 | Stub |
| UC-14 | Two devices edit the same document offline | PER-1, PER-2 | P04, P05 | Stub |
| UC-15 | Revoke Health data permission | PER-1 | P08 | Stub |
| UC-16 | Switch between Windows and Android | PER-1 | P04 (sync); not in MVP (OQ-S1 deferred by owner) | Stub |
| UC-21 | Create a Goal with Milestones and link Tasks | PER-1 | MVP (P03) | Medium |
| UC-22 | Use as guest, sign in (bind or new profile), sign out | PER-1 | MVP | Full |
| UC-17 | Lose app/network during a focus session | PER-1 | MVP | Full |
| UC-18 | AI proposal based on stale data | PER-1 | P06 | Stub |
| UC-19 | Delete data while another device is offline | PER-1, PER-2 | P04 | Stub |
| UC-20 | Export all data and delete account | PER-1 | MVP: local export (UC-20a) and deleting the account identity (UC-20b: removes the account and its binding; local profile data stays unless the user deletes it); deletion of synced content is P04 | Medium |

## 3. Full use cases (MVP)

### UC-01: Create Task and Subtask

- Actor: PER-1 (local user).
- Preconditions: App has a local profile and a Personal Workspace (implicit, always present).
- Main flow:
  1. User enters a title in quick capture (lands in Inbox) or in a list.
  2. System creates a Task with a new stable UUID, status `todo`, `createdAt` (UTC instant) and version 1.
  3. User adds a Subtask under the Task; system creates a child Task whose parent is the first.
  4. User optionally sets priority, tags, list, and a Schedule (see UC-06 for recurrence).
- Alternative flows:
  - A1: Quick capture without a list places the Task in Inbox.
  - A2: User moves a Subtask to another parent: system re-parents it if the new parent is not the Subtask itself or any of its descendants.
  - A3: User completes the parent while Subtasks are open: system applies the completion policy (see requirements FR-TASK-09); default is to require explicit choice (complete all / keep open).
- Error flows:
  - E1: Empty title is rejected with a validation message; nothing is written.
  - E2: Re-parenting would create a cycle: command is rejected; hierarchy unchanged.
  - E3: Database write fails: no partial state is visible (single transaction); the user is shown a retryable error.
- Permissions: Owner of the Personal Workspace (MVP has a single local owner).
- Data changes: insert Task (and child Task); optional Schedule row; audit entry.
- Domain events (provisional): `TaskCreated`, `TaskReparented`.
- Invariants involved (provisional): LF-INV-TASK-001 stable identity; LF-INV-TASK-002 valid hierarchy; LF-INV-TASK-003 no cycles; LF-INV-GOV-001 mutations only via commands.
- Acceptance criteria:
  - AC-01.1: Creating a Task returns a UUID that never changes after update, move, or restart.
  - AC-01.2: A Task at depth N can be created up to the documented maximum depth (value decided in the domain batch) and is rejected beyond it.
  - AC-01.3: For any sequence of random re-parent commands, the resulting parent graph is acyclic (property test).
  - AC-01.4: A failed write leaves no orphan Subtask (transaction test).
  - AC-01.5: Quick-captured Task appears in Inbox within one UI frame after command success.

### UC-02: Create Measurable Habit

- Actor: PER-1.
- Preconditions: Personal Workspace exists.
- Main flow:
  1. User creates a Habit with a title, a recurrence (for example daily), and a Target: type (`atLeast`, `atMost`, `about` with min/max), numeric value(s) and unit, plus an aggregation period (day, week or custom cycle).
  2. System stores the Habit definition (Target) separately from future Measurements.
  3. Each day/period, system generates an occurrence window (virtual, no physical row required until something is recorded).
  4. User records a Measurement (see UC-03); system evaluates the period against the Target and updates the Completion State under the Habit's completion policy.
- Alternative flows:
  - A1: User edits the Target mid-period: existing Measurements are kept; evaluation of the current and future periods uses the new Target; evaluation of closed periods is not rewritten (history preserved) [Proposal].
  - A2: User pauses the Habit: no occurrences evaluate during the pause.
- Error flows:
  - E1: `about` Target with min greater than max is rejected.
  - E2: Negative value for an `atLeast` Target with a unit that cannot be negative is rejected (unit catalog decided later).
- Permissions: Owner.
- Data changes: insert Habit (definition), recurrence rule; Measurements added in UC-03.
- Domain events (provisional): `HabitCreated`, `HabitTargetChanged`, `HabitPeriodEvaluated`.
- Invariants involved (provisional): LF-INV-TASK-010 measurement policy enforced; LF-INV-PLAN-010 recurrence bounded and deterministic; LF-INV-EXEC-001 history preserved.
- Acceptance criteria:
  - AC-02.1: Target types `atLeast`, `atMost`, `about` evaluate correctly at the boundary values (table-driven test, including min == max and infinite bounds).
  - AC-02.2: Changing the Target does not alter the stored result of any already-closed period.
  - AC-02.3: A period with zero Measurements is `no data`, not `0` and not `failed`, until the period closes under the policy rule (see requirements FR-HAB-06).
  - AC-02.4: Evaluation is deterministic: same Measurements and Target always yield the same state.

### UC-03: Set a 5,000 steps/day target and record steps manually

- Actor: PER-1.
- Preconditions: A Habit "Walk" exists with Target `atLeast 5000 steps` per day (UC-02).
- Main flow:
  1. User adds a Measurement of 2,300 steps at 08:00 local time; source `manual`.
  2. System stores a Measurement with source, value, unit, recorded-at instant, and the **local calendar date** it belongs to.
  3. User adds 3,100 steps at 18:00.
  4. System aggregates the day (sum for `steps`) = 5,400, evaluates the Target, and marks the day `achieved`.
- Alternative flows:
  - A1: User corrects the 08:00 entry to 1,800: system stores a correction (the previous value remains in history) and re-evaluates; day becomes `not yet achieved` (3,100 + 1,800 = 4,900) if still open.
  - A2: Aggregation policy for the metric is `sum` for steps; other metrics may use `max`, `latest` or `average` (catalog in later batch).
- Error flows:
  - E1: Non-numeric or negative steps are rejected.
  - E2: A Measurement dated in a closed period requires confirmation to change that period's result (policy, see FR-HAB-07).
- Permissions: Owner.
- Data changes: insert Measurement; update derived period state (derived or stored with version).
- Domain events (provisional): `MeasurementRecorded`, `MeasurementCorrected`, `HabitPeriodEvaluated`.
- Invariants involved (provisional): LF-INV-HEALTH-002 missing data is not zero (applies to the manual path too); LF-INV-HEALTH-004 provenance preserved; LF-INV-EXEC-001 history preserved; LF-INV-TASK-010.
- Acceptance criteria:
  - AC-03.1: Two Measurements on the same local date sum to the expected total; a Measurement at 23:59 and one at 00:01 fall on different dates in the user's current timezone.
  - AC-03.2: After a correction, both the corrected value and its predecessor exist in history, and the aggregate uses only the current value.
  - AC-03.3: Changing the device timezone does not move previously recorded Measurements to another date; the stored local date is kept [Proposal, pending timezone ADR].
  - AC-03.4: Provenance (`source = manual`) is present on every Measurement.

### UC-06: Create Recurring Task with limited repetitions

- Actor: PER-1.
- Preconditions: Personal Workspace exists.
- Main flow:
  1. User creates a Task with a Schedule (start date-time and duration) and a recurrence rule: weekly on Monday and Wednesday, ending after 10 occurrences.
  2. System stores one Task, one Schedule and one recurrence rule (no physical occurrences).
  3. Calendar/Today views request occurrences for a visible window; system generates them deterministically from the rule and exceptions.
  4. User completes the occurrence of a specific date; system records a completion for that occurrence only.
- Alternative flows:
  - A1: Skip, move, edit or cancel one occurrence: system stores an exception keyed by the original occurrence date; other occurrences are unchanged.
  - A2: User changes the rule going forward: system splits the series at that date (old rule ends, new rule starts) [Proposal].
  - A3: End condition is a date or "never" with a documented maximum horizon for generation.
- Error flows:
  - E1: Rule that would produce more than the configured maximum occurrences per request window is truncated with a visible notice; nothing unbounded is stored.
  - E2: Invalid combination (for example end date before start) is rejected.
  - E3: DST transition: a 02:30 local occurrence that does not exist on a spring-forward day is resolved by the documented DST rule (first valid minute after the gap); an ambiguous time on fall-back resolves to the earliest instant [Existing Fact in legacy `wall_clock_resolver`; Proposal to adopt].
- Permissions: Owner.
- Data changes: Task, Schedule, RecurrenceRule, Exceptions.
- Domain events (provisional): `RecurringTaskCreated`, `OccurrenceExceptionAdded`, `OccurrenceCompleted`.
- Invariants involved (provisional): LF-INV-PLAN-010 bounded and deterministic; LF-INV-PLAN-011 exceptions preserved; LF-INV-PLAN-004 date-only semantics preserved; LF-INV-PLAN-012 no duplicate occurrences.
- Acceptance criteria:
  - AC-06.1: A rule "after 10 occurrences" yields exactly 10 occurrences across any set of queried windows, with no duplicates and no gaps.
  - AC-06.2: Generating occurrences twice for the same window returns identical results (determinism).
  - AC-06.3: The number of database rows does not grow with the number of occurrences (no physical expansion).
  - AC-06.4: Occurrence exceptions survive a rule edit that does not affect their date.
  - AC-06.5: Across a DST change in a named zone, occurrences keep their local wall-clock time (table-driven test over at least two zones with DST).

### UC-17: Lose app or network during a focus session

- Actor: PER-1.
- Preconditions: A Focus Session is running for a Task (25-minute Pomodoro).
- Main flow:
  1. App persists the session at start: planned duration, start instant (UTC), state `running`.
  2. The remaining time is always derived from `now - start - pausedTotal`, not from a counter.
  3. The app is killed or the device restarts at minute 12.
  4. On next launch, system finds a session in `running` or `paused` state and recovers it: offers "resume", "end now (record 12+ minutes)" or "discard".
- Alternative flows:
  - A1: User paused before the crash: recovery keeps the paused total.
  - A2: Planned end passed while the app was closed: recovery shows the session as ended at planned end (or asks), never as still running.
  - A3: No network: no impact; the MVP has no network dependency.
- Error flows:
  - E1: Clock change (manual or timezone) during the session: duration uses a monotonic or UTC-based calculation; negative durations are rejected [Proposal].
  - E2: Corrupt session record: system preserves it as `unrecoverable` for the user to review, not silently deleted.
- Permissions: Owner.
- Data changes: FocusSession and related ExecutionRecord created or finalized on user decision.
- Domain events (provisional): `FocusSessionStarted`, `FocusSessionRecovered`, `FocusSessionEnded`, `ExecutionRecorded`.
- Invariants involved (provisional): LF-INV-EXEC-002 accurate duration; LF-INV-EXEC-003 session recovery; LF-INV-EXEC-004 explicit pause/cancel; LF-INV-EXEC-001 history preserved.
- Acceptance criteria:
  - AC-17.1: Killing the process at any point during a running session and restarting yields a recoverable session with the correct elapsed time within 1 second of the true value (crash/recovery test).
  - AC-17.2: Pause then kill then recover keeps the paused total.
  - AC-17.3: Recovery never creates two Execution Records for one session (idempotency test).
  - AC-17.4: Session state (focus) is independent from Task status; ending a session does not complete the Task.

### UC-20a: Export all data locally (MVP slice of UC-20)

- Actor: PER-1.
- Preconditions: Local data exists.
- Main flow:
  1. User chooses Export.
  2. System writes a versioned file containing all user-owned entities, including tombstones, with a schema version and checksum.
  3. System reports counts per entity type.
- Alternative flows: A1: Restore from file into an empty install reproduces the data.
- Error flows: E1: Disk full or permission denied is reported; no partial file is left under the final name.
- Permissions: Owner.
- Data changes: none to the database; file created.
- Domain events: none (read-only); audit entry `DataExported`.
- Invariants involved (provisional): LF-INV-SEC-010 export completeness; LF-INV-SYNC-004 tombstones propagate (kept in export).
- Acceptance criteria:
  - AC-20a.1: Export followed by restore into a clean database yields equal data (round-trip test), including Subtask hierarchy, recurrence exceptions and measurement history.
  - AC-20a.2: Export file declares its schema version; restoring a newer-version file into an older app is rejected with a clear message.
  - AC-20a.3: Export contains no data classified Restricted unless the user confirms (classification rules in the data batch).

## 4. Medium detail

### UC-08: Conflict detection and reschedule (MVP detection)

- Actor: PER-1. Precondition: At least two scheduled items overlap.
- Main flow: When a schedule is saved, system computes overlaps with other timed items and displays them; user chooses to keep, move one, or ignore.
- Error flow: items with date-only schedules are not treated as time conflicts unless the user opts in.
- Data changes: none by detection; a move is a normal schedule update command.
- Invariants (provisional): LF-INV-PLAN-004 date-only preserved; LF-INV-GOV-001.
- Acceptance: AC-08.1 Overlap result is symmetric and deterministic for a fixed set of items; AC-08.2 All-day items are excluded by default.
- AI proposing a reschedule is P06 and must follow the proposal/approval lifecycle.

### UC-21: Create a Goal with Milestones and link Tasks (P03)

- Actor: PER-1. Precondition: Tasks and at least one Habit exist.
- Main flow: User creates a Goal "Read 12 books", adds Milestones, links existing Tasks and a Habit. System shows progress derived from linked items.
- Alternative flow: User unlinks a Task; progress recalculates; the Task is unchanged.
- Error flow: Linking a Task from another workspace is rejected (MVP has one workspace; rule is enforced for P04).
- Data changes: Goal, Milestone, link rows. No Task rows change.
- Invariants (provisional): LF-INV-GOAL-001 progress is derived and never written back to a Task; LF-INV-GOV-001.
- Acceptance: AC-21.1 Deleting a Goal leaves all linked Tasks intact. AC-21.2 Progress is a pure function of linked items' states (same inputs, same output). AC-21.3 A Goal is never required to be a Task.

### UC-22: Use as guest, sign in, bind or start a new profile, sign out (MVP, ADR-0008)

- Actor: PER-1. Precondition: first launch; network may be absent.
- Main flow:
  1. App opens directly into a guest LocalProfile with a Personal Workspace; user creates Tasks.
  2. Later the user chooses Sign in (network required for this step only) and authenticates through the chosen provider.
  3. Because the profile contains data, the app asks: "Move your current data to this account?"
  4. User answers **Yes**: the current profile is bound to the account. No entity ID or workspace ID changes.
  5. App caches the session securely; user continues, including offline.
- Alternative flows:
  - A1: User answers **No**: the app creates a new LocalProfile (new session, empty) bound to the account; the previous guest profile and its data remain on the device and can be reopened.
  - A2: Profile is empty at sign-in: the app binds without asking.
  - A3: Session expires while offline: local data stays accessible; the app asks to re-authenticate when online.
  - A4: User signs out: behavior per OQ-S7 (proposal: return to a profile chooser; no data is deleted).
- Error flows:
  - E1: Authentication fails or the auth server is unreachable: the user stays in the current profile with no change to data.
  - E2: The user cancels at the question in step 3: sign-in is aborted, no binding occurs, no session is created.
  - E3: Binding fails midway (for example storage error): the profile remains unbound and fully intact (single transaction on the binding record).
- Permissions: Owner of the LocalProfile.
- Data changes: AccountBinding record; auth session in secure storage; on "No", a new LocalProfile and Personal Workspace.
- Domain events (provisional): `ProfileBoundToAccount`, `ProfileCreated`, `SignedOut`.
- Invariants (provisional): LF-INV-ID-001 binding never changes entity or workspace IDs; LF-INV-ID-002 profile data isolation; LF-INV-SEC-001 secrets only in secure storage; LF-INV-SEC-002 offline access never blocked by auth failures.
- Acceptance criteria:
  - AC-22.1 With airplane mode on, a guest user can create and edit Tasks from first launch.
  - AC-22.2 After "Yes", every Task ID, list ID and workspace ID is identical before and after binding (comparison test).
  - AC-22.3 After "No", the new profile contains no data from the previous profile, and the previous profile is unchanged (isolation test).
  - AC-22.4 No access or refresh token appears in logs or plain-text storage.
  - AC-22.5 Sign-out removes the cached session and deletes no user content.
  - AC-22.6 A failure during binding leaves the profile unbound and intact (fault-injection test).

## 5. Deferred use cases (stubs)

| UC | Short flow | Key risks recorded for later batches |
|---|---|---|
| UC-04 | Android reads steps via Health Connect (foreground or permitted background), normalizes, de-duplicates by source and ID, stores as evidence, then the habit policy evaluates | Late data, multi-source duplicates, timezone dates (see [verified-sources.md](../research/verified-sources.md) VS-13, VS-14) |
| UC-05 | No reading yet for the day: state is `no data`; later data triggers re-evaluation | Missing data must not become zero |
| UC-07 | AI builds a day plan proposal from workload and calendar; user approves; commands execute | AI cannot mutate directly; approval bound to resource versions |
| UC-09, UC-10 | Select text in document or PDF, open dictionary popup, save to vocabulary with context | Selection differs per renderer (Flutter text, PDF viewer, WebView) |
| UC-11 | Saved word becomes flashcard with deterministic spaced-repetition schedule | Dictionary updates must not overwrite learning progress |
| UC-12 | Course generates Tasks through the Task creation contract | Learning never writes Task storage directly |
| UC-13 | Share a Task into a Shared Workspace under permissions | No implicit sharing; RLS verification |
| UC-14 | Two offline edits to one document produce two revisions and a visible conflict | No silent content loss; revision-based sync |
| UC-15 | Revoke Health permission: stop reading, keep or delete stored data per user choice; revocation is not zero | Retention policy |
| UC-16 | Sync across Windows and Android (deferred to P04 by owner decision OQ-S1) | Idempotency, versioning, tombstones |
| UC-18 | Proposal references a resource version that has changed; system rejects or asks to regenerate | Stale approval |
| UC-19 | Delete on device A, device B still offline and later edits the item: tombstone vs edit conflict is surfaced | Delete/edit conflict policy |
| UC-20b | Delete cloud account and remote data | Retention, backups |

## 6. Traceability

| Use case | Requirements (see requirements.md) |
|---|---|
| UC-01 | FR-TASK-01..09, NFR-DATA-01 |
| UC-02, UC-03 | FR-HAB-01..08, FR-EXEC-05 |
| UC-06 | FR-PLAN-01..10 |
| UC-08 | FR-PLAN-11, FR-CAL-04 |
| UC-17 | FR-FOCUS-01..08 |
| UC-20a | FR-DATA-01..04 |
| UC-21 | FR-GOAL-01..05 |
| UC-22 | FR-AUTH-01..04, NFR-OFF-01 |

## 7. Self-check

- [x] Each full use case has actor, preconditions, flows, permissions, data changes, events, invariants and acceptance criteria.
- [x] Every acceptance criterion is phrased so it can be automated (unit, property, table-driven, crash/recovery or round-trip test).
- [x] Deferred use cases state their target phase and their key risk.
