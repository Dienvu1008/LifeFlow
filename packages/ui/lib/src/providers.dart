import 'package:application/application.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

// Ports are supplied by the composition root (apps/lifeflow_app) through
// ProviderScope overrides. The UI never builds an implementation itself
// (ADR-0019, FF-ARCH-04).
Never _notWired(String name) =>
    throw UnimplementedError('$name must be overridden in the composition root');

final taskQueriesProvider =
    Provider<TaskQueries>((ref) => _notWired('taskQueriesProvider'));
final taskServiceProvider =
    Provider<TaskService>((ref) => _notWired('taskServiceProvider'));
final profileServiceProvider =
    Provider<ProfileService>((ref) => _notWired('profileServiceProvider'));
final accountServiceProvider =
    Provider<AccountService>((ref) => _notWired('accountServiceProvider'));
final dataTransferServiceProvider = Provider<DataTransferService>(
    (ref) => _notWired('dataTransferServiceProvider'));
final fileGatewayProvider =
    Provider<FileGateway>((ref) => _notWired('fileGatewayProvider'));
final settingsServiceProvider =
    Provider<SettingsService>((ref) => _notWired('settingsServiceProvider'));

final reminderServiceProvider = Provider<ReminderService>((ref) => _notWired('reminderServiceProvider'));

/// The device's notifications (status and permission; scheduling is done by
/// the app's reminder sync, never by the UI).
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => _notWired('reminderSchedulerProvider'));

/// What the device allows for reminders. Invalidate after asking.
final reminderStatusProvider = FutureProvider.autoDispose<ReminderStatus>(
  (ref) => ref.watch(reminderSchedulerProvider).status(),
);

final taskSchedulingProvider =
    Provider<TaskScheduling>((ref) => _notWired('taskSchedulingProvider'));
final agendaQueriesProvider =
    Provider<AgendaQueries>((ref) => _notWired('agendaQueriesProvider'));
final zoneCatalogProvider =
    Provider<ZoneCatalog>((ref) => _notWired('zoneCatalogProvider'));

final eventServiceProvider = Provider<EventService>((ref) => _notWired('eventServiceProvider'));
final calendarServiceProvider = Provider<CalendarService>((ref) => _notWired('calendarServiceProvider'));
final calendarQueriesProvider = Provider<CalendarQueries>((ref) => _notWired('calendarQueriesProvider'));

/// The calendars of the ACTIVE profile.
final calendarsProvider = StreamProvider.autoDispose<List<CalendarView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(calendarServiceProvider).watchCalendars();
});

/// Events, scheduled tasks and conflicts of from..to (inclusive), for the
/// calendar views of the ACTIVE profile.
final calendarRangeProvider =
    StreamProvider.autoDispose.family<CalendarRange, ({LocalDate from, LocalDate to})>((ref, r) {
  ref.watch(activeProfileProvider);
  ref.watch(showArchivedScheduledProvider);
  return ref.watch(calendarQueriesProvider).watchRange(r.from, r.to);
});

/// P06b W6 (ADR-0094): whether archived items that are scheduled still show on
/// the Calendar and the Timeline (a setting of this device; no by default).
/// Changing it re-reads the calendar's ranges and the agendas.
final showArchivedScheduledProvider = StateNotifierProvider<ShowArchivedScheduled, bool>((ref) {
  SettingsService? settings;
  try {
    settings = ref.watch(settingsServiceProvider);
  } on UnimplementedError {
    settings = null;
  }
  return ShowArchivedScheduled(settings);
});

class ShowArchivedScheduled extends StateNotifier<bool> {
  ShowArchivedScheduled(this._settings) : super(false) {
    _settings?.showArchivedScheduled().then((v) {
      if (mounted && !_touched) state = v;
    }, onError: (Object _) {});
  }
  final SettingsService? _settings;
  var _touched = false;

  Future<void> set(bool show) async {
    _touched = true;
    // The setting first: the queries read it when the ranges are asked again.
    await _settings?.setShowArchivedScheduled(show);
    if (mounted) state = show;
  }
}

/// The archive and the trash of the shown space.
final shelfServiceProvider = Provider<ShelfService>((ref) => _notWired('shelfServiceProvider'));
final shelfQueriesProvider = Provider<ShelfQueries>((ref) => _notWired('shelfQueriesProvider'));

