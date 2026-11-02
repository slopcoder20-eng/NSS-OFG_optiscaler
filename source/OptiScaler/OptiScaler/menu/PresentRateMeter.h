#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <deque>
#include <mutex>

                                                                            
                                                                              
                                                                                    
class PresentRateMeter final
{
    static constexpr std::size_t Capacity = 512;
    static constexpr double WindowMs = 125.0;
    static constexpr double MinimumSpanMs = 50.0;

    struct Sample
    {
        double ms;
        std::uint64_t presents;
    };

    std::mutex _mutex;
    bool _enabled = false;
    std::uint64_t _presents = 0;
    double _lastPresentMs = 0.0;

                                                                                 
    std::deque<Sample> _samples;

                                                                                 
    std::deque<double> _intervals;

  public:
                                                                              
                                                                           
    void SetEnabled(bool enabled)
    {
        std::lock_guard lock(_mutex);
        if (_enabled == enabled)
            return;

        _enabled = enabled;
        _samples.clear();
        _intervals.clear();
        _lastPresentMs = 0.0;
    }

                                                                       
    void Present(double nowMs)
    {
        std::lock_guard lock(_mutex);
        if (!_enabled)
            return;

        ++_presents;

                                                                        
                                                                                    
        nowMs = std::max(nowMs, _lastPresentMs);

        if (_lastPresentMs > 0.0)
        {
            if (_intervals.size() == Capacity)
                _intervals.pop_front();

            _intervals.push_back(nowMs - _lastPresentMs);
        }

        _lastPresentMs = nowMs;
    }

                                                                          
                                                                              
    double FrameTime(double nowMs)
    {
        std::lock_guard lock(_mutex);
        if (!_enabled)
            return 0.0;

        while (!_samples.empty() && nowMs - _samples.front().ms > WindowMs)
            _samples.pop_front();

        _samples.push_back({ nowMs, _presents });

                                                                                                           
                                                                                                       
                                                           
        const double spanMs = nowMs - _samples.front().ms;
        const auto presents = _presents - _samples.front().presents;
        if (spanMs < MinimumSpanMs || presents < 2)
            return 0.0;

        return spanMs / static_cast<double>(presents);
    }

                                                                                                         
                                                   
    template <typename F> bool TakeIntervals(F&& callback)
    {
        std::lock_guard lock(_mutex);

        for (double ms : _intervals)
            callback(ms);

        _intervals.clear();
        return _enabled;
    }
};
