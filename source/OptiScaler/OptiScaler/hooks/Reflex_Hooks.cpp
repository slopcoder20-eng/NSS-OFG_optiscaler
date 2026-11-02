#include "pch.h"
#include "Reflex_Hooks.h"
#include <Config.h>

#include <proxies/Streamline_Proxy.h>

#include <magic_enum.hpp>

#include <math.h>
#include <imgui/ImGuiNotify.hpp>
#include <shaders/reproject/mouseInputs/InputCollection.h>
#include <low_latency/input/input_common.h>
#include <misc/FrameLimit.h>

static inline uint64_t _lastFrameId[20] = { 0 };
static inline IUnknown* _lastDev[20] = { 0 };

                           

NvAPI_Status ReflexHooks::hkNvAPI_D3D_SetSleepMode(IUnknown* pDev, NV_SET_SLEEP_MODE_PARAMS* pSetSleepModeParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif
                                                                
    memcpy(&_lastSleepParams, pSetSleepModeParams, sizeof(NV_SET_SLEEP_MODE_PARAMS));
    _lastSleepDev = pDev;

    if (State::Instance().gameQuirks & GameQuirk::HitmanReflexHacks)
        _lastSetSleepThread = std::this_thread::get_id();

    if (_minimumIntervalUs != 0)
        pSetSleepModeParams->minimumIntervalUs = _minimumIntervalUs;

    return o_NvAPI_D3D_SetSleepMode(pDev, pSetSleepModeParams);
}

NvAPI_Status ReflexHooks::hkNvAPI_D3D_Sleep(IUnknown* pDev)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif

                                             
    static bool skip = false;

    if (!skip)
    {
        skip = true;
        bool slept = streamlineSleep();
        skip = false;

        if (slept)
            return NVAPI_OK;
    }
    else
    {
        _lastSleepDev = pDev;
        return o_NvAPI_D3D_Sleep(pDev);
    }

    _lastSleepDev = pDev;
    return o_NvAPI_D3D_Sleep(pDev);
}

NvAPI_Status ReflexHooks::hkNvAPI_D3D_GetLatency(IUnknown* pDev, NV_LATENCY_RESULT_PARAMS* pGetLatencyParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif

    return o_NvAPI_D3D_GetLatency(pDev, pGetLatencyParams);
}

NvAPI_Status ReflexHooks::sendMarker(IUnknown* pDev, NV_LATENCY_MARKER_PARAMS* pSetLatencyMarkerParams,
                                     bool toStreamline)
{
    if (toStreamline)
        return NVAPI_OK;

    return o_NvAPI_D3D_SetLatencyMarker(pDev, pSetLatencyMarkerParams);
}

NvAPI_Status ReflexHooks::hkNvAPI_D3D_SetLatencyMarker(IUnknown* pDev,
                                                       NV_LATENCY_MARKER_PARAMS* pSetLatencyMarkerParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif

                                                                                                                   
                 
    _updatesWithoutMarker = 0;
    return sendMarker(pDev, pSetLatencyMarkerParams, false);
}

