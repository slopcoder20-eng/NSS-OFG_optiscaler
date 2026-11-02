#pragma once

#include <xell.h>

#include <low_latency/low_latency_tech/low_latency_tech.h>
#include <Config.h>

enum class InputMarkerMode
{
    NoMarkers,
    SimStartOnly,                                                              
    SimStartAndPresentStart,                                   
    SimOnly,                                 
    FullMarkers,                                                                      
};

struct InputContext
{
    LowLatencyInput caller;
    bool localContext;                         
    bool noFrameId;
    InputMarkerMode markerMode;
    API api;                                                                                    
};

enum class InputResult : uint32_t
{
    Ok,
    UsingDifferentInput,
    InputNotSupported,
    InvalidParameter,
    LowLatencyUpdateFail,
    NotEnoughReports,
    NoReadyOutput,
    GenericError,
};

class ReflexVk;

struct TimingData
{
    std::optional<TimingEntry> timeRange;                                 
    std::optional<TimingEntry> simulation;
    std::optional<TimingEntry> renderSubmit;
    std::optional<TimingEntry> present;
    std::optional<TimingEntry> driver;
    std::optional<TimingEntry> osRenderQueue;
    std::optional<TimingEntry> gpuRender;
};

class InputCommon
{
    static std::atomic<std::shared_ptr<LowLatencyTech>> currently_active_tech;
    inline static std::mutex create_tech_mutex {};

                                                                                                                      
                                                                                                                    
                                                         
    static std::atomic<std::shared_ptr<LowLatencyTech>> xefg_xell;
    inline static std::atomic_bool xefg_uses_output_xell = false;
                                                              
    inline static std::atomic<LowLatencyMode> xefg_started_output = LowLatencyMode::None;
    static LowLatencyMode xefg_output(LowLatencyMode configured);

    inline static FrameReport frame_reports[FRAME_REPORTS_BUFFER_SIZE] {};
    inline static std::array<std::atomic_uint64_t, 6> last_marker_frame_ids {};                                   
    inline static LowLatencyMode failed_output = LowLatencyMode::None;
    inline static std::chrono::steady_clock::time_point failed_time {};
    inline static std::atomic_uint64_t last_present_start_frame_id = 0;
    inline static std::atomic_uint32_t delay_deinit = 0;
    inline static std::array<SleepMode, static_cast<size_t>(LowLatencyInput::_)> sleep_mode_copies {};
    inline static std::atomic_uint32_t presents_without_input = 0;
    inline static std::atomic_uint32_t fps_limit_interval_us = 0;                                                   
    inline static std::atomic_bool limits_fps = false;
                                                                                                         
    inline static std::atomic_uint64_t present_count = 0;
    inline static std::array<std::atomic_uint64_t, static_cast<size_t>(LowLatencyInput::_)> last_fg_present {};
                                                                                                       
    inline static std::atomic_uint64_t fg_frame_id = 0;
    inline static std::atomic_bool fg_new_batch = false;
                                                                                                                     
                     
    inline static std::atomic<ID3D12CommandQueue*> xefg_present_queue = nullptr;
    inline static std::atomic_uint64_t xefg_frame_id = 0;
                                                                                                 
    inline static std::atomic<double> last_sleep_ms = 0.0;

    static void mark_frame_generation(LowLatencyInput input)
    {
        last_fg_present[static_cast<size_t>(input)] = present_count + 1;
    }

    static bool reports_frame_generation(LowLatencyInput input)
    {
        auto last = last_fg_present[static_cast<size_t>(input)].load();
        return last != 0 && present_count + 1 - last < 20;
    }

    static bool xefg_paced();

    inline static flag_set<LowLatencyInput> avaliableInputs {};
    inline static LowLatencyInput activeInput = LowLatencyInput::None;
    inline static LowLatencyMode activeOutput = LowLatencyMode::None;
    inline static bool enabled = false;

                                                                            
    inline static std::array<std::atomic<API>, static_cast<size_t>(LowLatencyInput::_)> input_api {};
    inline static std::atomic<API> output_api = API::NotSelected;

