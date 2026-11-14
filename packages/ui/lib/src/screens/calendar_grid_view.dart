// P03 UX U5 (ADR-0049): the day and week time grid and the year view.
// The grid: an hour gutter, the all-day row, timed items side by side, the
// now line, the night hours folded until shown (U-D5), zoom by pinch,
// Ctrl+wheel or buttons. A tap on an empty slot asks what to put there.
// Positions come from calendar_grid.dart (pure); times are the device's
// wall clock resolved by the Time Kernel (deviceStart/deviceEnd).
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:intl/intl.dart';

import '../calendar_grid.dart';
import '../calendar_layout.dart';
import '../l10n.dart';
import '../providers.dart';
import '../schedule_text.dart';

/// The height of one hour in the grid (zoom); kept while the app runs.
final calendarHourHeightProvider =
    StateProvider<double>((ref) => defaultHourHeight);

/// Whether the night hours are shown (hidden by default, U-D5).
final calendarShowNightProvider = StateProvider<bool>((ref) => false);

/// Zooms by [factor], within the limits.
void zoomCalendar(WidgetRef ref, double factor) {
  final n = ref.read(calendarHourHeightProvider.notifier);
  n.state = (n.state * factor).clamp(minHourHeight, maxHourHeight);
}

String _hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

const _gutter = 52.0;
const _bottomClearance = 80.0;

/// The start and end of [e] on the device's wall clock (resolved by the
/// Time Kernel); without them (a fake, or an old row), its own wall clock.
SchedulePointInput _deviceStart(CalendarEntry e) =>
    e.event?.deviceStart ?? e.task?.deviceStart ?? e.start;
SchedulePointInput? _deviceEnd(CalendarEntry e) =>
    (e.event?.deviceStart ?? e.task?.deviceStart) != null
        ? (e.event?.deviceEnd ?? e.task?.deviceEnd)
        : e.end;

class TimeGridView extends ConsumerStatefulWidget {
  const TimeGridView({
    super.key,
    required this.days,
    required this.byDay,
    required this.today,
    required this.block,
    required this.allDay,
    required this.onSlot,
    required this.onDay,
  });
  final List<LocalDate> days;
  final Map<LocalDate, List<CalendarEntry>> byDay;
  final LocalDate today;

  /// A timed item's block (it fills the given box).
  final Widget Function(CalendarEntry entry, double height) block;

  /// An all-day item's chip.
  final Widget Function(CalendarEntry entry) allDay;
  final void Function(LocalDate day, int minute) onSlot;
  final ValueChanged<LocalDate> onDay;

  @override
  ConsumerState<TimeGridView> createState() => _TimeGridViewState();
}

class _TimeGridViewState extends ConsumerState<TimeGridView> {
  final _scroll = ScrollController();
  Timer? _tick;
  final _pointers = <int, Offset>{};
  double? _pinchStart;
  double? _pinchHeight;

  @override
  void initState() {
    super.initState();
    // The now line moves once a minute.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToStart());
  }

  @override
  void didUpdateWidget(TimeGridView old) {
    super.didUpdateWidget(old);
    if (old.days.first != widget.days.first)
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToStart());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  GridScale _scale() {
    final s = ref.read(planningSettingsProvider).valueOrNull;
    final show = ref.read(calendarShowNightProvider);
    return GridScale(
      hourHeight: ref.read(calendarHourHeightProvider),
      hidden: show || s == null
          ? const []
          : hiddenSegments(s.hiddenFrom, s.hiddenTo),
    );
  }

