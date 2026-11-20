import 'dart:convert';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:file_picker/file_picker.dart';

/// Platform file dialogs for export / restore (UC-20a). The only place that
/// touches the file_picker plugin; `ui` sees the [FileGateway] port.
///
/// The user chooses every location. Nothing is written or read anywhere else,
/// and nothing is uploaded (SR-15).
class FilePickerGateway implements FileGateway {
  const FilePickerGateway();

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save LifeFlow export',
      fileName: suggestedName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'application/json',
    );
    return saved != null;
  }

  @override
  Future<Uint8List?> pickExport({required int maxBytes}) async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a LifeFlow export');
    if (file == null) return null; // cancelled

    // Check the size BEFORE reading it into memory (SR-14).
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > maxBytes) throw const FileTooLarge();

    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw const FileTooLarge();
    // A .json or a .zip export (P05a T9); the reader tells which, and
    // rejects anything else.
    return bytes;
  }

  // P05a T8 (ADR-0073): a file for a document, and a copy of one saved out.
  @override
  Future<PickedFile?> pickFile({required int maxBytes}) async {
    final file = await FilePicker.pickFile(dialogTitle: 'Attach a file');
    if (file == null) return null;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > maxBytes) throw const FileTooLarge();
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) throw const FileTooLarge();
    return PickedFile(name: file.name, mime: mimeOfName(file.name), bytes: bytes);
  }

  @override
  Future<bool> saveBytes(String suggestedName, Uint8List bytes, {String mime = 'application/octet-stream'}) async =>
      await FilePicker.saveFile(fileName: suggestedName, bytes: bytes, mimeType: mime) != null;
}

/// The type of a file by its name's extension, as far as LifeFlow shows it
/// (pictures inline, the rest as a file).
String mimeOfName(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'md' => 'text/markdown',
    'csv' => 'text/csv',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip' => 'application/zip',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'mp4' => 'video/mp4',
    _ => 'application/octet-stream',
  };
}
