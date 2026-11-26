// P06b W6 (ADR-0094): the Archive and the Trash of lists, tasks, events and
// documents.
//   archive    a list takes its tasks (with subtasks) and events away with
//              it, a task its subtasks, a document its subdocuments; one
//              moment for all of it, so unarchive brings back exactly that;
//              what was archived before stays archived
//   hidden     archived items are in no list, tree, search, agenda or
//              calendar (the agenda by a setting), and remind of nothing
//   restore    a task from the trash with what went with it; where its
//              parent or list is gone, at the top
//   purge      deleted for good: the content blanked on the row and in the
//              revisions, the schedule and the rest of what belonged to it
//              tombstoned, each in the outbox; only from the trash; what
//              went with it goes too; it cannot be restored
//   listing    the Archive and the Trash show top-level items with how many
//              went with them; the retention and "Empty trash"
//   files      an old export reads with nothing archived or deleted
import 'dart:convert';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:foundation/foundation.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

const zone = 'Asia/Ho_Chi_Minh';
final day = LocalDate(2026, 11, 5);

class _Time implements DeviceTime {
  _Time(this.at);
  Instant at;
  @override
  Instant now() => at;
  @override
  String zone() => 'Asia/Ho_Chi_Minh';
}

String ok(CommandResult r) {
  expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
  return (r as CommandOk).entityId;
}

SchedulePointInput at(LocalDate d, int h, int m) => SchedulePointInput.at(d, TimeOfDayValue(h, m), zone);

