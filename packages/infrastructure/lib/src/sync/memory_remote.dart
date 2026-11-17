// P04 T2 (ADR-0055): the sync server in memory, with the semantics of
// supabase/migrations (S-03, T2): workspaces owned by one account, per-record
// version checks, a replay of an accepted operation accepted once, change
// numbers per workspace, pulls in pages, purge only after the retention with
// the tombstone kept. Tests use it in place of Supabase; the contract test
// (remote_contract_test.dart) runs the same cases against both.
// P04b T9 (ADR-0061): shared spaces too (20261117000001_spaces.sql): members
// and their roles, invitations, account keys; records of a space are read by
// its active members and written by its owner and editors.
import 'dart:typed_data';

import 'package:application/application.dart';

/// How long a deleted record keeps its content on the server.
const purgeRetention = Duration(days: 90);

class _Workspace {
  _Workspace(this.ownerAccountId, this.info);

  /// account_workspaces.account_id: for a space, its current owner.
  String ownerAccountId;
  RemoteWorkspace info;
  int lastSeq = 0;
  final records = <String, _Row>{};
  bool get isSpace => info.unlockKind == 'space';
}

class _Row {
  _Row(this.id, this.version, this.seq, this.deleted, this.sealed, this.deviceId, this.operationId, this.updatedAt,
      [this.keyId = '']);
  final String id;
  String keyId;
  int version;
  int seq;
  bool deleted;
  Uint8List? sealed;
  String deviceId;
  String operationId;
  DateTime updatedAt;
}

class _Space {
  _Space(this.rulesChangedAt);
  SpaceRules rules = const SpaceRules();
  DateTime rulesChangedAt;
  final members = <String, _Member>{};
}

class _Member {
  _Member(this.role, this.status, this.wrappedKey, this.keyId, this.joinedAt);
  SpaceRole role;
  MemberStatus status;
  Uint8List? wrappedKey;
  String keyId;
  final DateTime joinedAt;
}

class _Invitation {
  _Invitation(this.workspaceId, this.role, this.kind, this.wrappedKey, this.keyId, this.expiresAt);
  final String workspaceId;
  final SpaceRole role;
  final InviteKind kind;
  Uint8List? wrappedKey;
  final String keyId;
  final DateTime expiresAt;
  String? usedBy;
}

