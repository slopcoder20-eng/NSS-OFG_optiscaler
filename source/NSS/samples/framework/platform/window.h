/* Copyright (c) 2018-2025, Arm Limited and Contributors
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

#include "common/optional.h"
#include "common/vk_common.h"
#include "core/instance.h"

namespace vkb
{
   
                                                                 
   
class Window
{
  public:
	struct Extent
	{
		uint32_t width;
		uint32_t height;
	};

	struct OptionalExtent
	{
		Optional<uint32_t> width;
		Optional<uint32_t> height;
	};

	enum class Mode
	{
		Headless,
		Fullscreen,
		FullscreenBorderless,
		FullscreenStretch,
		Default
	};

	enum class Vsync
	{
		OFF,
		ON,
		Default
	};

	struct OptionalProperties
	{
		Optional<std::string> title;
		Optional<Mode>        mode;
		Optional<bool>        resizable;
		Optional<Vsync>       vsync;
		OptionalExtent        extent;
	};

	struct Properties
	{
		std::string title     = "";
		Mode        mode      = Mode::Default;
		bool        resizable = true;
		Vsync       vsync     = Vsync::Default;
		Extent      extent    = {1280, 720};
	};

	   
                              
                                                               
    
	Window(const Properties &properties);

	virtual ~Window() = default;

	   
                                                           
                                     
                                                              
    
	virtual VkSurfaceKHR create_surface(vkb::core::InstanceC &instance) = 0;

	   
                                                           
                                     
                                                  
                                                              
    
	virtual VkSurfaceKHR create_surface(VkInstance instance, VkPhysicalDevice physical_device) = 0;

	   
                                                
    
	virtual bool should_close() = 0;

	   
                                                                 
    
	virtual void process_events();

	   
                                       
    
	virtual void close() = 0;

	   
                                         
    
	virtual float get_dpi_factor() const = 0;

	   
                                                                                        
    
	virtual float get_content_scale_factor() const;

	   
                                                                  
   
                                             
                                        
    
	Extent resize(const Extent &extent);

	   
                                                                
   
                                                      
                                                             
                                                               
                                                                     
                                                                                       
    
	virtual bool get_display_present_info(VkDisplayPresentInfoKHR *info,
	                                      uint32_t src_width, uint32_t src_height) const;

	virtual std::vector<const char *> get_required_surface_extensions() const = 0;

	const Extent &get_extent() const;

	Mode get_window_mode() const;

	inline const Properties &get_properties() const
	{
		return properties;
	}

  protected:
	Properties properties;
};
}                        
