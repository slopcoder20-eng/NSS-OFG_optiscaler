#pragma once
#include <upscalers/IFeature_Dx12.h>

#include <memory>

                                                                                                                  
                                                                                                                      
                                                                                                                            
                                 
namespace nssdx
{
class Nss;
}

class NSSFeatureDx12 : public IFeature_Dx12
{
  private:
    std::unique_ptr<nssdx::Nss> _nss;
    uint32_t _initRenderW = 0, _initRenderH = 0, _initDisplayW = 0, _initDisplayH = 0;

  protected:
    bool InitInternal(ID3D12GraphicsCommandList* InCommandList, NVSDK_NGX_Parameter* InParameters) override;
    bool EvaluateInternal(ID3D12GraphicsCommandList* InCommandList, NVSDK_NGX_Parameter* InParameters) override;

  public:
    NSSFeatureDx12(unsigned int InHandleId, NVSDK_NGX_Parameter* InParameters);

    feature_version Version() override { return feature_version { 1, 0, 0 }; }
    Upscaler GetUpscalerType() const final { return Upscaler::NSS; }
    API Api() const override { return IFeature_Dx12::Api(); }
    bool CallsUpscalerEndByItself() override { return IFeature_Dx12::CallsUpscalerEndByItself(); }

    bool IsWithDx12() final { return false; }

    ~NSSFeatureDx12();
};
