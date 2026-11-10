// P02 T6a: task schedules in the UI, with fake ports.
//   D2/D3   new repeats take the month-end rule and week start from Settings;
//           an existing repeat keeps its own
//   D4      skip / move only this occurrence
//   D5      ticking a repeating task marks only that occurrence done
//   D9      Today and Upcoming are filters of Tasks
//   D10     new timed items use the device zone, changeable in the editor
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'fake_world.dart';

FakeWorld world(List<TaskView> tasks) =>
    FakeWorld(tasks: {'A': tasks}, profiles: [profile('A', 'Guest')], activeId: 'A');

Future<void> pumpApp(WidgetTester tester, FakeWorld w, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

final mon = testToday; // 2026-11-09
LocalDate day(int d) => LocalDate(2026, 11, d);
TimeOfDayValue at(int h, [int m = 0]) => TimeOfDayValue(h, m);

Future<void> openEditor(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Actions for $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Schedule…').last);
  await tester.pumpAndSettle();
}

Future<void> pickerOk(WidgetTester tester) async {
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('schedule-save')));
  await tester.pumpAndSettle();
}

AgendaItem item(String id, String title, LocalDate date,
        {TimeOfDayValue? time, bool repeating = false, bool done = false, bool overdue = false, bool moved = false}) =>
    AgendaItem(
      taskId: id,
      title: title,
      originalDate: date,
      start: time == null ? SchedulePointInput.date(date) : SchedulePointInput.at(date, time, testZone),
      isRepeating: repeating,
      isDone: done,
      isOverdue: overdue,
      isMoved: moved,
    );

