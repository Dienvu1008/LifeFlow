// FF-ARCH-10 (P03 UX U1, ADR-0045, U-D11): user-facing text in the UI comes
// from the ARB file (packages/ui/lib/l10n/app_en.arb), not from literals.
// A ratchet: tools/fitness/ui_strings_baseline.txt records, per file, how
// many raw UI literals are left (screens not migrated yet, plain helpers).
// The check fails when a file has MORE than its baseline, or a new file has
// any. When strings are moved, lower the baseline:
//   dart run tools/fitness/ff_arch_10_ui_strings.dart --update
// (`--update` refuses to raise a number.)
import 'dart:io';

const _lib = 'packages/ui/lib';
const _baseline = 'tools/fitness/ui_strings_baseline.txt';

final _named = [
  'tooltip', 'labelText', 'hintText', 'helperText', 'errorText', 'semanticsLabel', 'semanticLabel',
  'label', 'title', 'subtitle', 'message', 'confirmLabel', 'helpText', 'cancelText', 'confirmText', 'counterText',
];
const _lit = r"'((?:[^'\\\n]|\\.)*)'";
final _patterns = <RegExp>[
  RegExp(r'\bText\(\s*' + _lit),
  RegExp(r'\b(?:' + _named.join('|') + r'):\s*' + _lit),
  RegExp(r'\bshowMessage\(\s*context,\s*' + _lit),
];

bool _looksLikeKey(String s) => !s.contains(' ') && RegExp(r'^[a-z0-9_.:/@#-]*$').hasMatch(s);

/// Raw UI literals per file (generated localization files excluded).
Map<String, int> count() {
  final out = <String, int>{};
  for (final f in Directory(_lib).listSync(recursive: true).whereType<File>()) {
    final path = f.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || path.contains('/src/l10n/')) continue;
    final src = f.readAsStringSync();
    var n = 0;
    for (final p in _patterns) {
      for (final m in p.allMatches(src)) {
        final raw = m.group(1)!;
        if (raw.trim().isEmpty || _looksLikeKey(raw)) continue;
        n++;
      }
    }
    if (n > 0) out[path] = n;
  }
  return out;
}

Map<String, int> readBaseline() {
  final f = File(_baseline);
  if (!f.existsSync()) return {};
  return {
    for (final line in f.readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        line.substring(0, line.lastIndexOf(' ')).trim(): int.parse(line.substring(line.lastIndexOf(' ') + 1)),
  };
}

void main(List<String> args) {
  final now = count();
  final base = readBaseline();
  if (args.contains('--update')) {
    final raised = [
      for (final e in now.entries)
        if (e.value > (base[e.key] ?? 0)) '${e.key}: ${base[e.key] ?? 0} -> ${e.value}'
    ];
    if (raised.isNotEmpty && base.isNotEmpty && !args.contains('--init')) {
      stderr.writeln('FF-ARCH-10: --update never raises a count; move these strings to the ARB file:');
      raised.forEach(stderr.writeln);
      exit(1);
    }
    final keys = now.keys.toList()..sort();
    File(_baseline).writeAsStringSync([
      '# FF-ARCH-10 baseline: raw UI literals left per file (lower it as strings move to app_en.arb).',
      for (final k in keys) '$k ${now[k]}',
      '',
    ].join('\n'));
    stdout.writeln('FF-ARCH-10 baseline written: ${now.values.fold<int>(0, (a, b) => a + b)} literals in ${now.length} files');
    return;
  }
  final over = [
    for (final e in now.entries)
      if (e.value > (base[e.key] ?? 0)) '${e.key}: ${e.value} raw UI strings (baseline ${base[e.key] ?? 0})'
  ];
  if (over.isNotEmpty) {
    stderr.writeln('FF-ARCH-10 FAILED: user-facing strings must come from packages/ui/lib/l10n/app_en.arb '
        '(context.l10n). Move them, e.g. with tools/l10n/migrate.ps1:');
    over.forEach(stderr.writeln);
    exit(1);
  }
  stdout.writeln('FF-ARCH-10 OK: ${now.values.fold<int>(0, (a, b) => a + b)} raw UI strings left in ${now.length} files '
      '(none above the baseline)');
}
