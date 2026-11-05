# ADR-0014: Atomic command side effects via a transactional outbox

- Status: Accepted
- Date: 2026-11-04
- Deciders: Architecture team; requested by the owner before Batch 3
- Resolves: OQ-GOV-1
- Evidence: [../governance/governance-kernel.md](../governance/governance-kernel.md); [ADR-0009](0009-identifier-and-versioning-strategy.md); [ADR-0011](0011-command-gateway-single-mutation-path.md)

## Context
The command gateway (ADR-0011) persists an aggregate change and also records an audit entry, outbox rows (for P04 sync) and in-process domain events. If these are written in separate transactions, a crash between them creates silent-correctness bugs:
- aggregate committed, outbox not written → sync loses the change at P04 (silent lost update);
- aggregate committed, audit not written → a change with no provenance (violates audit/provenance);
- aggregate committed, event not delivered → a downstream handler (e.g. Goal progress) never runs and the event is lost;
- version incremented before the concurrency check, or the check done outside the transaction → lost updates under concurrency.

The owner asked that the pipeline's ordering and atomicity be pinned down before Batch 3 (data/sync), because getting it wrong forces rework across the sync design.

## Options
1. Best-effort ordering (write aggregate, then audit, then outbox, then publish), no shared transaction.
2. **Transactional outbox**: the aggregate change, audit entry, outbox rows, event-log rows and idempotency record are written in **one database transaction**; domain events are dispatched to in-process handlers **after commit**, from the durable event log.
3. Two-phase commit / distributed transaction across stores.
4. Event sourcing (the event log is the source of truth).

## Decision
Option 2.

1. **One transaction, one atomic set.** Within a single local database transaction the gateway writes: the aggregate at `version+1`, the audit entry, the outbox row(s), the event-log row(s), and the dedupe (idempotency) record for `operationId`. These commit together or not at all.
2. **Version semantics inside the transaction.** The current version is re-read inside the transaction; if `expectedVersion` does not match, the transaction aborts and returns `VersionConflict`. The increment to `version+1` happens only on a match, inside the transaction, before commit. The pre-transaction read in the pipeline is only a fast-fail optimization.
3. **Rollback is total.** Any failure before or during commit rolls back the whole set: no aggregate change, no audit, no outbox, no event-log row, no dedupe record persists.
4. **Dispatch after commit.** In-process event handlers run after the transaction commits, reading from the event log. A handler failure never rolls back the committed command; undispatched event-log rows are retried (at-least-once; handlers must be idempotent).

This holds within the local database (SQLite/Drift), which is a single transactional store, so no distributed transaction is needed in the MVP. P04 sync drains the outbox separately; the outbox being durable and atomic with the mutation is exactly what makes sync safe.

## Invariants introduced
- LF-INV-GOV-003: the five writes above are one atomic transaction.
- LF-INV-OUTBOX-001: an outbox row exists iff the mutation committed.
- LF-INV-OUTBOX-002: an event-log row exists iff the mutation committed.
- LF-INV-AUDIT-001: an audit entry exists iff the mutation committed.
- LF-INV-VER-001: version is re-read and incremented inside the transaction, only on a match.

## Consequences
- Pro: eliminates every crash-window listed above; sync (P04) can trust the outbox.
- Pro: at-least-once handler delivery with idempotent handlers is simpler and safer than trying to make handlers part of the write transaction.
- Con: handlers must be idempotent (they may run again after a crash before the dispatch mark is set). Documented as a handler rule.
- Con: the audit and outbox share the write transaction, so a slow audit/outbox write slows the command. Acceptable for a local store; revisit only if profiling shows a problem.
- Event sourcing (option 4) remains rejected (AP-10/AP-13): the event log here is a delivery mechanism, not the source of truth.

## Follow-ups
- Data batch: physical layout (one table with a `channel` column vs separate outbox/event-log tables; OQ-GOV-3), dispatch-mark/retention (OQ-GOV-2).
- Batch 4: golden scenarios and tests — "crash between commit and handler does not lose the event", "crash does not leave an outbox row without its mutation or vice versa", "concurrent writers: exactly one wins, the other gets VersionConflict".
