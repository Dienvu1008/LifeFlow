// P05a T8 (ADR-0073; p05-plan.md C10, C4, C12): the Documents destination,
// after Calendar. The tree of the shown space's documents, one search over
// documents and tasks at the top, "New document", the trash. Documents follow
// the shown space, as every view (P04b); a viewer adds nothing (B4).
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../messages.dart';
import '../providers.dart';
import '../screens/spaces_ui.dart' show moveItemFlow, moveLabel;
import '../screens/task_page.dart' show openTaskPage;
import '../screens/tasks_screen.dart' show showTextDialog;
import '../shell.dart' show shellMenuButton;
import '../task_actions.dart' show reportResult, showMessage;
import 'document_page.dart';

/// A document with its depth in the tree.
typedef TreeRow = ({DocumentNodeView node, int depth, bool hasChildren});

/// The tree in order with depths; the children of [collapsed] ones hidden.
List<TreeRow> treeRows(List<DocumentNodeView> tree, Set<String> collapsed) {
  final ids = {for (final n in tree) n.id};
  final parents = {for (final n in tree) if (n.parentId != null && ids.contains(n.parentId)) n.parentId!};
  final depth = <String, int>{};
  final out = <TreeRow>[];
  final hiddenUnder = <String>{};
  for (final n in tree) {
    final p = ids.contains(n.parentId) ? n.parentId : null;
    final d = p == null ? 0 : (depth[p] ?? 0) + 1;
    depth[n.id] = d;
    if (p != null && (hiddenUnder.contains(p) || collapsed.contains(p))) {
      hiddenUnder.add(n.id);
      continue;
    }
    out.add((node: n, depth: d, hasChildren: parents.contains(n.id)));
  }
  return out;
}

/// "New document" (under [parentId] when given): asks for a title, then
/// opens it.
Future<void> newDocumentFlow(BuildContext context, WidgetRef ref, {String? parentId}) async {
  final l = context.l10n;
  final title = await showTextDialog(context, title: parentId == null ? l.docNew : l.docNewSub, confirmLabel: l.add);
  if (title == null || !context.mounted) return;
  final r = await ref.read(documentServiceProvider).create(title, parentId: parentId);
  if (!context.mounted) return;
  if (r is CommandFailure) return showMessage(context, describeFailure(r));
  await openDocumentPage(context, (r as CommandOk).entityId);
}

