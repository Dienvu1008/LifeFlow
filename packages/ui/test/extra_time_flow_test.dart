// P06c E2 (ADR-0096): extra times in the UI, with fake ports.
//   Today     an extra time is its own row ("Another time"); its box ticks the
//             extra time, not the task or an occurrence; "Skip this time" drops it
//   Calendar  an extra time of an event shows; "Skip this time" drops it;
//             two extra times of one event on a day are two rows
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'fake_world.dart';
import 'nav.dart';

FakeWorld world() => FakeWorld(tasks: {'A': []}, profiles: [profile('A', 'Guest')], activeId: 'A');
final mon = testToday; // 2026-11-09
TimeOfDayValue at(int h, [int m = 0]) => TimeOfDayValue(h, m);

AgendaItem extra(String id, String x, String title, LocalDate date, TimeOfDayValue from, TimeOfDayValue to,
        {bool done = false}) =>
    AgendaItem(
      taskId: id,
      extraId: x,
      title: title,
      originalDate: date,
      start: SchedulePointInput.at(date, from, testZone),
      end: SchedulePointInput.at(date, to, testZone),
      isRepeating: false,
      isDone: done,
    );

Future<void> pump(WidgetTester tester, FakeWorld w) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

void main() {
  group('Today', () {
    testWidgets('an extra time: its own row; the box ticks it; the menu has Skip, not the series entries', (tester) async {
      final w = world();
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15))]);
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('agenda-t1@$mon#x1')), findsOneWidget);
      expect(find.textContaining('Another time'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(w.calls, ['extra.done:x1:true']);
      await tester.tap(find.byTooltip('Actions for Study AI'));
      await tester.pumpAndSettle();
      expect(find.text('Move this time…'), findsNothing);
      expect(find.text('Edit the whole repeat…'), findsNothing);
      await tester.tap(find.text('Skip this time'));
      await tester.pumpAndSettle();
      expect(w.calls, ['extra.done:x1:true', 'extra.remove:x1']);
    });

    testWidgets('a done extra time is shown done and its box un-ticks it', (tester) async {
      final w = world();
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15), done: true)]);
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(w.calls, ['extra.done:x1:false']);
    });
  });

  group('Calendar', () {
    testWidgets('two extra times of an event on one day are two blocks; Skip drops the one asked', (tester) async {
      final w = world();
      EventItem ex(String x, int h) => EventItem(
            eventId: 'e1',
            extraId: x,
            title: 'Class',
            originalDate: mon,
            start: SchedulePointInput.at(mon, at(h), testZone),
            end: SchedulePointInput.at(mon, at(h + 1), testZone),
            isRepeating: false,
          );
      w.calendar.range = CalendarRange(events: [ex('x1', 9), ex('x2', 14)], tasks: const [], conflicts: const []);
      await pump(tester, w);
      await goToTab(tester, 'Calendar');
      await tester.tap(find.descendant(of: find.byKey(const Key('calendar-mode')), matching: find.text('Day')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chip-event:e1#x1')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-event:e1#x2')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('chip-event:e1#x2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chip-event:e1#x2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions for Class').first);
      await tester.pumpAndSettle();
      expect(find.text('Move this time…'), findsNothing);
      await tester.tap(find.text('Skip this time').last);
      await tester.pumpAndSettle();
      expect(w.calls, ['extra.remove:x2']);
    });
  });
}