NvAPI_Status ReflexHooks::processGameMarker(IUnknown* pDev, NV_LATENCY_MARKER_PARAMS* pSetLatencyMarkerParams,
                                            MarkerSend send)
{
    _updatesWithoutMarker = 0;

                                                                                 
                                                                             

                                                                                                  
    if (_lastAsyncMarkerFrameId + 10 < pSetLatencyMarkerParams->frameID)
    {
        _FgNumFramesToGenerate = 0;
    }

                                                                 
    if (pSetLatencyMarkerParams->frameID >> 32)
    {
        if (!State::Instance().rtssReflexInjection && State::Instance().activeFgOutput == FGOutput::XeFG)
        {
            ImGuiToast notification { ImGuiToastType::Warning, 10000 };
            notification.setTitle("RTSS + XeFG detected");
            notification.setContent(
                "RTSS Reflex Injection is known to cause issues.\nEspecially when using XeFG.\nPlease disable it.");
            ImGui::InsertNotification(notification);
        }

        State::Instance().rtssReflexInjection = true;
    }

                                                                                       
    State::Instance().reflexFrameId = pSetLatencyMarkerParams->frameID;

                                                              
    _lastFrameId[pSetLatencyMarkerParams->markerType] = pSetLatencyMarkerParams->frameID;
    _lastDev[pSetLatencyMarkerParams->markerType] = pDev;

    if (pSetLatencyMarkerParams->markerType == SIMULATION_START)
    {
        InputCollection::getInstance().startCollectingForFrame(pSetLatencyMarkerParams->frameID);
    }
    else if (pSetLatencyMarkerParams->markerType == SIMULATION_END)
    {
        _lastMarkerFrame = State::Instance().fgLastFrame;
    }

    static bool skip[20] = {};

    if (State::Instance().activeFgOutput == FGOutput::DLSSG && StreamlineProxy::IsD3D12Inited() &&
        Config::Instance()->FGDLSSGUseGamesReflexMarkers.value_or_default() && State::Instance().currentFG &&
        State::Instance().currentFG->IsActive() && !State::Instance().currentFG->IsPaused())
    {
        sl::PCLMarker marker {};
        bool noMarker = false;

        switch (pSetLatencyMarkerParams->markerType)
        {
        case SIMULATION_START:
            marker = sl::PCLMarker::eSimulationStart;
            break;

        case SIMULATION_END:
            marker = sl::PCLMarker::eSimulationEnd;
            break;

        case RENDERSUBMIT_START:
            marker = sl::PCLMarker::eRenderSubmitStart;
            break;

        case RENDERSUBMIT_END:
            marker = sl::PCLMarker::eRenderSubmitEnd;
            break;

        case PRESENT_START:
            marker = sl::PCLMarker::ePresentStart;
            break;

        case PRESENT_END:
            marker = sl::PCLMarker::ePresentEnd;
            break;

        case INPUT_SAMPLE:
            marker = sl::PCLMarker::eControllerInputSample;
            break;

        case TRIGGER_FLASH:
            marker = sl::PCLMarker::eTriggerFlash;
            break;

        case PC_LATENCY_PING:
            marker = sl::PCLMarker::eDeltaTCalculation;
            break;

        case OUT_OF_BAND_RENDERSUBMIT_START:
            marker = sl::PCLMarker::eOutOfBandRenderSubmitStart;
            break;

        case OUT_OF_BAND_RENDERSUBMIT_END:
            marker = sl::PCLMarker::eOutOfBandRenderSubmitEnd;
            break;

        case OUT_OF_BAND_PRESENT_START:
            marker = sl::PCLMarker::eOutOfBandPresentStart;
            break;

        case OUT_OF_BAND_PRESENT_END:
            marker = sl::PCLMarker::eOutOfBandPresentEnd;
            break;

        default:
            noMarker = true;
        }

        auto index = (UINT) marker;

        if (!noMarker && !skip[index])
        {
            if (pSetLatencyMarkerParams->markerType == PRESENT_START && State::Instance().currentFG != nullptr)
            {
                auto frameCount = State::Instance().currentFG->FrameCount();
                if (pSetLatencyMarkerParams->frameID - frameCount > 1)
                    LOG_WARN("FrameId Moved too much??? {} -> {}", frameCount, pSetLatencyMarkerParams->frameID);

                if (pSetLatencyMarkerParams->frameID != frameCount)
                    State::Instance().currentFG->SetFrameCount(pSetLatencyMarkerParams->frameID);

                State::Instance().reflexFrameId = pSetLatencyMarkerParams->frameID;
            }

            sl::FrameToken* frameToken;
            uint32_t frameCount = (uint32_t) pSetLatencyMarkerParams->frameID;
            StreamlineProxy::GetNewFrameToken()(frameToken, &frameCount);

            LOG_TRACE("{} for frame {}", magic_enum::enum_name(marker), frameCount);

            skip[index] = true;
            ScopedOptiScalerReflex optiScalerCall {};
            StreamlineProxy::PCLSetMarker()(marker, *frameToken);
            skip[index] = false;

            return send(pDev, pSetLatencyMarkerParams, true);
        }
        else
        {
                                                              
            return send(pDev, pSetLatencyMarkerParams, noMarker);
        }
    }

    if (State::Instance().gameQuirks & GameQuirk::HitmanReflexHacks)
    {
        if ((pSetLatencyMarkerParams->markerType != PRESENT_START &&
             pSetLatencyMarkerParams->markerType != PRESENT_END) &&
            _lastSetSleepThread != std::this_thread::get_id())
        {
            LOG_TRACE("Skipping marker for a hack");
            return NVAPI_OK;
        }

        if (pSetLatencyMarkerParams->markerType == SIMULATION_END)
        {
            NV_LATENCY_MARKER_PARAMS newParams = *pSetLatencyMarkerParams;
            auto previousThread = _lastSetSleepThread;
            _lastSetSleepThread = std::this_thread::get_id();

            newParams.markerType = RENDERSUBMIT_START;
            processGameMarker(pDev, &newParams, send);

            newParams.markerType = RENDERSUBMIT_END;
            processGameMarker(pDev, &newParams, send);

            _lastSetSleepThread = previousThread;
        }
    }

    return send(pDev, pSetLatencyMarkerParams, false);
}

