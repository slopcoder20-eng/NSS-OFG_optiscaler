/* Copyright (c) 2020-2024, Arm Limited and Contributors
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

#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "platform/application.h"

  
  
                                                                                                                      
                                                                                                                             
                                                                                  
  
   

namespace apps
{
using CreateFunc = std::function<std::unique_ptr<vkb::Application>()>;

  
                                                                                                            
   

class AppInfo
{
  public:
	AppInfo(const std::string &id, const CreateFunc &create) :
	    id(id), create(create)
	{}

	std::string id;
	CreateFunc  create;
};

  
                                                                                                               
   

class SampleInfo : public AppInfo
{
  public:
	SampleInfo(const std::string &id, const CreateFunc &create, const std::string &category, const std::string &author, const std::string &name, const std::string &description, const std::vector<std::string> &tags = {}) :
	    AppInfo(id, create), category(category), author(author), name(name), description(description), tags(tags)
	{}

	std::string              category;
	std::string              author;
	std::string              name;
	std::string              description;
	std::vector<std::string> tags;
};

   
                            
  
                                 
                                       
   
AppInfo *get_app(const std::string &id);

   
                      
  
                                                          
   
std::vector<AppInfo *> get_apps();

   
                         
  
                                                                                                          
                                                                                              
                                                   
   
std::vector<AppInfo *> get_samples(const std::vector<std::string> &categories = {}, const std::vector<std::string> &tags = {});

SampleInfo *get_sample(const std::string &id);
}                         
