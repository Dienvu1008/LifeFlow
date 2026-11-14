// Dogfooding F5 (ADR-0051, C2): every Calendar view turns like pages. The
// arrows slide the next period in; so do a swipe, a mouse drag, a sideways
// wheel, ←/→ and PageUp/PageDown. A vertical drag still scrolls the hours,
// a tap still picks a slot, and two fingers (pinch zoom) do not turn.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'calendar_flow_test.dart' show mode, pumpCalendar, world;

final _pages = find.byKey(const Key('calendar-pages'));

Finder _in(String key) => find.descendant(of: _pages, matching: find.byKey(Key(key)));

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

void main() {
  testWidgets('the arrows slide the next and previous period in, in every view', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    for (final (label, view, now, next) in [
      ('Day', 'calendar-grid', 'Mon 9 Nov 2026', 'Tue 10 Nov 2026'),
      ('Week', 'calendar-grid', '9 – 15 Nov 2026', '16 – 22 Nov 2026'),
      ('Month', 'calendar-month', 'November 2026', 'December 2026'),
      ('Year', 'calendar-year', '2026', '2027'),
    ]) {
      await mode(tester, label);
      expect(find.text(now), findsOneWidget, reason: label);
      await tester.tap(find.byKey(const Key('calendar-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Halfway: both periods are on screen, side by side.
      expect(_in(view), findsNWidgets(2), reason: '$label slides');
      final xs = [for (final e in _in(view).evaluate()) tester.getTopLeft(find.byWidget(e.widget)).dx];
      expect(xs.reduce((a, b) => a < b ? a : b), lessThan(0), reason: label);
      await _settle(tester);
      expect(_in(view), findsOneWidget);
      expect(find.text(next), findsOneWidget, reason: label);
      await tester.tap(find.byKey(const Key('calendar-prev')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_in(view), findsNWidgets(2), reason: '$label slides back');
      await _settle(tester);
      expect(find.text(now), findsOneWidget, reason: label);
    }
  });

  testWidgets('a swipe turns pages both ways; Today and the views still jump', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await tester.fling(_pages, const Offset(-400, 0), 1500);
    await _settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
    await tester.fling(_pages, const Offset(-400, 0), 1500);
    await _settle(tester);
    expect(find.text('January 2027'), findsOneWidget);
    await tester.fling(_pages, const Offset(400, 0), 1500);
    await _settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-go-today')));
    await _settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    // A day in the month opens it; the pager starts again from there.
    await tester.tap(find.byKey(const ValueKey('month-cell-2026-11-20')));
    await _settle(tester);
    expect(find.text('Fri 20 Nov 2026'), findsOneWidget);
    await tester.fling(_pages, const Offset(-400, 0), 1500);
    await _settle(tester);
    expect(find.text('Sat 21 Nov 2026'), findsOneWidget);
  });

  testWidgets('a mouse drags pages (Windows)', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await tester.drag(_pages, const Offset(-600, 0), kind: PointerDeviceKind.mouse);
    await _settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
    await tester.drag(_pages, const Offset(600, 0), kind: PointerDeviceKind.mouse);
    await _settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('a sideways wheel or touchpad scroll turns a page; a vertical one scrolls the hours', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await mode(tester, 'Week');
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final centre = tester.getCenter(_pages);
    await tester.sendEventToBinding(mouse.hover(centre));
    await tester.sendEventToBinding(mouse.scroll(const Offset(20, 0)));
    await _settle(tester);
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget); // not far enough yet
    await tester.sendEventToBinding(mouse.scroll(const Offset(30, 0)));
    await _settle(tester);
    expect(find.text('16 – 22 Nov 2026'), findsOneWidget);
    await tester.sendEventToBinding(mouse.scroll(const Offset(-60, 0)));
    await _settle(tester);
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
    // Up and down: the hours move, the week stays.
    final grid = tester.widget<SingleChildScrollView>(_in('calendar-grid')).controller!;
    final before = grid.offset;
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
    await _settle(tester);
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
    expect(grid.offset, lessThan(before));
    // Mostly up and down with a little sideways: still not a page.
    await mode(tester, 'Month');
    await tester.sendEventToBinding(mouse.scroll(const Offset(30, 60)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(30, 60)));
    await _settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    await mode(tester, 'Week');
    // Shift + the wheel turns too.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 60)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _settle(tester);
    expect(find.text('16 – 22 Nov 2026'), findsOneWidget);
  });

  testWidgets('←/→ and PageUp/PageDown turn pages', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(find.text('December 2026'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await _settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settle(tester);
    expect(find.text('October 2026'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await _settle(tester);
    expect(find.text('November 2026'), findsOneWidget);
    // Two presses during one slide go two pages on.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(find.text('January 2027'), findsOneWidget);
  });

  testWidgets('a vertical drag scrolls the hours and a tap still picks a slot', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await mode(tester, 'Week');
    final grid = tester.widget<SingleChildScrollView>(_in('calendar-grid')).controller!;
    final before = grid.offset;
    await tester.drag(_in('calendar-grid'), const Offset(-30, 200));
    await _settle(tester);
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
    expect(grid.offset, lessThan(before));
    await tester.tap(find.byKey(const ValueKey('grid-2026-11-11')));
    await _settle(tester);
    expect(find.byKey(const Key('slot-title')), findsOneWidget);
  });

  testWidgets('two fingers (pinch zoom) do not turn the page', (tester) async {
    final w = world();
    await pumpCalendar(tester, w);
    await mode(tester, 'Week');
    final c = tester.getCenter(_pages);
    final a = await tester.startGesture(c - const Offset(60, 0), pointer: 7);
    final b = await tester.startGesture(c + const Offset(60, 0), pointer: 8);
    await tester.pump();
    final pager = tester.widget<PageView>(find.byType(PageView)).controller!;
    for (var i = 0; i < 10; i++) {
      await a.moveBy(const Offset(-40, 0));
      await b.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(pager.page, pager.page!.roundToDouble(), reason: 'the page holds still');
    }
    await a.up();
    await b.up();
    await _settle(tester);
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
    // One finger again: it turns.
    await tester.fling(_pages, const Offset(-400, 0), 1500);
    await _settle(tester);
    expect(find.text('16 – 22 Nov 2026'), findsOneWidget);
  });
}
