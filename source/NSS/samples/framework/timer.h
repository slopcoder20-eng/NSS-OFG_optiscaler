/* Copyright (c) 2019-2020, Arm Limited and Contributors
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

#include <chrono>

namespace vkb
{
   
                                                                                  
                                                           
   
class Timer
{
  public:
	using Seconds      = std::ratio<1>;
	using Milliseconds = std::ratio<1, 1000>;
	using Microseconds = std::ratio<1, 1000000>;
	using Nanoseconds  = std::ratio<1, 1000000000>;

	            
	using Clock             = std::chrono::steady_clock;
	using DefaultResolution = Seconds;

	Timer();

	virtual ~Timer() = default;

	   
                                                                             
    
	void start();

	   
                                                                                  
    
	void lap();

	   
                                                   
                                                                   
    
	template <typename T = DefaultResolution>
	double stop()
	{
		if (!running)
		{
			return 0;
		}

		running       = false;
		lapping       = false;
		auto duration = std::chrono::duration<double, T>(Clock::now() - start_time);
		start_time    = Clock::now();
		lap_time      = Clock::now();

		return duration.count();
	}

	   
                                                                                    
                                                                                   
                                                                         
    
	template <typename T = DefaultResolution>
	double elapsed()
	{
		if (!running)
		{
			return 0;
		}

		Clock::time_point start = start_time;

		if (lapping)
		{
			start = lap_time;
		}

		return std::chrono::duration<double, T>(Clock::now() - start).count();
	}

	   
                                                                                                
                                                                         
    
	template <typename T = DefaultResolution>
	double tick()
	{
		auto now      = Clock::now();
		auto duration = std::chrono::duration<double, T>(now - previous_tick);
		previous_tick = now;
		return duration.count();
	}

	   
                                        
    
	bool is_running() const;

  private:
	bool running{false};

	bool lapping{false};

	Clock::time_point start_time;

	Clock::time_point lap_time;

	Clock::time_point previous_tick;
};
}                        