/// "Move under…": any document that is not this one or under it, or the top.
Future<void> moveUnderFlow(BuildContext context, WidgetRef ref, DocumentNodeView doc) async {
  final l = context.l10n;
  final List<DocumentNodeView> tree = ref.read(documentTreeProvider).valueOrNull ?? await ref.read(documentTreeProvider.future);
  final below = <String>{doc.id};
  for (final n in tree) {
    if (n.parentId != null && below.contains(n.parentId)) below.add(n.id);
  }
  if (!context.mounted) return;
  const top = '';
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      key: const Key('doc-move-under'),
      title: Text(l.docPickParent),
      children: [
        SimpleDialogOption(key: const Key('doc-move-top'), onPressed: () => Navigator.pop(ctx, top), child: Text(l.docTopLevel)),
        for (final row in treeRows(tree, const {}))
          if (!below.contains(row.node.id))
            SimpleDialogOption(
              key: ValueKey('doc-move-to-${row.node.id}'),
              onPressed: () => Navigator.pop(ctx, row.node.id),
              child: Padding(padding: EdgeInsets.only(left: 16.0 * row.depth), child: Text(row.node.title)),
            ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  await reportResult(context, ref.read(documentServiceProvider).move(doc.id, parentId: picked == top ? null : picked));
}

/// Moves a document (with its subdocuments) to the trash, and says so.
Future<bool> trashDocumentFlow(BuildContext context, WidgetRef ref, String id, String title) async {
  final r = await ref.read(documentServiceProvider).trash(id);
  if (!context.mounted) return false;
  if (r is CommandFailure) {
    showMessage(context, describeFailure(r));
    return false;
  }
  ref.invalidate(trashedDocumentsProvider);
  showMessage(context, context.l10n.docTrashed(title));
  return true;
}

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _query = TextEditingController();
  final _collapsed = <String>{};
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canEdit = ref.watch(canEditShownProvider);
    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: Text(l.navDocuments),
        actions: [
          IconButton(
            key: const Key('doc-open-trash'),
            tooltip: l.docTrash,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .push(MaterialPageRoute<void>(builder: (_) => const DocumentsTrashPage())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const Key('doc-search'),
              controller: _query,
              onChanged: _typed,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.docSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('doc-search-clear'),
                        tooltip: l.close,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _query.clear();
                          _typed('');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'fab-documents',
              tooltip: l.docNew,
              onPressed: () => newDocumentFlow(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: _results != null ? _SearchResults(query: _searched, results: _results!) : _tree(context, canEdit),
    );
  }

  Widget _tree(BuildContext context, bool canEdit) {
    final l = context.l10n;
    return ref.watch(documentTreeProvider).when(
          loading: () => Center(child: CircularProgressIndicator(semanticsLabel: l.docLoading)),
          error: (e, _) => Center(child: Text(l.docCouldNotLoad)),
          data: (tree) {
            if (tree.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.docEmpty,
                      key: const Key('docs-empty'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                ),
              );
            }
            final rows = treeRows(tree, _collapsed);
            return ListView(
              key: const Key('doc-tree'),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final r in rows)
                  ListTile(
                    key: ValueKey('doc-${r.node.id}'),
                    contentPadding: EdgeInsets.only(left: 8 + 20.0 * r.depth, right: 4),
                    leading: r.hasChildren
                        ? IconButton(
                            key: ValueKey('doc-toggle-${r.node.id}'),
                            tooltip: r.node.title,
                            icon: Icon(_collapsed.contains(r.node.id) ? Icons.chevron_right : Icons.expand_more),
                            onPressed: () => setState(() =>
                                _collapsed.contains(r.node.id) ? _collapsed.remove(r.node.id) : _collapsed.add(r.node.id)),
                          )
                        : const SizedBox(width: 48, child: Icon(Icons.description_outlined)),
                    title: Text(r.node.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => openDocumentPage(context, r.node.id),
                    trailing: canEdit ? _DocMenu(node: r.node) : null,
                  ),
              ],
            );
          },
        );
  }
}

enum _DocAction { sub, move, space, trash }

class _DocMenu extends ConsumerWidget {
  const _DocMenu({required this.node});
  final DocumentNodeView node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PopupMenuButton<_DocAction>(
      key: ValueKey('doc-menu-${node.id}'),
      tooltip: l.actionsForTitle(node.title),
      onSelected: (a) async {
        switch (a) {
          case _DocAction.sub:
            await newDocumentFlow(context, ref, parentId: node.id);
          case _DocAction.move:
            await moveUnderFlow(context, ref, node);
          case _DocAction.space:
            await moveItemFlow(context, ref, kind: 'document', id: node.id);
          case _DocAction.trash:
            await trashDocumentFlow(context, ref, node.id, node.title);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: _DocAction.sub, child: Text(l.docNewSub)),
        PopupMenuItem(value: _DocAction.move, child: Text(l.docMoveUnder)),
        if (moveLabel(context, ref) case final m?) PopupMenuItem(value: _DocAction.space, child: Text(m)),
        PopupMenuItem(value: _DocAction.trash, child: Text(l.moveToTrash)),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.results});
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
                subtitle: h.passage.trim().isEmpty ? null : Text.rich(passageSpan(h, theme), maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () => openDocumentPage(context, h.id),
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
TextSpan passageSpan(DocumentHitView h, ThemeData theme) {
  final spans = <TextSpan>[];
  var at = 0;
  for (final m in h.matches) {
    if (m.start < at || m.end > h.passage.length) continue;
    if (m.start > at) spans.add(TextSpan(text: h.passage.substring(at, m.start)));
    spans.add(TextSpan(
        text: h.passage.substring(m.start, m.end),
        style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)));
    at = m.end;
  }
  if (at < h.passage.length) spans.add(TextSpan(text: h.passage.substring(at)));
  return TextSpan(children: spans);
}

/// The documents in the trash: each as it was trashed (its subdocuments
/// come back with it).
class DocumentsTrashPage extends ConsumerWidget {
  const DocumentsTrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canEdit = ref.watch(canEditShownProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.docTrash)),
      body: ref.watch(trashedDocumentsProvider).when(
            loading: () => Center(child: CircularProgressIndicator(semanticsLabel: l.docLoading)),
            error: (e, _) => Center(child: Text(l.docCouldNotLoad)),
            data: (list) => list.isEmpty
                ? Center(child: Text(l.docTrashEmpty, key: const Key('doc-trash-empty')))
                : ListView(key: const Key('doc-trash'), children: [
                    for (final d in list)
                      ListTile(
                        key: ValueKey('doc-trashed-${d.id}'),
                        leading: const Icon(Icons.description_outlined),
                        title: Text(d.title),
                        onTap: () => openDocumentPage(context, d.id),
                        trailing: canEdit
                            ? TextButton(
                                key: ValueKey('doc-restore-${d.id}'),
                                onPressed: () async {
                                  await reportResult(context, ref.read(documentServiceProvider).restore(d.id));
                                  ref.invalidate(trashedDocumentsProvider);
                                },
                                child: Text(l.restore),
                              )
                            : null,
                      ),
                  ]),
          ),
    );
  }
}
