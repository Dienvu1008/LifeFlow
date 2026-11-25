// P06 T6 (ADR-0086; ai-architecture.md §2–§5; the owner's D1, D6, D8, D9):
// the assistant's turns over the real store.
//   plan my day     the open tasks of a day (no time yet) are placed around
//                   its fixed events and timed items. The model gives an
//                   order and a slot by task id; the code decides every time
//                   (fitDayPlan) and builds the commands. The model never
//                   names a command
//   fix conflicts   the timed one-off tasks of a day that overlap something
//                   are placed again the same way
//   ask             an answer about a document or a PDF; nothing changes
//   always          the personal space only (D7); the context only what the
//                   turn is about (ADR-0081); the route by the egress rule
//                   (OQ-AI-2: decline, never lower privacy); the turn kept
//                   in the history (ADR-0082); a change runs only when the
//                   person approves it (LF-INV-AI-001)
import 'dart:async';
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show DayInterval, DayPlanTask, DayPlanWish, fitDayPlan, formatDayMinute, parseDayMinute;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;

import 'ai_context_builder.dart';
import 'app_database.dart';
import 'calendar_service.dart';
import 'profile_store.dart';
import 'schedule_mapping.dart' show readSchedule, scheduleFieldsJson;

/// The most tasks one plan places (the context's own bound is 30 items).
const maxPlanTasks = 15;

/// The plan the model writes: small on purpose (S-17: a long JSON plan was
/// slow and broke) — an order, a start and a length per task id.
const dayPlanSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'taskId': {'type': 'string'},
          'start': {'type': 'string'},
          'minutes': {'type': 'integer'},
        },
        'required': ['taskId', 'start', 'minutes'],
        'additionalProperties': false,
      },
    },
    'note': {'type': 'string'},
  },
  'required': ['items', 'note'],
  'additionalProperties': false,
};

class DriftAiAssistant implements AiAssistant {
  DriftAiAssistant({
    required this.db,
    required this.history,
    required this.calendar,
    required this.time,
    required this.engines,
    required this.settings,
    AiContextBuilder? context,
  })  : context = context ?? DriftAiContextBuilder(db),
        _store = ProfileStore(db);

  final AppDatabase db;
  final AiHistoryService history;
  final DriftCalendarQueries calendar;
  final DeviceTime time;

  /// Every engine of this device (the local one, the cloud one).
  final List<AiEngine> engines;
  final Future<AiAssistantSettings> Function() settings;
  final AiContextBuilder context;
  final ProfileStore _store;

  bool get _vi => _lang == 'vi';
  String _lang = 'vi';

  Future<List<AiEngine>> _ordered(AiAssistantSettings s) async =>
      [...engines.where((e) => e.site == s.preferred), ...engines.where((e) => e.site != s.preferred)];

  AiEgressPolicy _policy(AiAssistantSettings s) =>
      // A plan is about the tasks, an answer about the document: Confidential
      // by their nature (ADR-0080, the matrix's "session scope").
      AiEgressPolicy(cloudEnabled: s.cloudEnabled, scopeIncludesConfidential: true);

  /// The assistant works in the personal space only (D7, ADR-0082).
  Future<String?> _notPersonal() async {
    final ctx = await _store.commandContext();
    if (ctx == null) return 'no active profile';
    return ctx.shared ? 'the assistant works in the personal space only' : null;
  }

  // ---- the day ----------------------------------------------------------------

  /// Minutes of [date] that an item from [start] to [end] (device time) takes.
  DayInterval? _interval(LocalDate date, SchedulePointInput? start, SchedulePointInput? end) {
    if (start == null || start.time == null) return null;
    final s = start.date.isBefore(date) ? 0 : (start.date == date ? start.time!.minuteOfDay : null);
    if (s == null) return null;
    final e = end?.time == null
        ? s + 30
        : (end!.date.isAfter(date) ? 24 * 60 : (end.date == date ? end.time!.minuteOfDay : 0));
    return e > s ? DayInterval(s, e) : null;
  }

