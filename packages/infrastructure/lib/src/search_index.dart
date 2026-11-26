// P05a T2 (schema v16, ADR-0067; p05-plan C4, C6, C12): search by the exact
// spelling, and the `[[…]]` links behind backlinks.
//
// Text is indexed in Unicode NFC, and queries are normalized the same way:
// the same Vietnamese word can be stored precomposed (NFC), decomposed (NFD)
// or half-decomposed (a vowel letter with its tone mark apart, as some
// keyboards type it), and FTS5 compares code points. NFC is computed in Dart
// (`unorm_dart`, VS-45), so the index is kept here, not by SQL alone:
//   - SQL triggers on tasks and documents only note which rows changed
//     (`search_pending`), whatever wrote them: a command, a pulled page, a
//     restore, a move into a space;
//   - before every search or backlink query, `catchUpSearch` re-indexes the
//     noted rows (title and body text in NFC; a document's links parsed from
//     its body with the domain's own reader) in one transaction.
// Records are never rewritten for the index.
import 'package:application/application.dart' show FileView, fileViewOf;
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'app_database.dart';

/// FTS5 with marks kept and case ignored (C4).
const _tokenize = "tokenize='unicode61 remove_diacritics 0'";

/// The search tables and the triggers that note changes (schema v16).
Future<void> createSearchIndex(AppDatabase db) async {
  await db.customStatement('CREATE VIRTUAL TABLE tasks_fts USING fts5(title, $_tokenize)');
  await db.customStatement('CREATE VIRTUAL TABLE documents_fts USING fts5(title, body, $_tokenize)');
  // "INSERT OR IGNORE" would not do: an outer statement's conflict clause
  // (Drift's upserts) overrides a trigger's, so a second note of the same row
  // failed. The triggers check first instead.
  String note(String kind, String row) => "INSERT INTO search_pending(kind, row_ref, record_id) SELECT '$kind', $row.rowid, $row.id "
      "WHERE NOT EXISTS (SELECT 1 FROM search_pending WHERE kind = '$kind' AND row_ref = $row.rowid AND record_id = $row.id);";
  for (final (table, kind, cols) in const [('tasks', 'task', 'title'), ('documents', 'document', 'title, body')]) {
    await db.customStatement('CREATE TRIGGER ${table}_search_ai AFTER INSERT ON $table BEGIN ${note(kind, 'new')} END');
    await db.customStatement(
        'CREATE TRIGGER ${table}_search_au AFTER UPDATE OF $cols ON $table BEGIN ${note(kind, 'old')} ${note(kind, 'new')} END');
    await db.customStatement('CREATE TRIGGER ${table}_search_ad AFTER DELETE ON $table BEGIN ${note(kind, 'old')} END');
  }
}

/// P05b T2 (schema v17, ADR-0077): the text of this device's PDFs, one row
/// per page, by the file's hash; and the files by hash.
Future<void> createPdfTextIndex(AppDatabase db) async {
  await db.customStatement('CREATE VIRTUAL TABLE pdf_text_fts USING fts5(text, hash UNINDEXED, page UNINDEXED, $_tokenize)');
  await db.customStatement('CREATE INDEX document_file_index_hash ON document_file_index (hash)');
}

/// Notes every task and document, so the next catch-up indexes them all
/// (the v16 upgrade).
Future<void> markAllForSearch(AppDatabase db) async {
  await db.customStatement("DELETE FROM search_pending");
  await db.customStatement("INSERT INTO search_pending(kind, row_ref, record_id) SELECT 'task', rowid, id FROM tasks");
  await db.customStatement("INSERT INTO search_pending(kind, row_ref, record_id) SELECT 'document', rowid, id FROM documents");
}

/// The text as it is indexed and queried.
String searchForm(String text) => unorm.nfc(text);

