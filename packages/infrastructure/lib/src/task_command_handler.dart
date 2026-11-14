import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' hide Task;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'execution_rows.dart';
import 'habit_tracking.dart';
import 'organize_ops.dart';
import 'task_schedule_ops.dart';
import 'task_target_ops.dart';

/// Applies Task commands within the gateway transaction (T3). Enforces the
/// domain rules (status transitions, hierarchy depth/acyclicity) before
/// writing, so every rule runs on the single mutation path (ADR-0011).
///
/// Supported command types (via payload['op']):
///   create   : payload id, title, parentId?, listId?
///   rename   : payload id, title
///   complete : payload id, cascade ('all'|'parentOnly')
///   reopen   : payload id (done/cancelled -> todo)
///   reparent : payload id, newParentId? (appended at the end there)
///   move     : payload id, listId? | parentId?, afterId? (P03 UX U2, organize_ops.dart)
///   setColor : payload id, colorIndex? (P03 UX U2)
///   setNotes : payload id, notes? (dogfooding F3; trimmed, empty = none)
///   trash    : payload id, cascade ('all'|'parentOnly'; default parentOnly)
///   P02 T4 schedule ops (task_schedule_ops.dart): setSchedule,
///   clearSchedule, setException, clearException, setOccurrenceDone,
///   setReminders
///   P03 T4 target ops (task_target_ops.dart): setHabit, setTarget,
///   setCompletion
class TaskCommandHandler implements CommandHandler {
  @override
  String get entityType => 'task';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final id = cmd.payload['id'] as String;
    final row = await (db.select(db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  Future<int> _depthOf(AppDatabase db, String? id) async {
    if (id == null) return 0; // parent of a root; a root task is depth 1
    var depth = 1;
    var cur = id;
    var guard = 0;
    while (guard++ < maxTaskDepth + 2) {
      final row = await (db.select(db.tasks)..where((t) => t.id.equals(cur)))
          .getSingleOrNull();
      if (row?.parentTaskId == null) break;
      depth++;
      cur = row!.parentTaskId!;
    }
    return depth;
  }

  Future<Set<String>> _ancestorsIncludingSelf(AppDatabase db, String id) async {
    final chain = <String>{};
    String? cur = id;
    var guard = 0;
    while (cur != null && guard++ < maxTaskDepth + 2) {
      if (!chain.add(cur)) break;
      final row = await (db.select(db.tasks)..where((t) => t.id.equals(cur!)))
          .getSingleOrNull();
      cur = row?.parentTaskId;
    }
    return chain;
  }

  /// P03 D6c: a one-off habit ticked or unticked after its period closed:
  /// its stored result follows, recorded as a new version.
  Future<void> _lateTick(AppDatabase db, Command cmd, String id, {required bool done, required DateTime now}) async {
    final stored = await (db.select(db.periodResults)
          ..where((r) => r.id.equals(periodResultIdOf(id, oncePeriodKey, 'occurrence')) & r.deletedAt.isNull()))
        .getSingleOrNull();
    if (stored == null) return;
    await rewriteStoredResult(db, stored, done ? HabitOutcome.done : HabitOutcome.missed, null,
        operationId: cmd.operationId, workspaceId: cmd.workspaceId, actor: cmd.actor.toString(), now: now);
  }

  /// Writes [change] to another task in the same command, moving its version
  /// and updatedAt forward (LF-INV-VER-001).
  Future<void> _bump(AppDatabase db, Task row, DateTime now, TasksCompanion change) =>
      (db.update(db.tasks)..where((t) => t.id.equals(row.id))).write(change.copyWith(
          version: Value(row.version + 1), updatedAt: Value(now)));

  /// One outbox row per other task the command changed, under the same
  /// operation id, so sync sees every change (LF-INV-OUTBOX-001). The gateway
  /// writes the row of the command's own task.
  Future<void> _outboxFor(AppDatabase db, Command cmd, Map<String, String> touched, DateTime now) async {
    for (final e in touched.entries) {
      final row = await (db.select(db.tasks)..where((t) => t.id.equals(e.key))).getSingle();
      await db.into(db.outbox).insert(OutboxCompanion.insert(
            operationId: cmd.operationId,
            entityId: e.key,
            entityType: entityType,
            workspaceId: cmd.workspaceId,
            actorId: cmd.actor.toString(),
            operationType: e.value,
            baseVersion: Value(row.version - 1),
            payload: jsonEncode({
              'id': e.key,
              'status': row.status,
              'parentId': row.parentTaskId,
              if (row.deletedAt != null) 'tombstone': true,
            }),
            createdAt: now,
          ));
    }
  }

  Future<Task> _liveTask(AppDatabase db, String id) async {
    final row = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) throw DomainRejection('task not found');
    return row;
  }

  /// A live task of [ws] to put a subtask under. An event never has
  /// subtasks (U-D1).
  Future<Task> _liveParent(AppDatabase db, String ws, String id) async {
    final row = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null || row.workspaceId != ws) throw DomainRejection('unknown parent task');
    return row;
  }

