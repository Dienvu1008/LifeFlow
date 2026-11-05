# ADR-0007: One schedule per Task/Event, occurrences derived and exceptions recorded

- Status: Accepted (owner decision)
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../product/product-scope.md](../product/product-scope.md) OQ-S3; [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 4.2 (legacy physical-expansion recurrence)

## Context
A Task or Event needs a time plan. The brief allows for "multiple schedules if justified by domain semantics." The legacy app expands a repeat rule into independent physical rows, one per occurrence, with no link back to a master after creation (see assessment section 4.2). That conflicts with the product requirement that occurrences are not stored physically (FR-PLAN-09).

## Options
1. **Single schedule per Task/Event** (one `ScheduleSpec` plus at most one `RecurrenceRule`); occurrences are derived on demand for a requested window; per-occurrence changes are stored as `OccurrenceException` records (skip, move, edit, cancel), keyed by the original occurrence date.
2. **Multiple independent schedules per Task/Event**, each with its own optional recurrence (for example one Task with both a Monday evening slot and a separate Thursday morning slot as two unrelated schedules).
3. Legacy-style physical expansion: one independent row per occurrence.

## Decision
Option 1. A Task or Event has exactly one `ScheduleSpec` and at most one `RecurrenceRule`. Occurrences are computed by the Time Kernel for a requested window (never stored in bulk) and combined with any `OccurrenceException` rows for that series.

If a user wants what looks like "two schedules" (Monday evenings and Thursday mornings for the same commitment), the MVP models that as **two separate Tasks** (or two separate Events) that may share a tag, list, or a future "linked items" reference, not as one Task with two schedules. [Proposal; revisit if real use cases show this is awkward]

## Consequences
- Pro: matches FR-PLAN-06 to FR-PLAN-09 directly; no physical occurrence rows; exceptions survive rule edits (AC-06.4).
- Pro: simpler conflict detection and workload computation (one schedule to reason about per Task/Event).
- Con: a genuinely multi-slot recurring commitment needs two Tasks, which may feel indirect to some users. Mitigated by keeping Task creation cheap and allowing a shared tag or a future "series" grouping concept if this becomes a real complaint.
- This decision does not block Goals/Projects (ADR scope, P03): a Goal/Project can still link multiple Tasks, each with its own single schedule.

## Follow-ups
- Domain batch: define `ScheduleSpec`, `RecurrenceRule`, `OccurrenceException` and the window-query contract on the Time Kernel.
- Revisit if user testing shows the two-Task workaround is a frequent pain point.
