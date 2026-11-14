// P03 UX U3 (ADR-0047): the Overview. Lists on top with their tasks and
// events, then the items in no list; tasks expand to their subtasks (4
// levels). Rows are dense, with a colour bar on the left (U-D4). Drag a row
// by its handle (or long-press it on a touch screen): above or below a row
// reorders, onto a task makes it a subtask, right / left changes the level,
// onto a list moves it there. Every move is also in the row's menu, so
// nothing needs dragging (WCAG 2.5.7). Each change is one command through
// the gateway; the store checks it again (ADR-0046).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../habit_text.dart';
import '../l10n.dart';
import '../overview_tree.dart';
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import '../theme/lifeflow_theme.dart';
import 'event_editor.dart';
import 'focus_page.dart';
import 'goals_screen.dart';
import 'habit_page.dart';
import 'schedule_editor.dart';
import 'task_page.dart';
import 'tasks_screen.dart' show addTaskWithDialog, showTextDialog, trashTask;

/// Width of one indentation step.
const _indentStep = 24.0;

/// Space kept free under the last row so the + button never covers it.
const _fabClearance = 96.0;

/// Typical row height; only an estimate to get near a row not built yet.
const _rowExtent = 48.0;

String colourName(BuildContext context, int index) {
  final l = context.l10n;
  return switch (index) {
    0 => l.ovColorRed,
    1 => l.ovColorOrange,
    2 => l.ovColorAmber,
    3 => l.ovColorOlive,
    4 => l.ovColorGreen,
    5 => l.ovColorTeal,
    6 => l.ovColorCyan,
    7 => l.ovColorBlue,
    8 => l.ovColorIndigo,
    9 => l.ovColorPurple,
    10 => l.ovColorPink,
    _ => l.ovColorBrown,
  };
}

/// Runs one move and shows what moved in (a list or a task it went into).
Future<void> runMove(BuildContext context, WidgetRef ref, MovePlan plan) async {
  final s = ref.read(overviewServiceProvider);
  final pending = switch (plan) {
    MoveListPlan(:final listId, :final afterId) => s.moveList(listId, afterId: afterId),
    MoveItemPlan(:final id, :final kind, :final place) =>
      kind == ItemKind.event ? s.moveEvent(id, place) : s.moveTask(id, place),
  };
  if (plan is MoveItemPlan && plan.opens != null) ref.read(collapsedItemsProvider.notifier).expand(plan.opens!);
  await reportResult(context, pending);
}

/// The palette, or "No colour". Null when cancelled.
Future<({int? index})?> pickColour(BuildContext context, int? current) => showDialog<({int? index})>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        return AlertDialog(
          key: const Key('colour-picker'),
          title: Text(l.ovColourTitle),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < itemPalette.length; i++)
                Semantics(
                  button: true,
                  selected: i == current,
                  label: colourName(context, i),
                  excludeSemantics: true,
                  child: InkResponse(
                    key: ValueKey('colour-$i'),
                    onTap: () => Navigator.pop(context, (index: i)),
                    radius: 24,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: itemColorOf(context, i),
                        shape: BoxShape.circle,
                        border: i == current
                            ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                            : null,
                      ),
                      child: i == current ? Icon(Icons.check, color: Theme.of(context).colorScheme.surface) : null,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
            TextButton(
                key: const Key('colour-none'),
                onPressed: () => Navigator.pop(context, (index: null)),
                child: Text(l.ovNoColour)),
          ],
        );
      },
    );

/// A list to move to ('' = no list). Null when cancelled.
Future<String?> pickList(BuildContext context, List<TaskListView> lists, String? current) => showDialog<String>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        Widget option(String value, String label, int? colour) => ListTile(
              key: ValueKey('move-to-${value.isEmpty ? 'none' : value}'),
              leading: Icon(Icons.circle, color: itemColorOf(context, colour) ?? Colors.transparent, size: 12),
              title: Text(label),
              selected: (current ?? '') == value,
              onTap: () => Navigator.pop(context, value),
            );
        return SimpleDialog(
          title: Text(l.ovMoveToListTitle),
          children: [
            option('', l.ovNoList, null),
            for (final x in lists) option(x.id, x.title, x.colorIndex),
          ],
        );
      },
    );