bool ReflexHooks::streamlineSleep()
{
    auto& state = State::Instance();

                                                                                                             
    if (state.activeFgOutput != FGOutput::DLSSG ||
        !Config::Instance()->FGDLSSGUseGamesReflexMarkers.value_or_default() || state.currentFG == nullptr ||
        !state.currentFG->IsActive() || state.currentFG->IsPaused())
    {
        return false;
    }

    uint32_t frameCount = (uint32_t) _lastFrameId[SIMULATION_START] + 1;

    sl::FrameToken* frameToken;
    StreamlineProxy::GetNewFrameToken()(frameToken, &frameCount);

    LOG_TRACE("Sleep for frame {}", frameCount);

    ScopedOptiScalerReflex optiScalerCall {};
    StreamlineProxy::ReflexSleep()(*frameToken);
    return true;
}

void ReflexHooks::gameSetSleepMode()
{
    if (State::Instance().gameQuirks & GameQuirk::HitmanReflexHacks)
        _lastSetSleepThread = std::this_thread::get_id();
}

NvAPI_Status ReflexHooks::hkNvAPI_D3D12_SetAsyncFrameMarker(ID3D12CommandQueue* pCommandQueue,
                                                            NV_ASYNC_FRAME_MARKER_PARAMS* pSetAsyncFrameMarkerParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif

    _lastAsyncMarkerFrameId = pSetAsyncFrameMarkerParams->frameID;

                                                                               
       
                                              
                                     
                                                              

                                                                                           
                    

                                                                                 

                                    
                                 

                                                  
           
                                                                     
               
                                
               
                  
               
                                                                         
                                  
               
           

                                                                 

                                
                                  
                                
                                       
                                
                                       
                                

                                     
                                                          
                                         
                                                

                                              
           
                                
           
              
           
                                             
                                  
           

                      
                                                                    

                                               
                                                     
           
                                                                    
               
                                             
                                                          
               
                                                                
               
                                                          

                                                                              
               
           
       

    return o_NvAPI_D3D12_SetAsyncFrameMarker(pCommandQueue, pSetAsyncFrameMarkerParams);
}

void* ReflexHooks::getHookedReflexSync(PFN_NvApi_QueryInterface& queryInterface)
{
    if (o_NvAPI_D3D_SetReflexSync == nullptr && queryInterface != nullptr)
        o_NvAPI_D3D_SetReflexSync = GET_INTERFACE(NvAPI_D3D_SetReflexSync, queryInterface);

    return o_NvAPI_D3D_SetReflexSync != nullptr ? (void*) &hkNvAPI_D3D_SetReflexSync : nullptr;
}

NvAPI_Status ReflexHooks::hkNvAPI_D3D_SetReflexSync(IUnknown* pDev, NV_SET_REFLEX_SYNC_PARAMS* pSetReflexSyncParams)
{
                                                                                                                   
                      
    if (InputCommon::active_output() == LowLatencyMode::Reflex &&
        (State::Instance().activeFgOutput == FGOutput::FSRFG || State::Instance().activeFgOutput == FGOutput::XeFG))
    {
        return NVAPI_OK;
    }

    return o_NvAPI_D3D_SetReflexSync(pDev, pSetReflexSyncParams);
}

NvAPI_Status ReflexHooks::hkNvAPI_Vulkan_SetLatencyMarker(HANDLE vkDevice,
                                                          NV_VULKAN_LATENCY_MARKER_PARAMS* pSetLatencyMarkerParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif

    _updatesWithoutMarker = 0;
    State::Instance().reflexFrameId = pSetLatencyMarkerParams->frameID;

    return o_NvAPI_Vulkan_SetLatencyMarker(vkDevice, pSetLatencyMarkerParams);
}

