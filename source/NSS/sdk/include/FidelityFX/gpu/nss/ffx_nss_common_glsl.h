/*
 * SPDX-FileCopyrightText: Copyright 2025-2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
 * SPDX-License-Identifier: MIT
 */

#if !defined(FFX_NSS_COMMON_GLSL_H)
#define FFX_NSS_COMMON_GLSL_H

#include "ffx_nss_resources.h"

#if defined(FFX_GPU)

#include "ffx_core.h"

#if QUANTIZED
#define tensor_t    int8_t
#define tensorVec_t int8_t4
#else
#define tensor_t    float
#define tensorVec_t float4
#endif

#if REVERSE_Z
#define INVERTED_DEPTH 1
#endif

                                                                            
#ifndef NSS_SHADER_QUALITY_MODE
#define NSS_SHADER_QUALITY_MODE 1
#endif

#define NSS_SCALE_PRESET_NONE 0
#define NSS_SCALE_PRESET_X2   1

#ifndef SCALE_PRESET_MODE
#define SCALE_PRESET_MODE NSS_SCALE_PRESET_NONE
#endif

                                                                             
                                                                             
                                 
                                         
                                          
                                           
                                            
#if SCALE_PRESET_MODE == NSS_SCALE_PRESET_X2
#if NSS_SHADER_QUALITY_MODE == 0
#define NSS_FILTER_MODE 0
#else
#define NSS_FILTER_MODE 1
#endif
#else
#if NSS_SHADER_QUALITY_MODE == 0
#define NSS_FILTER_MODE 2
#else
#define NSS_FILTER_MODE 3
#endif
#endif

                                                         
                                                                                                      
                                                                                                                      
                                                                                                                 
                                                                                 
#if NSS_SHADER_QUALITY_MODE == 0                  
#define NSS_DEPTH_SCATTER_QUARTER_RES_INPUT 0
#define NSS_PREPROCESS_HALF_RES_INPUT       0
#define NSS_V1_HIGH_LUMA_DERIVATIVE         1
#define NSS_V1_MID_LOW_LUMA_DERIVATIVE      0
#define NSS_PACKED_NEAREST_OFFSET_QUAD      0
#define NSS_USE_SPARSE_2X2_FILTER           0
#define NSS_USE_HISTORY_CATMULL             1
#elif NSS_SHADER_QUALITY_MODE == 1                 
#define NSS_DEPTH_SCATTER_QUARTER_RES_INPUT 1
#define NSS_PREPROCESS_HALF_RES_INPUT       1
#define NSS_V1_HIGH_LUMA_DERIVATIVE         0
#define NSS_V1_MID_LOW_LUMA_DERIVATIVE      1
#define NSS_PACKED_NEAREST_OFFSET_QUAD      1
#define NSS_USE_SPARSE_2X2_FILTER           1
#define NSS_USE_HISTORY_CATMULL             1
#elif NSS_SHADER_QUALITY_MODE == 2                     
#define NSS_DEPTH_SCATTER_QUARTER_RES_INPUT 1
#define NSS_PREPROCESS_HALF_RES_INPUT       1
#define NSS_V1_HIGH_LUMA_DERIVATIVE         0
#define NSS_V1_MID_LOW_LUMA_DERIVATIVE      1
#define NSS_PACKED_NEAREST_OFFSET_QUAD      1
#define NSS_USE_SPARSE_2X2_FILTER           1
#define NSS_USE_HISTORY_CATMULL             0
#else
#error "Unknown shader quality mode!"
#endif

#define NSS_YCOCG_LUMA_DERIVATIVE (NSS_V1_HIGH_LUMA_DERIVATIVE || NSS_V1_MID_LOW_LUMA_DERIVATIVE)

