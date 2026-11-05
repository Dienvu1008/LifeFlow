# Domain: Task Management

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Classification: Core. Phase: P01. In MVP: yes.
- Related: [../architecture/domain-model.md](../architecture/domain-model.md), [ADR-0006](../adr/0006-habit-is-a-task-capability.md), [ADR-0007](../adr/0007-single-schedule-with-derived-occurrences.md), [planning-scheduling.md](planning-scheduling.md), [execution-measurement.md](execution-measurement.md)

## 1. Purpose
Represent what the user intends to do and manage its lifecycle. Task is the hub concept (principle P1) but does not absorb time rules (Time Kernel), actual time spent (Execution), or events (Calendar).

## 2. Aggregate roots and boundaries
- **`Task`** (root): one task and its capability value objects, plus the identities of its direct Subtasks. A Subtask is itself a `Task` row with a `parentTaskId`; the parent aggregate owns the ordering and the parent-child link, but each Subtask is loaded and mutated as its own aggregate to keep transactions small. Completion that spans parent and children is coordinated by a domain service, not a single mega-transaction.
- **`TaskList`** (root): a named grouping. Tasks reference a list by `taskListId`; deleting a list does not delete its tasks (they become unlisted).

[Decision] The parent↔child link is modeled so that a parent references child IDs (ordered) and each child stores `parentTaskId`. The "aggregate" for a write is a single Task; hierarchy-wide operations (complete-all, re-parent) are domain services with explicit, bounded steps.

## 3. Entities and value objects
- `Task`: `taskId`, `workspaceId`, `ownerId`, `title`, `status`, `priority`, `tags: Set<Tag>`, `taskListId?`, `parentTaskId?`, `childOrder: List<TaskId>`, capabilities (below), `version`, timestamps, tombstone fields.
- Capabilities (value objects, all optional except CompletionPolicy):
  - `ScheduleRef` → one `ScheduleSpec` id (+ optional `RecurrenceRule` id) in the Time Kernel sense (ADR-0007).
  - `MeasurableTarget` → `targetType {atLeast, atMost, about}`, `Quantity` bounds, `unit`, `aggregation {sum, max, latest, average}`, `period {day, week, customCycle}`.
  - `CompletionPolicy` → `{manual, automatic, hybrid}` + rule (default `manual`).
- `Tag`: normalized label value object.
- Status enum (Decision): `inbox`, `todo`, `inProgress`, `done`, `cancelled`. Trash and archive are orthogonal flags (an archived or trashed task keeps its status).

## 4. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-TASK-001 | Task identity is stable across updates, move, binding, restart | `Task` (ID is immutable) |
| LF-INV-TASK-002 | A `CreateTask`/`Reparent` command may not place a task deeper than the current depth limit; the limit is checked at command time, not stored, so changing the limit is not a data migration | `CreateTask` / `Reparent` command |
| LF-INV-TASK-003 | The parent graph is acyclic | `Reparent` (rejects if the new parent is the task or a descendant) |
| LF-INV-TASK-004 | Status transitions follow the allowed graph | `Task.transition` |
| LF-INV-TASK-010 | A measurable task's completion respects its MeasurableTarget + CompletionPolicy | completion service + Execution events |
| LF-INV-TASK-011 | A trashed task is excluded from active views but keeps its data until purge | query scoping + tombstone |

[Decision, resolves OQ-R1, owner-confirmed 2026-11-04] Maximum subtask depth is **4 levels** (a root plus three nested levels). The limit is checked **at command time** (`CreateTask`/`Reparent`), never stored on the row. Raising the limit later to some N is **not a migration**: existing subtasks at the old depth remain valid, and only new `CreateTask`/`Reparent` commands are checked against the current limit. Lowering the limit does not retroactively invalidate existing deeper hierarchies; it only prevents creating or moving into a depth beyond the new limit. See LF-INV-TASK-002.

[Decision, resolves OQ-R3, owner-confirmed 2026-11-04] Completing a parent with open Subtasks is **two distinct commands**, not a boolean flag on one command, so audit and outbox can tell them apart:
- `CompleteTaskWithDescendants` — completes the parent and all open descendants (bounded by the depth limit).
- `CompleteTaskOnly` — completes the parent only, leaving subtasks open. This command **must write a warning note into the audit entry** recording that open subtasks remained at completion time (count and IDs).
There is no silent cascade and no single command that branches on a flag. The UI chooses which command to issue based on the user's explicit choice.