  /// Today: an hour before now; another day: 07:00 (or after the fold).
  void _scrollToStart() {
    if (!mounted || !_scroll.hasClients) return;
    final now = ref.read(nowProvider)();
    final showsToday = widget.days.contains(widget.today);
    final minute = showsToday
        ? (now.hour * 60 + now.minute - 60).clamp(0, minutesPerDay)
        : 7 * 60;
    final y = _scale().yOf(minute);
    _scroll.jumpTo(y.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final p = _pointers.values.toList();
      _pinchStart = (p[0] - p[1]).distance;
      _pinchHeight = ref.read(calendarHourHeightProvider);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _pinchStart, h = _pinchHeight;
    if (_pointers.length == 2 && start != null && start > 0 && h != null) {
      final p = _pointers.values.toList();
      ref.read(calendarHourHeightProvider.notifier).state =
          (h * (p[0] - p[1]).distance / start)
              .clamp(minHourHeight, maxHourHeight);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStart = _pinchHeight = null;
  }

  /// Ctrl + wheel zooms; the plain wheel scrolls.
  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !HardwareKeyboard.instance.isControlPressed)
      return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      if (dy != 0) zoomCalendar(ref, dy < 0 ? 1.15 : 1 / 1.15);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    ref.watch(calendarHourHeightProvider);
    ref.watch(calendarShowNightProvider);
    final settings = ref.watch(planningSettingsProvider).valueOrNull;
    final scale = _scale();
    final now = ref.watch(nowProvider)();
    final nowMinute = now.hour * 60 + now.minute;
    final days = widget.days;
    final allDay = {
      for (final d in days)
        d: [
          for (final e in widget.byDay[d] ?? const <CalendarEntry>[])
            if (e.isAllDay) e
        ]
    };
    final hasAllDay = allDay.values.any((v) => v.isNotEmpty);
    final timed = {
      for (final list in widget.byDay.values)
        for (final e in list)
          if (!e.isAllDay) e.key: e
    }.values;

    Widget dayLabel(LocalDate d) {
      final isToday = d == widget.today;
      return InkWell(
        key: ValueKey('day-header-$d'),
        onTap: () => widget.onDay(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Semantics(
            header: true,
            button: true,
            child: Column(children: [
              Text(weekdayShort(d.weekday), style: theme.textTheme.labelSmall),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: isToday
                    ? BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10))
                    : null,
                child: Text(d.day.toString(),
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: isToday ? theme.colorScheme.onPrimary : null)),
              ),
            ]),
          ),
        ),
      );
    }

    final header = days.length == 1
        ? const SizedBox.shrink()
        : Row(children: [
            const SizedBox(width: _gutter),
            for (final d in days) Expanded(child: dayLabel(d)),
          ]);

    final allDayRow = !hasAllDay
        ? const SizedBox.shrink()
        : Container(
            key: const Key('all-day-row'),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: _gutter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(l.tlAllDay, style: theme.textTheme.labelSmall),
                ),
              ),
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final e in allDay[d]!.take(2)) widget.allDay(e),
                          if (allDay[d]!.length > 2)
                            TextButton(
                              onPressed: () => widget.onDay(d),
                              child:
                                  Text(l.calAllDayMore(allDay[d]!.length - 2)),
                            ),
                        ]),
                  ),
                ),
            ]),
          );

    final folds = scale.hidden;
    final gutter = SizedBox(
      width: _gutter,
      height: scale.height,
      child: Stack(children: [
        for (var h = 1; h < 24; h++)
          if (!folds.any((f) => h * 60 > f.$1 && h * 60 < f.$2) &&
              !folds.any((f) => f.$2 == h * 60))
            Positioned(
              top: scale.yOf(h * 60) - 7,
              right: 6,
              child: Text(_hhmm(h * 60),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
      ]),
    );

    Widget column(LocalDate d, int index) =>
        LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final spans = <DaySpan>[];
          final byKey = <String, CalendarEntry>{};
          // By the DEVICE's date: an item elsewhere can fall on another day here.
          for (final e in timed) {
            final s = daySpan(e.key, _deviceStart(e), _deviceEnd(e), d);
            if (s != null) {
              spans.add(s);
              byKey[e.key] = e;
            }
          }
          final placed = placeSpans(spans);
          return SizedBox(
            height: scale.height,
            child: Stack(children: [
              Positioned.fill(
                child: GestureDetector(
                  key: ValueKey('grid-$d'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (t) {
                    final fold = scale.foldAt(t.localPosition.dy);
                    if (fold != null) {
                      ref.read(calendarShowNightProvider.notifier).state = true;
                    } else {
                      widget.onSlot(d, scale.minuteAt(t.localPosition.dy));
                    }
                  },
                  child: CustomPaint(
                    painter: _GridPainter(scale,
                        line: theme.dividerColor,
                        fold: theme.colorScheme.surfaceContainerHigh,
                        today: d == widget.today
                            ? theme.colorScheme.primary.withValues(alpha: 0.04)
                            : null),
                  ),
                ),
              ),
              if (index == 0 && settings != null)
                for (final f in folds)
                  Positioned(
                    top: scale.yOf(f.$1),
                    height: scale.yOf(f.$2) - scale.yOf(f.$1),
                    left: 4,
                    right: 4,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          l.calNightFold(_hhmm(f.$1), _hhmm(f.$2)),
                          key: const Key('night-fold'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
              for (final p in placed)
                () {
                  final top = scale.yOf(p.span.start);
                  final height = (scale.yOf(p.span.end) - top - 1)
                      .clamp(8.0, double.infinity);
                  return Positioned(
                    top: top,
                    height: height,
                    left: w * p.column / p.columns + 1,
                    width: w / p.columns - 2,
                    child: widget.block(byKey[p.span.key]!, height),
                  );
                }(),
              if (d == widget.today)
                Positioned(
                  key: const Key('now-line'),
                  top: scale.yOf(nowMinute) - 1,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: IgnorePointer(
                    child: Semantics(
                      label: [l.calNow, _hhmm(nowMinute)].join(' '),
                      child: Container(color: theme.colorScheme.error),
                    ),
                  ),
                ),
            ]),
          );
        });

    return Column(children: [
      header,
      allDayRow,
      Expanded(
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerUp,
          onPointerSignal: _onSignal,
          child: SingleChildScrollView(
            key: const Key('calendar-grid'),
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: _bottomClearance),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              gutter,
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(color: theme.dividerColor))),
                    child: column(days[i], i),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.scale,
      {required this.line, required this.fold, this.today});
  final GridScale scale;
  final Color line;
  final Color fold;
  final Color? today;

  @override
  void paint(Canvas canvas, Size size) {
    if (today != null)
      canvas.drawRect(Offset.zero & size, Paint()..color = today!);
    final p = Paint()
      ..color = line
      ..strokeWidth = 0.5;
    for (var h = 0; h <= 24; h++) {
      final y = scale.yOf(h * 60);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    for (final (from, to) in scale.hidden) {
      canvas.drawRect(
          Rect.fromLTRB(0, scale.yOf(from), size.width, scale.yOf(to)),
          Paint()..color = fold);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.scale.hourHeight != scale.hourHeight ||
      old.scale.hidden != scale.hidden ||
      old.today != today;
}

/// Twelve small months (U-D6): a day opens the day view, a month's name the
/// month view.
class YearView extends StatelessWidget {
  const YearView({
    super.key,
    required this.year,
    required this.counts,
    required this.first,
    required this.today,
    required this.onDay,
    required this.onMonth,
  });
  final int year;

  /// Items per day (for the marks).
  final Map<LocalDate, int> counts;
  final Weekday first;
  final LocalDate today;
  final ValueChanged<LocalDate> onDay;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final weekdays = [
      for (var i = 0; i < 7; i++) Weekday.values[(first.index + i) % 7]
    ];
    return LayoutBuilder(builder: (context, box) {
      final perRow = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 600 ? 3 : 2);
      return GridView.count(
        key: const Key('calendar-year'),
        crossAxisCount: perRow,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, _bottomClearance),
        childAspectRatio: perRow == 2 ? 0.78 : 0.9,
        children: [
          for (var m = 1; m <= 12; m++)
            Card(
              margin: const EdgeInsets.all(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(children: [
                  TextButton(
                    key: ValueKey('year-month-$m'),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () => onMonth(m),
                    child: Text(DateFormat.MMMM().format(DateTime(year, m)),
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: today.year == year && today.month == m
                                ? theme.colorScheme.primary
                                : null)),
                  ),
                  Row(children: [
                    for (final w in weekdays)
                      Expanded(
                        child: ExcludeSemantics(
                          child: Text(weekdayShort(w).substring(0, 1),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall),
                        ),
                      ),
                  ]),
                  for (final week in yearMonthGrid(year, m, first))
                    Expanded(
                      child: Row(children: [
                        for (final d in week)
                          Expanded(
                            child: d == null
                                ? const SizedBox.shrink()
                                : Semantics(
                                    button: true,
                                    label: l.calDayItems(
                                        formatDateLong(d, today: today),
                                        counts[d] ?? 0),
                                    excludeSemantics: true,
                                    child: InkWell(
                                      key: ValueKey('year-day-$d'),
                                      customBorder: const CircleBorder(),
                                      onTap: () => onDay(d),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: d == today
                                                  ? BoxDecoration(
                                                      color: theme
                                                          .colorScheme.primary,
                                                      shape: BoxShape.circle)
                                                  : null,
                                              child: Text(d.day.toString(),
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                          color: d == today
                                                              ? theme
                                                                  .colorScheme
                                                                  .onPrimary
                                                              : null)),
                                            ),
                                            if ((counts[d] ?? 0) > 0)
                                              Container(
                                                width: 4,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme.primary,
                                                    shape: BoxShape.circle),
                                              ),
                                          ]),
                                      ),
                                    ),
                                  ),
                          ),
                      ]),
                    ),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

/// The view switcher at the bottom (dogfooding C3): four separate buttons,
/// each on its own translucent background so the content shows around and
/// through them; the selected one is a little stronger, and also bold and
/// marked for screen readers (never colour alone).
class CalendarModeSwitcher extends StatelessWidget {
  const CalendarModeSwitcher({super.key, required this.mode, required this.onChanged});
  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget button(CalendarMode m, String label) {
      final on = m == mode;
      return Semantics(
        button: true,
        selected: on,
        child: Material(
          key: ValueKey('calendar-mode-${m.name}'),
          color: on ? scheme.primaryContainer.withValues(alpha: 0.85) : scheme.surfaceContainerHigh.withValues(alpha: 0.55),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: on ? null : () => onChanged(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(label,
                  style: text.labelLarge?.copyWith(
                      color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
        ),
      );
    }

    // Scales down rather than overflow on a narrow window with large text.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 24),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          key: const Key('calendar-mode'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (m, label) in [
              (CalendarMode.day, l.calDay),
              (CalendarMode.week, l.calWeek),
              (CalendarMode.month, l.calMonth),
              (CalendarMode.year, l.calYear),
            ]) ...[
              if (m != CalendarMode.day) const SizedBox(width: 8),
              button(m, label),
            ],
          ],
        ),
      ),
    );
  }
}