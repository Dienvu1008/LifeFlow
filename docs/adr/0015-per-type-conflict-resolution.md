# ADR-0015: Per-data-type conflict resolution (no global Last-Write-Wins)

- Status: Accepted (design; applies when sync P04 is built)
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Evidence: [../data/sync-protocol.md](../data/sync-protocol.md); brief section 8.3; [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 4.5 (legacy file-import used keepNewest, not a true per-type sync)

## Context
Sync must reconcile concurrent edits from multiple devices. A single global Last-Write-Wins rule silently loses data in categories where that is unacceptable: completions, execution history, measurements, learning progress and documents. The brief explicitly requires per-type strategies.

## Options
1. Global Last-Write-Wins by timestamp.
2. Per-data-type strategies, chosen by the semantics of each category (field merge, append-only, deterministic precedence, keep-both-with-conflict, server-authoritative).
3. CRDT for everything.

## Decision
Option 2. Each data category declares its strategy (table in sync-protocol.md section 5): field-level merge for task metadata; deterministic precedence for status/completion with an audit note; whole-value LWW for schedules with a conflict record; keyed union for occurrence exceptions; append-only for execution records and measurements; most-advanced-state for learning progress; keep-both-revisions for documents; server-authoritative for membership and permissions; not-synced for local profiles.

No category uses global LWW. Where field-level LWW is used (task metadata) it is version-ordered with a timestamp tiebreak and scoped to independent fields.

## Consequences
- Pro: no silent loss of completions, history, measurements, learning progress or document content.
- Pro: authorization data is server-authoritative, so a client cannot escalate via a crafted op.
- Con: more strategies to implement and test than one global rule. Mitigated by grouping entities into the small set of categories above; Batch 4 adds golden scenarios per category.
- CRDT (option 3) is rejected for now (AP-10/AP-13); documents may revisit it in P05+ only if real multi-writer editing demands it.

## Follow-ups
- P04: implement the strategies and the conflict-record UI.
- Batch 4: a golden scenario per category (for example "two devices complete and edit the same task", "offline measurement does not overwrite a correction", "document edit conflict keeps both").
