// P03 UX U3 (ADR-0047): the Overview as pure data. Lists with their items,
// then the items in no list; tasks with their subtasks. Which rows show
// (collapse), and where a drop or a menu move puts an item, are decided
// here, so they are tested without widgets. The store checks every move
// again (ADR-0046); this only proposes it.
import 'package:application/application.dart';

import 'task_tree.dart';

enum ItemKind { list, task, event }

/// The deepest task level (0 = top level; 4 levels in all, LF-INV-TASK-002).
const maxTaskLevel = 3;

/// The data of one Overview, indexed by container. Container keys: `lists`;
/// `in:` (no list) and `in:<listId>` (the top level of a list); `under:<id>`.
class OverviewIndex {
  OverviewIndex({
    required List<TaskListView> lists,
    required List<TaskView> tasks,
    required List<OverviewEventView> events,
  }) {
    for (final l in lists) {
      this.lists[l.id] = l;
    }
    for (final t in tasks) {
      this.tasks[t.id] = t;
    }
    for (final e in events) {
      this.events[e.id] = e;
    }
    for (final r in orderTree(tasks)) {
      taskRows[r.task.id] = r;
    }
    final keyed = <String, List<(String, String)>>{};
    void add(String container, String id, String key) {
      keyed.putIfAbsent(container, () => []).add((key, id));
      containerOf[id] = container;
    }

    for (final l in lists) {
      add('lists', l.id, l.orderKey);
    }
    String top(String? listId) => listId != null && this.lists.containsKey(listId) ? 'in:$listId' : 'in:';
    for (final t in tasks) {
      final p = t.parentId;
      add(p != null && this.tasks.containsKey(p) ? 'under:$p' : top(t.listId), t.id, t.orderKey);
    }
    for (final e in events) {
      add(top(e.listId), e.id, e.orderKey);
    }
    for (final MapEntry(:key, :value) in keyed.entries) {
      value.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
      children[key] = [for (final v in value) v.$2];
    }
  }

  final lists = <String, TaskListView>{};
  final tasks = <String, TaskView>{};
  final events = <String, OverviewEventView>{};
  final taskRows = <String, TaskRow>{};
  final children = <String, List<String>>{};
  final containerOf = <String, String>{};

  List<String> itemsOf(String container) => children[container] ?? const [];
  List<String> get listIds => itemsOf('lists');

  ItemKind kindOf(String id) => lists.containsKey(id)
      ? ItemKind.list
      : events.containsKey(id)
          ? ItemKind.event
          : ItemKind.task;

  /// 0 for a top-level item.
  int levelOf(String id) {
    var level = 0;
    var c = containerOf[id];
    var guard = 0;
    while (c != null && c.startsWith('under:') && guard++ < 64) {
      level++;
      c = containerOf[c.substring(6)];
    }
    return level;
  }

  /// Levels of [id] and its subtasks (1 = none).
  int heightOf(String id) {
    var h = 1;
    for (final k in itemsOf('under:$id')) {
      final kh = 1 + heightOf(k);
      if (kh > h) h = kh;
    }
    return h;
  }

  /// Whether [id] is [ancestor] or below it.
  bool isWithin(String id, String ancestor) {
    String? cur = id;
    var guard = 0;
    while (cur != null && guard++ < 64) {
      if (cur == ancestor) return true;
      final c = containerOf[cur];
      cur = c != null && c.startsWith('under:') ? c.substring(6) : null;
    }
    return false;
  }

  /// The ancestor of [id] at [level] (itself when its level is [level]).
  String ancestorAt(String id, int level) {
    var cur = id;
    var l = levelOf(id);
    while (l > level) {
      cur = containerOf[cur]!.substring(6);
      l--;
    }
    return cur;
  }

  /// The list a top-level container belongs to (null: no list).
  static String? listOfContainer(String container) =>
      container.startsWith('in:') && container.length > 3 ? container.substring(3) : null;

  /// The list [id] is shown in (through its top-level task).
  String? listOf(String id) {
    final top = ancestorAt(id, 0);
    return listOfContainer(containerOf[top] ?? 'in:');
  }

  static ItemPlace placeIn(String container, String? afterId) {
    if (container.startsWith('under:')) return ItemPlace.under(container.substring(6), afterId: afterId);
    final l = listOfContainer(container);
    return l == null ? ItemPlace.loose(afterId: afterId) : ItemPlace.inList(l, afterId: afterId);
  }

  static String containerOfPlace(ItemPlace p) =>
      p.parentId != null ? 'under:${p.parentId}' : 'in:${p.listId ?? ''}';
}

/// One visible row.
sealed class OverviewRow {
  const OverviewRow();
  String get id;

  /// Task level (0 = top level); -1 for a list or the "no list" header.
  int get level;

  /// Visual indentation in steps.
  int get indent;
}

class ListRow extends OverviewRow {
  const ListRow(this.list, {required this.collapsed, required this.itemCount});
  final TaskListView list;
  final bool collapsed;
  final int itemCount;
  @override
  String get id => list.id;
  @override
  int get level => -1;
  @override
  int get indent => 0;
}

