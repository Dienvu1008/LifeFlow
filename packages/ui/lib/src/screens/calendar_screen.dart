// P02 T6b: the Calendar tab. Day, week and month views of events and
// scheduled tasks; conflicts are shown, never resolved (D7); buttons lead to
// the Today and Upcoming task lists (D9); weeks start on the device setting
// (D3). The views only read CalendarQueries; every change is a command.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:go_router/go_router.dart';

import '../calendar_layout.dart';
import '../layout.dart';
import '../shell.dart' show shellMenuButton;
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import '../task_tree.dart';
import '../widgets/schedule_fields.dart';
import 'calendars_dialog.dart';
import 'event_editor.dart';
import 'tasks_screen.dart' show showTextDialog;

/// Which view and which date the Calendar tab shows; null until first shown
/// (then: today, and the view that suits the width).
final calendarPositionProvider = StateProvider<({CalendarMode mode, LocalDate anchor})?>((ref) => null);

/// Below this content width the week is a list of days, not seven columns.
const _weekColumnsMinWidth = 720.0;

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider)();
    final first = ref.watch(planningSettingsProvider).value?.firstDayOfWeek ?? Weekday.monday;
    final width = MediaQuery.sizeOf(context).width;
    final pos = ref.watch(calendarPositionProvider) ??
        (mode: layoutClassFor(width) == LayoutClass.compact ? CalendarMode.week : CalendarMode.month, anchor: today);
    void go(({CalendarMode mode, LocalDate anchor}) p) => ref.read(calendarPositionProvider.notifier).state = p;
    final range = rangeOf(pos.mode, pos.anchor, first);
    final data = ref.watch(calendarRangeProvider(range));

    void openTasks(TaskFilter f) {
      ref.read(taskFilterProvider.notifier).state = f;
      context.go('/tasks');
    }

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: Text(periodTitle(pos.mode, pos.anchor, first), key: const Key('calendar-title')),
        actions: [
          IconButton(
            tooltip: 'Previous',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => go((mode: pos.mode, anchor: stepAnchor(pos.mode, pos.anchor, -1))),
          ),
          IconButton(
            tooltip: 'Next',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => go((mode: pos.mode, anchor: stepAnchor(pos.mode, pos.anchor, 1))),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => showDialog<void>(context: context, builder: (_) => const CalendarsDialog()),
            itemBuilder: (_) => const [PopupMenuItem(value: 'calendars', child: Text('Manage calendars'))],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Column(
              children: [
                SegmentedButton<CalendarMode>(
                  key: const Key('calendar-mode'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: CalendarMode.day, label: Text('Day')),
                    ButtonSegment(value: CalendarMode.week, label: Text('Week')),
                    ButtonSegment(value: CalendarMode.month, label: Text('Month')),
                  ],
                  selected: {pos.mode},
                  onSelectionChanged: (s) => go((mode: s.first, anchor: pos.anchor)),
                ),
                SizedBox(
                  height: 44,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        TextButton.icon(
                          key: const Key('calendar-go-today'),
                          onPressed: () => go((mode: pos.mode, anchor: today)),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Go to today'),
                        ),
                        TextButton.icon(
                          key: const Key('calendar-today-tasks'),
                          onPressed: () => openTasks(TaskFilter.today),
                          icon: const Icon(Icons.today),
                          label: const Text("Today's tasks"),
                        ),
                        TextButton.icon(
                          key: const Key('calendar-upcoming-tasks'),
                          onPressed: () => openTasks(TaskFilter.upcoming),
                          icon: const Icon(Icons.date_range),
                          label: const Text('Upcoming tasks'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // Each tab keeps its page alive; two default hero tags would clash
        // when a full-screen editor opens.
        heroTag: 'fab-calendar',
        tooltip: 'New event',
        onPressed: () => openEventEditor(context, ref, date: pos.mode == CalendarMode.month ? today : pos.anchor),
        child: const Icon(Icons.add),
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading the calendar')),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load the calendar.', style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        data: (r) {
          final view = _ViewData(r, range.from, range.to, today, first);
          final body = switch (pos.mode) {
            CalendarMode.day => _DayView(view, pos.anchor),
            CalendarMode.week => _WeekView(view, onDay: (d) => go((mode: CalendarMode.day, anchor: d))),
            CalendarMode.month => _MonthView(view, pos.anchor, onDay: (d) => go((mode: CalendarMode.day, anchor: d))),
          };
          return Column(
            children: [
              if (r.truncated)
                const Card(
                  key: Key('calendar-truncated'),
                  margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Not everything is shown'),
                    subtitle: Text('There are more items than the limit in Settings → Calendar.'),
                  ),
                ),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }
}

/// What every view needs, computed once per range.
class _ViewData {
  _ViewData(this.range, this.from, this.to, this.today, this.first)
      : byDay = entriesByDay(range, from, to),
        conflicts = conflictTitles(range);
  final CalendarRange range;
  final LocalDate from;
  final LocalDate to;
  final LocalDate today;
  final Weekday first;
  final Map<LocalDate, List<CalendarEntry>> byDay;
  final Map<String, List<String>> conflicts;

  List<CalendarEntry> on(LocalDate d) => byDay[d] ?? const [];
}

class _DayView extends ConsumerWidget {
  const _DayView(this.v, this.day);
  final _ViewData v;
  final LocalDate day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = v.on(day);
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Nothing on this day.',
              key: const Key('calendar-empty'), style: Theme.of(context).textTheme.bodyLarge),
        ),
      );
    }
    return ListView(
      key: const Key('calendar-day'),
      padding: const EdgeInsets.only(bottom: 96),
      children: [for (final e in entries) _EntryTile(e, v)],
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView(this.v, {required this.onDay});
  final _ViewData v;
  final ValueChanged<LocalDate> onDay;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) v.from.addDays(i)];
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < _weekColumnsMinWidth) {
        // Phone: one list, a header per day.
        return ListView(
          key: const Key('calendar-week-list'),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final d in days) ...[
              _DayHeader(d, v.today, onTap: () => onDay(d)),
              if (v.on(d).isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Nothing planned', style: TextStyle(fontStyle: FontStyle.italic)),
                ),
              for (final e in v.on(d)) _EntryTile(e, v),
            ],
          ],
        );
      }
      // Wide: seven columns.
      return Row(
        key: const Key('calendar-week-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border(right: BorderSide(color: Theme.of(context).dividerColor))),
                child: Column(
                  children: [
                    _DayHeader(d, v.today, compact: true, onTap: () => onDay(d)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 96),
                        children: [for (final e in v.on(d)) _EntryChip(e, v)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView(this.v, this.anchor, {required this.onDay});
  final _ViewData v;
  final LocalDate anchor;
  final ValueChanged<LocalDate> onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _weekColumnsMinWidth;
      return Column(
        key: const Key('calendar-month'),
        children: [
          Row(
            children: [
              for (final d in weekFrom(v.first))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(weekdayShort(d), textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                  ),
                ),
            ],
          ),
          for (var w = 0; w < 6; w++)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(child: _MonthCell(v, v.from.addDays(w * 7 + i), anchor.month, wide: wide, onTap: onDay)),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell(this.v, this.day, this.month, {required this.wide, required this.onTap});
  final _ViewData v;
  final LocalDate day;
  final int month;
  final bool wide;
  final ValueChanged<LocalDate> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = v.on(day);
    final isToday = day == v.today;
    final outside = day.month != month;
    final conflicted = entries.any((e) => v.conflicts.containsKey(e.key));
    final n = entries.length;
    final label = '${formatDateLong(day, today: v.today)}, '
        '${n == 0 ? 'nothing planned' : n == 1 ? '1 item' : '$n items'}'
        '${conflicted ? ', with overlaps' : ''}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('month-cell-$day'),
        onTap: () => onTap(day),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: theme.dividerColor, width: 0.5)),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: isToday
                          ? BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10))
                          : null,
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isToday
                              ? theme.colorScheme.onPrimary
                              : outside
                                  ? theme.disabledColor
                                  : null,
                        ),
                      ),
                    ),
                    if (conflicted)
                      Icon(Icons.warning_amber_rounded, size: 12, color: theme.colorScheme.error),
                  ],
                ),
                if (wide)
                  Expanded(
                    child: ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final e in entries.take(3))
                            Text(e.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                    decoration: e.isCancelled ? TextDecoration.lineThrough : null)),
                          if (n > 3) Text('+${n - 3} more', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                  )
                else if (n > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(n > 3 ? '•••+' : '•' * n,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, height: 1)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.day, this.today, {required this.onTap, this.compact = false});
  final LocalDate day;
  final LocalDate today;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = day == today;
    final text = compact
        ? '${weekdayShort(day.weekday)} ${day.day}'
        : '${formatDate(day, today: today)}${day.daysUntil(today).abs() <= 1 ? ' · ${formatDateLong(day, today: today)}' : ''}';
    return InkWell(
      key: ValueKey('day-header-$day'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 4 : 16, 12, compact ? 4 : 16, 4),
        child: Semantics(
          header: true,
          child: Text(
            text,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: theme.textTheme.titleSmall?.copyWith(color: isToday ? theme.colorScheme.primary : null),
          ),
        ),
      ),
    );
  }
}

