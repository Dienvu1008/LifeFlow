# ADR-0072: Attachments: encrypted files on the device only

- Status: Accepted (P05a task T7, 2026-11-04); answers OQ-DATA-2 for P05a
- Date: 2026-11-04
- Deciders: implementation within [p05-plan.md](../roadmap/p05-plan.md) (the owner's C3: files stay on the device; syncing them is a later paid feature) and [data-architecture.md](../data/data-architecture.md) §2
- Related: [ADR-0021](0021-encryption-at-rest-platform-posture.md), [ADR-0022](0022-windows-encryption-at-rest.md), [ADR-0023](0023-per-profile-stores-and-registry.md), [ADR-0054](0054-sync-keys-recovery-key-and-passphrase.md), [ADR-0066](0066-document-record-model.md)

## Context
A document's body already names a file by `AttachmentRef`: a `sha256:` hash, a name, a size and a type (ADR-0066). Nothing kept the files. data-architecture.md decided that files live outside the database and left their encryption open (OQ-DATA-2): "the same key as the DB where the platform does not already encrypt". p05-plan.md proposed AES-GCM with a key in secure storage.

## Decision
1. **Where the files are.** In the profile's own folder, `profiles/<profileId>.files/`, beside its database. There is one file per content: the same file added twice is kept once, and adding it again repairs a damaged copy. The database holds no file data. The body's reference is the only link, and it syncs like the rest of the body. The file never syncs (C3).
2. **Always encrypted, with a key of the files' own.**
   - The key is 256 random bits in secure storage, `lifeflow.attach.key.<profileId>`. It is made when the first file is kept, so looking at a file never creates one.
   - HKDF derives two keys from it: one encrypts, one names files.
   - A file is a format byte (1) followed by AES-256-GCM output (nonce, ciphertext, tag). The file's hash is the associated data, so a file that decrypts is the file of that hash.
   - A file's name is an HMAC of its hash, so the folder does not reveal whether a known picture is there.
   - The files do not share the database key. That keeps them encrypted even when the database is plain (the Windows fallback of ADR-0022). It also keeps the two key lifecycles apart: the export and a later file sync can treat files separately.
3. **Writing is all or nothing.** A file is written beside its final name, then renamed.
4. **Reading never breaks a document** (`AttachmentService.open` and `availability`):
   - **here:** on this device, decrypted and authenticated;
   - **elsewhere:** not on this device; this is what another device or another member of a space sees ("Attachment on another device", with name and size from the body). A lost key looks the same, because files are found by a name derived from the key;
   - **unreadable:** on this device but changed, or in a newer format.

   None of these raise an error. The document opens, saves and is found by the file's name (search indexes the name, ADR-0067) whatever the file's state.
5. **Limits.** At most 25 MB per file, because a file is held in memory to be encrypted. A name of 1–255 characters. A type of the form `type/subtype`, otherwise `application/octet-stream`.
6. **Cleaning up** (`sweep`): a file is removed only when no document and no revision in any workspace of the store names it (C9 keeps every revision, so a file in a revision stays) and it is older than a day, so a file picked but not saved yet survives. If any body cannot be read, nothing is removed, because that body may name files. Deleting a profile deletes its folder and its key, including after an interrupted delete (`ProfileDirectory._wipe`).
7. **What T8 and T9 do with it.**
   - T8 builds the service per profile from `ProfileDirectory.attachmentsDir` and `attachmentKeys` and runs `sweep` when a profile opens.
   - T9 writes the files into the `.zip` export (C11), decrypted only into the zip the person chose to make.

## Consequences
- A member of a shared space never receives a file, only its name and size, as C3 says.
- If secure storage loses the key, the files cannot be read and show as "on another device". The document is untouched; adding the file again keeps a new copy.
- A file sync later (the paid feature) needs its own key handling for spaces. The key here never leaves the device.

## Verification
- `infrastructure/test/attachments_test.dart` (new, 6 tests):
  - At rest: neither the text nor the leading bytes appear in the stored file, and the hash is not its name; the file reads back whole; the same file is kept once; no key without a file, and looking makes none.
  - Limits: too large, no name, a name too long.
  - A file elsewhere, a changed byte, a newer format, an empty file; a damaged copy repaired by adding again; a lost key.
  - A document naming a missing file opens, saves, has its history, and is found by the file name.
  - Sweep: in a document or only in a revision is kept, unnamed is removed, newer than the grace is kept, nothing is removed while a body cannot be read.
  - Deleting a profile deletes its folder and its key.
- Mutations: 16 run one at a time, all killed.
  - One survived the first run (a key made by a mere look) and was killed after a new check.
  - Two first showed as "locked" because the test left its directory open when it failed; after the test closed it on failure, both were killed.
