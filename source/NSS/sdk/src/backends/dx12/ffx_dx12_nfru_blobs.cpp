                                                                                                                   
                                                                                                                           
                                                                                                                          
                                                                                                                              
#include <FidelityFX/host/ffx_util.h>
#include "ffx_shader_blobs.h"
#include <FidelityFX/host/ffx_frameinterpolation.h>
#include <FidelityFX/host/ffx_opticalflow.h>
#include "frameinterpolation/ffx_frameinterpolation_private.h"
#include "opticalflow/ffx_opticalflow_private.h"
#include <nfru_v1_int8.h>
#include <string.h>

#include <ffx_frameinterpolation_00_init_warp_pass_permutations.h>
#include <ffx_frameinterpolation_10_warp_flow_pass_permutations.h>
#include <ffx_frameinterpolation_11_warp_flow_tm1_pass_permutations.h>
#include <ffx_frameinterpolation_20_fill_holes_pass_permutations.h>
#include <ffx_frameinterpolation_21_fill_holes_tm1_pass_permutations.h>
#include <ffx_frameinterpolation_30_preprocess_pass_permutations.h>
#include <ffx_frameinterpolation_50_postprocess_pass_permutations.h>
#include <ffx_frameinterpolation_debug_view_pass_permutations.h>
#include <ffx_opticalflow_mv_hints_permutations.h>

#define FI_KEY(options, key)                                                                                                                  \
    key.index                                                    = 0;                                                                        \
    key.FFX_ARM_FRAMEINTERPOLATION_OPTION_LOW_RES_MOTION_VECTORS = FFX_CONTAINS_FLAG(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_LOW_RES_MOTION_VECTORS); \
    key.FFX_ARM_FRAMEINTERPOLATION_OPTION_JITTER_MOTION_VECTORS  = FFX_CONTAINS_FLAG(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_JITTER_MOTION_VECTORS);  \
    key.FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH         = FFX_CONTAINS_FLAG(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_DEPTH_INVERTED);         \
    key.FFX_ARM_FRAMEINTERPOLATION_OPTION_ENABLE_DATA_GRAPH_FI   = FFX_CONTAINS_FLAG(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_ENABLE_DATA_GRAPH_FI);   \
    key.FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_DEPTH  = FFX_CONTAINS_FLAG(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_MANAGE_PREVIOUS_DEPTH);  \
    key.FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_COLOR  = FFX_CONTAINS_FLAG(options, FRAMEINTERPOLATION_SHADER_PERMUTATION_MANAGE_PREVIOUS_COLOR);

#define FI_BLOB(pass)                                                         \
    {                                                                         \
        pass##_PermutationKey key;                                            \
        FI_KEY(permutationOptions, key);                                      \
        const int32_t tableIndex = g_##pass##_IndirectionTable[key.index];    \
        FfxShaderBlob blob = POPULATE_SHADER_BLOB_FFX(g_##pass##_PermutationInfo, tableIndex); \
        memcpy(outBlob, &blob, sizeof(FfxShaderBlob));                        \
        return FFX_OK;                                                        \
    }

static FfxErrorCode frameInterpolationBlobDX12(FfxFrameInterpolationPass passId, uint32_t permutationOptions, FfxShaderBlob* outBlob,
                                               FfxDataGraphBlob* outDataGraphBlob)
{
    switch (passId)
    {
    case FFX_FRAMEINTERPOLATION_PASS_INIT_WARP: FI_BLOB(ffx_frameinterpolation_00_init_warp_pass)
    case FFX_FRAMEINTERPOLATION_PASS_WARP_MV_TP1: FI_BLOB(ffx_frameinterpolation_10_warp_flow_pass)
    case FFX_FRAMEINTERPOLATION_PASS_WARP_FLOW_TM1: FI_BLOB(ffx_frameinterpolation_11_warp_flow_tm1_pass)
    case FFX_FRAMEINTERPOLATION_PASS_FILL_HOLES_TP1: FI_BLOB(ffx_frameinterpolation_20_fill_holes_pass)
    case FFX_FRAMEINTERPOLATION_PASS_FILL_HOLES_TM1: FI_BLOB(ffx_frameinterpolation_21_fill_holes_tm1_pass)
    case FFX_FRAMEINTERPOLATION_PASS_PREPROCESS: FI_BLOB(ffx_frameinterpolation_30_preprocess_pass)
    case FFX_FRAMEINTERPOLATION_PASS_POSTPROCESS: FI_BLOB(ffx_frameinterpolation_50_postprocess_pass)
    case FFX_FRAMEINTERPOLATION_PASS_DEBUG_VIEW: FI_BLOB(ffx_frameinterpolation_debug_view_pass)
    case FFX_FRAMEINTERPOLATION_PASS_NFRU_INTERPOLATION:
        memcpy(outDataGraphBlob, &g_nfru_v1_int8_Info, sizeof(FfxDataGraphBlob));
        return FFX_OK;
    default:
                                                                                                                    
        if (outBlob) memset(outBlob, 0, sizeof(FfxShaderBlob));
        return FFX_ERROR_INVALID_ARGUMENT;
    }
}

static FfxErrorCode opticalFlowBlobDX12(FfxOpticalflowPass passId, uint32_t permutationOptions, FfxShaderBlob* outBlob)
{
    if (passId != FFX_OPTICALFLOW_PASS_COMPUTE_MOTION_FROM_DEPTH)
    {
        if (outBlob) memset(outBlob, 0, sizeof(FfxShaderBlob));
        return FFX_ERROR_INVALID_ARGUMENT;
    }
    ffx_opticalflow_mv_hints_PermutationKey key;
    key.index = 0;
    key.DEPTH_INVERTED = FFX_CONTAINS_FLAG(permutationOptions, OPTICALFLOW_SHADER_PERMUTATION_DEPTH_INVERTED);
    const int32_t tableIndex = g_ffx_opticalflow_mv_hints_IndirectionTable[key.index];
    FfxShaderBlob blob = POPULATE_SHADER_BLOB_FFX(g_ffx_opticalflow_mv_hints_PermutationInfo, tableIndex);
    memcpy(outBlob, &blob, sizeof(FfxShaderBlob));
    return FFX_OK;
}

FfxErrorCode ffxGetPermutationBlobByIndex(FfxEffect effectId, FfxPass passId, uint32_t permutationOptions, FfxShaderBlob* outBlob,
                                          FfxShaderBlob* outVertBlob, FfxDataGraphBlob* outDataGraphBlob)
{
    if (outVertBlob) memset(outVertBlob, 0, sizeof(FfxShaderBlob));
    switch (effectId)
    {
    case ARM_EFFECT_FRAMEINTERPOLATION:
        return frameInterpolationBlobDX12((FfxFrameInterpolationPass) passId, permutationOptions, outBlob, outDataGraphBlob);
    case ARM_EFFECT_OPTICALFLOW:
        return opticalFlowBlobDX12((FfxOpticalflowPass) passId, permutationOptions, outBlob);
    default:
        if (outBlob) memset(outBlob, 0, sizeof(FfxShaderBlob));
        return FFX_ERROR_INVALID_ARGUMENT;
    }
}

FfxErrorCode ffxIsWave64(FfxEffect, uint32_t, bool& isWave64)
{
    isWave64 = false;
    return FFX_OK;
}
