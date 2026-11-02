/* Copyright (c) 2019-2026, Arm Limited and Contributors
 * Copyright (c) 2025, NVIDIA CORPORATION. All rights reserved.
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

#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include <core/platform/context.hpp>

#include "apps.h"
#include "common/optional.h"
#include "common/utils.h"
#include "common/vk_common.h"
#include "platform/application.h"
#include "platform/plugins/plugin.h"
#include "platform/window.h"
#include "rendering/render_context.h"

#if defined(VK_USE_PLATFORM_XLIB_KHR)
#	undef Success
#endif

namespace vkb
{
enum class ExitCode
{
	Success = 0,                               
	NoSample,                                                  
	Help,                                  
	Close,                                                              
	FatalError                                            
};

class Platform
{
  public:
	Platform(const PlatformContext &context);

	virtual ~Platform() = default;

	   
                                  
                                                    
                                                                   
    
	virtual ExitCode initialize(const std::vector<Plugin *> &plugins);

	   
                                                  
                                                             
    
	ExitCode main_loop();

	   
                                                    
                                                               
                                                                        
                                                             
    
	ExitCode main_loop_frame();

	   
                                             
    
	void update();

	   
                                                      
                                                       
    
	virtual void terminate(ExitCode code);

	   
                                                                     
    
	virtual void close();

	std::string &get_last_error();

	virtual void resize(uint32_t width, uint32_t height);

	virtual void input_event(const InputEvent &input_event);

	Window &get_window();

	Application &get_app() const;

	Application &get_app();

	void set_last_error(const std::string &error);

	template <class T>
	T *get_plugin() const;

	template <class T>
	bool using_plugin() const;

	void set_focus(bool focused);

	void request_application(const apps::AppInfo *app);

	bool app_requested();

	bool start_app();

	void force_simulation_fps(float fps);

	                                                                    
	void force_render(bool should_always_render);

	void disable_input_processing();

	void set_window_properties(const Window::OptionalProperties &properties);

	                                                                         
	                                                              
	void set_app_argument(const std::string &key, const std::string &value);
	const std::unordered_map<std::string, std::string> &get_app_arguments() const;

	void on_post_draw(RenderContext &context);

	static const uint32_t MIN_WINDOW_WIDTH;
	static const uint32_t MIN_WINDOW_HEIGHT;

  protected:
	std::vector<Plugin *> active_plugins;

	std::unordered_map<Hook, std::vector<Plugin *>> hooks;

	std::unique_ptr<Window> window{nullptr};

	std::unique_ptr<Application> active_app{nullptr};

	virtual std::vector<spdlog::sink_ptr> get_platform_sinks();

	   
                                             
   
                                                    
    
	virtual void create_window(const Window::Properties &properties) = 0;

	void register_hooks(Plugin *plugin);

	void on_update(float delta_time);
	void on_app_error(const std::string &app_id);
	void on_app_start(const std::string &app_id);
	void on_app_close(const std::string &app_id);
	void on_platform_close();
	void on_update_ui_overlay(vkb::Drawer &drawer);

	Window::Properties window_properties;                                                    
	bool               fixed_simulation_fps{false};                                                            
	bool               always_render{false};                                                              
	float              simulation_frame_time = 0.016f;                              
	bool               process_input_events{true};                                                      
	bool               focused{true};                                                                              
	bool               close_requested{false};                              

  protected:
	std::vector<Plugin *> plugins;

  private:
	Timer timer;

	const apps::AppInfo *requested_app{nullptr};

	std::vector<std::string> arguments;

	std::string last_error;

	std::map<std::string, Plugin *> command_map;
	std::map<std::string, Plugin *> option_map;

	std::unordered_map<std::string, std::string> app_arguments;
};

template <class T>
bool Platform::using_plugin() const
{
	return !plugins::with_tags<T>(active_plugins).empty();
}

template <class T>
T *Platform::get_plugin() const
{
	assert(using_plugin<T>() && "Plugin is not enabled but was requested");
	const auto plugins = plugins::with_tags<T>(active_plugins);
	return dynamic_cast<T *>(plugins[0]);
}
}                        
