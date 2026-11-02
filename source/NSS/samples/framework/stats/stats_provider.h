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

#include "common/vk_common.h"
#include "stats_common.h"

namespace vkb
{
namespace core
{
template <vkb::BindingType bindingType>
class CommandBuffer;
using CommandBufferC = CommandBuffer<vkb::BindingType::C>;
}                         

   
                                                          
   
class StatsProvider
{
  public:
	struct Counter
	{
		double result;
	};

	using Counters = std::unordered_map<StatIndex, Counter, StatIndexHash>;

	   
                             
    
	virtual ~StatsProvider()
	{}

	   
                                                                    
                               
                                                          
    
	virtual bool is_available(StatIndex index) const = 0;

	   
                                                            
                               
    
	virtual const StatGraphData &get_graph_data(StatIndex index) const
	{
		return default_graph_map.at(index);
	}

	   
                                                            
                               
    
	static const StatGraphData &default_graph_data(StatIndex index);

	   
                                    
                                            
    
	virtual Counters sample(float delta_time) = 0;

	   
                                                             
                                            
    
	virtual Counters continuous_sample(float delta_time)
	{
		return Counters();
	}

	   
                                                                   
                                
    
	virtual void begin_sampling(vkb::core::CommandBufferC &cb)
	{}

	   
                                                                         
                                
    
	virtual void end_sampling(vkb::core::CommandBufferC &cb)
	{}

  protected:
	static std::map<StatIndex, StatGraphData> default_graph_map;
};
}                        
