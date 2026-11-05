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
  });

  final String operationId;
  final ActorRef actor;
  final String workspaceId;
  final String type;
  final Map<String, Object?> payload;
  final Version? expectedVersion;
  final Instant issuedAt;
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
