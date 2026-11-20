// P05a T7 (ADR-0072; p05-plan.md C3; answers OQ-DATA-2 for P05a): the files
// of a profile's documents, kept on this device only, encrypted.
//   where      <profiles>/<profileId>.files/, one file per content
//   key        a random 256-bit key in secure storage
//              (`lifeflow.attach.key.<profileId>`), made at the first file;
//              two keys are derived from it (HKDF): one encrypts, one names
//   a file     format byte 1, then AES-256-GCM (nonce | ciphertext | tag) of
//              the bytes, bound to the file's hash (associated data); its
//              name is an HMAC of the hash, so the folder does not tell
//              which known file is there
//   reading    decrypted; the tag covers the bytes and their hash, so a
//              changed file is "unreadable", never an error that breaks
//              the document
// The database is not touched: the body's AttachmentRef is the reference.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:domain/domain.dart' show relationsOf;

import 'app_database.dart';
import 'local_store.dart' show DatabaseKeyStore;

const _format = 1;
const _suffix = '.lfa';
final _aes = AesGcm.with256bits();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// The reference of [bytes]: `sha256:` and 64 hex digits.
String attachmentHashOf(List<int> bytes) => 'sha256:${crypto.sha256.convert(bytes)}';

class DriftAttachmentService implements AttachmentService {
  DriftAttachmentService(this.db, {required this.folder, required this.keys, DateTime Function()? now})
      : _now = now ?? DateTime.now;
  /// The profile's store, for [sweep] (null: keeping and reading files only,
  /// as a restore into a profile that is not open does).
  final AppDatabase? db;
  final Directory folder;
  final DatabaseKeyStore keys;
  final DateTime Function() _now;

  ({SecretKey seal, SecretKey names})? _keys;

  Future<({SecretKey seal, SecretKey names})?> _keysOf({bool create = false}) async {
    if (_keys != null) return _keys;
    var stored = await keys.read();
    if (stored == null) {
      if (!create) return null;
      stored = base64Encode(await (await _aes.newSecretKey()).extractBytes());
      await keys.write(stored);
    }
    final root = SecretKey(base64Decode(stored));
    return _keys = (
      seal: await _hkdf.deriveKey(secretKey: root, info: utf8.encode('lifeflow attachment seal v1')),
      names: await _hkdf.deriveKey(secretKey: root, info: utf8.encode('lifeflow attachment name v1')),
    );
  }

  Future<String> _nameOf(SecretKey names, String hash) async {
    final mac = await Hmac.sha256().calculateMac(utf8.encode(hash), secretKey: names);
    return '${[for (final b in mac.bytes) b.toRadixString(16).padLeft(2, '0')].join()}$_suffix';
  }

  List<int> _aad(String hash) => utf8.encode('lifeflow attachment v1:$hash');

  Future<File?> _fileOf(String hash, {bool create = false}) async {
    final k = await _keysOf(create: create);
    return k == null ? null : File('${folder.path}${Platform.pathSeparator}${await _nameOf(k.names, hash)}');
  }

  @override
  Future<AttachmentAdded> add(Uint8List bytes, {required String name, required String mime}) async {
    if (bytes.length > maxAttachmentBytes) return const AttachmentAdded.failed(AttachmentProblem.tooLarge);
    final n = name.trim();
    if (n.isEmpty || n.length > maxAttachmentNameLength) return const AttachmentAdded.failed(AttachmentProblem.badName);
    final type = RegExp(r'^[a-z0-9.+-]+/[a-z0-9.+-]+$').hasMatch(mime.trim().toLowerCase())
        ? mime.trim().toLowerCase()
        : 'application/octet-stream';
    final hash = attachmentHashOf(bytes);
    final ref = AttachmentRef(hash: hash, name: n, size: bytes.length, mime: type);
    try {
      if ((await open(hash)).availability == AttachmentAvailability.here) return AttachmentAdded.ok(ref);
      final file = (await _fileOf(hash, create: true))!;
      await folder.create(recursive: true);
      final box = await _aes.encrypt(bytes, secretKey: (await _keysOf())!.seal, aad: _aad(hash));
      // Written aside, then renamed: a file is whole or not there.
      final part = File('${file.path}.part');
      await part.writeAsBytes([_format, ...box.concatenation()], flush: true);
      await part.rename(file.path);
      return AttachmentAdded.ok(ref);
    } on FileSystemException {
      return const AttachmentAdded.failed(AttachmentProblem.failed);
    }
  }

  @override
  Future<AttachmentAvailability> availability(String hash) async {
    final f = await _fileOf(hash);
    return f != null && f.existsSync() ? AttachmentAvailability.here : AttachmentAvailability.elsewhere;
  }

  @override
  Future<AttachmentContent> open(String hash) async {
    final f = await _fileOf(hash);
    if (f == null || !f.existsSync()) return const AttachmentContent(AttachmentAvailability.elsewhere);
    try {
      final raw = await f.readAsBytes();
      if (raw.isEmpty || raw.first != _format) return const AttachmentContent(AttachmentAvailability.unreadable);
      final box = SecretBox.fromConcatenation(raw.sublist(1), nonceLength: 12, macLength: 16, copy: true);
      // The tag covers the bytes and the hash they were kept under (the
      // associated data): a file that opens is the file of this hash.
      final clear = Uint8List.fromList(await _aes.decrypt(box, secretKey: (await _keysOf())!.seal, aad: _aad(hash)));
      return AttachmentContent(AttachmentAvailability.here, clear);
    } on SecretBoxAuthenticationError {
      return const AttachmentContent(AttachmentAvailability.unreadable);
    } on ArgumentError {
      return const AttachmentContent(AttachmentAvailability.unreadable);
    } on FileSystemException {
      return const AttachmentContent(AttachmentAvailability.unreadable);
    }
  }

  @override
  Future<int> sweep({Duration grace = const Duration(days: 1)}) async {
    final k = await _keysOf();
    final db = this.db;
    if (db == null || k == null || !folder.existsSync()) return 0;
    // Every file named by a document or a revision, in every workspace of
    // the store. A body this app cannot read may name files too: then
    // nothing is removed.
    final named = <String>{};
    for (final table in const ['documents', 'document_revisions']) {
      for (final r in await db.customSelect('SELECT body FROM $table').get()) {
        final DocumentBody body;
        try {
          body = DocumentBody.decode(r.read<String>('body'));
        } on FormatException {
          return 0;
        }
        for (final h in relationsOf(parentId: null, body: body).attachments) {
          named.add(await _nameOf(k.names, h));
        }
      }
    }
    final before = _now().subtract(grace);
    var removed = 0;
    for (final f in folder.listSync().whereType<File>()) {
      final base = f.uri.pathSegments.last;
      final ours = base.endsWith(_suffix) || base.endsWith('$_suffix.part');
      if (!ours || named.contains(base) || f.lastModifiedSync().isAfter(before)) continue;
      f.deleteSync();
      removed++;
    }
    return removed;
  }
}
