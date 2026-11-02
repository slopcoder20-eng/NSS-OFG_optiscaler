#pragma once
#include "SysUtils.h"
#include "State.h"

#include <optional>
#include <filesystem>

enum HasDefaultValue
{
    WithDefault,
    NoDefault,
    SoftDefault                                          
};

template <class T, HasDefaultValue defaultState = WithDefault> class CustomOptional : public std::optional<T>
{
  private:
    T _defaultValue;
    std::optional<T> _configIni;
    bool _volatile;

  public:
    CustomOptional(T defaultValue)
        requires(defaultState != NoDefault)
        : std::optional<T>(), _defaultValue(std::move(defaultValue)), _configIni(std::nullopt), _volatile(false)
    {
    }

    CustomOptional()
        requires(defaultState == NoDefault)
        : std::optional<T>(), _defaultValue(T {}), _configIni(std::nullopt), _volatile(false)
    {
    }

                                                
    constexpr void set_volatile_value(const T& value)
    {
        if (!_volatile)
        {                                               
            if (this->has_value())
                _configIni = this->value();
            else
                _configIni = std::nullopt;
        }
        _volatile = true;
        std::optional<T>::operator=(value);
    }

                                                   
    constexpr void set_from_config(const std::optional<T>& opt)
    {
        if (!this->has_value())
        {
            _configIni = opt;
            std::optional<T>::operator=(opt);
        }
    }

    constexpr CustomOptional& operator=(const T& value)
    {
        _volatile = false;
        std::optional<T>::operator=(value);
        return *this;
    }

    constexpr CustomOptional& operator=(T&& value)
    {
        _volatile = false;
        std::optional<T>::operator=(std::move(value));
        return *this;
    }

    constexpr CustomOptional& operator=(const std::optional<T>& opt)
    {
        _volatile = false;
        std::optional<T>::operator=(opt);
        return *this;
    }

    constexpr CustomOptional& operator=(std::optional<T>&& opt)
    {
        _volatile = false;
        std::optional<T>::operator=(std::move(opt));
        return *this;
    }

                                                 
    constexpr CustomOptional& operator=(const char* value)
        requires std::same_as<T, std::string>
    {
        _volatile = false;
        std::optional<T>::operator=(T(value));
        return *this;
    }

    constexpr T value_or_default() const&
        requires(defaultState != NoDefault)
    {
        return this->has_value() ? this->value() : _defaultValue;
    }

    constexpr T value_or_default() &&
        requires(defaultState != NoDefault)
    {
        return this->has_value() ? std::move(this->value()) : std::move(_defaultValue);
    }

    constexpr std::optional<T> value_for_config()
        requires(defaultState == WithDefault)
    {
        if (_volatile)
        {
            if (_configIni != _defaultValue)
                return _configIni;

            return std::nullopt;
        }

        if (!this->has_value() || *this == _defaultValue)
            return std::nullopt;

        return this->value();
    }

    constexpr std::optional<T> value_for_config()
        requires(defaultState != WithDefault)
    {
        if (_volatile)
            return _configIni;

        if (this->has_value())
            return this->value();

        return std::nullopt;
    }

    constexpr T value_for_config_or(T other)
    {
        auto option = value_for_config();

        if (option.has_value())
            return option.value();
        else
            return other;
    }
};

constexpr inline int UnboundKey = -1;
constexpr uint32_t NV_PRESET_LATEST = 0x00FFFFFF;

enum FpsOverlayPos : uint32_t
{
    FpsOverlayPos_TopLeft,
    FpsOverlayPos_TopRight,
    FpsOverlayPos_BottomLeft,
    FpsOverlayPos_BottomRight,
    FpsOverlayPos_TopCenter,
    FpsOverlayPos_BottomCenter,
    FpsOverlayPos_Custom,                    
    FpsOverlayPos_COUNT,
};

enum FpsOverlayShadow : uint32_t
{
    FpsOverlayShadow_Off,
    FpsOverlayShadow_Shadow,
    FpsOverlayShadow_Outline,
    FpsOverlayShadow_COUNT,
};

enum FpsOverlay : uint32_t
{
    FpsOverlay_JustFPS,
    FpsOverlay_Simple,
    FpsOverlay_Detailed,
    FpsOverlay_DetailedGraph,
    FpsOverlay_Full,
    FpsOverlay_FullGraph,
    FpsOverlay_LowLatencyTimings,
    FpsOverlay_Custom,                                       
    FpsOverlay_COUNT,
};

                                      
enum FpsOverlayFpsRow : uint32_t
{
    FpsOverlayFpsRow_JustFps,                     
    FpsOverlayFpsRow_FrameTime,                                                      
    FpsOverlayFpsRow_Average,                                                         
    FpsOverlayFpsRow_COUNT,
};

                            
enum class Scaler : uint32_t
{
    FSR1 = 0,
    Bicubic = 1,
    CatmullRom = 2,
    Lanczos2 = 3,
    Lanczos3 = 4,
    Kaiser2 = 5,
    Kaiser3 = 6,
    Magic = 7,
    Count
};

