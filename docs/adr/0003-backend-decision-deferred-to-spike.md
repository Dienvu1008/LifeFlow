# ADR-0003: Backend choice deferred to a spike (default lean: Supabase)

- Status: Partially Accepted — **auth half Accepted (Supabase Auth)** after spike S-03a (2026-11-04); data/sync half still Proposed (pending S-03/S-04)
- Date: 2026-11-04
- Deciders: Project owner (auth decided after S-03a; data/sync after S-03/S-04)

## Update 2026-11-04 (auth half)
Spike S-03a passed on Windows (see [../spikes/spike-results.md](../spikes/spike-results.md)): Supabase Auth with GitHub, SDK-managed PKCE (S256) via a fixed loopback (`127.0.0.1:53682`), session cached in secure storage surviving an offline restart, no token in logs. **Decision: Supabase Auth is the auth provider for the MVP.** Follow-up before P01 sign-in UI ships: verify on Android (deep link `lifeflow://callback`) and the email baseline. The data/sync backend remains undecided (still Supabase-lean) pending S-03 (RLS) and S-04 (sync).
- Evidence: [../research/verified-sources.md](../research/verified-sources.md) VS-06 to VS-10; legacy Firebase usage in [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 4.7

## Context
The brief states a backend direction of Supabase, PostgreSQL, Auth, Storage and Realtime. The legacy app uses Firebase Auth and Firestore. The owner asked for the backend to be decided by spike and ADR, leaning to Supabase. On 2026-11-04 the owner decided that sign-in must exist in the MVP (OQ-S4), for authentication only (OQ-S5), and that the app works guest-first with sign-in optional (OQ-S6, see [ADR-0008](0008-guest-first-with-optional-account-binding.md)). The MVP therefore needs an authentication provider even though user content sync and sharing remain P04. The backend choice also shapes the data model (IDs, versions, tombstones, outbox) that the MVP must already follow, and it determines how shared-workspace isolation is enforced.

## Options
1. Supabase (PostgreSQL, Auth, RLS, Realtime, Storage).
2. Firebase (Auth, Firestore, Cloud Storage).
3. Hybrid: Firebase Auth plus Supabase for data.
4. Custom backend (not evaluated for a solo developer).

## Evaluation criteria

| Criterion | Why it matters | Evidence so far |
|---|---|---|
| Tenant isolation for shared workspaces | Core security promise; must be enforced server-side, not by the client | Supabase RLS runs in the database as part of every access (VS-06) but requires explicit grants and per-table tests; views bypass RLS by default (VS-07, VS-08). Firestore security rules not evaluated. [Open] |
| Relational fit | Workspaces, memberships, hierarchies, recurrence exceptions, audit | PostgreSQL is relational; Firestore is document-based. [Assumption] Relational fits better; to be confirmed by the shared-workspace schema in spike S-03. |
| Offline sync support | Local-first with Drift on device | Neither provides a ready-made sync for Drift; a custom outbox/inbox sync is planned either way (sync batch). |
| Auth session model | Multi-device, Windows and Android | Supabase sessions use short-lived JWT plus single-use refresh tokens with reuse detection (VS-09). Windows desktop OAuth flow must be verified by a spike. [Open] |
| Realtime limits | Small teams | Free plan: 200 concurrent connections, 100 messages/s (VS-10). Sufficient for small teams; verify against real usage. |
| Cost and operations burden for a solo developer | Time cost dominates | Pricing, backups and Edge Function limits not yet verified (OQ-V4). |
| Path to public release | Scale seam (principle P9) | Postgres plus RLS gives a standard scaling path. Firestore also scales. Neutral. [Assumption] |
| Lock-in | Future flexibility | Postgres is portable; Firestore is proprietary. [Assumption] |
| Migration cost from legacy Firebase code | None needed (no data migration) | Only auth code is Firebase-specific and is being replaced anyway. |

## Decision (provisional)
**Split the decision in two.**

1. **Authentication provider: must be decided before P01 completes**, because the MVP requires the sign-in feature to exist (use of it stays optional, ADR-0008). A new, small spike **S-03a (auth only)** runs first: email plus one social provider, session persistence across offline restarts, the Windows desktop sign-in flow (no PKCE `plain`, refresh handled correctly), and the guest-to-account binding described in ADR-0008. Candidate outcomes: Supabase Auth (default lean), Firebase Auth, or a thin provider-neutral port with one implementation.
2. **Data and sync backend: still deferred to P04**, decided after spikes S-03 (Supabase RLS for shared workspaces) and S-04 (offline sync and conflict reconciliation).

The MVP data model assumes a PostgreSQL-compatible shape (UUID primary keys, per-entity version, `workspaceId`, tombstones) because that shape is also valid for a document backend.

**Default if spikes pass:** Supabase for both. **Fall back to:** reconsider if the Windows auth flow, RLS performance or sync cost fail the spike criteria. Using different vendors for auth and data is the Hybrid option, still not recommended unless S-03a fails for Supabase.

The MVP must work fully offline from first launch, with or without sign-in (ADR-0008). The auth session, once created, is cached locally and the app must not block on network for normal use.

## Consequences
- **P01 core work is not blocked** because the app is guest-first (ADR-0008). The auth-provider decision (spike S-03a) must be made before the sign-in work package starts, and before P01 exit if sign-in is part of P01. The roadmap batch schedules it.
- Auth failure or an unreachable server must never make local data inaccessible (NFR-OFF-01).
- Application code talks to the backend only through ports (`AuthGateway` in the MVP, `RemoteGateway` from P04) so the choice can still be changed. [Proposal, avoids a speculative abstraction by being the same ports the sync design needs]
- The Hybrid option is not recommended: two vendors, JWT compatibility work, and no clear benefit. [Proposal]

## Follow-ups
- Spike S-03a (new, before P01 exit): authentication only, including Windows desktop flow and offline session persistence.
- Spike S-03: multi-tenant RLS with membership table, performance and test approach (`supabase test db`).
- Spike S-04: outbox/inbox sync prototype with deliberate conflicts.
- Verify Windows desktop OAuth flow for the chosen provider.
- Gather Supabase pricing and backup limits (OQ-V4).
