# P03 UX plan: UI foundation, Overview, Timeline, Calendar (before the P03 exit)

- Status: **Accepted by the owner 2026-11-11** (decisions U-D1–U-D12 below). P03's exit (T7, [p03-exit-gate.md](../testing/p03-exit-gate.md)) waits for this work and the owner's dogfooding pass.
- Date: 2026-11-11
- Inputs: owner requests of 2026-11-11 (minimalism, density, theme, i18n infrastructure; Overview, Timeline and Calendar after the owner's earlier app *my_time_manager*), [ADR-0044](../adr/0044-navigation-drawer-on-phones.md) (drawer on phones), [p03-plan.md](p03-plan.md) D12, [ui-ux-architecture.md](../architecture/ui-ux-architecture.md)

## 1. Why
The P03 screens work, but the owner wants the app to be easy and flexible in daily use before the MVP closes. Two directions come out of it:
- **Design:** more content and less chrome; dense rows; a narrow sidebar and a wide main pane; neutral colours, with accents only where they mean something (priority, status).
- **Screens:** Overview (lists, tasks and events, drag and drop, a task tree) replaces Tasks; Timeline replaces Today and Upcoming; the Calendar becomes a time grid with day, week, month and year views.

Reference: the owner's app *my_time_manager* (read-only review, 2026-11-11).
- **Reused as design:** lists on top and loose items below; the expand state remembered; drag into a list; a left colour bar; a speed-dial "+"; a two-way timeline with sticky day headers and a month calendar under the app bar; a time grid with a now line, pinch/Ctrl+wheel zoom and a transparent view switcher at the bottom; month → day.
- **Not reused as code:** its calendar package carries copies of `table_calendar`, `flutter_sticky_header` and (apparently) `calendar_view` without their license notices. LifeFlow uses the upstream packages instead (U-D10) and writes its own time grid.

## 2. Starting point (checked in code)
- Table `task_lists` exists (title), and `tasks.taskListId` and `tasks.sortOrder` exist, all exported and restored. No command, query or screen uses them.
- Events have no list, order or colour. The task tree (4 levels, `reparent` with the depth rule, LF-INV-TASK-002/003) exists.
- Theme: `ThemeData(colorSchemeSeed: …)` inline in `router.dart`, light and dark. No density, semantic colours or theme setting. Two hard-coded colours.
- No localization: about 270 `Text('…')` literals plus tooltips, labels and messages, all English. Dates are formatted by hand ("Mon 9 Nov"). Command refusals reach the UI as English sentences.
- Navigation: drawer on phones, rail on wide windows (ADR-0044). Tabs: Tasks (All / Today / Upcoming / Habits), Calendar (list-based month/week/day), Goals, Profiles, Settings.

## 3. Owner decisions (2026-11-11)
| # | Question | Decision |
|---|---|---|
| U-D1 | Events in lists | An event belongs to a list or to no list. It is **never the child of a task**. |
| U-D2 | Habits | A destination of its own in the navigation, no longer a Tasks filter. |
| U-D3 | Overdue items | At the top of today in the Timeline, in a collapsible "Overdue" group. |
| U-D4 | Colours | A **fixed palette of 12 colours**, each with a light and a dark variant meeting contrast. Default display: a **colour bar on the left** of the row on a neutral background. Lists, tasks and events can have a colour. |
| U-D5 | Sleep hours | **One** hidden range per device, default **00:00–06:00**, user-adjustable. Hidden by default in the day and week grids, with a control on the calendar to show it. |
| U-D6 | Year view | **Add a year view** (12 small months; a day → the day view, a month → the month view). |
| U-D7 | Libraries | `table_calendar` and `flutter_sticky_header` from pub.dev (license checked under ADR-0018, FF-ARCH-07). The day/week time grid is LifeFlow's own. |
| U-D8 | Order of work | U1 → U6 in one pass, then the owner's dogfooding. |
| U-D9 | Density | Per platform: compact with a pointer (Windows), standard touch targets (48 dp) on phones; rows are one line with metadata as small icons. *(Agent proposal, taken as the default.)* |
| U-D10 | Base colour | A neutral seed; colour only for meaning (priority, status, habit outcome, focus, conflict) and the user's item colours; never colour alone (an icon or text too). *(Agent proposal, taken as the default.)* |
| U-D11 | Localization | Infrastructure now (`gen_l10n`, English ARB, `intl` formatting, a fitness check against raw strings); no translation and no language choice yet. Strings of the screens that stay move to ARB in U1; the new screens (U3–U5) use ARB from the start. *(Agent proposal, refined: the screens being replaced are not migrated twice.)* |
| U-D12 | Two-pane layout on wide windows | After the dogfooding pass. *(Agent proposal, taken as the default.)* |
| U-D13 | Stored result of a measured task under the manual policy (open question of ADR-0039, answered 2026-11-13) | **A setting chooses it:** the target's judgement (today's behaviour, the default) or the tick. Proposed details, to be confirmed by the owner: one setting for all such tasks, kept with the profile (exported, later synced) so two devices store the same result; it applies to periods that close after the change, results already stored are not rewritten (D9). Implemented as a small task with U6. |

