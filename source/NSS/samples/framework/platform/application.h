/* Copyright (c) 2019-2026, Arm Limited and Contributors
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
#include <string>

#include "debug_info.h"
#include "drawer.h"
#include "platform/configuration.h"
#include "platform/input_events.h"
#include "timer.h"

namespace vkb
{
class Window;

struct ApplicationOptions
{
	bool    benchmark_enabled{false};
	Window *window{nullptr};

	                                                                             
	                                                                        
	std::unordered_map<std::string, std::string> app_arguments{};
};

class Application
{
  public:
	Application();

	virtual ~Application() = default;

	   
                                                 
    
	virtual bool prepare(const ApplicationOptions &options);

	   
                                  
                                                    
    
	virtual void update(float delta_time);

	   
                                          
                                                         
                                                                   
    
	virtual void update_overlay(
	    float delta_time, const std::function<void()> &additional_ui = []() {});

	   
                                              
    
	virtual void finish();

	   
                                         
                                        
                                          
    
	virtual bool resize(const uint32_t width, const uint32_t height);

	   
                                             
                                             
    
	virtual void input_event(const InputEvent &input_event);

	   
                                                   
    
	virtual Drawer *get_drawer();

	const std::string &get_name() const;

	void set_name(const std::string &name);

	DebugInfo &get_debug_info();

	inline bool should_close() const
	{
		return requested_close;
	}

	                           
	                                                         
	inline void close()
	{
		requested_close = true;
	}

	   
                                                                           
                                                                 
    
	static void set_shading_language(const vkb::ShadingLanguage language);

	   
                                                                                        
    
	static vkb::ShadingLanguage get_shading_language();

	   
                                                                                 
    
	static std::string get_shader_folder();

  protected:
	float fps{0.0f};

	float frame_time{0.0f};                

	uint32_t frame_count{0};

	uint32_t last_frame_count{0};

	bool lock_simulation_speed{false};

	Window *window{nullptr};

  private:
	std::string name{};

	                            
	DebugInfo debug_info{};

	bool requested_close{false};

	                                                                                                          
	inline static vkb::ShadingLanguage shading_language{vkb::ShadingLanguage::GLSL};
};

inline void Application::set_shading_language(const vkb::ShadingLanguage language)
{
	shading_language = language;
}

inline vkb::ShadingLanguage Application::get_shading_language()
{
	return shading_language;
}

inline std::string Application::get_shader_folder()
{
	switch (shading_language)
	{
		case ShadingLanguage::HLSL:
			return "hlsl";
		case ShadingLanguage::SLANG:
			return "slang";
		default:
			return "glsl";
	}
}

}                        
