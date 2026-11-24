// P06 T3 (ADR-0082; ADR-0080; the owner's D7, D8): the assistant's history
// as records, through the gateway like every change (FF-ARCH-06).
//
// AiSessionHandler (the session is the aggregate; its messages and proposals
// are written in the same transaction, each with its own outbox row):
//   create           id, title, purpose
//   rename           id, title
//   trash / restore  id (its messages and proposals go and come back with it)
//   addMessage       id, messageId, role, text, model?, site?, sentRefs?
//   addProposal      id, proposalId, model, site, changes (encoded, every one
//                    proposed), messageId?, note?
//
// AiProposalHandler: what became of a change that did not run
//   record           id (the proposal), changeId, status (dismissed | stale |
//                    failed), reason?, approvedBy?, approvedAt?
//
// AiApprovedChangeHandler: an approved change, run by the gateway as the
// person's own command (the target's handler), and the proposal marked
// applied in the SAME transaction: either both are written or neither.
//
// The assistant works in the personal space only (p06-plan D7).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'record_kinds.dart' show recordKindByName;

const maxAiTitleLength = 120;
const maxAiMessageLength = 32000;
const maxAiChanges = 50;

/// The reason of a refusal because a thing changed since the proposal
/// (read by the service as "stale", LF-INV-AI-002).
const aiStaleReason = 'stale: a thing it was computed against changed';

String _id(Command cmd, String key) {
  final v = cmd.payload[key];
  if (v is! String || v.isEmpty) throw DomainRejection('$key is needed');
  return v;
}

String _title(Command cmd) {
  final t = (cmd.payload['title'] as String?)?.trim() ?? '';
  if (t.isEmpty || t.length > maxAiTitleLength) throw DomainRejection('a title is 1 to $maxAiTitleLength characters');
  return t;
}

Future<void> _outbox(
        AppDatabase db, Command cmd, String type, String id, String op, int? base, Object row, DateTime now) =>
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

/// The person's own personal workspace: the only place of the assistant.
Future<void> _checkPersonal(AppDatabase db, Command cmd) async {
  if (cmd.actor.kind != ActorKind.owner) throw DomainRejection('only the person writes their assistant history');
  final ws = await (db.select(db.workspaces)..where((w) => w.id.equals(cmd.workspaceId))).getSingleOrNull();
  if (ws == null || ws.kind != 'personal') throw DomainRejection('the assistant works in the personal space only');
}

/// The live version of [ref] in [workspaceId] now, or null (gone, trashed,
/// elsewhere, or a kind with no records).
Future<int?> liveVersionOf(AppDatabase db, String workspaceId, RecordRef ref) async {
  final kind = recordKindByName[ref.kind];
  if (kind == null) return null;
  final row = await kind.readOne(db, ref.id);
  if (row == null || row['deletedAt'] != null || row['workspaceId'] != workspaceId) return null;
  return row['version'] as int;
}

class AiSessionHandler implements CommandHandler {
  const AiSessionHandler({this.clock = const SystemClock()});
  final Clock clock;

  @override
  String get entityType => 'aiSession';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row =
        await (db.select(db.aiSessions)..where((s) => s.id.equals(cmd.payload['id'] as String))).getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String?;
    final id = _id(cmd, 'id');
    final now = clock.now().utc;
    await _checkPersonal(db, cmd);
    final session = await (db.select(db.aiSessions)..where((s) => s.id.equals(id))).getSingleOrNull();

    HandlerOutcome outcome(String type, Map<String, Object?> change, String event) =>
        HandlerOutcome(entityId: id, operationType: type, changeSet: {
          'id': id,
          ...change
        }, events: [
          DomainEvent(event, {'id': id})
        ]);

    Future<void> write(AiSessionsCompanion change) => (db.update(db.aiSessions)..where((s) => s.id.equals(id)))
        .write(change.copyWith(version: Value(newVersion.value), updatedAt: Value(now)));

