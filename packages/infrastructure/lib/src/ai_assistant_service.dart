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
import 'package:domain/domain.dart'
    show DayInterval, DayPlanTask, DayPlanWish, fitDayPlan, formatDayMinute, parseDayMinute;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'ai_context_builder.dart';
import 'ai_history_handlers.dart' show maxAiTitleLength;
import 'app_database.dart';
import 'calendar_service.dart';
import 'profile_store.dart';
import 'record_kinds.dart' show dataClassOf, kindClasses, recordKindByName;
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
  final _uuid = const Uuid();

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
              t.workspaceId.equals(ws) & t.deletedAt.isNull() & t.archivedAt.isNull() & t.status.isIn(const ['inbox', 'todo', 'inProgress'])))
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

  // ---- the chat (P06b W4, ADR-0088) -------------------------------------------

  /// When an item of the coming days is: its day, and its time if it has one.
  static String _when(LocalDate date, SchedulePointInput? start, SchedulePointInput? end) {
    final d = start?.date ?? date;
    final from = start?.time, to = end?.time;
    return 'on $d (${d.weekday.name})${from == null ? '' : ' at $from${to == null ? '' : '-$to'}'}';
  }

  /// The class of what an earlier answer was made from: a PDF's text is
  /// Confidential; a record by its row, or, once it is gone, by its kind (a
  /// measurement whose source cannot be read any more, or an unknown kind,
  /// is Restricted: nothing unclassified leaves the device).
  Future<DataClassification> _classOf(RecordRef ref) async {
    if (ref.kind == 'file') return DataClassification.confidential;
    final kind = recordKindByName[ref.kind];
    final row = kind == null ? null : await kind.readOne(db, ref.id);
    if (row != null) return dataClassOf(ref.kind, row);
    if (ref.kind == 'measurement') return DataClassification.restricted;
    return kindClasses[ref.kind] ?? DataClassification.restricted;
  }

  /// The earlier turns of [sessionId] as one private item (`aichat:<id>`),
  /// newest last, within [chatHistoryChars]. They are the chat history
  /// (Confidential), Restricted when an earlier answer was made from a
  /// Restricted item: they go through the checkpoint like any item, so a
  /// cloud model gets them only with consent, and never what came from
  /// Restricted data.
  Future<AiContextItem?> _earlier(String? sessionId) async {
    if (sessionId == null) return null;
    final all = await history.messages(sessionId);
    if (all.isEmpty) return null;
    final kept = all.length > chatHistoryMessages ? all.sublist(all.length - chatHistoryMessages) : all;
    var cls = DataClassification.confidential;
    for (final m in kept) {
      for (final (ref, _) in m.sentRefs) {
        if (await _classOf(ref) == DataClassification.restricted) cls = DataClassification.restricted;
      }
    }
    final lines = [
      for (final m in kept) '${m.role == AiMessageRole.person ? 'Person' : 'Assistant'}: ${m.text.trim()}',
    ];
    var text = lines.join('\n');
    if (text.length > chatHistoryChars) text = '…${text.substring(text.length - chatHistoryChars)}';
    return AiContextItem(
        ref: RecordRef('aichat', sessionId),
        classification: cls,
        title: _vi ? 'Các tin nhắn trước trong cuộc trò chuyện này' : 'Earlier messages of this chat',
        text: text);
  }

  @override
  Future<AiTurnResult> chat(String message,
      {String? sessionId, Set<RecordRef> consented = const {}, bool withoutUnconsented = false}) async {
    final s = await settings();
    _lang = s.language;
    final said = message.trim();
    if (said.isEmpty) return const AiTurnResult(AiTurnOutcome.nothingToDo, reason: 'no message');
    if (await _store.commandContext() == null) return const AiTurnResult(AiTurnOutcome.declined, reason: 'no active profile');
    final personal = await _store.personalWorkspaceId();
    final now = time.now(), zone = time.zone();
    final today = tk.dateAt(now, zone);
    final clock = tk.wallClockAt(now, zone).time;

    // 1. What it reads: the earlier turns, the shown space's coming days,
    // and what every space holds about the message (the owner's Q2).
    final earlier = await _earlier(sessionId);
    final days = await calendar.range(today, today.addDays(chatAgendaDays - 1));
    // Each item with its day and time, one line for each day it is on.
    final when = <RecordRef, List<String>>{};
    final occurrences = <String, List<EventItem>>{};
    for (final t in days.tasks) {
      final ref = RecordRef('task', t.taskId);
      if (t.isDone || (when.length >= chatAgendaItems && !when.containsKey(ref))) continue;
      when.putIfAbsent(ref, () => []).add(_when(t.originalDate, t.deviceStart ?? t.start, t.deviceEnd ?? t.end));
    }
    for (final e in days.events) {
      final ref = RecordRef('event', e.eventId);
      if (e.isCancelled || (when.length >= chatAgendaItems && !when.containsKey(ref))) continue;
      occurrences.putIfAbsent(e.eventId, () => []).add(e);
      when.putIfAbsent(ref, () => []).add(_when(e.originalDate, e.deviceStart ?? e.start, e.deviceEnd ?? e.end) +
          (e.isRepeating ? ' (repeats; this one is of ${e.originalDate})' : ''));
    }
    final built = await context
        .build(AiContextRequest(purpose: AiPurpose.chat, named: when.keys.toList(), query: said, allSpaces: true));

    // Only the personal space's tasks and timed events can be changed (an
    // approval runs there, ADR-0082): they say so, so the model proposes
    // nothing else.
    final taskIds = [for (final i in built.items) if (i.ref.kind == 'task') i.ref.id];
    final eventIds = [for (final i in built.items) if (i.ref.kind == 'event') i.ref.id];
    final changeable = <String>{
      if (taskIds.isNotEmpty && personal != null)
        for (final t in await (db.select(db.tasks)
              ..where((t) => t.id.isIn(taskIds) & t.workspaceId.equals(personal) & t.deletedAt.isNull() & t.archivedAt.isNull()))
            .get())
          t.id,
      if (eventIds.isNotEmpty && personal != null)
        for (final e in await (db.select(db.events)
              ..where((e) => e.id.isIn(eventIds) & e.workspaceId.equals(personal) & e.deletedAt.isNull() & e.archivedAt.isNull()))
            .get())
          // A day-long event has no time to move to.
          if (occurrences[e.id]?.any((o) => o.deviceStart?.time != null) ?? false) e.id,
    };
    final items = [
      if (earlier != null) earlier,
      for (final it in built.items)
        AiContextItem(
          ref: it.ref,
          classification: it.classification,
          title: it.title,
          version: it.version,
          text: [
            if (when[it.ref] case final w?) ...w,
            if (changeable.contains(it.ref.id) && (it.ref.kind == 'task' || it.ref.kind == 'event')) 'changeable',
            it.text,
          ].where((x) => x.isNotEmpty).join('\n'),
        ),
    ];
    final versions = {for (final it in built.items) if (it.version != null) it.ref: it.version!};

    final instructions = [
      'You are the person\'s assistant in LifeFlow, a planner of tasks, events and documents. '
          'Today is $today (${today.weekday.name}); the time is $clock.',
      'The data may hold the earlier messages of this chat (ref "aichat:…"), the coming days of the shown space '
          '("on <date> at <time>"), and items found for the message. Use them; if they do not hold the answer, say so.',
      'Write "reply" briefly, in the language of the person\'s message.',
      'You may propose changes in "changes"; nothing changes until the person approves each one. A change is '
          'action "create" (a new task: "title"; "date" YYYY-MM-DD and "start" HH:MM and "minutes" if it should have a time), '
          '"rename" ("taskId", "title"), "schedule" ("taskId", "date", "start", "minutes"), '
          '"createEvent" (a new event: "title", "date", "start", "minutes" its length) or "moveEvent" ("eventId", the new '
          '"date" and "start"; "minutes" its length, 0 to keep it; for an event that repeats, "fromDate" is the day '
          'of the occurrence to move, and only that one moves). Only tasks and events whose text says "changeable" may be '
          'changed; use only their ids (the part after "task:" or "event:"). '
          'Leave unused fields "" or 0. Propose nothing unless the person asks for a change.',
      'Answer only with JSON following the schema.',
    ].join(' ');

    // 2. The route: the cloud only when it is on (the message itself is the
    // person's private words), every item through the checkpoint.
    final route = await chooseAiRoute(
      engines: [for (final e in await _ordered(s)) if (e.site != AiEngineSite.cloud || s.cloudEnabled) e],
      policy: _policy(s),
      context: AiContext(items, truncated: built.truncated),
      instructions: instructions,
      question: said,
      // The earlier turns are what a chat is about: an engine that may not
      // get them is passed over (OQ-AI-2). A Restricted hit is only left out.
      needed: {
        for (final i in items)
          if (i.ref.kind == 'aichat' || i.classification != DataClassification.restricted) i.ref,
      },
      consented: consented,
      withoutUnconsented: withoutUnconsented,
    );
    if (!route.ready) return AiTurnResult(route.outcome, lines: route.lines, reason: route.reason, site: route.engine?.site);
    final engine = route.engine!, req = route.request!;
    final model = await engine.model() ?? engine.site.name;
    final Map<String, Object?> answer;
    try {
      answer = await engine.structured(req, schema: chatSchema, maxTokens: 1200);
    } on AiEngineFailure catch (e) {
      return AiTurnResult(AiTurnOutcome.failed,
          failure: e.kind, reason: e.message, lines: req.lines, site: engine.site, model: model);
    }

    // 3. The changes: only what the checks allow, built by the code (the
    // model never names a command).
    _titles = {for (final i in built.items) if (i.ref.kind == 'task') i.ref.id: i.title};
    final changes = _chatChanges(answer['changes'],
        sent: req.sentRefs, changeable: changeable, versions: versions, occurrences: occurrences);
    final reply = answer['reply'] is String && (answer['reply'] as String).trim().isNotEmpty
        ? (answer['reply'] as String).trim()
        : '…';

    // 4. The turn in the history (D7).
    final session = sessionId ??
        _ok(await history.startSession(
            title: said.length > 60 ? '${said.substring(0, 60).trimRight()}…' : said, purpose: AiPurpose.chat));
    _ok(await history.addMessage(session, AiMessageRole.person, said));
    final messageId = _ok(await history.addMessage(session, AiMessageRole.assistant, reply,
        model: model,
        site: engine.site,
        sentRefs: [for (final r in req.sentRefs) if (r.kind != 'aichat') (r, versions[r])]));
    if (changes.isEmpty) {
      return AiTurnResult(AiTurnOutcome.answered,
          sessionId: session, messageId: messageId, site: engine.site, model: model, lines: req.lines, text: reply);
    }
    final proposalId = _ok(await history.addProposal(session,
        model: model, site: engine.site, changes: changes, messageId: messageId, note: reply));
    return AiTurnResult(AiTurnOutcome.proposed,
        sessionId: session,
        proposalId: proposalId,
        messageId: messageId,
        site: engine.site,
        model: model,
        lines: req.lines,
        text: reply);
  }

  /// The proposed changes of a chat answer that pass the checks: a task or an
  /// event to change must be one that was sent, of the personal space, with
  /// its version; a slot is within one day; a new task's slot follows it
  /// (its first version is 1, so it runs after it); a new event carries its
  /// own slot; a repeating event moves one of the days it was shown on.
  List<ProposedChange> _chatChanges(Object? raw,
      {required Set<RecordRef> sent,
      required Set<String> changeable,
      required Map<RecordRef, int> versions,
      required Map<String, List<EventItem>> occurrences}) {
    final out = <ProposedChange>[];
    final zone = time.zone();
    String id() => 'c${out.length + 1}';

    ({LocalDate day, TimeOfDayValue at, TimeOfDayValue end, tk.ScheduleSpec spec})? slotOf(Object? date, Object? start, int length) {
      final LocalDate day;
      try {
        day = LocalDate.parse('$date');
      } on Object {
        return null;
      }
      final from = parseDayMinute(start);
      if (from == null) return null;
      final to = from + length;
      if (to >= 24 * 60) return null;
      final at = TimeOfDayValue(from ~/ 60, from % 60), end = TimeOfDayValue(to ~/ 60, to % 60);
      return (
        day: day,
        at: at,
        end: end,
        spec: tk.ScheduleSpec(
            start: tk.TimedPoint(ZonedWallClock(day, at, zone)), end: tk.TimedPoint(ZonedWallClock(day, end, zone)))
      );
    }

    int lengthOf(Object? minutes, int fallback) => minutes is int && minutes > 0 ? minutes.clamp(5, 12 * 60) : fallback;

    ProposedChange? slot(String taskId, String title, Object? date, Object? start, Object? minutes, int version) {
      final s = slotOf(date, start, lengthOf(minutes, 30));
      if (s == null) return null;
      return ProposedChange(
        id: id(),
        commandType: 'SetTaskSchedule',
        arguments: {'id': taskId, 'schedule': scheduleFieldsJson('task', taskId, s.spec, null)},
        versions: {RecordRef('task', taskId): version},
        summary: '"$title": ${s.day} ${s.at}–${s.end}',
      );
    }

    // One change per task or event: each is bound to the version it was
    // made against, so a second one on the same item would be stale once the
    // first runs.
    final touched = <String>{};
    for (final c in raw is List ? raw : const []) {
      if (c is! Map || out.length >= maxChatChanges) continue;
      final action = '${c['action'] ?? ''}';
      var taskId = '${c['taskId'] ?? ''}'.trim();
      if (taskId.startsWith('task:')) taskId = taskId.substring(5);
      var eventId = '${c['eventId'] ?? ''}'.trim();
      if (eventId.startsWith('event:')) eventId = eventId.substring(6);
      final title = '${c['title'] ?? ''}'.trim();
      final ref = RecordRef('task', taskId);
      final known = taskId.isNotEmpty &&
          !touched.contains(taskId) &&
          sent.contains(ref) &&
          changeable.contains(taskId) &&
          versions[ref] != null;

      switch (action) {
        case 'create':
          if (title.isEmpty || title.length > maxAiTitleLength) continue;
          final newId = _uuid.v7();
          out.add(ProposedChange(
            id: id(),
            commandType: 'CreateTask',
            arguments: {'id': newId, 'title': title},
            versions: const {},
            summary: _vi ? 'Việc mới: "$title"' : 'New task: "$title"',
          ));
          if (slot(newId, title, c['date'], c['start'], c['minutes'], 1) case final s?) out.add(s);
        case 'rename':
          if (!known || title.isEmpty || title.length > maxAiTitleLength) continue;
          out.add(ProposedChange(
            id: id(),
            commandType: 'RenameTask',
            arguments: {'id': taskId, 'title': title},
            versions: {ref: versions[ref]!},
            summary: _vi ? 'Đổi tên thành "$title"' : 'Rename to "$title"',
          ));
          touched.add(taskId);
        case 'schedule':
          if (!known) continue;
          final name = _titles[taskId] ?? taskId;
          if (slot(taskId, name, c['date'], c['start'], c['minutes'], versions[ref]!) case final s?) {
            out.add(s);
            touched.add(taskId);
          }
        case 'createEvent':
          // An event needs a day and a start; the length is an hour unless said.
          if (title.isEmpty || title.length > maxAiTitleLength) continue;
          final s = slotOf(c['date'], c['start'], lengthOf(c['minutes'], 60));
          if (s == null) continue;
          final newId = _uuid.v7();
          out.add(ProposedChange(
            id: id(),
            commandType: 'CreateEvent',
            arguments: {'id': newId, 'title': title, 'schedule': scheduleFieldsJson('event', newId, s.spec, null)},
            versions: const {},
            summary: _vi
                ? 'Sự kiện mới: "$title", ${s.day} ${s.at}–${s.end}'
                : 'New event: "$title", ${s.day} ${s.at}–${s.end}',
          ));
        case 'moveEvent':
          final eref = RecordRef('event', eventId);
          final shown = occurrences[eventId];
          if (eventId.isEmpty ||
              touched.contains(eventId) ||
              shown == null ||
              shown.isEmpty ||
              !sent.contains(eref) ||
              !changeable.contains(eventId) ||
              versions[eref] == null) {
            continue;
          }
          final first = shown.first;
          if (first.title.trim().isEmpty || first.title != first.title.trim() || first.title.length > maxAiTitleLength) continue;
          if (first.isRepeating) {
            // Only one of the days it was shown on moves (as "this event only").
            final from = '${c['fromDate'] ?? ''}'.trim();
            if (!shown.any((o) => '${o.originalDate}' == from)) continue;
            final to = slotOf(c['date'], c['start'], 30);
            if (to == null) continue;
            out.add(ProposedChange(
              id: id(),
              commandType: 'MoveEventOccurrence',
              arguments: {'id': eventId, 'kind': 'move', 'originalDate': from, 'moveDate': '${to.day}', 'moveTime': '${to.at}'},
              versions: {eref: versions[eref]!},
              summary: _vi
                  ? '"${first.title}" (ngày $from): ${to.day} ${to.at}'
                  : '"${first.title}" (of $from): ${to.day} ${to.at}',
            ));
          } else {
            // Its length is kept unless the model gives another.
            final a = first.deviceStart, z = first.deviceEnd;
            final kept = a?.time != null && z?.time != null && a!.date == z!.date
                ? z.time!.minuteOfDay - a.time!.minuteOfDay
                : 0;
            final to = slotOf(c['date'], c['start'], lengthOf(c['minutes'], kept > 0 ? kept : 60));
            if (to == null) continue;
            out.add(ProposedChange(
              id: id(),
              commandType: 'MoveEvent',
              arguments: {
                'id': eventId,
                'title': first.title,
                'location': first.location,
                'calendarId': first.calendarId,
                'schedule': scheduleFieldsJson('event', eventId, to.spec, null),
              },
              versions: {eref: versions[eref]!},
              summary: '"${first.title}": ${to.day} ${to.at}–${to.end}',
            ));
          }
          touched.add(eventId);
      }
    }
    return out;
  }
  /// Titles of the items of the last chat context, by task id (for the
  /// summaries of the changes).
  Map<String, String> _titles = const {};

  @override
  Future<void> stop() async {
    for (final e in engines) {
      await e.stop();
    }
  }
}

/// P06b W4: the most earlier messages, their characters, the coming days
/// and their items a chat turn carries, and the most changes it proposes.
const chatHistoryMessages = 12;
const chatHistoryChars = 6000;
const chatAgendaDays = 7;
const chatAgendaItems = 15;
const maxChatChanges = 10;

/// What the chat's model writes: a reply, and the changes it proposes. Every
/// field is required (some providers' strict JSON needs it): "" or 0 when
/// not used.
const chatSchema = <String, Object?>{
  'type': 'object',
  'properties': {
    'reply': {'type': 'string'},
    'changes': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['create', 'rename', 'schedule', 'createEvent', 'moveEvent'],
          },
          'taskId': {'type': 'string'},
          'eventId': {'type': 'string'},
          'fromDate': {'type': 'string'},
          'title': {'type': 'string'},
          'date': {'type': 'string'},
          'start': {'type': 'string'},
          'minutes': {'type': 'integer'},
        },
        'required': ['action', 'taskId', 'eventId', 'fromDate', 'title', 'date', 'start', 'minutes'],
        'additionalProperties': false,
      },
    },
  },
  'required': ['reply', 'changes'],
  'additionalProperties': false,
};

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
