// P03 T5 (ADR-0040): goals and projects as the UI and the app see them
// (owner decision D11). Progress is derived on every read, never stored or
// written back to a task (LF-INV-GOAL-001). `foundation` types only.
import 'package:foundation/foundation.dart';

import 'command.dart';

enum GoalKindInput { goal, project }

enum GoalState { active, done, archived }

enum GoalItemType { task, event }

/// How the progress was computed (D11).
enum GoalProgressBasis { milestones, links, none }

class MilestoneView {
  const MilestoneView({
    required this.id,
    required this.title,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.sortOrder = 0,
  });
  final String id;
  final String title;
  final LocalDate? dueDate;
  final bool isCompleted;
  final Instant? completedAt;
  final int sortOrder;
}

/// The state of a linked item, read from its own context.
enum LinkedItemState { open, done, cancelled, trashed, missing }

class GoalLinkView {
  const GoalLinkView({
    required this.itemType,
    required this.itemId,
    required this.state,
    this.title,
    this.isHabit = false,
    this.habitRate,
  });
  final GoalItemType itemType;
  final String itemId;
  final String? title;
  final LinkedItemState state;
  final bool isHabit;

  /// A habit: its achieved periods / ended periods since it was linked.
  final double? habitRate;
}

class GoalView {
  const GoalView({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    this.description,
    this.startDate,
    this.targetDate,
    this.isTrashed = false,
    this.milestones = const [],
    this.links = const [],
    this.progressBasis = GoalProgressBasis.none,
    this.progress,
  });
  final String id;
  final GoalKindInput kind;
  final String title;
  final String? description;
  final GoalState status;

  /// Projects only.
  final LocalDate? startDate;
  final LocalDate? targetDate;
  final bool isTrashed;

  /// In their order.
  final List<MilestoneView> milestones;
  final List<GoalLinkView> links;
  final GoalProgressBasis progressBasis;

  /// 0..1; null when nothing counts yet (not 0 %).
  final double? progress;
}

/// Goal commands; failures are returned, never thrown.
abstract interface class GoalService {
  /// A project can have a start date; a goal cannot.
  Future<CommandResult> create({
    required GoalKindInput kind,
    required String title,
    String? description,
    LocalDate? startDate,
    LocalDate? targetDate,
  });

  Future<CommandResult> update(String id,
      {required String title, String? description, LocalDate? startDate, LocalDate? targetDate});

  Future<CommandResult> setStatus(String id, GoalState status);

  /// To the trash: the linked tasks and events are kept (LF-INV-GOAL-002).
  Future<CommandResult> trash(String id);
  Future<CommandResult> restore(String id);

  Future<CommandResult> addMilestone(String goalId, String title, {LocalDate? dueDate});
  Future<CommandResult> updateMilestone(String goalId, String milestoneId, {required String title, LocalDate? dueDate});

  /// Milestones are completed by hand only (OQ-GOAL-1).
  Future<CommandResult> setMilestoneDone(String goalId, String milestoneId, {required bool done});
  Future<CommandResult> removeMilestone(String goalId, String milestoneId);

  /// The item must be in the goal's workspace (LF-INV-GOAL-003).
  Future<CommandResult> link(String goalId, GoalItemType type, String itemId);
  Future<CommandResult> unlink(String goalId, GoalItemType type, String itemId);
}

abstract interface class GoalQueries {
  /// Goals and projects not in the trash; archived ones only when asked.
  Stream<List<GoalView>> watchGoals({bool includeArchived = false});

  Future<GoalView?> goal(String id);

  /// "Part of": the live goals an item is linked to.
  Future<List<GoalView>> goalsOf(GoalItemType type, String itemId);

  Future<List<GoalView>> trashed();
}
