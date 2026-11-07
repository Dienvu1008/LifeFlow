// Export / restore in the UI (UC-20a, OQ-DATA-3 option a, GS-20).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';

FakeWorld world() => FakeWorld(
      tasks: {
        'A': [task('t1', 'One'), task('t2', 'Two')],
      },
      profiles: [profile('A', 'Guest')],
      activeId: 'A',
    );

Future<void> openProfiles(WidgetTester tester, FakeWorld w) async {
  tester.view.physicalSize = const Size(1000, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.people_outline));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Profiles screen explains why a backup matters',
      (tester) async {
    await openProfiles(tester, world());
    expect(find.byKey(const Key('data-card')), findsOneWidget);
    expect(find.textContaining('cannot be recovered'), findsOneWidget);
    expect(find.text('Export this profile'), findsOneWidget);
    expect(find.text('Restore from a file'), findsOneWidget);
  });

  group('export', () {
    testWidgets('warns it is unencrypted, then saves through the file dialog',
        (tester) async {
      final w = world();
      await openProfiles(tester, w);
      await tester.tap(find.text('Export this profile'));
      await tester.pumpAndSettle();
      expect(find.textContaining('UNENCRYPTED'), findsOneWidget);
      expect(find.textContaining('no password, key or sign-in token'), findsOneWidget);
      expect(w.calls, isEmpty); // nothing happens before the user confirms

      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();
      expect(w.calls, ['export', 'save:lifeflow-test-2026-11-07.lifeflow.json']);
      expect(find.text('Exported 2 tasks.'), findsOneWidget);
    });

    testWidgets('Cancel on the warning exports nothing', (tester) async {
      final w = world();
      await openProfiles(tester, w);
      await tester.tap(find.text('Export this profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls, isEmpty);
    });

    testWidgets('cancelling the save dialog says nothing was saved',
        (tester) async {
      final w = world()..saveResult = false;
      await openProfiles(tester, w);
      await tester.tap(find.text('Export this profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Export'));
      await tester.pumpAndSettle();
      expect(find.text('Export cancelled. Nothing was saved.'), findsOneWidget);
    });
  });

  group('restore', () {
    testWidgets('a valid file adds a separate profile and says how to open it',
        (tester) async {
      final w = world()..pickResult = '{"the":"file"}';
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(w.calls, ['pick', 'restore:{"the":"file"}']);
      expect(find.text('Restored'), findsOneWidget);
      expect(find.textContaining('was restored with 3 tasks'), findsOneWidget);
      expect(find.textContaining('Switch to it'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      // The new profile is now listed with a Switch button; not activated.
      expect(find.text('Backup of work'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Switch'), findsOneWidget);
      expect(w.activeId, 'A');
    });

    testWidgets('a profile already on the device is explained as a copy',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextRestore = Restored(
            profile('A2', 'Guest (restored)'), asCopy: true, taskCount: 1);
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('already on this device'), findsOneWidget);
      expect(find.textContaining('separate copy'), findsOneWidget);
      expect(find.textContaining('was not changed'), findsOneWidget);
      expect(find.textContaining('1 task.'), findsOneWidget); // singular
    });

    for (final c in <(RestoreRejection, String)>[
      (RestoreRejection.newerVersion,
          'This export was made by a newer version of LifeFlow. Update the app, then try again.'),
      (RestoreRejection.corrupted,
          'This file was changed or damaged and cannot be restored.'),
      (RestoreRejection.notAnExport, 'This is not a LifeFlow export file.'),
    ]) {
      testWidgets('a rejected file (${c.$1.name}) shows the reason and changes nothing',
          (tester) async {
        final w = world()
          ..pickResult = 'x'
          ..nextRestore = RestoreRejected(c.$1, c.$2);
        await openProfiles(tester, w);
        await tester.tap(find.text('Restore from a file'));
        await tester.pumpAndSettle();
        expect(find.text('Cannot restore'), findsOneWidget);
        expect(find.textContaining(c.$2), findsOneWidget);
        expect(find.textContaining('Nothing was changed.'), findsOneWidget);
        expect(w.profiles, hasLength(1));
      });
    }

    testWidgets('cancelling the file dialog does nothing', (tester) async {
      final w = world(); // pickResult == null
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(w.calls, ['pick']);
      expect(find.text('Cannot restore'), findsNothing);
    });

    testWidgets('a huge file is refused with a clear message', (tester) async {
      final w = world()..pickTooLarge = true;
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('too large'), findsOneWidget);
      expect(w.calls, ['pick']); // never reached the service
    });

    testWidgets('an unreadable file is reported, not crashed on',
        (tester) async {
      final w = world()..pickThrows = true;
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.text('The file could not be read.'), findsOneWidget);
    });
  });
}
