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

#pragma once

#include "pch.hpp"
#include <optional>

                                            
                                                         
   
                   

                                                                          
                                                                            
   
                           
struct IShaderBinary
{
                               
       
                
            
       
                               
    IShaderBinary()
    {
    }

                               
       
                
            
       
                               
    virtual ~IShaderBinary()
    {
    }

                                                                  
                                                  
       
                
                                                      
       
                               
    virtual uint8_t* BufferPointer() = 0;

                                                                   
                                                  
       
                
                                 
       
                               
    virtual size_t BufferSize() = 0;
};

                                                                             
   
                           
struct ShaderResourceInfo
{
    std::string name;                                  
    uint32_t    binding;                             
    uint32_t    count;                                        
    uint32_t    space;                            
};

                                                                              
                                                                                     
                   
   
                           
struct IReflectionData
{
    IReflectionData()
    {
    }
    virtual ~IReflectionData()
    {
    }

    std::vector<ShaderResourceInfo> constantBuffers;                                                                        
    std::vector<ShaderResourceInfo> srvTextures;                                                                              
    std::vector<ShaderResourceInfo> uavTextures;                                                                              
    std::vector<ShaderResourceInfo> srvBuffers;                                                                              
    std::vector<ShaderResourceInfo> uavBuffers;                                                                              
    std::vector<ShaderResourceInfo> samplers;                                                                                          
    std::vector<ShaderResourceInfo> rtAccelerationStructures;                                                                      
    std::vector<ShaderResourceInfo> rtTextures;                                                                           
    std::vector<ShaderResourceInfo> srvTensors;                                                                              
    std::vector<ShaderResourceInfo> uavTensors;                                                                              
};

                                                                                       
                                        
   
                           
struct Permutation
{
    uint32_t                         key = 0;                                                          
    std::string                      hashDigest;                                                 
    std::string                      name;                                                   
    std::string                      headerFileName;                                                     
    std::vector<std::wstring>        defines;                                                   
    std::shared_ptr<IShaderBinary>   shaderBinary   = nullptr;                                               
    std::shared_ptr<IReflectionData> reflectionData = nullptr;                                                             

    fs::path                        sourcePath;                                                          
    std::unordered_set<std::string> dependencies;                                                            
    std::optional<uint32_t>         identicalTo = {};                                                              
};

                                                                               
                                              
   
                           
class ICompiler
{
protected:
    std::string m_ShaderPath;
    std::string m_ShaderName;
    std::string m_ShaderFileName;
    std::string m_OutputPath;
    bool        m_DisableLogs;
    bool        m_DebugCompile;

public:
                                      
       
                                                                     
                                                          
                                                                              
                                                                     
                                                                                       
                                                                                             
       
                
            
       
                               
    ICompiler(const std::string& shaderPath,
              const std::string& shaderName,
              const std::string& shaderFileName,
              const std::string& outputPath,
              bool               disableLogs,
              bool               debugCompile)
        : m_ShaderPath(shaderPath)
        , m_ShaderName(shaderName)
        , m_ShaderFileName(shaderFileName)
        , m_OutputPath(outputPath)
        , m_DisableLogs(disableLogs)
        , m_DebugCompile(debugCompile)
    {
    }

                                     
       
                
            
       
                               
    virtual ~ICompiler()
    {
    }

                                                                  
                                                  
       
                                                                                     
                                                                                     
                                                                                             
       
                
                                           
       
                               
    virtual bool Compile(Permutation& permutation, const std::vector<std::string>& arguments, std::mutex& writeMutex) = 0;

                                                                    
                                                  
       
                                                                                                    
       
                
                                           
       
                               
    virtual bool ExtractReflectionData(Permutation& permutation) = 0;

                                                                                          
                                                  
       
                                                                                     
                                                                                           
                                                                                                    
       
                
            
       
                               
    virtual void WriteBinaryHeaderReflectionData(FILE* fp, const Permutation& permutation, std::mutex& writeMutex) = 0;

                                                                                                                 
                                                  
       
                                                                                         
       
                
            
       
                               
    virtual void WritePermutationHeaderReflectionStructMembers(FILE* fp) = 0;

                                                                                                      
                                                  
       
                                                                                     
                                                                                           
       
                
            
       
                               
    virtual void WritePermutationHeaderReflectionData(FILE* fp, const Permutation& permutation) = 0;
};
