# Risk Register

- Status: Draft (Batch 5)
- Date: 2026-11-04
- Related: [phase-breakdown.md](phase-breakdown.md), [../spikes/spike-plan.md](../spikes/spike-plan.md), [../testing/golden-scenarios.md](../testing/golden-scenarios.md)

Owner is one of: **Human (decision/review)**, **Agent (execution)**, or **needs external input** (product/legal/vendor decision outside the dev+agent lane). Severity = likelihood × impact (L/M/H). Validation names how we would know the mitigation worked.

| ID | Risk | Likelihood | Impact | Severity | Trigger | Mitigation | Contingency | Owner | Validation |
|---|---|---|---|---|---|---|---|---|---|
| R-SCOPE | Scope explosion beyond the MVP | High | High | H | new features pulled into P01–P03 | ADR-0005 boundary; deferred list with extension points; Human gate at each exit | cut back to the MVP boundary; move items to later phases | Human | each phase exit reviews scope vs ADR-0005 |
| R-OVERENG | Over-engineering (speculative abstractions) | Med | Med | M | abstractions without a current use case | AP-13; right-sized ADRs; review | remove the abstraction | Human | FF-ARCH + review flag unused seams |
| R-OFFLINE-SYNC | Offline sync complexity causes bugs/loss | High | High | H | P04 conflict/merge errors | per-type conflict (ADR-0015); outbox atomicity (ADR-0014); S-04 spike; GS-08/12/14/17 | narrow sync to fewer entity types; delay P04 features | Agent (build), Human (design) | GS-08/14/17 pass in the sync harness |
| R-PERMISSION | Shared-workspace permission errors | Med | High | H | P04 RLS/authorization gaps | server-authoritative membership; RLS mirrors app auth; S-03; supabase test db | restrict sharing scope; more tests | needs external input (backend) + Human | RLS allow/deny suite (VS-08) green |
| R-DATA-LOSS | Silent data loss (crash, concurrency, migration) | Med | High | H | a committed change missing audit/outbox, or a lost update | atomic set (LF-INV-GOV-003), in-tx version (VER-001), no destructive migrations | restore from export; fix + regression test | Agent (build), Human (review) | GS-06/07/12 + migration tests pass |
| R-DOC-COLLAB | Document collaboration complexity (CRDT temptation) | Med | Med | M | demand for real-time editing | ADR-0017 single-user + revision first; CRDT only on validated need | keep revision model; defer real-time | Human | GS-08 passes; CRDT not adopted without trigger |
| R-HEALTH-PRIVACY | Health data leak or implicit share | Low | High | M | Restricted data egress | Restricted class; default-deny egress (ADR-0016); FF-ARCH-08; GS-16 | disable health egress paths | needs external input (privacy posture) + Human | GS-16 + FF-ARCH-08 green |
| R-HEALTH-DUP | Duplicate health data double-counts | Med | Med | M | multi-source / token expiry | dedup in ACL by origin id + Changes token (VS-14); GS-05 | widen dedup window; manual review | Agent | GS-05 passes |
| R-DICT-LICENSE | No license-compatible dictionary source | Med | Med | M | S-10 finds no compatible source | provider port + ACL (source swappable); S-10 criteria | online-only or fewer languages | needs external input (licensing) | S-10 records ≥1 compatible source |
| R-EXTERNAL-API | External API dependency (dictionary/translation) unstable or changes terms | Med | Med | M | API outage/term change | ACL isolates providers; offline packages; multiple candidates | swap provider; offline fallback | needs external input (vendor) | ACL swap tested with a second provider |
| R-AI-HALLUCINATION | AI proposes wrong/destructive actions | Med | High | H | model error or injection | proposals only; gateway + approval; version-bound approval; untrusted-data tagging | deny/regenerate; reduce AI autonomy | Human (policy), Agent (build) | GS-15/16 + injection test pass |
| R-AI-LEAK | Over-broad or restricted context to AI | Low | High | M | context-builder scoping bug | bounded scoping; egress checkpoint; FF-ARCH-08 | disable cloud AI | Human | GS-16 + FF-ARCH-08 |
| R-CLOUD-COST | Cloud cost (AI/backend) unexpectedly high | Med | Med | M | heavy usage | local-first; caching; token-bounded context; prefer local AI | throttle/limit; local-only mode | needs external input (budget) | cost benchmark at P04/P06 (out of estimation scope) |
| R-WINDOWS-ANDROID | Windows/Android behavior differences | Med | Med | M | platform-specific bugs | adaptive-by-size UI; platform adapters behind ports; per-platform tests | reduce a feature on the weaker platform | Agent | build + tests green on both |
| R-FLUTTER-PLUGIN | Flutter plugin immaturity (Windows especially) | Med | Med | M | a needed plugin lacks Windows support | spikes S-05/S-08/S-09/S-12; candidate + criteria; port abstraction | native code or reduced scope on Windows | Agent (build), needs external input (if none exists) | spike success criteria met |
| R-BACKGROUND | Background execution limits (notifications/health) | Med | Med | M | OS restricts background work | foreground + on-resume reads (VS-13); scoped reminders | accept foreground-only; document | Agent | S-05/S-13 success criteria |
| R-WINDOWS-NOHEALTH | Windows has no Health Connect | High (known) | Low | L | health on Windows expected | documented: Windows gets health only via sync from Android (OQ-V1) | none needed; by design | Human (expectation) | doc + UX copy |
| R-EDITOR-LICENSE | Editor license incompatibility (AGPL) | Low (mitigated) | Med | L | adopting AppFlowy | ADR-0018 excludes AGPL; ADR-0020 picks MIT/BSD; S-07 | flutter_quill or custom | Human | FF-ARCH-07 (license scan) green |
| R-FTS-ENCRYPTION | FTS5 unavailable under the encrypted build (OQ-V10) | Low (mitigated) | Med | L | S-02 finds FTS5 absent | verified in S-02: FTS5 present on the plain build (3/3 headless) | LIKE search; external index later | Agent | S-02 `PRAGMA compile_options` (done, PASS plain) |
| R-ENCRYPTION-WINDOWS | Encryption-at-rest does not build cleanly on Flutter Windows (S-02: SQLCipher needs OpenSSL; sqlite3mc 3.x hook fails at CMake INSTALL) | High (observed) | Med | H | `flutter run -d windows` fails to bundle an encryption-capable sqlite | S-02 escalated it to an early P01 task with a fallback (ship plain-DB + FTS5 first, add encryption when a Windows-clean path is confirmed); Android path expected OK | OS/file-level encryption on Windows; or accept OpenSSL for SQLCipher; or wait for the 3.x sqlite3mc Flutter path to mature | Human (decide the Windows mechanism) + Agent (build) | a `flutter run -d windows` that bundles an encrypted sqlite and passes the S-02 check app |
| R-SPIKE-DRAG | A spike drifts into a feature | Med | Med | M | spike exceeds its time-box | time-box + escalate-as-Open rule (spike-plan) | stop, record Open, Human decides | Human | spike closes within time-box or is escalated |

## Defer / do-not-build-in-MVP / buy-third-party (summary)
- **Defer:** sync (P04), documents (P05), AI (P06), dictionary/vocabulary (P07), health (P08), learning (P09), iOS/CRDT (P10).
- **Do not build in MVP:** custom fitness algorithm, vendor smartwatch adapters, real-time collaboration, web client, microservices, analytics/telemetry.
- **Buy / third-party (license-cleared, ADR-0018):** Drift (DB), SQLite3MultipleCiphers (encryption), go_router, Riverpod, flutter_secure_storage, uuid, timezone; later: an MIT/BSD editor, viewers, TTS, AI providers — each via its spike.

## Self-check
- [x] Every brief-listed risk is present (scope, over-eng, offline-sync, permission, data loss, doc collab, health privacy, health dup, dictionary licensing, external API, AI hallucination, cloud cost, Windows/Android, Flutter plugin, background).
- [x] Each risk has mitigation + contingency + validation.
- [x] Owners are only Human / Agent / needs external input.
- [x] Defer / do-not-build / buy summary present.
