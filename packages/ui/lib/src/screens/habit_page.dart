// P03 T6a (ADR-0041): what a task tracks (D6–D10). The habit switch, the
// target and the completion apply at once, each as one command. The page
// shows the running period, measurements with their history, the results
// of ended periods and the statistics. No rule is computed here (AP-12):
// everything shown comes from TrackingView.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../habit_text.dart';
import '../messages.dart';
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart';
import '../l10n.dart';
import 'schedule_editor.dart' show EditorSection;

Future<void> openHabitPage(BuildContext context, {required String taskId, required String title}) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => HabitPage(taskId: taskId, taskTitle: title),
    ));

/// Records a measurement; a closed period asks first (D9).
Future<void> addMeasurement(BuildContext context, WidgetRef ref, TrackingView v) async {
  final today = ref.read(todayProvider)();
  final entry = await showDialog<_MeasurementEntry>(
      context: context, builder: (_) => _MeasurementDialog(unit: v.target?.unit ?? '', today: today));
  if (entry == null || !context.mounted) return;
  final service = ref.read(habitServiceProvider);
  Future<CommandResult> run(bool confirm) =>
      service.recordMeasurement(v.taskId, entry.value, date: entry.date, note: entry.note, confirmClosed: confirm);
  await _withClosedPeriodConfirmation(context, run);
}

Future<void> _withClosedPeriodConfirmation(BuildContext context, Future<CommandResult> Function(bool confirm) run) async {
  final first = await run(false);
  if (!context.mounted) return;
  if (first is CommandFailure && first.reason == closedPeriodNeedsConfirmation) {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.changeAClosedPeriod),
        content: Text(context.l10n.closedPeriodContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(context.l10n.cancel)),
          FilledButton(key: const Key('closed-confirm'), onPressed: () => Navigator.pop(c, true), child: Text(context.l10n.changeIt)),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await reportResult(context, run(true));
    return;
  }
  if (first is CommandFailure) showMessage(context, describeFailure(first));
}

class HabitPage extends ConsumerWidget {
  const HabitPage({super.key, required this.taskId, required this.taskTitle});
  final String taskId;
  final String taskTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider(taskId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            tooltip: context.l10n.close, icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(context.l10n.habitPageTitle(taskTitle), overflow: TextOverflow.ellipsis),
      ),
      body: tracking.when(
        loading: () => Center(child: CircularProgressIndicator(semanticsLabel: context.l10n.loading)),
        error: (e, _) => Center(child: Text(context.l10n.couldNotLoadThisTask)),
        data: (v) => v == null
            ? Center(child: Text(context.l10n.thisTaskNoLongerExists))
            : _HabitBody(view: v),
      ),
    );
  }
}

