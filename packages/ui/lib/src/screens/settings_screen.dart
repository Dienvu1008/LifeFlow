import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../providers.dart';
import '../schedule_text.dart';

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
          const Divider(height: 32),
          const _CalendarSettings(),
          const Divider(height: 32),
          const _ReminderSettings(),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text('About', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            key: const Key('open-source-licenses'),
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            subtitle: const Text('The licenses of the software LifeFlow is built with.'),
            onTap: () => showLicensePage(context: context, applicationName: 'LifeFlow'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Owner decisions D1–D3: query limits, month-end rule and first day of the
/// week. The rule and the week start are only defaults for NEW repeats; each
/// repeat keeps its own.
class _CalendarSettings extends ConsumerWidget {
  const _CalendarSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(planningSettingsProvider);
    Future<void> save(PlanningSettings s) async {
      await ref.read(settingsServiceProvider).setPlanningSettings(s);
      ref.invalidate(planningSettingsProvider);
      // Today/Upcoming re-query with the new limits.
      ref.invalidate(todayAgendaProvider);
      ref.invalidate(upcomingAgendaProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Calendar', style: Theme.of(context).textTheme.titleSmall),
        ),
        settings.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          error: (_, __) =>
              const ListTile(title: Text('These settings could not be loaded.')),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(title: Text('Week starts on')),
              RadioGroup<Weekday>(
                groupValue: s.firstDayOfWeek,
                onChanged: (d) => d == null ? null : save(s.copyWith(firstDayOfWeek: d)),
                child: const Column(children: [
                  RadioListTile<Weekday>(
                      key: Key('week-start-monday'),
                      value: Weekday.monday,
                      title: Text('Monday')),
                  RadioListTile<Weekday>(
                      key: Key('week-start-sunday'),
                      value: Weekday.sunday,
                      title: Text('Sunday')),
                ]),
              ),
              const ListTile(
                title: Text('New monthly repeats in a month without that day'),
                subtitle: Text('For example the 31st in April. Existing repeats keep their choice.'),
              ),
              RadioGroup<MonthEndChoice>(
                groupValue: s.defaultMonthEnd,
                onChanged: (m) => m == null ? null : save(s.copyWith(defaultMonthEnd: m)),
                child: const Column(children: [
                  RadioListTile<MonthEndChoice>(
                      key: Key('month-end-skip'),
                      value: MonthEndChoice.skip,
                      title: Text('Skip that month')),
                  RadioListTile<MonthEndChoice>(
                      key: Key('month-end-lastDay'),
                      value: MonthEndChoice.lastDay,
                      title: Text('Use the last day of the month')),
                ]),
              ),
              ListTile(
                key: const Key('max-occurrences'),
                title: const Text('Most items in one view'),
                subtitle: Text('${s.maxOccurrences}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final r = PlanningSettings.occurrencesRange;
                  final v = await _askNumber(context,
                      title: 'Most items in one view', initial: s.maxOccurrences, min: r.min, max: r.max);
                  if (v != null) await save(s.copyWith(maxOccurrences: v));
                },
              ),
              ListTile(
                key: const Key('max-window'),
                title: const Text('Longest range in days'),
                subtitle: Text('${s.maxWindowDays}'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final r = PlanningSettings.windowDaysRange;
                  final v = await _askNumber(context,
                      title: 'Longest range in days', initial: s.maxWindowDays, min: r.min, max: r.max);
                  if (v != null) await save(s.copyWith(maxWindowDays: v));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// P02 T7: what the device allows for reminders, and how to change it.
class _ReminderSettings extends ConsumerWidget {
  const _ReminderSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(reminderStatusProvider);
    return Column(
      key: const Key('reminder-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Reminders', style: Theme.of(context).textTheme.titleSmall),
        ),
        status.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          error: (_, __) => const ListTile(title: Text('The reminder status could not be read.')),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!s.supported)
                const ListTile(
                  leading: Icon(Icons.notifications_off_outlined),
                  title: Text('This device does not show reminders.'),
                )
              else if (!s.allowed && !s.canAsk)
                const ListTile(
                  key: Key('reminders-off-in-system'),
                  leading: Icon(Icons.notifications_off_outlined),
                  title: Text('Notifications are off for LifeFlow'),
                  subtitle: Text('Turn LifeFlow on in your system\'s notification settings to see reminders.'),
                )
              else if (!s.allowed)
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: const Text('Notifications are off for LifeFlow'),
                  subtitle: const Text('Reminders will not show until you allow them.'),
                  trailing: FilledButton(
                    key: const Key('reminders-allow'),
                    onPressed: () async {
                      await ref.read(reminderSchedulerProvider).requestPermission();
                      ref.invalidate(reminderStatusProvider);
                    },
                    child: const Text('Allow'),
                  ),
                )
              else
                const ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text('Reminders are on'),
                ),
              if (s.supported && s.exactAllowed == false)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Reminders may arrive a few minutes late'),
                  subtitle: const Text('Allow exact reminders to get them at the minute.'),
                  trailing: OutlinedButton(
                    key: const Key('reminders-exact'),
                    onPressed: () async {
                      await ref.read(reminderSchedulerProvider).requestExact();
                      ref.invalidate(reminderStatusProvider);
                    },
                    child: const Text('Allow'),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text(
            'LifeFlow sets up the reminders of the next $reminderHorizonDays days each time it runs, '
            'so open it at least once every $reminderHorizonDays days. '
            'All-day items remind at $allDayReminderTimeText. '
            'Only the open profile reminds.',
            key: const Key('reminder-info'),
          ),
        ),
      ],
    );
  }
}

Future<int?> _askNumber(BuildContext context,
        {required String title, required int initial, required int min, required int max}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _NumberDialog(title: title, initial: initial, min: min, max: max),
    );

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({required this.title, required this.initial, required this.min, required this.max});
  final String title;
  final int initial;
  final int min;
  final int max;
  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _c = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = int.tryParse(_c.text.trim());
    if (v == null || v < widget.min || v > widget.max) {
      setState(() => _error = 'Enter a number from ${widget.min} to ${widget.max}.');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          key: const Key('number-field'),
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: 'From ${widget.min} to ${widget.max}',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      );
}
