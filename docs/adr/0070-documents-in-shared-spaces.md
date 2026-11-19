# ADR-0070: Documents in shared spaces, and the personal export after a move

- Status: Accepted (P05a task T5, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05-plan.md](../roadmap/p05-plan.md) (owner's answers C2 and C8) and P04b's move rules (p04b-plan.md B2, B3, B4, B10, B14)
- Related: [ADR-0060](0060-shared-spaces-in-one-store.md), [ADR-0064](0064-sharing-commands.md), [ADR-0066](0066-document-record-model.md), [ADR-0068](0068-document-commands.md), [ADR-0069](0069-document-sync.md)

## Context
The owner allowed documents in shared spaces in P05a (C2), and asked that a move take a document's history along, with a confirmation that says "…and N earlier versions" (C8). T4 made documents sync; a space's sync takes a kind only when it is among the space's kinds, and a move takes only the kinds P04b listed.

While adding the move, a P04b bug showed up. The personal export leaves out what is in a shared space (B14), but its reader refused a personal row that still pointed to a moved record: a goal link to a goal moved into a space, a reminder or a focus session of a moved task, a trashed subtask left behind. The file was written, but it could not be restored, and the snapshot that "undo a join" reads had the same problem. T5's document links, which stay behind as goal links do, would have hit it too.

## Decision
1. **Documents, revisions and document links are space kinds** (`sharedSpaceKinds`). A member's save in a space names them as its author (B10), and a viewer saves nothing (the gateway refuses it, as for tasks).
2. **What a document's move takes** (`moveSetOf`): the document, its live subdocuments at any depth, and every revision of each. A trashed subdocument stays where it is, with its history. Links to tasks, events and goals stay where they are, as goal links do (P04b). A link shows only in the workspace of its document (`linksOf`). A link left behind cannot be changed from the other workspace: linking or unlinking it there is refused (`DocumentCommandHandler`; the same guard is added to `GoalCommandHandler`, where P04b let such an unlink write a personal row with an outbox row of the space).
3. **The moved document leaves its parent behind** (its `parentId` becomes empty; its subdocuments keep theirs). A subdocument can be moved alone. Tasks differ (only a top-level task moves), because a document's tree is only an outline, while a subtask's position is part of its task.
4. **A revision names its author once.** A move changes a revision's place and version, never its content or its author. The gateway stamps "changed by" on what a member's command wrote (B10). For revisions it stamps only one that has no author, that is, one written in the personal workspace by the person moving it. A revision Minh wrote keeps Minh's name when Lan moves the document out and back in.
5. **The confirmation** (`previewMove`) counts revisions and does not list their titles. `counts['documentRevision']` is the "N earlier versions" of C8. A document with text counts as notes ("its contents become visible").
6. **The personal export names what it points to in a space** (fixes the P04b bug). Under `inSpaces` the payload lists, by kind, the ids that exported rows point to and that are in a shared space of the store: only ids, which the pointing rows already hold. The key is absent when there are none, so other files do not change. The reader accepts a reference to a listed id and still refuses any other missing one. A listed id that is also in the file, an unknown kind, or a malformed list is refused. The rows stay in the file, so a restore on the same device changes nothing and keeps them, and undoing a join gets them back as they were. Writing the file into a new store (`withinFile`) treats a listed id as a record that will not exist, as a restore already does (`_dropOrphans`): a row that needs it is left out (a goal link, a document link, a reminder); an optional reference, a task's list or parent, is cleared (a focus session keeps its time, a trashed subtask goes to the top).

   Rejected alternatives:
   - Dropping such rows from the export. A restore that "makes the profile the file" would then move the reminders of shared tasks to the trash on the same device.
   - Accepting any missing reference. That would stop the reader from catching damaged files.

## Consequences
- The owner's C2 and C8 hold: a document and its whole history move together, and members see who wrote each version.
- A document link left behind does not follow later moves. If the task is moved into the space as well, the old link stays personal, and the same link cannot be made again in the space. This is the same limit P04b has for goal links. Lifting it needs links that move with both ends, and is left for later.
- Older apps (format version 1, unchanged) read files without `inSpaces` as before. A file with `inSpaces` still fails in an older app, as every such file did before this fix.

## Verification
- `infrastructure/test/space_export_test.dart` (new):
  - The P04b case: a goal with a link is moved into a space; the export lists the goal; a same-device restore changes nothing; a new store has no link; without the list the file is refused as before; the left-behind link cannot be unlinked from the space.
  - A task moved, with its reminder, focus session and trashed subtask left behind.
  - A document moved, with a link and a trashed subdocument left behind.
  - Each kind of pointer on its own, and a subdocument moved alone.
  - The list's checks, including a damaged store whose dangling id is not listed.
- `infrastructure/test/sharing_test.dart` (in-memory server, three accounts):
  - The confirmation: counts, titles, notes.
  - Nothing moves if the document changed after it was shown.
  - Subdocuments and every revision move; the trashed subdocument and the link stay; the link cannot be changed from the space.
  - The members see the history with its authors; an editor's save reaches the owner; a viewer's save is refused.
  - Back out: a delete for the others, authors kept. In again: authors still kept.
  - The account's other device, whichever sync comes first.
- `infrastructure/test/space_sync_supabase_e2e_test.dart`: a document moved in with its history on local Supabase, two accounts; the member sees the authors, finds it by "ghi chú", and saves; the owner gets the revision with the member's device.
- `infrastructure/test/atomic_set_test.dart`: `space.moveIn(document)` and `space.moveOut(document)` write the whole atomic set.
- Mutations: 26 run one at a time, all killed in the end. Two survived the first run:
  - The space-ids filter of the export list: killed after a new test with a damaged store.
  - The revision-author line of the move: the gateway's stamp overwrote it. A test that moves a document in, out and in again showed authors being lost, so the rule moved into the gateway (decision 4). Both parts of the new rule were then killed.
