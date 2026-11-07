import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Backup of the ACTIVE profile (UC-20a, OQ-DATA-3 option a). If the device or
/// its secure storage is lost, an export is the only way back to the data, so
/// this says so plainly.
class DataCard extends ConsumerWidget {
  const DataCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('data-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your data', style: theme.textTheme.titleMedium),
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
                  label: const Text('Export this profile'),
                ),
                OutlinedButton.icon(
                  onPressed: () => startRestore(context, ref),
                  icon: const Icon(Icons.download),
                  label: const Text('Restore from a file'),
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
      title: const Text('Export this profile?'),
      content: const Text(
        'The file is an UNENCRYPTED copy of this profile: tasks, subtasks, '
        'trash and history. It contains no password, key or sign-in token. '
        'Anyone who gets the file can read your tasks, so keep it somewhere '
        'safe.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Export')),
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
            ? 'Exported ${file.taskCount} ${file.taskCount == 1 ? 'task' : 'tasks'}.'
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

  final outcome = await ref.read(dataTransferServiceProvider).restore(text);
  if (!context.mounted) return;
  switch (outcome) {
    case Restored(:final profile, :final asCopy, :final taskCount):
      final name = profile.displayName.trim().isEmpty ? 'Guest' : profile.displayName;
      ref.invalidate(profilesProvider);
      await _result(
        context,
        'Restored',
        asCopy
            ? '"$name" now has $taskCount ${taskCount == 1 ? 'task' : 'tasks'}. '
                'This profile was already on this device, so it was restored as '
                'a separate copy. Your existing profile was not changed.'
            : '"$name" was restored with $taskCount ${taskCount == 1 ? 'task' : 'tasks'}. '
                'Switch to it from the list of profiles.',
      );
    case RestoreRejected(:final message):
      await _result(context, 'Cannot restore', '$message Nothing was changed.');
  }
}

Future<void> _result(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