/// What is archived, and what is in the trash. Invalidate after a change.
final archivedEntriesProvider = FutureProvider.autoDispose<List<ShelfEntry>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(shelfQueriesProvider).archived();
});
final trashedEntriesProvider = FutureProvider.autoDispose<List<ShelfEntry>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(shelfQueriesProvider).trashed();
});

/// The days the trash keeps an item (a setting of this device).
final trashRetentionDaysProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(settingsServiceProvider).trashRetentionDays(),
);
/// The device's IANA zone: the default zone of new timed items (D10).
final deviceZoneProvider = Provider<String>((ref) => 'UTC');

/// Calendar settings of this device (D1–D3). Invalidate after changing them.
final planningSettingsProvider = FutureProvider.autoDispose<PlanningSettings>(
  (ref) => ref.watch(settingsServiceProvider).planningSettings(),
);

/// Today's date on this device, for labels such as "Tomorrow". A function so
/// it never goes stale after midnight; tests override it.
final todayProvider = Provider<LocalDate Function()>((ref) => () {
      final n = DateTime.now();
      return LocalDate(n.year, n.month, n.day);
    });

/// The device's local date and time now, for the calendar's now line
/// (P03 UX U5). A function, like [todayProvider]; tests override it.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);


/// Today's agenda of the ACTIVE profile (re-subscribed on a profile switch).
final todayAgendaProvider = StreamProvider.autoDispose<Agenda>((ref) {
  ref.watch(activeProfileProvider);
  ref.watch(showArchivedScheduledProvider);
  return ref.watch(agendaQueriesProvider).watchToday();
});

/// The next 14 days after today.
final upcomingAgendaProvider = StreamProvider.autoDispose<Agenda>((ref) {
  ref.watch(activeProfileProvider);
  ref.watch(showArchivedScheduledProvider);
  return ref.watch(agendaQueriesProvider).watchUpcoming();
});

/// What happens to subtasks when their parent goes to the trash (device
/// setting). Invalidate after changing it.
final subtaskTrashPolicyProvider = FutureProvider.autoDispose<SubtaskTrashPolicy>(
  (ref) => ref.watch(settingsServiceProvider).subtaskTrashPolicy(),
);

/// Where a freshly opened profile session starts. The app shell sets
/// '/profiles' after a sign-out (OQ-S7: back to the profile chooser).
final initialRouteProvider = Provider<String>((ref) => '/overview');

/// Startup at-rest encryption result (ADR-0021). Null = nothing to show.
final storageNoticeProvider = Provider<StorageNotice?>((ref) => null);

/// The profile whose data the app is showing. Invalidate after a switch.
final activeProfileProvider = FutureProvider.autoDispose<ProfileView?>(
  (ref) => ref.watch(profileServiceProvider).active(),
);

/// Whether the active profile can go back to its state before the last
/// restore (ADR-0025). Invalidate after a restore or an undo.
final canUndoRestoreProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(dataTransferServiceProvider).canUndoRestore(),
);

/// Every profile on the device, for the chooser (OQ-S7).
final profilesProvider = FutureProvider.autoDispose<List<ProfileView>>(
  (ref) => ref.watch(profileServiceProvider).list(),
);

/// Tasks of the ACTIVE profile. It watches [activeProfileProvider] so the
/// stream is re-subscribed (and re-scoped) whenever the profile changes
/// (LF-INV-ID-002).
final tasksProvider = StreamProvider.autoDispose<List<TaskView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(taskQueriesProvider).watchTasks();
});

// --- P03 T6a: habits, targets and measurements (ADR-0039/0041) -------------

final habitServiceProvider = Provider<HabitService>((ref) => _notWired('habitServiceProvider'));
final habitQueriesProvider = Provider<HabitQueries>((ref) => _notWired('habitQueriesProvider'));

/// The habits of the ACTIVE profile (the Habits filter).
final habitsProvider = StreamProvider.autoDispose<List<TrackingView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(habitQueriesProvider).watchHabits();
});

