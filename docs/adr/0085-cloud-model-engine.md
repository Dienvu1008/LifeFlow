# ADR-0085: Cloud models with the person's own key (OpenAI, Gemini, Anthropic, Groq, OpenAI-compatible)

- Status: Accepted (P06 task T5, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md); the owner's D2 (local by default, cloud with the person's own key, off by default), D5 (**as many providers as possible**: OpenAI, Google Gemini, Anthropic and Groq first, plus an OpenAI-compatible address), D6 (the egress matrix with consent), D10 (token counts and a monthly cap)
- Related: [ADR-0080](0080-ai-egress-and-approvals.md), [ADR-0081](0081-ai-context-and-egress-checkpoint.md), [ADR-0083](0083-local-model-engine.md), [ADR-0016](0016-data-classification-and-egress-policy.md), LF-INV-SEC-001, LF-INV-PRIV-002

## Context
On phones the local model is too slow (S-17), so a cloud model is the practical choice there. The owner wants every common provider. The person pays the provider with their own key. LifeFlow never bills and never sees the key on a server.

## Decision
1. **The port** (application, `ai_engine.dart`):
   - `CloudProvider`: OpenAI, Google Gemini, Anthropic, Groq, and OpenAI-compatible. The last takes the person's own address, for example a self-hosted server or a router.
   - `CloudAiConfig`: the provider, the model, an optional address and a monthly token cap.
   - `AiKeyStore`: keys in secure storage.
   - `AiUsageLedger`: token counts.
   - `CloudModelCatalog`: the models a key may use, **read from the provider**, because model names change too often to hard-code.
   - `estimateAiTokens`: about 3 characters per token, plus the answer's limit.
   - New failure kinds: unauthorized, rate limited, network, cap reached, refused.
2. **One engine for every provider** (infrastructure, `CloudAiEngine`). It sits behind the same `AiEngine` port as the local engine and takes **only a request checked for the cloud**. The checkpoint (ADR-0081) has already:
   - dropped Restricted, whatever is consented;
   - kept Confidential only if the person consented;
   - kept nothing if the cloud option is off.
   
   Three wire formats cover the five providers:
   - **OpenAI chat completions** (OpenAI, Groq, OpenAI-compatible): a bearer key; streamed with `stream_options.include_usage`; JSON through `response_format: json_schema` (strict); `max_completion_tokens` (other servers: `max_tokens`).
   - **Anthropic messages**: `x-api-key` and `anthropic-version`; the system text apart; streamed events (text deltas, usage at the start and the end, error events); JSON through `output_config.format` (json_schema).
   - **Gemini generateContent**: the key in `x-goog-api-key`, **never in the URL**; `streamGenerateContent?alt=sse`; JSON through `responseMimeType` and `responseJsonSchema`. Thinking parts are not shown, but their tokens are counted (they are paid).
   
   For every provider:
   - **A structured answer** that was cut at the limit, did not parse, or was not an object is asked for once more, then refused. A refusal by the model is reported as one and not asked again.
   - **Errors**: 401/403 is unauthorized, 429 is rate limited, anything else failed, no connection is network. The provider's message is shortened and **any echo of the key is replaced**.
   - **Stop** closes the connection, and the answer ends as stopped.
   - **Address**: HTTPS only (loopback for tests). The OpenAI-compatible provider needs one.
3. **Keys** (app, `SecureAiKeyStore`): in the platform's secure storage, one slot per profile and provider (`ai.key.<profile>.<provider>`), so another profile on the device never uses them. A key is read for each request. It is never in the store, an export, a sync or a log (LF-INV-SEC-001).
4. **Cost (D10)** (infrastructure, `FileAiUsageLedger`): each request's tokens, as the provider counted them, go to a JSON file in the app's folder, as device data. The last 13 months are kept, and records written at once are all kept. If the person set a cap, a request whose estimate could go over it **is not sent**. A structured request counts both tries. LifeFlow shows tokens, not money: prices change and are the provider's.
5. **S-18** (`packages/infrastructure/tool/s18_probe.dart`) runs S-17's prompts through this engine for each provider the owner has a key for. Keys come only from `LIFEFLOW_S18_<PROVIDER>_KEY`; without a `…_MODEL` it lists the models. The probe checks the wire details (written from each provider's documentation of 2026-11-04) against the real services, and gives speed, tokens, Vietnamese quality and plan quality for choosing defaults.

## Consequences
- The assistant can use any of the five providers, chosen by the person, with their key and cap. The cloud stays off until they turn it on (D2).
- Not built yet:
  - **The consent sheet** (what would be sent, item by item, before a request with Confidential data) and the settings screens: T7;
  - **routing** (local or cloud by the request's class, OQ-AI-2): T6.
- Provider terms (training on API data, retention) are not decided here. S-18 records them, and the settings screen will link each provider's terms.
- The cap is per device: a person using two devices has a cap on each.

## Verification
- `infrastructure/test/cloud_engine_test.dart` (20 tests, against a local server speaking each provider's format):
  - only cloud-checked requests; **GS-16 at the wire**: a Restricted item consented is not in the request body, a Confidential item only when consented;
  - not ready: no model, no key, a blank key, no address or not HTTPS, with nothing sent;
  - each provider: the address, the header, the system text, the streamed answer, the recorded tokens; Gemini's key never in the URL and its thoughts not shown;
  - JSON in each provider's mode; cut or broken asked again once, then refused; refusals;
  - errors 401/403/429/500 with the key not in any message; no connection; an Anthropic error event;
  - the cap: nothing sent, two tries counted, a new month;
  - stop; the model lists; the ledger by month, after a restart, 13 months, records at once, a failed write, a broken file.
- Mutations: 26, run one at a time. 22 were killed at once. Four survived and got tests:
  - a blank key;
  - an answer cut at the limit that still parses;
  - the estimate itself;
  - the ledger after a failed write (run by hand: the helper read the test's own file error as a lock).
  
  All 26 killed after that.
- Not run against the real services yet: S-18, once the owner sets the keys.
