# P06 plan: the AI platform

- Status: **Decisions taken by the owner 2026-11-04** (§3): D1–D6 and D8–D10 as proposed; **D7 changed: the assistant's history syncs** (end-to-end encrypted, like notes). T1–T3 done and merged. **S-17 done (2026-11-04)**: llamadart embedded (D3 (a), no Ollama); Windows list Qwen 3.5 2 B (default), 4 B, 0.8 B; Android only Qwen 3.5 0.8 B behind a "slow, not recommended" warning (the owner's call). Next: S-18, T4.
- Date: 2026-11-04
- Inputs:
  - [phase-breakdown.md](phase-breakdown.md) P06;
  - [ai-architecture.md](../architecture/ai-architecture.md) (components, Context Builder scoping, routing, threats; OQ-AI-1…3);
  - [ai-action-governance.md](../governance/ai-action-governance.md) (lifecycle, provenance, the determinism boundary);
  - [ADR-0012](../adr/0012-ai-proposal-approval-binding.md) (approvals bound to resource versions);
  - [ADR-0016](../adr/0016-data-classification-and-egress-policy.md) and [data-classification.md](../data/data-classification.md) (the egress matrix);
  - [ADR-0059](../adr/0059-sync-egress-classification.md) (the classifier in code);
  - [ADR-0018](../adr/0018-dependency-license-policy.md) (licenses);
  - [personas-and-use-cases.md](../product/personas-and-use-cases.md) UC-07, UC-08, UC-18;
  - [technical-stack.md](../architecture/technical-stack.md) §3 (AI: port only, no provider chosen);
  - [effort-estimation.md](effort-estimation.md) (P06: 20–45 person-days, low confidence).
- Estimate: about 25–40 person-days after the spikes, depending on D2 and D3, plus a 30 % risk buffer.

## 1. Goal and exit gate

Goal: LifeFlow gets an assistant that **proposes** changes to the person's plan and **answers** about their own content, on Windows and Android. It never changes anything by itself, and private data never leaves the device without the person's say.

Exit gate (P06):
- **AI never acts on its own** (LF-INV-AI-001):
  - every change it suggests is a proposal the person approves;
  - an approved change runs through the command gateway as the person, with the same checks as a tap;
  - no AI code touches the store.
- **A stale proposal is refused** (LF-INV-AI-002, GS-15): if a task or event changed after the proposal was made, approving it changes nothing and the person is asked to regenerate.
- **Nothing private leaves without consent** (LF-INV-PRIV-001…003, GS-16, FF-ARCH-08 green):
  - Restricted data never reaches a cloud model;
  - Confidential data (documents, PDF text, task notes, chat history) reaches one only with the cloud option on and a per-request consent that shows what would be sent;
  - the egress checkpoint is the only way out, and it is tested.
- **Prompt injection does not act**: text in a document or a task that says "delete everything" produces at most a proposal, and the egress rules still hold (the legacy prompt-injection test, ported).
- **It works offline** with a local model (if D2 keeps one), and declines politely when no allowed model can do the request (OQ-AI-2). It never downgrades privacy to get an answer.
- The use cases chosen in D1 work in Vietnamese and English on both platforms.
- Every new library and model is in the license inventory with an accepted license (FF-ARCH-07, ADR-0018).
- P01–P05b properties still hold.

Out of scope for P06:
- AI that acts without approval ("autopilot");
- voice input (speech recognition is P07);
- AI in the dictionary (P07 uses this platform);
- health data (P08);
- training or fine-tuning models;
- a LifeFlow-paid cloud AI service (see D2 (c));
- sharing AI sessions with other members.

## 2. Starting point (checked 2026-11-04)

- **Designed, not built.** The architecture and governance docs define the components:
  - Orchestrator;
  - Provider Router;
  - the `AiEngine` port;
  - Context Builder with an egress checkpoint;
  - Tool Gateway;
  - Proposal/Approval;
  - AI Session;
  - usage tracking.
  
  No AI code exists in the repository.
- **Reusable today:**
  - the four data classes and `kindClasses` / `dataClassOf` (every record kind is classified; an unknown kind is Restricted, ADR-0059);
  - the command gateway, which already checks `expectedVersion` inside the transaction, so ADR-0012's revalidation is one version per command;
  - FF-ARCH-06/09, which force any tool to go through `CommandGateway.execute`;
  - the one search (documents, tasks, PDF text) as a context source;
  - the reading model (sentences) for showing an answer.
