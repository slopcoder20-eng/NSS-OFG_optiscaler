# OptiScaler with NFRU / OFG

A modified OptiScaler integration for NFRU frame interpolation and experimental OFG neural optical flow. NFRU supports up to 4x total output (the real frame plus up to three generated frames). OFG is experimental and currently uses the Vulkan path.

## Installation

The binary package follows the upstream OptiScaler layout:

```
OptiScaler.dll
OptiScaler.ini
setup_windows.bat
setup_linux.sh
OptiScaler/                 # providers and runtime dependencies
Licenses/                   # upstream and project notices
README.md
```

Extract the complete binary package, preserve your existing installation/configuration, and follow the upstream setup procedure for your game. The setup/fetch scripts are supplied for users to run explicitly; extraction does not run them. Additional input bridges may be needed by the game. Use the matching source archive for the modified binaries. There are no example INI files: use the included standard OptiScaler.ini and configure the menu for your game.

For native DX12 NFRU, select a compatible Streamline DLSSG or FSR 3.1 input and `NFRU (Beta)` as FG Output. Choose 2x, 3x or 4x in NFRU Output Multiplier. Provider/input changes require a restart; native multiplier changes apply at a real-frame boundary. Insert toggles the menu. While the menu is open, native interpolation is temporarily paused.

`Handshake` means the public scheduled-presentation path initialized after the actual adapter's WDDM HwFlipQueueEnabled query. Disabled/unavailable WDDM state or initialization/format failure selects `CPU fallback`. The label alone does not prove per-frame HWFQ or Advanced HWFQ use. Vulkan retains its CPU presentation policy.

The native overlay reports **Submitted FPS (output/base)** from independent output-submission and real-frame counters. It does not divide real FPS by a requested multiplier. These are API submission rates, not monitor scanout rates; queued presents may be superseded by the low-latency scheduling policy. The frame-time graph remains a base-frame graph for this route.

## Source and build

The source archive contains `source/OptiScaler` (GPLv3 integration), `source/NSS` (MIT code with component-specific exceptions), active custom model/training code under `source/NSS/mlof2`, build/restore helpers and reusable test code. The license-grouped source archive is an inspection index; build from source.zip to preserve paths. Ordinary code comments are removed from public copies; required copyright/license notices and runtime strings remain.

Requirements include Windows x64, Visual Studio C++ tools, Windows SDK, CMake, Python, Git and Vulkan SDK. In the source checkout, use `tools/restore_build_inputs.ps1` to retrieve dependencies at recorded upstream revisions, then `tools/build.ps1 -Component OptiScaler`, `Vulkan` or `D3D12`. Obtain proprietary NGX SDK headers separately under NVIDIA's terms; they are not included or downloaded by the restore helper. Use a checkout path without spaces for the inherited native DX12 build script.

Local benchmark results, test-run logs and machine-specific validation reports are not distributed. Users should build, inspect and test compatibility and performance themselves. Reusable test sources are provided without bundled results.

## Software licenses

OptiScaler modifications are GPLv3. NSS and individual dependencies retain their own licenses, including MIT, Apache-2.0 and other component-specific terms. The upstream runtime DLLs supplied from the OptiScaler 2026-10-29 package retain their own SDK licenses. See the included license map/notices and original per-file notices. No code or data is re-licensed merely by inclusion in this package.

## Training data, licenses and rights holders

The custom OF/OFT/Fuse training workflow uses the sources below. This table does not describe the undisclosed training history of upstream Arm NFRU or AMD/Intel/NVIDIA models. Dataset rights are separate from the source-code licenses.

| Source | Rights holders / attribution | Applicable terms |
| --- | --- | --- |
| [Spring dataset](https://doi.org/10.18419/darus-3376) | Lukas Mehl, Jenny Schmalfuss, Azin Jahedi, Yaroslava Nalivayko and Andres Bruhn; University of Stuttgart | [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/), as stated by the dataset repository. Credit the authors and dataset DOI. |
| [Spring movie assets](https://studio.blender.org/films/spring/) underlying the Spring renders | Blender Foundation / Blender Studio and the credited Spring artists, including Andy Goralczyk and Francesco Siddi | CC BY 4.0 for the movie assets, as identified by the Spring dataset authors. |
| [Lyra Starter Game](https://www.fab.com/listings/93faede1-4434-47c0-85f1-bf27c0820ad0) rendered captures | Epic Games, Inc. and applicable third-party contributors | Epic sample-content terms, including the [Epic Content License Agreement](https://www.unrealengine.com/eula/content) where applicable, and the acquisition-specific Fab/content terms. UE-only designations and content-specific restrictions remain applicable. This is not MIT-licensed training content. |
| [Electric Dreams Environment](https://www.unrealengine.com/electric-dreams-environment) / forest rendered captures | Epic Games, Inc., Quixel and applicable asset contributors | Applicable Epic Content License Agreement / Fab acquisition terms, including content-specific and Megascans terms where relevant. Preserve UE-only and NoAI/AI-use restrictions where marked. This project does not re-license the assets. |

The active custom loaders configure Spring, Lyra at 1.5x/1.7x and Electric Dreams forest captures at 1.5x. A training run can select a subset. No raw dataset, captured frame, UE project, map asset, UE engine source or capture plugin is included. The source license does not grant rights to these materials or establish that a trained model is permitted under every acquisition-time content term. The architectural use of flow/mask/weight predictions is not a legal exemption from those terms.

Frozen training-time references include SEA-RAFT (upstream code: BSD-3-Clause) and RIFE (the referenced upstream code: MIT). Checkpoint/weight permissions must be checked separately from their code licenses. Upstream notices are preserved in `LICENSES/research_references` in the source archive and `Licenses/project/research_references` in the binary package. Teacher checkpoints are not included.

## Rights-holder removal policy

If a person or company that owns rights to training data or related content requests removal, the maintainers will take down the affected model files and releases from the distribution channels they control, and will take down the repository where necessary to honor that request. Rights holders may contact the maintainers through the repository or their GitHub contact information. This commitment does not replace license compliance or grant permission to use someone else's content.

## LLM assistance

A substantial portion of this project's custom code and modifications was written with assistance from large language models (LLMs). This statement concerns project-specific work; upstream projects retain their original authorship, copyright and license notices. Review the code and test it independently on your own hardware and games.
