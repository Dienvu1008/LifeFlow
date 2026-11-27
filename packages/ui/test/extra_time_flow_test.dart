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

FakeWorld world([List<TaskView> tasks = const []]) =>
    FakeWorld(tasks: {'A': tasks}, profiles: [profile('A', 'Guest')], activeId: 'A');
final mon = testToday; // 2026-11-09
TimeOfDayValue at(int h, [int m = 0]) => TimeOfDayValue(h, m);

AgendaItem extra(String id, String x, String title, LocalDate date, TimeOfDayValue from, TimeOfDayValue to,
        {bool done = false, bool repeating = false, bool moved = false}) =>
    AgendaItem(
      taskId: id,
      extraId: x,
      title: title,
      originalDate: date,
      start: SchedulePointInput.at(date, from, testZone),
      end: SchedulePointInput.at(date, to, testZone),
      isRepeating: repeating,
      isDone: done,
      isMoved: moved,
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
      expect(find.byKey(ValueKey('chip-event:e1#x1@$mon')), findsOneWidget);
      expect(find.byKey(ValueKey('chip-event:e1#x2@$mon')), findsOneWidget);
      await tester.ensureVisible(find.byKey(ValueKey('chip-event:e1#x2@$mon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('chip-event:e1#x2@$mon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions for Class').first);
      await tester.pumpAndSettle();
      expect(find.text('Move this time…'), findsNothing);
      await tester.tap(find.text('Skip this time').last);
      await tester.pumpAndSettle();
      expect(w.calls, ['extra.remove:x2']);
    });
  });

  group('an extra time that repeats (ADR-0097)', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Actions for Study AI'));
      await tester.pumpAndSettle();
    }

    testWidgets('its box ticks that one time; Skip and Move are for that time; the whole is removed apart', (tester) async {
      final w = world();
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15), repeating: true)]);
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Skip this time'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Move this time…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('Edit the whole repeat…'), findsNothing, reason: 'that is the task\'s own');
      await tester.tap(find.text('Remove all of these times'));
      await tester.pumpAndSettle();
      expect(w.calls, [
        'extra.occurrenceDone:x1@$mon:true',
        'extra.change:x1@$mon:skip',
        'extra.change:x1@$mon:move>$mon',
        'extra.remove:x1',
      ]);
    });

    testWidgets('a moved time can be undone; focus on it is for the task, not for a time of the task\'s own rule', (tester) async {
      final w = world([task('t1', 'Study AI')]);
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15), repeating: true, moved: true)]);
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Undo the change to this time'));
      await tester.pumpAndSettle();
      expect(w.calls, ['extra.change:x1@$mon:undo']);
      await openMenu(tester);
      await tester.tap(find.text('Focus…').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('focus-start')));
      await tester.pumpAndSettle();
      expect(w.calls.last, 'focus.start:pomodoro:25:t1:null');
    });
    testWidgets('"Add another time…" opens the editor for the task; Save sends the time', (tester) async {
      final w = world();
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15), repeating: true)]);
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Add another time…'));
      await tester.pumpAndSettle();
      expect(find.text('Another time for Study AI'), findsOneWidget);
      await tester.tap(find.byKey(const Key('extra-save')));
      await tester.pumpAndSettle();
      expect(w.calls.single, startsWith('extra.add:task:t1:'));
      expect(find.text('Another time for Study AI'), findsNothing, reason: 'closed after saving');
    });

    testWidgets('a time that does not repeat: "Change this time…" opens it filled in', (tester) async {
      final w = world();
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15))]);
      w.extraTimes.stored['task:t1'] = [
        ExtraTimeView(
            id: 'x1',
            subject: ExtraTimeSubject.task,
            subjectId: 't1',
            start: SchedulePointInput.at(mon, at(13), testZone),
            end: SchedulePointInput.at(mon, at(15), testZone))
      ];
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await openMenu(tester);
      await tester.tap(find.text('Change this time…'));
      await tester.pumpAndSettle();
      expect(find.text('Change this time of Study AI'), findsOneWidget);
      await tester.tap(find.byKey(const Key('extra-save')));
      await tester.pumpAndSettle();
      expect(w.calls.single, startsWith('extra.change:x1:'));
    });
  });

  group('Other times', () {
    testWidgets('the task page lists them; one is removed with its cross; another is added', (tester) async {
      final w = world([task('t1', 'Study AI')]);
      w.today = Agenda([extra('t1', 'x1', 'Study AI', mon, at(13), at(15))]);
      w.extraTimes.stored['task:t1'] = [
        ExtraTimeView(
            id: 'x1',
            subject: ExtraTimeSubject.task,
            subjectId: 't1',
            start: SchedulePointInput.at(mon, at(13), testZone),
            end: SchedulePointInput.at(mon, at(15), testZone))
      ];
      await pump(tester, w);
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study AI'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('extra-times')));
      await tester.pumpAndSettle();
      expect(find.text('Other times'), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-x1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('extra-add')));
      await tester.pumpAndSettle();
      expect(find.text('Another time for Study AI'), findsOneWidget);
      await tester.tap(find.byKey(const Key('extra-save')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('extra-x1')));
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('extra-x1')), matching: find.byIcon(Icons.close)));
      await tester.pumpAndSettle();
      expect(w.calls.any((c) => c.startsWith('extra.add:task:t1:')), isTrue);
      expect(w.calls, contains('extra.remove:x1'));
    });

    testWidgets('an event that exists shows them in its editor; a new event has no such section', (tester) async {
      final w = world();
      w.calendar.events['e1'] = EventDetails(
          id: 'e1',
          isCancelled: false,
          input: EventInput(title: 'Class', start: SchedulePointInput.at(mon, at(9), testZone), end: SchedulePointInput.at(mon, at(10), testZone)));
      w.calendar.range = CalendarRange(
          events: [EventItem(eventId: 'e1', title: 'Class', originalDate: mon, start: SchedulePointInput.at(mon, at(9), testZone), isRepeating: false)],
          tasks: const [],
          conflicts: const []);
      await pump(tester, w);
      await goToTab(tester, 'Calendar');
      await tester.tap(find.descendant(of: find.byKey(const Key('calendar-mode')), matching: find.text('Day')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('chip-event:e1@$mon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Actions for Class').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit event…').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('extra-times')));
      expect(find.text('Other times'), findsOneWidget);
      expect(find.text('No other times'), findsOneWidget);
    });
  });

  group('an event\'s extra time that repeats', () {
    testWidgets('its own cancel, skip, removal and "Add another time…"', (tester) async {
      final w = world();
      w.calendar.range = CalendarRange(
          events: [
            EventItem(
                eventId: 'e1',
                extraId: 'x1',
                title: 'Class',
                originalDate: mon,
                start: SchedulePointInput.at(mon, at(14), testZone),
                end: SchedulePointInput.at(mon, at(15), testZone),
                isRepeating: true)
          ],
          tasks: const [],
          conflicts: const []);
      await pump(tester, w);
      await goToTab(tester, 'Calendar');
      await tester.tap(find.descendant(of: find.byKey(const Key('calendar-mode')), matching: find.text('Day')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('chip-event:e1#x1@$mon')));
      await tester.pumpAndSettle();
      Future<void> pick(String action) async {
        await tester.tap(find.byTooltip('Actions for Class').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(action).last);
        await tester.pumpAndSettle();
      }

      await pick('Cancel this time');
      await pick('Skip this time');
      await pick('Add another time…');
      expect(find.text('Another time for Class'), findsOneWidget);
      await tester.tap(find.byKey(const Key('extra-save')));
      await tester.pumpAndSettle();
      await pick('Remove all of these times');
      expect(w.calls.where((c) => !c.startsWith('extra.add')).toList(),
          ['extra.change:x1@$mon:cancel', 'extra.change:x1@$mon:skip', 'extra.remove:x1']);
      expect(w.calls.where((c) => c.startsWith('extra.add:event:e1:')), hasLength(1));
      expect(w.calls.any((c) => c.startsWith('event.change')), isFalse, reason: 'never the event\'s own series');
    });
  });
}