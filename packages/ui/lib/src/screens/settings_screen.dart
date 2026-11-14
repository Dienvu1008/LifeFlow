import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../shell.dart' show shellMenuButton;
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart' show reportResult;

import '../l10n.dart';
import '../theme/lifeflow_theme.dart' show fontFamilyOf;

/// P03 UX U1: the app's brightness (ADR-0045).
class _AppearanceSettings extends ConsumerWidget {
  const _AppearanceSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themePreferenceProvider).valueOrNull ?? ThemePreference.system;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(context.l10n.appearance, style: Theme.of(context).textTheme.titleSmall),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: SegmentedButton<ThemePreference>(
          key: Key('theme-preference'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: ThemePreference.system, label: Text(context.l10n.system), icon: Icon(Icons.brightness_auto_outlined)),
            ButtonSegment(value: ThemePreference.light, label: Text(context.l10n.light), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemePreference.dark, label: Text(context.l10n.dark), icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {current},
          onSelectionChanged: (s) async {
            await ref.read(settingsServiceProvider).setThemePreference(s.first);
            ref.invalidate(themePreferenceProvider);
          },
        ),
      ),
      const _LookSettings(),
    ]);
  }
}

/// P03 UX U6 (U-D13, ADR-0050): what is kept for a period of a measured task
/// completed by hand. A profile setting (exported, later synced), not a
/// device one.
class _ResultSettings extends ConsumerWidget {
  const _ResultSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(manualResultsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        title: Text(l.resultsTitle, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(l.resultsHint),
      ),
      current.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => ListTile(title: Text(l.resultsCouldNotLoad)),
        data: (v) => RadioGroup<ManualResults>(
          groupValue: v,
          onChanged: (n) async {
            if (n == null || n == v) return;
            await reportResult(context, ref.read(habitServiceProvider).setManualResults(n));
            ref.invalidate(manualResultsProvider);
          },
          child: Column(children: [
            RadioListTile<ManualResults>(
                key: const Key('results-target'),
                value: ManualResults.target,
                title: Text(l.resultsTarget),
                subtitle: Text(l.resultsTargetHint)),
            RadioListTile<ManualResults>(
                key: const Key('results-tick'),
                value: ManualResults.tick,
                title: Text(l.resultsTick),
                subtitle: Text(l.resultsTickHint)),
          ]),
        ),
      ),
    ]);
  }
}
/// Dogfooding O1/O3 (ADR-0051): drag handles, font and text size.
class _LookSettings extends ConsumerWidget {
  const _LookSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final look = ref.watch(appearanceProvider).valueOrNull ?? const AppearanceSettings();
    Future<void> save(AppearanceSettings s) async {
      await ref.read(settingsServiceProvider).setAppearance(s);
      ref.invalidate(appearanceProvider);
    }

