#include "pch.h"
#include "LibraryLoad_Hooks.h"

#include <Config.h>
#include <DllNames.h>

#include <proxies/Ntdll_Proxy.h>
#include <proxies/Kernel32_Proxy.h>
#include <proxies/Dxgi_Proxy.h>
#include <proxies/D3D12_Proxy.h>

#include <proxies/XeSS_Proxy.h>
#include <proxies/XeFG_Proxy.h>
#include <proxies/XeLL_Proxy.h>
#include <inputs/FG/XeFG_Inputs_Dx12.h>
#include <proxies/NVNGX_Proxy.h>
#include <proxies/FfxApi_Proxy.h>

#include <inputs/FSR2_Dx12.h>
#include <inputs/FSR3_Dx12.h>
#include <inputs/FfxApiExe_Dx12.h>

#include <spoofing/Dxgi_Spoofing.h>

#include <hooks/Dxgi_Hooks.h>
#include <hooks/D3D11_Hooks.h>
#include <hooks/D3D12_Hooks.h>
#include <hooks/Vulkan_Hooks.h>
#include <hooks/Gdi32_Hooks.h>
#include <hooks/Streamline_Hooks.h>
#include <hooks/Amdxc64_Hooks.h>

#include <misc/IdentifyGpu.h>
#include <low_latency/input/input_uell.h>

                             

HMODULE LibraryLoadHooks::LoadLibraryCheckA(std::string libName, LPCSTR lpLibFullPath)
{
    auto fullPath = std::string(lpLibFullPath);

    return LoadLibraryCheckW(string_to_wstring(libName), string_to_wstring(fullPath).c_str());
}

