#include "pch.h"

#include <misc/IdentifyGpu.h>

#include "input_common.h"
#include "input_xell.h"
#include <low_latency/low_latency_tech/ll_xell.h>
#include <low_latency/low_latency_tech/ll_antilag2.h>
#include <low_latency/low_latency_tech/ll_latencyflex.h>
#include <low_latency/low_latency_tech/ll_reflex.h>
#include <low_latency/low_latency_tech/ll_reflex_vk.h>
#include <low_latency/low_latency_tech/ll_antilag_vk.h>
#include <low_latency/low_latency_tech/ll_fps_limiter.h>
#include <hooks/Vulkan_Hooks.h>
#include <misc/FrameLimit.h>
#include <inputs/FG/XeFG_Inputs_Dx12.h>
#include <framegen/IFGFeature_Dx12.h>
#include <nvapi/fakenvapi.h>

#include <deque>

std::atomic<std::shared_ptr<LowLatencyTech>> InputCommon::currently_active_tech;
std::atomic<std::shared_ptr<LowLatencyTech>> InputCommon::xefg_xell;

static bool marker_supported(InputMarkerMode mode, MarkerType type)
{
    switch (mode)
    {
    case InputMarkerMode::NoMarkers:
        return false;
    case InputMarkerMode::SimStartOnly:
        return type == MarkerType::SIMULATION_START;
    case InputMarkerMode::SimStartAndPresentStart:
        return type == MarkerType::SIMULATION_START || type == MarkerType::PRESENT_START ||
               type == MarkerType::OUT_OF_BAND_PRESENT_START;
    case InputMarkerMode::SimOnly:
        return type == MarkerType::SIMULATION_START || type == MarkerType::SIMULATION_END;
    default:
        return true;
    }
}

          
bool InputCommon::deinit_current_tech()
{
                                            
                                                                  
    auto old_tech = currently_active_tech.exchange(nullptr);

    if (old_tech)
    {
        LOG_TRACE("Deiniting current tech");
        while (old_tech.use_count() > 1)
            std::this_thread::yield();

        old_tech->deinit();

        std::memset(frame_reports, 0, sizeof(frame_reports));

        return true;
    }

    return false;
}

bool InputCommon::init_tech(IUnknown* pDevice, API api, LowLatencyMode desiredMode)
{
    if (!currently_active_tech.load() && delay_deinit == 0)
    {
        auto try_init = [&](auto low_latency_tech, const char* name) -> bool
        {
            if (low_latency_tech->init(pDevice))
            {
                LOG_INFO("LowLatency algo: {}", name);
                currently_active_tech.store(std::move(low_latency_tech));
                return true;
            }
            return false;
        };

        bool isInitialized = false;
        switch (desiredMode)
        {
        case LowLatencyMode::XeLL:
            isInitialized = try_init(std::make_shared<XeLL>(), "XeLL");
            break;
        case LowLatencyMode::AntiLag2:
            isInitialized = try_init(std::make_shared<AntiLag2>(), "AntiLag2");
            break;
        case LowLatencyMode::Reflex:
            if (api == API::Vulkan)
                isInitialized = try_init(std::make_shared<ReflexVk>(), "Reflex Vulkan");
            else
                isInitialized = try_init(std::make_shared<Reflex>(), "Reflex");
            break;
        case LowLatencyMode::AntiLagVk:
            isInitialized = try_init(std::make_shared<AntiLagVk>(), "AntiLag Vulkan");
            break;
        case LowLatencyMode::LatencyFlex:
            isInitialized = try_init(std::make_shared<LatencyFlex>(), "LatencyFlex");
            break;
        case LowLatencyMode::FpsLimiter:
            isInitialized = try_init(std::make_shared<FpsLimiter>(), "FPS Limiter");
            break;
        default:
            break;
        }

        if (!isInitialized && desiredMode != LowLatencyMode::LatencyFlex)
        {
            failed_output = desiredMode;
            failed_time = std::chrono::steady_clock::now();
            isInitialized = try_init(std::make_shared<LatencyFlex>(), "LatencyFlex (Fallback)");
            if (isInitialized)
            {
                Config::Instance()->LowLatencyOutput.set_volatile_value(LowLatencyMode::LatencyFlex);
            }
        }

        if (auto current_tech = currently_active_tech.load(); current_tech && isInitialized)
        {
            activeOutput = current_tech->get_mode();
            output_api = api;

                                                                                                              
            current_tech->set_forced_mode(xefg_paced());
            current_tech->set_low_latency_override(Config::Instance()->FN_ForceReflex.value_or_default());

            apply_sleep_mode(current_tech.get());                                    
            return true;
        }
    }

    return false;
}

LowLatencyMode InputCommon::default_output(API api)
{
                                           
    auto vendorId = IdentifyGpu::getPrimaryGpu().vendorId;

                                                               
    if (api == API::Vulkan)
    {
        if (vendorId == VendorId::AMD && VulkanHooks::o_vkAntiLagUpdateAMD != nullptr)
            return LowLatencyMode::AntiLagVk;

        if (driver_reflex_available(api))
            return LowLatencyMode::Reflex;

        return LowLatencyMode::LatencyFlex;
    }

                         
    if (vendorId == VendorId::Intel && api != API::DX11)
        return LowLatencyMode::XeLL;

    if (vendorId == VendorId::AMD)
        return LowLatencyMode::AntiLag2;

    if (driver_reflex_available(api))
        return LowLatencyMode::Reflex;

    return LowLatencyMode::LatencyFlex;
}

const char* InputCommon::output_unavailable(LowLatencyMode output, API api)
{
    if (output == LowLatencyMode::Reflex && !driver_reflex_available(api))
        return api == API::Vulkan ? "Needs an Nvidia GPU with VK_NV_low_latency2" : "Needs an Nvidia GPU";

    if (output == LowLatencyMode::AntiLagVk && VulkanHooks::o_vkAntiLagUpdateAMD == nullptr)
        return "Needs an AMD GPU with VK_AMD_anti_lag";

    if (output == LowLatencyMode::AntiLag2 && IdentifyGpu::getPrimaryGpu().vendorId != VendorId::AMD)
        return "Needs an AMD GPU";

    return nullptr;
}

