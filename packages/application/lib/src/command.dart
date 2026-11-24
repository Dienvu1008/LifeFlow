import 'package:foundation/foundation.dart';

/// Command envelope (ADR-0011 / governance-kernel.md section 2).
class Command {
  Command({
    required this.operationId, // UUID v7, idempotency key
    required this.actor,
    required this.workspaceId,
    required this.type,
    required this.payload,
    this.expectedVersion, // required for updates, null for creates
    required this.issuedAt,
    this.aiProvenance,
  });

  final String operationId;
  final ActorRef actor;
  final String workspaceId;
  final String type;
  final Map<String, Object?> payload;
  final Version? expectedVersion;
  final Instant issuedAt;

  /// P06 T3 (ADR-0082, LF-INV-AI-003): for a change the person approved from
  /// an assistant's proposal, where it came from (the proposal, the change,
  /// the model, where it ran, who approved it). The gateway writes it into
  /// the audit row. The actor is still the person: they approved it.
  final Map<String, Object?>? aiProvenance;
}

/// Typed result of running a command through the gateway.
sealed class CommandResult {
  const CommandResult();
}

class CommandOk extends CommandResult {
  const CommandOk(this.entityId, this.newVersion, this.events);
  final String entityId;
  final Version newVersion;
  final List<DomainEvent> events;
}

enum CommandFailureKind {
  unauthorized,
  validationFailed,
  versionConflict,
  duplicateOperation,
  notFound,
  policyDenied,
}

class CommandFailure extends CommandResult {
  const CommandFailure(this.kind, {this.reason, this.currentVersion, this.previous});
  final CommandFailureKind kind;
  final String? reason;
  final Version? currentVersion; // for versionConflict
  final CommandResult? previous; // for duplicateOperation (the stored result)
}

/// A domain event (past tense fact). Payload is opaque to the kernel.
class DomainEvent {
  const DomainEvent(this.type, this.payload);
  final String type;
  final Map<String, Object?> payload;
}

/// Thrown by a [CommandHandler] when a domain rule rejects the command (e.g. an
/// invalid status transition, a hierarchy cycle, or exceeding max depth). The
/// gateway catches it, rolls back the transaction, and returns a
/// [CommandFailure] with kind [CommandFailureKind.validationFailed].
class DomainRejection implements Exception {
  DomainRejection(this.reason);
  final String reason;
  @override
  String toString() => 'DomainRejection: $reason';
}
