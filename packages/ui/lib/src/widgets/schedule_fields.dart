// P02 T6a/T6b: the parts of a schedule editor shared by tasks and events:
// a date with an optional time, the repeat fields and the zone picker.
// They collect input only; rules are checked by the commands (AP-12).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:foundation/foundation.dart';

import '../schedule_text.dart';

/// A date with an optional time, as edited.
class PointDraft {
  PointDraft([SchedulePointInput? p])
      : date = p?.date,
        time = p?.time;
  LocalDate? date;
  TimeOfDayValue? time;

  bool get hasTime => date != null && time != null;

  /// The input in [zone], or null when no date is set.
  SchedulePointInput? input(String zone) {
    final d = date;
    if (d == null) return null;
    final t = time;
    return t == null ? SchedulePointInput.date(d) : SchedulePointInput.at(d, t, zone);
  }
}

/// The platform date picker, as a [LocalDate].
Future<LocalDate?> pickLocalDate(BuildContext context,
    {LocalDate? current, required LocalDate today, String? help}) async {
  final c = current ?? today;
  final picked = await showDatePicker(
    context: context,
    helpText: help,
    initialDate: DateTime(c.year, c.month, c.day),
    firstDate: DateTime(1900),
    lastDate: DateTime(2200, 12, 31),
  );
  return picked == null ? null : LocalDate(picked.year, picked.month, picked.day);
}

/// One row: label and value, then buttons for the date, the time, removing
/// the time and removing the point. Keys: `<key>-date`, `<key>-time`,
/// `<key>-clear-time`, `<key>-clear`, `<key>-value`.
class PointField extends StatelessWidget {
  const PointField({
    super.key,
    required this.label,
    required this.fieldKey,
    required this.point,
    required this.zone,
    required this.deviceZone,
    required this.today,
    required this.onChanged,
    this.removable = true,
  });

  final String label;
  final String fieldKey;
  final PointDraft point;
  final String zone;
  final String deviceZone;
  final LocalDate today;

  /// Called after the draft changed.
  final VoidCallback onChanged;

  /// False for a required point (an event's start): no remove button.
  final bool removable;

