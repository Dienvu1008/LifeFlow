// P05a T3 (ADR-0068): document commands and reads for the shown workspace
// (personal or a shared space, P04b), through the gateway.
import 'package:application/application.dart';
import 'package:domain/domain.dart' show relationsOf, resolveLink, withLinkTitles;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'document_command_handler.dart';
import 'profile_store.dart';
import 'search_index.dart';

class DriftDocumentService implements DocumentService {
  DriftDocumentService(this.db, this.gateway, {this.clock = const SystemClock(), this.deviceId})
      : _store = ProfileStore(db),
        _handler = DocumentCommandHandler(clock: clock);

  final AppDatabase db;
  final CommandGateway gateway;
  final Clock clock;

  /// Named in each revision (which device saved it).
  final String? deviceId;
  final ProfileStore _store;
  final DocumentCommandHandler _handler;
  final _uuid = const Uuid();

  Future<CommandResult> _run(String type, Map<String, Object?> payload, {Version? expected}) async {
    final ctx = await _store.commandContext();
    if (ctx == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ctx.actor,
        workspaceId: ctx.workspaceId,
        type: type,
        payload: payload,
        expectedVersion: expected,
        issuedAt: clock.now(),
      ),
      _handler,
    );
  }

  Future<DocumentRow?> _row(String id) => (db.select(db.documents)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<CommandResult> _update(String type, String id, Map<String, Object?> payload) async {
    final d = await _row(id);
    if (d == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'document not found');
    return _run(type, {...payload, 'id': id}, expected: Version(d.version));
  }

  @override
  Future<CommandResult> create(String title, {String? parentId, String? afterId}) => _run('CreateDocument', {
        'op': 'create',
        'id': _uuid.v7(),
        'revisionId': _uuid.v7(),
        'firstBlockId': _uuid.v4().substring(0, 8),
        'title': title,
        'parentId': parentId,
        if (afterId != null) 'afterId': afterId,
      });

  @override
  Future<CommandResult> save(String id, {required String title, required DocumentBody body}) async {
    final d = await _row(id);
    if (d == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'document not found');
    // P05a T6 (ADR-0071): each `[[…]]` link is stored with its target's
    // current title (live, in the same workspace), so search finds what is
    // shown; a broken link keeps its text (DOC-003).
    final stored = await _withCurrentTitles(body, d.workspaceId);
    // Saving what is stored writes nothing: leaving or idling (C7) on an
    // unchanged document is no revision.
    if (d.deletedAt == null && title.trim() == d.title && stored.encode() == d.body) {
      return CommandOk(id, Version(d.version), const []);
    }
    return _run('SaveDocument', {
      'op': 'save',
      'id': id,
      'revisionId': _uuid.v7(),
      'title': title,
      'body': stored.encode(),
      'deviceId': deviceId,
    }, expected: Version(d.version));
  }

  Future<DocumentBody> _withCurrentTitles(DocumentBody body, String workspaceId) async {
    final targets = relationsOf(parentId: null, body: body).docLinks;
    if (targets.isEmpty) return body;
    final live = {
      for (final t in await (db.select(db.documents)
            ..where((x) => x.id.isIn(targets) & x.workspaceId.equals(workspaceId) & x.deletedAt.isNull()))
          .get())
        t.id: t.title
    };
    return withLinkTitles(body, (id) => live[id]);
  }

  @override
  Future<CommandResult> rename(String id, String title) async {
    final d = await _row(id);
    if (d == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'document not found');
    final DocumentBody body;
    try {
      body = DocumentBody.decode(d.body);
    } on FormatException {
      return const CommandFailure(CommandFailureKind.validationFailed, reason: 'the document cannot be read here');
    }
    return save(id, title: title, body: body);
  }

  @override
  Future<CommandResult> move(String id, {String? parentId, String? afterId}) =>
      _update('MoveDocument', id, {'op': 'move', 'parentId': parentId, 'afterId': afterId});

  @override
  Future<CommandResult> trash(String id) => _update('TrashDocument', id, {'op': 'trash'});

  @override
  Future<CommandResult> restore(String id) => _update('RestoreDocument', id, {'op': 'restore'});

  @override
  Future<CommandResult> restoreRevision(String id, String revisionId) => _update('RestoreDocumentRevision', id,
      {'op': 'restoreRevision', 'revisionId': _uuid.v7(), 'fromRevisionId': revisionId, 'deviceId': deviceId});

  @override
  Future<CommandResult> link(String id, DocumentItemType type, String itemId) =>
      _update('LinkDocument', id, {'op': 'link', 'itemType': type.name, 'itemId': itemId});

  @override
  Future<CommandResult> unlink(String id, DocumentItemType type, String itemId) =>
      _update('UnlinkDocument', id, {'op': 'unlink', 'itemType': type.name, 'itemId': itemId});
}