    static bool deinit_current_tech();
    static bool init_tech(IUnknown* pDevice, API api, LowLatencyMode desiredMode);
    static bool update_low_latency_tech(IUnknown* pDevice, API api, std::optional<LowLatencyMode> mode = std::nullopt);
    static void add_marker_to_report(const MarkerParams& marker_params);
    static bool copy_frame_reports(FrameReport* reports);                                           

                                   
    static API device_api(const InputContext& inputContext, IUnknown* pDevice);

                                                                  
    static API register_call(const InputContext& inputContext, IUnknown* pDevice);

                                                                                                                  
    static LowLatencyMode for_api(LowLatencyMode mode, API api);
    static SleepMode& get_sleep_copy(LowLatencyInput input) { return sleep_mode_copies[static_cast<size_t>(input)]; }
    static void apply_sleep_mode(LowLatencyTech* tech);

  public:
    static InputResult set_low_latency_tech(IUnknown* pDevice, LowLatencyMode mode);

                                                                    
    static double take_sleep_ms() { return last_sleep_ms.exchange(0.0); }

    static InputResult sleep(const InputContext& inputContext, IUnknown* pDevice,
                             std::optional<uint32_t> frame_id = std::nullopt);
                                                                            
    static InputResult set_marker(const InputContext& inputContext, IUnknown* pDevice,
                                  const MarkerParams& marker_params, bool toOutput = true);
    static InputResult set_async_marker(const InputContext& inputContext, ID3D12CommandQueue* pCommandQueue,
                                        const MarkerParams& marker_params);
    static InputResult set_sleep_mode(const InputContext& inputContext, IUnknown* pDevice, SleepMode* sleep_mode);
    static InputResult get_sleep_status(const InputContext& inputContext, IUnknown* pDevice, SleepParams* sleep_params);
    static InputResult
    get_latency(const InputContext& inputContext, IUnknown* pDev,
                void* latency_params);                                                                        
                                                                                             
    static InputResult get_frame_reports(const InputContext& inputContext, IUnknown* pDev, FrameReport* reports);
    static bool get_timing_data(TimingData& timingDataOut);
    static uint64_t get_last_present_start_frame_id() { return last_present_start_frame_id; };
    static flag_set<LowLatencyInput> get_avaliable_inputs() { return avaliableInputs; };
    static LowLatencyMode active_output() { return activeOutput; }

                                                          
    static API uses_api();
    static void get_currently_active(LowLatencyInput& activeInput, LowLatencyMode& activeOutput)
    {
        activeInput = InputCommon::activeInput;
        activeOutput = InputCommon::activeOutput;
    }

    static InputResult mark_present_start(IUnknown* pDevice);

                                                                                                                  
                                        
    static void update();
    static bool can_limit_fps() { return limits_fps; }

                                                                                                                      
                                                             
    static void fg_game_present(ID3D12CommandQueue* gameQueue, bool presented, uint32_t frameMultiplier);
    static void fg_output_present(ID3D12CommandQueue* presentQueue, bool presented, uint32_t frameMultiplier);
                                                                                                                   
    static bool dlssg_types_presents();
    static void dlssg_present();

                                                                                                                    
                                  
    static bool output_reports_fg_multiplier();

                                                                                                                       
                                                                                                                        
                                            
    static void xefg_marker(void* xellContext, uint32_t frame_id, uint32_t marker);

                                                                                                                    
                                                                                         
    static uint64_t xefg_marked_frame_id() { return xefg_frame_id; }
    static void xefg_present_status(uint64_t frameIdBefore, uint32_t framesPresented);

                                                                                                         
                                  
    static LowLatencyInput default_input();

                                              
    static LowLatencyMode default_output(API api);

                                                                                                                  
                                      
    static const char* output_unavailable(LowLatencyMode output, API api);

                                                                                                                   
                
    static bool driver_reflex_available(API api);

                                                                
    static const char* incompatibility(LowLatencyInput input, LowLatencyMode output);

                                                                                                                  
           
    static std::optional<LowLatencyMode> forced_output();
    static std::optional<LowLatencyInput> forced_input();

                                                       
    static xell_context_handle_t xell_output_context();

                                                                                        
    static std::shared_ptr<ReflexVk> reflex_vk_output();

                                                                                                                
    static xell_context_handle_t acquire_xefg_xell(IUnknown* pDevice);
    static void release_xefg_xell();

                                                          
    static bool xefg_output_change_pending();
};
