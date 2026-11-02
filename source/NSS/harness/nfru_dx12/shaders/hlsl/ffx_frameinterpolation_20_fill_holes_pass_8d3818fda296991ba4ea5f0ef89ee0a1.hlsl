static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static uint _8498;
static float2 _8548;

static const int2 _633[5] = { int2(0, 0), int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
static const int2 _1696[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1705[5] = { 2, 4, 7, 11, 16 };

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
    int2 _1962 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1962.x >= cbFI_MvDepthLaneSize.x, _1962.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        nfruWalkAvgMotion = 1000000015047466219876688855040.0f.xx;
        uint _2044[9];
        _2044[0] = r_warped_motion_qdata_tp1.Load(int3(_1962, 0)).x;
        _2044[1] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(1, 0), 0)).x;
        _2044[2] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(0, 1), 0)).x;
        _2044[3] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(0, -1), 0)).x;
        _2044[4] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(-1, 0), 0)).x;
        _2044[5] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(-1, 1), 0)).x;
        _2044[6] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(1, 1), 0)).x;
        _2044[7] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(-1, -1), 0)).x;
        _2044[8] = r_warped_motion_qdata_tp1.Load(int3(_1962 + int2(1, -1), 0)).x;
        uint _8368;
        _8368 = _2044[0];
        uint _9129;
        for (int _8367 = 1; _8367 < 9; _8368 = _9129, _8367++)
        {
            _9129 = (_2044[_8367] > _8368) ? _2044[_8367] : _8368;
        }
        bool _2144 = _8368 == 0u;
        bool _2151;
        if (_2144)
        {
            _2151 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _2151 = _2144;
        }
        uint _8376;
        if (_2151)
        {
            uint _8370;
            _8370 = 4294967295u;
            uint _2059[8];
            uint _8985;
            for (int _8369 = 0; _8369 < 8; _8370 = _8985, _8369++)
            {
                _2059[_8369] = 0u;
                int _8976 = 0;
                for (;;)
                {
                    if (_8976 < 5)
                    {
                        int2 _2174 = _1962 + (_1696[_8369] * _1705[_8976].xx);
                        bool _2177 = any(bool2(_2174.x < int2(0, 0).x, _2174.y < int2(0, 0).y));
                        bool _2185;
                        if (!_2177)
                        {
                            _2185 = any(bool2(_2174.x >= cbFI_MvDepthLaneSize.x, _2174.y >= cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _2185 = _2177;
                        }
                        if (_2185)
                        {
                            _8985 = _8370;
                            break;
                        }
                        uint4 _2474 = r_warped_motion_qdata_tp1.Load(int3(_2174, 0));
                        uint _2475 = _2474.x;
                        if (_2475 != 0u)
                        {
                            _2059[_8369] = _2475;
                            _8985 = min(_8370, _2475);
                            break;
                        }
                        _8976++;
                        continue;
                    }
                    else
                    {
                        _8985 = _8370;
                        break;
                    }
                }
            }
            bool _2209 = _8370 != 4294967295u;
            if (_2209)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _2484;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _2484);
                }
            }
            bool _2222;
            if (_2209)
            {
                _2222 = (cbFI_NfruT2Flags & 131072u) != 0u;
            }
            else
            {
                _2222 = _2209;
            }
            if (_2222)
            {
                float _8374;
                float2 _8375;
                _8375 = 0.0f.xx;
                _8374 = 0.0f;
                float _8986;
                float2 _8987;
                for (int _8373 = 0; _8373 < 8; _8375 = _8987, _8374 = _8986, _8373++)
                {
                    bool _2232 = _2059[_8373] != 0u;
                    bool _2245;
                    if (_2232)
                    {
                        _2245 = ((_2059[_8373] >> 20u) & 2047u) <= (((_8370 >> 20u) & 2047u) + 55u);
                    }
                    else
                    {
                        _2245 = _2232;
                    }
                    if (_2245)
                    {
                        uint _2501 = _2059[_8373] & 2147483647u;
                        uint _2533 = uint(max((int((_2501 >> 16u) & 15u) - 6), 0));
                        _8987 = _8375 + (float2(float((1 - (2 * int((_2501 >> 15u) & 1u))) * int(((_2501 >> uint(7)) & 127u) << _2533)), float((1 - (2 * int((_2501 >> 14u) & 1u))) * int((_2501 & 127u) << _2533))) * 0.0624427758157253265380859375f);
                        _8986 = _8374 + 1.0f;
                    }
                    else
                    {
                        _8987 = _8375;
                        _8986 = _8374;
                    }
                }
                if (_8374 > 0.0f)
                {
                    nfruWalkAvgMotion = _8375 / _8374.xx;
                }
            }
            _8376 = _2209 ? _8370 : _8368;
        }
        else
        {
            _8376 = _8368;
        }
        nfruHoleFlags = 0u;
        bool _2272 = _2044[0] == 0u;
        bool _2274 = _8376 == 0u;
        int _2276 = _1962.x;
        bool _2277 = _2276 == 0;
        bool _2284;
        if (!_2277)
        {
            _2284 = _1962.y == 0;
        }
        else
        {
            _2284 = _2277;
        }
        bool _2294;
        if (!_2284)
        {
            _2294 = _2276 == (cbFI_MvDepthLaneSize.x - 1);
        }
        else
        {
            _2294 = _2284;
        }
        bool _2304;
        if (!_2294)
        {
            _2304 = _1962.y == (cbFI_MvDepthLaneSize.y - 1);
        }
        else
        {
            _2304 = _2294;
        }
        if (_2272)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2561;
                rw_nfru_diagnostics.InterlockedAdd(88, 1u, _2561);
            }
            nfruHoleFlags |= 16u;
        }
        if (_2274)
        {
            bool _2567 = (cbFI_pad0 & 512u) != 0u;
            if (_2567)
            {
                uint _2571;
                rw_nfru_diagnostics.InterlockedAdd(92, 1u, _2571);
            }
            nfruHoleFlags |= 32u;
            if (!_2304)
            {
                if (_2567)
                {
                    uint _2581;
                    rw_nfru_diagnostics.InterlockedAdd(96, 1u, _2581);
                }
            }
        }
        if (_2304)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2591;
                rw_nfru_diagnostics.InterlockedAdd(108, 1u, _2591);
            }
        }
        if (_2272 && (!_2274))
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2601;
                rw_nfru_diagnostics.InterlockedAdd(112, 1u, _2601);
            }
        }
        float2 _8398;
        if (nfruWalkAvgMotion.x < 100000001504746621987668885504.0f)
        {
            _8398 = nfruWalkAvgMotion;
        }
        else
        {
            uint _2618 = _8376 & 2147483647u;
            uint _2650 = uint(max((int((_2618 >> 16u) & 15u) - 6), 0));
            _8398 = float2(float((1 - (2 * int((_2618 >> 15u) & 1u))) * int(((_2618 >> uint(7)) & 127u) << _2650)), float((1 - (2 * int((_2618 >> 14u) & 1u))) * int((_2618 & 127u) << _2650))) * 0.0624427758157253265380859375f;
        }
        float2 _2345 = _8398 * cbFI_MvDepthLaneSizeRcp;
        bool _2348 = all(bool2(_2345.x == 0.0f.xx.x, _2345.y == 0.0f.xx.y));
        if (_2348)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2678;
                rw_nfru_diagnostics.InterlockedAdd(100, 1u, _2678);
            }
            nfruHoleFlags |= 64u;
        }
        float2 _2356 = float2(cbFI_DisplaySize);
        float _2358 = length(_2345 * _2356);
        if (_2358 <= 0.25f)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2692;
                rw_nfru_diagnostics.InterlockedAdd(104, 1u, _2692);
            }
        }
        uint _2837;
        float2 _2713 = (float2(_1962) + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        float2 _8899;
        uint _8900;
        do
        {
            nfruCandidateFlags = 0u;
            _2837 = cbFI_pad0;
            bool _2839 = (_2837 & 536870912u) != 0u;
            bool _2845;
            if (_2839)
            {
                _2845 = (nfruHoleFlags & 32u) != 0u;
            }
            else
            {
                _2845 = _2839;
            }
            bool _2852;
            if (_2845)
            {
                _2852 = (cbFI_NfruT2Flags & 2u) == 0u;
            }
            else
            {
                _2852 = _2845;
            }
            if (_2852)
            {
                bool _3203;
                float4x4 _8403;
                do
                {
                    float4x4 _3179;
                    bool _8402;
                    do
                    {
                        _3179 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _3203 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_3203)
                        {
                            _8402 = false;
                            break;
                        }
                        uint _3213 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_3213 + 32u) * 4 + 0) != 1u)
                        {
                            _8402 = false;
                            break;
                        }
                        uint _8399;
                        _8399 = 0u;
                        for (; _8399 < 4u; _8399++)
                        {
                            for (uint _8400 = 0u; _8400 < 4u; )
                            {
                                _3179[_8399][_8400] = asfloat(rw_nfru_diagnostics.Load<uint>(((_3213 + (_8399 * 4u)) + _8400) * 4 + 0));
                                _8400++;
                                continue;
                            }
                        }
                        _8402 = true;
                        break;
                    } while(false);
                    if (_8402)
                    {
                        _8403 = _3179;
                        break;
                    }
                    _8403 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _3518;
                float _3521;
                float _3530;
                float _3531;
                float _2857 = 1.0f - cbFI_Timestep;
                uint _8477;
                float2 _8529;
                float2 _8568;
                do
                {
                    float2 _8404;
                    bool _8405;
                    do
                    {
                        _3518 = _2713.x;
                        _3521 = 1.0f - _2713.y;
                        float2 _3527 = (float2(_3518, _3521) * 2.0f) - 1.0f.xx;
                        uint _3584_dummy_parameter;
                        _3530 = _3527.x;
                        _3531 = _3527.y;
                        float4 _3533 = mul(float4(_3530, _3531, r_depth_tp1.Load(int3(int2(floor(_2713 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3584_dummy_parameter))))), 0)).x, 1.0f), _8403);
                        float _3535 = _3533.w;
                        bool _3536 = _3535 > 9.9999999747524270787835121154785e-07f;
                        if (!_3536)
                        {
                            _8405 = _3536;
                            _8404 = 0.0f.xx;
                            break;
                        }
                        float2 _3549 = ((_3533.xy / _3535.xx) + 1.0f.xx) * 0.5f;
                        float2 _3560 = float2(_3549.x - _3518, _3521 - _3549.y);
                        bool _3563 = any(isnan(_3560));
                        bool _3570;
                        if (!_3563)
                        {
                            _3570 = any(isinf(_3560));
                        }
                        else
                        {
                            _3570 = _3563;
                        }
                        bool _3571 = !_3570;
                        bool2 _3574 = _3571.xx;
                        _8405 = _3571;
                        _8404 = float2(_3574.x ? _3560.x : 0.0f.xx.x, _3574.y ? _3560.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8405)
                    {
                        _8568 = _8404;
                        _8529 = _8548;
                        _8477 = 3u;
                        break;
                    }
                    float2 _8407;
                    float2 _8570;
                    _8407 = _2713 - (_8404 * _2857);
                    _8570 = _8404;
                    float2 _3462;
                    float2 _8408;
                    bool _8452;
                    float2 _8468;
                    uint _8478;
                    float2 _8569;
                    int _8406 = 0;
                    for (;;)
                    {
                        if (_8406 < 8)
                        {
                            float _3609;
                            float _3611;
                            float2 _3346 = clamp(_8407, (-1.0f).xx, 2.0f.xx);
                            bool _8409;
                            do
                            {
                                _3609 = _3346.x;
                                _3611 = _3346.y;
                                float _3612 = 1.0f - _3611;
                                uint _3675_dummy_parameter;
                                float4 _3624 = mul(float4((float2(_3609, _3612) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3346 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3675_dummy_parameter))))), 0)).x, 1.0f), _8403);
                                float _3626 = _3624.w;
                                bool _3627 = _3626 > 9.9999999747524270787835121154785e-07f;
                                if (!_3627)
                                {
                                    _8409 = _3627;
                                    _8408 = 0.0f.xx;
                                    break;
                                }
                                float2 _3640 = ((_3624.xy / _3626.xx) + 1.0f.xx) * 0.5f;
                                float2 _3651 = float2(_3640.x - _3609, _3612 - _3640.y);
                                bool _3654 = any(isnan(_3651));
                                bool _3661;
                                if (!_3654)
                                {
                                    _3661 = any(isinf(_3651));
                                }
                                else
                                {
                                    _3661 = _3654;
                                }
                                bool _3662 = !_3661;
                                bool2 _3665 = _3662.xx;
                                _8409 = _3662;
                                _8408 = float2(_3665.x ? _3651.x : 0.0f.xx.x, _3665.y ? _3651.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3696;
                            float _3698;
                            float2 _3355 = _3346 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _8412;
                            bool _8413;
                            do
                            {
                                _3696 = _3355.x;
                                _3698 = _3355.y;
                                float _3699 = 1.0f - _3698;
                                uint _3762_dummy_parameter;
                                float4 _3711 = mul(float4((float2(_3696, _3699) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3355 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3762_dummy_parameter))))), 0)).x, 1.0f), _8403);
                                float _3713 = _3711.w;
                                bool _3714 = _3713 > 9.9999999747524270787835121154785e-07f;
                                if (!_3714)
                                {
                                    _8413 = _3714;
                                    _8412 = 0.0f.xx;
                                    break;
                                }
                                float2 _3727 = ((_3711.xy / _3713.xx) + 1.0f.xx) * 0.5f;
                                float2 _3738 = float2(_3727.x - _3696, _3699 - _3727.y);
                                bool _3741 = any(isnan(_3738));
                                bool _3748;
                                if (!_3741)
                                {
                                    _3748 = any(isinf(_3738));
                                }
                                else
                                {
                                    _3748 = _3741;
                                }
                                bool _3749 = !_3748;
                                bool2 _3752 = _3749.xx;
                                _8413 = _3749;
                                _8412 = float2(_3752.x ? _3738.x : 0.0f.xx.x, _3752.y ? _3738.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3783;
                            float _3785;
                            float2 _3363 = _3346 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _8416;
                            bool _8417;
                            do
                            {
                                _3783 = _3363.x;
                                _3785 = _3363.y;
                                float _3786 = 1.0f - _3785;
                                uint _3849_dummy_parameter;
                                float4 _3798 = mul(float4((float2(_3783, _3786) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_3363 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3849_dummy_parameter))))), 0)).x, 1.0f), _8403);
                                float _3800 = _3798.w;
                                bool _3801 = _3800 > 9.9999999747524270787835121154785e-07f;
                                if (!_3801)
                                {
                                    _8417 = _3801;
                                    _8416 = 0.0f.xx;
                                    break;
                                }
                                float2 _3814 = ((_3798.xy / _3800.xx) + 1.0f.xx) * 0.5f;
                                float2 _3825 = float2(_3814.x - _3783, _3786 - _3814.y);
                                bool _3828 = any(isnan(_3825));
                                bool _3835;
                                if (!_3828)
                                {
                                    _3835 = any(isinf(_3825));
                                }
                                else
                                {
                                    _3835 = _3828;
                                }
                                bool _3836 = !_3835;
                                bool2 _3839 = _3836.xx;
                                _8417 = _3836;
                                _8416 = float2(_3839.x ? _3825.x : 0.0f.xx.x, _3839.y ? _3825.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_8409 && _8413) && _8417))
                            {
                                _8569 = _8408;
                                _8478 = 3u;
                                _8468 = _3346;
                                _8452 = true;
                                break;
                            }
                            float2 _3868 = _3346 + _8408;
                            bool _3897 = (_2837 & 1073741824u) != 0u;
                            float2 _8428;
                            if (_3897)
                            {
                                float _3910 = ((2.0f * _3868.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3922 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3934 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3958 = ((2.0f * _3609) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8428 = (float2(atan(_3910) / _3922, atan((((2.0f * _3868.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3910 * _3910))) / _3934) + 0.5f.xx) - (float2(atan(_3958) / _3922, atan((((2.0f * _3611) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3958 * _3958))) / _3934) + 0.5f.xx);
                            }
                            else
                            {
                                _8428 = _3868 - _3346;
                            }
                            float2 _8429;
                            if (_3897)
                            {
                                float _4034 = ((2.0f * _3609) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4083 = clamp(((((float2(atan(_4034) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3611) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4034 * _4034))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8428 * _2857)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4086 = tan(_4083.x);
                                _8429 = (float2(_4086 / cbFI_DeviceToViewDepth.z, (tan(_4083.y) * sqrt(1.0f + (_4086 * _4086))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8429 = _3346 + (_8428 * _2857);
                            }
                            float2 _3381 = _8429 - _2713;
                            if (length(_3381 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8569 = _8408;
                                _8478 = _8498;
                                _8468 = _3346;
                                _8452 = false;
                                break;
                            }
                            float2 _4128 = _3355 + _8412;
                            float2 _8432;
                            if (_3897)
                            {
                                float _4170 = ((2.0f * _4128.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _4182 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _4194 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4218 = ((2.0f * _3696) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8432 = (float2(atan(_4170) / _4182, atan((((2.0f * _4128.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4170 * _4170))) / _4194) + 0.5f.xx) - (float2(atan(_4218) / _4182, atan((((2.0f * _3698) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4218 * _4218))) / _4194) + 0.5f.xx);
                            }
                            else
                            {
                                _8432 = _4128 - _3355;
                            }
                            float2 _8433;
                            if (_3897)
                            {
                                float _4294 = ((2.0f * _3696) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4343 = clamp(((((float2(atan(_4294) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3698) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4294 * _4294))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8432 * _2857)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4346 = tan(_4343.x);
                                _8433 = (float2(_4346 / cbFI_DeviceToViewDepth.z, (tan(_4343.y) * sqrt(1.0f + (_4346 * _4346))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8433 = _3355 + (_8432 * _2857);
                            }
                            float2 _3403 = (_8433 - _8429) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _4384 = _3363 + _8416;
                            float2 _8436;
                            if (_3897)
                            {
                                float _4426 = ((2.0f * _4384.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _4438 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _4450 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4474 = ((2.0f * _3783) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8436 = (float2(atan(_4426) / _4438, atan((((2.0f * _4384.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4426 * _4426))) / _4450) + 0.5f.xx) - (float2(atan(_4474) / _4438, atan((((2.0f * _3785) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4474 * _4474))) / _4450) + 0.5f.xx);
                            }
                            else
                            {
                                _8436 = _4384 - _3363;
                            }
                            float2 _8437;
                            if (_3897)
                            {
                                float _4550 = ((2.0f * _3783) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4599 = clamp(((((float2(atan(_4550) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3785) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4550 * _4550))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8436 * _2857)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4602 = tan(_4599.x);
                                _8437 = (float2(_4602 / cbFI_DeviceToViewDepth.z, (tan(_4599.y) * sqrt(1.0f + (_4602 * _4602))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8437 = _3363 + (_8436 * _2857);
                            }
                            float2 _3417 = (_8437 - _8429) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _3419 = _3403.x;
                            float _3421 = _3417.y;
                            float _3424 = _3417.x;
                            float _3426 = _3403.y;
                            float _3428 = (_3419 * _3421) - (_3424 * _3426);
                            if (abs(_3428) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8569 = _8408;
                                _8478 = 3u;
                                _8468 = _3346;
                                _8452 = true;
                                break;
                            }
                            float _3437 = _3381.x;
                            float _3442 = _3381.y;
                            _3462 = _3346 - (float2((_3421 * _3437) - (_3424 * _3442), ((-_3426) * _3437) + (_3419 * _3442)) / _3428.xx);
                            _8407 = _3462;
                            _8406++;
                            _8570 = _8408;
                            continue;
                        }
                        else
                        {
                            _8569 = _8570;
                            _8478 = _8498;
                            _8468 = _8407;
                            _8452 = false;
                            break;
                        }
                    }
                    if (_8452)
                    {
                        _8568 = _8569;
                        _8529 = _8468;
                        _8477 = _8478;
                        break;
                    }
                    float _4642;
                    float _4644;
                    float2 _8469;
                    bool _8470;
                    do
                    {
                        _4642 = _8468.x;
                        _4644 = _8468.y;
                        float _4645 = 1.0f - _4644;
                        uint _4708_dummy_parameter;
                        float4 _4657 = mul(float4((float2(_4642, _4645) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_8468 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4708_dummy_parameter))))), 0)).x, 1.0f), _8403);
                        float _4659 = _4657.w;
                        bool _4660 = _4659 > 9.9999999747524270787835121154785e-07f;
                        if (!_4660)
                        {
                            _8470 = _4660;
                            _8469 = 0.0f.xx;
                            break;
                        }
                        float2 _4673 = ((_4657.xy / _4659.xx) + 1.0f.xx) * 0.5f;
                        float2 _4684 = float2(_4673.x - _4642, _4645 - _4673.y);
                        bool _4687 = any(isnan(_4684));
                        bool _4694;
                        if (!_4687)
                        {
                            _4694 = any(isinf(_4684));
                        }
                        else
                        {
                            _4694 = _4687;
                        }
                        bool _4695 = !_4694;
                        bool2 _4698 = _4695.xx;
                        _8470 = _4695;
                        _8469 = float2(_4698.x ? _4684.x : 0.0f.xx.x, _4698.y ? _4684.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8470)
                    {
                        _8568 = _8469;
                        _8529 = _8468;
                        _8477 = 3u;
                        break;
                    }
                    float2 _4727 = _8468 + _8469;
                    bool _4756 = (_2837 & 1073741824u) != 0u;
                    float2 _8473;
                    if (_4756)
                    {
                        float _4769 = ((2.0f * _4727.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4781 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4793 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4817 = ((2.0f * _4642) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8473 = (float2(atan(_4769) / _4781, atan((((2.0f * _4727.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4769 * _4769))) / _4793) + 0.5f.xx) - (float2(atan(_4817) / _4781, atan((((2.0f * _4644) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4817 * _4817))) / _4793) + 0.5f.xx);
                    }
                    else
                    {
                        _8473 = _4727 - _8468;
                    }
                    float2 _8474;
                    if (_4756)
                    {
                        float _4893 = ((2.0f * _4642) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _4942 = clamp(((((float2(atan(_4893) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4644) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4893 * _4893))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8473 * _2857)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _4945 = tan(_4942.x);
                        _8474 = (float2(_4945 / cbFI_DeviceToViewDepth.z, (tan(_4942.y) * sqrt(1.0f + (_4945 * _4945))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _8474 = _8468 + (_8473 * _2857);
                    }
                    if (length((_8474 - _2713) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8568 = _8469;
                        _8529 = _8468;
                        _8477 = 2u;
                        break;
                    }
                    bool _3494 = all(bool2(_8468.x > cbFI_MvDepthLaneSizeRcp.x, _8468.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _3503;
                    if (_3494)
                    {
                        float2 _3499 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _3503 = all(bool2(_8468.x < _3499.x, _8468.y < _3499.y));
                    }
                    else
                    {
                        _3503 = _3494;
                    }
                    _8568 = _8469;
                    _8529 = _8468;
                    _8477 = _3503 ? 0u : 1u;
                    break;
                } while(false);
                if (_8477 == 0u)
                {
                    if ((_2837 & 512u) != 0u)
                    {
                        uint _4990;
                        rw_nfru_diagnostics.InterlockedAdd(4, 1u, _4990);
                    }
                    float2 _2868 = _8529 + _8568;
                    float2 _8898;
                    if ((_2837 & 1073741824u) != 0u)
                    {
                        float _5028 = ((2.0f * _2868.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _5040 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _5052 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _5076 = ((2.0f * _8529.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8898 = (float2(atan(_5028) / _5040, atan((((2.0f * _2868.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5028 * _5028))) / _5052) + 0.5f.xx) - (float2(atan(_5076) / _5040, atan((((2.0f * _8529.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5076 * _5076))) / _5052) + 0.5f.xx);
                    }
                    else
                    {
                        _8898 = _2868 - _8529;
                    }
                    _8900 = 2u;
                    _8899 = _8898;
                    break;
                }
                float4x4 _8584;
                do
                {
                    float4x4 _5116;
                    bool _8583;
                    do
                    {
                        _5116 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3203)
                        {
                            _8583 = false;
                            break;
                        }
                        uint _5150 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_5150 + 32u) * 4 + 0) != 1u)
                        {
                            _8583 = false;
                            break;
                        }
                        uint _8580;
                        _8580 = 0u;
                        for (; _8580 < 4u; _8580++)
                        {
                            for (uint _8581 = 0u; _8581 < 4u; )
                            {
                                _5116[_8580][_8581] = asfloat(rw_nfru_diagnostics.Load<uint>((((_5150 + 16u) + (_8580 * 4u)) + _8581) * 4 + 0));
                                _8581++;
                                continue;
                            }
                        }
                        _8583 = true;
                        break;
                    } while(false);
                    if (_8583)
                    {
                        _8584 = _5116;
                        break;
                    }
                    _8584 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                uint _8658;
                float2 _8735;
                float2 _8799;
                do
                {
                    float2 _8585;
                    bool _8586;
                    do
                    {
                        uint _5521_dummy_parameter;
                        float4 _5470 = mul(float4(_3530, _3531, r_depth_tp1.Load(int3(int2(floor(_2713 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5521_dummy_parameter))))), 0)).x, 1.0f), _8584);
                        float _5472 = _5470.w;
                        bool _5473 = _5472 > 9.9999999747524270787835121154785e-07f;
                        if (!_5473)
                        {
                            _8586 = _5473;
                            _8585 = 0.0f.xx;
                            break;
                        }
                        float2 _5486 = ((_5470.xy / _5472.xx) + 1.0f.xx) * 0.5f;
                        float2 _5497 = float2(_5486.x - _3518, _3521 - _5486.y);
                        bool _5500 = any(isnan(_5497));
                        bool _5507;
                        if (!_5500)
                        {
                            _5507 = any(isinf(_5497));
                        }
                        else
                        {
                            _5507 = _5500;
                        }
                        bool _5508 = !_5507;
                        bool2 _5511 = _5508.xx;
                        _8586 = _5508;
                        _8585 = float2(_5511.x ? _5497.x : 0.0f.xx.x, _5511.y ? _5497.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8586)
                    {
                        _8799 = _8585;
                        _8735 = _8548;
                        _8658 = 3u;
                        break;
                    }
                    float2 _8588;
                    float2 _8801;
                    _8588 = _2713 - (_8585 * cbFI_Timestep);
                    _8801 = _8585;
                    float2 _5399;
                    float2 _8589;
                    bool _8633;
                    float2 _8649;
                    uint _8659;
                    float2 _8800;
                    int _8587 = 0;
                    for (;;)
                    {
                        if (_8587 < 8)
                        {
                            float _5546;
                            float _5548;
                            float2 _5283 = clamp(_8588, (-1.0f).xx, 2.0f.xx);
                            bool _8590;
                            do
                            {
                                _5546 = _5283.x;
                                _5548 = _5283.y;
                                float _5549 = 1.0f - _5548;
                                uint _5612_dummy_parameter;
                                float4 _5561 = mul(float4((float2(_5546, _5549) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5283 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5612_dummy_parameter))))), 0)).x, 1.0f), _8584);
                                float _5563 = _5561.w;
                                bool _5564 = _5563 > 9.9999999747524270787835121154785e-07f;
                                if (!_5564)
                                {
                                    _8590 = _5564;
                                    _8589 = 0.0f.xx;
                                    break;
                                }
                                float2 _5577 = ((_5561.xy / _5563.xx) + 1.0f.xx) * 0.5f;
                                float2 _5588 = float2(_5577.x - _5546, _5549 - _5577.y);
                                bool _5591 = any(isnan(_5588));
                                bool _5598;
                                if (!_5591)
                                {
                                    _5598 = any(isinf(_5588));
                                }
                                else
                                {
                                    _5598 = _5591;
                                }
                                bool _5599 = !_5598;
                                bool2 _5602 = _5599.xx;
                                _8590 = _5599;
                                _8589 = float2(_5602.x ? _5588.x : 0.0f.xx.x, _5602.y ? _5588.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5633;
                            float _5635;
                            float2 _5292 = _5283 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _8593;
                            bool _8594;
                            do
                            {
                                _5633 = _5292.x;
                                _5635 = _5292.y;
                                float _5636 = 1.0f - _5635;
                                uint _5699_dummy_parameter;
                                float4 _5648 = mul(float4((float2(_5633, _5636) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5292 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5699_dummy_parameter))))), 0)).x, 1.0f), _8584);
                                float _5650 = _5648.w;
                                bool _5651 = _5650 > 9.9999999747524270787835121154785e-07f;
                                if (!_5651)
                                {
                                    _8594 = _5651;
                                    _8593 = 0.0f.xx;
                                    break;
                                }
                                float2 _5664 = ((_5648.xy / _5650.xx) + 1.0f.xx) * 0.5f;
                                float2 _5675 = float2(_5664.x - _5633, _5636 - _5664.y);
                                bool _5678 = any(isnan(_5675));
                                bool _5685;
                                if (!_5678)
                                {
                                    _5685 = any(isinf(_5675));
                                }
                                else
                                {
                                    _5685 = _5678;
                                }
                                bool _5686 = !_5685;
                                bool2 _5689 = _5686.xx;
                                _8594 = _5686;
                                _8593 = float2(_5689.x ? _5675.x : 0.0f.xx.x, _5689.y ? _5675.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5720;
                            float _5722;
                            float2 _5300 = _5283 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _8597;
                            bool _8598;
                            do
                            {
                                _5720 = _5300.x;
                                _5722 = _5300.y;
                                float _5723 = 1.0f - _5722;
                                uint _5786_dummy_parameter;
                                float4 _5735 = mul(float4((float2(_5720, _5723) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5300 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5786_dummy_parameter))))), 0)).x, 1.0f), _8584);
                                float _5737 = _5735.w;
                                bool _5738 = _5737 > 9.9999999747524270787835121154785e-07f;
                                if (!_5738)
                                {
                                    _8598 = _5738;
                                    _8597 = 0.0f.xx;
                                    break;
                                }
                                float2 _5751 = ((_5735.xy / _5737.xx) + 1.0f.xx) * 0.5f;
                                float2 _5762 = float2(_5751.x - _5720, _5723 - _5751.y);
                                bool _5765 = any(isnan(_5762));
                                bool _5772;
                                if (!_5765)
                                {
                                    _5772 = any(isinf(_5762));
                                }
                                else
                                {
                                    _5772 = _5765;
                                }
                                bool _5773 = !_5772;
                                bool2 _5776 = _5773.xx;
                                _8598 = _5773;
                                _8597 = float2(_5776.x ? _5762.x : 0.0f.xx.x, _5776.y ? _5762.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_8590 && _8594) && _8598))
                            {
                                _8800 = _8589;
                                _8659 = 3u;
                                _8649 = _5283;
                                _8633 = true;
                                break;
                            }
                            float2 _5805 = _5283 + _8589;
                            bool _5834 = (_2837 & 1073741824u) != 0u;
                            float2 _8609;
                            if (_5834)
                            {
                                float _5847 = ((2.0f * _5805.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5859 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5871 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5895 = ((2.0f * _5546) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8609 = (float2(atan(_5847) / _5859, atan((((2.0f * _5805.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5847 * _5847))) / _5871) + 0.5f.xx) - (float2(atan(_5895) / _5859, atan((((2.0f * _5548) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5895 * _5895))) / _5871) + 0.5f.xx);
                            }
                            else
                            {
                                _8609 = _5805 - _5283;
                            }
                            float2 _8610;
                            if (_5834)
                            {
                                float _5971 = ((2.0f * _5546) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6020 = clamp(((((float2(atan(_5971) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5548) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5971 * _5971))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8609 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6023 = tan(_6020.x);
                                _8610 = (float2(_6023 / cbFI_DeviceToViewDepth.z, (tan(_6020.y) * sqrt(1.0f + (_6023 * _6023))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8610 = _5283 + (_8609 * cbFI_Timestep);
                            }
                            float2 _5318 = _8610 - _2713;
                            if (length(_5318 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8800 = _8589;
                                _8659 = _8498;
                                _8649 = _5283;
                                _8633 = false;
                                break;
                            }
                            float2 _6065 = _5292 + _8593;
                            float2 _8613;
                            if (_5834)
                            {
                                float _6107 = ((2.0f * _6065.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _6119 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _6131 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _6155 = ((2.0f * _5633) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8613 = (float2(atan(_6107) / _6119, atan((((2.0f * _6065.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6107 * _6107))) / _6131) + 0.5f.xx) - (float2(atan(_6155) / _6119, atan((((2.0f * _5635) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6155 * _6155))) / _6131) + 0.5f.xx);
                            }
                            else
                            {
                                _8613 = _6065 - _5292;
                            }
                            float2 _8614;
                            if (_5834)
                            {
                                float _6231 = ((2.0f * _5633) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6280 = clamp(((((float2(atan(_6231) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5635) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6231 * _6231))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8613 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6283 = tan(_6280.x);
                                _8614 = (float2(_6283 / cbFI_DeviceToViewDepth.z, (tan(_6280.y) * sqrt(1.0f + (_6283 * _6283))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8614 = _5292 + (_8613 * cbFI_Timestep);
                            }
                            float2 _5340 = (_8614 - _8610) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _6321 = _5300 + _8597;
                            float2 _8617;
                            if (_5834)
                            {
                                float _6363 = ((2.0f * _6321.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _6375 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _6387 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _6411 = ((2.0f * _5720) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _8617 = (float2(atan(_6363) / _6375, atan((((2.0f * _6321.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6363 * _6363))) / _6387) + 0.5f.xx) - (float2(atan(_6411) / _6375, atan((((2.0f * _5722) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6411 * _6411))) / _6387) + 0.5f.xx);
                            }
                            else
                            {
                                _8617 = _6321 - _5300;
                            }
                            float2 _8618;
                            if (_5834)
                            {
                                float _6487 = ((2.0f * _5720) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _6536 = clamp(((((float2(atan(_6487) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5722) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6487 * _6487))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8617 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _6539 = tan(_6536.x);
                                _8618 = (float2(_6539 / cbFI_DeviceToViewDepth.z, (tan(_6536.y) * sqrt(1.0f + (_6539 * _6539))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _8618 = _5300 + (_8617 * cbFI_Timestep);
                            }
                            float2 _5354 = (_8618 - _8610) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _5356 = _5340.x;
                            float _5358 = _5354.y;
                            float _5361 = _5354.x;
                            float _5363 = _5340.y;
                            float _5365 = (_5356 * _5358) - (_5361 * _5363);
                            if (abs(_5365) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8800 = _8589;
                                _8659 = 3u;
                                _8649 = _5283;
                                _8633 = true;
                                break;
                            }
                            float _5374 = _5318.x;
                            float _5379 = _5318.y;
                            _5399 = _5283 - (float2((_5358 * _5374) - (_5361 * _5379), ((-_5363) * _5374) + (_5356 * _5379)) / _5365.xx);
                            _8588 = _5399;
                            _8587++;
                            _8801 = _8589;
                            continue;
                        }
                        else
                        {
                            _8800 = _8801;
                            _8659 = _8498;
                            _8649 = _8588;
                            _8633 = false;
                            break;
                        }
                    }
                    if (_8633)
                    {
                        _8799 = _8800;
                        _8735 = _8649;
                        _8658 = _8659;
                        break;
                    }
                    float _6579;
                    float _6581;
                    float2 _8650;
                    bool _8651;
                    do
                    {
                        _6579 = _8649.x;
                        _6581 = _8649.y;
                        float _6582 = 1.0f - _6581;
                        uint _6645_dummy_parameter;
                        float4 _6594 = mul(float4((float2(_6579, _6582) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_8649 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6645_dummy_parameter))))), 0)).x, 1.0f), _8584);
                        float _6596 = _6594.w;
                        bool _6597 = _6596 > 9.9999999747524270787835121154785e-07f;
                        if (!_6597)
                        {
                            _8651 = _6597;
                            _8650 = 0.0f.xx;
                            break;
                        }
                        float2 _6610 = ((_6594.xy / _6596.xx) + 1.0f.xx) * 0.5f;
                        float2 _6621 = float2(_6610.x - _6579, _6582 - _6610.y);
                        bool _6624 = any(isnan(_6621));
                        bool _6631;
                        if (!_6624)
                        {
                            _6631 = any(isinf(_6621));
                        }
                        else
                        {
                            _6631 = _6624;
                        }
                        bool _6632 = !_6631;
                        bool2 _6635 = _6632.xx;
                        _8651 = _6632;
                        _8650 = float2(_6635.x ? _6621.x : 0.0f.xx.x, _6635.y ? _6621.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_8651)
                    {
                        _8799 = _8650;
                        _8735 = _8649;
                        _8658 = 3u;
                        break;
                    }
                    float2 _6664 = _8649 + _8650;
                    bool _6693 = (_2837 & 1073741824u) != 0u;
                    float2 _8654;
                    if (_6693)
                    {
                        float _6706 = ((2.0f * _6664.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6718 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6730 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6754 = ((2.0f * _6579) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8654 = (float2(atan(_6706) / _6718, atan((((2.0f * _6664.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6706 * _6706))) / _6730) + 0.5f.xx) - (float2(atan(_6754) / _6718, atan((((2.0f * _6581) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6754 * _6754))) / _6730) + 0.5f.xx);
                    }
                    else
                    {
                        _8654 = _6664 - _8649;
                    }
                    float2 _8655;
                    if (_6693)
                    {
                        float _6830 = ((2.0f * _6579) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _6879 = clamp(((((float2(atan(_6830) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _6581) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6830 * _6830))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_8654 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6882 = tan(_6879.x);
                        _8655 = (float2(_6882 / cbFI_DeviceToViewDepth.z, (tan(_6879.y) * sqrt(1.0f + (_6882 * _6882))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _8655 = _8649 + (_8654 * cbFI_Timestep);
                    }
                    if (length((_8655 - _2713) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8799 = _8650;
                        _8735 = _8649;
                        _8658 = 2u;
                        break;
                    }
                    bool _5431 = all(bool2(_8649.x > cbFI_MvDepthLaneSizeRcp.x, _8649.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _5440;
                    if (_5431)
                    {
                        float2 _5436 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _5440 = all(bool2(_8649.x < _5436.x, _8649.y < _5436.y));
                    }
                    else
                    {
                        _5440 = _5431;
                    }
                    _8799 = _8650;
                    _8735 = _8649;
                    _8658 = _5440 ? 0u : 1u;
                    break;
                } while(false);
                if (_8658 == 0u)
                {
                    if ((_2837 & 512u) != 0u)
                    {
                        uint _6927;
                        rw_nfru_diagnostics.InterlockedAdd(8, 1u, _6927);
                    }
                    float2 _2884 = _8735 + _8799;
                    float2 _8895;
                    if ((_2837 & 1073741824u) != 0u)
                    {
                        float _6965 = ((2.0f * _2884.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6977 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6989 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _7013 = ((2.0f * _8735.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8895 = (float2(atan(_6965) / _6977, atan((((2.0f * _2884.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6965 * _6965))) / _6989) + 0.5f.xx) - (float2(atan(_7013) / _6977, atan((((2.0f * _8735.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7013 * _7013))) / _6989) + 0.5f.xx);
                    }
                    else
                    {
                        _8895 = _2884 - _8735;
                    }
                    _8900 = 2u;
                    _8899 = -_8895;
                    break;
                }
                bool _7053 = (_2837 & 512u) != 0u;
                if (_7053)
                {
                    uint _7057;
                    rw_nfru_diagnostics.InterlockedAdd(20, 1u, _7057);
                }
                if (_8658 == 1u)
                {
                    if (_7053)
                    {
                        uint _7067;
                        rw_nfru_diagnostics.InterlockedAdd(116, 1u, _7067);
                    }
                }
                else
                {
                    if (_8658 == 2u)
                    {
                        if (_7053)
                        {
                            uint _7077;
                            rw_nfru_diagnostics.InterlockedAdd(248, 1u, _7077);
                        }
                    }
                }
            }
            if (_2358 > 0.25f)
            {
                _8900 = 0u;
                _8899 = _2345;
                break;
            }
            bool _7087 = (_2837 & 512u) != 0u;
            if (_7087)
            {
                uint _7091;
                rw_nfru_diagnostics.InterlockedAdd(216, 1u, _7091);
            }
            if (_2348)
            {
                if (_7087)
                {
                    uint _7101;
                    rw_nfru_diagnostics.InterlockedAdd(212, 1u, _7101);
                }
            }
            float _8812;
            _8812 = 0.0f;
            for (int _8811 = 0; _8811 < 5; )
            {
                float2 _7126 = _2713 + (float2(_633[_8811]) * cbFI_MvDepthLaneSizeRcp);
                _8812 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _7126, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _7126, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                _8811++;
                continue;
            }
            float _7144 = _8812 * 0.20000000298023223876953125f;
            if (_7144 < 0.0199999995529651641845703125f)
            {
                _8900 = 1u;
                _8899 = _2345;
                break;
            }
            uint _7207;
            float _2927 = _2713.x;
            float _2929 = _2713.y;
            float _2930 = 1.0f - _2929;
            uint _7171_dummy_parameter;
            float4x4 _8817;
            do
            {
                float4x4 _7185;
                bool _8816;
                do
                {
                    _7185 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    _7207 = cbFI_NfruT2Flags;
                    if ((_7207 & 524288u) == 0u)
                    {
                        _8816 = false;
                        break;
                    }
                    uint _7219 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_7219 + 32u) * 4 + 0) != 1u)
                    {
                        _8816 = false;
                        break;
                    }
                    uint _8813;
                    _8813 = 0u;
                    for (; _8813 < 4u; _8813++)
                    {
                        for (uint _8814 = 0u; _8814 < 4u; )
                        {
                            _7185[_8813][_8814] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7219 + (_8813 * 4u)) + _8814) * 4 + 0));
                            _8814++;
                            continue;
                        }
                    }
                    _8816 = true;
                    break;
                } while(false);
                if (_8816)
                {
                    _8817 = _7185;
                    break;
                }
                _8817 = cbFI_MotionTP1ToTM1;
                break;
            } while(false);
            float4 _2943 = mul(float4((float2(_2927, _2930) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2713 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7171_dummy_parameter))))), 0)).x, 1.0f), _8817);
            float _2945 = _2943.w;
            bool _2946 = _2945 > 9.9999999747524270787835121154785e-07f;
            float2 _8819;
            if (_2946)
            {
                float2 _2956 = ((_2943.xy / _2945.xx) + 1.0f.xx) * 0.5f;
                _8819 = float2(_2956.x - _2927, _2930 - _2956.y);
            }
            else
            {
                _8819 = 0.0f.xx;
            }
            if (!_2946)
            {
                if (_7087)
                {
                    uint _7295;
                    rw_nfru_diagnostics.InterlockedAdd(208, 1u, _7295);
                }
            }
            float2 _2978 = _2713 + _8819;
            bool _7320 = (_2837 & 1073741824u) != 0u;
            float2 _8821;
            if (_7320)
            {
                float _7333 = ((2.0f * _2978.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float _7345 = 2.0f * cbFI_DeviceToViewDepth.z;
                float _7357 = 2.0f * cbFI_DeviceToViewDepth.w;
                float _7381 = ((2.0f * _2927) - 1.0f) * cbFI_DeviceToViewDepth.z;
                _8821 = (float2(atan(_7333) / _7345, atan((((2.0f * _2978.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7333 * _7333))) / _7357) + 0.5f.xx) - (float2(atan(_7381) / _7345, atan((((2.0f * _2929) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7381 * _7381))) / _7357) + 0.5f.xx);
            }
            else
            {
                _8821 = _2978 - _2713;
            }
            bool2 _9132 = ((_7207 & 8192u) != 0u).xx;
            float2 _2990[2] = { float2(_9132.x ? 0.0f.xx.x : _8821.x, _9132.y ? 0.0f.xx.y : _8821.y), -r_warped_filled_flow_tm1.Load(int3(clamp(int2(_2713 * float2(cbFI_FlowLaneSize)), int2(0, 0), cbFI_FlowLaneSize - int2(1, 1)), 0)).xy };
            float2 _2794[2] = _2990;
            uint _8824;
            bool _8831;
            bool _8836;
            bool _8841;
            float2 _8849;
            _8849 = _2345;
            _8841 = false;
            _8836 = false;
            _8831 = false;
            _8824 = 0u;
            uint _9017;
            bool _9038;
            bool _9056;
            bool _9077;
            float2 _9098;
            float _9119;
            int _8823 = 0;
            float _8869 = _7144;
            for (; _8823 < 2; _8869 = _9119, _8849 = _9098, _8841 = _9077, _8836 = _9056, _8831 = _9038, _8824 = _9017, _8823++)
            {
                bool _2999 = _8823 == 0;
                uint _3000 = _2999 ? 32u : 42u;
                uint _3003 = _2999 ? 8u : 12u;
                if (_7087)
                {
                    uint _7425;
                    rw_nfru_diagnostics.InterlockedAdd(_3000 * 4 + 0, 1u, _7425);
                }
                bool _3011 = any(isnan(_2794[_8823]));
                bool _3018;
                if (!_3011)
                {
                    _3018 = any(isinf(_2794[_8823]));
                }
                else
                {
                    _3018 = _3011;
                }
                if (_3018)
                {
                    if (_7087)
                    {
                        uint _7435;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 1u) * 4 + 0, 1u, _7435);
                    }
                    nfruCandidateFlags |= (1u << _3003);
                    _9119 = _8869;
                    _9098 = _8849;
                    _9077 = true;
                    _9056 = _8836;
                    _9038 = _8831;
                    _9017 = _8824;
                    continue;
                }
                float _3032 = length(_2794[_8823] * _2356);
                if (_3032 < 1.0f)
                {
                    if (_7087)
                    {
                        uint _7449;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 2u) * 4 + 0, 1u, _7449);
                    }
                    nfruCandidateFlags |= (2u << _3003);
                    _9119 = _8869;
                    _9098 = _8849;
                    _9077 = _8841;
                    _9056 = _8836;
                    _9038 = _8831;
                    _9017 = _8824;
                    continue;
                }
                if (_3032 > 256.0f)
                {
                    if (_7087)
                    {
                        uint _7459;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 8u) * 4 + 0, 1u, _7459);
                    }
                }
                if (_3032 > float(max(cbFI_DisplaySize.x, cbFI_DisplaySize.y)))
                {
                    if (_7087)
                    {
                        uint _7477;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 9u) * 4 + 0, 1u, _7477);
                    }
                }
                float2 _8854;
                if (_7320)
                {
                    float _7523 = ((2.0f * _2927) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7572 = clamp(((((float2(atan(_7523) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2929) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7523 * _7523))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2794[_8823] * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7575 = tan(_7572.x);
                    _8854 = (float2(_7575 / cbFI_DeviceToViewDepth.z, (tan(_7572.y) * sqrt(1.0f + (_7575 * _7575))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8854 = _2713 + (_2794[_8823] * cbFI_Timestep);
                }
                float _3070 = cbFI_Timestep - 1.0f;
                float2 _8855;
                if (_7320)
                {
                    float _7648 = ((2.0f * _2927) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7697 = clamp(((((float2(atan(_7648) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2929) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7648 * _7648))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2794[_8823] * _3070)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7700 = tan(_7697.x);
                    _8855 = (float2(_7700 / cbFI_DeviceToViewDepth.z, (tan(_7697.y) * sqrt(1.0f + (_7700 * _7700))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8855 = _2713 + (_2794[_8823] * _3070);
                }
                bool _7736 = all(bool2(_8854.x > cbFI_MvDepthLaneSizeRcp.x, _8854.y > cbFI_MvDepthLaneSizeRcp.y));
                bool _7745;
                if (_7736)
                {
                    float2 _7741 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7745 = all(bool2(_8854.x < _7741.x, _8854.y < _7741.y));
                }
                else
                {
                    _7745 = _7736;
                }
                bool _7752;
                if (_7745)
                {
                    _7752 = all(bool2(_8855.x > cbFI_MvDepthLaneSizeRcp.x, _8855.y > cbFI_MvDepthLaneSizeRcp.y));
                }
                else
                {
                    _7752 = _7745;
                }
                bool _7761;
                if (_7752)
                {
                    float2 _7757 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7761 = all(bool2(_8855.x < _7757.x, _8855.y < _7757.y));
                }
                else
                {
                    _7761 = _7752;
                }
                if (!_7761)
                {
                    if (_7087)
                    {
                        uint _7774;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 3u) * 4 + 0, 1u, _7774);
                    }
                    nfruCandidateFlags |= (3u << _3003);
                    _9119 = _8869;
                    _9098 = _8849;
                    _9077 = _8841;
                    _9056 = _8836;
                    _9038 = true;
                    _9017 = _8824;
                    continue;
                }
                if (_7087)
                {
                    uint _7784;
                    rw_nfru_diagnostics.InterlockedAdd((_3000 + 4u) * 4 + 0, 1u, _7784);
                }
                float _8857;
                _8857 = 0.0f;
                for (int _8856 = 0; _8856 < 5; )
                {
                    float2 _7806 = float2(_633[_8856]) * cbFI_MvDepthLaneSizeRcp;
                    _8857 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8854 + _7806, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _8855 + _7806, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                    _8856++;
                    continue;
                }
                float _7827 = _8857 * 0.20000000298023223876953125f;
                bool _3095 = _7827 < _8869;
                bool _3102;
                if (_3095)
                {
                    _3102 = _7827 < (_8812 * 0.12000000476837158203125f);
                }
                else
                {
                    _3102 = _3095;
                }
                bool _3109;
                if (_3102)
                {
                    _3109 = (_7144 - _7827) > 0.0199999995529651641845703125f;
                }
                else
                {
                    _3109 = _3102;
                }
                bool _3112 = _3109 && (_7827 < 0.119999997317790985107421875f);
                uint _9032;
                if (_3112)
                {
                    if (_7087)
                    {
                        uint _7856;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 6u) * 4 + 0, 1u, _7856);
                    }
                    nfruCandidateFlags |= (5u << _3003);
                    _9032 = uint(_8823) + 2u;
                }
                else
                {
                    if (_7087)
                    {
                        uint _7866;
                        rw_nfru_diagnostics.InterlockedAdd((_3000 + 5u) * 4 + 0, 1u, _7866);
                    }
                    nfruCandidateFlags |= (4u << _3003);
                    _9032 = _8824;
                }
                bool2 _9135 = _3112.xx;
                _9119 = _3112 ? _7827 : _8869;
                _9098 = float2(_9135.x ? _2794[_8823].x : _8849.x, _9135.y ? _2794[_8823].y : _8849.y);
                _9077 = _8841;
                _9056 = true;
                _9038 = true;
                _9017 = _9032;
            }
            if (_8824 == 2u)
            {
                if (_7087)
                {
                    uint _7876;
                    rw_nfru_diagnostics.InterlockedAdd(156, 1u, _7876);
                }
            }
            else
            {
                if (_8824 == 3u)
                {
                    if (_7087)
                    {
                        uint _7886;
                        rw_nfru_diagnostics.InterlockedAdd(196, 1u, _7886);
                    }
                }
            }
            uint _8845;
            if (_8824 != 0u)
            {
                _8845 = _8824;
            }
            else
            {
                uint _8844;
                if (!_8831)
                {
                    _8844 = _8841 ? 7u : 4u;
                }
                else
                {
                    _8844 = (!_8836) ? 5u : 6u;
                }
                _8845 = _8844;
            }
            _8900 = _8845;
            _8899 = _8849;
            break;
        } while(false);
        bool _7961 = (_2837 & 512u) != 0u;
        if (_7961)
        {
            uint _7965;
            rw_nfru_diagnostics.InterlockedAdd(24, 1u, _7965);
        }
        if (_7961)
        {
            uint _7975;
            rw_nfru_diagnostics.InterlockedAdd((7u + _8900) * 4 + 0, 1u, _7975);
        }
        if ((nfruHoleFlags & 32u) != 0u)
        {
            if (_7961)
            {
                uint _7985;
                rw_nfru_diagnostics.InterlockedAdd((((_8900 == 2u) || (_8900 == 3u)) ? 30u : 31u) * 4 + 0, 1u, _7985);
            }
        }
        uint _7913 = (_2837 >> 16u) & 255u;
        bool _7917 = (_2837 & 1024u) != 0u;
        bool _7926;
        if (!_7917)
        {
            _7926 = (_7913 >= 9u) && (_7913 <= 11u);
        }
        else
        {
            _7926 = _7917;
        }
        if (_7926)
        {
            rw_nfru_diagnostics.Store<uint>((64u + uint((_1962.y * cbFI_MvDepthLaneSize.x) + _2276)) * 4 + 0, ((_8900 | nfruHoleFlags) | nfruCandidateFlags) | (((((nfruHoleFlags & 32u) == 0u) || (_8900 == 2u)) || (_8900 == 3u)) ? 65536u : 0u));
        }
        rw_warped_filled_motion_tp1[_1962] = float4(_8899, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
