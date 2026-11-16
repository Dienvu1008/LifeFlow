# ADR-0055: The sync server port and its contract

- Status: Accepted (P04 task T2, 2026-11-14)
- Date: 2026-11-14
- Deciders: Implementation, within [ADR-0052](0052-sync-backend-and-end-to-end-encryption.md) and the owner's decisions D2, D3, D11, D12 of [p04-plan.md](../roadmap/p04-plan.md)
- Related: [ADR-0003](0003-backend-decision-deferred-to-spike.md) (`RemoteGateway` from P04), spike S-03, [ADR-0054](0054-sync-keys-recovery-key-and-passphrase.md)

## Decision
1. **Port.** `RemoteGateway` in `application`: list, create, re-wrap and delete the account's synced workspaces; push (at most 500 records), pull (pages of at most 1000 after a cursor), purge. Only sealed records, opaque ids and wrapped keys cross it. Failures are `RemoteFailure` of four kinds the app can explain: unavailable (offline, timeout, a paused free project, a server error), signed out, not yours, refused (malformed; a bug, not the user's).
2. **Server functions.** S-03's `push_records` and `purge_records` (security definer, owner checked first) and a new `pull_records` (security invoker, so row-level security applies: a foreign or unknown workspace gives no rows rather than an error that says it exists; sealed bytes as base64). Workspaces are read, created, re-wrapped and deleted through the `account_workspaces` table under its policy and column grants.
3. **Two implementations with one contract.** `HttpRemoteGateway` talks to Supabase's REST API with the project's public key and the signed-in account's access token, which the app hands in as a callback; the token never goes through an application port (LF-INV-SEC-002 stays as it is). It uses `http` 1.6.0 (BSD-3, already shipped). `MemoryRemoteGateway` keeps the same semantics in memory for tests, with a clock for the retention and a switch for an unreachable server. `remote_contract_test.dart` runs the same cases against both; CI's `supabase-db` job starts the local stack's REST API and sign-in and runs it against Supabase too.

## Consequences
- Tests: pgTAP `pull_records.test.sql` (8 assertions: pages, cap, order, base64, isolation, anon); the contract's 8 cases on both servers plus a memory-only purge after the retention and a forged token on Supabase (18 in all). Mutations 9/9 killed, after removing an error mapping the contract showed to be redundant (PostgREST already answers 403).
- Both servers behave the same on every contract case, including a refused batch writing nothing and another account's attempt to take a workspace id.
- **Before T6 the owner applies the migrations to the real project** (D3): `supabase login`, `supabase link --project-ref <ref>`, `supabase db push`.
- T3 builds the sync engine on this port; the S-04 prototype's fake server is replaced by `MemoryRemoteGateway`.
