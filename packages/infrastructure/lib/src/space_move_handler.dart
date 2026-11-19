// P04b T12 (ADR-0064; p04b-plan.md B2, B3, LF-INV-PRIV-002): moving an item
// into a shared space, or back out to the personal workspace, as ONE command
// through the gateway (FF-ARCH-06). The ids are kept (ID-001).
//   what moves  a list (with its tasks, their subtasks and its events), a
//               top-level task (with its subtasks), an event, a calendar
//               (with its events), a goal (with its milestones), or (P05a
//               T5) a document (with its live subdocuments and every
//               revision of each); with each task and event its schedule,
//               its occurrence changes and its done ticks. Reminders, focus
//               sessions, measurements and results stay personal (B2, B3);
//               goal links and document links stay where they are.
//   asked first the command carries what the person was shown (each moved
//               record and its version, from [moveSetOf]); if anything
//               changed since, nothing moves (PRIV-002: nothing moves
//               without confirmation)
//   never       Restricted data (ADR-0059), a tracked task (a habit or a
//               target; B2), an item already in the target, a subtask alone
// Into a space the actor is the member (the account), the command's
// workspace the space; out of it the actor is the profile, the command's
// workspace the personal one, and the person must be an owner or editor of
// the space (B4). Each moved record gets a new version above its last
// synced copy in the target (it may have been there before), and its own
// outbox row in the target; each workspace's sync then sends "moved away"
// from the source (sync_engine.dart).
//
// Payload: {op: 'move', id: root id, from: source workspace, expect: ['kind:id:version', ...]}
import 'dart:convert';

import 'package:application/application.dart';
import 'package:domain/domain.dart' show cloudSyncAllowed;
import 'package:drift/drift.dart';
import 'package:foundation/foundation.dart';

import 'app_database.dart';
import 'command_gateway.dart';
import 'record_kinds.dart';

/// The kinds an item to move can be (B3).
const movableKinds = {'taskList', 'task', 'event', 'calendar', 'goal', 'document'};

class SpaceMoveHandler implements CommandHandler {
  const SpaceMoveHandler(this.kind);

  /// The kind of the item moved (one handler per kind, so the gateway's own
  /// outbox row of the item has the right kind).
  final String kind;

  @override
  String get entityType => kind;

  @override
  Future<Version?> currentVersion(TxContext tx, Command cmd) async {
    final row = await recordKindByName[kind]!.readOne((tx as DriftTx).db, cmd.payload['id'] as String);
    return row == null ? null : Version(row['version'] as int);
  }

