# ADR-0029: Storage of schedules, exceptions, events and calendars (schema v4)

- Status: Accepted (P02 task T3, 2026-11-09; within the owner-accepted P02 plan §4)
- Date: 2026-11-09
- Deciders: Project owner (plan), implementation
- Related: [ADR-0007](0007-single-schedule-with-derived-occurrences.md), [ADR-0009](0009-identifier-and-versioning-strategy.md), [ADR-0010](0010-time-model-date-only-vs-instant.md), [ADR-0015](0015-per-type-conflict-resolution.md), [ADR-0025](0025-profile-export-and-restore.md), [ADR-0028](0028-time-types-and-dst-resolution.md)

## Context
P02 needs to persist what the Time Kernel computes from: one schedule (and optional repeat) per task or event, exceptions per occurrence, per-occurrence completions of repeating tasks (owner decision D5), events, calendars and reminders. P01's export, validation and restore (compare, merge, overwrite, undo) were written for task lists and tasks only.

## Decision
- **Schema v4**, additive migration from v1, v2 and v3: tables `calendars`, `events`, `schedules`, `occurrence_exceptions`, `occurrence_completions`, `reminders`, all with the shared syncable columns (ADR-0009), plus four indexes (schedule date range, exceptions and reminders by subject, completions by task).
- **Dates as text, never instants (LF-INV-PLAN-004):** dates are `YYYY-MM-DD`, times `HH:MM`, and a timed point stores its IANA zone. Nothing date-only is ever stored as a timestamp.
- **Schedules:** one row per subject, id `<task|event>:<subjectId>` (ADR-0007: at most one), with planned start, planned end and deadline points, the repeat rule (frequency, interval, weekdays, end, **month-end rule, week start**, D2/D3), and a cached **first date / last possible date** (null = open-ended) for range pre-filtering. Whole-value replace, as ADR-0015 plans for schedules. Clearing a schedule writes a tombstone.
- **Exceptions:** one row per (subject, original date), id `<subject>@<date>`, kind skip, cancel, move (date and optional time) or edit (an owner-defined JSON patch). Keyed rows, as ADR-0015 plans ("keyed union").
- **Occurrence completions:** id `task:<taskId>@<date>`; reopening writes a tombstone.
- **Events** have their own id space and are never tasks (LF-INV-CAL-001); status confirmed or cancelled.
- **Reminders:** minutes before the start, or an absolute instant, per task or event.
- **Occurrences are never stored** (FR-PLAN-09, AC-06.3).
- **Mapping** (`schedule_mapping.dart`) converts rows to and from the Time Kernel types and **validates on read**: a malformed row (time without zone, unknown zone, bad date, bad rule, id not matching its subject, stale date range, end before start) is rejected as a whole.
- **One registry of record tables** (`record_kinds.dart`). Export, file validation, compare/merge/overwrite/undo and the clean-install restore all iterate it, so the new tables got the full P01 restore behaviour (tombstones on overwrite, outbox row per changed record, undo) without a second mechanism. A guard test fails if a table is neither in the registry nor deliberately excluded.
- **File validation (SR-14)** adds: every schedule, exception, completion and reminder points to an existing task or event; every exception belongs to an item with a schedule; every event's calendar exists; schedules and exceptions pass the mapping checks above. Files from schema v3 or older restore (empty planning tables).
- **Restore consistency:** after compare and merge, a dependent row from the file (schedule, exception, completion, reminder) is not written if its task or event will not exist, and an event whose calendar will not exist keeps no calendar. Device rows are never dropped by this rule.

## Consequences
- Pro: the schema mirrors the kernel types one to one; storage never computes offsets or occurrences.
- Pro: every later record table only needs a registry entry to be exported, validated and restored.
- Con: a moved occurrence can fall outside its series' stored date range; window queries must also look at move exceptions (T4).
- Con: the schema version is now read from `AppDatabase.currentSchemaVersion`; tests use it instead of fixed numbers.

## Verification
- `packages/infrastructure/test/planning_storage_test.dart` (17 tests): every schedule shape crossed with every rule option round-trips exactly; stored date ranges (including "after N" under month-end skip and open-ended series); LF-INV-PLAN-004 at the SQL level; all four exception kinds round-trip; ten kinds of malformed rows are rejected; GS-20 round trip into a clean install keeps every planning row; six kinds of untrusted planning rows in a file are rejected; a schema-3 file restores; restore into the same profile: identical, merge (b) adds an event with its schedule, exception and reminder and writes an outbox row for each; merge (a) never leaves a dangling calendar; overwrite tombstones a device-only event and undo brings it back.
- `profile_directory_test.dart`: v1, v2 and v3 stores upgrade to v4 with data intact and the indexes present.
- `profile_export_test.dart`: the table guard covers the new tables.
- Mutations: skipping the v4 migration fails 3 tests; dropping the dangling-item check fails 2; disabling the orphan rule fails the calendar test.
