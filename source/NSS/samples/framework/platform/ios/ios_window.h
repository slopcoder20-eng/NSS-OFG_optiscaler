/* Copyright (c) 2023-2025, Holochip Inc.
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
#include "platform/window.h"

#import <UIKit/UIKit.h>

@interface VulkanView : UIView
@end

namespace vkb
{
class IosPlatform;

   
                                                                                                        
                                                                                              
   
class IosWindow : public Window
{
  public:
	   
                      
                                                           
                                          
    
	IosWindow(IosPlatform *platform, const Window::Properties &properties);

	~IosWindow() override = default;

	   
                                                        
                                                       
    
	VkSurfaceKHR create_surface(vkb::core::InstanceC &instance) override;

	   
                                                        
                                                
    
	VkSurfaceKHR create_surface(VkInstance instance, VkPhysicalDevice physical_device) override;

	void process_events() override;

	bool should_close() override;

	void close() override;

	float get_dpi_factor() const override;

	float get_content_scale_factor() const override;

	std::vector<const char *> get_required_surface_extensions() const override;
    
    VulkanView * get_vulkan_view() {return view;}
    void set_vulkan_view(VulkanView* _view) { view = _view; }

  private:
    VulkanView * view;
	IosPlatform *platform;

	bool finish_called{false};
};
}                        
