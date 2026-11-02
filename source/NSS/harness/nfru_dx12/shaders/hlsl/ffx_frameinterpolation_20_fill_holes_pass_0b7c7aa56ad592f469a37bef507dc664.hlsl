static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static uint _8521;
static float2 _8571;

static const int2 _633[5] = { int2(0, 0), int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
static const int2 _1705[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1721[12] = { 2, 4, 7, 11, 16, 24, 36, 54, 80, 120, 180, 384 };

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
    int2 _1978 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1978.x >= cbFI_MvDepthLaneSize.x, _1978.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        nfruWalkAvgMotion = 1000000015047466219876688855040.0f.xx;
        uint _2060[9];
        _2060[0] = r_warped_motion_qdata_tp1.Load(int3(_1978, 0)).x;
        _2060[1] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(1, 0), 0)).x;
        _2060[2] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(0, 1), 0)).x;
        _2060[3] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(0, -1), 0)).x;
        _2060[4] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(-1, 0), 0)).x;
        _2060[5] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(-1, 1), 0)).x;
        _2060[6] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(1, 1), 0)).x;
        _2060[7] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(-1, -1), 0)).x;
        _2060[8] = r_warped_motion_qdata_tp1.Load(int3(_1978 + int2(1, -1), 0)).x;
        uint _8391;
        _8391 = _2060[0];
        uint _9152;
        for (int _8390 = 1; _8390 < 9; _8391 = _9152, _8390++)
        {
            _9152 = (_2060[_8390] > _8391) ? _2060[_8390] : _8391;
        }
        bool _2161 = _8391 == 0u;
        bool _2168;
        if (_2161)
        {
            _2168 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _2168 = _2161;
        }
        uint _8399;
        if (_2168)
        {
            int _2174 = ((cbFI_NfruT2Flags & 1048576u) != 0u) ? 12 : 5;
            uint _8393;
            _8393 = 4294967295u;
            uint _2076[8];
            uint _9008;
            for (int _8392 = 0; _8392 < 8; _8393 = _9008, _8392++)
            {
                _2076[_8392] = 0u;
                int _8999 = 0;
                for (;;)
                {
                    if (_8999 < _2174)
                    {
                        int2 _2197 = _1978 + (_1705[_8392] * _1721[_8999].xx);
                        bool _2200 = any(bool2(_2197.x < int2(0, 0).x, _2197.y < int2(0, 0).y));
                        bool _2208;
                        if (!_2200)
                        {
                            _2208 = any(bool2(_2197.x >= cbFI_MvDepthLaneSize.x, _2197.y >= cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _2208 = _2200;
                        }
                        if (_2208)
                        {
                            _9008 = _8393;
                            break;
                        }
                        uint4 _2497 = r_warped_motion_qdata_tp1.Load(int3(_2197, 0));
                        uint _2498 = _2497.x;
                        if (_2498 != 0u)
                        {
                            _2076[_8392] = _2498;
                            _9008 = min(_8393, _2498);
                            break;
                        }
                        _8999++;
                        continue;
                    }
                    else
                    {
                        _9008 = _8393;
                        break;
                    }
                }
            }
            bool _2232 = _8393 != 4294967295u;
            if (_2232)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _2507;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _2507);
                }
            }
            bool _2245;
            if (_2232)
            {
                _2245 = (cbFI_NfruT2Flags & 131072u) != 0u;
            }
            else
            {
                _2245 = _2232;
            }
            if (_2245)
            {
                float _8397;
                float2 _8398;
                _8398 = 0.0f.xx;
                _8397 = 0.0f;
                float _9009;
                float2 _9010;
                for (int _8396 = 0; _8396 < 8; _8398 = _9010, _8397 = _9009, _8396++)
                {
                    bool _2255 = _2076[_8396] != 0u;
                    bool _2268;
                    if (_2255)
                    {
                        _2268 = ((_2076[_8396] >> 20u) & 2047u) <= (((_8393 >> 20u) & 2047u) + 55u);
                    }
                    else
                    {
                        _2268 = _2255;
                    }
                    if (_2268)
                    {
                        uint _2524 = _2076[_8396] & 2147483647u;
                        uint _2556 = uint(max((int((_2524 >> 16u) & 15u) - 6), 0));
                        _9010 = _8398 + (float2(float((1 - (2 * int((_2524 >> 15u) & 1u))) * int(((_2524 >> uint(7)) & 127u) << _2556)), float((1 - (2 * int((_2524 >> 14u) & 1u))) * int((_2524 & 127u) << _2556))) * 0.0624427758157253265380859375f);
                        _9009 = _8397 + 1.0f;
                    }
                    else
                    {
                        _9010 = _8398;
                        _9009 = _8397;
                    }
                }
                if (_8397 > 0.0f)
                {
                    nfruWalkAvgMotion = _8398 / _8397.xx;
                }
            }
            _8399 = _2232 ? _8393 : _8391;
        }
        else
        {
            _8399 = _8391;
        }
        nfruHoleFlags = 0u;
        bool _2295 = _2060[0] == 0u;
        bool _2297 = _8399 == 0u;
        int _2299 = _1978.x;
        bool _2300 = _2299 == 0;
        bool _2307;
        if (!_2300)
        {
            _2307 = _1978.y == 0;
        }
        else
        {
            _2307 = _2300;
        }
        bool _2317;
        if (!_2307)
        {
            _2317 = _2299 == (cbFI_MvDepthLaneSize.x - 1);
        }
        else
        {
            _2317 = _2307;
        }
        bool _2327;
        if (!_2317)
        {
            _2327 = _1978.y == (cbFI_MvDepthLaneSize.y - 1);
        }
        else
        {
            _2327 = _2317;
        }
        if (_2295)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2584;
                rw_nfru_diagnostics.InterlockedAdd(88, 1u, _2584);
            }
            nfruHoleFlags |= 16u;
        }
        if (_2297)
        {
            bool _2590 = (cbFI_pad0 & 512u) != 0u;
            if (_2590)
            {
                uint _2594;
                rw_nfru_diagnostics.InterlockedAdd(92, 1u, _2594);
            }
            nfruHoleFlags |= 32u;
            if (!_2327)
            {
                if (_2590)
                {
                    uint _2604;
                    rw_nfru_diagnostics.InterlockedAdd(96, 1u, _2604);
                }
            }
        }
        if (_2327)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2614;
                rw_nfru_diagnostics.InterlockedAdd(108, 1u, _2614);
            }
        }
        if (_2295 && (!_2297))
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2624;
                rw_nfru_diagnostics.InterlockedAdd(112, 1u, _2624);
            }
        }
        float2 _8421;
        if (nfruWalkAvgMotion.x < 100000001504746621987668885504.0f)
        {
            _8421 = nfruWalkAvgMotion;
        }
        else
        {
            uint _2641 = _8399 & 2147483647u;
            uint _2673 = uint(max((int((_2641 >> 16u) & 15u) - 6), 0));
            _8421 = float2(float((1 - (2 * int((_2641 >> 15u) & 1u))) * int(((_2641 >> uint(7)) & 127u) << _2673)), float((1 - (2 * int((_2641 >> 14u) & 1u))) * int((_2641 & 127u) << _2673))) * 0.0624427758157253265380859375f;
        }
        float2 _2368 = _8421 * cbFI_MvDepthLaneSizeRcp;
        bool _2371 = all(bool2(_2368.x == 0.0f.xx.x, _2368.y == 0.0f.xx.y));
        if (_2371)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2701;
                rw_nfru_diagnostics.InterlockedAdd(100, 1u, _2701);
            }
            nfruHoleFlags |= 64u;
        }
        float2 _2379 = float2(cbFI_DisplaySize);
        float _2381 = length(_2368 * _2379);
        if (_2381 <= 0.25f)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2715;
                rw_nfru_diagnostics.InterlockedAdd(104, 1u, _2715);
            }
        }
        uint _2860;
        float2 _2736 = (float2(_1978) + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        float2 _8922;
        uint _8923;
        do
        {
            nfruCandidateFlags = 0u;
            _2860 = cbFI_pad0;
            bool _2862 = (_2860 & 536870912u) != 0u;
            bool _2868;
            if (_2862)
            {
                _2868 = (nfruHoleFlags & 32u) != 0u;
            }
            else
            {
                _2868 = _2862;
            }
            bool _2875;
            if (_2868)
            {
                _2875 = (cbFI_NfruT2Flags & 2u) == 0u;
            }
            else
            {
                _2875 = _2868;
            }
            if (_2875)
            {
                bool _3226;
                float4x4 _8426;
                do
                {
                    float4x4 _3202;
                    bool _8425;
                    do
                    {
                        _3202 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _3226 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_3226)
                        {
                            _8425 = false;
                            break;
                        }
                        uint _3236 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_3236 + 32u) * 4 + 0) != 1u)
                        {
                            _8425 = false;
                            break;
                        }
                        uint _8422;
                        _8422 = 0u;
                        for (; _8422 < 4u; _8422++)
                        {
                            for (uint _8423 = 0u; _8423 < 4u; )
                            {
                                _3202[_8422][_8423] = asfloat(rw_nfru_diagnostics.Load<uint>(((_3236 + (_8422 * 4u)) + _8423) * 4 + 0));
                                _8423++;
                                continue;
                            }
                        }
                        _8425 = true;
                        break;
                    } while(false);
                    if (_8425)
                    {
                        _8426 = _3202;
                        break;
                    }
                    _8426 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _3541;
                float _3544;
                float _3553;
                float _3554;
                float _2880 = 1.0f - cbFI_Timestep;
                uint _8500;
                float2 _8552;
                float2 _8591;
                do
                {
                    float2 _8427;
                    bool _8428;
                    do
                    {
                        _3541 = _2736.x;
                        _3544 = 1.0f - _2736.y;
                        float2 _3550 = (float2(_3541, _3544) * 2.0f) - 1.0f.xx;
                        uint _3607_dummy_parameter;
                        _3553 = _3550.x;
                        _3554 = _3550.y;
                        float4 _3556 = mul(float4(_3553, _3554, r_depth_tp1.Load(int3(int2(floor(_2736 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3607_dummy_parameter))))), 0)).x, 1.0f), _8426);
                        float _3558 = _3556.w;
                        bool _3559 = _3558 > 9.9999999747524270787835121154785e-07f;
                        if (!_3559)
                        {
                            _8428 = _3559;
                            _8427 = 0.0f.xx;
                            break;
                        }
                        float2 _3572 = ((_3556.xy / _3558.xx) + 1.0f.xx) * 0.5f;
                        float2 _3583 = float2(_3572.x - _3541, _3544 - _3572.y);
                        bool _3586 = any(isnan(_3583));
                        bool _3593;
                        if (!_3586)
                        {
                            _3593 = any(isinf(_3583));
                        }
                        else
                        {
                            _3593 = _3586;
                        }
                        bool _3594 = !_3593;
                        bool2 _3597 = _3594.xx;
                        _8428 = _3594;
                        _8427 = float2(_3597.x ? _3583.x : 0.0f.xx.x, _3597.y ? _3583.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8428)
                    {
                        _8591 = _8427;
                        _8552 = _8571;
                        _8500 = 3u;
                        break;
                    }
                    float2 _8430;
                    float2 _8593;
                    _8430 = _2736 - (_8427 * _2880);
                    _8593 = _8427;
                    float2 _3485;
                    float2 _8431;
                    bool _8475;
                    float2 _8491;
                    uint _8501;
                    float2 _8592;
                    int _8429 = 0;
                    for (;;)
                    {
                        if (_8429 < 8)
                        {
                            float _3632;
                            float _3634;
                            float2 _3369 = clamp(_8430, (-1.0f).xx, 2.0f.xx);
                            bool _8432;
                            do
                            {
                                _3632 = _3369.x;
                                _3634 = _3369.y;
                                float _3635 = 1.0f - _3634;
                                uint _3698_dummy_parameter;
                                float4 _3647 = mul(float4((float2(_3632, _3635) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3369 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3698_dummy_parameter))))), 0)).x, 1.0f), _8426);
                                float _3649 = _3647.w;
                                bool _3650 = _3649 > 9.9999999747524270787835121154785e-07f;
                                if (!_3650)
                                {
                                    _8432 = _3650;
                                    _8431 = 0.0f.xx;
                                    break;
                                }
                                float2 _3663 = ((_3647.xy / _3649.xx) + 1.0f.xx) * 0.5f;
                                float2 _3674 = float2(_3663.x - _3632, _3635 - _3663.y);
                                bool _3677 = any(isnan(_3674));
                                bool _3684;
                                if (!_3677)
                                {
                                    _3684 = any(isinf(_3674));
                                }
                                else
                                {
                                    _3684 = _3677;
                                }
                                bool _3685 = !_3684;
                                bool2 _3688 = _3685.xx;
                                _8432 = _3685;
                                _8431 = float2(_3688.x ? _3674.x : 0.0f.xx.x, _3688.y ? _3674.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3719;
                            float _3721;
                            float2 _3378 = _3369 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _8435;
                            bool _8436;
                            do
                            {
                                _3719 = _3378.x;
                                _3721 = _3378.y;
                                float _3722 = 1.0f - _3721;
                                uint _3785_dummy_parameter;
                                float4 _3734 = mul(float4((float2(_3719, _3722) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3378 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3785_dummy_parameter))))), 0)).x, 1.0f), _8426);
                                float _3736 = _3734.w;
                                bool _3737 = _3736 > 9.9999999747524270787835121154785e-07f;
                                if (!_3737)
                                {
                                    _8436 = _3737;
                                    _8435 = 0.0f.xx;
                                    break;
                                }
                                float2 _3750 = ((_3734.xy / _3736.xx) + 1.0f.xx) * 0.5f;
                                float2 _3761 = float2(_3750.x - _3719, _3722 - _3750.y);
                                bool _3764 = any(isnan(_3761));
                                bool _3771;
                                if (!_3764)
                                {
                                    _3771 = any(isinf(_3761));
                                }
                                else
                                {
                                    _3771 = _3764;
                                }
                                bool _3772 = !_3771;
                                bool2 _3775 = _3772.xx;
                                _8436 = _3772;
                                _8435 = float2(_3775.x ? _3761.x : 0.0f.xx.x, _3775.y ? _3761.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3806;
                            float _3808;
                            float2 _3386 = _3369 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _8439;
                            bool _8440;
                            do
                            {
                                _3806 = _3386.x;
                                _3808 = _3386.y;
                                float _3809 = 1.0f - _3808;
                                uint _3872_dummy_parameter;
                                float4 _3821 = mul(float4((float2(_3806, _3809) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3386 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3872_dummy_parameter))))), 0)).x, 1.0f), _8426);
                                float _3823 = _3821.w;
                                bool _3824 = _3823 > 9.9999999747524270787835121154785e-07f;
                                if (!_3824)
                                {
                                    _8440 = _3824;
                                    _8439 = 0.0f.xx;
                                    break;
                                }
                                float2 _3837 = ((_3821.xy / _3823.xx) + 1.0f.xx) * 0.5f;
                                float2 _3848 = float2(_3837.x - _3806, _3809 - _3837.y);
                                bool _3851 = any(isnan(_3848));
                                bool _3858;
                                if (!_3851)
                                {
                                    _3858 = any(isinf(_3848));
                                }
                                else
                                {
                                    _3858 = _3851;
                                }
                                bool _3859 = !_3858;
                                bool2 _3862 = _3859.xx;
                                _8440 = _3859;
                                _8439 = float2(_3862.x ? _3848.x : 0.0f.xx.x, _3862.y ? _3848.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_8432 && _8436) && _8440))
                            {
                                _8592 = _8431;
                                _8501 = 3u;
                                _8491 = _3369;
                                _8475 = true;
                                break;
                            }
                            float2 _3891 = _3369 + _8431;
                            bool _3920 = (_2860 & 1073741824u) != 0u;
                            float2 _8451;
                            if (_3920)
                            {
                                float _3933 = ((2.0f * _3891.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3945 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3957 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3981 = ((2.0f * _3632) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8451 = (float2(atan(_3933) / _3945, atan((((2.0f * _3891.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3933 * _3933))) / _3957) + 0.5f.xx) - (float2(atan(_3981) / _3945, atan((((2.0f * _3634) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3981 * _3981))) / _3957) + 0.5f.xx);
                            }
                            else
                            {
                                _8451 = _3891 - _3369;
                            }
                            float2 _8452;
                            if (_3920)
                            {
                                float _4057 = ((2.0f * _3632) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4106 = clamp(((((float2(atan(_4057) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3634) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4057 * _4057))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8451 * _2880)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4109 = tan(_4106.x);
                                _8452 = (float2(_4109 / cbFI_DeviceToViewDepth.z, (tan(_4106.y) * sqrt(1.0f + (_4109 * _4109))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8452 = _3369 + (_8451 * _2880);
                            }
                            float2 _3404 = _8452 - _2736;
                            if (length(_3404 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8592 = _8431;
                                _8501 = _8521;
                                _8491 = _3369;
                                _8475 = false;
                                break;
                            }
                            float2 _4151 = _3378 + _8435;
                            float2 _8455;
                            if (_3920)
                            {
                                float _4193 = ((2.0f * _4151.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _4205 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _4217 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4241 = ((2.0f * _3719) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8455 = (float2(atan(_4193) / _4205, atan((((2.0f * _4151.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4193 * _4193))) / _4217) + 0.5f.xx) - (float2(atan(_4241) / _4205, atan((((2.0f * _3721) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4241 * _4241))) / _4217) + 0.5f.xx);
                            }
                            else
                            {
                                _8455 = _4151 - _3378;
                            }
                            float2 _8456;
                            if (_3920)
                            {
                                float _4317 = ((2.0f * _3719) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4366 = clamp(((((float2(atan(_4317) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3721) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4317 * _4317))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8455 * _2880)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4369 = tan(_4366.x);
                                _8456 = (float2(_4369 / cbFI_DeviceToViewDepth.z, (tan(_4366.y) * sqrt(1.0f + (_4369 * _4369))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8456 = _3378 + (_8455 * _2880);
                            }
                            float2 _3426 = (_8456 - _8452) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _4407 = _3386 + _8439;
                            float2 _8459;
                            if (_3920)
                            {
                                float _4449 = ((2.0f * _4407.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _4461 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _4473 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4497 = ((2.0f * _3806) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8459 = (float2(atan(_4449) / _4461, atan((((2.0f * _4407.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4449 * _4449))) / _4473) + 0.5f.xx) - (float2(atan(_4497) / _4461, atan((((2.0f * _3808) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4497 * _4497))) / _4473) + 0.5f.xx);
                            }
                            else
                            {
                                _8459 = _4407 - _3386;
                            }
                            float2 _8460;
                            if (_3920)
                            {
                                float _4573 = ((2.0f * _3806) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4622 = clamp(((((float2(atan(_4573) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3808) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4573 * _4573))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8459 * _2880)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4625 = tan(_4622.x);
                                _8460 = (float2(_4625 / cbFI_DeviceToViewDepth.z, (tan(_4622.y) * sqrt(1.0f + (_4625 * _4625))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8460 = _3386 + (_8459 * _2880);
                            }
                            float2 _3440 = (_8460 - _8452) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _3442 = _3426.x;
                            float _3444 = _3440.y;
                            float _3447 = _3440.x;
                            float _3449 = _3426.y;
                            float _3451 = (_3442 * _3444) - (_3447 * _3449);
                            if (abs(_3451) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8592 = _8431;
                                _8501 = 3u;
                                _8491 = _3369;
                                _8475 = true;
                                break;
                            }
                            float _3460 = _3404.x;
                            float _3465 = _3404.y;
                            _3485 = _3369 - (float2((_3444 * _3460) - (_3447 * _3465), ((-_3449) * _3460) + (_3442 * _3465)) / _3451.xx);
                            _8430 = _3485;
                            _8429++;
                            _8593 = _8431;
                            continue;
                        }
                        else
                        {
                            _8592 = _8593;
                            _8501 = _8521;
                            _8491 = _8430;
                            _8475 = false;
                            break;
                        }
                    }
                    if (_8475)
                    {
                        _8591 = _8592;
                        _8552 = _8491;
                        _8500 = _8501;
                        break;
                    }
                    float _4665;
                    float _4667;
                    float2 _8492;
                    bool _8493;
                    do
                    {
                        _4665 = _8491.x;
                        _4667 = _8491.y;
                        float _4668 = 1.0f - _4667;
                        uint _4731_dummy_parameter;
                        float4 _4680 = mul(float4((float2(_4665, _4668) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_8491 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4731_dummy_parameter))))), 0)).x, 1.0f), _8426);
                        float _4682 = _4680.w;
                        bool _4683 = _4682 > 9.9999999747524270787835121154785e-07f;
                        if (!_4683)
                        {
                            _8493 = _4683;
                            _8492 = 0.0f.xx;
                            break;
                        }
                        float2 _4696 = ((_4680.xy / _4682.xx) + 1.0f.xx) * 0.5f;
                        float2 _4707 = float2(_4696.x - _4665, _4668 - _4696.y);
                        bool _4710 = any(isnan(_4707));
                        bool _4717;
                        if (!_4710)
                        {
                            _4717 = any(isinf(_4707));
                        }
                        else
                        {
                            _4717 = _4710;
                        }
                        bool _4718 = !_4717;
                        bool2 _4721 = _4718.xx;
                        _8493 = _4718;
                        _8492 = float2(_4721.x ? _4707.x : 0.0f.xx.x, _4721.y ? _4707.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8493)
                    {
                        _8591 = _8492;
                        _8552 = _8491;
                        _8500 = 3u;
                        break;
                    }
                    float2 _4750 = _8491 + _8492;
                    bool _4779 = (_2860 & 1073741824u) != 0u;
                    float2 _8496;
                    if (_4779)
                    {
                        float _4792 = ((2.0f * _4750.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4804 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4816 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4840 = ((2.0f * _4665) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8496 = (float2(atan(_4792) / _4804, atan((((2.0f * _4750.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4792 * _4792))) / _4816) + 0.5f.xx) - (float2(atan(_4840) / _4804, atan((((2.0f * _4667) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4840 * _4840))) / _4816) + 0.5f.xx);
                    }
                    else
                    {
                        _8496 = _4750 - _8491;
                    }
                    float2 _8497;
                    if (_4779)
                    {
                        float _4916 = ((2.0f * _4665) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _4965 = clamp(((((float2(atan(_4916) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4667) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4916 * _4916))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8496 * _2880)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _4968 = tan(_4965.x);
                        _8497 = (float2(_4968 / cbFI_DeviceToViewDepth.z, (tan(_4965.y) * sqrt(1.0f + (_4968 * _4968))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _8497 = _8491 + (_8496 * _2880);
                    }
                    if (length((_8497 - _2736) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8591 = _8492;
                        _8552 = _8491;
                        _8500 = 2u;
                        break;
                    }
                    bool _3517 = all(bool2(_8491.x > cbFI_MvDepthLaneSizeRcp.x, _8491.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _3526;
                    if (_3517)
                    {
                        float2 _3522 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _3526 = all(bool2(_8491.x < _3522.x, _8491.y < _3522.y));
                    }
                    else
                    {
                        _3526 = _3517;
                    }
                    _8591 = _8492;
                    _8552 = _8491;
                    _8500 = _3526 ? 0u : 1u;
                    break;
                } while(false);
                if (_8500 == 0u)
                {
                    if ((_2860 & 512u) != 0u)
                    {
                        uint _5013;
                        rw_nfru_diagnostics.InterlockedAdd(4, 1u, _5013);
                    }
                    float2 _2891 = _8552 + _8591;
                    float2 _8921;
                    if ((_2860 & 1073741824u) != 0u)
                    {
                        float _5051 = ((2.0f * _2891.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _5063 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _5075 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _5099 = ((2.0f * _8552.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8921 = (float2(atan(_5051) / _5063, atan((((2.0f * _2891.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5051 * _5051))) / _5075) + 0.5f.xx) - (float2(atan(_5099) / _5063, atan((((2.0f * _8552.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5099 * _5099))) / _5075) + 0.5f.xx);
                    }
                    else
                    {
                        _8921 = _2891 - _8552;
                    }
                    _8923 = 2u;
                    _8922 = _8921;
                    break;
                }
                float4x4 _8607;
                do
                {
                    float4x4 _5139;
                    bool _8606;
                    do
                    {
                        _5139 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3226)
                        {
                            _8606 = false;
                            break;
                        }
                        uint _5173 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_5173 + 32u) * 4 + 0) != 1u)
                        {
                            _8606 = false;
                            break;
                        }
                        uint _8603;
                        _8603 = 0u;
                        for (; _8603 < 4u; _8603++)
                        {
                            for (uint _8604 = 0u; _8604 < 4u; )
                            {
                                _5139[_8603][_8604] = asfloat(rw_nfru_diagnostics.Load<uint>((((_5173 + 16u) + (_8603 * 4u)) + _8604) * 4 + 0));
                                _8604++;
                                continue;
                            }
                        }
                        _8606 = true;
                        break;
                    } while(false);
                    if (_8606)
                    {
                        _8607 = _5139;
                        break;
                    }
                    _8607 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                uint _8681;
                float2 _8758;
                float2 _8822;
                do
                {
                    float2 _8608;
                    bool _8609;
                    do
                    {
                        uint _5544_dummy_parameter;
                        float4 _5493 = mul(float4(_3553, _3554, r_depth_tp1.Load(int3(int2(floor(_2736 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5544_dummy_parameter))))), 0)).x, 1.0f), _8607);
                        float _5495 = _5493.w;
                        bool _5496 = _5495 > 9.9999999747524270787835121154785e-07f;
                        if (!_5496)
                        {
                            _8609 = _5496;
                            _8608 = 0.0f.xx;
                            break;
                        }
                        float2 _5509 = ((_5493.xy / _5495.xx) + 1.0f.xx) * 0.5f;
                        float2 _5520 = float2(_5509.x - _3541, _3544 - _5509.y);
                        bool _5523 = any(isnan(_5520));
                        bool _5530;
                        if (!_5523)
                        {
                            _5530 = any(isinf(_5520));
                        }
                        else
                        {
                            _5530 = _5523;
                        }
                        bool _5531 = !_5530;
                        bool2 _5534 = _5531.xx;
                        _8609 = _5531;
                        _8608 = float2(_5534.x ? _5520.x : 0.0f.xx.x, _5534.y ? _5520.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8609)
                    {
                        _8822 = _8608;
                        _8758 = _8571;
                        _8681 = 3u;
                        break;
                    }
                    float2 _8611;
                    float2 _8824;
                    _8611 = _2736 - (_8608 * cbFI_Timestep);
                    _8824 = _8608;
                    float2 _5422;
                    float2 _8612;
                    bool _8656;
                    float2 _8672;
                    uint _8682;
                    float2 _8823;
                    int _8610 = 0;
                    for (;;)
                    {
                        if (_8610 < 8)
                        {
                            float _5569;
                            float _5571;
                            float2 _5306 = clamp(_8611, (-1.0f).xx, 2.0f.xx);
                            bool _8613;
                            do
                            {
                                _5569 = _5306.x;
                                _5571 = _5306.y;
                                float _5572 = 1.0f - _5571;
                                uint _5635_dummy_parameter;
                                float4 _5584 = mul(float4((float2(_5569, _5572) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5306 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5635_dummy_parameter))))), 0)).x, 1.0f), _8607);
                                float _5586 = _5584.w;
                                bool _5587 = _5586 > 9.9999999747524270787835121154785e-07f;
                                if (!_5587)
                                {
                                    _8613 = _5587;
                                    _8612 = 0.0f.xx;
                                    break;
                                }
                                float2 _5600 = ((_5584.xy / _5586.xx) + 1.0f.xx) * 0.5f;
                                float2 _5611 = float2(_5600.x - _5569, _5572 - _5600.y);
                                bool _5614 = any(isnan(_5611));
                                bool _5621;
                                if (!_5614)
                                {
                                    _5621 = any(isinf(_5611));
                                }
                                else
                                {
                                    _5621 = _5614;
                                }
                                bool _5622 = !_5621;
                                bool2 _5625 = _5622.xx;
                                _8613 = _5622;
                                _8612 = float2(_5625.x ? _5611.x : 0.0f.xx.x, _5625.y ? _5611.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5656;
                            float _5658;
                            float2 _5315 = _5306 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _8616;
                            bool _8617;
                            do
                            {
                                _5656 = _5315.x;
                                _5658 = _5315.y;
                                float _5659 = 1.0f - _5658;
                                uint _5722_dummy_parameter;
                                float4 _5671 = mul(float4((float2(_5656, _5659) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5315 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5722_dummy_parameter))))), 0)).x, 1.0f), _8607);
                                float _5673 = _5671.w;
                                bool _5674 = _5673 > 9.9999999747524270787835121154785e-07f;
                                if (!_5674)
                                {
                                    _8617 = _5674;
                                    _8616 = 0.0f.xx;
                                    break;
                                }
                                float2 _5687 = ((_5671.xy / _5673.xx) + 1.0f.xx) * 0.5f;
                                float2 _5698 = float2(_5687.x - _5656, _5659 - _5687.y);
                                bool _5701 = any(isnan(_5698));
                                bool _5708;
                                if (!_5701)
                                {
                                    _5708 = any(isinf(_5698));
                                }
                                else
                                {
                                    _5708 = _5701;
                                }
                                bool _5709 = !_5708;
                                bool2 _5712 = _5709.xx;
                                _8617 = _5709;
                                _8616 = float2(_5712.x ? _5698.x : 0.0f.xx.x, _5712.y ? _5698.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5743;
                            float _5745;
                            float2 _5323 = _5306 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _8620;
                            bool _8621;
                            do
                            {
                                _5743 = _5323.x;
                                _5745 = _5323.y;
                                float _5746 = 1.0f - _5745;
                                uint _5809_dummy_parameter;
                                float4 _5758 = mul(float4((float2(_5743, _5746) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5323 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5809_dummy_parameter))))), 0)).x, 1.0f), _8607);
                                float _5760 = _5758.w;
                                bool _5761 = _5760 > 9.9999999747524270787835121154785e-07f;
                                if (!_5761)
                                {
                                    _8621 = _5761;
                                    _8620 = 0.0f.xx;
                                    break;
                                }
                                float2 _5774 = ((_5758.xy / _5760.xx) + 1.0f.xx) * 0.5f;
                                float2 _5785 = float2(_5774.x - _5743, _5746 - _5774.y);
                                bool _5788 = any(isnan(_5785));
                                bool _5795;
                                if (!_5788)
                                {
                                    _5795 = any(isinf(_5785));
                                }
                                else
                                {
                                    _5795 = _5788;
                                }
                                bool _5796 = !_5795;
                                bool2 _5799 = _5796.xx;
                                _8621 = _5796;
                                _8620 = float2(_5799.x ? _5785.x : 0.0f.xx.x, _5799.y ? _5785.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_8613 && _8617) && _8621))
                            {
                                _8823 = _8612;
                                _8682 = 3u;
                                _8672 = _5306;
                                _8656 = true;
                                break;
                            }
                            float2 _5828 = _5306 + _8612;
                            bool _5857 = (_2860 & 1073741824u) != 0u;
                            float2 _8632;
                            if (_5857)
                            {
                                float _5870 = ((2.0f * _5828.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5882 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5894 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5918 = ((2.0f * _5569) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8632 = (float2(atan(_5870) / _5882, atan((((2.0f * _5828.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5870 * _5870))) / _5894) + 0.5f.xx) - (float2(atan(_5918) / _5882, atan((((2.0f * _5571) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5918 * _5918))) / _5894) + 0.5f.xx);
                            }
                            else
                            {
                                _8632 = _5828 - _5306;
                            }
                            float2 _8633;
                            if (_5857)
                            {
                                float _5994 = ((2.0f * _5569) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6043 = clamp(((((float2(atan(_5994) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5571) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5994 * _5994))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8632 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6046 = tan(_6043.x);
                                _8633 = (float2(_6046 / cbFI_DeviceToViewDepth.z, (tan(_6043.y) * sqrt(1.0f + (_6046 * _6046))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8633 = _5306 + (_8632 * cbFI_Timestep);
                            }
                            float2 _5341 = _8633 - _2736;
                            if (length(_5341 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8823 = _8612;
                                _8682 = _8521;
                                _8672 = _5306;
                                _8656 = false;
                                break;
                            }
                            float2 _6088 = _5315 + _8616;
                            float2 _8636;
                            if (_5857)
                            {
                                float _6130 = ((2.0f * _6088.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _6142 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _6154 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _6178 = ((2.0f * _5656) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8636 = (float2(atan(_6130) / _6142, atan((((2.0f * _6088.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6130 * _6130))) / _6154) + 0.5f.xx) - (float2(atan(_6178) / _6142, atan((((2.0f * _5658) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6178 * _6178))) / _6154) + 0.5f.xx);
                            }
                            else
                            {
                                _8636 = _6088 - _5315;
                            }
                            float2 _8637;
                            if (_5857)
                            {
                                float _6254 = ((2.0f * _5656) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6303 = clamp(((((float2(atan(_6254) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5658) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6254 * _6254))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8636 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6306 = tan(_6303.x);
                                _8637 = (float2(_6306 / cbFI_DeviceToViewDepth.z, (tan(_6303.y) * sqrt(1.0f + (_6306 * _6306))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8637 = _5315 + (_8636 * cbFI_Timestep);
                            }
                            float2 _5363 = (_8637 - _8633) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _6344 = _5323 + _8620;
                            float2 _8640;
                            if (_5857)
                            {
                                float _6386 = ((2.0f * _6344.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _6398 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _6410 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _6434 = ((2.0f * _5743) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8640 = (float2(atan(_6386) / _6398, atan((((2.0f * _6344.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6386 * _6386))) / _6410) + 0.5f.xx) - (float2(atan(_6434) / _6398, atan((((2.0f * _5745) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6434 * _6434))) / _6410) + 0.5f.xx);
                            }
                            else
                            {
                                _8640 = _6344 - _5323;
                            }
                            float2 _8641;
                            if (_5857)
                            {
                                float _6510 = ((2.0f * _5743) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6559 = clamp(((((float2(atan(_6510) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5745) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6510 * _6510))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8640 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6562 = tan(_6559.x);
                                _8641 = (float2(_6562 / cbFI_DeviceToViewDepth.z, (tan(_6559.y) * sqrt(1.0f + (_6562 * _6562))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8641 = _5323 + (_8640 * cbFI_Timestep);
                            }
                            float2 _5377 = (_8641 - _8633) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _5379 = _5363.x;
                            float _5381 = _5377.y;
                            float _5384 = _5377.x;
                            float _5386 = _5363.y;
                            float _5388 = (_5379 * _5381) - (_5384 * _5386);
                            if (abs(_5388) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8823 = _8612;
                                _8682 = 3u;
                                _8672 = _5306;
                                _8656 = true;
                                break;
                            }
                            float _5397 = _5341.x;
                            float _5402 = _5341.y;
                            _5422 = _5306 - (float2((_5381 * _5397) - (_5384 * _5402), ((-_5386) * _5397) + (_5379 * _5402)) / _5388.xx);
                            _8611 = _5422;
                            _8610++;
                            _8824 = _8612;
                            continue;
                        }
                        else
                        {
                            _8823 = _8824;
                            _8682 = _8521;
                            _8672 = _8611;
                            _8656 = false;
                            break;
                        }
                    }
                    if (_8656)
                    {
                        _8822 = _8823;
                        _8758 = _8672;
                        _8681 = _8682;
                        break;
                    }
                    float _6602;
                    float _6604;
                    float2 _8673;
                    bool _8674;
                    do
                    {
                        _6602 = _8672.x;
                        _6604 = _8672.y;
                        float _6605 = 1.0f - _6604;
                        uint _6668_dummy_parameter;
                        float4 _6617 = mul(float4((float2(_6602, _6605) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_8672 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6668_dummy_parameter))))), 0)).x, 1.0f), _8607);
                        float _6619 = _6617.w;
                        bool _6620 = _6619 > 9.9999999747524270787835121154785e-07f;
                        if (!_6620)
                        {
                            _8674 = _6620;
                            _8673 = 0.0f.xx;
                            break;
                        }
                        float2 _6633 = ((_6617.xy / _6619.xx) + 1.0f.xx) * 0.5f;
                        float2 _6644 = float2(_6633.x - _6602, _6605 - _6633.y);
                        bool _6647 = any(isnan(_6644));
                        bool _6654;
                        if (!_6647)
                        {
                            _6654 = any(isinf(_6644));
                        }
                        else
                        {
                            _6654 = _6647;
                        }
                        bool _6655 = !_6654;
                        bool2 _6658 = _6655.xx;
                        _8674 = _6655;
                        _8673 = float2(_6658.x ? _6644.x : 0.0f.xx.x, _6658.y ? _6644.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8674)
                    {
                        _8822 = _8673;
                        _8758 = _8672;
                        _8681 = 3u;
                        break;
                    }
                    float2 _6687 = _8672 + _8673;
                    bool _6716 = (_2860 & 1073741824u) != 0u;
                    float2 _8677;
                    if (_6716)
                    {
                        float _6729 = ((2.0f * _6687.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6741 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6753 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6777 = ((2.0f * _6602) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8677 = (float2(atan(_6729) / _6741, atan((((2.0f * _6687.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6729 * _6729))) / _6753) + 0.5f.xx) - (float2(atan(_6777) / _6741, atan((((2.0f * _6604) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6777 * _6777))) / _6753) + 0.5f.xx);
                    }
                    else
                    {
                        _8677 = _6687 - _8672;
                    }
                    float2 _8678;
                    if (_6716)
                    {
                        float _6853 = ((2.0f * _6602) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _6902 = clamp(((((float2(atan(_6853) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _6604) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6853 * _6853))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8677 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6905 = tan(_6902.x);
                        _8678 = (float2(_6905 / cbFI_DeviceToViewDepth.z, (tan(_6902.y) * sqrt(1.0f + (_6905 * _6905))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _8678 = _8672 + (_8677 * cbFI_Timestep);
                    }
                    if (length((_8678 - _2736) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8822 = _8673;
                        _8758 = _8672;
                        _8681 = 2u;
                        break;
                    }
                    bool _5454 = all(bool2(_8672.x > cbFI_MvDepthLaneSizeRcp.x, _8672.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _5463;
                    if (_5454)
                    {
                        float2 _5459 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _5463 = all(bool2(_8672.x < _5459.x, _8672.y < _5459.y));
                    }
                    else
                    {
                        _5463 = _5454;
                    }
                    _8822 = _8673;
                    _8758 = _8672;
                    _8681 = _5463 ? 0u : 1u;
                    break;
                } while(false);
                if (_8681 == 0u)
                {
                    if ((_2860 & 512u) != 0u)
                    {
                        uint _6950;
                        rw_nfru_diagnostics.InterlockedAdd(8, 1u, _6950);
                    }
                    float2 _2907 = _8758 + _8822;
                    float2 _8918;
                    if ((_2860 & 1073741824u) != 0u)
                    {
                        float _6988 = ((2.0f * _2907.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _7000 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _7012 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _7036 = ((2.0f * _8758.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8918 = (float2(atan(_6988) / _7000, atan((((2.0f * _2907.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6988 * _6988))) / _7012) + 0.5f.xx) - (float2(atan(_7036) / _7000, atan((((2.0f * _8758.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7036 * _7036))) / _7012) + 0.5f.xx);
                    }
                    else
                    {
                        _8918 = _2907 - _8758;
                    }
                    _8923 = 2u;
                    _8922 = -_8918;
                    break;
                }
                bool _7076 = (_2860 & 512u) != 0u;
                if (_7076)
                {
                    uint _7080;
                    rw_nfru_diagnostics.InterlockedAdd(20, 1u, _7080);
                }
                if (_8681 == 1u)
                {
                    if (_7076)
                    {
                        uint _7090;
                        rw_nfru_diagnostics.InterlockedAdd(116, 1u, _7090);
                    }
                }
                else
                {
                    if (_8681 == 2u)
                    {
                        if (_7076)
                        {
                            uint _7100;
                            rw_nfru_diagnostics.InterlockedAdd(248, 1u, _7100);
                        }
                    }
                }
            }
            if (_2381 > 0.25f)
            {
                _8923 = 0u;
                _8922 = _2368;
                break;
            }
            bool _7110 = (_2860 & 512u) != 0u;
            if (_7110)
            {
                uint _7114;
                rw_nfru_diagnostics.InterlockedAdd(216, 1u, _7114);
            }
            if (_2371)
            {
                if (_7110)
                {
                    uint _7124;
                    rw_nfru_diagnostics.InterlockedAdd(212, 1u, _7124);
                }
            }
            float _8835;
            _8835 = 0.0f;
            for (int _8834 = 0; _8834 < 5; )
            {
                float2 _7149 = _2736 + (float2(_633[_8834]) * cbFI_MvDepthLaneSizeRcp);
                _8835 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _7149, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _7149, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                _8834++;
                continue;
            }
            float _7167 = _8835 * 0.20000000298023223876953125f;
            if (_7167 < 0.0199999995529651641845703125f)
            {
                _8923 = 1u;
                _8922 = _2368;
                break;
            }
            uint _7230;
            float _2950 = _2736.x;
            float _2952 = _2736.y;
            float _2953 = 1.0f - _2952;
            uint _7194_dummy_parameter;
            float4x4 _8840;
            do
            {
                float4x4 _7208;
                bool _8839;
                do
                {
                    _7208 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    _7230 = cbFI_NfruT2Flags;
                    if ((_7230 & 524288u) == 0u)
                    {
                        _8839 = false;
                        break;
                    }
                    uint _7242 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_7242 + 32u) * 4 + 0) != 1u)
                    {
                        _8839 = false;
                        break;
                    }
                    uint _8836;
                    _8836 = 0u;
                    for (; _8836 < 4u; _8836++)
                    {
                        for (uint _8837 = 0u; _8837 < 4u; )
                        {
                            _7208[_8836][_8837] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7242 + (_8836 * 4u)) + _8837) * 4 + 0));
                            _8837++;
                            continue;
                        }
                    }
                    _8839 = true;
                    break;
                } while(false);
                if (_8839)
                {
                    _8840 = _7208;
                    break;
                }
                _8840 = cbFI_MotionTP1ToTM1;
                break;
            } while(false);
            float4 _2966 = mul(float4((float2(_2950, _2953) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2736 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7194_dummy_parameter))))), 0)).x, 1.0f), _8840);
            float _2968 = _2966.w;
            bool _2969 = _2968 > 9.9999999747524270787835121154785e-07f;
            float2 _8842;
            if (_2969)
            {
                float2 _2979 = ((_2966.xy / _2968.xx) + 1.0f.xx) * 0.5f;
                _8842 = float2(_2979.x - _2950, _2953 - _2979.y);
            }
            else
            {
                _8842 = 0.0f.xx;
            }
            if (!_2969)
            {
                if (_7110)
                {
                    uint _7318;
                    rw_nfru_diagnostics.InterlockedAdd(208, 1u, _7318);
                }
            }
            float2 _3001 = _2736 + _8842;
            bool _7343 = (_2860 & 1073741824u) != 0u;
            float2 _8844;
            if (_7343)
            {
                float _7356 = ((2.0f * _3001.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float _7368 = 2.0f * cbFI_DeviceToViewDepth.z;
                float _7380 = 2.0f * cbFI_DeviceToViewDepth.w;
                float _7404 = ((2.0f * _2950) - 1.0f) * cbFI_DeviceToViewDepth.z;
                _8844 = (float2(atan(_7356) / _7368, atan((((2.0f * _3001.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7356 * _7356))) / _7380) + 0.5f.xx) - (float2(atan(_7404) / _7368, atan((((2.0f * _2952) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7404 * _7404))) / _7380) + 0.5f.xx);
            }
            else
            {
                _8844 = _3001 - _2736;
            }
            bool2 _9155 = ((_7230 & 8192u) != 0u).xx;
            float2 _3013[2] = { float2(_9155.x ? 0.0f.xx.x : _8844.x, _9155.y ? 0.0f.xx.y : _8844.y), -r_warped_filled_flow_tm1.Load(int3(clamp(int2(_2736 * float2(cbFI_FlowLaneSize)), int2(0, 0), cbFI_FlowLaneSize - int2(1, 1)), 0)).xy };
            float2 _2817[2] = _3013;
            uint _8847;
            bool _8854;
            bool _8859;
            bool _8864;
            float2 _8872;
            _8872 = _2368;
            _8864 = false;
            _8859 = false;
            _8854 = false;
            _8847 = 0u;
            uint _9040;
            bool _9061;
            bool _9079;
            bool _9100;
            float2 _9121;
            float _9142;
            int _8846 = 0;
            float _8892 = _7167;
            for (; _8846 < 2; _8892 = _9142, _8872 = _9121, _8864 = _9100, _8859 = _9079, _8854 = _9061, _8847 = _9040, _8846++)
            {
                bool _3022 = _8846 == 0;
                uint _3023 = _3022 ? 32u : 42u;
                uint _3026 = _3022 ? 8u : 12u;
                if (_7110)
                {
                    uint _7448;
                    rw_nfru_diagnostics.InterlockedAdd(_3023 * 4 + 0, 1u, _7448);
                }
                bool _3034 = any(isnan(_2817[_8846]));
                bool _3041;
                if (!_3034)
                {
                    _3041 = any(isinf(_2817[_8846]));
                }
                else
                {
                    _3041 = _3034;
                }
                if (_3041)
                {
                    if (_7110)
                    {
                        uint _7458;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 1u) * 4 + 0, 1u, _7458);
                    }
                    nfruCandidateFlags |= (1u << _3026);
                    _9142 = _8892;
                    _9121 = _8872;
                    _9100 = true;
                    _9079 = _8859;
                    _9061 = _8854;
                    _9040 = _8847;
                    continue;
                }
                float _3055 = length(_2817[_8846] * _2379);
                if (_3055 < 1.0f)
                {
                    if (_7110)
                    {
                        uint _7472;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 2u) * 4 + 0, 1u, _7472);
                    }
                    nfruCandidateFlags |= (2u << _3026);
                    _9142 = _8892;
                    _9121 = _8872;
                    _9100 = _8864;
                    _9079 = _8859;
                    _9061 = _8854;
                    _9040 = _8847;
                    continue;
                }
                if (_3055 > 256.0f)
                {
                    if (_7110)
                    {
                        uint _7482;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 8u) * 4 + 0, 1u, _7482);
                    }
                }
                if (_3055 > float(max(cbFI_DisplaySize.x, cbFI_DisplaySize.y)))
                {
                    if (_7110)
                    {
                        uint _7500;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 9u) * 4 + 0, 1u, _7500);
                    }
                }
                float2 _8877;
                if (_7343)
                {
                    float _7546 = ((2.0f * _2950) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7595 = clamp(((((float2(atan(_7546) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2952) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7546 * _7546))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2817[_8846] * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7598 = tan(_7595.x);
                    _8877 = (float2(_7598 / cbFI_DeviceToViewDepth.z, (tan(_7595.y) * sqrt(1.0f + (_7598 * _7598))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8877 = _2736 + (_2817[_8846] * cbFI_Timestep);
                }
                float _3093 = cbFI_Timestep - 1.0f;
                float2 _8878;
                if (_7343)
                {
                    float _7671 = ((2.0f * _2950) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7720 = clamp(((((float2(atan(_7671) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2952) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7671 * _7671))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2817[_8846] * _3093)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7723 = tan(_7720.x);
                    _8878 = (float2(_7723 / cbFI_DeviceToViewDepth.z, (tan(_7720.y) * sqrt(1.0f + (_7723 * _7723))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8878 = _2736 + (_2817[_8846] * _3093);
                }
                bool _7759 = all(bool2(_8877.x > cbFI_MvDepthLaneSizeRcp.x, _8877.y > cbFI_MvDepthLaneSizeRcp.y));
                bool _7768;
                if (_7759)
                {
                    float2 _7764 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7768 = all(bool2(_8877.x < _7764.x, _8877.y < _7764.y));
                }
                else
                {
                    _7768 = _7759;
                }
                bool _7775;
                if (_7768)
                {
                    _7775 = all(bool2(_8878.x > cbFI_MvDepthLaneSizeRcp.x, _8878.y > cbFI_MvDepthLaneSizeRcp.y));
                }
                else
                {
                    _7775 = _7768;
                }
                bool _7784;
                if (_7775)
                {
                    float2 _7780 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7784 = all(bool2(_8878.x < _7780.x, _8878.y < _7780.y));
                }
                else
                {
                    _7784 = _7775;
                }
                if (!_7784)
                {
                    if (_7110)
                    {
                        uint _7797;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 3u) * 4 + 0, 1u, _7797);
                    }
                    nfruCandidateFlags |= (3u << _3026);
                    _9142 = _8892;
                    _9121 = _8872;
                    _9100 = _8864;
                    _9079 = _8859;
                    _9061 = true;
                    _9040 = _8847;
                    continue;
                }
                if (_7110)
                {
                    uint _7807;
                    rw_nfru_diagnostics.InterlockedAdd((_3023 + 4u) * 4 + 0, 1u, _7807);
                }
                float _8880;
                _8880 = 0.0f;
                for (int _8879 = 0; _8879 < 5; )
                {
                    float2 _7829 = float2(_633[_8879]) * cbFI_MvDepthLaneSizeRcp;
                    _8880 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8877 + _7829, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _8878 + _7829, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                    _8879++;
                    continue;
                }
                float _7850 = _8880 * 0.20000000298023223876953125f;
                bool _3118 = _7850 < _8892;
                bool _3125;
                if (_3118)
                {
                    _3125 = _7850 < (_8835 * 0.12000000476837158203125f);
                }
                else
                {
                    _3125 = _3118;
                }
                bool _3132;
                if (_3125)
                {
                    _3132 = (_7167 - _7850) > 0.0199999995529651641845703125f;
                }
                else
                {
                    _3132 = _3125;
                }
                bool _3135 = _3132 && (_7850 < 0.119999997317790985107421875f);
                uint _9055;
                if (_3135)
                {
                    if (_7110)
                    {
                        uint _7879;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 6u) * 4 + 0, 1u, _7879);
                    }
                    nfruCandidateFlags |= (5u << _3026);
                    _9055 = uint(_8846) + 2u;
                }
                else
                {
                    if (_7110)
                    {
                        uint _7889;
                        rw_nfru_diagnostics.InterlockedAdd((_3023 + 5u) * 4 + 0, 1u, _7889);
                    }
                    nfruCandidateFlags |= (4u << _3026);
                    _9055 = _8847;
                }
                bool2 _9158 = _3135.xx;
                _9142 = _3135 ? _7850 : _8892;
                _9121 = float2(_9158.x ? _2817[_8846].x : _8872.x, _9158.y ? _2817[_8846].y : _8872.y);
                _9100 = _8864;
                _9079 = true;
                _9061 = true;
                _9040 = _9055;
            }
            if (_8847 == 2u)
            {
                if (_7110)
                {
                    uint _7899;
                    rw_nfru_diagnostics.InterlockedAdd(156, 1u, _7899);
                }
            }
            else
            {
                if (_8847 == 3u)
                {
                    if (_7110)
                    {
                        uint _7909;
                        rw_nfru_diagnostics.InterlockedAdd(196, 1u, _7909);
                    }
                }
            }
            uint _8868;
            if (_8847 != 0u)
            {
                _8868 = _8847;
            }
            else
            {
                uint _8867;
                if (!_8854)
                {
                    _8867 = _8864 ? 7u : 4u;
                }
                else
                {
                    _8867 = (!_8859) ? 5u : 6u;
                }
                _8868 = _8867;
            }
            _8923 = _8868;
            _8922 = _8872;
            break;
        } while(false);
        bool _7984 = (_2860 & 512u) != 0u;
        if (_7984)
        {
            uint _7988;
            rw_nfru_diagnostics.InterlockedAdd(24, 1u, _7988);
        }
        if (_7984)
        {
            uint _7998;
            rw_nfru_diagnostics.InterlockedAdd((7u + _8923) * 4 + 0, 1u, _7998);
        }
        if ((nfruHoleFlags & 32u) != 0u)
        {
            if (_7984)
            {
                uint _8008;
                rw_nfru_diagnostics.InterlockedAdd((((_8923 == 2u) || (_8923 == 3u)) ? 30u : 31u) * 4 + 0, 1u, _8008);
            }
        }
        uint _7936 = (_2860 >> 16u) & 255u;
        bool _7940 = (_2860 & 1024u) != 0u;
        bool _7949;
        if (!_7940)
        {
            _7949 = (_7936 >= 9u) && (_7936 <= 11u);
        }
        else
        {
            _7949 = _7940;
        }
        if (_7949)
        {
            rw_nfru_diagnostics.Store<uint>((64u + uint((_1978.y * cbFI_MvDepthLaneSize.x) + _2299)) * 4 + 0, ((_8923 | nfruHoleFlags) | nfruCandidateFlags) | (((((nfruHoleFlags & 32u) == 0u) || (_8923 == 2u)) || (_8923 == 3u)) ? 65536u : 0u));
        }
        rw_warped_filled_motion_tp1[_1978] = float4(_8922, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