enum class ForceReflex : uint32_t
{
    InGame,
    ForceDisable,
    ForceEnable,
    Count
};

enum class LFXMode : uint32_t
{
    Conservative,
    Aggressive,
    ReflexIDs,
    Count
};

enum class LowLatencyInput : uint32_t
{
    None,
    Auto,
    AntiLag2,
    Reflex,
    XeLL,
    UeLowLatency,
    OptiScaler,                                                                                          
    _
};

enum class LowLatencyMode : uint32_t
{
    None,
    Auto,
    LatencyFlex,
    AntiLag2,
    XeLL,
    AntiLagVk,
    Reflex,
    FpsLimiter,
    _
};

enum class ReprojectionFill : uint32_t
{
    StrechEdge,
    Dithering,
    Noise,
    Debug,
    SoftEdge,
};

template <> struct EnumConfig<ReprojectionFill>
{
    static constexpr auto default_value = ReprojectionFill::Dithering;

    static constexpr std::pair<ReprojectionFill, std::string_view> mapping[] = {
        { ReprojectionFill::StrechEdge, "strech" },
        { ReprojectionFill::Dithering, "dithering" },
        { ReprojectionFill::Noise, "noise" },
        { ReprojectionFill::Debug, "debug" },
        { ReprojectionFill::SoftEdge, "soft" }
    };
};

class Config
{
  public:
    Config();

                 
    CustomOptional<bool, NoDefault> DepthInverted;
    CustomOptional<bool, NoDefault> AutoExposure;
    CustomOptional<bool, NoDefault> HDR;
    CustomOptional<bool, NoDefault> JitterCancellation;
    CustomOptional<bool, NoDefault> DisplayResolution;
    CustomOptional<bool, NoDefault> DynamicResolution;
    CustomOptional<bool, NoDefault> DisableReactiveMask;
    CustomOptional<float> DlssReactiveMaskBias { 0.45f };

              
    CustomOptional<bool> LogToFile { false };
    CustomOptional<bool> LogToConsole { false };
    CustomOptional<bool> LogToDebug { false };
    CustomOptional<bool> LogToNGX { false };
    CustomOptional<bool> OpenConsole { false };
    CustomOptional<bool> DebugWait { false };              
    CustomOptional<int> LogLevel { 0 };
    CustomOptional<std::wstring> LogFileName { L"OptiScaler.log" };
    CustomOptional<bool> LogSingleFile { true };
    CustomOptional<bool> LogAsync { false };
    CustomOptional<int> LogAsyncThreads { 4 };

           
    CustomOptional<bool> BuildPipelines { true };
    CustomOptional<int32_t> NetworkModel { 0 };

                                                                                                                          
    CustomOptional<int32_t> NssBackend { 0 };
                                                                                                      
    CustomOptional<bool> NssProfile { false };
                                                                                                                  
                                                                                         
                                                                       
    CustomOptional<int32_t> NfruBackend { 0 };
                                                                                                       
                                                                                                                
    CustomOptional<int32_t> NfruEngine { 1 };
                                                                                                                 
                                                                                                                    
                                            
    CustomOptional<bool> NfruBothFail { false };
                                                                             
    CustomOptional<bool> NfruAsync { false };
    CustomOptional<int32_t> NfruMultiplier { 2 };
    CustomOptional<float> NfruRealFrameLimit { 0.0f };
    CustomOptional<bool> NfruSeparateHud { true };
                                                                                                   
