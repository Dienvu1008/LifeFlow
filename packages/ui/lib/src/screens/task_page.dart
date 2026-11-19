// Dogfooding F3 (O4, ADR-0051): a task's own page, opened by a tap on the
// task (as an event opens its editor). Everything about the task in one
// place: title, list, colour, notes, schedule and reminders, habit and
// target, goals, subtasks, focus and trash. Each change is one command
// through the ports; the page only reads the task streams.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../habit_text.dart';
import '../l10n.dart';
import '../overview_tree.dart';
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import '../task_tree.dart';
import '../theme/lifeflow_theme.dart';
import '../documents/document_page.dart' show ItemDocumentsSection;
import 'focus_page.dart';
import 'goals_screen.dart';
import 'habit_page.dart';
import 'overview_view.dart' show colourName, pickColour, pickList, runMove;
import 'schedule_editor.dart';
import 'tasks_screen.dart' show addTaskWithDialog, showTextDialog, trashTask;

Future<void> openTaskPage(BuildContext context, String taskId) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TaskPage(taskId: taskId),
    ));

class TaskPage extends ConsumerStatefulWidget {
  const TaskPage({super.key, required this.taskId});
  final String taskId;

  @override
  ConsumerState<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends ConsumerState<TaskPage> {
  final _notes = TextEditingController();
  final _notesFocus = FocusNode();

  /// The notes as stored (to know whether the field changed).
  String? _stored;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Leaving the field saves it. P04 T6: then the page builds again, so
    // notes another device synced while the field had the focus show.
    _notesFocus.addListener(() {
      if (_notesFocus.hasFocus) return;
      _saveNotes();
      if (mounted) setState(() {});
    });
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  bool get _dirty => _loaded && _notes.text.trim() != (_stored ?? '');

  /// P04b T13 (B9): to an owner or an editor of the space, or to nobody.
  Future<void> _pickAssignee(String spaceId, TaskView t) async {
    final sharing = ref.read(sharingServiceProvider);
    if (sharing == null) return;
    final l = context.l10n;
    final members = [
      for (final m in await sharing.members(spaceId))
        if (m.status == MemberStatus.active && m.role != SpaceRole.viewer) m
    ];
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.spAssignedTo),
        children: [
          SimpleDialogOption(key: const Key('assign-nobody'), onPressed: () => Navigator.pop(ctx, ''), child: Text(l.spNobody)),
          for (final m in members)
            SimpleDialogOption(
              key: ValueKey('assign-${m.accountId}'),
              onPressed: () => Navigator.pop(ctx, m.accountId),
              child: Text(m.isMe ? l.spYou(m.name ?? l.spSomeone) : (m.name ?? l.spSomeone)),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final r = await sharing.assign(t.id, picked.isEmpty ? null : picked);
    if (!r.ok && mounted) showMessage(context, l.spProblem(r.problem!.name));
  }

  Future<void> _saveNotes() async {
    if (!_dirty || !mounted) return;
    final text = _notes.text.trim();
    final r = await reportResult(context, ref.read(taskServiceProvider).setNotes(widget.taskId, text.isEmpty ? null : text));
    if (r is CommandOk && mounted) setState(() => _stored = text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tasks = ref.watch(tasksProvider).valueOrNull;
    final lists = ref.watch(listsProvider).valueOrNull ?? const <TaskListView>[];
    final events = ref.watch(overviewEventsProvider).valueOrNull ?? const <OverviewEventView>[];
    final t = tasks?.where((x) => x.id == widget.taskId).firstOrNull;
    if (tasks == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tpTitle)),
        body: Center(child: Text(l.tpGone, key: const Key('task-page-gone'))),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _stored = t.notes;
      _notes.text = t.notes ?? '';
    } else if (!_notesFocus.hasFocus && !_dirty && t.notes != _stored) {
      // Changed elsewhere while not being edited here.
      _stored = t.notes;
      _notes.text = t.notes ?? '';
    }
    final ix = OverviewIndex(lists: lists, tasks: tasks, events: events);
    final rows = {for (final r in orderTree(tasks)) r.task.id: r};
    final row = rows[t.id]!;
    final level = ix.levelOf(t.id);
    final parent = t.parentId == null ? null : ix.tasks[t.parentId];
    final listId = ix.listOf(t.id);
    final listTitle = listId == null ? null : ix.lists[listId]?.title;
    final subtasks = [for (final id in ix.itemsOf('under:${t.id}')) ix.tasks[id]!];
    final tracked = ref.watch(trackedProvider).valueOrNull?[t.id];
    final today = ref.watch(todayProvider)();
    final zone = ref.watch(deviceZoneProvider);
    final colour = itemColorOf(context, t.colorIndex);
    final theme = Theme.of(context);
    final space = ref.watch(shownSharedSpaceProvider);
    final names = space == null ? const <String, String>{} : ref.watch(memberNamesProvider(space.id)).valueOrNull ?? const {};

    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Semantics(header: true, child: Text(text, style: theme.textTheme.titleSmall)),
        );

    return Scaffold(
      key: const Key('task-page'),
      appBar: AppBar(
        title: Text(l.tpTitle),
        actions: [
          if (!t.isDone)
            IconButton(
              key: const Key('task-page-focus'),
              tooltip: l.tpFocus,
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => startFocus(context, ref, taskId: t.id, taskTitle: t.title),
            ),
          IconButton(
            key: const Key('task-page-trash'),
            tooltip: l.tpTrash,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await trashTask(context, ref, row);
              if (mounted && ref.read(tasksProvider).valueOrNull?.every((x) => x.id != t.id) != false) {
                navigator.pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: Checkbox(
              key: const Key('task-page-done'),
              value: t.isDone,
              semanticLabel: t.isDone ? l.ovMarkNotDone(t.title) : l.ovComplete(t.title),
              onChanged: tracked?.completion == CompletionMode.automatic
                  ? null
                  : (_) => t.isDone
                      ? reportResult(context, ref.read(taskServiceProvider).reopen(t.id))
                      : completeTask(context, ref, row),
            ),
            title: Text(t.title,
                key: const Key('task-page-title'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(decoration: t.isDone ? TextDecoration.lineThrough : null)),
            trailing: IconButton(
              key: const Key('task-page-rename'),
              tooltip: l.tpRename,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final title = await showTextDialog(context, title: l.ovRenameTask, initial: t.title, confirmLabel: l.save);
                if (title == null || !context.mounted) return;
                await reportResult(context, ref.read(taskServiceProvider).rename(t.id, title));
              },
            ),
          ),
          if (parent != null)
            ListTile(
              key: const Key('task-page-parent'),
              leading: const Icon(Icons.subdirectory_arrow_right),
              title: Text(l.tpUnder(parent.title)),
              onTap: () => openTaskPage(context, parent.id),
            )
          else
            ListTile(
              key: const Key('task-page-list'),
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.tpList),
              trailing: Text(listTitle ?? l.ovNoList),
              onTap: () async {
                final to = await pickList(context, [for (final x in ix.listIds) ix.lists[x]!], listId);
                if (to == null || !context.mounted) return;
                final plan = moveToList(ix, t.id, to.isEmpty ? null : to);
                if (plan != null) await runMove(context, ref, plan);
              },
            ),
          // P04b T13 (B9, B10): in a shared space, who it is assigned to and
          // who changed it last.
          if (space != null) ...[
            ListTile(
              key: const Key('task-page-assignee'),
              leading: const Icon(Icons.assignment_ind_outlined),
              title: Text(l.spAssignedTo),
              trailing: Text(t.assigneeId == null ? l.spNobody : (names[t.assigneeId] ?? l.spSomeone)),
              enabled: ref.watch(canEditShownProvider),
              onTap: () => _pickAssignee(space.id, t),
            ),
            if (t.changedBy != null && t.updatedAt != null)
              ListTile(
                key: const Key('task-page-changed-by'),
                leading: const Icon(Icons.history),
                title: Text(l.spChangedBy(names[t.changedBy] ?? l.spSomeone,
                    MaterialLocalizations.of(context).formatShortDate(t.updatedAt!.toLocal()) +
                        ' ' +
                        MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t.updatedAt!.toLocal())))),
              ),
          ],
          ListTile(
            key: const Key('task-page-colour'),
            leading: Icon(Icons.circle, color: colour ?? theme.colorScheme.outlineVariant),
            title: Text(l.tpColour),
            trailing: Text(t.colorIndex == null ? l.ovNoColour : colourName(context, t.colorIndex!)),
            onTap: () async {
              final c = await pickColour(context, t.colorIndex);
              if (c == null || !context.mounted) return;
              await reportResult(context, ref.read(overviewServiceProvider).setTaskColor(t.id, c.index));
            },
          ),
          section(l.tpNotes),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('task-page-notes'),
              controller: _notes,
              focusNode: _notesFocus,
              minLines: 3,
              maxLines: 12,
              maxLength: 20000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l.tpNotesHint, border: const OutlineInputBorder()),
            ),
          ),
          if (_dirty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FilledButton(
                  key: const Key('task-page-save-notes'),
                  onPressed: _saveNotes,
                  child: Text(l.tpSaveNotes),
                ),
              ),
            ),
          section(l.tpPlan),
          ListTile(
            key: const Key('task-page-schedule'),
            leading: const Icon(Icons.event_outlined),
            title: Text(l.tpSchedule),
            subtitle: Text(t.schedule == null
                ? l.tpNotScheduled
                : describeSchedule(t.schedule!, today: today, deviceZone: zone)),
            onTap: () => openScheduleEditor(context, ref, taskId: t.id, title: t.title, initial: t.schedule),
          ),
          ListTile(
            key: const Key('task-page-habit'),
            leading: const Icon(Icons.track_changes_outlined),
            title: Text(l.ovHabitAndTarget),
            subtitle: Text(tracked == null ? l.tpNotTracked : (currentPeriodLine(tracked) ?? statsLine(tracked))),
            onTap: () => openHabitPage(context, taskId: t.id, title: t.title),
          ),
          ListTile(
            key: const Key('task-page-goals'),
            leading: const Icon(Icons.flag_outlined),
            title: Text(l.ovGoals),
            onTap: () => showGoalsOfTask(context, ref, taskId: t.id, title: t.title),
          ),
          // P05a T8: the documents linked to it.
          ItemDocumentsSection(type: DocumentItemType.task, itemId: t.id),
          section(l.tpSubtasks),
          for (final s in subtasks)
            ListTile(
              key: ValueKey('task-page-sub-${s.id}'),
              leading: Checkbox(
                value: s.isDone,
                semanticLabel: s.isDone ? l.ovMarkNotDone(s.title) : l.ovComplete(s.title),
                onChanged: (_) => s.isDone
                    ? reportResult(context, ref.read(taskServiceProvider).reopen(s.id))
                    : completeTask(context, ref, rows[s.id]!),
              ),
              title: Text(s.title,
                  style: s.isDone ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openTaskPage(context, s.id),
            ),
          if (level < maxTaskLevel)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('task-page-add-subtask'),
                  onPressed: () async {
                    final id = await addTaskWithDialog(context, ref, t.id);
                    if (id != null) ref.read(collapsedItemsProvider.notifier).expand(t.id);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l.ovAddSubtask),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
