# ADR-0078: Reading a document aloud (TtsPort, flutter_tts)

- Status: Accepted (P05b task T4, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05b-plan.md](../roadmap/p05b-plan.md) (the owner's D4–D7)
- Related: [document-knowledge.md](../domains/document-knowledge.md) §6 (`TtsPort`), [ADR-0073](0073-documents-ui-and-editor-adapter.md) (the editor adapter), [ADR-0018](0018-dependency-license-policy.md), spike S-12 in [spike-results.md](../spikes/spike-results.md), VS-50

## Context
D4–D7: a LifeFlow document is read aloud with the device's voices only. Vietnamese is read when the device has a Vietnamese voice; otherwise the app says which language it lacks and how to add one. The sentence being read is shown. There are controls for read, pause, stop, previous and next sentence, and a speed from 0.5× to 2×. The speed and the voice are remembered on the device. Reading stops when the person leaves the page or the app goes to the background (no background reading, D6). S-12 chose `flutter_tts` 4.2.5 (MIT). Windows sends no word progress events, so reading goes one sentence at a time.

## Decision
1. **The sentence model (domain, pure, `reading.dart`).**
   - `readingOf(body)` gives the sentences of every block with text, in order. That covers paragraphs, headings, list items, to-dos, quotes and code; a file is skipped. Each sentence keeps its block id and its offsets in the block's text.
   - A sentence ends at `.`, `!`, `?` or `…` followed by a space or the end of the block, with closing quotes and brackets kept. It also ends at a line break. "3.5" and "lifeflow.app" do not end one.
   - A sentence over 300 characters is cut at a comma, else at a space.
   - `readingLanguageOf(body)` returns `vi` when at least one word in seven has a letter only Vietnamese uses, or a combining tone mark; otherwise `en`. Only these two languages are told apart in P05b.
2. **The port (application, `TtsPort`).**
   - `voices()` lists the device's voices.
   - `speak(text, voice, speed)` completes when the sentence was read (true) or stopped (false).
   - `stop()` stops at once.
3. **The adapter (ui, `tts_adapter.dart`)** is the only file that knows flutter_tts.
   - The speed is mapped per platform from the plugin's source: Android takes value × 2, so 0.5 is its normal pace; Windows takes value + 0.5 as WinRT's SpeakingRate.
   - A sentence ends on the completion or error event. The cancel event is ignored: it follows our own `stop()`, and it could arrive after the next sentence has started.
   - Widget tests use a fake through `ttsPortProvider`.
4. **The reader (ui, `ReadAloud` and `ReaderBar`), opened by "Read aloud" on a document.**
   - The document is saved first. Then its text, as shown, is read from the current sentence to the end, one sentence at a time.
   - The sentence being read is selected in the editor, which scrolls to it. The editor reads only while the reader is open, so nothing typed can shift the sentences. Reading changes and saves nothing.
   - Pause stops the voice; reading again starts that sentence over. This works the same on every platform, without relying on the plugin's pause.
   - Stop returns to the start.
   - Previous and next move by one sentence. While reading, they read that sentence; while paused, they only move.
   - Speed: 0.5, 0.75, 1, 1.25, 1.5 or 2×.
   - Voice: any of the device's voices can be picked.
   - "Sentence 3 of 12" is shown. If the voice fails on a sentence, reading pauses there and says so.
5. **Voices and language (D5).**
   - The voice used is the one chosen on this device for the document's language. Otherwise it is the first voice of that language.
   - With none, the reader says "This device has no Vietnamese voice" and how to add one. On Windows: Settings → Time & language → Speech → Add voices. On Android: Text-to-speech output, then the engine's voice data. Another voice can still be picked.
   - With no voices at all, or no text, the reader says so and nothing can be read.
6. **Device settings (D7)** are kept in the encrypted registry, never synced or exported:
   - `tts.speed`, between 0.5 and 2 (1 by default);
   - `tts.voice.<language>`, the voice's name.
7. **Leaving (D6).** Leaving the page stops the reading. The app going to the background (hidden or paused) pauses it, and it does not start again by itself. A window that only loses focus on Windows (inactive) does not pause it.
8. **Build and licenses.**
   - flutter_tts 4.2.5 is MIT (VS-50).
   - Its Windows build needs `nuget.exe` on the PATH. It fetches Microsoft.Windows.CppWinRT 2.0.210503.1 (MIT) and compiles it into the plugin, so that LICENSE ships in `assets/licenses/cppwinrt` and is listed with the other licenses.
   - The Android manifest declares the `TTS_SERVICE` intent query (package visibility on Android 11+).
   - CI builds no Windows app yet, so nothing changes there.

## Consequences
- On Windows the highlight moves sentence by sentence (no word events). The same is done on Android for one behaviour.
- A document in another language (French, for example) is treated as English for the choice of voice; any voice can be picked by hand.
- The owner must add a Vietnamese voice on Windows ("Microsoft An") to hear Vietnamese; S-12 had only English voices on this PC. The listening check is in T6.
- Building on Windows needs nuget.exe (for example `winget install Microsoft.NuGet`).

## Verification
- `domain/test/reading_test.dart` (9 tests): how sentences end, closers, not inside numbers or names, line breaks; offsets exact on 300 random texts; long sentences cut under the limit; blocks in order with files and empty blocks skipped; a sentence across runs; the language guess, typed composed or decomposed.
- `ui/test/read_aloud_flow_test.dart` (11 tests, fake voices):
  - read sentence by sentence, each selected in the editor, which reads only; nothing saved; closed it is editable again;
  - pause and stop;
  - previous and next, reading or paused;
  - speed and voice remembered, and the sentence started over with them;
  - an English voice for an English document;
  - no Vietnamese voice, with the Android and the Windows instructions, and another voice picked;
  - no voices, nothing to read, a failing voice;
  - leaving the page stops and the background pauses.
- `ui/test/quill_adapter_test.dart`: every sentence is at its offset in the Quill document (files, links); the speed mapping per platform.
- `infrastructure/test/overview_test.dart`: speed and voices round trip, clamped, bad values fall back.
- `apps/lifeflow_app/test/licenses_test.dart`: the C++/WinRT notice is listed.
- The Windows app builds with flutter_tts and nuget.exe (`flutter build windows --debug`, 2026-11-04).
- Mutations: 24 run one at a time. 23 were killed, two of them only after tests were added: a pause is not a failure, and a file between text blocks. One is equivalent: a file block has no text, so not skipping it reads nothing.
- Not covered headless: the real voices. The owner listens on Windows and Android in T6, Vietnamese included.
