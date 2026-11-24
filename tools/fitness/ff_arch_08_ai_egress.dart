// FF-ARCH-08 (docs/testing/architecture-fitness-functions.md; LF-INV-PRIV-002,
// LF-INV-PRIV-003, ADR-0081): no egress path takes a Restricted item to a
// cloud model, and every item of an AI request passes the egress checkpoint.
//
// Static guards (fast):
//   1. a request for an engine (`CheckedAiRequest`) has only a private
//      constructor, in the checkpoint's own file: nothing else can make one,
//      so an engine can only be given a checked request;
//   2. the checkpoint decides each item with the domain's rule (aiMaySend),
//      and builds the request from the items it allowed only;
//   3. no other library under packages/ or apps/ builds a request's data
//      from context items (no `'untrusted': true` outside the checkpoint).
// Then the tests tagged ff-arch-08 run (GS-16, the property over random
// contexts, injected text) and must pass with a minimum number of tests.
//
// Run from the repository root:  dart run tools/fitness/ff_arch_08_ai_egress.dart
import 'dart:io';

const _checkpoint = 'packages/application/lib/src/ai.dart';
const _infra = 'packages/infrastructure';

final _failures = <String>[];
void _fail(String m) => _failures.add(m);

String _norm(String p) => p.replaceAll('\\', '/');

Iterable<File> _libFiles() sync* {
  for (final root in ['packages', 'apps']) {
    final d = Directory(root);
    if (!d.existsSync()) continue;
    for (final pkg in d.listSync().whereType<Directory>()) {
      final lib = Directory('${pkg.path}/lib');
      if (!lib.existsSync()) continue;
      for (final f in lib.listSync(recursive: true).whereType<File>()) {
        final p = _norm(f.path);
        if (p.endsWith('.dart') && !p.endsWith('.g.dart')) yield f;
      }
    }
  }
}

void _guardCheckedRequest() {
  final text = File(_checkpoint).readAsStringSync();
  final decl = RegExp(r'final class CheckedAiRequest\s*\{([\s\S]*?)\n\}').firstMatch(text);
  if (decl == null) {
    _fail('FF-ARCH-08: CheckedAiRequest is not a final class in $_checkpoint (moved? update this guard)');
    return;
  }
  final body = decl.group(1)!;
  final ctors = RegExp(r'\bCheckedAiRequest(\.\w+)?\(').allMatches(body).map((m) => m.group(1) ?? '').toList();
  if (ctors.isEmpty) _fail('FF-ARCH-08: CheckedAiRequest has no constructor (scan broken?)');
  for (final c in ctors) {
    if (!c.startsWith('._')) _fail('FF-ARCH-08: CheckedAiRequest has a public constructor "CheckedAiRequest$c"');
  }
  for (final f in _libFiles()) {
    if (_norm(f.path).endsWith(_checkpoint)) continue;
    if (RegExp(r'CheckedAiRequest\._').hasMatch(f.readAsStringSync())) {
      _fail('FF-ARCH-08: ${_norm(f.path)} builds a CheckedAiRequest; only the checkpoint may');
    }
  }
  stdout.writeln('  guard 1 ok: only the checkpoint can build a request for an engine');
}

void _guardCheckpointUsesTheRule() {
  final text = File(_checkpoint).readAsStringSync();
  final fn = RegExp(r'CheckedAiRequest checkAiEgress\(\{[\s\S]*?\}\)\s*\{([\s\S]*?)\n\}').firstMatch(text);
  if (fn == null) {
    _fail('FF-ARCH-08: checkAiEgress not found in $_checkpoint');
    return;
  }
  final body = fn.group(1)!;
  final rule = body.indexOf('aiMaySend(');
  final skip = body.indexOf('if (!sent) continue;');
  final add = body.indexOf('data.add(');
  if (rule < 0 || skip < 0 || add < 0 || !(rule < skip && skip < add)) {
    _fail('FF-ARCH-08: the checkpoint must decide each item with aiMaySend and add only the items sent');
  }
  stdout.writeln('  guard 2 ok: the checkpoint decides every item with the domain rule');
}

void _guardNoOtherRequestData() {
  final tag = RegExp(r"""['"]untrusted['"]\s*:\s*true""");
  for (final f in _libFiles()) {
    if (_norm(f.path).endsWith(_checkpoint)) continue;
    if (tag.hasMatch(f.readAsStringSync())) {
      _fail('FF-ARCH-08: ${_norm(f.path)} builds tagged request data itself; only the checkpoint may');
    }
  }
  stdout.writeln('  guard 3 ok: no other library builds request data');
}

int _runTagged(String tag, {required int atLeast}) {
  final r = Process.runSync('dart', ['test', '-t', tag, '-r', 'expanded'], workingDirectory: _infra, runInShell: true);
  final out = '${r.stdout}\n${r.stderr}';
  final passed = RegExp(r'\+(\d+): All tests passed').allMatches(out).lastOrNull;
  if (r.exitCode != 0 || passed == null) {
    _fail('$tag: tests failed (exit ${r.exitCode})');
    stderr.writeln(out.split('\n').take(60).join('\n'));
    return 0;
  }
  final n = int.parse(passed.group(1)!);
  if (n < atLeast) _fail('$tag: only $n test(s) ran, expected at least $atLeast (tests removed or tag lost?)');
  return n;
}

void main() {
  stdout.writeln('FF-ARCH-08 static guards:');
  _guardCheckedRequest();
  _guardCheckpointUsesTheRule();
  _guardNoOtherRequestData();
  stdout.writeln('FF-ARCH-08 tagged tests:');
  final n = _runTagged('ff-arch-08', atLeast: 10);
  stdout.writeln('  ff-arch-08: $n test(s) passed');
  if (_failures.isEmpty) {
    stdout.writeln('FF-ARCH-08 OK');
    exit(0);
  }
  stderr.writeln('FF-ARCH-08 FAILED:');
  for (final f in _failures) {
    stderr.writeln('  $f');
  }
  exit(1);
}
