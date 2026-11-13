// P03 UX U2 (ADR-0046): containers and order keys for lists, tasks and
// events, shared by the list, task and event handlers.
//
// Containers (LF-INV-ORDER-001):
//   the lists of a workspace;
//   the top-level items in no list: tasks without a parent and events;
//   the top-level items of a list: tasks without a parent and events;
//   the subtasks of a task.
// A subtask follows its top-level task's list and keeps no list of its own
// (task_list_id is null below the top level). An event is never under a task
// (U-D1). An item in a list that is not live (only after a merge restore) is
// shown, and ordered, as an item in no list.
//
// Items are shown by order key, then id. A drop gives the moved item one new
// key between its neighbours: one row is rewritten (R-DATA-LOSS).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';

/// Where a task or an event goes: a list (or none) at the top level, or
/// under a task. [afterId] is the item it is dropped after; null = first.
class Place {
  const Place({this.listId, this.parentId});
  final String? listId;
  final String? parentId;

  /// Reads `listId`, `parentId` from a command payload (untrusted).
  factory Place.of(Map<String, Object?> payload) {
    final l = payload['listId'], p = payload['parentId'];
    if ((l != null && l is! String) || (p != null && p is! String)) throw DomainRejection('bad place');
    if (l != null && p != null) throw DomainRejection('a subtask follows the list of its parent');
    return Place(listId: l as String?, parentId: p as String?);
  }
}

typedef Keyed = ({String id, String key});

int _byKey(Keyed a, Keyed b) {
  final c = a.key.compareTo(b.key);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// The live lists of [ws], in order.
Future<List<Keyed>> listSiblings(AppDatabase db, String ws, {String? exclude}) async {
  final rows = await (db.select(db.taskLists)..where((l) => l.workspaceId.equals(ws) & l.deletedAt.isNull())).get();
  return [
    for (final l in rows)
      if (l.id != exclude) (id: l.id, key: l.orderKey)
  ]..sort(_byKey);
}

Future<Set<String>> _liveListIds(AppDatabase db, String ws) async =>
    {for (final l in await listSiblings(db, ws)) l.id};

/// The live items in [place] of [ws], in order, without [exclude].
Future<List<Keyed>> itemSiblings(AppDatabase db, String ws, Place place, {String? exclude}) async {
  final out = <Keyed>[];
  if (place.parentId != null) {
    final kids = await (db.select(db.tasks)
          ..where((t) => t.parentTaskId.equals(place.parentId!) & t.deletedAt.isNull() & t.workspaceId.equals(ws)))
        .get();
    out.addAll([for (final t in kids) (id: t.id, key: t.orderKey)]);
  } else {
    final live = await _liveListIds(db, ws);
    bool here(String? list) => (list != null && live.contains(list) ? list : null) == place.listId;
    final tasks = await (db.select(db.tasks)
          ..where((t) => t.parentTaskId.isNull() & t.deletedAt.isNull() & t.workspaceId.equals(ws)))
        .get();
    final events = await (db.select(db.events)..where((e) => e.deletedAt.isNull() & e.workspaceId.equals(ws))).get();
    out.addAll([
      for (final t in tasks)
        if (here(t.taskListId)) (id: t.id, key: t.orderKey),
      for (final e in events)
        if (here(e.listId)) (id: e.id, key: e.orderKey),
    ]);
  }
  out.removeWhere((k) => k.id == exclude);
  return out..sort(_byKey);
}

/// The key for an item dropped after [afterId] among [siblings] (null =
/// first). Refused when [afterId] is not in the container any more.
String keyAfter(List<Keyed> siblings, Object? afterId) {
  if (afterId != null && afterId is! String) throw DomainRejection('bad position');
  int? at;
  if (afterId != null) {
    at = siblings.indexWhere((s) => s.id == afterId);
    if (at < 0) throw DomainRejection('the drop position is out of date');
  }
  return orderKeyAfterIndex([for (final s in siblings) s.key], at);
}

/// The key for a new item at the end of [siblings].
String keyAtEnd(List<Keyed> siblings) => orderKeyBetween(siblings.isEmpty ? null : siblings.last.key, null);

/// [n] increasing keys right after [prevKey] and before the next larger key
/// of [siblings] (the subtasks of a trashed task taking its place).
List<String> keysAfterKey(List<Keyed> siblings, String prevKey, int n) {
  String? next;
  for (final s in siblings) {
    if (s.key.compareTo(prevKey) > 0) {
      next = s.key;
      break;
    }
  }
  final out = <String>[];
  var prev = prevKey;
  for (var i = 0; i < n; i++) {
    prev = orderKeyBetween(prev, next);
    out.add(prev);
  }
  return out;
}

/// The live list [id] of [ws], or a refusal.
Future<TaskList> liveList(AppDatabase db, String ws, String id) async {
  final l = await (db.select(db.taskLists)..where((x) => x.id.equals(id))).getSingleOrNull();
  if (l == null || l.deletedAt != null || l.workspaceId != ws) throw DomainRejection('unknown list');
  return l;
}

/// Checks a colour from a payload (untrusted): an index or null.
int? colorOf(Map<String, Object?> payload) {
  final c = payload['colorIndex'];
  if (c != null && (c is! int || itemColorError(c) != null)) throw DomainRejection('unknown colour');
  return c as int?;
}

/// One outbox row for another row the command changed, under the command's
/// operation (LF-INV-OUTBOX-001).
Future<void> outboxRow(AppDatabase db, Command cmd, String entityType, String id, String opType, int base,
        Map<String, Object?> payload, DateTime now) =>
    db.into(db.outbox).insert(OutboxCompanion.insert(
          operationId: cmd.operationId,
          entityId: id,
          entityType: entityType,
          workspaceId: cmd.workspaceId,
          actorId: cmd.actor.toString(),
          operationType: opType,
          baseVersion: Value(base),
          payload: jsonEncode(payload),
          createdAt: now,
        ));
