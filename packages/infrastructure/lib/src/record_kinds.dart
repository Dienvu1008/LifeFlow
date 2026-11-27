// The user-owned record tables of a profile store, in one registry
// (P02 T3, ADR-0029). Export, validation, restore compare/merge/undo and the
// clean-install restore all go through this list, so a new record table is
// handled everywhere by adding it here (and a guard test fails if a table of
// the schema is neither here nor deliberately excluded).
//
// Every record table uses the shared syncable columns (ADR-0009): text id,
// workspaceId, ownerId, version, createdAt, updatedAt, deletedAt (tombstone).
import 'package:domain/domain.dart' show DataClassification, personalMeasurementSources;
import 'package:drift/drift.dart';

import 'app_database.dart';

typedef Row = Map<String, dynamic>;

/// One record table: how to read it as JSON rows and write rows back.
class RecordKind {
  const RecordKind._(this.name, this.exportKey, this._read, this._write, this._insert, this._readOne, this.tableName);

  /// Kind name used in plans and outbox rows ('task', 'schedule', ...).
  final String name;

  /// Key of the table in an export payload (the Drift table getter name).
  final String exportKey;

  final Future<List<Row>> Function(AppDatabase db) _read;

  /// Upsert (fires update triggers; nulls are written, not skipped).
  final void Function(Batch b, AppDatabase db, List<Row> rows) _write;

  /// Plain insert into an empty store.
  final void Function(Batch b, AppDatabase db, List<Row> rows) _insert;

  final Future<Row?> Function(AppDatabase db, String id) _readOne;

  /// The SQL table (P04 T3: purging a record).
  final String tableName;

  /// One row as JSON, or null (P04 T3: the push reads the current record).
  Future<Row?> readOne(AppDatabase db, String id) => _readOne(db, id);

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
    'extraTime': ExtraTime.fromJson,
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
    'workspaceSettings': WorkspaceSetting.fromJson,
    'memberCard': MemberCard.fromJson,
    'document': DocumentRow.fromJson,
    'documentRevision': DocumentRevisionRow.fromJson,
    'documentLink': DocumentLinkRow.fromJson,
    'aiSession': AiSessionRow.fromJson,
    'aiMessage': AiMessageRow.fromJson,
    'aiProposal': AiProposalRow.fromJson,
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
      (db, id) async {
        final t = table(db);
        final rows = await db.customSelect('SELECT * FROM ${t.actualTableName} WHERE id = ?',
            variables: [Variable<String>(id)], readsFrom: {t}).get();
        return rows.isEmpty ? null : (t.map(rows.single.data) as DataClass).toJson();
      },
      exportKey.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}'),
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
  // P06c E1 (schema v20, ADR-0095): after its task or event.
  _kind('extraTime', 'extraTimes', (db) => db.extraTimes, ExtraTime.fromJson, (d) => d.toCompanion(false)),
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
  // P05a T2 (schema v16, ADR-0067): documents, written before what points to
  // them (their revisions, their links).
  _kind('document', 'documents', (db) => db.documents, DocumentRow.fromJson, (d) => d.toCompanion(false)),
  _kind('documentRevision', 'documentRevisions', (db) => db.documentRevisions, DocumentRevisionRow.fromJson,
      (d) => d.toCompanion(false)),
  _kind('documentLink', 'documentLinks', (db) => db.documentLinks, DocumentLinkRow.fromJson,
      (d) => d.toCompanion(false)),
  // P06 T3 (schema v18, ADR-0082; the owner's D7): the assistant's history,
  // a session before its messages, a message before the proposal it holds.
  _kind('aiSession', 'aiSessions', (db) => db.aiSessions, AiSessionRow.fromJson, (d) => d.toCompanion(false)),
  _kind('aiMessage', 'aiMessages', (db) => db.aiMessages, AiMessageRow.fromJson, (d) => d.toCompanion(false)),
  _kind('aiProposal', 'aiProposals', (db) => db.aiProposals, AiProposalRow.fromJson, (d) => d.toCompanion(false)),
  // P04 T1 (schema v10, ADR-0053): settings that sync with the workspace.
  _kind('workspaceSettings', 'workspaceSettings', (db) => db.workspaceSettings, WorkspaceSetting.fromJson,
      (d) => d.toCompanion(false)),
  // P04b T13 (schema v15, ADR-0065): members' names in a shared space.
  _kind('memberCard', 'memberCards', (db) => db.memberCards, MemberCard.fromJson, (d) => d.toCompanion(false)),
];

final Map<String, RecordKind> recordKindByName = {for (final k in recordKinds) k.name: k};

