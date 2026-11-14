// P02 T6b / P03 UX U5 (ADR-0049): the Calendar tab. Day and week as a time
// grid, month and year grids, a view switcher at the bottom; conflicts are
// shown, never resolved (D7); weeks start on the device setting (D3). The
// views only read CalendarQueries; every change is a command.
// Dogfooding C2 (ADR-0051): every view turns like pages, with a slide.
import 'package:application/application.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:go_router/go_router.dart';

import '../calendar_layout.dart';
import '../l10n.dart';
import '../theme/lifeflow_theme.dart';
import '../layout.dart';
import '../shell.dart' show shellMenuButton;
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import '../task_tree.dart';
import '../widgets/schedule_fields.dart';
import 'calendars_dialog.dart';
import 'calendar_grid_view.dart';
import 'event_editor.dart';
import 'tasks_screen.dart' show addTaskWithDialog, showTextDialog;
import 'timeline_view.dart' show jumpTimelineTo;

/// Which view and which date the Calendar tab shows; null until first shown
/// (then: today, and the view that suits the width).
final calendarPositionProvider = StateProvider<({CalendarMode mode, LocalDate anchor})?>((ref) => null);

/// Below this content width the week is a list of days, not seven columns.
const _weekColumnsMinWidth = 720.0;

/// Pages either side of where the pager starts; far more than anyone turns.
const _home = 100000;

/// How long a page takes to slide in (buttons, keys, the wheel).
const _turnDuration = Duration(milliseconds: 280);

/// Sideways wheel or touchpad travel that turns one page.
const _wheelStep = 40.0;

