#pragma once

#include <algorithm>
#include <cmath>

                                                                                                                   
                                                                                                                  
                                                                                     
  
                                                                                                                   
                                                               
  
                                                                                                                 
                                                                                                                   
                                                                                        
                                                                                                                   
                             
                                                                                                         
                                                                        
                                                                                                                  
                                                                                                                      
                                                                                                                    
                                                                                                                     
                                                                                                                      
                                                                                                                      
                                                                                                                   
                                                                                                                     
                 
  
                                                                                          
                                                                                                                     
                                                                                                                    
                                                              
                                                                                                        
                                                            
                                                                         
                                                                                                                 
                                                                                                                  
                                                                                                                 
                                                                  
                                                                                                                   
                                                                                                                   
                                                                                                                     
                                                                                               
                                                                                                                     
                                                                                                             
                                                                                                                   
                                                                                                            
                                                                                                                  
                                                                                                                  
                                
                                                                                                                  
                                                                                                                    
                                                                                                             
                                                                                                                  
                                                                                         
                                                                                                               
                       
                                                                                                                 
                                                                                                                   
                                                                    
class XeFG_DynamicCount
{
  public:
    struct Sample
    {
        double nowMs = 0.0;                        
        double frameMs = 0.0;                          
        double waitMs = 0.0;                                                                                           
        double targetFps = 0.0;                                       
        double refreshFps = 0.0;                                                        
        double limitFps = 0.0;                                       
        int maxCount = 1;                                           
        int currentCount = 1;                                 
        int rounding = 1;                                            
        int minCount = 1;                                                                         
    };

    enum class Rounding
    {
        Down,
        Nearest,
        Up
    };

    enum class Reason
    {
        None,
        Up,
        Down,
        Probe,
        Undo,
        Capped
    };