    CustomOptional<bool> NfruOriginalOf { false };
    CustomOptional<int32_t> NfruMvCoverage { 0 };
    CustomOptional<int32_t> NfruOfMode { 1 };
    CustomOptional<int32_t> NfruOfRadius { 2 };
    CustomOptional<bool> NfruOfExitCamera { false };                                                                         
    CustomOptional<bool> NfruDynamicRelative { false };                                                                      
    CustomOptional<int> NfruDebugView { 0 };                                                            
    CustomOptional<bool> NfruSplatStretch { true };                                                                            
    CustomOptional<bool> NfruAngular { true };                                                           
    CustomOptional<bool> NfruDisocclusion { true };                                                                                   
    CustomOptional<bool> NfruOfAdaptive { false };                                                                          
    CustomOptional<bool> NssJitterFlipX { true };
    CustomOptional<bool> NssJitterFlipY { true };
    CustomOptional<bool> CreateHeaps { true };

                                    
    CustomOptional<bool> OfgEnabled { false };
    CustomOptional<bool> OfgHalf { true };
    CustomOptional<int32_t> OfgLkIters { 2 };
    CustomOptional<float> OfgRuleMargin { 0.02f };
    CustomOptional<bool> OfgNoL4 { false };
    CustomOptional<int32_t> OfgDebugView { 0 };

           
    CustomOptional<bool> DLSSEnabled { true };
    CustomOptional<bool> RenderPresetOverride { false };
    CustomOptional<uint32_t> RenderPresetForAll { 0 };
    CustomOptional<uint32_t> RenderPresetDLAA { 0 };
    CustomOptional<uint32_t> RenderPresetUltraQuality { 0 };
    CustomOptional<uint32_t> RenderPresetQuality { 0 };
    CustomOptional<uint32_t> RenderPresetBalanced { 0 };
    CustomOptional<uint32_t> RenderPresetPerformance { 0 };
    CustomOptional<uint32_t> RenderPresetUltraPerformance { 0 };

            
    CustomOptional<bool> DLSSDRenderPresetOverride { false };
    CustomOptional<uint32_t> DLSSDRenderPresetForAll { 0 };
    CustomOptional<uint32_t> DLSSDRenderPresetDLAA { 0 };
    CustomOptional<uint32_t> DLSSDRenderPresetUltraQuality { 0 };
    CustomOptional<uint32_t> DLSSDRenderPresetQuality { 0 };
    CustomOptional<uint32_t> DLSSDRenderPresetBalanced { 0 };
    CustomOptional<uint32_t> DLSSDRenderPresetPerformance { 0 };
    CustomOptional<uint32_t> DLSSDRenderPresetUltraPerformance { 0 };

             
    CustomOptional<bool> NvngxFGMakeDepthCopy { false };

                
    CustomOptional<std::wstring, NoDefault> MainDllPath;
    CustomOptional<std::wstring, NoDefault> FfxDx12Path;
    CustomOptional<std::wstring, NoDefault> FfxDx12SRPath;
    CustomOptional<std::wstring, NoDefault> FfxDx12FGPath;
    CustomOptional<std::wstring, NoDefault> FfxDx12RRPath;
    CustomOptional<std::wstring, NoDefault> FfxDx12RCPath;
    CustomOptional<std::wstring, NoDefault> FfxVkPath;
    CustomOptional<std::wstring, NoDefault> FfxVkSRPath;
    CustomOptional<std::wstring, NoDefault> FfxVkFGPath;
    CustomOptional<std::wstring, NoDefault> XeSSLibrary;
    CustomOptional<std::wstring, NoDefault> XeFGLibrary;
    CustomOptional<std::wstring, NoDefault> XeLLLibrary;
    CustomOptional<std::wstring, NoDefault> XeSSDx11Library;
    CustomOptional<std::wstring, NoDefault> NvngxPath;
    CustomOptional<std::wstring, NoDefault> NVNGX_DLSS_Library;
    CustomOptional<std::wstring, NoDefault> DLSSFeaturePath;
    CustomOptional<std::wstring, NoDefault> NvapiDllPath;

                
    CustomOptional<SharpenShader> SharpnessShader { SharpenShader::RCAS };
    CustomOptional<bool> OverrideSharpness { false };
    CustomOptional<float> Sharpness { 0.4f };

           
    CustomOptional<bool> RcasEnabled { false };
    CustomOptional<bool> ContrastEnabled { false };
    CustomOptional<float> Contrast { -0.3f };

                    
    CustomOptional<float, NoDefault> DADepthScale;
    CustomOptional<float, NoDefault> DADepthBias;
    CustomOptional<bool, NoDefault> DAClampOutput;

          
    CustomOptional<bool> MotionSharpnessEnabled { false };
    CustomOptional<bool> MotionSharpnessDebug { false };
    CustomOptional<float> MotionSharpness { 0.2f };
    CustomOptional<float> MotionThreshold { 0.0f };
    CustomOptional<float> MotionScaleLimit { 10.0f };

                
    CustomOptional<bool> MagnifierEnabled { false };
    CustomOptional<float> MagnifierSize { 15.f };                      
    CustomOptional<int> MagnifierZoomFactor { 4 };
    CustomOptional<float> MagnifierBorderSize { 0.3f };                        
    CustomOptional<float> MagnifierCursorOffsetX { 0.f };          
    CustomOptional<float> MagnifierCursorOffsetY { 0.f };          
    CustomOptional<float, NoDefault> MagnifierStaticPosX;                                                             
    CustomOptional<float, NoDefault> MagnifierStaticPosY;                      

           
    CustomOptional<float, NoDefault> MenuScale;
    CustomOptional<float, NoDefault> MenuHeight;                                           
    CustomOptional<bool, SoftDefault> OverlayMenu { true };
    CustomOptional<int> ShortcutKey { VK_INSERT };
    CustomOptional<bool> ExtendedLimits { false };
    CustomOptional<bool> ShowFps { false };
                                                              
    CustomOptional<FpsOverlayPos> FpsOverlayPosition { FpsOverlayPos_TopLeft };
                                                             
                                                                     
                                             
