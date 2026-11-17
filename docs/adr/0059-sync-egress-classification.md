# ADR-0059: The sync egress checks the data classification

- Status: Accepted (P04 task T7, 2026-11-16)
- Date: 2026-11-16
- Deciders: Implementation, within the owner's decisions D4 and D12 of [p04-plan.md](../roadmap/p04-plan.md) and [data-classification.md](../data/data-classification.md)
- Related: [ADR-0052](0052-sync-backend-and-end-to-end-encryption.md), [ADR-0056](0056-sync-engine.md), LF-INV-PRIV-001/003, FF-ARCH-08

## Context
The P04a exit gate asks for FF-ARCH-08 to be prepared: the sync egress must check the classification (p04-plan §1, §4; data-classification §4: "the sync engine checks the matrix"). Up to T6 the push sealed every record a pending outbox row named. Every kind of today is allowed to sync (D4), so nothing visible changes. The check is needed so that health data (P08), or a kind added later without a class, cannot leave the device by accident.

## Decision
1. **The rule is pure, in `domain`.** `DataClassification` has the four classes of data-classification §1 (Public, Personal, Confidential, Restricted). `cloudSyncAllowed(class)` follows the egress matrix (§2):
   - Public, Personal and Confidential may sync. Sync is end-to-end encrypted (D12), and D4 includes every current kind, notes too. This answers **OQ-CLASS-1** for P04: Confidential syncs, encrypted.
   - Restricted is refused unless the user consented for its category. No such consent exists before P08.
2. **Each record kind has a class** (`kindClasses` beside the record registry):
   - A task is Confidential, because it carries its notes.
   - Every other kind is Personal.
   - A measurement from any source other than typed in, counted by a focus session, or restored from a LifeFlow file is Restricted. That is a health source (§3: health and activity data is Restricted regardless of source; D4: health data never syncs by default).
   - **An unknown kind is Restricted** (fail closed, PRIV-001). A guard test fails when a kind is missing from the classes.
3. **One enforcement point, before sealing.** The push step classifies each record it is about to send. A refused record is never sealed and never sent. Its outbox rows are marked `local`, so nothing waits for it, and the report counts it as `withheld`. Joining, turning sync on and every other way of queueing records all pass through this step.

## Consequences
- FF-ARCH-08 proper (GS-16, the AI context builder) is still P06. It will use the same classes and rule.
- Adding a record kind now needs its class, or it never syncs.
- Tests:
  - `domain/test/data_classification_test.dart`: the matrix and the personal measurement sources.
  - `sync_review_test.dart` group "egress": every kind is classified and an unknown one is Restricted; a measurement from a health source is never sealed or sent and is marked local, while a typed one reaches the other device.
  - Mutations 5 of 5 killed.
