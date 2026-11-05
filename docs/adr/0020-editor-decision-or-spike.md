# ADR-0020: Block editor — MIT/BSD-licensed, final pick via a short P05 spike

- Status: Accepted (direction decided; final library confirmed by a dated P05 spike)
- Date: 2026-11-04
- Deciders: Architecture team (owner to confirm)
- Resolves: OQ-DOC-2 (no longer vague)
- Evidence: [../domains/document-knowledge.md](../domains/document-knowledge.md) section 7; [ADR-0018](0018-dependency-license-policy.md); [../research/verified-sources.md](../research/verified-sources.md) VS-16/VS-29/VS-30

## Context
The Document engine (P05) needs a block/structured editor. ADR-0018 excludes AGPL. The owner asked that the editor be decided with a clean license or kept Open with criteria AND a dated spike — not left vague.

## Options and licenses
| Candidate | License | ADR-0018 verdict |
|---|---|---|
| AppFlowy Editor | AGPL-3.0 / MPL-2.0 (VS-16) | **Rejected** (AGPL excluded; the MPL option for a large multi-file editor is awkward and risky) |
| super_editor | MIT (VS-30) | Acceptable |
| flutter_quill | MIT (VS-29) | Acceptable, but document/delta model is richer-text than block-structured |
| custom block editor | project code | Acceptable, highest effort |

## Decision
Direction decided now: **use an MIT/BSD-licensed editor; AppFlowy is rejected on license (ADR-0018).** The leading candidate is **super_editor (MIT)** for its block/document model, which fits the block + revision design (document-knowledge.md). The **final library is confirmed by a short, dated spike at the start of P05** (spike S-07, document editor), which checks: block model fit, revision/delta integration, undo/redo, custom-block extensibility, large-document performance, Windows+Android support, and maintenance.

This is not left Open-ended: the acceptable set is fixed (MIT/BSD only), the leading candidate is named, and the decision point is a specific P05 precondition.

## Criteria the chosen editor must meet
- License MIT/BSD/Apache (ADR-0018); not AGPL.
- Block/structured model compatible with the `Block`/`DocumentRevision` design.
- Deterministic serialization for revision storage and sync (per-type keep-both, ADR-0015).
- Undo/redo; custom blocks/embeds; selection integration with `SelectionAdapter`.
- Acceptable performance on large documents; Windows + Android.

## Consequences
- Pro: no AGPL risk; a concrete leading candidate; a bounded decision point.
- Con: the final pick waits for the P05 spike; acceptable because Documents are P05, not MVP.
- If super_editor fails the spike, flutter_quill (MIT) or a custom editor are the fallbacks, both ADR-0018-compliant.

## Follow-ups
- Spike S-07 at P05 start; record the result and finalize the dependency with its license in verified-sources.
