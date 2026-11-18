// P04b T12 (ADR-0064; p04b-plan.md B3–B9, B13, B14, §4): the sharing
// commands of the active profile. What changes the store goes through the
// gateway (naming a space, moving items, assigning a task, showing a
// space); what changes membership happens on the server, which decides
// (SHARE-003), and this device's cache follows it (the space sync's
// refresh). Keys never leave the device unwrapped (SpaceKeyService).
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:foundation/foundation.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart' hide Workspace;
import 'command_gateway.dart';
import 'profile_store.dart';
import 'member_card_handler.dart';
import 'record_kinds.dart';
import 'space_move_handler.dart';
import 'space_service.dart';
import 'sync/sealing.dart' show SealBroken;
import 'sync/space_key_service.dart';
import 'sync/space_keys.dart';
import 'sync/space_leaving.dart';
import 'sync/space_sync_service.dart';
import 'sync/workspace_keyring.dart';
import 'task_command_handler.dart';
import 'workspace_settings_handler.dart';

class DriftSharingService implements SharingService {
  DriftSharingService({
    required this.db,
    required this.gateway,
    required this.server,
    required this.keys,
    required this.keyring,
    required this.sync,
    DateTime Function()? clock,
  })  : _store = ProfileStore(db),
        _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DriftCommandGateway gateway;
  final SpaceGateway server;
  final SpaceKeyService keys;
  final WorkspaceKeyring keyring;
  final DriftSpaceSyncService sync;
  final ProfileStore _store;
  final DateTime Function() _clock;

  Future<String?> _account() async {
    final p = await _store.getActiveProfile();
    if (p == null || p.signedOut) return null;
    return p.binding?.accountId;
  }

  static SharingProblem _problemOf(RemoteFailure e) {
    if (e is SpaceFailure) {
      return switch (e.reason) {
        SpaceRefusal.noPublicKey => SharingProblem.syncOff,
        SpaceRefusal.noSuchInvitation => SharingProblem.noSuchInvitation,
        SpaceRefusal.alreadyMember => SharingProblem.alreadyMember,
        SpaceRefusal.spaceFull => SharingProblem.spaceFull,
        SpaceRefusal.tooManySpaces => SharingProblem.tooManySpaces,
        SpaceRefusal.ownerMustHandOver => SharingProblem.ownerMustHandOver,
        SpaceRefusal.nobodyWaiting || SpaceRefusal.notAMember => SharingProblem.notAllowed,
        SpaceRefusal.staleKey || SpaceRefusal.wrongMembers => SharingProblem.failed,
      };
    }
    return switch (e.kind) {
      RemoteFailureKind.unavailable => SharingProblem.offline,
      RemoteFailureKind.signedOut => SharingProblem.notSignedIn,
      RemoteFailureKind.notYours => SharingProblem.notAllowed,
      RemoteFailureKind.refused => SharingProblem.failed,
    };
  }

  /// Runs a server action; signed in, with the account's keys (B5).
  Future<SharingResult> _guard(Future<SharingResult> Function(String account) action, {bool needKeys = true}) async {
    final account = await _account();
    if (account == null) return const SharingResult.failed(SharingProblem.notSignedIn);
    try {
      if (needKeys && await keys.accountKeyPair(account) == null) {
        final stop = await sync.refresh();
        if (stop == SyncOutcome.notOn) return const SharingResult.failed(SharingProblem.syncOff);
        if (stop == SyncOutcome.signedOut) return const SharingResult.failed(SharingProblem.notSignedIn);
      }
      return await action(account);
    } on RemoteFailure catch (e) {
      return SharingResult.failed(_problemOf(e), e.detail);
    } on SpaceKeyException catch (e) {
      return SharingResult.failed(SharingProblem.failed, e.problem.name);
    }
  }

  SharingResult _resultOf(CommandResult r) => switch (r) {
        CommandOk() => const SharingResult(),
        CommandFailure(kind: CommandFailureKind.unauthorized) => SharingResult.failed(SharingProblem.notAllowed, r.reason ?? ''),
        CommandFailure() => SharingResult.failed(SharingProblem.failed, r.reason ?? ''),
      };

