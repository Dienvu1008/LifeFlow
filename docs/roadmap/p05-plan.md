# P05 plan: Documents and knowledge

- Status: **Decisions taken by the owner 2026-11-04** (C1–C12, below; C4 and C12 changed after the FTS5 check of §2). **Accepted by the owner 2026-11-04.**
- Date: 2026-11-04
- Inputs: [phase-breakdown.md](phase-breakdown.md) (P05), [document-knowledge.md](../domains/document-knowledge.md), [ADR-0017](../adr/0017-document-collaboration-maturity.md) (single-user editing, revisions, no CRDT), [ADR-0020](../adr/0020-editor-decision-or-spike.md) (MIT/BSD editor, final pick by S-07), [ADR-0018](../adr/0018-dependency-license-policy.md), [spike-plan.md](../spikes/spike-plan.md) (S-07, S-08, S-09, S-12), [data-classification.md](../data/data-classification.md) (documents are Confidential), [local-storage.md](../data/local-storage.md) (OQ-LS-1), [data-architecture.md](../data/data-architecture.md) (attachments as files, OQ-DATA-2), [p04b-exit-gate.md](../testing/p04b-exit-gate.md); invariants DOC-001…005; GS-08; use cases UC-09, UC-10, UC-14; open questions OQ-DOC-1…3
- Estimate: P05a about 21–28 person-days, plus a 30 % risk buffer (the phase breakdown guessed 20–45 for all of P05). P05b is estimated at its start.

## 1. Split, goal and exit gate

P05 is split like P04, each part with its own exit gate and the owner's review:
- **P05a: documents.** Documents with a block editor, a revision at every save, a tree of documents, `[[…]]` links and backlinks, links to tasks, events and goals, search by the exact spelling (Vietnamese marks included), sync, shared spaces, and attachments kept on the device.
- **P05b: viewers and reading.** PDF and DOCX viewing (S-08, S-09) and reading aloud (S-12). It depends on what license-clean libraries work on Windows; it does not hold up P05a. Planned at P05a's exit.

P05a's goal: a person writes and organizes their own documents, and shares some of them in a space, with no content ever lost: not by a conflict, not by a sync, not by a move.

Exit gate (P05a):
- **No silent content loss** (DOC-002, DOC-005, GS-08): two offline edits of one document give two revisions and a visible conflict; every save is a revision; a revision never changes.
- **The tree has no cycle** (DOC-001); a link resolves or shows as broken, never vanishes (DOC-003); tree, `[[…]]` links, links to other things and attachments are separate relations (DOC-004).
- **Search by the exact spelling** (C4): "ghi chú" finds "ghi chú" and "Ghi Chú", and not "ghi chu"; "Đà Nẵng" finds "đà nẵng"; whichever way a keyboard encodes the marks (§2), on Windows and Android, in the encrypted store.
- **P04's properties hold for documents**: end-to-end encrypted sync, GS-14/GS-17, and in a shared space the roles (SHARE-001…005).
- **Nothing leaves the device that should not**: attachments stay on the device (C3); a document is Confidential and enters a space only by a confirmed move.

Fitness functions: FF-ARCH-06/09 for every new handler; FF-ARCH-07 for the editor and every package it brings; FF-ARCH-10 for the new screens.

Out of scope for P05a: viewers and TTS (P05b); syncing attachment files (C3: a paid feature later, with in-app purchase); real-time co-editing or CRDT (ADR-0017); comments; public links; turning task notes into documents (C1).

## 2. Starting point (checked)
- No document code, table or record kind exists. No FR-DOC requirement is written (requirements.md leaves them to P05).
- Task notes are one plain-text field (`tasks.notes`, at most 20 000 characters), merged as one value with a review (P04a). They stay as they are (C1).
- FTS5 works in the encrypted store on both platforms (S-02, ADR-0022). `tasks_fts` is an external-content index kept by triggers: the pattern to follow.
- Sync stores any record kind as sealed rows: **the server needs no change for documents** (no record size limit; batches of 500). A space holds only `sharedSpaceKinds`; documents must be added there (C2).
- The editor candidates today (checked on pub.dev, 2026-11-04):
  - **super_editor** (MIT, VS-30): block document model (nodes with ids), undo/redo. The last stable release is 0.2.7 (2024); since then only developer releases (0.3.0-dev.52, June 2026), and its README lists **Windows as "unverified"**.
  - **flutter_quill** (MIT, VS-29): 11.6.0 (September 2026), actively released, Android and desktop; a Delta model (a list of text operations with block attributes), not block objects; needs Flutter 3.44+ (the project is on 3.47.2). Its dependencies (`quill_native_bridge`, `flutter_keyboard_visibility_temp_fork`, `flutter_colorpicker`, `url_launcher`, …) each need a license row.
  - A custom block editor (project code): full control, the most work.
  So ADR-0020's lead candidate is no longer clear-cut; S-07 compares the first two on the owner's devices. **S-07 (2026-11-04): flutter_quill**, smooth on both platforms in the owner's test; super_editor lagged on Android.
