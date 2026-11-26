// P06b W2 (owner UI 1): one search, reached from every main screen's
// options menu and from the Overview's + button. It searches what the
// Documents app bar searched before (P05a T8, P05b T2): documents, PDF
// pages and tasks of the shown space. The field left the Documents screen.
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../documents/document_page.dart' show openDocumentPage;
import '../documents/pdf_page.dart' show openPdfPage;
import '../l10n.dart';
import '../providers.dart';
import '../screens/task_page.dart' show openTaskPage;

/// Opens the search over the whole app (above the shell, like a document).
Future<void> openSearch(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _searched = '';
  Future<SearchResults>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _typed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _searched = v;
        _results = v.trim().isEmpty ? null : ref.read(searchQueriesProvider).search(v);
      });
    });
  }

  /// P05b T6 (steps 14, 29, 30): the shown results are searched again when
  /// the documents change (saved, trashed, restored, moved) or another space
  /// is shown, so they never show what is no longer there. The old results
  /// stay on screen until the new ones come (no flicker).
  void _searchAgain() {
    if (!mounted || _searched.trim().isEmpty || _results == null) return;
    setState(() {
      _results = ref.read(searchQueriesProvider).search(_searched);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.listen(documentTreeProvider, (before, now) {
      if (now.hasValue && !identical(before?.valueOrNull, now.valueOrNull)) _searchAgain();
    });
    return Scaffold(
      key: const Key('search-page'),
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-field'),
          controller: _query,
          autofocus: true,
          onChanged: _typed,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(hintText: l.docSearchHint, border: InputBorder.none),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              key: const Key('search-clear'),
              tooltip: l.close,
              icon: const Icon(Icons.close),
              onPressed: () {
                _query.clear();
                _typed('');
              },
            ),
        ],
      ),
      body: _results != null
          ? SearchResultsList(query: _searched, results: _results!)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.docSearchHint, key: const Key('search-empty'), textAlign: TextAlign.center),
              ),
            ),
    );
  }
}

/// The hits, by kind: documents, PDF pages, tasks.
class SearchResultsList extends ConsumerWidget {
  const SearchResultsList({super.key, required this.query, required this.results});
  final String query;
  final Future<SearchResults> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return FutureBuilder<SearchResults>(
      future: results,
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) {
          return snap.hasError
              ? Center(child: Text(l.docCouldNotLoad))
              : Center(child: CircularProgressIndicator(semanticsLabel: l.docLoading));
        }
        if (r.isEmpty) {
          return Center(child: Text(l.docNoResults(query.trim()), key: const Key('doc-no-results')));
        }
        Widget header(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Semantics(header: true, child: Text(text, style: theme.textTheme.titleSmall)),
            );
        return ListView(
          key: const Key('doc-results'),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (r.documents.isNotEmpty) header(l.docResultsDocuments),
            for (final h in r.documents)
              ListTile(
                key: ValueKey('doc-hit-${h.id}'),
                leading: const Icon(Icons.description_outlined),
                title: Text(h.title),
                subtitle: h.passage.trim().isEmpty
                    ? null
                    : Text.rich(passageSpan(h.passage, h.matches, theme), maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () => openDocumentPage(context, h.id),
              ),
            // P05b T2 (ADR-0077, D3): pages of the PDFs on this device.
            if (r.files.isNotEmpty) header(l.docResultsFiles),
            for (final h in r.files)
              ListTile(
                key: ValueKey('file-hit-${h.documentId}-${h.file.hash}-${h.page}'),
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(l.docFileHitTitle(h.file.name, h.page)),
                subtitle: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${l.docFileHitIn(h.documentTitle)}\n'),
                    passageSpan(h.passage, h.matches, theme),
                  ]),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => openPdfPage(context, h.file, ref.read(attachmentServiceProvider), page: h.page, find: query.trim()),
              ),
            if (r.tasks.isNotEmpty) header(l.docResultsTasks),
            for (final t in r.tasks)
              ListTile(
                key: ValueKey('task-hit-${t.id}'),
                leading: Icon(t.isDone ? Icons.check_circle_outline : Icons.radio_button_unchecked),
                title: Text(t.title, style: t.isDone ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
                onTap: () => openTaskPage(context, t.id),
              ),
          ],
        );
      },
    );
  }
}

/// A search passage with its matched words in bold.
TextSpan passageSpan(String passage, List<SearchMatch> matches, ThemeData theme) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final m in matches) {
    if (m.start < at || m.end > passage.length) continue;
    if (m.start > at) spans.add(TextSpan(text: passage.substring(at, m.start)));
    spans.add(TextSpan(
        text: passage.substring(m.start, m.end),
        style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)));
    at = m.end;
  }
  if (at < passage.length) spans.add(TextSpan(text: passage.substring(at)));
  return TextSpan(children: spans);
}