    CustomOptional<FpsOverlay> FpsOverlayType { FpsOverlay_FullGraph };
    CustomOptional<int> FpsShortcutKey { VK_PRIOR };
    CustomOptional<int> FpsCycleShortcutKey { VK_NEXT };
    CustomOptional<bool> FpsOverlayHorizontal { false };
    CustomOptional<bool> FpsOverlayShowRatio { false };
    CustomOptional<bool> FpsOverlayCompactLabels { false };
    CustomOptional<bool> FpsOverlayHideAverages { false };
                                                                                                      
                                                     
    CustomOptional<std::string, NoDefault> FpsOverlayRows;
    CustomOptional<FpsOverlayFpsRow> FpsOverlayFpsRowType { FpsOverlayFpsRow_Average };                      
    CustomOptional<float, NoDefault> FpsOverlayRowSpacing;                                      
                                                                                           
    CustomOptional<float> FpsOverlayUpdateInterval { 0.0f };
    CustomOptional<float> FpsOverlayAlpha { 0.45f };
    CustomOptional<float, NoDefault> FpsScale;                                    
    CustomOptional<float> FpsOverlayGraphHeight { 1.0f };
                                                                          
    CustomOptional<float> FpsOverlayPosX { 0.0f };
    CustomOptional<float> FpsOverlayPosY { 0.0f };
                                                                                         
    CustomOptional<std::string, NoDefault> FpsOverlayFont;
    CustomOptional<float, NoDefault> FpsOverlayFontSize;                                     
    CustomOptional<float> FpsOverlayLetterSpacing { 0.0f };
                                                           
    CustomOptional<float> FpsOverlayLabelScale { 1.0f };
    CustomOptional<float> FpsOverlayValueScale { 1.0f };
                                                                  
    CustomOptional<uint32_t> FpsOverlayLabelColor { 0xEAEAEA };
    CustomOptional<uint32_t> FpsOverlayValueColor { 0xFFFFFF };
    CustomOptional<uint32_t> FpsOverlayGraphColor { 0x00FF00 };
    CustomOptional<uint32_t> FpsOverlayBGColor { 0x000000 };
    CustomOptional<FpsOverlayShadow> FpsOverlayShadowType { FpsOverlayShadow_Shadow };
    CustomOptional<float> FpsOverlayShadowStrength { 0.4f };
    CustomOptional<uint32_t> FpsOverlayShadowColor { 0x000000 };
    CustomOptional<float> FpsOverlayRounding { 2.0f };
    CustomOptional<float> MenuRounding { 2.0f };
    CustomOptional<bool> UseHQFont { true };
    CustomOptional<bool> DisableSplash { false };
    CustomOptional<float> FontSize { 14.0f };
    CustomOptional<std::wstring, NoDefault> TTFFontPath;
    CustomOptional<int> FGShortcutKey { VK_END };
    CustomOptional<bool> LightTheme { false };
    CustomOptional<bool> OverlaysUseTheme { false };
    CustomOptional<float> MenuAccentColorR { 0.00f };
    CustomOptional<float> MenuAccentColorG { 0.40f };
    CustomOptional<float> MenuAccentColorB { 0.77f };
    CustomOptional<float> MenuBGColorR { 0.0f };
    CustomOptional<float> MenuBGColorG { 0.0f };
    CustomOptional<float> MenuBGColorB { 0.0f };
    CustomOptional<float> MenuBGColorA { 0.93f };
    CustomOptional<bool> MenuBlur { true };
    CustomOptional<float> MenuBlurStrength { 1.0f };
    CustomOptional<bool> CustomTabEnabled { true };
    CustomOptional<std::string> CustomTabCards { "upscaler,sharpness,fg_selection,fg_fsrfg,fg_xefg,fg_dlssg,fg_"
                                                 "reprojection,fg_optifg,fg_nvngx,fg_fsrfg_inputs,fg_sl_"
                                                 "inputs,framerate" };                                    

            
    CustomOptional<bool> HookOriginalNvngxOnly { false };
    CustomOptional<bool> EarlyHooking { false };
    CustomOptional<bool, SoftDefault> UseNtdllHooks { true };

                             
    CustomOptional<bool> UpscaleRatioOverrideEnabled { false };
    CustomOptional<float> UpscaleRatioOverrideValue { 1.3f };

          
    CustomOptional<bool> DrsMinOverrideEnabled { false };
    CustomOptional<bool> DrsMaxOverrideEnabled { false };

                        
    CustomOptional<bool> QualityRatioOverrideEnabled { false };
    CustomOptional<float> QualityRatio_DLAA { 1.0f };
    CustomOptional<float> QualityRatio_UltraQuality { 1.3f };
    CustomOptional<float> QualityRatio_Quality { 1.5f };
    CustomOptional<float> QualityRatio_Balanced { 1.7f };
    CustomOptional<float> QualityRatio_Performance { 2.0f };
    CustomOptional<float> QualityRatio_UltraPerformance { 3.0f };

                    
    CustomOptional<std::wstring, NoDefault> TargetProcess;
    CustomOptional<std::wstring> ProcessExclusionList = {
        L"crashpad_handler.exe|crashreport.exe|crashreporter.exe|crs-handler.exe|crs-uploader.exe|crs-video.exe|"
        L"unitycrashhandler64.exe|idtechlauncher.exe|cefviewwing.exe|ace-setup64.exe|ace-service64.exe|"
        L"qtwebengineprocess.exe|platformprocess.exe|bugsplathd64.exe|bssndrpt64.exe|pspcsdkappmgr.exe|pspcsdkcore.exe|"
        L"pspcsdkstttts.exe|pspcsdktelemetry.exe|pspcsdkui.exe|pspcsdkupdatechecker.exe|pspcsdkvoicechat.exe|"
        L"pspcsdkwebview.exe|windhawk.exe|vscodium.exe|crash_reporter.exe|steamerrorreporter64.exe|crashreportclient."
        L"exe|edcefcrashpadprocess.exe|edcefrenderprocess.exe|unicrashreporter.exe"
    };

               
    CustomOptional<bool> CheckForUpdate { true };
    CustomOptional<bool, SoftDefault> DisableOverlays { false };

