// P03 T6c (ADR-0043): goals and projects in the UI (owner decisions D11, D12).
//   GoalsScreen   the 5th tab: active (with done), archived, trash
//   GoalPage      one goal: details, status, progress, milestones (by hand),
//                 linked tasks, habits and events
//   showGoalsOfTask  "Goals…" of a task: what it is part of, link / unlink
// Progress comes from GoalView (derived below the port, LF-INV-GOAL-001);
// nothing here computes it (AP-12).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../habit_text.dart' show formatRate;
import '../messages.dart';
import '../shell.dart' show shellMenuButton;
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import 'schedule_editor.dart' show EditorSection;

enum _GoalList { active, archived, trash }

String goalKindLabel(GoalKindInput k) => k == GoalKindInput.goal ? 'Goal' : 'Project';

String goalStateLabel(GoalState s) => switch (s) {
      GoalState.active => 'Active',
      GoalState.done => 'Done',
      GoalState.archived => 'Archived',
    };

/// "60% · 3 of 5 milestones", "50% · from linked tasks", "No progress yet".
String progressText(GoalView g) {
  final p = g.progress;
  if (p == null) return 'No progress yet';
  final pct = '${(p * 100).round()}%';
  return switch (g.progressBasis) {
    GoalProgressBasis.milestones =>
      '$pct · ${g.milestones.where((m) => m.isCompleted).length} of ${g.milestones.length} milestones',
    GoalProgressBasis.links => '$pct · from linked tasks and habits',
    GoalProgressBasis.none => pct,
  };
}

Future<void> openGoalPage(BuildContext context, String goalId) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => GoalPage(goalId: goalId)));

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});
  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  var _list = _GoalList.active;

  Future<void> _create() async {
    final input = await showDialog<_GoalInput>(context: context, builder: (_) => const _GoalDialog());
    if (input == null || !mounted) return;
    final r = await ref.read(goalServiceProvider).create(
        kind: input.kind,
        title: input.title,
        description: input.description,
        startDate: input.startDate,
        targetDate: input.targetDate);
    if (!mounted) return;
    if (r is CommandFailure) {
      showMessage(context, describeFailure(r));
      return;
    }
    await openGoalPage(context, (r as CommandOk).entityId);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider)();
    final AsyncValue<List<GoalView>> goals = switch (_list) {
      _GoalList.active => ref.watch(goalsProvider(false)),
      _GoalList.archived =>
        ref.watch(goalsProvider(true)).whenData((l) => [for (final g in l) if (g.status == GoalState.archived) g]),
      _GoalList.trash => ref.watch(trashedGoalsProvider),
    };
    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: const Text('Goals'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<_GoalList>(
              key: const Key('goal-filter'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _GoalList.active, label: Text('Active')),
                ButtonSegment(value: _GoalList.archived, label: Text('Archived')),
                ButtonSegment(value: _GoalList.trash, label: Text('Trash')),
              ],
              selected: {_list},
              onSelectionChanged: (s) {
                setState(() => _list = s.first);
                if (s.first == _GoalList.trash) ref.invalidate(trashedGoalsProvider);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-goals',
        tooltip: 'New goal or project',
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading goals')),
        error: (e, _) => const Center(child: Text('Could not load the goals.')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  switch (_list) {
                    _GoalList.active => 'No goals yet. Add a goal or a project with +, then link tasks and habits to it.',
                    _GoalList.archived => 'No archived goals.',
                    _GoalList.trash => 'The trash is empty.',
                  },
                  key: const Key('goals-empty'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView(
            key: const Key('goal-list'),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final g in list)
                _list == _GoalList.trash
                    ? ListTile(
                        key: ValueKey('goal-${g.id}'),
                        leading: Icon(g.kind == GoalKindInput.goal ? Icons.flag_outlined : Icons.work_outline),
                        title: Text(g.title),
                        subtitle: Text(goalKindLabel(g.kind)),
                        trailing: TextButton(
                          key: ValueKey('goal-restore-${g.id}'),
                          onPressed: () async {
                            await reportResult(context, ref.read(goalServiceProvider).restore(g.id));
                            ref.invalidate(trashedGoalsProvider);
                          },
                          child: const Text('Restore'),
                        ),
                      )
                    : _GoalTile(goal: g, today: today),
            ],
          );
        },
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.today});
  final GoalView goal;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return ListTile(
      key: ValueKey('goal-${g.id}'),
      leading: Icon(g.kind == GoalKindInput.goal ? Icons.flag_outlined : Icons.work_outline),
      title: Text(g.title, style: g.status == GoalState.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text([
          goalKindLabel(g.kind),
          if (g.status != GoalState.active) goalStateLabel(g.status),
          if (g.targetDate != null) 'by ${formatDate(g.targetDate!, today: today)}',
        ].join(' · ')),
        const SizedBox(height: 4),
        _ProgressBar(goal: g),
      ]),
      onTap: () => openGoalPage(context, g.id),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.goal});
  final GoalView goal;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Progress: ${progressText(goal)}',
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LinearProgressIndicator(value: goal.progress ?? 0, minHeight: 6),
          const SizedBox(height: 2),
          Text(progressText(goal), key: ValueKey('progress-${goal.id}')),
        ]),
      );
}

