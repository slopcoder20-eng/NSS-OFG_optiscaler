/* Copyright (c) 2018-2025, Arm Limited and Contributors
 * Copyright (c) 2020-2025, Broadcom Inc.
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

#include <cstdint>
#include <ctime>
#include <future>
#include <map>
#include <set>
#include <vector>

#include "stats_common.h"
#include "stats_provider.h"
#include "timer.h"

namespace vkb
{
class RenderContext;

namespace core
{
template <vkb::BindingType bindingType>
class CommandBuffer;
using CommandBufferC = CommandBuffer<vkb::BindingType::C>;
}                         

  
                                                                        
   
class Stats
{
  public:
	   
                                    
                                                           
                                                   
    
	explicit Stats(RenderContext &render_context, size_t buffer_size = 16);

	   
                                    
    
	~Stats();

	   
                                                        
                                                                    
                                                                              
    
	void request_stats(const std::set<StatIndex> &requested_stats,
	                   CounterSamplingConfig      sampling_config = {CounterSamplingMode::Polling});

	   
                                                                         
                                        
    
	void resize(size_t width);

	   
                                                                         
                               
                                                          
    
	bool is_available(StatIndex index) const;

	   
                                                                  
                                                     
                                          
    
	const StatGraphData &get_graph_data(StatIndex index) const;

	   
                                                              
                                                     
                                          
    
	const std::vector<float> &get_data(StatIndex index) const
	{
		return counters.at(index);
	};

	   
                               
    
	const std::set<StatIndex> &get_requested_stats() const
	{
		return requested_stats;
	}

	   
                                                              
                                            
    
	void update(float delta_time);

	   
                                                                              
   
                                                                               
                                                                               
                                                                              
                                                                               
                                                                              
                                                                             
                               
                                
    
	void begin_sampling(vkb::core::CommandBufferC &cb);

	   
                                                                                    
   
                                                                               
                                                                               
                                                                              
                                                                               
                                                                             
                                                                                   
                                     
                                
    
	void end_sampling(vkb::core::CommandBufferC &cb);

  private:
	                      
	RenderContext &render_context;

	                                                             
	std::set<StatIndex> requested_stats;

	                                    
	StatsProvider *frame_time_provider;

	                                                      
	std::vector<std::unique_ptr<StatsProvider>> providers;

	                                  
	CounterSamplingConfig sampling_config;

	                                
	size_t buffer_size;

	                                                       
	Timer main_timer;

	                                                                
	Timer worker_timer;

	                                       
	float alpha_smoothing{0.2f};

	                                     
	std::map<StatIndex, std::vector<float>> counters{};

	                                         
	std::thread worker_thread;

	                                     
	std::unique_ptr<std::promise<void>> stop_worker;

	                                                                 
	std::mutex continuous_sampling_mutex;

	                                               
	std::vector<StatsProvider::Counters> continuous_samples;

	                                                                                   
	bool should_add_to_continuous_samples{false};

	                                       
	std::vector<StatsProvider::Counters> pending_samples;

	                                                                        
	float fractional_pending_samples{0.0f};

	                                                       
	                                                               
	void continuous_sampling_worker(std::future<void> should_terminate);

	                                                     
	void push_sample(const StatsProvider::Counters &sample);

	                                      
	void profile_counters() const;
};

}                        
