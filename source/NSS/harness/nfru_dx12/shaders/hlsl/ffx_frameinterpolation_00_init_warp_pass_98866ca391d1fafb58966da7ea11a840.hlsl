static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

cbuffer cbFI_t : register(b4, space0)
{
    row_major float4x4 cbFI_MotionTM1ToTP1 : packoffset(c0);
    row_major float4x4 cbFI_MotionTP1ToTM1 : packoffset(c4);
    float4 cbFI_QuantParamsSINT : packoffset(c8);
    float4 cbFI_QuantParamsSNORM : packoffset(c9);
    float4 cbFI_DeviceToViewDepth : packoffset(c10);
    int2 cbFI_RenderSize : packoffset(c11);
    int2 cbFI_DisplaySize : packoffset(c11.z);
    int2 cbFI_OfSize : packoffset(c12);
    float2 cbFI_RenderSizeRcp : packoffset(c12.z);
    float2 cbFI_DisplaySizeRcp : packoffset(c13);
    float2 cbFI_OfSizeRcp : packoffset(c13.z);
    float2 cbFI_Jitter : packoffset(c14);
    float2 cbFI_MotionVectorScale : packoffset(c14.z);
    float2 cbFI_MvSimilarityThresholds : packoffset(c15);
    int2 cbFI_InputTensorSize : packoffset(c15.z);
    float2 cbFI_InputTensorSizeRcp : packoffset(c16);
    int cbFI_Reset : packoffset(c16.z);
    float cbFI_Timestep : packoffset(c16.w);
    uint cbFI_RandomSeed : packoffset(c17);
    uint cbFI_pad0 : packoffset(c17.y);
    int2 cbFI_MvDepthLaneSize : packoffset(c17.z);
    float2 cbFI_MvDepthLaneSizeRcp : packoffset(c18);
    int2 cbFI_FlowLaneSize : packoffset(c18.z);
    float2 cbFI_FlowLaneSizeRcp : packoffset(c19);
    float cbFI_OfGridSizeRcp : packoffset(c19.z);
    row_major float4x4 cbFI_MotionTM1ToTM2 : packoffset(c20);
    uint cbFI_NfruT2Flags : packoffset(c24);
};

RWByteAddressBuffer rw_nfru_diagnostics : register(u8, space0);
Texture2D<float4> r_motion_tp1 : register(t5, space0);
Texture2D<float4> r_depth_tp1 : register(t6, space0);
Texture2D<float4> r_depth_tm1 : register(t7, space0);
RWTexture2D<uint> rw_warped_motion_qdata_tp1 : register(u0, space0);
RWTexture2D<uint> rw_warped_flow_qdata_tm1 : register(u1, space0);
RWTexture2D<unorm float> rw_mv_holes_tp1 : register(u2, space0);
RWTexture2D<unorm float> rw_mv_holes_tm1 : register(u3, space0);

static uint3 gl_WorkGroupID;
static uint3 gl_GlobalInvocationID;
static uint gl_LocalInvocationIndex;
struct SPIRV_Cross_Input
{
    uint3 gl_WorkGroupID : SV_GroupID;
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
    uint gl_LocalInvocationIndex : SV_GroupIndex;
};

groupshared float nfruFitT[2304];
groupshared float nfruFitX[2304];
groupshared float nfruFitA[132];
groupshared float nfruFitTheta[11];
groupshared float nfruFitW[768];
groupshared float nfruFitCw[768];
groupshared float nfruFitRes[768];
groupshared float nfruFitStat[8];
groupshared float nfruFitScale;
groupshared float nfruFitThetaF[11];

uint2 spvTextureSize(Texture2D<float4> Tex, uint Level, out uint Param)
{
    uint2 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, Param);
    return ret;
}

                                           
float spvDet2x2(float a1, float a2, float b1, float b2)
{
    return a1 * b2 - b1 * a2;
}

                                           
float spvDet3x3(float a1, float a2, float a3, float b1, float b2, float b3, float c1, float c2, float c3)
{
    return a1 * spvDet2x2(b2, b3, c2, c3) - b1 * spvDet2x2(a2, a3, c2, c3) + c1 * spvDet2x2(a2, a3, b2, b3);
}

                                                                                       
                                                                                   
