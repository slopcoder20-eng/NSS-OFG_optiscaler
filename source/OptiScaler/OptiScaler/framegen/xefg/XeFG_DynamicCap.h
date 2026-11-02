#pragma once

#include <algorithm>

                                                                                                                   
                                                                                                                     
                                                                                                               
                                                                                                  
                                                                                        
                                                                                                                  
                                                                                                                  
                                                                                                                  
                                 
                                                                                                                    
                                                                                                                     
                                                                                                                    
                                                                                                              
                                                                                                                
class XeFG_DynamicCap
{
  public:
    struct Sample
    {
        double nowMs = 0.0;                       
        double frameMs = 0.0;                         
        double sleepMs = 0.0;                                                                          
        double targetFps = 0.0;                                      
        int maxCount = 1;                                          
        int currentCount = 1;                                
    };

    enum class Reason
    {
        None,
        Up,
        Down,
        Probe,
        Undo
    };

    int Update(const Sample& s)
    {
        _reason = Reason::None;
        const int maxCount = std::max(s.maxCount, 1);
        const int count = std::clamp(s.currentCount, 1, maxCount);

                                                                                      
        if (s.targetFps <= 0.0 || s.frameMs <= 0.0 || s.frameMs > 250.0)
            return count;

                                                     
        if (_frameMs > 0.0 && s.frameMs > _frameMs * kHitchFactor && _hitchRun < kMaxHitchRun)
        {
            ++_hitchRun;
            return count;
        }
        _hitchRun = 0;

        const double work = std::max(s.frameMs - std::max(s.sleepMs, 0.0), 0.5);
        _sleepShare += kAlpha * ((s.sleepMs > 0.1 ? 1.0 : 0.0) - _sleepShare);
        _sleepSeen = _sleepShare > 0.5;

        if (_frameMs <= 0.0)
        {
            _frameMs = s.frameMs;
            _workMs = work;
            _lastChangeMs = s.nowMs;
            _cappedSinceMs = s.nowMs;
        }
        else
        {
            _frameMs += kAlpha * (s.frameMs - _frameMs);
            _workMs += kAlpha * (work - _workMs);
        }

        const double presented = 1000.0 * (count + 1) / _frameMs;
        const double reachable = 1000.0 / _workMs;                                                      
        const double sinceChange = s.nowMs - _lastChangeMs;
        _presented = presented;
        _reachable = reachable;

                                                                                                                   
                                                                                                                
                                             
        if (_checkUntilMs > 0.0)
        {
            if (++_checkFrames > kCheckSkipFrames)
            {
                _checkSumMs += s.frameMs;
                ++_checkCount;
            }

            if (_checkCount >= kCheckMinFrames && sinceChange >= kCheckMinMs &&
                1000.0 * (count + 1) * _checkCount / _checkSumMs < s.targetFps * 0.93 && count < maxCount)
            {
                _backoffMs = std::min(_backoffMs * 2.0, kMaxBackoffMs);
                _downBlockedUntilMs = s.nowMs + _backoffMs;
                _failedReachable = _downReachable;
                return Change(count + 1, s.nowMs, Reason::Undo, reachable);
            }

            if (s.nowMs < _checkUntilMs)
                return count;

                                                                                                                   
                                                        
            if (_checkCount > 0 && 1000.0 * (count + 1) * _checkCount / _checkSumMs < s.targetFps * 0.97 &&
                count < maxCount)
            {
                _backoffMs = std::min(_backoffMs * 2.0, kMaxBackoffMs);
                _downBlockedUntilMs = s.nowMs + _backoffMs;
                _failedReachable = _downReachable;
                return Change(count + 1, s.nowMs, Reason::Undo, reachable);
            }

            _checkUntilMs = 0.0;
            _backoffMs = kMinBackoffMs;
            _failedReachable = 0.0;
        }

             
        if (count < maxCount && presented < s.targetFps * 0.97)
        {
            if (_lowSinceMs < 0.0)
                _lowSinceMs = s.nowMs;

            if (s.nowMs - _lowSinceMs >= kHoldUpMs && sinceChange >= kMinUpGapMs)
                return Change(count + 1, s.nowMs, Reason::Up, reachable);
        }
        else
        {
            _lowSinceMs = -1.0;
        }

                                                                                              
        const bool blocked =
            s.nowMs < _downBlockedUntilMs && !(_failedReachable > 0.0 && reachable >= _failedReachable * 1.1);

        if (count <= 1 || blocked || sinceChange < kMinDownGapMs)
        {
            _highSinceMs = -1.0;
            return count;
        }

                                                                      
        if (reachable * count >= s.targetFps * 1.04)
        {
            if (_highSinceMs < 0.0)
                _highSinceMs = s.nowMs;

            if (s.nowMs - _highSinceMs >= kHoldDownMs)
            {
                _checkUntilMs = s.nowMs + kCheckMs;
                _downReachable = reachable;
                return Change(count - 1, s.nowMs, Reason::Down, reachable);
            }
        }
        else
        {
            _highSinceMs = -1.0;
        }

                                                                                                                     
                                                                                                                  
                                                                                                                      
        if (presented >= s.targetFps * 0.97 && presented <= s.targetFps * 1.03)
        {
            if (_cappedSinceMs < 0.0 || s.nowMs - _cappedLastMs > kGraceMs)
                _cappedSinceMs = s.nowMs;

            _cappedLastMs = s.nowMs;
            const double wait = _sleepSeen ? std::max(_backoffMs, kSleepProbeMs) : _backoffMs;

            if (s.nowMs - _cappedSinceMs >= std::min(wait, kHoldDownMs) && sinceChange >= wait)
            {
                _checkUntilMs = s.nowMs + kCheckMs;
                _downReachable = reachable;
                return Change(count - 1, s.nowMs, Reason::Probe, reachable);
            }
        }
        else if (_cappedSinceMs >= 0.0 && s.nowMs - _cappedLastMs > kGraceMs)
        {
            _cappedSinceMs = -1.0;
        }

        return count;
    }