/// The heading over the items in no list (only when there are lists too).
class LooseHeaderRow extends OverviewRow {
  const LooseHeaderRow();
  @override
  String get id => '';
  @override
  int get level => -1;
  @override
  int get indent => 0;
}

class TaskItemRow extends OverviewRow {
  const TaskItemRow(this.row, {required this.level, required this.indent, required this.hasChildren, required this.collapsed});
  final TaskRow row;
  @override
  final int level;
  @override
  final int indent;
  final bool hasChildren;
  final bool collapsed;
  TaskView get task => row.task;
  @override
  String get id => row.task.id;
}

class EventItemRow extends OverviewRow {
  const EventItemRow(this.event, {required this.indent});
  final OverviewEventView event;
  @override
  String get id => event.id;
  @override
  int get level => 0;
  @override
  final int indent;
}

/// The visible rows: each list and, unless collapsed, its items; then the
/// items in no list. A task's subtasks show unless it is collapsed.
List<OverviewRow> overviewRows(OverviewIndex ix, Set<String> collapsed) {
  final out = <OverviewRow>[];
  void items(String container, int level, int indent) {
    for (final id in ix.itemsOf(container)) {
      final e = ix.events[id];
      if (e != null) {
        out.add(EventItemRow(e, indent: indent));
        continue;
      }
      final row = ix.taskRows[id];
      if (row == null) continue;
      final kids = ix.itemsOf('under:$id');
      final shut = collapsed.contains(id);
      out.add(TaskItemRow(row, level: level, indent: indent, hasChildren: kids.isNotEmpty, collapsed: shut));
      if (kids.isNotEmpty && !shut) items('under:$id', level + 1, indent + 1);
    }
  }

  for (final id in ix.listIds) {
    final shut = collapsed.contains(id);
    out.add(ListRow(ix.lists[id]!, collapsed: shut, itemCount: ix.itemsOf('in:$id').length));
    if (!shut) items('in:$id', 0, 1);
  }
  if (ix.listIds.isNotEmpty && ix.itemsOf('in:').isNotEmpty) out.add(const LooseHeaderRow());
  items('in:', 0, 0);
  return out;
}

// --- Moves ---------------------------------------------------------------

/// A proposed change: one command.
sealed class MovePlan {
  const MovePlan();
}

class MoveListPlan extends MovePlan {
  const MoveListPlan(this.listId, this.afterId);
  final String listId;
  final String? afterId;
}

class MoveItemPlan extends MovePlan {
  const MoveItemPlan(this.id, this.kind, this.place);
  final String id;
  final ItemKind kind;
  final ItemPlace place;

  /// The list or task to show expanded after the move (it went into it).
  String? get opens => place.parentId ?? place.listId;
}

enum DropZone { before, into, after }

/// [plan] for [id] when it is valid and changes something, else null.
MovePlan? _checked(OverviewIndex ix, String id, ItemPlace place) {
  final kind = ix.kindOf(id);
  if (kind == ItemKind.list) return null;
  final parent = place.parentId;
  if (parent != null) {
    if (kind == ItemKind.event) return null; // never under a task (U-D1)
    if (!ix.tasks.containsKey(parent) || ix.isWithin(parent, id)) return null;
    if (ix.levelOf(parent) + ix.heightOf(id) > maxTaskLevel) return null; // depth with the subtasks
  }
  final container = OverviewIndex.containerOfPlace(place);
  final siblings = [...ix.itemsOf(container)]..remove(id);
  if (place.afterId != null && !siblings.contains(place.afterId)) return null;
  // Unchanged: same container, same item before it.
  if (ix.containerOf[id] == container) {
    final now = ix.itemsOf(container);
    final i = now.indexOf(id);
    if ((i == 0 ? null : now[i - 1]) == place.afterId) return null;
  }
  return MoveItemPlan(id, kind, place);
}

MovePlan? _listAfter(OverviewIndex ix, String listId, String? afterId) {
  final now = ix.listIds;
  final i = now.indexOf(listId);
  if (afterId == listId || (i == 0 ? null : now[i - 1]) == afterId) return null;
  return MoveListPlan(listId, afterId);
}

