# MLOF2 shader build

GLSL shader sources are in shaders/. build_mlof2_shaders.py compiles the active kernels and generates mlof2_shaders_spv.h. The host/runtime headers select the graph and kernel for the requested backend.

Use the compiler/tool paths configured by the build script and keep generated graph/weight headers consistent with the runtime. The shipped generated headers can be consumed by the SDK build without re-exporting models. Training/model export and shader regeneration are separate authoring steps.

Run your own correctness and performance checks after changing kernels, tensor layouts or quantization contracts. No local benchmark results are included.
