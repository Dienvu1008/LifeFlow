# Data Architecture (Local-first)

- Status: Draft (Batch 3a)
- Date: 2026-11-04
- Related: [local-storage.md](local-storage.md), [sync-protocol.md](sync-protocol.md), [../governance/governance-kernel.md](../governance/governance-kernel.md), [ADR-0009](../adr/0009-identifier-and-versioning-strategy.md), [ADR-0014](../adr/0014-transactional-outbox-and-atomic-side-effects.md), [../research/verified-sources.md](../research/verified-sources.md)

Label legend: see [../README.md](../README.md).

## 1. Principle
Local-first: the device holds a usable, authoritative copy of the active profile's data, and all MVP features work offline. Cloud (P04) adds sync, sharing and backup. Local-first is not "everything only on device" — some data is server-authoritative once sync exists (section 3).

## 2. Local store
- [Decision] **Drift on a `NativeDatabase` (dart:ffi)** on Windows and Android (VS-02). With Drift 2.32.0+ and `sqlite3` 3.x, SQLite is bundled via build hooks; `sqlite3_flutter_libs`/`sqlcipher_flutter_libs` are not needed (VS-03, VS-22).
- [Decision] **Transactions**: the Governance Kernel runs each command in one Drift transaction holding the aggregate change, audit, outbox, event-log and dedupe writes (ADR-0014, LF-INV-GOV-003). Drift exposes `transaction()`; isolate use is recommended for the native database (VS-02).
- [Decision] **Full-text search via FTS5** (VS-23) for task titles, note/document text (P05) and vocabulary. FTS5 tables are declared in `.drift` files. [Open] OQ-V10: confirm FTS5 is compiled into the SQLite3MultipleCiphers build (encryption below) via `PRAGMA compile_options` in spike S-02; if absent, fall back to a non-encrypted search index over non-sensitive fields or a LIKE-based search for MVP.
- [Decision] **File/attachment storage**: binary attachments are stored as files in an app-private directory, referenced by path/hash in the database, not as BLOBs, to keep the DB small and backup incremental. [Proposal] Attachment encryption follows the same key as the DB where the platform does not already encrypt app-private storage; detailed in security-requirements.

## 3. Source-of-truth map (per entity)
[Decision] Authority is explicit per entity. "Local-authoritative" means the device's value wins and the server stores a copy; "Server-authoritative" means the server's value wins on conflict (relevant from P04); "Hybrid" means field-dependent. In the MVP (no sync) everything is local; this map is the contract the sync protocol (P04) implements.

| Entity | Authority | Reason |
|---|---|---|
| Task, Subtask, TaskList | Local-authoritative | Personal productivity data created on-device; conflicts resolved per-field (sync-protocol) |
| ScheduleSpec / RecurrenceRule / OccurrenceException | Local-authoritative | Owned by the Task/Event aggregate |
| Event, Calendar | Local-authoritative (external-calendar mirror is Hybrid, P04+) | App-owned events are local; synced external events conform to the provider via ACL |
| FocusSession | Local-authoritative | Device-local timing; not meaningfully editable elsewhere |
| ExecutionRecord, Measurement | Local-authoritative, append-mostly | History is preserved (LF-INV-EXEC-001); corrections add rows |
| Goal, Project, Milestone, LinkedResource | Local-authoritative | Derived progress recomputed locally |
| LocalProfile | Local-only | Never leaves the device |
| AccountBinding | Hybrid | `accountId` comes from the provider (server-authoritative); binding record is local |
| Workspace membership, roles, sharing grants (P04) | **Server-authoritative** | Authorization must be enforced server-side (RLS); a client cannot grant itself access |
| Audit, outbox, event log, dedupe | Local-authoritative, append-only | Local provenance; audit export is local (not pushed to cloud by default) |

