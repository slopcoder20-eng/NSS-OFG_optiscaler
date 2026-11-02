// Copyright 2021 Tatsuyuki Ishi
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#ifndef LATENCYFLEX_H
#define LATENCYFLEX_H

                   

#ifdef LATENCYFLEX_HAVE_PERFETTO
#include <perfetto.h>
PERFETTO_DEFINE_CATEGORIES(
    perfetto::Category("latencyflex").SetDescription("LatencyFleX latency and throughput metrics"));
#else
#define TRACE_COUNTER(...)
                                                               
#define TRACE_EVENT_BEGIN(...)
#define TRACE_EVENT_END(...)
#endif

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <thread>
#include <vector>

#if defined __MINGW64__ || defined __MINGW32__
#define max(a, b) std::max(a, b)
#endif

namespace lfx
{
namespace internal
{
                                                      
class EwmaEstimator
{
  public:
                                                                                  
                                           
                                                                          
                                                                                  
                                      
    EwmaEstimator(double alpha, bool full_weight = false) : alpha_(alpha), current_weight_(full_weight ? 1.0 : 0.0) {}

                                                                           
                                                                           
                                          
    void update(double value)
    {
        current_ = (1 - alpha_) * current_ + alpha_ * value;
        current_weight_ = (1 - alpha_) * current_weight_ + alpha_;
    }

    double get() const
    {
        if (current_weight_ == 0)
        {
            return 0;
        }
        return current_ / current_weight_;
    }

  private:
    double alpha_;
    double current_ = 0;
    double current_weight_;
};
}                      

enum Phases
{
    kUp = 0,
    kDown,
    kNumPhases
};

                                                                            
                                                                            
                                          
  
                                          
class LatencyFleX
{
  public:
    LatencyFleX() : latency_(0.3), inv_throughtput_(0.3), proj_correction_(0.5, true)
    {
        std::fill(std::begin(frame_begin_ids_), std::end(frame_begin_ids_), UINT64_MAX);
    }

                                                                                                   
                                                                                                     
                                                                        
      
                                                                             
                
