# ADR-0037: Storage v5 for focus, execution, measurement, habits and goals

- Status: Accepted (P03 task T2, 2026-11-11; within the owner-accepted P03 plan, decisions D1–D12)
- Date: 2026-11-11
- Deciders: Project owner (plan), implementation
- Related: [ADR-0036](0036-execution-measurement-goal-rules.md) (the rules stored here), [ADR-0009](0009-identifier-and-versioning-strategy.md) (shared columns), [ADR-0025](0025-profile-export-and-restore.md) (export/restore), [execution-measurement.md](../domains/execution-measurement.md), [goals-projects.md](../domains/goals-projects.md), [p03-plan.md](../roadmap/p03-plan.md)

## Context
T1 added the P03 rules as pure domain code. T3–T5 need somewhere to keep focus sessions, records, measurements, period results and goals, and those rows must survive the export → restore round trip (GS-20) like every earlier kind. The commands that write them come in T3–T5; this task is storage only.

## Decision
**Schema v5** (`AppDatabase.currentSchemaVersion = 5`). Seven new tables, all with the shared syncable columns (ADR-0009). Their row classes are named `…Row` (`@DataClassName`) so they never clash with the domain types:

| Table | Holds | Id |
|---|---|---|
| `focus_sessions` | a session, written at start and on every transition (LF-INV-EXEC-003); `plannedMs`, `pausedMs`, `pausedAt` in UTC/ms | random |
| `execution_records` | what was actually done; optional session, task and occurrence | `session:<sessionId>` when from a session (LF-INV-EXEC-004) |
| `measurements` | one value with its date, source and device; a correction supersedes, a withdrawal flags; optional execution record | random |
| `period_results` | the stored outcome of an ended period or habit occurrence, with the aggregate and a JSON copy of the target (D9) | `task:<taskId>@<key>#<period\|occurrence>` |
| `goals` | a goal or a project (`kind`), status active/done/archived (D11) | random |
| `milestones` | a milestone of a goal, done by hand | random |
| `goal_links` | a goal → task or event link; never owns the item (LF-INV-GOAL-002) | `<goalId>\|<itemType>:<itemId>` |

`tasks` gains `targetAggregation` (default `sum`, D7) and `isHabit` (default false, D6, ADR-0006 amendment).

Indexes: `measurements (task_id, local_date)`, `focus_sessions (state)`, `execution_records (task_id)`, `period_results (task_id, period_key)`, `milestones (goal_id)`, `goal_links (goal_id)`, `goal_links (item_type, item_id)`. They are created on a new store and by the upgrade.

**Upgrade** from v1–v4 on open: add the two task columns, create the seven tables and their indexes. Existing rows are not touched.

**Export / restore** (one registry, `record_kinds.dart`):
- Seven new record kinds. A schema 1–4 file is read as having none of them, and its tasks get `sum` and `false`.
- References are declared once and used by both export validation and restore:
  - **Required** (`requiredRefsOf`): a measurement, period result or session-less row needs its task; a milestone needs its goal; a goal link needs both its goal and its item. A correction needs the measurement it supersedes (same task).
  - **Optional** (`optionalRefs`): an event's calendar, a session's task, a record's task and session, a measurement's record. They are cleared, not dropped, when the target will not exist. History is kept even if the task is gone.
- **Untrusted file** (SR-14): the restore is refused when a required or optional reference does not resolve inside the file. It is also refused when a P03 row is malformed (`executionRowsError`):
  - an unknown mode, state, source, kind, outcome, status or aggregation;
  - a negative or non-finite value; a negative pause or focus time;
  - a pomodoro without a planned interval; a record that ends before it starts;
  - a bad date;
  - a keyed id that does not match its parts.
- **Restore into a profile**: a row from the file is never written without the records it requires. Dropping is repeated until stable, since a dropped goal drops its links. Device rows are never dropped; overwrite trashes them with tombstones, as for every kind.

## Consequences
- T3–T5 write through command handlers using the id helpers in `execution_rows.dart`; the store already enforces one record per session by key.
- Period results are a stored snapshot, not recomputed. Editing a target later does not rewrite closed periods (D9).
- No foreign keys: references are checked in code, at export, restore and (later) command time. The same rule set serves all three.

## Verification
- `packages/infrastructure/test/execution_storage_test.dart` (27 tests):
  - a new store has the tables, defaults and indexes;
  - GS-20 clean-install round trip keeps every P03 row, the habit flag, the aggregation and superseded history;
  - a schema-4 file gets the defaults;
  - 18 SR-14 rejections;
  - same-profile restore: identical, merge (a) without the missing goal, a newer session cleared of a missing task, a correction not written without its original, overwrite tombstones.
- `profile_directory_test.dart`: upgrades from v1, v2, v3 and v4 reach v5 with all 11 indexes and the task defaults.
- Mutations: 20/20 killed. They cover the required drop, the correction drop, optional clearing, one optional entry, both upgrade defaults, the reference checks, the `executionRowsError` hook, the index creation on new and upgraded stores, the upgrade gate, and nine well-formedness rules.
