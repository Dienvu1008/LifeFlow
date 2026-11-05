# Spike Results

- Status: In progress (spike phase). One entry per spike, fixed format.
- Related: [spike-plan.md](spike-plan.md), [../FINAL-REPORT.md](../FINAL-REPORT.md) §19

Fixed entry format: **Question / Hypothesis / What was done / Measured result / Success or Failure / Decision / ADR update or Open+escalation / Human gate date.**

---

## S-03a — Auth + Windows flow + offline session
- Branch: `spike/s-03a`. POC at `spikes/s-03a-auth/` (throwaway). Time-box 3–5 pd (setup sub-cap ~1 pd).
- **Question:** Can the chosen provider (Supabase Auth, GitHub social) do email + GitHub sign-in on Windows and Android, cache an offline session, and complete a Windows desktop flow with PKCE S256?
- **Hypothesis:** Supabase Auth + a fixed-port loopback (127.0.0.1:53682) with PKCE S256 works on Windows; supabase_flutter persists the session into secure storage so it survives an offline restart; GitHub is the simplest social provider to configure.
- **What was done (agent, in this environment):** Wrote a disposable Flutter POC (email + GitHub sign-in; desktop loopback + PKCE S256; session stored in `flutter_secure_storage` via a custom gotrue `LocalStorage`; offline status derived from the cached session with no network call, incl. read-only-on-expired-offline). Generated Windows + Android platforms; added the `lifeflow://callback` deep link. `flutter pub get` succeeded; `flutter analyze` = **No issues found**. Wrote `RUNBOOK.md`. **Not run on device/OAuth here** — requires the owner's Windows + Android + a Supabase project + GitHub OAuth app.
- **Measured result (owner to fill after running per RUNBOOK §0/§5/§6):**
  - [ ] Email sign-in: Windows ___ / Android ___
  - [ ] GitHub sign-in: Windows ___ / Android ___
  - [ ] PKCE S256 used on Windows (not plain): ___
  - [ ] Offline restart shows signedIn without network: ___
  - [ ] Expired-offline shows signedInReadOnlyOffline: ___
  - [ ] No token in logs: ___
  - Setup time vs 1 pd sub-cap: ___
- **Success or Failure:** _pending owner run_
- **Decision:** _pending_
- **ADR update or Open+escalation:** on success → move ADR-0003 auth half toward Accepted (Supabase Auth for auth); on failure → Open + escalate (try Firebase Auth / self-hosted GoTrue per spike-plan).
- **Human gate date:** _pending_

---

## S-01 — Flutter + Drift on Windows/Android
- Branch: `spike/s-01`. Not started (follows the S-03a gate).

## S-02 — Migrations + FTS5-under-encryption
- Branch: runs on `scaffold/p01-skeleton` after S-01 passes. Not started.
