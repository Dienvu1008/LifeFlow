# P02 exit-gate evidence

Maps each line of the P02 definition of done ([definition-of-done.md](definition-of-done.md)) and of the P02 plan ([p02-plan.md](../roadmap/p02-plan.md)) to the tests and checks that prove it. Status: **signed off by the owner, 2026-11-10** (L-1 decided: option (a), ADR-0035; see the end of this document).

How to reproduce:
- `dart test` in `packages/foundation|time_kernel|domain|application|infrastructure`.
- `flutter test` in `packages/ui` and `apps/lifeflow_app`.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- CI runs the same on every push (`.github/workflows/ci.yml`).

`main` at the start of T8: `8e29909` (T7 merged).

## Exit gate (DoD §P02)

| Line | Proof |
|---|---|
| Recurrence is bounded, deterministic, no duplicates (GS-03) | `time_kernel/test/recurrence_test.dart`: "after 10" over one window and over any split of windows gives exactly the same 10 dates (no duplicates, no gaps); regenerating is identical (AC-06.2); the engine matches an independent reference on random rules and windows; windows and counts over the limits are cut and say so; limits outside the hard bounds are clamped (D1). On the real store: `infrastructure/test/task_scheduling_test.dart` AC-06.1–06.3 (exactly 10 across windows, identical when repeated, one stored row however many occurrences) and truncation reported. |
| DST correct in at least two zones (GS-04) | `time_kernel/test/dst_test.dart`: GS-04 table over Europe/Berlin, America/New_York, Australia/Sydney and the half-hour Australia/Lord_Howe (gap → transition, overlap → earlier instant), a property test (an instant shown as a wall clock resolves back to itself), a daily 09:00 that keeps its wall clock across the change. Again on events: `events_calendar_test.dart` (a daily 09:00 event in Berlin stays 09:00). For reminders: `time_kernel/test/reminders_test.dart` (spring gap, autumn overlap, a New York change). |
| Conflict detection deterministic | `time_kernel/test/overlap_test.dart`: matches brute force and ignores input order (AC-08.1, property); touching is no conflict. `events_calendar_test.dart`: events and tasks mixed; only timed, open, overlapping items; the same result twice; cancelled occurrences and events never conflict. UI: `ui/test/calendar_layout_test.dart` and `calendar_flow_test.dart` show it on both items. `app_integration_test.dart`: on the real store, an event made in the Calendar tab and a task planned in its editor show the overlap on both rows. |

## Invariants

| Invariant | Proof |
|---|---|
| LF-INV-PLAN-004 date-only preserved | `time_kernel/test/schedule_test.dart` (a date-only point has no instant and stays a date); `planning_storage_test.dart` (stored as text dates only); the one documented conversion is the all-day reminder anchor (09:00 in the device zone, ADR-0034), tested in `reminders_test.dart` |
| LF-INV-PLAN-010 bounded and deterministic | `recurrence_test.dart` bounds group + reference property test; `task_scheduling_test.dart` truncation; settings clamp in `task_scheduling_test.dart` (T6a) and `ui/test/schedule_flow_test.dart` (Settings bounds) |
| LF-INV-PLAN-011 exceptions survive rule edits | `recurrence_test.dart` ("exceptions survive a rule edit that keeps their date"); `task_scheduling_test.dart` AC-06.4 on the real store; per-series month-end rule and week start stored with the series (D2/D3 refinement), so changing a setting never moves existing occurrences (`schedule_flow_test.dart`: "an existing repeat keeps its own month-end rule") |
| LF-INV-PLAN-012 no duplicate occurrences | `recurrence_test.dart` (any split, reference property test); identity = original date everywhere (agenda keys, completion and exception ids, reminder keys) |
| LF-INV-PLAN-013 wall clock across DST | `dst_test.dart`, `recurrence_test.dart`, `events_calendar_test.dart`, `reminders_test.dart` (see GS-04) |
| LF-INV-CAL-001 event distinct from task | `events_calendar_test.dart` (an event cannot take the id of a task; a deadline is refused); `app_integration_test.dart` (an event made in the UI is stored as an event with its own id); the UI never converts one into the other (D6): tasks in the calendar keep their own row and actions (`calendar_flow_test.dart`) |
| LF-INV-CAL-002 all-day excluded from conflicts | `overlap_test.dart` ("all-day and date-only schedules never take part"); `events_calendar_test.dart` (all-day items excluded); the event editor says so (`calendar_flow_test.dart`) |

