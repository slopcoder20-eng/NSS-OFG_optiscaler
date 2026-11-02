#pragma once
#include "SysUtils.h"
#include <NVNGX_Parameter.h>
#include <upscalers/IFeature_Vk.h>

#include <nvsdk_ngx_vk.h>

                                                             
class UpscalerInputsVk
{
  public:
    static void UpscaleStart(VkCommandBuffer cmdBuffer, NVSDK_NGX_Parameter* parameters, IFeature_Vk* feature);
                                                                             
    static void UpscaleEnd(VkCommandBuffer cmdBuffer, const NVSDK_NGX_Resource_VK* output);
};