/// The shared server; each account talks to it through its own gateway.
class MemoryRemoteServer {
  MemoryRemoteServer({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  DateTime Function() clock;
  final _workspaces = <String, _Workspace>{};
  final _spaces = <String, _Space>{};
  final _invitations = <String, _Invitation>{};
  final _publicKeys = <String, Uint8List>{};
  final _privateKeys = <String, Uint8List>{};

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

  /// The caller's role in a workspace, as private.role_in: an active
  /// member's role in a space, or owner of their personal workspace.
  SpaceRole? _roleIn(String workspaceId, String account) {
    final w = _workspaces[workspaceId];
    if (w == null) return null;
    if (w.isSpace) {
      final m = _spaces[workspaceId]?.members[account];
      return m != null && m.status == MemberStatus.active ? m.role : null;
    }
    return w.ownerAccountId == account ? SpaceRole.owner : null;
  }

  /// Whether [account] and [other] are in one space, [account] active.
  bool _sharesSpace(String account, String other) => _spaces.values.any((s) =>
      s.members[account]?.status == MemberStatus.active && s.members.containsKey(other));

  void _deleteWorkspace(String workspaceId) {
    _workspaces.remove(workspaceId);
    _spaces.remove(workspaceId);
    _invitations.removeWhere((_, i) => i.workspaceId == workspaceId);
  }
}

class MemoryRemoteGateway implements RemoteGateway, SpaceGateway {
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

  /// A row of account_workspaces the caller holds (personal, or a space
  /// they own).
  _Workspace _own(String workspaceId) {
    final a = _account();
    final w = server._workspaces[workspaceId];
    if (w == null || w.ownerAccountId != a) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown workspace');
    return w;
  }

  /// A workspace the caller may write to: an owner or an editor.
  _Workspace _writable(String workspaceId) {
    final a = _account();
    final role = server._roleIn(workspaceId, a);
    if (role != SpaceRole.owner && role != SpaceRole.editor) {
      throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown workspace');
    }
    return server._workspaces[workspaceId]!;
  }

  /// A space the caller owns, as private.must_own.
  _Space _ownedSpace(String workspaceId) {
    final a = _account();
    final s = server._spaces[workspaceId];
    if (s == null || s.members[a]?.role != SpaceRole.owner) {
      throw const RemoteFailure(RemoteFailureKind.notYours, 'not the owner of this space');
    }
    return s;
  }

  @override
  Future<List<RemoteWorkspace>> workspaces() async {
    final a = _account();
    return [
      for (final w in server._workspaces.values)
        if (w.ownerAccountId == a && !w.isSpace)
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
    // A space's row is changed only by the space functions.
    if (w.isSpace) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown workspace');
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
    server._deleteWorkspace(workspaceId);
  }

  @override
  Future<PushResult> push(String workspaceId, String deviceId, List<RecordPush> records, {String keyId = ''}) async {
    if (records.length > maxPushBatch) throw const RemoteFailure(RemoteFailureKind.refused, 'batch too large');
    final w = _writable(workspaceId);
    // ADR-0062: a space takes records sealed with its current key only.
    if (w.isSpace && keyId != w.info.keyId) throw const SpaceFailure(SpaceRefusal.staleKey);
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
          w.records[r.id] = _Row(r.id, r.version, s, r.deleted, r.sealed, deviceId, r.operationId, now, keyId);
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
    // Like row-level security: a workspace the caller may not read has no rows.
    if (server._roleIn(workspaceId, a) == null) return const [];
    final w = server._workspaces[workspaceId]!;
    final rows = [for (final r in w.records.values) if (r.seq > after) r]..sort((x, y) => x.seq.compareTo(y.seq));
    return [
      for (final r in rows.take(limit.clamp(1, maxPullPage)))
        SealedRecord(
            id: r.id,
            version: r.version,
            seq: r.seq,
            deleted: r.deleted,
            sealed: r.sealed,
            deviceId: r.deviceId,
            keyId: r.keyId),
    ];
  }

  @override
  Future<int> purge(String workspaceId, DateTime before) async {
    final w = _writable(workspaceId);
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

  // === Spaces (SpaceGateway) ================================================

  @override
  Future<AccountKeys?> myKeys() async {
    final a = _account();
    final pub = server._publicKeys[a];
    final priv = server._privateKeys[a];
    if (pub == null || priv == null) return null;
    return AccountKeys(publicKey: pub, sealedPrivate: priv);
  }

  @override
  Future<void> setMyKeys(AccountKeys keys) async {
    final a = _account();
    if (keys.publicKey.length != 32) throw const RemoteFailure(RemoteFailureKind.refused, 'a public key is 32 bytes');
    if (keys.sealedPrivate.isEmpty || keys.sealedPrivate.length > 1024) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'bad sealed private key');
    }
    server._publicKeys[a] = keys.publicKey;
    server._privateKeys[a] = keys.sealedPrivate;
  }

  @override
  Future<Map<String, Uint8List>> publicKeys(List<String> accountIds) async {
    final a = _account();
    return {
      for (final id in accountIds)
        if (server._publicKeys[id] != null && (id == a || server._sharesSpace(a, id))) id: server._publicKeys[id]!,
    };
  }

  @override
  Future<List<RemoteSpace>> spaces() async {
    final a = _account();
    final mine = [
      for (final e in server._spaces.entries)
        if (e.value.members[a] != null) (e.key, e.value, e.value.members[a]!),
    ]..sort((x, y) => x.$3.joinedAt.compareTo(y.$3.joinedAt));
    return [
      for (final (id, s, m) in mine)
        RemoteSpace(
          workspaceId: id,
          role: m.role,
          status: m.status,
          wrappedKey: m.wrappedKey,
          keyId: m.keyId,
          rules: m.status == MemberStatus.active ? s.rules : null,
          rulesChangedAt: m.status == MemberStatus.active ? s.rulesChangedAt : null,
        ),
    ];
  }

  int _spacesOf(String account) => server._spaces.values.where((s) => s.members.containsKey(account)).length;

  @override
  Future<void> createSpace(String workspaceId, Uint8List wrappedForMe, String keyId) async {
    final a = _account();
    if (!server._publicKeys.containsKey(a)) throw const SpaceFailure(SpaceRefusal.noPublicKey);
    if (_spacesOf(a) >= maxSpacesPerAccount) throw const SpaceFailure(SpaceRefusal.tooManySpaces);
    if (server._workspaces.containsKey(workspaceId)) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'the workspace exists');
    }
    _checkKey(wrappedForMe, keyId);
    final now = server.clock();
    server._workspaces[workspaceId] = _Workspace(
        a, RemoteWorkspace(workspaceId: workspaceId, wrappedKey: wrappedForMe, unlockKind: 'space', keyId: keyId));
    server._spaces[workspaceId] = _Space(now)
      ..members[a] = _Member(SpaceRole.owner, MemberStatus.active, wrappedForMe, keyId, now);
  }

