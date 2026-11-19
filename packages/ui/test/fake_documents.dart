// P05a T8: in-memory documents, search and attachments for the UI tests.
// Calls are recorded (`doc.create:<title>`, `doc.save:<id>:<text>`, …); the
// rules are the few the screens rely on (a revision per save, nothing saved
// when nothing changed, the trash takes subdocuments).
import 'dart:async';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';

class FakeDoc {
  FakeDoc(this.id, this.title, this.body, {this.parentId, required this.order});
  final String id;
  String title;
  DocumentBody body;
  String? parentId;
  int order;
  int version = 1;
  bool trashed = false;
  bool unreadable = false;
  String? changedBy;
  final revisions = <DocumentRevisionView>[];
}

class FakeDocuments implements DocumentService, DocumentQueries, SearchQueries, AttachmentService {
  FakeDocuments(this.calls, {required this.tasks});
  final List<String> calls;

  /// The tasks searched by title (the world's).
  final List<TaskView> Function() tasks;
  final docs = <String, FakeDoc>{};
  final links = <(String doc, DocumentItemType type, String item)>[];
  final itemTitles = <String, String>{};
  final files = <String, Uint8List>{};
  CommandFailure? failNext;
  final _changes = StreamController<void>.broadcast();
  var _n = 0;
  var _clock = 0;

  void dispose() => _changes.close();

  CommandFailure? _failure() {
    final f = failNext;
    failNext = null;
    return f;
  }

