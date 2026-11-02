# Training-data disclosure

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

Models predict flow, masks or blend weights; shaders sample and blend input pixels. Obtain all training data separately under the applicable terms and configure the training loaders for your own machine.
