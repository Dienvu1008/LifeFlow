// S-17 (throwaway): can a small model run inside LifeFlow on Windows and
// Android with llamadart (llama.cpp), well enough in Vietnamese?
//   load      a model from a short list (downloaded once from Hugging Face,
//             kept in the app's cache) or a GGUF file on disk
//   tests     fixed prompts: a Vietnamese day plan as strict JSON (checked:
//             it parses, uses only the given task ids, no overlap with the
//             fixed events); a Vietnamese summary; a question about a
//             Vietnamese text; an English summary; and a free prompt
//   measured  load time, reply time, tokens per second, memory of the app
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:llamadart/llamadart.dart';

Future<void> main(List<String> args) async {
  // `p06_probe.exe smoke <model> <out.txt>`: no window work, results to a file.
  if (args.isNotEmpty && args.first == 'smoke') {
    WidgetsFlutterBinding.ensureInitialized();
    final out = File(args.length > 2 ? args[2] : 's17_smoke.txt');
    await smoke(args.length > 1 ? args[1] : models.first.$2, (s) => out.writeAsStringSync('$s\n', mode: FileMode.append));
    exit(0);
  }
  runApp(const MaterialApp(home: Probe(), debugShowCheckedModeBanner: false));
}

Future<void> smoke(String source, void Function(String) say) async {
  final engine = LlamaEngine(LlamaBackend());
  try {
    final sw = Stopwatch()..start();
    await engine.setModel(LlamaModel(ModelSource.parse(source)), params: const ModelParams(contextSize: 4096));
    say('load ${sw.elapsedMilliseconds} ms runtime=${engine.runtime} rss=${ProcessInfo.currentRss ~/ (1 << 20)} MB model=$source');
    Future<void> ask(String name, String text) async {
      sw.reset();
      final b = StringBuffer();
      LlamaCompletionChunk? last;
      int? first;
      await for (final c in engine.create([LlamaChatMessage.fromText(role: LlamaChatRole.user, text: text)],
          params: const GenerationParams(maxTokens: 300, temp: 0.2), enableThinking: false)) {
        if (c.text.isNotEmpty) first ??= sw.elapsedMilliseconds;
        b.write(c.text);
        last = c;
      }
      final ms = sw.elapsedMilliseconds;
      final tok = last?.usage?.completionTokens ?? 0;
      say('$name: $ms ms, first ${first ?? '?'} ms, $tok tokens, ${first == null || ms == first ? '?' : (tok * 1000 / (ms - first)).toStringAsFixed(1)} tok/s, rss ${ProcessInfo.currentRss ~/ (1 << 20)} MB');
      say('  >> ${b.toString().replaceAll('\n', ' | ')}');
    }
    await ask('vi question', 'Dựa vào văn bản sau, trả lời ngắn: hạn nộp quỹ khuyến học là ngày nào, nộp cho ai, bao nhiêu tiền?\n$viText');
    await ask('vi summary', 'Tóm tắt văn bản sau thành 3 gạch đầu dòng, bằng tiếng Việt:\n$viText');
    await ask('en summary', 'Summarize in 3 bullet points:\n$enText');
    sw.reset();
    try {
      final plan = await engine.createStructuredJson(
        [
          const LlamaChatMessage.fromText(role: LlamaChatRole.system, text: 'Bạn là trợ lý lập kế hoạch. Chỉ trả lời bằng JSON đúng mẫu.'),
          LlamaChatMessage.fromText(
              role: LlamaChatRole.user,
              text: 'Hôm nay là thứ Tư. Tôi làm việc từ 08:00 đến 18:00. Lịch cố định (không được chồng lên): ${jsonEncode(planEvents)}. '
                  'Việc cần làm: ${jsonEncode(planTasks)}. Hãy xếp các việc vào giờ trống trong ngày, việc quan trọng trước. '
                  'Chỉ dùng các taskId đã cho. "reason" và "note" viết bằng tiếng Việt.'),
        ],
        output: LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(schema: planSchema, decoder: (j) => j),
        params: const GenerationParams(maxTokens: 1500, temp: 0),
        enableThinking: false,
      );
      say('plan: ${sw.elapsedMilliseconds} ms; ${checkPlan(plan)}');
      say('  >> ${jsonEncode(plan)}');
    } catch (e) {
      say('plan failed after ${sw.elapsedMilliseconds} ms: $e');
    }
  } catch (e) {
    say('failed: $e');
  } finally {
    await engine.dispose();
  }
}

