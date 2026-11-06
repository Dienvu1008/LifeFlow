// P01 T5 — Encryption-at-rest decision gate (ADR-0021, R-ENCRYPTION-WINDOWS).
//
// Baseline (option B): encryption is an injectable concern. Android gets an
// encrypted executor (SQLite3MultipleCiphers) and the app asserts `PRAGMA
// cipher` at startup (LF-INV-SEC-011). Windows ships on a PLAIN local DB for
// the MVP as an explicit, TRACKED exception — never a silent downgrade: the
// startup self-check emits a warning, records it in diagnostics, and exposes
// an `atRestEncrypted=false` flag so the exit gate and UI can surface it.
//
// This module is pure Dart (no native build) so the warning/flag logic is unit
// testable headless. The real encrypted executor + cipher probe live at the
// app-wiring layer (T6) and feed this via [StorageSecurity.evaluate].

/// Platforms the MVP ships to. Used to decide the expected at-rest posture.
enum StoragePlatform { android, windows, other }

/// The outcome of the at-rest encryption self-check, run once at startup.
/// Non-silent: when the DB is not encrypted on a platform where encryption is
/// the policy, [warning] is set and [encrypted] is false.
class AtRestStatus {
  const AtRestStatus({
    required this.platform,
    required this.encrypted,
    required this.cipher,
    required this.warning,
    required this.isTrackedException,
  });

  /// True when the open database is confirmed encrypted (cipher probe present).
  final bool encrypted;

  /// The cipher reported by `PRAGMA cipher` (e.g. 'sqlite3mc'/'sqlcipher'),
  /// or null when the DB is plain.
  final String? cipher;

  final StoragePlatform platform;

  /// A human-readable warning when running unencrypted where encryption is the
  /// policy. Null when encrypted (or when plain is the accepted posture).
  final String? warning;

  /// True when this is the sanctioned Windows-MVP plain-DB exception
  /// (ADR-0021), as opposed to an unexpected failure to encrypt.
  final bool isTrackedException;

  bool get hasWarning => warning != null;

  /// Machine-readable line for the diagnostic bundle (never contains secrets).
  Map<String, Object?> toDiagnostics() => {
        'atRestEncrypted': encrypted,
        'cipher': cipher,
        'platform': platform.name,
        'trackedException': isTrackedException,
        if (warning != null) 'warning': warning,
      };
}

/// Probes whether an open database is encrypted. The app-wiring layer backs
/// this with `SELECT cipher FROM pragma_cipher` (or `PRAGMA cipher`) on the
/// real NativeDatabase; tests provide a deterministic fake.
typedef CipherProbe = Future<String?> Function();

/// Emits a non-fatal warning somewhere durable (structured local log +
/// diagnostics). Must NOT include any secret (LF-INV-SEC-001 / SR-08).
typedef WarningSink = void Function(String message);

/// Runs the at-rest self-check at startup and enforces the at-rest policy
/// (ADR-0021, ADR-0022).
class StorageSecurity {
  const StorageSecurity({
    required this.platform,
    this.windowsPlainFallback = false,
    this.onWarning,
  });

  final StoragePlatform platform;

  /// ADR-0022: Windows is encrypted by default. A build may opt into the
  /// ADR-0021 plain fallback explicitly; only then is a plain Windows DB the
  /// sanctioned, tracked exception.
  final bool windowsPlainFallback;
  final WarningSink? onWarning;

  bool get _plainIsAcceptedHere =>
      platform == StoragePlatform.windows && windowsPlainFallback;

  /// Evaluate the open database. [probe] returns the active cipher or null.
  ///
  /// - cipher present  -> encrypted, no warning (LF-INV-SEC-011 satisfied).
  /// - cipher null on Windows -> tracked exception: warn + flag, do not throw.
  /// - cipher null elsewhere  -> policy violation: warn + flag (release builds
  ///   may choose to refuse to run; that decision is left to the caller via
  ///   [AtRestStatus.encrypted]).
  Future<AtRestStatus> evaluate(CipherProbe probe) async {
    final cipher = await probe();
    final encrypted = cipher != null && cipher.isNotEmpty;

    if (encrypted) {
      return AtRestStatus(
        platform: platform,
        encrypted: true,
        cipher: cipher,
        warning: null,
        isTrackedException: false,
      );
    }

    final warning = _plainIsAcceptedHere
        ? 'At-rest encryption is OFF on Windows (plain-database fallback build, '
            'ADR-0021/0022). The local database is NOT encrypted at rest. '
            'Mitigate with OS full-disk encryption (BitLocker) and avoid storing '
            'Restricted data on this device.'
        : 'At-rest encryption is OFF on ${platform.name} but the DB was '
            'expected to be encrypted (LF-INV-SEC-011). This is NOT an accepted '
            'configuration.';

    onWarning?.call(warning);

    return AtRestStatus(
      platform: platform,
      encrypted: false,
      cipher: null,
      warning: warning,
      isTrackedException: _plainIsAcceptedHere,
    );
  }
}
