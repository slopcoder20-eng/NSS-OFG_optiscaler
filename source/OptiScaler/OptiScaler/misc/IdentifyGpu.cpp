#include "pch.h"
#include "IdentifyGpu.h"

#include <magic_enum.hpp>
#include <include/device_info/device_info.hpp>

#include <proxies/Dxgi_Proxy.h>
#include <proxies/D3d12_Proxy.h>
#include "nvapi/NvApiTypes.h"
#include <hooks/Amdxc64_Hooks.h>

using Microsoft::WRL::ComPtr;

                                                                                              
static std::optional<device_info::CardInfo> GetAmdCardInfo(const GpuInformation& gpuInfo)
{
    if (auto cardInfo = device_info::GetCardInfo({ gpuInfo.vendorId, gpuInfo.deviceId, gpuInfo.revisionId }))
        return cardInfo;

    return device_info::GetCardInfo({ gpuInfo.vendorId, gpuInfo.deviceId, device_info::kRevisionIdAny });
}

std::vector<GpuInformation> IdentifyGpu::checkGpuInfo()
{
    auto localCachedInfo = std::vector<GpuInformation> {};

    ScopedSkipSpoofingThread skipSpoofingThread {};

    DxgiProxy::Init();

    ComPtr<IDXGIFactory6> factory = nullptr;
    HRESULT result = S_FALSE;

    {
        ScopedCreatingD3DDevice creatingD3DDevice {};
        result = DxgiProxy::CreateDxgiFactory_()(__uuidof(factory), (IDXGIFactory**) factory.GetAddressOf());
    }

    if (result != S_OK || factory == nullptr)
    {
                                                                                               
        LOG_ERROR("Failed to create DXGI Factory, GPU info will be inaccurate!");
        return localCachedInfo;
    }

    UINT adapterIndex = 0;
    DXGI_ADAPTER_DESC1 adapterDesc {};
    ComPtr<IDXGIAdapter1> adapter;

    DXGI_GPU_PREFERENCE gpuPreference = DXGI_GPU_PREFERENCE_UNSPECIFIED;
    if (Config::Instance()->PreferDedicatedGpu.value_or_default())
        gpuPreference = DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE;

    auto storePaths = Util::GetDriverStore();

    while (factory->EnumAdapterByGpuPreference(adapterIndex, gpuPreference, IID_PPV_ARGS(&adapter)) == S_OK)
    {
        if (adapter == nullptr)
        {
            adapterIndex++;
            continue;
        }

        result = adapter->GetDesc1(&adapterDesc);

        if (result == S_OK)
        {
            GpuInformation gpuInfo;
            gpuInfo.luid = adapterDesc.AdapterLuid;
            gpuInfo.vendorId = (VendorId::Value) adapterDesc.VendorId;
            gpuInfo.deviceId = adapterDesc.DeviceId;
            gpuInfo.subsystemId = adapterDesc.SubSysId;
            gpuInfo.revisionId = adapterDesc.Revision;
            gpuInfo.dedicatedVramInBytes = adapterDesc.DedicatedVideoMemory;

            std::wstring szName(adapterDesc.Description);
            gpuInfo.name = wstring_to_string(szName);

            ComPtr<IDXGIVkInteropAdapter> interopAdapter;
            if (SUCCEEDED(adapter->QueryInterface(__uuidof(IDXGIVkInteropAdapter), (void**) &interopAdapter)))
            {
                gpuInfo.dxgiIsDxvk = true;

                                                                             
                ComPtr<IDXGIVkInteropFactory> interopFactory;
                if (SUCCEEDED(factory->QueryInterface(__uuidof(IDXGIVkInteropFactory), (void**) &interopFactory)))
                {
                    VkInstance vkInst = VK_NULL_HANDLE;
                    VkPhysicalDevice vkPhysDev = VK_NULL_HANDLE;
                    interopAdapter->GetVulkanHandles(&vkInst, &vkPhysDev);

                    PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr = VK_NULL_HANDLE;
                    interopFactory->GetVulkanInstance(&vkInst, &vkGetInstanceProcAddr);

                    if (vkPhysDev)
                    {
                        PFN_vkGetPhysicalDeviceProperties pvkGetProps = VK_NULL_HANDLE;
                        if (vkGetInstanceProcAddr && vkInst)
                        {
                            pvkGetProps = (PFN_vkGetPhysicalDeviceProperties) vkGetInstanceProcAddr(
                                vkInst, "vkGetPhysicalDeviceProperties");
                        }

                        if (!pvkGetProps)
                        {
                            HMODULE hVulkan = GetModuleHandleA("vulkan-1.dll");
                            pvkGetProps = hVulkan
                                              ? (PFN_vkGetPhysicalDeviceProperties) KernelBaseProxy::GetProcAddress_()(
                                                    hVulkan, "vkGetPhysicalDeviceProperties")
                                              : nullptr;
                        }

                        if (pvkGetProps)
                        {
                            VkPhysicalDeviceProperties props {};
                            pvkGetProps(vkPhysDev, &props);
                            if (props.vendorID != gpuInfo.vendorId)
                            {
                                LOG_INFO("DXVK: unspoofing vendorId {:04X} -> {:04X} ({})", (uint32_t) gpuInfo.vendorId,
                                         props.vendorID, props.deviceName);
                                gpuInfo.vendorId = (VendorId::Value) props.vendorID;
                                gpuInfo.deviceId = props.deviceID;
                                gpuInfo.name = props.deviceName;
                            }
                        }
                    }
                }
            }

            if (adapterDesc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
                gpuInfo.softwareAdapter = true;

            if (gpuInfo.vendorId == VendorId::AMD)
            {
                auto cardInfo = GetAmdCardInfo(gpuInfo);

                if (cardInfo.has_value())
                    gpuInfo.amdHwGeneration = cardInfo.value().generation;

                auto asicInfoValid = queryAmdAsicInfo(gpuInfo.luid, gpuInfo.vendorId, gpuInfo.deviceId,
                                                      gpuInfo.amdAsicFamily, gpuInfo.amdAsicRevision);
                gpuInfo.fsr4DriverModel = getFsr4ModelForAsic(gpuInfo.amdAsicFamily, gpuInfo.amdAsicRevision,
                                                              gpuInfo.deviceId, asicInfoValid);
            }

            Util::Luid luid(gpuInfo.luid.LowPart, gpuInfo.luid.HighPart);

            if (storePaths.contains(luid))
                gpuInfo.driverStore = storePaths[luid];

            localCachedInfo.push_back(std::move(gpuInfo));

                                                                
                                                                                           
                                                                                                            
            if (Config::Instance()->Fsr4DoNotLoadAmdxc64.value_or_default())
                break;
        }
        else
        {
            LOG_DEBUG("Can't get description of adapter: {}", adapterIndex);
        }

        adapterIndex++;
    }

                                                           
                                                             
                                                            
                                 

    for (auto& gpuInfo : localCachedInfo)
    {
        if (gpuInfo.vendorId == VendorId::Nvidia)
        {
            queryNvapi(gpuInfo);

                                                           
            if (gpuInfo.nvidiaArchInfo.architecture_id >= NV_GPU_ARCHITECTURE_AD100 &&
                !Config::Instance()->FGNvngxReplacement.has_value())
            {
                Config::Instance()->FGNvngxReplacement = FGNvngxReplacement::None;

                if (State::Instance().activeFgOutput == FGOutput::DLSSG)
                    State::Instance().activeFgNvngx = FGNvngxReplacement::None;
            }
        }
    }

    return localCachedInfo;
}

void IdentifyGpu::queryNvapi(GpuInformation& gpuInfo)
{
    ScopedSkipDxgiLoadChecks skipDxgiLoadChecks {};

    auto nvapiModule = NtdllProxy::LoadLibraryExW_Ldr(L"nvapi64.dll", NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);

                                                                 
    if (!nvapiModule)
        return;

    auto o_NvAPI_QueryInterface =
        (PFN_NvApi_QueryInterface) KernelBaseProxy::GetProcAddress_()(nvapiModule, "nvapi_QueryInterface");

    if (!o_NvAPI_QueryInterface)
    {
        NtdllProxy::FreeLibrary_Ldr(nvapiModule);
        return;
    }

                                                                       
    if (o_NvAPI_QueryInterface(0x21382138))
    {
        NtdllProxy::FreeLibrary_Ldr(nvapiModule);
        return;
    }

    auto* init = GET_INTERFACE(NvAPI_Initialize, o_NvAPI_QueryInterface);
    if (!init || init() != NVAPI_OK)
    {
        LOG_ERROR("Failed to init NvApi");
        NtdllProxy::FreeLibrary_Ldr(nvapiModule);
        return;
    }

                             
    NvPhysicalGpuHandle hPhysicalGpu {};

                                                     
    auto* getLogicalGPUs = GET_INTERFACE(NvAPI_SYS_GetLogicalGPUs, o_NvAPI_QueryInterface);
    NV_LOGICAL_GPUS logicalGpus {};
    logicalGpus.version = NV_LOGICAL_GPUS_VER;
    if (getLogicalGPUs)
    {
        if (auto result = getLogicalGPUs(&logicalGpus); result != NVAPI_OK)
            LOG_ERROR("NvAPI_SYS_GetLogicalGPUs failed: {}", magic_enum::enum_name(result));
    }

    auto* getLogicalGpuInfo = GET_INTERFACE(NvAPI_GPU_GetLogicalGpuInfo, o_NvAPI_QueryInterface);

    if (getLogicalGpuInfo)
    {
        for (uint32_t i = 0; i < logicalGpus.gpuHandleCount; i++)
        {
            LUID luid;
            NV_LOGICAL_GPU_DATA logicalGpuData {};
            logicalGpuData.pOSAdapterId = &luid;
            logicalGpuData.version = NV_LOGICAL_GPU_DATA_VER;
            auto logicalGpu = logicalGpus.gpuHandleData[i].hLogicalGpu;

            if (auto result = getLogicalGpuInfo(logicalGpu, &logicalGpuData); result != NVAPI_OK)
                LOG_ERROR("NvAPI_GPU_GetLogicalGpuInfo failed: {}", magic_enum::enum_name(result));

                                                                      
            if (IsEqualLUID(luid, gpuInfo.luid) && logicalGpuData.physicalGpuCount > 0)
            {
                if (logicalGpuData.physicalGpuCount > 1)
                    LOG_WARN("A logical GPU has more than a single physical GPU, we are only checking one");

                hPhysicalGpu = logicalGpuData.physicalGpuHandles[0];
            }
        }
    }

    auto* getArchInfo = GET_INTERFACE(NvAPI_GPU_GetArchInfo, o_NvAPI_QueryInterface);
    gpuInfo.nvidiaArchInfo.version = NV_GPU_ARCH_INFO_VER;
    if (getArchInfo && hPhysicalGpu && getArchInfo(hPhysicalGpu, &gpuInfo.nvidiaArchInfo) != NVAPI_OK)
        LOG_ERROR("Couldn't get GPU Architecture");

    auto* getConnectedDisplayIds = GET_INTERFACE(NvAPI_GPU_GetConnectedDisplayIds, o_NvAPI_QueryInterface);
    NvU32 displayCount = 0;
    if (getConnectedDisplayIds && hPhysicalGpu &&
        getConnectedDisplayIds(hPhysicalGpu, nullptr, &displayCount, 0) == NVAPI_OK && displayCount == 0)
    {
        gpuInfo.noDisplayConnected = true;
    }

    auto* unload = GET_INTERFACE(NvAPI_Unload, o_NvAPI_QueryInterface);
    if (!unload || unload() != NVAPI_OK)
        LOG_ERROR("Failed to unload NvApi");

    NtdllProxy::FreeLibrary_Ldr(nvapiModule);

                                                        
    if (Config::Instance()->DLSSEnabled.value_or_default())
        gpuInfo.dlssCapable = gpuInfo.nvidiaArchInfo.architecture_id >= NV_GPU_ARCHITECTURE_TU100;
}

void IdentifyGpu::getHardwareAdapter(IDXGIFactory* InFactory, IDXGIAdapter** InAdapter,
                                     D3D_FEATURE_LEVEL requiredFeatureLevel)
{
    LOG_FUNC();

    *InAdapter = nullptr;

    auto allGpus = getAllGpus();
    IDXGIFactory6* factory6 = nullptr;

    if (InFactory->QueryInterface(IID_PPV_ARGS(&factory6)) == S_OK && factory6 != nullptr)
    {
        D3d12Proxy::Init();

        for (auto gpu : allGpus)
        {
            if (*InAdapter == nullptr)
            {
                LOG_TRACE("Trying to select: {}", gpu.name);

                ScopedSkipDxgiLoadChecks skipDxgiLoadChecks {};
                auto result = factory6->EnumAdapterByLuid(gpu.luid, IID_PPV_ARGS(InAdapter));
            }

            if (*InAdapter != nullptr)
            {
                                                                                                             
                if (SUCCEEDED(D3d12Proxy::D3D12CreateDevice_()(*InAdapter, requiredFeatureLevel, _uuidof(ID3D12Device),
                                                               nullptr)))
                {
                    break;
                }

                (*InAdapter)->Release();
                *InAdapter = nullptr;
            }
        }

        factory6->Release();
    }
}

std::vector<GpuInformation> IdentifyGpu::getAllGpus()
{
    thread_local bool is_fetching = false;
    if (is_fetching)
        return {};

    std::scoped_lock lock(mutex);

    if (!cache.empty() && cache.front().deviceId != VendorId::Invalid)
    {
        return cache;
    }

    is_fetching = true;
    cache = checkGpuInfo();
    is_fetching = false;

                                                                                    
    return cache;
}

GpuInformation IdentifyGpu::getPrimaryGpu()
{
    auto allGpus = getAllGpus();
    return !allGpus.empty() ? allGpus.front() : GpuInformation {};
}

bool IdentifyGpu::gameUsesDxvk() { return State::Instance().api == DX11 && getPrimaryGpu().dxgiIsDxvk; }

bool IdentifyGpu::gameUsesVkd3dProton() { return State::Instance().api == DX12 && getPrimaryGpu().d3d12IsVkd3dProton; }

void IdentifyGpu::updateD3d12Capabilities(D3d12Proxy::PFN_D3D12CreateDevice o_D3D12CreateDevice)
{
    if (hasD3d12Capabilities)
        return;

                                      
    getAllGpus();

    auto d3d12Module = KernelBaseProxy::GetModuleHandleW_()(L"d3d12.dll");
    if (!d3d12Module)
        return;

    D3d12Proxy::Init(d3d12Module);

    {
        std::scoped_lock lock(mutex);
        if (hasD3d12Capabilities)
            return;
        hasD3d12Capabilities = true;
    }

    struct D3d12Result
    {
        LUID luid;
        bool isVkd3dProton = false;
        FSR4Support fsr4Support = FSR4Support::None;                      
        FSR4Support realFsr4Support = FSR4Support::None;                         
        bool fsr4ForcedSupport = false;
    };
    std::vector<D3d12Result> results;

    for (auto& gpuInfo : cache)
    {
        if (gpuInfo.vendorId != VendorId::AMD && !gpuInfo.dxgiIsDxvk &&
            Config::Instance()->Fsr4GpuSupport.value_or_default() == FSR4Support::None)
        {
            continue;
        }

        ScopedSkipSpoofingThread skipSpoofingThread {};

        ComPtr<IDXGIFactory4> factory;
        if (FAILED(DxgiProxy::CreateDxgiFactory_()(__uuidof(factory), (IDXGIFactory**) factory.GetAddressOf())))
            continue;

        ComPtr<IDXGIAdapter> adapter;
        if (SUCCEEDED(factory->EnumAdapterByLuid(gpuInfo.luid, IID_PPV_ARGS(&adapter))))
        {
            D3d12Proxy::PFN_D3D12CreateDevice pD3D12CreateDevice = nullptr;
            if (o_D3D12CreateDevice)
                pD3D12CreateDevice = o_D3D12CreateDevice;
            else
                pD3D12CreateDevice = D3d12Proxy::D3D12CreateDevice_();

                                                                                          
            ScopedCreatingD3DDevice scopedCreating {};
            ScopedSkipVulkanHooks skipVulkanHooks {};
            ComPtr<ID3D12Device> localDevice;
            auto createResult = pD3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&localDevice));

            if (SUCCEEDED(createResult) && localDevice)
            {
                D3d12Result res;
                res.luid = gpuInfo.luid;

                ComPtr<ID3D12DXVKInteropDevice> vkd3dInterop;
                if (localDevice && SUCCEEDED(localDevice->QueryInterface(IID_PPV_ARGS(&vkd3dInterop))))
                    res.isVkd3dProton = true;

                                                             
                if (Config::Instance()->Fsr4GpuSupport.value_or_default() != FSR4Support::None)
                {
                    res.fsr4Support = Config::Instance()->Fsr4GpuSupport.value_or_default();
                    res.fsr4ForcedSupport = true;
                }

                if (gpuInfo.vendorId == VendorId::AMD)
                {
                                                                                                          
                    if (res.isVkd3dProton)
                    {
                        UINT extensionCount = 0;

                        if (SUCCEEDED(vkd3dInterop->GetDeviceExtensions(&extensionCount, nullptr)) &&
                            extensionCount > 0)
                        {
                            std::vector<const char*> exts(extensionCount);

                            if (SUCCEEDED(vkd3dInterop->GetDeviceExtensions(&extensionCount, exts.data())))
                            {
                                for (UINT i = 0; i < extensionCount; i++)
                                {
                                                  
                                    if (!strcmp("VK_EXT_shader_float8", exts[i]))
                                    {
                                        res.realFsr4Support = FSR4Support::FP8;
                                        break;
                                    }
                                }
                            }
                        }
                    }

                                                                                             
                                                                                                               
                            
                    if (res.realFsr4Support == FSR4Support::None)
                    {
                        const char* envvar = getenv("DXIL_SPIRV_CONFIG");
                        if (envvar && strstr(envvar, "wmma_rdna3_workaround"))
                            res.realFsr4Support = FSR4Support::FP8;
                    }

                    if (res.realFsr4Support == FSR4Support::None)
                    {
                        auto moduleAmdxc64 = KernelBaseProxy::GetModuleHandleW_()(L"amdxc64.dll");

                        if (moduleAmdxc64 == nullptr && !Config::Instance()->Fsr4DoNotLoadAmdxc64.value_or_default())
                            moduleAmdxc64 = NtdllProxy::LoadLibraryExW_Ldr(L"amdxc64.dll", NULL, 0);

                        PFN_AmdExtD3DCreateInterface AmdExtD3DCreateInterface = nullptr;

                        if (moduleAmdxc64 != nullptr)
                        {
                                                                                                
                                                                                
                            Amdxc64Hooks::Init();

                            AmdExtD3DCreateInterface =
                                (PFN_AmdExtD3DCreateInterface) KernelBaseProxy::GetProcAddress_()(
                                    moduleAmdxc64, "AmdExtD3DCreateInterface");
                        }

                                                                                                                  
                                                                                                     
                        if (localDevice && (State::Instance().isRunningOnLinux || !res.isVkd3dProton) &&
                            AmdExtD3DCreateInterface)
                        {
                            IAmdExtD3DFactory* amdExtD3DFactory = nullptr;

                            localDevice->AddRef();
                            auto pre = localDevice->Release();

                            if (SUCCEEDED(AmdExtD3DCreateInterface(localDevice.Get(), IID_PPV_ARGS(&amdExtD3DFactory))))
                            {
                                ComPtr<IAmdExtD3DShaderIntrinsics> amdExtD3DShaderIntrinsics;

                                if (amdExtD3DFactory &&
                                    SUCCEEDED(amdExtD3DFactory->CreateInterface(
                                        localDevice.Get(), IID_PPV_ARGS(&amdExtD3DShaderIntrinsics))))
                                {
                                    HRESULT float8support = amdExtD3DShaderIntrinsics->CheckSupport(
                                        AmdExtD3DShaderIntrinsicsSupport_Float8Conversion);

                                    if (float8support == S_OK)
                                        res.realFsr4Support = FSR4Support::FP8;
                                }

                                amdExtD3DFactory->Release();
                            }

                            localDevice->AddRef();
                            auto post = localDevice->Release();

                                                                       
                            while (post > 0 && post > pre)
                            {
                                localDevice->Release();
                                post--;
                            }
                        }
                    }

                                                                                             
                                                                                                                
                                                                                                              
                                     
                    bool preferDeviceInfo = State::Instance().isRunningOnLinux &&
                                            gpuInfo.amdHwGeneration != device_info::HwGeneration::kUndefinedGeneration;

                    if (res.fsr4Support == FSR4Support::None && !preferDeviceInfo &&
                        IsFsr4Int8(gpuInfo.fsr4DriverModel))
                    {
                        res.fsr4Support = gpuInfo.fsr4DriverModel;
                    }

                                                                                       
                    if (res.fsr4Support == FSR4Support::None && (preferDeviceInfo || gpuInfo.amdAsicFamily == 0))
                    {
                        auto cardInfo = GetAmdCardInfo(gpuInfo);

                        if (cardInfo.has_value())
                        {
                            using device_info::AsicType;
                            using device_info::HwGeneration;

                            auto& card = cardInfo.value();

                                                          
                                    
                            if (card.generation == HwGeneration::kGfx12)
                            {
                                res.fsr4Support = FSR4Support::FP8;
                            }
                                                             
                            else if ((card.generation == HwGeneration::kGfx11 && !card.is_apu) ||
                                     card.asic_type == AsicType::kGfx11_5_1)
                            {
                                res.fsr4Support = FSR4Support::INT8;
                            }
                                              
                            else if (card.generation == HwGeneration::kGfx10_3 && !card.is_apu)
                            {
                                res.fsr4Support = FSR4Support::INT8_2;
                            }
                                                       
                            else if (card.asic_type == AsicType::kGfx10_3_3 || card.asic_type == AsicType::kGfx11_5_0)
                            {
                                res.fsr4Support = FSR4Support::INT8Lite;
                            }
                                                                                                                  
                                                                                   
                            else if ((card.generation == HwGeneration::kGfx11 && card.is_apu) ||
                                     card.asic_type == AsicType::kGfx11_5_2 || card.asic_type == AsicType::kGfx10_1_0 ||
                                     card.asic_type == AsicType::kGfx10_1_0Xl || card.asic_type == AsicType::kGfx10_1_1)
                            {
                                res.fsr4Support = FSR4Support::INT8Lite;
                            }
                        }
                    }

                    if (res.fsr4Support == FSR4Support::None)
                        res.fsr4Support = res.realFsr4Support;

                                                                                             
                                                                                           
                }

                results.push_back(res);
            }
        }
    }

    {
        std::scoped_lock lock(mutex);
        for (auto& res : results)
        {
            for (auto& gpuInfo : cache)
            {
                if (IsEqualLUID(gpuInfo.luid, res.luid))
                {
                    gpuInfo.d3d12IsVkd3dProton = res.isVkd3dProton;
                    gpuInfo.fsr4Support = res.fsr4Support;
                    gpuInfo.realFsr4Support = res.realFsr4Support;
                    gpuInfo.fsr4ForcedSupport = res.fsr4ForcedSupport;
                    break;
                }
            }
        }

                             
                                                                                      
        if (!cache.empty() && Config::Instance()->_DONTUSE_Fsr4ForceEnableInt8.has_value() &&
            Config::Instance()->_DONTUSE_Fsr4ForceEnableInt8.value())
        {
            auto& primaryGpu = cache.front();

            if (primaryGpu.fsr4Support == FSR4Support::None)
            {
                primaryGpu.fsr4Support = FSR4Support::INT8;
                primaryGpu.fsr4ForcedSupport = true;

                Config::Instance()->Fsr4GpuSupport = FSR4Support::INT8;
            }
        }
    }

    auto detectedGpus = IdentifyGpu::getAllGpus();
    std::string gpus = "Detected GPUs:\n";

    std::string indent(22, ' ');

    for (auto& gpu : detectedGpus)
    {
        std::string fsr4Support = "unknown";
        if (gpu.fsr4Support == FSR4Support::None)
            fsr4Support = "false";
        else if (gpu.fsr4Support == FSR4Support::FP8)
            fsr4Support = "fp8";
        else if (gpu.fsr4Support == FSR4Support::INT8)
            fsr4Support = "int8";
        else if (gpu.fsr4Support == FSR4Support::INT8_2)
            fsr4Support = "int8-2";
        else if (gpu.fsr4Support == FSR4Support::INT8Lite)
            fsr4Support = "int8 lite";

        if (gpu.fsr4ForcedSupport)
            fsr4Support += " (forced)";

        if (gpu.amdAsicFamily != 0)
            fsr4Support += std::format(", asic family: {}, revision: {}, driver model: {}", gpu.amdAsicFamily,
                                       gpu.amdAsicRevision, magic_enum::enum_name(gpu.fsr4DriverModel));

        gpus += std::format("{}{}\n", indent, gpu.name);
        gpus += std::format("{}    vendorId: {:X}, deviceId: {:X}, VRAM: {}MB\n", indent, (uint32_t) gpu.vendorId,
                            gpu.deviceId, gpu.dedicatedVramInBytes / (1024 * 1024));
        gpus += std::format("{}    dxgi is dxvk: {}, d3d12 is vkd3d-proton: {}\n", indent, gpu.dxgiIsDxvk,
                            gpu.d3d12IsVkd3dProton);
        gpus += std::format("{}    Upscaler support - fsr4: {}, dlss: {}\n", indent, fsr4Support, gpu.dlssCapable);
    }

    spdlog::info(gpus);

    auto primaryGpu = !detectedGpus.empty() ? detectedGpus.front() : GpuInformation {};

    if (primaryGpu.vendorId != VendorId::AMD && primaryGpu.fsr4ForcedSupport &&
        primaryGpu.fsr4Support == FSR4Support::FP8)
    {
        State::Instance().postCodes |= PostCode::TryingFsr4Fp8OnUnsupported;

        std::scoped_lock lock(mutex);
        for (auto& gpuInfo : cache)
        {
            gpuInfo.fsr4Support = FSR4Support::None;
            gpuInfo.fsr4ForcedSupport = false;
        }
    }

                                                                                                    
                                                                                                 
                                                            
    if (Config::Instance()->Fsr4GpuSupport.value_or_default() == FSR4Support::None && primaryGpu.fsr4ForcedSupport)
    {
                                                                                               
                                                                    
           
                                                                                           
                                                                                           
            

                                                                     
    }
}

