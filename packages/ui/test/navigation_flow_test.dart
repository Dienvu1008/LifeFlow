// P03 UX U6 (ADR-0050): six destinations, the profile on top of the drawer
// and the rail, Habits on its own (U-D2), and the result policy of measured
// tasks completed by hand (U-D13) in Settings.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';
import 'nav.dart';

FakeWorld world() => FakeWorld(
      tasks: {'A': [task('t', 'Existing task')]},
      profiles: [profile('A', 'Guest')],
      activeId: 'A',
    );

Future<void> pumpApp(WidgetTester tester, FakeWorld w, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

/// The title of the current screen's app bar.
Finder title(String text) => find.descendant(of: find.byType(AppBar), matching: find.text(text));

void main() {
  for (final width in [400.0, 1000.0]) {
    final where = width < 600 ? 'phone (drawer)' : 'wide (rail)';
    testWidgets('$where: the app opens on the Overview; every destination opens its screen', (tester) async {
      final w = world();
      await pumpApp(tester, w, width: width);
      expect(title('Overview'), findsOneWidget);
      expect(find.text('Existing task'), findsOneWidget);
      await goToTab(tester, 'Timeline');
      expect(find.byKey(const Key('timeline-month')), findsOneWidget);
      await goToTab(tester, 'Calendar');
      expect(find.byKey(const Key('calendar-mode')), findsOneWidget);
      await goToTab(tester, 'Habits');
      expect(title('Habits'), findsOneWidget);
      expect(find.byKey(const Key('habits-empty')), findsOneWidget);
      await goToTab(tester, 'Goals');
      expect(title('Goals'), findsOneWidget);
      await goToTab(tester, 'Settings');
      expect(title('Settings'), findsOneWidget);
      await goToTab(tester, 'Profiles');
      expect(find.byKey(const Key('account-card')), findsOneWidget);
      await goToTab(tester, 'Overview');
      expect(find.text('Existing task'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Calendar\'s Timeline button opens the Timeline destination', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await goToTab(tester, 'Calendar');
    await tester.tap(find.byKey(const Key('calendar-today-tasks')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-month')), findsOneWidget);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 1);
  });

  testWidgets('U-D13: Settings chooses how measured tasks completed by hand are kept', (tester) async {
    final w = world();
    await pumpApp(tester, w);
    await goToTab(tester, 'Settings');
    final tick = find.byKey(const Key('results-tick'));
    await tester.scrollUntilVisible(tick, 300, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(tick);
    await tester.pumpAndSettle();
    expect(find.text('Measured tasks you tick yourself'), findsOneWidget);
    ManualResults? chosen() => tester.widget<RadioGroup<ManualResults>>(find.byType(RadioGroup<ManualResults>)).groupValue;
    expect(chosen(), ManualResults.target);
    await tester.tap(tick);
    await tester.pumpAndSettle();
    expect(w.calls.last, 'habit.manualResults:tick');
    expect(chosen(), ManualResults.tick);
    // A refusal is shown and nothing changes.
    w.habits.failNext = const CommandFailure(CommandFailureKind.versionConflict, reason: 'changed elsewhere');
    await tester.tap(find.byKey(const Key('results-target')));
    await tester.pumpAndSettle();
    expect(chosen(), ManualResults.tick);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
