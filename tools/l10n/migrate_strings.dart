// P03 UX U1 (ADR-0045): moves user-facing string literals of UI files into
// packages/ui/lib/l10n/app_en.arb and replaces them with `context.l10n.key`.
// The English text stays the same, so the widget tests (which find text)
// stay valid. Used on the screens that stay (U1) and on new screens.
//
//   dart run tools/l10n/migrate_strings.dart extract <file.dart>...
//       Replaces the literals and adds their keys to the ARB file.
//   dart run tools/l10n/migrate_strings.dart fix <analyzer-output.txt>
//       Repairs what `flutter analyze` reports after an extract: removes a
//       `const` that no longer applies, and puts a literal back where no
//       `context` is in scope (those are moved by hand).
//   dart run tools/l10n/migrate_strings.dart prune
//       Drops ARB keys no file uses.
//
// Only simple literals in UI positions are moved (Text(...), tooltip:,
// label:, title:, labelText:, ... and showMessage(context, ...)).
// Literals concatenated with others are left for a manual move.
import 'dart:convert';
import 'dart:io';

const arbPath = 'packages/ui/lib/l10n/app_en.arb';
const uiLib = 'packages/ui/lib';

final _named = [
  'tooltip', 'labelText', 'hintText', 'helperText', 'errorText', 'semanticsLabel', 'semanticLabel',
  'label', 'title', 'subtitle', 'message', 'confirmLabel', 'helpText', 'cancelText', 'confirmText', 'counterText',
];

// A single-quoted Dart string literal (no raw strings).
const _lit = r"'((?:[^'\\\n]|\\.)*)'";

final _patterns = <RegExp>[
  RegExp(r'\bText\(\s*' + _lit),
  RegExp(r'\b(?:' + _named.join('|') + r'):\s*' + _lit),
  RegExp(r'\bshowMessage\(\s*context,\s*' + _lit),
];

Map<String, Object?> readArb() => (jsonDecode(File(arbPath).readAsStringSync()) as Map).cast<String, Object?>();

void writeArb(Map<String, Object?> arb) =>
    File(arbPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(arb)}\n');

String _camel(String text) {
  final words = text
      .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+|\{\w+\}'), ' ')
      .replaceAll(RegExp(r"[^A-Za-z0-9 ]"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(6)
      .toList();
  if (words.isEmpty) return 'text';
  final b = StringBuffer(words.first.toLowerCase());
  for (final w in words.skip(1)) {
    b.write(w[0].toUpperCase() + w.substring(1).toLowerCase());
  }
  var k = b.toString();
  if (RegExp(r'^[0-9]').hasMatch(k)) k = 't$k';
  if (_reserved.contains(k)) k = '${k}Label';
  return k;
}

const _reserved = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'covariant', 'default', 'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
  'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide', 'if', 'implements', 'import', 'in',
  'interface', 'is', 'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required', 'rethrow',
  'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type',
  'typedef', 'var', 'void', 'when', 'while', 'with', 'yield', 'localeName', 'text',
};

/// The message (ICU) and the arguments of a literal's text.
(String message, List<(String name, String expr)> args) _message(String raw) {
  final args = <(String, String)>[];
  final used = <String>{};
  String nameFor(String expr) {
    final m = RegExp(r'^[A-Za-z_][\w.]*$').firstMatch(expr);
    var n = m == null ? 'value' : expr.split('.').last.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (n.isEmpty || n.startsWith(RegExp(r'[0-9]'))) n = 'value';
    var unique = n;
    var i = 2;
    while (!used.add(unique)) {
      unique = '$n${i++}';
    }
    return unique;
  }

  final out = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    final c = raw[i];
    if (c == r'\' && i + 1 < raw.length) {
      final n = raw[i + 1];
      out.write(switch (n) { 'n' => '\n', 't' => '\t', _ => n });
      i += 2;
      continue;
    }
    if (c == r'$') {
      if (i + 1 < raw.length && raw[i + 1] == '{') {
        var depth = 1, j = i + 2;
        while (j < raw.length && depth > 0) {
          if (raw[j] == '{') depth++;
          if (raw[j] == '}') depth--;
          j++;
        }
        final expr = raw.substring(i + 2, j - 1).trim();
        final name = nameFor(expr);
        args.add((name, expr));
        out.write('{$name}');
        i = j;
        continue;
      }
      final m = RegExp(r'^\$([A-Za-z_]\w*)').firstMatch(raw.substring(i));
      if (m != null) {
        final name = nameFor(m.group(1)!);
        args.add((name, m.group(1)!));
        out.write('{$name}');
        i += m.group(0)!.length;
        continue;
      }
    }
    out.write(c);
    i++;
  }
  return (out.toString(), args);
}