/// Dogfooding C2 (ADR-0051): every view turns like pages. A swipe (touch, a
/// mouse drag or a touchpad), a sideways wheel, ←/→ and PageUp/PageDown, and
/// the app bar's arrows slide the next period in. A vertical drag still
/// scrolls the hours and a tap still picks a slot (the gesture arena picks
/// by direction); while two fingers are down (pinch zoom) pages hold still.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarMode? _mode;
  late LocalDate _base;
  int _page = _home;
  int? _target;
  int _rebases = 0;
  PageController _pager = PageController(initialPage: _home);
  final _touches = <int>{};
  double _wheel = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// The period on page [i]; the start page is exactly the anchor it began on.
  LocalDate _anchorAt(int i) => i == _home ? _base : stepAnchor(_mode!, _base, i - _home);

  /// A new view or a jump (Today, a day, a month): the pager starts again there.
  void _rebase(CalendarMode mode, LocalDate anchor) {
    _mode = mode;
    _base = anchor;
    _page = _home;
    _target = null;
    _rebases++;
    final old = _pager;
    _pager = PageController(initialPage: _home);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _go(({CalendarMode mode, LocalDate anchor}) p) => ref.read(calendarPositionProvider.notifier).state = p;

  /// Slides [by] pages on (back when negative); presses during a slide add up.
  void _turn(int by) {
    if (!_pager.hasClients) return;
    final t = (_target ?? _page) + by;
    _target = t;
    _pager.animateToPage(t, duration: _turnDuration, curve: Curves.easeOutCubic).whenComplete(() {
      if (_target == t) _target = null;
    });
  }

  /// A sideways wheel or touchpad scroll turns a page (Shift + a mouse wheel
  /// too); a mostly vertical one is left to the grid.
  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || HardwareKeyboard.instance.isControlPressed) return;
    final shift = HardwareKeyboard.instance.isShiftPressed && e.kind == PointerDeviceKind.mouse;
    final dx = shift ? e.scrollDelta.dy : e.scrollDelta.dx;
    final dy = shift ? 0.0 : e.scrollDelta.dy;
    if (dx == 0 || dx.abs() <= dy.abs()) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) {
      if (_target != null) {
        _wheel = 0;
        return;
      }
      _wheel += dx;
      if (_wheel.abs() >= _wheelStep) {
        _turn(_wheel > 0 ? 1 : -1);
        _wheel = 0;
      }
    });
  }

  void _onDown(PointerDownEvent e) {
    _touches.add(e.pointer);
    if (_touches.length == 2) setState(() {});
  }

  void _onUp(PointerEvent e) {
    if (_touches.remove(e.pointer) && _touches.length == 1) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider)();
    final first = ref.watch(planningSettingsProvider).value?.firstDayOfWeek ?? Weekday.monday;
    final width = MediaQuery.sizeOf(context).width;
    final pos = ref.watch(calendarPositionProvider) ??
        (mode: layoutClassFor(width) == LayoutClass.compact ? CalendarMode.week : CalendarMode.month, anchor: today);
    if (pos.mode != _mode || pos.anchor != _anchorAt(_page)) _rebase(pos.mode, pos.anchor);
    // The periods either side load ahead, so a page slides in with its items.
    for (final i in [_page - 1, _page + 1]) {
      ref.watch(calendarRangeProvider(rangeOf(pos.mode, _anchorAt(i), first)));
    }
    final grid = pos.mode == CalendarMode.day || pos.mode == CalendarMode.week;
    final showNight = ref.watch(calendarShowNightProvider);
    final roomy = width >= 600;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    // P03 UX U4: the task lists are the Timeline now.
    void openTimeline(LocalDate day) {
      jumpTimelineTo(ref, day);
      context.go('/timeline');
    }

    final zoomOut = IconButton(
        key: const Key('zoom-out'),
        tooltip: l.calZoomOut,
        icon: const Icon(Icons.zoom_out),
        onPressed: () => zoomCalendar(ref, 1 / 1.25));
    final zoomIn = IconButton(
        key: const Key('zoom-in'),
        tooltip: l.calZoomIn,
        icon: const Icon(Icons.zoom_in),
        onPressed: () => zoomCalendar(ref, 1.25));
    final night = IconButton(
        key: const Key('night-toggle'),
        tooltip: showNight ? l.calHideNight : l.calShowNight,
        isSelected: showNight,
        icon: const Icon(Icons.bedtime_outlined),
        selectedIcon: const Icon(Icons.bedtime),
        onPressed: () => ref.read(calendarShowNightProvider.notifier).state = !showNight);

    final pages = Listener(
      key: const Key('calendar-pages'),
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: PageView.builder(
        // A new pager each time it starts again: a reused one would keep
        // its old position.
        key: ValueKey(_rebases),
        controller: _pager,
        physics: _touches.length >= 2 ? const NeverScrollableScrollPhysics() : null,
        // A mouse drags pages too (desktop scrolling leaves it out by
        // default); only for the pager, not for the hours inside.
        scrollBehavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        onPageChanged: (i) {
          _page = i;
          _go((mode: pos.mode, anchor: _anchorAt(i)));
        },
        itemCount: 2 * _home + 1,
        itemBuilder: (context, i) => Listener(
          onPointerSignal: _onSignal,
          child: _CalendarPage(mode: pos.mode, anchor: _anchorAt(i), first: first, today: today, onGo: _go),
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _turn(rtl ? 1 : -1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _turn(rtl ? -1 : 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () => _turn(-1),
        const SingleActivator(LogicalKeyboardKey.pageDown): () => _turn(1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: shellMenuButton(context),
            title: Text(periodTitle(pos.mode, pos.anchor, first), key: const Key('calendar-title')),
            actions: [
              IconButton(
                key: const Key('calendar-go-today'),
                tooltip: l.calGoToToday,
                icon: const Icon(Icons.today),
                onPressed: () => _go((mode: pos.mode, anchor: today)),
              ),
              IconButton(
                key: const Key('calendar-prev'),
                tooltip: l.calPrevious,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _turn(-1),
              ),
              IconButton(
                key: const Key('calendar-next'),
                tooltip: l.calNext,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _turn(1),
              ),
              if (grid && roomy) ...[zoomOut, zoomIn, night],
              if (grid && !roomy) night,
              IconButton(
                key: const Key('calendar-today-tasks'),
                tooltip: l.calOpenTimeline,
                icon: const Icon(Icons.view_timeline_outlined),
                onPressed: () => openTimeline(pos.mode == CalendarMode.day ? pos.anchor : today),
              ),
              PopupMenuButton<String>(
                tooltip: l.calMore,
                onSelected: (v) => switch (v) {
                  'in' => zoomCalendar(ref, 1.25),
                  'out' => zoomCalendar(ref, 1 / 1.25),
                  _ => showDialog<void>(context: context, builder: (_) => const CalendarsDialog()),
                },
                itemBuilder: (_) => [
                  if (grid && !roomy) ...[
                    PopupMenuItem(value: 'in', child: Text(l.calZoomIn)),
                    PopupMenuItem(value: 'out', child: Text(l.calZoomOut)),
                  ],
                  PopupMenuItem(value: 'calendars', child: Text(l.calManageCalendars)),
                ],
              ),
            ],
          ),
          body: Stack(children: [
            pages,
            // Centred at the bottom: there is no + button any more (C1).
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: SafeArea(
                child: Center(
                    child: CalendarModeSwitcher(
                  mode: pos.mode,
                  onChanged: (m) => _go((mode: m, anchor: pos.anchor)),
                )),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One period of one view: its own range, loaded on its own.
class _CalendarPage extends ConsumerWidget {
  const _CalendarPage({
    required this.mode,
    required this.anchor,
    required this.first,
    required this.today,
    required this.onGo,
  });
  final CalendarMode mode;
  final LocalDate anchor;
  final Weekday first;
  final LocalDate today;
  final ValueChanged<({CalendarMode mode, LocalDate anchor})> onGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final range = rangeOf(mode, anchor, first);
    return ref.watch(calendarRangeProvider(range)).when(
          loading: () => Center(child: CircularProgressIndicator(semanticsLabel: l.calLoading)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.calLoadError, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
          data: (r) {
            final view = _ViewData(r, range.from, range.to, today, first);
            void toDay(LocalDate d) => onGo((mode: CalendarMode.day, anchor: d));
            final body = switch (mode) {
              CalendarMode.day || CalendarMode.week => TimeGridView(
                  days: [for (var d = range.from; !d.isAfter(range.to); d = d.addDays(1)) d],
                  byDay: view.byDay,
                  today: today,
                  block: (e, h) => _GridBlock(e, view, height: h),
                  allDay: (e) => _EntryChip(e, view),
                  onSlot: (d, m) => _slotActions(context, ref, d, m),
                  onDay: toDay,
                ),
              CalendarMode.month => _MonthView(view, anchor, onDay: toDay),
              CalendarMode.year => YearView(
                  year: anchor.year,
                  counts: {for (final MapEntry(:key, :value) in view.byDay.entries) key: value.length},
                  first: first,
                  today: today,
                  onDay: toDay,
                  onMonth: (m) => onGo((mode: CalendarMode.month, anchor: LocalDate(anchor.year, m, 1))),
                ),
            };
            return Column(
              children: [
                if (r.truncated)
                  Card(
                    key: const Key('calendar-truncated'),
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l.tlTruncated),
                      subtitle: Text(l.tlTruncatedHint),
                    ),
                  ),
                Expanded(child: body),
              ],
            );
          },
        );
  }
}

/// A tap on an empty slot: a new event or task there, or an existing task
/// scheduled there (P03 UX U5).
Future<void> _slotActions(BuildContext context, WidgetRef ref, LocalDate day, int minute) async {
  final l = context.l10n;
  final time = TimeOfDayValue(minute ~/ 60, minute % 60);
  final today = ref.read(todayProvider)();
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.calSlotTitle(formatDate(day, today: today), '$time'),
              key: const Key('slot-title'), style: Theme.of(context).textTheme.titleMedium),
        ),
        ListTile(
          key: const Key('slot-event'),
          leading: const Icon(Icons.event_outlined),
          title: Text(l.calNewEvent),
          onTap: () => Navigator.pop(context, 'event'),
        ),
        ListTile(
          key: const Key('slot-allday'),
          leading: const Icon(Icons.wb_sunny_outlined),
          title: Text(l.calNewAllDayEvent),
          onTap: () => Navigator.pop(context, 'allday'),
        ),
        ListTile(
          key: const Key('slot-task'),
          leading: const Icon(Icons.check_box_outlined),
          title: Text(l.calNewTask),
          onTap: () => Navigator.pop(context, 'task'),
        ),
        ListTile(
          key: const Key('slot-schedule'),
          leading: const Icon(Icons.schedule),
          title: Text(l.calScheduleTask),
          onTap: () => Navigator.pop(context, 'schedule'),
        ),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  final start = TaskScheduleInput(start: SchedulePointInput.at(day, time, ref.read(deviceZoneProvider)));
  switch (choice) {
    case 'event':
      await openEventEditor(context, ref, date: day, time: time);
    case 'allday':
      await openEventEditor(context, ref, date: day, allDay: true);
    case 'task':
      final id = await addTaskWithDialog(context, ref, null);
      if (id == null || !context.mounted) return;
      await reportResult(context, ref.read(taskSchedulingProvider).setSchedule(id, start));
    case 'schedule':
      final open = [
        for (final t in ref.read(tasksProvider).valueOrNull ?? const <TaskView>[])
          if (t.schedule == null && !t.isDone) t
      ];
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(l.calPickTask),
          children: [
            if (open.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(l.calNoUnscheduled)),
            for (final t in open)
              SimpleDialogOption(
                key: ValueKey('pick-task-${t.id}'),
                onPressed: () => Navigator.pop(context, t.id),
                child: Text(t.title),
              ),
          ],
        ),
      );
      if (picked == null || !context.mounted) return;
      await reportResult(context, ref.read(taskSchedulingProvider).setSchedule(picked, start));
  }
}

/// A timed item's block in the grid; opens the full row in a sheet.
class _GridBlock extends ConsumerWidget {
  const _GridBlock(this.e, this.v, {required this.height});
  final CalendarEntry e;
  final _ViewData v;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _colorOf(ref, e, theme);
    final conflicted = v.conflicts.containsKey(e.key);
    final done = e.task?.isDone ?? false;
    final time = entryTime(e, deviceZone: ref.watch(deviceZoneProvider));
    final struck = e.isCancelled || done ? TextDecoration.lineThrough : null;
    return Semantics(
      button: true,
      label: '${e.title}, $time',
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: 0.18), theme.colorScheme.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('chip-${e.key}'),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: _EntryTile(e, v))),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 1, 2, 1),
              child: height < 30
                  ? Text(e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(decoration: struck))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (e.task != null) Icon(done ? Icons.check_box : Icons.check_box_outline_blank, size: 12),
                        if (conflicted) Icon(Icons.warning_amber_rounded, size: 12, color: theme.colorScheme.error),
                        Expanded(
                          child: Text(e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(decoration: struck)),
                        ),
                      ]),
                      if (height >= 44)
                        Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                    ]),
            ),
          ),
        ),
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
  // P03 UX U5: the item's own colour (U-D4) first.
  final task = e.task;
  if (task != null) {
    final tasks = ref.watch(tasksProvider).valueOrNull ?? const <TaskView>[];
    final c = tasks.where((t) => t.id == task.taskId).firstOrNull?.colorIndex;
    return c != null && c >= 0 && c < itemPalette.length ? itemPalette[c].on(theme.brightness) : theme.colorScheme.tertiary;
  }
  final own = (ref.watch(overviewEventsProvider).valueOrNull ?? const <OverviewEventView>[])
      .where((x) => x.id == e.event!.eventId)
      .firstOrNull
      ?.colorIndex;
  if (own != null && own >= 0 && own < itemPalette.length) return itemPalette[own].on(theme.brightness);
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
