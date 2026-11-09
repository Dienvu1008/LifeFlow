// P01 T7b (ADR-0025, owner decision 2026-11-07): restoring a file INTO the
// profile it was exported from. Never a second profile for the same data.
//
//   compare   records (task lists, tasks) matched by id; content compared
//             without version/updatedAt; records deleted on one side and
//             absent on the other do not count
//   overwrite the profile becomes the file; records only on this device are
//             TOMBSTONED (not hard-deleted), so a later sync (P04) deletes
//             them instead of bringing them back
//   merge     (a) same id -> the newer one (updatedAt, then version)
//             (b) records only in the file are added
//             records only on this device are always kept
//   hierarchy a merge that would leave a task in a cycle, under a missing
//             parent or list, or deeper than allowed is refused unless the
//             user chose to keep this device's parents for those tasks
//
// The write is ONE command through the gateway (ADR-0011): authorized, one
// transaction with audit + outbox + event + dedupe (LF-INV-GOV-003). The
// handler adds one outbox row per changed record (same operationId) so sync
// sees every change (LF-INV-OUTBOX-001), and keeps the pre-restore state in
// the profile's own encrypted store for undo.
import 'dart:collection';
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show maxTaskDepth;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart' show Version;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'profile_export.dart';

typedef Row = Map<String, dynamic>;

const _kinds = ['taskList', 'task'];

ValueSerializer get _ser => driftRuntimeOptions.defaultSerializer;

/// One record the restore writes.
class RowChange {
  RowChange(this.kind, this.id, this.before, this.after, this.operationType,
      {required this.fromFile});

  /// 'task' | 'taskList'
  final String kind;
  final String id;

  /// The device's row before the restore; null when the record is new.
  final Row? before;
  Row after;

  /// create | update | delete (outbox operation type)
  String operationType;

  /// True when [after] comes from the file (not a tombstone of a device row).
  final bool fromFile;
}

class RestorePlan {
  RestorePlan(this.changes, this.conflictTitles);
  final List<RowChange> changes;

  /// Titles of tasks the merge would break (before any fix). Empty when the
  /// result is consistent, or when the fix was applied.
  final List<String> conflictTitles;

  int get added => changes.where((c) => c.before == null).length;
  int get removed => changes
      .where((c) => !c.fromFile && c.operationType == 'delete')
      .length;
  int get updated => changes.length - added - removed;
}

/// Records of one side, by kind then id.
class RecordSet {
  RecordSet(this.byKind);
  final Map<String, Map<String, Row>> byKind;

  static Future<RecordSet> ofDatabase(AppDatabase db) async => RecordSet({
        'taskList': {
          for (final r in await db.select(db.taskLists).get()) r.id: r.toJson()
        },
        'task': {for (final r in await db.select(db.tasks).get()) r.id: r.toJson()},
      });

  static RecordSet ofExport(ParsedExport p) => RecordSet({
        'taskList': {for (final r in p.taskLists) r.id: r.toJson()},
        'task': {for (final r in p.tasks) r.id: r.toJson()},
      });
}

class RestorePlanner {
  const RestorePlanner._();

  static String _content(Row r) {
    final m = SplayTreeMap<String, dynamic>.of(r)
      ..remove('version')
      ..remove('updatedAt');
    return jsonEncode(m);
  }

  static bool _deleted(Row r) => r['deletedAt'] != null;
  static int _version(Row r) => r['version'] as int;
  static DateTime _updated(Row r) => _ser.fromJson<DateTime>(r['updatedAt']);

  /// The file's record is newer: later updatedAt, then higher version.
  static bool fileIsNewer(Row file, Row device) {
    final f = _updated(file), d = _updated(device);
    if (f.isAfter(d)) return true;
    if (f.isAtSameMomentAs(d)) return _version(file) > _version(device);
    return false;
  }

