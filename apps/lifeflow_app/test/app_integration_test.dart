// Composition-root integration: real per-profile stores (SR-03), registry,
// gateway and authorization policy behind the real UI. Headless.
//   ADR-0008          first launch = one guest profile, no account
//   ADR-0022 / GS-19  encrypted on Android AND Windows -> no banner
//   ADR-0021 fallback plain Windows only with the flag -> tracked banner
//   SR-03 / ID-002    switching profile in the UI swaps the store; data of
//                     one profile never shows in another
//   ADR-0011          a task added in the UI is committed with its audit row
//   LF-INV-SEC-002    opening and reading never call the identity provider
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:lifeflow_app/bootstrap.dart';
import 'package:lifeflow_app/root.dart';
import 'package:ui/src/documents/document_page.dart' show DocumentPage, DocumentPageState;

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
  OkAuth([this.account = 'acc-gh']);
  final String account;
  @override
  bool get isConfigured => true;
  @override
  Stream<void> get sessionRevoked => const Stream.empty();
  @override
  Future<AuthSession> signIn(SignInRequest request) async => AuthSession(
      accountId: account, provider: 'github', issuedAt: Instant.now());
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
  Future<Uint8List?> pickExport({required int maxBytes}) async {
    if (pickBytes != null) return pickBytes;
    final t = pickOverride ?? saved;
    return t == null ? null : Uint8List.fromList(utf8.encode(t));
  }

  /// What the next "choose an export" returns as bytes (a .zip).
  Uint8List? pickBytes;

  /// What the next "attach a file" dialog returns.
  PickedFile? nextFile;
  Uint8List? savedBytes;

  @override
  Future<PickedFile?> pickFile({required int maxBytes}) async => nextFile;

  @override
  Future<bool> saveBytes(String suggestedName, Uint8List bytes, {String mime = 'application/octet-stream'}) async {
    savedName = suggestedName;
    savedBytes = bytes;
    return true;
  }
}

/// P06 T7: API keys in memory (secure storage is not there in tests).
class MemoryAiKeys implements AiKeyStore {
  final values = <CloudProvider, String>{};
  @override
  Future<String?> read(CloudProvider p) async => values[p];
  @override
  Future<void> write(CloudProvider p, String key) async => values[p] = key;
  @override
  Future<void> delete(CloudProvider p) async => values.remove(p);
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
  final aiKeys = MemoryAiKeys();

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
          aiKeys: (_) => aiKeys,
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
      await tester.tap(find.byKey(const Key('rail-profile')));
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