  @override
  Widget build(BuildContext context) {
    final p = point;
    final d = p.date;
    final value = p.input(zone);
    final k = fieldKey;
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
                  value == null ? 'Not set' : formatPoint(value, today: today, deviceZone: deviceZone),
                  key: Key('$k-value'),
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
                key: Key('$k-date'),
                tooltip: d == null ? 'Set $label date' : 'Change $label date',
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final picked = await pickLocalDate(context, current: d, today: today, help: '$label date');
                  if (picked != null) {
                    p.date = picked;
                    onChanged();
                  }
                },
              ),
              if (d != null)
                IconButton(
                  key: Key('$k-time'),
                  tooltip: p.time == null ? 'Add $label time' : 'Change $label time',
                  icon: Icon(p.time == null ? Icons.more_time : Icons.schedule),
                  onPressed: () async {
                    final t = p.time ?? TimeOfDayValue(9, 0);
                    final picked = await showTimePicker(
                        context: context,
                        helpText: '$label time',
                        initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
                    if (picked != null) {
                      p.time = TimeOfDayValue(picked.hour, picked.minute);
                      onChanged();
                    }
                  },
                ),
              if (p.time != null)
                IconButton(
                  key: Key('$k-clear-time'),
                  tooltip: 'Remove $label time',
                  icon: const Icon(Icons.timer_off_outlined),
                  onPressed: () {
                    p.time = null;
                    onChanged();
                  },
                ),
              if (d != null && removable)
                IconButton(
                  key: Key('$k-clear'),
                  tooltip: 'Remove $label',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    p.date = null;
                    p.time = null;
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The zone row; opens [ZoneDialog].
class ZoneField extends StatelessWidget {
  const ZoneField({
    super.key,
    required this.zone,
    required this.deviceZone,
    required this.zones,
    required this.onChanged,
  });
  final String zone;
  final String deviceZone;
  final List<String> Function() zones;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('schedule-zone'),
        leading: const Icon(Icons.public),
        title: const Text('Time zone'),
        subtitle: Text(zone == deviceZone ? '$zone (this device)' : zone),
        onTap: () async {
          final z = await showDialog<String>(
            context: context,
            builder: (_) => ZoneDialog(zones: zones(), current: zone, device: deviceZone),
          );
          if (z != null) onChanged(z);
        },
      );
}

enum RepeatEndKind { never, onDate, afterCount }

/// The repeat part of an editor, as edited. New repeats start from the
/// device defaults; [load] takes an existing repeat with its own rule.
class RepeatDraft {
  RepeatDraft({required this.monthEnd, required this.weekStart});

  bool on = false;
  RepeatFrequency frequency = RepeatFrequency.daily;
  final interval = TextEditingController(text: '1');
  final weekdays = <Weekday>{};
  RepeatEndKind endKind = RepeatEndKind.never;
  LocalDate? until;
  final count = TextEditingController(text: '10');
  MonthEndChoice monthEnd;
  Weekday weekStart;

  void load(RepeatInput? r) {
    if (r == null) return;
    on = true;
    frequency = r.frequency;
    interval.text = '${r.interval}';
    weekdays
      ..clear()
      ..addAll(r.weekdays ?? const {});
    switch (r.end) {
      case RepeatForever():
        endKind = RepeatEndKind.never;
      case RepeatUntil(:final date):
        endKind = RepeatEndKind.onDate;
        until = date;
      case RepeatTimes(:final count):
        endKind = RepeatEndKind.afterCount;
        this.count.text = '$count';
    }
    // Each repeat keeps its own rule (D2/D3 refinement).
    monthEnd = r.monthEnd;
    weekStart = r.weekStart;
  }

  /// The repeat (null when off), or a message about a field that cannot be
  /// read.
  ({RepeatInput? value, String? error}) build() {
    if (!on) return (value: null, error: null);
    final n = int.tryParse(interval.text.trim());
    if (n == null) return (value: null, error: 'Enter how often it repeats.');
    final RepeatEnd end;
    switch (endKind) {
      case RepeatEndKind.never:
        end = const RepeatForever();
      case RepeatEndKind.onDate:
        final u = until;
        if (u == null) return (value: null, error: 'Choose the date the repeat ends.');
        end = RepeatUntil(u);
      case RepeatEndKind.afterCount:
        final c = int.tryParse(count.text.trim());
        if (c == null) return (value: null, error: 'Enter how many times it repeats.');
        end = RepeatTimes(c);
    }
    return (
      value: RepeatInput(
        frequency: frequency,
        interval: n,
        // None chosen: the start's own weekday.
        weekdays: frequency == RepeatFrequency.weekly && weekdays.isNotEmpty ? Set.of(weekdays) : null,
        end: end,
        monthEnd: monthEnd,
        weekStart: weekStart,
      ),
      error: null
    );
  }

  void dispose() {
    interval.dispose();
    count.dispose();
  }
}

/// The repeat switch and, when on, its fields. Weekday chips are ordered
/// from [firstDayOfWeek] (D3).
class RepeatFields extends StatefulWidget {
  const RepeatFields({
    super.key,
    required this.draft,
    required this.firstDayOfWeek,
    required this.today,
    this.anchor,
  });
  final RepeatDraft draft;
  final Weekday firstDayOfWeek;
  final LocalDate today;

  /// Where the "last date" picker opens (the start date).
  final LocalDate? anchor;

  @override
  State<RepeatFields> createState() => _RepeatFieldsState();
}

class _RepeatFieldsState extends State<RepeatFields> {
  RepeatDraft get r => widget.draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('repeat-switch'),
          title: const Text('Repeat'),
          value: r.on,
          onChanged: (v) => setState(() => r.on = v),
        ),
        if (r.on) ..._fields(context),
      ],
    );
  }

  List<Widget> _fields(BuildContext context) {
    final n = int.tryParse(r.interval.text.trim()) ?? 1;
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
                controller: r.interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<RepeatFrequency>(
              key: const Key('repeat-frequency'),
              value: r.frequency,
              onChanged: (f) => setState(() => r.frequency = f ?? r.frequency),
              items: [
                for (final f in RepeatFrequency.values)
                  DropdownMenuItem(
                    value: f,
                    child: Text(switch (f) {
                      RepeatFrequency.daily => n == 1 ? 'day' : 'days',
                      RepeatFrequency.weekly => n == 1 ? 'week' : 'weeks',
                      RepeatFrequency.monthly => n == 1 ? 'month' : 'months',
                      RepeatFrequency.yearly => n == 1 ? 'year' : 'years',
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (r.frequency == RepeatFrequency.weekly) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in weekFrom(widget.firstDayOfWeek))
                FilterChip(
                  key: Key('weekday-${d.name}'),
                  label: Text(weekdayShort(d)),
                  tooltip: weekdayLong(d),
                  selected: r.weekdays.contains(d),
                  onSelected: (on) => setState(() => on ? r.weekdays.add(d) : r.weekdays.remove(d)),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('With no day chosen it repeats on the start\'s weekday.'),
        ),
        if (n > 1)
          _choice<Weekday>('Weeks start on', r.weekStart, (v) => r.weekStart = v,
              {Weekday.monday: 'Monday', Weekday.sunday: 'Sunday'}, 'week-start'),
      ],
      if (r.frequency == RepeatFrequency.monthly || r.frequency == RepeatFrequency.yearly)
        _choice<MonthEndChoice>(
          'In a month without that day',
          r.monthEnd,
          (v) => r.monthEnd = v,
          {
            MonthEndChoice.skip: 'Skip that month',
            MonthEndChoice.lastDay: 'Use the last day of the month',
          },
          'month-end',
        ),
      _choice<RepeatEndKind>(
        'Ends',
        r.endKind,
        (v) => r.endKind = v,
        {
          RepeatEndKind.never: 'Never',
          RepeatEndKind.onDate: 'On a date',
          RepeatEndKind.afterCount: 'After a number of times',
        },
        'repeat-end',
      ),
      if (r.endKind == RepeatEndKind.onDate)
        ListTile(
          key: const Key('repeat-until'),
          leading: const Icon(Icons.event),
          title: const Text('Last date'),
          subtitle: Text(r.until == null ? 'Choose a date' : formatDateLong(r.until!, today: widget.today)),
          onTap: () async {
            final picked = await pickLocalDate(context,
                current: r.until ?? widget.anchor, today: widget.today, help: 'Last date');
            if (picked != null) setState(() => r.until = picked);
          },
        ),
      if (r.endKind == RepeatEndKind.afterCount)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: 160,
            child: TextField(
              key: const Key('repeat-count'),
              controller: r.count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Times'),
            ),
          ),
        ),
    ];
  }

  Widget _choice<T>(String title, T value, void Function(T) set, Map<T, String> options, String key) => Column(
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
List<Weekday> weekFrom(Weekday first) => [for (var i = 0; i < 7; i++) Weekday.values[(first.index + i) % 7]];

/// Search and pick an IANA zone. The device zone is listed first.
class ZoneDialog extends StatefulWidget {
  const ZoneDialog({super.key, required this.zones, required this.current, required this.device});
  final List<String> zones;
  final String current;
  final String device;

  @override
  State<ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<ZoneDialog> {
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
              decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search)),
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

// --- reminders (P02 T7) -------------------------------------------------------

const _timedPresets = [0, 5, 10, 15, 30, 60, 120, 1440];
const _allDayPresets = [0, 1440, 2 * 1440, 7 * 1440];

/// The reminders of an item, as chips, with "Add reminder". The list is
/// edited in place; [onChanged] is called after every change. Without a
/// schedule ([anchor] null) only a reminder at a date and time is offered.
class ReminderFields extends StatelessWidget {
  const ReminderFields({
    super.key,
    required this.reminders,
    required this.anchor,
    required this.allDay,
    required this.today,
    required this.onChanged,
    this.note,
  });

  final List<ReminderInput> reminders;

  /// 'start', 'deadline' or 'end'; null when the item has no date yet.
  final String? anchor;
  final bool allDay;
  final LocalDate today;

  /// Called after a change, with whether a reminder was added.
  final void Function({required bool added}) onChanged;

  /// Shown under the chips (for example: notifications are off).
  final String? note;

  @override
  Widget build(BuildContext context) {
    final a = anchor;
    final presets = a == null ? const <int>[] : (allDay ? _allDayPresets : _timedPresets);
    final has = reminders.whereType<RemindMinutesBefore>().map((r) => r.minutes).toSet();
    final full = reminders.length >= 5;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < reminders.length; i++)
                InputChip(
                  key: Key('reminder-$i'),
                  avatar: const Icon(Icons.notifications_outlined, size: 18),
                  label: Text(describeReminder(reminders[i], anchor: a ?? 'start', allDay: allDay, today: today)),
                  deleteButtonTooltipMessage: 'Remove this reminder',
                  onDeleted: () {
                    reminders.removeAt(i);
                    onChanged(added: false);
                  },
                ),
              if (!full)
                PopupMenuButton<int>(
                  key: const Key('reminder-add'),
                  tooltip: 'Add reminder',
                  onSelected: (v) async {
                    final ReminderInput? r = switch (v) {
                      -1 => await _custom(context),
                      -2 => await _atTime(context),
                      _ => RemindMinutesBefore(v),
                    };
                    if (r == null || reminders.contains(r)) return;
                    reminders.add(r);
                    onChanged(added: true);
                  },
                  itemBuilder: (_) => [
                    for (final m in presets)
                      if (!has.contains(m))
                        PopupMenuItem(
                          value: m,
                          child: Text(describeReminder(RemindMinutesBefore(m),
                              anchor: a!, allDay: allDay, today: today)),
                        ),
                    if (a != null) const PopupMenuItem(value: -1, child: Text('Custom…')),
                    const PopupMenuItem(value: -2, child: Text('At a date and time…')),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.add_alert_outlined, size: 18),
                    label: Text('Add reminder'),
                  ),
                ),
            ],
          ),
          if (a == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Set a date to be reminded before it.'),
            ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(note!,
                    key: const Key('reminder-note'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
        ],
      ),
    );
  }

  Future<ReminderInput?> _custom(BuildContext context) async {
    final m = await showDialog<int>(context: context, builder: (_) => const _OffsetDialog());
    return m == null ? null : RemindMinutesBefore(m);
  }

  Future<ReminderInput?> _atTime(BuildContext context) async {
    final d = await pickLocalDate(context, today: today, help: 'Remind on');
    if (d == null || !context.mounted) return null;
    final t = await showTimePicker(
        context: context, helpText: 'Remind at', initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (t == null) return null;
    // The device's local time is the device zone (D10).
    return RemindAtInstant(Instant(DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc()));
  }
}

/// "N minutes / hours / days / weeks before", at most 28 days.
class _OffsetDialog extends StatefulWidget {
  const _OffsetDialog();
  @override
  State<_OffsetDialog> createState() => _OffsetDialogState();
}

class _OffsetDialogState extends State<_OffsetDialog> {
  final _c = TextEditingController(text: '1');
  int _unit = 60;
  String? _error;

  static const _units = {1: 'minutes', 60: 'hours', 1440: 'days', 10080: 'weeks'};

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_c.text.trim());
    final m = n == null ? null : n * _unit;
    if (m == null || m < 1 || m > 28 * 1440) {
      setState(() => _error = 'From 1 minute to 4 weeks.');
      return;
    }
    Navigator.pop(context, m);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Remind before'),
        content: Row(
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                key: const Key('offset-number'),
                controller: _c,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(errorText: _error, errorMaxLines: 2),
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
              key: const Key('offset-unit'),
              value: _unit,
              onChanged: (u) => setState(() => _unit = u ?? _unit),
              items: [for (final e in _units.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Add')),
        ],
      );
}
