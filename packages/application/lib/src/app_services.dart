// P01 T6a: the surface the UI is allowed to see (ADR-0019, FF-ARCH-04).
// `ui` depends on these read models and service ports only — never on
// infrastructure, Drift or domain internals. Implementations live in
// infrastructure and are wired in the app composition root.
import 'package:foundation/foundation.dart';

import 'command.dart';
import 'planning.dart';

/// Read model of a task for list display. Plain data, no behavior.
class TaskView {
  const TaskView({
    required this.id,
    required this.title,
    required this.status,
    required this.parentId,
    required this.createdAt,
    this.schedule,
  });

  final String id;
  final String title;

  /// inbox | todo | inProgress | done | cancelled
  final String status;
  final String? parentId;
  final DateTime createdAt;

  /// The task's schedule, if it has one (P02 T6a).
  final TaskScheduleInput? schedule;

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

  /// Undoes a completion: a done (or cancelled) task becomes open again
  /// (`todo`). Its subtasks are not changed.
  Future<CommandResult> reopen(String id);

  /// [withSubtasks] true = the task and all its subtasks go to the trash;
  /// false = only the task, and its direct subtasks move up one level.
  Future<CommandResult> trash(String id, {bool withSubtasks = false});
}

/// The app's brightness (device setting, P03 UX U1).
enum ThemePreference { system, light, dark }

/// What happens to subtasks when their parent is moved to the trash.
enum SubtaskTrashPolicy {
  /// Ask each time (default).
  ask,

  /// Trash the subtasks too.
  withSubtasks,

  /// Keep the subtasks; they move up one level.
  keepSubtasks,
}

/// Calendar settings of this device (owner decisions D1–D3).
class PlanningSettings {
  const PlanningSettings({
    this.maxOccurrences = defaultMaxOccurrences,
    this.maxWindowDays = defaultMaxWindowDays,
    this.defaultMonthEnd = MonthEndChoice.skip,
    this.firstDayOfWeek = Weekday.monday,
  });

  /// D1: at most this many occurrences per query (clamped to the bounds).
  final int maxOccurrences;

  /// D1: at most this many days per query (clamped to the bounds).
  final int maxWindowDays;

  /// D2: month-end rule for NEW repeats (each repeat stores its own).
  final MonthEndChoice defaultMonthEnd;

  /// D3: first day of the week: for the week view, and the default week
  /// start of new repeats (each repeat stores its own).
  final Weekday firstDayOfWeek;

  static const defaultMaxOccurrences = 1000;
  static const defaultMaxWindowDays = 400;
  static const occurrencesRange = (min: 100, max: 5000);
  static const windowDaysRange = (min: 31, max: 1100);

  PlanningSettings copyWith({
    int? maxOccurrences,
    int? maxWindowDays,
    MonthEndChoice? defaultMonthEnd,
    Weekday? firstDayOfWeek,
  }) =>
      PlanningSettings(
        maxOccurrences: maxOccurrences ?? this.maxOccurrences,
        maxWindowDays: maxWindowDays ?? this.maxWindowDays,
        defaultMonthEnd: defaultMonthEnd ?? this.defaultMonthEnd,
        firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      );

  /// Within the hard bounds, so a query is always bounded (LF-INV-PLAN-010).
  PlanningSettings clamped() => copyWith(
        maxOccurrences: maxOccurrences.clamp(occurrencesRange.min, occurrencesRange.max),
        maxWindowDays: maxWindowDays.clamp(windowDaysRange.min, windowDaysRange.max),
      );

  @override
  bool operator ==(Object o) =>
      o is PlanningSettings &&
      o.maxOccurrences == maxOccurrences &&
      o.maxWindowDays == maxWindowDays &&
      o.defaultMonthEnd == defaultMonthEnd &&
      o.firstDayOfWeek == firstDayOfWeek;
  @override
  int get hashCode => Object.hash(maxOccurrences, maxWindowDays, defaultMonthEnd, firstDayOfWeek);
}

/// App settings of this device (not profile data, not synced, not exported).
abstract interface class SettingsService {
  Future<SubtaskTrashPolicy> subtaskTrashPolicy();
  Future<void> setSubtaskTrashPolicy(SubtaskTrashPolicy policy);

  /// P03 UX U1: light, dark, or as the system (default).
  Future<ThemePreference> themePreference();
  Future<void> setThemePreference(ThemePreference preference);
  Future<PlanningSettings> planningSettings();

  /// Stores [settings] after clamping them to the bounds.
  Future<void> setPlanningSettings(PlanningSettings settings);
}

/// The IANA time zones this build knows, for a zone picker.
abstract interface class ZoneCatalog {
  /// All zone names, sorted.
  List<String> zoneNames();
  bool isKnown(String zone);
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

  /// Deletes a profile that is NOT open, with all its data, from this device.
  /// Cannot be undone. The open profile is refused (switch first).
  Future<CommandResult> delete(String profileId);
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

  /// Could not write the restored data.
  storage,