bool InputCommon::driver_reflex_available(API api)
{
    if (IdentifyGpu::getPrimaryGpu().vendorId != VendorId::Nvidia)
        return false;

    if (api == API::Vulkan)
        return VulkanHooks::o_vkSetLatencySleepModeNV != nullptr;

    return !fakenvapi::isUsingAsMainNvapi();
}

LowLatencyMode InputCommon::for_api(LowLatencyMode mode, API api)
{
    if (api == API::Vulkan && mode == LowLatencyMode::AntiLag2)
        return LowLatencyMode::AntiLagVk;

    if (api != API::Vulkan && mode == LowLatencyMode::AntiLagVk)
        return LowLatencyMode::AntiLag2;

    if (api != API::DX12 && mode == LowLatencyMode::XeLL)
        return default_output(api);

    return mode;
}

API InputCommon::device_api(const InputContext& inputContext, IUnknown* pDevice)
{
    if (inputContext.api != API::NotSelected)
        return inputContext.api;

                                           
    thread_local IUnknown* lastDevice = nullptr;
    thread_local API lastApi = API::NotSelected;

    if (pDevice == nullptr)
        return lastApi;

    if (pDevice != lastDevice)
    {
        ID3D11Device* device11 = nullptr;

        if (pDevice->QueryInterface(IID_PPV_ARGS(&device11)) == S_OK)
        {
            device11->Release();
            lastApi = API::DX11;
        }
        else
        {
            lastApi = API::DX12;
        }

        lastDevice = pDevice;
    }

    return lastApi;
}

API InputCommon::register_call(const InputContext& inputContext, IUnknown* pDevice)
{
    auto api = device_api(inputContext, pDevice);

                                       
    if (!inputContext.localContext)
    {
        if (api != API::NotSelected)
            input_api[static_cast<size_t>(inputContext.caller)] = api;

        avaliableInputs.set(inputContext.caller);
    }

    return api;
}

API InputCommon::uses_api()
{
    if (activeInput != LowLatencyInput::None)
    {
        if (auto api = input_api[static_cast<size_t>(activeInput)].load(); api != API::NotSelected)
            return api;
    }

    return State::Instance().swapchainApi;
}

std::optional<LowLatencyMode> InputCommon::forced_output()
{
                                                                                                                
                                                                                                           
                                       
    if (InputXeLL::IsNative())
        return LowLatencyMode::XeLL;

    return std::nullopt;
}

                                                                                                                    
                                                                  
LowLatencyMode InputCommon::xefg_output(LowLatencyMode configured)
{
    if ((configured == LowLatencyMode::Reflex || configured == LowLatencyMode::AntiLag2) &&
        output_unavailable(configured, API::DX12) == nullptr)
    {
        return configured;
    }

    return LowLatencyMode::XeLL;
}

bool InputCommon::xefg_paced()
{
                                                                                      
    return activeOutput == LowLatencyMode::XeLL && State::Instance().activeFgOutput == FGOutput::XeFG;
}

LowLatencyInput InputCommon::default_input()
{
                                                                                                                    
                                                                                                                   
                   
    if (State::Instance().activeFgInput == FGInput::XeFG && avaliableInputs[LowLatencyInput::XeLL] &&
        get_sleep_copy(LowLatencyInput::XeLL).low_latency_enabled)
    {
        return LowLatencyInput::XeLL;
    }

                                                                            
    if (avaliableInputs[LowLatencyInput::AntiLag2] && reports_frame_generation(LowLatencyInput::AntiLag2))
        return LowLatencyInput::AntiLag2;

    if (avaliableInputs[LowLatencyInput::Reflex])
        return LowLatencyInput::Reflex;

                                                                                                 
    if (avaliableInputs[LowLatencyInput::XeLL] && get_sleep_copy(LowLatencyInput::XeLL).low_latency_enabled)
        return LowLatencyInput::XeLL;

    if (avaliableInputs[LowLatencyInput::AntiLag2])
        return LowLatencyInput::AntiLag2;

    if (avaliableInputs[LowLatencyInput::UeLowLatency])
        return LowLatencyInput::UeLowLatency;

    if (avaliableInputs[LowLatencyInput::XeLL])
        return LowLatencyInput::XeLL;

                                                                           
    if (avaliableInputs[LowLatencyInput::OptiScaler])
        return LowLatencyInput::OptiScaler;

    return LowLatencyInput::None;
}

const char* InputCommon::incompatibility(LowLatencyInput input, LowLatencyMode output)
{
                                                                                                                 
    if (input != LowLatencyInput::AntiLag2 && input != LowLatencyInput::UeLowLatency &&
        input != LowLatencyInput::OptiScaler)
    {
        return nullptr;
    }

    if (output == LowLatencyMode::XeLL && input != LowLatencyInput::OptiScaler)
    {
        return input == LowLatencyInput::AntiLag2
                   ? "XeLL needs frame ids and frame markers, AntiLag 2 has neither"
                   : "XeLL needs render submit and present markers, UE only sends simulation markers";
    }

                                                                                                             
    if (output == LowLatencyMode::LatencyFlex &&
        (LFXMode) Config::Instance()->FN_LatencyFlexMode.value_or_default() != LFXMode::Conservative)
    {
        return "LatencyFlex only works in the Conservative mode with this input";
    }

    return nullptr;
}

std::optional<LowLatencyInput> InputCommon::forced_input()
{
                                                                               
    if (XeFGInputs::Passthrough() || InputXeLL::IsNative())
        return LowLatencyInput::XeLL;

    return std::nullopt;
}

