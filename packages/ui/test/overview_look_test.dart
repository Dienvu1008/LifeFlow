// Dogfooding F2 (ADR-0051): drag handles by setting (O1), the drag feedback
// (O2), the type scale, the font and the text size (O3).
import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';
import 'nav.dart';

FakeWorld world({AppearanceSettings look = const AppearanceSettings()}) {
  final w = FakeWorld(
    tasks: {
      'A': [task('W1', 'Plan', list: 'Work'), task('A', 'Call mum'), task('B', 'Buy bread')],
    },
    profiles: [profile('A', 'Guest')],
    activeId: 'A',
  );
  w.overview.lists.add(const TaskListView(id: 'Work', title: 'Work', orderKey: ''));
  w.overview.order.addAll(['W1', 'A', 'B']);
  w.look = look;
  return w;
}

Future<void> pumpApp(WidgetTester tester, FakeWorld w, {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

void main() {
  group('O1: drag handles', () {
    testWidgets('Auto: hidden on a phone platform; the row is 24 dp wider for its title', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      expect(find.byKey(const ValueKey('drag-A')), findsNothing);
      final hidden = tester.getTopLeft(find.text('Call mum')).dx;
      await tester.pumpWidget(const SizedBox.shrink());
      final shown = world(look: const AppearanceSettings(dragHandles: DragHandles.always));
      await pumpApp(tester, shown);
      expect(find.byKey(const ValueKey('drag-A')), findsOneWidget);
      expect(tester.getTopLeft(find.text('Call mum')).dx - hidden, closeTo(24, 0.5));
    });

    testWidgets('Auto: shown with a pointer (Windows)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpApp(tester, world());
      expect(find.byKey(const ValueKey('drag-A')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Never on Windows: no handles, a long press still drags', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final w = world(look: const AppearanceSettings(dragHandles: DragHandles.never));
      await pumpApp(tester, w);
      expect(find.byKey(const ValueKey('drag-A')), findsNothing);
      final start = tester.getCenter(find.text('Buy bread'));
      final g = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 700));
      final end = tester.getCenter(find.byKey(const ValueKey('list-Work')));
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(start, end, i / 10)!);
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(w.calls.last, 'task.move:B:in:Work@null');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Settings: the choice is saved and applies at once', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await goToTab(tester, 'Settings');
      await tester.tap(find.descendant(of: find.byKey(const Key('drag-handles')), matching: find.text('Always')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'setAppearance:always:system:1.0');
      await goToTab(tester, 'Overview');
      expect(find.byKey(const ValueKey('drag-A')), findsOneWidget);
    });
  });

  testWidgets('O2: the dragged copy is the whole row; the original fades; the line sits at the landing level',
      (tester) async {
    final w = world(look: const AppearanceSettings(dragHandles: DragHandles.always));
    await pumpApp(tester, w);
    final row = tester.getRect(find.byKey(const ValueKey('slot-B')));
    final start = tester.getCenter(find.byKey(const ValueKey('drag-B')));
    final g = await tester.startGesture(start);
    await tester.pump();
    await g.moveBy(const Offset(0, -24)); // past the touch slop
    await tester.pump();
    final copy = find.byKey(const Key('drag-feedback'));
    expect(copy, findsOneWidget);
    expect(tester.getSize(copy).width, closeTo(row.width, 0.5));
    expect(find.descendant(of: copy, matching: find.text('Buy bread')), findsOneWidget);
    final fade = tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('fade-B')));
    expect(fade.opacity, lessThan(0.5));
    // Over the lower quarter of Plan (inside Work): after Plan, in the list.
    final plan = tester.getRect(find.byKey(const ValueKey('slot-W1')));
    await g.moveTo(Offset(start.dx, plan.bottom - 3));
    await tester.pumpAndSettle();
    final line = tester.getRect(find.byKey(const Key('drop-line')));
    expect(line.left - plan.left, closeTo(1 * 24 + 8, 0.5), reason: 'a list item: one step in');
    await g.up();
    await tester.pumpAndSettle();
    expect(w.calls.last, 'task.move:B:in:Work@W1');
    expect(find.byKey(const Key('drag-feedback')), findsNothing);
    expect(tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('fade-B'))).opacity, 1);
  });

  group('O3: type', () {
    testWidgets('a list title is the size of its tasks, bolder', (tester) async {
      await pumpApp(tester, world());
      TextStyle styleOf(String s) =>
          DefaultTextStyle.of(tester.element(find.text(s))).style.merge(tester.widget<Text>(find.text(s)).style);
      final list = styleOf('Work');
      final taskTitle = styleOf('Plan');
      final loose = styleOf('Call mum');
      expect(list.fontSize, greaterThanOrEqualTo(taskTitle.fontSize!));
      expect(list.fontWeight, FontWeight.w700);
      expect(taskTitle.fontSize, loose.fontSize, reason: 'tasks in and out of a list alike');
    });

    testWidgets('the font and the text size from Settings apply to the app', (tester) async {
      final w = world();
      await pumpApp(tester, w);
      await goToTab(tester, 'Settings');
      await tester.tap(find.byKey(const Key('app-font')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Be Vietnam Pro').last);
      await tester.pumpAndSettle();
      expect(w.calls.last, 'setAppearance:auto:beVietnamPro:1.0');
      final ctx = tester.element(find.byKey(const Key('app-font')));
      expect(Theme.of(ctx).textTheme.bodyMedium!.fontFamily, 'packages/ui/BeVietnamPro');
      // The slider saves in 5 % steps.
      await tester.drag(find.byKey(const Key('text-size')), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(w.calls.last, matches(RegExp(r'^setAppearance:auto:beVietnamPro:1\.\d+$')));
      expect(w.look.textScale, greaterThan(1.0));
    });

    testWidgets('the text size multiplies the system text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final w = world(look: const AppearanceSettings(textScale: 1.2));
      await pumpApp(tester, w);
      final ctx = tester.element(find.text('Plan'));
      expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(10 * 1.5 * 1.2, 0.01));
    });

    test('the text size is clamped to 80–150 %', () {
      expect(const AppearanceSettings().copyWith(textScale: 3).textScale, 1.5);
      expect(const AppearanceSettings().copyWith(textScale: 0.1).textScale, 0.8);
    });
  });
}
