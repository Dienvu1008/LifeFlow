// P04b T8 (ADR-0060; p04b-plan.md B1, B2, B10, B14): one profile store holds
// its personal workspace and the shared spaces its account belongs to.
//   views      each view shows the space being shown, and only it; a switch
//              is one audited command; a stranger's space cannot be shown
//   identity   in a shared space the person is their account (a member):
//              records carry it as owner and as "changed by"; a viewer
//              cannot write; the personal workspace is as before
//   personal   whatever is shown, sync, export, restore, reminders and focus
//              stay with the personal workspace, and none of them reads,
//              changes or drops a shared space's rows
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'profile_harness.dart' show MemoryKeys;

class _Utc implements DeviceTime {
  @override
  Instant now() => Instant.now();
  @override
  String zone() => 'UTC';
}

class _Fixed implements DeviceTime {
  _Fixed(this.clock);
  final FixedClock clock;
  @override
  Instant now() => clock.now();
  @override
  String zone() => 'UTC';
}

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: '$r');
  return (r as CommandOk).entityId;
}

const me = 'acc-me';
const space = '30000000-0000-4000-8000-0000000000aa';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late ProfileStore store;
  late String profileId;
  late String personal;
  late DriftSpaceService spaces;
  late DriftTaskService tasks;
  late DriftTaskQueries taskQueries;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    store = ProfileStore(db);
    final p = await store.ensureFirstProfile();
    profileId = p.profileId.value;
    personal = p.activeWorkspaceId.value;
    // Signed in (as P04a's binding writes it).
    await (db.update(db.profiles)..where((x) => x.id.equals(profileId)))
        .write(const ProfilesCompanion(accountId: Value(me), accountProvider: Value('github')));
    spaces = DriftSpaceService(db, gw);
    tasks = DriftTaskService(db, gw);
    taskQueries = DriftTaskQueries(db);
  });
  tearDown(() => db.close());

  Future<void> joinSpace({String role = 'editor', String status = 'active'}) => store.cacheSpace(SpaceSnapshot(
        workspaceId: space,
        ownerAccountId: 'acc-owner',
        name: 'Family',
        members: [
          const SpaceMemberSnapshot(accountId: 'acc-owner', role: 'owner', displayName: 'Lan'),
          SpaceMemberSnapshot(accountId: me, role: role, status: status, displayName: 'Dien'),
        ],
      ));

  Future<List<String>> titles() async => [for (final t in await taskQueries.watchTasks().first) t.title]..sort();

  test('the spaces: personal first, then the shared ones; showing one is one audited command', () async {
    await joinSpace();
    final list = await spaces.spaces();
    expect([for (final s in list) (s.shared, s.name, s.role, s.isShown, s.members)],
        [(false, null, null, true, 0), (true, 'Family', SpaceRole.editor, false, 2)]);
    ok(await spaces.show(space));
    expect((await store.getActiveProfile())!.activeWorkspaceId.value, space);
    expect((await db.select(db.auditLog).get()).where((a) => a.action == 'ShowSpace'), hasLength(1));
    expect((await spaces.show(space)), isA<CommandFailure>(), reason: 'already shown');
    ok(await spaces.show(personal));
    expect((await spaces.spaces()).first.isShown, isTrue);
  });

  test('a space this account is not an active member of cannot be shown', () async {
    await joinSpace(status: 'pending');
    expect(await spaces.spaces(), hasLength(1), reason: 'waiting for approval: not listed');
    final r = await spaces.show(space);
    expect((r as CommandFailure).reason, contains('not a member'));
    expect((await spaces.show('no-such-space') as CommandFailure).reason, contains('no such space'));
  });

  test('every view shows only the space being shown (B1)', () async {
    await joinSpace();
    final lists = DriftOverviewService(db, gw);
    final listQueries = DriftOverviewQueries(db);
    final calendars = DriftCalendarService(db, gw);
    final goals = DriftGoalService(db, gw);
    final goalQueries = DriftGoalQueries(db, _Utc());

    ok(await tasks.create('Mine'));
    ok(await lists.createList('My list'));
    ok(await calendars.create('My calendar'));
    ok(await goals.create(kind: GoalKindInput.goal, title: 'My goal'));

    ok(await spaces.show(space));
    expect(await titles(), isEmpty);
    expect(await listQueries.watchLists().first, isEmpty);
    expect(await calendars.watchCalendars().first, isEmpty);
    expect(await goalQueries.watchGoals().first, isEmpty);
    ok(await tasks.create('Ours'));
    ok(await lists.createList('Shopping'));
    ok(await calendars.create('Family calendar'));
    ok(await goals.create(kind: GoalKindInput.goal, title: 'Holiday'));
    expect(await titles(), ['Ours']);
    expect([for (final l in await listQueries.watchLists().first) l.title], ['Shopping']);
    expect([for (final c in await calendars.watchCalendars().first) c.name], ['Family calendar']);
    expect([for (final g in await goalQueries.watchGoals().first) g.title], ['Holiday']);

    ok(await spaces.show(personal));
    expect(await titles(), ['Mine']);
    expect([for (final l in await listQueries.watchLists().first) l.title], ['My list']);
    expect([for (final g in await goalQueries.watchGoals().first) g.title], ['My goal']);
  });

  test('in a shared space the person is their account: owner and "changed by" (B10)', () async {
    await joinSpace();
    final mine = ok(await tasks.create('Mine'));
    ok(await spaces.show(space));
    final ours = ok(await tasks.create('Ours'));
    ok(await tasks.rename(ours, 'Ours, renamed'));
    final o = (await recordKindByName['task']!.readOne(db, ours))!;
    expect((o['workspaceId'], o['ownerId'], o['changedBy']), (space, me, me));
    final m = (await recordKindByName['task']!.readOne(db, mine))!;
    expect((m['workspaceId'], m['ownerId'], m['changedBy']), (personal, profileId, null),
        reason: 'the personal workspace is as before');
    final audit = (await db.select(db.auditLog).get()).where((a) => a.action == 'CreateTask').map((a) => a.actor);
    expect(audit, containsAll(['owner:$profileId', 'member:$me']));
  });

  test('a viewer reads the space and cannot change it (SHARE-002, on the device)', () async {
    await joinSpace(role: 'editor');
    ok(await spaces.show(space));
    final id = ok(await tasks.create('Ours'));
    await joinSpace(role: 'viewer');
    final r = await tasks.rename(id, 'Changed by a viewer');
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    expect(r.reason, contains('viewer'));
    expect(await titles(), ['Ours']);
    // Nor a profile acting as owner in a space (the owner is someone else).
    final asOwner = await gw.execute(
        Command(
            operationId: const Uuid().v7(),
            actor: ActorRef(ActorKind.owner, profileId),
            workspaceId: space,
            type: 'RenameTask',
            payload: {'op': 'rename', 'id': id, 'title': 'x'},
            issuedAt: Instant.now()),
        TaskCommandHandler());
    expect((asOwner as CommandFailure).kind, CommandFailureKind.unauthorized);
  });

  test('someone waiting for approval cannot write, even with a crafted command', () async {
    await joinSpace(status: 'pending');
    final r = await gw.execute(
        Command(
            operationId: const Uuid().v7(),
            actor: const ActorRef(ActorKind.member, me),
            workspaceId: space,
            type: 'CreateTask',
            payload: {'op': 'create', 'id': 'crafted', 'title': 'Sneaked in'},
            issuedAt: Instant.now()),
        TaskCommandHandler());
    expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
    expect(await recordKindByName['task']!.readOne(db, 'crafted'), isNull);
  });

  test('reminders and focus stay personal: a switch never drops one (B2)', () async {
    await joinSpace();
    final id = ok(await tasks.create('Call the bank'));
    final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
    ok(await DriftTaskScheduling(db, gw).setSchedule(
        id,
        TaskScheduleInput(
            start: SchedulePointInput.at(
                LocalDate(tomorrow.year, tomorrow.month, tomorrow.day), TimeOfDayValue(9, 0), 'UTC'))));
    ok(await DriftReminderService(db, gw).setReminders(ReminderSubject.task, id, [const RemindMinutesBefore(10)]));
    final planner = DriftReminderPlanner(db, _Utc());
    final before = await planner.plan();
    expect(before, hasLength(1));
    final focus = DriftFocusService(db, gw);
    ok(await focus.start(mode: FocusSessionMode.stopwatch));

    ok(await spaces.show(space));
    expect([for (final r in await planner.plan()) r.key], [for (final r in before) r.key],
        reason: 'the device keeps the personal reminders');
    expect(await DriftFocusQueries(db).watchActive().first, isNotNull, reason: 'the focus bar in every space');
    expect(await focus.recoverOnLaunch(), isA<FocusResumed>());
  });

  test('a personal habit\'s ended periods close while a shared space is shown (B2)', () async {
    await joinSpace();
    final clock = FixedClock(Instant(DateTime.utc(2026, 11, 11, 10)));
    final time = _Fixed(clock);
    final habits = DriftHabitService(db, gw, time, clock: clock, deviceId: 'pc');
    final walk = ok(await tasks.create('Walk'));
    ok(await DriftTaskScheduling(db, gw).setSchedule(walk,
        TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 11, 11)), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
    ok(await habits.setHabit(walk, isHabit: true));
    ok(await habits.setTarget(walk, const TargetInput(kind: TargetKind.atLeast, min: 5000, unit: 'steps')));
    ok(await habits.recordMeasurement(walk, 6000));
    ok(await spaces.show(space));
    clock.value = Instant(DateTime.utc(2026, 11, 13, 10)); // two days later
    expect(await habits.closePeriods(), greaterThan(0));
    final results = await (db.select(db.periodResults)..where((r) => r.taskId.equals(walk))).get();
    expect(results, isNotEmpty);
    expect(results.map((r) => r.workspaceId).toSet(), {personal}, reason: 'stored in the personal workspace');
  });

  test('export: the personal workspace only, also while a shared space is shown (B14)', () async {
    await joinSpace();
    ok(await tasks.create('Mine'));
    ok(await spaces.show(space));
    final ours = ok(await tasks.create('Ours, private to the family'));
    final text = await ProfileExport.build(db);
    expect(text, isNot(contains('Ours, private to the family')), reason: 'no content of the space');
    expect(text, isNot(contains(ours)), reason: 'no row, outbox, audit or event of the space\'s operations');
    final payload = (jsonDecode(text) as Map)['payload'] as Map;
    for (final key in ['workspaces', 'tasks', 'outbox', 'opDedupe']) {
      expect([for (final r in payload[key] as List) r], everyElement(isNot(containsPair(key == 'workspaces' ? 'id' : 'workspaceId', space))),
          reason: key);
    }
    // (Showing the space is a command of the personal workspace: its audit row
    // names the space's id, an opaque UUID that says nothing.)
    final parsed = ProfileExport.parse(text, currentSchemaVersion: db.schemaVersion);
    expect((parsed.workspaceId, parsed.taskCount), (personal, 1));
  });

  test('restore (overwrite) never touches a shared space', () async {
    await joinSpace();
    ok(await tasks.create('Mine'));
    final file = await ProfileExport.build(db);
    ok(await tasks.create('Mine, after the export'));
    ok(await spaces.show(space));
    final ours = ok(await tasks.create('Ours'));
    final profile = await (db.select(db.profiles)..where((x) => x.id.equals(profileId))).getSingle();
    ok(await gw.execute(
        Command(
            operationId: const Uuid().v7(),
            actor: ActorRef(ActorKind.owner, profileId),
            workspaceId: personal,
            type: 'RestoreProfile',
            payload: {'op': 'restore', 'id': profileId, 'text': file, 'mode': 'overwrite'},
            expectedVersion: Version(profile.version),
            issuedAt: Instant.now()),
        const ProfileRestoreHandler()));
    final o = (await recordKindByName['task']!.readOne(db, ours))!;
    expect((o['deletedAt'], o['workspaceId']), (null, space), reason: 'the space\'s task is not trashed');
    expect(await titles(), ['Ours'], reason: 'still shown');
    ok(await spaces.show(personal));
    expect(await titles(), ['Mine'], reason: 'the personal workspace as in the file');
  });

  test('personal sync: on and off while a space is shown, and a space\'s sync bookkeeping is left alone', () async {
    await joinSpace();
    // The space syncs on its own (T11): its state, a last synced copy, a
    // review item and a change waiting to be sent.
    await db.into(db.syncState).insert(SyncStateCompanion.insert(workspaceId: space, deviceId: 'dev-space'));
    await db.into(db.syncBase).insert(SyncBaseCompanion.insert(
        kind: 'task', recordId: 't-space', version: 1, data: '{}', workspaceId: const Value(space)));
    await db.into(db.syncReviews).insert(SyncReviewsCompanion.insert(
        id: 'r-space', workspaceId: space, kind: 'task', recordId: 't-space', field: 'notes', kept: '"a"', other: '"b"',
        reason: 'changedOnBoth', createdAt: DateTime.utc(2026)));
    await db.into(db.outbox).insert(OutboxCompanion.insert(
        operationId: 'op-space', entityId: 't-space', entityType: 'task', workspaceId: space, actorId: 'member:$me',
        operationType: 'update', payload: '{}', createdAt: DateTime.utc(2026)));

    ok(await spaces.show(space));
    final sync = DriftSyncService(
        db: db,
        gateway: gw,
        remote: MemoryRemoteGateway(MemoryRemoteServer(), accountId: me),
        keyring: WorkspaceKeyring(MemoryKeys().call));
    expect((await sync.status()).on, isFalse, reason: 'the personal workspace is not synced; the space\'s sync is not this');
    final offer = await sync.offerRecoveryKey();
    final (p1, p2) = offer.check;
    final on = await sync.startWithRecoveryKey((offer.words[p1 - 1], offer.words[p2 - 1]));
    expect(on.problem, isNull, reason: on.message);
    final personalState = await (db.select(db.syncState)..where((s) => s.workspaceId.equals(personal))).getSingle();
    expect(personalState.workspaceId, personal);
    expect((await sync.turnOff()).problem, isNull);

    expect(await (db.select(db.syncState)..where((s) => s.workspaceId.equals(space))).get(), hasLength(1));
    expect(await (db.select(db.syncBase)..where((b) => b.workspaceId.equals(space))).get(), hasLength(1));
    expect(await (db.select(db.syncReviews)..where((r) => r.workspaceId.equals(space))).get(), hasLength(1));
    expect((await (db.select(db.outbox)..where((o) => o.operationId.equals('op-space'))).getSingle()).status, 'pending',
        reason: 'the space\'s waiting change is still to be sent');
    expect((await store.getActiveProfile())!.activeWorkspaceId.value, space, reason: 'still shown');
  });

  test('upgrade v12 -> v13: the last synced copies belong to the workspace that was synced', () async {
    // What the v13 step fills in (app_database.dart), on this store's tables.
    await db.into(db.syncState).insert(SyncStateCompanion.insert(workspaceId: personal, deviceId: 'd'));
    await db.into(db.syncBase).insert(SyncBaseCompanion.insert(kind: 'task', recordId: 'x', version: 1, data: '{}'));
    await db.customStatement(
        'UPDATE sync_base SET workspace_id = COALESCE((SELECT workspace_id FROM sync_state LIMIT 1), '
        '(SELECT active_workspace_id FROM profiles LIMIT 1), \'\')');
    expect((await db.select(db.syncBase).getSingle()).workspaceId, personal);
    expect(jsonEncode((await recordKindByName['task']!.readAll(db))), isNotNull);
  });
}