## 4. Tasks
One branch per task; headless tests, mutation checks of the key rules, an ADR, CI green; merged after the owner approves. The device checks of P03 (T7) and of U1–U6 happen together in the owner's dogfooding pass.

| Task | Content | Main proof | Est. (pd) |
|---|---|---|---|
| **U1** UI foundation | Theme module: neutral light/dark `ColorScheme`, no surface tint, semantic colours as a `ThemeExtension`, the 12-colour item palette. Theme mode System / Light / Dark in Settings. Density per platform; slimmer app bars; dense list tiles. i18n: `flutter_localizations` + `gen_l10n` with `app_en.arb`; dates through `intl`; strings of the screens that stay (focus, habit, goals, profiles, settings, account, data, dialogs, messages) moved to ARB; FF check against raw strings in migrated files. | widget tests (theme mode, dark contrast of the palette, density per platform), golden-free checks of the ARB, FF script | 2–2.5 |
| **U2** Data for Overview | Schema v7: `events.listId`, `colorIndex` on lists, tasks and events, and a fractional order key per container (a list, no list, a parent task) for lists, tasks and events. Commands: list create / rename / colour / trash / restore; move a task or an event into a list or out; reorder; reparent a task by drag (depth rule); set a colour. Export / restore and the reference checks; upgrade from v1–v6. Expand state is a device setting. | atomic set for every new op; GS-20 round trip; drag sequences as property tests (order stable, no lost or duplicated item, depth ≤ 4, an event never under a task); migration tests | 2 |
| **U3** Overview | Replaces Tasks. Lists on top, then items in no list. A list expands to its tasks and events; a task expands to its subtasks, down to level 4; the toggle shows only with children; the expand state is remembered on the device. Drag and drop in the AppFlowy way: above or below a row = reorder; onto a row or dragged right = become its child (tasks only); dragged left = one level up; into a list or out of it. A "+" speed dial: list, task, event. Colour bar. Row actions as today (focus, schedule, habit and target, goals, rename, colour, trash). | widget tests for expand, drag gestures, refusals (depth, event under a task); app integration on real stores | 3–4 |
| **U4** Timeline | Replaces Today and Upcoming. A two-way scrolling list around today with sticky day headers; the month and year in the app bar open a month calendar under it (`table_calendar`); choosing a day scrolls there; "Today". Rows: a time column (or "All day"), title, colour bar, habit state, tick. "Overdue" at the top of today (U-D3). Paged by date windows through the agenda queries. | widget tests (scroll to a day, sticky headers, overdue group, ticks), agenda paging tests | 2–3 |
| **U5** Calendar | Day and week: a time grid with an hour gutter, the all-day row, side-by-side overlaps, the **now line**, the sleep range hidden by default (U-D5). A tap on an empty slot → new task, new event, or schedule an existing task at that time. Month grid (a day → the day view); **year view** (U-D6). Zoom by pinch, Ctrl+wheel and buttons. The date in the app bar with previous / next / today. A transparent view switcher (Day, Week, Month, Year) at the bottom. Times through the Time Kernel (DST). | layout as pure functions (hour positions, overlaps, hidden range, DST days of 23/25 h); widget tests; app integration | 4–5 |
| **U6** Navigation and fixes | Destinations: Overview, Timeline, Calendar, Habits, Goals, Settings, with the profile in the drawer header (ADR-0044) and in the rail. Habits as its own screen (U-D2). Remaining fixes found along the way. | shell and router tests; app integration | 1 |

Total about 14–17.5 person-days.

## 5. Out of scope here
Translations and a language choice; the two-pane layout (U-D12); profile photos; "this and following" edits; syncing two devices (P04).

## 6. Risks
- **R-SCOPE:** this adds about two weeks before the MVP exit. Mitigation: the decisions above fix the scope; anything new from dogfooding is listed and decided again.
- **R-DATA-LOSS (drag and drop):** a drag could lose or duplicate an item, or break the depth rule. Mitigation: one command per drop through the gateway; property tests over random drag sequences; the order is a fractional key, so a drop rewrites one row.
- **R-LICENSE-SCAN:** two new packages. Mitigation: verified-sources rows and FF-ARCH-07 before merge.
