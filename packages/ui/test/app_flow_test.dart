// End-to-end UI flows through LifeFlowApp + go_router with fake ports.
//   OQ-R3          complete with / without subtasks
//   LF-INV-ID-002  switching profile re-scopes the visible tasks
//   LF-INV-TASK-002 a rejected command is shown, not thrown
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';

FakeWorld world({Map<String, List<TaskView>>? tasks}) => FakeWorld(
      tasks: tasks ??
          {
            'A': [
              task('p', 'Parent'),
              task('c', 'Child', parent: 'p'),
            ],
            'B': [task('b1', 'B-task')],
          },
      profiles: [
        profile('A', 'Guest'),
        profile('B', 'Work', bound: true, provider: 'github'),
      ],
      activeId: 'A',
    );

Future<void> pumpApp(
  WidgetTester tester,
  FakeWorld w, {
  double width = 1000,
  StorageNotice? notice,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w, notice: notice));
  await tester.pumpAndSettle();
}

void main() {
  group('task list', () {
    testWidgets('shows the tree, children indented under their parent',
        (tester) async {
      await pumpApp(tester, world());
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Child')).dx,
          greaterThan(tester.getTopLeft(find.text('Parent')).dx));
      // Parent is listed before its child.
      expect(tester.getTopLeft(find.text('Parent')).dy,
          lessThan(tester.getTopLeft(find.text('Child')).dy));
    });

    testWidgets('empty profile shows guidance, not a blank screen',
        (tester) async {
      await pumpApp(tester, world(tasks: {'A': [], 'B': []}));
      expect(find.textContaining('No tasks yet'), findsOneWidget);
    });

    testWidgets('adding a task calls the service and the list updates',
        (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(w.calls, ['create:Buy milk:null']);
      expect(find.text('Buy milk'), findsOneWidget);
    });

    testWidgets('an empty title is never submitted', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(w.calls, isEmpty);
    });

    testWidgets('add subtask passes the parent id', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(find.byTooltip('Actions for Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add subtask'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sub');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(w.calls, ['create:Sub:p']);
    });

    testWidgets('a rejected command is shown as a message (TASK-002)',
        (tester) async {
      final w = world()
        ..failNext = const CommandFailure(CommandFailureKind.validationFailed,
            reason: 'subtasks may be at most 4 levels deep');
      await pumpApp(tester, w);
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Too deep');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Subtasks may be at most 4 levels deep.'), findsOneWidget);
    });

    testWidgets('rename and trash go through the service', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(find.byTooltip('Actions for Child'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kid');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(w.calls, ['rename:c:Kid']);
      expect(find.text('Kid'), findsOneWidget);

      await tester.tap(find.byTooltip('Actions for Kid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'trash:c');
      expect(find.text('Kid'), findsNothing);
    });
  });

  group('completing (OQ-R3)', () {
    Finder checkboxOf(String title) => find.descendant(
        of: find.widgetWithText(ListTile, title), matching: find.byType(Checkbox));

    testWidgets('a leaf completes immediately, no dialog', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(checkboxOf('Child'));
      await tester.pumpAndSettle();
      expect(find.text('This task has open subtasks'), findsNothing);
      expect(w.calls, ['complete:c:false']);
    });

    testWidgets('a parent with open subtasks asks; "With subtasks" cascades',
        (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(checkboxOf('Parent'));
      await tester.pumpAndSettle();
      expect(find.text('This task has open subtasks'), findsOneWidget);
      await tester.tap(find.text('With subtasks'));
      await tester.pumpAndSettle();
      expect(w.calls, ['complete:p:true']);
    });

    testWidgets('"Only this task" completes the parent alone', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(checkboxOf('Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Only this task'));
      await tester.pumpAndSettle();
      expect(w.calls, ['complete:p:false']);
    });

    testWidgets('Cancel makes no call', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await tester.tap(checkboxOf('Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls, isEmpty);
    });

    testWidgets('unchecking a completed task reopens it (owner review)',
        (tester) async {
      final w = world(tasks: {
        'A': [task('d', 'Done one', status: 'done')],
        'B': [],
      });
      await pumpApp(tester, w);
      Checkbox box() => tester.widget<Checkbox>(find.descendant(
          of: find.widgetWithText(ListTile, 'Done one'),
          matching: find.byType(Checkbox)));
      expect(box().value, isTrue);
      expect(box().semanticLabel, 'Mark as not done: Done one');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(w.calls, ['reopen:d']); // no dialog, no complete
      expect(box().value, isFalse);
    });
  });

  group('trash a task with subtasks (owner review)', () {
    FakeWorld tree() => world(tasks: {
          'A': [
            task('p', 'Parent'),
            task('c', 'Child', parent: 'p'),
            task('g', 'Grandchild', parent: 'c'),
            task('o', 'Other'),
          ],
          'B': [],
        });
    Future<void> trashParent(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Actions for Parent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks by default, counting every subtask', (tester) async {
      final w = tree();
      await pumpApp(tester, w);
      await trashParent(tester);
      expect(find.byKey(const Key('trash-choice')), findsOneWidget);
      expect(find.textContaining('It has 2 subtasks'), findsOneWidget);
      expect(w.calls, isEmpty);
    });

    testWidgets('"Trash subtasks too" removes the whole subtree', (tester) async {
      final w = tree();
      await pumpApp(tester, w);
      await trashParent(tester);
      await tester.tap(find.text('Trash subtasks too'));
      await tester.pumpAndSettle();
      expect(w.calls, ['trash:p:all']);
      expect(find.text('Child'), findsNothing);
      expect(find.text('Grandchild'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('"Keep subtasks" keeps them, one level up', (tester) async {
      final w = tree();
      await pumpApp(tester, w);
      await trashParent(tester);
      await tester.tap(find.text('Keep subtasks'));
      await tester.pumpAndSettle();
      expect(w.calls, ['trash:p']);
      expect(find.text('Parent'), findsNothing);
      expect(find.text('Child'), findsOneWidget);
      expect(find.text('Grandchild'), findsOneWidget);
    });

    testWidgets('Cancel trashes nothing', (tester) async {
      final w = tree();
      await pumpApp(tester, w);
      await trashParent(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls, isEmpty);
      expect(find.text('Parent'), findsOneWidget);
    });

    testWidgets('"Remember my choice" saves the setting; next time no question',
        (tester) async {
      final w = tree()
        ..tasks('A').add(task('p2', 'Parent 2'))
        ..tasks('A').add(task('c2', 'Child 2', parent: 'p2'));
      await pumpApp(tester, w);
      await trashParent(tester);
      await tester.tap(find.byKey(const Key('trash-remember')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep subtasks'));
      await tester.pumpAndSettle();
      expect(w.trashPolicy, SubtaskTrashPolicy.keepSubtasks);

      await tester.tap(find.byTooltip('Actions for Parent 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trash-choice')), findsNothing);
      expect(w.calls.last, 'trash:p2');
    });

    testWidgets('the setting "with subtasks" applies without asking',
        (tester) async {
      final w = tree()..trashPolicy = SubtaskTrashPolicy.withSubtasks;
      await pumpApp(tester, w);
      await trashParent(tester);
      expect(find.byKey(const Key('trash-choice')), findsNothing);
      expect(w.calls, ['trash:p:all']);
    });

    testWidgets('a task without subtasks is trashed without a question',
        (tester) async {
      final w = tree();
      await pumpApp(tester, w);
      await tester.tap(find.byTooltip('Actions for Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to trash'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trash-choice')), findsNothing);
      expect(w.calls, ['trash:o']);
    });

    testWidgets('Settings: the option can be changed', (tester) async {
      final w = tree();
      await pumpApp(tester, w);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Moving a task with subtasks to the trash'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trash-policy-with')));
      await tester.pumpAndSettle();
      expect(w.trashPolicy, SubtaskTrashPolicy.withSubtasks);
      final radio = tester.widget<RadioGroup<SubtaskTrashPolicy>>(
          find.byType(RadioGroup<SubtaskTrashPolicy>));
      expect(radio.groupValue, SubtaskTrashPolicy.withSubtasks);
    });
  });

  group('a new task is brought into view (owner report, Android)', () {
    testWidgets('adding below the visible part scrolls to it, clear of the + button',
        (tester) async {
      final w = world(tasks: {
        'A': [for (var i = 0; i < 40; i++) task('t$i', 'Task $i')],
        'B': [],
      });
      await pumpApp(tester, w, width: 400);
      expect(find.text('Task 39'), findsNothing); // off screen
      await tester.tap(find.byTooltip('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Brand new');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      final row = find.text('Brand new');
      expect(row, findsOneWidget);
      // Fully visible, and not under the floating + button.
      final rowRect = tester.getRect(find.widgetWithText(ListTile, 'Brand new'));
      final fab = tester.getRect(find.byType(FloatingActionButton));
      final list = tester.getRect(find.byKey(const Key('task-list')));
      expect(rowRect.top, greaterThanOrEqualTo(list.top));
      expect(rowRect.bottom, lessThanOrEqualTo(list.bottom));
      expect(rowRect.bottom <= fab.top || rowRect.right <= fab.left, isTrue,
          reason: 'row $rowRect is under the + button $fab');
    });

    testWidgets('the last row can be scrolled clear of the + button',
        (tester) async {
      final w = world(tasks: {
        'A': [for (var i = 0; i < 40; i++) task('t$i', 'Task $i')],
        'B': [],
      });
      await pumpApp(tester, w, width: 400);
      await tester.drag(find.byKey(const Key('task-list')), const Offset(0, -10000));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.widgetWithText(ListTile, 'Task 39'));
      final fab = tester.getRect(find.byType(FloatingActionButton));
      expect(last.bottom, lessThanOrEqualTo(fab.top));
    });
  });

  group('profiles (OQ-S7, LF-INV-ID-002)', () {
    testWidgets('lists every profile with its sign-in state', (tester) async {
      await pumpApp(tester, world());
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Guest profile, data stays on this device'),
          findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Signed in with GitHub'), findsOneWidget);
      // Exactly one is marked active, the other offers a switch.
      expect(find.text('Active'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Switch'), findsOneWidget);
    });

    testWidgets('switching profile re-scopes the task list', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('B-task'), findsNothing);

      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
      await tester.pumpAndSettle();
      expect(w.calls, ['switch:B']);

      await tester.tap(find.byIcon(Icons.checklist_outlined));
      await tester.pumpAndSettle();
      // Only profile B's data; none of A's crosses over.
      expect(find.text('B-task'), findsOneWidget);
      expect(find.text('Parent'), findsNothing);
      expect(find.text('Child'), findsNothing);
    });

    testWidgets('a failed switch is reported and nothing changes',
        (tester) async {
      final w = world()
        ..failNext = const CommandFailure(CommandFailureKind.notFound);
      await pumpApp(tester, w);
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
      await tester.pumpAndSettle();
      expect(find.text('That item no longer exists.'), findsOneWidget);
      expect(w.activeId, 'A');
    });
  });

  group('storage notice in the full app (ADR-0021)', () {
    const notice = StorageNotice(
      atRestEncrypted: false,
      trackedException: true,
      message: 'At-rest encryption is OFF on Windows (MVP tracked exception).',
    );

    testWidgets('the banner is visible on every destination', (tester) async {
      await pumpApp(tester, world(), notice: notice);
      expect(find.byKey(const Key('storage-banner')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('storage-banner')), findsOneWidget);
    });

    testWidgets('works in a phone-sized window too', (tester) async {
      await pumpApp(tester, world(), width: 380, notice: notice);
      expect(find.byType(NavigationBar), findsNothing, reason: 'a phone uses the drawer');
      expect(find.byKey(const Key('nav-menu')), findsOneWidget);
      expect(find.byKey(const Key('storage-banner')), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
    });
  });
}