    CustomOptional<bool> SimulateWaitableObject { false };

    CustomOptional<float, NoDefault> MipmapBiasOverride;                       
    CustomOptional<bool> MipmapBiasFixedOverride { false };
    CustomOptional<bool> MipmapBiasScaleOverride { false };
    CustomOptional<bool> MipmapBiasOverrideAll { false };

    CustomOptional<int, NoDefault> AnisotropyOverride;                       
    CustomOptional<bool> OverrideShaderSampler { true };
    CustomOptional<bool> AnisotropyModifyComp { true };
    CustomOptional<bool> AnisotropyModifyMinMax { true };
    CustomOptional<bool> AnisotropySkipPointFilter { true };

    CustomOptional<int, NoDefault> RoundInternalResolution;                       

    CustomOptional<int, NoDefault> SkipFirstFrames;                       
    CustomOptional<bool, SoftDefault> RestoreComputeSignature { false };
    CustomOptional<bool, SoftDefault> RestoreGraphicSignature { false };
    CustomOptional<bool, SoftDefault> ExtendedStateRestore { false };

    CustomOptional<bool> UsePrecompiledShaders { true };

    CustomOptional<bool> UseGenericAppIdWithDlss { false };
    CustomOptional<bool> PreferDedicatedGpu { true };
    CustomOptional<bool> PreferFirstDedicatedGpu { false };

    CustomOptional<int32_t, NoDefault> ColorResourceBarrier;                          
    CustomOptional<int32_t, NoDefault> MVResourceBarrier;                             
    CustomOptional<int32_t, NoDefault> DepthResourceBarrier;                          
    CustomOptional<int32_t, NoDefault> ExposureResourceBarrier;                       
    CustomOptional<int32_t, NoDefault> MaskResourceBarrier;                           
    CustomOptional<int32_t, NoDefault> OutputResourceBarrier;                         

    CustomOptional<bool, SoftDefault> CreateD3D12DeviceForLuma { false };

                
    CustomOptional<Upscaler, SoftDefault> Dx11Upscaler { Upscaler::FSR22 };
    CustomOptional<Upscaler, SoftDefault> Dx12Upscaler { Upscaler::XeSS };
    CustomOptional<Upscaler, SoftDefault> VulkanUpscaler { Upscaler::FSR22 };

                     
    CustomOptional<bool> OutputScalingEnabled { false };
    CustomOptional<float> OutputScalingMultiplier { 1.5f };
    CustomOptional<Scaler> OutputScalingDownscaler { Scaler::FSR1 };

          
    CustomOptional<bool> FsrDebugView { false };
    CustomOptional<int> FfxUpscalerIndex { 0 };
                                                                                                         
    CustomOptional<std::string, NoDefault> CustomUpscaler;
                                                                                                          
    CustomOptional<std::string, NoDefault> CustomUpscalerVk;

                                                                                        
    CustomOptional<int>& FfxUpscalerIndexFor(const std::string& custom)
    {
        if (custom.empty())
            return FfxUpscalerIndex;

                                                                         
        std::scoped_lock lock(_customIndexMutex);
        return _ffxCustomUpscalerIndex.try_emplace(custom, 0).first->second;
    }
    CustomOptional<int> FfxFGIndex { 0 };
    CustomOptional<bool> FsrUseMaskForTransparency { true };
    CustomOptional<bool> FsrNonLinearColorSpace { false };
    CustomOptional<bool> FsrNonLinearSRGB { false };
    CustomOptional<bool> FsrNonLinearPQ { false };
    CustomOptional<bool> FsrAgilitySDKUpgrade { false };

                                                                                           
    CustomOptional<float> FsrVelocity { 1.0f };
    CustomOptional<float> FsrReactiveScale { 1.0f };
    CustomOptional<float> FsrShadingScale { 1.0f };
    CustomOptional<float> FsrAccAddPerFrame { 0.333f };
    CustomOptional<float> FsrMinDisOccAcc { -0.333f };

           
                                                       
