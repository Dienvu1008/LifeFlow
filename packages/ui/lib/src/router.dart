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
/// shell (drawer vs rail) differs; the routes do not.
/// P03 UX U6 (ADR-0050): Overview, Timeline, Calendar, Habits, Goals,
/// Settings, then Profiles (reached from the profile in the drawer or rail).
/// Anything else (for example "/" or an OS-delivered link such as an OAuth
/// callback) goes to the Overview, so the app never replaces itself with a
/// "Page Not Found" screen. The old "/tasks" (P01–P03 links and the shell's
/// first location until U6) is the Overview.
const _knownRoots = ['/overview', '/timeline', '/calendar', '/habits', '/goals', '/settings', '/profiles'];

String? _redirectUnknown(GoRouterState state) {
  final path = state.uri.path;
  final known = _knownRoots.any((root) => path == root || path.startsWith('$root/'));
  return known ? null : '/overview';
}
GoRouter createRouter({String initialLocation = '/overview'}) => GoRouter(
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
            for (final (path, screen) in const [
              ('/overview', OverviewScreen()),
              ('/timeline', TimelineScreen()),
              ('/calendar', CalendarScreen()),
              ('/habits', HabitsScreen()),
              ('/goals', GoalsScreen()),
              ('/settings', SettingsScreen()),
              ('/profiles', ProfilesScreen()),
            ])
              StatefulShellBranch(routes: [GoRoute(path: path, builder: (context, state) => screen)]),
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
