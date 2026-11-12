// P03 UX U1 (ADR-0045): the theme module.
//   U-D4   the 12 item colours keep 3:1 against the surface (WCAG 1.4.11)
//   U-D9   density by platform: compact with a pointer, 48 dp on phones
//   U-D10  neutral surfaces, untinted bars; meaning colours readable
//   setting  System / Light / Dark in Settings changes the app at once
import 'dart:math' as math;

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import 'fake_world.dart';
import 'nav.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('colours', () {
    for (final brightness in Brightness.values) {
      final theme = lifeFlowTheme(brightness, platform: TargetPlatform.android);
      final surfaces = {
        'surface': theme.colorScheme.surface,
        'card': theme.colorScheme.surfaceContainerLow,
      };

      test('the item palette keeps 3:1 on ${brightness.name} surfaces', () {
        expect(itemPalette, hasLength(12));
        expect(itemPalette.map((c) => c.name).toSet(), hasLength(12), reason: 'distinct names (read out)');
        for (final c in itemPalette) {
          for (final s in surfaces.entries) {
            expect(contrast(c.on(brightness), s.value), greaterThanOrEqualTo(3.0),
                reason: '${c.name} on ${s.key} (${brightness.name})');
          }
        }
      });

      test('meaning colours keep 3:1 on ${brightness.name} surfaces', () {
        final m = theme.extension<LifeFlowColors>()!;
        for (final (name, color) in [
          ('important', m.important),
          ('overdue', m.overdue),
          ('done', m.done),
          ('cancelled', m.cancelled),
          ('success', m.success),
          ('missed', m.missed),
          ('noData', m.noData),
          ('focus', m.focus),
          ('conflict', m.conflict),
        ]) {
          expect(contrast(color, theme.colorScheme.surface), greaterThanOrEqualTo(3.0), reason: name);
        }
      });

      test('neutral, untinted bars (${brightness.name})', () {
        expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
        expect(theme.cardTheme.elevation, 0);
        // A neutral scheme: the surface is close to grey (low chroma).
        final s = theme.colorScheme.surface;
        final spread = [s.r, s.g, s.b].reduce(math.max) - [s.r, s.g, s.b].reduce(math.min);
        expect(spread, lessThan(0.06));
        // Accents are muted too: colour is kept for meaning (U-D10).
        expect(HSLColor.fromColor(theme.colorScheme.primary).saturation, lessThan(0.35));
      });
    }

    test('each colour has its own tone for dark surfaces', () {
      expect(itemPalette.first.on(Brightness.dark), isNot(itemPalette.first.on(Brightness.light)));
    });
  });

  group('density by platform (U-D9)', () {
    test('a pointer platform is compact with slim bars', () {
      final t = lifeFlowTheme(Brightness.light, platform: TargetPlatform.windows);
      expect(t.visualDensity, VisualDensity.compact);
      expect(t.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
      expect(t.appBarTheme.toolbarHeight, 48);
      expect(t.listTileTheme.dense, isTrue);
    });

    test('a phone keeps 48 dp touch targets', () {
      final t = lifeFlowTheme(Brightness.light, platform: TargetPlatform.android);
      expect(t.visualDensity, VisualDensity.standard);
      expect(t.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(t.appBarTheme.toolbarHeight, 56);
      expect(t.listTileTheme.dense, isFalse);
    });
  });

  testWidgets('Settings: System / Light / Dark changes the app at once', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = FakeWorld(tasks: {'A': []}, profiles: [profile('A', 'Guest')], activeId: 'A');
    addTearDown(w.dispose);
    await tester.pumpWidget(appWith(w));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Settings');
    Brightness shown() => Theme.of(tester.element(find.byKey(const Key('theme-preference')))).brightness;
    expect(shown(), Brightness.light, reason: 'System, and the test platform is light');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'setTheme:dark');
    expect(shown(), Brightness.dark);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect((w.theme, shown()), (ThemePreference.light, Brightness.light));
  });
}