/// Every tracked task (habit or target) by task id: period states in the
/// task lists and the agenda. Empty while loading or when not wired.
final trackedProvider = StreamProvider.autoDispose<Map<String, TrackingView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(habitQueriesProvider).watchTracked().map((l) => {for (final v in l) v.taskId: v});
});

/// One task's tracking (the habit page).
final trackingProvider = StreamProvider.autoDispose.family<TrackingView?, String>((ref, taskId) {
  ref.watch(activeProfileProvider);
  return ref.watch(habitQueriesProvider).watchTracking(taskId);
});

// --- P03 T6b: focus sessions (ADR-0038/0042) --------------------------------

final focusServiceProvider = Provider<FocusService>((ref) => _notWired('focusServiceProvider'));
final focusQueriesProvider = Provider<FocusQueries>((ref) => _notWired('focusQueriesProvider'));

/// What was found when this profile opened (D1). The app sets it; the
/// shell asks the user once.
final focusLaunchProvider = Provider<FocusLaunch>((ref) => const NoActiveFocus());

/// The running or paused session of the ACTIVE profile, or null.
final activeFocusProvider = StreamProvider.autoDispose<FocusSessionView?>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(focusQueriesProvider).watchActive();
});

/// "Now" for the focus displays (tests set it).
final focusClockProvider = Provider<Instant Function()>((ref) => Instant.now);

/// Redraws the running time. Only the display ticks: the time itself is
/// derived from the stored instants (LF-INV-EXEC-002). Tests replace it.
/// A new stream per display, so each one's timer stops with it.
final focusTickerProvider =
    Provider<Stream<void> Function()>((ref) => () => Stream<void>.periodic(const Duration(seconds: 1)));

// --- P03 T6c: goals and projects (ADR-0040/0043) ---------------------------

final goalServiceProvider = Provider<GoalService>((ref) => _notWired('goalServiceProvider'));
final goalQueriesProvider = Provider<GoalQueries>((ref) => _notWired('goalQueriesProvider'));

/// The goals of the ACTIVE profile (archived ones only when asked).
final goalsProvider = StreamProvider.autoDispose.family<List<GoalView>, bool>((ref, includeArchived) {
  ref.watch(activeProfileProvider);
  return ref.watch(goalQueriesProvider).watchGoals(includeArchived: includeArchived);
});

/// Goals in the trash. Invalidate after a trash or a restore.
final trashedGoalsProvider = FutureProvider.autoDispose<List<GoalView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(goalQueriesProvider).trashed();
});

// --- P05a T8: documents (ADR-0073; p05-plan.md C4–C11) ----------------------

final documentServiceProvider = Provider<DocumentService>((ref) => _notWired('documentServiceProvider'));
final documentQueriesProvider = Provider<DocumentQueries>((ref) => _notWired('documentQueriesProvider'));
final searchQueriesProvider = Provider<SearchQueries>((ref) => _notWired('searchQueriesProvider'));
final attachmentServiceProvider = Provider<AttachmentService>((ref) => _notWired('attachmentServiceProvider'));

/// The documents of the shown workspace, in tree order.
final documentTreeProvider = StreamProvider.autoDispose<List<DocumentNodeView>>((ref) {
  ref.watch(activeProfileProvider);
  ref.watch(spacesProvider);
  return ref.watch(documentQueriesProvider).watchTree();
});

/// Documents in the trash. Invalidate after a trash or a restore.
final trashedDocumentsProvider = FutureProvider.autoDispose<List<DocumentNodeView>>((ref) {
  ref.watch(activeProfileProvider);
  ref.watch(documentTreeProvider);
  return ref.watch(documentQueriesProvider).trashed();
});

/// The documents linked to a task, an event or a goal (its page).
final itemDocumentsProvider =
    FutureProvider.autoDispose.family<List<DocumentNodeView>, ({DocumentItemType type, String id})>((ref, item) {
  ref.watch(documentTreeProvider);
  return ref.watch(documentQueriesProvider).documentsOf(item.type, item.id);
});

// --- P03 UX U1: appearance (ADR-0045) ---------------------------------------

/// Light, dark or as the system (device setting). Invalidate after a change.
final themePreferenceProvider = FutureProvider<ThemePreference>(
  (ref) => ref.watch(settingsServiceProvider).themePreference(),
);

