# ADR-0017: Document collaboration maturity — single-user + revision sync first

- Status: Accepted (design; applies when the Document engine P05 is built)
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Evidence: [../domains/document-knowledge.md](../domains/document-knowledge.md); brief 3.6; AP-10 (right-sized), [../data/sync-protocol.md](../data/sync-protocol.md) (documents = keep-both-revisions)

## Context
The Document engine (P05) must store block documents and sync them. The brief lists three collaboration models: single-user local editing; revision-based cloud sync; real-time collaborative editing (CRDT/OT). The brief explicitly says not to assume CRDT at MVP and not to build CRDT just to look modern.

## Options
1. Single-user editing + revision-based sync (each device produces revisions; conflicts keep both as sibling revisions).
2. Real-time collaborative editing via CRDT/OT from the start.
3. Last-write-wins on whole documents (silent content loss).

## Decision
Option 1 for P05. A Document has a revision history; offline edits on two devices produce two revisions and a visible conflict (keep-both, per ADR-0015), never silent content loss. Real-time collaboration (CRDT/OT) is deferred until there is a validated need for concurrent multi-user editing of the same document.

## Consequences
- Pro: far simpler and testable; matches the per-type conflict rule already chosen for documents (ADR-0015).
- Pro: no silent content loss (brief requirement).
- Con: two people editing the same document at the same time get a conflict to resolve, not a live merge. Acceptable until real-time demand is proven.
- Trigger to revisit: a concrete, validated use case for simultaneous multi-writer editing (for example shared team docs with heavy concurrency). Revisiting would add a CRDT layer behind the same Document contract, not replace it.

## Follow-ups
- P05: revision model and conflict-resolution UI.
- A future ADR if/when CRDT is adopted, superseding this one for the affected scope.