    uint64_t GetWaitTarget(uint64_t frame_id)
    {
        if (prev_frame_end_id_ != UINT64_MAX)
        {
            size_t phase = frame_id % kNumPhases;
            double invtpt = inv_throughtput_.get();
            int64_t comp_to_apply = 0;
            if (frame_end_projection_base_ == UINT64_MAX)
            {
                frame_end_projection_base_ = prev_frame_end_ts_;
            }
            else
            {
                                                                                          
                                                                                       
                                                                                        
                                                                                  

                                                                                       
                                                                                            
                int64_t prediction_error = (int64_t) prev_frame_end_ts_ -
                                           (int64_t) (frame_end_projection_base_ +
                                                      frame_end_projected_ts_[prev_frame_end_id_ % kMaxInflightFrames]);
                TRACE_COUNTER("latencyflex", "Prediction error", prediction_error);
                int64_t prev_comp_applied = comp_applied_[prev_frame_end_id_ % kMaxInflightFrames];
                                                                                                            
                                                                                                            
                                                   
                  
                                                                                                          
                                                                                            
                                                                                                       
                                                                                                   
                                                                                                        
                                                                                             
                                                                                       
                                                                                                            
                                                                                                        
                                                                                                    
                  
                                                                                                          
                                                                                                       
                                                                                                
                proj_correction_.update((double) (std::max(INT64_C(0), prediction_error) -
                                                  std::max(INT64_C(0), prev_prediction_error_ - prev_comp_applied)));
                prev_prediction_error_ = prediction_error;
                                                                                                   
                                                                                                      
                                                                                                          
                                                                                    
                comp_to_apply = (int64_t) std::round(proj_correction_.get());
                comp_applied_[frame_id % kMaxInflightFrames] = comp_to_apply;
                TRACE_COUNTER("latencyflex", "Delay Compensation", comp_to_apply);
            }

                                      
            uint64_t target =
                (int64_t) frame_end_projection_base_ +
                (int64_t) frame_end_projected_ts_[prev_frame_begin_id_ % kMaxInflightFrames] + comp_to_apply +
                (int64_t) std::round(
                    (((int64_t) frame_id - (int64_t) prev_frame_begin_id_) + 1 / (phase == kUp ? up_factor_ : 1) - 1) *
                        invtpt / down_factor_ -
                    latency_.get());
                                                                                                        
                                                                                                        
                                                          
            uint64_t new_projection =
                (int64_t) frame_end_projected_ts_[prev_frame_begin_id_ % kMaxInflightFrames] + comp_to_apply +
                (int64_t) std::round(((int64_t) frame_id - (int64_t) prev_frame_begin_id_) * invtpt / down_factor_);
            frame_end_projected_ts_[frame_id % kMaxInflightFrames] = new_projection;
            TRACE_EVENT_BEGIN("latencyflex", "projection",
                              perfetto::Track(track_base_ + frame_id % kMaxInflightFrames + kMaxInflightFrames),
                              target);
            TRACE_EVENT_END("latencyflex",
                            perfetto::Track(track_base_ + frame_id % kMaxInflightFrames + kMaxInflightFrames),
                            frame_end_projection_base_ + new_projection);
            return target;
        }
        else
        {
            return 0;
        }
    }

                                                             
      
                                                                   
      
                                                                      
                                                   
                                                                              
                                             
                                                                                 
                                                                                
                                          
    void BeginFrame(uint64_t frame_id, uint64_t target, uint64_t timestamp)
    {
        TRACE_EVENT_BEGIN("latencyflex", "frame", perfetto::Track(track_base_ + frame_id % kMaxInflightFrames),
                          timestamp);
        frame_begin_ids_[frame_id % kMaxInflightFrames] = frame_id;
        TRACE_COUNTER("latencyflex", "frame_id_begin", frame_id);
        frame_begin_ts_[frame_id % kMaxInflightFrames] = timestamp;
        prev_frame_begin_id_ = frame_id;
        if (target != 0)
        {
            int64_t forced_correction = timestamp - target;
            frame_end_projected_ts_[frame_id % kMaxInflightFrames] += forced_correction;
            comp_applied_[frame_id % kMaxInflightFrames] += forced_correction;
            prev_prediction_error_ += forced_correction;
        }
    }

                                                             
      
                                                                     
                                                                             
                                                                 
                                                                              
                                                          
      
                                                                                 
                                                                                  
                   
    void EndFrame(uint64_t frame_id, uint64_t timestamp, uint64_t* latency, uint64_t* frame_time)
    {
        size_t phase = frame_id % kNumPhases;
        int64_t latency_val = -1;
        int64_t frame_time_val = -1;
        TRACE_COUNTER("latencyflex", "frame_id_end", frame_id);
        if (frame_begin_ids_[frame_id % kMaxInflightFrames] == frame_id)
        {
            frame_begin_ids_[frame_id % kMaxInflightFrames] = UINT64_MAX;

            if (frame_time && prev_frame_end_id_ != UINT64_MAX)
                *frame_time = timestamp - prev_frame_real_end_ts_;
            prev_frame_real_end_ts_ = timestamp;
            timestamp = std::max(timestamp, prev_frame_end_ts_ + target_frame_time);
            auto frame_start = frame_begin_ts_[frame_id % kMaxInflightFrames];
            latency_val = (int64_t) timestamp - (int64_t) frame_start;
            if (phase == kDown)
            {
                latency_.update((double) latency_val);
            }
            if (latency)
                *latency = latency_val;
            TRACE_COUNTER("latencyflex", "Latency", latency_val);
            TRACE_COUNTER("latencyflex", "Latency (Estimate)", latency_.get());
            if (prev_frame_end_id_ != UINT64_MAX)
            {
                if (frame_id > prev_frame_end_id_)
                {
                    auto frames_elapsed = frame_id - prev_frame_end_id_;
                    frame_time_val = ((int64_t) timestamp - (int64_t) prev_frame_end_ts_) / (int64_t) frames_elapsed;
                    frame_time_val = std::clamp(frame_time_val, INT64_C(1000000), INT64_C(50000000));
                    if (phase == kUp)
                    {
                        inv_throughtput_.update((double) frame_time_val);
                    }
                    TRACE_COUNTER("latencyflex", "Frame Time", frame_time_val);
                    TRACE_COUNTER("latencyflex", "Frame Time (Estimate)", inv_throughtput_.get());
                }
            }
            prev_frame_end_id_ = frame_id;
            prev_frame_end_ts_ = timestamp;
        }
        if (frame_time)
            *frame_time = frame_time_val;
        TRACE_EVENT_END("latencyflex", perfetto::Track(track_base_ + frame_id % kMaxInflightFrames), timestamp);
    }

    void Reset()
    {
        auto new_instance = LatencyFleX();
#ifdef LATENCYFLEX_HAVE_PERFETTO
        new_instance.track_base_ = track_base_ + 2 * kMaxInflightFrames;
#endif
        new_instance.target_frame_time = target_frame_time;
        *this = new_instance;
    }

    uint64_t target_frame_time = 0;

  private:
    static const std::size_t kMaxInflightFrames = 16;

    uint64_t frame_begin_ts_[kMaxInflightFrames] = {};
    uint64_t frame_begin_ids_[kMaxInflightFrames];
    uint64_t frame_end_projected_ts_[kMaxInflightFrames] = {};
    uint64_t frame_end_projection_base_ = UINT64_MAX;
    int64_t comp_applied_[kMaxInflightFrames] = {};
    uint64_t prev_frame_begin_id_ = UINT64_MAX;
    double up_factor_ = 1.10;
    double down_factor_ = 0.985;
    int64_t prev_prediction_error_ = 0;
    uint64_t prev_frame_end_id_ = UINT64_MAX;
    uint64_t prev_frame_end_ts_ = 0;
    uint64_t prev_frame_real_end_ts_ = 0;
    internal::EwmaEstimator latency_;
    internal::EwmaEstimator inv_throughtput_;
    internal::EwmaEstimator proj_correction_;

#ifdef LATENCYFLEX_HAVE_PERFETTO
    uint64_t track_base_ = 0;
#endif
};
}                 
#undef max
#endif                 
