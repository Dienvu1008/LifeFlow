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
Future<List<String>> searchTaskIdsIn(AppDatabase db, String workspaceId, String typed) async {
  final q = searchQueryOf(searchForm(typed));
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
