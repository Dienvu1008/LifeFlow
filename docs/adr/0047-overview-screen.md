# ADR-0047: The Overview: lists, a task tree, drag and drop with menu equivalents

- Status: Accepted (P03 UX task U3, 2026-11-13; owner decisions U-D1, U-D4, U-D9 in [p03-ux-plan.md](../roadmap/p03-ux-plan.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0046](0046-lists-colours-and-order-keys.md) (data and commands), [ADR-0045](0045-ui-foundation-theme-density-i18n.md) (theme, palette, ARB), [ADR-0044](0044-navigation-drawer-on-phones.md) (navigation), [ADR-0026](0026-reopen-and-trash-with-subtasks.md) (trash with subtasks)

## Context
The owner wants one place that shows everything to do: lists with their tasks and events, then what is in no list, with a task tree of 4 levels, drag and drop in the way of AppFlowy documents, and a colour per item (after the owner's app *my_time_manager*). The data and the commands exist (ADR-0046). The Timeline (U4) replaces Today and Upcoming, and the navigation is rebuilt in U6.

## Decision
**Place.** The Overview replaces the "All" view of the Tasks tab (the first segment is now "Overview"). Today, Upcoming and Habits stay as segments until U4 and U6.

**Rows** (`overview_tree.dart`, pure). Each list, then (unless collapsed) its top-level tasks and events in order; a heading "Not in a list" (only when there are lists); the items in no list. A task shows its subtasks unless collapsed. The toggle shows only when there is something to fold. A row is one line: a drag handle, the toggle, a checkbox (task) or an event icon, the title, the schedule or the period as small text, the menu. A list's row shows its item count. The colour is a 4 dp bar on the left of the row (U-D4); the background stays neutral.

**Collapse is remembered per device, as the set of collapsed ids** (`SettingsService.collapsedItems`, key `ui.overview.collapsed`; amends ADR-0046, which stored the expanded ids). Everything else shows expanded, so a new subtask or a moved item is never hidden; a list or a task that receives an item opens.

**Drag and drop.** A row is dragged by its handle (pointer and touch), or by a long press anywhere on it (touch only). The part of the row under the pointer decides:
- the upper quarter: before the row (as after the row above it, at this row's level);
- the lower quarter: after the row; the middle of a task: the last subtask of that task;
- a list's row: the first item of that list (its upper 30 %: before it).
- The horizontal movement since the drag began changes the level after a row, one level per 24 dp: right makes the item the row's first child, left moves it up (after the matching ancestor).
- A line (or a highlight for "into") shows where it will land; nothing shows where it cannot go.

`resolveDrop` turns this into one command (`moveTask`, `moveEvent` or `moveList`) or none. None when the item would land in its own subtree, deeper than 4 levels with its subtasks, an event under a task (U-D1), or where it already is. The store checks the move again (ADR-0046); a refusal is shown as a message.

**Menu equivalents (WCAG 2.5.7).** Every move is also in the row's menu, offered only when possible: Move up, Move down, Make it a subtask of the task above, Move it up a level, Move to list… (a top-level item). Dragging is never the only way.

**Row actions.** Task: Focus, Rename, Schedule, Habit and target, Goals, Add subtask (not at level 4), Colour, the moves, Move to trash (with the subtask question, ADR-0026). Event: tap or Edit opens the editor; Colour, the moves, Move to trash with Undo. List: Add task, Add event, Rename, Colour, the moves, Move to trash with Undo (its contents go and come back with it).

**Adding.** The + is a small speed dial: New list, New event, Add task (a task in no list). A list's menu adds a task or an event to that list; `openEventEditor` takes the list.

**Colours.** A dialog with the 12 palette colours (named for screen readers) and "No colour".

**Strings.** All new strings are in the ARB (`ov…` keys), none raw; moving the old "All" view out of `tasks_screen.dart` lowers its FF-ARCH-10 count (34 → 20).

## Consequences
- The layout and the drop rules are pure functions with their own tests (`overview_tree_test`); the widgets are tested through the full app with fake ports (`overview_flow_test`: rows, collapse remembered, the + menu, list menu, colours, menu moves, a drag by the handle onto a task, a drag left after a deep row, a long-press drag onto a collapsed list that opens, a list trashed and restored, a refused move), and once on real stores (`app_integration_test`: a list, a task in it and a move, with their audit actions).
- The drop zones are proportions of the row, so they work with large text; the indentation step is fixed at 24 dp.
- No auto-scroll while dragging near the edge of a long list yet; the menu moves cover long distances. To be reviewed in the dogfooding pass.
- Events created from the Calendar appear in the Overview in no list; events are not shown as timed blocks here (that is the Calendar, U5).
