# Domain: Planning and Scheduling (Time Kernel)

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Classification: Core. Phase: P02. In MVP: yes. Packaging: standalone `time_kernel` package ([ADR-0013](../adr/0013-time-kernel-packaging.md)).
- Related: [ADR-0007](../adr/0007-single-schedule-with-derived-occurrences.md), [ADR-0010](../adr/0010-time-model-date-only-vs-instant.md), [../research/verified-sources.md](../research/verified-sources.md) VS-20

## 1. Purpose
One correct, stateless implementation of time semantics: schedule validation, recurrence, occurrence generation, DST resolution, overlap detection and workload math. No persistence, no Flutter, no network. Owners (Task, Event) store the value objects; the kernel computes over them.

## 2. Aggregate roots and boundaries
None. The kernel is stateless. It defines value objects and pure functions. There is no repository.

## 3. Value objects
- `ScheduleSpec` (one of the six shapes, FR-PLAN-01): built from `LocalDate`, `TimeOfDayValue`, `ZonedWallClock`, `Instant`, `Duration`, plus a `deadline?` distinct from the execution time (FR-PLAN-03) and an `allDay` flag. Exactly one `ScheduleSpec` per owner (ADR-0007).
- `RecurrenceRule` (FR-PLAN-06/07): `frequency {daily, weekly, monthly, yearly}`, `interval: int`, `byWeekday: Set<Weekday>?` (weekly), `end {never, onDate(LocalDate), afterCount(int)}`. Bounded.
- `OccurrenceException` (FR-PLAN-08): `seriesId`, `originalDate: LocalDate`, `kind {skip, move(to), edit(patch), cancel}`.
- `Occurrence`: `seriesId`, `originalDate`, `effectiveStart`, `effectiveEnd?`, `isException`.
- `Conflict`: pair of overlapping `TimedItem`s.

## 4. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-PLAN-004 | Date-only `ScheduleSpec` is never converted to an instant implicitly | type separation (ADR-0010) |
| LF-INV-PLAN-010 | Occurrence generation is bounded (max per window) and deterministic | `OccurrenceWindowQuery` (hard cap + pure function) |
| LF-INV-PLAN-011 | Exceptions survive rule edits that do not change their `originalDate` | exceptions keyed by original date, applied after generation |
| LF-INV-PLAN-012 | No duplicate occurrences in one window | generation de-dupes by `originalDate` |
| LF-INV-PLAN-013 | A timed recurring item keeps its wall-clock time across DST | `ZonedWallClock` + DST resolver (ADR-0010) |

[Decision] The maximum occurrences returned per window query is bounded (value set in the technical batch, e.g. a few thousand) and a window is always required; there is no unbounded "generate all" call. This replaces the legacy physical-expansion approach (assessment section 4.2).

## 5. Domain services (pure functions)
- `validateSchedule(ScheduleSpec) → Result`: rejects invalid combinations (end before start; `about` target min > max is a Task concern, not here).
- `OccurrenceWindowQuery(spec, rule?, exceptions, window) → List<Occurrence>`: deterministic; applies exceptions after generation; bounded.
- `resolveWallClock(ZonedWallClock) → Instant`: DST rule (gap → first valid minute; overlap → earliest).
- `OverlapQuery(List<TimedItem>) → List<Conflict>`: symmetric, deterministic; all-day/date-only items excluded by default (UC-08).
- `workload(occurrences, window) → Duration`: sum of durations in the window (used by planning views; AI workload is a later consumer).

## 6. Commands
None (stateless). Owners persist `ScheduleSpec`/`RecurrenceRule`/`OccurrenceException` through their own aggregate's commands (Task, Event). Those owners emit `RecurringSeriesChanged` / `OccurrenceExceptionAdded`.

## 7. Queries / read ports (published)
`OccurrenceWindowQuery`, `OverlapQuery`, `resolveWallClock`, `workload` — consumed by Task Management and Calendar and Events.

## 8. Domain events
None emitted by the kernel. Series/exception events are emitted by the owning aggregate (Task or Event).

## 9. Repository contract
None.

## 10. Reminder ownership (resolves OQ-B4)
[Decision] A `Reminder` is a capability of the **owning aggregate** (Task or Event), expressed as an offset-before or an absolute `Instant`, not a separate aggregate and not owned by the Time Kernel. The platform scheduling of a local notification is an infrastructure adapter behind a port (as in the legacy `ReminderScheduler`), invoked by the application layer after the owner's command succeeds. The Time Kernel only computes the trigger instant from the schedule and the reminder offset; it does not schedule anything.

## 11. Open questions
- OQ-PLAN-1: exact max-occurrences-per-window value and window default. Technical batch.
- OQ-PLAN-2: how a "move forward from here" rule edit splits a series (ADR-0007 A2). Proposal: end the old rule at the split date, start a new series; confirm in P02.

## 12. Self-check
- [x] Stateless: no aggregate, no repository, no events emitted here.
- [x] OQ-B4 resolved (reminder ownership).
- [x] DST and date-only rules cite ADR-0010.
