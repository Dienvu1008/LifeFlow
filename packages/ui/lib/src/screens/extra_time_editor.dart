// P06c E3 (ADR-0097): the other times of a task or an event: a list ("Other
// times") with add, change and remove, and the editor of one (start, end, and
// its own repeat). The editor only collects input; the rules are checked by
// the command (ExtraTimes) and its reason is shown here (AP-12).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../l10n.dart';
import '../messages.dart';
import '../providers.dart';
import '../schedule_text.dart';
import '../task_actions.dart' show reportResult;
import '../widgets/schedule_fields.dart';
import 'schedule_editor.dart';

/// Opens the editor of one other time of [subjectId]: a new one, or [initial]
/// changed. A new one starts on [date] (default today) at [time] (default 09:00).
Future<void> openExtraTimeEditor(
  BuildContext context,
  WidgetRef ref, {
  required ExtraTimeSubject subject,
  required String subjectId,
  required String title,
  ExtraTimeView? initial,
  LocalDate? date,
  TimeOfDayValue? time,
}) async {
  final defaults = await readPlanningDefaults(ref);
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ExtraTimeEditorPage(
        subject: subject,
        subjectId: subjectId,
        itemTitle: title,
        initial: initial,
        date: date,
        time: time,
        defaults: defaults),
  ));
}

class ExtraTimeEditorPage extends ConsumerStatefulWidget {
  const ExtraTimeEditorPage({
    super.key,
    required this.subject,
    required this.subjectId,
    required this.itemTitle,
    required this.defaults,
    this.initial,
    this.date,
    this.time,
  });
  final ExtraTimeSubject subject;
  final String subjectId;
  final String itemTitle;
  final ExtraTimeView? initial;
  final LocalDate? date;
  final TimeOfDayValue? time;
  final PlanningSettings defaults;

  @override
  ConsumerState<ExtraTimeEditorPage> createState() => _ExtraTimeEditorPageState();
}

class _ExtraTimeEditorPageState extends ConsumerState<ExtraTimeEditorPage> {
  late final PointDraft _start;
  late final PointDraft _end;
  late String _zone;
  late final _repeat =
      RepeatDraft(monthEnd: widget.defaults.defaultMonthEnd, weekStart: widget.defaults.firstDayOfWeek)
        ..load(widget.initial?.repeat);
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final device = ref.read(deviceZoneProvider);
    if (i == null) {
      // A new time: one hour from 09:00 (or the tapped slot), in the device zone.
      final d = widget.date ?? ref.read(todayProvider)();
      final s = widget.time ?? TimeOfDayValue(9, 0);
      final e = (s.minuteOfDay + 60).clamp(0, 23 * 60 + 59);
      _start = PointDraft(SchedulePointInput.at(d, s, device));
      _end = PointDraft(SchedulePointInput.at(d, TimeOfDayValue(e ~/ 60, e % 60), device));
      _zone = device;
    } else {
      _start = PointDraft(i.start);
      _end = PointDraft(i.end);
      _zone = i.start.zone ?? i.end?.zone ?? device;
    }
  }

  @override
  void dispose() {
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final start = _start.input(_zone);
    if (start == null) return setState(() => _error = 'Choose when it starts.');
    final r = _repeat.build();
    if (r.error != null) return setState(() => _error = r.error);
    final input = ExtraTimeInput(start: start, end: _end.input(_zone), repeat: r.value);
    final extras = ref.read(extraTimesProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final initial = widget.initial;
    final result = initial == null
        ? await extras.add(widget.subject, widget.subjectId, input)
        : await extras.change(initial.id, input);
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
    final l = context.l10n;
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
          tooltip: l.cancel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
            widget.initial == null
                ? l.extraAddTitle(widget.itemTitle)
                : l.extraChangeTitle(widget.itemTitle),
            overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            key: const Key('extra-save'),
            onPressed: _busy ? null : _save,
            child: Text(l.save),
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
          if (_start.hasTime || _end.hasTime)
            ZoneField(
              zone: _zone,
              deviceZone: device,
              zones: () => ref.read(zoneCatalogProvider).zoneNames(),
              onChanged: (z) => setState(() => _zone = z),
            ),
          const EditorSection('Repeat'),
          RepeatFields(
              draft: _repeat, firstDayOfWeek: widget.defaults.firstDayOfWeek, today: today, anchor: _start.date),
        ],
      ),
    );
  }
}

/// "Other times" of a task or an event: each with its date, hours and repeat;
/// tap one to change it, the cross removes it; a button adds one.
class ExtraTimesSection extends ConsumerStatefulWidget {
  const ExtraTimesSection({super.key, required this.subject, required this.subjectId, required this.title});
  final ExtraTimeSubject subject;
  final String subjectId;
  final String title;

  @override
  ConsumerState<ExtraTimesSection> createState() => _ExtraTimesSectionState();
}

class _ExtraTimesSectionState extends ConsumerState<ExtraTimesSection> {
  late Future<List<ExtraTimeView>> _list = _load();

  Future<List<ExtraTimeView>> _load() => ref.read(extraTimesProvider).of(widget.subject, widget.subjectId);
  void _reload() => setState(() {
        _list = _load();
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = ref.watch(todayProvider)();
    final zone = ref.watch(deviceZoneProvider);
    return FutureBuilder<List<ExtraTimeView>>(
      future: _list,
      builder: (context, snap) {
        final list = snap.data ?? const <ExtraTimeView>[];
        return Column(
          key: const Key('extra-times'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorSection(l.extraOtherTimes),
            if (snap.hasData && list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l.extraNone),
              ),
            for (final x in list)
              ListTile(
                key: ValueKey('extra-${x.id}'),
                leading: const Icon(Icons.more_time_outlined),
                title: Text(describeSchedule(TaskScheduleInput(start: x.start, end: x.end, repeat: x.repeat),
                    today: today, deviceZone: zone)),
                onTap: () async {
                  await openExtraTimeEditor(context, ref,
                      subject: widget.subject, subjectId: widget.subjectId, title: widget.title, initial: x);
                  if (mounted) _reload();
                },
                trailing: IconButton(
                  tooltip: l.extraRemoveTooltip(formatDate(x.start.date, today: today)),
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    await reportResult(context, ref.read(extraTimesProvider).remove(x.id));
                    if (mounted) _reload();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('extra-add'),
                  onPressed: () async {
                    await openExtraTimeEditor(context, ref,
                        subject: widget.subject, subjectId: widget.subjectId, title: widget.title);
                    if (mounted) _reload();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l.extraAdd),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