All seven also appear in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md) with their layers.

## Fitness functions and governance

| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain (`foundation` without `timezone`) | `tools/fitness/ff_arch_01_pure_domain.dart` |
| FF-ARCH-04 UI isolation (UI on application ports and `foundation` types only; no Time Kernel in the UI) | `tools/fitness/ff_arch_04_ui_isolation.dart` |
| FF-ARCH-06 atomic set for the new handlers | `infrastructure/test/atomic_set_test.dart` with fault injection for every new operation: task schedule, exception, occurrence done, clear schedule, reminders (set and shrink); event create, update, exception, reminders, cancel, trash, restore; calendar create, update, trash. Guard 1 of `ff_arch_06_09.dart` requires every handler to appear there. |
| FF-ARCH-09 authorize before domain | `tools/fitness/ff_arch_06_09.dart` + `authorization_gate_test.dart` (unchanged single apply site; the new handlers run through the same gateway) |
| Single mutation path | every schedule, exception, completion, event, calendar and reminder change is a command through the gateway, with audit and outbox rows (outbox assertions in `task_scheduling_test.dart`, `events_calendar_test.dart`, `reminders_test.dart`) |
| Export and restore cover the new tables (LF-INV-SEC-010) | `planning_storage_test.dart`: GS-20 round trip with every planning row, untrusted rows refused (SR-14), a schema-3 file still restores, restore into the same profile covers the new tables (identical, merge, overwrite with tombstones) |

## Universal DoD

| Line | Status |
|---|---|
| Build passes on Windows and Android; analyze clean | Debug builds for Windows and Android at every task (T6a, T6b, T7), last on the T7 branch (`80336cb`); `dart analyze` / `flutter analyze` clean in every package. CI does not build for the devices (as in P01); the builds are local. |
| Static fitness functions | FF-ARCH-01, 04 and **07 (license scan, added in T8, ADR-0035)** green in CI. FF-ARCH-02, 03 and 05 have no scripts yet, as at the P01 exit (P01 gate lists 01/04/06/09). |
| All phase tests pass | foundation 13, time_kernel 87, domain 17, application 3, infrastructure 224, ui 148, app 20 (local and CI on the T8 branch), plus the FF-ARCH-07 self-test (11 cases). |
| Every P02 invariant has a passing verification row | see "Invariants" above and the matrix |
| New dependencies have a verified license | `timezone` 0.11.2 BSD-2 (VS-32), `flutter_local_notifications` 22.3.3 BSD-3 (VS-33), `flutter_timezone` 5.1.1 Apache-2.0 (VS-34), `desugar_jdk_libs` 2.1.4 GPL-2.0 + Classpath Exception (VS-35, accepted by ADR-0035 with its notices shipped). All 125 shipped packages and libraries are in the FF-ARCH-07 inventory. |
| ADRs for decisions with trade-offs | ADR-0028 (time types, DST), 0029 (schema v4), 0030 (task scheduling, agenda), 0031 (events, calendars, conflicts), 0032 (schedule UI, device settings), 0033 (Calendar tab, event editor), 0034 (reminders), 0035 (GPL-2.0 + Classpath Exception for Android desugaring, ADR-0018 rule 7); plan and owner decisions D1–D10 in p02-plan.md |

## L-1: license decision (decided)
**Decision (owner, 2026-11-10): option (a)**, recorded in [ADR-0035](../adr/0035-gpl-classpath-exception-for-android-desugaring.md) (ADR-0018 rule 7). The owner asked whether (a) blocks a commercial store release. It does not: the Classpath Exception allows distributing the combined app under terms of our choice; the conditions are unmodified use, no copied code, and the notices in the app.

Done in T8:
- The notices are fetched from a pinned commit with checked hashes and shown under Settings → Open-source licenses.
- FF-ARCH-07 runs in CI over every shipped package and Android library.