#ifdef INVERTED_DEPTH
#define NSS_NEAREST_STEP(curr_depth, cand_depth) step(curr_depth, cand_depth)
#define NSS_PLANE_DEPTH(prev_depth, curr_depth)  min(prev_depth, curr_depth)
#else
#define NSS_NEAREST_STEP(curr_depth, cand_depth) step(cand_depth, curr_depth)
#define NSS_PLANE_DEPTH(prev_depth, curr_depth)  max(prev_depth, curr_depth)
#endif

                                               
                               
                                               
#if defined(NSS_BIND_CB_NSS)
layout(set = 0, binding = NSS_BIND_CB_NSS, std140) uniform cbNSS_t
{
                                                              
    float4 _DeviceToViewDepth;          
    float4 _JitterOffset;                                         
    float4 _JitterOffsetTm1;                                      
    float4 _ScaleFactor;                                               

    int32_t2 _OutputDims;          
    int32_t2 _InputDims;           

    float2 _InvOutputDims;          
    float2 _InvInputDims;           

    int32_t2 _DepthTm1Size;             
    float2   _InvDepthTm1Size;          

    int32_t2 _InputTensorSize;             
    float2   _InputTensorSizeRcp;          

    int32_t2 _KpnDimension;               
    float2   _MotionVectorScale;          

    float2 _PaddingScale;                                                    
    float  _DepthClipRequiredSepScale;          
    float  _DepthClipPower;                     

    float2  _KpnScale;                                         
    int32_t _DebugViewMode;                                                                       
    float   _NotHistoryReset;          

    float2   _Exposure;                                      
    int32_t2 _IndexModulo;                                            

    int32_t2 _ReducedInputModulo;                                            
    int32_t2 _LutOffset;                                              
    int32_t2 _ColourTransfer;                                                           
    float _ColourReferenceNits;                                    
    float _ColourPadding;
}
cbNSS;

                                                                
                          
                                                                
                      
float4 DeviceToViewDepth()
{
    return cbNSS._DeviceToViewDepth;
}

float4 JitterOffset()
{
    return cbNSS._JitterOffset;
}

float4 JitterOffsetTm1()
{
    return cbNSS._JitterOffsetTm1;
}

                      
half2 Exposure()
{
    return half2(cbNSS._Exposure);
}

half NotHistoryReset()
{
    return half(cbNSS._NotHistoryReset);
}

float2 MotionVectorScale()
{
    return cbNSS._MotionVectorScale;
}

             
int32_t DebugViewMode()
{
    return cbNSS._DebugViewMode;
}

int32_t2 ReducedInputModulo()
{
    return cbNSS._ReducedInputModulo;
}

                                                            
int32_t2 IndexModulo()
{
    return cbNSS._IndexModulo;
}

int32_t2 LutOffset()
{
    return cbNSS._LutOffset;
}

int32_t2 KpnDims()
{
    return cbNSS._KpnDimension;
}

float2 KpnScale()
{
    return cbNSS._KpnScale;
}

#endif                                 

                                                                
                                                                                     
                                                                                    
                                                            
                                                                
#define NSS_DEBUG_VIEW_MODE_ALL                      (0)                  
#define NSS_DEBUG_VIEW_MODE_HISTORY                  (1)                             
#define NSS_DEBUG_VIEW_MODE_DEPTH                    (2)                           
#define NSS_DEBUG_VIEW_MODE_RECONSTRUCTED_PREV_DEPTH (3)                          
#define NSS_DEBUG_VIEW_MODE_NEAREST_OFFSET           (4)                              
#define NSS_DEBUG_VIEW_MODE_LOW_RES_COLOR            (5)                                       
#define NSS_DEBUG_VIEW_MODE_MOTION_VECTOR            (6)                                       
#define NSS_DEBUG_VIEW_MODE_LUMA_DERIV_TM1           (7)                              
#define NSS_DEBUG_VIEW_MODE_TEMPORAL_FEEDBACK        (8)                                           
#define NSS_DEBUG_VIEW_MODE_LR_WARPED_HISTORY        (9)                                          
#define NSS_DEBUG_VIEW_MODE_DISOCCLUSION_MASK        (10)                                
#define NSS_DEBUG_VIEW_MODE_LUMA_DERIV_T             (11)                                               
#define NSS_DEBUG_VIEW_MODE_DEPTH_DILATED            (12)                            
#define NSS_DEBUG_VIEW_MODE_TENSOR_COLOR             (13)                                        
#define NSS_DEBUG_VIEW_MODE_TENSOR_MOTION_DETECTOR   (14)                                       
#define NSS_DEBUG_VIEW_MODE_TENSOR_LUMA_INSTABILITY  (15)                                        
#define NSS_DEBUG_VIEW_MODE_TENSOR_WARP_FEEDBACK     (16)                                     

