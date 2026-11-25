// P06 T5 (ADR-0085): the cloud engine against a local server speaking each
// provider's format.
//   site      only a cloud-checked request; Restricted never on the wire,
//             even consented (GS-16 at the wire); Confidential only consented
//   ready     no model, no key, an http:// address: refused, nothing sent
//   wire      OpenAI, Groq, an OpenAI-compatible address, Anthropic, Gemini:
//             the address, the key in its header (never the URL), the
//             system message, the answer streamed, the tokens recorded
//   JSON      each provider's schema mode; cut or broken: asked again once,
//             then refused; a refusal is a refusal
//   errors    a bad key, a rate limit, a server error, no connection; the
//             key never in a message
//   cap       a request that could go over the monthly cap is not sent
//   stop      the answer ends as stopped
//   models    listed from the provider
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const key = 'sk-test-SECRET-123';

class _Keys implements AiKeyStore {
  final map = <CloudProvider, String>{};
  @override
  Future<void> delete(CloudProvider p) async => map.remove(p);
  @override
  Future<String?> read(CloudProvider p) async => map[p];
  @override
  Future<void> write(CloudProvider p, String k) async => map[p] = k;
}

class _Seen {
  _Seen(this.method, this.uri, this.headers, this.body);
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final String body;
  Map<String, Object?> get json => (jsonDecode(body) as Map).cast<String, Object?>();
}

/// Answers by what the test sets for the next requests.
class _Server {
  late HttpServer http;
  final seen = <_Seen>[];
  final replies = <Future<void> Function(HttpResponse)>[];

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen((req) async {
      seen.add(_Seen(req.method, req.uri, req.headers, await utf8.decoder.bind(req).join()));
      final reply = replies.isEmpty ? _status(500, '{"error":{"message":"no reply set"}}') : replies.removeAt(0);
      await reply(req.response);
    });
  }

  String get base => 'http://127.0.0.1:${http.port}/v1';
}

Future<void> Function(HttpResponse) _status(int code, String body) => (r) async {
      r.statusCode = code;
      r.headers.contentType = ContentType.json;
      r.add(utf8.encode(body));
      await r.close();
    };

Future<void> Function(HttpResponse) _json(Object body) => _status(200, jsonEncode(body));

Future<void> Function(HttpResponse) _sse(List<String> lines, {Completer<void>? hold}) => (r) async {
      r.headers.contentType = ContentType('text', 'event-stream');
      r.bufferOutput = false;
      for (final (i, l) in lines.indexed) {
        if (i == 1 && hold != null) await hold.future;
        r.add(utf8.encode('$l\n'));
        await r.flush();
      }
      await r.close();
    };

CheckedAiRequest request({
  AiEngineSite site = AiEngineSite.cloud,
  List<AiContextItem> items = const [],
  Set<RecordRef> consented = const {},
}) =>
    checkAiEgress(
      site: site,
      policy: const AiEgressPolicy(cloudEnabled: true),
      context: AiContext(items),
      instructions: 'You help plan the day.',
      question: 'Tóm tắt giúp tôi',
      consented: consented,
    );

const planSchema = {
  'type': 'object',
  'properties': {'note': {'type': 'string'}},
  'required': ['note'],
  'additionalProperties': false,
};

