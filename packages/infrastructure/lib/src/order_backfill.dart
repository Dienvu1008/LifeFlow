// P03 UX U2 (schema v7, ADR-0046): order keys for rows written before keys
// existed, on a store upgrade and on an older export. The order is the one
// the app showed until then: by creation, then by position (rowid or the
// file's order). One container per workspace and place: the lists; the
// top-level items in no list (tasks and events together); the top-level
// items of a list; the subtasks of a task.
import 'package:domain/domain.dart';

/// One row to key: [kind] is 'taskList', 'task' or 'event'.
class UnkeyedRow {
  const UnkeyedRow({
    required this.kind,
    required this.id,
    required this.workspaceId,
    required this.createdAt,
    this.parentTaskId,
    this.listId,
  });
  final String kind;
  final String id;
  final String workspaceId;
  final int createdAt;
  final String? parentTaskId;
  final String? listId;

  /// The container this row is ordered in.
  String get container => switch (kind) {
        'taskList' => '$workspaceId/lists',
        _ when parentTaskId != null => '$workspaceId/under:$parentTaskId',
        _ => '$workspaceId/in:${listId ?? ''}',
      };
}

/// The new key of every row, by id. [rows] are in their current position
/// order; a stable sort by creation keeps it for equal times.
Map<String, String> backfillOrderKeys(List<UnkeyedRow> rows) {
  final byContainer = <String, List<(int, UnkeyedRow)>>{};
  for (var i = 0; i < rows.length; i++) {
    byContainer.putIfAbsent(rows[i].container, () => []).add((i, rows[i]));
  }
  final out = <String, String>{};
  for (final group in byContainer.values) {
    group.sort((a, b) {
      final c = a.$2.createdAt.compareTo(b.$2.createdAt);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    final keys = orderKeysAfter(null, group.length);
    for (var i = 0; i < group.length; i++) {
      out[group[i].$2.id] = keys[i];
    }
  }
  return out;
}
