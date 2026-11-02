/* Copyright (c) 2018-2025, Arm Limited and Contributors
 * Copyright (c) 2019-2025, Sascha Willems
 * Copyright (c) 2024-2025, Mobica Limited
 *
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 the "License";
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once

#include <cstdio>
#include <map>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include "common/error.h"
#include <vk_mem_alloc.h>
#include <volk.h>

#define VK_FLAGS_NONE 0                                                    

#define DEFAULT_FENCE_TIMEOUT 100000000000                                               

template <class T>
using ShaderStageMap = std::map<VkShaderStageFlagBits, T>;

template <class T>
using BindingMap = std::map<uint32_t, std::map<uint32_t, T>>;

namespace vkb
{
enum class BindingType
{
	C,
	Cpp
};

enum class CommandBufferResetMode
{
	ResetPool,
	ResetIndividually,
	AlwaysAllocate,
};

   
                                                                        
                                        
                                                           
   
bool is_depth_only_format(VkFormat format);

   
                                                                                
                                        
                                                                   
   
bool is_depth_stencil_format(VkFormat format);

   
                                                                   
                                        
                                                      
   
bool is_depth_format(VkFormat format);

   
                                                                                                 
                                                                                
                                                                                            
                                                                                                    
                                                                  
                                        
   
VkFormat get_suitable_depth_format(VkPhysicalDevice             physical_device,
                                   bool                         depth_only                 = false,
                                   const std::vector<VkFormat> &depth_format_priority_list = {
                                       VK_FORMAT_D32_SFLOAT,
                                       VK_FORMAT_D24_UNORM_S8_UINT,
                                       VK_FORMAT_D16_UNORM});

   
                                                                                 
                                                                          
                                                                   
                              
   
VkFormat choose_blendable_format(VkPhysicalDevice physical_device, const std::vector<VkFormat> &format_priority_list);

   
                                                                                                     
                                                                                
                                            
                                               
                                                                   
   
void make_filters_valid(VkPhysicalDevice physical_device, VkFormat format, VkFilter *filter, VkSamplerMipmapMode *mipmapMode = nullptr);

   
                                                                                                                         
                                                          
                                                           
   
bool is_dynamic_buffer_descriptor_type(VkDescriptorType descriptor_type);

   
                                                                                                                                  
                                                          
                                                   
   
bool is_buffer_descriptor_type(VkDescriptorType descriptor_type);

   
                                                                       
                                        
                                                                          
   
int32_t get_bits_per_pixel(VkFormat format);

enum class ShadingLanguage
{
	GLSL,
	HLSL,
	SLANG,
};

   
                                                                              
                                      
                                   
                                
                                                         
   
VkShaderModule load_shader(const std::string &filename, VkDevice device, VkShaderStageFlagBits stage);

   
                                                        
                                                          
                                                          
                                                               
                                            
   
VkSurfaceFormatKHR select_surface_format(VkPhysicalDevice             gpu,
                                         VkSurfaceKHR                 surface,
                                         std::vector<VkFormat> const &preferred_formats = {
                                             VK_FORMAT_R8G8B8A8_SRGB, VK_FORMAT_B8G8R8A8_SRGB, VK_FORMAT_A8B8G8R8_SRGB_PACK32});

   
                                                       
                                                                   
   
struct ImageMemoryBarrier
{
	VkPipelineStageFlags src_stage_mask{VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT};

	VkPipelineStageFlags dst_stage_mask{VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT};

	VkAccessFlags src_access_mask{0};

	VkAccessFlags dst_access_mask{0};

	VkImageLayout old_layout{VK_IMAGE_LAYOUT_UNDEFINED};

	VkImageLayout new_layout{VK_IMAGE_LAYOUT_UNDEFINED};

	uint32_t src_queue_family{VK_QUEUE_FAMILY_IGNORED};

	uint32_t dst_queue_family{VK_QUEUE_FAMILY_IGNORED};
};

   
                                                        
                                                              
   
struct BufferMemoryBarrier
{
	VkPipelineStageFlags src_stage_mask{VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT};

	VkPipelineStageFlags dst_stage_mask{VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT};

	VkAccessFlags src_access_mask{0};

	VkAccessFlags dst_access_mask{0};
};

   
                                                                                                                       
                                                                   
                                          
                                                                   
                                                                        
                                                             
                                                                  
                                                          
                                                        
                                                                                   
   
void image_layout_transition(VkCommandBuffer                command_buffer,
                             VkImage                        image,
                             VkPipelineStageFlags           src_stage_mask,
                             VkPipelineStageFlags           dst_stage_mask,
                             VkAccessFlags                  src_access_mask,
                             VkAccessFlags                  dst_access_mask,
                             VkImageLayout                  old_layout,
                             VkImageLayout                  new_layout,
                             VkImageSubresourceRange const &subresource_range);

   
                                                                                                        
  
                                                                                                                               
  
                                                                   
                                          
                                                          
                                                        
                                                                                   
   
void image_layout_transition(VkCommandBuffer                command_buffer,
                             VkImage                        image,
                             VkImageLayout                  old_layout,
                             VkImageLayout                  new_layout,
                             VkImageSubresourceRange const &subresource_range);

   
                                                                                                                                 
  
                                                                                                                               
  
                                                                   
                                          
                                                          
                                                        
   
void image_layout_transition(VkCommandBuffer command_buffer,
                             VkImage         image,
                             VkImageLayout   old_layout,
                             VkImageLayout   new_layout);

   
                                                                                                                              
  
                                                                                                                               
  
                                                                   
                                                                                         
                                                          
                                                        
   
void image_layout_transition(VkCommandBuffer                                                 command_buffer,
                             std::vector<std::pair<VkImage, VkImageSubresourceRange>> const &imagesAndRanges,
                             VkImageLayout                                                   old_layout,
                             VkImageLayout                                                   new_layout);

   
                                                   
   
std::vector<VkImageCompressionFixedRateFlagBitsEXT> fixed_rate_compression_flags_to_vector(VkImageCompressionFixedRateFlagsEXT flags);

VkImageCompressionPropertiesEXT query_supported_fixed_rate_compression(VkPhysicalDevice gpu, const VkImageCreateInfo &create_info);

VkImageCompressionPropertiesEXT query_applied_compression(VkDevice device, VkImage image);

   
                                                           
   
struct LoadStoreInfo
{
	VkAttachmentLoadOp load_op = VK_ATTACHMENT_LOAD_OP_CLEAR;

	VkAttachmentStoreOp store_op = VK_ATTACHMENT_STORE_OP_STORE;
};

namespace gbuffer
{
   
                                                                   
   
std::vector<LoadStoreInfo> get_load_all_store_swapchain();

   
                                                                    
   
std::vector<LoadStoreInfo> get_clear_all_store_swapchain();

   
                                                        
   
std::vector<LoadStoreInfo> get_clear_store_all();

   
                                                
   
std::vector<VkClearValue> get_clear_value();
}                            

uint32_t get_queue_family_index(std::vector<VkQueueFamilyProperties> const &queue_family_properties, VkQueueFlagBits queue_flag);

}                        
