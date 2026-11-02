// This file is part of the FidelityFX SDK.
//
// Copyright (C) 2024 Advanced Micro Devices, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// SPDX-FileCopyrightText: Copyright 2025 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#ifndef FFX_COMMON_TYPES_H
#define FFX_COMMON_TYPES_H

#if defined(FFX_CPU)
#define FFX_PARAMETER_IN
#define FFX_PARAMETER_OUT
#define FFX_PARAMETER_INOUT
#define FFX_PARAMETER_UNIFORM
#elif defined(FFX_HLSL)
#define FFX_PARAMETER_IN      in
#define FFX_PARAMETER_OUT     out
#define FFX_PARAMETER_INOUT   inout
#define FFX_PARAMETER_UNIFORM uniform
#elif defined(FFX_GLSL)
#define FFX_PARAMETER_IN      in
#define FFX_PARAMETER_OUT     out
#define FFX_PARAMETER_INOUT   inout
#define FFX_PARAMETER_UNIFORM const                                                    
#endif                                                      

#if defined(FFX_CPU)
                                  
   
                     
typedef bool FfxBoolean;

                                          
   
                     
typedef uint8_t FfxUInt8;

                                           
   
                     
typedef uint16_t FfxUInt16;

                                           
   
                     
typedef uint32_t FfxUInt32;

                                           
   
                     
typedef uint64_t FfxUInt64;

                                        
   
                     
typedef int8_t FfxInt8;

                                         
   
                     
typedef int16_t FfxInt16;

                                         
   
                     
typedef int32_t FfxInt32;

                                         
   
                     
typedef int64_t FfxInt64;

                                         
   
                     
typedef float FfxFloat32;

                                                       
   
                     
typedef float FfxFloat32x2[2];

                                                       
   
                     
typedef float FfxFloat32x3[3];

                                                       
   
                     
typedef float FfxFloat32x4[4];

                                              
   
                     
typedef float FfxFloat32x2x2[4];

                                              
   
                     
typedef float FfxFloat32x3x3[9];

                                              
   
                     
typedef float FfxFloat32x3x4[12];

                                              
   
                     
typedef float FfxFloat32x4x4[16];

                                                       
   
                     
typedef int32_t FfxInt32x2[2];

                                                       
   
                     
typedef int32_t FfxInt32x3[3];

                                                       
   
                     
typedef int32_t FfxInt32x4[4];

                                                        
   
                     
typedef uint32_t FfxUInt32x2[2];

                                                         
   
                     
typedef uint32_t FfxUInt32x3[3];

                                                         
   
                     
typedef uint32_t FfxUInt32x4[4];
#endif                         

#if defined(FFX_HLSL)

#define FfxFloat32Mat4 matrix<float, 4, 4>
#define FfxFloat32Mat3 matrix<float, 3, 3>

                                  
   
                      
typedef bool FfxBoolean;

#if FFX_HLSL_SM >= 62

                                                  
                                                                   
   
                      

                                         
   
                        
typedef float32_t FfxFloat32;

                                                       
   
                        
typedef float32_t2 FfxFloat32x2;

                                                       
   
                        
typedef float32_t3 FfxFloat32x3;

                                                       
   
                        
typedef float32_t4 FfxFloat32x4;

                                                                  
typedef float4x4 FfxFloat32x4x4;
typedef float3x4 FfxFloat32x3x4;
typedef float3x3 FfxFloat32x3x3;
typedef float2x2 FfxFloat32x2x2;

                                           
   
                        
typedef uint32_t FfxUInt32;

                                                         
   
                        
typedef uint32_t2 FfxUInt32x2;

                                                         
   
                        
typedef uint32_t3 FfxUInt32x3;

                                                         
   
                        
typedef uint32_t4 FfxUInt32x4;

                                         
   
                        
typedef int32_t FfxInt32;

                                                       
   
                        
typedef int32_t2 FfxInt32x2;

                                                       
   
                        
typedef int32_t3 FfxInt32x3;

                                                       
   
                        
typedef int32_t4 FfxInt32x4;

#else                        

                                                    
                                                                   
   
                      

