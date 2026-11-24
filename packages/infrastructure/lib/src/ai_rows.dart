// P06 T3 (ADR-0082): the assistant's history read from a file (an export,
// an undo copy) is checked as the commands would check it, so a file cannot
// put into the store what no command could write.
import 'dart:convert';

import 'package:application/application.dart';

import 'ai_history_handlers.dart' show maxAiChanges, maxAiMessageLength, maxAiTitleLength;
import 'record_kinds.dart' show Row;

/// Why the sessions, messages and proposals of [records] cannot be
/// restored, or null.
String? aiRowsError(Map<String, List<Row>> records) {
  bool known<T extends Enum>(List<T> values, Object? name) => values.any((v) => v.name == name);
  for (final s in records['aiSession'] ?? const <Row>[]) {
    final t = s['title'];
    if (t is! String || t.trim().isEmpty || t.length > maxAiTitleLength)
      return 'an assistant session has no valid title';
    if (!known(AiPurpose.values, s['purpose'])) return 'an assistant session has an unknown purpose';
  }
  for (final m in records['aiMessage'] ?? const <Row>[]) {
    if (!known(AiMessageRole.values, m['role'])) return 'an assistant message has an unknown role';
    final text = m['body'];
    if (text is! String || text.length > maxAiMessageLength) return 'an assistant message is too long';
    if (m['site'] != null && !known(AiEngineSite.values, m['site'])) return 'an assistant message has an unknown site';
    try {
      final refs = jsonDecode(m['sentRefs'] as String);
      if (refs is! List || refs.any((r) => r is! Map || r['kind'] is! String || r['id'] is! String))
        throw const FormatException();
    } catch (_) {
      return 'an assistant message has unreadable sent items';
    }
  }
  for (final p in records['aiProposal'] ?? const <Row>[]) {
    if (!known(AiEngineSite.values, p['site'])) return 'an assistant proposal has an unknown site';
    try {
      final changes = decodeAiChanges(p['changes'] as String);
      if (changes.isEmpty || changes.length > maxAiChanges) throw const FormatException();
      if (changes.map((c) => c.change.id).toSet().length != changes.length) throw const FormatException();
    } catch (_) {
      return 'an assistant proposal has unreadable changes';
    }
  }
  return null;
}
