/* Copyright (c) 2018-2024, Arm Limited and Contributors
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

#include <map>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include <volk.h>

namespace vkb
{
enum class ShaderResourceType;

namespace sg
{
enum class AlphaMode;
}

std::vector<std::string> split(const std::string &str, const std::string &delimiter);
std::string              join(const std::vector<std::string> &str, const std::string &separator);

   
                                                                
                                          
                                
   
const std::string to_string(VkFormat format);

   
                                                                   
                                                      
                                
   
const std::string to_string(VkPresentModeKHR present_mode);

   
                                                                
                                          
                                
   
const std::string to_string(VkResult result);

   
                                                                            
                                                      
                                
   
const std::string to_string(VkPhysicalDeviceType type);

   
                                                                                     
                                                                      
                                
   
const std::string to_string(VkSurfaceTransformFlagBitsKHR transform_flag);

   
                                                                            
                                                          
                                
   
const std::string to_string(VkSurfaceFormatKHR surface_format);

   
                                                                                   
                                                                     
                                
   
const std::string to_string(VkCompositeAlphaFlagBitsKHR composite_alpha);

   
                                                                            
                                                             
                                
   
const std::string to_string(VkImageUsageFlagBits image_usage);

   
                                                                  
                                          
                                
   
std::string to_string(VkExtent2D format);

   
                                                                      
                                                    
                            
   
const std::string to_string(VkSampleCountFlagBits flags);

   
                                                              
                                                
                               
   
const std::string to_string(VkImageTiling tiling);

   
                                                            
                                            
                               
   
const std::string to_string(VkImageType type);

   
                                                              
                                               
                               
   
const std::string to_string(VkBlendFactor blend);

   
                                                                  
                                                  
                               
   
const std::string to_string(VkVertexInputRate rate);

   
                                                         
                                          
                               
   
const std::string to_string_vk_bool(VkBool32 state);

   
                                                                    
                                                        
                               
   
const std::string to_string(VkPrimitiveTopology topology);

   
                                                            
                                            
                               
   
const std::string to_string(VkFrontFace face);

   
                                                              
                                              
                               
   
const std::string to_string(VkPolygonMode mode);

   
                                                            
                                                 
                               
   
const std::string to_string(VkCompareOp operation);

   
                                                            
                                                 
                               
   
const std::string to_string(VkStencilOp operation);

   
                                                          
                                               
                               
   
const std::string to_string(VkLogicOp operation);

   
                                                          
                                               
                               
   
const std::string to_string(VkBlendOp operation);

   
                                                          
                                          
                               
   
const std::string to_string(sg::AlphaMode mode);

   
                                                     
                                                  
                               
   
const std::string to_string(bool flag);

   
                                                                   
                                                   
                               
   
const std::string to_string(ShaderResourceType type);

   
                                                                                    
                                        
                                                                                      
                                                       
   
template <typename T>
inline const std::string to_string(uint32_t bitmask, const std::map<T, const char *> string_map)
{
	std::stringstream result;
	bool              append = false;
	for (const auto &s : string_map)
	{
		if (bitmask & s.first)
		{
			if (append)
			{
				result << " | ";
			}
			result << s.second;
			append = true;
		}
	}
	return result.str();
}

   
                                                                   
                                                                
                                         
   
const std::string buffer_usage_to_string(VkBufferUsageFlags bitmask);

   
                                                                   
                                                     
                                         
   
const std::string shader_stage_to_string(VkShaderStageFlags bitmask);

   
                                                                  
                                                    
                                         
   
const std::string image_usage_to_string(VkImageUsageFlags bitmask);

   
                                                                   
                                                     
                                         
   
const std::string image_aspect_to_string(VkImageAspectFlags bitmask);

   
                                                                
                                                  
                                         
   
const std::string cull_mode_to_string(VkCullModeFlags bitmask);

   
                                                                      
                                                        
                                         
   
const std::string color_component_to_string(VkColorComponentFlags bitmask);

   
                                                                           
                                    
                                         
   
const std::string image_compression_flags_to_string(VkImageCompressionFlagsEXT flags);

   
                                                                                    
                                    
                                         
   
const std::string image_compression_fixed_rate_flags_to_string(VkImageCompressionFixedRateFlagsEXT flags);

   
                                                                                          
                                            
                                           
                                          
   
std::vector<std::string> split(const std::string &input, char delim);
}                        