#define FfxFloat32     float
#define FfxFloat32x2   float2
#define FfxFloat32x3   float3
#define FfxFloat32x4   float4

                                                                  
#define FfxFloat32x4x4 float4x4
#define FfxFloat32x3x4 float3x4
#define FfxFloat32x3x3 float3x3
#define FfxFloat32x2x2 float2x2

                                           
   
                
typedef uint  FfxUInt32;
typedef uint2 FfxUInt32x2;
typedef uint3 FfxUInt32x3;
typedef uint4 FfxUInt32x4;

typedef int  FfxInt32;
typedef int2 FfxInt32x2;
typedef int3 FfxInt32x3;
typedef int4 FfxInt32x4;

#endif                        

#if FFX_HALF

#if FFX_HLSL_SM >= 62

typedef float16_t  FfxFloat16;
typedef float16_t2 FfxFloat16x2;
typedef float16_t3 FfxFloat16x3;
typedef float16_t4 FfxFloat16x4;

                                            
   
                      
typedef uint16_t  FfxUInt16;
typedef uint16_t2 FfxUInt16x2;
typedef uint16_t3 FfxUInt16x3;
typedef uint16_t4 FfxUInt16x4;

                                         
   
                      
typedef int16_t  FfxInt16;
typedef int16_t2 FfxInt16x2;
typedef int16_t3 FfxInt16x3;
typedef int16_t4 FfxInt16x4;
#else                         
typedef min16float  FfxFloat16;
typedef min16float2 FfxFloat16x2;
typedef min16float3 FfxFloat16x3;
typedef min16float4 FfxFloat16x4;

                                            
   
                      
typedef min16uint  FfxUInt16;
typedef min16uint2 FfxUInt16x2;
typedef min16uint3 FfxUInt16x3;
typedef min16uint4 FfxUInt16x4;

                                         
   
                      
typedef min16int  FfxInt16;
typedef min16int2 FfxInt16x2;
typedef min16int3 FfxInt16x3;
typedef min16int4 FfxInt16x4;
#endif                        

#endif             

#endif                          

#if defined(FFX_GLSL)

#define FfxFloat32Mat4 mat4
#define FfxFloat32Mat3 mat3

                                  
   
                      
#define FfxBoolean   bool
#define FfxFloat32   float
#define FfxFloat32x2 vec2
#define FfxFloat32x3 vec3
#define FfxFloat32x4 vec4
#define FfxUInt32    uint
#define FfxUInt32x2  uvec2
#define FfxUInt32x3  uvec3
#define FfxUInt32x4  uvec4
#define FfxInt32     int
#define FfxInt32x2   ivec2
#define FfxInt32x3   ivec3
#define FfxInt32x4   ivec4

                                                                  
#define FfxFloat32x4x4 mat4
#define FfxFloat32x3x4 mat4x3
#define FfxFloat32x3x3 mat3
#define FfxFloat32x2x2 mat2

#if FFX_HALF
#define FfxFloat16   float16_t
#define FfxFloat16x2 f16vec2
#define FfxFloat16x3 f16vec3
#define FfxFloat16x4 f16vec4
#define FfxUInt16    uint16_t
#define FfxUInt16x2  u16vec2
#define FfxUInt16x3  u16vec3
#define FfxUInt16x4  u16vec4
#define FfxInt16     int16_t
#define FfxInt16x2   i16vec2
#define FfxInt16x3   i16vec3
#define FfxInt16x4   i16vec4
#endif             

#if defined(FFX_8_BIT_TYPES) && FFX_8_BIT_TYPES
#define FfxUInt8   uint8_t
#define FfxUInt8x2 u8vec2
#define FfxUInt8x3 u8vec3
#define FfxUInt8x4 u8vec4
#define FfxInt8    int8_t
#define FfxInt8x2  i8vec2
#define FfxInt8x3  i8vec3
#define FfxInt8x4  i8vec4
#endif                    

#endif                          

                  
                                  
                                   

#if FFX_HALF

#if FFX_HLSL_SM >= 62

