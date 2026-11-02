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

#include "descriptor_pool.h"

#include "descriptor_set_layout.h"
#include "device.h"

namespace vkb
{
DescriptorPool::DescriptorPool(vkb::core::DeviceC        &device,
                               const DescriptorSetLayout &descriptor_set_layout,
                               uint32_t                   pool_size) :
    device{device},
    descriptor_set_layout{&descriptor_set_layout}
{
	const auto &bindings = descriptor_set_layout.get_bindings();

	std::map<VkDescriptorType, std::uint32_t> descriptor_type_counts;

	                                    
	for (auto &binding : bindings)
	{
		descriptor_type_counts[binding.descriptorType] += binding.descriptorCount;
	}

	                            
	pool_sizes.resize(descriptor_type_counts.size());

	auto pool_size_it = pool_sizes.begin();

	                                                                            
	for (auto &it : descriptor_type_counts)
	{
		pool_size_it->type = it.first;

		pool_size_it->descriptorCount = it.second * pool_size;

		++pool_size_it;
	}

	pool_max_sets = pool_size;
}

DescriptorPool::~DescriptorPool()
{
	                               
	for (auto pool : pools)
	{
		vkDestroyDescriptorPool(device.get_handle(), pool, nullptr);
	}
}

void DescriptorPool::reset()
{
	                             
	for (auto pool : pools)
	{
		vkResetDescriptorPool(device.get_handle(), pool, 0);
	}

	                                                        
	std::fill(pool_sets_count.begin(), pool_sets_count.end(), 0);
	set_pool_mapping.clear();

	                                                                
	pool_index = 0;
}

const DescriptorSetLayout &DescriptorPool::get_descriptor_set_layout() const
{
	assert(descriptor_set_layout && "Descriptor set layout is invalid");
	return *descriptor_set_layout;
}

void DescriptorPool::set_descriptor_set_layout(const DescriptorSetLayout &set_layout)
{
	descriptor_set_layout = &set_layout;
}

VkDescriptorSet DescriptorPool::allocate()
{
	pool_index = find_available_pool(pool_index);

	                                                     
	++pool_sets_count[pool_index];

	VkDescriptorSetLayout set_layout = get_descriptor_set_layout().get_handle();

	VkDescriptorSetAllocateInfo alloc_info{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};
	alloc_info.descriptorPool     = pools[pool_index];
	alloc_info.descriptorSetCount = 1;
	alloc_info.pSetLayouts        = &set_layout;

	VkDescriptorSet handle = VK_NULL_HANDLE;

	                                                      
	auto result = vkAllocateDescriptorSets(device.get_handle(), &alloc_info, &handle);

	if (result != VK_SUCCESS)
	{
		                                                     
		--pool_sets_count[pool_index];

		return VK_NULL_HANDLE;
	}

	                                                        
	set_pool_mapping.emplace(handle, pool_index);

	return handle;
}

VkResult DescriptorPool::free(VkDescriptorSet descriptor_set)
{
	                                           
	auto it = set_pool_mapping.find(descriptor_set);

	if (it == set_pool_mapping.end())
	{
		return VK_INCOMPLETE;
	}

	auto desc_pool_index = it->second;

	                                    
	vkFreeDescriptorSets(device.get_handle(), pools[desc_pool_index], 1, &descriptor_set);

	                                            
	set_pool_mapping.erase(it);

	                                             
	--pool_sets_count[desc_pool_index];

	                                                          
	pool_index = desc_pool_index;

	return VK_SUCCESS;
}

std::uint32_t DescriptorPool::find_available_pool(std::uint32_t search_index)
{
	                    
	if (pools.size() <= search_index)
	{
		VkDescriptorPoolCreateInfo create_info{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};

		create_info.poolSizeCount = to_u32(pool_sizes.size());
		create_info.pPoolSizes    = pool_sizes.data();
		create_info.maxSets       = pool_max_sets;

		                                                                                             
		create_info.flags = 0;

		                                                            
		auto &binding_flags = descriptor_set_layout->get_binding_flags();
		for (auto binding_flag : binding_flags)
		{
			if (binding_flag & VK_DESCRIPTOR_BINDING_UPDATE_AFTER_BIND_BIT_EXT)
			{
				create_info.flags |= VK_DESCRIPTOR_POOL_CREATE_UPDATE_AFTER_BIND_BIT_EXT;
			}
		}

		VkDescriptorPool handle = VK_NULL_HANDLE;

		                                    
		auto result = vkCreateDescriptorPool(device.get_handle(), &create_info, nullptr, &handle);

		if (result != VK_SUCCESS)
		{
			return 0;
		}

		                                     
		pools.push_back(handle);

		                                        
		pool_sets_count.push_back(0);

		return search_index;
	}
	else if (pool_sets_count[search_index] < pool_max_sets)
	{
		return search_index;
	}

	                       
	return find_available_pool(++search_index);
}
}                        
