// P03 UX U2 (schema v7, ADR-0046): well-formedness of the colours and order
// keys of lists, tasks and events, for export validation (the file is
// untrusted, SR-14). References (an event's list) are checked by the caller.
import 'package:domain/domain.dart' show isValidOrderKey, itemColorError;

import 'record_kinds.dart';

/// Why the list, task and event rows of [records] cannot be restored, or null.
String? organizeRowsError(Map<String, List<Row>> records) {
  for (final (kind, what) in const [('taskList', 'a list'), ('task', 'a task'), ('event', 'an event')]) {
    for (final r in records[kind] ?? const <Row>[]) {
      final c = r['colorIndex'];
      if (c != null && (c is! int || itemColorError(c) != null)) return '$what has an unknown colour';
      final k = r['orderKey'];
      if (k is! String || !isValidOrderKey(k)) return '$what has a bad order key';
    }
  }
  return null;
}
