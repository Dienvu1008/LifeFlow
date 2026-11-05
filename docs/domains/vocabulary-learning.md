# Domain: Vocabulary Learning

- Status: Draft (Batch 3b)
- Date: 2026-11-04
- Classification: Supporting. Phase: P07. In MVP: no.
- Related: [dictionary-translation.md](dictionary-translation.md), [task-management.md](task-management.md), [../architecture/domain-model.md](../architecture/domain-model.md)

## 1. Purpose
Let the user actively save vocabulary, organize it, and learn it with flashcards and spaced repetition. Owns user learning data; creates review Tasks only through the Task contract. Distinguishes words merely looked up from words the user chose to save.

## 2. Aggregates / value objects
- **`VocabularyCollection`** (root): a named set of saved items (for example "English B2", "Guitar terms"). Boundary: the collection and its items' membership.
- **`SavedVocabulary`** (root): a word/phrase the user saved, with the **capture context** (the sentence/source it was saved from), a reference to a `LexicalEntry` when available, user notes, and the owning collection(s). Distinct identity from any dictionary entry (LF-INV-DICT-001).
- **`ReviewState`** (child of SavedVocabulary): spaced-repetition scheduling state — ease, interval, due date (`LocalDate`), last result, repetition count. Deterministic.
- `ReviewRecord`: an append-only log of each review (date, result), for statistics and reproducibility.

## 3. Spaced repetition
[Decision] The spaced-repetition schedule is **deterministic and reproducible**: given the same review history and algorithm parameters, the next due date is always the same (brief 3.7, "deterministic and reproducible"). The specific algorithm (for example a documented SM-2 variant) is chosen in P07; whichever is chosen, it is pure and testable (no randomness, no wall-clock beyond the review date). Review scheduling uses `LocalDate` (ADR-0010), so changing device timezone does not shift due dates.

## 4. Relationship to Dictionary and Tasks
- [Decision] Looking up a word (Dictionary) does **not** create `SavedVocabulary`; saving is an explicit user action (brief 3.7). Not every looked-up word becomes a learning item.
- [Decision] Review Tasks are created **only** via the Task contract `CreateTask` through the command gateway (ADR-0011); Vocabulary never writes Task storage directly. A review Task is an ordinary Task (optionally with a schedule/recurrence), consistent with ADR-0006.
- [Decision] Dictionary updates (a provider refreshing a `LexicalEntry`) never overwrite `SavedVocabulary`, its capture context, or `ReviewState`/progress (LF-INV-VOCAB-002). The saved item references the entry but owns its own user data.

## 5. Commands
| Command | Actor | Args | Preconditions | Result | Events | Idempotency | Concurrency |
|---|---|---|---|---|---|---|---|
| `SaveVocabulary` | owner | text, lang, captureContext, lexicalEntryRef?, collectionId? | — | new SavedVocabulary | `VocabularySaved` | by `operationId` | n/a |
| `AddToCollection` / `RemoveFromCollection` | owner | savedId, collectionId | both exist | membership change | `VocabularyCollectionChanged` | by (savedId, collectionId) | `expectedVersion` |
| `RecordReview` | owner | savedId, result | item exists | new ReviewState + ReviewRecord | `VocabularyReviewed` | by `operationId` | `expectedVersion` |
| `CreateReviewTask` | owner / scheduler | savedId or collectionId, schedule? | — | Task via `CreateTask` | (Task events) | by `operationId` | n/a |

## 6. Invariants
| ID | Statement | Enforcement |
|---|---|---|
| LF-INV-VOCAB-001 | A looked-up word is not saved vocabulary; saving is explicit | `SaveVocabulary` is the only path |
| LF-INV-VOCAB-002 | Dictionary updates never overwrite saved vocabulary, capture context or progress | SavedVocabulary owns its user data; references the entry |
| LF-INV-VOCAB-003 | Review scheduling is deterministic and reproducible | pure spaced-repetition function over ReviewRecord |
| LF-INV-VOCAB-004 | Review Tasks are created only via the Task contract | `CreateReviewTask` calls `CreateTask`; no direct Task writes |

## 7. Domain events
`VocabularySaved`, `VocabularyCollectionChanged`, `VocabularyReviewed` (added to the catalog in domain-model.md).

## 8. Repository contract
```
VocabularyRepository:
  getCollection(id): VocabularyCollection?
  dueItems(asOf: LocalDate): List<SavedVocabulary>
  save(SavedVocabulary): void   // via command handler
```

## 9. Open questions
- OQ-VOCAB-1: which spaced-repetition algorithm/parameters. P07.
- OQ-VOCAB-2: listening/pronunciation practice depends on TTS/ASR ports (3c/stack). P07.

## 10. Self-check
- [x] Saved vocabulary is distinct from dictionary entries and from looked-up words.
- [x] Review scheduling is deterministic (LocalDate-based).
- [x] Review Tasks go through the Task contract; no direct Task writes.
- [x] Dictionary updates cannot overwrite learning progress.
