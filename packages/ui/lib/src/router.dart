import 'package:application/application.dart' show ThemePreference;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'l10n.dart';
import 'theme/lifeflow_theme.dart';

import 'providers.dart';
import 'screens/calendar_screen.dart';
import 'screens/focus_page.dart';
import 'screens/goals_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tasks_screen.dart';
import 'shell.dart';

/// One route table for every layout class (ui-ux-architecture.md §3). The
/// shell (bottom bar vs rail) differs; the routes do not.
/// Top-level destinations. Anything else (for example "/" or an OS-delivered
/// link such as an OAuth callback) is redirected to the task list, so the app
/// never replaces itself with a "Page Not Found" screen.
const _knownRoots = ['/tasks', '/calendar', '/goals', '/profiles', '/settings'];

String? _redirectUnknown(GoRouterState state) {
  final path = state.uri.path;
  final known = _knownRoots
      .any((root) => path == root || path.startsWith('$root/'));
  return known ? null : '/tasks';
}

GoRouter createRouter({String initialLocation = '/tasks'}) => GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) => _redirectUnknown(state),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Consumer(
            builder: (context, ref, _) => AdaptiveScaffold(
              selectedIndex: shell.currentIndex,
              onSelected: (i) =>
                  shell.goBranch(i, initialLocation: i == shell.currentIndex),
              notice: ref.watch(storageNoticeProvider),
              profile: ref.watch(activeProfileProvider).valueOrNull,
              // P03 T6b (D1, D4): the focus bar on every screen, and the
              // question about a session found at start.
              focusBar: const FocusBar(),
              body: FocusLaunchPrompt(child: shell),
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
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ]),
            // P03 D12: the 5th tab.
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/profiles',
                builder: (context, state) => const ProfilesScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ]),
          ],
        ),
      ],
    );

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(initialLocation: ref.watch(initialRouteProvider));
  ref.onDispose(router.dispose);
  return router;
});

/// Root widget. Ports are injected by the composition root through
/// ProviderScope overrides (see providers.dart).
class LifeFlowApp extends ConsumerWidget {
  const LifeFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // P03 UX U1 (ADR-0045): one theme module; the brightness follows the
    // device setting (System by default, also while it loads).
    final preference = ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.system;
    return MaterialApp.router(
      title: 'LifeFlow',
      routerConfig: ref.watch(routerProvider),
      // U-D11: English only for now; a new ARB file adds a language.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lifeFlowTheme(Brightness.light),
      darkTheme: lifeFlowTheme(Brightness.dark),
      themeMode: switch (preference) {
        ThemePreference.system => ThemeMode.system,
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      },
    );
  }
}
