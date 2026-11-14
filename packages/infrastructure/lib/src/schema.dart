// P01 local schema (ADR-0009 shared columns; ADR-0011/0014 governance tables).
// Domain-agnostic persistence shapes; the domain layer never imports this.
import 'package:drift/drift.dart';

/// Shared columns on every syncable, context-owned entity (ADR-0009):
/// stable id, tenancy/ownership, optimistic-concurrency version, timestamps,
/// and tombstone fields. Mixed into each entity table.
mixin SyncableColumns on Table {
  TextColumn get id => text()(); // UUID v7
  TextColumn get workspaceId => text()();
  TextColumn get ownerId => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()(); // tombstone
  TextColumn get deletedBy => text().nullable()();
}

class Profiles extends Table {
  TextColumn get id => text()(); // profileId (UUID v7)
  TextColumn get displayName => text().withDefault(const Constant(''))();
  TextColumn get activeWorkspaceId => text()();
  TextColumn get accountId => text().nullable()(); // bound account, if any
  TextColumn get accountProvider => text().nullable()();
  // Optimistic-concurrency version for BindAccount (workspace-and-access.md §6).
  IntColumn get version => integer().withDefault(const Constant(1))();
  // True for the single active profile on the device (SwitchProfile toggles it).
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  // ADR-0024: the user signed out. The binding is kept; the profile is locked
  // until the same account signs in again. Schema v2.
  BoolColumn get signedOut => boolean().withDefault(const Constant(false))();
  // P03 UX U6 (schema v8, ADR-0050, owner decision U-D13): the stored result
  // of a measured task completed by hand: 'target' (its target's judgement)
  // or 'tick' (done or missed, as ticked). Profile data: exported, synced.
  TextColumn get manualResults => text().withDefault(const Constant('target'))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Workspaces extends Table {
  TextColumn get id => text()(); // workspaceId (UUID v7)
  TextColumn get kind => text().withDefault(const Constant('personal'))();
  TextColumn get ownerId => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class TaskLists extends Table with SyncableColumns {
  TextColumn get title => text()();
  // P03 UX U2 (schema v7, ADR-0046): a palette colour (0..11, null = none)
  // and the fractional order key within the item's container.
  IntColumn get colorIndex => integer().nullable()();
  TextColumn get orderKey => text().withDefault(const Constant('a0'))();
  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table with SyncableColumns {
  TextColumn get title => text()();
  TextColumn get status =>
      text().withDefault(const Constant('inbox'))(); // inbox/todo/inProgress/done/cancelled
  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();
  TextColumn get taskListId => text().nullable()();
  TextColumn get parentTaskId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  // Measurable-target capability (nullable = not a measurable task).
  TextColumn get targetType => text().nullable()(); // atLeast/atMost/about
  RealColumn get targetMin => real().nullable()();
  RealColumn get targetMax => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get completionPolicy =>
      text().withDefault(const Constant('manual'))();
  // P03 (schema v5): how a period's measurements are combined (D7), and
  // the habit flag (D6, ADR-0006 amendment).
  TextColumn get targetAggregation => text().withDefault(const Constant('sum'))();
  BoolColumn get isHabit => boolean().withDefault(const Constant(false))();
  // P03 T4 (schema v6, ADR-0039): the day tracking began (it became a habit
  // or got a target). Periods that ended before it get no result.
  TextColumn get trackedSince => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array of strings (opaque)
  // Dogfooding F3 (schema v9, ADR-0051): free notes of the task (null = none).
  TextColumn get notes => text().nullable()();
  // P03 UX U2 (schema v7, ADR-0046): a palette colour (0..11, null = none)
  // and the fractional order key within the item's container.
  IntColumn get colorIndex => integer().nullable()();
  TextColumn get orderKey => text().withDefault(const Constant('a0'))();
  @override
  Set<Column> get primaryKey => {id};
}

/// Governance tables (ADR-0011/0014). Written in the same transaction as the
/// aggregate change by the command gateway (T2).

class AuditLog extends Table {
  TextColumn get auditId => text()();
  TextColumn get operationId => text()();
  TextColumn get actor => text()();
  TextColumn get onBehalfOf => text().nullable()();
  TextColumn get action => text()();
  TextColumn get resourceType => text()();
  TextColumn get resourceId => text()();
  IntColumn get versionBefore => integer().nullable()();
  IntColumn get versionAfter => integer().nullable()();
  TextColumn get outcome => text()(); // applied/deniedByPolicy/...
  TextColumn get reason => text().nullable()();
  DateTimeColumn get at => dateTime()();
  @override
  Set<Column> get primaryKey => {auditId};
}

class Outbox extends Table {
  TextColumn get operationId => text()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  TextColumn get workspaceId => text()();
  TextColumn get actorId => text()();
  TextColumn get operationType => text()(); // create/update/delete
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get payload => text()(); // JSON change set or tombstone
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  @override
  Set<Column> get primaryKey => {operationId, entityId};
}

class EventLog extends Table {
  TextColumn get eventId => text()();
  TextColumn get operationId => text()();
  TextColumn get eventType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get dispatched => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {eventId};
}

class OpDedupe extends Table {
  TextColumn get operationId => text()();
  TextColumn get workspaceId => text()();
  TextColumn get resultSummary => text()();
  DateTimeColumn get appliedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {operationId};
}

/// ADR-0025 (T7b): the state of the profile just before the last restore into
/// it, so that restore can be undone. It is an export document kept INSIDE
/// the profile's own encrypted store (never a plain file). At most one row;
/// written in the same transaction as the restore. Not part of an export.
/// Schema v3.
class RestoreSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get operationId => text()(); // the restore it can undo
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get exportText => text()();
  @override
  Set<Column> get primaryKey => {id};
}

// --- P02 T3 (schema v4): planning and calendar ---------------------------------
// Dates are stored as ISO text (`YYYY-MM-DD`) and times as `HH:MM`, never as
// instants, so a date-only value cannot drift with a time zone
// (LF-INV-PLAN-004). Timed points store the wall clock and the IANA zone; the
// UTC instants are only a cache for range queries (ADR-0010, ADR-0028).
// Occurrences are never stored (FR-PLAN-09).

/// A named collection of events (calendar-events.md).
class Calendars extends Table with SyncableColumns {
  TextColumn get name => text()();
  IntColumn get color => integer().withDefault(const Constant(0xFF009688))();
  @override
  Set<Column> get primaryKey => {id};
}

/// An event: its own aggregate and id space, never a task (LF-INV-CAL-001).
/// Its schedule lives in [Schedules] with subject_type = 'event'.
class Events extends Table with SyncableColumns {
  TextColumn get title => text()();
  TextColumn get location => text().nullable()();
  TextColumn get calendarId => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('confirmed'))(); // confirmed | cancelled
  // P03 UX U2 (schema v7, ADR-0046): the list it is in (never a task,
  // U-D1), its colour and its order key.
  TextColumn get listId => text().nullable()();
  IntColumn get colorIndex => integer().nullable()();
  TextColumn get orderKey => text().withDefault(const Constant('a0'))();
  @override
  Set<Column> get primaryKey => {id};
}

/// The one schedule (and optional repeat rule) of a task or an event
/// (ADR-0007). id = '<subjectType>:<subjectId>'. Clearing a schedule writes a
/// tombstone (deletedAt), never a hard delete (SYNC-004).
class Schedules extends Table with SyncableColumns {
  TextColumn get subjectType => text()(); // task | event
  TextColumn get subjectId => text()();
  // Planned start, planned end, deadline: date, optional time + zone.
  TextColumn get startDate => text().nullable()();
  TextColumn get startTime => text().nullable()();
  TextColumn get startZone => text().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get endTime => text().nullable()();
  TextColumn get endZone => text().nullable()();
  TextColumn get deadlineDate => text().nullable()();
  TextColumn get deadlineTime => text().nullable()();
  TextColumn get deadlineZone => text().nullable()();
  // Cache for range queries: first date of the series, and its last possible
  // date (null = open-ended). Derived from the fields above on every write.
  TextColumn get firstDate => text()();
  TextColumn get lastDate => text().nullable()();
  // Repeat rule (all null = no repeat).
  TextColumn get frequency => text().nullable()(); // daily|weekly|monthly|yearly
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get weekdays => text().nullable()(); // ISO numbers, e.g. "1,3"
  TextColumn get endKind => text().nullable()(); // never|onDate|afterCount
  TextColumn get endDateRule => text().nullable()();
  IntColumn get endCount => integer().nullable()();
  TextColumn get monthEndRule => text().withDefault(const Constant('skip'))();
  IntColumn get weekStart => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
}

/// A change to one occurrence, keyed by its original date (FR-PLAN-08,
/// LF-INV-PLAN-011). id = '<subjectType>:<subjectId>@<originalDate>'.
class OccurrenceExceptions extends Table with SyncableColumns {
  TextColumn get subjectType => text()();
  TextColumn get subjectId => text()();
  TextColumn get originalDate => text()();
  TextColumn get kind => text()(); // skip | cancel | move | edit
  TextColumn get moveDate => text().nullable()();
  TextColumn get moveTime => text().nullable()();
  TextColumn get patch => text().nullable()(); // JSON, owner-defined
  @override
  Set<Column> get primaryKey => {id};
}

/// One occurrence of a repeating task marked done (owner decision D5).
/// id = 'task:<taskId>@<originalDate>'. Reopening writes a tombstone.
class OccurrenceCompletions extends Table with SyncableColumns {
  TextColumn get taskId => text()();
  TextColumn get originalDate => text()();
  DateTimeColumn get completedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A reminder of a task or an event: minutes before its start, or an
/// absolute instant (planning-scheduling.md §10). Scheduling on the device is
/// done by an adapter (P02 T7).
class Reminders extends Table with SyncableColumns {
  TextColumn get subjectType => text()(); // task | event
  TextColumn get subjectId => text()();
  IntColumn get offsetMinutes => integer().nullable()();
  DateTimeColumn get atUtc => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

// --- P03 (schema v5, ADR-0037): execution, measurement, habits, goals --------

/// A focus session (execution-measurement.md §3, ADR-0036). Written at start
/// and on every transition, so a kill at any point leaves a recoverable row
/// (LF-INV-EXEC-003). The instants are UTC milliseconds, not DateTime
/// columns (kept to the second): the elapsed time is derived from them and
/// must stay within 1 s after any number of pauses (LF-INV-EXEC-002, ADR-0038).
/// Durations are in milliseconds.
@DataClassName('FocusSessionRow')
class FocusSessions extends Table with SyncableColumns {
  TextColumn get taskId => text().nullable()();
  TextColumn get occurrenceDate => text().nullable()(); // original date of a repeating task
  TextColumn get mode => text()(); // pomodoro | stopwatch
  TextColumn get state => text()(); // running | paused | ended | cancelled | unrecoverable
  IntColumn get startedAt => integer()(); // UTC ms
  IntColumn get plannedMs => integer().nullable()();
  IntColumn get pausedMs => integer().withDefault(const Constant(0))();
  IntColumn get pausedAt => integer().nullable()(); // UTC ms
  IntColumn get endedAt => integer().nullable()(); // UTC ms
  @override
  Set<Column> get primaryKey => {id};
}

/// What was actually done (FR-EXEC-01). id = 'session:<sessionId>' when it
/// comes from a focus session, so a session has at most one record
/// (LF-INV-EXEC-004).
@DataClassName('ExecutionRecordRow')
class ExecutionRecords extends Table with SyncableColumns {
  TextColumn get sessionId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get occurrenceDate => text().nullable()();
  DateTimeColumn get actualStart => dateTime()();
  DateTimeColumn get actualEnd => dateTime()();
  IntColumn get focusMs => integer()();
  TextColumn get note => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// One observed value for a measurable task (FR-HAB-02/03). Never
/// overwritten: a correction is a new row that supersedes the old one
/// (LF-INV-EXEC-001); provenance is required (LF-INV-HEALTH-004).
@DataClassName('MeasurementRow')
class Measurements extends Table with SyncableColumns {
  TextColumn get taskId => text()();
  RealColumn get value => real()();
  TextColumn get localDate => text()(); // the day it counts for (D10)
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get source => text()(); // manual | focusSession | import
  TextColumn get deviceId => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get supersedesId => text().nullable()();
  BoolColumn get withdrawn => boolean().withDefault(const Constant(false))();
  TextColumn get recordId => text().nullable()(); // optional execution record
  @override
  Set<Column> get primaryKey => {id};
}

/// The stored result of an ended period (D9) or habit occurrence (D6c).
/// id = 'task:<taskId>@<key>#<kind>', key = the period's first day (or
/// 'once' for a one-off task) or the occurrence's original date. Written
/// once per period; a later change is a new version, recorded.
@DataClassName('PeriodResultRow')
class PeriodResults extends Table with SyncableColumns {
  TextColumn get taskId => text()();
  TextColumn get periodKey => text()();
  TextColumn get kind => text()(); // period | occurrence
  TextColumn get outcome => text()(); // done | missed | achieved | notAchieved | noData
  RealColumn get value => real().nullable()(); // the aggregate, when measured
  TextColumn get target => text().nullable()(); // JSON copy of the target used
  DateTimeColumn get evaluatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A goal or a project (goals-projects.md, D11).
@DataClassName('GoalRow')
class Goals extends Table with SyncableColumns {
  TextColumn get kind => text()(); // goal | project
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active | done | archived
  TextColumn get startDate => text().nullable()();
  TextColumn get targetDate => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A milestone of a goal or project, completed by hand (D11, OQ-GOAL-1).
@DataClassName('MilestoneRow')
class Milestones extends Table with SyncableColumns {
  TextColumn get goalId => text()();
  TextColumn get title => text()();
  TextColumn get dueDate => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

/// A link from a goal or project to a task (habits are tasks) or an event.
/// id = '<goalId>|<itemType>:<itemId>'; unlinking writes a tombstone. A link
/// never owns the item (LF-INV-GOAL-002).
@DataClassName('GoalLinkRow')
class GoalLinks extends Table with SyncableColumns {
  TextColumn get goalId => text()();
  TextColumn get itemType => text()(); // task | event
  TextColumn get itemId => text()();
  @override
  Set<Column> get primaryKey => {id};
}
