// P04 T3 (ADR-0056, sync-protocol.md; spike S-04): one device's sync of one
// workspace with the server, end-to-end encrypted.
//   push   every record a pending outbox row names, as it is now, sealed,
//          with the version last synced as its base. Accepted: the copy
//          becomes the last synced one and its outbox rows are acked.
//          Conflict: left pending; the pull merges and pushes on top.
//   pull   the server's changes after this device's cursor, page by page.
//          A record this device did not change since the last sync is taken
//          as it is; one it changed too is merged per type (mergeRecord,
//          ADR-0015). Each page is applied as one command (SyncApplyHandler).
//   purge  the server is asked to drop the content of records deleted more
//          than 90 days ago; the tombstones reach every device (GS-14).
// Failures: no connection, a paused server or a lost answer leave
// everything pending for the next try (nothing is lost; a retry is the same
// operations, SYNC-001). A record the server refuses is set aside as failed
// so the rest still syncs.
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show mergeRecord, SyncReviewReason;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../record_kinds.dart';
import 'sealing.dart';
import 'sync_apply_handler.dart';

/// Waiting time before the next try after [failures] failed syncs in a row:
/// 5 s, 15 s, 1 min, 5 min, then every 15 min.
Duration syncBackoff(int failures) => switch (failures) {
      <= 0 => Duration.zero,
      1 => const Duration(seconds: 5),
      2 => const Duration(seconds: 15),
      3 => const Duration(minutes: 1),
      4 => const Duration(minutes: 5),
      _ => const Duration(minutes: 15),
    };