NvAPI_Status ReflexHooks::hkNvAPI_Vulkan_SetSleepMode(HANDLE vkDevice,
                                                      NV_VULKAN_SET_SLEEP_MODE_PARAMS* pSetSleepModeParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif
                                                                
    memcpy(&_lastVkSleepParams, pSetSleepModeParams, sizeof(NV_VULKAN_SET_SLEEP_MODE_PARAMS));
    _lastVkSleepDev = vkDevice;

    if (_minimumIntervalUs != 0)
        pSetSleepModeParams->minimumIntervalUs = _minimumIntervalUs;

    return o_NvAPI_Vulkan_SetSleepMode(vkDevice, pSetSleepModeParams);
}

NvAPI_Status ReflexHooks::hkNvAPI_Vulkan_GetLatency(HANDLE vkDevice, NV_VULKAN_LATENCY_RESULT_PARAMS* pGetLatencyParams)
{
#ifdef LOG_REFLEX_CALLS
    LOG_FUNC();
#endif

    return o_NvAPI_Vulkan_GetLatency(vkDevice, pGetLatencyParams);
}

void ReflexHooks::hookReflex(PFN_NvApi_QueryInterface& queryInterface)
{
    if (!_inited)
    {
#ifdef _DEBUG
        LOG_FUNC();
#endif

        o_NvAPI_D3D_SetSleepMode = GET_INTERFACE(NvAPI_D3D_SetSleepMode, queryInterface);
        o_NvAPI_D3D_Sleep = GET_INTERFACE(NvAPI_D3D_Sleep, queryInterface);
        o_NvAPI_D3D_GetLatency = GET_INTERFACE(NvAPI_D3D_GetLatency, queryInterface);
        o_NvAPI_D3D_SetLatencyMarker = GET_INTERFACE(NvAPI_D3D_SetLatencyMarker, queryInterface);
        o_NvAPI_D3D12_SetAsyncFrameMarker = GET_INTERFACE(NvAPI_D3D12_SetAsyncFrameMarker, queryInterface);
        o_NvAPI_Vulkan_SetLatencyMarker = GET_INTERFACE(NvAPI_Vulkan_SetLatencyMarker, queryInterface);
        o_NvAPI_Vulkan_SetSleepMode = GET_INTERFACE(NvAPI_Vulkan_SetSleepMode, queryInterface);
        o_NvAPI_Vulkan_GetLatency = GET_INTERFACE(NvAPI_Vulkan_GetLatency, queryInterface);

        _inited = o_NvAPI_D3D_SetSleepMode && o_NvAPI_D3D_Sleep && o_NvAPI_D3D_GetLatency &&
                  o_NvAPI_D3D_SetLatencyMarker && o_NvAPI_D3D12_SetAsyncFrameMarker &&
                  o_NvAPI_Vulkan_SetLatencyMarker && o_NvAPI_Vulkan_SetSleepMode && o_NvAPI_Vulkan_GetLatency;

        if (_inited)
            LOG_DEBUG("Inited Reflex hooks");
    }
}

uint8_t ReflexHooks::dlssgFrameCountToGenerate() { return _FgNumFramesToGenerate; }

void ReflexHooks::setDlssgFrameCount(uint8_t count) { _FgNumFramesToGenerate = count; }

bool ReflexHooks::isReflexHooked() { return _inited; }

