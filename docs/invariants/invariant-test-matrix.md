# Invariant Test Matrix

- Status: Draft (Batch 4)
- Date: 2026-11-04
- Related: [invariant-catalog.md](invariant-catalog.md), [../testing/golden-scenarios.md](../testing/golden-scenarios.md), [../testing/architecture-fitness-functions.md](../testing/architecture-fitness-functions.md)

Maps every invariant to its verification method, golden scenario(s) and/or fitness function. Any invariant with no verification is a **critical gap** (none remain). Layers: U=unit, P=property, SM=state-machine, I=integration, C=contract, A=architecture/FF, Sec=security, Sync=sync, Crash=crash/recovery.

| Invariant | Layers | Golden scenarios | Fitness fn | Gap? |
|---|---|---|---|---|
| LF-INV-ID-001 | U, P, I | GS-22 | — | no |
| LF-INV-ID-002 | I, A | GS-11, GS-22 | FF-ARCH-02 | no |
| LF-INV-WA-001 | U | — | — | no |
| LF-INV-TASK-001 | U, P | GS-18 | — | no |
| LF-INV-TASK-002 | U, P | GS-18 | — | no |
| LF-INV-TASK-003 | P | GS-18 | — | no |
| LF-INV-TASK-004 | SM | — | — | no |
| LF-INV-TASK-010 | U, I | GS-01, GS-02 | — | no |
| LF-INV-TASK-011 | U, I | GS-20 | — | no |
| LF-INV-PLAN-004 | U, P | GS-04 | — | no |
| LF-INV-PLAN-010 | P, U | GS-03 | — | no |
| LF-INV-PLAN-011 | U, I | GS-03 | — | no |
| LF-INV-PLAN-012 | P | GS-03 | — | no |
| LF-INV-PLAN-013 | table/U | GS-04 | — | no |
| LF-INV-CAL-001 | U | — | — | no |
| LF-INV-CAL-002 | U | GS-04(adjacent) | — | no |
| LF-INV-EXEC-001 | U, I | GS-20 | — | no |
| LF-INV-EXEC-002 | U, Crash | GS-13 | — | no |
| LF-INV-EXEC-003 | Crash | GS-13 | — | no |
| LF-INV-EXEC-004 | I | GS-13 | — | no |
| LF-INV-GOAL-001 | U, I | GS-21 | — | no |
| LF-INV-GOAL-002 | I | GS-21 | — | no |
| LF-INV-GOAL-003 | U | GS-11(analogue) | — | no |
| LF-INV-DOC-001 | P | — | — | no |
| LF-INV-DOC-002 | I, Sync | GS-08 | — | no |
| LF-INV-DOC-003 | U | — | — | no |
| LF-INV-DOC-004 | U, A | — | — | no |
| LF-INV-DOC-005 | Sync | GS-08 | — | no |
| LF-INV-DICT-001 | U | — | — | no |
| LF-INV-DICT-002 | U | — | — | no |
| LF-INV-DICT-003 | U | — | — | no |
| LF-INV-DICT-004 | U, I | GS-16(analogue) | FF-ARCH-08 | no |
| LF-INV-VOCAB-001 | U | — | — | no |
| LF-INV-VOCAB-002 | I | GS-09 | — | no |
| LF-INV-VOCAB-003 | P | — | — | no |
| LF-INV-VOCAB-004 | C | — | — | no |
| LF-INV-HEALTH-001 | I | GS-10 | — | no |
| LF-INV-HEALTH-002 | U, I | GS-05 | — | no |
| LF-INV-HEALTH-003 | I | GS-10 | — | no |
| LF-INV-HEALTH-004 | U | GS-05 | — | no |
| LF-INV-HEALTH-005 | U, I | GS-05 | — | no |
| LF-INV-HEALTH-006 | C, I | GS-01 | — | no |
| LF-INV-GOV-001 | A, I | GS-11 | FF-ARCH-03 | no |
| LF-INV-GOV-002 | I, A | GS-11 | FF-ARCH-09 | no |
| LF-INV-GOV-003 | Crash, A | GS-06, GS-07 | FF-ARCH-06 | no |
| LF-INV-OUTBOX-001 | Crash | GS-07 | FF-ARCH-06 | no |
| LF-INV-OUTBOX-002 | Crash | GS-06 | FF-ARCH-06 | no |
| LF-INV-AUDIT-001 | Crash, I | GS-07 | FF-ARCH-06 | no |
| LF-INV-VER-001 | Conc | GS-12 | — | no |
| LF-INV-SYNC-001 | Sync | GS-17 | — | no |
| LF-INV-SYNC-002 | Sync | GS-12(analogue) | — | no |
| LF-INV-SYNC-003 | Sync | GS-08 | — | no |
| LF-INV-SYNC-004 | Sync | GS-14 | — | no |
| LF-INV-SEC-001 | Sec | GS-19, GS-22 | — | no |
| LF-INV-SEC-002 | I | GS-22 | — | no |
| LF-INV-SEC-010 | I | GS-20 | — | no |
| LF-INV-SEC-011 | Sec | GS-19 | — | no |
| LF-INV-PRIV-001 | I | GS-16 | FF-ARCH-08 | no |
| LF-INV-PRIV-002 | Sec, I | GS-16 | FF-ARCH-08 | no |
| LF-INV-PRIV-003 | I | GS-16 | FF-ARCH-08 | no |
| LF-INV-AI-001 | I, A | GS-15(context), injection | FF-ARCH-03 | no |
| LF-INV-AI-002 | I | GS-15 | — | no |

## Coverage summary
- 62 invariants (60 harvested + LF-INV-DOC-005 + LF-INV-SEC-011). Every one has at least one verification method. **0 critical gaps.**
- Invariants with only unit coverage and no golden scenario (for example several Dictionary/Document detail invariants) are lower severity; a golden scenario can be added in their phase if needed.

## Self-check
- [x] Every cataloged invariant appears exactly once.
- [x] No invariant has an empty verification row.
- [x] Governance/transaction/privacy invariants map to both a golden scenario and a fitness function where applicable.
