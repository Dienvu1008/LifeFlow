// P06b W6 (ADR-0094; the owner's UI 4): the Archive and the Trash, two
// destinations in the navigation.
//   Archive   what is put away, not deleted: lists, tasks, events and
//             documents; Unarchive brings one back (with what went away with
//             it); "Move to trash". A switch says whether archived items that
//             are scheduled still show on the Calendar and the Timeline
//   Trash     what was deleted, which can be restored, deleted forever one
//             by one, or all at once ("Empty trash"); how long the trash
//             keeps an item is a choice (30 days by default). Opening it
//             deletes for good what has been there that long
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n.dart';
import '../messages.dart';
import '../providers.dart';
import '../shell.dart' show shellMenuButton;
import '../task_actions.dart' show reportResult, showMessage;
import '../widgets/options_menu.dart';

IconData shelfIcon(ShelfKind k) => switch (k) {
      ShelfKind.list => Icons.folder_outlined,
      ShelfKind.task => Icons.check_box_outlined,
      ShelfKind.event => Icons.event_outlined,
      ShelfKind.document => Icons.description_outlined,
    };

/// Archives [id] and says so, with Undo; whether it was archived.
Future<bool> archiveFlow(BuildContext context, WidgetRef ref, ShelfKind kind, String id, String title) async {
  final shelf = ref.read(shelfServiceProvider);
  final r = await shelf.archive(kind, id);
  if (!context.mounted) return false;
  if (r is CommandFailure) {
    showMessage(context, describeFailure(r));
    return false;
  }
  ref.invalidate(archivedEntriesProvider);
  showMessage(context, context.l10n.shelfArchived(title),
      action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () async {
            await shelf.unarchive(kind, id);
            ref.invalidate(archivedEntriesProvider);
          }));
  return true;
}

/// Moves an archived or listed item to the trash by the kind's own command.
Future<CommandResult> trashByKind(WidgetRef ref, ShelfKind kind, String id) => switch (kind) {
      ShelfKind.task => ref.read(taskServiceProvider).trash(id, withSubtasks: true),
      ShelfKind.list => ref.read(overviewServiceProvider).trashList(id),
      ShelfKind.event => ref.read(eventServiceProvider).trash(id),
      ShelfKind.document => ref.read(documentServiceProvider).trash(id),
    };

String _titleOf(BuildContext context, ShelfEntry e) => e.title.trim().isEmpty ? context.l10n.docUntitled : e.title;

/// The entry's second line: where it was, how many went with it, when.
Widget _subtitle(BuildContext context, ShelfEntry e, {required bool trash}) {
  final l = context.l10n;
  final when = MaterialLocalizations.of(context).formatMediumDate(e.at.toLocal());
  final parts = [
    if (e.place != null) l.shelfIn(e.place!),
    if (e.contents > 0) l.shelfContents(e.contents),
    trash ? l.shelfWhenTrashed(when) : l.shelfWhenArchived(when),
  ];
  return Text(parts.join(' · '));
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onChanged});
  final ShelfKind? selected;
  final ValueChanged<ShelfKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        for (final (k, label) in [
          (null, l.shelfAll),
          (ShelfKind.task, l.shelfTasks),
          (ShelfKind.list, l.shelfLists),
          (ShelfKind.event, l.shelfEvents),
          (ShelfKind.document, l.shelfDocuments),
        ])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('shelf-filter-${k?.name ?? 'all'}'),
              label: Text(label),
              selected: selected == k,
              onSelected: (_) => onChanged(k),
            ),
          ),
      ]),
    );
  }
}

// --- the Archive ---------------------------------------------------------------

class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});
  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  ShelfKind? _filter;

  Future<void> _unarchive(ShelfEntry e) async {
    final r = await reportResult(context, ref.read(shelfServiceProvider).unarchive(e.kind, e.id));
    ref.invalidate(archivedEntriesProvider);
    if (r is CommandOk && mounted) showMessage(context, context.l10n.shelfUnarchived(_titleOf(context, e)));
  }

  Future<void> _trash(ShelfEntry e) async {
    await reportResult(context, trashByKind(ref, e.kind, e.id));
    ref.invalidate(archivedEntriesProvider);
    ref.invalidate(trashedEntriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canEdit = ref.watch(canEditShownProvider);
    final all = ref.watch(archivedEntriesProvider);
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: Text(l.navArchive), actions: const [OptionsMenu()]),
      body: Column(children: [
        SwitchListTile(
          key: const Key('archive-show-scheduled'),
          title: Text(l.shelfShowScheduled),
          subtitle: Text(l.shelfShowScheduledHelp),
          value: ref.watch(showArchivedScheduledProvider),
          onChanged: (v) => ref.read(showArchivedScheduledProvider.notifier).set(v),
        ),
        _Filters(selected: _filter, onChanged: (k) => setState(() => _filter = k)),
        const Divider(height: 1),
        Expanded(
          child: all.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.docCouldNotLoad)),
            data: (entries) {
              final list = [for (final e in entries) if (_filter == null || e.kind == _filter) e];
              if (list.isEmpty) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.shelfArchiveEmpty, key: const Key('archive-empty'), textAlign: TextAlign.center)));
              }
              return ListView(key: const Key('archive-list'), children: [
                for (final e in list)
                  ListTile(
                    key: ValueKey('archived-${e.kind.name}-${e.id}'),
                    leading: Icon(shelfIcon(e.kind)),
                    title: Text(_titleOf(context, e)),
                    subtitle: _subtitle(context, e, trash: false),
                    trailing: !canEdit
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                key: ValueKey('unarchive-${e.id}'),
                                tooltip: l.shelfUnarchive,
                                icon: const Icon(Icons.unarchive_outlined),
                                onPressed: () => _unarchive(e)),
                            PopupMenuButton<String>(
                              key: ValueKey('archived-menu-${e.id}'),
                              tooltip: l.actionsForTitle(_titleOf(context, e)),
                              onSelected: (_) => _trash(e),
                              itemBuilder: (_) => [PopupMenuItem(value: 'trash', child: Text(l.shelfMoveToTrash))],
                            ),
                          ]),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