void IdentifyGpu::updateInt8Support(bool sdkSupportsInt8, bool driverSupportsInt8)
{
    if (sdkSupportsInt8 || driverSupportsInt8)
        return;

    std::scoped_lock lock(mutex);
    for (auto& gpuInfo : cache)
    {
        if (!IsFsr4Int8(gpuInfo.fsr4Support))
            continue;

        LOG_DEBUG("Neither driver nor the sdk supports FSR 4 Int 8, disabling FSR 4 for {}", gpuInfo.name);
        gpuInfo.fsr4Support = FSR4Support::None;
        gpuInfo.fsr4ForcedSupport = false;
    }
}

bool IdentifyGpu::queryAmdAsicInfo(LUID luid, uint32_t vendorId, uint32_t deviceId, uint32_t& family,
                                   uint32_t& revision)
{
    family = 0;
    revision = 0;

    auto gdi32 = KernelBaseProxy::GetModuleHandleW_()(L"gdi32.dll");

    if (gdi32 == nullptr)
        gdi32 = NtdllProxy::LoadLibraryExW_Ldr(L"gdi32.dll", NULL, 0);

    if (gdi32 == nullptr)
        return false;

    auto openAdapter = reinterpret_cast<decltype(&D3DKMTOpenAdapterFromLuid)>(
        KernelBaseProxy::GetProcAddress_()(gdi32, "D3DKMTOpenAdapterFromLuid"));
    auto queryAdapterInfo = reinterpret_cast<decltype(&D3DKMTQueryAdapterInfo)>(
        KernelBaseProxy::GetProcAddress_()(gdi32, "D3DKMTQueryAdapterInfo"));
    auto closeAdapter = reinterpret_cast<decltype(&D3DKMTCloseAdapter)>(
        KernelBaseProxy::GetProcAddress_()(gdi32, "D3DKMTCloseAdapter"));

    if (openAdapter == nullptr || queryAdapterInfo == nullptr || closeAdapter == nullptr)
        return false;

    D3DKMT_OPENADAPTERFROMLUID openData {};
    openData.AdapterLuid = luid;

    if (openAdapter(&openData) != 0)
        return false;

                                                                     
    constexpr NTSTATUS statusBufferTooSmall = 0xC0000023;
    constexpr UINT singleSize = 608;
    constexpr size_t familyIndex = 12;
    constexpr size_t revisionIndex = 13;

                                                                               
    constexpr size_t multiCountOffset = 0x8;
    constexpr size_t multiVendorIdsOffset = 0xC;                
    constexpr size_t multiDeviceIdsOffset = 0x14;               
    constexpr size_t multiEntrySize = 0x3A00;
    constexpr size_t multiFamilyOffset = 0x1364;
    constexpr size_t multiRevisionOffset = 0x1368;
    constexpr UINT multiHeaderSize = 0x960;
    constexpr uint32_t multiMaxEntries = 4;

    std::vector<uint8_t> buffer(singleSize);

    D3DKMT_QUERYADAPTERINFO query {};
    query.hAdapter = openData.hAdapter;
    query.Type = KMTQAITYPE_UMDRIVERPRIVATE;
    query.pPrivateDriverData = buffer.data();
    query.PrivateDriverDataSize = singleSize;

    auto read32 = [&](size_t offset) { return *reinterpret_cast<uint32_t*>(buffer.data() + offset); };
    auto read16 = [&](size_t offset) { return *reinterpret_cast<uint16_t*>(buffer.data() + offset); };

    auto status = queryAdapterInfo(&query);

    if (status == statusBufferTooSmall)
    {
                                           
        buffer.assign(multiHeaderSize + multiEntrySize, 0);
        query.pPrivateDriverData = buffer.data();
        query.PrivateDriverDataSize = static_cast<UINT>(buffer.size());
        status = queryAdapterInfo(&query);

        auto count = std::min(read32(multiCountOffset), multiMaxEntries);

        if (count > 1)
        {
            buffer.assign(multiHeaderSize + multiEntrySize * count, 0);
            query.pPrivateDriverData = buffer.data();
            query.PrivateDriverDataSize = static_cast<UINT>(buffer.size());
            status = queryAdapterInfo(&query);
        }

        if (status >= 0)
        {
            for (uint32_t i = 0; i < count; i++)
            {
                if (read16(multiVendorIdsOffset + i * 2) == static_cast<uint16_t>(vendorId) &&
                    read16(multiDeviceIdsOffset + i * 2) == static_cast<uint16_t>(deviceId))
                {
                    family = read32(i * multiEntrySize + multiFamilyOffset);
                    revision = read32(i * multiEntrySize + multiRevisionOffset);
                    break;
                }
            }
        }
    }
    else if (status >= 0)
    {
        family = read32(familyIndex * sizeof(uint32_t));
        revision = read32(revisionIndex * sizeof(uint32_t));
    }

    D3DKMT_CLOSEADAPTER closeData {};
    closeData.hAdapter = openData.hAdapter;
    closeAdapter(&closeData);

    return family != 0;
}

