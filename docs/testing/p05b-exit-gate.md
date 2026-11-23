# P05b exit-gate evidence (viewers and reading aloud)

This page maps each line of the P05b exit gate ([p05b-plan.md §1](../roadmap/p05b-plan.md)) to the tests and checks that prove it. It does the same for the invariant and scenarios the plan proposed (§6), the risks (§7), the fitness functions and the definition of done ([definition-of-done.md](definition-of-done.md)).

- Status: **waiting for the owner's sign-off**.
- Branch: `p05b/t7-exit-gate`, on `p05b/t6-device-check` (T6, not merged yet), on `main` at `869dd74` (T1, T2, T4 and T5 merged).

How to reproduce: as for P05a ([p05a-exit-gate.md](p05a-exit-gate.md)).
- `dart test` and `flutter test` in every package.
- `dart run tools/fitness/<script>.dart` for each fitness script.
- On a clean local Supabase: `supabase db reset`, then `supabase test db` (pgTAP), and only then the four contract and e2e files (they leave data that pgTAP's counts do not expect).
- PDF tests need the PDFium binary, which the build hook downloads the first time (online). A Windows app build also needs `nuget.exe` on the PATH (ADR-0078).

## Exit gate (p05b-plan.md §1)
| Line | Proof |
|---|---|
| **A PDF attached to a document opens inside the app**: pages, zoom, page by page and scrolling, find, text selection and copy, on both platforms | **The page.** `ui/test/pdf_flow_test.dart` (fake view): only a PDF opens, from the very bytes `open` gave; pages and zoom; the last page (D9); find with counts, next and previous; Ctrl+F and Escape; copy, and a PDF that forbids it; a password, wrong then right; giving up and "Try again"; a damaged PDF; a file gone. **The real engine.** `ui/test/pdfrx_adapter_test.dart` opens a real PDF from bytes: pages, find across pages, go to a page, the page text, and a file that is not a PDF. `apps/lifeflow_app/test/pdf_integration_test.dart`: a PDF attached in the real app opens with PDFium, find moves to page 2, the page is remembered and the PDF opens there again. **Device check.** T6 steps 2–9 (Windows) and 25 (Android: pinch, handles, copy), all as expected (ADR-0076) |
| **DOCX stays a file with "Save a copy"** (D1 after S-09) | `fileViewOf` shows a DOCX as no view (`pdf_flow_test.dart` "fileViewOf: …"); only a PDF tile opens (`pdf_flow_test.dart` "D8: …"); a DOCX is never read for search (`pdf_search_test.dart` "a picture or another file is not read"). T6 step 2 |
| **A document can be read aloud** with the device's voices, Vietnamese included, with play, pause or stop, speed, and the sentence being read shown | **The sentences.** `domain/test/reading_test.dart` (11 tests): how sentences end, exact offsets on random text, long sentences cut, blocks in order, the language, a PDF's lines joined. **Documents.** `ui/test/read_aloud_flow_test.dart` (11 tests, fake voices): read sentence by sentence with the sentence selected; pause, stop, previous and next; speed and voice remembered; English and Vietnamese voices; no Vietnamese voice said with how to add one; no voices; a failing voice; leaving stops and the background pauses (ADR-0078). **PDFs.** `ui/test/pdf_read_aloud_test.dart` (4 tests): from the page shown, the sentence in the bar, the page turned with the reading (ADR-0079). **Device check.** T6 steps 15–23 (Windows, "Microsoft An") and 26–27 (Android, Google's Vietnamese voice): the owner listened, as expected |
| **Nothing leaves the device and nothing is written in the clear** that the person did not ask for; every new library is in the license inventory | **LF-INV-FILE-001** (below). **PDF text** stays in device-only tables of the encrypted store, not synced, not exported (`pdf_search_test.dart` "device-only: …"; `profile_export_test.dart` covers every table). **Settings** (the last page, speed, voices) are in the encrypted registry. **Licenses.** FF-ARCH-07: 174 shipped packages, all accepted; pdfrx and its 9 packages (VS-49), flutter_tts (VS-50), and the build-hook toolchain. The PDFium notices (21, ADR-0075) and C++/WinRT's notice ship and are listed (`apps/lifeflow_app/test/licenses_test.dart`); FF-ARCH-07 fails when the PDFium notices are missing or from another pdfium_dart (6 self-test cases). T6 step 1 |
| **P05a's properties still hold**: documents are stored, synced and shared as before | No change to records or the server: `recordSchemaVersion` stays 16; schema v17 adds device tables only (`pdf_search_test.dart` "v16 -> v17 …"). The whole P05a suite passes (below), including GS-08, GS-20, GS-27 and GS-28. A PDF word follows its document through the trash, a sync, a move into a space and back (`sharing_test.dart` "P05b T6 steps 14, 29, 30: …"). T6 steps 24 and 28–30 with two accounts |

## Invariant (p05b-plan.md §6)
| Invariant | Proof |
|---|---|
| **LF-INV-FILE-001** (new): a file is decrypted only in memory, to be shown, searched or read; written in the clear only where the person chose | `pdf_integration_test.dart`: after the PDF is shown, found by find, and indexed for search, no file under the app's folder or the PDF engine's cache folder holds its text, in its own case or in the lower case of the index. A planted mutation that writes the PDF to the engine's cache fails that test (ADR-0076). The viewer is given bytes, never a path. The text index is in the encrypted store (ADR-0077) |
| LF-INV-SEARCH-001 | now also covers the text of PDFs: NFC, the exact spelling, NFD and half-decomposed typing (`pdf_search_test.dart` "by the exact spelling: …"); T6 steps 5, 10 and 11 |

Also held: LF-INV-PRIV-003 (the PDF text, the last page and the reading settings never leave the device) and LF-INV-SEC-010 (the export is unchanged and still covers every exported table). The catalog entry is in [invariant-catalog.md](../invariants/invariant-catalog.md) §6, and the matrix rows in [invariant-test-matrix.md](../invariants/invariant-test-matrix.md) (P05b status).

## Golden scenarios
| Scenario | Proof |
|---|---|
| **GS-29** (new) a PDF kept in a document opens on both platforms, is found by a Vietnamese word in it, and no clear copy appears on disk | the first, fourth and fifth exit-gate rows; `pdf_search_test.dart` (11 tests: the hit "in file.pdf, page 2", only through a live document of the shown space, read when kept and at the session start, dropped when the file leaves); `pdf_flow_test.dart` (the hit opens at its page with the words highlighted; the results follow the documents); `pdf_integration_test.dart`; T6 steps 2–14, 24–25 and 28–30 |
| **GS-30** (new) a Vietnamese document read aloud on both platforms, the sentence followed, speed changed, stopped when leaving | the third exit-gate row; T6 steps 15–23 and 26–27 |

## Server (Supabase)
| Check | Proof |
|---|---|
| No server change for P05b | no migration since P04b; nothing new is synced |
| pgTAP | 6 files, 195 assertions, PASS (local, 2026-11-04, after `db reset`) |
| Contract and e2e | 57 tests on local Supabase, PASS (2026-11-04, on the T6 commit) |

## Fitness functions and governance
| FF / rule | How it is checked |
|---|---|
| FF-ARCH-01 pure domain | green; the sentence model, the language guess and a PDF's reading text are in `domain` |
| FF-ARCH-04 UI isolation | green; pdfrx sits behind `pdf_adapter.dart` (the UI talks to `PdfViewControls`) and flutter_tts behind `tts_adapter.dart` (`TtsPort`); `infrastructure` reads PDF text with `pdfrx_engine` |
| FF-ARCH-06/09 | green; P05b adds no command (no record changes) |
| FF-ARCH-07 licenses | 174 shipped packages, all accepted; the PDFium notices checked against the locked pdfium_dart (new check, ADR-0075) |
| FF-ARCH-10 no raw UI strings | 44 left in 9 files, none above the baseline; the new screens have none |
| Store upgrade v16 → v17 | `pdf_search_test.dart` "v16 -> v17: the files of existing documents are listed and their PDFs read"; `profile_export_test.dart` and `execution_storage_test.dart` guard the schema; the owner's profiles upgraded on both devices in T6 |

## Universal DoD
| Line | Status |
|---|---|
| Builds on Windows and Android; analyze clean | the owner's release builds on both platforms (T6); `flutter build windows --debug` with nuget.exe (T4); `dart analyze` and `flutter analyze` clean in every package |
| All phase tests pass | foundation 13, time_kernel 92, domain 117, application 3, infrastructure 557 (4 skipped without the local stack; the 57 contract and e2e tests pass on it), ui 366, app 40; pgTAP 195 (local, 2026-11-04). CI green on every task branch except one infrastructure failure on T6 (below, R-CI-FLAKE) |
| Mutation checks on the new logic | run one at a time per task: T1 23/23, T2 22/22, T4 23/24, T5 11/12, T6 3/3. T4's one survivor is equivalent (a file block has no text to read); T5's (a stop before a dispose that stops anyway) led to removing that line. Some were killed only after tests were strengthened; each ADR says which |
| ADRs | 0075 (PDFium's bundled licenses, owner decision D10; ADR-0018 rule 8), 0076 (the PDF viewer), 0077 (the text of PDFs in search, schema v17), 0078 (reading aloud), 0079 (a PDF read aloud) |
| Open questions | OQ-DOC-3 resolved (PDF with pdfrx; no DOCX, PPTX or XLSX view) |

## Bugs found during P05b
1. **T1: the PDFium build hook did not build on Windows** with native_toolchain_c 0.19.2 ("'C:\Program' is not recognized"). Fixed by moving the build-hook toolchain to 0.19.6 and what it needs (all BSD-3-Clause, in the inventory).
2. **T1: FreeType's notice is Latin-1, not UTF-8**, and failed to load. Fixed: a notice that is not UTF-8 is read as Latin-1.
3. **T2 (from T1): the PDF was opened a second time** when the find bar and the page bar appeared in the same frame. Fixed by keying the viewer's slot (ADR-0077).
4. **T2: closing a session did not wait for its file work** (the sweep, reading PDFs), found by an older app test. Fixed: `AppWiring.close` waits for it.
5. **T6: search showed what was no longer there** (device check steps 14, 29, 30). The store was right; the Documents screen searched once and kept that answer after the trash, a move or another space shown. This had been the case for documents and tasks since P05a. Fixed: the results are searched again when the documents change (finding 2 of [p05b-device-check.md](p05b-device-check.md)).

## Device checks (T6, the owner, 2026-11-04)
All 31 steps of [p05b-device-check.md](p05b-device-check.md) were as expected on Windows and Android, after the fix of finding 2, which the owner checked again. This covered the PDF viewer, search in PDFs, and reading aloud in Vietnamese and English, alone and with a second account in a shared space.

Finding 1 (step 5): old Vietnamese PDFs, most likely in old font encodings without the font inside, show broken letters, as they do in other readers. **The owner accepts it as it is**; a conversion may come in a later phase if asked.

## Known limits carried out of P05b
- No DOCX, PPTX or XLSX view; they stay files with "Save a copy" (D1, D2). No "open in another app" (D2).
- No OCR: a scanned PDF is not found by its words and has nothing to read aloud (D3).
- Old Vietnamese font encodings in PDFs show and read wrong (T6 finding 1).
- Reading aloud stops when leaving the page and pauses in the background (D6). On Windows it goes sentence by sentence (no word events).
- The language of a document is guessed as Vietnamese or English only; any voice can be picked by hand.
- In a PDF, the sentence read is shown in the bar, not on the page.
- The text of a PDF is searched only on the device that has the file (C3).
- A PDF up to 25 MB is held in memory while shown or read.
- The Windows build needs nuget.exe; builds download PDFium and C++/WinRT the first time.
- CI builds no Windows app (as before).

## Risks
- **R-VIEWER-LICENSE** (new, the main risk): every notice read; the owner's decision (ADR-0075); the notices ship and FF-ARCH-07 checks them. Register updated.
- **R-FLUTTER-PLUGIN**: pdfrx pinned at 3.0.0 for Flutter 3.47.2; flutter_tts works on both platforms (T6). Register updated.
- **R-BUILD-DOWNLOAD** (new): PDFium pinned and hash-checked; nuget.exe documented. Register updated.
- **R-PRIVACY**: LF-INV-FILE-001 tested, including a planted leak. Register updated.
- **R-CI-FLAKE**: one failure in P05b, on the T6 branch, in starting the local stack in CI before any test ran; the log could not be read without signing in. pgTAP and the contract tests passed locally on that commit, and the T7 branch, with the same code, is green. Register updated.
- **R-SCOPE**: DOCX, PPTX, XLSX, OCR, background reading and cloud voices stayed outside P05b.

## Owner sign-off
- [x] Device checks above (owner, 2026-11-04).
- [ ] CI green on the T7 branch head.
- [ ] Owner approves P05b as done.
