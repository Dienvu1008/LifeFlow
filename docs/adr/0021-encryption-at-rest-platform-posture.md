# ADR-0021: Encryption-at-rest platform posture (Android encrypted, Windows MVP plain + tracked exception)

- Status: Accepted (owner decision, 2026-11-04, P01 task T5)
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../spikes/spike-results.md](../spikes/spike-results.md) (S-02), [../data/data-architecture.md](../data/data-architecture.md) §4, [../security/security-requirements.md](../security/security-requirements.md) SR-01/03, [../invariants/invariant-catalog.md](../invariants/invariant-catalog.md) LF-INV-SEC-011, risk R-ENCRYPTION-WINDOWS

## Context
The MVP design requires the local database to be encrypted at rest with SQLite3MultipleCiphers and to assert `PRAGMA cipher` at startup (SR-01, LF-INV-SEC-011). Spike S-02 found that **neither** encryption mechanism builds cleanly on Flutter **Windows** within the time-box:
- SQLCipher via `sqlcipher_flutter_libs` needs system OpenSSL (`Could NOT find OpenSSL`).
- SQLite3MultipleCiphers via the `sqlite3` 3.x build hook (`source: sqlite3mc`) fails at the CMake `INSTALL` step (`MSB3073`).

FTS5 + migrations pass on a **plain** build (OQ-V10 resolved for plain). Android encryption (sqlite3mc bundled in the Android build) is expected to work. Encryption-at-rest on Windows was escalated from the spike to this P01 task rather than assumed done.

## Options
A. Retry a Windows-clean encrypted path (matured 3.x sqlite3mc hook) and ship encrypted on both platforms.
B. **Encryption as an injectable executor**: Android encrypted; Windows MVP runs plain as an explicit, tracked exception until a Windows-clean path ships.
C. Accept a system OpenSSL dependency for SQLCipher on every Windows build.

## Decision
**Option B is the baseline.** Encryption is an injectable concern selected per platform:
- **Android**: encrypted executor (SQLite3MultipleCiphers); the app asserts `PRAGMA cipher` at startup (LF-INV-SEC-011 satisfied).
- **Windows (MVP)**: a **plain** local database, shipped as an **explicit, tracked exception** — never a silent downgrade. The startup self-check (`StorageSecurity.evaluate`) emits a warning, records `atRestEncrypted=false` + `trackedException=true` in diagnostics, and the UI surfaces it. FTS5 search works on the plain DB.
- **Revisit trigger**: promote Windows to encrypted when a Windows-clean path is confirmed (a matured 3.x sqlite3mc build hook, or option A below succeeding).

**Option A is a time-boxed stretch (1–2 person-days), attempted AFTER B is merged to `main`, and never blocks B.** If A fails it stays Open and B stands. If A passes, a follow-up ADR makes A primary and keeps B as a controlled fallback (B is not reverted immediately).

**Option C is rejected** for the MVP: requiring OpenSSL on every Windows build adds toolchain burden disproportionate to the MVP. Reconsider only if a compliance requirement mandates Windows at-rest encryption at MVP.

## Consequences
- Pro: unblocks the P01 exit gate with encryption verified on at least one platform (Android) and a non-silent, documented exception on Windows.
- Pro: the executor is injected at the app-wiring layer, so promoting Windows to encrypted later is a wiring change, not a schema or domain change.
- Con: on Windows MVP the database is readable at rest if the device/user account is compromised. Mitigations (security-requirements §1a): recommend OS full-disk encryption (BitLocker); warn the user; advise against storing Restricted data on a Windows device until encryption ships.
- Con: Restricted data (health, secrets other than the keys/tokens that already live in secure storage) is **not** encrypted at rest on Windows MVP. Recorded in data-classification §2a. Auth tokens and keys remain in `flutter_secure_storage` regardless (LF-INV-SEC-001), so they are not exposed by the plain DB.
- The exit gate records the Windows posture explicitly; GS-19 (encryption at rest) is verified on Android for P01 and marked as a tracked exception on Windows.

## Follow-ups
- A (stretch): time-boxed Windows-clean encryption attempt after B merges. Outcome recorded in spike-results.md (S-02 final).
- Revisit Windows encryption each time the sqlite3/drift build-hook toolchain is upgraded.
- OQ-DATA-3 (key/data backup) remains non-blocking for P01.
