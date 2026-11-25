# P06 T8: the assistant on the owner's devices

The owner's check of P06 on real devices: Windows and Android, the same account A, signed in, with sync on (the history syncs, D7). Step 24 also needs a shared space, as in P05a.
- Build: `main` at `a83a24f` (T1–T7 merged), plus this branch `p06/t8-device-check` (the provider terms links).
- Plan row: [p06-plan.md](../roadmap/p06-plan.md) T8.
- Status: **to do**.

What tests could not cover, and this check does:
- the real models and their speed on each device;
- the native runtime in a release build;
- the file dialog;
- the clipboard;
- the history synced between two devices;
- how it all looks and reads.

## Setup
- **Builds.** As for P05b (nuget.exe on the PATH for Windows):
  - `flutter build windows --release --dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`
  - `flutter build apk --release --split-per-abi` with the same defines; install `app-arm64-v8a-release.apk`.
  
  The first build downloads the llama.cpp runtime (pinned by llamadart), so it must be online.
- **Keys.** The Groq and Gemini keys used in S-18. They are typed into the app in step 15, not set in the environment.
- **Data in the personal space of A** (made on Windows, synced to Android). Use tomorrow's date:
  - two events: "Họp nhóm dự án" 09:00–10:30 and "Ăn trưa với khách hàng" 12:00–13:30;
  - a task with a time: "Khám răng" 15:00–16:00;
  - four open tasks with no time: "Viết báo cáo quý", "Gọi điện cho mẹ", "Đi chợ mua đồ nấu phở", and "Nộp quỹ khuyến học" with the notes "Nộp 100.000 đồng cho chị Lan trước 30/11";
  - a document "Biên bản họp tổ dân phố" with a few Vietnamese paragraphs (the S-17 text will do), and a Vietnamese PDF attached to it (P1 from P05b).
- **Free space.** About 1.5 GB on Windows for the 2B model, about 0.6 GB on the phone if you try the 0.8B there.

