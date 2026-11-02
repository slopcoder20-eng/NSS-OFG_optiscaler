#pragma once
#include "SysUtils.h"
#include "Config.h"
#include "detours/detours.h"

#include "Hook_Utils.h"
#include <misc/IdentifyGpu.h>

typedef decltype(&D3DKMTQueryAdapterInfo) PFN_D3DKMTQueryAdapterInfo;
typedef decltype(&D3DKMTEnumAdapters) PFN_D3DKMTEnumAdapters;
typedef decltype(&D3DKMTEnumAdapters2) PFN_D3DKMTEnumAdapters2;
typedef decltype(&D3DKMTCloseAdapter) PFN_D3DKMTCloseAdapter;

inline static PFN_D3DKMTQueryAdapterInfo o_D3DKMTQueryAdapterInfo = nullptr;

VALIDATE_HOOK(hkD3DKMTQueryAdapterInfo, PFN_D3DKMTQueryAdapterInfo)
static NTSTATUS hkD3DKMTQueryAdapterInfo(const D3DKMT_QUERYADAPTERINFO* data)
{
    auto result = o_D3DKMTQueryAdapterInfo(data);

                                                               
    if (data->Type == KMTQAITYPE_WDDM_2_7_CAPS && Config::Instance()->SpoofHAGS.value_or_default())
    {
        LOG_INFO("Spoofing HAGS 2.7");

        if (data->pPrivateDriverData == nullptr)
        {
            LOG_ERROR("HAGS data nullptr");
            return 0xFFFFFFFF;
        }

        auto d3dkmt_wddm_2_7_caps = static_cast<D3DKMT_WDDM_2_7_CAPS*>(data->pPrivateDriverData);
        d3dkmt_wddm_2_7_caps->HwSchSupported = 1;
        d3dkmt_wddm_2_7_caps->HwSchEnabled = 1;
        d3dkmt_wddm_2_7_caps->HwSchEnabledByDefault = 0;

        return 0;
    }
    else if (data->Type == KMTQAITYPE_WDDM_2_9_CAPS && Config::Instance()->SpoofHAGS.value_or_default())
    {
        LOG_INFO("Spoofing HAGS 2.9");

        if (data->pPrivateDriverData == nullptr)
        {
            LOG_ERROR("HAGS data nullptr");
            return 0xFFFFFFFF;
        }

        auto d3dkmt_wddm_2_9_caps = static_cast<D3DKMT_WDDM_2_9_CAPS*>(data->pPrivateDriverData);
        d3dkmt_wddm_2_9_caps->HwSchSupportState = DXGK_FEATURE_SUPPORT_STABLE;
        d3dkmt_wddm_2_9_caps->HwSchEnabled = 1;
        return 0;
    }
    else if (data->Type == KMTQAITYPE_UMDRIVERPRIVATE && data->PrivateDriverDataSize == 608 &&
             Util::WhoIsTheCaller(_ReturnAddress()).starts_with("amd"))
    {
        LOG_DEBUG("Likely FSR 4 GPU Check");

        auto primaryGpu = IdentifyGpu::getPrimaryGpu();

        auto amd_gpu_info = static_cast<uint32_t*>(data->pPrivateDriverData);

        if (primaryGpu.fsr4ForcedSupport || State::Instance().isRunningOnLinux)
        {
                                                                                                                        
                                                       
            if (primaryGpu.fsr4Support == FSR4Support::INT8)
            {
                amd_gpu_info[12] = 145;         
                amd_gpu_info[13] = 1;

                return 1;
            }
            else if (primaryGpu.fsr4Support == FSR4Support::INT8_2)
            {
                amd_gpu_info[12] = 143;         
                amd_gpu_info[13] = 40;

                return 1;
            }
            else if (primaryGpu.fsr4Support == FSR4Support::INT8Lite)
            {
                amd_gpu_info[12] = 150;           
                amd_gpu_info[13] = 1;

                return 1;
            }
            else if (primaryGpu.fsr4Support == FSR4Support::FP8)
            {
                                  
                amd_gpu_info[12] = 152;         
                amd_gpu_info[13] = 81;

                return 1;
            }
        }

        return result;
    }

    return result;
}

                                
static void hookGdi32()
{
    LOG_FUNC();

    o_D3DKMTQueryAdapterInfo =
        reinterpret_cast<PFN_D3DKMTQueryAdapterInfo>(DetourFindFunction("gdi32.dll", "D3DKMTQueryAdapterInfo"));

    if (o_D3DKMTQueryAdapterInfo != nullptr)
    {
        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());

        DetourAttach(&(PVOID&) o_D3DKMTQueryAdapterInfo, hkD3DKMTQueryAdapterInfo);

        auto detourResult = DetourTransactionCommit();
        if (detourResult != NO_ERROR)
        {
            LOG_ERROR("DetourTransactionCommit error: {:X}", detourResult);
            o_D3DKMTQueryAdapterInfo = nullptr;
        }
    }
}

static void unhookGdi32()
{
    if (o_D3DKMTQueryAdapterInfo != nullptr)
    {
        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());

        DetourDetach(&(PVOID&) o_D3DKMTQueryAdapterInfo, hkD3DKMTQueryAdapterInfo);

        auto detourResult = DetourTransactionCommit();
        if (detourResult != NO_ERROR)
        {
            LOG_ERROR("DetourTransactionCommit error: {:X}", detourResult);
        }
        else
        {
            o_D3DKMTQueryAdapterInfo = nullptr;
        }
    }
}
