import 'package:application/application.dart';
import 'package:flutter/material.dart';

import 'layout.dart';
import 'l10n.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// P03 UX U6 (ADR-0050): Overview, Timeline, Calendar, Habits, Goals,
/// Settings. Profiles is a branch too, but it is reached from the profile at
/// the top of the drawer or the rail, not from a destination.
List<_Destination> _destinationsOf(BuildContext context) {
  final l = context.l10n;
  return [
    _Destination(l.navOverview, Icons.checklist_outlined, Icons.checklist),
    _Destination(l.navTimeline, Icons.view_timeline_outlined, Icons.view_timeline),
    _Destination(l.navCalendar, Icons.calendar_month_outlined, Icons.calendar_month),
    _Destination(l.navHabits, Icons.track_changes_outlined, Icons.track_changes),
    _Destination(l.navGoals, Icons.flag_outlined, Icons.flag),
    _Destination(l.navSettings, Icons.settings_outlined, Icons.settings),
  ];
}

/// The branch index of Profiles (after the six destinations).
const profilesIndex = 6;
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
    tooltip: context.l10n.openNavigationMenu,
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
        final destinations = _destinationsOf(context);
        return Scaffold(
          key: _scaffold,
          body: content,
          drawer: NavigationDrawer(
            key: const Key('nav-drawer'),
            selectedIndex: selectedIndex < destinations.length ? selectedIndex : null,
            onDestinationSelected: _go,
            children: [
              DrawerProfileHeader(
                profile: widget.profile,
                selected: selectedIndex == profilesIndex,
                onTap: () => _go(profilesIndex),
              ),
              const SizedBox(height: 12),
              for (final d in destinations)
                NavigationDrawerDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
        );
      }

      final extended = layout == LayoutClass.expanded;
      final destinations = _destinationsOf(context);
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: selectedIndex < destinations.length ? selectedIndex : null,
                onDestinationSelected: onSelected,
                // The profile on top, as in the drawer (opens Profiles).
                leading: RailProfileButton(
                  profile: widget.profile,
                  selected: selectedIndex == profilesIndex,
                  onTap: () => onSelected(profilesIndex),
                ),
                extended: extended,
                labelType:
                    extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
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
      label: p == null ? context.l10n.drawerProfileLabel(name) : context.l10n.drawerProfileLabelWithStatus(name, statusOf(p)),
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

/// The profile at the top of the rail: its initials; a tap opens Profiles.
class RailProfileButton extends StatelessWidget {
  const RailProfileButton({super.key, required this.profile, required this.onTap, this.selected = false});
  final ProfileView? profile;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = profile;
    final name = p?.displayName ?? context.l10n.navProfiles;
    final label = p == null
        ? context.l10n.drawerProfileLabel(name)
        : context.l10n.drawerProfileLabelWithStatus(name, DrawerProfileHeader.statusOf(p));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            key: const Key('rail-profile'),
            onTap: onTap,
            radius: 28,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: selected ? scheme.primary : scheme.primaryContainer,
              foregroundColor: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
              child: Text(DrawerProfileHeader.initialsOf(name)),
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
      label: context.l10n.storageWarningMessage(message),
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
