# ADR-0022: Encrypt at rest on Windows too (ADR-0021 option A becomes primary)

- Status: Accepted (owner decision, 2026-11-06, P01 task T5a)
- Date: 2026-11-06
- Deciders: Project owner
- Amends: [ADR-0021](0021-encryption-at-rest-platform-posture.md) (the Windows MVP plain posture becomes a controlled fallback)
- Evidence: ADR-0021 "Update — P01 T6b"; [../spikes/spike-results.md](../spikes/spike-results.md) (S-02 follow-up T6b); `packages/infrastructure/test/local_store_test.dart`; owner Windows device run (T5a gate)

## Context
ADR-0021 shipped Windows on a plain local database as a tracked exception because, in spike S-02, neither encryption mechanism built on Flutter Windows. In T6b the app moved to `sqlite3` 3.5.2, whose build hook downloads **prebuilt, hash-pinned SQLite3MultipleCiphers** binaries (including `sqlite3mc.x64.windows.dll`). Nothing is compiled locally, so the S-02 CMake failure no longer occurs. T6b verified on Windows: encryption works, a wrong key is rejected, FTS5 works under encryption, and the app builds and runs. ADR-0021 said that if option A passed, a follow-up ADR would make A primary and keep B as a controlled fallback.

## Decision
- **Every platform is encrypted at rest by default**, Windows included: a random 256-bit key generated per install, stored in platform secure storage via `flutter_secure_storage` (OQ-DATA-1), applied with `PRAGMA key`. LF-INV-SEC-011 now holds on Windows. *Correction (T6c):* on Windows, `flutter_secure_storage_windows` 4.x does **not** use Credential Manager; it keeps a **DPAPI-protected file** (`flutter_secure_storage.dat`) in the app support directory, bound to the current Windows user. This protects the keys against another user or an offline copy of the disk, but not against code running as the same user.
- **Upgrade:** an existing plain Windows database (T6a/T6b builds) is encrypted in place on first launch (`PRAGMA rekey`), using the same resumable, non-destructive path already verified on Android.
- **Controlled fallback (ADR-0021 option B kept, not reverted):** a build made with `--dart-define=LIFEFLOW_WINDOWS_PLAIN_DB=true` opens a plain Windows database and shows it as the sanctioned tracked exception, as before. Without that flag, a plain database on Windows is a **policy violation** and is reported as such, like on Android. The fallback is meant only for a fresh install: it never downgrades an encrypted database; it reports the situation instead.
- Detection stays header-based (SR-01e); `PRAGMA cipher` is not used.

## Consequences
- Pro: Restricted data is encrypted at rest on both MVP platforms; the Windows mitigations in security-requirements §1a and the Windows note in data-classification §2a now apply only to fallback builds.
- Pro: the fallback is a single, explicit build flag, so a Windows-specific regression in the sqlite3mc binaries can be worked around without a code change.
- Con: the plain-to-encrypted upgrade is one-way. Going back to plain requires a decrypted export and restore (T7). The fallback build refuses an encrypted file rather than silently replacing it.
- Con: as with Android, losing the key from secure storage means the data cannot be read (OQ-DATA-1); OQ-DATA-3 (key/data backup) stays open and non-blocking.
- Unchanged: one database file and one key per install. Per-profile files and keys are the subject of the separate SR-03 task.

## Verification
- Headless: `local_store_test.dart`, `storage_security_test.dart` and the app integration test, encrypted end-to-end for both Android and Windows; a plain Windows DB without the fallback flag is a violation; with the flag it is the tracked exception.
- Device (Windows, T5a): the owner's existing plain database was backed up, then encrypted in place on first launch; the header is no longer plain SQLite, all existing tasks and subtasks are shown, and no storage banner is displayed.
