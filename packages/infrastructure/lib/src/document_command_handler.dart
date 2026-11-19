// P05a T3 (ADR-0068; p05-plan C5, C7, C8; document-knowledge.md §8): the
// document commands. The document is the aggregate: its revisions and links
// are written in the same gateway transaction, each with its own outbox row
// (LF-INV-OUTBOX-001), and the document's version moves.
//
//   create           id, title, revisionId, firstBlockId, parentId?, afterId?
//   save             id, revisionId, title, body (an encoded body), deviceId?
//   move             id, parentId?, afterId?
//   trash / restore  id (a document goes with its subdocuments, and comes back
//                    with the ones that went with it)
//   restoreRevision  id, revisionId (the new one), fromRevisionId
//   link / unlink    id, itemType (task|event|goal), itemId
//
// Every save writes exactly one revision with the whole title and body; a
// revision is written once and never changed (DOC-002, DOC-006).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'organize_ops.dart' show Keyed, keyAfter, keyAtEnd;

/// The id of a document's link to a task, an event or a goal.
String documentLinkIdOf(String documentId, String itemType, String itemId) => '$documentId|$itemType:$itemId';

const documentItemTypes = {'task', 'event', 'goal'};

String _title(Command cmd) {
  final t = (cmd.payload['title'] as String?)?.trim() ?? '';
  final why = documentTitleError(t);
  if (why != null) throw DomainRejection(why);
  return t;
}

/// The body as stored: read, checked and written again in the fixed form,
/// so the same content is always the same bytes (ADR-0066).
String _body(Object? raw) {
  if (raw is! String) throw DomainRejection('a body is needed');
  final DocumentBody body;
  try {
    body = DocumentBody.decode(raw);
  } on FormatException catch (e) {
    throw DomainRejection('the body cannot be read: ${e.message}');
  }
  final why = body.validate();
  if (why != null) throw DomainRejection(why);
  return body.encode();
}

String _id(Command cmd, String key) {
  final v = cmd.payload[key];
  if (v is! String || v.isEmpty) throw DomainRejection('$key is needed');
  return v;
}

class DocumentCommandHandler implements CommandHandler {
  const DocumentCommandHandler({this.clock = const SystemClock()});
  final Clock clock;

