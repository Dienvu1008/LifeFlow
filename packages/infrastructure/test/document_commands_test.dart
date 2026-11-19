// P05a T3 (ADR-0068): the document commands on the real store.
//   create    the first revision comes with it; at the end of its siblings
//   save      one revision per save, the whole title and body (C5); nothing
//             written when nothing changed (C7); the body stored in its fixed
//             form; a bad body or a stale version refused
//   history   revisions are written once and never changed (DOC-002/006);
//             an earlier one restored as a new revision
//   tree      DOC-001 on the store; positions; the trash takes subdocuments
//             and brings back exactly those; a restore without its parent
//             goes to the top
//   links     to a live task, event or goal of the same workspace (DOC-004)
//   space     a member's save is "changed by" them; a viewer saves nothing
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
  late ProfileStore store;
  late FixedClock clock;
  late DriftDocumentService docs;
  late DriftDocumentQueries queries;
  late String personal;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
    store = ProfileStore(db);
    final p = await store.ensureFirstProfile();
    personal = p.activeWorkspaceId.value;
    await (db.update(db.profiles)..where((x) => x.id.equals(p.profileId.value)))
        .write(const ProfilesCompanion(accountId: Value(me), accountProvider: Value('github')));
    clock = FixedClock(Instant(DateTime.utc(2026, 11, 4, 9)));
    docs = DriftDocumentService(db, gw, clock: clock, deviceId: 'windows');
    queries = DriftDocumentQueries(db);
  });
  tearDown(() => db.close());

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: r is CommandFailure ? '${r.kind}: ${r.reason}' : '$r');
    return (r as CommandOk).entityId;
  }

  void refused(CommandResult r, String mentions) {
    expect(r, isA<CommandFailure>());
    expect((r as CommandFailure).reason, contains(mentions));
  }

  void later() => clock.value = Instant(clock.value.utc.add(const Duration(minutes: 1)));

  DocumentBody text(String s) => DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun(s)])]);

  Future<List<String>> revisionRows() async =>
      [for (final r in await db.select(db.documentRevisions).get()) jsonEncode(r.toJson())]..sort();

  Future<String> newDoc(String title, {String? parentId, String? afterId}) async =>
      ok(await docs.create(title, parentId: parentId, afterId: afterId));

  group('create and save', () {
    test('a new document is empty and has its first revision', () async {
      final id = await newDoc('Ghi chú họp');
      final v = (await queries.document(id))!;
      expect((v.title, v.version, v.body.blocks.single.type, v.body.blocks.single.text), ('Ghi chú họp', 1, BlockType.paragraph, ''));
      final h = await queries.revisions(id);
      expect([for (final r in h) (r.documentVersion, r.reason, r.title, r.deviceId)], [(1, RevisionReason.save, 'Ghi chú họp', null)]);
      refused(await docs.create('   '), 'title');
    });

    test('every save is one revision with the whole title and body (C5); nothing changed, nothing written (C7)', () async {
      final id = await newDoc('Kế hoạch');
      later();
      ok(await docs.save(id, title: 'Kế hoạch', body: text('Bước một')));
      later();
      ok(await docs.save(id, title: 'Kế hoạch 2027', body: text('Bước một, bước hai')));
      final before = await revisionRows();
      final same = await docs.save(id, title: 'Kế hoạch 2027 ', body: text('Bước một, bước hai'));
      expect((same as CommandOk).newVersion, Version(3));
      expect(await revisionRows(), before, reason: 'leaving an unchanged document is no revision');
      final h = await queries.revisions(id);
      expect([for (final r in h) r.documentVersion], [3, 2, 1], reason: 'newest first');
      expect(h.first.deviceId, 'windows');
      final (title, body) = (await queries.revisionContent(h[1].id))!;
      expect((title, body.plainText()), ('Kế hoạch', 'Bước một'));
      final outbox = await db.select(db.outbox).get();
      expect(outbox.where((o) => o.entityType == 'documentRevision'), hasLength(3), reason: 'each revision syncs');
    });

    test('the body is stored in its fixed form; a bad body is refused; a stale save is a conflict', () async {
      final id = await newDoc('X');
      final b = DocumentBody([DocBlock('b1', BlockType.paragraph, runs: [TextRun('a'), TextRun('b')])]);
      ok(await docs.save(id, title: 'X', body: b));
      expect((await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle()).body, b.encode());
      refused(await docs.save(id, title: 'X', body: DocumentBody([])), 'at least one block');
      final cmd = Command(
          operationId: 'op-bad',
          actor: ActorRef(ActorKind.owner, (await store.getActiveProfile())!.profileId.value),
          workspaceId: personal,
          type: 'SaveDocument',
          payload: {'op': 'save', 'id': id, 'revisionId': 'r-bad', 'title': 'X', 'body': '{"v":1,"blocks":[{"id":"x"}]}'},
          expectedVersion: const Version(2),
          issuedAt: clock.now());
      refused(await gw.execute(cmd, const DocumentCommandHandler()), 'cannot be read');
      final stale = await gw.execute(
          Command(
              operationId: 'op-stale',
              actor: cmd.actor,
              workspaceId: personal,
              type: 'SaveDocument',
              payload: {'op': 'save', 'id': id, 'revisionId': 'r-stale', 'title': 'Y', 'body': b.encode()},
              expectedVersion: const Version(1),
              issuedAt: clock.now()),
          const DocumentCommandHandler());
      expect((stale as CommandFailure).kind, CommandFailureKind.versionConflict);
    });

    test('a rename is a save: a revision with the current body', () async {
      final id = await newDoc('Cũ');
      ok(await docs.save(id, title: 'Cũ', body: text('nội dung')));
      ok(await docs.rename(id, 'Mới'));
      final h = await queries.revisions(id);
      expect(h.first.title, 'Mới');
      expect((await queries.revisionContent(h.first.id))!.$2.plainText(), 'nội dung');
    });
  });

  group('history', () {
    test('DOC-002/006: revisions are written once; nothing after changes them', () async {
      final id = await newDoc('Nhật ký');
      ok(await docs.save(id, title: 'Nhật ký', body: text('Thứ Hai')));
      final kept = await revisionRows();
      final child = await newDoc('Con', parentId: id);
      ok(await docs.save(id, title: 'Nhật ký', body: text('Thứ Ba')));
      ok(await docs.move(child, parentId: null));
      ok(await docs.trash(id));
      ok(await docs.restore(id));
      final now = await revisionRows();
      for (final r in kept) {
        expect(now, contains(r), reason: 'an earlier revision is as it was');
      }
      expect(now.length, kept.length + 2, reason: 'the child\'s first revision and one save; moves and the trash write none');
    });

    test('an earlier revision restored is a new revision; restoring what is shown is refused', () async {
      final id = await newDoc('Bản nháp');
      ok(await docs.save(id, title: 'Bản nháp', body: text('Lần một')));
      final first = (await queries.revisions(id)).first.id;
      ok(await docs.save(id, title: 'Bản nháp', body: text('Lần hai')));
      ok(await docs.restoreRevision(id, first));
      final v = (await queries.document(id))!;
      expect(v.body.plainText(), 'Lần một');
      final h = await queries.revisions(id);
      expect((h.first.reason, h.length), (RevisionReason.restore, 4));
      refused(await docs.restoreRevision(id, first), 'already');
      refused(await docs.restoreRevision(id, 'nope'), 'revision not found');
      final other = await newDoc('Khác');
      refused(await docs.restoreRevision(other, first), 'revision not found');
    });
  });

  group('the tree', () {
    test('DOC-001: never under itself or a subdocument; positions among siblings', () async {
      final a = await newDoc('A');
      final b = await newDoc('B', parentId: a);
      final c = await newDoc('C', parentId: b);
      refused(await docs.move(a, parentId: c), 'under itself');
      refused(await docs.move(a, parentId: a), 'under itself');
      final d = await newDoc('D');
      final e = await newDoc('E');
      expect([for (final n in await queries.watchTree().first) n.title], ['A', 'B', 'C', 'D', 'E'],
          reason: 'a new document goes at the end of its siblings');
      final first = await newDoc('First', afterId: d);
      expect([for (final n in await queries.watchTree().first) n.title], ['A', 'B', 'C', 'D', 'First', 'E']);
      ok(await docs.move(d, afterId: e));
      ok(await docs.move(c, parentId: null, afterId: null));
      expect([for (final n in await queries.watchTree().first) (n.title, n.parentId)],
          [('C', null), ('A', null), ('B', a), ('First', null), ('E', null), ('D', null)]);
      expect(first, isNotEmpty);
      refused(await docs.move(b, parentId: 'nowhere'), 'not here');
      refused(await newDocResult(docs, 'F', parentId: 'nowhere'), 'not here');
    });

    test('the trash takes the subdocuments, and a restore brings back exactly those', () async {
      final a = await newDoc('A');
      final b = await newDoc('B', parentId: a);
      final c = await newDoc('C', parentId: b);
      final alone = await newDoc('Alone', parentId: a);
      ok(await docs.trash(alone));
      later();
      ok(await docs.trash(a));
      expect(await queries.watchTree().first, isEmpty);
      expect([for (final n in await queries.trashed()) n.title], ['A', 'Alone'], reason: 'each as it was trashed');
      refused(await docs.save(b, title: 'B', body: text('x')), 'in the trash');
      ok(await docs.restore(a));
      expect([for (final n in await queries.watchTree().first) n.id], [a, b, c]);
      expect((await queries.document(alone))!.isTrashed, isTrue, reason: 'trashed on its own: stays in the trash');
      ok(await docs.restore(alone));
      expect((await queries.document(alone))!.parentId, a);
    });

    test('a restore whose parent is in the trash goes to the top', () async {
      final a = await newDoc('A');
      final b = await newDoc('B', parentId: a);
      ok(await docs.trash(b));
      later();
      ok(await docs.trash(a));
      ok(await docs.restore(b));
      expect((await queries.document(b))!.parentId, isNull);
      refused(await newDocResult(docs, 'C', parentId: a), 'in the trash');
    });
  });

  group('links (DOC-004)', () {
    test('to a live task, event or goal of the same workspace; unlink and link again', () async {
      final id = await newDoc('Dự án');
      final task = ok(await DriftTaskService(db, gw).create('Gọi điện'));
      final goal = ok(await DriftGoalService(db, gw).create(kind: GoalKindInput.goal, title: 'Khoẻ'));
      ok(await docs.link(id, DocumentItemType.task, task));
      later();
      ok(await docs.link(id, DocumentItemType.goal, goal));
      refused(await docs.link(id, DocumentItemType.task, task), 'already');
      refused(await docs.link(id, DocumentItemType.event, 'none'), 'not found');
      expect([for (final l in await queries.linksOf(id)) (l.itemType, l.itemId)],
          [(DocumentItemType.task, task), (DocumentItemType.goal, goal)]);
      ok(await docs.unlink(id, DocumentItemType.task, task));
      refused(await docs.unlink(id, DocumentItemType.task, task), 'not linked');
      ok(await docs.link(id, DocumentItemType.task, task));
      expect(await queries.linksOf(id), hasLength(2));
      ok(await DriftTaskService(db, gw).trash(task));
      final other = await newDoc('Khác');
      refused(await docs.link(other, DocumentItemType.task, task), 'not found');
      // A link never changes the item.
      expect((await (db.select(db.goals)..where((g) => g.id.equals(goal))).getSingle()).version, 1);
    });
  });

  group('in a shared space', () {
    Future<void> joinAs(String role, {bool show = true}) async {
      await store.cacheSpace(SpaceSnapshot(workspaceId: space, ownerAccountId: 'acc-owner', name: 'Family', members: [
        const SpaceMemberSnapshot(accountId: 'acc-owner', role: 'owner'),
        SpaceMemberSnapshot(accountId: me, role: role),
      ]));
      if (show) ok(await DriftSpaceService(db, gw).show(space));
    }

    test('a member\'s document and save are "changed by" them; the revision names them', () async {
      await joinAs('editor');
      final id = await newDoc('Thực đơn tuần');
      ok(await docs.save(id, title: 'Thực đơn tuần', body: text('Phở')));
      final row = await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle();
      expect((row.workspaceId, row.ownerId, row.changedBy), (space, me, me));
      expect((await queries.revisions(id)).first.author, me);
      ok(await DriftSpaceService(db, gw).show(personal));
      expect(await queries.document(id), isNull, reason: 'the shown workspace only');
    });

    test('a viewer creates and saves nothing', () async {
      await joinAs('editor');
      final id = await newDoc('Chung');
      await joinAs('viewer', show: false); // the owner made them a viewer
      final r = await docs.save(id, title: 'Chung', body: text('đổi'));
      expect((r as CommandFailure).kind, CommandFailureKind.unauthorized);
      expect((await docs.create('Mới') as CommandFailure).kind, CommandFailureKind.unauthorized);
    });
  });

  group('commands that reach the gateway directly (a replay, another caller)', () {
    Future<CommandResult> raw(String id, Map<String, Object?> payload, String opId) async {
      final p = (await store.getActiveProfile())!;
      final v = (await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle()).version;
      return gw.execute(
          Command(
              operationId: opId,
              actor: ActorRef(ActorKind.owner, p.profileId.value),
              workspaceId: personal,
              type: 'SaveDocument',
              payload: {'id': id, ...payload},
              expectedVersion: Version(v),
              issuedAt: clock.now()),
          const DocumentCommandHandler());
    }

    test('a save of what is stored writes no revision; a revision id is used once; the body is stored in its fixed form',
        () async {
      final id = await newDoc('X');
      final first = (await queries.revisions(id)).single.id;
      final stored = (await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle()).body;
      refused(await raw(id, {'op': 'save', 'revisionId': 'r1', 'title': 'X', 'body': stored}, 'op-same'), 'nothing changed');
      refused(await raw(id, {'op': 'save', 'revisionId': first, 'title': 'Y', 'body': stored}, 'op-reuse'), 'written once');
      // Runs not merged, marks in another order: stored in the fixed form.
      const loose = '{"v":1,"blocks":[{"id":"b1","type":"paragraph","runs":[{"t":"Ghi "},{"t":"chú"},{"t":"!","m":["italic","bold"]}]}]}';
      ok(await raw(id, {'op': 'save', 'revisionId': 'r2', 'title': 'X', 'body': loose}, 'op-loose'));
      final body = (await (db.select(db.documents)..where((d) => d.id.equals(id))).getSingle()).body;
      expect(body, DocumentBody.decode(loose).encode());
      expect(body, isNot(loose));
    });

    test('a link to an item of another workspace is refused (DOC-004, as GOAL-003)', () async {
      await store.cacheSpace(SpaceSnapshot(workspaceId: space, ownerAccountId: 'acc-owner', name: 'Family', members: [
        const SpaceMemberSnapshot(accountId: 'acc-owner', role: 'owner'),
        const SpaceMemberSnapshot(accountId: me, role: 'editor'),
      ]));
      ok(await DriftSpaceService(db, gw).show(space));
      final theirs = ok(await DriftTaskService(db, gw).create('Của chung'));
      ok(await DriftSpaceService(db, gw).show(personal));
      final id = await newDoc('Của tôi');
      refused(await docs.link(id, DocumentItemType.task, theirs), 'another workspace');
    });

    test('the tree shows a document whose parent is not live at the top (a sync can leave one so)', () async {
      final a = await newDoc('A');
      final b = await newDoc('B', parentId: a);
      // As a pulled page could: A trashed on another device, B kept live.
      await (db.update(db.documents)..where((d) => d.id.equals(a))).write(DocumentsCompanion(deletedAt: Value(DateTime.utc(2026))));
      expect([for (final n in await queries.watchTree().first) n.id], [b]);
    });
  });

  group('from a file', () {
    test('an export with documents reads back; a file with what no command writes is refused', () async {
      final a = await newDoc('A');
      final b = await newDoc('B', parentId: a);
      ok(await docs.save(b, title: 'B', body: text('nội dung')));
      final task = ok(await DriftTaskService(db, gw).create('Gọi'));
      ok(await docs.link(a, DocumentItemType.task, task));
      final payload = await ProfileExport.payloadOf(db);
      String sealed(Map<String, Object?> p) =>
          ProfileExport.seal(p, schemaVersion: AppDatabase.currentSchemaVersion, now: DateTime.utc(2026, 11, 4));
      ProfileExport.parse(sealed(payload), currentSchemaVersion: AppDatabase.currentSchemaVersion);

      Map<String, Object?> changed(String key, void Function(List<Map<String, dynamic>> rows) edit) {
        final copy = jsonDecode(jsonEncode(payload)) as Map<String, Object?>;
        edit([for (final r in copy[key] as List) (r as Map).cast<String, dynamic>()]);
        return copy;
      }

      void rejected(Map<String, Object?> p, String mentions) => expect(
          () => ProfileExport.parse(sealed(p), currentSchemaVersion: AppDatabase.currentSchemaVersion),
          throwsA(isA<ExportRejected>().having((e) => e.message, 'message', contains(mentions))));

      rejected(changed('documents', (r) => r.firstWhere((d) => d['id'] == a)['parentId'] = b), 'under itself');
      rejected(changed('documents', (r) => r.first['body'] = '{"v":1,"blocks":[]}'), 'at least one block');
      rejected(changed('documents', (r) => r.first['body'] = 'not json'), 'cannot be read');
      rejected(changed('documents', (r) => r.first['title'] = '  '), 'valid title');
      rejected(changed('documentRevisions', (r) => r.first['body'] = 'x'), 'a revision');
      rejected(changed('documentRevisions', (r) => r.first['reason'] = 'magic'), 'unknown reason');
      rejected(changed('documentRevisions', (r) => r.first['documentId'] = 'gone'), 'documentRevision points to an unknown item');
      rejected(changed('documentLinks', (r) => r.first['id'] = 'forged'), 'does not match');
      rejected(changed('documentLinks', (r) => r.first['itemType'] = 'measurement'), 'points to an unknown item');
      rejected(
          changed('documentLinks', (r) {
            r.first..['itemType'] = 'document'..['itemId'] = b..['id'] = '$a|document:$b';
          }),
          'unknown item type');
    });
  });

  test('a saved document is found by its words (T2\'s index follows the commands)', () async {
    final id = await newDoc('Công thức');
    ok(await docs.save(id, title: 'Công thức', body: text('Bánh xèo miền Tây')));
    expect(await db.searchDocumentIds(personal, 'bánh xèo'), [id]);
    ok(await docs.trash(id));
    expect(await db.searchDocumentIds(personal, 'bánh xèo'), isEmpty);
  });
}

Future<CommandResult> newDocResult(DocumentService docs, String title, {String? parentId}) =>
    docs.create(title, parentId: parentId);