- Vietnamese search, checked on the project's SQLite (2026-11-04, a throwaway probe):
  - FTS5's default tokenizer (`unicode61`, which `tasks_fts` uses today) **removes most marks**: "ghi chú" and "ghi chu" find the same rows. But "đ" (U+0111) is its own letter with no decomposition, so "da" does not find "Đà" ([see the SQLite forum on letters like "ł"](https://sqlite.org/forum/forumpost/468a234e0b2d69b8?t=c)), and a letter with two marks ("ẵ") is not always folded. Task search therefore ignores marks today, inconsistently.
  - With `remove_diacritics 0` the marks are kept: "ghi chú" finds only "ghi chú", case is ignored ("ĐÀ" finds "đà"), and "ghi chu" finds only "ghi chu".
  - **The same word can be stored two ways**: "ú" as one character (NFC) or as "u" plus a combining mark (NFD), depending on the keyboard. With marks kept, an NFC query does not find NFD text. So text and queries are both normalized to NFC first, with `unorm_dart` (already licensed, VS-45).

## 3. Owner decisions

| # | Question | Decision |
|---|---|---|
| C1 | Documents and task notes | **(a) Kept separate**, as today (owner, 2026-11-04). A task can link to a document (LinkedResource); its notes stay plain text. |
| C2 | Documents in shared spaces | **Allowed in P05a** (owner, 2026-11-04). Same roles as P04b: owner and editors write, viewers read; a document enters a space only by "Move to a space…" with its confirmation. |
| C3 | Attachments (images, files) | **Kept on the device only** in P05a (owner, 2026-11-04). Syncing them through Supabase Storage will be a **paid feature (in-app purchase)**, in a later phase with its own plan (billing on Google Play and the Microsoft Store, storage costs, the D2 free plan). |
| C4 | Vietnamese search | **By the exact spelling** (owner, 2026-11-04, after the check in §2): a search without marks is not needed; "ghi chú" must find "ghi chú", in any letter case and whichever way the marks were typed. |
| C5 | Revisions | **A new revision at every save** (owner, 2026-11-04). What counts as a save is C7. |
| C6 | Links | **`[[…]]` links and a list of backlinks in P05a** (owner, 2026-11-04). |
| C7 | What is "a save" | **As proposed** (owner, 2026-11-04): the editor saves by itself (no Save button to forget): when you leave the document, switch to another, put the app in the background, or stop typing for **10 seconds**. Each save is a revision. A revision holds the whole document, so any one of them can be shown or restored on its own. |
| C8 | A document's history when it moves into a space | **As proposed** (owner, 2026-11-04): **the history moves with it**, and the confirmation says so: "Everyone in Family will see: the text, its 3 subdocuments, **and its 12 earlier versions**." Keeping the history behind would leave versions in another workspace than their document. |
| C9 | How long revisions are kept | **As proposed** (owner, 2026-11-04): **all are kept**, on the device and in sync; the document's history shows them newest first. A typical document (5 KB) saved 20 times a day adds about 100 KB a day before compression; the Settings show the space the documents use, so this can be revisited (a thinning rule for old revisions) if it grows. |
| C10 | Where documents appear | **A seventh destination "Documents", right after Calendar** (owner, 2026-11-04: documents shared with others matter, so they come early): Overview, Timeline, Calendar, **Documents**, Habits, Goals, Settings. It shows the tree of documents, search at the top, "New document". Documents follow the shown space, like every view (P04b). A document opens on its own page with its backlinks and links under the text and its history in the menu. |
| C11 | Export | **As proposed** (owner, 2026-11-04): the export holds documents and all revisions (SEC-010, as everything else). Attachments: the export becomes a `.zip` with the JSON file and the attachment files beside it; an export without attachments stays a plain JSON file, readable as today. |
| C12 | Task search | **By the exact spelling too** (owner, 2026-11-04): `tasks_fts` is rebuilt with marks kept and NFC, so the whole app searches alike. This changes today's behaviour: "ghi chu" will no longer find a task titled "ghi chú". |

