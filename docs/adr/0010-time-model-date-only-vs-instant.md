# ADR-0010: Time model separates date-only, instant and zoned wall-clock

- Status: Accepted
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Resolves: OQ-R2
- Evidence: [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 4.3 (legacy `wall_clock_resolver`, `HabitDay` date-only, vestigial `timeZone`); [../research/verified-sources.md](../research/verified-sources.md) VS-20 (timezone package)

## Context
The MVP needs: date-only tasks ("read 20 pages today"), timed events ("meeting 14:00–15:00"), recurring wall-clock events that must survive DST, and habit days keyed to a local calendar date. The legacy app conflated these (a `DateTime` with a volatile `isToday` flag computed in the constructor; a mostly unused `timeZone` string), and stored timestamps as local-time ISO strings without offset, which is unsafe for sync.

## Options
1. One `DateTime` type everywhere (legacy).
2. Three explicit types: `LocalDate` (floating calendar date), `Instant` (UTC point in time), and `ZonedWallClock` (wall-clock time + IANA zone, resolved to an `Instant` on demand).
3. Store everything as UTC `Instant` and derive dates by the device zone at read time.

## Decision
Option 2. Define three value types in `foundation` / Time Kernel:
- **`LocalDate`**: year-month-day, no time, no zone. Used for date-only schedules, habit days, and the "which day does this measurement belong to" key. Comparisons are calendar-based (never via `Duration`). Changing the device timezone never moves a `LocalDate` value (AC-03.3).
- **`Instant`**: a UTC point in time. Used for `createdAt`/`updatedAt`, audit timestamps, focus session start, and any precise event in the past.
- **`ZonedWallClock`**: a wall-clock date-time plus an IANA zone name (for example `2026-03-29 02:30 @ Europe/Berlin`). Used for timed Events and recurring timed Tasks so they keep their local time across DST. Resolution to an `Instant` uses the documented DST rule (below) via the `timezone` package.

**DST resolution rule (Decision, adopting legacy `wall_clock_resolver` behavior):**
- Spring-forward gap (the wall-clock time does not exist): resolve to the first valid minute after the gap.
- Fall-back overlap (the wall-clock time exists twice): resolve to the earliest instant.

The `timezone` package is initialized with `initializeTimeZones()` and runs under plain Dart (verified VS-20); the device's current zone is obtained from a platform plugin (`flutter_timezone`) at the edge, not inside the domain.

## Consequences
- Pro: date-only and timed semantics cannot be accidentally mixed; type system enforces FR-PLAN-02.
- Pro: DST is handled in one place and is testable with plain Dart (AC-06.5).
- Con: conversions between types must be explicit; the domain batch defines the allowed conversions (for example `LocalDate` + `TimeOfDayValue` + zone → `ZonedWallClock` → `Instant`).
- Con: storage must persist the zone name for `ZonedWallClock`, not just an instant, so a later zone-database update recomputes correctly.

## Follow-ups
- Time Kernel package (ADR-0013) owns these types and the resolver.
- Data batch: storage representation (store `ZonedWallClock` as wall-clock fields + zone name, plus a cached `Instant` for querying).
