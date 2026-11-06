import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'screens/profiles_screen.dart';
import 'screens/tasks_screen.dart';
import 'shell.dart';

/// One route table for every layout class (ui-ux-architecture.md §3). The
/// shell (bottom bar vs rail) differs; the routes do not.
GoRouter createRouter({String initialLocation = '/tasks'}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Consumer(
            builder: (context, ref, _) => AdaptiveScaffold(
              selectedIndex: shell.currentIndex,
              onSelected: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              notice: ref.watch(storageNoticeProvider),
              body: shell,
            ),
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => const TasksScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profiles',
                builder: (context, state) => const ProfilesScreen(),
              ),
            ]),
          ],
        ),
      ],
    );

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// Root widget. Ports are injected by the composition root through
/// ProviderScope overrides (see providers.dart).
class LifeFlowApp extends ConsumerWidget {
  const LifeFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const seed = Colors.teal;
    return MaterialApp.router(
      title: 'LifeFlow',
      routerConfig: ref.watch(routerProvider),
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
    );
  }
}
