# ADR-0028: Where the time types live, and how a wall clock becomes an instant

- Status: Accepted (P02 task T1, 2026-11-07; owner accepted the P02 plan)
- Date: 2026-11-07
- Deciders: Project owner (plan), implementation
- Refines: [ADR-0010](0010-time-model-date-only-vs-instant.md) (time model), [ADR-0013](0013-time-kernel-packaging.md) (Time Kernel package)
- Related: [../roadmap/p02-plan.md](../roadmap/p02-plan.md) §3–4

## Context
ADR-0010 defines three kinds of time (date only, instant, zoned wall clock) and the DST rule. ADR-0010 places the types in "foundation / Time Kernel", ADR-0013 places the primitives in `foundation`, and the old `foundation` header placed `ZonedWallClock` in the kernel. P02 needs one answer before schedules and recurrence are built. The recurrence rules of the plan (month-end rule, week start) also need date arithmetic that `LocalDate` did not have.

## Decision
- **`foundation` holds plain time data, no zone database:** `LocalDate` (validated; epoch day, weekday, add days, add months exact or clamped, order), `TimeOfDayValue` (minute precision), `Weekday` (ISO, Monday = 1), `ZonedWallClock` (local date, time, IANA zone name), `Instant`, and `Clock` (`SystemClock`, `FixedClock` for tests). FF-ARCH-01 now also fails if `foundation` imports `timezone`.
- **`time_kernel` holds everything that needs the zone database:** zone lookup (`TimeZones`), `resolveWallClock` (the only place that turns a wall clock into an instant), `wallClockAt` and `dateAt` (instant to local time, "today" in a zone), and `ScheduleSpec` with `validateSchedule`. Recurrence, occurrences, overlap and workload follow in T2.
- **DST rule (ADR-0010) as implemented:** the offsets 36 hours before and after the wall clock are tried. One valid instant: normal. Two: overlap, the **earlier** instant is used. None: gap, the **transition instant** is used (the first valid time after the gap, for example 02:30 in Berlin on 29 March becomes 03:00 CEST). The kind (normal, gap, overlap) is reported, so the UI can say "this time does not exist on that day" later.
- **Date-only stays a date (LF-INV-PLAN-004):** a schedule point is a `DatePoint` or a `TimedPoint`; only `TimedPoint` has a path to an instant (`instantOf`). A timed point's date is its local date, never the UTC date.
- **ScheduleSpec:** optional `start`, `end` and `deadline` points; at least one is set. The six FR-PLAN-01 shapes are derived from the kinds of start and end; a deadline is separate (FR-PLAN-03). Start and end must be of the same kind; a timed end before its start is compared as instants, so different zones are allowed (for example a flight). An unknown zone is rejected.
- **Zone database:** `timezone` (BSD-2-Clause, LICENSE checked), **pinned exactly**: the database ships inside the package, so upgrading it changes DST data and is a deliberate, reviewed change. Pinned at 0.9.4 in T1, moved to **0.11.2** in T0 (2026-11-09) because the notification plugin needs `^0.11.0` (spike S-05); the GS-04 table and all kernel tests pass on the new data. Devices may report legacy aliases (Windows: `Asia/Saigon`); they resolve like their canonical zone (tested).

## Recurrence, window query and conflicts (P02 task T2)
- **Own engine** in `time_kernel` (no rrule library): daily, weekly (weekdays), monthly (day of month), yearly; every N (1–999); ends never, on a date (inclusive) or after N (1–10 000).
- **Dates are counted from the series start**, never from the queried window, so every split of a period into windows gives the same occurrences (GS-03). Periods are skipped arithmetically when there is no count, so an old series queried far ahead stays fast.
- **The month-end rule and the week start are part of the rule** (owner decisions D2/D3 with the refinement): `skip` (default) or `lastDay`; Monday (default) or Sunday.
- **"After N" counts the rule's dates.** Exceptions do not change the count, so skipping one occurrence never moves the later ones. Under `skip`, missing month-ends are not counted.
- **Exceptions** (skip, cancel, move to another date and optional time, edit with an opaque patch) are keyed by original date, applied after generation; the last one for a date wins; an exception on a date the rule no longer has is ignored. A moved occurrence appears where it was moved to and keeps its original date as identity; a timed move keeps the planned length.
- **Bounds (D1):** a query is cut at `maxWindowDays` (default 400) and `maxOccurrences` (default 1000) and reports `truncated` and `coveredTo`. Settings are clamped to hard bounds 31–1100 days and 100–5000 occurrences, so no setting can make a query unbounded (LF-INV-PLAN-010).
- **Conflicts (D7):** only timed items with a start and an end take part; all-day, date-only, open-ended and cancelled items never do (LF-INV-CAL-002). Intervals are half-open (09:00–10:00 and 10:00–11:00 do not conflict). Sweep line, result independent of input order (AC-08.1). `workload` sums planned time inside a range.

## Consequences
- Pro: one resolver, one rule, testable without a device; the UI and storage never compute offsets.
- Pro: `foundation` stays free of the zone database, so pure packages that only need dates do not load it.
- Con: the kernel loads the full zone database on first use (a few hundred KB). Acceptable.
- Con: future rule changes by governments need a new `timezone` release and an app update.

## Verification
- `packages/foundation/test/time_test.dart`: date validation, epoch day and weekday against Dart's calendar on 20 000 random dates, day and month arithmetic (exact and clamped, leap years), times, wall clocks.
- `packages/time_kernel/test/dst_test.dart` (GS-04, LF-INV-PLAN-013, AC-06.5): table over Europe/Berlin, America/New_York and Australia/Sydney (gap, overlap, edges, both seasons), Australia/Lord_Howe (30-minute DST), Asia/Ho_Chi_Minh and UTC; a daily 09:00 keeps its wall clock across the change in all three zones; a property test over 12 000 random instants (an instant shown as a wall clock resolves back to itself, or to its earlier twin in an overlap).
- `packages/time_kernel/test/schedule_test.dart`: the six shapes, deadline, rejections, duration across a DST change, LF-INV-PLAN-004.
- Mutations: taking the later instant in an overlap, or the old offset in a gap, fails 10 tests.
- T2, `packages/time_kernel/test/recurrence_test.dart`: GS-03 (Mon+Wed after 10: exactly the 10 dates; 500 random splits into windows give the same 10 with no duplicates or gaps; regenerating is identical); the engine equals an independent day-by-day reference on 1 500 random rules and windows (all frequencies, intervals, weekdays, ends, both month-end rules, both week starts); month-end and leap-day cases; week start example; exceptions (skip keeps the count, move in and out of a window, timed move keeps the length, LF-INV-PLAN-011, last one wins); bounds and clamping; LF-INV-PLAN-013 through a daily series.
- T2, `overlap_test.dart`: equals brute force on 400 random sets and is independent of input order; who takes part (CAL-002, D7); two series conflict only on the day both happen; workload.
- T2 mutations: no de-duplication by original date, ignoring the week start, and counting touching intervals as conflicts each fail tests.
