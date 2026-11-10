# ADR-0031: Events, calendars and conflict detection

- Status: Accepted (P02 task T5, 2026-11-09; within the owner-accepted P02 plan, decisions D4, D6, D7)
- Date: 2026-11-09
- Deciders: Project owner (plan), implementation
- Related: [calendar-events.md](../domains/calendar-events.md), [ADR-0011](0011-command-gateway-single-mutation-path.md), [ADR-0028](0028-time-types-and-dst-resolution.md), [ADR-0029](0029-planning-storage-schema-v4.md), [ADR-0030](0030-task-scheduling-and-agenda.md)

## Decision
- **Two aggregates, two handlers** on the single mutation path: `EventCommandHandler` (create, update, cancel or un-cancel the whole event, trash, restore, change one occurrence, undo that change) and `CalendarCommandHandler` (create, update, trash). Both are covered by the FF-ARCH-06 atomic-set test.
- **An event is never a task (LF-INV-CAL-001, D6):** events have their own table and id space, and creating an event with the id of an existing task is refused. Tasks shown in the calendar stay tasks: the calendar range returns them as task agenda items.
- **Event schedule:** always a start; end optional; **no deadline**; all-day = dates without times. Same validation and row writing as tasks (`ScheduleRows`, shared): the payload is checked again, each written row gets a version and an outbox row.
- **Only this occurrence (D4):** skip (not shown), cancel (shown as cancelled), move (date and optional time, length kept), edit (title and/or location for that occurrence). The whole event can also be cancelled; then every occurrence shows as cancelled.
- **Trashing a calendar** keeps its events; they lose the calendar, each as a versioned change with an outbox row.
- **Calendar range query** (`CalendarQueries.watchRange`): event occurrences (with exceptions applied), the task agenda of the same range, and the **conflicts** between them. Re-runs when tasks, events, calendars, schedules, exceptions or completions change.
- **Conflicts (D7, FR-PLAN-11, UC-08):** only shown, never stored. Taking part: timed items with a start and an end. Never taking part: all-day and date-only items (LF-INV-CAL-002), cancelled events or occurrences, done tasks, overdue one-offs. Intervals are half-open (touching is no conflict). Computed by the kernel's `overlaps`, so the result is the same for the same data and independent of order (AC-08.1). Keys are `task:<id>@<date>` or `event:<id>@<date>`.

## Consequences
- Pro: events and tasks share one schedule engine, one validation and one storage path, with separate identities.
- Con: a done task stops conflicting immediately; a task finished early is not "busy" any more. Acceptable for MVP.
- Not in P02: attendees, invitations, shared calendars, external calendar sync (P04+).

## Verification
- `packages/infrastructure/test/events_calendar_test.dart` (10 tests): create, read back and update with outbox rows; invalid inputs returned with a message and nothing written; LF-INV-CAL-001 and no-deadline refusals on raw commands; skip, cancel, move (length kept), edit and undo one occurrence, and "not an occurrence" refused; cancel the whole event, trash, restore; a daily 09:00 event in Berlin stays 09:00 across DST (LF-INV-PLAN-013); calendars listed, renamed, trashed with their events kept and outbox rows; conflicts between an event and a task, with touching, all-day and done items excluded and the same result twice; cancelled occurrences and events never conflict; the range stream follows changes.
- `atomic_set_test.dart` (FF-ARCH-06): ten event and calendar operations with fault injection.
- Mutations: counting cancelled events in conflicts, removing the task-id check, and counting done tasks each fail tests.
