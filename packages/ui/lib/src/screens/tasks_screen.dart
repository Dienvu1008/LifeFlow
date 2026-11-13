import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../habit_text.dart';
import '../messages.dart';
import '../shell.dart' show shellMenuButton;
import '../providers.dart';
import '../task_actions.dart';
import '../task_tree.dart';
import 'event_editor.dart';
import 'focus_page.dart';
import 'overview_view.dart';
import 'timeline_view.dart';
import '../l10n.dart';
import 'habit_page.dart';

/// Space kept free under the last row so the + button never covers it.
const _fabClearance = 96.0;

/// The Tasks tab: the Overview (P03 UX U3), and the Today, Upcoming and
/// Habits filters until the Timeline and the Habits screen (U4, U6). All
/// writes go through the ports (the command gateway); this widget holds no
/// domain state (AP-12).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  /// A task just added in the Overview; scrolled into view once it shows.
  String? _revealId;

  Future<void> _addTask(String? parentId) async {
    final id = await addTaskWithDialog(context, ref, parentId);
    if (id == null || !mounted) return;
    // A task added in Today or Upcoming is planned there, so it does not
    // vanish from the list it was added to.
    final filter = ref.read(taskFilterProvider);
    if (parentId == null && filter == TaskFilter.habits) {
      // D6a: a habit added here repeats every day from today; both can be
      // changed later.
      final today = ref.read(todayProvider)();
      final made = await reportResult(context, ref.read(habitServiceProvider).setHabit(id, isHabit: true));
      if (made is CommandFailure || !mounted) return;
      await reportResult(
          context,
          ref.read(taskSchedulingProvider).setSchedule(id,
              TaskScheduleInput(start: SchedulePointInput.date(today), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
      return;
    }
    if (parentId == null && filter == TaskFilter.timeline) {
      // Planned on the day the Timeline shows (today unless one was chosen).
      final day = ref.read(timelineAnchorProvider) ?? ref.read(todayProvider)();
      await reportResult(
          context,
          ref.read(taskSchedulingProvider).setSchedule(
              id, TaskScheduleInput(start: SchedulePointInput.date(day))));
      return;
    }
    setState(() => _revealId = id);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterProvider);
    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: filter == TaskFilter.timeline ? const TimelineTitle() : const Text('Tasks'),
        actions: [
          if (filter == TaskFilter.timeline) const TimelineTodayButton(),
          // D12: focus without a task.
          IconButton(
            key: const Key('focus-open'),
            tooltip: 'Focus',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () => ref.read(activeFocusProvider).valueOrNull != null
                ? openFocusPage(context)
                : startFocus(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LayoutBuilder(builder: (context, box) {
              // Icons only when there is room: with a phone width and a
              // large system font the labels must stay on one line.
              final icons = box.maxWidth / MediaQuery.textScalerOf(context).scale(1) >= 560;
              Widget label(String s) => Text(s, maxLines: 1, softWrap: false, overflow: TextOverflow.fade);
              return SegmentedButton<TaskFilter>(
                key: const Key('task-filter'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: TaskFilter.all, label: label('Overview'), icon: icons ? const Icon(Icons.list) : null),
                  ButtonSegment(
                      value: TaskFilter.timeline,
                      label: label(context.l10n.tlTimeline),
                      icon: icons ? const Icon(Icons.view_timeline_outlined) : null),
                  ButtonSegment(
                      value: TaskFilter.habits,
                      label: label('Habits'),
                      icon: icons ? const Icon(Icons.track_changes) : null),
                ],
                selected: {filter},
                onSelectionChanged: (s) => ref.read(taskFilterProvider.notifier).state = s.first,
              );
            }),
          ),
        ),
      ),
      floatingActionButton: filter == TaskFilter.all
          ? OverviewAddButton(
              onTask: () => _addTask(null),
              onList: () => addList(context, ref),
              onEvent: () => openEventEditor(context, ref),
            )
          : FloatingActionButton(
              heroTag: 'fab-tasks',
              tooltip: 'Add task',
              onPressed: () => _addTask(null),
              child: const Icon(Icons.add),
            ),
      body: switch (filter) {
        TaskFilter.all => OverviewView(
            revealId: _revealId,
            onRevealed: () => _revealId = null,
            onAddSubtask: _addTask,
          ),
        TaskFilter.timeline => const TimelineView(),
        TaskFilter.habits => const _HabitList(),
      },
    );
  }
}
/// P03 T6a: the habits of the profile (D12: the 4th filter of Tasks), each
/// with its running period and statistics (D6b). Tapping opens the habit.
class _HabitList extends ConsumerWidget {
  const _HabitList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    return habits.when(
      loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading habits')),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load the habits.', style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No habits yet. Add one with +, or open a task\'s menu and choose "Habit and target…".',
                key: const Key('habits-empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return ListView(
          key: const Key('habit-list'),
          padding: const EdgeInsets.only(bottom: _fabClearance),
          children: [
            for (final h in list)
              ListTile(
                key: ValueKey('habit-${h.taskId}'),
                leading: Icon(h.target == null ? Icons.check_circle_outline : Icons.trending_up),
                title: Text(h.title),
                subtitle: Text([
                  if (currentPeriodLine(h) case final line?) line,
                  if (!h.isRepeating) 'No repeat',
                  statsLine(h),
                ].join('\n')),
                isThreeLine: currentPeriodLine(h) != null || !h.isRepeating,
                onTap: () => openHabitPage(context, taskId: h.taskId, title: h.title),
                trailing: h.target != null && h.current != null
                    ? IconButton(
                        key: ValueKey('habit-measure-${h.taskId}'),
                        tooltip: 'Add a measurement for ${h.title}',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => addMeasurement(context, ref, h),
                      )
                    : null,
              ),
          ],
        );
      },
    );
  }
}

/// Returns the new task's id, or null when cancelled or refused.
Future<String?> addTaskWithDialog(BuildContext context, WidgetRef ref, String? parentId, {String? listId}) async {
  final title = await showTextDialog(context,
      title: parentId == null ? 'New task' : 'New subtask',
      confirmLabel: 'Add');
  if (title == null || !context.mounted) return null;
  final result =
      await ref.read(taskServiceProvider).create(title, parentId: parentId, listId: listId);
  if (!context.mounted) return null;
  if (result is CommandFailure) {
    showMessage(context, describeFailure(result));
    return null;
  }
  return (result as CommandOk).entityId;
}

/// Moving a task with subtasks to the trash follows the device setting
/// (Settings): ask, always with subtasks, or keep them (they move up a level).
Future<void> trashTask(BuildContext context, WidgetRef ref, TaskRow row) async {
  final service = ref.read(taskServiceProvider);
  if (row.subtaskCount == 0) {
    await reportResult(context, service.trash(row.task.id));
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
  await reportResult(context, service.trash(row.task.id, withSubtasks: withSubtasks));
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
