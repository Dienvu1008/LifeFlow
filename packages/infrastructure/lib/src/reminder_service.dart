// P02 T7 (ADR-0034): reminders of tasks and events.
//   DriftReminderService   set / read the reminders (commands on the task or
//                          event, through the gateway)
//   DriftReminderPlanner   what should be pending on the device now: the
//                          ACTIVE profile's reminders inside a rolling horizon
//   ReminderSync           keeps the device in step: on start, after every
//                          change, and periodically while the app runs
import 'dart:async';
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:time_kernel/time_kernel.dart' as tk;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'event_command_handlers.dart';
import 'profile_store.dart';
import 'reminder_rows.dart';
import 'schedule_mapping.dart';
import 'task_command_handler.dart';

class DriftReminderService implements ReminderService {
  DriftReminderService(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;
  final _uuid = const Uuid();

  @override
  Future<CommandResult> setReminders(ReminderSubject subject, String id, List<ReminderInput> reminders) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'no active profile');
    final int? version;
    final CommandHandler handler;
    switch (subject) {
      case ReminderSubject.task:
        final t = await (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
        version = t == null || t.deletedAt != null ? null : t.version;
        handler = TaskCommandHandler();
      case ReminderSubject.event:
        final e = await (db.select(db.events)..where((e) => e.id.equals(id))).getSingleOrNull();
        version = e == null || e.deletedAt != null ? null : e.version;
        handler = const EventCommandHandler();
    }
    if (version == null) return const CommandFailure(CommandFailureKind.notFound, reason: 'item not found');
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: subject == ReminderSubject.task ? 'SetTaskReminders' : 'SetEventReminders',
        payload: {'op': 'setReminders', 'id': id, 'reminders': [for (final r in reminders) reminderPayloadOf(r)]},
        expectedVersion: Version(version),
        issuedAt: Instant.now(),
      ),
      handler,
    );
  }

  @override
  Future<List<ReminderInput>> remindersOf(ReminderSubject subject, String id) async =>
      [for (final r in await liveReminders(db, subject.name, id)) reminderInputOf(r)];
}

/// A stable positive 31-bit id for [key] (FNV-1a), so the same reminder
/// keeps its platform id across plans.
int notificationIdOf(String key) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(key)) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  final id = h & 0x7FFFFFFF;
  return id == 0 ? 1 : id;
}

class DriftReminderPlanner {
  DriftReminderPlanner(
    this.db,
    this.time, {
    this.horizon = const Duration(days: reminderHorizonDays),
    this.maxPending = 50,
    TimeOfDayValue? allDayTime,
  })  : allDayTime = allDayTime ??
            TimeOfDayValue(allDayReminderMinuteOfDay ~/ 60, allDayReminderMinuteOfDay % 60),
        _store = ProfileStore(db);

  final AppDatabase db;
  final DeviceTime time;

  /// Rolling horizon: reminders further ahead are scheduled on a later sync.
  final Duration horizon;

  /// Most pending reminders per profile (the earliest are kept).
  final int maxPending;

  /// When an all-day item reminds (in the device zone).
  final TimeOfDayValue allDayTime;
  final ProfileStore _store;

  Future<List<PlannedReminder>> plan() async {
    final profile = await _store.getActiveProfile();
    if (profile == null) return const [];
    final ws = profile.activeWorkspaceId.value;
    final now = time.now();
    final zone = time.zone();

    final bySubject = <(String, String), List<Reminder>>{};
    for (final r in await (db.select(db.reminders)
          ..where((r) => r.workspaceId.equals(ws) & r.deletedAt.isNull()))
        .get()) {
      bySubject.putIfAbsent((r.subjectType, r.subjectId), () => []).add(r);
    }
    if (bySubject.isEmpty) return const [];
    final taskIds = [for (final k in bySubject.keys) if (k.$1 == 'task') k.$2];
    final eventIds = [for (final k in bySubject.keys) if (k.$1 == 'event') k.$2];

    final tasks = {
      for (final t in await (db.select(db.tasks)..where((t) => t.id.isIn(taskIds) & t.deletedAt.isNull())).get())
        t.id: t,
    };
    final events = {
      for (final e in await (db.select(db.events)..where((e) => e.id.isIn(eventIds) & e.deletedAt.isNull())).get())
        e.id: e,
    };
    final schedules = {
      for (final s in await (db.select(db.schedules)
            ..where((s) => s.workspaceId.equals(ws) & s.deletedAt.isNull() & s.subjectId.isIn([...taskIds, ...eventIds])))
          .get())
        (s.subjectType, s.subjectId): s,
    };
    final exceptions = <(String, String), List<tk.OccurrenceException>>{};
    for (final e in await (db.select(db.occurrenceExceptions)
          ..where((e) => e.deletedAt.isNull() & e.subjectId.isIn([...taskIds, ...eventIds])))
        .get()) {
      exceptions.putIfAbsent((e.subjectType, e.subjectId), () => []).add(exceptionOf(e));
    }
    final done = {
      for (final c in await (db.select(db.occurrenceCompletions)
            ..where((c) => c.deletedAt.isNull() & c.taskId.isIn(taskIds)))
          .get())
        c.id,
    };

    final out = <(tk.ReminderTrigger, String, String)>[]; // trigger, title, body
    for (final entry in bySubject.entries) {
      final (type, id) = entry.key;
      final String title;
      bool Function(tk.Occurrence)? include;
      if (type == 'task') {
        final t = tasks[id];
        // A trashed or finished task reminds of nothing (one-off: the task
        // is done; repeating: each done occurrence is skipped).
        if (t == null || t.status == 'done' || t.status == 'cancelled') continue;
        title = t.title;
        include = (o) => !done.contains(completionIdOf(id, o.originalDate));
      } else {
        final e = events[id];
        if (e == null || e.status == 'cancelled') continue;
        title = e.title;
      }
      final rows = entry.value..sort((a, b) => a.id.compareTo(b.id));
      final rules = rows.map(reminderRuleOf).nonNulls.toList();
      final s = schedules[(type, id)];
      tk.ScheduleSpec? spec;
      tk.RecurrenceRule? rule;
      if (s != null) {
        try {
          (spec, rule) = readSchedule(s);
        } on BadScheduleRow {
          spec = null; // an unreadable schedule never reminds
        }
      }
      for (final trig in tk.remindersInHorizon(
        seriesId: '$type:$id',
        spec: spec,
        rule: rule,
        exceptions: exceptions[(type, id)] ?? const [],
        reminders: rules,
        now: now,
        horizon: horizon,
        deviceZone: zone,
        allDayTime: allDayTime,
        include: include,
      )) {
        out.add((trig, title, _body(trig, zone)));
      }
    }
    out.sort((a, b) {
      final c = a.$1.at.utc.compareTo(b.$1.at.utc);
      return c != 0 ? c : a.$1.key.compareTo(b.$1.key);
    });
    final used = <int>{};
    return [
      for (final (trig, title, body) in out.take(maxPending))
        PlannedReminder(id: _unique(notificationIdOf(trig.key), used), key: trig.key, at: trig.at, title: title, body: body),
    ];
  }