  @override
  String get entityType => 'document';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.documents)..where((d) => d.id.equals(cmd.payload['id'] as String))).getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  Future<void> _outbox(AppDatabase db, Command cmd, String type, String id, String op, int? base, Object row, DateTime now) =>
      db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: id,
            entityType: type,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: op,
            baseVersion: Value(base),
            payload: jsonEncode(row),
            createdAt: now,
          ));

  Future<List<Keyed>> _siblings(AppDatabase db, String ws, String? parentId, {String? exclude}) async {
    final rows = await (db.select(db.documents)
          ..where((d) =>
              d.workspaceId.equals(ws) &
              d.deletedAt.isNull() &
              (parentId == null ? d.parentId.isNull() : d.parentId.equals(parentId))))
        .get();
    final out = [for (final d in rows) if (d.id != exclude) (id: d.id, key: d.orderKey)];
    return out..sort((a, b) => a.key == b.key ? a.id.compareTo(b.id) : a.key.compareTo(b.key));
  }

  /// A live parent of the same workspace, and no cycle (DOC-001).
  Future<void> _checkParent(AppDatabase db, String ws, String? id, String? parentId) async {
    if (parentId == null) return;
    final chain = <String>{};
    String? at = parentId;
    while (at != null && chain.add(at)) {
      final p = await (db.select(db.documents)..where((d) => d.id.equals(at!))).getSingleOrNull();
      if (p == null || p.workspaceId != ws) throw DomainRejection('the parent document is not here');
      if (at == parentId && p.deletedAt != null) throw DomainRejection('the parent document is in the trash');
      at = p.parentId;
    }
    if (id != null) {
      final why = DocumentTreeRules.moveError(docId: id, newParentId: parentId, newParentAncestorsIncludingSelf: chain);
      if (why != null) throw DomainRejection(why);
    }
  }

  /// The document and every live subdocument under it, at any depth.
  Future<List<DocumentRow>> _subtree(AppDatabase db, DocumentRow root, {DateTime? trashedAt}) async {
    final out = [root];
    for (var i = 0; i < out.length; i++) {
      final kids = await (db.select(db.documents)
            ..where((d) =>
                d.parentId.equals(out[i].id) &
                d.workspaceId.equals(root.workspaceId) &
                (trashedAt == null ? d.deletedAt.isNull() : d.deletedAt.equals(trashedAt))))
          .get();
      out.addAll(kids);
    }
    return out;
  }

  Future<DocumentRevisionRow> _revision(AppDatabase db, Command cmd, DocumentRow doc, String reason, DateTime now) async {
    final rid = _id(cmd, 'revisionId');
    if (await (db.select(db.documentRevisions)..where((r) => r.id.equals(rid))).getSingleOrNull() != null) {
      throw DomainRejection('a revision is written once');
    }
    final device = cmd.payload['deviceId'];
    final r = DocumentRevisionRow(
      id: rid,
      workspaceId: doc.workspaceId,
      ownerId: doc.ownerId,
      version: 1,
      createdAt: now,
      updatedAt: now,
      documentId: doc.id,
      documentVersion: doc.version,
      title: doc.title,
      body: doc.body,
      reason: reason,
      deviceId: device is String ? device : null,
    );
    await db.into(db.documentRevisions).insert(r.toCompanion(false));
    await _outbox(db, cmd, 'documentRevision', rid, 'create', null, r.toJson(), now);
    return r;
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = _id(cmd, 'id');
    final now = clock.now().utc;
    final ws = cmd.workspaceId;
    final doc = await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingleOrNull();

    HandlerOutcome outcome(String type, Map<String, Object?> change, String event, [Map<String, Object?>? extra]) =>
        HandlerOutcome(
            entityId: id, operationType: type, changeSet: {'id': id, ...change}, events: [DomainEvent(event, {'id': id, ...?extra})]);

    Future<DocumentRow> write(DocumentsCompanion change) async {
      await (db.update(db.documents)..where((d) => d.id.equals(id)))
          .write(change.copyWith(version: Value(newVersion.value), updatedAt: Value(now)));
      return (await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle());
    }

    if (op == 'create') {
      if (doc != null) throw DomainRejection('the document already exists');
      final title = _title(cmd);
      final parentId = cmd.payload['parentId'] as String?;
      await _checkParent(db, ws, null, parentId);
      final siblings = await _siblings(db, ws, parentId);
      final key = cmd.payload.containsKey('afterId') ? keyAfter(siblings, cmd.payload['afterId']) : keyAtEnd(siblings);
      final body = DocumentBody.empty(_id(cmd, 'firstBlockId')).encode();
      await db.into(db.documents).insert(DocumentsCompanion.insert(
            id: id,
            workspaceId: ws,
            ownerId: cmd.actor.id,
            createdAt: now,
            updatedAt: now,
            parentId: Value(parentId),
            title: title,
            body: body,
            orderKey: Value(key),
            version: Value(newVersion.value),
          ));
      final created = (await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle());
      final r = await _revision(db, cmd, created, 'save', now);
      return outcome('create', {'title': title, 'parentId': parentId}, 'DocumentCreated', {'revisionId': r.id});
    }

    if (doc == null || doc.workspaceId != ws) throw DomainRejection('document not found');

    if (op == 'restore') {
      if (doc.deletedAt == null) throw DomainRejection('the document is not in the trash');
      final gone = await _subtree(db, doc, trashedAt: doc.deletedAt);
      // Back where it was, unless its parent is not live: then at the top.
      String? parentId = doc.parentId;
      if (parentId != null) {
        final p = await (db.select(db.documents)..where((d) => d.id.equals(parentId!))).getSingleOrNull();
        if (p == null || p.deletedAt != null || p.workspaceId != ws) parentId = null;
      }
      await write(DocumentsCompanion(deletedAt: const Value(null), deletedBy: const Value(null), parentId: Value(parentId)));
      for (final sub in gone.skip(1)) {
        final next = sub.copyWith(deletedAt: const Value(null), deletedBy: const Value(null), version: sub.version + 1, updatedAt: now);
        await db.into(db.documents).insertOnConflictUpdate(next.toCompanion(false));
        await _outbox(db, cmd, 'document', sub.id, 'update', sub.version, next.toJson(), now);
      }
      return outcome('update', {'tombstone': false, 'with': gone.length - 1}, 'DocumentRestored');
    }
    if (doc.deletedAt != null) throw DomainRejection('the document is in the trash');

    switch (op) {
      case 'save':
        final title = _title(cmd);
        final body = _body(cmd.payload['body']);
        if (title == doc.title && body == doc.body) throw DomainRejection('nothing changed');
        final saved = await write(DocumentsCompanion(title: Value(title), body: Value(body)));
        final r = await _revision(db, cmd, saved, 'save', now);
        return outcome('update', {'title': title, 'revisionId': r.id}, 'DocumentRevised', {'revisionId': r.id});

      case 'restoreRevision':
        final from = _id(cmd, 'fromRevisionId');
        final old = await (db.select(db.documentRevisions)..where((r) => r.id.equals(from))).getSingleOrNull();
        if (old == null || old.documentId != id || old.deletedAt != null) throw DomainRejection('revision not found');
        if (old.title == doc.title && old.body == doc.body) throw DomainRejection('the document is already like this');
        final saved = await write(DocumentsCompanion(title: Value(old.title), body: Value(old.body)));
        final r = await _revision(db, cmd, saved, 'restore', now);
        return outcome('update', {'from': from, 'revisionId': r.id}, 'DocumentRevised', {'revisionId': r.id, 'restored': from});

      case 'move':
        final parentId = cmd.payload['parentId'] as String?;
        await _checkParent(db, ws, id, parentId);
        final key = keyAfter(await _siblings(db, ws, parentId, exclude: id), cmd.payload['afterId']);
        await write(DocumentsCompanion(parentId: Value(parentId), orderKey: Value(key)));
        return outcome('update', {'parentId': parentId, 'orderKey': key}, 'DocumentMoved');

      case 'trash':
        // Its subdocuments go with it, at the same time, so a restore brings
        // back exactly those (as a list with its tasks, ORDER-004).
        final all = await _subtree(db, doc);
        await write(DocumentsCompanion(deletedAt: Value(now), deletedBy: Value(cmd.actor.toString())));
        for (final sub in all.skip(1)) {
          final next = sub.copyWith(
              deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: sub.version + 1, updatedAt: now);
          await db.into(db.documents).insertOnConflictUpdate(next.toCompanion(false));
          await _outbox(db, cmd, 'document', sub.id, 'delete', sub.version, next.toJson(), now);
        }
        return outcome('delete', {'tombstone': true, 'with': all.length - 1}, 'DocumentTrashed');

      case 'link':
      case 'unlink':
        final type = cmd.payload['itemType'];
        final itemId = cmd.payload['itemId'] as String?;
        if (!documentItemTypes.contains(type) || itemId == null) throw DomainRejection('a task, an event or a goal is needed');
        final lid = documentLinkIdOf(id, type as String, itemId);
        final existing = await (db.select(db.documentLinks)..where((l) => l.id.equals(lid))).getSingleOrNull();
        final live = existing != null && existing.deletedAt == null;
        final DocumentLinkRow next;
        if (op == 'link') {
          if (live) throw DomainRejection('already linked');
          final (itemWs, trashed) = switch (type) {
            'task' => await (db.select(db.tasks)..where((t) => t.id.equals(itemId)))
                .getSingleOrNull()
                .then((t) => (t?.workspaceId, t?.deletedAt != null)),
            'event' => await (db.select(db.events)..where((e) => e.id.equals(itemId)))
                .getSingleOrNull()
                .then((e) => (e?.workspaceId, e?.deletedAt != null)),
            _ => await (db.select(db.goals)..where((g) => g.id.equals(itemId)))
                .getSingleOrNull()
                .then((g) => (g?.workspaceId, g?.deletedAt != null)),
          };
          if (itemWs == null || trashed) throw DomainRejection('$type not found');
          if (itemWs != ws) throw DomainRejection('the $type is in another workspace');
          next = existing == null
              ? DocumentLinkRow(
                  id: lid,
                  workspaceId: ws,
                  ownerId: doc.ownerId,
                  version: 1,
                  createdAt: now,
                  updatedAt: now,
                  documentId: id,
                  itemType: type,
                  itemId: itemId)
              : existing.copyWith(
                  deletedAt: const Value(null), deletedBy: const Value(null), version: existing.version + 1, updatedAt: now);
        } else {
          if (!live) throw DomainRejection('not linked');
          next = existing.copyWith(
              deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: existing.version + 1, updatedAt: now);
        }
        await db.into(db.documentLinks).insertOnConflictUpdate(next.toCompanion(false));
        await _outbox(db, cmd, 'documentLink', lid, op == 'unlink' ? 'delete' : (existing == null ? 'create' : 'update'),
            existing?.version, next.toJson(), now);
        await write(const DocumentsCompanion());
        return outcome('update', {'link': lid, 'change': op}, op == 'link' ? 'DocumentLinked' : 'DocumentUnlinked',
            {'itemType': type, 'itemId': itemId});
    }
    throw DomainRejection('unknown op: $op');
  }
}
