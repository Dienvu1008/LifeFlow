// P05a T5 (ADR-0070): the personal export after something was moved into a
// shared space. A P04b bug: the export left the moved records out (B14) but
// its reader refused a personal row that still pointed to one (a goal link
// to a moved goal, a reminder of a moved task), so the file could not be
// restored. Now the file names those ids (inSpaces); the reader accepts
// them and nothing else; a restore on this device keeps the rows; a new
// store leaves out or clears what points to them.
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const me = 'acc-me';
const space = '30000000-0000-4000-8000-0000000000aa';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late String personal;
  late DriftTaskService tasks;
  final open = <AppDatabase>[];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    final store = ProfileStore(db);
    final p = await store.ensureFirstProfile();
    personal = p.activeWorkspaceId.value;
    await (db.update(db.profiles)..where((x) => x.id.equals(p.profileId.value)))
        .write(const ProfilesCompanion(accountId: Value(me), accountProvider: Value('github')));
    await store.cacheSpace(const SpaceSnapshot(
        workspaceId: space, ownerAccountId: me, name: 'Family', members: [SpaceMemberSnapshot(accountId: me, role: 'owner')]));
    tasks = DriftTaskService(db, gw);
  });
  tearDown(() async {
    await db.close();
    for (final d in open) {
      await d.close();
    }
    open.clear();
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  var moves = 0;
  Future<void> moveIn(String kind, String id) async {
    final set = await moveSetOf(db, kind, id);
    expect(set.blocker, isNull);
    ok(await gw.execute(
        Command(
            operationId: 'op-move-${moves++}',
            actor: const ActorRef(ActorKind.member, me),
            workspaceId: space,
            type: 'MoveIntoSpace',
            payload: {'op': 'move', 'id': id, 'from': personal, 'expect': set.fingerprint},
            issuedAt: Instant.now()),
        SpaceMoveHandler(kind)));
  }

  ParsedExport read(String text) => ProfileExport.parse(text, currentSchemaVersion: AppDatabase.currentSchemaVersion);

  /// The file, read and written into a new, empty store (another device).
  Future<AppDatabase> intoNewStore(ParsedExport file) async {
    final fresh = AppDatabase(NativeDatabase.memory());
    open.add(fresh);
    await ProfileExport.writeInto(fresh, file);
    return fresh;
  }

  /// A restore of the file on this same device, as "the profile becomes the
  /// file": nothing to change, nothing moved to the trash.
  Future<void> sameDeviceUnchanged(ParsedExport file) async {
    final plan = RestorePlanner.plan(await RecordSet.ofDatabase(db), RecordSet.ofExport(file), const RestoreChoice.overwrite(),
        now: DateTime.now().toUtc(), actor: '');
    expect([for (final c in plan.changes) '${c.kind}:${c.id}'], isEmpty);
    expect(plan.conflictTitles, isEmpty);
  }

  test('the P04b bug: a goal with a link moved into a space; the personal export still restores', () async {
    final goals = DriftGoalService(db, gw);
    final g = ok(await goals.create(kind: GoalKindInput.goal, title: 'Save for a trip'));
    final t = ok(await tasks.create('Open a savings account'));
    ok(await goals.link(g, GoalItemType.task, t));
    await moveIn('goal', g);
    // The link left behind is not the space's to change (it was written to
    // the personal row with an outbox row of the space).
    ok(await DriftSpaceService(db, gw).show(space));
    final link = (await db.select(db.goalLinks).get()).single;
    expect(await goals.unlink(g, GoalItemType.task, t), isA<CommandFailure>());
    expect((await db.select(db.goalLinks).get()).single, link);
    ok(await DriftSpaceService(db, gw).show(personal));

    final text = await ProfileExport.build(db);
    final payload = (jsonDecode(text) as Map)['payload'] as Map;
    expect(payload[inSpacesKey], {
      'goal': [g]
    }, reason: 'only the id, which the link holds already');
    final file = read(text);
    expect(file.records['goalLink'], hasLength(1), reason: 'the link stays in the file');
    expect(file.records['goal'], isEmpty);
    await sameDeviceUnchanged(file);

    final fresh = await intoNewStore(file);
    expect(await fresh.select(fresh.goalLinks).get(), isEmpty, reason: 'its goal is not there');
    expect([for (final x in await fresh.select(fresh.tasks).get()) x.id], [t]);

    expect(() => read(ProfileExport.seal(Map.of(payload.cast<String, Object?>())..remove(inSpacesKey),
            schemaVersion: AppDatabase.currentSchemaVersion)),
        throwsA(isA<ExportRejected>()), reason: 'without the list the link is a dangling id, refused as before');
  });

  test('a task moved: its reminder, its focus session and a trashed subtask stay personal; the export restores', () async {
    final t = ok(await tasks.create('Trip to Hue'));
    final kept = ok(await tasks.create('Book tickets', parentId: t));
    final gone = ok(await tasks.create('Old plan', parentId: t));
    ok(await tasks.trash(gone));
    ok(await DriftTaskScheduling(db, gw).setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 1)))));
    ok(await DriftReminderService(db, gw).setReminders(ReminderSubject.task, t, [const RemindMinutesBefore(60)]));
    final session = ok(await DriftFocusService(db, gw).start(mode: FocusSessionMode.stopwatch, taskId: t));
    await moveIn('task', t);
    expect((await recordKindByName['task']!.readOne(db, kept))!['workspaceId'], space);
    expect((await recordKindByName['task']!.readOne(db, gone))!['workspaceId'], personal, reason: 'a trashed subtask stays');

    final text = await ProfileExport.build(db);
    final inSpaces = ((jsonDecode(text) as Map)['payload'] as Map)[inSpacesKey] as Map;
    expect(inSpaces, {
      'task': [t]
    });
    final file = read(text);
    await sameDeviceUnchanged(file);

    final fresh = await intoNewStore(file);
    expect(await fresh.select(fresh.reminders).get(), isEmpty, reason: 'its task is not there');
    final s = await recordKindByName['focusSession']!.readOne(fresh, session);
    expect((s!['taskId'], s['deletedAt']), (null, null), reason: 'the session is kept, without its task');
    final sub = (await recordKindByName['task']!.readOne(fresh, gone))!;
    expect((sub['parentTaskId'], sub['deletedAt'] != null), (null, true), reason: 'in the trash, at the top');
  });

  test('a document moved: a link to a personal task and a trashed subdocument stay; the export restores', () async {
    final docs = DriftDocumentService(db, gw, clock: const SystemClock(), deviceId: 'windows');
    final d = ok(await docs.create('Recipes'));
    final child = ok(await docs.create('Old notes', parentId: d));
    ok(await docs.trash(child));
    final t = ok(await tasks.create('Buy rice'));
    ok(await docs.link(d, DocumentItemType.task, t));
    await moveIn('document', d);

    final text = await ProfileExport.build(db);
    expect(((jsonDecode(text) as Map)['payload'] as Map)[inSpacesKey], {
      'document': [d]
    });
    final file = read(text);
    expect([for (final r in file.records['document']!) r['id']], [child]);
    await sameDeviceUnchanged(file);

    final fresh = await intoNewStore(file);
    expect(await fresh.select(fresh.documentLinks).get(), isEmpty);
    final c = (await recordKindByName['document']!.readOne(fresh, child))!;
    expect((c['parentId'], c['deletedAt'] != null), (null, true));
    expect([for (final r in await fresh.select(fresh.documentRevisions).get()) r.documentId], [child],
        reason: 'its own history comes with it');
  });

  test('each kind of pointer alone is named: a trashed subtask, a focus session, a trashed subdocument', () async {
    final a = ok(await tasks.create('A'));
    final aSub = ok(await tasks.create('A, old step', parentId: a));
    ok(await tasks.trash(aSub));
    final b = ok(await tasks.create('B'));
    ok(await DriftFocusService(db, gw).start(mode: FocusSessionMode.stopwatch, taskId: b));
    final docs = DriftDocumentService(db, gw);
    final c = ok(await docs.create('C'));
    ok(await docs.trash(ok(await docs.create('C, old', parentId: c))));
    final e = ok(await docs.create('E'));
    final f = ok(await docs.create('F', parentId: e));
    for (final (kind, id) in [('task', a), ('task', b), ('document', c), ('document', f)]) {
      await moveIn(kind, id);
    }
    expect((await recordKindByName['document']!.readOne(db, f))!['parentId'], isNull,
        reason: 'a subdocument moved alone leaves its parent behind');
    final text = await ProfileExport.build(db);
    final inSpaces = ((jsonDecode(text) as Map)['payload'] as Map)[inSpacesKey] as Map;
    expect(inSpaces, {
      'document': [c],
      'task': [a, b]..sort(),
    }, reason: 'E points to nothing in the space');
    expect(read(text), isA<ParsedExport>());
  });

  test('the list is checked: well-formed, known kinds, never an id that is in the file', () async {
    final t = ok(await tasks.create('Here'));
    final base = ((jsonDecode(await ProfileExport.build(db)) as Map)['payload'] as Map).cast<String, Object?>();
    expect(base.containsKey(inSpacesKey), isFalse, reason: 'nothing moved: the file is as before');
    void refused(Object? list, String why) => expect(
        () => read(ProfileExport.seal({...base, inSpacesKey: list}, schemaVersion: AppDatabase.currentSchemaVersion)),
        throwsA(isA<ExportRejected>()),
        reason: why);
    refused(['task'], 'not a map');
    refused({'task': 'x'}, 'not a list');
    refused({
      'task': [1]
    }, 'not ids');
    refused({
      'profile': ['x']
    }, 'not a kind a row points to');
    refused({
      'task': [t]
    }, 'in the file and in a space');
    expect(read(ProfileExport.seal({...base, inSpacesKey: <String, Object?>{}}, schemaVersion: AppDatabase.currentSchemaVersion)),
        isA<ParsedExport>());

    // Only what is in a space is named: a personal row pointing to nothing
    // (a damaged store) still gives a file that is refused, as before.
    ok(await DriftTaskScheduling(db, gw).setSchedule(t, TaskScheduleInput(start: SchedulePointInput.date(LocalDate(2026, 12, 1)))));
    ok(await DriftReminderService(db, gw).setReminders(ReminderSubject.task, t, [const RemindMinutesBefore(5)]));
    await db.customStatement("UPDATE reminders SET subject_id = 'nowhere'");
    final damaged = await ProfileExport.build(db);
    expect(((jsonDecode(damaged) as Map)['payload'] as Map).containsKey(inSpacesKey), isFalse);
    expect(() => read(damaged), throwsA(isA<ExportRejected>()));
  });
}
