#include <pch.h>
#include <Config.h>
#include <Util.h>
#include <proxies/FfxApi_Proxy.h>
#include "NSSFeature_Vk.h"
#include "nvsdk_ngx_vk.h"
#include "MathUtils.h"
#include <misc/VkCoopMatSupport.h>
#include <fstream>
#include <chrono>

using namespace OptiMath;

                                                                                         

                                                                                                                       
                                                                                                                       
                     
namespace
{
struct NssSehInfo
{
    DWORD code = 0;
    void* address = nullptr;
    ULONG_PTR info0 = 0, info1 = 0;
};

int NssSehFilter(EXCEPTION_POINTERS* ep, NssSehInfo* out)
{
    out->code = ep->ExceptionRecord->ExceptionCode;
    out->address = ep->ExceptionRecord->ExceptionAddress;
    if (ep->ExceptionRecord->NumberParameters >= 2)
    {
        out->info0 = ep->ExceptionRecord->ExceptionInformation[0];
        out->info1 = ep->ExceptionRecord->ExceptionInformation[1];
    }
    return EXCEPTION_EXECUTE_HANDLER;
}

bool NssSafeDispatch(PfnFfxDispatch fn, ffxContext* ctx, const ffxDispatchDescHeader* header, ffxReturnCode_t* result,
                     NssSehInfo* info)
{
    __try
    {
        *result = fn(ctx, header);
        return true;
    }
    __except (NssSehFilter(GetExceptionInformation(), info))
    {
        return false;
    }
}
}             

static void NssLogCallback(uint32_t type, const wchar_t* message)
{
    if (message == nullptr)
        return;
    LOG_ERROR("NSS Runtime ({0}): {1}", type, std::string(reinterpret_cast<const char*>(message)));
}

                                                                                              
                                                                                         
                                                                                      
                                                                                           
                                                                                     
namespace NssAbi
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
enum State : uint32_t
{
    STATE_COMPUTE_UAV = 1 << 1,
    STATE_PIXEL_UAV = 1 << 2,
    STATE_UNORDERED_ACCESS = STATE_COMPUTE_UAV | STATE_PIXEL_UAV,
    STATE_COMPUTE_READ = 1 << 3,
};
}                    

struct NssApiResourceDescription
{
    uint32_t type;
    uint32_t format;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint32_t mipCount;
    uint32_t flags;
    uint32_t usage;
    uint32_t batchSize;
    uint32_t shapeSize;
};

struct NssApiResource
{
    void* resource;
    NssApiResourceDescription description;
    uint32_t state;
};

                                                                                  
struct NssApiDispatchDesc
{
    ffxDispatchDescHeader header;
    void* commandList;
    NssApiResource color;
    NssApiResource depth;
    NssApiResource motionVectors;
    NssApiResource output;
    NssApiResource outputTm1;
    FfxApiFloatCoords2D jitterOffset;
    FfxApiDimensions2D upscaleSize;
    FfxApiDimensions2D renderSize;
    float cameraNear;
    float cameraFar;
    float cameraFovAngleVertical;
    float exposure;
    FfxApiFloatCoords2D motionVectorScale;
    float frameTimeDelta;
    bool reset;
    uint32_t flags;
    NssApiResource debugViews;
    uint32_t debugViewMode;
};

