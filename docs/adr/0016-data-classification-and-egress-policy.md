# ADR-0016: Data classification and egress policy (default deny)

- Status: Accepted
- Date: 2026-11-04
- Deciders: Architecture team; requested by the owner for Batch 3a
- Evidence: [../data/data-classification.md](../data/data-classification.md); brief sections 8.4 and 3.8; [../governance/authorization-model.md](../governance/authorization-model.md)

## Context
Several later designs (AI context building in 3c, sync and sharing in P04, health in P08) must know what data may leave a boundary. Without one authoritative scheme, each would invent its own rule and they would drift apart, risking a privacy leak (for example health data reaching a cloud model). The owner asked for a dedicated decision record with an egress matrix and a default-deny principle, parallel to the per-type conflict ADR.

## Options
1. No formal classification; each feature decides ad hoc.
2. A four-class scheme (Public, Personal, Confidential, Restricted) with a default-deny egress matrix enforced at every egress point.
3. A binary public/private flag.

## Decision
Option 2. Four classes and the egress matrix in data-classification.md. Principle: **default deny** — an egress (cloud sync, AI context, cloud AI, sharing, analytics) is denied unless the matrix explicitly allows it for that class, and sensitive actions need explicit per-request consent. Health and secrets are Restricted; AI chat and private documents are Confidential; ordinary content is Personal; shippable reference data is Public.

## Consequences
- Pro: one scheme that AI, sync, sharing and health all consume; prevents divergent, leaky rules.
- Pro: a reviewer can audit egress by reading one matrix.
- Con: every egress point must call the classifier; a missed call is a leak. Mitigated by making the Context Builder and the sync/share paths the only egress points and covering them with tests (Batch 4) and, where applicable, server-side RLS as defense in depth.
- Con: default-deny can block a legitimate feature until its cell is explicitly allowed; this is the intended safe failure mode.

## Follow-ups
- 3c AI architecture: the Context Builder enforces the matrix before building context and before any cloud call.
- Batch 4: fitness functions / tests that no egress path includes a denied class (for example "Restricted never appears in a cloud-AI request", "a personal resource is never shared without an explicit action").
- P04/P08: confirm OQ-CLASS-1 (Confidential sync default) and revocation handling for Restricted.