  /// The list of [id]'s top-level task (null: in no list).
  Future<String?> _rootListOf(AppDatabase db, String id) async {
    var row = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
    var guard = 0;
    while (row?.parentTaskId != null && guard++ < maxTaskDepth + 2) {
      final up = row!.parentTaskId!;
      row = await (db.select(db.tasks)..where((t) => t.id.equals(up))).getSingleOrNull();
    }
    final list = row?.taskListId;
    if (list == null) return null;
    final l = await (db.select(db.taskLists)..where((x) => x.id.equals(list))).getSingleOrNull();
    return l != null && l.deletedAt == null ? list : null;
  }

  /// Levels of [id] and its live subtasks (1 = no subtasks).
  Future<int> _subtreeHeight(AppDatabase db, String id) async {
    var height = 0;
    var level = [id];
    final seen = <String>{};
    while (level.isNotEmpty && height <= maxTaskDepth + 1) {
      height++;
      final next = <String>[];
      for (final p in level) {
        if (!seen.add(p)) continue;
        final kids = await (db.select(db.tasks)..where((t) => t.parentTaskId.equals(p) & t.deletedAt.isNull())).get();
        next.addAll(kids.map((k) => k.id));
      }
      level = next;
    }
    return height;
  }

  /// P03 UX U2: one drop. The task goes to [place], after `afterId` (or at
  /// the end when [atEnd]); only its own row changes. Refused: a cycle, a
  /// subtree deeper than the limit (LF-INV-TASK-002/003), an unknown or
  /// trashed list or parent, a stale position.
  Future<HandlerOutcome> _move(AppDatabase db, Command cmd, String id, Version newVersion, DateTime now, Place place,
      {required bool atEnd, required String event}) async {
    await _liveTask(db, id);
    final ws = cmd.workspaceId;
    if (place.parentId != null) {
      await _liveParent(db, ws, place.parentId!);
      final err = TaskHierarchyRules.reparentError(
        taskId: EntityId(id),
        newParentId: EntityId(place.parentId!),
        newParentAncestorsIncludingSelf: await _ancestorsIncludingSelf(db, place.parentId!),
        newParentDepth: await _depthOf(db, place.parentId!),
        movedSubtreeHeight: await _subtreeHeight(db, id),
      );
      if (err != null) throw DomainRejection(err);
    }
    if (place.listId != null) await liveList(db, ws, place.listId!);
    final siblings = await itemSiblings(db, ws, place, exclude: id);
    final key = atEnd ? keyAtEnd(siblings) : keyAfter(siblings, cmd.payload['afterId']);
    await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(TasksCompanion(
        parentTaskId: Value(place.parentId),
        taskListId: Value(place.listId),
        orderKey: Value(key),
        version: Value(newVersion.value),
        updatedAt: Value(now)));
    return HandlerOutcome(
      entityId: id,
      operationType: 'update',
      changeSet: {'id': id, 'parentId': place.parentId, 'listId': place.listId, 'orderKey': key},
      events: [DomainEvent(event, {'id': id})],
    );
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();

    // P02 T4: schedule, occurrence change and occurrence completion.
    if (scheduleOps.contains(op)) return applyScheduleOp(db, cmd, newVersion, now);
    // P03 T4: habit flag, target and completion policy.
    if (targetOps.contains(op)) return applyTargetOp(db, cmd, newVersion, now);

    switch (op) {
      case 'create':
        final parentId = cmd.payload['parentId'] as String?;
        final depthErr = TaskHierarchyRules.createDepthError(
            parentId == null ? null : await _depthOf(db, parentId));
        if (depthErr != null) throw DomainRejection(depthErr);
        // P03 UX U2: a subtask follows its parent's list; a new item goes
        // to the end of its container.
        final listId = parentId == null ? cmd.payload['listId'] as String? : null;
        if (parentId != null) await _liveParent(db, cmd.workspaceId, parentId);
        if (listId != null) await liveList(db, cmd.workspaceId, listId);
        final place = Place(listId: listId, parentId: parentId);
        await db.into(db.tasks).insert(TasksCompanion.insert(
              id: id,
              workspaceId: cmd.workspaceId,
              ownerId: cmd.actor.id,
              createdAt: now,
              updatedAt: now,
              title: cmd.payload['title'] as String,
              parentTaskId: Value(parentId),
              taskListId: Value(listId),
              colorIndex: Value(colorOf(cmd.payload)),
              orderKey: Value(keyAtEnd(await itemSiblings(db, cmd.workspaceId, place))),
              version: Value(newVersion.value),
            ));
        return HandlerOutcome(
          entityId: id,
          operationType: 'create',
          changeSet: {'id': id, 'title': cmd.payload['title']},
          events: [DomainEvent('TaskCreated', {'id': id})],
        );

      case 'rename':
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(title: Value(cmd.payload['title'] as String), version: Value(newVersion.value), updatedAt: Value(now)));
        return HandlerOutcome(entityId: id, operationType: 'update', changeSet: {'id': id, 'title': cmd.payload['title']}, events: [DomainEvent('TaskUpdated', {'id': id})]);

      case 'reparent':
        // Kept for the task editor: appended at the end of the new place. To
        // the top level, the task goes to the list of its top-level task.
        final newParentId = cmd.payload['newParentId'] as String?;
        return _move(db, cmd, id, newVersion, now,
            Place(parentId: newParentId, listId: newParentId == null ? await _rootListOf(db, id) : null),
            atEnd: true, event: 'TaskReparented');

      case 'move':
        return _move(db, cmd, id, newVersion, now, Place.of(cmd.payload), atEnd: false, event: 'TaskMoved');

      case 'setNotes':
        await _liveTask(db, id);
        final raw = cmd.payload['notes'];
        if (raw != null && raw is! String) throw DomainRejection('bad notes');
        final text = (raw as String?)?.trim();
        final notes = text == null || text.isEmpty ? null : text;
        if (notes != null && notes.length > maxTaskNotesLength) throw DomainRejection('the notes are too long');
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(notes: Value(notes), version: Value(newVersion.value), updatedAt: Value(now)));
        return HandlerOutcome(entityId: id, operationType: 'update', changeSet: {'id': id, 'notes': notes != null}, events: [DomainEvent('TaskUpdated', {'id': id})]);

