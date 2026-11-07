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
