# ADR-0004: Domain-oriented modular monolith with explicit bounded contexts

- Status: Accepted
- Date: 2026-11-04
- Deciders: Project owner (brief), refined by architecture team
- Evidence: [../architecture/bounded-contexts.md](../architecture/bounded-contexts.md), [../architecture/context-map.md](../architecture/context-map.md), [../assessment/legacy-repo-assessment.md](../assessment/legacy-repo-assessment.md)

## Context
LifeFlow spans tasks, time, execution, documents, language learning, health, AI and collaboration. A solo developer plus a coding agent maintain it. The legacy app organizes by screen folders (`screen_*`) and a shared `DatabaseManager`; business rules once lived inside widgets (see `ARCHITECTURE_REFACTOR_REPORT.md`).

## Options
1. Layered monolith organized by technical layer only.
2. Modular monolith organized by bounded context, with layers inside each context and enforced boundaries.
3. Microservices or separate deployables.

## Decision
Option 2.
- One Flutter application, one local database, one deployable.
- Modules follow the contexts in `bounded-contexts.md`. MVP contexts: Workspace and Access (minimal), Task Management, Time Kernel, Calendar and Events, Execution and Measurement.
- Context-to-context communication uses published contracts only (query ports, commands, events). IDs are opaque.
- The Governance Kernel and platform adapters are cross-cutting foundations, not contexts.
- Boundary rules are checked automatically (fitness functions defined in a later batch).
- Cross-context dependency cycles are forbidden.

## Consequences
- Pro: smaller blast radius for the coding agent; contexts can be built in phases without touching the MVP core.
- Pro: clear route to extract a context later if needed (not planned).
- Con: more packages and boilerplate than a flat structure.
- Con: boundary rules require discipline and tooling to hold.
- The Time Kernel's packaging (separate package versus inside `foundation`) stays open (OQ-B1). Habit placement is resolved (ADR-0006: Task capability).

## Follow-ups
- Repository structure and package dependency table (architecture batch 2).
- Fitness functions for AP-02 to AP-05 (invariants batch).
