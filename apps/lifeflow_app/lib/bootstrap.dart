// Composition root wiring (docs/architecture/repository-structure.md): the only
// place that connects infrastructure implementations to the UI ports.
import 'package:application/application.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:ui/ui.dart';

import 'notifications.dart';

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
    this.reminders,
    this.focusLaunch = const NoActiveFocus(),
  });

  final String profileId;
  final AppDatabase db;

  /// P03 T3: the focus session found when this profile opened (D1). An
  /// untrusted one is already kept as unrecoverable; an overdue pomodoro
  /// waits for the user's choice (the UI comes in T6).
  final FocusLaunch focusLaunch;

  /// Keeps the device's reminders equal to this profile's plan (ADR-0034).
  final ReminderSync? reminders;

  /// Stops watching for reminder changes. The pending reminders stay: they
  /// must fire with the app closed. Call BEFORE the next profile opens, so
  /// the old profile can never re-schedule its reminders after the switch.
  Future<void> stopReminders() async => reminders?.stop();

  /// Ends the session: reminder sync, then the store.
  Future<void> close() async {
    await stopReminders();
    await db.close();
  }

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
  required FileGateway files,
  bool windowsPlainFallback = false,
  String initialRoute = '/tasks',
  String deviceZone = 'UTC',
  ReminderScheduler reminders = const NoDeviceReminders(),
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

    // P03 T3 (D1, LF-INV-EXEC-003): bring back the session a kill left.
    final focusLaunch = await DriftFocusService(db, gateway).recoverOnLaunch();

    final notice = storageNoticeFrom(status);
    final accounts = DriftAccountService(
        db: db, gateway: gateway, auth: auth, directory: directory, host: host);

    // P02 T6a: device settings (D1–D3) are read once so the agenda's query
    // limits are known before the first query; saving them updates the cache.
    final settings = DirectorySettingsService(directory);
    await settings.planningSettings();
    const zones = KernelZoneCatalog();
    final zone = zones.deviceZoneOr(deviceZone);
    final deviceTime = SystemDeviceTime(() => zone);
    final agenda = DriftAgendaQueries(db, deviceTime, limits: () => settings.limitsCache.limits);

    // P02 T7: this profile's reminders replace whatever is pending on the
    // device (another profile's after a switch or a sign-out lock).
    final reminderSync = ReminderSync(db, DriftReminderPlanner(db, deviceTime), reminders,
        onError: (e) => onWarning?.call('[reminders] $e'));
    await reminderSync.start();

    // P03 T4 (D9): store the results of the periods that ended while the
    // app was closed.
    final habits = DriftHabitService(db, gateway, deviceTime, deviceId: platform.name);
    try {
      await habits.closePeriods();
    } catch (e) {
      onWarning?.call('[habits] $e'); // never blocks opening the profile
    }
    return AppWiring(
      profileId: profileId,
      db: db,
      notice: notice,
      onSessionRevoked: accounts.handleSessionRevoked,
      reminders: reminderSync,
      focusLaunch: focusLaunch,
      overrides: [
        reminderServiceProvider.overrideWithValue(DriftReminderService(db, gateway)),
        reminderSchedulerProvider.overrideWithValue(reminders),
        taskQueriesProvider.overrideWithValue(DriftTaskQueries(db)),
        taskServiceProvider.overrideWithValue(DriftTaskService(db, gateway)),
        profileServiceProvider
            .overrideWithValue(DirectoryProfileService(directory, host)),
        accountServiceProvider.overrideWithValue(accounts),
        dataTransferServiceProvider
            .overrideWithValue(DriftDataTransferService(db, directory, gateway: gateway)),
        fileGatewayProvider.overrideWithValue(files),
        settingsServiceProvider.overrideWithValue(settings),
        taskSchedulingProvider.overrideWithValue(DriftTaskScheduling(db, gateway)),
        agendaQueriesProvider.overrideWithValue(agenda),
        zoneCatalogProvider.overrideWithValue(zones),
        deviceZoneProvider.overrideWithValue(zone),
        todayProvider.overrideWithValue(agenda.today),
        eventServiceProvider.overrideWithValue(DriftEventService(db, gateway)),
        calendarServiceProvider.overrideWithValue(DriftCalendarService(db, gateway)),
        calendarQueriesProvider.overrideWithValue(
            DriftCalendarQueries(db, agenda, limits: () => settings.limitsCache.limits)),
        storageNoticeProvider.overrideWithValue(notice),
        initialRouteProvider.overrideWithValue(initialRoute),
      ],
    );
  } catch (_) {
    await db.close();
    rethrow;
  }
}