const models = <(String, String)>[
  ('Qwen 3.5 0.8B (Q4_K_M, Apache-2.0)', 'hf://unsloth/Qwen3.5-0.8B-GGUF/Qwen3.5-0.8B-Q4_K_M.gguf'),
  ('Qwen 3.5 2B (Q4_K_M, Apache-2.0)', 'hf://unsloth/Qwen3.5-2B-GGUF/Qwen3.5-2B-Q4_K_M.gguf'),
  ('Qwen 3.5 4B (Q4_K_M, Apache-2.0)', 'hf://unsloth/Qwen3.5-4B-GGUF/Qwen3.5-4B-Q4_K_M.gguf'),
  ('Gemma 4 E2B (Q4_K_M)', 'hf://unsloth/gemma-4-E2B-it-GGUF/gemma-4-E2B-it-Q4_K_M.gguf'),
];

const viText = '''Biên bản họp tổ dân phố số 5, phường Hải Châu, Đà Nẵng, ngày 2 tháng 11.
Cuộc họp bàn ba việc. Thứ nhất, vệ sinh đường phố vào sáng Chủ nhật hằng tuần, mỗi hộ cử một người, bắt đầu lúc 6 giờ 30.
Thứ hai, thu quỹ khuyến học năm nay là 100.000 đồng mỗi hộ, hạn nộp ngày 30 tháng 11, nộp cho chị Lan tổ trưởng.
Thứ ba, đề nghị phường lắp thêm hai bóng đèn đường ở kiệt 12 vì buổi tối quá tối, nhiều người đi lại khó khăn.
Cuộc họp kết thúc lúc 21 giờ, có 34 trên 40 hộ tham dự.''';

const enText = '''Our team met on Monday to review the launch. The beta found two problems: sign-in fails on some Android phones,
and the PDF viewer is slow on files over 200 pages. We agreed to fix sign-in first, because it blocks new users.
Minh will look at the PDF speed next week. The launch moves from November 20 to December 4. Budget stays the same.''';

const planTasks = [
  {'id': 't1', 'title': 'Viết báo cáo quý cho sếp', 'minutes': 90, 'priority': 'high'},
  {'id': 't2', 'title': 'Gọi điện cho mẹ', 'minutes': 15, 'priority': 'medium'},
  {'id': 't3', 'title': 'Đi chợ mua đồ nấu phở', 'minutes': 45, 'priority': 'medium'},
  {'id': 't4', 'title': 'Đọc 20 trang sách tiếng Anh', 'minutes': 30, 'priority': 'low'},
  {'id': 't5', 'title': 'Nộp quỹ khuyến học cho chị Lan', 'minutes': 10, 'priority': 'high'},
];
const planEvents = [
  {'title': 'Họp nhóm dự án', 'start': '09:00', 'end': '10:30'},
  {'title': 'Ăn trưa với khách hàng', 'start': '12:00', 'end': '13:30'},
];

const planSchema = {
  'type': 'object',
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'taskId': {'type': 'string'},
          'start': {'type': 'string', 'pattern': r'^[0-2][0-9]:[0-5][0-9]$'},
          'minutes': {'type': 'integer'},
          'reason': {'type': 'string'},
        },
        'required': ['taskId', 'start', 'minutes', 'reason'],
        'additionalProperties': false,
      },
    },
    'note': {'type': 'string'},
  },
  'required': ['items', 'note'],
  'additionalProperties': false,
};

