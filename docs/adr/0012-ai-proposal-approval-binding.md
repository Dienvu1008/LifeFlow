# ADR-0012: AI approvals are bound to resource versions

- Status: Accepted (design; applies when AI Platform P06 is built)
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Evidence: [../governance/ai-action-governance.md](../governance/ai-action-governance.md); [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 4.6 (legacy approval bound to arguments only, no version)

## Context
In the legacy app, an AI confirmation carried only the tool name, risk, summary and arguments. There was no resource version or timestamp, so a user could approve an action computed against stale state and the tool would act on possibly-changed data (verified gap). LifeFlow uses optimistic concurrency with per-entity versions (ADR-0009), which makes a stronger binding possible.

## Options
1. Bind approval to arguments only (legacy).
2. Bind approval to actor + arguments + the resource versions the proposal was computed against + policy context; revalidate versions at execution.
3. Re-run the whole proposal at execution time (no human approval reuse).

## Decision
Option 2. An AI `Approval` records the acting owner, the exact command arguments, a `resourceRef → Version` map, and the policy context. At execution, the Governance Kernel revalidates authorization and compares each `expectedVersion` to the current version. If any target changed since the proposal, the approval is invalid and the user must regenerate (LF-INV-AI-002).

## Consequences
- Pro: an AI action cannot silently apply to data that changed after the user approved it.
- Pro: reuses the existing optimistic-concurrency mechanism; no new machinery.
- Con: in a busy session, frequent small edits can invalidate approvals and force regeneration. Mitigation: proposals should target current versions and the UI should make regeneration cheap.
- Con: multi-command proposals need per-command version maps; defined in P06 (OQ-AI-1).

## Follow-ups
- P06: implement the proposal/approval records and the revalidation step in the gateway.
- Batch 4: a golden scenario "AI proposal based on stale data is rejected or regenerated" with an automated test.
