#include <pch.h>
#include <Config.h>
#include <Util.h>
#include <State.h>
#include "MathUtils.h"

#include <cstdarg>
#include <cstdio>

                                                                          
static void NssDx12Log(const char* fmt, ...)
{
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    LOG_ERROR("{}", buf);
}
#define NSSDX_LOG(...) NssDx12Log(__VA_ARGS__)

#include "NSSFeature_Dx12.h"
#include "dx12/nss_dx12_host.h"

using namespace OptiMath;

namespace
{
                                                                                                                         
DXGI_FORMAT ColorSrvFormat(DXGI_FORMAT f)
{
    switch (f)
    {
    case DXGI_FORMAT_R32G32B32A32_TYPELESS:
        return DXGI_FORMAT_R32G32B32A32_FLOAT;
    case DXGI_FORMAT_R16G16B16A16_TYPELESS:
        return DXGI_FORMAT_R16G16B16A16_FLOAT;
    case DXGI_FORMAT_R10G10B10A2_TYPELESS:
        return DXGI_FORMAT_R10G10B10A2_UNORM;
    case DXGI_FORMAT_R8G8B8A8_TYPELESS:
        return DXGI_FORMAT_R8G8B8A8_UNORM;
    case DXGI_FORMAT_B8G8R8A8_TYPELESS:
        return DXGI_FORMAT_B8G8R8A8_UNORM;
    case DXGI_FORMAT_R11G11B10_FLOAT:
    default:
        return f;
    }
}

DXGI_FORMAT MotionSrvFormat(DXGI_FORMAT f)
{
    switch (f)
    {
    case DXGI_FORMAT_R16G16_TYPELESS:
        return DXGI_FORMAT_R16G16_FLOAT;
    case DXGI_FORMAT_R32G32_TYPELESS:
        return DXGI_FORMAT_R32G32_FLOAT;
    case DXGI_FORMAT_R16G16B16A16_TYPELESS:
        return DXGI_FORMAT_R16G16B16A16_FLOAT;
    case DXGI_FORMAT_R32G32B32A32_TYPELESS:
        return DXGI_FORMAT_R32G32B32A32_FLOAT;
    default:
        return f;
    }
}

                                                                                                                       
DXGI_FORMAT DepthSrvFormat(DXGI_FORMAT f)
{
    switch (f)
    {
    case DXGI_FORMAT_R32_TYPELESS:
    case DXGI_FORMAT_D32_FLOAT:
        return DXGI_FORMAT_R32_FLOAT;
    case DXGI_FORMAT_R16_TYPELESS:
    case DXGI_FORMAT_D16_UNORM:
        return DXGI_FORMAT_R16_UNORM;
    case DXGI_FORMAT_R24G8_TYPELESS:
    case DXGI_FORMAT_D24_UNORM_S8_UINT:
        return DXGI_FORMAT_R24_UNORM_X8_TYPELESS;
    case DXGI_FORMAT_R32G8X24_TYPELESS:
    case DXGI_FORMAT_D32_FLOAT_S8X24_UINT:
        return DXGI_FORMAT_R32_FLOAT_X8X24_TYPELESS;
    default:
        return f;
    }
}

                                                                                                                   
bool OutputUavFormat(ID3D12Device* device, DXGI_FORMAT f, DXGI_FORMAT* out)
{
    DXGI_FORMAT uav = ColorSrvFormat(f);

    D3D12_FEATURE_DATA_FORMAT_SUPPORT fs = { uav };
    if (FAILED(device->CheckFeatureSupport(D3D12_FEATURE_FORMAT_SUPPORT, &fs, sizeof(fs))) ||
        !(fs.Support2 & D3D12_FORMAT_SUPPORT2_UAV_TYPED_STORE))
        return false;

    *out = uav;
    return true;
}
}             

NSSFeatureDx12::NSSFeatureDx12(unsigned int InHandleId, NVSDK_NGX_Parameter* InParameters)
    : IFeature_Dx12(InHandleId, InParameters), IFeature(InHandleId, InParameters)
{
    _initParameters = SetInitParameters(InParameters);

                                                                                                                    
                                      
    _moduleLoaded = true;
    LOG_INFO("NSS (native D3D12, DP4a) selected");
}

NSSFeatureDx12::~NSSFeatureDx12()
{
    if (State::Instance().isShuttingDown)
    {
        _nss.release();                                                      
        return;
    }

    _nss.reset();
}

