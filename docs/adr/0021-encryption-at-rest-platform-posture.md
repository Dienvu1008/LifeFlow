# ADR-0021: Encryption-at-rest platform posture (Android encrypted, Windows MVP plain + tracked exception)

- Status: Accepted (owner decision, 2026-11-04, P01 task T5). **Amended by [ADR-0022](0022-windows-encryption-at-rest.md) (2026-11-06): Windows is now encrypted by default; the plain Windows posture below survives only as an explicit fallback build flag.**
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

## Update — P01 T6b (2026-11-06)
- **Mechanism implemented.** The app links **SQLite3MultipleCiphers on every platform** via the `sqlite3` 3.x build hook (`hooks: user_defines: sqlite3: source: sqlite3mc`). The hook downloads **prebuilt, hash-pinned** binaries (sqlite3 3.5.2 ships `sqlite3mc.x64.windows.dll` and `libsqlite3mc.*.android.so`); nothing is compiled locally, so the S-02 CMake `INSTALL` failure does not occur. Whether a database is encrypted depends only on whether a key is applied, so one binary serves both postures: Android applies a random 256-bit key from secure storage (OQ-DATA-1); Windows MVP opens it without a key (plain, tracked exception, unchanged).
- **Detection corrected.** `PRAGMA cipher` is **not** an encryption signal: sqlite3mc reports its configured cipher (`chacha20`) even for an unkeyed, plain file. T5's `activeCipher()` would have reported "encrypted" for a plain DB, which is exactly the silent downgrade this ADR forbids. The startup self-check now reads the **file header** (`fileCipherProbe`); a regression test pins the finding.
- **Upgrade path.** An existing plain DB (from T6a builds) is encrypted in place on Android (`PRAGMA rekey`); the key is persisted before any byte is encrypted, and an interrupted upgrade resumes. A lost key or an encrypted file opened by a plain-policy build is reported and the file is never rewritten or deleted.
- **Verified headless on Windows** with the real sqlite3mc binary: encrypted file is not a plain SQLite file, contains no plaintext, rejects a wrong key, and **FTS5 + MATCH work under encryption** (OQ-V10 resolved for the encrypted build). `flutter build windows` with sqlite3mc succeeds.
- **Consequence for option A.** A Windows-clean encrypted path now appears to exist: enabling Windows encryption is a one-line policy change (`atRestPolicyFor`). Per this ADR it is **not** switched on here; it needs the owner's decision, Windows device verification, and a follow-up ADR making A primary with B as the controlled fallback.

## Follow-ups
- A (stretch): time-boxed Windows-clean encryption attempt after B merges. Outcome recorded in spike-results.md (S-02 final). **T6b: the mechanism builds and passes headless on Windows; awaiting owner decision.**
- Revisit Windows encryption each time the sqlite3/drift build-hook toolchain is upgraded.
- OQ-DATA-3 (key/data backup) remains non-blocking for P01.
