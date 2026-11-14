// P03 UX U4 (ADR-0048): the Timeline. One list that scrolls both ways
// around an anchor day (today unless a day was chosen), with a sticky header
// per day; each row has a time column (or "All day"), a colour bar, the
// title, the habit state and a tick. Overdue one-off tasks are a collapsible
// group at the top of today (U-D3). The month and year in the app bar open a
// month calendar (table_calendar) under it; choosing a day jumps there.
// Data is loaded in windows of 21 days as the list scrolls, so every query
// stays bounded (LF-INV-PLAN-010).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:foundation/foundation.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n.dart';
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import '../task_tree.dart';
import '../theme/lifeflow_theme.dart';
import '../timeline_model.dart';
import 'event_editor.dart';

/// The day the Timeline is centred on; null = today. Choosing a day in the
/// month calendar (or "Today" in the Calendar tab) sets it.
final timelineAnchorProvider = StateProvider<LocalDate?>((ref) => null);

/// The month of the day at the top of the Timeline (for the app bar title).
final timelineMonthProvider = StateProvider<({int year, int month})?>((ref) => null);

/// Whether the month calendar under the app bar is open.
final timelineCalendarOpenProvider = StateProvider<bool>((ref) => false);

/// Space kept free under the last row so the + button never covers it.
const _fabClearance = 96.0;

/// Loads more days when the list is this close to an end.
const _loadAhead = 800.0;

/// "November 2026" for the app bar: a button that opens the month calendar.
class TimelineTitle extends ConsumerWidget {
  const TimelineTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(todayProvider)();
    final anchor = ref.watch(timelineAnchorProvider) ?? today;
    final m = ref.watch(timelineMonthProvider) ?? (year: anchor.year, month: anchor.month);
    final open = ref.watch(timelineCalendarOpenProvider);
    return TextButton.icon(
      key: const Key('timeline-month'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        textStyle: Theme.of(context).textTheme.titleLarge,
      ),
      onPressed: () => ref.read(timelineCalendarOpenProvider.notifier).state = !open,
      icon: Icon(open ? Icons.arrow_drop_up : Icons.arrow_drop_down),
      label: Tooltip(
        message: open ? l.tlHideMonth : l.tlShowMonth,
        child: Text(DateFormat.yMMMM().format(DateTime(m.year, m.month))),
      ),
    );
  }
}

/// "Today" for the app bar: back to today, at the top.
class TimelineTodayButton extends ConsumerWidget {
  const TimelineTodayButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        key: const Key('timeline-today'),
        tooltip: context.l10n.tlGoToToday,
        icon: const Icon(Icons.today),
        onPressed: () {
          ref.read(timelineAnchorProvider.notifier).state = ref.read(todayProvider)();
          ref.read(timelineMonthProvider.notifier).state = null;
        },
      );
}