    int Update(const Sample& s)
    {
        _reason = Reason::None;
        const int maxCount = std::max(s.maxCount, 1);
        const int minCount = std::clamp(s.minCount, 0, 1);
        const int count = std::clamp(s.currentCount, minCount, maxCount);

                                                                                      
        if (s.targetFps <= 0.0 || s.frameMs <= 0.0 || s.frameMs > 250.0)
            return count;

                                                                                                      
        if (_frameMs > 0.0 && s.frameMs > _frameMs * kHitchFactor && _hitchRun < kMaxHitchRun)
        {
            ++_hitchRun;
            return count;
        }
        _hitchRun = 0;

        const double nowMs = s.nowMs;
        const double work = std::max(s.frameMs - std::clamp(s.waitMs, 0.0, s.frameMs), 0.5);

                                                                                             
        const int rounding = std::clamp(s.rounding, 0, 2);
        _offset = rounding == (int) Rounding::Down ? 0.5 : rounding == (int) Rounding::Up ? -0.5 : 0.0;

                                                                
        if (std::abs(s.targetFps - _goalFps) > _goalFps * 0.03 || rounding != _goalRounding)
        {
            _goalFps = s.targetFps;
            _goalRounding = rounding;
            for (auto& step : _steps)
                step = Step {};
            _upBackoffMs = kMinBackoffMs;
            _upBlockedUntilMs = 0.0;
        }

        if (_frameMs <= 0.0)
        {
            _frameMs = s.frameMs;
            _workMs = work;

                                                                      
            if (_fresh)
                _lastChangeMs = nowMs;

            _fresh = false;
        }
        else
        {
            _frameMs += kAlpha * (s.frameMs - _frameMs);
            _workMs += kAlpha * (work - _workMs);
        }

        const double presented = 1000.0 * (count + 1) / _frameMs;
                                                                                                                     
        const bool toOff = count == 1;
        const double saved = toOff && _offSamples > 0 ? _offMs : _genMs;
        const double lower = count * 1000.0 / std::max(_workMs - saved, 0.5);
        const double waitShare = 1.0 - _workMs / _frameMs;
        const double sinceChange = nowMs - _lastChangeMs;
        const auto atCap = [presented](double cap)
        { return cap > 0.0 && presented >= cap * 0.97 && presented <= cap * 1.03; };

                                                                                                                 
        if (_capFps > 0.0 && (presented > _capFps * 1.05 || nowMs >= _capUntilMs))
            _capFps = 0.0;

        double target = s.targetFps;
        if (_capFps > 0.0)
            target = std::min(target, _capFps);
        if (atCap(s.refreshFps))
            target = std::min(target, s.refreshFps);

        const bool hidden = waitShare < kHiddenWaitShare &&
                            (atCap(target) || atCap(s.targetFps) || atCap(s.refreshFps) || atCap(s.limitFps));

        _presented = presented;
        _lower = lower;
        _target = target;
        _waitShare = waitShare;

                                                                                                                   
                                                                                                                   
                       
        if (Capped(presented, waitShare, s) || hidden)
            _cappedUntilMs = nowMs + kCapMemoryMs;

        if (const bool free = nowMs >= _cappedUntilMs; free != _free)
        {
            _free = free;
            _lowSinceMs = -1.0;
            _downHold = Hold {};
            _tryHold = Hold {};
            _upHold = Hold {};
        }

                                                                                                                     
                     
        if (_check != Check::None)
        {
            if (++_checkFrames > kCheckSkipFrames)
            {
                _checkSumMs += s.frameMs;
                _checkWorkSumMs += work;
                ++_checkCount;
            }

            const bool enough = _checkCount >= kCheckMinFrames && sinceChange >= kCheckMinMs;
            const bool end = enough && nowMs >= _checkUntilMs;
            const double mean = enough ? 1000.0 * (count + 1) * _checkCount / _checkSumMs : 0.0;

            if (_checkFree)
            {
                                                                                                                    
                                                                                                                     
                                                                                                                      
                                   
                const double before = Miss(_checkBefore, s.targetFps, rounding);
                const double after = enough ? Miss(mean, s.targetFps, rounding) : 0.0;
                const bool unreached = _checkBefore < s.targetFps * kReached;
                const bool capped = enough && Capped(mean, 1.0 - _checkWorkSumMs / _checkSumMs, s);
                bool good = false;
                bool bad = false;

                                                                                                                   
                                                                                    
                const bool held =
                    _check == Check::Down && mean >= _checkBefore * 0.99 && _checkExpected < _checkBefore * 0.9;

                if (_check == Check::Down)
                {
                    const double share = 1.0 / (count + 2);
                    const bool keeps = unreached && mean >= _checkBefore * (1.0 - kWorth * share);
                    good = held || keeps || after < before;
                    bad = !held && after > before + kNearMargin &&
                          !(unreached && mean >= _checkBefore * (1.0 - 0.7 * share));
                }
                else
                {
                    good = after < before && mean >= _checkBefore * (1.0 + kWorth / count);
                    bad = after > before + kNearMargin;
                }

                if (enough && (bad || (end && !good)))
                {
                    LearnFree(count, capped);

                    if (_check == Check::Down && count < maxCount)
                    {
                        FailedDown(count + 1, nowMs, !end, _checkBefore);
                        return Change(count + 1, nowMs, Reason::Undo, Check::None, presented);
                    }

                    if (_check == Check::Up && count > minCount)
                    {
                        BlockUp(nowMs);
                        return Change(count - 1, nowMs, Reason::Undo, Check::None, presented);
                    }
                }

                if (!end)
                    return count;

                                                                                                                  
                         
                if (held)
                    LearnCap(mean, nowMs);
                else
                    LearnFree(count, capped);

                if (_check == Check::Down)
                    DownHeld(count);
                else
                    UpHeld(count, mean, nowMs);
            }
            else if (_check == Check::Down)
            {
                                                                                                                 
                                                                                                                     
                                                                                  
                const bool unreached = _checkBefore < s.targetFps * kReached;
                const double share = 1.0 / (count + 2);
                const double pass = unreached ? _checkBefore * (1.0 - kWorth * share)
                                              : target * std::min(DownShare(count + 1), kReached);
                const double fail = unreached ? _checkBefore * (1.0 - 0.7 * share) : pass * 0.95;

                if (enough && count < maxCount && (mean < fail || (end && mean < pass)))
                {
                    Learn(count, mean);
                                                                                                  
                    FailedDown(count + 1, nowMs, mean < pass * 0.85 || !end, _checkBefore);
                    return Change(count + 1, nowMs, Reason::Undo, Check::None, presented);
                }

                if (!end)
                    return count;

                Learn(count, mean);
                DownHeld(count);

                if (unreached)
                    LearnCap(mean, nowMs);
            }
            else
            {
                                                                                                                 
                                       
                const double share = 1.0 / count;

                if (!(enough && mean >= _checkBefore * (1.0 + share * 0.5)))
                {
                    if (!end)
                        return count;

                    if (mean < _checkBefore * (1.0 + share * kWorth))
                    {
                        LearnCap(_checkBefore, nowMs);
                        BlockUp(nowMs);
                        return Change(count - 1, nowMs, Reason::Capped, Check::None, presented);
                    }
                }

                Learn(count, mean);
                UpHeld(count, mean, nowMs);
            }

            _check = Check::None;
        }

        if (_free)
            return Free(s, count, minCount, maxCount, rounding, presented, nowMs, sinceChange);

                                                                                                                  
                                                                   
                                                                                                                       
                                                                                                                    
                   
        Step& down = StepFrom(count);
        const bool knownBad = nowMs < down.blockedUntilMs && presented <= down.failFps * kLighter;
        _shownBackoffMs = down.backoffMs;

                                                                                             
        const bool upBlocked = nowMs < _upBlockedUntilMs && presented >= _upBlockedFps * 0.9;

        if (count < maxCount && presented < target * HoldShare(count) && !upBlocked)
        {
            if (_lowSinceMs < 0.0)
                _lowSinceMs = nowMs;

            if (nowMs - _lowSinceMs >= kHoldUpMs && sinceChange >= kMinUpGapMs)
            {
                                                                                   
                if (_lastDownMs >= 0.0 && nowMs - _lastDownMs < kDownHoldsMs && _lastDownFrom == count + 1)
                    FailedDown(count + 1, nowMs, false, _lastDownBefore);

                return Change(count + 1, nowMs, Reason::Up, Check::Up, presented);
            }
        }
        else
        {
            _lowSinceMs = -1.0;
        }

                                                                                                                   
                                                                               
        const bool capTest = count == maxCount && presented < target * HoldShare(count) && waitShare < kHiddenWaitShare;

        if (count <= minCount)
            return count;

                                                                                                                   
                                 
        const bool canDown = sinceChange >= kMinDownGapMs && (presented >= target * HoldShare(count) || capTest);
        const double needed = target * DownShare(count);                           

                                                                                                                      
        if (Held(_downHold, canDown && !capTest && !knownBad && lower >= needed, nowMs) >= kHoldDownMs)
        {
            return Change(count - 1, nowMs, Reason::Down, Check::Down, presented);
        }

                                                                                                                     
                                                                                                                   
                                                                         
        const bool costKnown = (toOff ? _offSamples : _genSamples) > 0;
        const double tryShare = costKnown ? kTryShareLearned : kTryShare;
        const bool unreached = presented < s.targetFps * kReached;

                                                                                                                 
                                                                                                          
        const double keep = presented * (1.0 - kWorth / (count + 1)) * kTryShareLearned;
        const bool worthTry = unreached && (!costKnown || hidden || lower >= keep);
        const bool tryDown = canDown && (capTest || hidden || worthTry || lower >= needed * tryShare);

                                                                                                                     
                                                   
        const bool heldAtCap = atCap(target) || atCap(s.limitFps) || atCap(s.refreshFps);
        const bool capProbe = canDown && heldAtCap && waitShare < kUnseenWaitShare && sinceChange >= kCapProbeMs;

        if (Held(_tryHold, (tryDown || capProbe) && !knownBad, nowMs) >= std::min(down.backoffMs, kTryHoldMs) &&
            sinceChange >= down.backoffMs)
        {
            return Change(count - 1, nowMs, Reason::Probe, Check::Down, presented);
        }

        return count;
    }

                                               
    void Reset() { *this = XeFG_DynamicCount {}; }

                                                                                  
    void Restart()
    {
        _frameMs = 0.0;
        _workMs = 0.0;
        _lowSinceMs = -1.0;
        _downHold = Hold {};
        _tryHold = Hold {};
        _upHold = Hold {};
        _lastDownMs = -1.0;
        _check = Check::None;
        _fresh = true;
        _hitchRun = 0;
    }