enum _GoalAction { edit, done, reopen, archive, unarchive, trash }

class GoalPage extends ConsumerWidget {
  const GoalPage({super.key, required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider(true));
    final g = goals.valueOrNull?.where((x) => x.id == goalId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(g?.title ?? 'Goal', overflow: TextOverflow.ellipsis),
        actions: [
          if (g != null)
            PopupMenuButton<_GoalAction>(
              tooltip: 'Actions for ${g.title}',
              onSelected: (a) => _act(context, ref, g, a),
              itemBuilder: (_) => [
                if (g.status != GoalState.archived) const PopupMenuItem(value: _GoalAction.edit, child: Text('Edit…')),
                if (g.status == GoalState.active) const PopupMenuItem(value: _GoalAction.done, child: Text('Mark as done')),
                if (g.status == GoalState.done) const PopupMenuItem(value: _GoalAction.reopen, child: Text('Mark as active')),
                if (g.status != GoalState.archived) const PopupMenuItem(value: _GoalAction.archive, child: Text('Archive')),
                if (g.status == GoalState.archived) const PopupMenuItem(value: _GoalAction.unarchive, child: Text('Unarchive')),
                const PopupMenuItem(value: _GoalAction.trash, child: Text('Move to trash')),
              ],
            ),
        ],
      ),
      body: goals.isLoading && g == null
          ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading'))
          : g == null
              ? const Center(child: Text('This goal is in the trash or no longer exists.', key: Key('goal-gone')))
              : _GoalBody(goal: g),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, GoalView g, _GoalAction a) async {
    final service = ref.read(goalServiceProvider);
    switch (a) {
      case _GoalAction.edit:
        final input = await showDialog<_GoalInput>(context: context, builder: (_) => _GoalDialog(initial: g));
        if (input == null || !context.mounted) return;
        await reportResult(context,
            service.update(g.id, title: input.title, description: input.description, startDate: input.startDate, targetDate: input.targetDate));
      case _GoalAction.done:
        await reportResult(context, service.setStatus(g.id, GoalState.done));
      case _GoalAction.reopen:
      case _GoalAction.unarchive:
        await reportResult(context, service.setStatus(g.id, GoalState.active));
      case _GoalAction.archive:
        await reportResult(context, service.setStatus(g.id, GoalState.archived));
      case _GoalAction.trash:
        final r = await service.trash(g.id);
        if (!context.mounted) return;
        if (r is CommandFailure) {
          showMessage(context, describeFailure(r));
          return;
        }
        ref.invalidate(trashedGoalsProvider);
        Navigator.of(context).pop();
        // LF-INV-GOAL-002: the linked tasks and events stay.
        showMessage(context, '"${g.title}" moved to the trash. Its tasks and events are kept.');
    }
  }
}

