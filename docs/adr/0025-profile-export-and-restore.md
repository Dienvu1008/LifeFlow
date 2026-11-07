# ADR-0025: Profile export and restore as a decrypted, versioned, checksummed file

- Status: Accepted (owner decision, 2026-11-06, P01 task T7)
- Date: 2026-11-06
- Deciders: Project owner
- Resolves: OQ-DATA-3 (option a). Implements UC-20a, GS-20, LF-INV-SEC-010, SR-14.
- Related: [ADR-0023](0023-per-profile-stores-and-registry.md), [ADR-0021](0021-encryption-at-rest-platform-posture.md)

## Context
Each profile is encrypted with a random key held only in secure storage (OQ-DATA-1). Without a backup, losing the device means losing the data. OQ-DATA-3 asked how to back it up. The owner chose the simplest path for the MVP: the user-initiated export is the backup. The owner also chose the scope: export the **active profile** only, and defer passphrase-encrypted export.

## Decision
- **Export file.** A JSON envelope: `format: lifeflow-export`, `formatVersion: 1`, `schemaVersion`, `checksumSha256`, `counts`, `payload`. The payload holds every table of the profile store, including tombstones, audit, outbox, event log and dedupe rows. A guard test fails if a table is added to the database without being exported.
- **Decrypted on purpose.** The file is application data, not the encrypted database. It is portable and needs no key. The UI warns that it is **unencrypted** before it is saved. The auth tokens and the database key are never included (SR-02).
- **Restore creates a profile.** It never replaces. If the profile already exists on the device, it is restored as a **copy under new ids**; the original is untouched. A restored profile has no account binding and is not signed out.
- **Untrusted input (SR-14).** A file is fully validated before anything is written: size cap (64 MB), format, version, checksum, counts, referential consistency, hierarchy cycles and depth. A file with a newer `formatVersion` or `schemaVersion` is rejected (AC-20a.2). Older schemas are accepted when the difference is additive. Nothing is written when validation fails.
- **Port boundary.** `DataTransferService` and `FileGateway` live in `application`. Drift code is in `infrastructure`. The file picker is wired in the composition root (`FilePickerGateway`). The UI sees only the ports (FF-ARCH-04).

## Rejected
- (b) Passphrase-wrapped key export: deferred, still open for P04 with the cryptographic lock from ADR-0024.
- (c) Cloud key escrow: needs the backend (P04+).
- Raw copy of the encrypted database: needs the key, not portable across installs.
- Passphrase-encrypted export file: deferred by the owner. Stays an open question.

## Consequences
- Pro: a real, testable backup path with no new key management.
- Pro: also the way back from the Windows fallback build to a plain database (ADR-0022).
- Con: the export contains the user's data in the clear. The user is responsible for where the file is stored.
- Con: export is per active profile; there is no "export all profiles" action.
- Open: passphrase-encrypted export; OQ-S9 (partial move of data between profiles).

## Verification
- `packages/infrastructure/test/profile_export_test.dart` (25 tests): content, round trip into a clean install, restore as a copy, tampered or newer files rejected, older files accepted, service.
- `packages/ui/test/data_flow_test.dart`: export warning and restore flows.
- `apps/lifeflow_app/test/app_integration_test.dart`: export and restore end to end on real stores.
- Mutation checks on the export logic were run; see the exit-gate document.
