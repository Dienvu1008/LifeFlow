# P03 dogfooding pass 1: fixes F1–F5

- Status: **Accepted by the owner 2026-11-13** (answers to the questions included below). **Done 2026-11-14:** F1–F5 merged after the owner's second pass; P03 signed off ([p03-exit-gate.md](../testing/p03-exit-gate.md)).
- Date: 2026-11-13
- Inputs: the owner's first dogfooding pass on Android and Windows after U1–U6 ([p03-ux-plan.md](p03-ux-plan.md))
- Way of working: F1–F5 in one pass, each group on its own branch (stacked), tests, mutation checks and an ADR where a design is decided; then the owner dogfoods again. P03's exit (T7) waits for this.

## Overview
- **O1 Drag handles.** Settings → Appearance → "Drag handles": Auto (default: shown with a pointer, hidden on phones), Always, Never. A device setting. Without handles a long press still drags (touch) and the row gains 24 dp.
- **O2 Drag feedback, as in AppFlowy.** The dragged "shadow" is a copy of the whole row, at its width, slightly transparent, with elevation. The original row fades in place. The drop line is indented at the level the item will take, and it updates smoothly as the pointer moves sideways.
- **O3 Type.** The task title (ListTile default `bodyLarge`, 16) was larger than the list title (`titleSmall`, 14). The new scale: a list is bolder and never smaller than its tasks, and subtasks keep the same size. Settings → Appearance → **Font** (System, Inter, Noto Sans, Be Vietnam Pro) and **Text size** (80–150 %, multiplied by the system's scale). Fonts are bundled in the app and never downloaded (LF-INV-PRIV-001). Each font's license is checked (ADR-0018).
- **O4 Task page.** A tap on a task opens a full-screen page, as for events. It has:
  - the title, the list and the colour;
  - **notes** (new: `tasks.notes`, schema v9, exported);
  - the schedule and reminders;
  - habit and target;
  - goals;
  - subtasks (add, tick);
  - Focus, and Move to trash.

## Timeline
- **T1** No Focus button and no "+" on this screen.
- **T2 App bar.**
  - Calendar closed: the full month ("November 2026") and no previous/next buttons. "Today" shows only while the list is scrolled away from today.
  - Calendar open: the short form ("Nov 2026", in the app's language) with previous/next. The month calendar's own header is hidden. "Today" shows only when the calendar shows another month; it brings the calendar back to this month and the list back to today.
  - A title too long for its space scrolls sideways (marquee) inside it.
- **T3 Day marks.** One dot per task or event on that day, in the item's colour (neutral without one). The row of dots scrolls when it is long.
- **T4 Calendar height.** A vertical swipe on the calendar switches month → 2 weeks → 1 week and back: table_calendar's three formats, chosen by the owner over a custom 3-week step. When the calendar moves to another month or week, the list jumps to the first day of that range, or to today when today is in it.

## Calendar
- **C1** No "+". Items are added by tapping a time slot in the day or week grid. In the month and year views a tap on a day opens that day. The slot sheet gains "All-day event", which replaces the old "+".
- **C2 Paging with a slide** for Day, Week, Month and Year:
  - a swipe left or right on phones;
  - on Windows: a mouse drag sideways, sideways scrolling on a touchpad, the ←/→ keys (also PageUp/PageDown);
  - the app-bar buttons slide too.

  A vertical drag still scrolls the hours, and a tap still picks a slot.
- **C3 View switcher.** Four separate buttons, each on its own translucent background. The selected one is a little stronger, so it stays recognisable without hiding the content.

## Groups
| Group | Content |
|---|---|
| F1 | T1, C1, C3, T3 |
| F2 | O1, O2, O3 |
| F3 | O4 (with notes, schema v9) |
| F4 | T2, T4 |
| F5 | C2 |
