# P05b T6: viewers and reading aloud on the owner's devices

The owner's check of P05b on real devices: Windows and Android, the same account A, signed in, with sync on. Steps 28–30 also need B in a shared space, as in P05a T10.

- Build: `main` at `869dd74` (T1, T2, T4 and T5 merged), from the branch `p05b/t6-device-check`.
- Plan row: [p05b-plan.md](../roadmap/p05b-plan.md) T6.
- Status: **waiting for the owner's run**.

The server needs nothing new for P05b. The text of PDFs, the last page and the reading settings live on each device only (ADR-0076, ADR-0077, ADR-0078).

## Setup
- **Windows build.**
  - The Windows build now needs `nuget.exe` on the PATH, for the reading-aloud plugin (ADR-0078). For example: `winget install Microsoft.NuGet`, then open a new terminal.
  - The build downloads PDFium (pinned, hash-checked) and C++/WinRT, so it must be online the first time.
  - `flutter build windows --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
- **Android build.** `flutter build apk --release` with the same two defines.
- **A Vietnamese voice on Windows.** Settings → Time & language → Speech → Add voices → Vietnamese ("Microsoft An"). Restart LifeFlow afterwards.
- **A Vietnamese voice on Android.** Settings → Text-to-speech output → Speech Services by Google (or the phone's engine) → Install voice data → Vietnamese.
- **Files.** Put them where the file dialog finds them on both devices:
  - **P1**: a PDF with Vietnamese text and several pages, for example the owner's tax form saved as PDF from Word.
  - **P2**: a PDF with a password. In Word: File → Save As → PDF → Options → "Encrypt the document with a password".
  - **P3**: a scanned PDF (pages that are pictures only), if one is at hand.
  - **D1**: a DOCX, for example the tax form.
  - A long English PDF, about 50 pages or more, if one is at hand.

## Steps and results
| # | Where | Step | Expected | Result |
|---|---|---|---|---|
| 1 | Windows | Settings → Open-source licenses | "PDFium (used by pdfrx)" with the FreeType and IJG credit lines and the notices; "C++/WinRT (Windows, used by flutter_tts)"; desugar_jdk_libs as before | |
| 2 | Windows | A new document "Hồ sơ thuế" → "Attach a file": P1, then D1 | P1 shows with a PDF icon, an open button and "Save a copy"; D1 shows only "Save a copy" (D1) | |
| 3 | Windows | Tap P1 | The PDF opens in the app: "Page 1 of N", pages render sharply, scrolling is smooth | |
| 4 | Windows | Zoom in and out with the buttons; previous and next page. Also try Ctrl + mouse wheel and a touchpad pinch | The buttons zoom; the page indicator follows; please note whether the wheel and the pinch work (they come from pdfrx, not tested here) | |
| 5 | Windows | Search button (or Ctrl+F): a Vietnamese word of P1, typed with your usual keyboard; then Unikey/EVKey and the built-in Vietnamese keyboard | "1 of N": the matches are highlighted, previous and next move between them; the same word typed either way is found; Escape closes the bar | |
| 6 | Windows | Select a sentence with the mouse → the copy button in the bar (also try Ctrl+C and the right-click menu); paste it in a document | The same text, Vietnamese marks right | |
| 7 | Windows | Go to page 3; back; open P1 again | It opens at page 3 (D9) | |
| 8 | Windows | Attach P2 to the document; open it; type a wrong password, then the right one | A password dialog; "That password is not right"; then the PDF opens (not covered by the headless tests: ADR-0076) | |
| 9 | Windows | Open P2 again → Cancel → "Try again" | "This PDF opens only with its password"; Try again asks again | |
| 10 | Windows | Documents → search: a Vietnamese word that is only in P1 (not in any document) | Under "In PDF files": "P1.pdf, page n", "In “Hồ sơ thuế”" and the passage with the word in bold | |
| 11 | Windows | Search the word without its marks (for example "thue" for "thuế") | Not found (exact spelling, C4) | |
| 12 | Windows | Tap the hit of step 10 | The PDF opens at that page, the word highlighted ("1 match" or more) | |
| 13 | Windows | If P3 is at hand: attach it; search a word you can see on it | Not found: a scan has no text (no OCR, D3) | |
| 14 | Windows | Move "Hồ sơ thuế" to the trash; search the word of step 10 again; restore it | Not found while in the trash; found again after | |
| 15 | Windows | A document in Vietnamese of a few paragraphs (from P05a) → "Read aloud" | The reader bar; voice "Microsoft An"; "Sentence 1 of N" | |
| 16 | Windows | Read | **Listen**: the Vietnamese is understandable, marks pronounced; the sentence being read is selected in the text and the page scrolls with it (**please say whether the selection is easy to see**) | |
| 17 | Windows | Pause, then Read; Next and Previous; speed 0.75× and 1.5× | Pause stops at once, Read starts that sentence again; Next/Previous jump; a new speed starts the current sentence again at that speed | |
| 18 | Windows | Pick another voice (an English one); close the reader; open it again | The voice and the speed are remembered | |
| 19 | Windows | An English document → Read aloud | An English voice (Zira, David or Mark) reads it | |
| 20 | Windows | While reading: minimize LifeFlow; bring it back | Reading paused; it does not start by itself | |
| 21 | Windows | While reading: leave the document (back) | The voice stops at once | |
| 22 | Windows | Open P1 at a middle page → "Read aloud" → Read | It reads from that page on; the sentence read shows in the bar; the page turns when the reading reaches the next page | |
| 23 | Windows | While a PDF sentence is read, scroll to another page | It is not pulled back until the next sentence starts | |
| 24 | Android | Sync; Documents → "Hồ sơ thuế" | P1, P2 and D1 show "On another device" (files are not synced, C3); searching the word of step 10 finds nothing on Android | |
| 25 | Android | Attach P1 here too (from the phone's storage); steps 3–7, 10 and 12 | Pinch-zoom, scrolling, find, selection with handles and copy, the last page, search in PDFs | |
| 26 | Android | Steps 15–19 with Google's Vietnamese voice | **Listen**: Vietnamese and English; the controls and the remembered voice and speed | |
| 27 | Android | While reading: press Home; come back. Then: lock the screen while reading | Paused in both cases (no background reading, D6) | |
| 28 | A Windows, B Android | A: move "Hồ sơ thuế" to the shared space | B sees it, with the files "On another device"; B finds nothing in the PDFs (B does not have them) | |
| 29 | A | Search the word of step 10 with the space shown, then with Personal shown | Found in the space; not in Personal (the document moved) | |
| 30 | A | Move the document back to Personal | Found again under Personal | |
| 31 | Both | If at hand: the long PDF; open it, search a word, read aloud from page 30 | Opens quickly; the first search after attaching may take a second or two; reading starts without a long wait | |

## Findings
None yet.
