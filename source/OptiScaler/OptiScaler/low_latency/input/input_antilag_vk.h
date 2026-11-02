#pragma once

#include "input_common.h"

#include <vulkan/vulkan.h>

                                                                                           
class InputAntiLagVk
{
                                                                                                                 
    const static inline InputContext inputContext { .caller = LowLatencyInput::AntiLag2,
                                                    .noFrameId = false,
                                                    .markerMode = InputMarkerMode::SimStartAndPresentStart,
                                                    .api = API::Vulkan };

                                                                              
    const static inline InputContext noFrameIdContext { .caller = LowLatencyInput::AntiLag2,
                                                        .noFrameId = true,
                                                        .markerMode = InputMarkerMode::SimStartOnly,
                                                        .api = API::Vulkan };

  public:
    static void VKAPI_CALL AntiLagUpdate(VkDevice device, const VkAntiLagDataAMD* pData);
};