/// A full row: an event row, or the task's own row (D6).
class _EntryTile extends ConsumerWidget {
  const _EntryTile(this.e, this.v);
  final CalendarEntry e;
  final _ViewData v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final others = v.conflicts[e.key] ?? const [];
    final task = e.task;
    if (task != null) {
      final rows = {for (final r in orderTree(ref.watch(tasksProvider).value ?? const [])) r.task.id: r};
      return TaskOccurrenceTile(item: task, row: rows[task.taskId], today: v.today, conflictWith: others);
    }
    return EventTile(event: e.event!, entry: e, today: v.today, conflictWith: others);
  }
}

/// A small block in a week column; opens the full row in a sheet.
class _EntryChip extends ConsumerWidget {
  const _EntryChip(this.e, this.v);
  final CalendarEntry e;
  final _ViewData v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _colorOf(ref, e, theme);
    final conflicted = v.conflicts.containsKey(e.key);
    final done = e.task?.isDone ?? false;
    final time = entryTime(e, deviceZone: ref.watch(deviceZoneProvider));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        label: '${e.task != null ? 'Task' : 'Event'} ${e.title}, $time'
            '${e.isCancelled ? ', cancelled' : ''}${done ? ', done' : ''}${conflicted ? ', overlaps' : ''}',
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('chip-${e.key}'),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: _EntryTile(e, v))),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              border: Border(left: BorderSide(color: color, width: 3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (e.task != null) Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 12),
                  if (conflicted) Icon(Icons.warning_amber_rounded, size: 12, color: theme.colorScheme.error),
                  Expanded(
                    child: Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                  ),
                ]),
                Text(e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                        decoration: e.isCancelled || done ? TextDecoration.lineThrough : null)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _colorOf(WidgetRef ref, CalendarEntry e, ThemeData theme) {
  if (e.task != null) return theme.colorScheme.tertiary;
  final id = e.event!.calendarId;
  final cals = ref.watch(calendarsProvider).value ?? const <CalendarView>[];
  final c = cals.where((c) => c.id == id).firstOrNull;
  return c == null ? theme.colorScheme.primary : Color(c.color);
}