class DriftDocumentQueries implements DocumentQueries {
  DriftDocumentQueries(this.db) : _store = ProfileStore(db);
  final AppDatabase db;
  final ProfileStore _store;

  Future<String?> _workspace() async => (await _store.getActiveProfile())?.activeWorkspaceId.value;

  DocumentNodeView _node(DocumentRow d) =>
      DocumentNodeView(id: d.id, title: d.title, parentId: d.parentId, orderKey: d.orderKey);

  /// Parents before their children; siblings by order key, then id.
  List<DocumentNodeView> _treeOrder(List<DocumentRow> rows) {
    final ids = {for (final d in rows) d.id};
    final byParent = <String?, List<DocumentRow>>{};
    for (final d in rows) {
      // A parent that is not live here: shown at the top.
      byParent.putIfAbsent(ids.contains(d.parentId) ? d.parentId : null, () => []).add(d);
    }
    for (final l in byParent.values) {
      l.sort((a, b) => a.orderKey == b.orderKey ? a.id.compareTo(b.id) : a.orderKey.compareTo(b.orderKey));
    }
    final out = <DocumentNodeView>[];
    void walk(String? parent) {
      for (final d in byParent[parent] ?? const <DocumentRow>[]) {
        out.add(_node(d));
        walk(d.id);
      }
    }

    void walkFrom(String parent, Set<String> seen) {
      for (final d in byParent[parent] ?? const <DocumentRow>[]) {
        if (!seen.add(d.id)) continue;
        out.add(_node(d));
        walkFrom(d.id, seen);
      }
    }

    walk(null);
    // P05a T4 (ADR-0069): two moves on two devices can merge into a loop (A
    // under B here, B under A there). Nothing in it is reachable from the
    // top, so each loop is shown from its smallest id, the same on every
    // device; nothing disappears from the tree.
    final shown = {for (final n in out) n.id};
    final rest = [for (final d in rows) if (!shown.contains(d.id)) d]..sort((a, b) => a.id.compareTo(b.id));
    for (final d in rest) {
      if (shown.contains(d.id)) continue;
      final start = out.length;
      out.add(_node(d));
      walkFrom(d.id, shown..add(d.id));
      for (final n in out.skip(start)) {
        shown.add(n.id);
      }
    }
    return out;
  }