layout(set = 0, binding = 1000) uniform sampler s_PointClamp;
layout(set = 0, binding = 1001) uniform sampler s_LinearClamp;

                                                                           
                                  
                                                                           

                                                                           
                        
                                                                           
#if defined(NSS_BIND_SRV_INPUT_COLOR_JITTERED)
layout(set = 0, binding = NSS_BIND_SRV_INPUT_COLOR_JITTERED) uniform mediump texture2D r_input_color_jittered;
#define _ColourTex sampler2D(r_input_color_jittered, s_LinearClamp)
#endif

                                                                           
                        
                                                                           
#if defined(NSS_BIND_SRV_INPUT_MOTION_VECTORS)
layout(set = 0, binding = NSS_BIND_SRV_INPUT_MOTION_VECTORS) uniform mediump texture2D r_input_motion_vectors;
#define _MotionTex sampler2D(r_input_motion_vectors, s_LinearClamp)
#endif

                                                                           
                             
                                                                           
#if defined(NSS_BIND_SRV_HISTORY_UPSCALED_COLOR)
layout(set = 0, binding = NSS_BIND_SRV_HISTORY_UPSCALED_COLOR) uniform mediump texture2D r_prev_upscaled_color;
#define _HistoryTex sampler2D(r_prev_upscaled_color, s_LinearClamp)
#endif

                                                                           
                                                                   
                                                                           
#if defined(NSS_BIND_SRV_INPUT_DEPTH)
layout(set = 0, binding = NSS_BIND_SRV_INPUT_DEPTH) uniform highp texture2D r_input_depth;
#define _DepthTex sampler2D(r_input_depth, s_PointClamp)

float2 GatherQuadUvFromTL(int32_t2 base, float2 inv_size)
{
                                                                               
                                                                             
    return (float2(base) + float2(0.75)) * inv_size;
}

float4 GatherDepthQuadTLBR(int32_t2 base, float2 inv_size)
{
    return textureGather(_DepthTex, GatherQuadUvFromTL(base, inv_size), 0).wzxy;
}

#endif

                                                                           
                                                                           
                                                                              
                                                                           
#if defined(NSS_BIND_UAV_DEPTH_TM1)
layout(set = 0, binding = NSS_BIND_UAV_DEPTH_TM1, r32ui) coherent uniform uimage2D rw_reconstructed_prev_depth;
#endif

#define FLT_MIN            1.175494351e-38
#define MEDIUMP_FLT_MAX    65504.f
#define MEDIUMP_FLT_MIN    0.00006103515625
#define FLT_EPS            MEDIUMP_FLT_MIN
#define SaturateMediump(x) min(x, MEDIUMP_FLT_MAX)


                                                                               
                                                                          