/// P04b B2 (ADR-0063): the kinds a shared space holds: lists, tasks with
/// their schedules, repeats and done ticks, events and calendars, goals and
/// milestones (and the links between them), and the space's settings.
/// Reminders, focus sessions, execution records, measurements and period
/// results stay personal: a space's sync never sends or takes them.
const sharedSpaceKinds = {
  'taskList', 'task', 'calendar', 'event', 'schedule', 'extraTime', 'exception', 'completion', 'goal', 'milestone', 'goalLink',
  'workspaceSettings', 'memberCard',
  // P05a T5 (ADR-0070, owner's C2): documents, their history and their links.
  'document', 'documentRevision', 'documentLink',
};

/// Kinds whose rows belong to another record (a task or an event).
const subjectKinds = {'schedule', 'extraTime', 'exception', 'reminder'};

/// Kinds a row can point to, for reference checks.
const referableKinds = {
  'taskList', 'task', 'event', 'calendar', 'goal', 'focusSession', 'executionRecord', 'measurement', 'document',
  'aiSession', 'aiMessage',
  'extraTime', // P06c E3: a repeating extra time's changes and ticks point to it
};

/// The record a dependent row belongs to, as (kind, id), or null.
(String, String)? subjectOf(String kind, Row r) => switch (kind) {
      'schedule' || 'extraTime' || 'exception' || 'reminder' => (r['subjectType'] as String, r['subjectId'] as String),
      'completion' || 'measurement' || 'periodResult' => ('task', r['taskId'] as String),
      'milestone' => ('goal', r['goalId'] as String),
      'documentRevision' => ('document', r['documentId'] as String),
      'aiMessage' || 'aiProposal' => ('aiSession', r['sessionId'] as String),
      _ => null,
    };

/// Every record a row must point to (kind, id): it cannot exist without
/// them. A goal link needs both its goal and its item.
List<(String, String)> requiredRefsOf(String kind, Row r) => [
      if (subjectOf(kind, r) case final s?) s,
      if (kind == 'completion' && r['extraId'] is String) ('extraTime', r['extraId'] as String),
      if (kind == 'goalLink') ...[('goal', r['goalId'] as String), (r['itemType'] as String, r['itemId'] as String)],
      if (kind == 'documentLink') ...[
        ('document', r['documentId'] as String),
        (r['itemType'] as String, r['itemId'] as String),
      ],
    ];

/// Optional references (kind, row field, target kind): kept when the target
/// exists, otherwise cleared (an event's calendar; a session or record of a
/// task; a measurement's record). History is never dropped for them.
const optionalRefs = <(String, String, String)>[
  ('event', 'calendarId', 'calendar'),
  ('event', 'listId', 'taskList'), // P03 UX U2
  ('focusSession', 'taskId', 'task'),
  ('executionRecord', 'taskId', 'task'),
  ('executionRecord', 'sessionId', 'focusSession'),
  ('measurement', 'recordId', 'executionRecord'),
  ('document', 'parentId', 'document'), // P05a: a missing parent puts it at the top
  ('aiProposal', 'messageId', 'aiMessage'), // P06 T3
];

/// P04 T7 (ADR-0059; data-classification.md §1, §3): the class of each kind's
/// records. A task carries its notes (Confidential); a workspace's settings
/// and a goal link are bookkeeping of Personal data. A guard test fails when
/// a kind of [recordKinds] is missing here.
const kindClasses = <String, DataClassification>{
  'taskList': DataClassification.personal,
  'task': DataClassification.confidential,
  'calendar': DataClassification.personal,
  'event': DataClassification.personal,
  'schedule': DataClassification.personal,
  'extraTime': DataClassification.personal,
  'exception': DataClassification.personal,
  'completion': DataClassification.personal,
  'reminder': DataClassification.personal,
  'focusSession': DataClassification.personal,
  'executionRecord': DataClassification.personal,
  'measurement': DataClassification.personal,
  'periodResult': DataClassification.personal,
  'goal': DataClassification.personal,
  'milestone': DataClassification.personal,
  'goalLink': DataClassification.personal,
  'workspaceSettings': DataClassification.personal,
  'memberCard': DataClassification.personal,
  // P05a (ADR-0067; data-classification.md: document bodies are Confidential).
  'document': DataClassification.confidential,
  'documentRevision': DataClassification.confidential,
  'documentLink': DataClassification.personal,
  // P06 T3 (ADR-0082; D7): what a person asked, what the assistant said and
  // proposed hold their notes and documents: Confidential, as notes.
  'aiSession': DataClassification.confidential,
  'aiMessage': DataClassification.confidential,
  'aiProposal': DataClassification.confidential,
};

/// The class of one record: its kind's, raised to Restricted for a
/// measurement from a health source (P08). An unknown kind is Restricted,
/// so nothing unclassified leaves the device (LF-INV-PRIV-001).
DataClassification dataClassOf(String kind, Row row) {
  final c = kindClasses[kind];
  if (c == null) return DataClassification.restricted;
  if (kind == 'measurement' && !personalMeasurementSources.contains(row['source'])) return DataClassification.restricted;
  return c;
}
