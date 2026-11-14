// P03 UX U3 (ADR-0047): the Overview through the full app with fake ports.
// Lists, collapse (remembered), the + menu, row menus (colour, move, levels),
// drag and drop by the handle and by a long press, trashing a list with undo.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';

FakeWorld world() {
  final w = FakeWorld(
    tasks: {
      'A': [
        task('W1', 'Plan', list: 'Work'),
        task('W1a', 'Draft', parent: 'W1'),
        task('W1b', 'Outline', parent: 'W1a'),
        task('A', 'Call mum'),
        task('B', 'Buy bread'),
      ],
    },
    profiles: [profile('A', 'Guest')],
    activeId: 'A',
  );
  w.overview.lists.addAll(const [
    TaskListView(id: 'Work', title: 'Work', orderKey: ''),
    TaskListView(id: 'Home', title: 'Home', colorIndex: 4, orderKey: ''),
  ]);
  w.overview.events.addAll(const [
    OverviewEventView(id: 'WE', title: 'Standup', listId: 'Work', orderKey: ''),
    OverviewEventView(id: 'E', title: 'Dentist', orderKey: ''),
  ]);
  // Tests run as Android, where Auto hides the handles (O1); these tests
  // drag by the handle, so they turn them on.
  w.look = const AppearanceSettings(dragHandles: DragHandles.always);
  // Display order: Work: Plan, Standup; no list: Call mum, Dentist, Buy bread.
  w.overview.order.addAll(['W1', 'W1a', 'W1b', 'WE', 'A', 'E', 'B']);
  return w;
}

