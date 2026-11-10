// P03 T1 (ADR-0036): goal and project progress, a pure function of the
// linked items' states (LF-INV-GOAL-001: derived, never written back).
// Owner decision D11.

enum GoalKind { goal, project }

enum GoalStatus { active, done, archived }

/// The state of one linked item, as read from its own context.
sealed class LinkedState {
  const LinkedState();
}

/// A linked task. Trashed or cancelled tasks do not count (D11).
class LinkedTask extends LinkedState {
  const LinkedTask({required this.done, this.trashed = false, this.cancelled = false});
  final bool done;
  final bool trashed;
  final bool cancelled;
}

/// A linked habit: its achieved (or done) periods out of its ended, judged
/// periods since it was linked (D11). No ended period yet: it does not count.
class LinkedHabit extends LinkedState {
  const LinkedHabit({required this.successes, required this.judged, this.trashed = false});
  final int successes;
  final int judged;
  final bool trashed;
}

/// A linked event: shown with the goal, not counted in its progress.
class LinkedEvent extends LinkedState {
  const LinkedEvent();
}

enum ProgressBasis { milestones, links, none }

class GoalProgress {
  const GoalProgress({required this.basis, required this.done, required this.total});
  final ProgressBasis basis;

  /// Milestones: done milestones. Links: the sum of each counted item's
  /// share (a task 0 or 1, a habit its rate).
  final double done;
  final int total;

  /// Null when nothing counts yet.
  double? get ratio => total == 0 ? null : done / total;
}

/// D11: with milestones, done milestones / all milestones (milestones are
/// completed by hand); without milestones, the linked tasks and habits.
GoalProgress goalProgress({required List<bool> milestonesDone, required List<LinkedState> links}) {
  if (milestonesDone.isNotEmpty) {
    return GoalProgress(
        basis: ProgressBasis.milestones,
        done: milestonesDone.where((d) => d).length.toDouble(),
        total: milestonesDone.length);
  }
  var sum = 0.0;
  var total = 0;
  for (final l in links) {
    switch (l) {
      case LinkedTask(:final done, :final trashed, :final cancelled):
        if (trashed || cancelled) continue;
        total++;
        if (done) sum += 1;
      case LinkedHabit(:final successes, :final judged, :final trashed):
        if (trashed || judged == 0) continue;
        total++;
        sum += successes / judged;
      case LinkedEvent():
        continue;
    }
  }
  return GoalProgress(basis: total == 0 ? ProgressBasis.none : ProgressBasis.links, done: sum, total: total);
}