  Future<CommandResult> _asMember(String account, String spaceId, String type, Map<String, Object?> payload,
          CommandHandler handler) =>
      gateway.execute(
        Command(
          operationId: const Uuid().v7(),
          actor: ActorRef(ActorKind.member, account),
          workspaceId: spaceId,
          type: type,
          payload: payload,
          issuedAt: Instant(_clock().toUtc()),
        ),
        handler,
      );

  bool _validName(String name) => name.trim().isNotEmpty && name.trim().length <= maxSpaceNameLength;

  @override
  Future<SharingResult> createSpace(String name) async {
    if (!_validName(name)) return const SharingResult.failed(SharingProblem.failed, 'a space name is 1 to 60 characters');
    return _guard((account) async {
      final id = const Uuid().v7();
      await keys.createSpace(account, id);
      await sync.refresh();
      final named = _resultOf(await _asMember(account, id, 'NameSpace',
          {'op': 'setName', 'id': id, 'name': name.trim()}, const WorkspaceSettingsCommandHandler()));
      if (!named.ok) return named;
      await rulesSeen(id);
      final shown = await DriftSpaceService(db, gateway).show(id);
      if (shown is! CommandOk) return _resultOf(shown);
      return SharingResult(spaceId: id);
    });
  }

  @override
  Future<SharingResult> renameSpace(String spaceId, String name) async {
    if (!_validName(name)) return const SharingResult.failed(SharingProblem.failed, 'a space name is 1 to 60 characters');
    final account = await _account();
    if (account == null) return const SharingResult.failed(SharingProblem.notSignedIn);
    return _resultOf(await _asMember(account, spaceId, 'RenameSpace',
        {'op': 'setName', 'id': spaceId, 'name': name.trim()}, const WorkspaceSettingsCommandHandler()));
  }

  // --- moving items in and out (B3) ------------------------------------------

  @override
  Future<MovePreview> previewMove(String kind, String id, String to) async {
    final set = await moveSetOf(db, kind, id);
    final counts = <String, int>{};
    final titles = <String>[];
    var notes = false, dates = false;
    for (final (i, (k, _)) in set.records.indexed) {
      final r = set.rows[i];
      counts[k] = (counts[k] ?? 0) + 1;
      final t = r['title'] ?? r['name'];
      if (t is String && t.isNotEmpty && titles.length < 50) titles.add(t);
      if (r['notes'] is String && (r['notes'] as String).isNotEmpty) notes = true;
      if (k == 'schedule' || k == 'exception' || k == 'event') dates = true;
    }
    String? blocker = set.blocker;
    if (blocker == null) {
      final target = await (db.select(db.workspaces)..where((w) => w.id.equals(to))).getSingleOrNull();
      if (target == null || target.leftAt != null) blocker = 'not a space of this profile';
      if (set.workspaceId == to) blocker = 'it is already there';
    }
    return MovePreview(
      kind: kind,
      id: id,
      to: to,
      counts: counts,
      titles: titles,
      hasNotes: notes,
      hasDates: dates,
      confirmation: set.fingerprint,
      blocker: blocker,
    );
  }

