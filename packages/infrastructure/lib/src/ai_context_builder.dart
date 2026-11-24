// P06 T2 (ADR-0081; ai-architecture.md §3): the context of an AI request,
// read from the store. It reads only; it never writes.
//   scope       only what the request names (records, a document, a PDF's
//               text) and, when words are given, a few search hits; never
//               the whole store
//   permission  the shown space only, live records only: a record of
//               another space, in the trash, or gone is left out. A PDF's
//               text only through a live document of the shown space that
//               names the file
//   class       each record's own class (dataClassOf: an unknown kind and a
//               health measurement are Restricted); a PDF's text is
//               Confidential like the document that names it
//   bounds      at most [maxItems] items, [maxItemChars] per item and
//               [maxTotalChars] in all (cut with "…"; `truncated` says so)
import 'package:application/application.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'profile_store.dart';
import 'record_kinds.dart';
import 'search_index.dart';

class DriftAiContextBuilder implements AiContextBuilder {
  DriftAiContextBuilder(
    this.db, {
    this.maxItems = 30,
    this.maxItemChars = 4000,
    this.maxTotalChars = 24000,
    this.maxSearchHits = 8,
  }) : _store = ProfileStore(db);

  final AppDatabase db;
  final int maxItems;
  final int maxItemChars;
  final int maxTotalChars;
  final int maxSearchHits;
  final ProfileStore _store;

  @override
  Future<AiContext> build(AiContextRequest request) async {
    final ws = (await _store.getActiveProfile())?.activeWorkspaceId.value;
    if (ws == null) return const AiContext([]);
    await catchUpSearch(db);
    final items = <AiContextItem>[];
    final seen = <RecordRef>{};
    var truncated = false;
    var total = 0;

    void add(AiContextItem item) {
      if (!seen.add(item.ref)) return;
      if (items.length >= maxItems) {
        truncated = true;
        return;
      }
      var text = item.text;
      var title = item.title;
      if (title.length > 200) title = '${title.substring(0, 200)}…';
      final room = maxTotalChars - total - title.length;
      if (room < 0) {
        truncated = true; // not even its title fits any more
        return;
      }
      final limit = room < maxItemChars ? room : maxItemChars;
      if (text.length > limit) {
        text = '${text.substring(0, limit)}…';
        truncated = true;
      }
      total += title.length + text.length;
      items.add(AiContextItem(
          ref: item.ref, classification: item.classification, title: title, text: text, version: item.version));
    }

    for (final ref in request.named) {
      if (ref.kind == 'file') {
        final hash = ref.id.split('#').first;
        final page = ref.id.contains('#') ? int.tryParse(ref.id.split('#').last) : null;
        final f = await _fileOf(ws, hash);
        if (f == null) continue;
        add(AiContextItem(
            ref: ref,
            classification: DataClassification.confidential,
            title: page == null ? f : '$f, page $page',
            text: await _pdfText(hash, page: page)));
        continue;
      }
      final kind = recordKindByName[ref.kind];
      if (kind == null) continue;
      final row = await kind.readOne(db, ref.id);
      if (row == null || row['workspaceId'] != ws || row['deletedAt'] != null) continue;
      add(AiContextItem(
        ref: ref,
        classification: dataClassOf(ref.kind, row),
        title: '${row['title'] ?? ref.kind}',
        text: await _textOf(ref.kind, row),
        version: row['version'] as int?,
      ));
      // A document brings the text of its PDFs on this device.
      if (ref.kind == 'document') {
        for (final r in await (db.select(db.documentFileIndex)..where((x) => x.documentId.equals(ref.id))).get()) {
          final text = await _pdfText(r.hash);
          if (text.isEmpty) continue;
          add(AiContextItem(
              ref: RecordRef('file', r.hash), classification: DataClassification.confidential, title: r.name, text: text));
        }
      }
    }

    final words = request.query?.trim() ?? '';
    if (words.isNotEmpty) {
      for (final (id, marked) in await searchDocumentPassagesIn(db, ws, words, limit: maxSearchHits)) {
        final d = await (db.select(db.documents)..where((x) => x.id.equals(id))).getSingleOrNull();
        if (d == null) continue;
        add(AiContextItem(
            ref: RecordRef('document', id),
            classification: DataClassification.confidential,
            title: d.title,
            text: passageOf(marked).$1,
            version: d.version));
      }
      for (final id in (await searchTaskIdsIn(db, ws, words)).take(maxSearchHits)) {
        final row = await recordKindByName['task']!.readOne(db, id);
        if (row == null) continue;
        add(AiContextItem(
            ref: RecordRef('task', id),
            classification: dataClassOf('task', row),
            title: '${row['title']}',
            text: await _textOf('task', row),
            version: row['version'] as int?));
      }
      for (final p in await searchPdfPagesIn(db, ws, words, limit: maxSearchHits)) {
        add(AiContextItem(
            ref: RecordRef('file', '${p.file.hash}#${p.page}'),
            classification: DataClassification.confidential,
            title: '${p.file.name}, page ${p.page}',
            text: await _pdfText(p.file.hash, page: p.page)));
      }
    }
    return AiContext(List.unmodifiable(items), truncated: truncated);
  }

  /// The name a live document of [ws] gives the file of [hash], or null.
  Future<String?> _fileOf(String ws, String hash) async {
    final r = await db.customSelect(
      'SELECT i.name AS name FROM document_file_index i JOIN documents d ON d.id = i.document_id '
      'WHERE i.hash = ? AND d.workspace_id = ? AND d.deleted_at IS NULL ORDER BY d.title LIMIT 1',
      variables: [Variable<String>(hash), Variable<String>(ws)],
      readsFrom: {db.documents, db.documentFileIndex},
    ).getSingleOrNull();
    return r?.read<String>('name');
  }

  /// The indexed text of a PDF: one page, or all its pages in order.
  Future<String> _pdfText(String hash, {int? page}) async {
    final rows = await db.customSelect(
      'SELECT page, text FROM pdf_text_fts WHERE hash = ?${page == null ? '' : ' AND page = ?'} ORDER BY page',
      variables: [Variable<String>(hash), if (page != null) Variable<int>(page)],
    ).get();
    return [for (final r in rows) if (page == null) '[page ${r.read<int>('page')}]\n${r.read<String>('text')}' else r.read<String>('text')]
        .join('\n');
  }

  Future<String> _textOf(String kind, Row row) async {
    switch (kind) {
      case 'task':
        final notes = '${row['notes'] ?? ''}'.trim();
        return [if (row['status'] != null) 'status: ${row['status']}', if (notes.isNotEmpty) notes].join('\n');
      case 'event':
        return [if ('${row['location'] ?? ''}'.isNotEmpty) 'location: ${row['location']}'].join('\n');
      case 'document':
        try {
          return DocumentBody.decode('${row['body']}').plainText();
        } on FormatException {
          return '';
        }
      case 'measurement':
        return 'value ${row['value']} on ${row['localDate']}${'${row['note'] ?? ''}'.isEmpty ? '' : ': ${row['note']}'}';
      default:
        return '';
    }
  }
}