static inline uint32_t nssApiGetSurfaceFormatVKLocal(VkFormat fmt)
{
    using namespace NssAbi;
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

static inline NssApiResource nssApiGetResourceVK(NVSDK_NGX_Resource_VK* vkResource, uint32_t state)
{
    using namespace NssAbi;
    NssApiResource out = {};

    if (vkResource->Resource.ImageViewInfo.Image == VK_NULL_HANDLE)
        return out;

    out.resource = (void*) vkResource->Resource.ImageViewInfo.Image;
    out.state = state;

    NssApiResourceDescription& d = out.description;
    d.usage = USAGE_READ_ONLY;

    if (vkResource->ReadWrite)
        d.usage |= USAGE_UAV;

                                                                                                                                              
                                                                                                               
    const VkFormat depthFmtCheck = vkResource->Resource.ImageViewInfo.Format;
    const bool formatIsDepth = depthFmtCheck == VK_FORMAT_D16_UNORM || depthFmtCheck == VK_FORMAT_X8_D24_UNORM_PACK32 ||
                               depthFmtCheck == VK_FORMAT_D32_SFLOAT || depthFmtCheck == VK_FORMAT_D16_UNORM_S8_UINT ||
                               depthFmtCheck == VK_FORMAT_D24_UNORM_S8_UINT || depthFmtCheck == VK_FORMAT_D32_SFLOAT_S8_UINT;
    if (formatIsDepth || (vkResource->Resource.ImageViewInfo.SubresourceRange.aspectMask & VK_IMAGE_ASPECT_DEPTH_BIT) > 0)
        d.usage |= USAGE_DEPTHTARGET;

                                                                                          
                                                                      
    const VkFormat fmt = vkResource->Resource.ImageViewInfo.Format;
    const bool formatHasStencil = fmt == VK_FORMAT_D32_SFLOAT_S8_UINT || fmt == VK_FORMAT_D24_UNORM_S8_UINT ||
                                  fmt == VK_FORMAT_D16_UNORM_S8_UINT;
    if (formatHasStencil ||
        (vkResource->Resource.ImageViewInfo.SubresourceRange.aspectMask & VK_IMAGE_ASPECT_STENCIL_BIT) > 0)
        d.usage |= USAGE_STENCILTARGET;

    d.type = FFX_API_RESOURCE_TYPE_TEXTURE2D;
    d.width = vkResource->Resource.ImageViewInfo.Width;
    d.height = vkResource->Resource.ImageViewInfo.Height;
    d.mipCount = 1;
    d.depth = 1;
    d.flags = 0;
    d.format = nssApiGetSurfaceFormatVKLocal(fmt);

    return out;
}

NSSFeatureVk::NSSFeatureVk(unsigned int InHandleId, NVSDK_NGX_Parameter* InParameters)
    : IFeature_Vk(InHandleId, InParameters), IFeature(InHandleId, InParameters)
{
    _initParameters = SetInitParameters(InParameters);

    _moduleLoaded = FfxApiProxy::InitFfxVkNss();

    if (_moduleLoaded)
        LOG_INFO("ngsdk_windows_x64.dll methods loaded!");
    else
        LOG_ERROR("Can't load ngsdk_windows_x64.dll methods!");
}

bool NSSFeatureVk::InitNSS(const NVSDK_NGX_Parameter* InParameters, uint32_t rw, uint32_t rh, uint32_t uw, uint32_t uh)
{
    LOG_DEBUG("NSSFeatureVk::InitNSS");

    if (!ModuleLoaded())
        return false;

    if (IsInited())
        return true;

    if (PhysicalDevice == nullptr || Device == nullptr || Instance == nullptr)
    {
        LOG_ERROR("Instance/PhysicalDevice/Device is null!");
        return false;
    }

    {
        ScopedSkipSpoofingGlobal skipSpoofingGlobal {};

                                                                                         
                                                                                     
                                                                               
                                                                                           
                                                                                          
                                                                                                 
                                                                                            
                                                                                       
                                                                                  
                                                                      
        NssCreateBackendVKDesc backendDesc = { 0 };
        backendDesc.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_VK;
        backendDesc.vkDevice = Device;
        backendDesc.vkPhysicalDevice = PhysicalDevice;
        backendDesc.vkInstance = Instance;

        if (GDPA == nullptr)
            backendDesc.vkDeviceProcAddr = vkGetDeviceProcAddr;
        else
            backendDesc.vkDeviceProcAddr = GDPA;

        backendDesc.vkGetInstanceProcAddr = vkGetInstanceProcAddr;

        _contextDesc = {};
        _contextDesc.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_NSS;
        _contextDesc.header.pNext = &backendDesc.header;
                                                                                                    
                                                                                                    
        _contextDesc.flags = FFX_API_NSS_CONTEXT_FLAG_QUANTIZED | FFX_API_NSS_CONTEXT_FLAG_MANAGE_HISTORY;

        if (IsHdr())
            _contextDesc.flags |= FFX_API_NSS_CONTEXT_FLAG_HIGH_DYNAMIC_RANGE;

        if (DepthInverted())
            _contextDesc.flags |= FFX_API_NSS_CONTEXT_FLAG_DEPTH_INVERTED;

        unsigned int renderWidth = 0, renderHeight = 0;
        GetRenderResolution(InParameters, &renderWidth, &renderHeight);
        if (rw != 0 && rh != 0)
        {
            renderWidth = rw;
            renderHeight = rh;
        }

        _contextDesc.maxRenderSize.width = renderWidth;
        _contextDesc.maxRenderSize.height = renderHeight;
        _contextDesc.maxUpscaleSize.width = uw != 0 ? uw : TargetWidth();
        _contextDesc.maxUpscaleSize.height = uh != 0 ? uh : TargetHeight();
        _contextDesc.fpMessage = NssLogCallback;
        _contextDesc.qualityMode = FFX_API_NSS_SHADER_QUALITY_MODE_QUALITY;

                                                                                                      
        {
            int sel = Config::Instance()->NssBackend.value_or_default();
                                                                           
            if (!VkCoopMatInt8Supported())
            {
                sel = 2;
            }
            _putenv_s("NSS_FORCE_BACKEND", sel == 1 ? "coopmat" : (sel == 2 ? "dp4a" : ""));
            if (Config::Instance()->NssProfile.value_or_default())
                _putenv_s("NSS_PROFILE", "1");
        }

        LOG_INFO("Calling FfxApi VULKAN_NSS_CreateContext: render={0}x{1}, upscale={2}x{3}", renderWidth,
                 renderHeight, _contextDesc.maxUpscaleSize.width, _contextDesc.maxUpscaleSize.height);

        auto ret = FfxApiProxy::VULKAN_NSS_CreateContext()(&_context, &_contextDesc.header, NULL);

        LOG_INFO("VULKAN_NSS_CreateContext returned: {0} (0x{1:X}), context={2}",
                 FfxApiProxy::ReturnCodeToString(ret), (uint32_t) ret, (void*) _context);

        if (ret != FFX_API_RETURN_OK)
        {
            LOG_ERROR("NSS_createContext error: {0}", FfxApiProxy::ReturnCodeToString(ret));
            return false;
        }
    }

    _ctxRenderW = _contextDesc.maxRenderSize.width;
    _ctxRenderH = _contextDesc.maxRenderSize.height;
    _ctxUpscaleW = _contextDesc.maxUpscaleSize.width;
    _ctxUpscaleH = _contextDesc.maxUpscaleSize.height;

    LOG_INFO("NSSFeatureVk init finished! SetInit(true)");
    SetInit(true);

    return true;
}

bool NSSFeatureVk::InitInternal(VkCommandBuffer InCmdList, NVSDK_NGX_Parameter* InParameters)
{
    LOG_FUNC();

    if (IsInited())
        return true;

    return InitNSS(InParameters);
}

bool NSSFeatureVk::EnsureDebugImage(VkFormat fmt, uint32_t w, uint32_t h)
{
    if (_dbgImage != VK_NULL_HANDLE && _dbgW == w && _dbgH == h)
        return true;

    VkImageCreateInfo ci = { VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO };
    ci.imageType = VK_IMAGE_TYPE_2D;
    ci.format = fmt;
    ci.extent = { w, h, 1 };
    ci.mipLevels = 1;
    ci.arrayLayers = 1;
    ci.samples = VK_SAMPLE_COUNT_1_BIT;
    ci.tiling = VK_IMAGE_TILING_OPTIMAL;
    ci.usage = VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_SAMPLED_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
               VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    ci.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    if (vkCreateImage(Device, &ci, nullptr, &_dbgImage) != VK_SUCCESS)
        return false;

    VkMemoryRequirements mr;
    vkGetImageMemoryRequirements(Device, _dbgImage, &mr);
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(PhysicalDevice, &mp);
    uint32_t idx = UINT32_MAX;
    for (uint32_t i = 0; i < mp.memoryTypeCount; ++i)
        if ((mr.memoryTypeBits & (1u << i)) &&
            (mp.memoryTypes[i].propertyFlags & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT))
        {
            idx = i;
            break;
        }
    if (idx == UINT32_MAX)
        return false;
    VkMemoryAllocateInfo ai = { VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO };
    ai.allocationSize = mr.size;
    ai.memoryTypeIndex = idx;
    if (vkAllocateMemory(Device, &ai, nullptr, &_dbgMem) != VK_SUCCESS)
        return false;
    vkBindImageMemory(Device, _dbgImage, _dbgMem, 0);
    _dbgW = w;
    _dbgH = h;
    return true;
}

bool NSSFeatureVk::EvaluateInternal(VkCommandBuffer InCmdBuffer, NVSDK_NGX_Parameter* InParameters)
{
    LOG_FUNC();

    if (!IsInited())
        return false;

    NssApiDispatchDesc params = {};
    params.header.type = FFX_API_DISPATCH_DESC_TYPE_NSS;
    params.commandList = InCmdBuffer;

    NVSDK_NGX_Resource_VK* paramColor = nullptr;
    InParameters->Get(NVSDK_NGX_Parameter_Color, (void**) &paramColor);
    if (!paramColor)
    {
        LOG_ERROR("Color not exist!!");
        return false;
    }
    params.color = nssApiGetResourceVK(paramColor, NssAbi::STATE_COMPUTE_READ);

    NVSDK_NGX_Resource_VK* paramDepth = nullptr;
    InParameters->Get(NVSDK_NGX_Parameter_Depth, (void**) &paramDepth);
    if (!paramDepth)
    {
        LOG_ERROR("Depth not exist!!");
        if (LowResMV())
            return false;
    }
    else
    {
        params.depth = nssApiGetResourceVK(paramDepth, NssAbi::STATE_COMPUTE_READ);
    }

    NVSDK_NGX_Resource_VK* paramVelocity = nullptr;
    InParameters->Get(NVSDK_NGX_Parameter_MotionVectors, (void**) &paramVelocity);
    if (!paramVelocity)
    {
        LOG_ERROR("MotionVectors not exist!!");
        return false;
    }
    params.motionVectors = nssApiGetResourceVK(paramVelocity, NssAbi::STATE_COMPUTE_READ);

    NVSDK_NGX_Resource_VK* paramOutput = nullptr;
    InParameters->Get(NVSDK_NGX_Parameter_Output, (void**) &paramOutput);
    if (!paramOutput)
    {
        LOG_ERROR("Output not exist!!");
        return false;
    }
    params.output = nssApiGetResourceVK(paramOutput, NssAbi::STATE_UNORDERED_ACCESS);

    params.motionVectorScale.x = 1.0f;
    params.motionVectorScale.y = 1.0f;
    InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_X, &params.motionVectorScale.x);
    InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_Y, &params.motionVectorScale.y);

    InParameters->Get(NVSDK_NGX_Parameter_Jitter_Offset_X, &params.jitterOffset.x);
    InParameters->Get(NVSDK_NGX_Parameter_Jitter_Offset_Y, &params.jitterOffset.y);
    if (Config::Instance()->NssJitterFlipX.value_or_default())
        params.jitterOffset.x = -params.jitterOffset.x;
    if (Config::Instance()->NssJitterFlipY.value_or_default())
        params.jitterOffset.y = -params.jitterOffset.y;

    GetRenderResolution(InParameters, &params.renderSize.width, &params.renderSize.height);
    params.upscaleSize.width = TargetWidth();
    params.upscaleSize.height = TargetHeight();

                                                                                                                                  
                                                                                                                                
    bool recreatedForSize = false;
    if (params.renderSize.width != _ctxRenderW || params.renderSize.height != _ctxRenderH ||
        params.upscaleSize.width != _ctxUpscaleW || params.upscaleSize.height != _ctxUpscaleH)
    {
        LOG_INFO("NSS context size {}x{} -> {}x{} (output {}x{} -> {}x{}): recreating the context", _ctxRenderW, _ctxRenderH,
                 params.renderSize.width, params.renderSize.height, _ctxUpscaleW, _ctxUpscaleH, params.upscaleSize.width,
                 params.upscaleSize.height);
        vkDeviceWaitIdle(Device);                                                      
        if (_context != nullptr)
            FfxApiProxy::VULKAN_NSS_DestroyContext()(&_context, NULL);
        _context = nullptr;
        SetInit(false);
        if (!InitNSS(InParameters, params.renderSize.width, params.renderSize.height, params.upscaleSize.width, params.upscaleSize.height))
            return false;
        recreatedForSize = true;
    }

    params.cameraNear = Config::Instance()->FsrCameraNear.value_or_default();
    params.cameraFar = Config::Instance()->FsrCameraFar.value_or_default();
    params.cameraFovAngleVertical = GetRadiansFromDeg(60);

    if (InParameters->Get(NVSDK_NGX_Parameter_FrameTimeDeltaInMsec, &params.frameTimeDelta) != NVSDK_NGX_Result_Success ||
        params.frameTimeDelta < 1.0f)
        params.frameTimeDelta = 16.6f;

                                                                                                      
    params.exposure = 1.0f;
    float preExposure = 1.0f;
    if (InParameters->Get(NVSDK_NGX_Parameter_DLSS_Pre_Exposure, &preExposure) == NVSDK_NGX_Result_Success &&
        preExposure > 0.0f)
        params.exposure = preExposure;
    if (const char* e = getenv("NSS_EXPOSURE"))
        params.exposure = (float) atof(e);

    unsigned int reset = 0;
    InParameters->Get(NVSDK_NGX_Parameter_Reset, &reset);
    params.reset = (reset == 1) || recreatedForSize;

    params.flags = FFX_API_NSS_DISPATCH_FLAG_ENABLE_DEBUG_CHECKING;

    {
        static int dbgCount = 0;
        if (dbgCount < 6 || (dbgCount % 600) == 0)
        {
            auto fmtOf = [](NVSDK_NGX_Resource_VK* r) { return r ? (int) r->Resource.ImageViewInfo.Format : -1; };
            auto wOf = [](NVSDK_NGX_Resource_VK* r) { return r ? (int) r->Resource.ImageViewInfo.Width : -1; };
            auto hOf = [](NVSDK_NGX_Resource_VK* r) { return r ? (int) r->Resource.ImageViewInfo.Height : -1; };
            LOG_ERROR("NSS in #{}: color fmt={} {}x{} | depth fmt={} {}x{} | mv fmt={} {}x{} | out fmt={} {}x{} rw={}",
                      dbgCount, fmtOf(paramColor), wOf(paramColor), hOf(paramColor), fmtOf(paramDepth),
                      wOf(paramDepth), hOf(paramDepth), fmtOf(paramVelocity), wOf(paramVelocity), hOf(paramVelocity),
                      fmtOf(paramOutput), wOf(paramOutput), hOf(paramOutput), paramOutput ? (int) paramOutput->ReadWrite : -1);
            LOG_ERROR("NSS in #{}: jitter=({:.4f},{:.4f}) mvScale=({:.4f},{:.4f}) render={}x{} up={}x{} near={} far={} fov={:.4f} "
                      "exposure={} dt={} reset={}",
                      dbgCount, params.jitterOffset.x, params.jitterOffset.y, params.motionVectorScale.x,
                      params.motionVectorScale.y, params.renderSize.width, params.renderSize.height,
                      params.upscaleSize.width, params.upscaleSize.height, params.cameraNear, params.cameraFar,
                      params.cameraFovAngleVertical, params.exposure, params.frameTimeDelta, (int) params.reset);
        }
        dbgCount++;
    }

                                                                                                                
    static std::string dbgModeStr;
    static int dbgFrame = 0;
    if ((dbgFrame++ % 120) == 0)
    {
        dbgModeStr.clear();
        if (const char* e = getenv("NSS_DEBUG_VIEW"))
            dbgModeStr = e;
        else if (Config::Instance()->MainDllPath.has_value())
        {
            std::ifstream f(Config::Instance()->MainDllPath.value() + L"/nss_debug_view.txt");
            std::getline(f, dbgModeStr);
        }
    }
    const char* dbgEnv = dbgModeStr.empty() ? nullptr : dbgModeStr.c_str();
    bool dbgActive = false;
    if (dbgEnv != nullptr && EnsureDebugImage(paramOutput->Resource.ImageViewInfo.Format, TargetWidth(), TargetHeight()))
    {
        VkImageMemoryBarrier b = { VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER };
        b.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
        b.newLayout = VK_IMAGE_LAYOUT_GENERAL;
        b.srcAccessMask = 0;
        b.dstAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
        b.srcQueueFamilyIndex = b.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        b.image = _dbgImage;
        b.subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
        vkCmdPipelineBarrier(InCmdBuffer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0,
                             nullptr, 0, nullptr, 1, &b);

        NssApiResource dbgRes = {};
        dbgRes.resource = (void*) _dbgImage;
        dbgRes.state = NssAbi::STATE_UNORDERED_ACCESS;
        dbgRes.description = params.output.description;
        dbgRes.description.usage = NssAbi::USAGE_UAV;
        params.debugViews = dbgRes;
        params.debugViewMode = (uint32_t) atoi(dbgEnv);
        params.flags |= 2;                                             
        dbgActive = true;
    }

    LOG_DEBUG("Dispatch!!");
    const auto dispatchStart = std::chrono::steady_clock::now();
    ffxReturnCode_t result = FFX_API_RETURN_ERROR;
    NssSehInfo sehInfo;
    const bool dispatched = NssSafeDispatch(FfxApiProxy::VULKAN_NSS_Dispatch(), &_context, &params.header, &result, &sehInfo);
    if (!dispatched)
    {
        HMODULE mod = nullptr;
        char modName[MAX_PATH] = "?";
        size_t offset = 0;
        if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR) sehInfo.address, &mod) && mod)
        {
            GetModuleFileNameA(mod, modName, MAX_PATH);
            offset = (size_t) sehInfo.address - (size_t) mod;
        }
        static uint32_t sehLogged = 0;
        if (sehLogged++ < 20)
            LOG_ERROR("NSS dispatch raised exception 0x{:X} at {} ({}+0x{:X}) access={} target=0x{:X}", sehInfo.code, sehInfo.address, modName,
                      offset, (uint64_t) sehInfo.info0, (uint64_t) sehInfo.info1);
        return false;
    }
    {
        static uint32_t dispatchCount = 0;
        const float dispatchMs = std::chrono::duration<float, std::milli>(std::chrono::steady_clock::now() - dispatchStart).count();
        if (Config::Instance()->NssProfile.value_or_default() && (dispatchCount < 30 || dispatchMs > 8.0f))
            LOG_INFO("NSS dispatch CPU time {:.3f} ms (call #{})", dispatchMs, dispatchCount);
        ++dispatchCount;
    }

    if (result != FFX_API_RETURN_OK)
    {
        LOG_ERROR("NSS dispatch error: {0}", FfxApiProxy::ReturnCodeToString(result));
        return false;
    }

    if (dbgActive)
    {
        VkImage outImg = paramOutput->Resource.ImageViewInfo.Image;
        VkImageMemoryBarrier bs[2] = {};
        for (auto& b : bs)
        {
            b.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
            b.srcQueueFamilyIndex = b.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
            b.subresourceRange = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1 };
        }
        bs[0].image = _dbgImage;
        bs[0].oldLayout = VK_IMAGE_LAYOUT_GENERAL;
        bs[0].newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        bs[0].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT;
        bs[0].dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        bs[1].image = outImg;
        bs[1].oldLayout = VK_IMAGE_LAYOUT_GENERAL;
        bs[1].newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        bs[1].srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT | VK_ACCESS_SHADER_READ_BIT;
        bs[1].dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        vkCmdPipelineBarrier(InCmdBuffer, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0,
                             nullptr, 0, nullptr, 2, bs);
        VkImageCopy cp = {};
        cp.srcSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 };
        cp.dstSubresource = { VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1 };
        cp.extent = { TargetWidth(), TargetHeight(), 1 };
        vkCmdCopyImage(InCmdBuffer, _dbgImage, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, outImg,
                       VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &cp);
        bs[1].oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
        bs[1].newLayout = VK_IMAGE_LAYOUT_GENERAL;
        bs[1].srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
        bs[1].dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
        vkCmdPipelineBarrier(InCmdBuffer, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 0,
                             nullptr, 0, nullptr, 1, &bs[1]);
    }

    return true;
}
