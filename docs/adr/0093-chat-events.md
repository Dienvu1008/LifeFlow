# ADR-0093: The chat creates and moves events
- Status: Accepted (P06b W4b, 2026-11-04; the owner asked for it after W4)
- Date: 2026-11-04
- Deciders: the owner ([p06b-plan.md](../roadmap/p06b-plan.md) W4b); implementation
- Related: [ADR-0091](0091-free-chat.md) (the free chat), [ADR-0082](0082-ai-history-and-approved-changes.md) (approved changes, the tool catalog), [ADR-0031](0031-events-calendars-conflicts.md) (events and their occurrences)
## Context
ADR-0091 let the chat propose tasks only. The owner wants it to create events and move them too.
## Decision
1. **Three tools** join the catalog. Each runs the handler the Calendar's own screens use, with exactly the arguments that were approved:
   - `CreateEvent`: a new event with a title and a one-off slot on one day. Nothing else (no repeat, no deadline, no place, no calendar).
   - `MoveEvent`: a one-off event of the personal space gets another one-off slot. The command is an update, which replaces the title, place and calendar, so the proposal names the current ones again; if any of them changed since, the version has changed and the change is stale.
   - `MoveEventOccurrence`: one day of a repeating event goes to another day and time (the Calendar's "this event only"). The whole series is never moved. Only a day the event was shown on in the chat's data can be named.
2. **What the model writes:** the actions `createEvent` and `moveEvent`, with `eventId`, `fromDate` (the occurrence of a repeating event), `date`, `start`, `minutes`. The code builds the commands. A one-off event keeps its length unless the model gives another; a new event is an hour unless said.
3. **What the model sees:** the events of the next 7 days, each day it is on as one line ("on <date> at <start>-<end>", and "repeats; this one is of <date>"). An event says "changeable" when it is in the personal space and has a time. Day-long events are read, not moved.
4. **What is dropped:** an event not sent, not changeable (a shared space's, day-long), a task's id given as an event, an invented id, a day the event was not shown on, a bad date or time, a slot past midnight, a title that is empty or over 120 characters, and a second change to an event already changed in the same proposal.
5. **Approval:** as every change (D8): each or all, stale when the event changed (LF-INV-AI-002), the audit row says it came from the assistant (LF-INV-AI-003).
## Consequences
- The chat can plan a task and an event in the same answer.
- A move that changes an event's zone: the new slot is in the device's zone. An event made in another zone is now in this one.
- Cancelling or deleting an event, changing its place, calendar or reminders, and creating repeating events stay for the person to do on the Calendar.
