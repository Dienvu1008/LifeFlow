// P03 T5 (ADR-0040): goal and project commands (owner decision D11). The
// goal is the aggregate: its milestones and links are written in the same
// gateway transaction, the goal's version moves, and each milestone or
// link row gets its own outbox row (LF-INV-OUTBOX-001).
//
//   create            id, kind (goal|project), title, description?,
//                     startDate? (project only), targetDate?
//   update            id, title, description?, startDate?, targetDate?
//   setStatus         id, status (active|done|archived)
//   trash / restore   id
//   addMilestone      id, milestoneId, title, dueDate?
//   updateMilestone   id, milestoneId, title, dueDate?
//   setMilestoneDone  id, milestoneId, done
//   removeMilestone   id, milestoneId
//   link / unlink     id, itemType (task|event), itemId
//
// A goal never changes a task or an event (LF-INV-GOAL-001/002).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'execution_rows.dart';

const maxGoalTitle = 200;
const maxGoalDescription = 4000;

String _title(Command cmd) {
  final t = (cmd.payload['title'] as String?)?.trim() ?? '';
  if (t.isEmpty) throw DomainRejection('a title is needed');
  if (t.length > maxGoalTitle) throw DomainRejection('the title is too long');
  return t;
}

String? _description(Command cmd) {
  final t = (cmd.payload['description'] as String?)?.trim();
  if (t == null || t.isEmpty) return null;
  if (t.length > maxGoalDescription) throw DomainRejection('the description is too long');
  return t;
}

LocalDate? _date(Command cmd, String key) {
  final raw = cmd.payload[key];
  if (raw == null) return null;
  try {
    return LocalDate.parse(raw as String);
  } catch (_) {
    throw DomainRejection('bad $key');
  }
}

class GoalCommandHandler implements CommandHandler {
  const GoalCommandHandler({this.clock = const SystemClock()});
  final Clock clock;

