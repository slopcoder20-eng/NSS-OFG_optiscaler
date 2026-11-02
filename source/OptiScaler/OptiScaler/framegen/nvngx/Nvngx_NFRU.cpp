#include "pch.h"
#include "Nvngx_NFRU.h"
#include "NfruCamera.h"

#include <Config.h>
#include <State.h>
#include <Util.h>
#include <NVNGX_Parameter.h>
#include <nvsdk_ngx_vk.h>
#include <proxies/FfxApi_Proxy.h>
#include <misc/VkCoopMatSupport.h>
#include <hooks/VulkanwDx12_Hooks.h>
#include <numbers>
#include <algorithm>
#include <array>
#include <psapi.h>
#include <mutex>
#include <vector>
#include <atomic>
#pragma comment(lib, "psapi.lib")

                                                                                                                        
                                                                                                                    
                                                                                                                
                                                                                                                   
                                                                    
                                                                                                                        
namespace NfruAbi
{
enum SurfaceFormat : uint32_t
{
    FMT_UNKNOWN = 0,
    FMT_R32G32B32A32_FLOAT = 3,
    FMT_R16G16B16A16_FLOAT = 4,
    FMT_R32G32_FLOAT = 6,
    FMT_R32_UINT = 9,
    FMT_R8G8B8A8_UNORM = 11,
    FMT_R8G8B8A8_SRGB = 13,
    FMT_B8G8R8A8_UNORM = 15,
    FMT_B8G8R8A8_SRGB = 16,
    FMT_R11G11B10_FLOAT = 17,
    FMT_R10G10B10A2_UNORM = 18,
    FMT_R16G16_FLOAT = 19,
    FMT_R16_FLOAT = 22,
    FMT_R16_UNORM = 24,
    FMT_R8_UNORM = 26,
    FMT_R32_FLOAT = 31,
};
enum Usage : uint32_t
{
    USAGE_READ_ONLY = 0,
    USAGE_UAV = 1 << 1,
    USAGE_DEPTHTARGET = 1 << 2,
    USAGE_STENCILTARGET = 1 << 5,
};
enum ResourceState : uint32_t
{
    STATE_COMPUTE_UAV = 1 << 1,
    STATE_PIXEL_UAV = 1 << 2,
    STATE_UNORDERED_ACCESS = STATE_COMPUTE_UAV | STATE_PIXEL_UAV,
    STATE_COMPUTE_READ = 1 << 3,
    STATE_COPY_DEST = 1 << 6,
};
enum CreateFlags : uint32_t
{
    FG_DISPLAY_RESOLUTION_MVS = 1 << 0,
    FG_MV_JITTER_CANCELLATION = 1 << 1,
    FG_DEPTH_INVERTED = 1 << 2,
    FG_DEPTH_INFINITE = 1 << 3,
    FG_HDR = 1 << 4,
    FG_MANAGE_PREVIOUS_DEPTH = 1 << 17,
    FG_MANAGE_PREVIOUS_COLOR = 1 << 18,
};
constexpr uint32_t FG_DISPATCH_DRAW_DEBUG_VIEW = 1 << 0;
constexpr uint32_t FG_DISPATCH_NO_SWAPCHAIN_NOTIFY = 1 << 1;

constexpr uint64_t DESC_CREATE_FG = 0x00020001u;
constexpr uint64_t DESC_CONFIGURE_FG = 0x00020002u;
constexpr uint64_t DESC_DISPATCH_FG = 0x00020003u;
constexpr uint64_t DESC_DISPATCH_FG_PREPARE = 0x00020004u;

struct ResourceDescription
{
    uint32_t type, format, width, height, depth, mipCount, flags, usage, batchSize, shapeSize;
};
struct Resource
{
    void* resource;
    ResourceDescription description;
    uint32_t state;
};

                                                                                                            
struct BackendVKDesc
{
    ffxCreateContextDescHeader header;
    VkDevice vkDevice;
    VkPhysicalDevice vkPhysicalDevice;
    VkInstance vkInstance;
    PFN_vkGetDeviceProcAddr vkDeviceProcAddr;
    PFN_vkGetInstanceProcAddr vkGetInstanceProcAddr;
};

                                                                                                      
constexpr uint64_t DESC_BACKEND_DX12 = 0x0000002u;
struct BackendDX12Desc
{
    ffxCreateContextDescHeader header;
    ID3D12Device* device;
};

struct CreateDescFG
{
    ffxCreateContextDescHeader header;
    uint32_t flags;
    FfxApiDimensions2D displaySize;
    FfxApiDimensions2D renderSize;
    float initialViewProjection[16];
    uint32_t backBufferFormat;
    const char* fpMessage;                                                           
};

struct ConfigureDescFG
{
    ffxConfigureDescHeader header;
    void* swapChain;
    void* presentCallback;
    void* presentCallbackUserContext;
    void* frameGenerationCallback;
    void* frameGenerationCallbackUserContext;
    bool frameGenerationEnabled;
    bool allowAsyncWorkloads;
    uint32_t flags;
    bool onlyPresentGenerated;
    uint64_t frameID;
    const char* dumpGeneratedFramePath;
};

struct PrepareDescFG
{
    ffxDispatchDescHeader header;
    uint64_t frameID;
    void* commandList;
    FfxApiFloatCoords2D jitterOffset;
    FfxApiFloatCoords2D motionVectorScale;
    float mvSimilarityThreshold;
    float mvSimilarityNoiseThreshold;
    float frameTimeDelta;
    float cameraNear;
    float cameraFar;
    float cameraFovAngleVertical;
    float viewSpaceToMetersFactor;
    Resource depth;
    Resource motionVectors;
    Resource depthTm1;
    Resource colorTm1;
    float viewProjection[16];
};

struct DispatchDescFG
{
    ffxDispatchDescHeader header;
    void* commandList;
    Resource presentColor;
    Resource outputs[4];
    uint32_t numGeneratedFrames;
    bool reset;
    uint64_t frameID;
};
constexpr uint64_t DESC_MFG = 0x4E46525500000001ull;
struct MfgDesc { ffxDispatchDescHeader header; uint32_t index, count; };
constexpr uint64_t DESC_HUD = 0x4E46525500000002ull;
struct HudDesc { ffxDispatchDescHeader header; Resource fullColor; };
}                     