## 5. Domain services
- `TaskHierarchyService`: reparent with cycle and depth checks; complete-all descendants (bounded walk).
- `TaskCompletionService`: toggle/set completion; for measurable tasks, derive completion from the current period evaluation (reads Execution summaries) under the CompletionPolicy. Never writes Measurements.
- `HabitView` (query helper, not a mutation): selects Tasks that have both a `RecurrenceRule` and a `MeasurableTarget` (ADR-0006).

## 6. Commands
| Command | Actor | Args | Preconditions | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|---|
| `CreateTask` | owner / Learning / Vocabulary (via gateway) | title, workspaceId, parentTaskId?, listId?, capabilities? | title non-empty; parent exists and depth < max | new Task v1 | `TaskCreated` | by `operationId` | n/a |
| `UpdateTask` | owner | taskId, changed fields | task exists, not purged | updated Task | `TaskUpdated` | by `operationId` | `expectedVersion` |
| `Reparent` | owner | taskId, newParentId? | no cycle; depth ok | moved Task | `TaskReparented` | by `operationId` | `expectedVersion` |
| `CompleteTaskWithDescendants` | owner | taskId | valid transition; depth bounded | parent + open descendants done | `TaskCompleted` (one per completed task) | by `operationId` | `expectedVersion` on the parent |
| `CompleteTaskOnly` | owner | taskId | valid transition | parent done, subtasks untouched | `TaskCompleted` | by `operationId` | `expectedVersion` |
| `SetMeasurableTarget` | owner | taskId, target | valid bounds (min ≤ max for `about`) | capability set | `TaskUpdated` | by `operationId` | `expectedVersion` |
| `TrashTask` / `RestoreTask` | owner | taskId | — | tombstone set/cleared | `TaskTrashed`/`TaskRestored` | by `operationId` | `expectedVersion` |
| `PurgeTask` | owner / retention job | taskId | tombstoned past retention | hard delete | `TaskPurged` | by `operationId` | `expectedVersion` |
| `EvaluateHabitPeriod` | system (on `MeasurementRecorded`) | taskId, period | measurable task | period state | `HabitPeriodEvaluated` | by (taskId, period) key | derived |

## 7. Queries / read ports (published)
- `TaskReader`: `exists(TaskId)`, `TaskSummary(id, title, status, workspaceId)` — consumed by Calendar, Execution, Goals.
- `ScheduledItemReader`: occurrences of scheduled tasks in a window (delegates to the Time Kernel) — consumed by Calendar overlays.

## 8. Domain events
`TaskCreated`, `TaskUpdated`, `TaskReparented`, `TaskCompleted`, `TaskTrashed`, `TaskRestored`, `TaskPurged`, `HabitPeriodEvaluated`, `RecurringSeriesChanged`, `OccurrenceExceptionAdded` (shared with Calendar).

## 9. Repository contract
```
TaskRepository:
  getById(TaskId): Task?
  childrenOf(TaskId): List<Task>
  bySubtree(TaskId): List<Task>     // bounded by max depth
  activeInList(TaskListId): List<Task>
  save(Task): void                  // via command handler only
TaskListRepository:
  getById(TaskListId): TaskList?
  save(TaskList): void
```

## 10. Open questions
- OQ-TASK-1: do Subtasks carry their own schedule/target, or only the root? Proposal: yes, a Subtask (being a Task) may, consistent with the legacy `subtaskId` planning. Confirm in P01.
- OQ-TASK-2: are tags workspace-scoped value objects or a managed vocabulary? Proposal: free value objects in MVP.

## 11. Self-check
- [x] Every command lists events, idempotency and concurrency.
- [x] OQ-R1 resolved: depth limit is a command-time check, not stored; raising it is not a migration.
- [x] OQ-R3 resolved: two distinct complete commands (not a flag); `CompleteTaskOnly` writes an audit warning.
- [x] Habit is a capability combination, not a new aggregate (ADR-0006).
- [x] No command mutates Execution or Time Kernel state.