Future<void> pumpApp(WidgetTester tester, FakeWorld w, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;
double left(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dx;

Future<void> menu(WidgetTester tester, String title, String item) async {
  await tester.tap(find.byTooltip('Actions for $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists with their items, then the items in no list; subtasks indented', (tester) async {
    await pumpApp(tester, world());
    final order = ['Work', 'Plan', 'Draft', 'Outline', 'Standup', 'Home', 'Not in a list', 'Call mum', 'Dentist', 'Buy bread'];
    for (var i = 1; i < order.length; i++) {
      expect(top(tester, order[i]), greaterThan(top(tester, order[i - 1])), reason: order[i]);
    }
    expect(left(tester, 'Draft'), greaterThan(left(tester, 'Plan')));
    expect(left(tester, 'Outline'), greaterThan(left(tester, 'Draft')));
    expect(left(tester, 'Plan'), greaterThan(left(tester, 'Call mum'))); // inside a list
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    // The toggle shows only where there is something to fold.
    expect(find.byKey(const ValueKey('toggle-W1')), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-A')), findsNothing);
    expect(find.byKey(const ValueKey('toggle-Home')), findsNothing);
  });

  testWidgets('collapsing hides the contents and is remembered on the device', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Collapse Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Draft'), findsNothing);
    expect(w.calls, ['setCollapsed:W1']);
    await tester.tap(find.byTooltip('Collapse Work'));
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsNothing);
    expect(find.text('Standup'), findsNothing);
    expect(w.calls.last, 'setCollapsed:W1,Work');
    await tester.tap(find.byTooltip('Expand Work'));
    await tester.pumpAndSettle();
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);
  });

  testWidgets('the remembered state applies when the Overview opens', (tester) async {
    final w = world()..collapsed = {'W1a'};
    await pumpApp(tester, w);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Outline'), findsNothing);
  });

  testWidgets('the + menu: a new list, and a task in no list', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('New event'), findsOneWidget);
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(w.calls, ['list.create:Groceries']);
    expect(find.text('Groceries'), findsOneWidget);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Milk');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'create:Milk:null');
  });

  testWidgets('a list\'s menu adds a task to it; rename; colour', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await menu(tester, 'Home', 'Add task');
    await tester.enterText(find.byType(TextField), 'Fix the door');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'create:Fix the door:null:Home');
    expect(top(tester, 'Fix the door'), greaterThan(top(tester, 'Home')));
    expect(top(tester, 'Fix the door'), lessThan(top(tester, 'Not in a list')));
    await menu(tester, 'Home', 'Rename');
    await tester.enterText(find.byType(TextField), 'House');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'list.rename:Home:House');
    await menu(tester, 'House', 'Colour…');
    expect(find.byKey(const Key('colour-picker')), findsOneWidget);
    expect(find.bySemanticsLabel('Green'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('colour-7')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'list.color:Home:7');
  });

  testWidgets('a task\'s colour, and no colour', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await menu(tester, 'Call mum', 'Colour…');
    await tester.tap(find.byKey(const ValueKey('colour-0')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.color:A:0');
    // The bar on the left takes the colour.
    final bar = tester.widgetList<DecoratedBox>(
        find.ancestor(of: find.byKey(const ValueKey('task-A')), matching: find.byType(DecoratedBox)));
    expect(bar.any((d) => (d.decoration as BoxDecoration?)?.border is BorderDirectional), isTrue);
    await menu(tester, 'Call mum', 'Colour…');
    await tester.tap(find.byKey(const Key('colour-none')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.color:A:null');
  });

  testWidgets('menu moves: up, down, to a list, a level up, under the task above', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    // The first item cannot move up; the last cannot move down.
    await tester.tap(find.byTooltip('Actions for Call mum'));
    await tester.pumpAndSettle();
    expect(find.text('Move up'), findsNothing);
    expect(find.text('Move down'), findsOneWidget);
    await tester.tap(find.text('Move down'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.move:A:loose@E');
    expect(top(tester, 'Call mum'), greaterThan(top(tester, 'Dentist')));

    await menu(tester, 'Dentist', 'Move to list…');
    await tester.tap(find.byKey(const ValueKey('move-to-Work')));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'event.move:E:in:Work@WE');
    expect(top(tester, 'Dentist'), lessThan(top(tester, 'Home')));

    await menu(tester, 'Draft', 'Move it up a level');
    expect(w.calls.last, 'task.move:W1a:in:Work@W1');
    expect(left(tester, 'Draft'), left(tester, 'Plan'));

    await menu(tester, 'Buy bread', 'Make it a subtask of the task above');
    expect(w.calls.last, 'task.move:B:under:A@null');
    expect(left(tester, 'Buy bread'), greaterThan(left(tester, 'Call mum')));
  });

  testWidgets('drag by the handle: onto a task makes it a subtask', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('drag-B'))));
    await tester.pump();
    // Straight down onto the middle of the row: no level change from moving sideways.
    final a = tester.getCenter(find.byKey(const ValueKey('task-A')));
    final target = Offset(tester.getCenter(find.byKey(const ValueKey('drag-B'))).dx, a.dy);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(tester.getCenter(find.byKey(const ValueKey('drag-B'))), target, i / 10)!);
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.move:B:under:A@null');
    expect(left(tester, 'Buy bread'), greaterThan(left(tester, 'Call mum')));
  });

  testWidgets('drag left below a deep row: up two levels, after its top task', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    // A long press on the title (touch), so there is room to the left.
    final start = tester.getCenter(find.text('Buy bread'));
    final row = tester.getRect(find.byKey(const ValueKey('task-W1b')));
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    // The lower quarter of Outline, 48 px (two steps) to the left of the start.
    final end = Offset(start.dx - 48, row.bottom - 3);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump();
    }
    expect(find.byKey(const Key('drop-line')), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.move:B:in:Work@W1');
  });

  testWidgets('a long press on a touch screen drags the row onto a list, which opens', (tester) async {
    final w = world()..collapsed = {'Home'};
    await pumpApp(tester, w, width: 400);
    final start = tester.getCenter(find.text('Call mum'));
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    final end = tester.getCenter(find.byKey(const ValueKey('list-Home')));
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(start, end, i / 10)!);
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(w.calls, ['task.move:A:in:Home@null', 'setCollapsed:']);
    expect(tester.getTopLeft(find.text('Call mum')).dy, greaterThan(tester.getTopLeft(find.text('Home')).dy));
    expect(tester.getTopLeft(find.text('Call mum')).dy, lessThan(tester.getTopLeft(find.text('Not in a list')).dy));
  });

  testWidgets('a list goes to the trash with its contents; Undo brings it back', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await menu(tester, 'Work', 'Move to trash');
    expect(w.calls.last, 'list.trash:Work');
    expect(find.text('Plan'), findsNothing);
    expect(find.text('Standup'), findsNothing);
    expect(find.textContaining('moved to the trash with its tasks and events'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'list.restore:Work');
    expect(find.text('Plan'), findsOneWidget);
  });

  testWidgets('a refused move is shown, not thrown', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    w.overview.failNext = const CommandFailure(CommandFailureKind.validationFailed, reason: 'the drop position is out of date');
    await menu(tester, 'Call mum', 'Move down');
    expect(find.text('The drop position is out of date.'), findsOneWidget);
  });
}
