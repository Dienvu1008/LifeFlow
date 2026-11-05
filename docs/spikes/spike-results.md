# Spike Results

- Status: In progress (spike phase). One entry per spike, fixed format.
- Note: this file lives on each spike branch; S-03a's full entry is on `spike/s-03a`. This copy (branch `spike/s-01`) carries the S-03a outcome summary for context and the S-01 detail.
- Related: [spike-plan.md](spike-plan.md), [../FINAL-REPORT.md](../FINAL-REPORT.md) §19

Fixed entry format: **Question / Hypothesis / What was done / Measured result / Success or Failure / Decision / ADR update or Open+escalation / Human gate date.**

---

## S-03a — Auth + Windows flow + offline session (summary; full entry on `spike/s-03a`)
- **PASS on Windows (2026-11-04):** GitHub sign-in via SDK-managed PKCE (S256) + fixed loopback; session cached in secure storage survives an offline restart; no token in logs. Finding: Supabase owns PKCE/state, so use `getOAuthSignInUrl` + `exchangeCodeForSession` (not a self-made PKCE/state). Decision: Supabase Auth is the MVP auth provider (ADR-0003 auth half Accepted). Follow-up: Android + email baseline before P01 sign-in UI.

---

## S-01 — Flutter + Drift on Windows/Android
- Branch: `spike/s-01`. POC at `spikes/s-01-drift/` (throwaway). Time-box 1–2 pd.
- **Question:** Does Flutter + Drift `NativeDatabase` run cleanly on Windows and Android with bundled sqlite3 3.x (no manual native setup), supporting CRUD + an atomic transaction (+ rollback)?
- **Hypothesis:** drift 2.28 + sqlite3 3.x via `drift_flutter` bundles sqlite3 through build hooks on both platforms; a transaction commits atomically and rolls back fully on error (the ADR-0014 foundation).
- **What was done (agent, in this environment):** Wrote a disposable Flutter+Drift POC (two tables with a FK; `createDeckWithCards` in one transaction; a rollback test). Generated Windows + Android platforms. Drift codegen succeeds; `flutter analyze` = **No issues found**; `flutter test` on `NativeDatabase.memory()` = **2/2 passed** (CRUD+transaction, and full rollback). Wrote `RUNBOOK.md`. **Platform build/run not executed here** — owner verifies Windows + Android.
- **Measured result (owner to fill per RUNBOOK §3/§4):**
  - [ ] Windows: builds + runs; Create/Read/Rollback behave as specified: ___
  - [ ] Android: builds + runs; same: ___
  - [ ] No manual native sqlite setup needed (bundled): ___
  - [ ] Rollback test shows "rollback OK" (never "ROLLBACK FAILED"): ___
- **Success or Failure:** _pending owner platform run_ (headless logic already PASS)
- **Decision:** _pending_
- **ADR update or Open+escalation:** on success → confirms the Drift/NativeDatabase stack rows (technical-stack) and ADR-0013; **then create the `scaffold/p01-skeleton` branch** (Task C) on which S-02 runs. On failure → Open + escalate (reconsider local store).
- **Human gate date:** _pending_

---

## S-02 — Migrations + FTS5-under-encryption
- Branch: runs on `scaffold/p01-skeleton` after S-01 passes. Not started.