- **Missing:**
  - an AI rule for egress (`cloudAiAllowed`, `localAiAllowed`; only the sync rule exists);
  - FF-ARCH-08 (a stub);
  - AI record kinds (sessions, proposals);
  - an audit field for AI provenance;
  - any provider.
- **Candidates found (not verified; each is read in a spike before use, ADR-0018):**
  - **On-device, embedded in the app:**
    - `llamadart` (llama.cpp for Dart and Flutter: GGUF models on Android, iOS, macOS, Windows, Linux; LiteRT-LM on Android);
    - `flutter_gemma` (Gemma and other models, Android and Windows among others, with function calling);
    - `fllama` (llama.cpp for Flutter, every platform);
    - `llama_cpp_dart` (MIT, VS-18).
  - **On-device through another program:** Ollama, a local server at `localhost:11434` with tool calling and structured outputs. On Windows the person installs it separately; there is no Android version.
  - **Small open models (Apache-2.0 as published; to verify):**
    - the Qwen 3 / 3.5 family (0.6 B–9 B, native tool calling, multilingual);
    - Gemma (Gemma license: to read, it is not Apache).
    
    Vietnamese quality, speed and memory on the owner's devices are unknown: that is spike S-17.
  - **Cloud:** OpenAI, Google Gemini, Anthropic and others. Prices, terms (training on the data, retention) and Vietnamese quality are not verified: spike S-18, only if D2 asks for cloud.
- **Model files are large:** about 0.5–5 GB. They cannot ship inside the app (the APK and the Windows installer). They are downloaded after the person agrees (D4).

## 3. Owner decisions (D1–D10)

| # | Question | Options | Proposed (the owner, 2026-11-04: as proposed, except D7) |
|---|---|---|---|
| D1 | **What the assistant does in P06** | (a) UC-07 "plan my day" and UC-08 "fix a conflict", as proposals; (b) (a) plus "ask about this document or PDF" (summary, answer, find), read-only; (c) (b) plus a free chat about everything in the shown space | **(b)**. It covers both kinds of AI work: proposals that change things, and answers that change nothing. (c) gives the widest context, which means the most risk and cost; it can come later |
| D2 | **Where the model runs** | (a) on the device only (local), cloud as a port with no adapter; (b) local by default, plus an optional cloud model with **the person's own API key**, off by default; (c) a cloud model paid by LifeFlow through its server | **(b)**. Local keeps privacy and works offline, but small models are weaker, especially in Vietnamese. The person's own key puts no cost on LifeFlow and needs no server work. (c) needs a server, billing and terms: a paid feature, later, like file sync |
| D3 | **Which local runtime** | (a) embedded in the app (llama.cpp through a Dart package, or flutter_gemma); (b) Ollama, installed by the person (Windows only); (c) both | **(a), chosen by spike S-17**, with (b) as an optional extra on Windows if S-17 shows the embedded runtime too slow there. Android has no Ollama |
| D4 | **Getting the model** | (a) the app downloads a model from a pinned list (name, size, license, SHA-256) after the person agrees, over Wi-Fi by default; (b) the person picks a GGUF file they downloaded; (c) both | **(c)**. A short list (one small and one larger model per platform, from S-17), plus "Use a model file" for people who know. The file stays in the app's folder; deleting it frees the space |
| D5 | **Cloud provider** (if D2 (b)) | OpenAI, Google Gemini, Anthropic, an OpenAI-compatible address (for example a self-hosted server) | Proposed: one provider plus "OpenAI-compatible address". **Owner's choice (2026-11-04): support as many providers as possible, starting with OpenAI, Google Gemini, Anthropic and Groq**, plus an OpenAI-compatible address. S-18 checks each on terms (training on API data, retention), Vietnamese quality, structured output and price. The key stays in secure storage (LF-INV-SEC-001) |
| D6 | **What may be sent to a cloud model** (the matrix allows Personal with the option on, Confidential only with per-request consent, Restricted never) | (a) as the matrix says, with a consent sheet listing what would be sent ("3 tasks, 1 document: …") each time Confidential is in the request; (b) never Confidential to the cloud; (c) consent once per session | **(a)**. The sheet shows the items by title and their class. "Send without these" removes the Confidential items. A consent is for one request only (privacy-model §3) |
| D7 | **The assistant's history** (chat and proposals, Confidential) | (a) kept on this device only, encrypted, deletable, not synced, not exported; (b) synced, end-to-end encrypted, like notes; (c) not kept | Proposed (a). **Owner's choice: (b)**: a person may need to read the history again on another device. So sessions, their messages and proposals are record kinds, Confidential, sealed and synced like notes (ADR-0052, D12 of P04), in the profile's export, deletable (to the trash, then purged), and in the personal space only (an AI session is not moved into a shared space in P06). Syncing them is sync, not egress to a model: a cloud model still gets nothing without the D6 rules |
| D8 | **Approving a proposal with several changes** (OQ-AI-1) | (a) all or nothing; (b) each change approved on its own, with "Approve all"; each still version-checked | **(b)**. One stale change does not block the others; it is shown as stale with "Regenerate" |
| D9 | **Language** | (a) the assistant answers in the language the person writes in (Vietnamese or English); (b) always Vietnamese; (c) a setting | **(a)**, with the app's prompts in English and Vietnamese. S-17 checks Vietnamese quality |
| D10 | **Limits and cost** | (a) local: no cost, a stop button; cloud: token counts shown per request and a monthly cap set by the person (default: none until set; a warning at each request with an estimate); (b) no limits | **(a)**. With the person's own key, the person pays the provider directly. LifeFlow shows the tokens and the estimate, never bills |

