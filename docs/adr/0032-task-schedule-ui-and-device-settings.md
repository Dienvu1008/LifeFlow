# ADR-0032: Task schedule UI, Today and Upcoming, device calendar settings

- Status: Accepted (P02 task T6a, 2026-11-09; within the owner-accepted P02 plan, decisions D1–D5, D9, D10 and the D2/D3 refinement)
- Date: 2026-11-09
- Deciders: Project owner (plan), implementation
- Related: [ADR-0019](0019-ui-state-management-and-navigation.md), [ADR-0028](0028-time-types-and-dst-resolution.md), [ADR-0030](0030-task-scheduling-and-agenda.md), [ADR-0031](0031-events-calendars-conflicts.md), [p02-plan.md](../roadmap/p02-plan.md)

## Context
T6 of the P02 plan is the whole planning UI. It is split in two so each part can be checked on the devices on its own:
- **T6a** (this ADR): schedule editor on a task, Tasks filters All / Today / Upcoming, schedule summary on task rows, Settings → Calendar, and the wiring of the device zone and query limits.
- **T6b**: Calendar tab (day, week, month) with buttons to Today and Upcoming, event editor, conflict badges.

## Decision
- **Device zone (D10):** the app reads the IANA zone from the platform once at startup (`flutter_timezone` 5.1.1, Apache-2.0, pinned; spike S-05). A zone this build does not know, or a failed read, becomes `UTC`, never a guess. Legacy aliases such as `Asia/Saigon` (reported by Windows) are valid zones of the database and are kept. The same zone drives the agenda's "today" and the UI's date labels (`todayProvider`), so a label never says "Today" for another day than the Today list.
- **Editor:** start, end and deadline each take a date and an optional time. One zone per schedule, defaulting to the device zone and changeable with a searchable picker; it is shown only when some point has a time. Repeat: frequency, interval, weekdays (weekly; none = the start's weekday), end (never, on a date, after N times), month-end rule (monthly and yearly), week start (weekly with interval > 1). The editor collects input only; rules are checked by `TaskScheduling.setSchedule` and the refusal reason is shown in the editor, which stays open (AP-12). Fields that cannot be read (empty number, missing end date) are caught before any command.
- **Defaults vs. stored rule (D2/D3 refinement):** a new repeat takes the month-end rule and the week start from Settings; an existing repeat shows and keeps its own, and can be changed per repeat.
- **Device settings (D1–D3):** `SettingsService.planningSettings()` / `setPlanningSettings()`, stored in the registry under `planning.*` (device setting, not profile data: not synced, not exported). Limits are clamped to 100–5000 occurrences and 31–1100 days on save and on read; the Settings dialog refuses values outside the range with a message. `DirectorySettingsService.limitsCache` holds the current values; the agenda reads its limits through it, so a change applies to the next query without a restart.
- **Tasks filters (D9):** All (the tree, with a one-line schedule summary per row), Today (overdue one-offs first, then today's items in time order), Upcoming (the next 14 days, grouped by date). The filter is a provider so the Calendar tab (T6b) can switch to it. A list cut by the limits shows a notice. A task added while Today or Upcoming is shown is planned for today or tomorrow (date only), so it does not vanish from the list it was added to.
- **Ticking (D5):** in Today and Upcoming a repeating item marks only that occurrence done or open; a one-off completes or reopens the task (with the open-subtasks question as in All).
- **Only this occurrence (D4):** in Today and Upcoming a repeating item offers skip, move to another date (time kept), and undo of that change; "Edit the whole repeat" opens the editor. "This and following" stays deferred.
- **Read model:** `TaskView.schedule` carries the live schedule of each task (left join; a cleared schedule's tombstone is not shown, and a task row is never duplicated).

## Consequences
- Pro: the UI stays on application ports and `foundation` types only (FF-ARCH-04); all checks remain in the command path.
- Con: the device zone is read at startup; a zone change while the app runs applies after a restart. Acceptable for MVP; revisit with reminders (T7) if needed.
- Con: date and time pickers use the platform-neutral Material pickers in English; localization comes with the string set.

## Verification
- `packages/ui/test/schedule_flow_test.dart` (18 tests) and `schedule_text_test.dart` (3): summaries with and without a foreign zone; editor with date, time, zone change, new-repeat defaults from Settings, an existing repeat's own rule, a refused schedule, an incomplete repeat end, remove; Today order and overdue, ticking per occurrence, Upcoming grouping, skip, move and undo, empty and truncated lists, adding in Today and Upcoming; Settings saves and bounds; phone width without overflow; filter labels on one line at phone width with a large system font (found on the Android device: "Upcoming" wrapped; icons are now shown only when there is room).
- `packages/infrastructure/test/task_scheduling_test.dart` (4 new): `watchTasks` carries the schedule and drops a cleared one; settings defaults, round trip, clamping and cache; the agenda follows changed limits; device zone fallback.
- `apps/lifeflow_app/test/app_integration_test.dart`: a schedule set through the UI on the real store shows in Today; ticking it writes one occurrence completion and leaves the task open.
- Mutations (14, all killed): filter icons shown at any width; occurrence tick sent as a task completion; new-repeat defaults ignored (month end, week start); an existing repeat's rule replaced by the default; chosen zone ignored; Upcoming add planned for today; foreign zone hidden; Settings bounds removed; overdue group removed; settings not clamped; cleared schedule still joined; limits cache not filled; unknown device zone accepted.
