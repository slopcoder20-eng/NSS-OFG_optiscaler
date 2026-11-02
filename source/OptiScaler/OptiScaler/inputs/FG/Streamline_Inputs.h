#pragma once
#include "SysUtils.h"
#include <sl.h>

class IFGFeature;

                                                       
class Sl_Inputs
{
  private:
    bool infiniteDepth = false;
    sl::EngineType engineType = sl::EngineType::eCount;

    std::mutex _frameBoundaryMutex;
    bool _isFrameFinished = true;

    uint32_t _currentFrameId = 0;
    uint32_t _currentIndex = -1;
    uint32_t _lastPresentFrameId = UINT32_MAX;
    uint32_t _frameIdIndex[BUFFER_COUNT] = { UINT32_MAX, UINT32_MAX, UINT32_MAX, UINT32_MAX };

    uint64_t mvsWidth = 0;
    uint32_t mvsHeight = 0;

    void CheckForFrame(IFGFeature* fg, uint32_t frameId);
    int IndexForFrameId(uint32_t frameId) const;

  public:
    bool setConstants(const sl::Constants& constants, uint32_t frameId);
    bool evaluateState();
                                                                 
    bool reportResource(const sl::ResourceTag& tag, void* cmdBuffer, uint32_t frameId);
    void reportEngineType(sl::EngineType type) { engineType = type; };
    bool dispatchFG();
    void markPresent(uint64_t frameId);

                                              
};
