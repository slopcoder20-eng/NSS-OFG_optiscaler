#pragma once

#include <framegen/IFGFeature.h>

#include <proxies/Streamline_Proxy.h>

                                                                               
class DLSSG_Common : public virtual IFGFeature
{
  protected:
    sl::ViewportHandle _viewport { 0 };
    sl::FrameToken* _frameToken = nullptr;

                                                                          
    void QueryState();

                                                                                                               
    void SetOptions(bool gameMarkersReachStreamline);

                                                                                                
    bool SetConstants(int fIndex, uint32_t frameId, uint32_t mvWidth, uint32_t mvHeight);

    void PauseAfterError();

  public:
                 
    const char* Name() override final { return "DLSSG"; }
    feature_version Version() override final;
    void Activate() override final;
    void Deactivate() override final;
    bool SetInterpolatedFrameCount(UINT interpolatedFrameCount) override final { return true; }
};
