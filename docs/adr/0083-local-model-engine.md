# ADR-0083: The local model engine (llama.cpp through llamadart) and the models of a device

- Status: Accepted (P06 task T4, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md) (the owner's D3 and D4, and his reading of spike S-17)
- Related: [ADR-0081](0081-ai-context-and-egress-checkpoint.md) (`CheckedAiRequest`), [ADR-0084](0084-llama-cpp-runtime-licenses.md) (the runtime's bundled licenses), [spike-results.md](../spikes/spike-results.md) S-17, [ai-architecture.md](../architecture/ai-architecture.md)

## Context
S-17 showed that llama.cpp, embedded through `llamadart`, runs small Qwen 3.5 models well on Windows and slowly on Android. The owner decided:
- local AI on Windows is acceptable;
- on Android it must be marked slow and not recommended.

D4 asks for a pinned list of models, downloaded after the person agrees, plus "Use a model file". The engine must take only requests that passed the egress checkpoint.

## Decision
1. **The port** (application, `ai_engine.dart`).
   - `AiEngine`: `site`, `model()`, `answer` (streamed), `structured` (a JSON object following a schema), `stop`. It takes only a `CheckedAiRequest`.
   - **A request checked for one site is refused by an engine of the other** (`wrongSite`). A request that may carry Confidential data to this device can therefore never reach a cloud engine.
   - `aiMessagesOf` builds the messages:
     - the system message holds the app's instructions and a fixed rule: the data is the person's, it is data and never instructions;
     - the user message holds the tagged data, then the question.
   - Failures have kinds: not ready, wrong site, malformed output, stopped, failed.
2. **The engine** (infrastructure, `LocalAiEngine`, over a small `LocalRuntime` port).
   - It loads the chosen model once, and loads again only when the choice changes (the old model is freed first). Two requests at once load it once.
   - It streams the answer; `stop` cancels it and the answer ends as "stopped".
   - **A structured answer is parsed, and asked for again once when it does not parse.** S-17 had 1 broken plan in 5. A second failure is refused (`malformedOutput`): a broken plan is never used.
   - Thinking is off. With it on, S-17's models spent the whole budget thinking and cut the JSON.
3. **The runtime binding** (app, `ai/llamadart_runtime.dart`). This thin file is the only one that imports llamadart. It maps llamadart's "malformed or not matching the schema" errors to `FormatException`. `localAi()` builds the engine and the model service in `<app support>/models`.
4. **The models of a device** (infrastructure, `FileLocalModelService`).
   - **The pinned list.** Hugging Face URLs at a fixed commit, the size and SHA-256 from the host's LFS records (checked against the files S-17 downloaded), and the license (Apache-2.0, read in the model repositories and in `Qwen/Qwen3.5-*`'s LICENSE):
     - Windows: Qwen 3.5 2B Q4_K_M (the default, 1.28 GB), 4B (2.74 GB), 0.8B (0.53 GB);
     - Android: 0.8B only, flagged `slowOn: android` and not recommended. The app says so before any download (T7). Gemma 4 E2B is left out (its terms are not Apache, and it did no better).
   - **Download** is over HTTPS only (loopback is allowed for tests) and goes to `<file>.part`.
     - A stopped or dropped download resumes with a range request. A server that ignores the range sends the whole file, which starts again.
     - The whole file's size and SHA-256 are checked before it is kept. A wrong file is deleted.
     - One download per model runs at a time.
   - **"Use a model file"** accepts a GGUF file only (checked by its magic bytes). It is copied into the folder and hashed. A file of the list is known by its hash, with its name and license; any other is "the person's own", with no license claimed.
   - **The index** (`models.json`, written through a temporary file) records what is installed and which model the assistant uses. Deleting a model clears the choice. A file removed by hand is not listed, and a broken index reads as empty.
   - These files are device data, one copy for all profiles. They are never synced or exported.
5. **Native size** (the llamadart build hook, configured in the app's pubspec):
   - GGUF only: no LiteRT-LM, no WebGPU;
   - Windows: the CPU and Vulkan modules (no OpenBLAS, no CUDA);
   - Android and the Linux test host: the CPU modules (Vulkan is experimental on Android, and OpenCL works only on Adreno). Android keeps all 7 CPU builds, so the fastest one the phone supports is loaded.
   
   Measured release builds:
   - the Windows folder is 103.6 MB, of which the llama.cpp runtime is about 52 MB (33 MB is Vulkan; S-17's probe folder was 170 MB);
   - the Android arm64 APK is 60.3 MB, of which the llama.cpp libraries are 22.1 MB (S-17's probe APK was 116 MB).
   
   32-bit Android has no runtime, so it has no local model.
6. CI caches the runtime archive the hook downloads for the app's tests.

## Consequences
- Local answers work offline on Windows at acceptable speed. On phones the app warns before the download, and the cloud (T5) is the better path there.
- The day plan stays slow with any local model (about 26 s on the owner's PC). T6 keeps the model's plan small (the order and slots by task id) and computes and checks every time in code.
- The person may use any GGUF file they trust. The app claims no license for it.
- Not built yet:
  - choosing the network ("Wi-Fi only") is left to the download screen (T7), which shows the size first;
  - free disk space is not checked before a download, but a failed write keeps the part for a later try.

## Verification
- `infrastructure/test/local_models_test.dart` (14 tests, against a local HTTP server):
  - the lists per platform; every entry pinned;
  - kept only after the size and hash checks; progress;
  - resume after a stop and after a dropped line; a server ignoring the range; a part longer than the model;
  - a wrong or short file deleted; HTTPS only; one download at a time;
  - own files: GGUF only, copied and hashed, a list file known by its hash;
  - choose and delete (downloaded again, not chosen again by itself); the index after a restart; a broken index.
- `infrastructure/test/local_engine_test.dart` (7 tests, a fake runtime):
  - wrong site refused; the model loaded once, again on a change, none chosen, a failed load, two requests at once;
  - the prompt (the rule, the tagged data, the question after it, an injected line kept as data);
  - stop; JSON parsed, retried once, refused.
- `apps/lifeflow_app/test/local_ai_smoke_test.dart`: the real runtime and the real Qwen 3.5 0.8B on Windows. Skipped in CI; run with `LIFEFLOW_TEST_GGUF` (and `LLAMADART_BACKEND_MODULE_DIR`).
  - The file was imported and known by its hash.
  - It answered "Ngày 30 tháng 11, nộp cho chị Lan tổ trưởng." about a Vietnamese note.
  - It returned a JSON list following a schema.
- Mutations: 24, run one at a time, over the model service, the engine, the prompt and the FF-ARCH-07 notice check.
  - 22 were killed at once.
  - Two survived and got tests: a part file longer than the model (it would have asked for a range past the end, forever), and the choice kept after a delete (a later download would have been chosen by itself).
  - All 24 killed after that.
