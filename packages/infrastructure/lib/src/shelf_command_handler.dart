// P06b W6 (ADR-0094): archive, unarchive, restore a task from the trash, and
// delete for good, of a list, a task, an event or a document, on the single
// mutation path (ADR-0011) with the atomic set (ADR-0014).
//
// ShelfCommandHandler(kind), payload['op']:
//   archive     id   it and what is in it (a list: its tasks and events; a
//                    task: its subtasks; a document: its subdocuments) leave
//                    the screens, at one moment
//   unarchive   id   it and what went with it (the same moment) come back
//   restore     id   (tasks only) from the trash, with what went with it
//   purge       id   (in the trash) deleted for good: the content is blanked
//                    and the tombstone stays, so every device does the same
//                    and the server's purge later drops the row (GS-14)
//
// What went with an item is told by the moment: archive sets one `archivedAt`
// on all of it, trash one `deletedAt`, as a list's trash and restore do.
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'organize_ops.dart';
import 'record_kinds.dart' show recordKindByName;

/// What one row is, for the work on a set of them.
class _Item {
  const _Item(this.kind, this.id, this.version);
  final String kind;
  final String id;
  final int version;
}

class ShelfCommandHandler implements CommandHandler {
  const ShelfCommandHandler(this.kind);

  /// 'taskList' | 'task' | 'event' | 'document'.
  final String kind;

  @override
  String get entityType => kind;

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final db = (tx as DriftTx).db;
    final row = await recordKindByName[kind]!.readOne(db, cmd.payload['id'] as String);
    return row == null ? null : Version(row['version'] as int);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    final op = cmd.payload['op'] as String;
    final id = cmd.payload['id'] as String;
    final now = DateTime.now().toUtc();
    final root = await _row(db, kind, id);
    if (root == null || root.workspaceId != cmd.workspaceId) throw DomainRejection('$kind not found');

    HandlerOutcome outcome(Map<String, Object?> change, String event) => HandlerOutcome(
        entityId: id,
        operationType: 'update',
        changeSet: {'id': id, ...change},
        events: [DomainEvent(event, {'id': id, 'kind': kind})]);

