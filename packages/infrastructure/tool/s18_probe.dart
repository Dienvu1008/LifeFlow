// S-18 (throwaway probe, P06): the same prompts as S-17, through the real
// cloud engine, against each provider the owner has a key for.
//
// Keys come only from the environment, never from a file or the command line:
//   LIFEFLOW_S18_OPENAI_KEY, LIFEFLOW_S18_GEMINI_KEY,
//   LIFEFLOW_S18_ANTHROPIC_KEY, LIFEFLOW_S18_GROQ_KEY
// and optionally the model of each (else the models are listed and the run
// stops for that provider):
//   LIFEFLOW_S18_OPENAI_MODEL, …
// Run from packages/infrastructure:  dart run tool/s18_probe.dart [out.txt]
// The output has the answers, times, tokens and the plan check; never a key.
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:infrastructure/infrastructure.dart';

class _EnvKeys implements AiKeyStore {
  @override
  Future<String?> read(CloudProvider p) async => Platform.environment['LIFEFLOW_S18_${p.name.toUpperCase()}_KEY'];
  @override
  Future<void> write(CloudProvider p, String k) async {}
  @override
  Future<void> delete(CloudProvider p) async {}
}

const viText = '''Biên bản họp tổ dân phố số 5, phường Hải Châu, Đà Nẵng, ngày 2 tháng 11.
Cuộc họp bàn ba việc. Thứ nhất, vệ sinh đường phố vào sáng Chủ nhật hằng tuần, mỗi hộ cử một người, bắt đầu lúc 6 giờ 30.
Thứ hai, thu quỹ khuyến học năm nay là 100.000 đồng mỗi hộ, hạn nộp ngày 30 tháng 11, nộp cho chị Lan tổ trưởng.
Thứ ba, đề nghị phường lắp thêm hai bóng đèn đường ở kiệt 12 vì buổi tối quá tối, nhiều người đi lại khó khăn.
Cuộc họp kết thúc lúc 21 giờ, có 34 trên 40 hộ tham dự.''';

const enText = '''Our team met on Monday to review the launch. The beta found two problems: sign-in fails on some Android phones,
and the PDF viewer is slow on files over 200 pages. We agreed to fix sign-in first, because it blocks new users.
Minh will look at the PDF speed next week. The launch moves from November 20 to December 4. Budget stays the same.''';

const tasks = [
  {'id': 't1', 'title': 'Viết báo cáo quý cho sếp', 'minutes': 90, 'priority': 'high'},
  {'id': 't2', 'title': 'Gọi điện cho mẹ', 'minutes': 15, 'priority': 'medium'},
  {'id': 't3', 'title': 'Đi chợ mua đồ nấu phở', 'minutes': 45, 'priority': 'medium'},
  {'id': 't4', 'title': 'Đọc 20 trang sách tiếng Anh', 'minutes': 30, 'priority': 'low'},
  {'id': 't5', 'title': 'Nộp quỹ khuyến học cho chị Lan', 'minutes': 10, 'priority': 'high'},
];
const events = [
  {'title': 'Họp nhóm dự án', 'start': '09:00', 'end': '10:30'},
  {'title': 'Ăn trưa với khách hàng', 'start': '12:00', 'end': '13:30'},
];
const planSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'taskId': {'type': 'string'},
          'start': {'type': 'string'},
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

