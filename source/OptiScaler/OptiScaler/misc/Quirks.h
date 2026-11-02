#pragma once

#include "SysUtils.h"

#include <flag-set-cpp/flag_set.hpp>

                                                      
                                                                              
enum class GameQuirk : uint64_t
{
    CyberpunkHudlessState,
    FSRFGHudlessMismatchFixup,                                                                         
    SkipFsr3Method,
    FastFeatureReset,
    LoadD3D12Manually,
    LoadVulkanManually,
    KernelBaseHooks,
    VulkanDLSSBarrierFixup,
    ForceUnrealEngine,
    NoFSRFGFirstSwapchain,
    FixSlSimulationMarkers,
    HitmanReflexHacks,
    SkipD3D11FeatureLevelElevation,
    CreateD3D12DeviceForLuma,
    ForceCreateD3D12Device,
    ForceDepthD32S8,
    PregmataFixDLSSModes,
    IgnoreValidUntilEvaluateForFG,
    IgnoreTagsWithoutHudlessForFG,
    ForceFGRenderSizeMVs,
    CreateSLOnThe2ndDevice,
    XeFGCameraMotionFill,                                                                                      
    DLSSGFrameLatencyWaitable,                                                                        
    HideFsr4,                                                                                             
                                                       
    _
};
