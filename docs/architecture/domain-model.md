# Domain Model Overview

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Scope: cross-context overview. Per-context detail is in [../domains/](../domains/). MVP contexts are fully modeled; deferred contexts are stubs ([../domains/deferred-contexts.md](../domains/deferred-contexts.md)).
- Related: [bounded-contexts.md](bounded-contexts.md), [context-map.md](context-map.md), ADR-0006, ADR-0007, [ADR-0009](../adr/0009-identifier-and-versioning-strategy.md), [ADR-0010](../adr/0010-time-model-date-only-vs-instant.md), [ADR-0013](../adr/0013-time-kernel-packaging.md)

Label legend: see [../README.md](../README.md).

## 1. Aggregate map (MVP + P03)

| Context | Aggregate root | Child entities | Lifecycle |
|---|---|---|---|
| Workspace and Access | `LocalProfile` | `AccountBinding` | create on first launch; bind/unbind |
| Workspace and Access | `Workspace` | `Membership` (P04) | one Personal Workspace per profile in MVP |
| Task Management | `Task` | `Subtask` (a Task child), capabilities as value objects | create → update → complete → trash → purge |
| Task Management | `TaskList` | — | create → update → archive/trash |
| Planning and Scheduling | none (stateless rules) | value objects only | n/a |
| Calendar and Events | `Event` | `OccurrenceException` (shared VO) | create → update → cancel → trash |
| Calendar and Events | `Calendar` | — | create → update → archive |
| Execution and Measurement | `FocusSession` | — | start → pause/resume → end/cancel/recover |
| Execution and Measurement | `ExecutionRecord` | `Measurement` | record → correct (history kept) |
| Goals and Projects (P03) | `Goal` | `Milestone`, `LinkedResource` | create → update → complete → trash |
| Goals and Projects (P03) | `Project` | `LinkedResource` | create → update → trash |
| Health and Activity (P08) | `HealthConnection` | (no stored measurement aggregate; publishes `Measurement` to Execution) | connect → read → revoke |
| Dictionary (P07) | `LexicalEntry`, `DictionaryPackage` | `Sense`, `Pronunciation` | fetch/cache |
| Translation (P07) | `TranslationRequest` | `TranslationResult` | translate |
| Vocabulary Learning (P07) | `VocabularyCollection`, `SavedVocabulary` | `ReviewState`, `ReviewRecord` | save → review |
| Document and Knowledge (P05) | `Document`, `DocumentRevision` | `Block`, link/reference value objects | create → revise → move → trash |

[Proposal] "Habit" is not an aggregate (ADR-0006). A Habit is a `Task` whose capabilities include a `RecurrenceRule` and a `MeasurableTarget`. Measurements for it are `Measurement` entities under Execution and Measurement.

## 2. Shared `foundation` value objects

Defined once in `foundation`; referenced by all contexts. No business rules of any single context.

| Type | Meaning | Notes |
|---|---|---|
| `EntityId<T>` | Typed UUID v7 wrapper (e.g. `TaskId`, `EventId`) | ADR-0009; client-generated, stable |
| `LocalDate` | Calendar date, no time, no zone | ADR-0010; calendar comparisons only |
| `Instant` | UTC point in time | ADR-0010; metadata and precise past events |
| `TimeOfDayValue` | Hour and minute, no date | combined with `LocalDate`+zone → `ZonedWallClock` |
| `ZonedWallClock` | Wall-clock date-time + IANA zone name | ADR-0010; resolves to `Instant` via Time Kernel |
| `Version` | Monotonic integer per aggregate | ADR-0009; optimistic concurrency |
| `ActorRef` | Who acts (local owner, AI assistant, provider, sync) | see [../governance/authorization-model.md](../governance/authorization-model.md) |
| `WorkspaceId`, `OwnerId` | Tenancy and ownership | on every resource |
| `Result<T, E>` | Success or typed failure | domain methods return this, not exceptions, for expected failures |
| `Money`-style `Quantity` | Numeric value + unit | measurable targets and measurements; supports open bounds |

[Decision] The Time Kernel value objects (`ScheduleSpec`, `RecurrenceRule`, `OccurrenceException`) live in the `time_kernel` package (ADR-0013), not in `foundation`. Contexts that only need a `LocalDate` do not depend on `time_kernel`.

## 3. Identity, versioning, tombstones