// --- the Trash -----------------------------------------------------------------

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});
  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  ShelfKind? _filter;

  @override
  void initState() {
    super.initState();
    // What has been here as long as the retention is deleted for good.
    WidgetsBinding.instance.addPostFrameCallback((_) => _expire());
  }

  Future<void> _expire() async {
    if (!mounted || !ref.read(canEditShownProvider)) return;
    try {
      final days = await ref.read(trashRetentionDaysProvider.future);
      await ref.read(shelfServiceProvider).purgeOlderThan(days);
    } on Object {
      // the list below still shows what is there
    }
    if (mounted) ref.invalidate(trashedEntriesProvider);
  }

  Future<void> _restore(ShelfEntry e) async {
    final r = await reportResult(context, ref.read(shelfServiceProvider).restore(e.kind, e.id));
    ref.invalidate(trashedEntriesProvider);
    if (r is CommandOk && mounted) showMessage(context, context.l10n.shelfRestored(_titleOf(context, e)));
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          key: const Key('shelf-confirm'),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
            FilledButton(key: const Key('shelf-confirm-yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _purge(ShelfEntry e) async {
    final l = context.l10n;
    if (!await _confirm(l.shelfDeleteTitle, l.shelfDeleteBody(_titleOf(context, e)), l.shelfDeleteForever) || !mounted) return;
    final r = await reportResult(context, ref.read(shelfServiceProvider).purge(e.kind, e.id));
    ref.invalidate(trashedEntriesProvider);
    if (r is CommandOk && mounted) showMessage(context, l.shelfDeletedForever);
  }

  Future<void> _empty(int count) async {
    final l = context.l10n;
    if (!await _confirm(l.shelfEmptyTrash, l.shelfEmptyTrashBody(count), l.shelfEmptyTrash) || !mounted) return;
    final n = await ref.read(shelfServiceProvider).emptyTrash();
    ref.invalidate(trashedEntriesProvider);
    if (mounted) showMessage(context, l.shelfTrashEmptied(n));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canEdit = ref.watch(canEditShownProvider);
    final all = ref.watch(trashedEntriesProvider);
    final count = all.valueOrNull?.length ?? 0;
    final days = ref.watch(trashRetentionDaysProvider).valueOrNull ?? defaultTrashRetentionDays;
    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: Text(l.navTrash),
        actions: [
          if (canEdit)
            IconButton(
              key: const Key('trash-empty'),
              tooltip: l.shelfEmptyTrash,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: count == 0 ? null : () => _empty(count),
            ),
          const OptionsMenu(),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.shelfKeepFor, style: Theme.of(context).textTheme.bodyLarge),
            Text(l.shelfKeepHelp, style: Theme.of(context).textTheme.bodySmall),
            DropdownButton<int>(
              key: const Key('trash-retention'),
              isExpanded: true,
              value: trashRetentionChoices.contains(days) ? days : defaultTrashRetentionDays,
              items: [
                for (final d in trashRetentionChoices)
                  DropdownMenuItem(
                      value: d, child: Text(d == 0 ? l.shelfNever : l.shelfDays(d), overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) async {
                if (v == null) return;
                await ref.read(settingsServiceProvider).setTrashRetentionDays(v);
                ref.invalidate(trashRetentionDaysProvider);
                await _expire();
              },
            ),
          ]),
        ),        _Filters(selected: _filter, onChanged: (k) => setState(() => _filter = k)),
        const Divider(height: 1),
        Expanded(
          child: all.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l.docCouldNotLoad)),
            data: (entries) {
              final list = [for (final e in entries) if (_filter == null || e.kind == _filter) e];
              if (list.isEmpty) {
                return Center(child: Text(l.shelfTrashEmpty, key: const Key('trash-empty-text')));
              }
              return ListView(key: const Key('trash-list'), children: [
                for (final e in list)
                  ListTile(
                    key: ValueKey('trashed-${e.kind.name}-${e.id}'),
                    leading: Icon(shelfIcon(e.kind)),
                    title: Text(_titleOf(context, e)),
                    subtitle: _subtitle(context, e, trash: true),
                    trailing: !canEdit
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                key: ValueKey('restore-${e.id}'),
                                tooltip: l.shelfRestore,
                                icon: const Icon(Icons.restore_from_trash_outlined),
                                onPressed: () => _restore(e)),
                            IconButton(
                                key: ValueKey('purge-${e.id}'),
                                tooltip: l.shelfDeleteForever,
                                icon: const Icon(Icons.delete_forever_outlined),
                                onPressed: () => _purge(e)),
                          ]),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
