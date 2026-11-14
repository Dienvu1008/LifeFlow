// P03 UX U4 (ADR-0048): the Timeline through the full app with fake ports.
// Time column and colour bar, events beside tasks, both-way scrolling with
// more windows loaded as it scrolls, the month calendar and "Today".
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/ui.dart';

import 'fake_world.dart';

SchedulePointInput at(LocalDate d, int h, [int m = 0]) => SchedulePointInput.at(d, TimeOfDayValue(h, m), testZone);

AgendaItem occurrence(String id, String title, LocalDate d, {int? hour}) => AgendaItem(
      taskId: id,
      title: title,
      originalDate: d,
      start: hour == null ? SchedulePointInput.date(d) : at(d, hour),
      isRepeating: false,
      isDone: false,
    );

FakeWorld world({List<AgendaItem> tasks = const [], List<EventItem> events = const []}) {
  final w = FakeWorld(
    tasks: {
      'A': [
        task('c', 'Call the bank', color: 3),
        task('p', 'Past thing'),
        task('d', 'December thing'),
      ],
    },
    profiles: [profile('A', 'Guest')],
    activeId: 'A',
  );
  w.calendar.range = CalendarRange(events: events, tasks: tasks, conflicts: const []);
  return w;
}

Future<void> pumpTimeline(WidgetTester tester, FakeWorld w, {double height = 900}) async {
  tester.view.physicalSize = Size(1000, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Timeline'));
  await tester.pumpAndSettle();
}

void main() {
  final today = testToday;

  testWidgets('a time column, the colour bar, events beside tasks', (tester) async {
    final w = world(
      tasks: [occurrence('c', 'Call the bank', today, hour: 9)],
      events: [
        EventItem(
            eventId: 'e1',
            title: 'Standup',
            originalDate: today,
            start: at(today, 10),
            end: at(today, 10, 15),
            location: 'Room 2',
            isRepeating: false),
      ],
    );
    await pumpTimeline(tester, w);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('– 10:15 · Room 2'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Call the bank')).dy, lessThan(tester.getTopLeft(find.text('Standup')).dy));
    // The task's colour on the left of its row (palette index 3).
    final ctx = tester.element(find.text('Call the bank'));
    final bar = tester.widgetList<Container>(find.byType(Container)).where((c) => c.color == itemColorOf(ctx, 3));
    expect(bar, isNotEmpty);
    // Ticking works as in the agenda.
    await tester.tap(find.bySemanticsLabel('Complete Call the bank'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'complete:c:false');
  });

  testWidgets('the list scrolls both ways: earlier days above, more windows below as it scrolls', (tester) async {
    final w = world(tasks: [
      occurrence('p', 'Long ago', today.addDays(-30)), // two windows back
      occurrence('p', 'Past thing', today.addDays(-3)),
      occurrence('c', 'Call the bank', today, hour: 9),
    ]);
    await pumpTimeline(tester, w);
    // Today is at the top; the past is above it, out of sight.
    expect(find.text('Past thing'), findsNothing);
    final first = w.calendar.ranges.length;
    expect(first, 3); // a window before the anchor, two after it
    expect(w.calendar.ranges.any((r) => r.startsWith('${today.addDays(-42)}')), isFalse);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(w.calendar.ranges.length, greaterThan(first));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 6000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Past thing'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Past thing')).dy, lessThan(tester.getTopLeft(find.text('Call the bank')).dy));
    // Further back, another window is loaded.
    await tester.scrollUntilVisible(find.text('Long ago'), -400, scrollable: find.byType(Scrollable).last, maxScrolls: 80);
    expect(find.text('Long ago'), findsOneWidget);
  });

  testWidgets('the month and year open a month calendar; a day jumps there; Today comes back', (tester) async {
    final w = world(tasks: [occurrence('c', 'Call the bank', today, hour: 9)]);
    await pumpTimeline(tester, w);
    expect(find.text('November 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-calendar')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('timeline-calendar')), matching: find.text('20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-calendar')), findsNothing);
    final day = find.byKey(ValueKey('day-${today.addDays(11)}'));
    expect(day, findsOneWidget);
    expect(tester.getTopLeft(day).dy, lessThan(200));
    expect(find.text('Nothing planned.'), findsOneWidget);
    await tester.tap(find.byTooltip('Go to today'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(ValueKey('day-$today'))).dy, lessThan(200));
    expect(find.text('Call the bank'), findsOneWidget);
  });

  testWidgets('T3: one mark per item on a day, in the item\'s colour or neutral', (tester) async {
    final w = world(
      tasks: [occurrence('c', 'Call the bank', today, hour: 9), occurrence('p', 'Past thing', today)],
      events: [EventItem(eventId: 'e', title: 'Talk', originalDate: today, start: at(today, 11), isRepeating: false)],
    );
    w.overview.events.add(const OverviewEventView(id: 'e', title: 'Talk', colorIndex: 7, orderKey: ''));
    await pumpTimeline(tester, w);
    await tester.tap(find.byKey(const Key('timeline-month')));
    await tester.pumpAndSettle();
    final marks = find.byKey(const Key('day-marks'));
    expect(marks, findsOneWidget); // only today has items
    final ctx = tester.element(marks);
    final colours = [
      for (final c in tester.widgetList<Container>(find.descendant(of: marks, matching: find.byType(Container))))
        (c.decoration as BoxDecoration).color
    ];
    expect(colours, hasLength(3));
    expect(colours, containsAll([itemColorOf(ctx, 3), itemColorOf(ctx, 7), Theme.of(ctx).colorScheme.onSurfaceVariant]));
  });

  testWidgets('the title follows the day at the top', (tester) async {
    final dec = LocalDate(2026, 12, 3);
    final w = world(tasks: [
      for (var i = 0; i < 20; i++) occurrence('c', 'Item $i', today.addDays(i)),
      occurrence('d', 'December thing', dec),
      for (var i = 1; i < 12; i++) occurrence('d', 'After $i', dec.addDays(i)),
    ]);
    await pumpTimeline(tester, w, height: 600);
    expect(find.text('November 2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('December thing'), 300, scrollable: find.byType(Scrollable).last);
    // Bring December's first day to the top, under the app bar.
    final y = tester.getTopLeft(find.byKey(ValueKey('day-$dec'))).dy;
    final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    await tester.drag(find.byType(CustomScrollView), Offset(0, -(y - top) - 20));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
  });

  testWidgets('an empty profile says so under today', (tester) async {
    final w = world();
    await pumpTimeline(tester, w);
    expect(find.byKey(const Key('agenda-empty')), findsOneWidget);
    expect(find.textContaining('Nothing planned yet'), findsOneWidget);
  });
}
