# Policy Catalog

- Status: Draft (Batch 4)
- Date: 2026-11-04
- Related: [invariant-catalog.md](invariant-catalog.md), [../governance/governance-kernel.md](../governance/governance-kernel.md)

Policies are configurable or decision rules the design relies on, distinct from invariants (which must always hold). Each: statement, owner (context), enforcement point, related invariants, configurability, phase.

| ID | Policy | Owner | Statement | Enforcement point | Related invariants | Configurable? | Phase |
|---|---|---|---|---|---|---|---|
| POL-COMPLETION | Task completion | Task Management | manual / automatic / hybrid; measurable tasks complete per MeasurableTarget; parent-with-open-subtasks uses two explicit commands (ADR-0006, OQ-R3) | completion service | LF-INV-TASK-010 | per-task (default manual) | P01/P03 |
| POL-MEASURE-AGG | Measurement aggregation | Execution and Measurement | sum/max/latest/average per metric, keyed by LocalDate | MeasurementAggregator | LF-INV-EXEC-001, LF-INV-HEALTH-002 | per-target metric | P03 |
| POL-CONFLICT | Per-type conflict resolution | Sync | per data category (ADR-0015); no global LWW | sync apply | LF-INV-SYNC-003, LF-INV-DOC-002/005 | fixed per category | P04 |
| POL-EGRESS | Data classification and egress | Data classification | four classes + default-deny matrix (ADR-0016) | Context Builder, sync, share | LF-INV-PRIV-001/002/003 | fixed; per-item class may be raised | 3a / all egress phases |
| POL-RETENTION | Tombstone retention and purge | Governance/Data | tombstone first, purge after a retention window; purge is a replicated op | purge job | LF-INV-SYNC-004, LF-INV-SEC-010 | retention window configurable | P01 (tombstone), P04 (propagate) |
| POL-AI-APPROVAL | AI proposal approval | AI governance | approval bound to actor+args+resource versions+policy; revalidate at execution (ADR-0012) | gateway + proposal service | LF-INV-AI-001/002 | fixed | P06 |
| POL-LICENSE | Dependency license | Project | AGPL excluded; MIT/Apache/BSD/MPL-2.0 accepted; LGPL only with documented compliance; unknown = reject (ADR-0018) | dependency review + license scan (FF-ARCH-07) | — | fixed | all |
| POL-REVIEW-SCHED | Spaced repetition | Vocabulary | deterministic, reproducible schedule; LocalDate-based | review scheduler | LF-INV-VOCAB-003 | algorithm params | P07 |
| POL-HEALTH-READ | Health read cadence | Health | foreground + on-resume + periodic; background only if permitted; Changes-token de-dup (VS-13/14) | Health ingestion | LF-INV-HEALTH-001/005 | cadence configurable | P08 |

## Self-check
- [x] Each policy names an owner, enforcement point and related invariant(s).
- [x] Each references its ADR/doc.
- [x] Policies are separated from invariants.
