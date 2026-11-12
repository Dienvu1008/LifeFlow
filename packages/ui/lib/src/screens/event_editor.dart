// P02 T6b: create or edit an event (title, start, end, zone, location,
// calendar, repeat). Editing here changes ALL occurrences; one occurrence
// is changed from its actions (owner decision D4). An event is never a task
// (D6). Rules are checked by the command (EventService); the reason of a
// refusal is shown here (AP-12).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';

import '../messages.dart';
import '../providers.dart';
import '../widgets/schedule_fields.dart';
import 'schedule_editor.dart';
import '../l10n.dart';

/// Opens the editor: a new event on [date], or the event [eventId].
Future<void> openEventEditor(BuildContext context, WidgetRef ref, {String? eventId, LocalDate? date}) async {
  final defaults = await readPlanningDefaults(ref);
  EventDetails? existing;
  if (eventId != null) {
    existing = await ref.read(eventServiceProvider).details(eventId);
    if (existing == null) {
      if (context.mounted) _snack(context, 'That event no longer exists.');
      return;
    }
  }
  final reminders = eventId == null ? const <ReminderInput>[] : await readReminders(ref, ReminderSubject.event, eventId);
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) =>
        EventEditorPage(existing: existing, date: date, defaults: defaults, initialReminders: reminders),
  ));
}

void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage(
      {super.key, this.existing, this.date, required this.defaults, this.initialReminders = const []});
  final EventDetails? existing;
  final List<ReminderInput> initialReminders;

  /// The day a new event goes on (default: today).
  final LocalDate? date;
  final PlanningSettings defaults;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  late final EventInput? _in = widget.existing?.input;
  late final _title = TextEditingController(text: _in?.title ?? '');
  late final _location = TextEditingController(text: _in?.location ?? '');
  late final PointDraft _start;
  late final PointDraft _end;
  late String _zone;
  String? _calendarId;
  late final _repeat =
      RepeatDraft(monthEnd: widget.defaults.defaultMonthEnd, weekStart: widget.defaults.firstDayOfWeek)
        ..load(_in?.repeat);
  late final _reminders = List<ReminderInput>.of(widget.initialReminders);
  String? _reminderNote;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final i = _in;
    final device = ref.read(deviceZoneProvider);
    if (i == null) {
      // A new event: one hour from 09:00 in the device zone (D10).
      final d = widget.date ?? ref.read(todayProvider)();
      _start = PointDraft(SchedulePointInput.at(d, TimeOfDayValue(9, 0), device));
      _end = PointDraft(SchedulePointInput.at(d, TimeOfDayValue(10, 0), device));
      _zone = device;
    } else {
      _start = PointDraft(i.start);
      _end = PointDraft(i.end);
      _zone = i.start.zone ?? i.end?.zone ?? device;
      _calendarId = i.calendarId;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Enter a title.');
    final start = _start.input(_zone);
    if (start == null) return setState(() => _error = 'Choose when it starts.');
    final r = _repeat.build();
    if (r.error != null) return setState(() => _error = r.error);
    final location = _location.text.trim();
    final input = EventInput(
      title: title,
      start: start,
      end: _end.input(_zone),
      location: location.isEmpty ? null : location,
      calendarId: _calendarId,
      repeat: r.value,
    );
    final events = ref.read(eventServiceProvider);
    final existing = widget.existing;
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final saved = existing == null ? await events.create(input) : await events.update(existing.id, input);
      if (saved is! CommandOk || sameReminders(_reminders, widget.initialReminders)) return saved;
      // The reminders are a second command on the (now existing) event.
      final r = await ref.read(reminderServiceProvider).setReminders(ReminderSubject.event, saved.entityId, _reminders);
      if (r is CommandFailure && existing == null) {
        // The event exists now: close (saving again would make a second one)
        // and say what was not saved.
        messenger.showSnackBar(SnackBar(content: Text(context.l10n.eventSavedRemindersFailed(describeFailure(r)))));
        return saved;
      }
      return r;
    }());
  }

  Future<void> _trash() async {
    final id = widget.existing!.id;
    final events = ref.read(eventServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _run(events.trash(id));
    if (ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(context.l10n.eventMovedToTheTrash),
          action: SnackBarAction(label: context.l10n.undo, onPressed: () => events.restore(id)),
        ));
    }
  }

  /// Runs a command; pops on success. Returns whether it succeeded.
  Future<bool> _run(Future<CommandResult> pending) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await pending;
    if (!mounted) return result is! CommandFailure;
    if (result is CommandFailure) {
      setState(() {
        _busy = false;
        _error = describeFailure(result);
      });
      return false;
    }
    Navigator.of(context).pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceZoneProvider);
    final today = ref.watch(todayProvider)();
    final calendars = ref.watch(calendarsProvider).value ?? const <CalendarView>[];
    final editing = widget.existing != null;
    Widget point(String label, String key, PointDraft p, {bool removable = true}) => PointField(
        label: label,
        fieldKey: key,
        point: p,
        zone: _zone,
        deviceZone: device,
        today: today,
        removable: removable,
        onChanged: () => setState(() {}));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            tooltip: context.l10n.cancel, icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: Text(editing ? 'Edit event' : 'New event'),
        actions: [
          TextButton(key: const Key('event-save'), onPressed: _busy ? null : _save, child: Text(context.l10n.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_error != null) EditorError(_error!),
          if (editing && (widget.existing!.input.repeat != null))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(context.l10n.eventRepeatHint),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('event-title'),
              controller: _title,
              autofocus: !editing,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: context.l10n.title),
            ),
          ),
          const EditorSection('When'),
          point('Start', 'event-start', _start, removable: false),
          point('End', 'event-end', _end),
          if (!_start.hasTime && !_end.hasTime && _start.date != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(context.l10n.allDayAllDayEventsNever),
            ),
          if (_start.hasTime || _end.hasTime)
            ZoneField(
              zone: _zone,
              deviceZone: device,
              zones: () => ref.read(zoneCatalogProvider).zoneNames(),
              onChanged: (z) => setState(() => _zone = z),
            ),
          const EditorSection('Details'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              key: const Key('event-location'),
              controller: _location,
              decoration: InputDecoration(labelText: context.l10n.locationOptional),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: DropdownButtonFormField<String?>(
              key: const Key('event-calendar'),
              initialValue: calendars.any((c) => c.id == _calendarId) ? _calendarId : null,
              decoration: InputDecoration(labelText: context.l10n.calendar),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(context.l10n.noCalendar)),
                for (final c in calendars)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(children: [
                      Icon(Icons.circle, size: 14, color: Color(c.color)),
                      const SizedBox(width: 8),
                      Text(c.name),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _calendarId = v),
            ),
          ),
          const EditorSection('Repeat'),
          RepeatFields(
              draft: _repeat, firstDayOfWeek: widget.defaults.firstDayOfWeek, today: today, anchor: _start.date),
          const EditorSection('Reminders'),
          ReminderFields(
            reminders: _reminders,
            anchor: _start.date == null ? null : 'start',
            allDay: !_start.hasTime,
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
          if (editing) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                key: const Key('event-trash'),
                onPressed: _busy ? null : _trash,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.moveToTrash),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
