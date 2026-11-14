// P03 UX U5 (ADR-0049): the Calendar's time grid and year view with fake
// ports: the year view and its links, the night fold (U-D5), zoom by
// button, Ctrl+wheel and pinch, the now line, and taps on empty slots.
import 'package:application/application.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'fake_world.dart';
import 'nav.dart';

final mon = testToday; // Monday 2026-11-09
final thu = mon.addDays(3);

FakeWorld world({List<EventItem> events = const [], List<TaskView>? tasks}) {
  final w = FakeWorld(tasks: {'A': tasks ?? []}, profiles: [profile('A', 'Guest')], activeId: 'A');
  w.calendar.range = CalendarRange(events: events, tasks: const [], conflicts: const []);
  return w;
}

EventItem ev(String id, String title, LocalDate d, int from, int to) => EventItem(
      eventId: id,
      title: title,
      originalDate: d,
      start: SchedulePointInput.at(d, TimeOfDayValue(from, 0), testZone),
      end: SchedulePointInput.at(d, TimeOfDayValue(to, 0), testZone),
      isRepeating: false,
    );

Future<void> pumpCalendar(WidgetTester tester, FakeWorld w, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
  await goToTab(tester, 'Calendar');
}

Future<void> mode(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('calendar-mode')), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// The day view of [d] (from the month grid).
Future<void> openDay(WidgetTester tester, LocalDate d) async {
  await tester.tap(find.byKey(ValueKey('month-cell-$d')));
  await tester.pumpAndSettle();
}

double blockHeight(WidgetTester tester, String key) => tester.getSize(find.byKey(ValueKey('chip-$key'))).height;

