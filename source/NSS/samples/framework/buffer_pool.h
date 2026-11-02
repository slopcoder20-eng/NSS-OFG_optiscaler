/* Copyright (c) 2019-2025, Arm Limited and Contributors
 * Copyright (c) 2024-2025, NVIDIA CORPORATION. All rights reserved.
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
#include "core/buffer.h"
#include "core/device.h"

namespace vkb
{
   
                                                                       
                                                                              
   
template <vkb::BindingType bindingType>
class BufferAllocation
{
  public:
	using DeviceSizeType = typename std::conditional<bindingType == vkb::BindingType::Cpp, vk::DeviceSize, VkDeviceSize>::type;

  public:
	BufferAllocation()                                    = default;
	BufferAllocation(const BufferAllocation &)            = default;
	BufferAllocation(BufferAllocation &&)                 = default;
	BufferAllocation &operator=(const BufferAllocation &) = default;
	BufferAllocation &operator=(BufferAllocation &&)      = default;

	BufferAllocation(vkb::core::Buffer<bindingType> &buffer, DeviceSizeType size, DeviceSizeType offset);

	bool                            empty() const;
	vkb::core::Buffer<bindingType> &get_buffer();
	DeviceSizeType                  get_offset() const;
	DeviceSizeType                  get_size() const;
	void                            update(const std::vector<uint8_t> &data, uint32_t offset = 0);
	template <typename T>
	void update(const T &value, uint32_t offset = 0);

  private:
	vkb::core::BufferCpp *buffer = nullptr;
	vk::DeviceSize        offset = 0;
	vk::DeviceSize        size   = 0;
};

using BufferAllocationC   = BufferAllocation<vkb::BindingType::C>;
using BufferAllocationCpp = BufferAllocation<vkb::BindingType::Cpp>;

template <>
inline BufferAllocation<vkb::BindingType::Cpp>::BufferAllocation(vkb::core::BufferCpp &buffer, vk::DeviceSize size, vk::DeviceSize offset) :
    buffer(&buffer),
    offset(offset),
    size(size)
{}

template <>
inline BufferAllocation<vkb::BindingType::C>::BufferAllocation(vkb::core::BufferC &buffer, VkDeviceSize size, VkDeviceSize offset) :
    buffer(reinterpret_cast<vkb::core::BufferCpp *>(&buffer)),
    offset(static_cast<vk::DeviceSize>(offset)),
    size(static_cast<vk::DeviceSize>(size))
{}

template <vkb::BindingType bindingType>
bool BufferAllocation<bindingType>::empty() const
{
	return size == 0 || buffer == nullptr;
}

template <vkb::BindingType bindingType>
typename vkb::core::Buffer<bindingType> &BufferAllocation<bindingType>::get_buffer()
{
	assert(buffer && "Invalid buffer pointer");
	if constexpr (bindingType == vkb::BindingType::Cpp)
	{
		return *buffer;
	}
	else
	{
		return reinterpret_cast<vkb::core::BufferC &>(*buffer);
	}
}

template <vkb::BindingType bindingType>
typename BufferAllocation<bindingType>::DeviceSizeType BufferAllocation<bindingType>::get_offset() const
{
	if constexpr (bindingType == vkb::BindingType::Cpp)
	{
		return offset;
	}
	else
	{
		return static_cast<VkDeviceSize>(offset);
	}
}

template <vkb::BindingType bindingType>
typename BufferAllocation<bindingType>::DeviceSizeType BufferAllocation<bindingType>::get_size() const
{
	if constexpr (bindingType == vkb::BindingType::Cpp)
	{
		return size;
	}
	else
	{
		return static_cast<VkDeviceSize>(size);
	}
}

template <vkb::BindingType bindingType>
void BufferAllocation<bindingType>::update(const std::vector<uint8_t> &data, uint32_t offset)
{
	assert(buffer && "Invalid buffer pointer");

	if (offset + data.size() <= size)
	{
		buffer->update(data, to_u32(this->offset) + offset);
	}
	else
	{
		LOGE("Ignore buffer allocation update");
	}
}

template <vkb::BindingType bindingType>
template <typename T>
void BufferAllocation<bindingType>::update(const T &value, uint32_t offset)
{
	update(to_bytes(value), offset);
}

   
                                                                                                
   
template <vkb::BindingType bindingType>
class BufferBlock
{
  public:
	using BufferUsageFlagsType = typename std::conditional<bindingType == vkb::BindingType::Cpp, vk::BufferUsageFlags, VkBufferUsageFlags>::type;
	using DeviceSizeType       = typename std::conditional<bindingType == vkb::BindingType::Cpp, vk::DeviceSize, VkDeviceSize>::type;

  public:
	BufferBlock()                                  = delete;
	BufferBlock(BufferBlock const &rhs)            = delete;
	BufferBlock(BufferBlock &&rhs)                 = default;
	BufferBlock &operator=(BufferBlock const &rhs) = delete;
	BufferBlock &operator=(BufferBlock &&rhs)      = default;

	BufferBlock(vkb::core::Device<bindingType> &device, DeviceSizeType size, BufferUsageFlagsType usage, VmaMemoryUsage memory_usage);

	   
                                                                
    
	BufferAllocation<bindingType> allocate(DeviceSizeType size);

	   
                                                                          
                                            
                                                                                                   
    
	bool can_allocate(DeviceSizeType size) const;

	DeviceSizeType get_size() const;
	void           reset();

  private:
	   
                                                 
                                       
    
	vk::DeviceSize aligned_offset() const;
	vk::DeviceSize determine_alignment(vk::BufferUsageFlags usage, vk::PhysicalDeviceLimits const &limits) const;

  private:
	vkb::core::BufferCpp buffer;
	vk::DeviceSize       alignment = 0;                                                                 
	vk::DeviceSize       offset    = 0;                                                           
};

using BufferBlockC   = BufferBlock<vkb::BindingType::C>;
using BufferBlockCpp = BufferBlock<vkb::BindingType::Cpp>;

template <vkb::BindingType bindingType>
BufferBlock<bindingType>::BufferBlock(vkb::core::Device<bindingType> &device, DeviceSizeType size, BufferUsageFlagsType usage, VmaMemoryUsage memory_usage) :
    buffer{device, size, usage, memory_usage}
{
	if constexpr (bindingType == BindingType::Cpp)
	{
		alignment = determine_alignment(usage, device.get_gpu().get_properties().limits);
	}
	else
	{
		alignment =
		    determine_alignment(static_cast<vk::BufferUsageFlags>(usage), static_cast<vk::PhysicalDeviceLimits>(device.get_gpu().get_properties().limits));
	}
}

template <vkb::BindingType bindingType>
BufferAllocation<bindingType> BufferBlock<bindingType>::allocate(DeviceSizeType size)
{
	if (can_allocate(size))
	{
		                                                   
		auto aligned = aligned_offset();
		offset       = aligned + size;
		if constexpr (bindingType == vkb::BindingType::Cpp)
		{
			return BufferAllocationCpp{buffer, size, aligned};
		}
		else
		{
			return BufferAllocationC{reinterpret_cast<vkb::core::BufferC &>(buffer), static_cast<VkDeviceSize>(size), static_cast<VkDeviceSize>(aligned)};
		}
	}

	                                                                              
	return BufferAllocation<bindingType>{};
}

template <vkb::BindingType bindingType>
bool BufferBlock<bindingType>::can_allocate(DeviceSizeType size) const
{
	assert(size > 0 && "Allocation size must be greater than zero");
	return (aligned_offset() + size <= buffer.get_size());
}

template <vkb::BindingType bindingType>
typename BufferBlock<bindingType>::DeviceSizeType BufferBlock<bindingType>::get_size() const
{
	return buffer.get_size();
}

template <vkb::BindingType bindingType>
void BufferBlock<bindingType>::reset()
{
	offset = 0;
}

template <vkb::BindingType bindingType>
vk::DeviceSize BufferBlock<bindingType>::aligned_offset() const
{
	return (offset + alignment - 1) & ~(alignment - 1);
}

template <vkb::BindingType bindingType>
vk::DeviceSize BufferBlock<bindingType>::determine_alignment(vk::BufferUsageFlags usage, vk::PhysicalDeviceLimits const &limits) const
{
	if (usage == vk::BufferUsageFlagBits::eUniformBuffer)
	{
		return limits.minUniformBufferOffsetAlignment;
	}
	else if (usage == vk::BufferUsageFlagBits::eStorageBuffer)
	{
		return limits.minStorageBufferOffsetAlignment;
	}
	else if (usage == vk::BufferUsageFlagBits::eUniformTexelBuffer)
	{
		return limits.minTexelBufferOffsetAlignment;
	}
	else if (usage == vk::BufferUsageFlagBits::eIndexBuffer || usage == vk::BufferUsageFlagBits::eVertexBuffer ||
	         usage == vk::BufferUsageFlagBits::eIndirectBuffer)
	{
		                                                                                                 
		return 16;
	}
	else
	{
		throw std::runtime_error("Usage not recognised");
	}
}

   
                                                       
                                                       
  
                                                                                                
                                                                                         
                                                                              
                          
  
                                                                                            
                                                                                              
                     
  
                                                                                              
                                                                                   
   
template <vkb::BindingType bindingType>
class BufferPool
{
  public:
	using BufferUsageFlagsType = typename std::conditional<bindingType == vkb::BindingType::Cpp, vk::BufferUsageFlags, VkBufferUsageFlags>::type;
	using DeviceSizeType       = typename std::conditional<bindingType == vkb::BindingType::Cpp, vk::DeviceSize, VkDeviceSize>::type;

  public:
	BufferPool(
	    vkb::core::Device<bindingType> &device, DeviceSizeType block_size, BufferUsageFlagsType usage, VmaMemoryUsage memory_usage = VMA_MEMORY_USAGE_CPU_TO_GPU);

	BufferBlock<bindingType> &request_buffer_block(DeviceSizeType minimum_size, bool minimal = false);

	void reset();

  private:
	vkb::core::DeviceCpp                        &device;
	std::vector<std::unique_ptr<BufferBlockCpp>> buffer_blocks;                                                                                                                      
	vk::DeviceSize                               block_size = 0;                                      
	vk::BufferUsageFlags                         usage;
	VmaMemoryUsage                               memory_usage{};
};

using BufferPoolC   = BufferPool<vkb::BindingType::C>;
using BufferPoolCpp = BufferPool<vkb::BindingType::Cpp>;

template <vkb::BindingType bindingType>
BufferPool<bindingType>::BufferPool(vkb::core::Device<bindingType> &device,
                                    DeviceSizeType                  block_size,
                                    BufferUsageFlagsType            usage,
                                    VmaMemoryUsage                  memory_usage) :
    device{reinterpret_cast<vkb::core::DeviceCpp &>(device)}, block_size{block_size}, usage{usage}, memory_usage{memory_usage}
{
}

template <vkb::BindingType bindingType>
BufferBlock<bindingType> &BufferPool<bindingType>::request_buffer_block(DeviceSizeType minimum_size, bool minimal)
{
	                                                                         
	auto it = minimal ? std::ranges::find_if(buffer_blocks,
	                                         [&minimum_size](auto const &buffer_block) { return (buffer_block->get_size() == minimum_size) && buffer_block->can_allocate(minimum_size); }) :
	                    std::ranges::find_if(buffer_blocks,
	                                         [&minimum_size](auto const &buffer_block) { return buffer_block->can_allocate(minimum_size); });

	if (it == buffer_blocks.end())
	{
		LOGD("Building #{} buffer block ({})", buffer_blocks.size(), vk::to_string(usage));

		vk::DeviceSize new_block_size = minimal ? minimum_size : std::max(block_size, minimum_size);

		                                                
		it = buffer_blocks.emplace(buffer_blocks.end(), std::make_unique<BufferBlockCpp>(device, new_block_size, usage, memory_usage));
	}

	if constexpr (bindingType == vkb::BindingType::Cpp)
	{
		return *it->get();
	}
	else
	{
		return reinterpret_cast<BufferBlockC &>(*it->get());
	}
}

template <vkb::BindingType bindingType>
void BufferPool<bindingType>::reset()
{
	                                                                                                      
	                                                                                                       
	                                                                  
	for (auto &buffer_block : buffer_blocks)
	{
		buffer_block->reset();
	}
}

}                        