float4x4 spvInverse(float4x4 m)
{
    float4x4 adj;	                                                             

                                                                                     
    adj[0][0] =  spvDet3x3(m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][1] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][2] =  spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[3][1], m[3][2], m[3][3]);
    adj[0][3] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3]);

    adj[1][0] = -spvDet3x3(m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][1] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][2] = -spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[3][0], m[3][2], m[3][3]);
    adj[1][3] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3]);

    adj[2][0] =  spvDet3x3(m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][1] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][2] =  spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[3][0], m[3][1], m[3][3]);
    adj[2][3] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3]);

    adj[3][0] = -spvDet3x3(m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][1] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][2] = -spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[3][0], m[3][1], m[3][2]);
    adj[3][3] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]);

                                                                                    
    float det = (adj[0][0] * m[0][0]) + (adj[0][1] * m[1][0]) + (adj[0][2] * m[2][0]) + (adj[0][3] * m[3][0]);

                                                              
                                                                               
    return (det != 0.0f) ? (adj * (1.0f / det)) : m;
}

void comp_main()
{
    int2 _1904 = int2(gl_GlobalInvocationID.xy);
    if (all(bool2(_1904.x < cbFI_MvDepthLaneSize.x, _1904.y < cbFI_MvDepthLaneSize.y)))
    {
        rw_warped_motion_qdata_tp1[_1904] = uint4(0u, 0u, 0u, 0u).x;
        rw_mv_holes_tp1[_1904] = 0.0f.x;
        rw_mv_holes_tm1[_1904] = 0.0f.x;
    }
    if (all(bool2(_1904.x < cbFI_FlowLaneSize.x, _1904.y < cbFI_FlowLaneSize.y)))
    {
        rw_warped_flow_qdata_tm1[_1904] = uint4(0u, 0u, 0u, 0u).x;
    }
    bool _1913 = (cbFI_NfruT2Flags & 524288u) != 0u;
    bool _1921;
    if (_1913)
    {
        _1921 = gl_WorkGroupID.x == 0u;
    }
    else
    {
        _1921 = _1913;
    }
    bool _1927;
    if (_1921)
    {
        _1927 = gl_WorkGroupID.y == 0u;
    }
    else
    {
        _1927 = _1921;
    }
    if (_1927)
    {
        float2 _2067 = float2(cbFI_RenderSize);
        float2 _2068 = _2067 * 0.5f;
        for (uint _4280 = 0u; _4280 < 3u; _4280++)
        {
            uint _2077 = (gl_LocalInvocationIndex * 3u) + _4280;
            float2 _2090 = 0.02999999932944774627685546875f.xx + ((float2(float(_2077 % 32u) + 0.5f, float(_2077 / 32u) + 0.5f) * float2(0.03125f, 0.0416666679084300994873046875f)) * 0.939999997615814208984375f);
            uint _2681_dummy_parameter;
            float2 _2696 = r_motion_tp1.Load(int3(int2(floor(_2090 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2681_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _2095 = _2090 + _2696;
            bool _2098 = all(bool2(_2095.x > 0.0f.xx.x, _2095.y > 0.0f.xx.y));
            bool _2104;
            if (_2098)
            {
                _2104 = all(bool2(_2095.x < 1.0f.xx.x, _2095.y < 1.0f.xx.y));
            }
            else
            {
                _2104 = _2098;
            }
            bool _2111;
            if (_2104)
            {
                _2111 = !any(isnan(_2696));
            }
            else
            {
                _2111 = _2104;
            }
            bool _2118;
            if (_2111)
            {
                _2118 = !any(isinf(_2696));
            }
            else
            {
                _2118 = _2111;
            }
            uint _2120 = _2077 * 3u;
            nfruFitX[_2120] = (2.0f * _2090.x) - 1.0f;
            uint _2128 = _2120 + 1u;
            nfruFitX[_2128] = 1.0f - (2.0f * _2090.y);
            uint _2136 = _2120 + 2u;
            uint _2708_dummy_parameter;
            nfruFitX[_2136] = r_depth_tp1.Load(int3(int2(floor(_2090 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2708_dummy_parameter))))), 0)).x;
            float _4474;
            if (_2118)
            {
                _4474 = (2.0f * _2095.x) - 1.0f;
            }
            else
            {
                _4474 = -1000000000.0f;
            }
            nfruFitT[_2120] = _4474;
            nfruFitT[_2128] = 1.0f - (2.0f * _2095.y);
            float _4475;
            if (_2118)
            {
                uint _2724_dummy_parameter;
                _4475 = r_depth_tm1.Load(int3(int2(floor(_2095 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _2724_dummy_parameter))))), 0)).x;
            }
            else
            {
                _4475 = 0.0f;
            }
            nfruFitT[_2136] = _4475;
            float _4476;
            if (_2118)
            {
                _4476 = length(_2696 * _2067);
            }
            else
            {
                _4476 = -1.0f;
            }
            nfruFitRes[_2077] = _4476;
            nfruFitW[_2077] = float(_2118);
            nfruFitCw[_2077] = 1.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _2195 = gl_LocalInvocationIndex == 0u;
        if (_2195)
        {
            float _4282;
            float _4283;
            float _4284;
            _4284 = 0.0f;
            _4283 = 0.0f;
            _4282 = 0.0f;
            float _2208;
            float _4484;
            float _4485;
            for (uint _4281 = 0u; _4281 < 768u; _4284 = _4485, _4283 = _4484, _4282 = _2208, _4281++)
            {
                _2208 = _4282 + nfruFitX[(_4281 * 3u) + 2u];
                if (nfruFitRes[_4281] >= 0.0f)
                {
                    _4485 = _4284 + nfruFitRes[_4281];
                    _4484 = _4283 + 1.0f;
                }
                else
                {
                    _4485 = _4284;
                    _4484 = _4283;
                }
            }
            nfruFitScale = 1.0f / max(_4282 * 0.001302083372138440608978271484375f, 9.9999999747524270787835121154785e-07f);
            float _4285;
            if (_4283 > 0.0f)
            {
                _4285 = _4284 / _4283;
            }
            else
            {
                _4285 = 0.0f;
            }
            nfruFitStat[7] = _4285;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4286 = 0u; _4286 < 3u; _4286++)
        {
            uint _2250 = (gl_LocalInvocationIndex * 3u) + _4286;
            uint _2253 = (_2250 * 3u) + 2u;
            nfruFitX[_2253] *= nfruFitScale;
            nfruFitT[_2253] *= nfruFitScale;
            if (nfruFitRes[_2250] < (0.25f * nfruFitStat[7]))
            {
                nfruFitW[_2250] = 0.0f;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4287 = 0u; _4287 <= 5u; _4287++)
        {
            if (gl_LocalInvocationIndex < 77u)
            {
                if (gl_LocalInvocationIndex < 66u)
                {
                    uint _4346;
                    uint _4348;
                    _4348 = 0u;
                    _4346 = gl_LocalInvocationIndex;
                    for (uint _4347 = 11u; _4346 >= _4347; )
                    {
                        uint _3219 = _4346 - _4347;
                        _4348++;
                        _4347--;
                        _4346 = _3219;
                        continue;
                    }
                    uint _3228 = _4348 + _4346;
                    float _4350;
                    _4350 = 0.0f;
                    float _4497;
                    for (uint _4349 = 0u; _4349 < 768u; _4350 = _4497, _4349++)
                    {
                        float _2830 = nfruFitW[_4349] / max(nfruFitCw[_4349] * nfruFitCw[_4349], 9.9999999747524270787835121154785e-07f);
                        if (_2830 > 0.0f)
                        {
                            uint _3247;
                            uint _3252;
                            uint _3257;
                            bool _3275;
                            float _4426;
                            do
                            {
                                _3247 = _4349 * 3u;
                                _3252 = _3247 + 1u;
                                _3257 = _3247 + 2u;
                                _3275 = _4348 < 4u;
                                if (_3275)
                                {
                                    float _4425;
                                    if (_4348 == 0u)
                                    {
                                        _4425 = nfruFitX[_3247];
                                    }
                                    else
                                    {
                                        float _4424;
                                        if (_4348 == 1u)
                                        {
                                            _4424 = nfruFitX[_3252];
                                        }
                                        else
                                        {
                                            _4424 = (_4348 == 2u) ? nfruFitX[_3257] : 1.0f;
                                        }
                                        _4425 = _4424;
                                    }
                                    _4426 = _4425;
                                    break;
                                }
                                if (_4348 < 8u)
                                {
                                    _4426 = 0.0f;
                                    break;
                                }
                                float _4423;
                                if (_4348 == 8u)
                                {
                                    _4423 = nfruFitX[_3247];
                                }
                                else
                                {
                                    _4423 = (_4348 == 9u) ? nfruFitX[_3252] : nfruFitX[_3257];
                                }
                                _4426 = (-nfruFitT[_3247]) * _4423;
                                break;
                            } while(false);
                            bool _3391;
                            float _4434;
                            do
                            {
                                _3391 = _3228 < 4u;
                                if (_3391)
                                {
                                    float _4433;
                                    if (_3228 == 0u)
                                    {
                                        _4433 = nfruFitX[_3247];
                                    }
                                    else
                                    {
                                        float _4432;
                                        if (_3228 == 1u)
                                        {
                                            _4432 = nfruFitX[_3252];
                                        }
                                        else
                                        {
                                            _4432 = (_3228 == 2u) ? nfruFitX[_3257] : 1.0f;
                                        }
                                        _4433 = _4432;
                                    }
                                    _4434 = _4433;
                                    break;
                                }
                                if (_3228 < 8u)
                                {
                                    _4434 = 0.0f;
                                    break;
                                }
                                float _4431;
                                if (_3228 == 8u)
                                {
                                    _4431 = nfruFitX[_3247];
                                }
                                else
                                {
                                    _4431 = (_3228 == 9u) ? nfruFitX[_3252] : nfruFitX[_3257];
                                }
                                _4434 = (-nfruFitT[_3247]) * _4431;
                                break;
                            } while(false);
                            float _4442;
                            do
                            {
                                if (_3275)
                                {
                                    _4442 = 0.0f;
                                    break;
                                }
                                if (_4348 < 8u)
                                {
                                    float _4441;
                                    if (_4348 == 4u)
                                    {
                                        _4441 = nfruFitX[_3247];
                                    }
                                    else
                                    {
                                        float _4440;
                                        if (_4348 == 5u)
                                        {
                                            _4440 = nfruFitX[_3252];
                                        }
                                        else
                                        {
                                            _4440 = (_4348 == 6u) ? nfruFitX[_3257] : 1.0f;
                                        }
                                        _4441 = _4440;
                                    }
                                    _4442 = _4441;
                                    break;
                                }
                                float _4439;
                                if (_4348 == 8u)
                                {
                                    _4439 = nfruFitX[_3247];
                                }
                                else
                                {
                                    _4439 = (_4348 == 9u) ? nfruFitX[_3252] : nfruFitX[_3257];
                                }
                                _4442 = (-nfruFitT[_3252]) * _4439;
                                break;
                            } while(false);
                            float _4450;
                            do
                            {
                                if (_3391)
                                {
                                    _4450 = 0.0f;
                                    break;
                                }
                                if (_3228 < 8u)
                                {
                                    float _4449;
                                    if (_3228 == 4u)
                                    {
                                        _4449 = nfruFitX[_3247];
                                    }
                                    else
                                    {
                                        float _4448;
                                        if (_3228 == 5u)
                                        {
                                            _4448 = nfruFitX[_3252];
                                        }
                                        else
                                        {
                                            _4448 = (_3228 == 6u) ? nfruFitX[_3257] : 1.0f;
                                        }
                                        _4449 = _4448;
                                    }
                                    _4450 = _4449;
                                    break;
                                }
                                float _4447;
                                if (_3228 == 8u)
                                {
                                    _4447 = nfruFitX[_3247];
                                }
                                else
                                {
                                    _4447 = (_3228 == 9u) ? nfruFitX[_3252] : nfruFitX[_3257];
                                }
                                _4450 = (-nfruFitT[_3252]) * _4447;
                                break;
                            } while(false);
                            _4497 = _4350 + (_2830 * ((_4426 * _4434) + (_4442 * _4450)));
                        }
                        else
                        {
                            _4497 = _4350;
                        }
                    }
                    nfruFitA[(_4348 * 12u) + _3228] = _4350;
                    nfruFitA[(_3228 * 12u) + _4348] = _4350;
                }
                else
                {
                    uint _2872 = gl_LocalInvocationIndex - 66u;
                    float _4320;
                    _4320 = 0.0f;
                    float _4496;
                    for (uint _4319 = 0u; _4319 < 768u; _4320 = _4496, _4319++)
                    {
                        float _2889 = nfruFitW[_4319] / max(nfruFitCw[_4319] * nfruFitCw[_4319], 9.9999999747524270787835121154785e-07f);
                        if (_2889 > 0.0f)
                        {
                            uint _3711;
                            uint _3716;
                            uint _3721;
                            bool _3739;
                            float _4324;
                            do
                            {
                                _3711 = _4319 * 3u;
                                _3716 = _3711 + 1u;
                                _3721 = _3711 + 2u;
                                _3739 = _2872 < 4u;
                                if (_3739)
                                {
                                    float _4323;
                                    if (_2872 == 0u)
                                    {
                                        _4323 = nfruFitX[_3711];
                                    }
                                    else
                                    {
                                        float _4322;
                                        if (_2872 == 1u)
                                        {
                                            _4322 = nfruFitX[_3716];
                                        }
                                        else
                                        {
                                            _4322 = (_2872 == 2u) ? nfruFitX[_3721] : 1.0f;
                                        }
                                        _4323 = _4322;
                                    }
                                    _4324 = _4323;
                                    break;
                                }
                                if (_2872 < 8u)
                                {
                                    _4324 = 0.0f;
                                    break;
                                }
                                float _4321;
                                if (_2872 == 8u)
                                {
                                    _4321 = nfruFitX[_3711];
                                }
                                else
                                {
                                    _4321 = (_2872 == 9u) ? nfruFitX[_3716] : nfruFitX[_3721];
                                }
                                _4324 = (-nfruFitT[_3711]) * _4321;
                                break;
                            } while(false);
                            float _4332;
                            do
                            {
                                if (_3739)
                                {
                                    _4332 = 0.0f;
                                    break;
                                }
                                if (_2872 < 8u)
                                {
                                    float _4331;
                                    if (_2872 == 4u)
                                    {
                                        _4331 = nfruFitX[_3711];
                                    }
                                    else
                                    {
                                        float _4330;
                                        if (_2872 == 5u)
                                        {
                                            _4330 = nfruFitX[_3716];
                                        }
                                        else
                                        {
                                            _4330 = (_2872 == 6u) ? nfruFitX[_3721] : 1.0f;
                                        }
                                        _4331 = _4330;
                                    }
                                    _4332 = _4331;
                                    break;
                                }
                                float _4329;
                                if (_2872 == 8u)
                                {
                                    _4329 = nfruFitX[_3711];
                                }
                                else
                                {
                                    _4329 = (_2872 == 9u) ? nfruFitX[_3716] : nfruFitX[_3721];
                                }
                                _4332 = (-nfruFitT[_3716]) * _4329;
                                break;
                            } while(false);
                            _4496 = _4320 + (_2889 * ((_4324 * nfruFitT[_3711]) + (_4332 * nfruFitT[_3716])));
                        }
                        else
                        {
                            _4496 = _4320;
                        }
                    }
                    nfruFitA[(_2872 * 12u) + 11u] = _4320;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2195)
            {
                float _4422;
                _4422 = 0.0f;
                for (uint _4352 = 0u; _4352 < 11u; )
                {
                    _4422 += nfruFitA[(_4352 * 12u) + _4352];
                    _4352++;
                    continue;
                }
                for (uint _4353 = 0u; _4353 < 11u; )
                {
                    uint _2956 = (_4353 * 12u) + _4353;
                    nfruFitA[_2956] += (9.999999717180685365747194737196e-10f * _4422);
                    _4353++;
                    continue;
                }
                if (_4287 < 3u)
                {
                    uint _4370;
                    _4370 = 2u;
                    for (; _4370 <= 10u; _4370 += 4u)
                    {
                        for (uint _4417 = 0u; _4417 < 12u; )
                        {
                            nfruFitA[(_4370 * 12u) + _4417] = 0.0f;
                            _4417++;
                            continue;
                        }
                        for (uint _4418 = 0u; _4418 < 11u; )
                        {
                            nfruFitA[(_4418 * 12u) + _4370] = 0.0f;
                            _4418++;
                            continue;
                        }
                        nfruFitA[(_4370 * 12u) + _4370] = 1.0f;
                    }
                }
                for (uint _4371 = 0u; _4371 < 11u; _4371++)
                {
                    uint _3949 = _4371 * 12u;
                    uint _3951 = _3949 + _4371;
                    float _3954 = abs(nfruFitA[_3951]);
                    uint _3956 = _4371 + 1u;
                    uint _4402;
                    _4402 = _4371;
                    uint _4534;
                    float _4533;
                    uint _4401 = _3956;
                    float _4415 = _3954;
                    for (; _4401 < 11u; _4415 = _4533, _4402 = _4534, _4401++)
                    {
                        uint _3965 = (_4401 * 12u) + _4371;
                        bool _3970 = abs(nfruFitA[_3965]) > _4415;
                        if (_3970)
                        {
                            _4533 = abs(nfruFitA[_3965]);
                        }
                        else
                        {
                            _4533 = _4415;
                        }
                        _4534 = _3970 ? _4401 : _4402;
                    }
                    if (_4402 != _4371)
                    {
                        for (uint _4404 = 0u; _4404 < 12u; )
                        {
                            uint _3997 = _3949 + _4404;
                            float _3999 = nfruFitA[_3997];
                            uint _4007 = (_4402 * 12u) + _4404;
                            nfruFitA[_3997] = nfruFitA[_4007];
                            nfruFitA[_4007] = _3999;
                            _4404++;
                            continue;
                        }
                    }
                    float _4407;
                    if (abs(nfruFitA[_3951]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _4407 = nfruFitA[_3951];
                    }
                    else
                    {
                        _4407 = 9.9999996826552253889678874634872e-21f;
                    }
                    for (uint _4409 = _3956; _4409 < 11u; _4409++)
                    {
                        uint _4048 = _4409 * 12u;
                        float _4054 = nfruFitA[_4048 + _4371] / _4407;
                        for (uint _4411 = _4371; _4411 < 12u; )
                        {
                            uint _4064 = _4048 + _4411;
                            nfruFitA[_4064] -= (_4054 * nfruFitA[_3949 + _4411]);
                            _4411++;
                            continue;
                        }
                    }
                }
                for (int _4372 = 10; _4372 >= 0; _4372--)
                {
                    uint _4095 = uint(_4372);
                    uint _4096 = _4095 * 12u;
                    uint _4102 = _4095 + 1u;
                    float _4400;
                    _4400 = nfruFitA[_4096 + 11u];
                    for (uint _4398 = _4102; _4398 < 11u; )
                    {
                        _4400 -= (nfruFitA[_4096 + _4398] * nfruFitTheta[_4398]);
                        _4398++;
                        continue;
                    }
                    uint _4130 = _4096 + _4095;
                    nfruFitTheta[_4095] = _4400 / ((abs(nfruFitA[_4130]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_4130] : 9.9999996826552253889678874634872e-21f);
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            float _4380;
            if (_4287 == 0u)
            {
                _4380 = 16.0f;
            }
            else
            {
                float _4379;
                if (_4287 == 1u)
                {
                    _4379 = 6.0f;
                }
                else
                {
                    float _4378;
                    if (_4287 == 2u)
                    {
                        _4378 = 3.0f;
                    }
                    else
                    {
                        _4378 = (_4287 == 3u) ? 2.0f : 1.0f;
                    }
                    _4379 = _4378;
                }
                _4380 = _4379;
            }
            for (uint _4381 = 0u; _4381 < 3u; _4381++)
            {
                uint _3045 = (gl_LocalInvocationIndex * 3u) + _4381;
                uint _4151 = _3045 * 3u;
                float _4386;
                if (nfruFitT[_4151] > (-100000000.0f))
                {
                    uint _3055 = _4151 + 1u;
                    uint _3060 = _4151 + 2u;
                    float _3077 = (((nfruFitTheta[8] * nfruFitX[_4151]) + (nfruFitTheta[9] * nfruFitX[_3055])) + (nfruFitTheta[10] * nfruFitX[_3060])) + 1.0f;
                    nfruFitCw[_3045] = _3077;
                    _4386 = length(float2(((((((nfruFitTheta[0] * nfruFitX[_4151]) + (nfruFitTheta[1] * nfruFitX[_3055])) + (nfruFitTheta[2] * nfruFitX[_3060])) + nfruFitTheta[3]) / _3077) - nfruFitT[_4151]) * _2068.x, ((((((nfruFitTheta[4] * nfruFitX[_4151]) + (nfruFitTheta[5] * nfruFitX[_3055])) + (nfruFitTheta[6] * nfruFitX[_3060])) + nfruFitTheta[7]) / _3077) - nfruFitT[_3055]) * _2068.y));
                }
                else
                {
                    _4386 = 1000000000.0f;
                }
                nfruFitRes[_3045] = _4386;
                if (!(nfruFitT[_4151] > (-100000000.0f)))
                {
                    nfruFitW[_3045] = 0.0f;
                }
                else
                {
                    if (_4287 == 2u)
                    {
                        nfruFitW[_3045] = float(_4386 < 4.0f);
                    }
                    else
                    {
                        if (_4287 > 2u)
                        {
                            float _4390;
                            if (_4386 < 8.0f)
                            {
                                float _4389;
                                if (_4386 < _4380)
                                {
                                    _4389 = 1.0f;
                                }
                                else
                                {
                                    _4389 = _4380 / max(_4386, 9.9999999747524270787835121154785e-07f);
                                }
                                _4390 = _4389;
                            }
                            else
                            {
                                _4390 = 0.0f;
                            }
                            nfruFitW[_3045] = _4390;
                        }
                        else
                        {
                            float _4388;
                            if (_4386 < _4380)
                            {
                                _4388 = 1.0f;
                            }
                            else
                            {
                                _4388 = _4380 / max(_4386, 9.9999999747524270787835121154785e-07f);
                            }
                            nfruFitW[_3045] = _4388;
                        }
                    }
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        if (gl_LocalInvocationIndex == 20u)
        {
            float _4289;
            float _4290;
            float _4291;
            _4291 = 0.0f;
            _4290 = 0.0f;
            _4289 = 0.0f;
            float _4486;
            float _4488;
            float _4489;
            for (uint _4288 = 0u; _4288 < 768u; _4291 = _4489, _4290 = _4488, _4289 = _4486, _4288++)
            {
                if (nfruFitT[_4288 * 3u] > (-100000000.0f))
                {
                    _4488 = _4290 + 1.0f;
                }
                else
                {
                    _4488 = _4290;
                }
                if (nfruFitRes[_4288] < 2.0f)
                {
                    _4489 = _4291 + nfruFitRes[_4288];
                    _4486 = _4289 + 1.0f;
                }
                else
                {
                    _4489 = _4291;
                    _4486 = _4289;
                }
            }
            nfruFitStat[0u] = _4289;
            nfruFitStat[1u] = _4290;
            float _4292;
            if (_4289 > 0.0f)
            {
                _4292 = _4291 / _4289;
            }
            else
            {
                _4292 = 1000000000.0f;
            }
            nfruFitStat[2u] = _4292;
        }
        if (gl_LocalInvocationIndex < 11u)
        {
            nfruFitThetaF[gl_LocalInvocationIndex] = nfruFitTheta[gl_LocalInvocationIndex];
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4293 = 0u; _4293 < 3u; _4293++)
        {
            uint _2311 = (gl_LocalInvocationIndex * 3u) + _4293;
            uint _4228 = _2311 * 3u;
            bool _4231 = nfruFitT[_4228] > (-100000000.0f);
            bool _2320;
            if (_4231)
            {
                _2320 = nfruFitRes[_2311] < 1.5f;
            }
            else
            {
                _2320 = _4231;
            }
            float _4312;
            if (_2320)
            {
                _4312 = ((nfruFitT[_4228 + 2u] / nfruFitScale) - cbFI_DeviceToViewDepth.x) * nfruFitCw[_2311];
            }
            else
            {
                _4312 = 0.0f;
            }
            nfruFitW[_2311] = _4312;
            nfruFitCw[_2311] = float(_2320);
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2195)
        {
            float _4295;
            float _4296;
            _4296 = 0.0f;
            _4295 = 0.0f;
            float _4490;
            float _4491;
            for (uint _4294 = 0u; _4294 < 768u; _4296 = _4491, _4295 = _4490, _4294++)
            {
                if (nfruFitCw[_4294] > 0.0f)
                {
                    _4491 = _4296 + nfruFitW[_4294];
                    _4490 = _4295 + 1.0f;
                }
                else
                {
                    _4491 = _4296;
                    _4490 = _4295;
                }
            }
            float _4297;
            if (_4295 > 0.0f)
            {
                _4297 = _4296 / _4295;
            }
            else
            {
                _4297 = 0.0f;
            }
            float _4299;
            _4299 = _4297;
            float _4307;
            for (uint _4298 = 0u; _4298 < 4u; _4299 = _4307, _4298++)
            {
                float _2392 = max(abs(_4299) * 0.100000001490116119384765625f, 9.9999999600419720025001879548654e-13f);
                float _4304;
                float _4306;
                _4306 = 0.0f;
                _4304 = 0.0f;
                float _4492;
                float _4494;
                for (uint _4303 = 0u; _4303 < 768u; _4306 = _4494, _4304 = _4492, _4303++)
                {
                    if (nfruFitCw[_4303] > 0.0f)
                    {
                        float _2409 = (nfruFitW[_4303] - _4299) / _2392;
                        float _2414 = 1.0f / (1.0f + (_2409 * _2409));
                        _4494 = _4306 + (_2414 * nfruFitW[_4303]);
                        _4492 = _4304 + _2414;
                    }
                    else
                    {
                        _4494 = _4306;
                        _4492 = _4304;
                    }
                }
                if (_4304 > 0.0f)
                {
                    _4307 = _4306 / _4304;
                }
                else
                {
                    _4307 = _4299;
                }
            }
            nfruFitStat[6] = _4299;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2195)
        {
            float4 _2484 = float4(nfruFitThetaF[8], nfruFitThetaF[9], nfruFitThetaF[10] * nfruFitScale, 1.0f);
            float4x4 _2516 = transpose(float4x4(float4(nfruFitThetaF[0], nfruFitThetaF[1], nfruFitThetaF[2] * nfruFitScale, nfruFitThetaF[3]), float4(nfruFitThetaF[4], nfruFitThetaF[5], nfruFitThetaF[6] * nfruFitScale, nfruFitThetaF[7]), (_2484 * cbFI_DeviceToViewDepth.x) + float4(0.0f, 0.0f, 0.0f, nfruFitStat[6]), _2484));
            float4x4 _2055 = _2516;
            float4x4 _2056 = spvInverse(_2516);
            uint _4243 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
            uint _4300;
            _4300 = 0u;
            for (; _4300 < 4u; _4300++)
            {
                for (uint _4301 = 0u; _4301 < 4u; )
                {
                    uint _2532 = _4300 * 4u;
                    rw_nfru_diagnostics.Store<uint>(((_4243 + _2532) + _4301) * 4 + 0, asuint(_2055[_4300][_4301]));
                    rw_nfru_diagnostics.Store<uint>((((_4243 + 16u) + _2532) + _4301) * 4 + 0, asuint(_2056[_4300][_4301]));
                    _4301++;
                    continue;
                }
            }
            bool _2573 = !any(isnan(_2055[0]));
            bool _2581;
            if (_2573)
            {
                _2581 = !any(isnan(_2055[1]));
            }
            else
            {
                _2581 = _2573;
            }
            bool _2589;
            if (_2581)
            {
                _2589 = !any(isnan(_2055[3]));
            }
            else
            {
                _2589 = _2581;
            }
            bool _2597;
            if (_2589)
            {
                _2597 = !any(isnan(_2056[0]));
            }
            else
            {
                _2597 = _2589;
            }
            bool _2605;
            if (_2597)
            {
                _2605 = !any(isnan(_2056[1]));
            }
            else
            {
                _2605 = _2597;
            }
            bool _2613;
            if (_2605)
            {
                _2613 = !any(isnan(_2056[3]));
            }
            else
            {
                _2613 = _2605;
            }
            bool _2621;
            if (_2613)
            {
                _2621 = !any(isinf(_2056[0]));
            }
            else
            {
                _2621 = _2613;
            }
            bool _2629;
            if (_2621)
            {
                _2629 = !any(isinf(_2056[3]));
            }
            else
            {
                _2629 = _2621;
            }
            bool _2635;
            if (_2629)
            {
                _2635 = abs(nfruFitStat[6]) > 0.0f;
            }
            else
            {
                _2635 = _2629;
            }
            bool _2639 = _2635 && (nfruFitStat[1] > 250.0f);
            bool _2646;
            if (_2639)
            {
                _2646 = nfruFitStat[0] > (0.4000000059604644775390625f * nfruFitStat[1]);
            }
            else
            {
                _2646 = _2639;
            }
            rw_nfru_diagnostics.Store<uint>((_4243 + 32u) * 4 + 0, uint(_2646 && (nfruFitStat[2] < 1.0f)));
            rw_nfru_diagnostics.Store<uint>((_4243 + 33u) * 4 + 0, asuint(nfruFitStat[2]));
            rw_nfru_diagnostics.Store<uint>((_4243 + 34u) * 4 + 0, uint(nfruFitStat[0]));
            rw_nfru_diagnostics.Store<uint>((_4243 + 35u) * 4 + 0, uint(nfruFitStat[1]));
        }
    }
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_WorkGroupID = stage_input.gl_WorkGroupID;
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    gl_LocalInvocationIndex = stage_input.gl_LocalInvocationIndex;
    comp_main();
}
