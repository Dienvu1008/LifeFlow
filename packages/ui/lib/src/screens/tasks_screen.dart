import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foundation/foundation.dart';

import '../messages.dart';
import '../providers.dart';
import '../schedule_text.dart';
import '../task_tree.dart';
import 'schedule_editor.dart';

enum _RowAction { rename, schedule, addSubtask, trash }

enum _AgendaAction { skip, move, undoChange, schedule }

enum _CompleteChoice { withSubtasks, onlyThis }

/// Typical height of one row (one-line ListTile); only an estimate used to
/// get close to a row that is not built yet.
const _rowExtent = 56.0;

/// Space kept free under the last row so the + button never covers it.
const _fabClearance = 96.0;

/// Task list for the active profile. All writes go through [TaskService]
/// (the command gateway); this widget holds no domain state (AP-12).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _scroll = ScrollController();

  /// A task just added here; scrolled into view once the list shows it.
  String? _revealId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _addTask(String? parentId) async {
    final id = await _add(context, ref, parentId);
    if (id == null || !mounted) return;
    // A task added in Today or Upcoming is planned there, so it does not
    // vanish from the list it was added to.
    final filter = ref.read(taskFilterProvider);
    if (parentId == null && filter != TaskFilter.all) {
      final today = ref.read(todayProvider)();
      final day = filter == TaskFilter.today ? today : today.addDays(1);
      await _report(
          context,
          ref.read(taskSchedulingProvider).setSchedule(
              id, TaskScheduleInput(start: SchedulePointInput.date(day))));
      return;
    }
    setState(() => _revealId = id);
  }

  /// Attached to the row being revealed, so it can be scrolled into view
  /// precisely once it is built.
  final _revealKey = GlobalKey();
  String? _revealing;

  /// Scrolls so the row at [index] is visible (owner report: a new task was
  /// added below the visible part of the list and looked lost). Rows have no
  /// fixed height (large text), so: jump near it by estimate, then align on
  /// the real row.
  void _reveal(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      if (_revealKey.currentContext == null) {
        final pos = _scroll.position;
        final estimate = index * _rowExtent - pos.viewportDimension / 2;
        _scroll.jumpTo(estimate.clamp(0.0, pos.maxScrollExtent));
        await WidgetsBinding.instance.endOfFrame;
      }
      final ctx = _revealKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx,
            alignment: 0.5, duration: const Duration(milliseconds: 250));
      }
      if (mounted) setState(() => _revealing = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LayoutBuilder(builder: (context, box) {
              // Icons only when there is room: with a phone width and a
              // large system font the labels must stay on one line.
              final icons = box.maxWidth / MediaQuery.textScalerOf(context).scale(1) >= 440;
              Widget label(String s) => Text(s, maxLines: 1, softWrap: false, overflow: TextOverflow.fade);
              return SegmentedButton<TaskFilter>(
                key: const Key('task-filter'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: TaskFilter.all, label: label('All'), icon: icons ? const Icon(Icons.list) : null),
                  ButtonSegment(
                      value: TaskFilter.today,
                      label: label('Today'),
                      icon: icons ? const Icon(Icons.today) : null),
                  ButtonSegment(
                      value: TaskFilter.upcoming,
                      label: label('Upcoming'),
                      icon: icons ? const Icon(Icons.date_range) : null),
                ],
                selected: {filter},
                onSelectionChanged: (s) => ref.read(taskFilterProvider.notifier).state = s.first,
              );
            }),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => _addTask(null),
        child: const Icon(Icons.add),
      ),
      body: switch (filter) {
        TaskFilter.all => _allTasks(context),
        TaskFilter.today => const _AgendaList(upcoming: false),
        TaskFilter.upcoming => const _AgendaList(upcoming: true),
      },
    );
  }

  Widget _allTasks(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return tasks.when(
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
          final reveal = _revealId;
          if (reveal != null) {
            final i = rows.indexWhere((r) => r.task.id == reveal);
            if (i >= 0) {
              _revealId = null;
              _revealing = reveal;
              _reveal(i);
            }
          }
          return ListView.builder(
            key: const Key('task-list'),
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: _fabClearance),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final tile = _TaskTile(row: rows[i], onAddSubtask: _addTask);
              return rows[i].task.id == _revealing
                  ? KeyedSubtree(key: _revealKey, child: tile)
                  : tile;
            },
          );
        },
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

