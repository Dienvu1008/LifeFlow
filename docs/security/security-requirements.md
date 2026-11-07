# Security Requirements

- Status: Draft (Batch 3a)
- Date: 2026-11-04
- Related: [threat-model.md](threat-model.md), [privacy-model.md](privacy-model.md), [../data/data-architecture.md](../data/data-architecture.md), [../research/verified-sources.md](../research/verified-sources.md)

Each requirement is testable. Priority M = MVP.

## 1. Storage and keys
| ID | Requirement | Pri | Label | Source |
|---|---|---|---|---|
| SR-01 | The local database is encrypted at rest with SQLite3MultipleCiphers (whole-file); the app asserts `PRAGMA cipher` at startup. **Platform posture (ADR-0022, T5a):** enforced on **Android and Windows**. An existing plain DB is encrypted in place. A plain Windows DB is accepted only in a build made with `LIFEFLOW_WINDOWS_PLAIN_DB=true` (ADR-0021 fallback), and is then shown as a tracked exception; otherwise it is a policy violation. | M | Decision | VS-21, data-architecture §4, ADR-0021, ADR-0022 |
| SR-02 | The DB encryption key and auth tokens are stored only in platform secure storage (`flutter_secure_storage`); never in the DB, plain files, logs, exports, sync or AI context. | M | Decision | VS-24, LF-INV-SEC-001 |
| SR-03 | Each LocalProfile has its own DB file and its own key. **Implemented in P01 T6c (ADR-0023):** `profiles/<id>.sqlite` with key `lifeflow.db.key.<id>`, plus an encrypted device registry with its own key. The pre-SR-03 shared DB is split once and kept as an encrypted `.pre-sr03` backup. | M | Decision | data-architecture §6, ADR-0023 |
| SR-04 | A random 256-bit key is generated on first launch per profile; no user passphrase in MVP (OQ-DATA-1 resolved). Losing the device without an export means the data is unrecoverable; the user-initiated export is the MVP backup (OQ-DATA-3 (a), ADR-0025). | M | Decision | data-architecture §4 |
| SR-05 | Attachments stored outside the DB are protected consistently with the DB (approach per OQ-DATA-2). | M | Proposal | data-architecture §2 |

### 1a. Windows plain-DB mitigations (ADR-0021; fallback builds only since ADR-0022)
Since ADR-0022 Windows is encrypted by default. SR-01a still applies to every build (the self-check always runs). SR-01b and SR-01c apply only to a build made with the plain-database fallback flag. While a Windows DB is plain, these mitigations apply and are surfaced to the user rather than left implicit:
| ID | Requirement | Pri | Label |
|---|---|---|---|
| SR-01a | The startup storage self-check (`StorageSecurity.evaluate`) runs on every launch; when at-rest encryption is off it emits a local warning and sets `atRestEncrypted=false` + `trackedException=true` in the diagnostic bundle. Never silent. | M | Decision (ADR-0021) |
| SR-01b | The Windows app recommends enabling OS full-disk encryption (BitLocker) and documents that the local DB is not encrypted at rest in the MVP. | M | Decision (ADR-0021) |
| SR-01c | The UI warns the user before storing Restricted data (e.g. health) on a Windows device while at-rest encryption is off, and advises using the local export as the controlled backup. | M | Decision (ADR-0021) |
| SR-01d | Auth tokens and the DB key remain in `flutter_secure_storage` regardless of DB encryption (LF-INV-SEC-001), so the plain DB never exposes secrets. **T6b:** the Supabase session and the PKCE code verifier are both stored in secure storage (the SDK's `shared_preferences` default for the verifier is overridden). | M | Decision |
| SR-01e | At-rest encryption is detected from the database **file header**, never from `PRAGMA cipher` (sqlite3mc reports a cipher even for an unkeyed plain file; T6b finding, ADR-0021 update). | M | Decision |

## 2. Authentication and session
| ID | Requirement | Pri | Label |
|---|---|---|---|
| SR-06 | Desktop (Windows) OAuth uses PKCE with S256, not `plain` (correcting the legacy anti-pattern). | M | Decision |
| SR-07 | The auth session is cached in secure storage and refreshed correctly; an unreachable auth server never blocks local data. | M | Decision (LF-INV-SEC-002) |
| SR-08 | Tokens are never written to the app's logs or diagnostic bundle. | M | Decision |

## 3. Authorization and egress
| ID | Requirement | Pri | Label |
|---|---|---|---|
| SR-09 | Every mutation is authorized before the domain method runs (gateway). | M | Decision (LF-INV-GOV-002) |
| SR-10 | Every egress point (AI context, cloud AI, sync, share) enforces the data-classification matrix (default deny). | M | Decision (LF-INV-PRIV-003) |
| SR-11 | Restricted data (health, secrets) is never sent to cloud AI and never shared implicitly. | M | Decision (LF-INV-PRIV-002) |
| SR-12 | When Supabase is the backend (ADR-0003), every synced table has an RLS policy mirroring the authorization model, with a `supabase test db` allow/deny suite. | P (P04) | Proposal | VS-06/07/08 |

## 4. Integrity and recovery
| ID | Requirement | Pri | Label |
|---|---|---|---|
| SR-13 | A command's atomic set commits in one transaction; a failure leaves no partial state. | M | Decision (LF-INV-GOV-003) |
| SR-14 | Import validates schema, version and checksum; untrusted until validated; failure is atomic. **Implemented in P01 T7 (ADR-0025).** | M | Decision |
| SR-15 | No telemetry or user-data egress except the user's own auth (and P04 sync); debugging via local logs + audit + user-initiated export. | M | Decision (NFR-PRIV-01) |

## 5. Dependencies
| ID | Requirement | Pri | Label |
|---|---|---|---|
| SR-16 | Dependencies are pinned to exact/reviewed versions; unusual or typosquat-looking packages are flagged before adding. | M | Decision |
| SR-17 | AGPL/MPL-licensed candidates (for example AppFlowy, VS-16) are reviewed for license fit before any dependency is added. | M | Decision (OQ-V6) |

## 6. Verification posture
- [Assumption] Full WCAG/security certification is out of scope for the MVP; these requirements are verified by unit/integration/architecture tests (Batch 4) and manual review. Encryption, secure storage, egress and RLS get explicit tests/golden scenarios.
- [Open] OQ-SEC-1: do we need encryption-export self-classification (US regulations) because SQLCipher-family crypto is bundled? Flag for legal review before release (not legal advice).

## 7. Self-check
- [x] Every requirement is testable and labeled.
- [x] Legacy anti-patterns (PKCE plain) are explicitly corrected.
- [x] Egress and secure-storage requirements map to invariants.
