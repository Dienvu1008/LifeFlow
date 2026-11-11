# ADR-0040: Goals and projects: commands, links and derived progress

- Status: Accepted (P03 task T5, 2026-11-11; within the owner-accepted P03 plan, decision D11)
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0036](0036-execution-measurement-goal-rules.md) (`goalProgress`), [ADR-0037](0037-storage-v5-execution-measurement-goals.md) (tables), [ADR-0039](0039-habits-targets-measurements-period-results.md) (habit results), [goals-projects.md](../domains/goals-projects.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T1 gave the pure progress function and T2 the tables. T5 adds the commands and reads for goals and projects, their milestones and their links to tasks, habits and events.

## Decision
**The goal is the aggregate.** `GoalCommandHandler` (entity `goal`) runs every change through the gateway. A milestone or link change is written in the same transaction, moves the goal's version, and adds its own outbox row (entity `milestone` / `goalLink`). Ops:
- create (kind goal or project)
- update, setStatus (active / done / archived), trash, restore
- addMilestone, updateMilestone, setMilestoneDone (by hand only, OQ-GOAL-1), removeMilestone (a tombstone)
- link, unlink (a tombstone; linking again revives the row)

**Rules:**
- **Titles and dates:** a title is required (at most 200 characters). Only a project has a start date. The target date is not before the start.
- **Archived:** an archived goal can only change its status. A trashed goal can only be restored.
- **Links:** a link needs a live task or event in the goal's workspace (LF-INV-GOAL-003), and is refused if it already exists. Its id is `<goal>|<type>:<item>` (ADR-0037).
- **Trash keeps everything:** trashing a goal keeps its milestones and links, so a restore brings them back. Linked tasks and events are never touched (LF-INV-GOAL-002). A goal command never writes a task or an event.

**Progress is derived on every read** by the domain's `goalProgress`, from the linked items' own states. Nothing is stored or written back (LF-INV-GOAL-001).
- **With milestones:** done milestones / all milestones.
- **Without milestones:** linked tasks count 1 when done and 0 when open; trashed, cancelled or missing tasks do not count. A linked **habit** counts its successes / judged results whose key is on or after the link date (ADR-0039 results, stored or derived). Linking again restarts that count. Events are shown with their state, not counted.
- **Nothing to count:** no progress (null), not 0 %.

**Reads** (`GoalQueries`): `watchGoals` (trash left out, archived only when asked; it follows goal, milestone, link, task, event and habit-result changes), `goal`, `goalsOf` ("part of" for a task or an event, trashed goals left out), and `trashed`.

## Consequences
- T6c builds the Goals tab (D12) on these ports.
- Progress costs one read per linked item, plus the habit's results for a linked habit. That is fine for personal-scale goals; caching is not needed in the MVP.
- Export and restore already carry goals, milestones and links with their reference checks (ADR-0037).

## Verification
- `packages/infrastructure/test/goals_test.dart` (8 tests):
  - GS-21: derived progress with tasks and a habit, a pure function, no task row changed by goal commands or reads, trash keeps the tasks, restore brings the links back.
  - A habit counted since its link, and again after re-linking.
  - Milestones over links, done by hand, update and remove, the order they were added in, another goal's milestone refused.
  - GOAL-003 (another workspace); unknown, trashed and duplicate links; unlink and relink; an event shown, not counted; "part of".
  - Date, status, archived and trash rules; audit, outbox rows and a clean export.
- `atomic_set_test.dart`: 12 goal steps.
- Mutations: 17/17 killed.
