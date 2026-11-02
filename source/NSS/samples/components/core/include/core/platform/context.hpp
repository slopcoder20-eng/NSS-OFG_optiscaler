/* Copyright (c) 2023, Thomas Atkinson
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

#include <filesystem>
#include <memory>
#include <string>
#include <vector>

namespace vkb
{

                                                                                                
inline std::string find_samples_root()
{
	namespace fs = std::filesystem;
	std::error_code ec;
	auto cwd = fs::current_path(ec);
	if (ec)
		return {};

	if (fs::is_directory(cwd / "assets", ec) && fs::is_directory(cwd / "shaders", ec))
		return cwd.string();

	auto samples = cwd / "samples";
	if (fs::is_directory(samples / "assets", ec) && fs::is_directory(samples / "shaders", ec))
		return samples.string();

	return {};
}

class UnixPlatformContext;
class WindowsPlatformContext;
class AndroidPlatformContext;

   
                                                                           
  
                                                                                                                  
                        
  
                                                                                                                
                                                                                                    
   
class PlatformContext
{
	                                                                                      
	friend class UnixPlatformContext;
	friend class WindowsPlatformContext;
	friend class AndroidPlatformContext;

  public:
	virtual ~PlatformContext() = default;

	virtual const std::vector<std::string> &arguments() const
	{
		return _arguments;
	}

	virtual const std::string &external_storage_directory() const
	{
		return _external_storage_directory;
	}

	virtual const std::string &temp_directory() const
	{
		return _temp_directory;
	}

  protected:
	std::vector<std::string> _arguments;
	std::string              _external_storage_directory;
	std::string              _temp_directory;

	PlatformContext() = default;
};
}                        