    CustomOptional<FSR4Support> Fsr4GpuSupport { FSR4Support::None };
    CustomOptional<uint32_t, NoDefault> Fsr4Preset;
    CustomOptional<FSR4Model, NoDefault> Fsr4Model;
    CustomOptional<bool> Fsr4EnableWatermark { false };
    CustomOptional<bool, SoftDefault> Fsr4DoNotLoadAmdxc64 { false };

                 
    CustomOptional<float> FsrVerticalFov { 60.0f };
    CustomOptional<float> FsrHorizontalFov { 0.0f };                  
    CustomOptional<float> FsrCameraNear { 0.1f };
    CustomOptional<float> FsrCameraFar { 100000.0f };
    CustomOptional<bool, SoftDefault> FsrUseFsrInputValues { true };

                
    CustomOptional<bool> Dx11DelayedInit { false };
    CustomOptional<bool, SoftDefault> DontUseNTShared { true };

                  
    CustomOptional<bool> VulkanUseCopyForInputs { false };
    CustomOptional<bool> VulkanUseCopyForOutput { false };

                     
    CustomOptional<bool> DisableFlipMetering { false };
    CustomOptional<bool> DisableOTA { false };

               
    CustomOptional<bool, SoftDefault> DxgiSpoofing { true };
    CustomOptional<bool> DxgiFactoryWrapping { false };
    CustomOptional<bool, SoftDefault> StreamlineSpoofing { true };
    CustomOptional<std::string, NoDefault> DxgiBlacklist;                       
    CustomOptional<int, NoDefault> DxgiVRAM;                                    
    CustomOptional<bool, SoftDefault> VulkanSpoofing { false };
    CustomOptional<bool, SoftDefault> VulkanExtensionSpoofing { false };
    CustomOptional<int, NoDefault> VulkanVRAM;                       
    CustomOptional<bool> SpoofHAGS { false };
    CustomOptional<bool> SpoofFeatureLevel { false };
    CustomOptional<uint32_t> SpoofedVendorId { VendorId::Nvidia };
    CustomOptional<uint32_t> SpoofedDeviceId { 0x2684 };
    CustomOptional<uint32_t, NoDefault> TargetVendorId;
    CustomOptional<uint32_t, NoDefault> TargetDeviceId;
    CustomOptional<std::wstring> SpoofedGPUName { L"NVIDIA GeForce RTX 4090" };
    CustomOptional<bool> UESpoofIntelAtomics64 { false };
    CustomOptional<bool> SpoofRegistry { false };
    CustomOptional<bool> SpoofUser32 { false };
    CustomOptional<std::wstring> SpoofedDriver { L"32.0.15.9155" };

              
    CustomOptional<std::wstring, NoDefault> PluginPath;
    CustomOptional<bool> LoadSpecialK { false };
    CustomOptional<bool> LoadReShade { false };
    CustomOptional<bool> LoadCustomAmdxc64OnRdna2 { false };
    CustomOptional<bool> LoadAsiPlugins { false };
    CustomOptional<int> LateAsiPluginsDelay { 30 };

                       
    CustomOptional<FGInput> FGInput { FGInput::NoFG };
    CustomOptional<FGOutput> FGOutput { FGOutput::NoFG };
    CustomOptional<FGNvngxReplacement> FGNvngxReplacement { FGNvngxReplacement::Nukems };
    CustomOptional<bool> FGDrawUIOverFG { false };
    CustomOptional<bool> FGUIPremultipliedAlpha { true };
    CustomOptional<bool, SoftDefault> FGDisableHudless { false };
    CustomOptional<bool> FGDisableUI { false };
    CustomOptional<bool> FGSkipReset { false };
    CustomOptional<int> FGAllowedFrameAhead { 1 };
    CustomOptional<bool> FGDepthValidNow { false };
    CustomOptional<bool> FGVelocityValidNow { false };
    CustomOptional<bool> FGHudlessValidNow { false };
    CustomOptional<bool> FGOnlyAcceptFirstHudless { false };
    CustomOptional<bool, SoftDefault> FGPreserveSwapChain { true };
    CustomOptional<bool, SoftDefault> FGSkipResizeBuffers { false };
    CustomOptional<bool> FGModifyBufferState { false };
    CustomOptional<bool> FGModifySCIndex { false };
    CustomOptional<float> FGHudCutoff { 0.0f };
    CustomOptional<FrameTimeSource> FTInput { FrameTimeSource::Input };
    CustomOptional<bool> FGReprojectionEnabled { false };                           

             
                                                                                                    
