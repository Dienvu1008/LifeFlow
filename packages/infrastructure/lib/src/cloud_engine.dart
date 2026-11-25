// P06 T5 (ADR-0085; the owner's D2, D5, D6, D10): cloud models with the
// person's own key.
//   site      only a request checked for the cloud (ADR-0081): Restricted
//             never in it, Confidential only consented, nothing with the
//             cloud option off
//   wire      OpenAI chat completions (OpenAI, Groq, any OpenAI-compatible
//             address), Anthropic messages, Gemini generateContent; the
//             answer streamed (server-sent events); a structured answer with
//             the provider's own JSON Schema mode, checked and asked again
//             once
//   key       read from secure storage for each request; sent only in the
//             provider's header, over HTTPS (loopback for tests); never in a
//             URL, an error or a log
//   cost      the provider's token counts recorded per request; a request
//             that could go over the person's monthly cap is not sent
//   stop      the connection is closed; the answer ends as stopped
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:http/http.dart' as http;

bool _loopback(Uri u) => u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1';

/// The address of a provider, checked: HTTPS (or a loopback address).
Uri cloudBaseUri(CloudAiConfig config) {
  final raw = config.effectiveBaseUrl;
  final u = Uri.tryParse(raw);
  if (raw.isEmpty || u == null || !u.hasAuthority) {
    throw const AiEngineFailure(AiEngineFailureKind.notReady, 'no address for this provider');
  }
  if (u.scheme != 'https' && !(u.scheme == 'http' && _loopback(u))) {
    throw const AiEngineFailure(AiEngineFailureKind.notReady, 'only an https:// address');
  }
  return u.replace(path: u.path.endsWith('/') ? u.path.substring(0, u.path.length - 1) : u.path);
}

Uri _at(Uri base, String path, [Map<String, String>? query]) =>
    base.replace(path: '${base.path}$path', queryParameters: query);

/// A provider's message, short, with the key taken out if it was echoed.
String _clean(String text, String key) {
  var t = text.replaceAll(key, '***');
  if (t.length > 300) t = '${t.substring(0, 300)}…';
  return t;
}

class CloudAiEngine implements AiEngine, CloudModelCatalog {
  CloudAiEngine({
    required this.config,
    required this.keys,
    required this.ledger,
    http.Client Function()? client,
    DateTime Function()? now,
  })  : _newClient = client ?? http.Client.new,
        _now = now ?? DateTime.now;

  /// The person's current choice (read for each request).
  final Future<CloudAiConfig?> Function() config;
  final AiKeyStore keys;
  final AiUsageLedger ledger;
  final http.Client Function() _newClient;
  final DateTime Function() _now;

  http.Client? _active;
  bool _stopped = false;

  @override
  AiEngineSite get site => AiEngineSite.cloud;

  @override
  Future<String?> model() async {
    final c = await config();
    return c == null ? null : '${c.provider.name}:${c.model}';
  }

  Future<(CloudAiConfig, Uri, String)> _ready(CheckedAiRequest request) async {
    if (request.site != site) throw AiEngineFailure(AiEngineFailureKind.wrongSite, 'checked for ${request.site.name}');
    final c = await config();
    if (c == null || c.model.trim().isEmpty) throw const AiEngineFailure(AiEngineFailureKind.notReady, 'no cloud model chosen');
    final base = cloudBaseUri(c);
    final key = await keys.read(c.provider);
    if (key == null || key.trim().isEmpty) {
      throw const AiEngineFailure(AiEngineFailureKind.notReady, 'no key for this provider');
    }
    return (c, base, key.trim());
  }

  Future<void> _checkCap(CloudAiConfig c, List<AiChatMessage> messages, int maxTokens) async {
    final cap = c.monthlyTokenCap;
    if (cap == null) return;
    final used = await ledger.usedInMonthOf(_now());
    final need = estimateAiTokens(messages, maxTokens);
    if (used + need > cap) {
      throw AiEngineFailure(AiEngineFailureKind.capReached, 'used $used of $cap tokens this month; this request may use $need');
    }
  }

  // ---- requests per provider ----------------------------------------------

  String _system(List<AiChatMessage> m) => m.where((x) => x.role == AiRole.system).map((x) => x.text).join('\n\n');
  List<AiChatMessage> _turns(List<AiChatMessage> m) => [for (final x in m) if (x.role != AiRole.system) x];

  http.Request _post(Uri url, Map<String, String> headers, Map<String, Object?> body) => http.Request('POST', url)
    ..headers.addAll({'content-type': 'application/json', ...headers})
    ..body = jsonEncode(body);

  Map<String, String> _auth(CloudProvider p, String key) => switch (p) {
        CloudProvider.anthropic => {'x-api-key': key, 'anthropic-version': '2023-06-01'},
        CloudProvider.gemini => {'x-goog-api-key': key},
        _ => {'authorization': 'Bearer $key'},
      };

