#include "pch.h"
#include <Config.h>

#include "Reproject.h"

#include <numbers>

using namespace DirectX;

void Reproject::FilloutStruct(FilloutData data, ReprojectionParams& params)
{
                                                                              
                                                              
    if (_statsWritten[_statsSlot])
    {
        ProcessStats(_statsMapped[_statsSlot], _statsOrbit[_statsSlot], _statsFlip[_statsSlot]);
        _statsWritten[_statsSlot] = false;
    }

    auto negate = [](float* axis)
    {
        for (int i = 0; i < 3; i++)
            axis[i] = -axis[i];
    };

    if (_cameraFlip.right)
    {
        negate(data.cameraRight);
        negate(data.cameraPrevRight);
    }

    if (_cameraFlip.up)
    {
        negate(data.cameraUp);
        negate(data.cameraPrevUp);
    }

                                                                                               
    if (_cameraFlip.move)
    {
        negate(data.cameraPosition);
        negate(data.cameraPrevPosition);
    }

    params.ScreenWidth = data.screenWidth;
    params.ScreenHeight = data.screenHeight;
    params.InvScreenWidth = 1.0f / data.screenWidth;
    params.InvScreenHeight = 1.0f / data.screenHeight;

    params.DepthWidth = data.depthWidth;
    params.DepthHeight = data.depthHeight;

    params.UiDiffThreshold = data.diffThreshold;
    params.DepthCutoff = Config::Instance()->ReprojectionDepthCutoff.value_or_default();
    params.DitherWidthPx = data.screenHeight / 16.0f;                      
    params.CutoffExpandPx = Config::Instance()->ReprojectionCutoffExpand.value_or_default();

    params.InvertedDepth = data.invertedDepth;
    params.ShowStaticElements = State::Instance().fgHudlessCompare;
    params.FakeFrame = data.fakeFrame;

    auto fillMode = Config::Instance()->ReprojectionFillMode.value_or_default();
    if (fillMode == ReprojectionFill::Debug)
        params.EdgeMode = 0;
    else if (fillMode == ReprojectionFill::StrechEdge)
        params.EdgeMode = 1;
    else if (fillMode == ReprojectionFill::Dithering)
        params.EdgeMode = 2;
    else if (fillMode == ReprojectionFill::Noise)
        params.EdgeMode = 3;
    else if (fillMode == ReprojectionFill::SoftEdge)
        params.EdgeMode = 4;

    const float tanHalfFovY = std::tan(data.cameraVFov * 0.5f);
    const float pixelAngle = 2.0f * std::atan(tanHalfFovY / data.screenHeight);

    params.TanHalfFovY = tanHalfFovY;
    params.TanHalfFovX = tanHalfFovY * data.cameraAspectRatio;
    params.InvTanHalfFovY = 1.0f / tanHalfFovY;
    params.InvTanHalfFovX = 1.0f / params.TanHalfFovX;

                                                           
    if (!_isFirstFrame && !data.fakeFrame)
    {
        XMVECTOR prevFwd = XMVector3Normalize(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraPrevForward)));
        XMVECTOR currFwd = XMVector3Normalize(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraForward)));

        XMFLOAT3 p, c;
        XMStoreFloat3(&p, prevFwd);
        XMStoreFloat3(&c, currFwd);

                                           
        float camYawDelta = std::atan2(c.y, c.x) - std::atan2(p.y, p.x);

        if (camYawDelta > std::numbers::pi_v<float>)
            camYawDelta -= 2.0f * std::numbers::pi_v<float>;

        if (camYawDelta < -std::numbers::pi_v<float>)
            camYawDelta += 2.0f * std::numbers::pi_v<float>;

                      
        const float camPitchDelta = std::asin(std::clamp(c.z, -1.0f, 1.0f)) - std::asin(std::clamp(p.z, -1.0f, 1.0f));

        if (data.frameId != _calibrationFrameId)
        {
            _calibrationFrameId = data.frameId;

            std::shift_right(std::begin(_simDeltas), std::end(_simDeltas), 1);
            _simDeltas[0] = data.mouseDeltaSimToSim;

            for (uint32_t lag = 0; lag < InputLags; lag++)
            {
                _calibration[lag].Update(_simDeltas[lag].x * pixelAngle, _simDeltas[lag].y * pixelAngle, camYawDelta,
                                         camPitchDelta);
            }

                                                                                                           
            uint32_t bestLag = _inputLag;

            for (uint32_t lag = 0; lag < InputLags; lag++)
            {
                if (_calibration[lag].Fit() > _calibration[bestLag].Fit() + 0.1f)
                    bestLag = lag;
            }

            if (bestLag != _inputLag)
            {
                LOG_INFO("Camera input lag: {} simulations, fit: {:.2f}", bestLag, _calibration[bestLag].Fit());
                _inputLag = bestLag;
            }
        }
    }
    else
    {
        _isFirstFrame = false;
    }

                           
    XMVECTOR camRight = XMVector3Normalize(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraRight)));
    XMVECTOR camUp = XMVector3Normalize(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraUp)));
    XMVECTOR camForward = XMVector3Normalize(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraForward)));

    constexpr float TEST_ANGLE = 0.001f;

                                                                                  
    XMVECTOR testPitchForward =
        XMVector3Normalize(XMVector3TransformNormal(camForward, XMMatrixRotationAxis(camRight, TEST_ANGLE)));

    float pitchTest = std::asin(std::clamp(XMVectorGetZ(testPitchForward), -1.0f, 1.0f)) -
                      std::asin(std::clamp(XMVectorGetZ(camForward), -1.0f, 1.0f));

    int pitchSign = (pitchTest >= 0.0f) ? 1 : -1;

    XMVECTOR testYawForward = XMVector3Normalize(
        XMVector3TransformNormal(camForward, XMMatrixRotationAxis(XMVectorSet(0, 0, 1, 0), TEST_ANGLE)));

    float yawTest = std::atan2(XMVectorGetY(testYawForward), XMVectorGetX(testYawForward)) -
                    std::atan2(XMVectorGetY(camForward), XMVectorGetX(camForward));

    if (yawTest > std::numbers::pi_v<float>)
        yawTest -= 2.0f * std::numbers::pi_v<float>;

    if (yawTest < -std::numbers::pi_v<float>)
        yawTest += 2.0f * std::numbers::pi_v<float>;

    int yawSign = (std::abs(yawTest) >= 1e-8f && yawTest >= 0.0f) ? 1 : -1;

                                                                                          
    XMStoreFloat4(&params.CameraRight, camRight);
    XMStoreFloat4(&params.CameraUp, camUp);
    XMStoreFloat4(&params.CameraForward, camForward);
    const auto& calibration = _calibration[_inputLag];
    params.Calibration = { calibration.yawFromX, calibration.yawFromY, calibration.pitchFromX, calibration.pitchFromY };

    params.PixelAngle = pixelAngle;
    params.YawSign = (float) yawSign;
    params.PitchSign = (float) pitchSign;

    FilloutStats(data, params);

                                                                                                                  
    _bypass = _thirdPerson && Config::Instance()->ReprojectionThirdPersonDetection.value_or_default();

                                                                                                  
    XMINT2 mouseDeltaSinceSim = data.mouseDeltaSinceSim;
    XMINT2 simStartMouse = data.simStartMouse;

    for (uint32_t lag = 0; lag < _inputLag; lag++)
    {
        mouseDeltaSinceSim.x += _simDeltas[lag].x;
        mouseDeltaSinceSim.y += _simDeltas[lag].y;
        simStartMouse.x -= _simDeltas[lag].x;
        simStartMouse.y -= _simDeltas[lag].y;
    }

    params.LateLatch = (data.lateLatch && !_bypass) ? 1 : 0;
    params.MouseDelta = _bypass ? XMINT2 { 0, 0 } : mouseDeltaSinceSim;
    params.SimStartMouse = simStartMouse;

                                                                                                 
    params.CacheEnabled = (Config::Instance()->ReprojectionDirectionCache.value_or_default() && !_bypass) ? 1 : 0;

                                                                                                                 
    params.CacheSize = std::clamp((static_cast<uint32_t>(data.screenHeight * 0.7f) + 15u) & ~15u, 256u, 1024u);
    params.InvCacheSize = 1.0f / params.CacheSize;
    params.CacheDecay = 1.0f / 60.0f;                      
    params.CacheMaxDistance = 60000.0f;

                                                       
    const float camNear = std::min(data.cameraNear, data.cameraFar);
    const float camFar = std::max(data.cameraNear, data.cameraFar);
    const bool parallaxValid = std::isfinite(camNear) && camNear > 0.0f;

    params.CameraNear = parallaxValid ? camNear : 0.0f;
    params.CameraFar = (parallaxValid && std::isfinite(camFar) && camFar < 1e30f) ? camFar : 0.0f;

    _cacheUpdatePending = params.CacheEnabled && !data.fakeFrame && data.frameId != _cacheFrameId;

    if (!params.CacheEnabled)
        _cacheValid = false;

    if (_cacheUpdatePending)
    {
        _pendingCacheOrigin = { data.cameraPosition[0], data.cameraPosition[1], data.cameraPosition[2] };
        _pendingCacheFrameId = data.frameId;

        XMFLOAT3 move = { _pendingCacheOrigin.x - _cacheOrigin.x, _pendingCacheOrigin.y - _cacheOrigin.y,
                          _pendingCacheOrigin.z - _cacheOrigin.z };
        const float moveLength = XMVectorGetX(XMVector3Length(XMLoadFloat3(&move)));

                                                                                        
                                                                                              
        bool teleport = _cacheValid && _cacheMoveAverage > 0.0f && moveLength > 500.0f * _cacheMoveAverage;

        if (teleport)
            LOG_DEBUG("Cache reset, camera moved {} with an average of {}", moveLength, _cacheMoveAverage);
        else if (moveLength > 0.0f)
            _cacheMoveAverage = _cacheMoveAverage > 0.0f ? std::lerp(_cacheMoveAverage, moveLength, 0.1f) : moveLength;

                                                                                                               
                                                                                                                   
                                                                                                                  
        const float parallaxScale = ParallaxScale();

        if (parallaxValid && parallaxScale > 0.0f)
            params.CameraDelta = { move.x / parallaxScale, move.y / parallaxScale, move.z / parallaxScale, 0.0f };

        params.CacheReset = (data.reset || !_cacheValid || teleport) ? 1 : 0;

        LOG_TRACE("Cache update frame: {}, reset: {} (fg reset: {}), delta: {:.3f} {:.3f} {:.3f}, near: {}, far: {}",
                  data.frameId, params.CacheReset, data.reset, params.CameraDelta.x, params.CameraDelta.y,
                  params.CameraDelta.z, data.cameraNear, data.cameraFar);
    }
}

