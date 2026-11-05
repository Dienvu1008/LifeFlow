# Deferred Contexts (Contract Stubs)

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Purpose: confirm the extension points named in [../product/product-scope.md](../product/product-scope.md) section 4 without designing these contexts yet. Each is intentionally a stub (principle AP-13: no speculative structure).
- Related: [../architecture/context-map.md](../architecture/context-map.md), [../architecture/domain-model.md](../architecture/domain-model.md)

Each entry states: purpose (one line), the contract it will consume or expose, and the single MVP extension point it relies on. No aggregates, commands or events are designed here. "Not yet designed" is deliberate.

## Collaboration (P04)
- Purpose: comments, mentions, invitations lifecycle, shared activity feed. Authorization stays in Workspace and Access.
- Will consume: `AuthorizationService`, resource refs by ID.
- Extension point in MVP: every resource has `workspaceId`/`ownerId`; the Governance Kernel command path exists.

## Sync (P04, infrastructure)
- Purpose: transport and reconcile commands/operations across devices.
- Will consume: the outbox rows and tombstones produced by the Governance Kernel; `expectedVersion` on commands.
- Extension point in MVP: UUID v7 IDs, per-entity `version`, tombstones, and the outbox row shape (see [../governance/governance-kernel.md](../governance/governance-kernel.md)).

## Knowledge and Documents (P05)
**Now designed in full: [document-knowledge.md](document-knowledge.md).** Extension point in MVP: `LinkedResource(type, id)` already used by Goals; adding `document` as a type needs no MVP change. Editor library stays Open (spike/3c; AppFlowy AGPL-3.0/MPL-2.0 risk, VS-16/OQ-V6).

## Dictionary, Translation, Vocabulary Learning (P07)
**Now designed in full: [dictionary-translation.md](dictionary-translation.md) and [vocabulary-learning.md](vocabulary-learning.md).** Dictionary and Translation are separate models sharing only `foundation` language primitives, behind provider ports + ACL; no source is chosen (spike S-10). Vocabulary creates review Tasks via the `CreateTask` contract; dictionary updates never overwrite saved vocabulary or progress. Extension point in MVP: language primitives in `foundation` and the `CreateTask` contract.

## Health and Activity (P08)
**Now designed in full: [health-integration.md](health-integration.md)** (Android Health Connect only). Publishes evidence via `RecordMeasurement` (`source=health` + provenance); never writes Task/completion; missing≠zero; Restricted class (ADR-0016). Extension point in MVP: `Measurement` carries `source`/`provenance` and a dedupe hook. Platform facts: VS-11..VS-15; Windows has no Health Connect (OQ-V1).

### HealthKit / iOS (future extension point, not designed)
[Open] When iOS enters scope, Apple HealthKit is added as a second implementation behind a shared `HealthProvider` abstraction that maps HealthKit records to the same `RecordMeasurement` contract. No HealthKit design, model or document is produced now (AP-13: not speculative). This is the single extension-point line the owner approved.

## Learning Studio (P09)
- Purpose: courses, modules, lessons, progress; generates learning tasks.
- Will consume: `CreateTask`/`UpdateTask` via the Governance Kernel; vocabulary.
- Extension point in MVP: `CreateTask` contract; learning never writes Task storage directly.

## AI Intelligence (P06)
- Purpose: sessions, proposals, approvals, provider routing; assists planning, Q&A, summarization.
- Will consume: the Governance Kernel command path and `AuthorizationService`; bounded context snapshots.
- Will expose: `AiProposal` and `AiApproval` (governed; see [../governance/ai-action-governance.md](../governance/ai-action-governance.md)).
- Extension point in MVP: the single mutation path (command gateway) is the only way AI can change state; nothing AI-specific is in MVP persistence.

## Self-check
- [x] Each deferred context references exactly one MVP extension point from product-scope.md section 4.
- [x] No deferred context introduces a dependency that the MVP contexts must implement now.
- [x] No aggregates or commands are designed here (stub level only).
