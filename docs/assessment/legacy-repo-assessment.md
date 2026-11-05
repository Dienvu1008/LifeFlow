# Legacy Repository Assessment: `my_time_manager`

- Status: Draft (Batch 1)
- Date: 2026-11-04
- Subject: `D:\Workspace\Flutter_Projects\My_Own_Repositories\my_time_manager` (read-only, v1.5.3+23, git HEAD `db4c429`, branch `master`)
- Companion: [legacy-component-matrix.md](legacy-component-matrix.md)

Label legend: **[Fact]** Existing Fact, **[Verified]** Verified Finding, **[Assumption]**, **[Proposal]**, **[Open]** Open Question, **[Decision]**. See [../README.md](../README.md).

## 1. Method and limits

- [Verified] Source files were read directly (paths cited per finding). Where a finding relied on regex counts (tests), it is marked approximate.
- [Verified] Nothing was executed. `flutter analyze` and `flutter test` were **not** run, so claims in the legacy repo's own reports ("0 errors", "all tests passing") are [Fact] about what those reports say, not independently verified.
- [Open] Not read in detail: `notification_service.dart` internals, the trash/archive/goal/habit/learning/project repositories, `device_calendar_service.dart`, and the remaining domain models. The matrix marks affected rows with "partial evidence".
- [Fact] The legacy repo has `.agents/` (untracked) holding AI-workflow artifacts. They were not used as evidence.

## 2. Executive summary

`my_time_manager` is a substantial, working personal-productivity app, not a prototype. It already contains: tasks with subtasks and measurable targets, time intervals (the scheduling unit), calendar events (Google-compatible model), Pomodoro focus, notes (AppFlowy), goals/milestones, projects, a learning module, habits, reminders, and a provider-independent local AI agent layer. About 900 test cases exist (approximate).

The code is **not** a good *base* for LifeFlow because its structural choices conflict with LifeFlow's principles (local-first with sync, shared workspaces, deterministic invariants):

1. [Verified] Persistence is a `DatabaseManager` singleton over sqflite with a 18-version `if (oldVersion < N)` ladder; v9 was destructive (`database_manager.dart`, `_onUpgrade`).
2. [Verified] Nested aggregates are stored as JSON in TEXT columns (`tasks.subtasks`, `calendar_events.attendees`, `recurrence`, `reminders`, etc.). Subtasks have no table or foreign key; `timeintervals.subtaskId` has no FK.
3. [Verified] There is no workspace/tenant concept, no ownership column, no operation log/outbox, and no per-row version. Only `updateTimeStamp` (local-time ISO string) and `deviceId` exist. `TaskDao.update` and `TimeIntervalDao.update` do not stamp `deviceId` (inserts do).
4. [Verified] Two unrelated recurrence systems exist (see §4.2), neither using the `rrule` package.
5. [Verified] Referential integrity for polymorphic links (`goal_links`, `project_items`, `reminder_rules`) is trigger-based and fires only on hard delete.
6. [Verified] Focus session recovery after crash is **not** implemented (`PomodoroBloc` keeps phase start in memory only).
7. [Verified] Approvals in the AI layer are bound to arguments by value only, with no version/staleness check.

What is **valuable** is the *knowledge and tested logic* in the legacy repo, which can be ported selectively: the AI abstraction and tool/policy layering, prompt-injection tests, `RepeatRule` occurrence logic, `wall_clock_resolver` DST handling, measurable-target semantics, habit/goal/learning progress calculators, and the import/conflict policy design.