/// Re-indexes the rows changed since the last catch-up. Two passes, so a
/// rowid freed by a delete and given to a new row is indexed for the new one.
Future<void> catchUpSearch(AppDatabase db) async {
  final pending = await db.select(db.searchPending).get();
  if (pending.isEmpty) return;
  await db.transaction(() async {
    for (final p in pending) {
      if (p.kind == 'task') {
        await db.customStatement('DELETE FROM tasks_fts WHERE rowid = ?', [p.rowRef]);
      } else {
        await db.customStatement('DELETE FROM documents_fts WHERE rowid = ?', [p.rowRef]);
        await (db.delete(db.documentLinkIndex)..where((x) => x.fromDocumentId.equals(p.recordId))).go();
        await (db.delete(db.documentFileIndex)..where((x) => x.documentId.equals(p.recordId))).go();
      }
    }
    for (final p in pending) {
      if (p.kind == 'task') {
        final r = await db
            .customSelect('SELECT title FROM tasks WHERE rowid = ? AND id = ?',
                variables: [Variable<int>(p.rowRef), Variable<String>(p.recordId)])
            .getSingleOrNull();
        if (r == null) continue;
        await db.customStatement('INSERT OR REPLACE INTO tasks_fts(rowid, title) VALUES (?, ?)',
            [p.rowRef, searchForm(r.read<String>('title'))]);
      } else {
        final r = await db
            .customSelect('SELECT title, body FROM documents WHERE rowid = ? AND id = ?',
                variables: [Variable<int>(p.rowRef), Variable<String>(p.recordId)])
            .getSingleOrNull();
        if (r == null) continue;
        DocumentBody? body;
        try {
          body = DocumentBody.decode(r.read<String>('body'));
        } on FormatException {
          body = null; // the title is still found; the body waits for an app that reads it
        }
        await db.customStatement('INSERT OR REPLACE INTO documents_fts(rowid, title, body) VALUES (?, ?, ?)',
            [p.rowRef, searchForm(r.read<String>('title')), searchForm(body?.plainText() ?? '')]);
        if (body == null) continue;
        for (final to in relationsOf(parentId: null, body: body).docLinks) {
          await db.into(db.documentLinkIndex).insertOnConflictUpdate(
              DocumentLinkIndexCompanion.insert(fromDocumentId: p.recordId, toDocumentId: to));
        }
        // P05b T2: its PDFs (the first name given to a file in the body).
        final seen = <String>{};
        for (final b in body.blocks) {
          final f = b.attachment;
          if (f == null || fileViewOf(f) != FileView.pdf || !seen.add(f.hash)) continue;
          await db.into(db.documentFileIndex).insertOnConflictUpdate(DocumentFileIndexCompanion.insert(
              documentId: p.recordId, hash: f.hash, name: f.name, size: f.size, mime: f.mime));
        }
      }
    }
    for (final p in pending) {
      await db.customStatement('DELETE FROM search_pending WHERE kind = ? AND row_ref = ? AND record_id = ?',
          [p.kind, p.rowRef, p.recordId]);
    }
  });
}

/// The live tasks of [workspaceId] whose title matches what was typed (C12),
/// best first.
Future<List<String>> searchTaskIdsIn(AppDatabase db, String workspaceId, String typed, {bool anyWord = false}) async {
  // P06b W4: the chat searches a whole question by any of its words.
  final q = anyWord ? searchAnyQueryOf(searchForm(typed)) : searchQueryOf(searchForm(typed));
  if (q == null) return const [];
  await catchUpSearch(db);
  final rows = await db.customSelect(
    'SELECT t.id AS id FROM tasks_fts f JOIN tasks t ON t.rowid = f.rowid '
    'WHERE tasks_fts MATCH ? AND t.workspace_id = ? AND t.deleted_at IS NULL ORDER BY rank',
    variables: [Variable<String>(q), Variable<String>(workspaceId)],
    readsFrom: {db.tasks},
  ).get();
  return [for (final r in rows) r.read<String>('id')];
}

/// The live documents of [workspaceId] whose title or text matches (C4).
Future<List<String>> searchDocumentIdsIn(AppDatabase db, String workspaceId, String typed) async {
  final q = searchQueryOf(searchForm(typed));
  if (q == null) return const [];
  await catchUpSearch(db);
  final rows = await db.customSelect(
    'SELECT d.id AS id FROM documents_fts f JOIN documents d ON d.rowid = f.rowid '
    'WHERE documents_fts MATCH ? AND d.workspace_id = ? AND d.deleted_at IS NULL ORDER BY rank',
    variables: [Variable<String>(q), Variable<String>(workspaceId)],
    readsFrom: {db.documents},
  ).get();
  return [for (final r in rows) r.read<String>('id')];
}

/// P05a T6: marks FTS5 puts around each matched word of a passage (Unicode
/// private use, never typed); taken out again by [passageOf].
const _matchStart = '\uE000', _matchEnd = '\uE001';

/// A passage as FTS5's `snippet` gave it: the text without the marks, and
/// where the marks were.
(String, List<({int start, int end})>) passageOf(String marked) {
  final out = StringBuffer();
  final matches = <({int start, int end})>[];
  int? from;
  for (final ch in marked.split('')) {
    if (ch == _matchStart) {
      from = out.length;
    } else if (ch == _matchEnd) {
      if (from != null && out.length > from) matches.add((start: from, end: out.length));
      from = null;
    } else {
      out.write(ch);
    }
  }
  return (out.toString(), matches);
}

