# Product Vision

- Status: Draft (Batch 1)
- Date: 2026-11-04
- Related: [product-scope.md](product-scope.md), [../architecture/architecture-principles.md](../architecture/architecture-principles.md)

Label legend: see [../README.md](../README.md).

## 1. Positioning

[Decision] LifeFlow is a **Personal & Collaborative Life Operating System**: one environment where a person plans time, executes work, records what actually happened, keeps knowledge, learns, and (later) shares parts of this with others.

It is not a to-do app, a calendar app, a notes app or an AI chat app. Those are views onto a shared model of a person's commitments, time and evidence of progress.

## 2. Who it is for

- [Decision] Primary: individuals who want a complete personal system that works fully offline.
- [Decision] Secondary: small teams (initially under about 20 people) who share selected tasks, lists, calendars and documents under explicit permissions.
- [Assumption] Initial users are the author and a few acquaintances. Wide public release is possible later, so the design must not rule it out (see principle P9 below), but no scale infrastructure is built now.

## 3. Product principles

| ID | Principle | Meaning in practice |
|---|---|---|
| P1 | Task-centric, not everything is a Task | Tasks are a core concept. Events, Documents, Goals, Habits, Vocabulary and Health measurements are separate concepts linked by references, not forced into the Task shape. |
| P2 | Local-first, cloud-enabled | The device holds a usable copy of the user's data and all MVP features work offline. Cloud adds sync, sharing and backup. Local-first does not mean data exists only on the device. |
| P3 | Personal and Shared are separate | A personal resource never becomes shared because the user joined a shared workspace. Sharing is an explicit act. |
| P4 | Deterministic core, AI-assisted experience | Scheduling, recurrence, completion, permissions and sync are deterministic and testable without AI. AI proposes; it does not own authority. |
| P5 | User remains in control | Destructive or schedule-changing actions need user approval unless the user set a policy allowing otherwise. |
| P6 | Privacy by design | Data is classified. Sensitive categories (health, private AI chats, private documents) are not synced, shared or sent to cloud AI implicitly. |
| P7 | Responsive and cross-platform | Windows and Android first; layout adapts to window size, not device type. |
| P8 | Modules talk through contracts | No module reads another module's tables. |
| P9 | Scale is a seam, not a feature | Tenant isolation, idempotent operations and module boundaries are designed in from day one so a later public release scales by infrastructure, not by rewriting the domain. |
| P10 | Right-sized | Modular monolith first. No microservices, CRDT, or provider adapters without a use case. |

## 4. What success looks like

[Proposal] Measured on the author's daily use first.

1. A user can plan a day, execute it with focus sessions, and see planned versus actual, entirely offline, on Windows and Android.
2. No data is lost or silently overwritten across app crashes, restarts and (once sync exists) multi-device edits.
3. A coding agent can implement each phase from the docs without inventing architecture.
4. Adding a later capability (documents, dictionary, health, AI) does not require changing Task or Scheduling internals, only adding contracts.

## 5. Differentiators (hypotheses to validate)

- [Assumption] Distinguishing target, measurement, execution record, evidence and completion state lets habits and goals stay accurate when data arrives late or from automatic sources.
- [Assumption] A governed AI (proposal, approval bound to a resource version, audit) is more trustworthy than a free-acting assistant.
- [Open] Whether users value the integrated language-learning and document capabilities enough to justify their cost. This is why they are deferred and validated with spikes first.

## 6. Non-goals (vision level)

- Replacing specialized tools (full office suites, medical-grade health tracking, enterprise project portfolios).
- Building a fitness-tracking algorithm; health data is read from platform providers only.
- Real-time collaborative editing as a launch feature.
