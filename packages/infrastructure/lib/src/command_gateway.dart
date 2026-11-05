import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Drift-backed transaction context passed to handlers. Exposes the active
/// transactional database so a handler's repository can read/write the
/// aggregate inside the gateway transaction.
class DriftTx implements TxContext {
  DriftTx(this.db);
  final AppDatabase db;
}

/// In-process event handler invoked AFTER commit (transactional-outbox).
typedef EventSink = Future<void> Function(DomainEvent event);

/// The single mutation path (ADR-0011) with the atomic transactional set
/// (ADR-0014): aggregate change + audit + outbox + event-log + dedupe commit in
/// ONE Drift transaction; events dispatch after commit from the durable log.
class DriftCommandGateway implements CommandGateway {
  DriftCommandGateway(this.db, this.authz, {this.onEvent});

  final AppDatabase db;
  final AuthorizationService authz;
  final EventSink? onEvent;
  final _uuid = const Uuid();

  @override
  Future<CommandResult> execute(Command cmd, CommandHandler handler) async {
    // 1. Idempotency (pre-transaction fast path).
    final existing = await (db.select(db.opDedupe)
          ..where((r) => r.operationId.equals(cmd.operationId)))
        .getSingleOrNull();
    if (existing != null) {
      return CommandFailure(CommandFailureKind.duplicateOperation,
          reason: 'operationId already applied');
    }

    // 2. Authorize BEFORE the domain method (LF-INV-GOV-002).
    final denied = await authz.denyReason(
      cmd.actor,
      cmd.type,
      ResourceRef(cmd.workspaceId, handler.entityType,
          (cmd.payload['id'] as String?) ?? ''),
    );
    if (denied != null) {
      return CommandFailure(CommandFailureKind.unauthorized, reason: denied);
    }

    CommandResult result = const CommandFailure(CommandFailureKind.validationFailed);
    final eventsToDispatch = <DomainEvent>[];

    // 3-7. One transaction: version check, apply, persist aggregate + audit +
    // outbox + event-log + dedupe. Any throw rolls back the whole set.
    try {
      await db.transaction(() async {
        final tx = DriftTx(db);

        // In-transaction version re-read + optimistic check (LF-INV-VER-001).
        final current = await handler.currentVersion(tx, cmd);
        if (cmd.expectedVersion != null &&
            (current == null || current.value != cmd.expectedVersion!.value)) {
          // Abort the transaction and surface a conflict.
          result = CommandFailure(CommandFailureKind.versionConflict,
              currentVersion: current);
          throw _AbortTx();
        }
        final newVersion =
            current == null ? Version.initial : current.next;

        // Apply the domain method within the transaction. A domain rule
        // rejection aborts the transaction and surfaces as validationFailed.
        final HandlerOutcome outcome;
        try {
          outcome = await handler.apply(tx, cmd, newVersion);
        } on DomainRejection catch (e) {
          result = CommandFailure(CommandFailureKind.validationFailed, reason: e.reason);
          throw _AbortTx();
        }

        final now = DateTime.now().toUtc();

        // Audit (LF-INV-AUDIT-001).
        await db.into(db.auditLog).insert(AuditLogCompanion.insert(
              auditId: _uuid.v7(),
              operationId: cmd.operationId,
              actor: cmd.actor.toString(),
              action: cmd.type,
              resourceType: handler.entityType,
              resourceId: outcome.entityId,
              versionBefore: Value(current?.value),
              versionAfter: Value(newVersion.value),
              outcome: 'applied',
              at: now,
            ));

        // Outbox (LF-INV-OUTBOX-001).
        await db.into(db.outbox).insert(OutboxCompanion.insert(
              operationId: cmd.operationId,
              entityId: outcome.entityId,
              entityType: handler.entityType,
              workspaceId: cmd.workspaceId,
              actorId: cmd.actor.toString(),
              operationType: outcome.operationType,
              baseVersion: Value(current?.value),
              payload: jsonEncode(outcome.changeSet),
              createdAt: now,
            ));

        // Event log (LF-INV-OUTBOX-002) — dispatched after commit.
        for (final ev in outcome.events) {
          await db.into(db.eventLog).insert(EventLogCompanion.insert(
                eventId: _uuid.v7(),
                operationId: cmd.operationId,
                eventType: ev.type,
                payload: jsonEncode(ev.payload),
                createdAt: now,
              ));
        }

        // Dedupe record — commits atomically with the change (LF-INV-GOV-003).
        await db.into(db.opDedupe).insert(OpDedupeCompanion.insert(
              operationId: cmd.operationId,
              workspaceId: cmd.workspaceId,
              resultSummary: '${outcome.operationType}:${outcome.entityId}:v${newVersion.value}',
              appliedAt: now,
            ));

        eventsToDispatch.addAll(outcome.events);
        result = CommandOk(outcome.entityId, newVersion, outcome.events);
      });
    } on _AbortTx {
      return result; // versionConflict, nothing persisted
    }

    // 8. Dispatch events AFTER commit (handler failure never rolls back).
    if (result is CommandOk) {
      await _dispatch(eventsToDispatch);
    }
    return result;
  }

  @override
  Future<void> dispatchPendingEvents() async {
    final pending = await (db.select(db.eventLog)
          ..where((r) => r.dispatched.equals(false))
          ..orderBy([(r) => OrderingTerm(expression: r.createdAt)]))
        .get();
    for (final row in pending) {
      await _deliver(DomainEvent(
          row.eventType, jsonDecode(row.payload) as Map<String, Object?>));
      await (db.update(db.eventLog)..where((r) => r.eventId.equals(row.eventId)))
          .write(const EventLogCompanion(dispatched: Value(true)));
    }
  }

  Future<void> _dispatch(List<DomainEvent> events) async {
    // Mark the just-written events dispatched and deliver them. On a crash
    // before this runs, dispatchPendingEvents() on next startup delivers them
    // (at-least-once; handlers must be idempotent).
    await dispatchPendingEvents();
  }

  Future<void> _deliver(DomainEvent ev) async {
    if (onEvent != null) await onEvent!(ev);
  }
}

class _AbortTx implements Exception {}
