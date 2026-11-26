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
import '../overview_tree.dart' show DropZone;
import '../widgets/options_menu.dart';
import '../widgets/row_drag.dart';
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

/// Where a dropped document goes: under [parentId] (null: the top), after
/// [afterId] (null: first), as `DocumentService.move` takes it.
typedef DocumentDrop = ({String? parentId, String? afterId});

/// P06b W5 (owner UI 3): where [dragged] lands when dropped on the row of
/// [targetId] in [zone] of the tree as shown ([collapsed] folded):
///   before   just above the row, in the row's parent
///   into     the row's last subdocument
///   after    just below the row: its first subdocument when it is open with
///            subdocuments (they show right below), else after it
/// Null when nothing would change, or the target is the dragged document or
/// under it (DOC-001: never under itself).
DocumentDrop? resolveDocumentDrop(
    List<DocumentNodeView> tree, Set<String> collapsed, String dragged, String targetId, DropZone zone) {
  final ids = {for (final n in tree) n.id};
  String? parentOf(String id) {
    final p = tree.firstWhere((n) => n.id == id).parentId;
    return ids.contains(p) ? p : null;
  }

  if (!ids.contains(dragged) || !ids.contains(targetId)) return null;
  // The dragged one and everything under it cannot take it.
  for (String? x = targetId; x != null; x = parentOf(x)) {
    if (x == dragged) return null;
  }
  List<String> kids(String? parent) => [for (final n in tree) if (n.id != dragged && parentOf(n.id) == parent) n.id];

  final DocumentDrop drop;
  switch (zone) {
    case DropZone.into:
      final k = kids(targetId);
      drop = (parentId: targetId, afterId: k.isEmpty ? null : k.last);
    case DropZone.before:
      final parent = parentOf(targetId);
      final k = kids(parent);
      final i = k.indexOf(targetId);
      drop = (parentId: parent, afterId: i <= 0 ? null : k[i - 1]);
    case DropZone.after:
      drop = kids(targetId).isNotEmpty && !collapsed.contains(targetId)
          ? (parentId: targetId, afterId: null)
          : (parentId: parentOf(targetId), afterId: targetId);
  }
  // Where it already is: nothing to do.
  final parent = parentOf(dragged);
  final all = [for (final n in tree) if (parentOf(n.id) == parent) n.id];
  final i = all.indexOf(dragged);
  final current = (parentId: parent, afterId: i <= 0 ? null : all[i - 1]);
  return drop == current ? null : drop;
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

  /// P06b W5: the document being dragged, and the row and zone under it.
  String? _dragging;
  ({String id, DropZone zone})? _hover;
  Offset? _pointer;

  /// [id] is [ancestor] or under it.
  static bool _isUnder(List<DocumentNodeView> tree, String id, String ancestor) {
    final parent = {for (final n in tree) n.id: n.parentId};
    for (String? x = id; x != null; x = parent[x]) {
      if (x == ancestor) return true;
    }
    return false;
  }

  /// The depth [drop] puts a document at, for the drop line.
  static int _depthOf(List<TreeRow> rows, DocumentDrop drop) {
    if (drop.parentId == null) return 0;
    final p = rows.where((r) => r.node.id == drop.parentId).firstOrNull;
    return p == null ? 0 : p.depth + 1;
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
            final look = ref.watch(appearanceProvider).valueOrNull ?? const AppearanceSettings();
            final drop = _dragging == null || _hover == null
                ? null
                : resolveDocumentDrop(tree, _collapsed, _dragging!, _hover!.id, _hover!.zone);
            Widget tile(TreeRow r) => ListTile(
                  key: ValueKey('doc-${r.node.id}'),
                  contentPadding: EdgeInsets.only(left: 8 + 20.0 * r.depth, right: 4),
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (canEdit) const RowDragHandle(),
                    r.hasChildren
                        ? IconButton(
                            key: ValueKey('doc-toggle-${r.node.id}'),
                            tooltip: r.node.title,
                            icon: Icon(_collapsed.contains(r.node.id) ? Icons.chevron_right : Icons.expand_more),
                            onPressed: () => setState(() =>
                                _collapsed.contains(r.node.id) ? _collapsed.remove(r.node.id) : _collapsed.add(r.node.id)),
                          )
                        : const SizedBox(width: 48, child: Icon(Icons.description_outlined)),
                  ]),
                  title: Text(r.node.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => openDocumentPage(context, r.node.id),
                  trailing: canEdit ? _DocMenu(node: r.node) : null,
                );
            return DragHandlesScope(
              show: showDragHandles(context, look.dragHandles),
              // The drop zone follows the pointer, not the dragged copy's corner.
              child: Listener(
                onPointerDown: (e) => _pointer = e.position,
                onPointerMove: (e) => _pointer = e.position,
                child: ListView(
                key: const Key('doc-tree'),
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final r in rows)
                    if (!canEdit)
                      tile(r)
                    else
                      _DocDropSlot(
                        key: ValueKey('doc-slot-${r.node.id}'),
                        row: r,
                        hover: _hover?.id == r.node.id ? _hover!.zone : null,
                        // The line at the depth it lands on; nothing shown where it cannot go.
                        landing: _hover?.id == r.node.id && drop != null ? _depthOf(rows, drop) : null,
                        fade: _dragging != null && _isUnder(tree, r.node.id, _dragging!),
                        onHover: (zone) {
                          if (_hover?.id != r.node.id || _hover?.zone != zone) setState(() => _hover = (id: r.node.id, zone: zone));
                        },
                        onLeave: () {
                          if (_hover?.id == r.node.id) setState(() => _hover = null);
                        },
                        onDrop: (dragged, zone) {
                          setState(() => _hover = null);
                          final to = resolveDocumentDrop(tree, _collapsed, dragged, r.node.id, zone);
                          if (to == null) return;
                          // Dropped into a folded one: open it, so the document is seen there.
                          if (to.parentId != null) _collapsed.remove(to.parentId);
                          reportResult(context, ref.read(documentServiceProvider).move(dragged, parentId: to.parentId, afterId: to.afterId));
                        },
                        onDragStart: () => setState(() => _dragging = r.node.id),
                        onDragEnd: () => setState(() {
                          _dragging = null;
                          _hover = null;
                        }),
                        pointer: () => _pointer,
                        child: tile(r),
                      ),
                ],
              ),
              ),
            );
          },
        );
  }
}