void Reproject::FilloutStats(const FilloutData& data, ReprojectionParams& params)
{
    _statsPending = false;

    if (data.fakeFrame || data.frameId == _statsFrameId)
        return;

    _statsFrameId = data.frameId;

    if (!data.hasMotionVectors || data.mvWidth == 0 || data.mvHeight == 0)
    {
                                                                            
        if (++_framesWithoutMvs > 60)
        {
            _hasStats = false;
            _thirdPerson = false;
            _lockedDetected = false;
            _orbitDetected = false;
            _thirdPersonScore = 0.0f;
            _orbitScore = 0.0f;
        }

        return;
    }

    _framesWithoutMvs = 0;

    if (!data.hasPrevCamera || data.reset)
        return;

    auto load = [](const float* v) { return XMVector3Normalize(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(v))); };

    const XMVECTOR right = load(data.cameraRight);
    const XMVECTOR up = load(data.cameraUp);
    const XMVECTOR forward = load(data.cameraForward);

    const XMVECTOR prevAxes[3] = { load(data.cameraPrevRight), load(data.cameraPrevUp), load(data.cameraPrevForward) };
    XMFLOAT4* rows[3] = { &params.PrevViewX, &params.PrevViewY, &params.PrevViewZ };

    const XMVECTOR move = XMVectorSubtract(XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraPosition)),
                                           XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(data.cameraPrevPosition)));
    float moveInView[3];

    for (int i = 0; i < 3; i++)
    {
        *rows[i] = { XMVectorGetX(XMVector3Dot(prevAxes[i], right)), XMVectorGetX(XMVector3Dot(prevAxes[i], up)),
                     XMVectorGetX(XMVector3Dot(prevAxes[i], forward)), 0.0f };

        moveInView[i] = XMVectorGetX(XMVector3Dot(prevAxes[i], move));
    }

    const bool moveValid = std::isfinite(moveInView[0]) && std::isfinite(moveInView[1]) && std::isfinite(moveInView[2]);
    const float parallaxScale = ParallaxScale();
    const float worldToDepth = (moveValid && parallaxScale > 0.0f) ? 1.0f / parallaxScale : 0.0f;

    params.PrevViewMove =
        moveValid ? XMFLOAT4 { moveInView[0], moveInView[1], moveInView[2], worldToDepth } : XMFLOAT4 {};

    params.MvToUv = { data.mvScaleX / data.mvWidth, data.mvScaleY / data.mvHeight };
    params.MvWidth = data.mvWidth;
    params.MvHeight = data.mvHeight;

    UpdateOrbitFit(data, parallaxScale);
    params.OrbitPivotDepth = _pendingOrbitPivotDepth;

    _statsPending = true;
}