bool InputCommon::update_low_latency_tech(IUnknown* pDevice, API api, std::optional<LowLatencyMode> mode)
{
                                                                                                              
    if (InputXeLL::IsNative())
    {
        activeInput = LowLatencyInput::XeLL;
        return true;
    }

                                                                 
    if (avaliableInputs.count() == 0 && !mode.has_value())
    {
        LOG_TRACE("No avaliable inputs");

                                                
                                                                                         

        return true;
    }

    LowLatencyMode desiredMode = LowLatencyMode::None;
    LowLatencyInput desiredInput = Config::Instance()->LowLatencyInput.value_or_default();

    if (!pDevice)
    {
                                                     
        if (activeOutput != LowLatencyMode::None && !mode.has_value())
            return true;                                                                        
        else
            return false;
    }

    if (mode.has_value())
        desiredMode = mode.value();

    if (desiredMode != LowLatencyMode::None && desiredMode == activeOutput && api == output_api)
    {
                                 
        return true;
    }

                                                                     

    if (auto forced = forced_input())
        desiredInput = *forced;

                                               
    if (desiredInput == LowLatencyInput::None)
        desiredInput = LowLatencyInput::Auto;

                                                                           
    if (!avaliableInputs[desiredInput] && desiredInput != LowLatencyInput::Auto)
    {
        static std::atomic<LowLatencyInput> unavailable = LowLatencyInput::_;

        if (unavailable.exchange(desiredInput) != desiredInput)
            LOG_WARN("Selected Low Latency Input is not avaliable yet: {}", magic_enum::enum_name(desiredInput));

        desiredInput = LowLatencyInput::Auto;
    }

    if (desiredInput == LowLatencyInput::Auto)
        desiredInput = default_input();

                                                                                         
    if (activeInput != desiredInput)
    {
        activeInput = desiredInput;
        LOG_INFO("Low latency input: {}", magic_enum::enum_name(activeInput));

                                                                                                     
        std::memset(frame_reports, 0, sizeof(frame_reports));

        for (auto& id : last_marker_frame_ids)
            id = 0;

        if (auto current_tech = currently_active_tech.load())
            apply_sleep_mode(current_tech.get());                                    
    }

                                                                                                            
                                                          
    if (auto inputApi = input_api[static_cast<size_t>(activeInput)].load();
        !mode.has_value() && inputApi != API::NotSelected && api != inputApi)
    {
        return true;
    }

                                                                                                              
                                                                              
    auto forced = forced_output();

    if (!forced.has_value() && State::Instance().activeFgOutput == FGOutput::XeFG)
        forced = xefg_output(Config::Instance()->LowLatencyOutput.value_or_default());

                                                                                                                  
                                                                                                           
                                                                                                  
    if (forced.has_value() && !mode.has_value() && for_api(*forced, api) != *forced)
        return true;

    if (desiredMode == LowLatencyMode::None)
        desiredMode = Config::Instance()->LowLatencyOutput.value_or_default();

                                          
    if (desiredMode == LowLatencyMode::Auto || desiredMode == LowLatencyMode::None ||
        output_unavailable(desiredMode, api) != nullptr)
    {
        desiredMode = default_output(api);
    }

    if (forced.has_value())
        desiredMode = *forced;

    desiredMode = for_api(desiredMode, api);

                                                                                                     
    if (xefg_uses_output_xell && activeOutput == LowLatencyMode::XeLL && desiredMode != LowLatencyMode::XeLL)
    {
        static std::atomic<LowLatencyMode> waiting = LowLatencyMode::None;

        if (waiting.exchange(desiredMode) != desiredMode)
            LOG_INFO("Low latency output {} waits for XeFG to restart, it paces with the XeLL output's context",
                     magic_enum::enum_name(desiredMode));

        return true;
    }

                                                                                           
    if (desiredMode == failed_output && currently_active_tech.load() != nullptr &&
        std::chrono::steady_clock::now() - failed_time < std::chrono::seconds(10))
    {
        desiredMode = activeOutput;
    }

    if (activeOutput == desiredMode && api == output_api)
    {
        delay_deinit = 0;
        return true;
    }

                                                    

    std::scoped_lock lock(create_tech_mutex);

    if (init_tech(pDevice, api, desiredMode))
        return true;

    auto try_reinit = [&]() -> bool
    {
        if (!deinit_current_tech())
        {
            LOG_ERROR("Couldn't deinitialize low latency tech");
            return false;
        }

        return init_tech(pDevice, api, desiredMode);
    };

                                                                                            
    if (delay_deinit > 0)
    {
        if (--delay_deinit == 0)
            return try_reinit();
    }
    else
    {
        bool al2 = false;
        {
            auto current_tech = currently_active_tech.load();
            if (current_tech && current_tech->get_mode() == LowLatencyMode::AntiLag2)
                al2 = true;
        }

        if (al2)
        {
            delay_deinit = 50;
        }
        else
        {
            return try_reinit();
        }
    }

    return true;
}

void InputCommon::add_marker_to_report(const MarkerParams& marker_params)
{
    auto current_timestamp = Util::GetTimestamp() / 1000;
    static auto last_sim_start = current_timestamp;
    static auto _2nd_last_sim_start = current_timestamp;
    auto current_report = &frame_reports[marker_params.frame_id % FRAME_REPORTS_BUFFER_SIZE];

    if (current_report->frameID != marker_params.frame_id)
    {
        *current_report = FrameReport {};
    }

    current_report->frameID = marker_params.frame_id;
    current_report->gpuFrameTimeUs = (uint32_t) (last_sim_start - _2nd_last_sim_start);
    current_report->gpuActiveRenderTimeUs = 100;
    current_report->driverStartTime = current_timestamp;
    current_report->driverEndTime = current_timestamp + 100;
    current_report->gpuRenderStartTime = current_timestamp;
    current_report->gpuRenderEndTime = current_timestamp + 100;
    current_report->osRenderQueueStartTime = current_timestamp;
    current_report->osRenderQueueEndTime = current_timestamp + 100;
    switch (marker_params.marker_type)
    {
    case MarkerType::SIMULATION_START:
        _2nd_last_sim_start = last_sim_start;
        last_sim_start = Util::GetTimestamp() / 1000;
        current_report->simStartTime = last_sim_start;
        break;
    case MarkerType::SIMULATION_END:
        current_report->simEndTime = Util::GetTimestamp() / 1000;
        break;
    case MarkerType::RENDERSUBMIT_START:
        current_report->renderSubmitStartTime = Util::GetTimestamp() / 1000;
        break;
    case MarkerType::RENDERSUBMIT_END:
        current_report->renderSubmitEndTime = Util::GetTimestamp() / 1000;
        break;
    case MarkerType::PRESENT_START:
        current_report->presentStartTime = Util::GetTimestamp() / 1000;
        break;
    case MarkerType::PRESENT_END:
        current_report->presentEndTime = Util::GetTimestamp() / 1000;
        break;
    case MarkerType::INPUT_SAMPLE:
        current_report->inputSampleTime = Util::GetTimestamp() / 1000;
        break;
    default:
        break;
    }
}

         
InputResult InputCommon::set_low_latency_tech(IUnknown* pDevice, LowLatencyMode mode)
{
    if (!update_low_latency_tech(pDevice, API::DX12, mode))
        return InputResult::LowLatencyUpdateFail;

    return InputResult::Ok;
}