  /// The file is valid but cannot be restored here as asked (for example it
  /// belongs to another profile on this device, or no choice was given).
  notApplicable,
}

/// How the records of the file and of the active profile compare
/// (tasks and task lists, matched by id). Records deleted on one side and
/// absent on the other are not counted: they are invisible to the user.
class RestoreDiff {
  const RestoreDiff({
    required this.onlyInFile,
    required this.onlyOnDevice,
    required this.differing,
    required this.newerInFile,
  });

  final int onlyInFile;
  final int onlyOnDevice;

  /// Same id on both sides, different content.
  final int differing;

  /// Of [differing]: the file's version is newer (updatedAt, then version).
  final int newerInFile;

  bool get isIdentical => onlyInFile == 0 && onlyOnDevice == 0 && differing == 0;
}

/// What restoring a file would do, computed WITHOUT writing anything.
sealed class RestorePreview {
  const RestorePreview();
}

/// The file's profile is not on this device: it is restored as a new profile
/// with its original ids.
class RestoreAsNewProfile extends RestorePreview {
  const RestoreAsNewProfile({required this.displayName, required this.taskCount});
  final String displayName;
  final int taskCount;
}

/// The file is the ACTIVE profile and nothing differs: nothing to restore.
class RestoreIdentical extends RestorePreview {
  const RestoreIdentical();
}

/// The file is the ACTIVE profile and differs; the user picks a
/// [RestoreChoice].
class RestoreDifferent extends RestorePreview {
  const RestoreDifferent(this.diff);
  final RestoreDiff diff;
}

/// The file belongs to another profile on this device. Restore it from that
/// profile (after signing in, when [locked]).
class RestoreOtherProfile extends RestorePreview {
  const RestoreOtherProfile({required this.displayName, required this.locked});
  final String displayName;
  final bool locked;
}

enum RestoreMode {
  /// The profile becomes exactly the file. Records only on this device are
  /// moved to the trash (tombstones), never hard-deleted.
  overwrite,

  /// Keep this device's data and take from the file what the options allow.
  merge,
}

/// The user's decision for a [RestoreDifferent] file.
class RestoreChoice {
  const RestoreChoice.overwrite()
      : mode = RestoreMode.overwrite,
        takeNewer = false,
        addMissing = false,
        keepDeviceParents = false;
  const RestoreChoice.merge({
    required this.takeNewer,
    required this.addMissing,
    this.keepDeviceParents = false,
  }) : mode = RestoreMode.merge;

  final RestoreMode mode;

  /// Merge (a): same id on both sides -> take the newer one.
  final bool takeNewer;

  /// Merge (b): add records that exist only in the file.
  final bool addMissing;

  /// When the merge would break the task hierarchy: keep this device's parent
  /// for those tasks (a task new from the file becomes top-level).
  final bool keepDeviceParents;

  RestoreChoice withDeviceParents() => mode == RestoreMode.overwrite
      ? this
      : RestoreChoice.merge(
          takeNewer: takeNewer, addMissing: addMissing, keepDeviceParents: true);
}

/// Result of restoring. Nothing is written unless it is [Restored] or
/// [RestoredInto].
sealed class RestoreOutcome {
  const RestoreOutcome();
}

/// The file was restored as a new profile (not activated).
class Restored extends RestoreOutcome {
  const Restored(this.profile, {required this.taskCount});
  final ProfileView profile;
  final int taskCount;
}

/// The file was restored INTO the active profile.
class RestoredInto extends RestoreOutcome {
  const RestoredInto({
    required this.added,
    required this.updated,
    required this.removed,
    required this.undoAvailable,
  });
  final int added;
  final int updated;

  /// Moved to the trash by an overwrite.
  final int removed;

  /// The state before the restore is kept and can be brought back.
  final bool undoAvailable;

  bool get changedNothing => added == 0 && updated == 0 && removed == 0;
}

/// The merge would leave tasks in a cycle, under a missing parent or list, or
/// too deep. Nothing was written. Retry with
/// [RestoreChoice.withDeviceParents], or cancel.
class RestoreHierarchyConflict extends RestoreOutcome {
  const RestoreHierarchyConflict(this.taskTitles);
  final List<String> taskTitles;
}

class RestoreRejected extends RestoreOutcome implements RestorePreview {
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

  /// Validates [text] (schema, version, checksum, consistency; SR-14) and says
  /// what a restore would do. Writes nothing.
  Future<RestorePreview> inspect(String text);

  /// Restores [text]. A profile that is not on this device is created with its
  /// original ids ([choice] is ignored). The active profile needs a [choice];
  /// the change is one atomic command, audited, and can be undone.
  Future<RestoreOutcome> restore(String text, {RestoreChoice? choice});

  /// Whether the active profile keeps a pre-restore state to go back to.
  Future<bool> canUndoRestore();

  /// Brings the active profile back to the state before the last restore.
  /// Changes made after that restore are moved to the trash or reverted.
  Future<RestoreOutcome> undoLastRestore();
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