  static int _unique(int id, Set<int> used) {
    var i = id;
    while (!used.add(i)) {
      i = (i + 1) & 0x7FFFFFFF;
      if (i == 0) i = 1;
    }
    return i;
  }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "Starts Tue 10 Nov, 09:00", "Due Fri 13 Nov", "Ends …"; the zone when
  /// it is not the device's. An absolute reminder: "Reminder".
  static String _body(tk.ReminderTrigger t, String deviceZone) {
    final o = t.occurrence;
    if (o == null) return 'Reminder';
    final s = o.schedule;
    final (label, p) = s.start != null
        ? ('Starts', s.start!)
        : s.deadline != null
            ? ('Due', s.deadline!)
            : ('Ends', s.end!);
    final d = p.date;
    final date = '${_wd[d.weekday.index]} ${d.day} ${_mo[d.month - 1]}';
    return switch (p) {
      tk.DatePoint() => '$label $date',
      tk.TimedPoint(:final wallClock) => wallClock.zone == deviceZone
          ? '$label $date, ${wallClock.time}'
          : '$label $date, ${wallClock.time} (${wallClock.zone})',
    };
  }
}

/// Keeps the device's pending reminders equal to the plan of the ACTIVE
/// profile: on [start], after any change to tasks, events, schedules,
/// exceptions, completions or reminders (debounced), and every [refresh]
/// while running (the horizon rolls forward). Stopping does NOT cancel
/// anything: reminders must fire with the app closed. A profile switch or
/// sign-out replaces them, because the next profile's sync makes the pending
/// set exactly its own plan.
class ReminderSync {
  ReminderSync(
    this.db,
    this.planner,
    this.scheduler, {
    this.debounce = const Duration(milliseconds: 400),
    this.refresh = const Duration(hours: 6),
    this.onError,
  });

  final AppDatabase db;
  final DriftReminderPlanner planner;
  final ReminderScheduler scheduler;
  final Duration debounce;
  final Duration refresh;
  final void Function(Object error)? onError;

  StreamSubscription<void>? _sub;
  Timer? _debounce;
  Timer? _periodic;
  bool _stopped = false;
  Future<void> _last = Future<void>.value();

  /// The last plan handed to the device (for tests and diagnostics).
  List<PlannedReminder>? lastPlan;

  /// Starts (or, after [stop], restarts) watching, and syncs once.
  Future<void> start() async {
    _stopped = false;
    await _sub?.cancel();
    _periodic?.cancel();
    _sub = db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.tasks, db.events, db.schedules, db.occurrenceExceptions, db.occurrenceCompletions, db.reminders,
        ]))
        .listen((_) => _soon());
    _periodic = Timer.periodic(refresh, (_) => syncNow());
    await syncNow();
  }

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => syncNow());
  }

  /// Plans and hands the plan to the device; runs one at a time.
  Future<void> syncNow() => _last = _last.then((_) async {
        if (_stopped) return;
        try {
          final plan = await planner.plan();
          if (_stopped) return;
          await scheduler.sync(plan);
          lastPlan = plan;
        } catch (e) {
          onError?.call(e);
        }
      });

  /// Stops watching (the pending reminders stay).
  Future<void> stop() async {
    _stopped = true;
    _debounce?.cancel();
    _periodic?.cancel();
    await _sub?.cancel();
    await _last;
  }
}
