// P01 T7 (UC-20a, FR-DATA-01/02, ADR-0025): export and restore of ONE profile.
// P02 T3 (ADR-0029): the record tables are listed once in record_kinds.dart.
//
// The export is a DECRYPTED, versioned, checksummed JSON document, so it is
// portable and does not need the database key (OQ-DATA-3 option a). It holds
// every user-owned row of the profile's store, including tombstones and the
// governance tables (audit, outbox, event log, dedupe), and no key or token
// (LF-INV-SEC-001, LF-INV-SEC-010). Import treats the file as untrusted until
// it is validated (SR-14, threat T9): format, version, checksum, consistency.
import 'dart:convert';

import 'package:application/application.dart' show RestoreRejection;
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:foundation/foundation.dart' show LocalDate;

import 'app_database.dart';
import 'execution_rows.dart';
import 'record_kinds.dart';
import 'schedule_mapping.dart';

export 'record_kinds.dart' show Row;

const exportFormat = 'lifeflow-export';

/// Version of the envelope layout. Bump when the envelope itself changes.
const exportFormatVersion = 1;

/// A real export is far smaller; refuse to parse anything bigger (SR-14).
const maxExportBytes = 64 * 1024 * 1024;

const exportNotice =
    'This file is an unencrypted copy of one LifeFlow profile. Keep it '
    'somewhere safe. It contains no password, key or sign-in token.';

const _governanceTables = ['auditLog', 'outbox', 'eventLog', 'opDedupe'];

/// The tables an export carries. A test guards that this list plus
/// [notExportedTables] covers every table of the schema, so a new table
/// cannot be forgotten (LF-INV-SEC-010).
final List<String> exportedTables = [
  'profiles',
  'workspaces',
  for (final k in recordKinds) k.exportKey,
  ..._governanceTables,
];

/// Tables that are deliberately NOT exported. `restoreSnapshots` holds the
/// undo copy of the last restore (an export itself); exporting it would nest
/// old data in every file.
const notExportedTables = ['restoreSnapshots'];

/// A file that must not be restored. [message] is safe to show to the user and
/// never echoes file contents.
class ExportRejected implements Exception {
  const ExportRejected(this.kind, this.message);
  final RestoreRejection kind;
  final String message;
  @override
  String toString() => 'ExportRejected($kind): $message';
}

/// A validated export. Construct only through [ProfileExport.parse].
class ParsedExport {
  ParsedExport._(this.schemaVersion, this.exportedAt, this._payload,
      this.profile, this.workspaces, this.records, this.auditLog,
      this.outbox, this.eventLog, this.opDedupe);

  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, Object?> _payload;

  final Profile profile;
  final List<Workspace> workspaces;

  /// Validated record rows by kind name (see [recordKinds]), as JSON.
  final Map<String, List<Row>> records;
  final List<AuditLogData> auditLog;
  final List<OutboxData> outbox;
  final List<EventLogData> eventLog;
  final List<OpDedupeData> opDedupe;

  List<TaskList> get taskLists => [for (final r in records['taskList']!) TaskList.fromJson(r)];
  List<Task> get tasks => [for (final r in records['task']!) Task.fromJson(r)];

  String get profileId => profile.id;
  String get workspaceId => profile.activeWorkspaceId;
  String get displayName => profile.displayName;
  int get taskCount => records['task']!.length;

  /// The validated payload (read-only use).
  Map<String, Object?> get payload => _payload;

  /// The account the exported profile was bound to, if any.
  String? get accountId => profile.accountId;
  String? get accountProvider => profile.accountProvider;

  /// The same records placed in ANOTHER profile and workspace: the profile of
  /// the same account on another device (ADR-0025, T7c). Until sync (P04)
  /// each device gives an account its own profile and workspace ids, so the
  /// container ids are mapped; record ids are kept, which is what lets two
  /// exports of the same device compare. Governance history is kept as
  /// written (it records what happened where it happened).
  ParsedExport rebasedOnto({required String profileId, required String workspaceId}) {
    final fromWs = this.workspaceId;
    final fromProfile = this.profileId;
    String ws(String w) => w == fromWs ? workspaceId : w;
    String owner(String o) => o == fromProfile ? profileId : o;
    return ParsedExport._(
      schemaVersion,
      exportedAt,
      _payload,
      profile.copyWith(id: profileId, activeWorkspaceId: workspaceId),
      // The target profile's own workspace already exists.
      [
        for (final w in workspaces)
          if (w.id != fromWs) w.copyWith(ownerId: owner(w.ownerId))
      ],
      {
        for (final e in records.entries)
          e.key: [
            for (final r in e.value)
              Row.of(r)
                ..['workspaceId'] = ws(r['workspaceId'] as String)
                ..['ownerId'] = owner(r['ownerId'] as String)
          ]
      },
      auditLog,
      [for (final o in outbox) o.copyWith(workspaceId: ws(o.workspaceId))],
      eventLog,
      [for (final d in opDedupe) d.copyWith(workspaceId: ws(d.workspaceId))],
    );
  }
}

