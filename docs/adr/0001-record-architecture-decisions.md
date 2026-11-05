# ADR-0001: Record architecture decisions

- Status: Accepted
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../architecture/architecture-principles.md](../architecture/architecture-principles.md) AP-15

## Context
LifeFlow will be built by one developer and a coding agent over many phases. Decisions with trade-offs must be discoverable so later work does not re-litigate them or contradict them silently.

## Options
1. No formal records; rely on documents and chat history.
2. ADRs in `docs/adr/` using a short fixed template.

## Decision
Option 2. Every decision with real trade-offs gets an ADR. File name: `NNNN-short-title.md`. Template fields: Status, Date, Deciders, Evidence, Context, Options, Decision, Consequences, Follow-ups.

Status values: `Proposed`, `Accepted`, `Superseded by ADR-NNNN`, `Rejected`. An accepted ADR is changed only by a new ADR that supersedes it.

## Consequences
- Small overhead per decision.
- The coding agent can read ADRs to learn constraints before changing code.
- Open questions that are not yet decisions stay in the documents they affect and become ADRs when decided.

## Follow-ups
None.
