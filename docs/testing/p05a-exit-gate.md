# P05a exit-gate evidence (documents)

This page maps each line of the P05a exit gate ([p05-plan.md §1](../roadmap/p05-plan.md)) to the tests and checks that prove it. It does the same for the invariants and scenarios the plan proposed (§7), the fitness functions and the definition of done ([definition-of-done.md](definition-of-done.md)). Status: **signed off by the owner, 2026-11-04**.

How to reproduce:
- `dart test` in `packages/foundation|time_kernel|domain|application|infrastructure`.
- `flutter test` in `packages/ui` and `apps/lifeflow_app`.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- The server, on a clean local database: `supabase start`, `supabase db reset`, `supabase test db` (pgTAP). Then, in `packages/infrastructure` with `LIFEFLOW_TEST_SUPABASE_URL` and `LIFEFLOW_TEST_SUPABASE_ANON_KEY` set to the local stack: `dart test test/remote_contract_test.dart test/remote_spaces_contract_test.dart test/sync_supabase_e2e_test.dart test/space_sync_supabase_e2e_test.dart`. Run pgTAP before these, as P04b's gate notes.
- CI runs all of this on every push (`.github/workflows/ci.yml`).

Branch at T11: `p05a/t11-exit-gate`, on `main` at `7c52a66` (T10 merged).

## Exit gate (p05-plan.md §1)

| Line | Proof |
|---|---|
| **No silent content loss** (DOC-002, DOC-005, GS-08): two offline edits of one document give two revisions and a visible conflict; every save is a revision; a revision never changes | **Two offline edits.** `sync_engine_test.dart` "GS-08 / DOC-005: changed on both offline: both saves are revisions everywhere, one review; \"Take the other\" syncs". On the real stack: `sync_supabase_e2e_test.dart` "GS-08 (P05a T4): a document changed on both offline: both saves kept, one review; \"Take the other\" reaches the other device". The merge rules: `sync_merge_test.dart` group "P05a T4: documents (ADR-0069)"; a revision changed on two sides is kept whole, never mixed. **Every save is a revision.** `document_commands_test.dart` "every save is one revision with the whole title and body (C5); nothing changed, nothing written (C7)", "a rename is a save: …". **A revision never changes.** "DOC-002/006: revisions are written once; nothing after changes them" and "a save of what is stored writes no revision; a revision id is used once; …". **Autosave (C7).** `documents_flow_test.dart`: 10 s idle (not before), back, the page taken down, the app to the background, before following a link. **A body this app cannot read is never written over** (ADR-0069). **Device check.** T10 step 18 (both offline, "Take the other") and step 17 (the background) |
| **The tree has no cycle** (DOC-001); a link resolves or shows as broken, never vanishes (DOC-003); tree, `[[…]]` links, links to other things and attachments are separate relations (DOC-004) | **DOC-001.** `documents_test.dart` "DOC-001: …" and "DOC-001 property: random moves checked by the rule never make a cycle". `document_commands_test.dart` "DOC-001: never under itself or a subdocument; positions among siblings". The UI never offers a document's own subtree (`documents_flow_test.dart` "the tree: …"). Two moves merged into a loop are shown, not lost (`sync_engine_test.dart`, ADR-0069). **DOC-003 (GS-27).** `documents_test.dart` "DOC-003: …". `document_links_search_test.dart` "a link shows the current title, or broken: in the trash, gone, or in another workspace" and "at a save a link takes its target's current title; a broken link keeps its text; search follows". **DOC-004.** `documents_test.dart` "DOC-004: the tree, [[…]] links, web links and files are separate relations". Links to tasks, events and goals are records of their own (`document_commands_test.dart` group "links (DOC-004)") |
| **Search by the exact spelling** (C4): "ghi chú" finds "ghi chú" and "Ghi Chú", not "ghi chu"; "Đà Nẵng" finds "đà nẵng"; whichever way a keyboard encodes the marks; on Windows and Android, in the encrypted store | **GS-28.** `search_index_test.dart` "Vietnamese words are found however the keyboard encoded the marks": NFC, NFD and half-decomposed; any case; "Đà Nẵng"; "ghi chu" not found. The same file covers the last word as a prefix, the workspace, and the v15 → v16 upgrade. `document_links_search_test.dart` group "search (C4, C12)" covers documents with passages, tasks, and the shown workspace only. **Encrypted store:** the app integration test searches a document in the real encrypted store. **Device check:** T10 steps 11 (Windows) and 15 (Android: Gboard Telex and VNI, Laban Key) |
| **P04's properties hold for documents**: end-to-end encrypted sync, GS-14/GS-17, and in a shared space the roles (SHARE-001…005) | **Sync.** Documents, revisions and document links are sealed records like every other (ADR-0069), with no server change: pgTAP is unchanged at 195/195. `search_index_test.dart` "a purged task and document leave no text in the index (GS-14)". **Spaces.** `sharing_test.dart` "P05a T5 (C2, C8): a document moves with its subdocuments and its whole history; its links stay; the members see who wrote what; a viewer saves nothing; and back out" and "P05a T5: a document moved reaches the account's other device, whichever sync comes first". `document_commands_test.dart` "a viewer creates and saves nothing". `space_sync_supabase_e2e_test.dart` "P05a T5: a personal document moved in with its history; …". UI: `documents_flow_test.dart` "B4: a viewer reads only". **Device check:** T10 steps 21–29 with two accounts |
| **Nothing leaves the device that should not**: attachments stay on the device (C3); a document is Confidential and enters a space only by a confirmed move | **Files.** They are kept in `profiles/<id>.files/`, encrypted with a key of their own (ADR-0072). Sync carries records only, and the body names a file by its hash: `attachments_test.dart` (at rest neither the text nor the hash shows; deleted with the profile), and T10 step 14 ("On another device" on Android). The personal export holds files only in the `.zip` the person chooses to make (ADR-0074). **Confidential and a confirmed move.** `kindClasses` (Confidential for documents and revisions). `sharing_test.dart` "P05a T5 …": the preview counts the revisions, and a change after the preview moves nothing. T10 step 21 ("… and N earlier versions", C8). A link in a space never shows a personal document's title (`document_links_search_test.dart`; T10 step 25) |