  static RestoreDiff diff(RecordSet device, RecordSet file) {
    var onlyInFile = 0, onlyOnDevice = 0, differing = 0, newer = 0;
    for (final kind in _kinds) {
      final dev = device.byKind[kind]!, fil = file.byKind[kind]!;
      for (final e in fil.entries) {
        final d = dev[e.key];
        if (d == null) {
          if (!_deleted(e.value)) onlyInFile++;
        } else if (_content(d) != _content(e.value)) {
          differing++;
          if (fileIsNewer(e.value, d)) newer++;
        }
      }
      for (final e in dev.entries) {
        if (!fil.containsKey(e.key) && !_deleted(e.value)) onlyOnDevice++;
      }
    }
    return RestoreDiff(
        onlyInFile: onlyInFile,
        onlyOnDevice: onlyOnDevice,
        differing: differing,
        newerInFile: newer);
  }

  /// The records to write for [choice]. Pure: reads nothing, writes nothing.
  static RestorePlan plan(
    RecordSet device,
    RecordSet file,
    RestoreChoice choice, {
    required DateTime now,
    required String actor,
  }) {
    final overwrite = choice.mode == RestoreMode.overwrite;
    final nowJson = _ser.toJson<DateTime>(now);
    final changes = <RowChange>[];

    for (final kind in _kinds) {
      final dev = device.byKind[kind]!, fil = file.byKind[kind]!;
      for (final e in fil.entries) {
        final f = e.value;
        final d = dev[e.key];
        if (d == null) {
          if (overwrite || choice.addMissing) {
            changes.add(RowChange(kind, e.key, null, Row.of(f), 'create',
                fromFile: true));
          }
        } else if (_content(d) != _content(f) &&
            (overwrite || (choice.takeNewer && fileIsNewer(f, d)))) {
          final v = (_version(f) > _version(d) ? _version(f) : _version(d)) + 1;
          changes.add(RowChange(
            kind,
            e.key,
            d,
            Row.of(f)
              ..['version'] = v
              ..['updatedAt'] = nowJson,
            _deleted(f) && !_deleted(d) ? 'delete' : 'update',
            fromFile: true,
          ));
        }
      }
      if (overwrite) {
        for (final e in dev.entries) {
          if (fil.containsKey(e.key) || _deleted(e.value)) continue;
          changes.add(RowChange(
            kind,
            e.key,
            e.value,
            Row.of(e.value)
              ..['deletedAt'] = nowJson
              ..['deletedBy'] = actor
              ..['version'] = _version(e.value) + 1
              ..['updatedAt'] = nowJson,
            'delete',
            fromFile: false,
          ));
        }
      }
    }

    var offenders = _offenders(device, file, changes);
    final titles = [
      for (final id in offenders) '${changes.firstWhere((c) => c.kind == 'task' && c.id == id).after['title']}'
    ];
    if (offenders.isEmpty || !choice.keepDeviceParents) {
      return RestorePlan(changes, titles);
    }

    // Fix: keep this device's parent (and list) for the offending tasks; a
    // task that is new from the file becomes top-level. Repeat until stable;
    // the device's own hierarchy is valid, so this converges.
    for (var round = 0; offenders.isNotEmpty && round < 8; round++) {
      for (final id in offenders) {
        final c = changes.firstWhere((c) => c.kind == 'task' && c.id == id);
        final d = c.before;
        final lists = _finalIds(device, changes, 'taskList');
        // Last resort (never expected): top-level.
        final lastRound = round >= 7;
        c.after['parentTaskId'] = lastRound ? null : d?['parentTaskId'];
        final list = c.after['taskListId'];
        if (list != null && !lists.contains(list)) {
          final dl = d?['taskListId'];
          c.after['taskListId'] = dl != null && lists.contains(dl) ? dl : null;
        }
      }
      offenders = _offenders(device, file, changes);
    }
    // A record that became equal to the device again needs no write.
    changes.removeWhere((c) =>
        c.before != null && _content(c.before!) == _content(c.after));
    return RestorePlan(changes, const []);
  }

  static Set<String> _finalIds(
      RecordSet device, List<RowChange> changes, String kind) => {
        ...device.byKind[kind]!.keys,
        for (final c in changes)
          if (c.kind == kind) c.id,
      };

