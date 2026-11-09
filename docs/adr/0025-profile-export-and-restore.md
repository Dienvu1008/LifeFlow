# ADR-0025: Profile export and restore

- Status: Accepted (owner decisions 2026-11-06 and 2026-11-07, P01 tasks T7 and T7b)
- Date: 2026-11-07
- Deciders: Project owner
- Resolves: OQ-DATA-3 (option a). Implements UC-20a, GS-20, LF-INV-SEC-010, SR-14.
- Related: [ADR-0011](0011-command-gateway-single-mutation-path.md), [ADR-0015](0015-per-type-conflict-resolution.md), [ADR-0021](0021-encryption-at-rest-platform-posture.md), [ADR-0023](0023-per-profile-stores-and-registry.md), [ADR-0024](0024-sign-out-locks-the-account-profile.md)

## Context
Each profile is encrypted with a random key held only in secure storage (OQ-DATA-1). Without a backup, losing the device means losing the data. OQ-DATA-3 asked how to back it up. The owner chose the simplest path for the MVP: the user-initiated export is the backup. The owner also chose the scope: export the **active profile** only, and defer passphrase-encrypted export.

The first T7 build restored a file of a profile that was already on the device as a **separate copy under new ids**. The owner rejected this on device review (2026-11-07): the same data must not become a second profile. It also breaks sync later (P04): the same task would exist twice under two ids and never reconcile.

## Decision

### Export
- A JSON envelope: `format: lifeflow-export`, `formatVersion: 1`, `schemaVersion`, `checksumSha256`, `counts`, `payload`. The payload holds every exported table of the profile store, including tombstones, audit, outbox, event log and dedupe rows. A guard test fails if a table is added without being exported or explicitly listed as not exported (`restoreSnapshots` only).
- **Decrypted on purpose.** The file is application data, not the encrypted database. It is portable and needs no key. The UI warns that it is **unencrypted** before saving. Auth tokens and database keys are never included (SR-02).

### Validation (SR-14)
A file is fully validated before anything is written: size cap (64 MB), format, version, checksum, counts, referential consistency, hierarchy cycles. A newer `formatVersion` or `schemaVersion` is rejected (AC-20a.2). Older schemas are accepted when the difference is additive. A failure writes nothing.

### Restore: where the file goes
1. **Profile not on this device** (new device, reinstall, deleted profile): restored as a new profile with its **original ids**, its own file and key. Inactive, no account binding.
2. **The active profile**: compared, then restored **into it** (below). Never a second profile.
3. **Another profile on this device**: refused with a message to open that profile (sign in first when it is locked) and restore there.

### The same account on another device (T7c, owner report 2026-11-07)
Until sync (P04), each device gives an account **its own profile and workspace ids**. A file exported on Windows from the GitHub account's profile therefore never had the id of that account's profile on Android, and was restored as a new profile. Fixed:
- A file is **this profile's data** when it has the same profile id, **or** it was exported from a profile bound to the **same account** (same account id and provider).
- Such a file is mapped onto this profile: its workspace id and owner id become this profile's. Record ids (tasks, lists) are kept, so the usual compare, overwrite, merge and undo apply. Tasks created on the other device are "only in the file" and merge (b) adds them.
- If that account's profile is on this device but another profile is open, the file is refused with a pointer to that profile (sign in first when it is locked). Another account's file is never merged in.
- Known limit until P04: the same task edited on both devices only matches if it was first created on one device and restored onto the other; otherwise the two are separate tasks.

### Restore into the active profile
- **Compare** task lists and tasks by id. Content is compared without `version` and `updatedAt`. A record deleted on one side and absent on the other is not a difference. Identical: the app says there is nothing to restore and writes nothing.
- **Overwrite everything**: the profile becomes the file. Records only on this device become **tombstones** (moved to trash), never hard-deleted, so a later sync deletes them instead of bringing them back.
- **Merge**, two options, each optional:
  - (a) same id on both sides: take the newer one. **Newer = later `updatedAt`, then higher `version`** (owner choice). Accepted risk: clocks of two devices can differ.
  - (b) add records that exist only in the file.
  - Records only on this device are always kept.