/// Parses, uses only given ids, within 08:00-18:00, no overlap with events or each other.
String checkPlan(Map<String, dynamic> plan) {
  int m(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
  final ids = {for (final t in planTasks) t['id']};
  final busy = [for (final e in planEvents) (m(e['start']!), m(e['end']!))];
  final problems = <String>[];
  final items = (plan['items'] as List).cast<Map<String, dynamic>>();
  for (final i in items) {
    final id = i['taskId'] as String;
    if (!ids.contains(id)) problems.add('unknown id $id');
    final s = m(i['start'] as String), e = s + (i['minutes'] as int);
    if (s < 480 || e > 1080) problems.add('$id outside working hours');
    for (final (a, b) in busy) {
      if (s < b && a < e) problems.add('$id overlaps an event');
    }
    busy.add((s, e));
  }
  final missing = ids.difference({for (final i in items) i['taskId']});
  if (missing.isNotEmpty) problems.add('not placed: ${missing.join(',')}');
  return problems.isEmpty ? 'OK (${items.length} tasks placed)' : problems.join('; ');
}


class Probe extends StatefulWidget {
  const Probe({super.key});
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  final _engine = LlamaEngine(LlamaBackend());
  final _prompt = TextEditingController(text: 'Hãy giải thích ngắn gọn bằng tiếng Việt: vì sao nên ngủ đủ 8 tiếng?');
  final _log = <String>[];
  String _model = models.first.$2;
  bool _busy = false;
  bool _loaded = false;
  double? _download;
  String _output = '';
  String _status = 'No model loaded';

  void _note(String s) {
    setState(() => _log.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)} $s'));
  }

  String get _memory => '${(ProcessInfo.currentRss / (1024 * 1024)).toStringAsFixed(0)} MB';

  Future<void> _load(String source) async {
    setState(() {
      _busy = true;
      _loaded = false;
      _download = null;
      _status = 'Loading $source';
    });
    final sw = Stopwatch()..start();
    try {
      await _engine.setModel(
        LlamaModel(ModelSource.parse(source)),
        params: const ModelParams(contextSize: 4096),
        onProgress: (p) => setState(() => _download = p.fraction),
      );
      _loaded = true;
      _status = 'Loaded ${source.split('/').last} in ${sw.elapsedMilliseconds} ms; runtime ${_engine.runtime}; app memory $_memory';
      _note(_status);
    } catch (e) {
      _status = 'Load failed: $e';
      _note(_status);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickFile() async {
    final f = await openFile(acceptedTypeGroups: [const XTypeGroup(label: 'GGUF', extensions: ['gguf'])]);
    if (f != null) await _load(f.path);
  }

  Future<void> _run(String name, List<LlamaChatMessage> messages, {int maxTokens = 400}) async {
    if (!_loaded || _busy) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    final sw = Stopwatch()..start();
    int? firstMs;
    LlamaCompletionChunk? last;
    final out = StringBuffer();
    try {
      await for (final c in _engine.create(messages,
          params: GenerationParams(maxTokens: maxTokens, temp: 0.3), enableThinking: false)) {
        if (c.text.isNotEmpty) {
          firstMs ??= sw.elapsedMilliseconds;
          out.write(c.text);
          setState(() => _output = out.toString());
        }
        last = c;
      }
      final ms = sw.elapsedMilliseconds;
      final tokens = last?.usage?.completionTokens;
      final speed = tokens == null || firstMs == null || ms == firstMs ? '?' : (tokens * 1000 / (ms - firstMs)).toStringAsFixed(1);
      _note('$name: ${ms} ms, first word after ${firstMs ?? '?'} ms, $tokens tokens, $speed tokens/s, prompt ${last?.usage?.promptTokens} tokens, memory $_memory');
    } catch (e) {
      _note('$name failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _plan() async {
    if (!_loaded || _busy) return;
    setState(() {
      _busy = true;
      _output = '';
    });
    final sw = Stopwatch()..start();
    try {
      final prompt = 'Hôm nay là thứ Tư. Tôi làm việc từ 08:00 đến 18:00. '
          'Lịch cố định (không được chồng lên): ${jsonEncode(planEvents)}. '
          'Việc cần làm: ${jsonEncode(planTasks)}. '
          'Hãy xếp các việc vào giờ trống trong ngày, việc quan trọng trước. '
          'Chỉ dùng các taskId đã cho. "reason" và "note" viết bằng tiếng Việt.';
      final result = await _engine.createStructuredJson(
        [
          const LlamaChatMessage.fromText(role: LlamaChatRole.system, text: 'Bạn là trợ lý lập kế hoạch. Chỉ trả lời bằng JSON đúng mẫu.'),
          LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt),
        ],
        output: LlamaStructuredOutput<Map<String, dynamic>>.jsonSchema(schema: planSchema, decoder: (j) => j),
        params: const GenerationParams(maxTokens: 1500, temp: 0),
        enableThinking: false,
      );
      final check = checkPlan(result);
      setState(() => _output = '${const JsonEncoder.withIndent('  ').convert(result)}\n\nCHECK: $check');
      _note('plan: ${sw.elapsedMilliseconds} ms; $check; memory $_memory');
    } catch (e) {
      _note('plan failed after ${sw.elapsedMilliseconds} ms: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LlamaChatMessage u(String t) => LlamaChatMessage.fromText(role: LlamaChatRole.user, text: t);
    return Scaffold(
      appBar: AppBar(title: const Text('S-17 local model probe')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        DropdownButton<String>(
          isExpanded: true,
          value: _model,
          items: [for (final (n, s) in models) DropdownMenuItem(value: s, child: Text(n))],
          onChanged: _busy ? null : (v) => setState(() => _model = v!),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: _busy ? null : () => _load(_model), child: const Text('Load (downloads once)')),
          OutlinedButton(onPressed: _busy ? null : _pickFile, child: const Text('Use a GGUF file')),
        ]),
        if (_download != null && _download! < 1) LinearProgressIndicator(value: _download),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_status)),
        const Divider(),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonal(onPressed: _loaded && !_busy ? _plan : null, child: const Text('1. Day plan (VI, JSON)')),
          FilledButton.tonal(
              onPressed: _loaded && !_busy ? () => _run('vi summary', [u('Tóm tắt văn bản sau thành 3 gạch đầu dòng, bằng tiếng Việt:\n$viText')]) : null,
              child: const Text('2. Summary (VI)')),
          FilledButton.tonal(
              onPressed: _loaded && !_busy
                  ? () => _run('vi question', [u('Dựa vào văn bản sau, trả lời ngắn: hạn nộp quỹ khuyến học là ngày nào, nộp cho ai, bao nhiêu tiền?\n$viText')])
                  : null,
              child: const Text('3. Question (VI)')),
          FilledButton.tonal(
              onPressed: _loaded && !_busy ? () => _run('en summary', [u('Summarize in 3 bullet points:\n$enText')]) : null,
              child: const Text('4. Summary (EN)')),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _prompt, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Free prompt')),
        Row(children: [
          FilledButton.tonal(onPressed: _loaded && !_busy ? () => _run('free', [u(_prompt.text)], maxTokens: 600) : null, child: const Text('5. Send')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _busy ? _engine.cancelGeneration : null, child: const Text('Stop')),
        ]),
        const SizedBox(height: 8),
        SelectableText(_output.isEmpty ? '(reply)' : _output),
        const Divider(),
        Row(children: [
          const Text('Log'),
          const Spacer(),
          TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: _log.reversed.join('\n'))), child: const Text('Copy log')),
        ]),
        for (final l in _log) Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ]),
    );
  }
}
