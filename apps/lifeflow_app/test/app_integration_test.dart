// Composition-root integration: real per-profile stores (SR-03), registry,
// gateway and authorization policy behind the real UI. Headless.
//   ADR-0008          first launch = one guest profile, no account
//   ADR-0022 / GS-19  encrypted on Android AND Windows -> no banner
//   ADR-0021 fallback plain Windows only with the flag -> tracked banner
//   SR-03 / ID-002    switching profile in the UI swaps the store; data of
//                     one profile never shows in another
//   ADR-0011          a task added in the UI is committed with its audit row
//   LF-INV-SEC-002    opening and reading never call the identity provider
import 'dart:io';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:lifeflow_app/bootstrap.dart';
import 'package:lifeflow_app/root.dart';

/// Drift does real async I/O, which the widget tester's fake clock never
/// advances. Give real time to the stores, then pump the UI.
Future<void> settle(WidgetTester tester, [int rounds = 6]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Records every call so tests can prove startup and reads never touch the
/// identity provider (LF-INV-SEC-002).
class RecordingAuth implements AuthGateway {
  final calls = <String>[];
  @override
  bool get isConfigured => true;
  @override
  Stream<void> get sessionRevoked => const Stream.empty();
  @override
  Future<AuthSession> signIn(SignInRequest request) async {
    calls.add('signIn');
    throw const AuthFailure(AuthFailureKind.network, 'offline');
  }

  @override
  Future<AuthSession?> currentSession() async {
    calls.add('currentSession');
    return null;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');
}

/// A provider that always signs the same GitHub account in.
class OkAuth implements AuthGateway {
  @override
  bool get isConfigured => true;
  @override
  Stream<void> get sessionRevoked => const Stream.empty();
  @override
  Future<AuthSession> signIn(SignInRequest request) async => AuthSession(
      accountId: 'acc-gh', provider: 'github', issuedAt: Instant.now());
  @override
  Future<AuthSession?> currentSession() async => null;
  @override
  Future<void> signOut() async {}
}

/// File dialogs backed by memory: what the user "saves" can be "picked" again.
class MemoryFiles implements FileGateway {
  String? saved;
  String? savedName;

  /// What the next open dialog returns; defaults to the last saved file.
  String? pickOverride;

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    savedName = suggestedName;
    saved = text;
    return true;
  }

  @override
  Future<String?> pickText() async => pickOverride ?? saved;
}

class MemoryKeys {
  final values = <String, String>{};
  DatabaseKeyStore call(String name) => _Slot(this, name);
}

class _Slot implements DatabaseKeyStore {
  _Slot(this.keys, this.name);
  final MemoryKeys keys;
  final String name;
  @override
  Future<String?> read() async => keys.values[name];
  @override
  Future<void> write(String key) async => keys.values[name] = key;
  @override
  Future<void> delete() async => keys.values.remove(name);
}

/// The device's notifications, recorded: every plan the app hands over.
class RecordingReminders implements ReminderScheduler {
  final plans = <List<PlannedReminder>>[];
  List<PlannedReminder> get pending => plans.isEmpty ? const [] : plans.last;
  @override
  Future<void> sync(List<PlannedReminder> planned) async => plans.add(planned);
  @override
  Future<ReminderStatus> status() async => const ReminderStatus(supported: true, allowed: true);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> requestExact() async {}
}

/// A temp app-support directory with a directory opened on it.
class World {
  late Directory base;
  late ProfileDirectory directory;
  final keys = MemoryKeys();
  final auth = RecordingAuth();
  final warnings = <String>[];
  final files = MemoryFiles();
  final device = RecordingReminders();

  Future<void> open(StoragePlatform platform, {bool fallback = false}) async {
    base = await Directory.systemTemp.createTemp('lifeflow_app_');
    directory = await ProfileDirectory.open(
      baseDir: base,
      policy: atRestPolicyFor(platform, windowsPlainFallback: fallback),
      keysFor: keys.call,
      background: false,
    );
  }

  Widget root(StoragePlatform platform, {bool fallback = false, String? initial}) =>
      LifeFlowRoot(
        initialProfileId: initial ?? 'unset',
        openSession: (id, host, route) => openSession(
          directory: directory,
          profileId: id,
          platform: platform,
          auth: auth,
          host: host,
          initialRoute: route, files: files,
          windowsPlainFallback: fallback,
          reminders: device,
          onWarning: warnings.add,
        ),
      );

  Future<void> dispose() async {
    await directory.close();
    await base.delete(recursive: true);
  }
}

Future<World> pumpApp(WidgetTester tester, StoragePlatform platform,
    {bool fallback = false, double width = 1000}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = World();
  await tester.runAsync(() => w.open(platform, fallback: fallback));
  final active = await tester.runAsync(() => w.directory.active());
  await tester.pumpWidget(w.root(platform, fallback: fallback, initial: active!.id));
  await settle(tester);
  return w;
}

/// Unmount INSIDE the test body: the binding checks for pending timers before
/// tear-downs run, and Drift schedules a zero-length timer when the task
/// stream is cancelled.
Future<void> finish(WidgetTester tester, World w) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await settle(tester, 2);
  await tester.runAsync(w.dispose);
}