## 4. Technical design (no owner input needed; ADRs during the tasks)

- **Domain (pure):**
  - the egress rules `localAiAllowed(class, scope, consent)` and `cloudAiAllowed(class, cloudOn, consent)`, from the matrix, beside `cloudSyncAllowed`;
  - `AiProposal` (intended commands with arguments and the `resourceRef → Version` map);
  - `AiApproval` (the actor, the exact arguments, the versions, the policy context);
  - the day-plan rules the AI may not break (it proposes; deterministic checks still run: conflicts, working hours).
- **Application (ports):**
  - `AiEngine`: generate, stream, structured output and tools, provider-neutral;
  - `AiModelCatalog`;
  - `AiSessionService`;
  - `ContextBuilder`;
  - the egress checkpoint;
  - `ProposalService` (propose, approve, execute).
- **Infrastructure:**
  - the Context Builder over the store, which reads only, scoped by the request: the screen, the selection, named items and search hits. It never loads the whole store;
  - the checkpoint, the last gate before any cloud call. A denied item is dropped and listed to the person, never sent;
  - the Tool Gateway: a fixed list of tools mapped to existing commands (create, schedule, move or reschedule a task or event; mark done). Their arguments are validated like any payload, and they run through `CommandGateway.execute` as the approving person;
  - record kinds for sessions, messages and proposals (schema v18, a new `recordSchemaVersion`), Confidential, synced end-to-end encrypted and exported like other records (D7); the server needs no change (sealed records);
  - an `aiProvenance` field in the audit log (proposal id, approval id, model, versions).
- **Untrusted content:** text from the person's items is passed to the model as tagged data (`{"untrusted": true}`), never as instructions. Prompt-injection defense is enforced in code: the model's output is only ever a proposal or an answer.
- **Adapters:**
  - the local runtime behind `AiEngine` (D3), in ui or the app as pdfrx and flutter_tts are;
  - the cloud adapter (D2, D5) over HTTPS with the person's key from secure storage.
  
  Small local models often return broken tool calls; the legacy text-tool-call parser is ported for that.
- **FF-ARCH-08:** a tagged test group run by the fitness script, like FF-ARCH-06/09. It is a property test: random contexts with Restricted and Confidential items toward a cloud engine, and none reaches the request without the rules allowing it. A static guard also checks that only the checkpoint calls a cloud adapter.

## 5. Spikes and tasks