    String fontName(AppFont f) => switch (f) {
          AppFont.system => l.apFontSystem,
          AppFont.inter => 'Inter',
          AppFont.notoSans => 'Noto Sans',
          AppFont.beVietnamPro => 'Be Vietnam Pro',
        };
    final percent = (look.textScale * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(title: Text(l.apDragHandles), subtitle: Text(l.apDragHandlesHint)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SegmentedButton<DragHandles>(
          key: const Key('drag-handles'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: DragHandles.auto, label: Text(l.apAuto)),
            ButtonSegment(value: DragHandles.always, label: Text(l.apAlways)),
            ButtonSegment(value: DragHandles.never, label: Text(l.apNever)),
          ],
          selected: {look.dragHandles},
          onSelectionChanged: (s) => save(look.copyWith(dragHandles: s.first)),
        ),
      ),
      ListTile(
        title: Text(l.apFont),
        trailing: DropdownButton<AppFont>(
          key: const Key('app-font'),
          value: look.font,
          onChanged: (f) => f == null ? null : save(look.copyWith(font: f)),
          items: [
            for (final f in AppFont.values)
              DropdownMenuItem(
                value: f,
                child: Text(fontName(f), style: TextStyle(fontFamily: fontFamilyOf(f))),
              ),
          ],
        ),
      ),
      ListTile(
        title: Text(l.apTextSize),
        subtitle: Text(l.apTextSizeHint),
        trailing: Text(l.apTextSizeValue(percent), key: const Key('text-size-value')),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Slider(
          key: const Key('text-size'),
          min: AppearanceSettings.textScaleRange.min,
          max: AppearanceSettings.textScaleRange.max,
          divisions: 14, // 5 % steps
          value: look.textScale,
          label: l.apTextSizeValue(percent),
          semanticFormatterCallback: (v) => l.apTextSizeValue((v * 100).round()),
          onChanged: (v) => save(look.copyWith(textScale: (v * 20).round() / 20)),
        ),
      ),
    ]);
  }
}
/// App settings of this device.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(subtaskTrashPolicyProvider);
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: Text(context.l10n.settings)),
      body: ListView(
        children: [
          const _AppearanceSettings(),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(context.l10n.tasks, style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            title: Text(context.l10n.movingATaskWithSubtasksTo),
            subtitle: Text(context.l10n.keptSubtasksMoveUpOneLevel),
          ),
          policy.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => ListTile(
                title: Text(context.l10n.thisSettingCouldNotBeLoaded)),
            data: (current) => RadioGroup<SubtaskTrashPolicy>(
              groupValue: current,
              onChanged: (p) async {
                if (p == null) return;
                await ref.read(settingsServiceProvider).setSubtaskTrashPolicy(p);
                ref.invalidate(subtaskTrashPolicyProvider);
              },
              child: Column(
                children: [
                  RadioListTile<SubtaskTrashPolicy>(
                    key: Key('trash-policy-ask'),
                    value: SubtaskTrashPolicy.ask,
                    title: Text(context.l10n.askEveryTime),
                  ),
                  RadioListTile<SubtaskTrashPolicy>(
                    key: Key('trash-policy-with'),
                    value: SubtaskTrashPolicy.withSubtasks,
                    title: Text(context.l10n.moveTheSubtasksToTheTrash),
                  ),
                  RadioListTile<SubtaskTrashPolicy>(
                    key: Key('trash-policy-keep'),
                    value: SubtaskTrashPolicy.keepSubtasks,
                    title: Text(context.l10n.keepTheSubtasks),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          const _CalendarSettings(),
          const Divider(height: 32),
          const _ResultSettings(),
          const Divider(height: 32),
          const _ReminderSettings(),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(context.l10n.about, style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            key: const Key('open-source-licenses'),
            leading: const Icon(Icons.description_outlined),
            title: Text(context.l10n.openSourceLicenses),
            subtitle: Text(context.l10n.theLicensesOfTheSoftwareLifeflow),
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
          child: Text(context.l10n.calendar, style: Theme.of(context).textTheme.titleSmall),
        ),
        settings.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          error: (_, __) =>
              ListTile(title: Text(context.l10n.theseSettingsCouldNotBeLoaded)),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(title: Text(context.l10n.weekStartsOn)),
              RadioGroup<Weekday>(
                groupValue: s.firstDayOfWeek,
                onChanged: (d) => d == null ? null : save(s.copyWith(firstDayOfWeek: d)),
                child: Column(children: [
                  RadioListTile<Weekday>(
                      key: Key('week-start-monday'),
                      value: Weekday.monday,
                      title: Text(context.l10n.monday)),
                  RadioListTile<Weekday>(
                      key: Key('week-start-sunday'),
                      value: Weekday.sunday,
                      title: Text(context.l10n.sunday)),
                ]),
              ),
              // P03 UX U5 (U-D5): one hidden range of night hours.
              ListTile(
                title: Text(context.l10n.calNightHours),
                subtitle: Text(context.l10n.calNightHoursHint),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (key, from) in const [('night-from', true), ('night-to', false)])
                    OutlinedButton(
                      key: Key(key),
                      onPressed: () async {
                        final m = from ? s.hiddenFrom : s.hiddenTo;
                        final picked = await showTimePicker(
                            context: context, initialTime: TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60));
                        if (picked == null) return;
                        final v = picked.hour * 60 + picked.minute;
                        await save(from ? s.copyWith(hiddenFrom: v) : s.copyWith(hiddenTo: v));
                      },
                      child: Text(() {
                        final m = from ? s.hiddenFrom : s.hiddenTo;
                        final hhmm = '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
                        return from ? context.l10n.calNightFrom(hhmm) : context.l10n.calNightTo(hhmm);
                      }()),
                    ),
                ]),
              ),
              ListTile(
                title: Text(context.l10n.newMonthlyRepeatsInAMonth),
                subtitle: Text(context.l10n.forExampleThe31stInApril),
              ),
              RadioGroup<MonthEndChoice>(
                groupValue: s.defaultMonthEnd,
                onChanged: (m) => m == null ? null : save(s.copyWith(defaultMonthEnd: m)),
                child: Column(children: [
                  RadioListTile<MonthEndChoice>(
                      key: Key('month-end-skip'),
                      value: MonthEndChoice.skip,
                      title: Text(context.l10n.skipThatMonth)),
                  RadioListTile<MonthEndChoice>(
                      key: Key('month-end-lastDay'),
                      value: MonthEndChoice.lastDay,
                      title: Text(context.l10n.useTheLastDayOfThe)),
                ]),
              ),
              ListTile(
                key: const Key('max-occurrences'),
                title: Text(context.l10n.mostItemsInOneView),
                subtitle: Text(context.l10n.settingMaxOccurrences(s.maxOccurrences)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final r = PlanningSettings.occurrencesRange;
                  final v = await _askNumber(context,
                      title: context.l10n.mostItemsInOneView, initial: s.maxOccurrences, min: r.min, max: r.max);
                  if (v != null) await save(s.copyWith(maxOccurrences: v));
                },
              ),
              ListTile(
                key: const Key('max-window'),
                title: Text(context.l10n.longestRangeInDays),
                subtitle: Text(context.l10n.settingMaxWindowDays(s.maxWindowDays)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final r = PlanningSettings.windowDaysRange;
                  final v = await _askNumber(context,
                      title: context.l10n.longestRangeInDays, initial: s.maxWindowDays, min: r.min, max: r.max);
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
          child: Text(context.l10n.reminders, style: Theme.of(context).textTheme.titleSmall),
        ),
        status.when(
          loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
          error: (_, __) => ListTile(title: Text(context.l10n.theReminderStatusCouldNotBe)),
          data: (s) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!s.supported)
                ListTile(
                  leading: Icon(Icons.notifications_off_outlined),
                  title: Text(context.l10n.thisDeviceDoesNotShowReminders),
                )
              else if (!s.allowed && !s.canAsk)
                ListTile(
                  key: Key('reminders-off-in-system'),
                  leading: Icon(Icons.notifications_off_outlined),
                  title: Text(context.l10n.notificationsAreOffForLifeflow),
                  subtitle: Text(context.l10n.turnLifeflowOnInYourSystem),
                )
              else if (!s.allowed)
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: Text(context.l10n.notificationsAreOffForLifeflow),
                  subtitle: Text(context.l10n.remindersWillNotShowUntilYou),
                  trailing: FilledButton(
                    key: const Key('reminders-allow'),
                    onPressed: () async {
                      await ref.read(reminderSchedulerProvider).requestPermission();
                      ref.invalidate(reminderStatusProvider);
                    },
                    child: Text(context.l10n.allow),
                  ),
                )
              else
                ListTile(
                  leading: Icon(Icons.notifications_active_outlined),
                  title: Text(context.l10n.remindersAreOn),
                ),
              if (s.supported && s.exactAllowed == false)
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(context.l10n.remindersMayArriveAFewMinutes),
                  subtitle: Text(context.l10n.allowExactRemindersToGetThem),
                  trailing: OutlinedButton(
                    key: const Key('reminders-exact'),
                    onPressed: () async {
                      await ref.read(reminderSchedulerProvider).requestExact();
                      ref.invalidate(reminderStatusProvider);
                    },
                    child: Text(context.l10n.allow),
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
            helperText: context.l10n.fromMinToMax(widget.min, widget.max),
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: _submit, child: Text(context.l10n.save)),
        ],
      );
}