    if (op == 'create') {
      if (session != null) throw DomainRejection('the session already exists');
      final purpose = cmd.payload['purpose'];
      if (!AiPurpose.values.any((p) => p.name == purpose)) throw DomainRejection('an unknown purpose');
      final title = _title(cmd);
      await db.into(db.aiSessions).insert(AiSessionsCompanion.insert(
            id: id,
            workspaceId: cmd.workspaceId,
            ownerId: cmd.actor.id,
            createdAt: now,
            updatedAt: now,
            version: Value(newVersion.value),
            title: title,
            purpose: purpose as String,
          ));
      return outcome('create', {'title': title, 'purpose': purpose}, 'AiSessionStarted');
    }

    if (session == null || session.workspaceId != cmd.workspaceId) throw DomainRejection('session not found');

    if (op == 'restore') {
      if (session.deletedAt == null) throw DomainRejection('the session is not in the trash');
      final at = session.deletedAt!;
      await write(const AiSessionsCompanion(deletedAt: Value(null), deletedBy: Value(null)));
      for (final m
          in await (db.select(db.aiMessages)..where((m) => m.sessionId.equals(id) & m.deletedAt.equals(at))).get()) {
        final next = m.copyWith(
            deletedAt: const Value(null), deletedBy: const Value(null), version: m.version + 1, updatedAt: now);
        await db.into(db.aiMessages).insertOnConflictUpdate(next.toCompanion(false));
        await _outbox(db, cmd, 'aiMessage', m.id, 'update', m.version, next.toJson(), now);
      }
      for (final p
          in await (db.select(db.aiProposals)..where((p) => p.sessionId.equals(id) & p.deletedAt.equals(at))).get()) {
        final next = p.copyWith(
            deletedAt: const Value(null), deletedBy: const Value(null), version: p.version + 1, updatedAt: now);
        await db.into(db.aiProposals).insertOnConflictUpdate(next.toCompanion(false));
        await _outbox(db, cmd, 'aiProposal', p.id, 'update', p.version, next.toJson(), now);
      }
      return outcome('update', {'tombstone': false}, 'AiSessionRestored');
    }
    if (session.deletedAt != null) throw DomainRejection('the session is in the trash');

