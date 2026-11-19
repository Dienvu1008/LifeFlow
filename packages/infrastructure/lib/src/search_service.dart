// P05a T6 (ADR-0071; p05-plan.md C4, C12): one search over the shown
// workspace (personal or a shared space): documents by title and text with a
// passage, tasks by title. By the exact spelling (search_index.dart).
import 'package:application/application.dart';

import 'app_database.dart';
import 'profile_store.dart';
import 'search_index.dart';

class DriftSearchQueries implements SearchQueries {
  DriftSearchQueries(this.db) : _store = ProfileStore(db);
  final AppDatabase db;
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
    return SearchResults(
      documents: hits,
      tasks: [
        for (final id in taskIds)
          if (tasks[id] case final t?) TaskHitView(id: id, title: t.title, isDone: t.status == 'done'),
      ],
    );
  }
}
