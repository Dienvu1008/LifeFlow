import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/ui.dart';

/// In-memory stand-in for the application ports. Like the real implementation
/// the task stream is bound to the profile that is active when it subscribes
/// (LF-INV-ID-002), so a UI that forgets to re-subscribe after a switch fails.
class FakeWorld
    implements
        TaskQueries,
        TaskService,
        ProfileService,
        AccountService,
        DataTransferService,
        FileGateway,
        SettingsService,
        TaskScheduling,
        AgendaQueries,
        ZoneCatalog {
  FakeWorld({
    required Map<String, List<TaskView>> tasks,
    required this.profiles,
    required this.activeId,
  }) : _tasks = tasks;

  final Map<String, List<TaskView>> _tasks;
  final List<ProfileView> profiles;
  String activeId;

  /// Every service call, in order, e.g. `create:Title:parentId`.
  final calls = <String>[];

  /// When set, the next write returns this failure instead of applying.
  CommandFailure? failNext;

  final _changes = StreamController<void>.broadcast();
  var _n = 0;

  List<TaskView> _mine() => _tasks[activeId]!;

  /// The task list of profile [id] (test setup).
  List<TaskView> tasks(String id) => _tasks[id]!;

  @override
  Stream<List<TaskView>> watchTasks() async* {
    final id = activeId; // bound at subscribe time
    yield List.of(_tasks[id]!);
    await for (final _ in _changes.stream) {
      yield List.of(_tasks[id]!);
    }
  }

  CommandResult? _failure() {
    final f = failNext;
    failNext = null;
    return f;
  }

  @override
  Future<CommandResult> create(String title, {String? parentId}) async {
    calls.add('create:$title:$parentId');
    final f = _failure();
    if (f != null) return f;
    final id = 'new${_n++}';
    _mine().add(TaskView(
        id: id,
        title: title,
        status: 'inbox',
        parentId: parentId,
        createdAt: DateTime(2026)));
    _changes.add(null);
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> rename(String id, String title) async {
    calls.add('rename:$id:$title');
    final f = _failure();
    if (f != null) return f;
    _replace(id, (t) => _copy(t, title: title));
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> complete(String id,
      {required bool withDescendants}) async {
    calls.add('complete:$id:$withDescendants');
    final f = _failure();
    if (f != null) return f;
    _replace(id, (t) => _copy(t, status: 'done'));
    if (withDescendants) {
      for (final c in _mine().where((t) => t.parentId == id).toList()) {
        _replace(c.id, (t) => _copy(t, status: 'done'));
      }
    }
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> reopen(String id) async {
    calls.add('reopen:$id');
    final f = _failure();
    if (f != null) return f;
    _replace(id, (t) => _copy(t, status: 'todo'));
    return CommandOk(id, Version.initial, const []);
  }

  @override
  Future<CommandResult> trash(String id, {bool withSubtasks = false}) async {
    calls.add(withSubtasks ? 'trash:$id:all' : 'trash:$id');
    final f = _failure();
    if (f != null) return f;
    final list = _mine();
    final gone = list.firstWhere((t) => t.id == id);
    if (withSubtasks) {
      final ids = {id};
      var grew = true;
      while (grew) {
        grew = false;
        for (final t in list) {
          if (t.parentId != null && ids.contains(t.parentId) && ids.add(t.id)) grew = true;
        }
      }
      list.removeWhere((t) => ids.contains(t.id));
    } else {
      list.removeWhere((t) => t.id == id);
      for (var i = 0; i < list.length; i++) {
        final t = list[i];
        if (t.parentId == id) {
          list[i] = TaskView(
              id: t.id, title: t.title, status: t.status,
              parentId: gone.parentId, createdAt: t.createdAt);
        }
      }
    }
    _changes.add(null);
    return CommandOk(id, Version.initial, const []);
  }

  // --- SettingsService --------------------------------------------------------
  SubtaskTrashPolicy trashPolicy = SubtaskTrashPolicy.ask;

  @override
  Future<SubtaskTrashPolicy> subtaskTrashPolicy() async => trashPolicy;

  @override
  Future<void> setSubtaskTrashPolicy(SubtaskTrashPolicy policy) async {
    calls.add('setTrashPolicy:${policy.name}');
    trashPolicy = policy;
  }

  PlanningSettings planning = const PlanningSettings();

  @override
  Future<PlanningSettings> planningSettings() async => planning;

  @override
  Future<void> setPlanningSettings(PlanningSettings settings) async {
    final s = settings.clamped();
    calls.add('setPlanning:${s.maxOccurrences}:${s.maxWindowDays}:'
        '${s.defaultMonthEnd.name}:${s.firstDayOfWeek.name}');
    planning = s;
  }

  // --- TaskScheduling + AgendaQueries + ZoneCatalog ---------------------------

  /// What Today and Upcoming show (test setup; done flags follow the calls).
  Agenda today = const Agenda([]);
  Agenda upcoming = const Agenda([]);

  @override
  Future<CommandResult> setSchedule(String taskId, TaskScheduleInput? schedule) async {
    calls.add('setSchedule:$taskId:${describeInput(schedule)}');
    final f = _failure();
    if (f != null) return f;
    _replace(taskId, (t) => _copy(t, schedule: schedule, setSchedule: true));
    return CommandOk(taskId, Version.initial, const []);
  }

  @override
  Future<CommandResult> changeOccurrence(
      String taskId, LocalDate originalDate, OccurrenceChange? change) async {
    final what = switch (change) {
      null => 'undo',
      SkipThisOccurrence() => 'skip',
      MoveThisOccurrence(:final toDate) => 'move>$toDate',
    };
    calls.add('change:$taskId@$originalDate:$what');
    final f = _failure();
    if (f != null) return f;
    _changes.add(null);
    return CommandOk(taskId, Version.initial, const []);
  }

  @override
  Future<CommandResult> setOccurrenceDone(String taskId, LocalDate originalDate,
      {required bool done}) async {
    calls.add('occurrenceDone:$taskId@$originalDate:$done');
    final f = _failure();
    if (f != null) return f;
    Agenda mark(Agenda a) => Agenda([
          for (final i in a.items)
            i.taskId == taskId && i.originalDate == originalDate
                ? AgendaItem(
                    taskId: i.taskId,
                    title: i.title,
                    originalDate: i.originalDate,
                    start: i.start,
                    end: i.end,
                    deadline: i.deadline,
                    isRepeating: i.isRepeating,
                    isDone: done,
                    isMoved: i.isMoved,
                    isOverdue: i.isOverdue)
                : i,
        ], truncated: a.truncated);
    today = mark(today);
    upcoming = mark(upcoming);
    _changes.add(null);
    return CommandOk(taskId, Version.initial, const []);
  }

  @override
  Future<TaskScheduleInput?> scheduleOf(String taskId) async =>
      _mine().where((t) => t.id == taskId).firstOrNull?.schedule;

  Stream<Agenda> _agenda(Agenda Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<Agenda> watchToday() => _agenda(() => today);

  @override
  Stream<Agenda> watchUpcoming({int days = 14}) => _agenda(() => upcoming);

  @override
  Stream<Agenda> watchRange(LocalDate from, LocalDate to) => _agenda(() => const Agenda([]));

  static const zones = ['Asia/Ho_Chi_Minh', 'Europe/Berlin', 'UTC'];

  @override
  List<String> zoneNames() => zones;

  @override
  bool isKnown(String zone) => zones.contains(zone);

  @override
  Future<ProfileView?> active() async =>
      profiles.firstWhere((p) => p.id == activeId).asActive(true);

  @override
  Future<List<ProfileView>> list() async =>
      [for (final p in profiles) p.asActive(p.id == activeId)];

  @override
  Future<CommandResult> delete(String profileId) async {
    calls.add('deleteProfile:$profileId');
    final f = _failure();
    if (f != null) return f;
    profiles.removeWhere((p) => p.id == profileId);
    _tasks.remove(profileId);
    return CommandOk(profileId, Version.initial, const []);
  }

  @override
  Future<CommandResult> switchTo(String profileId) async {
    calls.add('switch:$profileId');
    final f = _failure();
    if (f != null) return f;
    activeId = profileId;
    return CommandOk(profileId, Version.initial, const []);
  }

  // --- DataTransferService + FileGateway --------------------------------------

  /// What the save dialog answers (false = the user cancelled).
  bool saveResult = true;

  /// What the open dialog returns (null = cancelled).
  String? pickResult;
  bool pickTooLarge = false;
  bool pickThrows = false;

  /// What inspect returns; default: a profile not on this device.
  RestorePreview? nextPreview;

  /// What the next restores return, in order; when empty, a restore adds a
  /// new profile.
  final restoreResults = <RestoreOutcome>[];
  bool canUndo = false;

  @override
  Future<ExportFile> exportActiveProfile() async {
    calls.add('export');
    return ExportFile(
        suggestedName: 'lifeflow-test-2026-11-07.lifeflow.json',
        contents: '{"fake":"export"}',
        taskCount: _mine().length);
  }

  @override
  Future<RestorePreview> inspect(String text) async {
    calls.add('inspect:$text');
    return nextPreview ??
        const RestoreAsNewProfile(displayName: 'Backup of work', taskCount: 3);
  }

  @override
  Future<RestoreOutcome> restore(String text, {RestoreChoice? choice}) async {
    calls.add('restore:$text:${_choice(choice)}');
    if (restoreResults.isNotEmpty) {
      final r = restoreResults.removeAt(0);
      if (r is RestoredInto && !r.changedNothing) canUndo = true;
      return r;
    }
    final id = 'restored${_n++}';
    profiles.add(ProfileView(
        id: id, displayName: 'Backup of work', isActive: false, isBound: false));
    _tasks[id] = [];
    return Restored(profiles.last, taskCount: 3);
  }

  static String _choice(RestoreChoice? c) => c == null
      ? '-'
      : c.mode == RestoreMode.overwrite
          ? 'overwrite'
          : 'merge(newer=${c.takeNewer},missing=${c.addMissing},keepParents=${c.keepDeviceParents})';

  @override
  Future<bool> canUndoRestore() async => canUndo;

  @override
  Future<RestoreOutcome> undoLastRestore() async {
    calls.add('undo');
    canUndo = false;
    return const RestoredInto(added: 0, updated: 1, removed: 0, undoAvailable: false);
  }

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    calls.add('save:$suggestedName');
    return saveResult;
  }

  @override
  Future<String?> pickText() async {
    calls.add('pick');
    if (pickTooLarge) throw const FileTooLarge();
    if (pickThrows) throw StateError('disk error');
    return pickResult;
  }

  // --- AccountService (mirrors DriftAccountService's rules) -----------------

  @override
  bool signInAvailable = true;

  /// When set, the next sign-in fails with this message.
  String? signInFailure;
  String? _pendingProvider;

  String _providerOf(SignInRequest r) => switch (r) {
        EmailPasswordSignIn() => 'email',
        OAuthSignIn(:final provider) => provider,
      };

  @override
  Future<SignInOutcome> signIn(SignInRequest request) async {
    final provider = _providerOf(request);
    calls.add('signIn:$provider');
    final f = signInFailure;
    if (f != null) {
      signInFailure = null;
      return SignInFailed(f);
    }
    // ADR-0024: the account's own (locked) profile is unlocked and opened.
    final owned = profiles.where((p) => p.isBound && p.provider == provider).firstOrNull;
    if (owned != null) {
      _setProfile(owned.id, bound: true, provider: provider, signedOut: false);
      activeId = owned.id;
      return SignedIn(owned.asActive(true), switchedProfile: true);
    }
    if (_mine().isEmpty) return _bind(provider, move: true);
    _pendingProvider = provider;
    return NeedsBindChoice(provider: provider);
  }

  @override
  Future<SignInOutcome> completeBind({required bool moveData}) async {
    calls.add('completeBind:$moveData');
    final provider = _pendingProvider!;
    _pendingProvider = null;
    return _bind(provider, move: moveData);
  }

  @override
  Future<void> cancelPendingBind() async {
    calls.add('cancelPendingBind');
    _pendingProvider = null;
  }

  @override
  Future<CommandResult> signOut() async {
    calls.add('signOut');
    // ADR-0024: keep the binding, lock it, move to a guest (create if none).
    final me = profiles.firstWhere((p) => p.id == activeId);
    _setProfile(activeId, bound: true, provider: me.provider, signedOut: true);
    final guest = profiles.where((p) => !p.isBound).firstOrNull;
    if (guest == null) {
      final id = 'guest${_n++}';
      profiles.add(ProfileView(
          id: id, displayName: '', isActive: false, isBound: false));
      _tasks[id] = [];
      activeId = id;
    } else {
      activeId = guest.id;
    }
    return CommandOk(me.id, Version.initial, const []);
  }

  SignInOutcome _bind(String provider, {required bool move}) {
    if (move) {
      _setProfile(activeId, bound: true, provider: provider);
      return SignedIn(profiles.firstWhere((p) => p.id == activeId).asActive(true));
    }
    final id = 'acct${_n++}';
    profiles.add(ProfileView(
        id: id, displayName: '', isActive: false, isBound: true, provider: provider));
    _tasks[id] = [];
    activeId = id;
    return SignedIn(profiles.last.asActive(true), switchedProfile: true);
  }

  void _setProfile(String id,
      {required bool bound, String? provider, bool signedOut = false}) {
    final i = profiles.indexWhere((p) => p.id == id);
    final p = profiles[i];
    profiles[i] = ProfileView(
        id: p.id,
        displayName: p.displayName,
        isActive: p.isActive,
        isBound: bound,
        provider: provider,
        isSignedOut: signedOut);
  }

  void _replace(String id, TaskView Function(TaskView) f) {
    final list = _mine();
    final i = list.indexWhere((t) => t.id == id);
    list[i] = f(list[i]);
    _changes.add(null);
  }

  TaskView _copy(TaskView t,
          {String? title, String? status, TaskScheduleInput? schedule, bool setSchedule = false}) =>
      TaskView(
        id: t.id,
        title: title ?? t.title,
        status: status ?? t.status,
        parentId: t.parentId,
        createdAt: t.createdAt,
        schedule: setSchedule ? schedule : t.schedule,
      );

  /// Events, calendars and the calendar range (P02 T6b).
  late final FakeCalendar calendar = FakeCalendar(calls);

  void dispose() {
    _changes.close();
    calendar.dispose();
  }
}

/// In-memory events, calendars and calendar range. Writes are recorded in
/// the shared [calls] list; the range shown is whatever [range] is set to.
class FakeCalendar implements EventService, CalendarQueries {
  FakeCalendar(this.calls);
  final List<String> calls;

  CalendarRange range = const CalendarRange(events: [], tasks: [], conflicts: []);
  final calendars = <CalendarView>[];
  final events = <String, EventDetails>{};
  CommandFailure? failNext;

  /// Every range a view asked for, as `from..to`.
  final ranges = <String>[];

  final _changes = StreamController<void>.broadcast();
  var _n = 0;

  /// Re-emits the range and the calendars (after a test changed them).
  void changed() => _changes.add(null);

  CommandResult _ok(String id) {
    _changes.add(null);
    return CommandOk(id, Version.initial, const []);
  }

  CommandFailure? _failure() {
    final f = failNext;
    failNext = null;
    return f;
  }

  @override
  Stream<CalendarRange> watchRange(LocalDate from, LocalDate to) async* {
    ranges.add('$from..$to');
    yield range;
    await for (final _ in _changes.stream) {
      yield range;
    }
  }

  // --- EventService -----------------------------------------------------------
  @override
  Future<CommandResult> create(EventInput input) async {
    calls.add('event.create:${describeEvent(input)}');
    final f = _failure();
    if (f != null) return f;
    final id = 'ev${_n++}';
    events[id] = EventDetails(id: id, input: input, isCancelled: false);
    return _ok(id);
  }

  @override
  Future<CommandResult> update(String eventId, EventInput input) async {
    calls.add('event.update:$eventId:${describeEvent(input)}');
    final f = _failure();
    if (f != null) return f;
    events[eventId] = EventDetails(id: eventId, input: input, isCancelled: events[eventId]?.isCancelled ?? false);
    return _ok(eventId);
  }

  @override
  Future<CommandResult> setCancelled(String eventId, {required bool cancelled}) async {
    calls.add('event.cancelled:$eventId:$cancelled');
    return _failure() ?? _ok(eventId);
  }

  @override
  Future<CommandResult> trash(String id) async {
    calls.add(id.startsWith('cal') ? 'calendar.trash:$id' : 'event.trash:$id');
    final f = _failure();
    if (f != null) return f;
    calendars.removeWhere((c) => c.id == id);
    return _ok(id);
  }

  @override
  Future<CommandResult> restore(String eventId) async {
    calls.add('event.restore:$eventId');
    return _failure() ?? _ok(eventId);
  }

  @override
  Future<CommandResult> changeOccurrence(String eventId, LocalDate originalDate, EventOccurrenceChange? change) async {
    final what = switch (change) {
      null => 'undo',
      SkipEventOccurrence() => 'skip',
      CancelEventOccurrence() => 'cancel',
      MoveEventOccurrence(:final toDate) => 'move>$toDate',
      EditEventOccurrence(:final title) => 'edit>$title',
    };
    calls.add('event.change:$eventId@$originalDate:$what');
    return _failure() ?? _ok(eventId);
  }

  @override
  Future<EventDetails?> details(String eventId) async => events[eventId];

  // --- Calendars --------------------------------------------------------------
  // CalendarService's create/update clash with EventService's, so the port is
  // the adapter [calendarService] over the methods below.
  late final CalendarService calendarService = _CalendarPort(this);

  Stream<List<CalendarView>> watchCalendars() async* {
    yield List.of(calendars);
    await for (final _ in _changes.stream) {
      yield List.of(calendars);
    }
  }

  Future<CommandResult> createCalendar(String name, int color) async {
    calls.add('calendar.create:$name:${color.toRadixString(16)}');
    final f = _failure();
    if (f != null) return f;
    final id = 'cal${_n++}';
    calendars.add(CalendarView(id: id, name: name, color: color));
    return _ok(id);
  }

  Future<CommandResult> updateCalendar(String id, String? name, int? color) async {
    calls.add('calendar.update:$id:$name:${color?.toRadixString(16)}');
    final f = _failure();
    if (f != null) return f;
    final i = calendars.indexWhere((c) => c.id == id);
    final c = calendars[i];
    calendars[i] = CalendarView(id: id, name: name ?? c.name, color: color ?? c.color);
    return _ok(id);
  }

  void dispose() => _changes.close();
}

/// [CalendarService] over [FakeCalendar] (its own create/update signatures).
class _CalendarPort implements CalendarService {
  _CalendarPort(this.f);
  final FakeCalendar f;
  @override
  Future<CommandResult> create(String name, {int color = 0xFF00897B}) => f.createCalendar(name, color);
  @override
  Future<CommandResult> update(String calendarId, {String? name, int? color}) =>
      f.updateCalendar(calendarId, name, color);
  @override
  Future<CommandResult> trash(String calendarId) => f.trash(calendarId);
  @override
  Stream<List<CalendarView>> watchCalendars() => f.watchCalendars();
}

/// A compact form of an event input for [FakeWorld.calls].
String describeEvent(EventInput e) {
  final r = e.repeat;
  return '${e.title}|${e.start}|${e.end ?? '-'}|${e.location ?? '-'}|${e.calendarId ?? '-'}|'
      '${r == null ? '-' : '${r.frequency.name}/${r.interval}'}';
}

extension on ProfileView {
  ProfileView asActive(bool active) => ProfileView(
        id: id,
        displayName: displayName,
        isActive: active,
        isBound: isBound,
        provider: provider,
        isSignedOut: isSignedOut,
      );
}

TaskView task(String id, String title,
        {String? parent, String status = 'inbox', TaskScheduleInput? schedule}) =>
    TaskView(
        id: id,
        title: title,
        status: status,
        parentId: parent,
        createdAt: DateTime(2026),
        schedule: schedule);

/// A compact, comparable form of a schedule input for [FakeWorld.calls].
String describeInput(TaskScheduleInput? s) {
  if (s == null) return 'none';
  final r = s.repeat;
  final repeat = r == null
      ? '-'
      : '${r.frequency.name}/${r.interval}/'
          '${r.weekdays == null ? '-' : (r.weekdays!.toList()..sort((a, b) => a.index - b.index)).map((d) => d.name).join('+')}/'
          '${switch (r.end) { RepeatForever() => 'forever', RepeatUntil(:final date) => 'until $date', RepeatTimes(:final count) => '$count times' }}/'
          '${r.monthEnd.name}/${r.weekStart.name}';
  return 'start=${s.start ?? '-'};end=${s.end ?? '-'};due=${s.deadline ?? '-'};repeat=$repeat';
}

/// The fixed "today" of widget tests (a Monday).
final testToday = LocalDate(2026, 11, 9);

/// The device zone of widget tests.
const testZone = 'Asia/Ho_Chi_Minh';

ProfileView profile(String id, String name,
        {bool bound = false, String? provider}) =>
    ProfileView(
        id: id,
        displayName: name,
        isActive: false,
        isBound: bound,
        provider: provider);

/// The full app with the ports overridden by [world].
Widget appWith(FakeWorld world, {StorageNotice? notice}) => ProviderScope(
      overrides: [
        taskQueriesProvider.overrideWithValue(world),
        taskServiceProvider.overrideWithValue(world),
        profileServiceProvider.overrideWithValue(world),
        accountServiceProvider.overrideWithValue(world),
        dataTransferServiceProvider.overrideWithValue(world),
        fileGatewayProvider.overrideWithValue(world),
        settingsServiceProvider.overrideWithValue(world),
        taskSchedulingProvider.overrideWithValue(world),
        agendaQueriesProvider.overrideWithValue(world),
        zoneCatalogProvider.overrideWithValue(world),
        deviceZoneProvider.overrideWithValue(testZone),
        todayProvider.overrideWithValue(() => testToday),
        eventServiceProvider.overrideWithValue(world.calendar),
        calendarServiceProvider.overrideWithValue(world.calendar.calendarService),
        calendarQueriesProvider.overrideWithValue(world.calendar),
        storageNoticeProvider.overrideWithValue(notice),
      ],
      child: const LifeFlowApp(),
    );
