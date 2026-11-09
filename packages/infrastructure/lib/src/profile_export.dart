// P01 T7 (UC-20a, FR-DATA-01/02, ADR-0025): export and restore of ONE profile.
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

import 'app_database.dart';

const exportFormat = 'lifeflow-export';

/// Version of the envelope layout. Bump when the envelope itself changes.
const exportFormatVersion = 1;

/// A real export is far smaller; refuse to parse anything bigger (SR-14).
const maxExportBytes = 64 * 1024 * 1024;

const exportNotice =
    'This file is an unencrypted copy of one LifeFlow profile. Keep it '
    'somewhere safe. It contains no password, key or sign-in token.';

/// The tables an export carries, in write order. A test guards that this list
/// covers every table of the schema, so a new table cannot be forgotten
/// (LF-INV-SEC-010).
const exportedTables = [
  'profiles',
  'workspaces',
  'taskLists',
  'tasks',
  'auditLog',
  'outbox',
  'eventLog',
  'opDedupe',
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
      this.profile, this.workspaces, this.taskLists, this.tasks, this.auditLog,
      this.outbox, this.eventLog, this.opDedupe);

  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, Object?> _payload;

  final Profile profile;
  final List<Workspace> workspaces;
  final List<TaskList> taskLists;
  final List<Task> tasks;
  final List<AuditLogData> auditLog;
  final List<OutboxData> outbox;
  final List<EventLogData> eventLog;
  final List<OpDedupeData> opDedupe;

  String get profileId => profile.id;
  String get workspaceId => profile.activeWorkspaceId;
  String get displayName => profile.displayName;
  int get taskCount => tasks.length;

  /// The validated payload (read-only use).
  Map<String, Object?> get payload => _payload;

  /// The account the exported profile was bound to, if any.
  String? get accountId => profile.accountId;
  String? get accountProvider => profile.accountProvider;

  /// The same records placed in ANOTHER profile and workspace: the profile of
  /// the same account on another device (ADR-0025, T7c). Until sync (P04)
  /// each device gives an account its own profile and workspace ids, so the
  /// container ids are mapped; record ids (tasks, lists) are kept, which is
  /// what lets two exports of the same device compare. Governance history is
  /// kept as written (it records what happened where it happened).
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
      [
        for (final l in taskLists)
          l.copyWith(workspaceId: ws(l.workspaceId), ownerId: owner(l.ownerId))
      ],
      [
        for (final t in tasks)
          t.copyWith(workspaceId: ws(t.workspaceId), ownerId: owner(t.ownerId))
      ],
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
  static Future<Map<String, Object?>> payloadOf(AppDatabase db) async =>
      <String, Object?>{
        'profiles': [for (final r in await db.select(db.profiles).get()) r.toJson()],
        'workspaces': [for (final r in await db.select(db.workspaces).get()) r.toJson()],
        'taskLists': [for (final r in await db.select(db.taskLists).get()) r.toJson()],
        // Includes trashed tasks: tombstones are part of the data (SYNC-004).
        'tasks': [for (final r in await db.select(db.tasks).get()) r.toJson()],
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
  /// filling the columns added since (additive migrations only, VS-04).
  static void _upgradeOlderSchema(Map<String, Object?> map, int fromSchema) {
    if (fromSchema < 2) {
      for (final p in (map['profiles'] as List).cast<Map<String, Object?>>()) {
        p.putIfAbsent('signedOut', () => false); // schema v2 (ADR-0024)
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
    final taskLists = rows('taskLists', TaskList.fromJson);
    final tasks = rows('tasks', Task.fromJson);
    final audit = rows('auditLog', AuditLogData.fromJson);
    final outbox = rows('outbox', OutboxData.fromJson);
    final events = rows('eventLog', EventLogData.fromJson);
    final dedupe = rows('opDedupe', OpDedupeData.fromJson);

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

    unique(taskLists.map((r) => r.id), 'task lists');
    unique(tasks.map((r) => r.id), 'tasks');
    unique(audit.map((r) => r.auditId), 'audit rows');
    unique(events.map((r) => r.eventId), 'events');
    unique(dedupe.map((r) => r.operationId), 'operations');
    unique(outbox.map((r) => '${r.operationId}/${r.entityId}'), 'outbox rows');

    // References resolve inside the file.
    final listIds = {for (final l in taskLists) l.id};
    final taskIds = {for (final t in tasks) t.id};
    if (taskLists.any((l) => !wsIds.contains(l.workspaceId)) ||
        tasks.any((t) => !wsIds.contains(t.workspaceId)) ||
        outbox.any((o) => !wsIds.contains(o.workspaceId)) ||
        dedupe.any((d) => !wsIds.contains(d.workspaceId))) {
      bad('a row points to an unknown workspace');
    }
    if (tasks.any((t) => t.taskListId != null && !listIds.contains(t.taskListId))) {
      bad('a task points to an unknown list');
    }
    final parent = <String, String?>{};
    for (final t in tasks) {
      if (t.parentTaskId != null && !taskIds.contains(t.parentTaskId)) {
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

    return ParsedExport._(schemaVersion, exportedAt, map, profile, workspaces,
        taskLists, tasks, audit, outbox, events, dedupe);
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
        b.insertAll(db.taskLists, data.taskLists);
        b.insertAll(db.tasks, data.tasks); // FTS triggers index the titles
        b.insertAll(db.opDedupe, data.opDedupe);
        b.insertAll(db.auditLog, data.auditLog);
        b.insertAll(db.outbox, data.outbox);
        b.insertAll(db.eventLog, data.eventLog);
      });
    });
  }
}