bool NSSFeatureDx12::InitInternal(ID3D12GraphicsCommandList* InCommandList, NVSDK_NGX_Parameter* InParameters)
{
    LOG_FUNC();

    if (IsInited())
        return true;

    if (Device == nullptr)
    {
        LOG_ERROR("D3D12Device is null!");
        return false;
    }

    unsigned int renderWidth = 0, renderHeight = 0;
    GetRenderResolution(InParameters, &renderWidth, &renderHeight);

    if (renderWidth == 0 || renderHeight == 0 || TargetWidth() == 0 || TargetHeight() == 0)
    {
        LOG_ERROR("Invalid resolution: render {}x{}, target {}x{}", renderWidth, renderHeight, TargetWidth(),
                  TargetHeight());
        return false;
    }

    nssdx::InitDesc desc;
    desc.device = Device;
    desc.renderW = renderWidth;
    desc.renderH = renderHeight;
    desc.dispW = TargetWidth();
    desc.dispH = TargetHeight();
    desc.depthInverted = DepthInverted();
    desc.depthInfinite = false;

    LOG_INFO("NSS D3D12 init: render={}x{}, upscale={}x{}, depthInverted={}", renderWidth, renderHeight,
             desc.dispW, desc.dispH, desc.depthInverted);

    auto nss = std::make_unique<nssdx::Nss>();
    if (!nss->Init(desc))
    {
        LOG_ERROR("NSS D3D12 init failed (needs Shader Model 6.6 and native 16-bit shader ops)");
        return false;
    }

    _nss = std::move(nss);
    _initRenderW = renderWidth;
    _initRenderH = renderHeight;
    _initDisplayW = desc.dispW;
    _initDisplayH = desc.dispH;

    LOG_INFO("NSSFeatureDx12 init finished! SetInit(true)");
    SetInit(true);
    return true;
}

