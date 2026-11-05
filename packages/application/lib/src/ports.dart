import 'package:foundation/foundation.dart';

import 'command.dart';

/// Authorization port (owned by Workspace and Access; evaluated BEFORE the
/// domain method runs — LF-INV-GOV-002). MVP policy: owner of the workspace.
abstract interface class AuthorizationService {
  /// Returns null if allowed, or a reason string if denied.
  Future<String?> denyReason(ActorRef actor, String action, ResourceRef ref);
}

class ResourceRef {
  const ResourceRef(this.workspaceId, this.entityType, this.entityId);
  final String workspaceId;
  final String entityType;
  final String entityId;
}

/// What a command does to its aggregate, run INSIDE the gateway transaction
/// after authorization + the in-transaction version check. The handler must be
/// pure w.r.t. side effects other than the writes it returns: it reads/writes
/// the aggregate via [tx] and returns the outcome for the kernel to finalize.
abstract interface class CommandHandler {
  /// The entity type this handler owns (for audit/outbox/resource ref).
  String get entityType;

  /// The current version of the target aggregate, read INSIDE the transaction,
  /// or null if the target does not exist yet (a create).
  Future<Version?> currentVersion(TxContext tx, Command cmd);

  /// Apply the command to the aggregate within [tx] at [newVersion], returning
  /// the entity id, the change set for the outbox, and the domain events.
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion);
}

/// An opaque transaction context handed to handlers; the infrastructure
/// implementation backs it with a Drift transaction. Handlers use it via
/// context-specific repository ports (added per context); here it is a marker
/// so the application layer does not depend on Drift.
abstract interface class TxContext {}

class HandlerOutcome {
  const HandlerOutcome({
    required this.entityId,
    required this.operationType, // create/update/delete
    required this.changeSet, // JSON-able payload for the outbox
    required this.events,
  });
  final String entityId;
  final String operationType;
  final Map<String, Object?> changeSet;
  final List<DomainEvent> events;
}

/// The single mutation path (ADR-0011). UI/AI/sync all go through this.
abstract interface class CommandGateway {
  Future<CommandResult> execute(Command cmd, CommandHandler handler);

  /// Dispatch undispatched event-log rows to in-process handlers (after commit,
  /// transactional-outbox pattern, ADR-0014). Idempotent; safe to call on
  /// startup to drain events a crash left undispatched.
  Future<void> dispatchPendingEvents();
}
