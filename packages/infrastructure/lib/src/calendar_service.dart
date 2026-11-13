// P02 T5 (ADR-0031): event and calendar services, and the calendar range
// query with conflicts (FR-PLAN-11, UC-08, owner decision D7).
import 'dart:async';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'agenda_service.dart';
import 'app_database.dart';
import 'event_command_handlers.dart';
import 'profile_store.dart';
import 'schedule_inputs.dart';
import 'schedule_mapping.dart';

class _Runner {
  _Runner(this.db, this.gateway) : store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore store;
  final _uuid = const Uuid();

  Future<CommandResult> run(CommandHandler handler, String type, Map<String, Object?> payload,
      {int? expectedVersion}) async {
    final profile = await store.getActiveProfile();
    if (profile == null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    }
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: payload,
        expectedVersion: expectedVersion == null ? null : Version(expectedVersion),
        issuedAt: Instant.now(),
      ),
      handler,
    );
  }
}

class DriftEventService implements EventService {
  DriftEventService(AppDatabase db, CommandGateway gateway) : _r = _Runner(db, gateway);
  final _Runner _r;
  static const _handler = EventCommandHandler();
  AppDatabase get _db => _r.db;

  Future<Event?> _event(String id) =>
      (_db.select(_db.events)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<CommandResult> _onExisting(String id, String type, Map<String, Object?> payload,
      {bool allowTrashed = false}) async {
    final e = await _event(id);
    if (e == null || (e.deletedAt != null && !allowTrashed)) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'event not found');
    }
    return _r.run(_handler, type, {...payload, 'id': id}, expectedVersion: e.version);
  }

  Map<String, Object?>? _fields(String id, EventInput input, void Function(String) fail) {
    final schedule = TaskScheduleInput(start: input.start, end: input.end, repeat: input.repeat);
    final error = scheduleInputError(schedule);
    if (error != null) {
      fail(error);
      return null;
    }
    return scheduleFieldsJson('event', id, specOfInput(schedule), ruleOfInput(input.repeat));
  }

  Future<CommandResult> _write(String id, String op, EventInput input, {int? expectedVersion}) async {
    if (input.title.trim().isEmpty) {
      return const CommandFailure(CommandFailureKind.validationFailed, reason: 'title is empty');
    }
    String? error;
    final fields = _fields(id, input, (e) => error = e);
    if (fields == null) return CommandFailure(CommandFailureKind.validationFailed, reason: error);
    return _r.run(_handler, op == 'create' ? 'CreateEvent' : 'UpdateEvent', {
      'op': op,
      'id': id,
      'title': input.title,
      'location': input.location,
      'calendarId': input.calendarId,
      if (op == 'create') 'listId': input.listId,
      'schedule': fields,
    }, expectedVersion: expectedVersion);
  }

  @override
  Future<CommandResult> create(EventInput input) => _write(EntityId.generate().value, 'create', input);

  @override
  Future<CommandResult> update(String eventId, EventInput input) async {
    final e = await _event(eventId);
    if (e == null || e.deletedAt != null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'event not found');
    }
    return _write(eventId, 'update', input, expectedVersion: e.version);
  }

  @override
  Future<CommandResult> setCancelled(String eventId, {required bool cancelled}) =>
      _onExisting(eventId, cancelled ? 'CancelEvent' : 'UncancelEvent', {'op': 'setCancelled', 'cancelled': cancelled});

  @override
  Future<CommandResult> trash(String eventId) => _onExisting(eventId, 'TrashEvent', {'op': 'trash'});

  @override
  Future<CommandResult> restore(String eventId) =>
      _onExisting(eventId, 'RestoreEvent', {'op': 'restore'}, allowTrashed: true);

  @override
  Future<CommandResult> changeOccurrence(String eventId, LocalDate originalDate, EventOccurrenceChange? change) {
    final base = {'originalDate': '$originalDate'};
    return switch (change) {
      null => _onExisting(eventId, 'ClearEventOccurrenceChange', {...base, 'op': 'clearException'}),
      SkipEventOccurrence() => _onExisting(eventId, 'SkipEventOccurrence', {...base, 'op': 'setException', 'kind': 'skip'}),
      CancelEventOccurrence() =>
        _onExisting(eventId, 'CancelEventOccurrence', {...base, 'op': 'setException', 'kind': 'cancel'}),
      MoveEventOccurrence(:final toDate, :final toTime) => _onExisting(eventId, 'MoveEventOccurrence',
          {...base, 'op': 'setException', 'kind': 'move', 'moveDate': '$toDate', 'moveTime': toTime?.toString()}),
      EditEventOccurrence(:final title, :final location) => _onExisting(eventId, 'EditEventOccurrence', {
          ...base,
          'op': 'setException',
          'kind': 'edit',
          if (title != null) 'title': title,
          if (location != null) 'location': location,
        }),
    };
  }

  @override
  Future<EventDetails?> details(String eventId) async {
    final e = await _event(eventId);
    if (e == null || e.deletedAt != null) return null;
    final s = await (_db.select(_db.schedules)
          ..where((s) => s.id.equals(scheduleIdOf('event', eventId)) & s.deletedAt.isNull()))
        .getSingleOrNull();
    if (s == null) return null;
    final (spec, rule) = readSchedule(s);
    return EventDetails(
      id: e.id,
      isCancelled: e.status == 'cancelled',
      input: EventInput(
        title: e.title,
        start: inputOf(spec.start)!,
        end: inputOf(spec.end),
        location: e.location,
        calendarId: e.calendarId,
        repeat: repeatOf(rule),
        listId: e.listId,
      ),
    );
  }
}

