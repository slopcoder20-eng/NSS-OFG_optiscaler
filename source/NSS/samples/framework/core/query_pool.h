/* Copyright (c) 2020-2025, Broadcom Inc. and Contributors
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
namespace core
{
template <vkb::BindingType bindingType>
class Device;
using DeviceC = Device<vkb::BindingType::C>;
}                         

   
                                        
   
class QueryPool
{
  public:
	   
                                      
                              
                                
    
	QueryPool(vkb::core::DeviceC &d, const VkQueryPoolCreateInfo &info);

	QueryPool(const QueryPool &) = delete;

	QueryPool(QueryPool &&pool);

	~QueryPool();

	QueryPool &operator=(const QueryPool &) = delete;

	QueryPool &operator=(QueryPool &&) = delete;

	   
                                        
    
	VkQueryPool get_handle() const;

	   
                                                                                                       
                                               
                                                     
    
	void host_reset(uint32_t first_query, uint32_t query_count);

	   
                                 
                                              
                                                    
                                                                
                                                   
                                                                            
                                                   
    
	VkResult get_results(uint32_t first_query, uint32_t num_queries,
	                     size_t result_bytes, void *results, VkDeviceSize stride,
	                     VkQueryResultFlags flags);

  private:
	vkb::core::DeviceC &device;

	VkQueryPool handle{VK_NULL_HANDLE};
};
}                        
