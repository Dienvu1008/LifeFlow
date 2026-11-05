# Domain Documents

- Status: Draft (Batch 2)
- Date: 2026-11-04
- Related: [../architecture/domain-model.md](../architecture/domain-model.md), [../architecture/bounded-contexts.md](../architecture/bounded-contexts.md)

Each MVP context has one document following the template below. Deferred contexts share one stub file ([deferred-contexts.md](deferred-contexts.md)). Detail stops at contract level: interfaces, invariants and event names, not SQL or Dart code.

## Template

1. **Purpose and classification** (Core/Supporting, phase, in MVP?).
2. **Aggregate roots and boundaries** — what is consistent within one transaction.
3. **Entities and value objects** — with the `foundation` / Time Kernel types they use.
4. **Invariants enforced inside the aggregate** — canonical `LF-INV-*` IDs and the enforcement point.
5. **Domain services** — stateless logic that spans entities but not persistence.
6. **Commands** — name, actor, args, preconditions, result, events emitted, idempotency note, concurrency note (`expectedVersion`).
7. **Queries / read ports** — published language types other contexts may consume.
8. **Domain events** — emitted facts (names from the catalog in domain-model.md section 5).
9. **Repository contract** — interface-level methods, no SQL.
10. **Open questions**.
11. **Self-check**.

## Documents

| Doc | Context | Phase |
|---|---|---|
| [workspace-and-access.md](workspace-and-access.md) | Workspace and Access | MVP |
| [task-management.md](task-management.md) | Task Management (Core) | MVP |
| [planning-scheduling.md](planning-scheduling.md) | Planning and Scheduling / Time Kernel (Core) | MVP |
| [calendar-events.md](calendar-events.md) | Calendar and Events (Core) | MVP |
| [execution-measurement.md](execution-measurement.md) | Execution and Measurement (Core) | MVP |
| [goals-projects.md](goals-projects.md) | Goals and Projects (Supporting) | P03 |
| [deferred-contexts.md](deferred-contexts.md) | all deferred contexts | P05+ |

## Conventions

- Commands are imperative (`CreateTask`); events are past tense (`TaskCreated`).
- A command mutates exactly one aggregate instance by default (see [../governance/governance-kernel.md](../governance/governance-kernel.md)).
- Cross-context access is by published contract only (DR-2 in bounded-contexts.md).
