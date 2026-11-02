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

#include "core/query_pool.h"
#include "stats_provider.h"

namespace vkb
{
class RenderContext;

class VulkanStatsProvider : public StatsProvider
{
  private:
	struct StatData
	{
		StatScaling                    scaling;
		uint32_t                       counter_index;
		uint32_t                       divisor_counter_index;
		VkPerformanceCounterStorageKHR storage;
		VkPerformanceCounterStorageKHR divisor_storage;
		StatGraphData                  graph_data;

		StatData() = default;

		StatData(uint32_t counter_index, VkPerformanceCounterStorageKHR storage,
		         StatScaling                    stat_scaling    = StatScaling::ByDeltaTime,
		         uint32_t                       divisor_index   = std::numeric_limits<uint32_t>::max(),
		         VkPerformanceCounterStorageKHR divisor_storage = VK_PERFORMANCE_COUNTER_STORAGE_FLOAT64_KHR) :
		    scaling(stat_scaling),
		    counter_index(counter_index),
		    divisor_counter_index(divisor_index),
		    storage(storage),
		    divisor_storage(divisor_storage)
		{}
	};

	struct VendorStat
	{
		VendorStat(const std::string &name, const std::string &divisor_name = "") :
		    name(name),
		    divisor_name(divisor_name)
		{
			if (divisor_name != "")
				scaling = StatScaling::ByCounter;
		}

		void set_vendor_graph_data(const StatGraphData &data)
		{
			has_vendor_graph_data = true;
			graph_data            = data;
		}

		std::string   name;
		StatScaling   scaling = StatScaling::ByDeltaTime;
		std::string   divisor_name;
		bool          has_vendor_graph_data = false;
		StatGraphData graph_data;
	};

	using StatDataMap   = std::unordered_map<StatIndex, StatData, StatIndexHash>;
	using VendorStatMap = std::unordered_map<StatIndex, VendorStat, StatIndexHash>;

  public:
	   
                                           
                                                                                                      
                                                                              
                                            
    
	VulkanStatsProvider(std::set<StatIndex> &requested_stats, const CounterSamplingConfig &sampling_config,
	                    RenderContext &render_context);

	   
                                          
    
	~VulkanStatsProvider();

	   
                                                                    
                               
                                                          
    
	bool is_available(StatIndex index) const override;

	   
                                                            
                               
    
	const StatGraphData &get_graph_data(StatIndex index) const override;

	   
                                                         
                                            
    
	Counters sample(float delta_time) override;

	   
                                                                   
                                
    
	void begin_sampling(vkb::core::CommandBufferC &cb) override;

	   
                                                                         
                                
    
	void end_sampling(vkb::core::CommandBufferC &cb) override;

  private:
	bool is_supported(const CounterSamplingConfig &sampling_config) const;

	bool fill_vendor_data();

	bool create_query_pools(uint32_t queue_family_index);

	float get_best_delta_time(float sw_delta_time) const;

  private:
	                     
	RenderContext &render_context;

	                                             
	std::unique_ptr<QueryPool> query_pool;

	                                  
	bool has_timestamps{false};

	                       
	float timestamp_period{1.0f};

	                            
	std::unique_ptr<QueryPool> timestamp_pool;

	                                   
	VendorStatMap vendor_data;

	                                                                        
	StatDataMap stat_data;

	                                            
	std::vector<uint32_t> counter_indices;

	                                    
	uint32_t queries_ready = 0;
};

}                        