    Reason LastReason() const { return _reason; }

                                               
    double PresentedFps() const { return _presented; }
    double LowerFps() const { return _lower; }                                            
    double TargetFps() const { return _target; }
    double WaitShare() const { return _waitShare; }
    bool Uncapped() const { return _free; }                                                                 

                                             
    double FrameCostMs() const { return _free && _freeGenSamples > 0 ? _freeGenMs : _genMs; }
    double BackoffMs() const { return _shownBackoffMs; }                                           

  private:
    enum class Check
    {
        None,
        Down,
        Up
    };

                                                                      
    struct Hold
    {
        double sinceMs = -1.0;
        double lastMs = -1.0;
    };

    static constexpr double kAlpha = 0.1;
    static constexpr double kHysteresis = 0.8;          
    static constexpr double kReached = 0.97;                                                   
    static constexpr double kHoldUpMs = 300.0;
    static constexpr double kHoldDownMs = 1000.0;
    static constexpr double kLighter = 1.08;                                                                       
    static constexpr double kUpHoldsMs = 20000.0;                                                                   
    static constexpr double kGraceMs = 300.0;
    static constexpr double kMinUpGapMs = 500.0;
    static constexpr double kMinDownGapMs = 1500.0;                                
    static constexpr int kCheckSkipFrames = 3;                                                                   
    static constexpr int kCheckMinFrames = 6;
    static constexpr double kCheckMinMs = 400.0;
    static constexpr double kCheckMs = 1500.0;
    static constexpr double kDownHoldsMs = 10000.0;
    static constexpr double kTryShare = 0.75;
    static constexpr double kTryShareLearned = 0.95;
    static constexpr double kWorth = 0.3;                                                                         
    static constexpr double kHiddenWaitShare = 0.05;                                                             
    static constexpr double kCapRetestMs = 20000.0;
    static constexpr double kMinBackoffMs = 3000.0;
    static constexpr double kMaxBackoffMs = 60000.0;
    static constexpr double kNearMargin = 0.03;                                                                      
    static constexpr double kSideMargin = 0.01;                                                             
    static constexpr double kAtMost = 1.03;                                                                         
    static constexpr double kLimitNear = 1.1;                                                                           
    static constexpr double kCapMemoryMs = 2000.0;                                                 
    static constexpr double kHitchFactor = 2.5;                                                           
    static constexpr int kMaxHitchRun = 2;                                           
    static constexpr double kTryHoldMs = 3000.0;                                               
    static constexpr double kCapProbeMs = 15000.0;                                                                 
    static constexpr double kUnseenWaitShare = 0.15;                                                              

                                                                                                                  
                                                                                                              
                                       
    static bool Capped(double fps, double waitShare, const Sample& s)
    {
        const auto at = [fps](double cap) { return cap > 0.0 && fps >= cap * 0.97 && fps <= cap * 1.03; };
        return (s.limitFps > 0.0 && s.limitFps <= s.targetFps * kLimitNear) || at(s.limitFps) || at(s.refreshFps) ||
               (waitShare < kHiddenWaitShare && at(s.targetFps));
    }

                                                                                                                   
                                                                                                                    
                                                                                                      
    static double Miss(double fps, double targetFps, int rounding)
    {
        const double r = fps / targetFps;

        if (rounding == (int) Rounding::Up)
            return r >= kReached ? r - kReached : 1.0 + kReached - r;

        if (rounding == (int) Rounding::Down)
            return r <= kAtMost ? kAtMost - r : 1.0 + r - kAtMost;

        return std::abs(r - 1.0);
    }

                                                                                                                  
                                   
