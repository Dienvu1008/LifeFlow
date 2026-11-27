// Composition root wiring (docs/architecture/repository-structure.md): the only
// place that connects infrastructure implementations to the UI ports.
import 'dart:async';
import 'dart:io';

import 'package:application/application.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:ui/ui.dart';

import 'ai/llamadart_runtime.dart';
import 'ai/secure_ai_keys.dart';
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
    this.sync,
    this.spaceSync,
    this.background,
  });

  /// P05b T2: work this session started that uses the store (the sweep, the
  /// reading of PDFs); [close] waits for it before closing the store.
  final Future<void> Function()? background;

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

  /// P04 T5 (D8): this profile's automatic sync while the app is open; null
  /// when the build has no sync server.
  final SyncScheduler? sync;

  /// P04b T11 (B12): the shown shared space's automatic sync, every minute
  /// while one is shown; null when the build has no sync server.
  final SyncScheduler? spaceSync;

  /// The app came back to the front: sync now if automatic (D8).
  void resumed() {
    sync?.resumed();
    spaceSync?.resumed();
  }

  /// Stops the automatic sync. Call BEFORE the next profile opens, as for
  /// reminders, so the old store is not synced while it closes.
  Future<void> stopSync() async {
    await sync?.stop();
    await spaceSync?.stop();
  }

  /// Ends the session: reminder sync, automatic sync, then the store.
  Future<void> close() async {
    await stopReminders();
    await stopSync();
    await background?.call();
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

/// P04 T5 (ADR-0058): how a profile reaches the sync server. Null in a build
/// without one (no Supabase defines): sync shows as unavailable.
class SyncWiring {
  const SyncWiring({required this.remoteFor, required this.keysFor});

  /// The server for the profile's own account: [accountOf] gives that
  /// account's id (null for a guest or a signed-out profile), read at each
  /// call.
  final RemoteGateway Function(Future<String?> Function() accountOf) remoteFor;

  /// Secure-storage slots for the workspace keys (ADR-0054).
  final DatabaseKeyStore Function(String name) keysFor;
}

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
  String initialRoute = '/overview',
  String deviceZone = 'UTC',
  ReminderScheduler reminders = const NoDeviceReminders(),
  SyncWiring? sync,
  void Function(String message)? onWarning,
  // P06 T7 (ADR-0087): the person's API keys (secure storage by default),
  // the local runtime, and the file dialog for a model file.
  AiKeyStore Function(String profileId)? aiKeys,
  LocalRuntime Function()? localRuntime,
  Future<String?> Function()? pickModelFile,
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
    await settings.showArchivedScheduled(); // primes what the agenda reads
    const zones = KernelZoneCatalog();
    final zone = zones.deviceZoneOr(deviceZone);
    final deviceTime = SystemDeviceTime(() => zone);
    final agenda = DriftAgendaQueries(db, deviceTime,
        limits: () => settings.limitsCache.limits, showArchived: () => settings.showArchivedCache);

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
    // P06b W6 (ADR-0094): what has been in the trash long enough is deleted
    // for good (the retention is a setting; the trash screen does it too).
    final shelf = DriftShelfService(db, gateway);
    try {
      await shelf.purgeOlderThan(await settings.trashRetentionDays());
    } catch (e) {
      onWarning?.call('[trash] $e'); // never blocks opening the profile
    }
    final transfer = DriftDataTransferService(db, directory, gateway: gateway);

    // P05a T7/T8 (ADR-0072): this profile's files; the ones no document
    // names any more go, never blocking the opening.
    final store = DriftAttachmentService(db,
        folder: directory.attachmentsDir(profileId), keys: directory.attachmentKeys(profileId));
    // P05b T2 (ADR-0077): each PDF kept is read for search; after the sweep,
    // the PDFs not read yet are, and the text of files gone is dropped.
    final pdfs = PdfTextIndex(db, store);
    final attachments = PdfIndexingAttachments(store, pdfs);
    // No folder yet: no file was ever kept in this profile, nothing to read.
    final fileWork = store.sweep().then((_) => store.folder.existsSync() ? pdfs.catchUp() : 0).then((_) {}, onError: (Object e) => onWarning?.call('[attachments] $e'));

    // P04 T5 (D4, D8): sync of this profile, if the build has a server. The
    // first automatic sync is not awaited: opening never waits for the
    // network (LF-INV-SEC-002).
    DriftSyncService? syncService;
    SyncScheduler? scheduler;
    SyncScheduler? spaceScheduler;
    DriftSpaceSyncService? spaceSyncService;
    DriftSharingService? sharing;
    if (sync != null) {
      final profiles = ProfileStore(db);
      final remote = sync.remoteFor(() async {
        final p = await profiles.getActiveProfile();
        if (p == null || p.signedOut) return null;
        return p.binding?.accountId;
      });
      final keyring = WorkspaceKeyring(sync.keysFor);
      syncService = DriftSyncService(
        db: db,
        gateway: gateway,
        remote: remote,
        keyring: keyring,
        transfer: transfer,
        log: (line) => onWarning?.call(line),
      );
      scheduler = SyncScheduler(
          service: syncService, when: settings.syncWhen, onError: (e) => onWarning?.call('[sync] $e'));
      unawaited(scheduler.start());
      // P04b T11 (ADR-0063, B12): the shown shared space, every minute.
      if (remote case final SpaceGateway spaces) {
        final keys = SpaceKeyService(server: spaces, keyring: keyring, slots: sync.keysFor);
        final spaceSync = DriftSpaceSyncService(
          db: db,
          gateway: gateway,
          remote: remote,
          spaces: spaces,
          keyring: keyring,
          keys: keys,
          log: (line) => onWarning?.call(line),
        );
        spaceSyncService = spaceSync;
        // P04b T13: the sharing commands of the UI (ADR-0064, ADR-0065).
        sharing = DriftSharingService(
            db: db, gateway: gateway, server: spaces, keys: keys, keyring: keyring, sync: spaceSync);
        spaceScheduler = SyncScheduler(
            service: spaceSync,
            when: settings.syncWhen,
            every: spaceSyncEvery,
            onError: (e) => onWarning?.call('[space sync] $e'));
        unawaited(spaceScheduler.start());
      }
    }
    // P06 T7 (ADR-0087): the assistant. The models and the token counts are
    // the device's (in the app's folder); the settings, the cloud choice and
    // the keys are this profile's. Nothing loads a model until it is used.
    final aiFolder = '${directory.baseDir.path}${Platform.pathSeparator}ai';
    final aiPlatform = platform == StoragePlatform.android ? LocalPlatform.android : LocalPlatform.windows;
    final aiModels = FileLocalModelService(Directory('$aiFolder${Platform.pathSeparator}models'), platform: aiPlatform);
    final aiLedger = FileAiUsageLedger(File('$aiFolder${Platform.pathSeparator}usage.json'));
    final aiKeyStore = (aiKeys ?? (id) => SecureAiKeyStore(id))(profileId);
    late final DeviceAiSetup aiSetup;
    final cloudEngine = CloudAiEngine(config: () => aiSetup.cloud(), keys: aiKeyStore, ledger: aiLedger);
    aiSetup = DeviceAiSetup(
      profileId: profileId,
      read: directory.readSetting,
      write: directory.writeSetting,
      keys: aiKeyStore,
      ledger: aiLedger,
      catalog: cloudEngine,
      models: aiModels,
      platform: aiPlatform,
    );
    final localEngine = LocalAiEngine((localRuntime ?? LlamadartRuntime.new)(), aiModels);
    final aiHistory = DriftAiHistoryService(db, gateway);
    final assistant = DriftAiAssistant(
      db: db,
      history: aiHistory,
      calendar: DriftCalendarQueries(db, agenda, limits: () => settings.limitsCache.limits),
      time: deviceTime,
      engines: [localEngine, cloudEngine],
      settings: aiSetup.settings,
    );

    return AppWiring(
      profileId: profileId,
      background: () async {
        await fileWork;
        await pdfs.idle;
        await assistant.stop();
        await localEngine.unload();
      },
      sync: scheduler,
      spaceSync: spaceScheduler,
      db: db,
      notice: notice,
      onSessionRevoked: accounts.handleSessionRevoked,
      reminders: reminderSync,
      focusLaunch: focusLaunch,
      overrides: [
        reminderServiceProvider.overrideWithValue(DriftReminderService(db, gateway)),
        reminderSchedulerProvider.overrideWithValue(reminders),
        habitServiceProvider.overrideWithValue(habits),
        focusServiceProvider.overrideWithValue(DriftFocusService(db, gateway)),
        focusQueriesProvider.overrideWithValue(DriftFocusQueries(db)),
        focusLaunchProvider.overrideWithValue(focusLaunch),
        // P05a T8 (ADR-0073): documents, one search, files on this device.
        documentServiceProvider.overrideWithValue(DriftDocumentService(db, gateway, deviceId: platform.name)),
        documentQueriesProvider.overrideWithValue(DriftDocumentQueries(db)),
        searchQueriesProvider.overrideWithValue(DriftSearchQueries(db, pdfs: pdfs)),
        attachmentServiceProvider.overrideWithValue(attachments),
        goalServiceProvider.overrideWithValue(DriftGoalService(db, gateway)),
        shelfServiceProvider.overrideWithValue(shelf),
        shelfQueriesProvider.overrideWithValue(shelf),
        overviewServiceProvider.overrideWithValue(DriftOverviewService(db, gateway)),
        overviewQueriesProvider.overrideWithValue(DriftOverviewQueries(db)),
        goalQueriesProvider.overrideWithValue(DriftGoalQueries(db, deviceTime)),
        habitQueriesProvider.overrideWithValue(DriftHabitQueries(db, deviceTime)),
        taskQueriesProvider.overrideWithValue(DriftTaskQueries(db)),
        taskServiceProvider.overrideWithValue(DriftTaskService(db, gateway)),
        profileServiceProvider
            .overrideWithValue(DirectoryProfileService(directory, host)),
        accountServiceProvider.overrideWithValue(accounts),
        dataTransferServiceProvider.overrideWithValue(transfer),
        syncServiceProvider.overrideWithValue(syncService),
        // P04b T13: spaces always (the personal one at least); sharing and
        // the space sync with a sync server.
        spaceServiceProvider.overrideWithValue(DriftSpaceService(db, gateway)),
        sharingServiceProvider.overrideWithValue(sharing),
        spaceSyncProvider.overrideWithValue(spaceSyncService),
        fileGatewayProvider.overrideWithValue(files),
        settingsServiceProvider.overrideWithValue(settings),
        taskSchedulingProvider.overrideWithValue(DriftTaskScheduling(db, gateway)),
        extraTimesProvider.overrideWithValue(DriftExtraTimes(db, gateway)),
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
        aiAssistantProvider.overrideWithValue(assistant),
        aiHistoryProvider.overrideWithValue(aiHistory),
        aiSetupProvider.overrideWithValue(aiSetup),
        aiModelFilePickerProvider.overrideWithValue(pickModelFile),
      ],
    );
  } catch (_) {
    await db.close();
    rethrow;
  }
}