InputResult InputCommon::sleep(const InputContext& inputContext, IUnknown* pDevice, std::optional<uint32_t> frame_id)
{
    if (!update_low_latency_tech(pDevice, register_call(inputContext, pDevice)))
        return InputResult::LowLatencyUpdateFail;

    if (inputContext.caller != activeInput)
        return InputResult::UsingDifferentInput;

    presents_without_input = 0;

    if (auto current_tech = currently_active_tech.load())
    {
        const auto start = std::chrono::steady_clock::now();
        current_tech->sleep(frame_id);
        last_sleep_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    }
    else
    {
        return InputResult::NoReadyOutput;
    }

    return InputResult::Ok;
}

InputResult InputCommon::set_marker(const InputContext& inputContext, IUnknown* pDevice,
                                    const MarkerParams& marker_params, bool toOutput)
{
    if (!update_low_latency_tech(pDevice, register_call(inputContext, pDevice)))
        return InputResult::LowLatencyUpdateFail;

    if (inputContext.caller != activeInput)
        return InputResult::UsingDifferentInput;

    if (!marker_supported(inputContext.markerMode, marker_params.marker_type))
        return InputResult::InputNotSupported;

                                                                                                                   
                                                                              
    if (auto type = (size_t) marker_params.marker_type;
        type < last_marker_frame_ids.size() && marker_params.frame_id != 0)
    {
        if (last_marker_frame_ids[type].exchange(marker_params.frame_id) == marker_params.frame_id)
            return InputResult::Ok;
    }

    presents_without_input = 0;

    if (marker_params.marker_type == MarkerType::PRESENT_START)
        last_present_start_frame_id = marker_params.frame_id;

                                                                                   
    if (!inputContext.noFrameId)
    {
        if (marker_params.marker_type == MarkerType::SIMULATION_START)
            State::Instance().reflexFrameId = marker_params.frame_id;

        add_marker_to_report(marker_params);
    }

    if (!toOutput)
        return InputResult::Ok;

                                                                                                  
    if (marker_params.frame_id != 0)
    {
        if (auto own = xefg_xell.load())
            own->set_marker(pDevice, marker_params);
    }

                                                                                                                    
    if (marker_params.frame_id == 0 && (activeOutput == LowLatencyMode::Reflex || activeOutput == LowLatencyMode::XeLL))
    {
        return InputResult::Ok;
    }

    if (auto current_tech = currently_active_tech.load())
        current_tech->set_marker(pDevice, marker_params);
    else
        return InputResult::NoReadyOutput;

    LOG_TRACE_LOWLATENCY("{}: {}", magic_enum::enum_name(marker_params.marker_type), marker_params.frame_id);

    return InputResult::Ok;
}

InputResult InputCommon::set_async_marker(const InputContext& inputContext, ID3D12CommandQueue* pCommandQueue,
                                          const MarkerParams& marker_params)
{
    auto fgOutput = State::Instance().activeFgOutput;

                                                                                               
    if (!inputContext.localContext)
        mark_frame_generation(inputContext.caller);

                                                                                                                 
                                                                                                                     
                            
    if (fgOutput == FGOutput::XeFG || (activeOutput == LowLatencyMode::Reflex && fgOutput == FGOutput::FSRFG))
        return InputResult::UsingDifferentInput;

                                                                                      
    if (marker_params.marker_type == MarkerType::OUT_OF_BAND_PRESENT_START && !marker_params.interpolated.has_value() &&
        dlssg_types_presents())
    {
        return InputResult::Ok;
    }

                                                                                                            
                                                                          
    if (inputContext.caller != activeInput && !inputContext.localContext)
        return InputResult::UsingDifferentInput;

                                                                                                                       
                                                                                            
    if (!currently_active_tech.load())
        return inputContext.localContext ? InputResult::Ok : InputResult::LowLatencyUpdateFail;

    if (!marker_supported(inputContext.markerMode, marker_params.marker_type))
        return InputResult::InputNotSupported;

                                                                                               
                                           

    if (auto current_tech = currently_active_tech.load())
        current_tech->set_async_marker(pCommandQueue, marker_params);
    else
        return InputResult::NoReadyOutput;

    LOG_TRACE_LOWLATENCY("{}: {}", magic_enum::enum_name(marker_params.marker_type), marker_params.frame_id);

    return InputResult::Ok;
}

InputResult InputCommon::set_sleep_mode(const InputContext& inputContext, IUnknown* pDevice, SleepMode* sleep_mode)
{
                                                                                                                    
                                                                                           
    if (!inputContext.localContext)
        get_sleep_copy(inputContext.caller) = *sleep_mode;

    if (!update_low_latency_tech(pDevice, register_call(inputContext, pDevice)))
        return InputResult::LowLatencyUpdateFail;

    if (inputContext.caller != activeInput)
        return InputResult::UsingDifferentInput;

    if (auto current_tech = currently_active_tech.load())
        apply_sleep_mode(current_tech.get());
    else
        return InputResult::NoReadyOutput;

    return InputResult::Ok;
}

InputResult InputCommon::get_sleep_status(const InputContext& inputContext, IUnknown* pDevice,
                                          SleepParams* sleep_params)
{
    if (!update_low_latency_tech(pDevice, register_call(inputContext, pDevice)))
        return InputResult::LowLatencyUpdateFail;

                                                                
                                              
                                                   

    if (auto current_tech = currently_active_tech.load())
        current_tech->get_sleep_status(sleep_params);
    else
        return InputResult::NoReadyOutput;

    return InputResult::Ok;
}

