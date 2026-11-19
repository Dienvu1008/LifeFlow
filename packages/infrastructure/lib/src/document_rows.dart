// P05a T3 (ADR-0068): documents read from a file (an export, an undo copy)
// are checked as the commands would check them, so a file cannot put into
// the store what no command could write.
import 'package:domain/domain.dart';

import 'document_command_handler.dart' show documentItemTypes, documentLinkIdOf;
import 'record_kinds.dart' show Row;

/// Why the documents, revisions and links of [records] cannot be restored,
/// or null: every title and body readable and valid, every link keyed by its
/// document and item, and no document under itself (DOC-001).
String? documentRowsError(Map<String, List<Row>> records) {
  String? body(Object? raw) {
    if (raw is! String) return 'a document has no body';
    try {
      return DocumentBody.decode(raw).validate();
    } on FormatException {
      return 'a document body cannot be read';
    }
  }

  final parent = <String, String?>{};
  for (final d in records['document'] ?? const <Row>[]) {
    final t = d['title'];
    if (t is! String || documentTitleError(t) != null) return 'a document has no valid title';
    final why = body(d['body']);
    if (why != null) return why;
    parent[d['id'] as String] = d['parentId'] as String?;
  }
  for (final id in parent.keys) {
    final seen = <String>{};
    String? at = id;
    while (at != null) {
      if (!seen.add(at)) return 'a document is under itself';
      at = parent[at];
    }
  }
  for (final r in records['documentRevision'] ?? const <Row>[]) {
    final why = body(r['body']);
    if (why != null) return 'a revision: $why';
    if (!const {'save', 'conflict', 'restore'}.contains(r['reason'])) return 'a revision has an unknown reason';
  }
  for (final l in records['documentLink'] ?? const <Row>[]) {
    final type = l['itemType'];
    if (!documentItemTypes.contains(type)) return 'a document link has an unknown item type';
    if (l['id'] != documentLinkIdOf(l['documentId'] as String, type as String, l['itemId'] as String)) {
      return 'a document link id does not match its document and item';
    }
  }
  return null;
}
