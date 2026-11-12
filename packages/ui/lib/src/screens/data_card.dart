import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../l10n.dart';

/// Backup of the ACTIVE profile (UC-20a, OQ-DATA-3 option a). If the device or
/// its secure storage is lost, an export is the only way back to the data, so
/// this says so plainly.
class DataCard extends ConsumerWidget {
  const DataCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Unknown or failed -> no Undo button (never breaks the screen).
    final canUndo = ref.watch(canUndoRestoreProvider).valueOrNull ?? false;
    return Card(
      key: const Key('data-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.yourData, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Your data is encrypted on this device. If you lose the device, '
              'or its secure storage is reset, it cannot be recovered. Export '
              'this profile to keep a backup file you control.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => startExport(context, ref),
                  icon: const Icon(Icons.upload_file),
                  label: Text(context.l10n.exportThisProfile),
                ),
                OutlinedButton.icon(
                  onPressed: () => startRestore(context, ref),
                  icon: const Icon(Icons.download),
                  label: Text(context.l10n.restoreFromAFile),
                ),
                if (canUndo)
                  TextButton.icon(
                    key: const Key('undo-restore'),
                    onPressed: () => startUndoRestore(context, ref),
                    icon: const Icon(Icons.undo),
                    label: Text(context.l10n.undoLastRestore),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> startExport(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.exportThisProfile2),
      content: const Text(
        'The file is an UNENCRYPTED copy of this profile: tasks, subtasks, '
        'trash and history. It contains no password, key or sign-in token. '
        'Anyone who gets the file can read your tasks, so keep it somewhere '
        'safe.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.exportLabel)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    final file = await ref.read(dataTransferServiceProvider).exportActiveProfile();
    final saved = await ref
        .read(fileGatewayProvider)
        .saveText(file.suggestedName, file.contents);
    if (!context.mounted) return;
    _snack(
        context,
        saved
            ? 'Exported ${file.taskCount} ${_items(file.taskCount, 'task')}.'
            : 'Export cancelled. Nothing was saved.');
  } catch (_) {
    if (context.mounted) {
      _snack(context, 'The export could not be saved. Nothing was changed.');
    }
  }
}

Future<void> startRestore(BuildContext context, WidgetRef ref) async {
  final String? text;
  try {
    text = await ref.read(fileGatewayProvider).pickText();
  } on FileTooLarge {
    if (context.mounted) {
      await _result(context, 'Cannot restore',
          'This file is too large to be a LifeFlow export.');
    }
    return;
  } catch (_) {
    if (context.mounted) {
      await _result(context, 'Cannot restore', 'The file could not be read.');
    }
    return;
  }
  if (text == null || !context.mounted) return; // cancelled

  final service = ref.read(dataTransferServiceProvider);
  final preview = await service.inspect(text);
  if (!context.mounted) return;

  switch (preview) {
    case RestoreRejected(:final message):
      await _result(context, 'Cannot restore', '$message Nothing was changed.');

    case RestoreIdentical():
      await _result(
          context,
          'Nothing to restore',
          'The data in this file and in this profile are the same. There is '
              'nothing to restore.');

    case RestoreOtherProfile(:final displayName, :final locked):
      final name = _name(displayName);
      await _result(
          context,
          'Another profile',
          locked
              ? 'This file belongs to "$name", which is signed out. Sign in '
                  'to open it, then restore the file there. Nothing was changed.'
              : 'This file belongs to "$name" on this device. Switch to it, '
                  'then restore the file there. Nothing was changed.');

    case RestoreAsNewProfile(:final displayName, :final taskCount):
      final go = await _confirm(
          context,
          'Restore as a new profile?',
          '"${_name(displayName)}" ($taskCount ${_items(taskCount, 'task')}) '
              'is not on this device. It will be added as a separate profile '
              'with its own data. Your current profile is not changed.',
          'Restore');
      if (go != true || !context.mounted) return;
      await _apply(context, ref, text, null);

    case RestoreDifferent(:final diff):
      final choice = await showDialog<RestoreChoice>(
          context: context, builder: (_) => _ChoiceDialog(diff));
      if (choice == null || !context.mounted) return;
      await _apply(context, ref, text, choice);
  }
}

Future<void> _apply(BuildContext context, WidgetRef ref, String text,
    RestoreChoice? choice) async {
  final service = ref.read(dataTransferServiceProvider);
  var outcome = await service.restore(text, choice: choice);
  if (!context.mounted) return;

  if (outcome case RestoreHierarchyConflict(:final taskTitles)) {
    final keep = await _hierarchyDialog(context, taskTitles);
    if (keep != true || !context.mounted) {
      if (context.mounted) {
        _snack(context, 'Restore cancelled. Nothing was changed.');
      }
      return;
    }
    outcome = await service.restore(text, choice: choice!.withDeviceParents());
    if (!context.mounted) return;
  }

  ref.invalidate(profilesProvider);
  ref.invalidate(canUndoRestoreProvider);
  switch (outcome) {
    case Restored(:final profile, :final taskCount):
      await _result(
          context,
          'Restored',
          '"${_name(profile.displayName)}" was restored with $taskCount '
              '${_items(taskCount, 'task')}. Switch to it from the list of profiles.');
    case RestoredInto() when outcome.changedNothing:
      await _result(context, 'Nothing to restore',
          'Nothing in this profile needed to change.');
    case RestoredInto(:final added, :final updated, :final removed):
      await _result(
          context,
          'Restored',
          [
            if (added > 0) 'Added $added ${_items(added, 'item')}.',
            if (updated > 0) 'Updated $updated ${_items(updated, 'item')}.',
            if (removed > 0)
              'Moved $removed ${_items(removed, 'item')} to the trash.',
            'You can undo this with "Undo last restore".',
          ].join(' '));
    case RestoreHierarchyConflict():
      await _result(context, 'Cannot restore',
          'The task hierarchy could not be repaired. Nothing was changed.');
    case RestoreRejected(:final message):
      await _result(context, 'Cannot restore', message);
  }
}

Future<void> startUndoRestore(BuildContext context, WidgetRef ref) async {
  final go = await _confirm(
      context,
      'Undo the last restore?',
      'This profile goes back to how it was just before the last restore. '
          'Changes made since then are undone too.',
      'Undo restore');
  if (go != true || !context.mounted) return;
  final outcome = await ref.read(dataTransferServiceProvider).undoLastRestore();
  ref.invalidate(canUndoRestoreProvider);
  if (!context.mounted) return;
  switch (outcome) {
    case RestoredInto():
      _snack(context, 'The last restore was undone.');
    case RestoreRejected(:final message):
      await _result(context, 'Cannot undo', message);
    default:
      await _result(context, 'Cannot undo', 'Nothing was changed.');
  }
}

/// The owner's choice for a file that differs from the active profile:
/// overwrite everything, or merge with (a) newer wins and (b) add missing.
class _ChoiceDialog extends StatefulWidget {
  const _ChoiceDialog(this.diff);
  final RestoreDiff diff;
  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  RestoreMode _mode = RestoreMode.merge;
  bool _takeNewer = true;
  bool _addMissing = true;

  @override
  Widget build(BuildContext context) {
    final d = widget.diff;
    final merge = _mode == RestoreMode.merge;
    final canGo = !merge || _takeNewer || _addMissing;
    return AlertDialog(
      key: const Key('restore-choice'),
      title: Text(context.l10n.thisFileDiffersFromThisProfile),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.restoreOnlyInFile(d.onlyInFile)),
            Text(context.l10n.restoreOnlyOnDevice(d.onlyOnDevice)),
            Text(context.l10n.restoreInBothDifferent(d.differing, d.newerInFile)),
            const SizedBox(height: 12),
            RadioGroup<RestoreMode>(
              groupValue: _mode,
              onChanged: (m) => setState(() => _mode = m ?? _mode),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<RestoreMode>(
                    key: Key('mode-overwrite'),
                    value: RestoreMode.overwrite,
                    title: Text(context.l10n.overwriteEverything),
                    subtitle: Text(context.l10n.restoreOverwriteHint),
                  ),
                  RadioListTile<RestoreMode>(
                    key: Key('mode-merge'),
                    value: RestoreMode.merge,
                    title: Text(context.l10n.merge),
                    subtitle: Text(context.l10n.restoreMergeHint),
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              key: const Key('opt-newer'),
              value: _takeNewer,
              onChanged: merge ? (v) => setState(() => _takeNewer = v!) : null,
              title: Text(context.l10n.useTheNewerVersion),
              subtitle: Text(context.l10n.restoreNewerHint),
            ),
            CheckboxListTile(
              key: const Key('opt-missing'),
              value: _addMissing,
              onChanged: merge ? (v) => setState(() => _addMissing = v!) : null,
              title: Text(context.l10n.addWhatIsOnlyInThe),
            ),
            const SizedBox(height: 8),
            Text(context.l10n.restoreUndoHint),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel)),
        FilledButton(
          key: const Key('restore-go'),
          onPressed: canGo
              ? () => Navigator.pop(
                  context,
                  merge
                      ? RestoreChoice.merge(
                          takeNewer: _takeNewer, addMissing: _addMissing)
                      : const RestoreChoice.overwrite())
              : null,
          child: Text(merge ? 'Merge' : 'Overwrite'),
        ),
      ],
    );
  }
}

Future<bool?> _hierarchyDialog(BuildContext context, List<String> titles) {
  final shown = titles.take(5).map((t) => '• $t').join('\n');
  final more = titles.length > 5 ? '\n…and ${titles.length - 5} more' : '';
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('hierarchy-conflict'),
      title: Text(context.l10n.someSubtasksWouldNotFit),
      content: Text(
        'Merging would put ${titles.length} ${_items(titles.length, 'task')} '
        'in a loop, under a missing parent, or too deep:\n$shown$more\n\n'
        'You can keep this device\'s parent for these tasks (a task that is '
        'new from the file goes to the top level), or cancel.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.keepThisDeviceSParents)),
      ],
    ),
  );
}

Future<bool?> _confirm(
        BuildContext context, String title, String message, String action) =>
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );

Future<void> _result(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.ok)),
        ],
      ),
    );

String _name(String n) => n.trim().isEmpty ? 'Guest' : n;
String _items(int n, String word) => n == 1 ? word : '${word}s';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