## 4. What `[[…]]` does (C6)
- Typing `[[` in a document opens a list of the documents of the **same workspace**, filtered as you type (as search does, C4). Picking one inserts a link; "Create '…'" makes a new document with that title and links it.
- The link stores the document's id; it shows the document's current title, so renaming changes nothing. A link to a document in the trash, or deleted, shows as broken (DOC-003) and is never removed silently; restoring the document repairs it.
- Under every document: **Backlinks** (the documents whose text links here, with the sentence around each link) and **Linked** (tasks, events and goals linked to it, and from it: LinkedResource, as goals do).
- Links stay inside one workspace (as goal links do). In a shared space, the links are the space's; a personal document cannot be linked from a space, so nothing personal shows in a space's backlinks.

## 5. Technical design (no owner input needed; ADRs during the tasks)
- **Document record.** A document is one synced record: id, workspace, parent, title, order key, the body as **deterministically serialized blocks** (each block with a stable id, its type, its text with marks, its attributes), version, timestamps, tombstone, "changed by". This amends document-knowledge.md §4 (blocks as rows): with blocks inside the record, a sync conflict is one value to keep twice (ADR-0017) instead of a block-by-block merge, which is what a CRDT would be for. The block ids are kept so that block-level links can come later. ADR at T1.
- **Revisions.** `documentRevision` records: id, document id, the full serialized body and title, the author, the device, the time. **Append-only**: written once, never changed, so they never conflict. Saving is one command: the document's new version and its revision, in one transaction (the atomic set).
- **Conflict (GS-08, DOC-005).** In P04a's per-type merge, a document whose body changed on both sides keeps the newer one as the document and **the other one as a revision marked "conflict"**, plus a "Changes to review" item ("Changed on two devices: both versions are kept; open the history to compare"). Nothing is lost either way, and "Take the other" restores that revision as a new save. Title, parent and order merge field by field as tasks do.
- **Links.** `[[…]]` links live in the body (an inline mark with the document id). A local index table, rebuilt from the bodies at each save and each pull, answers backlinks; it is device bookkeeping, not synced. Links to tasks, events and goals are `documentLink` records (as `goalLink`).
- **Search (C4, C12).** One FTS5 table over each document's title and body text, with `unicode61 remove_diacritics 0` (marks kept, case ignored). Text and queries are normalized to NFC first (`unorm_dart`). Several words must all be there; the last one may be the start of a word ("ghi ch" finds "ghi chú"); quotes search a phrase. The same for task titles (C12): `tasks_fts` is rebuilt at the upgrade. Tested with a Vietnamese table (both encodings, letter case, "đ", two-mark letters) on the real sqlite3mc build; Android checked in T10.
- **Attachments (C3).** A pasted or picked image or file is copied into the profile's own folder, **encrypted with a key kept in secure storage** (AES-GCM, from `cryptography`, already licensed); the body refers to it by its hash. This answers OQ-DATA-2 for P05a (ADR at T7). The reference syncs; the file does not. On another device, or for another member, the block shows "Attachment on another device" with its name and size.
- **Shared spaces (C2).** `document`, `documentRevision` and `documentLink` join `sharedSpaceKinds`; "Move to a space…" and back out handle a document with its subdocuments and (C8) its history; the role policy and the server are unchanged.
- **Editor port.** The UI talks to the editor through an adapter (load blocks, get blocks, selection, the `[[` trigger), so the stored format is ours and not the library's. If the library changes or is replaced, the stored documents stay readable.
- **Store.** Schema v16: documents, revisions, document links, attachments, the link index, the search table; the upgrade loop from v2.

## 6. Spikes and tasks (P05a)
One branch per task; merge after the headless tests, and after the owner's check where marked.

