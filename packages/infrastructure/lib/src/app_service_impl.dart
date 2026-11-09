// P01 T6a: infrastructure implementations of the ports the UI consumes
// (application/app_services.dart) plus the production authorization policy.
// Every write goes through the DriftCommandGateway (ADR-0011).
import 'package:application/application.dart';
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'profile_directory.dart';
import 'profile_store.dart';
import 'storage_security.dart';
import 'task_command_handler.dart';

/// MVP authorization policy (authorization-model.md): the owner of a workspace
/// may act on it; everyone else is denied (LF-INV-GOV-002, GS-11). Reads the
/// workspace owner from the store so it cannot be spoofed by the caller.
class WorkspaceOwnerAuthorization implements AuthorizationService {
  WorkspaceOwnerAuthorization(this.db);
  final AppDatabase db;

  @override
  Future<String?> denyReason(
      ActorRef actor, String action, ResourceRef ref) async {
    if (actor.kind != ActorKind.owner) {
      return 'only the workspace owner may act in the MVP';
    }
    final ws = await (db.select(db.workspaces)
          ..where((w) => w.id.equals(ref.workspaceId)))
        .getSingleOrNull();
    if (ws == null) return 'unknown workspace';
    if (ws.ownerId != actor.id) return 'not the owner of this workspace';
    return null;
  }
}

/// Device settings in the encrypted registry (not profile data).
class DirectorySettingsService implements SettingsService {
  DirectorySettingsService(this.directory);
  final ProfileDirectory directory;
  static const _subtaskTrash = 'subtaskTrashPolicy';

  @override
  Future<SubtaskTrashPolicy> subtaskTrashPolicy() async {
    final v = await directory.readSetting(_subtaskTrash);
    return SubtaskTrashPolicy.values
            .where((p) => p.name == v)
            .firstOrNull ??
        SubtaskTrashPolicy.ask;
  }

  @override
  Future<void> setSubtaskTrashPolicy(SubtaskTrashPolicy policy) =>
      directory.writeSetting(_subtaskTrash, policy.name);
}

/// Maps the startup self-check to the UI-facing notice (ADR-0021).
StorageNotice storageNoticeFrom(AtRestStatus s) => StorageNotice(
      atRestEncrypted: s.encrypted,
      trackedException: s.isTrackedException,
      message: s.warning,
    );

/// Read side: tasks of the ACTIVE profile's workspace, trash excluded.
class DriftTaskQueries implements TaskQueries {
  DriftTaskQueries(this.db) : _store = ProfileStore(db);
  final AppDatabase db;
  final ProfileStore _store;

  @override
  Stream<List<TaskView>> watchTasks() async* {
    final profile = await _store.getActiveProfile();
    if (profile == null) {
      yield const [];
      return;
    }
    final query = db.select(db.tasks)
      ..where((t) =>
          t.workspaceId.equals(profile.activeWorkspaceId.value) &
          t.deletedAt.isNull())
      // Insertion order: createdAt has second precision, rowid is exact.
      ..orderBy([(t) => OrderingTerm(expression: const CustomExpression<int>('rowid'))]);
    yield* query.watch().map((rows) => [
          for (final r in rows)
            TaskView(
              id: r.id,
              title: r.title,
              status: r.status,
              parentId: r.parentTaskId,
              createdAt: r.createdAt,
            ),
        ]);
  }
}

/// Write side for tasks via the gateway, acting as the active profile's owner.
class DriftTaskService implements TaskService {
  DriftTaskService(this.db, this.gateway) : _store = ProfileStore(db);
  final AppDatabase db;
  final CommandGateway gateway;
  final ProfileStore _store;
  final _handler = TaskCommandHandler();
  final _uuid = const Uuid();

  Future<CommandResult> _run(
    String type,
    Map<String, Object?> payload, {
    Version? expected,
  }) async {
    final profile = await _store.getActiveProfile();
    if (profile == null) {
      return const CommandFailure(CommandFailureKind.notFound,
          reason: 'no active profile');
    }
    return gateway.execute(
      Command(
        operationId: _uuid.v7(),
        actor: ActorRef(ActorKind.owner, profile.profileId.value),
        workspaceId: profile.activeWorkspaceId.value,
        type: type,
        payload: payload,
        expectedVersion: expected,
        issuedAt: Instant.now(),
      ),
      _handler,
    );
  }

  Future<Version?> _versionOf(String id) async {
    final row = await (db.select(db.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : Version(row.version);
  }

  Future<CommandResult> _update(
      String type, String id, Map<String, Object?> extra) async {
    final v = await _versionOf(id);
    if (v == null) {
      return const CommandFailure(CommandFailureKind.notFound,
          reason: 'task not found');
    }
    return _run(type, {'id': id, ...extra}, expected: v);
  }

  @override
  Future<CommandResult> create(String title, {String? parentId}) {
    final t = title.trim();
    if (t.isEmpty) {
      return Future.value(const CommandFailure(
          CommandFailureKind.validationFailed,
          reason: 'title is empty'));
    }
    return _run('CreateTask', {
      'op': 'create',
      'id': EntityId.generate().value,
      'title': t,
      'parentId': parentId,
    });
  }

  @override
  Future<CommandResult> rename(String id, String title) {
    final t = title.trim();
    if (t.isEmpty) {
      return Future.value(const CommandFailure(
          CommandFailureKind.validationFailed,
          reason: 'title is empty'));
    }
    return _update('RenameTask', id, {'op': 'rename', 'title': t});
  }

  @override
  Future<CommandResult> complete(String id, {required bool withDescendants}) =>
      _update(
        withDescendants ? 'CompleteTaskWithDescendants' : 'CompleteTaskOnly',
        id,
        {'op': 'complete', 'cascade': withDescendants ? 'all' : 'parentOnly'},
      );

  @override
  Future<CommandResult> reopen(String id) =>
      _update('ReopenTask', id, {'op': 'reopen'});

  @override
  Future<CommandResult> trash(String id, {bool withSubtasks = false}) => _update(
        withSubtasks ? 'TrashTaskWithSubtasks' : 'TrashTask',
        id,
        {'op': 'trash', 'cascade': withSubtasks ? 'all' : 'parentOnly'},
      );
}