  @override
  Future<void> deleteSpace(String workspaceId) async {
    final w = _own(workspaceId);
    if (!w.isSpace) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown space');
    server._deleteWorkspace(workspaceId);
  }

  @override
  Future<List<RemoteMember>> members(String workspaceId) async {
    final a = _account();
    final s = server._spaces[workspaceId];
    if (s == null) return const [];
    final canSee = server._roleIn(workspaceId, a) != null;
    final rows = [
      for (final e in s.members.entries)
        if (canSee || e.key == a)
          RemoteMember(accountId: e.key, role: e.value.role, status: e.value.status, keyId: e.value.keyId,
              joinedAt: e.value.joinedAt),
    ]..sort((x, y) => x.joinedAt.compareTo(y.joinedAt));
    return rows;
  }

  @override
  Future<List<RemoteInvitation>> invitations(String workspaceId) async {
    final a = _account();
    final s = server._spaces[workspaceId];
    if (s == null || s.members[a]?.role != SpaceRole.owner) return const [];
    final now = server.clock();
    return [
      for (final e in server._invitations.entries)
        if (e.value.workspaceId == workspaceId && e.value.usedBy == null && e.value.expiresAt.isAfter(now))
          RemoteInvitation(codeHash: e.key, role: e.value.role, kind: e.value.kind, expiresAt: e.value.expiresAt),
    ];
  }

  @override
  Future<void> invite(String workspaceId, String codeHash, SpaceRole role, InviteKind kind,
      {Uint8List? wrappedKey, String keyId = '', int days = 7}) async {
    _ownedSpace(workspaceId);
    if (days < 1 || days > 7) throw const RemoteFailure(RemoteFailureKind.refused, 'an invitation lasts 1 to 7 days');
    if (kind == InviteKind.joinAtOnce && wrappedKey == null) {
      throw const RemoteFailure(RemoteFailureKind.refused, 'a "join at once" invitation carries the key');
    }
    if (role == SpaceRole.owner) throw const RemoteFailure(RemoteFailureKind.refused, 'nobody is invited as owner');
    if (!_hex64.hasMatch(codeHash)) throw const RemoteFailure(RemoteFailureKind.refused, 'bad code hash');
    if (server._invitations.containsKey(codeHash)) throw const RemoteFailure(RemoteFailureKind.refused, 'duplicate code');
    final atOnce = kind == InviteKind.joinAtOnce;
    if (atOnce) _checkKey(wrappedKey!, keyId);
    server._invitations[codeHash] = _Invitation(workspaceId, role, kind, atOnce ? wrappedKey : null,
        atOnce ? keyId : '', server.clock().add(Duration(days: days)));
  }

