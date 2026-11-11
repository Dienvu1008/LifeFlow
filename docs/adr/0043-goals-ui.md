# ADR-0043: Goals in the UI (the Goals tab, the goal page, a task's goals)

- Status: Accepted (P03 task T6c, 2026-11-11; within the owner-accepted P03 plan, decisions D11, D12). The device check is in the owner's single pass over the P03 screens before T7.
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0040](0040-goals-and-projects.md) (commands, links, derived progress), [ADR-0041](0041-habits-ui.md), [ADR-0042](0042-focus-ui-bar-notification-recovery.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T5 gave the goal and project commands and the derived progress. T6c shows them, completing the P03 screens.

## Decision
**The 5th tab "Goals"** (D12): Tasks, Calendar, Goals, Profiles, Settings, in the bottom bar and the rail; route `/goals`.
- Three lists: **Active** (active and done), **Archived**, **Trash** (each item has "Restore").
- Each goal shows its kind, status, target date and progress. The progress is a bar plus a text: "60% · 3 of 5 milestones", "50% · from linked tasks and habits", or **"No progress yet"** (never 0 % when nothing counts). It is read as one spoken label.
- "+" creates a goal or a project (title, optional description, a start date for a project only, a target date) and opens it.

**The goal page:**
- **Details:** kind, status, dates, description.
- **Menu:** Edit…, Mark as done / Mark as active, Archive / Unarchive, Move to trash.
- **Archived:** read only, with a line saying how to change it.
- **Trash:** closes the page and says that the tasks and events are kept (LF-INV-GOAL-002).
- **Milestones** (D11, OQ-GOAL-1): ticked by hand, with due dates. Edit and remove are in each one's menu. With milestones, a line explains that progress counts them.
- **Links:** each item shows its kind (task, habit, event) and state. A habit shows its rate since it was linked; an event is "not counted in progress"; trashed, cancelled or removed items are "not counted". Each link has Unlink.
- **"Link a task or habit"** lists the profile's tasks not linked yet. **"Link an event"** lists the events from 30 days ago to 6 months ahead, once per event (not per occurrence). Refusals, such as another workspace (LF-INV-GOAL-003), show as a message.

**A task's "Goals…"** (task menu, D12): the live goals, each with a checkbox showing whether this task is part of it. Ticking links it and unticking unlinks it; the task itself is never changed.

No progress is computed in the UI. It is the `GoalView` value derived below the port (LF-INV-GOAL-001, AP-12).

## Consequences
- An event cannot yet be linked from the event editor; it is linked from the goal page.
- With only an hour or two of use, most goals will show "No progress yet". That is intended: progress needs a milestone or a finished linked item.

## Verification
- `packages/ui/test/goal_flow_test.dart` (8 widget tests):
  - the tab: empty, a new project (title required, start only for a project, a start dropped when switched back to a goal);
  - progress text and spoken label; archived and trash lists;
  - milestones: add, tick, edit, remove;
  - links: states, picking a task (linked ones hidden), an event (once per event), unlink;
  - status: done, archived read only, unarchive, edit, trash with the "kept" message, restore;
  - a task's "Goals…": empty, tick, untick;
  - five tabs at a phone width with a large font.
- `shell_test.dart`: the destination order, with Goals at index 2.
- `apps/lifeflow_app/test/app_integration_test.dart` (real stores): a goal made in the tab links a task (0 %), and a ticked milestone gives 100 %. After the trash, the goal has a tombstone, its link and milestone remain, and the task is unchanged.
- UI mutations: 10/10 killed.
