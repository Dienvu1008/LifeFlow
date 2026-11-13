# ADR-0049: The Calendar as a time grid, with a year view

- Status: Accepted (P03 UX task U5, 2026-11-13; owner decisions U-D5, U-D6 in [p03-ux-plan.md](../roadmap/p03-ux-plan.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0031](0031-events-calendars-conflicts.md) (events, conflicts), [ADR-0030](0030-task-scheduling-and-agenda.md) (schedules), [ADR-0048](0048-timeline.md) (Timeline), [ADR-0013](0013-time-kernel-packaging.md) (Time Kernel)

## Context
The Calendar's day and week views were lists of rows. The owner wants a time grid like other calendars (after *my_time_manager*): an hour gutter, a line at the current time, the night hours hidden, zoom, a tap on a free slot to add something there, a month grid that opens a day, a year view, and a view switcher at the bottom. Times must stay right across zones and DST.

## Decision
**Views.** Day and Week are a time grid; Month is the existing grid (a day opens the day view); **Year** is new (U-D6): 12 small months with a mark on days that have items. A day opens the day view and a month's name opens the month view. The year is one range query (Jan 1 to Dec 31), within the default limit of 400 days. With a lower limit set, the cut-off notice shows.

**Switcher and app bar.** Day / Week / Month / Year is a translucent bar at the bottom left. It scales down so it always leaves room for the + button. The app bar has the period title, "Go to today", previous and next, the Timeline, and More (calendars). For the grid it also has zoom out and zoom in (in More on phones) and the night-hours switch.

**The grid** (`calendar_grid.dart`, pure; `calendar_grid_view.dart`):
- An hour gutter, a row of all-day items above the grid (two per day, then "+n", which opens the day), and day columns.
- Timed items are blocks. Items that overlap share the width side by side: a group of items that overlap, directly or through others, gets as many columns as it needs, and each item takes the first free one.
- A block is drawn at least 30 minutes tall. It shows its colour (the item's palette colour, else the calendar's), the title, and the time when there is room. A tap opens the item's full row (ticks, "only this time", conflicts) in a sheet, as the week chips did before.
- **The now line** is on today's column only. It moves once a minute and does not catch taps.
- The grid opens an hour before now on today, and at 07:00 on other days.

**Device time (DST).** The grid draws the device's wall clock from 00:00 to 24:00. Each event and task occurrence now carries `deviceStart` and `deviceEnd`, the same instant on the device zone's wall clock, resolved by the Time Kernel (`devicePointOf`: `instantOf` and then `wallClockAt`).
- An item in another zone sits at its local time. It can fall on another date, and the grid places it by the device date.
- On a 23 h day, a wall-clock time in the gap resolves to the end of the gap (the kernel's rule).
- On a 25 h day, the repeated hour is drawn once. An item whose end reads earlier than its start is drawn from its start with the minimum length.
- The UI never converts zones itself (FF-ARCH-04).

**Night hours (U-D5).**
- One hidden range per device, 00:00–06:00 by default.
- Settings → Calendar → Night hours sets From and To (`PlanningSettings.hiddenFrom/hiddenTo`, registry keys `planning.hiddenFrom/To`). From after To wraps past midnight; equal hides nothing.
- The hidden hours are folded into a thin band labelled "00:00–06:00 hidden. Show". Tapping the band or the switch shows them for the session.

**Zoom.** The hour height runs from 24 to 160 dp (48 by default) and is kept while the app runs. Three ways to change it:
- the zoom buttons;
- Ctrl + mouse wheel (the event is claimed, so the grid does not scroll);
- two-finger pinch, through a pointer listener, so one finger still scrolls.

**A tap on a free slot** (snapped to 15 minutes) opens a sheet with three choices:
- a new event there (the editor starts at that time, for an hour);
- a new task scheduled there;
- an existing open task without a schedule, scheduled there.

**Strings.** All new strings are in the ARB (`cal…`). Removing the old list views lowers `calendar_screen.dart`'s FF-ARCH-10 count from 31 to 16.

## Consequences
- Layout, folding, slots, spans over midnight and DST are pure functions with their own tests (`calendar_grid_test`).
- The widgets are tested through the full app with fake ports (`calendar_grid_flow_test`: the year view and its links, the fold and its setting, zoom by button, Ctrl+wheel and pinch, the now line, slot taps, zones, phone fit). The older calendar tests now open a block first. On real stores the event and task blocks and their overlap are tested in `app_integration_test`. Device times and the hidden-hours setting are tested in `device_time_test`.
- The range query is by the items' own dates. An item in a far zone near the edge of a week can be missed in that week (it shows in the next range). This is accepted at personal scale.
- Dragging a block to another time is not part of U5 (the slot sheet and the editors cover it). To be reviewed in the dogfooding pass.