void main() {
  group('All: schedule summary on the row', () {
    testWidgets('date, time and repeat; the device zone is not repeated', (tester) async {
      await pumpApp(
          tester,
          world([
            task('a', 'Gym',
                schedule: TaskScheduleInput(
                  start: SchedulePointInput.at(day(10), at(9), testZone),
                  repeat: const RepeatInput(
                      frequency: RepeatFrequency.weekly, weekdays: {Weekday.wednesday, Weekday.monday}),
                )),
            task('b', 'Plain'),
          ]));
      expect(find.text('Start Tomorrow 09:00 · Every week on Mon, Wed'), findsOneWidget);
      expect(find.byKey(const ValueKey('schedule-b')), findsNothing);
    });

    testWidgets('a foreign zone, a same-day range and a deadline', (tester) async {
      await pumpApp(
          tester,
          world([
            task('a', 'Call Berlin',
                schedule: TaskScheduleInput(
                  start: SchedulePointInput.at(day(12), at(14), 'Europe/Berlin'),
                  end: SchedulePointInput.at(day(12), at(15), 'Europe/Berlin'),
                )),
            task('b', 'Report', schedule: TaskScheduleInput(deadline: SchedulePointInput.date(day(13)))),
          ]));
      expect(find.text('Thu 12 Nov 14:00 (Europe/Berlin)–15:00'), findsOneWidget);
      expect(find.text('Due Fri 13 Nov'), findsOneWidget);
    });
  });

  group('schedule editor', () {
    testWidgets('a start date and time in the device zone (D10)', (tester) async {
      final w = world([task('a', 'Gym')]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Gym');
      await tapKey(tester, 'start-date');
      await pickerOk(tester); // today
      await tapKey(tester, 'start-time');
      await pickerOk(tester); // 09:00
      expect(find.text('$testZone (this device)'), findsOneWidget);
      await save(tester);
      expect(w.calls.last, 'setSchedule:a:start=2026-11-09T09:00[$testZone];end=-;due=-;repeat=-');
      expect(find.text('Start Today 09:00'), findsOneWidget);
    });

    testWidgets('the zone can be changed in the editor (D10)', (tester) async {
      final w = world([task('a', 'Call')]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await tapKey(tester, 'due-date');
      await pickerOk(tester);
      // No time yet: no zone to choose.
      expect(find.byKey(const Key('schedule-zone')), findsNothing);
      await tapKey(tester, 'due-time');
      await pickerOk(tester);
      await tapKey(tester, 'schedule-zone');
      await tester.enterText(find.byKey(const Key('zone-search')), 'berl');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('zone-UTC')), findsNothing);
      await tester.tap(find.byKey(const Key('zone-Europe/Berlin')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(w.calls.last, 'setSchedule:a:start=-;end=-;due=2026-11-09T09:00[Europe/Berlin];repeat=-');
    });

    testWidgets('a new repeat takes month-end rule and week start from Settings (D2/D3)', (tester) async {
      final w = world([task('a', 'Gym')]);
      w.planning = const PlanningSettings(defaultMonthEnd: MonthEndChoice.lastDay, firstDayOfWeek: Weekday.sunday);
      await pumpApp(tester, w);
      await openEditor(tester, 'Gym');
      await tapKey(tester, 'start-date');
      await pickerOk(tester);
      await tapKey(tester, 'repeat-switch');
      await tester.tap(find.byKey(const Key('repeat-frequency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('week').last);
      await tester.pumpAndSettle();
      // The week is shown from the first day of the week in Settings.
      expect(tester.getTopLeft(find.byKey(const Key('weekday-sunday'))).dx,
          lessThan(tester.getTopLeft(find.byKey(const Key('weekday-monday'))).dx));
      await tapKey(tester, 'weekday-wednesday');
      await tapKey(tester, 'weekday-friday');
      await tapKey(tester, 'repeat-end-afterCount');
      await tester.enterText(find.byKey(const Key('repeat-count')), '5');
      await save(tester);
      expect(w.calls.last,
          'setSchedule:a:start=2026-11-09;end=-;due=-;repeat=weekly/1/wednesday+friday/5 times/lastDay/sunday');
    });

    testWidgets('an existing repeat keeps its own month-end rule', (tester) async {
      final w = world([
        task('a', 'Rent',
            schedule: TaskScheduleInput(
              start: SchedulePointInput.date(LocalDate(2026, 1, 31)),
              repeat: const RepeatInput(frequency: RepeatFrequency.monthly, monthEnd: MonthEndChoice.skip),
            )),
      ]);
      w.planning = const PlanningSettings(defaultMonthEnd: MonthEndChoice.lastDay);
      await pumpApp(tester, w);
      await openEditor(tester, 'Rent');
      expect(tester.widget<RadioListTile<MonthEndChoice>>(find.byKey(const Key('month-end-skip'))).value,
          MonthEndChoice.skip);
      await save(tester);
      expect(w.calls.last, 'setSchedule:a:start=2026-01-31;end=-;due=-;repeat=monthly/1/-/forever/skip/monday');
      // Changing it for this repeat is possible.
      await openEditor(tester, 'Rent');
      await tapKey(tester, 'month-end-lastDay');
      await save(tester);
      expect(w.calls.last, endsWith('/lastDay/monday'));
    });

    testWidgets('a refused schedule shows the reason and the editor stays open', (tester) async {
      final w = world([task('a', 'Gym')]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Gym');
      await tapKey(tester, 'start-date');
      await pickerOk(tester);
      w.failNext = const CommandFailure(CommandFailureKind.validationFailed, reason: 'the end is before the start');
      await save(tester);
      expect(find.text('The end is before the start.'), findsOneWidget);
      expect(find.byKey(const Key('schedule-save')), findsOneWidget);
    });

    testWidgets('an incomplete repeat end is caught before any command', (tester) async {
      final w = world([task('a', 'Gym')]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Gym');
      await tapKey(tester, 'start-date');
      await pickerOk(tester);
      await tapKey(tester, 'repeat-switch');
      await tapKey(tester, 'repeat-end-onDate');
      await save(tester);
      expect(find.text('Choose the date the repeat ends.'), findsOneWidget);
      expect(w.calls.where((c) => c.startsWith('setSchedule')), isEmpty);
    });

    testWidgets('remove schedule is offered only when there is one', (tester) async {
      final w = world([
        task('a', 'Gym', schedule: TaskScheduleInput(start: SchedulePointInput.date(day(10)))),
        task('b', 'Plain'),
      ]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Plain');
      expect(find.byKey(const Key('schedule-remove')), findsNothing);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls, isEmpty);
      await openEditor(tester, 'Gym');
      await tapKey(tester, 'schedule-remove');
      expect(w.calls.last, 'setSchedule:a:none');
      expect(find.text('Start Tomorrow'), findsNothing);
    });
  });

  group('Today and Upcoming (D9)', () {
    Future<void> show(WidgetTester tester, String filter) async {
      await tester.tap(find.text(filter));
      await tester.pumpAndSettle();
    }

    testWidgets('Today lists overdue first, then today in time order', (tester) async {
      final w = world([task('o', 'Late'), task('r', 'Gym'), task('t', 'Call')]);
      w.today = Agenda([
        item('o', 'Late', day(6), overdue: true),
        item('t', 'Call', mon, time: at(8)),
        item('r', 'Gym', mon, time: at(18), repeating: true),
      ]);
      await pumpApp(tester, w);
      await show(tester, 'Today');
      final y = [
        for (final t in ['Overdue', 'Late', 'Today · Mon 9 Nov', 'Call', 'Gym'])
          tester.getTopLeft(find.text(t)).dy
      ];
      expect(y, orderedEquals([...y]..sort()));
      expect(find.text('Planned Fri 6 Nov'), findsOneWidget);
      expect(find.text('18:00 · Repeats'), findsOneWidget);
    });

    testWidgets('ticking a repeating task marks only that occurrence (D5)', (tester) async {
      final w = world([task('r', 'Gym'), task('t', 'Call')]);
      w.today = Agenda([
        item('r', 'Gym', mon, repeating: true),
        item('t', 'Call', mon),
      ]);
      await pumpApp(tester, w);
      await show(tester, 'Today');
      await tester.tap(find.bySemanticsLabel('Complete Gym'));
      await tester.pumpAndSettle();
      expect(w.calls, ['occurrenceDone:r@2026-11-09:true']);
      await tester.tap(find.bySemanticsLabel('Mark as not done: Gym'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'occurrenceDone:r@2026-11-09:false');
      // A one-off is completed as a task.
      await tester.tap(find.bySemanticsLabel('Complete Call'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'complete:t:false');
    });

    testWidgets('Upcoming groups by date; skip and move only this time (D4)', (tester) async {
      final w = world([task('r', 'Gym')]);
      w.upcoming = Agenda([
        item('r', 'Gym', day(10), repeating: true),
        item('r', 'Gym', day(11), repeating: true, moved: true),
      ]);
      await pumpApp(tester, w);
      await show(tester, 'Upcoming');
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Wed 11 Nov'), findsOneWidget);
      expect(find.text('Repeats · Moved'), findsOneWidget);

      await tester.tap(find.byTooltip('Actions for Gym').first);
      await tester.pumpAndSettle();
      expect(find.text('Undo the change to this time'), findsNothing);
      await tester.tap(find.text('Skip this time'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'change:r@2026-11-10:skip');

      await tester.tap(find.byTooltip('Actions for Gym').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move this time…'));
      await tester.pumpAndSettle();
      await pickerOk(tester); // keeps the date: still a valid move
      expect(w.calls.last, 'change:r@2026-11-10:move>2026-11-10');

      await tester.tap(find.byTooltip('Actions for Gym').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo the change to this time'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'change:r@2026-11-11:undo');
    });

    testWidgets('an empty day says so; a cut-off list says so', (tester) async {
      final w = world([]);
      await pumpApp(tester, w);
      await show(tester, 'Today');
      expect(find.byKey(const Key('agenda-empty')), findsOneWidget);
      expect(find.byKey(const Key('agenda-truncated')), findsNothing);
      w.today = const Agenda([], truncated: true);
      w.calls.add('poke');
      await w.setOccurrenceDone('x', mon, done: true); // emits a change
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agenda-truncated')), findsOneWidget);
    });

    testWidgets('a task added in Today is planned for today; in Upcoming for tomorrow', (tester) async {
      final w = world([]);
      await pumpApp(tester, w);
      Future<void> add(String title) async {
        await tester.tap(find.byTooltip('Add task'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), title);
        await tester.tap(find.widgetWithText(FilledButton, 'Add'));
        await tester.pumpAndSettle();
      }

      await show(tester, 'Today');
      await add('Now');
      expect(w.calls, ['create:Now:null', 'setSchedule:new0:start=2026-11-09;end=-;due=-;repeat=-']);
      await show(tester, 'Upcoming');
      await add('Later');
      expect(w.calls.last, 'setSchedule:new1:start=2026-11-10;end=-;due=-;repeat=-');
      await show(tester, 'All');
      await add('Someday');
      expect(w.calls.last, 'create:Someday:null');
    });
  });

  testWidgets('phone width: filter bar, editor and agenda fit without overflow', (tester) async {
    final w = world([task('a', 'A task with a rather long title for a phone')]);
    w.today = Agenda([item('a', 'A task with a rather long title for a phone', mon, time: at(9), repeating: true)]);
    await pumpApp(tester, w, width: 360);
    await openEditor(tester, 'A task with a rather long title for a phone');
    await tapKey(tester, 'start-date');
    await pickerOk(tester);
    await tapKey(tester, 'start-time');
    await pickerOk(tester);
    await tapKey(tester, 'repeat-switch');
    await save(tester);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('09:00 · Repeats'), findsOneWidget);
  });

  testWidgets('phone width with a large font: filter labels stay on one line (device check)',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, world([]), width: 400);
    final label = find.descendant(of: find.byKey(const Key('task-filter')), matching: find.text('Upcoming'));
    final para = tester.renderObject<RenderParagraph>(label);
    expect(para.didExceedMaxLines, isFalse);
    expect(tester.getSize(label).height, lessThan(30)); // one line
    expect(find.descendant(of: find.byKey(const Key('task-filter')), matching: find.byIcon(Icons.today)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('Settings → Calendar (D1–D3)', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
    }

    testWidgets('week start and month-end defaults are saved', (tester) async {
      final w = world([]);
      await pumpApp(tester, w);
      await openSettings(tester);
      await tapKey(tester, 'week-start-sunday');
      expect(w.calls.last, 'setPlanning:1000:400:skip:sunday');
      await tapKey(tester, 'month-end-lastDay');
      expect(w.calls.last, 'setPlanning:1000:400:lastDay:sunday');
    });

    testWidgets('limits are checked against their bounds', (tester) async {
      final w = world([]);
      await pumpApp(tester, w);
      await openSettings(tester);
      await tapKey(tester, 'max-occurrences');
      await tester.enterText(find.byKey(const Key('number-field')), '50');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 100 to 5000.'), findsOneWidget);
      expect(w.calls, isEmpty);
      await tester.enterText(find.byKey(const Key('number-field')), '2000');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'setPlanning:2000:400:skip:monday');
      expect(find.text('2000'), findsOneWidget);

      await tapKey(tester, 'max-window');
      await tester.enterText(find.byKey(const Key('number-field')), '1101');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a number from 31 to 1100.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('number-field')), '31');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'setPlanning:2000:31:skip:monday');
    });
  });
}
