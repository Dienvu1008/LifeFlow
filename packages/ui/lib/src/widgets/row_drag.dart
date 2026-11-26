// Dogfooding O1/O2 (ADR-0051), shared since P06b W5: dragging a row of a
// list (the Overview's items, the documents tree). The handle at the start
// of a row (hidden by the setting), a long press on the row (on touch, and
// where the handles are hidden), and the dragged copy: the whole row at its
// width, raised, kept where it was under the pointer. Where it lands is the
// list's own (its drop targets).
import 'package:application/application.dart' show DragHandles;
import 'package:flutter/material.dart';

import '../l10n.dart';
import '../theme/lifeflow_theme.dart' show isPointerPlatform;

/// Whether rows show their drag handle for [setting] on this platform.
bool showDragHandles(BuildContext context, DragHandles setting) => switch (setting) {
      DragHandles.always => true,
      DragHandles.never => false,
      DragHandles.auto => isPointerPlatform(Theme.of(context).platform),
    };

/// Whether drag handles are shown (dogfooding O1: the setting); also given to
/// the dragged copy so it looks like its row.
class DragHandlesScope extends InheritedWidget {
  const DragHandlesScope({super.key, required this.show, required super.child});
  final bool show;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DragHandlesScope>()?.show ?? true;

  @override
  bool updateShouldNotify(DragHandlesScope old) => old.show != show;
}

/// Lets the row's handle (and a long press on the row) start a drag of [id].
class RowDragScope extends InheritedWidget {
  const RowDragScope({
    super.key,
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

  static RowDragScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RowDragScope>();

  @override
  bool updateShouldNotify(RowDragScope old) => old.id != id || old.title != title || old.preview != preview;
}

/// The dragged copy: the whole row at its width, a little transparent, raised.
/// Built when the drag starts (in the overlay), so the row is laid out.
Widget rowDragFeedback(BuildContext context, RowDragScope scope) =>
    _DragCopy(scope: scope, handles: DragHandlesScope.of(context));

class _DragCopy extends StatelessWidget {
  const _DragCopy({required this.scope, required this.handles});
  final RowDragScope scope;
  final bool handles;

  @override
  Widget build(BuildContext context) {
    final box = scope.rowBox();
    final width = box != null && box.hasSize ? box.size.width : 320.0;
    return DragHandlesScope(
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
DragAnchorStrategy rowDragAnchor(RowDragScope scope) => (draggable, context, position) {
      final box = scope.rowBox();
      return box == null || !box.hasSize ? Offset.zero : box.globalToLocal(position);
    };

/// The drag handle at the start of a row (hidden by the setting, O1).
class RowDragHandle extends StatelessWidget {
  const RowDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    if (!DragHandlesScope.of(context)) return const SizedBox.shrink();
    final scope = RowDragScope.of(context);
    if (scope == null) return const SizedBox(width: 24);
    return Draggable<String>(
      data: scope.id,
      dragAnchorStrategy: rowDragAnchor(scope),
      feedback: rowDragFeedback(context, scope),
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
Widget longPressRowDrag(BuildContext context, Widget child) {
  final scope = RowDragScope.of(context);
  if (scope == null || (isPointerPlatform(Theme.of(context).platform) && DragHandlesScope.of(context))) return child;
  return LongPressDraggable<String>(
    data: scope.id,
    dragAnchorStrategy: rowDragAnchor(scope),
    feedback: rowDragFeedback(context, scope),
    onDragStarted: scope.onStart,
    onDragEnd: (_) => scope.onEnd(),
    child: child,
  );
}

