// Moving between the top-level tabs in widget tests: through the navigation
// drawer in the compact (phone) layout, directly on the rail otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the navigation drawer (compact layout only).
Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav-menu')).first);
  await tester.pumpAndSettle();
}

/// Goes to the tab [label] ("Tasks", "Calendar", "Goals", "Profiles",
/// "Settings"). On a phone, Profiles is the drawer's header.
Future<void> goToTab(WidgetTester tester, String label) async {
  if (find.byKey(const Key('nav-menu')).evaluate().isNotEmpty) {
    await openDrawer(tester);
    await tester.tap(label == 'Profiles'
        ? find.byKey(const Key('drawer-profile'))
        : find.descendant(of: find.byKey(const Key('nav-drawer')), matching: find.text(label)));
  } else {
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(label)));
  }
  await tester.pumpAndSettle();
}
