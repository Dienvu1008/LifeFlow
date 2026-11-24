# ADR-0084: The licenses bundled in the llama.cpp runtime

- Status: **Proposed (P06 T4, 2026-11-04): the owner's decision is needed** (as for ADR-0075)
- Date: 2026-11-04
- Deciders: Project owner
- Amends (when accepted): [ADR-0018](0018-dependency-license-policy.md) (adds rule 9)
- Related: [ADR-0075](0075-pdfium-bundled-licenses.md) (the same kind of decision for PDFium), [ADR-0083](0083-local-model-engine.md), [verified-sources.md](../research/verified-sources.md) VS-51

## Context
The local models run on llama.cpp through `llamadart` (MIT). Its build hook downloads a prebuilt runtime, `leehack/llamadart-native` v1.0.0-4 (MIT), pinned by llamadart. The runtime is built from llama.cpp commit `b1b770d` (MIT, with ggml). The release carries no license files, so the agent read the sources at the commits it was built from, and the strings in the shipped libraries. What the app ships after the trimming in ADR-0083:

| Code | Where | License |
|---|---|---|
| llama.cpp, ggml, llama.cpp's own chat-template code | all libraries | MIT |
| llamadart-native's wrapper | `llamadart.dll` / `.so` | MIT |
| cpp-httplib, nlohmann json | `llama-common` | MIT |
| stb_image | `mtmd` | MIT **or** public domain (we take MIT) |
| miniaudio | `mtmd` | public domain (Unlicense) **or** MIT No Attribution (MIT-0) |
| sheredom `subprocess.h` | `llama-common`, `mtmd` | Unlicense (public domain) |
| Vulkan-Headers, SPIRV-Headers (headers used to build the Vulkan module) | `ggml-vulkan` (Windows) | Apache-2.0 or MIT; MIT-style (Khronos) |
| Microsoft Visual C++ runtime: `msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, `vcomp140.dll` | the Windows app folder, beside the runtime (so no Visual C++ Redistributable is needed) | Microsoft's terms for redistributable Visual C++ files |

Not shipped, so not part of this decision: OpenBLAS, CUDA, OpenCL and its ICD loader, LiteRT-LM, WebGPU/Dawn (all left out by the configuration of ADR-0083); OpenSSL (only named in a help string, not linked).

Most of the table is already accepted by ADR-0018 rule 2 (MIT, Apache-2.0, BSD). Two kinds are not:
- **Public-domain dedications (the Unlicense) and MIT-0**: miniaudio and subprocess.h. They are as permissive as a license can be: no conditions, not even a notice.
- **The Visual C++ runtime DLLs**: not an open-source license. Microsoft allows apps built with Visual Studio to ship these files beside the app, unmodified.

## Decision (proposed)
1. **ADR-0018 rule 9:** for the llama.cpp runtime that llamadart's build hook downloads, these are also accepted:
   - **public domain (Unlicense) and MIT-0**, for the code llama.cpp vendors (miniaudio, sheredom subprocess.h; for stb_image the MIT option is taken);
   - **the Microsoft Visual C++ runtime DLLs** that the runtime ships app-locally, used unmodified, under Microsoft's redistribution terms.
   
   The same conditions as ADR-0075 apply:
   - the runtime is used as published, at the release pinned by the locked llamadart version, unmodified, with no code copied into LifeFlow's files;
   - **every notice ships with the app**, unchanged, under Settings → Open-source licenses;
   - **a new llamadart version means reading the licenses again**, because a new runtime may build in other code;
   - any other use of these licenses needs its own decision.
2. **How it is enforced** (P06 T4, done on the branch):
   - `tools/licenses/fetch_llamacpp_notices.ps1` takes each text from the source at the pinned commits (llama.cpp, the runtime, Vulkan-Headers, SPIRV-Headers). It writes them to `apps/lifeflow_app/assets/licenses/llamacpp/` with `SOURCE`, which records the release, the commit and each notice's SHA-256.
   - The app registers them on the licenses page, after a line naming the release.
   - FF-ARCH-07 fails when llamadart is shipped and `SOURCE` is missing, belongs to another llamadart version, lacks one of the named notices, or a listed file is missing. Its self-test covers each case.
   - `licenses_test.dart` checks that the notices are listed.

## Consequences
- The local engine can ship on Windows and Android with its notices. About 10 more entries appear on the licenses page.
- Nothing here limits a commercial, closed-source release. This is an engineering reading of the licenses, not legal advice (as in ADR-0035 and ADR-0075).
- If the owner declines, the choices are:
  - build a runtime without miniaudio and stb (llama.cpp's multimodal part, which LifeFlow does not use), from source, which means a C++ toolchain in the build;
  - or drop local models.
  
  The Visual C++ files could instead come from the installer as Microsoft's redistributable package.

## Verification
- Read 2026-11-04:
  - the llamadart-native and llama.cpp licenses;
  - llama.cpp's `vendor/` folder and the license blocks in each header;
  - the strings in the Windows libraries, which show httplib, nlohmann json, jinja and subprocess in `llama-common`, and stb_image and miniaudio in `mtmd`.
- The notices are in the app (`licenses_test.dart`); FF-ARCH-07 and its self-test are green.
