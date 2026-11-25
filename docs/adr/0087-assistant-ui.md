# ADR-0087: The assistant in the app

- Status: Accepted (P06 task T7, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md) (the owner's D1–D10; the owner's call after S-17 on phones)
- Related: [ADR-0082](0082-ai-history-and-approved-changes.md), [ADR-0083](0083-local-model-engine.md), [ADR-0085](0085-cloud-model-engine.md), [ADR-0086](0086-assistant-orchestrator.md), [ui-ux-architecture.md](../architecture/ui-ux-architecture.md)

## Context
T3–T6 built the assistant behind ports. The person needs to reach it, see what it proposes and decide each change. They also need to see and approve what would be sent to a cloud model, read the history, and set up the models, the cloud and the limits.

## Decision
1. **Where it is.** The assistant is not a new tab; it opens from where its turns belong.
   - **Calendar**: a button "Plan this day with the assistant" opens it on the shown day (today in a week or month view).
   - **A document or a PDF**: a button "Ask the assistant" opens a question sheet about it (the whole PDF's text, within the context's bounds).
   - **Settings → Assistant**: models, cloud and plans.
   
   Every entry shows only where the app wires an assistant (ports null otherwise), so the parts without it are unchanged.
2. **The assistant page** has the day (changeable), an optional note for the plan, "Plan my day", "Fix conflicts", and "Stop" while it works.
   - The result is said plainly: nothing to plan, no conflict, no model set up, privacy (no allowed model may receive it), the personal space only, and each failure kind (no key, a rate limit, no connection, the cap, a refusal, an answer that could not be read).
   - **The proposal card** names the engine and model and says "Nothing changes until you approve it." Each change has its summary and status with approve or dismiss; "Approve all" appears when more than one is open (D8). A stale change offers "Regenerate", which plans again in the same conversation.
   - **The history** is listed newest first. A conversation opens with its messages and proposals (approvable there too), and a delete goes to the trash with Undo.
3. **The consent sheet (D6).** When a turn needs consent, the sheet lists the private items waiting, by title and class, and the items that are never sent. **Nothing is sent before the choice.**
   - "Send" consents to the waiting items for this request only.
   - "Send without these" consents to nothing and leaves them out.
   - "Cancel" sends nothing.
4. **Settings → Assistant**
   - **Try first**: the model on this device or the cloud model.
   - **Models on this device**: the pinned list for the platform with size, license and memory; "Recommended" on the default.
     - On a phone each model is marked "Slow on this device: not recommended". **A warning comes before any download** ("Local models are slow on phones… a cloud model with your own key works better here. Download anyway?"), the owner's call after S-17.
     - Elsewhere a dialog gives the size first.
     - The download shows progress and can be cancelled. The first model kept becomes the one in use. Models can be used or deleted.
     - "Use a model file" opens the app's file dialog (a path is typed where there is none), copies the file and uses it.
   - **Cloud model**: **off by default** (D2), with the rule said ("Private items are sent only with your consent; health data never").
     - The provider: OpenAI, Gemini, Anthropic, Groq, or an OpenAI-compatible address.
     - **The key**: typed in a hidden field, saved to secure storage, and never shown again ("A key is saved"); it can be forgotten.
     - The model: listed from the provider or typed.
     - The monthly token limit, with this month's tokens shown (D10).
   - **Plans**: the hours of a day plan and the language of plans.
5. **Wiring** (app, `openSession`):
   - the local engine (llamadart, loaded only when a model is used, and freed when the profile closes) and the cloud engine;
   - the models and the token ledger in `<app support>/ai`, as device data;
   - the settings and cloud choice of **this profile** in the device's encrypted registry (`ai.<profile>.*`), so another profile does not inherit the cloud option;
   - the keys in secure storage per profile;
   - the history and the assistant over the profile's store.
   
   `AiSetupService` (application) is the settings screen's port; `DeviceAiSetup` implements it.
6. All text is in the ARB file (`ai*` keys); FF-ARCH-10 has no new raw strings.

## Consequences
- The person can plan a day, fix its conflicts and ask about a document from where they are, and decide every change. What leaves the device is shown before it goes.
- On Android, a model file chosen from a content address (not a file path) cannot be used; the downloaded models can.
- A wrong key or model shows when the assistant is used, not when it is saved.
- The device check (T8) covers what tests cannot: the real models, the speed on the phone, the file dialog, the look.

## Verification
- `packages/ui/test/assistant_test.dart` (22 widget tests with fake ports):
  - **plan**: approve each, dismiss, approve all, nothing approved by itself, stale with "Regenerate" in the same conversation, fix conflicts on another day, seven outcomes said plainly;
  - **consent**: the waiting and never-sent items listed, nothing sent before the choice, Send, Send without these (which consents to nothing), Cancel;
  - **history**: order, opening a conversation, delete with Undo, empty;
  - **ask**: streamed, stop, the engine named, consent, a failure;
  - **settings**: the recommended model and its download with progress, chosen and deleted; a phone showing only the small model marked slow, the warning before the download (cancel downloads nothing) and a cancelled download; own files (GGUF only); the cloud off by default, the key hidden and never shown again, the models listed, the cap and this month's tokens; the engine tried first, the hours, the language;
  - **entries**: Calendar, Settings, a document; none without an assistant.
- `apps/lifeflow_app/test/assistant_integration_test.dart` (2 tests, the real store and wiring, no model):
  - from the Calendar with no task, then with a task and no model: nothing kept;
  - Settings shows this platform's models, and a key saved reaches the key store, not the screen.
- A bug found by the tests: "Send without these" also consented to the waiting items, so they would have been sent. Fixed and covered.
- Mutations: 16, run one at a time, over the consent choice, the proposal card, the outcome texts, the download warning, the key field and the entries. 14 were killed at once. Two survived and got tests: "Regenerate" shown with nothing stale, and approve buttons left on decided changes. All 16 killed after that.
- P06 T8 (the owner's decision): each provider's terms page (what it does with API data: training, retention) is linked in the cloud settings; a tap copies the link, as the app does with other web links. The addresses were checked (HTTP 200) on 2026-11-04 and are kept in `CloudProvider.termsUrl`.
