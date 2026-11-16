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
      {this.pushed = 0, this.pulled = 0, this.merged = 0, this.reviews = 0, this.failedRecords = 0, this.detail = ''});
  final SyncOutcome outcome;
  final int pushed;
  final int pulled;
  final int merged;
  final int reviews;

  /// Records the server refused; set aside, the rest still synced.
  final int failedRecords;

  /// For logs; never content or a key.
  final String detail;
  @override
  String toString() =>
      'SyncReport(${outcome.name}, pushed $pushed, pulled $pulled, merged $merged, reviews $reviews, failed $failedRecords) $detail';
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
  });
  final bool on;
  final SyncOutcome? lastResult;
  final DateTime? lastSyncAt;

  /// Changes not on the server yet.
  final int pending;

  /// Open "Changes to review" items.
  final int reviews;
  final bool canUndoJoin;
}

abstract interface class SyncService {
  Future<SyncStatus> status();

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
