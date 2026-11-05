# LifeFlow — Design Phase Final Report

- Status: Design phase complete (Batches 1–5). Stakeholder entry point.
- Date: 2026-11-04
- Full corpus index: [README.md](README.md)

Label legend in [README.md](README.md). This report summarizes the design and answers the brief's final questions. It cites the authoritative docs rather than restating them.

## 1. Executive summary
LifeFlow is designed as a local-first, modular-monolith Personal & Collaborative Life OS on Flutter (Windows + Android first). The design is complete across product scope, domain model, governance, data/sync/security, specialized domains, AI/UI/stack, a verifiable invariant set, and an executable roadmap. The MVP is deliberately narrow (personal, offline, P01–P03) with a governance spine (atomic commands, audit, outbox) that lets later capabilities (sync, documents, AI, dictionary, health, learning) attach through contracts without redesigning the core. Twenty ADRs record the decisions with trade-offs. The build target is one developer plus one coding agent — a single delivery lane — and the roadmap and estimates reflect that.

## 2. Repository assessment recap
`my_time_manager` is a working app but not a suitable base (singleton `DatabaseManager`, JSON-in-TEXT, no workspace/version/sync identity, two recurrence systems, mixed state management). It is a **source of selective ports**, not a foundation (ADR-0002). Details: [assessment/legacy-repo-assessment.md](assessment/legacy-repo-assessment.md), [assessment/legacy-component-matrix.md](assessment/legacy-component-matrix.md).

## 3. Product scope & MVP
MVP = Task + Subtask, Schedule/Recurrence, Calendar/Event, Focus (crash-recoverable), measurable Habit, Goals/Projects, guest-first optional sign-in, on Windows + Android, fully offline. Everything else is deferred with extension points. [product/product-scope.md](product/product-scope.md), ADR-0005/0006/0007/0008.

## 4. Bounded context map & domain
Five MVP contexts (Workspace & Access, Task Management, Time Kernel, Calendar & Events, Execution & Measurement) plus Goals & Projects (P03); deferred contexts stubbed. [architecture/bounded-contexts.md](architecture/bounded-contexts.md), [context-map.md](architecture/context-map.md), [domain-model.md](architecture/domain-model.md), [domains/](domains/).

## 5. Governance
One command gateway is the only mutation path; authorization before the domain; the aggregate change + audit + outbox + event log + dedupe commit in one transaction (ADR-0011/0014); AI approvals are version-bound (ADR-0012). [governance/](governance/).

## 6. Critical invariants
62 invariants in a single catalog with severity and verification; every one has a verification method and 0 coverage gaps. The highest-value ones are the transactional-atomicity and concurrency set (LF-INV-GOV-003, OUTBOX-001/002, AUDIT-001, VER-001) and the privacy egress set (PRIV-001/002/003). [invariants/invariant-catalog.md](invariants/invariant-catalog.md), [invariant-test-matrix.md](invariants/invariant-test-matrix.md).

## 7. Data & sync
Local-first Drift store, whole-file encryption (SQLite3MultipleCiphers, MIT), explicit source-of-truth map, outbox-based sync with per-type conflict resolution (no global LWW), four-class default-deny egress policy. [data/](data/), ADR-0009/0015/0016.

## 8. Health
Android Health Connect only for P08; evidence-only via `RecordMeasurement`; Restricted class; missing≠zero; revocation handled. HealthKit is a future extension point, not designed. [domains/health-integration.md](domains/health-integration.md).

## 9. Dictionary & language learning
Dictionary and Translation are separate models behind provider ports + ACL; no source chosen (spike S-10); Vocabulary owns learning data with deterministic spaced repetition and creates review Tasks via the Task contract. [domains/dictionary-translation.md](domains/dictionary-translation.md), [vocabulary-learning.md](domains/vocabulary-learning.md).

## 10. Documents
Block + revision model; single-user + revision-based collaboration (CRDT deferred, ADR-0017); editor is MIT/BSD (AppFlowy excluded by license), final pick via spike S-07. [domains/document-knowledge.md](domains/document-knowledge.md).

## 11. AI
Interface-level contract: context builder scoped by permission + workspace + classification; provider routing with hard privacy rules; execution via the gateway with version-bound approval. No cloud adapter chosen. [architecture/ai-architecture.md](architecture/ai-architecture.md).

## 12. Technical stack decisions
Flutter/Dart, Drift + NativeDatabase (MIT), SQLite3MultipleCiphers (MIT), Riverpod (MIT) + go_router (BSD), flutter_secure_storage (BSD), uuid/timezone. AGPL excluded (ADR-0018). Viewers/TTS/AI providers are candidate+spike or port-only. [architecture/technical-stack.md](architecture/technical-stack.md).

## 13. Master roadmap & critical path
P00 → spikes (S-01/02/03a) → P01 → P02 → P03 (MVP) → P04 → {P05, P06} → {P07, P08} → P09 → P10. The MVP is the whole critical path in a single lane; P04 is the next critical node. [roadmap/master-roadmap.md](roadmap/master-roadmap.md), [dependency-map.md](roadmap/dependency-map.md).