  /// Tasks written from the file whose final position is invalid.
  static List<String> _offenders(
      RecordSet device, RecordSet file, List<RowChange> changes) {
    final tasks = <String, Row>{...device.byKind['task']!};
    for (final c in changes) {
      if (c.kind == 'task') tasks[c.id] = c.after;
    }
    final lists = _finalIds(device, changes, 'taskList');
    final fileTasks = file.byKind['task']!;

    int? depthIn(Map<String, Row> graph, String id) {
      var depth = 1;
      final seen = <String>{id};
      String? cur = graph[id]?['parentTaskId'] as String?;
      while (cur != null) {
        if (!seen.add(cur)) return null; // cycle
        final row = graph[cur];
        if (row == null) return -1; // missing parent
        depth++;
        cur = row['parentTaskId'] as String?;
      }
      return depth;
    }

    final out = <String>[];
    for (final c in changes) {
      if (c.kind != 'task' || !c.fromFile) continue;
      final list = c.after['taskListId'];
      final depth = depthIn(tasks, c.id);
      final fileDepth = depthIn(fileTasks, c.id) ?? 0;
      final allowed = fileDepth > maxTaskDepth ? fileDepth : maxTaskDepth;
      if (depth == null ||
          depth < 0 ||
          depth > allowed ||
          (list != null && !lists.contains(list))) {
        out.add(c.id);
      }
    }
    return out;
  }
}

/// The file as data of [own] (a profile's own row), or null when the file
/// belongs to someone else. A file is this profile's data when it was
/// exported from this very profile (same id), or from the profile of the SAME
/// account on another device (same account id and provider; ADR-0025 T7c).
ParsedExport? alignToProfile(ParsedExport parsed, Profile own) {
  if (parsed.profileId == own.id) return parsed;
  final account = own.accountId;
  if (account != null &&
      parsed.accountId == account &&
      parsed.accountProvider == own.accountProvider) {
    return parsed.rebasedOnto(profileId: own.id, workspaceId: own.activeWorkspaceId);
  }
  return null;
}

/// Command types handled by [ProfileRestoreHandler].
const restoreCommandType = 'RestoreProfile';
const undoRestoreCommandType = 'UndoRestoreProfile';

/// Applies a restore (or its undo) to the profile's store inside the gateway
/// transaction. payload:
///   op: 'restore' | 'undo'
///   id: profileId (the profile row's version is the aggregate version)
///   text: the export text (restore only)
///   mode, takeNewer, addMissing, keepDeviceParents (restore only)
class ProfileRestoreHandler implements CommandHandler {
  const ProfileRestoreHandler();

