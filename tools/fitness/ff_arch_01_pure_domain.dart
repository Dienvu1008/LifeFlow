// FF-ARCH-01 (scaffold stub, runnable): domain/*, time_kernel and foundation
// import no Flutter, Drift, Supabase or platform SDK.
// See docs/testing/architecture-fitness-functions.md. This is a minimal
// import scan; P01 hardens it (allowlist, all packages, CI wiring).
import 'dart:io';

const _forbidden = [
  "package:flutter/",
  "package:drift/",
  "package:supabase",
  "dart:ui",
];
const _purePackages = ['foundation', 'time_kernel', 'domain'];

void main() {
  final root = Directory('packages');
  final violations = <String>[];
  for (final pkg in _purePackages) {
    final libDir = Directory('${root.path}/$pkg/lib');
    if (!libDir.existsSync()) continue;
    for (final f in libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))) {
      final text = f.readAsStringSync();
      for (final bad in _forbidden) {
        if (text.contains("import '$bad") || text.contains('import "$bad')) {
          violations.add('${f.path}: forbidden import $bad');
        }
      }
    }
  }
  if (violations.isEmpty) {
    stdout.writeln('FF-ARCH-01 OK: pure packages have no forbidden imports');
    exit(0);
  }
  stderr.writeln('FF-ARCH-01 FAILED:');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  exit(1);
}
