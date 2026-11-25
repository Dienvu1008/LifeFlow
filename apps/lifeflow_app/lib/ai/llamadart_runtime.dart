// P06 T4 (ADR-0083; D3 after spike S-17): llama.cpp through llamadart, bound
// to the engine's runtime port. Thin on purpose: what the app decides
// (site, model choice, prompt, retries, stop) is in LocalAiEngine and is
// tested headless; this file only translates. Thinking is off: with it on,
// small models spent the whole budget thinking and cut the JSON (S-17).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:llamadart/llamadart.dart';

class LlamadartRuntime implements LocalRuntime {
  LlamadartRuntime();

  // Made on first use: the native runtime is loaded only when a model is.
  LlamaEngine? _made;
  LlamaEngine get _engine => _made ??= LlamaEngine(LlamaBackend());

  static List<LlamaChatMessage> _messages(List<AiChatMessage> messages) => [
        for (final m in messages)
          LlamaChatMessage.fromText(
            role: switch (m.role) {
              AiRole.system => LlamaChatRole.system,
              AiRole.user => LlamaChatRole.user,
              AiRole.assistant => LlamaChatRole.assistant,
            },
            text: m.text,
          ),
      ];

  @override
  Future<void> load(String path, {int contextSize = 8192}) =>
      _engine.setModel(LlamaModel(ModelSource.parse(path)), params: ModelParams(contextSize: contextSize));

  @override
  Stream<String> generate(List<AiChatMessage> messages, {int maxTokens = 800, double temperature = 0.3}) async* {
    await for (final c in _engine.create(_messages(messages),
        params: GenerationParams(maxTokens: maxTokens, temp: temperature), enableThinking: false)) {
      if (c.text.isNotEmpty) yield c.text;
    }
  }

  @override
  Future<String> generateJson(List<AiChatMessage> messages, Map<String, Object?> schema, {int maxTokens = 1500}) async {
    try {
      final out = await _engine.createStructuredJson(
        _messages(messages),
        output: LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(
            schema: schema.cast<String, dynamic>(), decoder: (j) => j),
        params: GenerationParams(maxTokens: maxTokens, temp: 0),
        enableThinking: false,
      );
      return jsonEncode(out);
    } on LlamaInferenceException catch (e) {
      final text = '$e';
      if (text.contains('Malformed structured JSON') || text.contains('did not match the requested schema')) {
        throw FormatException(text);
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel() async => _made?.cancelGeneration();

  @override
  Future<void> unload() async => _made?.unloadModel();

  Future<void> dispose() async {
    await _made?.dispose();
    _made = null;
  }
}