## Steps and results
| # | Where | Step | Expected | Result |
|---|---|---|---|---|
| 1 | Windows | Settings → Open-source licenses | "llama.cpp (local models, used by llamadart)" with its notices (llama.cpp, cpp-httplib, nlohmann json, stb_image, miniaudio, subprocess.h, Vulkan and SPIR-V headers) | |
| 2 | Windows | Settings → Assistant | "Try first: the model on this device"; three models: Qwen 3.5 2B "Recommended", 4B, 0.8B, each with size, Apache-2.0 and memory; "Cloud model" off | |
| 3 | Windows | Download Qwen 3.5 2B | A dialog with the size first; then "Downloading… n%"; at the end the model is "In use" | |
| 4 | Windows | Start the 4B download, cancel it at about 20%; start it again | Cancel stops it; the second start continues from where it stopped (the percentage does not go back to 0); delete the 4B afterwards if you do not want it | |
| 5 | Windows | "Use a model file" → the 0.8B file from S-17 (`%LOCALAPPDATA%\llamadart\models\…\Qwen3.5-0.8B-Q4_K_M.gguf`) | It is copied and recognised as "Qwen 3.5 0.8B" (by its hash), not as "Your own file"; then "Use" the 2B again | |
| 6 | Windows | Calendar → the day view of tomorrow → the assistant button | The assistant opens with "Day: <tomorrow>"; the history is empty | |
| 7 | Windows | "Plan my day" | The first time the model loads (some seconds), then a proposal in about 30 s: each of the four tasks between 08:00 and 18:00, none over the meeting, the lunch or "Khám răng", and none over each other. Some may say "(đã chỉnh để không trùng giờ)". "On this device · Qwen 3.5 2B" | |
| 8 | Windows | Read the note and the summaries | Vietnamese, sensible; important tasks earlier. **Please judge the quality** | |
| 9 | Windows | Approve one change with ✓, dismiss one with ✕, then "Approve all" | Each shows Applied or Dismissed; the Calendar shows the approved tasks at those times, without a conflict mark | |
| 10 | Windows | Plan the day again; before approving, rename one of its tasks in the Overview; then approve that change | "Out of date: something changed since"; nothing changed for that task; "Regenerate" gives a new proposal in the same conversation | |
| 11 | Windows | Move "Khám răng" to 10:00–10:45 (over the meeting) → assistant → "Fix conflicts" | A proposal moves "Khám răng" to a free time; approved, the conflict is gone | |
| 12 | Windows | Open "Biên bản họp tổ dân phố" → the assistant button → ask "Hạn nộp quỹ khuyến học là ngày nào, nộp cho ai?" | The answer appears as it is written: 30/11, chị Lan; "On this device · …" | |
| 13 | Windows | Open P1 → the assistant button → ask a question about its content; ask again and press Stop while it writes | An answer from the PDF's text; Stop ends it, the part written stays | |
| 14 | Windows | The assistant page → History | Each conversation of steps 7–13, newest first; opening one shows the questions, answers and proposals with their statuses | |
| 15 | Windows | Settings → Assistant → turn the cloud model on → Groq → "How Groq uses your data" | The link is copied ("Link copied…"); paste it in a browser: Groq's data page opens. Read what it says about training and retention | |
| 16 | Windows | Type the Groq key → "Save the key" → leave the page and come back | "A key is saved for this provider"; the key is not shown anywhere | |
| 17 | Windows | "Load the models" → choose `qwen/qwen3.8-27b` → Save; "Try first: the cloud model" | The model list comes from Groq | |
| 18 | Windows | Plan tomorrow again (new open tasks if all were placed) | **The consent sheet**: "Nộp quỹ khuyến học" and the other tasks listed as Private, waiting for consent. Nothing sent yet | |
| 19 | Windows | "Send without these" | Nothing is sent: "No model you allowed may receive this data, so nothing was sent." (every task needed consent) | |
| 20 | Windows | Plan again → "Send" | A proposal in a few seconds: "Cloud · groq:qwen/qwen3.8-27b"; times as in step 7 | |
| 21 | Windows | Settings → Assistant: the tokens used this month; set the limit to 100 → plan again | The used tokens are shown; with the limit: "This would go over your monthly token limit, so it was not sent." Then clear the limit | |
| 22 | Windows | Gemini: its terms link, its key, `gemini-flash-lite-latest`; ask about the document | An answer, "Cloud · gemini:…". If Gemini says it is busy: "The provider asks to wait a moment" | |
| 23 | Windows | Turn the cloud off; ask about the document again | It goes to the model on this device, without asking | |
| 24 | Windows | Show a shared space → the assistant on the Calendar → "Plan my day" | "The assistant works in your personal space only." Nothing sent | |
| 25 | Windows | History → delete a conversation → Undo | It goes and comes back | |
| 26 | Android | Sync; open the assistant from the Calendar | The history of Windows is there (D7), with the same statuses | |
| 27 | Android | Settings → Assistant | Only Qwen 3.5 0.8B, marked "Slow on this device: not recommended"; the cloud is off and the Groq key is **not** there: the assistant's settings and keys stay on each device (only the history syncs) | |
| 28 | Android | Download the 0.8B | First the warning "Local models are slow on phones…"; "Download anyway" downloads. Optional: try "Plan my day" on the device to see the time (several minutes is expected, S-17) | |
| 29 | Android | Type the Groq key; plan tomorrow with the cloud, consenting | A proposal in a few seconds; approve one; sync; Windows shows it applied | |
| 30 | Android | Ask about P1 with the cloud | The answer from the PDF's text | |
| 31 | Both | Note the app size: the Windows folder, the installed Android app | About 104 MB on Windows, about 60 MB for the arm64 APK (S-17's probe: 170 and 116) | |

## Findings
(Filled in from the owner's results.)
