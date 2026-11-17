// P04 T3/T4 (ADR-0056, ADR-0057; p04-plan.md D4, D5, D9–D11, D15): sync of a
// profile with the signed-in account, as the app sees it. The UI only talks
// to this port (FF-ARCH-04); keys, sealing and the server stay behind it.
import 'app_services.dart' show ExportFile;

/// How a sync ended.
enum SyncOutcome {
  /// Everything is on the server and this device has everything.
  upToDate,

  /// No connection, a timeout, or the server is paused or down.
  offline,

  /// Not signed in any more.
  signedOut,

  /// The server says the workspace is not this account's.
  notYours,

  /// The server has a change this app version cannot read: update LifeFlow
  /// (D10). Pushing still works.
  updateNeeded,

  /// The workspace was set up again with a new key on another device: this
  /// device must turn sync off and join again (ADR-0057).
  keyChanged,

  /// The workspace is no longer on the server ("Delete my data from the
  /// server" on another device).
  workspaceGone,

  /// Sync is not on for this profile.
  notOn,

  /// Something else; see [SyncReport.detail].
  failed,
}

class SyncReport {
  SyncReport(this.outcome,
      {this.pushed = 0,
      this.pulled = 0,
      this.merged = 0,
      this.reviews = 0,
      this.failedRecords = 0,
      this.withheld = 0,
      this.notTaken = 0,
      this.detail = ''});
  final SyncOutcome outcome;
  final int pushed;
  final int pulled;
  final int merged;
  final int reviews;

  /// Records the server refused; set aside, the rest still synced.
  final int failedRecords;

  /// Records kept on the device by their classification (Restricted data,
  /// ADR-0059); never sealed, never sent.
  final int withheld;

  /// P04b T11: changes pulled into a shared space and not taken: a kind
  /// that stays personal (B2), or a record that is not the space's.
  final int notTaken;

  /// For logs; never content or a key.
  final String detail;
  @override
  String toString() =>
      'SyncReport(${outcome.name}, pushed $pushed, pulled $pulled, merged $merged, reviews $reviews, failed $failedRecords, withheld $withheld${notTaken > 0 ? ', not taken $notTaken' : ''}) $detail';
}

/// What turning sync on will do for this profile.
sealed class SyncStart {
  const SyncStart();
}

/// The account has no synced workspace yet: this device makes it.
class SyncStartFresh extends SyncStart {
  const SyncStartFresh();
}

/// The account has one: this device joins it, unlocking with [unlock].
class SyncStartJoin extends SyncStart {
  const SyncStartJoin(this.unlock);
  final SyncUnlock unlock;
}

/// Sync is already on for this profile.
class SyncStartAlreadyOn extends SyncStart {
  const SyncStartAlreadyOn();
}

enum SyncUnlock { recoveryKey, passphrase }

/// D5: what a joining device does with what it already has.
enum JoinChoice {
  /// Its records keep their ids and move into the account's workspace (the
  /// default).
  mergeThisDevice,

  /// Its data is saved to an export file, then the account's data replaces it.
  useAccountOnly,
}

/// A new recovery key to show (24 words and the QR text), and the two word
/// positions (1-based) the user types back to confirm it.
class RecoveryKeyOffer {
  const RecoveryKeyOffer({required this.words, required this.qrText, required this.check});
  final List<String> words;
  final String qrText;
  final (int, int) check;
}

enum SyncSetupProblem {
  offline,
  signedOut,
  notYours,
  recoveryKeyNotConfirmed,
  recoveryKeyInvalid,
  wrongRecoveryKey,
  wrongPassphrase,
  passphraseTooShort,
  passphraseTooCommon,
  alreadyOn,
  notOn,
  nothingToUndo,

  /// The review item is closed already, or its record is gone.
  reviewGone,
  failed,
}

class SyncSetupResult {
  const SyncSetupResult({this.problem, this.message = '', this.firstSync, this.export});
  const SyncSetupResult.failed(SyncSetupProblem p, [String message = '']) : this(problem: p, message: message);
  final SyncSetupProblem? problem;

  /// Safe to show (for example which recovery-key word is wrong).
  final String message;

  /// The first sync after turning sync on or joining, when it ran.
  final SyncReport? firstSync;

  /// D5 "use the account's data": this device's data as it was, exported
  /// before it was replaced, for the app to save as a file (it is also kept
  /// in the store until the join is undone or sync is turned off).
  final ExportFile? export;
  bool get ok => problem == null;
}