    switch (op) {
      case 'archive':
        if (root.deletedAt != null) throw DomainRejection('$kind is in the trash');
        if (root.archivedAt != null) throw DomainRejection('$kind is already archived');
        final set = await _within(db, root, (r) => r.deletedAt == null && r.archivedAt == null);
        await _setArchived(db, cmd, set, root, now, now, newVersion);
        return outcome({'archived': true, 'with': set.length - 1}, 'ItemArchived');

      case 'unarchive':
        final at = root.archivedAt;
        if (at == null) throw DomainRejection('$kind is not archived');
        final set = await _within(db, root, (r) => r.archivedAt != null && r.archivedAt!.isAtSameMomentAs(at));
        await _setArchived(db, cmd, set, root, null, now, newVersion);
        // Back where it was, unless what held it is away: then at the top.
        await _placeAfterUnarchive(db, root, now);
        return outcome({'archived': false, 'with': set.length - 1}, 'ItemUnarchived');

      case 'restore':
        if (kind != 'task') throw DomainRejection('unknown op: $op');
        final gone = root.deletedAt;
        if (gone == null || root.purgedAt != null) throw DomainRejection('the task is not in the trash');
        final set = await _within(db, root, (r) => r.deletedAt != null && r.deletedAt!.isAtSameMomentAs(gone) && r.purgedAt == null);
        for (final item in set) {
          final v = item.id == id ? newVersion.value : item.version + 1;
          final t = await (db.select(db.tasks)..where((x) => x.id.equals(item.id))).getSingle();
          // Back where it was: under its parent and in its list, when they are
          // live; else at the top, in no list.
          var parent = t.parentTaskId, list = t.taskListId;
          if (item.id == id) {
            if (parent != null && !await _liveTask(db, parent)) parent = null;
            if (list != null && !await _liveList(db, list)) list = null;
          }
          await (db.update(db.tasks)..where((x) => x.id.equals(item.id))).write(TasksCompanion(
              deletedAt: const Value(null),
              deletedBy: const Value(null),
              parentTaskId: Value(parent),
              taskListId: Value(list),
              version: Value(v),
              updatedAt: Value(now)));
          if (item.id != id) await outboxRow(db, cmd, 'task', item.id, 'update', item.version, {'id': item.id, 'tombstone': false}, now);
        }
        return outcome({'tombstone': false, 'with': set.length - 1}, 'TaskRestored');

      case 'purge':
        final gone = root.deletedAt;
        if (gone == null) throw DomainRejection('$kind is not in the trash');
        if (root.purgedAt != null) throw DomainRejection('$kind is already deleted');
        final set = await _within(db, root, (r) => r.deletedAt != null && r.deletedAt!.isAtSameMomentAs(gone) && r.purgedAt == null);
        for (final item in set) {
          final v = item.id == root.id ? newVersion.value : item.version + 1;
          await _blank(db, item, v, now);
          if (item.id != id) await outboxRow(db, cmd, item.kind, item.id, 'update', item.version, {'id': item.id, 'purged': true}, now);
          await _blankDependents(db, cmd, item, now);
        }
        return outcome({'purged': true, 'with': set.length - 1}, 'ItemPurged');
    }
    throw DomainRejection('unknown op: $op');
  }

  // ---- what is in an item -------------------------------------------------------

  /// [root] and what is in it, for which [take] says yes (the root itself
  /// always): a list's tasks (with their subtasks) and events; a task's
  /// subtasks; a document's subdocuments.
  Future<List<_Item>> _within(AppDatabase db, _Row root, bool Function(_Row) take) async {
    final out = <_Item>[_Item(kind, root.id, root.version)];
    final seen = {root.id};

    Future<void> tasksUnder(Iterable<String> starts) async {
      var frontier = starts.toList();
      while (frontier.isNotEmpty) {
        final next = <String>[];
        for (final p in frontier) {
          for (final k in await (db.select(db.tasks)..where((t) => t.parentTaskId.equals(p))).get()) {
            if (!seen.add(k.id)) continue;
            if (!take(_Row.ofTask(k))) continue;
            out.add(_Item('task', k.id, k.version));
            next.add(k.id);
          }
        }
        frontier = next;
      }
    }

    switch (kind) {
      case 'task':
        await tasksUnder([root.id]);
      case 'taskList':
        final tops = <String>[];
        for (final t in await (db.select(db.tasks)
              ..where((t) => t.workspaceId.equals(root.workspaceId) & t.taskListId.equals(root.id) & t.parentTaskId.isNull()))
            .get()) {
          if (!seen.add(t.id) || !take(_Row.ofTask(t))) continue;
          out.add(_Item('task', t.id, t.version));
          tops.add(t.id);
        }
        await tasksUnder(tops);
        for (final e in await (db.select(db.events)
              ..where((e) => e.workspaceId.equals(root.workspaceId) & e.listId.equals(root.id)))
            .get()) {
          if (take(_Row.ofEvent(e))) out.add(_Item('event', e.id, e.version));
        }
      case 'document':
        var frontier = [root.id];
        while (frontier.isNotEmpty) {
          final next = <String>[];
          for (final p in frontier) {
            for (final d in await (db.select(db.documents)..where((d) => d.parentId.equals(p))).get()) {
              if (!seen.add(d.id) || !take(_Row.ofDocument(d))) continue;
              out.add(_Item('document', d.id, d.version));
              next.add(d.id);
            }
          }
          frontier = next;
        }
    }
    return out;
  }

  // ---- archive ------------------------------------------------------------------

  Future<void> _setArchived(AppDatabase db, Command cmd, List<_Item> set, _Row root, DateTime? at, DateTime now,
      Version newVersion) async {
    for (final item in set) {
      final v = item.id == root.id ? newVersion.value : item.version + 1;
      final a = Value<DateTime?>(at);
      switch (item.kind) {
        case 'taskList':
          await (db.update(db.taskLists)..where((x) => x.id.equals(item.id)))
              .write(TaskListsCompanion(archivedAt: a, version: Value(v), updatedAt: Value(now)));
        case 'task':
          await (db.update(db.tasks)..where((x) => x.id.equals(item.id)))
              .write(TasksCompanion(archivedAt: a, version: Value(v), updatedAt: Value(now)));
        case 'event':
          await (db.update(db.events)..where((x) => x.id.equals(item.id)))
              .write(EventsCompanion(archivedAt: a, version: Value(v), updatedAt: Value(now)));
        case 'document':
          await (db.update(db.documents)..where((x) => x.id.equals(item.id)))
              .write(DocumentsCompanion(archivedAt: a, version: Value(v), updatedAt: Value(now)));
      }
      if (item.id != root.id) {
        await outboxRow(db, cmd, item.kind, item.id, 'update', item.version, {'id': item.id, 'archived': at != null}, now);
      }
    }
  }

  /// The unarchived root goes to the top when its parent or list is still
  /// away (archived or in the trash).
  Future<void> _placeAfterUnarchive(AppDatabase db, _Row root, DateTime now) async {
    Future<bool> away(Future<_Row?> f) async {
      final r = await f;
      return r == null || r.deletedAt != null || r.archivedAt != null;
    }

    switch (kind) {
      case 'task':
        final t = await (db.select(db.tasks)..where((x) => x.id.equals(root.id))).getSingle();
        final parentAway = t.parentTaskId != null && await away(_row(db, 'task', t.parentTaskId!));
        final listAway = t.taskListId != null && await away(_row(db, 'taskList', t.taskListId!));
        if (parentAway || listAway) {
          await (db.update(db.tasks)..where((x) => x.id.equals(root.id))).write(TasksCompanion(
              parentTaskId: parentAway ? const Value(null) : const Value.absent(),
              taskListId: listAway ? const Value(null) : const Value.absent()));
        }
      case 'event':
        final e = await (db.select(db.events)..where((x) => x.id.equals(root.id))).getSingle();
        if (e.listId != null && await away(_row(db, 'taskList', e.listId!))) {
          await (db.update(db.events)..where((x) => x.id.equals(root.id))).write(const EventsCompanion(listId: Value(null)));
        }
      case 'document':
        final d = await (db.select(db.documents)..where((x) => x.id.equals(root.id))).getSingle();
        if (d.parentId != null && await away(_row(db, 'document', d.parentId!))) {
          await (db.update(db.documents)..where((x) => x.id.equals(root.id))).write(const DocumentsCompanion(parentId: Value(null)));
        }
    }
  }

  Future<bool> _liveTask(AppDatabase db, String id) async {
    final r = await _row(db, 'task', id);
    return r != null && r.deletedAt == null;
  }

  Future<bool> _liveList(AppDatabase db, String id) async {
    final r = await _row(db, 'taskList', id);
    return r != null && r.deletedAt == null;
  }

  // ---- delete for good ----------------------------------------------------------

  /// The content of the row is gone; the row stays as a tombstone marked
  /// purged (what it was is no longer anywhere on this device).
  Future<void> _blank(AppDatabase db, _Item item, int version, DateTime now) async {
    final p = Value<DateTime?>(now);
    switch (item.kind) {
      case 'taskList':
        await (db.update(db.taskLists)..where((x) => x.id.equals(item.id)))
            .write(TaskListsCompanion(title: const Value(''), purgedAt: p, version: Value(version), updatedAt: Value(now)));
      case 'task':
        await (db.update(db.tasks)..where((x) => x.id.equals(item.id))).write(TasksCompanion(
            title: const Value(''),
            notes: const Value(null),
            tags: const Value('[]'),
            unit: const Value(null),
            purgedAt: p,
            version: Value(version),
            updatedAt: Value(now)));
      case 'event':
        await (db.update(db.events)..where((x) => x.id.equals(item.id))).write(EventsCompanion(
            title: const Value(''), location: const Value(null), purgedAt: p, version: Value(version), updatedAt: Value(now)));
      case 'document':
        await (db.update(db.documents)..where((x) => x.id.equals(item.id))).write(DocumentsCompanion(
            title: const Value(''),
            body: Value(DocumentBody([]).encode()),
            purgedAt: p,
            version: Value(version),
            updatedAt: Value(now)));
    }
  }

  /// What belongs to a purged row goes too: a task's or an event's schedule,
  /// changes of its days, done ticks and reminders; a document's revisions
  /// (they hold its old text) and links. Each is a tombstone, as clearing a
  /// schedule is (SYNC-004).
  Future<void> _blankDependents(AppDatabase db, Command cmd, _Item item, DateTime now) async {
    final by = cmd.actor.toString();

    Future<void> tomb<T extends Table, D>(String kindName, List<(String, int)> rows, Future<void> Function(String id, int v) write) async {
      for (final (rid, version) in rows) {
        await write(rid, version + 1);
        await outboxRow(db, cmd, kindName, rid, 'delete', version, {'id': rid, 'tombstone': true}, now);
      }
    }

    if (item.kind == 'task' || item.kind == 'event') {
      await tomb('schedule', [
        for (final s in await (db.select(db.schedules)
              ..where((s) => s.subjectType.equals(item.kind) & s.subjectId.equals(item.id) & s.deletedAt.isNull()))
            .get())
          (s.id, s.version)
      ], (rid, v) => (db.update(db.schedules)..where((x) => x.id.equals(rid)))
          .write(SchedulesCompanion(deletedAt: Value(now), deletedBy: Value(by), version: Value(v), updatedAt: Value(now))));
      // P06c: its extra times are tombstoned too (their content is only a time).
      await tomb('extraTime', [
        for (final s in await (db.select(db.extraTimes)
              ..where((s) => s.subjectType.equals(item.kind) & s.subjectId.equals(item.id) & s.deletedAt.isNull()))
            .get())
          (s.id, s.version)
      ], (rid, v) => (db.update(db.extraTimes)..where((x) => x.id.equals(rid)))
          .write(ExtraTimesCompanion(deletedAt: Value(now), deletedBy: Value(by), version: Value(v), updatedAt: Value(now))));
      await tomb('exception', [
        for (final s in await (db.select(db.occurrenceExceptions)
              ..where((s) => s.subjectType.equals(item.kind) & s.subjectId.equals(item.id) & s.deletedAt.isNull()))
            .get())
          (s.id, s.version)
      ], (rid, v) => (db.update(db.occurrenceExceptions)..where((x) => x.id.equals(rid))).write(OccurrenceExceptionsCompanion(
          deletedAt: Value(now), deletedBy: Value(by), patch: const Value(null), version: Value(v), updatedAt: Value(now))));
      await tomb('reminder', [
        for (final s in await (db.select(db.reminders)
              ..where((s) => s.subjectType.equals(item.kind) & s.subjectId.equals(item.id) & s.deletedAt.isNull()))
            .get())
          (s.id, s.version)
      ], (rid, v) => (db.update(db.reminders)..where((x) => x.id.equals(rid)))
          .write(RemindersCompanion(deletedAt: Value(now), deletedBy: Value(by), version: Value(v), updatedAt: Value(now))));
    }
    if (item.kind == 'task') {
      await tomb('completion', [
        for (final s in await (db.select(db.occurrenceCompletions)..where((s) => s.taskId.equals(item.id) & s.deletedAt.isNull())).get())
          (s.id, s.version)
      ], (rid, v) => (db.update(db.occurrenceCompletions)..where((x) => x.id.equals(rid)))
          .write(OccurrenceCompletionsCompanion(deletedAt: Value(now), deletedBy: Value(by), version: Value(v), updatedAt: Value(now))));
    }
    if (item.kind == 'document') {
      // Every revision, trashed or not: each holds a title and a body.
      await tomb('documentRevision', [
        for (final r in await (db.select(db.documentRevisions)..where((r) => r.documentId.equals(item.id))).get()) (r.id, r.version)
      ], (rid, v) => (db.update(db.documentRevisions)..where((x) => x.id.equals(rid))).write(DocumentRevisionsCompanion(
          title: const Value(''),
          body: Value(DocumentBody([]).encode()),
          deletedAt: Value(now),
          deletedBy: Value(by),
          version: Value(v),
          updatedAt: Value(now))));
      await tomb('documentLink', [
        for (final l in await (db.select(db.documentLinks)..where((l) => l.documentId.equals(item.id) & l.deletedAt.isNull())).get())
          (l.id, l.version)
      ], (rid, v) => (db.update(db.documentLinks)..where((x) => x.id.equals(rid)))
          .write(DocumentLinksCompanion(deletedAt: Value(now), deletedBy: Value(by), version: Value(v), updatedAt: Value(now))));
    }
  }
}

