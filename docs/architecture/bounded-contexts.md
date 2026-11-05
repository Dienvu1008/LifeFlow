# Bounded Contexts (Preliminary)

- Status: Draft (Batch 1). Aggregate design, commands and events are detailed in the domain batch.
- Date: 2026-11-04
- Related: [context-map.md](context-map.md), [architecture-principles.md](architecture-principles.md), [../product/product-scope.md](../product/product-scope.md), [../assessment/legacy-component-matrix.md](../assessment/legacy-component-matrix.md)

## 1. Evaluation of the 15 candidates

The brief's candidate list is a starting point, not a requirement. Changes are justified below. [Proposal]

| # | Candidate | Verdict | Reason |
|---|---|---|---|
| 1 | Identity and Workspace | Rename to **Workspace and Access**; authentication moves to an adapter | Identity provider is a Generic concern (backend undecided, ADR-0003). The domain concern is workspaces, membership, roles, sharing grants and permission evaluation. |
| 2 | Task Management | Keep, **Core** | |
| 3 | Planning and Scheduling | Keep as **Core**, but as a **Time Kernel**, not a data owner | Schedule and recurrence are value objects stored by their owning aggregate (Task, Event). The context owns rules and algorithms: schedule semantics, recurrence expansion, exceptions, DST resolution, overlap detection, workload math. |
| 4 | Calendar and Events | Keep, **Core** | Event is its own aggregate; attendance and calendar overlays live here. |
| 5 | Goals and Projects | Keep, **Supporting**, P03 (in MVP) | Progress is derived from Tasks and Habits by reference; must not make every goal a Task. |
| 6 | Execution and Focus | Rename to **Execution and Measurement**, **Core** | Execution Records, Measurements and Focus Sessions share the idea of "what actually happened". Measurement and evidence belong here, not in Task, so Health can later publish evidence here without touching Task. |
| 7 | Knowledge and Documents | Keep, **Supporting**, P05 | |
| 8 | Dictionary and Lexical Knowledge | Keep, **Supporting**, P07 | |
| 9 | Translation | Keep **separate**, **Supporting**, P07 | Brief requires its own data model and logic. Shares language primitives with Dictionary through `foundation`, not a shared context. |
| 10 | Vocabulary Learning | Keep, **Supporting**, P07 | Saved vocabulary and review progress are user-owned and never overwritten by dictionary updates. |
| 11 | Health and Activity Integration | Keep, **Supporting**, P08 | Produces evidence only. Platform clients sit behind an anti-corruption layer. |
| 12 | Learning Studio | Keep, **Supporting**, P09 | Creates Tasks only via the Task Management contract. |
| 13 | Collaboration | Keep but **thin**, **Supporting**, P04 | Comments, mentions, invitations lifecycle, shared activity feed. Authorization stays in Workspace and Access. |
| 14 | AI Intelligence | Keep, **Supporting**, P06 | Holds sessions, proposals, approvals and routing. Owns no domain state of other contexts. |
| 15 | Platform Services | **Not a bounded context** | A technical layer (platform adapters, persistence, notifications, files). Contains no business rules. See architecture-principles.md section 3. |
| New | Governance Kernel | **Cross-cutting application foundation**, not a context | Command gateway, audit, idempotency, versioning, outbox. Needed for every context. |
| New | Sync | **Infrastructure capability**, not a context | Transport and reconciliation; business semantics stay in contexts. |

## 2. Summary table

