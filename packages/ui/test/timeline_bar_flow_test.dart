// Dogfooding F4 (ADR-0051, T2/T4): the Timeline app bar and the calendar
// under it. Closed: the full month, "Today" only while today is out of
// sight. Open: the short month between previous / next, no calendar header
// of its own, "Today" only on a page without today; a vertical swipe goes
// month -> two weeks -> week and back; turning a page moves the list to
// the page's first day, or to today when today is on it. A title too long
// for its space slides once inside it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:table_calendar/table_calendar.dart';

import 'fake_world.dart';
import 'nav.dart';
import 'timeline_flow_test.dart' show occurrence, pumpTimeline, world;

final _calendar = find.byKey(const Key('timeline-calendar'));
final _today = find.byKey(const Key('timeline-today'));
final _prev = find.byKey(const Key('timeline-prev'));
final _next = find.byKey(const Key('timeline-next'));

CalendarFormat formatOf(WidgetTester tester) =>
    (tester.widget(find.byWidgetPredicate((w) => w is TableCalendar)) as TableCalendar).calendarFormat;

/// The day header right under the app bar (the list's top).
void expectAtTop(WidgetTester tester, LocalDate d) {
  final header = find.byKey(ValueKey('day-$d'));
  expect(header, findsOneWidget, reason: '$d is shown');
  final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
  expect(tester.getTopLeft(header).dy, moreOrLessEquals(top, epsilon: 1), reason: '$d is at the top');
}