| Task | Content | Main proof | Owner's check | Est. (pd) |
|---|---|---|---|---|
| **S-07** Editor (**done**: flutter_quill 11.6.0, [spike-results.md](../spikes/spike-results.md) S-07; ADR-0020 amended) | super_editor (developer release) and flutter_quill side by side behind the editor port, on Windows and Android: headings, lists, checklists, an image block, the `[[` trigger, undo/redo, Vietnamese typing (IME, Telex), a 50-page document, our deterministic serialization in and out; licenses of every package they bring | a written comparison and a pick; ADR-0020 confirmed or changed | **yes** (type in both on your devices) | 3–4 |
| **T1** Domain (**done**: [ADR-0066](../adr/0066-document-record-model.md)) | Document, blocks and their serialization, revisions, links, search text (NFC); DOC-001…004 as pure rules; ADR for the record model | unit and property tests (no cycle; serialization round-trips exactly) | no | 2–3 |
| **T2** Store (**done**: [ADR-0067](../adr/0067-document-store-and-exact-search.md)) | schema v16, record kinds and classes (Confidential), the search table and link index, `tasks_fts` rebuilt (C12), upgrade v2…v15 → v16 | upgrade test; the Vietnamese search table on the store; OQ-LS-1 answered | no | 2–3 |
| **T3** Commands (**done**: [ADR-0068](../adr/0068-document-commands.md)) | create, save (with its revision), rename, move in the tree, trash and restore, restore a revision, link to a task/event/goal; FF-ARCH-06/09 | atomic-set steps; DOC-001/002 on the store | no | 2–3 |
| **T4** Sync (**done**: [ADR-0069](../adr/0069-document-sync.md)) | documents in the engine; the conflict rule (both kept); revisions append-only | GS-08 and GS-14/17 on the sync harness and on local Supabase (e2e) | no | 2–3 |
| **T5** Shared spaces (**done**: [ADR-0070](../adr/0070-documents-in-shared-spaces.md); also fixes a P04b bug: the personal export after a move) | documents in spaces, the move with its confirmation (C8), viewers read only | SHARE-001/002 for documents; e2e with two accounts | no | 1–2 |
| **T6** Links and search (**done**: [ADR-0071](../adr/0071-document-links-and-search.md)) | `[[…]]` resolution and broken links, backlinks with their sentence, search across titles and bodies (and task titles, C12) | DOC-003/004 tests; search tests | no | 2 |
| **T7** Attachments (**done**: [ADR-0072](../adr/0072-encrypted-attachments.md)) | encrypted files, references, "on another device"; ADR for OQ-DATA-2 | a file at rest is not readable; a missing file never breaks the document | no | 1–2 |
| **T8** UI (**done**, your check in T10: [ADR-0073](../adr/0073-documents-ui-and-editor-adapter.md)) | the Documents destination (C10), the tree, the editor page, the `[[` picker, backlinks and links, history and restore, the conflict item, search | widget tests; app integration test | **yes** | 4–5 |
| **T9** Export and restore (**done**: [ADR-0074](../adr/0074-export-with-documents-and-files.md)) | documents and revisions in the export; `.zip` with attachments (C11) | GS-20 round trip with documents | no | 1 |
| **T10** On the devices (**done**: [p05a-device-check.md](../testing/p05a-device-check.md)) | your Windows and Android, alone and with a second account in a space: write, link, search in Vietnamese, conflict, history, move into a space | your check | **yes** | 1 |
| **T11** P05a exit gate (evidence: [p05a-exit-gate.md](../testing/p05a-exit-gate.md); waiting for your review) | p05a-exit-gate.md, ADRs, invariants, risks; your review | all suites, CI | yes | 1 |

Order: S-07 → T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11.

## 7. Invariants and scenarios
- DOC-001…005 are enforced and tested in P05a (catalog §6).
- Proposed new: **LF-INV-DOC-006**: a revision is written once and never changed; every save writes exactly one. **LF-INV-SEARCH-001**: search matches the exact spelling, marks included, ignoring letter case and how the marks were encoded (NFC on both sides).
- GS-08 (two offline edits of one document) is proved in T4. Proposed new: **GS-27** (a `[[…]]` link survives a rename and shows broken after a delete, repaired by a restore), **GS-28** (a search with marks finds the same words typed on another keyboard, in any case, and does not find them without marks; on both platforms).

## 8. Risks
- **R-EDITOR** (new, main risk; S-07 picked flutter_quill, whose Delta model has no block ids and whose cursor needs a line after an image, both handled in the adapter): no candidate is a clear fit (super_editor without a stable release and unverified on Windows; flutter_quill not block-based). Mitigation: S-07 on the owner's devices before any task; the editor port keeps our format, so a later switch does not touch stored documents. Contingency: a custom block editor over Flutter's text fields (more effort, about +5–8 pd).
- **R-EDITOR-LICENSE**: each package an editor brings needs a license row before the merge (FF-ARCH-07).
- **R-DATA-LOSS**: autosave, conflicts and moves. Mitigation: every save a revision, conflicts keep both, revisions never change, GS-08 on the real stack.
- **R-CLOUD-COST**: every save syncs a full revision (C9). Mitigation: the size shown in Settings; a thinning rule later if needed; attachments do not sync (C3).
- **R-DOC-COLLAB**: two people editing one shared document at once get a conflict, not live merging (ADR-0017); the trigger to revisit stays ADR-0017's.
- **R-SCOPE**: viewers, TTS and attachment sync are outside P05a.
