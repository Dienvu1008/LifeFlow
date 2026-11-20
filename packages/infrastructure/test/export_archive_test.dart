// P05a T9 (ADR-0074; p05-plan.md C11, GS-20): documents and all their
// revisions in the export; a `.zip` with the files beside the JSON when
// documents have files on this device; a plain JSON file otherwise.
//   round trip   a clean install gets the documents, their history, their
//                links and their files (kept encrypted with its own key)
//   same device  a file lost here comes back from the .zip
//   untrusted    only our names; each file checked against its hash; stored
//                entries only (no zip bomb); the JSON's own checks as ever
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:archive/archive.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart';

void main() {
  late Directory base;
  late MemoryKeys keys;
  late ProfileDirectory dir;
  late TestHost host;
  late DriftDataTransferService transfer;
  late String profileId;
  final cleanups = <Future<void> Function()>[];

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_zip_');
    keys = MemoryKeys();
    dir = await openDirectory(base, keys);
    host = TestHost(dir);
    await host.openActive();
    transfer = DriftDataTransferService(host.db, dir, clock: () => DateTime.utc(2026, 11, 7, 9));
    profileId = host.currentId!;
  });
  tearDown(() async {
    for (final c in cleanups.reversed) {
      await c();
    }
    cleanups.clear();
    await host.close();
    await dir.close();
    if (base.existsSync()) base.deleteSync(recursive: true);
  });

  String ok(CommandResult r) {
    expect(r, isA<CommandOk>(), reason: '$r');
    return (r as CommandOk).entityId;
  }

  DriftAttachmentService filesOf(ProfileDirectory d, String id, [AppDatabase? db]) =>
      DriftAttachmentService(db, folder: d.attachmentsDir(id), keys: d.attachmentKeys(id));

  final photo = Uint8List.fromList(utf8.encode('ảnh bảng trắng ' * 50));
  final pdf = Uint8List.fromList(List.generate(3000, (i) => i % 251));

  /// A document with a picture, an older version with a PDF (only in its
  /// history), a subdocument, a link to a task; and a file not on this device.
  Future<({String doc, String sub, AttachmentRef photo, AttachmentRef pdf, AttachmentRef elsewhere})> seed() async {
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    final docs = DriftDocumentService(host.db, gw, deviceId: 'windows');
    final files = filesOf(dir, profileId, host.db);
    final p = (await files.add(photo, name: 'bảng.png', mime: 'image/png')).ref!;
    final f = (await files.add(pdf, name: 'biên bản.pdf', mime: 'application/pdf')).ref!;
    final elsewhere = AttachmentRef(hash: attachmentHashOf(utf8.encode('on the phone')), name: 'xa.jpg', size: 12, mime: 'image/jpeg');
    DocBlock fileBlock(String id, AttachmentRef r) => DocBlock(id, BlockType.attachment, attachment: r);
    final doc = ok(await docs.create('Họp'));
    ok(await docs.save(doc, title: 'Họp', body: DocumentBody([fileBlock('f', f)])));
    ok(await docs.save(doc,
        title: 'Họp',
        body: DocumentBody([
          DocBlock('a', BlockType.paragraph, runs: [TextRun('Xem ảnh')]),
          fileBlock('p', p),
          fileBlock('x', elsewhere),
        ])));
    final sub = ok(await docs.create('Chi tiết', parentId: doc));
    final t = ok(await DriftTaskService(host.db, gw).create('Gửi biên bản'));
    ok(await docs.link(doc, DocumentItemType.task, t));
    return (doc: doc, sub: sub, photo: p, pdf: f, elsewhere: elsewhere);
  }

  Future<Map<String, List<String>>> documentRows(AppDatabase db) async {
    List<String> j(Iterable<Map<String, dynamic>> rows) => rows.map(jsonEncode).toList()..sort();
    return {
      'documents': j((await db.select(db.documents).get()).map((r) => r.toJson())),
      'revisions': j((await db.select(db.documentRevisions).get()).map((r) => r.toJson())),
      'links': j((await db.select(db.documentLinks).get()).map((r) => r.toJson())),
    };
  }

  Future<ProfileDirectory> cleanInstall(MemoryKeys k) async {
    final b = Directory.systemTemp.createTempSync('lifeflow_zip_clean_');
    final d = await openDirectory(b, k);
    cleanups.add(() async {
      await d.close();
      if (b.existsSync()) b.deleteSync(recursive: true);
    });
    return d;
  }

  test('GS-20 with documents: the .zip carries the history and the files; a clean install gets them all', () async {
    final s = await seed();
    final before = await documentRows(host.db);
    final file = await transfer.exportActiveProfile();
    expect(file.suggestedName, endsWith('.lifeflow.zip'));
    expect(file.fileCount, 2, reason: 'the picture and the PDF only in the history; not the file from elsewhere');
    expect(isZipArchive(file.archive!), isTrue);
    final names = [for (final f in ZipDecoder().decodeBytes(file.archive!).files) f.name]..sort();
    expect(names, [
      ...[for (final h in [s.photo.hash, s.pdf.hash]) 'attachments/${h.substring(7)}']..sort(),
      'lifeflow-export.json',
    ]..sort());
    expect(ProfileExport.parse(file.contents, currentSchemaVersion: AppDatabase.currentSchemaVersion).records['documentRevision'],
        hasLength(4), reason: 'every revision (C11)');

    final cleanKeys = MemoryKeys();
    final clean = await cleanInstall(cleanKeys);
    final h = TestHost(clean);
    await h.openActive();
    cleanups.add(h.close);
    final r = await DriftDataTransferService(h.db, clean).restoreFile(file.archive!);
    expect(r, isA<Restored>(), reason: '$r');
    final store = await clean.openProfile(profileId);
    cleanups.add(store.db.close);
    expect(await documentRows(store.db), before);

    final there = filesOf(clean, profileId);
    expect((await there.open(s.photo.hash)).bytes, photo);
    expect((await there.open(s.pdf.hash)).bytes, pdf);
    expect(await there.availability(s.elsewhere.hash), AttachmentAvailability.elsewhere);
    expect(cleanKeys.values.containsKey(ProfileDirectory.attachmentKeyName(profileId)), isTrue,
        reason: 'kept with the clean install\'s own key');
    for (final f in clean.attachmentsDir(profileId).listSync().whereType<File>()) {
      expect(utf8.decode(f.readAsBytesSync(), allowMalformed: true), isNot(contains('bảng trắng')));
    }
    expect(await store.db.searchDocumentIds((await ProfileStore(store.db).personalWorkspaceId())!, 'xem ảnh'), [s.doc]);
  });

  test('without files on this device the export stays a plain JSON file, read as before', () async {
    final gw = DriftCommandGateway(host.db, WorkspaceOwnerAuthorization(host.db));
    final docs = DriftDocumentService(host.db, gw);
    final d = ok(await docs.create('Chỉ chữ'));
    ok(await docs.save(d,
        title: 'Chỉ chữ',
        body: DocumentBody([
          DocBlock('x', BlockType.attachment,
              attachment: AttachmentRef(hash: attachmentHashOf([9]), name: 'xa.png', size: 1, mime: 'image/png')),
        ])));
    final file = await transfer.exportActiveProfile();
    expect((file.archive, file.fileCount, file.suggestedName), (null, 0, 'lifeflow-profile-2026-11-07.lifeflow.json'));
    final clean = await cleanInstall(MemoryKeys());
    final h = TestHost(clean);
    await h.openActive();
    cleanups.add(h.close);
    expect(await DriftDataTransferService(h.db, clean).restoreFile(Uint8List.fromList(utf8.encode(file.contents))),
        isA<Restored>());
  });

  test('on the same device: a file lost here comes back from the .zip', () async {
    final s = await seed();
    final file = await transfer.exportActiveProfile();
    dir.attachmentsDir(profileId).deleteSync(recursive: true);
    expect(await filesOf(dir, profileId).availability(s.photo.hash), AttachmentAvailability.elsewhere);
    expect(await transfer.inspectFile(file.archive!), isA<RestoreIdentical>());
    final r = await transfer.restoreFile(file.archive!, choice: const RestoreChoice.overwrite());
    expect(r, isA<RestoredInto>(), reason: '$r');
    expect((await filesOf(dir, profileId).open(s.photo.hash)).bytes, photo);
  });

  group('the .zip is untrusted (SR-14)', () {
    late ExportFile good;
    setUp(() async {
      await seed();
      good = await transfer.exportActiveProfile();
    });

    Uint8List rezip(void Function(Archive a) change) {
      final a = Archive();
      for (final f in ZipDecoder().decodeBytes(good.archive!).files) {
        final b = f.readBytes()!;
        a.addFile(ArchiveFile.noCompress(f.name, b.length, b));
      }
      change(a);
      return ZipEncoder().encodeBytes(a);
    }

    Future<RestoreRejection?> rejected(Uint8List bytes) async {
      final p = await transfer.inspectFile(bytes);
      final r = await transfer.restoreFile(bytes, choice: const RestoreChoice.overwrite());
      expect(r.runtimeType == RestoreRejected, p is RestoreRejected, reason: 'inspect and restore agree');
      return r is RestoreRejected ? r.kind : null;
    }

    test('a file that is not its hash, a forged export inside, no export inside, garbage', () async {
      final someHash = good.archive == null ? '' : ZipDecoder().decodeBytes(good.archive!).files.firstWhere((f) => f.name.startsWith('attachments/')).name;
      expect(
          await rejected(rezip((a) {
            final b = Uint8List.fromList([1, 2, 3]);
            a.addFile(ArchiveFile.noCompress(someHash, b.length, b));
          })),
          RestoreRejection.corrupted,
          reason: 'its bytes do not match its name');
      expect(
          await rejected(rezip((a) {
            final t = utf8.encode(good.contents.replaceFirst('Họp', 'Giả'));
            a.addFile(ArchiveFile.noCompress('lifeflow-export.json', t.length, t));
          })),
          isNotNull,
          reason: 'the JSON keeps its checksum');
      final noJson = Archive();
      final b = Uint8List.fromList([1]);
      noJson.addFile(ArchiveFile.noCompress('attachments/${attachmentHashOf(b).substring(7)}', b.length, b));
      expect(await rejected(ZipEncoder().encodeBytes(noJson)), RestoreRejection.notAnExport);
      expect(await rejected(Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 1, 2, 3])), RestoreRejection.notAnExport);
    });

    test('only stored entries are read (no zip bomb); entries that are not ours are ignored', () async {
      final compressed = Archive();
      for (final f in ZipDecoder().decodeBytes(good.archive!).files) {
        compressed.addFile(ArchiveFile.bytes(f.name, f.readBytes()!));
      }
      expect(await rejected(ZipEncoder().encodeBytes(compressed)), RestoreRejection.notAnExport);
      expect(
          await rejected(rezip((a) {
            final t = utf8.encode('hello');
            a.addFile(ArchiveFile.noCompress('../../evil.txt', t.length, t));
            a.addFile(ArchiveFile.noCompress('attachments/not-a-hash', t.length, t));
          })),
          isNull,
          reason: 'ignored, never written anywhere');
      expect(base.parent.listSync().whereType<File>().where((f) => f.path.endsWith('evil.txt')), isEmpty);
    });
  });
}