class DriftCalendarService implements CalendarService {
  DriftCalendarService(AppDatabase db, CommandGateway gateway) : _r = _Runner(db, gateway);
  final _Runner _r;
  static const _handler = CalendarCommandHandler();
  AppDatabase get _db => _r.db;

  Future<Calendar?> _calendar(String id) =>
      (_db.select(_db.calendars)..where((c) => c.id.equals(id))).getSingleOrNull();

  @override
  Future<CommandResult> create(String name, {int color = 0xFF009688}) {
    if (name.trim().isEmpty) {
      return Future.value(const CommandFailure(CommandFailureKind.validationFailed, reason: 'name is empty'));
    }
    return _r.run(_handler, 'CreateCalendar',
        {'op': 'create', 'id': EntityId.generate().value, 'name': name, 'color': color});
  }

  @override
  Future<CommandResult> update(String calendarId, {String? name, int? color}) async {
    final c = await _calendar(calendarId);
    if (c == null || c.deletedAt != null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'calendar not found');
    }
    return _r.run(_handler, 'UpdateCalendar', {'op': 'update', 'id': calendarId, 'name': name, 'color': color},
        expectedVersion: c.version);
  }

  @override
  Future<CommandResult> trash(String calendarId) async {
    final c = await _calendar(calendarId);
    if (c == null || c.deletedAt != null) {
      return const CommandFailure(CommandFailureKind.notFound, reason: 'calendar not found');
    }
    return _r.run(_handler, 'TrashCalendar', {'op': 'trash', 'id': calendarId}, expectedVersion: c.version);
  }

  @override
  Stream<List<CalendarView>> watchCalendars() async* {
    final profile = await _r.store.getActiveProfile();
    if (profile == null) {
      yield const [];
      return;
    }
    yield* (_db.select(_db.calendars)
          ..where((c) => c.workspaceId.equals(profile.activeWorkspaceId.value) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm(expression: c.name)]))
        .watch()
        .map((rows) => [for (final c in rows) CalendarView(id: c.id, name: c.name, color: c.color)]);
  }
}

class DriftCalendarQueries implements CalendarQueries {
  DriftCalendarQueries(this.db, this.agenda, {tk.OccurrenceLimits Function()? limits})
      : _store = ProfileStore(db),
        _limits = limits ?? (() => tk.OccurrenceLimits.standard);
  final AppDatabase db;
  final DriftAgendaQueries agenda;
  final ProfileStore _store;
  final tk.OccurrenceLimits Function() _limits;

