#pragma once
#include "MenuBlur_Common.h"

#include <shaders/Shader_Vk.h>
#include <imgui/imgui.h>

                                                                   
class MenuBlur_Vk : public Shader_Vk, public MenuBlur_Common
{
  private:
    struct BlurImage
    {
        VkImage Image = VK_NULL_HANDLE;
        VkImageView View = VK_NULL_HANDLE;
        VkDeviceMemory Memory = VK_NULL_HANDLE;
    };

                                                                                   
    enum PassSet : uint32_t
    {
        DownsampleSet = 0,                  
        HorizontalSet,                        
        VerticalSet,                          
        PassSetCount
    };

    VkDescriptorSet _passSets[PassSetCount] = {};

                                                                        
    BlurImage _copy;
                                  
    BlurImage _blurA;
    BlurImage _blurB;

    VkExtent2D _extent {};
    VkFormat _swapchainFormat = VK_FORMAT_UNDEFINED;

                                         
    VkDescriptorSet _imguiTexture = VK_NULL_HANDLE;

                                                                 
    ImVec2 _uvScale { 1.0f, 1.0f };

    bool CreateImage(BlurImage& OutImage, uint32_t InWidth, uint32_t InHeight, VkFormat InFormat,
                     VkImageUsageFlags InUsage);
    void DestroyImage(BlurImage& InImage);
    void ReleaseImages();
    void DispatchPass(VkCommandBuffer InCmdBuffer, PassSet InSet, BlurMode InMode, float InSpacing);

    static void ComputeBarrier(VkCommandBuffer InCmdBuffer, VkPipelineStageFlags InDstStage, VkAccessFlags InDstAccess);

  public:
                                                                                                
    bool Prepare(VkFormat InFormat, VkExtent2D InExtent, VkImageUsageFlags InUsage);

                                                                                                              
    bool Dispatch(VkCommandBuffer InCmdBuffer, VkImage InSwapchainImage);

    ImTextureID TextureId() const { return (ImTextureID) _imguiTexture; }
    ImVec2 UVScale() const { return _uvScale; }

    MenuBlur_Vk(std::string InName, VkDevice InDevice, VkPhysicalDevice InPhysicalDevice);
    ~MenuBlur_Vk();
};