**[Proposal]** Start LifeFlow as a new repository (consistent with the user's decision), port selected pure-Dart logic with its tests, and rewrite persistence, identity, sync and state management.

## 3. What exists (verified inventory)

| Area | Status | Evidence |
|---|---|---|
| Layering | Domain interfaces (`lib/domain/repositories`) + `Sqlite*` adapters + DAOs; DI via one `MultiRepositoryProvider` (~27 providers) | `lib/app/app.dart` L85-210; ARCHITECTURE_REFACTOR_REPORT.md |
| DB | sqflite, schema v18, 13 DAOs, `DatabaseManager` 722 lines | `lib/data/database/database_manager.dart` |
| Models | Real models in `lib/domain/models`; `lib/data/models` has 2 re-export shims | `lib/data/models/*` |
| State mgmt | Mixed BLoC/Cubit and ChangeNotifier; global `PomodoroBloc` | `lib/app/app.dart`; `lib/home/` |
| Navigation | One integer index in `home.dart` + ~40 imperative `MaterialPageRoute` pushes; no route table | `lib/home/home.dart` ~L493-563 |
| AI | `lib/ai` layered, no Flutter/DB dependency except 3 narrow imports | see §4.6 |
| Auth | Firebase Auth + Google sign-in; Windows loopback OAuth with PKCE `plain`; `bypassAuth` defaults to true | `lib/auth/**` |
| Cloud sync | Focus sessions to Firestore (one-way); Google Calendar two-way sync with etag | `focus_sync_service.dart`; `google_calendar_sync_service.dart` |
| Tests | 114 test files, ~920-950 cases (approximate); none for auth, Firestore, notes UI, home | `test/**` |
| CI | None (`.github` absent) | filesystem |
| License | Apache 2.0 | `LICENSE`, `NOTICE` |

## 4. Key findings

### 4.1 Task and TimeInterval model
- [Verified] `Task` (`model_task.dart`) is a unified model: `isMeasurable`, `targetType {atLeast, atMost, about}`, `targetAtLeast/AtMost`, `unit`, `howMuchHasBeenDone`, embedded `List<Subtask>` (each with its own UUID and optional measurable fields). No deadline, no estimate, no status beyond `isCompleted`.
- [Verified] Scheduling lives in `TimeInterval` (`model_time_interval.dart`): `startDate/endDate` (DateTime), `startTime/endTime` (TimeOfDay, stored as minutes since midnight), four `is*Undefined` flags, `reminderMinutesBefore`. The constructor throws `ArgumentError` for invalid combinations, derives timestamps, and also computes volatile "today/this week" flags at construction time (wall-clock dependent state inside a value object).
- [Verified] `TimeInterval.timeZone` defaults to `''` and appears vestigial.
- [Verified] `howMuchHasBeenDone` is a single scalar. There are no per-measurement records, so multiple recordings per cycle, provenance, and evidence are **not** modeled (confirmed by the field list; habits use a separate `habit_occurrences` table).
- [Proposal] Do not port these models. LifeFlow needs date-only vs instant semantics, execution records and evidence separate from targets (see later batches).

### 4.2 Recurrence
- [Verified] `RepeatRule` (`lib/domain/services/repeat_rule.dart`) is hand-rolled (not RFC 5545): frequency, interval, weekdays, end mode {never, onDate, afterOccurrences}. `RecurrenceService.saveWithRepeat` **expands to physical `TimeInterval` rows** with fresh UUIDs and no link to a master. Caps: 1000 occurrences, hard end 2100-12-31.
- [Verified] A cap-free query API (`matchesPattern`/`occurrencesBetween`/`occursOn`) uses pure calendar-day arithmetic, commented as DST-safe.
- [Verified] `CalendarEvent` recurrence is a different system: `recurrence_expander.dart` expands a partial RRULE subset (DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL, COUNT, UNTIL, BYDAY weekly, EXDATE/RDATE) virtually within a window, cap 1000.
- [Verified] The `rrule` package is **not** used by app code; `packages/time_manager` re-exports it but is itself unused.
- [Proposal] Keep the *ideas* (bounded rule, window expansion, date-only arithmetic) and port the `RepeatRule` unit tests as behavioral specs. LifeFlow's model: one rule + exceptions + window-generated occurrences (virtual), per the product brief. Physical expansion conflicts with that brief.

### 4.3 Timezone and DST
- [Verified] `wall_clock_resolver.dart` correctly resolves wall-clock to instant against an IANA `tz.Location`, choosing the earliest instant on fall-back and the first valid minute after a spring-forward gap. This is directly reusable logic.
- [Verified] `RepeatRule` and `HabitDay` are intentionally timezone-naive (local calendar dates, `yyyy-MM-dd` strings), which is the right choice for date-only semantics.
- [Verified] Many persisted timestamps (`updateTimeStamp`, `deletedAt`) are local-time ISO strings with no offset. This is unsafe for multi-device sync.

### 4.4 Focus / Pomodoro
- [Verified] `PomodoroBloc` is global and ticks at 1 Hz; sessions are saved only on phase completion or an explicit stop-with-count. No persistence of an in-progress session, no lifecycle observer. Crash/kill loses the running session.
- [Verified] `FocusSession` has `taskTitle` denormalized and no FK to tasks.
- [Verified] `TimerBloc`/`TimerPage` are unreferenced tutorial leftovers.
- [Proposal] Rewrite focus as a persisted state machine (start timestamp + planned duration, derived remaining time), not a tick counter.

### 4.5 Persistence, sync and backup
- [Verified] Backup/import (`import_service.dart`) merges rows by id with policies `keepLocal | keepIncoming | keepNewest | askEach`, an update-first path for tables with cascades, and sentinel handling for infinite doubles. It is a solid *file-based merge* design, but it is not a sync protocol: no tombstone propagation (hard delete vs soft delete differs per table), no operation identity, no base version.
- [Verified] Google Calendar sync uses `syncStatus` plus etag (`If-Match`) and push-then-pull; per-event errors are swallowed and the loop continues. Pull deletes local rows when Google reports `cancelled`.
- [Verified] Firestore focus sync is one-way upload to `users/{uid}/focus_sessions/{id}`, errors swallowed, no rules in repo.
- [Verified] `DatabaseManager` imports presentation models (`screen_archive`, `screen_trash`). `NotificationService` lives under `screen_focus_timer/data` and is reached from `lib/data/notifications`. Layering is inverted in both places.
- [Verified] Repository notification side effects now go through injected ports (`ReminderScheduler`, `ReminderReconcileTrigger`) defaulting to no-ops. This corrects the older report's claim that `DatabaseManager` calls `NotificationService`. [Open] Whether `reminder_module.dart` L80-85 constructs repositories with no-op defaults was not fully traced.

### 4.6 AI layer
- [Verified] `lib/ai` is layered: `core` (provider-neutral types, `AiEngine`), `config`, `gateway`, `providers` (Ollama HTTP; llama.cpp port + engine), `agent` (bounded loop, text tool-call parser, workflows), `tools` (`Tool`, `ToolRegistry`, `ToolExecutor`, `tool_guard`, domain tools), `policy` (`ActionPolicy`, confirmation, `AiActionLog`), `context` (bounded `ContextBuilder`), `models`, `analytics`.
- [Verified] Imports in `lib/ai`: only three Flutter-related imports (`flutter_timezone`, `kIsWeb`, `TimeOfDay`); zero `DatabaseManager`/`dart:ui` references. Data access is via domain repositories/services.
- [Verified] Untrusted free text is wrapped as `{"untrusted": true, ...}` (`tool_views.dart`), a system rule is included (`AgentConfig.untrustedDataRule`), and `prompt_injection_test.dart` verifies that a destructive call still requires confirmation and is denied under read-only mode.
- [Verified] **Gaps** against LifeFlow's AI governance requirements: no cloud adapter exists (enum only); approval carries no resource version or staleness check (`ConfirmationRequest` has only toolName, risk, summary, arguments); `llama_cpp_dart_backend.dart` is fully commented out; no per-actor/workspace permission model; action log is device-local and excluded from backup.
- [Verified] Tests: ~30 files under `test/ai`, ~300+ cases (approximate regex count; the sub-investigations gave 305 and 337 using different counting).

### 4.7 Auth and cloud
- [Verified] Firebase Auth with email and Google. `firebase_options.dart` is a `REPLACE_ME` placeholder. No `google-services.json` in repo. `AuthConfig.bypassAuth` defaults to **true**, so release builds skip login unless overridden.
- [Verified] Windows OAuth uses a loopback server with PKCE method `plain` (not S256) and re-runs the browser flow each time for the Calendar token (no refresh token stored).
- [Proposal] Do not port auth. The backend decision (ADR-0003) is open; the PKCE `plain` and bypass default are anti-patterns to avoid.

### 4.8 Notes and editor
- [Verified] Notes store `Document.toJson()` as `contentJson TEXT`. The same format is reused for `descriptionDoc` on tasks/lists/intervals and lesson content. `appflowy_editor` is a git dependency on `ref: main`, with `dependency_overrides` for `file_picker` and `device_info_plus`.
- [Verified] Notes UI has hard-coded Vietnamese strings, no tests, no search.
- [Verified] AppFlowy Editor is dual-licensed AGPL-3.0 and MPL-2.0 (VS-16 in [../research/verified-sources.md](../research/verified-sources.md)). Which license applies to a closed-source LifeFlow build is [Open] (OQ-V6); decide in the document-engine batch before any dependency on it is added. Not legal advice.
- [Open] AppFlowy's maintenance status and fit for LifeFlow's block-document needs go to the document-engine batch.

### 4.9 Dead or unused code
- [Verified] `lib/ads_mob/**` (8 files, never imported; AdMob account deactivated per `main.dart` comment). `google_mobile_ads` remains a dependency and `AndroidManifest.xml` still declares an AdMob app id.
- [Verified] `flutter_background_service` (+ android) declared, never referenced in `lib/`.
- [Verified] `packages/time_manager` (device_calendar fork) is not imported by the app; Windows/Linux native parts are template stubs. `packages/calendar_widgets` **is** used (day/week/month views, vendored `table_calendar`) but has an empty test.
- [Verified] Large commented-out legacy `CREATE TABLE` blocks remain in `_onCreate`; `events` legacy table coexists with `calendar_events`.
- [Verified] `PRIVACY.md` is a stale template naming a different product ("V Schedule").

### 4.10 Quality tooling
- [Verified] `analysis_options.yaml` is flutter_lints defaults with no custom rules; it excludes folders that do not exist. `dart_test.yaml` sets `concurrency: 1` because of the DB singleton. No CI. `app.dart` is 1,199 lines; `app_localizations.dart` is 8,386 lines (hand-written).

## 5. Reuse summary

Detail and evidence per component are in [legacy-component-matrix.md](legacy-component-matrix.md).

| Class | Components |
|---|---|
| Reuse (port with tests) | `wall_clock_resolver`, `RepeatRule` date arithmetic (as spec), measurable target semantics, `FocusStatisticsService`, `GoalProgressService`, `LearningProgressService`, `HabitStatisticsService` (concepts), prompt-injection test patterns |
| Refactor (port and reshape) | AI core/gateway/policy/tool layering, `ContextBuilder`, `TextToolCallParser`, import conflict-policy design, reminder ports |
| Replace | Persistence (Drift + migrations), auth, state management/navigation, notes editor binding, Google Calendar sync adapter, focus timer |
| Rewrite | Task/TimeInterval/Event schema, recurrence persistence, sync, workspace/identity, approval binding |
| Drop | `ads_mob`, `flutter_background_service`, `packages/time_manager`, `TimerBloc`, legacy `events` table, `PRIVACY.md` |

## 6. Risks of porting

- [Proposal] Ported code carries Vietnamese-only comments and hand-written localization; each port must translate or drop comments and use ARB-based localization.
- [Proposal] Ported tests assume the sqflite singleton; only pure-Dart logic tests are portable without change.
- [Assumption] The legacy test suite passes. Not verified (see §1).

## 7. Open questions

1. [Open] Does the legacy app have users who need their data later? The user's decision says no migration, so this is out of scope; export format compatibility is not required.
2. [Open] Is AdMob revenue still a goal? Assumed no (account deactivated).

## 8. Self-check checklist

- [x] Every finding in §4 cites a file or states it is a count-based approximation.
- [x] Every finding carries a label.
- [x] Limits of the review are listed in §1.
