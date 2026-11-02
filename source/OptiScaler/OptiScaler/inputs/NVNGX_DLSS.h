#pragma once

template <typename FeatureType> struct ContextData
{
    std::unique_ptr<FeatureType> feature;
    NVSDK_NGX_Parameter* createParams = nullptr;
    bool createParamsFromGame = false;                                             
    int changeBackendCounter = 0;
    UINT64 lastEvalFrame = 0;
};