Fitness functions: FF-ARCH-06/09 for every new handler, FF-ARCH-07 for the editor and every package it brings, and FF-ARCH-10 for the new screens (below).

## Invariants (p05-plan.md §7)

| Invariant | Proof |
|---|---|
| LF-INV-DOC-001…005 | the first two exit-gate rows |
| LF-INV-DOC-006 (new): a revision is written once; every save writes exactly one | the first exit-gate row; the atomic set (`atomic_set_test.dart` steps `document.save`, `document.restoreRevision`, `space.moveIn(document)`, …) writes each revision with its outbox row; a move changes only a revision's place and version, and its author is named once (`sharing_test.dart`, ADR-0070) |
| LF-INV-SEARCH-001 (new): search by the exact spelling, marks included, case and encoding aside | the third exit-gate row |

Also held for documents: LF-INV-OUTBOX-001 and GOV-001 (every document command through the gateway, every record with its outbox row: `atomic_set_test.dart`), ID-001 (moves into and out of a space keep ids), and SEC-010 (the export holds every document and revision: `export_archive_test.dart`). The catalog entries are in [invariant-catalog.md](../invariants/invariant-catalog.md) §6. The matrix rows are in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md) (P05a status).

## Golden scenarios

| Scenario | Proof |
|---|---|
| GS-08 two offline edits of one document | the first exit-gate row (sync harness, local Supabase, T10 step 18) |
| GS-20 export and restore on a clean install, with documents | `export_archive_test.dart` "GS-20 with documents: the .zip carries the history and the files; a clean install gets them all"; `document_commands_test.dart` "an export with documents reads back; …"; T10 steps 19–20 |
| GS-27 (new) a `[[…]]` link survives a rename and shows broken, never vanishes | the second exit-gate row; the app integration test "P05a T10 step 6: a [[…]] link made in the editor shows as a backlink on its target"; T10 steps 4–6 and 13 |
| GS-28 (new) search by the exact spelling, whatever the keyboard | the third exit-gate row |

## Server (Supabase)

| Check | Proof |
|---|---|
| No server change for P05a | no migration since P04b; documents are sealed records (ADR-0069); nothing to push to the owner's project |
| pgTAP | 6 files, 195 assertions, PASS (local, 2026-11-04, after `db reset`) |
| Contract and e2e | 57 tests on local Supabase (2026-11-04), including GS-08 for documents and a document moved into a space with two accounts |

## Fitness functions and governance

| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | green; the document format, rules, merges and link titles are in `domain` |
| FF-ARCH-04 UI isolation | green; the UI talks to `DocumentService`, `DocumentQueries`, `SearchQueries` and `AttachmentService`. flutter_quill sits behind `quill_adapter.dart` in `ui`, and the stored format is LifeFlow's (ADR-0073) |
| FF-ARCH-06 atomic set | `atomic_set_test.dart` steps `document.create`, `.save`, `.restoreRevision`, `.move`, `.link`, `.unlink`, `.trash`, `.restore`, `space.moveIn(document)`, `space.moveOut(document)`, with fault injection |
| FF-ARCH-07 licenses | 163 shipped packages, all accepted. New: flutter_quill 11.6.0 and 26 packages it brings (VS-47); archive 4.0.9 and posix 6.5.4 (VS-48) |
| FF-ARCH-09 authorize before domain | green; document commands go through the role policy, so a viewer is refused before the handler |
| FF-ARCH-10 no raw UI strings | 44 left in 9 files, none above the baseline; the Documents screens have none |
| Store upgrade v15 → v16 | `search_index_test.dart` "the v15 -> v16 upgrade indexes the tasks already there, …"; `profile_directory_test.dart` upgrades every version from v2 to the latest; the owner's existing profile upgraded on both devices in T10 |

