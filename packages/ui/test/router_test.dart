// Regression (T6b, Android): an OS-delivered link such as the OAuth callback
// lifeflow://callback?code=... reached go_router as location "/" and replaced
// the whole app with "Page Not Found". Unknown locations land on the Overview.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'fake_world.dart';

Future<void> pumpAt(WidgetTester tester, String location) async {
  final w = FakeWorld(
    tasks: {'A': [task('t', 'Existing task')]},
    profiles: [profile('A', 'Guest')],
    activeId: 'A',
  );
  addTearDown(w.dispose);
  final router = createRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      taskQueriesProvider.overrideWithValue(w),
      taskServiceProvider.overrideWithValue(w),
      profileServiceProvider.overrideWithValue(w),
      accountServiceProvider.overrideWithValue(w),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final location in [
    '/',
    '/?code=f0d61a4a-1177-49c9-9ce8-7fca3b339ef6',
    '/callback?code=abc',
    '/no/such/page',
    '/tasks', // P03 UX U6: the old first location is the Overview
  ]) {
    testWidgets('"$location" lands on the Overview, never "Page Not Found"',
        (tester) async {
      await pumpAt(tester, location);
      expect(find.textContaining('Page Not Found'), findsNothing);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.text('Existing task'), findsOneWidget);
    });
  }

  testWidgets('known routes are left alone', (tester) async {
    await pumpAt(tester, '/profiles');
    expect(find.byKey(const Key('account-card')), findsOneWidget);
  });
}
