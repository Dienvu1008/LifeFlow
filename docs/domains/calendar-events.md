# Domain: Calendar and Events

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Classification: Core. Phase: P02. In MVP: yes.
- Related: [planning-scheduling.md](planning-scheduling.md), [task-management.md](task-management.md), [ADR-0007](../adr/0007-single-schedule-with-derived-occurrences.md), [ADR-0010](../adr/0010-time-model-date-only-vs-instant.md)

## 1. Purpose
Represent things that happen at a time (meeting, birthday, anniversary, timetable, appointment). An Event is a distinct concept from a Task (LF-INV-CAL-001); it is not a scheduled Task and does not share identity with one.

## 2. Aggregate roots and boundaries
- **`Event`** (root): one event, its `ScheduleSpec` (+ optional `RecurrenceRule`), its `OccurrenceException`s, and (P04) its attendees. Boundary: the event and its own recurrence exceptions.
- **`Calendar`** (root): a named collection used to group and color events and to overlay with tasks.

## 3. Entities and value objects
- `Event`: `eventId`, `workspaceId`, `ownerId`, `calendarId?`, `title`, `location?`, `scheduleSpec` (from Time Kernel; timed events use `ZonedWallClock`, all-day events use `LocalDate`), `recurrenceRule?`, `exceptions: List<OccurrenceException>`, `reminder?`, `version`, timestamps, tombstone.
- `Calendar`: `calendarId`, `name`, `color`.
- Attendee, invitation, attendance status: **P04** (not modeled here).

## 4. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-CAL-001 | An Event has its own identity, never shared with a Task | separate aggregate and ID space |
| LF-INV-PLAN-012 | No duplicate occurrences in a window (shared with Time Kernel) | occurrence query |
| LF-INV-PLAN-013 | Timed events keep wall-clock time across DST | `ZonedWallClock` + resolver |
| LF-INV-CAL-002 | An all-day event uses `LocalDate` and is excluded from timed conflict detection by default | `OverlapQuery` input mapping |

## 5. Domain services
- `ConflictDetection`: delegates to the Time Kernel `OverlapQuery` over the window's events plus (via `ScheduledItemReader`) scheduled task occurrences. Deterministic and AI-free (FR-PLAN-11).
- `EventOccurrences`: delegates to `OccurrenceWindowQuery`.

## 6. Commands
| Command | Actor | Args | Preconditions | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|---|
| `CreateEvent` | owner | title, scheduleSpec, calendarId?, recurrenceRule? | valid schedule | new Event v1 | `EventCreated` | by `operationId` | n/a |
| `UpdateEvent` | owner | eventId, changes | exists, not purged | updated | `EventUpdated` | by `operationId` | `expectedVersion` |
| `AddEventException` | owner | eventId, exception | recurring event | exception stored | `OccurrenceExceptionAdded` | by (eventId, originalDate) | `expectedVersion` |
| `CancelEvent` | owner | eventId | exists | status cancelled | `EventCancelled` | by `operationId` | `expectedVersion` |
| `TrashEvent` / `RestoreEvent` | owner | eventId | — | tombstone | `EventUpdated` | by `operationId` | `expectedVersion` |
| `CreateCalendar` / `UpdateCalendar` | owner | name, color | — | calendar | `EventUpdated`(n/a) | by `operationId` | `expectedVersion` |

## 7. Queries / read ports
- `EventsInWindow(window) → List<Occurrence>`.
- `Conflicts(window) → List<Conflict>` (events + scheduled tasks).

## 8. Domain events
`EventCreated`, `EventUpdated`, `EventCancelled`, `OccurrenceExceptionAdded`.

## 9. Repository contract
```
EventRepository:
  getById(EventId): Event?
  inWindow(window, calendarIds?): List<Event>
  save(Event): void            // via command handler
CalendarRepository:
  list(): List<Calendar>
  save(Calendar): void
```

## 10. Anti-corruption note
[Decision] The domain `Event` is **not** shaped after Google Calendar (contrast the legacy `CalendarEvent`, which mirrored Google fields like `etag`, `sequence`, `syncStatus`). External calendar integration (Google, Outlook) is P04+ and sits behind an anti-corruption layer that maps provider events to this domain model. The domain does not carry provider sync fields.

## 11. Open questions
- OQ-CAL-1: do scheduled Tasks appear in calendar views as read-only overlays only, or can a user edit a task's schedule from the calendar? Proposal: edit via the Task command, surfaced in the calendar UI. UI batch.

## 12. Self-check
- [x] Event is a distinct aggregate (LF-INV-CAL-001).
- [x] Recurrence reuses the Time Kernel; no second recurrence engine (contrast legacy two engines).
- [x] No provider sync fields in the domain model.
