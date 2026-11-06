// Composition-root integration: the REAL store, gateway and authorization
// policy behind the REAL UI (no fakes). Headless.
//   ADR-0008       first launch creates a guest profile with no account
//   ADR-0021       the Windows plain DB is a visible, tracked exception
//   ADR-0011       a task added in the UI is committed with its audit entry
import 'dart:io';

import 'package:application/application.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:lifeflow_app/bootstrap.dart';
import 'package:ui/ui.dart';

/// Drift does real async I/O, which the widget tester's fake clock never
/// advances. Give real time to the store, then pump the UI.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// In-memory DBs have no file header; they are plain by construction.
Future<String?> plainProbe() async => null;

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

final noAuth = RecordingAuth();

class _MemoryKeys implements DatabaseKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String key) async => value = key;
}

void main() {
  testWidgets('Android: a real encrypted file on disk shows no banner (GS-19)',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Directory dir;
    late File file;
    late AppWiring wiring;
    final warnings = <String>[];
    final auth = RecordingAuth();
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('lifeflow_app_');
      file = File('${dir.path}${Platform.pathSeparator}lifeflow.sqlite');
      final store = await openLocalStore(
        file: file,
        policy: atRestPolicyFor(StoragePlatform.android),
        keys: _MemoryKeys(),
        background: false,
      );
      wiring = await bootstrap(
        store.db,
        platform: StoragePlatform.android,
        cipherProbe: fileCipherProbe(file),
        auth: auth,
        onWarning: warnings.add,
      );
    });
    addTearDown(() async => tester.runAsync(() async {
          await wiring.db.close();
          await dir.delete(recursive: true);
        }));

    expect(wiring.notice.atRestEncrypted, isTrue);
    expect(warnings, isEmpty);
    expect(isPlainSqliteFile(file), isFalse);

    await tester.pumpWidget(ProviderScope(
      overrides: wiring.overrides,
      child: const LifeFlowApp(),
    ));
    await settle(tester);
    expect(find.byKey(const Key('storage-banner')), findsNothing);
    expect(find.textContaining('No tasks yet'), findsOneWidget);

    // Startup, rendering and opening Profiles made no auth call (SEC-002).
    await tester.tap(find.byIcon(Icons.people_outline));
    await settle(tester);
    expect(find.byKey(const Key('account-card')), findsOneWidget);
    expect(auth.calls, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('guest first launch, add a task in the UI, it is persisted',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final warnings = <String>[];
    late AppWiring wiring;
    await tester.runAsync(() async {
      wiring = await bootstrap(
        AppDatabase(NativeDatabase.memory()),
        platform: StoragePlatform.windows,
        cipherProbe: plainProbe,
        auth: noAuth,
        onWarning: warnings.add,
      );
    });
    addTearDown(() async => tester.runAsync(wiring.db.close));

    // ADR-0021: Windows plain DB warned through the log AND the notice.
    expect(warnings, hasLength(1));
    expect(wiring.notice.trackedException, isTrue);
    expect(wiring.notice.atRestEncrypted, isFalse);

    // ADR-0008: a guest profile with exactly one workspace and no account.
    final profiles = await tester.runAsync(() => ProfileStore(wiring.db).listProfiles());
    expect(profiles, hasLength(1));
    expect(profiles!.single.isBound, isFalse);

    await tester.pumpWidget(ProviderScope(
      overrides: wiring.overrides,
      child: const LifeFlowApp(),
    ));
    await settle(tester);

    expect(find.byKey(const Key('storage-banner')), findsOneWidget);
    expect(find.textContaining('No tasks yet'), findsOneWidget);

    // Add a task through the UI.
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write the report');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await settle(tester);

    expect(find.text('Write the report'), findsOneWidget);

    // It really is in the store, with its governance records (ADR-0011/0014).
    final rows = await tester.runAsync(() => wiring.db.select(wiring.db.tasks).get());
    expect(rows!.single.title, 'Write the report');
    final audit = await tester.runAsync(() => wiring.db.select(wiring.db.auditLog).get());
    expect(audit!.where((a) => a.action == 'CreateTask'), hasLength(1));
    final outbox = await tester.runAsync(() => wiring.db.select(wiring.db.outbox).get());
    expect(outbox, hasLength(1));

    // Unmount inside the test so Drift's stream-close timer (scheduled when the
    // task stream is cancelled) runs before the binding checks for timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('a plain DB on Android is a policy violation, not an exception',
      (tester) async {
    late AppWiring wiring;
    await tester.runAsync(() async {
      // A plain DB on Android is NOT the sanctioned posture (ADR-0021), so the
      // self-check must flag it rather than accept it.
      wiring = await bootstrap(
        AppDatabase(NativeDatabase.memory()),
        platform: StoragePlatform.android,
        cipherProbe: plainProbe,
        auth: noAuth,
      );
    });
    addTearDown(() async => tester.runAsync(wiring.db.close));
    // Plain on Android is NOT an accepted configuration: it must warn, loudly.
    expect(wiring.notice.atRestEncrypted, isFalse);
    expect(wiring.notice.trackedException, isFalse);
    expect(wiring.notice.needsAttention, isTrue);
  });

  testWidgets('bootstrap is idempotent: a second launch reuses the profile',
      (tester) async {
    late AppDatabase db;
    await tester.runAsync(() async {
      db = AppDatabase(NativeDatabase.memory());
      await bootstrap(db,
          platform: StoragePlatform.windows, cipherProbe: plainProbe, auth: noAuth);
      await bootstrap(db,
          platform: StoragePlatform.windows, cipherProbe: plainProbe, auth: noAuth);
    });
    addTearDown(() async => tester.runAsync(db.close));
    final n = await tester.runAsync(() => db.select(db.profiles).get());
    expect(n, hasLength(1));
    final w = await tester.runAsync(() => db.select(db.workspaces).get());
    expect(w, hasLength(1));
  });

  test('storagePlatformFor maps target platforms', () {
    expect(storagePlatformFor(TargetPlatform.android), StoragePlatform.android);
    expect(storagePlatformFor(TargetPlatform.windows), StoragePlatform.windows);
    expect(storagePlatformFor(TargetPlatform.macOS), StoragePlatform.other);
  });
}
