// P03 T6a (ADR-0041): habits, targets and measurements in the UI, with fakes.
//   D12   Habits is the 4th filter of Tasks; adding there makes a daily habit
//   D6    the habit switch; a habit without a repeat is offered "every day"
//   D7    the target editor (type, bounds, unit suggestions, aggregation)
//   D8    completion manual / automatic; automatic boxes are not ticked
//   D9    a measurement in a closed period asks first
//   D10   measurements: add, correct, withdraw; history shown
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'fake_world.dart';
import 'nav.dart';

FakeWorld world(List<TaskView> tasks) =>
    FakeWorld(tasks: {'A': tasks}, profiles: [profile('A', 'Guest')], activeId: 'A');

Future<void> pumpApp(WidgetTester tester, FakeWorld w, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openHabit(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Actions for $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Habit and target…').last);
  await tester.pumpAndSettle();
}

const steps = TargetInput(kind: TargetKind.atLeast, min: 6000, unit: 'steps');

TrackingView walking({
  CompletionMode completion = CompletionMode.manual,
  double? value = 4000,
  bool complete = false,
  List<PeriodResultView> results = const [],
  List<MeasurementView> measurements = const [],
}) =>
    TrackingView(
      taskId: 't1',
      title: 'Walk',
      isHabit: true,
      isRepeating: true,
      target: steps,
      completion: completion,
      current: CurrentPeriodView(
          from: testToday, to: testToday, value: value, progress: complete ? PeriodProgress.achieved : PeriodProgress.inProgress),
      results: results,
      measurements: measurements,
      rate30: 0.75,
      rateAll: 0.5,
      streak: 3,
      isCompleteNow: complete,
    );

void main() {
  group('the Habits destination (U-D2)', () {
    testWidgets('lists the habits with their period and statistics; empty state', (tester) async {
      final w = world([task('t1', 'Walk'), task('t2', 'Read')]);
      await pumpApp(tester, w);
      await goToTab(tester, 'Habits');
      expect(find.byKey(const Key('habits-empty')), findsOneWidget);

      w.habits.views['t1'] = walking();
      w.habits.changed();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('habit-t1')), findsOneWidget);
      expect(find.textContaining('4000 / 6000 steps · In progress'), findsOneWidget);
      expect(find.textContaining('Streak 3 · 30 days 75% · all 50%'), findsOneWidget);
      expect(find.text('Read'), findsNothing, reason: 'not a habit');

      // Quick add from the list.
      await tester.tap(find.byTooltip('Add a measurement for Walk'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('measure-value')), '1500');
      await tapKey(tester, 'measure-save');
      expect(w.calls, contains('measure:t1:1500.0:$testToday:null:false'));
    });

    testWidgets('a task added in Habits is a habit that repeats every day (D6a)', (tester) async {
      final w = world([]);
      await pumpApp(tester, w);
      await goToTab(tester, 'Habits');
      await tester.tap(find.byTooltip('Add habit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Warm water');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(w.calls.where((c) => c.startsWith('create:') || c.startsWith('habit:') || c.startsWith('setSchedule:')), [
        'create:Warm water:null',
        'habit:new0:true',
        'setSchedule:new0:start=$testToday;end=-;due=-;repeat=daily/1/-/forever/skip/monday',
      ]);
    });

    testWidgets('fits a phone width with a large font', (tester) async {
      final w = world([task('t1', 'Walk')]);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester, w, width: 360);
      await goToTab(tester, 'Habits');
      expect(find.text('Habits'), findsOneWidget); // the title
      expect(tester.takeException(), isNull);
    });
  });

  group('the habit page', () {
    testWidgets('the habit switch; a habit without a repeat is offered every day (D6, D6a)', (tester) async {
      final w = world([task('t1', 'Walk')]);
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      expect(find.byKey(const Key('habit-page')), findsOneWidget);
      expect(find.text('No target'), findsOneWidget);
      await tapKey(tester, 'habit-switch');
      expect(w.calls, contains('habit:t1:true'));
      expect(find.byKey(const Key('habit-no-repeat')), findsOneWidget);
      await tapKey(tester, 'habit-repeat-daily');
      expect(w.calls.last, startsWith('setSchedule:t1:start=$testToday'));
      expect(w.calls.last, contains('repeat=daily/1'));
    });

    testWidgets('the target editor: type, bounds, unit suggestion, aggregation (D7)', (tester) async {
      final w = world([task('t1', 'Walk')]);
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      await tapKey(tester, 'target-edit');
      // Nothing entered: explained in the dialog, no command.
      await tapKey(tester, 'target-save');
      expect(find.byKey(const Key('target-error')), findsOneWidget);
      expect(w.calls.where((c) => c.startsWith('target:')), isEmpty);

      await tester.enterText(find.byKey(const Key('target-min')), '6000');
      await tapKey(tester, 'unit-steps');
      await tester.tap(find.byKey(const Key('target-aggregation')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('highest').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'target-save');
      expect(w.calls, contains('target:t1:atLeast,6000.0,null,steps,max'));
      expect(find.text('At least 6000 steps (highest)'), findsOneWidget);

      // "Between" needs both bounds.
      await tapKey(tester, 'target-edit');
      await tester.tap(find.byKey(const Key('target-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Between').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('target-max')), '9000');
      await tapKey(tester, 'target-save');
      expect(w.calls, contains('target:t1:about,6000.0,9000.0,steps,max'));

      // A refusal from the command is shown.
      w.habits.failNext = const CommandFailure(CommandFailureKind.validationFailed, reason: 'about target requires min <= max');
      await tapKey(tester, 'target-edit');
      await tester.enterText(find.byKey(const Key('target-min')), '10000');
      await tapKey(tester, 'target-save');
      expect(find.textContaining('About target requires min <= max'), findsOneWidget);

      await tapKey(tester, 'target-remove');
      expect(w.calls.last, 'target:t1:none');
      expect(find.text('No target'), findsOneWidget);
    });

    testWidgets('completion manual or automatic (D8)', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.habits.views['t1'] = walking();
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      await tester.tap(find.text('From measurements'));
      await tester.pumpAndSettle();
      expect(w.calls, contains('completion:t1:automatic'));
      expect(find.text('Done automatically when the target is reached'), findsOneWidget);
    });

    testWidgets('a measurement in a closed period asks first, then is confirmed (D9)', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.habits.views['t1'] = walking();
      w.habits.closedDates.add(testToday);
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      await tapKey(tester, 'measure-add');
      await tester.enterText(find.byKey(const Key('measure-value')), '2500');
      await tester.enterText(find.byKey(const Key('measure-note')), 'evening walk');
      await tapKey(tester, 'measure-save');
      expect(find.text('Change a closed period?'), findsOneWidget);
      await tapKey(tester, 'closed-confirm');
      expect(w.calls.where((c) => c.startsWith('measure:')), [
        'measure:t1:2500.0:$testToday:evening walk:false',
        'measure:t1:2500.0:$testToday:evening walk:true',
      ]);
    });

    testWidgets('a bad value is explained in the dialog', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.habits.views['t1'] = walking();
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      await tapKey(tester, 'measure-add');
      await tester.enterText(find.byKey(const Key('measure-value')), '.');
      await tapKey(tester, 'measure-save');
      expect(find.text('Enter a number, 0 or more.'), findsOneWidget);
      expect(w.calls.where((c) => c.startsWith('measure:')), isEmpty);
    });

    testWidgets('a past day can be chosen, never the future (D10)', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.habits.views['t1'] = walking();
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      await tapKey(tester, 'measure-add');
      await tester.tap(find.byKey(const Key('measure-date')));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      expect(picker.lastDate, DateTime(testToday.year, testToday.month, testToday.day));
      await tester.tap(find.text('8')); // yesterday
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Yesterday'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('measure-value')), '3000');
      await tapKey(tester, 'measure-save');
      expect(w.calls.last, 'measure:t1:3000.0:${testToday.addDays(-1)}:null:false');
    });

    testWidgets('statistics, history and measurements with corrections (D6b, D10)', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.habits.views['t1'] = walking(results: [
        PeriodResultView(key: testToday.addDays(-1), isOccurrence: false, outcome: PeriodOutcome.achieved, value: 7000, target: steps),
        PeriodResultView(
            key: testToday.addDays(-2),
            isOccurrence: false,
            outcome: PeriodOutcome.noData,
            target: const TargetInput(kind: TargetKind.atLeast, min: 5000, unit: 'steps')),
      ], measurements: [
        MeasurementView(id: 'm2', value: 4000, date: testToday, recordedAt: Instant(DateTime.utc(2026, 11, 9, 3)), source: 'manual', supersedesId: 'm1'),
        MeasurementView(id: 'm1', value: 400, date: testToday, recordedAt: Instant(DateTime.utc(2026, 11, 9, 2)), source: 'manual', isCurrent: false, note: 'typo'),
      ]);
      await pumpApp(tester, w);
      await openHabit(tester, 'Walk');
      expect(find.byKey(const Key('stat-streak')), findsOneWidget);
      expect(find.bySemanticsLabel('Current streak: 3'), findsOneWidget);
      expect(find.bySemanticsLabel('Last 30 days: 75%'), findsOneWidget);
      expect(find.text('Achieved · 7000 steps'), findsOneWidget);
      expect(find.textContaining('No data · target then: At least 5000 steps'), findsOneWidget);
      expect(find.text('Today · correction'), findsOneWidget);
      expect(find.text('Today · corrected · typo'), findsOneWidget);
      // Only the current value can be corrected or withdrawn.
      expect(find.byTooltip('Actions for the value 400 of Today'), findsNothing);
      await tester.tap(find.byTooltip('Actions for the value 4000 of Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct…').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('measure-value')), '4200');
      await tapKey(tester, 'measure-save');
      expect(w.calls.last, 'correct:m2:4200.0:false');
      await tester.tap(find.byTooltip('Actions for the value 4000 of Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw').last);
      await tester.pumpAndSettle();
      expect(w.calls.last, 'correct:m2:null:false');
    });
  });

  group('period states in the lists (D8)', () {
    testWidgets('Today: a measured task shows its period; automatic boxes cannot be ticked', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.today = Agenda([
        AgendaItem(taskId: 't1', title: 'Walk', originalDate: testToday, start: SchedulePointInput.date(testToday), isRepeating: true, isDone: false),
      ]);
      w.habits.views['t1'] = walking(completion: CompletionMode.automatic, value: 6500, complete: true);
      await pumpApp(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('period-t1')), findsOneWidget);
      expect(find.text('6500 / 6000 steps · Achieved'), findsOneWidget);
      final box = tester.widget<Checkbox>(find.descendant(
          of: find.byKey(ValueKey('agenda-t1@$testToday')), matching: find.byType(Checkbox)));
      expect((box.value, box.onChanged), (true, null));
      expect(find.bySemanticsLabel('Done from measurements: Walk'), findsOneWidget);
    });

    testWidgets('Today: a manual habit is ticked as before', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.today = Agenda([
        AgendaItem(taskId: 't1', title: 'Walk', originalDate: testToday, start: SchedulePointInput.date(testToday), isRepeating: true, isDone: false),
      ]);
      w.habits.views['t1'] = walking();
      await pumpApp(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Complete Walk'));
      await tester.pumpAndSettle();
      expect(w.calls, contains('occurrenceDone:t1@$testToday:true'));
    });

    testWidgets('All: an automatic task\'s box is not ticked by hand', (tester) async {
      final w = world([task('t1', 'Walk')]);
      w.habits.views['t1'] = TrackingView(
          taskId: 't1',
          title: 'Walk',
          isHabit: false,
          isRepeating: false,
          target: steps,
          completion: CompletionMode.automatic,
          current: const CurrentPeriodView(value: 6000, progress: PeriodProgress.achieved),
          isCompleteNow: true);
      await pumpApp(tester, w);
      final box = tester.widget<Checkbox>(
          find.descendant(of: find.byKey(const ValueKey('task-t1')), matching: find.byType(Checkbox)));
      expect((box.value, box.onChanged), (true, null));
      expect(find.byKey(const ValueKey('period-t1')), findsOneWidget);
    });
  });
}