/// Where dropping [dragged] on [rows][target] puts it. [zone] is the part of
/// the row under the pointer; [shift] the levels the pointer moved right
/// (positive) or left since the drag began: after a row, 0 keeps the row's
/// level, +1 makes the item the row's first child, -1 one level up.
MovePlan? resolveDrop(OverviewIndex ix, List<OverviewRow> rows, String dragged, int target, DropZone zone, int shift) {
  if (target < 0 || target >= rows.length) return null;
  final row = rows[target];
  final kind = ix.kindOf(dragged);

  if (kind == ItemKind.list) {
    final lists = ix.listIds;
    if (row is ListRow) {
      if (zone == DropZone.before) {
        final i = lists.indexOf(row.id);
        return _listAfter(ix, dragged, i <= 0 ? null : lists[i - 1]);
      }
      return _listAfter(ix, dragged, row.id);
    }
    if (lists.isEmpty) return null;
    final owner = row is LooseHeaderRow ? null : ix.listOf(row.id);
    return _listAfter(ix, dragged, owner ?? lists.last);
  }

  // Its own subtree, a task under an event, a level too deep: _checked.
  // Above a row = after the row before it, at this row's level.
  if (zone == DropZone.before) {
    if (target == 0) {
      return row is ListRow ? null : _checked(ix, dragged, ItemPlace.loose());
    }
    return _after(ix, rows, dragged, target - 1, row.level < 0 ? 0 : row.level + shift);
  }
  if (zone == DropZone.into) {
    if (row is ListRow) return _checked(ix, dragged, ItemPlace.inList(row.id));
    if (row is LooseHeaderRow) return _checked(ix, dragged, const ItemPlace.loose());
    if (row is TaskItemRow && kind == ItemKind.task) {
      final kids = [...ix.itemsOf('under:${row.id}')]..remove(dragged);
      return _checked(ix, dragged, ItemPlace.under(row.id, afterId: kids.isEmpty ? null : kids.last));
    }
  }
  return _after(ix, rows, dragged, target, row.level < 0 ? 0 : row.level + shift);
}

MovePlan? _after(OverviewIndex ix, List<OverviewRow> rows, String dragged, int index, int level) {
  final row = rows[index];
  if (row is ListRow) return _checked(ix, dragged, ItemPlace.inList(row.id));
  if (row is LooseHeaderRow) return _checked(ix, dragged, const ItemPlace.loose());
  if (row.id == dragged || ix.isWithin(row.id, dragged)) {
    // After its own subtree: the row before the dragged item decides.
    final start = rows.indexWhere((r) => r.id == dragged);
    return start > 0 ? _after(ix, rows, dragged, start - 1, level) : null;
  }
  final isEvent = ix.kindOf(dragged) == ItemKind.event;
  final canNest = row is TaskItemRow && !isEvent;
  final top = row.level + (canNest ? 1 : 0);
  final l = (isEvent ? 0 : level).clamp(0, top);
  if (l == row.level + 1) return _checked(ix, dragged, ItemPlace.under(row.id));
  final x = ix.ancestorAt(row.id, l);
  if (x == dragged) return null;
  return _checked(ix, dragged, OverviewIndex.placeIn(ix.containerOf[x]!, x));
}

// Menu moves: accessible alternatives to dragging (WCAG 2.5.7).

MovePlan? moveUp(OverviewIndex ix, String id) {
  if (ix.kindOf(id) == ItemKind.list) {
    final l = ix.listIds;
    final i = l.indexOf(id);
    return i <= 0 ? null : MoveListPlan(id, i >= 2 ? l[i - 2] : null);
  }
  final c = ix.containerOf[id]!;
  final s = ix.itemsOf(c);
  final i = s.indexOf(id);
  return i <= 0 ? null : _checked(ix, id, OverviewIndex.placeIn(c, i >= 2 ? s[i - 2] : null));
}

MovePlan? moveDown(OverviewIndex ix, String id) {
  if (ix.kindOf(id) == ItemKind.list) {
    final l = ix.listIds;
    final i = l.indexOf(id);
    return i < 0 || i == l.length - 1 ? null : MoveListPlan(id, l[i + 1]);
  }
  final c = ix.containerOf[id]!;
  final s = ix.itemsOf(c);
  final i = s.indexOf(id);
  return i < 0 || i == s.length - 1 ? null : _checked(ix, id, OverviewIndex.placeIn(c, s[i + 1]));
}

/// Under the task just above it, at the end (a task only).
MovePlan? indent(OverviewIndex ix, String id) {
  if (ix.kindOf(id) != ItemKind.task) return null;
  final s = ix.itemsOf(ix.containerOf[id]!);
  final i = s.indexOf(id);
  if (i <= 0) return null; // the item above must be a task: _checked
  final kids = ix.itemsOf('under:${s[i - 1]}');
  return _checked(ix, id, ItemPlace.under(s[i - 1], afterId: kids.isEmpty ? null : kids.last));
}

/// Right after its parent, one level up.
MovePlan? outdent(OverviewIndex ix, String id) {
  final c = ix.containerOf[id];
  if (c == null || !c.startsWith('under:')) return null;
  final parent = c.substring(6);
  return _checked(ix, id, OverviewIndex.placeIn(ix.containerOf[parent]!, parent));
}

/// To the end of [listId] (null: no list), at the top level.
MovePlan? moveToList(OverviewIndex ix, String id, String? listId) {
  final c = 'in:${listId ?? ''}';
  final s = [...ix.itemsOf(c)]..remove(id);
  return _checked(ix, id, OverviewIndex.placeIn(c, s.isEmpty ? null : s.last));
}
