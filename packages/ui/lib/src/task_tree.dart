import 'package:application/application.dart';

/// One visible row of the task list: the task, its indentation depth (0 for a
/// root) and whether any direct child is still open (drives the choice between
/// "complete with subtasks" and "complete only this", OQ-R3).
class TaskRow {
  const TaskRow(this.task, this.depth, this.hasOpenChildren);
  final TaskView task;
  final int depth;
  final bool hasOpenChildren;
}

/// Orders a flat task list into depth-first tree order, keeping the incoming
/// (creation) order among siblings. A task whose parent is not in the list
/// (for example the parent was trashed) is shown as a root so nothing vanishes
/// silently. Cycle-safe: each task is emitted at most once.
List<TaskRow> orderTree(List<TaskView> tasks) {
  final ids = {for (final t in tasks) t.id};
  final children = <String, List<TaskView>>{};
  final roots = <TaskView>[];
  for (final t in tasks) {
    final p = t.parentId;
    if (p == null || !ids.contains(p)) {
      roots.add(t);
    } else {
      children.putIfAbsent(p, () => []).add(t);
    }
  }

  final out = <TaskRow>[];
  final seen = <String>{};
  void visit(TaskView t, int depth) {
    if (!seen.add(t.id)) return;
    final kids = children[t.id] ?? const <TaskView>[];
    out.add(TaskRow(t, depth, kids.any((c) => !c.isDone)));
    for (final c in kids) {
      visit(c, depth + 1);
    }
  }

  for (final r in roots) {
    visit(r, 0);
  }
  // Defensive: cycles are prevented at write time (LF-INV-TASK-003), but if
  // bad data ever reaches the UI, show the unreachable tasks as roots rather
  // than hiding them.
  for (final t in tasks) {
    visit(t, 0);
  }
  return out;
}
