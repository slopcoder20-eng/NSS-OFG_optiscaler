#pragma once
#include <Windows.h>
#include <algorithm>
#include <chrono>
#include <cmath>

                                                                               
                                                                                
class NfruRealFramePacer
{
    using Clock = std::chrono::steady_clock;
    Clock::time_point previous {};
    float activeFps = 0.0f;
    HANDLE timer = nullptr;
public:
    NfruRealFramePacer() = default;
    NfruRealFramePacer(const NfruRealFramePacer&) = delete;
    NfruRealFramePacer& operator=(const NfruRealFramePacer&) = delete;
    ~NfruRealFramePacer() { if (timer) CloseHandle(timer); }

    void Pace(float fps, bool firstOutput)
    {
                                                                            
        if (!std::isfinite(fps) || fps <= 0.0f) {
            activeFps = 0.0f; previous = {}; return;
        }
        fps = std::clamp(fps, 1.0f, 500.0f);
        if (fps != activeFps) { activeFps = fps; previous = {}; }
        if (!firstOutput) return;
        if (previous.time_since_epoch().count() != 0) {
            const auto interval = std::chrono::duration_cast<Clock::duration>(std::chrono::duration<double>(1.0 / fps));
            const auto deadline = previous + interval;
            for (auto now = Clock::now(); now < deadline; now = Clock::now()) {
                const auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(deadline - now).count();
                if (!timer) timer = CreateWaitableTimerExW(nullptr, nullptr, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
                                                         TIMER_MODIFY_STATE | SYNCHRONIZE);
                LARGE_INTEGER due {};
                due.QuadPart = -(ns / 100 + 1);
                if (!timer || !SetWaitableTimerEx(timer, &due, 0, nullptr, nullptr, nullptr, 0) ||
                    WaitForSingleObject(timer, INFINITE) != WAIT_OBJECT_0)
                    Sleep(static_cast<DWORD>((ns + 999999) / 1000000));
            }
        }
                                                                            
        previous = Clock::now();
    }
};
