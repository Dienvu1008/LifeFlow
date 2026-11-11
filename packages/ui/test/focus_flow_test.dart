// P03 T6b (ADR-0042): focus sessions in the UI, with fakes.
//   D3   pomodoro (default 25 min) or stopwatch, from a task or without one
//   D2   one session at a time: starting another offers to open it
//   D4   the focus bar on every screen; "time is up" when a pomodoro ends
//   D5   ending asks whether to save; a session never completes the task
//   D1   the question about a session found at start
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';

import 'fake_world.dart';

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

Future<void> tick(WidgetTester tester, FakeWorld w, Duration d) async {
  w.tick(d);
  await tester.pump(); // the tick is delivered
  await tester.pump(); // and drawn
}

String timeShown(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('focus-time'))).data!;

FocusSessionView session({
  FocusSessionMode mode = FocusSessionMode.stopwatch,
  FocusSessionStatus status = FocusSessionStatus.running,
  Duration? planned,
  required Instant startedAt,
}) =>
    FocusSessionView(
        id: 'old', mode: mode, status: status, startedAt: startedAt, taskId: 't1', taskTitle: 'Write', planned: planned);

void main() {
  testWidgets('a pomodoro from a task: counts down, pauses, and the bar shows on every screen (D3, D4)', (tester) async {
    final w = world([task('t1', 'Write')]);
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Actions for Write'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus…').last);
    await tester.pumpAndSettle();
    expect(find.text('Focus on Write'), findsOneWidget);
    await tapKey(tester, 'focus-start'); // pomodoro, 25 minutes (D3)
    expect(w.calls.last, 'focus.start:pomodoro:25:t1:null');
    expect(timeShown(tester), '25:00');
    await tick(tester, w, const Duration(minutes: 5, seconds: 3));
    expect(timeShown(tester), '19:57');

    await tapKey(tester, 'focus-pause');
    expect(w.calls.last, 'focus.pause:fs0');
    expect(find.text('Paused'), findsOneWidget);
    await tick(tester, w, const Duration(minutes: 10));
    expect(timeShown(tester), '19:57', reason: 'a pause does not count');
    await tapKey(tester, 'focus-pause');
    expect(w.calls.last, 'focus.resume:fs0');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-bar')), findsOneWidget);
    expect(find.text('19:57 · t1'), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-bar')), findsOneWidget, reason: 'every screen (D4)');

    // Time is up: shown in the bar; the bar opens the page.
    await tick(tester, w, const Duration(minutes: 20));
    expect(find.textContaining('Time is up'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-bar-text')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-overdue')), findsOneWidget);
  });

  testWidgets('a stopwatch without a task counts up; ending asks whether to save (D5)', (tester) async {
    final w = world([task('t1', 'Write')]);
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stopwatch'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-minutes')), findsNothing);
    await tapKey(tester, 'focus-start');
    expect(w.calls.last, 'focus.start:stopwatch:null:null:null');
    expect(find.text('Focus without a task'), findsOneWidget);
    await tick(tester, w, const Duration(minutes: 2));
    expect(timeShown(tester), '2:00');

    await tapKey(tester, 'focus-end');
    expect(find.textContaining('it does not complete the task'), findsOneWidget);
    await tapKey(tester, 'focus-end-save');
    expect(w.calls.last, 'focus.end:fs0:true');
    expect(find.byKey(const Key('focus-none')), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-bar')), findsNothing);
  });

  testWidgets('from the bar: pause, and end without saving; cancel asks first', (tester) async {
    final w = world([task('t1', 'Write')]);
    w.focus.active = session(startedAt: w.now);
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Pause focus'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'focus.pause:old');
    expect(find.textContaining('paused'), findsOneWidget);
    await tester.tap(find.byTooltip('End focus'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'focus-end-discard');
    expect(w.calls.last, 'focus.end:old:false');

    w.focus.active = session(startedAt: w.now);
    w.focus.changed();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-bar-text')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'focus-cancel');
    await tapKey(tester, 'focus-cancel-confirm');
    expect(w.calls.last, 'focus.cancel:old');
  });

  testWidgets('D2: with a session running, starting another offers to open it', (tester) async {
    final w = world([task('t1', 'Write'), task('t2', 'Read')]);
    w.focus.active = session(startedAt: w.now);
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Actions for Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus…').last);
    await tester.pumpAndSettle();
    expect(find.text('A focus session is running'), findsOneWidget);
    await tester.tap(find.text('Open it'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-time')), findsOneWidget);
    expect(w.calls.where((c) => c.startsWith('focus.start')), isEmpty);
  });

  testWidgets('the pomodoro length is checked; a done task offers no focus', (tester) async {
    final w = world([task('t1', 'Write'), task('t2', 'Done', status: 'done')]);
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Actions for Write'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus…').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('focus-minutes')), '0');
    await tapKey(tester, 'focus-start');
    expect(find.text('Between 1 and 240 minutes.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('focus-minutes')), '50');
    await tapKey(tester, 'focus-start');
    expect(w.calls.last, 'focus.start:pomodoro:50:t1:null');
    await tapKey(tester, 'focus-end');
    await tapKey(tester, 'focus-end-discard');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actions for Done'));
    await tester.pumpAndSettle();
    expect(find.text('Focus…'), findsNothing);
  });

  testWidgets('Today: focus on one occurrence of a repeating task (D5)', (tester) async {
    final w = world([task('t1', 'Write')]);
    w.today = Agenda([
      AgendaItem(
          taskId: 't1', title: 'Write', originalDate: testToday, start: SchedulePointInput.date(testToday), isRepeating: true, isDone: false),
    ]);
    await pumpApp(tester, w);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions for Write'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus…').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'focus-start');
    expect(w.calls.last, 'focus.start:pomodoro:25:t1:$testToday');
  });

  testWidgets('Today: a done occurrence offers no focus', (tester) async {
    final w = world([task('t1', 'Write')]);
    w.today = Agenda([
      AgendaItem(
          taskId: 't1', title: 'Write', originalDate: testToday, start: SchedulePointInput.date(testToday), isRepeating: true, isDone: true),
    ]);
    await pumpApp(tester, w);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions for Write'));
    await tester.pumpAndSettle();
    expect(find.text('Focus…'), findsNothing);
    expect(find.text('Skip this time'), findsOneWidget);
  });

  group('D1: the session found at start', () {
    testWidgets('an overdue pomodoro: the three answers, counted until it ended by default', (tester) async {
      for (final (key, choice) in [
        ('launch-to-end', 'countToPlannedEnd'),
        ('launch-to-now', 'countToNow'),
        ('launch-discard', 'discard'),
      ]) {
        final w = world([task('t1', 'Write')]);
        final s = session(mode: FocusSessionMode.pomodoro, planned: const Duration(minutes: 25), startedAt: w.now);
        w.launch = FocusOverdue(s, Instant(w.now.utc.add(const Duration(minutes: 25))));
        await pumpApp(tester, w);
        expect(find.text('Your pomodoro ended while LifeFlow was closed'), findsOneWidget);
        expect(tester.widget(find.byKey(const Key('launch-to-end'))), isA<FilledButton>(), reason: 'the default');
        await tapKey(tester, key);
        expect(w.calls.last, 'focus.overdue:old:$choice');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a stopwatch: resume, or end now', (tester) async {
      var w = world([task('t1', 'Write')]);
      w.focus.active = session(startedAt: Instant(w.now.utc.subtract(const Duration(minutes: 12))));
      w.launch = FocusResumed(w.focus.active!);
      await pumpApp(tester, w);
      expect(find.text('Your stopwatch is still running'), findsOneWidget);
      expect(find.textContaining('Write: 12 minutes so far.'), findsOneWidget);
      await tapKey(tester, 'launch-resume');
      expect(w.calls.where((c) => c.startsWith('focus.')), isEmpty);
      expect(find.byKey(const Key('focus-bar')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      w = world([task('t1', 'Write')]);
      w.focus.active = session(startedAt: w.now);
      w.launch = FocusResumed(w.focus.active!);
      await pumpApp(tester, w);
      await tapKey(tester, 'launch-end');
      await tapKey(tester, 'focus-end-save');
      expect(w.calls.last, 'focus.end:old:true');
    });

    testWidgets('a running pomodoro continues without a question; an unrecoverable one is explained', (tester) async {
      var w = world([task('t1', 'Write')]);
      w.focus.active = session(mode: FocusSessionMode.pomodoro, planned: const Duration(minutes: 25), startedAt: w.now);
      w.launch = FocusResumed(w.focus.active!);
      await pumpApp(tester, w);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('focus-bar')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      w = world([task('t1', 'Write')]);
      w.launch = FocusUnrecoverable(session(status: FocusSessionStatus.unrecoverable, startedAt: w.now), 'paused without a pause time');
      await pumpApp(tester, w);
      expect(find.text('A focus session could not be recovered'), findsOneWidget);
      expect(find.textContaining('paused without a pause time'), findsOneWidget);
    });
  });

  testWidgets('the bar fits a phone width with a large font', (tester) async {
    final w = world([task('t1', 'A rather long task title that does not fit on one line')]);
    w.focus.active = FocusSessionView(
        id: 'old',
        mode: FocusSessionMode.stopwatch,
        status: FocusSessionStatus.running,
        startedAt: w.now,
        taskId: 't1',
        taskTitle: 'A rather long task title that does not fit on one line');
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, w, width: 360);
    expect(find.byKey(const Key('focus-bar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
