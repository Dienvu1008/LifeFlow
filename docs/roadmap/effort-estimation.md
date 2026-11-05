# Effort, Resource, Performance and Cost Estimation

- Status: Draft (Batch 5)
- Date: 2026-11-04
- Related: [phase-breakdown.md](phase-breakdown.md), [master-roadmap.md](master-roadmap.md), [../testing/test-strategy.md](../testing/test-strategy.md), [risk-register.md](risk-register.md)

All numbers are **ranges with assumptions and a confidence level**, for **one developer + one coding agent (a single delivery lane)**. They are not commitments. Person-days (pd) count developer-driven effort; the agent raises throughput within the lane but does not add a second lane. High variance is expected.

## 0. Out of estimation scope (explicit)
To avoid mistaking a range for a commitment, these are **not** estimated here:
- **Actual cloud-AI cost**: only token/request ranges and the benchmark needed (section 4); real cost depends on provider pricing and usage, decided at P06.
- **Legal review time** (OQ-SEC-1, encryption export; license interpretation): needs external input; no duration given.
- **External-dependency waiting time**: license negotiation/clarification (S-10) and real-device availability (S-13) are calendar waits, not effort; excluded.
- **Calendar dates**: ordinal only (master-roadmap.md).

## 1. Engineering effort per phase (pd ranges)
[Assumption] Based on the scope in phase-breakdown.md and the legacy port opportunities (assessment); confidence is Low-to-Medium because this is a greenfield solo+agent build.

| Phase | Range (pd) | Confidence | Dominant cost |
|---|---|---|---|
| P00 Design | (this corpus) | — | done when Batch 5 completes |
| MVP-blocking spikes (S-01/02/03a) | 4–9 | Medium | environment + auth proof |
| P01 Core + Workspace | 20–40 | Low–Med | governance spine, encryption, atomic-set tests |
| P02 Planning + Calendar | 15–30 | Low–Med | recurrence/DST correctness + tests |
| P03 Execution + Goals + Focus | 15–30 | Low–Med | focus state machine + recovery, habit/goal derivation |
| **MVP subtotal (P01–P03 + spikes)** | **~55–110** | Low–Med | the whole critical path |
| P04 Collaboration + Sync | 30–60 | Low | sync is the single hardest area |
| P05 Documents | 20–45 | Low | editor + viewers + revisions |
| P06 AI | 20–45 | Low | orchestrator wiring + governance + routing |
| P07 Dictionary + Vocabulary | 15–35 | Low | providers + offline + spaced repetition |
| P08 Health | 8–18 | Low–Med | Health Connect + dedup (scoped to steps) |
| P09 Learning + Automation | 15–35 | Low | course model + generation |
| P10 Advanced/iOS | not estimated | — | per validated need (AP-13) |

[Proposal] Add a **risk buffer of +30–50%** on P04 and anything sync-touching, and +20–30% elsewhere, given solo+agent variance. The buffer is on top of the ranges, not inside them.

## 2. Effort split by area (proportional, MVP)
[Assumption] Rough proportions for P01–P03 combined:

| Area | Share | Note |
|---|---|---|
| Domain (contexts, value objects) | ~25% | much is pure logic; some ported (time, progress) |
| Data/infra (Drift, gateway, outbox, encryption, migrations) | ~30% | the governance spine is front-loaded in P01 |
| UI (adaptive shell, screens, view models) | ~20% | Riverpod + go_router |
| Testing (unit/property/crash/concurrency) | ~20% | crash/concurrency tests are high-value, non-trivial |
| Security (encryption, secure storage, egress) | ~5% | small but critical |

The human is the bottleneck for review and decisions; the agent compresses the Domain/Testing shares most, less so Security (needs human judgment).

## 3. Critical path (pd)
P00 → spikes (4–9) → P01 (20–40) → P02 (15–30) → P03 (15–30). Critical-path MVP effort ≈ **55–110 pd** before buffer, **~70–150 pd** with the suggested buffer. There is no parallel branch to shorten it in one lane (dependency-map §2). After MVP, P04 (30–60 pd) is the next critical node gating P05–P09.

## 4. Storage, sync, AI, performance estimates

### Storage / data growth [Assumption]
- Tasks/events/goals: small text rows; thousands of rows are kilobytes-to-megabytes. Dominated by **attachments** (stored as files, not in DB) and **document revisions** (P05) and **audit/outbox** growth.
- Audit + outbox + event log grow per mutation; retention/compaction (OQ-GOV-2) bounds them. Benchmark needed: growth per active day.

### Sync [Assumption]
- Payload per operation is small (a change set or tombstone). Conflict rate depends on multi-device usage; for a solo user across two devices it is low. Benchmark needed at P04: payload sizes, conflict frequency.

### AI token/request [Assumption]
- Context Builder keeps context bounded (not whole-DB), so per-request tokens are modest. Only **ranges** are meaningful here; actual cost is out of scope (section 0) and decided at P06 with the chosen provider. Caching repeated context reduces tokens.

### Performance targets
Restated from [test-strategy.md](../testing/test-strategy.md) §3 as Assumption/benchmark-needed: cold start (~<2 s), 10k-task list (60 fps), occurrence generation (~<50 ms/month-window/200 rules), focus accuracy (within 1 s, measured by GS-13), dictionary lookup and sync latency (TBD). **Benchmarks needed** on a mid-range Android device and a typical Windows laptop before any threshold is treated as firm.

## 5. Resourcing notes (solo + agent)
- One lane: exits serialize on the single human reviewer. The agent increases per-phase throughput (drafting code, tests, docs) but cannot review its own exit gates — the Human gate (dependency-map) is the pacing constraint.
- Sustainable pace matters more than peak; the buffer (section 1) accounts for context-switching and decision latency.

## 6. Self-check
- [x] Every estimate is a range with an assumption and a confidence.
- [x] "Out of estimation scope" lists cloud-AI cost, legal review, external waiting, calendar dates.
- [x] Critical path identified (MVP ≈ 55–110 pd pre-buffer); no fake-precise single numbers.
- [x] Benchmarks-needed are listed for performance and growth.
