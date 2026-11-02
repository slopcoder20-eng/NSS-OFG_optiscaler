/* Copyright (c) 2020-2025, Arm Limited and Contributors
 * Copyright (c) 2023-2025, Mobica Limited
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

#include <cassert>
#include <deque>
#include <string>
#include <typeindex>
#include <vector>

#include "common/tags.h"
#include "gui.h"

namespace vkb
{
class Platform;
class RenderContext;
class Plugin;

   
                                                                                                                 
                                                                                                                               
                                                                 
  
                                                                                                                       
                                                                                                                                   
                                                                                     
                                                                           
   
namespace tags
{
struct Entrypoint
{};
struct FullControl
{};
struct Stopping
{};
struct Passive
{};
}                         

   
                                                                                                                                                                                                               
  
                                                           
                                                                          
   
std::vector<Plugin *> associate_plugins(const std::vector<Plugin *> &plugins);

   
                                                                                                                                              
  
                                          
                                           
                                           
                                                                                   
   
enum class Hook
{
	OnUpdate,
	OnAppStart,
	OnAppClose,
	OnAppError,
	OnPlatformClose,
	PostDraw,
	OnUpdateUi
};

   
                                                                                                            
                                                            
   
class Plugin
{
  public:
	Plugin(const std::string                                       name,
	       const std::string                                       description,
	       std::vector<std::pair<std::string, std::string>> const &commands = {},
	       std::vector<std::pair<std::string, std::string>> const &options  = {}) :
	    name{name}, description{description}, commands{commands}, options{options} {};

	virtual ~Plugin() = default;

	   
                                                                      
   
                                              
    
	virtual const std::vector<Hook> &get_hooks() const = 0;

	   
                                                      
   
                                                       
    
	virtual void on_update(float delta_time) = 0;

	   
                                         
   
                                   
    
	virtual void on_app_start(const std::string &app_id) = 0;

	   
                                             
   
                                   
    
	virtual void on_app_close(const std::string &app_id) = 0;

	   
                                            
   
                                                 
    
	virtual void on_app_error(const std::string &app_id) = 0;

	   
                                                               
    
	virtual void on_platform_close() = 0;

	   
                    
    
	virtual void on_post_draw(RenderContext &context) = 0;

	   
                                         
   
                                                                        
    
	virtual void on_update_ui_overlay(vkb::Drawer &drawer) = 0;

	const std::string &get_name() const;
	const std::string &get_description() const;

	   
                                                       
   
                                  
                            
                                 
    
	template <typename C>
	bool has_tag() const
	{
		return has_tag(Tag<C>::ID);
	}

	   
                                                           
   
                           
                                  
                                           
    
	template <typename... C>
	bool has_tags() const
	{
		std::vector<TagID> query = {Tag<C>::ID...};
		bool               res   = true;
		for (auto id : query)
		{
			res &= has_tag(id);
		}
		return res;
	}

	   
                                                                            
   
                                 
                             
                                      
    
	virtual bool has_tag(TagID id) const = 0;

	std::vector<std::pair<std::string, std::string>> const &get_commands() const
	{
		return commands;
	}

	std::vector<std::pair<std::string, std::string>> const &get_options() const
	{
		return options;
	}

	virtual bool handle_command(std::deque<std::string> &arguments) const
	{
		return false;
	}

	virtual bool handle_option(std::deque<std::string> &arguments)
	{
		return false;
	}

	virtual void trigger_command()
	{}

	void log_help(size_t width) const;

	void set_platform(Platform *platform)
	{
		assert(!this->platform && platform);
		this->platform = platform;
	}

	void clear_platform()
	{
		platform = nullptr;
	}

  protected:
	Platform *platform = nullptr;

  private:
	std::string                                      name;
	std::string                                      description;
	std::vector<std::pair<std::string, std::string>> commands;
	std::vector<std::pair<std::string, std::string>> options;
};

   
                                                                                      
   
namespace plugins
{
   
                                   
                                           
  
                                                
                                             
                                                                                    
   
template <typename... TAGS>
const std::vector<Plugin *> with_tags(const std::vector<Plugin *> &domain = {})
{
	std::vector<TagID>    tags = {Tag<TAGS>::ID...};
	std::vector<Plugin *> compatable;
	for (auto ext : domain)
	{
		assert(ext != nullptr);

		bool has_one = false;
		for (auto t : tags)
		{
			has_one |= ext->has_tag(t);
		}

		if (has_one)
		{
			compatable.push_back(ext);
		}
	}
	return compatable;
}

   
                                                
                                               
                                                                 
  
                                                    
                                             
                                                                                    
   
template <typename... TAGS>
const std::vector<Plugin *> without_tags(const std::vector<Plugin *> &domain = {})
{
	std::vector<TagID>    tags = {Tag<TAGS>::ID...};
	std::vector<Plugin *> compatable;
	for (auto ext : domain)
	{
		assert(ext != nullptr);

		bool has_any = false;
		for (auto t : tags)
		{
			has_any |= ext->has_tag(t);
		}

		if (!has_any)
		{
			compatable.push_back(ext);
		}
	}
	return compatable;
}
}                            
}                        