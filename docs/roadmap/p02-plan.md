# P02 plan: Planning & Calendar

- Status: **Accepted by the owner 2026-11-07** (decisions D1–D10 and the D2/D3 refinement, section 3). T0–T7 done and merged; T8 exit gate: [p02-exit-gate.md](../testing/p02-exit-gate.md) (waiting for sign-off).
- Date: 2026-11-07
- Inputs: [definition-of-done.md §P02](../testing/definition-of-done.md), [phase-breakdown.md](phase-breakdown.md), [planning-scheduling.md](../domains/planning-scheduling.md), [calendar-events.md](../domains/calendar-events.md), [task-management.md](../domains/task-management.md), ADR-0007, ADR-0010, ADR-0013, ADR-0015, invariant catalog §2–3, GS-03/04, UC-06/08, FR-PLAN-01..12, FR-CAL-01..04
- Estimate (effort-estimation.md): 15–30 person-days

## 1. Goal and exit gate
Schedules, recurrence, events, a calendar, conflicts and reminders on top of the P01 core.

Exit gate (DoD §P02): recurrence is bounded, deterministic and has no duplicates (GS-03); DST is correct in at least two zones (GS-04); conflict detection is deterministic. Invariants enforced and tested: LF-INV-PLAN-004/010/011/012/013, LF-INV-CAL-001/002. Static FFs plus FF-ARCH-06/09 for the new handlers.

Out of scope: AI scheduling (P06), external calendar sync, attendees and shared calendars (P04), goals and habit evaluation (P03).

## 2. Starting point (checked in code)
- `time_kernel` is an empty library with `timezone` declared; no tests.
- `foundation` has only `LocalDate` (no arithmetic, comparison or weekday) and `Instant`. `ZonedWallClock`, `TimeOfDayValue`, `Weekday` and a clock do not exist.
- `Task` and the `tasks` table have no schedule fields. No event, calendar, schedule or exception tables. Store schema is v3.
- No Today, Upcoming or Calendar views. No notification or device-timezone plugin.
- Spike S-05 (local notifications on Windows and Android) has **not been run**.
- Risks R-DST and R-RECURRENCE-DUP are cited in phase-breakdown but missing from the risk register (to add).

## 3. Owner decisions (2026-11-07)

| # | Question | Decision |
|---|---|---|
| D1 | OQ-PLAN-1: limits of one window query | Default **1000 occurrences per item per query** and a window of at most **400 days**; beyond that the result is truncated with a visible notice (LF-INV-PLAN-010). **Both are changeable in Settings** (device setting), inside hard bounds so generation always stays bounded: 100–5000 occurrences, 31–1100 days. |
| D2 | Monthly on the 29th–31st, and yearly on Feb 29, when the month has no such day | Two options: **skip that month/year** (default, like Google Calendar) or **use the last day of the month**. The default for new repeats is a **Setting**; see the refinement below. |
| D3 | First day of the week | **Monday** by default, **Sunday** selectable in **Settings**. Used by the week view and as the week start for "every N weeks"; see the refinement below. |
| D4 | OQ-PLAN-2: editing a recurring item | **"Only this occurrence"** (an exception) and **"all occurrences"** (edit the rule; exceptions on unchanged dates are kept, LF-INV-PLAN-011). **"This and following"** is deferred (needs P03 history rules). |
| D5 | Ticking a recurring task (UC-06 step 4) | Ticking marks **that occurrence** done (an occurrence completion keyed by task and original date). The task itself stays open. |
| D6 | OQ-CAL-1: scheduled tasks in the calendar | Shown in the calendar; tapping one opens the **task's** schedule editor. A task is **never turned into an event, nor an event into a task**. |
| D7 | UC-08: conflicts | Conflicts are **only shown**; nothing is stored. All-day and date-only items are **never** in conflicts. |
| D8 | Reminders on Windows | Decided by spike S-05. If Windows cannot fire scheduled notifications while the app is closed, Windows reminds **only while the app runs** (documented). **S-05 result (2026-11-09): Windows fires scheduled notifications with the app closed, so reminders work fully on both platforms.** |
| D9 | Navigation | **Tasks, Calendar, Profiles, Settings**. Today and Upcoming are filters in Tasks; the **Calendar screen has buttons that open Tasks on Today and on Upcoming**. |
| D10 | Time zone of a new timed item | The **device zone** at creation, shown and changeable in the editor. Date-only and all-day items have no zone. |