Summarized from [ADR-0009](../adr/0009-identifier-and-versioning-strategy.md):
- Every aggregate root and identity-bearing child uses a client-generated UUID v7.
- Every aggregate root carries `version`, `createdAt`, `updatedAt` (UTC), `workspaceId`, `ownerId`.
- Delete writes a tombstone (`deletedAt`, `deletedBy`); hard delete only on purge or discard of never-synced data.
- Commands carry `expectedVersion`; the Governance Kernel rejects stale commands.

## 4. Capability composition on Task

[Decision, ADR-0006/0007] A `Task` is composed from optional capability value objects rather than a type hierarchy:

| Capability | Shape | Present when |
|---|---|---|
| `ScheduleRef` | reference to one `ScheduleSpec` (+ optional `RecurrenceRule`) | the Task is scheduled |
| `MeasurableTarget` | `targetType {atLeast, atMost, about}`, value(s), unit, aggregation policy, period | the Task is measurable (a Habit has this + recurrence) |
| `CompletionPolicy` | `{manual, automatic, hybrid}` + rule | always (default `manual`) |
| `SubtaskSet` | ordered child Task references | the Task has subtasks |

A Habit is exactly: `Task` + `ScheduleRef` with a `RecurrenceRule` + `MeasurableTarget`. No separate entity.

Two Task modeling rules the owner confirmed on 2026-11-04 (detailed in [../domains/task-management.md](../domains/task-management.md)):
- **Subtask depth (4) is a command-time check, not stored.** Raising the limit later is not a migration: existing subtasks at the old depth stay valid; only new `CreateTask`/`Reparent` commands are checked (LF-INV-TASK-002).
- **Completing a parent with open subtasks is two distinct commands**, `CompleteTaskWithDescendants` and `CompleteTaskOnly`, not a boolean flag, so audit and outbox distinguish them. `CompleteTaskOnly` writes an audit warning listing the still-open subtasks.

## 5. Domain event catalog

Events are facts in the past tense, carrying IDs and the minimum payload. Consumers listed; "external" means no in-process consumer yet (reserved for sync/audit or a deferred context).

| Event | Emitted by | Payload (core) | Consumers |
|---|---|---|---|
| `ProfileCreated` | Workspace and Access | profileId, workspaceId | audit |
| `ProfileBoundToAccount` | Workspace and Access | profileId, accountId | audit |
| `SignedOut` | Workspace and Access | profileId | audit |
| `TaskCreated` | Task Management | taskId, workspaceId | audit, Goals (if linked) |
| `TaskUpdated` | Task Management | taskId, changed fields | audit |
| `TaskReparented` | Task Management | taskId, oldParentId, newParentId | audit |
| `TaskCompleted` | Task Management | taskId, at | audit, Goals |
| `TaskTrashed` / `TaskRestored` / `TaskPurged` | Task Management | taskId | audit, sync (P04) |
| `HabitPeriodEvaluated` | Task Management | taskId, period, state | audit |
| `RecurringSeriesChanged` | Task Management | taskId, ruleId | Calendar (occurrence views) |
| `OccurrenceExceptionAdded` | Task Management / Calendar | seriesId, originalDate, kind | audit |
| `EventCreated` / `EventUpdated` / `EventCancelled` | Calendar and Events | eventId | audit |
| `FocusSessionStarted` | Execution and Measurement | sessionId, taskId?, startInstant, plannedDuration | audit |
| `FocusSessionEnded` | Execution and Measurement | sessionId, endInstant | Task Management (planned vs actual), audit |
| `FocusSessionRecovered` | Execution and Measurement | sessionId, recoveredState | audit |
| `ExecutionRecorded` | Execution and Measurement | recordId, taskId?, actualStart/end | Task Management, Goals, audit |
| `MeasurementRecorded` | Execution and Measurement | measurementId, targetRef, value, unit, source, localDate | Task Management (habit evaluation), Goals, audit |
| `MeasurementCorrected` | Execution and Measurement | measurementId, newValue | Task Management, audit |
| `GoalProgressRecomputed` | Goals and Projects | goalId, ratio | UI (read); audit optional |
| `GoalCreated` / `GoalCompleted` / `GoalTrashed` | Goals and Projects | goalId | audit |
| `VocabularySaved` / `VocabularyReviewed` / `VocabularyCollectionChanged` | Vocabulary Learning (P07) | savedId / collectionId | audit |
| `DocumentCreated` / `DocumentRevised` / `DocumentMoved` / `DocumentLinked` / `DocumentTrashed` / `DocumentRestored` | Document and Knowledge (P05) | documentId | audit, search index |

