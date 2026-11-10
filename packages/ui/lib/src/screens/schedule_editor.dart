// P02 T6a: the schedule editor of a task (start, end, deadline, repeat).
// The editor only collects input; the rules are checked by the command
// (TaskScheduling.setSchedule) and its reason is shown here (AP-12).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../messages.dart';
import '../providers.dart';
import '../schedule_text.dart';

/// Opens the editor for [taskId] over the whole app. New repeats take their
/// month-end rule and week start from the device settings (D2/D3).
Future<void> openScheduleEditor(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  required String title,
  TaskScheduleInput? initial,
}) async {
  var defaults = const PlanningSettings();
  try {
    defaults = await ref.read(settingsServiceProvider).planningSettings();
  } catch (_) {
    // Settings unavailable: the built-in defaults.
  }
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ScheduleEditorPage(
        taskId: taskId, taskTitle: title, initial: initial, defaults: defaults),
  ));
}

enum _EndKind { never, onDate, afterCount }

class ScheduleEditorPage extends ConsumerStatefulWidget {
  const ScheduleEditorPage({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.defaults,
    this.initial,
  });

  final String taskId;
  final String taskTitle;
  final TaskScheduleInput? initial;
  final PlanningSettings defaults;

  @override
  ConsumerState<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _Point {
  LocalDate? date;
  TimeOfDayValue? time;
}

class _ScheduleEditorPageState extends ConsumerState<ScheduleEditorPage> {
  final _start = _Point();
  final _end = _Point();
  final _due = _Point();
  late String _zone;

  bool _repeat = false;
  RepeatFrequency _frequency = RepeatFrequency.daily;
  final _interval = TextEditingController(text: '1');
  final _weekdays = <Weekday>{};
  _EndKind _endKind = _EndKind.never;
  LocalDate? _until;
  final _count = TextEditingController(text: '10');
  late MonthEndChoice _monthEnd = widget.defaults.defaultMonthEnd;
  late Weekday _weekStart = widget.defaults.firstDayOfWeek;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    void load(_Point to, SchedulePointInput? p) {
      to.date = p?.date;
      to.time = p?.time;
    }

    load(_start, s?.start);
    load(_end, s?.end);
    load(_due, s?.deadline);
    _zone = [s?.start, s?.end, s?.deadline]
            .firstWhere((p) => p?.zone != null, orElse: () => null)
            ?.zone ??
        ref.read(deviceZoneProvider);
    final r = s?.repeat;
    if (r != null) {
      _repeat = true;
      _frequency = r.frequency;
      _interval.text = '${r.interval}';
      _weekdays.addAll(r.weekdays ?? const {});
      switch (r.end) {
        case RepeatForever():
          _endKind = _EndKind.never;
        case RepeatUntil(:final date):
          _endKind = _EndKind.onDate;
          _until = date;
        case RepeatTimes(:final count):
          _endKind = _EndKind.afterCount;
          _count.text = '$count';
      }
      // Each repeat keeps its own rule (D2/D3 refinement).
      _monthEnd = r.monthEnd;
      _weekStart = r.weekStart;
    }
  }

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  LocalDate get _today => ref.read(todayProvider)();

  bool get _hasTime => [_start, _end, _due].any((p) => p.date != null && p.time != null);

  SchedulePointInput? _input(_Point p) {
    final d = p.date;
    if (d == null) return null;
    final t = p.time;
    return t == null ? SchedulePointInput.date(d) : SchedulePointInput.at(d, t, _zone);
  }

  /// The input, or a message about a field that cannot be read.
  (TaskScheduleInput?, String?) _build() {
    RepeatInput? repeat;
    if (_repeat) {
      final interval = int.tryParse(_interval.text.trim());
      if (interval == null) return (null, 'Enter how often it repeats.');
      final RepeatEnd end;
      switch (_endKind) {
        case _EndKind.never:
          end = const RepeatForever();
        case _EndKind.onDate:
          final u = _until;
          if (u == null) return (null, 'Choose the date the repeat ends.');
          end = RepeatUntil(u);
        case _EndKind.afterCount:
          final c = int.tryParse(_count.text.trim());
          if (c == null) return (null, 'Enter how many times it repeats.');
          end = RepeatTimes(c);
      }
      repeat = RepeatInput(
        frequency: _frequency,
        interval: interval,
        // None chosen: the start's own weekday.
        weekdays: _frequency == RepeatFrequency.weekly && _weekdays.isNotEmpty
            ? Set.of(_weekdays)
            : null,
        end: end,
        monthEnd: _monthEnd,
        weekStart: _weekStart,
      );
    }
    return (
      TaskScheduleInput(
          start: _input(_start), end: _input(_end), deadline: _input(_due), repeat: repeat),
      null
    );
  }