FSR4Support IdentifyGpu::getFsr4ModelForAsic(uint32_t family, uint32_t revision, uint32_t deviceId, bool asicInfoValid)
{
                                                                                     
    constexpr uint32_t familyNv = 143;               
    constexpr uint32_t familyVgh = 144;            
    constexpr uint32_t familyNv3 = 145;           
    constexpr uint32_t familyPhx = 148;                        
    constexpr uint32_t familyStx = 150;         
    constexpr uint32_t familyNv4 = 152;           

    struct Asic
    {
        uint32_t family, min, max;
    };

    constexpr Asic navi10 { familyNv, 0x01, 0x0A };
    constexpr Asic navi12 { familyNv, 0x0A, 0x14 };
    constexpr Asic navi21 { familyNv, 0x28, 0x32 };
    constexpr Asic navi22 { familyNv, 0x32, 0x3C };
    constexpr Asic navi23 { familyNv, 0x3C, 0x46 };
    constexpr Asic navi24 { familyNv, 0x46, 0x50 };
    constexpr Asic vanGogh { familyVgh, 0x01, 0x80 };                                                              
    constexpr Asic navi31 { familyNv3, 0x01, 0x10 };
    constexpr Asic navi33 { familyNv3, 0x10, 0x20 };
    constexpr Asic navi32 { familyNv3, 0x20, 0xFF };
    constexpr Asic phoenix1 { familyPhx, 0x01, 0x80 };
    constexpr Asic phoenix2 { familyPhx, 0x80, 0xC0 };
    constexpr Asic hawkPoint1 { familyPhx, 0xC0, 0xF0 };
    constexpr Asic hawkPoint2 { familyPhx, 0xF0, 0xFF };
    constexpr Asic strix1 { familyStx, 0x01, 0x40 };
    constexpr Asic krackan1 { familyStx, 0x40, 0x50 };
    constexpr Asic strixHalo { familyStx, 0xC0, 0xD0 };

    auto is = [&](const Asic& asic) { return family == asic.family && revision >= asic.min && revision < asic.max; };

                                              
                    
    if (family == familyNv4)
        return FSR4Support::FP8;

                                    
                                                                                     
    if (is(navi31) || is(navi32) || is(navi33) || is(strixHalo) || (!asicInfoValid && deviceId == 0x7481))
        return FSR4Support::INT8;

                      
    if (is(navi21) || is(navi22) || is(navi23) || is(navi24))
        return FSR4Support::INT8_2;

    if (is(strix1) || is(vanGogh))
        return FSR4Support::INT8Lite;

                                                               
                                                    
    if (is(phoenix1) || is(phoenix2) || is(hawkPoint1) || is(hawkPoint2) || is(krackan1) || is(navi10) || is(navi12))
        return FSR4Support::INT8Lite;

    return FSR4Support::None;
}
