import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages.dart';
import '../providers.dart';
import '../task_tree.dart';

enum _RowAction { rename, addSubtask, trash }

enum _CompleteChoice { withSubtasks, onlyThis }

/// Task list for the active profile. All writes go through [TaskService]
/// (the command gateway); this widget holds no domain state (AP-12).
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => _add(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: tasks.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading tasks'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load tasks.',
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          final rows = orderTree(list);
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) => _TaskTile(row: rows[i]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No tasks yet. Use the + button to add your first one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.row});
  final TaskRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = row.task;
    return ListTile(
      key: ValueKey('task-${t.id}'),
      contentPadding:
          EdgeInsetsDirectional.only(start: 16 + row.depth * 24.0, end: 8),
      leading: Checkbox(
        value: t.isDone,
        semanticLabel: t.isDone ? 'Completed: ${t.title}' : 'Complete ${t.title}',
        onChanged: t.isDone ? null : (_) => _complete(context, ref, row),
      ),
      title: Text(
        t.title,
        style: t.isDone
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      trailing: PopupMenuButton<_RowAction>(
        tooltip: 'Actions for ${t.title}',
        onSelected: (a) => _onAction(context, ref, a),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _RowAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _RowAction.addSubtask, child: Text('Add subtask')),
          PopupMenuItem(value: _RowAction.trash, child: Text('Move to trash')),
        ],
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, _RowAction a) async {
    final t = row.task;
    switch (a) {
      case _RowAction.rename:
        final title = await showTextDialog(context,
            title: 'Rename task', initial: t.title, confirmLabel: 'Save');
        if (title == null || !context.mounted) return;
        await _report(context, ref.read(taskServiceProvider).rename(t.id, title));
      case _RowAction.addSubtask:
        await _add(context, ref, t.id);
      case _RowAction.trash:
        await _report(context, ref.read(taskServiceProvider).trash(t.id));
    }
  }
}

Future<void> _add(BuildContext context, WidgetRef ref, String? parentId) async {
  final title = await showTextDialog(context,
      title: parentId == null ? 'New task' : 'New subtask',
      confirmLabel: 'Add');
  if (title == null || !context.mounted) return;
  await _report(
      context, ref.read(taskServiceProvider).create(title, parentId: parentId));
}

/// OQ-R3: with open subtasks the user chooses between the two commands.
Future<void> _complete(BuildContext context, WidgetRef ref, TaskRow row) async {
  var withDescendants = false;
  if (row.hasOpenChildren) {
    final choice = await showDialog<_CompleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('This task has open subtasks'),
        content: const Text('Complete the subtasks too, or only this task?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _CompleteChoice.onlyThis),
              child: const Text('Only this task')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, _CompleteChoice.withSubtasks),
              child: const Text('With subtasks')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    withDescendants = choice == _CompleteChoice.withSubtasks;
  }
  await _report(
    context,
    ref
        .read(taskServiceProvider)
        .complete(row.task.id, withDescendants: withDescendants),
  );
}

/// Shows a failure as a snackbar; success needs no message (the list updates).
Future<void> _report(BuildContext context, Future<CommandResult> pending) async {
  final result = await pending;
  if (result is CommandFailure && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(describeFailure(result))));
  }
}

/// Small single-field dialog. Returns the trimmed text, or null if cancelled
/// or empty.
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  required String confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(
        title: title, initial: initial, confirmLabel: confirmLabel),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });
  final String title;
  final String initial;
  final String confirmLabel;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    Navigator.pop(context, v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _c,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      );
}
