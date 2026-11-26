// P06b W2 (owner UI 1): every main screen's app bar ends with one options
// menu, and Search is always its first entry. A screen adds its own entries
// below Search.
import 'package:flutter/material.dart';

import '../l10n.dart';
import '../search/search_page.dart' show openSearch;

/// One entry of an [OptionsMenu].
class MenuOption {
  const MenuOption({required this.label, required this.onSelected, this.key, this.icon});
  final Key? key;
  final String label;
  final IconData? icon;
  final VoidCallback onSelected;
}

/// The app bar's options menu: Search, then [options].
class OptionsMenu extends StatelessWidget {
  const OptionsMenu({super.key = const Key('screen-options'), this.options = const [], this.tooltip});
  final List<MenuOption> options;

  /// Defaults to "More options".
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = [
      MenuOption(key: const Key('options-search'), label: l.search, icon: Icons.search, onSelected: () => openSearch(context)),
      ...options,
    ];
    return PopupMenuButton<int>(
      tooltip: tooltip ?? l.moreOptions,
      onSelected: (i) => all[i].onSelected(),
      itemBuilder: (_) => [
        for (final (i, o) in all.indexed)
          PopupMenuItem(
            key: o.key,
            value: i,
            child: o.icon == null
                ? Text(o.label)
                : Row(children: [Icon(o.icon, size: 20), const SizedBox(width: 12), Flexible(child: Text(o.label))]),
          ),
      ],
    );
  }
}
