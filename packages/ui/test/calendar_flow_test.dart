// P02 T6b: the Calendar tab with fake ports.
//   D3   weeks start on the device setting (week view, month grid)
//   D4   only this time: skip, cancel, move, rename, undo; or every time
//   D6   tasks stay tasks in the calendar (their own row and actions)
//   D7   overlaps are shown, never resolved
//   D9   Calendar is a tab; it has buttons to the Today and Upcoming lists
//   D10  a new timed event uses the device zone
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'fake_world.dart';
import 'nav.dart';

FakeWorld world({List<TaskView>? tasks}) =>
    FakeWorld(tasks: {'A': tasks ?? []}, profiles: [profile('A', 'Guest')], activeId: 'A');

Future<void> pumpCalendar(WidgetTester tester, FakeWorld w, {double width = 1000, double height = 1000}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
  await goToTab(tester, 'Calendar');
}

LocalDate day(int d, [int m = 11]) => LocalDate(2026, m, d);
TimeOfDayValue at(int h, [int m = 0]) => TimeOfDayValue(h, m);
final mon = testToday; // Monday 2026-11-09

EventItem ev(String id, String title, LocalDate date,
        {TimeOfDayValue? from, TimeOfDayValue? to, String? location, String? calendarId,
        bool repeating = false, bool cancelled = false, bool moved = false}) =>
    EventItem(
      eventId: id,
      title: title,
      originalDate: date,
      start: from == null ? SchedulePointInput.date(date) : SchedulePointInput.at(date, from, testZone),
      end: to == null ? null : SchedulePointInput.at(date, to, testZone),
      location: location,
      calendarId: calendarId,
      isRepeating: repeating,
      isCancelled: cancelled,
      isMoved: moved,
    );

AgendaItem taskAt(String id, String title, LocalDate date, TimeOfDayValue from, TimeOfDayValue to,
        {bool repeating = false}) =>
    AgendaItem(
      taskId: id,
      title: title,
      originalDate: date,
      start: SchedulePointInput.at(date, from, testZone),
      end: SchedulePointInput.at(date, to, testZone),
      isRepeating: repeating,
      isDone: false,
    );

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> mode(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('calendar-mode')), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// P03 UX U5: a timed item is a block in the grid; it opens the full row.
Future<void> openBlock(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey('chip-$key')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('chip-$key')));
  await tester.pumpAndSettle();
}