  Future<List<DocumentNodeView>> _tree() async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final rows = await (db.select(db.documents)..where((d) => d.workspaceId.equals(ws) & d.deletedAt.isNull() & d.archivedAt.isNull())).get();
    return _treeOrder(rows);
  }

  @override
  Stream<List<DocumentNodeView>> watchTree() async* {
    yield await _tree();
    yield* db.tableUpdates(TableUpdateQuery.onAllTables([db.documents])).asyncMap((_) => _tree());
  }

  @override
  Future<DocumentView?> document(String id) async {
    final ws = await _workspace();
    final d = await (db.select(db.documents)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (d == null || d.workspaceId != ws) return null;
    DocumentBody? body;
    try {
      body = DocumentBody.decode(d.body);
    } on FormatException {
      body = null;
    }
    return DocumentView(
      id: d.id,
      title: d.title,
      body: body ?? DocumentBody([]),
      isUnreadable: body == null,
      version: d.version,
      updatedAt: Instant(d.updatedAt.toUtc()),
      parentId: d.parentId,
      isTrashed: d.deletedAt != null,
      changedBy: d.changedBy,
    );
  }

  @override
  Future<List<DocumentRevisionView>> revisions(String id) async {
    final ws = await _workspace();
    final rows = await (db.select(db.documentRevisions)
          ..where((r) => r.documentId.equals(id) & r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.documentVersion), (r) => OrderingTerm.desc(r.createdAt)]))
        .get();
    return [
      for (final r in rows)
        if (r.workspaceId == ws)
          DocumentRevisionView(
            id: r.id,
            documentVersion: r.documentVersion,
            title: r.title,
            reason: RevisionReason.values.where((x) => x.name == r.reason).firstOrNull ?? RevisionReason.save,
            savedAt: Instant(r.createdAt.toUtc()),
            author: r.changedBy,
            deviceId: r.deviceId,
          ),
    ];
  }

  @override
  Future<(String, DocumentBody)?> revisionContent(String revisionId) async {
    final ws = await _workspace();
    final r = await (db.select(db.documentRevisions)..where((x) => x.id.equals(revisionId))).getSingleOrNull();
    if (r == null || r.workspaceId != ws) return null;
    try {
      return (r.title, DocumentBody.decode(r.body));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<List<DocumentItemLinkView>> linksOf(String id) async {
    // P05a T5 (ADR-0070): a link shows where its document is: one left
    // behind by a move into or out of a space does not.
    final ws = await _workspace();
    final rows = await (db.select(db.documentLinks)
          ..where((l) => l.documentId.equals(id) & l.deletedAt.isNull() & l.workspaceId.equals(ws ?? ''))
          ..orderBy([(l) => OrderingTerm(expression: l.createdAt), (l) => OrderingTerm(expression: l.id)]))
        .get();
    return [for (final l in rows) await _item(DocumentItemType.values.byName(l.itemType), l.itemId)];
  }

  /// P05a T6: a linked item read from its own table (as goal links are).
  Future<DocumentItemLinkView> _item(DocumentItemType type, String id) async {
    DocumentItemLinkView view(String? title, LinkedItemState state) =>
        DocumentItemLinkView(itemType: type, itemId: id, title: title, state: title == null ? LinkedItemState.missing : state);
    switch (type) {
      case DocumentItemType.task:
        final t = await (db.select(db.tasks)..where((x) => x.id.equals(id))).getSingleOrNull();
        return view(
            t?.title,
            t?.deletedAt != null
                ? LinkedItemState.trashed
                : switch (t?.status) { 'done' => LinkedItemState.done, 'cancelled' => LinkedItemState.cancelled, _ => LinkedItemState.open });
      case DocumentItemType.event:
        final e = await (db.select(db.events)..where((x) => x.id.equals(id))).getSingleOrNull();
        return view(
            e?.title,
            e?.deletedAt != null
                ? LinkedItemState.trashed
                : e?.status == 'cancelled'
                    ? LinkedItemState.cancelled
                    : LinkedItemState.open);
      case DocumentItemType.goal:
        final g = await (db.select(db.goals)..where((x) => x.id.equals(id))).getSingleOrNull();
        return view(g?.title, g?.deletedAt != null ? LinkedItemState.trashed : g?.status == 'done' ? LinkedItemState.done : LinkedItemState.open);
    }
  }

  @override
  Future<List<DocumentNodeView>> documentsOf(DocumentItemType type, String itemId) async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final links = await (db.select(db.documentLinks)
          ..where((l) => l.itemType.equals(type.name) & l.itemId.equals(itemId) & l.deletedAt.isNull() & l.workspaceId.equals(ws)))
        .get();
    final docs = await (db.select(db.documents)
          ..where((d) => d.id.isIn([for (final l in links) l.documentId]) & d.workspaceId.equals(ws) & d.deletedAt.isNull()))
        .get();
    return [for (final d in docs..sort(_byTitle)) _node(d)];
  }

  static int _byTitle(DocumentRow a, DocumentRow b) {
    final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return t != 0 ? t : a.id.compareTo(b.id);
  }

  @override
  Future<Map<String, DocumentLinkTarget>> linkTargets(Iterable<String> ids) async {
    final ws = await _workspace();
    final wanted = ids.toSet();
    final rows = ws == null || wanted.isEmpty
        ? const <DocumentRow>[]
        : await (db.select(db.documents)..where((d) => d.id.isIn(wanted) & d.workspaceId.equals(ws))).get();
    final here = {for (final d in rows) d.id: d};
    return {
      for (final id in wanted)
        id: switch (resolveLink(id, (x) => here[x] == null ? null : here[x]!.deletedAt != null)) {
          LinkState.missing => DocumentLinkTarget(id: id, state: LinkState.missing),
          final s => DocumentLinkTarget(id: id, state: s, title: here[id]!.title),
        },
    };
  }

  @override
  Future<List<BacklinkView>> backlinks(String id) async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final out = <BacklinkView>[];
    for (final from in await backlinkIdsIn(db, ws, id)) {
      final d = (await _row(from))!;
      DocumentBody body;
      try {
        body = DocumentBody.decode(d.body);
      } on FormatException {
        continue; // the index holds no link of a body it cannot read
      }
      out.add(BacklinkView(id: d.id, title: d.title, snippets: backlinkSnippets(body, id)));
    }
    // By title, letter case aside (as an item's documents).
    int key(BacklinkView a, BacklinkView b) {
      final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return t != 0 ? t : a.id.compareTo(b.id);
    }

    return out..sort(key);
  }

  Future<DocumentRow?> _row(String id) => (db.select(db.documents)..where((d) => d.id.equals(id))).getSingleOrNull();

  @override
  Future<List<DocumentNodeView>> linkCandidates(String typed, {String? excludeId}) async {
    final ws = await _workspace();
    if (ws == null) return const [];
    const most = 20;
    if (typed.trim().isEmpty) {
      final rows = await (db.select(db.documents)
            ..where((d) => d.workspaceId.equals(ws) & d.deletedAt.isNull() & d.archivedAt.isNull() & d.id.equals(excludeId ?? '').not())
            ..orderBy([(d) => OrderingTerm.desc(d.updatedAt), (d) => OrderingTerm(expression: d.id)])
            ..limit(most))
          .get();
      return [for (final d in rows) _node(d)];
    }
    final ids = [
      for (final x in await searchDocumentTitleIdsIn(db, ws, typed, limit: most + 1))
        if (x != excludeId) x
    ];
    final rows = {for (final d in await (db.select(db.documents)..where((d) => d.id.isIn(ids))).get()) d.id: d};
    return [for (final x in ids.take(most)) _node(rows[x]!)];
  }

  @override
  Future<List<DocumentNodeView>> trashed() async {
    final ws = await _workspace();
    if (ws == null) return const [];
    final rows = await (db.select(db.documents)..where((d) => d.workspaceId.equals(ws) & d.deletedAt.isNotNull() & d.purgedAt.isNull())).get();
    // Only what was trashed on its own: a subdocument that went with its
    // parent comes back with it.
    final byId = {for (final d in rows) d.id: d};
    final tops = [
      for (final d in rows)
        if (d.parentId == null || byId[d.parentId]?.deletedAt != d.deletedAt) d
    ];
    return [for (final d in tops..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!))) _node(d)];
  }
}