#define FFX_MIN16_SCALAR(TypeName, BaseComponentType)           typedef BaseComponentType##16_t TypeName;
#define FFX_MIN16_VECTOR(TypeName, BaseComponentType, COL)      typedef vector<BaseComponentType##16_t, COL> TypeName;
#define FFX_MIN16_MATRIX(TypeName, BaseComponentType, ROW, COL) typedef matrix<BaseComponentType##16_t, ROW, COL> TypeName;

#define FFX_16BIT_SCALAR(TypeName, BaseComponentType)           typedef BaseComponentType##16_t TypeName;
#define FFX_16BIT_VECTOR(TypeName, BaseComponentType, COL)      typedef vector<BaseComponentType##16_t, COL> TypeName;
#define FFX_16BIT_MATRIX(TypeName, BaseComponentType, ROW, COL) typedef matrix<BaseComponentType##16_t, ROW, COL> TypeName;

#else                   

#define FFX_MIN16_SCALAR(TypeName, BaseComponentType)           typedef min16##BaseComponentType TypeName;
#define FFX_MIN16_VECTOR(TypeName, BaseComponentType, COL)      typedef vector<min16##BaseComponentType, COL> TypeName;
#define FFX_MIN16_MATRIX(TypeName, BaseComponentType, ROW, COL) typedef matrix<min16##BaseComponentType, ROW, COL> TypeName;

#define FFX_16BIT_SCALAR(TypeName, BaseComponentType)           FFX_MIN16_SCALAR(TypeName, BaseComponentType);
#define FFX_16BIT_VECTOR(TypeName, BaseComponentType, COL)      FFX_MIN16_VECTOR(TypeName, BaseComponentType, COL);
#define FFX_16BIT_MATRIX(TypeName, BaseComponentType, ROW, COL) FFX_MIN16_MATRIX(TypeName, BaseComponentType, ROW, COL);

#endif                   

#else            

#define FFX_MIN16_SCALAR(TypeName, BaseComponentType)           typedef BaseComponentType TypeName;
#define FFX_MIN16_VECTOR(TypeName, BaseComponentType, COL)      typedef vector<BaseComponentType, COL> TypeName;
#define FFX_MIN16_MATRIX(TypeName, BaseComponentType, ROW, COL) typedef matrix<BaseComponentType, ROW, COL> TypeName;

#define FFX_16BIT_SCALAR(TypeName, BaseComponentType)           typedef BaseComponentType TypeName;
#define FFX_16BIT_VECTOR(TypeName, BaseComponentType, COL)      typedef vector<BaseComponentType, COL> TypeName;
#define FFX_16BIT_MATRIX(TypeName, BaseComponentType, ROW, COL) typedef matrix<BaseComponentType, ROW, COL> TypeName;

#endif            

#if defined(FFX_GPU)
                   
#if defined(FFX_HLSL)
FFX_MIN16_SCALAR(FFX_MIN16_F, float);
FFX_MIN16_VECTOR(FFX_MIN16_F2, float, 2);
FFX_MIN16_VECTOR(FFX_MIN16_F3, float, 3);
FFX_MIN16_VECTOR(FFX_MIN16_F4, float, 4);

FFX_MIN16_SCALAR(FFX_MIN16_I, int);
FFX_MIN16_VECTOR(FFX_MIN16_I2, int, 2);
FFX_MIN16_VECTOR(FFX_MIN16_I3, int, 3);
FFX_MIN16_VECTOR(FFX_MIN16_I4, int, 4);

FFX_MIN16_SCALAR(FFX_MIN16_U, uint);
FFX_MIN16_VECTOR(FFX_MIN16_U2, uint, 2);
FFX_MIN16_VECTOR(FFX_MIN16_U3, uint, 3);
FFX_MIN16_VECTOR(FFX_MIN16_U4, uint, 4);

FFX_16BIT_SCALAR(FFX_F16_t, float);
FFX_16BIT_VECTOR(FFX_F16_t2, float, 2);
FFX_16BIT_VECTOR(FFX_F16_t3, float, 3);
FFX_16BIT_VECTOR(FFX_F16_t4, float, 4);