- **Hierarchy**: a merge can make a cycle (A under B on one side, B under A on the other), a missing parent or list, or a tree deeper than the limit (deeper than the file itself had; older deeper data stays valid, GS-18). The user gets **both choices** (owner decision): cancel (nothing written), or keep this device's parent for those tasks. A task that is new from the file then goes to the top level.
- **Versions only increase** (LF-INV-VER-001): a written record gets `max(device, file) + 1`.
- **Never from the file**: the profile row (account binding, sign-out lock, name). Governance history (audit, outbox, event log, dedupe) is **appended** by id, never rewritten. Imported events are marked dispatched (they were delivered where they happened).
- **One command** through the gateway (ADR-0011): `RestoreProfile` / `UndoRestoreProfile`, authorized, one transaction with audit, dedupe and event (LF-INV-GOV-003), plus **one outbox row per changed record** under the same operation id (LF-INV-OUTBOX-001). The profile row's version is the aggregate version.
- **Undo**: in the same transaction, the state before the restore is saved in `restore_snapshots` (schema v3) **inside the profile's own encrypted store**, never as a plain file. Only the latest is kept. "Undo last restore" overwrites the profile with it (again with tombstones, audited) and consumes it. Changes made after the restore are undone too; the UI says so.

### Port boundary
`DataTransferService` (`inspect`, `restore(choice)`, `canUndoRestore`, `undoLastRestore`) and `FileGateway` live in `application`; the planner and handler in `infrastructure`; the file picker in the composition root. The UI sees only the ports (FF-ARCH-04).

## Rejected
- Restore as a copy under new ids (first T7 build): duplicates data and breaks P04 sync.
- Hard-deleting device-only records on overwrite: sync would resurrect them.
- Global last-write-wins with no user choice: this is a user-driven, per-record choice for a restore, not automatic sync. Per-field merge is left to P04 (ADR-0015).
- An undo copy as a plain file next to the database: it would hold the data unencrypted.
- (b) passphrase-wrapped key export and (c) cloud key escrow: open for P04. Passphrase-encrypted export file: deferred by the owner.

## Consequences
- Pro: a real, testable backup path with no new key management; restore keeps one profile per data set.
- Pro: also the way back from the Windows fallback build to a plain database (ADR-0022).
- Con: the export contains the user's data in the clear. The user is responsible for where the file is stored.
- Con: "newer" depends on device clocks. A wrong clock can make the older edit win; undo is the safety net.
- Con: the undo copy doubles the store size until the next restore or undo.
- Open: passphrase-encrypted export; OQ-S9 (partial move of data between profiles); restoring a file into a different profile.

## Verification
- `packages/infrastructure/test/profile_restore_test.dart` (21 tests): identical / counts / tie rule; overwrite (tombstones, versions, FTS, one audited command, one outbox row per record, binding kept); merge (a), (b), (a)+(b); hierarchy (cycle, missing parent, too deep, both choices); undo (state back, only latest kept, copy stays encrypted and is not exported); file of another profile.
- `profile_export_test.dart`: content, clean-install round trip with original ids, untrusted input, older files; the same profile is never added twice.
- `atomic_set_test.dart` (FF-ARCH-06) covers `ProfileRestoreHandler` (restore and undo) with fault injection.
- `profile_directory_test.dart`: v1 → v3 and v2 → v3 upgrades with data intact.
- `packages/ui/test/data_flow_test.dart`: every dialog (new profile, identical, choices, overwrite, merge options, hierarchy both ways, undo, other profile, rejected files).
- `apps/lifeflow_app/test/app_integration_test.dart`: on real stores through the UI: export, identical, drift, overwrite, undo; and a file from another install restored as a new profile with its ids.
- T7c: `profile_restore_test.dart` group "the same account on another device": two installs with their own folders and keys, same account; the file merges into the account's profile under its own workspace; a guest being open points to the account's profile; another account becomes a new profile.
- Mutations: disabling the account match fails the cross-device test; disabling the hierarchy check fails 3 tests; `>=` instead of `>` on the version tie fails the tie test; writing rows with nulls treated as absent (deletedAt not cleared) fails 2 undo tests.
