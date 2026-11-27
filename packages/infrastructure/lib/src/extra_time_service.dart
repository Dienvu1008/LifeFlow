// P06c E1 (ADR-0095): the extra times of tasks and events, from the app: the
// commands through the gateway (on the item's own handler, so the item moves
// forward with them) and the list of an item's times.
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'event_command_handlers.dart';
import 'profile_store.dart';
import 'schedule_inputs.dart';
import 'schedule_mapping.dart';
import 'task_command_handler.dart';

class DriftExtraTimes implements ExtraTimes {
  DriftExtraTimes(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;
  final _tasks = TaskCommandHandler();
  final _events = const EventCommandHandler();
  final _uuid = const Uuid();

  static const _notFound = CommandFailure(CommandFailureKind.notFound, reason: 'not found');

  static String _name(ExtraTimeSubject s) => s == ExtraTimeSubject.task ? 'Task' : 'Event';

  Future<CommandResult> _run(ExtraTimeSubject subject, String subjectId, String verb, Map<String, Object?> payload) async {
    final ctx = await _store.commandContext();
    if (ctx == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    final int version;
    switch (subject) {
      case ExtraTimeSubject.task:
        final t = await (db.select(db.tasks)..where((x) => x.id.equals(subjectId))).getSingleOrNull();
        if (t == null || t.deletedAt != null || t.workspaceId != ctx.workspaceId) return _notFound;
        version = t.version;
      case ExtraTimeSubject.event:
        final e = await (db.select(db.events)..where((x) => x.id.equals(subjectId))).getSingleOrNull();
        if (e == null || e.deletedAt != null || e.workspaceId != ctx.workspaceId) return _notFound;
        version = e.version;
    }
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ctx.actor,
        workspaceId: ctx.workspaceId,
        type: '$verb${_name(subject)}ExtraTime',
        payload: {...payload, 'id': subjectId},
        expectedVersion: Version(version),
        issuedAt: Instant.now(),
      ),
      subject == ExtraTimeSubject.task ? _tasks : _events,
    );
  }

  /// The time as schedule columns, or the failure.
  (Map<String, Object?>?, CommandFailure?) _fields(ExtraTimeSubject subject, String subjectId, ExtraTimeInput time) {
    final input = TaskScheduleInput(start: time.start, end: time.end, repeat: time.repeat);
    final error = scheduleInputError(input);
    if (error != null) return (null, CommandFailure(CommandFailureKind.validationFailed, reason: error));
    return (scheduleFieldsJson(subject.name, subjectId, specOfInput(input), ruleOfInput(time.repeat)), null);
  }

  @override
  Future<CommandResult> add(ExtraTimeSubject subject, String subjectId, ExtraTimeInput time) async {
    final (fields, failure) = _fields(subject, subjectId, time);
    if (failure != null) return failure;
    return _run(subject, subjectId, 'Add', {'op': 'addExtra', 'extraId': _uuid.v7(), 'schedule': fields});
  }

  Future<ExtraTime?> _extra(String id) async {
    final r = await (db.select(db.extraTimes)..where((x) => x.id.equals(id))).getSingleOrNull();
    return r == null || r.deletedAt != null ? null : r;
  }

  static ExtraTimeSubject _subjectOf(ExtraTime e) => e.subjectType == 'task' ? ExtraTimeSubject.task : ExtraTimeSubject.event;

  @override
  Future<CommandResult> change(String extraId, ExtraTimeInput time) async {
    final e = await _extra(extraId);
    if (e == null) return _notFound;
    final (fields, failure) = _fields(_subjectOf(e), e.subjectId, time);
    if (failure != null) return failure;
    return _run(_subjectOf(e), e.subjectId, 'Change', {'op': 'changeExtra', 'extraId': extraId, 'schedule': fields});
  }

  @override
  Future<CommandResult> remove(String extraId) async {
    final e = await _extra(extraId);
    if (e == null) return _notFound;
    return _run(_subjectOf(e), e.subjectId, 'Remove', {'op': 'removeExtra', 'extraId': extraId});
  }

  @override
  Future<CommandResult> setDone(String extraId, {required bool done}) async {
    final e = await _extra(extraId);
    if (e == null) return _notFound;
    return _run(_subjectOf(e), e.subjectId, done ? 'Complete' : 'Reopen', {'op': 'setExtraDone', 'extraId': extraId, 'done': done});
  }

