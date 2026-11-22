// P05a T7 (ADR-0072; p05-plan.md C3, OQ-DATA-2): images and files in a
// document. A file is copied into the profile's own folder, encrypted; the
// body names it by its hash (AttachmentRef). The reference syncs, the file
// does not (C3): on another device, or for another member, it is "on another
// device". A missing or damaged file never breaks the document.
import 'dart:typed_data';

import 'package:domain/domain.dart' show AttachmentRef;

/// The largest file a document takes (it is held in memory to be encrypted).
const maxAttachmentBytes = 25 * 1024 * 1024;

enum AttachmentProblem {
  /// Larger than [maxAttachmentBytes].
  tooLarge,

  /// No name, or a name longer than the body allows.
  badName,

  /// The file could not be written (storage full, no key).
  failed,
}

class AttachmentAdded {
  const AttachmentAdded.ok(AttachmentRef this.ref) : problem = null;
  const AttachmentAdded.failed(AttachmentProblem this.problem) : ref = null;

  /// What the body keeps; null when [problem] is set.
  final AttachmentRef? ref;
  final AttachmentProblem? problem;
}

enum AttachmentAvailability {
  /// On this device, readable.
  here,

  /// Not on this device: added on another one, or by another member (C3).
  elsewhere,

  /// On this device but cannot be read: changed on disk, or its key is gone.
  unreadable,
}

class AttachmentContent {
  const AttachmentContent(this.availability, [this.bytes]);
  final AttachmentAvailability availability;

  /// The file's bytes when [availability] is here.
  final Uint8List? bytes;
}

/// P05b (ADR-0076; document-knowledge.md §6, `FileViewer`): how LifeFlow
/// shows a file of a document. Anything else stays a file with "Save a copy"
/// (a DOCX too, D1).
enum FileView {
  /// Shown as the picture itself.
  picture,

  /// Opens in the PDF page.
  pdf,

  /// Not shown inside the app.
  none,
}

/// How [file] is shown: by its media type, or by its name when the type is
/// a generic one (some pickers give `application/octet-stream`).
FileView fileViewOf(AttachmentRef file) {
  if (file.isImage) return FileView.picture;
  final mime = file.mime.toLowerCase();
  if (mime == 'application/pdf') return FileView.pdf;
  final generic = mime.isEmpty || mime == 'application/octet-stream';
  if (generic && file.name.toLowerCase().endsWith('.pdf')) return FileView.pdf;
  return FileView.none;
}

abstract interface class AttachmentService {
  /// Keeps [bytes] in this profile, encrypted, and gives the reference for
  /// the body. The same file twice is kept once.
  Future<AttachmentAdded> add(Uint8List bytes, {required String name, required String mime});

  /// Whether the file of [hash] is on this device (no decryption).
  Future<AttachmentAvailability> availability(String hash);

  /// The file of [hash], authenticated (a changed file is unreadable).
  Future<AttachmentContent> open(String hash);

  /// Removes the files no document and no revision of this profile names
  /// any more, once older than [grace] (a file just picked and not saved yet
  /// stays). Returns how many were removed.
  Future<int> sweep({Duration grace = const Duration(days: 1)});
}
