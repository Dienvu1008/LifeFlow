# ADR-0024: Sign-out keeps the account's profile and locks it until that account signs in again

- Status: Accepted (owner decision, 2026-11-06, P01 task T6c)
- Date: 2026-11-06
- Deciders: Project owner
- Refines: [ADR-0008](0008-guest-first-with-optional-account-binding.md) and the OQ-S7 decision in [../domains/workspace-and-access.md](../domains/workspace-and-access.md)
- Evidence: owner device test (T6c): after signing out and back in with the same account, the account's data appeared as guest data and the account got an empty profile

## Context
From T4 to T6c, `SignOut` **cleared the account binding** from the profile. The profile became a guest and lost its link to the account. When the same account signed in again, the app no longer found "the profile of this account": it either asked to move the (now guest) data, or created an empty profile. The data was never lost, but the result was wrong. OQ-S7 says sign-out returns to the profile chooser, data stays on the device, and each profile belongs to at most one account. The intent is that the profile still belongs to the account and only the session ends. The T4/T6b tests asserted the faulty behavior, so they did not catch it.

Two postures were compared for a signed-out account profile:
- (a) still openable without signing in (fully local-first);
- (b) **locked until the same account signs in again** (the behavior of mature apps).

Being signed in needs the network only once. After that the session is cached in secure storage. Going offline, or an access token expiring while offline, does not sign the user out, so the signed-in profile stays fully usable offline (LF-INV-SEC-002). Guest mode is always available without an account. The owner chose (b).

## Decision
- **Sign-out keeps the binding.** The profile stays the account's profile. It is marked `signedOut` in its own store (schema v2; source of truth, ADR-0023) and mirrored in the registry. Its data stays on the device.
- **A signed-out profile is locked.** It cannot become the active profile (`setActive` refuses; Switch is refused with `policyDenied`). The profile chooser shows it as "<provider> account · signed out" with **Sign in to open**.
- **After sign-out the app moves to a guest profile** (an existing guest, or a new empty one) and opens the profile chooser (OQ-S7). If the app stops right after a sign-out, the next start never opens the locked profile.
- **Signing in again with the same account unlocks it** (`resume`, audited as `ResumeSession`) and opens it with all its data. Nothing is asked and no profile is created. A different account never unlocks it; that account goes to its own profile, or follows the ADR-0008 bind rules.
- **The lock is a local flag set only by an explicit sign-out**, never by connectivity or token expiry. One more trigger: if the identity provider itself ends the session while online (for example a revoked refresh token), `AuthGateway.sessionRevoked` fires and the profile is locked as for a sign-out. Network failures during refresh do not fire it.
- **Scope of the lock:** in the MVP this is an **application-level** lock, not a cryptographic one. The profile store stays encrypted with a key kept in the device's secure storage. The app will not open the profile, but someone with technical access to the same OS user account could still extract the key. A cryptographic lock needs key material held by the server or wrapped by a passphrase (OQ-DATA-3, P04).

## Consequences
- Pro: signing out and back in returns to the same data, which matches user expectations and OQ-S7.
- Pro: better privacy on a shared device. A signed-out account's data is not shown to the next person using the app.
- Pro: offline use is unaffected for a signed-in user (LF-INV-SEC-002 unchanged).
- Con: reopening a signed-out profile requires the network (to sign in). This is accepted: the user chose to sign out.
- Con: profiles that earlier builds already turned into guests (binding cleared) are not recognized automatically. Signing in on such a profile and choosing **Move my data** re-links it once.
- New open question **OQ-S9**: move all or part of a guest profile's data into a signed-in account's profile (selection, duplicates, id preservation). Today "Move my data" can only bind the whole guest profile in place.

## Verification
- Domain: `LocalProfile.isLocked` / `canResumeWith`; only the same account may resume.
- Handler: sign-out keeps the binding and locks; resume is refused for another account or a profile that is not signed out; both are audited.
- Account service on real per-profile stores: sign-out moves to a new or existing guest and the chooser; the same account signing in again returns to its data (the owner's scenario); Switch to a locked profile is refused; a different account does not unlock it; provider revocation locks; a restart right after sign-out never opens the locked profile.
- Schema: existing v1 profile stores and registry upgrade to v2 with data intact.
- UI and app: end-to-end on real stores (sign in → add task → sign out → "Sign in to open" → task is back), and the locked profile shows no Switch.
- Mutations: clearing the binding on sign-out fails 10 tests; skipping the unlock fails 2.
