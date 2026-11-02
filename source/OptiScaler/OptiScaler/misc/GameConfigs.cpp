#include "pch.h"
#include "GameConfigs.h"

#include "State.h"
#include "Config.h"
#include "Logger.h"

                    
                    
                                     
  
                 
                                         
      
                                                                        
                                                                                                                        
                                                                       
                                         
       
  
                                                                           
  
                                                                                  
                                                                                                        
                                                                                       
                                                             
                                                                                               
                                                                                           
                                                                                             
  
                                                                                          

namespace
{
template <auto Member> struct Setting
{
    using ValueType = typename std::remove_reference_t<decltype(std::declval<Config&>().*Member)>::value_type;

    const char* name;

                                                    
    template <class V> ConfigDefault operator=(V value) const
    {
        const auto typedValue = static_cast<ValueType>(value);

        return { std::format("{} = {}", name, typedValue), [typedValue]
                 {
                     auto& option = Config::Instance()->*Member;

                     if (option.has_value())
                         return false;

                     option.set_volatile_value(typedValue);
                     return true;
                 } };
    }
};

#define GAME_SETTING(member)                                                                                           \
    const Setting<&Config::member> member { #member }

GAME_SETTING(AutoExposure);
GAME_SETTING(BuildPipelines);
GAME_SETTING(ColorResourceBarrier);
GAME_SETTING(CreateHeaps);
GAME_SETTING(DisableOTA);
GAME_SETTING(DisableReactiveMask);
GAME_SETTING(DontUseNTShared);
GAME_SETTING(DxgiSpoofing);
GAME_SETTING(EnableFfxInputs);
GAME_SETTING(EnableFsr2Inputs);
GAME_SETTING(EnableFsr3Inputs);
GAME_SETTING(ExtendedStateRestore);
GAME_SETTING(FGAllowedFrameAhead);
GAME_SETTING(FGAlwaysCaptureFSRFGSwapchain);
GAME_SETTING(FGDisableHUDFix);
GAME_SETTING(FGPreserveSwapChain);
GAME_SETTING(FGSkipResizeBuffers);
GAME_SETTING(FGXeFGForceBorderless);
GAME_SETTING(FGXeFGIgnoreInitChecks);
GAME_SETTING(Fsr2Pattern);
GAME_SETTING(Fsr4DoNotLoadAmdxc64);
GAME_SETTING(FsrUseFsrInputValues);
GAME_SETTING(MVResourceBarrier);
GAME_SETTING(OverlayMenu);
GAME_SETTING(OverrideVsync);
GAME_SETTING(RestoreComputeSignature);
GAME_SETTING(SkipFirstFrames);
GAME_SETTING(SpoofRegistry);
GAME_SETTING(UseFakenvapi);
GAME_SETTING(UseFsr2Dx11Inputs);
GAME_SETTING(UseFsr2VulkanInputs);
GAME_SETTING(UseNtdllHooks);
GAME_SETTING(VulkanExtensionSpoofing);
GAME_SETTING(VulkanSpoofing);
GAME_SETTING(ReprojectionDepthCutoff);
GAME_SETTING(SimulateWaitableObject);

#undef GAME_SETTING

ConfigDefault When(bool (*condition)(const GameConfigContext&), ConfigDefault setting)
{
    setting.condition = condition;
    return setting;
}

ConfigDefault OnNvidia(ConfigDefault setting)
{
    return When([](const GameConfigContext& context) { return context.isNvidia; }, std::move(setting));
}

ConfigDefault OnNonNvidia(ConfigDefault setting)
{
    return When([](const GameConfigContext& context) { return !context.isNvidia; }, std::move(setting));
}

ConfigDefault WithUpscalerFGInput(ConfigDefault setting)
{
    return When([](const GameConfigContext&)
                { return Config::Instance()->FGInput.value_or_default() == FGInput::Upscaler; }, std::move(setting));
}

ConfigDefault WithXeFG(ConfigDefault setting)
{
    return When(
        [](const GameConfigContext&)
        {
            auto& state = State::Instance();
            return state.activeFgOutput == FGOutput::XeFG && state.activeFgInput != FGInput::NoFG &&
                   state.activeFgInput != FGInput::NvngxFG;
        },
        std::move(setting));
}

using enum GameQuirk;

const std::vector<GameConfig> gameConfigs = {

             
                                                                 
    {
        .exes = { "beamng.drive.x64.exe" },
        .defaults = { DxgiSpoofing = false },
        .quirks = { HideFsr4 },
    },

                            
                                                                                                        
    {
        .exes = { "rdr2.exe", "playrdr2.exe" },
        .defaults = { EnableFsr3Inputs = false, DxgiSpoofing = false },
    },

                          
                                                                   
    {
        .exes = { "rdr.exe", "playrdr.exe" },
        .defaults = { DxgiSpoofing = false, FGPreserveSwapChain = false },
        .quirks = { SkipFsr3Method, NoFSRFGFirstSwapchain },
    },

                      
                                                             
    {
        .ueExes = { "visionsofmana" },
        .defaults = { Fsr2Pattern = true, DxgiSpoofing = false },
    },

                    
    {
        .ueExes = { "shf" },
        .defaults = { FGAlwaysCaptureFSRFGSwapchain = true },
    },

                             
    {
        .ueExes = { "beastofreincarnation" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false, FGAlwaysCaptureFSRFGSwapchain = true },
    },

                                     
    {
        .exes = { "fall of avalon.exe" },
        .defaults = { AutoExposure = true },
    },

                              
                                                 
    {
        .exes = { "granblue_fantasy_relink.exe" },
        .defaults = { UseFakenvapi = false },
    },

                      
    {
        .exes = { "pathofexile.exe", "pathofexile_x64.exe", "pathofexile_kg.exe", "pathofexile_x64_kg.exe",
                  "pathofexilesteam.exe", "pathofexile_x64steam.exe" },
        .defaults = { DxgiSpoofing = false },
        .quirks = { LoadD3D12Manually },
    },

                       
                                                                                           
    {
        .exes = { "wwm.exe" },
        .defaults = { DxgiSpoofing = false },
        .quirks = { ForceFGRenderSizeMVs },
    },

                          
                                            
    {
        .exes = { "endfield.exe" },
        .defaults = { UseFakenvapi = false, OnNonNvidia(VulkanSpoofing = true),
                      OnNonNvidia(VulkanExtensionSpoofing = true) },
        .quirks = { ForceCreateD3D12Device, VulkanDLSSBarrierFixup, IgnoreTagsWithoutHudlessForFG },
    },

                            
                                                  
    {
        .exes = { "htgame.exe" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false, UseNtdllHooks = false },
    },

                      
                                                                                               
    {
        .ueExes = { "client" },
        .defaults = { UseNtdllHooks = false, FGPreserveSwapChain = false },
    },

                        
                                                                  
    {
        .exes = { "zenlesszonezero.exe" },
        .quirks = { IgnoreTagsWithoutHudlessForFG },
    },

                                                                   
    {
        .exes = { "sora_1st.exe", "sora_2nd.exe" },
        .defaults = { UseFsr2Dx11Inputs = true, DxgiSpoofing = false },
    },

                     
                                                           
    {
        .exes = { "ninjagaiden4-steam.exe", "ninjagaiden4-wingdk.exe" },
        .defaults = { DxgiSpoofing = false, FGSkipResizeBuffers = false, FGPreserveSwapChain = false,
                      WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                                 
                                      
    {
        .exes = { "doa6lr.exe" },
        .defaults = { DxgiSpoofing = false, FGSkipResizeBuffers = false, FGPreserveSwapChain = false },
    },

                            
                          
    {
        .exes = { "tlou-i.exe", "tlou-i-l.exe" },
        .defaults = { FGAllowedFrameAhead = 2, DxgiSpoofing = false },
    },

                                                                               
      
                                                                              
    {
        .exes = { "kunitsugami.exe", "kunitsugamidemo.exe", "drdr.exe" },
        .defaults = { OnNonNvidia(RestoreComputeSignature = true), DxgiSpoofing = false },
    },
                                                                                                          
                                          
    {
        .exes = { "monsterhunterwilds.exe", "re9.exe", "re9demo.exe", "monster_hunter_stories_3_twisted_reflection.exe",
                  "onimushawots_demo.exe", "onimushawots.exe" },
        .defaults = { RestoreComputeSignature = true, DxgiSpoofing = false },
    },
                          
                                                                 
    {
        .exes = { "monsterhunterrise.exe" },
        .defaults = { RestoreComputeSignature = true },
    },
                                                   
    {
        .exes = { "dd2ccs.exe" },
        .defaults = { OnNonNvidia(RestoreComputeSignature = true), DxgiSpoofing = false,
                      WithUpscalerFGInput(FGDisableHUDFix = true) },
    },
                       
    {
        .exes = { "dd2.exe" },
        .defaults = { RestoreComputeSignature = true, DxgiSpoofing = false,
                      WithUpscalerFGInput(FGDisableHUDFix = true) },
        .quirks = { PregmataFixDLSSModes },
    },
                    
    {
        .exes = { "pragmata_sketchbook.exe" },
        .defaults = { RestoreComputeSignature = true, DxgiSpoofing = false, FGAllowedFrameAhead = 2 },
        .quirks = { PregmataFixDLSSModes },
    },
               
    {
        .exes = { "pragmata.exe" },
        .defaults = { RestoreComputeSignature = true, DxgiSpoofing = false },
        .quirks = { PregmataFixDLSSModes },
    },

                            
                                                                               
    {
        .exes = { "re2.exe", "re3.exe", "re4.exe", "re7.exe", "re8.exe", "devilmaycry5.exe", "streetfighter6.exe" },
        .defaults = { DxgiSpoofing = false, OverlayMenu = false },
    },

                     
                                                
    {
        .exes = { "cyberpunk2077.exe" },
        .defaults = { WithUpscalerFGInput(FGDisableHUDFix = true), DxgiSpoofing = false,
                      ReprojectionDepthCutoff = 0.02f },
        .quirks = { CyberpunkHudlessState, FSRFGHudlessMismatchFixup },
    },

                      
                                                
    {
        .exes = { "forzahorizon5.exe" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false, DxgiSpoofing = false },
    },

                                   
                                                                                                                   
    {
        .exes = { "afop.exe" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false, DxgiSpoofing = false,
                      WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                         
                      
    {
        .exes = { "forza_steamworks_release_final.exe", "forza_gaming.desktop.x64_release_final.exe" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false },
    },

                                        
                                      
    {
        .exes = { "ds.exe" },
        .defaults = { DxgiSpoofing = false, EnableFsr2Inputs = false, EnableFsr3Inputs = false },
    },

                       
    {
        .exes = { "em-win64-shipping.exe" },
        .defaults = { UseNtdllHooks = false },
    },

                            
    {
        .exes = { "talos2-win64-shipping.exe" },
        .defaults = { FGSkipResizeBuffers = false, FGPreserveSwapChain = false },
    },

                            
                                 
    {
        .ueExes = { "thecallistoprotocol" },
        .defaults = { FsrUseFsrInputValues = false, DxgiSpoofing = false, DisableReactiveMask = true,
                      AutoExposure = true },
    },

                                    
                                                
    {
        .exes = { "hitman3.exe" },
        .defaults = { DxgiSpoofing = false, EnableFsr2Inputs = false },
        .quirks = { HitmanReflexHacks },
    },

                      
                                                                                                   
    {
        .exes = { "007firstlight.exe" },
        .defaults = { DxgiSpoofing = false, RestoreComputeSignature = true, ExtendedStateRestore = true,
                      Fsr4DoNotLoadAmdxc64 = true },
        .quirks = { IgnoreValidUntilEvaluateForFG },
    },

                                
                                      
    {
        .exes = { "eldenring.exe" },
        .defaults = { DxgiSpoofing = false },
    },

                                           
                                      
    {
        .exes = { "nightreign.exe" },
        .defaults = { DxgiSpoofing = false, CreateHeaps = false, BuildPipelines = false },
    },

               
                                                               
    {
        .ueExes = { "returnal" },
        .defaults = { DxgiSpoofing = false, MVResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                      ColorResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE },
    },

                               
                                                     
    {
        .exes = { "project_plague-deck-shipping.exe", "project_plague-win64-shipping.exe" },
        .defaults = { SkipFirstFrames = 10 },
    },

                        
    {
        .exes = { "ffxiv_dx11.exe" },
        .defaults = { OverrideVsync = false },
    },
    {
        .exes = { "graphadapterdesc.exe" },
        .quirks = { SkipD3D11FeatureLevelElevation },
    },

                
                                                      
    {
        .exes = { "prey.exe" },
        .defaults = { DontUseNTShared = true, CreateHeaps = false, BuildPipelines = false, DxgiSpoofing = false },
    },

                         
                               
    {
        .ueExes = { "b1" },
        .defaults = { SpoofRegistry = true },
    },

             
                                                                                                    
    {
        .ueExes = { "avowed" },
        .defaults = { AutoExposure = true, ColorResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                      EnableFsr2Inputs = false, EnableFsr3Inputs = false },
    },

                
                                                                                                 
    {
        .exes = { "starfield.exe" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false, DxgiSpoofing = false, AutoExposure = true },
    },

                                                                   
      
                                  
    {
        .exes = { "riftapart.exe" },
        .defaults = { DxgiSpoofing = false },
    },
                                     
    {
        .exes = { "spider-man.exe" },
        .defaults = { DxgiSpoofing = false, WithUpscalerFGInput(FGDisableHUDFix = true) },
        .quirks = { FSRFGHudlessMismatchFixup },
    },
                                                                
    {
        .exes = { "milesmorales.exe", "spider-man2.exe" },
        .defaults = { DxgiSpoofing = false, WithUpscalerFGInput(FGDisableHUDFix = true) },
    },
                                      
    {
        .exes = { "ds2.exe" },
        .defaults = { DxgiSpoofing = false },
        .quirks = { FSRFGHudlessMismatchFixup },
    },
      
                                                                                                                    
                       
      
                                                                      
    {
        .exes = { "horizonzerodawnremastered.exe", "tlou-ii.exe", "tlou-ii-l.exe" },
        .defaults = { DxgiSpoofing = false },
    },
                                              
    {
        .exes = { "horizonforbiddenwest.exe" },
        .defaults = { DxgiSpoofing = false, FGAllowedFrameAhead = 2 },
    },
                                       
    {
        .exes = { "ghostoftsushima.exe" },
        .defaults = { DxgiSpoofing = false, WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                        
                                                     
    {
        .exes = { "dead space.exe" },
        .defaults = { DxgiSpoofing = false, WithXeFG(OverrideVsync = true), WithXeFG(FGXeFGForceBorderless = true),
                      FGSkipResizeBuffers = false },
    },

                                    
                                                               
                          
    {
        .exes = { "metroexodus.exe" },
        .defaults = { DxgiSpoofing = false, WithXeFG(FGXeFGForceBorderless = true), AutoExposure = true,
                      WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                                               
    {
        .exes = { "metro.exe" },
        .defaults = { DxgiSpoofing = false },
    },

                                   
                                                                                               
    {
        .exes = { "kingdomcome.exe" },
        .quirks = { DLSSGFrameLatencyWaitable },
    },

                         
                                                                     
    {
        .exes = { "outlaws.exe", "outlaws_plus.exe" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false, DxgiSpoofing = false,
                      WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                
                                                                             
    {
        .ueExes = { "lop" },
        .defaults = { DxgiSpoofing = false },
    },

                     
                                                       
    {
        .exes = { "crimsondesert.exe" },
        .defaults = { DxgiSpoofing = false },
    },

                              
                                                                                                               
                          
    {
        .exes = { "acmirage.exe", "acmirage_plus.exe" },
        .defaults = { DxgiSpoofing = false, WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                
                                                                           
    {
        .exes = { "dcs.exe" },
        .defaults = { UseFakenvapi = false },
    },

                                                                      
                                      
    {
        .exes = { "xrengine.exe" },
        .defaults = { DxgiSpoofing = false },
    },

                                      
                                                
                          
    {
        .exes = { "dyinglightgame_x64_rwdi.exe" },
        .defaults = { DxgiSpoofing = false, WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                             
                                                
    {
        .exes = { "dyinglightgame_thebeast_x64_rwdi.exe" },
        .defaults = { DxgiSpoofing = false },
    },

                        
                                                                                  
    {
        .exes = { "assettocorsaevo.exe" },
        .defaults = { DxgiSpoofing = false, AutoExposure = true },
    },

                                                                                             
                                                                     
    {
        .exes = { "alanwake2.exe", "gotg.exe", "u4.exe", "u4-l.exe", "tll.exe", "tll-l.exe" },
        .defaults = { DxgiSpoofing = false, WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                    
                                                                                 
                                                                                            
                                                                                   
                                                       
    {
        .exes = { "witcher3.exe" },
        .defaults = { DxgiSpoofing = false },
        .quirks = { CreateSLOnThe2ndDevice, XeFGCameraMotionFill },
    },

                                                   
      
                                                                                            
    {
        .ueExes = { "hellbladegame", "outriders", "medium" },
        .defaults = { DxgiSpoofing = false, ColorResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                      MVResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE },
    },
                                                                                                                  
                             
    {
        .ueExes = { "sackboy", "pumpkinjack", "dungeonhaven" },
        .defaults = { DxgiSpoofing = false, AutoExposure = true,
                      ColorResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                      MVResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE },
    },
                                                               
    {
        .exes = { "observersystemredux.exe" },
        .defaults = { DxgiSpoofing = false, AutoExposure = true,
                      ColorResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                      MVResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE },
    },
                        
    {
        .ueExes = { "pal7" },
        .defaults = { ColorResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,
                      MVResourceBarrier = D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE },
    },

                         
                                       
    {
        .exes = { "watchdogslegion.exe", "watchdogslegion_plus.exe" },
        .defaults = { AutoExposure = true },
    },

                                                                                     
                                                
    {
        .exes = { "acshadows.exe", "acshadows_plus.exe", "acblackflag.exe", "acblackflag_plus.exe",
                  "fbcfirebreak.exe" },
        .defaults = { DxgiSpoofing = false },
    },

                       
                                                                                                                   
    {
        .exes = { "controlresonant.exe" },
        .defaults = { DxgiSpoofing = false, FGPreserveSwapChain = false, SimulateWaitableObject = true },
    },

                                                                                
      
                                                                                                                        
                                                                                                                
                                                                                                                      
                                                                                                                      
                                                                                                        
    {
        .exes = { "crysis3remastered.exe",
                  "darktide.exe",
                  "ronin.exe",
                  "dworigins.exe",
                  "crysisremastered.exe",
                  "crysis2remastered.exe",
                  "sekiro.exe",
                  "gow.exe",
                  "eu5.exe",
                  "needforspeedunbound.exe",
                  "deathloop.exe",
                  "ff7remake_.exe",
                  "farmingsimulator2025game.exe",
                  "nioh3.exe",
                  "fatalframeii.exe",
                  "mouse.exe",
                  "yet another zombie survivors.exe",
                  "voodoo fishin'.exe",
                  "forzahorizon6.exe",
                  "over the hill.exe",
                  "shrot.exe" },
        .defaults = { DxgiSpoofing = false },
    },
                                                              
    {
        .exes = { "nioh2.exe", "control_dx12.exe" },
        .defaults = { DxgiSpoofing = false, AutoExposure = true },
    },

                                   
      
                                                                         
    {
        .ueExes = { "deadisland", "indiana" },
        .defaults = { DisableReactiveMask = true, DxgiSpoofing = false, AutoExposure = true },
    },
                                                                                                                        
                        
    {
        .exes = { "reliccoh3.exe", "saintsrow_dx12.exe" },
        .ueExes = { "scorn", "plagueproject", "caravansandwitch", "genesis" },
        .defaults = { DxgiSpoofing = false },
    },

                              
                                                                                                                     
    {
        .exes = { "wonderlands.exe" },
        .defaults = { DisableReactiveMask = true, DxgiSpoofing = false },
    },

                                                                   
      
                                                                                                         
                                                                                                              
                                                                                                                
                          
    {
        .exes = { "f1_22.exe", "bloom&rage.exe", "flightsimulator.exe", "f1manager24.exe", "acr.exe" },
        .ueExes = { "fmf2", "towers", "metaleden", "bates", "bcg", "banishers", "game", "supraworld", "keeper",
                    "paganidol" },
        .defaults = { EnableFsr2Inputs = false, EnableFsr3Inputs = false },
    },

                                 
      
                                              
    {
        .ueExes = { "redout2", "recolored" },
        .defaults = { DxgiSpoofing = false },
    },

                          
      
                                                                                                           
                    
    {
        .exes = { "dragon age the veilguard.exe", "f1_2020_dx12.exe", "f1_2021_dx12.exe", "gta5_enhanced.exe",
                  "sottr.exe" },
        .ueExes = { "sb" },
        .defaults = { WithUpscalerFGInput(FGDisableHUDFix = true) },
    },

                              
                          
    {
        .exes = { "rottr.exe" },
        .quirks = { SkipD3D11FeatureLevelElevation },
    },

                       
      
                                                                                                
    {
        .exes = { "gwt.exe" },
        .ueExes = { "persistence", "mechwarrior", "ghostrunner", "ghostrunner2" },
        .quirks = { ForceUnrealEngine },
    },
                        
    {
        .exes = { "minecraft.windows.exe" },
        .quirks = { KernelBaseHooks },
    },
                
    {
        .exes = { "roadcraft - retail.exe" },
        .quirks = { FixSlSimulationMarkers },
    },
                               
    {
        .exes = { "jedisurvivor.exe" },
        .defaults = { AutoExposure = true },
    },
                                
    {
        .exes = { "ff7rebirth_.exe" },
        .defaults = { WithUpscalerFGInput(FGDisableHUDFix = true) },
        .quirks = { ForceUnrealEngine },
    },
                
    {
        .ueExes = { "witchfire" },
        .defaults = { FsrUseFsrInputValues = false },
    },
                
    {
        .exes = { "soulstice.exe" },
        .defaults = { AutoExposure = true },
        .quirks = { ForceUnrealEngine },
    },

             
             

                   
    {
        .exes = { "nms.exe" },
        .defaults = { OnNonNvidia(VulkanSpoofing = true) },
        .quirks = { KernelBaseHooks, VulkanDLSSBarrierFixup, FSRFGHudlessMismatchFixup },
    },

                
    {
        .exes = { "nvremixbridge.exe" },
        .defaults = { DxgiSpoofing = false, OnNonNvidia(VulkanExtensionSpoofing = true) },
        .quirks = { LoadVulkanManually, VulkanDLSSBarrierFixup },
    },

                 
    {
        .exes = { "enshrouded.exe" },
        .defaults = { OnNonNvidia(VulkanSpoofing = true), OnNonNvidia(VulkanExtensionSpoofing = true) },
        .quirks = { LoadVulkanManually },
    },

                  
    {
        .exes = { "wwzretail.exe" },
        .defaults = { UseFsr2VulkanInputs = true, OnNonNvidia(VulkanExtensionSpoofing = true), DxgiSpoofing = false },
        .quirks = { ForceDepthD32S8 },
    },

                      
                                   
    {
        .exes = { "bg3.exe" },
        .defaults = { OnNonNvidia(VulkanExtensionSpoofing = true) },
    },

                                         
                                                                           
    {
        .exes = { "thegreatcircle.exe" },
        .defaults = { OnNonNvidia(VulkanExtensionSpoofing = true), DxgiSpoofing = false },
    },

                          
                                                                            
    {
        .exes = { "doomthedarkages.exe" },
        .defaults = { DxgiSpoofing = false },
        .quirks = { ForceCreateD3D12Device },
    },

};

bool MatchesExe(const GameConfig& game, const std::string& exeName)
{
    if (std::ranges::find(game.exes, exeName) != game.exes.end())
        return true;

    for (const auto& name : game.ueExes)
    {
        if (exeName == name + "-win64-shipping.exe" || exeName == name + "-wingdk-shipping.exe")
            return true;
    }

    return false;
}
}             

flag_set<GameQuirk> ApplyGameConfigs(std::string exeName, const GameConfigContext& context)
{
    to_lower_in_place(exeName);
    flag_set<GameQuirk> quirks;

    for (const auto& game : gameConfigs)
    {
        if (!MatchesExe(game, exeName))
            continue;

        for (auto quirk : game.quirks)
            quirks |= quirk;

        for (const auto& setting : game.defaults)
        {
            if (setting.condition != nullptr && !setting.condition(context))
                continue;

                                           
            if (!setting.apply())
                continue;

            LOG_INFO("Game default: {}", setting.text);
            State::Instance().detectedQuirks.push_back(setting.text);
        }
    }

    return quirks;
}