namespace
{
uint32_t SurfaceFormatFromVk(VkFormat fmt)
{
    using namespace NfruAbi;
    switch (fmt)
    {
    case VK_FORMAT_R32G32B32A32_SFLOAT:
        return FMT_R32G32B32A32_FLOAT;
    case VK_FORMAT_R16G16B16A16_SFLOAT:
        return FMT_R16G16B16A16_FLOAT;
    case VK_FORMAT_R32G32_SFLOAT:
        return FMT_R32G32_FLOAT;
    case VK_FORMAT_R32_UINT:
    case VK_FORMAT_D24_UNORM_S8_UINT:
    case VK_FORMAT_X8_D24_UNORM_PACK32:
        return FMT_R32_UINT;
    case VK_FORMAT_R8G8B8A8_UNORM:
        return FMT_R8G8B8A8_UNORM;
    case VK_FORMAT_R8G8B8A8_SRGB:
        return FMT_R8G8B8A8_SRGB;
    case VK_FORMAT_B8G8R8A8_UNORM:
        return FMT_B8G8R8A8_UNORM;
    case VK_FORMAT_B8G8R8A8_SRGB:
        return FMT_B8G8R8A8_SRGB;
    case VK_FORMAT_B10G11R11_UFLOAT_PACK32:
        return FMT_R11G11B10_FLOAT;
    case VK_FORMAT_A2B10G10R10_UNORM_PACK32:
        return FMT_R10G10B10A2_UNORM;
    case VK_FORMAT_R16G16_SFLOAT:
        return FMT_R16G16_FLOAT;
    case VK_FORMAT_R16_SFLOAT:
        return FMT_R16_FLOAT;
    case VK_FORMAT_R16_UNORM:
    case VK_FORMAT_D16_UNORM:
    case VK_FORMAT_D16_UNORM_S8_UINT:
        return FMT_R16_UNORM;
    case VK_FORMAT_R8_UNORM:
        return FMT_R8_UNORM;
    case VK_FORMAT_R32_SFLOAT:
    case VK_FORMAT_D32_SFLOAT:
    case VK_FORMAT_D32_SFLOAT_S8_UINT:
        return FMT_R32_FLOAT;
    default:
        return FMT_UNKNOWN;
    }
}

NfruAbi::Resource GetResource(const NVSDK_NGX_Resource_VK* vkResource, uint32_t state)
{
    using namespace NfruAbi;
    Resource out = {};
    if (!vkResource || vkResource->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW ||
        vkResource->Resource.ImageViewInfo.Image == VK_NULL_HANDLE)
        return out;

    const auto& info = vkResource->Resource.ImageViewInfo;
    out.resource = (void*) info.Image;
    out.state = state;

    ResourceDescription& d = out.description;
    d.usage = USAGE_READ_ONLY;
    if (vkResource->ReadWrite)
        d.usage |= USAGE_UAV;
                                                                                                           
    const bool formatIsDepth = info.Format == VK_FORMAT_D16_UNORM || info.Format == VK_FORMAT_X8_D24_UNORM_PACK32 ||
                               info.Format == VK_FORMAT_D32_SFLOAT || info.Format == VK_FORMAT_D16_UNORM_S8_UINT ||
                               info.Format == VK_FORMAT_D24_UNORM_S8_UINT || info.Format == VK_FORMAT_D32_SFLOAT_S8_UINT;
    if (formatIsDepth || (info.SubresourceRange.aspectMask & VK_IMAGE_ASPECT_DEPTH_BIT))
        d.usage |= USAGE_DEPTHTARGET;
                                                                                                          
    const bool hasStencil = info.Format == VK_FORMAT_D32_SFLOAT_S8_UINT || info.Format == VK_FORMAT_D24_UNORM_S8_UINT ||
                            info.Format == VK_FORMAT_D16_UNORM_S8_UINT;
    if (hasStencil || (info.SubresourceRange.aspectMask & VK_IMAGE_ASPECT_STENCIL_BIT))
        d.usage |= USAGE_STENCILTARGET;
    d.type = FFX_API_RESOURCE_TYPE_TEXTURE2D;
    d.width = info.Width;
    d.height = info.Height;
    d.mipCount = 1;
    d.depth = 1;
    d.flags = 0;
    d.format = SurfaceFormatFromVk(info.Format);
    return out;
}

                                                                                                                  
uint32_t SurfaceFormatFromDxgi(DXGI_FORMAT fmt)
{
    using namespace NfruAbi;
    switch (fmt)
    {
    case DXGI_FORMAT_R32G32B32A32_TYPELESS:
    case DXGI_FORMAT_R32G32B32A32_FLOAT:
        return FMT_R32G32B32A32_FLOAT;
    case DXGI_FORMAT_R16G16B16A16_TYPELESS:
    case DXGI_FORMAT_R16G16B16A16_FLOAT:
        return FMT_R16G16B16A16_FLOAT;
    case DXGI_FORMAT_R32G32_TYPELESS:
    case DXGI_FORMAT_R32G32_FLOAT:
        return FMT_R32G32_FLOAT;
    case DXGI_FORMAT_R32_UINT:
        return FMT_R32_UINT;
    case DXGI_FORMAT_R8G8B8A8_TYPELESS:
    case DXGI_FORMAT_R8G8B8A8_UNORM:
        return FMT_R8G8B8A8_UNORM;
    case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:
        return FMT_R8G8B8A8_SRGB;
    case DXGI_FORMAT_B8G8R8A8_TYPELESS:
    case DXGI_FORMAT_B8G8R8A8_UNORM:
        return FMT_B8G8R8A8_UNORM;
    case DXGI_FORMAT_B8G8R8A8_UNORM_SRGB:
        return FMT_B8G8R8A8_SRGB;
    case DXGI_FORMAT_R11G11B10_FLOAT:
        return FMT_R11G11B10_FLOAT;
    case DXGI_FORMAT_R10G10B10A2_TYPELESS:
    case DXGI_FORMAT_R10G10B10A2_UNORM:
        return FMT_R10G10B10A2_UNORM;
    case DXGI_FORMAT_R16G16_TYPELESS:
    case DXGI_FORMAT_R16G16_FLOAT:
        return FMT_R16G16_FLOAT;
    case DXGI_FORMAT_R16_TYPELESS:
    case DXGI_FORMAT_R16_FLOAT:
        return FMT_R16_FLOAT;
    case DXGI_FORMAT_R16_UNORM:
    case DXGI_FORMAT_D16_UNORM:
        return FMT_R16_UNORM;
    case DXGI_FORMAT_R8_TYPELESS:
    case DXGI_FORMAT_R8_UNORM:
        return FMT_R8_UNORM;
    case DXGI_FORMAT_R32_TYPELESS:
    case DXGI_FORMAT_R32_FLOAT:
    case DXGI_FORMAT_D32_FLOAT:
        return FMT_R32_FLOAT;
    default:
        return FMT_UNKNOWN;
    }
}

NfruAbi::Resource GetResourceD3D12(ID3D12Resource* resource, uint32_t state)
{
    using namespace NfruAbi;
    Resource out = {};
    if (!resource)
        return out;
    const D3D12_RESOURCE_DESC desc = resource->GetDesc();
    out.resource = resource;
    out.state = state;
    out.description.type = desc.Dimension == D3D12_RESOURCE_DIMENSION_BUFFER ? 0u : 2u;                      
    out.description.format = SurfaceFormatFromDxgi(desc.Format);
    out.description.width = static_cast<uint32_t>(desc.Width);
    out.description.height = desc.Height;
    out.description.depth = desc.DepthOrArraySize;
    out.description.mipCount = desc.MipLevels;
    out.description.usage = USAGE_READ_ONLY;
    if (desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS)
        out.description.usage |= USAGE_UAV;
                                                                                                               
                                 
    if (desc.Flags & D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL)
        out.description.usage |= USAGE_DEPTHTARGET;
    return out;
}

bool CopyTextureVk(VkCommandBuffer commandList, const NVSDK_NGX_Resource_VK* destination,
                   const NVSDK_NGX_Resource_VK* source)
{
    if (commandList == VK_NULL_HANDLE || !destination || !source ||
        destination->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW ||
        source->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW)
        return false;

    const auto& dst = destination->Resource.ImageViewInfo;
    const auto& src = source->Resource.ImageViewInfo;
    if (dst.Image == VK_NULL_HANDLE || src.Image == VK_NULL_HANDLE)
        return false;
    if (dst.Image == src.Image)
        return true;
    if (dst.Width != src.Width || dst.Height != src.Height || dst.Format != src.Format)
    {
        LOG_WARN("NFRU: DLSSG copy skipped, incompatible images src={}x{} fmt={} dst={}x{} fmt={}", src.Width,
                 src.Height, (uint32_t) src.Format, dst.Width, dst.Height, (uint32_t) dst.Format);
        return false;
    }

    const VkImageAspectFlags srcAspect =
        src.SubresourceRange.aspectMask != 0 ? src.SubresourceRange.aspectMask : VK_IMAGE_ASPECT_COLOR_BIT;
    const VkImageAspectFlags dstAspect =
        dst.SubresourceRange.aspectMask != 0 ? dst.SubresourceRange.aspectMask : VK_IMAGE_ASPECT_COLOR_BIT;
    const uint32_t srcLayers = src.SubresourceRange.layerCount == VK_REMAINING_ARRAY_LAYERS
                                   ? 1
                                   : std::max(1u, src.SubresourceRange.layerCount);
    const uint32_t dstLayers = dst.SubresourceRange.layerCount == VK_REMAINING_ARRAY_LAYERS
                                   ? 1
                                   : std::max(1u, dst.SubresourceRange.layerCount);
    const uint32_t layerCount = std::min(srcLayers, dstLayers);

    const VkImageSubresourceRange srcRange { srcAspect, src.SubresourceRange.baseMipLevel, 1,
                                             src.SubresourceRange.baseArrayLayer, layerCount };
    const VkImageSubresourceRange dstRange { dstAspect, dst.SubresourceRange.baseMipLevel, 1,
                                             dst.SubresourceRange.baseArrayLayer, layerCount };
    std::array<VkImageMemoryBarrier, 2> toCopy { {
        { VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_SHADER_READ_BIT, VK_ACCESS_TRANSFER_READ_BIT,
          VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, VK_QUEUE_FAMILY_IGNORED,
          VK_QUEUE_FAMILY_IGNORED, src.Image, srcRange },
        { VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER, nullptr, VK_ACCESS_SHADER_WRITE_BIT, VK_ACCESS_TRANSFER_WRITE_BIT,
          VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_QUEUE_FAMILY_IGNORED,
          VK_QUEUE_FAMILY_IGNORED, dst.Image, dstRange },
    } };
    vkCmdPipelineBarrier(commandList, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0,
                         nullptr, 0, nullptr, static_cast<uint32_t>(toCopy.size()), toCopy.data());

    const VkImageCopy region { { srcAspect, src.SubresourceRange.baseMipLevel, src.SubresourceRange.baseArrayLayer,
                                 layerCount },
                               { 0, 0, 0 },
                               { dstAspect, dst.SubresourceRange.baseMipLevel, dst.SubresourceRange.baseArrayLayer,
                                 layerCount },
                               { 0, 0, 0 },
                               { src.Width, src.Height, 1 } };
    vkCmdCopyImage(commandList, src.Image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, dst.Image,
                   VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);

    std::array<VkImageMemoryBarrier, 2> restore { toCopy };
    restore[0].srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
    restore[0].dstAccessMask = VK_ACCESS_SHADER_READ_BIT;
    restore[0].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    restore[0].newLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    restore[1].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
    restore[1].dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
    restore[1].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    restore[1].newLayout = VK_IMAGE_LAYOUT_GENERAL;
    vkCmdPipelineBarrier(commandList, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT, 0, 0,
                         nullptr, 0, nullptr, static_cast<uint32_t>(restore.size()), restore.data());
    return true;
}

NVSDK_NGX_Result GetCurrentSettingsCallback(Nvngx_NFRU_Handle* InHandle, NVSDK_NGX_Parameter* InParameters)
{
    if (!InHandle || !InParameters)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;

    const uint32_t count = Nvngx_NFRU::MfgSupported() ? std::clamp(Config::Instance()->NfruMultiplier.value_or_default(), 2, 4) - 1 : 1;
    static uint32_t lastLogged = 0;
    if (count != lastLogged)
    {
        lastLogged = count;
        LOG_INFO("NFRU MFG settings: MultiFrameCount={} (Multiplier={}, mfgSupported={})", count,
                 Config::Instance()->NfruMultiplier.value_or_default(), Nvngx_NFRU::MfgSupported());
    }
    InParameters->Set("DLSSG.MultiFrameCountMax", Nvngx_NFRU::MfgSupported() ? 3u : 1u);
    InParameters->Set("DLSSG.MultiFrameCount", count);
    InParameters->Set("DLSSG.MustCallEval", 1);
    InParameters->Set("DLSSG.BurstCaptureRunning", 0);
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result EstimateVRAMCallback(uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
                                      uint32_t, size_t* EstimatedSize)
{
    if (EstimatedSize)
        *EstimatedSize = 300 * 1024 * 1024;
    return NVSDK_NGX_Result_Success;
}
}             

namespace
{
struct NfruSehInfo
{
    DWORD code = 0;
    void* address = nullptr;
};

int NfruSehFilter(EXCEPTION_POINTERS* ep, NfruSehInfo* out)
{
    out->code = ep->ExceptionRecord->ExceptionCode;
    out->address = ep->ExceptionRecord->ExceptionAddress;
    return EXCEPTION_EXECUTE_HANDLER;
}

                                                                                                                                  
                                                                                                         
template <typename Fn, typename... Args> bool NfruTryCall(Fn fn, ffxReturnCode_t* rc, NfruSehInfo* info, Args... args)
{
    __try
    {
        *rc = fn(args...);
        return true;
    }
    __except (NfruSehFilter(GetExceptionInformation(), info))
    {
        return false;
    }
}

template <typename Fn, typename... Args>
bool NfruSafeCall(Fn fn, ffxReturnCode_t* rc, const char* what, Args... args)
{
    NfruSehInfo info;
    if (NfruTryCall(fn, rc, &info, args...))
        return true;

    HMODULE mod = nullptr;
    char modName[MAX_PATH] = "?";
    size_t offset = 0;
    if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCSTR) info.address, &mod) &&
        mod)
    {
        GetModuleFileNameA(mod, modName, MAX_PATH);
        offset = (size_t) info.address - (size_t) mod;
    }
    LOG_ERROR("NFRU {} raised exception 0x{:X} at {} ({}+0x{:X})", what, info.code, info.address, modName, offset);
    return false;
}

                                                                                                                    
                                                                                                                      
                                                                                                             
                                                                           
constexpr uint64_t kRetireFrames = 3;
                                                                                                                
                                                      
std::atomic<int> g_swapTrace {0};
#define NFRU_SWAP_TRACE(step) do { if (g_swapTrace.load() > 0) LOG_INFO("NFRU swap trace: {}", step); } while (0)
std::mutex g_retireMutex;
struct NfruRetiredContext { ffxContext context;uint64_t frame;PfnFfxDestroyContext destroy; };
std::vector<NfruRetiredContext> g_retired;
std::atomic<uint64_t> g_realFrames {0};

ffxReturnCode_t NfruDestroyCtx(ffxContext* c)
{
    auto destroy = FfxApiProxy::VULKAN_NSS_DestroyContext();
    return destroy ? destroy(c, nullptr) : FFX_API_RETURN_OK;
}

void NfruRetireContext(ffxContext ctx, bool dx12 = false)
{
    if (!ctx)
        return;
    std::lock_guard<std::mutex> lock(g_retireMutex);
    g_retired.push_back({ctx,g_realFrames.load(),dx12?FfxApiProxy::D3D12_NSS_DestroyContext():FfxApiProxy::VULKAN_NSS_DestroyContext()});
    g_swapTrace = 40;
    LOG_INFO("NFRU context {} retired (destroyed after {} real frames)", (void*) ctx, kRetireFrames);
}

void NfruDestroyRetired(bool all)
{
    std::vector<NfruRetiredContext> now;
    {
        std::lock_guard<std::mutex> lock(g_retireMutex);
        const uint64_t f = g_realFrames.load();
        for (auto it = g_retired.begin(); it != g_retired.end();)
        {
            if (all || f >= it->frame + kRetireFrames) { now.push_back(*it); it = g_retired.erase(it); }
            else ++it;
        }
    }
    for (const auto& retired : now)
    {
        ffxReturnCode_t rc = FFX_API_RETURN_OK;
        NFRU_SWAP_TRACE("destroy retired: begin");
        ffxContext c=retired.context;
        if(retired.destroy) NfruSafeCall(retired.destroy, &rc, "DestroyContext (retired)", &c, nullptr);
        NFRU_SWAP_TRACE("destroy retired: end");
    }
}
}             

Nvngx_NFRU_Handle::~Nvngx_NFRU_Handle()
{
    if (State::Instance().isShuttingDown && asyncVk) asyncVk->Abandon();
    asyncVk.reset();                                                             
    if (ctx == nullptr || State::Instance().isShuttingDown)
        return;

    NfruRetireContext(ctx, dx12);                                                                          
    ctx = nullptr;
}


bool Nvngx_NFRU::isDx12Available()
{
    return _type != FGNvngxReplacement::OFG && FfxApiProxy::InitFfxDx12Nss();
}

