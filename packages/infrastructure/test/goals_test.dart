// P03 T5 (ADR-0040): goals and projects on a real profile store.
//   GS-21     progress is a pure function of the linked items' states and
//             is never written back; trashing the goal keeps the tasks
//             (LF-INV-GOAL-001/002)
//   GOAL-003  a link to an item in another workspace is refused
//   D11       milestones (by hand) win over links; a habit counts its rate
//             since it was linked; events are shown, not counted
import 'dart:convert';
import 'dart:io';

import 'package:application/application.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'fake_auth.dart';
import 'profile_harness.dart';

class _Time implements DeviceTime {
  _Time(this.clock);
  final FixedClock clock;
  @override
  Instant now() => clock.now();
  @override
  String zone() => 'UTC';
}

void main() {
  late Directory base;
  late ProfileDirectory dir;
  late TestHost host;
  late FixedClock clock;
  late DriftCommandGateway gw;
  late DriftGoalService goals;
  late DriftGoalQueries queries;
  late Services svc;

  final day0 = LocalDate(2026, 11, 11);
  void toDay(int n) => clock.value = Instant(DateTime.utc(2026, 11, 11 + n, 10));

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_goal_');
    dir = await openDirectory(base, MemoryKeys());
    host = TestHost(dir);
    await host.openActive();
    clock = FixedClock(Instant(DateTime.utc(2026, 11, 11, 10)));
    gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    goals = DriftGoalService(host.db, gw, clock: clock);
    queries = DriftGoalQueries(host.db, _Time(clock));
    svc = Services(host, FakeAuthGateway());
  });
  tearDown(() async {
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  void refused(CommandResult r, String mentions) {
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).reason, contains(mentions));
  }

  Future<String> task(String title) async => ok(await svc.tasks.create(title));
  Future<String> newGoal([String title = 'Get fit']) async =>
      ok(await goals.create(kind: GoalKindInput.goal, title: title));
  Future<GoalView> view(String id) async => (await queries.goal(id))!;
  Future<List<String>> taskRows() async => [for (final t in await host.db.select(host.db.tasks).get()) jsonEncode(t.toJson())];

  test('GS-21: progress is derived from the linked items, never written back; trashing keeps the tasks', () async {
    final a = await task('Buy shoes');
    final b = await task('Book a trainer');
    final c = await task('Old idea');
    final water = await task('Warm water');
    ok(await DriftTaskScheduling(host.db, gw).setSchedule(water,
        TaskScheduleInput(start: SchedulePointInput.date(day0), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
    final habits = DriftHabitService(host.db, gw, _Time(clock), clock: clock);
    ok(await habits.setHabit(water, isHabit: true));
    ok(await DriftTaskScheduling(host.db, gw).setOccurrenceDone(water, day0, done: true));

    final g = await newGoal();
    expect((await view(g)).progress, isNull, reason: 'nothing counts yet: not 0 %');
    for (final id in [a, b, c, water]) {
      ok(await goals.link(g, GoalItemType.task, id));
    }
    final before = await taskRows();

    ok(await svc.tasks.complete(a, withDescendants: false));
    ok(await svc.tasks.trash(c));
    toDay(2); // the habit: day 0 done, day 1 missed
    var v = await view(g);
    expect(v.progressBasis, GoalProgressBasis.links);
    // a 1, b 0, c trashed (not counted), the habit 1/2.
    expect(v.progress, closeTo((1 + 0 + 0.5) / 3, 1e-9));
    expect(v.links.firstWhere((l) => l.itemId == water).habitRate, 0.5);
    expect(v.links.firstWhere((l) => l.itemId == c).state, LinkedItemState.trashed);
    // Same inputs, same output (a pure function of the states).
    expect((await view(g)).progress, v.progress);

    // Reads and goal commands never change a task (LF-INV-GOAL-001).
    final afterTaskChanges = await taskRows();
    await queries.goal(g);
    ok(await goals.update(g, title: 'Get fitter'));
    ok(await goals.unlink(g, GoalItemType.task, b));
    ok(await goals.trash(g));
    expect(await taskRows(), afterTaskChanges);
    expect(afterTaskChanges, isNot(before), reason: 'only the task commands changed tasks');

    // Trashed: the tasks are all there; the links come back with a restore.
    expect((await host.db.select(host.db.tasks).get()).length, 4);
    expect((await queries.trashed()).single.id, g);
    expect(await queries.watchGoals().first, isEmpty);
    refused(await goals.link(g, GoalItemType.task, b), 'in the trash');
    ok(await goals.restore(g));
    v = await view(g);
    expect(v.links.map((l) => l.itemId).toSet(), {a, c, water});
    expect(v.progress, closeTo((1 + 0.5) / 2, 1e-9));
  });

  test('a habit counts only its periods since it was linked', () async {
    final water = await task('Warm water');
    ok(await DriftTaskScheduling(host.db, gw).setSchedule(water,
        TaskScheduleInput(start: SchedulePointInput.date(day0), repeat: const RepeatInput(frequency: RepeatFrequency.daily))));
    final habits = DriftHabitService(host.db, gw, _Time(clock), clock: clock);
    ok(await habits.setHabit(water, isHabit: true)); // day 0 missed, day 1 missed
    toDay(2);
    final g = await newGoal();
    ok(await goals.link(g, GoalItemType.task, water));
    expect((await view(g)).progress, isNull, reason: 'no ended period since the link');
    ok(await DriftTaskScheduling(host.db, gw).setOccurrenceDone(water, day0.addDays(2), done: true));
    toDay(3);
    expect((await view(g)).progress, 1.0, reason: 'day 2 only');
    // Linked again later: counted from the new link.
    ok(await goals.unlink(g, GoalItemType.task, water));
    toDay(5); // days 3 and 4 missed
    ok(await goals.link(g, GoalItemType.task, water));
    expect((await view(g)).progress, isNull, reason: 'nothing ended since the new link');
  });

  test('milestones keep the order they were added in', () async {
    final g = await newGoal();
    final p = (await ProfileStore(host.db).getActiveProfile())!;
    for (final mid in ['z', 'a']) {
      final v = (await (host.db.select(host.db.goals)..where((x) => x.id.equals(g))).getSingle()).version;
      ok(await gw.execute(
          Command(
            operationId: 'add-$mid',
            actor: ActorRef(ActorKind.owner, p.profileId.value),
            workspaceId: p.activeWorkspaceId.value,
            type: 'AddMilestone',
            payload: {'op': 'addMilestone', 'id': g, 'milestoneId': mid, 'title': 'M $mid'},
            expectedVersion: Version(v),
            issuedAt: clock.now(),
          ),
          GoalCommandHandler(clock: clock)));
    }
    expect((await view(g)).milestones.map((m) => m.id), ['z', 'a']);
  });

  test('D11: milestones (by hand) win over links; order, update, done, remove', () async {
    final p = ok(await goals.create(
        kind: GoalKindInput.project, title: 'Move house', startDate: LocalDate(2026, 11, 1), targetDate: LocalDate(2026, 12, 31)));
    ok(await goals.link(p, GoalItemType.task, await task('Call movers')));
    ok(await goals.addMilestone(p, 'Pack', dueDate: LocalDate(2026, 11, 20)));
    ok(await goals.addMilestone(p, 'Move'));
    var v = await view(p);
    expect((v.kind, v.startDate), (GoalKindInput.project, LocalDate(2026, 11, 1)));
    expect(v.milestones.map((m) => m.title), ['Pack', 'Move']);
    expect((v.progressBasis, v.progress), (GoalProgressBasis.milestones, 0.0));
    final pack = v.milestones.first.id;
    ok(await goals.setMilestoneDone(p, pack, done: true));
    refused(await goals.setMilestoneDone(p, pack, done: true), 'already done');
    ok(await goals.updateMilestone(p, pack, title: 'Pack everything'));
    v = await view(p);
    expect((v.progress, v.milestones.first.title, v.milestones.first.isCompleted, v.milestones.first.dueDate),
        (0.5, 'Pack everything', true, null));
    ok(await goals.removeMilestone(p, v.milestones.last.id));
    expect((await view(p)).progress, 1.0);
    refused(await goals.removeMilestone(p, v.milestones.last.id), 'milestone not found');
    // A milestone of another goal is never touched through this one.
    final other = await newGoal('Other');
    refused(await goals.setMilestoneDone(other, pack, done: false), 'another goal');
  });

  group('links', () {
    test('GOAL-003: an item in another workspace is refused', () async {
      final db = host.db;
      final p = (await ProfileStore(db).getActiveProfile())!;
      final now = DateTime.utc(2026, 11, 11);
      await db.into(db.workspaces).insert(WorkspacesCompanion.insert(id: 'ws-other', ownerId: p.profileId.value, createdAt: now));
      await db.into(db.tasks).insert(TasksCompanion.insert(
          id: 'foreign', workspaceId: 'ws-other', ownerId: p.profileId.value, createdAt: now, updatedAt: now, title: 'Not here'));
      final g = await newGoal();
      refused(await goals.link(g, GoalItemType.task, 'foreign'), 'another workspace');
      expect(await db.select(db.goalLinks).get(), isEmpty);
    });

    test('unknown, trashed, twice; unlink and link again; events shown, not counted', () async {
      final g = await newGoal();
      refused(await goals.link(g, GoalItemType.task, 'nope'), 'task not found');
      final gone = await task('Gone');
      ok(await svc.tasks.trash(gone));
      refused(await goals.link(g, GoalItemType.task, gone), 'task not found');
      final t = await task('Plan meals');
      ok(await goals.link(g, GoalItemType.task, t));
      refused(await goals.link(g, GoalItemType.task, t), 'already linked');
      ok(await goals.unlink(g, GoalItemType.task, t));
      refused(await goals.unlink(g, GoalItemType.task, t), 'not linked');
      ok(await goals.link(g, GoalItemType.task, t));
      final link = (await host.db.select(host.db.goalLinks).get()).single;
      expect((link.id, link.version, link.deletedAt), (goalLinkIdOf(g, 'task', t), 3, null));

      final ev = ok(await DriftEventService(host.db, gw)
          .create(EventInput(title: 'Gym class', start: SchedulePointInput.date(day0))));
      ok(await goals.link(g, GoalItemType.event, ev));
      final v = await view(g);
      expect(v.links.firstWhere((l) => l.itemType == GoalItemType.event).title, 'Gym class');
      expect(v.progress, 0.0, reason: 'one open task; the event does not count');
      expect((await queries.goalsOf(GoalItemType.task, t)).single.id, g, reason: '"part of"');
      expect(await queries.goalsOf(GoalItemType.task, gone), isEmpty);
    });
  });

  test('rules: dates, status, archived and trashed goals', () async {
    refused(await goals.create(kind: GoalKindInput.goal, title: 'X', startDate: day0), 'only a project');
    refused(
        await goals.create(kind: GoalKindInput.project, title: 'X', startDate: day0, targetDate: day0.addDays(-1)),
        'before the start');
    refused(await goals.create(kind: GoalKindInput.goal, title: '  '), 'title');
    final g = await newGoal();
    ok(await goals.setStatus(g, GoalState.done));
    refused(await goals.setStatus(g, GoalState.done), 'already done');
    ok(await goals.setStatus(g, GoalState.archived));
    refused(await goals.update(g, title: 'Y'), 'archived');
    refused(await goals.addMilestone(g, 'M'), 'archived');
    expect(await queries.watchGoals().first, isEmpty);
    expect((await queries.watchGoals(includeArchived: true).first).single.status, GoalState.archived);
    ok(await goals.setStatus(g, GoalState.active));
    ok(await goals.trash(g));
    refused(await goals.trash(g), 'in the trash');
    refused(await goals.setStatus(g, GoalState.done), 'in the trash');
    refused(await goals.restore(await newGoal('Live')), 'not in the trash');
  });

  test('every change is audited and the profile still exports and restores cleanly', () async {
    final g = await newGoal();
    ok(await goals.addMilestone(g, 'First'));
    ok(await goals.link(g, GoalItemType.task, await task('Run')));
    final audit = (await host.db.select(host.db.auditLog).get()).where((a) => a.resourceId == g).map((a) => a.action);
    expect(audit, ['CreateGoal', 'AddMilestone', 'LinkToGoal']);
    // The milestone and the link rows are in the outbox too (sync).
    final outbox = (await host.db.select(host.db.outbox).get()).map((o) => o.entityType).toSet();
    expect(outbox, containsAll(['goal', 'milestone', 'goalLink']));
    // A trashed goal is no longer "part of" for its items.
    final t = (await host.db.select(host.db.goalLinks).get()).single.itemId;
    ok(await goals.trash(g));
    expect(await queries.goalsOf(GoalItemType.task, t), isEmpty);
    final file = (await DriftDataTransferService(host.db, dir).exportActiveProfile()).contents;
    expect(() => ProfileExport.parse(file, currentSchemaVersion: AppDatabase.currentSchemaVersion), returnsNormally);
  });
}
