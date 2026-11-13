# ADR-0050: Six destinations, Habits on its own, and the result policy of measured tasks completed by hand

- Status: Accepted (P03 UX task U6, 2026-11-13; owner decisions U-D2 and U-D13 in [p03-ux-plan.md](../roadmap/p03-ux-plan.md))
- Date: 2026-11-13
- Deciders: Project owner (direction), implementation
- Related: [ADR-0044](0044-navigation-drawer-on-phones.md) (drawer on phones; amended), [ADR-0047](0047-overview-screen.md), [ADR-0048](0048-timeline.md), [ADR-0049](0049-calendar-time-grid.md), [ADR-0039](0039-habits-targets-measurements-period-results.md) (period results; amended)

## Context
U3–U5 placed the Overview and the Timeline inside a Tasks tab with segments, and Habits as a third segment. The plan (U6) makes them destinations of their own: Overview, Timeline, Calendar, Habits, Goals, Settings, with the profile on top. ADR-0039 also left a question open: for a measured task completed by hand (manual policy), is a period's stored result the target's judgement or the tick? The owner answered (U-D13): the user chooses it in Settings.

## Decision
**Destinations** (`shell.dart`, `router.dart`). There are six, in this order:
- Overview `/overview`
- Timeline `/timeline`
- Calendar `/calendar`
- Habits `/habits`
- Goals `/goals`
- Settings `/settings`

Profiles `/profiles` is a seventh branch, reached from the profile at the top:
- the drawer's header on phones (ADR-0044);
- a profile button with the initials at the top of the rail (`RailProfileButton`), new on wide windows.

There is one route table for every width. "/" and unknown links go to the Overview. So does the old `/tasks`, which was the first location until U6. The Tasks tab and its segments are gone. The Calendar's Timeline button opens the Timeline destination. The labels come from the ARB.

**Habits (U-D2)** is its own screen: the habit list with periods and statistics. Its + ("Add habit") adds a daily habit from today (D6a), as the old filter did.

**Result policy (U-D13).** `profiles.manual_results` holds `target` (the default) or `tick` (schema v8). It applies to a measured task completed by hand (the manual policy):
- `target`: a period's stored result is its target's judgement (achieved, not achieved, no data), as before.
- `tick`: the result is done or missed per occurrence, as ticked, like a habit without a target. Measurements still show progress.
- An automatic task is always judged by its target.

The setting is **profile data**, not a device setting:
- It is changed by a command on the profile (`setManualResults`) through the gateway, with audit and outbox.
- It is exported. An older file gets `target`, and an unknown value is refused.
- Later it is synced, so two devices store the same results.

It applies only to periods that are not stored yet, which are those that close after the change. Stored results are never rewritten (D9). A period already stored under one kind is not stored again under the other: occurrences inside a stored period, or a period over stored occurrences.

Settings has a section "Measured tasks you tick yourself" with the choices "Judge by the target" and "Count the tick".

## Consequences
- ADR-0044 is amended: the drawer lists six destinations, and the rail shows the profile on top.
- ADR-0039 is amended: U-D13 answers its open question.
- Schema v8 is additive. The upgrade from v1–v7 is tested; the export upgrade and validation are tested.
- Verification:
  - `habit_tracking_test`: tick versus target, the automatic case, results kept across a change, no double storing.
  - `overview_export_test`: the policy in files.
  - The atomic set with the new op.
  - `shell_test`: six destinations, the profile in the rail.
  - `router_test`: the old `/tasks` link.
  - `navigation_flow_test`: every destination on a phone and on a wide window, the Calendar link, the Settings choice.
  - The habit, schedule and integration tests on the new destinations.
