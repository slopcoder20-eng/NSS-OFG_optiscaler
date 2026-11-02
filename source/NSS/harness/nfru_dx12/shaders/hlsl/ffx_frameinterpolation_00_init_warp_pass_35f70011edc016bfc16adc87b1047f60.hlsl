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
groupshared float nfruFitT[1536];
groupshared float nfruFitR[9];
groupshared float nfruFitTr[3];
groupshared float nfruFitRes[768];
groupshared float nfruFitStat[8];
groupshared float nfruFitW[768];
groupshared float nfruFitRed[256];
groupshared float nfruFitA[42];
groupshared float nfruFitStep[6];

uint2 spvTextureSize(Texture2D<float4> Tex, uint Level, out uint Param)
{
    uint2 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, Param);
    return ret;
}

void comp_main()
{
    int2 _2498 = int2(gl_GlobalInvocationID.xy);
    if (all(bool2(_2498.x < cbFI_MvDepthLaneSize.x, _2498.y < cbFI_MvDepthLaneSize.y)))
    {
        rw_warped_motion_qdata_tp1[_2498] = uint4(0u, 0u, 0u, 0u).x;
        rw_mv_holes_tp1[_2498] = 0.0f.x;
        rw_mv_holes_tm1[_2498] = 0.0f.x;
    }
    if (all(bool2(_2498.x < cbFI_FlowLaneSize.x, _2498.y < cbFI_FlowLaneSize.y)))
    {
        rw_warped_flow_qdata_tm1[_2498] = uint4(0u, 0u, 0u, 0u).x;
    }
    bool _2507 = (cbFI_NfruT2Flags & 524288u) != 0u;
    bool _2515;
    if (_2507)
    {
        _2515 = gl_WorkGroupID.x == 0u;
    }
    else
    {
        _2515 = _2507;
    }
    bool _2521;
    if (_2515)
    {
        _2521 = gl_WorkGroupID.y == 0u;
    }
    else
    {
        _2521 = _2515;
    }
    if (_2521)
    {
        float2 _2712 = float2(cbFI_RenderSize);
        float2 _2713 = _2712 * 0.5f;
        for (uint _16384 = 0u; _16384 < 3u; _16384++)
        {
            uint _2727 = (gl_LocalInvocationIndex * 3u) + _16384;
            float2 _2740 = 0.02999999932944774627685546875f.xx + ((float2(float(_2727 % 32u) + 0.5f, float(_2727 / 32u) + 0.5f) * float2(0.03125f, 0.0416666679084300994873046875f)) * 0.939999997615814208984375f);
            uint _3548_dummy_parameter;
            float2 _3563 = r_motion_tp1.Load(int3(int2(floor(_2740 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3548_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _2745 = _2740 + _3563;
            uint _3575_dummy_parameter;
            float _2752 = cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_2740 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3575_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x);
            bool _2755 = all(bool2(_2745.x > 0.0f.xx.x, _2745.y > 0.0f.xx.y));
            bool _2761;
            if (_2755)
            {
                _2761 = all(bool2(_2745.x < 1.0f.xx.x, _2745.y < 1.0f.xx.y));
            }
            else
            {
                _2761 = _2755;
            }
            bool _2768;
            if (_2761)
            {
                _2768 = !any(isnan(_3563));
            }
            else
            {
                _2768 = _2761;
            }
            bool _2775;
            if (_2768)
            {
                _2775 = !any(isinf(_3563));
            }
            else
            {
                _2775 = _2768;
            }
            bool _2778 = _2775 && (_2752 > 0.0f);
            bool _2784;
            if (_2778)
            {
                _2784 = !isinf(_2752);
            }
            else
            {
                _2784 = _2778;
            }
            bool _2790;
            if (_2784)
            {
                _2790 = !isnan(_2752);
            }
            else
            {
                _2790 = _2784;
            }
            uint _2801 = _2727 * 3u;
            nfruFitX[_2801] = (((2.0f * _2740.x) - 1.0f) * cbFI_DeviceToViewDepth.z) * _2752;
            nfruFitX[_2801 + 1u] = ((1.0f - (2.0f * _2740.y)) * cbFI_DeviceToViewDepth.w) * _2752;
            nfruFitX[_2801 + 2u] = _2790 ? _2752 : (-1.0f);
            uint _2829 = _2727 * 2u;
            nfruFitT[_2829] = (2.0f * _2745.x) - 1.0f;
            nfruFitT[_2829 + 1u] = 1.0f - (2.0f * _2745.y);
            float _17124;
            if (_2790)
            {
                _17124 = length(_3563 * _2712);
            }
            else
            {
                _17124 = -1.0f;
            }
            nfruFitRes[_2727] = _17124;
        }
        if (gl_LocalInvocationIndex < 9u)
        {
            nfruFitR[gl_LocalInvocationIndex] = float(((gl_LocalInvocationIndex == 0u) || (gl_LocalInvocationIndex == 4u)) || (gl_LocalInvocationIndex == 8u));
        }
        if (gl_LocalInvocationIndex < 3u)
        {
            nfruFitTr[gl_LocalInvocationIndex] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _2882 = gl_LocalInvocationIndex == 0u;
        if (_2882)
        {
            float _16386;
            float _16387;
            float _16391;
            _16391 = 0.0f;
            _16387 = 0.0f;
            _16386 = 0.0f;
            float _17131;
            float _17132;
            float _17133;
            for (uint _16385 = 0u; _16385 < 768u; _16391 = _17133, _16387 = _17132, _16386 = _17131, _16385++)
            {
                if (nfruFitRes[_16385] >= 0.0f)
                {
                    _17133 = _16391 + log(nfruFitX[(_16385 * 3u) + 2u]);
                    _17132 = _16387 + nfruFitRes[_16385];
                    _17131 = _16386 + 1.0f;
                }
                else
                {
                    _17133 = _16391;
                    _17132 = _16387;
                    _17131 = _16386;
                }
            }
            bool _2915 = _16386 > 0.0f;
            float _16388;
            if (_2915)
            {
                _16388 = _16387 / _16386;
            }
            else
            {
                _16388 = 0.0f;
            }
            nfruFitStat[4] = _16388;
            float _16392;
            if (_2915)
            {
                _16392 = exp(_16391 / _16386);
            }
            else
            {
                _16392 = 0.0f;
            }
            nfruFitStat[3] = _16392;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        for (uint _16393 = 0u; _16393 < 3u; _16393++)
        {
            uint _2945 = (gl_LocalInvocationIndex * 3u) + _16393;
            bool _2952 = nfruFitRes[_2945] < (0.25f * nfruFitStat[4]);
            bool _2965;
            if (!_2952)
            {
                _2965 = nfruFitX[(_2945 * 3u) + 2u] < (0.20000000298023223876953125f * nfruFitStat[3]);
            }
            else
            {
                _2965 = _2952;
            }
            if (_2965)
            {
                nfruFitX[(_2945 * 3u) + 2u] = -1.0f;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _3594[9];
        for (uint _16394 = 0u; _16394 < 9u; )
        {
            _3594[_16394] = nfruFitR[_16394];
            _16394++;
            continue;
        }
        float _4446 = nfruFitTr[0];
        float _4448 = nfruFitTr[1];
        float _4450 = nfruFitTr[2];
        float3 _4451 = float3(_4446, _4448, _4450);
        float _3689[9] = _3594;
        float _3592[9] = _3689;
        for (uint _16395 = 0u; _16395 < 3u; _16395++)
        {
            uint _3699 = (gl_LocalInvocationIndex * 3u) + _16395;
            uint _4455 = _3699 * 3u;
            uint _4456 = _4455 + 2u;
            float _17119;
            if (nfruFitX[_4456] > 0.0f)
            {
                uint _4474 = _4455 + 1u;
                float3 _4488 = float3(((_3689[0] * nfruFitX[_4455]) + (_3689[1] * nfruFitX[_4474])) + (_3689[2] * nfruFitX[_4456]), ((_3689[3] * nfruFitX[_4455]) + (_3689[4] * nfruFitX[_4474])) + (_3689[5] * nfruFitX[_4456]), ((_3689[6] * nfruFitX[_4455]) + (_3689[7] * nfruFitX[_4474])) + (_3689[8] * nfruFitX[_4456])) + _4451;
                uint _4500 = _3699 * 2u;
                _17119 = length(((_4488.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_4488.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_4500], nfruFitT[_4500 + 1u])) * _2713);
            }
            else
            {
                _17119 = 1000000000.0f;
            }
            nfruFitRes[_3699] = _17119;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            nfruFitStat[2] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _3762 = nfruFitStat[2] > 0.5f;
        float _16398;
        _16398 = 0.0f;
        float _3811;
        for (uint _16397 = 0u; _16397 < 3u; _16398 = _3811, _16397++)
        {
            uint _3771 = (gl_LocalInvocationIndex * 3u) + _16397;
            bool _4590 = nfruFitX[(_3771 * 3u) + 2u] > 0.0f;
            bool _3788;
            if (_4590)
            {
                bool _3785;
                if (_3762)
                {
                    _3785 = nfruFitRes[_3771] >= 64.0f;
                }
                else
                {
                    _3785 = _3762;
                }
                _3788 = !_3785;
            }
            else
            {
                _3788 = _4590;
            }
            float _17104;
            if (_3788)
            {
                float _17103;
                if (nfruFitRes[_3771] < 16.0f)
                {
                    _17103 = 1.0f;
                }
                else
                {
                    _17103 = 16.0f / max(nfruFitRes[_3771], 9.9999999747524270787835121154785e-07f);
                }
                _17104 = _17103;
            }
            else
            {
                _17104 = 0.0f;
            }
            nfruFitW[_3771] = _17104;
            _3811 = _16398 + ((_17104 * nfruFitRes[_3771]) * nfruFitRes[_3771]);
        }
        nfruFitRed[gl_LocalInvocationIndex] = _16398;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _3821 = gl_LocalInvocationIndex < 27u;
        if (_3821)
        {
            bool _3824 = gl_LocalInvocationIndex < 21u;
            uint _16404;
            uint _16407;
            if (_3824)
            {
                uint _16399;
                uint _16401;
                _16401 = 0u;
                _16399 = gl_LocalInvocationIndex;
                for (uint _16400 = 6u; _16399 >= _16400; )
                {
                    uint _3835 = _16399 - _16400;
                    _16401++;
                    _16400--;
                    _16399 = _3835;
                    continue;
                }
                _16407 = _16401 + _16399;
                _16404 = _16401;
            }
            else
            {
                _16407 = 0u;
                _16404 = gl_LocalInvocationIndex - 21u;
            }
            float _16405;
            _16405 = 0.0f;
            float _17138;
            for (uint _16402 = 0u; _16402 < 768u; _16405 = _17138, _16402++)
            {
                if (nfruFitW[_16402] <= 0.0f)
                {
                    _17138 = _16405;
                    continue;
                }
                uint _4601 = _16402 * 3u;
                uint _4606 = _4601 + 1u;
                uint _4611 = _4601 + 2u;
                float3 _4697 = float3(((_3689[0] * nfruFitX[_4601]) + (_3689[1] * nfruFitX[_4606])) + (_3689[2] * nfruFitX[_4611]), ((_3689[3] * nfruFitX[_4601]) + (_3689[4] * nfruFitX[_4606])) + (_3689[5] * nfruFitX[_4611]), ((_3689[6] * nfruFitX[_4601]) + (_3689[7] * nfruFitX[_4606])) + (_3689[8] * nfruFitX[_4611]));
                float3 _4620 = _4697 + _4451;
                float _4626 = max(_4620.z, 9.9999999747524270787835121154785e-07f);
                uint _4632 = _16402 * 2u;
                float _4721 = 1.0f / _4626;
                float3 _4739 = float3(_4721 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_4620.x) * _4721) * _4721) / cbFI_DeviceToViewDepth.z) * _2713.x;
                float3 _4757 = float3(0.0f, _4721 / cbFI_DeviceToViewDepth.w, (((-_4620.y) * _4721) * _4721) / cbFI_DeviceToViewDepth.w) * _2713.y;
                float3 _17094;
                if (_16404 < 3u)
                {
                    _17094 = cross(float3(float(_16404 == 0u), float(_16404 == 1u), float(_16404 == 2u)), _4697);
                }
                else
                {
                    _17094 = float3(float(_16404 == 3u), float(_16404 == 4u), float(_16404 == 5u));
                }
                float2 _4792 = float2(dot(_4739, _17094), dot(_4757, _17094));
                float _17139;
                if (_3824)
                {
                    float3 _17097;
                    if (_16407 < 3u)
                    {
                        _17097 = cross(float3(float(_16407 == 0u), float(_16407 == 1u), float(_16407 == 2u)), _4697);
                    }
                    else
                    {
                        _17097 = float3(float(_16407 == 3u), float(_16407 == 4u), float(_16407 == 5u));
                    }
                    _17139 = _16405 + (nfruFitW[_16402] * dot(_4792, float2(dot(_4739, _17097), dot(_4757, _17097))));
                }
                else
                {
                    _17139 = _16405 + (nfruFitW[_16402] * dot(_4792, ((_4620.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _4626)) - float2(nfruFitT[_4632], nfruFitT[_4632 + 1u])) * _2713));
                }
                _17138 = _17139;
            }
            if (_3824)
            {
                nfruFitA[(_16404 * 7u) + _16407] = _16405;
                nfruFitA[(_16407 * 7u) + _16404] = _16405;
            }
            else
            {
                nfruFitA[(_16404 * 7u) + 6u] = _16405;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16409;
            _16409 = 0.0f;
            for (uint _16408 = 0u; _16408 < 256u; )
            {
                _16409 += nfruFitRed[_16408];
                _16408++;
                continue;
            }
            nfruFitStat[0] = _16409;
            float _17093;
            _17093 = 0.0f;
            for (uint _16410 = 0u; _16410 < 6u; )
            {
                _17093 += nfruFitA[(_16410 * 7u) + _16410];
                _16410++;
                continue;
            }
            for (uint _16411 = 0u; _16411 < 6u; )
            {
                uint _3968 = (_16411 * 7u) + _16411;
                nfruFitA[_3968] += ((9.999999717180685365747194737196e-10f * _17093) + 1.0000000031710768509710513471353e-30f);
                _16411++;
                continue;
            }
            uint _16412;
            _16412 = 3u;
            for (; _16412 < 6u; _16412++)
            {
                for (uint _17088 = 0u; _17088 < 7u; )
                {
                    nfruFitA[(_16412 * 7u) + _17088] = 0.0f;
                    _17088++;
                    continue;
                }
                for (uint _17089 = 0u; _17089 < 6u; )
                {
                    nfruFitA[(_17089 * 7u) + _16412] = 0.0f;
                    _17089++;
                    continue;
                }
                nfruFitA[(_16412 * 7u) + _16412] = 1.0f;
            }
            for (uint _16413 = 0u; _16413 < 6u; _16413++)
            {
                uint _4033 = _16413 * 7u;
                uint _4035 = _4033 + _16413;
                float _4038 = abs(nfruFitA[_4035]);
                uint _4040 = _16413 + 1u;
                uint _17073;
                _17073 = _16413;
                uint _17330;
                float _17325;
                uint _17072 = _4040;
                float _17086 = _4038;
                for (; _17072 < 6u; _17086 = _17325, _17073 = _17330, _17072++)
                {
                    uint _4049 = (_17072 * 7u) + _16413;
                    bool _4054 = abs(nfruFitA[_4049]) > _17086;
                    if (_4054)
                    {
                        _17325 = abs(nfruFitA[_4049]);
                    }
                    else
                    {
                        _17325 = _17086;
                    }
                    _17330 = _4054 ? _17072 : _17073;
                }
                if (_17073 != _16413)
                {
                    for (uint _17075 = 0u; _17075 < 7u; )
                    {
                        uint _4081 = _4033 + _17075;
                        float _4083 = nfruFitA[_4081];
                        uint _4091 = (_17073 * 7u) + _17075;
                        nfruFitA[_4081] = nfruFitA[_4091];
                        nfruFitA[_4091] = _4083;
                        _17075++;
                        continue;
                    }
                }
                float _17078;
                if (abs(nfruFitA[_4035]) > 1.0000000031710768509710513471353e-30f)
                {
                    _17078 = nfruFitA[_4035];
                }
                else
                {
                    _17078 = 1.0000000031710768509710513471353e-30f;
                }
                for (uint _17080 = _4040; _17080 < 6u; _17080++)
                {
                    uint _4132 = _17080 * 7u;
                    float _4138 = nfruFitA[_4132 + _16413] / _17078;
                    for (uint _17082 = _16413; _17082 < 7u; )
                    {
                        uint _4148 = _4132 + _17082;
                        nfruFitA[_4148] -= (_4138 * nfruFitA[_4033 + _17082]);
                        _17082++;
                        continue;
                    }
                }
            }
            for (int _16414 = 5; _16414 >= 0; _16414--)
            {
                uint _4179 = uint(_16414);
                uint _4180 = _4179 * 7u;
                uint _4186 = _4179 + 1u;
                float _17071;
                _17071 = nfruFitA[_4180 + 6u];
                for (uint _17069 = _4186; _17069 < 6u; )
                {
                    _17071 -= (nfruFitA[_4180 + _17069] * nfruFitStep[_17069]);
                    _17069++;
                    continue;
                }
                uint _4214 = _4180 + _4179;
                nfruFitStep[_4179] = _17071 / ((abs(nfruFitA[_4214]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_4214] : 1.0000000031710768509710513471353e-30f);
            }
            nfruFitStep[3] = 0.0f;
            nfruFitStep[4] = 0.0f;
            nfruFitStep[5] = 0.0f;
            nfruFitStat[1] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _3672[9];
        for (uint _16415 = 0u; _16415 < 5u; _16415++)
        {
            uint _4247 = 1u << _16415;
            float _4248 = float(_4247);
            float3 _4259 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _4248);
            float _4904 = length(_4259);
            float3 _17050;
            if (_4904 > 9.9999999600419720025001879548654e-13f)
            {
                _17050 = _4259 / _4904.xxx;
            }
            else
            {
                _17050 = float3(1.0f, 0.0f, 0.0f);
            }
            float _4916 = sin(_4904);
            float _4919 = 1.0f - cos(_4904);
            float _4931 = -_4916;
            float _4938 = _4919 * _17050.x;
            float _4941 = _4938 * _17050.y;
            float _4954 = _4938 * _17050.z;
            float _4991 = (_4919 * _17050.y) * _17050.z;
            float _15746[9] = { 1.0f + (_4919 * ((_17050.x * _17050.x) - 1.0f)), (_4931 * _17050.z) + _4941, (_4916 * _17050.y) + _4954, (_4916 * _17050.z) + _4941, 1.0f + (_4919 * ((_17050.y * _17050.y) - 1.0f)), (_4931 * _17050.x) + _4991, (_4931 * _17050.y) + _4954, (_4916 * _17050.x) + _4991, 1.0f + (_4919 * ((_17050.z * _17050.z) - 1.0f)) };
            float _3667[9] = _15746;
            uint _17051;
            _17051 = 0u;
            for (; _17051 < 3u; _17051++)
            {
                for (uint _17067 = 0u; _17067 < 3u; )
                {
                    uint _4273 = _17051 * 3u;
                    _3672[_4273 + _17067] = ((_3667[_4273] * _3592[_17067]) + (_3667[_4273 + 1u] * _3592[3u + _17067])) + (_3667[_4273 + 2u] * _3592[6u + _17067]);
                    _17067++;
                    continue;
                }
            }
            float _4318 = nfruFitStep[3];
            float _4320 = nfruFitStep[4];
            float _4322 = nfruFitStep[5];
            float3 _4325 = _4451 - (float3(_4318, _4320, _4322) * (1.0f / _4248));
            float _17053;
            _17053 = 0.0f;
            float _17320;
            for (uint _17052 = 0u; _17052 < 3u; _17053 = _17320, _17052++)
            {
                uint _4334 = (gl_LocalInvocationIndex * 3u) + _17052;
                if (nfruFitW[_4334] > 0.0f)
                {
                    uint _5040 = _4334 * 3u;
                    uint _5045 = _5040 + 1u;
                    uint _5050 = _5040 + 2u;
                    float3 _5059 = float3(((_3672[0] * nfruFitX[_5040]) + (_3672[1] * nfruFitX[_5045])) + (_3672[2] * nfruFitX[_5050]), ((_3672[3] * nfruFitX[_5040]) + (_3672[4] * nfruFitX[_5045])) + (_3672[5] * nfruFitX[_5050]), ((_3672[6] * nfruFitX[_5040]) + (_3672[7] * nfruFitX[_5045])) + (_3672[8] * nfruFitX[_5050])) + _4325;
                    uint _5071 = _4334 * 2u;
                    float2 _5082 = ((_5059.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_5059.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_5071], nfruFitT[_5071 + 1u])) * _2713;
                    _17320 = _17053 + (nfruFitW[_4334] * dot(_5082, _5082));
                }
                else
                {
                    _17320 = _17053;
                }
            }
            nfruFitRed[gl_LocalInvocationIndex] = _17053;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _4371;
            if (_2882)
            {
                _4371 = nfruFitStat[1] < 0.5f;
            }
            else
            {
                _4371 = _2882;
            }
            if (_4371)
            {
                float _17055;
                _17055 = 0.0f;
                for (uint _17054 = 0u; _17054 < 256u; )
                {
                    _17055 += nfruFitRed[_17054];
                    _17054++;
                    continue;
                }
                bool _4390 = _17055 < nfruFitStat[0];
                bool _4396;
                if (_4390)
                {
                    _4396 = !isnan(_17055);
                }
                else
                {
                    _4396 = _4390;
                }
                if (_4396)
                {
                    for (uint _17056 = 0u; _17056 < 9u; )
                    {
                        nfruFitR[_17056] = _3672[_17056];
                        _17056++;
                        continue;
                    }
                    nfruFitTr[0] = _4325.x;
                    nfruFitTr[1] = _4325.y;
                    nfruFitTr[2] = _4325.z;
                    nfruFitStat[1] = 1.0f;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _5148[9];
        for (uint _16416 = 0u; _16416 < 9u; )
        {
            _5148[_16416] = nfruFitR[_16416];
            _16416++;
            continue;
        }
        float _6000 = nfruFitTr[0];
        float _6002 = nfruFitTr[1];
        float _6004 = nfruFitTr[2];
        float3 _6005 = float3(_6000, _6002, _6004);
        float _5243[9] = _5148;
        float _5146[9] = _5243;
        for (uint _16417 = 0u; _16417 < 3u; _16417++)
        {
            uint _5253 = (gl_LocalInvocationIndex * 3u) + _16417;
            uint _6009 = _5253 * 3u;
            uint _6010 = _6009 + 2u;
            float _17048;
            if (nfruFitX[_6010] > 0.0f)
            {
                uint _6028 = _6009 + 1u;
                float3 _6042 = float3(((_5243[0] * nfruFitX[_6009]) + (_5243[1] * nfruFitX[_6028])) + (_5243[2] * nfruFitX[_6010]), ((_5243[3] * nfruFitX[_6009]) + (_5243[4] * nfruFitX[_6028])) + (_5243[5] * nfruFitX[_6010]), ((_5243[6] * nfruFitX[_6009]) + (_5243[7] * nfruFitX[_6028])) + (_5243[8] * nfruFitX[_6010])) + _6005;
                uint _6054 = _5253 * 2u;
                _17048 = length(((_6042.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_6042.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_6054], nfruFitT[_6054 + 1u])) * _2713);
            }
            else
            {
                _17048 = 1000000000.0f;
            }
            nfruFitRes[_5253] = _17048;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            nfruFitStat[2] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _5316 = nfruFitStat[2] > 0.5f;
        float _16420;
        _16420 = 0.0f;
        float _5365;
        for (uint _16419 = 0u; _16419 < 3u; _16420 = _5365, _16419++)
        {
            uint _5325 = (gl_LocalInvocationIndex * 3u) + _16419;
            bool _6144 = nfruFitX[(_5325 * 3u) + 2u] > 0.0f;
            bool _5342;
            if (_6144)
            {
                bool _5339;
                if (_5316)
                {
                    _5339 = nfruFitRes[_5325] >= 24.0f;
                }
                else
                {
                    _5339 = _5316;
                }
                _5342 = !_5339;
            }
            else
            {
                _5342 = _6144;
            }
            float _17033;
            if (_5342)
            {
                float _17032;
                if (nfruFitRes[_5325] < 6.0f)
                {
                    _17032 = 1.0f;
                }
                else
                {
                    _17032 = 6.0f / max(nfruFitRes[_5325], 9.9999999747524270787835121154785e-07f);
                }
                _17033 = _17032;
            }
            else
            {
                _17033 = 0.0f;
            }
            nfruFitW[_5325] = _17033;
            _5365 = _16420 + ((_17033 * nfruFitRes[_5325]) * nfruFitRes[_5325]);
        }
        nfruFitRed[gl_LocalInvocationIndex] = _16420;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_3821)
        {
            bool _5378 = gl_LocalInvocationIndex < 21u;
            uint _16426;
            uint _16429;
            if (_5378)
            {
                uint _16421;
                uint _16423;
                _16423 = 0u;
                _16421 = gl_LocalInvocationIndex;
                for (uint _16422 = 6u; _16421 >= _16422; )
                {
                    uint _5389 = _16421 - _16422;
                    _16423++;
                    _16422--;
                    _16421 = _5389;
                    continue;
                }
                _16429 = _16423 + _16421;
                _16426 = _16423;
            }
            else
            {
                _16429 = 0u;
                _16426 = gl_LocalInvocationIndex - 21u;
            }
            float _16427;
            _16427 = 0.0f;
            float _17147;
            for (uint _16424 = 0u; _16424 < 768u; _16427 = _17147, _16424++)
            {
                if (nfruFitW[_16424] <= 0.0f)
                {
                    _17147 = _16427;
                    continue;
                }
                uint _6155 = _16424 * 3u;
                uint _6160 = _6155 + 1u;
                uint _6165 = _6155 + 2u;
                float3 _6251 = float3(((_5243[0] * nfruFitX[_6155]) + (_5243[1] * nfruFitX[_6160])) + (_5243[2] * nfruFitX[_6165]), ((_5243[3] * nfruFitX[_6155]) + (_5243[4] * nfruFitX[_6160])) + (_5243[5] * nfruFitX[_6165]), ((_5243[6] * nfruFitX[_6155]) + (_5243[7] * nfruFitX[_6160])) + (_5243[8] * nfruFitX[_6165]));
                float3 _6174 = _6251 + _6005;
                float _6180 = max(_6174.z, 9.9999999747524270787835121154785e-07f);
                uint _6186 = _16424 * 2u;
                float _6275 = 1.0f / _6180;
                float3 _6293 = float3(_6275 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_6174.x) * _6275) * _6275) / cbFI_DeviceToViewDepth.z) * _2713.x;
                float3 _6311 = float3(0.0f, _6275 / cbFI_DeviceToViewDepth.w, (((-_6174.y) * _6275) * _6275) / cbFI_DeviceToViewDepth.w) * _2713.y;
                float3 _17023;
                if (_16426 < 3u)
                {
                    _17023 = cross(float3(float(_16426 == 0u), float(_16426 == 1u), float(_16426 == 2u)), _6251);
                }
                else
                {
                    _17023 = float3(float(_16426 == 3u), float(_16426 == 4u), float(_16426 == 5u));
                }
                float2 _6346 = float2(dot(_6293, _17023), dot(_6311, _17023));
                float _17148;
                if (_5378)
                {
                    float3 _17026;
                    if (_16429 < 3u)
                    {
                        _17026 = cross(float3(float(_16429 == 0u), float(_16429 == 1u), float(_16429 == 2u)), _6251);
                    }
                    else
                    {
                        _17026 = float3(float(_16429 == 3u), float(_16429 == 4u), float(_16429 == 5u));
                    }
                    _17148 = _16427 + (nfruFitW[_16424] * dot(_6346, float2(dot(_6293, _17026), dot(_6311, _17026))));
                }
                else
                {
                    _17148 = _16427 + (nfruFitW[_16424] * dot(_6346, ((_6174.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _6180)) - float2(nfruFitT[_6186], nfruFitT[_6186 + 1u])) * _2713));
                }
                _17147 = _17148;
            }
            if (_5378)
            {
                nfruFitA[(_16426 * 7u) + _16429] = _16427;
                nfruFitA[(_16429 * 7u) + _16426] = _16427;
            }
            else
            {
                nfruFitA[(_16426 * 7u) + 6u] = _16427;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16431;
            _16431 = 0.0f;
            for (uint _16430 = 0u; _16430 < 256u; )
            {
                _16431 += nfruFitRed[_16430];
                _16430++;
                continue;
            }
            nfruFitStat[0] = _16431;
            float _17022;
            _17022 = 0.0f;
            for (uint _16432 = 0u; _16432 < 6u; )
            {
                _17022 += nfruFitA[(_16432 * 7u) + _16432];
                _16432++;
                continue;
            }
            for (uint _16433 = 0u; _16433 < 6u; )
            {
                uint _5522 = (_16433 * 7u) + _16433;
                nfruFitA[_5522] += ((9.999999717180685365747194737196e-10f * _17022) + 1.0000000031710768509710513471353e-30f);
                _16433++;
                continue;
            }
            uint _16434;
            _16434 = 3u;
            for (; _16434 < 6u; _16434++)
            {
                for (uint _17017 = 0u; _17017 < 7u; )
                {
                    nfruFitA[(_16434 * 7u) + _17017] = 0.0f;
                    _17017++;
                    continue;
                }
                for (uint _17018 = 0u; _17018 < 6u; )
                {
                    nfruFitA[(_17018 * 7u) + _16434] = 0.0f;
                    _17018++;
                    continue;
                }
                nfruFitA[(_16434 * 7u) + _16434] = 1.0f;
            }
            for (uint _16435 = 0u; _16435 < 6u; _16435++)
            {
                uint _5587 = _16435 * 7u;
                uint _5589 = _5587 + _16435;
                float _5592 = abs(nfruFitA[_5589]);
                uint _5594 = _16435 + 1u;
                uint _17002;
                _17002 = _16435;
                uint _17331;
                float _17315;
                uint _17001 = _5594;
                float _17015 = _5592;
                for (; _17001 < 6u; _17015 = _17315, _17002 = _17331, _17001++)
                {
                    uint _5603 = (_17001 * 7u) + _16435;
                    bool _5608 = abs(nfruFitA[_5603]) > _17015;
                    if (_5608)
                    {
                        _17315 = abs(nfruFitA[_5603]);
                    }
                    else
                    {
                        _17315 = _17015;
                    }
                    _17331 = _5608 ? _17001 : _17002;
                }
                if (_17002 != _16435)
                {
                    for (uint _17004 = 0u; _17004 < 7u; )
                    {
                        uint _5635 = _5587 + _17004;
                        float _5637 = nfruFitA[_5635];
                        uint _5645 = (_17002 * 7u) + _17004;
                        nfruFitA[_5635] = nfruFitA[_5645];
                        nfruFitA[_5645] = _5637;
                        _17004++;
                        continue;
                    }
                }
                float _17007;
                if (abs(nfruFitA[_5589]) > 1.0000000031710768509710513471353e-30f)
                {
                    _17007 = nfruFitA[_5589];
                }
                else
                {
                    _17007 = 1.0000000031710768509710513471353e-30f;
                }
                for (uint _17009 = _5594; _17009 < 6u; _17009++)
                {
                    uint _5686 = _17009 * 7u;
                    float _5692 = nfruFitA[_5686 + _16435] / _17007;
                    for (uint _17011 = _16435; _17011 < 7u; )
                    {
                        uint _5702 = _5686 + _17011;
                        nfruFitA[_5702] -= (_5692 * nfruFitA[_5587 + _17011]);
                        _17011++;
                        continue;
                    }
                }
            }
            for (int _16436 = 5; _16436 >= 0; _16436--)
            {
                uint _5733 = uint(_16436);
                uint _5734 = _5733 * 7u;
                uint _5740 = _5733 + 1u;
                float _17000;
                _17000 = nfruFitA[_5734 + 6u];
                for (uint _16998 = _5740; _16998 < 6u; )
                {
                    _17000 -= (nfruFitA[_5734 + _16998] * nfruFitStep[_16998]);
                    _16998++;
                    continue;
                }
                uint _5768 = _5734 + _5733;
                nfruFitStep[_5733] = _17000 / ((abs(nfruFitA[_5768]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_5768] : 1.0000000031710768509710513471353e-30f);
            }
            nfruFitStep[3] = 0.0f;
            nfruFitStep[4] = 0.0f;
            nfruFitStep[5] = 0.0f;
            nfruFitStat[1] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _5226[9];
        for (uint _16437 = 0u; _16437 < 5u; _16437++)
        {
            uint _5801 = 1u << _16437;
            float _5802 = float(_5801);
            float3 _5813 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _5802);
            float _6458 = length(_5813);
            float3 _16979;
            if (_6458 > 9.9999999600419720025001879548654e-13f)
            {
                _16979 = _5813 / _6458.xxx;
            }
            else
            {
                _16979 = float3(1.0f, 0.0f, 0.0f);
            }
            float _6470 = sin(_6458);
            float _6473 = 1.0f - cos(_6458);
            float _6485 = -_6470;
            float _6492 = _6473 * _16979.x;
            float _6495 = _6492 * _16979.y;
            float _6508 = _6492 * _16979.z;
            float _6545 = (_6473 * _16979.y) * _16979.z;
            float _15589[9] = { 1.0f + (_6473 * ((_16979.x * _16979.x) - 1.0f)), (_6485 * _16979.z) + _6495, (_6470 * _16979.y) + _6508, (_6470 * _16979.z) + _6495, 1.0f + (_6473 * ((_16979.y * _16979.y) - 1.0f)), (_6485 * _16979.x) + _6545, (_6485 * _16979.y) + _6508, (_6470 * _16979.x) + _6545, 1.0f + (_6473 * ((_16979.z * _16979.z) - 1.0f)) };
            float _5221[9] = _15589;
            uint _16980;
            _16980 = 0u;
            for (; _16980 < 3u; _16980++)
            {
                for (uint _16996 = 0u; _16996 < 3u; )
                {
                    uint _5827 = _16980 * 3u;
                    _5226[_5827 + _16996] = ((_5221[_5827] * _5146[_16996]) + (_5221[_5827 + 1u] * _5146[3u + _16996])) + (_5221[_5827 + 2u] * _5146[6u + _16996]);
                    _16996++;
                    continue;
                }
            }
            float _5872 = nfruFitStep[3];
            float _5874 = nfruFitStep[4];
            float _5876 = nfruFitStep[5];
            float3 _5879 = _6005 - (float3(_5872, _5874, _5876) * (1.0f / _5802));
            float _16982;
            _16982 = 0.0f;
            float _17310;
            for (uint _16981 = 0u; _16981 < 3u; _16982 = _17310, _16981++)
            {
                uint _5888 = (gl_LocalInvocationIndex * 3u) + _16981;
                if (nfruFitW[_5888] > 0.0f)
                {
                    uint _6594 = _5888 * 3u;
                    uint _6599 = _6594 + 1u;
                    uint _6604 = _6594 + 2u;
                    float3 _6613 = float3(((_5226[0] * nfruFitX[_6594]) + (_5226[1] * nfruFitX[_6599])) + (_5226[2] * nfruFitX[_6604]), ((_5226[3] * nfruFitX[_6594]) + (_5226[4] * nfruFitX[_6599])) + (_5226[5] * nfruFitX[_6604]), ((_5226[6] * nfruFitX[_6594]) + (_5226[7] * nfruFitX[_6599])) + (_5226[8] * nfruFitX[_6604])) + _5879;
                    uint _6625 = _5888 * 2u;
                    float2 _6636 = ((_6613.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_6613.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_6625], nfruFitT[_6625 + 1u])) * _2713;
                    _17310 = _16982 + (nfruFitW[_5888] * dot(_6636, _6636));
                }
                else
                {
                    _17310 = _16982;
                }
            }
            nfruFitRed[gl_LocalInvocationIndex] = _16982;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _5925;
            if (_2882)
            {
                _5925 = nfruFitStat[1] < 0.5f;
            }
            else
            {
                _5925 = _2882;
            }
            if (_5925)
            {
                float _16984;
                _16984 = 0.0f;
                for (uint _16983 = 0u; _16983 < 256u; )
                {
                    _16984 += nfruFitRed[_16983];
                    _16983++;
                    continue;
                }
                bool _5944 = _16984 < nfruFitStat[0];
                bool _5950;
                if (_5944)
                {
                    _5950 = !isnan(_16984);
                }
                else
                {
                    _5950 = _5944;
                }
                if (_5950)
                {
                    for (uint _16985 = 0u; _16985 < 9u; )
                    {
                        nfruFitR[_16985] = _5226[_16985];
                        _16985++;
                        continue;
                    }
                    nfruFitTr[0] = _5879.x;
                    nfruFitTr[1] = _5879.y;
                    nfruFitTr[2] = _5879.z;
                    nfruFitStat[1] = 1.0f;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _6702[9];
        for (uint _16438 = 0u; _16438 < 9u; )
        {
            _6702[_16438] = nfruFitR[_16438];
            _16438++;
            continue;
        }
        float _7554 = nfruFitTr[0];
        float _7556 = nfruFitTr[1];
        float _7558 = nfruFitTr[2];
        float3 _7559 = float3(_7554, _7556, _7558);
        float _6797[9] = _6702;
        float _6700[9] = _6797;
        for (uint _16439 = 0u; _16439 < 3u; _16439++)
        {
            uint _6807 = (gl_LocalInvocationIndex * 3u) + _16439;
            uint _7563 = _6807 * 3u;
            uint _7564 = _7563 + 2u;
            float _16977;
            if (nfruFitX[_7564] > 0.0f)
            {
                uint _7582 = _7563 + 1u;
                float3 _7596 = float3(((_6797[0] * nfruFitX[_7563]) + (_6797[1] * nfruFitX[_7582])) + (_6797[2] * nfruFitX[_7564]), ((_6797[3] * nfruFitX[_7563]) + (_6797[4] * nfruFitX[_7582])) + (_6797[5] * nfruFitX[_7564]), ((_6797[6] * nfruFitX[_7563]) + (_6797[7] * nfruFitX[_7582])) + (_6797[8] * nfruFitX[_7564])) + _7559;
                uint _7608 = _6807 * 2u;
                _16977 = length(((_7596.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_7596.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_7608], nfruFitT[_7608 + 1u])) * _2713);
            }
            else
            {
                _16977 = 1000000000.0f;
            }
            nfruFitRes[_6807] = _16977;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            nfruFitStat[2] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _6870 = nfruFitStat[2] > 0.5f;
        float _16442;
        _16442 = 0.0f;
        float _6919;
        for (uint _16441 = 0u; _16441 < 3u; _16442 = _6919, _16441++)
        {
            uint _6879 = (gl_LocalInvocationIndex * 3u) + _16441;
            bool _7698 = nfruFitX[(_6879 * 3u) + 2u] > 0.0f;
            bool _6896;
            if (_7698)
            {
                bool _6893;
                if (_6870)
                {
                    _6893 = nfruFitRes[_6879] >= 12.0f;
                }
                else
                {
                    _6893 = _6870;
                }
                _6896 = !_6893;
            }
            else
            {
                _6896 = _7698;
            }
            float _16962;
            if (_6896)
            {
                float _16961;
                if (nfruFitRes[_6879] < 3.0f)
                {
                    _16961 = 1.0f;
                }
                else
                {
                    _16961 = 3.0f / max(nfruFitRes[_6879], 9.9999999747524270787835121154785e-07f);
                }
                _16962 = _16961;
            }
            else
            {
                _16962 = 0.0f;
            }
            nfruFitW[_6879] = _16962;
            _6919 = _16442 + ((_16962 * nfruFitRes[_6879]) * nfruFitRes[_6879]);
        }
        nfruFitRed[gl_LocalInvocationIndex] = _16442;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_3821)
        {
            bool _6932 = gl_LocalInvocationIndex < 21u;
            uint _16448;
            uint _16451;
            if (_6932)
            {
                uint _16443;
                uint _16445;
                _16445 = 0u;
                _16443 = gl_LocalInvocationIndex;
                for (uint _16444 = 6u; _16443 >= _16444; )
                {
                    uint _6943 = _16443 - _16444;
                    _16445++;
                    _16444--;
                    _16443 = _6943;
                    continue;
                }
                _16451 = _16445 + _16443;
                _16448 = _16445;
            }
            else
            {
                _16451 = 0u;
                _16448 = gl_LocalInvocationIndex - 21u;
            }
            float _16449;
            _16449 = 0.0f;
            float _17156;
            for (uint _16446 = 0u; _16446 < 768u; _16449 = _17156, _16446++)
            {
                if (nfruFitW[_16446] <= 0.0f)
                {
                    _17156 = _16449;
                    continue;
                }
                uint _7709 = _16446 * 3u;
                uint _7714 = _7709 + 1u;
                uint _7719 = _7709 + 2u;
                float3 _7805 = float3(((_6797[0] * nfruFitX[_7709]) + (_6797[1] * nfruFitX[_7714])) + (_6797[2] * nfruFitX[_7719]), ((_6797[3] * nfruFitX[_7709]) + (_6797[4] * nfruFitX[_7714])) + (_6797[5] * nfruFitX[_7719]), ((_6797[6] * nfruFitX[_7709]) + (_6797[7] * nfruFitX[_7714])) + (_6797[8] * nfruFitX[_7719]));
                float3 _7728 = _7805 + _7559;
                float _7734 = max(_7728.z, 9.9999999747524270787835121154785e-07f);
                uint _7740 = _16446 * 2u;
                float _7829 = 1.0f / _7734;
                float3 _7847 = float3(_7829 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_7728.x) * _7829) * _7829) / cbFI_DeviceToViewDepth.z) * _2713.x;
                float3 _7865 = float3(0.0f, _7829 / cbFI_DeviceToViewDepth.w, (((-_7728.y) * _7829) * _7829) / cbFI_DeviceToViewDepth.w) * _2713.y;
                float3 _16952;
                if (_16448 < 3u)
                {
                    _16952 = cross(float3(float(_16448 == 0u), float(_16448 == 1u), float(_16448 == 2u)), _7805);
                }
                else
                {
                    _16952 = float3(float(_16448 == 3u), float(_16448 == 4u), float(_16448 == 5u));
                }
                float2 _7900 = float2(dot(_7847, _16952), dot(_7865, _16952));
                float _17157;
                if (_6932)
                {
                    float3 _16955;
                    if (_16451 < 3u)
                    {
                        _16955 = cross(float3(float(_16451 == 0u), float(_16451 == 1u), float(_16451 == 2u)), _7805);
                    }
                    else
                    {
                        _16955 = float3(float(_16451 == 3u), float(_16451 == 4u), float(_16451 == 5u));
                    }
                    _17157 = _16449 + (nfruFitW[_16446] * dot(_7900, float2(dot(_7847, _16955), dot(_7865, _16955))));
                }
                else
                {
                    _17157 = _16449 + (nfruFitW[_16446] * dot(_7900, ((_7728.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _7734)) - float2(nfruFitT[_7740], nfruFitT[_7740 + 1u])) * _2713));
                }
                _17156 = _17157;
            }
            if (_6932)
            {
                nfruFitA[(_16448 * 7u) + _16451] = _16449;
                nfruFitA[(_16451 * 7u) + _16448] = _16449;
            }
            else
            {
                nfruFitA[(_16448 * 7u) + 6u] = _16449;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16453;
            _16453 = 0.0f;
            for (uint _16452 = 0u; _16452 < 256u; )
            {
                _16453 += nfruFitRed[_16452];
                _16452++;
                continue;
            }
            nfruFitStat[0] = _16453;
            float _16951;
            _16951 = 0.0f;
            for (uint _16454 = 0u; _16454 < 6u; )
            {
                _16951 += nfruFitA[(_16454 * 7u) + _16454];
                _16454++;
                continue;
            }
            for (uint _16455 = 0u; _16455 < 6u; )
            {
                uint _7076 = (_16455 * 7u) + _16455;
                nfruFitA[_7076] += ((9.999999717180685365747194737196e-10f * _16951) + 1.0000000031710768509710513471353e-30f);
                _16455++;
                continue;
            }
            uint _16456;
            _16456 = 3u;
            for (; _16456 < 6u; _16456++)
            {
                for (uint _16946 = 0u; _16946 < 7u; )
                {
                    nfruFitA[(_16456 * 7u) + _16946] = 0.0f;
                    _16946++;
                    continue;
                }
                for (uint _16947 = 0u; _16947 < 6u; )
                {
                    nfruFitA[(_16947 * 7u) + _16456] = 0.0f;
                    _16947++;
                    continue;
                }
                nfruFitA[(_16456 * 7u) + _16456] = 1.0f;
            }
            for (uint _16457 = 0u; _16457 < 6u; _16457++)
            {
                uint _7141 = _16457 * 7u;
                uint _7143 = _7141 + _16457;
                float _7146 = abs(nfruFitA[_7143]);
                uint _7148 = _16457 + 1u;
                uint _16931;
                _16931 = _16457;
                uint _17332;
                float _17305;
                uint _16930 = _7148;
                float _16944 = _7146;
                for (; _16930 < 6u; _16944 = _17305, _16931 = _17332, _16930++)
                {
                    uint _7157 = (_16930 * 7u) + _16457;
                    bool _7162 = abs(nfruFitA[_7157]) > _16944;
                    if (_7162)
                    {
                        _17305 = abs(nfruFitA[_7157]);
                    }
                    else
                    {
                        _17305 = _16944;
                    }
                    _17332 = _7162 ? _16930 : _16931;
                }
                if (_16931 != _16457)
                {
                    for (uint _16933 = 0u; _16933 < 7u; )
                    {
                        uint _7189 = _7141 + _16933;
                        float _7191 = nfruFitA[_7189];
                        uint _7199 = (_16931 * 7u) + _16933;
                        nfruFitA[_7189] = nfruFitA[_7199];
                        nfruFitA[_7199] = _7191;
                        _16933++;
                        continue;
                    }
                }
                float _16936;
                if (abs(nfruFitA[_7143]) > 1.0000000031710768509710513471353e-30f)
                {
                    _16936 = nfruFitA[_7143];
                }
                else
                {
                    _16936 = 1.0000000031710768509710513471353e-30f;
                }
                for (uint _16938 = _7148; _16938 < 6u; _16938++)
                {
                    uint _7240 = _16938 * 7u;
                    float _7246 = nfruFitA[_7240 + _16457] / _16936;
                    for (uint _16940 = _16457; _16940 < 7u; )
                    {
                        uint _7256 = _7240 + _16940;
                        nfruFitA[_7256] -= (_7246 * nfruFitA[_7141 + _16940]);
                        _16940++;
                        continue;
                    }
                }
            }
            for (int _16458 = 5; _16458 >= 0; _16458--)
            {
                uint _7287 = uint(_16458);
                uint _7288 = _7287 * 7u;
                uint _7294 = _7287 + 1u;
                float _16929;
                _16929 = nfruFitA[_7288 + 6u];
                for (uint _16927 = _7294; _16927 < 6u; )
                {
                    _16929 -= (nfruFitA[_7288 + _16927] * nfruFitStep[_16927]);
                    _16927++;
                    continue;
                }
                uint _7322 = _7288 + _7287;
                nfruFitStep[_7287] = _16929 / ((abs(nfruFitA[_7322]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_7322] : 1.0000000031710768509710513471353e-30f);
            }
            nfruFitStep[3] = 0.0f;
            nfruFitStep[4] = 0.0f;
            nfruFitStep[5] = 0.0f;
            nfruFitStat[1] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _6780[9];
        for (uint _16459 = 0u; _16459 < 5u; _16459++)
        {
            uint _7355 = 1u << _16459;
            float _7356 = float(_7355);
            float3 _7367 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _7356);
            float _8012 = length(_7367);
            float3 _16908;
            if (_8012 > 9.9999999600419720025001879548654e-13f)
            {
                _16908 = _7367 / _8012.xxx;
            }
            else
            {
                _16908 = float3(1.0f, 0.0f, 0.0f);
            }
            float _8024 = sin(_8012);
            float _8027 = 1.0f - cos(_8012);
            float _8039 = -_8024;
            float _8046 = _8027 * _16908.x;
            float _8049 = _8046 * _16908.y;
            float _8062 = _8046 * _16908.z;
            float _8099 = (_8027 * _16908.y) * _16908.z;
            float _15432[9] = { 1.0f + (_8027 * ((_16908.x * _16908.x) - 1.0f)), (_8039 * _16908.z) + _8049, (_8024 * _16908.y) + _8062, (_8024 * _16908.z) + _8049, 1.0f + (_8027 * ((_16908.y * _16908.y) - 1.0f)), (_8039 * _16908.x) + _8099, (_8039 * _16908.y) + _8062, (_8024 * _16908.x) + _8099, 1.0f + (_8027 * ((_16908.z * _16908.z) - 1.0f)) };
            float _6775[9] = _15432;
            uint _16909;
            _16909 = 0u;
            for (; _16909 < 3u; _16909++)
            {
                for (uint _16925 = 0u; _16925 < 3u; )
                {
                    uint _7381 = _16909 * 3u;
                    _6780[_7381 + _16925] = ((_6775[_7381] * _6700[_16925]) + (_6775[_7381 + 1u] * _6700[3u + _16925])) + (_6775[_7381 + 2u] * _6700[6u + _16925]);
                    _16925++;
                    continue;
                }
            }
            float _7426 = nfruFitStep[3];
            float _7428 = nfruFitStep[4];
            float _7430 = nfruFitStep[5];
            float3 _7433 = _7559 - (float3(_7426, _7428, _7430) * (1.0f / _7356));
            float _16911;
            _16911 = 0.0f;
            float _17300;
            for (uint _16910 = 0u; _16910 < 3u; _16911 = _17300, _16910++)
            {
                uint _7442 = (gl_LocalInvocationIndex * 3u) + _16910;
                if (nfruFitW[_7442] > 0.0f)
                {
                    uint _8148 = _7442 * 3u;
                    uint _8153 = _8148 + 1u;
                    uint _8158 = _8148 + 2u;
                    float3 _8167 = float3(((_6780[0] * nfruFitX[_8148]) + (_6780[1] * nfruFitX[_8153])) + (_6780[2] * nfruFitX[_8158]), ((_6780[3] * nfruFitX[_8148]) + (_6780[4] * nfruFitX[_8153])) + (_6780[5] * nfruFitX[_8158]), ((_6780[6] * nfruFitX[_8148]) + (_6780[7] * nfruFitX[_8153])) + (_6780[8] * nfruFitX[_8158])) + _7433;
                    uint _8179 = _7442 * 2u;
                    float2 _8190 = ((_8167.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_8167.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_8179], nfruFitT[_8179 + 1u])) * _2713;
                    _17300 = _16911 + (nfruFitW[_7442] * dot(_8190, _8190));
                }
                else
                {
                    _17300 = _16911;
                }
            }
            nfruFitRed[gl_LocalInvocationIndex] = _16911;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _7479;
            if (_2882)
            {
                _7479 = nfruFitStat[1] < 0.5f;
            }
            else
            {
                _7479 = _2882;
            }
            if (_7479)
            {
                float _16913;
                _16913 = 0.0f;
                for (uint _16912 = 0u; _16912 < 256u; )
                {
                    _16913 += nfruFitRed[_16912];
                    _16912++;
                    continue;
                }
                bool _7498 = _16913 < nfruFitStat[0];
                bool _7504;
                if (_7498)
                {
                    _7504 = !isnan(_16913);
                }
                else
                {
                    _7504 = _7498;
                }
                if (_7504)
                {
                    for (uint _16914 = 0u; _16914 < 9u; )
                    {
                        nfruFitR[_16914] = _6780[_16914];
                        _16914++;
                        continue;
                    }
                    nfruFitTr[0] = _7433.x;
                    nfruFitTr[1] = _7433.y;
                    nfruFitTr[2] = _7433.z;
                    nfruFitStat[1] = 1.0f;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _8256[9];
        for (uint _16460 = 0u; _16460 < 9u; )
        {
            _8256[_16460] = nfruFitR[_16460];
            _16460++;
            continue;
        }
        float _9108 = nfruFitTr[0];
        float _9110 = nfruFitTr[1];
        float _9112 = nfruFitTr[2];
        float3 _9113 = float3(_9108, _9110, _9112);
        float _8351[9] = _8256;
        float _8254[9] = _8351;
        for (uint _16461 = 0u; _16461 < 3u; _16461++)
        {
            uint _8361 = (gl_LocalInvocationIndex * 3u) + _16461;
            uint _9117 = _8361 * 3u;
            uint _9118 = _9117 + 2u;
            float _16906;
            if (nfruFitX[_9118] > 0.0f)
            {
                uint _9136 = _9117 + 1u;
                float3 _9150 = float3(((_8351[0] * nfruFitX[_9117]) + (_8351[1] * nfruFitX[_9136])) + (_8351[2] * nfruFitX[_9118]), ((_8351[3] * nfruFitX[_9117]) + (_8351[4] * nfruFitX[_9136])) + (_8351[5] * nfruFitX[_9118]), ((_8351[6] * nfruFitX[_9117]) + (_8351[7] * nfruFitX[_9136])) + (_8351[8] * nfruFitX[_9118])) + _9113;
                uint _9162 = _8361 * 2u;
                _16906 = length(((_9150.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_9150.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_9162], nfruFitT[_9162 + 1u])) * _2713);
            }
            else
            {
                _16906 = 1000000000.0f;
            }
            nfruFitRes[_8361] = _16906;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            nfruFitStat[2] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _8424 = nfruFitStat[2] > 0.5f;
        float _16464;
        _16464 = 0.0f;
        float _8473;
        for (uint _16463 = 0u; _16463 < 3u; _16464 = _8473, _16463++)
        {
            uint _8433 = (gl_LocalInvocationIndex * 3u) + _16463;
            bool _9252 = nfruFitX[(_8433 * 3u) + 2u] > 0.0f;
            bool _8450;
            if (_9252)
            {
                bool _8447;
                if (_8424)
                {
                    _8447 = nfruFitRes[_8433] >= 32.0f;
                }
                else
                {
                    _8447 = _8424;
                }
                _8450 = !_8447;
            }
            else
            {
                _8450 = _9252;
            }
            float _16891;
            if (_8450)
            {
                float _16890;
                if (nfruFitRes[_8433] < 8.0f)
                {
                    _16890 = 1.0f;
                }
                else
                {
                    _16890 = 8.0f / max(nfruFitRes[_8433], 9.9999999747524270787835121154785e-07f);
                }
                _16891 = _16890;
            }
            else
            {
                _16891 = 0.0f;
            }
            nfruFitW[_8433] = _16891;
            _8473 = _16464 + ((_16891 * nfruFitRes[_8433]) * nfruFitRes[_8433]);
        }
        nfruFitRed[gl_LocalInvocationIndex] = _16464;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_3821)
        {
            bool _8486 = gl_LocalInvocationIndex < 21u;
            uint _16470;
            uint _16473;
            if (_8486)
            {
                uint _16465;
                uint _16467;
                _16467 = 0u;
                _16465 = gl_LocalInvocationIndex;
                for (uint _16466 = 6u; _16465 >= _16466; )
                {
                    uint _8497 = _16465 - _16466;
                    _16467++;
                    _16466--;
                    _16465 = _8497;
                    continue;
                }
                _16473 = _16467 + _16465;
                _16470 = _16467;
            }
            else
            {
                _16473 = 0u;
                _16470 = gl_LocalInvocationIndex - 21u;
            }
            float _16471;
            _16471 = 0.0f;
            float _17165;
            for (uint _16468 = 0u; _16468 < 768u; _16471 = _17165, _16468++)
            {
                if (nfruFitW[_16468] <= 0.0f)
                {
                    _17165 = _16471;
                    continue;
                }
                uint _9263 = _16468 * 3u;
                uint _9268 = _9263 + 1u;
                uint _9273 = _9263 + 2u;
                float3 _9359 = float3(((_8351[0] * nfruFitX[_9263]) + (_8351[1] * nfruFitX[_9268])) + (_8351[2] * nfruFitX[_9273]), ((_8351[3] * nfruFitX[_9263]) + (_8351[4] * nfruFitX[_9268])) + (_8351[5] * nfruFitX[_9273]), ((_8351[6] * nfruFitX[_9263]) + (_8351[7] * nfruFitX[_9268])) + (_8351[8] * nfruFitX[_9273]));
                float3 _9282 = _9359 + _9113;
                float _9288 = max(_9282.z, 9.9999999747524270787835121154785e-07f);
                uint _9294 = _16468 * 2u;
                float _9383 = 1.0f / _9288;
                float3 _9401 = float3(_9383 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_9282.x) * _9383) * _9383) / cbFI_DeviceToViewDepth.z) * _2713.x;
                float3 _9419 = float3(0.0f, _9383 / cbFI_DeviceToViewDepth.w, (((-_9282.y) * _9383) * _9383) / cbFI_DeviceToViewDepth.w) * _2713.y;
                float3 _16881;
                if (_16470 < 3u)
                {
                    _16881 = cross(float3(float(_16470 == 0u), float(_16470 == 1u), float(_16470 == 2u)), _9359);
                }
                else
                {
                    _16881 = float3(float(_16470 == 3u), float(_16470 == 4u), float(_16470 == 5u));
                }
                float2 _9454 = float2(dot(_9401, _16881), dot(_9419, _16881));
                float _17166;
                if (_8486)
                {
                    float3 _16884;
                    if (_16473 < 3u)
                    {
                        _16884 = cross(float3(float(_16473 == 0u), float(_16473 == 1u), float(_16473 == 2u)), _9359);
                    }
                    else
                    {
                        _16884 = float3(float(_16473 == 3u), float(_16473 == 4u), float(_16473 == 5u));
                    }
                    _17166 = _16471 + (nfruFitW[_16468] * dot(_9454, float2(dot(_9401, _16884), dot(_9419, _16884))));
                }
                else
                {
                    _17166 = _16471 + (nfruFitW[_16468] * dot(_9454, ((_9282.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _9288)) - float2(nfruFitT[_9294], nfruFitT[_9294 + 1u])) * _2713));
                }
                _17165 = _17166;
            }
            if (_8486)
            {
                nfruFitA[(_16470 * 7u) + _16473] = _16471;
                nfruFitA[(_16473 * 7u) + _16470] = _16471;
            }
            else
            {
                nfruFitA[(_16470 * 7u) + 6u] = _16471;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16475;
            _16475 = 0.0f;
            for (uint _16474 = 0u; _16474 < 256u; )
            {
                _16475 += nfruFitRed[_16474];
                _16474++;
                continue;
            }
            nfruFitStat[0] = _16475;
            float _16880;
            _16880 = 0.0f;
            for (uint _16476 = 0u; _16476 < 6u; )
            {
                _16880 += nfruFitA[(_16476 * 7u) + _16476];
                _16476++;
                continue;
            }
            for (uint _16477 = 0u; _16477 < 6u; )
            {
                uint _8630 = (_16477 * 7u) + _16477;
                nfruFitA[_8630] += ((9.999999717180685365747194737196e-10f * _16880) + 1.0000000031710768509710513471353e-30f);
                _16477++;
                continue;
            }
            for (uint _16478 = 0u; _16478 < 6u; _16478++)
            {
                uint _8695 = _16478 * 7u;
                uint _8697 = _8695 + _16478;
                float _8700 = abs(nfruFitA[_8697]);
                uint _8702 = _16478 + 1u;
                uint _16864;
                _16864 = _16478;
                uint _17333;
                float _17295;
                uint _16863 = _8702;
                float _16877 = _8700;
                for (; _16863 < 6u; _16877 = _17295, _16864 = _17333, _16863++)
                {
                    uint _8711 = (_16863 * 7u) + _16478;
                    bool _8716 = abs(nfruFitA[_8711]) > _16877;
                    if (_8716)
                    {
                        _17295 = abs(nfruFitA[_8711]);
                    }
                    else
                    {
                        _17295 = _16877;
                    }
                    _17333 = _8716 ? _16863 : _16864;
                }
                if (_16864 != _16478)
                {
                    for (uint _16866 = 0u; _16866 < 7u; )
                    {
                        uint _8743 = _8695 + _16866;
                        float _8745 = nfruFitA[_8743];
                        uint _8753 = (_16864 * 7u) + _16866;
                        nfruFitA[_8743] = nfruFitA[_8753];
                        nfruFitA[_8753] = _8745;
                        _16866++;
                        continue;
                    }
                }
                float _16869;
                if (abs(nfruFitA[_8697]) > 1.0000000031710768509710513471353e-30f)
                {
                    _16869 = nfruFitA[_8697];
                }
                else
                {
                    _16869 = 1.0000000031710768509710513471353e-30f;
                }
                for (uint _16871 = _8702; _16871 < 6u; _16871++)
                {
                    uint _8794 = _16871 * 7u;
                    float _8800 = nfruFitA[_8794 + _16478] / _16869;
                    for (uint _16873 = _16478; _16873 < 7u; )
                    {
                        uint _8810 = _8794 + _16873;
                        nfruFitA[_8810] -= (_8800 * nfruFitA[_8695 + _16873]);
                        _16873++;
                        continue;
                    }
                }
            }
            for (int _16479 = 5; _16479 >= 0; _16479--)
            {
                uint _8841 = uint(_16479);
                uint _8842 = _8841 * 7u;
                uint _8848 = _8841 + 1u;
                float _16862;
                _16862 = nfruFitA[_8842 + 6u];
                for (uint _16860 = _8848; _16860 < 6u; )
                {
                    _16862 -= (nfruFitA[_8842 + _16860] * nfruFitStep[_16860]);
                    _16860++;
                    continue;
                }
                uint _8876 = _8842 + _8841;
                nfruFitStep[_8841] = _16862 / ((abs(nfruFitA[_8876]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_8876] : 1.0000000031710768509710513471353e-30f);
            }
            nfruFitStat[1] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _8334[9];
        for (uint _16480 = 0u; _16480 < 5u; _16480++)
        {
            uint _8909 = 1u << _16480;
            float _8910 = float(_8909);
            float3 _8921 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _8910);
            float _9566 = length(_8921);
            float3 _16841;
            if (_9566 > 9.9999999600419720025001879548654e-13f)
            {
                _16841 = _8921 / _9566.xxx;
            }
            else
            {
                _16841 = float3(1.0f, 0.0f, 0.0f);
            }
            float _9578 = sin(_9566);
            float _9581 = 1.0f - cos(_9566);
            float _9593 = -_9578;
            float _9600 = _9581 * _16841.x;
            float _9603 = _9600 * _16841.y;
            float _9616 = _9600 * _16841.z;
            float _9653 = (_9581 * _16841.y) * _16841.z;
            float _15275[9] = { 1.0f + (_9581 * ((_16841.x * _16841.x) - 1.0f)), (_9593 * _16841.z) + _9603, (_9578 * _16841.y) + _9616, (_9578 * _16841.z) + _9603, 1.0f + (_9581 * ((_16841.y * _16841.y) - 1.0f)), (_9593 * _16841.x) + _9653, (_9593 * _16841.y) + _9616, (_9578 * _16841.x) + _9653, 1.0f + (_9581 * ((_16841.z * _16841.z) - 1.0f)) };
            float _8329[9] = _15275;
            uint _16842;
            _16842 = 0u;
            for (; _16842 < 3u; _16842++)
            {
                for (uint _16858 = 0u; _16858 < 3u; )
                {
                    uint _8935 = _16842 * 3u;
                    _8334[_8935 + _16858] = ((_8329[_8935] * _8254[_16858]) + (_8329[_8935 + 1u] * _8254[3u + _16858])) + (_8329[_8935 + 2u] * _8254[6u + _16858]);
                    _16858++;
                    continue;
                }
            }
            float _8980 = nfruFitStep[3];
            float _8982 = nfruFitStep[4];
            float _8984 = nfruFitStep[5];
            float3 _8987 = _9113 - (float3(_8980, _8982, _8984) * (1.0f / _8910));
            float _16844;
            _16844 = 0.0f;
            float _17290;
            for (uint _16843 = 0u; _16843 < 3u; _16844 = _17290, _16843++)
            {
                uint _8996 = (gl_LocalInvocationIndex * 3u) + _16843;
                if (nfruFitW[_8996] > 0.0f)
                {
                    uint _9702 = _8996 * 3u;
                    uint _9707 = _9702 + 1u;
                    uint _9712 = _9702 + 2u;
                    float3 _9721 = float3(((_8334[0] * nfruFitX[_9702]) + (_8334[1] * nfruFitX[_9707])) + (_8334[2] * nfruFitX[_9712]), ((_8334[3] * nfruFitX[_9702]) + (_8334[4] * nfruFitX[_9707])) + (_8334[5] * nfruFitX[_9712]), ((_8334[6] * nfruFitX[_9702]) + (_8334[7] * nfruFitX[_9707])) + (_8334[8] * nfruFitX[_9712])) + _8987;
                    uint _9733 = _8996 * 2u;
                    float2 _9744 = ((_9721.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_9721.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_9733], nfruFitT[_9733 + 1u])) * _2713;
                    _17290 = _16844 + (nfruFitW[_8996] * dot(_9744, _9744));
                }
                else
                {
                    _17290 = _16844;
                }
            }
            nfruFitRed[gl_LocalInvocationIndex] = _16844;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _9033;
            if (_2882)
            {
                _9033 = nfruFitStat[1] < 0.5f;
            }
            else
            {
                _9033 = _2882;
            }
            if (_9033)
            {
                float _16846;
                _16846 = 0.0f;
                for (uint _16845 = 0u; _16845 < 256u; )
                {
                    _16846 += nfruFitRed[_16845];
                    _16845++;
                    continue;
                }
                bool _9052 = _16846 < nfruFitStat[0];
                bool _9058;
                if (_9052)
                {
                    _9058 = !isnan(_16846);
                }
                else
                {
                    _9058 = _9052;
                }
                if (_9058)
                {
                    for (uint _16847 = 0u; _16847 < 9u; )
                    {
                        nfruFitR[_16847] = _8334[_16847];
                        _16847++;
                        continue;
                    }
                    nfruFitTr[0] = _8987.x;
                    nfruFitTr[1] = _8987.y;
                    nfruFitTr[2] = _8987.z;
                    nfruFitStat[1] = 1.0f;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _9810[9];
        for (uint _16481 = 0u; _16481 < 9u; )
        {
            _9810[_16481] = nfruFitR[_16481];
            _16481++;
            continue;
        }
        float _10662 = nfruFitTr[0];
        float _10664 = nfruFitTr[1];
        float _10666 = nfruFitTr[2];
        float3 _10667 = float3(_10662, _10664, _10666);
        float _9905[9] = _9810;
        float _9808[9] = _9905;
        for (uint _16482 = 0u; _16482 < 3u; _16482++)
        {
            uint _9915 = (gl_LocalInvocationIndex * 3u) + _16482;
            uint _10671 = _9915 * 3u;
            uint _10672 = _10671 + 2u;
            float _16839;
            if (nfruFitX[_10672] > 0.0f)
            {
                uint _10690 = _10671 + 1u;
                float3 _10704 = float3(((_9905[0] * nfruFitX[_10671]) + (_9905[1] * nfruFitX[_10690])) + (_9905[2] * nfruFitX[_10672]), ((_9905[3] * nfruFitX[_10671]) + (_9905[4] * nfruFitX[_10690])) + (_9905[5] * nfruFitX[_10672]), ((_9905[6] * nfruFitX[_10671]) + (_9905[7] * nfruFitX[_10690])) + (_9905[8] * nfruFitX[_10672])) + _10667;
                uint _10716 = _9915 * 2u;
                _16839 = length(((_10704.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_10704.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_10716], nfruFitT[_10716 + 1u])) * _2713);
            }
            else
            {
                _16839 = 1000000000.0f;
            }
            nfruFitRes[_9915] = _16839;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            nfruFitStat[2] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _9978 = nfruFitStat[2] > 0.5f;
        float _16485;
        _16485 = 0.0f;
        float _10027;
        for (uint _16484 = 0u; _16484 < 3u; _16485 = _10027, _16484++)
        {
            uint _9987 = (gl_LocalInvocationIndex * 3u) + _16484;
            bool _10806 = nfruFitX[(_9987 * 3u) + 2u] > 0.0f;
            bool _10004;
            if (_10806)
            {
                bool _10001;
                if (_9978)
                {
                    _10001 = nfruFitRes[_9987] >= 16.0f;
                }
                else
                {
                    _10001 = _9978;
                }
                _10004 = !_10001;
            }
            else
            {
                _10004 = _10806;
            }
            float _16824;
            if (_10004)
            {
                float _16823;
                if (nfruFitRes[_9987] < 4.0f)
                {
                    _16823 = 1.0f;
                }
                else
                {
                    _16823 = 4.0f / max(nfruFitRes[_9987], 9.9999999747524270787835121154785e-07f);
                }
                _16824 = _16823;
            }
            else
            {
                _16824 = 0.0f;
            }
            nfruFitW[_9987] = _16824;
            _10027 = _16485 + ((_16824 * nfruFitRes[_9987]) * nfruFitRes[_9987]);
        }
        nfruFitRed[gl_LocalInvocationIndex] = _16485;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_3821)
        {
            bool _10040 = gl_LocalInvocationIndex < 21u;
            uint _16491;
            uint _16494;
            if (_10040)
            {
                uint _16486;
                uint _16488;
                _16488 = 0u;
                _16486 = gl_LocalInvocationIndex;
                for (uint _16487 = 6u; _16486 >= _16487; )
                {
                    uint _10051 = _16486 - _16487;
                    _16488++;
                    _16487--;
                    _16486 = _10051;
                    continue;
                }
                _16494 = _16488 + _16486;
                _16491 = _16488;
            }
            else
            {
                _16494 = 0u;
                _16491 = gl_LocalInvocationIndex - 21u;
            }
            float _16492;
            _16492 = 0.0f;
            float _17174;
            for (uint _16489 = 0u; _16489 < 768u; _16492 = _17174, _16489++)
            {
                if (nfruFitW[_16489] <= 0.0f)
                {
                    _17174 = _16492;
                    continue;
                }
                uint _10817 = _16489 * 3u;
                uint _10822 = _10817 + 1u;
                uint _10827 = _10817 + 2u;
                float3 _10913 = float3(((_9905[0] * nfruFitX[_10817]) + (_9905[1] * nfruFitX[_10822])) + (_9905[2] * nfruFitX[_10827]), ((_9905[3] * nfruFitX[_10817]) + (_9905[4] * nfruFitX[_10822])) + (_9905[5] * nfruFitX[_10827]), ((_9905[6] * nfruFitX[_10817]) + (_9905[7] * nfruFitX[_10822])) + (_9905[8] * nfruFitX[_10827]));
                float3 _10836 = _10913 + _10667;
                float _10842 = max(_10836.z, 9.9999999747524270787835121154785e-07f);
                uint _10848 = _16489 * 2u;
                float _10937 = 1.0f / _10842;
                float3 _10955 = float3(_10937 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_10836.x) * _10937) * _10937) / cbFI_DeviceToViewDepth.z) * _2713.x;
                float3 _10973 = float3(0.0f, _10937 / cbFI_DeviceToViewDepth.w, (((-_10836.y) * _10937) * _10937) / cbFI_DeviceToViewDepth.w) * _2713.y;
                float3 _16814;
                if (_16491 < 3u)
                {
                    _16814 = cross(float3(float(_16491 == 0u), float(_16491 == 1u), float(_16491 == 2u)), _10913);
                }
                else
                {
                    _16814 = float3(float(_16491 == 3u), float(_16491 == 4u), float(_16491 == 5u));
                }
                float2 _11008 = float2(dot(_10955, _16814), dot(_10973, _16814));
                float _17175;
                if (_10040)
                {
                    float3 _16817;
                    if (_16494 < 3u)
                    {
                        _16817 = cross(float3(float(_16494 == 0u), float(_16494 == 1u), float(_16494 == 2u)), _10913);
                    }
                    else
                    {
                        _16817 = float3(float(_16494 == 3u), float(_16494 == 4u), float(_16494 == 5u));
                    }
                    _17175 = _16492 + (nfruFitW[_16489] * dot(_11008, float2(dot(_10955, _16817), dot(_10973, _16817))));
                }
                else
                {
                    _17175 = _16492 + (nfruFitW[_16489] * dot(_11008, ((_10836.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _10842)) - float2(nfruFitT[_10848], nfruFitT[_10848 + 1u])) * _2713));
                }
                _17174 = _17175;
            }
            if (_10040)
            {
                nfruFitA[(_16491 * 7u) + _16494] = _16492;
                nfruFitA[(_16494 * 7u) + _16491] = _16492;
            }
            else
            {
                nfruFitA[(_16491 * 7u) + 6u] = _16492;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16496;
            _16496 = 0.0f;
            for (uint _16495 = 0u; _16495 < 256u; )
            {
                _16496 += nfruFitRed[_16495];
                _16495++;
                continue;
            }
            nfruFitStat[0] = _16496;
            float _16813;
            _16813 = 0.0f;
            for (uint _16497 = 0u; _16497 < 6u; )
            {
                _16813 += nfruFitA[(_16497 * 7u) + _16497];
                _16497++;
                continue;
            }
            for (uint _16498 = 0u; _16498 < 6u; )
            {
                uint _10184 = (_16498 * 7u) + _16498;
                nfruFitA[_10184] += ((9.999999717180685365747194737196e-10f * _16813) + 1.0000000031710768509710513471353e-30f);
                _16498++;
                continue;
            }
            for (uint _16499 = 0u; _16499 < 6u; _16499++)
            {
                uint _10249 = _16499 * 7u;
                uint _10251 = _10249 + _16499;
                float _10254 = abs(nfruFitA[_10251]);
                uint _10256 = _16499 + 1u;
                uint _16797;
                _16797 = _16499;
                uint _17334;
                float _17285;
                uint _16796 = _10256;
                float _16810 = _10254;
                for (; _16796 < 6u; _16810 = _17285, _16797 = _17334, _16796++)
                {
                    uint _10265 = (_16796 * 7u) + _16499;
                    bool _10270 = abs(nfruFitA[_10265]) > _16810;
                    if (_10270)
                    {
                        _17285 = abs(nfruFitA[_10265]);
                    }
                    else
                    {
                        _17285 = _16810;
                    }
                    _17334 = _10270 ? _16796 : _16797;
                }
                if (_16797 != _16499)
                {
                    for (uint _16799 = 0u; _16799 < 7u; )
                    {
                        uint _10297 = _10249 + _16799;
                        float _10299 = nfruFitA[_10297];
                        uint _10307 = (_16797 * 7u) + _16799;
                        nfruFitA[_10297] = nfruFitA[_10307];
                        nfruFitA[_10307] = _10299;
                        _16799++;
                        continue;
                    }
                }
                float _16802;
                if (abs(nfruFitA[_10251]) > 1.0000000031710768509710513471353e-30f)
                {
                    _16802 = nfruFitA[_10251];
                }
                else
                {
                    _16802 = 1.0000000031710768509710513471353e-30f;
                }
                for (uint _16804 = _10256; _16804 < 6u; _16804++)
                {
                    uint _10348 = _16804 * 7u;
                    float _10354 = nfruFitA[_10348 + _16499] / _16802;
                    for (uint _16806 = _16499; _16806 < 7u; )
                    {
                        uint _10364 = _10348 + _16806;
                        nfruFitA[_10364] -= (_10354 * nfruFitA[_10249 + _16806]);
                        _16806++;
                        continue;
                    }
                }
            }
            for (int _16500 = 5; _16500 >= 0; _16500--)
            {
                uint _10395 = uint(_16500);
                uint _10396 = _10395 * 7u;
                uint _10402 = _10395 + 1u;
                float _16795;
                _16795 = nfruFitA[_10396 + 6u];
                for (uint _16793 = _10402; _16793 < 6u; )
                {
                    _16795 -= (nfruFitA[_10396 + _16793] * nfruFitStep[_16793]);
                    _16793++;
                    continue;
                }
                uint _10430 = _10396 + _10395;
                nfruFitStep[_10395] = _16795 / ((abs(nfruFitA[_10430]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_10430] : 1.0000000031710768509710513471353e-30f);
            }
            nfruFitStat[1] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _9888[9];
        for (uint _16501 = 0u; _16501 < 5u; _16501++)
        {
            uint _10463 = 1u << _16501;
            float _10464 = float(_10463);
            float3 _10475 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _10464);
            float _11120 = length(_10475);
            float3 _16774;
            if (_11120 > 9.9999999600419720025001879548654e-13f)
            {
                _16774 = _10475 / _11120.xxx;
            }
            else
            {
                _16774 = float3(1.0f, 0.0f, 0.0f);
            }
            float _11132 = sin(_11120);
            float _11135 = 1.0f - cos(_11120);
            float _11147 = -_11132;
            float _11154 = _11135 * _16774.x;
            float _11157 = _11154 * _16774.y;
            float _11170 = _11154 * _16774.z;
            float _11207 = (_11135 * _16774.y) * _16774.z;
            float _15118[9] = { 1.0f + (_11135 * ((_16774.x * _16774.x) - 1.0f)), (_11147 * _16774.z) + _11157, (_11132 * _16774.y) + _11170, (_11132 * _16774.z) + _11157, 1.0f + (_11135 * ((_16774.y * _16774.y) - 1.0f)), (_11147 * _16774.x) + _11207, (_11147 * _16774.y) + _11170, (_11132 * _16774.x) + _11207, 1.0f + (_11135 * ((_16774.z * _16774.z) - 1.0f)) };
            float _9883[9] = _15118;
            uint _16775;
            _16775 = 0u;
            for (; _16775 < 3u; _16775++)
            {
                for (uint _16791 = 0u; _16791 < 3u; )
                {
                    uint _10489 = _16775 * 3u;
                    _9888[_10489 + _16791] = ((_9883[_10489] * _9808[_16791]) + (_9883[_10489 + 1u] * _9808[3u + _16791])) + (_9883[_10489 + 2u] * _9808[6u + _16791]);
                    _16791++;
                    continue;
                }
            }
            float _10534 = nfruFitStep[3];
            float _10536 = nfruFitStep[4];
            float _10538 = nfruFitStep[5];
            float3 _10541 = _10667 - (float3(_10534, _10536, _10538) * (1.0f / _10464));
            float _16777;
            _16777 = 0.0f;
            float _17280;
            for (uint _16776 = 0u; _16776 < 3u; _16777 = _17280, _16776++)
            {
                uint _10550 = (gl_LocalInvocationIndex * 3u) + _16776;
                if (nfruFitW[_10550] > 0.0f)
                {
                    uint _11256 = _10550 * 3u;
                    uint _11261 = _11256 + 1u;
                    uint _11266 = _11256 + 2u;
                    float3 _11275 = float3(((_9888[0] * nfruFitX[_11256]) + (_9888[1] * nfruFitX[_11261])) + (_9888[2] * nfruFitX[_11266]), ((_9888[3] * nfruFitX[_11256]) + (_9888[4] * nfruFitX[_11261])) + (_9888[5] * nfruFitX[_11266]), ((_9888[6] * nfruFitX[_11256]) + (_9888[7] * nfruFitX[_11261])) + (_9888[8] * nfruFitX[_11266])) + _10541;
                    uint _11287 = _10550 * 2u;
                    float2 _11298 = ((_11275.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_11275.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_11287], nfruFitT[_11287 + 1u])) * _2713;
                    _17280 = _16777 + (nfruFitW[_10550] * dot(_11298, _11298));
                }
                else
                {
                    _17280 = _16777;
                }
            }
            nfruFitRed[gl_LocalInvocationIndex] = _16777;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _10587;
            if (_2882)
            {
                _10587 = nfruFitStat[1] < 0.5f;
            }
            else
            {
                _10587 = _2882;
            }
            if (_10587)
            {
                float _16779;
                _16779 = 0.0f;
                for (uint _16778 = 0u; _16778 < 256u; )
                {
                    _16779 += nfruFitRed[_16778];
                    _16778++;
                    continue;
                }
                bool _10606 = _16779 < nfruFitStat[0];
                bool _10612;
                if (_10606)
                {
                    _10612 = !isnan(_16779);
                }
                else
                {
                    _10612 = _10606;
                }
                if (_10612)
                {
                    for (uint _16780 = 0u; _16780 < 9u; )
                    {
                        nfruFitR[_16780] = _9888[_16780];
                        _16780++;
                        continue;
                    }
                    nfruFitTr[0] = _10541.x;
                    nfruFitTr[1] = _10541.y;
                    nfruFitTr[2] = _10541.z;
                    nfruFitStat[1] = 1.0f;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _11364[9];
        for (uint _16502 = 0u; _16502 < 9u; )
        {
            _11364[_16502] = nfruFitR[_16502];
            _16502++;
            continue;
        }
        float _12216 = nfruFitTr[0];
        float _12218 = nfruFitTr[1];
        float _12220 = nfruFitTr[2];
        float3 _12221 = float3(_12216, _12218, _12220);
        float _11459[9] = _11364;
        float _11362[9] = _11459;
        for (uint _16503 = 0u; _16503 < 3u; _16503++)
        {
            uint _11469 = (gl_LocalInvocationIndex * 3u) + _16503;
            uint _12225 = _11469 * 3u;
            uint _12226 = _12225 + 2u;
            float _16772;
            if (nfruFitX[_12226] > 0.0f)
            {
                uint _12244 = _12225 + 1u;
                float3 _12258 = float3(((_11459[0] * nfruFitX[_12225]) + (_11459[1] * nfruFitX[_12244])) + (_11459[2] * nfruFitX[_12226]), ((_11459[3] * nfruFitX[_12225]) + (_11459[4] * nfruFitX[_12244])) + (_11459[5] * nfruFitX[_12226]), ((_11459[6] * nfruFitX[_12225]) + (_11459[7] * nfruFitX[_12244])) + (_11459[8] * nfruFitX[_12226])) + _12221;
                uint _12270 = _11469 * 2u;
                _16772 = length(((_12258.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_12258.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_12270], nfruFitT[_12270 + 1u])) * _2713);
            }
            else
            {
                _16772 = 1000000000.0f;
            }
            nfruFitRes[_11469] = _16772;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16505;
            float _16506;
            _16506 = 0.0f;
            _16505 = 0.0f;
            float _17179;
            float _17181;
            for (uint _16504 = 0u; _16504 < 768u; _16506 = _17181, _16505 = _17179, _16504++)
            {
                if (nfruFitX[(_16504 * 3u) + 2u] > 0.0f)
                {
                    float _17180;
                    if (nfruFitRes[_16504] < 8.0f)
                    {
                        _17180 = _16505 + 1.0f;
                    }
                    else
                    {
                        _17180 = _16505;
                    }
                    _17181 = _16506 + 1.0f;
                    _17179 = _17180;
                }
                else
                {
                    _17181 = _16506;
                    _17179 = _16505;
                }
            }
            nfruFitStat[2] = float(_16505 >= (0.25f * _16506));
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        bool _11532 = nfruFitStat[2] > 0.5f;
        float _16508;
        _16508 = 0.0f;
        float _11581;
        for (uint _16507 = 0u; _16507 < 3u; _16508 = _11581, _16507++)
        {
            uint _11541 = (gl_LocalInvocationIndex * 3u) + _16507;
            bool _12360 = nfruFitX[(_11541 * 3u) + 2u] > 0.0f;
            bool _11558;
            if (_12360)
            {
                bool _11555;
                if (_11532)
                {
                    _11555 = nfruFitRes[_11541] >= 8.0f;
                }
                else
                {
                    _11555 = _11532;
                }
                _11558 = !_11555;
            }
            else
            {
                _11558 = _12360;
            }
            float _16759;
            if (_11558)
            {
                float _16758;
                if (nfruFitRes[_11541] < 2.0f)
                {
                    _16758 = 1.0f;
                }
                else
                {
                    _16758 = 2.0f / max(nfruFitRes[_11541], 9.9999999747524270787835121154785e-07f);
                }
                _16759 = _16758;
            }
            else
            {
                _16759 = 0.0f;
            }
            nfruFitW[_11541] = _16759;
            _11581 = _16508 + ((_16759 * nfruFitRes[_11541]) * nfruFitRes[_11541]);
        }
        nfruFitRed[gl_LocalInvocationIndex] = _16508;
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_3821)
        {
            bool _11594 = gl_LocalInvocationIndex < 21u;
            uint _16514;
            uint _16517;
            if (_11594)
            {
                uint _16509;
                uint _16511;
                _16511 = 0u;
                _16509 = gl_LocalInvocationIndex;
                for (uint _16510 = 6u; _16509 >= _16510; )
                {
                    uint _11605 = _16509 - _16510;
                    _16511++;
                    _16510--;
                    _16509 = _11605;
                    continue;
                }
                _16517 = _16511 + _16509;
                _16514 = _16511;
            }
            else
            {
                _16517 = 0u;
                _16514 = gl_LocalInvocationIndex - 21u;
            }
            float _16515;
            _16515 = 0.0f;
            float _17187;
            for (uint _16512 = 0u; _16512 < 768u; _16515 = _17187, _16512++)
            {
                if (nfruFitW[_16512] <= 0.0f)
                {
                    _17187 = _16515;
                    continue;
                }
                uint _12371 = _16512 * 3u;
                uint _12376 = _12371 + 1u;
                uint _12381 = _12371 + 2u;
                float3 _12467 = float3(((_11459[0] * nfruFitX[_12371]) + (_11459[1] * nfruFitX[_12376])) + (_11459[2] * nfruFitX[_12381]), ((_11459[3] * nfruFitX[_12371]) + (_11459[4] * nfruFitX[_12376])) + (_11459[5] * nfruFitX[_12381]), ((_11459[6] * nfruFitX[_12371]) + (_11459[7] * nfruFitX[_12376])) + (_11459[8] * nfruFitX[_12381]));
                float3 _12390 = _12467 + _12221;
                float _12396 = max(_12390.z, 9.9999999747524270787835121154785e-07f);
                uint _12402 = _16512 * 2u;
                float _12491 = 1.0f / _12396;
                float3 _12509 = float3(_12491 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_12390.x) * _12491) * _12491) / cbFI_DeviceToViewDepth.z) * _2713.x;
                float3 _12527 = float3(0.0f, _12491 / cbFI_DeviceToViewDepth.w, (((-_12390.y) * _12491) * _12491) / cbFI_DeviceToViewDepth.w) * _2713.y;
                float3 _16749;
                if (_16514 < 3u)
                {
                    _16749 = cross(float3(float(_16514 == 0u), float(_16514 == 1u), float(_16514 == 2u)), _12467);
                }
                else
                {
                    _16749 = float3(float(_16514 == 3u), float(_16514 == 4u), float(_16514 == 5u));
                }
                float2 _12562 = float2(dot(_12509, _16749), dot(_12527, _16749));
                float _17188;
                if (_11594)
                {
                    float3 _16752;
                    if (_16517 < 3u)
                    {
                        _16752 = cross(float3(float(_16517 == 0u), float(_16517 == 1u), float(_16517 == 2u)), _12467);
                    }
                    else
                    {
                        _16752 = float3(float(_16517 == 3u), float(_16517 == 4u), float(_16517 == 5u));
                    }
                    _17188 = _16515 + (nfruFitW[_16512] * dot(_12562, float2(dot(_12509, _16752), dot(_12527, _16752))));
                }
                else
                {
                    _17188 = _16515 + (nfruFitW[_16512] * dot(_12562, ((_12390.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _12396)) - float2(nfruFitT[_12402], nfruFitT[_12402 + 1u])) * _2713));
                }
                _17187 = _17188;
            }
            if (_11594)
            {
                nfruFitA[(_16514 * 7u) + _16517] = _16515;
                nfruFitA[(_16517 * 7u) + _16514] = _16515;
            }
            else
            {
                nfruFitA[(_16514 * 7u) + 6u] = _16515;
            }
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16519;
            _16519 = 0.0f;
            for (uint _16518 = 0u; _16518 < 256u; )
            {
                _16519 += nfruFitRed[_16518];
                _16518++;
                continue;
            }
            nfruFitStat[0] = _16519;
            float _16748;
            _16748 = 0.0f;
            for (uint _16520 = 0u; _16520 < 6u; )
            {
                _16748 += nfruFitA[(_16520 * 7u) + _16520];
                _16520++;
                continue;
            }
            for (uint _16521 = 0u; _16521 < 6u; )
            {
                uint _11738 = (_16521 * 7u) + _16521;
                nfruFitA[_11738] += ((9.999999717180685365747194737196e-10f * _16748) + 1.0000000031710768509710513471353e-30f);
                _16521++;
                continue;
            }
            for (uint _16522 = 0u; _16522 < 6u; _16522++)
            {
                uint _11803 = _16522 * 7u;
                uint _11805 = _11803 + _16522;
                float _11808 = abs(nfruFitA[_11805]);
                uint _11810 = _16522 + 1u;
                uint _16732;
                _16732 = _16522;
                uint _17335;
                float _17279;
                uint _16731 = _11810;
                float _16745 = _11808;
                for (; _16731 < 6u; _16745 = _17279, _16732 = _17335, _16731++)
                {
                    uint _11819 = (_16731 * 7u) + _16522;
                    bool _11824 = abs(nfruFitA[_11819]) > _16745;
                    if (_11824)
                    {
                        _17279 = abs(nfruFitA[_11819]);
                    }
                    else
                    {
                        _17279 = _16745;
                    }
                    _17335 = _11824 ? _16731 : _16732;
                }
                if (_16732 != _16522)
                {
                    for (uint _16734 = 0u; _16734 < 7u; )
                    {
                        uint _11851 = _11803 + _16734;
                        float _11853 = nfruFitA[_11851];
                        uint _11861 = (_16732 * 7u) + _16734;
                        nfruFitA[_11851] = nfruFitA[_11861];
                        nfruFitA[_11861] = _11853;
                        _16734++;
                        continue;
                    }
                }
                float _16737;
                if (abs(nfruFitA[_11805]) > 1.0000000031710768509710513471353e-30f)
                {
                    _16737 = nfruFitA[_11805];
                }
                else
                {
                    _16737 = 1.0000000031710768509710513471353e-30f;
                }
                for (uint _16739 = _11810; _16739 < 6u; _16739++)
                {
                    uint _11902 = _16739 * 7u;
                    float _11908 = nfruFitA[_11902 + _16522] / _16737;
                    for (uint _16741 = _16522; _16741 < 7u; )
                    {
                        uint _11918 = _11902 + _16741;
                        nfruFitA[_11918] -= (_11908 * nfruFitA[_11803 + _16741]);
                        _16741++;
                        continue;
                    }
                }
            }
            for (int _16523 = 5; _16523 >= 0; _16523--)
            {
                uint _11949 = uint(_16523);
                uint _11950 = _11949 * 7u;
                uint _11956 = _11949 + 1u;
                float _16730;
                _16730 = nfruFitA[_11950 + 6u];
                for (uint _16728 = _11956; _16728 < 6u; )
                {
                    _16730 -= (nfruFitA[_11950 + _16728] * nfruFitStep[_16728]);
                    _16728++;
                    continue;
                }
                uint _11984 = _11950 + _11949;
                nfruFitStep[_11949] = _16730 / ((abs(nfruFitA[_11984]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_11984] : 1.0000000031710768509710513471353e-30f);
            }
            nfruFitStat[1] = 0.0f;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        float _11442[9];
        for (uint _16524 = 0u; _16524 < 5u; _16524++)
        {
            uint _12017 = 1u << _16524;
            float _12018 = float(_12017);
            float3 _12029 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _12018);
            float _12674 = length(_12029);
            float3 _16709;
            if (_12674 > 9.9999999600419720025001879548654e-13f)
            {
                _16709 = _12029 / _12674.xxx;
            }
            else
            {
                _16709 = float3(1.0f, 0.0f, 0.0f);
            }
            float _12686 = sin(_12674);
            float _12689 = 1.0f - cos(_12674);
            float _12701 = -_12686;
            float _12708 = _12689 * _16709.x;
            float _12711 = _12708 * _16709.y;
            float _12724 = _12708 * _16709.z;
            float _12761 = (_12689 * _16709.y) * _16709.z;
            float _14961[9] = { 1.0f + (_12689 * ((_16709.x * _16709.x) - 1.0f)), (_12701 * _16709.z) + _12711, (_12686 * _16709.y) + _12724, (_12686 * _16709.z) + _12711, 1.0f + (_12689 * ((_16709.y * _16709.y) - 1.0f)), (_12701 * _16709.x) + _12761, (_12701 * _16709.y) + _12724, (_12686 * _16709.x) + _12761, 1.0f + (_12689 * ((_16709.z * _16709.z) - 1.0f)) };
            float _11437[9] = _14961;
            uint _16710;
            _16710 = 0u;
            for (; _16710 < 3u; _16710++)
            {
                for (uint _16726 = 0u; _16726 < 3u; )
                {
                    uint _12043 = _16710 * 3u;
                    _11442[_12043 + _16726] = ((_11437[_12043] * _11362[_16726]) + (_11437[_12043 + 1u] * _11362[3u + _16726])) + (_11437[_12043 + 2u] * _11362[6u + _16726]);
                    _16726++;
                    continue;
                }
            }
            float _12088 = nfruFitStep[3];
            float _12090 = nfruFitStep[4];
            float _12092 = nfruFitStep[5];
            float3 _12095 = _12221 - (float3(_12088, _12090, _12092) * (1.0f / _12018));
            float _16712;
            _16712 = 0.0f;
            float _17274;
            for (uint _16711 = 0u; _16711 < 3u; _16712 = _17274, _16711++)
            {
                uint _12104 = (gl_LocalInvocationIndex * 3u) + _16711;
                if (nfruFitW[_12104] > 0.0f)
                {
                    uint _12810 = _12104 * 3u;
                    uint _12815 = _12810 + 1u;
                    uint _12820 = _12810 + 2u;
                    float3 _12829 = float3(((_11442[0] * nfruFitX[_12810]) + (_11442[1] * nfruFitX[_12815])) + (_11442[2] * nfruFitX[_12820]), ((_11442[3] * nfruFitX[_12810]) + (_11442[4] * nfruFitX[_12815])) + (_11442[5] * nfruFitX[_12820]), ((_11442[6] * nfruFitX[_12810]) + (_11442[7] * nfruFitX[_12815])) + (_11442[8] * nfruFitX[_12820])) + _12095;
                    uint _12841 = _12104 * 2u;
                    float2 _12852 = ((_12829.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_12829.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_12841], nfruFitT[_12841 + 1u])) * _2713;
                    _17274 = _16712 + (nfruFitW[_12104] * dot(_12852, _12852));
                }
                else
                {
                    _17274 = _16712;
                }
            }
            nfruFitRed[gl_LocalInvocationIndex] = _16712;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _12141;
            if (_2882)
            {
                _12141 = nfruFitStat[1] < 0.5f;
            }
            else
            {
                _12141 = _2882;
            }
            if (_12141)
            {
                float _16714;
                _16714 = 0.0f;
                for (uint _16713 = 0u; _16713 < 256u; )
                {
                    _16714 += nfruFitRed[_16713];
                    _16713++;
                    continue;
                }
                bool _12160 = _16714 < nfruFitStat[0];
                bool _12166;
                if (_12160)
                {
                    _12166 = !isnan(_16714);
                }
                else
                {
                    _12166 = _12160;
                }
                if (_12166)
                {
                    for (uint _16715 = 0u; _16715 < 9u; )
                    {
                        nfruFitR[_16715] = _11442[_16715];
                        _16715++;
                        continue;
                    }
                    nfruFitTr[0] = _12095.x;
                    nfruFitTr[1] = _12095.y;
                    nfruFitTr[2] = _12095.z;
                    nfruFitStat[1] = 1.0f;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
        }
        float _12918[9];
        float _12996[9];
        for (uint _16525 = 0u; _16525 < 5u; _16525++)
        {
            for (uint _16604 = 0u; _16604 < 9u; )
            {
                _12918[_16604] = nfruFitR[_16604];
                _16604++;
                continue;
            }
            float _13770 = nfruFitTr[0];
            float _13772 = nfruFitTr[1];
            float _13774 = nfruFitTr[2];
            float3 _13775 = float3(_13770, _13772, _13774);
            float _13013[9] = _12918;
            float _12916[9] = _13013;
            for (uint _16605 = 0u; _16605 < 3u; _16605++)
            {
                uint _13023 = (gl_LocalInvocationIndex * 3u) + _16605;
                uint _13779 = _13023 * 3u;
                uint _13780 = _13779 + 2u;
                float _16707;
                if (nfruFitX[_13780] > 0.0f)
                {
                    uint _13798 = _13779 + 1u;
                    float3 _13812 = float3(((_13013[0] * nfruFitX[_13779]) + (_13013[1] * nfruFitX[_13798])) + (_13013[2] * nfruFitX[_13780]), ((_13013[3] * nfruFitX[_13779]) + (_13013[4] * nfruFitX[_13798])) + (_13013[5] * nfruFitX[_13780]), ((_13013[6] * nfruFitX[_13779]) + (_13013[7] * nfruFitX[_13798])) + (_13013[8] * nfruFitX[_13780])) + _13775;
                    uint _13824 = _13023 * 2u;
                    _16707 = length(((_13812.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_13812.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_13824], nfruFitT[_13824 + 1u])) * _2713);
                }
                else
                {
                    _16707 = 1000000000.0f;
                }
                nfruFitRes[_13023] = _16707;
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2882)
            {
                float _16607;
                float _16608;
                _16608 = 0.0f;
                _16607 = 0.0f;
                float _17225;
                float _17227;
                for (uint _16606 = 0u; _16606 < 768u; _16608 = _17227, _16607 = _17225, _16606++)
                {
                    if (nfruFitX[(_16606 * 3u) + 2u] > 0.0f)
                    {
                        float _17226;
                        if (nfruFitRes[_16606] < 4.0f)
                        {
                            _17226 = _16607 + 1.0f;
                        }
                        else
                        {
                            _17226 = _16607;
                        }
                        _17227 = _16608 + 1.0f;
                        _17225 = _17226;
                    }
                    else
                    {
                        _17227 = _16608;
                        _17225 = _16607;
                    }
                }
                nfruFitStat[2] = float(_16607 >= (0.25f * _16608));
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            bool _13086 = nfruFitStat[2] > 0.5f;
            float _16610;
            _16610 = 0.0f;
            float _13135;
            for (uint _16609 = 0u; _16609 < 3u; _16610 = _13135, _16609++)
            {
                uint _13095 = (gl_LocalInvocationIndex * 3u) + _16609;
                bool _13914 = nfruFitX[(_13095 * 3u) + 2u] > 0.0f;
                bool _13112;
                if (_13914)
                {
                    bool _13109;
                    if (_13086)
                    {
                        _13109 = nfruFitRes[_13095] >= 4.0f;
                    }
                    else
                    {
                        _13109 = _13086;
                    }
                    _13112 = !_13109;
                }
                else
                {
                    _13112 = _13914;
                }
                float _16694;
                if (_13112)
                {
                    float _16693;
                    if (nfruFitRes[_13095] < 1.0f)
                    {
                        _16693 = 1.0f;
                    }
                    else
                    {
                        _16693 = 1.0f / max(nfruFitRes[_13095], 9.9999999747524270787835121154785e-07f);
                    }
                    _16694 = _16693;
                }
                else
                {
                    _16694 = 0.0f;
                }
                nfruFitW[_13095] = _16694;
                _13135 = _16610 + ((_16694 * nfruFitRes[_13095]) * nfruFitRes[_13095]);
            }
            nfruFitRed[gl_LocalInvocationIndex] = _16610;
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_3821)
            {
                bool _13148 = gl_LocalInvocationIndex < 21u;
                uint _16616;
                uint _16619;
                if (_13148)
                {
                    uint _16611;
                    uint _16613;
                    _16613 = 0u;
                    _16611 = gl_LocalInvocationIndex;
                    for (uint _16612 = 6u; _16611 >= _16612; )
                    {
                        uint _13159 = _16611 - _16612;
                        _16613++;
                        _16612--;
                        _16611 = _13159;
                        continue;
                    }
                    _16619 = _16613 + _16611;
                    _16616 = _16613;
                }
                else
                {
                    _16619 = 0u;
                    _16616 = gl_LocalInvocationIndex - 21u;
                }
                float _16617;
                _16617 = 0.0f;
                float _17233;
                for (uint _16614 = 0u; _16614 < 768u; _16617 = _17233, _16614++)
                {
                    if (nfruFitW[_16614] <= 0.0f)
                    {
                        _17233 = _16617;
                        continue;
                    }
                    uint _13925 = _16614 * 3u;
                    uint _13930 = _13925 + 1u;
                    uint _13935 = _13925 + 2u;
                    float3 _14021 = float3(((_13013[0] * nfruFitX[_13925]) + (_13013[1] * nfruFitX[_13930])) + (_13013[2] * nfruFitX[_13935]), ((_13013[3] * nfruFitX[_13925]) + (_13013[4] * nfruFitX[_13930])) + (_13013[5] * nfruFitX[_13935]), ((_13013[6] * nfruFitX[_13925]) + (_13013[7] * nfruFitX[_13930])) + (_13013[8] * nfruFitX[_13935]));
                    float3 _13944 = _14021 + _13775;
                    float _13950 = max(_13944.z, 9.9999999747524270787835121154785e-07f);
                    uint _13956 = _16614 * 2u;
                    float _14045 = 1.0f / _13950;
                    float3 _14063 = float3(_14045 / cbFI_DeviceToViewDepth.z, 0.0f, (((-_13944.x) * _14045) * _14045) / cbFI_DeviceToViewDepth.z) * _2713.x;
                    float3 _14081 = float3(0.0f, _14045 / cbFI_DeviceToViewDepth.w, (((-_13944.y) * _14045) * _14045) / cbFI_DeviceToViewDepth.w) * _2713.y;
                    float3 _16684;
                    if (_16616 < 3u)
                    {
                        _16684 = cross(float3(float(_16616 == 0u), float(_16616 == 1u), float(_16616 == 2u)), _14021);
                    }
                    else
                    {
                        _16684 = float3(float(_16616 == 3u), float(_16616 == 4u), float(_16616 == 5u));
                    }
                    float2 _14116 = float2(dot(_14063, _16684), dot(_14081, _16684));
                    float _17234;
                    if (_13148)
                    {
                        float3 _16687;
                        if (_16619 < 3u)
                        {
                            _16687 = cross(float3(float(_16619 == 0u), float(_16619 == 1u), float(_16619 == 2u)), _14021);
                        }
                        else
                        {
                            _16687 = float3(float(_16619 == 3u), float(_16619 == 4u), float(_16619 == 5u));
                        }
                        _17234 = _16617 + (nfruFitW[_16614] * dot(_14116, float2(dot(_14063, _16687), dot(_14081, _16687))));
                    }
                    else
                    {
                        _17234 = _16617 + (nfruFitW[_16614] * dot(_14116, ((_13944.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * _13950)) - float2(nfruFitT[_13956], nfruFitT[_13956 + 1u])) * _2713));
                    }
                    _17233 = _17234;
                }
                if (_13148)
                {
                    nfruFitA[(_16616 * 7u) + _16619] = _16617;
                    nfruFitA[(_16619 * 7u) + _16616] = _16617;
                }
                else
                {
                    nfruFitA[(_16616 * 7u) + 6u] = _16617;
                }
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            if (_2882)
            {
                float _16621;
                _16621 = 0.0f;
                for (uint _16620 = 0u; _16620 < 256u; )
                {
                    _16621 += nfruFitRed[_16620];
                    _16620++;
                    continue;
                }
                nfruFitStat[0] = _16621;
                float _16683;
                _16683 = 0.0f;
                for (uint _16622 = 0u; _16622 < 6u; )
                {
                    _16683 += nfruFitA[(_16622 * 7u) + _16622];
                    _16622++;
                    continue;
                }
                for (uint _16623 = 0u; _16623 < 6u; )
                {
                    uint _13292 = (_16623 * 7u) + _16623;
                    nfruFitA[_13292] += ((9.999999717180685365747194737196e-10f * _16683) + 1.0000000031710768509710513471353e-30f);
                    _16623++;
                    continue;
                }
                for (uint _16624 = 0u; _16624 < 6u; _16624++)
                {
                    uint _13357 = _16624 * 7u;
                    uint _13359 = _13357 + _16624;
                    float _13362 = abs(nfruFitA[_13359]);
                    uint _13364 = _16624 + 1u;
                    uint _16667;
                    _16667 = _16624;
                    uint _17336;
                    float _17273;
                    uint _16666 = _13364;
                    float _16680 = _13362;
                    for (; _16666 < 6u; _16680 = _17273, _16667 = _17336, _16666++)
                    {
                        uint _13373 = (_16666 * 7u) + _16624;
                        bool _13378 = abs(nfruFitA[_13373]) > _16680;
                        if (_13378)
                        {
                            _17273 = abs(nfruFitA[_13373]);
                        }
                        else
                        {
                            _17273 = _16680;
                        }
                        _17336 = _13378 ? _16666 : _16667;
                    }
                    if (_16667 != _16624)
                    {
                        for (uint _16669 = 0u; _16669 < 7u; )
                        {
                            uint _13405 = _13357 + _16669;
                            float _13407 = nfruFitA[_13405];
                            uint _13415 = (_16667 * 7u) + _16669;
                            nfruFitA[_13405] = nfruFitA[_13415];
                            nfruFitA[_13415] = _13407;
                            _16669++;
                            continue;
                        }
                    }
                    float _16672;
                    if (abs(nfruFitA[_13359]) > 1.0000000031710768509710513471353e-30f)
                    {
                        _16672 = nfruFitA[_13359];
                    }
                    else
                    {
                        _16672 = 1.0000000031710768509710513471353e-30f;
                    }
                    for (uint _16674 = _13364; _16674 < 6u; _16674++)
                    {
                        uint _13456 = _16674 * 7u;
                        float _13462 = nfruFitA[_13456 + _16624] / _16672;
                        for (uint _16676 = _16624; _16676 < 7u; )
                        {
                            uint _13472 = _13456 + _16676;
                            nfruFitA[_13472] -= (_13462 * nfruFitA[_13357 + _16676]);
                            _16676++;
                            continue;
                        }
                    }
                }
                for (int _16625 = 5; _16625 >= 0; _16625--)
                {
                    uint _13503 = uint(_16625);
                    uint _13504 = _13503 * 7u;
                    uint _13510 = _13503 + 1u;
                    float _16665;
                    _16665 = nfruFitA[_13504 + 6u];
                    for (uint _16663 = _13510; _16663 < 6u; )
                    {
                        _16665 -= (nfruFitA[_13504 + _16663] * nfruFitStep[_16663]);
                        _16663++;
                        continue;
                    }
                    uint _13538 = _13504 + _13503;
                    nfruFitStep[_13503] = _16665 / ((abs(nfruFitA[_13538]) > 1.0000000031710768509710513471353e-30f) ? nfruFitA[_13538] : 1.0000000031710768509710513471353e-30f);
                }
                nfruFitStat[1] = 0.0f;
            }
            AllMemoryBarrier();
            GroupMemoryBarrierWithGroupSync();
            for (uint _16626 = 0u; _16626 < 5u; _16626++)
            {
                uint _13571 = 1u << _16626;
                float _13572 = float(_13571);
                float3 _13583 = float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]) * ((-1.0f) / _13572);
                float _14228 = length(_13583);
                float3 _16644;
                if (_14228 > 9.9999999600419720025001879548654e-13f)
                {
                    _16644 = _13583 / _14228.xxx;
                }
                else
                {
                    _16644 = float3(1.0f, 0.0f, 0.0f);
                }
                float _14240 = sin(_14228);
                float _14243 = 1.0f - cos(_14228);
                float _14255 = -_14240;
                float _14262 = _14243 * _16644.x;
                float _14265 = _14262 * _16644.y;
                float _14278 = _14262 * _16644.z;
                float _14315 = (_14243 * _16644.y) * _16644.z;
                float _14804[9] = { 1.0f + (_14243 * ((_16644.x * _16644.x) - 1.0f)), (_14255 * _16644.z) + _14265, (_14240 * _16644.y) + _14278, (_14240 * _16644.z) + _14265, 1.0f + (_14243 * ((_16644.y * _16644.y) - 1.0f)), (_14255 * _16644.x) + _14315, (_14255 * _16644.y) + _14278, (_14240 * _16644.x) + _14315, 1.0f + (_14243 * ((_16644.z * _16644.z) - 1.0f)) };
                float _12991[9] = _14804;
                uint _16645;
                _16645 = 0u;
                for (; _16645 < 3u; _16645++)
                {
                    for (uint _16661 = 0u; _16661 < 3u; )
                    {
                        uint _13597 = _16645 * 3u;
                        _12996[_13597 + _16661] = ((_12991[_13597] * _12916[_16661]) + (_12991[_13597 + 1u] * _12916[3u + _16661])) + (_12991[_13597 + 2u] * _12916[6u + _16661]);
                        _16661++;
                        continue;
                    }
                }
                float _13642 = nfruFitStep[3];
                float _13644 = nfruFitStep[4];
                float _13646 = nfruFitStep[5];
                float3 _13649 = _13775 - (float3(_13642, _13644, _13646) * (1.0f / _13572));
                float _16647;
                _16647 = 0.0f;
                float _17268;
                for (uint _16646 = 0u; _16646 < 3u; _16647 = _17268, _16646++)
                {
                    uint _13658 = (gl_LocalInvocationIndex * 3u) + _16646;
                    if (nfruFitW[_13658] > 0.0f)
                    {
                        uint _14364 = _13658 * 3u;
                        uint _14369 = _14364 + 1u;
                        uint _14374 = _14364 + 2u;
                        float3 _14383 = float3(((_12996[0] * nfruFitX[_14364]) + (_12996[1] * nfruFitX[_14369])) + (_12996[2] * nfruFitX[_14374]), ((_12996[3] * nfruFitX[_14364]) + (_12996[4] * nfruFitX[_14369])) + (_12996[5] * nfruFitX[_14374]), ((_12996[6] * nfruFitX[_14364]) + (_12996[7] * nfruFitX[_14369])) + (_12996[8] * nfruFitX[_14374])) + _13649;
                        uint _14395 = _13658 * 2u;
                        float2 _14406 = ((_14383.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_14383.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_14395], nfruFitT[_14395 + 1u])) * _2713;
                        _17268 = _16647 + (nfruFitW[_13658] * dot(_14406, _14406));
                    }
                    else
                    {
                        _17268 = _16647;
                    }
                }
                nfruFitRed[gl_LocalInvocationIndex] = _16647;
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
                bool _13695;
                if (_2882)
                {
                    _13695 = nfruFitStat[1] < 0.5f;
                }
                else
                {
                    _13695 = _2882;
                }
                if (_13695)
                {
                    float _16649;
                    _16649 = 0.0f;
                    for (uint _16648 = 0u; _16648 < 256u; )
                    {
                        _16649 += nfruFitRed[_16648];
                        _16648++;
                        continue;
                    }
                    bool _13714 = _16649 < nfruFitStat[0];
                    bool _13720;
                    if (_13714)
                    {
                        _13720 = !isnan(_16649);
                    }
                    else
                    {
                        _13720 = _13714;
                    }
                    if (_13720)
                    {
                        for (uint _16650 = 0u; _16650 < 9u; )
                        {
                            nfruFitR[_16650] = _12996[_16650];
                            _16650++;
                            continue;
                        }
                        nfruFitTr[0] = _13649.x;
                        nfruFitTr[1] = _13649.y;
                        nfruFitTr[2] = _13649.z;
                        nfruFitStat[1] = 1.0f;
                    }
                }
                AllMemoryBarrier();
                GroupMemoryBarrierWithGroupSync();
            }
        }
        float _2659[9];
        for (uint _16526 = 0u; _16526 < 9u; )
        {
            _2659[_16526] = nfruFitR[_16526];
            _16526++;
            continue;
        }
        float3 _14492 = float3(nfruFitTr[0], nfruFitTr[1], nfruFitTr[2]);
        for (uint _16527 = 0u; _16527 < 3u; _16527++)
        {
            uint _3018 = (gl_LocalInvocationIndex * 3u) + _16527;
            uint _14496 = _3018 * 3u;
            uint _14497 = _14496 + 2u;
            float _16602;
            if (nfruFitX[_14497] > 0.0f)
            {
                uint _14515 = _14496 + 1u;
                float3 _14529 = float3(((_2659[0] * nfruFitX[_14496]) + (_2659[1] * nfruFitX[_14515])) + (_2659[2] * nfruFitX[_14497]), ((_2659[3] * nfruFitX[_14496]) + (_2659[4] * nfruFitX[_14515])) + (_2659[5] * nfruFitX[_14497]), ((_2659[6] * nfruFitX[_14496]) + (_2659[7] * nfruFitX[_14515])) + (_2659[8] * nfruFitX[_14497])) + _14492;
                uint _14541 = _3018 * 2u;
                _16602 = length(((_14529.xy / (float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w) * max(_14529.z, 9.9999999747524270787835121154785e-07f))) - float2(nfruFitT[_14541], nfruFitT[_14541 + 1u])) * _2713);
            }
            else
            {
                _16602 = 1000000000.0f;
            }
            nfruFitRes[_3018] = _16602;
        }
        AllMemoryBarrier();
        GroupMemoryBarrierWithGroupSync();
        if (_2882)
        {
            float _16529;
            float _16530;
            float _16550;
            _16550 = 0.0f;
            _16530 = 0.0f;
            _16529 = 0.0f;
            float _17192;
            float _17193;
            float _17195;
            for (uint _16528 = 0u; _16528 < 768u; _16550 = _17195, _16530 = _17193, _16529 = _17192, _16528++)
            {
                if (nfruFitX[(_16528 * 3u) + 2u] > 0.0f)
                {
                    _17195 = _16550 + 1.0f;
                }
                else
                {
                    _17195 = _16550;
                }
                if (nfruFitRes[_16528] < 2.0f)
                {
                    _17193 = _16530 + nfruFitRes[_16528];
                    _17192 = _16529 + 1.0f;
                }
                else
                {
                    _17193 = _16530;
                    _17192 = _16529;
                }
            }
            float _16531;
            if (_16529 > 0.0f)
            {
                _16531 = _16530 / _16529;
            }
            else
            {
                _16531 = 1000000000.0f;
            }
            float _2679[16];
            float _2680[16];
            float _2681[16];
            float _2682[16];
            for (uint _16532 = 0u; _16532 < 16u; )
            {
                _2679[_16532] = 0.0f;
                _2680[_16532] = 0.0f;
                _2681[_16532] = 0.0f;
                _2682[_16532] = 0.0f;
                _16532++;
                continue;
            }
            uint _16533;
            _16533 = 0u;
            for (; _16533 < 3u; _16533++)
            {
                for (uint _16596 = 0u; _16596 < 3u; )
                {
                    uint _3109 = (_16533 * 4u) + _16596;
                    _2679[_3109] = nfruFitR[(_16533 * 3u) + _16596];
                    _2680[_3109] = nfruFitR[(_16596 * 3u) + _16533];
                    _16596++;
                    continue;
                }
            }
            _2679[3] = nfruFitTr[0];
            _2679[7] = nfruFitTr[1];
            _2679[11] = nfruFitTr[2];
            _2679[15] = 1.0f;
            for (uint _16534 = 0u; _16534 < 3u; )
            {
                _2680[(_16534 * 4u) + 3u] = -(((nfruFitR[_16534] * nfruFitTr[0]) + (nfruFitR[3u + _16534] * nfruFitTr[1])) + (nfruFitR[6u + _16534] * nfruFitTr[2]));
                _16534++;
                continue;
            }
            _2680[15] = 1.0f;
            _2681[0] = 1.0f / cbFI_DeviceToViewDepth.z;
            _2681[5] = 1.0f / cbFI_DeviceToViewDepth.w;
            _2681[10] = cbFI_DeviceToViewDepth.x;
            _2681[11] = cbFI_DeviceToViewDepth.y;
            _2681[14] = 1.0f;
            _2682[0] = cbFI_DeviceToViewDepth.z;
            _2682[5] = cbFI_DeviceToViewDepth.w;
            _2682[11] = 1.0f;
            _2682[14] = 1.0f / cbFI_DeviceToViewDepth.y;
            _2682[15] = (-cbFI_DeviceToViewDepth.x) / cbFI_DeviceToViewDepth.y;
            uint _16535;
            _16535 = 0u;
            float _2690[16];
            for (; _16535 < 4u; _16535++)
            {
                uint _16590;
                _16590 = 0u;
                for (; _16590 < 4u; _16590++)
                {
                    float _16595;
                    _16595 = 0.0f;
                    for (uint _16592 = 0u; _16592 < 4u; )
                    {
                        _16595 += (_2679[(_16535 * 4u) + _16592] * _2682[(_16592 * 4u) + _16590]);
                        _16592++;
                        continue;
                    }
                    _2690[(_16535 * 4u) + _16590] = _16595;
                }
            }
            uint _16536;
            _16536 = 0u;
            float _2695[16];
            for (; _16536 < 4u; _16536++)
            {
                uint _16584;
                _16584 = 0u;
                for (; _16584 < 4u; _16584++)
                {
                    float _16589;
                    _16589 = 0.0f;
                    for (uint _16586 = 0u; _16586 < 4u; )
                    {
                        _16589 += (_2681[(_16536 * 4u) + _16586] * _2690[(_16586 * 4u) + _16584]);
                        _16586++;
                        continue;
                    }
                    _2695[(_16536 * 4u) + _16584] = _16589;
                }
            }
            uint _16537;
            _16537 = 0u;
            for (; _16537 < 4u; _16537++)
            {
                uint _16578;
                _16578 = 0u;
                for (; _16578 < 4u; _16578++)
                {
                    float _16583;
                    _16583 = 0.0f;
                    for (uint _16580 = 0u; _16580 < 4u; )
                    {
                        _16583 += (_2680[(_16537 * 4u) + _16580] * _2682[(_16580 * 4u) + _16578]);
                        _16580++;
                        continue;
                    }
                    _2690[(_16537 * 4u) + _16578] = _16583;
                }
            }
            uint _16538;
            _16538 = 0u;
            float _2704[16];
            for (; _16538 < 4u; _16538++)
            {
                uint _16572;
                _16572 = 0u;
                for (; _16572 < 4u; _16572++)
                {
                    float _16577;
                    _16577 = 0.0f;
                    for (uint _16574 = 0u; _16574 < 4u; )
                    {
                        _16577 += (_2681[(_16538 * 4u) + _16574] * _2690[(_16574 * 4u) + _16572]);
                        _16574++;
                        continue;
                    }
                    _2704[(_16538 * 4u) + _16572] = _16577;
                }
            }
            uint _14632 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
            bool _16540;
            _16540 = true;
            bool _16564;
            for (uint _16539 = 0u; _16539 < 4u; _16540 = _16564, _16539++)
            {
                _16564 = _16540;
                bool _3487;
                for (uint _16562 = 0u; _16562 < 4u; _16564 = _3487, _16562++)
                {
                    uint _3416 = _16539 * 4u;
                    uint _3423 = (_16562 * 4u) + _16539;
                    rw_nfru_diagnostics.Store<uint>(((_14632 + _3416) + _16562) * 4 + 0, asuint(_2695[_3423]));
                    rw_nfru_diagnostics.Store<uint>((((_14632 + 16u) + _3416) + _16562) * 4 + 0, asuint(_2704[_3423]));
                    bool _3454;
                    if (_16564)
                    {
                        _3454 = !isnan(_2695[_3423]);
                    }
                    else
                    {
                        _3454 = _16564;
                    }
                    bool _3465;
                    if (_3454)
                    {
                        _3465 = !isinf(_2695[_3423]);
                    }
                    else
                    {
                        _3465 = _3454;
                    }
                    bool _3476;
                    if (_3465)
                    {
                        _3476 = !isnan(_2704[_3423]);
                    }
                    else
                    {
                        _3476 = _3465;
                    }
                    if (_3476)
                    {
                        _3487 = !isinf(_2704[_3423]);
                    }
                    else
                    {
                        _3487 = _3476;
                    }
                }
            }
            bool _3499 = _16540 && (_16550 > 250.0f);
            bool _3506;
            if (_3499)
            {
                _3506 = _16529 > (0.4000000059604644775390625f * _16550);
            }
            else
            {
                _3506 = _3499;
            }
            rw_nfru_diagnostics.Store<uint>((_14632 + 32u) * 4 + 0, uint(_3506 && (_16531 < 1.0f)));
            rw_nfru_diagnostics.Store<uint>((_14632 + 33u) * 4 + 0, asuint(_16531));
            rw_nfru_diagnostics.Store<uint>((_14632 + 34u) * 4 + 0, uint(_16529));
            rw_nfru_diagnostics.Store<uint>((_14632 + 35u) * 4 + 0, uint(_16550));
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