Future<void> eventAction(WidgetTester tester, String title, String action) async {
  await tester.tap(find.byTooltip('Actions for $title').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

void main() {
  group('views and navigation', () {
    testWidgets('wide: a month grid from Monday by default; prev and next', (tester) async {
      final w = world();
      await pumpCalendar(tester, w);
      expect(find.byKey(const Key('calendar-month')), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);
      expect(w.calendar.ranges.last, '2026-10-26..2026-12-06');
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(find.text('December 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-go-today')));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('weeks start on Sunday when Settings say so (D3)', (tester) async {
      final w = world();
      w.planning = const PlanningSettings(firstDayOfWeek: Weekday.sunday);
      await pumpCalendar(tester, w);
      expect(w.calendar.ranges.last, '2026-11-01..2026-12-12');
      final month = find.byKey(const Key('calendar-month'));
      expect(tester.getTopLeft(find.descendant(of: month, matching: find.text('Sun'))).dx,
          lessThan(tester.getTopLeft(find.descendant(of: month, matching: find.text('Mon'))).dx));
      await mode(tester, 'Week');
      expect(find.text('8 – 14 Nov 2026'), findsOneWidget);
      expect(w.calendar.ranges.last, '2026-11-08..2026-11-14');
    });

    testWidgets('phone: the week is a time grid of seven days; tapping a day opens it', (tester) async {
      final w = world();
      w.calendar.range = CalendarRange(
          events: [ev('e1', 'Dentist', day(11), from: at(14), to: at(15))], tasks: const [], conflicts: const []);
      await pumpCalendar(tester, w, width: 400, height: 900);
      expect(find.byKey(const Key('calendar-grid')), findsOneWidget);
      expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
      expect(find.byKey(ValueKey('chip-event:e1@${day(11)}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('day-header-${day(11)}')));
      await tester.pumpAndSettle();
      expect(find.text('Wed 11 Nov 2026'), findsOneWidget);
      expect(w.calendar.ranges.last, '2026-11-11..2026-11-11');
      expect(tester.takeException(), isNull);
    });

    testWidgets('wide week: seven columns; a block opens the full row', (tester) async {
      final w = world();
      w.calendar.range = CalendarRange(
          events: [ev('e1', 'Dentist', day(11), from: at(14), to: at(15), location: 'Clinic')],
          tasks: const [],
          conflicts: const []);
      await pumpCalendar(tester, w, width: 1200);
      await mode(tester, 'Week');
      expect(find.byKey(const Key('calendar-grid')), findsOneWidget);
      await openBlock(tester, 'event:e1@${day(11)}');
      expect(find.text('14:00–15:00 · Clinic'), findsOneWidget);
    });

    testWidgets('a month cell opens its day', (tester) async {
      final w = world();
      await pumpCalendar(tester, w);
      await tester.tap(find.byKey(ValueKey('month-cell-${day(20)}')));
      await tester.pumpAndSettle();
      expect(find.text('Fri 20 Nov 2026'), findsOneWidget);
      expect(find.byKey(const Key('calendar-grid')), findsOneWidget);
      expect(find.byKey(const Key('now-line')), findsNothing); // not today
    });

    testWidgets("buttons open the Timeline on today and on tomorrow (U4)", (tester) async {
      final w = world();
      await pumpCalendar(tester, w);
      // P03 UX U4: both open the Timeline, on today or on tomorrow.
      await tapKey(tester, 'calendar-today-tasks');
      expect(find.byKey(const Key('timeline-month')), findsOneWidget);
      expect(find.byKey(ValueKey('day-$testToday')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pumpAndSettle();
      // From the day view, it opens on the day shown.
      await mode(tester, 'Day');
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'calendar-today-tasks');
      expect(find.byKey(ValueKey('day-${testToday.addDays(1)}')), findsOneWidget);
      // At the top of the list, under the app bar.
      expect(tester.getTopLeft(find.byKey(ValueKey('day-${testToday.addDays(1)}'))).dy, lessThan(300));
    });

    testWidgets('a cut-off range says so', (tester) async {
      final w = world();
      w.calendar.range = const CalendarRange(events: [], tasks: [], conflicts: [], truncated: true);
      await pumpCalendar(tester, w);
      expect(find.byKey(const Key('calendar-truncated')), findsOneWidget);
    });
  });

  group('day view: events, tasks, overlaps', () {
    testWidgets('a task keeps its own row; overlaps are shown on both (D6, D7)', (tester) async {
      final w = world(tasks: [task('t', 'Gym')]);
      w.calendar.range = CalendarRange(
        events: [ev('e1', 'Standup', mon, from: at(9), to: at(10)), ev('e2', 'Holiday', mon)],
        tasks: [taskAt('t', 'Gym', mon, at(9, 30), at(10, 30), repeating: true)],
        conflicts: [ConflictView('event:e1@$mon', 'task:t@$mon')],
      );
      await pumpCalendar(tester, w);
      await mode(tester, 'Day');
      expect(find.text('Mon 9 Nov 2026'), findsOneWidget);
      // P03 UX U5: the all-day item above the grid; the two that overlap side by side.
      expect(find.descendant(of: find.byKey(const Key('all-day-row')), matching: find.text('Holiday')), findsOneWidget);
      final standup = tester.getRect(find.byKey(ValueKey('chip-event:e1@$mon')));
      final gym = tester.getRect(find.byKey(ValueKey('chip-task:t@$mon')));
      expect(standup.right, lessThanOrEqualTo(gym.left + 1));
      expect(standup.top, lessThan(gym.top));
      // The full rows show the overlaps; the task ticks one occurrence (D5).
      await openBlock(tester, 'event:e1@$mon');
      expect(find.text('Overlaps Gym'), findsOneWidget);
      Navigator.of(tester.element(find.text('Overlaps Gym'))).pop();
      await tester.pumpAndSettle();
      await openBlock(tester, 'task:t@$mon');
      expect(find.text('Overlaps Standup'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Complete Gym'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'occurrenceDone:t@$mon:true');
    });

    testWidgets('a cancelled event is marked, and can be un-cancelled', (tester) async {
      final w = world();
      w.calendar.range =
          CalendarRange(events: [ev('e1', 'Party', mon, from: at(20), cancelled: true)], tasks: const [], conflicts: const []);
      await pumpCalendar(tester, w);
      await mode(tester, 'Day');
      await openBlock(tester, 'event:e1@$mon');
      expect(find.text('20:00 · Cancelled'), findsOneWidget);
      await eventAction(tester, 'Party', 'Un-cancel the event');
      expect(w.calls.last, 'event.cancelled:e1:false');
    });
  });

  group('only this time, or every time (D4)', () {
    late FakeWorld w;
    Future<void> setUpDay(WidgetTester tester, {bool moved = false}) async {
      w = world();
      w.calendar.range = CalendarRange(
          events: [ev('e1', 'Class', mon, from: at(18), to: at(19), repeating: true, moved: moved)],
          tasks: const [],
          conflicts: const []);
      await pumpCalendar(tester, w);
      await mode(tester, 'Day');
      await openBlock(tester, 'event:e1@$mon');
    }

    testWidgets('skip, cancel, move and rename one time', (tester) async {
      await setUpDay(tester);
      expect(find.text('Undo the change to this time'), findsNothing);
      await eventAction(tester, 'Class', 'Skip this time');
      expect(w.calls.last, 'event.change:e1@$mon:skip');
      await eventAction(tester, 'Class', 'Cancel this time');
      expect(w.calls.last, 'event.change:e1@$mon:cancel');
      await eventAction(tester, 'Class', 'Move this time…');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'event.change:e1@$mon:move>$mon');
      await eventAction(tester, 'Class', 'Rename this time…');
      await tester.enterText(find.byType(TextField), 'Exam');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'event.change:e1@$mon:edit>Exam');
    });

    testWidgets('undo a change to one time; cancel every time', (tester) async {
      await setUpDay(tester, moved: true);
      await eventAction(tester, 'Class', 'Undo the change to this time');
      expect(w.calls.last, 'event.change:e1@$mon:undo');
      await eventAction(tester, 'Class', 'Cancel every time');
      expect(w.calls.last, 'event.cancelled:e1:true');
    });

    testWidgets('trash with undo', (tester) async {
      await setUpDay(tester);
      await eventAction(tester, 'Class', 'Move to trash');
      expect(w.calls.last, 'event.trash:e1');
      expect(find.text('Event moved to the trash.'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'event.restore:e1');
    });

    testWidgets('a refused change is reported', (tester) async {
      await setUpDay(tester);
      w.calendar.failNext =
          const CommandFailure(CommandFailureKind.validationFailed, reason: 'not an occurrence of this event');
      await eventAction(tester, 'Class', 'Skip this time');
      expect(find.text('Not an occurrence of this event.'), findsOneWidget);
    });
  });

  group('event editor', () {
    testWidgets('a new event: 09:00–10:00 in the device zone on the shown day (D10)', (tester) async {
      final w = world();
      w.calendar.calendars.add(const CalendarView(id: 'cal-work', name: 'Work', color: 0xFF1E88E5));
      await pumpCalendar(tester, w);
      await mode(tester, 'Day');
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New event'));
      await tester.pumpAndSettle();
      expect(find.text('$testZone (this device)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('event-title')), 'Review');
      await tester.enterText(find.byKey(const Key('event-location')), 'Room 2');
      await tester.tap(find.byKey(const Key('event-calendar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'event-save');
      expect(w.calls.last,
          'event.create:Review|2026-11-10T09:00[$testZone]|2026-11-10T10:00[$testZone]|Room 2|cal-work|-');
      expect(find.byKey(const Key('event-save')), findsNothing); // closed
    });

    testWidgets('all day, repeating weekly; the start cannot be removed', (tester) async {
      final w = world();
      await pumpCalendar(tester, w);
      await mode(tester, 'Day');
      await tester.tap(find.byTooltip('New event'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-start-clear')), findsNothing);
      await tester.enterText(find.byKey(const Key('event-title')), 'Market');
      await tapKey(tester, 'event-start-clear-time');
      await tapKey(tester, 'event-end-clear');
      expect(find.textContaining('All-day events never count as overlapping'), findsOneWidget);
      await tapKey(tester, 'repeat-switch');
      await tester.tap(find.byKey(const Key('repeat-frequency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('week').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'event-save');
      expect(w.calls.last, 'event.create:Market|2026-11-09|-|-|-|weekly/1');
    });

    testWidgets('no title: asked for before any command; a refusal is shown', (tester) async {
      final w = world();
      await pumpCalendar(tester, w);
      await tester.tap(find.byTooltip('New event'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'event-save');
      expect(find.text('Enter a title.'), findsOneWidget);
      expect(w.calls, isEmpty);
      await tester.enterText(find.byKey(const Key('event-title')), 'X');
      w.calendar.failNext =
          const CommandFailure(CommandFailureKind.validationFailed, reason: 'the end is before the start');
      await tapKey(tester, 'event-save');
      expect(find.text('The end is before the start.'), findsOneWidget);
      expect(find.byKey(const Key('event-save')), findsOneWidget);
    });

    testWidgets('editing changes every time and keeps the repeat', (tester) async {
      final w = world();
      final input = EventInput(
        title: 'Class',
        start: SchedulePointInput.at(mon, at(18), testZone),
        end: SchedulePointInput.at(mon, at(19), testZone),
        repeat: const RepeatInput(frequency: RepeatFrequency.weekly),
      );
      w.calendar.events['e1'] = EventDetails(id: 'e1', input: input, isCancelled: false);
      w.calendar.range = CalendarRange(
          events: [ev('e1', 'Class', mon, from: at(18), to: at(19), repeating: true)],
          tasks: const [],
          conflicts: const []);
      await pumpCalendar(tester, w);
      await mode(tester, 'Day');
      await openBlock(tester, 'event:e1@$mon');
      await tester.tap(find.text('Class').last); // the full row opens the editor
      await tester.pumpAndSettle();
      expect(find.textContaining('apply to every time this event repeats'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('event-title')), 'Class B');
      await tapKey(tester, 'event-save');
      expect(w.calls.last,
          'event.update:e1:Class B|2026-11-09T18:00[$testZone]|2026-11-09T19:00[$testZone]|-|-|weekly/1');
    });
  });

  group('calendars', () {
    testWidgets('add, edit and trash a calendar', (tester) async {
      final w = world();
      await pumpCalendar(tester, w);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage calendars'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No calendars yet'), findsOneWidget);

      await tapKey(tester, 'calendar-add');
      await tester.enterText(find.byKey(const Key('calendar-name')), 'Work');
      await tester.tap(find.byKey(const ValueKey('color-Blue')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'calendar.create:Work:ff1e88e5');
      expect(find.text('Work'), findsOneWidget);

      await tester.tap(find.byTooltip('Edit Work'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('calendar-name')), 'Job');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(w.calls.last, startsWith('calendar.update:cal0:Job:'));

      await tester.tap(find.byTooltip('Move Job to the trash'));
      await tester.pumpAndSettle();
      expect(find.text('Its events stay, without a calendar.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Move to trash'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'calendar.trash:cal0');
      expect(find.text('Job'), findsNothing);
    });
  });

  testWidgets('phone month with a large font: no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final w = world();
    w.calendar.range = CalendarRange(
      events: [for (var i = 0; i < 5; i++) ev('e$i', 'Event $i', mon, from: at(8 + i))],
      tasks: const [],
      conflicts: const [],
    );
    await pumpCalendar(tester, w, width: 360, height: 760);
    await mode(tester, 'Month');
    expect(find.byKey(const Key('calendar-month')), findsOneWidget);
    expect(find.bySemanticsLabel('Mon 9 Nov, 5 items'), findsOneWidget);
    await mode(tester, 'Day');
    expect(tester.takeException(), isNull);
  });
}