class _GoalBody extends ConsumerWidget {
  const _GoalBody({required this.goal});
  final GoalView goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = goal;
    final today = ref.watch(todayProvider)();
    final service = ref.read(goalServiceProvider);
    final archived = g.status == GoalState.archived;
    final theme = Theme.of(context);
    return ListView(
      key: const Key('goal-page'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ListTile(
          title: Text([
            goalKindLabel(g.kind),
            goalStateLabel(g.status),
            if (g.startDate != null) 'from ${formatDate(g.startDate!, today: today)}',
            if (g.targetDate != null) 'by ${formatDate(g.targetDate!, today: today)}',
          ].join(' · ')),
          subtitle: g.description == null ? null : Text(g.description!),
        ),
        if (archived)
          const ListTile(
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('Archived: unarchive it to change it.'),
          ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _ProgressBar(goal: g)),
        if (g.progressBasis == GoalProgressBasis.milestones)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('With milestones, progress counts the milestones you have ticked.'),
          ),
        const EditorSection('Milestones'),
        if (g.milestones.isEmpty)
          const ListTile(title: Text('No milestones. Without them, progress comes from the linked tasks and habits.')),
        for (final m in g.milestones)
          CheckboxListTile(
            key: ValueKey('milestone-${m.id}'),
            controlAffinity: ListTileControlAffinity.leading,
            value: m.isCompleted,
            title: Text(m.title),
            subtitle: m.dueDate == null ? null : Text('Due ${formatDate(m.dueDate!, today: today)}'),
            onChanged: archived ? null : (v) => reportResult(context, service.setMilestoneDone(g.id, m.id, done: v == true)),
            secondary: archived
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Actions for the milestone ${m.title}',
                    onSelected: (a) async {
                      if (a == 'remove') {
                        await reportResult(context, service.removeMilestone(g.id, m.id));
                        return;
                      }
                      final input = await showDialog<_MilestoneInput>(
                          context: context, builder: (_) => _MilestoneDialog(initial: m, today: today));
                      if (input == null || !context.mounted) return;
                      await reportResult(context, service.updateMilestone(g.id, m.id, title: input.title, dueDate: input.dueDate));
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit…')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
          ),
        if (!archived)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                key: const Key('milestone-add'),
                onPressed: () async {
                  final input = await showDialog<_MilestoneInput>(context: context, builder: (_) => _MilestoneDialog(today: today));
                  if (input == null || !context.mounted) return;
                  await reportResult(context, service.addMilestone(g.id, input.title, dueDate: input.dueDate));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add milestone'),
              ),
            ),
          ),
        const EditorSection('Linked tasks, habits and events'),
        if (g.links.isEmpty) const ListTile(title: Text('Nothing linked yet.')),
        for (final l in g.links)
          ListTile(
            key: ValueKey('link-${l.itemId}'),
            leading: Icon(l.itemType == GoalItemType.event
                ? Icons.event
                : l.isHabit
                    ? Icons.track_changes
                    : l.state == LinkedItemState.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                color: l.state == LinkedItemState.done ? theme.colorScheme.primary : null),
            title: Text(l.title ?? 'A removed item',
                style: l.state == LinkedItemState.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
            subtitle: Text(_linkLine(l)),
            trailing: archived
                ? null
                : IconButton(
                    tooltip: 'Unlink ${l.title ?? 'item'}',
                    icon: const Icon(Icons.link_off),
                    onPressed: () => reportResult(context, service.unlink(g.id, l.itemType, l.itemId)),
                  ),
          ),
        if (!archived)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(spacing: 8, children: [
              TextButton.icon(
                key: const Key('link-task'),
                onPressed: () => _linkTask(context, ref),
                icon: const Icon(Icons.add_task),
                label: const Text('Link a task or habit'),
              ),
              TextButton.icon(
                key: const Key('link-event'),
                onPressed: () => _linkEvent(context, ref),
                icon: const Icon(Icons.event),
                label: const Text('Link an event'),
              ),
            ]),
          ),
      ],
    );
  }

  static String _linkLine(GoalLinkView l) => [
        switch (l.itemType) {
          GoalItemType.event => 'Event',
          GoalItemType.task => l.isHabit ? 'Habit' : 'Task',
        },
        switch (l.state) {
          LinkedItemState.open => l.itemType == GoalItemType.event ? 'not counted in progress' : 'open',
          LinkedItemState.done => 'done',
          LinkedItemState.cancelled => 'cancelled, not counted',
          LinkedItemState.trashed => 'in the trash, not counted',
          LinkedItemState.missing => 'removed, not counted',
        },
        if (l.isHabit && l.state != LinkedItemState.trashed) '${formatRate(l.habitRate)} since linked',
      ].join(' · ');

  Future<void> _linkTask(BuildContext context, WidgetRef ref) async {
    final linked = {for (final l in goal.links) if (l.itemType == GoalItemType.task) l.itemId};
    final tasks = (ref.read(tasksProvider).valueOrNull ?? const <TaskView>[])
        .where((t) => !linked.contains(t.id) && t.status != 'cancelled')
        .toList();
    final picked = await _pick(context, 'Link a task or habit',
        [for (final t in tasks) (t.id, t.title, t.isDone ? 'done' : null)], 'All your tasks are linked already.');
    if (picked == null || !context.mounted) return;
    await reportResult(context, ref.read(goalServiceProvider).link(goal.id, GoalItemType.task, picked));
  }

  Future<void> _linkEvent(BuildContext context, WidgetRef ref) async {
    final today = ref.read(todayProvider)();
    final linked = {for (final l in goal.links) if (l.itemType == GoalItemType.event) l.itemId};
    List<EventItem> events;
    try {
      events = (await ref.read(calendarQueriesProvider).watchRange(today.addDays(-30), today.addDays(180)).first).events;
    } catch (_) {
      events = const [];
    }
    final seen = <String>{};
    final options = [
      for (final e in events)
        if (!linked.contains(e.eventId) && seen.add(e.eventId))
          (e.eventId, e.title, formatDate(e.originalDate, today: today)),
    ];
    if (!context.mounted) return;
    final picked = await _pick(context, 'Link an event', options, 'No events from 30 days ago to 6 months ahead.');
    if (picked == null || !context.mounted) return;
    await reportResult(context, ref.read(goalServiceProvider).link(goal.id, GoalItemType.event, picked));
  }
}

