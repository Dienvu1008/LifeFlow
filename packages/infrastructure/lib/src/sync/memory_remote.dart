// P04 T2 (ADR-0055): the sync server in memory, with the semantics of
// supabase/migrations (S-03, T2): workspaces owned by one account, per-record
// version checks, a replay of an accepted operation accepted once, change
// numbers per workspace, pulls in pages, purge only after the retention with
// the tombstone kept. Tests use it in place of Supabase; the contract test
// (remote_contract_test.dart) runs the same cases against both.
import 'dart:typed_data';

import 'package:application/application.dart';

/// How long a deleted record keeps its content on the server.
const purgeRetention = Duration(days: 90);

class _Workspace {
  _Workspace(this.ownerAccountId, this.info);
  final String ownerAccountId;
  RemoteWorkspace info;
  int lastSeq = 0;
  final records = <String, _Row>{};
}

class _Row {
  _Row(this.id, this.version, this.seq, this.deleted, this.sealed, this.deviceId, this.operationId, this.updatedAt);
  final String id;
  int version;
  int seq;
  bool deleted;
  Uint8List? sealed;
  String deviceId;
  String operationId;
  DateTime updatedAt;
}

/// The shared server; each account talks to it through its own gateway.
class MemoryRemoteServer {
  MemoryRemoteServer({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  DateTime Function() clock;
  final _workspaces = <String, _Workspace>{};

  /// Makes the next calls fail as if the server could not be reached.
  bool unavailable = false;

  /// The next push is stored, then its answer is lost (the device retries).
  bool loseNextAnswer = false;

  /// For tests: ages a record's last change (e.g. past the retention).
  void age(String workspaceId, String id, Duration by) {
    final r = _workspaces[workspaceId]!.records[id]!;
    r.updatedAt = r.updatedAt.subtract(by);
  }

  /// For tests: what the server holds, as an operator would see it.
  List<SealedRecord> dump(String workspaceId) => [
        for (final r in _workspaces[workspaceId]?.records.values ?? const <_Row>[])
          SealedRecord(id: r.id, version: r.version, seq: r.seq, deleted: r.deleted, sealed: r.sealed, deviceId: r.deviceId),
      ];
}

class MemoryRemoteGateway implements RemoteGateway {
  MemoryRemoteGateway(this.server, {this.accountId});
  final MemoryRemoteServer server;

  /// The signed-in account; null = signed out.
  String? accountId;

  String _account() {
    if (server.unavailable) throw const RemoteFailure(RemoteFailureKind.unavailable, 'server unreachable');
    final a = accountId;
    if (a == null) throw const RemoteFailure(RemoteFailureKind.signedOut);
    return a;
  }

  _Workspace _own(String workspaceId) {
    final a = _account();
    final w = server._workspaces[workspaceId];
    if (w == null || w.ownerAccountId != a) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown workspace');
    return w;
  }

  @override
  Future<List<RemoteWorkspace>> workspaces() async {
    final a = _account();
    return [
      for (final w in server._workspaces.values)
        if (w.ownerAccountId == a)
          RemoteWorkspace(
            workspaceId: w.info.workspaceId,
            wrappedKey: w.info.wrappedKey,
            unlockKind: w.info.unlockKind,
            unlockSalt: w.info.unlockSalt,
            lastSeq: w.lastSeq,
            keyId: w.info.keyId,
          ),
    ];
  }

  @override
  Future<void> createWorkspace(RemoteWorkspace workspace) async {
    final a = _account();
    if (!const {'recoveryKey', 'passphrase'}.contains(workspace.unlockKind)) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'unknown unlock kind');
    }
    if (workspace.keyId.isNotEmpty && !_hex64.hasMatch(workspace.keyId)) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'bad key id');
    }
    if (server._workspaces.containsKey(workspace.workspaceId)) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'the workspace exists');
    }
    server._workspaces[workspace.workspaceId] = _Workspace(a, workspace);
  }

  @override
  Future<void> updateWrappedKey(String workspaceId, Uint8List wrappedKey, String unlockKind, Uint8List? unlockSalt) async {
    final w = _own(workspaceId);
    if (!const {'recoveryKey', 'passphrase'}.contains(unlockKind)) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'unknown unlock kind');
    }
    w.info = RemoteWorkspace(
        workspaceId: workspaceId, wrappedKey: wrappedKey, unlockKind: unlockKind, unlockSalt: unlockSalt,
        keyId: w.info.keyId);
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    _own(workspaceId);
    server._workspaces.remove(workspaceId);
  }

  @override
  Future<PushResult> push(String workspaceId, String deviceId, List<RecordPush> records) async {
    final w = _own(workspaceId);
    if (records.length > maxPushBatch) throw const RemoteFailure(RemoteFailureKind.refused, 'batch too large');
    if (deviceId.isEmpty || deviceId.length > 64) throw const RemoteFailure(RemoteFailureKind.refused, 'bad device id');
    for (final r in records) {
      if (!_hex64.hasMatch(r.id)) throw const RemoteFailure(RemoteFailureKind.refused, 'ids are 64 hex characters');
    }
    // Checked and applied in one go, like the SQL function's transaction.
    final accepted = <String, int>{};
    final conflicts = <String, int?>{};
    final writes = <void Function()>[];
    var seq = w.lastSeq;
    final staged = <String, int>{};
    for (final r in records) {
      final cur = w.records[r.id];
      final curVersion = staged[r.id] ?? cur?.version;
      if (cur != null && cur.operationId == r.operationId) {
        accepted[r.id] = cur.seq;
        continue;
      }
      final isNew = curVersion == null;
      if ((isNew && r.base == null) || (!isNew && curVersion == r.base)) {
        if (r.version <= (r.base ?? 0)) throw const RemoteFailure(RemoteFailureKind.refused, 'the version must go up');
        final s = ++seq;
        staged[r.id] = r.version;
        accepted[r.id] = s;
        writes.add(() {
          final now = server.clock();
          w.records[r.id] = _Row(r.id, r.version, s, r.deleted, r.sealed, deviceId, r.operationId, now);
        });
      } else {
        conflicts[r.id] = curVersion;
      }
    }
    for (final write in writes) {
      write();
    }
    w.lastSeq = seq;
    if (server.loseNextAnswer) {
      server.loseNextAnswer = false;
      throw const RemoteFailure(RemoteFailureKind.unavailable, 'answer lost');
    }
    return PushResult(accepted: accepted, conflicts: conflicts);
  }

  @override
  Future<List<SealedRecord>> pull(String workspaceId, int after, {int limit = maxPullPage}) async {
    final a = _account();
    final w = server._workspaces[workspaceId];
    // Like row-level security: a workspace that is not yours has no rows.
    if (w == null || w.ownerAccountId != a) return const [];
    final rows = [for (final r in w.records.values) if (r.seq > after) r]..sort((x, y) => x.seq.compareTo(y.seq));
    return [
      for (final r in rows.take(limit.clamp(1, maxPullPage)))
        SealedRecord(id: r.id, version: r.version, seq: r.seq, deleted: r.deleted, sealed: r.sealed, deviceId: r.deviceId),
    ];
  }

  @override
  Future<int> purge(String workspaceId, DateTime before) async {
    final w = _own(workspaceId);
    final cut = server.clock().subtract(purgeRetention);
    final limit = before.isBefore(cut) ? before : cut;
    var n = 0;
    final rows = w.records.values.toList()..sort((x, y) => x.seq.compareTo(y.seq));
    for (final r in rows) {
      if (r.deleted && r.sealed != null && r.updatedAt.isBefore(limit)) {
        r
          ..sealed = null
          ..seq = ++w.lastSeq
          ..updatedAt = server.clock();
        n++;
      }
    }
    return n;
  }
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');