  http.Request _request(CloudAiConfig c, Uri base, String key, List<AiChatMessage> messages,
      {required int maxTokens, required bool stream, Map<String, Object?>? schema}) {
    final auth = _auth(c.provider, key);
    switch (c.provider) {
      case CloudProvider.anthropic:
        return _post(_at(base, '/messages'), auth, {
          'model': c.model,
          'max_tokens': maxTokens,
          'system': _system(messages),
          'messages': [
            for (final m in _turns(messages)) {'role': m.role == AiRole.assistant ? 'assistant' : 'user', 'content': m.text},
          ],
          if (stream) 'stream': true,
          if (schema != null) 'output_config': {'format': {'type': 'json_schema', 'schema': schema}},
        });
      case CloudProvider.gemini:
        final path = '/models/${Uri.encodeComponent(c.model)}:${stream ? 'streamGenerateContent' : 'generateContent'}';
        return _post(_at(base, path, stream ? {'alt': 'sse'} : null), auth, {
          'systemInstruction': {
            'parts': [
              {'text': _system(messages)}
            ]
          },
          'contents': [
            for (final m in _turns(messages))
              {
                'role': m.role == AiRole.assistant ? 'model' : 'user',
                'parts': [
                  {'text': m.text}
                ],
              },
          ],
          'generationConfig': {
            'maxOutputTokens': maxTokens,
            if (schema != null) ...{'responseMimeType': 'application/json', 'responseJsonSchema': schema},
          },
        });
      case CloudProvider.openai:
      case CloudProvider.groq:
      case CloudProvider.openaiCompatible:
        return _post(_at(base, '/chat/completions'), auth, {
          'model': c.model,
          'messages': [
            for (final m in messages) {'role': m.role.name, 'content': m.text},
          ],
          // OpenAI and Groq take max_completion_tokens; other servers the
          // older max_tokens.
          if (c.provider == CloudProvider.openaiCompatible) 'max_tokens': maxTokens else 'max_completion_tokens': maxTokens,
          if (stream) ...{'stream': true, 'stream_options': {'include_usage': true}},
          if (schema != null)
            'response_format': {
              'type': 'json_schema',
              'json_schema': {'name': 'lifeflow', 'strict': true, 'schema': schema},
            },
        });
    }
  }

  // ---- sending ---------------------------------------------------------------

  Never _http(int status, String body, String key) {
    String message = body;
    try {
      final j = jsonDecode(body);
      if (j is Map) {
        final e = j['error'];
        message = e is Map ? '${e['message'] ?? e}' : '${e ?? j['message'] ?? body}';
      }
    } on FormatException {
      // not JSON: the text as it is
    }
    final kind = switch (status) {
      401 || 403 => AiEngineFailureKind.unauthorized,
      429 => AiEngineFailureKind.rateLimited,
      _ => AiEngineFailureKind.failed,
    };
    throw AiEngineFailure(kind, 'HTTP $status: ${_clean(message, key)}');
  }

