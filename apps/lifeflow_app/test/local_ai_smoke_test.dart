// P06 T4 (ADR-0083): the real runtime (llama.cpp through llamadart) with a
// real model, end to end: the person's file is imported and known by its
// hash, chosen, loaded, asked in Vietnamese, and asked for a JSON plan.
// Runs only with LIFEFLOW_TEST_GGUF set to a model file of the list (for
// example Qwen3.5-0.8B-Q4_K_M.gguf); CI has no model. Under `flutter test`
// on Windows, also set LLAMADART_BACKEND_MODULE_DIR to the app's
// build/native_assets/windows (the backend modules the app bundles).
import 'dart:io';

import 'package:application/application.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:lifeflow_app/ai/llamadart_runtime.dart';

void main() {
  final gguf = Platform.environment['LIFEFLOW_TEST_GGUF'];

  test('a real model answers and plans through the engine', () async {
    final dir = Directory.systemTemp.createTempSync('lifeflow_local_ai_');
    final runtime = LlamadartRuntime();
    try {
      final models = FileLocalModelService(Directory('${dir.path}/models'), platform: LocalPlatform.windows);
      final m = await models.importFile(gguf!);
      expect(m.fromFile, isFalse, reason: 'a file of the list is known by its hash');
      await models.select(m.id);
      final engine = LocalAiEngine(runtime, models, contextSize: 4096);

      CheckedAiRequest ask(String q) => checkAiEgress(
            site: AiEngineSite.device,
            policy: const AiEgressPolicy(scopeIncludesConfidential: true),
            context: const AiContext([
              AiContextItem(
                  ref: RecordRef('document', 'd1'),
                  classification: DataClassification.confidential,
                  title: 'Biên bản họp tổ dân phố',
                  text: 'Thu quỹ khuyến học 100.000 đồng mỗi hộ, hạn nộp ngày 30 tháng 11, nộp cho chị Lan tổ trưởng.'),
            ]),
            instructions: 'Answer briefly, in the language of the question.',
            question: q,
          );

      final sw = Stopwatch()..start();
      final text = await engine.answer(ask('Hạn nộp quỹ khuyến học là ngày nào, nộp cho ai?'), maxTokens: 120).join();
      // ignore: avoid_print
      print('answer in ${sw.elapsedMilliseconds} ms: $text');
      expect(text, contains('30'));
      expect(text, contains('Lan'));

      final plan = await engine.structured(ask('Liệt kê việc cần làm từ văn bản.'), schema: const {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {'title': {'type': 'string'}},
              'required': ['title'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      }, maxTokens: 300);
      expect(plan['items'], isA<List<Object?>>());
    } finally {
      await runtime.dispose();
      dir.deleteSync(recursive: true);
    }
  }, skip: gguf == null ? 'set LIFEFLOW_TEST_GGUF to a model file of the list' : false, timeout: const Timeout(Duration(minutes: 5)));
}