void main() {
  final today = testToday; // Mon 9 Nov 2026

  testWidgets('closed: the full month, no arrows; Today only while today is out of sight', (tester) async {
    final w = world(tasks: [for (var i = -15; i < 30; i++) occurrence('c', 'Item $i', today.addDays(i))]);
    await pumpTimeline(tester, w, height: 600);
    expect(find.text('November 2026'), findsOneWidget);
    expect(_prev, findsNothing);
    expect(_next, findsNothing);
    expect(_today, findsNothing);
    // A little down, today's section is still partly there.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(_today, findsNothing);
    // Further down, it is gone: Today shows and brings it back, at the top
    // (the anchor was today all along).
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('day-$today')), findsNothing);
    expect(_today, findsOneWidget);
    await tester.tap(_today);
    await tester.pumpAndSettle();
    expectAtTop(tester, today);
    expect(_today, findsNothing);
    // Scrolled up into the past, too.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(_today, findsOneWidget);
  });

  testWidgets('open: the short month between the arrows, no header of its own; a page moves the list', (tester) async {
    final w = world(tasks: [occurrence('c', 'Call the bank', today, hour: 9)]);
    await pumpTimeline(tester, w);
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pumpAndSettle();
    expect(_calendar, findsOneWidget);
    expect(find.text('Nov 2026'), findsOneWidget);
    expect(find.text('November 2026'), findsNothing); // table_calendar's header is hidden
    expect(_prev, findsOneWidget);
    expect(_next, findsOneWidget);
    expect(_today, findsNothing); // the page has today
    expectAtTop(tester, today);

    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(find.text('Dec 2026'), findsOneWidget);
    expect(_today, findsOneWidget);
    expectAtTop(tester, LocalDate(2026, 12, 1));
    await tester.tap(_prev);
    await tester.pumpAndSettle();
    await tester.tap(_prev);
    await tester.pumpAndSettle();
    expect(find.text('Oct 2026'), findsOneWidget);
    expectAtTop(tester, LocalDate(2026, 10, 1));
    // Back on today's month the list goes to today, not to the 1st.
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(find.text('Nov 2026'), findsOneWidget);
    expect(_today, findsNothing);
    expectAtTop(tester, today);

    // A swipe turns the page as the arrows do.
    await tester.fling(_calendar, const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Dec 2026'), findsOneWidget);
    expectAtTop(tester, LocalDate(2026, 12, 1));
    // Today brings the calendar and the list back.
    await tester.tap(_today);
    await tester.pumpAndSettle();
    expect(find.text('Nov 2026'), findsOneWidget);
    expect(_today, findsNothing);
    expectAtTop(tester, today);
    expect(find.text('Call the bank'), findsOneWidget);
    // Closed again: the full month, no arrows.
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(_next, findsNothing);
  });

  testWidgets('the calendar opens on the month at the top of the list', (tester) async {
    final dec = LocalDate(2026, 12, 3);
    final w = world(tasks: [
      for (var i = 0; i < 20; i++) occurrence('c', 'Item $i', today.addDays(i)),
      for (var i = 0; i < 12; i++) occurrence('d', 'After $i', dec.addDays(i)),
    ]);
    await pumpTimeline(tester, w, height: 600);
    await tester.scrollUntilVisible(find.byKey(ValueKey('day-$dec')), 300, scrollable: find.byType(Scrollable).last);
    final y = tester.getTopLeft(find.byKey(ValueKey('day-$dec'))).dy;
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    await tester.drag(find.byType(CustomScrollView), Offset(0, -(y - top) - 20));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pumpAndSettle();
    expect(find.text('Dec 2026'), findsOneWidget);
    expect(_today, findsOneWidget);
  });

  testWidgets('a vertical swipe: month -> two weeks -> week and back; week pages move the list by weeks', (tester) async {
    final w = world();
    await pumpTimeline(tester, w);
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pumpAndSettle();
    expect(formatOf(tester), CalendarFormat.month);
    final monthHeight = tester.getSize(_calendar).height;
    await tester.drag(_calendar, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(formatOf(tester), CalendarFormat.twoWeeks);
    await tester.drag(_calendar, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(formatOf(tester), CalendarFormat.week);
    expect(tester.getSize(_calendar).height, lessThan(monthHeight));
    await tester.drag(_calendar, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(formatOf(tester), CalendarFormat.week); // the smallest stays

    // Weeks start on Monday (the default): next week starts on the 16th.
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expectAtTop(tester, LocalDate(2026, 11, 16));
    expect(_today, findsOneWidget);
    await tester.tap(_prev);
    await tester.pumpAndSettle();
    expectAtTop(tester, today);
    expect(_today, findsNothing);
    await tester.tap(_prev);
    await tester.pumpAndSettle();
    expectAtTop(tester, LocalDate(2026, 11, 2));

    await tester.drag(_calendar, const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(formatOf(tester), CalendarFormat.twoWeeks);
    // Two weeks from 2 Nov hold today.
    expect(_today, findsNothing);
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expectAtTop(tester, LocalDate(2026, 11, 16));
    await tester.drag(_calendar, const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(formatOf(tester), CalendarFormat.month);
  });

  testWidgets('a title too long for its space slides once, then rests cut', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = world();
    addTearDown(w.dispose);
    await tester.pumpWidget(appWith(w));
    await tester.pumpAndSettle();
    await goToTab(tester, 'Timeline');
    // The test font is wide: "November 2026" does not fit next to the menu.
    final title = find.byKey(const Key('timeline-month'));
    final marquee = find.descendant(of: title, matching: find.byKey(const Key('marquee')));
    expect(marquee, findsNothing); // played already, now resting
    final resting = tester.widget<Text>(find.descendant(of: title, matching: find.text('November 2026')));
    expect(resting.overflow, TextOverflow.ellipsis);

    // A new title plays again: a pause, then it slides.
    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(marquee, findsOneWidget);
    double shift() => tester.widget<Transform>(find.descendant(of: marquee, matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .x;
    expect(shift(), 0);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(shift(), lessThan(0));
    await tester.pumpAndSettle();
    expect(marquee, findsNothing);
  });

  testWidgets('a title that fits never moves', (tester) async {
    final w = world();
    await pumpTimeline(tester, w);
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('marquee')), findsNothing);
    await tester.pumpAndSettle();
  });
}