    static double Expected(double fps, int rounding)
    {
        if (rounding == (int) Rounding::Up)
            return fps * (1.0 - kSideMargin);

        if (rounding == (int) Rounding::Down)
            return fps * (1.0 + kSideMargin);

        return fps;
    }

                                                                                                                  
                                                                                                                    
                                           
    int Free(const Sample& s, int count, int minCount, int maxCount, int rounding, double presented, double nowMs,
             double sinceChange)
    {
        const double genMs = _freeGenSamples > 0 ? _freeGenMs : _genMs;
        const double offMs = _freeOffSamples > 0 ? _freeOffMs : _offSamples > 0 ? _offMs : genMs;
        const auto limited = [&s](double fps) { return s.limitFps > 0.0 ? std::min(fps, s.limitFps) : fps; };

                                                                                                 
        const double higher =
            count < maxCount ? limited((count + 2) * 1000.0 / (_frameMs + (count == 0 ? offMs : genMs))) : 0.0;
        const double lower =
            count > minCount ? limited(count * 1000.0 / std::max(_frameMs - (count == 1 ? offMs : genMs), 0.5)) : 0.0;
        const double miss = Miss(presented, s.targetFps, rounding);
        const bool unreached = presented < s.targetFps * kReached;

        _lower = lower;
        _target = s.targetFps;

                                                                                                                    
                                                                          
        const bool upBlocked = nowMs < _upBlockedUntilMs && presented >= _upBlockedFps * 0.9;
        const bool up = higher >= presented * (1.0 + kWorth / (count + 1)) && !upBlocked &&
                        Miss(Expected(higher, rounding), s.targetFps, rounding) + kNearMargin < miss;

        if (Held(_upHold, up, nowMs) >= kHoldUpMs && sinceChange >= kMinUpGapMs)
        {
                                                                               
            if (_lastDownMs >= 0.0 && nowMs - _lastDownMs < kDownHoldsMs && _lastDownFrom == count + 1)
                FailedDown(count + 1, nowMs, false, _lastDownBefore);

            return Change(count + 1, nowMs, Reason::Up, Check::Up, presented);
        }

                                                                                                                      
                                                                                              
        const Step& step = StepFrom(count);
        const bool knownBad = nowMs < step.blockedUntilMs && presented <= step.failFps * kLighter;
        const bool keeps = unreached && lower >= presented * (1.0 - kWorth / (count + 1));
        const bool canDown = lower > 0.0 && sinceChange >= kMinDownGapMs && !knownBad;
        _shownBackoffMs = step.backoffMs;

        if (Held(_downHold,
                 canDown && (keeps || Miss(Expected(lower, rounding), s.targetFps, rounding) + kNearMargin < miss),
                 nowMs) >= kHoldDownMs)
        {
            _checkExpected = lower;
            return Change(count - 1, nowMs, Reason::Down, Check::Down, presented);
        }

                                                                                                                      
                                                                                                                   
        const bool probe =
            canDown && count == maxCount && unreached && _waitShare < kHiddenWaitShare && _freeGenSamples == 0;

        if (Held(_tryHold, probe, nowMs) >= step.backoffMs)
        {
            _checkExpected = lower;
            return Change(count - 1, nowMs, Reason::Probe, Check::Down, presented);
        }

        return count;
    }

                                                                                                     
    void BlockUp(double nowMs)
    {
        _upBackoffMs = std::min(_upBackoffMs * 2.0, kMaxBackoffMs);
        _upBlockedUntilMs = nowMs + _upBackoffMs;
        _upBlockedFps = _checkBefore;
    }

                                                                                                                   
                                 
