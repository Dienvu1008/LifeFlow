# Privacy Model

- Status: Draft (Batch 3a)
- Date: 2026-11-04
- Related: [../data/data-classification.md](../data/data-classification.md), [threat-model.md](threat-model.md), [security-requirements.md](security-requirements.md), [../product/product-vision.md](../product/product-vision.md) (principle P6)

## 1. Principles
Privacy-by-design (P6). Data minimization, explicit consent, local-first, default-deny egress (ADR-0016).

## 2. Telemetry
[Decision] **No telemetry in the MVP.** The app sends no usage analytics, crash telemetry or user data to any server except the user's own authentication (and, from P04, their own sync backend). This is a Decision, not an Assumption: it follows from NFR-PRIV-01 and the egress matrix (Personal/Confidential/Restricted are not sent for analytics).

Because there is no telemetry, production debugging relies on local, user-controlled mechanisms:
- [Decision] **Local structured logs** on the device, at a level the user can raise/lower, stored in app-private storage, never auto-uploaded. Logs exclude Restricted data (no tokens, no health values) and redact Confidential content.
- [Decision] **User-initiated diagnostic export**: the user can export a diagnostic bundle (recent local logs + non-sensitive environment info + optionally the data export) and share it manually (for example attach to a bug report). Nothing leaves the device without this explicit action.
- [Decision] The in-app **audit log** (governance) already records what changed and why, which covers most "what happened" debugging without telemetry.
- [Proposal] If opt-in crash reporting is ever added, it is off by default, names the provider, and scrubs Personal/Confidential/Restricted data; this would be a new ADR, not a silent change.

This gives a debugging path that respects the no-telemetry decision: reproduce from the user's exported logs and audit trail, not from server-side collection.

## 3. Consent
- [Decision] Sensitive egress (cloud AI on Confidential data, any Restricted action, sharing a resource) requires explicit, per-request consent; a prior unrelated approval does not carry over (ADR-0016).
- [Decision] Health access (P08) uses the platform permission flow (Health Connect, VS-12); the app re-checks permission before each use and never treats absence as zero (LF-INV-HEALTH-002).

## 4. Revocation
- [Decision] Revoking health permission stops reads immediately; already-stored measurements remain unless the user deletes them, and their provenance marks them as from a now-revoked source. Revocation is not retroactive deletion and is not zero (brief 3.8).
- [Proposal] The user can delete previously imported health data in one action; health batch confirms the UX.

## 5. Export and deletion
- Export (UC-20a): complete local export including tombstones and audit; Restricted items flagged, with a warning (data-architecture.md section 5).
- Account identity deletion (UC-20b): removes the account and its binding; local profile data stays unless the user also deletes the profile. Deleting a profile removes its database file and key (secure wipe).
- [Decision] Deletion produces tombstones first (for sync), then purges after retention; purge removes decrypted copies and FTS index entries.
- Right-to-be-forgotten for synced/shared data is a P04 concern (needs the backend).

## 6. Cloud-AI data boundary
The Context Builder enforces the egress matrix before building context and before any cloud call (ADR-0016 section 4). Restricted never reaches cloud AI; Confidential requires the cloud-AI toggle plus per-request consent (LF-INV-PRIV-002).

## 7. Invariants
- LF-INV-PRIV-001/002/003 (default-deny, Restricted protection, enforcement at egress), LF-INV-SEC-001/002.

## 8. Open questions
- OQ-PRIV-1: default log retention and redaction rules. Security batch / P01.
- OQ-PRIV-2: whether a diagnostic bundle may include the encrypted DB (proposal: no; only decrypted, redacted logs + optional data export).

## 9. Self-check
- [x] No-telemetry is a Decision with a stated production-debugging path.
- [x] Consent, revocation, export/delete and cloud-AI boundary are covered.
- [x] Health revocation is not treated as zero.
