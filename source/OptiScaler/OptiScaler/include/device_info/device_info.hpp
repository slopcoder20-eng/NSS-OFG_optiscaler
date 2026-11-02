// From https://github.com/GPUOpen-Tools/device_info licensed under MIT

//==============================================================================
/// Copyright Advanced Micro Devices, Inc. All rights reserved.
/// @author AMD Developer Tools Team
/// @file
/// @brief device_info library interface.
//==============================================================================

#ifndef DEVICE_INFO_HPP_
#define DEVICE_INFO_HPP_

#include <cstdint>
#include <limits>
#include <optional>

namespace device_info
{
                            
enum class AsicType : std::int8_t
{
    kUndefinedAsic = -1,                    
    kTahitiPro,                             
    kTahitiXt,                             
    kPitcairnPro,                             
    kPitcairnXt,                             
    kCapeVerdePro,                              
    kCapeVerdeXt,                              
    kOland,                                             
    kHainan,                            
    kBonaire,                                               
    kHawaii,                            
    kKalindi,                       
    kSpectre,                               
    kSpectreSl,                                
    kSpectreLite,                                
    kSpooky,                               
    kIceland,                            
    kTonga,                            
    kCarrizo,                       
    kCarrizoEmb,                             
    kFiji,                            
    kStoney,                            
    kEllesmere,                            
    kBaffin,                            
    kGfx8_0_4,                            
    kVegaM1,                           
    kVegaM2,                           
    kGfx9_0_0,                            
    kGfx9_0_2,                            
    kGfx9_0_4,                            
    kGfx9_0_6,                            
    kGfx9_0_9,                            
    kGfx9_0_A,                            
    kGfx9_0_C,                            
    kGfx9_4_2,                            
    kGfx9_5_0,                            
    kGfx10_1_0,                            
    kGfx10_1_0Xl,                             
    kGfx10_1_2,                            
    kGfx10_1_2X,                             
    kGfx10_1_2Xt,                             
    kGfx10_1_1,                            
    kGfx10_3_0,                            
    kGfx10_3_0Xt,                             
    kGfx10_3_0Xtx,                             
    kGfx10_3_1,                            
    kGfx10_3_2,                            
    kGfx10_3_2Xt,                             
    kGfx10_3_3,                            
    kGfx10_3_4,                            
    kGfx10_3_5,                            
    kGfx10_3_6,                            
    kGfx11_0_0,                            
    kGfx11_0_0Xt,                             
    kGfx11_0_0Gre,                             
    kGfx11_0_0M,                             
    kGfx11_0_1,                            
    kGfx11_0_1Xt,                             
    kGfx11_0_2,                            
    kGfx11_0_2Xt,                             
    kGfx11_0_3,                            
    kGfx11_0_3A,                            
    kGfx11_0_3B,                            
    kGfx11_5_0,                            
    kGfx11_5_1,                            
    kGfx11_5_2,                            
    kGfx11_5_3,                            
    kGfx11_5_3A,                            
    kGfx12_0_0,                            
    kGfx12_0_0Xt,                             
    kGfx12_0_1Gre,                             
    kGfx12_0_1,                            
    kGfx12_0_1Xt,                             
    kTotalAsics                                                   
};

                                      
enum class HwGeneration : std::uint8_t
{
    kUndefinedGeneration,                                    
    kNvidia,                                                                                 
    kIntel,                                                                                 
    kSouthernIsland,                          
    kFirstAmd = kSouthernIsland,                          
    kSeaIsland,                               
    kVolcanicIsland,                          
    kGfx9,                                    
    kGfx10,                                    
    kGfx10_3,                                    
    kGfx11,                                    
    kCdna,                                  
    kCdna2,                                 
    kCdna3,                                 
    kGfx12,                                    
    kCdna4,                                 
    kGfx11_5,                                    
    kTotalHwGenerations                                                                  
};

              
struct CardInfo
{
    AsicType asic_type;                        
    uint32_t device_id;                                
    uint32_t revision_id;                                
    HwGeneration generation;                             
    bool is_apu;                                                                         
    const char* gfx_target;                                                                           
    const char* marketing_name;                                  
};

                
struct DeviceInfo
{
    uint8_t num_shader_engines;                                 
    uint8_t max_wave_per_simd;                                       
    uint8_t clocks_per_primitive;                                                       
    uint8_t num_sq_counters;                                     
    uint8_t num_prim_pipes;                                      
    uint8_t wave_size;                                
    uint8_t num_sh_per_se;                                                       
    uint8_t num_cus;                                           
    uint8_t num_simd_per_cu;                                            
    uint16_t num_vgpr_per_simd;                                 
};

                              
   
                                        
   
                                  
[[nodiscard]] constexpr uint32_t TotalSimds(const DeviceInfo& info) noexcept
{
    return info.num_simd_per_cu * info.num_cus;
}

                                      
   
                                        
   
                                          
[[nodiscard]] constexpr uint32_t TotalShaderArrays(const DeviceInfo& info) noexcept
{
    return info.num_sh_per_se * info.num_shader_engines;
}

                              
   
                                        
   
                                  
[[nodiscard]] constexpr uint32_t TotalVgprs(const DeviceInfo& info) noexcept
{
    return TotalSimds(info) * info.num_vgpr_per_simd;
}

constexpr uint32_t kRevisionIdAny =
    std::numeric_limits<uint32_t>::max();                                                   
constexpr uint32_t kAmdVendorId = 0x1002;                        

                                                    
                                                                                 
struct AdapterId
{
    uint32_t vendor_id;                  
    uint32_t device_id;                  
    uint32_t revision_id;                  
};

                                                                                          
   
                                                                                                             
                                                    
   
                                                  
[[nodiscard]] std::optional<CardInfo> GetCardInfo(const AdapterId& id) noexcept;

                                                                                             
   
                                      
   
                                                    
[[nodiscard]] std::optional<DeviceInfo> GetDeviceInfo(const CardInfo& info) noexcept;

                                
   
                                        
                                                                           
   
                                             
[[nodiscard]] std::optional<uint32_t> GetTotalLdsSizeInBytes(HwGeneration gen, const DeviceInfo& info) noexcept;
}                         

#endif
