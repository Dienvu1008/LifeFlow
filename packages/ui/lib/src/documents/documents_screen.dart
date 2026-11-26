// P05a T8 (ADR-0073; p05-plan.md C10, C4, C12): the Documents destination,
// after Calendar. The tree of the shown space's documents, "New document",
// the trash; the search moved to the options menu (P06b W2). Documents follow
// the shown space, as every view (P04b); a viewer adds nothing (B4).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../messages.dart';
import '../providers.dart';
import '../screens/spaces_ui.dart' show moveItemFlow, moveLabel;
import '../screens/tasks_screen.dart' show showTextDialog;
import '../shell.dart' show shellMenuButton;
import '../task_actions.dart' show reportResult, showMessage;
import '../widgets/options_menu.dart';
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
  final _collapsed = <String>{};

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
          // P06b W2 (owner UI 1): the search left this app bar for the
          // options menu (and the Overview's +), to give the tree the room.
          const OptionsMenu(),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              heroTag: 'fab-documents',
              tooltip: l.docNew,
              onPressed: () => newDocumentFlow(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: _tree(context, canEdit),
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