void Reproject::UpdateOrbitFit(const FilloutData& data, float parallaxScale)
{
    auto load = [](const float* v) { return XMLoadFloat3(reinterpret_cast<const XMFLOAT3*>(v)); };
    auto axis = [&](const float* v) { return XMVector3Normalize(load(v)); };

                                                                                               
    const XMVECTOR columns[3] = { XMVectorSubtract(axis(data.cameraRight), axis(data.cameraPrevRight)),
                                  XMVectorSubtract(axis(data.cameraUp), axis(data.cameraPrevUp)),
                                  XMVectorSubtract(axis(data.cameraForward), axis(data.cameraPrevForward)) };

    const XMVECTOR move = XMVectorSubtract(load(data.cameraPosition), load(data.cameraPrevPosition));

    auto dot = [](XMVECTOR a, XMVECTOR b) { return XMVectorGetX(XMVector3Dot(a, b)); };

                                        
    constexpr float decay = 0.95f;
    constexpr float window = 1.0f / (1.0f - decay);

    _pendingOrbit = {};
    _pendingOrbitPivotDepth = 0.0f;

                                                                                                              
    const float moveSq = dot(move, move);
    if (_orbitBtb > 0.0f && moveSq > 100.0f * _orbitBtb / window)
    {
        std::memset(_orbitAtA, 0, sizeof(_orbitAtA));
        std::memset(_orbitAtb, 0, sizeof(_orbitAtb));
        _orbitBtb = 0.0f;
        return;
    }

    for (int i = 0; i < 3; i++)
    {
        for (int j = 0; j < 3; j++)
            _orbitAtA[i][j] = _orbitAtA[i][j] * decay + dot(columns[i], columns[j]);

        _orbitAtb[i] = _orbitAtb[i] * decay + dot(columns[i], move);
    }

    _orbitBtb = _orbitBtb * decay + moveSq;

                                                                   
    bool finite = std::isfinite(_orbitBtb);
    for (int i = 0; i < 3; i++)
        finite = finite && std::isfinite(_orbitAtb[i]) && std::isfinite(_orbitAtA[i][i]);

    if (!finite)
    {
        std::memset(_orbitAtA, 0, sizeof(_orbitAtA));
        std::memset(_orbitAtb, 0, sizeof(_orbitAtb));
        _orbitBtb = 0.0f;
        return;
    }

                                                                                  
    const float rotation = _orbitAtA[0][0] + _orbitAtA[1][1] + _orbitAtA[2][2];
    if (!(rotation > 1e-3f) || parallaxScale <= 0.0f)
        return;

    _pendingOrbit.rotating = true;

                                                                                                                 
    const float ridge = 1e-3f * rotation;
    const XMMATRIX ata(_orbitAtA[0][0] + ridge, _orbitAtA[0][1], _orbitAtA[0][2], 0.0f, _orbitAtA[1][0],
                       _orbitAtA[1][1] + ridge, _orbitAtA[1][2], 0.0f, _orbitAtA[2][0], _orbitAtA[2][1],
                       _orbitAtA[2][2] + ridge, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);

    XMVECTOR determinant;
    const XMMATRIX inverse = XMMatrixInverse(&determinant, ata);

                                                                           
    const XMVECTOR atb = XMVectorSet(_orbitAtb[0], _orbitAtb[1], _orbitAtb[2], 0.0f);
    const XMVECTOR offset = XMVector3TransformNormal(atb, inverse);

    const float offsetLength = XMVectorGetX(XMVector3Length(offset));
    const float fit = _orbitBtb > 0.0f ? dot(offset, atb) / _orbitBtb : 0.0f;
    _pendingOrbit.fit = fit;
    XMStoreFloat3(&_pendingOrbit.offset, offset);

                                                                                              
                                                       
    float cameraNear = std::min(data.cameraNear, data.cameraFar);
    if (!std::isfinite(cameraNear) || cameraNear <= 0.0f)
        cameraNear = 1e-4f;

    if (std::sqrt(_orbitBtb) / parallaxScale < cameraNear)
    {
        _pendingOrbit.still = true;
        return;
    }

                                                                                             
                                                                                                    
                                                           
    const bool behind = _pendingOrbit.offset.z < -0.7f * offsetLength;

    if (fit >= 0.9f && behind && std::isfinite(offsetLength))
    {
        _pendingOrbit.orbiting = true;
        _pendingOrbitPivotDepth = offsetLength / parallaxScale;
    }
}