## 14. Spikes
13 spikes, each time-boxed with success/failure criteria and an escalate-as-Open rule; MVP-blocking: S-01, S-02 (FTS/encryption), S-03a (auth). [spikes/spike-plan.md](spikes/spike-plan.md).

## 15. Effort & resources
Ranges with assumptions + confidence for dev + agent; MVP critical path ≈ 55–110 pd pre-buffer (~70–150 with buffer). Cloud-AI cost, legal review and external waiting are out of estimation scope. [roadmap/effort-estimation.md](roadmap/effort-estimation.md).

## 16. Major risks
Scope explosion, offline-sync complexity, data loss, permission errors, AI hallucination/leak, dictionary licensing, Flutter plugin maturity, FTS-under-encryption. Each has mitigation + contingency + validation. [roadmap/risk-register.md](roadmap/risk-register.md).

## 17. Unresolved decisions
Backend (ADR-0003, via S-03a/S-03/S-04); editor final pick (S-07); dictionary sources (S-10); FTS5-under-encryption (S-02/OQ-V10); sign-out behavior (OQ-S7); encryption key derivation (OQ-DATA-1); legal/export-crypto (OQ-SEC-1). Full list in [README.md](README.md).

## 18. Answers to the brief's final questions

1. **What of my_time_manager can be reused?** The pure-Dart logic with tests: `wall_clock_resolver` (DST), `RepeatRule` day-matching, progress calculators, the AI core/policy/tool layering and its prompt-injection test pattern. Everything stateful (DB, auth, state management, navigation, focus timer) is rewritten. [assessment/legacy-component-matrix.md](assessment/legacy-component-matrix.md).
2. **Which domain to start from?** Task Management on the Workspace + governance spine (P01). Task is the hub; the gateway/outbox/audit must exist from the first mutation.
3. **What must be in the MVP?** Task/Subtask, Schedule/Recurrence, Calendar/Event, Focus with recovery, measurable Habit, Goals/Projects, guest-first sign-in, offline, Windows+Android.
4. **What should be deferred?** Sync, documents, AI, dictionary/vocabulary, health, learning, iOS/CRDT — each attaches via an existing contract.
5. **Minimal governance kernel?** Command gateway (authorize → validate → in-tx version check → atomic set: aggregate+audit+outbox+event+dedupe → commit → dispatch after commit). That is the smallest thing that guarantees no unauthorized mutation, no lost event/outbox/audit, and safe retries/sync. [governance/governance-kernel.md](governance/governance-kernel.md).
6. **How do AI/Health/Dictionary/Learning avoid bloating the core?** They are separate contexts that reach the core only through published contracts: AI proposes and executes via the gateway; Health only calls `RecordMeasurement`; Learning/Vocabulary only call `CreateTask`; Documents link via `LinkedResource`. None writes another context's storage (DR-2, FF-ARCH-02/03).
7. **How to support offline + multi-device without data loss?** Local-first with stable UUIDs, per-entity versions, tombstones, an atomic transactional outbox (ADR-0014), and per-type conflict resolution (ADR-0015) — no global LWW. Verified by GS-06/07/08/12/14/17.
8. **Which technical risks could force a redesign?** Offline-sync reconciliation (S-04), Supabase RLS fit (S-03), FTS5-under-encryption (S-02), and auth/Windows flow (S-03a). These are front-loaded as spikes with escalate-as-Open time-boxes.
9. **Realistic roadmap for one dev + one agent?** The strictly sequential P01→P02→P03 MVP (~55–110 pd pre-buffer), then P04 as the gateway to the rest; one lane, human review gates pace it. [roadmap/master-roadmap.md](roadmap/master-roadmap.md).
10. **Preconditions before starting P01?** See section 19.

## 19. Preconditions to start P01 (implementation)
1. Owner confirms the design corpus (this report + README) and the key ADRs (0002, 0005–0008, 0009–0020).
2. MVP-blocking spikes pass or are escalated: **S-01** (Flutter+Drift on both platforms), **S-02** (migrations + FTS5-under-encryption, OQ-V10), **S-03a** (auth provider + Windows flow + offline session).
3. Backend auth provider chosen from S-03a (ADR-0003 moves from Proposed toward Accepted for the auth half).
4. Answer the few P01-relevant open questions or accept their proposals: OQ-S7 (sign-out), OQ-DATA-1 (key derivation). Others are later-phase.
5. Repository scaffolded per [architecture/repository-structure.md](architecture/repository-structure.md) with the fitness-function skeleton (FF-ARCH-01..09) and CI stage order.

## 20. Documents produced
66 markdown documents across product, assessment, architecture, domains, governance, data, security, invariants, testing, roadmap, spikes, research, ADRs, plus this report and the README index. The design phase is complete.
