// Adaptive shell + storage banner (ui-ux-architecture §2, ADR-0021, SR-01a).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

Future<void> pumpShell(
  WidgetTester tester, {
  required double width,
  StorageNotice? notice,
  ValueChanged<int>? onSelected,
  int selectedIndex = 0,
  ProfileView? profile = guest,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: AdaptiveScaffold(
      selectedIndex: selectedIndex,
      onSelected: onSelected ?? (_) {},
      notice: notice,
      profile: profile,
      // A tab's own app bar, as the screens have.
      body: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(leading: shellMenuButton(context), title: const Text('Tab')),
          body: const Center(child: Text('content')),
        ),
      ),
    ),
  ));
}

const guest = ProfileView(id: 'A', displayName: 'Dien Vu', isActive: true, isBound: false);
const bound = ProfileView(id: 'B', displayName: 'Work', isActive: true, isBound: true, provider: 'github');

const windowsPlain = StorageNotice(
  atRestEncrypted: false,
  trackedException: true,
  message: 'At-rest encryption is OFF on Windows (MVP tracked exception).',
);
const unexpectedPlain = StorageNotice(
  atRestEncrypted: false,
  trackedException: false,
  message: 'At-rest encryption is OFF but was expected.',
);
const encrypted = StorageNotice(atRestEncrypted: true, trackedException: false);

void main() {
  group('layout follows window width', () {
    testWidgets('compact: a navigation drawer, no bottom bar, no rail (the content keeps the height)', (tester) async {
      await pumpShell(tester, width: 400);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-menu')));
      await tester.pumpAndSettle();
      final drawer = find.byKey(const Key('nav-drawer'));
      expect(drawer, findsOneWidget);
      // Profiles is the header; the rest are destinations, in order.
      for (final label in ['Tasks', 'Calendar', 'Goals', 'Settings']) {
        expect(find.descendant(of: drawer, matching: find.text(label)), findsOneWidget, reason: label);
      }
      expect(find.descendant(of: drawer, matching: find.text('Profiles')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('drawer-profile'))).dy,
          lessThan(tester.getTopLeft(find.descendant(of: drawer, matching: find.text('Tasks'))).dy),
          reason: 'the profile comes first');
    });

    testWidgets('compact: the drawer header shows the profile picture, name and status', (tester) async {
      await pumpShell(tester, width: 400);
      await tester.tap(find.byKey(const Key('nav-menu')));
      await tester.pumpAndSettle();
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('DV'), findsOneWidget, reason: 'initials until profiles have a photo');
      expect(find.text('Dien Vu'), findsOneWidget);
      expect(find.text('Guest · on this device'), findsOneWidget);
      expect(find.bySemanticsLabel('Profile: Dien Vu, Guest · on this device. Open profiles'), findsOneWidget);
    });

    testWidgets('compact: a signed-in profile says how', (tester) async {
      await pumpShell(tester, width: 400, profile: bound);
      await tester.tap(find.byKey(const Key('nav-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Signed in with GitHub'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
    });

    testWidgets('compact: a tab in the drawer and the profile header report their index; the drawer closes',
        (tester) async {
      int? picked;
      await pumpShell(tester, width: 400, onSelected: (i) => picked = i);
      for (final (label, index) in [('Calendar', 1), ('Goals', 2), ('Settings', 4), ('Tasks', 0)]) {
        await tester.tap(find.byKey(const Key('nav-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(of: find.byKey(const Key('nav-drawer')), matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(picked, index, reason: label);
        expect(find.byKey(const Key('nav-drawer')), findsNothing, reason: 'closed after choosing');
      }
      await tester.tap(find.byKey(const Key('nav-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-profile')));
      await tester.pumpAndSettle();
      expect(picked, profilesIndex);
    });

    testWidgets('compact: the drawer marks the current tab', (tester) async {
      await pumpShell(tester, width: 400, selectedIndex: 2);
      await tester.tap(find.byKey(const Key('nav-menu')));
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationDrawer>(find.byKey(const Key('nav-drawer'))).selectedIndex, 2);
    });

    testWidgets('compact: on Profiles no destination is marked', (tester) async {
      await pumpShell(tester, width: 400, selectedIndex: profilesIndex);
      await tester.tap(find.byKey(const Key('nav-menu')));
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationDrawer>(find.byKey(const Key('nav-drawer'))).selectedIndex, isNull);
    });

    testWidgets('rail layouts have no menu button', (tester) async {
      await pumpShell(tester, width: 700);
      expect(find.byKey(const Key('nav-menu')), findsNothing);
    });

    testWidgets('medium: rail with labels, not extended', (tester) async {
      await pumpShell(tester, width: 700);
      expect(find.byType(NavigationBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(rail.labelType, NavigationRailLabelType.all);
    });

    testWidgets('expanded: extended rail', (tester) async {
      await pumpShell(tester, width: 1100);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('the same window resized switches layout', (tester) async {
      await pumpShell(tester, width: 400);
      expect(find.byKey(const Key('nav-menu')), findsOneWidget);
      tester.view.physicalSize = const Size(1100, 800);
      await tester.pump();
      expect(find.byKey(const Key('nav-menu')), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('rail: selecting a destination reports its index', (tester) async {
      int? picked;
      await pumpShell(tester, width: 700, onSelected: (i) => picked = i);
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      await tester.pump();
      expect(picked, 1);
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pump();
      expect(picked, 2, reason: 'P03 D12: Goals is the 3rd destination');
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pump();
      expect(picked, 3);
    });
  });

  group('storage banner (ADR-0021: never silent)', () {
    testWidgets('Windows tracked exception shows the warning text',
        (tester) async {
      await pumpShell(tester, width: 700, notice: windowsPlain);
      expect(find.byKey(const Key('storage-banner')), findsOneWidget);
      expect(find.textContaining('OFF on Windows'), findsOneWidget);
    });

    testWidgets('unexpected unencrypted state is also shown', (tester) async {
      await pumpShell(tester, width: 400, notice: unexpectedPlain);
      expect(find.byKey(const Key('storage-banner')), findsOneWidget);
    });

    testWidgets('encrypted storage shows no banner', (tester) async {
      await pumpShell(tester, width: 400, notice: encrypted);
      expect(find.byKey(const Key('storage-banner')), findsNothing);
    });

    testWidgets('no notice shows no banner', (tester) async {
      await pumpShell(tester, width: 400);
      expect(find.byKey(const Key('storage-banner')), findsNothing);
    });

    testWidgets('the banner is exposed to assistive tech as a live region',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester, width: 700, notice: windowsPlain);
      expect(
        find.bySemanticsLabel(RegExp('Storage warning')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
