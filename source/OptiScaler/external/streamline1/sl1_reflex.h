/*
* Copyright (c) 2022 NVIDIA CORPORATION. All rights reserved
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/ 

#pragma once

namespace sl1
{

enum ReflexMode
{
    eReflexModeOff,
    eReflexModeLowLatency,
    eReflexModeLowLatencyWithBoost,
};

struct ReflexConstants
{
                                           
    ReflexMode mode = eReflexModeOff;
                                                                                     
    uint32_t frameLimitUs = 0;
                                                                                                                
    bool useMarkersToOptimize = false;
                                                                                                  
                                               
    uint16_t virtualKey = 0;
                                                          
    void* ext = {};
};

struct ReflexReport
{
                                     
    uint64_t frameID{};
    uint64_t inputSampleTime{};
    uint64_t simStartTime{};
    uint64_t simEndTime{};
    uint64_t renderSubmitStartTime{};
    uint64_t renderSubmitEndTime{};
    uint64_t presentStartTime{};
    uint64_t presentEndTime{};
    uint64_t driverStartTime{};
    uint64_t driverEndTime{};
    uint64_t osRenderQueueStartTime{};
    uint64_t osRenderQueueEndTime{};
    uint64_t gpuRenderStartTime{};
    uint64_t gpuRenderEndTime{};
    uint32_t gpuActiveRenderTimeUs{};
    uint32_t gpuFrameTimeUs{};
};

struct ReflexSettings
{
                                                         
    bool lowLatencyAvailable = false;
                                                       
    bool latencyReportAvailable = false;
                                                                                      
    uint32_t statsWindowMessage;
                               
    ReflexReport frameReport[64];
                                                                                          
    bool flashIndicatorDriverControlled = false;    
                                                          
    void* ext = {};
};

enum ReflexMarker
{
    eReflexMarkerSimulationStart,
    eReflexMarkerSimulationEnd,
    eReflexMarkerRenderSubmitStart,
    eReflexMarkerRenderSubmitEnd,
    eReflexMarkerPresentStart,
    eReflexMarkerPresentEnd,
    eReflexMarkerInputSample,
    eReflexMarkerTriggerFlash,    
    eReflexMarkerPCLatencyPing,
                      
    eReflexMarkerSleep = 0x1000,
};

}