/// Times are kept to the second, and what went away together is told by its
/// moment: a step in time between what must be told apart.
Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 1100));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late DriftCommandGateway gw;
  late DriftTaskService tasks;
  late DriftTaskScheduling scheduling;
  late DriftEventService events;
  late DriftOverviewService lists;
  late DriftDocumentService docs;
  late DriftShelfService shelf;
  late _Time time;
  var showArchived = false;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    tasks = DriftTaskService(db, gw);
    scheduling = DriftTaskScheduling(db, gw);
    events = DriftEventService(db, gw);
    lists = DriftOverviewService(db, gw);
    docs = DriftDocumentService(db, gw, deviceId: 'w');
    shelf = DriftShelfService(db, gw);
    time = _Time(Instant(DateTime.utc(2026, 11, 4, 2)));
    showArchived = false;
  });
  tearDown(() => db.close());

  Future<ProfileStore> ready() async {
    final s = ProfileStore(db);
    await s.ensureFirstProfile();
    return s;
  }

  DriftCalendarQueries calendar() =>
      DriftCalendarQueries(db, DriftAgendaQueries(db, time, showArchived: () => showArchived));

  Future<List<String>> taskTitles() async => [for (final t in await DriftTaskQueries(db).watchTasks().first) t.title];
  Future<List<String>> listTitles() async => [for (final l in await DriftOverviewQueries(db).watchLists().first) l.title];
  Future<List<String>> eventTitles() async => [for (final e in await DriftOverviewQueries(db).watchEvents().first) e.title];
  Future<List<String>> docTitles() async => [for (final d in await DriftDocumentQueries(db).watchTree().first) d.title];
  Future<Map<String, Object?>> row(String kind, String id) async => (await recordKindByName[kind]!.readOne(db, id))!;

  setUp(() async => await ready());

  group('archive', () {
    test('a task takes its subtasks away and brings them back; one archived before stays archived', () async {
      final parent = ok(await tasks.create('Dọn nhà'));
      final a = ok(await tasks.create('Quét sân', parentId: parent));
      final b = ok(await tasks.create('Lau cửa', parentId: parent));
      ok(await shelf.archive(ShelfKind.task, b)); // on its own, first
      await tick();
      ok(await shelf.archive(ShelfKind.task, parent));
      expect(await taskTitles(), isEmpty);
      expect((await row('task', a))['archivedAt'], (await row('task', parent))['archivedAt'], reason: 'one moment');
      expect((await row('task', b))['archivedAt'], isNot((await row('task', parent))['archivedAt']));

      ok(await shelf.unarchive(ShelfKind.task, parent));
      expect(await taskTitles(), unorderedEquals(['Dọn nhà', 'Quét sân']), reason: 'what was archived before stays away');
      expect((await row('task', b))['archivedAt'], isNotNull);
      expect((await shelf.archive(ShelfKind.task, parent)), isA<CommandOk>());
    });

    test('a list takes its tasks, subtasks and events; unarchive brings back what went with it', () async {
      final l = ok(await lists.createList('Chuyển nhà'));
      final t = ok(await tasks.create('Đóng thùng', listId: l));
      ok(await tasks.create('Dán nhãn', parentId: t));
      final done = ok(await tasks.create('Thuê xe', listId: l));
      ok(await shelf.archive(ShelfKind.task, done));
      ok(await events.create(EventInput(title: 'Xe đến', start: at(day, 9, 0), end: at(day, 10, 0), listId: l)));
      final other = ok(await tasks.create('Việc khác'));
      await tick();

      ok(await shelf.archive(ShelfKind.list, l));
      expect(await listTitles(), isEmpty);
      expect(await taskTitles(), ['Việc khác']);
      expect(await eventTitles(), isEmpty);
      final entries = await shelf.archived();
      expect([for (final e in entries) (e.kind, e.title, e.contents)], [
        (ShelfKind.list, 'Chuyển nhà', 3), // two tasks, one event
        (ShelfKind.task, 'Thuê xe', 0),
      ], reason: 'what went with the list is not listed on its own');

      ok(await shelf.unarchive(ShelfKind.list, l));
      expect(await listTitles(), ['Chuyển nhà']);
      expect(await taskTitles(), unorderedEquals(['Việc khác', 'Đóng thùng', 'Dán nhãn']));
      expect(await eventTitles(), ['Xe đến']);
      expect((await row('task', done))['archivedAt'], isNotNull, reason: 'it was archived on its own');
      expect(other, isNotEmpty);
    });

    test('an event, and a document with its subdocuments', () async {
      final e = ok(await events.create(EventInput(title: 'Họp', start: at(day, 9, 0), end: at(day, 10, 0))));
      final d = ok(await docs.create('Kế hoạch'));
      final sub = ok(await docs.create('Chi tiết', parentId: d));
      ok(await shelf.archive(ShelfKind.event, e));
      await tick();
      ok(await shelf.archive(ShelfKind.document, d));
      expect(await eventTitles(), isEmpty);
      expect(await docTitles(), isEmpty);
      expect((await row('document', sub))['archivedAt'], isNotNull);
      expect([for (final x in await shelf.archived()) (x.kind, x.contents)], [(ShelfKind.document, 1), (ShelfKind.event, 0)]);
      ok(await shelf.unarchive(ShelfKind.document, d));
      expect(await docTitles(), unorderedEquals(['Kế hoạch', 'Chi tiết']));
    });

    test('refused: archiving twice, unarchiving what is not archived, archiving what is in the trash', () async {
      final t = ok(await tasks.create('Việc'));
      expect((await shelf.unarchive(ShelfKind.task, t)), isA<CommandFailure>());
      ok(await shelf.archive(ShelfKind.task, t));
      expect((await shelf.archive(ShelfKind.task, t)), isA<CommandFailure>());
      ok(await shelf.unarchive(ShelfKind.task, t));
      ok(await tasks.trash(t));
      expect((await shelf.archive(ShelfKind.task, t)), isA<CommandFailure>());
      expect((await shelf.archive(ShelfKind.task, 'nope')), isA<CommandFailure>());
    });

    test('an item unarchived while its list is still archived goes to no list', () async {
      final l = ok(await lists.createList('Dự án'));
      final t = ok(await tasks.create('Việc', listId: l));
      await tick();
      ok(await shelf.archive(ShelfKind.list, l));
      ok(await shelf.unarchive(ShelfKind.task, t)); // not what archived it: the list's moment differs? it is the same
      // The task was archived with the list at the same moment; unarchiving it
      // alone puts it where nothing holds it away.
      expect((await row('task', t))['taskListId'], isNull);
      expect(await taskTitles(), ['Việc']);
    });
  });

  group('hidden', () {
    test('search, the agenda and the calendar do not show archived items; the agenda by a setting', () async {
      final t = ok(await tasks.create('Nộp thuế tháng mười'));
      ok(await scheduling.setSchedule(t, TaskScheduleInput(start: at(day, 9, 0), end: at(day, 10, 0))));
      final e = ok(await events.create(EventInput(title: 'Họp thuế', start: at(day, 14, 0), end: at(day, 15, 0))));
      final d = ok(await docs.create('Hồ sơ thuế'));
      Future<List<String>> found() async {
        final r = await DriftSearchQueries(db).search('thuế');
        return [for (final x in r.tasks) x.title, for (final x in r.documents) x.title];
      }

      Future<List<String>> shown() async {
        final r = await calendar().range(day, day);
        return [for (final x in r.tasks) x.title, for (final x in r.events) x.title];
      }

      expect(await shown(), unorderedEquals(['Nộp thuế tháng mười', 'Họp thuế']));
      expect(await found(), unorderedEquals(['Nộp thuế tháng mười', 'Hồ sơ thuế']));
      ok(await shelf.archive(ShelfKind.task, t));
      ok(await shelf.archive(ShelfKind.event, e));
      ok(await shelf.archive(ShelfKind.document, d));
      expect(await shown(), isEmpty);
      expect(await found(), isEmpty);
      showArchived = true;
      expect(await shown(), unorderedEquals(['Nộp thuế tháng mười', 'Họp thuế']), reason: 'the setting shows them');
      expect(await found(), isEmpty, reason: 'search never does');
    });

    test('an archived task is not reminded', () async {
      final t = ok(await tasks.create('Uống thuốc'));
      ok(await scheduling.setSchedule(t, TaskScheduleInput(start: at(day, 9, 0), end: at(day, 9, 30))));
      ok(await DriftReminderService(db, gw).setReminders(ReminderSubject.task, t, [const RemindMinutesBefore(10)]));
      final planner = DriftReminderPlanner(db, time);
      Future<int> planned() async => (await planner.plan()).length;
      expect(await planned(), 1);
      ok(await shelf.archive(ShelfKind.task, t));
      expect(await planned(), 0);
      ok(await shelf.unarchive(ShelfKind.task, t));
      expect(await planned(), 1);
    });
  });

  group('restore', () {
    test('a task comes back from the trash with its subtasks; its parent gone, at the top', () async {
      final p = ok(await tasks.create('Mẹ'));
      final k = ok(await tasks.create('Con', parentId: p));
      ok(await tasks.trash(p, withSubtasks: true));
      expect(await taskTitles(), isEmpty);
      expect([for (final e in await shelf.trashed()) (e.kind, e.title, e.contents)], [(ShelfKind.task, 'Mẹ', 1)]);
      ok(await shelf.restore(ShelfKind.task, p));
      expect(await taskTitles(), unorderedEquals(['Mẹ', 'Con']));
      expect((await row('task', k))['parentTaskId'], p);
      expect((await shelf.restore(ShelfKind.task, p)), isA<CommandFailure>(), reason: 'not in the trash now');

      // A subtask trashed alone, then its parent too: it comes back at the top.
      ok(await tasks.trash(k));
      await tick();
      ok(await tasks.trash(p));
      ok(await shelf.restore(ShelfKind.task, k));
      expect((await row('task', k))['parentTaskId'], isNull);
      expect(await taskTitles(), ['Con']);
    });

    test('a list, an event and a document come back as their own commands bring them', () async {
      final l = ok(await lists.createList('Danh sách'));
      final t = ok(await tasks.create('Trong list', listId: l));
      final e = ok(await events.create(EventInput(title: 'Sự kiện', start: at(day, 9, 0), end: at(day, 10, 0))));
      final d = ok(await docs.create('Tài liệu'));
      ok(await lists.trashList(l));
      ok(await events.trash(e));
      ok(await docs.trash(d));
      expect([for (final x in await shelf.trashed()) x.kind], unorderedEquals([ShelfKind.list, ShelfKind.event, ShelfKind.document]));
      for (final (k, id) in [(ShelfKind.list, l), (ShelfKind.event, e), (ShelfKind.document, d)]) {
        ok(await shelf.restore(k, id));
      }
      expect(await listTitles(), ['Danh sách']);
      expect(await taskTitles(), ['Trong list']);
      expect(await eventTitles(), ['Sự kiện']);
      expect(await docTitles(), ['Tài liệu']);
      expect(t, isNotEmpty);
    });
  });

  group('delete for good', () {
    test('a task: the content is gone, its schedule and ticks too; each change is in the outbox; no restore', () async {
      final t = ok(await tasks.create('Đơn thuốc bí mật', ));
      ok(await tasks.setNotes(t, 'Bác sĩ dặn: uống sau ăn'));
      ok(await scheduling.setSchedule(t, TaskScheduleInput(start: at(day, 9, 0), end: at(day, 10, 0))));
      final kid = ok(await tasks.create('Việc con', parentId: t));
      expect((await shelf.purge(ShelfKind.task, t)), isA<CommandFailure>(), reason: 'only from the trash');
      ok(await tasks.trash(t, withSubtasks: true));
      await db.customStatement('DELETE FROM outbox');
      ok(await shelf.purge(ShelfKind.task, t));

      for (final id in [t, kid]) {
        final r = await row('task', id);
        expect((r['title'], r['notes'], r['tags']), ('', null, '[]'));
        expect(r['purgedAt'], isNotNull);
        expect(r['deletedAt'], isNotNull, reason: 'the tombstone stays (GS-14)');
      }
      final sched = await (db.select(db.schedules)..where((s) => s.subjectId.equals(t))).getSingle();
      expect(sched.deletedAt, isNotNull);
      final out = {for (final o in await db.select(db.outbox).get()) '${o.entityType}:${o.entityId}'};
      expect(out, containsAll(['task:$t', 'task:$kid', 'schedule:task:$t']));
      expect(await shelf.trashed(), isEmpty, reason: 'it is not in the trash any more');
      expect((await shelf.restore(ShelfKind.task, t)), isA<CommandFailure>());
      expect((await shelf.purge(ShelfKind.task, t)), isA<CommandFailure>(), reason: 'once');
      expect(jsonEncode(await db.select(db.tasks).get().then((r) => [for (final x in r) x.toJson()])), isNot(contains('bí mật')));
    });

    test('a document: its title and body, and every revision, are blanked; its links go', () async {
      final target = ok(await tasks.create('Việc liên quan'));
      final d = ok(await docs.create('Nhật ký riêng'));
      ok(await docs.save(d, title: 'Nhật ký riêng', body: DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun('Mật khẩu là hoa-sen-77')])])));
      ok(await docs.link(d, DocumentItemType.task, target));
      ok(await docs.trash(d));
      ok(await shelf.purge(ShelfKind.document, d));
      final all = jsonEncode([
        for (final r in await db.select(db.documents).get()) r.toJson(),
        for (final r in await db.select(db.documentRevisions).get()) r.toJson(),
      ]);
      expect(all, isNot(contains('hoa-sen')));
      expect(all, isNot(contains('Nhật ký riêng')));
      expect((await db.select(db.documentRevisions).get()).every((r) => r.deletedAt != null), isTrue);
      expect((await db.select(db.documentLinks).get()).every((r) => r.deletedAt != null), isTrue);
      expect((await DriftSearchQueries(db).search('hoa-sen')).isEmpty, isTrue);
      expect(await DriftDocumentQueries(db).trashed(), isEmpty);
      expect((await shelf.restore(ShelfKind.document, d)), isA<CommandFailure>());
    });

    test('a list takes the tasks and events that went to the trash with it; one trashed before is left', () async {
      final l = ok(await lists.createList('Cũ'));
      final before = ok(await tasks.create('Xóa trước', listId: l));
      ok(await tasks.trash(before));
      await tick();
      final t = ok(await tasks.create('Trong list', listId: l));
      final e = ok(await events.create(EventInput(title: 'Sự kiện', start: at(day, 9, 0), end: at(day, 10, 0), listId: l)));
      await tick();
      ok(await lists.trashList(l));
      ok(await shelf.purge(ShelfKind.list, l));
      expect((await row('task', t))['purgedAt'], isNotNull);
      expect((await row('event', e))['title'], '');
      expect((await row('task', before))['purgedAt'], isNull, reason: 'it was in the trash on its own');
      expect([for (final x in await shelf.trashed()) x.title], ['Xóa trước']);
      // What was deleted for good cannot come back as a blank ghost.
      expect(await shelf.restore(ShelfKind.list, l), isA<CommandFailure>());
      expect(await events.restore(e), isA<CommandFailure>());
      expect((await row('list' == 'x' ? 'task' : 'taskList', l))['title'], '');
      expect(await listTitles(), isEmpty);
      expect(await eventTitles(), isEmpty);
    });
  });

  group('the trash', () {
    test('listed top level, newest first, with where it was; the retention and "Empty trash"', () async {
      final l = ok(await lists.createList('Việc nhà'));
      final old = ok(await tasks.create('Cũ', listId: l));
      final fresh = ok(await tasks.create('Mới'));
      final e = ok(await events.create(EventInput(title: 'Họp', start: at(day, 9, 0), end: at(day, 10, 0))));
      ok(await tasks.trash(old));
      // "Old" went to the trash 40 days ago.
      final long = DateTime.now().toUtc().subtract(const Duration(days: 40));
      await (db.update(db.tasks)..where((t) => t.id.equals(old))).write(TasksCompanion(deletedAt: Value(long)));
      await tick();
      ok(await tasks.trash(fresh));
      await tick();
      ok(await events.trash(e));
      final listed = await shelf.trashed();
      expect([for (final x in listed) x.title], ['Họp', 'Mới', 'Cũ'], reason: 'newest first');
      expect(listed.last.place, 'Việc nhà');

      expect(await shelf.purgeOlderThan(0), 0, reason: 'zero keeps it');
      expect(await shelf.purgeOlderThan(30), 1);
      expect([for (final x in await shelf.trashed()) x.title], ['Họp', 'Mới']);
      expect(await shelf.purgeOlderThan(30), 0);
      expect(await shelf.emptyTrash(), 2);
      expect(await shelf.trashed(), isEmpty);
      expect(await tasks.create('Còn'), isA<CommandOk>());
    });
  });

  group('files', () {
    test('an export keeps what is archived and deleted for good; one of schema 18 reads with neither', () async {
      final t = ok(await tasks.create('Lưu trữ'));
      ok(await shelf.archive(ShelfKind.task, t));
      final text = await ProfileExport.build(db);
      final parsed = ProfileExport.parse(text, currentSchemaVersion: AppDatabase.currentSchemaVersion);
      expect((parsed.records['task']!.single)['archivedAt'], isNotNull);

      Map<String, Object?> payload() => ((jsonDecode(text) as Map)['payload'] as Map).cast<String, Object?>();
      final old = payload();
      for (final key in ['taskLists', 'tasks', 'events', 'documents']) {
        for (final r in (old[key] as List).cast<Map>()) {
          r
            ..remove('archivedAt')
            ..remove('purgedAt');
        }
      }
      final back = ProfileExport.parse(ProfileExport.seal(old, schemaVersion: 18),
          currentSchemaVersion: AppDatabase.currentSchemaVersion);
      final r = back.records['task']!.single;
      expect((r['archivedAt'], r['purgedAt']), (null, null));
    });
  });
}
