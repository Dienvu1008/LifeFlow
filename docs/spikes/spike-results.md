# Spike Results

- Status: In progress (spike phase). One entry per spike, fixed format.
- Related: [spike-plan.md](spike-plan.md), [../FINAL-REPORT.md](../FINAL-REPORT.md) §19

Fixed entry format: **Question / Hypothesis / What was done / Measured result / Success or Failure / Decision / ADR update or Open+escalation / Human gate date.**

---

## S-03a — Auth + Windows flow + offline session
- Branch: `spike/s-03a`. POC at `spikes/s-03a-auth/` (throwaway). Time-box 3–5 pd (setup sub-cap ~1 pd).
- **Question:** Can the chosen provider (Supabase Auth, GitHub social) do email + GitHub sign-in on Windows and Android, cache an offline session, and complete a Windows desktop flow with PKCE S256?
- **Hypothesis:** Supabase Auth + a fixed-port loopback (127.0.0.1:53682) with PKCE S256 works on Windows; supabase_flutter persists the session into secure storage so it survives an offline restart; GitHub is the simplest social provider to configure.
- **What was done (agent, in this environment):** Wrote a disposable Flutter POC (email + GitHub sign-in; desktop loopback on 127.0.0.1:53682; session stored in `flutter_secure_storage` via a custom gotrue `LocalStorage`; offline status derived from the cached session with no network call, incl. read-only-on-expired-offline). Generated Windows + Android platforms; added the `lifeflow://callback` deep link. `flutter analyze` = **No issues found**. Wrote `RUNBOOK.md`.
- **Finding during owner's first Windows run (2026-11-04):** the GitHub flow reached the loopback but failed with "State mismatch". Root cause (verified against the Supabase docs/source): with `authFlowType: pkce`, the **Supabase SDK owns the PKCE verifier and the OAuth state**; the POC's original code generated its own PKCE/state and validated state at the loopback, which Supabase does not echo back. **Fix applied:** use the SDK's `getOAuthSignInUrl` (SDK stores the verifier) + `exchangeCodeForSession(code)`; the loopback now only captures `code` and does not validate state. Our manual `pkce.dart` was removed (and the `crypto` dep). This is a real mechanism finding, recorded here rather than worked around silently. Re-analyze clean. **Owner to re-run** after `git pull` on `spike/s-03a`.
- **Measured result (owner run on Windows, 2026-11-04):**
  - GitHub sign-in: Windows **PASS** (loopback + code exchange; Status=signedIn, user shown) / Android **not run** (follow-up)
  - Email sign-in: **not run** (follow-up; optional baseline)
  - PKCE S256 on Windows (not plain): **PASS** — SDK-managed PKCE flow (`authFlowType: pkce`), default S256
  - Offline restart shows signedIn without network: **PASS** — app reopened offline, Status=signedIn, no network block (terminal shows init completes, no hang)
  - Expired-offline shows signedInReadOnlyOffline: **not observed** — token not yet expired (~1h default); logic only triggers on expired+offline; acceptable
  - No token in logs: **PASS** — owner's full terminal shows only init + DevTools URLs, no access/refresh token
  - Setup time vs 1 pd sub-cap: within sub-cap (Supabase project + GitHub OAuth app configured without blockers)
- **Success or Failure:** **SUCCESS for Windows** on the core criteria (#1 session, #2 offline restart, PKCE S256, no token in logs). Email baseline and Android are **follow-ups**, not blockers for the auth-provider decision.
- **Decision:** Supabase Auth is viable for LifeFlow auth on Windows via SDK-managed PKCE + a fixed loopback. Proceed to S-01. Carry Android + email as a verification follow-up before P01 sign-in UI ships.
- **ADR update or Open+escalation:** ADR-0003 auth half → moved toward **Accepted** (Supabase Auth as the auth provider), with the Android/email follow-up noted. No escalation.
- **Human gate date:** 2026-11-04 — passed for Windows; Android/email tracked as follow-up.

---

## S-01 — Flutter + Drift on Windows/Android
- Branch: `spike/s-01`. Not started (follows the S-03a gate).

## S-02 — Migrations + FTS5-under-encryption
- Branch: runs on `scaffold/p01-skeleton` after S-01 passes. Not started.
