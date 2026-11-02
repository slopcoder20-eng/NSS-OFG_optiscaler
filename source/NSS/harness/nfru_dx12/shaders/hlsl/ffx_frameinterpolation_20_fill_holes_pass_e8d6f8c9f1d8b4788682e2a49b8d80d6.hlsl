static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static uint _8068;
static float2 _8114;

static const int2 _527[5] = { int2(0, 0), int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
static const int2 _1594[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1603[5] = { 2, 4, 7, 11, 16 };

cbuffer cbFI_t : register(b2, space0)
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

RWByteAddressBuffer rw_nfru_diagnostics : register(u7, space0);
Texture2D<float4> r_depth_tp1 : register(t5, space0);
Texture2D<uint4> r_warped_motion_qdata_tp1 : register(t0, space0);
Texture2D<float4> r_warped_filled_flow_tm1 : register(t6, space0);
Texture2D<float4> r_previous_interpolation_source : register(t3, space0);
SamplerState s_LinearClamp : register(s1001, space0);
Texture2D<float4> r_current_interpolation_source : register(t4, space0);
RWTexture2D<float2> rw_warped_filled_motion_tp1 : register(u1, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

static uint nfruHoleFlags;
static uint nfruCandidateFlags;
static float2 nfruWalkAvgMotion;

uint2 spvTextureSize(Texture2D<float4> Tex, uint Level, out uint Param)
{
    uint2 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, Param);
    return ret;
}

void comp_main()
{
    nfruHoleFlags = 0u;
    nfruCandidateFlags = 0u;
    int2 _1860 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1860.x >= cbFI_MvDepthLaneSize.x, _1860.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        nfruWalkAvgMotion = 1000000015047466219876688855040.0f.xx;
        uint _1927[9];
        _1927[0] = r_warped_motion_qdata_tp1.Load(int3(_1860, 0)).x;
        _1927[1] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(1, 0), 0)).x;
        _1927[2] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(0, 1), 0)).x;
        _1927[3] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(0, -1), 0)).x;
        _1927[4] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(-1, 0), 0)).x;
        _1927[5] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(-1, 1), 0)).x;
        _1927[6] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(1, 1), 0)).x;
        _1927[7] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(-1, -1), 0)).x;
        _1927[8] = r_warped_motion_qdata_tp1.Load(int3(_1860 + int2(1, -1), 0)).x;
        uint _7945;
        _7945 = _1927[0];
        uint _8659;
        for (int _7944 = 1; _7944 < 9; _7945 = _8659, _7944++)
        {
            _8659 = (_1927[_7944] > _7945) ? _1927[_7944] : _7945;
        }
        bool _2027 = _7945 == 0u;
        bool _2034;
        if (_2027)
        {
            _2034 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _2034 = _2027;
        }
        uint _7953;
        if (_2034)
        {
            uint _7947;
            _7947 = 4294967295u;
            uint _1942[8];
            uint _8515;
            for (int _7946 = 0; _7946 < 8; _7947 = _8515, _7946++)
            {
                _1942[_7946] = 0u;
                int _8506 = 0;
                for (;;)
                {
                    if (_8506 < 5)
                    {
                        int2 _2057 = _1860 + (_1594[_7946] * _1603[_8506].xx);
                        bool _2060 = any(bool2(_2057.x < int2(0, 0).x, _2057.y < int2(0, 0).y));
                        bool _2068;
                        if (!_2060)
                        {
                            _2068 = any(bool2(_2057.x >= cbFI_MvDepthLaneSize.x, _2057.y >= cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _2068 = _2060;
                        }
                        if (_2068)
                        {
                            _8515 = _7947;
                            break;
                        }
                        uint4 _2357 = r_warped_motion_qdata_tp1.Load(int3(_2057, 0));
                        uint _2358 = _2357.x;
                        if (_2358 != 0u)
                        {
                            _1942[_7946] = _2358;
                            _8515 = min(_7947, _2358);
                            break;
                        }
                        _8506++;
                        continue;
                    }
                    else
                    {
                        _8515 = _7947;
                        break;
                    }
                }
            }
            bool _2092 = _7947 != 4294967295u;
            if (_2092)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _2367;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _2367);
                }
            }
            bool _2105;
            if (_2092)
            {
                _2105 = (cbFI_NfruT2Flags & 131072u) != 0u;
            }
            else
            {
                _2105 = _2092;
            }
            if (_2105)
            {
                float _7951;
                float2 _7952;
                _7952 = 0.0f.xx;
                _7951 = 0.0f;
                float _8516;
                float2 _8517;
                for (int _7950 = 0; _7950 < 8; _7952 = _8517, _7951 = _8516, _7950++)
                {
                    bool _2115 = _1942[_7950] != 0u;
                    bool _2128;
                    if (_2115)
                    {
                        _2128 = ((_1942[_7950] >> 20u) & 2047u) <= (((_7947 >> 20u) & 2047u) + 55u);
                    }
                    else
                    {
                        _2128 = _2115;
                    }
                    if (_2128)
                    {
                        uint _2384 = _1942[_7950] & 2147483647u;
                        uint _2416 = uint(max((int((_2384 >> 16u) & 15u) - 6), 0));
                        _8517 = _7952 + (float2(float((1 - (2 * int((_2384 >> 15u) & 1u))) * int(((_2384 >> uint(7)) & 127u) << _2416)), float((1 - (2 * int((_2384 >> 14u) & 1u))) * int((_2384 & 127u) << _2416))) * 0.0624427758157253265380859375f);
                        _8516 = _7951 + 1.0f;
                    }
                    else
                    {
                        _8517 = _7952;
                        _8516 = _7951;
                    }
                }
                if (_7951 > 0.0f)
                {
                    nfruWalkAvgMotion = _7952 / _7951.xx;
                }
            }
            _7953 = _2092 ? _7947 : _7945;
        }
        else
        {
            _7953 = _7945;
        }
        nfruHoleFlags = 0u;
        bool _2155 = _1927[0] == 0u;
        bool _2157 = _7953 == 0u;
        int _2159 = _1860.x;
        bool _2160 = _2159 == 0;
        bool _2167;
        if (!_2160)
        {
            _2167 = _1860.y == 0;
        }
        else
        {
            _2167 = _2160;
        }
        bool _2177;
        if (!_2167)
        {
            _2177 = _2159 == (cbFI_MvDepthLaneSize.x - 1);
        }
        else
        {
            _2177 = _2167;
        }
        bool _2187;
        if (!_2177)
        {
            _2187 = _1860.y == (cbFI_MvDepthLaneSize.y - 1);
        }
        else
        {
            _2187 = _2177;
        }
        if (_2155)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2444;
                rw_nfru_diagnostics.InterlockedAdd(88, 1u, _2444);
            }
            nfruHoleFlags |= 16u;
        }
        if (_2157)
        {
            bool _2450 = (cbFI_pad0 & 512u) != 0u;
            if (_2450)
            {
                uint _2454;
                rw_nfru_diagnostics.InterlockedAdd(92, 1u, _2454);
            }
            nfruHoleFlags |= 32u;
            if (!_2187)
            {
                if (_2450)
                {
                    uint _2464;
                    rw_nfru_diagnostics.InterlockedAdd(96, 1u, _2464);
                }
            }
        }
        if (_2187)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2474;
                rw_nfru_diagnostics.InterlockedAdd(108, 1u, _2474);
            }
        }
        if (_2155 && (!_2157))
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2484;
                rw_nfru_diagnostics.InterlockedAdd(112, 1u, _2484);
            }
        }
        float2 _7975;
        if (nfruWalkAvgMotion.x < 100000001504746621987668885504.0f)
        {
            _7975 = nfruWalkAvgMotion;
        }
        else
        {
            uint _2501 = _7953 & 2147483647u;
            uint _2533 = uint(max((int((_2501 >> 16u) & 15u) - 6), 0));
            _7975 = float2(float((1 - (2 * int((_2501 >> 15u) & 1u))) * int(((_2501 >> uint(7)) & 127u) << _2533)), float((1 - (2 * int((_2501 >> 14u) & 1u))) * int((_2501 & 127u) << _2533))) * 0.0624427758157253265380859375f;
        }
        float2 _2228 = _7975 * cbFI_MvDepthLaneSizeRcp;
        bool _2231 = all(bool2(_2228.x == 0.0f.xx.x, _2228.y == 0.0f.xx.y));
        if (_2231)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2561;
                rw_nfru_diagnostics.InterlockedAdd(100, 1u, _2561);
            }
            nfruHoleFlags |= 64u;
        }
        float2 _2239 = float2(cbFI_DisplaySize);
        float _2241 = length(_2228 * _2239);
        if (_2241 <= 0.25f)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2575;
                rw_nfru_diagnostics.InterlockedAdd(104, 1u, _2575);
            }
        }
        uint _2720;
        float2 _2596 = (float2(_1860) + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        float2 _8437;
        uint _8438;
        do
        {
            nfruCandidateFlags = 0u;
            _2720 = cbFI_pad0;
            bool _2722 = (_2720 & 536870912u) != 0u;
            bool _2728;
            if (_2722)
            {
                _2728 = (nfruHoleFlags & 32u) != 0u;
            }
            else
            {
                _2728 = _2722;
            }
            bool _2735;
            if (_2728)
            {
                _2735 = (cbFI_NfruT2Flags & 2u) == 0u;
            }
            else
            {
                _2735 = _2728;
            }
            if (_2735)
            {
                float _3299;
                float _3302;
                float _3311;
                float _3312;
                float _2740 = 1.0f - cbFI_Timestep;
                uint _8049;
                float2 _8097;
                float2 _8132;
                do
                {
                    float2 _7976;
                    bool _7977;
                    do
                    {
                        _3299 = _2596.x;
                        _3302 = 1.0f - _2596.y;
                        float2 _3308 = (float2(_3299, _3302) * 2.0f) - 1.0f.xx;
                        uint _3365_dummy_parameter;
                        _3311 = _3308.x;
                        _3312 = _3308.y;
                        float4 _3314 = mul(float4(_3311, _3312, r_depth_tp1.Load(int3(int2(floor(_2596 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3365_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _3316 = _3314.w;
                        bool _3317 = _3316 > 9.9999999747524270787835121154785e-07f;
                        if (!_3317)
                        {
                            _7977 = _3317;
                            _7976 = 0.0f.xx;
                            break;
                        }
                        float2 _3330 = ((_3314.xy / _3316.xx) + 1.0f.xx) * 0.5f;
                        float2 _3341 = float2(_3330.x - _3299, _3302 - _3330.y);
                        bool _3344 = any(isnan(_3341));
                        bool _3351;
                        if (!_3344)
                        {
                            _3351 = any(isinf(_3341));
                        }
                        else
                        {
                            _3351 = _3344;
                        }
                        bool _3352 = !_3351;
                        bool2 _3355 = _3352.xx;
                        _7977 = _3352;
                        _7976 = float2(_3355.x ? _3341.x : 0.0f.xx.x, _3355.y ? _3341.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7977)
                    {
                        _8132 = _7976;
                        _8097 = _8114;
                        _8049 = 3u;
                        break;
                    }
                    float2 _7979;
                    float2 _8134;
                    _7979 = _2596 - (_7976 * _2740);
                    _8134 = _7976;
                    float2 _3243;
                    float2 _7980;
                    bool _8024;
                    float2 _8040;
                    uint _8050;
                    float2 _8133;
                    int _7978 = 0;
                    for (;;)
                    {
                        if (_7978 < 8)
                        {
                            float _3390;
                            float _3392;
                            float2 _3127 = clamp(_7979, (-1.0f).xx, 2.0f.xx);
                            bool _7981;
                            do
                            {
                                _3390 = _3127.x;
                                _3392 = _3127.y;
                                float _3393 = 1.0f - _3392;
                                uint _3456_dummy_parameter;
                                float4 _3405 = mul(float4((float2(_3390, _3393) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3127 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3456_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3407 = _3405.w;
                                bool _3408 = _3407 > 9.9999999747524270787835121154785e-07f;
                                if (!_3408)
                                {
                                    _7981 = _3408;
                                    _7980 = 0.0f.xx;
                                    break;
                                }
                                float2 _3421 = ((_3405.xy / _3407.xx) + 1.0f.xx) * 0.5f;
                                float2 _3432 = float2(_3421.x - _3390, _3393 - _3421.y);
                                bool _3435 = any(isnan(_3432));
                                bool _3442;
                                if (!_3435)
                                {
                                    _3442 = any(isinf(_3432));
                                }
                                else
                                {
                                    _3442 = _3435;
                                }
                                bool _3443 = !_3442;
                                bool2 _3446 = _3443.xx;
                                _7981 = _3443;
                                _7980 = float2(_3446.x ? _3432.x : 0.0f.xx.x, _3446.y ? _3432.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3477;
                            float _3479;
                            float2 _3136 = _3127 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _7984;
                            bool _7985;
                            do
                            {
                                _3477 = _3136.x;
                                _3479 = _3136.y;
                                float _3480 = 1.0f - _3479;
                                uint _3543_dummy_parameter;
                                float4 _3492 = mul(float4((float2(_3477, _3480) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3136 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3543_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3494 = _3492.w;
                                bool _3495 = _3494 > 9.9999999747524270787835121154785e-07f;
                                if (!_3495)
                                {
                                    _7985 = _3495;
                                    _7984 = 0.0f.xx;
                                    break;
                                }
                                float2 _3508 = ((_3492.xy / _3494.xx) + 1.0f.xx) * 0.5f;
                                float2 _3519 = float2(_3508.x - _3477, _3480 - _3508.y);
                                bool _3522 = any(isnan(_3519));
                                bool _3529;
                                if (!_3522)
                                {
                                    _3529 = any(isinf(_3519));
                                }
                                else
                                {
                                    _3529 = _3522;
                                }
                                bool _3530 = !_3529;
                                bool2 _3533 = _3530.xx;
                                _7985 = _3530;
                                _7984 = float2(_3533.x ? _3519.x : 0.0f.xx.x, _3533.y ? _3519.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3564;
                            float _3566;
                            float2 _3144 = _3127 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _7988;
                            bool _7989;
                            do
                            {
                                _3564 = _3144.x;
                                _3566 = _3144.y;
                                float _3567 = 1.0f - _3566;
                                uint _3630_dummy_parameter;
                                float4 _3579 = mul(float4((float2(_3564, _3567) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3144 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3630_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3581 = _3579.w;
                                bool _3582 = _3581 > 9.9999999747524270787835121154785e-07f;
                                if (!_3582)
                                {
                                    _7989 = _3582;
                                    _7988 = 0.0f.xx;
                                    break;
                                }
                                float2 _3595 = ((_3579.xy / _3581.xx) + 1.0f.xx) * 0.5f;
                                float2 _3606 = float2(_3595.x - _3564, _3567 - _3595.y);
                                bool _3609 = any(isnan(_3606));
                                bool _3616;
                                if (!_3609)
                                {
                                    _3616 = any(isinf(_3606));
                                }
                                else
                                {
                                    _3616 = _3609;
                                }
                                bool _3617 = !_3616;
                                bool2 _3620 = _3617.xx;
                                _7989 = _3617;
                                _7988 = float2(_3620.x ? _3606.x : 0.0f.xx.x, _3620.y ? _3606.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_7981 && _7985) && _7989))
                            {
                                _8133 = _7980;
                                _8050 = 3u;
                                _8040 = _3127;
                                _8024 = true;
                                break;
                            }
                            float2 _3649 = _3127 + _7980;
                            bool _3678 = (_2720 & 1073741824u) != 0u;
                            float2 _8000;
                            if (_3678)
                            {
                                float _3691 = ((2.0f * _3649.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3703 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3715 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3739 = ((2.0f * _3390) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8000 = (float2(atan(_3691) / _3703, atan((((2.0f * _3649.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3691 * _3691))) / _3715) + 0.5f.xx) - (float2(atan(_3739) / _3703, atan((((2.0f * _3392) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3739 * _3739))) / _3715) + 0.5f.xx);
                            }
                            else
                            {
                                _8000 = _3649 - _3127;
                            }
                            float2 _8001;
                            if (_3678)
                            {
                                float _3815 = ((2.0f * _3390) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _3864 = clamp(((((float2(atan(_3815) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3392) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3815 * _3815))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8000 * _2740)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _3867 = tan(_3864.x);
                                _8001 = (float2(_3867 / cbFI_DeviceToViewDepth.z, (tan(_3864.y) * sqrt(1.0f + (_3867 * _3867))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8001 = _3127 + (_8000 * _2740);
                            }
                            float2 _3162 = _8001 - _2596;
                            if (length(_3162 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8133 = _7980;
                                _8050 = _8068;
                                _8040 = _3127;
                                _8024 = false;
                                break;
                            }
                            float2 _3909 = _3136 + _7984;
                            float2 _8004;
                            if (_3678)
                            {
                                float _3951 = ((2.0f * _3909.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3963 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3975 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3999 = ((2.0f * _3477) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8004 = (float2(atan(_3951) / _3963, atan((((2.0f * _3909.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3951 * _3951))) / _3975) + 0.5f.xx) - (float2(atan(_3999) / _3963, atan((((2.0f * _3479) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3999 * _3999))) / _3975) + 0.5f.xx);
                            }
                            else
                            {
                                _8004 = _3909 - _3136;
                            }
                            float2 _8005;
                            if (_3678)
                            {
                                float _4075 = ((2.0f * _3477) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4124 = clamp(((((float2(atan(_4075) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3479) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4075 * _4075))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8004 * _2740)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4127 = tan(_4124.x);
                                _8005 = (float2(_4127 / cbFI_DeviceToViewDepth.z, (tan(_4124.y) * sqrt(1.0f + (_4127 * _4127))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8005 = _3136 + (_8004 * _2740);
                            }
                            float2 _3184 = (_8005 - _8001) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _4165 = _3144 + _7988;
                            float2 _8008;
                            if (_3678)
                            {
                                float _4207 = ((2.0f * _4165.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _4219 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _4231 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4255 = ((2.0f * _3564) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8008 = (float2(atan(_4207) / _4219, atan((((2.0f * _4165.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4207 * _4207))) / _4231) + 0.5f.xx) - (float2(atan(_4255) / _4219, atan((((2.0f * _3566) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4255 * _4255))) / _4231) + 0.5f.xx);
                            }
                            else
                            {
                                _8008 = _4165 - _3144;
                            }
                            float2 _8009;
                            if (_3678)
                            {
                                float _4331 = ((2.0f * _3564) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4380 = clamp(((((float2(atan(_4331) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3566) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4331 * _4331))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8008 * _2740)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4383 = tan(_4380.x);
                                _8009 = (float2(_4383 / cbFI_DeviceToViewDepth.z, (tan(_4380.y) * sqrt(1.0f + (_4383 * _4383))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8009 = _3144 + (_8008 * _2740);
                            }
                            float2 _3198 = (_8009 - _8001) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _3200 = _3184.x;
                            float _3202 = _3198.y;
                            float _3205 = _3198.x;
                            float _3207 = _3184.y;
                            float _3209 = (_3200 * _3202) - (_3205 * _3207);
                            if (abs(_3209) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8133 = _7980;
                                _8050 = 3u;
                                _8040 = _3127;
                                _8024 = true;
                                break;
                            }
                            float _3218 = _3162.x;
                            float _3223 = _3162.y;
                            _3243 = _3127 - (float2((_3202 * _3218) - (_3205 * _3223), ((-_3207) * _3218) + (_3200 * _3223)) / _3209.xx);
                            _7979 = _3243;
                            _7978++;
                            _8134 = _7980;
                            continue;
                        }
                        else
                        {
                            _8133 = _8134;
                            _8050 = _8068;
                            _8040 = _7979;
                            _8024 = false;
                            break;
                        }
                    }
                    if (_8024)
                    {
                        _8132 = _8133;
                        _8097 = _8040;
                        _8049 = _8050;
                        break;
                    }
                    float _4423;
                    float _4425;
                    float2 _8041;
                    bool _8042;
                    do
                    {
                        _4423 = _8040.x;
                        _4425 = _8040.y;
                        float _4426 = 1.0f - _4425;
                        uint _4489_dummy_parameter;
                        float4 _4438 = mul(float4((float2(_4423, _4426) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_8040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4489_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _4440 = _4438.w;
                        bool _4441 = _4440 > 9.9999999747524270787835121154785e-07f;
                        if (!_4441)
                        {
                            _8042 = _4441;
                            _8041 = 0.0f.xx;
                            break;
                        }
                        float2 _4454 = ((_4438.xy / _4440.xx) + 1.0f.xx) * 0.5f;
                        float2 _4465 = float2(_4454.x - _4423, _4426 - _4454.y);
                        bool _4468 = any(isnan(_4465));
                        bool _4475;
                        if (!_4468)
                        {
                            _4475 = any(isinf(_4465));
                        }
                        else
                        {
                            _4475 = _4468;
                        }
                        bool _4476 = !_4475;
                        bool2 _4479 = _4476.xx;
                        _8042 = _4476;
                        _8041 = float2(_4479.x ? _4465.x : 0.0f.xx.x, _4479.y ? _4465.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8042)
                    {
                        _8132 = _8041;
                        _8097 = _8040;
                        _8049 = 3u;
                        break;
                    }
                    float2 _4508 = _8040 + _8041;
                    bool _4537 = (_2720 & 1073741824u) != 0u;
                    float2 _8045;
                    if (_4537)
                    {
                        float _4550 = ((2.0f * _4508.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4562 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4574 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4598 = ((2.0f * _4423) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8045 = (float2(atan(_4550) / _4562, atan((((2.0f * _4508.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4550 * _4550))) / _4574) + 0.5f.xx) - (float2(atan(_4598) / _4562, atan((((2.0f * _4425) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4598 * _4598))) / _4574) + 0.5f.xx);
                    }
                    else
                    {
                        _8045 = _4508 - _8040;
                    }
                    float2 _8046;
                    if (_4537)
                    {
                        float _4674 = ((2.0f * _4423) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _4723 = clamp(((((float2(atan(_4674) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4425) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4674 * _4674))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8045 * _2740)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _4726 = tan(_4723.x);
                        _8046 = (float2(_4726 / cbFI_DeviceToViewDepth.z, (tan(_4723.y) * sqrt(1.0f + (_4726 * _4726))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _8046 = _8040 + (_8045 * _2740);
                    }
                    if (length((_8046 - _2596) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8132 = _8041;
                        _8097 = _8040;
                        _8049 = 2u;
                        break;
                    }
                    bool _3275 = all(bool2(_8040.x > cbFI_MvDepthLaneSizeRcp.x, _8040.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _3284;
                    if (_3275)
                    {
                        float2 _3280 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _3284 = all(bool2(_8040.x < _3280.x, _8040.y < _3280.y));
                    }
                    else
                    {
                        _3284 = _3275;
                    }
                    _8132 = _8041;
                    _8097 = _8040;
                    _8049 = _3284 ? 0u : 1u;
                    break;
                } while(false);
                if (_8049 == 0u)
                {
                    if ((_2720 & 512u) != 0u)
                    {
                        uint _4771;
                        rw_nfru_diagnostics.InterlockedAdd(4, 1u, _4771);
                    }
                    float2 _2751 = _8097 + _8132;
                    float2 _8436;
                    if ((_2720 & 1073741824u) != 0u)
                    {
                        float _4809 = ((2.0f * _2751.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4821 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4833 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4857 = ((2.0f * _8097.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8436 = (float2(atan(_4809) / _4821, atan((((2.0f * _2751.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4809 * _4809))) / _4833) + 0.5f.xx) - (float2(atan(_4857) / _4821, atan((((2.0f * _8097.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4857 * _4857))) / _4833) + 0.5f.xx);
                    }
                    else
                    {
                        _8436 = _2751 - _8097;
                    }
                    _8438 = 2u;
                    _8437 = _8436;
                    break;
                }
                uint _8217;
                float2 _8286;
                float2 _8342;
                do
                {
                    float2 _8144;
                    bool _8145;
                    do
                    {
                        uint _5200_dummy_parameter;
                        float4 _5149 = mul(float4(_3311, _3312, r_depth_tp1.Load(int3(int2(floor(_2596 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5200_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _5151 = _5149.w;
                        bool _5152 = _5151 > 9.9999999747524270787835121154785e-07f;
                        if (!_5152)
                        {
                            _8145 = _5152;
                            _8144 = 0.0f.xx;
                            break;
                        }
                        float2 _5165 = ((_5149.xy / _5151.xx) + 1.0f.xx) * 0.5f;
                        float2 _5176 = float2(_5165.x - _3299, _3302 - _5165.y);
                        bool _5179 = any(isnan(_5176));
                        bool _5186;
                        if (!_5179)
                        {
                            _5186 = any(isinf(_5176));
                        }
                        else
                        {
                            _5186 = _5179;
                        }
                        bool _5187 = !_5186;
                        bool2 _5190 = _5187.xx;
                        _8145 = _5187;
                        _8144 = float2(_5190.x ? _5176.x : 0.0f.xx.x, _5190.y ? _5176.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8145)
                    {
                        _8342 = _8144;
                        _8286 = _8114;
                        _8217 = 3u;
                        break;
                    }
                    float2 _8147;
                    float2 _8344;
                    _8147 = _2596 - (_8144 * cbFI_Timestep);
                    _8344 = _8144;
                    float2 _5078;
                    float2 _8148;
                    bool _8192;
                    float2 _8208;
                    uint _8218;
                    float2 _8343;
                    int _8146 = 0;
                    for (;;)
                    {
                        if (_8146 < 8)
                        {
                            float _5225;
                            float _5227;
                            float2 _4962 = clamp(_8147, (-1.0f).xx, 2.0f.xx);
                            bool _8149;
                            do
                            {
                                _5225 = _4962.x;
                                _5227 = _4962.y;
                                float _5228 = 1.0f - _5227;
                                uint _5291_dummy_parameter;
                                float4 _5240 = mul(float4((float2(_5225, _5228) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4962 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5291_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5242 = _5240.w;
                                bool _5243 = _5242 > 9.9999999747524270787835121154785e-07f;
                                if (!_5243)
                                {
                                    _8149 = _5243;
                                    _8148 = 0.0f.xx;
                                    break;
                                }
                                float2 _5256 = ((_5240.xy / _5242.xx) + 1.0f.xx) * 0.5f;
                                float2 _5267 = float2(_5256.x - _5225, _5228 - _5256.y);
                                bool _5270 = any(isnan(_5267));
                                bool _5277;
                                if (!_5270)
                                {
                                    _5277 = any(isinf(_5267));
                                }
                                else
                                {
                                    _5277 = _5270;
                                }
                                bool _5278 = !_5277;
                                bool2 _5281 = _5278.xx;
                                _8149 = _5278;
                                _8148 = float2(_5281.x ? _5267.x : 0.0f.xx.x, _5281.y ? _5267.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5312;
                            float _5314;
                            float2 _4971 = _4962 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _8152;
                            bool _8153;
                            do
                            {
                                _5312 = _4971.x;
                                _5314 = _4971.y;
                                float _5315 = 1.0f - _5314;
                                uint _5378_dummy_parameter;
                                float4 _5327 = mul(float4((float2(_5312, _5315) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5378_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5329 = _5327.w;
                                bool _5330 = _5329 > 9.9999999747524270787835121154785e-07f;
                                if (!_5330)
                                {
                                    _8153 = _5330;
                                    _8152 = 0.0f.xx;
                                    break;
                                }
                                float2 _5343 = ((_5327.xy / _5329.xx) + 1.0f.xx) * 0.5f;
                                float2 _5354 = float2(_5343.x - _5312, _5315 - _5343.y);
                                bool _5357 = any(isnan(_5354));
                                bool _5364;
                                if (!_5357)
                                {
                                    _5364 = any(isinf(_5354));
                                }
                                else
                                {
                                    _5364 = _5357;
                                }
                                bool _5365 = !_5364;
                                bool2 _5368 = _5365.xx;
                                _8153 = _5365;
                                _8152 = float2(_5368.x ? _5354.x : 0.0f.xx.x, _5368.y ? _5354.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5399;
                            float _5401;
                            float2 _4979 = _4962 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _8156;
                            bool _8157;
                            do
                            {
                                _5399 = _4979.x;
                                _5401 = _4979.y;
                                float _5402 = 1.0f - _5401;
                                uint _5465_dummy_parameter;
                                float4 _5414 = mul(float4((float2(_5399, _5402) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4979 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5465_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5416 = _5414.w;
                                bool _5417 = _5416 > 9.9999999747524270787835121154785e-07f;
                                if (!_5417)
                                {
                                    _8157 = _5417;
                                    _8156 = 0.0f.xx;
                                    break;
                                }
                                float2 _5430 = ((_5414.xy / _5416.xx) + 1.0f.xx) * 0.5f;
                                float2 _5441 = float2(_5430.x - _5399, _5402 - _5430.y);
                                bool _5444 = any(isnan(_5441));
                                bool _5451;
                                if (!_5444)
                                {
                                    _5451 = any(isinf(_5441));
                                }
                                else
                                {
                                    _5451 = _5444;
                                }
                                bool _5452 = !_5451;
                                bool2 _5455 = _5452.xx;
                                _8157 = _5452;
                                _8156 = float2(_5455.x ? _5441.x : 0.0f.xx.x, _5455.y ? _5441.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_8149 && _8153) && _8157))
                            {
                                _8343 = _8148;
                                _8218 = 3u;
                                _8208 = _4962;
                                _8192 = true;
                                break;
                            }
                            float2 _5484 = _4962 + _8148;
                            bool _5513 = (_2720 & 1073741824u) != 0u;
                            float2 _8168;
                            if (_5513)
                            {
                                float _5526 = ((2.0f * _5484.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5538 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5550 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5574 = ((2.0f * _5225) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8168 = (float2(atan(_5526) / _5538, atan((((2.0f * _5484.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5526 * _5526))) / _5550) + 0.5f.xx) - (float2(atan(_5574) / _5538, atan((((2.0f * _5227) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5574 * _5574))) / _5550) + 0.5f.xx);
                            }
                            else
                            {
                                _8168 = _5484 - _4962;
                            }
                            float2 _8169;
                            if (_5513)
                            {
                                float _5650 = ((2.0f * _5225) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5699 = clamp(((((float2(atan(_5650) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5227) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5650 * _5650))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8168 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5702 = tan(_5699.x);
                                _8169 = (float2(_5702 / cbFI_DeviceToViewDepth.z, (tan(_5699.y) * sqrt(1.0f + (_5702 * _5702))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8169 = _4962 + (_8168 * cbFI_Timestep);
                            }
                            float2 _4997 = _8169 - _2596;
                            if (length(_4997 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8343 = _8148;
                                _8218 = _8068;
                                _8208 = _4962;
                                _8192 = false;
                                break;
                            }
                            float2 _5744 = _4971 + _8152;
                            float2 _8172;
                            if (_5513)
                            {
                                float _5786 = ((2.0f * _5744.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5798 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5810 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5834 = ((2.0f * _5312) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8172 = (float2(atan(_5786) / _5798, atan((((2.0f * _5744.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5786 * _5786))) / _5810) + 0.5f.xx) - (float2(atan(_5834) / _5798, atan((((2.0f * _5314) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5834 * _5834))) / _5810) + 0.5f.xx);
                            }
                            else
                            {
                                _8172 = _5744 - _4971;
                            }
                            float2 _8173;
                            if (_5513)
                            {
                                float _5910 = ((2.0f * _5312) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5959 = clamp(((((float2(atan(_5910) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5314) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5910 * _5910))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8172 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5962 = tan(_5959.x);
                                _8173 = (float2(_5962 / cbFI_DeviceToViewDepth.z, (tan(_5959.y) * sqrt(1.0f + (_5962 * _5962))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8173 = _4971 + (_8172 * cbFI_Timestep);
                            }
                            float2 _5019 = (_8173 - _8169) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _6000 = _4979 + _8156;
                            float2 _8176;
                            if (_5513)
                            {
                                float _6042 = ((2.0f * _6000.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _6054 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _6066 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _6090 = ((2.0f * _5399) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8176 = (float2(atan(_6042) / _6054, atan((((2.0f * _6000.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6042 * _6042))) / _6066) + 0.5f.xx) - (float2(atan(_6090) / _6054, atan((((2.0f * _5401) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6090 * _6090))) / _6066) + 0.5f.xx);
                            }
                            else
                            {
                                _8176 = _6000 - _4979;
                            }
                            float2 _8177;
                            if (_5513)
                            {
                                float _6166 = ((2.0f * _5399) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6215 = clamp(((((float2(atan(_6166) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5401) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6166 * _6166))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8176 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6218 = tan(_6215.x);
                                _8177 = (float2(_6218 / cbFI_DeviceToViewDepth.z, (tan(_6215.y) * sqrt(1.0f + (_6218 * _6218))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8177 = _4979 + (_8176 * cbFI_Timestep);
                            }
                            float2 _5033 = (_8177 - _8169) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _5035 = _5019.x;
                            float _5037 = _5033.y;
                            float _5040 = _5033.x;
                            float _5042 = _5019.y;
                            float _5044 = (_5035 * _5037) - (_5040 * _5042);
                            if (abs(_5044) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8343 = _8148;
                                _8218 = 3u;
                                _8208 = _4962;
                                _8192 = true;
                                break;
                            }
                            float _5053 = _4997.x;
                            float _5058 = _4997.y;
                            _5078 = _4962 - (float2((_5037 * _5053) - (_5040 * _5058), ((-_5042) * _5053) + (_5035 * _5058)) / _5044.xx);
                            _8147 = _5078;
                            _8146++;
                            _8344 = _8148;
                            continue;
                        }
                        else
                        {
                            _8343 = _8344;
                            _8218 = _8068;
                            _8208 = _8147;
                            _8192 = false;
                            break;
                        }
                    }
                    if (_8192)
                    {
                        _8342 = _8343;
                        _8286 = _8208;
                        _8217 = _8218;
                        break;
                    }
                    float _6258;
                    float _6260;
                    float2 _8209;
                    bool _8210;
                    do
                    {
                        _6258 = _8208.x;
                        _6260 = _8208.y;
                        float _6261 = 1.0f - _6260;
                        uint _6324_dummy_parameter;
                        float4 _6273 = mul(float4((float2(_6258, _6261) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_8208 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6324_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6275 = _6273.w;
                        bool _6276 = _6275 > 9.9999999747524270787835121154785e-07f;
                        if (!_6276)
                        {
                            _8210 = _6276;
                            _8209 = 0.0f.xx;
                            break;
                        }
                        float2 _6289 = ((_6273.xy / _6275.xx) + 1.0f.xx) * 0.5f;
                        float2 _6300 = float2(_6289.x - _6258, _6261 - _6289.y);
                        bool _6303 = any(isnan(_6300));
                        bool _6310;
                        if (!_6303)
                        {
                            _6310 = any(isinf(_6300));
                        }
                        else
                        {
                            _6310 = _6303;
                        }
                        bool _6311 = !_6310;
                        bool2 _6314 = _6311.xx;
                        _8210 = _6311;
                        _8209 = float2(_6314.x ? _6300.x : 0.0f.xx.x, _6314.y ? _6300.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8210)
                    {
                        _8342 = _8209;
                        _8286 = _8208;
                        _8217 = 3u;
                        break;
                    }
                    float2 _6343 = _8208 + _8209;
                    bool _6372 = (_2720 & 1073741824u) != 0u;
                    float2 _8213;
                    if (_6372)
                    {
                        float _6385 = ((2.0f * _6343.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6397 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6409 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6433 = ((2.0f * _6258) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8213 = (float2(atan(_6385) / _6397, atan((((2.0f * _6343.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6385 * _6385))) / _6409) + 0.5f.xx) - (float2(atan(_6433) / _6397, atan((((2.0f * _6260) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6433 * _6433))) / _6409) + 0.5f.xx);
                    }
                    else
                    {
                        _8213 = _6343 - _8208;
                    }
                    float2 _8214;
                    if (_6372)
                    {
                        float _6509 = ((2.0f * _6258) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _6558 = clamp(((((float2(atan(_6509) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _6260) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6509 * _6509))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8213 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6561 = tan(_6558.x);
                        _8214 = (float2(_6561 / cbFI_DeviceToViewDepth.z, (tan(_6558.y) * sqrt(1.0f + (_6561 * _6561))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _8214 = _8208 + (_8213 * cbFI_Timestep);
                    }
                    if (length((_8214 - _2596) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8342 = _8209;
                        _8286 = _8208;
                        _8217 = 2u;
                        break;
                    }
                    bool _5110 = all(bool2(_8208.x > cbFI_MvDepthLaneSizeRcp.x, _8208.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _5119;
                    if (_5110)
                    {
                        float2 _5115 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _5119 = all(bool2(_8208.x < _5115.x, _8208.y < _5115.y));
                    }
                    else
                    {
                        _5119 = _5110;
                    }
                    _8342 = _8209;
                    _8286 = _8208;
                    _8217 = _5119 ? 0u : 1u;
                    break;
                } while(false);
                if (_8217 == 0u)
                {
                    if ((_2720 & 512u) != 0u)
                    {
                        uint _6606;
                        rw_nfru_diagnostics.InterlockedAdd(8, 1u, _6606);
                    }
                    float2 _2767 = _8286 + _8342;
                    float2 _8433;
                    if ((_2720 & 1073741824u) != 0u)
                    {
                        float _6644 = ((2.0f * _2767.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6656 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6668 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6692 = ((2.0f * _8286.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8433 = (float2(atan(_6644) / _6656, atan((((2.0f * _2767.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6644 * _6644))) / _6668) + 0.5f.xx) - (float2(atan(_6692) / _6656, atan((((2.0f * _8286.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6692 * _6692))) / _6668) + 0.5f.xx);
                    }
                    else
                    {
                        _8433 = _2767 - _8286;
                    }
                    _8438 = 2u;
                    _8437 = -_8433;
                    break;
                }
                bool _6732 = (_2720 & 512u) != 0u;
                if (_6732)
                {
                    uint _6736;
                    rw_nfru_diagnostics.InterlockedAdd(20, 1u, _6736);
                }
                if (_8217 == 1u)
                {
                    if (_6732)
                    {
                        uint _6746;
                        rw_nfru_diagnostics.InterlockedAdd(116, 1u, _6746);
                    }
                }
                else
                {
                    if (_8217 == 2u)
                    {
                        if (_6732)
                        {
                            uint _6756;
                            rw_nfru_diagnostics.InterlockedAdd(248, 1u, _6756);
                        }
                    }
                }
            }
            if (_2241 > 0.25f)
            {
                _8438 = 0u;
                _8437 = _2228;
                break;
            }
            bool _6766 = (_2720 & 512u) != 0u;
            if (_6766)
            {
                uint _6770;
                rw_nfru_diagnostics.InterlockedAdd(216, 1u, _6770);
            }
            if (_2231)
            {
                if (_6766)
                {
                    uint _6780;
                    rw_nfru_diagnostics.InterlockedAdd(212, 1u, _6780);
                }
            }
            float _8355;
            _8355 = 0.0f;
            for (int _8354 = 0; _8354 < 5; )
            {
                float2 _6805 = _2596 + (float2(_527[_8354]) * cbFI_MvDepthLaneSizeRcp);
                _8355 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _6805, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _6805, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                _8354++;
                continue;
            }
            float _6823 = _8355 * 0.20000000298023223876953125f;
            if (_6823 < 0.0199999995529651641845703125f)
            {
                _8438 = 1u;
                _8437 = _2228;
                break;
            }
            float _2810 = _2596.x;
            float _2812 = _2596.y;
            float _2813 = 1.0f - _2812;
            uint _6850_dummy_parameter;
            float4 _2826 = mul(float4((float2(_2810, _2813) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2596 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6850_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
            float _2828 = _2826.w;
            bool _2829 = _2828 > 9.9999999747524270787835121154785e-07f;
            float2 _8357;
            if (_2829)
            {
                float2 _2839 = ((_2826.xy / _2828.xx) + 1.0f.xx) * 0.5f;
                _8357 = float2(_2839.x - _2810, _2813 - _2839.y);
            }
            else
            {
                _8357 = 0.0f.xx;
            }
            if (!_2829)
            {
                if (_6766)
                {
                    uint _6872;
                    rw_nfru_diagnostics.InterlockedAdd(208, 1u, _6872);
                }
            }
            float2 _2861 = _2596 + _8357;
            bool _6897 = (_2720 & 1073741824u) != 0u;
            float2 _8359;
            if (_6897)
            {
                float _6910 = ((2.0f * _2861.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float _6922 = 2.0f * cbFI_DeviceToViewDepth.z;
                float _6934 = 2.0f * cbFI_DeviceToViewDepth.w;
                float _6958 = ((2.0f * _2810) - 1.0f) * cbFI_DeviceToViewDepth.z;
                _8359 = (float2(atan(_6910) / _6922, atan((((2.0f * _2861.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6910 * _6910))) / _6934) + 0.5f.xx) - (float2(atan(_6958) / _6922, atan((((2.0f * _2812) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6958 * _6958))) / _6934) + 0.5f.xx);
            }
            else
            {
                _8359 = _2861 - _2596;
            }
            bool2 _8662 = ((cbFI_NfruT2Flags & 8192u) != 0u).xx;
            float2 _2873[2] = { float2(_8662.x ? 0.0f.xx.x : _8359.x, _8662.y ? 0.0f.xx.y : _8359.y), -r_warped_filled_flow_tm1.Load(int3(clamp(int2(_2596 * float2(cbFI_FlowLaneSize)), int2(0, 0), cbFI_FlowLaneSize - int2(1, 1)), 0)).xy };
            float2 _2677[2] = _2873;
            uint _8362;
            bool _8369;
            bool _8374;
            bool _8379;
            float2 _8387;
            _8387 = _2228;
            _8379 = false;
            _8374 = false;
            _8369 = false;
            _8362 = 0u;
            uint _8547;
            bool _8568;
            bool _8586;
            bool _8607;
            float2 _8628;
            float _8649;
            int _8361 = 0;
            float _8407 = _6823;
            for (; _8361 < 2; _8407 = _8649, _8387 = _8628, _8379 = _8607, _8374 = _8586, _8369 = _8568, _8362 = _8547, _8361++)
            {
                bool _2882 = _8361 == 0;
                uint _2883 = _2882 ? 32u : 42u;
                uint _2886 = _2882 ? 8u : 12u;
                if (_6766)
                {
                    uint _7002;
                    rw_nfru_diagnostics.InterlockedAdd(_2883 * 4 + 0, 1u, _7002);
                }
                bool _2894 = any(isnan(_2677[_8361]));
                bool _2901;
                if (!_2894)
                {
                    _2901 = any(isinf(_2677[_8361]));
                }
                else
                {
                    _2901 = _2894;
                }
                if (_2901)
                {
                    if (_6766)
                    {
                        uint _7012;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 1u) * 4 + 0, 1u, _7012);
                    }
                    nfruCandidateFlags |= (1u << _2886);
                    _8649 = _8407;
                    _8628 = _8387;
                    _8607 = true;
                    _8586 = _8374;
                    _8568 = _8369;
                    _8547 = _8362;
                    continue;
                }
                float _2915 = length(_2677[_8361] * _2239);
                if (_2915 < 1.0f)
                {
                    if (_6766)
                    {
                        uint _7026;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 2u) * 4 + 0, 1u, _7026);
                    }
                    nfruCandidateFlags |= (2u << _2886);
                    _8649 = _8407;
                    _8628 = _8387;
                    _8607 = _8379;
                    _8586 = _8374;
                    _8568 = _8369;
                    _8547 = _8362;
                    continue;
                }
                if (_2915 > 256.0f)
                {
                    if (_6766)
                    {
                        uint _7036;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 8u) * 4 + 0, 1u, _7036);
                    }
                }
                if (_2915 > float(max(cbFI_DisplaySize.x, cbFI_DisplaySize.y)))
                {
                    if (_6766)
                    {
                        uint _7054;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 9u) * 4 + 0, 1u, _7054);
                    }
                }
                float2 _8392;
                if (_6897)
                {
                    float _7100 = ((2.0f * _2810) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7149 = clamp(((((float2(atan(_7100) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2812) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7100 * _7100))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2677[_8361] * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7152 = tan(_7149.x);
                    _8392 = (float2(_7152 / cbFI_DeviceToViewDepth.z, (tan(_7149.y) * sqrt(1.0f + (_7152 * _7152))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8392 = _2596 + (_2677[_8361] * cbFI_Timestep);
                }
                float _2953 = cbFI_Timestep - 1.0f;
                float2 _8393;
                if (_6897)
                {
                    float _7225 = ((2.0f * _2810) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7274 = clamp(((((float2(atan(_7225) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2812) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7225 * _7225))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2677[_8361] * _2953)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7277 = tan(_7274.x);
                    _8393 = (float2(_7277 / cbFI_DeviceToViewDepth.z, (tan(_7274.y) * sqrt(1.0f + (_7277 * _7277))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8393 = _2596 + (_2677[_8361] * _2953);
                }
                bool _7313 = all(bool2(_8392.x > cbFI_MvDepthLaneSizeRcp.x, _8392.y > cbFI_MvDepthLaneSizeRcp.y));
                bool _7322;
                if (_7313)
                {
                    float2 _7318 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7322 = all(bool2(_8392.x < _7318.x, _8392.y < _7318.y));
                }
                else
                {
                    _7322 = _7313;
                }
                bool _7329;
                if (_7322)
                {
                    _7329 = all(bool2(_8393.x > cbFI_MvDepthLaneSizeRcp.x, _8393.y > cbFI_MvDepthLaneSizeRcp.y));
                }
                else
                {
                    _7329 = _7322;
                }
                bool _7338;
                if (_7329)
                {
                    float2 _7334 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7338 = all(bool2(_8393.x < _7334.x, _8393.y < _7334.y));
                }
                else
                {
                    _7338 = _7329;
                }
                if (!_7338)
                {
                    if (_6766)
                    {
                        uint _7351;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 3u) * 4 + 0, 1u, _7351);
                    }
                    nfruCandidateFlags |= (3u << _2886);
                    _8649 = _8407;
                    _8628 = _8387;
                    _8607 = _8379;
                    _8586 = _8374;
                    _8568 = true;
                    _8547 = _8362;
                    continue;
                }
                if (_6766)
                {
                    uint _7361;
                    rw_nfru_diagnostics.InterlockedAdd((_2883 + 4u) * 4 + 0, 1u, _7361);
                }
                float _8395;
                _8395 = 0.0f;
                for (int _8394 = 0; _8394 < 5; )
                {
                    float2 _7383 = float2(_527[_8394]) * cbFI_MvDepthLaneSizeRcp;
                    _8395 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8392 + _7383, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _8393 + _7383, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                    _8394++;
                    continue;
                }
                float _7404 = _8395 * 0.20000000298023223876953125f;
                bool _2978 = _7404 < _8407;
                bool _2985;
                if (_2978)
                {
                    _2985 = _7404 < (_8355 * 0.12000000476837158203125f);
                }
                else
                {
                    _2985 = _2978;
                }
                bool _2992;
                if (_2985)
                {
                    _2992 = (_6823 - _7404) > 0.0199999995529651641845703125f;
                }
                else
                {
                    _2992 = _2985;
                }
                bool _2995 = _2992 && (_7404 < 0.119999997317790985107421875f);
                uint _8562;
                if (_2995)
                {
                    if (_6766)
                    {
                        uint _7433;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 6u) * 4 + 0, 1u, _7433);
                    }
                    nfruCandidateFlags |= (5u << _2886);
                    _8562 = uint(_8361) + 2u;
                }
                else
                {
                    if (_6766)
                    {
                        uint _7443;
                        rw_nfru_diagnostics.InterlockedAdd((_2883 + 5u) * 4 + 0, 1u, _7443);
                    }
                    nfruCandidateFlags |= (4u << _2886);
                    _8562 = _8362;
                }
                bool2 _8665 = _2995.xx;
                _8649 = _2995 ? _7404 : _8407;
                _8628 = float2(_8665.x ? _2677[_8361].x : _8387.x, _8665.y ? _2677[_8361].y : _8387.y);
                _8607 = _8379;
                _8586 = true;
                _8568 = true;
                _8547 = _8562;
            }
            if (_8362 == 2u)
            {
                if (_6766)
                {
                    uint _7453;
                    rw_nfru_diagnostics.InterlockedAdd(156, 1u, _7453);
                }
            }
            else
            {
                if (_8362 == 3u)
                {
                    if (_6766)
                    {
                        uint _7463;
                        rw_nfru_diagnostics.InterlockedAdd(196, 1u, _7463);
                    }
                }
            }
            uint _8383;
            if (_8362 != 0u)
            {
                _8383 = _8362;
            }
            else
            {
                uint _8382;
                if (!_8369)
                {
                    _8382 = _8379 ? 7u : 4u;
                }
                else
                {
                    _8382 = (!_8374) ? 5u : 6u;
                }
                _8383 = _8382;
            }
            _8438 = _8383;
            _8437 = _8387;
            break;
        } while(false);
        bool _7538 = (_2720 & 512u) != 0u;
        if (_7538)
        {
            uint _7542;
            rw_nfru_diagnostics.InterlockedAdd(24, 1u, _7542);
        }
        if (_7538)
        {
            uint _7552;
            rw_nfru_diagnostics.InterlockedAdd((7u + _8438) * 4 + 0, 1u, _7552);
        }
        if ((nfruHoleFlags & 32u) != 0u)
        {
            if (_7538)
            {
                uint _7562;
                rw_nfru_diagnostics.InterlockedAdd((((_8438 == 2u) || (_8438 == 3u)) ? 30u : 31u) * 4 + 0, 1u, _7562);
            }
        }
        uint _7490 = (_2720 >> 16u) & 255u;
        bool _7494 = (_2720 & 1024u) != 0u;
        bool _7503;
        if (!_7494)
        {
            _7503 = (_7490 >= 9u) && (_7490 <= 11u);
        }
        else
        {
            _7503 = _7494;
        }
        if (_7503)
        {
            rw_nfru_diagnostics.Store<uint>((64u + uint((_1860.y * cbFI_MvDepthLaneSize.x) + _2159)) * 4 + 0, ((_8438 | nfruHoleFlags) | nfruCandidateFlags) | (((((nfruHoleFlags & 32u) == 0u) || (_8438 == 2u)) || (_8438 == 3u)) ? 65536u : 0u));
        }
        rw_warped_filled_motion_tp1[_1860] = float4(_8437, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