    CustomOptional<bool, SoftDefault> FGEnabled { false };
    CustomOptional<bool> FGUseMutexForSwapchain { true };
    CustomOptional<bool> FGMakeMVCopy { true };
    CustomOptional<bool> FGMakeDepthCopy { true };
    CustomOptional<bool> FGResourceFlip { false };
    CustomOptional<bool> FGResourceFlipOffset { false };
    CustomOptional<bool, SoftDefault> FGAlwaysCaptureFSRFGSwapchain { false };

    CustomOptional<int, NoDefault> FGRectLeft;
    CustomOptional<int, NoDefault> FGRectTop;
    CustomOptional<int, NoDefault> FGRectWidth;
    CustomOptional<int, NoDefault> FGRectHeight;

                      
    CustomOptional<bool, SoftDefault> FGDisableHUDFix { false };
    CustomOptional<bool> FGHUDFix { false };
    CustomOptional<int> FGHUDLimit { 1 };
    CustomOptional<bool> FGHUDFixExtended { false };
    CustomOptional<bool> FGHUDFixUITexture { true };
    CustomOptional<bool, NoDefault> FGHUDFixUIUnblend;
    CustomOptional<bool> FGImmediateCapture { false };
    CustomOptional<bool> FGHudfixPersistentBindings { true };
    CustomOptional<bool> FGDontUseSwapchainBuffers { false };
    CustomOptional<bool> FGRelaxedResolutionCheck { false };
    CustomOptional<bool> FGHudfixDisableRTV { false };
    CustomOptional<bool> FGHudfixDisableSRV { false };
    CustomOptional<bool> FGHudfixDisableUAV { false };
    CustomOptional<bool> FGHudfixDisableOM { false };
    CustomOptional<bool> FGHudfixDisableDispatch { false };
    CustomOptional<bool> FGHudfixDisableDI { false };
    CustomOptional<bool> FGHudfixDisableDII { false };
    CustomOptional<bool> FGHudfixDisableSCR { true };
    CustomOptional<bool> FGHudfixDisableSGR { true };

                                 
    CustomOptional<bool> FGAlwaysTrackHeaps { false };
    CustomOptional<bool> FGResourceBlocking { false };
    CustomOptional<bool> FGUseShards { false };

                                  
    CustomOptional<bool> FGEnableDepthScale { false };
    CustomOptional<float> FGDepthScaleMax { 10000.0f };

             
                                                                  
                                                            
    CustomOptional<bool> FGDebugView { false };
    CustomOptional<bool> FGDebugResetLines { false };
    CustomOptional<bool> FGDebugTearLines { false };
    CustomOptional<bool> FGDebugPacingLines { false };
    CustomOptional<bool> FGAsync { false };
    CustomOptional<bool> FGFramePacingTuning { true };
    CustomOptional<float> FGFPTSafetyMarginInMs { 0.01f };
    CustomOptional<float> FGFPTVarianceFactor { 0.3f };
    CustomOptional<bool> FGFPTAllowHybridSpin { false };
    CustomOptional<int> FGFPTHybridSpinTime { 2 };
    CustomOptional<bool> FGFPTAllowWaitForSingleObjectOnFence { false };
    CustomOptional<bool> FSRFGDisableFlipMetering { false };

    CustomOptional<bool> FSRFGSkipConfigForHudless { false };
    CustomOptional<bool> FSRFGSkipDispatchForHudless { false };
    CustomOptional<bool> FSRFGEnableWatermark { false };

           
    CustomOptional<bool> FGXeFGIgnoreInitChecks { false };
    CustomOptional<int> FGXeFGInterpolationCount { 1 };
    CustomOptional<bool> FGXeFGDynamicMFG { false };                                                        
    CustomOptional<float> FGXeFGFramerateTargetDMFG { 0.0f };                                                       
    CustomOptional<int> FGXeFGRoundingDMFG { 1 };                                                          
    CustomOptional<bool> FGXeFGDynamicAllow1X { true };                                                        
    CustomOptional<bool> FGXeFGTargetAsCapDMFG { false };                                                    
    CustomOptional<int, NoDefault> FGXeFGOverrideInterpolationCount;                                         
    CustomOptional<bool> FGXeFGUIComposition { false };
    CustomOptional<bool> FGXeFGDepthInverted { true };
    CustomOptional<bool> FGXeFGJitteredMV { false };
    CustomOptional<bool> FGXeFGHighResMV { false };
    CustomOptional<bool> FGXeFGDebugView { false };
    CustomOptional<bool, SoftDefault> FGXeFGForceBorderless { false };

            
    CustomOptional<int> FGDLSSGInterpolationCount { 1 };                              
    CustomOptional<bool> FGDLSSGUseGamesReflexMarkers { true };
    CustomOptional<int, NoDefault>
        FGDLSSGOverrideInterpolationCount;                                                                            
                                                                              
