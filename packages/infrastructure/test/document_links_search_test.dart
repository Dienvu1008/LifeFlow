// P05a T6 (ADR-0071; p05-plan.md §4, C4, C6, C12): `[[…]]` links, backlinks
// and search on the real store.
//   targets     a link shows its target's current title, or broken: in the
//               trash, or not in the shown workspace (never its title);
//               restoring repairs it (DOC-003)
//   save        a link's text follows a rename at the next save; a broken
//               link keeps its text
//   backlinks   the live documents of the workspace linking here, with
//               their sentences
//   [[          documents by title, as search does; the latest changed with
//               nothing typed; never the document itself
//   search      documents with a passage and its matches, tasks by title;
//               by the exact spelling; the shown workspace only
//   items       the linked tasks, events and goals with their titles and
//               states; a task's documents
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
  late FixedClock clock;
  late DriftDocumentService docs;
  late DriftDocumentQueries queries;
  late DriftSearchQueries search;
  late DriftSpaceService spaces;
  late String personal;

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
    clock = FixedClock(Instant(DateTime.utc(2026, 11, 4, 9)));
    docs = DriftDocumentService(db, gw, clock: clock, deviceId: 'windows');
    queries = DriftDocumentQueries(db);
    search = DriftSearchQueries(db);
    spaces = DriftSpaceService(db, gw);
  });
  tearDown(() => db.close());

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  void later() => clock.value = Instant(clock.value.utc.add(const Duration(minutes: 1)));

  DocBlock para(String id, List<TextRun> runs) => DocBlock(id, BlockType.paragraph, runs: runs);

  Future<String> newDoc(String title, [List<TextRun> runs = const []]) async {
    final id = ok(await docs.create(title));
    if (runs.isNotEmpty) ok(await docs.save(id, title: title, body: DocumentBody([para('b1', runs)])));
    later();
    return id;
  }

  Future<String> inSpace(Future<String> Function() make) async {
    ok(await spaces.show(space));
    final id = await make();
    ok(await spaces.show(personal));
    return id;
  }

  Future<List<TextRun>> runsOf(String id) async => (await queries.document(id))!.body.blocks.first.runs;

  group('[[…]] links (DOC-003)', () {
    test('a link shows the current title, or broken: in the trash, gone, or in another workspace', () async {
      final a = await newDoc('Ghi chú họp');
      final b = await newDoc('Sách');
      final elsewhere = await inSpace(() => newDoc('Kế hoạch gia đình'));
      ok(await docs.rename(a, 'Ghi chú họp tuần'));
      ok(await docs.trash(b));
      final t = await queries.linkTargets([a, b, 'gone', elsewhere]);
      expect([for (final id in [a, b, 'gone', elsewhere]) (t[id]!.state, t[id]!.title)], [
        (LinkState.ok, 'Ghi chú họp tuần'),
        (LinkState.inTrash, 'Sách'),
        (LinkState.missing, null),
        (LinkState.missing, null),
      ], reason: 'a document of another workspace never shows its title here');
      ok(await docs.restore(b));
      expect((await queries.linkTargets([b]))[b]!.state, LinkState.ok, reason: 'restoring repairs the link');
      expect(await queries.linkTargets(const []), isEmpty);
    });

    test('at a save a link takes its target\'s current title; a broken link keeps its text; search follows', () async {
      final a = await newDoc('Họp');
      final b = await newDoc('Sách');
      final from = await newDoc('Nhật ký', [
        TextRun('Xem '),
        TextRun('Họp', doc: a, marks: {TextMark.bold}),
        TextRun(', '),
        TextRun('Sách', doc: b),
        TextRun(' và '),
        TextRun('Cũ', doc: 'gone'),
      ]);
      ok(await docs.rename(a, 'Họp tổ dân phố'));
      ok(await docs.rename(b, 'Sách cũ'));
      ok(await docs.trash(b));
      final before = (await queries.revisions(from)).length;
      final shown = (await queries.document(from))!;
      ok(await docs.save(from, title: shown.title, body: shown.body));
      expect([for (final r in await runsOf(from)) (r.text, r.doc)], [
        ('Xem ', null),
        ('Họp tổ dân phố', a),
        (', ', null),
        ('Sách', b),
        (' và ', null),
        ('Cũ', 'gone'),
      ]);
      expect((await runsOf(from))[1].marks, {TextMark.bold});
      expect((await queries.revisions(from)).length, before + 1, reason: 'the new text is a save');
      expect([for (final h in (await search.search('tổ dân phố')).documents) h.id], containsAll([a, from]));
      final again = (await queries.document(from))!;
      ok(await docs.save(from, title: again.title, body: again.body));
      expect((await queries.revisions(from)).length, before + 1, reason: 'nothing changed: no revision');
    });

    test('a link in a shared space to a personal document is not filled with its title', () async {
      final mine = await newDoc('Lương tháng này');
      final ours = await inSpace(() => newDoc('Đi chợ'));
      ok(await spaces.show(space));
      ok(await docs.save(ours, title: 'Đi chợ', body: DocumentBody([para('b1', [TextRun('xem', doc: mine)])])));
      expect([for (final r in await runsOf(ours)) r.text], ['xem']);
      expect((await queries.linkTargets([mine]))[mine]!.state, LinkState.missing);
    });
  });

  group('backlinks (C6)', () {
    test('the live documents of the workspace linking here, by title, with their sentences', () async {
      final target = await newDoc('Ghi chú họp');
      final b = await newDoc('Việc tuần', [TextRun('Đọc '), TextRun('Ghi chú họp', doc: target), TextRun(' trước. Xong.')]);
      final a = await newDoc('Bữa tối', [TextRun('Mang theo '), TextRun('Ghi chú họp', doc: target), TextRun('!')]);
      final c = await newDoc('cuối tuần', [TextRun('Ghi chú họp', doc: target)]);
      final trashed = await newDoc('Cũ', [TextRun('x', doc: target)]);
      ok(await docs.trash(trashed));
      await inSpace(() => newDoc('Ở không gian', [TextRun('x', doc: target)]));
      ok(await docs.save(target, title: 'Ghi chú họp', body: DocumentBody([para('b1', [TextRun('mình', doc: target)])])));
      final back = await queries.backlinks(target);
      expect([for (final x in back) (x.id, x.title)], [(a, 'Bữa tối'), (c, 'cuối tuần'), (b, 'Việc tuần')],
          reason: 'by title, letter case aside; not the trashed one, not one of another workspace, not itself');
      expect([for (final x in back) x.snippets], [
        ['Mang theo Ghi chú họp!'],
        ['Ghi chú họp'],
        ['Đọc Ghi chú họp trước.'],
      ]);
    });
  });

  group('[[ candidates (§4)', () {
    test('by title as search does; the latest changed with nothing typed; never itself; this workspace', () async {
      final hop = await newDoc('Ghi chú họp');
      final tuan = await newDoc('Ghi chú tuần');
      await newDoc('Khác', [TextRun('ghi chú trong thân bài')]);
      final self = await newDoc('Ghi chép');
      await inSpace(() => newDoc('Ghi chú gia đình'));
      final gone = await newDoc('Ghi chú cũ');
      ok(await docs.trash(gone));
      Future<List<String>> pick(String typed) async =>
          [for (final n in await queries.linkCandidates(typed, excludeId: self)) n.title]..sort();
      expect(await pick('ghi ch'), ['Ghi chú họp', 'Ghi chú tuần'], reason: 'titles only; the last word as a prefix');
      expect(await pick('GHI CHU\u0301'), ['Ghi chú họp', 'Ghi chú tuần'], reason: 'any case, marks typed apart');
      expect(await pick('ghi chu '), isEmpty, reason: 'by the exact spelling');
      expect(await pick('"chú họp"'), ['Ghi chú họp']);
      expect([for (final n in await queries.linkCandidates('', excludeId: self)) n.title], ['Khác', 'Ghi chú tuần', 'Ghi chú họp'],
          reason: 'the latest changed first');
      expect([for (final n in await queries.linkCandidates('ghi')) n.id], containsAll([hop, tuan, self]));
    });
  });

  group('search (C4, C12)', () {
    test('documents with a passage and its matches, tasks by title; the shown workspace only', () async {
      final tasks = DriftTaskService(db, gw);
      final d = await newDoc('Công thức', [TextRun('Phở bò: nấu nước dùng 6 giờ, thêm ghi chú về hành.')]);
      final titled = await newDoc('Ghi chú họp');
      ok(await docs.trash(await newDoc('Ghi chú cũ')));
      final t1 = ok(await tasks.create('Viết ghi chú'));
      final t2 = ok(await tasks.create('Đọc ghi chú cũ'));
      ok(await tasks.complete(t2, withDescendants: false));
      await inSpace(() async {
        ok(await tasks.create('Ghi chú chung'));
        return newDoc('Ghi chú chung');
      });

      final r = await search.search('ghi chú');
      expect({for (final h in r.documents) h.id}, {d, titled});
      final hit = r.documents.singleWhere((h) => h.id == d);
      expect(hit.title, 'Công thức');
      expect(hit.passage, contains('thêm ghi chú về hành'));
      expect([for (final m in hit.matches) hit.passage.substring(m.start, m.end)], ['ghi', 'chú']);
      expect({for (final t in r.tasks) (t.id, t.isDone)}, {(t1, false), (t2, true)});

      expect((await search.search('ghi chu ')).isEmpty, isTrue, reason: 'by the exact spelling');
      expect((await search.search('  ')).isEmpty, isTrue);
      expect([for (final h in (await search.search('nước dùng')).documents) h.id], [d]);
      expect((await search.search('ghi', limit: 1)).documents, hasLength(1));
      ok(await spaces.show(space));
      expect([for (final t in (await search.search('ghi chú')).tasks) t.title], ['Ghi chú chung']);
    });
  });

  group('links to tasks, events and goals', () {
    test('shown with their titles and states; an item\'s documents', () async {
      final tasks = DriftTaskService(db, gw);
      final goals = DriftGoalService(db, gw);
      final d = await newDoc('Kế hoạch');
      final other = await newDoc('Ghi chép khác');
      final done = ok(await tasks.create('Đặt vé'));
      ok(await tasks.complete(done, withDescendants: false));
      final trashed = ok(await tasks.create('Bỏ'));
      final g = ok(await goals.create(kind: GoalKindInput.goal, title: 'Du lịch Huế'));
      for (final (type, id) in [(DocumentItemType.task, done), (DocumentItemType.task, trashed), (DocumentItemType.goal, g)]) {
        ok(await docs.link(d, type, id));
        later();
      }
      ok(await docs.link(other, DocumentItemType.task, done));
      ok(await tasks.trash(trashed));
      expect([for (final l in await queries.linksOf(d)) (l.itemType, l.title, l.state)], [
        (DocumentItemType.task, 'Đặt vé', LinkedItemState.done),
        (DocumentItemType.task, 'Bỏ', LinkedItemState.trashed),
        (DocumentItemType.goal, 'Du lịch Huế', LinkedItemState.open),
      ]);
      expect([for (final n in await queries.documentsOf(DocumentItemType.task, done)) n.title], ['Ghi chép khác', 'Kế hoạch']);
      ok(await docs.trash(other));
      expect([for (final n in await queries.documentsOf(DocumentItemType.task, done)) n.title], ['Kế hoạch']);
      ok(await spaces.show(space));
      expect(await queries.documentsOf(DocumentItemType.task, done), isEmpty);
    });
  });
}
