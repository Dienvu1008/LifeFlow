# P05b plan: viewers and reading aloud

- Status: **Proposed (2026-11-04); waiting for the owner's decisions (D1–D10, §3)**
- Date: 2026-11-04
- Inputs: [p05-plan.md](p05-plan.md) (P05b split off at P05a's start), [p05a-exit-gate.md](../testing/p05a-exit-gate.md), [document-knowledge.md](../domains/document-knowledge.md) §6 (`FileViewer`, `TtsPort`, `SelectionAdapter`; OQ-DOC-3), [spike-plan.md](../spikes/spike-plan.md) (S-08, S-09, S-12), [technical-stack.md](../architecture/technical-stack.md) (viewers and TTS not chosen yet), [ADR-0018](../adr/0018-dependency-license-policy.md), [ADR-0072](../adr/0072-encrypted-attachments.md) (files encrypted, on the device only), [ADR-0074](../adr/0074-export-with-documents-and-files.md); use cases UC-10 (look up a word in a PDF: the lookup itself is P07)
- Estimate: about 12–18 person-days, plus a 30 % risk buffer. The spikes come first and may change the tasks.

## 1. Goal and exit gate

Goal: the files kept in documents can be read inside LifeFlow, and a document can be read aloud, on Windows and Android, offline, with license-clean libraries.

Exit gate (P05b):
- **A PDF attached to a document opens inside the app**: pages, zoom, page by page and scrolling, find in the PDF, text selection and copy; on both platforms.
- **DOCX** is handled as the owner decides in D1 (read inside the app, import as a LifeFlow document, or open in another app).
- **A document can be read aloud** with the device's voices, Vietnamese included, with play, pause or stop, speed, and the sentence being read shown.
- **Nothing leaves the device and nothing is written in the clear** that the person did not ask for: a file is decrypted in memory to be shown or read (ADR-0072). Every new library is in the license inventory (FF-ARCH-07).
- P05a's properties still hold (no change to how documents are stored, synced or shared).

Out of scope: looking up or translating a selected word (P07, through `SelectionAdapter`); speech recognition (P07); editing a PDF or a DOCX; PPTX and XLSX inside the app (see D2); syncing files (C3, a paid feature later); cloud voices.

## 2. Starting point (checked 2026-11-04)

- **Files** are encrypted on the device; `AttachmentService.open` returns the bytes in memory. Today a PDF shows as a file with "Save a copy".
- **PDF candidates** (pub.dev, 2026-11-04):
  - `pdfrx` (MIT), built on PDFium, for Android, iOS, Windows, macOS, Linux and web. It renders, selects text, finds text and opens from bytes. Version 3.1.0 needs Flutter 3.50; **3.0.0 is the newest for our Flutter 3.47.2**. It downloads a prebuilt PDFium at build time, which matters for CI and offline builds.
  - `pdfx` 2.11.0 (MIT), also PDFium on Windows. It renders pages as images; text selection is weaker.
  - Syncfusion and Apryse are commercial and excluded (ADR-0018).
- **PDFium's own licenses are not verified yet.** PDFium is BSD-3-Clause, but a binary bundles third-party libraries (for example FreeType, libjpeg, OpenJPEG, Little CMS, zlib). Some of their licenses (FreeType's FTL, the IJG license) are not in ADR-0018's accepted list. S-08 reads them; a license decision like P02's L-1 may be needed (D10).
- **DOCX**: no license-clean Flutter package renders DOCX inside the app on Windows. A DOCX is a zip of XML, and we already ship `archive`; the `xml` package (MIT) can read it. So a DOCX can be turned into LifeFlow's own block format (headings, paragraphs, lists, bold and italic, tables as text, pictures as files) and shown or edited with the editor that already exists. This is S-09.
- **Text to speech**: `flutter_tts` 4.2.5 (MIT) for Android, iOS, macOS, web and Windows, using the system voices. Windows has a Vietnamese voice ("Microsoft An") when the Vietnamese speech pack is installed; Android uses Google's TTS, which has Vietnamese. Open points for S-12:
  - an open issue reports a crash on Windows from messages sent off the platform thread;
  - word or sentence progress events on Windows;
  - pause on Windows.

