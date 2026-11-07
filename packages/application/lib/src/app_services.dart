// P01 T6a: the surface the UI is allowed to see (ADR-0019, FF-ARCH-04).
// `ui` depends on these read models and service ports only — never on
// infrastructure, Drift or domain internals. Implementations live in
// infrastructure and are wired in the app composition root.
import 'command.dart';

/// Read model of a task for list display. Plain data, no behavior.
class TaskView {
  const TaskView({
    required this.id,
    required this.title,
    required this.status,
    required this.parentId,
    required this.createdAt,
  });

  final String id;
  final String title;

  /// inbox | todo | inProgress | done | cancelled
  final String status;
  final String? parentId;
  final DateTime createdAt;

  bool get isDone => status == 'done';
}

/// Read side for tasks, scoped to the ACTIVE profile's workspace
/// (LF-INV-ID-002). Excludes trashed tasks (LF-INV-TASK-011).
abstract interface class TaskQueries {
  /// Emits the current list, then again after every change. Re-subscribe after
  /// a profile switch so the stream follows the new active workspace.
  Stream<List<TaskView>> watchTasks();
}

/// Write side for tasks. Every call goes through the command gateway
/// (ADR-0011): authorize, version-check, atomic set. Failures are returned,
/// never thrown, so the UI can show a message.
abstract interface class TaskService {
  Future<CommandResult> create(String title, {String? parentId});
  Future<CommandResult> rename(String id, String title);

  /// [withDescendants] true = CompleteTaskWithDescendants, false =
  /// CompleteTaskOnly (open subtasks are recorded in the audit, OQ-R3).
  Future<CommandResult> complete(String id, {required bool withDescendants});
  Future<CommandResult> trash(String id);
}

/// Read model of a local profile for the profile chooser.
class ProfileView {
  const ProfileView({
    required this.id,
    required this.displayName,
    required this.isActive,
    required this.isBound,
    this.provider,
    this.isSignedOut = false,
  });

  final String id;
  final String displayName;
  final bool isActive;
  final bool isBound;

  /// ADR-0024: bound to an account that signed out; opens only after that
  /// account signs in again.
  final bool isSignedOut;
  bool get isLocked => isBound && isSignedOut;

  /// Auth provider name when bound ('email' | 'github'); never a token.
  final String? provider;
}

/// Profile chooser operations (OQ-S7: sign-out lands here, data stays).
abstract interface class ProfileService {
  Future<ProfileView?> active();
  Future<List<ProfileView>> list();
  Future<CommandResult> switchTo(String profileId);
}

/// A finished export, ready to be saved by the platform file dialog
/// (UC-20a, ADR-0025).
class ExportFile {
  const ExportFile({
    required this.suggestedName,
    required this.contents,
    required this.taskCount,
  });

  /// e.g. `lifeflow-guest-2026-11-07.lifeflow.json`
  final String suggestedName;

  /// The decrypted export text (UTF-8 JSON). Handle with care: it holds the
  /// profile's data in the clear.
  final String contents;
  final int taskCount;
}

enum RestoreRejection {
  /// Not a LifeFlow export, truncated, or not valid JSON.
  notAnExport,

  /// Made by a newer LifeFlow (AC-20a.2): update the app first.
  newerVersion,

  /// The checksum does not match: the file was changed or damaged (SR-14).
  corrupted,

  /// Passed the checksum but the contents are inconsistent or unsafe.
  invalidContents,

  /// Too large to be a LifeFlow export.
  tooLarge,

  /// Could not write the restored profile.
  storage,
}

/// Result of restoring an export. Nothing is written unless it is [Restored].
sealed class RestoreOutcome {
  const RestoreOutcome();
}

class Restored extends RestoreOutcome {
  const Restored(this.profile, {required this.asCopy, required this.taskCount});

  /// The new profile (not activated; the user can switch to it).
  final ProfileView profile;

  /// True when the profile already exists on this device, so the data was
  /// restored under new profile/workspace ids instead of replacing anything.
  final bool asCopy;
  final int taskCount;
}

class RestoreRejected extends RestoreOutcome {
  const RestoreRejected(this.kind, this.message);
  final RestoreRejection kind;

  /// Safe to show to the user; never includes file contents.
  final String message;
}

/// Export / restore of one profile's data (UC-20a, FR-DATA-01/02, ADR-0025).
abstract interface class DataTransferService {
  /// Exports the ACTIVE profile: a versioned, checksummed, decrypted file with
  /// every user-owned entity, tombstones and audit (LF-INV-SEC-010). Contains
  /// no keys or tokens (LF-INV-SEC-001).
  Future<ExportFile> exportActiveProfile();

  /// Validates [text] (schema, version, checksum, consistency; SR-14) and, only
  /// if it passes, restores it as a new profile in one atomic step. Never
  /// replaces an existing profile.
  Future<RestoreOutcome> restore(String text);
}

/// Platform file dialogs, kept behind a port so `ui` stays free of plugins.
abstract interface class FileGateway {
  /// Lets the user choose where to save [text]. Returns false if cancelled.
  Future<bool> saveText(String suggestedName, String text);

  /// Lets the user choose a LifeFlow export and returns its text, or null if
  /// cancelled. Throws [FileTooLarge] instead of reading a huge file.
  Future<String?> pickText();
}

class FileTooLarge implements Exception {
  const FileTooLarge();
}

/// Result of the startup at-rest encryption self-check, as the UI needs it
/// (ADR-0021). Mirrors infrastructure's AtRestStatus without exposing it.
class StorageNotice {
  const StorageNotice({
    required this.atRestEncrypted,
    required this.trackedException,
    this.message,
  });

  final bool atRestEncrypted;

  /// True for the sanctioned Windows-MVP plain-DB exception.
  final bool trackedException;

  /// Human-readable warning; null when nothing needs showing.
  final String? message;

  bool get needsAttention => !atRestEncrypted && message != null;
}