String checkPlan(Map<String, Object?> plan) {
  int m(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
  final ids = {for (final t in tasks) t['id']};
  final busy = [for (final e in events) (m(e['start']!), m(e['end']!))];
  final problems = <String>[];
  final items = (plan['items'] as List).cast<Map>();
  for (final i in items) {
    final id = i['taskId'] as String;
    if (!ids.contains(id)) problems.add('unknown id $id');
    final int s;
    try {
      s = m(i['start'] as String);
    } on Object {
      problems.add('$id: bad start ${i['start']}');
      continue;
    }
    final e = s + (i['minutes'] as int);
    if (s < 480 || e > 1080) problems.add('$id outside working hours');
    for (final (a, b) in busy) {
      if (s < b && a < e) problems.add('$id overlaps');
    }
    busy.add((s, e));
  }
  final missing = ids.difference({for (final i in items) i['taskId']});
  if (missing.isNotEmpty) problems.add('not placed: ${missing.join(',')}');
  return problems.isEmpty ? 'OK (${items.length} placed)' : problems.join('; ');
}

CheckedAiRequest ask(String instructions, String question, [String? text]) => checkAiEgress(
      site: AiEngineSite.cloud,
      policy: const AiEgressPolicy(cloudEnabled: true),
      context: AiContext([
        if (text != null)
          AiContextItem(ref: const RecordRef('document', 'd1'), classification: DataClassification.personal, title: 'Văn bản', text: text),
      ]),
      instructions: instructions,
      question: question,
    );

Future<void> main(List<String> args) async {
  final out = File(args.isNotEmpty ? args.first : 's18_results.txt');
  void say(String s) {
    stdout.writeln(s);
    out.writeAsStringSync('$s\n', mode: FileMode.append);
  }

  final dir = Directory.systemTemp.createTempSync('lifeflow_s18_');
  final keys = _EnvKeys();
  for (final p in [CloudProvider.openai, CloudProvider.gemini, CloudProvider.anthropic, CloudProvider.groq]) {
    if (await keys.read(p) == null) {
      say('== ${p.label}: no key (LIFEFLOW_S18_${p.name.toUpperCase()}_KEY), skipped');
      continue;
    }
    final model = Platform.environment['LIFEFLOW_S18_${p.name.toUpperCase()}_MODEL'];
    final ledger = FileAiUsageLedger(File('${dir.path}/${p.name}.json'));
    CloudAiConfig? cfg = model == null ? null : CloudAiConfig(provider: p, model: model);
    final engine = CloudAiEngine(config: () async => cfg, keys: keys, ledger: ledger);
    if (model == null) {
      try {
        final list = await engine.models(p);
        say('== ${p.label}: set LIFEFLOW_S18_${p.name.toUpperCase()}_MODEL to one of (${list.length}): ${list.join(', ')}');
      } on AiEngineFailure catch (e) {
        say('== ${p.label}: models failed: $e');
      }
      continue;
    }
    say('== ${p.label} / $model');
    Future<void> run(String name, CheckedAiRequest r, {int maxTokens = 400}) async {
      final before = await ledger.usedInMonthOf(DateTime.now());
      final sw = Stopwatch()..start();
      int? first;
      final b = StringBuffer();
      try {
        await for (final t in engine.answer(r, maxTokens: maxTokens)) {
          first ??= sw.elapsedMilliseconds;
          b.write(t);
        }
        final used = await ledger.usedInMonthOf(DateTime.now()) - before;
        say('$name: ${sw.elapsedMilliseconds} ms, first word ${first ?? '?'} ms, $used tokens');
        say('  >> ${b.toString().replaceAll('\n', ' | ')}');
      } on AiEngineFailure catch (e) {
        say('$name failed after ${sw.elapsedMilliseconds} ms: $e');
      }
    }

    const brief = 'Answer briefly, in the language of the question.';
    await run('vi question', ask(brief, 'Hạn nộp quỹ khuyến học là ngày nào, nộp cho ai, bao nhiêu tiền?', viText));
    await run('vi summary', ask(brief, 'Tóm tắt văn bản thành 3 gạch đầu dòng, bằng tiếng Việt.', viText));
    await run('en summary', ask(brief, 'Summarize in 3 bullet points.', enText));
    final sw = Stopwatch()..start();
    final before = await ledger.usedInMonthOf(DateTime.now());
    try {
      final plan = await engine.structured(
          ask('You plan the day. Answer only with JSON following the schema.',
              'Hôm nay là thứ Tư. Tôi làm việc từ 08:00 đến 18:00. Lịch cố định (không được chồng lên): ${jsonEncode(events)}. '
                  'Việc cần làm: ${jsonEncode(tasks)}. Hãy xếp các việc vào giờ trống, việc quan trọng trước. '
                  'Chỉ dùng các taskId đã cho; "start" là HH:MM. "reason" và "note" viết bằng tiếng Việt.'),
          schema: planSchema,
          maxTokens: 1500);
      final used = await ledger.usedInMonthOf(DateTime.now()) - before;
      say('plan: ${sw.elapsedMilliseconds} ms, $used tokens; ${checkPlan(plan)}');
      say('  >> ${jsonEncode(plan)}');
    } on AiEngineFailure catch (e) {
      say('plan failed after ${sw.elapsedMilliseconds} ms: $e');
    }
  }
  dir.deleteSync(recursive: true);
  say('done; results in ${out.path}');
}
