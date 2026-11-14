# P03 exit-gate evidence (MVP exit)

Maps each line of the P03 definition of done ([definition-of-done.md](definition-of-done.md)) and of the P03 plans ([p03-plan.md](../roadmap/p03-plan.md), [p03-ux-plan.md](../roadmap/p03-ux-plan.md), [p03-dogfood-1.md](../roadmap/p03-dogfood-1.md)) to the tests and checks that prove it. Status: **signed off by the owner, 2026-11-14**. P03 is the last phase of the MVP (P01 → P02 → P03), so this is also the MVP exit.

How to reproduce:
- `dart test` in `packages/foundation|time_kernel|domain|application|infrastructure`.
- `flutter test` in `packages/ui` and `apps/lifeflow_app`.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- CI runs the same on every push (`.github/workflows/ci.yml`).

`main` at T7: `1c1e399` (dogfooding fixes F1–F5 merged on top of U6, `3e2ebc5`).

## Exit gate (DoD §P03)

| Line | Proof |
|---|---|
| Focus recovery within 1 s and one record per session (GS-13) | `infrastructure/test/focus_commands_test.dart`: "GS-13: kill at minute 12, relaunch: elapsed within 1 s, pauses kept, one record, task untouched" (a second end is refused, still one record, reason LF-INV-EXEC-004); "kill before or after the commit of every step: the last committed state recovers" (start, pause, resume, pause, end, each killed before and after its commit); the D1 group for an overdue pomodoro (count to the planned end, count to now, discard) and the D2 group (one active session; two found after a merge). Domain: `domain/test/focus_test.dart` "kill after any step: the stored session gives the same time on recovery (GS-13 at the domain level)". App on real stores: `app_integration_test.dart` "P03 T3: openSession recovers the running focus session (D1, LF-INV-EXEC-003)". |
| Goal progress derived with no write-back (GS-21) | `infrastructure/test/goals_test.dart` "GS-21: progress is derived from the linked items, never written back; trashing keeps the tasks" (the task rows are compared before and after reads and goal commands); `domain/test/goals_test.dart` "GS-21: the same items always give the same progress; the inputs are untouched"; UI: `ui/test/goal_flow_test.dart` "status: done, archived (read only), trash keeps the tasks, restore (GOAL-002)". |
| A measurable habit completes correctly (GS-01) | `infrastructure/test/habit_tracking_test.dart` group "GS-01: automatic completion is derived": achieved exactly at the target, undone by a correction, the task status never moved, the tick refused (D8), the period closed with the target used. Domain: `measurement_test.dart` group "GS-01: walk at least 5000 steps a day". App on real stores: `app_integration_test.dart` (habit, target, automatic completion, manual measurements, the audit trail) and "P03 T4: openSession closes the ended periods of a habit". |
| Target boundaries (GS-02) | `domain/test/measurement_test.dart` group "GS-02: boundaries, inclusive" (table over atLeast, atMost and about, min == max, open and ended periods). |
| No data is not zero, manual path (GS-05) | `habit_tracking_test.dart` "GS-05: manual completion: measurements show progress, the tick is the user's" and "HEALTH-002: a day without a measurement closes as no data; the rate leaves it out, the streak ends"; `measurement_test.dart` "no value is no data, open or ended, for every type (LF-INV-HEALTH-002)". |

## Invariants