  @override
  String get entityType => 'goal';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.goals)..where((g) => g.id.equals(cmd.payload['id'] as String))).getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  Future<void> _outbox(AppDatabase db, Command cmd, String type, String id, String op, int? base, Object row,
          DateTime now) =>
      db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: id,
            entityType: type,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: op,
            baseVersion: Value(base),
            payload: jsonEncode(row),
            createdAt: now,
          ));

  /// Start (projects only) and target dates, in order.
  (LocalDate?, LocalDate?) _dates(Command cmd, String kind) {
    final start = _date(cmd, 'startDate');
    final target = _date(cmd, 'targetDate');
    if (start != null && kind != 'project') throw DomainRejection('only a project has a start date');
    if (start != null && target != null && target.isBefore(start)) {
      throw DomainRejection('the target date is before the start');
    }
    return (start, target);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = clock.now().utc;
    final goal = await (db.select(db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();

    HandlerOutcome outcome(String type, Map<String, Object?> change, String event, [Map<String, Object?>? extra]) =>
        HandlerOutcome(
            entityId: id,
            operationType: type,
            changeSet: {'id': id, ...change},
            events: [DomainEvent(event, {'id': id, ...?extra})]);

    Future<void> bump([GoalsCompanion change = const GoalsCompanion()]) =>
        (db.update(db.goals)..where((g) => g.id.equals(id)))
            .write(change.copyWith(version: Value(newVersion.value), updatedAt: Value(now)));

    if (op == 'create') {
      if (goal != null) throw DomainRejection('the goal already exists');
      final kind = cmd.payload['kind'];
      if (kind != 'goal' && kind != 'project') throw DomainRejection('unknown kind');
      final title = _title(cmd);
      final (start, target) = _dates(cmd, kind as String);
      await db.into(db.goals).insert(GoalsCompanion.insert(
            id: id,
            workspaceId: cmd.workspaceId,
            ownerId: cmd.actor.id,
            createdAt: now,
            updatedAt: now,
            kind: kind,
            title: title,
            description: Value(_description(cmd)),
            startDate: Value(start?.toString()),
            targetDate: Value(target?.toString()),
            version: Value(newVersion.value),
          ));
      return outcome('create', {'kind': kind, 'title': title}, 'GoalCreated');
    }

    if (goal == null || goal.workspaceId != cmd.workspaceId) throw DomainRejection('goal not found');
    if (op == 'restore') {
      if (goal.deletedAt == null) throw DomainRejection('the goal is not in the trash');
      await bump(const GoalsCompanion(deletedAt: Value(null), deletedBy: Value(null)));
      return outcome('update', {'tombstone': false}, 'GoalRestored');
    }
    if (goal.deletedAt != null) throw DomainRejection('the goal is in the trash');
    if (op == 'trash') {
      // The links stay with the goal (restore brings them back); the
      // linked tasks and events are never touched (LF-INV-GOAL-002).
      await bump(GoalsCompanion(deletedAt: Value(now), deletedBy: Value(cmd.actor.toString())));
      return outcome('delete', {'tombstone': true}, 'GoalTrashed');
    }
    if (op == 'setStatus') {
      final status = cmd.payload['status'];
      if (!goalStatuses.contains(status)) throw DomainRejection('unknown status');
      if (goal.status == status) throw DomainRejection('the goal is already $status');
      await bump(GoalsCompanion(status: Value(status as String)));
      return outcome('update', {'status': status}, 'GoalStatusChanged', {'status': status});
    }
    // Everything else changes the content: not while archived.
    if (goal.status == 'archived') throw DomainRejection('the goal is archived');

    switch (op) {
      case 'update':
        final title = _title(cmd);
        final (start, target) = _dates(cmd, goal.kind);
        await bump(GoalsCompanion(
          title: Value(title),
          description: Value(_description(cmd)),
          startDate: Value(start?.toString()),
          targetDate: Value(target?.toString()),
        ));
        return outcome('update', {'title': title}, 'GoalUpdated');

      case 'addMilestone':
      case 'updateMilestone':
      case 'setMilestoneDone':
      case 'removeMilestone':
        final mid = cmd.payload['milestoneId'] as String?;
        if (mid == null || mid.isEmpty) throw DomainRejection('a milestone id is needed');
        final existing = await (db.select(db.milestones)..where((m) => m.id.equals(mid))).getSingleOrNull();
        if (existing != null && existing.goalId != id) throw DomainRejection('the milestone belongs to another goal');
        final live = existing != null && existing.deletedAt == null;
        MilestoneRow next;
        String rowOp = 'update';
        String event;
        switch (op) {
          case 'addMilestone':
            if (existing != null) throw DomainRejection('the milestone already exists');
            final count = await (db.select(db.milestones)
                  ..where((m) => m.goalId.equals(id) & m.deletedAt.isNull()))
                .get();
            next = MilestoneRow(
              id: mid,
              workspaceId: cmd.workspaceId,
              ownerId: goal.ownerId,
              version: 1,
              createdAt: now,
              updatedAt: now,
              goalId: id,
              title: _title(cmd),
              dueDate: _date(cmd, 'dueDate')?.toString(),
              isCompleted: false,
              sortOrder: count.length,
            );
            rowOp = 'create';
            event = 'MilestoneAdded';
          case 'updateMilestone':
            if (!live) throw DomainRejection('milestone not found');
            next = existing.copyWith(
                title: _title(cmd), dueDate: Value(_date(cmd, 'dueDate')?.toString()), version: existing.version + 1, updatedAt: now);
            event = 'MilestoneUpdated';
          case 'setMilestoneDone':
            if (!live) throw DomainRejection('milestone not found');
            final done = cmd.payload['done'] == true;
            if (existing.isCompleted == done) {
              throw DomainRejection(done ? 'the milestone is already done' : 'the milestone is not done');
            }
            next = existing.copyWith(
                isCompleted: done, completedAt: Value(done ? now : null), version: existing.version + 1, updatedAt: now);
            event = done ? 'MilestoneCompleted' : 'MilestoneReopened';
          default: // removeMilestone: a tombstone
            if (!live) throw DomainRejection('milestone not found');
            next = existing.copyWith(
                deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: existing.version + 1, updatedAt: now);
            rowOp = 'delete';
            event = 'MilestoneRemoved';
        }
        await db.into(db.milestones).insertOnConflictUpdate(next.toCompanion(false));
        await _outbox(db, cmd, 'milestone', mid, rowOp, existing?.version, next.toJson(), now);
        await bump();
        return outcome('update', {'milestone': mid, 'change': op}, event, {'milestoneId': mid});

      case 'link':
      case 'unlink':
        final type = cmd.payload['itemType'];
        final itemId = cmd.payload['itemId'] as String?;
        if ((type != 'task' && type != 'event') || itemId == null) throw DomainRejection('a task or an event is needed');
        final lid = goalLinkIdOf(id, type as String, itemId);
        final existing = await (db.select(db.goalLinks)..where((l) => l.id.equals(lid))).getSingleOrNull();
        final live = existing != null && existing.deletedAt == null;
        final GoalLinkRow next;
        if (op == 'link') {
          if (live) throw DomainRejection('already linked');
          // The item exists, is not in the trash, and is in the goal's
          // workspace (LF-INV-GOAL-003).
          final (ws, trashed) = switch (type) {
            'task' => await (db.select(db.tasks)..where((t) => t.id.equals(itemId)))
                .getSingleOrNull()
                .then((t) => (t?.workspaceId, t?.deletedAt != null)),
            _ => await (db.select(db.events)..where((e) => e.id.equals(itemId)))
                .getSingleOrNull()
                .then((e) => (e?.workspaceId, e?.deletedAt != null)),
          };
          if (ws == null || trashed) throw DomainRejection('$type not found');
          if (ws != goal.workspaceId) throw DomainRejection('the $type is in another workspace');
          next = existing == null
              ? GoalLinkRow(
                  id: lid,
                  workspaceId: cmd.workspaceId,
                  ownerId: goal.ownerId,
                  version: 1,
                  createdAt: now,
                  updatedAt: now,
                  goalId: id,
                  itemType: type,
                  itemId: itemId)
              // Linked again: counted from now (a habit's periods, D11).
              : existing.copyWith(
                  deletedAt: const Value(null),
                  deletedBy: const Value(null),
                  createdAt: now,
                  version: existing.version + 1,
                  updatedAt: now);
        } else {
          if (!live) throw DomainRejection('not linked');
          next = existing.copyWith(
              deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: existing.version + 1, updatedAt: now);
        }
        await db.into(db.goalLinks).insertOnConflictUpdate(next.toCompanion(false));
        await _outbox(db, cmd, 'goalLink', lid,
            op == 'unlink' ? 'delete' : (existing == null ? 'create' : 'update'), existing?.version, next.toJson(), now);
        await bump();
        return outcome('update', {'link': lid, 'change': op}, op == 'link' ? 'GoalLinked' : 'GoalUnlinked',
            {'itemType': type, 'itemId': itemId});
    }
    throw DomainRejection('unknown op: $op');
  }
}