HMODULE LibraryLoadHooks::LoadLibraryCheckW(std::wstring libName, LPCWSTR lpLibFullPath)
{
    auto libNameA = wstring_to_string(libName);

#ifdef LOG_LIB_OPERATIONS
    LOG_TRACE("{}", libNameA);
#endif

                               
    auto path = std::filesystem::path(libName).lexically_normal();
    auto normalizedPath = path.wstring();
    to_lower_in_place(normalizedPath);

    std::filesystem::path localSlPath(Config::Instance()->MainDllPath.value());
    localSlPath = localSlPath / L"streamline";                               
    auto normalizedLocalSlPath = localSlPath.lexically_normal();

    const bool pathInsideLocalSlPath = Util::IsSubpath(path, normalizedLocalSlPath);

               
    auto exePath = Util::ExePath().parent_path().wstring();

    for (size_t i = 0; i < exePath.size(); i++)
        exePath[i] = std::tolower(exePath[i]);

    auto pos = libName.rfind(exePath);

    if (Config::Instance()->EnableDlssInputs.value_or_default() && CheckDllNameW(&libName, &nvngxNamesW) &&
        (!Config::Instance()->HookOriginalNvngxOnly.value_or_default() || pos == std::string::npos))
    {
        LOG_INFO("nvngx call: {0}, returning this dll!", libNameA);

                          
                       

        return dllModule;
    }

    if ((State::Instance().workingMode != WorkingMode::Dxgi || !State::Instance().skipDxgiLoadChecks) &&
        CheckDllNameW(&libName, &dllNamesW))
    {
        if (!State::Instance().ServeOriginal())
        {
            LOG_INFO("{} call, returning this dll!", libNameA);
            return dllModule;
        }
        else
        {
            LOG_INFO("{} call, ServeOriginal active returning original dll!", libNameA);
            return originalModule;
        }
    }

                 
    if (Config::Instance()->DLSSEnabled.value_or_default() && Config::Instance()->NVNGX_DLSS_Library.has_value() &&
        CheckDllNameW(&libName, &nvngxDlssNamesW))
    {
        auto nvngxDlss = LoadNvngxDlss(libName);

        if (nvngxDlss != nullptr)
            return nvngxDlss;
        else
            LOG_ERROR("Trying to load dll: {}", libNameA);
    }

              
                                        
                                                                                     
    if (libName.ends_with(L".bin"))
    {
        auto loadedBin = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        if (loadedBin && normalizedPath.contains(L"\\versions\\"))
        {
            if (normalizedPath.contains(L"\\dlss\\"))
            {
                State::Instance().NGX_OTA_Dlss = wstring_to_string(lpLibFullPath);
            }

            if (normalizedPath.contains(L"\\dlssd\\"))
            {
                State::Instance().NGX_OTA_Dlssd = wstring_to_string(lpLibFullPath);
            }
        }
        return loadedBin;
    }

                  
    if (CheckDllNameW(&libName, &nvapiNamesW))
    {
        LOG_INFO("{} call!", libNameA);

        return LibraryLoadHooks::LoadNvApi();
    }

                                                                                   
    const bool shouldHookSl = !pathInsideLocalSlPath || State::Instance().activeFgInput == FGInput::NvngxFG;

                        
    if (CheckDllNameW(&libName, &slInterposerNamesW) && shouldHookSl)
    {
        auto streamlineModule = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        if (streamlineModule != nullptr && streamlineModule != State::Instance().optiSlInterposer)
        {
            StreamlineHooks::hookInterposer(streamlineModule);
            slInterposerModule = streamlineModule;
        }
        else
        {
            LOG_ERROR("Trying to load dll: {}", libNameA);
        }

        return streamlineModule;
    }

                  
                                        
                                                                                       
    if (shouldHookSl && (CheckDllNameW(&libName, &slDlssNamesW) ||
                         (normalizedPath.contains(L"\\versions\\") && normalizedPath.contains(L"\\sl_dlss_0"))))
    {
        auto dlssModule = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        std::scoped_lock lock(StreamlineHooks::mutexHookDlss);

        if (dlssModule != nullptr)
        {
            StreamlineHooks::hookDlss(dlssModule);
        }
        else
        {
            LOG_ERROR("Trying to load dll as sl.dlss: {}", libNameA);
        }

        return dlssModule;
    }

                    
    if ((CheckDllNameW(&libName, &slDlssgNamesW) ||
         (normalizedPath.contains(L"\\versions\\") && normalizedPath.contains(L"\\sl_dlss_g_"))))
    {
        auto dlssgModule = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        std::scoped_lock lock1(StreamlineHooks::mutexHookDlssg);
        std::scoped_lock lock2(StreamlineHooks::mutexHookLocalDlssg);

        if (dlssgModule != nullptr)
        {
            const bool localDlssg = pathInsideLocalSlPath && State::Instance().activeFgOutput == FGOutput::DLSSG;

            if (!localDlssg && dlssgModule != State::Instance().optiSlDLSSG)
                StreamlineHooks::hookDlssg(dlssgModule);
            else
                StreamlineHooks::hookLocalDlssg(dlssgModule);
        }
        else
        {
            LOG_ERROR("Trying to load dll as sl.dlss_g: {}", libNameA);
        }

        return dlssgModule;
    }

                    
    if (shouldHookSl && (CheckDllNameW(&libName, &slReflexNamesW) ||
                         (normalizedPath.contains(L"\\versions\\") && normalizedPath.contains(L"\\sl_reflex_"))))
    {
        auto reflexModule = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        std::scoped_lock lock(StreamlineHooks::mutexHookReflex);

        if (reflexModule != nullptr && reflexModule != State::Instance().optiSlReflex)
        {
            StreamlineHooks::hookReflex(reflexModule);
        }
        else
        {
            LOG_ERROR("Trying to load dll as sl.reflex: {}", libNameA);
        }

        return reflexModule;
    }

                 
    if (shouldHookSl && (CheckDllNameW(&libName, &slPclNamesW) ||
                         (normalizedPath.contains(L"\\versions\\") && normalizedPath.contains(L"\\sl_pcl_"))))
    {
        auto pclModule = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        std::scoped_lock lock(StreamlineHooks::mutexHookPcl);

        if (pclModule != nullptr && pclModule != State::Instance().optiSlPCL)
        {
            StreamlineHooks::hookPcl(pclModule);
        }
        else
        {
            LOG_ERROR("Trying to load dll as sl.pcl: {}", libNameA);
        }

        return pclModule;
    }

                    
    if (shouldHookSl && (CheckDllNameW(&libName, &slCommonNamesW) ||
                         (normalizedPath.contains(L"\\versions\\") && normalizedPath.contains(L"\\sl_common_"))))
    {
        auto commonModule = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);

        std::scoped_lock lock(StreamlineHooks::mutexHookCommon);

        if (commonModule != nullptr && commonModule != State::Instance().optiSlCommon)
        {
            StreamlineHooks::hookCommon(commonModule);
        }
        else
        {
            LOG_ERROR("Trying to load dll as sl.common: {}", libNameA);
        }

        return commonModule;
    }

                                                                                     
    if (!Config::Instance()->DisableOverlays.has_value() && State::Instance().activeFgOutput != FGOutput::NoFG &&
        CheckDllNameW(&libName, &eosOverlayNamesW))
    {
        LOG_DEBUG("Blocking overlay dll: {}", wstring_to_string(libName));
        return (HMODULE) 1337;
    }

    if (CheckDllNameW(&libName, &blockedDllNamesW))
    {
        LOG_DEBUG("Blocking dll: {}", wstring_to_string(libName));
        return (HMODULE) 1337;
    }
    else if (Config::Instance()->DisableOverlays.value_or_default() && CheckDllNameW(&libName, &blockOverlayNamesW))
    {
        LOG_DEBUG("Blocking overlay dll: {}", wstring_to_string(libName));
        return (HMODULE) 1337;
    }
    else if (CheckDllNameW(&libName, &overlayNamesW))
    {
                                                                                
                                                
                                  
                                                                     
                                                                                                         
                                                         
                                  
                                                          

        std::filesystem::path path(libName);
        auto dllName = path.filename().string();

        thread_local bool insideThisCode = false;
        if (insideThisCode)
            return nullptr;

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        LOG_DEBUG("Overlay dll: {}, module: {:X}", wstring_to_string(libName), (size_t) module);

        if (module != nullptr)
        {
            if (DxgiProxy::Module() != nullptr)
            {
                LOG_INFO("Calling CreateDxgiFactory methods for overlay!");
                IDXGIFactory* factory = nullptr;
                IDXGIFactory1* factory1 = nullptr;
                IDXGIFactory2* factory2 = nullptr;

                auto ocResult = DxgiProxy::CreateDxgiFactory_()(__uuidof(factory), &factory);
                LOG_DEBUG("CreateDxgiFactory result: {:X}", ocResult);

                if (ocResult == S_OK && factory != nullptr)
                {
                    insideThisCode = true;
                    LOG_DEBUG("CreateDxgiFactory ok");
                    factory->Release();
                }

                ocResult = DxgiProxy::CreateDxgiFactory1_()(__uuidof(factory1), &factory1);
                LOG_DEBUG("CreateDxgiFactory1 result: {:X}", ocResult);

                if (ocResult == S_OK && factory1 != nullptr)
                {
                    LOG_DEBUG("CreateDxgiFactory1 ok");
                    factory1->Release();
                }

                ocResult = DxgiProxy::CreateDxgiFactory2_()(0, __uuidof(factory2), &factory2);
                LOG_DEBUG("CreateDxgiFactory2 result: {:X}", ocResult);

                if (ocResult == S_OK && factory2 != nullptr)
                {
                    LOG_DEBUG("CreateDxgiFactory2 ok");
                    factory2->Release();
                }
            }

            return module;
        }
    }

            
    if (CheckDllNameW(&libName, &dx11NamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
            D3D11Hooks::Hook(module);

        return module;
    }

    if (CheckDllNameW(&libName, &dx12NamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
        {
            D3d12Proxy::Init(module);
            D3D12Hooks::Hook();
        }

        return module;
    }

    if (CheckDllNameW(&libName, &dx12agilityNamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
            D3D12Hooks::HookAgility(module);

        return module;
    }

    if (CheckDllNameW(&libName, &vkNamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
        {
                                                                          
            GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN, L"vulkan-1", &module);
            VulkanHooks::Hook(module);
        }

        return module;
    }

    if (!State::Instance().skipDxgiLoadChecks && CheckDllNameW(&libName, &dxgiNamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);

        if (module != nullptr)
        {
            DxgiProxy::Init(module);
            DxgiHooks::Hook();
        }
    }

    if (CheckDllNameW(&libName, &fsr2NamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
            HookFSR2Inputs(module);

        return module;
    }

    if (CheckDllNameW(&libName, &fsr2BENamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
            HookFSR2Dx12Inputs(module);

        return module;
    }

    if (CheckDllNameW(&libName, &fsr3NamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
            HookFSR3Inputs(module);

        return module;
    }

    if (CheckDllNameW(&libName, &fsr3BENamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (module != nullptr)
            HookFSR3Dx12Inputs(module);

        return module;
    }

    if (CheckDllNameW(&libName, &xessNamesW))
    {
        if (XeSSProxy::Module() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(XeSSProxy::Module_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            XeSSProxy::InitXeSS(module);

        return module;
    }

                                                     
    if (CheckDllNameW(&libName, &xefgNamesW))
    {
        auto module = NtdllProxy::LoadLibraryExW_Ldr(lpLibFullPath, NULL, 0);
        XeFGInputs::Hook(module);
        return module;
    }

    if (CheckDllNameW(&libName, &xessDx11NamesW))
    {
        if (XeSSProxy::ModuleDx11() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(XeSSProxy::ModuleDx11_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            XeSSProxy::InitXeSSDx11(module);

        return module;
    }

    if (CheckDllNameW(&libName, &amdxc64NamesW))
    {
        HMODULE moduleAmdxc64 = nullptr;

        if (Config::Instance()->LoadCustomAmdxc64OnRdna2.value_or_default())
        {
            auto allDetectedGpus = IdentifyGpu::getAllGpus();
            GpuInformation gpuMatchingDriverStore {};

            for (auto& gpu : allDetectedGpus)
            {
                                              
                if (Util::IsSubpath(path, gpu.driverStore))
                {
                    gpuMatchingDriverStore = gpu;
                    break;
                }
            }

                                 
            if (gpuMatchingDriverStore.amdHwGeneration == device_info::HwGeneration::kGfx10_3)
            {
                LOG_INFO("Trying to loading custom amdxc64.dll");

                HMODULE memModule = nullptr;
                auto& optiPath = Config::Instance()->MainDllPath.value();
                Util::LoadProxyLibrary(L"amdxc64.dll", L"", optiPath, &memModule, &moduleAmdxc64);

                if (moduleAmdxc64 == nullptr && memModule != nullptr)
                    moduleAmdxc64 = memModule;
            }
        }

        if (moduleAmdxc64 == nullptr && !Config::Instance()->Fsr4DoNotLoadAmdxc64.value_or_default())
            moduleAmdxc64 = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, 0);

        if (moduleAmdxc64 != nullptr)
            Amdxc64Hooks::Init();

        return moduleAmdxc64;
    }

    if (CheckDllNameW(&libName, &ffxDx12NamesW))
    {
        if (FfxApiProxy::Dx12Module() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(FfxApiProxy::Dx12Module_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            FfxApiProxy::InitFfxDx12(module);

        return module;
    }

    if (CheckDllNameW(&libName, &ffxDx12UpscalerNamesW))
    {
        if (FfxApiProxy::Dx12Module_SR() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(FfxApiProxy::Dx12Module_SR_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            FfxApiProxy::InitFfxDx12_SR(module);

        return module;
    }

    if (CheckDllNameW(&libName, &ffxDx12FGNamesW))
    {
        if (FfxApiProxy::Dx12Module_FG() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(FfxApiProxy::Dx12Module_FG_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            FfxApiProxy::InitFfxDx12_FG(module);

        return module;
    }

    if (CheckDllNameW(&libName, &ffxVkNamesW))
    {
                                                                                                                 
        const bool sameBackend = CheckDllNameW(&libName, &ffxVkLegacyNamesW) != FfxApiProxy::VkModule_BackendV2();

        if (FfxApiProxy::VkModule() != nullptr &&
            (sameBackend || Config::Instance()->EnableFfxInputs.value_or_default()))
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(FfxApiProxy::VkModule_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            FfxApiProxy::InitFfxVk(module);

        return module;
    }

    if (CheckDllNameW(&libName, &ffxVkUpscalerNamesW))
    {
        if (FfxApiProxy::VkModule_SR() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(FfxApiProxy::VkModule_SR_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            FfxApiProxy::InitFfxVk_SR(module);

        return module;
    }

    if (CheckDllNameW(&libName, &ffxVkFGNamesW))
    {
        if (FfxApiProxy::VkModule_FG() != nullptr)
        {
            auto module = NtdllProxy::LoadLibraryExW_Ldr(FfxApiProxy::VkModule_FG_Path().c_str(), NULL, NULL);
            return module;
        }

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module != nullptr)
            FfxApiProxy::InitFfxVk_FG(module);

        return module;
    }

           
                                                                                                    
    if (CheckDllNameW(&libName, &uellNamesW))
    {
        LOG_INFO("{} call!", libNameA);

        auto module = NtdllProxy::LoadLibraryExW_Ldr(libName.c_str(), NULL, NULL);

        if (module)
        {
            auto setTickStartCallback =
                (PFN_setTickCallback) KernelBaseProxy::GetProcAddress_()(module, "setTickStartCallback");
            auto setTickEndCallback =
                (PFN_setTickCallback) KernelBaseProxy::GetProcAddress_()(module, "setTickEndCallback");
            auto setCameraUpdateCallback =
                (PFN_setCameraUpdateExternal) KernelBaseProxy::GetProcAddress_()(module, "setCameraUpdateCallback");

            if (setTickStartCallback)
                setTickStartCallback(InputUeLowLatency::tickStart);

            if (setTickEndCallback)
                setTickEndCallback(InputUeLowLatency::tickEnd);

            if (setCameraUpdateCallback)
                setCameraUpdateCallback(InputUeLowLatency::cameraUpdate);
        }

        return module;
    }

    CheckModulesInMemory();

    return nullptr;
}

std::optional<NTSTATUS> LibraryLoadHooks::FreeLibrary(PVOID lpLibrary)
{
    std::optional<NTSTATUS> result;

    if (lpLibrary == dllModule)
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for OptiScaler, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == FfxApiProxy::Dx12Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for FFX Dx12, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == FfxApiProxy::Dx12Module_SR())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for FFX Dx12 SR, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == FfxApiProxy::Dx12Module_FG())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for FFX Dx12 FG, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == FfxApiProxy::VkModule())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for FFX Vulkan, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == FfxApiProxy::VkModule_SR())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for FFX Vulkan SR, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == FfxApiProxy::VkModule_FG())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for FFX Vulkan FG, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == XeSSProxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for XeSS, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == XeSSProxy::ModuleDx11())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for XeSS Dx11, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == XeLLProxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for XeLL, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == XeFGProxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for XeFG, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == DxgiProxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for DXGI, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == D3d12Proxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for D3D12, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == Kernel32Proxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for Kernel32, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == KernelBaseProxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for KernelBase, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == NtdllProxy::Module())
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for ntdll, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == vulkanModule)
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for Vulkan, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }
    else if (lpLibrary == d3d11Module)
    {
#ifdef LOG_LIB_OPERATIONS
        LOG_WARN("Call for D3D11, caller: {}", Util::WhoIsTheCaller(_ReturnAddress()));
#endif
        result = TRUE;
    }

                                                                                                      
    if (result.has_value())
    {
        std::scoped_lock lock(State::Instance().modulesToFreeMutex);
        State::Instance().modulesToFree.insert(lpLibrary);
    }

    return result;
}

void LibraryLoadHooks::AfterFreeLibrary(PVOID lpLibrary)
{
    if (lpLibrary == nullptr || State::Instance().isShuttingDown)
        return;

                                                                                                        
                                                                                              
    StreamlineHooks::onModuleFreed(lpLibrary);
}

void LibraryLoadHooks::AfterLoadLibrary(HMODULE library)
{
    if (library == nullptr || State::Instance().isShuttingDown)
        return;

                                                                                         
    if (auto libxell = KernelBaseProxy::GetModuleHandleW_()(L"libxell.dll"))
        XeLLProxy::RedirectToInput(libxell);

                                          
    wchar_t path[MAX_PATH];

    if (GetModuleFileNameW(library, path, MAX_PATH) != 0 &&
        EndsWithInsensitive(std::wstring_view(path), std::wstring_view(L"\\libxell.dll")))
    {
        XeLLProxy::RedirectToInput(library);
    }
}

HMODULE LibraryLoadHooks::LoadNvApi()
{
    LOG_FUNC();

    HMODULE nvapi = nullptr;

                                                            
    if (Config::Instance()->UseFakenvapi.value_or_default() &&
        IdentifyGpu::getPrimaryGpu().vendorId != VendorId::Nvidia)
    {
        nvapi = dllModule;
        fakenvapi::setUsingAsMainNvapi(true);

        if (GetModuleHandleW(L"nvapi64.dll"))
            LOG_WARN("nvapi64.dll is loaded when Nvidia is not the primary GPU");
    }

                                                                         
    if (nvapi == nullptr)
        nvapi = NtdllProxy::LoadLibraryExW_Ldr(L"nvapi64.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);

                                              
    if (Config::Instance()->UseFakenvapi.value_or_default() && nvapi == nullptr)
    {
        LOG_WARN("Using fakenvapi on Nvidia as the main nvapi");
        nvapi = dllModule;
        fakenvapi::setUsingAsMainNvapi(true);
    }

    if (nvapi != nullptr)
        NvApiHooks::Hook(nvapi);

    return nvapi;
}

HMODULE LibraryLoadHooks::LoadNvngxDlss(std::wstring originalPath)
{
    HMODULE nvngxDlss = nullptr;

    if (Config::Instance()->NVNGX_DLSS_Library.has_value())
    {
        nvngxDlss = NtdllProxy::LoadLibraryExW_Ldr(Config::Instance()->NVNGX_DLSS_Library.value().c_str(), NULL, 0);

        if (nvngxDlss != nullptr)
        {
            LOG_INFO("nvngx_dlss.dll loaded from {0}",
                     wstring_to_string(Config::Instance()->NVNGX_DLSS_Library.value()));
            return nvngxDlss;
        }
        else
        {
            LOG_WARN("nvngx_dlss.dll can't found at {0}",
                     wstring_to_string(Config::Instance()->NVNGX_DLSS_Library.value()));
        }
    }

    if (nvngxDlss == nullptr)
    {
        nvngxDlss = NtdllProxy::LoadLibraryExW_Ldr(originalPath.c_str(), NULL, 0);

        if (nvngxDlss != nullptr)
        {
            LOG_INFO("nvngx_dlss.dll loaded from {0}", wstring_to_string(originalPath));
            return nvngxDlss;
        }
    }

    return nullptr;
}

                                                                   
   
                                          
                                      
  
                                 
  
                                                       
        
                                                                                          
  
                                      
                                                                                  
               
                                                                                                     
  
                                  
            
                                                                                                                   
                              
            
               
            
                                                                                                                      
            
        
  
                              
        
                                                                                   
  
                                  
            
                                                                                        
                              
            
        
  
                      
    
  
                                                                       
   
                                              
                                          
  
                                 
  
                                                           
        
                                                                                              
  
                                      
                                                                                  
               
                                                                                                          
  
                                  
            
                                                           
                                                                                        
                              
            
               
            
                                                              
                                                                                        
            
        
  
                              
        
                                                                                   
  
                                  
            
                                                                                             
                              
            
        
  
                      
    
  
                                                                      
   
                                                
                                            
  
                                 
  
                                                                                                              
  
                                                   
        
                                                           
            
                                                                                              
  
                                          
                                                                                      
                   
                                                                                                      
  
                                      
                
                                                                                  
                                                                                        
                                  
                
                   
                
                                                                                     
                                                                                        
                
            
  
                                  
            
                                                                                       
  
                                      
                
                                                                                                                    
                                  
                
            
        
  
                      
    
  
                                                                    
   
                                              
                                          
  
                               
  
                                                     
        
                                                                                        
  
                                      
                                                                                
               
                                                                                                             
  
                                
            
                                                                
                                                                                       
            
               
            
                                                                   
                                                                                  
            
        
  
                            
        
                                                                                 
  
                                
            
                                                                                                  
                            
            
        
  
                      
    

void LibraryLoadHooks::CheckModulesInMemory()
{
    const auto isLocalStreamlineModule = [](HMODULE module) -> bool
    {
        if (module == nullptr)
            return false;

        char modulePath[MAX_PATH] = {};
        if (GetModuleFileNameA(module, modulePath, sizeof(modulePath)) == 0)
            return false;

        const auto path = std::filesystem::path(modulePath).lexically_normal();
        const std::filesystem::path localSlPath =
            std::filesystem::path(Config::Instance()->MainDllPath.value()) / L"streamline";
        return Util::IsSubpath(path, localSlPath.lexically_normal());
    };

    if (!StreamlineHooks::isInterposerHooked())
    {
                                                            
        HMODULE slModule = nullptr;
        slModule = GetDllNameWModule(&slInterposerNamesW);

        const bool gameInterposer =
            slModule != nullptr && slModule != State::Instance().optiSlInterposer &&
            (!isLocalStreamlineModule(slModule) || State::Instance().activeFgInput == FGInput::NvngxFG);

        if (gameInterposer)
        {
            LOG_DEBUG("sl.interposer.dll already in memory");
            StreamlineHooks::hookInterposer(slModule);
            slInterposerModule = slModule;
        }
    }

                                                                                                       
                                                                                                           
    {
        std::unique_lock lock(StreamlineHooks::mutexHookDlss, std::try_to_lock);
        if (lock.owns_lock() && !StreamlineHooks::isDlssHooked())
        {
            HMODULE slDlss = nullptr;
            slDlss = GetDllNameWModule(&slDlssNamesW);
            if (slDlss != nullptr)
            {
                LOG_DEBUG("sl.dlss.dll already in memory");
                StreamlineHooks::hookDlss(slDlss);
            }
        }
    }

             
    {
        std::unique_lock lock1(StreamlineHooks::mutexHookDlssg, std::try_to_lock);
        std::unique_lock lock2(StreamlineHooks::mutexHookLocalDlssg, std::try_to_lock);
        if (lock1.owns_lock() && lock2.owns_lock() &&
            (!StreamlineHooks::isDlssgHooked() || !StreamlineHooks::isLocalDlssgHooked()))
        {
            HMODULE slDlssg = GetDllNameWModule(&slDlssgNamesW);

            if (slDlssg != nullptr && slDlssg != State::Instance().optiSlDLSSG)
            {
                const bool localDlssg = isLocalStreamlineModule(slDlssg);

                if (localDlssg && State::Instance().activeFgOutput == FGOutput::DLSSG)
                {
                    if (!StreamlineHooks::isLocalDlssgHooked())
                    {
                        LOG_DEBUG("local sl.dlss_g.dll already in memory");
                        StreamlineHooks::hookLocalDlssg(slDlssg);
                    }
                }
                else if (!localDlssg && !StreamlineHooks::isDlssgHooked())
                {
                    LOG_DEBUG("sl.dlss_g.dll already in memory");
                    StreamlineHooks::hookDlssg(slDlssg);
                }
            }
        }
    }

             
    {
        std::unique_lock lock(StreamlineHooks::mutexHookReflex, std::try_to_lock);
        if (lock.owns_lock() && !StreamlineHooks::isReflexHooked())
        {
            HMODULE slReflex = GetDllNameWModule(&slReflexNamesW);

            if (slReflex != nullptr && slReflex != State::Instance().optiSlReflex)
            {
                const bool localReflex = isLocalStreamlineModule(slReflex);

                if (!localReflex || State::Instance().activeFgOutput != FGOutput::DLSSG)
                {
                    if (localReflex)
                        LOG_DEBUG("local sl.reflex.dll already in memory");
                    else
                        LOG_DEBUG("sl.reflex.dll already in memory");

                    StreamlineHooks::hookReflex(slReflex);
                }
            }
        }
    }

          
    {
        std::unique_lock lock(StreamlineHooks::mutexHookPcl, std::try_to_lock);
        if (lock.owns_lock() && !StreamlineHooks::isPclHooked())
        {
            HMODULE slPcl = GetDllNameWModule(&slPclNamesW);

            if (slPcl != nullptr && slPcl != State::Instance().optiSlPCL)
            {
                const bool localPcl = isLocalStreamlineModule(slPcl);

                if (!localPcl || State::Instance().activeFgOutput != FGOutput::DLSSG)
                {
                    if (localPcl)
                        LOG_DEBUG("local sl.pcl.dll already in memory");
                    else
                        LOG_DEBUG("sl.pcl.dll already in memory");

                    StreamlineHooks::hookPcl(slPcl);
                }
            }
        }
    }

    {
        std::unique_lock lock(StreamlineHooks::mutexHookCommon, std::try_to_lock);
        if (lock.owns_lock() && !StreamlineHooks::isCommonHooked())
        {
            HMODULE slCommon = nullptr;
            slCommon = GetDllNameWModule(&slCommonNamesW);
            if (slCommon != nullptr && slCommon != State::Instance().optiSlCommon)
            {
                LOG_DEBUG("sl.common.dll already in memory");
                StreamlineHooks::hookCommon(slCommon);
            }
        }
    }

             
                                          
       
                                        
                                                       
                                     
            
                                                          
                                               
            
        

                                              
       
                                            
                                                               
                                         
            
                                                               
                                                       
            
        

                 
                                                
       
                                           
                                                             
                                        
            
                                                                      
                                                       
            
        

                   
                                              
       
                                         
                                                         
                                      
            
                                                                    
                                                   
            
        
}

bool LibraryLoadHooks::EndsWithInsensitive(std::wstring_view text, std::wstring_view suffix)
{
    if (suffix.size() > text.size())
        return false;

    if (suffix.empty())
        return true;

    const wchar_t* tail = text.data() + (text.size() - suffix.size());
    const int res =
        CompareStringOrdinal(tail, static_cast<int>(suffix.size()), suffix.data(), static_cast<int>(suffix.size()),
                             TRUE);                    
    return res == CSTR_EQUAL;
}

bool LibraryLoadHooks::EndsWithInsensitive(const UNICODE_STRING& text, std::wstring_view suffix)
{
    return EndsWithInsensitive(std::wstring_view { text.Buffer, static_cast<size_t>(text.Length) / sizeof(wchar_t) },
                               suffix);
}

bool LibraryLoadHooks::StartsWithInsensitive(std::wstring_view str, std::wstring_view prefix)
{
    if (str.size() < prefix.size())
        return false;

    for (size_t i = 0; i < prefix.size(); ++i)
    {
        if (std::towlower(str[i]) != std::towlower(prefix[i]))
            return false;
    }

    return true;
}

bool LibraryLoadHooks::IsApiSetName(const std::wstring_view& n)
{
    return StartsWithInsensitive(n, L"api-ms-win-") || StartsWithInsensitive(n, L"ext-ms-") ||
           StartsWithInsensitive(n, L"api-ms-onecore-");
}
