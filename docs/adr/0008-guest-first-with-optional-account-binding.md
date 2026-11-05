# ADR-0008: Guest-first local profile with optional account sign-in

- Status: Accepted (owner decision on OQ-S5 and OQ-S6), details Proposed
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../product/product-scope.md](../product/product-scope.md) OQ-S4 to OQ-S8; [0003-backend-decision-deferred-to-spike.md](0003-backend-decision-deferred-to-spike.md); [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md) section 4.7

## Context
The owner decided that cloud sign-in must exist in the MVP (OQ-S4), that the account is used for **authentication only** (OQ-S5), and that the app **can be used before signing in** (OQ-S6). When a user who is already using the app signs in, the app asks whether to move the current data to that account. If the user declines, a new session is created.

This replaces the earlier assumption of a mandatory sign-in and a single profile per device.

## Options
1. Sign-in required before any use.
2. Guest-first: the app starts with a local profile. Sign-in is optional. On sign-in the user chooses to bind the current local data to the account, or to start a separate data space for it.
3. Guest-first with automatic merge of guest data into the account.

## Decision
Option 2.

Model (Proposal, to be detailed in the domain batch):
- **LocalProfile** exists from first launch, with a stable `profileId` and one Personal Workspace (stable `workspaceId`). Every resource carries `workspaceId` and `ownerId` as already required.
- **AccountBinding**: a LocalProfile may be bound to at most one cloud account (`accountId` from the auth provider). Binding does not change any entity ID or workspace ID.
- **On sign-in from a profile that has data**, the app asks: "Move the data you are using now to this account?"
  - **Yes**: the current LocalProfile is bound to the account. No data is copied or re-keyed.
  - **No**: a **new LocalProfile (new data space, "new session")** is created and bound to the account. The previous profile and its data stay on the device, unchanged, and remain accessible as a separate profile.
- **On sign-in from an empty profile**, the app binds without asking.
- Authentication provides identity only in the MVP. No user content is sent to the cloud (FR-AUTH-04).
- The auth session is cached securely so offline use continues. An unreachable auth server never blocks local data.

## Consequences
- Pro: lowest friction. The app is useful immediately and sign-in is never an obstacle.
- Pro: no entity is re-keyed on binding, which keeps identity stable (AP-09) and avoids a migration step when sync arrives.
- Con: a device can hold several LocalProfiles (a guest profile and one per account). This introduces profile switching and per-profile storage isolation. Data isolation between profiles must be tested (privacy requirement).
- Con: in P04, binding a profile that has local data to an account that **already has cloud data** (for example the account was used on another device) creates a merge problem. This is a real conflict case and is deferred to the sync batch (OQ-S8). Until then, binding in the MVP never meets existing cloud data because nothing is synced.
- Con: the "no, create a new session" path can strand guest data if the user forgets it exists. The UI should make the other profile discoverable (OQ-S7).
- The `AuthGateway` port is needed in the MVP, but only for sign-in, session and sign-out.

## Follow-ups
- OQ-S7: what happens at sign-out (does the user return to the guest profile, is account data kept on device, can another account sign in on the same profile?).
- OQ-S8 (P04): merge or conflict rules when a profile with local data is bound to an account that already has cloud data.
- Decide per-profile storage layout (one database file per profile versus one database with profile-scoped rows) in the data batch. Leaning to one database file per profile for isolation. [Assumption, needs spike S-01/S-02]
