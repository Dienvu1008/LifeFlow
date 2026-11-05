# Legacy Component Matrix: `my_time_manager`

- Status: Draft (Batch 1)
- Date: 2026-11-04
- Companion: [legacy-repo-assessment.md](legacy-repo-assessment.md)

Classification: **Reuse** (use essentially as-is, maybe a straight port), **Refactor** (port the idea/logic but reshape the API), **Replace** (a different design/implementation is more suitable), **Rewrite** (not practically reusable). Confidence is **High** when read directly in full, **Medium** when read partially or via sub-agent summary, **Low** when inferred.

## Domain logic

| Component | Evidence | Classification | Rationale | Port cost | Risk |
|---|---|---|---|---|---|
| `RepeatRule` occurrence generation (`lib/domain/services/repeat_rule.dart`) | Read in full via sub-agent; bounded (1000 occ, hard end 2100), calendar-aware month/year math | Refactor | Logic and edge-case handling (month clamping, 1000 cap) are good references; physical-expansion persistence model conflicts with LifeFlow's virtual-occurrence requirement | Medium — port algorithm, not persistence | Low |
| `RepeatRule` day-matching (`matchesPattern`/`occurrencesBetween`/`occursOn`) | Same file, DST-safe by design (day arithmetic, no `Duration` across days) | Reuse (as a ported, tested utility) | Directly answers "does this date match the rule" without generating a list — useful for virtual occurrence windows | Low | Low |
| `wall_clock_resolver.dart` | Read in full; handles DST fall-back (earliest instant) and spring-forward gap (binary search) | Reuse | Correct, narrow, well-tested wall-clock↔instant logic against `timezone` package | Low | Low |
| Google Calendar recurrence expander (`recurrence_expander.dart`) | Sub-agent summary; partial RFC 5545 subset, virtual, windowed, cap 1000 | Refactor | Useful reference for windowed virtual expansion of real RRULE strings from external calendars; the app does not use the `rrule` package at all | Medium | Medium — subset is partial, needs RFC 5545 validation against the full spec in a later batch |
| Measurable target model (`TargetType {atLeast, atMost, about}`, `targetAtLeast/AtMost`, `unit`, `howMuchHasBeenDone`) | Read in full (`model_task.dart`, `model_time_interval.dart`) | Refactor | Semantics are a reasonable starting taxonomy, but `howMuchHasBeenDone` is a single scalar with no execution-record/evidence separation required by LifeFlow | Low (concept only) | Low |
| `TaskCompletionService` / `TimeIntervalProgressService` | Sub-agent summary, thin wrappers over `copyWith` + repository update | Replace | Simple enough that re-deriving against the new aggregate design is cheaper than adapting | — | Low |
| `GoalProgressService`, `LearningProgressService` | Sub-agent summary; pure, derived, read-only ratio calculators | Reuse (as ported pure functions) | Deterministic, no side effects, good test target | Low | Low |
| `FocusStatisticsService` | Referenced in `AI_ARCHITECTURE_REPORT.md` and audit; pure aggregator over sessions | Reuse (as ported pure function) | Deterministic aggregation with no AI/network dependency | Low | Low |
| Habit day model (`HabitDay`, `yyyy-MM-dd` string, no timezone) | Sub-agent summary | Reuse (concept) | Correct date-only representation pattern to copy for LifeFlow's date-only semantics | Low | Low |

## Data and persistence