    void UpHeld(int count, double mean, double nowMs)
    {
        _upBackoffMs = kMinBackoffMs;
        Step& back = StepFrom(count);
        back.failFps = mean;
        back.blockedUntilMs = std::max(back.blockedUntilMs, nowMs + std::max(back.backoffMs, kUpHoldsMs));
    }

                                                                                                                     
    void DownHeld(int count)
    {
        if (Step& held = StepFrom(count + 1); held.failFps <= 0.0 || _checkBefore <= held.failFps * kLighter)
            held = Step {};
    }

                                                                                                          
    double HoldShare(int n) const { return (n + 1.0) / (n + 1.0 + kHysteresis + _offset); }

                                                                                                                   
    double DownShare(int n) const { return n / (n + 1.0 - kHysteresis + _offset); }

    static double Held(Hold& hold, bool condition, double nowMs)
    {
        if (!condition)
        {
            if (hold.sinceMs >= 0.0 && nowMs - hold.lastMs > kGraceMs)
                hold = Hold {};

            return -1.0;
        }

        if (hold.sinceMs < 0.0 || nowMs - hold.lastMs > kGraceMs)
            hold.sinceMs = nowMs;

        hold.lastMs = nowMs;
        return nowMs - hold.sinceMs;
    }

                                                                                                                        
                                                                            