    CustomOptional<bool> FGDLSSGOverrideForceDMFG { false };                                            
    CustomOptional<bool> FGDLSSGForceDMFG { false };                                                    
    CustomOptional<float> FGDLSSGFramerateTargetDMFG { 0.0f };                                                   

                   
    CustomOptional<ReprojectionFill> ReprojectionFillMode { ReprojectionFill::Dithering };
    CustomOptional<float> ReprojectionDepthCutoff { 0.1f };
    CustomOptional<uint32_t> ReprojectionCutoffExpand { 1 };
    CustomOptional<bool> ReprojectionLateLatch { true };
    CustomOptional<bool> ReprojectionDirectionCache { true };
    CustomOptional<bool> ReprojectionParallaxAuto { true };                                       
    CustomOptional<float> ReprojectionParallaxScale { 0.0f };                                    
    CustomOptional<bool> ReprojectionThirdPersonDetection { true };

             
                                                                                                                                       
    CustomOptional<uint32_t> NvngxFGDispatchFlags { 0x10000000 };                     
    CustomOptional<bool> NvngxFGShowDebug { false };
    CustomOptional<bool> NvngxFGDisableHudless { false };

                
    CustomOptional<bool, SoftDefault> UseFakenvapi { true };
    CustomOptional<bool> ForceXeLL { false };
    CustomOptional<bool> FN_ForceLatencyFlex { false };
    CustomOptional<LFXMode> FN_LatencyFlexMode { LFXMode::Conservative };
    CustomOptional<ForceReflex> FN_ForceReflex { ForceReflex::InGame };
    CustomOptional<LowLatencyInput> LowLatencyInput { LowLatencyInput::Auto };
    CustomOptional<LowLatencyMode> LowLatencyOutput { LowLatencyMode::Auto };

             
    CustomOptional<bool> EnableDlssInputs { true };
    CustomOptional<bool> EnableXeSSInputs { true };
    CustomOptional<bool, SoftDefault> UseFsr2Inputs { true };
    CustomOptional<bool, SoftDefault> UseFsr2Dx11Inputs { false };
    CustomOptional<bool, SoftDefault> UseFsr2VulkanInputs { false };
    CustomOptional<bool, SoftDefault> Fsr2Pattern { false };
    CustomOptional<bool, SoftDefault> UseFsr3Inputs { true };
    CustomOptional<bool, SoftDefault> Fsr3Pattern { false };
    CustomOptional<bool, SoftDefault> UseFfxInputs { true };
    CustomOptional<bool> EnableHotSwapping { false };
    CustomOptional<bool, SoftDefault> EnableFsr2Inputs { true };
    CustomOptional<bool, SoftDefault> EnableFsr3Inputs { true };
    CustomOptional<bool, SoftDefault> EnableFfxInputs { true };

                
    CustomOptional<float> FramerateLimit { 0.0f };

          
    CustomOptional<bool> ForceHDR { false };
    CustomOptional<bool> UseHDR10 { false };
    CustomOptional<bool> SkipColorSpace { false };

             
    CustomOptional<bool, SoftDefault> OverrideVsync { false };
    CustomOptional<bool, NoDefault> ForceVsync;
    CustomOptional<UINT> VsyncInterval { 0 };

                                     
    CustomOptional<bool, NoDefault> _DONTUSE_Fsr4ForceEnableInt8;

    bool LoadFromPath(const wchar_t* InPath);
    bool SaveIni();
    bool SaveXeFG();

    void CheckUpscalerFiles();

                                                                                                  
    static bool FGCanFollowGame();
    bool FGFollowsGame() const;
    bool IsFGEnabled() const;
    int FGInterpolationCount(int outputCount) const;

    std::vector<std::string> GetConfigLog();

                                                                                                                 
                          
    std::string ExportOverlaySettings();
    bool ImportOverlaySettings(std::string_view code);

                                                                                                                
                                                     
    bool ApplyOverlaySettings(std::string_view text);

    static Config* Instance();

  private:
    inline static Config* _config;
    inline static std::vector<std::string> _log;

    std::filesystem::path absoluteFileName;
    std::wstring fileName = L"OptiScaler.ini";

                                                                   
    struct NoCaseLess
    {
        bool operator()(const std::string& a, const std::string& b) const { return _stricmp(a.c_str(), b.c_str()) < 0; }
    };

    std::map<std::string, CustomOptional<int>, NoCaseLess> _ffxCustomUpscalerIndex;
    std::mutex _customIndexMutex;

    bool Reload(std::filesystem::path iniPath);

                                                                                                           
    void ReadOverlaySettings(bool assign);
    void WriteOverlaySettings();

    std::optional<std::string> readString(std::string section, std::string key, bool lowercase = false);
    std::optional<std::wstring> readWString(std::string section, std::string key, bool lowercase = false);
    std::optional<float> readFloat(std::string section, std::string key);
    std::optional<int> readInt(std::string section, std::string key);
    std::optional<uint32_t> readUInt(std::string section, std::string key);
    std::optional<bool> readBool(std::string section, std::string key);

    template <typename Enum> std::optional<Enum> readEnum(std::string section, std::string key);
};
