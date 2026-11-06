// Composition root wiring (docs/architecture/repository-structure.md): the only
// place that connects infrastructure implementations to the UI ports.
import 'package:application/application.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:ui/ui.dart';

/// Everything the UI needs, built once at startup.
class AppWiring {
  const AppWiring({required this.db, required this.notice, required this.overrides});

  final AppDatabase db;

  /// Result of the at-rest encryption self-check (ADR-0021).
  final StorageNotice notice;

  /// ProviderScope overrides that inject the implementations into the UI ports.
  final List<Override> overrides;
}

/// Maps the Flutter target platform to the at-rest policy platform.
StoragePlatform storagePlatformFor(TargetPlatform p) => switch (p) {
      TargetPlatform.android => StoragePlatform.android,
      TargetPlatform.windows => StoragePlatform.windows,
      _ => StoragePlatform.other,
    };

/// Opens the app on [db]:
///  1. first-launch bootstrap (a guest profile + its Personal Workspace;
///     idempotent, ADR-0008),
///  2. the startup at-rest encryption self-check; a warning is emitted through
///     [onWarning] and surfaced in the UI, never silent (ADR-0021, SR-01a),
///  3. drains events a crash left undispatched (transactional outbox, ADR-0014).
///
/// [cipherProbe] must reflect the real file on disk (use `fileCipherProbe`);
/// `PRAGMA cipher` is not a valid signal with sqlite3mc (T6b finding).
///
/// [auth] is only used for interactive sign-in/out, never while starting up
/// or reading data (LF-INV-SEC-002): this function makes no auth call.
Future<AppWiring> bootstrap(
  AppDatabase db, {
  required StoragePlatform platform,
  required CipherProbe cipherProbe,
  required AuthGateway auth,
  void Function(String message)? onWarning,
}) async {
  // Writes the first page, so the header check below sees the real file.
  await ProfileStore(db).ensureFirstProfile();

  final status = await StorageSecurity(platform: platform, onWarning: onWarning)
      .evaluate(cipherProbe);

  final gateway = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
  await gateway.dispatchPendingEvents();

  final notice = storageNoticeFrom(status);
  return AppWiring(
    db: db,
    notice: notice,
    overrides: [
      taskQueriesProvider.overrideWithValue(DriftTaskQueries(db)),
      taskServiceProvider.overrideWithValue(DriftTaskService(db, gateway)),
      profileServiceProvider.overrideWithValue(DriftProfileService(db, gateway)),
      accountServiceProvider
          .overrideWithValue(DriftAccountService(db, gateway, auth)),
      storageNoticeProvider.overrideWithValue(notice),
    ],
  );
}
