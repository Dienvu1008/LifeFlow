// The user-owned record tables of a profile store, in one registry
// (P02 T3, ADR-0029). Export, validation, restore compare/merge/undo and the
// clean-install restore all go through this list, so a new record table is
// handled everywhere by adding it here (and a guard test fails if a table of
// the schema is neither here nor deliberately excluded).
//
// Every record table uses the shared syncable columns (ADR-0009): text id,
// workspaceId, ownerId, version, createdAt, updatedAt, deletedAt (tombstone).
import 'package:drift/drift.dart';

import 'app_database.dart';

typedef Row = Map<String, dynamic>;

/// One record table: how to read it as JSON rows and write rows back.
class RecordKind {
  const RecordKind._(this.name, this.exportKey, this._read, this._write, this._insert);

  /// Kind name used in plans and outbox rows ('task', 'schedule', ...).
  final String name;

  /// Key of the table in an export payload (the Drift table getter name).
  final String exportKey;

  final Future<List<Row>> Function(AppDatabase db) _read;

  /// Upsert (fires update triggers; nulls are written, not skipped).
  final void Function(Batch b, AppDatabase db, List<Row> rows) _write;

  /// Plain insert into an empty store.
  final void Function(Batch b, AppDatabase db, List<Row> rows) _insert;

  Future<List<Row>> readAll(AppDatabase db) => _read(db);
  void upsert(Batch b, AppDatabase db, List<Row> rows) {
    if (rows.isNotEmpty) _write(b, db, rows);
  }

  void insertAll(Batch b, AppDatabase db, List<Row> rows) {
    if (rows.isNotEmpty) _insert(b, db, rows);
  }

  /// Parses every row with the table's own JSON reader; throws on bad rows.
  void checkRows(List<Row> rows) {
    for (final r in rows) {
      _parse(r);
    }
  }

  static final Map<String, Object Function(Row)> _parsers = {
    'taskList': TaskList.fromJson,
    'task': Task.fromJson,
    'calendar': Calendar.fromJson,
    'event': Event.fromJson,
    'schedule': Schedule.fromJson,
    'exception': OccurrenceException.fromJson,
    'completion': OccurrenceCompletion.fromJson,
    'reminder': Reminder.fromJson,
    'focusSession': FocusSessionRow.fromJson,
    'executionRecord': ExecutionRecordRow.fromJson,
    'measurement': MeasurementRow.fromJson,
    'periodResult': PeriodResultRow.fromJson,
    'goal': GoalRow.fromJson,
    'milestone': MilestoneRow.fromJson,
    'goalLink': GoalLinkRow.fromJson,
  };
  Object _parse(Row r) => _parsers[name]!(r);
}

RecordKind _kind<T extends Table, D extends Insertable<D>>(
  String name,
  String exportKey,
  TableInfo<T, D> Function(AppDatabase) table,
  D Function(Row) fromJson,
  Insertable<D> Function(D) companion,
) =>
    RecordKind._(
      name,
      exportKey,
      (db) async => [
            for (final r in await db.select(table(db)).get()) (r as DataClass).toJson()
          ],
      (b, db, rows) => b.insertAllOnConflictUpdate(
          table(db), [for (final r in rows) companion(fromJson(r))]),
      (b, db, rows) => b.insertAll(table(db), [for (final r in rows) fromJson(r)]),
    );

/// In write order: a row is written after the rows it points to.
final List<RecordKind> recordKinds = [
  _kind('taskList', 'taskLists', (db) => db.taskLists, TaskList.fromJson,
      (d) => d.toCompanion(false)),
  _kind('task', 'tasks', (db) => db.tasks, Task.fromJson, (d) => d.toCompanion(false)),
  _kind('calendar', 'calendars', (db) => db.calendars, Calendar.fromJson,
      (d) => d.toCompanion(false)),
  _kind('event', 'events', (db) => db.events, Event.fromJson, (d) => d.toCompanion(false)),
  _kind('schedule', 'schedules', (db) => db.schedules, Schedule.fromJson,
      (d) => d.toCompanion(false)),
  _kind('exception', 'occurrenceExceptions', (db) => db.occurrenceExceptions,
      OccurrenceException.fromJson, (d) => d.toCompanion(false)),
  _kind('completion', 'occurrenceCompletions', (db) => db.occurrenceCompletions,
      OccurrenceCompletion.fromJson, (d) => d.toCompanion(false)),
  _kind('reminder', 'reminders', (db) => db.reminders, Reminder.fromJson,
      (d) => d.toCompanion(false)),
  // P03 (schema v5, ADR-0037).
  _kind('focusSession', 'focusSessions', (db) => db.focusSessions, FocusSessionRow.fromJson,
      (d) => d.toCompanion(false)),
  _kind('executionRecord', 'executionRecords', (db) => db.executionRecords, ExecutionRecordRow.fromJson,
      (d) => d.toCompanion(false)),
  _kind('measurement', 'measurements', (db) => db.measurements, MeasurementRow.fromJson,
      (d) => d.toCompanion(false)),
  _kind('periodResult', 'periodResults', (db) => db.periodResults, PeriodResultRow.fromJson,
      (d) => d.toCompanion(false)),
  _kind('goal', 'goals', (db) => db.goals, GoalRow.fromJson, (d) => d.toCompanion(false)),
  _kind('milestone', 'milestones', (db) => db.milestones, MilestoneRow.fromJson,
      (d) => d.toCompanion(false)),
  _kind('goalLink', 'goalLinks', (db) => db.goalLinks, GoalLinkRow.fromJson, (d) => d.toCompanion(false)),
];

final Map<String, RecordKind> recordKindByName = {for (final k in recordKinds) k.name: k};

/// Kinds whose rows belong to another record (a task or an event).
const subjectKinds = {'schedule', 'exception', 'reminder'};

/// Kinds a row can point to, for reference checks.
const referableKinds = {'task', 'event', 'calendar', 'goal', 'focusSession', 'executionRecord', 'measurement'};

/// The record a dependent row belongs to, as (kind, id), or null.
(String, String)? subjectOf(String kind, Row r) => switch (kind) {
      'schedule' || 'exception' || 'reminder' => (r['subjectType'] as String, r['subjectId'] as String),
      'completion' || 'measurement' || 'periodResult' => ('task', r['taskId'] as String),
      'milestone' => ('goal', r['goalId'] as String),
      _ => null,
    };

/// Every record a row must point to (kind, id): it cannot exist without
/// them. A goal link needs both its goal and its item.
List<(String, String)> requiredRefsOf(String kind, Row r) => [
      if (subjectOf(kind, r) case final s?) s,
      if (kind == 'goalLink') ...[('goal', r['goalId'] as String), (r['itemType'] as String, r['itemId'] as String)],
    ];

/// Optional references (kind, row field, target kind): kept when the target
/// exists, otherwise cleared (an event's calendar; a session or record of a
/// task; a measurement's record). History is never dropped for them.
const optionalRefs = <(String, String, String)>[
  ('event', 'calendarId', 'calendar'),
  ('focusSession', 'taskId', 'task'),
  ('executionRecord', 'taskId', 'task'),
  ('executionRecord', 'sessionId', 'focusSession'),
  ('measurement', 'recordId', 'executionRecord'),
];
