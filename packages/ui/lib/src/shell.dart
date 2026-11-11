import 'package:application/application.dart';
import 'package:flutter/material.dart';

import 'layout.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('Tasks', Icons.checklist_outlined, Icons.checklist),
  // Owner decision D9: Tasks, Calendar, Profiles, Settings.
  _Destination('Calendar', Icons.calendar_month_outlined, Icons.calendar_month),
  // P03 D12: Goals is the 5th tab, before Profiles and Settings.
  _Destination('Goals', Icons.flag_outlined, Icons.flag),
  _Destination('Profiles', Icons.people_outline, Icons.people),
  _Destination('Settings', Icons.settings_outlined, Icons.settings),
];

/// The branch index of Profiles: in the compact layout it is the drawer's
/// header, not one of its destinations.
const profilesIndex = 3;

/// Lets a tab's app bar open the shell's navigation drawer. [open] is null
/// when the layout has no drawer (rail layouts).
class ShellMenuScope extends InheritedWidget {
  const ShellMenuScope({super.key, required this.open, required super.child});
  final VoidCallback? open;

  static ShellMenuScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellMenuScope>();

  @override
  bool updateShouldNotify(ShellMenuScope oldWidget) => (open == null) != (oldWidget.open == null);
}

/// The menu button for a tab's app bar `leading`: only in the compact
/// layout, where the navigation is in a drawer. Null otherwise.
Widget? shellMenuButton(BuildContext context) {
  final open = ShellMenuScope.maybeOf(context)?.open;
  if (open == null) return null;
  return IconButton(
    key: const Key('nav-menu'),
    tooltip: 'Open navigation menu',
    icon: const Icon(Icons.menu),
    onPressed: open,
  );
}

/// Adaptive shell driven by window width (ui-ux-architecture.md section 2):
/// compact = a navigation drawer (the whole height stays for the content;
/// the profile is the drawer's header), medium = navigation rail with
/// labels, expanded = extended navigation rail. The same routes serve every
/// class. Pure widget (no router, no providers) so it is testable in
/// isolation.
class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.notice,
    this.focusBar,
    this.profile,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  /// Startup at-rest encryption notice (ADR-0021); shown above the content.
  final StorageNotice? notice;

  /// Shown under the content, above the navigation (P03 D4).
  final Widget? focusBar;

  /// The active profile, shown in the drawer's header.
  final ProfileView? profile;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  final _scaffold = GlobalKey<ScaffoldState>();

  void _go(int index) {
    _scaffold.currentState?.closeDrawer();
    widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final selectedIndex = widget.selectedIndex;
    final onSelected = widget.onSelected;
    final focusBar = widget.focusBar;
    return LayoutBuilder(builder: (context, constraints) {
      final layout = layoutClassFor(constraints.maxWidth);
      final showBanner = notice?.needsAttention ?? false;
      final compact = layout == LayoutClass.compact;
      final content = ShellMenuScope(
        open: compact ? () => _scaffold.currentState?.openDrawer() : null,
        child: Column(
          children: [
            if (showBanner)
              SafeArea(bottom: false, child: StorageBanner(notice: notice!)),
            Expanded(
              // The banner already absorbed the status-bar inset.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: showBanner,
                child: widget.body,
              ),
            ),
            if (focusBar != null) focusBar,
          ],
        ),
      );

      if (compact) {
        final drawerDestinations = [for (var i = 0; i < _destinations.length; i++) if (i != profilesIndex) i];
        final drawerIndex = drawerDestinations.indexOf(selectedIndex);
        return Scaffold(
          key: _scaffold,
          body: content,
          drawer: NavigationDrawer(
            key: const Key('nav-drawer'),
            selectedIndex: drawerIndex < 0 ? null : drawerIndex,
            onDestinationSelected: (i) => _go(drawerDestinations[i]),
            children: [
              DrawerProfileHeader(
                profile: widget.profile,
                selected: selectedIndex == profilesIndex,
                onTap: () => _go(profilesIndex),
              ),
              const SizedBox(height: 12),
              for (final i in drawerDestinations)
                NavigationDrawerDestination(
                  icon: Icon(_destinations[i].icon),
                  selectedIcon: Icon(_destinations[i].selectedIcon),
                  label: Text(_destinations[i].label),
                ),
            ],
          ),
        );
      }

      final extended = layout == LayoutClass.expanded;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected,
                extended: extended,
                labelType:
                    extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    });
  }
}

/// The top of the navigation drawer: the active profile, with its picture
/// (initials until profiles have a photo), its name and how it is signed in.
/// A tap opens Profiles (switch, sign in, manage).
class DrawerProfileHeader extends StatelessWidget {
  const DrawerProfileHeader({super.key, required this.profile, required this.onTap, this.selected = false});
  final ProfileView? profile;
  final VoidCallback onTap;
  final bool selected;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final second = words.length > 1 ? words.last.characters.first : '';
    return (first + second).toUpperCase();
  }

  static String statusOf(ProfileView p) {
    if (!p.isBound) return 'Guest · on this device';
    final provider = switch (p.provider) {
      null => 'an account',
      'github' => 'GitHub',
      'google' => 'Google',
      final other => other,
    };
    return p.isSignedOut ? 'Signed out of $provider' : 'Signed in with $provider';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = profile;
    final name = p?.displayName ?? 'Profile';
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: 'Profile: $name${p == null ? '' : ', ${statusOf(p)}'}. Open profiles',
      excludeSemantics: true,
      child: Material(
        key: const Key('drawer-profile'),
        color: scheme.primaryContainer,
        child: InkWell(
          onTap: onTap,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(initialsOf(name), style: text.headlineSmall?.copyWith(color: scheme.onPrimary)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
                      if (p != null)
                        Text(statusOf(p),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-silent at-rest encryption warning (ADR-0021, SR-01a). The sanctioned
/// Windows-MVP exception is styled as a caution; an unexpected unencrypted
/// state is styled as an error.
class StorageBanner extends StatelessWidget {
  const StorageBanner({super.key, required this.notice});
  final StorageNotice notice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tracked = notice.trackedException;
    final background = tracked ? scheme.tertiaryContainer : scheme.errorContainer;
    final foreground =
        tracked ? scheme.onTertiaryContainer : scheme.onErrorContainer;
    final message = notice.message ?? '';
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Storage warning. $message',
      child: Material(
        key: const Key('storage-banner'),
        color: background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                  child: Icon(Icons.warning_amber_rounded, color: foreground)),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(message, style: TextStyle(color: foreground)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
