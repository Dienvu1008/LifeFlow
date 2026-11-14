# P04 plan: Sync & Collaboration

- Status: **Draft, for the owner's decisions** (D1–D14 below are proposals)
- Date: 2026-11-14
- Inputs: [phase-breakdown.md §P04](phase-breakdown.md), [definition-of-done.md](../testing/definition-of-done.md) (P04 anchors), [effort-estimation.md](effort-estimation.md), [sync-protocol.md](../data/sync-protocol.md), [governance-kernel.md](../governance/governance-kernel.md), [authorization-model.md](../governance/authorization-model.md), [data-classification.md](../data/data-classification.md), [workspace-and-access.md](../domains/workspace-and-access.md), ADR-0003 (backend: auth half accepted, data half open), ADR-0008, ADR-0009, ADR-0014, ADR-0015, ADR-0016, ADR-0024, ADR-0025, invariants SYNC-001…004, VER-001, GOV-001…003, ID-001/002, PRIV-001…003, WA-001; GS-08, GS-14, GS-17 (and GS-11, GS-12, GS-22); UC-13, UC-16, UC-19, UC-20b; open questions OQ-S8, OQ-S9, OQ-SYNC-1…3, OQ-CLASS-1, OQ-AUTHZ-1, OQ-GOV-2/3, OQ-DATA-3 (b/c), OQ-V4
- Estimate (effort-estimation.md): 30–60 person-days plus a 30–50 % risk buffer ("sync is the single hardest area"). Prerequisites: P03 exit (done 2026-11-14), spikes S-03 and S-04.

## 1. Goal and exit gate
The same account's data on Windows and Android, kept in step without losing anything; then workspaces shared with other people. Local-first stays: the app works fully offline and never waits for the network to read or write (NFR-OFF-01).

Because of its size, P04 is proposed in two parts (D1):
- **P04a, sync of one account's devices**: backend decision, server schema, the sync engine, joining a second device, status and conflicts in the UI.
- **P04b, sharing**: shared workspaces, members and roles, invitations, sharing tasks, calendars and goals, server-side authorization per member. Planned in detail at the start of P04b, after P04a's exit.

Exit gate (DoD P04 anchors):
- Offline changes survive sync, with an idempotent replay (GS-17, SYNC-001, OUTBOX-001).
- A delete syncs as a tombstone and a purge after retention propagates (GS-14, SYNC-004).
- Conflicts are detected by version, never by time (SYNC-002), and resolved per data type, never by a global last-writer-wins (SYNC-003). GS-08 proper is about documents (P05); P04a proves the same rule on its own types (D9).
- The data backend is decided (ADR-0003 data half, a new ADR after S-03/S-04).
- P04b adds: a member cannot read or write another workspace's rows, even with crafted requests (server-side RLS allow/deny suite, R-PERMISSION); nothing personal becomes shared implicitly (PRIV-002/003).

Fitness functions: the static set, FF-ARCH-06/09 for every new handler (the sync apply path goes through the same gateway, GOV-001), FF-ARCH-07 for new packages, and FF-ARCH-08 prepared (the sync egress checks the classification, D4).

Out of scope: documents and their conflicts (P05), AI (P06), health data (P08; Restricted data never syncs by default), external calendar sync (Google/Outlook, P10), CRDTs (ADR-0017 trigger, P10), background sync while the app is closed (D8).

## 2. Starting point (checked in code)
- Every record table has the syncable columns (UUID v7 `id`, `workspaceId`, `ownerId`, `version`, timestamps, `deletedAt`/`deletedBy` tombstone; ADR-0009). Deletes are tombstones everywhere (SYNC-004 write side done).
- Every command writes an outbox row in the same transaction as the change (ADR-0014, FF-ARCH-06), with `entityType`, `baseVersion`, `operationType` and a JSON payload. **Nothing reads the outbox yet**: its `status` stays `pending`. The payload shape differs per handler (a full row in some, a change set in others).
- `OpDedupe` makes a repeated `operationId` a no-op (the base of SYNC-001).
- `record_kinds.dart` lists the 15 record kinds with their JSON read/upsert; export/restore already merges by id (by hand, not per type).
- Supabase is used **for sign-in only** (`supabase_flutter` 2.18.3 in the app; `SupabaseAuthGateway`). No data client, no server schema, no `supabase/` folder, no `RemoteGateway` port.
- Workspaces: one personal workspace per profile (WA-001); `Workspaces.kind` exists but only `personal` is used; no memberships.
- **Each device gives the same account its own profile and workspace ids** (ADR-0025 T7c). Records created separately on two devices are different records. Joining a second device must deal with this (OQ-S8, D5).
- Store schema v9. Sync tables mean v10.
- Spikes S-03 (RLS) and S-04 (two-replica sync harness) have no results yet.

## 3. Owner decisions (proposals)

