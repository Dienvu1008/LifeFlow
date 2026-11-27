# ADR-0095: Extra times ("Add another time")
- Status: Accepted (P06c E1, 2026-11-04; the owner's request and answers, [p06c-plan.md](../roadmap/p06c-plan.md))
- Date: 2026-11-04
- Deciders: the owner; implementation
- Related: [ADR-0031](0031-events-calendars-conflicts.md) (events and their occurrences), [ADR-0094](0094-archive-and-trash.md) (what a purge and a move take with an item)
## Context
A task or an event had one schedule, with an optional repeat rule. Its occurrences were known by their original date, and a series could only be changed as a whole, or one occurrence at a time by skipping or moving it. The owner wanted to add a time outside the rule: study every weekday 9–11 for fifty times, then one day add 13–15 on a day of his choice.
## Decision
1. **An extra time is a record of its own** (`extraTime`, table `extra_times`, schema v20), belonging to a task or an event: its start (a day, with or without hours), an optional end, and, for a task, its own tick. It has an id of its own. It has no title: it uses its item's title, list, colour, notes and reminders.
2. **Why not a second schedule row, or an occurrence with a date:**
   - an occurrence is known by its original date, and a task's skip, move and done tick are keyed by it; an extra time on the same day as an occurrence would share them;
   - several extra times may fall on one day.
3. **It is independent of the rule.** Changing the whole repeat, or clearing the schedule, leaves the extra times. The series' skips, moves and ticks are untouched by adding, changing or removing one.
4. **Commands** run on the item's own handler, so the item moves forward with each (the optimistic version) and one operation writes the item, the extra time, the audit row and the outbox rows: `addExtra`, `changeExtra`, `removeExtra`, and for a task `setExtraDone`.
   - The time is given as the columns of a schedule, and checked again in the handler (the payload is untrusted): a start, maybe an end, no repeat, no deadline, a valid date range. Rejected otherwise.
   - A task whose completion is derived from measurements cannot have a time ticked by hand.
   - An extra time is changed only through its own item; another item's id is refused.
   - **No limit** on how many a task or an event has (the owner's answer). A query still returns at most its usual bound.
   - A removal is a tombstone (SYNC-004), never a hard delete.
5. **It goes with its item:**
   - sync and shared spaces: a record kind, written after its item;
   - export and restore: part of the file; a file of schema 19 or older reads with none;
   - delete for good (ADR-0094): its extra times are tombstoned with the schedule;
   - a move to a shared space: they move with the item;
   - trash and archive: they follow the item (they are shown only through it).
6. **What this step does not do:** show them (the agenda, Calendar, Timeline, reminders and the assistant read them in E2), edit them in the screens (E3), or offer "Schedule … here" on the Calendar for scheduled tasks and events (E4).
## Consequences
- Older app versions on other devices cannot read the new kind: a sealed record of schema 20 is refused by an older build until it is updated, as for every earlier record schema change.
- A done task that is given another time is reopened by the caller first (the screens, E4); the command does not reopen it.
