# ADR-0097: An extra time may repeat
- Status: Accepted (P06c E3, 2026-11-04; the owner chose option B in [p06c-plan.md](../roadmap/p06c-plan.md) §5)
- Date: 2026-11-04
- Deciders: the owner; implementation
- Related: [ADR-0095](0095-extra-times.md) (the record), [ADR-0096](0096-extra-times-shown.md) (where it shows), [ADR-0007](0007-single-schedule-with-derived-occurrences.md) (the schedule and its repeat)
## Context
A task or an event has one schedule with one repeat rule. The owner wants a second repeating series on the same item: study Tuesdays 9-11 by the rule, and also Thursdays 13-15 for four weeks. An extra time (ADR-0095) was one time that did not repeat.
## Decision
1. **An extra time may carry its own repeat rule** (schema v21): the same columns as a schedule (`frequency`, `interval`, `weekdays`, `endKind`, `endDateRule`, `endCount`, `monthEndRule`, `weekStart`). All null is one time, as before. `lastDate` becomes nullable (a repeat with no end); `firstDate`/`lastDate` are derived from the time and the rule on every write and checked on every read (`readExtra`), as for a schedule.
2. **One time of a repeating extra time** is changed and ticked by its own rows, keyed by the extra's id, so they never meet the item's own:
   - a change (skip, move; for an event also cancel and rename) is an `exception` row with `subjectType = 'extraTime'` and `subjectId = <extraId>`, id `extraTime:<extraId>@<date>`;
   - a task's tick is a `completion` row with a new column `extraId`, id `extra:<extraId>@<date>`, `taskId` the task. The task's habit ignores rows with an `extraId` (Q3).
   - A time that does not repeat keeps `doneAt`. A repeating one is ticked one time at a time (a tick on the whole is refused).
3. **Commands** (on the item's own handler, so the item moves forward): `setExtraException`, `clearExtraException`, `setExtraOccurrenceDone`, besides ADR-0095's. The date must be a time of that rule; the item's own handler decides what a change may be (a task skips or moves; an event also cancels and renames). Removing an extra time tombstones its changes and ticks in the same operation.
4. **Keys.** An occurrence key is `task:<id>@<date>` for the item's rule and `task:<id>#<extraId>@<date>` for an extra time (same for events), since one extra time now has many dates. This replaces ADR-0096's `task:<id>#<extraId>`.
5. **Reads.** Agenda, Calendar, reminders and the assistant expand an extra time with the Time Kernel like a schedule (rule, its changes, a window), including times moved into the window from outside its range. A skipped or ticked time reminds of nothing. A done task has every time done.
6. **Goes with its item:** purge tombstones the changes and ticks too; a space move takes the changes (the ticks go by the task); export and restore check the extra time as a command would have written it, accept a change or a tick that points to an extra time, and read a file of schema 20 or older with none of the new fields. Sync merges an extra time as a whole value (a rule must not be half of each side).
7. **Migration v20 → v21:** the table is rebuilt for the nullable column and the new ones (existing rows are one-off times); the tick table gets `extra_id`.
8. **UI.** The occurrence menus gain "Add another time…", and on an extra time its own Skip, Move, Undo, "Edit this repeat…" and "Remove all of these times" (a one-off one: "Change this time…"). The task page and the event editor list "Other times" with add, change (tap) and remove. The editor is the schedule editor's fields without a deadline or reminders (reminders are the item's).
## Consequences
- An item can have any number of series; each has its own skips, moves and ticks. Changing the item's own repeat never touches them.
- Focus sessions for an occurrence of an extra time are not offered (a session is for a time of the item's own rule); a session can still be started for the task.
- Older builds on another device cannot read the new shape of the record until updated (as for every record schema change).