  Future<http.StreamedResponse> _send(http.BaseRequest request, String key) async {
    final client = _newClient();
    _active = client;
    try {
      final res = await client.send(request).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) _http(res.statusCode, await res.stream.bytesToString(), key);
      return res;
    } on AiEngineFailure {
      _close(client);
      rethrow;
    } on Object catch (e) {
      _close(client);
      if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
      throw AiEngineFailure(AiEngineFailureKind.network, _clean('$e', key));
    }
  }

  void _closeActive() {
    final c = _active;
    if (c != null) _close(c);
  }

  void _close(http.Client c) {
    c.close();
    if (identical(_active, c)) _active = null;
  }

  Future<void> _record(CloudAiConfig c, int prompt, int completion) => ledger.record(AiUsageEntry(
      at: _now(), provider: c.provider, model: c.model, promptTokens: prompt, completionTokens: completion));

  @override
  Stream<String> answer(CheckedAiRequest request, {int maxTokens = 800}) async* {
    final (c, base, key) = await _ready(request);
    final messages = aiMessagesOf(request);
    await _checkCap(c, messages, maxTokens);
    _stopped = false;
    final res = await _send(_request(c, base, key, messages, maxTokens: maxTokens, stream: true), key);
    var prompt = 0, completion = 0;
    String? event;
    try {
      await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_stopped) break;
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
          continue;
        }
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') continue;
        final Object? j;
        try {
          j = jsonDecode(payload);
        } on FormatException {
          continue;
        }
        if (j is! Map) continue;
        final d = j.cast<String, Object?>();
        switch (c.provider) {
          case CloudProvider.anthropic:
            if (event == 'error' || d['type'] == 'error') {
              final e = d['error'];
              throw AiEngineFailure(AiEngineFailureKind.failed, _clean('${e is Map ? e['message'] : e}', key));
            }
            final usage = (d['message'] is Map ? (d['message'] as Map)['usage'] : d['usage']);
            if (usage is Map) {
              prompt = (usage['input_tokens'] as int?) ?? prompt;
              completion = (usage['output_tokens'] as int?) ?? completion;
            }
            final delta = d['delta'];
            if (delta is Map && delta['type'] == 'text_delta' && delta['text'] is String) yield delta['text'] as String;
            if (delta is Map && delta['stop_reason'] == 'refusal') {
              throw const AiEngineFailure(AiEngineFailureKind.refused);
            }
          case CloudProvider.gemini:
            final u = d['usageMetadata'];
            if (u is Map) {
              prompt = (u['promptTokenCount'] as int?) ?? prompt;
              completion = ((u['candidatesTokenCount'] as int?) ?? 0) + ((u['thoughtsTokenCount'] as int?) ?? 0);
            }
            final cand = d['candidates'];
            if (cand is List && cand.isNotEmpty && cand.first is Map) {
              final first = cand.first as Map;
              final parts = (first['content'] is Map ? (first['content'] as Map)['parts'] : null);
              if (parts is List) {
                for (final p in parts) {
                  if (p is Map && p['text'] is String && p['thought'] != true) yield p['text'] as String;
                }
              }
              if (first['finishReason'] == 'SAFETY' || first['finishReason'] == 'PROHIBITED_CONTENT') {
                throw const AiEngineFailure(AiEngineFailureKind.refused);
              }
            }
          case CloudProvider.openai:
          case CloudProvider.groq:
          case CloudProvider.openaiCompatible:
            final u = d['usage'];
            if (u is Map) {
              prompt = (u['prompt_tokens'] as int?) ?? prompt;
              completion = (u['completion_tokens'] as int?) ?? completion;
            }
            final ch = d['choices'];
            if (ch is List && ch.isNotEmpty && ch.first is Map) {
              final delta = (ch.first as Map)['delta'];
              if (delta is Map && delta['content'] is String) yield delta['content'] as String;
              if (delta is Map && delta['refusal'] is String) throw const AiEngineFailure(AiEngineFailureKind.refused);
            }
        }
      }
    } on AiEngineFailure {
      rethrow;
    } on Object catch (e) {
      if (!_stopped) throw AiEngineFailure(AiEngineFailureKind.network, _clean('$e', key));
    } finally {
      _closeActive();
      if (prompt > 0 || completion > 0) await _record(c, prompt, completion);
    }
    if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
  }

  /// One structured answer: its JSON text, or a [FormatException] when the
  /// provider cut it or it does not parse.
  Future<String> _structuredOnce(CloudAiConfig c, Uri base, String key, List<AiChatMessage> messages,
      Map<String, Object?> schema, int maxTokens) async {
    final res = await _send(_request(c, base, key, messages, maxTokens: maxTokens, stream: false, schema: schema), key);
    final String body;
    try {
      body = await res.stream.bytesToString();
    } on Object catch (e) {
      if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
      throw AiEngineFailure(AiEngineFailureKind.network, _clean('$e', key));
    } finally {
      _closeActive();
    }
    final j = (jsonDecode(body) as Map).cast<String, Object?>();
    switch (c.provider) {
      case CloudProvider.anthropic:
        final u = j['usage'];
        if (u is Map) await _record(c, (u['input_tokens'] as int?) ?? 0, (u['output_tokens'] as int?) ?? 0);
        if (j['stop_reason'] == 'refusal') throw const AiEngineFailure(AiEngineFailureKind.refused);
        if (j['stop_reason'] == 'max_tokens') throw const FormatException('cut at the token limit');
        return [
          for (final b in (j['content'] as List? ?? const []))
            if (b is Map && b['type'] == 'text') b['text'] as String,
        ].join();
      case CloudProvider.gemini:
        final u = j['usageMetadata'];
        if (u is Map) {
          await _record(c, (u['promptTokenCount'] as int?) ?? 0,
              ((u['candidatesTokenCount'] as int?) ?? 0) + ((u['thoughtsTokenCount'] as int?) ?? 0));
        }
        final cand = (j['candidates'] as List?)?.firstOrNull;
        if (cand is! Map) throw const AiEngineFailure(AiEngineFailureKind.refused, 'no answer');
        if (cand['finishReason'] == 'SAFETY' || cand['finishReason'] == 'PROHIBITED_CONTENT') {
          throw const AiEngineFailure(AiEngineFailureKind.refused);
        }
        if (cand['finishReason'] == 'MAX_TOKENS') throw const FormatException('cut at the token limit');
        final parts = (cand['content'] as Map?)?['parts'] as List? ?? const [];
        return [for (final p in parts) if (p is Map && p['text'] is String && p['thought'] != true) p['text'] as String].join();
      case CloudProvider.openai:
      case CloudProvider.groq:
      case CloudProvider.openaiCompatible:
        final u = j['usage'];
        if (u is Map) await _record(c, (u['prompt_tokens'] as int?) ?? 0, (u['completion_tokens'] as int?) ?? 0);
        final choice = (j['choices'] as List?)?.firstOrNull;
        if (choice is! Map) throw const FormatException('no answer');
        final msg = choice['message'];
        if (msg is Map && msg['refusal'] is String) throw const AiEngineFailure(AiEngineFailureKind.refused);
        if (choice['finish_reason'] == 'length') throw const FormatException('cut at the token limit');
        return (msg is Map ? msg['content'] as String? : null) ?? '';
    }
  }

  @override
  Future<Map<String, Object?>> structured(CheckedAiRequest request,
      {required Map<String, Object?> schema, int maxTokens = 1500}) async {
    final (c, base, key) = await _ready(request);
    final messages = aiMessagesOf(request);
    // Two tries at most (D10: the cap counts both).
    await _checkCap(c, messages, maxTokens * 2);
    _stopped = false;
    String? why;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final v = jsonDecode(await _structuredOnce(c, base, key, messages, schema, maxTokens));
        if (v is Map) return v.cast<String, Object?>();
        why = 'not a JSON object';
      } on FormatException catch (e) {
        why = e.message;
      }
      if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
    }
    throw AiEngineFailure(AiEngineFailureKind.malformedOutput, why ?? '');
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    final c = _active;
    if (c != null) _close(c);
  }

  @override
  Future<List<String>> models(CloudProvider provider, {String? baseUrl}) async {
    final c = CloudAiConfig(provider: provider, model: '-', baseUrl: baseUrl);
    final base = cloudBaseUri(c);
    final key = (await keys.read(provider))?.trim();
    if (key == null || key.isEmpty) throw const AiEngineFailure(AiEngineFailureKind.notReady, 'no key for this provider');
    final res = await _send(http.Request('GET', _at(base, '/models', provider == CloudProvider.gemini ? {'pageSize': '1000'} : null))
      ..headers.addAll(_auth(provider, key)), key);
    final String body;
    try {
      body = await res.stream.bytesToString();
    } finally {
      _closeActive();
    }
    final j = jsonDecode(body) as Map;
    final out = switch (provider) {
      CloudProvider.gemini => [
          for (final m in (j['models'] as List? ?? const []))
            if (m is Map && ((m['supportedGenerationMethods'] as List?)?.contains('generateContent') ?? false))
              (m['name'] as String).replaceFirst('models/', ''),
        ],
      _ => [
          for (final m in (j['data'] as List? ?? const []))
            if (m is Map && m['id'] is String) m['id'] as String,
        ],
    };
    return out..sort();
  }
}

