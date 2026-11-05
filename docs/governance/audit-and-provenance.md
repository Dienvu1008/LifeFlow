# Audit and Provenance

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Related: [governance-kernel.md](governance-kernel.md), [../domains/execution-measurement.md](../domains/execution-measurement.md), [ai-action-governance.md](ai-action-governance.md)

## 1. Purpose
Make every state change explainable: who did what, to which resource, from which version to which, with what outcome, and (for measurements and AI) from what source. This corrects the legacy gap where the AI action log was device-local and excluded from backup.

## 2. Audit entry
Append-only. One entry per command that mutates state (and per denied attempt that is security-relevant).
```
AuditEntry {
  auditId: UUID v7
  operationId: UUID v7         // ties to the command and outbox
  actor: ActorRef              // owner | aiAssistant(on behalf of owner) | provider | sync
  onBehalfOf: ActorRef?        // the owner, when actor is aiAssistant
  action: string               // command type
  resourceRef: ResourceRef
  versionBefore: Version?
  versionAfter: Version?
  outcome: {applied, deniedByPolicy, validationFailed, versionConflict, duplicateIgnored}
  reason?: string
  at: Instant
}
```
[Decision] The audit entry is written **inside the same transaction as the mutation** (LF-INV-AUDIT-001, [ADR-0014](../adr/0014-transactional-outbox-and-atomic-side-effects.md)): there is no committed state change without its audit entry, and a crash cannot leave a change unaudited.

[Decision] Audit is durable, workspace-scoped, and **included in export** (contrast legacy). Whether it syncs to cloud follows the data classification (data batch); by default audit is local and exportable, not pushed to cloud in MVP.

[Decision] `CompleteTaskOnly` (task-management.md) writes a warning into its audit entry listing the subtasks that were still open at completion time, so a parent-only completion is distinguishable in the trail from a full completion.

## 3. Provenance for measurements
Every `Measurement` (see execution-measurement.md) carries:
```
provenance {
  source: {manual, focusSession, import, health}
  deviceId
  recordedAt: Instant
  origin?: string        // e.g. Health Connect record id, import file id
}
```
Rules (Decisions):
- Provenance is never dropped (LF-INV-HEALTH-004).
- A correction creates a new Measurement with its own provenance and `supersedesId`; the predecessor and its provenance remain (LF-INV-EXEC-001).
- Health-sourced measurements keep the origin id so de-duplication and later re-reads are possible (VS-14).

## 4. Provenance for AI actions
When a command's actor is `aiAssistant`, the audit entry and an AI-action record capture:
```
aiProvenance {
  proposalId
  approvalId
  model: {provider, name}
  inputsDigest           // hash of the context + arguments the proposal was built from
  approvedResourceVersions: map<ResourceRef, Version>
}
```
This supports LF-INV-AI-002 (approval bound to version) and makes an AI change auditable end to end.

## 5. Retention and export
- Audit and provenance are kept at least as long as the data they describe; purged with the entity under the retention policy (data batch).
- Export (UC-20a) includes audit and provenance so a user's record is complete.
- [Open] OQ-AUD-1: maximum audit growth and whether to compact old entries. Estimation/data batches.

## 6. Invariants
- LF-INV-AUDIT-001 (an audit entry exists iff the mutation committed — same transaction, ADR-0014), LF-INV-EXEC-001 (history preserved), LF-INV-HEALTH-004 (provenance preserved), LF-INV-AI-002 (version-bound approval traceable).

## 7. Self-check
- [x] Audit shape ties to operationId and outbox.
- [x] Provenance fields match execution-measurement.md.
- [x] AI provenance records the approved resource versions.
