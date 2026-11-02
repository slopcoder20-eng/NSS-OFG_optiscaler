#pragma once

#include "SysUtils.h"

#include <DirectXMath.h>
#include <atomic>

#include "mouseInputs/InputCollection.h"

struct alignas(16) ReprojectionParams
{
    uint32_t ScreenWidth;
    uint32_t ScreenHeight;
    float InvScreenWidth;
    float InvScreenHeight;

    uint32_t DepthWidth;
    uint32_t DepthHeight;
    float _Pad0[2];

    float UiDiffThreshold;
    float DepthCutoff;
    float DitherWidthPx;
    uint32_t CutoffExpandPx;

    uint32_t EdgeMode;
    uint32_t ShowStaticElements;
    uint32_t InvertedDepth;
    uint32_t FakeFrame;                               

    float TanHalfFovX;
    float TanHalfFovY;
    float InvTanHalfFovX;
    float InvTanHalfFovY;

                                                                                  
    DirectX::XMFLOAT4 CameraRight;                     
    DirectX::XMFLOAT4 CameraUp;                        
    DirectX::XMFLOAT4 CameraForward;                   
    DirectX::XMFLOAT4 Calibration;                                                

    float PixelAngle;
    float YawSign;
    float PitchSign;
    uint32_t LateLatch;                                                                                 

    DirectX::XMINT2 MouseDelta;                                                       
    DirectX::XMINT2 SimStartMouse;                                                       

                                                
    DirectX::XMFLOAT4 CameraDelta;                                                                              

    float CameraNear;
    float CameraFar;                
    uint32_t CacheSize;
    float InvCacheSize;

    uint32_t CacheEnabled;
    uint32_t CacheReset;
    float CacheDecay;                                                                          
    float CacheMaxDistance;                               

                                                         
    DirectX::XMFLOAT4 PrevViewX;                                                                            
    DirectX::XMFLOAT4 PrevViewY;
    DirectX::XMFLOAT4 PrevViewZ;
    DirectX::XMFLOAT4 PrevViewMove;                                                                              
                                                                                                            

    DirectX::XMFLOAT2 MvToUv;                                                    
    uint32_t MvWidth;
    uint32_t MvHeight;

    float OrbitPivotDepth;                                                                                    
    float _Pad1[3];
};

                                                                  
struct alignas(16) ReprojectionLiveInput
{
    DirectX::XMINT2 Mouse;                                            
    uint32_t _Pad0[2];
};

struct FilloutData
{
    float diffThreshold;
    uint32_t screenWidth;
    uint32_t screenHeight;
    uint32_t depthWidth;
    uint32_t depthHeight;
    bool invertedDepth;
    bool fakeFrame;

    float cameraVFov;
    float cameraAspectRatio;
    float cameraUp[3];
    float cameraRight[3];
    float cameraForward[3];
    float cameraPrevForward[3];
    float cameraPosition[3];

                                                                
    bool hasPrevCamera = false;
    float cameraPrevUp[3];
    float cameraPrevRight[3];
    float cameraPrevPosition[3];
    float cameraNear;
    float cameraFar;

    uint64_t frameId;                                               
    bool reset;

                                                                                         
    bool hasMotionVectors = false;
    float mvScaleX;                                                        
    float mvScaleY;
    uint32_t mvWidth;
    uint32_t mvHeight;

    DirectX::XMINT2 mouseDeltaSinceSim;                    
    DirectX::XMINT2 mouseDeltaSimToSim;                   

                                                                                                            
    bool lateLatch = false;
    DirectX::XMINT2 simStartMouse {};
};

struct CalibrationState
{
    float Sxx = 0.0f, Sxy = 0.0f, Syy = 0.0f;
    float BxYaw = 0.0f, ByYaw = 0.0f;
    float BxPitch = 0.0f, ByPitch = 0.0f;
    float Syaw = 0.0f, Spitch = 0.0f;

    float yawFromX = 1.0f, yawFromY = 0.0f;
    float pitchFromX = 0.0f, pitchFromY = 1.0f;
    int sampleCount = 0;

    void Reset() { *this = CalibrationState {}; }

                                                                                        
    float Fit() const
    {
        const float total = Syaw + Spitch;

        if (sampleCount < 20 || !(total > 0.0f))
            return 0.0f;

        return (yawFromX * BxYaw + yawFromY * ByYaw + pitchFromX * BxPitch + pitchFromY * ByPitch) / total;
    }

