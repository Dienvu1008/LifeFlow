// P02 T6a: the schedule editor of a task (start, end, deadline, repeat).
// The editor only collects input; the rules are checked by the command
// (TaskScheduling.setSchedule) and its reason is shown here (AP-12).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../messages.dart';
import '../providers.dart';
import '../widgets/schedule_fields.dart';

/// The device's calendar settings, or the built-in defaults.
Future<PlanningSettings> readPlanningDefaults(WidgetRef ref) async {
  try {
    return await ref.read(settingsServiceProvider).planningSettings();
  } catch (_) {
    return const PlanningSettings();
  }
}

/// Opens the editor for [taskId] over the whole app. New repeats take their
/// month-end rule and week start from the device settings (D2/D3).
Future<void> openScheduleEditor(
  BuildContext context,
  WidgetRef ref, {
  required String taskId,
  required String title,
  TaskScheduleInput? initial,
}) async {
  final defaults = await readPlanningDefaults(ref);
  final reminders = await readReminders(ref, ReminderSubject.task, taskId);
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ScheduleEditorPage(
        taskId: taskId, taskTitle: title, initial: initial, defaults: defaults, initialReminders: reminders),
  ));
}

/// The stored reminders of an item, or none when they cannot be read.
Future<List<ReminderInput>> readReminders(WidgetRef ref, ReminderSubject subject, String id) async {
  try {
    return await ref.read(reminderServiceProvider).remindersOf(subject, id);
  } catch (_) {
    return const [];
  }
}

/// After the first reminder is added: asks the device for permission once.
/// Returns a note to show when reminders will not appear, else null.
Future<String?> ensureReminderPermission(WidgetRef ref) async {
  try {
    final scheduler = ref.read(reminderSchedulerProvider);
    final status = await scheduler.status();
    if (!status.supported) return 'This device does not show reminders.';
    if (status.allowed) return null;
    if (!status.canAsk) {
      return 'Notifications are off for LifeFlow, so reminders will not show. '
          'Turn LifeFlow on in your system\'s notification settings.';
    }
    final ok = await scheduler.requestPermission();
    ref.invalidate(reminderStatusProvider);
    return ok ? null : 'Notifications are off for LifeFlow, so reminders will not show. '
        'You can allow them in Settings → Reminders.';
  } catch (_) {
    return null;
  }
}

/// The point reminders count from in an editor: ('start'|'deadline'|'end',
/// all day?), or null without a date.
(String, bool)? reminderAnchorOf(PointDraft start, PointDraft due, PointDraft end) {
  for (final (name, p) in [('start', start), ('deadline', due), ('end', end)]) {
    if (p.date != null) return (name, p.time == null);
  }
  return null;
}

bool sameReminders(List<ReminderInput> a, List<ReminderInput> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class ScheduleEditorPage extends ConsumerStatefulWidget {
  const ScheduleEditorPage({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.defaults,
    this.initial,
    this.initialReminders = const [],
  });

  final String taskId;
  final String taskTitle;
  final TaskScheduleInput? initial;
  final PlanningSettings defaults;
  final List<ReminderInput> initialReminders;

  @override
  ConsumerState<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends ConsumerState<ScheduleEditorPage> {
  late final _start = PointDraft(widget.initial?.start);
  late final _end = PointDraft(widget.initial?.end);
  late final _due = PointDraft(widget.initial?.deadline);
  late String _zone;
  late final _repeat = RepeatDraft(
      monthEnd: widget.defaults.defaultMonthEnd, weekStart: widget.defaults.firstDayOfWeek)
    ..load(widget.initial?.repeat);

  late final _reminders = List<ReminderInput>.of(widget.initialReminders);
  String? _reminderNote;

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _zone = [s?.start, s?.end, s?.deadline].map((p) => p?.zone).nonNulls.firstOrNull ??
        ref.read(deviceZoneProvider);
  }

  @override
  void dispose() {
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final r = _repeat.build();
    if (r.error != null) {
      setState(() => _error = r.error);
      return;
    }
    final input = TaskScheduleInput(
        start: _start.input(_zone), end: _end.input(_zone), deadline: _due.input(_zone), repeat: r.value);
    // No date and no repeat: no schedule (a reminder at a date and time
    // needs none); an existing schedule is cleared.
    final empty = input.start == null && input.end == null && input.deadline == null && input.repeat == null;
    await _run(() async {
      final scheduling = ref.read(taskSchedulingProvider);
      if (!empty || widget.initial != null) {
        final saved = await scheduling.setSchedule(widget.taskId, empty ? null : input);
        if (saved is CommandFailure) return saved;
      }
      // Reminders counting from a date need one.
      return _saveReminders(empty ? [for (final r in _reminders) if (r is RemindAtInstant) r] : _reminders);
    });
  }

  /// Removing the schedule also removes the reminders that count from it;
  /// a reminder at a date and time stays.
  Future<void> _remove() => _run(() async {
        final cleared = await ref.read(taskSchedulingProvider).setSchedule(widget.taskId, null);
        if (cleared is CommandFailure) return cleared;
        return _saveReminders([for (final r in _reminders) if (r is RemindAtInstant) r]);
      });

  Future<CommandResult?> _saveReminders(List<ReminderInput> list) async {
    if (sameReminders(list, widget.initialReminders)) return null;
    final r = await ref.read(reminderServiceProvider).setReminders(ReminderSubject.task, widget.taskId, list);
    return r is CommandFailure ? r : null;
  }

  /// Runs the save; a failure (of the schedule or of the reminders) stays
  /// in the editor with its reason.
  Future<void> _run(Future<CommandResult?> Function() save) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await save();
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

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceZoneProvider);
    final today = ref.watch(todayProvider)();
    Widget point(String label, String key, PointDraft p) => PointField(
        label: label,
        fieldKey: key,
        point: p,
        zone: _zone,
        deviceZone: device,
        today: today,
        onChanged: () => setState(() {}));
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
          if (_error != null) EditorError(_error!),
          const EditorSection('When'),
          point('Start', 'start', _start),
          point('End', 'end', _end),
          point('Deadline', 'due', _due),
          if (_start.hasTime || _end.hasTime || _due.hasTime)
            ZoneField(
              zone: _zone,
              deviceZone: device,
              zones: () => ref.read(zoneCatalogProvider).zoneNames(),
              onChanged: (z) => setState(() => _zone = z),
            ),
          const EditorSection('Repeat'),
          RepeatFields(
              draft: _repeat, firstDayOfWeek: widget.defaults.firstDayOfWeek, today: today, anchor: _start.date),
          const EditorSection('Reminders'),
          ReminderFields(
            reminders: _reminders,
            anchor: reminderAnchorOf(_start, _due, _end)?.$1,
            allDay: reminderAnchorOf(_start, _due, _end)?.$2 ?? false,
            today: today,
            note: _reminderNote,
            onChanged: ({required bool added}) async {
              setState(() {});
              if (added && _reminders.length == 1) {
                final note = await ensureReminderPermission(ref);
                if (mounted) setState(() => _reminderNote = note);
              }
            },
          ),
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
}

/// A refusal or input problem at the top of an editor (announced).
class EditorError extends StatelessWidget {
  const EditorError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Semantics(
          liveRegion: true,
          child: Text(message,
              key: const Key('schedule-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

class EditorSection extends StatelessWidget {
  const EditorSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );
}
