                                                    
#pragma once
#include <stdint.h>

#define MLOF2_FUSE_NUM_TENSORS 8
#define MLOF2_FUSE_NUM_SEGS 7
#define MLOF2_FUSE_NUM_OPS 7
#define MLOF2_FUSE_ARENA_UNITS 4096
static const uint32_t MLOF2_FUSE_BLOB_WORDS = 15168u;

static const Mlof2Tensor g_mlof2_fuse_tensors[] = {
    {21, 2, 1, 0u, 2, 32, 3.14960630e-02f},               
    {16, 4, 1, 64u, 2, 16, 2.98052022e-02f},                 
    {32, 8, 1, 128u, 2, 32, 4.20332180e-02f},                 
    {32, 8, 1, 192u, 2, 32, 1.46386830e-02f},              
    {32, 8, 1, 256u, 2, 32, 4.46732213e-02f},              
    {32, 8, 1, 320u, 2, 32, 2.00749232e-02f},              
    {32, 8, 1, 384u, 2, 32, 4.92390009e-02f},              
    {48, 8, 1, 448u, 1, 96, 1.00000000e+00f},                        
};

static const Mlof2Seg g_mlof2_fuse_segs[] = {
    {0, 0, 21, 0},       
    {1, 0, 16, 0},       
    {2, 0, 32, 0},       
    {3, 0, 32, 0},       
    {4, 0, 32, 0},       
    {5, 0, 32, 0},       
    {6, 0, 32, 0},       
};

static const Mlof2Op g_mlof2_fuse_ops[] = {
    {0, 1, 0, 16, 0, 1, {3, 3, 2, 1, 1, 1, -1, 0}, {3.175000e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 0u, 54u, 864u, 880u},       
    {0, 2, 0, 32, 1, 1, {3, 3, 2, 1, 1, 1, -1, 0}, {3.355119e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 896u, 36u, 2048u, 2080u},       
    {0, 3, 0, 32, 2, 1, {3, 3, 1, 1, 1, 1, -1, 0}, {2.379071e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 2112u, 72u, 4416u, 4448u},       
    {0, 4, 0, 32, 3, 1, {3, 3, 1, 1, 1, 0, 2, 0}, {6.831216e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 4480u, 72u, 6784u, 6816u},       
    {0, 5, 0, 32, 4, 1, {3, 3, 1, 1, 1, 1, -1, 0}, {2.238477e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 6848u, 72u, 9152u, 9184u},       
    {0, 6, 0, 32, 5, 1, {3, 3, 1, 1, 1, 1, 4, -1}, {4.981339e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 9216u, 72u, 11520u, 11552u},       
    {0, 7, 0, 48, 6, 1, {3, 3, 1, 1, 1, 0, -1, 0}, {2.030910e+01f, 0.000000e+00f, 0.000000e+00f, 0.000000e+00f}, 11584u, 72u, 15040u, 15088u},       
};

static const int g_mlof2_fuse_io[] = {0, 7};
static const char* const g_mlof2_fuse_io_names[] = {"fuse_in", "fuse_logits_s8_7"};

static const Mlof2Graph g_mlof2_fuse_graph = {
    g_mlof2_fuse_tensors, 8,
    g_mlof2_fuse_segs, 7,
    g_mlof2_fuse_ops, 7,
    15168u, 4096u, "mlof2_fuse.bin",
    g_mlof2_fuse_io, g_mlof2_fuse_io_names, 1, 1,
    2
};
