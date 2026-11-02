#include "ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf.h"
#include "ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991.h"
#include "ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e.h"
#include "ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453.h"

typedef union ffx_frameinterpolation_10_warp_flow_pass_PermutationKey {
    struct {
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_ENABLE_DATA_GRAPH_FI : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_DEPTH : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS : 1;
        uint32_t FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_COLOR : 1;
    };
    uint32_t index;
} ffx_frameinterpolation_10_warp_flow_pass_PermutationKey;

typedef struct ffx_frameinterpolation_10_warp_flow_pass_PermutationInfo {
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
} ffx_frameinterpolation_10_warp_flow_pass_PermutationInfo;

static const uint32_t g_ffx_frameinterpolation_10_warp_flow_pass_IndirectionTable[] = {
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
    2,
    0,
    2,
    0,
};

static const ffx_frameinterpolation_10_warp_flow_pass_PermutationInfo g_ffx_frameinterpolation_10_warp_flow_pass_PermutationInfo[] = {
    { g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_size, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_data, 1, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_CBVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_CBVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_CBVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_CBVResourceSets, 4, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureSRVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureSRVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureSRVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureSRVResourceSets, 5, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_TextureUAVResourceSets, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_BufferUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_BufferUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_BufferUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_d3471bd369767622fa6e15eef4ef0ebf_BufferUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_size, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_data, 1, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_CBVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_CBVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_CBVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_CBVResourceSets, 4, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureSRVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureSRVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureSRVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureSRVResourceSets, 4, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_TextureUAVResourceSets, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_BufferUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_BufferUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_BufferUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_9be2d4142b0abb31609a57bc3e5f7991_BufferUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_size, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_data, 1, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_CBVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_CBVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_CBVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_CBVResourceSets, 4, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureSRVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureSRVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureSRVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureSRVResourceSets, 5, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_TextureUAVResourceSets, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_BufferUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_BufferUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_BufferUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_bbaab9d7730d7f9c6d1ee9db5162ac3e_BufferUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
    { g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_size, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_data, 1, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_CBVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_CBVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_CBVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_CBVResourceSets, 4, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureSRVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureSRVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureSRVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureSRVResourceSets, 4, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_TextureUAVResourceSets, 0, 0, 0, 0, 0, 1, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_BufferUAVResourceNames, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_BufferUAVResourceBindings, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_BufferUAVResourceCounts, g_ffx_frameinterpolation_10_warp_flow_pass_085cf0fd9c8c9cd4bdf29852821c4453_BufferUAVResourceSets, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
};