void main() {
  late _Server server;
  late _Keys keys;
  late Directory dir;
  late FileAiUsageLedger ledger;
  late CloudAiConfig? cfg;
  late CloudAiEngine engine;
  var now = DateTime(2026, 11, 4, 9);

  setUp(() async {
    server = _Server();
    await server.start();
    keys = _Keys();
    dir = Directory.systemTemp.createTempSync('lifeflow_cloud_');
    ledger = FileAiUsageLedger(File('${dir.path}/usage.json'));
    now = DateTime(2026, 11, 4, 9);
    cfg = null;
    engine = CloudAiEngine(config: () async => cfg, keys: keys, ledger: ledger, now: () => now);
  });
  tearDown(() async {
    await server.http.close(force: true);
    dir.deleteSync(recursive: true);
  });

  void use(CloudProvider p, {String model = 'm-1', int? cap, String? base}) {
    cfg = CloudAiConfig(provider: p, model: model, baseUrl: base ?? server.base, monthlyTokenCap: cap);
    keys.map[p] = key;
  }

  Matcher fails(AiEngineFailureKind k) => throwsA(isA<AiEngineFailure>().having((e) => e.kind, 'kind', k));

  group('what may be sent', () {
    test('only a request checked for the cloud', () async {
      use(CloudProvider.openai);
      await expectLater(engine.answer(request(site: AiEngineSite.device)).toList(), fails(AiEngineFailureKind.wrongSite));
      expect(server.seen, isEmpty);
    });

    test('GS-16 at the wire: Restricted never sent, even consented; Confidential only consented', () async {
      use(CloudProvider.openai);
      const health = RecordRef('measurement', 'm1');
      const note = RecordRef('document', 'd1');
      const list = RecordRef('taskList', 'l1');
      final items = [
        const AiContextItem(ref: health, classification: DataClassification.restricted, title: 'Nhịp tim', text: 'HEART_RATE_92'),
        const AiContextItem(ref: note, classification: DataClassification.confidential, title: 'Ghi chú', text: 'PRIVATE_NOTE'),
        const AiContextItem(ref: list, classification: DataClassification.personal, title: 'Việc nhà', text: 'PERSONAL_LIST'),
      ];
      server.replies.add(_sse(['data: {"choices":[{"delta":{"content":"ok"}}]}', 'data: [DONE]']));
      await engine.answer(request(items: items, consented: {health})).drain<void>();
      server.replies.add(_sse(['data: {"choices":[{"delta":{"content":"ok"}}]}', 'data: [DONE]']));
      await engine.answer(request(items: items, consented: {health, note})).drain<void>();
      final [first, second] = server.seen;
      for (final s in server.seen) {
        expect(s.body, isNot(contains('HEART_RATE_92')));
        expect(s.body, contains('PERSONAL_LIST'));
      }
      expect(first.body, isNot(contains('PRIVATE_NOTE')));
      expect(second.body, contains('PRIVATE_NOTE'));
    });

    test('not ready: no model, no key, or an address that is not https; nothing sent', () async {
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.notReady));
      cfg = CloudAiConfig(provider: CloudProvider.openai, model: 'm', baseUrl: server.base);
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.notReady));
      keys.map[CloudProvider.openai] = '   ';
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.notReady), reason: 'a blank key');
      use(CloudProvider.openaiCompatible, base: 'http://example.org/v1');
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.notReady));
      use(CloudProvider.openaiCompatible, base: '');
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.notReady));
      expect(server.seen, isEmpty);
      expect(cloudBaseUri(const CloudAiConfig(provider: CloudProvider.groq, model: 'x')).toString(),
          'https://api.groq.com/openai/v1');
    });
  });

  group('the wire, per provider', () {
    for (final p in [CloudProvider.openai, CloudProvider.groq, CloudProvider.openaiCompatible]) {
      test('${p.name}: chat completions, a bearer key, streamed, tokens recorded', () async {
        use(p);
        server.replies.add(_sse([
          'data: {"choices":[{"delta":{"role":"assistant"}}]}',
          'data: {"choices":[{"delta":{"content":"Xin "}}]}',
          'data: {"choices":[{"delta":{"content":"chào"}}]}',
          'data: {"choices":[],"usage":{"prompt_tokens":40,"completion_tokens":2}}',
          'data: [DONE]',
        ]));
        expect(await engine.answer(request(), maxTokens: 50).join(), 'Xin chào');
        final s = server.seen.single;
        expect(s.uri.path, '/v1/chat/completions');
        expect(s.uri.query, isEmpty);
        expect(s.headers.value('authorization'), 'Bearer $key');
        final j = s.json;
        expect(j['model'], 'm-1');
        expect(j['stream'], true);
        expect(j['stream_options'], {'include_usage': true});
        expect(j[p == CloudProvider.openaiCompatible ? 'max_tokens' : 'max_completion_tokens'], 50);
        final msgs = (j['messages'] as List).cast<Map>();
        expect([for (final m in msgs) m['role']], ['system', 'user']);
        expect(msgs.first['content'], contains(aiUntrustedDataRule));
        final e = (await ledger.entriesInMonthOf(now)).single;
        expect((e.provider, e.model, e.promptTokens, e.completionTokens), (p, 'm-1', 40, 2));
      });
    }

    test('anthropic: messages, x-api-key and version, the system apart, streamed, tokens recorded', () async {
      use(CloudProvider.anthropic);
      server.replies.add(_sse([
        'event: message_start',
        'data: {"type":"message_start","message":{"usage":{"input_tokens":55,"output_tokens":1}}}',
        'event: content_block_delta',
        'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Xin "}}',
        'event: content_block_delta',
        'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"chào"}}',
        'event: message_delta',
        'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":3}}',
        'event: message_stop',
        'data: {"type":"message_stop"}',
      ]));
      expect(await engine.answer(request(), maxTokens: 64).join(), 'Xin chào');
      final s = server.seen.single;
      expect(s.uri.path, '/v1/messages');
      expect(s.headers.value('x-api-key'), key);
      expect(s.headers.value('anthropic-version'), '2023-06-01');
      expect(s.headers.value('authorization'), isNull);
      final j = s.json;
      expect(j['system'], contains(aiUntrustedDataRule));
      expect([for (final m in (j['messages'] as List).cast<Map>()) m['role']], ['user']);
      expect(j['max_tokens'], 64);
      final e = (await ledger.entriesInMonthOf(now)).single;
      expect((e.promptTokens, e.completionTokens), (55, 3));
    });

    test('gemini: streamGenerateContent with alt=sse, the key in a header, never in the URL', () async {
      use(CloudProvider.gemini, model: 'gemini-x-flash');
      server.replies.add(_sse([
        'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Xin "}]}}]}',
        'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"thinking","thought":true},{"text":"chào"}]},'
            '"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":30,"candidatesTokenCount":4,"thoughtsTokenCount":6}}',
      ]));
      expect(await engine.answer(request(), maxTokens: 64).join(), 'Xin chào', reason: 'thoughts are not the answer');
      final s = server.seen.single;
      expect(s.uri.path, '/v1/models/gemini-x-flash:streamGenerateContent');
      expect(s.uri.queryParameters, {'alt': 'sse'});
      expect(s.uri.toString(), isNot(contains(key)));
      expect(s.headers.value('x-goog-api-key'), key);
      final j = s.json;
      expect(((j['systemInstruction'] as Map)['parts'] as List).single['text'], contains(aiUntrustedDataRule));
      expect((j['generationConfig'] as Map)['maxOutputTokens'], 64);
      final e = (await ledger.entriesInMonthOf(now)).single;
      expect((e.promptTokens, e.completionTokens), (30, 10), reason: 'thinking tokens are paid too');
    });
  });

  group('structured answers', () {
    test('openai: json_schema strict', () async {
      use(CloudProvider.openai);
      server.replies.add(_json({
        'choices': [
          {'finish_reason': 'stop', 'message': {'role': 'assistant', 'content': '{"note":"Ổn"}'}}
        ],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 5},
      }));
      expect(await engine.structured(request(), schema: planSchema), {'note': 'Ổn'});
      final rf = server.seen.single.json['response_format'] as Map;
      expect(rf['type'], 'json_schema');
      expect((rf['json_schema'] as Map)['strict'], true);
      expect((rf['json_schema'] as Map)['schema'], planSchema);
      expect(server.seen.single.json.containsKey('stream'), isFalse);
      expect(await ledger.usedInMonthOf(now), 15);
    });

    test('anthropic: output_config.format', () async {
      use(CloudProvider.anthropic);
      server.replies.add(_json({
        'content': [
          {'type': 'text', 'text': '{"note":"Ổn"}'}
        ],
        'stop_reason': 'end_turn',
        'usage': {'input_tokens': 10, 'output_tokens': 5},
      }));
      expect(await engine.structured(request(), schema: planSchema), {'note': 'Ổn'});
      expect(server.seen.single.json['output_config'], {
        'format': {'type': 'json_schema', 'schema': planSchema}
      });
    });

    test('gemini: generateContent with responseJsonSchema', () async {
      use(CloudProvider.gemini, model: 'g');
      server.replies.add(_json({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '{"note":"Ổn"}'}
              ]
            },
            'finishReason': 'STOP'
          }
        ],
        'usageMetadata': {'promptTokenCount': 10, 'candidatesTokenCount': 5},
      }));
      expect(await engine.structured(request(), schema: planSchema), {'note': 'Ổn'});
      final s = server.seen.single;
      expect(s.uri.path, '/v1/models/g:generateContent');
      final g = s.json['generationConfig'] as Map;
      expect(g['responseMimeType'], 'application/json');
      expect(g['responseJsonSchema'], planSchema);
    });

    test('cut at the limit or broken: asked again once, then refused', () async {
      use(CloudProvider.openai);
      Map<String, Object?> reply(String content, String finish) => {
            'choices': [
              {'finish_reason': finish, 'message': {'content': content}}
            ]
          };
      server.replies
        ..add(_json(reply('{"note":"Ổ"}', 'length'))) // parses, but cut: not trusted
        ..add(_json(reply('{"note":"Ổn"}', 'stop')));
      expect(await engine.structured(request(), schema: planSchema), {'note': 'Ổn'});
      server.replies
        ..add(_json(reply('{"note":', 'stop')))
        ..add(_json(reply('[1]', 'stop')));
      await expectLater(engine.structured(request(), schema: planSchema), fails(AiEngineFailureKind.malformedOutput));
      expect(server.seen, hasLength(4));
    });

    test('a refusal is a refusal, not asked again', () async {
      use(CloudProvider.openai);
      server.replies.add(_json({
        'choices': [
          {'finish_reason': 'stop', 'message': {'content': null, 'refusal': 'I cannot help with that.'}}
        ]
      }));
      await expectLater(engine.structured(request(), schema: planSchema), fails(AiEngineFailureKind.refused));
      use(CloudProvider.anthropic);
      server.replies.add(_json({'content': [], 'stop_reason': 'refusal'}));
      await expectLater(engine.structured(request(), schema: planSchema), fails(AiEngineFailureKind.refused));
      expect(server.seen, hasLength(2));
    });
  });

  group('errors', () {
    test('a bad key, a rate limit, a server error; the key never in the message', () async {
      use(CloudProvider.openai);
      for (final (code, kind) in [
        (401, AiEngineFailureKind.unauthorized),
        (403, AiEngineFailureKind.unauthorized),
        (429, AiEngineFailureKind.rateLimited),
        (503, AiEngineFailureKind.rateLimited), // S-18: Gemini under high demand
        (529, AiEngineFailureKind.rateLimited),
        (500, AiEngineFailureKind.failed),
      ]) {
        server.replies.add(_status(code, '{"error":{"message":"Incorrect API key provided: $key"}}'));
        try {
          await engine.answer(request()).drain<void>();
          fail('expected $kind');
        } on AiEngineFailure catch (e) {
          expect(e.kind, kind);
          expect(e.message, contains('HTTP $code'));
          expect(e.message, isNot(contains(key)));
          expect(e.toString(), isNot(contains(key)));
        }
      }
      expect(await ledger.usedInMonthOf(now), 0);
    });

    test('no connection', () async {
      use(CloudProvider.openai, base: 'http://127.0.0.1:1/v1');
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.network));
    });

    test('an error event in an Anthropic stream', () async {
      use(CloudProvider.anthropic);
      server.replies.add(_sse([
        'event: error',
        'data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}',
      ]));
      await expectLater(engine.answer(request()).toList(), fails(AiEngineFailureKind.failed));
    });
  });

  group('the monthly cap (D10)', () {
    test('a request that could go over it is not sent; the month turns', () async {
      use(CloudProvider.openai, cap: 1000);
      await ledger.record(AiUsageEntry(
          at: now, provider: CloudProvider.openai, model: 'm-1', promptTokens: 600, completionTokens: 100));
      final r = request();
      expect(estimateAiTokens([AiChatMessage(AiRole.user, 'a' * 300)], 100), 200, reason: 'a token is about 3 characters');
      final need = estimateAiTokens(aiMessagesOf(r), 400);
      expect(need, greaterThan(300));
      await expectLater(engine.answer(r, maxTokens: 400).toList(), fails(AiEngineFailureKind.capReached));
      await expectLater(engine.structured(r, schema: planSchema, maxTokens: 200), fails(AiEngineFailureKind.capReached),
          reason: 'two tries are counted');
      expect(server.seen, isEmpty);

      now = DateTime(2026, 12, 1, 0, 1);
      server.replies.add(_sse(['data: {"choices":[{"delta":{"content":"ok"}}]}', 'data: [DONE]']));
      expect(await engine.answer(r, maxTokens: 400).join(), 'ok', reason: 'a new month');
    });
  });

  test('stop ends the answer as stopped', () async {
    use(CloudProvider.openai);
    final hold = Completer<void>();
    server.replies.add(_sse([
      'data: {"choices":[{"delta":{"content":"Một "}}]}',
      'data: {"choices":[{"delta":{"content":"hai"}}]}',
      'data: [DONE]',
    ], hold: hold));
    final got = <String>[];
    final done = engine.answer(request()).listen(got.add).asFuture<void>();
    while (got.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final ended = expectLater(done, fails(AiEngineFailureKind.stopped));
    await engine.stop();
    hold.complete();
    await ended;
    expect(got, ['Một ']);
  });

  group('models', () {
    test('listed from the provider: OpenAI-style data and Gemini models', () async {
      use(CloudProvider.groq);
      server.replies.add(_json({
        'data': [
          {'id': 'b-model'},
          {'id': 'a-model'}
        ]
      }));
      expect(await engine.models(CloudProvider.groq, baseUrl: server.base), ['a-model', 'b-model']);
      expect(server.seen.last.uri.path, '/v1/models');
      expect(server.seen.last.headers.value('authorization'), 'Bearer $key');

      keys.map[CloudProvider.gemini] = key;
      server.replies.add(_json({
        'models': [
          {'name': 'models/gemini-x', 'supportedGenerationMethods': ['generateContent', 'countTokens']},
          {'name': 'models/embed-x', 'supportedGenerationMethods': ['embedContent']},
        ]
      }));
      expect(await engine.models(CloudProvider.gemini, baseUrl: server.base), ['gemini-x']);
      expect(server.seen.last.uri.toString(), isNot(contains(key)));
      await expectLater(engine.models(CloudProvider.anthropic, baseUrl: server.base), fails(AiEngineFailureKind.notReady));
    });
  });

  group('the ledger', () {
    test('by month, kept across a restart, only 13 months kept, a broken file is empty', () async {
      final f = File('${dir.path}/u2.json');
      final a = FileAiUsageLedger(f);
      await a.record(AiUsageEntry(
          at: DateTime(2025, 12, 3), provider: CloudProvider.gemini, model: 'g', promptTokens: 7, completionTokens: 0));
      for (final m in [1, 2, 11]) {
        await a.record(AiUsageEntry(
            at: DateTime(2026, m, 3), provider: CloudProvider.gemini, model: 'g', promptTokens: m, completionTokens: 1));
      }
      expect(await FileAiUsageLedger(f).usedInMonthOf(DateTime(2026, 11, 20)), 12);
      await Future.wait([
        for (var i = 0; i < 5; i++)
          a.record(AiUsageEntry(
              at: DateTime(2027, 1, 5), provider: CloudProvider.groq, model: 'q', promptTokens: 1, completionTokens: 1)),
      ]);
      expect(await a.usedInMonthOf(DateTime(2027, 1, 9)), 10, reason: 'records at once are all kept');
      expect(await a.usedInMonthOf(DateTime(2026, 1, 9)), 2, reason: '13 months are kept: January 2026 too');
      expect(await a.usedInMonthOf(DateTime(2025, 12, 9)), 0, reason: 'older is dropped');
      // A write that fails does not stop the next ones.
      final g = File('${dir.path}/u3.json');
      Directory('${g.path}.tmp').createSync();
      final b = FileAiUsageLedger(g);
      final e1 = AiUsageEntry(at: DateTime(2027, 1, 5), provider: CloudProvider.groq, model: 'q', promptTokens: 1, completionTokens: 1);
      await expectLater(b.record(e1), throwsA(isA<FileSystemException>()));
      Directory('${g.path}.tmp').deleteSync();
      await b.record(e1);
      expect(await b.usedInMonthOf(DateTime(2027, 1, 9)), 2);
      f.writeAsStringSync('{broken');
      expect(await FileAiUsageLedger(f).usedInMonthOf(DateTime(2027, 1, 9)), 0);
    });
  });
}
