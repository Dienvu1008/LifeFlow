# ADR-0009: Identifier, versioning and tombstone strategy

- Status: Accepted
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Evidence: [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 2 (legacy: only `updateTimeStamp` + `deviceId`, no version); [../research/verified-sources.md](../research/verified-sources.md) VS (uuid v7, added below)

## Context
LifeFlow is local-first and must add sync (P04) without re-keying data (ADR-0002, ADR-0008). Mutations flow through a command gateway with optimistic concurrency (ADR-0011). The legacy app had no per-entity version and no real tombstones (hard delete differed per table); this made safe sync impossible.

## Options for identity
1. Client-generated UUID v4 (random).
2. Client-generated UUID v7 (time-ordered, RFC 9562).
3. Server-assigned IDs.

## Options for change tracking
1. `updateTimeStamp` only (legacy).
2. Monotonic integer `version` per entity plus timestamps.
3. Vector clocks / CRDT metadata.

## Decision
- **Identity:** client-generated **UUID v7** for every aggregate root and for child entities that need stable identity (Subtask, Milestone, ExecutionRecord, Measurement, OccurrenceException). v7 is time-ordered, which gives natural local ordering and better index locality than v4 while staying collision-safe and offline-generatable. Verified: the `uuid` package 4.x supports v7 (see verified-sources VS-19). IDs never change, including on account binding (ADR-0008) and future sync.
- **Versioning:** every aggregate root carries a monotonic integer `version`, incremented once per successful command. Commands supply `expectedVersion`; a mismatch is a concurrency conflict (ADR-0011). Child entities do not carry their own version; the aggregate root's version covers them.
- **Timestamps:** `createdAt` and `updatedAt` are UTC `Instant`s (see ADR-0010 for the time model). They are metadata, not the basis for conflict resolution (version is).
- **Tombstones:** deletion sets a tombstone (`deletedAt` UTC instant + `deletedBy` actor) and keeps the row until a retention window allows purge. Hard delete is reserved for purge and for "discard" of never-synced local data. Tombstones are included in export (AC-20a.1) and will propagate in P04 sync.
- CRDT/vector clocks are out of scope (AP-10); revisit only if a context needs true concurrent merge (documents, P05+).

## Consequences
- Pro: sync can be added without a migration that changes IDs.
- Pro: optimistic concurrency is simple and deterministic.
- Con: every table needs `version`, `createdAt`, `updatedAt`, `deletedAt`, `deletedBy`, `workspaceId`, `ownerId` columns; a shared base is documented in the data batch.
- Con: UUID v7 embeds a timestamp; it is not a secret and must not be treated as one (it leaks creation time). Acceptable for this data.

## Follow-ups
- Data batch: shared column set and index strategy; purge/retention policy per data classification.
- Add `uuid` v7 support to verified-sources (done: VS-19).