  @override
  Future<HandlerOutcome> apply(TxContext tx, Command cmd, Version newVersion) async {
    final db = (tx as DriftTx).db;
    if (cmd.payload['op'] != 'move' || !movableKinds.contains(kind)) throw DomainRejection('not a move');
    final id = cmd.payload['id'] as String;
    final from = cmd.payload['from'] as String?;
    final to = cmd.workspaceId;
    if (from == null || from == to) throw DomainRejection('it is already there');
    final target = await (db.select(db.workspaces)..where((w) => w.id.equals(to))).getSingleOrNull();
    final source = await (db.select(db.workspaces)..where((w) => w.id.equals(from))).getSingleOrNull();
    if (target == null || source == null) throw DomainRejection('unknown workspace');
    final intoSpace = target.kind == 'shared';
    if (intoSpace == (source.kind == 'shared')) throw DomainRejection('a move is between the personal workspace and a space');

    // Out of a space: the person must be its owner or an editor (B4).
    final profile = await (db.select(db.profiles)..where((p) => p.isActive.equals(true))).getSingle();
    if (!intoSpace) {
      final me = await (db.select(db.spaceMembers)
            ..where((m) => m.workspaceId.equals(from) & m.accountId.equals(profile.accountId ?? '')))
          .getSingleOrNull();
      if (me == null || me.status != 'active' || (me.role != 'owner' && me.role != 'editor')) {
        throw DomainRejection('only an owner or an editor moves things out of a space');
      }
    }

    final plan = await moveSetOf(db, kind, id);
    if (plan.blocker != null) throw DomainRejection(plan.blocker!);
    if (plan.workspaceId != from) throw DomainRejection('the item is not in that workspace');
    final expect = [for (final e in (cmd.payload['expect'] as List? ?? const [])) e as String];
    if (!_sameList(expect, plan.fingerprint)) throw DomainRejection('what would move changed: look again');

    final now = DateTime.now().toUtc();
    final owner = intoSpace ? cmd.actor.id : profile.id;
    for (final (k, rid) in plan.records) {
      final rk = recordKindByName[k]!;
      final row = (await rk.readOne(db, rid))!;
      final base = await (db.select(db.syncBase)
            ..where((b) => b.workspaceId.equals(to) & b.kind.equals(k) & b.recordId.equals(rid)))
          .getSingleOrNull();
      final version = (row['version'] as int) > (base?.version ?? 0) ? (row['version'] as int) + 1 : base!.version + 1;
      final moved = {
        ...row,
        'workspaceId': to,
        'ownerId': owner,
        'version': version,
        'updatedAt': now.millisecondsSinceEpoch,
        'changedBy': intoSpace ? cmd.actor.id : null,
        // What is not moved with it is no longer pointed at.
        if (k == 'task' && rid == id) 'taskListId': null,
        if (k == 'task') 'assigneeId': null,
        if (k == 'event' && !(kind == 'calendar')) 'calendarId': null,
        if (k == 'event' && !(kind == 'taskList')) 'listId': null,
        // P05a T5 (ADR-0070): the moved document leaves its parent behind;
        // its subdocuments keep theirs. A revision keeps who wrote it: only
        // its place and version change with the move, never its content.
        // One without an author (written in the personal workspace) is
        // named for the mover by the gateway, into a space (B10).
        if (k == 'document' && rid == id) 'parentId': null,
        if (k == 'documentRevision') 'changedBy': row['changedBy'],
      };
      await db.batch((b) => rk.upsert(b, db, [moved]));
      if (!(k == kind && rid == id)) {
        await db.into(db.outbox).insert(OutboxCompanion.insert(
              operationId: cmd.operationId,
              entityId: rid,
              entityType: k,
              workspaceId: to,
              actorId: cmd.actor.toString(),
              operationType: 'update',
              baseVersion: Value(base?.version),
              payload: jsonEncode({'id': rid, 'movedFrom': from}),
              createdAt: now,
            ));
      }
    }
    return HandlerOutcome(
      entityId: id,
      operationType: 'update',
      changeSet: {'id': id, 'movedFrom': from, 'records': plan.records.length},
      events: [DomainEvent(intoSpace ? 'MovedIntoSpace' : 'MovedOutOfSpace', {'id': id, 'kind': kind, 'to': to})],
    );
  }
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// What moving [id] (of [kind]) would take with it, in write order, and
/// what stops it.
class MoveSet {
  const MoveSet({required this.workspaceId, required this.records, required this.rows, this.blocker});

  /// Where the item is now.
  final String workspaceId;
  final List<(String kind, String id)> records;

  /// The records' rows, for the preview.
  final List<Map<String, dynamic>> rows;

  /// Why it cannot move, or null.
  final String? blocker;