      case 'setColor':
        await _liveTask(db, id);
        final color = colorOf(cmd.payload);
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(colorIndex: Value(color), version: Value(newVersion.value), updatedAt: Value(now)));
        return HandlerOutcome(entityId: id, operationType: 'update', changeSet: {'id': id, 'colorIndex': color}, events: [DomainEvent('TaskUpdated', {'id': id})]);

      case 'complete':
        final cascade = cmd.payload['cascade'] as String? ?? 'parentOnly';
        final current = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
        // P03 D8: with automatic completion the state is derived from the
        // measurements and cannot be ticked by hand (LF-INV-TASK-010).
        if (current.completionPolicy == 'automatic') {
          throw DomainRejection('the completion is derived from the measurements');
        }
        final from = TaskStatus.values.byName(current.status);
        if (!isValidTransition(from, TaskStatus.done)) {
          throw DomainRejection('invalid transition ${current.status} -> done');
        }
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(status: const Value('done'), version: Value(newVersion.value), updatedAt: Value(now)));
        await _lateTick(db, cmd, id, done: true, now: now);
        var openChildren = <String>[];
        if (cascade == 'all') {
          final children = await (db.select(db.tasks)
                ..where((t) => t.parentTaskId.equals(id) & t.deletedAt.isNull()))
              .get();
          final touched = <String, String>{};
          for (final c in children.where((c) => c.status != 'done')) {
            // Version and updatedAt move too, and sync sees the change
            // (LF-INV-VER-001, LF-INV-OUTBOX-001).
            await _bump(db, c, now, const TasksCompanion(status: Value('done')));
            touched[c.id] = 'update';
          }
          await _outboxFor(db, cmd, touched, now);
        } else {
          final children = await (db.select(db.tasks)
                ..where((t) => t.parentTaskId.equals(id) & t.deletedAt.isNull()))
              .get();
          openChildren = children.where((c) => c.status != 'done').map((c) => c.id).toList();
        }
        return HandlerOutcome(
          entityId: id,
          operationType: 'update',
          changeSet: {'id': id, 'status': 'done', 'cascade': cascade, if (openChildren.isNotEmpty) 'openSubtasksAtCompletion': openChildren},
          events: [DomainEvent('TaskCompleted', {'id': id})],
        );

      case 'reopen':
        // Undo a completion (done/cancelled -> todo). Subtasks are not
        // touched: reopening a parent does not reopen work already finished.
        final current = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
        final from = TaskStatus.values.byName(current.status);
        if (from != TaskStatus.done && from != TaskStatus.cancelled) {
          throw DomainRejection('the task is not completed');
        }
        if (!isValidTransition(from, TaskStatus.todo)) {
          throw DomainRejection('invalid transition ${current.status} -> todo');
        }
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(status: const Value('todo'), version: Value(newVersion.value), updatedAt: Value(now)));
        await _lateTick(db, cmd, id, done: false, now: now);
        return HandlerOutcome(
          entityId: id,
          operationType: 'update',
          changeSet: {'id': id, 'status': 'todo', 'reopenedFrom': current.status},
          events: [DomainEvent('TaskReopened', {'id': id})],
        );

      case 'trash':
        // cascade 'all'        : the task and every live descendant are trashed
        // cascade 'parentOnly' : only the task; its direct children move up to
        //                        its parent (nothing is left under a tombstone)
        final cascade = cmd.payload['cascade'] as String? ?? 'parentOnly';
        final target = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(deletedAt: Value(now), deletedBy: Value(cmd.actor.toString()), version: Value(newVersion.value), updatedAt: Value(now)));
        final touched = <String, String>{}; // id -> outbox operation type
        if (cascade == 'all') {
          final frontier = [id];
          final seen = {id};
          while (frontier.isNotEmpty) {
            final kids = await (db.select(db.tasks)
                  ..where((t) => t.parentTaskId.equals(frontier.removeLast()) & t.deletedAt.isNull()))
                .get();
            for (final k in kids) {
              if (!seen.add(k.id)) continue;
              frontier.add(k.id);
              await _bump(db, k, now, TasksCompanion(deletedAt: Value(now), deletedBy: Value(cmd.actor.toString())));
              touched[k.id] = 'delete';
            }
          }
        } else {
          final kids = await (db.select(db.tasks)
                ..where((t) => t.parentTaskId.equals(id) & t.deletedAt.isNull()))
              .get();
          // They take the trashed task's place, in their order (P03 UX U2):
          // its parent, or its list at the top level.
          kids.sort((a, b) => a.orderKey != b.orderKey ? a.orderKey.compareTo(b.orderKey) : a.id.compareTo(b.id));
          final place = Place(parentId: target.parentTaskId, listId: target.parentTaskId == null ? target.taskListId : null);
          final keys = keysAfterKey(await itemSiblings(db, cmd.workspaceId, place), target.orderKey, kids.length);
          for (var i = 0; i < kids.length; i++) {
            await _bump(db, kids[i], now, TasksCompanion(
                parentTaskId: Value(target.parentTaskId), taskListId: Value(place.listId), orderKey: Value(keys[i])));
            touched[kids[i].id] = 'update';
          }
        }
        await _outboxFor(db, cmd, touched, now);
        return HandlerOutcome(
          entityId: id,
          operationType: 'delete',
          changeSet: {
            'id': id,
            'tombstone': true,
            'cascade': cascade,
            if (touched.isNotEmpty) 'subtasks': touched.keys.toList(),
          },
          events: [DomainEvent('TaskTrashed', {'id': id, 'cascade': cascade})],
        );

      default:
        throw DomainRejection('unknown op: $op');
    }
  }
}


