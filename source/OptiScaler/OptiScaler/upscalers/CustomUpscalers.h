#pragma once

#include "Config.h"

#include <proxies/Ntdll_Proxy.h>

#include <filesystem>

                                                                                                                     
                                             
                                               
                                                      
                                                                                                                   
                                                                                                                    
                                                                                                 
namespace CustomUpscalers
{
inline std::filesystem::path Root()
{
    return std::filesystem::path(Config::Instance()->MainDllPath.value()) / L"custom";
}

inline std::filesystem::path Folder(const std::string& name) { return Root() / string_to_wstring(name); }

                                                           
inline std::filesystem::path DllPath(const std::string& name, const wchar_t* kind,
                                     std::initializer_list<const wchar_t*> standardNames)
{
    auto folder = Folder(name) / kind;
    std::error_code error;

    for (auto standardName : standardNames)
    {
        if (std::filesystem::exists(folder / standardName, error))
            return folder / standardName;
    }

    for (auto& entry : std::filesystem::directory_iterator(folder, error))
    {
        if (_wcsicmp(entry.path().extension().c_str(), L".dll") == 0)
            return entry.path();
    }

    return {};
}

inline std::filesystem::path FfxDllPath(const std::string& name)
{
    return DllPath(name, L"ffx", { L"amd_fidelityfx_upscaler_dx12.dll" });
}

inline std::filesystem::path FfxVkDllPath(const std::string& name)
{
    return DllPath(name, L"ffx_vk", { L"amd_fidelityfx_upscaler_vk.dll", L"amd_fidelityfx_vk.dll" });
}

                                                                                                             
inline bool IsLegacyFfxVkDll(const std::filesystem::path& path)
{
    return _wcsicmp(path.filename().c_str(), L"amd_fidelityfx_vk.dll") == 0;
}

inline std::filesystem::path NgxDllPath(const std::string& name) { return DllPath(name, L"dlss", { L"nvngx.dll" }); }

                                                            
inline HMODULE LoadDll(const std::string& name, const std::filesystem::path& path)
{
    auto dll = path.empty() ? nullptr : NtdllProxy::LoadLibraryExW_Ldr(path.c_str(), NULL, NULL);

    if (dll == nullptr)
        LOG_ERROR("Can't load custom upscaler {} from {}", name, wstring_to_string(Folder(name).wstring()));
    else
        LOG_INFO("Loaded custom upscaler {} from {}", name, wstring_to_string(path.wstring()));

    return dll;
}

struct Names
{
    std::vector<std::string> ffx;
    std::vector<std::string> ffxVk;
    std::vector<std::string> dlss;
};

               
inline const Names& Scan()
{
    static const auto names = []
    {
        Names found;
        std::error_code error;

        for (auto& entry : std::filesystem::directory_iterator(Root(), error))
        {
            auto name = wstring_to_string(entry.path().filename().wstring());

            if (!FfxDllPath(name).empty())
                found.ffx.push_back(name);

            if (!FfxVkDllPath(name).empty())
                found.ffxVk.push_back(name);

            if (!NgxDllPath(name).empty())
                found.dlss.push_back(name);
        }

        return found;
    }();

    return names;
}

                                     
inline bool Contains(const std::vector<std::string>& names, const std::string& name)
{
    return std::ranges::any_of(names, [&name](const std::string& n) { return _stricmp(n.c_str(), name.c_str()) == 0; });
}

inline bool IsFfx(const std::string& name) { return Contains(Scan().ffx, name); }
inline bool IsFfxVk(const std::string& name) { return Contains(Scan().ffxVk, name); }
inline bool IsDlss(const std::string& name) { return Contains(Scan().dlss, name); }

                                                                                         
inline void ResolveDx12Upscaler()
{
    auto cfg = Config::Instance();
    auto name = cfg->CustomUpscaler.value_or("");

    if (name.empty())
        return;

    if (IsFfx(name))
    {
        cfg->Dx12Upscaler.set_from_config(Upscaler::FFX);
    }
    else if (IsDlss(name))
    {
        cfg->Dx12Upscaler.set_from_config(Upscaler::DLSS);
    }
    else
    {
        LOG_WARN("Dx12Upscaler={} isn't an upscaler or a folder in {}", name, wstring_to_string(Root().wstring()));
        cfg->CustomUpscaler.reset();
    }
}

                                                                              
inline void ResolveVulkanUpscaler()
{
    auto cfg = Config::Instance();
    auto name = cfg->CustomUpscalerVk.value_or("");

    if (name.empty())
        return;

    if (IsFfxVk(name))
    {
        cfg->VulkanUpscaler.set_from_config(Upscaler::FFX);
    }
    else
    {
        LOG_WARN("VulkanUpscaler={} isn't an upscaler or a folder with ffx_vk in {}", name,
                 wstring_to_string(Root().wstring()));
        cfg->CustomUpscalerVk.reset();
    }
}
}                             