    switch (op) {
      case 'rename':
        final title = _title(cmd);
        if (title == session.title) throw DomainRejection('already so');
        await write(AiSessionsCompanion(title: Value(title)));
        return outcome('update', {'title': title}, 'AiSessionRenamed');

      case 'trash':
        // Its messages and proposals go with it, at the same time, so a
        // restore brings back exactly those.
        final by = cmd.actor.toString();
        await write(AiSessionsCompanion(deletedAt: Value(now), deletedBy: Value(by)));
        for (final m
            in await (db.select(db.aiMessages)..where((m) => m.sessionId.equals(id) & m.deletedAt.isNull())).get()) {
          final next = m.copyWith(deletedAt: Value(now), deletedBy: Value(by), version: m.version + 1, updatedAt: now);
          await db.into(db.aiMessages).insertOnConflictUpdate(next.toCompanion(false));
          await _outbox(db, cmd, 'aiMessage', m.id, 'delete', m.version, next.toJson(), now);
        }
        for (final p
            in await (db.select(db.aiProposals)..where((p) => p.sessionId.equals(id) & p.deletedAt.isNull())).get()) {
          final next = p.copyWith(deletedAt: Value(now), deletedBy: Value(by), version: p.version + 1, updatedAt: now);
          await db.into(db.aiProposals).insertOnConflictUpdate(next.toCompanion(false));
          await _outbox(db, cmd, 'aiProposal', p.id, 'delete', p.version, next.toJson(), now);
        }
        return outcome('delete', {'tombstone': true}, 'AiSessionTrashed');

      case 'addMessage':
        final mid = _id(cmd, 'messageId');
        if (await (db.select(db.aiMessages)..where((m) => m.id.equals(mid))).getSingleOrNull() != null) {
          throw DomainRejection('a message is written once');
        }
        final role = cmd.payload['role'];
        if (!AiMessageRole.values.any((r) => r.name == role)) throw DomainRejection('an unknown role');
        final text = cmd.payload['text'];
        if (text is! String || text.trim().isEmpty || text.length > maxAiMessageLength) {
          throw DomainRejection('a message is 1 to $maxAiMessageLength characters');
        }
        final model = cmd.payload['model'] as String?;
        final site = cmd.payload['site'] as String?;
        if (site != null && !AiEngineSite.values.any((s) => s.name == site)) throw DomainRejection('an unknown site');
        if (role == AiMessageRole.person.name && (model != null || site != null)) {
          throw DomainRejection("a person's message has no model");
        }
        final refs = cmd.payload['sentRefs'] ?? const [];
        if (refs is! List ||
            refs.any((r) =>
                r is! Map ||
                r['kind'] is! String ||
                r['id'] is! String ||
                (r['version'] != null && r['version'] is! int))) {
          throw DomainRejection('sent refs are {kind, id, version}');
        }
        final row = AiMessageRow(
          id: mid,
          workspaceId: cmd.workspaceId,
          ownerId: session.ownerId,
          version: 1,
          createdAt: now,
          updatedAt: now,
          sessionId: id,
          role: role as String,
          body: text,
          model: model,
          site: site,
          sentRefs: jsonEncode(refs),
        );
        await db.into(db.aiMessages).insert(row.toCompanion(false));
        await _outbox(db, cmd, 'aiMessage', mid, 'create', null, row.toJson(), now);
        await write(const AiSessionsCompanion());
        return outcome('update', {'messageId': mid}, 'AiMessageAdded');

      case 'addProposal':
        final pid = _id(cmd, 'proposalId');
        if (await (db.select(db.aiProposals)..where((p) => p.id.equals(pid))).getSingleOrNull() != null) {
          throw DomainRejection('the proposal already exists');
        }
        final mid = cmd.payload['messageId'] as String?;
        if (mid != null) {
          final m = await (db.select(db.aiMessages)..where((m) => m.id.equals(mid))).getSingleOrNull();
          if (m == null || m.sessionId != id || m.deletedAt != null) throw DomainRejection('message not found');
        }
        final model = cmd.payload['model'];
        final site = cmd.payload['site'];
        if (model is! String || model.isEmpty) throw DomainRejection('the model is needed');
        if (!AiEngineSite.values.any((s) => s.name == site)) throw DomainRejection('an unknown site');
        final raw = cmd.payload['changes'];
        final List<AiChangeRecord> changes;
        try {
          changes = decodeAiChanges(raw as String);
          // Unique change ids (the domain's proposal says so).
          AiProposal(
              id: pid,
              sessionId: id,
              model: model,
              createdAt: Instant(now),
              changes: [for (final c in changes) c.change]);
        } catch (_) {
          throw DomainRejection('the changes cannot be read');
        }
        if (changes.isEmpty || changes.length > maxAiChanges)
          throw DomainRejection('a proposal has 1 to $maxAiChanges changes');
        if (changes.any((c) => c.status != AiChangeStatus.proposed))
          throw DomainRejection('a new proposal is only proposed');
        final note = cmd.payload['note'] as String? ?? '';
        if (note.length > maxAiMessageLength) throw DomainRejection('the note is too long');
        final row = AiProposalRow(
          id: pid,
          workspaceId: cmd.workspaceId,
          ownerId: session.ownerId,
          version: 1,
          createdAt: now,
          updatedAt: now,
          sessionId: id,
          messageId: mid,
          model: model,
          site: site as String,
          changes: encodeAiChanges(changes),
          note: note,
        );
        await db.into(db.aiProposals).insert(row.toCompanion(false));
        await _outbox(db, cmd, 'aiProposal', pid, 'create', null, row.toJson(), now);
        await write(const AiSessionsCompanion());
        return outcome('update', {'proposalId': pid}, 'AiProposalAdded');
    }
    throw DomainRejection('unknown op: $op');
  }
}

/// A live proposal of a live session in the command's workspace, and its
/// change [changeId], still proposed.
Future<(AiProposalRow, List<AiChangeRecord>, int)> _proposedChange(
    AppDatabase db, Command cmd, String proposalId, String changeId) async {
  final p = await (db.select(db.aiProposals)..where((p) => p.id.equals(proposalId))).getSingleOrNull();
  if (p == null || p.workspaceId != cmd.workspaceId || p.deletedAt != null) throw DomainRejection('proposal not found');
  final changes = decodeAiChanges(p.changes);
  final at = changes.indexWhere((c) => c.change.id == changeId);
  if (at < 0) throw DomainRejection('change not found');
  if (changes[at].status != AiChangeStatus.proposed)
    throw DomainRejection('the change is already ${changes[at].status.name}');
  return (p, changes, at);
}