class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({super.key});

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  final _center = GlobalKey();
  LocalDate? _anchor;
  ScrollController _scroll = ScrollController();
  int _back = 1;
  int _ahead = 2;
  bool _overdueOpen = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A new anchor starts afresh: a few windows around it, at the top.
  void _reset(LocalDate anchor) {
    _anchor = anchor;
    _back = 1;
    _ahead = 2;
    final old = _scroll;
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    var changed = false;
    if (m.extentAfter < _loadAhead && _ahead < timelineMaxWindows) {
      _ahead++;
      changed = true;
    }
    if (m.extentBefore < _loadAhead && _back < timelineMaxWindows) {
      _back++;
      changed = true;
    }
    if (changed) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() {}) : null);
    return false;
  }

  void _reportMonth(LocalDate day) {
    final m = (year: day.year, month: day.month);
    if (ref.read(timelineMonthProvider) == m) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(timelineMonthProvider.notifier).state = m;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider)();
    final anchor = ref.watch(timelineAnchorProvider) ?? today;
    if (anchor != _anchor) _reset(anchor);
    final windows = [
      for (var i = -_back; i < _ahead; i++)
        () {
          final w = timelineWindow(anchor, i);
          return (w, ref.watch(calendarRangeProvider(w)).valueOrNull);
        }(),
    ];
    final todayAgenda = ref.watch(todayAgendaProvider).valueOrNull;
    final data = buildTimeline(windows: windows, todayAgenda: todayAgenda, today: today);
    final firstWeekday = ref.watch(planningSettingsProvider).valueOrNull?.firstDayOfWeek ?? Weekday.monday;
    final open = ref.watch(timelineCalendarOpenProvider);
    final rows = {for (final r in orderTree(ref.watch(tasksProvider).valueOrNull ?? const [])) r.task.id: r};
    final eventColours = {
      for (final e in ref.watch(overviewEventsProvider).valueOrNull ?? const <OverviewEventView>[]) e.id: e.colorIndex
    };

    final days = data.visibleDays(anchor, today);
    final empty = data.days.isEmpty && data.overdue.isEmpty;
    Widget daySliver(LocalDate d) {
      final entries = data.days[d] ?? const <TimelineEntry>[];
      final isToday = d == today;
      return SliverStickyHeader.builder(
        key: d == anchor ? _center : ValueKey('day-sliver-$d'),
        builder: (context, state) {
          if (state.isPinned) _reportMonth(d);
          return _DayHeader(date: d, today: today, pinned: state.isPinned);
        },
        sliver: SliverList.list(children: [
          if (isToday && data.overdue.isNotEmpty) ...[
            _OverdueToggle(
              count: data.overdue.length,
              open: _overdueOpen,
              onToggle: () => setState(() => _overdueOpen = !_overdueOpen),
            ),
            if (_overdueOpen)
              for (final i in data.overdue)
                _TimeRow(
                  time: null,
                  colour: rows[i.taskId]?.task.colorIndex,
                  child: TaskOccurrenceTile(item: i, row: rows[i.taskId], today: today, showTimes: false),
                ),
          ],
          if (entries.isEmpty && !(isToday && data.overdue.isNotEmpty))
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(80, 8, 16, 12),
              child: Text(
                empty && isToday ? l.tlNothingPlanned : l.tlNothingThisDay,
                key: isToday ? const Key('agenda-empty') : null,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          for (final e in entries)
            switch (e) {
              TaskEntry(:final item) => _TimeRow(
                  time: item.start ?? item.end,
                  colour: rows[item.taskId]?.task.colorIndex,
                  child: TaskOccurrenceTile(
                    item: item,
                    row: rows[item.taskId],
                    today: today,
                    showTimes: false,
                    conflictWith: data.conflicts[e.key] ?? const [],
                  ),
                ),
              EventEntry(:final item) => _TimeRow(
                  time: item.start,
                  colour: eventColours[item.eventId],
                  child: _EventRow(item: item, conflictWith: data.conflicts[e.key] ?? const []),
                ),
            },
        ]),
      );
    }

    final list = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        key: ValueKey('timeline-$anchor'),
        controller: _scroll,
        center: _center,
        slivers: [
          for (final d in days) daySliver(d),
          const SliverPadding(padding: EdgeInsets.only(bottom: _fabClearance)),
        ],
      ),
    );

    return Column(
      children: [
        if (open)
          Material(
            key: const Key('timeline-calendar'),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: TableCalendar<TimelineEntry>(
              firstDay: DateTime(today.year - 10),
              lastDay: DateTime(today.year + 10, 12, 31),
              focusedDay: DateTime(anchor.year, anchor.month, anchor.day),
              currentDay: DateTime(today.year, today.month, today.day),
              selectedDayPredicate: (d) => d.year == anchor.year && d.month == anchor.month && d.day == anchor.day,
              startingDayOfWeek: firstWeekday == Weekday.sunday ? StartingDayOfWeek.sunday : StartingDayOfWeek.monday,
              availableCalendarFormats: const {CalendarFormat.month: ''},
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              rowHeight: 40,
              eventLoader: (d) => data.days[LocalDate(d.year, d.month, d.day)] ?? const [],
              // Dogfooding T3: one dot per item in its own colour (neutral
              // without one); a long row of dots scrolls.
              calendarBuilders: CalendarBuilders<TimelineEntry>(
                markerBuilder: (context, day, entries) => entries.isEmpty
                    ? null
                    : DayMarks(colours: [
                        for (final e in entries)
                          switch (e) {
                            TaskEntry(:final item) => rows[item.taskId]?.task.colorIndex,
                            EventEntry(:final item) => eventColours[item.eventId],
                          },
                      ]),
              ),
              onDaySelected: (selected, _) {
                ref.read(timelineAnchorProvider.notifier).state = LocalDate(selected.year, selected.month, selected.day);
                ref.read(timelineMonthProvider.notifier).state = null;
                ref.read(timelineCalendarOpenProvider.notifier).state = false;
              },
            ),
          ),
        if (data.truncated)
          Card(
            key: const Key('agenda-truncated'),
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.tlTruncated),
              subtitle: Text(l.tlTruncatedHint),
            ),
          ),
        Expanded(child: list),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.today, required this.pinned});
  final LocalDate date;
  final LocalDate today;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relative = formatDate(date, today: today);
    final long = formatDateLong(date, today: today);
    final text = relative == long ? long : context.l10n.tlDayHeader(relative, long);
    final isToday = date == today;
    return Material(
      key: ValueKey('day-$date'),
      color: theme.colorScheme.surface,
      elevation: pinned ? 1 : 0,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 6),
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isToday ? theme.colorScheme.primary : null,
              fontWeight: isToday ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverdueToggle extends StatelessWidget {
  const _OverdueToggle({required this.count, required this.open, required this.onToggle});
  final int count;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colour = LifeFlowColors.of(context).overdue;
    return ListTile(
      key: const Key('overdue-toggle'),
      dense: true,
      leading: Icon(Icons.warning_amber_rounded, color: colour),
      title: Text(l.tlOverdue(count), style: TextStyle(color: colour, fontWeight: FontWeight.w600)),
      trailing: Icon(open ? Icons.expand_less : Icons.expand_more,
          semanticLabel: open ? l.tlHideOverdue : l.tlShowOverdue),
      onTap: onToggle,
    );
  }
}

