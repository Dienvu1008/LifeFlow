# Domain: Goals and Projects

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Classification: Supporting. Phase: P03. In MVP: yes (owner decision OQ-S2).
- Related: [task-management.md](task-management.md), [execution-measurement.md](execution-measurement.md), [../product/requirements.md](../product/requirements.md) FR-GOAL

## 1. Purpose
Group intent over a longer horizon without turning it into a Task (principle P1). Progress is derived from linked Tasks and Habits; it is never written back onto a Task.

## 2. Aggregate roots and boundaries
- **`Goal`** (root): a goal, its `Milestone`s and its `LinkedResource`s. Boundary: the goal and its milestones/links.
- **`Project`** (root): a project and its `LinkedResource`s (and optional milestones if reused). Boundary: the project and its links.

## 3. Entities and value objects
- `Goal`: `goalId`, `workspaceId`, `ownerId`, `title`, `description?`, `status {active, done, trashed}`, `targetDate: LocalDate?`, `version`, timestamps, tombstone.
- `Milestone` (child of Goal): `milestoneId`, `title`, `dueDate: LocalDate?`, `isCompleted`, `completedAt: Instant?`, `order`.
- `Project`: like Goal plus `startDate: LocalDate?`.
- `LinkedResource` (value object): `{type: {task, habit, event, note(P05), ...}, id}`. A link does not transfer ownership.

## 4. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-GOAL-001 | Progress is derived read-only; no Goal operation writes to a Task | progress service reads only |
| LF-INV-GOAL-002 | Deleting a Goal/Project removes links, not the linked Tasks | `TrashGoal`/`DeleteLink` |
| LF-INV-GOAL-003 | A linked resource in another workspace is rejected | link command checks `workspaceId` (relevant from P04) |

## 5. Domain services
- `GoalProgressService` (pure, reusable from legacy): milestone ratio = completed-live-linked-tasks / total; goal ratio = done-milestones / total, else direct-linked-task ratio. Reads `TaskReader` and Execution summaries; never writes.

## 6. Commands
| Command | Actor | Args | Preconditions | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|---|
| `CreateGoal` / `CreateProject` | owner | title, ... | — | new v1 | `GoalCreated` | by `operationId` | n/a |
| `AddMilestone` | owner | goalId, title, dueDate? | goal exists | milestone added | `GoalProgressRecomputed` | by `operationId` | `expectedVersion` |
| `LinkResource` | owner | goalId/projectId, LinkedResource | resource exists in same workspace | link added | `GoalProgressRecomputed` | by (goalId, resourceRef) | `expectedVersion` |
| `UnlinkResource` | owner | goalId, LinkedResource | link exists | link removed (resource untouched) | `GoalProgressRecomputed` | by (goalId, resourceRef) | `expectedVersion` |
| `CompleteGoal` | owner | goalId | — | status done | `GoalCompleted` | by `operationId` | `expectedVersion` |
| `TrashGoal` / `RestoreGoal` | owner | goalId | — | tombstone | `GoalTrashed` | by `operationId` | `expectedVersion` |

Progress recomputation also runs when it receives `TaskCompleted` / `MeasurementRecorded` for a linked resource (application-layer handler), emitting `GoalProgressRecomputed`.

## 7. Queries / read ports
- `GoalProgress(goalId) → ratio + breakdown` (derived).
- `GoalsLinkingResource(resourceRef) → List<GoalId>` (for showing "part of" on a Task).

## 8. Domain events
`GoalCreated`, `GoalCompleted`, `GoalTrashed`, `GoalProgressRecomputed`.

## 9. Repository contract
```
GoalRepository:
  getById(GoalId): Goal?
  linking(resourceRef): List<Goal>
  save(Goal): void
ProjectRepository:
  getById(ProjectId): Project?
  save(Project): void
```

## 10. Open questions
- OQ-GOAL-1: can a Milestone be completed manually independent of its linked tasks? Proposal: yes, a manual `isCompleted` overrides the derived ratio for that milestone (as in legacy). Confirm in P03.

## 11. Self-check
- [x] Progress is derived; no write-back (LF-INV-GOAL-001).
- [x] Links use `LinkedResource`, the same contract documents will reuse (P05).
- [x] Depends only on Task Management and Execution and Measurement.
