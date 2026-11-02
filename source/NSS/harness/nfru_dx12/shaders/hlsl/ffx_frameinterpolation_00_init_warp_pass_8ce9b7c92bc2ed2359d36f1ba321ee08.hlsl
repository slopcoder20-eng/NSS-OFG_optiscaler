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

void comp_main()
{
    int2 _1899 = int2(gl_GlobalInvocationID.xy);
    if (all(bool2(_1899.x < cbFI_MvDepthLaneSize.x, _1899.y < cbFI_MvDepthLaneSize.y)))
    {
        rw_warped_motion_qdata_tp1[_1899] = uint4(0u, 0u, 0u, 0u).x;
        rw_mv_holes_tp1[_1899] = 0.0f.x;
        rw_mv_holes_tm1[_1899] = 0.0f.x;
    }
    if (all(bool2(_1899.x < cbFI_FlowLaneSize.x, _1899.y < cbFI_FlowLaneSize.y)))
    {
        rw_warped_flow_qdata_tm1[_1899] = uint4(0u, 0u, 0u, 0u).x;
    }
    bool _1908 = (cbFI_NfruT2Flags & 524288u) != 0u;
    bool _1916;
    if (_1908)
    {
        _1916 = gl_WorkGroupID.x == 0u;
    }
    else
    {
        _1916 = _1908;
    }
    bool _1922;
    if (_1916)
    {
        _1922 = gl_WorkGroupID.y == 0u;
    }
    else
    {
        _1922 = _1916;
    }
    if (_1922)
    {
        float2 _2062 = float2(cbFI_RenderSize);
        float2 _2063 = _2062 * 0.5f;
        for (uint _5821 = 0u; _5821 < 3u; _5821++)
        {
            uint _2072 = (gl_LocalInvocationIndex * 3u) + _5821;
            float2 _2085 = 0.02999999932944774627685546875f.xx + ((float2(float(_2072 % 32u) + 0.5f, float(_2072 / 32u) + 0.5f) * float2(0.03125f, 0.0416666679084300994873046875f)) * 0.939999997615814208984375f);
            uint _2605_dummy_parameter;
            float2 _2620 = r_motion_tp1.Load(int3(int2(floor(_2085 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2605_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _2090 = _2085 + _2620;
            bool _2093 = all(bool2(_2090.x > 0.0f.xx.x, _2090.y > 0.0f.xx.y));
            bool _2099;
            if (_2093)
            {
                _2099 = all(bool2(_2090.x < 1.0f.xx.x, _2090.y < 1.0f.xx.y));
            }
            else
            {
                _2099 = _2093;
            }
            bool _2106;
            if (_2099)
            {
                _2106 = !any(isnan(_2620));
            }
            else
            {
                _2106 = _2099;
            }
            bool _2113;
            if (_2106)
            {
                _2113 = !any(isinf(_2620));
            }
            else
            {
                _2113 = _2106;
            }
            uint _2115 = _2072 * 3u;
            nfruFitX[_2115] = (2.0f * _2085.x) - 1.0f;
            uint _2123 = _2115 + 1u;
            nfruFitX[_2123] = 1.0f - (2.0f * _2085.y);
            uint _2131 = _2115 + 2u;
            uint _2632_dummy_parameter;
            nfruFitX[_2131] = r_depth_tp1.Load(int3(int2(floor(_2085 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2632_dummy_parameter))))), 0)).x;
            float _6161;
            if (_2113)
            {
                _6161 = (2.0f * _2090.x) - 1.0f;
            }
            else
            {
                _6161 = -1000000000.0f;
            }
            nfruFitT[_2115] = _6161;
            nfruFitT[_2123] = 1.0f - (2.0f * _2090.y);
            float _6162;
            if (_2113)
            {
                uint _2648_dummy_parameter;
                _6162 = r_depth_tm1.Load(int3(int2(floor(_2090 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _2648_dummy_parameter))))), 0)).x;
            }
            else
            {
                _6162 = 0.0f;
            }
            nfruFitT[_2131] = _6162;
            float _6163;
            if (_2113)
            {
                _6163 = length(_2620 * _2062);
            }
            else
            {
                _6163 = -1.0f;
            }
            nfruFitRes[_2072] = _6163;
            nfruFitW[_2072] = float(_2113);
            nfruFitCw[_2072] = 1.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _2190 = gl_LocalInvocationIndex == 0u;
        if (_2190)
        {
            float _5823;
            float _5824;
            float _5825;
            _5825 = 0.0f;
            _5824 = 0.0f;
            _5823 = 0.0f;
            float _2203;
            float _6171;
            float _6172;
            for (uint _5822 = 0u; _5822 < 768u; _5825 = _6172, _5824 = _6171, _5823 = _2203, _5822++)
            {
                _2203 = _5823 + nfruFitX[(_5822 * 3u) + 2u];
                if (nfruFitRes[_5822] >= 0.0f)
                {
                    _6172 = _5825 + nfruFitRes[_5822];
                    _6171 = _5824 + 1.0f;
                }
                else
                {
                    _6172 = _5825;
                    _6171 = _5824;
                }
            }
            nfruFitScale = 1.0f / max(_5823 * 0.001302083372138440608978271484375f, 9.9999999747524270787835121154785e-07f);
            float _5826;
            if (_5824 > 0.0f)
            {
                _5826 = _5825 / _5824;
            }
            else
            {
                _5826 = 0.0f;
            }
            nfruFitStat[7] = _5826;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _5827 = 0u; _5827 < 3u; _5827++)
        {
            uint _2245 = (gl_LocalInvocationIndex * 3u) + _5827;
            uint _2248 = (_2245 * 3u) + 2u;
            nfruFitX[_2248] *= nfruFitScale;
            nfruFitT[_2248] *= nfruFitScale;
            if (nfruFitRes[_2245] < (0.25f * nfruFitStat[7]))
            {
                nfruFitW[_2245] = 0.0f;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _5828 = 0u; _5828 <= 5u; _5828++)
        {
            if (gl_LocalInvocationIndex < 77u)
            {
                if (gl_LocalInvocationIndex < 66u)
                {
                    uint _6033;
                    uint _6035;
                    _6035 = 0u;
                    _6033 = gl_LocalInvocationIndex;
                    for (uint _6034 = 11u; _6033 >= _6034; )
                    {
                        uint _3143 = _6033 - _6034;
                        _6035++;
                        _6034--;
                        _6033 = _3143;
                        continue;
                    }
                    uint _3152 = _6035 + _6033;
                    float _6037;
                    _6037 = 0.0f;
                    float _6220;
                    for (uint _6036 = 0u; _6036 < 768u; _6037 = _6220, _6036++)
                    {
                        float _2754 = nfruFitW[_6036] / max(nfruFitCw[_6036] * nfruFitCw[_6036], 9.9999999747524270787835121154785e-07f);
                        if (_2754 > 0.0f)
                        {
                            uint _3171;
                            uint _3176;
                            uint _3181;
                            bool _3199;
                            float _6113;
                            do
                            {
                                _3171 = _6036 * 3u;
                                _3176 = _3171 + 1u;
                                _3181 = _3171 + 2u;
                                _3199 = _6035 < 4u;
                                if (_3199)
                                {
                                    float _6112;
                                    if (_6035 == 0u)
                                    {
                                        _6112 = nfruFitX[_3171];
                                    }
                                    else
                                    {
                                        float _6111;
                                        if (_6035 == 1u)
                                        {
                                            _6111 = nfruFitX[_3176];
                                        }
                                        else
                                        {
                                            _6111 = (_6035 == 2u) ? nfruFitX[_3181] : 1.0f;
                                        }
                                        _6112 = _6111;
                                    }
                                    _6113 = _6112;
                                    break;
                                }
                                if (_6035 < 8u)
                                {
                                    _6113 = 0.0f;
                                    break;
                                }
                                float _6110;
                                if (_6035 == 8u)
                                {
                                    _6110 = nfruFitX[_3171];
                                }
                                else
                                {
                                    _6110 = (_6035 == 9u) ? nfruFitX[_3176] : nfruFitX[_3181];
                                }
                                _6113 = (-nfruFitT[_3171]) * _6110;
                                break;
                            } while(false);
                            bool _3315;
                            float _6121;
                            do
                            {
                                _3315 = _3152 < 4u;
                                if (_3315)
                                {
                                    float _6120;
                                    if (_3152 == 0u)
                                    {
                                        _6120 = nfruFitX[_3171];
                                    }
                                    else
                                    {
                                        float _6119;
                                        if (_3152 == 1u)
                                        {
                                            _6119 = nfruFitX[_3176];
                                        }
                                        else
                                        {
                                            _6119 = (_3152 == 2u) ? nfruFitX[_3181] : 1.0f;
                                        }
                                        _6120 = _6119;
                                    }
                                    _6121 = _6120;
                                    break;
                                }
                                if (_3152 < 8u)
                                {
                                    _6121 = 0.0f;
                                    break;
                                }
                                float _6118;
                                if (_3152 == 8u)
                                {
                                    _6118 = nfruFitX[_3171];
                                }
                                else
                                {
                                    _6118 = (_3152 == 9u) ? nfruFitX[_3176] : nfruFitX[_3181];
                                }
                                _6121 = (-nfruFitT[_3171]) * _6118;
                                break;
                            } while(false);
                            float _6129;
                            do
                            {
                                if (_3199)
                                {
                                    _6129 = 0.0f;
                                    break;
                                }
                                if (_6035 < 8u)
                                {
                                    float _6128;
                                    if (_6035 == 4u)
                                    {
                                        _6128 = nfruFitX[_3171];
                                    }
                                    else
                                    {
                                        float _6127;
                                        if (_6035 == 5u)
                                        {
                                            _6127 = nfruFitX[_3176];
                                        }
                                        else
                                        {
                                            _6127 = (_6035 == 6u) ? nfruFitX[_3181] : 1.0f;
                                        }
                                        _6128 = _6127;
                                    }
                                    _6129 = _6128;
                                    break;
                                }
                                float _6126;
                                if (_6035 == 8u)
                                {
                                    _6126 = nfruFitX[_3171];
                                }
                                else
                                {
                                    _6126 = (_6035 == 9u) ? nfruFitX[_3176] : nfruFitX[_3181];
                                }
                                _6129 = (-nfruFitT[_3176]) * _6126;
                                break;
                            } while(false);
                            float _6137;
                            do
                            {
                                if (_3315)
                                {
                                    _6137 = 0.0f;
                                    break;
                                }
                                if (_3152 < 8u)
                                {
                                    float _6136;
                                    if (_3152 == 4u)
                                    {
                                        _6136 = nfruFitX[_3171];
                                    }
                                    else
                                    {
                                        float _6135;
                                        if (_3152 == 5u)
                                        {
                                            _6135 = nfruFitX[_3176];
                                        }
                                        else
                                        {
                                            _6135 = (_3152 == 6u) ? nfruFitX[_3181] : 1.0f;
                                        }
                                        _6136 = _6135;
                                    }
                                    _6137 = _6136;
                                    break;
                                }
                                float _6134;
                                if (_3152 == 8u)
                                {
                                    _6134 = nfruFitX[_3171];
                                }
                                else
                                {
                                    _6134 = (_3152 == 9u) ? nfruFitX[_3176] : nfruFitX[_3181];
                                }
                                _6137 = (-nfruFitT[_3176]) * _6134;
                                break;
                            } while(false);
                            _6220 = _6037 + (_2754 * ((_6113 * _6121) + (_6129 * _6137)));
                        }
                        else
                        {
                            _6220 = _6037;
                        }
                    }
                    nfruFitA[(_6035 * 12u) + _3152] = _6037;
                    nfruFitA[(_3152 * 12u) + _6035] = _6037;
                }
                else
                {
                    uint _2796 = gl_LocalInvocationIndex - 66u;
                    float _6007;
                    _6007 = 0.0f;
                    float _6219;
                    for (uint _6006 = 0u; _6006 < 768u; _6007 = _6219, _6006++)
                    {
                        float _2813 = nfruFitW[_6006] / max(nfruFitCw[_6006] * nfruFitCw[_6006], 9.9999999747524270787835121154785e-07f);
                        if (_2813 > 0.0f)
                        {
                            uint _3635;
                            uint _3640;
                            uint _3645;
                            bool _3663;
                            float _6011;
                            do
                            {
                                _3635 = _6006 * 3u;
                                _3640 = _3635 + 1u;
                                _3645 = _3635 + 2u;
                                _3663 = _2796 < 4u;
                                if (_3663)
                                {
                                    float _6010;
                                    if (_2796 == 0u)
                                    {
                                        _6010 = nfruFitX[_3635];
                                    }
                                    else
                                    {
                                        float _6009;
                                        if (_2796 == 1u)
                                        {
                                            _6009 = nfruFitX[_3640];
                                        }
                                        else
                                        {
                                            _6009 = (_2796 == 2u) ? nfruFitX[_3645] : 1.0f;
                                        }
                                        _6010 = _6009;
                                    }
                                    _6011 = _6010;
                                    break;
                                }
                                if (_2796 < 8u)
                                {
                                    _6011 = 0.0f;
                                    break;
                                }
                                float _6008;
                                if (_2796 == 8u)
                                {
                                    _6008 = nfruFitX[_3635];
                                }
                                else
                                {
                                    _6008 = (_2796 == 9u) ? nfruFitX[_3640] : nfruFitX[_3645];
                                }
                                _6011 = (-nfruFitT[_3635]) * _6008;
                                break;
                            } while(false);
                            float _6019;
                            do
                            {
                                if (_3663)
                                {
                                    _6019 = 0.0f;
                                    break;
                                }
                                if (_2796 < 8u)
                                {
                                    float _6018;
                                    if (_2796 == 4u)
                                    {
                                        _6018 = nfruFitX[_3635];
                                    }
                                    else
                                    {
                                        float _6017;
                                        if (_2796 == 5u)
                                        {
                                            _6017 = nfruFitX[_3640];
                                        }
                                        else
                                        {
                                            _6017 = (_2796 == 6u) ? nfruFitX[_3645] : 1.0f;
                                        }
                                        _6018 = _6017;
                                    }
                                    _6019 = _6018;
                                    break;
                                }
                                float _6016;
                                if (_2796 == 8u)
                                {
                                    _6016 = nfruFitX[_3635];
                                }
                                else
                                {
                                    _6016 = (_2796 == 9u) ? nfruFitX[_3640] : nfruFitX[_3645];
                                }
                                _6019 = (-nfruFitT[_3640]) * _6016;
                                break;
                            } while(false);
                            _6219 = _6007 + (_2813 * ((_6011 * nfruFitT[_3635]) + (_6019 * nfruFitT[_3640])));
                        }
                        else
                        {
                            _6219 = _6007;
                        }
                    }
                    nfruFitA[(_2796 * 12u) + 11u] = _6007;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2190)
            {
                float _6109;
                _6109 = 0.0f;
                for (uint _6039 = 0u; _6039 < 11u; )
                {
                    _6109 += nfruFitA[(_6039 * 12u) + _6039];
                    _6039++;
                    continue;
                }
                for (uint _6040 = 0u; _6040 < 11u; )
                {
                    uint _2880 = (_6040 * 12u) + _6040;
                    nfruFitA[_2880] += (9.999999717180685365747194737196e-10f * _6109);
                    _6040++;
                    continue;
                }
                if (_5828 < 3u)
                {
                    uint _6057;
                    _6057 = 2u;
                    for (; _6057 <= 10u; _6057 += 4u)
                    {
                        for (uint _6104 = 0u; _6104 < 12u; )
                        {
                            nfruFitA[(_6057 * 12u) + _6104] = 0.0f;
                            _6104++;
                            continue;
                        }
                        for (uint _6105 = 0u; _6105 < 11u; )
                        {
                            nfruFitA[(_6105 * 12u) + _6057] = 0.0f;
                            _6105++;
                            continue;
                        }
                        nfruFitA[(_6057 * 12u) + _6057] = 1.0f;
                    }
                }
                for (uint _6058 = 0u; _6058 < 11u; _6058++)
                {
                    uint _3873 = _6058 * 12u;
                    uint _3875 = _3873 + _6058;
                    float _3878 = abs(nfruFitA[_3875]);
                    uint _3880 = _6058 + 1u;
                    uint _6089;
                    _6089 = _6058;
                    uint _6257;
                    float _6256;
                    uint _6088 = _3880;
                    float _6102 = _3878;
                    for (; _6088 < 11u; _6102 = _6256, _6089 = _6257, _6088++)
                    {
                        uint _3889 = (_6088 * 12u) + _6058;
                        bool _3894 = abs(nfruFitA[_3889]) > _6102;
                        if (_3894)
                        {
                            _6256 = abs(nfruFitA[_3889]);
                        }
                        else
                        {
                            _6256 = _6102;
                        }
                        _6257 = _3894 ? _6088 : _6089;
                    }
                    if (_6089 != _6058)
                    {
                        for (uint _6091 = 0u; _6091 < 12u; )
                        {
                            uint _3921 = _3873 + _6091;
                            float _3923 = nfruFitA[_3921];
                            uint _3931 = (_6089 * 12u) + _6091;
                            nfruFitA[_3921] = nfruFitA[_3931];
                            nfruFitA[_3931] = _3923;
                            _6091++;
                            continue;
                        }
                    }
                    float _6094;
                    if (abs(nfruFitA[_3875]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _6094 = nfruFitA[_3875];
                    }
                    else
                    {
                        _6094 = 9.9999996826552253889678874634872e-21f;
                    }
                    for (uint _6096 = _3880; _6096 < 11u; _6096++)
                    {
                        uint _3972 = _6096 * 12u;
                        float _3978 = nfruFitA[_3972 + _6058] / _6094;
                        for (uint _6098 = _6058; _6098 < 12u; )
                        {
                            uint _3988 = _3972 + _6098;
                            nfruFitA[_3988] -= (_3978 * nfruFitA[_3873 + _6098]);
                            _6098++;
                            continue;
                        }
                    }
                }
                for (int _6059 = 10; _6059 >= 0; _6059--)
                {
                    uint _4019 = uint(_6059);
                    uint _4020 = _4019 * 12u;
                    uint _4026 = _4019 + 1u;
                    float _6087;
                    _6087 = nfruFitA[_4020 + 11u];
                    for (uint _6085 = _4026; _6085 < 11u; )
                    {
                        _6087 -= (nfruFitA[_4020 + _6085] * nfruFitTheta[_6085]);
                        _6085++;
                        continue;
                    }
                    uint _4054 = _4020 + _4019;
                    nfruFitTheta[_4019] = _6087 / ((abs(nfruFitA[_4054]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_4054] : 9.9999996826552253889678874634872e-21f);
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            float _6067;
            if (_5828 == 0u)
            {
                _6067 = 16.0f;
            }
            else
            {
                float _6066;
                if (_5828 == 1u)
                {
                    _6066 = 6.0f;
                }
                else
                {
                    float _6065;
                    if (_5828 == 2u)
                    {
                        _6065 = 3.0f;
                    }
                    else
                    {
                        _6065 = (_5828 == 3u) ? 2.0f : 1.0f;
                    }
                    _6066 = _6065;
                }
                _6067 = _6066;
            }
            for (uint _6068 = 0u; _6068 < 3u; _6068++)
            {
                uint _2969 = (gl_LocalInvocationIndex * 3u) + _6068;
                uint _4075 = _2969 * 3u;
                float _6073;
                if (nfruFitT[_4075] > (-100000000.0f))
                {
                    uint _2979 = _4075 + 1u;
                    uint _2984 = _4075 + 2u;
                    float _3001 = (((nfruFitTheta[8] * nfruFitX[_4075]) + (nfruFitTheta[9] * nfruFitX[_2979])) + (nfruFitTheta[10] * nfruFitX[_2984])) + 1.0f;
                    nfruFitCw[_2969] = _3001;
                    _6073 = length(float2(((((((nfruFitTheta[0] * nfruFitX[_4075]) + (nfruFitTheta[1] * nfruFitX[_2979])) + (nfruFitTheta[2] * nfruFitX[_2984])) + nfruFitTheta[3]) / _3001) - nfruFitT[_4075]) * _2063.x, ((((((nfruFitTheta[4] * nfruFitX[_4075]) + (nfruFitTheta[5] * nfruFitX[_2979])) + (nfruFitTheta[6] * nfruFitX[_2984])) + nfruFitTheta[7]) / _3001) - nfruFitT[_2979]) * _2063.y));
                }
                else
                {
                    _6073 = 1000000000.0f;
                }
                nfruFitRes[_2969] = _6073;
                if (!(nfruFitT[_4075] > (-100000000.0f)))
                {
                    nfruFitW[_2969] = 0.0f;
                }
                else
                {
                    if (_5828 == 2u)
                    {
                        nfruFitW[_2969] = float(_6073 < 4.0f);
                    }
                    else
                    {
                        if (_5828 > 2u)
                        {
                            float _6077;
                            if (_6073 < 8.0f)
                            {
                                float _6076;
                                if (_6073 < _6067)
                                {
                                    _6076 = 1.0f;
                                }
                                else
                                {
                                    _6076 = _6067 / max(_6073, 9.9999999747524270787835121154785e-07f);
                                }
                                _6077 = _6076;
                            }
                            else
                            {
                                _6077 = 0.0f;
                            }
                            nfruFitW[_2969] = _6077;
                        }
                        else
                        {
                            float _6075;
                            if (_6073 < _6067)
                            {
                                _6075 = 1.0f;
                            }
                            else
                            {
                                _6075 = _6067 / max(_6073, 9.9999999747524270787835121154785e-07f);
                            }
                            nfruFitW[_2969] = _6075;
                        }
                    }
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        bool _2282 = gl_LocalInvocationIndex == 20u;
        if (_2282)
        {
            float _5830;
            float _5831;
            float _5832;
            _5832 = 0.0f;
            _5831 = 0.0f;
            _5830 = 0.0f;
            float _6173;
            float _6175;
            float _6176;
            for (uint _5829 = 0u; _5829 < 768u; _5832 = _6176, _5831 = _6175, _5830 = _6173, _5829++)
            {
                if (nfruFitT[_5829 * 3u] > (-100000000.0f))
                {
                    _6175 = _5831 + 1.0f;
                }
                else
                {
                    _6175 = _5831;
                }
                if (nfruFitRes[_5829] < 2.0f)
                {
                    _6176 = _5832 + nfruFitRes[_5829];
                    _6173 = _5830 + 1.0f;
                }
                else
                {
                    _6176 = _5832;
                    _6173 = _5830;
                }
            }
            nfruFitStat[0u] = _5830;
            nfruFitStat[1u] = _5831;
            float _5833;
            if (_5830 > 0.0f)
            {
                _5833 = _5832 / _5830;
            }
            else
            {
                _5833 = 1000000000.0f;
            }
            nfruFitStat[2u] = _5833;
        }
        if (gl_LocalInvocationIndex < 11u)
        {
            nfruFitThetaF[gl_LocalInvocationIndex] = nfruFitTheta[gl_LocalInvocationIndex];
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _5834 = 0u; _5834 < 3u; _5834++)
        {
            uint _2304 = (gl_LocalInvocationIndex * 3u) + _5834;
            uint _4152 = _2304 * 3u;
            bool _4155 = nfruFitT[_4152] > (-100000000.0f);
            bool _2313;
            if (_4155)
            {
                _2313 = nfruFitRes[_2304] < 1.5f;
            }
            else
            {
                _2313 = _4155;
            }
            float _2317 = nfruFitX[_4152];
            uint _2320 = _4152 + 1u;
            float _2322 = nfruFitX[_2320];
            uint _2325 = _4152 + 2u;
            float _2327 = nfruFitX[_2325];
            nfruFitX[_4152] = nfruFitT[_4152];
            nfruFitX[_2320] = nfruFitT[_2320];
            nfruFitX[_2325] = nfruFitT[_2325];
            nfruFitT[_4152] = _2313 ? _2317 : (-1000000000.0f);
            nfruFitT[_2320] = _2322;
            nfruFitT[_2325] = _2327;
            nfruFitW[_2304] = float(_2313);
            nfruFitCw[_2304] = 1.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _5835 = 3u; _5835 <= 5u; _5835++)
        {
            if (gl_LocalInvocationIndex < 77u)
            {
                if (gl_LocalInvocationIndex < 66u)
                {
                    uint _5875;
                    uint _5877;
                    _5877 = 0u;
                    _5875 = gl_LocalInvocationIndex;
                    for (uint _5876 = 11u; _5875 >= _5876; )
                    {
                        uint _4635 = _5875 - _5876;
                        _5877++;
                        _5876--;
                        _5875 = _4635;
                        continue;
                    }
                    uint _4644 = _5877 + _5875;
                    float _5879;
                    _5879 = 0.0f;
                    float _6182;
                    for (uint _5878 = 0u; _5878 < 768u; _5879 = _6182, _5878++)
                    {
                        float _4246 = nfruFitW[_5878] / max(nfruFitCw[_5878] * nfruFitCw[_5878], 9.9999999747524270787835121154785e-07f);
                        if (_4246 > 0.0f)
                        {
                            uint _4663;
                            uint _4668;
                            uint _4673;
                            bool _4691;
                            float _5955;
                            do
                            {
                                _4663 = _5878 * 3u;
                                _4668 = _4663 + 1u;
                                _4673 = _4663 + 2u;
                                _4691 = _5877 < 4u;
                                if (_4691)
                                {
                                    float _5954;
                                    if (_5877 == 0u)
                                    {
                                        _5954 = nfruFitX[_4663];
                                    }
                                    else
                                    {
                                        float _5953;
                                        if (_5877 == 1u)
                                        {
                                            _5953 = nfruFitX[_4668];
                                        }
                                        else
                                        {
                                            _5953 = (_5877 == 2u) ? nfruFitX[_4673] : 1.0f;
                                        }
                                        _5954 = _5953;
                                    }
                                    _5955 = _5954;
                                    break;
                                }
                                if (_5877 < 8u)
                                {
                                    _5955 = 0.0f;
                                    break;
                                }
                                float _5952;
                                if (_5877 == 8u)
                                {
                                    _5952 = nfruFitX[_4663];
                                }
                                else
                                {
                                    _5952 = (_5877 == 9u) ? nfruFitX[_4668] : nfruFitX[_4673];
                                }
                                _5955 = (-nfruFitT[_4663]) * _5952;
                                break;
                            } while(false);
                            bool _4807;
                            float _5963;
                            do
                            {
                                _4807 = _4644 < 4u;
                                if (_4807)
                                {
                                    float _5962;
                                    if (_4644 == 0u)
                                    {
                                        _5962 = nfruFitX[_4663];
                                    }
                                    else
                                    {
                                        float _5961;
                                        if (_4644 == 1u)
                                        {
                                            _5961 = nfruFitX[_4668];
                                        }
                                        else
                                        {
                                            _5961 = (_4644 == 2u) ? nfruFitX[_4673] : 1.0f;
                                        }
                                        _5962 = _5961;
                                    }
                                    _5963 = _5962;
                                    break;
                                }
                                if (_4644 < 8u)
                                {
                                    _5963 = 0.0f;
                                    break;
                                }
                                float _5960;
                                if (_4644 == 8u)
                                {
                                    _5960 = nfruFitX[_4663];
                                }
                                else
                                {
                                    _5960 = (_4644 == 9u) ? nfruFitX[_4668] : nfruFitX[_4673];
                                }
                                _5963 = (-nfruFitT[_4663]) * _5960;
                                break;
                            } while(false);
                            float _5971;
                            do
                            {
                                if (_4691)
                                {
                                    _5971 = 0.0f;
                                    break;
                                }
                                if (_5877 < 8u)
                                {
                                    float _5970;
                                    if (_5877 == 4u)
                                    {
                                        _5970 = nfruFitX[_4663];
                                    }
                                    else
                                    {
                                        float _5969;
                                        if (_5877 == 5u)
                                        {
                                            _5969 = nfruFitX[_4668];
                                        }
                                        else
                                        {
                                            _5969 = (_5877 == 6u) ? nfruFitX[_4673] : 1.0f;
                                        }
                                        _5970 = _5969;
                                    }
                                    _5971 = _5970;
                                    break;
                                }
                                float _5968;
                                if (_5877 == 8u)
                                {
                                    _5968 = nfruFitX[_4663];
                                }
                                else
                                {
                                    _5968 = (_5877 == 9u) ? nfruFitX[_4668] : nfruFitX[_4673];
                                }
                                _5971 = (-nfruFitT[_4668]) * _5968;
                                break;
                            } while(false);
                            float _5979;
                            do
                            {
                                if (_4807)
                                {
                                    _5979 = 0.0f;
                                    break;
                                }
                                if (_4644 < 8u)
                                {
                                    float _5978;
                                    if (_4644 == 4u)
                                    {
                                        _5978 = nfruFitX[_4663];
                                    }
                                    else
                                    {
                                        float _5977;
                                        if (_4644 == 5u)
                                        {
                                            _5977 = nfruFitX[_4668];
                                        }
                                        else
                                        {
                                            _5977 = (_4644 == 6u) ? nfruFitX[_4673] : 1.0f;
                                        }
                                        _5978 = _5977;
                                    }
                                    _5979 = _5978;
                                    break;
                                }
                                float _5976;
                                if (_4644 == 8u)
                                {
                                    _5976 = nfruFitX[_4663];
                                }
                                else
                                {
                                    _5976 = (_4644 == 9u) ? nfruFitX[_4668] : nfruFitX[_4673];
                                }
                                _5979 = (-nfruFitT[_4668]) * _5976;
                                break;
                            } while(false);
                            _6182 = _5879 + (_4246 * ((_5955 * _5963) + (_5971 * _5979)));
                        }
                        else
                        {
                            _6182 = _5879;
                        }
                    }
                    nfruFitA[(_5877 * 12u) + _4644] = _5879;
                    nfruFitA[(_4644 * 12u) + _5877] = _5879;
                }
                else
                {
                    uint _4288 = gl_LocalInvocationIndex - 66u;
                    float _5849;
                    _5849 = 0.0f;
                    float _6181;
                    for (uint _5848 = 0u; _5848 < 768u; _5849 = _6181, _5848++)
                    {
                        float _4305 = nfruFitW[_5848] / max(nfruFitCw[_5848] * nfruFitCw[_5848], 9.9999999747524270787835121154785e-07f);
                        if (_4305 > 0.0f)
                        {
                            uint _5127;
                            uint _5132;
                            uint _5137;
                            bool _5155;
                            float _5853;
                            do
                            {
                                _5127 = _5848 * 3u;
                                _5132 = _5127 + 1u;
                                _5137 = _5127 + 2u;
                                _5155 = _4288 < 4u;
                                if (_5155)
                                {
                                    float _5852;
                                    if (_4288 == 0u)
                                    {
                                        _5852 = nfruFitX[_5127];
                                    }
                                    else
                                    {
                                        float _5851;
                                        if (_4288 == 1u)
                                        {
                                            _5851 = nfruFitX[_5132];
                                        }
                                        else
                                        {
                                            _5851 = (_4288 == 2u) ? nfruFitX[_5137] : 1.0f;
                                        }
                                        _5852 = _5851;
                                    }
                                    _5853 = _5852;
                                    break;
                                }
                                if (_4288 < 8u)
                                {
                                    _5853 = 0.0f;
                                    break;
                                }
                                float _5850;
                                if (_4288 == 8u)
                                {
                                    _5850 = nfruFitX[_5127];
                                }
                                else
                                {
                                    _5850 = (_4288 == 9u) ? nfruFitX[_5132] : nfruFitX[_5137];
                                }
                                _5853 = (-nfruFitT[_5127]) * _5850;
                                break;
                            } while(false);
                            float _5861;
                            do
                            {
                                if (_5155)
                                {
                                    _5861 = 0.0f;
                                    break;
                                }
                                if (_4288 < 8u)
                                {
                                    float _5860;
                                    if (_4288 == 4u)
                                    {
                                        _5860 = nfruFitX[_5127];
                                    }
                                    else
                                    {
                                        float _5859;
                                        if (_4288 == 5u)
                                        {
                                            _5859 = nfruFitX[_5132];
                                        }
                                        else
                                        {
                                            _5859 = (_4288 == 6u) ? nfruFitX[_5137] : 1.0f;
                                        }
                                        _5860 = _5859;
                                    }
                                    _5861 = _5860;
                                    break;
                                }
                                float _5858;
                                if (_4288 == 8u)
                                {
                                    _5858 = nfruFitX[_5127];
                                }
                                else
                                {
                                    _5858 = (_4288 == 9u) ? nfruFitX[_5132] : nfruFitX[_5137];
                                }
                                _5861 = (-nfruFitT[_5132]) * _5858;
                                break;
                            } while(false);
                            _6181 = _5849 + (_4305 * ((_5853 * nfruFitT[_5127]) + (_5861 * nfruFitT[_5132])));
                        }
                        else
                        {
                            _6181 = _5849;
                        }
                    }
                    nfruFitA[(_4288 * 12u) + 11u] = _5849;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2190)
            {
                float _5951;
                _5951 = 0.0f;
                for (uint _5881 = 0u; _5881 < 11u; )
                {
                    _5951 += nfruFitA[(_5881 * 12u) + _5881];
                    _5881++;
                    continue;
                }
                for (uint _5882 = 0u; _5882 < 11u; )
                {
                    uint _4372 = (_5882 * 12u) + _5882;
                    nfruFitA[_4372] += (9.999999717180685365747194737196e-10f * _5951);
                    _5882++;
                    continue;
                }
                if (_5835 < 3u)
                {
                    uint _5899;
                    _5899 = 2u;
                    for (; _5899 <= 10u; _5899 += 4u)
                    {
                        for (uint _5946 = 0u; _5946 < 12u; )
                        {
                            nfruFitA[(_5899 * 12u) + _5946] = 0.0f;
                            _5946++;
                            continue;
                        }
                        for (uint _5947 = 0u; _5947 < 11u; )
                        {
                            nfruFitA[(_5947 * 12u) + _5899] = 0.0f;
                            _5947++;
                            continue;
                        }
                        nfruFitA[(_5899 * 12u) + _5899] = 1.0f;
                    }
                }
                for (uint _5900 = 0u; _5900 < 11u; _5900++)
                {
                    uint _5365 = _5900 * 12u;
                    uint _5367 = _5365 + _5900;
                    float _5370 = abs(nfruFitA[_5367]);
                    uint _5372 = _5900 + 1u;
                    uint _5931;
                    _5931 = _5900;
                    uint _6258;
                    float _6218;
                    uint _5930 = _5372;
                    float _5944 = _5370;
                    for (; _5930 < 11u; _5944 = _6218, _5931 = _6258, _5930++)
                    {
                        uint _5381 = (_5930 * 12u) + _5900;
                        bool _5386 = abs(nfruFitA[_5381]) > _5944;
                        if (_5386)
                        {
                            _6218 = abs(nfruFitA[_5381]);
                        }
                        else
                        {
                            _6218 = _5944;
                        }
                        _6258 = _5386 ? _5930 : _5931;
                    }
                    if (_5931 != _5900)
                    {
                        for (uint _5933 = 0u; _5933 < 12u; )
                        {
                            uint _5413 = _5365 + _5933;
                            float _5415 = nfruFitA[_5413];
                            uint _5423 = (_5931 * 12u) + _5933;
                            nfruFitA[_5413] = nfruFitA[_5423];
                            nfruFitA[_5423] = _5415;
                            _5933++;
                            continue;
                        }
                    }
                    float _5936;
                    if (abs(nfruFitA[_5367]) > 9.9999996826552253889678874634872e-21f)
                    {
                        _5936 = nfruFitA[_5367];
                    }
                    else
                    {
                        _5936 = 9.9999996826552253889678874634872e-21f;
                    }
                    for (uint _5938 = _5372; _5938 < 11u; _5938++)
                    {
                        uint _5464 = _5938 * 12u;
                        float _5470 = nfruFitA[_5464 + _5900] / _5936;
                        for (uint _5940 = _5900; _5940 < 12u; )
                        {
                            uint _5480 = _5464 + _5940;
                            nfruFitA[_5480] -= (_5470 * nfruFitA[_5365 + _5940]);
                            _5940++;
                            continue;
                        }
                    }
                }
                for (int _5901 = 10; _5901 >= 0; _5901--)
                {
                    uint _5511 = uint(_5901);
                    uint _5512 = _5511 * 12u;
                    uint _5518 = _5511 + 1u;
                    float _5929;
                    _5929 = nfruFitA[_5512 + 11u];
                    for (uint _5927 = _5518; _5927 < 11u; )
                    {
                        _5929 -= (nfruFitA[_5512 + _5927] * nfruFitTheta[_5927]);
                        _5927++;
                        continue;
                    }
                    uint _5546 = _5512 + _5511;
                    nfruFitTheta[_5511] = _5929 / ((abs(nfruFitA[_5546]) > 9.9999996826552253889678874634872e-21f) ? nfruFitA[_5546] : 9.9999996826552253889678874634872e-21f);
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            float _5909;
            if (_5835 == 0u)
            {
                _5909 = 16.0f;
            }
            else
            {
                float _5908;
                if (_5835 == 1u)
                {
                    _5908 = 6.0f;
                }
                else
                {
                    float _5907;
                    if (_5835 == 2u)
                    {
                        _5907 = 3.0f;
                    }
                    else
                    {
                        _5907 = (_5835 == 3u) ? 2.0f : 1.0f;
                    }
                    _5908 = _5907;
                }
                _5909 = _5908;
            }
            for (uint _5910 = 0u; _5910 < 3u; _5910++)
            {
                uint _4461 = (gl_LocalInvocationIndex * 3u) + _5910;
                uint _5567 = _4461 * 3u;
                float _5915;
                if (nfruFitT[_5567] > (-100000000.0f))
                {
                    uint _4471 = _5567 + 1u;
                    uint _4476 = _5567 + 2u;
                    float _4493 = (((nfruFitTheta[8] * nfruFitX[_5567]) + (nfruFitTheta[9] * nfruFitX[_4471])) + (nfruFitTheta[10] * nfruFitX[_4476])) + 1.0f;
                    nfruFitCw[_4461] = _4493;
                    _5915 = length(float2(((((((nfruFitTheta[0] * nfruFitX[_5567]) + (nfruFitTheta[1] * nfruFitX[_4471])) + (nfruFitTheta[2] * nfruFitX[_4476])) + nfruFitTheta[3]) / _4493) - nfruFitT[_5567]) * _2063.x, ((((((nfruFitTheta[4] * nfruFitX[_5567]) + (nfruFitTheta[5] * nfruFitX[_4471])) + (nfruFitTheta[6] * nfruFitX[_4476])) + nfruFitTheta[7]) / _4493) - nfruFitT[_4471]) * _2063.y));
                }
                else
                {
                    _5915 = 1000000000.0f;
                }
                nfruFitRes[_4461] = _5915;
                if (!(nfruFitT[_5567] > (-100000000.0f)))
                {
                    nfruFitW[_4461] = 0.0f;
                }
                else
                {
                    if (_5835 == 2u)
                    {
                        nfruFitW[_4461] = float(_5915 < 4.0f);
                    }
                    else
                    {
                        if (_5835 > 2u)
                        {
                            float _5919;
                            if (_5915 < 8.0f)
                            {
                                float _5918;
                                if (_5915 < _5909)
                                {
                                    _5918 = 1.0f;
                                }
                                else
                                {
                                    _5918 = _5909 / max(_5915, 9.9999999747524270787835121154785e-07f);
                                }
                                _5919 = _5918;
                            }
                            else
                            {
                                _5919 = 0.0f;
                            }
                            nfruFitW[_4461] = _5919;
                        }
                        else
                        {
                            float _5917;
                            if (_5915 < _5909)
                            {
                                _5917 = 1.0f;
                            }
                            else
                            {
                                _5917 = _5909 / max(_5915, 9.9999999747524270787835121154785e-07f);
                            }
                            nfruFitW[_4461] = _5917;
                        }
                    }
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        if (_2282)
        {
            float _5837;
            float _5838;
            float _5839;
            _5839 = 0.0f;
            _5838 = 0.0f;
            _5837 = 0.0f;
            float _6177;
            float _6179;
            float _6180;
            for (uint _5836 = 0u; _5836 < 768u; _5839 = _6180, _5838 = _6179, _5837 = _6177, _5836++)
            {
                if (nfruFitT[_5836 * 3u] > (-100000000.0f))
                {
                    _6179 = _5838 + 1.0f;
                }
                else
                {
                    _6179 = _5838;
                }
                if (nfruFitRes[_5836] < 2.0f)
                {
                    _6180 = _5839 + nfruFitRes[_5836];
                    _6177 = _5837 + 1.0f;
                }
                else
                {
                    _6180 = _5839;
                    _6177 = _5837;
                }
            }
            nfruFitStat[3u] = _5837;
            nfruFitStat[4u] = _5838;
            float _5840;
            if (_5837 > 0.0f)
            {
                _5840 = _5839 / _5837;
            }
            else
            {
                _5840 = 1000000000.0f;
            }
            nfruFitStat[5u] = _5840;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2190)
        {
            float4x4 _2039 = transpose(float4x4(float4(nfruFitThetaF[0], nfruFitThetaF[1], nfruFitThetaF[2] * nfruFitScale, nfruFitThetaF[3]), float4(nfruFitThetaF[4], nfruFitThetaF[5], nfruFitThetaF[6] * nfruFitScale, nfruFitThetaF[7]), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(nfruFitThetaF[8], nfruFitThetaF[9], nfruFitThetaF[10] * nfruFitScale, 1.0f)));
            float4x4 _2044 = transpose(float4x4(float4(nfruFitTheta[0], nfruFitTheta[1], nfruFitTheta[2] * nfruFitScale, nfruFitTheta[3]), float4(nfruFitTheta[4], nfruFitTheta[5], nfruFitTheta[6] * nfruFitScale, nfruFitTheta[7]), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(nfruFitTheta[8], nfruFitTheta[9], nfruFitTheta[10] * nfruFitScale, 1.0f)));
            uint _5772 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
            uint _5841;
            _5841 = 0u;
            for (; _5841 < 4u; _5841++)
            {
                for (uint _5842 = 0u; _5842 < 4u; )
                {
                    uint _2460 = _5841 * 4u;
                    rw_nfru_diagnostics.Store<uint>(((_5772 + _2460) + _5842) * 4 + 0, asuint(_2039[_5841][_5842]));
                    rw_nfru_diagnostics.Store<uint>((((_5772 + 16u) + _2460) + _5842) * 4 + 0, asuint(_2044[_5841][_5842]));
                    _5842++;
                    continue;
                }
            }
            bool _2507 = !any(isnan(_2039[0]));
            bool _2515;
            if (_2507)
            {
                _2515 = !any(isnan(_2039[1]));
            }
            else
            {
                _2515 = _2507;
            }
            bool _2523;
            if (_2515)
            {
                _2523 = !any(isnan(_2039[3]));
            }
            else
            {
                _2523 = _2515;
            }
            bool _2531;
            if (_2523)
            {
                _2531 = !any(isnan(_2044[0]));
            }
            else
            {
                _2531 = _2523;
            }
            bool _2539;
            if (_2531)
            {
                _2539 = !any(isnan(_2044[1]));
            }
            else
            {
                _2539 = _2531;
            }
            bool _2547;
            if (_2539)
            {
                _2547 = !any(isnan(_2044[3]));
            }
            else
            {
                _2547 = _2539;
            }
            bool _2551 = _2547 && (nfruFitStat[1] > 250.0f);
            bool _2558;
            if (_2551)
            {
                _2558 = nfruFitStat[0] > (0.4000000059604644775390625f * nfruFitStat[1]);
            }
            else
            {
                _2558 = _2551;
            }
            bool _2561 = _2558 && (nfruFitStat[2] < 1.0f);
            bool _2568;
            if (_2561)
            {
                _2568 = nfruFitStat[3] > (0.699999988079071044921875f * nfruFitStat[4]);
            }
            else
            {
                _2568 = _2561;
            }
            rw_nfru_diagnostics.Store<uint>((_5772 + 32u) * 4 + 0, uint(_2568 && (nfruFitStat[5] < 1.0f)));
            rw_nfru_diagnostics.Store<uint>((_5772 + 33u) * 4 + 0, asuint(max(nfruFitStat[2], nfruFitStat[5])));
            rw_nfru_diagnostics.Store<uint>((_5772 + 34u) * 4 + 0, uint(nfruFitStat[0]));
            rw_nfru_diagnostics.Store<uint>((_5772 + 35u) * 4 + 0, uint(nfruFitStat[1]));
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
