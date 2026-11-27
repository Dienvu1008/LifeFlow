# P06c plan: extra times ("Add another time")
- Status: **Agreed by the owner 2026-11-04** (answers in §4). E1 merged ([ADR-0095](../adr/0095-extra-times.md)). E2 merged ([ADR-0096](../adr/0096-extra-times-shown.md)). E3 built ([ADR-0097](../adr/0097-repeating-extra-times.md)): an extra time may repeat (owner's choice B); the editor, Other times and the menus. Next: E4.
- Date: 2026-11-04
- Why: before using the app on the devices, the owner found that planning a repeating task or event is too rigid. A series changes as a whole, and the only way to depart from it is "Skip this time" or "Move this time". He wants to add times outside the rule, and to schedule from the Calendar a task that already has a schedule, and an event.
- Inputs:
  - [p06b-plan.md](p06b-plan.md) (the screens this touches: Calendar slots, Timeline, the task page, the event editor);
  - [ADR-0031](../adr/0031-events-calendars-conflicts.md) (events, occurrences, conflicts) and the schedule model of P02 (ADR-0007: one schedule per task or event, the occurrence's identity is its original date);
  - [ADR-0094](../adr/0094-archive-and-trash.md) (what a purge and an archive take with an item).

## 1. What the owner asked (2026-11-04)
1. **Unchanged:** a task or an event can repeat by a rule, and "Skip this time" and "Move this time" stay as they are.
2. **New, in the plan of a task or an event: "Add another time"**, a time outside the rule. His example: AI study every weekday 9–11 for about 50 times; one day he has more time and adds 13–15 on any other day of the series.
3. **New, on the Calendar** (day and week views): "Schedule a task here" also offers tasks that already have a schedule (today it lists only unscheduled ones, so the AI study task cannot be added). The same for **events**.

## 2. Design

### 2.1 What an extra time is
- A one-off time that **belongs to a task or an event**: its date, an optional start and end time (a day-long one has none), and the zone of a timed one. It has the item's title, list, colour, notes and reminders; nothing of its own to name.
- It has its **own identity** (an id). A series' occurrence is known by its original date; an extra time cannot be, because it may fall on the same date as an occurrence (9–11 and 13–15 on one day), and a task can have several extras on a day.
- It is **independent of the rule**: changing "the whole repeat" changes the series' times and leaves the extras where they are. Clearing the series (no schedule any more) leaves the extras. A task with no schedule at all that gets its first time from the Calendar gets a **schedule**, as today (the first time is the plan; only the next ones are extras).
- Why not a second schedule row per item: the occurrence changes (skip, move) and the done ticks are keyed by the item and the original date, so a second row on the same item would share them and collide with the series. A record of its own has none of that and cannot make the series read wrong.

### 2.2 What the person can do with one
- **Add:** "Add another time…" in the plan of the task page and in the event editor (a list "Other times" under the schedule, each with Change and Remove), and in the menu of any occurrence on the Timeline and the Calendar.
- **Change a time:** on an extra, "Move this time" is free (date, start, end); on the series' occurrences it is what it is today (the day and time of that occurrence).
- **Remove a time:** on an extra, "Skip this time" removes it (it is gone, not hidden).
- **Done (tasks):** each time of a task has its own tick, as each occurrence of a repeating task has. Ticking an extra does not complete the task; completing the task in the Overview shows all its times done. Adding a time to a done task reopens it.
- **Reminders:** an extra gets the item's reminders (offsets before its start), as an occurrence does.
- **Conflicts:** an extra takes part in the conflict marks like any timed item.
- **Search, archive, trash, purge, move to another space, export, sync:** an extra goes with its item, as its schedule does. A purge blanks it.

### 2.3 On the Calendar
- Tap an empty slot → **\"Schedule a task here\"** lists **every task**, each with its current schedule as the second line (\"Every weekday 9:00–11:00\", \"5 Nov 15:00\", \"not scheduled\"), and a field to filter by title. A done task is listed too, struck through; scheduling it **makes it undone again** (it is reopened, then given the time).
  - Unscheduled: it gets its schedule, as now.
  - Scheduled: it gets an extra time at that slot.
- A new entry **\"Schedule an event here\"** lists the live events the same way (title, current schedule, filter); the slot becomes an extra time of that event, or its schedule if it has none; its length is the event's own, or an hour. An event that is cancelled is not listed (un-cancel it first).
- The slot keeps its other entries (new event, new all-day event, new task).

### 2.4 What stays out of this step
- Habits and targets: an extra time does not count in a habit's periods (see Q3).
- The assistant: its day plan treats an extra as fixed time (it comes in the calendar range); the chat cannot propose one yet.
- Several extras at once ("add these five days"): one at a time.

## 3. Work, in order
| # | Item | Notes |
|---|---|---|
| E1 | Data and commands | schema v20: table `extra_times`, a synced kind (shared spaces too); commands add, change, remove, tick; export, restore, purge, archive, move to a space; guard tests |
| E2 | Showing them | agenda, calendar range, timeline, Today and Upcoming, conflicts, reminders, the assistant's busy time; identity of an item grows an `extraId` |
| E3 | Planning them | the task page and the event editor: "Other times"; the occurrence menus: "Add another time…", change, remove |
| E4 | On the Calendar | "Schedule a task here" for scheduled tasks, with filter and subtitles; "Add a time for an event" |
- Every item: its own branch, headless tests, mutation checks, an ADR (0095), docs, CI green, a Vietnamese handoff, merge after the owner approves. The device check list (89 steps) gets a short part for this after E4.

## 4. The owner's answers (2026-11-04)
- **Q1.** An extra time may be a whole day. Yes.
- **Q2.** Each time of a task has its own tick; completing the task in the Overview marks every time done. Yes.
- **Q3.** Habits count their periods from the rule only. Yes, for now.
- **Q4.** **No limit** on extra times (the owner: 100 is too few). Only the existing bound on what a query returns applies, as for a long series.
- **Q5.** \"Schedule a task here\" lists **every** task, a done one struck through; scheduling a done task makes it undone again. And an **\"Schedule an event here\"** entry, the same for events.
- **Q6.** \"Edit the whole repeat…\" never moves extras. Yes.

## 5. Open question from the owner (2026-11-04): more than one repeat on one item
Example: a task with 9-11 on Tuesdays **and** 13-15 on Thursdays. Today an item has one repeat rule, and an extra time is a single time (no repeat), so this is not possible as one series.

Options:
- **A. Add many extra times at once.** In "Add another time", the person picks a pattern (for example every Thursday, 13-15, until a date or N times) and the app creates one independent extra time for each date. No limit applies (Q4). Each can be ticked, moved or skipped alone. Cost: small (UI over E1's commands). Drawback: the group is not a series; changing the hour of all of them means editing each, or removing and adding again.
- **B. An extra time may repeat** (its own rule, like a second schedule). Each one then needs its own skips, moves and ticks keyed by (extra, date), so the series code of tasks, events, habits, reminders and the Calendar is repeated for a second kind. Cost: large (about the size of P02 T4/T5 again), and a new schema step.
- **C. One rule with a different time on each weekday** (Tue 9-11, Thu 13-15). Fits this example exactly, but not two series with different end dates or periods.

**Decision (owner, 2026-11-04): B.** An extra time may repeat on its own rule; built in E3 ([ADR-0097](../adr/0097-repeating-extra-times.md)).