## Universal DoD

| Line | Status |
|---|---|
| Builds on Windows and Android; analyze clean | the owner ran both platforms in T10; release builds made at T8; `dart analyze` and `flutter analyze` clean in every package |
| All phase tests pass | foundation 13, time_kernel 92, domain 106, application 3, infrastructure 543 (plus 57 on local Supabase), ui 334, app 36; pgTAP 195 (local, 2026-11-04); CI green on every task branch and on `main` at T10's merge |
| Mutation checks on the new logic | run one at a time per task: T1 19/20, T2 15/15, T3 29/29, T4 12/12, T5 26/26, T6 18/18, T7 16/16, T8 18/19, T9 10/11. Each ADR records the ones not killed and why: T1's unreachable case was removed, and T8 and T9 each have one equivalent mutation |
| ADRs | 0066 (record model), 0067 (store and search, v16), 0068 (commands), 0069 (sync), 0070 (spaces; fixes P04b's export), 0071 (links and search), 0072 (attachments, OQ-DATA-2), 0073 (UI and editor adapter), 0074 (export with files); ADR-0020 amended (S-07) |
| Open questions | OQ-LS-1 resolved (ADR-0067), OQ-DATA-2 resolved for P05a (ADR-0072), OQ-DOC-1 resolved (full copy at each save, all kept), OQ-DOC-2 resolved (flutter_quill, S-07); OQ-DOC-3 (viewers) stays with P05b |

## Bugs found during P05a
1. **P04b: the personal export could not be restored after a move into a space** (found in T5). The file left the moved records out, but the reader refused personal rows that still pointed to them, such as a goal link or a reminder. Fixed: the export lists the ids it points to in a space (`inSpaces`), and a new store drops or clears what points to them (ADR-0070, `space_export_test.dart`).
2. **T5: a revision's author was overwritten when a document moved back into a space**, by the gateway's "changed by" stamp. Fixed: a revision names its author once (ADR-0070).
3. **T8: text beside a file on one line was lost**, found by the app integration test. Fixed in the adapter, and the page puts a file on a line of its own (ADR-0073).
4. **T8: leaving a page that was taken down did not save**: the service was read in `dispose`, after Riverpod's ref was gone. Fixed (ADR-0073).
5. **T8: the item picker called `setState` with a future**. Fixed.

## Device checks (T10, the owner, 2026-11-04)
All 30 steps of [p05a-device-check.md](p05a-device-check.md) were as expected on Windows and Android:
- alone with account A;
- then with account B in a shared space;
- with Vietnamese keyboards (Gboard Telex and VNI, Laban Key; the Windows keyboard and Unikey or EVKey) and a 50-page document.

Finding 1 (step 6, the links panel lists only the documents that link to the open one and its linked items, not its own `[[…]]` links) is the panel's design, not data. **The owner's decision: no change.**

## Known limits carried out of P05a
- Viewers (PDF, DOCX) and reading aloud are P05b (OQ-DOC-3).
- Files stay on the device (C3). Syncing them is a later paid feature with its own plan. A space's export carries no files.
- Tapping a web link copies it; it does not open.
- Events cannot be linked from a document.
- The links panel does not list a document's own `[[…]]` links (T10 finding 1, kept by the owner).
- A link's text follows a rename at the linking document's next save, not at once (ADR-0071).
- Titles are not sorted in Vietnamese dictionary order.
- The UI is in English.
- Settings do not yet show how much space documents use (C9).
- A pasted picture from another app is dropped; "Attach a file" is the way (ADR-0073).
- Two people editing one shared document at once get a conflict and both versions, not live merging (ADR-0017).
- A document link left behind by a move does not follow later moves, as goal links do (ADR-0070).
- An export with files is held in memory: up to 256 MB, 25 MB a file (ADR-0074).

## Risks
- **R-EDITOR** (new, the main risk): S-07 on the owner's devices; LifeFlow's own format behind an adapter, with round-trip tests of every block type; T10 30/30 on both platforms. Register updated.
- **R-EDITOR-LICENSE**: 27 new packages, all accepted (VS-47); FF-ARCH-07 green. Register updated.
- **R-DATA-LOSS**: autosave on every exit path, a revision per save, both sides of a conflict kept, revisions never change; GS-08 on the real stack and on the devices. Two bugs found and fixed (the P04b export, a revision's author).
- **R-CLOUD-COST**: every save syncs a full revision (C9); files do not sync (C3). Watch the size; a thinning rule later if needed.
- **R-DOC-COLLAB**: unchanged; conflicts, not live merging (ADR-0017).
- **R-CI-FLAKE**: no CI failure in P05a. Register updated.
- **R-SCOPE**: viewers, TTS and file sync stayed outside P05a.

## Owner sign-off
- [x] Device checks above (owner, 2026-11-04).
- [x] CI green on the T11 branch head (`6b66014`).
- [x] Owner approves P05a as done (2026-11-04).