    void Reset() { *this = XeFG_DynamicCap {}; }

    Reason LastReason() const { return _reason; }
                                                                   
    double DecisionReachableFps() const { return _decisionReachable; }
                                                                                                    
    double PresentedFps() const { return _presented; }
    double ReachableFps() const { return _reachable; }
    double BackoffMs() const { return _backoffMs; }

  private:
    static constexpr double kAlpha = 0.1;
    static constexpr double kHoldUpMs = 300.0;
    static constexpr double kHoldDownMs = 1500.0;
    static constexpr double kMinUpGapMs = 500.0;
    static constexpr double kMinDownGapMs = 2000.0;
    static constexpr int kCheckSkipFrames = 3;                                                              
    static constexpr int kCheckMinFrames = 6;
    static constexpr double kCheckMinMs = 400.0;
    static constexpr double kCheckMs = 1500.0;
    static constexpr double kMinBackoffMs = 5000.0;
    static constexpr double kMaxBackoffMs = 60000.0;
    static constexpr double kSleepProbeMs = 15000.0;                                             
    static constexpr double kGraceMs = 300.0;                                                              
    static constexpr double kHitchFactor = 2.5;                                                             
    static constexpr int kMaxHitchRun = 2;                                             

    int Change(int count, double nowMs, Reason reason, double reachable)
    {
        _reason = reason;
        _decisionReachable = reachable;
        _lastChangeMs = nowMs;
        _lowSinceMs = -1.0;
        _highSinceMs = -1.0;
        _cappedSinceMs = -1.0;
        if (reason == Reason::Up || reason == Reason::Undo)
            _checkUntilMs = 0.0;

        _checkFrames = 0;
        _checkCount = 0;
        _checkSumMs = 0.0;

                                                                               
        _frameMs = 0.0;
        _workMs = 0.0;
        return count;
    }

    double _frameMs = 0.0;
    double _workMs = 0.0;
    double _lastChangeMs = 0.0;
    double _lowSinceMs = -1.0;
    double _highSinceMs = -1.0;
    double _cappedSinceMs = -1.0;
    double _cappedLastMs = -1.0;
    int _hitchRun = 0;
    double _checkUntilMs = 0.0;
    int _checkFrames = 0;                            
    int _checkCount = 0;                     
    double _checkSumMs = 0.0;
    double _downBlockedUntilMs = 0.0;
    double _backoffMs = kMinBackoffMs;
    double _downReachable = 0.0;                                             
    double _failedReachable = 0.0;                                                   
    double _decisionReachable = 0.0;
    double _sleepShare = 0.0;                                                                          
    bool _sleepSeen = false;
    double _presented = 0.0;
    double _reachable = 0.0;
    Reason _reason = Reason::None;
};