  @override
  Future<void> cancelInvitation(String codeHash) async {
    _account();
    final i = server._invitations[codeHash];
    if (i == null || i.usedBy != null) throw const SpaceFailure(SpaceRefusal.noSuchInvitation);
    _ownedSpace(i.workspaceId);
    server._invitations.remove(codeHash);
  }

  _Invitation _open(String codeHash) {
    final i = server._invitations[codeHash];
    if (i == null || i.usedBy != null || !i.expiresAt.isAfter(server.clock())) {
      throw const SpaceFailure(SpaceRefusal.noSuchInvitation);
    }
    return i;
  }

  InvitationPreview _preview(_Invitation i) {
    final s = server._spaces[i.workspaceId]!;
    return InvitationPreview(
        workspaceId: i.workspaceId,
        role: i.role,
        kind: i.kind,
        leave: s.rules.leave,
        export: s.rules.export,
        expiresAt: i.expiresAt);
  }

  @override
  Future<InvitationPreview> peekInvitation(String codeHash) async {
    _account();
    return _preview(_open(codeHash));
  }

  @override
  Future<AcceptedInvitation> acceptInvitation(String codeHash) async {
    final a = _account();
    final i = _open(codeHash);
    if (!server._publicKeys.containsKey(a)) throw const SpaceFailure(SpaceRefusal.noPublicKey);
    final s = server._spaces[i.workspaceId]!;
    if (s.members.containsKey(a)) throw const SpaceFailure(SpaceRefusal.alreadyMember);
    if (s.members.length >= maxSpaceMembers) throw const SpaceFailure(SpaceRefusal.spaceFull);
    if (_spacesOf(a) >= maxSpacesPerAccount) throw const SpaceFailure(SpaceRefusal.tooManySpaces);
    final atOnce = i.kind == InviteKind.joinAtOnce;
    final wrapped = i.wrappedKey;
    i
      ..usedBy = a
      ..wrappedKey = null;
    s.members[a] = _Member(i.role, atOnce ? MemberStatus.active : MemberStatus.pending, atOnce ? wrapped : null,
        atOnce ? i.keyId : '', server.clock());
    return AcceptedInvitation(
        preview: InvitationPreview(
            workspaceId: i.workspaceId, role: i.role, kind: i.kind, leave: s.rules.leave, export: s.rules.export),
        wrappedKey: atOnce ? wrapped : null,
        keyId: atOnce ? i.keyId : '');
  }

  String _currentKeyId(String workspaceId) => server._workspaces[workspaceId]!.info.keyId;

  @override
  Future<void> approveMember(String workspaceId, String accountId, Uint8List wrappedKey, String keyId) async {
    final s = _ownedSpace(workspaceId);
    if (keyId != _currentKeyId(workspaceId)) throw const SpaceFailure(SpaceRefusal.staleKey);
    final m = s.members[accountId];
    if (m == null || m.status != MemberStatus.pending) throw const SpaceFailure(SpaceRefusal.nobodyWaiting);
    _checkKey(wrappedKey, keyId);
    m
      ..status = MemberStatus.active
      ..wrappedKey = wrappedKey
      ..keyId = keyId;
  }

  @override
  Future<void> setMyWrappedKey(String workspaceId, Uint8List wrappedKey, String keyId) async {
    final a = _account();
    final m = server._spaces[workspaceId]?.members[a];
    if (m == null || m.status != MemberStatus.active || m.keyId != keyId || keyId != _currentKeyId(workspaceId)) {
      throw const RemoteFailure(RemoteFailureKind.notYours, 'not a member, or not the current key');
    }
    _checkKey(wrappedKey, keyId);
    m.wrappedKey = wrappedKey;
  }

