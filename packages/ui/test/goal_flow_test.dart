// P03 T6c (ADR-0043): goals and projects in the UI, with fakes.
//   D12   Goals is the 5th tab; a task's "Goals…" shows what it is part of
//   D11   goals and projects, milestones by hand, links to tasks, habits
//         and events; active / done / archived and the trash
//   GOAL-001  progress is shown as the port gives it (derived below)
//   GOAL-002  trashing says the tasks are kept
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> openGoals(WidgetTester tester) async {
  await tester.tap(find.text('Goals'));
  await tester.pumpAndSettle();
}

GoalView fit({
  GoalState status = GoalState.active,
  List<MilestoneView> milestones = const [],
  List<GoalLinkView> links = const [],
  GoalProgressBasis basis = GoalProgressBasis.none,
  double? progress,
}) =>
    GoalView(
      id: 'g1',
      kind: GoalKindInput.goal,
      title: 'Get fit',
      status: status,
      targetDate: testToday.addDays(30),
      milestones: milestones,
      links: links,
      progressBasis: basis,
      progress: progress,
    );

void main() {
  testWidgets('the Goals tab: empty, then a new project opens its page (D11, D12)', (tester) async {
    final w = world([]);
    await pumpApp(tester, w);
    await openGoals(tester);
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    await tester.tap(find.byTooltip('New goal or project'));
    await tester.pumpAndSettle();
    // A title is needed.
    await tapKey(tester, 'goal-save');
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.byKey(const Key('goal-start')), findsNothing, reason: 'a goal has no start');
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-start')), findsOneWidget, reason: 'only a project has a start');
    await tester.enterText(find.byKey(const Key('goal-title')), 'Move house');
    await tester.enterText(find.byKey(const Key('goal-description')), 'Before Christmas');
    await tapKey(tester, 'goal-start');
    await tester.tap(find.text('OK')); // today
    await tester.pumpAndSettle();
    await tapKey(tester, 'goal-save');
    expect(w.calls.last, 'goal.create:project:Move house:Before Christmas:$testToday:null');
    expect(find.byKey(const Key('goal-page')), findsOneWidget);
    expect(find.text('No progress yet'), findsOneWidget, reason: 'not 0 %');
  });

  testWidgets('a start chosen for a project is dropped when it becomes a goal again', (tester) async {
    final w = world([]);
    await pumpApp(tester, w);
    await openGoals(tester);
    await tester.tap(find.byTooltip('New goal or project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'goal-start');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-title')), 'Read more');
    await tapKey(tester, 'goal-save');
    expect(w.calls.last, 'goal.create:goal:Read more:null:null:null');
  });

  testWidgets('the list shows progress as the port gives it; archived and trash lists', (tester) async {
    final w = world([]);
    w.goals.goals['g1'] = fit(progress: 0.6, basis: GoalProgressBasis.milestones, milestones: [
      for (var i = 0; i < 5; i++) MilestoneView(id: 'm$i', title: 'M$i', isCompleted: i < 3),
    ]);
    w.goals.goals['g2'] = GoalView(id: 'g2', kind: GoalKindInput.project, title: 'Old project', status: GoalState.archived);
    await pumpApp(tester, w);
    await openGoals(tester);
    expect(find.text('60% · 3 of 5 milestones'), findsOneWidget);
    expect(find.bySemanticsLabel('Progress: 60% · 3 of 5 milestones'), findsOneWidget);
    expect(find.text('Old project'), findsNothing);
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Old project'), findsOneWidget);
    expect(find.text('Get fit'), findsNothing);
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
  });

  testWidgets('milestones: add, tick by hand, edit, remove (D11)', (tester) async {
    final w = world([]);
    w.goals.goals['g1'] = fit();
    await pumpApp(tester, w);
    await openGoals(tester);
    await tester.tap(find.text('Get fit'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'milestone-add');
    await tester.enterText(find.byKey(const Key('milestone-title')), 'Run 5 km');
    await tapKey(tester, 'milestone-save');
    expect(w.calls.last, 'goal.milestone.add:g1:Run 5 km:null');
    final id = w.goals.goals['g1']!.milestones.single.id;
    await tester.tap(find.text('Run 5 km'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.milestone.done:g1:$id:true');
    await tester.tap(find.byTooltip('Actions for the milestone Run 5 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit…').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('milestone-title')), 'Run 10 km');
    await tapKey(tester, 'milestone-save');
    expect(w.calls.last, 'goal.milestone.update:g1:$id:Run 10 km:null');
    await tester.tap(find.byTooltip('Actions for the milestone Run 5 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.milestone.remove:g1:$id');
  });

  testWidgets('links: a task or habit, an event; their state; unlink', (tester) async {
    final w = world([task('t1', 'Buy shoes'), task('t2', 'Book a trainer')]);
    w.calendar.range = CalendarRange(events: [
      EventItem(eventId: 'e1', title: 'Gym class', originalDate: testToday, start: SchedulePointInput.date(testToday), isRepeating: true),
      EventItem(
          eventId: 'e1', title: 'Gym class', originalDate: testToday.addDays(7), start: SchedulePointInput.date(testToday.addDays(7)), isRepeating: true),
    ], tasks: const [], conflicts: const []);
    w.goals.goals['g1'] = fit(links: const [
      GoalLinkView(itemType: GoalItemType.task, itemId: 't1', title: 'Buy shoes', state: LinkedItemState.done),
      GoalLinkView(itemType: GoalItemType.task, itemId: 'h1', title: 'Walk', state: LinkedItemState.open, isHabit: true, habitRate: 0.5),
    ], basis: GoalProgressBasis.links, progress: 0.75);
    await pumpApp(tester, w);
    await openGoals(tester);
    await tester.tap(find.text('Get fit'));
    await tester.pumpAndSettle();
    expect(find.text('Task · done'), findsOneWidget);
    expect(find.text('Habit · open · 50% since linked'), findsOneWidget);
    expect(find.text('75% · from linked tasks and habits'), findsOneWidget);

    await tapKey(tester, 'link-task');
    expect(find.byKey(const ValueKey('pick-t1')), findsNothing, reason: 'already linked');
    await tester.tap(find.byKey(const ValueKey('pick-t2')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.link:g1:task:t2');

    await tapKey(tester, 'link-event');
    expect(find.byKey(const ValueKey('pick-e1')), findsOneWidget, reason: 'one per event, not per occurrence');
    await tester.tap(find.byKey(const ValueKey('pick-e1')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.link:g1:event:e1');

    await tester.tap(find.byTooltip('Unlink Buy shoes'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.unlink:g1:task:t1');
  });

  testWidgets('status: done, archived (read only), trash keeps the tasks, restore (GOAL-002)', (tester) async {
    final w = world([]);
    w.goals.goals['g1'] = fit();
    await pumpApp(tester, w);
    await openGoals(tester);
    await tester.tap(find.text('Get fit'));
    await tester.pumpAndSettle();
    Future<void> act(String label) async {
      await tester.tap(find.byTooltip('Actions for ${w.goals.goals['g1']!.title}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await act('Mark as done');
    expect(w.calls.last, 'goal.status:g1:done');
    await act('Archive');
    expect(w.calls.last, 'goal.status:g1:archived');
    expect(find.text('Archived: unarchive it to change it.'), findsOneWidget);
    expect(find.byKey(const Key('milestone-add')), findsNothing);
    expect(find.byKey(const Key('link-task')), findsNothing);
    await act('Unarchive');
    expect(w.calls.last, 'goal.status:g1:active');
    await act('Edit…');
    await tester.enterText(find.byKey(const Key('goal-title')), 'Get fitter');
    await tapKey(tester, 'goal-save');
    expect(w.calls.last, startsWith('goal.update:g1:Get fitter:'));

    await act('Move to trash');
    expect(w.calls.last, 'goal.trash:g1');
    expect(find.byKey(const Key('goal-page')), findsNothing, reason: 'the page closes');
    expect(find.textContaining('Its tasks and events are kept'), findsOneWidget);
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-restore-g1')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.restore:g1');
  });

  testWidgets('a task\'s "Goals…": what it is part of; tick links, untick unlinks (D12)', (tester) async {
    final w = world([task('t1', 'Buy shoes')]);
    await pumpApp(tester, w);
    Future<void> openFor() async {
      await tester.tap(find.byTooltip('Actions for Buy shoes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Goals…').last);
      await tester.pumpAndSettle();
    }

    await openFor();
    expect(find.byKey(const Key('task-goals-empty')), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    w.goals.goals['g1'] = fit();
    w.goals.goals['g2'] = GoalView(id: 'g2', kind: GoalKindInput.project, title: 'Move house', status: GoalState.active);
    w.goals.changed();
    await openFor();
    await tester.tap(find.byKey(const ValueKey('task-goal-g1')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.link:g1:task:t1');
    final box = tester.widget<CheckboxListTile>(find.byKey(const ValueKey('task-goal-g1')));
    expect(box.value, isTrue);
    await tester.tap(find.byKey(const ValueKey('task-goal-g1')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'goal.unlink:g1:task:t1');
  });

  testWidgets('five tabs fit a phone with a large font', (tester) async {
    final w = world([]);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, w, width: 360);
    expect(find.text('Goals'), findsOneWidget);
    await openGoals(tester);
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
