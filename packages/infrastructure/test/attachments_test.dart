// P05a T7 (ADR-0072; C3, OQ-DATA-2): attachment files on this device only,
// encrypted.
//   at rest     the folder holds neither the bytes nor their hash; the same
//               file twice is kept once
//   reading     checked against the hash: a changed byte or a lost key is
//               "unreadable" or "elsewhere", never an error
//   documents   a missing file never breaks a document (open, save, search,
//               history)
//   sweep       only files no document or revision names, and only old ones;
//               nothing when a body cannot be read
//   profiles    deleting a profile deletes its files and their key
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:test/test.dart';

import 'profile_harness.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory base;
  late AppDatabase db;
  late MemoryKeys keys;
  late DriftAttachmentService files;
  var now = DateTime.now();

  DriftAttachmentService serviceWith(MemoryKeys k, {String slot = 'lifeflow.attach.key.p1'}) =>
      DriftAttachmentService(db, folder: Directory('${base.path}/p1.files'), keys: k(slot), now: () => now);

  setUp(() async {
    base = Directory.systemTemp.createTempSync('lifeflow_attach_');
    db = AppDatabase(NativeDatabase.memory());
    keys = MemoryKeys();
    files = serviceWith(keys);
    now = DateTime.now(); // files carry the real clock's times
  });
  tearDown(() async {
    await db.close();
    base.deleteSync(recursive: true);
  });

  final photo = Uint8List.fromList(utf8.encode('Ảnh chụp bảng trắng: họp thứ Hai, phòng 3. ' * 40));

  List<File> stored() => Directory('${base.path}/p1.files').existsSync()
      ? Directory('${base.path}/p1.files').listSync().whereType<File>().toList()
      : <File>[];

  bool holds(List<int> hay, List<int> needle) {
    for (var i = 0; i + needle.length <= hay.length; i++) {
      var j = 0;
      while (j < needle.length && hay[i + j] == needle[j]) {
        j++;
      }
      if (j == needle.length) return true;
    }
    return false;
  }

  AttachmentRef added(AttachmentAdded a) {
    expect(a.problem, isNull);
    return a.ref!;
  }

  group('at rest (C3)', () {
    test('kept encrypted, under a name that is not its hash; read back whole; the same file kept once', () async {
      final ref = added(await files.add(photo, name: '  bảng trắng.png ', mime: 'Image/PNG'));
      expect((ref.name, ref.size, ref.mime), ('bảng trắng.png', photo.length, 'image/png'));
      expect(ref.hash, attachmentHashOf(photo));
      expect(ref.hash, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
      final f = stored().single;
      final raw = f.readAsBytesSync();
      expect(holds(raw, utf8.encode('bảng trắng')), isFalse, reason: 'the text is not readable at rest');
      expect(holds(raw, photo.sublist(0, 32)), isFalse);
      expect(f.path, isNot(contains(ref.hash.substring(7))), reason: 'the folder does not tell which file it is');
      expect(keys.values['lifeflow.attach.key.p1'], isNotNull, reason: 'a key made at the first file');

      final back = await files.open(ref.hash);
      expect(back.availability, AttachmentAvailability.here);
      expect(back.bytes, photo);
      expect(await files.availability(ref.hash), AttachmentAvailability.here);

      added(await files.add(photo, name: 'again.png', mime: 'image/png'));
      expect(stored(), hasLength(1), reason: 'one file per content');
      expect(added(await files.add(Uint8List(0), name: 'empty', mime: 'nonsense')).mime, 'application/octet-stream');
      expect(stored(), hasLength(2));
    });

    test('too large, or without a usable name: nothing kept', () async {
      expect((await files.add(Uint8List(maxAttachmentBytes + 1), name: 'big.bin', mime: 'application/zip')).problem,
          AttachmentProblem.tooLarge);
      expect((await files.add(photo, name: '   ', mime: 'image/png')).problem, AttachmentProblem.badName);
      expect((await files.add(photo, name: 'x' * 256, mime: 'image/png')).problem, AttachmentProblem.badName);
      expect(stored(), isEmpty);
      expect(await files.availability(attachmentHashOf(photo)), AttachmentAvailability.elsewhere);
      expect((await files.open(attachmentHashOf(photo))).availability, AttachmentAvailability.elsewhere);
      expect(keys.values, isEmpty, reason: 'no key without a file; looking makes none');
    });
  });

  group('reading', () {
    test('a file not here is elsewhere; a changed byte is unreadable; another key finds nothing', () async {
      final ref = added(await files.add(photo, name: 'a.png', mime: 'image/png'));
      expect((await files.open(attachmentHashOf([1, 2, 3]))).availability, AttachmentAvailability.elsewhere);
      expect(await serviceWith(MemoryKeys()).availability(ref.hash), AttachmentAvailability.elsewhere,
          reason: 'before any file of its own: no key, nothing here');

      final f = stored().single;
      final raw = f.readAsBytesSync();
      f.writeAsBytesSync([...raw.sublist(0, 40), raw[40] ^ 1, ...raw.sublist(41)]);
      final broken = await files.open(ref.hash);
      expect((broken.availability, broken.bytes), (AttachmentAvailability.unreadable, null));
      f.writeAsBytesSync([2, ...raw.sublist(1)]);
      expect((await files.open(ref.hash)).availability, AttachmentAvailability.unreadable, reason: 'a newer format');
      f.writeAsBytesSync(const []);
      expect((await files.open(ref.hash)).availability, AttachmentAvailability.unreadable);
      // Adding the same file again repairs a damaged copy.
      added(await files.add(photo, name: 'a.png', mime: 'image/png'));
      expect((await files.open(ref.hash)).bytes, photo);

      // Secure storage lost the key: a new one names files differently.
      keys.values.clear();
      final fresh = serviceWith(keys);
      expect(await fresh.availability(ref.hash), AttachmentAvailability.elsewhere);
      added(await fresh.add(photo, name: 'a.png', mime: 'image/png'));
      expect((await fresh.open(ref.hash)).availability, AttachmentAvailability.here);
      expect(stored(), hasLength(2));
    });
  });

  group('documents', () {
    test('a document with a file that is not here opens, saves, is found by the file name, keeps its history',
        () async {
      final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
      await ProfileStore(db).ensureFirstProfile();
      final docs = DriftDocumentService(db, gw);
      final queries = DriftDocumentQueries(db);
      final id = (await docs.create('Họp') as CommandOk).entityId;
      final missing = AttachmentRef(hash: attachmentHashOf(utf8.encode('on the phone')), name: 'biên bản.pdf', size: 12, mime: 'application/pdf');
      final body = DocumentBody([
        DocBlock('a', BlockType.paragraph, runs: [TextRun('Xem tệp:')]),
        DocBlock('f', BlockType.attachment, attachment: missing),
      ]);
      expect(await docs.save(id, title: 'Họp', body: body), isA<CommandOk>());
      final v = (await queries.document(id))!;
      expect((v.isUnreadable, v.body.blocks.last.attachment), (false, missing));
      expect(await files.availability(missing.hash), AttachmentAvailability.elsewhere);
      expect([for (final h in (await DriftSearchQueries(db).search('biên bản')).documents) h.id], [id]);
      expect(await queries.revisions(id), hasLength(2));
    });
  });

  group('sweep', () {
    test('only files no document or revision names, older than the grace; nothing while a body cannot be read', () async {
      final gw = DriftCommandGateway(db, WorkspaceOwnerAuthorization(db));
      await ProfileStore(db).ensureFirstProfile();
      final docs = DriftDocumentService(db, gw);
      DocumentBody withFile(AttachmentRef r) => DocumentBody([DocBlock('f', BlockType.attachment, attachment: r)]);
      final inDoc = added(await files.add(Uint8List.fromList([1, 2, 3]), name: 'in doc', mime: 'image/png'));
      final inHistory = added(await files.add(Uint8List.fromList([4, 5, 6]), name: 'in history', mime: 'image/png'));
      final dropped = added(await files.add(Uint8List.fromList([7, 8, 9]), name: 'never saved', mime: 'image/png'));
      final id = (await docs.create('Ảnh') as CommandOk).entityId;
      expect(await docs.save(id, title: 'Ảnh', body: withFile(inHistory)), isA<CommandOk>());
      expect(await docs.save(id, title: 'Ảnh', body: withFile(inDoc)), isA<CommandOk>());

      expect(await files.sweep(), 0, reason: 'all are newer than a day');
      now = now.add(const Duration(days: 2));
      final kept = (await db.customSelect('SELECT body FROM documents').getSingle()).read<String>('body');
      await db.customStatement("UPDATE documents SET body = '{\"v\":99,\"blocks\":[]}'");
      expect(await files.sweep(), 0, reason: 'a body this app cannot read may name any file');
      await db.customStatement('UPDATE documents SET body = ?', [kept]);
      expect(await files.sweep(), 1);
      for (final (r, here) in [(inDoc, true), (inHistory, true), (dropped, false)]) {
        expect(await files.availability(r.hash), here ? AttachmentAvailability.here : AttachmentAvailability.elsewhere,
            reason: r.name);
      }
    });
  });

  test('deleting a profile deletes its files and their key', () async {
    final root = Directory('${base.path}/root')..createSync();
    final dirKeys = MemoryKeys();
    final dir = await openDirectory(root, dirKeys);
    var closed = false;
    addTearDown(() async {
      if (!closed) await dir.close();
    });
    final other = await dir.createProfile(displayName: 'Khác');
    final store = await dir.openProfile(other.id);
    final mine = DriftAttachmentService(store.db, folder: dir.attachmentsDir(other.id), keys: dir.attachmentKeys(other.id));
    final ref = added(await mine.add(photo, name: 'a.png', mime: 'image/png'));
    expect(await mine.availability(ref.hash), AttachmentAvailability.here);
    expect(dirKeys.values.keys, contains(ProfileDirectory.attachmentKeyName(other.id)));
    await store.db.close();

    await dir.deleteProfile(other.id);
    expect(dir.attachmentsDir(other.id).existsSync(), isFalse);
    expect(dirKeys.values.keys, isNot(contains(ProfileDirectory.attachmentKeyName(other.id))));
    closed = true;
    await dir.close();
  });
}