| Component | Evidence | Classification | Rationale | Port cost | Risk |
|---|---|---|---|---|---|
| `DatabaseManager` (singleton, sqflite, v18 ladder) | Read in full (722 lines) | Rewrite | Singleton, sequential `if` migrations, one destructive migration (v9), imports presentation models | High to adapt, so rewrite on Drift instead | High if ported as-is |
| Task/TimeInterval/CalendarEvent schema (JSON-in-TEXT for subtasks, attendees, recurrence, reminders) | Read in full | Rewrite | Conflicts with the product brief's requirement to avoid untyped JSON blobs for structured sub-entities and to have stable identity or FKs | — | High |
| Soft-delete + archive columns pattern | Read in full | Refactor | The two-state (trash/archive) idea is reusable; implementation (per-table column duplication, string-compared ISO dates) should be redesigned with typed columns and a shared base | Low (concept) | Medium |
| Trigger-based cascade for polymorphic links (`goal_links`, `project_items`, `reminder_rules`) | Read in full | Replace | Fires only on hard delete, not soft delete; a typed join/ownership model is more consistent with "no domain accesses another domain's persistence" | — | Medium |
| Backup/import conflict policy (`keepLocal/keepIncoming/keepNewest/askEach`, update-first for cascading tables, double sentinel encoding) | Read in full | Refactor | The policy enumeration and double-sentinel trick are reusable ideas for a real sync engine's conflict strategy catalog | Low (concept) | Low |
| Google Calendar sync (`syncStatus` + etag, push-then-pull) | Read in full | Refactor | Etag-based optimistic concurrency against Google is a valid pattern to study for the ACL/anti-corruption layer to Google Calendar, planned as a later integration, not MVP | Medium | Medium |
| Firestore focus sync (one-way upload) | Sub-agent summary | Replace | One-way, no rules in repo, tied to Firebase; backend choice is open (ADR-0003) | — | Low |
| `lib/data/models` re-export shims | Read in full (4 lines each) | Drop | Dead indirection; real models are in `lib/domain/models` | — | Low |

## AI layer

| Component | Evidence | Classification | Rationale | Port cost | Risk |
|---|---|---|---|---|---|
| `AiEngine` abstraction + request/response/message/stream types (`lib/ai/core`) | Sub-agent, full-file reads of key files | Reuse (as a ported, reshaped package) | Provider-neutral, no Flutter/DB dependency, well-tested (31 cases in `ai_abstraction_test.dart`) | Medium | Low |
| `AiGateway` / `ProviderCandidate` / `AiEngineFactory` | Read `ai_engine_factory.dart` in full | Refactor | Clean seam for provider routing; needs a real cloud candidate and privacy-level routing criteria per LifeFlow's AI architecture (later batch) | Medium | Low |
| `ToolRegistry` / `ToolExecutor` / `Tool` / `tool_guard` | Read `tool_executor.dart` in full | Refactor | Solid choke-point design (policy → confirmation → execute → audit); needs resource-version binding on approval, which is currently missing | Medium | Medium — must close the staleness gap before reuse |
| `ActionPolicy` / `ConfirmationRequest` / confirmation UI binding | Read `action_policy.dart`, `confirmation.dart` in full | Refactor | Destructive-action gating is real and enforced; `ConfirmationRequest` has no version/timestamp field (verified absence) | Medium | Medium |
| `ContextBuilder` (bounded context snapshot) | Sub-agent summary, confirmed no raw DB dump | Reuse (concept, reshape for workspace scoping) | Matches LifeFlow's "no full DB to the LLM" principle; needs workspace/permission scoping added | Medium | Low |
| `AgentRuntime` / `TextToolCallParser` / workflows | Read `agent_runtime.dart` in full | Refactor | Bounded tool loop with cancellation is a good base; text-tool-call recovery is valuable for small local models | Medium | Low |
| Untrusted-data tagging + `prompt_injection_test.dart` | Read test file in full | Reuse (port the test strategy directly) | Concrete, executable proof of a real mitigation; port the pattern and the test itself | Low | Low |
| `AiActionLog` (local-only, excluded from backup) | Sub-agent summary | Refactor | Good audit concept; needs to become a durable, exportable, per-workspace audit trail | Medium | Medium |
| `llama_cpp_dart_backend.dart` | Read in full; entirely commented out | Drop (for MVP); revisit later | Not wired, mobile-only native binding, explicit opt-in steps documented in-file | — | Low |
| Cloud provider adapter | Confirmed absent (enum/placeholder only) | N/A (nothing to reuse) | Must be designed from scratch in the AI architecture batch | — | — |

## Auth, notifications, UI shell