class ProfileExport {
  const ProfileExport._();

  // --- export ---------------------------------------------------------------

  /// Builds the export text for the single profile in [db]. Reads one
  /// consistent snapshot. [now] is injectable for tests.
  static Future<String> build(AppDatabase db, {DateTime? now}) async {
    final payload = await db.transaction(() => payloadOf(db));
    return seal(payload, schemaVersion: db.schemaVersion, now: now);
  }

  /// The export payload of [db], read in the CALLER's transaction (if any).
  /// Includes tombstones: they are part of the data (SYNC-004).
  static Future<Map<String, Object?>> payloadOf(AppDatabase db) async =>
      <String, Object?>{
        'profiles': [for (final r in await db.select(db.profiles).get()) r.toJson()],
        'workspaces': [for (final r in await db.select(db.workspaces).get()) r.toJson()],
        for (final k in recordKinds) k.exportKey: await k.readAll(db),
        'auditLog': [for (final r in await db.select(db.auditLog).get()) r.toJson()],
        'outbox': [for (final r in await db.select(db.outbox).get()) r.toJson()],
        'eventLog': [for (final r in await db.select(db.eventLog).get()) r.toJson()],
        'opDedupe': [for (final r in await db.select(db.opDedupe).get()) r.toJson()],
      };

  /// Wraps [payload] in the envelope with counts and checksum. Public so tests
  /// can build files that are structurally wrong but correctly sealed.
  static String seal(Map<String, Object?> payload,
      {required int schemaVersion, DateTime? now}) {
    final counts = {
      for (final t in exportedTables) t: (payload[t] as List?)?.length ?? 0
    };
    return jsonEncode({
      'format': exportFormat,
      'formatVersion': exportFormatVersion,
      'schemaVersion': schemaVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'notice': exportNotice,
      'counts': counts,
      'checksumSha256': _checksum(payload),
      'payload': payload,
    });
  }

  static String _checksum(Map<String, Object?> payload) =>
      sha256.convert(utf8.encode(jsonEncode(payload))).toString();

  // --- import: validate ------------------------------------------------------

  /// Validates [text] and returns the typed data, or throws [ExportRejected].
  /// Writes nothing. [currentSchemaVersion] is the schema this app runs.
  static ParsedExport parse(String text,
      {required int currentSchemaVersion, int maxBytes = maxExportBytes}) {
    if (text.length > maxBytes) {
      throw const ExportRejected(RestoreRejection.tooLarge,
          'This file is too large to be a LifeFlow export.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const ExportRejected(RestoreRejection.notAnExport,
          'This is not a LifeFlow export file.');
    }
    if (decoded is! Map || decoded['format'] != exportFormat) {
      throw const ExportRejected(RestoreRejection.notAnExport,
          'This is not a LifeFlow export file.');
    }
    final formatVersion = decoded['formatVersion'];
    final schemaVersion = decoded['schemaVersion'];
    if (formatVersion is! int || schemaVersion is! int) {
      throw const ExportRejected(RestoreRejection.notAnExport,
          'This is not a LifeFlow export file.');
    }
    // AC-20a.2: a newer file is rejected BEFORE anything else, because we may
    // not understand its checksum or layout.
    if (formatVersion > exportFormatVersion || schemaVersion > currentSchemaVersion) {
      throw const ExportRejected(RestoreRejection.newerVersion,
          'This export was made by a newer version of LifeFlow. Update the '
          'app, then try again.');
    }
    final payload = decoded['payload'];
    final checksum = decoded['checksumSha256'];
    if (payload is! Map || checksum is! String) {
      throw const ExportRejected(RestoreRejection.notAnExport,
          'This is not a LifeFlow export file.');
    }
    final map = payload.cast<String, Object?>();
    if (_checksum(map) != checksum) {
      throw const ExportRejected(RestoreRejection.corrupted,
          'This file was changed or damaged and cannot be restored.');
    }
    final counts = decoded['counts'];
    if (counts is! Map ||
        exportedTables.any((t) => counts[t] != (map[t] as List?)?.length)) {
      throw const ExportRejected(RestoreRejection.invalidContents,
          'This file is incomplete and cannot be restored.');
    }
    final exportedAt = DateTime.tryParse('${decoded['exportedAt']}') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    _upgradeOlderSchema(map, schemaVersion);
    return _decode(map, schemaVersion, exportedAt);
  }

