#pragma once

#include "SysUtils.h"

#include <ffx_api.h>

                                                                                          
struct ProviderInterface
{
    uint64_t versionId;
    const char* versionName;
    bool (*canProvide)(uint64_t descType);
    ffxReturnCode_t (*createContext)(ffxContext* context, ffxCreateContextDescHeader* desc,
                                     const ffxAllocationCallbacks* memCb);
    ffxReturnCode_t (*destroyContext)(ffxContext* context, const ffxAllocationCallbacks* memCb);
    ffxReturnCode_t (*configure)(ffxContext* context, const ffxConfigureDescHeader* desc);
    ffxReturnCode_t (*query)(ffxContext* context, ffxQueryDescHeader* desc);
    ffxReturnCode_t (*dispatch)(ffxContext* context, const ffxDispatchDescHeader* desc);
};

                                                                                         
struct ExternalProviderData
{
    uint32_t structVersion;
    uint64_t descType;
    ProviderInterface provider;

                                                                                                                    
                                                                                             
    bool (*isSupported)(const void* backend);
    void* reserved;

                                                                                        
                                                                                   
    static constexpr uint32_t SizeFor(uint32_t structVersion)
    {
        return structVersion >= 3 ? sizeof(ExternalProviderData) : offsetof(ExternalProviderData, isSupported);
    }
};

static_assert(offsetof(ExternalProviderData, isSupported) == 0x50);
static_assert(sizeof(ExternalProviderData) == 0x60);

                                                                                                             
                                                                                                            
enum class ProviderEffect : uint32_t
{
    Upscale = 0,
    FrameGeneration = 1,
    FrameGenerationSwapchain = 5,
};

                                                          
struct ProviderOption
{
    uint32_t type = 0;                    
    ProviderEffect effect = ProviderEffect::Upscale;
    bool enable = true;
    ProviderOption* next = nullptr;
};

static_assert(sizeof(ProviderOption) == 0x18);

typedef HRESULT(STDMETHODCALLTYPE* PFN_UpdateFfxApiProvider)(void* pData, uint32_t dataSizeInBytes);
typedef HRESULT(STDMETHODCALLTYPE* PFN_UpdateFfxApiProviderEx)(void* pData, uint32_t dataSizeInBytes,
                                                               ProviderOption* options);

                                                                              
enum class DriverListing
{
    Always,                           
    WhenNewestUpscaler,                               
};

                                                                                                 
inline feature_version ProviderVersion(uint64_t versionId)
{
    auto packed = static_cast<uint32_t>(versionId) & 0x7FFFFFFF;
    return feature_version(packed >> 22, (packed >> 12) & 0x3FF, packed & 0xFFF);
}
                                                                                            
void AddDriverToVersionList(std::vector<uint64_t>& ids, std::vector<const char*>& names, uint64_t driverId,
                            const char* driverName, DriverListing listing);

                                                                                                                      
            
struct DriverProvider
{
    ProviderInterface functions {};                                                               
    std::string versionName;
    bool (*isSupported)(const void* backend) = nullptr;
};

                                                                                                          
class FSR4DriverDll
{
  public:
                                                                                                                        
                                                                                                                    
                                                                                                                   
                                            
    FSR4DriverDll(const wchar_t* name, std::vector<std::wstring> sdkModules);

    FSR4DriverDll(const FSR4DriverDll&) = delete;
    FSR4DriverDll& operator=(const FSR4DriverDll&) = delete;

                                                                                           
    HMODULE Load();

                                    
    HMODULE Module() const { return _module; }

                                                                             
    std::optional<DriverProvider> QueryProvider(uint64_t descType, std::initializer_list<uint32_t> structVersions,
                                                ProviderOption* options = nullptr) const;

                                                                                            
    HRESULT UpdateFfxApiProvider(void* data, uint32_t dataSizeInBytes, ProviderOption* options = nullptr) const;

                                                                                                              
    static HMODULE SdkModuleStandIn(const wchar_t* moduleName, HMODULE caller);

  private:
    std::wstring _name;
    std::vector<std::wstring> _sdkModules;

    HMODULE _module = nullptr;
    PFN_UpdateFfxApiProvider _updateFfxApiProvider = nullptr;
    PFN_UpdateFfxApiProviderEx _updateFfxApiProviderEx = nullptr;
    std::once_flag _loadOnce;
};