    void Update(float mx, float my, float camYawDelta, float camPitchDelta)
    {
        if (mx * mx + my * my < 1e-12f)
            return;

        constexpr float DECAY = 0.99f;

        Sxx = Sxx * DECAY + mx * mx;
        Sxy = Sxy * DECAY + mx * my;
        Syy = Syy * DECAY + my * my;

        BxYaw = BxYaw * DECAY + mx * camYawDelta;
        ByYaw = ByYaw * DECAY + my * camYawDelta;
        BxPitch = BxPitch * DECAY + mx * camPitchDelta;
        ByPitch = ByPitch * DECAY + my * camPitchDelta;
        Syaw = Syaw * DECAY + camYawDelta * camYawDelta;
        Spitch = Spitch * DECAY + camPitchDelta * camPitchDelta;

        sampleCount++;

        const float det = Sxx * Syy - Sxy * Sxy;
        if (std::abs(det) >= 1e-10f && sampleCount >= 20)
        {
            const float invDet = 1.0f / det;
            yawFromX = std::clamp((BxYaw * Syy - ByYaw * Sxy) * invDet, -1.5f, 1.5f);
            yawFromY = std::clamp((ByYaw * Sxx - BxYaw * Sxy) * invDet, -1.5f, 1.5f);
            pitchFromX = std::clamp((BxPitch * Syy - ByPitch * Sxy) * invDet, -1.5f, 1.5f);
            pitchFromY = std::clamp((ByPitch * Sxx - BxPitch * Sxy) * invDet, -1.5f, 1.5f);
        }
    }
};

                                                                                                               
                                                                                       
                                                                               
class Reproject
{
  protected:
                                                                                  
                                                                                                           
    static constexpr uint32_t StatsBins = 128;
    static constexpr uint32_t StatsCounters = 12;
    static constexpr uint32_t StatsCount = StatsBins + StatsCounters;
    static constexpr float StatsLogScaleMin = -3.0f;
    static constexpr float StatsLogScaleMax = 6.0f;
    static constexpr uint32_t StatsLatency = 8;

                                                                        
    const uint32_t* _statsMapped[StatsLatency] = {};

    bool _cacheValid = false;

                                     
    struct DispatchPlan
    {
        bool cacheUpdate = false;
        uint32_t prevCache = 0;                              
        uint32_t newestCache = 0;                                                         
        bool statsUpdate = false;
        uint32_t statsSlot = 0;                                         
    };

                                                                
                                                   
    DispatchPlan PlanDispatch(ReprojectionParams& params, bool cacheReady, bool hasVelocity);

                                                 
    void PlanRecorded(const DispatchPlan& plan);

  private:
    uint32_t _statsSlot = 0;
    bool _statsWritten[StatsLatency] = {};
    uint64_t _statsFrameId = UINT64_MAX;
    bool _statsPending = false;                                                 
    uint32_t _framesWithoutMvs = 0;

                                                                    
    struct OrbitSample
    {
        bool rotating = false;                                                           
        bool orbiting = false;                                                                
        bool still = false;                                                             
        float fit = 0.0f;                                                                           
        DirectX::XMFLOAT3 offset {};                                                                              
    };

    OrbitSample _pendingOrbit;
    float _pendingOrbitPivotDepth = 0.0f;
    OrbitSample _statsOrbit[StatsLatency];

                                                                                                              
    struct CameraFlip
    {
        bool right = false;
        bool up = false;
                                                                                                  
                                                                                                            
        bool move = false;

        bool operator==(const CameraFlip&) const = default;
    };

    CameraFlip _cameraFlip;
    CameraFlip _statsFlip[StatsLatency];                                                   

                                                                                                                 
                                                                                       
    float _orbitAtA[3][3] = {};
    float _orbitAtb[3] = {};
    float _orbitBtb = 0.0f;

    float _parallaxHistogram[StatsBins] = {};
    std::atomic<float> _parallaxEstimate = 0.0f;                     
    uint32_t _parallaxFrames = 0;                                                                    

    float _mvTrust = 0.0f;                                                                    
    float _mvOppositeX = 0.0f;                                                                             
    float _mvOppositeY = 0.0f;
    float _moveOpposite = 0.0f;                                                                            
    std::atomic<float> _thirdPersonScore = 0.0f;                                                                
    std::atomic<float> _orbitScore = 0.0f;                                                   
    bool _lockedDetected = false;
    bool _orbitDetected = false;
    std::atomic<bool> _thirdPerson = false;
    std::atomic<bool> _hasStats = false;
    bool _bypass = false;                                                    

                                            
    uint32_t _cacheIndex = 0;                                
    DirectX::XMFLOAT3 _cacheOrigin {};
    uint64_t _cacheFrameId = UINT64_MAX;
    float _cacheMoveAverage = 0.0f;                                                      

                                                    
    bool _cacheUpdatePending = false;
    DirectX::XMFLOAT3 _pendingCacheOrigin {};
    uint64_t _pendingCacheFrameId = 0;

                                                                                                     
                                                                          
    static constexpr uint32_t InputLags = 3;
    CalibrationState _calibration[InputLags];
    uint32_t _inputLag = 0;
    DirectX::XMINT2 _simDeltas[InputLags] {};                                                                   
    uint64_t _calibrationFrameId = UINT64_MAX;
    bool _isFirstFrame = true;

    void ProcessStats(const uint32_t* stats, const OrbitSample& orbit, const CameraFlip& flip);
    void UpdateOrbitFit(const FilloutData& data, float parallaxScale);
    void FilloutStats(const FilloutData& data, ReprojectionParams& params);

  public:
    void FilloutStruct(FilloutData data, ReprojectionParams& params);

                                                                                          
    float ParallaxScaleEstimate() const { return _parallaxEstimate; }

                                                                     
    float ParallaxScale() const;

                                                                                               
    bool ThirdPersonDetected() const { return _thirdPerson; }
    float ThirdPersonScore() const { return _thirdPersonScore; }
    float OrbitScore() const { return _orbitScore; }

                                                        
    bool HasMotionStats() const { return _hasStats; }

                                                                                 
    bool IsBypassed() const { return _bypass; }

    virtual ~Reproject() = default;
};
