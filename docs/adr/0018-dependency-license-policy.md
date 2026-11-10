# ADR-0018: Dependency license policy

- Status: Accepted (owner decision); amended by ADR-0035 (rule 7, 2026-11-10)
- Date: 2026-11-04
- Deciders: Project owner
- Evidence: [../security/security-requirements.md](../security/security-requirements.md) SR-16/SR-17; [../research/verified-sources.md](../research/verified-sources.md); brief section 22 (license claims must be verified)

## Context
LifeFlow is intended as a potentially closed-source, distributable app. Copyleft licenses (especially AGPL) can impose source-disclosure obligations incompatible with that. The owner set an explicit policy for the MVP tech stack and asked that every stack choice in Batch 3c carry its license and a reason.

## Decision
1. **Excluded for the MVP: AGPL** (any version). Not used for direct or important transitive dependencies.
2. **Accepted: MIT, Apache-2.0, BSD (2/3-clause), MPL-2.0.** MPL-2.0 is accepted with its condition noted: modifications to MPL-licensed *files* must be shared, but it does not impose whole-app copyleft; keep MPL components as separate files/modules and do not copy their code into proprietary files.
3. **LGPL: only if there is no equivalent alternative**, and only with a documented compliance method (dynamic linking or user-replaceability of the LGPL component). Each such use is recorded in an ADR or in verified-sources with the compliance approach.
4. **Unknown or unverified license: default reject.** A dependency with an unknown license is not adopted, not even temporarily. It may be adopted only after its license is verified against an official source and recorded. There is no "use now, check later".
5. **Scope:** applies to direct dependencies and to important transitive dependencies (those that materially affect distribution). Each chosen library in technical-stack.md lists its license and an accept/reject reason, cross-referenced to a `VS-*` row in verified-sources.
6. **Enforcement:** adding a dependency requires a verified-sources row; a review step and the CI license scan **FF-ARCH-07** (`tools/fitness/ff_arch_07_licenses.dart`, since P02) flag any license outside rule 2 before merge (ties to SR-16/SR-17).
7. **GPL-2.0 with the Classpath Exception: only for `com.android.tools:desugar_jdk_libs`** (Android desugaring), used unmodified, with its notices shipped in the app. Added by [ADR-0035](0035-gpl-classpath-exception-for-android-desugaring.md) (owner decision 2026-11-10). Any other GPL dependency needs its own decision.

## Consequences
- Pro: avoids an AGPL obligation reaching the shippable app; keeps the distribution options open.
- Pro: "default reject unknown" prevents accidental adoption of a copyleft or unlicensed package.
- Con: some capable libraries are off-limits (for example AppFlowy Editor, AGPL-3.0/MPL-2.0 dual license — the AGPL option is excluded; the MPL option is acceptable only under the MPL condition, which for an editor pulling in many files is awkward — see ADR-0020).
- Con: verifying transitive licenses was manual until P02; since then FF-ARCH-07 checks every shipped package and Android library in CI against a reviewed inventory (ADR-0035).

## Follow-ups
- technical-stack.md: every row carries a license + reason + `VS-*`.
- ADR-0020 (editor) applies this policy: prefer an MIT/BSD/Apache editor over an AGPL/MPL one.
- Batch 4: a license-scan fitness function if the toolchain supports it. **Done in P02 (FF-ARCH-07, ADR-0035).**