  testWidgets('P02 T6a: a schedule set in the UI is stored and shows in the Timeline',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Water the plants');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    // Not planned yet: Today is empty.
    await tester.tap(find.text('Timeline'));
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

    await tester.tap(find.text('Timeline'));
    await settle(tester);
    // P03 UX U4: the Timeline shows the daily repeat on every day; today first.
    expect(find.text('Water the plants'), findsWidgets);
    expect(find.text('Repeats'), findsWidgets);

    // D5: ticking marks only today's occurrence; the task stays open.
    await tester.tap(find.bySemanticsLabel('Complete Water the plants').first);
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
    // Added in Habits (its own destination, U-D2): a daily habit (D6a).
    await tester.tap(find.text('Habits'));
    await settle(tester);
    expect(find.byKey(const Key('habits-empty')), findsOneWidget);
    await tester.tap(find.byTooltip('Add habit'));
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
    await tester.tap(find.text('Timeline'));
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

  testWidgets('P05a T8: a document made in Documents is stored with its revisions; found by search; a file kept encrypted',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    w.files.nextFile = PickedFile(name: 'bảng.txt', mime: 'text/plain', bytes: Uint8List.fromList(utf8.encode('bí mật')));
    await tester.tap(find.text('Documents'));
    await settle(tester);
    await tester.tap(find.byTooltip('New document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ghi chú họp');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    final page = tester.state<DocumentPageState>(find.byType(DocumentPage));
    final c = page.controller!;
    c.replaceText(0, 0, 'Thứ Hai lúc 9 giờ', const TextSelection.collapsed(offset: 17));
    await tester.tap(find.byKey(const Key('doc-tool-attach')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Ghi chú họp'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('doc-search')), 'ghi chú');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-results')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('doc-results')), matching: find.text('Ghi chú họp')), findsOneWidget);

    final id = (await tester.runAsync(() => w.directory.active()))!.id;
    final rows = await tester.runAsync(() async {
      final s = await w.directory.openProfile(id);
      final docs = await s.db.select(s.db.documents).get();
      final revisions = await s.db.select(s.db.documentRevisions).get();
      final audit = await s.db.select(s.db.auditLog).get();
      await s.db.close();
      final files = w.directory.attachmentsDir(id).listSync().whereType<File>().toList();
      return (docs: docs, revisions: revisions, audit: audit, files: files);
    });
    final d = rows!.docs.single;
    expect(d.title, 'Ghi chú họp');
    expect(d.body, contains('Thứ Hai lúc 9 giờ'));
    expect(d.body, contains('bảng.txt'), reason: 'the reference is in the body');
    // The first revision, then one per save (C5): 10 s idle may have saved
    // already while the editor animated; leaving saved the rest (C7).
    expect(rows.revisions.length, greaterThanOrEqualTo(2));
    final newest = rows.revisions.reduce((a, b) => a.documentVersion > b.documentVersion ? a : b);
    expect((newest.body, newest.documentVersion), (d.body, d.version), reason: 'the stored text is its newest revision');
    expect(rows.audit.where((a) => a.resourceType == 'document'), hasLength(rows.revisions.length));
    final stored = rows.files.single.readAsBytesSync();
    expect(utf8.decode(stored, allowMalformed: true), isNot(contains('bí mật')), reason: 'kept encrypted (ADR-0072)');

    // P05a T9 (C11): the export is a .zip with the file beside the JSON.
    await tester.tap(find.byKey(const Key('rail-profile')));
    await settle(tester);
    await tester.tap(find.text('Export this profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Export'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(w.files.savedName, endsWith('.lifeflow.zip'));
    final zip = readExportFile(w.files.savedBytes!);
    expect(zip.files.values.single, utf8.encode('bí mật'), reason: 'decrypted in the file the person chose to make');
    expect(zip.text, contains('Ghi chú họp'));
    await finish(tester, w);
  });

  testWidgets('P05a T10 step 6: a [[…]] link made in the editor shows as a backlink on its target', (tester) async {
    final w = await pumpApp(tester, StoragePlatform.windows);
    await tester.tap(find.text('Documents'));
    await settle(tester);
    Future<void> newDoc(String title) async {
      await tester.tap(find.byTooltip('New document'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, title);
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      await settle(tester);
      await tester.pumpAndSettle();
    }

    Future<void> back() async {
      await tester.pageBack();
      await tester.pump();
      await settle(tester);
      await tester.pumpAndSettle();
    }

    await newDoc('Kế hoạch');
    await back();
    await newDoc('Nhật ký');
    final c = tester.state<DocumentPageState>(find.byType(DocumentPage)).controller!;
    c.replaceText(0, 0, 'Đọc [[', const TextSelection.collapsed(offset: 6));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('doc-link-picker')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const Key('doc-link-picker')), matching: find.text('Kế hoạch')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(c.document.toPlainText(), contains('Đọc Kế hoạch'));
    await back();

    // Step 5: rename the target on its page, then open the first again.
    await tester.tap(find.text('Kế hoạch'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('doc-title')), 'Kế hoạch mới');
    await back();
    await tester.tap(find.text('Nhật ký'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(tester.state<DocumentPageState>(find.byType(DocumentPage)).controller!.document.toPlainText(),
        contains('Đọc Kế hoạch mới'));
    await back();

    await tester.tap(find.text('Kế hoạch mới'));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('doc-links')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('Đọc Kế hoạch'), findsOneWidget, reason: 'the sentence of the backlink');
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
    // P03 UX U5: the day is a time grid.
    expect(find.byKey(const Key('calendar-grid')), findsOneWidget);

    // New event from the 09:00 slot (no + button, C1): 09:00–10:00 in the
    // device zone.
    await tester.drag(find.byKey(const Key('calendar-grid')), const Offset(0, 3000));
    await tester.pumpAndSettle();
    final column = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('grid-'));
    await tester.tapAt(tester.getTopLeft(column.first) + const Offset(30, 28 + 3 * 48 + 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slot-event')));
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Standup');
    await tester.tap(find.byKey(const Key('event-save')));
    await tester.pump();
    await settle(tester);
    await tester.pumpAndSettle();
    // A block in the grid; it opens the full row.
    Future<void> openBlock(String title) async {
      final block = find.widgetWithText(InkWell, title).first;
      await tester.ensureVisible(block);
      await tester.pumpAndSettle();
      await tester.tap(block);
      await tester.pumpAndSettle();
    }

    await openBlock('Standup');
    // In the block and in the full row.
    expect(find.text('09:00–10:00'), findsNWidgets(2));
    Navigator.of(tester.element(find.text('09:00–10:00').last)).pop();
    await tester.pumpAndSettle();

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
    await openBlock('Standup');
    expect(find.text('Overlaps Gym'), findsOneWidget);
    Navigator.of(tester.element(find.text('Overlaps Gym'))).pop();
    await tester.pumpAndSettle();
    await openBlock('Gym');
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
    await tester.tap(find.byKey(const Key('rail-profile')));
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

    await tester.tap(find.byKey(const Key('rail-profile')));
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
    await tester.tap(find.byKey(const Key('rail-profile')));
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
    await tapAndSettle(find.byKey(const Key('rail-profile')));
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
    await tapAndSettle(find.byKey(const Key('rail-profile')));
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
    await tapAndSettle(find.byKey(const Key('rail-profile')));
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
    await tapAndSettle(find.byKey(const Key('rail-profile')));
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
    await tapAndSettle(find.byKey(const Key('rail-profile')));
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

    await tapAndSettle(find.byKey(const Key('rail-profile')));
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

    await tester.tap(find.byKey(const Key('rail-profile')));
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
    await tester.tap(find.byKey(const Key('rail-profile')));
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
  syncThroughTheUi();
  shareThroughTheUi();
}

/// The in-memory sync server as the profile's own account sees it: like the
/// app's HttpRemoteGateway, it asks for the profile's account at each call.
class _AccountRemote implements RemoteGateway, SpaceGateway {
  _AccountRemote(this.server, this.accountOf) : inner = MemoryRemoteGateway(server);
  final MemoryRemoteServer server;
  final Future<String?> Function() accountOf;
  final MemoryRemoteGateway inner;

  Future<MemoryRemoteGateway> _signedIn() async => inner..accountId = await accountOf();

  @override
  Future<List<RemoteWorkspace>> workspaces() async => (await _signedIn()).workspaces();
  @override
  Future<void> createWorkspace(RemoteWorkspace w) async => (await _signedIn()).createWorkspace(w);
  @override
  Future<void> updateWrappedKey(String id, Uint8List key, String kind, Uint8List? salt) async =>
      (await _signedIn()).updateWrappedKey(id, key, kind, salt);
  @override
  Future<void> deleteWorkspace(String id) async => (await _signedIn()).deleteWorkspace(id);
  @override
  Future<PushResult> push(String ws, String device, List<RecordPush> records, {String keyId = ''}) async =>
      (await _signedIn()).push(ws, device, records, keyId: keyId);
  @override
  Future<List<SealedRecord>> pull(String ws, int after, {int limit = 1000}) async =>
      (await _signedIn()).pull(ws, after, limit: limit);
  @override
  Future<int> purge(String ws, DateTime before) async => (await _signedIn()).purge(ws, before);

  // P04b T13: the spaces, for the same account at each call.
  @override
  Future<AccountKeys?> myKeys() async => (await _signedIn()).myKeys();
  @override
  Future<void> setMyKeys(AccountKeys k) async => (await _signedIn()).setMyKeys(k);
  @override
  Future<Map<String, Uint8List>> publicKeys(List<String> ids) async => (await _signedIn()).publicKeys(ids);
  @override
  Future<List<RemoteSpace>> spaces() async => (await _signedIn()).spaces();
  @override
  Future<void> createSpace(String w, Uint8List k, String id) async => (await _signedIn()).createSpace(w, k, id);
  @override
  Future<void> deleteSpace(String w) async => (await _signedIn()).deleteSpace(w);
  @override
  Future<List<RemoteMember>> members(String w) async => (await _signedIn()).members(w);
  @override
  Future<List<RemoteInvitation>> invitations(String w) async => (await _signedIn()).invitations(w);
  @override
  Future<void> invite(String w, String h, SpaceRole role, InviteKind kind,
          {Uint8List? wrappedKey, String keyId = '', int days = 7}) async =>
      (await _signedIn()).invite(w, h, role, kind, wrappedKey: wrappedKey, keyId: keyId, days: days);
  @override
  Future<void> cancelInvitation(String h) async => (await _signedIn()).cancelInvitation(h);
  @override
  Future<InvitationPreview> peekInvitation(String h) async => (await _signedIn()).peekInvitation(h);
  @override
  Future<AcceptedInvitation> acceptInvitation(String h, {Uint8List? sealedName}) async =>
      (await _signedIn()).acceptInvitation(h, sealedName: sealedName);
  @override
  Future<void> approveMember(String w, String a, Uint8List k, String id) async => (await _signedIn()).approveMember(w, a, k, id);
  @override
  Future<void> setMyWrappedKey(String w, Uint8List k, String id) async => (await _signedIn()).setMyWrappedKey(w, k, id);
  @override
  Future<void> removeMember(String w, String a) async => (await _signedIn()).removeMember(w, a);
  @override
  Future<void> leaveSpace(String w) async => (await _signedIn()).leaveSpace(w);
  @override
  Future<void> setRole(String w, String a, SpaceRole role) async => (await _signedIn()).setRole(w, a, role);
  @override
  Future<void> handOver(String w, String a) async => (await _signedIn()).handOver(w, a);
  @override
  Future<void> setRules(String w, SpaceRules rules) async => (await _signedIn()).setRules(w, rules);
  @override
  Future<void> rotateKey(String w, String id, Map<String, Uint8List> wraps) async => (await _signedIn()).rotateKey(w, id, wraps);
  @override
  Future<int> dropOldKeyRecords(String w) async => (await _signedIn()).dropOldKeyRecords(w);
}

/// P04 T5 (ADR-0058; D5, D9, D15): two devices of one account, each with its
/// own stores and secure storage, one in-memory server, through the real UI:
/// the first turns sync on with a recovery key, the second joins with the
/// words and merges; each sees the other's task, and the status shows.
void syncThroughTheUi() {
  testWidgets('P04 T5: sync on with a recovery key on one device; a second joins and merges', (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = MemoryRemoteServer();

    Future<void> tapAndSettle(Finder f, [int rounds = 8]) async {
      await tester.ensureVisible(f);
      await settle(tester, 2);
      await tester.tap(f);
      await settle(tester, rounds);
    }

    Future<World> device() async {
      final w = World();
      await tester.runAsync(() => w.open(StoragePlatform.android));
      final first = (await tester.runAsync(() => w.directory.active()))!.id;
      final auth = OkAuth();
      await tester.pumpWidget(LifeFlowRoot(
        initialProfileId: first,
        openSession: (id, host, route) => openSession(
          directory: w.directory,
          profileId: id,
          platform: StoragePlatform.android,
          auth: auth,
          host: host,
          initialRoute: route,
          files: w.files,
          sync: SyncWiring(remoteFor: (accountOf) => _AccountRemote(server, accountOf), keysFor: w.keys.call),
        ),
      ));
      await settle(tester);
      // Sign in on the empty guest (binds in place).
      await tapAndSettle(find.byKey(const Key('rail-profile')));
      await tapAndSettle(find.widgetWithText(FilledButton, 'Sign in'));
      await tapAndSettle(find.text('Continue with GitHub'), 12);
      expect(find.text('Signed in with GitHub.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6)); // the snackbar goes
      await settle(tester, 2);
      return w;
    }

    Future<void> addTask(String title) async {
      await tapAndSettle(find.byIcon(Icons.checklist_outlined));
      await tapAddTask(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), title);
      await tapAndSettle(find.widgetWithText(FilledButton, 'Add'));
      expect(find.text(title), findsOneWidget);
    }

    Future<void> openSyncSettings() async {
      await tapAndSettle(find.byIcon(Icons.settings_outlined));
      final list = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      for (var i = 0; i < 20 && find.byKey(const Key('sync-settings')).evaluate().isEmpty; i++) {
        list.jumpTo((list.pixels + 400).clamp(0, list.maxScrollExtent));
        await settle(tester, 1);
      }
      await tapAndSettle(find.byKey(const Key('sync-settings')));
    }

    Future<void> close(World w) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester, 2);
      await tester.runAsync(w.dispose);
    }

    // Device A: a task, then sync on with a recovery key.
    final a = await device();
    await addTask('From A');
    await openSyncSettings();
    await tapAndSettle(find.byKey(const Key('sync-switch')), 10);
    await tapAndSettle(find.byKey(const Key('setup-recovery-key')));
    final words = [
      for (var n = 1; n <= 24; n++) (tester.widget<Text>(find.byKey(Key('key-word-$n'))).data!).split(' ').last
    ];
    await tapAndSettle(find.byKey(const Key('setup-next')));
    final prompt = tester.widget<Text>(find.textContaining('Type words')).data!;
    final positions = [for (final m in RegExp(r'\d+').allMatches(prompt)) int.parse(m[0]!)];
    await tester.enterText(find.byKey(const Key('setup-word-1')), words[positions[0] - 1]);
    await tester.enterText(find.byKey(const Key('setup-word-2')), words[positions[1] - 1]);
    await tapAndSettle(find.byKey(const Key('setup-turn-on')), 16);
    expect(find.text('Sync is on.'), findsOneWidget);
    final onServer = (await tester.runAsync(() => MemoryRemoteGateway(server, accountId: 'acc-gh').workspaces()))!;
    expect(server.dump(onServer.single.workspaceId), isNotEmpty, reason: 'uploaded, sealed');
    expect(find.textContaining('Synced'), findsWidgets);
    expect(a.keys.values.keys.where((k) => k.startsWith('lifeflow.sync.key.')), hasLength(1),
        reason: 'the workspace key is in secure storage');
    await close(a);

    // Device B: its own task, then joins with the 24 words; merge (default).
    final b = await device();
    await addTask('From B');
    await openSyncSettings();
    await tapAndSettle(find.byKey(const Key('sync-switch')), 10);
    expect(find.text('Join your synced data'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-key')), words.join(' '));
    await tapAndSettle(find.byKey(const Key('join-submit')), 20);
    expect(find.text('This device now syncs with your account.'), findsOneWidget);
    expect(find.byKey(const Key('sync-undo-join')), findsOneWidget);
    await tapAndSettle(find.byIcon(Icons.checklist_outlined));
    expect(find.text('From A'), findsOneWidget);
    expect(find.text('From B'), findsOneWidget);
    await close(b);
  });
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

/// P04b T13 (ADR-0065): two people, each signed in to their own account on
/// their own device, one in-memory server, through the real UI: Lan makes a
/// space and an invitation; Minh asks to join with the code (the rules shown
/// first); Lan lets Minh in, by name; Lan's task reaches Minh; the server
/// never sees a title or a name.
void shareThroughTheUi() {
  testWidgets('P04b T13: a space made, an invitation, a request let in, a task shared', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = MemoryRemoteServer();

    Future<void> tapAndSettle(Finder f, [int rounds = 8]) async {
      await tester.ensureVisible(f);
      await settle(tester, 2);
      await tester.tap(f);
      await settle(tester, rounds);
    }

    Future<void> open(World w, OkAuth auth) async {
      final id = (await tester.runAsync(() => w.directory.active()))!.id;
      await tester.pumpWidget(LifeFlowRoot(
        initialProfileId: id,
        openSession: (id, host, route) => openSession(
          directory: w.directory,
          profileId: id,
          platform: StoragePlatform.android,
          auth: auth,
          host: host,
          initialRoute: route,
          files: w.files,
          sync: SyncWiring(remoteFor: (accountOf) => _AccountRemote(server, accountOf), keysFor: w.keys.call),
        ),
      ));
      await settle(tester);
    }

    Future<void> close() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester, 2);
    }

    /// A person's device: signed in, named, personal sync on (B5).
    Future<World> person(String account, String name) async {
      final w = World();
      await tester.runAsync(() => w.open(StoragePlatform.android));
      final p = (await tester.runAsync(() => w.directory.active()))!;
      await tester.runAsync(() async {
        final store = await w.directory.openProfile(p.id);
        await store.db.update(store.db.profiles).write(ProfilesCompanion(displayName: Value(name)));
        await store.db.close();
      });
      final auth = OkAuth(account);
      await open(w, auth);
      await tapAndSettle(find.byKey(const Key('rail-profile')));
      await tapAndSettle(find.widgetWithText(FilledButton, 'Sign in'));
      await tapAndSettle(find.text('Continue with GitHub'), 12);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester, 2);
      await tapAndSettle(find.byIcon(Icons.settings_outlined));
      final list = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      for (var i = 0; i < 20 && find.byKey(const Key('sync-settings')).evaluate().isEmpty; i++) {
        list.jumpTo((list.pixels + 400).clamp(0, list.maxScrollExtent));
        await settle(tester, 1);
      }
      await tapAndSettle(find.byKey(const Key('sync-settings')));
      await tapAndSettle(find.byKey(const Key('sync-switch')), 10);
      await tapAndSettle(find.byKey(const Key('setup-recovery-key')));
      final words = [
        for (var n = 1; n <= 24; n++) (tester.widget<Text>(find.byKey(Key('key-word-$n'))).data!).split(' ').last
      ];
      await tapAndSettle(find.byKey(const Key('setup-next')));
      final prompt = tester.widget<Text>(find.textContaining('Type words')).data!;
      final positions = [for (final m in RegExp(r'\d+').allMatches(prompt)) int.parse(m[0]!)];
      await tester.enterText(find.byKey(const Key('setup-word-1')), words[positions[0] - 1]);
      await tester.enterText(find.byKey(const Key('setup-word-2')), words[positions[1] - 1]);
      await tapAndSettle(find.byKey(const Key('setup-turn-on')), 16);
      expect(find.text('Sync is on.'), findsOneWidget);
      await tapAndSettle(find.byIcon(Icons.checklist_outlined));
      return w;
    }

    // Lan: a space, a task in it, an invitation.
    final lan = await person('acc-lan', 'Lan');
    await tapAndSettle(find.byKey(const Key('rail-spaces')));
    await tapAndSettle(find.byKey(const Key('rail-space-new')));
    await tester.enterText(find.byType(TextField), 'Family');
    await tapAndSettle(find.widgetWithText(FilledButton, 'Create'), 16);
    expect(find.byKey(const Key('space-bar')), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // the snackbar goes
    await settle(tester, 2);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family dinner');
    await tapAndSettle(find.widgetWithText(FilledButton, 'Add'));
    await tapAndSettle(find.byKey(const Key('space-bar')));
    await tapAndSettle(find.byKey(const Key('invite-make')), 12);
    final code = tester.widget<SelectableText>(find.byKey(const Key('invite-code'))).data!;
    await tapAndSettle(find.byKey(const Key('space-sync-now')), 16);
    await close();

    // Minh: asks to join with the code; the rules first.
    final minh = await person('acc-minh', 'Minh');
    await tapAndSettle(find.byKey(const Key('rail-spaces')));
    await tapAndSettle(find.byKey(const Key('rail-space-join')));
    await tester.enterText(find.byKey(const Key('join-space-code')), code.toLowerCase());
    await tapAndSettle(find.byKey(const Key('join-space-look')), 12);
    expect(find.text('You are invited as Editor.'), findsOneWidget);
    expect(find.byKey(const Key('join-space-leave-rule')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('join-space-name'))).controller!.text, 'Minh',
        reason: 'the profile\'s name, to keep or change (T14 finding 1)');
    await tapAndSettle(find.byKey(const Key('join-space-join')), 16);
    expect(find.text('You asked to join. The owner lets you in.'), findsOneWidget);
    await close();

    // Lan lets Minh in, knowing it is Minh (the name sealed for Lan).
    await open(lan, OkAuth('acc-lan'));
    await tapAndSettle(find.byKey(const Key('space-bar')));
    expect(find.text('Minh'), findsOneWidget);
    await tapAndSettle(find.byKey(const ValueKey('member-approve-acc-minh')), 16);
    await tapAndSettle(find.byKey(const Key('space-sync-now')), 16);
    await close();

    // Minh: the space appears (the space sync refreshes when the app opens);
    // the task is there.
    await open(minh, OkAuth('acc-minh'));
    await settle(tester, 20);
    await tapAndSettle(find.byKey(const Key('rail-spaces')), 12);
    expect(find.text('Family'), findsWidgets);
    await tapAndSettle(find.text('Family').last, 20);
    expect(find.byKey(const Key('space-bar')), findsOneWidget);
    expect(find.text('Family dinner'), findsOneWidget);
    await close();

    final space = (await tester.runAsync(() => MemoryRemoteGateway(server, accountId: 'acc-lan').spaces()))!.single;
    for (final r in server.dump(space.workspaceId)) {
      final text = String.fromCharCodes(r.sealed ?? const []);
      expect(text, isNot(anyOf(contains('Family dinner'), contains('Minh'), contains('Family'))));
    }
    await tester.runAsync(lan.dispose);
    await tester.runAsync(minh.dispose);
  });
}
