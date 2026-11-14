# ADR-0051: Changes from the first dogfooding pass (F1–F5)

- Status: Accepted (owner's dogfooding pass 1, 2026-11-13; decisions in [p03-dogfood-1.md](../roadmap/p03-dogfood-1.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0047](0047-overview-screen.md), [ADR-0048](0048-timeline.md), [ADR-0049](0049-calendar-time-grid.md) (amended)

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

## Consequences
- ADR-0049 is amended: no + button, the all-day choice in the slot sheet, the new switcher.
- F1 tests: the tests that used the + now start from a slot (`newEventFromSlot`). New tests cover the all-day slot, no + in the Calendar and the Timeline, the coloured marks, and the separate view buttons.