vec3 NssDecodeInput(vec3 c) {
    int mode = cbNSS._ColourTransfer.x;
    if (mode == 0) return c;
    c = max(c, vec3(0.0));
    if (mode == 1) return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), greaterThan(c, vec3(0.04045)));
    const float m1=2610.0/16384.0, m2=2523.0/32.0;
    const float c1=3424.0/4096.0, c2=2413.0/128.0, c3=2392.0/128.0;
    vec3 p=pow(clamp(c,0.0,1.0),vec3(1.0/m2));
    return pow(max(p-c1,0.0)/max(c2-c3*p,vec3(1e-6)),vec3(1.0/m1)) * (10000.0 / cbNSS._ColourReferenceNits);
}
vec3 NssEncodeOutput(vec3 c) {
    int mode=cbNSS._ColourTransfer.y;
    if (mode == 0) return c;
    c=max(c,vec3(0.0));
    if (mode == 1) return mix(c*12.92,1.055*pow(c,vec3(1.0/2.4))-0.055,greaterThan(c,vec3(0.0031308)));
    const float m1=2610.0/16384.0, m2=2523.0/32.0;
    const float c1=3424.0/4096.0, c2=2413.0/128.0, c3=2392.0/128.0;
    vec3 p=pow(clamp(c*(cbNSS._ColourReferenceNits/10000.0),0.0,1.0),vec3(m1));
    return pow((c1+c2*p)/(1.0+c3*p),vec3(m2));
}
#if defined(NSS_BIND_SRV_INPUT_COLOR_JITTERED)
vec3 NssSampleInput(float2 uv) {
    if (cbNSS._ColourTransfer.x == 0) return textureLod(_ColourTex,uv,0.0).rgb;
                                                                              
                                                                 
    ivec2 size=textureSize(_ColourTex,0);
    vec2 pos=uv*vec2(size)-0.5, f=fract(pos);
    ivec2 p=ivec2(floor(pos));
    vec3 a=NssDecodeInput(texelFetch(_ColourTex,clamp(p,ivec2(0),size-1),0).rgb);
    vec3 b=NssDecodeInput(texelFetch(_ColourTex,clamp(p+ivec2(1,0),ivec2(0),size-1),0).rgb);
    vec3 c=NssDecodeInput(texelFetch(_ColourTex,clamp(p+ivec2(0,1),ivec2(0),size-1),0).rgb);
    vec3 d=NssDecodeInput(texelFetch(_ColourTex,clamp(p+ivec2(1,1),ivec2(0),size-1),0).rgb);
    return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
#endif

                                      
vec3 SafeHDR(vec3 c)
{
    return vec3(clamp(c, 0.f, MEDIUMP_FLT_MAX));
}

                                                                                     
void Bicubic2DCatmullRom(in vec2 uv, in vec2 size, in vec2 invSize, out vec2 samples[3], out vec2 weights[3])
{
    uv *= size;

    vec2 tc = floor(uv - 0.5) + 0.5;
    vec2 f  = uv - tc;
    vec2 f2 = f * f;
    vec2 f3 = f2 * f;

    vec2 w0 = f2 - 0.5 * (f3 + f);
    vec2 w1 = 1.5 * f3 - 2.5 * f2 + 1.f;
    vec2 w3 = 0.5 * (f3 - f2);
    vec2 w2 = 1.f - w0 - w1 - w3;

    weights[0] = w0;
    weights[1] = w1 + w2;
    weights[2] = w3;

    samples[0] = tc - 1.f;
    samples[1] = tc + w2 / weights[1];
    samples[2] = tc + 2.f;

    samples[0] *= invSize;
    samples[1] *= invSize;
    samples[2] *= invSize;
}

#define BICUBIC_CATMULL_ROM_SAMPLES 5U

struct CatmullRomSamples
{
                                                               
    uint Count;

                                                      
    vec2 UV[BICUBIC_CATMULL_ROM_SAMPLES];

                             
    float Weight[BICUBIC_CATMULL_ROM_SAMPLES];

                                                                                            
    float FinalMultiplier;
};

CatmullRomSamples GetBicubic2DCatmullRomSamples(vec2 uv, vec2 size, in vec2 invSize)
{
    vec2 weights[3];
    vec2 samples[3];
    Bicubic2DCatmullRom(uv, size, invSize, samples, weights);

    CatmullRomSamples crSamples;
    crSamples.Count = BICUBIC_CATMULL_ROM_SAMPLES;

                                           
    crSamples.UV[0] = vec2(samples[1].x, samples[0].y);
    crSamples.UV[1] = vec2(samples[0].x, samples[1].y);
    crSamples.UV[2] = vec2(samples[1].x, samples[1].y);
    crSamples.UV[3] = vec2(samples[2].x, samples[1].y);
    crSamples.UV[4] = vec2(samples[1].x, samples[2].y);

    crSamples.Weight[0] = weights[1].x * weights[0].y;
    crSamples.Weight[1] = weights[0].x * weights[1].y;
    crSamples.Weight[2] = weights[1].x * weights[1].y;
    crSamples.Weight[3] = weights[2].x * weights[1].y;
    crSamples.Weight[4] = weights[1].x * weights[2].y;

                                          
    float cornerWeights;
    cornerWeights = crSamples.Weight[0];
    cornerWeights += crSamples.Weight[1];
    cornerWeights += crSamples.Weight[2];
    cornerWeights += crSamples.Weight[3];
    cornerWeights += crSamples.Weight[4];
    crSamples.FinalMultiplier = 1.f / cornerWeights;

    return crSamples;
}

float sigmoid(float x)
{
                                     
    return (1.f / (1.f + exp(-x)));
}

vec2 sigmoid(vec2 x)
{
                                     
    return (1.f / (1.f + exp(-x)));
}

vec3 sigmoid(vec3 x)
{
                                     
    return (1.f / (1.f + exp(-x)));
}

vec4 sigmoid(vec4 x)
{
                                     
    return (1.f / (1.f + exp(-x)));
}

vec3 clip_aabb(vec3 minc, vec3 maxc, vec3 history)
{
    vec3  center    = 0.5f * (maxc + minc);
    vec3  extents   = 0.5f * (maxc - minc);
    vec3  offset    = history - center;
    vec3  ts        = abs(extents / (offset + FLT_EPS));
    float t         = clamp(min(min(ts.r, ts.g), ts.b), 0.0, 1.0);
    vec3  rectified = center + offset * t;
    return rectified;
}

vec3 RGBToYCoCg(vec3 Rgb)
{
    vec3 YCoCg;
    YCoCg.y   = Rgb.r - Rgb.b;
    float tmp = Rgb.b + YCoCg.y / 2.0;
    YCoCg.z   = Rgb.g - tmp;
    YCoCg.x   = tmp + YCoCg.z / 2.0;
    return YCoCg;
}

float RGBToY(vec3 Rgb)
{
    return 0.25 * Rgb.r + 0.5 * Rgb.g + 0.25 * Rgb.b;
}

vec3 YCoCgToRGB(vec3 YCoCg)
{
    vec3  Rgb;
    float tmp = YCoCg.x - YCoCg.z / 2.0;
    Rgb.g     = YCoCg.z + tmp;
    Rgb.b     = tmp - YCoCg.y / 2.0;
    Rgb.r     = Rgb.b + YCoCg.y;
    return Rgb;
}

float GetViewSpaceDepth(float fDeviceDepth)
{
    return (cbNSS._DeviceToViewDepth[1] / (fDeviceDepth - cbNSS._DeviceToViewDepth[0]));
}

#define lerp mix

#if FFX_HALF
                                          
half rcp(half x)
{
    return half(1.HF) / x;
}
half2 rcp(half2 x)
{
    return half2(1.HF) / x;
}
half3 rcp(half3 x)
{
    return half3(1.HF) / x;
}
half4 rcp(half4 x)
{
    return half4(1.HF) / x;
}

                                               
half saturate(half x)
{
    return clamp(x, half(0.HF), half(1.HF));
}
half2 saturate(half2 x)
{
    return clamp(x, half2(0.HF), half2(1.HF));
}
half3 saturate(half3 x)
{
    return clamp(x, half3(0.HF), half3(1.HF));
}
half4 saturate(half4 x)
{
    return clamp(x, half4(0.HF), half4(1.HF));
}
#endif

                                          
float rcp(float x)
{
    return float(1.0f) / x;
}
float2 rcp(float2 x)
{
    return float2(1.0f) / x;
}
float3 rcp(float3 x)
{
    return float3(1.0f) / x;
}
float4 rcp(float4 x)
{
    return float4(1.0f) / x;
}

                                               
float saturate(float x)
{
    return clamp(x, 0.f, 1.f);
}
float2 saturate(float2 x)
{
    return clamp(x, float2(0.f), float2(1.f));
}
float3 saturate(float3 x)
{
    return clamp(x, float3(0.f), float3(1.f));
}
float4 saturate(float4 x)
{
    return clamp(x, float4(0.f), float4(1.f));
}

#define MAX_FP16      65504.HF
#define EPS           1e-7HF
#define MIN_SUMW_HALF 6.1035156e-5HF

#define TONEMAP_KARIS
                           

#if defined(TONEMAP_KARIS)
half3 Tonemap(half3 x)
{
                       
                                                                 

                                                        
    half3 xc = clamp(x, half3(0.HF), half3(MAX_FP16));

                                                              
    float m = max(max(float(xc.r), float(xc.g)), float(xc.b));

    return half3(float3(xc) * (1.0f / (1.0f + m)));
}

half3 InverseTonemap(half3 x)
{
                               
                                                                 
    x = clamp(x, half3(0.HF), half3(1.HF - EPS));
    return x * rcp(half3(1.HF) - max(max(x.r, x.g), x.b));
}
#elif defined(TONEMAP_REINHARD)
vec3 Tonemap(vec3 colour)
{
                       
    return colour / (vec3(1.f) + colour);
}

vec3 TonemapExp(vec3 colour, float exponent)
{
                       
    colour = colour * exp(exponent);
    return colour / (vec3(1.f) + colour);
}

vec3 InverseTonemap(vec3 colour)
{
                       
    return colour / (vec3(1.f) - colour);
}

vec4 Tonemap(vec4 colour)
{
                       
    return colour / (vec4(1.f) + colour);
}

vec4 InverseTonemap(vec4 colour)
{
                       
    return colour / (vec4(1.f) - colour);
}

#if FFX_HALF
half3 Tonemap(half3 colour)
{
                       
    return colour / (half3(1.f) + colour);
}

half3 TonemapExp(half3 colour, half exponent)
{
                       
    colour = colour * exp(exponent);
    return colour / (half3(1.f) + colour);
}

half3 InverseTonemap(half3 colour)
{
                       
    return colour / (half3(1.f) - colour);
}

half4 Tonemap(half4 colour)
{
                       
    return colour / (half4(1.f) + colour);
}

half4 InverseTonemap(half4 colour)
{
                       
    return colour / (half4(1.f) - colour);
}
#endif
#endif

bool IsOnScreen(int32_t2 pos, int32_t2 size)
{
    return all(lessThan(uint32_t2(pos), uint32_t2(size)));
}

half Luminance(half3 rgb)
{
                                                           
    return dot(rgb, half3(0.2126, 0.7152, 0.0722));
}

                      
                                                                                             
                                                                                        

half Dequantize(half i, half2 quant_params)
{
    return (i - quant_params.y) * quant_params.x;
}

half2 Dequantize(half2 i, half2 quant_params)
{
    return (i - quant_params.y) * quant_params.x;
}

half3 Dequantize(half3 i, half2 quant_params)
{
    return (i - quant_params.y) * quant_params.x;
}

half4 Dequantize(half4 i, half2 quant_params)
{
    return (i - quant_params.y) * quant_params.x;
}

int8_t Quantize(half f, half2 quant_params)
{
    return int8_t(clamp(round(f * quant_params.x + quant_params.y), half(-128.HF), half(127.HF)));
}

int8_t2 Quantize(half2 f, half2 quant_params)
{
    return int8_t2(clamp(round(f * quant_params.x + quant_params.y), half2(-128.HF), half2(127.HF)));
}

int8_t3 Quantize(half3 f, half2 quant_params)
{
    return int8_t3(clamp(round(f * quant_params.x + quant_params.y), half3(-128.HF), half3(127.HF)));
}

int8_t4 Quantize(half4 f, half2 quant_params)
{
    return int8_t4(clamp(round(f * quant_params.x + quant_params.y), half4(-128.HF), half4(127.HF)));
}

half3 SafeColour(half3 x)
{
    return clamp(x, half3(0.HF), half3(MAX_FP16));
}

                
                                                                                             
                                                                                      
                                                                                         
                                                                                 

uint8_t EncodeNearestDepthCoord(int32_t2 o)
{
                                                                             
                                                                    
    o = clamp(o, ivec2(-2), ivec2(2));
    return uint8_t(((o.y + 2) << 3) | (o.x + 2));                
}

int32_t2 DecodeNearestDepthCoord(int32_t code)
{
    int32_t x = int32_t(code & 0x7) - 2;                    
    int32_t y = int32_t((code >> 3) & 0x7) - 2;             
    return int32_t2(x, y);
}

struct BilinearSamplingData
{
    int32_t2 iOffsets[4];
    float    fWeights[4];
    int32_t2 iBasePos;
};

BilinearSamplingData GetBilinearSamplingData(float2 fUv, int32_t2 iSize)
{
    BilinearSamplingData data;
    float2               fPxSample = (fUv * float2(iSize)) - float2(0.5f, 0.5f);
    data.iBasePos                  = int32_t2(floor(fPxSample));
    float2 fPxFrac                 = fract(fPxSample);

    data.iOffsets[0] = int32_t2(0, 0);
    data.iOffsets[1] = int32_t2(1, 0);
    data.iOffsets[2] = int32_t2(0, 1);
    data.iOffsets[3] = int32_t2(1, 1);

    data.fWeights[0] = (1.f - fPxFrac.x) * (1.f - fPxFrac.y);
    data.fWeights[1] = (fPxFrac.x) * (1.f - fPxFrac.y);
    data.fWeights[2] = (1.f - fPxFrac.x) * (fPxFrac.y);
    data.fWeights[3] = (fPxFrac.x) * (fPxFrac.y);

    return data;
}

#endif                         

                                                                
                                         
                                                                
#if defined(NSS_BIND_UAV_DEBUG_VIEWS)
layout(set = 0, binding = NSS_BIND_UAV_DEBUG_VIEWS, r11f_g11f_b10f) uniform mediump image2D rw_debug_views;
void StoreDebugView(int32_t2 iPxPos, float4 v)
{
    imageStore(rw_debug_views, iPxPos, v);
}
int32_t2 GetDebugViewDimensions()
{
    return cbNSS._OutputDims;
}
#endif                                          

                                                                
                                                    
                                                                
#if defined(NSS_BIND_RENDER_TARGET_DEBUG_VIEWS)
layout(location = NSS_BIND_RENDER_TARGET_DEBUG_VIEWS) out mediump vec4 rw_debug_views;
void StoreDebugView(int32_t2 iPxPos, float4 v)
{
    rw_debug_views = v;
}
int32_t2 GetDebugViewDimensions()
{
    return cbNSS._OutputDims;
}
#endif                                                    

#endif                                   
