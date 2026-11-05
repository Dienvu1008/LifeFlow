# Spike S-03a — auth POC (THROWAWAY)

This is a disposable proof of concept for spike S-03a (auth + Windows flow +
offline session). It is **not** part of the LifeFlow application and must not be
merged into `main` as a feature. See [RUNBOOK.md](RUNBOOK.md) to run it and
[../spike-results.md](../spike-results.md) for the result.

- Branch: `spike/s-03a`
- Provider: Supabase Auth (primary); fallbacks Firebase Auth / self-hosted GoTrue.
- Social login: GitHub.
- Honors SR-06 (PKCE S256 on Windows), SR-07 (session in secure storage, offline-safe).
