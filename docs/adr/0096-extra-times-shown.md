# ADR-0096: Extra times are read wherever the plan is read
- Status: Accepted (P06c E2, 2026-11-04)
- Date: 2026-11-04
- Deciders: the owner; implementation
- Related: [ADR-0095](0095-extra-times.md) (the record and its commands), [ADR-0031](0031-events-calendars-conflicts.md) (conflicts), [p06c-plan.md](../roadmap/p06c-plan.md)
## Context
E1 stored extra times but nothing showed them. A task's agenda item was known by (task, original date); an extra time can share a date with an occurrence, and two can share a day.
## Decision
1. **An extra time is one more item** in the agenda of a task and in the events of the Calendar. `AgendaItem` and `EventItem` get `extraId` (null for an occurrence of the rule) and `isExtra`. `originalDate` of an extra item is only the date it is on.
2. **Keys.** The key of a timed item in the conflict list is `task:<id>@<originalDate>` for an occurrence and `task:<id>#<extraId>` for an extra time (same for events). The two forms cannot collide. `taskOccurrenceKey` and `eventOccurrenceKey` take an optional `extraId`; every widget key built on them does too.
3. **Where they show:** Today, Upcoming, the Timeline, the Calendar (day, week, month), the conflicts, the reminders and the assistant. The queries read `extra_times` by `firstDate`/`lastDate`, like schedules, and refresh when the table changes.
4. **Done.** An extra item of a task is done when its own tick is set or the whole task is done (Q2). A done extra time is not a conflict and does not remind.
5. **Not overdue.** An extra time of the past is not listed as overdue in Today (only one-off tasks are).
6. **Reminders.** An extra time reminds with the rules of its item, under its own key `<type>:<id>/<extraId>#<rule>@<date>`. A cancelled event, a done or cancelled task, a trashed or archived item remind of nothing, extra times included.
7. **Assistant.** The extra times of a day are fixed times (busy) in "Plan my day". They are not named records sent to the model, because several can fall on one day and none is the item's rule. The chat does not propose extra times yet.
8. **Habits** ignore extra times: their periods come from the rule only (Q3). An extra time of a habit with automatic completion cannot be ticked.
9. **Menus on an extra time (before E3):** "Skip this time" removes it; its box ticks it. It has no "Move this time" or "Edit the whole repeat" until E3, where "Move this time" becomes a free edit.
## Consequences
- The same task can have an occurrence and an extra time at one hour; both show, and they overlap as two items.
- The total returned is still bounded by the Time Kernel limits; there is no limit on how many a task has.