| Context | Type | Phase | In MVP | Aggregate roots to expect (names only) | Owns persistence of |
|---|---|---|---|---|---|
| Workspace and Access | Supporting | P01 (minimal), P04 (full) | Minimal (guest-first LocalProfile, optional account binding via `AuthGateway`, one Personal Workspace per profile) | Workspace, Membership, SharingGrant (later) | Workspaces, memberships, grants |
| Task Management | Core | P01 | Yes | Task, TaskList | Tasks, lists, task capabilities (target, completion policy), task history |
| Planning and Scheduling (Time Kernel) | Core | P02 | Yes | none (pure rules; value objects ScheduleSpec, RecurrenceRule, Exception) | none; owners store the value objects |
| Calendar and Events | Core | P02 | Yes | Event, Calendar | Events, calendars, attendance (later) |
| Execution and Measurement | Core | P03 | Yes | FocusSession, ExecutionRecord, MeasurementSeries (name tentative) | Sessions, records, measurements, evidence |
| Goals and Projects | Supporting | P03 | Yes (owner decision OQ-S2) | Goal, Project | Goals, projects, milestones |
| Collaboration | Supporting | P04 | No | Comment, Invitation | Comments, invitations |
| Knowledge and Documents | Supporting | P05 | No | Document, DocumentRevision | Documents, blocks, revisions, attachments metadata |
| AI Intelligence | Supporting | P06 | No | AiSession, AiProposal | Sessions, proposals, approvals, usage |
| Dictionary and Lexical Knowledge | Supporting | P07 | No | LexicalEntry (provider data), DictionaryPackage | Dictionary packages, cache |
| Translation | Supporting | P07 | No | TranslationRequest | Translation history |
| Vocabulary Learning | Supporting | P07 | No | VocabularyCollection, SavedVocabulary, ReviewState | Vocabulary, reviews |
| Health and Activity | Supporting | P08 | No | HealthConnection, HealthMeasurement (evidence) | Health connections, normalized health data |
| Learning Studio | Supporting | P09 | No | Course | Courses, modules, lessons, progress |

[Decision, owner 2026-11-04, see [ADR-0006](../adr/0006-habit-is-a-task-capability.md)] A Habit is a **Task with a recurrence and a measurable target**, not a separate aggregate. Task Management owns the Target and Completion Policy; Execution and Measurement owns Measurements.

## 3. Context responsibilities (MVP contexts)

### 3.1 Task Management (Core)
- Purpose: define what the user intends to do and its lifecycle.
- Owns: Task identity, hierarchy, status transitions, tags, list membership, capabilities (schedule reference, recurrence reference, measurable target, completion policy), history.
- Does not own: schedule algorithms (Time Kernel), actual time spent (Execution), calendar events (Calendar).
- Inbound: commands (create, update, move, complete, trash, restore); events from Execution (`MeasurementRecorded`, `ExecutionRecorded`) consumed in an application handler to evaluate completion.
- Outbound: events (`TaskCreated`, `TaskCompleted`, ...); query port `TaskReader` (published language: `TaskSummary`).

### 3.2 Planning and Scheduling (Time Kernel, Core)
- Purpose: one correct implementation of time semantics.
- Provides: `ScheduleSpec` validation, `RecurrenceRule` + exceptions, window-based occurrence generation, DST resolution, overlap detection, workload computation.
- Rule: stateless. No database. Called by Task Management and Calendar and Events.
- Open decision (ADR candidate): implement as a context package inside the domain layer versus part of `foundation`. Leaning: separate package `planning` with no I/O so it stays testable and portable.

### 3.3 Calendar and Events (Core)
- Purpose: things that happen at a time (meeting, birthday, timetable).
- Owns: Event, Calendar, recurrence exceptions of events, attendance (post-MVP).
- Reads (by contract): occurrences of scheduled Tasks for overlay views via `ScheduledItemReader` (published by Task Management).

### 3.4 Execution and Measurement (Core)
- Purpose: record what actually happened and the evidence for it.
- Owns: FocusSession state machine, ExecutionRecord, Measurement entries (value, unit, source, provenance, local date), corrections.
- Publishes: `FocusSessionStarted/Ended`, `ExecutionRecorded`, `MeasurementRecorded`, `MeasurementCorrected`.
- Rule: never sets Task status. Task Management decides completion.

### 3.5 Workspace and Access (Supporting, minimal in MVP)
- Purpose: who owns and may touch what.
- MVP: guest-first. A `LocalProfile` with one Personal Workspace exists from first launch and may be bound to one account through an `AuthGateway` port (provider per ADR-0003, binding rules per ADR-0008). Every resource carries `workspaceId` and `ownerId`; binding never changes them. Profile data is isolated per profile. The cached session lets the app run offline. Candidate aggregate roots: `LocalProfile`, `AccountBinding` (names tentative).
- Later: membership, roles, sharing grants, policy evaluation used by the Governance Kernel.