  Future<void> _save() async {
    final (input, problem) = _build();
    if (input == null) {
      setState(() => _error = problem);
      return;
    }
    await _run(ref.read(taskSchedulingProvider).setSchedule(widget.taskId, input));
  }

  Future<void> _remove() =>
      _run(ref.read(taskSchedulingProvider).setSchedule(widget.taskId, null));

  Future<void> _run(Future<CommandResult> pending) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await pending;
    if (!mounted) return;
    if (result is CommandFailure) {
      setState(() {
        _busy = false;
        _error = describeFailure(result);
      });
      return;
    }
    Navigator.of(context).pop();
  }

  Future<LocalDate?> _pickDate(LocalDate? current, String help) async {
    final c = current ?? _today;
    final picked = await showDatePicker(
      context: context,
      helpText: help,
      initialDate: DateTime(c.year, c.month, c.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    return picked == null ? null : LocalDate(picked.year, picked.month, picked.day);
  }

  Future<void> _pickZone() async {
    final zone = await showDialog<String>(
      context: context,
      builder: (_) => _ZoneDialog(
          zones: ref.read(zoneCatalogProvider).zoneNames(),
          current: _zone,
          device: ref.read(deviceZoneProvider)),
    );
    if (zone != null) setState(() => _zone = zone);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = ref.watch(deviceZoneProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Schedule: ${widget.taskTitle}', overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            key: const Key('schedule-save'),
            onPressed: _busy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!,
                    key: const Key('schedule-error'),
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          _section(context, 'When'),
          _pointRow('Start', 'start', _start, device),
          _pointRow('End', 'end', _end, device),
          _pointRow('Deadline', 'due', _due, device),
          if (_hasTime)
            ListTile(
              key: const Key('schedule-zone'),
              leading: const Icon(Icons.public),
              title: const Text('Time zone'),
              subtitle: Text(_zone == device ? '$_zone (this device)' : _zone),
              onTap: _pickZone,
            ),
          _section(context, 'Repeat'),
          SwitchListTile(
            key: const Key('repeat-switch'),
            title: const Text('Repeat'),
            value: _repeat,
            onChanged: (v) => setState(() => _repeat = v),
          ),
          if (_repeat) ..._repeatFields(context),
          if (widget.initial != null) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                key: const Key('schedule-remove'),
                onPressed: _busy ? null : _remove,
                icon: const Icon(Icons.event_busy),
                label: const Text('Remove schedule'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _pointRow(String label, String key, _Point p, String device) {
    final d = p.date;
    final value = _input(p);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  value == null
                      ? 'Not set'
                      : formatPoint(value, today: _today, deviceZone: device),
                  key: Key('$key-value'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: Key('$key-date'),
                tooltip: d == null ? 'Set $label date' : 'Change $label date',
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await _pickDate(d, '$label date');
                  if (picked != null) setState(() => p.date = picked);
                },
              ),
              if (d != null)
                IconButton(
                  key: Key('$key-time'),
                  tooltip: p.time == null ? 'Add $label time' : 'Change $label time',
                  icon: Icon(p.time == null ? Icons.more_time : Icons.schedule),
                  onPressed: () async {
                    final t = p.time ?? TimeOfDayValue(9, 0);
                    final picked = await showTimePicker(
                        context: context,
                        helpText: '$label time',
                        initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
                    if (picked != null) {
                      setState(() => p.time = TimeOfDayValue(picked.hour, picked.minute));
                    }
                  },
                ),
              if (p.time != null)
                IconButton(
                  key: Key('$key-clear-time'),
                  tooltip: 'Remove $label time',
                  icon: const Icon(Icons.timer_off_outlined),
                  onPressed: () => setState(() => p.time = null),
                ),
              if (d != null)
                IconButton(
                  key: Key('$key-clear'),
                  tooltip: 'Remove $label',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    p.date = null;
                    p.time = null;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _repeatFields(BuildContext context) {
    final interval = int.tryParse(_interval.text.trim()) ?? 1;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            const Text('Every'),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: TextField(
                key: const Key('repeat-interval'),
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<RepeatFrequency>(
              key: const Key('repeat-frequency'),
              value: _frequency,
              onChanged: (f) => setState(() => _frequency = f ?? _frequency),
              items: [
                for (final f in RepeatFrequency.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(switch (f) {
                      RepeatFrequency.daily => interval == 1 ? 'day' : 'days',
                      RepeatFrequency.weekly => interval == 1 ? 'week' : 'weeks',
                      RepeatFrequency.monthly => interval == 1 ? 'month' : 'months',
                      RepeatFrequency.yearly => interval == 1 ? 'year' : 'years',
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (_frequency == RepeatFrequency.weekly) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in _weekOrder(widget.defaults.firstDayOfWeek))
                FilterChip(
                  key: Key('weekday-${d.name}'),
                  label: Text(weekdayShort(d)),
                  tooltip: weekdayLong(d),
                  selected: _weekdays.contains(d),
                  onSelected: (on) =>
                      setState(() => on ? _weekdays.add(d) : _weekdays.remove(d)),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('With no day chosen it repeats on the start\'s weekday.'),
        ),
        if (interval > 1)
          _choice<Weekday>(
            'Weeks start on',
            _weekStart,
            (v) => _weekStart = v,
            {Weekday.monday: 'Monday', Weekday.sunday: 'Sunday'},
            'week-start',
          ),
      ],
      if (_frequency == RepeatFrequency.monthly || _frequency == RepeatFrequency.yearly)
        _choice<MonthEndChoice>(
          'In a month without that day',
          _monthEnd,
          (v) => _monthEnd = v,
          {
            MonthEndChoice.skip: 'Skip that month',
            MonthEndChoice.lastDay: 'Use the last day of the month',
          },
          'month-end',
        ),
      _choice<_EndKind>(
        'Ends',
        _endKind,
        (v) => _endKind = v,
        {
          _EndKind.never: 'Never',
          _EndKind.onDate: 'On a date',
          _EndKind.afterCount: 'After a number of times',
        },
        'repeat-end',
      ),
      if (_endKind == _EndKind.onDate)
        ListTile(
          key: const Key('repeat-until'),
          leading: const Icon(Icons.event),
          title: const Text('Last date'),
          subtitle: Text(_until == null
              ? 'Choose a date'
              : formatDateLong(_until!, today: _today)),
          onTap: () async {
            final picked = await _pickDate(_until ?? _start.date, 'Last date');
            if (picked != null) setState(() => _until = picked);
          },
        ),
      if (_endKind == _EndKind.afterCount)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: 160,
            child: TextField(
              key: const Key('repeat-count'),
              controller: _count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Times'),
            ),
          ),
        ),
    ];
  }

  Widget _choice<T>(String title, T value, void Function(T) set, Map<T, String> options, String key) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          ),
          RadioGroup<T>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) setState(() => set(v));
            },
            child: Column(
              children: [
                for (final e in options.entries)
                  RadioListTile<T>(
                    key: Key('$key-${e.key is Enum ? (e.key as Enum).name : e.key}'),
                    value: e.key,
                    title: Text(e.value),
                  ),
              ],
            ),
          ),
        ],
      );
}

/// The seven days starting at [first].
List<Weekday> _weekOrder(Weekday first) =>
    [for (var i = 0; i < 7; i++) Weekday.values[(first.index + i) % 7]];

/// Search and pick an IANA zone.
class _ZoneDialog extends StatefulWidget {
  const _ZoneDialog({required this.zones, required this.current, required this.device});
  final List<String> zones;
  final String current;
  final String device;

  @override
  State<_ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<_ZoneDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().replaceAll(' ', '_');
    final shown = [
      widget.device,
      for (final z in widget.zones)
        if (z != widget.device) z,
    ].where((z) => q.isEmpty || z.toLowerCase().contains(q)).toList();
    return AlertDialog(
      title: const Text('Time zone'),
      content: SizedBox(
        width: 400,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const Key('zone-search'),
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Search', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final z = shown[i];
                  return ListTile(
                    key: Key('zone-$z'),
                    title: Text(z),
                    subtitle: z == widget.device ? const Text('This device') : null,
                    selected: z == widget.current,
                    trailing: z == widget.current ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, z),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
