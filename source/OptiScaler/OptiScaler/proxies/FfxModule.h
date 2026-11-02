#pragma once

#include "SysUtils.h"

#include <ffx_api.h>

struct FfxModule
{
    HMODULE dll = nullptr;
    feature_version version { 0, 0, 0 };
    std::wstring filePath;

    bool skipCreateCalls = false;
    bool skipConfigureCalls = false;
    bool skipQueryCalls = false;
    bool skipDispatchCalls = false;

    bool isLoader = false;
    bool hooked = false;

                                                                                                        
                                                                                         
    bool vkBackendV2 = false;

    PfnFfxCreateContext CreateContext = nullptr;
    PfnFfxDestroyContext DestroyContext = nullptr;
    PfnFfxConfigure Configure = nullptr;
    PfnFfxQuery Query = nullptr;
    PfnFfxDispatch Dispatch = nullptr;
};
