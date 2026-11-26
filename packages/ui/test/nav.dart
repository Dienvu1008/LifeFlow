// Moving between the top-level tabs in widget tests: through the navigation
// drawer in the compact (phone) layout, directly on the rail otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the navigation drawer (compact layout only).
Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-menu')).first);
  await tester.pumpAndSettle();
}

/// Goes to the destination [label] ("Overview", "Timeline", "Calendar",
/// "Documents", "Assistant", "Habits", "Goals", "Settings", or "Profiles": the profile at the top of
/// the drawer or the rail).
Future<void> goToTab(WidgetTester tester, String label) async {
  if (find.byKey(const Key('nav-menu')).evaluate().isNotEmpty) {
    await openDrawer(tester);
    await tester.tap(label == 'Profiles'
        ? find.byKey(const Key('drawer-profile'))
        : find.descendant(of: find.byKey(const Key('nav-drawer')), matching: find.text(label)));
  } else if (label == 'Profiles') {
    // P03 UX U6: the profile at the top of the rail.
    await tester.tap(find.byKey(const Key('rail-profile')));
  } else {
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(label)));
  }
  await tester.pumpAndSettle();
}

/// P06b W2: opens the search from the shown screen's options menu ([menu]
/// is the menu's key: 'screen-options' on the main screens).
Future<void> openSearchFromMenu(WidgetTester tester, {String menu = 'screen-options'}) async {
  await tester.tap(find.byKey(Key(menu)).hitTestable().first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('options-search')));
  await tester.pumpAndSettle();
}

/// Types [text] into the search and waits for its results.
Future<void> searchFor(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('search-field')), text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}