**Refinement for D2/D3 (accepted by the owner 2026-11-07).** The month-end rule and the week start change *which dates a series has*. If they were only device settings read at display time, the same task would show different dates on two devices with different settings (and after sync in P04), and changing the setting would move existing occurrences away from their exceptions and completions, which are keyed by original date (LF-INV-PLAN-011). Proposal: the Settings value is the **default for new repeats**; each repeat **stores its own** month-end rule and week start (shown and changeable in the repeat editor). Changing the setting never changes existing series. The week start of the **week view** is display only and follows the setting directly. D1 limits are query bounds, not data, so they stay pure device settings.

## 4. Technical design choices (no owner input needed; to be recorded in ADR-0028 during T1)
- **Type homes** (resolves the ADR-0010/0013 ambiguity): plain data types `LocalDate` (with comparison, add days or months, weekday), `TimeOfDayValue`, `Weekday`, `ZonedWallClock` (local date-time + IANA zone name) and `Clock` live in `foundation`. Everything that needs the zone database lives in `time_kernel`: `resolveWallClock`, `ScheduleSpec` validation, `RecurrenceRule` expansion, `OccurrenceWindowQuery`, `OverlapQuery`, `workload`, reminder trigger computation. `foundation` stays free of `timezone`.
- **DST rule** (ADR-0010): gap → first valid minute after the gap; overlap → the earlier instant. Table-driven tests over **Europe/Berlin, America/New_York and Australia/Sydney** (the southern hemisphere checks the opposite season).
- **Recurrence engine**: our own, in the kernel (daily, weekly with weekdays, monthly by day of month, yearly; every N; ends never, on a date or after a count). No rrule library: the scope is small, and a library would need license checks and still need the DST and exception rules on top. "After N" counts from the series start, independent of the window queried (AC-06.1).
- **Storage** (schema v4, additive migration):
  - `schedules`: one row per owner (`owner_type` task|event, `owner_id`), the six shapes as typed columns (start date, start time, end date, end time, zone name, all-day, deadline date and time) plus cached UTC start and end instants for range pre-filtering, plus the rule (frequency, interval, weekdays, end kind, end date, count, **month-end rule, week start**). Whole-value replace, matching ADR-0015 "whole-value LWW" for P04.
- **Settings** (device, encrypted registry, as ADR-0026): max occurrences per query, max window days, default month-end rule, first day of the week. Shown in Settings → Calendar.
  - `occurrence_exceptions`: keyed by (owner, original date); kind skip | move | edit | cancel with typed fields. Keyed rows, matching ADR-0015 "keyed union".
  - `occurrence_completions` (if D5 is accepted): keyed by (task, original date).
  - `calendars` and `events` with the shared syncable columns (ADR-0009).
  - `reminders`: offset-before or absolute instant, per owner.
  - All new tables go into export and restore (LF-INV-SEC-010; guard test). Export `schemaVersion` becomes 4; older files are upgraded additively.
- **Writes**: schedules, exceptions and completions are written by the **owner's** command handler (Task or Event) in the gateway transaction, with audit, outbox and event (ADR-0011/0014). The kernel has no commands.
- **Reads**: `ScheduledItemReader` (task occurrences in a window), `EventsInWindow`, `Conflicts(window)`, `TodayQuery` and `UpcomingQuery`. Occurrences are computed, never stored (FR-PLAN-09, AC-06.3).
- **Reminders**: a `ReminderScheduler` port in `application`; the adapter (from S-05) in the app. After each command that changes a schedule or reminder, and on app start, the app reschedules the next occurrences inside a rolling horizon (for example 14 days, at most 50 pending per profile). Trash, cancel, profile switch and sign-out lock remove them. On a device time-zone change, timed items keep their own zone; only the display changes.

## 5. Tasks
One branch per task, merge after the headless tests pass and the owner checks the device parts (same rules as P01).