/// The ledger in a JSON file of the app's folder (device data, like the
/// models): the last 13 months are kept.
class FileAiUsageLedger implements AiUsageLedger {
  FileAiUsageLedger(this.file);
  final File file;
  Future<void> _lock = Future.value();

  Future<List<AiUsageEntry>> _read() async {
    if (!await file.exists()) return [];
    try {
      return [
        for (final e in (jsonDecode(await file.readAsString()) as List).cast<Map>())
          if (CloudProvider.values.where((p) => p.name == e['provider']).firstOrNull case final p?)
            AiUsageEntry(
              at: DateTime.fromMillisecondsSinceEpoch(e['at'] as int),
              provider: p,
              model: e['model'] as String,
              promptTokens: e['prompt'] as int,
              completionTokens: e['completion'] as int,
            ),
      ];
    } on Object {
      return [];
    }
  }

  @override
  Future<void> record(AiUsageEntry entry) {
    final done = _lock.then((_) async {
      final cutoff = DateTime(entry.at.year, entry.at.month - 12);
      final all = [for (final e in await _read()) if (!e.at.isBefore(cutoff)) e, entry];
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode([
        for (final e in all)
          {
            'at': e.at.millisecondsSinceEpoch,
            'provider': e.provider.name,
            'model': e.model,
            'prompt': e.promptTokens,
            'completion': e.completionTokens,
          },
      ]), flush: true);
      await tmp.rename(file.path);
    });
    _lock = done.catchError((_) {});
    return done;
  }

  @override
  Future<List<AiUsageEntry>> entriesInMonthOf(DateTime now) async {
    await _lock;
    final l = now.toLocal();
    return [
      for (final e in await _read())
        if (e.at.toLocal().year == l.year && e.at.toLocal().month == l.month) e,
    ];
  }

  @override
  Future<int> usedInMonthOf(DateTime now) async =>
      (await entriesInMonthOf(now)).fold<int>(0, (n, e) => n + e.totalTokens);
}