const _opNamespace = '6f1b3a52-8c1e-4f0e-9c2b-7d4a1e5b9c33';

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.gateway,
    required this.remote,
    required this.sealer,
    required this.workspaceId,
    required this.deviceId,
    this.pageSize = maxPullPage,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final AppDatabase db;
  final CommandGateway gateway;
  final RemoteGateway remote;
  final RecordSealer sealer;
  final String workspaceId;
  final String deviceId;
  final int pageSize;
  final DateTime Function() clock;

  int _pushed = 0, _pulled = 0, _merged = 0, _reviews = 0, _failed = 0;
  bool _updateNeeded = false;

  /// Push, pull and push again until nothing is left (a conflict is merged
  /// by the pull and its merge pushed in the next round).
  Future<SyncReport> sync({int rounds = 4}) async {
    _pushed = _pulled = _merged = _reviews = _failed = 0;
    _updateNeeded = false;
    final state = await _state();
    if (state == null) throw StateError('sync is not on for this workspace on this device');
    SyncReport report;
    try {
      // ADR-0057: is the workspace still there, sealed with this device's key?
      final here = (await remote.workspaces()).where((w) => w.workspaceId == workspaceId).firstOrNull;
      if (here == null) return await _finish(_report(SyncOutcome.workspaceGone));
      if (here.keyId.isNotEmpty && here.keyId != sealer.keyId) return await _finish(_report(SyncOutcome.keyChanged));
      var settled = false;
      for (var i = 0; i < rounds && !settled; i++) {
        final conflicts = await _push();
        await _pull();
        settled = conflicts == 0 && await _pendingCount() == 0;
      }
      try {
        await remote.purge(workspaceId, clock().subtract(const Duration(days: 90)));
      } on RemoteFailure {
        // Purging can wait for the next sync.
      }
      report = _report(_updateNeeded ? SyncOutcome.updateNeeded : SyncOutcome.upToDate);
    } on RemoteFailure catch (e) {
      report = _report(switch (e.kind) {
        RemoteFailureKind.unavailable => SyncOutcome.offline,
        RemoteFailureKind.signedOut => SyncOutcome.signedOut,
        RemoteFailureKind.notYours => SyncOutcome.notYours,
        RemoteFailureKind.refused => SyncOutcome.failed,
      }, e.detail);
    } catch (e) {
      // P04 T6: anything else (a store error while applying a page) is a
      // failed sync, never an exception out of "Sync now". The page's
      // transaction rolled back; the cursor did not move. Only the type is
      // kept: a store error can quote the values it was writing.
      report = _report(SyncOutcome.failed, 'error: ${e.runtimeType}');
    }
    return _finish(report);
  }

  Future<SyncReport> _finish(SyncReport report) async {
    await (db.update(db.syncState)..where((s) => s.workspaceId.equals(workspaceId)))
        .write(SyncStateCompanion(lastResult: Value(report.outcome.name)));
    return report;
  }

  SyncReport _report(SyncOutcome o, [String detail = '']) => SyncReport(o,
      pushed: _pushed, pulled: _pulled, merged: _merged, reviews: _reviews, failedRecords: _failed, detail: detail);

  Future<SyncStateRow?> _state() =>
      (db.select(db.syncState)..where((s) => s.workspaceId.equals(workspaceId))).getSingleOrNull();

  /// Pending outbox rows that name a record of this workspace.
  Future<int> _pendingCount() async {
    final kinds = recordKinds.map((k) => "'${k.name}'").join(',');
    return (await db.customSelect(
            "SELECT count(*) AS n FROM outbox WHERE status = 'pending' AND workspace_id = ? AND entity_type IN ($kinds)",
            variables: [Variable<String>(workspaceId)]).getSingle())
        .read<int>('n');
  }

  Future<SyncBaseRow?> _base(String kind, String id) =>
      (db.select(db.syncBase)..where((b) => b.kind.equals(kind) & b.recordId.equals(id))).getSingleOrNull();

  Future<void> _setOutboxStatus(String kind, String id, String status) => db.customStatement(
      "UPDATE outbox SET status = ? WHERE status = 'pending' AND workspace_id = ? AND entity_type = ? AND entity_id = ?",
      [status, workspaceId, kind, id]);

  // --- push ------------------------------------------------------------------

  Future<int> _push() async {
    // Rows of things that never sync (a profile, a sync batch) are local.
    final kinds = recordKinds.map((k) => "'${k.name}'").join(',');
    await db.customStatement(
        "UPDATE outbox SET status = 'local' WHERE status = 'pending' AND entity_type NOT IN ($kinds)");
    final touched = await db.customSelect(
        "SELECT DISTINCT entity_type, entity_id FROM outbox WHERE status = 'pending' AND workspace_id = ? "
        "AND entity_type IN ($kinds) ORDER BY entity_type, entity_id",
        variables: [Variable<String>(workspaceId)]).get();

    final items = <(RecordPush, String, String, Row)>[];
    for (final t in touched) {
      final kind = t.read<String>('entity_type');
      final id = t.read<String>('entity_id');
      final row = await recordKindByName[kind]!.readOne(db, id);
      final base = await _base(kind, id);
      if (row == null || (base != null && base.version == row['version'])) {
        await _setOutboxStatus(kind, id, 'acked');
        continue;
      }
      final version = row['version'] as int;
      final sid = await sealer.serverId(kind, id);
      final sealed = await sealer.seal(sid, version, {
        'kind': kind,
        'id': id,
        'schemaVersion': AppDatabase.recordSchemaVersion,
        'row': row,
      });
      items.add((
        RecordPush(
          id: sid,
          base: base?.version,
          version: version,
          deleted: row['deletedAt'] != null,
          sealed: sealed,
          operationId: const Uuid().v5(_opNamespace, '$deviceId:$kind:$id:$version'),
        ),
        kind,
        id,
        row,
      ));
    }

    var conflicts = 0;
    for (var i = 0; i < items.length; i += maxPushBatch) {
      final batch = items.sublist(i, i + maxPushBatch > items.length ? items.length : i + maxPushBatch);
      conflicts += await _pushBatch(batch);
    }
    return conflicts;
  }

  Future<int> _pushBatch(List<(RecordPush, String, String, Row)> batch) async {
    PushResult result;
    try {
      result = await remote.push(workspaceId, deviceId, [for (final b in batch) b.$1]);
    } on RemoteFailure catch (e) {
      if (e.kind != RemoteFailureKind.refused || batch.length == 1) {
        if (e.kind == RemoteFailureKind.refused) {
          // The one record the server will not take: set aside, the rest goes on.
          await _setOutboxStatus(batch.single.$2, batch.single.$3, 'failed');
          _failed++;
          return 0;
        }
        rethrow;
      }
      // Find the record the server refuses; push the others one by one.
      var conflicts = 0;
      for (final b in batch) {
        conflicts += await _pushBatch([b]);
      }
      return conflicts;
    }
    await db.transaction(() async {
      for (final (push, kind, id, row) in batch) {
        if (!result.accepted.containsKey(push.id)) continue;
        await db.into(db.syncBase).insertOnConflictUpdate(SyncBaseCompanion.insert(
              kind: kind,
              recordId: id,
              version: push.version,
              data: jsonEncode(row),
              serverId: Value(push.id),
            ));
        await _setOutboxStatus(kind, id, 'acked');
        _pushed++;
      }
    });
    return result.conflicts.length;
  }

  // --- pull ------------------------------------------------------------------

  Future<void> _pull() async {
    while (true) {
      final cursor = (await _state())!.cursor;
      final page = await remote.pull(workspaceId, cursor, limit: pageSize);
      if (page.isEmpty) return;
      final changes = <Map<String, Object?>>[];
      final reviews = <Map<String, Object?>>[];
      var last = cursor;
      var stop = false;
      for (final s in page) {
        final step = await _take(s, changes, reviews);
        if (!step) {
          stop = true;
          break;
        }
        last = s.seq;
      }
      if (last != cursor || changes.isNotEmpty || reviews.isNotEmpty) await _apply(last, changes, reviews);
      if (stop || page.length < pageSize) return;
    }
  }

  /// Decides what one server change does here; false = stop the pull here
  /// (a change this app version cannot read yet).
  Future<bool> _take(SealedRecord s, List<Map<String, Object?>> changes, List<Map<String, Object?>> reviews) async {
    if (s.sealed == null) {
      final known = await (db.select(db.syncBase)..where((b) => b.serverId.equals(s.id))).getSingleOrNull();
      if (known != null) changes.add({'kind': known.kind, 'mode': 'purge', 'id': known.recordId, 'serverId': s.id});
      return true;
    }
    final Map<String, dynamic> env;
    try {
      env = await sealer.open(s.id, s.version, s.sealed!);
    } on SealBroken {
      reviews.add({'kind': '?', 'recordId': s.id, 'field': '*', 'kept': null, 'other': null, 'reason': 'unreadable'});
      return true;
    }
    final kindName = env['kind'];
    final kind = kindName is String ? recordKindByName[kindName] : null;
    final schema = env['schemaVersion'];
    if (kind == null || schema is! int || schema > AppDatabase.recordSchemaVersion) {
      _updateNeeded = true;
      return false;
    }
    final id = env['id'] as String;
    final remoteRow = (env['row'] as Map).cast<String, dynamic>();
    final base = await _base(kind.name, id);
    if (base != null && base.version == s.version) return true; // this device's own push, or already here
    _pulled++;
    final local = await kind.readOne(db, id);
    final unchangedHere = local == null || (base != null && local['version'] == base.version);
    if (unchangedHere) {
      changes.add({'kind': kind.name, 'mode': 'remote', 'row': remoteRow, 'serverId': s.id});
      return true;
    }
    final m = mergeRecord(kind.name, base == null ? null : (jsonDecode(base.data) as Map).cast<String, dynamic>(),
        local, remoteRow, localDevice: deviceId, remoteDevice: s.deviceId);
    _merged++;
    changes.add({'kind': kind.name, 'mode': 'merged', 'row': m.row, 'base': remoteRow, 'serverId': s.id});
    for (final r in m.reviews) {
      _reviews++;
      reviews.add({
        'kind': kind.name,
        'recordId': id,
        'field': r.field,
        'kept': r.kept,
        'other': r.other,
        'reason': r.reason == SyncReviewReason.changedOnBoth ? 'changedOnBoth' : 'deletedAndEdited',
      });
    }
    return true;
  }

  Future<void> _apply(int cursor, List<Map<String, Object?>> changes, List<Map<String, Object?>> reviews) async {
    final r = await gateway.execute(
      Command(
        operationId: const Uuid().v7(),
        actor: ActorRef(ActorKind.sync, deviceId),
        workspaceId: workspaceId,
        type: syncApplyAction,
        payload: {'op': 'apply', 'id': workspaceId, 'cursor': cursor, 'changes': changes, 'reviews': reviews},
        issuedAt: Instant(clock().toUtc()),
      ),
      const SyncApplyHandler(),
    );
    if (r is! CommandOk) throw RemoteFailure(RemoteFailureKind.refused, 'applying pulled changes failed: $r');
  }
}