  /// The open tasks [date] may plan: no schedule, or a one-off planned for
  /// that day without a time. Important ones first, then by list order.
  Future<List<Task>> _plannable(String ws, LocalDate date) async {
    final rows = await (db.select(db.tasks)
          ..where((t) =>
              t.workspaceId.equals(ws) & t.deletedAt.isNull() & t.status.isIn(const ['inbox', 'todo', 'inProgress'])))
        .get();
    final schedules = {
      for (final s in await (db.select(db.schedules)
            ..where((s) => s.subjectType.equals('task') & s.deletedAt.isNull() & s.workspaceId.equals(ws)))
          .get())
        s.subjectId: s,
    };
    final out = <Task>[];
    for (final t in rows) {
      final s = schedules[t.id];
      if (s == null) {
        out.add(t);
        continue;
      }
      try {
        final (spec, rule) = readSchedule(s);
        final p = spec.start ?? spec.end;
        if (rule == null && p is tk.DatePoint && p.date == date && spec.end is! tk.TimedPoint) out.add(t);
      } on Object {
        // a row that cannot be read is not planned
      }
    }
    out.sort((a, b) => a.isImportant != b.isImportant
        ? (a.isImportant ? -1 : 1)
        : (a.orderKey == b.orderKey ? a.id.compareTo(b.id) : a.orderKey.compareTo(b.orderKey)));
    return out.take(maxPlanTasks).toList();
  }

