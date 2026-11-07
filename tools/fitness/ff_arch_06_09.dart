// FF-ARCH-06 and FF-ARCH-09 (docs/testing/architecture-fitness-functions.md):
// the TEST-BASED fitness functions, plus the static guards that keep those
// tests honest.
//
//   FF-ARCH-06  every mutation command handler writes the atomic set
//               (aggregate + audit + outbox + event + dedupe) in one
//               transaction                         -> LF-INV-GOV-003
//   FF-ARCH-09  every mutation is authorized before the domain method runs
//                                                    -> LF-INV-GOV-002
//
// Static guards (fast, no test run):
//   1. every class implementing CommandHandler is covered by the table-driven
//      atomic-set test (a new handler cannot skip FF-ARCH-06);
//   2. a handler's `apply` is called ONLY by the command gateway;
//   3. in the gateway, authorization comes before the handler, and every
//      governance write sits inside the transaction.
// Then the tagged tests run and must pass with a minimum number of tests.
//
// Run from the repository root:  dart run tools/fitness/ff_arch_06_09.dart
import 'dart:io';

const _infra = 'packages/infrastructure';
const _gateway = '$_infra/lib/src/command_gateway.dart';
const _atomicTest = '$_infra/test/atomic_set_test.dart';

final _failures = <String>[];
void _fail(String m) => _failures.add(m);

List<File> _dartFiles(String dir, {bool includeGenerated = false}) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => includeGenerated || !f.path.endsWith('.g.dart'))
      .toList();
}

String _norm(String p) => p.replaceAll('\\', '/');

void _guardHandlersAreCovered() {
  final handlers = <String, String>{};
  final decl = RegExp(r'class\s+(\w+)\s+implements\s+CommandHandler\b');
  for (final f in _dartFiles('packages')) {
    if (!_norm(f.path).contains('/lib/')) continue;
    for (final m in decl.allMatches(f.readAsStringSync())) {
      handlers[m.group(1)!] = f.path;
    }
  }
  if (handlers.isEmpty) {
    _fail('FF-ARCH-06: found no CommandHandler implementations (scan broken?)');
    return;
  }
  final testText = File(_atomicTest).existsSync()
      ? File(_atomicTest).readAsStringSync()
      : '';
  for (final name in handlers.keys) {
    // Must be exercised, not just mentioned in a comment: look for `Name(`.
    if (!RegExp('\\b$name\\(').hasMatch(testText)) {
      _fail('FF-ARCH-06: handler $name (${_norm(handlers[name]!)}) is not '
          'covered by $_atomicTest');
    }
  }
  stdout.writeln('  guard 1 ok: ${handlers.length} handler(s) covered: '
      '${handlers.keys.join(', ')}');
}

void _guardOnlyGatewayCallsApply() {
  final call = RegExp(r'\bhandler\.apply\(');
  var sites = 0;
  for (final f in _dartFiles('packages')) {
    if (!_norm(f.path).contains('/lib/')) continue;
    final n = call.allMatches(f.readAsStringSync()).length;
    if (n == 0) continue;
    sites += n;
    if (!_norm(f.path).endsWith('infrastructure/lib/src/command_gateway.dart')) {
      _fail('FF-ARCH-06: ${_norm(f.path)} calls handler.apply directly; only '
          'the command gateway may (it adds authorization and the atomic set)');
    }
  }
  if (sites != 1) {
    _fail('FF-ARCH-06: expected exactly one handler.apply call site (the '
        'gateway), found $sites');
  }
  stdout.writeln('  guard 2 ok: handler.apply is called only by the gateway');
}

void _guardGatewayOrder() {
  final text = File(_gateway).readAsStringSync();
  int at(String s) => text.indexOf(s);
  final auth = at('authz.denyReason(');
  final version = at('handler.currentVersion(');
  final apply = at('handler.apply(');
  final tx = at('db.transaction(');
  if ([auth, version, apply, tx].any((i) => i < 0)) {
    _fail('FF-ARCH-09: could not find authorize/currentVersion/apply/'
        'transaction in the gateway (renamed? update this guard)');
    return;
  }
  if (!(auth < version && auth < apply)) {
    _fail('FF-ARCH-09: authorization must come BEFORE the handler in the gateway');
  }
  if (auth > tx) {
    _fail('FF-ARCH-09: authorization must run before the transaction opens');
  }
  for (final w in [
    'db.into(db.auditLog)',
    'db.into(db.outbox)',
    'db.into(db.eventLog)',
    'db.into(db.opDedupe)',
  ]) {
    final i = at(w);
    if (i < 0) {
      _fail('FF-ARCH-06: the gateway no longer writes $w');
    } else if (i < tx) {
      _fail('FF-ARCH-06: $w is written outside the transaction');
    }
  }
  stdout.writeln('  guard 3 ok: authorize -> handler order; all governance '
      'writes inside the transaction');
}

/// Runs the tests with [tag]; returns the number that passed.
int _runTagged(String tag, {required int atLeast}) {
  final r = Process.runSync(
    'dart',
    ['test', '-t', tag, '-r', 'expanded'],
    workingDirectory: _infra,
    runInShell: true,
  );
  final out = '${r.stdout}\n${r.stderr}';
  final passed = RegExp(r'\+(\d+): All tests passed').allMatches(out).lastOrNull;
  if (r.exitCode != 0 || passed == null) {
    _fail('$tag: tests failed (exit ${r.exitCode})');
    stderr.writeln(out.split('\n').take(60).join('\n'));
    return 0;
  }
  final n = int.parse(passed.group(1)!);
  if (n < atLeast) {
    _fail('$tag: only $n test(s) ran, expected at least $atLeast '
        '(tests removed or tag lost?)');
  }
  return n;
}

void main() {
  stdout.writeln('FF-ARCH-06 / FF-ARCH-09 static guards:');
  _guardHandlersAreCovered();
  _guardOnlyGatewayCallsApply();
  _guardGatewayOrder();

  stdout.writeln('FF-ARCH-06 / FF-ARCH-09 tagged tests:');
  final n06 = _runTagged('ff-arch-06', atLeast: 2);
  stdout.writeln('  ff-arch-06: $n06 test(s) passed');
  final n09 = _runTagged('ff-arch-09', atLeast: 7);
  stdout.writeln('  ff-arch-09: $n09 test(s) passed');

  if (_failures.isEmpty) {
    stdout.writeln('FF-ARCH-06/09 OK');
    exit(0);
  }
  stderr.writeln('FF-ARCH-06/09 FAILED:');
  for (final f in _failures) {
    stderr.writeln('  $f');
  }
  exit(1);
}
