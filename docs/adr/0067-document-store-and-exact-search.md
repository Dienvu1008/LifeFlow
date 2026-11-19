# ADR-0067: The document store (schema v16) and search by the exact spelling

- Status: Accepted (P05a task T2, 2026-11-04)
- Date: 2026-11-04
- Deciders: the owner's C4 and C12 (search by the exact spelling, for documents and tasks); implementation within [p05-plan.md](../roadmap/p05-plan.md)
- Related: [ADR-0066](0066-document-record-model.md), [ADR-0053](0053-sync-storage-contract-schema-v10.md), [ADR-0059](0059-sync-egress-classification.md), [local-storage.md](../data/local-storage.md) (answers OQ-LS-1)

## Context
T2 puts ADR-0066's documents in the store and makes search work by the exact spelling. A check on the project's SQLite (p05-plan §2) showed that FTS5's default tokenizer removed most marks (task search ignored them, inconsistently: "đ" stayed), that keeping the marks makes the comparison byte-exact, and that the same Vietnamese word reaches the store in more than one encoding: precomposed (NFC), decomposed (NFD), or half-decomposed, a vowel letter whole with its tone mark apart, as some keyboards type it ("ă" + U+0303 for "ẵ"). Only Unicode normalization of both sides makes them one.

## Decision
1. **Three record kinds**, in the write order after goal links:
   - `document` (table `documents`): parent, title, body (ADR-0066's encoded body), order key; **Confidential**.
   - `documentRevision` (`document_revisions`): the document, the version it recorded, the whole title and body, the reason (save, conflict, restore), the device; **Confidential**; it requires its document (restore and merge reference checks).
   - `documentLink` (`document_links`): a document's link to a task, an event or a goal, id `<document>|<type>:<id>` as goal links; Personal; it requires both ends.
   - A document's parent is an optional reference: a restore that does not have the parent puts the document at the top instead of refusing it.
   - `recordSchemaVersion` and `currentSchemaVersion` become 16. A device on v15 that pulls a document stops at it with "update needed", as for any newer record.
2. **Search keeps the marks.** `tasks_fts(title)` and `documents_fts(title, body)` use `unicode61 remove_diacritics 0`: case is ignored, marks are not. "ghi chú" does not find "ghi chu" and the reverse (C4, C12).
3. **NFC on both sides, kept by Dart.** The index holds each title and body text in NFC (`unorm_dart`, already licensed, VS-45), and every query is normalized the same way. SQLite has no NFC of its own, so the index is no longer kept by SQL triggers alone:
   - triggers on `tasks` and `documents` (insert; update of title or body; delete) only note the row in `search_pending`, whatever wrote it (a command, a pulled page, a restore, a move into a space, a purge);
   - before every search or backlink query, `catchUpSearch` re-indexes the noted rows in one transaction, in two passes (all removals, then all inserts), so a rowid freed by a purge and given to a new row is indexed for the new row;
   - the triggers check `NOT EXISTS` instead of `INSERT OR IGNORE`, because an outer statement's conflict clause (Drift's upserts) overrides a trigger's, which made the second note of a row fail.
   Records are never rewritten for the index: a title typed in NFD stays NFD, so sync and merges see exactly what was written.
4. **Backlinks from the bodies.** `document_link_index` (from, to) is rebuilt at catch-up from each body with the domain's own reader (`relationsOf`), so the format is parsed in one place. A body this app cannot read keeps its title searchable and links nothing until an app that reads it.
5. **Queries** (`searchTaskIds`, `searchDocumentIds`, `backlinkIds` on `AppDatabase`): live records of one workspace; the query is ADR-0066's `searchQueryOf` (every word, the last one as a prefix, phrases in quotes, FTS5 syntax quoted away); a backlink is a live document of the same workspace, never the document itself.
6. **The v16 upgrade** creates the document tables and indexes, drops the old external-content `tasks_fts` and its three triggers, creates the new tables and triggers, and notes every task for the first catch-up. `search_pending` and `document_link_index` are device bookkeeping: not exported, not synced.
7. **Sync of documents waits for T4.** The kinds are in `recordKinds`, so the engine would carry them with the field-by-field merge; nothing creates a document before T3's commands and T8's UI, and T4 adds the document rule (both bodies kept) before either ships.

## Consequences
- **Task search changes** (C12): a search without marks no longer finds a title with marks, and "đ" is no longer a special case.
- OQ-LS-1 is answered: `unicode61` with marks kept, NFC in Dart, no custom tokenizer, Vietnamese without word segmentation (a word is what spaces and punctuation separate, which suits Vietnamese syllables). CJK search would need another tokenizer; it is not in scope.
- A search does a little writing first (the catch-up); its cost is the rows changed since the last search.
- The rowid of `tasks` and `documents` is the index key, as `tasks_fts` already assumed; a `VACUUM` would need an index rebuild (`markAllForSearch`). The app does not vacuum.

## Verification
- `infrastructure/test/search_index_test.dart` (9 tests):
  - the same words typed three ways (NFC, NFD, half-decomposed) found by queries typed each way and in capitals, phrases included, while text without marks is found only without marks;
  - the prefix and the trailing space, FTS syntax as plain words, a phrase's order;
  - workspaces apart, the trash hidden;
  - a rename, a purge, and a freed rowid reused before the catch-up;
  - the record keeps its bytes (no write to the record, the outbox untouched);
  - a purged task and document leave no text in the index (GS-14);
  - documents' titles and text, a rewritten body, an unreadable body;
  - backlinks: one workspace, live documents, not itself, an unlink, the trash;
  - the v15 → v16 upgrade of a store with an NFD title.
- The upgrade loop (`profile_directory_test.dart`) now runs every version from v2 to v15 into v16, every column of every table checked; `rewindProfileStore` rebuilds the v15 shape (old `tasks_fts` and triggers).
- The export guard lists the new tables; the classification guard covers the new kinds; the record-kind contract checks their tables.
- Mutations: 15 run one at a time; 15 killed, one after a new test (the delete trigger: without it a purged record's text stayed in the index).
