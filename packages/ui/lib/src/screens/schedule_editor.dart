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
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ScheduleEditorPage(taskId: taskId, taskTitle: title, initial: initial, defaults: defaults),
  ));
}

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

class _ScheduleEditorPageState extends ConsumerState<ScheduleEditorPage> {
  late final _start = PointDraft(widget.initial?.start);
  late final _end = PointDraft(widget.initial?.end);
  late final _due = PointDraft(widget.initial?.deadline);
  late String _zone;
  late final _repeat = RepeatDraft(
      monthEnd: widget.defaults.defaultMonthEnd, weekStart: widget.defaults.firstDayOfWeek)
    ..load(widget.initial?.repeat);

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
    await _run(ref.read(taskSchedulingProvider).setSchedule(widget.taskId, input));
  }

  Future<void> _remove() => _run(ref.read(taskSchedulingProvider).setSchedule(widget.taskId, null));

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