/// The + of the Overview: a small speed dial (list, event, task).
class OverviewAddButton extends StatefulWidget {
  const OverviewAddButton({super.key, required this.onTask, required this.onList, required this.onEvent});
  final VoidCallback onTask;
  final VoidCallback onList;
  final VoidCallback onEvent;

  @override
  State<OverviewAddButton> createState() => _OverviewAddButtonState();
}

class _OverviewAddButtonState extends State<OverviewAddButton> {
  bool _open = false;

  void _pick(VoidCallback f) {
    setState(() => _open = false);
    f();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget mini(String key, String label, IconData icon, VoidCallback f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FloatingActionButton.extended(
            key: Key(key),
            heroTag: key,
            tooltip: label,
            onPressed: () => _pick(f),
            icon: Icon(icon),
            label: Text(label),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          mini('add-list', l.ovNewList, Icons.folder_outlined, widget.onList),
          mini('add-event', l.ovNewEvent, Icons.event_outlined, widget.onEvent),
          mini('add-task', l.ovAddTask, Icons.check_box_outlined, widget.onTask),
        ],
        FloatingActionButton(
          key: const Key('add-menu'),
          heroTag: 'fab-tasks',
          tooltip: _open ? l.ovCloseAddMenu : l.ovAddMenu,
          onPressed: () => setState(() => _open = !_open),
          child: Icon(_open ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

/// Asks for a list's title and creates it at the end.
Future<void> addList(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final title = await showTextDialog(context, title: l.ovNewList, confirmLabel: l.add);
  if (title == null || !context.mounted) return;
  await reportResult(context, ref.read(overviewServiceProvider).createList(title));
}

class OverviewView extends ConsumerStatefulWidget {
  const OverviewView({super.key, this.revealId, required this.onRevealed, required this.onAddSubtask});

  /// A task just added; scrolled into view once it shows.
  final String? revealId;
  final VoidCallback onRevealed;
  final Future<void> Function(String parentId) onAddSubtask;

  @override
  ConsumerState<OverviewView> createState() => _OverviewViewState();
}

/// Where a drag hovers: row, zone and level shift.
typedef _Hover = ({int index, DropZone zone, int shift});

class _OverviewViewState extends ConsumerState<OverviewView> {
  final _scroll = ScrollController();
  final _revealKey = GlobalKey();
  String? _revealing;

  /// The last id revealed (the parent clears its own on the callback).
  String? _revealed;
  _Hover? _hover;
  double? _downX;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      if (_revealKey.currentContext == null) {
        final pos = _scroll.position;
        _scroll.jumpTo((index * _rowExtent - pos.viewportDimension / 2).clamp(0.0, pos.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
      }
      final ctx = _revealKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, alignment: 0.5, duration: const Duration(milliseconds: 250));
      }
      if (mounted) setState(() => _revealing = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tasks = ref.watch(tasksProvider);
    final lists = ref.watch(listsProvider).valueOrNull ?? const <TaskListView>[];
    final events = ref.watch(overviewEventsProvider).valueOrNull ?? const <OverviewEventView>[];
    final collapsed = ref.watch(collapsedItemsProvider);
    return tasks.when(
      loading: () => Center(child: CircularProgressIndicator(semanticsLabel: l.ovLoading)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.ovLoadError, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
      data: (list) {
        if (list.isEmpty && lists.isEmpty && events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.ovEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            ),
          );
        }
        final ix = OverviewIndex(lists: lists, tasks: list, events: events);
        final rows = overviewRows(ix, collapsed);
        final reveal = widget.revealId;
        if (reveal != null && reveal != _revealed) {
          final i = rows.indexWhere((r) => r.id == reveal);
          if (i >= 0) {
            _revealed = reveal;
            _revealing = reveal;
            widget.onRevealed();
            _reveal(i);
          }
        }
        final look = ref.watch(appearanceProvider).valueOrNull ?? const AppearanceSettings();
        final handles = switch (look.dragHandles) {
          DragHandles.always => true,
          DragHandles.never => false,
          DragHandles.auto => isPointerPlatform(Theme.of(context).platform),
        };
        return _Handles(show: handles, child: Listener(
          onPointerDown: (e) {
            _downX = e.position.dx;
            _pointer = e.position;
          },
          // The drop zone follows the pointer, not the dragged copy's corner.
          onPointerMove: (e) => _pointer = e.position,
          child: ListView.builder(
            key: const Key('task-list'),
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: _fabClearance),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = _DropSlot(
                key: ValueKey('slot-${rows[i].id}'),
                index: i,
                row: rows[i],
                hover: _hover?.index == i ? _hover : null,
                plan: _hover?.index == i ? _planFor(ix, rows, _dragging, _hover!) : null,
                lineIndent: _hover?.index == i ? _landingIndent(ix, rows, _planFor(ix, rows, _dragging, _hover!)) : 0,
                fade: _dragging != null && (rows[i].id == _dragging || ix.isWithin(rows[i].id, _dragging!)),
                onHover: (h) => setState(() => _hover = h),
                onLeave: () {
                  if (_hover?.index == i) setState(() => _hover = null);
                },
                onDrop: (id, h) {
                  setState(() => _hover = null);
                  final plan = resolveDrop(ix, rows, id, h.index, h.zone, h.shift);
                  if (plan != null) runMove(context, ref, plan);
                },
                dragStartX: () => _downX,
                pointer: () => _pointer,
                isTask: ix.tasks.containsKey,
                onDragStart: (id) => setState(() => _dragging = id),
                onDragEnd: () => setState(() {
                  _dragging = null;
                  _hover = null;
                }),
                child: _rowWidget(ix, rows[i]),
              );
              return rows[i].id == _revealing ? KeyedSubtree(key: _revealKey, child: row) : row;
            },
          ),
        ));
      },
    );
  }

  String? _dragging;
  Offset? _pointer;

  /// The indentation of the place [plan] puts the item (for the drop line).
  int _landingIndent(OverviewIndex ix, List<OverviewRow> rows, MovePlan? plan) {
    if (plan is! MoveItemPlan) return 0;
    final p = plan.place;
    if (p.parentId != null) {
      final parent = rows.where((r) => r.id == p.parentId).firstOrNull;
      return (parent?.indent ?? 0) + 1;
    }
    return p.listId != null ? 1 : 0;
  }

  MovePlan? _planFor(OverviewIndex ix, List<OverviewRow> rows, String? dragged, _Hover h) =>
      dragged == null ? null : resolveDrop(ix, rows, dragged, h.index, h.zone, h.shift);

  Widget _rowWidget(OverviewIndex ix, OverviewRow r) => switch (r) {
        ListRow() => _ListHeader(ix: ix, row: r),
        LooseHeaderRow() => const _LooseHeader(),
        TaskItemRow() => _TaskItem(ix: ix, row: r, onAddSubtask: widget.onAddSubtask),
        EventItemRow() => _EventItem(ix: ix, row: r),
      };
}

/// A row that can be dragged (by its handle, or a long press when handles
/// are hidden or on touch) and dropped on. The zone under the pointer and the
/// horizontal movement since the drag began decide the drop (resolveDrop).
/// Dogfooding O2 (ADR-0051): the dragged copy is the whole row at its width;
/// the original fades in place; the drop line is indented at the level the
/// item will take and slides there.
class _DropSlot extends StatefulWidget {
  const _DropSlot({
    super.key,
    required this.index,
    required this.row,
    required this.hover,
    required this.plan,
    required this.lineIndent,
    required this.fade,
    required this.onHover,
    required this.onLeave,
    required this.onDrop,
    required this.dragStartX,
    required this.pointer,
    required this.isTask,
    required this.onDragStart,
    required this.onDragEnd,
    required this.child,
  });
  final int index;
  final OverviewRow row;
  final _Hover? hover;
  final MovePlan? plan;

  /// Where the item lands, in indentation steps (for the drop line).
  final int lineIndent;

  /// This row is the dragged one, or inside it.
  final bool fade;
  final ValueChanged<_Hover> onHover;
  final VoidCallback onLeave;
  final void Function(String id, _Hover hover) onDrop;
  final double? Function() dragStartX;
  final Offset? Function() pointer;
  final bool Function(String id) isTask;
  final ValueChanged<String> onDragStart;
  final VoidCallback onDragEnd;
  final Widget child;

  @override
  State<_DropSlot> createState() => _DropSlotState();
}

class _DropSlotState extends State<_DropSlot> {
  double? _startX;

  _Hover? _hoverAt(String dragged, Offset global, bool draggingTask) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final f = (local.dy / box.size.height).clamp(0.0, 1.0);
    final row = widget.row;
    final DropZone zone;
    if (row is ListRow) {
      zone = f < 0.3 ? DropZone.before : DropZone.into;
    } else if (row is LooseHeaderRow) {
      zone = DropZone.into;
    } else if (row is TaskItemRow && draggingTask) {
      zone = f < 0.25 ? DropZone.before : (f > 0.75 ? DropZone.after : DropZone.into);
    } else {
      zone = f < 0.5 ? DropZone.before : DropZone.after;
    }
    final start = _startX ?? widget.dragStartX() ?? global.dx;
    return (index: widget.index, zone: zone, shift: ((global.dx - start) / _indentStep).round());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = widget.row;
    final h = widget.hover;
    final valid = widget.plan != null;
    Widget content = AnimatedOpacity(
      key: ValueKey('fade-${row.id}'),
      opacity: widget.fade ? 0.35 : 1,
      duration: const Duration(milliseconds: 120),
      child: widget.child,
    );
    if (h != null && valid && h.zone == DropZone.into) {
      // Its own Material, so the rows' ink still shows (tiles are tappable).
      content = Material(color: scheme.primaryContainer.withValues(alpha: 0.6), child: content);
    }
    final showLine = h != null && valid && h.zone != DropZone.into;
    final target = DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (d) {
        final hov = _hoverAt(d.data, widget.pointer() ?? d.offset, widget.isTask(d.data));
        if (hov != null && hov != widget.hover) widget.onHover(hov);
      },
      onLeave: (_) => widget.onLeave(),
      onAcceptWithDetails: (d) {
        final hov = _hoverAt(d.data, widget.pointer() ?? d.offset, widget.isTask(d.data));
        if (hov != null) widget.onDrop(d.data, hov);
      },
      builder: (context, candidates, rejected) => Stack(
        children: [
          content,
          if (showLine)
            AnimatedPositionedDirectional(
              key: const Key('drop-line'),
              duration: const Duration(milliseconds: 120),
              start: widget.lineIndent * _indentStep + 8,
              end: 8,
              top: h.zone == DropZone.before ? 0 : null,
              bottom: h.zone == DropZone.after ? 0 : null,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
    );
    if (row is LooseHeaderRow) return target;
    return _DragScope(
      id: row.id,
      title: _titleOf(row),
      preview: widget.child,
      rowBox: () => context.findRenderObject() as RenderBox?,
      onStart: () {
        _startX = widget.dragStartX();
        widget.onDragStart(row.id);
      },
      onEnd: () {
        _startX = null;
        widget.onDragEnd();
      },
      child: target,
    );
  }
}

String _titleOf(OverviewRow r) => switch (r) {
      ListRow(:final list) => list.title,
      TaskItemRow(:final task) => task.title,
      EventItemRow(:final event) => event.title,
      LooseHeaderRow() => '',
    };

/// Whether the Overview shows drag handles (dogfooding O1); also given to
/// the dragged copy so it looks like its row.
class _Handles extends InheritedWidget {
  const _Handles({required this.show, required super.child});
  final bool show;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_Handles>()?.show ?? true;

  @override
  bool updateShouldNotify(_Handles old) => old.show != show;
}

/// Lets the row's handle (and a long press on the row) start a drag of [id].
class _DragScope extends InheritedWidget {
  const _DragScope({
    required this.id,
    required this.title,
    required this.preview,
    required this.rowBox,
    required this.onStart,
    required this.onEnd,
    required super.child,
  });
  final String id;
  final String title;

  /// The row as it looks, for the dragged copy.
  final Widget preview;
  final RenderBox? Function() rowBox;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  static _DragScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_DragScope>();

  @override
  bool updateShouldNotify(_DragScope old) => old.id != id || old.title != title || old.preview != preview;
}

/// The dragged copy: the whole row at its width, a little transparent, raised.
/// Built when the drag starts (in the overlay), so the row is laid out.
Widget _feedback(BuildContext context, _DragScope scope) =>
    _FeedbackCopy(scope: scope, handles: _Handles.of(context));

class _FeedbackCopy extends StatelessWidget {
  const _FeedbackCopy({required this.scope, required this.handles});
  final _DragScope scope;
  final bool handles;

  @override
  Widget build(BuildContext context) {
    final box = scope.rowBox();
    final width = box != null && box.hasSize ? box.size.width : 320.0;
    return _Handles(
      show: handles,
      child: SizedBox(
        key: const Key('drag-feedback'),
        width: width,
        child: Opacity(
          opacity: 0.9,
          child: Material(
            elevation: 6,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: scope.preview,
          ),
        ),
      ),
    );
  }
}
/// Keeps the copy where the row was under the pointer (not at its corner).
DragAnchorStrategy _rowAnchor(_DragScope scope) => (draggable, context, position) {
      final box = scope.rowBox();
      return box == null || !box.hasSize ? Offset.zero : box.globalToLocal(position);
    };

/// The drag handle at the start of a row (hidden by the setting, O1).
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    if (!_Handles.of(context)) return const SizedBox.shrink();
    final scope = _DragScope.of(context);
    if (scope == null) return const SizedBox(width: 24);
    return Draggable<String>(
      data: scope.id,
      dragAnchorStrategy: _rowAnchor(scope),
      feedback: _feedback(context, scope),
      onDragStarted: scope.onStart,
      onDragEnd: (_) => scope.onEnd(),
      child: Semantics(
        label: context.l10n.ovDragHandle(scope.title),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: SizedBox(
            key: ValueKey('drag-${scope.id}'),
            width: 24,
            height: 40,
            child: Icon(Icons.drag_indicator, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// A long press anywhere on the row drags it too: on touch, and wherever the
/// handles are hidden.
Widget _longPressDrag(BuildContext context, Widget child) {
  final scope = _DragScope.of(context);
  if (scope == null || (isPointerPlatform(Theme.of(context).platform) && _Handles.of(context))) return child;
  return LongPressDraggable<String>(
    data: scope.id,
    dragAnchorStrategy: _rowAnchor(scope),
    feedback: _feedback(context, scope),
    onDragStarted: scope.onStart,
    onDragEnd: (_) => scope.onEnd(),
    child: child,
  );
}

/// The colour bar on the left (U-D4) and the indentation of a row.
Widget _frame(BuildContext context, {required int indent, required int? colour, required Widget child}) {
  final c = itemColorOf(context, colour);
  return Padding(
    padding: EdgeInsetsDirectional.only(start: indent * _indentStep),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: c ?? Colors.transparent, width: 4)),
      ),
      child: _longPressDrag(context, child),
    ),
  );
}

Widget _toggle(BuildContext context, WidgetRef ref, String id, String title, {required bool show, required bool collapsed}) {
  if (!show) return const SizedBox(width: 32);
  final l = context.l10n;
  return SizedBox(
    width: 32,
    child: IconButton(
      key: ValueKey('toggle-$id'),
      padding: EdgeInsets.zero,
      tooltip: collapsed ? l.ovExpand(title) : l.ovCollapse(title),
      icon: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
      onPressed: () => ref.read(collapsedItemsProvider.notifier).toggle(id),
    ),
  );
}

PopupMenuItem<String> _item(String value, String label) => PopupMenuItem(value: value, child: Text(label));

/// The menu entries that move [id] (only those that are possible).
List<PopupMenuItem<String>> _moveItems(BuildContext context, OverviewIndex ix, String id) {
  final l = context.l10n;
  return [
    if (moveUp(ix, id) != null) _item('up', l.ovMoveUp),
    if (moveDown(ix, id) != null) _item('down', l.ovMoveDown),
    if (indent(ix, id) != null) _item('indent', l.ovIndent),
    if (outdent(ix, id) != null) _item('outdent', l.ovOutdent),
    if (ix.kindOf(id) != ItemKind.list && ix.containerOf[id]?.startsWith('in:') == true) _item('list', l.ovMoveToList),
  ];
}

/// Handles a move entry of a menu; false when [action] is not one.
Future<bool> _onMoveAction(BuildContext context, WidgetRef ref, OverviewIndex ix, String id, String action) async {
  MovePlan? plan;
  switch (action) {
    case 'up':
      plan = moveUp(ix, id);
    case 'down':
      plan = moveDown(ix, id);
    case 'indent':
      plan = indent(ix, id);
    case 'outdent':
      plan = outdent(ix, id);
    case 'list':
      final to = await pickList(context, [for (final x in ix.listIds) ix.lists[x]!], ix.listOf(id));
      if (to == null || !context.mounted) return true;
      plan = moveToList(ix, id, to.isEmpty ? null : to);
    default:
      return false;
  }
  if (plan != null && context.mounted) await runMove(context, ref, plan);
  return true;
}

class _ListHeader extends ConsumerWidget {
  const _ListHeader({required this.ix, required this.row});
  final OverviewIndex ix;
  final ListRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = row.list;
    return _frame(
      context,
      indent: 0,
      colour: list.colorIndex,
      child: ListTile(
        key: ValueKey('list-${list.id}'),
        contentPadding: const EdgeInsetsDirectional.only(start: 0, end: 8),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          const _Handle(),
          _toggle(context, ref, list.id, list.title, show: row.itemCount > 0, collapsed: row.collapsed),
          Icon(Icons.folder_outlined, color: itemColorOf(context, list.colorIndex)),
        ]),
        title: Semantics(
          header: true,
          // Dogfooding O3: the size of its rows, bolder (never smaller).
          child: Text(list.title,
              style: (ListTileTheme.of(context).titleTextStyle ?? Theme.of(context).textTheme.bodyLarge)
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(l.ovItemCount(row.itemCount), style: Theme.of(context).textTheme.bodySmall),
          PopupMenuButton<String>(
            tooltip: l.actionsForTitle(list.title),
            onSelected: (a) => _onAction(context, ref, a),
            itemBuilder: (context) => [
              _item('task', l.ovAddTask),
              _item('event', l.ovAddEvent),
              _item('rename', l.ovRename),
              _item('colour', l.ovColour),
              ..._moveItems(context, ix, list.id),
              _item('trash', l.moveToTrash),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String a) async {
    final l = context.l10n;
    final list = row.list;
    final s = ref.read(overviewServiceProvider);
    if (await _onMoveAction(context, ref, ix, list.id, a) || !context.mounted) return;
    switch (a) {
      case 'task':
        final id = await addTaskWithDialog(context, ref, null, listId: list.id);
        if (id != null) ref.read(collapsedItemsProvider.notifier).expand(list.id);
      case 'event':
        ref.read(collapsedItemsProvider.notifier).expand(list.id);
        await openEventEditor(context, ref, listId: list.id);
      case 'rename':
        final title = await showTextDialog(context, title: l.ovRenameList, initial: list.title, confirmLabel: l.save);
        if (title == null || !context.mounted) return;
        await reportResult(context, s.renameList(list.id, title));
      case 'colour':
        final c = await pickColour(context, list.colorIndex);
        if (c == null || !context.mounted) return;
        await reportResult(context, s.setListColor(list.id, c.index));
      case 'trash':
        final r = await reportResult(context, s.trashList(list.id));
        if (r is CommandOk && context.mounted) {
          showMessage(context, l.ovListTrashed(list.title),
              action: SnackBarAction(label: l.undo, onPressed: () => s.restoreList(list.id)));
        }
    }
  }
}

class _LooseHeader extends StatelessWidget {
  const _LooseHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
        child: Semantics(
          header: true,
          child: Text(context.l10n.ovNotInAList, style: Theme.of(context).textTheme.labelLarge),
        ),
      );
}

class _TaskItem extends ConsumerWidget {
  const _TaskItem({required this.ix, required this.row, required this.onAddSubtask});
  final OverviewIndex ix;
  final TaskItemRow row;
  final Future<void> Function(String parentId) onAddSubtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = row.task;
    // P03 D8: with automatic completion the box shows the derived state of
    // a one-off task and is never ticked by hand.
    final tracked = ref.watch(trackedProvider).valueOrNull?[t.id];
    final auto = tracked != null && tracked.completion == CompletionMode.automatic;
    final period = tracked == null ? null : currentPeriodLine(tracked);
    final schedule = t.schedule == null
        ? null
        : describeSchedule(t.schedule!, today: ref.watch(todayProvider)(), deviceZone: ref.watch(deviceZoneProvider));
    final meta = [if (schedule != null) schedule, if (period != null) period];
    return _frame(
      context,
      indent: row.indent,
      colour: t.colorIndex,
      child: ListTile(
        key: ValueKey('task-${t.id}'),
        contentPadding: const EdgeInsetsDirectional.only(start: 0, end: 8),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          const _Handle(),
          _toggle(context, ref, t.id, t.title, show: row.hasChildren, collapsed: row.collapsed),
          auto
              ? Checkbox(
                  value: tracked.isRepeating ? false : tracked.isCompleteNow,
                  semanticLabel: l.ovDoneFromMeasurements(t.title),
                  onChanged: null,
                )
              : Checkbox(
                  value: t.isDone,
                  semanticLabel: t.isDone ? l.ovMarkNotDone(t.title) : l.ovComplete(t.title),
                  // Unchecking a done task reopens it (a completion can be undone).
                  onChanged: (_) => t.isDone
                      ? reportResult(context, ref.read(taskServiceProvider).reopen(t.id))
                      : completeTask(context, ref, row.row),
                ),
        ]),
        title: Text(
          t.title,
          style: t.isDone ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        // Dogfooding O4: a tap opens the task's page.
        onTap: () => openTaskPage(context, t.id),
        subtitle: meta.isEmpty
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (schedule != null) Text(schedule, key: ValueKey('schedule-${t.id}')),
                  if (period != null) Text(period, key: ValueKey('period-${t.id}')),
                ],
              ),
        trailing: PopupMenuButton<String>(
          tooltip: l.actionsForTitle(t.title),
          onSelected: (a) => _onAction(context, ref, a),
          itemBuilder: (context) => [
            if (!t.isDone) _item('focus', l.ovFocus),
            _item('rename', l.ovRename),
            _item('schedule', l.ovSchedule),
            _item('tracking', l.ovHabitAndTarget),
            _item('goals', l.ovGoals),
            if (ix.levelOf(t.id) < maxTaskLevel) _item('subtask', l.ovAddSubtask),
            _item('colour', l.ovColour),
            ..._moveItems(context, ix, t.id),
            _item('trash', l.moveToTrash),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String a) async {
    final l = context.l10n;
    final t = row.task;
    if (await _onMoveAction(context, ref, ix, t.id, a) || !context.mounted) return;
    switch (a) {
      case 'focus':
        await startFocus(context, ref, taskId: t.id, taskTitle: t.title);
      case 'rename':
        final title = await showTextDialog(context, title: l.ovRenameTask, initial: t.title, confirmLabel: l.save);
        if (title == null || !context.mounted) return;
        await reportResult(context, ref.read(taskServiceProvider).rename(t.id, title));
      case 'schedule':
        await openScheduleEditor(context, ref, taskId: t.id, title: t.title, initial: t.schedule);
      case 'tracking':
        await openHabitPage(context, taskId: t.id, title: t.title);
      case 'goals':
        await showGoalsOfTask(context, ref, taskId: t.id, title: t.title);
      case 'subtask':
        ref.read(collapsedItemsProvider.notifier).expand(t.id);
        await onAddSubtask(t.id);
      case 'colour':
        final c = await pickColour(context, t.colorIndex);
        if (c == null || !context.mounted) return;
        await reportResult(context, ref.read(overviewServiceProvider).setTaskColor(t.id, c.index));
      case 'trash':
        await trashTask(context, ref, row.row);
    }
  }
}

class _EventItem extends ConsumerWidget {
  const _EventItem({required this.ix, required this.row});
  final OverviewIndex ix;
  final EventItemRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = row.event;
    final when = e.schedule == null
        ? null
        : describeSchedule(e.schedule!, today: ref.watch(todayProvider)(), deviceZone: ref.watch(deviceZoneProvider));
    return _frame(
      context,
      indent: row.indent,
      colour: e.colorIndex,
      child: ListTile(
        key: ValueKey('event-${e.id}'),
        contentPadding: const EdgeInsetsDirectional.only(start: 0, end: 8),
        leading: Row(mainAxisSize: MainAxisSize.min, children: [
          const _Handle(),
          const SizedBox(width: 32),
          Semantics(
            label: l.ovEventLabel(e.title),
            excludeSemantics: true,
            child: const SizedBox(width: 40, child: Icon(Icons.event_outlined)),
          ),
        ]),
        title: Text(
          e.title,
          style: e.isCancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: when == null ? null : Text(when),
        onTap: () => openEventEditor(context, ref, eventId: e.id),
        trailing: PopupMenuButton<String>(
          tooltip: l.actionsForTitle(e.title),
          onSelected: (a) => _onAction(context, ref, a),
          itemBuilder: (context) => [
            _item('edit', l.edit),
            _item('colour', l.ovColour),
            ..._moveItems(context, ix, e.id),
            _item('trash', l.moveToTrash),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String a) async {
    final l = context.l10n;
    final e = row.event;
    if (await _onMoveAction(context, ref, ix, e.id, a) || !context.mounted) return;
    switch (a) {
      case 'edit':
        await openEventEditor(context, ref, eventId: e.id);
      case 'colour':
        final c = await pickColour(context, e.colorIndex);
        if (c == null || !context.mounted) return;
        await reportResult(context, ref.read(overviewServiceProvider).setEventColor(e.id, c.index));
      case 'trash':
        final events = ref.read(eventServiceProvider);
        final r = await reportResult(context, events.trash(e.id));
        if (r is CommandOk && context.mounted) {
          showMessage(context, l.eventMovedToTheTrash,
              action: SnackBarAction(label: l.undo, onPressed: () => events.restore(e.id)));
        }
    }
  }
}
