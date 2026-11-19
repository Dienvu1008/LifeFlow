// P05a T2 (ADR-0067; p05-plan C4, C6, C12): search by the exact spelling and
// the `[[…]]` link index, on the real store (in memory; the sqlite3mc build).
//   spelling   marks kept, case ignored, the same word typed three ways
//              (NFC, NFD, a vowel letter with its tone apart) found alike;
//              "ghi chu" does not find "ghi chú"; "đ" is its own letter
//   index      kept up whatever writes the row (insert, update, tombstone,
//              purge, a freed rowid reused); records are never rewritten
//   documents  title and body text; an unreadable body still finds the title
//   links      backlinks from the bodies, live documents of one workspace only
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart' show rewindProfileStore;

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now().toUtc();
    for (final ws in ['ws1', 'ws2']) {
      await db.into(db.workspaces).insert(WorkspacesCompanion.insert(id: ws, ownerId: 'o', createdAt: now));
    }
  });
  tearDown(() => db.close());

  Future<void> task(String id, String title, {String ws = 'ws1'}) async {
    final now = DateTime.now().toUtc();
    await db.into(db.tasks).insert(
        TasksCompanion.insert(id: id, workspaceId: ws, ownerId: 'o', createdAt: now, updatedAt: now, title: title));
  }

  String body(List<TextRun> runs) => DocumentBody([DocBlock('b1', BlockType.paragraph, runs: runs)]).encode();

  Future<void> doc(String id, String title, String body, {String ws = 'ws1'}) async {
    final now = DateTime.now().toUtc();
    await db.into(db.documents).insert(DocumentsCompanion.insert(
        id: id, workspaceId: ws, ownerId: 'o', createdAt: now, updatedAt: now, title: title, body: body));
  }

  Future<List<String>> tasks(String q, {String ws = 'ws1'}) async => [...await db.searchTaskIds(ws, q)]..sort();

  // The same words, typed three ways.
  const nfc = 'Ghi chú họp ở Đà Nẵng';
  const nfd = 'Ghi chu\u0301 ho\u0323p o\u0309 \u0110a\u0300 Na\u0306\u0303ng';
  const half = 'Ghi chu\u0301 ho\u0323p o\u0309 \u0110a\u0300 N\u0103\u0303ng'; // ă kept whole, its tone apart

  group('the exact spelling (C4, C12)', () {
    test('Vietnamese words are found however the keyboard encoded the marks', () async {
      await task('nfc', nfc);
      await task('nfd', nfd);
      await task('half', half);
      await task('plain', 'Ghi chu hop o Da Nang');
      for (final typed in [
        'ghi chú', 'GHI CHÚ', 'chu\u0301', 'Đà Nẵng', 'đà nẵng', 'Na\u0306\u0303ng', 'N\u0103\u0303ng', 'họp', '"ghi chú họp"',
      ]) {
        expect(await tasks(typed), ['half', 'nfc', 'nfd'], reason: typed);
      }
      for (final typed in ['ghi chu', 'chu', 'da nang', 'hop', 'Da']) {
        expect(await tasks(typed), ['plain'], reason: '$typed: without marks, only the text without marks');
      }
    });

    test('the last word is the start of a word; a trailing space ends it; FTS syntax is plain text', () async {
      await task('t1', 'Kế hoạch năm mới');
      expect(await tasks('kế hoạ'), ['t1']);
      expect(await tasks('kế hoạ '), isEmpty);
      expect(await tasks('năm OR xyz'), isEmpty, reason: 'OR is a word to find, not an operator');
      expect(await tasks('"mới năm"'), isEmpty, reason: 'a phrase keeps its order');
      expect(await tasks('   '), isEmpty);
    });

    test('a workspace finds only its own; a trashed task is not found', () async {
      await task('a', 'Đi chợ');
      await task('b', 'Đi chợ', ws: 'ws2');
      expect(await tasks('chợ'), ['a']);
      expect(await tasks('chợ', ws: 'ws2'), ['b']);
      await (db.update(db.tasks)..where((t) => t.id.equals('a'))).write(TasksCompanion(deletedAt: Value(DateTime.now().toUtc())));
      expect(await tasks('chợ'), isEmpty);
    });
  });

  group('the index follows every write', () {
    test('a rename, a purge, and a freed rowid given to a new task', () async {
      await task('t1', 'Mua sữa');
      expect(await tasks('sữa'), ['t1']);
      await (db.update(db.tasks)..where((t) => t.id.equals('t1'))).write(const TasksCompanion(title: Value('Mua bánh mì')));
      expect(await tasks('sữa'), isEmpty);
      expect(await tasks('bánh'), ['t1']);
      final rowid = (await db.customSelect("SELECT rowid AS r FROM tasks WHERE id = 't1'").getSingle()).read<int>('r');
      await db.customStatement("DELETE FROM tasks WHERE id = 't1'");
      // A new task takes the same rowid before the index catches up.
      final now = DateTime.now().toUtc();
      await db.customStatement(
          'INSERT INTO tasks (rowid, id, workspace_id, owner_id, created_at, updated_at, title) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [rowid, 't2', 'ws1', 'o', now.millisecondsSinceEpoch ~/ 1000, now.millisecondsSinceEpoch ~/ 1000, 'Gọi điện']);
      expect(await tasks('bánh'), isEmpty);
      expect(await tasks('điện'), ['t2']);
      expect(await db.select(db.searchPending).get(), isEmpty, reason: 'caught up');
    });

    test('a purged task and document leave no text in the index (GS-14)', () async {
      await task('t1', 'Bí mật');
      await doc('d1', 'Nhật ký', body([TextRun('riêng tư')]));
      await tasks('bí');
      await db.customStatement("DELETE FROM tasks WHERE id = 't1'");
      await db.customStatement("DELETE FROM documents WHERE id = 'd1'");
      await tasks('bí');
      for (final t in ['tasks_fts', 'documents_fts']) {
        expect((await db.customSelect('SELECT count(*) AS n FROM $t').getSingle()).read<int>('n'), 0, reason: t);
      }
      expect(await db.select(db.documentLinkIndex).get(), isEmpty);
    });

    test('the index is the only thing written: the record keeps its bytes', () async {
      await task('t1', nfd);
      await tasks('chú');
      final row = await (db.select(db.tasks)..where((t) => t.id.equals('t1'))).getSingle();
      expect(row.title, nfd);
      expect(row.version, 1);
      expect(await db.select(db.outbox).get(), isEmpty);
    });
  });

  test('the v15 -> v16 upgrade indexes the tasks already there, by the exact spelling', () async {
    final dir = Directory.systemTemp.createTempSync('lf_search_upgrade_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/store.db');
    final old = AppDatabase(NativeDatabase(file));
    final now = DateTime.now().toUtc();
    await old.into(old.workspaces).insert(WorkspacesCompanion.insert(id: 'ws1', ownerId: 'o', createdAt: now));
    await old.into(old.tasks).insert(
        TasksCompanion.insert(id: 't1', workspaceId: 'ws1', ownerId: 'o', createdAt: now, updatedAt: now, title: nfd));
    await rewindProfileStore(old, 15);
    await old.customStatement('PRAGMA user_version = 15');
    expect((await old.customSelect("SELECT rowid FROM tasks_fts WHERE tasks_fts MATCH 'chu'").get()).length, 1,
        reason: 'v15: marks removed by the default tokenizer');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect(await upgraded.searchTaskIds('ws1', 'chú'), ['t1']);
    expect(await upgraded.searchTaskIds('ws1', 'chu'), isEmpty);
    expect(await upgraded.searchDocumentIds('ws1', 'chú'), isEmpty);
  });

  group('documents', () {
    test('title and body text are found; an unreadable body still finds the title', () async {
      await doc('d1', 'Chuyến đi', body([TextRun('Biển Mỹ Khê, '), TextRun('tháng Sáu', marks: {TextMark.bold})]));
      await doc('d2', 'Sách muốn đọc', '{"v":99,"blocks":[]}');
      await doc('d3', 'Khác', body([TextRun('biển')]), ws: 'ws2');
      expect(await db.searchDocumentIds('ws1', 'mỹ khê'), ['d1']);
      expect(await db.searchDocumentIds('ws1', 'tháng sáu'), ['d1'], reason: 'marks of style do not matter');
      expect(await db.searchDocumentIds('ws1', 'chuyến'), ['d1']);
      expect(await db.searchDocumentIds('ws1', 'sách'), ['d2']);
      expect(await db.searchDocumentIds('ws1', 'biển'), ['d1']);
      await (db.update(db.documents)..where((d) => d.id.equals('d1')))
          .write(DocumentsCompanion(body: Value(body([TextRun('Núi Bà Nà')]))));
      expect(await db.searchDocumentIds('ws1', 'biển'), isEmpty);
      expect(await db.searchDocumentIds('ws1', 'bà nà'), ['d1']);
    });

    test('backlinks: the live documents of the workspace whose text links here', () async {
      await doc('target', 'Ghi chú họp', body([TextRun('Nội dung')]));
      await doc('a', 'A', body([TextRun('Xem '), TextRun('họp', doc: 'target')]));
      await doc('b', 'B', body([TextRun('Lại '), TextRun('họp', doc: 'target'), TextRun(' và '), TextRun('khác', doc: 'other')]));
      await doc('c', 'C', body([TextRun('không liên quan')]));
      await doc('self', 'Self', body([TextRun('mình', doc: 'self')]));
      await doc('elsewhere', 'E', body([TextRun('họp', doc: 'target')]), ws: 'ws2');
      expect(await db.backlinkIds('ws1', 'target'), ['a', 'b']);
      expect(await db.backlinkIds('ws1', 'other'), ['b']);
      expect(await db.backlinkIds('ws1', 'self'), isEmpty, reason: 'a document is not its own backlink');
      await (db.update(db.documents)..where((d) => d.id.equals('a')))
          .write(DocumentsCompanion(body: Value(body([TextRun('bỏ liên kết')]))));
      expect(await db.backlinkIds('ws1', 'target'), ['b']);
      await (db.update(db.documents)..where((d) => d.id.equals('b'))).write(DocumentsCompanion(deletedAt: Value(DateTime.now().toUtc())));
      expect(await db.backlinkIds('ws1', 'target'), isEmpty, reason: 'a document in the trash links nothing');
    });
  });
}
