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
  await tester.tap(find.byKey(const Key('rail-profile')));
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


  group('restore: a profile not on this device', () {
    testWidgets('asks first, then adds it as a separate profile',
        (tester) async {
      final w = world()..pickResult = '{"the":"file"}';
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.text('Restore as a new profile?'), findsOneWidget);
      expect(find.textContaining('"Backup of work" (3 tasks)'), findsOneWidget);
      expect(w.calls, ['pick', 'inspect:{"the":"file"}']); // nothing written yet

      await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'restore:{"the":"file"}:-');
      expect(find.textContaining('was restored with 3 tasks'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();
      expect(find.text('Backup of work'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Switch'), findsOneWidget);
      expect(w.activeId, 'A');
    });

    testWidgets('Cancel adds nothing', (tester) async {
      final w = world()..pickResult = 'x';
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls, ['pick', 'inspect:x']);
      expect(w.profiles, hasLength(1));
    });
  });

  group('restore into this profile (no second profile)', () {
    const diff = RestoreDiff(
        onlyInFile: 2, onlyOnDevice: 1, differing: 3, newerInFile: 1);

    testWidgets('an identical file says there is nothing to restore',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreIdentical();
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to restore'), findsOneWidget);
      expect(find.textContaining('are the same'), findsOneWidget);
      expect(w.calls, ['pick', 'inspect:x']);
      expect(w.profiles, hasLength(1));
    });

    testWidgets('a different file shows the differences and the choices',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreDifferent(diff);
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restore-choice')), findsOneWidget);
      expect(find.text('Only in the file: 2'), findsOneWidget);
      expect(find.text('Only on this device: 1'), findsOneWidget);
      expect(find.textContaining('different: 3 (newer in the file: 1)'), findsOneWidget);
      expect(find.text('Overwrite everything'), findsOneWidget);
      expect(find.text('Merge'), findsWidgets);
      expect(find.text('Use the newer version'), findsOneWidget);
      expect(find.text('Add what is only in the file'), findsOneWidget);
    });

    testWidgets('overwrite: applies, reports, and offers undo', (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreDifferent(diff)
        ..restoreResults.add(const RestoredInto(
            added: 2, updated: 3, removed: 1, undoAvailable: true));
      await openProfiles(tester, w);
      expect(find.byKey(const Key('undo-restore')), findsNothing);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mode-overwrite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restore-go')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'restore:x:overwrite');
      expect(find.textContaining('Added 2 items. Updated 3 items. Moved 1 item to the trash.'),
          findsOneWidget);
      expect(w.profiles, hasLength(1)); // never a second profile
      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      await tester.pumpAndSettle();

      // Undo is offered and asks first.
      await tester.tap(find.byKey(const Key('undo-restore')));
      await tester.pumpAndSettle();
      expect(find.text('Undo the last restore?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Undo restore'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'undo');
      expect(find.text('The last restore was undone.'), findsOneWidget);
      expect(find.byKey(const Key('undo-restore')), findsNothing);
    });

    testWidgets('merge: the two options are passed through; both off cannot start',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreDifferent(diff)
        ..restoreResults.add(const RestoredInto(
            added: 0, updated: 1, removed: 0, undoAvailable: true));
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      // Merge is the default with both options on; turn both off.
      await tester.tap(find.byKey(const Key('opt-newer')));
      await tester.tap(find.byKey(const Key('opt-missing')));
      await tester.pumpAndSettle();
      final go = tester.widget<FilledButton>(find.byKey(const Key('restore-go')));
      expect(go.onPressed, isNull);
      // (a) only.
      await tester.tap(find.byKey(const Key('opt-newer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restore-go')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'restore:x:merge(newer=true,missing=false,keepParents=false)');
      expect(find.textContaining('Updated 1 item.'), findsOneWidget);
    });

    testWidgets('a hierarchy conflict offers: keep device parents, or cancel',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreDifferent(diff)
        ..restoreResults.addAll(const [
          RestoreHierarchyConflict(['Learn English']),
          RestoredInto(added: 0, updated: 1, removed: 0, undoAvailable: true),
        ]);
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restore-go')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hierarchy-conflict')), findsOneWidget);
      expect(find.textContaining('• Learn English'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Keep this device\'s parents'));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'restore:x:merge(newer=true,missing=true,keepParents=true)');
      expect(find.text('Restored'), findsOneWidget);
    });

    testWidgets('cancelling the hierarchy question changes nothing',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreDifferent(diff)
        ..restoreResults.add(const RestoreHierarchyConflict(['A', 'B']));
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('restore-go')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(w.calls.where((c) => c.startsWith('restore:')), hasLength(1));
      expect(find.text('Restore cancelled. Nothing was changed.'), findsOneWidget);
    });

    testWidgets('a file of another profile says where to restore it',
        (tester) async {
      final w = world()
        ..pickResult = 'x'
        ..nextPreview = const RestoreOtherProfile(displayName: 'Work', locked: true);
      await openProfiles(tester, w);
      await tester.tap(find.text('Restore from a file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('belongs to "Work", which is signed out'), findsOneWidget);
      expect(w.calls, ['pick', 'inspect:x']);
    });
  });

  group('restore: rejected files', () {
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
          ..nextPreview = RestoreRejected(c.$1, c.$2);
        await openProfiles(tester, w);
        await tester.tap(find.text('Restore from a file'));
        await tester.pumpAndSettle();
        expect(find.text('Cannot restore'), findsOneWidget);
        expect(find.textContaining(c.$2), findsOneWidget);
        expect(find.textContaining('Nothing was changed.'), findsOneWidget);
        expect(w.calls, ['pick', 'inspect:x']);
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
