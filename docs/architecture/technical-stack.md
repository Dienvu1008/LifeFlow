# Technical Stack

- Status: Draft (Batch 3c)
- Date: 2026-11-04
- Related: [ADR-0018](../adr/0018-dependency-license-policy.md), [ADR-0019](../adr/0019-ui-state-management-and-navigation.md), [ADR-0020](../adr/0020-editor-decision-or-spike.md), [repository-structure.md](repository-structure.md), [../research/verified-sources.md](../research/verified-sources.md)

Every row is classified: **Chosen now** (needed for P01–P03, decided), **Candidate + spike** (criteria set, decision deferred to a spike), or **Port only** (an interface now; implementation chosen later). Licenses follow ADR-0018 (AGPL excluded; unknown = reject). Each choice cites a `VS-*` license row.

## 1. Core (Chosen now — P01–P03)

| Concern | Choice | License | Class | Reason / alternative |
|---|---|---|---|---|
| Framework | Flutter / Dart | BSD-3 (Flutter) | Chosen now | Owner decision; cross-platform Windows+Android (VS-01) |
| Local DB | Drift on `NativeDatabase` (dart:ffi) | MIT (VS-26) | Chosen now | Recommended for new apps, all target platforms (VS-02/03); alt `drift_sqflite` rejected (no desktop, no isolate) |
| Encryption at rest | SQLite3MultipleCiphers via `sqlite3` build hook (`source: sqlite3mc`) | MIT (VS-25) | Chosen now | SQLCipher-compatible, current mechanism (VS-21/22); replaces obsolete `sqlcipher_flutter_libs` |
| Full-text search | SQLite FTS5 (bundled) | public domain (SQLite) | Chosen now, with caveat | VS-23; **OQ-V10**: confirm FTS5 compiled into the encrypted build in spike S-02; fallback = LIKE search for MVP |
| IDs | `uuid` (v7) | MIT (VS-19 package) | Chosen now | Time-ordered IDs (ADR-0009) |
| Time zones | `timezone` | BSD-2 (per pub) | Chosen now | IANA DB + TZDateTime (VS-20); confirm SPDX in T6 |
| Secure storage | `flutter_secure_storage` | BSD-3 (VS-31) | Chosen now | Keys/tokens in platform secure storage (VS-24, SR-02) |
| State management | Riverpod (`flutter_riverpod`) | MIT (VS-28) | Chosen now | ADR-0019; testable, compile-safe, no business logic in widgets |
| Routing | `go_router` | BSD-3 (VS-27) | Chosen now | ADR-0019; declarative router for adaptive navigation |

## 2. Platform capabilities (mix)

| Concern | Choice | License | Class | Reason |
|---|---|---|---|---|
| Local notifications | candidate: `flutter_local_notifications` | BSD-3 (to confirm) | Candidate + spike (S-05) | Legacy used it; verify Windows behavior (OQ-V2) |
| Background execution | candidate per platform | — | Candidate + spike (S-05) | Windows/Android differ; do not adopt the legacy dead `flutter_background_service` |
| File picking / files | candidate: `file_picker` / `path_provider` | MIT/BSD (to confirm) | Candidate + spike | Needed for export/attachments; confirm licenses |
| Audio / TTS | `TtsPort` / `SpeechPort` interfaces | — | Port only | Implementations chosen in P07 (vocabulary) / P05 (reading); candidates + S-12 |
| PDF rendering | — | — | Candidate + spike (S-08) | No library chosen; criteria below |
| DOCX / PPTX rendering | — | — | Candidate + spike (S-09) | No library chosen; feasibility uncertain |

[Decision] PDF/DOCX/PPTX viewers, TTS and background/notification libraries are **not chosen now**; each is a `FileViewer`/platform port with a candidate list and a spike. Rationale: these belong to P05/P07/later and choosing now would be speculative (AP-13) and license-risky without verification.

## 3. AI providers

| Concern | Choice | License | Class | Reason |
|---|---|---|---|---|
| AI engine abstraction | `AiEngine` port (ported from legacy) | project code | Port only | ai-architecture.md |
| Local provider | candidate: Ollama (HTTP), llama.cpp (FFI) | MIT (llama_cpp_dart VS-18) / Ollama terms | Candidate + spike | Legacy already has adapters; not wired as a dependency now |
| Cloud provider | `AiEngine` port, no adapter | — | Port only | No cloud AI chosen; routing governed by ADR-0016 |

[Decision] No AI provider is a committed dependency in the MVP; AI is P06. Local candidates reuse the legacy adapters; the cloud side is a port only.

## 4. Backend (Port only — backend-neutral, ADR-0003)

| Concern | Choice | Class | Reason |
|---|---|---|---|
| Auth | `AuthGateway` port | Port only | Provider decided by spike S-03a (Supabase lean); not hard-wired |
| Sync / remote data | `RemoteGateway` port | Port only | P04; backend decided after S-03/S-04 |

No Supabase (or Firebase) package is a committed dependency in the MVP. Any Supabase-specific choice is conditional on ADR-0003.

## 5. Editor (see ADR-0020)
Resolved as a decision with a clean license (not left vague): see ADR-0020 and document-knowledge.md section 7. Summary: prefer an MIT/BSD block/structured editor (super_editor MIT, VS-30) over AGPL/MPL (AppFlowy excluded by ADR-0018). Final pick confirmed by a short P05 editor spike; AppFlowy is out due to AGPL.

## 6. CI/CD
| Concern | Choice | Class | Reason |
|---|---|---|---|
| CI | candidate: GitHub Actions (or equivalent) | Candidate | Legacy had no CI; Batch 4 defines the pipeline and fitness functions |

## 7. License compliance summary
All "Chosen now" rows are MIT/BSD/Apache/public-domain (ADR-0018 compliant). No AGPL in any chosen row. Unverified SPDX notes (timezone BSD variant, flutter_secure_storage, file/notification packages) are marked "to confirm" and must be verified before adoption (default reject until then, ADR-0018).

## 8. Open questions
- OQ-STACK-1: confirm exact SPDX for `timezone`, `flutter_secure_storage`, `file_picker`, `flutter_local_notifications`. Before adoption.
- OQ-V10: FTS5 under encryption (spike S-02).
- Spikes S-05/S-08/S-09/S-12 for platform/viewer/TTS libraries.

## 9. Self-check
- [x] Every row is classified Chosen now / Candidate + spike / Port only.
- [x] PDF/DOCX, TTS, AI providers are candidate+spike or port, not chosen.
- [x] Every chosen row has a license compatible with ADR-0018 and a `VS-*`.
- [x] Backend is port-only (backend-neutral).