class SyncStatus {
  const SyncStatus({
    required this.on,
    this.lastResult,
    this.lastSyncAt,
    this.pending = 0,
    this.reviews = 0,
    this.canUndoJoin = false,
    this.syncing = false,
  });
  final bool on;
  final SyncOutcome? lastResult;
  final DateTime? lastSyncAt;

  /// Changes not on the server yet.
  final int pending;

  /// Open "Changes to review" items.
  final int reviews;
  final bool canUndoJoin;

  /// A sync is running now.
  final bool syncing;
}

/// D8: when this device syncs (a setting of the device, not synced).
enum SyncWhen {
  /// On start, on return to the app, a few seconds after a change and every
  /// few minutes while open (the default).
  automatic,

  /// Only when the user taps "Sync now".
  onlySyncNow,
}

enum SyncReviewKind {
  /// Both devices changed it; the newer change was kept.
  changedOnBoth,

  /// Deleted on one device, edited on the other: it is in the trash with the
  /// edits (D7); restoring it from the trash brings it back.
  deletedAndEdited,

  /// A record from the server that could not be opened.
  unreadable,
}

/// One "Changes to review" item (D9): what was kept and what gave way.
class SyncReviewView {
  const SyncReviewView({
    required this.id,
    required this.recordKind,
    required this.recordId,
    required this.reason,
    required this.field,
    this.title,
    this.kept = '',
    this.other = '',
    this.canTakeOther = false,
    required this.createdAt,
  });
  final String id;

  /// The record kind ('task', 'schedule', 'workspaceSettings', ...).
  final String recordKind;
  final String recordId;
  final SyncReviewKind reason;

  /// The field that differed; '*' for the whole value.
  final String field;

  /// The record's title, or the title of the task or event it belongs to.
  final String? title;

  /// The kept and the other value, as text to show.
  final String kept;
  final String other;

  /// Whether "Take the other" is possible (not for a delete, nor when the
  /// record is gone).
  final bool canTakeOther;
  final DateTime createdAt;
}

/// P04b T11 (ADR-0063): what the automatic sync needs of a sync: the
/// profile's own (SyncService) and the shown shared space's (every minute).
abstract interface class SyncRunner {
  Future<SyncStatus> status();

  /// [status] now and after every change of it.
  Stream<SyncStatus> watchStatus();

  /// Syncs now; while a sync runs, waits for it instead of starting another.
  Future<SyncReport> syncNow();
}

abstract interface class SyncService implements SyncRunner {
  @override
  Future<SyncStatus> status();

  /// [status] now and after every change of it (a sync starting or ending,
  /// an edit waiting to be sent, a review item).
  @override
  Stream<SyncStatus> watchStatus();

  /// The open "Changes to review" items, newest first.
  Future<List<SyncReviewView>> reviews();

  /// Closes a review item: keeps what was kept, or puts the other value back
  /// as a new change ([takeOther]), which then syncs.
  Future<SyncSetupResult> resolveReview(String id, {required bool takeOther});

  /// What turning sync on will do; a [RemoteFailure]-like problem comes back
  /// as an exception of type SyncSetupException.
  Future<SyncStart> prepare();

  /// The first device: a new recovery key to show. Nothing is kept yet.
  Future<RecoveryKeyOffer> offerRecoveryKey();

  /// Confirms the offered key with the two words, then turns sync on.
  Future<SyncSetupResult> startWithRecoveryKey((String, String) answers);

  /// The first device, with a passphrase instead (D15).
  Future<SyncSetupResult> startWithPassphrase(String passphrase);

  /// Another device: unlock with the recovery key (typed words or the QR
  /// text) or the passphrase, then join (D5).
  Future<SyncSetupResult> join(JoinChoice choice, {String? recoveryKey, String? passphrase});

  /// Back to how this device was before it joined; sync is off again. What
  /// the join already uploaded stays on the server.
  Future<SyncSetupResult> undoJoin();

  /// Syncs now; while a sync runs, waits for it instead of starting another.
  @override
  Future<SyncReport> syncNow();

  /// Stops syncing this profile here; its data stays on the device (D11).
  Future<SyncSetupResult> turnOff();

  /// "Delete my data from the server" (D11), then sync is off; this
  /// device's data stays.
  Future<SyncSetupResult> deleteServerData();
}

/// prepare() could not reach the server or the account.
class SyncSetupException implements Exception {
  const SyncSetupException(this.problem);
  final SyncSetupProblem problem;
  @override
  String toString() => 'SyncSetupException(${problem.name})';
}