bool NSSFeatureDx12::EvaluateInternal(ID3D12GraphicsCommandList* InCommandList, NVSDK_NGX_Parameter* InParameters)
{
    LOG_FUNC();

    if (!IsInited() || !_nss)
        return false;

    auto& cfg = *Config::Instance();

    unsigned int renderWidth = 0, renderHeight = 0;
    GetRenderResolution(InParameters, &renderWidth, &renderHeight);

                                                                                                                                      
                                                                                                                              
    bool recreatedForSize = false;
    if (renderWidth != _initRenderW || renderHeight != _initRenderH || TargetWidth() != _initDisplayW ||
        TargetHeight() != _initDisplayH)
    {
        LOG_INFO("NSS resolution {}x{} -> {}x{} (output {}x{} -> {}x{}): rebuilding", _initRenderW, _initRenderH, renderWidth,
                 renderHeight, _initDisplayW, _initDisplayH, TargetWidth(), TargetHeight());

        nssdx::InitDesc desc;
        desc.device = Device;
        desc.renderW = renderWidth;
        desc.renderH = renderHeight;
        desc.dispW = TargetWidth();
        desc.dispH = TargetHeight();
        desc.depthInverted = DepthInverted();
        desc.depthInfinite = false;

        auto fresh = std::make_unique<nssdx::Nss>();
        if (!fresh->Init(desc))
        {
            LOG_ERROR("NSS D3D12 rebuild failed");
            return false;
        }

        Util::DelayedDestroy(std::move(_nss));                                                            
        _nss = std::move(fresh);
        _initRenderW = renderWidth;
        _initRenderH = renderHeight;
        _initDisplayW = desc.dispW;
        _initDisplayH = desc.dispH;
        recreatedForSize = true;
    }

    ID3D12Resource* paramColor = nullptr;
    if (InParameters->Get(NVSDK_NGX_Parameter_Color, &paramColor) != NVSDK_NGX_Result_Success)
        InParameters->Get(NVSDK_NGX_Parameter_Color, (void**) &paramColor);

    ID3D12Resource* paramVelocity = nullptr;
    if (InParameters->Get(NVSDK_NGX_Parameter_MotionVectors, &paramVelocity) != NVSDK_NGX_Result_Success)
        InParameters->Get(NVSDK_NGX_Parameter_MotionVectors, (void**) &paramVelocity);

    ID3D12Resource* paramOutput = nullptr;
    if (InParameters->Get(NVSDK_NGX_Parameter_Output, &paramOutput) != NVSDK_NGX_Result_Success)
        InParameters->Get(NVSDK_NGX_Parameter_Output, (void**) &paramOutput);

    ID3D12Resource* paramDepth = nullptr;
    if (InParameters->Get(NVSDK_NGX_Parameter_Depth, &paramDepth) != NVSDK_NGX_Result_Success)
        InParameters->Get(NVSDK_NGX_Parameter_Depth, (void**) &paramDepth);

    _hasColor = paramColor != nullptr;
    _hasMV = paramVelocity != nullptr;
    _hasOutput = paramOutput != nullptr;
    _hasDepth = paramDepth != nullptr;

    if (!paramColor || !paramVelocity || !paramOutput || !paramDepth)
    {
        LOG_ERROR("Missing input: color={}, motion={}, output={}, depth={}", (void*) paramColor,
                  (void*) paramVelocity, (void*) paramOutput, (void*) paramDepth);
        return false;
    }

    DXGI_FORMAT outputFormat = DXGI_FORMAT_UNKNOWN;
    if (!OutputUavFormat(Device, paramOutput->GetDesc().Format, &outputFormat))
    {
        LOG_ERROR("Output format {} has no typed UAV store support, NSS can't write it",
                  (int) paramOutput->GetDesc().Format);
        return false;
    }

                                                                          
    if (cfg.ColorResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramColor, (D3D12_RESOURCE_STATES) cfg.ColorResourceBarrier.value(),
                        D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);

    if (cfg.MVResourceBarrier.has_value())
    {
        ResourceBarrier(InCommandList, paramVelocity, (D3D12_RESOURCE_STATES) cfg.MVResourceBarrier.value(),
                        D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
    }
    else if (State::Instance().NVNGX_Engine == NVSDK_NGX_ENGINE_TYPE_UNREAL ||
             State::Instance().gameEngine == GameEngineType::Unreal ||
             State::Instance().gameQuirks & GameQuirk::ForceUnrealEngine)
    {
        cfg.MVResourceBarrier.set_volatile_value(D3D12_RESOURCE_STATE_UNORDERED_ACCESS);
        ResourceBarrier(InCommandList, paramVelocity, D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                        D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
    }

    if (cfg.DepthResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramDepth, (D3D12_RESOURCE_STATES) cfg.DepthResourceBarrier.value(),
                        D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);

    if (cfg.OutputResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramOutput, (D3D12_RESOURCE_STATES) cfg.OutputResourceBarrier.value(),
                        D3D12_RESOURCE_STATE_UNORDERED_ACCESS);

    nssdx::Frame frame;
    frame.cl = InCommandList;
    frame.color = paramColor;
    frame.depth = paramDepth;
    frame.motion = paramVelocity;
    frame.output = paramOutput;
    frame.colorFmt = ColorSrvFormat(paramColor->GetDesc().Format);
    frame.depthFmt = DepthSrvFormat(paramDepth->GetDesc().Format);
    frame.motionFmt = MotionSrvFormat(paramVelocity->GetDesc().Format);
    frame.outputFmt = outputFormat;

                                                                                                        
    float jitterX = 0.0f, jitterY = 0.0f;
    InParameters->Get(NVSDK_NGX_Parameter_Jitter_Offset_X, &jitterX);
    InParameters->Get(NVSDK_NGX_Parameter_Jitter_Offset_Y, &jitterY);
    if (cfg.NssJitterFlipX.value_or_default())
        jitterX = -jitterX;
    if (cfg.NssJitterFlipY.value_or_default())
        jitterY = -jitterY;
    frame.jitterX = jitterX;
    frame.jitterY = jitterY;

    frame.mvScaleX = 1.0f;
    frame.mvScaleY = 1.0f;
    InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_X, &frame.mvScaleX);
    InParameters->Get(NVSDK_NGX_Parameter_MV_Scale_Y, &frame.mvScaleY);

                                                                  
    frame.camNear = cfg.FsrCameraNear.value_or_default();
    frame.camFar = cfg.FsrCameraFar.value_or_default();
    if (cfg.FsrVerticalFov.has_value())
        frame.fovY = GetRadiansFromDeg(cfg.FsrVerticalFov.value());
    else if (cfg.FsrHorizontalFov.value_or_default() > 0.0f)
        frame.fovY = GetVerticalFovFromHorizontal(GetRadiansFromDeg(cfg.FsrHorizontalFov.value()),
                                                  (float) TargetWidth(), (float) TargetHeight());
    else
        frame.fovY = GetRadiansFromDeg(60);

    frame.exposure = 1.0f;
    float preExposure = 1.0f;
    if (InParameters->Get(NVSDK_NGX_Parameter_DLSS_Pre_Exposure, &preExposure) == NVSDK_NGX_Result_Success &&
        preExposure > 0.0f)
        frame.exposure = preExposure;

    unsigned int reset = 0;
    InParameters->Get(NVSDK_NGX_Parameter_Reset, &reset);
    frame.reset = (reset == 1) || recreatedForSize;

    LOG_DEBUG("NSS DX12 dispatch: color fmt {} depth fmt {} mv fmt {} out fmt {}, jitter {}x{}, mvScale {}x{}",
              (int) frame.colorFmt, (int) frame.depthFmt, (int) frame.motionFmt, (int) frame.outputFmt, frame.jitterX,
              frame.jitterY, frame.mvScaleX, frame.mvScaleY);

    const bool ok = _nss->Record(frame);

                              
    if (cfg.ColorResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramColor, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                        (D3D12_RESOURCE_STATES) cfg.ColorResourceBarrier.value());

    if (cfg.MVResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramVelocity, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                        (D3D12_RESOURCE_STATES) cfg.MVResourceBarrier.value());

    if (cfg.DepthResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramDepth, D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                        (D3D12_RESOURCE_STATES) cfg.DepthResourceBarrier.value());

    if (cfg.OutputResourceBarrier.has_value())
        ResourceBarrier(InCommandList, paramOutput, D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
                        (D3D12_RESOURCE_STATES) cfg.OutputResourceBarrier.value());

    if (!ok)
    {
        LOG_ERROR("NSS D3D12 record failed");
        return false;
    }

    _frameCount++;
    return true;
}
