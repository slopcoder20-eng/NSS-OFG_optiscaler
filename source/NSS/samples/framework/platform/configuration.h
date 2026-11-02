/* Copyright (c) 2019-2025, Arm Limited and Contributors
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

#include <algorithm>
#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <typeindex>
#include <unordered_map>
#include <vector>

namespace vkb
{
class Setting
{
  public:
	Setting() = default;

	Setting(Setting &&other) = default;

	virtual ~Setting()
	{}

	virtual void set() = 0;

	virtual std::type_index get_type() = 0;
};

class BoolSetting : public Setting
{
  public:
	BoolSetting(bool &handle, bool value);

	virtual void set() override;

	virtual std::type_index get_type() override;

  private:
	bool &handle;

	bool value;
};

class IntSetting : public Setting
{
  public:
	IntSetting(int &handle, int value);

	virtual void set() override;

	virtual std::type_index get_type() override;

  private:
	int &handle;

	int value;
};

class EmptySetting : public Setting
{
  public:
	EmptySetting();

	virtual void set() override;

	virtual std::type_index get_type() override;
};

using ConfigMap = std::map<uint32_t, std::unordered_map<std::type_index, std::vector<Setting *>>>;

   
                                                                
   
class Configuration
{
  public:
	   
                      
    
	Configuration() = default;

	   
                                                        
    
	void set();

	   
                                             
                                                                       
    
	bool next();

	   
                                                
    
	void reset();

	   
                                                           
                                                                    
                                                                  
    
	void insert_setting(uint32_t config_index, std::unique_ptr<Setting> setting);

	   
                                                           
                                                                    
                                                                                         
    
	template <class T, class... A>
	void insert(uint32_t config_index, A &&... args)
	{
		static_assert(std::is_base_of<Setting, T>::value,
		              "T is not a type of setting.");

		insert_setting(config_index, std::make_unique<T>(args...));
	}

  protected:
	ConfigMap configs;

	std::vector<std::unique_ptr<Setting>> settings;

	ConfigMap::iterator current_configuration;
};
}                        