/// The fields of a row of the four kinds that the work looks at.
class _Row {
  const _Row(this.id, this.workspaceId, this.version, this.deletedAt, this.archivedAt, this.purgedAt);
  factory _Row.ofTask(Task t) => _Row(t.id, t.workspaceId, t.version, t.deletedAt, t.archivedAt, t.purgedAt);
  factory _Row.ofList(TaskList t) => _Row(t.id, t.workspaceId, t.version, t.deletedAt, t.archivedAt, t.purgedAt);
  factory _Row.ofEvent(Event t) => _Row(t.id, t.workspaceId, t.version, t.deletedAt, t.archivedAt, t.purgedAt);
  factory _Row.ofDocument(DocumentRow t) => _Row(t.id, t.workspaceId, t.version, t.deletedAt, t.archivedAt, t.purgedAt);
  final String id;
  final String workspaceId;
  final int version;
  final DateTime? deletedAt;
  final DateTime? archivedAt;
  final DateTime? purgedAt;
}

Future<_Row?> _row(AppDatabase db, String kind, String id) async => switch (kind) {
      'task' => await (db.select(db.tasks)..where((x) => x.id.equals(id))).getSingleOrNull().then((r) => r == null ? null : _Row.ofTask(r)),
      'taskList' =>
        await (db.select(db.taskLists)..where((x) => x.id.equals(id))).getSingleOrNull().then((r) => r == null ? null : _Row.ofList(r)),
      'event' => await (db.select(db.events)..where((x) => x.id.equals(id))).getSingleOrNull().then((r) => r == null ? null : _Row.ofEvent(r)),
      'document' =>
        await (db.select(db.documents)..where((x) => x.id.equals(id))).getSingleOrNull().then((r) => r == null ? null : _Row.ofDocument(r)),
      _ => null,
    };