  static DocumentBody text(String s) => DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun(s)])]);

  /// Test setup: a document (and its first revision).
  String put(String title, {String? parentId, DocumentBody? body, String? id}) {
    final d = FakeDoc(id ?? 'd${_n++}', title, body ?? DocumentBody([DocBlock('b1', BlockType.paragraph)]),
        parentId: parentId, order: _clock++);
    docs[d.id] = d;
    _revision(d, RevisionReason.save);
    _changes.add(null);
    return d.id;
  }

  void _revision(FakeDoc d, RevisionReason reason) => d.revisions.insert(
      0,
      DocumentRevisionView(
          id: '${d.id}-r${d.version}',
          documentVersion: d.version,
          title: d.title,
          reason: reason,
          savedAt: Instant(DateTime.utc(2026, 11, 4, 9, d.version)),
          author: d.changedBy,
          deviceId: 'windows'));

  final _revisionBodies = <String, DocumentBody>{};

  // --- DocumentService ---------------------------------------------------------

  @override
  Future<CommandResult> create(String title, {String? parentId, String? afterId}) async {
    calls.add('doc.create:$title:$parentId');
    final f = _failure();
    if (f != null) return f;
    final id = put(title, parentId: parentId);
    _revisionBodies['$id-r1'] = docs[id]!.body;
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> save(String id, {required String title, required DocumentBody body}) async {
    final d = docs[id]!;
    if (title.trim() == d.title && body.encode() == d.body.encode()) return CommandOk(id, Version(d.version), const []);
    calls.add('doc.save:$id:${title.trim()}:${body.plainText()}');
    final f = _failure();
    if (f != null) return f;
    d
      ..title = title.trim()
      ..body = body
      ..version += 1;
    _revision(d, RevisionReason.save);
    _revisionBodies[d.revisions.first.id] = body;
    _changes.add(null);
    return CommandOk(id, Version(d.version), const []);
  }

  @override
  Future<CommandResult> rename(String id, String title) => save(id, title: title, body: docs[id]!.body);

  @override
  Future<CommandResult> move(String id, {String? parentId, String? afterId}) async {
    calls.add('doc.move:$id:$parentId');
    docs[id]!.parentId = parentId;
    _changes.add(null);
    return CommandOk(id, Version(docs[id]!.version), const []);
  }

  Iterable<FakeDoc> _subtree(String id) sync* {
    yield docs[id]!;
    for (final c in docs.values.where((d) => d.parentId == id)) {
      yield* _subtree(c.id);
    }
  }

  @override
  Future<CommandResult> trash(String id) async {
    calls.add('doc.trash:$id');
    final f = _failure();
    if (f != null) return f;
    for (final d in _subtree(id)) {
      d.trashed = true;
    }
    _changes.add(null);
    return CommandOk(id, Version(docs[id]!.version), const []);
  }

  @override
  Future<CommandResult> restore(String id) async {
    calls.add('doc.restore:$id');
    for (final d in _subtree(id)) {
      d.trashed = false;
    }
    _changes.add(null);
    return CommandOk(id, Version(docs[id]!.version), const []);
  }

  @override
  Future<CommandResult> restoreRevision(String id, String revisionId) async {
    calls.add('doc.restoreRevision:$id:$revisionId');
    final d = docs[id]!;
    d
      ..body = _revisionBodies[revisionId] ?? d.body
      ..version += 1;
    _revision(d, RevisionReason.restore);
    _changes.add(null);
    return CommandOk(id, Version(d.version), const []);
  }

  @override
  Future<CommandResult> link(String id, DocumentItemType type, String itemId) async {
    calls.add('doc.link:$id:${type.name}:$itemId');
    links.add((id, type, itemId));
    return CommandOk(id, Version(docs[id]!.version), const []);
  }

  @override
  Future<CommandResult> unlink(String id, DocumentItemType type, String itemId) async {
    calls.add('doc.unlink:$id:${type.name}:$itemId');
    links.remove((id, type, itemId));
    return CommandOk(id, Version(docs[id]!.version), const []);
  }

  // --- DocumentQueries ---------------------------------------------------------

  DocumentNodeView _node(FakeDoc d) => DocumentNodeView(id: d.id, title: d.title, parentId: d.parentId, orderKey: '${d.order}');

  List<DocumentNodeView> _tree() {
    final live = [for (final d in docs.values) if (!d.trashed) d]..sort((a, b) => a.order.compareTo(b.order));
    final out = <DocumentNodeView>[];
    void walk(String? parent) {
      for (final d in live.where((d) => d.parentId == parent)) {
        out.add(_node(d));
        walk(d.id);
      }
    }

    walk(null);
    return out;
  }

  @override
  Stream<List<DocumentNodeView>> watchTree() async* {
    yield _tree();
    await for (final _ in _changes.stream) {
      yield _tree();
    }
  }

  @override
  Future<DocumentView?> document(String id) async {
    final d = docs[id];
    if (d == null) return null;
    return DocumentView(
      id: d.id,
      title: d.title,
      body: d.unreadable ? DocumentBody([]) : d.body,
      version: d.version,
      updatedAt: Instant(DateTime.utc(2026, 11, 4, 9)),
      parentId: d.parentId,
      isTrashed: d.trashed,
      changedBy: d.changedBy,
      isUnreadable: d.unreadable,
    );
  }

  @override
  Future<List<DocumentRevisionView>> revisions(String id) async => [...docs[id]!.revisions];

  @override
  Future<(String, DocumentBody)?> revisionContent(String revisionId) async {
    final b = _revisionBodies[revisionId];
    if (b == null) return null;
    final d = docs.values.firstWhere((d) => d.revisions.any((r) => r.id == revisionId));
    return (d.revisions.firstWhere((r) => r.id == revisionId).title, b);
  }

  @override
  Future<List<DocumentItemLinkView>> linksOf(String id) async => [
        for (final (doc, type, item) in links)
          if (doc == id) DocumentItemLinkView(itemType: type, itemId: item, title: itemTitles[item], state: itemTitles[item] == null ? LinkedItemState.missing : LinkedItemState.open),
      ];

  @override
  Future<List<DocumentNodeView>> trashed() async => [
        for (final d in docs.values)
          if (d.trashed && (d.parentId == null || docs[d.parentId]?.trashed != true)) _node(d)
      ];

  @override
  Future<List<DocumentNodeView>> documentsOf(DocumentItemType type, String itemId) async => [
        for (final (doc, t, item) in links)
          if (t == type && item == itemId && docs[doc]?.trashed == false) _node(docs[doc]!)
      ];

  @override
  Future<Map<String, DocumentLinkTarget>> linkTargets(Iterable<String> ids) async => {
        for (final id in ids)
          id: switch (docs[id]) {
            null => DocumentLinkTarget(id: id, state: LinkState.missing),
            final d => DocumentLinkTarget(id: id, state: d.trashed ? LinkState.inTrash : LinkState.ok, title: d.title),
          }
      };

  @override
  Future<List<BacklinkView>> backlinks(String id) async => [
        for (final d in docs.values)
          if (!d.trashed && d.id != id && d.body.blocks.any((b) => b.runs.any((r) => r.doc == id)))
            BacklinkView(id: d.id, title: d.title, snippets: backlinkSnippets(d.body, id)),
      ];

  @override
  Future<List<DocumentNodeView>> linkCandidates(String typed, {String? excludeId}) async {
    final t = typed.trim().toLowerCase();
    return [
      for (final d in docs.values)
        if (!d.trashed && d.id != excludeId && d.title.toLowerCase().contains(t)) _node(d)
    ];
  }

  // --- SearchQueries ---------------------------------------------------------------

  @override
  Future<SearchResults> search(String typed, {int limit = 50}) async {
    calls.add('search:$typed');
    final t = typed.trim().toLowerCase();
    if (t.isEmpty) return SearchResults.empty;
    final hits = <DocumentHitView>[];
    for (final d in docs.values.where((d) => !d.trashed)) {
      final text = d.body.plainText();
      final at = text.toLowerCase().indexOf(t);
      if (d.title.toLowerCase().contains(t) || at >= 0) {
        hits.add(DocumentHitView(
            id: d.id, title: d.title, passage: text, matches: at < 0 ? const [] : [(start: at, end: at + t.length)]));
      }
    }
    return SearchResults(documents: hits, tasks: [
      for (final x in tasks())
        if (x.title.toLowerCase().contains(t)) TaskHitView(id: x.id, title: x.title, isDone: x.isDone)
    ]);
  }

  // --- AttachmentService ---------------------------------------------------------

  @override
  Future<AttachmentAdded> add(Uint8List bytes, {required String name, required String mime}) async {
    calls.add('file.add:$name');
    if (bytes.length > maxAttachmentBytes) return const AttachmentAdded.failed(AttachmentProblem.tooLarge);
    final hash = 'sha256:${(bytes.length + files.length).toRadixString(16).padLeft(64, '0')}';
    files[hash] = bytes;
    return AttachmentAdded.ok(AttachmentRef(hash: hash, name: name, size: bytes.length, mime: mime));
  }

  @override
  Future<AttachmentAvailability> availability(String hash) async =>
      files.containsKey(hash) ? AttachmentAvailability.here : AttachmentAvailability.elsewhere;

  @override
  Future<AttachmentContent> open(String hash) async => files.containsKey(hash)
      ? AttachmentContent(AttachmentAvailability.here, files[hash])
      : const AttachmentContent(AttachmentAvailability.elsewhere);

  @override
  Future<int> sweep({Duration grace = const Duration(days: 1)}) async => 0;
}
