// Dogfooding F3 (O4, ADR-0051): the task page, opened by a tap on a task in
// the Overview, the Timeline or the Calendar.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';
import 'nav.dart';

FakeWorld world() {
  final w = FakeWorld(
    tasks: {
      'A': [
        TaskView(id: 'p', title: 'Visa', status: 'todo', parentId: null, createdAt: DateTime(2026), listId: 'Work', notes: 'Forms'),
        task('k', 'Photos', parent: 'p'),
        task('d', 'Done step', parent: 'p', status: 'done'),
        task('x', 'Loose'),
      ],
    },
    profiles: [profile('A', 'Guest')],
    activeId: 'A',
  );
  w.overview.lists.addAll(const [
    TaskListView(id: 'Work', title: 'Work', orderKey: ''),
    TaskListView(id: 'Home', title: 'Home', orderKey: ''),
  ]);
  w.overview.order.addAll(['p', 'k', 'd', 'x']);
  return w;
}

Future<void> pumpApp(WidgetTester tester, FakeWorld w) async {
  tester.view.physicalSize = const Size(1000, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

Future<void> openPage(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('task-page')), findsOneWidget);
}

void main() {
  testWidgets('a tap opens the page: title, list, colour, notes, plan, subtasks', (tester) async {
    await pumpApp(tester, world());
    await openPage(tester, 'Visa');
    expect(tester.widget<Text>(find.byKey(const Key('task-page-title'))).data, 'Visa');
    expect(find.descendant(of: find.byKey(const Key('task-page-list')), matching: find.text('Work')), findsOneWidget);
    expect(find.text('No colour'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('task-page-notes'))).controller!.text, 'Forms');
    expect(find.text('Not scheduled'), findsOneWidget);
    expect(find.text('Not tracked'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-page-sub-k')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-page-sub-d')), findsOneWidget);
  });

  testWidgets('notes: saved with the button, and when the field is left; emptied removes them', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await openPage(tester, 'Visa');
    expect(find.byKey(const Key('task-page-save-notes')), findsNothing);
    await tester.enterText(find.byKey(const Key('task-page-notes')), 'Forms and two photos');
    await tester.pump();
    await tester.tap(find.byKey(const Key('task-page-save-notes')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'notes:p:Forms and two photos');
    expect(find.byKey(const Key('task-page-save-notes')), findsNothing);
    // Leaving the field (here: tapping the title) saves too.
    await tester.enterText(find.byKey(const Key('task-page-notes')), '   ');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(w.calls.last, 'notes:p:-');
  });

  testWidgets('rename, colour, move to another list', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await openPage(tester, 'Visa');
    await tester.tap(find.byKey(const Key('task-page-rename')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Visa trip');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'rename:p:Visa trip');
    await tester.tap(find.byKey(const Key('task-page-colour')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('colour-4')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.color:p:4');
    expect(find.text('Green'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-page-list')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-to-Home')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.move:p:in:Home@null');
    expect(find.descendant(of: find.byKey(const Key('task-page-list')), matching: find.text('Home')), findsOneWidget);
  });

  testWidgets('subtasks: tick one, add one, open one (it links back to its parent)', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await openPage(tester, 'Visa');
    await tester.tap(find.bySemanticsLabel('Complete Photos'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'complete:k:false');
    await tester.tap(find.bySemanticsLabel('Mark as not done: Done step'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'reopen:d');
    await tester.tap(find.byKey(const Key('task-page-add-subtask')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pay the fee');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'create:Pay the fee:p');
    expect(find.text('Pay the fee'), findsOneWidget);
    await tester.tap(find.text('Photos'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-page-parent')), findsOneWidget);
    expect(find.text('Subtask of Visa'), findsOneWidget);
  });

  testWidgets('the plan rows open the schedule, the habit page and the goals', (tester) async {
    await pumpApp(tester, world());
    await openPage(tester, 'Loose');
    await tester.tap(find.byKey(const Key('task-page-schedule')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('schedule-save')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('schedule-save')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-page-habit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('habit-page')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('habit-page')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-page-goals')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-goals-empty')), findsOneWidget);
  });

  testWidgets('trash: the task goes and the page closes', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await openPage(tester, 'Loose');
    await tester.tap(find.byKey(const Key('task-page-trash')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'trash:x');
    expect(find.byKey(const Key('task-page')), findsNothing);
    expect(find.byKey(const Key('task-page-gone')), findsNothing, reason: 'closed, not left open on an empty page');
    expect(find.text('Loose'), findsNothing);
  });

  testWidgets('from the Timeline: a tap on an occurrence opens its task', (tester) async {
    final w = world();
    w.today = Agenda([
      AgendaItem(
          taskId: 'x', title: 'Loose', originalDate: testToday, start: SchedulePointInput.date(testToday), isRepeating: false, isDone: false),
    ]);
    await pumpApp(tester, w);
    await goToTab(tester, 'Timeline');
    await tester.tap(find.text('Loose'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-page')), findsOneWidget);
  });
}
