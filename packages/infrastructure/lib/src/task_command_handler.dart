import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' hide Task;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';

/// Applies Task commands within the gateway transaction (T3). Enforces the
/// domain rules (status transitions, hierarchy depth/acyclicity) before
/// writing, so every rule runs on the single mutation path (ADR-0011).
///
/// Supported command types (via payload['op']):
///   create   : payload id, title, parentId?, listId?
///   rename   : payload id, title
///   complete : payload id, cascade ('all'|'parentOnly')
///   reopen   : payload id (done/cancelled -> todo)
///   reparent : payload id, newParentId?
///   trash    : payload id, cascade ('all'|'parentOnly'; default parentOnly)
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

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();

    switch (op) {
      case 'create':
        final parentId = cmd.payload['parentId'] as String?;
        final depthErr = TaskHierarchyRules.createDepthError(
            parentId == null ? null : await _depthOf(db, parentId));
        if (depthErr != null) throw DomainRejection(depthErr);
        await db.into(db.tasks).insert(TasksCompanion.insert(
              id: id,
              workspaceId: cmd.workspaceId,
              ownerId: cmd.actor.id,
              createdAt: now,
              updatedAt: now,
              title: cmd.payload['title'] as String,
              parentTaskId: Value(parentId),
              taskListId: Value(cmd.payload['listId'] as String?),
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
        final newParentId = cmd.payload['newParentId'] as String?;
        if (newParentId != null) {
          final err = TaskHierarchyRules.reparentError(
            taskId: EntityId(id),
            newParentId: EntityId(newParentId),
            newParentAncestorsIncludingSelf: await _ancestorsIncludingSelf(db, newParentId),
            newParentDepth: await _depthOf(db, newParentId),
          );
          if (err != null) throw DomainRejection(err);
        }
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(parentTaskId: Value(newParentId), version: Value(newVersion.value), updatedAt: Value(now)));
        return HandlerOutcome(entityId: id, operationType: 'update', changeSet: {'id': id, 'parentId': newParentId}, events: [DomainEvent('TaskReparented', {'id': id})]);

      case 'complete':
        final cascade = cmd.payload['cascade'] as String? ?? 'parentOnly';
        final current = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingle();
        final from = TaskStatus.values.byName(current.status);
        if (!isValidTransition(from, TaskStatus.done)) {
          throw DomainRejection('invalid transition ${current.status} -> done');
        }
        await (db.update(db.tasks)..where((t) => t.id.equals(id))).write(
            TasksCompanion(status: const Value('done'), version: Value(newVersion.value), updatedAt: Value(now)));
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
          for (final k in kids) {
            await _bump(db, k, now, TasksCompanion(parentTaskId: Value(target.parentTaskId)));
            touched[k.id] = 'update';
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