    struct Step
    {
        double backoffMs = kMinBackoffMs;
        double blockedUntilMs = 0.0;
        double failFps = 0.0;                                                     
    };

    static constexpr int kSteps = 9;                

    Step& StepFrom(int count) { return _steps[std::clamp(count, 0, kSteps - 1)]; }

                                                                                      
    void FailedDown(int from, double nowMs, bool farShort, double fromFps)
    {
        Step& step = StepFrom(from);
        step.backoffMs = std::min(step.backoffMs * (farShort ? 4.0 : 2.0), kMaxBackoffMs);
        step.blockedUntilMs = nowMs + step.backoffMs;
        step.failFps = fromFps;
        _lastDownMs = -1.0;
    }

    void LearnCap(double capFps, double nowMs)
    {
        _capFps = capFps;
        _capUntilMs = nowMs + kCapRetestMs;
    }

                                                                                                                   
                                                                                                                   
                                    
    void Learn(int count, double mean)
    {
        if (_checkCount < kCheckMinFrames || count == _checkBeforeCount || _checkBefore <= 0.0)
            return;

        const double after = _checkWorkSumMs / _checkCount;
        const double afterWaitShare = 1.0 - _checkWorkSumMs / _checkSumMs;
        const double expected = (count + 1.0) / (_checkBeforeCount + 1.0) - 1.0;
        const bool moved = std::abs(mean / _checkBefore - 1.0) >= std::abs(expected) * 0.25;
        const bool seen = _checkBeforeWaitShare >= 0.1 && afterWaitShare >= 0.1;

        if (!moved && !seen)
            return;

        const double perFrame = (after - _checkBeforeWorkMs) / (count - _checkBeforeCount);

                                                                                                     
        const bool onOff = std::min(count, _checkBeforeCount) == 0;
        if (perFrame < -0.1 * after || perFrame > (onOff ? 1.0 : 0.4) * after)
            return;

        const double cost = std::max(perFrame, 0.0);

                                                                                   
        if (onOff)
        {
            _offMs = _offSamples == 0 ? cost : _offMs + 0.5 * (cost - _offMs);
            ++_offSamples;
            return;
        }

        _genMs = _genSamples == 0 ? cost : _genMs + 0.5 * (cost - _genMs);
        ++_genSamples;
    }

                                                                                                                     
                                                                            
