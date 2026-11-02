/* Copyright (c) 2019-2025, Arm Limited and Contributors
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

#include "common/helpers.h"
#include "common/vk_common.h"

#if defined(VK_USE_PLATFORM_XLIB_KHR)
#	undef None
#endif

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class Device;
using DeviceC = Device<vkb::BindingType::C>;
}                         

                             
enum class ShaderResourceType
{
	Input,
	InputAttachment,
	Output,
	Image,
	ImageSampler,
	ImageStorage,
	Sampler,
	BufferUniform,
	BufferStorage,
	PushConstant,
	SpecializationConstant,
	All
};

                                                                                         
enum class ShaderResourceMode
{
	Static,
	Dynamic,
	UpdateAfterBind
};

                                                 
struct ShaderResourceQualifiers
{
	enum : uint32_t
	{
		None        = 0,
		NonReadable = 1,
		NonWritable = 2,
	};
};

                               
                              
struct ShaderResource
{
	VkShaderStageFlags stages;

	ShaderResourceType type;

	ShaderResourceMode mode;

	uint32_t set;

	uint32_t binding;

	uint32_t location;

	uint32_t input_attachment_index;

	uint32_t vec_size;

	uint32_t columns;

	uint32_t array_size;

	uint32_t offset;

	uint32_t size;

	uint32_t constant_id;

	uint32_t qualifiers;

	std::string name;
};

   
                                                                      
                                                            
   
class ShaderVariant
{
  public:
	ShaderVariant() = default;

	size_t get_id() const;

	   
                                                                                                                          
                                                                                         
                                                                                                                                                             
                                                                 
    
	void add_runtime_array_size(const std::string &runtime_array_name, size_t size);

	void set_runtime_array_sizes(const std::unordered_map<std::string, size_t> &sizes);

	const std::unordered_map<std::string, size_t> &get_runtime_array_sizes() const;

	void clear();

  private:
	size_t id;

	std::unordered_map<std::string, size_t> runtime_array_sizes;
};

class ShaderSource
{
  public:
	ShaderSource() = default;

	ShaderSource(const std::string &filename);

	size_t get_id() const;

	const std::string &get_filename() const;

	void set_source(const std::string &source);

	const std::string &get_source() const;

  private:
	size_t id;

	std::string filename;

	std::string source;
};

   
                                                                                 
                                                         
                                                                     
                                                                                
                                                                            
                                                                                      
                                                                  
   
class ShaderModule
{
  public:
	ShaderModule(vkb::core::DeviceC   &device,
	             VkShaderStageFlagBits stage,
	             const ShaderSource   &shader_source,
	             const std::string    &entry_point,
	             const ShaderVariant  &shader_variant);

	ShaderModule(const ShaderModule &) = delete;

	ShaderModule(ShaderModule &&other);

	ShaderModule &operator=(const ShaderModule &) = delete;

	ShaderModule &operator=(ShaderModule &&) = delete;

	size_t get_id() const;

	VkShaderStageFlagBits get_stage() const;

	const std::string &get_entry_point() const;

	const std::vector<ShaderResource> &get_resources() const;

	const std::vector<uint32_t> &get_binary() const;

	inline const std::string &get_debug_name() const
	{
		return debug_name;
	}

	inline void set_debug_name(const std::string &name)
	{
		debug_name = name;
	}

	   
                                                                                  
                                                        
                                                                          
    
	void set_resource_mode(const std::string &resource_name, const ShaderResourceMode &resource_mode);

  private:
	vkb::core::DeviceC &device;

	                    
	size_t id;

	                                               
	VkShaderStageFlagBits stage{};

	                             
	std::string entry_point;

	                                      
	std::string debug_name;

	                   
	std::vector<uint32_t> spirv;

	std::vector<ShaderResource> resources;
};
}                        