InputResult InputCommon::get_latency(const InputContext& inputContext, IUnknown* pDev, void* latency_params)
{
                                              
                                                   

    if (!update_low_latency_tech(pDev, register_call(inputContext, pDev)))
        return InputResult::LowLatencyUpdateFail;

    if (!latency_params)
        return InputResult::InvalidParameter;

                                                  
    if (inputContext.caller == LowLatencyInput::Reflex || inputContext.caller == LowLatencyInput::OptiScaler)
    {
        if (activeOutput == LowLatencyMode::Reflex)
        {
            if (auto reflex_tech = std::dynamic_pointer_cast<Reflex>(currently_active_tech.load()))
            {
                if (reflex_tech->get_latency((NV_LATENCY_RESULT_PARAMS*) latency_params) == NVAPI_OK)
                    return InputResult::Ok;
            }
        }

        NV_LATENCY_RESULT_PARAMS* reports = (NV_LATENCY_RESULT_PARAMS*) latency_params;

        if (reports->version != NV_LATENCY_RESULT_PARAMS_VER1)
        {
            LOG_ERROR("Unsupported version {}", reports->version);
            return InputResult::InvalidParameter;
        }

        static_assert(sizeof(reports->frameReport) == NVAPI_BUFFER_SIZE * sizeof(FrameReport));

        if (!copy_frame_reports((FrameReport*) reports->frameReport))
            return InputResult::NotEnoughReports;

        return InputResult::Ok;
    }
    else if (inputContext.caller == LowLatencyInput::XeLL)
    {
        xell_frame_report_t* reports = (xell_frame_report_t*) latency_params;
        constexpr size_t reportCount = 64;                                                           

        if (activeOutput == LowLatencyMode::XeLL)
        {
            if (auto current_tech = currently_active_tech.load())
            {
                auto xell_tech = std::static_pointer_cast<XeLL>(current_tech);
                auto result = xell_tech->xellGetFramesReports(reports);

                if (result == XELL_RESULT_SUCCESS)
                    return InputResult::Ok;
            }
        }

                                 
                                                                                    
        for (auto i = 0; i < reportCount; i++)
        {
            auto& reportOut = reports[i];
            auto& reportIn = frame_reports[i];

            reportOut.m_frame_id = reportIn.frameID & 0xFFFFFFFF;
            reportOut.m_sim_start_ts = reportIn.simStartTime;
            reportOut.m_sim_end_ts = reportIn.simEndTime;
            reportOut.m_render_submit_start_ts = reportIn.renderSubmitStartTime;
            reportOut.m_render_submit_end_ts = reportIn.renderSubmitEndTime;
            reportOut.m_present_start_ts = reportIn.presentStartTime;
            reportOut.m_present_end_ts = reportIn.presentEndTime;
        }

        return InputResult::Ok;
    }
    else
    {
        return InputResult::InputNotSupported;
    }
}

bool InputCommon::copy_frame_reports(FrameReport* reports)
{
                                                              
    if (frame_reports[FRAME_REPORTS_BUFFER_SIZE - 1].frameID == 0)
    {
        std::memset(reports, 0, NVAPI_BUFFER_SIZE * sizeof(FrameReport));
                                                                 
        return false;
    }

                                          
    size_t minIdx = 0;
    uint64_t minID = frame_reports[0].frameID;
    for (size_t i = 1; i < FRAME_REPORTS_BUFFER_SIZE; i++)
    {
        if (frame_reports[i].frameID < minID)
        {
            minID = frame_reports[i].frameID;
            minIdx = i;
        }
    }

                                                      
    size_t firstChunk = std::min<uint64_t>(NVAPI_BUFFER_SIZE, FRAME_REPORTS_BUFFER_SIZE - minIdx);
    std::memcpy(reports, frame_reports + minIdx, firstChunk * sizeof(FrameReport));

                                          
    if (firstChunk < NVAPI_BUFFER_SIZE)
        std::memcpy(reports + firstChunk, frame_reports, (NVAPI_BUFFER_SIZE - firstChunk) * sizeof(FrameReport));

    return true;
}

InputResult InputCommon::get_frame_reports(const InputContext& inputContext, IUnknown* pDev, FrameReport* reports)
{
    if (!update_low_latency_tech(pDev, register_call(inputContext, pDev)))
        return InputResult::LowLatencyUpdateFail;

    if (reports == nullptr)
        return InputResult::InvalidParameter;

    return copy_frame_reports(reports) ? InputResult::Ok : InputResult::NotEnoughReports;
}

