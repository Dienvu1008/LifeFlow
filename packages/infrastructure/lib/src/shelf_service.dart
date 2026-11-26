// P06b W6 (ADR-0094): the Archive and the Trash of the shown space.
//   lists      what is archived, what is in the trash (top level only: what
//              went with an item comes back, or goes, with it)
//   commands   archive, unarchive, delete for good: the shelf handler;
//              restore: the list's, the event's, the document's own handler
//              (they place the item again), and the shelf handler for a task
//   retention  what has been in the trash long enough is deleted for good
import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'document_command_handler.dart';
import 'event_command_handlers.dart';
import 'list_command_handler.dart';
import 'profile_store.dart';
import 'record_kinds.dart' show recordKindByName;
import 'shelf_command_handler.dart';

/// A row as the lists see it.
typedef _Rec = ({String id, String title, DateTime flag, String? parent, String? list});

class DriftShelfService implements ShelfService, ShelfQueries {
  DriftShelfService(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;
  final _uuid = const Uuid();

  static String _entityOf(ShelfKind k) => switch (k) {
        ShelfKind.list => 'taskList',
        ShelfKind.task => 'task',
        ShelfKind.event => 'event',
        ShelfKind.document => 'document',
      };

  static String _word(ShelfKind k) => switch (k) {
        ShelfKind.list => 'List',
        ShelfKind.task => 'Task',
        ShelfKind.event => 'Event',
        ShelfKind.document => 'Document',
      };

  // ---- commands -----------------------------------------------------------------

  Future<CommandResult> _run(ShelfKind kind, CommandHandler handler, String type, String op, String id) async {
    final ctx = await _store.commandContext();
    if (ctx == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    final row = await recordKindByName[_entityOf(kind)]!.readOne(db, id);
    if (row == null || row['workspaceId'] != ctx.workspaceId) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'not found');
    }
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ctx.actor,
        workspaceId: ctx.workspaceId,
        type: type,
        payload: {'op': op, 'id': id},
        expectedVersion: Version(row['version'] as int),
        issuedAt: Instant.now(),
      ),
      handler,
    );
  }

  @override
  Future<CommandResult> archive(ShelfKind kind, String id) =>
      _run(kind, ShelfCommandHandler(_entityOf(kind)), 'Archive${_word(kind)}', 'archive', id);

  @override
  Future<CommandResult> unarchive(ShelfKind kind, String id) =>
      _run(kind, ShelfCommandHandler(_entityOf(kind)), 'Unarchive${_word(kind)}', 'unarchive', id);

  @override
  Future<CommandResult> purge(ShelfKind kind, String id) =>
      _run(kind, ShelfCommandHandler(_entityOf(kind)), 'Purge${_word(kind)}', 'purge', id);

  @override
  Future<CommandResult> restore(ShelfKind kind, String id) => switch (kind) {
        ShelfKind.task => _run(kind, ShelfCommandHandler('task'), 'RestoreTask', 'restore', id),
        ShelfKind.list => _run(kind, const ListCommandHandler(), 'RestoreList', 'restore', id),
        ShelfKind.event => _run(kind, const EventCommandHandler(), 'RestoreEvent', 'restore', id),
        ShelfKind.document => _run(kind, const DocumentCommandHandler(), 'RestoreDocument', 'restore', id),
      };

  @override
  Future<int> emptyTrash() async => _purgeAll(await trashed());

  @override
  Future<int> purgeOlderThan(int days, {Instant? now}) async {
    if (days <= 0) return 0;
    final cut = (now ?? Instant.now()).utc.subtract(Duration(days: days));
    return _purgeAll([for (final e in await trashed()) if (!e.at.isAfter(cut)) e]);
  }

  Future<int> _purgeAll(List<ShelfEntry> entries) async {
    var n = 0;
    for (final e in entries) {
      if (await purge(e.kind, e.id) is CommandOk) n++;
    }
    return n;
  }

  // ---- lists --------------------------------------------------------------------

  @override
  Future<List<ShelfEntry>> archived() => _entries(trash: false);

  @override
  Future<List<ShelfEntry>> trashed() => _entries(trash: true);

  Future<List<ShelfEntry>> _entries({required bool trash}) async {
    final ws = (await _store.getActiveProfile())?.activeWorkspaceId.value;
    if (ws == null) return const [];
    // In the trash: deleted and not for good. In the Archive: archived and
    // not in the trash.
    bool shown(DateTime? deleted, DateTime? archived, DateTime? purged) =>
        trash ? deleted != null && purged == null : archived != null && deleted == null;
    DateTime flagOf(DateTime? deleted, DateTime? archived) => (trash ? deleted : archived)!;

    final lists = <String, _Rec>{}, tasks = <String, _Rec>{}, events = <String, _Rec>{}, docs = <String, _Rec>{};
    final listTitles = <String, String>{};
    for (final l in await (db.select(db.taskLists)..where((l) => l.workspaceId.equals(ws))).get()) {
      listTitles[l.id] = l.title;
      if (shown(l.deletedAt, l.archivedAt, l.purgedAt)) {
        lists[l.id] = (id: l.id, title: l.title, flag: flagOf(l.deletedAt, l.archivedAt), parent: null, list: null);
      }
    }
    for (final t in await (db.select(db.tasks)..where((t) => t.workspaceId.equals(ws))).get()) {
      if (shown(t.deletedAt, t.archivedAt, t.purgedAt)) {
        tasks[t.id] = (id: t.id, title: t.title, flag: flagOf(t.deletedAt, t.archivedAt), parent: t.parentTaskId, list: t.taskListId);
      }
    }
    for (final e in await (db.select(db.events)..where((e) => e.workspaceId.equals(ws))).get()) {
      if (shown(e.deletedAt, e.archivedAt, e.purgedAt)) {
        events[e.id] = (id: e.id, title: e.title, flag: flagOf(e.deletedAt, e.archivedAt), parent: null, list: e.listId);
      }
    }
    for (final d in await (db.select(db.documents)..where((d) => d.workspaceId.equals(ws))).get()) {
      if (shown(d.deletedAt, d.archivedAt, d.purgedAt)) {
        docs[d.id] = (id: d.id, title: d.title, flag: flagOf(d.deletedAt, d.archivedAt), parent: d.parentId, list: null);
      }
    }

    bool same(DateTime a, DateTime b) => a.isAtSameMomentAs(b);
    final contents = <String, int>{}; // by the id of the item they went with
    void within(String root) => contents[root] = (contents[root] ?? 0) + 1;

    /// The top of a chain of parents that went at the same moment.
    _Rec top(Map<String, _Rec> of, _Rec r) {
      var cur = r;
      for (var p = cur.parent; p != null && of[p] != null && same(of[p]!.flag, r.flag); p = cur.parent) {
        cur = of[p]!;
      }
      return cur;
    }

    final out = <ShelfEntry>[];
    ShelfEntry entry(ShelfKind kind, _Rec r, {String? place}) =>
        ShelfEntry(kind: kind, id: r.id, title: r.title, at: r.flag, contents: contents[r.id] ?? 0, place: place);

    // What went with its list, its parent task or its parent document is not
    // listed; it counts for the one it went with.
    final taskTops = <String, _Rec>{};
    for (final r in tasks.values) {
      final t = top(tasks, r);
      final list = t.list == null ? null : lists[t.list];
      if (list != null && same(list.flag, r.flag)) {
        within(list.id);
      } else if (t.id != r.id) {
        within(t.id);
      } else {
        taskTops[r.id] = r;
      }
    }
    for (final r in events.values) {
      final list = r.list == null ? null : lists[r.list];
      if (list != null && same(list.flag, r.flag)) within(list.id);
    }
    final docTops = <String, _Rec>{};
    for (final r in docs.values) {
      final t = top(docs, r);
      if (t.id != r.id) {
        within(t.id);
      } else {
        docTops[r.id] = r;
      }
    }

    out.addAll([for (final r in lists.values) entry(ShelfKind.list, r)]);
    out.addAll([for (final r in taskTops.values) entry(ShelfKind.task, r, place: r.list == null ? null : listTitles[r.list])]);
    for (final r in events.values) {
      final list = r.list == null ? null : lists[r.list];
      if (list != null && same(list.flag, r.flag)) continue;
      out.add(entry(ShelfKind.event, r, place: r.list == null ? null : listTitles[r.list]));
    }
    out.addAll([for (final r in docTops.values) entry(ShelfKind.document, r)]);
    out.sort((a, b) => b.at != a.at ? b.at.compareTo(a.at) : a.id.compareTo(b.id));
    return out;
  }
}