  @override
  Future<CommandResult> changeTaskOccurrence(String extraId, LocalDate originalDate, OccurrenceChange? change) async {
    final e = await _extra(extraId);
    if (e == null || e.subjectType != 'task') return _notFound;
    final base = {'extraId': extraId, 'originalDate': '$originalDate'};
    final (verb, payload) = switch (change) {
      null => ('ClearOccurrenceChangeOf', {...base, 'op': 'clearExtraException'}),
      SkipThisOccurrence() => ('SkipOccurrenceOf', {...base, 'op': 'setExtraException', 'kind': 'skip'}),
      MoveThisOccurrence(:final toDate, :final toTime) => (
          'MoveOccurrenceOf',
          {...base, 'op': 'setExtraException', 'kind': 'move', 'moveDate': '$toDate', 'moveTime': toTime?.toString()}
        ),
    };
    return _run(ExtraTimeSubject.task, e.subjectId, verb, payload);
  }

  @override
  Future<CommandResult> changeEventOccurrence(
      String extraId, LocalDate originalDate, EventOccurrenceChange? change) async {
    final e = await _extra(extraId);
    if (e == null || e.subjectType != 'event') return _notFound;
    final base = {'extraId': extraId, 'originalDate': '$originalDate'};
    final (verb, payload) = switch (change) {
      null => ('ClearOccurrenceChangeOf', {...base, 'op': 'clearExtraException'}),
      SkipEventOccurrence() => ('SkipOccurrenceOf', {...base, 'op': 'setExtraException', 'kind': 'skip'}),
      CancelEventOccurrence() => ('CancelOccurrenceOf', {...base, 'op': 'setExtraException', 'kind': 'cancel'}),
      MoveEventOccurrence(:final toDate, :final toTime) => (
          'MoveOccurrenceOf',
          {...base, 'op': 'setExtraException', 'kind': 'move', 'moveDate': '$toDate', 'moveTime': toTime?.toString()}
        ),
      EditEventOccurrence(:final title, :final location) => (
          'EditOccurrenceOf',
          {
            ...base,
            'op': 'setExtraException',
            'kind': 'edit',
            if (title != null) 'title': title,
            if (location != null) 'location': location,
          }
        ),
    };
    return _run(ExtraTimeSubject.event, e.subjectId, verb, payload);
  }

  @override
  Future<CommandResult> setOccurrenceDone(String extraId, LocalDate originalDate, {required bool done}) async {
    final e = await _extra(extraId);
    if (e == null || e.subjectType != 'task') return _notFound;
    return _run(ExtraTimeSubject.task, e.subjectId, done ? 'CompleteOccurrenceOf' : 'ReopenOccurrenceOf',
        {'op': 'setExtraOccurrenceDone', 'extraId': extraId, 'originalDate': '$originalDate', 'done': done});
  }

  @override
  Future<List<ExtraTimeView>> of(ExtraTimeSubject subject, String subjectId) async {
    final rows = await (db.select(db.extraTimes)
          ..where((x) => x.subjectType.equals(subject.name) & x.subjectId.equals(subjectId) & x.deletedAt.isNull()))
        .get();
    rows.sort((a, b) {
      final c = a.startDate.compareTo(b.startDate);
      if (c != 0) return c;
      final t = (a.startTime ?? '').compareTo(b.startTime ?? '');
      return t != 0 ? t : a.id.compareTo(b.id);
    });
    return [for (final r in rows) extraTimeViewOf(r)];
  }
}

/// A stored extra time as the app lists it.
ExtraTimeView extraTimeViewOf(ExtraTime r) {
  SchedulePointInput point(String date, String? time, String? zone) => time == null || zone == null
      ? SchedulePointInput.date(LocalDate.parse(date))
      : SchedulePointInput.at(LocalDate.parse(date), TimeOfDayValue.parse(time), zone);
  return ExtraTimeView(
    id: r.id,
    subject: r.subjectType == 'task' ? ExtraTimeSubject.task : ExtraTimeSubject.event,
    subjectId: r.subjectId,
    start: point(r.startDate, r.startTime, r.startZone),
    end: r.endDate == null ? null : point(r.endDate!, r.endTime, r.endZone),
    isDone: r.doneAt != null,
    repeat: repeatOf(ruleOfExtra(r)),
  );
}
