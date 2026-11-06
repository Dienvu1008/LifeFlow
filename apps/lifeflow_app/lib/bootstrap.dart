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
Future<AppWiring> bootstrap(
  AppDatabase db, {
  required StoragePlatform platform,
  void Function(String message)? onWarning,
}) async {
  await ProfileStore(db).ensureFirstProfile();

  final status = await StorageSecurity(platform: platform, onWarning: onWarning)
      .evaluate(db.activeCipher);

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
      storageNoticeProvider.overrideWithValue(notice),
    ],
  );
}
