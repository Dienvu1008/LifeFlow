// Deleting a profile from the profile chooser (ADR-0027).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';

FakeWorld world() => FakeWorld(
      tasks: {
        'A': [task('t1', 'Mine')],
        'B': [task('b1', 'Old')],
        'C': [],
      },
      profiles: [
        profile('A', 'Guest'),
        profile('B', 'Guest (restored)'),
        profile('C', '', bound: true, provider: 'github'),
      ],
      activeId: 'A',
    );

Future<void> openProfiles(WidgetTester tester, FakeWorld w) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.people_outline));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every profile but the open one has a Delete button',
      (tester) async {
    await openProfiles(tester, world());
    expect(find.byTooltip('Delete Guest (restored)'), findsOneWidget);
    expect(find.byTooltip('Delete Account profile'), findsOneWidget);
    expect(find.byTooltip('Delete Guest'), findsNothing); // the open one
  });

  testWidgets('asks first; Cancel deletes nothing', (tester) async {
    final w = world();
    await openProfiles(tester, w);
    await tester.tap(find.byTooltip('Delete Guest (restored)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-profile')), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(w.calls, isEmpty);
    expect(w.profiles, hasLength(3));
  });

  testWidgets('confirming deletes it and it leaves the list', (tester) async {
    final w = world();
    await openProfiles(tester, w);
    await tester.tap(find.byTooltip('Delete Guest (restored)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete profile'));
    await tester.pumpAndSettle();
    expect(w.calls, ['deleteProfile:B']);
    expect(find.text('Guest (restored)'), findsNothing);
    expect(find.text('"Guest (restored)" was deleted.'), findsOneWidget);
  });

  testWidgets('an account profile warns that nothing is online yet',
      (tester) async {
    await openProfiles(tester, world());
    await tester.tap(find.byTooltip('Delete Account profile'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing of it is stored online yet'), findsOneWidget);
  });

  testWidgets('a refused delete is shown and the profile stays', (tester) async {
    final w = world()
      ..failNext = const CommandFailure(CommandFailureKind.policyDenied,
          reason: 'switch to another profile before deleting this one');
    await openProfiles(tester, w);
    await tester.tap(find.byTooltip('Delete Guest (restored)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete profile'));
    await tester.pumpAndSettle();
    expect(find.text('Guest (restored)'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