bool _looksLikeKey(String s) => !s.contains(' ') && RegExp(r'^[a-z0-9_.:/@#-]*$').hasMatch(s);

void extract(List<String> files) {
  final arb = readArb();
  final byText = <String, String>{
    for (final e in arb.entries)
      if (!e.key.startsWith('@') && e.value is String) e.value as String: e.key,
  };
  var moved = 0;
  for (final path in files) {
    final f = File(path);
    var src = f.readAsStringSync();
    final edits = <(int start, int end, String text)>[];
    for (final p in _patterns) {
      for (final m in p.allMatches(src)) {
        final raw = m.group(1)!;
        final litStart = m.start + m.group(0)!.lastIndexOf("'$raw'");
        final litEnd = litStart + raw.length + 2;
        if (raw.trim().isEmpty || _looksLikeKey(raw)) continue;
        // A quote inside an interpolation ('${a ? 'x' : 'y'}') cut the
        // literal short: leave it for a manual move.
        if ('{'.allMatches(raw).length != '}'.allMatches(raw).length) continue;
        // Adjacent literals ('a' 'b') or a concatenation: by hand.
        final after = src.substring(litEnd).trimLeft();
        if (after.startsWith("'") || after.startsWith('+')) continue;
        final before = src.substring(0, litStart).trimRight();
        if (before.endsWith("'") || before.endsWith('+')) continue;
        if (edits.any((e) => e.$1 == litStart)) continue;
        final (message, args) = _message(raw);
        String? found = byText[message];
        late final String key;
        if (found != null) {
          key = found;
        } else {
          final base = _camel(message);
          var candidate = base;
          var n = 2;
          while (arb.containsKey(candidate)) {
            candidate = '$base${n++}';
          }
          key = candidate;
          arb[key] = message;
          if (args.isNotEmpty) {
            arb['@$key'] = {
              'placeholders': {for (final (name, _) in args) name: {'type': 'Object'}},
            };
          }
          byText[message] = key;
        }
        final call = args.isEmpty ? 'context.l10n.$key' : 'context.l10n.$key(${args.map((a) => a.$2).join(', ')})';
        edits.add((litStart, litEnd, call));
      }
    }
    if (edits.isEmpty) continue;
    edits.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (s, e, t) in edits) {
      src = src.replaceRange(s, e, t);
    }
    if (!src.contains("l10n.dart'")) {
      final rel = _relativeL10n(path);
      final firstImport = RegExp(r"^import '[^']+';\r?$", multiLine: true).allMatches(src).lastOrNull;
      if (firstImport != null) {
        final nl = src.contains('\r\n') ? '\r\n' : '\n';
        src = src.replaceRange(firstImport.end, firstImport.end, "${nl}import '$rel';");
      }
    }
    f.writeAsStringSync(src);
    moved += edits.length;
    stdout.writeln('$path: ${edits.length}');
  }
  writeArb(arb);
  stdout.writeln('moved $moved literals; ARB has ${arb.keys.where((k) => !k.startsWith('@')).length} keys');
}