// --- P03 UX U3: the Overview (ADR-0046/0047) --------------------------------

final overviewServiceProvider = Provider<OverviewService>((ref) => _notWired('overviewServiceProvider'));
final overviewQueriesProvider = Provider<OverviewQueries>((ref) => _notWired('overviewQueriesProvider'));

/// The lists of the ACTIVE profile, in order.
final listsProvider = StreamProvider.autoDispose<List<TaskListView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(overviewQueriesProvider).watchLists();
});

/// The events of the ACTIVE profile with their list, colour and order.
final overviewEventsProvider = StreamProvider.autoDispose<List<OverviewEventView>>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(overviewQueriesProvider).watchEvents();
});

/// The lists and tasks collapsed in the Overview (device setting). Loaded
/// once, then changed here and written through, so a toggle is instant.
class CollapsedItems extends StateNotifier<Set<String>> {
  CollapsedItems(this._settings) : super(const {}) {
    _settings?.collapsedItems().then((v) {
      if (mounted && !_touched) state = v;
    }, onError: (Object _) {});
  }

  /// Null where no settings are wired (isolated widget tests).
  final SettingsService? _settings;
  var _touched = false;

  void toggle(String id) => _set(state.contains(id) ? ({...state}..remove(id)) : {...state, id});

  /// Shows [id]'s contents (after a drop into it or a new child).
  void expand(String id) {
    if (state.contains(id)) _set({...state}..remove(id));
  }

  void _set(Set<String> next) {
    _touched = true;
    state = next;
    _settings?.setCollapsedItems(next).catchError((Object _) {});
  }
}

final collapsedItemsProvider = StateNotifierProvider<CollapsedItems, Set<String>>(
    (ref) {
  SettingsService? settings;
  try {
    settings = ref.watch(settingsServiceProvider);
  } on UnimplementedError {
    settings = null;
  }
  return CollapsedItems(settings);
});
/// U-D13 (ADR-0050): the ACTIVE profile's result policy for measured tasks
/// completed by hand. Invalidate after a change.
final manualResultsProvider = FutureProvider.autoDispose<ManualResults>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(habitQueriesProvider).manualResults();
});

/// Dogfooding O1/O3 (ADR-0051): drag handles, font and text size of this
/// device. Invalidate after a change.
final appearanceProvider = FutureProvider<AppearanceSettings>(
  (ref) => ref.watch(settingsServiceProvider).appearance(),
);

// --- P04 T5: sync (ADR-0058; p04-plan.md D8, D9) ---------------------------

/// Sync of the ACTIVE profile with the signed-in account. Null where the
/// build has no sync server (no Supabase defines) or in widget tests that do
/// not need it: the UI then shows sync as unavailable.
final syncServiceProvider = Provider<SyncService?>((ref) => null);

/// The sync status of the ACTIVE profile, live; null without sync.
final syncStatusProvider = StreamProvider.autoDispose<SyncStatus?>((ref) {
  ref.watch(activeProfileProvider);
  final sync = ref.watch(syncServiceProvider);
  if (sync == null) return Stream.value(null);
  return sync.watchStatus();
});

/// "Changes to review", read again whenever the status changes.
final syncReviewsProvider = FutureProvider.autoDispose<List<SyncReviewView>>((ref) async {
  final status = ref.watch(syncStatusProvider).valueOrNull;
  final sync = ref.watch(syncServiceProvider);
  if (sync == null || status == null || !status.on) return const [];
  return sync.reviews();
});

/// "When to sync" of this device (D8). Invalidate after a change.
final syncWhenProvider = FutureProvider.autoDispose<SyncWhen>(
  (ref) => ref.watch(settingsServiceProvider).syncWhen(),
);

// --- P04b T13: shared spaces (ADR-0065; p04b-plan.md B1–B14) --------------

/// The spaces of the ACTIVE profile and which one is shown. Null where the
/// app has none wired (widget tests that do not need it).
final spaceServiceProvider = Provider<SpaceService?>((ref) => null);

/// Sharing (needs an account and sync on, B5). Null without a sync server.
final sharingServiceProvider = Provider<SharingService?>((ref) => null);

/// The shown space's sync (every minute, B12); the UI asks for a sync right
/// after showing a space. Null without a sync server.
final spaceSyncProvider = Provider<SpaceSyncRunner?>((ref) => null);