/// A time column (or "All day"), the colour bar, then the row.
class _TimeRow extends ConsumerWidget {
  const _TimeRow({required this.time, required this.colour, required this.child});
  final SchedulePointInput? time;
  final int? colour;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = time;
    final label = t == null || !t.isTimed
        ? context.l10n.tlAllDay
        : formatTimeOnly(t, deviceZone: ref.watch(deviceZoneProvider));
    final c = itemColorOf(context, colour);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 14),
              child: Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
            ),
          ),
          Container(width: 4, color: c ?? Colors.transparent),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({required this.item, required this.conflictWith});
  final EventItem item;
  final List<String> conflictWith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deviceZoneProvider);
    final e = item.end;
    final parts = [
      if (e != null && e.isTimed) '– ${formatTimeOnly(e, deviceZone: zone)}',
      if (item.location != null) item.location!,
    ];
    return ListTile(
      key: ValueKey('timeline-event-${item.eventId}@${item.originalDate}'),
      leading: const SizedBox(width: 40, child: Icon(Icons.event_outlined)),
      title: Text(
        item.title,
        style: item.isCancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
      ),
      subtitle: parts.isEmpty && conflictWith.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parts.isNotEmpty) Text(parts.join(' · ')),
                if (conflictWith.isNotEmpty) ConflictBadge(conflictWith),
              ],
            ),
      onTap: () => openEventEditor(context, ref, eventId: item.eventId),
    );
  }
}

/// The marks under a day of the month calendar: one dot per item, in the
/// item's palette colour or a neutral one; scrolls sideways when long.
class DayMarks extends StatelessWidget {
  const DayMarks({super.key, required this.colours});
  final List<int?> colours;

  @override
  Widget build(BuildContext context) {
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    return Positioned(
      left: 4,
      right: 4,
      bottom: 3,
      height: 7,
      child: Center(
        child: SingleChildScrollView(
          key: const Key('day-marks'),
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final c in colours)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: itemColorOf(context, c) ?? neutral, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}