FFX_16BIT_SCALAR(FFX_I16_t, int);
FFX_16BIT_VECTOR(FFX_I16_t2, int, 2);
FFX_16BIT_VECTOR(FFX_I16_t3, int, 3);
FFX_16BIT_VECTOR(FFX_I16_t4, int, 4);

FFX_16BIT_SCALAR(FFX_U16_t, uint);
FFX_16BIT_VECTOR(FFX_U16_t2, uint, 2);
FFX_16BIT_VECTOR(FFX_U16_t3, uint, 3);
FFX_16BIT_VECTOR(FFX_U16_t4, uint, 4);

#define TYPEDEF_MIN16_TYPES(Prefix)   \
    typedef FFX_MIN16_F  Prefix##_F;  \
    typedef FFX_MIN16_F2 Prefix##_F2; \
    typedef FFX_MIN16_F3 Prefix##_F3; \
    typedef FFX_MIN16_F4 Prefix##_F4; \
    typedef FFX_MIN16_I  Prefix##_I;  \
    typedef FFX_MIN16_I2 Prefix##_I2; \
    typedef FFX_MIN16_I3 Prefix##_I3; \
    typedef FFX_MIN16_I4 Prefix##_I4; \
    typedef FFX_MIN16_U  Prefix##_U;  \
    typedef FFX_MIN16_U2 Prefix##_U2; \
    typedef FFX_MIN16_U3 Prefix##_U3; \
    typedef FFX_MIN16_U4 Prefix##_U4;

#define TYPEDEF_16BIT_TYPES(Prefix)   \
    typedef FFX_16BIT_F  Prefix##_F;  \
    typedef FFX_16BIT_F2 Prefix##_F2; \
    typedef FFX_16BIT_F3 Prefix##_F3; \
    typedef FFX_16BIT_F4 Prefix##_F4; \
    typedef FFX_16BIT_I  Prefix##_I;  \
    typedef FFX_16BIT_I2 Prefix##_I2; \
    typedef FFX_16BIT_I3 Prefix##_I3; \
    typedef FFX_16BIT_I4 Prefix##_I4; \
    typedef FFX_16BIT_U  Prefix##_U;  \
    typedef FFX_16BIT_U2 Prefix##_U2; \
    typedef FFX_16BIT_U3 Prefix##_U3; \
    typedef FFX_16BIT_U4 Prefix##_U4;

#define TYPEDEF_FULL_PRECISION_TYPES(Prefix) \
    typedef FfxFloat32   Prefix##_F;         \
    typedef FfxFloat32x2 Prefix##_F2;        \
    typedef FfxFloat32x3 Prefix##_F3;        \
    typedef FfxFloat32x4 Prefix##_F4;        \
    typedef FfxInt32     Prefix##_I;         \
    typedef FfxInt32x2   Prefix##_I2;        \
    typedef FfxInt32x3   Prefix##_I3;        \
    typedef FfxInt32x4   Prefix##_I4;        \
    typedef FfxUInt32    Prefix##_U;         \
    typedef FfxUInt32x2  Prefix##_U2;        \
    typedef FfxUInt32x3  Prefix##_U3;        \
    typedef FfxUInt32x4  Prefix##_U4;
#endif                          

#if defined(FFX_GLSL)

             
#define float2 vec2
#define float3 vec3
#define float4 vec4

#define int32_t  int
#define int32_t2 ivec2
#define int32_t3 ivec3
#define int32_t4 ivec4

             
#if defined(FFX_NFRU_DX12) && FFX_NFRU_DX12
                                                                                                                  
                                                                                                          
#define int8_t  int
#define int8_t2 ivec2
#define int8_t3 ivec3
#define int8_t4 ivec4
#define uint8_t uint
#undef FfxUInt8
#undef FfxUInt8x2
#undef FfxUInt8x3
#undef FfxUInt8x4
#undef FfxInt8
#undef FfxInt8x2
#undef FfxInt8x3
#undef FfxInt8x4
#define FfxUInt8   uint
#define FfxUInt8x2 uvec2
#define FfxUInt8x3 uvec3
#define FfxUInt8x4 uvec4
#define FfxInt8    int
#define FfxInt8x2  ivec2
#define FfxInt8x3  ivec3
#define FfxInt8x4  ivec4
#else
#define int8_t  int8_t
#define int8_t2 i8vec2
#define int8_t3 i8vec3
#define int8_t4 i8vec4
#endif

               
#define uint32_t  uint32_t
#define uint32_t2 u32vec2
#define uint32_t3 u32vec3
#define uint32_t4 u32vec4

