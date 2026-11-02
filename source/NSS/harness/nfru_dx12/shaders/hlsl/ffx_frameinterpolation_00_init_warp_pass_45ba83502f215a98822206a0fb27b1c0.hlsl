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
groupshared float nfruFitRes[768];
groupshared float nfruFitCw[768];
groupshared float nfruFitScale;
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
    int2 _2024 = int2(gl_GlobalInvocationID.xy);
    if (all(bool2(_2024.x < cbFI_MvDepthLaneSize.x, _2024.y < cbFI_MvDepthLaneSize.y)))
    {
        rw_warped_motion_qdata_tp1[_2024] = uint4(0u, 0u, 0u, 0u).x;
        rw_mv_holes_tp1[_2024] = 0.0f.x;
        rw_mv_holes_tm1[_2024] = 0.0f.x;
    }
    if (all(bool2(_2024.x < cbFI_FlowLaneSize.x, _2024.y < cbFI_FlowLaneSize.y)))
    {
        rw_warped_flow_qdata_tm1[_2024] = uint4(0u, 0u, 0u, 0u).x;
    }
    bool _2033 = (cbFI_NfruT2Flags & 524288u) != 0u;
    bool _2041;
    if (_2033)
    {
        _2041 = gl_WorkGroupID.x == 0u;
    }
    else
    {
        _2041 = _2033;
    }
    bool _2047;
    if (_2041)
    {
        _2047 = gl_WorkGroupID.y == 0u;
    }
    else
    {
        _2047 = _2041;
    }
    if (_2047)
    {
        float2 _2256 = float2(cbFI_RenderSize);
        float2 _2257 = _2256 * 0.5f;
        for (uint _4766 = 0u; _4766 < 3u; _4766++)
        {
            uint _2266 = (gl_LocalInvocationIndex * 3u) + _4766;
            float2 _2279 = 0.02999999932944774627685546875f.xx + ((float2(float(_2266 % 32u) + 0.5f, float(_2266 / 32u) + 0.5f) * float2(0.03125f, 0.0416666679084300994873046875f)) * 0.939999997615814208984375f);
            uint _3326_dummy_parameter;
            float2 _3341 = r_motion_tp1.Load(int3(int2(floor(_2279 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3326_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            uint _3353_dummy_parameter;
            float2 _2286 = _2279 + _3341;
            bool _2289 = all(bool2(_2286.x > 0.0f.xx.x, _2286.y > 0.0f.xx.y));
            bool _2295;
            if (_2289)
            {
                _2295 = all(bool2(_2286.x < 1.0f.xx.x, _2286.y < 1.0f.xx.y));
            }
            else
            {
                _2295 = _2289;
            }
            bool _2302;
            if (_2295)
            {
                _2302 = !any(isnan(_3341));
            }
            else
            {
                _2302 = _2295;
            }
            bool _2309;
            if (_2302)
            {
                _2309 = !any(isinf(_3341));
            }
            else
            {
                _2309 = _2302;
            }
            uint _2311 = _2266 * 3u;
            nfruFitX[_2311] = (2.0f * _2279.x) - 1.0f;
            uint _2319 = _2311 + 1u;
            nfruFitX[_2319] = 1.0f - (2.0f * _2279.y);
            uint _2327 = _2311 + 2u;
            nfruFitX[_2327] = r_depth_tp1.Load(int3(int2(floor(_2279 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3353_dummy_parameter))))), 0)).x;
            float _4997;
            if (_2309)
            {
                _4997 = (2.0f * _2286.x) - 1.0f;
            }
            else
            {
                _4997 = -1000000000.0f;
            }
            nfruFitT[_2311] = _4997;
            nfruFitT[_2319] = 1.0f - (2.0f * _2286.y);
            float _4998;
            if (_2309)
            {
                uint _3369_dummy_parameter;
                _4998 = r_depth_tm1.Load(int3(int2(floor(_2286 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _3369_dummy_parameter))))), 0)).x;
            }
            else
            {
                _4998 = 0.0f;
            }
            nfruFitT[_2327] = _4998;
            nfruFitW[_2266] = float(_2309);
            float _4999;
            if (_2309)
            {
                _4999 = length(_3341 * _2256);
            }
            else
            {
                _4999 = -1.0f;
            }
            nfruFitRes[_2266] = _4999;
            nfruFitCw[_2266] = 1.0f;
        }
        bool _2387 = gl_LocalInvocationIndex == 0u;
        if (_2387)
        {
            nfruFitScale = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        nfruFitA[gl_LocalInvocationIndex % 132u] = 0.0f;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2387)
        {
            float _4768;
            float _4769;
            float _4770;
            _4770 = 0.0f;
            _4769 = 0.0f;
            _4768 = 0.0f;
            float _2409;
            float _5007;
            float _5008;
            for (uint _4767 = 0u; _4767 < 768u; _4770 = _5008, _4769 = _5007, _4768 = _2409, _4767++)
            {
                _2409 = _4768 + nfruFitX[(_4767 * 3u) + 2u];
                if (nfruFitRes[_4767] >= 0.0f)
                {
                    _5008 = _4770 + nfruFitRes[_4767];
                    _5007 = _4769 + 1.0f;
                }
                else
                {
                    _5008 = _4770;
                    _5007 = _4769;
                }
            }
            nfruFitScale = 1.0f / max(_4768 * 0.001302083372138440608978271484375f, 9.9999999747524270787835121154785e-07f);
            float _4771;
            if (_4769 > 0.0f)
            {
                _4771 = _4770 / _4769;
            }
            else
            {
                _4771 = 0.0f;
            }
            nfruFitStat[3] = _4771;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4772 = 0u; _4772 < 3u; _4772++)
        {
            uint _2451 = (gl_LocalInvocationIndex * 3u) + _4772;
            if (nfruFitRes[_2451] < (0.25f * nfruFitStat[3]))
            {
                nfruFitW[_2451] = 0.0f;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4773 = 0u; _4773 < 3u; )
        {
            uint _2479 = (((gl_LocalInvocationIndex * 3u) + _4773) * 3u) + 2u;
            nfruFitX[_2479] *= nfruFitScale;
            nfruFitT[_2479] *= nfruFitScale;
            _4773++;
            continue;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _4774 = 0u; _4774 < 6u; _4774++)
        {
            bool _2504 = _4774 < 3u;
            if (gl_LocalInvocationIndex < 77u)
            {
                if (gl_LocalInvocationIndex < 66u)
                {
                    uint _4871;
                    uint _4873;
                    _4873 = 0u;
                    _4871 = gl_LocalInvocationIndex;
                    for (uint _4872 = 11u; _4871 >= _4872; )
                    {
                        uint _3399 = _4871 - _4872;
                        _4873++;
                        _4872--;
                        _4871 = _3399;
                        continue;
                    }
                    uint _3408 = _4873 + _4871;
                    float _4875;
                    _4875 = 0.0f;
                    float _5019;
                    for (uint _4874 = 0u; _4874 < 768u; _4875 = _5019, _4874++)
                    {
                        float _2531 = nfruFitW[_4874] / max(nfruFitCw[_4874] * nfruFitCw[_4874], 9.9999999747524270787835121154785e-07f);
                        if (_2531 > 0.0f)
                        {
                            uint _3427;
                            uint _3432;
                            uint _3437;
                            bool _3455;
                            float _4949;
                            do
                            {
                                _3427 = _4874 * 3u;
                                _3432 = _3427 + 1u;
                                _3437 = _3427 + 2u;
                                _3455 = _4873 < 4u;
                                if (_3455)
                                {
                                    float _4948;
                                    if (_4873 == 0u)
                                    {
                                        _4948 = nfruFitX[_3427];
                                    }
                                    else
                                    {
                                        float _4947;
                                        if (_4873 == 1u)
                                        {
                                            _4947 = nfruFitX[_3432];
                                        }
                                        else
                                        {
                                            _4947 = (_4873 == 2u) ? nfruFitX[_3437] : 1.0f;
                                        }
                                        _4948 = _4947;
                                    }
                                    _4949 = _4948;
                                    break;
                                }
                                if (_4873 < 8u)
                                {
                                    _4949 = 0.0f;
                                    break;
                                }
                                float _4946;
                                if (_4873 == 8u)
                                {
                                    _4946 = nfruFitX[_3427];
                                }
                                else
                                {
                                    _4946 = (_4873 == 9u) ? nfruFitX[_3432] : nfruFitX[_3437];
                                }
                                _4949 = (-nfruFitT[_3427]) * _4946;
                                break;
                            } while(false);
                            bool _3571;
                            float _4957;
                            do
                            {
                                _3571 = _3408 < 4u;
                                if (_3571)
                                {
                                    float _4956;
                                    if (_3408 == 0u)
                                    {
                                        _4956 = nfruFitX[_3427];
                                    }
                                    else
                                    {
                                        float _4955;
                                        if (_3408 == 1u)
                                        {
                                            _4955 = nfruFitX[_3432];
                                        }
                                        else
                                        {
                                            _4955 = (_3408 == 2u) ? nfruFitX[_3437] : 1.0f;
                                        }
                                        _4956 = _4955;
                                    }
                                    _4957 = _4956;
                                    break;
                                }
                                if (_3408 < 8u)
                                {
                                    _4957 = 0.0f;
                                    break;
                                }
                                float _4954;
                                if (_3408 == 8u)
                                {
                                    _4954 = nfruFitX[_3427];
                                }
                                else
                                {
                                    _4954 = (_3408 == 9u) ? nfruFitX[_3432] : nfruFitX[_3437];
                                }
                                _4957 = (-nfruFitT[_3427]) * _4954;
                                break;
                            } while(false);
                            float _4965;
                            do
                            {
                                if (_3455)
                                {
                                    _4965 = 0.0f;
                                    break;
                                }
                                if (_4873 < 8u)
                                {
                                    float _4964;
                                    if (_4873 == 4u)
                                    {
                                        _4964 = nfruFitX[_3427];
                                    }
                                    else
                                    {
                                        float _4963;
                                        if (_4873 == 5u)
                                        {
                                            _4963 = nfruFitX[_3432];
                                        }
                                        else
                                        {
                                            _4963 = (_4873 == 6u) ? nfruFitX[_3437] : 1.0f;
                                        }
                                        _4964 = _4963;
                                    }
                                    _4965 = _4964;
                                    break;
                                }
                                float _4962;
                                if (_4873 == 8u)
                                {
                                    _4962 = nfruFitX[_3427];
                                }
                                else
                                {
                                    _4962 = (_4873 == 9u) ? nfruFitX[_3432] : nfruFitX[_3437];
                                }
                                _4965 = (-nfruFitT[_3432]) * _4962;
                                break;
                            } while(false);
                            float _4973;
                            do
                            {
                                if (_3571)
                                {
                                    _4973 = 0.0f;
                                    break;
                                }
                                if (_3408 < 8u)
                                {
                                    float _4972;
                                    if (_3408 == 4u)
                                    {
                                        _4972 = nfruFitX[_3427];
                                    }
                                    else
                                    {
                                        float _4971;
                                        if (_3408 == 5u)
                                        {
                                            _4971 = nfruFitX[_3432];
                                        }
                                        else
                                        {
                                            _4971 = (_3408 == 6u) ? nfruFitX[_3437] : 1.0f;
                                        }
                                        _4972 = _4971;
                                    }
                                    _4973 = _4972;
                                    break;
                                }
                                float _4970;
                                if (_3408 == 8u)
                                {
                                    _4970 = nfruFitX[_3427];
                                }
                                else
                                {
                                    _4970 = (_3408 == 9u) ? nfruFitX[_3432] : nfruFitX[_3437];
                                }
                                _4973 = (-nfruFitT[_3432]) * _4970;
                                break;
                            } while(false);
                            _5019 = _4875 + (_2531 * ((_4949 * _4957) + (_4965 * _4973)));
                        }
                        else
                        {
                            _5019 = _4875;
                        }
                    }
                    nfruFitA[(_4873 * 12u) + _3408] = _4875;
                    nfruFitA[(_3408 * 12u) + _4873] = _4875;
                }
                else
                {
                    uint _2573 = gl_LocalInvocationIndex - 66u;
                    float _4845;
                    _4845 = 0.0f;
                    float _5018;
                    for (uint _4844 = 0u; _4844 < 768u; _4845 = _5018, _4844++)
                    {
                        float _2590 = nfruFitW[_4844] / max(nfruFitCw[_4844] * nfruFitCw[_4844], 9.9999999747524270787835121154785e-07f);
                        if (_2590 > 0.0f)
                        {
                            uint _3891;
                            uint _3896;
                            uint _3901;
                            bool _3919;
                            float _4849;
                            do
                            {
                                _3891 = _4844 * 3u;
                                _3896 = _3891 + 1u;
                                _3901 = _3891 + 2u;
                                _3919 = _2573 < 4u;
                                if (_3919)
                                {
                                    float _4848;
                                    if (_2573 == 0u)
                                    {
                                        _4848 = nfruFitX[_3891];
                                    }
                                    else
                                    {
                                        float _4847;
                                        if (_2573 == 1u)
                                        {
                                            _4847 = nfruFitX[_3896];
                                        }
                                        else
                                        {
                                            _4847 = (_2573 == 2u) ? nfruFitX[_3901] : 1.0f;
                                        }
                                        _4848 = _4847;
                                    }
                                    _4849 = _4848;
                                    break;
                                }
                                if (_2573 < 8u)
                                {
                                    _4849 = 0.0f;
                                    break;
                                }
                                float _4846;
                                if (_2573 == 8u)
                                {
                                    _4846 = nfruFitX[_3891];
                                }
                                else
                                {
                                    _4846 = (_2573 == 9u) ? nfruFitX[_3896] : nfruFitX[_3901];
                                }
                                _4849 = (-nfruFitT[_3891]) * _4846;
                                break;
                            } while(false);
                            float _4857;
                            do
                            {
                                if (_3919)
                                {
                                    _4857 = 0.0f;
                                    break;
                                }
                                if (_2573 < 8u)
                                {
                                    float _4856;
                                    if (_2573 == 4u)
                                    {
                                        _4856 = nfruFitX[_3891];
                                    }
                                    else
                                    {
                                        float _4855;
                                        if (_2573 == 5u)
                                        {
                                            _4855 = nfruFitX[_3896];
                                        }
                                        else
                                        {
                                            _4855 = (_2573 == 6u) ? nfruFitX[_3901] : 1.0f;
                                        }
                                        _4856 = _4855;
                                    }
                                    _4857 = _4856;
                                    break;
                                }
                                float _4854;
                                if (_2573 == 8u)
                                {
                                    _4854 = nfruFitX[_3891];
                                }
                                else
                                {
                                    _4854 = (_2573 == 9u) ? nfruFitX[_3896] : nfruFitX[_3901];
                                }
                                _4857 = (-nfruFitT[_3896]) * _4854;
                                break;
                            } while(false);
                            _5018 = _4845 + (_2590 * ((_4849 * nfruFitT[_3891]) + (_4857 * nfruFitT[_3896])));
                        }
                        else
                        {
                            _5018 = _4845;
                        }
                    }
                    nfruFitA[(_2573 * 12u) + 11u] = _4845;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2387)
            {
                float _4945;
                _4945 = 0.0f;
                for (uint _4877 = 0u; _4877 < 11u; )
                {
                    _4945 += nfruFitA[(_4877 * 12u) + _4877];
                    _4877++;
                    continue;
                }
                for (uint _4878 = 0u; _4878 < 11u; )
                {
                    uint _2657 = (_4878 * 12u) + _4878;
                    nfruFitA[_2657] += (9.999999717180685365747194737196e-10f * _4945);
                    _4878++;
                    continue;
                }
                if (_2504)
                {
                    uint _4879;
                    _4879 = 2u;
                    for (; _4879 <= 10u; _4879 += 4u)
                    {
                        for (uint _4942 = 0u; _4942 < 11u; )
                        {
                            nfruFitA[(_4879 * 12u) + _4942] = 0.0f;
                            nfruFitA[(_4942 * 12u) + _4879] = 0.0f;
                            _4942++;
                            continue;
                        }
                        uint _2695 = _4879 * 12u;
                        nfruFitA[_2695 + _4879] = 1.0f;
                        nfruFitA[_2695 + 11u] = 0.0f;
                    }
                }
                for (uint _4880 = 0u; _4880 < 11u; _4880++)
                {
                    uint _4130 = _4880 * 12u;
                    uint _4132 = _4130 + _4880;
                    float _4135 = abs(nfruFitA[_4132]);
                    uint _4137 = _4880 + 1u;
                    uint _4927;
                    _4927 = _4880;
                    uint _5055;
                    float _5054;
                    uint _4926 = _4137;
                    float _4940 = _4135;
                    for (; _4926 < 11u; _4940 = _5054, _4927 = _5055, _4926++)
                    {
                        uint _4147 = (_4926 * 12u) + _4880;
                        bool _4152 = abs(nfruFitA[_4147]) > _4940;
                        if (_4152)
                        {
                            _5054 = abs(nfruFitA[_4147]);
                        }
                        else
                        {
                            _5054 = _4940;
                        }
                        _5055 = _4152 ? _4926 : _4927;
                    }
                    if (_4927 != _4880)
                    {
                        for (uint _4929 = 0u; _4929 < 12u; )
                        {
                            uint _4179 = _4130 + _4929;
                            float _4181 = nfruFitA[_4179];
                            uint _4189 = (_4927 * 12u) + _4929;
                            nfruFitA[_4179] = nfruFitA[_4189];
                            nfruFitA[_4189] = _4181;
                            _4929++;
                            continue;
                        }
                    }
                    float _4932;
                    if (abs(nfruFitA[_4132]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _4932 = nfruFitA[_4132];
                    }
                    else
                    {
                        _4932 = 9.9999996826552253889678874634872e-21f;
                    }
                    for (uint _4934 = _4137; _4934 < 11u; _4934++)
                    {
                        uint _4231 = _4934 * 12u;
                        float _4235 = nfruFitA[_4231 + _4880];
                        float _4237 = _4235 / _4932;
                        for (uint _4936 = _4880; _4936 < 11u; )
                        {
                            uint _4248 = _4231 + _4936;
                            nfruFitA[_4248] -= (_4237 * nfruFitA[_4130 + _4936]);
                            _4936++;
                            continue;
                        }
                        uint _4267 = _4231 + 11u;
                        nfruFitA[_4267] -= (_4237 * nfruFitA[_4130 + 11u]);
                    }
                }
                for (int _4881 = 10; _4881 >= 0; _4881--)
                {
                    uint _4296 = uint(_4881);
                    uint _4297 = _4296 * 12u;
                    uint _4303 = _4296 + 1u;
                    float _4925;
                    _4925 = nfruFitA[_4297 + 11u];
                    for (uint _4923 = _4303; _4923 < 11u; )
                    {
                        _4925 -= (nfruFitA[_4297 + _4923] * nfruFitTheta[_4923]);
                        _4923++;
                        continue;
                    }
                    uint _4332 = _4297 + _4296;
                    nfruFitTheta[_4296] = _4925 / ((abs(nfruFitA[_4332]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_4332] : 9.9999996826552253889678874634872e-21f);
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            float _4905;
            if (_4774 == 0u)
            {
                _4905 = 16.0f;
            }
            else
            {
                float _4904;
                if (_4774 == 1u)
                {
                    _4904 = 6.0f;
                }
                else
                {
                    float _4903;
                    if (_4774 == 2u)
                    {
                        _4903 = 3.0f;
                    }
                    else
                    {
                        _4903 = (_4774 == 3u) ? 2.0f : 1.0f;
                    }
                    _4904 = _4903;
                }
                _4905 = _4904;
            }
            for (uint _4906 = 0u; _4906 < 3u; _4906++)
            {
                uint _2740 = (gl_LocalInvocationIndex * 3u) + _4906;
                uint _4353 = _2740 * 3u;
                bool _4356 = nfruFitT[_4353] > (-100000000.0f);
                float _4911;
                if (_4356)
                {
                    uint _2751 = _4353 + 1u;
                    uint _2756 = _4353 + 2u;
                    nfruFitCw[_2740] = (((nfruFitTheta[8] * nfruFitX[_4353]) + (nfruFitTheta[9] * nfruFitX[_2751])) + (nfruFitTheta[10] * nfruFitX[_2756])) + 1.0f;
                    float _4393 = (((nfruFitTheta[8] * nfruFitX[_4353]) + (nfruFitTheta[9] * nfruFitX[_2751])) + (nfruFitTheta[10] * nfruFitX[_2756])) + 1.0f;
                    _4911 = length(float2(((((((nfruFitTheta[0] * nfruFitX[_4353]) + (nfruFitTheta[1] * nfruFitX[_2751])) + (nfruFitTheta[2] * nfruFitX[_2756])) + nfruFitTheta[3]) / _4393) - nfruFitT[_4353]) * _2257.x, ((((((nfruFitTheta[4] * nfruFitX[_4353]) + (nfruFitTheta[5] * nfruFitX[_2751])) + (nfruFitTheta[6] * nfruFitX[_2756])) + nfruFitTheta[7]) / _4393) - nfruFitT[_2751]) * _2257.y));
                }
                else
                {
                    _4911 = 1000000000.0f;
                }
                nfruFitRes[_2740] = _4911;
                if (!_4356)
                {
                    nfruFitW[_2740] = 0.0f;
                }
                else
                {
                    if (_4774 == 2u)
                    {
                        nfruFitW[_2740] = float(_4911 < 4.0f);
                    }
                    else
                    {
                        if (_4774 > 2u)
                        {
                            float _4915;
                            if (_4911 < 8.0f)
                            {
                                float _4914;
                                if (_4911 < _4905)
                                {
                                    _4914 = 1.0f;
                                }
                                else
                                {
                                    _4914 = _4905 / max(_4911, 9.9999999747524270787835121154785e-07f);
                                }
                                _4915 = _4914;
                            }
                            else
                            {
                                _4915 = 0.0f;
                            }
                            nfruFitW[_2740] = _4915;
                        }
                        else
                        {
                            float _4913;
                            if (_4911 < _4905)
                            {
                                _4913 = 1.0f;
                            }
                            else
                            {
                                _4913 = _4905 / max(_4911, 9.9999999747524270787835121154785e-07f);
                            }
                            nfruFitW[_2740] = _4913;
                        }
                    }
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        if (gl_LocalInvocationIndex < 14u)
        {
            if (gl_LocalInvocationIndex < 10u)
            {
                uint _4784;
                uint _4786;
                _4786 = 0u;
                _4784 = gl_LocalInvocationIndex;
                for (uint _4785 = 4u; _4784 >= _4785; )
                {
                    uint _4465 = _4784 - _4785;
                    _4786++;
                    _4785--;
                    _4784 = _4465;
                    continue;
                }
                uint _4474 = _4786 + _4784;
                float _4788;
                _4788 = 0.0f;
                float _5010;
                for (uint _4787 = 0u; _4787 < 768u; _4788 = _5010, _4787++)
                {
                    if (nfruFitRes[_4787] < 1.5f)
                    {
                        float _4827;
                        if (_4786 == 0u)
                        {
                            _4827 = nfruFitX[_4787 * 3u];
                        }
                        else
                        {
                            float _4826;
                            if (_4786 == 1u)
                            {
                                _4826 = nfruFitX[(_4787 * 3u) + 1u];
                            }
                            else
                            {
                                float _4825;
                                if (_4786 == 2u)
                                {
                                    _4825 = nfruFitX[(_4787 * 3u) + 2u];
                                }
                                else
                                {
                                    _4825 = 1.0f;
                                }
                                _4826 = _4825;
                            }
                            _4827 = _4826;
                        }
                        float _4833;
                        if (_4474 == 0u)
                        {
                            _4833 = nfruFitX[_4787 * 3u];
                        }
                        else
                        {
                            float _4832;
                            if (_4474 == 1u)
                            {
                                _4832 = nfruFitX[(_4787 * 3u) + 1u];
                            }
                            else
                            {
                                float _4831;
                                if (_4474 == 2u)
                                {
                                    _4831 = nfruFitX[(_4787 * 3u) + 2u];
                                }
                                else
                                {
                                    _4831 = 1.0f;
                                }
                                _4832 = _4831;
                            }
                            _4833 = _4832;
                        }
                        _5010 = _4788 + (_4827 * _4833);
                    }
                    else
                    {
                        _5010 = _4788;
                    }
                }
                nfruFitA[(_4786 * 12u) + _4474] = _4788;
                nfruFitA[(_4474 * 12u) + _4786] = _4788;
            }
            else
            {
                uint _2954 = gl_LocalInvocationIndex - 10u;
                float _4776;
                _4776 = 0.0f;
                float _5009;
                for (uint _4775 = 0u; _4775 < 768u; _4776 = _5009, _4775++)
                {
                    if (nfruFitRes[_4775] < 1.5f)
                    {
                        uint _2966 = _4775 * 3u;
                        uint _2971 = _2966 + 1u;
                        uint _2976 = _2966 + 2u;
                        float _4778;
                        if (_2954 == 0u)
                        {
                            _4778 = nfruFitX[_2966];
                        }
                        else
                        {
                            float _4777;
                            if (_2954 == 1u)
                            {
                                _4777 = nfruFitX[_2971];
                            }
                            else
                            {
                                _4777 = (_2954 == 2u) ? nfruFitX[_2976] : 1.0f;
                            }
                            _4778 = _4777;
                        }
                        _5009 = _4776 + ((_4778 * nfruFitT[_2976]) * ((((nfruFitTheta[8] * nfruFitX[_2966]) + (nfruFitTheta[9] * nfruFitX[_2971])) + (nfruFitTheta[10] * nfruFitX[_2976])) + 1.0f));
                    }
                    else
                    {
                        _5009 = _4776;
                    }
                }
                nfruFitA[(_2954 * 12u) + 11u] = _4776;
            }
        }
        if (gl_LocalInvocationIndex == 20u)
        {
            float _4791;
            float _4792;
            float _4793;
            _4793 = 0.0f;
            _4792 = 0.0f;
            _4791 = 0.0f;
            float _5011;
            float _5013;
            float _5014;
            for (uint _4790 = 0u; _4790 < 768u; _4793 = _5014, _4792 = _5013, _4791 = _5011, _4790++)
            {
                if (nfruFitRes[_4790] < 100000000.0f)
                {
                    _5013 = _4792 + 1.0f;
                }
                else
                {
                    _5013 = _4792;
                }
                if (nfruFitRes[_4790] < 2.0f)
                {
                    _5014 = _4793 + nfruFitRes[_4790];
                    _5011 = _4791 + 1.0f;
                }
                else
                {
                    _5014 = _4793;
                    _5011 = _4791;
                }
            }
            nfruFitStat[0] = _4791;
            nfruFitStat[1] = _4792;
            float _4794;
            if (_4791 > 0.0f)
            {
                _4794 = _4793 / _4791;
            }
            else
            {
                _4794 = 1000000000.0f;
            }
            nfruFitStat[2] = _4794;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2387)
        {
            float _2236[11];
            for (uint _4795 = 0u; _4795 < 11u; )
            {
                _2236[_4795] = nfruFitTheta[_4795];
                _4795++;
                continue;
            }
            float _3107 = 9.9999999747524270787835121154785e-07f * ((nfruFitA[0] + nfruFitA[13]) + 9.999999717180685365747194737196e-10f);
            for (uint _4796 = 0u; _4796 < 4u; )
            {
                uint _3116 = (_4796 * 12u) + _4796;
                nfruFitA[_3116] += _3107;
                _4796++;
                continue;
            }
            for (uint _4797 = 0u; _4797 < 4u; _4797++)
            {
                uint _4500 = _4797 * 12u;
                uint _4502 = _4500 + _4797;
                float _4505 = abs(nfruFitA[_4502]);
                uint _4507 = _4797 + 1u;
                uint _4806;
                _4806 = _4797;
                uint _5056;
                float _5017;
                uint _4805 = _4507;
                float _4819 = _4505;
                for (; _4805 < 4u; _4819 = _5017, _4806 = _5056, _4805++)
                {
                    uint _4517 = (_4805 * 12u) + _4797;
                    bool _4522 = abs(nfruFitA[_4517]) > _4819;
                    if (_4522)
                    {
                        _5017 = abs(nfruFitA[_4517]);
                    }
                    else
                    {
                        _5017 = _4819;
                    }
                    _5056 = _4522 ? _4805 : _4806;
                }
                if (_4806 != _4797)
                {
                    for (uint _4808 = 0u; _4808 < 12u; )
                    {
                        uint _4549 = _4500 + _4808;
                        float _4551 = nfruFitA[_4549];
                        uint _4559 = (_4806 * 12u) + _4808;
                        nfruFitA[_4549] = nfruFitA[_4559];
                        nfruFitA[_4559] = _4551;
                        _4808++;
                        continue;
                    }
                }
                float _4811;
                if (abs(nfruFitA[_4502]) > 9.9999996826552253889678874634872e-21f)
                {
                    _4811 = nfruFitA[_4502];
                }
                else
                {
                    _4811 = 9.9999996826552253889678874634872e-21f;
                }
                for (uint _4813 = _4507; _4813 < 4u; _4813++)
                {
                    uint _4601 = _4813 * 12u;
                    float _4605 = nfruFitA[_4601 + _4797];
                    float _4607 = _4605 / _4811;
                    for (uint _4815 = _4797; _4815 < 4u; )
                    {
                        uint _4618 = _4601 + _4815;
                        nfruFitA[_4618] -= (_4607 * nfruFitA[_4500 + _4815]);
                        _4815++;
                        continue;
                    }
                    uint _4637 = _4601 + 11u;
                    nfruFitA[_4637] -= (_4607 * nfruFitA[_4500 + 11u]);
                }
            }
            for (int _4798 = 3; _4798 >= 0; _4798--)
            {
                uint _4666 = uint(_4798);
                uint _4667 = _4666 * 12u;
                uint _4673 = _4666 + 1u;
                float _4804;
                _4804 = nfruFitA[_4667 + 11u];
                for (uint _4802 = _4673; _4802 < 4u; )
                {
                    _4804 -= (nfruFitA[_4667 + _4802] * nfruFitTheta[_4802]);
                    _4802++;
                    continue;
                }
                uint _4702 = _4667 + _4666;
                nfruFitTheta[_4666] = _4804 / ((abs(nfruFitA[_4702]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_4702] : 9.9999996826552253889678874634872e-21f);
            }
            float4x4 _3198 = transpose(float4x4(float4(_2236[0], _2236[1], _2236[2] * nfruFitScale, _2236[3]), float4(_2236[4], _2236[5], _2236[6] * nfruFitScale, _2236[7]), float4(nfruFitTheta[0], nfruFitTheta[1], nfruFitTheta[2] * nfruFitScale, nfruFitTheta[3]) / nfruFitScale.xxxx, float4(_2236[8], _2236[9], _2236[10] * nfruFitScale, 1.0f)));
            float4x4 _2245 = _3198;
            float4x4 _2246 = spvInverse(_3198);
            uint _4728 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
            uint _4799;
            _4799 = 0u;
            for (; _4799 < 4u; _4799++)
            {
                for (uint _4800 = 0u; _4800 < 4u; )
                {
                    uint _3214 = _4799 * 4u;
                    rw_nfru_diagnostics.Store<uint>(((_4728 + _3214) + _4800) * 4 + 0, asuint(_2245[_4799][_4800]));
                    rw_nfru_diagnostics.Store<uint>((((_4728 + 16u) + _3214) + _4800) * 4 + 0, asuint(_2246[_4799][_4800]));
                    _4800++;
                    continue;
                }
            }
            bool _3252 = nfruFitStat[1] > 250.0f;
            bool _3259;
            if (_3252)
            {
                _3259 = nfruFitStat[0] > (0.4000000059604644775390625f * nfruFitStat[1]);
            }
            else
            {
                _3259 = _3252;
            }
            bool _3262 = _3259 && (nfruFitStat[2] < 1.0f);
            bool _3270;
            if (_3262)
            {
                _3270 = !any(isnan(_2245[0]));
            }
            else
            {
                _3270 = _3262;
            }
            bool _3278;
            if (_3270)
            {
                _3278 = !any(isnan(_2245[3]));
            }
            else
            {
                _3278 = _3270;
            }
            bool _3286;
            if (_3278)
            {
                _3286 = !any(isnan(_2246[0]));
            }
            else
            {
                _3286 = _3278;
            }
            bool _3294;
            if (_3286)
            {
                _3294 = !any(isnan(_2246[3]));
            }
            else
            {
                _3294 = _3286;
            }
            rw_nfru_diagnostics.Store<uint>((_4728 + 32u) * 4 + 0, uint(_3294));
            rw_nfru_diagnostics.Store<uint>((_4728 + 33u) * 4 + 0, asuint(nfruFitStat[2]));
            rw_nfru_diagnostics.Store<uint>((_4728 + 34u) * 4 + 0, uint(nfruFitStat[0]));
            rw_nfru_diagnostics.Store<uint>((_4728 + 35u) * 4 + 0, uint(nfruFitStat[1]));
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
