// P04 T5 (ADR-0058; p04-plan.md D6, D7, D9): closing a "Changes to review"
// item, as a command through the gateway (GOV-001).
//   keep   what the merge kept stays; the item is closed
//   other  the value that gave way is put back on the record as a new change
//          (version + 1, an outbox row pending), so it syncs like any edit
// Only a value changed on both devices can be taken back. A delete against
// an edit is in the trash with the edits (D7): restoring it from the trash
// is the way back, so that item can only be closed. Neither can an
// unreadable record's.
// Payload: {op: 'resolve', id: the review item, take: 'kept' | 'other'}
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show DocumentBody, syncMetaFields;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../command_gateway.dart';
import '../record_kinds.dart';

const resolveSyncReviewAction = 'ResolveSyncReview';

class SyncReviewHandler implements CommandHandler {
  const SyncReviewHandler();

  @override
  String get entityType => 'syncReview';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async => null;

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final p = cmd.payload;
    if (p['op'] != 'resolve') throw DomainRejection('unknown op');
    final id = p['id'];
    final take = p['take'];
    if (id is! String || (take != 'kept' && take != 'other')) throw DomainRejection('bad review command');
    final review = await (db.select(db.syncReviews)..where((r) => r.id.equals(id))).getSingleOrNull();
    if (review == null || review.workspaceId != cmd.workspaceId) throw DomainRejection('no such review item');
    if (review.resolvedAt != null) throw DomainRejection('the review item is closed already');
    final now = DateTime.now().toUtc();

    var changed = false;
    if (take == 'other') {
      final kind = recordKindByName[review.kind];
      if (review.reason != 'changedOnBoth' || kind == null) {
        throw DomainRejection('the other value of this item cannot be taken');
      }
      final row = await kind.readOne(db, review.recordId);
      if (row == null || row['deletedAt'] != null) throw DomainRejection('the record is gone');
      final other = jsonDecode(review.other);
      final next = <String, dynamic>{...row};
      if (review.field == '*') {
        if (other is! Map) throw DomainRejection('the other value cannot be read');
        for (final e in other.entries) {
          if (!syncMetaFields.contains(e.key)) next[e.key as String] = e.value;
        }
      } else {
        if (syncMetaFields.contains(review.field) || !row.containsKey(review.field)) {
          throw DomainRejection('the other value cannot be read');
        }
        next[review.field] = other;
      }
      final base = row['version'] as int;
      next
        ..['version'] = base + 1
        ..['updatedAt'] = now.millisecondsSinceEpoch;
      try {
        kind.checkRows([next]);
        // P05a T4: a document's body taken back must be one this app reads.
        if (kind.name == 'document') DocumentBody.decode(next['body'] as String);
      } catch (_) {
        throw DomainRejection('the other value cannot be read');
      }
      await db.batch((b) => kind.upsert(b, db, [next]));
      await db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: review.recordId,
            entityType: kind.name,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: 'update',
            baseVersion: Value(base),
            payload: jsonEncode(next),
            createdAt: now,
          ));
      if (kind.name == 'document') {
        // P05a T4 (ADR-0069): a document's every change of content is a
        // revision (DOC-006); this one is the side of a conflict taken back.
        final rid = const Uuid().v7();
        await db.into(db.documentRevisions).insert(DocumentRevisionsCompanion.insert(
              id: rid,
              workspaceId: cmd.workspaceId,
              ownerId: next['ownerId'] as String,
              createdAt: now,
              updatedAt: now,
              documentId: review.recordId,
              documentVersion: base + 1,
              title: next['title'] as String,
              body: next['body'] as String,
              reason: const Value('conflict'),
            ));
        final rev = await (db.select(db.documentRevisions)..where((r) => r.id.equals(rid))).getSingle();
        await db.into(db.outbox).insert(OutboxCompanion.insert(
              operationId: cmd.operationId,
              entityId: rid,
              entityType: 'documentRevision',
              workspaceId: cmd.workspaceId,
              actorId: cmd.actor.toString(),
              operationType: 'create',
              payload: jsonEncode(rev.toJson()),
              createdAt: now,
            ));
      }
      changed = true;
    }
    await (db.update(db.syncReviews)..where((r) => r.id.equals(id))).write(SyncReviewsCompanion(resolvedAt: Value(now)));
    return HandlerOutcome(
      entityId: 'review:$id',
      operationType: 'update',
      changeSet: {'id': id, 'take': take},
      events: [
        DomainEvent('SyncReviewResolved', {'id': id, 'take': take, 'recordKind': review.kind, 'changed': changed})
      ],
    );
  }
}

/// A review value as text to show: a text as it is; for a whole value, the
/// fields that differ from [against], one per line.
String describeReviewValue(Object? value, {Object? against}) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map) {
    final lines = <String>[];
    for (final e in value.entries) {
      if (syncMetaFields.contains(e.key)) continue;
      if (against is Map && jsonEncode(against[e.key]) == jsonEncode(e.value)) continue;
      lines.add('${e.key}: ${e.value is String ? e.value : jsonEncode(e.value)}');
    }
    return lines.join('\n');
  }
  return jsonEncode(value);
}
