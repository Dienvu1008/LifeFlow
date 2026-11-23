# ADR-0079: Reading a PDF aloud from the page shown

- Status: Accepted (P05b task T5, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05b-plan.md](../roadmap/p05b-plan.md) (the owner's D4, D6, D7)
- Related: [ADR-0076](0076-pdf-viewer.md) (the PDF viewer), [ADR-0078](0078-reading-aloud.md) (reading aloud, `TtsPort`), [ADR-0077](0077-pdf-text-in-search.md) (the text of PDFs)

## Context
D4: LifeFlow documents and PDFs can be read aloud, a PDF "from the page shown". T4 built the reader for documents (ADR-0078): one sentence at a time, with the device's voices. A PDF's text comes from PDFium page by page, with a line break wherever a line ended on the page.

## Decision
1. **What is read.** "Read aloud" on the PDF page reads from the page shown to the last page. The text is that of each page (`PdfViewControls.pageText`), taken from memory like everything else of the file (ADR-0072).
2. **The text as it is read (domain, `pdfReadingText`).**
   - A page's lines are joined with a space, so a sentence over two lines is one sentence.
   - A word cut by a hyphen at a line end is joined back. This happens only when a lower-case letter follows the hyphen; "Hà Nội-\nHuế" stays two words.
   - A blank line (a new paragraph) still ends a sentence.
   - `pdfReadingBody` makes one block per page (`page-<n>`), so each sentence knows its page (`pageOfReadingBlock`). The sentences, the language and the voice are then those of T4.
3. **The reader is the same as for documents.** The controls are read, pause, stop, previous and next sentence, speed and voice, and the speed and voice per language are remembered on the device.
4. **Showing the sentence.** A PDF page cannot be marked as the editor can. The sentence being read is shown in the reader bar instead, and the page turns to the sentence's page. It turns only when a new sentence starts, so the person can look at another page while a sentence is read. A restart of the same sentence (for example a speed change) leaves the page where it is.
5. **A scan** has no text. The reader says there is nothing to read (no OCR, D3).
6. **Leaving (D6).** Leaving the PDF page stops the reading, and the app going to the background pauses it, as for documents. Closing the reader stops the voice (through the reader's dispose).

## Consequences
- A PDF whose text PDFium gives in a strange order (columns, tables) is read in that order.
- Highlighting the sentence on the page itself would need text positions (pdfrx has them, through structured text). It is left out of P05b.

## Verification
- `domain/test/reading_test.dart` (2 new tests): lines joined, a hyphenated word joined, a dash between words kept, a capital not joined, a blank line ending a sentence; pages from the one shown and back to their page; a scan has nothing to read.
- `ui/test/pdf_read_aloud_test.dart` (4 tests, fake PDF view and voices):
  - read from the page shown (2 of 3), lines joined, the Vietnamese voice; the sentence shown in the bar; the page turned to 3 with the reading;
  - looking at another page is not undone within a sentence, nor by a restart at a new speed; the next sentence brings the page back;
  - an English PDF gets an English voice; closing stops; a scan has nothing to read;
  - the background pauses; leaving stops.
- `ui/test/pdfrx_adapter_test.dart`: a page's text from the real engine; none for a page that does not exist.
- Mutations: 12 run one at a time. 11 were killed, one only after a test was added: a restart of the same sentence leaves the page. One was equivalent: stopping before dispose, which stops anyway. That line was removed.