  /// What the person is shown and confirms: each record and its version.
  List<String> get fingerprint => [
        for (final (i, (k, id)) in records.indexed) '$k:$id:${rows[i]['version']}',
      ];
}

/// The records a move of [id] takes (live ones only), and a blocker if it
/// must not move: Restricted data, a tracked task, a subtask alone.
Future<MoveSet> moveSetOf(AppDatabase db, String kind, String id) async {
  final rk = recordKindByName[kind];
  final root = rk == null ? null : await rk.readOne(db, id);
  if (rk == null || !movableKinds.contains(kind) || root == null || root['deletedAt'] != null) {
    return const MoveSet(workspaceId: '', records: [], rows: [], blocker: 'not found');
  }
  final ws = root['workspaceId'] as String;
  final out = <(String, String)>[];
  final rows = <Map<String, dynamic>>[];
  Future<void> add(String k, String rid) async {
    if (out.contains((k, rid))) return;
    final r = await recordKindByName[k]!.readOne(db, rid);
    if (r == null || r['deletedAt'] != null || r['workspaceId'] != ws) return;
    out.add((k, rid));
    rows.add(r);
  }

  Future<List<String>> ids(String sql, List<String> args) async => [
        for (final r in await db.customSelect(sql, variables: [for (final a in args) Variable<String>(a)]).get())
          r.read<String>('id')
      ];

  Future<void> addTaskTree(String taskId) async {
    final frontier = [taskId];
    while (frontier.isNotEmpty) {
      final t = frontier.removeAt(0);
      await add('task', t);
      frontier.addAll(await ids(
          'SELECT id FROM tasks WHERE parent_task_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid', [t, ws]));
    }
  }

  switch (kind) {
    case 'task':
      if (root['parentTaskId'] != null) {
        return MoveSet(workspaceId: ws, records: const [], rows: const [], blocker: 'move its top-level task');
      }
      await addTaskTree(id);
    case 'taskList':
      await add('taskList', id);
      for (final t in await ids(
          'SELECT id FROM tasks WHERE task_list_id = ? AND parent_task_id IS NULL AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid',
          [id, ws])) {
        await addTaskTree(t);
      }
      for (final e in await ids(
          'SELECT id FROM events WHERE list_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid', [id, ws])) {
        await add('event', e);
      }
    case 'event':
      await add('event', id);
    case 'calendar':
      await add('calendar', id);
      for (final e in await ids(
          'SELECT id FROM events WHERE calendar_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid', [id, ws])) {
        await add('event', e);
      }
    case 'document':
      // P05a T5 (ADR-0070, owner's C8): the document, its live subdocuments
      // at any depth, and the whole history of each. Links to tasks, events
      // and goals stay where they are (as goal links do).
      final docs = [id];
      for (var i = 0; i < docs.length; i++) {
        await add('document', docs[i]);
        docs.addAll(await ids(
            'SELECT id FROM documents WHERE parent_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY order_key, id',
            [docs[i], ws]));
      }
      for (final d in docs) {
        for (final r in await ids(
            'SELECT id FROM document_revisions WHERE document_id = ? AND workspace_id = ? ORDER BY document_version, id',
            [d, ws])) {
          await add('documentRevision', r);
        }
      }
    case 'goal':
      await add('goal', id);
      for (final m in await ids(
          'SELECT id FROM milestones WHERE goal_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid', [id, ws])) {
        await add('milestone', m);
      }
  }
  // Each task's and event's schedule, occurrence changes and done ticks.
  for (final (k, rid) in [...out]) {
    if (k != 'task' && k != 'event') continue;
    for (final s in await ids(
        'SELECT id FROM schedules WHERE subject_type = ? AND subject_id = ? AND workspace_id = ? AND deleted_at IS NULL', [k, rid, ws])) {
      await add('schedule', s);
    }
    for (final x in await ids(
        'SELECT id FROM occurrence_exceptions WHERE subject_type = ? AND subject_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid',
        [k, rid, ws])) {
      await add('exception', x);
    }
    if (k == 'task') {
      for (final c in await ids(
          'SELECT id FROM occurrence_completions WHERE task_id = ? AND workspace_id = ? AND deleted_at IS NULL ORDER BY rowid', [rid, ws])) {
        await add('completion', c);
      }
    }
  }
  String? blocker;
  for (final (i, (k, _)) in out.indexed) {
    final r = rows[i];
    if (!sharedSpaceKinds.contains(k)) blocker ??= 'a ${k} stays personal';
    if (!cloudSyncAllowed(dataClassOf(k, r))) blocker ??= 'restricted data never moves';
    if (k == 'task' && (r['isHabit'] == true || r['targetType'] != null)) {
      blocker ??= 'a tracked task moves only after its tracking is turned off';
    }
  }
  return MoveSet(workspaceId: ws, records: out, rows: rows, blocker: blocker);
}