| # | Question | Proposal |
|---|---|---|
| D1 | Split P04 | **P04a: sync of one account's devices; P04b: sharing.** Each with its own exit gate and your review. P04a first, because sharing needs working sync. |
| D2 | Backend for data (ADR-0003 data half) | **Supabase (Postgres + RLS), the same project as sign-in**, if S-03 and S-04 pass. Free plan limits (checked 2026-11-14): 500 MB database, two active projects, and **a free project pauses after a week of low activity** until it is resumed from the dashboard ([Supabase](https://supabase.com/kb/faqs/platform/database-only-cost)). For two devices of one person 500 MB is plenty; the pause only stops sync, never local use. You decide whether the free plan is enough for now or you move to a paid plan (OQ-V4, R-CLOUD-COST). |
| D3 | Who changes the server schema | The schema lives in the repo (`supabase/migrations`, SQL). **You apply it to the real project** (`supabase db push` with your login); the agent never holds the database password or the service key. The RLS tests run in CI on a local Supabase (Docker on the GitHub runner). Locally on Windows they need Docker Desktop: install it, or rely on CI only. |
| D4 | What syncs (OQ-CLASS-1) | **Sync is off until you turn it on per profile** ("Sync this profile with my account"), and then covers all current data: lists, tasks with notes, schedules and repeats, events and calendars, reminders, habits and measurements, period results, focus sessions and records, goals. Profile settings sync (for example the manual-results setting). **Device settings do not sync** (theme, font and text size, drag handles, night hours, zoom, week start). The audit log stays on the device. Restricted data (health, P08) never syncs by default. Guest profiles never sync. |
| D5 | A second device joins an account that already has data (OQ-S8) | The first device that turns sync on makes the account's workspace. On another device, turning sync on asks: **"Merge this device's data into the account"** (default: its records keep their ids and move into the account's workspace; the same record on both sides is resolved per type, D6) or **"Use only the account's data"** (this device's data is saved to an export file first, then replaced). This is one command with an undo snapshot, like a restore (ADR-0025). |
| D6 | Conflict rules | **ADR-0015 as written**: task fields merge field by field (the newer version per field); a completion is never undone by a conflict (done wins); a schedule or repeat is one value (the newer version wins and the other is kept as a conflict to review); occurrence changes are united by date; focus records and measurements are append-only (never overwritten). New types: **notes** (F3) are one value like a schedule (the other text is kept for review, never lost); colours and order keys follow task fields; a habit's period results follow the measurements (recomputed, not merged). |
| D7 | Delete against edit (OQ-SYNC-2) | **The delete wins, the edit is not lost**: the item stays in the trash with the other device's edit applied, and a note in "Changes to review" says so; restoring brings it back with the edit. A purge (empty trash) after the retention period is synced too, so other devices purge. |
| D8 | When sync runs | **On app start, on return to the app, a few seconds after each change, every few minutes while open, and with "Sync now".** No sync while the app is closed (Android and Windows limit background work; R-BACKGROUND). Instant updates through Supabase Realtime only if polling proves too slow (measured in T6). |
| D9 | What you see | A **sync status** under the profile in the drawer and rail: up to date (with the time), syncing, offline, paused server, or an error with what to do. Settings → Sync: the switch, "Sync now", this device's name, and **"Changes to review"** (schedule, notes and delete conflicts: keep this one, take the other). |
| D10 | Ordering and old app versions (OQ-SYNC-1, OQ-SYNC-3) | The server gives every accepted change a number; devices pull in that order (one total order per account, so per-record order holds). Every change carries its schema version. **A device on an older app version pulls but does not push newer kinds of change; it says "Update LifeFlow to keep syncing"** and keeps working locally. |
| D11 | Signing out and deleting cloud data (OQ-S7 refinement, UC-20b) | Signing out stops sync and locks the profile as today (ADR-0024); nothing is deleted. Settings → Sync gets **"Delete my data from the server"**: removes the account's synced rows; the data on this device stays. Deleting the account itself stays in the Supabase dashboard for now. |
| D12 | Encryption of synced data | Encrypted in transit (TLS) and at rest by Supabase, and fenced per account by RLS. **Not end-to-end**: whoever runs the Supabase project (you) could read it. End-to-end encryption would make sharing (P04b) and server checks much harder; propose to revisit before a public release. This answers OQ-DATA-3 (b/c) as "not needed for P04". |
| D13 | Moving part of a guest profile into an account (OQ-S9) | **Still deferred**: the whole profile only, as today. |
| D14 | P04b scope, decided at its start | Shared workspaces with **roles owner / editor / viewer** (OQ-AUTHZ-1), invitations by link or email, an item is shared only by an explicit action (PRIV), shared tasks, calendars and goals, assignment. Comments and activity feed are optional for P04b. |

## 4. Technical design choices (no owner input needed; ADR-0052 and later)
- **Port**: `RemoteGateway` in `application` (push a batch, pull since a cursor, account workspace, delete my data). Supabase behind it in `infrastructure`; a fake in-memory server with the same semantics for headless tests (FF-ARCH-04 unchanged: the UI never sees it).
- **Server model** (Postgres, `supabase/migrations`): one table of records rather than a copy of the 15 local tables: `(workspace_id, kind, id, version, schema_version, data jsonb, deleted_at, seq bigserial, device_id, operation_id, updated_at)` plus `account_workspaces`. Push is one SQL function that checks each record's `base_version` and accepts or reports a conflict, atomically; pull selects `seq > cursor`. RLS: a row is visible and writable only for the account that owns its workspace (P04b extends this to members). Adding a local kind needs no server migration.
- **Outbox contract** (schema v10): each outbox row carries the full record after the change, its schema version and the device id, so the receiver needs no handler-specific shapes. `status` moves pending → sent → acked. A local `sync_base` table keeps the last synced copy of each record for three-way merges (D6). `sync_state` keeps the cursor and the last result.
- **Apply path**: pulled changes are applied as commands of actor `sync` through the same gateway (GOV-001, FF-ARCH-06/09), deduped by `operationId` (SYNC-001); a version mismatch goes to the per-type resolver (SYNC-002/003) in `domain` (pure, property-tested); unresolvable cases become review items (D9).
- **Egress check**: the push step asks the classification policy before anything leaves the device (PRIV-003; prepares FF-ARCH-08).
- **Retention**: tombstones are kept at least 90 days before a purge is offered (OQ-GOV-2 answered for sync; dedupe rows kept as long as tombstones).
- **Tests**: the two-replica harness from S-04 grows into the sync test suite (GS-14, GS-17, the per-type table, random interleavings as property tests); pgTAP allow/deny tests for RLS run in CI against a local Supabase; a contract test runs the same cases against the fake server and the local Supabase so they cannot drift apart.

## 5. Tasks (P04a)
One branch per task; merge after the headless tests pass and, where marked, you check the devices.

| Task | Content | Main proof | Device check | Est. (pd) |
|---|---|---|---|---|
| **S-03** Spike: RLS | Local Supabase in CI, the records table, account-scoped RLS, push function with version check; pgTAP allow/deny | RLS suite green in CI; another account's rows unreadable and unwritable, also through the function | no | 2–4 |
| **S-04** Spike: sync harness | Two replicas + fake server; deliberate offline conflicts per ADR-0015; replay | conflicts resolve per type, idempotent replay, no loss | no | 3–5 |
| **ADR** Backend decision | ADR-0052: data half of ADR-0003 from S-03/S-04, with your D2/D3 answers | — | no | 0.5 |
| **T1** Outbox contract | Schema v10: full-record outbox payloads, schema version, device id, status, `sync_base`, `sync_state`; upgrade test | every handler's outbox row parses as its record kind (guard test over all ops) | no | 2–3 |
| **T2** Server schema | Migrations, `account_workspaces`, push and pull functions, retention; contract tests fake ↔ local Supabase | contract suite green on both | no | 2–3 |
| **T3** Sync engine | Push, pull, apply as actor `sync`, per-type resolver, review items, tombstones and purge, backoff, partial failure | GS-17, GS-14, SYNC-001…004, property tests over interleavings | no | 5–7 |
| **T4** Joining and leaving | Turn sync on (first device / merge / use the account's data, D5), sign-out (D11), delete my server data | merge keeps ids and loses nothing; undo restores; GS-22 still holds | no | 3–4 |
| **T5** UI | Sync status, Settings → Sync, Changes to review, update notice (D9, D10) | widget tests; app integration test on real stores with the fake server | **yes** | 3–4 |
| **T6** Two real devices | Your Supabase project, Windows + Android: offline edits, conflicts, deletes, a second device joining; measure sync time (D8) | your check on both devices | **yes** | 1–2 |
| **T7** P04a exit gate | p04a-exit-gate.md, ADRs, risk register, invariant matrix; your review | all suites, CI | yes | 1 |

Order: S-03 and S-04 → ADR-0052 → T1 → T2 → T3 → T4 → T5 → T6 → T7. P04a total about 23–34 person-days; P04b is estimated at its start (roughly 15–25).

## 6. Risks
- **R-OFFLINE-SYNC** (sync bugs lose data). Mitigation: per-type rules in pure, property-tested code; the gateway apply path with dedupe; the undo snapshot when joining; spikes first; a narrower set of kinds if a type proves hard.
- **R-DATA-LOSS** (a merge or a purge removes something). Mitigation: nothing is overwritten without a `sync_base` three-way check; append-only kinds never overwritten; delete-vs-edit keeps the edit (D7); purge only after retention.
- **R-PERMISSION** (one account reads another's rows). Mitigation: RLS from the first server table, pgTAP allow/deny in CI, the push function checks ownership too; P04b extends the suite per role.
- **R-CLOUD-COST / free-plan pause**. Mitigation: local-first (a paused server only stops sync, and the status says so); small payloads (one record per change); your budget decision in D2.
- **R-SCOPE**. Mitigation: the P04a/P04b split; Realtime, comments and the activity feed only if needed.