class AiProposalHandler implements CommandHandler {
  const AiProposalHandler({this.clock = const SystemClock()});
  final Clock clock;

  @override
  String get entityType => 'aiProposal';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row =
        await (db.select(db.aiProposals)..where((p) => p.id.equals(cmd.payload['id'] as String))).getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    if (cmd.payload['op'] != 'record') throw DomainRejection('unknown op: ${cmd.payload['op']}');
    await _checkPersonal(db, cmd);
    final id = _id(cmd, 'id');
    final changeId = _id(cmd, 'changeId');
    final status = AiChangeStatus.values.where((s) => s.name == cmd.payload['status']).firstOrNull;
    // Applied is written only with the change itself (AiApprovedChangeHandler).
    if (status == null || status == AiChangeStatus.proposed || status == AiChangeStatus.applied) {
      throw DomainRejection('a change is recorded dismissed, stale or failed here');
    }
    final (p, changes, at) = await _proposedChange(db, cmd, id, changeId);
    final approvedAt = cmd.payload['approvedAt'];
    changes[at] = changes[at].withOutcome(status,
        reason: cmd.payload['reason'] as String?,
        approvedBy: cmd.payload['approvedBy'] as String?,
        approvedAt: approvedAt is int ? Instant.fromMillis(approvedAt) : null);
    await (db.update(db.aiProposals)..where((x) => x.id.equals(p.id))).write(AiProposalsCompanion(
        changes: Value(encodeAiChanges(changes)), version: Value(newVersion.value), updatedAt: Value(clock.now().utc)));
    return HandlerOutcome(
      entityId: id,
      operationType: 'update',
      changeSet: {'id': id, 'changeId': changeId, 'status': status.name},
      events: [
        DomainEvent('AiChangeRecorded', {'id': id, 'changeId': changeId, 'status': status.name})
      ],
    );
  }
}

/// An approved change (ADR-0080): the target's own command, run by the
/// gateway as the person, and the proposal marked applied in the same
/// transaction. Every thing the change was computed against is read again
/// inside the transaction: one that moved makes it stale, nothing written.
class AiApprovedChangeHandler implements CommandHandler {
  const AiApprovedChangeHandler(this.inner,
      {required this.proposalId, required this.changeId, required this.versions, this.clock = const SystemClock()});

  /// The target's handler (the tool's).
  final CommandHandler inner;
  final String proposalId;
  final String changeId;

  /// The versions the approval holds (approved == proposed, checked before).
  final Map<RecordRef, int> versions;
  final Clock clock;

  @override
  String get entityType => inner.entityType;

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) => inner.currentVersion(tx, cmd);

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    await _checkPersonal(db, cmd);
    final (p, changes, at) = await _proposedChange(db, cmd, proposalId, changeId);
    for (final MapEntry(key: ref, value: v) in versions.entries) {
      if (await liveVersionOf(db, cmd.workspaceId, ref) != v) throw DomainRejection(aiStaleReason);
    }
    // The one place a handler's apply is called outside the gateway: from
    // inside it, in its transaction (FF-ARCH-06 guard 2 allows this file).
    final outcome = await inner.apply(tx, cmd, newVersion);
    final now = clock.now().utc;
    final approvedAt = cmd.aiProvenance?['approvedAt'];
    changes[at] = changes[at].withOutcome(AiChangeStatus.applied,
        approvedBy: cmd.actor.id,
        approvedAt: approvedAt is int ? Instant.fromMillis(approvedAt) : Instant(now),
        operationId: cmd.operationId);
    final next = p.copyWith(changes: encodeAiChanges(changes), version: p.version + 1, updatedAt: now);
    await db.into(db.aiProposals).insertOnConflictUpdate(next.toCompanion(false));
    await _outbox(db, cmd, 'aiProposal', p.id, 'update', p.version, next.toJson(), now);
    return HandlerOutcome(
      entityId: outcome.entityId,
      operationType: outcome.operationType,
      changeSet: outcome.changeSet,
      events: [
        ...outcome.events,
        DomainEvent('AiChangeApplied', {'id': proposalId, 'changeId': changeId})
      ],
    );
  }
}
