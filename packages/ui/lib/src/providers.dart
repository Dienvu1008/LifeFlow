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

final taskSchedulingProvider =
    Provider<TaskScheduling>((ref) => _notWired('taskSchedulingProvider'));
final agendaQueriesProvider =
    Provider<AgendaQueries>((ref) => _notWired('agendaQueriesProvider'));
final zoneCatalogProvider =
    Provider<ZoneCatalog>((ref) => _notWired('zoneCatalogProvider'));

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
enum TaskFilter { all, today, upcoming }

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
