// P04 T3 (ADR-0056): pulled changes enter the store as ONE command of actor
// `sync` through the gateway (GOV-001, FF-ARCH-06/09): the records of a
// page, their last synced copies, the review items and the new cursor commit
// together, so a crash keeps either all of a page or none of it, and the
// next pull starts where the store is.
//   remote  the server's copy, taken as it is: written with an outbox row
//           already acked (it came from the server; nothing to push)
//   merged  this device's change and the server's merged (mergeRecord): an
//           outbox row pending, so the merge is pushed on top
//   purge   the server dropped a deleted record's content: the row goes here
//           too (GS-14)
// Payload: {op: 'apply', id: workspaceId, cursor, changes: [{kind, mode,
// row?, id?, base?, serverId}], reviews: [{kind, recordId, field, kept,
// other, reason}]}
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../command_gateway.dart';
import '../record_kinds.dart';

const syncApplyAction = 'ApplySyncChanges';

class SyncApplyHandler implements CommandHandler {
  const SyncApplyHandler();

  @override
  String get entityType => 'syncBatch';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async => null;

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final p = cmd.payload;
    if (p['op'] != 'apply' || p['id'] != cmd.workspaceId) throw DomainRejection('not a sync batch of this workspace');
    final cursor = p['cursor'];
    if (cursor is! int || cursor < 0) throw DomainRejection('bad cursor');
    final changes = [for (final c in (p['changes'] as List? ?? const [])) (c as Map).cast<String, dynamic>()];
    final order = {for (final (i, k) in recordKinds.indexed) k.name: i};
    changes.sort((a, b) => (order[a['kind']] ?? 99).compareTo(order[b['kind']] ?? 99));
    final now = DateTime.now().toUtc();
    var written = 0, purged = 0;

    for (final c in changes) {
      final kind = recordKindByName[c['kind']];
      if (kind == null) throw DomainRejection('unknown record kind');
      final mode = c['mode'];
      final serverId = c['serverId'] as String?;
      if (mode == 'purge') {
        final id = c['id'] as String;
        await db.customStatement('DELETE FROM ${kind.tableName} WHERE id = ?', [id]);
        await (db.delete(db.syncBase)..where((b) => b.kind.equals(kind.name) & b.recordId.equals(id))).go();
        purged++;
        continue;
      }
      if (mode != 'remote' && mode != 'merged') throw DomainRejection('unknown change mode');
      final row = (c['row'] as Map).cast<String, dynamic>();
      final base = ((c['base'] ?? c['row']) as Map).cast<String, dynamic>();
      try {
        kind.checkRows([row, base]);
      } catch (_) {
        throw DomainRejection('a pulled record cannot be read');
      }
      if (row['workspaceId'] != cmd.workspaceId) throw DomainRejection('a pulled record of another workspace');
      await db.batch((b) => kind.upsert(b, db, [row]));
      // Every written record has an outbox row of its own (ADR-0053).
      await db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: row['id'] as String,
            entityType: kind.name,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: 'update',
            baseVersion: Value(base['version'] as int?),
            payload: jsonEncode(row),
            createdAt: now,
            status: Value(mode == 'remote' ? 'acked' : 'pending'),
          ));
      await db.into(db.syncBase).insertOnConflictUpdate(SyncBaseCompanion.insert(
            kind: kind.name,
            recordId: row['id'] as String,
            version: base['version'] as int,
            data: jsonEncode(base),
            serverId: Value(serverId),
          ));
      written++;
    }

    var reviews = 0;
    for (final r in (p['reviews'] as List? ?? const [])) {
      final m = (r as Map).cast<String, dynamic>();
      await db.into(db.syncReviews).insert(SyncReviewsCompanion.insert(
            id: const Uuid().v7(),
            workspaceId: cmd.workspaceId,
            kind: m['kind'] as String,
            recordId: m['recordId'] as String,
            field: m['field'] as String,
            kept: jsonEncode(m['kept']),
            other: jsonEncode(m['other']),
            reason: m['reason'] as String,
            createdAt: now,
          ));
      reviews++;
    }

    final updated = await (db.update(db.syncState)..where((s) => s.workspaceId.equals(cmd.workspaceId)))
        .write(SyncStateCompanion(cursor: Value(cursor), lastSyncAt: Value(now)));
    if (updated != 1) throw DomainRejection('this workspace is not synced on this device');

    return HandlerOutcome(
      // Not the workspace id itself: a pulled settings record has that id
      // and an outbox row under this operation.
      entityId: 'sync:${cmd.workspaceId}',
      operationType: 'update',
      changeSet: {'cursor': cursor, 'written': written, 'purged': purged, 'reviews': reviews},
      events: [
        DomainEvent('SyncApplied', {'workspaceId': cmd.workspaceId, 'written': written, 'purged': purged, 'reviews': reviews})
      ],
    );
  }
}
