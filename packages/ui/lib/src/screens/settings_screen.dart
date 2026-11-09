import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// App settings of this device.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(subtaskTrashPolicyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Tasks', style: Theme.of(context).textTheme.titleSmall),
          ),
          const ListTile(
            title: Text('Moving a task with subtasks to the trash'),
            subtitle: Text('Kept subtasks move up one level.'),
          ),
          policy.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const ListTile(
                title: Text('This setting could not be loaded.')),
            data: (current) => RadioGroup<SubtaskTrashPolicy>(
              groupValue: current,
              onChanged: (p) async {
                if (p == null) return;
                await ref.read(settingsServiceProvider).setSubtaskTrashPolicy(p);
                ref.invalidate(subtaskTrashPolicyProvider);
              },
              child: const Column(
                children: [
                  RadioListTile<SubtaskTrashPolicy>(
                    key: Key('trash-policy-ask'),
                    value: SubtaskTrashPolicy.ask,
                    title: Text('Ask every time'),
                  ),
                  RadioListTile<SubtaskTrashPolicy>(
                    key: Key('trash-policy-with'),
                    value: SubtaskTrashPolicy.withSubtasks,
                    title: Text('Move the subtasks to the trash too'),
                  ),
                  RadioListTile<SubtaskTrashPolicy>(
                    key: Key('trash-policy-keep'),
                    value: SubtaskTrashPolicy.keepSubtasks,
                    title: Text('Keep the subtasks'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