/// P05a T6 (ADR-0071): the live documents of [workspaceId] matching what was
/// typed, best first, each with a passage of its text around the matches
/// (marked as [passageOf] reads them).
Future<List<(String, String)>> searchDocumentPassagesIn(AppDatabase db, String workspaceId, String typed,
    {int limit = 50, bool anyWord = false}) async {
  // P06b W4: the chat searches a whole question by any of its words.
  final q = anyWord ? searchAnyQueryOf(searchForm(typed)) : searchQueryOf(searchForm(typed));
  if (q == null) return const [];
  await catchUpSearch(db);
  final rows = await db.customSelect(
    "SELECT d.id AS id, snippet(documents_fts, 1, ?, ?, '…', 24) AS passage "
    'FROM documents_fts f JOIN documents d ON d.rowid = f.rowid '
    'WHERE documents_fts MATCH ? AND d.workspace_id = ? AND d.deleted_at IS NULL ORDER BY rank LIMIT ?',
    variables: [
      Variable<String>(_matchStart),
      Variable<String>(_matchEnd),
      Variable<String>(q),
      Variable<String>(workspaceId),
      Variable<int>(limit),
    ],
    readsFrom: {db.documents},
  ).get();
  return [for (final r in rows) (r.read<String>('id'), r.read<String>('passage'))];
}

/// P05a T6 (§4, `[[`): the live documents of [workspaceId] whose TITLE
/// matches what was typed, best first.
Future<List<String>> searchDocumentTitleIdsIn(AppDatabase db, String workspaceId, String typed, {int limit = 20}) async {
  final q = searchQueryOf(searchForm(typed));
  if (q == null) return const [];
  await catchUpSearch(db);
  final rows = await db.customSelect(
    'SELECT d.id AS id FROM documents_fts f JOIN documents d ON d.rowid = f.rowid '
    'WHERE documents_fts MATCH ? AND d.workspace_id = ? AND d.deleted_at IS NULL ORDER BY rank LIMIT ?',
    variables: [Variable<String>('title : ($q)'), Variable<String>(workspaceId), Variable<int>(limit)],
    readsFrom: {db.documents},
  ).get();
  return [for (final r in rows) r.read<String>('id')];
}

/// The live documents of [workspaceId] whose text links to [documentId]
/// (backlinks, C6), by title. Links stay inside one workspace.
Future<List<String>> backlinkIdsIn(AppDatabase db, String workspaceId, String documentId) async {
  await catchUpSearch(db);
  final rows = await db.customSelect(
    'SELECT d.id AS id FROM document_link_index i JOIN documents d ON d.id = i.from_document_id '
    'WHERE i.to_document_id = ? AND d.workspace_id = ? AND d.deleted_at IS NULL AND d.id <> ? ORDER BY d.title, d.id',
    variables: [Variable<String>(documentId), Variable<String>(workspaceId), Variable<String>(documentId)],
    readsFrom: {db.documents},
  ).get();
  return [for (final r in rows) r.read<String>('id')];
}

/// P05b T2 (ADR-0077, D3): a PDF page that matched, with the live document
/// of the workspace that names its file, and a marked passage.
typedef PdfPageMatch = ({
  String documentId,
  String documentTitle,
  AttachmentRef file,
  int page,
  String passage,
});

/// The pages of this device's PDFs matching what was typed, through the live
/// documents of [workspaceId] that name them, best first.
Future<List<PdfPageMatch>> searchPdfPagesIn(AppDatabase db, String workspaceId, String typed,
    {int limit = 50, bool anyWord = false}) async {
  // P06b W4: the chat searches a whole question by any of its words.
  final q = anyWord ? searchAnyQueryOf(searchForm(typed)) : searchQueryOf(searchForm(typed));
  if (q == null) return const [];
  await catchUpSearch(db);
  final rows = await db.customSelect(
    "SELECT d.id AS doc, d.title AS title, i.hash AS hash, i.name AS name, i.size AS size, i.mime AS mime, "
    "f.page AS page, snippet(pdf_text_fts, 0, ?, ?, '…', 24) AS passage "
    'FROM pdf_text_fts f JOIN document_file_index i ON i.hash = f.hash JOIN documents d ON d.id = i.document_id '
    'WHERE pdf_text_fts MATCH ? AND d.workspace_id = ? AND d.deleted_at IS NULL ORDER BY rank, d.title, f.page LIMIT ?',
    variables: [
      Variable<String>(_matchStart),
      Variable<String>(_matchEnd),
      Variable<String>(q),
      Variable<String>(workspaceId),
      Variable<int>(limit),
    ],
    readsFrom: {db.documents, db.documentFileIndex},
  ).get();
  return [
    for (final r in rows)
      (
        documentId: r.read<String>('doc'),
        documentTitle: r.read<String>('title'),
        file: AttachmentRef(
            hash: r.read<String>('hash'), name: r.read<String>('name'), size: r.read<int>('size'), mime: r.read<String>('mime')),
        page: r.read<int>('page'),
        passage: r.read<String>('passage'),
      ),
  ];
}
