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

class HttpRemoteGateway implements RemoteGateway {
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
    try {
      code = (jsonDecode(res.body) as Map)['code'] as String?;
    } catch (_) {}
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
    final rows = await _send('GET',
        _uri('account_workspaces', {'select': 'workspace_id,wrapped_key,unlock_kind,unlock_salt,last_seq'})) as List;
    return [
      for (final r in rows.cast<Map>())
        RemoteWorkspace(
          workspaceId: r['workspace_id'] as String,
          wrappedKey: _fromHex(r['wrapped_key'] as String),
          unlockKind: r['unlock_kind'] as String,
          unlockSalt: r['unlock_salt'] == null ? null : _fromHex(r['unlock_salt'] as String),
          lastSeq: (r['last_seq'] as num).toInt(),
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
  Future<PushResult> push(String workspaceId, String deviceId, List<RecordPush> records) async {
    final res = await _send('POST', _uri('rpc/push_records'), body: {
      'p_workspace': workspaceId,
      'p_device': deviceId,
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
          sealed: r['sealed'] == null ? null : base64Decode(r['sealed'] as String),
          deviceId: r['device_id'] as String,
        ),
    ];
  }

  @override
  Future<int> purge(String workspaceId, DateTime before) async =>
      ((await _send('POST', _uri('rpc/purge_records'),
              body: {'p_workspace': workspaceId, 'p_before': before.toUtc().toIso8601String()})) as num)
          .toInt();
}

/// PostgREST's text form of bytea: `\x` and hex digits.
String _toHex(Uint8List b) => '\\x${[for (final x in b) x.toRadixString(16).padLeft(2, '0')].join()}';

Uint8List _fromHex(String s) {
  final h = s.startsWith('\\x') ? s.substring(2) : s;
  return Uint8List.fromList([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);
}
