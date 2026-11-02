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

namespace vkb
{
class DescriptorSetLayout;
class DescriptorPool;

namespace core
{
template <vkb::BindingType bindingType>
class Device;
using DeviceC = Device<vkb::BindingType::C>;
}                         

   
                                                                       
                                                                                                        
  
                                                                              
   
class DescriptorSet
{
  public:
	   
                                                                        
                                     
                                       
                                                                                         
                                                                                          
                                                                 
                                                               
    
	DescriptorSet(vkb::core::DeviceC                       &device,
	              const DescriptorSetLayout                &descriptor_set_layout,
	              DescriptorPool                           &descriptor_pool,
	              const BindingMap<VkDescriptorBufferInfo> &buffer_infos = {},
	              const BindingMap<VkDescriptorImageInfo>  &image_infos  = {});

	DescriptorSet(const DescriptorSet &) = delete;

	DescriptorSet(DescriptorSet &&other);

	                                                                                                 
	~DescriptorSet() = default;

	DescriptorSet &operator=(const DescriptorSet &) = delete;

	DescriptorSet &operator=(DescriptorSet &&) = delete;

	   
                                         
                                                                           
                                                                                     
                                                                                   
    
	void reset(const BindingMap<VkDescriptorBufferInfo> &new_buffer_infos = {},
	           const BindingMap<VkDescriptorImageInfo>  &new_image_infos  = {});

	   
                                                                                       
                                                                                                                                                 
    
	void update(const std::vector<uint32_t> &bindings_to_update = {});

	   
                                                                      
    
	void apply_writes() const;

	const DescriptorSetLayout &get_layout() const;

	VkDescriptorSet get_handle() const;

	BindingMap<VkDescriptorBufferInfo> &get_buffer_infos();

	BindingMap<VkDescriptorImageInfo> &get_image_infos();

  protected:
	   
                                                                                                           
                                                                        
    
	void prepare();

  private:
	vkb::core::DeviceC &device;

	const DescriptorSetLayout &descriptor_set_layout;

	DescriptorPool &descriptor_pool;

	BindingMap<VkDescriptorBufferInfo> buffer_infos;

	BindingMap<VkDescriptorImageInfo> image_infos;

	VkDescriptorSet handle{VK_NULL_HANDLE};

	                                                      
	std::vector<VkWriteDescriptorSet> write_descriptor_sets;

	                                                                                                              
	                                                                                                 
	std::unordered_map<uint32_t, size_t> updated_bindings;
};
}                        
