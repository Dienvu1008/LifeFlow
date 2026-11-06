# Data Classification and Egress Policy

- Status: Draft (Batch 3a)
- Date: 2026-11-04
- Related: [ADR-0016](../adr/0016-data-classification-and-egress-policy.md), [../governance/authorization-model.md](../governance/authorization-model.md), [../governance/ai-action-governance.md](../governance/ai-action-governance.md), [../security/privacy-model.md](../security/privacy-model.md)

This is the contract that Batch 3c's AI architecture consumes for context eligibility and that the sync and sharing designs consume for cloud eligibility.

## 1. Classes
[Decision] Four classes, from least to most sensitive:

| Class | Meaning | Examples |
|---|---|---|
| Public | Non-personal reference data shippable with the app | Dictionary packages, app templates, time-zone data |
| Personal | The user's ordinary content | Tasks, events, goals, lists, schedules, focus sessions |
| Confidential | Personal content the user would not want shared without intent | Private documents (P05), note bodies, AI chat history |
| Restricted | Sensitive categories needing explicit consent and the tightest egress | Health and activity data, auth tokens/secrets, biometric-derived data |

## 2. Egress matrix
[Decision] "Default deny": unless a cell is explicitly allowed, the action is denied. Egress means the data leaving its current boundary.

| Action | Public | Personal | Confidential | Restricted |
|---|---|---|---|---|
| Read on device (owner) | Allow | Allow | Allow | Allow |
| Edit on device (owner) | n/a | Allow | Allow | Allow (manual); provider data via ACL only |
| Cloud sync (P04) | Allow | Allow | Allow (encrypted in transit and at rest) | **Deny by default**; opt-in per category with explicit consent |
| Included in local AI context | Allow | Allow | Allow if the session scope permits | **Deny by default**; explicit per-request consent |
| Sent to cloud AI | Allow | Allow only if the user enabled cloud AI and the data class is permitted | **Deny by default**; explicit per-request consent | **Deny** |
| Shared into a Shared Workspace (P04) | Allow | Explicit share action only (never implicit) | Explicit share action only | **Deny** (health is never shared implicitly; explicit share is a separate, logged decision) |
| Used in analytics | Allow (aggregate) | Aggregate only, on-device | **Deny** | **Deny** |
| Retention / deletion | App-managed | Deleted with the entity; tombstone then purge | Same, plus secure wipe of decrypted copies | Same, plus revocation handling (health) |

Notes:
- "Explicit per-request consent" means the user approves this specific egress for this specific action; a prior unrelated approval does not carry over.
- Cloud AI with Confidential data requires both the feature toggle and a per-request consent; Restricted is never sent to cloud AI.
- Auth tokens (Restricted) live only in secure storage and never appear in exports, logs, sync or AI context (LF-INV-SEC-001).

### 2a. At-rest encryption posture per platform (ADR-0021, amended by ADR-0022)
**Since ADR-0022 (2026-11-06) both Android and Windows are encrypted at rest by default, so Restricted data is encrypted at rest on both MVP platforms.** The Windows paragraph below now describes only a build made with the explicit plain-database fallback flag (`LIFEFLOW_WINDOWS_PLAIN_DB=true`).

The egress matrix above governs data **leaving** the device. At-rest protection on the device itself depends on the platform (ADR-0021):
- **Android**: the local DB is encrypted at rest (SQLite3MultipleCiphers), so all classes including **Restricted** are encrypted at rest.
- **Windows (MVP)**: the local DB runs **plain** as a tracked exception. Consequence: **Restricted data (health, etc.) is NOT encrypted at rest on Windows in the MVP.** This is explicit, not silent — the startup self-check warns and records it (SR-01a). Mitigations: OS full-disk encryption (BitLocker, SR-01b), a UI warning before storing Restricted data on Windows (SR-01c), and the local export as the controlled backup. Auth tokens and keys stay in secure storage regardless (SR-01d / LF-INV-SEC-001). Promote Windows to encrypted when a Windows-clean path ships.

## 3. Classification rules
- [Decision] Default class for new user content is **Personal**.
- [Decision] Health and activity data is **Restricted** regardless of source.
- [Decision] AI chat history and private document bodies are **Confidential** by default; a user may raise an item to a stricter handling but not lower Restricted data.
- [Proposal] A per-item override may raise classification; it cannot lower Restricted. Confirmed in the privacy model.

## 4. Enforcement points
- The AI Context Builder checks the egress matrix before including any item and before any cloud call (ai-action-governance.md section 3).
- The sync engine checks the matrix before placing an item in the outbox for cloud (P04).
- The sharing action checks the matrix and requires an explicit, logged decision (P04).
- Export includes all classes (it is local), but marks Restricted items and warns on export (data-architecture.md section 5).

## 5. Invariants
- LF-INV-PRIV-001 (default-deny egress), LF-INV-PRIV-002 (Restricted never reaches cloud AI; never shared implicitly), LF-INV-PRIV-003 (classification is enforced at every egress point), LF-INV-SEC-001 (secrets only in secure storage).

## 6. Open questions
- OQ-CLASS-1: whether Confidential may sync to cloud by default at P04 or stays opt-in. Proposal: opt-in per category. Collaboration/sync batch.
- OQ-CLASS-2: analytics scope (the MVP has none; NFR-PRIV-01). Revisit only if analytics is ever added.

## 7. Self-check
- [x] Four classes with examples.
- [x] Default-deny egress matrix covering sync, AI context, cloud AI, sharing, analytics, retention.
- [x] Health is Restricted and never implicitly shared or sent to cloud AI.
- [x] Enforcement points name who checks the matrix.