#define UPDATE_TIMING_ENTRY(name, type)                                                                                \
    if (frameReport.name##EndTime >= frameReport.name##StartTime)                                                      \
    {                                                                                                                  \
        double name##Pos = (double) (frameReport.name##StartTime - start) / rangeNs;                                   \
        double name##Length = (double) (frameReport.name##EndTime - frameReport.name##StartTime) / rangeNs;            \
        timingDataOut.type = TimingEntry { .position = name##Pos, .length = name##Length };                            \
    }                                                                                                                  \
    else                                                                                                               \
    {                                                                                                                  \
        timingDataOut.type.reset();                                                                                    \
    }

bool InputCommon::get_timing_data(TimingData& timingDataOut)
{
    InputContext tempContext {};

    if (activeOutput == LowLatencyMode::Reflex)
    {
                                                               
        timingDataOut = {};
        return false;
    }

                                                                     
       
                                       
                            

                                                                   
                                                                    
                                       
           
                                     
                            
                           

                               
                               

                             
                             
           

                          
                           

                                                            

                                                                                               
                                              
                                                         
                                               
                                             
                                                           
                                                   

                                       
                                                                    

                      
        

                                                   
       
                                                                        
                                                                                     
                                                           

                                                                                               
           
                                                                                         
                           
           

                                             
                                                              
       

                                                        
       
                                                                        
                                                                                                   
                                                                  

                                                                                                    
           
                                                                                            
                           
           

                                             
                                                              
       

    {
        size_t maxIdx = 0;
        uint64_t maxID = frame_reports[0].frameID;
        for (size_t i = 1; i < FRAME_REPORTS_BUFFER_SIZE; i++)
        {
            if (frame_reports[i].frameID > maxID)
            {
                maxID = frame_reports[i].frameID;
                maxIdx = i;
            }
        }

        auto highestValidId = (NVAPI_BUFFER_SIZE + maxIdx) % FRAME_REPORTS_BUFFER_SIZE;
        auto& frameReport = frame_reports[highestValidId];                 

        uint64_t start = UINT64_MAX;
        uint64_t end = 0;

                                                                 
        auto pTimes = (const uint64_t*) &frameReport.simStartTime;
        for (auto i = 0; i < 11; i++)
        {
            auto& time = pTimes[i];
            if (time == 0)
                continue;

            if (time < start)
                start = time;

            if (time > end)
                end = time;
        }

                                                                                               
        if (end <= start)
        {
            timingDataOut = {};
            return false;
        }

        double rangeNs = static_cast<double>(end - start);

        timingDataOut.timeRange = TimingEntry { .position = 0, .length = rangeNs };
        UPDATE_TIMING_ENTRY(sim, simulation)
        UPDATE_TIMING_ENTRY(renderSubmit, renderSubmit)
        UPDATE_TIMING_ENTRY(present, present)
        UPDATE_TIMING_ENTRY(driver, driver)
        UPDATE_TIMING_ENTRY(osRenderQueue, osRenderQueue)
        UPDATE_TIMING_ENTRY(gpuRender, gpuRender)

        return true;
    };

    return false;
}

                                                                                                               
                                                                 
void InputCommon::fg_game_present(ID3D12CommandQueue* gameQueue, bool presented, uint32_t frameMultiplier)
{
    auto reflex_tech = std::dynamic_pointer_cast<Reflex>(currently_active_tech.load());

    if (reflex_tech == nullptr || gameQueue == nullptr)
        return;

    uint64_t frame_id = last_present_start_frame_id;
    reflex_tech->set_async_marker(gameQueue,
                                  { frame_id, presented ? MarkerType::PRESENT_END : MarkerType::PRESENT_START });

    if (!presented)
    {
        reflex_tech->set_reflex_sync(frameMultiplier);
        fg_frame_id = frame_id;
        fg_new_batch = true;
    }
}

bool InputCommon::output_reports_fg_multiplier()
{
    auto reflex_tech = std::dynamic_pointer_cast<Reflex>(currently_active_tech.load());
    return reflex_tech != nullptr && reflex_tech->has_reflex_sync();
}

                                                                                                                   
                                                                                                     
namespace
{
struct XeFGBatch
{
    uint64_t frame_id = 0;
    uint32_t frames = 0;                                                                            
    uint32_t presented = 0;
};

std::mutex xefg_batch_mutex;
std::deque<XeFGBatch> xefg_batches;                             
XeFGBatch xefg_batch;                            
constexpr size_t xefg_max_batches = 8;
uint32_t xefg_types_logged = 0;                                                 
constexpr uint32_t xefg_types_log_limit = 16;

void reset_xefg_batches()
{
    std::scoped_lock lock(xefg_batch_mutex);
    xefg_batches.clear();
    xefg_batch = {};
    xefg_types_logged = 0;
}
}             

                                                                                                            
                                                                                                  
void InputCommon::fg_output_present(ID3D12CommandQueue* presentQueue, bool presented, uint32_t frameMultiplier)
{
                                              
    static uint64_t batchFrameId = 0;
    static uint32_t batchPresents = 0;
    static bool batchOpen = false;

                                                                                                                      
                                                                                      
                                         
    if (State::Instance().activeFgOutput == FGOutput::XeFG)
    {
        if (presentQueue == nullptr)
            return;

        if (xefg_present_queue.load() != presentQueue)
        {
            presentQueue->AddRef();

            if (auto old = xefg_present_queue.exchange(presentQueue))
                old->Release();
        }

        auto tech = currently_active_tech.load();

        if (xefg_xell.load() == nullptr || tech == nullptr)
            return;

        uint64_t frame_id = 0;
        std::optional<bool> interpolated;
        uint32_t position = 0;
        uint32_t frames = 0;
        bool logType = false;

        {
            std::scoped_lock lock(xefg_batch_mutex);

                                                                                                        
            if (!presented && xefg_batch.presented >= xefg_batch.frames && !xefg_batches.empty())
            {
                xefg_batch = xefg_batches.front();
                xefg_batches.pop_front();
            }
            else if (presented && xefg_batch.frame_id != 0)
            {
                xefg_batch.presented++;
            }

            frame_id = xefg_batch.frame_id;

                                                                                     
            if (!presented && frame_id != 0 && activeOutput == LowLatencyMode::AntiLag2)
            {
                position = xefg_batch.presented;
                frames = xefg_batch.frames;

                if (position < frames)
                    interpolated = position + 1 < frames;

                if (xefg_types_logged < xefg_types_log_limit)
                {
                    xefg_types_logged++;
                    logType = true;
                }
            }
        }

        if (frame_id != 0)
        {
            MarkerParams params { frame_id, presented ? MarkerType::OUT_OF_BAND_PRESENT_END
                                                      : MarkerType::OUT_OF_BAND_PRESENT_START };
            params.interpolated = interpolated;

            if (logType)
            {
                LOG_INFO("XeFG AntiLag 2 frame type: frame id {}, position {} of {} frames, interpolated {}", frame_id,
                         position, frames, interpolated.has_value() ? (*interpolated ? "true" : "false") : "inferred");
            }

            tech->set_async_marker(presentQueue, params);
        }

        return;
    }

    auto reflex_tech = std::dynamic_pointer_cast<Reflex>(currently_active_tech.load());

    if (reflex_tech == nullptr || presentQueue == nullptr)
        return;

    auto send = [&](MarkerType type) { reflex_tech->set_async_marker(presentQueue, { batchFrameId, type }); };

    if (!presented && fg_new_batch.exchange(false))
    {
                                               
        if (batchOpen)
            send(MarkerType::OUT_OF_BAND_RENDERSUBMIT_END);

        batchFrameId = fg_frame_id;
        batchPresents = 0;
        batchOpen = true;
        send(MarkerType::OUT_OF_BAND_RENDERSUBMIT_START);
    }

    if (batchFrameId == 0)
        return;

    send(presented ? MarkerType::OUT_OF_BAND_PRESENT_END : MarkerType::OUT_OF_BAND_PRESENT_START);

    if (presented && batchOpen && ++batchPresents >= frameMultiplier)
    {
        send(MarkerType::OUT_OF_BAND_RENDERSUBMIT_END);
        batchOpen = false;
    }
}

                                                                                                                   
                                                                                                                     
                                                                                                                       
bool InputCommon::dlssg_types_presents()
{
    auto fgOutput = State::Instance().activeFgOutput;

    return activeOutput == LowLatencyMode::AntiLag2 && fgOutput != FGOutput::FSRFG && fgOutput != FGOutput::XeFG &&
           State::Instance().dlssgDetectedInterpolationCount > 0;
}

void InputCommon::dlssg_present()
{
                                         
    static uint32_t presents = 0;

    if (!dlssg_types_presents())
    {
        presents = 0;
        return;
    }

    auto tech = currently_active_tech.load();

    if (tech == nullptr)
        return;

    auto frames = static_cast<uint32_t>(State::Instance().dlssgDetectedInterpolationCount) + 1;
    bool interpolated = presents++ % frames != 0;

    tech->set_async_marker(nullptr, { 0, MarkerType::OUT_OF_BAND_PRESENT_START, interpolated });
}

void InputCommon::xefg_marker(void* xellContext, uint32_t frame_id, uint32_t marker)
{
    static std::atomic_bool seen[2] {};

    MarkerType type;

    if (marker == 80860000)
        type = MarkerType::OUT_OF_BAND_RENDERSUBMIT_START;
    else if (marker == 80860001)
        type = MarkerType::OUT_OF_BAND_RENDERSUBMIT_END;
    else
    {
        LOG_WARN("Unknown XeFG XeLL marker {} for frame id {}", marker, frame_id);
        return;
    }

    auto index = marker - 80860000;

    if (!seen[index].exchange(true))
        LOG_INFO("XeFG sends XeLL marker {} ({}), frame id {}", marker, magic_enum::enum_name(type), frame_id);

    LOG_TRACE_LOWLATENCY("XeFG {}: {}", magic_enum::enum_name(type), frame_id);

                                                                                                               
    auto own = xefg_xell.load();

    if (own == nullptr || own->get_tech_context() != xellContext)
        return;

                                                                                   
    auto fg = State::Instance().currentFG;

    if (fg == nullptr || !fg->IsActive() || fg->IsPaused())
    {
        reset_xefg_batches();
        return;
    }

    if (type == MarkerType::OUT_OF_BAND_RENDERSUBMIT_START)
    {
        xefg_frame_id = frame_id;

        std::scoped_lock lock(xefg_batch_mutex);

                                                                                                                   
        if (xefg_batches.size() >= xefg_max_batches)
            xefg_batches.pop_front();

        xefg_batches.push_back({ frame_id, fg->GetInterpolatedFrameCount() + 1 });
    }

                                       
    auto queue = xefg_present_queue.load();

    if (auto tech = currently_active_tech.load(); tech != nullptr && queue != nullptr)
        tech->set_async_marker(queue, { frame_id, type });
}

                                                                                                                 
                                                       
void InputCommon::xefg_present_status(uint64_t frameIdBefore, uint32_t framesPresented)
{
    auto frame_id = xefg_frame_id.load();

    if (frame_id == 0 || frame_id == frameIdBefore || framesPresented == 0)
        return;

    std::scoped_lock lock(xefg_batch_mutex);

    XeFGBatch* batch = xefg_batch.frame_id == frame_id ? &xefg_batch : nullptr;

    for (auto it = xefg_batches.rbegin(); batch == nullptr && it != xefg_batches.rend(); ++it)
    {
        if (it->frame_id == frame_id)
            batch = &*it;
    }

    if (batch != nullptr)
        batch->frames = framesPresented;
}

void InputCommon::apply_sleep_mode(LowLatencyTech* tech)
{
    auto sleepMode = get_sleep_copy(activeInput);

    if (auto interval = fps_limit_interval_us.load(); interval != 0)
        sleepMode.minimum_interval_us = interval;

    tech->set_sleep_mode(&sleepMode);
}

void InputCommon::update()
{
    auto& state = State::Instance();
    auto current_tech = currently_active_tech.load();
    bool active = false;
    ++present_count;

                                                                         
    auto fpsLimit = FrameLimit::targetFps();

                                                                                                                  
    if (InputXeLL::IsNative())
    {
        if (current_tech != nullptr)
        {
            current_tech.reset();
            std::scoped_lock lock(create_tech_mutex);
            deinit_current_tech();
            activeOutput = LowLatencyMode::None;
        }

        limits_fps = InputXeLL::LimitFps(fpsLimit > 0.0f ? static_cast<uint32_t>(std::round(1'000'000 / fpsLimit)) : 0);
        return;
    }

                                                                                            
    if (current_tech != nullptr)
    {
        bool xefgPaced = xefg_paced();

                                                                                                                   
                                                                                                                       
                                                                 
        static bool lastMultiFrame = false;
        bool multiFrame = state.dlssgLastSetMode == sl::DLSSGMode::eDynamic ||
                          (state.dlssgDetectedInterpolationCount > 1 && activeOutput != LowLatencyMode::AntiLag2);

        if (!std::exchange(lastMultiFrame, multiFrame) && multiFrame && activeOutput != LowLatencyMode::Reflex &&
            activeOutput != LowLatencyMode::FpsLimiter && !xefgPaced &&
            Config::Instance()->FN_ForceReflex.value_or_default() != ForceReflex::ForceEnable)
        {
            LOG_INFO("Multi frame generation, disabling {}", magic_enum::enum_name(activeOutput));
            Config::Instance()->FN_ForceReflex.set_volatile_value(ForceReflex::ForceDisable);
        }

                                                           
        static bool lastXefgPaced = false;
        static ForceReflex lastOverride = ForceReflex::InGame;
        auto lowLatencyOverride = Config::Instance()->FN_ForceReflex.value_or_default();
        current_tech->set_low_latency_override(lowLatencyOverride);
        current_tech->set_forced_mode(xefgPaced);

        bool overrideChanged = std::exchange(lastOverride, lowLatencyOverride) != lowLatencyOverride;

        if (overrideChanged)
            LOG_INFO("Low latency Force State: {}", magic_enum::enum_name(lowLatencyOverride));

        if (std::exchange(lastXefgPaced, xefgPaced) != xefgPaced || overrideChanged)
            apply_sleep_mode(current_tech.get());
    }

                                                                         
    if (current_tech != nullptr && !state.reflexLimitsFps && activeInput != LowLatencyInput::None &&
        ++presents_without_input <= 20)
    {
        auto mode = current_tech->get_mode();

                                                                                                               
                                                                                                                     
                                                                                                    
                                                                                                    
        if (mode == LowLatencyMode::AntiLag2 || mode == LowLatencyMode::XeLL || mode == LowLatencyMode::LatencyFlex ||
            mode == LowLatencyMode::AntiLagVk)
        {
            active = current_tech->is_enabled();
        }
        else if (mode == LowLatencyMode::Reflex && output_api == API::Vulkan)
        {
            auto reflex = std::dynamic_pointer_cast<ReflexVk>(current_tech);
            active = reflex != nullptr && reflex->has_swapchain();
        }
        else if (mode == LowLatencyMode::FpsLimiter)
        {
            active = static_cast<FpsLimiter*>(current_tech.get())->is_limiting();
        }
    }

    uint32_t interval = 0;

    if (active && fpsLimit > 0.0f)
    {
        interval = static_cast<uint32_t>(std::round(1'000'000 / fpsLimit));

                                                                                                                    
                                                                                                       
        auto fg = state.CurrentFG();
        bool fgActive = fg != nullptr && fg->IsActive() && !fg->IsPaused();

                                                                                                                     
        auto vkFg = state.currentVkFG;
        bool driverCountsFg = fgActive && activeOutput == LowLatencyMode::Reflex && output_api == API::Vulkan &&
                              vkFg != nullptr && vkFg->OwnsSwapchain(VulkanHooks::LowLatencySwapchain());

        if (xefg_paced() || driverCountsFg)
        {
                                                                              
        }
        else if (fgActive)
        {
            interval *= fg->GetInterpolatedFrameCount() + 1;
        }
        else if (state.dlssgDetectedInterpolationCount > 0)
        {
            interval *= state.dlssgDetectedInterpolationCount + 1;
        }
        else if (activeInput == LowLatencyInput::AntiLag2 && reports_frame_generation(LowLatencyInput::AntiLag2))
        {
                                                                                                               
            interval *= 2;
        }
    }

    limits_fps = active;

    if (fps_limit_interval_us.exchange(interval) != interval)
    {
        LOG_INFO("FPS limit through {}: {} us", magic_enum::enum_name(activeOutput), interval);

        if (current_tech != nullptr)
            apply_sleep_mode(current_tech.get());
    }
}

InputResult InputCommon::mark_present_start(IUnknown* pDevice)
{
    auto fg = State::Instance().CurrentFG();
    bool fsrfgTypesFrames =
        State::Instance().activeFgOutput == FGOutput::FSRFG && fg != nullptr && fg->IsActive() && !fg->IsPaused();

                                       
    bool marksEnds =
        activeInput == LowLatencyInput::UeLowLatency || (activeInput == LowLatencyInput::AntiLag2 && fsrfgTypesFrames &&
                                                         !reports_frame_generation(LowLatencyInput::AntiLag2));

    if (!marksEnds)
        return InputResult::InputNotSupported;

                                                                   
    if (activeOutput != LowLatencyMode::AntiLag2)
        return InputResult::GenericError;

    if (auto current_tech = currently_active_tech.load())
    {
        MarkerParams marker_params {};
        marker_params.frame_id = 0;                                             
        marker_params.marker_type = MarkerType::PRESENT_START;

                                                        
        current_tech->set_marker(pDevice, marker_params);
    }
    else
    {
        return InputResult::NoReadyOutput;
    }

    return InputResult::Ok;
}

std::shared_ptr<ReflexVk> InputCommon::reflex_vk_output()
{
    return std::dynamic_pointer_cast<ReflexVk>(currently_active_tech.load());
}

xell_context_handle_t InputCommon::xell_output_context()
{
    auto current_tech = currently_active_tech.load();

    if (current_tech == nullptr || current_tech->get_mode() != LowLatencyMode::XeLL)
        return nullptr;

    return (xell_context_handle_t) current_tech->get_tech_context();
}

xell_context_handle_t InputCommon::acquire_xefg_xell(IUnknown* pDevice)
{
    auto output = xefg_output(Config::Instance()->LowLatencyOutput.value_or_default());

    if (output == LowLatencyMode::XeLL)
    {
                                                                                                                    
                               
        if (set_low_latency_tech(pDevice, LowLatencyMode::XeLL) != InputResult::Ok)
            return nullptr;

        auto context = xell_output_context();
        xefg_uses_output_xell = context != nullptr;

        if (context != nullptr)
            xefg_started_output = output;

        return context;
    }

                                                                                                                 
                                         
    std::scoped_lock lock(create_tech_mutex);
    xefg_uses_output_xell = false;

    auto own = xefg_xell.load();

    if (own == nullptr)
    {
        auto xell = std::make_shared<XeLL>();

        if (!xell->init(pDevice))
        {
            LOG_ERROR("Couldn't create XeFG's own XeLL context");
            return nullptr;
        }

        xell->set_markers_only(true);
        xell->set_forced_mode(true);

        SleepMode sleepMode {};
        sleepMode.low_latency_enabled = true;
        xell->set_sleep_mode(&sleepMode);

        xefg_xell.store(xell);
        own = xell;

        LOG_INFO("XeFG paces with its own XeLL context, the low latency output is {}", magic_enum::enum_name(output));
    }

    xefg_started_output = output;

    return (xell_context_handle_t) own->get_tech_context();
}

void InputCommon::release_xefg_xell()
{
    xefg_uses_output_xell = false;
    xefg_started_output = LowLatencyMode::None;

    std::scoped_lock lock(create_tech_mutex);

                                                  
    if (auto own = xefg_xell.exchange(nullptr))
    {
        while (own.use_count() > 1)
            std::this_thread::yield();

        own->deinit();
    }

    xefg_frame_id = 0;
    reset_xefg_batches();

    if (auto queue = xefg_present_queue.exchange(nullptr))
        queue->Release();
}

bool InputCommon::xefg_output_change_pending()
{
                                                                                                                  
              
    auto started = xefg_started_output.load();

    return started != LowLatencyMode::None &&
           xefg_output(Config::Instance()->LowLatencyOutput.value_or_default()) != started;
}
