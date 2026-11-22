# ADR-0076: The PDF viewer (pdfrx behind an adapter)

- Status: Accepted (P05b task T1, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05b-plan.md](../roadmap/p05b-plan.md) (the owner's D8, D9, D10)
- Related: [ADR-0072](0072-encrypted-attachments.md) (files encrypted, on the device only), [ADR-0073](0073-documents-ui-and-editor-adapter.md) (the editor adapter, the same pattern), [ADR-0075](0075-pdfium-bundled-licenses.md) (PDFium's licenses), [ADR-0018](0018-dependency-license-policy.md), spike S-08 in [spike-results.md](../spikes/spike-results.md), VS-49

## Context
A PDF kept in a document was a file with "Save a copy" (P05a). P05b shows it inside the app on Windows and Android (exit gate §1). S-08 chose `pdfrx` 3.0.0 (MIT, PDFium): it opens from bytes, renders, selects, finds text, and extracts Vietnamese text correctly. 3.1 needs Flutter 3.50; the project is on 3.47.2. The files are encrypted on the device and `AttachmentService.open` gives their bytes in memory (ADR-0072); nothing may be written in the clear that the person did not ask for (proposed LF-INV-FILE-001).

## Decision
1. **Where a PDF opens (D8).** From the file in a document: when the file is on this device and is a PDF, its tile opens the PDF page (tap, or the reader button). "Save a copy" stays. A PDF from another device stays "On another device". `fileViewOf` (application, the first part of the `FileViewer` port of document-knowledge.md §6) says how a file is shown: a picture, a PDF (`application/pdf`, or a `.pdf` name when the type is generic), or not at all. A DOCX is not shown (D1). The text part of the port (search, reading aloud) comes in T2.
2. **pdfrx behind an adapter.** Only `ui/lib/src/documents/pdf_adapter.dart` imports pdfrx. The PDF page talks to `PdfViewControls` (`pdf_view.dart`): pages, the page shown, go to a page, zoom in and out, find with a match count and next or previous, the selection, whether copying is allowed. The view comes from `pdfViewBuilderProvider` (pdfrx by default; a fake in widget tests). The app starts the engine once at startup (`initPdfViewer`); if it fails, the app still starts and a PDF says it cannot be opened.
3. **Memory only.** The page gets the bytes from `AttachmentService.open` and gives them to `PdfViewer.data`. No path, no temporary copy. pdfrx's cache folder (the app's cache) holds fonts only. A link inside a PDF does nothing (nothing leaves the device).
4. **The page.**
   - Scrolling, zoom in and out, previous and next page, "Page 3 of 12".
   - Find (the search button or Ctrl+F; Escape closes): ignoring case, "2 of 5", previous and next go to the match's page, "No matches". Closing clears the highlights.
   - Copy the selected text (a button when text is selected, and pdfrx's own menu). A PDF whose permissions forbid copying says so.
   - Password: pdfrx first tries none, then the page asks in a dialog, again after a wrong one ("That password is not right"). Giving up shows "This PDF opens only with its password" with "Try again". Each try is a new source for pdfrx, which shares a loaded document by its source name.
   - A damaged file: "This PDF cannot be opened".
5. **The last page (D9)** is a device setting in the encrypted registry: `SettingsService.lastPdfPage(hash)` / `setLastPdfPage`, key `pdf.page.<hash>`. It is keyed by the file's content hash, so the same PDF opens at its page wherever it is attached. It is saved 1 s after the page changes and on leaving the page; never synced or exported. The registry is shared by the device's profiles: a profile could only learn that another opened a PDF if it holds the same file.
6. **Licenses.** pdfrx and the 9 packages it brings are in the inventory (VS-49). The PDFium notices of the four archives the app ships (Windows x64, Android arm, arm64, x64) are fetched and hash-checked by `tools/licenses/fetch_pdfium_notices.ps1`, stored in `apps/lifeflow_app/assets/licenses/pdfium/` with a `SOURCE` file, and listed under Settings → Open-source licenses with the FTL and IJG credit lines (ADR-0075). The Android archives carry three notices more than the Windows one (catapult, cpu_features, libunwind), all under licenses already accepted. FF-ARCH-07 fails when pdfium_dart is shipped and the notices are missing, lack one ADR-0075 names, or come from another pdfium_dart version.
7. **Build.** `archive` moves to 4.7.1 (pdfrx's `image` needs it). The build-hook toolchain in the app's lock moves too (`native_toolchain_c` 0.19.2 → 0.19.6 and what it needs): with 0.19.2 the hook could not compile pdfium_dart's small C helper on Windows. CI downloads the PDFium binary during the build (pinned hash, by pdfium_dart).

## Consequences
- The app grows by the PDFium binary: 7.2 MB on Windows, 4–7 MB per Android ABI (S-08).
- A PDF up to 25 MB (the attachment limit) is held in memory while shown.
- The FileViewer port is split: what can be shown now, the text in T2.
- A scanned PDF shows but has no text to find or copy (no OCR, D3).

## Verification
- `ui/test/pdf_flow_test.dart` (10 tests, fake view): only a PDF opens; the view gets the very bytes `open` gave; pages and zoom; it opens at the remembered page, which is saved after the delay and on leaving; find (counts, next and previous with wrap-around, none, close); Ctrl+F and Escape; copy and a PDF that forbids it; a wrong password then the right one; giving up and Try again as a new source; a damaged PDF; a file gone since; `fileViewOf`.
- `ui/test/pdfrx_adapter_test.dart` (3 tests, the real engine and a real PDF): opens from bytes, pages, find across pages ignoring case, next match, clearing, go to a page; opens at the page asked for; a file that is not a PDF is reported unreadable.
- `apps/lifeflow_app/test/pdf_integration_test.dart`: in the real app, a PDF attached in the UI opens with the real engine, find moves to page 2, **no file under the app's folder or the engine's cache folder contains the PDF's text**, the page is remembered in the registry and the PDF opens there again.
- `apps/lifeflow_app/test/licenses_test.dart`: the 21 PDFium notices are registered, in full, after the credits; FreeType's Latin-1 text is read as such.
- `infrastructure/test/overview_test.dart`: the last page round trip, ignored below 1, bad values fall back.
- `tools/fitness/ff_arch_07_test.dart`: 6 new cases for the PDFium notices.
- Mutations: 23 run one at a time, all killed (one only after a test was added: Try again as a new source). One was a planted leak: the adapter writing the PDF to the engine's cache folder fails the integration test. Not covered headless: the real engine's password path (no encrypted PDF fixture); checked on the devices in T6.
