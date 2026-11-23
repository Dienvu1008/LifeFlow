# ADR-0080: The AI egress rule and version-bound approvals in the domain

- Status: Accepted (P06 task T1, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p06-plan.md](../roadmap/p06-plan.md) (the owner's D2, D6, D8)
- Related: [ADR-0012](0012-ai-proposal-approval-binding.md) (approvals bound to resource versions), [ADR-0016](0016-data-classification-and-egress-policy.md) and [data-classification.md](../data/data-classification.md) §2 (the egress matrix), [ADR-0059](0059-sync-egress-classification.md) (the classes in code, the sync rule), [ai-architecture.md](../architecture/ai-architecture.md) §3–§5

## Context
P06 builds the AI platform. Two rules must hold whatever model, prompt or screen is involved.
- **The egress matrix decides what a request to a model may carry.** For a model on this device: Public and Personal yes; Confidential if the request is about it, else with consent; Restricted only with consent. For a cloud model: nothing unless the cloud option is on; then Public and Personal yes, Confidential only with consent for that request (D6), Restricted never (LF-INV-PRIV-002).
- **An approval is bound to the person, the exact arguments and the versions the proposal was computed against** (ADR-0012, LF-INV-AI-002). Each change of a proposal is approved on its own (D8, OQ-AI-1).

The sync rule (`cloudSyncAllowed`) is already pure, in `domain`. These rules belong beside it, so that the Context Builder (T2), the gateway path (T3) and the UI all use the same ones.

## Decision
1. **`aiEgressOf(class, site, policy)`** (domain, `ai.dart`) returns allow, needs consent, or deny. The site is this device or the cloud. The policy says whether the cloud option is on and whether the request is about Confidential items by its nature, as "ask about this document" or "plan my day" over the tasks are. This is the matrix's "if the session scope permits".
   - Every case of the matrix is written once. Restricted toward the cloud is the first case, so no later rule can let it through.
   - `aiMaySend(…, consented:)` is what the Context Builder asks of each item. Consent never turns the cloud on.
2. **The proposal model.**
   - A `ResourceRef` is a record kind and an id.
   - A `ProposedChange` is a command type, its exact arguments, the version of each existing thing it was computed against (a new thing has none), and a summary for the person.
   - An `AiProposal` is a session, a model, a time and its changes, each named once.
3. **The approval.**
   - `approveChange` binds an approval to the person, the proposal and the change, its arguments in canonical JSON (keys sorted at every level), its versions, and the policy context (the site, the model, the items consented to).
   - `approvalProblem` says why an approval does not let a change run now:
     - another person, proposal or change;
     - the arguments or versions differ from what was approved;
     - stale: a thing named changed or is gone since.
   - The command gateway still checks `expectedVersion` inside its transaction (T3). This check comes first, so the person is told before anything runs.
4. **The domain stays pure.** There is no model, store or clock in it. Misuse (a change named twice, approving another proposal's change) throws an `ArgumentError`. The domain cannot depend on `application`'s `DomainRejection`.
5. **Not in T1** (moved to T3, with their tables): the record kinds for AI sessions, messages and proposals, classified Confidential (D7: they sync). The classification guard test requires every record kind to be classified, and a kind cannot exist without its table.

## Consequences
- Every egress decision about AI is one pure function, testable case by case; the Context Builder cannot apply a looser rule by accident.
- An approval cannot be reused for changed arguments, another change, or changed data.
- A task is Confidential because of its notes (ADR-0059). So "plan my day" toward a cloud model needs consent for the tasks; on this device it does not (the request is about them). Classifying by field (title Personal, notes Confidential) could lighten that later; it is not done now.

## Verification
- `domain/test/ai_test.dart` (11 tests):
  - the whole matrix (16 cases);
  - GS-16's pure part: Restricted is never sent to the cloud, whatever the policy and consent;
  - consent lets through only what needs it;
  - approvals: valid; GS-15's pure part, stale when a thing changed or is gone;
  - another person, proposal or change is refused; changed arguments or versions are refused; key order does not matter;
  - a create holds;
  - a property over 500 random version maps;
  - misuse;
  - canonical JSON.
- Mutations: 15, run one at a time, all killed. One first survived: Restricted was denied twice in the cloud branch. The rule is now written once.
