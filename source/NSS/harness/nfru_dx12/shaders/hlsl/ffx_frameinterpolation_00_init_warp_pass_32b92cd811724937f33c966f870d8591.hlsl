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

groupshared float nfruFitX[2304];
groupshared float nfruFitT[2304];
groupshared float nfruFitA[132];
groupshared float nfruFitTheta[16];
groupshared float nfruFitW[768];
groupshared float nfruFitScale;
groupshared float nfruFitRes[768];
groupshared float nfruFitStat[4];

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
    int2 _1764 = int2(gl_GlobalInvocationID.xy);
    if (all(bool2(_1764.x < cbFI_MvDepthLaneSize.x, _1764.y < cbFI_MvDepthLaneSize.y)))
    {
        rw_warped_motion_qdata_tp1[_1764] = uint4(0u, 0u, 0u, 0u).x;
        rw_mv_holes_tp1[_1764] = 0.0f.x;
        rw_mv_holes_tm1[_1764] = 0.0f.x;
    }
    if (all(bool2(_1764.x < cbFI_FlowLaneSize.x, _1764.y < cbFI_FlowLaneSize.y)))
    {
        rw_warped_flow_qdata_tm1[_1764] = uint4(0u, 0u, 0u, 0u).x;
    }
    bool _1772 = (cbFI_NfruT2Flags & 524288u) != 0u;
    bool _1780;
    if (_1772)
    {
        _1780 = gl_WorkGroupID.x == 0u;
    }
    else
    {
        _1780 = _1772;
    }
    bool _1786;
    if (_1780)
    {
        _1786 = gl_WorkGroupID.y == 0u;
    }
    else
    {
        _1786 = _1780;
    }
    if (_1786)
    {
        float2 _1975 = float2(cbFI_RenderSize) * 0.5f;
        float _4249;
        _4249 = 0.0f;
        float _2080;
        for (uint _4247 = 0u; _4247 < 3u; _4249 = _2080, _4247++)
        {
            uint _1984 = (gl_LocalInvocationIndex * 3u) + _4247;
            float2 _1997 = 0.02999999932944774627685546875f.xx + ((float2(float(_1984 % 32u) + 0.5f, float(_1984 / 32u) + 0.5f) * float2(0.03125f, 0.0416666679084300994873046875f)) * 0.939999997615814208984375f);
            uint _2819_dummy_parameter;
            float2 _2834 = r_motion_tp1.Load(int3(int2(floor(_1997 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2819_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            uint _2846_dummy_parameter;
            float4 _2853 = r_depth_tp1.Load(int3(int2(floor(_1997 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2846_dummy_parameter))))), 0));
            float _2854 = _2853.x;
            float2 _2004 = _1997 + _2834;
            bool _2007 = all(bool2(_2004.x > 0.0f.xx.x, _2004.y > 0.0f.xx.y));
            bool _2013;
            if (_2007)
            {
                _2013 = all(bool2(_2004.x < 1.0f.xx.x, _2004.y < 1.0f.xx.y));
            }
            else
            {
                _2013 = _2007;
            }
            bool _2020;
            if (_2013)
            {
                _2020 = !any(isnan(_2834));
            }
            else
            {
                _2020 = _2013;
            }
            bool _2027;
            if (_2020)
            {
                _2027 = !any(isinf(_2834));
            }
            else
            {
                _2027 = _2020;
            }
            uint _2029 = _1984 * 3u;
            nfruFitX[_2029] = (2.0f * _1997.x) - 1.0f;
            uint _2037 = _2029 + 1u;
            nfruFitX[_2037] = 1.0f - (2.0f * _1997.y);
            uint _2045 = _2029 + 2u;
            nfruFitX[_2045] = _2854;
            nfruFitT[_2029] = (2.0f * _2004.x) - 1.0f;
            nfruFitT[_2037] = 1.0f - (2.0f * _2004.y);
            float _4450;
            if (_2027)
            {
                uint _2862_dummy_parameter;
                _4450 = r_depth_tm1.Load(int3(int2(floor(_2004 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _2862_dummy_parameter))))), 0)).x;
            }
            else
            {
                _4450 = 0.0f;
            }
            nfruFitT[_2045] = _4450;
            nfruFitW[_1984] = float(_2027);
            _2080 = _4249 + _2854;
        }
        bool _2086 = gl_LocalInvocationIndex == 0u;
        if (_2086)
        {
            nfruFitScale = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        nfruFitRes[gl_LocalInvocationIndex] = _4249;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2086)
        {
            float _4251;
            _4251 = 0.0f;
            for (uint _4250 = 0u; _4250 < 256u; )
            {
                _4251 += nfruFitRes[_4250];
                _4250++;
                continue;
            }
            nfruFitScale = 1.0f / max(_4251 * 0.001302083372138440608978271484375f, 9.9999999747524270787835121154785e-07f);
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4252 = 0u; _4252 < 3u; )
        {
            uint _2128 = (((gl_LocalInvocationIndex * 3u) + _4252) * 3u) + 2u;
            nfruFitX[_2128] *= nfruFitScale;
            nfruFitT[_2128] *= nfruFitScale;
            _4252++;
            continue;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4253 = 0u; _4253 < 3u; _4253++)
        {
            if (gl_LocalInvocationIndex < 77u)
            {
                if (gl_LocalInvocationIndex < 66u)
                {
                    uint _4350;
                    uint _4352;
                    _4352 = 0u;
                    _4350 = gl_LocalInvocationIndex;
                    for (uint _4351 = 11u; _4350 >= _4351; )
                    {
                        uint _2887 = _4350 - _4351;
                        _4352++;
                        _4351--;
                        _4350 = _2887;
                        continue;
                    }
                    uint _2896 = _4352 + _4350;
                    float _4354;
                    _4354 = 0.0f;
                    float _4469;
                    for (uint _4353 = 0u; _4353 < 768u; _4354 = _4469, _4353++)
                    {
                        if (nfruFitW[_4353] > 0.0f)
                        {
                            uint _2915;
                            uint _2920;
                            uint _2925;
                            bool _2943;
                            float _4404;
                            do
                            {
                                _2915 = _4353 * 3u;
                                _2920 = _2915 + 1u;
                                _2925 = _2915 + 2u;
                                _2943 = _4352 < 4u;
                                if (_2943)
                                {
                                    float _4403;
                                    if (_4352 == 0u)
                                    {
                                        _4403 = nfruFitX[_2915];
                                    }
                                    else
                                    {
                                        float _4402;
                                        if (_4352 == 1u)
                                        {
                                            _4402 = nfruFitX[_2920];
                                        }
                                        else
                                        {
                                            _4402 = (_4352 == 2u) ? nfruFitX[_2925] : 1.0f;
                                        }
                                        _4403 = _4402;
                                    }
                                    _4404 = _4403;
                                    break;
                                }
                                if (_4352 < 8u)
                                {
                                    _4404 = 0.0f;
                                    break;
                                }
                                float _4401;
                                if (_4352 == 8u)
                                {
                                    _4401 = nfruFitX[_2915];
                                }
                                else
                                {
                                    _4401 = (_4352 == 9u) ? nfruFitX[_2920] : nfruFitX[_2925];
                                }
                                _4404 = (-nfruFitT[_2915]) * _4401;
                                break;
                            } while(false);
                            bool _3059;
                            float _4412;
                            do
                            {
                                _3059 = _2896 < 4u;
                                if (_3059)
                                {
                                    float _4411;
                                    if (_2896 == 0u)
                                    {
                                        _4411 = nfruFitX[_2915];
                                    }
                                    else
                                    {
                                        float _4410;
                                        if (_2896 == 1u)
                                        {
                                            _4410 = nfruFitX[_2920];
                                        }
                                        else
                                        {
                                            _4410 = (_2896 == 2u) ? nfruFitX[_2925] : 1.0f;
                                        }
                                        _4411 = _4410;
                                    }
                                    _4412 = _4411;
                                    break;
                                }
                                if (_2896 < 8u)
                                {
                                    _4412 = 0.0f;
                                    break;
                                }
                                float _4409;
                                if (_2896 == 8u)
                                {
                                    _4409 = nfruFitX[_2915];
                                }
                                else
                                {
                                    _4409 = (_2896 == 9u) ? nfruFitX[_2920] : nfruFitX[_2925];
                                }
                                _4412 = (-nfruFitT[_2915]) * _4409;
                                break;
                            } while(false);
                            float _4420;
                            do
                            {
                                if (_2943)
                                {
                                    _4420 = 0.0f;
                                    break;
                                }
                                if (_4352 < 8u)
                                {
                                    float _4419;
                                    if (_4352 == 4u)
                                    {
                                        _4419 = nfruFitX[_2915];
                                    }
                                    else
                                    {
                                        float _4418;
                                        if (_4352 == 5u)
                                        {
                                            _4418 = nfruFitX[_2920];
                                        }
                                        else
                                        {
                                            _4418 = (_4352 == 6u) ? nfruFitX[_2925] : 1.0f;
                                        }
                                        _4419 = _4418;
                                    }
                                    _4420 = _4419;
                                    break;
                                }
                                float _4417;
                                if (_4352 == 8u)
                                {
                                    _4417 = nfruFitX[_2915];
                                }
                                else
                                {
                                    _4417 = (_4352 == 9u) ? nfruFitX[_2920] : nfruFitX[_2925];
                                }
                                _4420 = (-nfruFitT[_2920]) * _4417;
                                break;
                            } while(false);
                            float _4428;
                            do
                            {
                                if (_3059)
                                {
                                    _4428 = 0.0f;
                                    break;
                                }
                                if (_2896 < 8u)
                                {
                                    float _4427;
                                    if (_2896 == 4u)
                                    {
                                        _4427 = nfruFitX[_2915];
                                    }
                                    else
                                    {
                                        float _4426;
                                        if (_2896 == 5u)
                                        {
                                            _4426 = nfruFitX[_2920];
                                        }
                                        else
                                        {
                                            _4426 = (_2896 == 6u) ? nfruFitX[_2925] : 1.0f;
                                        }
                                        _4427 = _4426;
                                    }
                                    _4428 = _4427;
                                    break;
                                }
                                float _4425;
                                if (_2896 == 8u)
                                {
                                    _4425 = nfruFitX[_2915];
                                }
                                else
                                {
                                    _4425 = (_2896 == 9u) ? nfruFitX[_2920] : nfruFitX[_2925];
                                }
                                _4428 = (-nfruFitT[_2920]) * _4425;
                                break;
                            } while(false);
                            _4469 = _4354 + (nfruFitW[_4353] * ((_4404 * _4412) + (_4420 * _4428)));
                        }
                        else
                        {
                            _4469 = _4354;
                        }
                    }
                    nfruFitA[(_4352 * 12u) + _2896] = _4354;
                    nfruFitA[(_2896 * 12u) + _4352] = _4354;
                }
                else
                {
                    uint _2211 = gl_LocalInvocationIndex - 66u;
                    float _4324;
                    _4324 = 0.0f;
                    float _4468;
                    for (uint _4323 = 0u; _4323 < 768u; _4324 = _4468, _4323++)
                    {
                        if (nfruFitW[_4323] > 0.0f)
                        {
                            uint _3379;
                            uint _3384;
                            uint _3389;
                            bool _3407;
                            float _4328;
                            do
                            {
                                _3379 = _4323 * 3u;
                                _3384 = _3379 + 1u;
                                _3389 = _3379 + 2u;
                                _3407 = _2211 < 4u;
                                if (_3407)
                                {
                                    float _4327;
                                    if (_2211 == 0u)
                                    {
                                        _4327 = nfruFitX[_3379];
                                    }
                                    else
                                    {
                                        float _4326;
                                        if (_2211 == 1u)
                                        {
                                            _4326 = nfruFitX[_3384];
                                        }
                                        else
                                        {
                                            _4326 = (_2211 == 2u) ? nfruFitX[_3389] : 1.0f;
                                        }
                                        _4327 = _4326;
                                    }
                                    _4328 = _4327;
                                    break;
                                }
                                if (_2211 < 8u)
                                {
                                    _4328 = 0.0f;
                                    break;
                                }
                                float _4325;
                                if (_2211 == 8u)
                                {
                                    _4325 = nfruFitX[_3379];
                                }
                                else
                                {
                                    _4325 = (_2211 == 9u) ? nfruFitX[_3384] : nfruFitX[_3389];
                                }
                                _4328 = (-nfruFitT[_3379]) * _4325;
                                break;
                            } while(false);
                            float _4336;
                            do
                            {
                                if (_3407)
                                {
                                    _4336 = 0.0f;
                                    break;
                                }
                                if (_2211 < 8u)
                                {
                                    float _4335;
                                    if (_2211 == 4u)
                                    {
                                        _4335 = nfruFitX[_3379];
                                    }
                                    else
                                    {
                                        float _4334;
                                        if (_2211 == 5u)
                                        {
                                            _4334 = nfruFitX[_3384];
                                        }
                                        else
                                        {
                                            _4334 = (_2211 == 6u) ? nfruFitX[_3389] : 1.0f;
                                        }
                                        _4335 = _4334;
                                    }
                                    _4336 = _4335;
                                    break;
                                }
                                float _4333;
                                if (_2211 == 8u)
                                {
                                    _4333 = nfruFitX[_3379];
                                }
                                else
                                {
                                    _4333 = (_2211 == 9u) ? nfruFitX[_3384] : nfruFitX[_3389];
                                }
                                _4336 = (-nfruFitT[_3384]) * _4333;
                                break;
                            } while(false);
                            _4468 = _4324 + (nfruFitW[_4323] * ((_4328 * nfruFitT[_3379]) + (_4336 * nfruFitT[_3384])));
                        }
                        else
                        {
                            _4468 = _4324;
                        }
                    }
                    nfruFitA[(_2211 * 12u) + 11u] = _4324;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2086)
            {
                float _2262 = nfruFitA[0];
                float _2264 = nfruFitA[13];
                float _2266 = 9.9999999747524270787835121154785e-07f * (_2262 + _2264);
                nfruFitA[26] += _2266;
                nfruFitA[78] += _2266;
                nfruFitA[130] += _2266;
                for (uint _4356 = 0u; _4356 < 11u; _4356++)
                {
                    uint _3618 = _4356 * 12u;
                    uint _3620 = _3618 + _4356;
                    float _3623 = abs(nfruFitA[_3620]);
                    uint _3625 = _4356 + 1u;
                    uint _4386;
                    _4386 = _4356;
                    uint _4500;
                    float _4499;
                    uint _4385 = _3625;
                    float _4399 = _3623;
                    for (; _4385 < 11u; _4399 = _4499, _4386 = _4500, _4385++)
                    {
                        uint _3635 = (_4385 * 12u) + _4356;
                        bool _3640 = abs(nfruFitA[_3635]) > _4399;
                        if (_3640)
                        {
                            _4499 = abs(nfruFitA[_3635]);
                        }
                        else
                        {
                            _4499 = _4399;
                        }
                        _4500 = _3640 ? _4385 : _4386;
                    }
                    if (_4386 != _4356)
                    {
                        for (uint _4388 = 0u; _4388 < 12u; )
                        {
                            uint _3667 = _3618 + _4388;
                            float _3669 = nfruFitA[_3667];
                            uint _3677 = (_4386 * 12u) + _4388;
                            nfruFitA[_3667] = nfruFitA[_3677];
                            nfruFitA[_3677] = _3669;
                            _4388++;
                            continue;
                        }
                    }
                    float _4391;
                    if (abs(nfruFitA[_3620]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _4391 = nfruFitA[_3620];
                    }
                    else
                    {
                        _4391 = 9.9999996826552253889678874634872e-21f;
                    }
                    for (uint _4393 = _3625; _4393 < 11u; _4393++)
                    {
                        uint _3719 = _4393 * 12u;
                        float _3723 = nfruFitA[_3719 + _4356];
                        float _3725 = _3723 / _4391;
                        for (uint _4395 = _4356; _4395 < 11u; )
                        {
                            uint _3736 = _3719 + _4395;
                            nfruFitA[_3736] -= (_3725 * nfruFitA[_3618 + _4395]);
                            _4395++;
                            continue;
                        }
                        uint _3755 = _3719 + 11u;
                        nfruFitA[_3755] -= (_3725 * nfruFitA[_3618 + 11u]);
                    }
                }
                for (int _4357 = 10; _4357 >= 0; _4357--)
                {
                    uint _3784 = uint(_4357);
                    uint _3785 = _3784 * 12u;
                    uint _3791 = _3784 + 1u;
                    float _4384;
                    _4384 = nfruFitA[_3785 + 11u];
                    for (uint _4382 = _3791; _4382 < 11u; )
                    {
                        _4384 -= (nfruFitA[_3785 + _4382] * nfruFitTheta[_4382]);
                        _4382++;
                        continue;
                    }
                    uint _3820 = _3785 + _3784;
                    nfruFitTheta[_3784] = _4384 / ((abs(nfruFitA[_3820]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_3820] : 9.9999996826552253889678874634872e-21f);
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            float _4375;
            if (_4253 == 0u)
            {
                _4375 = 8.0f;
            }
            else
            {
                _4375 = (_4253 == 1u) ? 3.0f : 1.5f;
            }
            for (uint _4376 = 0u; _4376 < 3u; _4376++)
            {
                uint _2302 = (gl_LocalInvocationIndex * 3u) + _4376;
                if (nfruFitW[_2302] <= 0.0f)
                {
                    nfruFitRes[_2302] = 1000000000.0f;
                    continue;
                }
                uint _3847 = _2302 * 3u;
                uint _3852 = _3847 + 1u;
                uint _3857 = _3847 + 2u;
                float _3874 = (((nfruFitTheta[8] * nfruFitX[_3847]) + (nfruFitTheta[9] * nfruFitX[_3852])) + (nfruFitTheta[10] * nfruFitX[_3857])) + 1.0f;
                float _3933 = length(float2(((((((nfruFitTheta[0] * nfruFitX[_3847]) + (nfruFitTheta[1] * nfruFitX[_3852])) + (nfruFitTheta[2] * nfruFitX[_3857])) + nfruFitTheta[3]) / _3874) - nfruFitT[_3847]) * _1975.x, ((((((nfruFitTheta[4] * nfruFitX[_3847]) + (nfruFitTheta[5] * nfruFitX[_3852])) + (nfruFitTheta[6] * nfruFitX[_3857])) + nfruFitTheta[7]) / _3874) - nfruFitT[_3852]) * _1975.y));
                nfruFitRes[_2302] = _3933;
                float _4379;
                if (_3933 < _4375)
                {
                    _4379 = 1.0f;
                }
                else
                {
                    _4379 = _4375 / max(_3933, 9.9999999747524270787835121154785e-07f);
                }
                nfruFitW[_2302] = _4379;
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        if (gl_LocalInvocationIndex < 14u)
        {
            if (gl_LocalInvocationIndex < 10u)
            {
                uint _4263;
                uint _4265;
                _4265 = 0u;
                _4263 = gl_LocalInvocationIndex;
                for (uint _4264 = 4u; _4263 >= _4264; )
                {
                    uint _3946 = _4263 - _4264;
                    _4265++;
                    _4264--;
                    _4263 = _3946;
                    continue;
                }
                uint _3955 = _4265 + _4263;
                float _4267;
                _4267 = 0.0f;
                float _4460;
                for (uint _4266 = 0u; _4266 < 768u; _4267 = _4460, _4266++)
                {
                    if (nfruFitRes[_4266] < 1.5f)
                    {
                        float _4306;
                        if (_4265 == 0u)
                        {
                            _4306 = nfruFitX[_4266 * 3u];
                        }
                        else
                        {
                            float _4305;
                            if (_4265 == 1u)
                            {
                                _4305 = nfruFitX[(_4266 * 3u) + 1u];
                            }
                            else
                            {
                                float _4304;
                                if (_4265 == 2u)
                                {
                                    _4304 = nfruFitX[(_4266 * 3u) + 2u];
                                }
                                else
                                {
                                    _4304 = 1.0f;
                                }
                                _4305 = _4304;
                            }
                            _4306 = _4305;
                        }
                        float _4312;
                        if (_3955 == 0u)
                        {
                            _4312 = nfruFitX[_4266 * 3u];
                        }
                        else
                        {
                            float _4311;
                            if (_3955 == 1u)
                            {
                                _4311 = nfruFitX[(_4266 * 3u) + 1u];
                            }
                            else
                            {
                                float _4310;
                                if (_3955 == 2u)
                                {
                                    _4310 = nfruFitX[(_4266 * 3u) + 2u];
                                }
                                else
                                {
                                    _4310 = 1.0f;
                                }
                                _4311 = _4310;
                            }
                            _4312 = _4311;
                        }
                        _4460 = _4267 + (_4306 * _4312);
                    }
                    else
                    {
                        _4460 = _4267;
                    }
                }
                nfruFitA[(_4265 * 12u) + _3955] = _4267;
                nfruFitA[(_3955 * 12u) + _4265] = _4267;
            }
            else
            {
                uint _2447 = gl_LocalInvocationIndex - 10u;
                float _4255;
                _4255 = 0.0f;
                float _4459;
                for (uint _4254 = 0u; _4254 < 768u; _4255 = _4459, _4254++)
                {
                    if (nfruFitRes[_4254] < 1.5f)
                    {
                        uint _2459 = _4254 * 3u;
                        uint _2464 = _2459 + 1u;
                        uint _2469 = _2459 + 2u;
                        float _4257;
                        if (_2447 == 0u)
                        {
                            _4257 = nfruFitX[_2459];
                        }
                        else
                        {
                            float _4256;
                            if (_2447 == 1u)
                            {
                                _4256 = nfruFitX[_2464];
                            }
                            else
                            {
                                _4256 = (_2447 == 2u) ? nfruFitX[_2469] : 1.0f;
                            }
                            _4257 = _4256;
                        }
                        _4459 = _4255 + ((_4257 * nfruFitT[_2469]) * ((((nfruFitTheta[8] * nfruFitX[_2459]) + (nfruFitTheta[9] * nfruFitX[_2464])) + (nfruFitTheta[10] * nfruFitX[_2469])) + 1.0f));
                    }
                    else
                    {
                        _4459 = _4255;
                    }
                }
                nfruFitA[(_2447 * 12u) + 11u] = _4255;
            }
        }
        if (gl_LocalInvocationIndex == 20u)
        {
            float _4270;
            float _4271;
            float _4272;
            _4272 = 0.0f;
            _4271 = 0.0f;
            _4270 = 0.0f;
            float _4461;
            float _4463;
            float _4464;
            for (uint _4269 = 0u; _4269 < 768u; _4272 = _4464, _4271 = _4463, _4270 = _4461, _4269++)
            {
                if (nfruFitRes[_4269] < 100000000.0f)
                {
                    _4463 = _4271 + 1.0f;
                }
                else
                {
                    _4463 = _4271;
                }
                if (nfruFitRes[_4269] < 2.0f)
                {
                    _4464 = _4272 + nfruFitRes[_4269];
                    _4461 = _4270 + 1.0f;
                }
                else
                {
                    _4464 = _4272;
                    _4461 = _4270;
                }
            }
            nfruFitStat[0] = _4270;
            nfruFitStat[1] = _4271;
            float _4273;
            if (_4270 > 0.0f)
            {
                _4273 = _4272 / _4270;
            }
            else
            {
                _4273 = 1000000000.0f;
            }
            nfruFitStat[2] = _4273;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2086)
        {
            float _1954[11];
            for (uint _4274 = 0u; _4274 < 11u; )
            {
                _1954[_4274] = nfruFitTheta[_4274];
                _4274++;
                continue;
            }
            float _2600 = 9.9999999747524270787835121154785e-07f * ((nfruFitA[0] + nfruFitA[13]) + 9.999999717180685365747194737196e-10f);
            for (uint _4275 = 0u; _4275 < 4u; )
            {
                uint _2609 = (_4275 * 12u) + _4275;
                nfruFitA[_2609] += _2600;
                _4275++;
                continue;
            }
            for (uint _4276 = 0u; _4276 < 4u; _4276++)
            {
                uint _3981 = _4276 * 12u;
                uint _3983 = _3981 + _4276;
                float _3986 = abs(nfruFitA[_3983]);
                uint _3988 = _4276 + 1u;
                uint _4285;
                _4285 = _4276;
                uint _4501;
                float _4467;
                uint _4284 = _3988;
                float _4298 = _3986;
                for (; _4284 < 4u; _4298 = _4467, _4285 = _4501, _4284++)
                {
                    uint _3998 = (_4284 * 12u) + _4276;
                    bool _4003 = abs(nfruFitA[_3998]) > _4298;
                    if (_4003)
                    {
                        _4467 = abs(nfruFitA[_3998]);
                    }
                    else
                    {
                        _4467 = _4298;
                    }
                    _4501 = _4003 ? _4284 : _4285;
                }
                if (_4285 != _4276)
                {
                    for (uint _4287 = 0u; _4287 < 12u; )
                    {
                        uint _4030 = _3981 + _4287;
                        float _4032 = nfruFitA[_4030];
                        uint _4040 = (_4285 * 12u) + _4287;
                        nfruFitA[_4030] = nfruFitA[_4040];
                        nfruFitA[_4040] = _4032;
                        _4287++;
                        continue;
                    }
                }
                float _4290;
                if (abs(nfruFitA[_3983]) > 9.9999996826552253889678874634872e-21f)
                {
                    _4290 = nfruFitA[_3983];
                }
                else
                {
                    _4290 = 9.9999996826552253889678874634872e-21f;
                }
                for (uint _4292 = _3988; _4292 < 4u; _4292++)
                {
                    uint _4082 = _4292 * 12u;
                    float _4086 = nfruFitA[_4082 + _4276];
                    float _4088 = _4086 / _4290;
                    for (uint _4294 = _4276; _4294 < 4u; )
                    {
                        uint _4099 = _4082 + _4294;
                        nfruFitA[_4099] -= (_4088 * nfruFitA[_3981 + _4294]);
                        _4294++;
                        continue;
                    }
                    uint _4118 = _4082 + 11u;
                    nfruFitA[_4118] -= (_4088 * nfruFitA[_3981 + 11u]);
                }
            }
            for (int _4277 = 3; _4277 >= 0; _4277--)
            {
                uint _4147 = uint(_4277);
                uint _4148 = _4147 * 12u;
                uint _4154 = _4147 + 1u;
                float _4283;
                _4283 = nfruFitA[_4148 + 11u];
                for (uint _4281 = _4154; _4281 < 4u; )
                {
                    _4283 -= (nfruFitA[_4148 + _4281] * nfruFitTheta[_4281]);
                    _4281++;
                    continue;
                }
                uint _4183 = _4148 + _4147;
                nfruFitTheta[_4147] = _4283 / ((abs(nfruFitA[_4183]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_4183] : 9.9999996826552253889678874634872e-21f);
            }
            float4x4 _2691 = transpose(float4x4(float4(_1954[0], _1954[1], _1954[2] * nfruFitScale, _1954[3]), float4(_1954[4], _1954[5], _1954[6] * nfruFitScale, _1954[7]), float4(nfruFitTheta[0], nfruFitTheta[1], nfruFitTheta[2] * nfruFitScale, nfruFitTheta[3]) / nfruFitScale.xxxx, float4(_1954[8], _1954[9], _1954[10] * nfruFitScale, 1.0f)));
            float4x4 _1963 = _2691;
            float4x4 _1964 = spvInverse(_2691);
            uint _4209 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
            uint _4278;
            _4278 = 0u;
            for (; _4278 < 4u; _4278++)
            {
                for (uint _4279 = 0u; _4279 < 4u; )
                {
                    uint _2707 = _4278 * 4u;
                    rw_nfru_diagnostics.Store<uint>(((_4209 + _2707) + _4279) * 4 + 0, asuint(_1963[_4278][_4279]));
                    rw_nfru_diagnostics.Store<uint>((((_4209 + 16u) + _2707) + _4279) * 4 + 0, asuint(_1964[_4278][_4279]));
                    _4279++;
                    continue;
                }
            }
            bool _2745 = nfruFitStat[1] > 250.0f;
            bool _2752;
            if (_2745)
            {
                _2752 = nfruFitStat[0] > (0.4000000059604644775390625f * nfruFitStat[1]);
            }
            else
            {
                _2752 = _2745;
            }
            bool _2755 = _2752 && (nfruFitStat[2] < 1.0f);
            bool _2763;
            if (_2755)
            {
                _2763 = !any(isnan(_1963[0]));
            }
            else
            {
                _2763 = _2755;
            }
            bool _2771;
            if (_2763)
            {
                _2771 = !any(isnan(_1963[3]));
            }
            else
            {
                _2771 = _2763;
            }
            bool _2779;
            if (_2771)
            {
                _2779 = !any(isnan(_1964[0]));
            }
            else
            {
                _2779 = _2771;
            }
            bool _2787;
            if (_2779)
            {
                _2787 = !any(isnan(_1964[3]));
            }
            else
            {
                _2787 = _2779;
            }
            rw_nfru_diagnostics.Store<uint>((_4209 + 32u) * 4 + 0, uint(_2787));
            rw_nfru_diagnostics.Store<uint>((_4209 + 33u) * 4 + 0, asuint(nfruFitStat[2]));
            rw_nfru_diagnostics.Store<uint>((_4209 + 34u) * 4 + 0, uint(nfruFitStat[0]));
            rw_nfru_diagnostics.Store<uint>((_4209 + 35u) * 4 + 0, uint(nfruFitStat[1]));
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