class _HabitBody extends ConsumerWidget {
  const _HabitBody({required this.view});
  final TrackingView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = view;
    final today = ref.watch(todayProvider)();
    final service = ref.read(habitServiceProvider);
    final theme = Theme.of(context);
    final target = v.target;
    return ListView(
      key: const Key('habit-page'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const EditorSection('Habit'),
        SwitchListTile(
          key: const Key('habit-switch'),
          title: Text(context.l10n.trackAsAHabit),
          subtitle: Text(context.l10n.eachPeriodIsSavedAsDone),
          value: v.isHabit,
          onChanged: (on) => reportResult(context, service.setHabit(v.taskId, isHabit: on)),
        ),
        if (v.isHabit && !v.isRepeating)
          ListTile(
            key: const Key('habit-no-repeat'),
            leading: const Icon(Icons.repeat),
            title: Text(context.l10n.habitsUsuallyRepeat),
            subtitle: Text(context.l10n.withoutARepeatThisHabitHas),
            trailing: TextButton(
              key: const Key('habit-repeat-daily'),
              onPressed: () => _repeatDaily(context, ref),
              child: Text(context.l10n.everyDay),
            ),
          ),
        const EditorSection('Target'),
        ListTile(
          key: const Key('target-summary'),
          title: Text(target == null ? 'No target' : describeTarget(target)),
          subtitle: target == null ? Text(context.l10n.addATargetToMeasureProgress) : null,
          trailing: Wrap(spacing: 4, children: [
            if (target != null)
              IconButton(
                key: const Key('target-remove'),
                tooltip: context.l10n.removeTarget,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => reportResult(context, service.setTarget(v.taskId, null)),
              ),
            TextButton(
              key: Key('target-edit'),
              onPressed: () => _editTarget(context, ref),
              child: Text(target == null ? 'Set target' : 'Change'),
            ),
          ]),
        ),
        if (target != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<CompletionMode>(
              key: Key('completion'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: CompletionMode.manual, label: Text(context.l10n.iTickIt)),
                ButtonSegment(value: CompletionMode.automatic, label: Text(context.l10n.fromMeasurements)),
              ],
              selected: {v.completion},
              onSelectionChanged: (s) => reportResult(context, service.setCompletion(v.taskId, s.first)),
            ),
          ),
        if (target != null && v.current != null) ...[
          EditorSection('This period · ${periodLabel(v.current!, today)}'),
          ListTile(
            key: const Key('period-current'),
            title: Text(currentPeriodLine(v) ?? ''),
            subtitle: v.completion == CompletionMode.automatic
                ? Text(v.isCompleteNow ? 'Done automatically' : 'Done automatically when the target is reached')
                : null,
            trailing: FilledButton.tonalIcon(
              key: const Key('measure-add'),
              onPressed: () => addMeasurement(context, ref, v),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.add),
            ),
          ),
        ] else if (target != null)
          ListTile(
            title: Text(context.l10n.noRunningPeriod),
            trailing: TextButton(
              key: const Key('measure-add'),
              onPressed: () => addMeasurement(context, ref, v),
              child: Text(context.l10n.addAPastValue),
            ),
          ),
        if (v.isHabit || target != null) ...[
          const EditorSection('Statistics'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              _Stat(key: const Key('stat-streak'), label: context.l10n.currentStreak, value: '${v.streak}'),
              _Stat(key: const Key('stat-30'), label: context.l10n.last30Days, value: formatRate(v.rate30)),
              _Stat(key: const Key('stat-all'), label: context.l10n.allTime, value: formatRate(v.rateAll)),
            ]),
          ),
          const EditorSection('History'),
          if (v.results.isEmpty)
            ListTile(title: Text(context.l10n.noEndedPeriodsYet))
          else
            for (final r in v.results.take(60))
              ListTile(
                key: ValueKey('result-${r.key}'),
                dense: true,
                leading: Icon(r.outcome.isSuccess ? Icons.check_circle : Icons.circle_outlined,
                    color: r.outcome.isSuccess ? theme.colorScheme.primary : theme.colorScheme.outline),
                title: Text(r.key == null ? 'The whole task' : formatDateLong(r.key!, today: today)),
                subtitle: Text([
                  outcomeLabel(r.outcome),
                  if (r.value != null) '${formatValue(r.value!)} ${r.target?.unit ?? ''}'.trim(),
                  if (r.target != null && r.target != target) 'target then: ${describeTarget(r.target!)}',
                ].join(' · ')),
              ),
        ],
        if (target != null || v.measurements.isNotEmpty) ...[
          const EditorSection('Measurements'),
          if (v.measurements.isEmpty)
            ListTile(title: Text(context.l10n.noMeasurementsYet))
          else
            for (final m in v.measurements.take(100)) _MeasurementTile(view: v, m: m, today: today),
        ],
      ],
    );
  }

  Future<void> _repeatDaily(BuildContext context, WidgetRef ref) async {
    final scheduling = ref.read(taskSchedulingProvider);
    final current = await scheduling.scheduleOf(view.taskId);
    final today = ref.read(todayProvider)();
    final input = TaskScheduleInput(
      start: current?.start ?? SchedulePointInput.date(today),
      end: current?.end,
      deadline: current?.deadline,
      repeat: const RepeatInput(frequency: RepeatFrequency.daily),
    );
    if (!context.mounted) return;
    await reportResult(context, scheduling.setSchedule(view.taskId, input));
  }

  Future<void> _editTarget(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<TargetInput>(context: context, builder: (_) => _TargetDialog(initial: view.target));
    if (input == null || !context.mounted) return;
    await reportResult(context, ref.read(habitServiceProvider).setTarget(view.taskId, input));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: context.l10n.labelValue(label, value),
        excludeSemantics: true,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

enum _MeasureAction { correct, withdraw }

class _MeasurementTile extends ConsumerWidget {
  _MeasurementTile({required this.view, required this.m, required this.today});
  final TrackingView view;
  final MeasurementView m;
  final LocalDate today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = view.target?.unit ?? '';
    final value = m.withdrawn ? 'Withdrawn' : '${formatValue(m.value)} $unit'.trim();
    final status = m.withdrawn
        ? 'removes the earlier value'
        : !m.isCurrent
            ? 'corrected'
            : m.supersedesId != null
                ? 'correction'
                : null;
    return ListTile(
      key: ValueKey('measurement-${m.id}'),
      dense: true,
      title: Text(value,
          style: m.isCurrent || m.withdrawn ? null : TextStyle(decoration: TextDecoration.lineThrough)),
      subtitle: Text([
        formatDate(m.date, today: today),
        if (status != null) status,
        if (m.note != null) m.note!,
      ].join(' · ')),
      trailing: m.isCurrent && !m.withdrawn
          ? PopupMenuButton<_MeasureAction>(
              tooltip: context.l10n.measurementActions(formatValue(m.value), formatDate(m.date, today: today)),
              onSelected: (a) => _act(context, ref, a),
              itemBuilder: (_) => [
                PopupMenuItem(value: _MeasureAction.correct, child: Text(context.l10n.correct)),
                PopupMenuItem(value: _MeasureAction.withdraw, child: Text(context.l10n.withdraw)),
              ],
            )
          : null,
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, _MeasureAction a) async {
    final service = ref.read(habitServiceProvider);
    double? value;
    if (a == _MeasureAction.correct) {
      final entry = await showDialog<_MeasurementEntry>(
          context: context,
          builder: (_) => _MeasurementDialog(
              unit: view.target?.unit ?? '', today: today, initial: m.value, fixedDate: m.date, title: context.l10n.correctTheValue));
      if (entry == null || !context.mounted) return;
      value = entry.value;
    }
    await _withClosedPeriodConfirmation(
        context, (confirm) => service.correctMeasurement(m.id, value, confirmClosed: confirm));
  }
}

class _MeasurementEntry {
  const _MeasurementEntry(this.value, this.date, this.note);
  final double value;
  final LocalDate date;
  final String? note;
}

class _MeasurementDialog extends StatefulWidget {
  const _MeasurementDialog(
      {required this.unit, required this.today, this.initial, this.fixedDate, this.title = 'Add a measurement'});
  final String unit;
  final LocalDate today;
  final double? initial;
  final LocalDate? fixedDate;
  final String title;

  @override
  State<_MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<_MeasurementDialog> {
  late final _value = TextEditingController(text: widget.initial == null ? '' : formatValue(widget.initial!));
  final _note = TextEditingController();
  late LocalDate _date = widget.fixedDate ?? widget.today;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  void _ok() {
    final v = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || !v.isFinite) {
      setState(() => _error = 'Enter a number, 0 or more.');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(context, _MeasurementEntry(v, _date, note.isEmpty ? null : note));
  }

  Future<void> _pickDate() async {
    final t = widget.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(t.year - 3),
      lastDate: DateTime(t.year, t.month, t.day), // never the future (D10)
    );
    if (picked != null) setState(() => _date = LocalDate(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('measure-value'),
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
                labelText: context.l10n.value2, suffixText: widget.unit.isEmpty ? null : widget.unit, errorText: _error),
            onSubmitted: (_) => _ok(),
          ),
          if (widget.fixedDate == null) ...[
            const SizedBox(height: 8),
            ListTile(
              key: const Key('measure-date'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDate(_date, today: widget.today)),
              subtitle: Text(context.l10n.theDayItCountsFor),
              onTap: _pickDate,
            ),
            TextField(
              key: const Key('measure-note'),
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(labelText: context.l10n.noteOptional),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          FilledButton(key: const Key('measure-save'), onPressed: _ok, child: Text(context.l10n.save)),
        ],
      );
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({this.initial});
  final TargetInput? initial;
  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late TargetKind _kind = widget.initial?.kind ?? TargetKind.atLeast;
  late TargetAggregationKind _aggregation = widget.initial?.aggregation ?? TargetAggregationKind.sum;
  late final _min = TextEditingController(text: _num(widget.initial?.min));
  late final _max = TextEditingController(text: _num(widget.initial?.max));
  late final _unit = TextEditingController(text: widget.initial?.unit ?? '');
  String? _error;

  static String _num(double? v) => v == null ? '' : formatValue(v);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _unit.dispose();
    super.dispose();
  }

  double? _read(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _ok() {
    final min = _kind == TargetKind.atMost ? null : _read(_min);
    final max = _kind == TargetKind.atLeast ? null : _read(_max);
    final unit = _unit.text.trim();
    String? error;
    if (_kind != TargetKind.atMost && min == null) error = 'Enter the minimum.';
    if (_kind != TargetKind.atLeast && max == null) error ??= 'Enter the maximum.';
    if (unit.isEmpty) error ??= 'Enter a unit, for example steps or minutes.';
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    // The other rules (min ≤ max, ≥ 0) are checked by the command; its
    // reason is shown on the page.
    Navigator.pop(context, TargetInput(kind: _kind, min: min, max: max, unit: unit, aggregation: _aggregation));
  }

  Widget _number(String key, String label, TextEditingController c) => TextField(
        key: Key(key),
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.l10n.target),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<TargetKind>(
            key: const Key('target-kind'),
            initialValue: _kind,
            decoration: InputDecoration(labelText: context.l10n.typeLabel),
            items: [for (final k in TargetKind.values) DropdownMenuItem(value: k, child: Text(targetKindLabel(k)))],
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          if (_kind != TargetKind.atMost) _number('target-min', 'Minimum', _min),
          if (_kind != TargetKind.atLeast) _number('target-max', 'Maximum', _max),
          TextField(
            key: const Key('target-unit'),
            controller: _unit,
            maxLength: 40,
            decoration: InputDecoration(labelText: context.l10n.unit),
          ),
          Wrap(spacing: 6, children: [
            for (final u in unitSuggestions)
              ActionChip(
                key: ValueKey('unit-$u'),
                label: Text(u),
                onPressed: () => setState(() => _unit.text = u),
              ),
          ]),
          const SizedBox(height: 8),
          DropdownButtonFormField<TargetAggregationKind>(
            key: const Key('target-aggregation'),
            initialValue: _aggregation,
            decoration: InputDecoration(labelText: context.l10n.eachPeriodCountsThe),
            items: [
              for (final a in TargetAggregationKind.values)
                DropdownMenuItem(value: a, child: Text(aggregationLabel(a).toLowerCase())),
            ],
            onChanged: (a) => setState(() => _aggregation = a ?? _aggregation),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!, key: const Key('target-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
          FilledButton(key: const Key('target-save'), onPressed: _ok, child: Text(context.l10n.save)),
        ],
      );
}
