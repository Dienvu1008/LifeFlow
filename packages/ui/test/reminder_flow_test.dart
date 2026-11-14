// P02 T7 (ADR-0034): reminders in the editors and in Settings, with fakes.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/src/schedule_text.dart';

import 'fake_world.dart';

FakeWorld world(List<TaskView> tasks) =>
    FakeWorld(tasks: {'A': tasks}, profiles: [profile('A', 'Guest')], activeId: 'A');

Future<void> pumpApp(WidgetTester tester, FakeWorld w) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> openEditor(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Actions for $title'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Schedule…').last);
  await tester.pumpAndSettle();
}

Future<void> addReminder(WidgetTester tester, String label) async {
  await tapKey(tester, 'reminder-add');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) => tapKey(tester, 'schedule-save');

final tue = LocalDate(2026, 11, 10);
TaskScheduleInput timed() => TaskScheduleInput(start: SchedulePointInput.at(tue, TimeOfDayValue(9, 0), testZone));

void main() {
  group('task editor', () {
    testWidgets('a preset is saved after the schedule; the first one asks for permission', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      w.reminders.deviceStatus = const ReminderStatus(supported: true, allowed: false);
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await addReminder(tester, '10 minutes before');
      expect(w.calls, ['notify:ask']);
      expect(find.text('10 minutes before'), findsOneWidget);
      expect(find.byKey(const Key('reminder-note')), findsNothing); // granted
      await save(tester);
      expect(w.calls.sublist(1), [
        'setSchedule:a:start=2026-11-10T09:00[$testZone];end=-;due=-;repeat=-',
        'reminders:task:a:10m',
      ]);
    });

    testWidgets('turned off in the system: the editor says so and does not ask', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      w.reminders.deviceStatus = const ReminderStatus(supported: true, allowed: false, canAsk: false);
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await addReminder(tester, 'At the start');
      expect(w.calls.where((c) => c == 'notify:ask'), isEmpty);
      expect(find.textContaining("system's notification settings"), findsOneWidget);
    });

    testWidgets('permission refused: the editor says reminders will not show', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      w.reminders
        ..deviceStatus = const ReminderStatus(supported: true, allowed: false)
        ..grant = false;
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await addReminder(tester, 'At the start');
      expect(find.byKey(const Key('reminder-note')), findsOneWidget);
      expect(find.textContaining('Settings → Reminders'), findsOneWidget);
    });

    testWidgets('stored reminders are shown and can be removed; unchanged ones are not re-saved', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      w.reminders.stored['task:a'] = [const RemindMinutesBefore(60), const RemindMinutesBefore(1440)];
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      expect(find.text('1 hour before'), findsOneWidget);
      expect(find.text('1 day before'), findsOneWidget);
      await save(tester);
      expect(w.calls.where((c) => c.startsWith('reminders:')), isEmpty);

      await openEditor(tester, 'Call');
      await tester.tap(find.descendant(of: find.byKey(const Key('reminder-0')), matching: find.byTooltip('Remove this reminder')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(w.calls.last, 'reminders:task:a:1440m');
    });

    testWidgets('all-day items remind relative to 09:00', (tester) async {
      final w = world([task('a', 'Rent', schedule: TaskScheduleInput(deadline: SchedulePointInput.date(tue)))]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Rent');
      await tapKey(tester, 'reminder-add');
      expect(find.text('On the day, 09:00'), findsOneWidget);
      expect(find.text('1 week before, 09:00'), findsOneWidget);
      expect(find.text('10 minutes before'), findsNothing);
      await tester.tap(find.text('1 day before, 09:00'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(w.calls.last, 'reminders:task:a:1440m');
    });

    testWidgets('a custom time before; out of range is refused', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await addReminder(tester, 'Custom…');
      await tester.enterText(find.byKey(const Key('offset-number')), '5');
      await tester.tap(find.byKey(const Key('offset-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('weeks').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('From 1 minute to 4 weeks.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('offset-number')), '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('2 weeks before'), findsOneWidget);
      await save(tester);
      expect(w.calls.last, 'reminders:task:a:20160m');
    });

    testWidgets('without a date only a date-and-time reminder; no schedule is written', (tester) async {
      final w = world([task('a', 'Think')]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Think');
      expect(find.text('Set a date to be reminded before it.'), findsOneWidget);
      await tapKey(tester, 'reminder-add');
      expect(find.text('Custom…'), findsNothing);
      await tester.tap(find.text('At a date and time…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // today (9 Nov)
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // 09:00
      await tester.pumpAndSettle();
      expect(find.text('Today at 09:00'), findsOneWidget);
      await save(tester);
      final at = DateTime(2026, 11, 9, 9).toUtc().toIso8601String();
      expect(w.calls, ['reminders:task:a:at:$at']);
    });

    testWidgets('removing the schedule keeps only reminders at a date and time', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      final at = Instant(DateTime.utc(2026, 11, 12, 2));
      w.reminders.stored['task:a'] = [const RemindMinutesBefore(10), RemindAtInstant(at)];
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await tapKey(tester, 'schedule-remove');
      expect(w.calls, ['setSchedule:a:none', 'reminders:task:a:at:${at.utc.toIso8601String()}']);
    });

    testWidgets('at most five', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      w.reminders.stored['task:a'] = [for (final m in [0, 5, 10, 15]) RemindMinutesBefore(m)];
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await addReminder(tester, '30 minutes before');
      expect(find.byKey(const Key('reminder-add')), findsNothing);
    });

    testWidgets('a refused reminder list is shown and the editor stays open', (tester) async {
      final w = world([task('a', 'Call', schedule: timed())]);
      await pumpApp(tester, w);
      await openEditor(tester, 'Call');
      await addReminder(tester, '5 minutes before');
      w.reminders.failNext = const CommandFailure(CommandFailureKind.validationFailed, reason: 'at most 5 reminders');
      await save(tester);
      expect(find.text('At most 5 reminders.'), findsOneWidget);
      expect(find.byKey(const Key('schedule-save')), findsOneWidget);
    });
  });

  testWidgets('event editor: a new event with a reminder (second command, on the new id)', (tester) async {
    final w = world([]);
    await pumpApp(tester, w);
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await tester.pumpAndSettle();
    await newEventFromSlot(tester);
    await tester.enterText(find.byKey(const Key('event-title')), 'Standup');
    await addReminder(tester, '15 minutes before');
    await tapKey(tester, 'event-save');
    expect(w.calls.last, 'reminders:event:ev0:15m');
    expect(w.calls[w.calls.length - 2], startsWith('event.create:Standup|'));
  });

  group('Settings → Reminders', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('reminder-info')));
      await tester.pumpAndSettle();
    }

    testWidgets('off: allow; late on Android: allow exact', (tester) async {
      final w = world([]);
      w.reminders.deviceStatus = const ReminderStatus(supported: true, allowed: false, exactAllowed: false);
      await pumpApp(tester, w);
      await openSettings(tester);
      expect(find.text('Notifications are off for LifeFlow'), findsOneWidget);
      await tapKey(tester, 'reminders-allow');
      expect(w.calls.last, 'notify:ask');
      expect(find.text('Reminders are on'), findsOneWidget);
      await tapKey(tester, 'reminders-exact');
      expect(w.calls.last, 'notify:exact');
      expect(find.byKey(const Key('reminders-exact')), findsNothing);
      expect(find.textContaining('next 14 days'), findsOneWidget);
      expect(find.textContaining('remind at 09:00'), findsOneWidget);
    });

    testWidgets('About: the open-source licenses page opens (ADR-0035)', (tester) async {
      final w = world([]);
      await pumpApp(tester, w);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      // The list is long: built as it scrolls.
      await tester.scrollUntilVisible(find.byKey(const Key('open-source-licenses')), 300,
          scrollable: find.byType(Scrollable).last);
      await tapKey(tester, 'open-source-licenses');
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('turned off in the system settings: no Allow button, says where to turn it on', (tester) async {
      final w = world([]);
      w.reminders.deviceStatus = const ReminderStatus(supported: true, allowed: false, canAsk: false);
      await pumpApp(tester, w);
      await openSettings(tester);
      expect(find.byKey(const Key('reminders-off-in-system')), findsOneWidget);
      expect(find.byKey(const Key('reminders-allow')), findsNothing);
    });

    testWidgets('a device without notifications says so', (tester) async {
      final w = world([]);
      w.reminders.deviceStatus = const ReminderStatus(supported: false, allowed: false);
      await pumpApp(tester, w);
      await openSettings(tester);
      expect(find.text('This device does not show reminders.'), findsOneWidget);
    });
  });

  test('reminder texts', () {
    final today = LocalDate(2026, 11, 9);
    expect(describeOffset(5), '5 minutes');
    expect(describeOffset(90), '1 hour 30 minutes');
    expect(describeOffset(1440 + 180), '1 day 3 hours');
    expect(describeOffset(14 * 1440), '2 weeks');
    String r(int m, {bool allDay = false, String anchor = 'start'}) =>
        describeReminder(RemindMinutesBefore(m), anchor: anchor, allDay: allDay, today: today);
    expect(r(0), 'At the start');
    expect(r(0, anchor: 'deadline'), 'At the deadline');
    expect(r(0, allDay: true), 'On the day, 09:00');
    expect(r(2880, allDay: true), '2 days before, 09:00');
    expect(r(60, allDay: true), '1 hour before 09:00');
  });
}