  @override
  Future<SharingResult> move(MovePreview preview) async {
    if (preview.blocker != null) return SharingResult.failed(SharingProblem.cannotMove, preview.blocker!);
    final set = await moveSetOf(db, preview.kind, preview.id);
    final target = await (db.select(db.workspaces)..where((w) => w.id.equals(preview.to))).getSingleOrNull();
    if (target == null) return const SharingResult.failed(SharingProblem.cannotMove, 'no such space');
    final intoSpace = target.kind == 'shared';
    final Command cmd;
    final payload = {'op': 'move', 'id': preview.id, 'from': set.workspaceId, 'expect': preview.confirmation};
    if (intoSpace) {
      final account = await _account();
      if (account == null) return const SharingResult.failed(SharingProblem.notSignedIn);
      cmd = Command(
          operationId: const Uuid().v7(),
          actor: ActorRef(ActorKind.member, account),
          workspaceId: preview.to,
          type: 'MoveIntoSpace',
          payload: payload,
          issuedAt: Instant(_clock().toUtc()));
    } else {
      final personal = await _store.personalContext();
      if (personal == null || personal.workspaceId != preview.to) {
        return const SharingResult.failed(SharingProblem.cannotMove, 'out of a space is to the personal workspace');
      }
      cmd = Command(
          operationId: const Uuid().v7(),
          actor: personal.actor,
          workspaceId: personal.workspaceId,
          type: 'MoveOutOfSpace',
          payload: payload,
          issuedAt: Instant(_clock().toUtc()));
    }
    final r = await gateway.execute(cmd, SpaceMoveHandler(preview.kind));
    if (r is CommandFailure && (r.reason ?? '').contains('changed')) {
      return SharingResult.failed(SharingProblem.changedSinceShown, r.reason ?? '');
    }
    if (r is CommandFailure && r.kind == CommandFailureKind.validationFailed) {
      return SharingResult.failed(SharingProblem.cannotMove, r.reason ?? '');
    }
    return _resultOf(r);
  }

  // --- invitations and members (B6, B7, B13) --------------------------------

  @override
  Future<SharingResult> invite(String spaceId, SpaceRole role, InviteKind kind) => _guard((_) async {
        final i = await keys.invite(spaceId, role, kind);
        return SharingResult(
            spaceId: spaceId,
            invitation: InvitationToGive(code: i.code, grouped: i.grouped, link: i.link, kind: kind, role: role));
      });

  @override
  Future<List<RemoteInvitation>> invitations(String spaceId) => server.invitations(spaceId);

  @override
  Future<SharingResult> cancelInvitation(String spaceId, String codeHash) => _guard((_) async {
        await server.cancelInvitation(codeHash);
        return SharingResult(spaceId: spaceId);
      }, needKeys: false);

  @override
  Future<SharingResult> peek(String text) async {
    final code = parseInvitation(text);
    if (code == null) return const SharingResult.failed(SharingProblem.noSuchInvitation);
    return _guard((_) async {
      final p = await keys.peek(code);
      return SharingResult(spaceId: p.workspaceId, preview: p);
    }, needKeys: false);
  }

  @override
  Future<SharingResult> join(String text, {String? name}) async {
    final code = parseInvitation(text);
    if (code == null) return const SharingResult.failed(SharingProblem.noSuchInvitation);
    final given = name?.trim() ?? '';
    if (given.length > maxMemberNameLength) {
      return const SharingResult.failed(SharingProblem.failed, 'a name is at most 60 characters');
    }
    return _guard((account) async {
      // The person's name goes with the request, sealed for the owner: the
      // one typed when joining, else the profile's (T14 finding 1).
      final profileName = (await _store.getActiveProfile())?.displayName.trim() ?? '';
      final sent = given.isNotEmpty ? given : profileName;
      final a = await keys.accept(account, code, name: sent.isEmpty ? null : sent);
      await sync.refresh();
      final id = a.preview.workspaceId;
      // The rules were shown before joining (SHARE-005).
      await rulesSeen(id);
      return SharingResult(spaceId: id, preview: a.preview);
    });
  }

  @override
  Future<List<SpaceMemberView>> members(String spaceId) async {
    final account = await _account();
    final names = await memberNamesOf(db, spaceId);
    final pair = account == null ? null : await keys.accountKeyPair(account);
    return [
      for (final m in await server.members(spaceId))
        SpaceMemberView(
          accountId: m.accountId,
          role: m.role,
          status: m.status,
          isMe: m.accountId == account,
          name: names[m.accountId] ?? await _sealedName(m, pair, spaceId),
        ),
    ];
  }