The analysis that led to the decision:
`flutter_local_notifications` (10+) requires Android core-library desugaring, so T7 added `com.android.tools:desugar_jdk_libs:2.1.4` to the Android build. Its code is compiled into the APK.
- **License:** GPL-2.0 with the Classpath Exception (OpenJDK libraries; files `LICENSE`, `ASSEMBLY_EXCEPTION`, `ADDITIONAL_LICENSE_INFO` of google/desugar_jdk_libs). The Classpath Exception allows linking it with independent modules under other licenses without the whole app becoming GPL. Copying its code into our files is not allowed.
- **The gap:** ADR-0018 accepts MIT, Apache-2.0, BSD and MPL-2.0, and LGPL only with a compliance method. It says nothing about GPL with the Classpath Exception. By rule 4 (unknown or not covered → reject), the dependency should have been decided before T7 merged. I missed this in T7.
- **Options:**
  - (a) Accept GPL-2.0 + Classpath Exception as a recorded exception in ADR-0018, for this build-time Android library only. Compliance: unmodified, used through the Android toolchain, its notices kept in the app's open-source notices. This is how Android apps commonly use it.
  - (b) Remove desugaring. That needs a reminder plugin without it, or a small own Android alarm adapter behind the same `ReminderScheduler` port; estimate 1–2 days.
  - (c) Ship Android without scheduled reminders until (b) is done.
- **Recommendation:** (a), plus an FF-ARCH-07 license scan in CI so the next case is flagged before merge.

## Owner decisions applied
D1–D10 and the D2/D3 refinement (p02-plan.md §3), with the proofs listed in the ADRs. D8 was answered by spike S-05: reminders fire with the app closed on both platforms (spike-results.md).

## Device checks
- [x] T0 / S-05: scheduled notifications on Windows and Android, app open and closed (owner, 2026-11-09).
- [x] T6a: schedule editor, Today and Upcoming, Settings → Calendar (owner approved the merge, 2026-11-10); the agent also ran it on Android: device zone `Asia/Ho_Chi_Minh` read, a daily schedule shown in Today, the filter bar fixed for a large font.
- [x] T6b: Calendar tab, event editor, conflicts (owner approved the merge, 2026-11-10).
- [x] T7 Android (agent, 2026-11-10): exact alarm registered, reminder posted at 12:16:00 with the app in the background, text "Starts Tue 10 Nov, 12:16".
- [x] T7 Windows, found and fixed (2026-11-10):
  - The owner found that reminders did not fire with the app closed.
  - Cause: Windows drops scheduled toasts for an app id it has never shown a notification for ("Element not found" in its push-notification log). The S-05 probe had passed only because it showed a toast first.
  - Fix: the adapter registers the app id with one "Reminders are on" notification and reports "turned off in Windows settings" (ADR-0034, S-05 correction).
  - Verified by the agent end to end: real app, window closed normally, reminder delivered at the minute.
- [x] T7 Windows, owner re-check after the fix: a reminder showed with LifeFlow closed (owner, 2026-11-10).

## Known limits carried out of P02
- "This and following" edits of a repeat (D4): deferred to after P03.
- Reminders use a rolling 14-day horizon (max 50). If the app is not opened for more than 14 days, later reminders are not scheduled; Settings says so. The all-day reminder time is a fixed 09:00 in the device zone.
- The device zone is read at app start; a change while running applies after a restart.
- The day view is a list, not an hour grid; the Material date picker starts its week on Sunday (English locale) regardless of D3.
- Saving a schedule and its reminders are two commands; a failure of the second is shown (for a new event the editor closes and says what was not saved).
- No attendees, shared calendars or external calendar sync (P04+). Two devices of one account still do not sync (P04).
- OQ-S8 and OQ-S9 remain with P04 (owner, 2026-11-07).
- No row indicator yet for "this task has reminders".

## Risks
- R-DST and R-RECURRENCE-DUP: mitigations in place and validated (GS-04, GS-03); register updated.
- R-BACKGROUND / R-FLUTTER-PLUGIN: S-05 PASS on both platforms; T7 Android device check PASS; register updated.
- New: **R-LICENSE-SCAN** (a dependency outside ADR-0018 merged without a decision). It came from L-1 and is mitigated: FF-ARCH-07 in CI since T8.

## Owner sign-off
- [x] L-1 decided: (a), ADR-0035 (owner, 2026-11-10).
- [x] T7 Windows device check confirmed after the fix (owner, 2026-11-10).
- [x] CI green on the T8 branch (`b070368`, run 42784381706).
- [x] Owner approves P02 as done (2026-11-10).

**P02 status: Done (2026-11-10).**