## 3. Owner decisions (D1–D10)

| # | Question | Proposal |
|---|---|---|
| D1 | **DOCX** | **(b)**: a DOCX attached to a document opens read-only in LifeFlow's own view (converted to our block format in memory), with **"Make a LifeFlow document from it"**, which creates an editable copy, with a revision as usual. Other choices: (a) only "open in another app" (D2), or (c) import only, without a view. |
| D2 | **"Open in another app"** for files LifeFlow does not show (PPTX, XLSX, others) | **Not in P05b.** It needs a decrypted copy written to a temporary folder for the other app, which ADR-0072 avoids. "Save a copy" already lets you choose where. If you want it: the copy goes to the app's own temporary folder and is deleted when LifeFlow next starts. |
| D3 | **Search inside PDFs** | **Yes**: the text of PDFs that are on this device goes into the one search (local, in the encrypted store, by the exact spelling, C4), shown as "in file.pdf, page 3". A scanned PDF has no text and is not found (no OCR). |
| D4 | **What can be read aloud** | **LifeFlow documents and PDFs** (a PDF's text, from the page shown). A DOCX is read once it is shown in LifeFlow's view (D1). |
| D5 | **Which voices** | **The device's voices only**: offline, free, private. Vietnamese works when the device has a Vietnamese voice; otherwise the app says which language it lacks and how to add it (Windows: Settings → Time & language → Speech; Android: Google TTS). No cloud voices. |
| D6 | **Reading with the app in the background, or the screen off (Android)** | **Not in P05b**: reading stops when you leave the page or the app goes to the background. Background reading needs a foreground service, a media notification and its permission; it can come later. |
| D7 | **While reading** | The sentence being read is highlighted and the page follows it; play / pause / stop, back and forward a sentence; speed 0.5×–2×; the speed and voice are remembered on this device. |
| D8 | **Where viewers open** | **From the file in a document** (tap it). No separate "Files" list in P05b. |
| D9 | **Last page of a PDF** | **Remembered on this device** (a device setting, not synced): a PDF opens where you left it. |
| D10 | **PDFium's bundled licenses** (if S-08 finds ones outside ADR-0018) | **Decide after S-08** with the list in front of you, as for L-1 in P02. If refused: `pdfx` with the same binary has the same question; the fallback is no in-app PDF in P05b. |

## 4. Technical design (no owner input needed; ADRs during the tasks)

- **Ports** (`application`), as document-knowledge.md §6 planned:
  - `FileViewer`: what kind of file can be shown, and the text of a file (for search and reading), by its hash.
  - `TtsPort`: voices, speak, pause, stop, speed, and progress (what is being read).
  - The UI never sees PDFium or the TTS plugin directly; both sit behind adapters in the app or `ui`, as the editor does (ADR-0073).
- **Files stay encrypted.** A viewer gets the bytes from `AttachmentService.open` in memory, never a path. pdfrx opens from bytes. Nothing is written to a temporary folder.
- **PDF text for search (D3)**: extracted when a PDF is added on this device, or when the app finds one not indexed yet; kept in a device-only table (like the link index, not synced, not exported), by hash and page; NFC as all search text.
- **DOCX (D1)**: `docx_reader` in `infrastructure` turns `word/document.xml` (with `numbering.xml` and `styles.xml`) into a `DocumentBody`. Pictures become attachments of the new document only when it is imported. The reader is untrusted-input code: size limits, no external entities, never a path from the file.
- **Reading aloud**: the text to read is built from the blocks (domain, pure): sentences with their block and offsets, so the editor can highlight the one being read; lists and headings read as text; a file is skipped (or its name read).
- **Device settings**: speed, voice and the last page of each PDF, in the registry (as other device settings), never exported or synced.

## 5. Spikes and tasks

| Task | What | Proof | Your check | Days |
|---|---|---|---|---|
| **S-08** PDF | pdfrx 3.0.0 on Windows and Android: open from bytes, render, zoom, select and copy, find, extract text in Vietnamese (marks right?); a 300-page PDF; the build-time PDFium download (CI, offline); APK and Windows size; **every bundled license** | a probe app; results in spike-results.md | **yes**: the probe on your devices | 1–2 |
| **S-09** DOCX | sample DOCX files from Word and Google Docs, in Vietnamese (headings, lists, tables, pictures, comments, tracked changes) through a throwaway reader into our blocks; what is kept and lost | a list of what converts; results | no (samples from you welcome) | 1 |
| **S-12** Voices | flutter_tts 4.2.5 on Windows and Android: Vietnamese and English voices, speed, pause or stop, progress events, the Windows thread issue | a probe app; results | **yes**: listen on your devices | 1 |
| **T1** Viewer port and PDF | `FileViewer`, the PDF page (from a document's file), find, selection and copy, last page (D9) | widget tests with a fake viewer; an integration test with a real PDF | no | 2–3 |
| **T2** PDF in search | text extracted and indexed per page (D3) | search tests (Vietnamese PDF text, the exact spelling); a file elsewhere is not indexed | no | 1–2 |
| **T3** DOCX | read-only view and "Make a LifeFlow document from it" (D1) | reader tests on the S-09 samples; forged files refused | no | 2 |
| **T4** Reading aloud | `TtsPort`, the sentence model, the reader controls on a document (D7), the language check (D5) | domain tests; widget tests with a fake voice | no | 2–3 |
| **T5** PDFs read aloud | from the page shown (D4) | widget tests | no | 1 |
| **T6** On the devices | your Windows and Android: PDFs, DOCX, search, reading in Vietnamese and English | your check | **yes** | 1 |
| **T7** P05b exit gate | p05b-exit-gate.md, ADRs, invariants, risks; your review | all suites, CI | yes | 1 |

Order: S-08, S-09, S-12 (they can run together; S-08 decides D10) → T1 → T2 → T3 → T4 → T5 → T6 → T7.

## 6. Invariants and scenarios

- Proposed new: **LF-INV-FILE-001**: a file is decrypted only in memory to be shown, searched or read; it is written in the clear only where the person chose (Save a copy, an export).
- Proposed new: **GS-29** (a PDF kept in a document opens on both platforms, is found by a Vietnamese word in it, and no clear copy appears on disk), **GS-30** (a Vietnamese document read aloud on both platforms, the sentence followed, speed changed, stopped when leaving).

## 7. Risks

- **R-VIEWER-LICENSE** (new, main risk): PDFium's bundled libraries may fall outside ADR-0018. Mitigation: S-08 reads every license before any task; D10. Contingency: no in-app PDF in P05b, "Save a copy" as today.
- **R-FLUTTER-PLUGIN**: pdfrx's newest version already needs a newer Flutter; flutter_tts has an open Windows issue. Mitigation: pin versions (pdfrx 3.0.0), S-08 and S-12 on the owner's devices. Contingency: upgrade Flutter as its own task, or a smaller Windows TTS adapter.
- **R-BUILD-DOWNLOAD** (new): pdfrx fetches PDFium during the build. Mitigation: S-08 checks CI and an offline build; pin the binary's version and checksum if possible.
- **R-PRIVACY**: a viewer that wrote temporary files would leave clear copies. Mitigation: bytes in memory only (LF-INV-FILE-001), checked in GS-29.
- **R-SCOPE**: PPTX, XLSX, OCR, background reading and cloud voices stay outside P05b (D2, D3, D5, D6).
