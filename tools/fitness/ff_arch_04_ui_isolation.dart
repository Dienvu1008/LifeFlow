// FF-ARCH-04: `ui` does not import infrastructure, Drift/sqlite, or domain
// internals. The UI sees application ports and read models only; the app
// composition root (apps/lifeflow_app) is the single place allowed to wire
// infrastructure (docs/architecture/repository-structure.md).
// See docs/testing/architecture-fitness-functions.md.
import 'dart:io';

const _forbidden = [
  'package:infrastructure/',
  'package:drift/',
  'package:drift_flutter/',
  'package:sqlite3/',
  'package:domain/',
];

void main() {
  final violations = <String>[];
  for (final dir in ['packages/ui/lib', 'packages/ui/test']) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final f in d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!(line.startsWith('import ') || line.startsWith('export '))) continue;
        for (final bad in _forbidden) {
          if (line.contains("'$bad") || line.contains('"$bad')) {
            violations.add('${f.path}:${i + 1}: forbidden $bad');
          }
        }
      }
    }
  }

  // The dependency declaration must not allow it either.
  final pubspec = File('packages/ui/pubspec.yaml');
  if (pubspec.existsSync()) {
    final text = pubspec.readAsStringSync();
    for (final dep in ['infrastructure:', 'drift:', 'drift_flutter:', 'domain:']) {
      if (RegExp('^\\s+${RegExp.escape(dep)}', multiLine: true).hasMatch(text)) {
        violations.add('packages/ui/pubspec.yaml: forbidden dependency $dep');
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('FF-ARCH-04 OK: ui depends on application ports only');
    exit(0);
  }
  stderr.writeln('FF-ARCH-04 FAILED:');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  exit(1);
}
