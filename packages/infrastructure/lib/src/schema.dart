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
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array of strings (opaque)
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