float Reproject::ParallaxScale() const
{
    if (Config::Instance()->ReprojectionParallaxAuto.value_or_default())
        return _parallaxEstimate;

    return Config::Instance()->ReprojectionParallaxScale.value_or_default();
}

void Reproject::ProcessStats(const uint32_t* stats, const OrbitSample& orbit, const CameraFlip& flip)
{
                                                         
    const uint32_t* counters = stats + StatsBins;
    const uint32_t centerSamples = counters[0];
    const uint32_t centerValid = counters[1];
    const uint32_t centerLocked = counters[2];
    const uint32_t outerValid = counters[3];
    const uint32_t outerConsistent = counters[4];
    const uint32_t centerAtPivot = counters[5];
    const uint32_t outerXValid = counters[6];
    const uint32_t outerXOpposite = counters[7];
    const uint32_t outerYValid = counters[8];
    const uint32_t outerYOpposite = counters[9];
    const uint32_t moveAlong = counters[10];
    const uint32_t moveAgainst = counters[11];

                                                                                              
    if (flip != _cameraFlip)
        return;

                                                         
    if (outerValid >= 64)
        _mvTrust = std::lerp(_mvTrust, (float) outerConsistent / outerValid, 0.1f);

    if (outerXValid >= 64)
        _mvOppositeX = std::lerp(_mvOppositeX, (float) outerXOpposite / outerXValid, 0.1f);

    if (outerYValid >= 64)
        _mvOppositeY = std::lerp(_mvOppositeY, (float) outerYOpposite / outerYValid, 0.1f);

                                                                                                              
    if (_mvTrust >= 0.35f && moveAlong + moveAgainst >= 100)
        _moveOpposite = std::lerp(_moveOpposite, (float) moveAgainst / (moveAlong + moveAgainst), 0.1f);

                                                                                                               
                                                                                                         
    const bool flipRight = _mvOppositeX > 0.6f;
    const bool flipUp = _mvOppositeY > 0.6f;
    const bool flipMove = _moveOpposite > 0.6f;

    if (flipRight || flipUp || flipMove)
    {
        if (flipRight)
        {
            _cameraFlip.right = !_cameraFlip.right;
            _mvOppositeX = 0.0f;
        }

        if (flipUp)
        {
            _cameraFlip.up = !_cameraFlip.up;
            _mvOppositeY = 0.0f;
        }

        if (flipMove)
            _cameraFlip.move = !_cameraFlip.move;

                                                              
                                                                                                                    
                                                                                 
        _mvTrust = 0.0f;
        _moveOpposite = 0.0f;
        std::fill(std::begin(_parallaxHistogram), std::end(_parallaxHistogram), 0.0f);
        _parallaxFrames = 0;
        _cacheValid = false;
        std::memset(_orbitAtA, 0, sizeof(_orbitAtA));
        std::memset(_orbitAtb, 0, sizeof(_orbitAtb));
        _orbitBtb = 0.0f;

        LOG_INFO("Camera right is {}, up is {} on the screen, movement is {}",
                 _cameraFlip.right ? "turned around" : "as given", _cameraFlip.up ? "turned around" : "as given",
                 _cameraFlip.move ? "turned around" : "as given");

        return;
    }

                                                                                                     
                                                                                       
    if (_mvTrust < 0.35f)
    {
        _hasStats = false;
        _thirdPerson = false;
        _lockedDetected = false;
        _orbitDetected = false;
        return;
    }

    _hasStats = true;

    static constexpr int window = 2;
    static constexpr int lastBin = (int) StatsBins - 1;

    auto findPeak = [](const auto& bins, float& peakMass)
    {
        int peak = -1;
        peakMass = 0.0f;

        for (int i = 0; i <= lastBin; i++)
        {
            float mass = 0.0f;
            for (int j = std::max(i - window, 0); j <= std::min(i + window, lastBin); j++)
                mass += (float) bins[j];

            if (mass > peakMass)
            {
                peakMass = mass;
                peak = i;
            }
        }

        return peak;
    };

                                                                                           
                                                                                                               
                                                                                                              
                                                                                                                
    float frameVotes = 0.0f;
    for (uint32_t i = 0; i < StatsBins; i++)
        frameVotes += stats[i];

    float framePeakMass = 0.0f;
    findPeak(stats, framePeakMass);

    if (frameVotes >= 100.0f && framePeakMass >= 0.3f * frameVotes)
    {
        for (uint32_t i = 0; i < StatsBins; i++)
            _parallaxHistogram[i] = _parallaxHistogram[i] * 0.98f + stats[i];

        _parallaxFrames++;
    }

    float total = 0.0f;
    for (uint32_t i = 0; i < StatsBins; i++)
        total += _parallaxHistogram[i];

    float peakMass = 0.0f;
    const int peak = findPeak(_parallaxHistogram, peakMass);

                                                                                       
                                                                                                          
    if (peak >= 0 && _parallaxFrames >= 10 && peakMass >= 0.3f * total)
    {
        float weighted = 0.0f;
        for (int j = std::max(peak - window, 0); j <= std::min(peak + window, lastBin); j++)
            weighted += _parallaxHistogram[j] * j;

        const float bin = weighted / peakMass + 0.5f;
        const float logScale = StatsLogScaleMin + bin * (StatsLogScaleMax - StatsLogScaleMin) / StatsBins;
        const float estimate = std::pow(10.0f, logScale);

        if (_parallaxEstimate == 0.0f)
            LOG_INFO("Parallax scale estimate: {}", estimate);

        _parallaxEstimate = estimate;
    }

                                                                                                                      

                                                                                                                  
                                                                                                            
                                     
    if (centerValid >= 32)
    {
        const float locked = (float) centerLocked / centerValid;
        const bool fullView = centerValid >= 0.85f * centerSamples;

        float score = _thirdPersonScore;
        if (locked > score || fullView)
            score = std::lerp(score, locked, 0.08f);

        _thirdPersonScore = score;
                                                                                                
                                                                                             
        _lockedDetected = _lockedDetected ? score > 0.015f : score > 0.04f;
    }

                                                                                                             
                                                                                                  
                                                                                             
    if (orbit.rotating && centerSamples >= 32)
    {
        float target = 0.0f;
        float rate = 0.05f;

        if (orbit.orbiting)
            target = centerAtPivot >= 0.15f * centerSamples ? 1.0f : 0.0f;
        else if (!orbit.still)
            rate = 0.002f;                                                                                         

        const float score = std::lerp(_orbitScore.load(), target, rate);

        _orbitScore = score;
        _orbitDetected = _orbitDetected ? score > 0.3f : score > 0.6f;
    }

    const bool detected = _lockedDetected || _orbitDetected;

    if (detected != _thirdPerson)
    {
        LOG_INFO("3rd person {}, score: {:.3f}, orbit score: {:.3f}", detected ? "detected" : "no longer detected",
                 _thirdPersonScore.load(), _orbitScore.load());
    }

    _thirdPerson = detected;

    LOG_TRACE("Stats center: {}/{}/{}, at pivot: {}, outer: {}/{}, mv trust: {:.2f}, orbit: {}{}{} fit {:.2f} "
              "offset {:.2f} {:.2f} {:.2f}, "
              "3rd person score: {:.3f}, orbit score: {:.3f}, parallax votes: {:.0f} (frame {:.0f}), "
              "move against: {}/{} ({:.2f}), opposite x: {}/{} y: {}/{} ({:.2f} {:.2f}), scale: {}",
              centerLocked, centerValid, centerSamples, centerAtPivot, outerConsistent, outerValid, _mvTrust,
              orbit.rotating ? "R" : "-", orbit.orbiting ? "O" : "-", orbit.still ? "S" : "-", orbit.fit,
              orbit.offset.x, orbit.offset.y, orbit.offset.z, _thirdPersonScore.load(), _orbitScore.load(), total,
              frameVotes, moveAgainst, moveAlong + moveAgainst, _moveOpposite, outerXOpposite, outerXValid,
              outerYOpposite, outerYValid, _mvOppositeX, _mvOppositeY, _parallaxEstimate.load());
}

