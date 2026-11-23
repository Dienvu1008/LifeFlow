# ADR-0077: The text of PDFs in the one search

- Status: Accepted (P05b task T2, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05b-plan.md](../roadmap/p05b-plan.md) (the owner's D3)
- Related: [ADR-0067](0067-document-store-and-exact-search.md) (search by the exact spelling, the link index), [ADR-0071](0071-document-links-and-search.md) (one search, passages), [ADR-0072](0072-encrypted-attachments.md) (files on the device only), [ADR-0076](0076-pdf-viewer.md) (the PDF viewer), VS-49

## Context
D3: the text of the PDFs that are on this device goes into the one search, local, in the encrypted store, by the exact spelling (C4), and a hit says "in file.pdf, page 3". A scanned PDF has no text and is not found (no OCR). Files are encrypted, on this device only, and never synced (ADR-0072). The same file (by hash) can be named by several documents, in several spaces.

## Decision
1. **Reading the text.** `infrastructure` reads each page's text with PDFium through `pdfrx_engine` 0.9.3: the same engine and pin as ui's pdfrx (VS-49), started by the app before a session. The text comes from memory (`AttachmentService.open`), never from a path. It is read:
   - when a PDF is kept on this device (`PdfIndexingAttachments` wraps the attachment service);
   - at the start of a session, after the sweep, for every PDF a document names that is here and not read yet (a restore, a file kept by an older build). A profile with no files yet skips this.
   
   One PDF is read at a time. A search waits for the reads already started, so a PDF just added is found. A file that is elsewhere is never read. A PDF with a password, or one PDFium cannot open, is noted and not tried again. If the engine is missing, nothing is noted and the file is tried again in a later session.
2. **Where it is kept (schema v17, device-only).**
   - `pdf_text_fts`: FTS5, one row per page with text, by hash and page number. NFC, marks kept, case ignored, as all search text (ADR-0067).
   - `pdf_text_state`: the hashes read, with `indexed`, `locked` or `unreadable` and the page count.
   - `document_file_index`: the PDFs each document names (hash, name, size, type). `catchUpSearch` rebuilds it from the body, as it rebuilds the link index.
   
   All of these are in the profile's encrypted store. None is a record kind (not synced), and none is exported (`notExportedTables`). `recordSchemaVersion` stays 16. An export from this build says v17, so an older build will not restore it, as with earlier schema steps.
3. **How long.** The text of a file lives as long as the file is on this device. At the start of a session, after the sweep has removed files nothing names, the text of every file no longer here is dropped.
4. **Found only through a document.** A PDF page matches only through a live document (not in the trash) of the shown space that names the file. The same PDF in two documents gives a hit in each, under the name each document gave it. Taking the file out of a document removes its hits there.
5. **The port.** `SearchResults.files` holds `FileHitView` items (the document, its title, the file, the page, a passage with its matches), best first, one per document, file and page, at most `limit`.
6. **The UI.** Search in Documents shows an "In PDF files" section. Each hit reads "file.pdf, page 2", then "In “Document”" and the passage with the words in bold. Tapping it opens the PDF page at that page, with the searched words in the find bar and highlighted ("1 match"), without jumping elsewhere (`find(…, go: false)`). The page bar and the find bar can appear in the same frame. The viewer's slot is now keyed, so that never opens the PDF a second time (a bug found by this task's test).
7. **Closing a session** waits for its file work (the sweep, the reading of PDFs) before closing the store (`AppWiring.background`).
8. **Tests only:** `pdf` 3.13.1 (Apache-2.0) is a dev dependency of infrastructure, used to make real PDFs with Vietnamese text in the bundled Be Vietnam Pro font. It is not shipped.

## Consequences
- Adding a large PDF costs a read in the background: about 0.6 s for 300 pages (S-08). The first search after it may wait for that.
- The index grows with the text of the PDFs on the device, in the encrypted store.
- A scan has pages without text: it is not found by its words (no OCR, D3). Its name in the document is still found as document text.
- Another device, or another member, does not find the words of a PDF it does not have.

## Verification
- `infrastructure/test/pdf_search_test.dart` (11 tests, real PDFs, PDFium):
  - a Vietnamese word on page 2 of a PDF just added is found "in biên bản.pdf, page 2", with its passage and matches;
  - exact spelling: NFD and half-decomposed typing are found, case is ignored, other marks are not;
  - not from the trash, not after the file is taken out, not from a space that is not shown, found in the shown space;
  - two documents with the same PDF give two hits, each with its own name;
  - a file elsewhere is looked for but never read and not noted; one kept without being read is read at the next catch-up, once, and not decrypted again;
  - the text goes when the file leaves the device;
  - a damaged PDF and one with a password are noted and not read again; with no engine it is tried again;
  - text that comes back decomposed is indexed in NFC; the same PDF kept twice is read once;
  - a picture or a DOCX is never read;
  - the new tables are not exported;
  - the v16 → v17 upgrade lists the files of existing documents.
- `ui/test/pdf_flow_test.dart`: a hit shows where it is, and opens at its page with the words highlighted and the PDF opened once.
- `apps/lifeflow_app/test/pdf_integration_test.dart`:
  - in the real app, the PDF's word is found under "In PDF files", and the hit opens at page 2 with "1 match";
  - neither the PDF's text nor its indexed (lowercase) form is in the clear anywhere under the app's folder;
  - a PDF kept but not read is read when the next session opens.
- Mutations: 22, run one at a time, all killed. Three were killed only after tests were strengthened: a file read before is not decrypted again; a file elsewhere is never read; the upgrade notes the documents again.