  @override
  Stream<CalendarRange> watchRange(LocalDate from, LocalDate to) async* {
    yield await range(from, to);
    yield* db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.tasks, db.events, db.calendars, db.schedules, db.occurrenceExceptions, db.occurrenceCompletions
        ]))
        .asyncMap((_) => range(from, to));
  }

  Future<CalendarRange> range(LocalDate from, LocalDate to) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const CalendarRange(events: [], tasks: [], conflicts: []);
    final ws = profile.activeWorkspaceId.value;
    final limits = _limits();
    final taskAgenda = await agenda.range(from, to);

    final events = {
      for (final e in await (db.select(db.events)..where((e) => e.workspaceId.equals(ws) & e.deletedAt.isNull())).get())
        e.id: e,
    };
    final f = '$from', t = '$to';
    final moved = await (db.select(db.occurrenceExceptions)
          ..where((e) =>
              e.subjectType.equals('event') & e.deletedAt.isNull() & e.kind.equals('move') &
              e.moveDate.isBetweenValues(f, t)))
        .get();
    final schedules = await (db.select(db.schedules)
          ..where((s) =>
              s.workspaceId.equals(ws) &
              s.subjectType.equals('event') &
              s.deletedAt.isNull() &
              ((s.firstDate.isSmallerOrEqualValue(t) &
                      (s.lastDate.isNull() | s.lastDate.isBiggerOrEqualValue(f))) |
                  s.subjectId.isIn(moved.map((m) => m.subjectId)))))
        .get();
    final ids = schedules.map((s) => s.subjectId).toList();
    final exceptions = <String, List<tk.OccurrenceException>>{};
    for (final e in await (db.select(db.occurrenceExceptions)
          ..where((e) => e.subjectType.equals('event') & e.deletedAt.isNull() & e.subjectId.isIn(ids)))
        .get()) {
      exceptions.putIfAbsent(e.subjectId, () => []).add(exceptionOf(e));
    }

    final window = tk.DateWindow(from, to);
    var truncated = taskAgenda.truncated;
    final items = <EventItem>[];
    final timed = <tk.TimedItem>[];
    for (final s in schedules) {
      final event = events[s.subjectId];
      if (event == null) continue; // in the trash
      final (spec, rule) = readSchedule(s);
      final r = tk.occurrencesInWindow(
          seriesId: event.id, spec: spec, rule: rule,
          exceptions: exceptions[event.id] ?? const [], window: window, limits: limits);
      truncated |= r.truncated;
      for (final o in r.occurrences) {
        final cancelled = event.status == 'cancelled' || o.isCancelled;
        final patch = o.patch ?? const {};
        items.add(EventItem(
          eventId: event.id,
          title: (patch['title'] as String?) ?? event.title,
          originalDate: o.originalDate,
          start: inputOf(o.schedule.start)!,
          end: inputOf(o.schedule.end),
          location: patch.containsKey('location') ? patch['location'] as String? : event.location,
          calendarId: event.calendarId,
          isRepeating: rule != null,
          isCancelled: cancelled,
          isMoved: o.isException && o.patch == null && !o.isCancelled,
        ));
        if (!cancelled) {
          final it = tk.timedItemOf(eventOccurrenceKey(event.id, o.originalDate), o.schedule);
          if (it != null) timed.add(it);
        }
      }
    }
    items.sort((a, b) {
      final c = a.date.compareTo(b.date);
      if (c != 0) return c;
      final m = (a.start.time?.minuteOfDay ?? -1).compareTo(b.start.time?.minuteOfDay ?? -1);
      return m != 0 ? m : a.title.compareTo(b.title);
    });

    // Scheduled tasks take part too (D6/D7); done ones and all-day ones do not.
    for (final i in taskAgenda.items) {
      if (i.isDone || i.isOverdue) continue;
      final it = tk.timedItemOf(taskOccurrenceKey(i.taskId, i.originalDate),
          tk.ScheduleSpec(start: pointOf(i.start), end: pointOf(i.end)));
      if (it != null) timed.add(it);
    }
    final conflicts = [for (final c in tk.overlaps(timed)) ConflictView(c.first, c.second)];
    if (items.length > limits.maxOccurrences) {
      truncated = true;
      items.removeRange(limits.maxOccurrences, items.length);
    }
    return CalendarRange(events: items, tasks: taskAgenda.items, conflicts: conflicts, truncated: truncated);
  }
}