Reproject::DispatchPlan Reproject::PlanDispatch(ReprojectionParams& params, bool cacheReady, bool hasVelocity)
{
    DispatchPlan plan {};
    plan.cacheUpdate = cacheReady && _cacheUpdatePending;

                                                  
    params.CacheEnabled = (cacheReady && (_cacheValid || plan.cacheUpdate)) ? 1 : 0;

    if (plan.cacheUpdate && !_cacheValid)
        params.CacheReset = 1;

                                                                                              
    plan.prevCache = _cacheIndex;
    plan.newestCache = plan.cacheUpdate ? 1 - _cacheIndex : _cacheIndex;

    plan.statsUpdate = _statsPending && hasVelocity;
    plan.statsSlot = _statsSlot;
    _statsPending = false;

    return plan;
}

void Reproject::PlanRecorded(const DispatchPlan& plan)
{
    if (plan.statsUpdate)
    {
        _statsWritten[_statsSlot] = true;
        _statsOrbit[_statsSlot] = _pendingOrbit;
        _statsFlip[_statsSlot] = _cameraFlip;
        _statsSlot = (_statsSlot + 1) % StatsLatency;
    }

    if (plan.cacheUpdate)
    {
        _cacheIndex = plan.newestCache;
        _cacheValid = true;
        _cacheOrigin = _pendingCacheOrigin;
        _cacheFrameId = _pendingCacheFrameId;
        _cacheUpdatePending = false;
    }
}