  /// Brings a payload written by an older schema up to the current one by
  /// filling what was added since (additive migrations only, VS-04).
  static void _upgradeOlderSchema(Map<String, Object?> map, int fromSchema) {
    if (fromSchema < 2) {
      for (final p in (map['profiles'] as List).cast<Map<String, Object?>>()) {
        p.putIfAbsent('signedOut', () => false); // schema v2 (ADR-0024)
      }
    }
    if (fromSchema < 5) {
      // Schema v4 (P02 T3): planning and calendar tables did not exist.
      // Schema v5 (P03 T2): execution, measurement, habit and goal tables
      // did not exist, and tasks had no aggregation or habit flag.
      for (final k in recordKinds) {
        map.putIfAbsent(k.exportKey, () => <Object?>[]);
      }
      final tasks = map['tasks'];
      if (tasks is List) {
        for (final t in tasks) {
          if (t is Map) {
            t.putIfAbsent('targetAggregation', () => 'sum');
            t.putIfAbsent('isHabit', () => false);
          }
        }
      }
    }
    if (fromSchema < 6) {
      // Schema v6 (P03 T4): tasks had no tracking start.
      final tasks = map['tasks'];
      if (tasks is List) {
        for (final t in tasks) {
          if (t is Map) t.putIfAbsent('trackedSince', () => null);
        }
      }
    }
  }

