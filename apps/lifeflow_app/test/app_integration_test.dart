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
}

/// A temp app-support directory with a directory opened on it.
class World {
  late Directory base;
  late ProfileDirectory directory;
  final keys = MemoryKeys();
  final auth = RecordingAuth();
  final warnings = <String>[];

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
        openSession: (id, host) => openSession(
          directory: directory,
          profileId: id,
          platform: platform,
          auth: auth,
          host: host,
          windowsPlainFallback: fallback,
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
    await tester.tap(find.byTooltip('Add task'));
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

  testWidgets('switching profile in the UI swaps the store (SR-03, ID-002)',
      (tester) async {
    final w = await pumpApp(tester, StoragePlatform.android);
    final a = (await tester.runAsync(() => w.directory.active()))!.id;

    // A has a task.
    await tester.tap(find.byTooltip('Add task'));
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

  test('storagePlatformFor maps target platforms', () {
    expect(storagePlatformFor(TargetPlatform.android), StoragePlatform.android);
    expect(storagePlatformFor(TargetPlatform.windows), StoragePlatform.windows);
    expect(storagePlatformFor(TargetPlatform.macOS), StoragePlatform.other);
  });
}