  @override
  String get entityType => 'profile';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.profiles)
          ..where((p) => p.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final profileId = cmd.payload['id'] as String;
    final undo = cmd.payload['op'] == 'undo';
    final now = DateTime.now().toUtc();

    final profile = await (db.select(db.profiles)
          ..where((p) => p.id.equals(profileId)))
        .getSingleOrNull();
    if (profile == null) throw DomainRejection('unknown profile');

    // The file (or the kept pre-restore state, for undo), validated again.
    final RestoreSnapshot? snapshot = undo
        ? await (db.select(db.restoreSnapshots)..limit(1)).getSingleOrNull()
        : null;
    if (undo && snapshot == null) {
      throw DomainRejection('there is no restore to undo');
    }
    final ParsedExport file;
    try {
      file = ProfileExport.parse(
          undo ? snapshot!.exportText : cmd.payload['text'] as String,
          currentSchemaVersion: db.schemaVersion);
    } on ExportRejected catch (e) {
      throw DomainRejection(e.message);
    }
    final parsed = alignToProfile(file, profile);
    if (parsed == null) {
      throw DomainRejection('the file belongs to another profile');
    }

    final choice = undo || cmd.payload['mode'] == 'overwrite'
        ? const RestoreChoice.overwrite()
        : RestoreChoice.merge(
            takeNewer: cmd.payload['takeNewer'] == true,
            addMissing: cmd.payload['addMissing'] == true,
            keepDeviceParents: cmd.payload['keepDeviceParents'] == true,
          );
    final plan = RestorePlanner.plan(
        await RecordSet.ofDatabase(db), RecordSet.ofExport(parsed), choice,
        now: now, actor: cmd.actor.toString());
    if (plan.conflictTitles.isNotEmpty) {
      throw DomainRejection('restore-hierarchy-conflict');
    }

    // Undo copy: the state right before this restore, in this encrypted
    // store, same transaction. Only the latest is kept. An undo consumes it.
    if (undo) {
      await db.delete(db.restoreSnapshots).go();
    } else {
      final before = ProfileExport.seal(await ProfileExport.payloadOf(db),
          schemaVersion: db.schemaVersion, now: now);
      await db.delete(db.restoreSnapshots).go();
      await db.into(db.restoreSnapshots).insert(RestoreSnapshotsCompanion.insert(
          id: const Uuid().v7(),
          operationId: cmd.operationId,
          createdAt: now,
          exportText: before));
    }

    await db.batch((b) {
      // Containers the file needs (never removed).
      b.insertAll(db.workspaces, parsed.workspaces, mode: InsertMode.insertOrIgnore);
      // Lists before tasks (a task may point to a new list).
      // Upsert, NOT "insert or replace": REPLACE deletes without firing the
      // delete trigger and would leave the FTS index stale. ON CONFLICT DO
      // UPDATE fires the update trigger, so the title index stays in step.
      // toCompanion(false): a null (e.g. deletedAt or parentTaskId cleared)
      // must be WRITTEN, not skipped as "absent".
      b.insertAllOnConflictUpdate(db.taskLists, [
        for (final c in plan.changes.where((c) => c.kind == 'taskList'))
          TaskList.fromJson(c.after).toCompanion(false)
      ]);
      b.insertAllOnConflictUpdate(db.tasks, [
        for (final c in plan.changes.where((c) => c.kind == 'task'))
          Task.fromJson(c.after).toCompanion(false)
      ]);
      // Governance history is append-only: union by id, nothing rewritten.
      if (!undo) {
        b.insertAll(db.auditLog, parsed.auditLog, mode: InsertMode.insertOrIgnore);
        b.insertAll(db.opDedupe, parsed.opDedupe, mode: InsertMode.insertOrIgnore);
        b.insertAll(db.outbox, parsed.outbox, mode: InsertMode.insertOrIgnore);
        b.insertAll(
            db.eventLog,
            // Already delivered where they happened; never re-dispatched here.
            [for (final e in parsed.eventLog) e.copyWith(dispatched: true)],
            mode: InsertMode.insertOrIgnore);
      }
      // One outbox row per changed record, same operation (LF-INV-OUTBOX-001).
      for (final c in plan.changes) {
        b.insert(
            db.outbox,
            OutboxCompanion.insert(
              operationId: cmd.operationId,
              entityId: c.id,
              entityType: c.kind,
              workspaceId: c.after['workspaceId'] as String,
              actorId: cmd.actor.toString(),
              operationType: c.operationType,
              baseVersion: Value(c.before?['version'] as int?),
              payload: jsonEncode(c.after),
              createdAt: now,
            ));
      }
    });

    // The profile row (binding, sign-out state, name) is never taken from a
    // file; only its version moves, as the aggregate of this command.
    await (db.update(db.profiles)..where((p) => p.id.equals(profileId)))
        .write(ProfilesCompanion(version: Value(newVersion.value)));

    final summary = {
      'mode': undo ? 'undo' : choice.mode.name,
      if (!undo && choice.mode == RestoreMode.merge) ...{
        'takeNewer': choice.takeNewer,
        'addMissing': choice.addMissing,
        'keepDeviceParents': choice.keepDeviceParents,
      },
      'added': plan.added,
      'updated': plan.updated,
      'removed': plan.removed,
    };
    return HandlerOutcome(
      entityId: profileId,
      operationType: 'update',
      changeSet: {'id': profileId, ...summary},
      events: [
        DomainEvent(undo ? 'ProfileRestoreUndone' : 'ProfileRestored',
            {'id': profileId, ...summary}),
      ],
    );
  }
}
