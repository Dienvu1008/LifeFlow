# ADR-0075: The permissive licenses bundled in PDFium

- Status: Accepted (owner decision, 2026-11-04; P05b D10, after spike S-08)
- Date: 2026-11-04
- Deciders: Project owner
- Amends: [ADR-0018](0018-dependency-license-policy.md) (adds rule 8)
- Related: [ADR-0035](0035-gpl-classpath-exception-for-android-desugaring.md) (the same kind of decision, L-1), [p05b-plan.md](../roadmap/p05b-plan.md) D10, [spike-results.md](../spikes/spike-results.md) S-08, risks R-VIEWER-LICENSE and R-LICENSE-SCAN

## Context
P05b shows PDFs with `pdfrx` (MIT). pdfrx uses PDFium, which its build hook (`pdfium_dart`) downloads as a prebuilt binary: `bblanchon/pdfium-binaries`, release `chromium/8125`, checked against pinned SHA-256 hashes. PDFium itself is BSD-3-Clause. The binary also contains third-party libraries, whose licenses ship in the archive's `licenses/` folder. S-08 read them all (2026-11-04). None is copyleft. Many are already accepted by ADR-0018 rule 2:
- Apache-2.0: abseil, highway, and llvm-libc (Apache-2.0 WITH LLVM-exception);
- MIT: fast_float, simdutf, Little CMS;
- "Old MIT": HarfBuzz;
- BSD-2-Clause: OpenJPEG;
- dragonbox: Apache-2.0 WITH LLVM-exception or BSL-1.0, the choice is ours.
- Found in T1, in the Android archives only (S-08 read the Windows one): catapult (BSD-3-Clause), cpu_features (Apache-2.0), libunwind (Apache-2.0 WITH LLVM-exception, as llvm-libc). All are already accepted, so this decision does not change.

Six licenses are not in rule 2's list:
- **FTL** (FreeType Project License; FreeType is FTL or GPL-2.0, the choice is ours): permissive, with a credit in the documentation.
- **IJG** (libjpeg-turbo, also BSD-3-Clause for its other parts): permissive, with a credit.
- **libpng License v2**: permissive.
- **zlib License**: permissive.
- **Unicode License v3** (ICU data): permissive.
- **Anti-Grain Geometry 2.3**: a short permissive notice.

## Decision
1. **ADR-0018 rule 8:** these six licenses are accepted **for the libraries bundled in the PDFium binary that pdfrx uses**, on these conditions:
   - **Only the FTL option of FreeType**; never its GPL option.
   - **The binary is used as it is published, at a pinned release with its hash.** Nothing is modified, and no code from it is copied into LifeFlow files.
   - **Every notice ships with the app.** The texts from the archive's `licenses/` folder, unchanged, are shown under Settings → Open-source licenses, together with the credit lines that FTL and IJG ask for:
     - "Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved."
     - "This software is based in part on the work of the Independent JPEG Group."
   - **A change of release means reading the licenses again.** A new PDFium release may bundle other libraries.
   - Any other use of these licenses still needs its own decision.
2. **How it is enforced** (P05b T1, when pdfrx enters the app):
   - The notices are taken from the pinned archive by a script that checks its hash, as for desugar_jdk_libs (ADR-0035). They are stored in the app's assets and added to Flutter's license registry at startup.
   - FF-ARCH-07 already checks the pub packages (pdfrx, pdfium_dart, pdfium_flutter: MIT). It also checks that the PDFium notices are present and match the pinned release.

## Consequences
- In-app PDF viewing is possible on Windows and Android with an engine that renders well (S-08: 300 pages opened in 0.17 s, Vietnamese text extracted correctly).
- The licenses page lists about 20 more notices. The app grows by 7.2 MB on Windows and about 6 MB per Android device.
- No license here limits a commercial, closed-source release. This is an engineering reading of the licenses, not legal advice (as in ADR-0035).

## Verification
- S-08: every file of the archive's `licenses/` folder was read and its license named (spike-results.md).
- T1 adds the notices, their check in FF-ARCH-07, and a test that the licenses page lists them.