Health and Activity (P08) emits no event of its own; its effect is a `MeasurementRecorded` from Execution and Measurement when `RecordMeasurement` commits. Dictionary and Translation (P07) are read/cache capabilities and emit no domain events.

[Open] Final payloads are fixed per command in the context docs; this catalog is the authoritative list of event names.

## 6. Cross-context contracts (published language)

| Contract | Owner | Shape | Consumer |
|---|---|---|---|
| `TaskReader` | Task Management | `exists(TaskId)`, `TaskSummary(id, title, status, workspaceId)` | Calendar, Execution, Goals |
| `ScheduledItemReader` | Task Management | occurrences of scheduled tasks in a window | Calendar overlays |
| `OccurrenceWindowQuery` | Time Kernel | `(ScheduleSpec, RecurrenceRule?, exceptions, window) → List<Occurrence>` | Task Management, Calendar |
| `OverlapQuery` | Time Kernel | `(List<TimedItem>) → List<Conflict>` | Calendar, Planning views |
| `RecordMeasurement` command | Execution and Measurement | source + provenance + value | Health (P08), Learning (P09) |
| `CreateTask` / `UpdateTask` command | Task Management | via Governance Kernel | Learning, Vocabulary (deferred) |
| `AuthorizationService.check` | Workspace and Access | `(actor, action, resourceRef) → allow/deny` | Governance Kernel |

## 7. Invariant index (canonical IDs; enforcement detailed in context docs)

These IDs are now canonical (they were provisional in Batch 1). The full test matrix is Batch 4.

