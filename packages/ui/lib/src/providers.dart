import 'package:application/application.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Startup at-rest encryption result (ADR-0021). Null = nothing to show.
final storageNoticeProvider = Provider<StorageNotice?>((ref) => null);

/// The profile whose data the app is showing. Invalidate after a switch.
final activeProfileProvider = FutureProvider.autoDispose<ProfileView?>(
  (ref) => ref.watch(profileServiceProvider).active(),
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
