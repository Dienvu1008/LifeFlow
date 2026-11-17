// P04 T2 (ADR-0055): the sync server over Supabase's REST API (PostgREST),
// using the signed-in account's access token. Only the functions and the
// table of supabase/migrations are used, so row-level security and the
// functions' owner checks always apply. Errors become RemoteFailure; no
// content and no token is ever put in a failure or a log.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:http/http.dart' as http;

class HttpRemoteGateway implements RemoteGateway, SpaceGateway {
  HttpRemoteGateway({
    required this.baseUrl,
    required this.anonKey,
    required this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  /// The project URL (`https://<ref>.supabase.co`, or the local stack).
  final String baseUrl;

  /// The public (publishable) key; it identifies the project, not the user.
  final String anonKey;

  /// The account's current access token, or null when signed out.
  final Future<String?> Function() accessToken;
  final Duration timeout;
  final http.Client _client;

  Future<Map<String, String>> _headers({String? prefer}) async {
    final token = await accessToken();
    if (token == null) throw const RemoteFailure(RemoteFailureKind.signedOut);
    return {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (prefer != null) 'Prefer': prefer,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/rest/v1/$path').replace(queryParameters: query);

  Future<Object?> _send(String method, Uri uri, {Object? body, String? prefer}) async {
    final req = http.Request(method, uri)..headers.addAll(await _headers(prefer: prefer));
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req).timeout(timeout));
    } on TimeoutException {
      throw const RemoteFailure(RemoteFailureKind.unavailable, 'timeout');
    } on SocketException {
      throw const RemoteFailure(RemoteFailureKind.unavailable, 'no connection');
    } on http.ClientException {
      throw const RemoteFailure(RemoteFailureKind.unavailable, 'connection failed');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw _failure(res);
  }

  RemoteFailure _failure(http.Response res) {
    String? code;
    String? hint;
    try {
      final body = jsonDecode(res.body) as Map;
      code = body['code'] as String?;
      hint = body['hint'] as String?;
    } catch (_) {}
    // A space request refused for a reason the app explains (ADR-0061).
    if (hint != null && hint.startsWith(_hintPrefix)) {
      final reason = SpaceRefusal.values.where((r) => r.name == hint!.substring(_hintPrefix.length)).firstOrNull;
      if (reason != null) return SpaceFailure(reason, 'status ${res.statusCode}');
    }
    // PostgREST answers 403 to insufficient_privilege (42501), which the
    // functions raise for a workspace that is not the caller's.
    if (code == 'PGRST301' || code == 'PGRST302' || res.statusCode == 401) {
      return RemoteFailure(RemoteFailureKind.signedOut, 'status ${res.statusCode}');
    }
    if (res.statusCode == 403) return RemoteFailure(RemoteFailureKind.notYours, 'status 403');
    if (res.statusCode >= 500 || res.statusCode == 408 || res.statusCode == 429) {
      return RemoteFailure(RemoteFailureKind.unavailable, 'status ${res.statusCode}');
    }
    return RemoteFailure(RemoteFailureKind.refused, 'status ${res.statusCode} ${code ?? ''}');
  }

  @override
  Future<List<RemoteWorkspace>> workspaces() async {
    // Personal workspaces only; a space the account owns is in spaces().
    final rows = await _send('GET', _uri('account_workspaces', {
      'select': 'workspace_id,wrapped_key,unlock_kind,unlock_salt,last_seq,key_id',
      'unlock_kind': 'neq.space',
    })) as List;
    return [
      for (final r in rows.cast<Map>())
        RemoteWorkspace(
          workspaceId: r['workspace_id'] as String,
          wrappedKey: _fromHex(r['wrapped_key'] as String),
          unlockKind: r['unlock_kind'] as String,
          unlockSalt: r['unlock_salt'] == null ? null : _fromHex(r['unlock_salt'] as String),
          lastSeq: (r['last_seq'] as num).toInt(),
          keyId: r['key_id'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<void> createWorkspace(RemoteWorkspace workspace) async {
    await _send('POST', _uri('account_workspaces'),
        body: {
          'workspace_id': workspace.workspaceId,
          'wrapped_key': _toHex(workspace.wrappedKey),
          'unlock_kind': workspace.unlockKind,
          'unlock_salt': workspace.unlockSalt == null ? null : _toHex(workspace.unlockSalt!),
          'key_id': workspace.keyId,
        },
        prefer: 'return=minimal');
  }

  @override
  Future<void> updateWrappedKey(String workspaceId, Uint8List wrappedKey, String unlockKind, Uint8List? unlockSalt) async {
    final rows = await _send('PATCH', _uri('account_workspaces', {'workspace_id': 'eq.$workspaceId'}),
        body: {
          'wrapped_key': _toHex(wrappedKey),
          'unlock_kind': unlockKind,
          'unlock_salt': unlockSalt == null ? null : _toHex(unlockSalt),
        },
        prefer: 'return=representation') as List;
    if (rows.isEmpty) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown workspace');
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    final rows = await _send('DELETE', _uri('account_workspaces', {'workspace_id': 'eq.$workspaceId'}),
        prefer: 'return=representation') as List;
    if (rows.isEmpty) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown workspace');
  }

  @override
  Future<PushResult> push(String workspaceId, String deviceId, List<RecordPush> records, {String keyId = ''}) async {
    final res = await _send('POST', _uri('rpc/push_records'), body: {
      'p_workspace': workspaceId,
      'p_device': deviceId,
      // Only when named, so a P04a push also reaches a server without
      // 20261118000001 (ADR-0062).
      if (keyId.isNotEmpty) 'p_key_id': keyId,
      'p_records': [
        for (final r in records)
          {
            'id': r.id,
            'base': r.base,
            'version': r.version,
            'deleted': r.deleted,
            'sealed': base64Encode(r.sealed),
            'op': r.operationId,
          },
      ],
    }) as Map;
    return PushResult(
      accepted: {
        for (final a in (res['accepted'] as List).cast<Map>()) a['id'] as String: (a['seq'] as num).toInt(),
      },
      conflicts: {
        for (final c in (res['conflicts'] as List).cast<Map>()) c['id'] as String: (c['version'] as num?)?.toInt(),
      },
    );
  }

  @override
  Future<List<SealedRecord>> pull(String workspaceId, int after, {int limit = maxPullPage}) async {
    final rows = await _send('POST', _uri('rpc/pull_records'),
        body: {'p_workspace': workspaceId, 'p_after': after, 'p_limit': limit}) as List;
    return [
      for (final r in rows.cast<Map>())
        SealedRecord(
          id: r['id'] as String,
          version: (r['version'] as num).toInt(),
          seq: (r['seq'] as num).toInt(),
          deleted: r['deleted'] as bool,
          // Postgres' encode(..., 'base64') breaks lines every 76 characters
          // (T6 finding): the line breaks are not part of the data.
          sealed: r['sealed'] == null ? null : base64Decode((r['sealed'] as String).replaceAll(_whitespace, '')),
          deviceId: r['device_id'] as String,
          keyId: r['key_id'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<int> purge(String workspaceId, DateTime before) async =>
      ((await _send('POST', _uri('rpc/purge_records'),
              body: {'p_workspace': workspaceId, 'p_before': before.toUtc().toIso8601String()})) as num)
          .toInt();

  // === Spaces (SpaceGateway; 20261117000001_spaces.sql) ====================

  Future<Object?> _rpc(String name, Map<String, Object?> args) => _send('POST', _uri('rpc/$name'), body: args);

  @override
  Future<AccountKeys?> myKeys() async {
    // Row-level security: only the caller's own private key is readable.
    final mine = await _send('GET', _uri('account_private_keys', {'select': 'account_id,sealed_private'})) as List;
    if (mine.isEmpty) return null;
    final row = mine.single as Map;
    final pub = await _send('GET', _uri('account_public_keys', {
      'select': 'public_key',
      'account_id': 'eq.${row['account_id']}',
    })) as List;
    if (pub.isEmpty) return null;
    return AccountKeys(
        publicKey: _fromHex((pub.single as Map)['public_key'] as String),
        sealedPrivate: _fromHex(row['sealed_private'] as String));
  }

  @override
  Future<void> setMyKeys(AccountKeys keys) async {
    await _rpc('set_account_keys', {'p_public': _toHex(keys.publicKey), 'p_sealed_private': _toHex(keys.sealedPrivate)});
  }

  @override
  Future<Map<String, Uint8List>> publicKeys(List<String> accountIds) async {
    if (accountIds.isEmpty) return const {};
    for (final id in accountIds) {
      if (!_uuid.hasMatch(id)) throw const RemoteFailure(RemoteFailureKind.refused, 'bad account id');
    }
    final rows = await _send('GET', _uri('account_public_keys', {
      'select': 'account_id,public_key',
      'account_id': 'in.(${accountIds.join(',')})',
    })) as List;
    return {
      for (final r in rows.cast<Map>()) r['account_id'] as String: _fromHex(r['public_key'] as String),
    };
  }

  @override
  Future<List<RemoteSpace>> spaces() async {
    final rows = await _rpc('my_spaces', const {}) as List;
    return [
      for (final r in rows.cast<Map>())
        RemoteSpace(
          workspaceId: r['workspace_id'] as String,
          role: SpaceRole.values.byName(r['role'] as String),
          status: MemberStatus.values.byName(r['status'] as String),
          wrappedKey: r['wrapped_key'] == null ? null : _fromHex(r['wrapped_key'] as String),
          keyId: r['key_id'] as String,
          rules: r['leave_rule'] == null
              ? null
              : SpaceRules(
                  leave: LeaveRule.values.byName(r['leave_rule'] as String),
                  export: ExportRule.values.byName(r['export_rule'] as String),
                  inviteDefault: InviteKind.values.byName(r['invite_default'] as String),
                ),
          rulesChangedAt: r['rules_changed_at'] == null ? null : DateTime.parse(r['rules_changed_at'] as String),
        ),
    ];
  }

  @override
  Future<void> createSpace(String workspaceId, Uint8List wrappedForMe, String keyId) async {
    await _rpc('create_space', {'p_workspace': workspaceId, 'p_wrapped_for_me': _toHex(wrappedForMe), 'p_key_id': keyId});
  }

  @override
  Future<void> deleteSpace(String workspaceId) async {
    final rows = await _send('DELETE',
        _uri('account_workspaces', {'workspace_id': 'eq.$workspaceId', 'unlock_kind': 'eq.space'}),
        prefer: 'return=representation') as List;
    if (rows.isEmpty) throw const RemoteFailure(RemoteFailureKind.notYours, 'unknown space');
  }

  @override
  Future<List<RemoteMember>> members(String workspaceId) async {
    final rows = await _send('GET', _uri('space_members', {
      'select': 'account_id,role,status,key_id,created_at,sealed_name',
      'workspace_id': 'eq.$workspaceId',
      'order': 'created_at',
    })) as List;
    return [
      for (final r in rows.cast<Map>())
        RemoteMember(
          accountId: r['account_id'] as String,
          role: SpaceRole.values.byName(r['role'] as String),
          status: MemberStatus.values.byName(r['status'] as String),
          keyId: r['key_id'] as String,
          joinedAt: DateTime.parse(r['created_at'] as String),
          sealedName: r['sealed_name'] == null ? null : _fromHex(r['sealed_name'] as String),
        ),
    ];
  }

  @override
  Future<List<RemoteInvitation>> invitations(String workspaceId) async {
    final rows = await _send('GET', _uri('space_invitations', {
      'select': 'code_hash,role,kind,expires_at',
      'workspace_id': 'eq.$workspaceId',
      'used_by': 'is.null',
      'expires_at': 'gt.${DateTime.now().toUtc().toIso8601String()}',
    })) as List;
    return [
      for (final r in rows.cast<Map>())
        RemoteInvitation(
          codeHash: r['code_hash'] as String,
          role: SpaceRole.values.byName(r['role'] as String),
          kind: InviteKind.values.byName(r['kind'] as String),
          expiresAt: DateTime.parse(r['expires_at'] as String),
        ),
    ];
  }

  @override
  Future<void> invite(String workspaceId, String codeHash, SpaceRole role, InviteKind kind,
      {Uint8List? wrappedKey, String keyId = '', int days = 7}) async {
    await _rpc('invite', {
      'p_workspace': workspaceId,
      'p_code_hash': codeHash,
      'p_role': role.name,
      'p_kind': kind.name,
      'p_wrapped': wrappedKey == null ? null : _toHex(wrappedKey),
      'p_key_id': keyId,
      'p_days': days,
    });
  }

  @override
  Future<void> cancelInvitation(String codeHash) async {
    await _rpc('cancel_invitation', {'p_code_hash': codeHash});
  }

  InvitationPreview _previewOf(Map r) => InvitationPreview(
        workspaceId: r['workspace_id'] as String,
        role: SpaceRole.values.byName(r['role'] as String),
        kind: InviteKind.values.byName(r['kind'] as String),
        leave: LeaveRule.values.byName(r['leave_rule'] as String),
        export: ExportRule.values.byName(r['export_rule'] as String),
        expiresAt: r['expires_at'] == null ? null : DateTime.parse(r['expires_at'] as String),
        ownerPublicKey: r['owner_public_key'] == null
            ? null
            : base64Decode((r['owner_public_key'] as String).replaceAll(_whitespace, '')),
      );

  @override
  Future<InvitationPreview> peekInvitation(String codeHash) async =>
      _previewOf(await _rpc('peek_invitation', {'p_code_hash': codeHash}) as Map);

  @override
  Future<AcceptedInvitation> acceptInvitation(String codeHash, {Uint8List? sealedName}) async {
    final r = await _rpc('accept_invitation', {
      'p_code_hash': codeHash,
      if (sealedName != null) 'p_sealed_name': _toHex(sealedName),
    }) as Map;
    final wrapped = r['wrapped_key'] as String?;
    return AcceptedInvitation(
      preview: _previewOf(r),
      // encode(..., 'base64') breaks lines (T6 finding 2).
      wrappedKey: wrapped == null ? null : base64Decode(wrapped.replaceAll(_whitespace, '')),
      keyId: r['key_id'] as String? ?? '',
    );
  }

  @override
  Future<void> approveMember(String workspaceId, String accountId, Uint8List wrappedKey, String keyId) async {
    await _rpc('approve_member', {
      'p_workspace': workspaceId,
      'p_account': accountId,
      'p_wrapped': _toHex(wrappedKey),
      'p_key_id': keyId,
    });
  }

  @override
  Future<void> setMyWrappedKey(String workspaceId, Uint8List wrappedKey, String keyId) async {
    await _rpc('set_my_wrapped_key', {'p_workspace': workspaceId, 'p_wrapped': _toHex(wrappedKey), 'p_key_id': keyId});
  }

  @override
  Future<void> removeMember(String workspaceId, String accountId) async {
    await _rpc('remove_member', {'p_workspace': workspaceId, 'p_account': accountId});
  }

  @override
  Future<void> leaveSpace(String workspaceId) async {
    await _rpc('leave_space', {'p_workspace': workspaceId});
  }

  @override
  Future<void> setRole(String workspaceId, String accountId, SpaceRole role) async {
    await _rpc('set_role', {'p_workspace': workspaceId, 'p_account': accountId, 'p_role': role.name});
  }

  @override
  Future<void> handOver(String workspaceId, String accountId) async {
    await _rpc('hand_over', {'p_workspace': workspaceId, 'p_account': accountId});
  }

  @override
  Future<void> setRules(String workspaceId, SpaceRules rules) async {
    await _rpc('set_space_rules', {
      'p_workspace': workspaceId,
      'p_leave': rules.leave.name,
      'p_export': rules.export.name,
      'p_invite': rules.inviteDefault.name,
    });
  }

  @override
  Future<int> dropOldKeyRecords(String workspaceId) async =>
      ((await _rpc('drop_old_key_records', {'p_workspace': workspaceId})) as num).toInt();

  @override
  Future<void> rotateKey(String workspaceId, String keyId, Map<String, Uint8List> wrappedFor) async {
    await _rpc('rotate_space_key', {
      'p_workspace': workspaceId,
      'p_key_id': keyId,
      'p_wraps': [
        for (final e in wrappedFor.entries) {'account': e.key, 'wrapped': base64Encode(e.value)},
      ],
    });
  }
}

const _hintPrefix = 'lifeflow:';
final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

final _whitespace = RegExp(r'\s');

/// PostgREST's text form of bytea: `\x` and hex digits.
String _toHex(Uint8List b) => '\\x${[for (final x in b) x.toRadixString(16).padLeft(2, '0')].join()}';

Uint8List _fromHex(String s) {
  final h = s.startsWith('\\x') ? s.substring(2) : s;
  return Uint8List.fromList([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);
}
