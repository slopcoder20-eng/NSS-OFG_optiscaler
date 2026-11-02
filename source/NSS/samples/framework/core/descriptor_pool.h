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

#include <unordered_map>

#include "common/helpers.h"
#include "common/vk_common.h"

namespace vkb
{
class DescriptorSetLayout;

namespace core
{
template <vkb::BindingType bindingType>
class Device;
using DeviceC = Device<vkb::BindingType::C>;
}                         

   
                                                                                                 
   
class DescriptorPool
{
  public:
	static const uint32_t MAX_SETS_PER_POOL = 16;

	DescriptorPool(vkb::core::DeviceC        &device,
	               const DescriptorSetLayout &descriptor_set_layout,
	               uint32_t                   pool_size = MAX_SETS_PER_POOL);

	DescriptorPool(const DescriptorPool &) = delete;

	DescriptorPool(DescriptorPool &&) = default;

	~DescriptorPool();

	DescriptorPool &operator=(const DescriptorPool &) = delete;

	DescriptorPool &operator=(DescriptorPool &&) = delete;

	void reset();

	const DescriptorSetLayout &get_descriptor_set_layout() const;

	void set_descriptor_set_layout(const DescriptorSetLayout &set_layout);

	VkDescriptorSet allocate();

	VkResult free(VkDescriptorSet descriptor_set);

  private:
	vkb::core::DeviceC &device;

	const DescriptorSetLayout *descriptor_set_layout{nullptr};

	                       
	std::vector<VkDescriptorPoolSize> pool_sizes;

	                                           
	uint32_t pool_max_sets{0};

	                                 
	std::vector<VkDescriptorPool> pools;

	                           
	std::vector<uint32_t> pool_sets_count;

	                                                
	uint32_t pool_index{0};

	                                            
	std::unordered_map<VkDescriptorSet, uint32_t> set_pool_mapping;

	                                          
	uint32_t find_available_pool(uint32_t pool_index);
};
}                        
