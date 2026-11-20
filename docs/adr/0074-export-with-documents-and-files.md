# ADR-0074: The export with documents, revisions and files (.zip)

- Status: Accepted (P05a task T9, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05-plan.md](../roadmap/p05-plan.md) (the owner's C11) and ADR-0025 (export and restore, GS-20)
- Related: [ADR-0025](0025-profile-export-and-restore.md), [ADR-0068](0068-document-commands.md), [ADR-0070](0070-documents-in-shared-spaces.md), [ADR-0072](0072-encrypted-attachments.md)

## Context
Documents, revisions and document links have been record kinds since T2, so the JSON export already carries them all, and the restore checks them as commands would (ADR-0068). A document's files are not records: they stay on the device, encrypted (ADR-0072). The owner's C11 says that when there are files, the export is a `.zip` with the JSON and the files beside it, and that without files it stays a plain JSON file, readable as today.

## Decision
1. **What the export holds.**
   - Everything it held before (SEC-010).
   - Every document, every revision (C9) and every document link of the personal workspace (B14).
   - The files named by those documents or revisions, when they can be read on this device. Then the export is a `.zip` (`….lifeflow.zip`) containing:
     - `lifeflow-export.json`: the export itself, unchanged, with its checksum and its 64 MB limit;
     - `attachments/<64 hex>`: each file, decrypted, named by its SHA-256.

   A file only in an old revision goes in too, because restoring that version needs it. A file that is not on this device (added on another device, or by another member) is left out, and the document still names it; after a restore it shows as "On another device". Shared spaces are not in the personal export, and neither are their files. A space's own export stays JSON.
2. **No compression, by choice.** Entries are stored, not compressed. The files are mostly pictures and documents that are compressed already, and the JSON stays under its own limit. The reader accepts stored entries only, so a zip can never unpack to more than its own size (no zip bomb).
3. **Reading treats the zip as untrusted** (SR-14):
   - A picked export may be up to 256 MB (`maxExportFileBytes`), checked before it is read.
   - Only `lifeflow-export.json` and `attachments/<64 hex>` are read. Any other entry is ignored and never written anywhere (no path from the zip is used).
   - Each file is at most 25 MB, there are at most 20 000 files, and each must match its name's hash; otherwise the file is "damaged".
   - The JSON then goes through every check it always had.
   - A plain JSON file is read as before. Whether a file is a zip is decided by its first bytes, not by its name.
4. **Restoring** (`inspectFile`, `restoreFile`): the data is restored exactly as before (new profile, or into this profile with its choices and undo). Then each file of the zip is kept in the profile the data went to, encrypted with that profile's own key (ADR-0072). On the same device, a file lost here comes back. "Undo the restore" leaves the files; the sweep removes the ones nothing names.
5. **The port.**
   - `ExportFile` gains `archive` (the zip's bytes) and `fileCount`.
   - `DataTransferService` gains `inspectFile` and `restoreFile`, which take the picked bytes.
   - `FileGateway.pickText` becomes `pickExport(maxBytes)`, which returns bytes.
   - The UI saves the zip with `saveBytes` (Profiles → Export, and the export offered before "use the account's data" in Sync). The export warning now says that documents with all their versions and the files are in it, in the clear.
6. **The library**: `archive` 4.0.9 (and `posix` 6.5.4), MIT (VS-48, FF-ARCH-07).

## Consequences
- An export with many pictures is as large as the pictures. The 256 MB limit can be raised later, but each file is held in memory when it is read.
- Files and the JSON are checked separately. The JSON's checksum does not cover the files; each file is checked against its own hash, and the documents name those hashes.
- The export is still unencrypted (ADR-0025), and the warning says so.

## Verification
- `infrastructure/test/export_archive_test.dart` (new, 5 tests):
  - GS-20 with documents: a clean install gets the same documents, revisions and links, the picture and a PDF that appears only in the history. The files are kept with the clean install's own key and are unreadable at rest. The document is found by search. A file from elsewhere stays "elsewhere".
  - Without files: plain JSON, restored from its bytes.
  - On the same device: a lost file comes back with an "overwrite".
  - Untrusted input: a file that does not match its hash, a changed JSON, no JSON, garbage, compressed entries, entries that are not ours (ignored and never written).
- `ui/test/data_flow_test.dart`: an export with files is saved as its `.zip`; the warning names documents and files.
- `apps/lifeflow_app/test/app_integration_test.dart`: in the real app, a document with a file exported from Profiles is a `.zip` holding the file in the clear and the document in the JSON.
- Mutations: 11 run one at a time; 10 killed. One is equivalent: a zip without JSON read as empty text is refused by the JSON reader anyway.