  static ParsedExport _decode(
      Map<String, Object?> map, int schemaVersion, DateTime exportedAt) {
    Never bad(String why) => throw ExportRejected(
        RestoreRejection.invalidContents,
        'This file has contents that cannot be restored ($why).');

    List<T> rows<T>(String key, T Function(Map<String, dynamic>) read) {
      final raw = map[key];
      if (raw is! List) bad('missing $key');
      try {
        return [for (final r in raw) read((r as Map).cast<String, dynamic>())];
      } catch (_) {
        bad('unreadable $key');
      }
    }

    final profiles = rows('profiles', Profile.fromJson);
    final workspaces = rows('workspaces', Workspace.fromJson);
    final audit = rows('auditLog', AuditLogData.fromJson);
    final outbox = rows('outbox', OutboxData.fromJson);
    final events = rows('eventLog', EventLogData.fromJson);
    final dedupe = rows('opDedupe', OpDedupeData.fromJson);

    // Record tables: each row must parse with its table's own reader; the
    // JSON round trip normalizes it.
    final records = <String, List<Row>>{};
    for (final k in recordKinds) {
      final raw = map[k.exportKey];
      if (raw is! List) bad('missing ${k.exportKey}');
      final list = <Row>[];
      try {
        for (final r in raw) {
          list.add((r as Map).cast<String, dynamic>());
        }
        k.checkRows(list);
      } catch (_) {
        bad('unreadable ${k.exportKey}');
      }
      records[k.name] = list;
    }

    // One profile per store (SR-03, WA-001).
    if (profiles.length != 1) bad('expected one profile');
    final profile = profiles.single;
    final wsIds = {for (final w in workspaces) w.id};
    if (wsIds.length != workspaces.length) bad('duplicate workspaces');
    final home = workspaces.where((w) => w.id == profile.activeWorkspaceId);
    if (home.length != 1 || home.single.ownerId != profile.id) {
      bad('profile and workspace do not match');
    }
    if (workspaces.any((w) => w.ownerId != profile.id)) {
      bad('a workspace belongs to another profile');
    }

    // Unique primary keys, so the write cannot half-succeed on a duplicate.
    void unique(Iterable<String> ids, String what) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) bad('duplicate $what');
      }
    }

    final ids = <String, Set<String>>{};
    for (final k in recordKinds) {
      unique(records[k.name]!.map((r) => r['id'] as String), k.exportKey);
      ids[k.name] = {for (final r in records[k.name]!) r['id'] as String};
      if (records[k.name]!.any((r) => !wsIds.contains(r['workspaceId']))) {
        bad('a row points to an unknown workspace');
      }
    }
    unique(audit.map((r) => r.auditId), 'audit rows');
    unique(events.map((r) => r.eventId), 'events');
    unique(dedupe.map((r) => r.operationId), 'operations');
    unique(outbox.map((r) => '${r.operationId}/${r.entityId}'), 'outbox rows');
    if (outbox.any((o) => !wsIds.contains(o.workspaceId)) ||
        dedupe.any((d) => !wsIds.contains(d.workspaceId))) {
      bad('a row points to an unknown workspace');
    }

    // References resolve inside the file.
    final tasks = [for (final r in records['task']!) Task.fromJson(r)];
    if (tasks.any((t) => t.taskListId != null && !ids['taskList']!.contains(t.taskListId))) {
      bad('a task points to an unknown list');
    }
    final parent = <String, String?>{};
    for (final t in tasks) {
      if (t.parentTaskId != null && !ids['task']!.contains(t.parentTaskId)) {
        bad('a task points to an unknown parent');
      }
      parent[t.id] = t.parentTaskId;
    }
    // The hierarchy must be acyclic (LF-INV-TASK-003). Depth is NOT enforced
    // here: existing deeper data stays valid (GS-18).
    for (final start in parent.keys) {
      var cur = start;
      var steps = 0;
      while (parent[cur] != null) {
        cur = parent[cur]!;
        if (++steps > parent.length) bad('the task hierarchy has a cycle');
      }
    }
    for (final e in records['event']!) {
      final c = e['calendarId'];
      if (c != null && !ids['calendar']!.contains(c)) bad('an event points to an unknown calendar');
    }
    // Dependent rows point to existing records (a task or an event; a goal;
    // both ends of a goal link).
    for (final k in recordKinds) {
      for (final r in records[k.name]!) {
        for (final (type, id) in requiredRefsOf(k.name, r)) {
          final allowed = k.name == 'milestone' || (k.name == 'goalLink' && type == 'goal')
              ? type == 'goal'
              : type == 'task' || type == 'event';
          if (!allowed || !(ids[type]?.contains(id) ?? false)) bad('a ${k.name} points to an unknown item');
        }
      }
    }
    // Optional references, when set, resolve inside the file too.
    for (final (kind, field, target) in optionalRefs) {
      for (final r in records[kind]!) {
        final v = r[field];
        if (v != null && !ids[target]!.contains(v)) bad('a $kind points to an unknown $target');
      }
    }
    // P03 rows are well-formed (values, states, keyed ids).
    final p03 = executionRowsError(records);
    if (p03 != null) bad(p03);
    // Schedules and exceptions are well-formed and valid (dates, zones, rule).
    final scheduled = <String>{};
    try {
      for (final r in records['schedule']!) {
        readSchedule(Schedule.fromJson(r));
        scheduled.add(r['id'] as String);
      }
      for (final r in records['exception']!) {
        exceptionOf(OccurrenceException.fromJson(r));
        if (!scheduled.contains(scheduleIdOf(r['subjectType'] as String, r['subjectId'] as String))) {
          bad('an exception belongs to an item without a schedule');
        }
      }
      for (final r in records['completion']!) {
        final c = OccurrenceCompletion.fromJson(r);
        if (c.id != completionIdOf(c.taskId, LocalDate.parse(c.originalDate))) {
          bad('a completion id does not match its task and date');
        }
      }
    } on BadScheduleRow catch (e) {
      bad(e.why);
    } on FormatException {
      bad('a date cannot be read');
    } on ArgumentError {
      bad('a date does not exist');
    }

    return ParsedExport._(schemaVersion, exportedAt, map, profile, workspaces,
        records, audit, outbox, events, dedupe);
  }

  // --- import: write ----------------------------------------------------------

  /// Writes [data] into the EMPTY store [db] in one transaction. The restored
  /// profile is a guest: it carries no account binding and is not locked, so an
  /// account is never linked to two profiles (ADR-0008, ADR-0024), and it is
  /// the active profile of its own store, like every store (SR-03).
  static Future<void> writeInto(AppDatabase db, ParsedExport data) async {
    await db.transaction(() async {
      if ((await db.select(db.profiles).get()).isNotEmpty) {
        throw StateError('the target store is not empty');
      }
      await db.batch((b) {
        b.insertAll(db.profiles, [
          data.profile.copyWith(
            accountId: const Value(null),
            accountProvider: const Value(null),
            signedOut: false,
            isActive: true,
          )
        ]);
        b.insertAll(db.workspaces, data.workspaces);
        for (final k in recordKinds) {
          k.insertAll(b, db, data.records[k.name]!); // FTS triggers index titles
        }
        b.insertAll(db.opDedupe, data.opDedupe);
        b.insertAll(db.auditLog, data.auditLog);
        b.insertAll(db.outbox, data.outbox);
        b.insertAll(db.eventLog, data.eventLog);
      });
    });
  }
}
