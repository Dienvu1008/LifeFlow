// P04 T2 (ADR-0052, ADR-0055): the sync server as a device sees it. Only
// sealed records cross this port (end-to-end encryption, p04-plan.md D12):
// ids are opaque, content is sealed bytes, the workspace key is wrapped.
// The implementations live in infrastructure (Supabase over HTTP, and one
// in memory with the same semantics for tests); a contract test runs the
// same cases against both.
import 'dart:typed_data';

/// One record as the server keeps it.
class SealedRecord {
  const SealedRecord({
    required this.id,
    required this.version,
    required this.seq,
    required this.deleted,
    required this.sealed,
    required this.deviceId,
  });

  /// 64 hex characters, made on the device.
  final String id;
  final int version;

  /// The workspace's change number of the record's last change.
  final int seq;
  final bool deleted;

  /// Null once purged: the tombstone stays (GS-14).
  final Uint8List? sealed;

  /// The device that made the last change.
  final String deviceId;
}

/// One change to push: accepted when [base] is the server's version (null
/// for a new record) and [version] is above it.
class RecordPush {
  const RecordPush({
    required this.id,
    required this.base,
    required this.version,
    required this.deleted,
    required this.sealed,
    required this.operationId,
  });
  final String id;
  final int? base;
  final int version;
  final bool deleted;
  final Uint8List sealed;

  /// The same for a retry of the same change, so a replay is accepted once.
  final String operationId;
}

class PushResult {
  const PushResult({required this.accepted, required this.conflicts});

  /// Server id -> change number given (or already given, for a replay).
  final Map<String, int> accepted;

  /// Server id -> the server's version (null: the device thought it new
  /// and it is not, or the other way round).
  final Map<String, int?> conflicts;
}

/// A synced workspace of the signed-in account, with its key wrapped by the
/// recovery key or the passphrase (D15).
class RemoteWorkspace {
  const RemoteWorkspace({
    required this.workspaceId,
    required this.wrappedKey,
    required this.unlockKind,
    this.unlockSalt,
    this.lastSeq = 0,
  });
  final String workspaceId;
  final Uint8List wrappedKey;

  /// 'recoveryKey' or 'passphrase'.
  final String unlockKind;
  final Uint8List? unlockSalt;
  final int lastSeq;
}

/// Why the server could not be used. [kind] decides what the app says.
class RemoteFailure implements Exception {
  const RemoteFailure(this.kind, [this.detail = '']);
  final RemoteFailureKind kind;

  /// For logs; never contains content or a token.
  final String detail;
  @override
  String toString() => 'RemoteFailure(${kind.name}) $detail';
}

enum RemoteFailureKind {
  /// No connection, a timeout, or the server is paused (free plan) or down.
  unavailable,

  /// Not signed in, or the session is no longer valid.
  signedOut,

  /// The workspace is not this account's (or does not exist).
  notYours,

  /// The server refused the request as malformed (a bug, not the user's).
  refused,
}

abstract interface class RemoteGateway {
  /// The signed-in account's synced workspaces.
  Future<List<RemoteWorkspace>> workspaces();

  /// Starts syncing a workspace under the signed-in account.
  Future<void> createWorkspace(RemoteWorkspace workspace);

  /// Re-wrapped key (the unlock method changed); nothing else changes.
  Future<void> updateWrappedKey(String workspaceId, Uint8List wrappedKey, String unlockKind, Uint8List? unlockSalt);

  /// "Delete my data from the server" (D11): the workspace and all its records.
  Future<void> deleteWorkspace(String workspaceId);

  /// At most 500 records per call.
  Future<PushResult> push(String workspaceId, String deviceId, List<RecordPush> records);

  /// Changes after [after], in change-number order, at most [limit] (≤ 1000).
  Future<List<SealedRecord>> pull(String workspaceId, int after, {int limit = 1000});

  /// Drops the content of records deleted before [before] (never within the
  /// 90-day retention); returns how many.
  Future<int> purge(String workspaceId, DateTime before);
}

/// The most records one push may carry.
const maxPushBatch = 500;

/// The most changes one pull returns.
const maxPullPage = 1000;
