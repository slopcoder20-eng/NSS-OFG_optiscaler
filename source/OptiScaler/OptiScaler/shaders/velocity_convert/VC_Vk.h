#pragma once
#include <pch.h>
#include <shaders/Shader_Vk.h>

class VelocityConvert_Vk : public Shader_Vk
{
    uint32_t InNumThreadsX = 16;
    uint32_t InNumThreadsY = 16;

  public:
    VelocityConvert_Vk(std::string InName, VkDevice InDevice, VkPhysicalDevice InPhysicalDevice);
    ~VelocityConvert_Vk() = default;

                                                                                    
                                                       
    bool Dispatch(VkCommandBuffer InCmdList, VkImageView InResourceView, VkExtent2D InExtent);
};
