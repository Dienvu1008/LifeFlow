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
  return ref.watch(calendarQueriesProvider).watchRange(r.from, r.to);
});

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

/// Which tasks the Tasks tab shows (D9: Today and Upcoming are filters of
/// Tasks; the Calendar tab can switch to them).
enum TaskFilter { all, today, upcoming, habits }

final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);

/// Today's agenda of the ACTIVE profile (re-subscribed on a profile switch).
final todayAgendaProvider = StreamProvider.autoDispose<Agenda>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(agendaQueriesProvider).watchToday();
});

/// The next 14 days after today.
final upcomingAgendaProvider = StreamProvider.autoDispose<Agenda>((ref) {
  ref.watch(activeProfileProvider);
  return ref.watch(agendaQueriesProvider).watchUpcoming();
});

/// What happens to subtasks when their parent goes to the trash (device
/// setting). Invalidate after changing it.
final subtaskTrashPolicyProvider = FutureProvider.autoDispose<SubtaskTrashPolicy>(
  (ref) => ref.watch(settingsServiceProvider).subtaskTrashPolicy(),
);

/// Where a freshly opened profile session starts. The app shell sets
/// '/profiles' after a sign-out (OQ-S7: back to the profile chooser).
final initialRouteProvider = Provider<String>((ref) => '/tasks');

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