#if FFX_HALF

             
#define half  float16_t
#define half2 f16vec2
#define half3 f16vec3
#define half4 f16vec4

              
#define int16_t  int16_t
#define int16_t2 i16vec2
#define int16_t3 i16vec3
#define int16_t4 i16vec4

#define half2x2 f16mat2
#define half2x3 f16mat2x3
#define half2x4 f16mat2x4
#define half3x2 f16mat3x2
#define half3x3 f16mat3
#define half3x4 f16mat3x4
#define half4x2 f16mat4x2
#define half4x3 f16mat4x3
#define half4x4 f16mat4

#define FFX_MIN16_F  float16_t
#define FFX_MIN16_F2 f16vec2
#define FFX_MIN16_F3 f16vec3
#define FFX_MIN16_F4 f16vec4

#define FFX_MIN16_I  int16_t
#define FFX_MIN16_I2 i16vec2
#define FFX_MIN16_I3 i16vec3
#define FFX_MIN16_I4 i16vec4

#define FFX_MIN16_U  uint16_t
#define FFX_MIN16_U2 u16vec2
#define FFX_MIN16_U3 u16vec3
#define FFX_MIN16_U4 u16vec4

#define FFX_16BIT_F  float16_t
#define FFX_16BIT_F2 f16vec2
#define FFX_16BIT_F3 f16vec3
#define FFX_16BIT_F4 f16vec4

#define FFX_16BIT_I  int16_t
#define FFX_16BIT_I2 i16vec2
#define FFX_16BIT_I3 i16vec3
#define FFX_16BIT_I4 i16vec4

#define FFX_16BIT_U  uint16_t
#define FFX_16BIT_U2 u16vec2
#define FFX_16BIT_U3 u16vec3
#define FFX_16BIT_U4 u16vec4

#else             

             
#define half     float
#define half2    vec2
#define half3    vec3
#define half4    vec4

              
#define int16_t  int
#define int16_t2 ivec2
#define int16_t3 ivec3
#define int16_t4 ivec4

#define half2x2 mat2
#define half2x3 mat2x3
#define half2x4 mat2x4
#define half3x2 mat3x2
#define half3x3 mat3
#define half3x4 mat3x4
#define half4x2 mat4x2
#define half4x3 mat4x3
#define half4x4 mat4

#define f16mat2   mat2
#define f16mat2x3 mat2x3
#define f16mat2x4 mat2x4
#define f16mat3x2 mat3x2
#define f16mat3   mat3
#define f16mat3x4 mat3x4
#define f16mat4x2 mat4x2
#define f16mat4x3 mat4x3
#define f16mat4   mat4
#define f16mat4x4 mat4

#define FFX_MIN16_F  float
#define FFX_MIN16_F2 vec2
#define FFX_MIN16_F3 vec3
#define FFX_MIN16_F4 vec4

#define FFX_MIN16_I  int
#define FFX_MIN16_I2 ivec2
#define FFX_MIN16_I3 ivec3
#define FFX_MIN16_I4 ivec4

#define FFX_MIN16_U  uint
#define FFX_MIN16_U2 uvec2
#define FFX_MIN16_U3 uvec3
#define FFX_MIN16_U4 uvec4

#define FFX_16BIT_F  float
#define FFX_16BIT_F2 vec2
#define FFX_16BIT_F3 vec3
#define FFX_16BIT_F4 vec4

#define FFX_16BIT_I  int
#define FFX_16BIT_I2 ivec2
#define FFX_16BIT_I3 ivec3
#define FFX_16BIT_I4 ivec4

#define FFX_16BIT_U  uint
#define FFX_16BIT_U2 uvec2
#define FFX_16BIT_U3 uvec3
#define FFX_16BIT_U4 uvec4

#endif             

#endif                          

#endif                         
#endif                               