| Component | Evidence | Classification | Rationale | Port cost | Risk |
|---|---|---|---|---|---|
| `AuthRepository` / `AuthBloc` (Firebase + Google) | Sub-agent, full-file read of `google_desktop_sign_in.dart` | Replace | Backend is undecided (ADR-0003); Windows PKCE uses `plain`, not S256; `bypassAuth` defaults true | — | High if copied as-is (security defaults) |
| Windows loopback OAuth pattern (local server, state check, PKCE) | Read in full | Refactor (concept only) | The loopback-server technique for desktop OAuth is reusable; the PKCE method and missing refresh-token handling must be fixed | Low (concept) | Medium |
| Notification scheduling ports (`ReminderScheduler`, `ReminderReconcileTrigger`) | Sub-agent summary, confirmed no-op defaults exist | Refactor | The "inject a port, default to no-op" pattern cleanly decouples persistence from side effects; reshape for the new domain boundaries | Low (concept) | Low |
| `NotificationService` (flutter_local_notifications + audioplayers split by platform) | Not read in full (Open) | Refactor (tentative) | Platform-branching approach is reasonable; must be re-verified before reuse | — | Unknown (Open) |
| AppFlowy editor integration (notes, `descriptionDoc` reuse across entities) | Sub-agent summary | Replace | Git-`main` dependency, no pin; dual-licensed AGPL-3.0/MPL-2.0 (VS-16), license applicability to LifeFlow is open (OQ-V6); reusing one JSON format across unrelated entities blurs the Document/Knowledge boundary the product brief requires to stay separate | — | Medium |
| State management (mixed BLoC/Cubit/ChangeNotifier) | Sub-agent summary, `app.dart` read in part | Rewrite | Mixed patterns increase onboarding cost for a coding agent; pick one pattern for LifeFlow | — | Low |
| Navigation (`home.dart` integer index + imperative pushes) | Sub-agent summary | Rewrite | No route table; LifeFlow's adaptive multi-pane UI needs a declarative router | — | Low |
| `PomodoroBloc` focus timer | Sub-agent summary | Rewrite | No crash recovery; LifeFlow requires persisted session recovery per the product brief | — | Medium |
| `packages/calendar_widgets` (day/week/month views) | Sub-agent summary | Refactor (evaluate later) | Actively used UI widgets, reasonable size, but untested; evaluate against Flutter calendar packages in a later UI batch | Medium | Medium |

## Do-not-carry-over list

| Component | Reason |
|---|---|
| `lib/ads_mob/**` | Unused Google sample code; AdMob account deactivated |
| `flutter_background_service` (+android) | Declared dependency, zero references in `lib/` |
| `packages/time_manager` | Unused device_calendar fork; Windows/Linux native parts are stubs |
| `TimerBloc` / `page_focus_timer.dart` legacy pair | Unreferenced tutorial leftover |
| Legacy `events` table | Superseded by `calendar_events`, kept only for history |
| `PRIVACY.md` | Stale template naming a different product |
| `DatabaseManager` singleton pattern | Conflicts with testable, modular persistence |
| `AuthConfig.bypassAuth = true` default | Unsafe default to avoid repeating |
| PKCE `plain` method | Security anti-pattern; use S256 |

## Port candidates (ranked)

1. AI core abstraction, tool/policy/executor layering, and prompt-injection test pattern — highest value, directly supports LifeFlow's AI governance requirements.
2. `wall_clock_resolver` DST handling — small, correct, immediately reusable.
3. `RepeatRule` day-matching and bounded generation algorithm — reshape for virtual occurrences.
4. Derived-progress calculators (goal/learning/habit/focus statistics) — pure functions, cheap to port with their tests.
5. Backup/import conflict-policy catalog — informs the sync engine's conflict-resolution design (later batch).

## Self-check checklist

- [x] Every row has at least one evidence citation or an explicit "not read in detail" marker.
- [x] Every row has a classification label and a confidence level implied by its evidence column.
- [x] The do-not-carry-over list is evidence-based, not name-based guessing.