| Invariant | Proof |
|---|---|
| LF-INV-EXEC-001 corrections replace, history kept | `measurement_test.dart` group "aggregation and corrections (LF-INV-EXEC-001)"; `habit_tracking_test.dart` "EXEC-001: a correction replaces the value in the totals; history is kept; provenance kept"; `execution_storage_test.dart` GS-20 round trip (superseded measurements travel too) |
| LF-INV-EXEC-002 time derived from instants | `focus_test.dart` group "time (LF-INV-EXEC-002)" (pauses are not focus time; the pomodoro end moves with them); the GS-13 tests above |
| LF-INV-EXEC-003 a session survives a kill at any step | `focus_test.dart` "kill after any step …"; `focus_commands_test.dart` "kill before or after the commit of every step …"; `app_integration_test.dart` "P03 T3: openSession recovers …" |
| LF-INV-EXEC-004 one record per session | `focus_test.dart` "counting gives one record, without the pauses; a second end is refused"; GS-13 in `focus_commands_test.dart` |
| LF-INV-HEALTH-002 no data ≠ 0 (manual path) | see GS-05 above |
| LF-INV-HEALTH-004 source and device kept (manual path) | `habit_tracking_test.dart` "EXEC-001 … provenance kept" (source `manual`, the device id, the note and the date of a measurement); `execution_storage_test.dart` round trip of those fields; the app integration test asserts `source` on the real store |
| LF-INV-TASK-010 a target never sets the task's status | `habit_tracking_test.dart` GS-01 ("never set by the data (LF-INV-TASK-010)") and "target and policy rules"; `task_rules_test.dart` group "measurable target validation (LF-INV-TASK-010 groundwork)"; the app integration test |
| LF-INV-GOAL-001 progress is a pure function | domain and infrastructure GS-21 tests |
| LF-INV-GOAL-002 trashing a goal keeps its items | infrastructure GS-21; `goal_flow_test.dart` (GOAL-002) |
| LF-INV-GOAL-003 links stay in one workspace | `goals_test.dart` "GOAL-003: an item in another workspace is refused" |
| LF-INV-ORDER-001…004 (added by U2, ADR-0046) | `domain/test/order_key_test.dart` and the list and move tests of ADR-0046 (`overview_test`, `overview_export_test`) |

All of them appear in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md) (P03 status section).

## Fitness functions and governance

| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | `tools/fitness/ff_arch_01_pure_domain.dart` (the new focus, measurement and goal rules are pure Dart) |
| FF-ARCH-04 UI isolation | `tools/fitness/ff_arch_04_ui_isolation.dart` |
| FF-ARCH-06 atomic set for the new handlers | `infrastructure/test/atomic_set_test.dart`, with fault injection for every P03 operation: habit, target and completion; record, correct, record in a closed period; period close; every goal, milestone and link op; every focus op (start, pause, resume, end, cancel, mark unrecoverable); list create, rename, colour, move, trash, restore; task and event move and colour; task notes (F3); the profile's manual-results setting (U-D13). The new handlers (Focus, Measurement, PeriodClose, Goal, List) are in the registry that `ff_arch_06_09.dart` checks. |
| FF-ARCH-07 licenses | `tools/fitness/ff_arch_07_licenses.dart`: 130 shipped packages and libraries, all accepted; self-test `ff_arch_07_test.dart` |
| FF-ARCH-09 authorize before domain | `ff_arch_06_09.dart` + `authorization_gate_test.dart`; the new handlers run through the same single gateway |
| FF-ARCH-10 no raw UI strings (added in U1, ADR-0045) | `tools/fitness/ff_arch_10_ui_strings.dart`: 44 left in 9 files, none above the baseline |
| Export and restore cover the new tables (LF-INV-SEC-010) | `execution_storage_test.dart` (GS-20 with every P03 row, untrusted rows refused, a schema-4 file restores, restore into the same profile: identical, merge, overwrite with tombstones); `profile_export_test.dart` "covers every table of the schema"; `overview_export_test.dart` (schema-6, 7 and 8 files: order keys, the result policy, notes) |
| Store upgrades (schema v5 → v9) | `profile_directory_test.dart` "an existing v$from profile store upgrades to the latest schema, data intact" for v2–v8, which checks every column of every table after the upgrade (hardened in F3) |

## Universal DoD

