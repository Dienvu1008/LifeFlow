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

/// "Focus" for an app bar: open the running session, or start one without
/// a task (D12).
Widget _focusAction(BuildContext context, WidgetRef ref) => IconButton(
      key: const Key('focus-open'),
      tooltip: context.l10n.focus,
      icon: const Icon(Icons.timer_outlined),
      onPressed: () =>
          ref.read(activeFocusProvider).valueOrNull != null ? openFocusPage(context) : startFocus(context, ref),
    );

/// P03 UX U3/U6 (ADR-0047, ADR-0050): the Overview destination. All writes
/// go through the ports (the command gateway); this widget holds no domain
/// state (AP-12).
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  /// A task just added; scrolled into view once it shows.
  String? _revealId;

  Future<void> _addTask(String? parentId) async {
    final id = await addTaskWithDialog(context, ref, parentId);
    if (id == null || !mounted) return;
    setState(() => _revealId = id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: shellMenuButton(context),
          title: Text(context.l10n.navOverview),
          actions: [_focusAction(context, ref)],
        ),
        floatingActionButton: OverviewAddButton(
          onTask: () => _addTask(null),
          onList: () => addList(context, ref),
          onEvent: () => openEventEditor(context, ref),
        ),
        body: OverviewView(
          revealId: _revealId,
          onRevealed: () => _revealId = null,
          onAddSubtask: _addTask,
        ),
      );
}

/// P03 UX U4/U6 (ADR-0048, ADR-0050): the Timeline destination. No Focus
/// and no "+" here (dogfooding T1): items are added in the Overview or the
/// Calendar.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          leading: shellMenuButton(context),
          title: const TimelineTitle(),
          actions: const [TimelineTodayButton()],
        ),
        body: const TimelineView(),
      );
}
/// P03 UX U6 (U-D2, ADR-0050): Habits is a destination of its own.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          leading: shellMenuButton(context),
          title: Text(context.l10n.navHabits),
          actions: [_focusAction(context, ref)],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'fab-habits',
          tooltip: context.l10n.habitsAdd,
          onPressed: () async {
            final id = await addTaskWithDialog(context, ref, null, title: context.l10n.habitsNew);
            if (id == null || !context.mounted) return;
            // D6a: a new habit repeats every day from today; both can be
            // changed later.
            final today = ref.read(todayProvider)();
            final made = await reportResult(context, ref.read(habitServiceProvider).setHabit(id, isHabit: true));
            if (made is CommandFailure || !context.mounted) return;
            await reportResult(
                context,
                ref.read(taskSchedulingProvider).setSchedule(
                    id,
                    TaskScheduleInput(
                        start: SchedulePointInput.date(today), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
          },
          child: const Icon(Icons.add),
        ),
        body: const _HabitList(),
      );
}

/// P03 T6a: the habits of the profile, each with its running period and
/// statistics (D6b). Tapping opens the habit.
class _HabitList extends ConsumerWidget {
  const _HabitList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final habits = ref.watch(habitsProvider);
    return habits.when(
      loading: () => Center(child: CircularProgressIndicator(semanticsLabel: l.habitsLoading)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.habitsLoadError, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.habitsEmpty,
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
                  if (!h.isRepeating) l.habitsNoRepeat,
                  statsLine(h),
                ].join('\n')),
                isThreeLine: currentPeriodLine(h) != null || !h.isRepeating,
                onTap: () => openHabitPage(context, taskId: h.taskId, title: h.title),
                trailing: h.target != null && h.current != null
                    ? IconButton(
                        key: ValueKey('habit-measure-${h.taskId}'),
                        tooltip: l.habitsAddMeasurement(h.title),
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
Future<String?> addTaskWithDialog(BuildContext context, WidgetRef ref, String? parentId,
    {String? listId, String? title}) async {
  final name = await showTextDialog(context,
      title: title ?? (parentId == null ? 'New task' : 'New subtask'),
      confirmLabel: 'Add');
  if (name == null || !context.mounted) return null;
  final result =
      await ref.read(taskServiceProvider).create(name, parentId: parentId, listId: listId);
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