  @override
  Future<void> removeMember(String workspaceId, String accountId) async {
    final s = _ownedSpace(workspaceId);
    final m = s.members[accountId];
    if (m == null || m.role == SpaceRole.owner) throw const SpaceFailure(SpaceRefusal.notAMember);
    s.members.remove(accountId);
  }

  @override
  Future<void> leaveSpace(String workspaceId) async {
    final a = _account();
    final s = server._spaces[workspaceId];
    final m = s?.members[a];
    if (m?.role == SpaceRole.owner) throw const SpaceFailure(SpaceRefusal.ownerMustHandOver);
    if (m == null) throw const SpaceFailure(SpaceRefusal.notAMember);
    s!.members.remove(a);
  }

  @override
  Future<void> setRole(String workspaceId, String accountId, SpaceRole role) async {
    final s = _ownedSpace(workspaceId);
    if (role == SpaceRole.owner) throw const RemoteFailure(RemoteFailureKind.refused, 'use handOver for the owner role');
    final m = s.members[accountId];
    if (m == null || m.role == SpaceRole.owner) throw const SpaceFailure(SpaceRefusal.notAMember);
    m.role = role;
  }

  @override
  Future<void> handOver(String workspaceId, String accountId) async {
    final a = _account();
    final s = _ownedSpace(workspaceId);
    final m = s.members[accountId];
    if (m == null || m.status != MemberStatus.active || m.role == SpaceRole.owner) {
      throw const SpaceFailure(SpaceRefusal.notAMember);
    }
    s.members[a]!.role = SpaceRole.editor;
    m.role = SpaceRole.owner;
    server._workspaces[workspaceId]!.ownerAccountId = accountId;
  }

  @override
  Future<void> setRules(String workspaceId, SpaceRules rules) async {
    final s = _ownedSpace(workspaceId);
    if (s.rules == rules) return;
    s
      ..rules = rules
      ..rulesChangedAt = server.clock();
  }

  @override
  Future<void> rotateKey(String workspaceId, String keyId, Map<String, Uint8List> wrappedFor) async {
    final a = _account();
    final s = _ownedSpace(workspaceId);
    final active = {
      for (final e in s.members.entries)
        if (e.value.status == MemberStatus.active) e.key,
    };
    if (active.length != wrappedFor.length || !active.containsAll(wrappedFor.keys)) {
      throw const SpaceFailure(SpaceRefusal.wrongMembers);
    }
    for (final w in wrappedFor.values) {
      _checkKey(w, keyId);
    }
    for (final e in wrappedFor.entries) {
      s.members[e.key]!
        ..wrappedKey = e.value
        ..keyId = keyId;
    }
    final w = server._workspaces[workspaceId]!;
    w.info = RemoteWorkspace(workspaceId: workspaceId, wrappedKey: wrappedFor[a]!, unlockKind: 'space', keyId: keyId);
    server._invitations.removeWhere(
        (_, i) => i.workspaceId == workspaceId && i.usedBy == null && i.kind == InviteKind.joinAtOnce);
  }

  @override
  Future<int> dropOldKeyRecords(String workspaceId) async {
    _ownedSpace(workspaceId);
    final w = server._workspaces[workspaceId]!;
    final before = w.records.length;
    w.records.removeWhere((_, r) => r.keyId != w.info.keyId);
    return before - w.records.length;
  }

  void _checkKey(Uint8List wrapped, String keyId) {
    if (wrapped.isEmpty || wrapped.length > 1024) throw const RemoteFailure(RemoteFailureKind.refused, 'bad wrapped key');
    if (keyId.isNotEmpty && !_hex64.hasMatch(keyId)) throw const RemoteFailure(RemoteFailureKind.refused, 'bad key id');
  }
}

final _hex64 = RegExp(r'^[0-9a-f]{64}$');