void main() {
  for (final platform in [StoragePlatform.android, StoragePlatform.windows]) {
    testWidgets('${platform.name}: encrypted profile store, no banner (GS-19)',
        (tester) async {
      final w = await pumpApp(tester, platform);
      final id = (await tester.runAsync(() => w.directory.active()))!.id;

      expect(isPlainSqliteFile(w.directory.profileFile(id)), isFalse);
      expect(w.warnings, isEmpty);
      expect(find.byKey(const Key('storage-banner')), findsNothing);
      expect(find.textContaining('No tasks yet'), findsOneWidget);

      // Opening Profiles made no auth call either (SEC-002).
      await tester.tap(find.byIcon(Icons.people_outline));
      await settle(tester);
      expect(find.byKey(const Key('account-card')), findsOneWidget);
      expect(w.auth.calls, isEmpty);
      await finish(tester, w);
    });
  }

  testWidgets('Windows plain fallback build shows the tracked exception',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.windows, fallback: true);
    expect(w.warnings, hasLength(1));
    expect(find.byKey(const Key('storage-banner')), findsOneWidget);
    await finish(tester, w);
  });

  testWidgets('a task added in the UI lands in the profile store with audit',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write the report');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);
    expect(find.text('Write the report'), findsOneWidget);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      // A second connection to the same file, for inspection only.
      final s = await w.directory.openProfile(id);
      final tasks = await s.db.select(s.db.tasks).get();
      final audit = await s.db.select(s.db.auditLog).get();
      await s.db.close();
      return (tasks: tasks, audit: audit);
    });
    expect(rows!.tasks.single.title, 'Write the report');
    expect(rows.audit.where((a) => a.action == 'CreateTask'), hasLength(1));
    await finish(tester, w);
  });

  testWidgets('P03 UX U3: a list, a task in it and a move land in the store with audit (ADR-0047)',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    Future<void> add(String title) async {
      await tester.enterText(find.byType(TextField), title);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      await settle(tester);
    }

    // A list from the + menu.
    await tester.tap(find.byKey(const Key('add-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New list'));
    await tester.pumpAndSettle();
    await add('Work');
    // A task in it from the list's menu, and a loose task.
    await tester.tap(find.byTooltip('Actions for Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add task').last);
    await tester.pumpAndSettle();
    await add('Report');
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await add('Call mum');
    // The loose task into the list, from its menu.
    await tester.tap(find.byTooltip('Actions for Call mum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to list…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pump();
    await settle(tester);
    expect(tester.getTopLeft(find.text('Call mum')).dx, tester.getTopLeft(find.text('Report')).dx);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final lists = await s.db.select(s.db.taskLists).get();
      final tasks = await s.db.select(s.db.tasks).get();
      final audit = await s.db.select(s.db.auditLog).get();
      await s.db.close();
      return (lists: lists, tasks: tasks, audit: audit);
    });
    final list = rows!.lists.single;
    expect(list.title, 'Work');
    final byTitle = {for (final t in rows.tasks) t.title: t};
    expect(byTitle['Report']!.taskListId, list.id);
    expect(byTitle['Call mum']!.taskListId, list.id);
    expect(byTitle['Report']!.orderKey.compareTo(byTitle['Call mum']!.orderKey) < 0, isTrue);
    expect([for (final a in rows.audit) a.action], containsAll(['CreateList', 'CreateTask', 'MoveTask']));
    await finish(tester, w);
  });

  testWidgets('P02 T6a: a schedule set in the UI is stored and shows in Today',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Water the plants');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    // Not planned yet: Today is empty.
    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.byKey(const Key('agenda-empty')), findsOneWidget);
    await tester.tap(find.text('Overview'));
    await settle(tester);

    await tester.tap(find.byTooltip('Actions for Water the plants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule…'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('start-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // today, in the device zone
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repeat-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle(); // the editor's closing transition
    expect(find.text('Start Today · Every day'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.text('Water the plants'), findsOneWidget);
    expect(find.text('Repeats'), findsOneWidget);

    // D5: ticking marks only today's occurrence; the task stays open.
    await tester.tap(find.bySemanticsLabel('Complete Water the plants'));
    await tester.pump();
    await settle(tester);
    expect(find.bySemanticsLabel('Mark as not done: Water the plants'), findsOneWidget);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final tasks = await s.db.select(s.db.tasks).get();
      final schedules = await s.db.select(s.db.schedules).get();
      final done = await s.db.select(s.db.occurrenceCompletions).get();
      final audit = await s.db.select(s.db.auditLog).get();
      await s.db.close();
      return (tasks: tasks, schedules: schedules, done: done, audit: audit);
    });
    expect(rows!.tasks.single.status, isNot('done'));
    expect(rows.schedules.single.frequency, 'daily');
    expect(rows.done, hasLength(1));
    expect(rows.audit.map((a) => a.action), containsAll(['SetTaskSchedule', 'CompleteOccurrence']));
    await finish(tester, w);
  });

  testWidgets('P03 T6a: a habit with a target made in the UI is stored; measurements and automatic completion',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    // Added in the Habits filter: a daily habit (D6a).
    await tester.tap(find.text('Habits'));
    await settle(tester);
    expect(find.byKey(const Key('habits-empty')), findsOneWidget);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Walk');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester, 10);
    expect(find.byKey(const Key('habit-list')), findsOneWidget);

    // The habit page: a target and automatic completion.
    await tester.tap(find.text('Walk'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('target-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-min')), '6000');
    await tester.tap(find.byKey(const ValueKey('unit-steps')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('target-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('At least 6000 steps'), findsOneWidget);
    await tester.tap(find.text('From measurements'));
    await tester.pump();
    await settle(tester);

    for (final v in ['4000', '2500']) {
      await tester.tap(find.byKey(const Key('measure-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('measure-value')), v);
      await tester.tap(find.byKey(const Key('measure-save')));
      await tester.pump();
      await settle(tester);
      await tester.pumpAndSettle();
    }
    expect(find.text('6500 / 6000 steps · Achieved'), findsOneWidget);
    expect(find.text('Done automatically'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Today: the box shows the derived state and cannot be ticked (D8).
    await tester.tap(find.text('Today'));
    await settle(tester);
    expect(find.bySemanticsLabel('Done from measurements: Walk'), findsOneWidget);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final tasks = await s.db.select(s.db.tasks).get();
      final m = await s.db.select(s.db.measurements).get();
      final audit = await s.db.select(s.db.auditLog).get();
      await s.db.close();
      return (tasks: tasks, m: m, audit: audit);
    });
    final t = rows!.tasks.single;
    expect((t.isHabit, t.targetType, t.targetMin, t.unit, t.completionPolicy),
        (true, 'atLeast', 6000.0, 'steps', 'automatic'));
    expect(t.status, isNot('done'), reason: 'never set by the data (LF-INV-TASK-010)');
    expect(rows.m.map((m) => (m.value, m.source)).toSet(), {(4000.0, 'manual'), (2500.0, 'manual')});
    expect(rows.audit.map((a) => a.action),
        containsAll(['SetTaskHabit', 'SetTaskSchedule', 'SetTaskTarget', 'SetTaskCompletion', 'RecordMeasurement']));
    await finish(tester, w);
  });

  testWidgets('P03 T6b: a focus session started in the UI shows in the bar and is saved as one record',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write the report');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byTooltip('Actions for Write the report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Focus…').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-start'))); // pomodoro, 25 minutes
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Write the report'), findsWidgets);
    // The real clock runs: 25:00 or a second or two less.
    final shown = tester.widget<Text>(find.byKey(const Key('focus-time'))).data!;
    expect(shown, matches(RegExp(r'^2[45]:\d\d$')));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-bar')), findsOneWidget);
    // The device gets the pomodoro end (D4).
    await settle(tester, 8);
    expect(w.device.pending.where((p) => p.key.startsWith('focus:')), hasLength(1));

    await tester.tap(find.byTooltip('End focus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-end-save')));
    await tester.pump();
    await settle(tester);
    expect(find.byKey(const Key('focus-bar')), findsNothing);
    await settle(tester, 8);
    expect(w.device.pending.where((p) => p.key.startsWith('focus:')), isEmpty);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final sessions = await s.db.select(s.db.focusSessions).get();
      final records = await s.db.select(s.db.executionRecords).get();
      final tasks = await s.db.select(s.db.tasks).get();
      await s.db.close();
      return (sessions: sessions, records: records, tasks: tasks);
    });
    expect(rows!.sessions.single.state, 'ended');
    expect(rows.records.single.taskId, rows.tasks.single.id);
    expect(rows.tasks.single.status, isNot('done'), reason: 'a session never completes its task (D5)');
    await finish(tester, w);
  });

  testWidgets('P03 T6c: a goal made in the Goals tab links a task; progress is derived; the trash keeps the task',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Buy shoes');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    await tester.tap(find.text('Goals'));
    await settle(tester);
    await tester.tap(find.byTooltip('New goal or project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-title')), 'Get fit');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-page')), findsOneWidget);
    expect(find.text('No progress yet'), findsOneWidget);

    await tester.tap(find.byKey(const Key('link-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy shoes').last);
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('0% · from linked tasks and habits'), findsOneWidget);

    // A milestone wins over the links; ticked by hand.
    await tester.tap(find.byKey(const Key('milestone-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('milestone-title')), 'Run 5 km');
    await tester.tap(find.byKey(const Key('milestone-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run 5 km'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('100% · 1 of 1 milestones'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions for Get fit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to trash').last);
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final goals = await s.db.select(s.db.goals).get();
      final links = await s.db.select(s.db.goalLinks).get();
      final milestones = await s.db.select(s.db.milestones).get();
      final tasks = await s.db.select(s.db.tasks).get();
      await s.db.close();
      return (goals: goals, links: links, milestones: milestones, tasks: tasks);
    });
    expect(rows!.goals.single.deletedAt, isNotNull);
    expect(rows.links.single.deletedAt, isNull, reason: 'kept with the goal for a restore');
    expect(rows.milestones.single.isCompleted, isTrue);
    final t = rows.tasks.single;
    expect((t.title, t.deletedAt, t.status), ('Buy shoes', null, 'inbox'), reason: 'LF-INV-GOAL-001/002');
    await finish(tester, w);
  });

  testWidgets('P02 T6b: an event made in the Calendar tab is stored, shown, and overlaps a task',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android, width: 1200);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Gym');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await settle(tester);
    expect(find.byKey(const Key('calendar-month')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('calendar-mode')), matching: find.text('Day')));
    await settle(tester);
    expect(find.byKey(const Key('calendar-empty')), findsOneWidget);

    // New event: the default is today 09:00–10:00 in the device zone.
    await tester.tap(find.byTooltip('New event'));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Standup');
    await tester.tap(find.byKey(const Key('event-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('09:00–10:00'), findsOneWidget);

    // Plan the task today 09:00–10:30 through its schedule editor.
    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await settle(tester);
    await tester.tap(find.byTooltip('Actions for Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule…'));
    await settle(tester);
    await tester.pumpAndSettle();
    for (final key in ['start-date', 'start-time', 'end-date']) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // today; 09:00
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('end-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined)); // type the time
    await tester.pumpAndSettle();
    final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '10');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Today 09:00–10:30'), findsOneWidget);

    // Back in the calendar day: both rows show the overlap (D7).
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await settle(tester);
    expect(find.text('Overlaps Gym'), findsOneWidget);
    expect(find.text('Overlaps Standup'), findsOneWidget);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final events = await s.db.select(s.db.events).get();
      final schedules = await s.db.select(s.db.schedules).get();
      final tasks = await s.db.select(s.db.tasks).get();
      await s.db.close();
      return (events: events, schedules: schedules, tasks: tasks);
    });
    expect(rows!.events.single.title, 'Standup');
    expect(rows.schedules.map((s) => s.subjectType).toSet(), {'event', 'task'});
    // D6: the event is not a task, and has its own id.
    expect(rows.tasks.map((t) => t.id), isNot(contains(rows.events.single.id)));
    await finish(tester, w);
  });

  testWidgets('P02 T7: a reminder set in the UI reaches the device; a profile switch replaces it',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    expect(w.device.plans, isNotEmpty); // synced on open
    expect(w.device.pending, isEmpty);

    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pay the bill');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    // Tomorrow, all day, reminded on the day at 09:00 (device zone: UTC here).
    await tester.tap(find.byTooltip('Actions for Pay the bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schedule…'));
    await settle(tester);
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
    await tester.tap(find.byKey(const Key('due-date')));
    await tester.pumpAndSettle();
    // Pick tomorrow in the open month (or the next one at a month end).
    if (tomorrow.day == 1) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${tomorrow.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reminder-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On the day, 09:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('schedule-save')));
    await tester.pump();
    await settle(tester, 14); // debounce of the sync
    await tester.pumpAndSettle();

    final p = w.device.pending.single;
    expect(p.title, 'Pay the bill');
    expect(p.at.utc, DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day, 9));
    expect(p.body, startsWith('Due '));

    // Switch to another (empty) profile: its plan replaces the pending set.
    await tester.runAsync(() => w.directory.createProfile(displayName: 'Work'));
    await tester.tap(find.byIcon(Icons.people_outline));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
    await settle(tester, 10);
    expect(w.device.pending, isEmpty);
    final n = w.device.plans.length;
    await settle(tester, 14); // the old profile never schedules again
    expect(w.device.plans, hasLength(n));
    expect(w.device.pending, isEmpty);
    await finish(tester, w);
  });

  testWidgets('switching profile in the UI swaps the store (SR-03, ID-002)',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    final a = (await tester.runAsync(() => w.directory.active()))!.id;

    // A has a task.
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A-task');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);
    expect(find.text('A-task'), findsOneWidget);

    // A second profile exists on the device.
    final b = (await tester.runAsync(
        () => w.directory.createProfile(displayName: 'Work')))!;

    await tester.tap(find.byIcon(Icons.people_outline));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
    await settle(tester, 10);

    final root = tester.state<LifeFlowRootState>(find.byType(LifeFlowRoot));
    expect(root.activeProfileId, b.id);
    expect((await tester.runAsync(() => w.directory.active()))!.id, b.id);
    // The rebuilt scope shows B's (empty) store, never A's task.
    expect(find.text('A-task'), findsNothing);
    expect(find.textContaining('No tasks yet'), findsOneWidget);

    // And back to A.
    await tester.tap(find.byIcon(Icons.people_outline));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
    await settle(tester, 10);
    expect(root.activeProfileId, a);
    expect(find.text('A-task'), findsOneWidget);
    await finish(tester, w);
  });

  testWidgets('a missing profile file shows the store error, data untouched',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = World();
    await tester.runAsync(() => w.open(StoragePlatform.android));
    final b = (await tester.runAsync(() => w.directory.createProfile()))!;
    w.directory.profileFile(b.id).deleteSync();

    await tester.pumpWidget(w.root(StoragePlatform.android, initial: b.id));
    await settle(tester);
    expect(find.text('LifeFlow cannot open your data'), findsOneWidget);
    expect(find.textContaining('missing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(w.dispose);
  });

  testWidgets('sign out locks; signing in again returns to the data (ADR-0024)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = World();
    final auth = OkAuth();
    await tester.runAsync(() => w.open(StoragePlatform.android));
    final first = (await tester.runAsync(() => w.directory.active()))!.id;
    await tester.pumpWidget(LifeFlowRoot(
      initialProfileId: first,
      openSession: (id, host, route) => openSession(
        directory: w.directory, profileId: id, platform: StoragePlatform.android,
        auth: auth, host: host, initialRoute: route, files: w.files),
    ));
    await settle(tester);

    Future<void> tapAndSettle(Finder f, [int rounds = 8]) async {
      await tester.tap(f);
      await settle(tester, rounds);
    }

    // Sign in on the empty guest (binds in place), then add a task.
    await tapAndSettle(find.byIcon(Icons.people_outline));
    await tapAndSettle(find.widgetWithText(FilledButton, 'Sign in'));
    await tapAndSettle(find.text('Continue with GitHub'), 12);
    expect(find.text('Signed in with GitHub.'), findsOneWidget);
    // Let the "Signed in." snackbar expire; it sits over the add button.
    await tester.pump(const Duration(seconds: 6));
    await settle(tester, 2);
    await tapAndSettle(find.byIcon(Icons.checklist_outlined));
    await tapAddTask(tester);
        await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My account task');
    await tapAndSettle(find.widgetWithText(FilledButton, 'Add'));
    expect(find.text('My account task'), findsOneWidget);

    // Sign out: lands on Profiles of a guest; the account profile is locked.
    await tapAndSettle(find.byIcon(Icons.people_outline));
    await tapAndSettle(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tapAndSettle(find.widgetWithText(FilledButton, 'Sign out'), 14);
    final root = tester.state<LifeFlowRootState>(find.byType(LifeFlowRoot));
    expect(root.activeProfileId, isNot(first));
    expect(find.byKey(const Key('account-card')), findsOneWidget); // on Profiles
    expect(find.textContaining('Using LifeFlow as a guest'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in to open'), findsOneWidget);
    final locked = await tester.runAsync(() => w.directory.list());
    expect(locked!.firstWhere((e) => e.id == first).isLocked, isTrue);

    // Sign in again with the same account: back to the same profile + data.
    await tapAndSettle(find.widgetWithText(FilledButton, 'Sign in to open'));
    await tapAndSettle(find.text('Continue with GitHub'), 14);
    expect(root.activeProfileId, first);
    expect(find.text('Move your data to this account?'), findsNothing);
    // The reopened session starts on Tasks: the account's data is back.
    expect(find.text('My account task'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester, 2);
    await tester.runAsync(w.dispose);
  });

  testWidgets('export then restore through the UI gives the same data (GS-20)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = await pumpApp(tester, StoragePlatform.android);

    Future<void> tapAndSettle(Finder f, [int rounds = 8]) async {
      await tester.tap(f);
      await settle(tester, rounds);
    }

    // Two tasks and a subtask in the active profile.
    Future<void> add(String title, {String? under}) async {
      if (under == null) {
        await tapAddTask(tester);
        await tester.pumpAndSettle();
      } else {
        await tapAndSettle(find.byTooltip('Actions for $under'));
        await tapAndSettle(find.text('Add subtask'));
      }
      await tester.enterText(find.byType(TextField), title);
      await tapAndSettle(find.widgetWithText(FilledButton, 'Add'));
    }

    await add('Learn English');
    await add('Chapter 1', under: 'Learn English');
    await add('Pay rent');
    expect(find.text('Chapter 1'), findsOneWidget);
    final original = (await tester.runAsync(() => w.directory.active()))!.id;

    // Export from the Profiles screen.
    await tapAndSettle(find.byIcon(Icons.people_outline));
    await tapAndSettle(find.text('Export this profile'));
    expect(find.textContaining('UNENCRYPTED'), findsOneWidget);
    await tapAndSettle(find.widgetWithText(FilledButton, 'Export'));
    expect(w.files.saved, isNotNull);
    expect(w.files.savedName, endsWith('.lifeflow.json'));
    expect(find.text('Exported 3 tasks.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // let the snackbar go

    // Restore the same file into the same profile: nothing differs.
    await tapAndSettle(find.text('Restore from a file'));
    expect(find.text('Nothing to restore'), findsOneWidget);
    await tapAndSettle(find.widgetWithText(FilledButton, 'OK'));

    // The device drifts: one more task. Restoring now shows the difference.
    await tapAndSettle(find.byIcon(Icons.checklist_outlined));
    await add('Device only');
    expect(find.text('Device only'), findsOneWidget);
    await tapAndSettle(find.byIcon(Icons.people_outline));
    await tapAndSettle(find.text('Restore from a file'));
    expect(find.byKey(const Key('restore-choice')), findsOneWidget);
    expect(find.text('Only on this device: 1'), findsOneWidget);

    // Overwrite: the profile becomes the file; the extra task goes to trash.
    await tapAndSettle(find.byKey(const Key('mode-overwrite')));
    await tapAndSettle(find.byKey(const Key('restore-go')), 12);
    expect(find.textContaining('Moved 1 item to the trash.'), findsOneWidget);
    await tapAndSettle(find.widgetWithText(FilledButton, 'OK'));
    // Never a second profile for the same data (owner decision, ADR-0025).
    final profiles = (await tester.runAsync(() => w.directory.list()))!;
    expect(profiles.single.id, original);

    await tapAndSettle(find.byIcon(Icons.checklist_outlined));
    expect(find.text('Device only'), findsNothing);
    expect(find.text('Learn English'), findsOneWidget);
    expect(find.text('Chapter 1'), findsOneWidget);
    expect(find.text('Pay rent'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Chapter 1')).dx,
        greaterThan(tester.getTopLeft(find.text('Learn English')).dx));

    // Undo brings the extra task back.
    await tapAndSettle(find.byIcon(Icons.people_outline));
    await tapAndSettle(find.byKey(const Key('undo-restore')));
    await tapAndSettle(find.widgetWithText(FilledButton, 'Undo restore'), 12);
    await tester.pump(const Duration(seconds: 6));
    await settle(tester, 2);
    await tapAndSettle(find.byIcon(Icons.checklist_outlined));
    expect(find.text('Device only'), findsOneWidget);

    // Still one encrypted file for the profile (SR-03, GS-19).
    expect(isPlainSqliteFile(w.directory.profileFile(original)), isFalse);
    await finish(tester, w);
  });

  testWidgets('a backup of a profile that is not on the device is restored as '
      'a new profile with its own ids (GS-20 clean install)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = await pumpApp(tester, StoragePlatform.android);
    Future<void> tapAndSettle(Finder f, [int rounds = 8]) async {
      await tester.tap(f);
      await settle(tester, rounds);
    }

    // A file from ANOTHER install (its own folder and keys): a profile with
    // one task, exported there.
    final other = (await tester.runAsync(() async {
      final oldBase = Directory.systemTemp.createTempSync('lifeflow_oldphone_');
      final oldKeys = MemoryKeys();
      final oldDir = await ProfileDirectory.open(
          baseDir: oldBase,
          policy: AtRestPolicy.encrypt,
          keysFor: oldKeys.call,
          background: false);
      final p = (await oldDir.active())!;
      final store = await oldDir.openProfile(p.id);
      final db = store.db;
      final ws = (await db.select(db.workspaces).getSingle()).id;
      await DriftCommandGateway(db, WorkspaceOwnerAuthorization(db)).execute(
          Command(
            operationId: 'op-old-1',
            actor: ActorRef(ActorKind.owner, p.id),
            workspaceId: ws,
            type: 'CreateTask',
            payload: {'op': 'create', 'id': 'old-task-1', 'title': 'Old phone task'},
            issuedAt: Instant.now(),
          ),
          TaskCommandHandler());
      final text = await ProfileExport.build(db);
      await db.close();
      await oldDir.close();
      oldBase.deleteSync(recursive: true);
      return (id: p.id, text: text);
    }))!;
    w.files.pickOverride = other.text;

    await tapAndSettle(find.byIcon(Icons.people_outline));
    await tapAndSettle(find.text('Restore from a file'));
    expect(find.text('Restore as a new profile?'), findsOneWidget);
    await tapAndSettle(find.widgetWithText(FilledButton, 'Restore'), 12);
    expect(find.textContaining('was restored with 1 task'), findsOneWidget);
    final ids = (await tester.runAsync(() => w.directory.list()))!.map((e) => e.id);
    expect(ids, contains(other.id)); // original id kept (LF-INV-ID-001)
    await tapAndSettle(find.widgetWithText(FilledButton, 'OK'));
    await finish(tester, w);
  });

  testWidgets('deleting a profile through the UI removes its file and key '
      '(ADR-0027)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = await pumpApp(tester, StoragePlatform.android);
    final extra = (await tester.runAsync(
        () => w.directory.createProfile(displayName: 'Old copy')))!;
    expect(w.directory.profileFile(extra.id).existsSync(), isTrue);

    await tester.tap(find.byIcon(Icons.people_outline));
    await settle(tester);
    await tester.tap(find.byTooltip('Delete Old copy'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete profile'));
    await settle(tester, 10);

    expect(find.text('Old copy'), findsNothing);
    final ids = (await tester.runAsync(() => w.directory.list()))!.map((e) => e.id);
    expect(ids, isNot(contains(extra.id)));
    expect(w.directory.profileFile(extra.id).existsSync(), isFalse);
    expect(w.keys.values.containsKey(ProfileDirectory.profileKeyName(extra.id)),
        isFalse);
    await tester.pump(const Duration(seconds: 6));
    await finish(tester, w);
  });

  testWidgets('a damaged export is rejected by the UI and changes nothing',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = await pumpApp(tester, StoragePlatform.android);
    await tester.tap(find.byIcon(Icons.people_outline));
    await settle(tester);
    w.files.pickOverride = '{"format":"lifeflow-export","formatVersion":1,'
        '"schemaVersion":2,"checksumSha256":"${'0' * 64}","counts":{},"payload":{}}';
    await tester.tap(find.text('Restore from a file'));
    await settle(tester);
    expect(find.text('Cannot restore'), findsOneWidget);
    expect(find.textContaining('Nothing was changed.'), findsOneWidget);
    expect((await tester.runAsync(() => w.directory.list()))!, hasLength(1));
    await finish(tester, w);
  });

  test('storagePlatformFor maps target platforms', () {
    expect(storagePlatformFor(TargetPlatform.android), StoragePlatform.android);
    expect(storagePlatformFor(TargetPlatform.windows), StoragePlatform.windows);
    expect(storagePlatformFor(TargetPlatform.macOS), StoragePlatform.other);
  });

  focusRecoveryOnOpen();
  habitPeriodsCloseOnOpen();
}

class _NoHost implements ProfileHost {
  @override
  Future<void> activate(String profileId, {bool showProfiles = false}) async {}
}

/// P03 T3 (D1): opening a profile brings back the focus session a kill left.
void focusRecoveryOnOpen() {
  test('P03 T3: openSession recovers the running focus session (D1, LF-INV-EXEC-003)', () async {
    final w = World();
    await w.open(StoragePlatform.android);
    addTearDown(w.dispose);
    final id = (await w.directory.active())!.id;
    Future<AppWiring> open() => openSession(
        directory: w.directory, profileId: id, platform: StoragePlatform.android,
        auth: w.auth, host: _NoHost(), files: w.files);

    final first = await open();
    expect(first.focusLaunch, isA<NoActiveFocus>());
    final focus = DriftFocusService(first.db, DriftCommandGateway(first.db, WorkspaceOwnerAuthorization(first.db)));
    final started = await focus.start(mode: FocusSessionMode.stopwatch);
    expect(started, isA<CommandOk>());
    await first.db.close(); // killed: no end, no cleanup

    final again = await open();
    addTearDown(again.close);
    expect(again.focusLaunch,
        isA<FocusResumed>().having((l) => l.session.id, 'id', (started as CommandOk).entityId));
  });
}

/// P03 T4 (D9): opening a profile stores the results of periods that ended.
void habitPeriodsCloseOnOpen() {
  test('P03 T4: openSession closes the ended periods of a habit', () async {
    final w = World();
    await w.open(StoragePlatform.android);
    addTearDown(w.dispose);
    final id = (await w.directory.active())!.id;
    Future<AppWiring> open() => openSession(
        directory: w.directory, profileId: id, platform: StoragePlatform.android,
        auth: w.auth, host: _NoHost(), files: w.files);

    final first = await open();
    final db = first.db;
    final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    final task = (await DriftTaskService(db, gw).create('Warm water') as CommandOk).entityId;
    final now = DateTime.now().toUtc();
    final start = LocalDate(now.year, now.month, now.day).addDays(-3);
    final p = (await ProfileStore(db).getActiveProfile())!;
    Command cmd(String op, Map<String, Object?> payload, int v) => Command(
        operationId: op,
        actor: ActorRef(ActorKind.owner, p.profileId.value),
        workspaceId: p.activeWorkspaceId.value,
        type: op,
        payload: {'id': task, ...payload},
        expectedVersion: Version(v),
        issuedAt: Instant.now());
    expect(
        await DriftTaskScheduling(db, gw).setSchedule(task,
            TaskScheduleInput(start: SchedulePointInput.date(start), repeat: const RepeatInput(frequency: RepeatFrequency.daily))),
        isA<CommandOk>());
    expect(await gw.execute(cmd('SetTaskHabit', {'op': 'setHabit', 'isHabit': true, 'today': '$start'}, 2), TaskCommandHandler()),
        isA<CommandOk>());
    await first.db.close();

    final again = await open();
    addTearDown(again.close);
    final results = await again.db.select(again.db.periodResults).get();
    expect(results.map((r) => r.outcome).toSet(), {'missed'});
    expect(results, hasLength(greaterThanOrEqualTo(2)), reason: 'the days before today (device zone)');
  });
}

/// Taps "Add task": in the Overview it is in the + menu (P03 UX U3).
Future<void> tapAddTask(WidgetTester tester) async {
  final menu = find.byKey(const Key('add-menu'));
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byTooltip('Add task').last);
}