| Task | Content | Main proof | Device check | Est. (pd) |
|---|---|---|---|---|
| **T0** Spike S-05 + licenses | Scheduled local notifications on Windows and Android, app closed and open; permissions on Android 13+ and exact alarms. License check of `flutter_local_notifications`, `flutter_timezone` (and SPDX of `timezone`), recorded in verified-sources. Result in spike-results.md, answers D8. Can run alongside T1–T2. | spike report | yes | 1–3 |
| **T1** Time primitives + DST | `foundation` types (§4); `time_kernel`: `resolveWallClock`, `ScheduleSpec` (six shapes, deadline, all-day) and `validateSchedule`. | GS-04 table over 3 zones; LF-INV-PLAN-004 (a date-only spec has no path to an instant); property tests on date arithmetic | no | 2–3 |
| **T2** Recurrence, exceptions, overlap | `RecurrenceRule` (with month-end rule and week start), `OccurrenceWindowQuery` (limits passed in, clamped to the hard bounds; truncation notice), exceptions applied after generation, `OverlapQuery`, `workload`. | GS-03 property tests (any window split gives the same set, exactly N, no duplicates, regenerating is identical); LF-INV-PLAN-010/011/012/013; CAL-002 mapping; both month-end rules and both week starts (D2/D3); limits outside the bounds are clamped (D1) | no | 3–4 |
| **T3** Storage v4 | Tables §4, migration v3→v4, export/restore of the new tables (restore compare and merge cover schedules, exceptions, events, calendars). | migration test on a real v3 file; export guard; GS-20 round trip with schedules, exceptions and events | no | 2–3 |
| **T4** Scheduling tasks | Task commands: set or clear schedule and rule, add exception, complete or reopen an occurrence (D5). `ScheduledItemReader`, Today and Upcoming queries. | FF-ARCH-06 coverage of the new operations; integration tests; AC-06.1–06.4 on the real store | no | 2–3 |
| **T5** Events and calendars | `Event` and `Calendar` aggregates and handler (create, update, exception, cancel, trash and restore, calendars). `EventsInWindow`, `Conflicts`. | LF-INV-CAL-001 (separate ids); FF-ARCH-06/09; conflict determinism with tasks and events mixed | no | 2–3 |
| **T6** UI | Schedule editor on a task (six shapes, deadline, all-day, zone, repeat with month-end rule and week start, reminder); Tasks filters All, Today, Upcoming; Calendar tab with day, week and month views that adapt to width, and buttons to Today and Upcoming (D9); event editor; "only this / all" on recurring items (D4); conflict badges (D7); Settings → Calendar (D1–D3). | widget tests; app integration test on real stores | **yes** | 3–5 |
| **T7** Reminders | Reminder capability on Task and Event, trigger computation in the kernel, `ReminderScheduler` port and adapter, rolling horizon, removal on trash, cancel, switch and lock. | unit tests of trigger times across DST; adapter fake in tests | **yes** (both platforms) | 2–3 |
| **T8** Exit gate | p02-exit-gate.md (DoD line → proof), ADRs, risk register (R-DST, R-RECURRENCE-DUP), invariant matrix; owner review. | all suites, CI | yes | 1 |

T6 is split for review on the devices: **T6a** schedule editor, Tasks filters, Settings → Calendar, device zone ([ADR-0032](../adr/0032-task-schedule-ui-and-device-settings.md)); **T6b** Calendar tab with buttons to Today and Upcoming, event editor, conflict badges ([ADR-0033](../adr/0033-calendar-tab-and-event-editor.md)). The reminder part of the editor comes with T7 ([ADR-0034](../adr/0034-reminders.md)).

Order: T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8, with T0 run in parallel early. T7 depends on T0. Total about 18–28 person-days, inside the roadmap range.

## 6. Risks
- **R-DST** (add to register): wrong times around DST changes. Mitigation: one resolver, ADR-0010 rule, three-zone table tests, `timezone` database pinned and its version recorded.
- **R-RECURRENCE-DUP** (add to register): duplicate or missing occurrences across window boundaries. Mitigation: occurrences keyed by original date, property tests over random window splits.
- **R-BACKGROUND / R-FLUTTER-PLUGIN**: notifications behave differently per platform. Mitigation: spike first, port abstraction, documented fallback (D8).
- **Scope**: the UI (T6) is the largest and least certain item. Mitigation: views read only kernel queries; day, week and month views can ship one at a time.
- **Restore** (P01 T7b/T7c): new tables widen the compare and merge. Mitigation: extend the same planner and its tests in T3, not a second mechanism.