void* ReflexHooks::getHookedReflex(unsigned int InterfaceId)
{
    if (InterfaceId == GET_ID(NvAPI_D3D_SetSleepMode) && o_NvAPI_D3D_SetSleepMode)
    {
        return &hkNvAPI_D3D_SetSleepMode;
    }
    if (InterfaceId == GET_ID(NvAPI_D3D_Sleep) && o_NvAPI_D3D_Sleep)
    {
        return &hkNvAPI_D3D_Sleep;
    }
    if (InterfaceId == GET_ID(NvAPI_D3D_GetLatency) && o_NvAPI_D3D_GetLatency)
    {
        return &hkNvAPI_D3D_GetLatency;
    }
    if (InterfaceId == GET_ID(NvAPI_D3D_SetLatencyMarker) && o_NvAPI_D3D_SetLatencyMarker)
    {
        return &hkNvAPI_D3D_SetLatencyMarker;
    }
    if (InterfaceId == GET_ID(NvAPI_D3D12_SetAsyncFrameMarker) && o_NvAPI_D3D12_SetAsyncFrameMarker)
    {
        return &hkNvAPI_D3D12_SetAsyncFrameMarker;
    }
    if (InterfaceId == GET_ID(NvAPI_Vulkan_SetLatencyMarker) && o_NvAPI_Vulkan_SetLatencyMarker)
    {
        return &hkNvAPI_Vulkan_SetLatencyMarker;
    }
    if (InterfaceId == GET_ID(NvAPI_Vulkan_SetSleepMode) && o_NvAPI_Vulkan_SetSleepMode)
    {
        return &hkNvAPI_Vulkan_SetSleepMode;
    }
    if (InterfaceId == GET_ID(NvAPI_Vulkan_GetLatency) && o_NvAPI_Vulkan_GetLatency)
    {
        return &hkNvAPI_Vulkan_GetLatency;
    }

    return nullptr;
}

                                              
void ReflexHooks::update(bool fgActive, bool isVulkan)
{
                                                                              
                                                                             
    _updatesWithoutMarker++;

    State::Instance().reflexShowWarning = false;

                                                                              
    bool reflexOutput = InputCommon::active_output() == LowLatencyMode::Reflex;

    if (_updatesWithoutMarker > 20 || !_inited)
    {
        State::Instance().reflexLimitsFps = false;
        return;
    }

    if (isVulkan && _lastVkSleepDev)
    {
                                             
        State::Instance().reflexLimitsFps = _lastVkSleepParams.bLowLatencyMode;
    }
    else if (!reflexOutput)
    {
                                                                            
        State::Instance().reflexLimitsFps = false;
    }
    else if (_lastSleepDev)
    {
                                                                                                    
        State::Instance().reflexLimitsFps = !fgActive || _lastSleepParams.bLowLatencyMode;
        State::Instance().reflexShowWarning =
            State::Instance().activeFgOutput == FGOutput::FSRFG && fgActive && _lastSleepParams.bLowLatencyMode;
    }
    else
    {
        State::Instance().reflexLimitsFps = false;
    }

    static float lastFps = 0;
    static bool lastReflexLimitsFps = State::Instance().reflexLimitsFps;

                                          
    if (State::Instance().reflexLimitsFps != lastReflexLimitsFps)
    {
        lastReflexLimitsFps = State::Instance().reflexLimitsFps;
        lastFps = 0;
        setFPSLimit(0);
    }

    if (!State::Instance().reflexLimitsFps)
        return;

                                                                         
    float currentFps = FrameLimit::targetFps();
    static uint8_t lastFgNumFramesToGenerate = 0;

    if (lastFgNumFramesToGenerate != _FgNumFramesToGenerate)
    {
        lastFgNumFramesToGenerate = _FgNumFramesToGenerate;
        setFPSLimit(currentFps);

        if (_FgNumFramesToGenerate == 0)
            LOG_DEBUG("DLSS FG no longer detected");
        else
            LOG_DEBUG("DLSS FG detected, mode: {}x", _FgNumFramesToGenerate + 1);
    }

                                                         
                                                           
    if (fgActive && State::Instance().activeFgOutput == FGOutput::FSRFG)
    {
                                                                                                                 
        bool driverCountsFg = reflexOutput && InputCommon::output_reports_fg_multiplier();

        if (!driverCountsFg)
            currentFps /= 2;
    }

    if (currentFps != lastFps)
    {
        setFPSLimit(currentFps);
        lastFps = currentFps;
    }
}

                           
void ReflexHooks::setFPSLimit(float fps)
{
    LOG_INFO("Set FPS Limit to: {}", fps);
    if (fps == 0.0)
        _minimumIntervalUs = 0;
    else
        _minimumIntervalUs = static_cast<uint32_t>(std::round(1'000'000 / fps));

    if (_lastSleepDev != nullptr)
    {
        NV_SET_SLEEP_MODE_PARAMS temp {};
        memcpy(&temp, &_lastSleepParams, sizeof(NV_SET_SLEEP_MODE_PARAMS));
        temp.minimumIntervalUs = _minimumIntervalUs;

        o_NvAPI_D3D_SetSleepMode(_lastSleepDev, &temp);
    }

    if (_lastVkSleepDev != nullptr)
    {
        NV_VULKAN_SET_SLEEP_MODE_PARAMS temp {};
        memcpy(&temp, &_lastVkSleepParams, sizeof(NV_VULKAN_SET_SLEEP_MODE_PARAMS));
        temp.minimumIntervalUs = _minimumIntervalUs;
        o_NvAPI_Vulkan_SetSleepMode(_lastVkSleepDev, &temp);
    }
}

bool ReflexHooks::gameIsSendingMarkers()
{
    return _lastMarkerFrame != 0 && ((State::Instance().fgLastFrame < _lastMarkerFrame) ||
                                     (State::Instance().fgLastFrame - _lastMarkerFrame) < 5);
}
