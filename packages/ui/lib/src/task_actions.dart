// Task actions shared by the Tasks tab and the Calendar tab: completing with
// the open-subtasks question (OQ-R3), reporting a refused command, and the
// row of one scheduled task occurrence (P02 T6a/T6b).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import 'habit_text.dart';
import 'messages.dart';
import 'providers.dart';
import 'schedule_text.dart';
import 'screens/focus_page.dart';
import 'screens/schedule_editor.dart';
import 'task_tree.dart';
import 'widgets/schedule_fields.dart';

enum _CompleteChoice { withSubtasks, onlyThis }

/// OQ-R3: with open subtasks the user chooses between the two commands.
Future<void> completeTask(BuildContext context, WidgetRef ref, TaskRow row) async {
  var withDescendants = false;
  if (row.hasOpenChildren) {
    final choice = await showDialog<_CompleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('This task has open subtasks'),
        content: const Text('Complete the subtasks too, or only this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, _CompleteChoice.onlyThis), child: const Text('Only this task')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, _CompleteChoice.withSubtasks), child: const Text('With subtasks')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    withDescendants = choice == _CompleteChoice.withSubtasks;
  }
  await reportResult(context, ref.read(taskServiceProvider).complete(row.task.id, withDescendants: withDescendants));
}

/// Shows a failure as a snackbar; success needs no message (lists update).
/// Returns the result.
Future<CommandResult> reportResult(BuildContext context, Future<CommandResult> pending) async {
  final result = await pending;
  if (result is CommandFailure && context.mounted) {
    showMessage(context, describeFailure(result));
  }
  return result;
}

void showMessage(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

enum _OccurrenceAction { focus, skip, move, undoChange, schedule }

/// One occurrence of a scheduled task (Today, Upcoming, Calendar). A
/// repeating task is ticked one occurrence at a time (D5); "only this time"
/// changes are offered for it (D4).
class TaskOccurrenceTile extends ConsumerWidget {
  const TaskOccurrenceTile({
    super.key,
    required this.item,
    required this.row,
    required this.today,
    this.showDate = false,
    this.showTimes = true,
    this.conflictWith = const [],
  });
  final AgendaItem item;

  /// The task's row in the tree (for the open-subtasks question and its
  /// current schedule), if loaded.
  final TaskRow? row;
  final LocalDate today;

  /// Show the date in the subtitle (rows not grouped by date).
  final bool showDate;

  /// Show the start time in the subtitle (false in the Timeline, which has
  /// a time column, P03 UX U4).
  final bool showTimes;

  /// Titles of items this one overlaps (D7: shown, never resolved).
  final List<String> conflictWith;

  String _subtitle(String zone) {
    final s = item.start, e = item.end, d = item.deadline;
    final parts = <String>[
      if (item.isOverdue) 'Planned ${formatDate(item.date, today: today)}',
      if (showDate && !item.isOverdue) formatDate(item.date, today: today),
      if (showTimes && s != null && s.isTimed)
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
    // P03 T6a: a tracked task shows its running period; with automatic
    // completion the box shows the derived state and is not ticked (D8).
    final tracked = ref.watch(trackedProvider).valueOrNull?[i.taskId];
    final auto = tracked != null && tracked.completion == CompletionMode.automatic;
    final done = auto ? isDoneAutomatically(tracked, i.originalDate) : i.isDone;
    final period = tracked == null || !inCurrentPeriod(tracked, i.originalDate) ? null : currentPeriodLine(tracked);
    return ListTile(
      key: ValueKey('agenda-${i.taskId}@${i.originalDate}'),
      leading: Checkbox(
        value: done,
        semanticLabel: auto
            ? (done ? 'Done from measurements: ${i.title}' : 'Not reached yet: ${i.title}')
            : i.isDone
                ? 'Mark as not done: ${i.title}'
                : 'Complete ${i.title}',
        onChanged: auto ? null : (_) => _toggle(context, ref),
      ),
      title: Text(
        i.title,
        style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: subtitle.isEmpty && conflictWith.isEmpty && period == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle.isNotEmpty) Text(subtitle),
                if (period != null) Text(period, key: ValueKey('period-${i.taskId}')),
                if (conflictWith.isNotEmpty) ConflictBadge(conflictWith),
              ],
            ),
      trailing: PopupMenuButton<_OccurrenceAction>(
        tooltip: 'Actions for ${i.title}',
        onSelected: (a) => _onAction(context, ref, a),
        itemBuilder: (_) => [
          if (!done) const PopupMenuItem(value: _OccurrenceAction.focus, child: Text('Focus…')),
          if (i.isRepeating) ...[
            const PopupMenuItem(value: _OccurrenceAction.skip, child: Text('Skip this time')),
            const PopupMenuItem(value: _OccurrenceAction.move, child: Text('Move this time…')),
            if (i.isMoved)
              const PopupMenuItem(value: _OccurrenceAction.undoChange, child: Text('Undo the change to this time')),
          ],
          PopupMenuItem(
              value: _OccurrenceAction.schedule,
              child: Text(i.isRepeating ? 'Edit the whole repeat…' : 'Schedule…')),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final i = item;
    // D5: a repeating task is done one occurrence at a time; it stays open.
    if (i.isRepeating) {
      await reportResult(
          context, ref.read(taskSchedulingProvider).setOccurrenceDone(i.taskId, i.originalDate, done: !i.isDone));
      return;
    }
    if (i.isDone) {
      await reportResult(context, ref.read(taskServiceProvider).reopen(i.taskId));
      return;
    }
    final r = row;
    if (r == null) {
      await reportResult(context, ref.read(taskServiceProvider).complete(i.taskId, withDescendants: false));
    } else {
      await completeTask(context, ref, r);
    }
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, _OccurrenceAction a) async {
    final i = item;
    final scheduling = ref.read(taskSchedulingProvider);
    switch (a) {
      case _OccurrenceAction.skip:
        await reportResult(context, scheduling.changeOccurrence(i.taskId, i.originalDate, const SkipThisOccurrence()));
      case _OccurrenceAction.move:
        final picked = await pickLocalDate(context, current: i.date, today: today, help: 'Move this time to');
        if (picked == null || !context.mounted) return;
        await reportResult(context, scheduling.changeOccurrence(i.taskId, i.originalDate, MoveThisOccurrence(picked)));
      case _OccurrenceAction.focus:
        // D5: the session is for this occurrence of a repeating task.
        await startFocus(context, ref,
            taskId: i.taskId, taskTitle: i.title, occurrenceDate: i.isRepeating ? i.originalDate : null);
      case _OccurrenceAction.undoChange:
        await reportResult(context, scheduling.changeOccurrence(i.taskId, i.originalDate, null));
      case _OccurrenceAction.schedule:
        final initial = row?.task.schedule ?? await scheduling.scheduleOf(i.taskId);
        if (!context.mounted) return;
        await openScheduleEditor(context, ref, taskId: i.taskId, title: i.title, initial: initial);
    }
  }
}

/// D7: an overlap is shown, never resolved. Readable without colour.
class ConflictBadge extends StatelessWidget {
  const ConflictBadge(this.others, {super.key});
  final List<String> others;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final text = 'Overlaps ${others.join(', ')}';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        key: const Key('conflict-badge'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
