import 'dart:convert';
import 'dart:typed_data';

import 'package:application/application.dart';
import 'package:file_picker/file_picker.dart';
import 'package:infrastructure/infrastructure.dart' show maxExportBytes;

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
  Future<String?> pickText() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a LifeFlow export');
    if (file == null) return null; // cancelled

    // Check the size BEFORE reading it into memory (SR-14).
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > maxExportBytes) throw const FileTooLarge();

    final bytes = await file.readAsBytes();
    if (bytes.length > maxExportBytes) throw const FileTooLarge();
    // Not valid UTF-8 just means "not an export"; validation rejects it.
    return utf8.decode(bytes, allowMalformed: true);
  }
}
