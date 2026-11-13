import 'package:foundation/foundation.dart';

/// Task status (ADR / task-management.md section 3). Trash/archive are
/// orthogonal (tombstone fields), not statuses.
enum TaskStatus { inbox, todo, inProgress, done, cancelled }

/// Allowed status transitions (LF-INV-TASK-004). A map from a status to the
/// set it may move to. Completion to `done`/`cancelled` is allowed from any
/// active state; re-opening is allowed back to todo/inProgress.
const Map<TaskStatus, Set<TaskStatus>> _allowedTransitions = {
  TaskStatus.inbox: {TaskStatus.todo, TaskStatus.inProgress, TaskStatus.done, TaskStatus.cancelled},
  TaskStatus.todo: {TaskStatus.inProgress, TaskStatus.done, TaskStatus.cancelled, TaskStatus.inbox},
  TaskStatus.inProgress: {TaskStatus.todo, TaskStatus.done, TaskStatus.cancelled},
  TaskStatus.done: {TaskStatus.todo, TaskStatus.inProgress}, // re-open
  TaskStatus.cancelled: {TaskStatus.todo, TaskStatus.inProgress},
};

bool isValidTransition(TaskStatus from, TaskStatus to) =>
    from == to || (_allowedTransitions[from]?.contains(to) ?? false);

/// Target type for a measurable task/habit capability.
enum TargetType { atLeast, atMost, about }

/// Completion policy for a task (POL-COMPLETION).
enum CompletionPolicy { manual, automatic, hybrid }

/// How the measurements of one period are combined (P03 D7, FR-HAB-03).
enum TargetAggregation { sum, max, latest, average }

/// The longest unit text accepted (free text with suggestions, D7).
const maxUnitLength = 40;

/// Measurable-target capability (present only on measurable tasks).
/// P03 (ADR-0036): which bounds a type needs, values >= 0 (D7), and the
/// aggregation of a period's measurements (default sum).
class MeasurableTarget {
  const MeasurableTarget({
    required this.type,
    this.min,
    this.max,
    required this.unit,
    this.aggregation = TargetAggregation.sum,
  });
  final TargetType type;
  final double? min;
  final double? max;
  final String unit;
  final TargetAggregation aggregation;

  /// Why the target is invalid, or null:
  ///  - atLeast needs min; atMost needs max; about needs both, min <= max;
  ///  - bounds are finite and >= 0 (D7);
  ///  - the unit is not empty and at most [maxUnitLength] characters.
  String? validate() {
    final lo = min, hi = max;
    switch (type) {
      case TargetType.atLeast:
        if (lo == null) return 'an "at least" target needs a minimum';
      case TargetType.atMost:
        if (hi == null) return 'an "at most" target needs a maximum';
      case TargetType.about:
        if (lo == null || hi == null) return 'an "about" target needs a minimum and a maximum';
        if (lo > hi) return 'about target requires min <= max';
    }
    for (final v in [lo, hi]) {
      if (v != null && (!v.isFinite || v < 0)) return 'target values must be 0 or more';
    }
    final u = unit.trim();
    if (u.isEmpty) return 'a target needs a unit';
    if (u.length > maxUnitLength) return 'the unit is too long';
    return null;
  }

  @override
  bool operator ==(Object o) =>
      o is MeasurableTarget &&
      o.type == type &&
      o.min == min &&
      o.max == max &&
      o.unit == unit &&
      o.aggregation == aggregation;
  @override
  int get hashCode => Object.hash(type, min, max, unit, aggregation);
}

/// The maximum subtask depth, checked at command time only (LF-INV-TASK-002).
/// Changing this constant is NOT a data migration: existing rows at an older
/// depth stay valid; only new create/reparent commands are checked.
const int maxTaskDepth = 4; // root + 3 nested levels (OQ-R1)

/// A Task aggregate (pure domain; no persistence, no Flutter). Hierarchy is
/// expressed by parentId; the acyclic/depth rules are enforced by domain
/// services using ancestry provided by the application layer.
class Task {
  Task({
    required this.id,
    required this.workspaceId,
    required this.ownerId,
    required this.title,
    this.status = TaskStatus.inbox,
    this.parentId,
    this.taskListId,
    this.target,
    this.completionPolicy = CompletionPolicy.manual,
    this.isHabit = false,
    this.version = Version.initial,
  });

  final EntityId id;
  final String workspaceId;
  final String ownerId;
  final String title;
  final TaskStatus status;
  final EntityId? parentId;
  final EntityId? taskListId;
  final MeasurableTarget? target;
  final CompletionPolicy completionPolicy;

  /// P03 D6 (amends ADR-0006): a habit is a flag of its own, independent of
  /// the repeat and of a target. An unmeasured habit is tracked done/missed.
  final bool isHabit;
  final Version version;

  bool get isMeasurable => target != null;

  Task copyWith({String? title, TaskStatus? status, EntityId? parentId, bool clearParent = false, Version? version}) {
    return Task(
      id: id,
      workspaceId: workspaceId,
      ownerId: ownerId,
      title: title ?? this.title,
      status: status ?? this.status,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      taskListId: taskListId,
      target: target,
      completionPolicy: completionPolicy,
      isHabit: isHabit,
      version: version ?? this.version,
    );
  }
}

/// Pure hierarchy rules (LF-INV-TASK-002/003). The caller supplies the
/// ancestor chain of the prospective new parent (root-first or any order),
/// read via the application layer, so the domain stays persistence-free.
class TaskHierarchyRules {
  /// Returns a reason if re-parenting [taskId] under [newParentId] is invalid.
  /// [newParentAncestorsIncludingSelf] = the new parent plus all its ancestors
  /// (their ids). [newParentDepth] = depth of the new parent (root = 1).
  /// [movedSubtreeHeight] = levels of the moved task and its live subtasks
  /// (1 = no subtasks; P03 UX U2): the deepest of them must stay within the
  /// limit too.
  static String? reparentError({
    required EntityId taskId,
    required EntityId? newParentId,
    required Set<String> newParentAncestorsIncludingSelf,
    required int newParentDepth,
    int movedSubtreeHeight = 1,
  }) {
    if (newParentId == null) return null; // moving to root is always fine
    // No cycle: the task cannot be its new parent or any ancestor of it.
    if (newParentAncestorsIncludingSelf.contains(taskId.value)) {
      return 'reparent would create a cycle';
    }
    // Depth: the task sits at newParentDepth + 1, its deepest subtask
    // movedSubtreeHeight - 1 levels below; neither may exceed the limit.
    if (newParentDepth + movedSubtreeHeight > maxTaskDepth) {
      return 'reparent would exceed max depth ($maxTaskDepth)';
    }
    return null;
  }

  /// Returns a reason if creating a child under [parentDepth] is too deep.
  static String? createDepthError(int? parentDepth) {
    if (parentDepth == null) return null; // root task
    if (parentDepth + 1 > maxTaskDepth) {
      return 'new task would exceed max depth ($maxTaskDepth)';
    }
    return null;
  }
}
