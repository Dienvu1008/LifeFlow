# ADR-0051: Changes from the first dogfooding pass (F1–F5)

- Status: Accepted (owner's dogfooding pass 1, 2026-11-13; decisions in [p03-dogfood-1.md](../roadmap/p03-dogfood-1.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0047](0047-overview-screen.md), [ADR-0048](0048-timeline.md) (amended), [ADR-0049](0049-calendar-time-grid.md) (amended)

## Context
The owner used U1–U6 on Android and Windows and asked for the changes listed in p03-dogfood-1.md. Each group (F1–F5) adds its decisions below.

## Decision

### F1 — Fewer buttons, clearer marks
- **Timeline (T1):** no Focus button and no "+". Items are added in the Overview or the Calendar.
- **Calendar (C1):** no "+". Items are added from a time slot of the day or week grid. The slot sheet now offers:
  - a new event;
  - **a new all-day event** (the editor opens on that date without times);
  - a new task;
  - an existing task scheduled there.
- **View switcher (C3):** four separate buttons, centred at the bottom, each on its own translucent background. The selected one is stronger and bold, and is marked as selected for screen readers. The switcher scales down on narrow windows.
- **Day marks (T3):** the Timeline's month calendar shows one dot per item on a day, in the item's palette colour (neutral without one). A long row of dots scrolls sideways.

### F2 — Drag handles, drag feedback, type and fonts
- **Drag handles (O1):** Settings → Appearance → "Drag handles":
  - Auto (default): shown with a pointer, hidden on phones;
  - Always;
  - Never.

  This is a device setting (`SettingsService.appearance`, keys `ui.dragHandles`, `ui.font`, `ui.textScale`). Wherever the handles are hidden, a long press on a row drags it, also with a mouse. The row gains the 24 dp the handle used.
- **Drag feedback (O2):**
  - The dragged copy is the whole row at its width: 90 % opaque, raised (elevation 6), held where the pointer took it.
  - The original row and its subtasks fade to 35 % in place.
  - The drop line is indented at the level the item will take (under a task: its indent + 1; in a list: 1; in no list: 0) and slides there (120 ms).
  - The drop zone follows the pointer, not the copy's corner.
- **Type (O3):**
  - Row titles have one explicit size for tasks, events and subtasks: 14 with a pointer, 16 on phones.
  - A list's title has the same size in bold, so it is never smaller than its tasks.
  - The theme's component styles now carry real sizes. Before, Material only filled them in for the default text theme, so the app bar and the list titles fell back to 14.
- **Font and text size (O3):** Settings → Appearance → Font offers System, Inter, Noto Sans and Be Vietnam Pro.
  - The three named fonts are bundled TTFs under SIL OFL 1.1 (VS-39), about 4 MB in all. They are never downloaded (LF-INV-PRIV-001). Their licenses are on the licenses page.
  - Text size runs from 80 % to 150 % in 5 % steps and multiplies the system's text scale.

### F3 — The task page, with notes
- **Opening:** a tap on a task opens its page, full screen, as an event opens its editor. This works from the Overview, the Timeline and the Calendar's rows.
- **Contents:**
  - the tick and the title (rename);
  - the list (top-level tasks), or "Subtask of …" (a link to the parent);
  - the colour;
  - **notes**;
  - Plan: schedule and reminders (the schedule editor), habit and target (the habit page), goals;
  - subtasks: tick, open, and "Add subtask" up to the depth limit;
  - in the app bar, Focus and Move to trash (with the subtask question; the page closes).
- **Notes** are new profile data: `tasks.notes` (schema v9, nullable).
  - A task command `setNotes` sets them, trimmed. Empty notes are removed, and notes over 20 000 characters are refused.
  - They are exported. An older file gets none, and bad notes in a file are refused.
  - The page saves the notes with "Save notes" or when the field is left.
- **Migration test (hardened):** the upgrade test now checks that every column of every table exists after the upgrade. Drift reads a missing nullable column as null, so a forgotten `addColumn` for such a column was not caught before.
### F4 — The Timeline app bar and calendar heights
- **App bar, calendar closed (T2):** the full month and year of the day at the top of the list ("November 2026"), no arrows. "Today" shows only while no part of today's section is on screen. It brings the list back to today at the top, also when the list was already centred on today.
- **App bar, calendar open (T2):**
  - the short month in the app's language ("Nov 2026") between Previous and Next; table_calendar's own header is hidden;
  - the calendar opens on the month at the top of the list;
  - "Today" shows only while the calendar's page does not contain today. It brings the calendar and the list back to today.
- **Long titles (T2):** a title wider than its space slides sideways inside it once: a pause, a slide to the end, a pause, then it rests at the start cut with an ellipsis. It plays again whenever the title changes. It does not loop, so nothing keeps moving for more than a few seconds (WCAG 2.2.2). With animations turned off it only gets the ellipsis.
- **Calendar heights (T4):** a swipe up on the calendar goes month → two weeks → one week; a swipe down goes back. These are table_calendar's three formats (the owner chose them over a three-week step).
- **Paging moves the list (T4):** when the calendar turns to another page (swipe or arrows), the list goes to the first day of that page: the 1st for a month, the first day of the week for one or two weeks. If today is on the page, it goes to today. Changing the height alone does not move the list.
- The calendar's weeks start on the planning setting's first day of the week, any day (before: only Sunday or Monday).

### F5 — Calendar paging
- **Every view turns like pages (C2):** Day, Week, Month and Year sit in a pager (`PageView`). The next or previous period slides in (280 ms), and its items are loaded ahead, so a page arrives with its contents.
- **Ways to turn:**
  - a swipe on a phone; on Windows also a mouse drag and a touchpad swipe. The mouse drag is enabled for the pager only, not for the hours inside it;
  - a sideways wheel or touchpad scroll (40 px per page), and Shift + the mouse wheel. A mostly vertical scroll is left to the hours;
  - ← / → (mirrored in right-to-left languages) and PageUp / PageDown. Presses during a slide add up;
  - the app bar's Previous and Next, which slide as well.
- **What stays:** a vertical drag scrolls the hours and a tap still picks a slot; the gesture arena decides by direction. While two fingers are down (pinch zoom), the pages hold still.
- Today, a day, a month in the year view and the view switcher jump without a slide; the pager starts again from there.

## Consequences
- ADR-0049 is amended: no + button, the all-day choice in the slot sheet, the new switcher.
- ADR-0049 is amended by F5 too: paging.
- F5 tests: `calendar_paging_flow_test` (the slide in all four views both ways, swipes, a mouse drag, the wheel and Shift + wheel, a vertical scroll left to the hours, keys and presses adding up, a vertical drag and a slot tap, two fingers not turning).
- ADR-0048 is amended by F4: the app bar and the calendar under it.
- F4 tests: `timeline_bar_flow_test` (Today in and out of sight, closed and open titles, arrows and swipes moving the list to the page's first day or today, the calendar opening on the list's month, the three heights, the long title sliding once).
- F3 tests: `task_page_flow_test` (contents, notes saved both ways, rename, colour, list, subtasks, parent link, plan rows, trash closes, from the Timeline), notes in `overview_test` and `overview_export_test`, the atomic set with `setNotes`, the v1–v8 upgrades with the column check.
- F2 tests: `overview_look_test` (handles by setting and platform, long-press drag on Windows without handles, the dragged copy, the fade, the drop line's indent, list and task title sizes, font and text size applied and saved, clamping) and the appearance round trip in `overview_test`.
- F1 tests: the tests that used the + now start from a slot (`newEventFromSlot`). New tests cover the all-day slot, no + in the Calendar and the Timeline, the coloured marks, and the separate view buttons.
