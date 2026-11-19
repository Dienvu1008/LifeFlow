# ADR-0066: Documents as records with a block body of our own

- Status: Accepted (P05a task T1, 2026-11-04); amended by [ADR-0071](0071-document-links-and-search.md) (a link's current title is written back by the document service at a save, not by the editor adapter)
- Date: 2026-11-04
- Deciders: implementation within the owner's decisions C1–C12 of [p05-plan.md](../roadmap/p05-plan.md) and the S-07 pick (ADR-0020 amendment: flutter_quill)
- Related: [document-knowledge.md](../domains/document-knowledge.md) (amends §4), [ADR-0015](0015-per-type-conflict-resolution.md), [ADR-0017](0017-document-collaboration-maturity.md), [ADR-0020](0020-editor-decision-or-spike.md), [ADR-0059](0059-sync-egress-classification.md)

## Context
P05a needs a document model before the store (T2), the commands (T3) and sync (T4). Three things push on its shape: the editor is a library behind an adapter (ADR-0020), a revision holds the whole document at every save (C5, C7), and sync keeps both sides of a conflict (ADR-0017, DOC-005). document-knowledge.md §4 proposed blocks as rows of their own.

## Decision
1. **A document is one record; its body is one value.** The record holds the id, workspace, parent, title, order key and the body, plus the usual version, timestamps, tombstone and "changed by". This amends document-knowledge.md §4 (blocks as rows): block rows would invite a block-by-block merge, which is what a CRDT is for and ADR-0017 leaves out. As one value, a body changed on both sides is kept twice (T4), and a revision is a plain copy.
2. **The body is LifeFlow's own block format** (`DocumentBody` in `domain/documents.dart`), never the editor's (Quill's Delta):
   - blocks: paragraph, heading 1–3, bullet, numbered, to-do (with its tick), quote, code, attachment; list items and to-dos have an indent 0–5;
   - runs of text with marks (bold, italic, underline, strike, code) and at most one link each: a `[[…]]` link to a document (its id) or a web address (http, https, mailto only);
   - an attachment block names its file by `sha256:` hash, name, size and type (C3: the file stays on the device).
3. **Deterministic serialization.** One JSON text `{"v":1,"blocks":[…]}` with a fixed key order, marks in a fixed order, adjacent runs of the same style merged and empty runs dropped. The same content always gives the same bytes (a property test over random bodies), so an unchanged document is never a "change" to sync or a revision. A body names its format version; an older app refuses a newer body rather than read half of it.
4. **Limits**, checked by `validate()`: at least one block, at most 10 000 blocks and 300 000 characters (about 100 pages), unique block ids of 1–64 characters, a title of 1–200 characters.
5. **Block ids are not a promise.** Quill has none; the adapter (T8) keeps them by line position since the last load, so a line inserted above shifts the ids below. P05a has no links to a block, so nothing depends on them; they exist so that a later editor or feature can keep them.
6. **Relations stay distinct (DOC-004).** The parent is a field of the record; `[[…]]` links, web links and files live in the body; links to tasks, events and goals are `documentLink` records (T3, as `goalLink`). `relationsOf` reads each kind apart.
7. **Rules as pure functions:** no cycle in the tree (`DocumentTreeRules.moveError`, DOC-001, property-tested over random moves); a link resolves or shows as in the trash or missing, and is never dropped (`resolveLink`, DOC-003); backlinks show the sentence around each link, cut to 200 characters around it (`backlinkSnippets`, C6).
8. **Search by the exact spelling (C4).** `plainText()` gives the text to index (a file by its name); `searchQueryOf` turns what a person typed into an FTS5 query: every word must be there, the last may be the start of a word unless the input ends with a space, double quotes make a phrase, and every word is quoted so FTS5's own syntax (`OR`, `NEAR`, `*`) cannot be typed in. NFC normalization of both sides is the store's (T2, `unorm_dart`), so `domain` keeps its two dependencies.

## Consequences
- The stored documents outlive the editor: replacing flutter_quill touches only the adapter.
- A large document rewritten at every save is a large revision (C9 keeps all of them); the size shown in Settings (T8) and a later thinning rule are the answer if it grows. The export's 64 MB cap (SR-14) becomes a limit to watch in T9.
- A `[[…]]` link stores the text it showed when it was made; the UI shows the target's current title and the adapter writes it back at the next save (T6, T8), so search finds the current title.
- Revisions (`RevisionReason`: save, conflict, restore) are records of their own, written once (T2, T3); `documentIdleSave` is C7's 10 seconds.

## Verification
- `domain/test/documents_test.dart` (18 tests): the format (exact round trip, fixed bytes, merged runs, a property over 200 random bodies, eleven malformed bodies refused, the indexed text), the rules (limits and shapes, titles, DOC-001 with a property over random moves, DOC-003, DOC-004), backlinks (sentences, one entry per sentence, a long sentence cut) and the search query (prefix, phrase, FTS syntax quoted).
- Mutations: 20 run one at a time; 19 killed, two of them after new tests (an empty run of another style; two links in one sentence). The twentieth, the escaping of `"` inside a quoted word, could not be reached (quotes are removed first), so the code was removed.
