// P05a T9 (ADR-0074; p05-plan.md C11): the export as a `.zip` when documents
// have files on this device: the JSON export (as ever, with its checksum)
// and each file beside it, decrypted, named by its hash. An export without
// files stays a plain JSON file, readable as before.
//   lifeflow-export.json        the export (ProfileExport, ≤ 64 MB)
//   attachments/<64 hex>        one file per content (sha256 of the bytes)
// Entries are stored, not compressed (the files are pictures and documents,
// mostly compressed already): reading accepts stored entries only, so a zip
// cannot unpack to more than its own size (no zip bomb). Reading treats the
// zip as untrusted (SR-14): only these names, sizes checked before the bytes
// are read, each file checked against its name.
import 'dart:convert';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:archive/archive.dart';

import 'attachment_store.dart' show attachmentHashOf;
import 'profile_export.dart' show ExportRejected, maxExportBytes;

const exportArchiveJsonName = 'lifeflow-export.json';
const exportArchiveFilesDir = 'attachments/';

/// At most this many files in an export (a document's limit is far above
/// what a person attaches; this only bounds a forged file).
const maxExportArchiveFiles = 20000;

/// Whether [bytes] look like a zip (the local file header's signature).
bool isZipArchive(List<int> bytes) =>
    bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b && bytes[2] == 0x03 && bytes[3] == 0x04;

/// The `.zip` of [json] and [files] (by `sha256:` hash).
Uint8List buildExportArchive(String json, Map<String, Uint8List> files) {
  final text = utf8.encode(json);
  final a = Archive()..addFile(ArchiveFile.noCompress(exportArchiveJsonName, text.length, text));
  for (final hash in files.keys.toList()..sort()) {
    final b = files[hash]!;
    a.addFile(ArchiveFile.noCompress('$exportArchiveFilesDir${hash.substring('sha256:'.length)}', b.length, b));
  }
  return ZipEncoder().encodeBytes(a);
}

/// An export file as picked: its JSON text and, for a `.zip`, its files by
/// `sha256:` hash. Throws [ExportRejected] for a zip that is not an export.
({String text, Map<String, Uint8List> files}) readExportFile(Uint8List bytes) {
  if (!isZipArchive(bytes)) {
    // Not valid UTF-8 just means "not an export"; the reader says so.
    return (text: utf8.decode(bytes, allowMalformed: true), files: const {});
  }
  const notAnExport = ExportRejected(RestoreRejection.notAnExport, 'This is not a LifeFlow export file.');
  const damaged = ExportRejected(RestoreRejection.corrupted, 'This file was changed or damaged and cannot be restored.');
  final Archive a;
  try {
    a = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw notAnExport;
  }
  String? text;
  final files = <String, Uint8List>{};
  final name = RegExp('^${RegExp.escape(exportArchiveFilesDir)}([0-9a-f]{64})\$');
  for (final f in a.files) {
    if (!f.isFile) continue;
    if (f.compression != null && f.compression != CompressionType.none) throw notAnExport;
    if (f.name == exportArchiveJsonName) {
      if (text != null || f.size > maxExportBytes) throw notAnExport;
      final raw = _read(f, maxExportBytes, damaged);
      text = utf8.decode(raw, allowMalformed: true);
      continue;
    }
    final m = name.firstMatch(f.name);
    if (m == null) continue; // anything else in the zip is not ours: ignored
    if (files.length >= maxExportArchiveFiles || f.size > maxAttachmentBytes) throw notAnExport;
    final raw = _read(f, maxAttachmentBytes, damaged);
    final hash = 'sha256:${m.group(1)}';
    if (attachmentHashOf(raw) != hash) throw damaged;
    files[hash] = raw;
  }
  if (text == null) throw notAnExport;
  return (text: text, files: files);
}

/// The entry's bytes, never more than [max] (the declared size may lie).
Uint8List _read(ArchiveFile f, int max, ExportRejected damaged) {
  final Uint8List? raw;
  try {
    raw = f.readBytes();
  } catch (_) {
    throw damaged;
  }
  if (raw == null || raw.length > max || raw.length != f.size) throw damaged;
  return raw;
}
