# License map

| Component | Governing terms | Included notice |
| --- | --- | --- |
| Modified OptiScaler source | GPL version 3; preserve the upstream license and file notices | COPYING; source/OptiScaler/LICENSE |
| NSS SDK code and local extensions | MIT unless a file/component specifies otherwise | source/NSS/LICENSES/MIT.txt; original file notices |
| AMD FidelityFX components / analytic optical flow | MIT; retain AMD notices | original source notices and LICENSES trees |
| SPIRV-Tools / SPIRV-Headers / SPIRV-Cross / model parser libraries | Component-specific upstream terms, including Apache-2.0 and MIT | LICENSES/NSS and restored dependency notices |
| ImGui, Detours, Hack, NVAPI, Streamline headers, SimpleIni, spdlog/fmt, unordered_dense, nlohmann/json | Their original license texts, commonly MIT with component-specific additions | LICENSES/OptiScaler plus named notice files |
| FreeType | FreeType License / GPLv2 alternatives; preserve attribution and notices for the chosen distribution | FreeType-FTL.TXT and FreeType-GPLv2.TXT |
| Intel XeSS, DirectX Agility and other SDK components | Their own upstream SDK terms | LICENSES/OptiScaler and component directories |
| NVIDIA NGX SDK proprietary headers and DLSS runtime/model DLLs | Separate NVIDIA terms; not re-licensed by this repository | Excluded from this source/release bundle |

The top-level GPL copy applies to the OptiScaler integration. It does not erase the original licenses of separately supplied components. Preserve all notices and provide matching source/build instructions when distributing GPL-covered binaries.

NSS upstream documentation is not uniformly MIT: its README mentions a CC-BY-ND documentation license, while the supplied CC-BY text has a different name. The Developer Guide has been omitted from this repack; original README and notices are retained without changing their terms.

Embedded/exported neural weights and generated headers retain their source provenance. This package does not grant rights to the training datasets, game assets or third-party research checkpoints; those are not included. Research-reference notices are retained where found and do not imply every referenced implementation was incorporated.