    void LearnFree(int count, bool capped)
    {
        if (capped || _checkCount < kCheckMinFrames || count == _checkBeforeCount || _checkBeforeFrameMs <= 0.0)
            return;

        const double after = _checkSumMs / _checkCount;
        const double perFrame = (after - _checkBeforeFrameMs) / (count - _checkBeforeCount);
        const bool onOff = std::min(count, _checkBeforeCount) == 0;

        if (perFrame < -0.1 * after || perFrame > (onOff ? 1.0 : 0.4) * after)
            return;

        const double cost = std::max(perFrame, 0.0);

        if (onOff)
        {
            _freeOffMs = _freeOffSamples == 0 ? cost : _freeOffMs + 0.5 * (cost - _freeOffMs);
            ++_freeOffSamples;
            return;
        }

        _freeGenMs = _freeGenSamples == 0 ? cost : _freeGenMs + 0.5 * (cost - _freeGenMs);
        ++_freeGenSamples;
    }

    int Change(int count, double nowMs, Reason reason, Check check, double presented)
    {
        _reason = reason;
        _lastChangeMs = nowMs;
        _lowSinceMs = -1.0;
        _downHold = Hold {};
        _tryHold = Hold {};
        _upHold = Hold {};

        if (reason == Reason::Down || reason == Reason::Probe)
        {
            _lastDownMs = nowMs;
            _lastDownFrom = count + 1;
            _lastDownBefore = presented;
        }

        _check = check;
        _checkUntilMs = nowMs + kCheckMs;
        _checkFree = _free;
        _checkBefore = presented;
        _checkBeforeFrameMs = _frameMs;
        _checkBeforeWorkMs = _workMs;
        _checkBeforeWaitShare = _frameMs > 0.0 ? 1.0 - _workMs / _frameMs : 0.0;
        _checkBeforeCount = check == Check::Up ? count - 1 : count + 1;
        _checkFrames = 0;
        _checkCount = 0;
        _checkSumMs = 0.0;
        _checkWorkSumMs = 0.0;

                                                                               
        _frameMs = 0.0;
        _workMs = 0.0;
        return count;
    }

    bool _fresh = true;                                   
    int _hitchRun = 0;                                  
    double _frameMs = 0.0;
    double _workMs = 0.0;
    double _lastChangeMs = 0.0;
    double _lowSinceMs = -1.0;
    Hold _downHold;                                                  
    Hold _tryHold;                                 
    Hold _upHold;                                                                 
    bool _free = false;                                   
    double _cappedUntilMs = 0.0;
    double _lastDownMs = -1.0;
    int _lastDownFrom = -1;                                           
    double _lastDownBefore = 0.0;                               

    Check _check = Check::None;
    double _checkUntilMs = 0.0;
    bool _checkFree = false;                                         
    double _checkExpected = 0.0;                                                                   
    double _checkBefore = 0.0;                                      
    double _checkBeforeFrameMs = 0.0;
    double _checkBeforeWorkMs = 0.0;
    double _checkBeforeWaitShare = 0.0;
    int _checkBeforeCount = 0;
    int _checkFrames = 0;                           
    int _checkCount = 0;                     
    double _checkSumMs = 0.0;
    double _checkWorkSumMs = 0.0;

    double _goalFps = 0.0;                                              
    int _goalRounding = -1;
    double _offset = 0.0;                                    
    double _genMs = 0.0;                                           
    int _genSamples = 0;
    double _offMs = 0.0;                                                     
    int _offSamples = 0;
    double _freeGenMs = 0.0;                                                          
    int _freeGenSamples = 0;
    double _freeOffMs = 0.0;
    int _freeOffSamples = 0;
    double _capFps = 0.0;                                           
    double _capUntilMs = 0.0;
    double _upBlockedUntilMs = 0.0;
    double _upBlockedFps = 0.0;
    double _upBackoffMs = kMinBackoffMs;
    Step _steps[kSteps];
    double _shownBackoffMs = kMinBackoffMs;

    double _presented = 0.0;
    double _lower = 0.0;
    double _target = 0.0;
    double _waitShare = 0.0;
    Reason _reason = Reason::None;
};