  Future<AiTurnResult> _plan(LocalDate date, AiPurpose purpose,
      {String? sessionId, String? request, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) async {
    final s = await settings();
    _lang = s.language;
    final no = await _notPersonal();
    if (no != null) return AiTurnResult(AiTurnOutcome.declined, reason: no);
    final ws = (await _store.commandContext())!.workspaceId;
    final day = await calendar.range(date, date);

    // Who moves and what stays: a plan places the open tasks; a conflict fix
    // the timed one-off tasks that overlap something.
    final List<String> movable;
    final titles = <String, String>{};
    if (purpose == AiPurpose.planDay) {
      final tasks = await _plannable(ws, date);
      movable = [for (final t in tasks) t.id];
      for (final t in tasks) {
        titles[t.id] = t.title;
      }
    } else {
      final keys = {for (final c in day.conflicts) ...[c.first, c.second]};
      movable = [
        for (final t in day.tasks)
          if (!t.isRepeating && !t.isDone && t.deviceStart?.time != null && keys.contains(taskOccurrenceKey(t.taskId, t.originalDate)))
            t.taskId,
      ];
      for (final t in day.tasks) {
        titles[t.taskId] = t.title;
      }
    }
    if (movable.isEmpty) {
      return AiTurnResult(AiTurnOutcome.nothingToDo,
          reason: purpose == AiPurpose.planDay ? 'no open task to plan' : 'no conflict to fix');
    }

    // What is fixed that day, from the store (never from the model).
    final busy = <String, DayInterval>{};
    final busyTitles = <String, String>{};
    for (final e in day.events) {
      if (e.isCancelled) continue;
      final i = _interval(date, e.deviceStart, e.deviceEnd);
      if (i != null) {
        busy['event:${e.eventId}'] = i;
        busyTitles['event:${e.eventId}'] = e.title;
      }
    }
    for (final t in day.tasks) {
      if (t.isDone || movable.contains(t.taskId)) continue;
      final i = _interval(date, t.deviceStart, t.deviceEnd);
      if (i != null) busy['task:${t.taskId}'] = i;
    }

    // The context: the tasks to place and what is fixed, each with its time.
    final built = await context.build(AiContextRequest(purpose: purpose, named: [
      for (final id in movable) RecordRef('task', id),
      for (final k in busy.keys) RecordRef(k.split(':').first, k.substring(k.indexOf(':') + 1)),
    ]));
    final items = [
      for (final it in built.items)
        AiContextItem(
          ref: it.ref,
          classification: it.classification,
          title: it.title,
          version: it.version,
          text: [
            if (busy['${it.ref}'] case final b?) 'fixed ${formatDayMinute(b.start)}-${formatDayMinute(b.end)}' else 'to place',
            it.text,
          ].where((x) => x.isNotEmpty).join('\n'),
        ),
    ];
    final versions = {for (final it in built.items) if (it.version != null) it.ref: it.version!};
    final hours = DayInterval(s.dayStart, s.dayEnd);
    final instructions = [
      'You plan one day for the person. The data lists tasks "to place" and items "fixed" at their times.',
      'Give each task to place a start (HH:MM, 24-hour) and a length in minutes, between '
          '${formatDayMinute(hours.start)} and ${formatDayMinute(hours.end)}, not over a fixed item or another task.',
      'Important and urgent first. Use only the task ids of the data (the part after "task:").',
      'Answer only with JSON following the schema. Write "note" (one or two short sentences) in '
          '${_vi ? 'Vietnamese' : 'English'}.',
    ].join(' ');
    final weekday = date.weekday.name;
    final question = [
      purpose == AiPurpose.planDay ? 'Plan my day on $date ($weekday).' : 'Move the tasks to place so nothing overlaps on $date ($weekday).',
      if (request != null && request.trim().isNotEmpty) 'The person adds: ${request.trim()}',
    ].join('\n');

    final route = await chooseAiRoute(
      engines: await _ordered(s),
      policy: _policy(s),
      context: AiContext(items, truncated: built.truncated),
      instructions: instructions,
      question: question,
      needed: {for (final id in movable) RecordRef('task', id)},
      consented: consented,
      withoutUnconsented: withoutUnconsented,
    );
    if (!route.ready) return AiTurnResult(route.outcome, lines: route.lines, reason: route.reason, site: route.engine?.site);
    final engine = route.engine!, req = route.request!;
    final model = await engine.model() ?? engine.site.name;

    final Map<String, Object?> answer;
    try {
      answer = await engine.structured(req, schema: dayPlanSchema, maxTokens: 1200);
    } on AiEngineFailure catch (e) {
      return AiTurnResult(AiTurnOutcome.failed,
          failure: e.kind, reason: e.message, lines: req.lines, site: engine.site, model: model);
    }

    // The code decides the times: only the tasks that were sent, each once,
    // on the day's free time (S-17: models overlap).
    final sentTasks = [for (final r in req.sentRefs) if (r.kind == 'task' && movable.contains(r.id)) r.id];
    final wishes = [
      for (final w in (answer['items'] is List ? answer['items'] as List : const []))
        if (w is Map)
          DayPlanWish(
            '${w['taskId']}'.startsWith('task:') ? '${w['taskId']}'.substring(5) : '${w['taskId']}',
            start: parseDayMinute(w['start']),
            minutes: w['minutes'] is int ? w['minutes'] as int : null,
          ),
    ];
    final today = tk.dateAt(time.now(), time.zone());
    final now = tk.wallClockAt(time.now(), time.zone()).time.minuteOfDay;
    final fit = fitDayPlan(
      tasks: [for (final id in sentTasks) DayPlanTask(id)],
      wishes: wishes,
      hours: hours,
      busy: busy.values.toList(),
      notBefore: date == today ? now : (date.isBefore(today) ? 24 * 60 : null),
    );

    final zone = time.zone();
    final changes = <ProposedChange>[];
    for (final slot in fit.slots) {
      final at = TimeOfDayValue(slot.start ~/ 60, slot.start % 60);
      final end = TimeOfDayValue(slot.end ~/ 60, slot.end % 60);
      final spec = tk.ScheduleSpec(
          start: tk.TimedPoint(ZonedWallClock(date, at, zone)), end: tk.TimedPoint(ZonedWallClock(date, end, zone)));
      final ref = RecordRef('task', slot.taskId);
      final v = versions[ref];
      if (v == null) continue;
      changes.add(ProposedChange(
        id: 'c${changes.length + 1}',
        commandType: 'SetTaskSchedule',
        arguments: {'id': slot.taskId, 'schedule': scheduleFieldsJson('task', slot.taskId, spec, null)},
        versions: {ref: v},
        summary: _vi
            ? '"${titles[slot.taskId]}": $at–$end${slot.moved ? ' (đã chỉnh để không trùng giờ)' : ''}'
            : '"${titles[slot.taskId]}": $at–$end${slot.moved ? ' (moved so nothing overlaps)' : ''}',
      ));
    }
    final unplaced = [...fit.unplaced, for (final id in sentTasks) if (!wishes.any((w) => w.taskId == id)) id];
    final note = [
      if (answer['note'] is String) (answer['note'] as String).trim(),
      if (unplaced.isNotEmpty)
        _vi
            ? 'Không còn chỗ trong ngày cho: ${unplaced.map((id) => '"${titles[id] ?? id}"').join(', ')}.'
            : 'No room that day for: ${unplaced.map((id) => '"${titles[id] ?? id}"').join(', ')}.',
    ].where((x) => x.isNotEmpty).join('\n');

    // The turn in the history (D7), the proposal with it.
    final session = sessionId ??
        _ok(await history.startSession(
            title: _vi ? 'Kế hoạch ngày ${date.day}/${date.month}' : 'Plan for $date',
            purpose: purpose));
    _ok(await history.addMessage(session, AiMessageRole.person, question));
    final messageId = _ok(await history.addMessage(session, AiMessageRole.assistant, note.isEmpty ? '…' : note,
        model: model, site: engine.site, sentRefs: [for (final r in req.sentRefs) (r, versions[r])]));
    if (changes.isEmpty) {
      return AiTurnResult(AiTurnOutcome.answered,
          sessionId: session, messageId: messageId, site: engine.site, model: model, lines: req.lines, text: note, unplaced: unplaced);
    }
    final proposalId = _ok(await history.addProposal(session,
        model: model, site: engine.site, changes: changes, messageId: messageId, note: note));
    return AiTurnResult(AiTurnOutcome.proposed,
        sessionId: session,
        proposalId: proposalId,
        messageId: messageId,
        site: engine.site,
        model: model,
        lines: req.lines,
        text: note,
        unplaced: unplaced,
        moved: [for (final s in fit.slots) if (s.moved) s.taskId]);
  }

  String _ok(CommandResult r) => switch (r) {
        CommandOk(:final entityId) => entityId,
        CommandFailure(:final kind, :final reason) => throw StateError('the history could not be written: $kind $reason'),
      };

  @override
  Future<AiTurnResult> planDay(LocalDate date,
          {String? sessionId, String? request, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) =>
      _plan(date, AiPurpose.planDay,
          sessionId: sessionId, request: request, consented: consented, withoutUnconsented: withoutUnconsented);

  @override
  Future<AiTurnResult> fixConflicts(LocalDate date,
          {String? sessionId, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) =>
      _plan(date, AiPurpose.fixConflict,
          sessionId: sessionId, consented: consented, withoutUnconsented: withoutUnconsented);

  // ---- a document ---------------------------------------------------------------

  @override
  Future<AiTurnResult> askDocument(RecordRef item, String question,
      {String? sessionId,
      Set<RecordRef> consented = const {},
      bool withoutUnconsented = false,
      void Function(String text)? onText}) async {
    final s = await settings();
    _lang = s.language;
    final no = await _notPersonal();
    if (no != null) return AiTurnResult(AiTurnOutcome.declined, reason: no);
    if (question.trim().isEmpty) return const AiTurnResult(AiTurnOutcome.nothingToDo, reason: 'no question');
    final built = await context.build(AiContextRequest(purpose: AiPurpose.askDocument, named: [item]));
    if (built.items.isEmpty) return const AiTurnResult(AiTurnOutcome.nothingToDo, reason: 'nothing to read here');
    const instructions = 'You answer questions about the person\'s document. Use only the data. '
        'Answer in the language of the question (D9), briefly. If the data does not hold the answer, say so.';
    final route = await chooseAiRoute(
      engines: await _ordered(s),
      policy: _policy(s),
      context: built,
      instructions: instructions,
      question: question.trim(),
      needed: {for (final i in built.items) i.ref},
      consented: consented,
      withoutUnconsented: withoutUnconsented,
    );
    if (!route.ready) return AiTurnResult(route.outcome, lines: route.lines, reason: route.reason, site: route.engine?.site);
    final engine = route.engine!, req = route.request!;
    final model = await engine.model() ?? engine.site.name;
    final text = StringBuffer();
    AiEngineFailure? failure;
    try {
      await for (final chunk in engine.answer(req)) {
        text.write(chunk);
        onText?.call(text.toString());
      }
    } on AiEngineFailure catch (e) {
      failure = e;
    }
    final versions = {for (final i in built.items) if (i.version != null) i.ref: i.version!};
    if (failure != null && text.isEmpty) {
      return AiTurnResult(AiTurnOutcome.failed,
          failure: failure.kind, reason: failure.message, lines: req.lines, site: engine.site, model: model);
    }
    // An answer only: it is kept, it changes nothing (LF-INV-AI-001).
    final session = sessionId ??
        _ok(await history.startSession(
            title: (built.items.first.title.isEmpty ? (_vi ? 'Hỏi tài liệu' : 'Ask a document') : built.items.first.title),
            purpose: AiPurpose.askDocument));
    _ok(await history.addMessage(session, AiMessageRole.person, question.trim()));
    final answer = failure == null ? text.toString() : '${text.toString()}\n…';
    final messageId = _ok(await history.addMessage(session, AiMessageRole.assistant, answer.trim().isEmpty ? '…' : answer,
        model: model, site: engine.site, sentRefs: [for (final r in req.sentRefs) (r, versions[r])]));
    return AiTurnResult(failure == null ? AiTurnOutcome.answered : AiTurnOutcome.failed,
        failure: failure?.kind,
        reason: failure?.message,
        sessionId: session,
        messageId: messageId,
        site: engine.site,
        model: model,
        lines: req.lines,
        text: answer);
  }

  @override
  Future<void> stop() async {
    for (final e in engines) {
      await e.stop();
    }
  }
}

/// The assistant's settings as one JSON value (the app keeps it in its
/// encrypted registry, T7).
AiAssistantSettings aiAssistantSettingsOf(String? json) {
  if (json == null) return const AiAssistantSettings();
  try {
    final j = (jsonDecode(json) as Map).cast<String, Object?>();
    int minute(Object? v, int d) => v is int && v >= 0 && v <= 24 * 60 ? v : d;
    final start = minute(j['dayStart'], 8 * 60), end = minute(j['dayEnd'], 18 * 60);
    return AiAssistantSettings(
      preferred: AiEngineSite.values.where((s) => s.name == j['preferred']).firstOrNull ?? AiEngineSite.device,
      cloudEnabled: j['cloudEnabled'] == true,
      dayStart: start < end ? start : 8 * 60,
      dayEnd: start < end ? end : 18 * 60,
      language: j['language'] == 'en' ? 'en' : 'vi',
    );
  } on Object {
    return const AiAssistantSettings();
  }
}

/// [s] as stored.
String aiAssistantSettingsJson(AiAssistantSettings s) => jsonEncode({
      'preferred': s.preferred.name,
      'cloudEnabled': s.cloudEnabled,
      'dayStart': s.dayStart,
      'dayEnd': s.dayEnd,
      'language': s.language,
    });