/// Taps the grid of [d] at [minute] (no night fold shown above it: 00-06
/// folded into 28 px, then 48 px per hour).
Future<void> tapSlot(WidgetTester tester, LocalDate d, int minute) async {
  final grid = find.byKey(ValueKey('grid-$d'));
  final y = 28 + (minute - 360) * 48 / 60 + 4;
  await tester.tapAt(tester.getTopLeft(grid) + Offset(30, y));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the year: twelve months; a day opens the day view, a month the month view (U-D6)', (tester) async {
    final w = world(events: [ev('e1', 'Dentist', thu, 14, 15)]);
    await pumpCalendar(tester, w);
    await mode(tester, 'Year');
    expect(find.byKey(const Key('calendar-year')), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(w.calendar.ranges.last, '2026-01-01..2026-12-31');
    expect(find.bySemanticsLabel('Thu 12 Nov, 1 item'), findsOneWidget);
    expect(find.bySemanticsLabel('Fri 13 Nov, nothing planned'), findsOneWidget);
    await tester.ensureVisible(find.byKey(ValueKey('year-day-$thu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('year-day-$thu')));
    await tester.pumpAndSettle();
    expect(find.text('Thu 12 Nov 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('chip-event:e1@2026-11-12')), findsOneWidget);
    await mode(tester, 'Year');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('year-month-3')), -200,
        scrollable: find.descendant(of: find.byKey(const Key('calendar-year')), matching: find.byType(Scrollable)));
    await tester.tap(find.byKey(const ValueKey('year-month-3')));
    await tester.pumpAndSettle();
    expect(find.text('March 2026'), findsOneWidget);
    expect(find.byKey(const Key('calendar-month')), findsOneWidget);
  });

  testWidgets('the night hours are folded until shown (U-D5)', (tester) async {
    final w = world(events: [ev('n', 'Night flight', thu, 3, 4), ev('d', 'Lunch', thu, 12, 13)]);
    await pumpCalendar(tester, w);
    await openDay(tester, thu);
    await tester.drag(find.byKey(const Key('calendar-grid')), const Offset(0, 2000)); // to the top
    await tester.pumpAndSettle();
    expect(find.text('00:00–06:00 hidden. Show'), findsOneWidget);
    expect(blockHeight(tester, 'event:n@$thu'), lessThan(20));
    expect(blockHeight(tester, 'event:d@$thu'), closeTo(47, 1));
    await tester.tap(find.byKey(const Key('night-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('00:00–06:00 hidden. Show'), findsNothing);
    expect(blockHeight(tester, 'event:n@$thu'), closeTo(47, 1));
    // A tap on the fold shows the hours too.
    await tester.tap(find.byKey(const Key('night-toggle')));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('calendar-grid')), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('grid-$thu'))) + const Offset(30, 10));
    await tester.pumpAndSettle();
    expect(blockHeight(tester, 'event:n@$thu'), closeTo(47, 1));
    expect(find.byKey(const Key('slot-title')), findsNothing); // not a slot
  });

  testWidgets('a hidden range set in Settings is the one folded', (tester) async {
    final w = world(events: [ev('n', 'Night flight', thu, 3, 4)]);
    w.planning = const PlanningSettings(hiddenFrom: 22 * 60, hiddenTo: 2 * 60);
    await pumpCalendar(tester, w);
    await openDay(tester, thu);
    await tester.drag(find.byKey(const Key('calendar-grid')), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text('00:00–02:00 hidden. Show'), findsOneWidget);
    expect(blockHeight(tester, 'event:n@$thu'), closeTo(47, 1)); // 03:00 is not hidden
  });

  testWidgets('zoom: buttons, Ctrl+wheel and pinch change the hour height', (tester) async {
    final w = world(events: [ev('d', 'Lunch', thu, 12, 13)]);
    await pumpCalendar(tester, w);
    await openDay(tester, thu);
    final h0 = blockHeight(tester, 'event:d@$thu');
    await tester.tap(find.byKey(const Key('zoom-in')));
    await tester.pumpAndSettle();
    final h1 = blockHeight(tester, 'event:d@$thu');
    expect(h1, greaterThan(h0 * 1.2));
    await tester.tap(find.byKey(const Key('zoom-out')));
    await tester.pumpAndSettle();
    expect(blockHeight(tester, 'event:d@$thu'), closeTo(h0, 1));

    // Ctrl + wheel up zooms in; the wheel alone does not.
    final center = tester.getCenter(find.byKey(const Key('calendar-grid')));
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -50)));
    await tester.pumpAndSettle();
    expect(blockHeight(tester, 'event:d@$thu'), closeTo(h0, 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -50)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(blockHeight(tester, 'event:d@$thu'), greaterThan(h0 * 1.1));

    // Two fingers apart zoom in.
    final before = blockHeight(tester, 'event:d@$thu');
    final a = await tester.startGesture(center - const Offset(0, 40), pointer: 7);
    final b = await tester.startGesture(center + const Offset(0, 40), pointer: 8);
    await a.moveBy(const Offset(0, -60));
    await b.moveBy(const Offset(0, 60));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(blockHeight(tester, 'event:d@$thu'), greaterThan(before * 1.5));
  });

  testWidgets('an item in another zone sits at the device time (from the Time Kernel)', (tester) async {
    final berlin = EventItem(
      eventId: 'b',
      title: 'Call Berlin',
      originalDate: thu,
      start: SchedulePointInput.at(thu, TimeOfDayValue(9, 0), 'Europe/Berlin'),
      end: SchedulePointInput.at(thu, TimeOfDayValue(10, 0), 'Europe/Berlin'),
      isRepeating: false,
      deviceStart: SchedulePointInput.at(thu, TimeOfDayValue(15, 0), testZone),
      deviceEnd: SchedulePointInput.at(thu, TimeOfDayValue(16, 0), testZone),
    );
    final w = world(events: [berlin, ev('l', 'Local', thu, 15, 16)]);
    await pumpCalendar(tester, w);
    await openDay(tester, thu);
    final a = tester.getRect(find.byKey(ValueKey('chip-event:b@$thu')));
    final b = tester.getRect(find.byKey(ValueKey('chip-event:l@$thu')));
    expect(a.top, closeTo(b.top, 1)); // same device time: side by side
    expect(a.right, lessThanOrEqualTo(b.left + 1));
  });

  testWidgets('the now line is on today only', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await openDay(tester, mon);
    expect(find.byKey(const Key('now-line')), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-line')), findsNothing);
    await mode(tester, 'Week');
    expect(find.byKey(const Key('now-line')), findsOneWidget); // Monday is in this week
  });

  testWidgets('an empty slot: a new event there', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await openDay(tester, thu);
    await tapSlot(tester, thu, 14 * 60 + 30);
    expect(find.text('Thu 12 Nov at 14:30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('slot-event')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Review');
    await tester.ensureVisible(find.byKey(const Key('event-save')));
    await tester.tap(find.byKey(const Key('event-save')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'event.create:Review|2026-11-12T14:30[$testZone]|2026-11-12T15:30[$testZone]|-|-|-');
  });

  testWidgets('an empty slot: a new task there, or an open task scheduled there', (tester) async {
    final w = world(tasks: [task('t', 'Write report'), task('s', 'Planned', schedule: TaskScheduleInput(start: SchedulePointInput.date(mon)))]);
    await pumpCalendar(tester, w);
    await openDay(tester, thu);
    await tapSlot(tester, thu, 9 * 60);
    await tester.tap(find.byKey(const Key('slot-task')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Call');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(w.calls.sublist(w.calls.length - 2), [
      'create:Call:null',
      'setSchedule:new0:start=2026-11-12T09:00[$testZone];end=-;due=-;repeat=-',
    ]);

    await tapSlot(tester, thu, 16 * 60);
    await tester.tap(find.byKey(const Key('slot-schedule')));
    await tester.pumpAndSettle();
    // Only open tasks without a schedule are offered.
    expect(find.byKey(const ValueKey('pick-task-s')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pick-task-t')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'setSchedule:t:start=2026-11-12T16:00[$testZone];end=-;due=-;repeat=-');
  });

  testWidgets('phone: four separate view buttons fit, with a large font', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final w = world(events: [ev('d', 'Lunch', thu, 12, 13)]);
    await pumpCalendar(tester, w, width: 360);
    // C3: four separate buttons, inside the window, no + button beside them.
    final switcher = tester.getRect(find.byKey(const Key('calendar-mode')));
    expect(switcher.left, greaterThanOrEqualTo(0));
    expect(switcher.right, lessThanOrEqualTo(360));
    for (final m in ['day', 'week', 'month', 'year']) {
      expect(find.byKey(ValueKey('calendar-mode-$m')), findsOneWidget);
    }
    final day = tester.getRect(find.byKey(const ValueKey('calendar-mode-day')));
    final week = tester.getRect(find.byKey(const ValueKey('calendar-mode-week')));
    expect(week.left, greaterThan(day.right), reason: 'separate buttons');
    await mode(tester, 'Year');
    await mode(tester, 'Day');
    expect(tester.takeException(), isNull);
  });
}
