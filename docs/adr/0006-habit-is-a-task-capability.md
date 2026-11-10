# ADR-0006: Habit is a Task capability, not a separate aggregate

- Status: Accepted (owner decision); amended 2026-11-10 (P03 D6, ADR-0036: a habit is its own flag)
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../architecture/bounded-contexts.md](../architecture/bounded-contexts.md) OQ-B2; [../assessment/legacy-component-matrix.md](../assessment/legacy-component-matrix.md) (legacy `habits`/`habit_occurrences` tables)

## Context
A Habit is a recurring commitment with a measurable target (for example "walk at least 5,000 steps/day"). The architecture batch raised two options for where it lives in the domain model.

## Options
1. **Habit as a Task capability**: a Task with a `RecurrenceRule` and a `MeasurableTarget` capability attached. No separate `Habit` aggregate or table.
2. **Habit as its own aggregate**, mirroring the legacy `habits` + `habit_occurrences` tables, with its own identity separate from Task.

## Decision
Option 1. A Habit is a Task that carries:
- a `RecurrenceRule` (from the Time Kernel), and
- a `MeasurableTarget` capability (target type, value(s), unit, aggregation policy).

Task Management owns the Target and the Completion Policy for that Task. Execution and Measurement owns the Measurement entries recorded against it and evaluates each period. There is no separate `Habit` table or aggregate root.

## Consequences
- Pro: one lifecycle (status, trash, archive, history) for both plain Tasks and Habits; no duplicated hierarchy, tagging, or list logic.
- Pro: matches principle P1 (task-centric, not everything is a Task, but a Habit genuinely is a kind of Task with extra capabilities).
- Con: Task Management's model carries more optional capabilities (schedule, recurrence, measurable target); the domain batch must keep these as composable value objects, not a type-code branch, consistent with AP-13 (right-sized abstractions).
- Con: a UI concept "Habit" is a filtered view of Tasks with a measurable target and recurrence, not a distinct screen model; this must be documented for the UI batch so navigation does not assume a separate entity.
- Legacy `HabitStatisticsService` logic is still reusable as a pure function over Execution and Measurement data (see component matrix), independent of this decision.

## Follow-ups
- Domain batch: define `MeasurableTarget` and `CompletionPolicy` as capability value objects on Task.
- UI batch: confirm the "Habits" view is a query (Tasks with recurrence + measurable target), not a new screen-level model.

## Amendment (2026-11-10, owner decision P03 D6; ADR-0036)
The core decision stands: a habit is still a **Task capability**, with no separate aggregate or table. What changes is **what makes a task a habit**.
- **A habit is a flag of its own** (`Task.isHabit`), set by the user. It is independent of the repeat and of a measurable target. A habit **usually repeats but does not have to be measured**.
  - "Drink warm water every morning" is a habit that repeats and is only tracked as done or missed.
  - "Walk at least 6000 steps a day" is a habit that repeats and is measured.
  - "Read 50 pages" is measured but not a habit.
- The "Habits" view selects `isHabit` tasks, not "recurrence + target".
- An unmeasured habit is tracked per occurrence: done when ticked, missed when its period ended unticked. A measured one is evaluated per period from its measurements. Both show a history, a completion rate and a streak.
- A habit without a repeat is allowed (the editor suggests "every day"); it has one period.