| Task | What | Proof | Your check | Days |
|---|---|---|---|---|
| **S-17** Local model (**done**: PASS on Windows; slow on Android, see [spike-results.md](../spikes/spike-results.md)) | A throwaway probe app on Windows and Android with the runtime candidates (llamadart, flutter_gemma; Ollama on Windows) and 2–3 small models (for example Qwen 3.5 0.8 B / 4 B, a Gemma). Measured: Vietnamese and English answers, JSON or tool output that parses, speed (tokens/s), memory, model size, app size, the licenses of the runtime and of each model | results in spike-results.md; a recommended runtime and model list | **yes**: run the probe, judge the Vietnamese answers | 2–3 |
| **S-18** Cloud model (**done** for Groq and Gemini: [spike-results.md](../spikes/spike-results.md); OpenAI, Anthropic when keys are added) | With your own key: 2–3 providers on the same prompts (plan my day, summarize a Vietnamese document); structured output; tokens and cost per request; the terms on training and retention | results; a provider for D5 | **yes**: give a key, judge the answers | 1–2 |
| **T1** Domain and egress (**done**: [ADR-0080](../adr/0080-ai-egress-and-approvals.md)) | The proposal and approval model; the AI egress rules (the AI record kinds moved to T3, with their tables) | domain tests; property tests of the matrix | no | 2 |
| **T2** Context Builder and checkpoint (**done**: [ADR-0081](../adr/0081-ai-context-and-egress-checkpoint.md)) | Scoped context (screen, selection, named items, search); the checkpoint; FF-ARCH-08; GS-16 | integration tests; the property test; a planted leak caught | no | 3–4 |
| **T3** Proposals and approvals (**done**: [ADR-0082](../adr/0082-ai-history-and-approved-changes.md)) | Session, message and proposal records (Confidential, synced, D7); approve each or all; revalidation at execution; `aiProvenance` in the audit; GS-15 | integration tests through the real gateway; atomic-set coverage | no | 3 |
| **T4** Local engine (**done**: [ADR-0083](../adr/0083-local-model-engine.md); licenses [ADR-0084](../adr/0084-llama-cpp-runtime-licenses.md), accepted by the owner) | The runtime adapter (S-17), the model list and download with hash check, "Use a model file", the stop button | adapter tests with a tiny model or a fake; download tests | no | 3–4 |
| **T5** Cloud engine (**done**: [ADR-0085](../adr/0085-cloud-model-engine.md); real services in S-18) | The adapter (S-18), the key in secure storage, the consent sheet, token counts and the cap | adapter tests against a fake server; consent tests | no | 2–3 |
| **T6** Orchestrator and tools (**done**: [ADR-0086](../adr/0086-assistant-orchestrator.md)) | The turn loop, the Tool Gateway with the fixed tool list, untrusted tagging, the injection test, routing (local/cloud by class, OQ-AI-2 decline) | integration tests with a scripted fake model; the injection test | no | 3–4 |
| **T7** The assistant in the UI (**done**: [ADR-0087](../adr/0087-assistant-ui.md)) | "Plan my day" and "Fix this conflict" (proposals with approve each or all, stale shown, regenerate); "Ask about this document/PDF"; the history; settings (model, cloud, key, cap) | widget tests with a fake engine | no | 4–5 |
| **T8** On the devices | Your Windows and Android: the use cases of D1 in Vietnamese and English, offline, with and without cloud, consent, a stale proposal | your check | **yes** | 1 |
| **T9** P06 exit gate | p06-exit-gate.md, ADRs, invariants, risks; your review | all suites, CI | yes | 1 |

Order: S-17 (and S-18) → T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9. T1–T3 do not need a model and can start while you run the spikes.

**After S-17 (2026-11-04):** T4 offers local models on Windows as the normal path and on Android with a clear warning before the download (slow and not recommended there; cloud with the person's own key is the better option on phones). T6 keeps the model's plan small (order and slot by id) and computes and checks every time in code, retrying a broken JSON plan once.

## 6. Invariants and scenarios

- Enforced and tested in P06:
  - LF-INV-AI-001 (no bypass, no direct persistence);
  - LF-INV-AI-002 (approval bound to versions);
  - LF-INV-PRIV-001…003 (egress);
  - LF-INV-SEC-001 (the API key only in secure storage, never in context, logs or exports).
- Golden scenarios: GS-15 (a stale proposal is refused), GS-16 (cloud never gets Restricted context).
- Proposed new:
  - **LF-INV-AI-003**: every AI-made change names its proposal and approval in the audit (provenance);
  - **GS-31**: injected text in a document produces no change without approval, and no egress beyond the rules.

## 7. Risks

- **R-AI-HALLUCINATION**: proposals only, deterministic checks, version-bound approval, entities by id.
- **R-AI-LEAK** (main risk): one checkpoint; FF-ARCH-08 as a property test; a planted leak must be caught; cloud off by default.
- **R-CLOUD-COST**: the person's own key, token counts, a cap (D10).
- **R-LOCAL-MODEL** (new):
  - small models may be too weak in Vietnamese, or too slow or too big on the owner's phone;
  - mitigation: S-17 on the owner's devices before T4;
  - contingency: a larger model on Windows only, or cloud (D2 (b)) for what local cannot do.
- **R-MODEL-LICENSE** (new):
  - model weights carry their own licenses (Apache-2.0 for Qwen as published, the Gemma license for Gemma, others with use restrictions);
  - mitigation: each model's license read and recorded before it is offered, ADR-0018;
  - contingency: offer only Apache-2.0 or MIT models.
- **R-APP-SIZE** (new): runtimes add native libraries. Mitigation: measured in S-17; models are downloaded, never bundled.
