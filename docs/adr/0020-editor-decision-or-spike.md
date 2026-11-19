# ADR-0020: Block editor — MIT/BSD-licensed, final pick via a short P05 spike

- Status: Accepted (direction decided; final library confirmed by a dated P05 spike). **Amended 2026-11-04 by S-07: flutter_quill 11.6.0** (below).
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

## Amendment: the S-07 result (P05, 2026-11-04)
- Status: the final library is **flutter_quill 11.6.0 (MIT, VS-29)**, pinned. The leading candidate super_editor was not chosen.
- Why: in the owner's test on both platforms ([spike-results.md](../spikes/spike-results.md) S-07), super_editor (0.3.0-dev.52, the only current release) still lagged when scrolling and typing on Android in a profile build, shook while scrolling on Windows, and misaligned its to-do boxes on Android; it also needs an Android build workaround and has had no stable release since 2024. flutter_quill was smooth on both and the owner judged it fit for daily use.
- What the Delta model changes: nothing in storage. The documents are stored in LifeFlow's own block format (deterministic serialization, the criterion above), and the editor is reached only through an adapter. Block ids are kept by the adapter by line position and are not promised stable across edits; P05a has no block-level links. An image block is always followed by a text line so the cursor has a place after it.
- The criteria above stay as written; super_editor (or a custom editor) remains the fallback behind the same adapter if flutter_quill stops being maintained.
