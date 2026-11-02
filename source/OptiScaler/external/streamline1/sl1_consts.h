/*
 * Copyright (c) 2022 NVIDIA CORPORATION. All rights reserved
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#pragma once

#include <stdint.h>

#pragma warning(disable : 4005)

#define SL_ENUM_OPERATORS_64(T)                                                                                        \
    inline bool operator&(T a, T b) { return ((uint64_t) a & (uint64_t) b) != 0; }                                     \
                                                                                                                       \
    inline T& operator&=(T& a, T b)                                                                                    \
    {                                                                                                                  \
        a = (T) ((uint64_t) a & (uint64_t) b);                                                                         \
        return a;                                                                                                      \
    }                                                                                                                  \
                                                                                                                       \
    inline T operator|(T a, T b) { return (T) ((uint64_t) a | (uint64_t) b); }                                         \
                                                                                                                       \
    inline T& operator|=(T& lhs, T rhs)                                                                                \
    {                                                                                                                  \
        lhs = (T) ((uint64_t) lhs | (uint64_t) rhs);                                                                   \
        return lhs;                                                                                                    \
    }                                                                                                                  \
                                                                                                                       \
    inline T operator~(T a) { return (T) ~((uint64_t) a); }

#define SL_ENUM_OPERATORS_32(T)                                                                                        \
    inline bool operator&(T a, T b) { return ((uint32_t) a & (uint32_t) b) != 0; }                                     \
                                                                                                                       \
    inline T& operator&=(T& a, T b)                                                                                    \
    {                                                                                                                  \
        a = (T) ((uint32_t) a & (uint32_t) b);                                                                         \
        return a;                                                                                                      \
    }                                                                                                                  \
                                                                                                                       \
    inline T operator|(T a, T b) { return (T) ((uint32_t) a | (uint32_t) b); }                                         \
                                                                                                                       \
    inline T& operator|=(T& lhs, T rhs)                                                                                \
    {                                                                                                                  \
        lhs = (T) ((uint32_t) lhs | (uint32_t) rhs);                                                                   \
        return lhs;                                                                                                    \
    }                                                                                                                  \
                                                                                                                       \
    inline T operator~(T a) { return (T) ~((uint32_t) a); }

namespace sl1
{
                                                                          
constexpr float INVALID_FLOAT = 3.40282346638528859811704183484516925440e38f;
constexpr uint32_t INVALID_UINT = 0xffffffff;

struct float2
{
    float2() : x(INVALID_FLOAT), y(INVALID_FLOAT) {}
    float2(float _x, float _y) : x(_x), y(_y) {}
    float x, y;
};

struct float3
{
    float3() : x(INVALID_FLOAT), y(INVALID_FLOAT), z(INVALID_FLOAT) {}
    float3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
    float x, y, z;
};

struct float4
{
    float4() : x(INVALID_FLOAT), y(INVALID_FLOAT), z(INVALID_FLOAT), w(INVALID_FLOAT) {}
    float4(float _x, float _y, float _z, float _w) : x(_x), y(_y), z(_z), w(_w) {}
    float x, y, z, w;
};

struct float4x4
{
                                                       
    inline float4& operator[](uint32_t i) { return row[i]; }
    inline const float4& operator[](uint32_t i) const { return row[i]; }
    inline void setRow(uint32_t i, const float4& v) { row[i] = v; }
    inline const float4& getRow(uint32_t i) { return row[i]; }

  private:
                        
    float4 row[4];
};

struct Extent
{
    uint32_t top {};
    uint32_t left {};
    uint32_t width {};
    uint32_t height {};

    inline operator bool() const { return width != 0 && height != 0; }
    inline bool operator==(const Extent& rhs) const
    {
        return top == rhs.top && left == rhs.left && width == rhs.width && height == rhs.height;
    }
    inline bool operator!=(const Extent& rhs) const { return !operator==(rhs); }
};

                                                                          
enum Boolean : char
{
    eFalse,
    eTrue,
    eInvalid
};

                                                                                        
struct Constants
{
                                                                           
                                                                              
                                                                                          

                                                                               
    float4x4 cameraViewToClip;
                                                                                     
    float4x4 clipToCameraView;
                                                                                            
    float4x4 clipToLensClip;
                                                                                         
                                                                                    
    float4x4 clipToPrevClip;
                                                                                         
                                                 
    float4x4 prevClipToClip;

                                           
    float2 jitterOffset;
                                                                                                    
    float2 mvecScale;
                                                           
    float2 cameraPinholeOffset;
                                                 
    float3 cameraPos;
                                                  
    float3 cameraUp;
                                                     
    float3 cameraRight;
                                                       
    float3 cameraFwd;

                                                  
    float cameraNear = INVALID_FLOAT;
                                                 
    float cameraFar = INVALID_FLOAT;
                                                  
    float cameraFOV = INVALID_FLOAT;
                                                                                    
    float cameraAspectRatio = INVALID_FLOAT;
                                                                                                       
                                                                                                         
    float motionVectorsInvalidValue = INVALID_FLOAT;

                                                                                             
    Boolean depthInverted = Boolean::eInvalid;
                                                                  
    Boolean cameraMotionIncluded = Boolean::eInvalid;
                                                  
    Boolean motionVectors3D = Boolean::eInvalid;
                                                                                                          
    Boolean reset = Boolean::eInvalid;
                                                                                                                  
    Boolean notRenderingGameFrames = Boolean::eInvalid;
                                                            
    Boolean orthographicProjection = Boolean::eFalse;
                                                               
    Boolean motionVectorsDilated = Boolean::eFalse;
                                                        
    Boolean motionVectorsJittered = Boolean::eFalse;

                                                          
    void* ext = {};
};

}                 
