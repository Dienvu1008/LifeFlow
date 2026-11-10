# ADR-0030: Scheduling tasks, and the agenda (Today, Upcoming, ranges)

- Status: Accepted (P02 task T4, 2026-11-09; within the owner-accepted P02 plan, decisions D4, D5)
- Date: 2026-11-09
- Deciders: Project owner (plan), implementation
- Related: [ADR-0007](0007-single-schedule-with-derived-occurrences.md), [ADR-0011](0011-command-gateway-single-mutation-path.md), [ADR-0028](0028-time-types-and-dst-resolution.md), [ADR-0029](0029-planning-storage-schema-v4.md)

## Decision
- **Ports in `application`, with `foundation` types only** (`planning.dart`): `TaskScheduleInput` (start, end, deadline, repeat), `SchedulePointInput` (a date, optionally a time and an IANA zone), `RepeatInput` (frequency, interval, weekdays, end, month-end rule, week start), `OccurrenceChange` (skip or move), the `TaskScheduling` command port, the `AgendaQueries` read port and the `DeviceTime` port (clock and zone). The UI never sees the Time Kernel (FF-ARCH-04). Infrastructure maps both ways (`schedule_inputs.dart`).
- **Commands are task commands** on the single mutation path (ADR-0011): `SetTaskSchedule`, `ClearTaskSchedule`, `SkipOccurrence` / `MoveOccurrence` / `ClearOccurrenceChange` (D4: only this occurrence), `CompleteOccurrence` / `ReopenOccurrence` (D5). The task is the aggregate: its version moves on each of them (`expectedVersion` = the task's version). Every changed schedule, exception or completion row gets its own version and **an outbox row under the same operation** (LF-INV-VER-001, LF-INV-OUTBOX-001). Clearing writes a tombstone.
- **The handler checks the payload again** with the same validation as an imported file (ADR-0029): a command is untrusted input too (for example from a future AI proposal). Input errors from the UI are returned as `validationFailed` with a message, never thrown.
- **Occurrence rules:** a change or a completion is only accepted for a date that is an occurrence of the task's current rule; a date-only task cannot be moved to a time; a one-off task has no per-occurrence completion (its normal completion applies).
- **Agenda queries** compute occurrences on demand (FR-PLAN-09): candidate series are selected by their stored date range, plus series with an occurrence **moved into** the window, then expanded by the kernel with the query limits (D1). The result reports `truncated`.
  - **Today** = the date in the device's zone (`DeviceTime`): today's occurrences, and **one-off** tasks planned or due before today that are still open, listed first and marked overdue. Missed occurrences of repeating tasks are not shown as overdue (history rules come with P03).
  - **Upcoming** = the next 14 days after today. **Range** = any window, for the calendar.
  - Items are ordered: overdue first, then by date, untimed before timed, then by time and title. A trashed task's schedule is not shown. A done one-off task, or a done occurrence, is shown as done.
  - The streams re-run when tasks, schedules, exceptions or completions change. A new day starts when the app recomputes (resume or a change); a timer at midnight is left to the UI (T6).

## Consequences
- Pro: everything about a task's schedule goes through one handler with the governance set; sync later sees each row change.
- Pro: the UI can be built against plain data ports and a fake.
- Con: per-occurrence history beyond "done" (missed, partial) waits for P03.

## Verification
- `packages/infrastructure/test/task_scheduling_test.dart` (16 tests): set, read back, clear and set again; task version and outbox rows; invalid inputs returned with a message and nothing written; a tampered command payload refused and rolled back; AC-06.1/06.2/06.3/06.4 on the real store; skip, move (also beyond the series end) and undo; refusals (not an occurrence, no repeat, nothing to remove, date-only to a time); per-occurrence done and open again with a tombstone; one-off done through the task; Today in the device zone (the date changes with the zone), overdue one-offs first, done ones not overdue, Upcoming excludes today, ordering; a trashed task leaves the stream; truncation reported.
- `atomic_set_test.dart` (FF-ARCH-06) covers the five schedule operations with fault injection.
- Mutations: ignoring moved occurrences in the query, skipping the payload re-check, and skipping the occurrence-date check each fail tests.
