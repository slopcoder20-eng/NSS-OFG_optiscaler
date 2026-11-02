# Third-party licenses (reference / possible teacher models)

Fetched 2026-10-16 from each repository's LICENSE (GitHub API) and the Hugging Face model cards.
Used so far: ideas only (papers cited in the code). Nothing copied yet. If code or weights get used,
keep the matching file here and the copyright notice in the source.

| Project | Repository | License | File |
|---|---|---|---|
| RAFT | github.com/princeton-vl/RAFT | BSD-3-Clause, (c) 2020 princeton-vl | princeton-vl_RAFT.LICENSE.txt |
| SEA-RAFT | github.com/princeton-vl/SEA-RAFT | BSD-3-Clause, (c) 2024 Princeton Vision & Learning Lab | princeton-vl_SEA-RAFT.LICENSE.txt |
| NeuFlow v2 | github.com/neufieldrobotics/NeuFlow_v2 | Apache-2.0 | neufieldrobotics_NeuFlow_v2.LICENSE.txt |
| UniMatch / GMFlow | github.com/autonomousvision/unimatch | MIT, (c) 2022 autonomousvision | autonomousvision_unimatch.LICENSE.txt |
| ARFlow | github.com/lliuz/ARFlow | MIT, (c) 2020 Liang Liu | lliuz_ARFlow.LICENSE.txt |
| IFRNet | github.com/ltkong218/IFRNet | MIT, (c) 2022 Lingtong Kong | ltkong218_IFRNet.LICENSE.txt |
| RIFE | github.com/hzwer/ECCV2022-RIFE | MIT, (c) Megvii Inc. | hzwer_ECCV2022-RIFE.LICENSE.txt |
| UFlow / SMURF | github.com/google-research/google-research | Apache-2.0 | google-research_google-research.LICENSE.txt |

Pretrained weights (Hugging Face license tag):
- SEA-RAFT: MemorySlices/Tartan-C-T-TSKH-spring540x960-M and -S: bsd-3-clause
- NeuFlow v2: Study-is-happy/neuflow-v2: apache-2.0

Note: the weights were trained on public datasets with their own terms (SEA-RAFT: TartanAir, FlyingChairs,
FlyingThings3D, Sintel, KITTI, HD1K, Spring; NeuFlow v2: FlyingThings3D). FlyingChairs is "research purposes
only, commercial use prohibited" (official Freiburg page). The weights themselves are released under the
licenses above.
