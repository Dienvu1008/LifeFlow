// P06 T4 (ADR-0083; D3 after spike S-17): the model engine on this device.
// The runtime (llama.cpp through llamadart) is bound in the app; here is
// what does not depend on it, so it is tested headless with a fake runtime:
//   - only a request checked for this device (ADR-0081);
//   - the model the person chose, loaded once and again when they change it;
//   - the answer streamed; a stop ends it;
//   - a structured answer parsed, and asked again once when it does not
//     parse (S-17: 1 plan in 5 came back broken), never used broken.
import 'dart:async';
import 'dart:convert';

import 'package:application/application.dart';

/// What the app needs from a local runtime.
abstract interface class LocalRuntime {
  Future<void> load(String path, {int contextSize});

  /// The answer as it is written. Ends early after [cancel].
  Stream<String> generate(List<AiChatMessage> messages, {int maxTokens, double temperature});

  /// JSON text following [schema]. Throws [FormatException] when the model's
  /// output is not valid JSON.
  Future<String> generateJson(List<AiChatMessage> messages, Map<String, Object?> schema, {int maxTokens});
  Future<void> cancel();
  Future<void> unload();
}

class LocalAiEngine implements AiEngine {
  LocalAiEngine(this.runtime, this.models, {this.contextSize = 8192});
  final LocalRuntime runtime;
  final LocalModelService models;
  final int contextSize;

  String? _loadedPath;
  String? _loadedName;
  Future<void>? _loading;
  bool _stopped = false;

  @override
  AiEngineSite get site => AiEngineSite.device;

  @override
  Future<String?> model() async => (await models.selected())?.name;

  void _checkSite(CheckedAiRequest request) {
    if (request.site != site) {
      throw AiEngineFailure(AiEngineFailureKind.wrongSite, 'checked for ${request.site.name}');
    }
  }

  /// The chosen model, loaded.
  Future<void> _ready() async {
    final m = await models.selected();
    if (m == null) throw const AiEngineFailure(AiEngineFailureKind.notReady, 'no model chosen');
    if (_loadedPath == m.path) return;
    if (_loading != null) {
      await _loading;
      if (_loadedPath == m.path) return;
    }
    final load = () async {
      if (_loadedPath != null) await runtime.unload();
      _loadedPath = null;
      try {
        await runtime.load(m.path, contextSize: contextSize);
      } on Object catch (e) {
        throw AiEngineFailure(AiEngineFailureKind.failed, 'the model could not be loaded: $e');
      }
      _loadedPath = m.path;
      _loadedName = m.name;
    }();
    _loading = load;
    try {
      await load;
    } finally {
      _loading = null;
    }
  }

  /// The loaded model's name (after a request).
  String? get loadedModel => _loadedName;

  @override
  Stream<String> answer(CheckedAiRequest request, {int maxTokens = 800}) async* {
    _checkSite(request);
    await _ready();
    _stopped = false;
    try {
      yield* runtime.generate(aiMessagesOf(request), maxTokens: maxTokens, temperature: 0.3);
    } on AiEngineFailure {
      rethrow;
    } on Object catch (e) {
      throw AiEngineFailure(AiEngineFailureKind.failed, '$e');
    }
    if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
  }

  @override
  Future<Map<String, Object?>> structured(CheckedAiRequest request,
      {required Map<String, Object?> schema, int maxTokens = 1500}) async {
    _checkSite(request);
    await _ready();
    _stopped = false;
    final messages = aiMessagesOf(request);
    String? why;
    for (var attempt = 0; attempt < 2; attempt++) {
      final String text;
      try {
        text = await runtime.generateJson(messages, schema, maxTokens: maxTokens);
      } on FormatException catch (e) {
        if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
        why = e.message;
        continue;
      } on Object catch (e) {
        if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
        throw AiEngineFailure(AiEngineFailureKind.failed, '$e');
      }
      if (_stopped) throw const AiEngineFailure(AiEngineFailureKind.stopped);
      try {
        final v = jsonDecode(text);
        if (v is Map) return v.cast<String, Object?>();
        why = 'not a JSON object';
      } on FormatException catch (e) {
        why = e.message;
      }
    }
    throw AiEngineFailure(AiEngineFailureKind.malformedOutput, why ?? '');
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await runtime.cancel();
  }

  /// Frees the model's memory (the person deleted it, or left the assistant).
  Future<void> unload() async {
    if (_loadedPath == null) return;
    await runtime.unload();
    _loadedPath = null;
    _loadedName = null;
  }
}
