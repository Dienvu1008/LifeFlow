# ADR-0005: MVP scope is narrow and personal-first

- Status: Accepted (owner choice, confirmed 2026-11-04 with amendments below), pending review of the roadmap batch

## Amendments (2026-11-04)
- Goals, Projects and Milestones are in the MVP (P03), per OQ-S2.
- Sign-in must exist in the MVP but is optional and authentication-only (OQ-S4, OQ-S5); the app is usable guest-first from first launch (OQ-S6). See [ADR-0003](0003-backend-decision-deferred-to-spike.md) and [ADR-0008](0008-guest-first-with-optional-account-binding.md).
- Windows to Android data movement is deferred until sync (P04), per OQ-S1.
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../product/product-scope.md](../product/product-scope.md), [../product/requirements.md](../product/requirements.md), [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md)

## Context
The brief lists roadmap hypotheses P01 to P10, including Shared Workspace and Sync as P04. Audience is initially personal and small groups; resources are one developer plus a coding agent. Sync, sharing and AI each add substantial invariants, security work and test surface.

## Options
1. Narrow, personal-first MVP: Task, Schedule and Recurrence, Calendar and Event, Focus, basic Measurable Habit; offline; Windows and Android.
2. Broader MVP close to P01 to P04, including Shared Workspace and Sync.
3. Capability-complete MVP including documents, dictionary, health and AI.

## Decision
Option 1, with the amendments above (adds Goals/Projects and cloud sign-in).

Deferred capabilities stay deferred but keep extension points in the MVP (workspace and owner IDs on every resource, command layer with operation IDs and expected versions, tombstones, measurement provenance, linked-resource references). See product-scope.md section 4.

## Consequences
- Pro: shortest critical path; sync design can be informed by a stable, tested single-user domain.
- Pro: lower risk of permission and sync errors reaching users.
- Con: users who sign in on both Windows and Android see no shared data until P04 (OQ-S1 deferred). This may confuse users who expect a cloud account to sync; UI copy must say so. [Proposal]
- Con: adding Goals/Projects and the guest/account profile model (ADR-0008) widens the MVP; the roadmap batch must re-check the critical path and effort.
- Pro: guest-first (ADR-0008) means sign-in adds a feature, not a barrier, keeping the "fully offline" promise from product-vision.md intact for users who never sign in.
- Con: designing extension points without implementing them risks speculative structure. Mitigation: each extension point is a field or contract already needed by the MVP (IDs, versions, events), not a new abstraction.
- The first users cannot collaborate until P04.

## Follow-ups
- Roadmap batch re-estimates MVP with Goals/Projects and sign-in included.
- Re-evaluate this ADR if user feedback shows sharing is required earlier.