/// The space sync's status: it changes after each refresh, so the spaces
/// are read again (a space someone let this account into appears).
final spaceSyncStatusProvider = StreamProvider.autoDispose<SyncStatus?>((ref) {
  ref.watch(activeProfileProvider);
  final sync = ref.watch(spaceSyncProvider);
  if (sync == null) return Stream.value(null);
  return sync.watchStatus();
});

/// The shown space's "Changes to review" (T14 finding 2), read again
/// whenever the space sync's status changes.
final spaceReviewsProvider = FutureProvider.autoDispose<List<SyncReviewView>>((ref) async {
  final status = ref.watch(spaceSyncStatusProvider).valueOrNull;
  final sync = ref.watch(spaceSyncProvider);
  if (sync == null || status == null || status.reviews == 0) return const [];
  return sync.reviews();
});

/// The spaces of the ACTIVE profile: the personal one first.
final spacesProvider = FutureProvider.autoDispose<List<SpaceView>>((ref) async {
  ref.watch(activeProfileProvider);
  ref.watch(spaceSyncStatusProvider);
  final spaces = ref.watch(spaceServiceProvider);
  if (spaces == null) return const [];
  return spaces.spaces();
});

/// The shown space, if it is a shared one.
final shownSharedSpaceProvider = Provider.autoDispose<SpaceView?>((ref) {
  final list = ref.watch(spacesProvider).valueOrNull ?? const <SpaceView>[];
  return list.where((s) => s.isShown && s.shared).firstOrNull;
});

/// Whether this profile may change what is shown: not in a space it only
/// views, nor in a copy left after leaving (B4, B8).
final canEditShownProvider = Provider.autoDispose<bool>((ref) {
  final s = ref.watch(shownSharedSpaceProvider);
  return s == null || (s.role != SpaceRole.viewer && s.left == SpaceLeft.no);
});

/// This profile's account id (to find "me" among members and assignees).
final myAccountProvider = FutureProvider.autoDispose<String?>((ref) async {
  ref.watch(activeProfileProvider);
  return ref.watch(sharingServiceProvider)?.myAccountId();
});

/// The names of a space's members known here (ADR-0065), by account id.
final memberNamesProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, spaceId) async {
  ref.watch(spacesProvider);
  return await ref.watch(sharingServiceProvider)?.memberNames(spaceId) ?? const {};
});

/// A space's members as the server says; read again after each change.
final spaceMembersProvider = FutureProvider.autoDispose.family<List<SpaceMemberView>, String>((ref, spaceId) async {
  ref.watch(spacesProvider);
  return await ref.watch(sharingServiceProvider)?.members(spaceId) ?? const [];
});

/// Spaces whose rules changed since this device showed them (SHARE-005).
final rulesNoticesProvider = FutureProvider.autoDispose<List<RulesNotice>>((ref) async {
  ref.watch(spacesProvider);
  return await ref.watch(sharingServiceProvider)?.rulesNotices() ?? const [];
});

/// "Assigned to me" in the Overview of a shared space (B9).
final assignedToMeProvider = StateProvider<bool>((ref) => false);

// --- P06 T7: the assistant (ADR-0087) -------------------------------------

/// The assistant's turns. Null where the app has none wired (then no entry
/// to it is shown).
final aiAssistantProvider = Provider<AiAssistant?>((ref) => null);

/// The assistant's history and the approval of its proposals.
final aiHistoryProvider = Provider<AiHistoryService?>((ref) => null);

/// The assistant's settings, models and cloud choice.
final aiSetupProvider = Provider<AiSetupService?>((ref) => null);

/// Opens the app's file dialog for a GGUF model and gives its path; null
/// where the build has none (the path is typed instead).
final aiModelFilePickerProvider = Provider<Future<String?> Function()?>((ref) => null);

/// The live conversations of the ACTIVE profile, newest first. Invalidate
/// after a turn or a delete.
final aiSessionsProvider = FutureProvider.autoDispose<List<AiSessionView>>((ref) async {
  ref.watch(activeProfileProvider);
  final h = ref.watch(aiHistoryProvider);
  return h == null ? const [] : h.sessions();
});
