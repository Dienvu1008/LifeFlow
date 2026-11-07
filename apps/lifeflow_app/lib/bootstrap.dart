// Composition root wiring (docs/architecture/repository-structure.md): the only
// place that connects infrastructure implementations to the UI ports.
import 'package:application/application.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:ui/ui.dart';

/// Everything the UI needs for ONE profile, built when that profile opens.
/// Since SR-03 every profile has its own store, so switching profiles means
/// a new [AppWiring] (and a new provider scope).
class AppWiring {
  const AppWiring({
    required this.profileId,
    required this.db,
    required this.notice,
    required this.overrides,
    required this.onSessionRevoked,
  });

  final String profileId;
  final AppDatabase db;

  /// ADR-0024: the provider ended the session while online; lock this
  /// profile and move to a guest (no-op for a guest profile).
  final Future<void> Function() onSessionRevoked;

  /// Result of the at-rest encryption self-check (ADR-0021/0022).
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

/// Opens [profileId]'s own store and wires the UI ports to it:
///  1. the startup at-rest encryption self-check on THIS profile's file;
///     a warning is emitted through [onWarning] and surfaced in the UI, never
///     silent (ADR-0021/0022, SR-01a),
///  2. drains events a crash left undispatched (transactional outbox, ADR-0014).
///
/// [auth] is only used for interactive sign-in/out, never while opening or
/// reading data (LF-INV-SEC-002): this function makes no auth call.
Future<AppWiring> openSession({
  required ProfileDirectory directory,
  required String profileId,
  required StoragePlatform platform,
  required AuthGateway auth,
  required ProfileHost host,
  bool windowsPlainFallback = false,
  String initialRoute = '/tasks',
  void Function(String message)? onWarning,
}) async {
  final store = await directory.openProfile(profileId);
  final db = store.db;
  try {
    // Reads the store, so the header check below sees the written file.
    await ProfileStore(db).getActiveProfile();

    final status = await StorageSecurity(
      platform: platform,
      windowsPlainFallback: windowsPlainFallback,
      onWarning: onWarning,
    ).evaluate(fileCipherProbe(directory.profileFile(profileId)));

    final gateway = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    await gateway.dispatchPendingEvents();

    final notice = storageNoticeFrom(status);
    final accounts = DriftAccountService(
        db: db, gateway: gateway, auth: auth, directory: directory, host: host);
    return AppWiring(
      profileId: profileId,
      db: db,
      notice: notice,
      onSessionRevoked: accounts.handleSessionRevoked,
      overrides: [
        taskQueriesProvider.overrideWithValue(DriftTaskQueries(db)),
        taskServiceProvider.overrideWithValue(DriftTaskService(db, gateway)),
        profileServiceProvider
            .overrideWithValue(DirectoryProfileService(directory, host)),
        accountServiceProvider.overrideWithValue(accounts),
        storageNoticeProvider.overrideWithValue(notice),
        initialRouteProvider.overrideWithValue(initialRoute),
      ],
    );
  } catch (_) {
    await db.close();
    rethrow;
  }
}