  /// The name someone sent sealed for this account (the owner's), or null.
  Future<String?> _sealedName(RemoteMember m, AccountKeyPair? pair, String spaceId) async {
    final sealed = m.sealedName;
    if (sealed == null || pair == null) return null;
    try {
      return await openNameAs(sealed, pair, spaceId, m.accountId);
    } on SealBroken {
      return null;
    }
  }

  @override
  Future<SharingResult> setMyName(String spaceId, String name) async {
    final account = await _account();
    if (account == null) return const SharingResult.failed(SharingProblem.notSignedIn);
    return _resultOf(await _asMember(account, spaceId, 'NameMember', {
      'op': 'setName',
      'id': memberCardIdOf(spaceId, account),
      'accountId': account,
      'name': name.trim(),
    }, const MemberCardHandler()));
  }

  @override
  Future<Map<String, String>> memberNames(String spaceId) => memberNamesOf(db, spaceId);

  @override
  Future<String?> myAccountId() => _account();

  @override
  Future<SpaceRules> rulesOf(String spaceId) async {
    final w = await (db.select(db.workspaces)..where((x) => x.id.equals(spaceId))).getSingleOrNull();
    return SpaceRules(
      leave: LeaveRule.values.where((r) => r.name == w?.leaveRule).firstOrNull ?? LeaveRule.disappear,
      export: ExportRule.values.where((r) => r.name == w?.exportRule).firstOrNull ?? ExportRule.ownerOnly,
      inviteDefault: InviteKind.values.where((r) => r.name == w?.inviteDefault).firstOrNull ?? InviteKind.approve,
    );
  }

  @override
  Future<SharingResult> approve(String spaceId, String accountId) => _guard((_) async {
        await keys.approve(spaceId, accountId);
        await sync.refresh();
        return SharingResult(spaceId: spaceId);
      });

  @override
  Future<SharingResult> removeMember(String spaceId, String accountId) => _guard((_) async {
        await server.removeMember(spaceId, accountId);
        // B8: a new key for the others; this device seals the space again
        // at its next sync of it (now, if it can).
        await keys.rotate(spaceId);
        await sync.refresh();
        await sync.syncSpace(spaceId);
        return SharingResult(spaceId: spaceId);
      });

  @override
  Future<SharingResult> leave(String spaceId) => _guard((_) async {
        await server.leaveSpace(spaceId);
        await leaveSpaceHere(db, gateway, keyring, spaceId);
        return SharingResult(spaceId: spaceId);
      }, needKeys: false);

  @override
  Future<SharingResult> setRole(String spaceId, String accountId, SpaceRole role) => _guard((_) async {
        await server.setRole(spaceId, accountId, role);
        await sync.refresh();
        return SharingResult(spaceId: spaceId);
      }, needKeys: false);

  @override
  Future<SharingResult> handOver(String spaceId, String accountId) => _guard((_) async {
        await server.handOver(spaceId, accountId);
        await sync.refresh();
        return SharingResult(spaceId: spaceId);
      }, needKeys: false);

  @override
  Future<SharingResult> setRules(String spaceId, SpaceRules rules) => _guard((_) async {
        await server.setRules(spaceId, rules);
        await sync.refresh();
        await rulesSeen(spaceId);
        return SharingResult(spaceId: spaceId);
      }, needKeys: false);

  @override
  Future<SharingResult> deleteSpace(String spaceId) => _guard((_) async {
        await server.deleteSpace(spaceId);
        await leaveSpaceHere(db, gateway, keyring, spaceId, forget: true);
        return SharingResult(spaceId: spaceId);
      }, needKeys: false);

  // --- assignment (B9) ------------------------------------------------------

