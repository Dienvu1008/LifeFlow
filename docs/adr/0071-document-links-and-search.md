# ADR-0071: `[[…]]` links, backlinks and one search

- Status: Accepted (P05a task T6, 2026-11-04)
- Date: 2026-11-04
- Deciders: implementation within [p05-plan.md](../roadmap/p05-plan.md) §4 and the owner's answers C4, C6 and C12
- Related: [ADR-0066](0066-document-record-model.md), [ADR-0067](0067-document-store-and-exact-search.md), [ADR-0068](0068-document-commands.md), [ADR-0070](0070-documents-in-shared-spaces.md)

## Context
T1 gave the pure rules (`resolveLink`, `backlinkSnippets`, `searchQueryOf`) and T2 the index (search tables, the backlink index from the bodies). Nothing above the store used them yet: the UI (T8) needs to show what a link points to, the backlinks under a document, what `[[` offers, and one search over documents and tasks. ADR-0066 left one point open: a link stores the text it showed when it was made, and "the adapter writes the current title back at the next save".

## Decision
1. **Link targets** (`DocumentQueries.linkTargets`). For a set of ids, each link shows one of:
   - its target's current title;
   - "in the trash", with the title;
   - "missing", without a title.

   A link resolves only inside the shown workspace. A document of another workspace in the same store is "missing", so a space never shows the title of a personal document, and the reverse holds too. Restoring a document from the trash repairs its links, because they are read live (DOC-003).
2. **A link's text follows a rename at the next save.**
   - `DriftDocumentService.save` sets each live link's text to its target's current title (`withLinkTitles`, domain) before deciding whether anything changed. Only targets in the document's own workspace count.
   - A broken link keeps its text (DOC-003).
   - Marks stay on the link.
   - A body that the new titles would push past the limits is saved as it was.

   The service does this, not the editor adapter, so every writer stores the same thing and search finds the title people see. Renaming a document does not rewrite the documents that link to it; each catches up at its own next save. Doing it at the rename would write revisions nobody made.
3. **Backlinks** (`backlinks`): the live documents of the shown workspace whose text links here, never the document itself. Each comes with its sentences (`backlinkSnippets`). They are sorted by title, ignoring letter case. A body this app cannot read links nothing.
4. **What `[[` offers** (`linkCandidates`): the live documents of the shown workspace whose **title** matches what was typed, by the same exact-spelling rules as search (an FTS5 column filter `title : (…)`). With nothing typed, the 20 most recently changed. Never the document being edited. "Create '…'" is the existing `create` followed by inserting the link (T8).
5. **One search** (`SearchQueries`, new port; `DriftSearchQueries`):
   - It covers the live documents (title and text) and tasks (title, C12) of the shown workspace, best first, at most 50 of each.
   - A document hit carries a passage from FTS5's `snippet()` with where the words matched. The match marks are private-use characters, taken out before the text reaches the UI.
   - Nothing typed returns nothing.
6. **Linked items show their own state** (`linksOf`, as goal links do): title and open, done, cancelled, in the trash, or missing. A task's, event's or goal's page can list its documents (`documentsOf`, live ones of the shown workspace).

## Consequences
- The same document text gives the same search results on every device, because search reads stored text, and the stored text holds the titles as of the last save.
- A link pasted from a personal document into a space keeps the text it was pasted with and shows as missing there. Its id never resolves across workspaces. The person pasted that text themselves.
- Titles are ordered by code point after lower-casing. This is not Vietnamese dictionary order: "Ă…" comes after "V…". A proper collation is left for when the UI shows long lists (T8 or later).

## Verification
- `domain/test/documents_test.dart`: link titles (current title, marks and block kept, broken text kept, unchanged body returned as is, a too-long result refused).
- `infrastructure/test/document_links_search_test.dart` (new, 7 tests):
  - Link targets: OK, in the trash, gone, and in another workspace (no title); a restore repairs.
  - A save rewrites link texts and search follows; an unchanged save after that writes no revision.
  - A space document linking a personal one stays unfilled.
  - Backlinks: order, sentences, trash, workspace, itself.
  - `[[` candidates: titles only, any case, marks typed apart, exact spelling, phrase, latest changed, never itself.
  - Search: passages and matches, tasks with done, trash, exact spelling, limit, shown workspace.
  - Linked items with titles and states, and an item's documents.
- Mutations: 18 run one at a time, all killed.
