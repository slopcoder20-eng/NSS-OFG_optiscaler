#include "ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3.h"
#include "ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2.h"
#include "ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d.h"
#include "ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b.h"

typedef union ffx_frameinterpolation_50_postprocess_pass_PermutationKey {
    struct {
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_ENABLE_DATA_GRAPH_FI : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_COLOR : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_DEPTH : 1;
    };
    uint32_t index;
} ffx_frameinterpolation_50_postprocess_pass_PermutationKey;

typedef struct ffx_frameinterpolation_50_postprocess_pass_PermutationInfo {
    const uint32_t       blobSize;
    const unsigned char* blobData;


    const uint32_t  numConstantBuffers;
    const char**    constantBufferNames;
    const uint32_t* constantBufferBindings;
    const uint32_t* constantBufferCounts;
    const uint32_t* constantBufferSpaces;

    const uint32_t  numSRVTextures;
    const char**    srvTextureNames;
    const uint32_t* srvTextureBindings;
    const uint32_t* srvTextureCounts;
    const uint32_t* srvTextureSpaces;

    const uint32_t  numUAVTextures;
    const char**    uavTextureNames;
    const uint32_t* uavTextureBindings;
    const uint32_t* uavTextureCounts;
    const uint32_t* uavTextureSpaces;

    const uint32_t  numSRVBuffers;
    const char**    srvBufferNames;
    const uint32_t* srvBufferBindings;
    const uint32_t* srvBufferCounts;
    const uint32_t* srvBufferSpaces;

    const uint32_t  numUAVBuffers;
    const char**    uavBufferNames;
    const uint32_t* uavBufferBindings;
    const uint32_t* uavBufferCounts;
    const uint32_t* uavBufferSpaces;

    const uint32_t  numSamplers;
    const char**    samplerNames;
    const uint32_t* samplerBindings;
    const uint32_t* samplerCounts;
    const uint32_t* samplerSpaces;

    const uint32_t  numRTAccelerationStructures;
    const char**    rtAccelerationStructureNames;
    const uint32_t* rtAccelerationStructureBindings;
    const uint32_t* rtAccelerationStructureCounts;
    const uint32_t* rtAccelerationStructureSpaces;

    const uint32_t  numRTTextures;
    const char**    rtTextureNames;
    const uint32_t* rtTextureBindings;
    const uint32_t* rtTextureCounts;
    const uint32_t* rtTextureSpaces;

    const uint32_t  numSRVTensors;
    const char**    srvTensorNames;
    const uint32_t* srvTensorBindings;
    const uint32_t* srvTensorCounts;
    const uint32_t* srvTensorSpaces;

    const uint32_t  numUAVTensors;
    const char**    uavTensorNames;
    const uint32_t* uavTensorBindings;
    const uint32_t* uavTensorCounts;
    const uint32_t* uavTensorSpaces;
} ffx_frameinterpolation_50_postprocess_pass_PermutationInfo;

static const uint32_t g_ffx_frameinterpolation_50_postprocess_pass_IndirectionTable[] = {
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
    2,
    0,
    2,
    0,
    3,
    1,
    3,
    1,
};

static const ffx_frameinterpolation_50_postprocess_pass_PermutationInfo g_ffx_frameinterpolation_50_postprocess_pass_PermutationInfo[] = {
    { g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_size, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_data, 1, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_CBVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_CBVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_CBVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_CBVResourceSets, 14, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureSRVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureSRVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureSRVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureSRVResourceSets, 1, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_TextureUAVResourceSets, 0, 0, 0, 0, 0, 2, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_BufferUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_BufferUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_BufferUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_BufferUAVResourceSets, 1, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_SamplerResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_SamplerResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_SamplerResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_4676829f3d694df78c684b44afd93de3_SamplerResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_size, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_data, 1, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_CBVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_CBVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_CBVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_CBVResourceSets, 14, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureSRVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureSRVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureSRVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureSRVResourceSets, 2, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_TextureUAVResourceSets, 0, 0, 0, 0, 0, 2, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_BufferUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_BufferUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_BufferUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_BufferUAVResourceSets, 1, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_SamplerResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_SamplerResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_SamplerResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_66fb796c6d13ab1d4a5cfd18aed392c2_SamplerResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_size, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_data, 1, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_CBVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_CBVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_CBVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_CBVResourceSets, 14, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureSRVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureSRVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureSRVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureSRVResourceSets, 1, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_TextureUAVResourceSets, 0, 0, 0, 0, 0, 2, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_BufferUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_BufferUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_BufferUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_BufferUAVResourceSets, 1, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_SamplerResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_SamplerResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_SamplerResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_6ac2959d7986a35f9cbc6ff5fdf85f6d_SamplerResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_size, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_data, 1, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_CBVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_CBVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_CBVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_CBVResourceSets, 14, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureSRVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureSRVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureSRVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureSRVResourceSets, 2, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_TextureUAVResourceSets, 0, 0, 0, 0, 0, 2, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_BufferUAVResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_BufferUAVResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_BufferUAVResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_BufferUAVResourceSets, 1, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_SamplerResourceNames, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_SamplerResourceBindings, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_SamplerResourceCounts, g_ffx_frameinterpolation_50_postprocess_pass_72d43c61977a889f8c1c80603bbc1f6b_SamplerResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
};

