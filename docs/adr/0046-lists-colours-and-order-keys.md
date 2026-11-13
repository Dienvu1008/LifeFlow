# ADR-0046: Lists, colours and fractional order keys (data for the Overview)

- Status: Accepted (P03 UX task U2, 2026-11-13; owner decisions U-D1 and U-D4 in [p03-ux-plan.md](../roadmap/p03-ux-plan.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0011](0011-command-gateway-single-mutation-path.md) (single mutation path), [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md) (atomic set), [ADR-0025](0025-profile-export-and-restore.md) (export / restore), [ADR-0026](0026-reopen-and-trash-with-subtasks.md) (trash with subtasks), [ADR-0045](0045-ui-foundation-theme-density-i18n.md) (palette), [invariant-catalog.md](../invariants/invariant-catalog.md) (LF-INV-ORDER-001–004)

## Context
The Overview (U3) shows lists with their tasks and events, then the items in no list. Users drag to reorder, to move an item into or out of a list, and to change a task's level (up to 4). Items carry a colour from a fixed palette. Until now the store had a `task_lists` table and `tasks.task_list_id` / `tasks.sort_order` that nothing used, and events had no list, order or colour. A drag must never lose or double an item (R-DATA-LOSS), and the data must stay ready for sync (P04).

## Decision
**Schema v7** (additive, VS-04):
- `color_index` (nullable int, 0–11) on `task_lists`, `tasks` and `events`. The data keeps the index only; the tones belong to the theme (ADR-0045), so a theme change never rewrites data.
- `order_key` (text, fractional key) on the same three tables; `events.list_id` (nullable).
- The upgrade keys every existing row in the order the app showed (creation, then rowid), trashed rows included. An export older than v7 gets keys the same way (creation, then file order) and no colours. `tasks.sort_order` stays unused.

**Containers (LF-INV-ORDER-001).** The lists of a workspace; the top-level items in no list (tasks and events together); the top-level items of a list; the subtasks of a task. A subtask keeps no list of its own: it follows its top-level task, so moving a task with subtasks into a list rewrites one row. An item in a list that is not live (possible only after a merge restore) shows and orders as in no list. Items show by order key, then id.

**Fractional order keys (LF-INV-ORDER-002).** `domain/order_key.dart` implements the known fractional-indexing scheme: an integer part whose first character gives its length, then a base-62 fraction without a trailing zero. Keys compare as plain strings. Appending only increments the integer part (10 000 appends stay at 4 characters). A drop sends the id of the item it lands after (`afterId`, null = first); the handler reads the container and computes one key between that item and the next larger key. If `afterId` is not in the container any more, the drop is refused ("out of date") rather than guessed. Equal keys (two devices) are kept together and a drop goes after all of them; the id breaks the tie in display.

**Commands** (one per change, through the gateway, atomic set):
- `ListCommandHandler` (new, entity `taskList`): `create` (at the end), `rename`, `setColor`, `move`, `trash`, `restore`.
- Task: `move` (place + `afterId`), `setColor`; `create` takes a list for a top-level task and goes to the end of its place; `reparent` (the task editor) appends at the end of the new place, and to the top level it goes to the list of its top-level task.
- Event: `move` (a list or none + `afterId`), `setColor`; `create` takes a list.
- **Depth with the subtree (LF-INV-TASK-002, amended):** a move counts the subtasks that move along; the deepest must stay within 4. The old reparent rule checked only the new parent's depth.
- **An event is never under a task (LF-INV-ORDER-003, U-D1):** refused by the event handler (untrusted payload) and by the service; an event id is not accepted as a parent.

**Trash and restore of a list (LF-INV-ORDER-004).** Trashing a list trashes its top-level tasks with all their live subtasks and its events, at one tombstone time and actor, each with its own version and outbox row. Restoring the list brings back the rows with that time and actor; an item trashed on its own before stays in the trash. An event restored on its own while its list is in the trash comes back in no list. When a task is trashed alone, its subtasks take its place, in their order (its parent, or its list at the top level).

**Export / restore.** Colours must be palette indexes and keys well-formed (`organize_rows.dart`); an event's list is an optional reference (refused in a file when unknown, cleared on a merge when the list will not exist).

**Expand state.** The expanded lists and tasks are a device setting (`SettingsService.expandedItems`, registry key `ui.overview.expanded`): not profile data, not synced, not exported. An unreadable value only loses the expand state.

**Application surface.** `OverviewQueries` (`watchLists`, `watchEvents`) and `OverviewService` (lists, moves, colours) in `application/overview.dart`; `TaskView` gains `listId`, `colorIndex` and `orderKey`; `TaskQueries.watchTasks` orders by key. The UI wiring comes with the Overview (U3).

## Consequences
- A drop is one row: concurrent moves of different items on two devices never conflict; moves of the same item conflict on its version, as any edit.
- The handlers read a container per drop (a few dozen rows in practice); no index is added yet.
- Keys grow only when items are dropped into the same gap many times (about one character per six drops there). A rebalance is not needed at personal scale; it can be added later as one command per container if keys ever get long.
- Restoring a list by tombstone time has second precision: an item trashed on its own within the same second as its list, by the same actor, comes back with it. Accepted.
- Verification: `order_key_test` (keys, 3 000 random insertions, ties), `task_rules_test` (subtree depth), `overview_test` (containers, one-row drops, refusals, list trash/restore, stranded items, expand setting), `organize_property_test` (3 × 250 random drops through the real gateway against a model), `overview_export_test` (GS-20, v6 files, untrusted fields), the atomic set (FF-ARCH-06) with every new op, and the v1–v6 upgrade tests.