### 3.6 Goals and Projects (Supporting, in MVP at P03)
- Purpose: group intent over a longer horizon (Life Goals, Projects, Milestones) without turning them into Tasks.
- Owns: Goal, Project, Milestone identity and lifecycle; links to Tasks, Habits and other resources held as `LinkedResource(type, id)` references.
- Does not own: Task state or Measurements. Progress is **derived** from linked Tasks/Habits by reading `TaskReader` and Execution and Measurement summaries, never written back.
- Dependency: downstream of Task Management and Execution and Measurement; nothing in the other MVP contexts depends on it.
- Legacy reuse: `GoalProgressService` logic as pure functions (see component matrix).

## 4. Dependency rules

| Rule | Statement |
|---|---|
| DR-1 | Contexts reference each other's entities by opaque ID only (typed ID in `foundation`). |
| DR-2 | A context may depend on another context's **published contract** (query port, command, event, published language types). Never on its tables, repositories, or internal domain types. |
| DR-3 | Downstream contexts consume upstream events through application-layer handlers. |
| DR-4 | No dependency cycle between context packages. Event direction is allowed only with an explicit upstream/downstream relation in the context map. |
| DR-5 | Learning, AI and Health create or change other contexts' state only through those contexts' commands. |
| DR-6 | Platform adapters implement ports defined by contexts; they hold no business rules. |
| DR-7 | Shared Kernel is limited to `foundation` (IDs, clock, result types, language codes, time primitives). Anything larger needs an ADR. |

## 5. MVP closure check

MVP contexts: Workspace and Access (minimal), Task Management, Time Kernel, Calendar and Events, Execution and Measurement, Goals and Projects (P03).

- [x] None of them depends on a deferred context (AI, Documents, Dictionary, Health, Learning, Collaboration).
- [x] Goals and Projects is a leaf: it depends on Task Management and Execution and Measurement, and nothing depends on it.
- [x] Deferred contexts attach through contracts that already exist in the MVP (commands, events, `MeasurementRecorded`, `workspaceId` on resources).
- [x] The only upstream/downstream pair among MVP contexts is Execution (upstream) to Task Management (downstream, via events).

## 6. Legacy mapping

| Legacy area | Target context | Disposition |
|---|---|---|
| `Task`, `Subtask`, task lists | Task Management | Rewrite model, reuse test ideas |
| `TimeInterval`, `RepeatRule`, `wall_clock_resolver` | Time Kernel | Refactor/Reuse logic |
| `CalendarEvent`, `recurrence_expander` | Calendar and Events, Time Kernel | Refactor |
| `FocusSession`, `PomodoroBloc`, `FocusStatisticsService` | Execution and Measurement | Rewrite state machine; reuse statistics |
| `habits`, `habit_occurrences`, `HabitStatisticsService` | Task Management (target), Execution and Measurement (measurements) | Refactor concepts |
| `goals`, `projects`, `GoalProgressService` | Goals and Projects | Post-MVP; reuse pure progress logic |
| `notes` | Knowledge and Documents | Post-MVP; replace |
| `courses`, `LearningProgressService` | Learning Studio | Post-MVP; reuse pure logic |
| `lib/ai/**` | AI Intelligence | Post-MVP; Refactor with approval binding |
| `lib/auth/**` | Adapter for Workspace and Access | Replace |
| Notification service | Platform adapters | Refactor |

## 7. Open questions

| ID | Question | Decide in |
|---|---|---|
| OQ-B1 | Time Kernel as a separate package or inside `foundation`? | Repository structure batch, ADR |
| OQ-B2 | Habit as Task capability or its own aggregate? | **Resolved: Task capability**, ADR-0006 |
| OQ-B3 | Is Goals and Projects in MVP? | **Resolved: yes, P03** (OQ-S2) |
| OQ-B4 | Who owns `Reminder` (Task, Event, or a Notifications capability)? | Domain batch |
