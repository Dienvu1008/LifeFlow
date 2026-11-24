# ADR-0081: The AI context builder and the egress checkpoint (FF-ARCH-08)

- Status: Accepted (P06 task T2, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md) (the owner's D1, D2, D6)
- Related: [ADR-0080](0080-ai-egress-and-approvals.md) (the egress rule), [ADR-0016](0016-data-classification-and-egress-policy.md), [ADR-0059](0059-sync-egress-classification.md) (`dataClassOf`), [ADR-0077](0077-pdf-text-in-search.md) (the text of PDFs), [ai-architecture.md](../architecture/ai-architecture.md) §3, [architecture-fitness-functions.md](../testing/architecture-fitness-functions.md) FF-ARCH-08

## Context
A model's request may carry only what the request is about, from the shown space, and only what the egress rule allows for the engine it goes to (ADR-0080). The architecture names one egress checkpoint as the last gate before any model (LF-INV-PRIV-003). FF-ARCH-08 must show that no Restricted item reaches a cloud request (GS-16). Until now it was a stub.

## Decision
1. **The port** (application, `ai.dart`).
   - `AiContextRequest`: a purpose (plan the day, fix a conflict, ask about a document; D1), the named things, and optional words to search for.
   - `AiContextItem`: a reference, its class, a title, its text, and its version for proposals.
   - `AiContextBuilder.build` returns an `AiContext` with a `truncated` flag.
2. **The context builder** (infrastructure, `DriftAiContextBuilder`). It reads only, and only what the request names:
   - any record kind through the record registry;
   - a document with the text of its PDFs on this device;
   - a PDF (`file:<hash>`) or one page (`file:<hash>#<n>`);
   - when words are given, up to 8 search hits each among documents, tasks and PDF pages.
   
   Never the whole store. Its rules:
   - **The shown space only, and live records only.** A record of another space, in the trash or gone is left out. A PDF's text is reached only through a live document of the shown space that names the file. An unknown kind is left out.
   - **Each record keeps its own class** (`dataClassOf`: a health measurement and an unknown kind are Restricted). A PDF's text is Confidential, as the documents that name it are.
   - **Bounded:** 30 items, 4 000 characters per item and 24 000 in all, cut with "…". An item whose title no longer fits is left out, and `truncated` says something was.
3. **The checkpoint** (application, `checkAiEgress`).
   - Each item is decided with the domain's rule (`aiMaySend`), given the site, the policy and the items the person consented to for this request.
   - What may go is put in the request as JSON objects tagged `"untrusted": true` (the person's content is data, never instructions). The app's instructions and the person's question are kept apart.
   - Every item comes back with what happened to it: sent, waiting for consent, or denied. The UI shows this (D6).
   - **The result type, `CheckedAiRequest`, has only a private constructor in the checkpoint's file.** An engine adapter (T4, T5) will take only that type, so it cannot be given an unchecked request.
4. **FF-ARCH-08** (`tools/fitness/ff_arch_08_ai_egress.dart`, in CI).
   - Guard 1: `CheckedAiRequest` has no public constructor, and no other library builds one.
   - Guard 2: the checkpoint decides each item with `aiMaySend` and adds only the items it allowed.
   - Guard 3: no other library builds tagged request data.
   - Then the tests tagged `ff-arch-08` must pass, at least 10.
5. `application` re-exports the domain's AI names, as it does for documents. The domain's reference type is `RecordRef`, because `application` already has a `ResourceRef` (for authorization).

## Consequences
- Every AI request goes through one function that a test can check against the rule. A builder bug can add an item, but cannot send it past the rule.
- What the person is about to send can be shown exactly, item by item.
- Search hits in a context are bounded; better ranking of context (OQ-AI-3) can come later.
- A task is Confidential (its notes), so toward the cloud a "plan my day" request needs consent for its tasks (ADR-0080).

## Verification
- `infrastructure/test/ai_context_test.dart` (10 tests, tagged `ff-arch-08`):
  - named records with class, text and version, a document bringing its PDF, a health measurement Restricted;
  - never another space, the trash, a gone record or an unknown kind;
  - a PDF or a page only through a live document of the shown space;
  - search hits within the limit and not twice;
  - the three bounds;
  - GS-16: toward the cloud Restricted is never sent, even consented, and is listed as left out;
  - Confidential waits for consent, Personal goes, and with the cloud off nothing goes;
  - on the device, Confidential goes when the request is about it and Restricted only with consent;
  - injected text stays tagged data;
  - a property over 400 random contexts: what is sent is exactly what the rule allows.
- FF-ARCH-08 green.
- Mutations: 17, run one at a time.
  - 16 were killed, among them a planted leak in the checkpoint and a public constructor (caught by guard 1).
  - The survivor only left out an empty text field. That condition was removed.
- A bug found by the tests: the total bound still added an item's title when the budget was used up. Fixed.
