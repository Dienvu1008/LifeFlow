// P05a T6 (ADR-0071; p05-plan.md C4, C12): one search over the shown
// workspace, by the exact spelling: documents by title and text, tasks by
// title. Marks are kept and letter case is ignored; whichever way a keyboard
// typed the marks, the same word is found. Every word typed must be there;
// the last may be the start of a word; "double quotes" make a phrase.

/// A part of [text] that matched: [start] to [end] (end not included).
typedef SearchMatch = ({int start, int end});

/// A document found: its title, and a short passage of its text with the
/// words that matched.
class DocumentHitView {
  const DocumentHitView({required this.id, required this.title, required this.passage, this.matches = const []});
  final String id;
  final String title;

  /// Up to a few lines of the text, cut with "…"; empty when only the title
  /// matched and the text is empty.
  final String passage;

  /// Where the words matched in [passage].
  final List<SearchMatch> matches;
}

/// A task found by its title.
class TaskHitView {
  const TaskHitView({required this.id, required this.title, required this.isDone});
  final String id;
  final String title;
  final bool isDone;
}

class SearchResults {
  const SearchResults({this.documents = const [], this.tasks = const []});
  static const empty = SearchResults();
  final List<DocumentHitView> documents;
  final List<TaskHitView> tasks;
  bool get isEmpty => documents.isEmpty && tasks.isEmpty;
}

abstract interface class SearchQueries {
  /// The live documents and tasks of the shown workspace matching [typed],
  /// best first, at most [limit] of each. Nothing typed: nothing found.
  Future<SearchResults> search(String typed, {int limit = 50});
}
