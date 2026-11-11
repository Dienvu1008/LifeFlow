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
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: AdaptiveScaffold(
      selectedIndex: 0,
      onSelected: onSelected ?? (_) {},
      notice: notice,
      body: const Center(child: Text('content')),
    ),
  ));
}

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
    testWidgets('compact: bottom navigation, no rail', (tester) async {
      await pumpShell(tester, width: 400);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
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
      expect(find.byType(NavigationBar), findsOneWidget);
      tester.view.physicalSize = const Size(1100, 800);
      await tester.pump();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('selecting a destination reports its index', (tester) async {
      int? picked;
      await pumpShell(tester, width: 400, onSelected: (i) => picked = i);
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
