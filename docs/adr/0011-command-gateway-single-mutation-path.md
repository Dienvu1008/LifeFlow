# ADR-0011: One command gateway is the only mutation path

- Status: Accepted
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Evidence: [../governance/governance-kernel.md](../governance/governance-kernel.md); [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) (legacy: business rules once in widgets; repositories writable from many places)

## Context
LifeFlow must guarantee that UI, AI, background jobs and sync cannot change domain state without authorization, audit, idempotency and concurrency control. The legacy app had business rules in widgets and repositories callable from scattered places, with no version or audit.

## Options
1. Repositories are public; callers write directly (legacy).
2. A single command gateway: all mutations are commands passing through one pipeline; repositories are only writable from command handlers.
3. CQRS with an event-sourced store.

## Decision
Option 2. Every mutation is a `Command` through the Governance Kernel pipeline (authorize → validate → load+version → execute → one transaction persisting aggregate+audit+outbox → publish events). Reads bypass the gateway (queries are free and side-effect-free). Repositories expose reads publicly but writes only to command handlers (enforced by a fitness function, FF-GOV-01, defined in Batch 4).

Event sourcing (option 3) is rejected for now (AP-10/AP-13): it adds complexity without a current need; the outbox plus per-entity version gives the sync properties we need.

## Consequences
- Pro: one place enforces authorization, audit, idempotency, concurrency (LF-INV-GOV-001/002).
- Pro: AI and providers are ordinary actors; they cannot escalate by writing a repository directly (LF-INV-AI-001).
- Pro: retries and future sync replay are safe (idempotency by operationId).
- Con: more ceremony than direct writes; every mutation needs a command type. Mitigated by keeping commands close to use cases and generating boilerplate if needed.
- Con: one-aggregate-per-command means multi-aggregate effects are eventual (via events). Acceptable; documented in governance-kernel.md section 4.

## Follow-ups
- Batch 4: FF-GOV-01 (no repository write outside a command handler), FF-GOV-02 (authorize-before-domain).
- Confirm post-commit vs in-transaction event delivery (OQ-GOV-1).
