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
}

/// A temp app-support directory with a directory opened on it.
class World {
  late Directory base;
  late ProfileDirectory directory;
  final keys = MemoryKeys();
  final auth = RecordingAuth();
  final warnings = <String>[];
  final files = MemoryFiles();

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
    await tapAndSettle(find.byTooltip('Add task'));
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
        await tapAndSettle(find.byTooltip('Add task'));
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
}
