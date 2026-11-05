# Spike S-01 — Flutter + Drift POC (THROWAWAY)

Disposable proof of concept for spike S-01 (Flutter + Drift `NativeDatabase` on
Windows and Android with bundled sqlite3 3.x). **Not** part of the LifeFlow app;
do not merge to `main` as a feature. See [RUNBOOK.md](RUNBOOK.md) and
[../spike-results.md](../spike-results.md).

- Branch: `spike/s-01`
- Proves: Drift CRUD + atomic transaction + rollback; sqlite3 bundled, no manual native setup.
- Headless tests pass in CI-less dev (`flutter test`); platform build/run is owner-verified.
