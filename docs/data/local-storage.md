# Local Storage

- Status: Draft (Batch 3a)
- Date: 2026-11-04
- Related: [data-architecture.md](data-architecture.md), [ADR-0009](../adr/0009-identifier-and-versioning-strategy.md), [../architecture/domain-model.md](../architecture/domain-model.md), [../research/verified-sources.md](../research/verified-sources.md) VS-04

## 1. Purpose
How the local database is structured, owned and migrated. Table ownership follows the bounded contexts (AP-04); other contexts never read a context's tables directly.

## 2. Shared column set
[Decision] Every context-owned, syncable entity table carries this base (from ADR-0009):

| Column | Type | Meaning |
|---|---|---|
| `id` | TEXT (UUID v7) | stable identity |
| `workspaceId` | TEXT | tenancy |
| `ownerId` | TEXT | ownership |
| `version` | INTEGER | optimistic concurrency (LF-INV-VER-001) |
| `createdAt` | TEXT (UTC ISO-8601) | metadata |
| `updatedAt` | TEXT (UTC ISO-8601) | metadata |
| `deletedAt` | TEXT null | tombstone (soft delete) |
| `deletedBy` | TEXT null | actor who deleted |

Value objects embedded in an aggregate (for example capabilities on Task) are columns or typed child rows of that aggregate's tables, not JSON blobs where a typed shape is needed (contrast legacy JSON-in-TEXT, assessment section 2). JSON is used only for genuinely opaque payloads (for example an outbox payload snapshot).

## 3. Table ownership
[Decision] Tables are grouped by owning context; cross-context access is only via published read ports (AP-04, DR-2).

| Context | Owns tables (illustrative names) |
|---|---|
| Workspace and Access | `profiles`, `account_bindings`, `workspaces` (+ `memberships` P04) |
| Task Management | `tasks`, `task_lists` (subtasks are `tasks` rows with `parentTaskId`) |
| Planning (Time Kernel) | none (value objects stored by Task/Event tables) |
| Calendar and Events | `events`, `calendars`, `event_exceptions` |
| Execution and Measurement | `focus_sessions`, `execution_records`, `measurements` |
| Goals and Projects | `goals`, `milestones`, `projects`, `goal_links` |
| Governance Kernel | `audit_log`, `outbox`, `event_log`, `op_dedupe` |

FTS5 virtual tables (VS-23) accompany the owning table (for example `tasks_fts` for task titles), rebuilt via triggers or in the command handler. [Open] OQ-V10 affects whether FTS5 is available on the encrypted build.

## 4. Profile isolation
[Decision] One database file per `LocalProfile` (data-architecture.md section 6). File naming includes the `profileId`; each has its own encryption key in secure storage. A query is always within the open profile's database, so cross-profile access is structurally impossible (LF-INV-ID-002), not merely filtered.

## 5. Migrations
[Decision] Use Drift's guided migrations: `drift_dev make-migrations` generates per-version schema files, step-by-step migration code and migration tests (VS-04). This replaces the legacy hand-written `if (oldVersion < N)` ladder (assessment section 1). Migrations are forward-only; each schema version has a migration test (Batch 4 ties these to the test strategy).

- [Decision] No destructive migrations like the legacy v9 (assessment). A schema change that would drop data requires an explicit, reviewed migration with a test proving no unintended loss.

## 6. Transactions and the atomic set
Every mutation's atomic set (aggregate + audit + outbox + event-log + dedupe) is one Drift transaction (ADR-0014). Repositories expose reads publicly but writes only through command handlers (ADR-0011; fitness function FF-GOV-01 in Batch 4).

## 7. Open questions
- OQ-LS-1: FTS5 rebuild strategy (triggers vs handler) and tokenizer choice (for CJK/Vietnamese search). Proposal: `unicode61` with diacritics handling; confirm when search is built (P01/P05).
- OQ-V10: FTS5 under encryption (verified-sources).

## 8. Self-check
- [x] Shared column set matches ADR-0009.
- [x] Table ownership respects context boundaries (AP-04).
- [x] Profile isolation is structural (one file per profile).
- [x] Migrations are guided, forward-only, non-destructive.
