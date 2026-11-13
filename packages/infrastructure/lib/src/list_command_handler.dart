// P03 UX U2 (ADR-0046): task lists, on the single mutation path (ADR-0011)
// with the atomic set (ADR-0014). A list holds top-level tasks (with their
// subtasks) and events (U-D1).
//
// ListCommandHandler, payload['op']:
//   create    id, title, colorIndex?        (at the end of the lists)
//   rename    id, title
//   setColor  id, colorIndex?
//   move      id, afterId?                  (one row rewritten)
//   trash     id: the list, its top-level tasks with all their subtasks, and
//             its events go to the trash together (one tombstone time)
//   restore   id: the list and what went to the trash with it (same time
//             and actor); items trashed on their own before stay there
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'organize_ops.dart';

class ListCommandHandler implements CommandHandler {
  const ListCommandHandler();

  @override
  String get entityType => 'taskList';

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await (db.select(db.taskLists)..where((l) => l.id.equals(cmd.payload['id'] as String)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  String _title(Command cmd) {
    final t = cmd.payload['title'];
    final s = t is String ? t.trim() : '';
    if (s.isEmpty) throw DomainRejection('title is empty');
    return s;
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();
    final ws = cmd.workspaceId;
    final existing = await (db.select(db.taskLists)..where((l) => l.id.equals(id))).getSingleOrNull();

    HandlerOutcome outcome(String type, String event, Map<String, Object?> change) => HandlerOutcome(
        entityId: id, operationType: type, changeSet: {'id': id, ...change}, events: [DomainEvent(event, {'id': id})]);

    TaskList live() {
      if (existing == null || existing.deletedAt != null || existing.workspaceId != ws) {
        throw DomainRejection('list not found');
      }
      return existing;
    }

    Future<void> write(TaskListsCompanion c) => (db.update(db.taskLists)..where((l) => l.id.equals(id)))
        .write(c.copyWith(version: Value(newVersion.value), updatedAt: Value(now)));

    switch (op) {
      case 'create':
        if (existing != null) throw DomainRejection('the list already exists');
        final title = _title(cmd);
        final key = keyAtEnd(await listSiblings(db, ws));
        await db.into(db.taskLists).insert(TaskListsCompanion.insert(
              id: id,
              workspaceId: ws,
              ownerId: cmd.actor.id,
              createdAt: now,
              updatedAt: now,
              title: title,
              colorIndex: Value(colorOf(cmd.payload)),
              orderKey: Value(key),
              version: Value(newVersion.value),
            ));
        return outcome('create', 'ListCreated', {'title': title, 'orderKey': key});

      case 'rename':
        live();
        final title = _title(cmd);
        await write(TaskListsCompanion(title: Value(title)));
        return outcome('update', 'ListUpdated', {'title': title});

      case 'setColor':
        live();
        final color = colorOf(cmd.payload);
        await write(TaskListsCompanion(colorIndex: Value(color)));
        return outcome('update', 'ListUpdated', {'colorIndex': color});

      case 'move':
        live();
        final key = keyAfter(await listSiblings(db, ws, exclude: id), cmd.payload['afterId']);
        await write(TaskListsCompanion(orderKey: Value(key)));
        return outcome('update', 'ListMoved', {'orderKey': key});

      case 'trash':
        live();
        final by = cmd.actor.toString();
        await write(TaskListsCompanion(deletedAt: Value(now), deletedBy: Value(by)));
        final touched = await _contents(db, ws, id, (deletedAt) => deletedAt == null);
        await _setTombstones(db, cmd, touched, now, by, trash: true);
        return outcome('delete', 'ListTrashed',
            {'tombstone': true, 'tasks': touched.tasks.length, 'events': touched.events.length});

      case 'restore':
        if (existing == null || existing.workspaceId != ws) throw DomainRejection('list not found');
        final at = existing.deletedAt;
        if (at == null) throw DomainRejection('the list is not in the trash');
        final by = existing.deletedBy;
        await write(const TaskListsCompanion(deletedAt: Value(null), deletedBy: Value(null)));
        // What went with it: the same tombstone time and actor.
        final touched = await _contents(db, ws, id, (d) => d != null && d.isAtSameMomentAs(at), by: by);
        await _setTombstones(db, cmd, touched, now, null, trash: false);
        return outcome('update', 'ListRestored',
            {'tombstone': false, 'tasks': touched.tasks.length, 'events': touched.events.length});
    }
    throw DomainRejection('unknown op: $op');
  }

  /// The top-level tasks of list [listId] with all their subtasks, and its
  /// events, whose tombstone time passes [select] (and actor, when [by]).
  Future<({List<Task> tasks, List<Event> events})> _contents(
      AppDatabase db, String ws, String listId, bool Function(DateTime?) select,
      {String? by}) async {
    bool take(DateTime? at, String? who) => select(at) && (by == null || who == by);
    final tasks = <Task>[];
    var frontier = [
      for (final t in await (db.select(db.tasks)
            ..where((t) => t.workspaceId.equals(ws) & t.taskListId.equals(listId) & t.parentTaskId.isNull()))
          .get())
        if (take(t.deletedAt, t.deletedBy)) t
    ];
    final seen = <String>{};
    while (frontier.isNotEmpty) {
      final next = <Task>[];
      for (final t in frontier) {
        if (!seen.add(t.id)) continue;
        tasks.add(t);
        next.addAll([
          for (final k in await (db.select(db.tasks)..where((k) => k.parentTaskId.equals(t.id))).get())
            if (take(k.deletedAt, k.deletedBy)) k
        ]);
      }
      frontier = next;
    }
    final events = [
      for (final e in await (db.select(db.events)..where((e) => e.workspaceId.equals(ws) & e.listId.equals(listId))).get())
        if (take(e.deletedAt, e.deletedBy)) e
    ];
    return (tasks: tasks, events: events);
  }

  /// Trashes or restores [rows], each with its own version and an outbox
  /// row under the command's operation (LF-INV-VER-001, LF-INV-OUTBOX-001).
  Future<void> _setTombstones(AppDatabase db, Command cmd, ({List<Task> tasks, List<Event> events}) rows,
      DateTime now, String? by, {required bool trash}) async {
    final at = Value(trash ? now : null);
    for (final t in rows.tasks) {
      await (db.update(db.tasks)..where((x) => x.id.equals(t.id))).write(TasksCompanion(
          deletedAt: at, deletedBy: Value(by), version: Value(t.version + 1), updatedAt: Value(now)));
      await outboxRow(db, cmd, 'task', t.id, trash ? 'delete' : 'update', t.version,
          {'id': t.id, 'tombstone': trash, 'listId': t.taskListId}, now);
    }
    for (final e in rows.events) {
      await (db.update(db.events)..where((x) => x.id.equals(e.id))).write(EventsCompanion(
          deletedAt: at, deletedBy: Value(by), version: Value(e.version + 1), updatedAt: Value(now)));
      await outboxRow(db, cmd, 'event', e.id, trash ? 'delete' : 'update', e.version,
          {'id': e.id, 'tombstone': trash, 'listId': e.listId}, now);
    }
  }
}