  @override
  Future<SharingResult> assign(String taskId, String? accountId) async {
    final account = await _account();
    if (account == null) return const SharingResult.failed(SharingProblem.notSignedIn);
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) return const SharingResult.failed(SharingProblem.failed, 'task not found');
    return _resultOf(await gateway.execute(
      Command(
        operationId: const Uuid().v7(),
        actor: ActorRef(ActorKind.member, account),
        workspaceId: task.workspaceId,
        type: 'AssignTask',
        payload: {'op': 'assign', 'id': taskId, 'assigneeId': accountId},
        expectedVersion: Version(task.version),
        issuedAt: Instant(_clock().toUtc()),
      ),
      TaskCommandHandler(),
    ));
  }

  // --- the rules (SHARE-005) and export (B14) -------------------------------

  @override
  Future<List<RulesNotice>> rulesNotices() async => [
        for (final w in await (db.select(db.workspaces)..where((w) => w.kind.equals('shared'))).get())
          if (w.leftAt == null &&
              w.rulesChangedAt != null &&
              (w.rulesSeenAt == null || w.rulesSeenAt!.isBefore(w.rulesChangedAt!)))
            RulesNotice(
              spaceId: w.id,
              name: await spaceNameOf(db, w.id) ?? w.name,
              rules: SpaceRules(
                leave: LeaveRule.values.where((r) => r.name == w.leaveRule).firstOrNull ?? LeaveRule.disappear,
                export: ExportRule.values.where((r) => r.name == w.exportRule).firstOrNull ?? ExportRule.ownerOnly,
                inviteDefault: InviteKind.values.where((r) => r.name == w.inviteDefault).firstOrNull ?? InviteKind.approve,
              ),
              changedAt: w.rulesChangedAt!,
            ),
      ];

  @override
  Future<void> rulesSeen(String spaceId) async {
    final w = await (db.select(db.workspaces)..where((x) => x.id.equals(spaceId))).getSingleOrNull();
    if (w == null) return;
    await (db.update(db.workspaces)..where((x) => x.id.equals(spaceId)))
        .write(WorkspacesCompanion(rulesSeenAt: Value(w.rulesChangedAt ?? _clock().toUtc())));
  }

  @override
  Future<(ExportFile?, SharingProblem?)> exportSpace(String spaceId) async {
    final w = await (db.select(db.workspaces)..where((x) => x.id.equals(spaceId))).getSingleOrNull();
    if (w == null || w.kind != 'shared') return (null, SharingProblem.notAllowed);
    final account = await _account();
    final me = account == null
        ? null
        : await (db.select(db.spaceMembers)..where((m) => m.workspaceId.equals(spaceId) & m.accountId.equals(account)))
            .getSingleOrNull();
    final allowed = (w.leftAt != null && w.leftKeep == 'exportFirst') ||
        (me != null && me.status == 'active' && (me.role == 'owner' || w.exportRule == 'everyMember'));
    if (!allowed) return (null, SharingProblem.exportNotAllowed);
    final now = _clock().toUtc();
    final name = await spaceNameOf(db, spaceId) ?? w.name ?? '';
    final records = <String, Object?>{};
    var tasks = 0;
    for (final k in recordKinds) {
      if (!sharedSpaceKinds.contains(k.name)) continue;
      final rows = [for (final r in await k.readAll(db)) if (r['workspaceId'] == spaceId) r];
      records[k.exportKey] = rows;
      if (k.name == 'task') tasks = rows.length;
    }
    final text = jsonEncode({
      'format': 'lifeflow-space-copy',
      'formatVersion': 1,
      'exportedAt': now.toIso8601String(),
      'notice': 'A copy of a LifeFlow shared space. It cannot be restored as a profile.',
      'space': {'id': spaceId, 'name': name},
      'records': records,
    });
    final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return (ExportFile(suggestedName: 'lifeflow-space-${slug.isEmpty ? 'shared' : slug}-$date.json', contents: text, taskCount: tasks), null);
  }

  @override
  Future<SharingResult> forgetSpace(String spaceId) async {
    final w = await (db.select(db.workspaces)..where((x) => x.id.equals(spaceId))).getSingleOrNull();
    if (w == null || w.leftAt == null) return const SharingResult.failed(SharingProblem.notAllowed, 'still a member: leave first');
    await leaveSpaceHere(db, gateway, keyring, spaceId, forget: true);
    return SharingResult(spaceId: spaceId);
  }
}
