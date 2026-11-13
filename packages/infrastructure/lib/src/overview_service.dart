// P03 UX U2 (ADR-0046): the Overview's lists, colours and order. Every write
// is one command through the gateway (ADR-0011): the list handler, or the
// task and event handlers for a move or a colour.
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'event_command_handlers.dart';
import 'list_command_handler.dart';
import 'profile_store.dart';
import 'schedule_inputs.dart';
import 'schedule_mapping.dart';
import 'task_command_handler.dart';

class DriftOverviewQueries implements OverviewQueries {
  DriftOverviewQueries(this.db) : _store = ProfileStore(db);
  final AppDatabase db;
  final ProfileStore _store;

  @override
  Stream<List<TaskListView>> watchLists() async* {
    final profile = await _store.getActiveProfile();
    if (profile == null) {
      yield const [];
      return;
    }
    final ws = profile.activeWorkspaceId.value;
    final q = db.select(db.taskLists)
      ..where((l) => l.workspaceId.equals(ws) & l.deletedAt.isNull())
      ..orderBy([(l) => OrderingTerm.asc(l.orderKey), (l) => OrderingTerm.asc(l.id)]);
    yield* q.watch().map((rows) => [
          for (final l in rows) TaskListView(id: l.id, title: l.title, colorIndex: l.colorIndex, orderKey: l.orderKey)
        ]);
  }

  @override
  Stream<List<OverviewEventView>> watchEvents() async* {
    final profile = await _store.getActiveProfile();
    if (profile == null) {
      yield const [];
      return;
    }
    final ws = profile.activeWorkspaceId.value;
    final q = db.select(db.events).join([
      leftOuterJoin(
          db.schedules,
          db.schedules.subjectType.equals('event') &
              db.schedules.subjectId.equalsExp(db.events.id) &
              db.schedules.deletedAt.isNull()),
      leftOuterJoin(db.taskLists, db.taskLists.id.equalsExp(db.events.listId) & db.taskLists.deletedAt.isNull()),
    ])
      ..where(db.events.workspaceId.equals(ws) & db.events.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.events.orderKey), OrderingTerm.asc(db.events.id)]);
    yield* q.watch().map((rows) => [
          for (final row in rows)
            () {
              final e = row.readTable(db.events);
              final s = row.readTableOrNull(db.schedules);
              TaskScheduleInput? schedule;
              if (s != null) {
                try {
                  final (spec, rule) = readSchedule(s);
                  schedule = scheduleInputOf(spec, rule);
                } on BadScheduleRow {
                  schedule = null; // never shown half-read
                }
              }
              return OverviewEventView(
                id: e.id,
                title: e.title,
                listId: row.readTableOrNull(db.taskLists)?.id,
                colorIndex: e.colorIndex,
                orderKey: e.orderKey,
                isCancelled: e.status == 'cancelled',
                schedule: schedule,
              );
            }(),
        ]);
  }
}

class DriftOverviewService implements OverviewService {
  DriftOverviewService(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;
  final _uuid = const Uuid();
  static const _lists = ListCommandHandler();
  static final _tasks = TaskCommandHandler();
  static const _events = EventCommandHandler();

  Future<CommandResult> _run(CommandHandler handler, String type, Map<String, Object?> payload, int? version) async {
    final profile = await _store.getActiveProfile();
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
        expectedVersion: version == null ? null : Version(version),
        issuedAt: Instant.now(),
      ),
      handler,
    );
  }

  static const _notFound = CommandFailure(CommandFailureKind.notFound, reason: 'not found');

  Future<CommandResult> _onList(String id, String type, Map<String, Object?> payload, {bool trashed = false}) async {
    final l = await (db.select(db.taskLists)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (l == null || (l.deletedAt != null) != trashed) return _notFound;
    return _run(_lists, type, {...payload, 'id': id}, l.version);
  }

  Future<CommandResult> _onTask(String id, String type, Map<String, Object?> payload) async {
    final t = await (db.select(db.tasks)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (t == null || t.deletedAt != null) return _notFound;
    return _run(_tasks, type, {...payload, 'id': id}, t.version);
  }

  Future<CommandResult> _onEvent(String id, String type, Map<String, Object?> payload) async {
    final e = await (db.select(db.events)..where((x) => x.id.equals(id))).getSingleOrNull();
    if (e == null || e.deletedAt != null) return _notFound;
    return _run(_events, type, {...payload, 'id': id}, e.version);
  }

  static CommandResult? _titleError(String title) => title.trim().isEmpty
      ? const CommandFailure(CommandFailureKind.validationFailed, reason: 'title is empty')
      : null;

  static Map<String, Object?> _place(ItemPlace p) =>
      {'listId': p.listId, 'parentId': p.parentId, 'afterId': p.afterId};

  @override
  Future<CommandResult> createList(String title, {int? colorIndex}) async =>
      _titleError(title) ??
      await _run(_lists, 'CreateList',
          {'op': 'create', 'id': EntityId.generate().value, 'title': title.trim(), 'colorIndex': colorIndex}, null);

  @override
  Future<CommandResult> renameList(String listId, String title) async =>
      _titleError(title) ?? await _onList(listId, 'RenameList', {'op': 'rename', 'title': title.trim()});

  @override
  Future<CommandResult> setListColor(String listId, int? colorIndex) =>
      _onList(listId, 'SetListColor', {'op': 'setColor', 'colorIndex': colorIndex});

  @override
  Future<CommandResult> moveList(String listId, {String? afterId}) =>
      _onList(listId, 'MoveList', {'op': 'move', 'afterId': afterId});

  @override
  Future<CommandResult> trashList(String listId) => _onList(listId, 'TrashList', {'op': 'trash'});

  @override
  Future<CommandResult> restoreList(String listId) =>
      _onList(listId, 'RestoreList', {'op': 'restore'}, trashed: true);

  @override
  Future<CommandResult> moveTask(String taskId, ItemPlace place) =>
      _onTask(taskId, 'MoveTask', {'op': 'move', ..._place(place)});

  @override
  Future<CommandResult> moveEvent(String eventId, ItemPlace place) async => place.parentId != null
      ? const CommandFailure(CommandFailureKind.validationFailed, reason: 'an event cannot be under a task')
      : await _onEvent(eventId, 'MoveEvent', {'op': 'move', ..._place(place)});

  @override
  Future<CommandResult> setTaskColor(String taskId, int? colorIndex) =>
      _onTask(taskId, 'SetTaskColor', {'op': 'setColor', 'colorIndex': colorIndex});

  @override
  Future<CommandResult> setEventColor(String eventId, int? colorIndex) =>
      _onEvent(eventId, 'SetEventColor', {'op': 'setColor', 'colorIndex': colorIndex});
}