String _relativeL10n(String path) {
  final dir = File(path).parent.path.replaceAll(r'\', '/');
  final lib = '$uiLib/src';
  final depth = dir.length <= lib.length ? 0 : dir.substring(lib.length + 1).split('/').length;
  return '${'../' * depth}l10n.dart';
}

/// Repairs after an extract, from `flutter analyze` output lines such as
/// "error - Invalid constant value - lib\src\x.dart:12:34 - invalid_constant".
void fix(String analyzerOutput) {
  final arb = readArb();
  final keyText = {for (final e in arb.entries) if (!e.key.startsWith('@')) e.key: e.value};
  final line = RegExp(r'error - (.*?) - (\S+\.dart):(\d+):(\d+) - (\w+)');
  final constCodes = {
    'invalid_constant',
    'const_with_non_constant_argument',
    'non_constant_list_element',
    'const_initialized_with_non_constant_value',
    'non_constant_map_element',
    'non_constant_default_value',
    'const_eval_method_invocation',
    'const_constructor_param_type_mismatch',
  };
  final byFile = <String, List<(int, int, String, String)>>{};
  for (final m in line.allMatches(File(analyzerOutput).readAsStringSync())) {
    final file = 'packages/ui/${m.group(2)!.replaceAll(r'\', '/')}';
    byFile.putIfAbsent(file, () => []).add((int.parse(m.group(3)!), int.parse(m.group(4)!), m.group(5)!, m.group(1)!));
  }
  var fixes = 0;
  for (final entry in byFile.entries) {
    final f = File(entry.key);
    if (!f.existsSync()) continue;
    var src = f.readAsStringSync();
    // Line starts by '\n' only: files may mix CRLF and LF.
    final starts = <int>[0];
    for (var i = 0; i < src.length; i++) {
      if (src.codeUnitAt(i) == 10) starts.add(i + 1);
    }
    int offsetOf(int ln, int col) => ln - 1 < starts.length ? starts[ln - 1] + col - 1 : src.length;

    // Bottom-up, so earlier offsets stay valid.
    final errors = entry.value..sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : b.$2.compareTo(a.$2));
    final removedConst = <int>{};
    for (final (ln, col, code, msg) in errors) {
      final at = offsetOf(ln, col);
      if (at < 0 || at > src.length) continue;
      if (constCodes.contains(code)) {
        final head = src.substring(0, at);
        final m = RegExp(r'\bconst\s+').allMatches(head).lastOrNull;
        // Never the `const` of a constructor declaration.
        final rest = m == null ? '' : src.substring(m.end, (m.end + 80).clamp(0, src.length));
        final declaration = RegExp(r'^[A-Z]\w*(\.\w+)?\((\{\s*super|\{\s*required|\{\s*this\.|super\.|this\.|\);)').hasMatch(rest);
        if (m != null && !declaration && !removedConst.contains(m.start)) {
          src = src.replaceRange(m.start, m.end, '');
          removedConst.add(m.start);
          fixes++;
        }
      } else if (code == 'undefined_identifier' && msg.contains("'context'")) {
        final m = RegExp(r'context\.l10n\.(\w+)(\(([^()]*(?:\([^()]*\))*[^()]*)\))?').matchAsPrefix(src, at);
        if (m == null) continue;
        final key = m.group(1)!;
        var text = '${keyText[key]}';
        final args = m.group(3)?.split(',').map((s) => s.trim()).toList() ?? const [];
        final ph = ((arb['@$key'] as Map?)?['placeholders'] as Map?)?.keys.toList() ?? const [];
        for (var i = 0; i < ph.length && i < args.length; i++) {
          text = text.replaceAll('{${ph[i]}}', '\${${args[i]}}');
        }
        text = text.replaceAll(r"'", r"\'").replaceAll('\n', r'\n');
        src = src.replaceRange(m.start, m.end, "'$text'");
        fixes++;
      }
    }
    f.writeAsStringSync(src);
  }
  stdout.writeln('fixes: $fixes');
}

void prune() {
  final arb = readArb();
  final used = <String>{};
  for (final f in Directory(uiLib).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    if (f.path.replaceAll(r'\', '/').contains('/src/l10n/')) continue;
    for (final m in RegExp(r'l10n\.(\w+)').allMatches(f.readAsStringSync())) {
      used.add(m.group(1)!);
    }
  }
  final keep = <String, Object?>{};
  var dropped = 0;
  for (final e in arb.entries) {
    final k = e.key.startsWith('@') && !e.key.startsWith('@@') ? e.key.substring(1) : e.key;
    if (k.startsWith('@') || used.contains(k)) {
      keep[e.key] = e.value;
    } else if (!e.key.startsWith('@')) {
      dropped++;
    }
  }
  writeArb(keep);
  stdout.writeln('dropped $dropped unused keys');
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: extract <files> | fix <analyzer.txt> | prune');
    exit(64);
  }
  switch (args.first) {
    case 'extract':
      extract(args.skip(1).toList());
    case 'fix':
      fix(args[1]);
    case 'prune':
      prune();
    default:
      stderr.writeln('unknown command ${args.first}');
      exit(64);
  }
}
