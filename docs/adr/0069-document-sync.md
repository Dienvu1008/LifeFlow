# ADR-0069: Documents in sync, both sides of a conflict kept

- Status: Accepted (P05a task T4, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05-plan.md](../roadmap/p05-plan.md) (§5 "Conflict", GS-08) and ADR-0017 (revisions, no CRDT)
- Related: [ADR-0015](0015-per-type-conflict-resolution.md), [ADR-0056](0056-sync-engine.md), [ADR-0058](0058-sync-ui-and-scheduler.md), [ADR-0066](0066-document-record-model.md), [ADR-0068](0068-document-commands.md)

## Context
T2 put documents among the record kinds and T3 gave them commands, but the engine still merged a document field by field with no review, so two offline edits of one body kept only the newer (a DOC-005 breach, held back only because nothing could create a document yet). p05-plan.md proposed writing the losing body as a "conflict" revision during the merge.

## Decision
1. **Nothing extra is written by the merge, because nothing can be lost.** Every save is a revision (ADR-0068), and revisions are records of their own that sync. When two devices change one body offline, each side's body is already a revision, and both revisions reach every device. So the merge only chooses what the document shows, and both texts stay in its history (DOC-005, GS-08). This replaces the plan's "conflict revision written by the merge": it would duplicate a revision that exists.
2. **The document's merge rule** (`domain/sync_merge.dart`): field by field, as tasks; the body is one value with a review (as a task's notes): when both sides changed it, the newer stays and the other becomes a "Changes to review" item. A title changed on one side and the body on the other are both kept, with nothing to review; that combined state is not a revision of its own (each side's save is).
3. **Revisions merge append-only** (as measurements): the same id on both sides is the same fact, kept whole from one side. A revision that differs on two sides can only be damaged or forged; it is never a mix of the two.
4. **"Take the other" on a document** (`SyncReviewHandler`) puts the other body back as a new value and writes a revision with the reason `conflict`, so every change of a body has its revision (DOC-006). The other body must be one this app reads; otherwise the item cannot be taken (the document stays as it is). The review shows both sides as their text, not as the stored form.
5. **What a pull can leave, and how it is shown** (`DriftDocumentQueries`):
   - A body this app cannot read (damaged, or written by a member's altered app; a newer app's record stops the pull with "update needed" before it is stored) is shown as unreadable, never edited over: a save or rename is refused, and restoring a readable revision is the way back.
   - Two moves on two devices can merge into a loop (A under B here, B under A there). DOC-001 holds for every command, but a merge of two valid moves can still close a loop. The tree shows each loop from its smallest id, the same on every device, so nothing disappears; the next move of either document breaks it. P04a's task hierarchy has the same gap and is not changed here.
6. **The engine is unchanged.** Documents, revisions and links are sealed and pulled as any kind; a shared space's sync takes them once they are among its kinds (T5).

## Consequences
- A conflict leaves one review item and two ordinary revisions; the history shows both saves in order, each with its device.
- The rule needs every save to be a revision; ADR-0068's handler is the only local writer of document bodies besides "Take the other" and a revision restore, and each of the three writes one.
- A loop is shown, not repaired automatically: repairing it would write a change that no person made.

## Verification
- `domain/test/sync_merge_test.dart`: a body changed on both (newer kept, the other a review item); a title and a body on two sides (both kept, no review); a revision the same on both; a revision changed on both sides kept whole, never mixed.
- `infrastructure/test/sync_engine_test.dart` (two devices, the in-memory server): GS-08 (both saves are revisions on both devices, one review item on the device that merged, shown as text; "Take the other" reaches the other device with a `conflict` revision; the revisions are identical on both devices); a title and a body on two devices; two moves that merge into a loop (both documents shown, the same order on both devices).
- `infrastructure/test/sync_supabase_e2e_test.dart`: GS-08 on local Supabase with the real HTTP gateway, a real-size body, "Take the other" reaching the other device (56 Supabase tests in all).
- `infrastructure/test/document_commands_test.dart`: an unreadable body shown as such, a save and a rename refused, a readable revision restored; "Take the other" with an unreadable body refused.
- Mutations: 12 run one at a time; 12 killed, two of them after new tests (a revision changed on two sides kept whole; "Take the other" with an unreadable body).
