/* Copyright (c) 2022-2025, NVIDIA CORPORATION. All rights reserved.
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

#include "common/vk_common.h"
#include <glm/glm.hpp>
#include <vulkan/vulkan.hpp>

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class CommandBuffer;
using CommandBufferCpp = CommandBuffer<vkb::BindingType::Cpp>;

   
                                                               
   
class HPPDebugUtils
{
  public:
	virtual ~HPPDebugUtils() = default;

	   
                                                   
    
	virtual void set_debug_name(vk::Device device, vk::ObjectType object_type, uint64_t object_handle, const char *name) const = 0;

	   
                                                       
    
	virtual void set_debug_tag(
	    vk::Device device, vk::ObjectType object_type, uint64_t object_handle, uint64_t tag_name, const void *tag_data, size_t tag_data_size) const = 0;

	   
                                                                     
    
	virtual void cmd_begin_label(vk::CommandBuffer command_buffer, const char *name, glm::vec4 const color = {}) const = 0;

	   
                                                                         
    
	virtual void cmd_end_label(vk::CommandBuffer command_buffer) const = 0;

	   
                                                                           
    
	virtual void cmd_insert_label(vk::CommandBuffer command_buffer, const char *name, glm::vec4 const color = {}) const = 0;
};

   
                                                                 
   
class HPPDebugUtilsExtDebugUtils final : public vkb::core::HPPDebugUtils
{
  public:
	~HPPDebugUtilsExtDebugUtils() override = default;

	void set_debug_name(vk::Device device, vk::ObjectType object_type, uint64_t object_handle, const char *name) const override;

	void set_debug_tag(
	    vk::Device device, vk::ObjectType object_type, uint64_t object_handle, uint64_t tag_name, const void *tag_data, size_t tag_data_size) const override;

	void cmd_begin_label(vk::CommandBuffer command_buffer, const char *name, glm::vec4 const color) const override;

	void cmd_end_label(vk::CommandBuffer command_buffer) const override;

	void cmd_insert_label(vk::CommandBuffer command_buffer, const char *name, glm::vec4 const color) const override;
};

   
                                                                  
   
class HPPDebugMarkerExtDebugUtils final : public vkb::core::HPPDebugUtils
{
  public:
	~HPPDebugMarkerExtDebugUtils() override = default;

	void set_debug_name(vk::Device device, vk::ObjectType object_type, uint64_t object_handle, const char *name) const override;

	void set_debug_tag(
	    vk::Device device, vk::ObjectType object_type, uint64_t object_handle, uint64_t tag_name, const void *tag_data, size_t tag_data_size) const override;

	void cmd_begin_label(vk::CommandBuffer command_buffer, const char *name, glm::vec4 const color) const override;

	void cmd_end_label(vk::CommandBuffer command_buffer) const override;

	void cmd_insert_label(vk::CommandBuffer command_buffer, const char *name, glm::vec4 const color) const override;
};

   
                              
   
class HPPDummyDebugUtils final : public vkb::core::HPPDebugUtils
{
  public:
	~HPPDummyDebugUtils() override = default;

	inline void set_debug_name(vk::Device, vk::ObjectType, uint64_t, const char *) const override
	{}

	inline void set_debug_tag(vk::Device, vk::ObjectType, uint64_t, uint64_t, const void *, size_t) const override
	{}

	inline void cmd_begin_label(vk::CommandBuffer, const char *, glm::vec4 const) const override
	{}

	inline void cmd_end_label(vk::CommandBuffer) const override
	{}

	inline void cmd_insert_label(vk::CommandBuffer, const char *, glm::vec4 const) const override
	{}
};

   
                             
                                                                           
                                                         
                                  
   
class HPPScopedDebugLabel final
{
  public:
	HPPScopedDebugLabel(const vkb::core::HPPDebugUtils &debug_utils, vk::CommandBuffer command_buffer, std::string const &name, glm::vec4 const color = {});

	HPPScopedDebugLabel(const vkb::core::CommandBufferCpp &command_buffer, std::string const &name, glm::vec4 const color = {});

	~HPPScopedDebugLabel();

  private:
	const vkb::core::HPPDebugUtils *debug_utils;
	vk::CommandBuffer               command_buffer;
};

}                         
}                        