/// P06b W5 (owner UI 3): a row of the tree that can be dragged (by its
/// handle, or a long press on touch and where the handles are hidden) and
/// dropped on: its top quarter puts the document before it, its bottom
/// quarter after it, the middle into it.
class _DocDropSlot extends StatelessWidget {
  const _DocDropSlot({
    super.key,
    required this.row,
    required this.hover,
    required this.landing,
    required this.fade,
    required this.onHover,
    required this.onLeave,
    required this.onDrop,
    required this.onDragStart,
    required this.onDragEnd,
    required this.pointer,
    required this.child,
  });
  final TreeRow row;
  final Offset? Function() pointer;

  /// The zone of this row under the dragged document, if any.
  final DropZone? hover;

  /// The depth the document would land at; null when it cannot land here.
  final int? landing;

  /// This row is the dragged one, or under it.
  final bool fade;
  final ValueChanged<DropZone> onHover;
  final VoidCallback onLeave;
  final void Function(String dragged, DropZone zone) onDrop;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final Widget child;

  DropZone? _zoneAt(BuildContext context, Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final f = (box.globalToLocal(global).dy / box.size.height).clamp(0.0, 1.0);
    return f < 0.25 ? DropZone.before : (f > 0.75 ? DropZone.after : DropZone.into);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = hover;
    final ok = landing != null;
    Widget content = AnimatedOpacity(opacity: fade ? 0.35 : 1, duration: const Duration(milliseconds: 120), child: child);
    if (h == DropZone.into && ok) {
      content = Material(key: const Key('doc-drop-into'), color: scheme.primaryContainer.withValues(alpha: 0.6), child: content);
    }
    final target = DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (d) {
        final z = _zoneAt(context, pointer() ?? d.offset);
        if (z != null) onHover(z);
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) {
        final z = _zoneAt(context, pointer() ?? d.offset) ?? hover;
        if (z != null) onDrop(d.data, z);
      },
      builder: (context, _, __) => Stack(children: [
        content,
        if (h != null && h != DropZone.into && ok)
          PositionedDirectional(
            key: const Key('doc-drop-line'),
            start: 8 + 20.0 * landing! + 8,
            end: 8,
            top: h == DropZone.before ? 0 : null,
            bottom: h == DropZone.after ? 0 : null,
            height: 3,
            child: DecoratedBox(decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2))),
          ),
      ]),
    );
    return RowDragScope(
      id: row.node.id,
      title: row.node.title,
      preview: child,
      rowBox: () => context.findRenderObject() as RenderBox?,
      onStart: onDragStart,
      onEnd: onDragEnd,
      child: Builder(builder: (context) => longPressRowDrag(context, target)),
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