enum _EventAction { edit, skip, cancelThis, move, editThis, undoThis, cancelAll, uncancelAll, trash }

/// One occurrence of an event, with its actions: the whole event, or only
/// this time (D4).
class EventTile extends ConsumerWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.entry,
    required this.today,
    this.conflictWith = const [],
  });
  final EventItem event;
  final CalendarEntry entry;
  final LocalDate today;
  final List<String> conflictWith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ev = event;
    final zone = ref.watch(deviceZoneProvider);
    final theme = Theme.of(context);
    final parts = <String>[
      entryTime(entry, deviceZone: zone),
      if (entry.lastDay != ev.start.date) 'Until ${formatPoint(ev.end!, today: today, deviceZone: zone)}',
      if (ev.location != null && ev.location!.isNotEmpty) ev.location!,
      if (ev.isRepeating) 'Repeats',
      if (ev.isMoved) 'Moved',
      if (ev.isCancelled) 'Cancelled',
    ];
    return ListTile(
      key: ValueKey('event-${ev.eventId}@${ev.originalDate}'),
      leading: Icon(Icons.event, color: _colorOf(ref, entry, theme)),
      title: Text(ev.title,
          style: ev.isCancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parts.join(' · ')),
          if (conflictWith.isNotEmpty) ConflictBadge(conflictWith),
        ],
      ),
      onTap: () => openEventEditor(context, ref, eventId: ev.eventId),
      trailing: PopupMenuButton<_EventAction>(
        tooltip: 'Actions for ${ev.title}',
        onSelected: (a) => _onAction(context, ref, a),
        itemBuilder: (_) => [
          PopupMenuItem(
              value: _EventAction.edit, child: Text(ev.isRepeating ? 'Edit every time…' : 'Edit event…')),
          if (ev.isRepeating) ...[
            const PopupMenuItem(value: _EventAction.skip, child: Text('Skip this time')),
            if (!ev.isCancelled)
              const PopupMenuItem(value: _EventAction.cancelThis, child: Text('Cancel this time')),
            const PopupMenuItem(value: _EventAction.move, child: Text('Move this time…')),
            const PopupMenuItem(value: _EventAction.editThis, child: Text('Rename this time…')),
            if (ev.isMoved || ev.isCancelled)
              const PopupMenuItem(value: _EventAction.undoThis, child: Text('Undo the change to this time')),
          ],
          if (ev.isCancelled)
            const PopupMenuItem(value: _EventAction.uncancelAll, child: Text('Un-cancel the event'))
          else
            PopupMenuItem(
                value: _EventAction.cancelAll,
                child: Text(ev.isRepeating ? 'Cancel every time' : 'Cancel the event')),
          const PopupMenuItem(value: _EventAction.trash, child: Text('Move to trash')),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, _EventAction a) async {
    final ev = event;
    final events = ref.read(eventServiceProvider);
    Future<CommandResult> change(EventOccurrenceChange? c) => events.changeOccurrence(ev.eventId, ev.originalDate, c);
    switch (a) {
      case _EventAction.edit:
        await openEventEditor(context, ref, eventId: ev.eventId);
      case _EventAction.skip:
        await reportResult(context, change(const SkipEventOccurrence()));
      case _EventAction.cancelThis:
        await reportResult(context, change(const CancelEventOccurrence()));
      case _EventAction.move:
        final picked = await pickLocalDate(context, current: ev.date, today: today, help: 'Move this time to');
        if (picked == null || !context.mounted) return;
        await reportResult(context, change(MoveEventOccurrence(picked)));
      case _EventAction.editThis:
        final title =
            await showTextDialog(context, title: 'Rename this time', initial: ev.title, confirmLabel: 'Save');
        if (title == null || !context.mounted) return;
        await reportResult(context, change(EditEventOccurrence(title: title)));
      case _EventAction.undoThis:
        await reportResult(context, change(null));
      case _EventAction.cancelAll:
        await reportResult(context, events.setCancelled(ev.eventId, cancelled: true));
      case _EventAction.uncancelAll:
        await reportResult(context, events.setCancelled(ev.eventId, cancelled: false));
      case _EventAction.trash:
        final r = await reportResult(context, events.trash(ev.eventId));
        if (r is CommandOk && context.mounted) {
          showMessage(context, 'Event moved to the trash.',
              action: SnackBarAction(label: 'Undo', onPressed: () => events.restore(ev.eventId)));
        }
    }
  }
}