| Line | Status |
|---|---|
| Build passes on Windows and Android; analyze clean | Debug builds for Windows and Android from `main` at T7 (see "Builds" below); the owner ran both platforms in two dogfooding passes. `dart analyze` / `flutter analyze` clean in every package. CI does not build for the devices (as in P01/P02). |
| Static fitness functions | FF-ARCH-01, 04, 07 and 10 green in CI. FF-ARCH-02, 03 and 05 still have no scripts, as at the P01 and P02 exits. |
| All phase tests pass | foundation 13, time_kernel 92, domain 72, application 3, infrastructure 334, ui 289, app 26 (local on `main` at T7, and CI on every F1–F5 branch), plus the FF-ARCH-07 self-test. |
| Every P03 invariant has a passing verification row | see "Invariants" above and the matrix |
| New dependencies have a verified license | `intl` BSD-3 (VS-36), `flutter_sticky_header` + `value_layout_builder` MIT (VS-37), `table_calendar` + `simple_gesture_detector` Apache-2.0 (VS-38), the bundled fonts Inter, Noto Sans and Be Vietnam Pro under SIL OFL 1.1 (VS-39, licenses registered in the app). All in the FF-ARCH-07 inventory. |
| ADRs for decisions with trade-offs | ADR-0036 (domain rules), 0037 (storage v5), 0038 (focus commands), 0039 (habits, targets, measurements, results; v6), 0040 (goals and projects), 0041 (habits UI), 0042 (focus UI), 0043 (goals UI), 0044 (navigation drawer), 0045 (UI foundation, FF-ARCH-10), 0046 (lists, colours, order keys; v7), 0047 (Overview), 0048 (Timeline), 0049 (Calendar time grid), 0050 (six destinations, manual results; v8), 0051 (dogfooding pass 1, F1–F5; v9) |

## Owner decisions applied
- P03 plan D1–D12, with D6 revised by the owner and D6a–D6c as proposed (2026-11-10).
- UX plan U-D1–U-D12 (2026-11-11) and U-D13 (2026-11-13).
- Dogfooding pass 1, groups F1–F5 (2026-11-13), all merged 2026-11-14.

## Device checks
The owner asked to check every P03 screen on the devices in one pass instead of after each UI task (ADR-0041, 0042, 0043; p03-ux-plan.md §4).
- [x] Dogfooding pass 1 on Android and Windows, after U1–U6 (owner, 2026-11-13): feedback recorded as F1–F5 in p03-dogfood-1.md; no data or recovery problem was reported.
- [x] Dogfooding pass 2 on Android and Windows, on F1–F5 (owner, 2026-11-14): approved, merged.
- [x] Focus kill and relaunch on Windows and Android (ADR-0042): after the app was closed and opened again, the focus timer went on running (owner, 2026-11-14). Headless proofs: the GS-13 tests above.
- [x] Pomodoro-end notification with the app closed, on Windows and Android (ADR-0042): it showed (owner, 2026-11-14). It uses the reminder adapter checked on both devices in P02 (S-05, P02 T7).

## Builds
- `flutter build windows --debug` and `flutter build apk --debug` from `main` at `1c1e399` (agent, 2026-11-14): both built (`lifeflow_app.exe`, `app-debug.apk`).

## Known limits carried out of P03 (the MVP)
- Hybrid completion and health-sourced measurements: P08. AI analytics: P06. Shared goals and syncing two devices of one account: P04 (the manual-results setting is not synced either).
- "This and following" edits of a repeat: still deferred.
- Focus: no pomodoro cycles (D3); the optional break timer after a pomodoro is not built; unrecoverable sessions are explained once at start but have no list screen.
- The manual-results setting (U-D13) applies only to periods that close after the change; stored results are never rewritten (D9).
- UI: English only (localisation infrastructure in place, U-D11); no two-pane layout on wide windows yet (U-D12); no profile photos.
- Timeline: a long title slides once per change, then rests with an ellipsis (F4). Calendar: Today, a chosen day or month and the view switcher jump without a slide (F5).
- Carried from P02: rolling 14-day reminder horizon; the device zone is read at app start.

## Risks
- R-DATA-LOSS: P03 adds focus sessions, measurements and drag and drop. Mitigated by persisting every focus transition in one transaction, kill tests at every step (GS-13), one command per drop and the store-upgrade column check; register updated.
- R-SCOPE: the UX plan (U1–U6) and dogfooding (F1–F5) were added before the exit by the owner's decision and kept inside ADR-0005; the deferred items are listed above; register updated.
- R-LICENSE-SCAN: the new P03 packages and fonts were recorded (VS-36–39) before their merges; FF-ARCH-07 covers 130 packages and libraries; register updated.

## Owner sign-off
- [x] Dogfooding pass 2 approved and F1–F5 merged with `--no-ff` (owner, 2026-11-14).
- [x] CI green on every F1–F5 branch head (`9359e61`, `8923a19`, `8eff439`, `84fe715`, `4f12bb0`).
- [x] Owner approves P03 as done (2026-11-14).

**P03 status: Done (2026-11-14). The MVP (P01–P03) is complete.**
