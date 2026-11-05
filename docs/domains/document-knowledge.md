# Domain: Document and Knowledge

- Status: Draft (Batch 3b)
- Date: 2026-11-04
- Classification: Supporting. Phase: P05. In MVP: no.
- Related: [ADR-0017](../adr/0017-document-collaboration-maturity.md), [../data/sync-protocol.md](../data/sync-protocol.md), [../data/local-storage.md](../data/local-storage.md), [../architecture/domain-model.md](../architecture/domain-model.md), [../research/verified-sources.md](../research/verified-sources.md) VS-16/OQ-V6 (editor license)

## 1. Purpose
A block-based document engine that is independent of other contexts but linkable to Task/Event/Goal. Supports hierarchy, revisions, links, attachments, search, viewers and reading/TTS. Confidential by default (ADR-0016).

## 2. Aggregates / value objects
- **`Document`** (root): `documentId`, `title`, `parentDocumentId?` (hierarchy), ordered `blocks`, `tags`, metadata, `version`, timestamps, tombstone. Confidential class.
- `Block` (value/child): typed content block (paragraph, heading, list, image ref, embed, code, ...). Blocks are ordered; nested blocks allowed within the document.
- **`DocumentRevision`** (root or child depending on storage, see §4): an immutable snapshot/delta of a document at a point in time, with author and timestamp.
- Link/reference value objects (kept **distinct**, brief 3.6):
  - `DocumentHierarchy` — parent/child nesting of documents.
  - `Hyperlink` — a link (wiki-style or URL) from a block to a document or external target.
  - `SemanticReference` — a typed reference to a concept/entity (for backlinks/knowledge graph).
  - `Attachment` — a file stored outside the DB, referenced by path/hash (local-storage.md).
  - `LinkedResource` — the cross-context link to a Task/Event/Goal (type `document`), the same contract Goals already use.

## 3. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-DOC-001 | Document hierarchy has no parent-child cycle | `MoveDocument` checks ancestry |
| LF-INV-DOC-002 | Revision history is preserved; no silent content loss | revisions are append-only; conflicts keep both (ADR-0015) |
| LF-INV-DOC-003 | Internal references resolve or are marked broken, never silently dropped | reference integrity check |
| LF-INV-DOC-004 | Hierarchy, hyperlinks, semantic references, attachments and cross-context links are distinct relations | separate value objects |

## 4. Storage and revision model
- [Decision] Blocks are stored as typed rows/children of the document (not one opaque JSON blob where structure matters), consistent with local-storage.md; a block's inline content may be a structured value. Revisions may be stored as periodic snapshots plus deltas; exact snapshot/delta cadence is a P05 detail (OQ-DOC-1).
- [Decision] Search uses the FTS5 seam (local-storage.md, VS-23), honoring the OQ-V10 caveat (FTS5 under the encrypted build). Document text is Confidential; the search index is on-device and encrypted with the DB.
- [Decision] Attachments are files referenced by path/hash (data-architecture.md §2), not DB blobs.

## 5. Collaboration maturity (ADR-0017)
- [Decision] P05 ships **single-user editing + revision-based sync**. Two offline edits produce two revisions and a visible conflict (keep-both, ADR-0015); never silent content loss (LF-INV-DOC-002). Real-time/CRDT editing is deferred (AP-10) with a clear trigger (ADR-0017).

## 6. Viewers, reading and TTS (ports)
- [Decision] File viewers (PDF, DOCX, PPTX, images, audio/video) are **adapters behind a `FileViewer` port**, not core domain logic; feasibility and library choice are spikes (brief 3.6; viewer feasibility S-08/S-09). The domain references a file by `Attachment`; a viewer adapter renders it.
- [Decision] Reading/TTS and (later) speech recognition are **platform ports** (`TtsPort`, `SpeechPort`), not domain logic; the vocabulary listening/pronunciation features (vocabulary-learning.md OQ-VOCAB-2) reuse these ports.
- Text selection inside a document or a PDF viewer reuses the renderer-agnostic `SelectionAdapter` (dictionary-translation.md §4) so "look up / translate / save vocabulary" works from documents.

## 7. Editor library (Open — not chosen here)
[Open] The block-editor library is **not** chosen in this batch (choosing it now is premature and carries license risk). Candidates and the decision criteria are recorded for a spike / Batch 3c (stack):
- Candidates: AppFlowy Editor (**AGPL-3.0 / MPL-2.0**, VS-16 — license risk for a closed-source app, OQ-V6), super_editor, flutter_quill, or a custom block editor.
- Criteria: license fit for the app's distribution; block model match; undo/redo; extensibility for custom blocks and embeds; performance on large documents; maintenance; platform support (Windows + Android). The legacy app used AppFlowy on a git `main` pin (assessment §4.8) — informative, not decisive.

## 8. Commands (illustrative)
| Command | Actor | Args | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|
| `CreateDocument` | owner | title, parentId? | new Document v1 + initial revision | `DocumentCreated` | by `operationId` | n/a |
| `EditDocument` | owner | documentId, block changes | new revision | `DocumentRevised` | by `operationId` | `expectedVersion` |
| `MoveDocument` | owner | documentId, newParentId? | re-parented (no cycle) | `DocumentMoved` | by `operationId` | `expectedVersion` |
| `LinkDocument` | owner | documentId, LinkedResource | link added | `DocumentLinked` | by (documentId, ref) | `expectedVersion` |
| `TrashDocument` / `RestoreDocument` | owner | documentId | tombstone | `DocumentTrashed`/`DocumentRestored` | by `operationId` | `expectedVersion` |

## 9. Domain events
`DocumentCreated`, `DocumentRevised`, `DocumentMoved`, `DocumentLinked`, `DocumentTrashed`, `DocumentRestored` (added to the catalog in domain-model.md).

## 10. Repository contract
```
DocumentRepository:
  getById(DocumentId): Document?
  childrenOf(DocumentId): List<Document>
  revisions(DocumentId): List<DocumentRevision>
  search(query): List<DocumentId>     // via FTS seam
  save(Document, DocumentRevision): void  // via command handler, one transaction
```

## 11. Open questions
- OQ-DOC-1: revision snapshot/delta cadence and retention. P05.
- OQ-DOC-2: editor library (section 7) — spike / 3c.
- OQ-DOC-3: viewer library feasibility (PDF/DOCX/PPTX) — spikes S-08/S-09.
- OQ-V10: FTS5 under encryption (verified-sources).

## 12. Self-check
- [x] Block + revision model present; hierarchy has no cycles; no silent content loss.
- [x] Hierarchy / hyperlink / semantic reference / attachment / LinkedResource are distinct.
- [x] Collaboration maturity is single-user + revision sync (ADR-0017); CRDT deferred.
- [x] Editor and viewer libraries are Open (spike/3c); license risk flagged.
- [x] Documents link to Task/Event/Goal via `LinkedResource`.
