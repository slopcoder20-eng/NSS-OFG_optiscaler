#pragma once
#include <deque>
#include <mutex>
#include <utility>
#include <cstdint>
class SubmittedRateTracker {
    struct Sample{double time;std::uint64_t real,output;};
    mutable std::mutex mutex;
    std::deque<Sample> samples;
    std::uint64_t real=0,output=0;
public:
    void Reset(){std::lock_guard lock(mutex);samples.clear();real=output=0;}
    void Record(double now,unsigned outputs){std::lock_guard lock(mutex);if(!outputs)return;if(!samples.empty()&&now<samples.back().time){samples.clear();real=output=0;}++real;output+=outputs;samples.push_back({now,real,output});while(samples.size()>2&&now-samples[1].time>=500)samples.pop_front();}
    std::pair<double,double> Rates(double now)const{std::lock_guard lock(mutex);if(samples.size()<2||now<samples.back().time||now-samples.back().time>500)return {};const auto& a=samples.front();const auto& b=samples.back();double span=b.time-a.time;if(span<50)return {};return {1000.0*double(b.real-a.real)/span,1000.0*double(b.output-a.output)/span};}
};