static bool CopyTextureD3D12(ID3D12GraphicsCommandList* cl, ID3D12Resource* dst, ID3D12Resource* src,
                             D3D12_RESOURCE_STATES dstState = D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                             D3D12_RESOURCE_STATES srcState = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE)
{
    if (!cl || !dst || !src || dst == src)
        return false;

    D3D12_RESOURCE_BARRIER barriers[2] = {};
    barriers[0].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barriers[0].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    barriers[0].Transition.pResource = dst;
    barriers[0].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barriers[0].Transition.StateBefore = dstState;
    barriers[0].Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_DEST;

    barriers[1].Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barriers[1].Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE;
    barriers[1].Transition.pResource = src;
    barriers[1].Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barriers[1].Transition.StateBefore = srcState;
    barriers[1].Transition.StateAfter = D3D12_RESOURCE_STATE_COPY_SOURCE;

    cl->ResourceBarrier(2, barriers);
    cl->CopyResource(dst, src);

    std::swap(barriers[0].Transition.StateBefore, barriers[0].Transition.StateAfter);
    std::swap(barriers[1].Transition.StateBefore, barriers[1].Transition.StateAfter);
    cl->ResourceBarrier(2, barriers);
    return true;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_Init(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                        ID3D12Device* InDevice, const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo,
                                        NVSDK_NGX_Version InSDKVersion)
{
    return D3D12_Init_Ext(InApplicationId, InApplicationDataPath, InDevice, InSDKVersion, InFeatureInfo);
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_Init_Ext(unsigned long long, const wchar_t*, ID3D12Device* InDevice,
                                            NVSDK_NGX_Version, const NVSDK_NGX_FeatureCommonInfo*)
{
    if (!isDx12Available() || !InDevice)
        return NVSDK_NGX_Result_Fail;

    initD3D12Device = InDevice;
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_Shutdown() { return D3D12_Shutdown1(nullptr); }
NVSDK_NGX_Result Nvngx_NFRU::D3D12_Shutdown1(ID3D12Device*) { return NVSDK_NGX_Result_Success; }

NVSDK_NGX_Result Nvngx_NFRU::D3D12_GetScratchBufferSize(NVSDK_NGX_Feature, const NVSDK_NGX_Parameter*,
                                                        size_t* OutSizeInBytes)
{
    if (!OutSizeInBytes)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    *OutSizeInBytes = 0;
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_CreateFeature(ID3D12GraphicsCommandList*, NVSDK_NGX_Feature InFeatureID,
                                                 NVSDK_NGX_Parameter* InParameters, NVSDK_NGX_Handle** OutHandle)
{
    if (!isDx12Available())
        return NVSDK_NGX_Result_Fail;
    if (!InParameters || !OutHandle)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    if (InFeatureID != NVSDK_NGX_Feature_FrameGeneration)
        return NVSDK_NGX_Result_FAIL_FeatureNotSupported;

    auto* handle = new Nvngx_NFRU_Handle {};
    handle->Id = lastIdCreated++;
    handle->dx12 = true;
    handle->d3d12Device = initD3D12Device;
    InParameters->Get("Width", &handle->swapchainWidth);
    InParameters->Get("Height", &handle->swapchainHeight);
    *OutHandle = reinterpret_cast<NVSDK_NGX_Handle*>(handle);
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_ReleaseFeature(NVSDK_NGX_Handle* InHandle)
{
    if (!InHandle)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    delete reinterpret_cast<Nvngx_NFRU_Handle*>(InHandle);
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_GetFeatureRequirements(IDXGIAdapter*, const NVSDK_NGX_FeatureDiscoveryInfo*,
                                                          NVSDK_NGX_FeatureRequirement* OutSupported)
{
    if (!OutSupported)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    OutSupported->FeatureSupported = NVSDK_NGX_FeatureSupportResult_Supported;
    OutSupported->MinHWArchitecture = 0;
    strcpy_s(OutSupported->MinOSVersion, "10.0.0");
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_PopulateParameters_Impl(NVSDK_NGX_Parameter* InParameters)
{
    if (!InParameters)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;

    InParameters->Set("DLSSG.GetCurrentSettingsCallback", &GetCurrentSettingsCallback);
    InParameters->Set("DLSSG.EstimateVRAMCallback", &EstimateVRAMCallback);
    InParameters->Set("DLSSG.MultiFrameCountMax", getMaxFakeFramesCount());
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::D3D12_EvaluateFeature(ID3D12GraphicsCommandList* InCmdList,
                                                   const NVSDK_NGX_Handle* InFeatureHandle,
                                                   NVSDK_NGX_Parameter* InParameters,
                                                   PFN_NVSDK_NGX_ProgressCallback)
{
                                                                                                                          
                                                                                                          
    using namespace NfruAbi;

    auto* handle = reinterpret_cast<Nvngx_NFRU_Handle*>(const_cast<NVSDK_NGX_Handle*>(InFeatureHandle));
    if (!handle || !InParameters || InCmdList == nullptr || !isDx12Available())
        return NVSDK_NGX_Result_FAIL_InvalidParameter;

    uint32_t mfgIndex = 1, mfgCount = 1;
    InParameters->Get("DLSSG.MultiFrameIndex", &mfgIndex);
    InParameters->Get("DLSSG.MultiFrameCount", &mfgCount);
    {
        static uint32_t traced = 0;
        if (traced < 24)
        {
            ++traced;
            LOG_INFO("NFRU D3D12 MFG eval: index={} count={} max={} expected={} handleCount={}", mfgIndex, mfgCount,
                     getMaxFakeFramesCount(), handle->mfgExpectedIndex, handle->mfgCount);
        }
    }
    if (mfgCount < 1 || mfgCount > uint32_t(getMaxFakeFramesCount()) || mfgIndex < 1 || mfgIndex > mfgCount)
    {
        static uint32_t rejected = 0;
        if (rejected++ < 16)
            LOG_WARN("NFRU D3D12 MFG rejected (range): index={} count={} max={}", mfgIndex, mfgCount, getMaxFakeFramesCount());
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }
    const bool mfgFirst = mfgIndex == 1, mfgLast = mfgIndex == mfgCount;
    if(mfgFirst){g_realFrames.fetch_add(1);NfruDestroyRetired(false);}
    if (!mfgFirst && (handle->mfgExpectedIndex != mfgIndex || handle->mfgCount != mfgCount || handle->resetAfterAsyncFailure))
    {
        static uint32_t rejected = 0;
        if (rejected++ < 16)
            LOG_WARN("NFRU D3D12 MFG rejected (sequence): index={} count={} expected={} handleCount={} reset={}", mfgIndex,
                     mfgCount, handle->mfgExpectedIndex, handle->mfgCount, handle->resetAfterAsyncFailure);
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }

    ID3D12Resource* backbuffer = nullptr;
    ID3D12Resource* hudless = nullptr;
    ID3D12Resource* depth = nullptr;
    ID3D12Resource* motionVectors = nullptr;
    ID3D12Resource* output = nullptr;
    ID3D12Resource* outputReal = nullptr;
    InParameters->Get("DLSSG.Backbuffer", &backbuffer);
    InParameters->Get("DLSSG.HUDLess", &hudless);
    InParameters->Get("DLSSG.Depth", &depth);
    InParameters->Get("DLSSG.MVecs", &motionVectors);
    InParameters->Get("DLSSG.OutputInterpolated", &output);
    InParameters->Get("DLSSG.OutputReal", &outputReal);

    {
        static bool typeLogged = false;
        if (!typeLogged)
        {
            typeLogged = true;
            const D3D12_COMMAND_LIST_TYPE type = InCmdList->GetType();
            LOG_INFO("NFRU D3D12: command list type {} ({})", (int) type,
                     type == D3D12_COMMAND_LIST_TYPE_COMPUTE ? "COMPUTE" : (type == D3D12_COMMAND_LIST_TYPE_DIRECT ? "DIRECT" : "other"));
        }
    }
    if (!backbuffer || !depth || !motionVectors || !output)
    {
        LOG_ERROR("NFRU: D3D12 DLSSG resources are missing");
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }

                                                                                                                     
                                                                                                 
    const D3D12_RESOURCE_DESC backDesc = backbuffer->GetDesc();
    const D3D12_RESOURCE_DESC outDesc = output->GetDesc();
    const uint32_t displayW = static_cast<uint32_t>(outDesc.Width);
    const uint32_t displayH = outDesc.Height;

    uint32_t hudColorHdr = 0;
    InParameters->Get("DLSSG.ColorBuffersHDR", &hudColorHdr);
    const D3D12_RESOURCE_DESC hudDesc = hudless ? hudless->GetDesc() : D3D12_RESOURCE_DESC {};
    const bool mixedHudFormat = !hudColorHdr && hudless && hudDesc.Format == DXGI_FORMAT_R11G11B10_FLOAT &&
                                (backDesc.Format == DXGI_FORMAT_B8G8R8A8_UNORM || backDesc.Format == DXGI_FORMAT_R8G8B8A8_UNORM);
    const bool splitHud = Config::Instance()->NfruSeparateHud.value_or_default() && HudSeparationSupported() && hudless &&
                          hudless != backbuffer && hudless != output && hudDesc.Width == backDesc.Width &&
                          hudDesc.Height == backDesc.Height &&
                          (SurfaceFormatFromDxgi(hudDesc.Format) == SurfaceFormatFromDxgi(backDesc.Format) || mixedHudFormat);
    if (splitHud != handle->hudSeparated)
    {
        if (!mfgFirst)
        {
            static uint32_t rejected = 0;
            if (rejected++ < 16)
                LOG_WARN("NFRU D3D12 MFG rejected (HUD split changed mid-sequence): index={} count={} split={}", mfgIndex, mfgCount, splitHud);
            return NVSDK_NGX_Result_FAIL_InvalidParameter;
        }
        handle->hudSeparated = splitHud;
        handle->resetAfterAsyncFailure = true;                                                 
    }

    const D3D12_RESOURCE_DESC depthDesc = depth->GetDesc();
    uint32_t renderW = 0, renderH = 0;
    InParameters->Get("DLSSG.DepthSubrectWidth", &renderW);
    InParameters->Get("DLSSG.DepthSubrectHeight", &renderH);
    if (!renderW || !renderH)
    {
        renderW = static_cast<uint32_t>(depthDesc.Width);
        renderH = depthDesc.Height;
    }
    const uint32_t backFormat = SurfaceFormatFromDxgi(backDesc.Format);

    const D3D12_RESOURCE_DESC mvDesc = motionVectors->GetDesc();
    uint32_t mvWidth = 0, mvHeight = 0;
    InParameters->Get("DLSSG.MVecsSubrectWidth", &mvWidth);
    InParameters->Get("DLSSG.MVecsSubrectHeight", &mvHeight);
    if (!mvWidth || !mvHeight)
    {
        mvWidth = static_cast<uint32_t>(mvDesc.Width);
        mvHeight = mvDesc.Height;
    }

    const int mvCoverage = std::clamp(Config::Instance()->NfruMvCoverage.value_or_default(), 0, 2);
    const bool displayResolutionMotionVectors = mvWidth == displayW && mvHeight == displayH;
    uint32_t cameraMotionIncluded = 0;
    const bool cameraMotionKnown = InParameters->Get("DLSSG.CameraMotionIncluded", &cameraMotionIncluded) == NVSDK_NGX_Result_Success;
    const bool fullMotionVectors = mvCoverage == 1 || (mvCoverage == 0 && cameraMotionKnown && cameraMotionIncluded != 0);

    const bool sizeChanged = displayW != handle->swapchainWidth || displayH != handle->swapchainHeight ||
                             renderW != handle->renderWidth || renderH != handle->renderHeight ||
                             mvWidth != handle->motionVectorWidth || mvHeight != handle->motionVectorHeight ||
                             backFormat != handle->backbufferFormat;
    if ((State::Instance().fgChanged || sizeChanged) && handle->ctx)
    {
        NfruRetireContext(handle->ctx,true);
        handle->ctx = nullptr;
        handle->lastFrameId = 0;
    }
    State::Instance().fgChanged = false;

    uint32_t depthInverted = 0, hdr = 0, jittered = 0;
    InParameters->Get("DLSSG.DepthInverted", &depthInverted);
    InParameters->Get("DLSSG.ColorBuffersHDR", &hdr);
    InParameters->Get("DLSSG.MvecJittered", &jittered);

    uint32_t mvBaseX = 0, mvBaseY = 0;
    InParameters->Get("DLSSG.MVecsSubrectBaseX", &mvBaseX);
    InParameters->Get("DLSSG.MVecsSubrectBaseY", &mvBaseY);
    float mvScaleX = 0.0f, mvScaleY = 0.0f;
    const bool dlssgPixelScale = InParameters->Get("DLSSG.MvecScaleX", &mvScaleX) == NVSDK_NGX_Result_Success &&
                                 InParameters->Get("DLSSG.MvecScaleY", &mvScaleY) == NVSDK_NGX_Result_Success;
    const bool pixelScaleKnown = dlssgPixelScale ||
        (InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_X, &mvScaleX) == NVSDK_NGX_Result_Success &&
         InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_Y, &mvScaleY) == NVSDK_NGX_Result_Success);
    const bool mvExtentValid = (displayResolutionMotionVectors || (mvWidth == renderW && mvHeight == renderH)) &&
                               mvWidth == static_cast<uint32_t>(mvDesc.Width) && mvHeight == mvDesc.Height;
    if (!pixelScaleKnown || !std::isfinite(mvScaleX) || !std::isfinite(mvScaleY) || mvScaleX == 0.0f || mvScaleY == 0.0f ||
        mvBaseX || mvBaseY || !mvExtentValid || jittered)
    {
        static uint32_t invalidMvCount = 0;
        if (invalidMvCount++ < 4)
            LOG_WARN("NFRU D3D12: rejecting unsupported MV contract: scaleKnown={} scale=({}, {}) origin=({}, {}) extentValid={} jittered={}",
                     pixelScaleKnown, mvScaleX, mvScaleY, mvBaseX, mvBaseY, mvExtentValid, jittered);
        CopyTextureD3D12(InCmdList, output, backbuffer);
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }

                                                                                                                         
    _putenv_s("NFRU_GAME_MV", fullMotionVectors ? "1" : "0");
    const int requestedOfMode = Config::Instance()->NfruOfMode.value_or_default();
    const int effectiveOfMode = fullMotionVectors ? 0 : requestedOfMode;
    _putenv_s("NFRU_OF_MODE", std::to_string(effectiveOfMode).c_str());
    _putenv_s("NFRU_OF_RADIUS", std::to_string(Config::Instance()->NfruOfRadius.value_or_default()).c_str());
    _putenv_s("NFRU_OF_ADAPTIVE", Config::Instance()->NfruOfAdaptive.value_or_default() ? "1" : "0");
    _putenv_s("NFRU_OF_EXIT_CAMERA", Config::Instance()->NfruOfExitCamera.value_or_default() ? "1" : "0");
    _putenv_s("NFRU_DYN_REL", Config::Instance()->NfruDynamicRelative.value_or_default() ? "1" : "0"); _putenv_s("NFRU_ANGULAR", Config::Instance()->NfruAngular.value_or_default() ? "1" : "0"); _putenv_s("NFRU_OCCLUSION", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0"); _putenv_s("NFRU_T2", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0"); _putenv_s("NFRU_SPLAT_STRETCH", Config::Instance()->NfruSplatStretch.value_or_default() ? "1" : "0"); _putenv_s("NFRU_DEBUG_VIEW", std::to_string(std::clamp(Config::Instance()->NfruDebugView.value_or_default(), 0, 17)).c_str()); _putenv_s("NFRU_HOLE_CAMERA", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0");
                                                                                                                  
    _putenv_s("OFG_ENABLE", "0");
    _putenv_s("NFRU_BACKEND", "dp4a");

    float cameraNear = 0.0f, cameraFar = 0.0f, cameraFov = 0.0f;
    const bool nearValid = InParameters->Get("DLSSG.CameraNear", &cameraNear) == NVSDK_NGX_Result_Success;
    const bool farValid = InParameters->Get("DLSSG.CameraFar", &cameraFar) == NVSDK_NGX_Result_Success;
    const bool fovValid = InParameters->Get("DLSSG.CameraFOV", &cameraFov) == NVSDK_NGX_Result_Success;
    if (!nearValid || !farValid || !fovValid)
    {
        uint32_t orthographic = 0;
        float (*viewToClip)[4] = nullptr;
        InParameters->Get("DLSSG.OrthoProjection", &orthographic);
        InParameters->Get("DLSSG.CameraViewToClip", reinterpret_cast<void**>(&viewToClip));
        if (!orthographic && viewToClip)
        {
            const double b = viewToClip[1][1], c = viewToClip[2][2], d = viewToClip[3][2], e = viewToClip[2][3];
            if (std::abs(b) > 1.0e-6 && std::abs(c) > 1.0e-6)
            {
                float derivedNear = 0.0f, derivedFar = 0.0f;
                if (e < 0.0)
                {
                    derivedNear = static_cast<float>(d / c);
                    if (std::abs(c + 1.0) > 1.0e-6)
                        derivedFar = static_cast<float>(d / (c + 1.0));
                }
                else
                {
                    derivedNear = static_cast<float>(-d / c);
                    if (std::abs(c - 1.0) > 1.0e-6)
                        derivedFar = static_cast<float>(-d / (c - 1.0));
                }
                if (depthInverted)
                    std::swap(derivedNear, derivedFar);
                if (!nearValid && std::isfinite(derivedNear) && derivedNear >= 0.0f)
                    cameraNear = derivedNear;
                if (!farValid && std::isfinite(derivedFar) && derivedFar >= 0.0f)
                    cameraFar = derivedFar;
                if (!fovValid)
                    cameraFov = static_cast<float>(2.0 * std::atan(1.0 / std::abs(b)));
            }
        }
    }
    {
        uint32_t projOrtho = 0;
        float (*proj)[4] = nullptr;
        InParameters->Get("DLSSG.OrthoProjection", &projOrtho);
        InParameters->Get("DLSSG.CameraViewToClip", reinterpret_cast<void**>(&proj));
        if (!projOrtho && proj && std::abs(proj[1][1]) > 1.0e-6f)
            cameraFov = static_cast<float>(2.0 * std::atan(1.0 / std::abs(proj[1][1])));
    }
    if (cameraFov == 0.0f)
        cameraFov = 90.0f;
    if (cameraFov > 10.0f)
        cameraFov *= std::numbers::pi_v<float> / 180.0f;
    const bool depthInfinite = cameraNear != 0.0f && cameraFar == 0.0f;
    if (depthInfinite)
        cameraFar = cameraNear + 1.0f;

    if (!handle->ctx)
    {
        ScopedSkipSpoofingGlobal skipSpoofingGlobal {};

        BackendDX12Desc backend = {};
        backend.header.type = DESC_BACKEND_DX12;
        backend.device = handle->d3d12Device;

        CreateDescFG create = {};
        create.header.type = DESC_CREATE_FG;
        create.header.pNext = &backend.header;
        create.displaySize = { displayW, displayH };
        create.renderSize = { renderW, renderH };
        create.backBufferFormat = backFormat;
        create.flags = FG_MANAGE_PREVIOUS_DEPTH | FG_MANAGE_PREVIOUS_COLOR;
        if (hdr)
            create.flags |= FG_HDR;
        if (depthInverted)
            create.flags |= FG_DEPTH_INVERTED;
        if (depthInfinite)
            create.flags |= FG_DEPTH_INFINITE;
        if (jittered)
            create.flags |= FG_MV_JITTER_CANCELLATION;
        if (displayResolutionMotionVectors)
            create.flags |= FG_DISPLAY_RESOLUTION_MVS;
        for (int i = 0; i < 4; ++i)
            create.initialViewProjection[i * 5] = 1.0f;

        LOG_INFO("NFRU D3D12: MV coverage={} mvSubrect={}x{} mvImage={}x{} display={}x{} displayRes={} requested OF={} effective OF={}",
                 mvCoverage == 0 ? "auto" : (mvCoverage == 1 ? "full" : "incomplete"), mvWidth, mvHeight,
                 static_cast<uint32_t>(mvDesc.Width), mvDesc.Height, displayW, displayH, displayResolutionMotionVectors,
                 requestedOfMode, effectiveOfMode);

        auto createFn = FfxApiProxy::D3D12_NSS_CreateContext();
        ffxReturnCode_t rc = FFX_API_RETURN_ERROR;
        if (createFn && !NfruSafeCall(createFn, &rc, "create context (DX12)", &handle->ctx, &create.header, nullptr))
            rc = FFX_API_RETURN_ERROR;
        LOG_INFO("NFRU D3D12: FG context create display={}x{} render={}x{} format={} flags={:X} -> {}", displayW, displayH,
                 renderW, renderH, backFormat, create.flags, (int) rc);
        if (rc != FFX_API_RETURN_OK)
        {
            handle->ctx = nullptr;
            CopyTextureD3D12(InCmdList, output, backbuffer);
            return NVSDK_NGX_Result_Fail;
        }
        handle->swapchainWidth = displayW;
        handle->swapchainHeight = displayH;
        handle->renderWidth = renderW;
        handle->renderHeight = renderH;
        handle->motionVectorWidth = mvWidth;
        handle->motionVectorHeight = mvHeight;
        handle->backbufferFormat = backFormat;
        handle->hdr = hdr != 0;
    }

                                                                              
    handle->realFramePacer.Pace(Config::Instance()->NfruRealFrameLimit.value_or_default(), mfgFirst);

    if (mfgFirst)
    {
        if (handle->mfgExpectedIndex != 1) handle->resetAfterAsyncFailure = true;
        ++handle->lastFrameId;
        handle->mfgCount = mfgCount;
        handle->mfgExpectedIndex = 1;
    }

    ConfigureDescFG configure = {};
    configure.header.type = DESC_CONFIGURE_FG;
    configure.frameGenerationEnabled = true;
    configure.allowAsyncWorkloads = false;
    configure.flags = FG_DISPATCH_NO_SWAPCHAIN_NOTIFY;
    if (Config::Instance()->FGDebugView.value_or_default())
        configure.flags |= FG_DISPATCH_DRAW_DEBUG_VIEW;
    configure.frameID = handle->lastFrameId;

    auto configureFn = FfxApiProxy::D3D12_NSS_Configure();
    ffxReturnCode_t configureRc = FFX_API_RETURN_ERROR;
    if (configureFn && !NfruSafeCall(configureFn, &configureRc, "configure (DX12)", &handle->ctx, &configure.header))
        configureRc = FFX_API_RETURN_ERROR;
    if (!configureFn || configureRc != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NFRU D3D12: FG configure failed");
        CopyTextureD3D12(InCmdList, output, backbuffer);
        return NVSDK_NGX_Result_Fail;
    }

    uint32_t reset = 0;
    InParameters->Get("DLSSG.Reset", &reset);
    if (handle->lastFrameId == 1 || handle->resetAfterAsyncFailure)
        reset = 1;

    PrepareDescFG prepare = {};
    prepare.header.type = DESC_DISPATCH_FG_PREPARE;
    prepare.commandList = InCmdList;
    prepare.frameID = handle->lastFrameId;
    InParameters->Get("DLSSG.JitterOffsetX", &prepare.jitterOffset.x);
    InParameters->Get("DLSSG.JitterOffsetY", &prepare.jitterOffset.y);
    prepare.motionVectorScale = { mvScaleX, mvScaleY };

    const auto now = std::chrono::steady_clock::now();
    auto& lastEval = handle->lastRealEval;
    float measuredFrameTime = 1000.0f / 60.0f;
    if (lastEval.time_since_epoch().count() != 0)
        measuredFrameTime = std::chrono::duration<float, std::milli>(now - lastEval).count();
    if (mfgFirst) lastEval = now;
    const bool frameTimeFromInput =
        InParameters->Get("FSR.frameTimeDelta", &prepare.frameTimeDelta) == NVSDK_NGX_Result_Success ||
        InParameters->Get(NVSDK_NGX_Parameter_FrameTimeDeltaInMsec, &prepare.frameTimeDelta) == NVSDK_NGX_Result_Success;
    if (!frameTimeFromInput || !std::isfinite(prepare.frameTimeDelta) || prepare.frameTimeDelta <= 0.0f)
        prepare.frameTimeDelta = std::clamp(measuredFrameTime, 1.0f, 100.0f);
    if (mfgFirst) handle->mfgFrameTimeDelta = prepare.frameTimeDelta;
    else prepare.frameTimeDelta = handle->mfgFrameTimeDelta;

    prepare.viewSpaceToMetersFactor = 1.0f;
    prepare.cameraNear = cameraNear;
    prepare.cameraFar = cameraFar;
    prepare.cameraFovAngleVertical = cameraFov;
    prepare.depth = GetResourceD3D12(depth, STATE_COPY_DEST);
    prepare.motionVectors = GetResourceD3D12(motionVectors, STATE_COPY_DEST);
    if (mfgFirst)
    {
        float (*projection)[4] = nullptr;
        float pos[3] {}, right[3] {}, up[3] {}, forward[3] {};
        const char* posKeys[] = { "DLSSG.CameraPosX", "DLSSG.CameraPosY", "DLSSG.CameraPosZ" };
        const char* rightKeys[] = { "DLSSG.CameraRightX", "DLSSG.CameraRightY", "DLSSG.CameraRightZ" };
        const char* upKeys[] = { "DLSSG.CameraUpX", "DLSSG.CameraUpY", "DLSSG.CameraUpZ" };
        const char* forwardKeys[] = { "DLSSG.CameraFwdX", "DLSSG.CameraFwdY", "DLSSG.CameraFwdZ" };
        bool available = InParameters->Get("DLSSG.CameraViewToClip", reinterpret_cast<void**>(&projection)) == NVSDK_NGX_Result_Success && projection;
        for (int c = 0; c < 3; ++c)
        {
            available &= InParameters->Get(posKeys[c], &pos[c]) == NVSDK_NGX_Result_Success;
            available &= InParameters->Get(rightKeys[c], &right[c]) == NVSDK_NGX_Result_Success;
            available &= InParameters->Get(upKeys[c], &up[c]) == NVSDK_NGX_Result_Success;
            available &= InParameters->Get(forwardKeys[c], &forward[c]) == NVSDK_NGX_Result_Success;
        }
        const float* origin = handle->cameraOriginValid ? handle->cameraOrigin : pos;
        float candidate[16] {};
        const bool valid = available && NfruBuildCameraViewProjection(&projection[0][0], pos, right, up, forward, origin, candidate);
        if (valid != handle->mfgCameraValid) { handle->resetAfterAsyncFailure = true; reset = 1; }
        handle->mfgCameraValid = valid;
        std::fill(std::begin(handle->mfgViewProjection), std::end(handle->mfgViewProjection), 0.0f);
        if (valid)
        {
            if (!handle->cameraOriginValid) { std::copy(pos, pos + 3, handle->cameraOrigin); handle->cameraOriginValid = true; }
            std::copy(candidate, candidate + 16, handle->mfgViewProjection);
        }
        else
        {
            for (int i = 0; i < 4; ++i) handle->mfgViewProjection[i * 5] = 1.0f;
        }
    }
    std::copy(std::begin(handle->mfgViewProjection), std::end(handle->mfgViewProjection), prepare.viewProjection);

    if (handle->lastFrameId <= 4 && mfgFirst)
        LOG_INFO("NFRU D3D12 Prepare frame={} render={}x{} mv={}x{} mvScale=({}, {}) jitter=({}, {}) dt={}ms camera=({}, {}, {}) "
                 "depthInv={} hdr={} hudless={} hudSplit={} gameMV->OF={} mfgCount={}",
                 handle->lastFrameId, renderW, renderH, mvWidth, mvHeight, prepare.motionVectorScale.x, prepare.motionVectorScale.y,
                 prepare.jitterOffset.x, prepare.jitterOffset.y, prepare.frameTimeDelta, cameraNear, cameraFar, cameraFov,
                 depthInverted, hdr, hudless != nullptr, splitHud, fullMotionVectors, mfgCount);

    auto dispatchFn = FfxApiProxy::D3D12_NSS_Dispatch();
    if (!dispatchFn)
    {
        LOG_ERROR("NFRU D3D12: FG dispatch function is unavailable");
        CopyTextureD3D12(InCmdList, output, backbuffer);
        return NVSDK_NGX_Result_Fail;
    }

    ffxReturnCode_t prepareResult = FFX_API_RETURN_ERROR;
    if (!NfruSafeCall(dispatchFn, &prepareResult, "prepare (DX12)", &handle->ctx, &prepare.header))
        prepareResult = FFX_API_RETURN_ERROR;
    if (prepareResult != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NFRU D3D12: FG prepare failed: {}", (int) prepareResult);
        CopyTextureD3D12(InCmdList, output, backbuffer);
        handle->resetAfterAsyncFailure = true;
        return NVSDK_NGX_Result_Fail;
    }

    DispatchDescFG generate = {};
    generate.header.type = DESC_DISPATCH_FG;
    generate.commandList = InCmdList;
    generate.frameID = handle->lastFrameId;
    generate.presentColor = splitHud ? GetResourceD3D12(hudless, STATE_COPY_DEST) : GetResourceD3D12(backbuffer, STATE_COMPUTE_READ);
    generate.outputs[0] = GetResourceD3D12(output, STATE_UNORDERED_ACCESS);
    generate.numGeneratedFrames = 1;
    if (mfgFirst) handle->mfgReset = reset != 0;
    generate.reset = handle->mfgReset;
    MfgDesc mfgDesc {};
    if (mfgCount > 1)
    {
        mfgDesc.header.type = DESC_MFG;
        mfgDesc.index = mfgIndex;
        mfgDesc.count = mfgCount;
        generate.header.pNext = &mfgDesc.header;
    }
    HudDesc hudDescFg {};
    if (splitHud)
    {
        hudDescFg.header.type = DESC_HUD;
        hudDescFg.header.pNext = generate.header.pNext;
        hudDescFg.fullColor = GetResourceD3D12(backbuffer, STATE_COMPUTE_READ);
        generate.header.pNext = &hudDescFg.header;
    }

    ffxReturnCode_t generateResult = FFX_API_RETURN_ERROR;
    if (!NfruSafeCall(dispatchFn, &generateResult, "generate (DX12)", &handle->ctx, &generate.header))
        generateResult = FFX_API_RETURN_ERROR;

                                                                                                                  
    if (outputReal)
    {
        const bool debugView = Config::Instance()->FGDebugView.value_or_default();
        if (!CopyTextureD3D12(InCmdList, outputReal, debugView ? output : backbuffer, D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                              debugView ? D3D12_RESOURCE_STATE_UNORDERED_ACCESS : D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE))
            LOG_WARN("NFRU D3D12: failed to populate DLSSG.OutputReal on frame {}", handle->lastFrameId);
    }

    if (generateResult != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NFRU D3D12: FG generation failed: {}", (int) generateResult);
        CopyTextureD3D12(InCmdList, output, backbuffer);
    }
    handle->mfgExpectedIndex = generateResult == FFX_API_RETURN_OK && !mfgLast ? mfgIndex + 1 : 1;
    handle->resetAfterAsyncFailure = generateResult != FFX_API_RETURN_OK;
    return generateResult == FFX_API_RETURN_OK ? NVSDK_NGX_Result_Success : NVSDK_NGX_Result_Fail;
}

bool Nvngx_NFRU::isVulkanAvailable()
{
                                                                                       
    return !(_type == FGNvngxReplacement::OFG && State::Instance().api == DX12) && FfxApiProxy::InitFfxVkNss();
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_Init(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                         VkInstance InInstance, VkPhysicalDevice InPD, VkDevice InDevice,
                                         PFN_vkGetInstanceProcAddr InGIPA, PFN_vkGetDeviceProcAddr InGDPA,
                                         const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo,
                                         NVSDK_NGX_Version InSDKVersion)
{
    return VULKAN_Init_Ext2(InApplicationId, InApplicationDataPath, InInstance, InPD, InDevice, InGIPA, InGDPA,
                            InSDKVersion, InFeatureInfo);
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_Init_Ext(unsigned long long InApplicationId, const wchar_t* InApplicationDataPath,
                                             VkInstance InInstance, VkPhysicalDevice InPD, VkDevice InDevice,
                                             NVSDK_NGX_Version InSDKVersion,
                                             const NVSDK_NGX_FeatureCommonInfo* InFeatureInfo)
{
    return VULKAN_Init_Ext2(InApplicationId, InApplicationDataPath, InInstance, InPD, InDevice, vkGetInstanceProcAddr,
                            vkGetDeviceProcAddr, InSDKVersion, InFeatureInfo);
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_Init_Ext2(unsigned long long, const wchar_t*, VkInstance InInstance,
                                              VkPhysicalDevice InPD, VkDevice InDevice,
                                              PFN_vkGetInstanceProcAddr InGIPA, PFN_vkGetDeviceProcAddr InGDPA,
                                              NVSDK_NGX_Version, const NVSDK_NGX_FeatureCommonInfo*)
{
    if (!isVulkanAvailable() || InPD == VK_NULL_HANDLE || InDevice == VK_NULL_HANDLE)
        return NVSDK_NGX_Result_Fail;

    initVkInstance = InInstance;
    initVkPhysicalDevice = InPD;
    initVkDevice = InDevice;
    initVkInstanceProcAddr = InGIPA ? InGIPA : vkGetInstanceProcAddr;
    initVkDeviceProcAddr = InGDPA ? InGDPA : vkGetDeviceProcAddr;
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_Shutdown() { return VULKAN_Shutdown1(VK_NULL_HANDLE); }
NVSDK_NGX_Result Nvngx_NFRU::VULKAN_Shutdown1(VkDevice) { return NVSDK_NGX_Result_Success; }

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_GetScratchBufferSize(NVSDK_NGX_Feature, const NVSDK_NGX_Parameter*,
                                                         size_t* OutSizeInBytes)
{
    if (!OutSizeInBytes)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    *OutSizeInBytes = 0;
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_CreateFeature(VkCommandBuffer InCmdBuffer, NVSDK_NGX_Feature InFeatureID,
                                                  NVSDK_NGX_Parameter* InParameters, NVSDK_NGX_Handle** OutHandle)
{
    return VULKAN_CreateFeature1(initVkDevice, InCmdBuffer, InFeatureID, InParameters, OutHandle);
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_CreateFeature1(VkDevice InDevice, VkCommandBuffer, NVSDK_NGX_Feature InFeatureID,
                                                   NVSDK_NGX_Parameter* InParameters, NVSDK_NGX_Handle** OutHandle)
{
    if (!isVulkanAvailable())
        return NVSDK_NGX_Result_Fail;
    if (!InParameters || !OutHandle || InDevice == VK_NULL_HANDLE)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    if (InFeatureID != NVSDK_NGX_Feature_FrameGeneration)
        return NVSDK_NGX_Result_FAIL_FeatureNotSupported;

    auto* handle = new Nvngx_NFRU_Handle {};
    handle->Id = lastIdCreated++;
    handle->vkInstance = initVkInstance;
    handle->vkPhysicalDevice = initVkPhysicalDevice;
    handle->vkDevice = InDevice;
    handle->vkDeviceProcAddr = initVkDeviceProcAddr ? initVkDeviceProcAddr : vkGetDeviceProcAddr;
    handle->vkInstanceProcAddr = initVkInstanceProcAddr ? initVkInstanceProcAddr : vkGetInstanceProcAddr;
    InParameters->Get("Width", &handle->swapchainWidth);
    InParameters->Get("Height", &handle->swapchainHeight);
    *OutHandle = reinterpret_cast<NVSDK_NGX_Handle*>(handle);
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_ReleaseFeature(NVSDK_NGX_Handle* InHandle)
{
    if (!InHandle)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    delete reinterpret_cast<Nvngx_NFRU_Handle*>(InHandle);
    return NVSDK_NGX_Result_Success;
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_GetFeatureRequirements(const VkInstance, const VkPhysicalDevice,
                                                           const NVSDK_NGX_FeatureDiscoveryInfo*,
                                                           NVSDK_NGX_FeatureRequirement* OutSupported)
{
    if (!OutSupported)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    OutSupported->FeatureSupported = NVSDK_NGX_FeatureSupportResult_Supported;
    OutSupported->MinHWArchitecture = 0;
    strcpy_s(OutSupported->MinOSVersion, "10.0.0");
    return NVSDK_NGX_Result_Success;
}

static bool NfruSdkExportIs(PfnFfxDispatch fn, const char* exportName, uint32_t expected)
{
    HMODULE module = nullptr;
    if (!fn || !GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                  reinterpret_cast<LPCWSTR>(fn), &module)) return false;
    auto version = reinterpret_cast<uint32_t(*)()>(GetProcAddress(module, exportName));
    return version && version() == expected;
}
static bool NfruSdkVersion(const char* exportName, uint32_t expected)
{
    const API api = State::Instance().api;
    if (api == DX12)
        return NfruSdkExportIs(FfxApiProxy::D3D12_NSS_Dispatch(), exportName, expected);
    if (api == Vulkan)
        return NfruSdkExportIs(FfxApiProxy::VULKAN_NSS_Dispatch(), exportName, expected);
                                                              
    return NfruSdkExportIs(FfxApiProxy::VULKAN_NSS_Dispatch(), exportName, expected) ||
           NfruSdkExportIs(FfxApiProxy::D3D12_NSS_Dispatch(), exportName, expected);
}
bool Nvngx_NFRU::MfgSupported() { return NfruSdkVersion("ffxNfruMfgVersion", 0x00010000u); }
bool Nvngx_NFRU::HudSeparationSupported() { return NfruSdkVersion("ffxNfruHudVersion", 0x00010001u); }
bool Nvngx_NFRU::OfgActive()
{
    return State::Instance().api != DX12 && State::Instance().activeFgNvngx == FGNvngxReplacement::OFG;
}
bool Nvngx_NFRU::Mlof2Active()
{
                                                                            
    return false;
}
int Nvngx_NFRU::getMaxFakeFramesCount()
{
    return MfgSupported() ? 3 : 1;
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_EvaluateFeature(VkCommandBuffer InCmdList, const NVSDK_NGX_Handle* InFeatureHandle,
                                                    NVSDK_NGX_Parameter* InParameters, PFN_NVSDK_NGX_ProgressCallback)
{
    using namespace NfruAbi;

    auto* handle = reinterpret_cast<Nvngx_NFRU_Handle*>(const_cast<NVSDK_NGX_Handle*>(InFeatureHandle));
    if (!handle || !InParameters || InCmdList == VK_NULL_HANDLE || !isVulkanAvailable())
        return NVSDK_NGX_Result_FAIL_InvalidParameter;

    uint32_t mfgIndex = 1, mfgCount = 1;
    InParameters->Get("DLSSG.MultiFrameIndex", &mfgIndex);
    InParameters->Get("DLSSG.MultiFrameCount", &mfgCount);
    {
                                                                                                             
        static uint32_t traced = 0;
        if (traced < 24)
        {
            ++traced;
            LOG_INFO("NFRU MFG eval: index={} count={} max={} expected={} handleCount={}", mfgIndex, mfgCount,
                     getMaxFakeFramesCount(), handle->mfgExpectedIndex, handle->mfgCount);
        }
    }
    if (mfgCount < 1 || mfgCount > uint32_t(getMaxFakeFramesCount()) || mfgIndex < 1 || mfgIndex > mfgCount)
    {
        static uint32_t rejected = 0;
        if (rejected++ < 16)
            LOG_WARN("NFRU MFG rejected (range): index={} count={} max={}", mfgIndex, mfgCount, getMaxFakeFramesCount());
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }
    const bool mfgFirst = mfgIndex == 1, mfgLast = mfgIndex == mfgCount;
    if (g_swapTrace.load() > 0)
    {
        LOG_INFO("NFRU swap trace: evaluate index={} count={} frames={}", mfgIndex, mfgCount, g_realFrames.load());
        g_swapTrace.fetch_sub(1);
    }
    if (!mfgFirst && (handle->mfgExpectedIndex != mfgIndex || handle->mfgCount != mfgCount || handle->resetAfterAsyncFailure))
    {
        static uint32_t rejected = 0;
        if (rejected++ < 16)
            LOG_WARN("NFRU MFG rejected (sequence): index={} count={} expected={} handleCount={} asyncReset={}", mfgIndex,
                     mfgCount, handle->mfgExpectedIndex, handle->mfgCount, handle->resetAfterAsyncFailure);
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }
    NVSDK_NGX_Resource_VK* backbuffer = nullptr;
    NVSDK_NGX_Resource_VK* hudless = nullptr;
    NVSDK_NGX_Resource_VK* depth = nullptr;
    NVSDK_NGX_Resource_VK* motionVectors = nullptr;
    NVSDK_NGX_Resource_VK* output = nullptr;
    NVSDK_NGX_Resource_VK* outputReal = nullptr;
    InParameters->Get("DLSSG.Backbuffer", reinterpret_cast<void**>(&backbuffer));
    InParameters->Get("DLSSG.HUDLess", reinterpret_cast<void**>(&hudless));
    InParameters->Get("DLSSG.Depth", reinterpret_cast<void**>(&depth));
    InParameters->Get("DLSSG.MVecs", reinterpret_cast<void**>(&motionVectors));
    InParameters->Get("DLSSG.OutputInterpolated", reinterpret_cast<void**>(&output));
    InParameters->Get("DLSSG.OutputReal", reinterpret_cast<void**>(&outputReal));

    if (!backbuffer || !depth || !motionVectors || !output ||
        backbuffer->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW ||
        depth->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW ||
        motionVectors->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW ||
        output->Type != NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW)
    {
        LOG_ERROR("NFRU: Vulkan DLSSG resources are missing or aren't image views");
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }

                                                                                   
                                                                                      
    uint32_t hudColorHdr = 0;
    InParameters->Get("DLSSG.ColorBuffersHDR", &hudColorHdr);
    const bool mixedHudFormat = !hudColorHdr && hudless &&
        hudless->Type == NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW &&
        hudless->Resource.ImageViewInfo.Format == VK_FORMAT_B10G11R11_UFLOAT_PACK32 &&
        (backbuffer->Resource.ImageViewInfo.Format == VK_FORMAT_B8G8R8A8_UNORM ||
         backbuffer->Resource.ImageViewInfo.Format == VK_FORMAT_R8G8B8A8_UNORM);
    const bool splitHud = Config::Instance()->NfruSeparateHud.value_or_default() && HudSeparationSupported() &&
        hudless && hudless->Type == NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW &&
        hudless->Resource.ImageViewInfo.Image != VK_NULL_HANDLE &&
        hudless->Resource.ImageViewInfo.Image != backbuffer->Resource.ImageViewInfo.Image &&
        hudless->Resource.ImageViewInfo.Image != output->Resource.ImageViewInfo.Image &&
        hudless->Resource.ImageViewInfo.Width == backbuffer->Resource.ImageViewInfo.Width &&
        hudless->Resource.ImageViewInfo.Height == backbuffer->Resource.ImageViewInfo.Height &&
        (hudless->Resource.ImageViewInfo.Format == backbuffer->Resource.ImageViewInfo.Format || mixedHudFormat);
    if (splitHud != handle->hudSeparated) {
        if (!mfgFirst)
        {
            static uint32_t rejected = 0;
            if (rejected++ < 16)
                LOG_WARN("NFRU MFG rejected (HUD split changed mid-sequence): index={} count={} split={}", mfgIndex, mfgCount, splitHud);
            return NVSDK_NGX_Result_FAIL_InvalidParameter;
        }
        handle->hudSeparated = splitHud;
        handle->resetAfterAsyncFailure = true;                                                 
    }
    const auto* sceneSource = splitHud ? hudless : backbuffer;
    if (mfgFirst && handle->lastFrameId == 0 && Config::Instance()->NfruSeparateHud.value_or_default()) {
        const bool validView = hudless && hudless->Type == NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW;
        LOG_INFO("NFRU HUD separation={} full={}x{} fmt={} hud={}x{} fmt={}", splitHud,
                 backbuffer->Resource.ImageViewInfo.Width, backbuffer->Resource.ImageViewInfo.Height,
                 (uint32_t)backbuffer->Resource.ImageViewInfo.Format,
                 validView ? hudless->Resource.ImageViewInfo.Width : 0,
                 validView ? hudless->Resource.ImageViewInfo.Height : 0,
                 validView ? (uint32_t)hudless->Resource.ImageViewInfo.Format : 0);
    }

    const Resource outputRes = GetResource(output, STATE_UNORDERED_ACCESS);
    const uint32_t displayW = outputRes.description.width, displayH = outputRes.description.height;
    uint32_t renderW = 0, renderH = 0;
    InParameters->Get("DLSSG.DepthSubrectWidth", &renderW);
    InParameters->Get("DLSSG.DepthSubrectHeight", &renderH);
    if (!renderW || !renderH)
    {
        renderW = depth->Resource.ImageViewInfo.Width;
        renderH = depth->Resource.ImageViewInfo.Height;
    }
    const uint32_t backFormat = GetResource(backbuffer, STATE_COMPUTE_READ).description.format;
    uint32_t mvWidth = 0, mvHeight = 0;
    InParameters->Get("DLSSG.MVecsSubrectWidth", &mvWidth);
    InParameters->Get("DLSSG.MVecsSubrectHeight", &mvHeight);
    if (!mvWidth || !mvHeight)
    {
        mvWidth = motionVectors->Resource.ImageViewInfo.Width;
        mvHeight = motionVectors->Resource.ImageViewInfo.Height;
    }

    const int mvCoverage = std::clamp(Config::Instance()->NfruMvCoverage.value_or_default(), 0, 2);
    const bool displayResolutionMotionVectors = mvWidth == displayW && mvHeight == displayH;
    uint32_t cameraMotionIncluded = 0;
    const bool cameraMotionKnown = InParameters->Get("DLSSG.CameraMotionIncluded", &cameraMotionIncluded) == NVSDK_NGX_Result_Success;
                                                                                                
    const bool fullMotionVectors = mvCoverage == 1 || (mvCoverage == 0 && cameraMotionKnown && cameraMotionIncluded != 0);

                                                                                         
    const bool sizeChanged = displayW != handle->swapchainWidth || displayH != handle->swapchainHeight ||
                             renderW != handle->renderWidth || renderH != handle->renderHeight ||
                             mvWidth != handle->motionVectorWidth || mvHeight != handle->motionVectorHeight ||
                             backFormat != handle->backbufferFormat;
    if (mfgFirst)
        NfruDestroyRetired(false);
    if ((State::Instance().fgChanged || sizeChanged) && handle->ctx)
    {
        if (!mfgFirst)
        {
                                                                                                                 
                                                              
            if (sizeChanged)
                return NVSDK_NGX_Result_FAIL_InvalidParameter;
        }
        else
        {
            NfruRetireContext(handle->ctx);
            handle->ctx = nullptr;
            handle->lastFrameId = 0;
        }
    }
    if (mfgFirst)
        State::Instance().fgChanged = false;

    uint32_t depthInverted = 0, hdr = 0, jittered = 0;
    InParameters->Get("DLSSG.DepthInverted", &depthInverted);
    InParameters->Get("DLSSG.ColorBuffersHDR", &hdr);
    InParameters->Get("DLSSG.MvecJittered", &jittered);

    uint32_t mvBaseX = 0, mvBaseY = 0;
    InParameters->Get("DLSSG.MVecsSubrectBaseX", &mvBaseX);
    InParameters->Get("DLSSG.MVecsSubrectBaseY", &mvBaseY);
    float mvScaleX = 0.0f, mvScaleY = 0.0f;
    const bool dlssgPixelScale = InParameters->Get("DLSSG.MvecScaleX", &mvScaleX) == NVSDK_NGX_Result_Success &&
                                 InParameters->Get("DLSSG.MvecScaleY", &mvScaleY) == NVSDK_NGX_Result_Success;
    const bool pixelScaleKnown = dlssgPixelScale ||
        (InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_X, &mvScaleX) == NVSDK_NGX_Result_Success &&
         InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_Y, &mvScaleY) == NVSDK_NGX_Result_Success);
                                                                                  
                                                                                            
    const bool mvExtentValid = (displayResolutionMotionVectors || (mvWidth == renderW && mvHeight == renderH)) &&
        mvWidth == motionVectors->Resource.ImageViewInfo.Width && mvHeight == motionVectors->Resource.ImageViewInfo.Height;
    if (!pixelScaleKnown || !std::isfinite(mvScaleX) || !std::isfinite(mvScaleY) ||
        mvScaleX == 0.0f || mvScaleY == 0.0f || mvBaseX || mvBaseY || !mvExtentValid || jittered)
    {
        static uint32_t invalidMvCount = 0;
        if (invalidMvCount++ < 4)
            LOG_WARN("NFRU: rejecting unsupported MV contract: scaleKnown={} scale=({}, {}) origin=({}, {}) extentValid={} jittered={}",
                     pixelScaleKnown, mvScaleX, mvScaleY, mvBaseX, mvBaseY, mvExtentValid, jittered);
        return NVSDK_NGX_Result_FAIL_InvalidParameter;
    }
                                                                                        
    _putenv_s("NFRU_GAME_MV", fullMotionVectors ? "1" : "0");
    const int requestedGameOfMode = Config::Instance()->NfruOfMode.value_or_default();
    _putenv_s("NFRU_OF_MODE", std::to_string(fullMotionVectors ? 0 : requestedGameOfMode).c_str());
    _putenv_s("NFRU_OF_ADAPTIVE", Config::Instance()->NfruOfAdaptive.value_or_default() ? "1" : "0");
    _putenv_s("NFRU_OF_EXIT_CAMERA", Config::Instance()->NfruOfExitCamera.value_or_default() ? "1" : "0");
    _putenv_s("NFRU_DYN_REL", Config::Instance()->NfruDynamicRelative.value_or_default() ? "1" : "0"); _putenv_s("NFRU_ANGULAR", Config::Instance()->NfruAngular.value_or_default() ? "1" : "0"); _putenv_s("NFRU_OCCLUSION", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0"); _putenv_s("NFRU_T2", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0"); _putenv_s("NFRU_SPLAT_STRETCH", Config::Instance()->NfruSplatStretch.value_or_default() ? "1" : "0"); _putenv_s("NFRU_DEBUG_VIEW", std::to_string(std::clamp(Config::Instance()->NfruDebugView.value_or_default(), 0, 17)).c_str()); _putenv_s("NFRU_HOLE_CAMERA", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0");

    float cameraNear = 0.0f, cameraFar = 0.0f, cameraFov = 0.0f;
    const bool nearValid = InParameters->Get("DLSSG.CameraNear", &cameraNear) == NVSDK_NGX_Result_Success;
    const bool farValid = InParameters->Get("DLSSG.CameraFar", &cameraFar) == NVSDK_NGX_Result_Success;
    const bool fovValid = InParameters->Get("DLSSG.CameraFOV", &cameraFov) == NVSDK_NGX_Result_Success;

                                                                                                              
    if (!nearValid || !farValid || !fovValid)
    {
        uint32_t orthographic = 0;
        float (*viewToClip)[4] = nullptr;
        InParameters->Get("DLSSG.OrthoProjection", &orthographic);
        InParameters->Get("DLSSG.CameraViewToClip", reinterpret_cast<void**>(&viewToClip));
        if (!orthographic && viewToClip)
        {
            const double b = viewToClip[1][1], c = viewToClip[2][2], d = viewToClip[3][2], e = viewToClip[2][3];
            if (std::abs(b) > 1.0e-6 && std::abs(c) > 1.0e-6)
            {
                float derivedNear = 0.0f, derivedFar = 0.0f;
                if (e < 0.0)
                {
                    derivedNear = static_cast<float>(d / c);
                    if (std::abs(c + 1.0) > 1.0e-6)
                        derivedFar = static_cast<float>(d / (c + 1.0));
                }
                else
                {
                    derivedNear = static_cast<float>(-d / c);
                    if (std::abs(c - 1.0) > 1.0e-6)
                        derivedFar = static_cast<float>(-d / (c - 1.0));
                }
                if (depthInverted)
                    std::swap(derivedNear, derivedFar);
                if (!nearValid && std::isfinite(derivedNear) && derivedNear >= 0.0f)
                    cameraNear = derivedNear;
                if (!farValid && std::isfinite(derivedFar) && derivedFar >= 0.0f)
                    cameraFar = derivedFar;
                if (!fovValid)
                    cameraFov = static_cast<float>(2.0 * std::atan(1.0 / std::abs(b)));
            }
        }
    }
                                                                                                                
                                                                          
    {
        uint32_t projOrtho = 0;
        float (*proj)[4] = nullptr;
        InParameters->Get("DLSSG.OrthoProjection", &projOrtho);
        InParameters->Get("DLSSG.CameraViewToClip", reinterpret_cast<void**>(&proj));
        if (!projOrtho && proj && std::abs(proj[1][1]) > 1.0e-6f)
        {
            const float fromProj = static_cast<float>(2.0 * std::atan(1.0 / std::abs(proj[1][1])));
            static bool fovLogged = false;
            if (!fovLogged)
            {
                fovLogged = true;
                LOG_INFO("NFRU: camera FOV reported={} from projection={} rad (aspect from projection {})", cameraFov, fromProj,
                         std::abs(proj[1][1] / proj[0][0]));
            }
            cameraFov = fromProj;
        }
    }
    if (cameraFov == 0.0f)
        cameraFov = 90.0f;
    if (cameraFov > 10.0f)
        cameraFov *= std::numbers::pi_v<float> / 180.0f;
    const bool depthInfinite = cameraNear != 0.0f && cameraFar == 0.0f;
    if (depthInfinite)
        cameraFar = cameraNear + 1.0f;

    if (!handle->ctx)
    {
        ScopedSkipSpoofingGlobal skipSpoofingGlobal {};

        BackendVKDesc backend = {};
        backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_VK;
        backend.vkDevice = handle->vkDevice;
        backend.vkPhysicalDevice = handle->vkPhysicalDevice;
        backend.vkInstance = handle->vkInstance;
        backend.vkDeviceProcAddr = handle->vkDeviceProcAddr;
        backend.vkGetInstanceProcAddr = handle->vkInstanceProcAddr;

        CreateDescFG create = {};
        create.header.type = DESC_CREATE_FG;
        create.header.pNext = &backend.header;
        create.displaySize = { displayW, displayH };
        create.renderSize = { renderW, renderH };
        create.backBufferFormat = backFormat;
        create.flags = FG_MANAGE_PREVIOUS_DEPTH | FG_MANAGE_PREVIOUS_COLOR;
        if (hdr)
            create.flags |= FG_HDR;
        if (depthInverted)
            create.flags |= FG_DEPTH_INVERTED;
        if (depthInfinite)
            create.flags |= FG_DEPTH_INFINITE;
        if (jittered)
            create.flags |= FG_MV_JITTER_CANCELLATION;
        if (displayResolutionMotionVectors)
            create.flags |= FG_DISPLAY_RESOLUTION_MVS;
        for (int i = 0; i < 4; ++i)
            create.initialViewProjection[i * 5] = 1.0f;

                                                                                             
        {
            int sel = Config::Instance()->NfruBackend.value_or_default();
            if (!VkCoopMatInt8Supported())
            {
                sel = 2;                     
            }
            _putenv_s("NFRU_FORCE_BACKEND", sel == 2 ? "dp4a" : (sel == 1 ? "coopmat" : ""));

            const bool ofg = Nvngx_NFRU::OfgActive();
            const bool mlof2 = !ofg && Nvngx_NFRU::Mlof2Active();
            if (ofg) {
                _putenv_s("NFRU_ENGINE", "ofg");
                _putenv_s("OFG_ENABLE", "1");
                _putenv_s("OFG_HALF", Config::Instance()->OfgHalf.value_or_default() ? "1" : "0");
                _putenv_s("OFG_LK_ITERS", std::to_string(Config::Instance()->OfgLkIters.value_or_default()).c_str());
                char marginBuf[32];
                snprintf(marginBuf, sizeof(marginBuf), "%.4f", Config::Instance()->OfgRuleMargin.value_or_default());
                _putenv_s("OFG_RULE_MARGIN", marginBuf);
                _putenv_s("OFG_NO_L4", Config::Instance()->OfgNoL4.value_or_default() ? "1" : "0");
                _putenv_s("OFG_DEBUG_VIEW", std::to_string(Config::Instance()->OfgDebugView.value_or_default()).c_str());
                LOG_INFO("NFRU engine: OFG (half={}, lk={}, margin={:.3f}, noL4={}, debugView={})",
                         Config::Instance()->OfgHalf.value_or_default(),
                         Config::Instance()->OfgLkIters.value_or_default(),
                         Config::Instance()->OfgRuleMargin.value_or_default(),
                         Config::Instance()->OfgNoL4.value_or_default(),
                         Config::Instance()->OfgDebugView.value_or_default());
            } else {
                _putenv_s("OFG_ENABLE", "");
                                                                           
                _putenv_s("NFRU_ENGINE", mlof2 ? "mlof2" : "");
                _putenv_s("MLOF2_USE_COOPMAT", sel == 2 ? "0" : (sel == 1 ? "1" : ""));
                _putenv_s("MLOF2_BOTHFAIL", Config::Instance()->NfruBothFail.value_or_default() ? "1" : "0");
                                                                                                                      
                                                                            
                {
                    void* vtc = nullptr;
                    float px = 0.0f;
                    const bool pose = InParameters->Get("DLSSG.CameraViewToClip", &vtc) == NVSDK_NGX_Result_Success && vtc &&
                                      InParameters->Get("DLSSG.CameraPosX", &px) == NVSDK_NGX_Result_Success;
                    _putenv_s("MLOF2_TRAIL_HOMOG", pose ? "off" : "10");
                    LOG_INFO("NFRU trailing band homography: {} (camera pose {})", pose ? "off" : "auto 10 px",
                             pose ? "available" : "missing");
                }
                LOG_INFO("NFRU engine: {} (backend {})", mlof2 ? "MLOF2 neural flow" : "analytic flow",
                         sel == 2 ? "DP4a" : (sel == 1 ? "Cooperative Matrix" : "Auto"));
            }
        }
        const int requestedOfMode = Config::Instance()->NfruOfMode.value_or_default();
        const int effectiveOfMode = fullMotionVectors ? 0 : requestedOfMode;
        _putenv_s("NFRU_OF_MODE", std::to_string(effectiveOfMode).c_str());
        _putenv_s("NFRU_OF_RADIUS", std::to_string(Config::Instance()->NfruOfRadius.value_or_default()).c_str());
        _putenv_s("NFRU_OF_ADAPTIVE", Config::Instance()->NfruOfAdaptive.value_or_default() ? "1" : "0");
        _putenv_s("NFRU_OF_EXIT_CAMERA", Config::Instance()->NfruOfExitCamera.value_or_default() ? "1" : "0");
        _putenv_s("NFRU_DYN_REL", Config::Instance()->NfruDynamicRelative.value_or_default() ? "1" : "0"); _putenv_s("NFRU_ANGULAR", Config::Instance()->NfruAngular.value_or_default() ? "1" : "0"); _putenv_s("NFRU_OCCLUSION", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0"); _putenv_s("NFRU_T2", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0"); _putenv_s("NFRU_SPLAT_STRETCH", Config::Instance()->NfruSplatStretch.value_or_default() ? "1" : "0"); _putenv_s("NFRU_DEBUG_VIEW", std::to_string(std::clamp(Config::Instance()->NfruDebugView.value_or_default(), 0, 17)).c_str()); _putenv_s("NFRU_HOLE_CAMERA", Config::Instance()->NfruDisocclusion.value_or_default() ? "1" : "0");
        LOG_INFO("NFRU: MV coverage={} mvSubrect={}x{} mvImage={}x{} display={}x{} displayRes={} requested OF={} effective OF={}",
                 mvCoverage == 0 ? "auto" : (mvCoverage == 1 ? "full" : "incomplete"), mvWidth, mvHeight,
                 motionVectors->Resource.ImageViewInfo.Width, motionVectors->Resource.ImageViewInfo.Height, displayW,
                 displayH, displayResolutionMotionVectors, requestedOfMode, effectiveOfMode);

        auto createFn = FfxApiProxy::VULKAN_NSS_CreateContext();
        LOG_INFO("NFRU: creating FG context display={}x{} render={}x{}", displayW, displayH, renderW, renderH);
        ffxReturnCode_t rc = FFX_API_RETURN_ERROR;
        NFRU_SWAP_TRACE("create: begin");
        if (createFn && !NfruSafeCall(createFn, &rc, "create context", &handle->ctx, &create.header, nullptr))
            rc = FFX_API_RETURN_ERROR;
        LOG_INFO("NFRU: FG context create display={}x{} render={}x{} format={} flags={:X} -> {}", displayW, displayH,
                 renderW, renderH, backFormat, create.flags, (int) rc);
        if (rc != FFX_API_RETURN_OK)
        {
            handle->ctx = nullptr;
            CopyTextureVk(InCmdList, output, backbuffer);
            return NVSDK_NGX_Result_Fail;
        }
        handle->swapchainWidth = displayW;
        handle->swapchainHeight = displayH;
        handle->renderWidth = renderW;
        handle->renderHeight = renderH;
        handle->motionVectorWidth = mvWidth;
        handle->motionVectorHeight = mvHeight;
        handle->backbufferFormat = backFormat;
        handle->hdr = hdr != 0;
    }

                                                                              
    NFRU_SWAP_TRACE("pace: begin");
    handle->realFramePacer.Pace(Config::Instance()->NfruRealFrameLimit.value_or_default(), mfgFirst);
    NFRU_SWAP_TRACE("pace: end");

    if (mfgFirst) {
        g_realFrames.fetch_add(1);
        if (handle->mfgExpectedIndex != 1) handle->resetAfterAsyncFailure = true;
        ++handle->lastFrameId;
        handle->mfgCount = mfgCount;
        handle->mfgExpectedIndex = 1;
    }

    if (handle->asyncVk && !handle->asyncVk->BeforeRecord())
    {
        LOG_ERROR("NFRU Async: too many unsubmitted frames or GPU retirement failed; refusing SDK descriptor overwrite");
        handle->resetAfterAsyncFailure = true;
        CopyTextureVk(InCmdList, output, backbuffer);
        return NVSDK_NGX_Result_Fail;
    }
    std::shared_ptr<NfruAsyncVk::Frame> asyncFrame;
    if (mfgCount == 1 && Config::Instance()->NfruAsync.value_or_default() && NfruAsyncVk::hasQueues.load(std::memory_order_relaxed) &&
        Vulkan_wDx12::GetVirtualCommandBuffer(InCmdList) == VK_NULL_HANDLE &&
        Vulkan_wDx12::cmdBufferStateTracker.CanSplitForNfru(InCmdList))
    {
        auto family = Vulkan_wDx12::GetVerifiedQueueFamily(InCmdList);
        if (family)
        {
            if (!handle->asyncVk) handle->asyncVk = std::make_unique<NfruAsyncVk::Context>();
            asyncFrame = handle->asyncVk->Begin(handle->vkDevice, *family, InCmdList);
            if (asyncFrame)
            {
                vk_state::ReplayParams replay {};
                replay.ReplayComputeToo = true;
                replay.RequiredGraphicsSetMask = 0xFFFFFFFFu;
                if (!Vulkan_wDx12::cmdBufferStateTracker.CaptureAndReplay(InCmdList, asyncFrame->continuation, replay))
                { asyncFrame->retired = true; asyncFrame.reset(); }
            }
        }
    }
    if (Config::Instance()->NfruAsync.value_or_default() && !asyncFrame && !handle->asyncFallbackReported)
    {
        LOG_WARN("NFRU Async: synchronous fallback (MFG uses synchronous execution, or no safe same-family queue). Restart after enabling.");
        handle->asyncFallbackReported = true;
    }
    if (!asyncFrame && handle->asyncVk && !handle->asyncVk->Drain())
    {
        LOG_ERROR("NFRU Async: fallback cannot retire unsubmitted FG work; refusing mixed execution");
        handle->resetAfterAsyncFailure = true;
        CopyTextureVk(InCmdList, output, backbuffer);
        return NVSDK_NGX_Result_Fail;
    }
    const VkCommandBuffer fgCmd = asyncFrame ? asyncFrame->work : InCmdList;

    ConfigureDescFG configure = {};
    configure.header.type = DESC_CONFIGURE_FG;
    configure.frameGenerationEnabled = true;
    configure.allowAsyncWorkloads = bool(asyncFrame);
    configure.flags = FG_DISPATCH_NO_SWAPCHAIN_NOTIFY;
    if (Config::Instance()->FGDebugView.value_or_default())
        configure.flags |= FG_DISPATCH_DRAW_DEBUG_VIEW;
    configure.frameID = handle->lastFrameId;

    auto configureFn = FfxApiProxy::VULKAN_NSS_Configure();
    ffxReturnCode_t configureRc = FFX_API_RETURN_ERROR;
    NFRU_SWAP_TRACE("configure: begin");
    if (configureFn && !NfruSafeCall(configureFn, &configureRc, "configure", &handle->ctx, &configure.header))
        configureRc = FFX_API_RETURN_ERROR;
    if (!configureFn || configureRc != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NFRU: FG configure failed");
        CopyTextureVk(InCmdList, output, backbuffer);
        if (asyncFrame) asyncFrame->retired = true;
        return NVSDK_NGX_Result_Fail;
    }

    uint32_t reset = 0;
    InParameters->Get("DLSSG.Reset", &reset);
    if (handle->lastFrameId == 1 || handle->resetAfterAsyncFailure)
        reset = 1;

    PrepareDescFG prepare = {};
    prepare.header.type = DESC_DISPATCH_FG_PREPARE;
    prepare.commandList = fgCmd;
    prepare.frameID = handle->lastFrameId;
    InParameters->Get("DLSSG.JitterOffsetX", &prepare.jitterOffset.x);
    InParameters->Get("DLSSG.JitterOffsetY", &prepare.jitterOffset.y);

    prepare.motionVectorScale = {mvScaleX, mvScaleY};

    const auto now = std::chrono::steady_clock::now();
    auto& lastEval = handle->lastRealEval;
    float measuredFrameTime = 1000.0f / 60.0f;
    if (lastEval.time_since_epoch().count() != 0)
        measuredFrameTime = std::chrono::duration<float, std::milli>(now - lastEval).count();
    if (mfgFirst) lastEval = now;
    const bool frameTimeFromInput =
        InParameters->Get("FSR.frameTimeDelta", &prepare.frameTimeDelta) == NVSDK_NGX_Result_Success ||
        InParameters->Get(NVSDK_NGX_Parameter_FrameTimeDeltaInMsec, &prepare.frameTimeDelta) == NVSDK_NGX_Result_Success;
    if (!frameTimeFromInput || !std::isfinite(prepare.frameTimeDelta) || prepare.frameTimeDelta <= 0.0f)
        prepare.frameTimeDelta = std::clamp(measuredFrameTime, 1.0f, 100.0f);

    if (mfgFirst) handle->mfgFrameTimeDelta = prepare.frameTimeDelta;
    else prepare.frameTimeDelta = handle->mfgFrameTimeDelta;

    prepare.viewSpaceToMetersFactor = 1.0f;
    prepare.cameraNear = cameraNear;
    prepare.cameraFar = cameraFar;
    prepare.cameraFovAngleVertical = cameraFov;
    prepare.depth = GetResource(depth, STATE_COMPUTE_READ);
    prepare.motionVectors = GetResource(motionVectors, STATE_COMPUTE_READ);
    if (mfgFirst) {
        float (*projection)[4] = nullptr;
        float pos[3]{}, right[3]{}, up[3]{}, forward[3]{};
        const char* posKeys[]={"DLSSG.CameraPosX","DLSSG.CameraPosY","DLSSG.CameraPosZ"};
        const char* rightKeys[]={"DLSSG.CameraRightX","DLSSG.CameraRightY","DLSSG.CameraRightZ"};
        const char* upKeys[]={"DLSSG.CameraUpX","DLSSG.CameraUpY","DLSSG.CameraUpZ"};
        const char* forwardKeys[]={"DLSSG.CameraFwdX","DLSSG.CameraFwdY","DLSSG.CameraFwdZ"};
        bool available=InParameters->Get("DLSSG.CameraViewToClip", reinterpret_cast<void**>(&projection))==NVSDK_NGX_Result_Success && projection;
        for(int c=0;c<3;++c){
            available &= InParameters->Get(posKeys[c],&pos[c])==NVSDK_NGX_Result_Success;
            available &= InParameters->Get(rightKeys[c],&right[c])==NVSDK_NGX_Result_Success;
            available &= InParameters->Get(upKeys[c],&up[c])==NVSDK_NGX_Result_Success;
            available &= InParameters->Get(forwardKeys[c],&forward[c])==NVSDK_NGX_Result_Success;
        }
        const float* origin=handle->cameraOriginValid?handle->cameraOrigin:pos;
        float candidate[16]{};
        const bool valid=available && NfruBuildCameraViewProjection(&projection[0][0],pos,right,up,forward,origin,candidate);
        if (valid != handle->mfgCameraValid) { handle->resetAfterAsyncFailure=true; reset=1; }
        handle->mfgCameraValid=valid;
        std::fill(std::begin(handle->mfgViewProjection),std::end(handle->mfgViewProjection),0.0f);
        if(valid){
            if(!handle->cameraOriginValid){std::copy(pos,pos+3,handle->cameraOrigin);handle->cameraOriginValid=true;}
            std::copy(candidate,candidate+16,handle->mfgViewProjection);
        } else {
            for(int i=0;i<4;++i)handle->mfgViewProjection[i*5]=1.0f;
        }
        if(handle->lastFrameId<=4)
            LOG_INFO("NFRU camera VP: valid={} poseAvailable={} source=NVNGX camera pose + CameraViewToClip",valid,available);
    }
    std::copy(std::begin(handle->mfgViewProjection),std::end(handle->mfgViewProjection),prepare.viewProjection);

    if (handle->lastFrameId <= 4)
        LOG_INFO("NFRU Prepare frame={} render={}x{} mv={}x{} mvScale=({}, {}) jitter=({}, {}) dt={}ms camera=({}, {}, "
                 "{}) depthInv={} hdr={} jittered={} hudless={} hudSplit={}",
                 handle->lastFrameId, renderW, renderH, motionVectors->Resource.ImageViewInfo.Width,
                 motionVectors->Resource.ImageViewInfo.Height, prepare.motionVectorScale.x,
                 prepare.motionVectorScale.y, prepare.jitterOffset.x, prepare.jitterOffset.y, prepare.frameTimeDelta,
                 cameraNear, cameraFar, cameraFov, depthInverted, hdr, jittered, hudless != nullptr, splitHud);
    if (handle->lastFrameId <= 4)
        LOG_INFO("NFRU game MV->OF: enabled={} scaleSource={} pixelScale=({}, {}) normalizedScale=({}, {}) coverage={} cameraIncludedKnown={} cameraIncluded={}",
                 fullMotionVectors, dlssgPixelScale ? "DLSSG" : "NGX", mvScaleX, mvScaleY,
                 mvScaleX / float(displayResolutionMotionVectors ? displayW : renderW),
                 mvScaleY / float(displayResolutionMotionVectors ? displayH : renderH), mvCoverage, cameraMotionKnown, cameraMotionIncluded);

    auto dispatchFn = FfxApiProxy::VULKAN_NSS_Dispatch();
    if (!dispatchFn)
    {
        LOG_ERROR("NFRU: FG dispatch function is unavailable");
        if (asyncFrame) asyncFrame->retired = true;
        return NVSDK_NGX_Result_Fail;
    }

                                                                                              
    const bool profile = mfgCount == 1 && Config::Instance()->NssProfile.value_or_default();
    const uint32_t profSlot = (uint32_t) (handle->lastFrameId % 8);
    if (profile)
    {
        if (handle->profPool == VK_NULL_HANDLE)
        {
            VkQueryPoolCreateInfo qi = { VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO };
            qi.queryType = VK_QUERY_TYPE_TIMESTAMP;
            qi.queryCount = 16;
            if (vkCreateQueryPool(handle->vkDevice, &qi, nullptr, &handle->profPool) == VK_SUCCESS)
            {
                VkPhysicalDeviceProperties pp {};
                vkGetPhysicalDeviceProperties(handle->vkPhysicalDevice, &pp);
                handle->profPeriodMs = pp.limits.timestampPeriod * 1e-6f;
            }
        }
        if (handle->profPool != VK_NULL_HANDLE)
        {
            if (handle->lastFrameId > 4)
            {
                uint64_t t[2] = {};
                const uint32_t old = (uint32_t) ((handle->lastFrameId - 4) % 8);
                if (vkGetQueryPoolResults(handle->vkDevice, handle->profPool, old * 2, 2, sizeof(t), t, sizeof(uint64_t), VK_QUERY_RESULT_64_BIT) == VK_SUCCESS)
                {
                    const double ms = (double) (t[1] - t[0]) * handle->profPeriodMs;
                    handle->profSumMs += ms;
                    handle->profMaxMs = std::max(handle->profMaxMs, ms);
                    if (++handle->profCount >= 120)
                    {
                        LOG_INFO("NFRU GPU time over {} frames: avg {:.3f} ms, max {:.3f} ms", handle->profCount, handle->profSumMs / handle->profCount, handle->profMaxMs);
                        handle->profSumMs = 0.0;
                        handle->profMaxMs = 0.0;
                        handle->profCount = 0;
                    }
                }
            }
            vkCmdResetQueryPool(fgCmd, handle->profPool, profSlot * 2, 2);
            vkCmdWriteTimestamp(fgCmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, handle->profPool, profSlot * 2);
        }
    }

    const auto cpuT0 = std::chrono::steady_clock::now();
    ffxReturnCode_t prepareResult = FFX_API_RETURN_ERROR;
    NFRU_SWAP_TRACE("prepare: begin");
    if (!NfruSafeCall(dispatchFn, &prepareResult, "prepare", &handle->ctx, &prepare.header))
        prepareResult = FFX_API_RETURN_ERROR;
    if (prepareResult != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NFRU: FG prepare failed: {}", (int) prepareResult);
        CopyTextureVk(InCmdList, output, backbuffer);
        if (asyncFrame) asyncFrame->retired = true;
        return NVSDK_NGX_Result_Fail;
    }

    DispatchDescFG generate = {};
    generate.header.type = DESC_DISPATCH_FG;
    generate.commandList = fgCmd;
    generate.frameID = handle->lastFrameId;
    generate.presentColor = GetResource(sceneSource, STATE_COMPUTE_READ);
    generate.outputs[0] = outputRes;
    generate.numGeneratedFrames = 1;
    if (mfgFirst) handle->mfgReset = reset != 0;
    generate.reset = handle->mfgReset;
    MfgDesc mfgDesc {};
    if (mfgCount > 1) {
        mfgDesc.header.type = DESC_MFG;
        mfgDesc.index = mfgIndex;
        mfgDesc.count = mfgCount;
        generate.header.pNext = &mfgDesc.header;
    }

    HudDesc hudDesc {};
    if (splitHud) {
        hudDesc.header.type = DESC_HUD;
        hudDesc.header.pNext = generate.header.pNext;
        hudDesc.fullColor = GetResource(backbuffer, STATE_COMPUTE_READ);
        generate.header.pNext = &hudDesc.header;
    }

    ffxReturnCode_t generateResult = FFX_API_RETURN_ERROR;
    NFRU_SWAP_TRACE("generate: begin");
    if (!NfruSafeCall(dispatchFn, &generateResult, "generate", &handle->ctx, &generate.header))
        generateResult = FFX_API_RETURN_ERROR;
    if (profile)
    {
        const auto cpuT1 = std::chrono::steady_clock::now();
        const double cpuMs = std::chrono::duration<double, std::milli>(cpuT1 - cpuT0).count();
        if (handle->profLastEval.time_since_epoch().count() != 0)
            handle->profGapMaxMs = std::max(handle->profGapMaxMs, std::chrono::duration<double, std::milli>(cpuT0 - handle->profLastEval).count());
        handle->profLastEval = cpuT0;
        handle->profCpuSumMs += cpuMs;
        handle->profCpuMaxMs = std::max(handle->profCpuMaxMs, cpuMs);
        if (++handle->profCpuCount >= 120)
        {
            PROCESS_MEMORY_COUNTERS_EX pmc = {};
            GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*) &pmc, sizeof(pmc));
            LOG_INFO("NFRU CPU record time over {} frames: avg {:.3f} ms, max {:.3f} ms | max gap between FG evals {:.1f} ms | process private {:.0f} MB",
                     handle->profCpuCount, handle->profCpuSumMs / handle->profCpuCount, handle->profCpuMaxMs, handle->profGapMaxMs,
                     pmc.PrivateUsage / 1048576.0);
            handle->profCpuSumMs = handle->profCpuMaxMs = handle->profGapMaxMs = 0.0;
            handle->profCpuCount = 0;
        }
    }

                                                                                                                       
                                                                                      
    if (outputReal && outputReal->Type == NVSDK_NGX_RESOURCE_VK_TYPE_VK_IMAGEVIEW)
    {
        const auto* realSource = Config::Instance()->FGDebugView.value_or_default() ? output : backbuffer;
        if (!CopyTextureVk(fgCmd, outputReal, realSource))
            LOG_WARN("NFRU: failed to populate DLSSG.OutputReal on frame {}", handle->lastFrameId);
    }

    if (profile && handle->profPool != VK_NULL_HANDLE)
        vkCmdWriteTimestamp(fgCmd, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, handle->profPool, profSlot * 2 + 1);

    if (generateResult != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NFRU: FG generation failed: {}", (int) generateResult);
        CopyTextureVk(fgCmd, output, backbuffer);
    }
    if (asyncFrame)
    {
        if (!NfruAsyncVk::Publish(asyncFrame))
        {
            LOG_ERROR("NFRU Async: could not finish private command buffer");
            handle->resetAfterAsyncFailure = true;
            CopyTextureVk(InCmdList, output, backbuffer);
            return NVSDK_NGX_Result_Fail;
        }
                                                                            
                                                                              
        if (!Vulkan_wDx12::RegisterVirtualCommandBuffer(InCmdList, asyncFrame->continuation))
        {
            LOG_ERROR("NFRU Async: could not route the caller's command buffer into the continuation");
            handle->resetAfterAsyncFailure = true;
            return NVSDK_NGX_Result_Fail;
        }
    }
    handle->mfgExpectedIndex = generateResult == FFX_API_RETURN_OK && !mfgLast ? mfgIndex + 1 : 1;
    handle->resetAfterAsyncFailure = generateResult != FFX_API_RETURN_OK;
    return generateResult == FFX_API_RETURN_OK ? NVSDK_NGX_Result_Success : NVSDK_NGX_Result_Fail;
}

NVSDK_NGX_Result Nvngx_NFRU::VULKAN_PopulateParameters_Impl(NVSDK_NGX_Parameter* InParameters)
{
    if (!InParameters)
        return NVSDK_NGX_Result_FAIL_InvalidParameter;

    InParameters->Set("DLSSG.GetCurrentSettingsCallback", &GetCurrentSettingsCallback);
    InParameters->Set("DLSSG.EstimateVRAMCallback", &EstimateVRAMCallback);
    InParameters->Set("DLSSG.MultiFrameCountMax", getMaxFakeFramesCount());
    return NVSDK_NGX_Result_Success;
}
