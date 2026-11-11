// P03 T5 (ADR-0040): goal commands and reads for the active profile.
// Progress is computed on every read by the domain's pure goalProgress
// from the linked items' own states; nothing is stored or written back
// (LF-INV-GOAL-001).
import 'package:application/application.dart';
import 'package:domain/domain.dart' as d;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'goal_command_handler.dart';
import 'habit_tracking.dart';
import 'profile_store.dart';

class DriftGoalService implements GoalService {
  DriftGoalService(this.db, this.gateway, {this.clock = const SystemClock()})
      : _store = ProfileStore(db),
        _handler = GoalCommandHandler(clock: clock);

  final AppDatabase db;
  final CommandGateway gateway;
  final Clock clock;
  final ProfileStore _store;
  final GoalCommandHandler _handler;
  final _uuid = const Uuid();

  Future<CommandResult> _run(String type, Map<String, Object?> payload, {Version? expected}) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: payload,
        expectedVersion: expected,
        issuedAt: clock.now(),
      ),
      _handler,
    );
  }

  Future<CommandResult> _update(String type, String id, Map<String, Object?> payload) async {
    final g = await (db.select(db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();
    if (g == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'goal not found');
    return _run(type, {...payload, 'id': id}, expected: Version(g.version));
  }

  @override
  Future<CommandResult> create({
    required GoalKindInput kind,
    required String title,
    String? description,
    LocalDate? startDate,
    LocalDate? targetDate,
  }) =>
      _run(kind == GoalKindInput.goal ? 'CreateGoal' : 'CreateProject', {
        'op': 'create',
        'id': _uuid.v7(),
        'kind': kind.name,
        'title': title,
        'description': description,
        'startDate': startDate?.toString(),
        'targetDate': targetDate?.toString(),
      });

  @override
  Future<CommandResult> update(String id,
          {required String title, String? description, LocalDate? startDate, LocalDate? targetDate}) =>
      _update('UpdateGoal', id, {
        'op': 'update',
        'title': title,
        'description': description,
        'startDate': startDate?.toString(),
        'targetDate': targetDate?.toString(),
      });

  @override
  Future<CommandResult> setStatus(String id, GoalState status) =>
      _update('SetGoalStatus', id, {'op': 'setStatus', 'status': status.name});

  @override
  Future<CommandResult> trash(String id) => _update('TrashGoal', id, {'op': 'trash'});

  @override
  Future<CommandResult> restore(String id) => _update('RestoreGoal', id, {'op': 'restore'});

  @override
  Future<CommandResult> addMilestone(String goalId, String title, {LocalDate? dueDate}) => _update('AddMilestone',
      goalId, {'op': 'addMilestone', 'milestoneId': _uuid.v7(), 'title': title, 'dueDate': dueDate?.toString()});

  @override
  Future<CommandResult> updateMilestone(String goalId, String milestoneId, {required String title, LocalDate? dueDate}) =>
      _update('UpdateMilestone', goalId,
          {'op': 'updateMilestone', 'milestoneId': milestoneId, 'title': title, 'dueDate': dueDate?.toString()});

  @override
  Future<CommandResult> setMilestoneDone(String goalId, String milestoneId, {required bool done}) =>
      _update(done ? 'CompleteMilestone' : 'ReopenMilestone', goalId,
          {'op': 'setMilestoneDone', 'milestoneId': milestoneId, 'done': done});

  @override
  Future<CommandResult> removeMilestone(String goalId, String milestoneId) =>
      _update('RemoveMilestone', goalId, {'op': 'removeMilestone', 'milestoneId': milestoneId});

  @override
  Future<CommandResult> link(String goalId, GoalItemType type, String itemId) =>
      _update('LinkToGoal', goalId, {'op': 'link', 'itemType': type.name, 'itemId': itemId});

  @override
  Future<CommandResult> unlink(String goalId, GoalItemType type, String itemId) =>
      _update('UnlinkFromGoal', goalId, {'op': 'unlink', 'itemType': type.name, 'itemId': itemId});
}

class DriftGoalQueries implements GoalQueries {
  DriftGoalQueries(this.db, this.time) : _store = ProfileStore(db);
  final AppDatabase db;
  final DeviceTime time;
  final ProfileStore _store;

  LocalDate _today() => tk.dateAt(time.now(), time.zone());

  Future<String?> _workspace() async => (await _store.getActiveProfile())?.activeWorkspaceId.value;

  Future<(GoalLinkView, d.LinkedState)> _link(GoalLinkRow l, LocalDate today) async {
    final type = GoalItemType.values.byName(l.itemType);
    if (type == GoalItemType.event) {
      final e = await (db.select(db.events)..where((e) => e.id.equals(l.itemId))).getSingleOrNull();
      final state = e == null
          ? LinkedItemState.missing
          : e.deletedAt != null
              ? LinkedItemState.trashed
              : e.status == 'cancelled'
                  ? LinkedItemState.cancelled
                  : LinkedItemState.open;
      return (GoalLinkView(itemType: type, itemId: l.itemId, title: e?.title, state: state), const d.LinkedEvent());
    }
    final t = await (db.select(db.tasks)..where((t) => t.id.equals(l.itemId))).getSingleOrNull();
    if (t == null) {
      return (
        GoalLinkView(itemType: type, itemId: l.itemId, state: LinkedItemState.missing),
        const d.LinkedTask(done: false, trashed: true),
      );
    }
    final trashed = t.deletedAt != null;
    final state = trashed
        ? LinkedItemState.trashed
        : switch (t.status) { 'done' => LinkedItemState.done, 'cancelled' => LinkedItemState.cancelled, _ => LinkedItemState.open };
    if (t.isHabit) {
      // D11: its achieved periods / ended periods since it was linked.
      final linked = l.createdAt.toUtc();
      final since = LocalDate(linked.year, linked.month, linked.day);
      final tracked = trashed ? null : await TrackedTask.load(db, t.id);
      final outcomes = [
        for (final (r, _) in tracked?.results(today) ?? const <(TaskResult, bool)>[])
          if (r.keyDate == null || !r.keyDate!.isBefore(since)) r.outcome
      ];
      final rate = d.completionRate(outcomes);
      return (
        GoalLinkView(
            itemType: type, itemId: t.id, title: t.title, state: state, isHabit: true, habitRate: rate.ratio),
        d.LinkedHabit(successes: rate.successes, judged: rate.judged, trashed: trashed),
      );
    }
    return (
      GoalLinkView(itemType: type, itemId: t.id, title: t.title, state: state),
      d.LinkedTask(done: t.status == 'done', trashed: trashed, cancelled: t.status == 'cancelled'),
    );
  }

  Future<GoalView> _view(GoalRow g, LocalDate today) async {
    final milestones = await (db.select(db.milestones)
          ..where((m) => m.goalId.equals(g.id) & m.deletedAt.isNull())
          ..orderBy([(m) => OrderingTerm(expression: m.sortOrder), (m) => OrderingTerm(expression: m.id)]))
        .get();
    final links = await (db.select(db.goalLinks)
          ..where((l) => l.goalId.equals(g.id) & l.deletedAt.isNull())
          ..orderBy([(l) => OrderingTerm(expression: l.createdAt), (l) => OrderingTerm(expression: l.id)]))
        .get();
    final read = [for (final l in links) await _link(l, today)];
    final p = d.goalProgress(
        milestonesDone: [for (final m in milestones) m.isCompleted], links: [for (final (_, s) in read) s]);
    return GoalView(
      id: g.id,
      kind: GoalKindInput.values.byName(g.kind),
      title: g.title,
      description: g.description,
      status: GoalState.values.byName(g.status),
      startDate: g.startDate == null ? null : LocalDate.parse(g.startDate!),
      targetDate: g.targetDate == null ? null : LocalDate.parse(g.targetDate!),
      isTrashed: g.deletedAt != null,
      milestones: [
        for (final m in milestones)
          MilestoneView(
            id: m.id,
            title: m.title,
            dueDate: m.dueDate == null ? null : LocalDate.parse(m.dueDate!),
            isCompleted: m.isCompleted,
            completedAt: m.completedAt == null ? null : Instant(m.completedAt!.toUtc()),
            sortOrder: m.sortOrder,
          ),
      ],
      links: [for (final (v, _) in read) v],
      progressBasis: GoalProgressBasis.values.byName(p.basis.name),
      progress: p.ratio,
    );
  }

  Future<List<GoalView>> _list({required bool trashed, required bool archived}) async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final rows = await (db.select(db.goals)
          ..where((g) =>
              g.workspaceId.equals(ws) &
              (trashed ? g.deletedAt.isNotNull() : g.deletedAt.isNull()) &
              (archived || trashed ? const Constant(true) : g.status.equals('archived').not()))
          ..orderBy([(g) => OrderingTerm(expression: const CustomExpression<int>('goals.rowid'))]))
        .get();
    final today = _today();
    return [for (final g in rows) await _view(g, today)];
  }

  @override
  Stream<List<GoalView>> watchGoals({bool includeArchived = false}) async* {
    yield await _list(trashed: false, archived: includeArchived);
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.goals,
          db.milestones,
          db.goalLinks,
          db.tasks,
          db.events,
          db.periodResults,
          db.occurrenceCompletions,
          db.measurements,
        ]))
        .asyncMap((_) => _list(trashed: false, archived: includeArchived));
  }

  @override
  Future<GoalView?> goal(String id) async {
    final ws = await _workspace();
    final g = await (db.select(db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();
    if (g == null || g.workspaceId != ws) return null;
    return _view(g, _today());
  }

  @override
  Future<List<GoalView>> goalsOf(GoalItemType type, String itemId) async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final links = await (db.select(db.goalLinks)
          ..where((l) => l.itemType.equals(type.name) & l.itemId.equals(itemId) & l.deletedAt.isNull()))
        .get();
    final today = _today();
    final out = <GoalView>[];
    for (final l in links) {
      final g = await (db.select(db.goals)..where((g) => g.id.equals(l.goalId))).getSingleOrNull();
      if (g != null && g.deletedAt == null && g.workspaceId == ws) out.add(await _view(g, today));
    }
    return out;
  }

  @override
  Future<List<GoalView>> trashed() => _list(trashed: true, archived: true);
}