/// Today or Upcoming: occurrences of scheduled tasks, grouped by date
/// (owner decision D9). Today puts overdue one-off tasks first.
class _AgendaList extends ConsumerWidget {
  const _AgendaList({required this.upcoming});
  final bool upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(upcoming ? upcomingAgendaProvider : todayAgendaProvider);
    final today = ref.watch(todayProvider)();
    // For the open-subtasks question and the editor's current schedule.
    final rows = {for (final r in orderTree(ref.watch(tasksProvider).value ?? const [])) r.task.id: r};
    return agenda.when(
      loading: () => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading the agenda'),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the agenda.', style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
      data: (a) {
        final children = <Widget>[
          if (a.truncated)
            Card(
              key: const Key('agenda-truncated'),
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Not everything is shown'),
                subtitle: Text('There are more items than the limit in Settings → Calendar.'),
              ),
            ),
        ];
        if (a.items.isEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              upcoming
                  ? 'Nothing planned for the next 14 days.'
                  : 'Nothing planned for today. Tasks you plan for today show up here.',
              key: const Key('agenda-empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ));
        }
        String? group;
        for (final item in a.items) {
          final g = item.isOverdue ? 'Overdue' : formatDate(item.date, today: today);
          if (g != group) {
            group = g;
            children.add(Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Semantics(
                header: true,
                child: Text(
                  item.isOverdue || upcoming ? g : '$g · ${formatDateLong(item.date, today: today)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ));
          }
          children.add(_AgendaTile(item: item, row: rows[item.taskId], today: today));
        }
        return ListView(
          key: Key(upcoming ? 'upcoming-list' : 'today-list'),
          padding: const EdgeInsets.only(bottom: _fabClearance),
          children: children,
        );
      },
    );
  }
}

class _AgendaTile extends ConsumerWidget {
  const _AgendaTile({required this.item, required this.row, required this.today});
  final AgendaItem item;
  final TaskRow? row;
  final LocalDate today;

  String _subtitle(String zone) {
    final s = item.start, e = item.end, d = item.deadline;
    final parts = <String>[
      if (item.isOverdue) 'Planned ${formatDate(item.date, today: today)}',
      if (s != null && s.isTimed)
        e != null && e.isTimed && e.date == s.date && e.zone == s.zone
            ? '${formatTimeOnly(s, deviceZone: zone)}–${e.time}'
            : formatTimeOnly(s, deviceZone: zone),
      if (s != null && e != null && e.date != s.date)
        'Until ${formatPoint(e, today: today, deviceZone: zone)}'
      else if (s == null && e != null && e.isTimed)
        'Ends ${formatTimeOnly(e, deviceZone: zone)}',
      if (d != null) 'Due ${formatPoint(d, today: today, deviceZone: zone)}',
      if (item.isRepeating) 'Repeats',
      if (item.isMoved) 'Moved',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = item;
    final subtitle = _subtitle(ref.watch(deviceZoneProvider));
    return ListTile(
      key: ValueKey('agenda-${i.taskId}@${i.originalDate}'),
      leading: Checkbox(
        value: i.isDone,
        semanticLabel: i.isDone ? 'Mark as not done: ${i.title}' : 'Complete ${i.title}',
        onChanged: (_) => _toggle(context, ref),
      ),
      title: Text(
        i.title,
        style: i.isDone ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: PopupMenuButton<_AgendaAction>(
        tooltip: 'Actions for ${i.title}',
        onSelected: (a) => _onAction(context, ref, a),
        itemBuilder: (_) => [
          if (i.isRepeating) ...[
            const PopupMenuItem(value: _AgendaAction.skip, child: Text('Skip this time')),
            const PopupMenuItem(value: _AgendaAction.move, child: Text('Move this time…')),
            if (i.isMoved)
              const PopupMenuItem(
                  value: _AgendaAction.undoChange, child: Text('Undo the change to this time')),
          ],
          PopupMenuItem(
              value: _AgendaAction.schedule,
              child: Text(i.isRepeating ? 'Edit the whole repeat…' : 'Schedule…')),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final i = item;
    // D5: a repeating task is done one occurrence at a time; it stays open.
    if (i.isRepeating) {
      await _report(context,
          ref.read(taskSchedulingProvider).setOccurrenceDone(i.taskId, i.originalDate, done: !i.isDone));
      return;
    }
    if (i.isDone) {
      await _report(context, ref.read(taskServiceProvider).reopen(i.taskId));
      return;
    }
    final r = row;
    if (r == null) {
      await _report(context, ref.read(taskServiceProvider).complete(i.taskId, withDescendants: false));
    } else {
      await _complete(context, ref, r);
    }
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, _AgendaAction a) async {
    final i = item;
    final scheduling = ref.read(taskSchedulingProvider);
    switch (a) {
      case _AgendaAction.skip:
        await _report(context, scheduling.changeOccurrence(i.taskId, i.originalDate, const SkipThisOccurrence()));
      case _AgendaAction.move:
        final d = i.date;
        final picked = await showDatePicker(
          context: context,
          helpText: 'Move this time to',
          initialDate: DateTime(d.year, d.month, d.day),
          firstDate: DateTime(1900),
          lastDate: DateTime(2200, 12, 31),
        );
        if (picked == null || !context.mounted) return;
        await _report(
            context,
            scheduling.changeOccurrence(i.taskId, i.originalDate,
                MoveThisOccurrence(LocalDate(picked.year, picked.month, picked.day))));
      case _AgendaAction.undoChange:
        await _report(context, scheduling.changeOccurrence(i.taskId, i.originalDate, null));
      case _AgendaAction.schedule:
        final initial = row?.task.schedule ?? await scheduling.scheduleOf(i.taskId);
        if (!context.mounted) return;
        await openScheduleEditor(context, ref, taskId: i.taskId, title: i.title, initial: initial);
    }
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.row, required this.onAddSubtask});
  final TaskRow row;
  final Future<void> Function(String parentId) onAddSubtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = row.task;
    return ListTile(
      key: ValueKey('task-${t.id}'),
      contentPadding:
          EdgeInsetsDirectional.only(start: 16 + row.depth * 24.0, end: 8),
      leading: Checkbox(
        value: t.isDone,
        semanticLabel:
            t.isDone ? 'Mark as not done: ${t.title}' : 'Complete ${t.title}',
        // Unchecking a done task reopens it (a completion can be undone).
        onChanged: (_) => t.isDone
            ? _report(context, ref.read(taskServiceProvider).reopen(t.id))
            : _complete(context, ref, row),
      ),
      title: Text(
        t.title,
        style: t.isDone
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: t.schedule == null
          ? null
          : Text(
              describeSchedule(t.schedule!,
                  today: ref.watch(todayProvider)(),
                  deviceZone: ref.watch(deviceZoneProvider)),
              key: ValueKey('schedule-${t.id}'),
            ),
      trailing: PopupMenuButton<_RowAction>(
        tooltip: 'Actions for ${t.title}',
        onSelected: (a) => _onAction(context, ref, a),
        itemBuilder: (_) => const [
          PopupMenuItem(value: _RowAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _RowAction.schedule, child: Text('Schedule…')),
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
      case _RowAction.schedule:
        await openScheduleEditor(context, ref,
            taskId: t.id, title: t.title, initial: t.schedule);
      case _RowAction.addSubtask:
        await onAddSubtask(t.id);
      case _RowAction.trash:
        await _trash(context, ref, row);
    }
  }
}

/// Returns the new task's id, or null when cancelled or refused.
Future<String?> _add(BuildContext context, WidgetRef ref, String? parentId) async {
  final title = await showTextDialog(context,
      title: parentId == null ? 'New task' : 'New subtask',
      confirmLabel: 'Add');
  if (title == null || !context.mounted) return null;
  final result =
      await ref.read(taskServiceProvider).create(title, parentId: parentId);
  if (!context.mounted) return null;
  if (result is CommandFailure) {
    _show(context, describeFailure(result));
    return null;
  }
  return (result as CommandOk).entityId;
}

/// Moving a task with subtasks to the trash follows the device setting
/// (Settings): ask, always with subtasks, or keep them (they move up a level).
Future<void> _trash(BuildContext context, WidgetRef ref, TaskRow row) async {
  final service = ref.read(taskServiceProvider);
  if (row.subtaskCount == 0) {
    await _report(context, service.trash(row.task.id));
    return;
  }
  var policy = SubtaskTrashPolicy.ask;
  try {
    policy = await ref.read(settingsServiceProvider).subtaskTrashPolicy();
  } catch (_) {
    // No setting available: ask.
  }
  if (!context.mounted) return;
  final bool withSubtasks;
  switch (policy) {
    case SubtaskTrashPolicy.withSubtasks:
      withSubtasks = true;
    case SubtaskTrashPolicy.keepSubtasks:
      withSubtasks = false;
    case SubtaskTrashPolicy.ask:
      final answer = await showDialog<(bool, bool)>(
          context: context,
          builder: (_) => _TrashDialog(
              title: row.task.title, subtasks: row.subtaskCount));
      if (answer == null || !context.mounted) return;
      final (all, remember) = answer;
      withSubtasks = all;
      if (remember) {
        await ref.read(settingsServiceProvider).setSubtaskTrashPolicy(all
            ? SubtaskTrashPolicy.withSubtasks
            : SubtaskTrashPolicy.keepSubtasks);
        ref.invalidate(subtaskTrashPolicyProvider);
        if (!context.mounted) return;
      }
  }
  await _report(context, service.trash(row.task.id, withSubtasks: withSubtasks));
}

/// Asks what to do with the subtasks. Pops (withSubtasks, remember).
class _TrashDialog extends StatefulWidget {
  const _TrashDialog({required this.title, required this.subtasks});
  final String title;
  final int subtasks;
  @override
  State<_TrashDialog> createState() => _TrashDialogState();
}

class _TrashDialogState extends State<_TrashDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.subtasks;
    final s = n == 1 ? 'subtask' : 'subtasks';
    return AlertDialog(
      key: const Key('trash-choice'),
      title: Text('Move "${widget.title}" to the trash?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n == 1
              ? 'It has 1 subtask. Move it to the trash too, or keep it? '
                  'A kept subtask moves up one level.'
              : 'It has $n subtasks. Move them to the trash too, or keep '
                  'them? Kept subtasks move up one level.'),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('trash-remember'),
            contentPadding: EdgeInsets.zero,
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            title: const Text('Remember my choice'),
            subtitle: const Text('You can change this in Settings.'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(context, (false, _remember)),
            child: Text('Keep $s')),
        FilledButton(
            onPressed: () => Navigator.pop(context, (true, _remember)),
            child: Text('Trash $s too')),
      ],
    );
  }
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
    _show(context, describeFailure(result));
  }
}

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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