Future<String?> _pick(BuildContext context, String title, List<(String, String, String?)> options, String empty) =>
    showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(title),
        children: options.isEmpty
            ? [Padding(padding: const EdgeInsets.all(24), child: Text(empty, key: const Key('pick-empty')))]
            : [
                for (final (id, label, note) in options)
                  SimpleDialogOption(
                    key: ValueKey('pick-$id'),
                    onPressed: () => Navigator.pop(c, id),
                    child: Text(note == null ? label : '$label · $note'),
                  ),
              ],
      ),
    );

/// The "Goals…" of a task (D12): the goals it is part of, ticked; ticking
/// links it, unticking unlinks it. The task itself is never changed.
Future<void> showGoalsOfTask(BuildContext context, WidgetRef ref, {required String taskId, required String title}) =>
    showDialog<void>(context: context, builder: (_) => _GoalsOfTaskDialog(taskId: taskId, title: title));

class _GoalsOfTaskDialog extends ConsumerWidget {
  const _GoalsOfTaskDialog({required this.taskId, required this.title});
  final String taskId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider(false));
    final service = ref.read(goalServiceProvider);
    return AlertDialog(
      title: Text('Goals for $title'),
      content: SizedBox(
        width: 400,
        child: goals.when(
          loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading goals')),
          error: (e, _) => const Text('Could not load the goals.'),
          data: (list) => list.isEmpty
              ? const Text('No goals yet. Add one in the Goals tab.', key: Key('task-goals-empty'))
              : ListView(shrinkWrap: true, children: [
                  for (final g in list)
                    CheckboxListTile(
                      key: ValueKey('task-goal-${g.id}'),
                      value: g.links.any((l) => l.itemType == GoalItemType.task && l.itemId == taskId),
                      title: Text(g.title),
                      subtitle: Text('${goalKindLabel(g.kind)} · ${progressText(g)}'),
                      onChanged: (on) => reportResult(
                          context,
                          on == true
                              ? service.link(g.id, GoalItemType.task, taskId)
                              : service.unlink(g.id, GoalItemType.task, taskId)),
                    ),
                ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

class _GoalInput {
  const _GoalInput(this.kind, this.title, this.description, this.startDate, this.targetDate);
  final GoalKindInput kind;
  final String title;
  final String? description;
  final LocalDate? startDate;
  final LocalDate? targetDate;
}

Future<LocalDate?> _pickDate(BuildContext context, LocalDate? initial, LocalDate today) async {
  final i = initial ?? today;
  final d = await showDatePicker(
      context: context,
      initialDate: DateTime(i.year, i.month, i.day),
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 20));
  return d == null ? null : LocalDate(d.year, d.month, d.day);
}

class _DateField extends StatelessWidget {
  const _DateField({required this.fieldKey, required this.label, required this.date, required this.today, required this.onChanged});
  final String fieldKey;
  final String label;
  final LocalDate? date;
  final LocalDate today;
  final ValueChanged<LocalDate?> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
        key: Key(fieldKey),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event),
        title: Text(date == null ? label : '$label: ${formatDate(date!, today: today)}'),
        onTap: () async {
          final d = await _pickDate(context, date, today);
          if (d != null) onChanged(d);
        },
        trailing: date == null
            ? null
            : IconButton(tooltip: 'Clear $label', icon: const Icon(Icons.clear), onPressed: () => onChanged(null)),
      );
}

class _GoalDialog extends ConsumerStatefulWidget {
  const _GoalDialog({this.initial});
  final GoalView? initial;
  @override
  ConsumerState<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends ConsumerState<_GoalDialog> {
  late var _kind = widget.initial?.kind ?? GoalKindInput.goal;
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _description = TextEditingController(text: widget.initial?.description ?? '');
  late LocalDate? _start = widget.initial?.startDate;
  late LocalDate? _target = widget.initial?.targetDate;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _ok() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    final d = _description.text.trim();
    Navigator.pop(context,
        _GoalInput(_kind, t, d.isEmpty ? null : d, _kind == GoalKindInput.project ? _start : null, _target));
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider)();
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit ${goalKindLabel(_kind).toLowerCase()}' : 'New goal or project'),
      scrollable: true,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!editing)
          SegmentedButton<GoalKindInput>(
            key: const Key('goal-kind'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: GoalKindInput.goal, label: Text('Goal'), icon: Icon(Icons.flag_outlined)),
              ButtonSegment(value: GoalKindInput.project, label: Text('Project'), icon: Icon(Icons.work_outline)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
        TextField(
          key: const Key('goal-title'),
          controller: _title,
          autofocus: true,
          maxLength: 200,
          decoration: InputDecoration(labelText: 'Title', errorText: _error),
        ),
        TextField(
          key: const Key('goal-description'),
          controller: _description,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Description (optional)'),
        ),
        if (_kind == GoalKindInput.project)
          _DateField(fieldKey: 'goal-start', label: 'Start', date: _start, today: today, onChanged: (d) => setState(() => _start = d)),
        _DateField(fieldKey: 'goal-target', label: 'Target date', date: _target, today: today, onChanged: (d) => setState(() => _target = d)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('goal-save'), onPressed: _ok, child: Text(editing ? 'Save' : 'Create')),
      ],
    );
  }
}

class _MilestoneInput {
  const _MilestoneInput(this.title, this.dueDate);
  final String title;
  final LocalDate? dueDate;
}

class _MilestoneDialog extends StatefulWidget {
  const _MilestoneDialog({this.initial, required this.today});
  final MilestoneView? initial;
  final LocalDate today;
  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late LocalDate? _due = widget.initial?.dueDate;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _ok() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Enter a title.');
      return;
    }
    Navigator.pop(context, _MilestoneInput(t, _due));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initial == null ? 'New milestone' : 'Edit milestone'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('milestone-title'),
            controller: _title,
            autofocus: true,
            maxLength: 200,
            decoration: InputDecoration(labelText: 'Title', errorText: _error),
            onSubmitted: (_) => _ok(),
          ),
          _DateField(
              fieldKey: 'milestone-due', label: 'Due', date: _due, today: widget.today, onChanged: (d) => setState(() => _due = d)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const Key('milestone-save'), onPressed: _ok, child: const Text('Save')),
        ],
      );
}