## 4. Encryption at rest (resolves OQ-R4)
[Decision] The MVP encrypts the **whole database file** using **SQLite3MultipleCiphers** (SQLCipher-compatible), enabled through the `sqlite3` build hook `hooks: user_defines: sqlite3: source: sqlite3mc`, with the key set via `PRAGMA key` in the `NativeDatabase` `setup` callback (VS-21). The app verifies the encrypted build at runtime with `PRAGMA cipher` (VS-21).

[Decision] **Field-level encryption is rejected** for the MVP: it does not protect metadata (table shape, row counts, timestamps, foreign keys), it breaks or greatly complicates FTS5 and range queries, and it adds key-management complexity per field. Whole-file encryption protects the data and metadata at rest with one key and keeps FTS and queries working on the decrypted in-memory database. This supersedes the owner's wording "SQLCipher via `sqlcipher_flutter_libs`": the library is obsolete (VS-22); the equivalent, current mechanism is SQLite3MultipleCiphers via build hooks, which is SQLCipher-compatible. See [ADR-0016](../adr/0016-data-classification-and-egress-policy.md) for the egress side and the security-requirements doc for key handling.

- The encryption key lives in platform secure storage (`flutter_secure_storage`, VS-24), never in the database or plain files (LF-INV-SEC-001).
- [Decision, owner 2026-11-04] OQ-DATA-1 resolved: a **random 256-bit key generated on first launch per profile, stored in platform secure storage; no user passphrase in the MVP**. Consequence (recorded): if the device is lost or secure storage is wiped and there is **no backup of the key or of a decrypted export**, the encrypted database is **unrecoverable** — the data is lost. This is acceptable for the MVP because the local export (UC-20a) is the user-controlled backup path. See the new OQ-DATA-3 on key backup.
- [Open] OQ-DATA-3 (new, non-blocking for P01): should the MVP offer a key/data backup so a lost device does not mean lost data? Options: (a) rely only on the user-initiated decrypted export (UC-20a) as the backup — simplest, MVP default; (b) optional passphrase-wrapped key export; (c) cloud key escrow (needs backend, P04+). Proposal: ship (a) for the MVP and surface a clear warning that losing the device without an export loses the data; revisit (b)/(c) at P04. Decide before P01 UX is finalized.
- Caveat to verify: FTS5 availability under the encrypted build (OQ-V10, spike S-02).

## 5. Backup and restore
- [Decision] Local export is a versioned, checksummed file of all user-owned entities including tombstones (UC-20a, LF-INV-SEC-010). Restore into a clean install reproduces the data (round-trip, AC-20a.1).
- [Decision] The export file is **decrypted application data** (not the raw encrypted DB) in a documented schema, so it is portable across installs and the encryption key is not needed to read it. [Proposal] The export may itself be optionally encrypted with a user-provided passphrase; default is a plain (but local-only) file with a warning. Security batch decides the default.
- Export includes audit and provenance (audit-and-provenance.md).

## 6. Profile isolation storage
[Decision] Each `LocalProfile` (ADR-0008) uses a **separate database file** (and its own encryption key) rather than profile-scoped rows in one shared database. Reason: strong isolation (LF-INV-ID-002) with no risk of a query leaking across profiles, and per-profile export/delete is a file operation. Trade-off: switching profiles reopens a database; acceptable (profile switching is infrequent, AS-07). See local-storage.md section 4.

## 7. Open questions
- OQ-DATA-1: **resolved** (section 4) — random 256-bit key in secure storage, no passphrase.
- OQ-DATA-3 (new, non-blocking): key/data backup so a lost device is not a total loss (section 4).
- OQ-V10: FTS5 under the encrypted build (verified-sources; spike S-02).
- OQ-DATA-2: attachment encryption approach (section 2); security batch.

## 8. Self-check
- [x] Source-of-truth map lists every MVP entity with an authority and a reason.
- [x] Encryption decision resolves OQ-R4 and corrects the obsolete library to the current mechanism.
- [x] FTS5-under-encryption risk is tracked as OQ-V10 with a fallback.
- [x] Local-first is defined without claiming everything is device-only.
