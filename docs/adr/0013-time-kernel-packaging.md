# ADR-0013: Time Kernel is a standalone pure-Dart package

- Status: Accepted
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Resolves: OQ-B1
- Evidence: [../architecture/bounded-contexts.md](../architecture/bounded-contexts.md) section 3.2; ADR-0010

## Context
Planning and Scheduling is a stateless set of time rules (schedule validation, recurrence, occurrence generation, DST resolution, overlap, workload). Task Management and Calendar and Events both depend on it. OQ-B1 asked whether it lives in its own package or inside `foundation`.

## Options
1. Inside `foundation` (shared kernel).
2. Standalone package `planning` (or `time_kernel`), pure Dart, no I/O, depending only on `foundation` and the `timezone` package.
3. Inside Task Management, exposed to others.

## Decision
Option 2. The Time Kernel is a standalone pure-Dart package. It depends only on `foundation` (IDs, `LocalDate`, `Instant`, `ZonedWallClock`, `TimeOfDayValue`, `Result`) and the `timezone` package. It has no database, no Flutter, no network.

`foundation` keeps only the primitive value types (so other contexts can reference a `LocalDate` without importing the Time Kernel). The Time Kernel keeps the *rules* (`ScheduleSpec` validation, `RecurrenceRule` expansion, `OccurrenceException` application, `OverlapQuery`, DST resolver, workload math).

## Consequences
- Pro: the rules can be versioned and unit-tested as a unit, portable to any Dart environment (AP-14).
- Pro: keeps `foundation` small (AP-13), so a change to recurrence logic does not ripple through every context that only needs a `LocalDate`.
- Con: one more package boundary; Task Management and Calendar depend on two packages (`foundation` + `time_kernel`) instead of one. Acceptable.
- Reinforces DR-7 (shared kernel limited to `foundation`).

## Follow-ups
- Repository-structure batch: list `time_kernel` in the package dependency table.
- Confirm the final package name (`time_kernel` vs `planning`) in the repository-structure batch.
