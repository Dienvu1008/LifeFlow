# ADR-0033: Calendar tab, event editor, conflict badges

- Status: Accepted (P02 task T6b, 2026-11-09; within the owner-accepted P02 plan, decisions D3, D4, D6, D7, D9, D10)
- Date: 2026-11-09
- Deciders: Project owner (plan), implementation
- Related: [ADR-0019](0019-ui-state-management-and-navigation.md), [ADR-0031](0031-events-calendars-conflicts.md), [ADR-0032](0032-task-schedule-ui-and-device-settings.md), [p02-plan.md](../roadmap/p02-plan.md)

## Decision
- **Navigation (D9):** Tasks, Calendar, Profiles, Settings. The Calendar tab has buttons to Today's tasks and Upcoming tasks; they switch the Tasks filter and open Tasks. A "Go to today" button jumps the calendar to today.
- **Views:**
  - Day, Week and Month, chosen with a segmented control. The first view follows the width: week on a phone, month on a wider window. The position is kept while the app runs.
  - The week and the month grid start on the device's first day of the week (D3).
  - The month is always six weeks (42 days), so the grid never changes height.
  - Below 720 px of content width, the week is a list of days. Wider, it is seven columns of blocks, and a block opens the full row in a sheet.
  - Month cells show up to three titles when wide, or dots on a phone. Each cell has one accessible label (date, item count, overlaps), and tapping it opens that day.
  - Day lists are ordered all-day first, then by start time.
  - An item that spans days is shown on each day it covers. An end at midnight belongs to the day before.
- **Events and tasks (D6):**
  - Events and scheduled tasks share the views, but each keeps its own row and actions.
  - A task row is the same row as in Today/Upcoming: one occurrence is ticked at a time (D5), and skip, move and undo apply to that time only.
  - Events show the calendar colour, time, location, "Repeats", "Moved" and "Cancelled".
- **Only this time or every time (D4):**
  - For one time of a repeating event: skip, cancel, move, rename, and undo that change.
  - For the whole event: edit (the editor says the change applies to every time), cancel or un-cancel, and trash with Undo (restore).
  - "This and following" is still deferred.
- **Event editor:**
  - Fields: title, start (required, cannot be removed), optional end, one zone (the device zone by default, D10), location, calendar (or none) and repeat.
  - A new event defaults to 09:00–10:00 on the day shown. An event without times is all-day, and the editor says that all-day events never overlap.
  - The input parts (date and time row, repeat fields, zone picker) are shared with the task schedule editor (`widgets/schedule_fields.dart`).
- **Conflicts (D7):**
  - Shown on both items as "Overlaps <title>" with a warning icon, never resolved.
  - Month cells and week blocks show a warning icon.
  - They come from `CalendarRange.conflicts` (kernel `overlaps`); the UI only looks up titles.
- **Calendars:** managed from the Calendar tab's menu (add, rename, recolour from eight named colours, trash). Trashing a calendar says that its events stay without a calendar (ADR-0031).
- **Truncation:** a range cut by the limits shows the same notice as Today/Upcoming.

## Consequences
- Pro: the views read `CalendarQueries` only. Every change is a command, and the UI holds no planning rules (AP-12, FF-ARCH-04).
- Con: the day view is a list, not an hour grid, so overlaps are shown by badges rather than by position. An hour grid can come later without changing the queries.
- Con: the platform date picker starts its week on Sunday (English Material locale), independent of D3. It follows the locale once localization lands.
- Fix found while testing: each tab keeps its page alive, so the two "+" buttons need their own hero tags. With the default tag, opening a full-screen editor raised a duplicate-hero assertion.

## Verification
- `packages/ui/test/calendar_layout_test.dart` (8 tests): week start for Monday and Sunday; day, week and 42-day month ranges; stepping (a month never lands on a missing day); period titles across months and years; items on each covered day, midnight end, clipping and order; tasks as entries; conflicts both ways; entry times.
- `packages/ui/test/calendar_flow_test.dart` (19 tests):
  - Views: month grid by default when wide; prev, next and today; Sunday start in month and week; phone week list and opening a day; wide week columns and the block sheet; a month cell opens its day.
  - Navigation and notices: Today and Upcoming buttons; truncation notice.
  - Day view: a task row with D5 ticking and overlap badges on both items; a cancelled event and un-cancel.
  - D4 and trash: skip, cancel, move and rename one time; undo and cancel every time; trash with undo; a refused change reported.
  - Event editor: new-event defaults and calendar choice; all-day weekly with a required start; title and refusal messages; editing every time.
  - Calendars: add, edit and trash; phone month with a large font without overflow.
- `packages/ui/test/shell_test.dart`: four destinations in order.
- `apps/lifeflow_app/test/app_integration_test.dart`: on the real store, an event made in the Calendar tab is stored as an event (not a task, with its own id) and shown. A task planned through its editor to overlap it makes both rows show the overlap.
- Mutations (10 killed): week start ignoring the setting; midnight end on the next day; conflicts on one side only; five-week month; tasks drawn without their own row; Today's-tasks button opening Upcoming; new event zone UTC; trash Undo not restoring; removable required start; default FAB hero tag; plus one equivalent mutant (the start draft's zone is unused).
