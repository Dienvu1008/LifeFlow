# ADR-0048: The Timeline replaces Today and Upcoming

- Status: Accepted (P03 UX task U4, 2026-11-13; owner decisions U-D3, U-D7 in [p03-ux-plan.md](../roadmap/p03-ux-plan.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0047](0047-overview-screen.md) (Overview), [ADR-0031](0031-events-calendars-conflicts.md) (events, calendar range), [ADR-0018](0018-dependency-license-policy.md) (licenses), VS-37 / VS-38

## Context
Today and Upcoming were two separate lists (today with overdue tasks; the next 14 days), tasks only. The owner wants one list in time order around today, with events too, sticky day headers and a month calendar under the app bar to jump to a day (after *my_time_manager*). Queries must stay bounded (LF-INV-PLAN-010).

## Decision
**Place.** The Tasks tab has three views: Overview, Timeline, Habits. Today and Upcoming are gone; the Calendar's "Today's tasks" and "Upcoming tasks" open the Timeline on today and on tomorrow. U6 makes the Timeline its own destination.

**One list, both ways.** A `CustomScrollView` centred on an anchor day (today, or the day chosen): days before it grow upwards, days after it downwards. Each day is a `SliverStickyHeader` (flutter_sticky_header 0.11.0, MIT, VS-37). Its header reads "Today · Fri 13 Nov", or the date. The days shown are those with items, the anchor, and today when loaded.

**Bounded loading.** Data comes in windows of 21 days through the calendar range query (events, task occurrences and their conflicts): one window before the anchor and two after it at first. One more is loaded on a side when the list is within 800 px of that end, up to 26 windows each way (about 18 months). Each window keeps only the items that start inside it, so an item is never doubled. Today's agenda adds the overdue tasks and any of today's occurrences the windows do not have. The cut-off notice shows when any query was truncated.

**Rows.** A time column (the start time, or "All day"), the item's colour bar (U-D4), then the row: task occurrences use the agenda tile (tick, habit period, "only this time" actions, overlaps), without the time in the subtitle; an event shows its end and place, opens its editor on tap, and is struck through when cancelled. In a day: all-day first, then by time, then by title.

**Overdue (U-D3).** Open one-off tasks planned before today are a group "Overdue (n)" at the top of today, open by default, folded by a tap.

**Month calendar.** The app bar's title is the month and year of the day at the top (it follows the pinned header). Tapping it opens a month calendar under the app bar (table_calendar 3.3.0, Apache-2.0, VS-38; no NOTICE file), with markers for the loaded days and the week start from Settings. Choosing a day makes it the anchor and closes the calendar. "Go to today" in the app bar comes back.

**Adding.** The + in the Timeline adds a task planned on the anchor day.

**Strings.** All new strings are in the ARB (`tl…`); removing the old agenda lists lowers `tasks_screen.dart`'s FF-ARCH-10 count (20 → 16).

## Consequences
- Jumping to a day rebuilds the list around it, so it never measures rows that are not built; the list starts with that day at the top.
- A daily repeat shows on every day of the Timeline (as in the Calendar), not once as in the old Today.
- Two new packages and two transitive ones (value_layout_builder MIT, simple_gesture_detector Apache-2.0), in the license inventory (FF-ARCH-07).
- Verification: `timeline_model_test` (windows, no doubles, order, overdue, truncation, conflicts, days shown), `timeline_flow_test` (time column and colour, events, both-way scrolling with more windows, the month calendar and "Today", the title following the top day, the empty state), the updated agenda tests in `schedule_flow_test`, and the schedule test on real stores (`app_integration_test`).