| ID | Statement (short) | Enforced in |
|---|---|---|
| LF-INV-ID-001 | Entity IDs never change (including on account binding) | all aggregates |
| LF-INV-ID-002 | Profile data is isolated across LocalProfiles | Workspace and Access |
| LF-INV-WA-001 | A profile has exactly one active Workspace in MVP | Workspace and Access |
| LF-INV-TASK-001 | Task identity is stable | Task |
| LF-INV-TASK-002 | Task hierarchy is valid (depth bounded) | Task |
| LF-INV-TASK-003 | No cycles in task hierarchy | Task |
| LF-INV-TASK-004 | Completion transitions are valid | Task |
| LF-INV-TASK-010 | Measurement policy is enforced for measurable tasks | Task + Execution |
| LF-INV-TASK-011 | A trashed task is excluded from active views but kept until purge | Task |
| LF-INV-PLAN-004 | Date-only semantics preserved (no implicit instant conversion) | Time Kernel |
| LF-INV-PLAN-010 | Recurrence is bounded and deterministic | Time Kernel |
| LF-INV-PLAN-011 | Occurrence exceptions are preserved across rule edits | Time Kernel / Task |
| LF-INV-PLAN-012 | No duplicate occurrences in a window | Time Kernel |
| LF-INV-PLAN-013 | A timed recurring item keeps its wall-clock time across DST | Time Kernel |
| LF-INV-CAL-001 | Event is distinct from Task (no shared identity) | Calendar |
| LF-INV-CAL-002 | All-day events use `LocalDate` and are excluded from timed conflicts by default | Calendar |
| LF-INV-EXEC-001 | Execution and measurement history is preserved (corrections keep predecessors) | Execution |
| LF-INV-EXEC-002 | Duration accounting is accurate | Execution |
| LF-INV-EXEC-003 | Focus session is recoverable after crash | Execution |
| LF-INV-EXEC-004 | At most one ExecutionRecord per focus session | Execution |
| LF-INV-HEALTH-001 | Health access is permission-scoped and re-checked before each use | Health (P08) |
| LF-INV-HEALTH-002 | Missing data is not zero (applies to manual measurements too) | Execution, Health |
| LF-INV-HEALTH-003 | Revocation is not retroactive deletion and not zero | Health (P08) |
| LF-INV-HEALTH-004 | Measurement provenance is preserved | Execution, Health |
| LF-INV-HEALTH-005 | Duplicate protection: a source activity is not counted twice | Health ACL (P08) |
| LF-INV-HEALTH-006 | Health evidence cannot bypass Task completion policy | Health (P08) |
| LF-INV-DICT-001 | Lexical identity is separate from user-captured contextual meaning | Dictionary / Vocabulary (P07) |
| LF-INV-DICT-002 | Source and license provenance preserved on cached lexical data | Dictionary (P07) |
| LF-INV-DICT-003 | AI-generated definitions are not authoritative dictionary data | Dictionary (P07) |
| LF-INV-DICT-004 | Translation routing obeys the egress matrix | Translation (P07) |
| LF-INV-VOCAB-001 | A looked-up word is not saved vocabulary (saving is explicit) | Vocabulary (P07) |
| LF-INV-VOCAB-002 | Dictionary updates never overwrite saved vocabulary or progress | Vocabulary (P07) |
| LF-INV-VOCAB-003 | Review scheduling is deterministic and reproducible | Vocabulary (P07) |
| LF-INV-VOCAB-004 | Review Tasks are created only via the Task contract | Vocabulary (P07) |
| LF-INV-DOC-001 | Document hierarchy has no parent-child cycle | Document (P05) |
| LF-INV-DOC-002 | Revision history preserved; no silent content loss | Document (P05) |
| LF-INV-DOC-003 | Internal references resolve or are marked broken, never silently dropped | Document (P05) |
| LF-INV-DOC-004 | Hierarchy, hyperlink, semantic reference, attachment and cross-context link are distinct | Document (P05) |
| LF-INV-DOC-005 | No silent content loss on concurrent document edit (keep both + conflict) | Document (P05), introduced Batch 4 |
| LF-INV-GOAL-001 | Goal/Project progress is derived, never written back to a Task | Goals |
| LF-INV-GOAL-002 | Deleting a Goal/Project removes links, not the linked Tasks | Goals |
| LF-INV-GOAL-003 | A linked resource in another workspace is rejected | Goals |
| LF-INV-GOV-001 | All state changes go through the command gateway | Governance Kernel |
| LF-INV-GOV-002 | Authorization is checked before the domain method runs | Governance Kernel |
| LF-INV-GOV-003 | Aggregate change, audit, outbox, event log and dedupe commit in one transaction | Governance Kernel (ADR-0014) |
| LF-INV-OUTBOX-001 | An outbox row exists iff the mutation committed | Governance Kernel (ADR-0014) |
| LF-INV-OUTBOX-002 | An event-log row exists iff the mutation committed | Governance Kernel (ADR-0014) |
| LF-INV-AUDIT-001 | An audit entry exists iff the mutation committed | Governance Kernel (ADR-0014) |
| LF-INV-VER-001 | Version re-read and incremented inside the transaction, only on match | Governance Kernel (ADR-0014) |
| LF-INV-AI-001 | AI cannot bypass authorization or mutate persistence directly | AI governance |
| LF-INV-AI-002 | An AI approval is bound to the resource version it was made against | AI governance |
| LF-INV-SEC-001 | Secrets live only in secure storage | platform adapters |
| LF-INV-SEC-002 | Offline access is never blocked by auth failures | Workspace and Access |
| LF-INV-SEC-010 | Export is complete (all user-owned entities, including tombstones) | Data/export (batch 3/4) |
| LF-INV-SEC-011 | Local database is encrypted at rest; cipher verified at startup | Storage, introduced Batch 4 |
| LF-INV-SYNC-001 | Sync apply is idempotent by operationId | Sync (P04) |
| LF-INV-SYNC-002 | Conflicts are detected by version, not timestamp | Sync (P04) |
| LF-INV-SYNC-003 | No global Last-Write-Wins; conflict resolution is per data type | Sync (P04), ADR-0015 |
| LF-INV-SYNC-004 | Tombstones propagate (kept until retention allows purge) | Governance Kernel / sync (P04) |
| LF-INV-PRIV-001 | Egress is default-deny (allowed only where the classification matrix permits) | Data classification, ADR-0016 |
| LF-INV-PRIV-002 | Restricted data never reaches cloud AI and is never shared implicitly | Data classification |
| LF-INV-PRIV-003 | Classification is enforced at every egress point | AI Context Builder, sync, share |

## 8. Self-check

- [x] Every aggregate in section 1 has a context doc (or is a stub) in [../domains/](../domains/).
- [x] Every value object referenced by a context doc is defined in section 2 or the Time Kernel doc.
- [x] Every event name used in a context doc appears in section 5.
- [x] Every invariant ID used in a context doc appears in section 7.
