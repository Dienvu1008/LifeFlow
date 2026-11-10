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
  _Destination('Profiles', Icons.people_outline, Icons.people),
  _Destination('Settings', Icons.settings_outlined, Icons.settings),
];

/// Adaptive shell driven by window width (ui-ux-architecture.md §2):
/// compact = bottom navigation, medium = navigation rail with labels,
/// expanded = extended navigation rail. The same routes serve every class.
/// Pure widget (no router, no providers) so it is testable in isolation.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.notice,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  /// Startup at-rest encryption notice (ADR-0021); shown above the content.
  final StorageNotice? notice;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final layout = layoutClassFor(constraints.maxWidth);
      final showBanner = notice?.needsAttention ?? false;
      final content = Column(
        children: [
          if (showBanner)
            SafeArea(bottom: false, child: StorageBanner(notice: notice!)),
          Expanded(
            // The banner already absorbed the status-bar inset.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: showBanner,
              child: body,
            ),
          ),
        ],
      );

      if (layout == LayoutClass.compact) {
        return Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
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
