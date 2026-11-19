# ADR-0068: Document commands

- Status: Accepted (P05a task T3, 2026-11-04)
- Date: 2026-11-04
- Deciders: the owner's C5 (a revision at every save), C7 (what a save is) and C9 (all revisions kept); implementation within [p05-plan.md](../roadmap/p05-plan.md)
- Related: [ADR-0066](0066-document-record-model.md), [ADR-0067](0067-document-store-and-exact-search.md), [ADR-0040](0040-goals-and-projects.md) (the same shape for links), [ADR-0046](0046-lists-colours-and-order-keys.md) (order keys, a list's trash)

## Context
T3 gives documents their commands: what the UI (T8) and sync (T4) will call. Each must keep the atomic set (FF-ARCH-06), be authorized before the domain (FF-ARCH-09), and keep DOC-001…004 and the owner's C5, C7 and C9.

## Decision
1. **One handler, the document as the aggregate** (`DocumentCommandHandler`, entity `document`). Its revisions and links are written in the same gateway transaction, each with its own outbox row, and the document's version moves with every operation:
   - `create`: a document with one empty paragraph, at the end of its siblings (or after a given one), and its first revision.
   - `save`: a new title and body and **exactly one revision** holding both, whole (C5). The body is read and written again in its fixed form (ADR-0066), so a body sent loosely (runs not merged, marks in another order) is stored as the same bytes as its tidy form. A save of what is stored is refused, so no empty revision is ever written; the service answers such a save as a success without a command (C7: leaving or idling on an unchanged document).
   - `restoreRevision`: an earlier revision of the same document becomes the document again, as a new revision with the reason "restore". The old revision is untouched.
   - `move`: under a live document of the same workspace or at the top, at a position among the siblings; never under itself or one of its subdocuments (DOC-001, the domain's rule over the stored ancestors).
   - `trash` / `restore`: a document goes to the trash with its live subdocuments at one time, and a restore brings back exactly those that went with it, as a list does with its tasks (ORDER-004). A subdocument trashed on its own before stays there. A restore whose parent is not live puts the document at the top.
   - `link` / `unlink`: to a live task, event or goal of the same workspace (DOC-004, as GOAL-003), id `<document>|<type>:<id>`; a link never changes the item.
2. **A rename is a save** (`DocumentService.rename`): the title is part of every revision, so changing it writes one, with the current body.
3. **Revisions are written once** (DOC-002; proposed DOC-006): the handler only inserts them; a revision id is refused if it exists; no command updates or deletes one. Moves, links and the trash write none.
4. **Who and where.** A revision names the device (`deviceId`, given by the app) and, in a shared space, its author through "changed by" (stamped by the gateway, ADR-0060). The service acts in the shown workspace, as every service since P04b: a member's command in a shared space, the owner's in the personal one; a viewer is refused by the role policy before the handler.
5. **The port** (`application/documents.dart`): `DocumentService` (commands; failures returned, never thrown) and `DocumentQueries` (the tree in order, a document, its history newest first, a revision's content, its links, the trash). The body's value types are the domain's, re-exported by `application`: they are the port's published language, so the UI uses them without importing `domain` (FF-ARCH-04 holds).
6. **Files are checked like commands.** An export or an undo copy is read with the document rules too (`documentRowsError`): titles and bodies valid, revisions readable with a known reason, a link keyed by its document and item and of a known type, no document under itself; a revision needs its document and a link both its ends. A file cannot put into the store what no command could write.

## Consequences
- Every save is a full copy (C9 keeps all). The autosave of C7 lives in the UI (T8); the service's "nothing changed" answer keeps an idle document from piling up revisions.
- The trash is per subtree; there is no "trash only this, keep its children".
- Sync (T4) applies pulled documents and revisions with the engine's apply command; this handler is the local path only.

## Verification
- `infrastructure/test/document_commands_test.dart` (17 tests): create with its first revision; one revision per save with title and body, none for an unchanged save, newest first, the device named; the fixed form of the body, a bad body and a stale version refused; a rename as a save; DOC-002/006 (earlier revisions unchanged by later saves, moves, the trash and a restore); restoring a revision, and refusals; DOC-001 and positions; the trash and restore of a subtree; a restore without its parent; links to tasks, events and goals, refusals, another workspace; a member's save "changed by" them and a viewer refused; commands sent to the gateway directly (an unchanged save, a reused revision id, a loose body); the tree with a parent not live; an export read back and nine kinds of bad file refused; a saved document found by search.
- `atomic_set_test.dart`: ten new steps (create, a subdocument, save, restore a revision, move, link, unlink, move under, trash, restore), with fault injection; `ff_arch_06_09.dart` finds the handler.
- Mutations: 29 run one at a time; 29 killed, five of them after new tests (an unchanged save sent directly, the fixed form of the body, a reused revision id, a link to another workspace, the tree with a parent not live).
