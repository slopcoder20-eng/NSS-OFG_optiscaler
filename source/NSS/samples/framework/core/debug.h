/* Copyright (c) 2021-2025, Arm Limited and Contributors
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

#include "common/glm_common.h"
#include "common/vk_common.h"
#include <cassert>

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class CommandBuffer;
using CommandBufferC = CommandBuffer<vkb::BindingType::C>;
}                         

   
                                                               
   
class DebugUtils
{
  public:
	virtual ~DebugUtils() = default;

	   
                                                   
    
	virtual void set_debug_name(VkDevice device, VkObjectType object_type, uint64_t object_handle,
	                            const char *name) const = 0;

	   
                                                       
    
	virtual void set_debug_tag(VkDevice device, VkObjectType object_type, uint64_t object_handle,
	                           uint64_t tag_name, const void *tag_data, size_t tag_data_size) const = 0;

	   
                                                                     
    
	virtual void cmd_begin_label(VkCommandBuffer command_buffer,
	                             const char *name, glm::vec4 color = {}) const = 0;

	   
                                                                         
    
	virtual void cmd_end_label(VkCommandBuffer command_buffer) const = 0;

	   
                                                                           
    
	virtual void cmd_insert_label(VkCommandBuffer command_buffer,
	                              const char *name, glm::vec4 color = {}) const = 0;
};

   
                                                              
   
class DebugUtilsExtDebugUtils final : public DebugUtils
{
  public:
	~DebugUtilsExtDebugUtils() override = default;

	void set_debug_name(VkDevice device, VkObjectType object_type, uint64_t object_handle,
	                    const char *name) const override;

	void set_debug_tag(VkDevice device, VkObjectType object_type, uint64_t object_handle,
	                   uint64_t tag_name, const void *tag_data, size_t tag_data_size) const override;

	void cmd_begin_label(VkCommandBuffer command_buffer,
	                     const char *name, glm::vec4 color) const override;

	void cmd_end_label(VkCommandBuffer command_buffer) const override;

	void cmd_insert_label(VkCommandBuffer command_buffer,
	                      const char *name, glm::vec4 color) const override;
};

   
                                                               
   
class DebugMarkerExtDebugUtils final : public DebugUtils
{
  public:
	~DebugMarkerExtDebugUtils() override = default;

	void set_debug_name(VkDevice device, VkObjectType object_type, uint64_t object_handle,
	                    const char *name) const override;

	void set_debug_tag(VkDevice device, VkObjectType object_type, uint64_t object_handle,
	                   uint64_t tag_name, const void *tag_data, size_t tag_data_size) const override;

	void cmd_begin_label(VkCommandBuffer command_buffer,
	                     const char *name, glm::vec4 color) const override;

	void cmd_end_label(VkCommandBuffer command_buffer) const override;

	void cmd_insert_label(VkCommandBuffer command_buffer,
	                      const char *name, glm::vec4 color) const override;
};

   
                           
   
class DummyDebugUtils final : public DebugUtils
{
  public:
	~DummyDebugUtils() override = default;

	inline void set_debug_name(VkDevice, VkObjectType, uint64_t, const char *) const override
	{}

	inline void set_debug_tag(VkDevice, VkObjectType, uint64_t,
	                          uint64_t, const void *, size_t) const override
	{}

	inline void cmd_begin_label(VkCommandBuffer,
	                            const char *, glm::vec4) const override
	{}

	inline void cmd_end_label(VkCommandBuffer) const override
	{}

	inline void cmd_insert_label(VkCommandBuffer,
	                             const char *, glm::vec4) const override
	{}
};

   
                             
                                                                           
                                                         
                                  
   
class ScopedDebugLabel final
{
  public:
	ScopedDebugLabel(const DebugUtils &debug_utils, VkCommandBuffer command_buffer,
	                 const char *name, glm::vec4 color = {});

	ScopedDebugLabel(const vkb::core::CommandBufferC &command_buffer, const char *name, glm::vec4 color = {});

	~ScopedDebugLabel();

  private:
	const DebugUtils *debug_utils;
	VkCommandBuffer   command_buffer;
};

}                        