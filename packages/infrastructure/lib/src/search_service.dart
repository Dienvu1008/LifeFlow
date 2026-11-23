// P05a T6 (ADR-0071; p05-plan.md C4, C12): one search over the shown
// workspace (personal or a shared space): documents by title and text with a
// passage, tasks by title. By the exact spelling (search_index.dart).
// P05b T2 (ADR-0077, D3): and the pages of the PDFs on this device that the
// workspace's live documents name (pdf_text_index.dart).
import 'package:application/application.dart';

import 'app_database.dart';
import 'pdf_text_index.dart';
import 'profile_store.dart';
import 'search_index.dart';

class DriftSearchQueries implements SearchQueries {
  DriftSearchQueries(this.db, {this.pdfs}) : _store = ProfileStore(db);
  final AppDatabase db;

  /// The PDF text reader of this session: a search waits for the reads it
  /// has started (a PDF just added). Null: PDFs are searched as indexed.
  final PdfTextIndex? pdfs;
  final ProfileStore _store;

  @override
  Future<SearchResults> search(String typed, {int limit = 50}) async {
    final ws = (await _store.getActiveProfile())?.activeWorkspaceId.value;
    if (ws == null || typed.trim().isEmpty) return SearchResults.empty;
    final found = await searchDocumentPassagesIn(db, ws, typed, limit: limit);
    final docs = {
      for (final d in await (db.select(db.documents)..where((d) => d.id.isIn([for (final (id, _) in found) id]))).get())
        d.id: d
    };
    final taskIds = (await searchTaskIdsIn(db, ws, typed)).take(limit).toList();
    final tasks = {for (final t in await (db.select(db.tasks)..where((t) => t.id.isIn(taskIds))).get()) t.id: t};
    final hits = <DocumentHitView>[];
    for (final (id, marked) in found) {
      final d = docs[id];
      if (d == null) continue;
      final (passage, matches) = passageOf(marked);
      hits.add(DocumentHitView(id: id, title: d.title, passage: passage, matches: matches));
    }
    await pdfs?.idle;
    final pages = await searchPdfPagesIn(db, ws, typed, limit: limit);
    return SearchResults(
      documents: hits,
      tasks: [
        for (final id in taskIds)
          if (tasks[id] case final t?) TaskHitView(id: id, title: t.title, isDone: t.status == 'done'),
      ],
      files: [
        for (final p in pages)
          () {
            final (passage, matches) = passageOf(p.passage);
            return FileHitView(
                documentId: p.documentId,
                documentTitle: p.documentTitle,
                file: p.file,
                page: p.page,
                passage: passage,
                matches: matches);
          }(),
      ],
    );
  }
}
