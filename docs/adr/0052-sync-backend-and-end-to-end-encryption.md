# ADR-0052: Sync backend and end-to-end encryption (data half of ADR-0003)

- Status: Accepted (owner decisions D2, D3, D12, D15 of [p04-plan.md](../roadmap/p04-plan.md), 2026-11-14; spikes S-03, S-04 and S-15 PASS)
- Date: 2026-11-14
- Deciders: Project owner (direction), implementation
- Related: [ADR-0003](0003-backend-decision-deferred-to-spike.md) (its data half is decided here), [ADR-0009](0009-identifier-and-versioning-strategy.md), [ADR-0014](0014-transactional-outbox-and-atomic-side-effects.md), [ADR-0015](0015-per-type-conflict-resolution.md), [ADR-0016](0016-data-classification.md), [sync-protocol.md](../data/sync-protocol.md), [spike-results.md](../spikes/spike-results.md) (S-03, S-04, S-15)

## Context
ADR-0003 accepted Supabase Auth and left the data and sync backend to spikes S-03 (RLS) and S-04 (sync). The owner then decided that synced data is end-to-end encrypted (D12) and that a new device gets the key from a recovery key or a passphrase, the user's choice (D15). Spike S-15 checked the encryption.

## Decision
1. **Supabase (Postgres) is the sync backend**, in the same project as sign-in, on the free plan for now (D2). The schema lives in `supabase/migrations`; the owner applies it to the project (D3); CI runs its allow/deny tests on a local Supabase.
2. **The server stores sealed records, not tables of content.** `sync_records (workspace_id, id, version, seq, deleted, sealed, device_id, operation_id, updated_at)` and `account_workspaces (workspace_id, account_id, wrapped_key, unlock_kind, unlock_salt, last_seq)`. The id is a keyed hash made on the device; kind, local id, relations and all content are inside `sealed`. A new local record kind needs no server migration.
3. **Writes only through two functions** that check the caller owns the workspace: `push_records` (accepts a record when its base is the stored version, otherwise reports a conflict; a replay of an accepted operation is a no-op; change numbers come from a row lock per workspace so they commit in order) and `purge_records` (only after the 90-day retention; the tombstone stays). Row-level security limits reads to the caller's own workspaces; nothing is granted to anonymous callers.
4. **Conflicts are found by version and resolved on the devices, per type** (ADR-0015 with D6/D7): task fields merge field by field; a task's status never goes down and an occurrence tick is never undone by a conflict; schedules, reminders and notes are one value, with the other value kept for review; measurements and execution records are append-only; a delete beats an edit and the edit stays on the item in the trash. Ties fall back to the later update, then the device name. The server never resolves anything, so encryption does not limit it.
5. **End-to-end encryption.** A random 256-bit workspace key seals each record with AES-256-GCM (a fresh nonce; the server id and version as associated data) and keys the server ids (HMAC-SHA-256 via HKDF). The server holds the workspace key only wrapped by an unlock key: the recovery key (256 random bits, shown as 24 BIP-39 words with a checksum) or Argon2id of a passphrase (at least 19 MiB, 2 passes). Switching the unlock method re-wraps the key only. Devices keep the workspace key in secure storage. Library: `cryptography` (Apache-2.0, VS-42).
6. **Ports.** Application code reaches the server only through a `RemoteGateway` port; Supabase and the sealing sit behind it in `infrastructure`; tests use an in-memory server with the same semantics.

## Consequences
- The server, and whoever runs it, sees account ids, random record ids, versions, change numbers, deleted flags, sizes, times and device ids, never content (D12).
- **A lost recovery key or passphrase with no device left means the server copy cannot be read** (R-KEY-LOSS). Mitigations: setup asks the user to confirm the key, every device keeps a full copy, any device can reset sync, and the local export (ADR-0025) stays a backup that does not need the key.
- Sharing (P04b) needs a key per shared workspace, given to each member wrapped with the member's public key; the server-side checks extend to members. Decided at P04b's start.
- Spike findings carried to the tasks: execution records are written without an outbox row of their own and syncing profile settings needs a record kind (T1); pulled rows must be applied through the gateway as actor `sync` with a `sync_base` table (T3); the passphrase strength rule and the recovery-key confirmation (T1b); speed on Android (T6).
- Windows reserves port ranges (Hyper-V/WSL): the local Supabase stack uses ports 55320–55329, and Windows sign-in now takes a port the system picks (ADR-0003 update 2026-11-14).

## Alternatives considered
- **A copy of the 15 local tables on the server, readable by the server**: field merges and queries on the server, but no end-to-end encryption (rejected by D12) and a server migration for every new kind.
- **Firebase / Firestore**: not evaluated further; Postgres with RLS passed S-03, and Supabase is already the sign-in provider (ADR-0003).
- **A passphrase only, or a recovery key only**: the owner chose both, as the user's choice (D15).
- **Encryption with the server holding an escrow copy of the key**: easier recovery, but the operator could read the data (against D12).
