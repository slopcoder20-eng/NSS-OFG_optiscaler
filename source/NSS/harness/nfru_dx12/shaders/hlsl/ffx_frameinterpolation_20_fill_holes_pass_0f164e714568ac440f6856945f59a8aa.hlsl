static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static uint _7830;
static float2 _7871;

static const int2 _527[5] = { int2(0, 0), int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
static const int2 _1585[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1594[5] = { 2, 4, 7, 11, 16 };

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
    int2 _1774 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1774.x >= cbFI_MvDepthLaneSize.x, _1774.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        uint _1841[9];
        _1841[0] = r_warped_motion_qdata_tp1.Load(int3(_1774, 0)).x;
        _1841[1] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(1, 0), 0)).x;
        _1841[2] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(0, 1), 0)).x;
        _1841[3] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(0, -1), 0)).x;
        _1841[4] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(-1, 0), 0)).x;
        _1841[5] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(-1, 1), 0)).x;
        _1841[6] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(1, 1), 0)).x;
        _1841[7] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(-1, -1), 0)).x;
        _1841[8] = r_warped_motion_qdata_tp1.Load(int3(_1774 + int2(1, -1), 0)).x;
        uint _7718;
        _7718 = _1841[0];
        uint _8382;
        for (int _7717 = 1; _7717 < 9; _7718 = _8382, _7717++)
        {
            _8382 = (_1841[_7717] > _7718) ? _1841[_7717] : _7718;
        }
        bool _1935 = _7718 == 0u;
        bool _1942;
        if (_1935)
        {
            _1942 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _1942 = _1935;
        }
        uint _7721;
        if (_1942)
        {
            uint _7720;
            _7720 = 4294967295u;
            uint _8252;
            for (int _7719 = 0; _7719 < 8; _7720 = _8252, _7719++)
            {
                int _8243 = 0;
                for (;;)
                {
                    if (_8243 < 5)
                    {
                        int2 _1963 = _1774 + (_1585[_7719] * _1594[_8243].xx);
                        bool _1966 = any(bool2(_1963.x < int2(0, 0).x, _1963.y < int2(0, 0).y));
                        bool _1974;
                        if (!_1966)
                        {
                            _1974 = any(bool2(_1963.x >= cbFI_MvDepthLaneSize.x, _1963.y >= cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _1974 = _1966;
                        }
                        if (_1974)
                        {
                            _8252 = _7720;
                            break;
                        }
                        uint4 _2197 = r_warped_motion_qdata_tp1.Load(int3(_1963, 0));
                        uint _2198 = _2197.x;
                        if (_2198 != 0u)
                        {
                            _8252 = min(_7720, _2198);
                            break;
                        }
                        _8243++;
                        continue;
                    }
                    else
                    {
                        _8252 = _7720;
                        break;
                    }
                }
            }
            bool _1995 = _7720 != 4294967295u;
            if (_1995)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _2207;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _2207);
                }
            }
            _7721 = _1995 ? _7720 : _7718;
        }
        else
        {
            _7721 = _7718;
        }
        nfruHoleFlags = 0u;
        bool _2003 = _1841[0] == 0u;
        bool _2005 = _7721 == 0u;
        int _2007 = _1774.x;
        bool _2008 = _2007 == 0;
        bool _2015;
        if (!_2008)
        {
            _2015 = _1774.y == 0;
        }
        else
        {
            _2015 = _2008;
        }
        bool _2025;
        if (!_2015)
        {
            _2025 = _2007 == (cbFI_MvDepthLaneSize.x - 1);
        }
        else
        {
            _2025 = _2015;
        }
        bool _2035;
        if (!_2025)
        {
            _2035 = _1774.y == (cbFI_MvDepthLaneSize.y - 1);
        }
        else
        {
            _2035 = _2025;
        }
        if (_2003)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2217;
                rw_nfru_diagnostics.InterlockedAdd(88, 1u, _2217);
            }
            nfruHoleFlags |= 16u;
        }
        if (_2005)
        {
            bool _2223 = (cbFI_pad0 & 512u) != 0u;
            if (_2223)
            {
                uint _2227;
                rw_nfru_diagnostics.InterlockedAdd(92, 1u, _2227);
            }
            nfruHoleFlags |= 32u;
            if (!_2035)
            {
                if (_2223)
                {
                    uint _2237;
                    rw_nfru_diagnostics.InterlockedAdd(96, 1u, _2237);
                }
            }
        }
        if (_2035)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2247;
                rw_nfru_diagnostics.InterlockedAdd(108, 1u, _2247);
            }
        }
        if (_2003 && (!_2005))
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2257;
                rw_nfru_diagnostics.InterlockedAdd(112, 1u, _2257);
            }
        }
        uint _2274 = _7721 & 2147483647u;
        uint _2306 = uint(max((int((_2274 >> 16u) & 15u) - 6), 0));
        float2 _2068 = (float2(float((1 - (2 * int((_2274 >> 15u) & 1u))) * int(((_2274 >> uint(7)) & 127u) << _2306)), float((1 - (2 * int((_2274 >> 14u) & 1u))) * int((_2274 & 127u) << _2306))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
        bool _2071 = all(bool2(_2068.x == 0.0f.xx.x, _2068.y == 0.0f.xx.y));
        if (_2071)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2334;
                rw_nfru_diagnostics.InterlockedAdd(100, 1u, _2334);
            }
            nfruHoleFlags |= 64u;
        }
        float2 _2079 = float2(cbFI_DisplaySize);
        float _2081 = length(_2068 * _2079);
        if (_2081 <= 0.25f)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2348;
                rw_nfru_diagnostics.InterlockedAdd(104, 1u, _2348);
            }
        }
        uint _2493;
        float2 _2369 = (float2(_1774) + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        float2 _8180;
        uint _8181;
        do
        {
            nfruCandidateFlags = 0u;
            _2493 = cbFI_pad0;
            bool _2495 = (_2493 & 536870912u) != 0u;
            bool _2501;
            if (_2495)
            {
                _2501 = (nfruHoleFlags & 32u) != 0u;
            }
            else
            {
                _2501 = _2495;
            }
            bool _2508;
            if (_2501)
            {
                _2508 = (cbFI_NfruT2Flags & 2u) == 0u;
            }
            else
            {
                _2508 = _2501;
            }
            if (_2508)
            {
                float _3072;
                float _3075;
                float _3084;
                float _3085;
                float _2513 = 1.0f - cbFI_Timestep;
                uint _7812;
                float2 _7855;
                float2 _7885;
                do
                {
                    float2 _7739;
                    bool _7740;
                    do
                    {
                        _3072 = _2369.x;
                        _3075 = 1.0f - _2369.y;
                        float2 _3081 = (float2(_3072, _3075) * 2.0f) - 1.0f.xx;
                        uint _3138_dummy_parameter;
                        _3084 = _3081.x;
                        _3085 = _3081.y;
                        float4 _3087 = mul(float4(_3084, _3085, r_depth_tp1.Load(int3(int2(floor(_2369 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3138_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _3089 = _3087.w;
                        bool _3090 = _3089 > 9.9999999747524270787835121154785e-07f;
                        if (!_3090)
                        {
                            _7740 = _3090;
                            _7739 = 0.0f.xx;
                            break;
                        }
                        float2 _3103 = ((_3087.xy / _3089.xx) + 1.0f.xx) * 0.5f;
                        float2 _3114 = float2(_3103.x - _3072, _3075 - _3103.y);
                        bool _3117 = any(isnan(_3114));
                        bool _3124;
                        if (!_3117)
                        {
                            _3124 = any(isinf(_3114));
                        }
                        else
                        {
                            _3124 = _3117;
                        }
                        bool _3125 = !_3124;
                        bool2 _3128 = _3125.xx;
                        _7740 = _3125;
                        _7739 = float2(_3128.x ? _3114.x : 0.0f.xx.x, _3128.y ? _3114.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7740)
                    {
                        _7885 = _7739;
                        _7855 = _7871;
                        _7812 = 3u;
                        break;
                    }
                    float2 _7742;
                    float2 _7887;
                    _7742 = _2369 - (_7739 * _2513);
                    _7887 = _7739;
                    float2 _3016;
                    float2 _7743;
                    bool _7787;
                    float2 _7803;
                    uint _7813;
                    float2 _7886;
                    int _7741 = 0;
                    for (;;)
                    {
                        if (_7741 < 8)
                        {
                            float _3163;
                            float _3165;
                            float2 _2900 = clamp(_7742, (-1.0f).xx, 2.0f.xx);
                            bool _7744;
                            do
                            {
                                _3163 = _2900.x;
                                _3165 = _2900.y;
                                float _3166 = 1.0f - _3165;
                                uint _3229_dummy_parameter;
                                float4 _3178 = mul(float4((float2(_3163, _3166) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2900 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3229_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3180 = _3178.w;
                                bool _3181 = _3180 > 9.9999999747524270787835121154785e-07f;
                                if (!_3181)
                                {
                                    _7744 = _3181;
                                    _7743 = 0.0f.xx;
                                    break;
                                }
                                float2 _3194 = ((_3178.xy / _3180.xx) + 1.0f.xx) * 0.5f;
                                float2 _3205 = float2(_3194.x - _3163, _3166 - _3194.y);
                                bool _3208 = any(isnan(_3205));
                                bool _3215;
                                if (!_3208)
                                {
                                    _3215 = any(isinf(_3205));
                                }
                                else
                                {
                                    _3215 = _3208;
                                }
                                bool _3216 = !_3215;
                                bool2 _3219 = _3216.xx;
                                _7744 = _3216;
                                _7743 = float2(_3219.x ? _3205.x : 0.0f.xx.x, _3219.y ? _3205.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3250;
                            float _3252;
                            float2 _2909 = _2900 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _7747;
                            bool _7748;
                            do
                            {
                                _3250 = _2909.x;
                                _3252 = _2909.y;
                                float _3253 = 1.0f - _3252;
                                uint _3316_dummy_parameter;
                                float4 _3265 = mul(float4((float2(_3250, _3253) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2909 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3316_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3267 = _3265.w;
                                bool _3268 = _3267 > 9.9999999747524270787835121154785e-07f;
                                if (!_3268)
                                {
                                    _7748 = _3268;
                                    _7747 = 0.0f.xx;
                                    break;
                                }
                                float2 _3281 = ((_3265.xy / _3267.xx) + 1.0f.xx) * 0.5f;
                                float2 _3292 = float2(_3281.x - _3250, _3253 - _3281.y);
                                bool _3295 = any(isnan(_3292));
                                bool _3302;
                                if (!_3295)
                                {
                                    _3302 = any(isinf(_3292));
                                }
                                else
                                {
                                    _3302 = _3295;
                                }
                                bool _3303 = !_3302;
                                bool2 _3306 = _3303.xx;
                                _7748 = _3303;
                                _7747 = float2(_3306.x ? _3292.x : 0.0f.xx.x, _3306.y ? _3292.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3337;
                            float _3339;
                            float2 _2917 = _2900 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _7751;
                            bool _7752;
                            do
                            {
                                _3337 = _2917.x;
                                _3339 = _2917.y;
                                float _3340 = 1.0f - _3339;
                                uint _3403_dummy_parameter;
                                float4 _3352 = mul(float4((float2(_3337, _3340) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2917 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3403_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3354 = _3352.w;
                                bool _3355 = _3354 > 9.9999999747524270787835121154785e-07f;
                                if (!_3355)
                                {
                                    _7752 = _3355;
                                    _7751 = 0.0f.xx;
                                    break;
                                }
                                float2 _3368 = ((_3352.xy / _3354.xx) + 1.0f.xx) * 0.5f;
                                float2 _3379 = float2(_3368.x - _3337, _3340 - _3368.y);
                                bool _3382 = any(isnan(_3379));
                                bool _3389;
                                if (!_3382)
                                {
                                    _3389 = any(isinf(_3379));
                                }
                                else
                                {
                                    _3389 = _3382;
                                }
                                bool _3390 = !_3389;
                                bool2 _3393 = _3390.xx;
                                _7752 = _3390;
                                _7751 = float2(_3393.x ? _3379.x : 0.0f.xx.x, _3393.y ? _3379.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_7744 && _7748) && _7752))
                            {
                                _7886 = _7743;
                                _7813 = 3u;
                                _7803 = _2900;
                                _7787 = true;
                                break;
                            }
                            float2 _3422 = _2900 + _7743;
                            bool _3451 = (_2493 & 1073741824u) != 0u;
                            float2 _7763;
                            if (_3451)
                            {
                                float _3464 = ((2.0f * _3422.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3476 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3488 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3512 = ((2.0f * _3163) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7763 = (float2(atan(_3464) / _3476, atan((((2.0f * _3422.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3464 * _3464))) / _3488) + 0.5f.xx) - (float2(atan(_3512) / _3476, atan((((2.0f * _3165) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3512 * _3512))) / _3488) + 0.5f.xx);
                            }
                            else
                            {
                                _7763 = _3422 - _2900;
                            }
                            float2 _7764;
                            if (_3451)
                            {
                                float _3588 = ((2.0f * _3163) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _3637 = clamp(((((float2(atan(_3588) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3165) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3588 * _3588))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7763 * _2513)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _3640 = tan(_3637.x);
                                _7764 = (float2(_3640 / cbFI_DeviceToViewDepth.z, (tan(_3637.y) * sqrt(1.0f + (_3640 * _3640))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7764 = _2900 + (_7763 * _2513);
                            }
                            float2 _2935 = _7764 - _2369;
                            if (length(_2935 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _7886 = _7743;
                                _7813 = _7830;
                                _7803 = _2900;
                                _7787 = false;
                                break;
                            }
                            float2 _3682 = _2909 + _7747;
                            float2 _7767;
                            if (_3451)
                            {
                                float _3724 = ((2.0f * _3682.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3736 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3748 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3772 = ((2.0f * _3250) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7767 = (float2(atan(_3724) / _3736, atan((((2.0f * _3682.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3724 * _3724))) / _3748) + 0.5f.xx) - (float2(atan(_3772) / _3736, atan((((2.0f * _3252) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3772 * _3772))) / _3748) + 0.5f.xx);
                            }
                            else
                            {
                                _7767 = _3682 - _2909;
                            }
                            float2 _7768;
                            if (_3451)
                            {
                                float _3848 = ((2.0f * _3250) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _3897 = clamp(((((float2(atan(_3848) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3252) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3848 * _3848))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7767 * _2513)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _3900 = tan(_3897.x);
                                _7768 = (float2(_3900 / cbFI_DeviceToViewDepth.z, (tan(_3897.y) * sqrt(1.0f + (_3900 * _3900))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7768 = _2909 + (_7767 * _2513);
                            }
                            float2 _2957 = (_7768 - _7764) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _3938 = _2917 + _7751;
                            float2 _7771;
                            if (_3451)
                            {
                                float _3980 = ((2.0f * _3938.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3992 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _4004 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4028 = ((2.0f * _3337) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7771 = (float2(atan(_3980) / _3992, atan((((2.0f * _3938.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3980 * _3980))) / _4004) + 0.5f.xx) - (float2(atan(_4028) / _3992, atan((((2.0f * _3339) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4028 * _4028))) / _4004) + 0.5f.xx);
                            }
                            else
                            {
                                _7771 = _3938 - _2917;
                            }
                            float2 _7772;
                            if (_3451)
                            {
                                float _4104 = ((2.0f * _3337) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4153 = clamp(((((float2(atan(_4104) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3339) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4104 * _4104))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7771 * _2513)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4156 = tan(_4153.x);
                                _7772 = (float2(_4156 / cbFI_DeviceToViewDepth.z, (tan(_4153.y) * sqrt(1.0f + (_4156 * _4156))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7772 = _2917 + (_7771 * _2513);
                            }
                            float2 _2971 = (_7772 - _7764) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _2973 = _2957.x;
                            float _2975 = _2971.y;
                            float _2978 = _2971.x;
                            float _2980 = _2957.y;
                            float _2982 = (_2973 * _2975) - (_2978 * _2980);
                            if (abs(_2982) < 9.9999997473787516355514526367188e-05f)
                            {
                                _7886 = _7743;
                                _7813 = 3u;
                                _7803 = _2900;
                                _7787 = true;
                                break;
                            }
                            float _2991 = _2935.x;
                            float _2996 = _2935.y;
                            _3016 = _2900 - (float2((_2975 * _2991) - (_2978 * _2996), ((-_2980) * _2991) + (_2973 * _2996)) / _2982.xx);
                            _7742 = _3016;
                            _7741++;
                            _7887 = _7743;
                            continue;
                        }
                        else
                        {
                            _7886 = _7887;
                            _7813 = _7830;
                            _7803 = _7742;
                            _7787 = false;
                            break;
                        }
                    }
                    if (_7787)
                    {
                        _7885 = _7886;
                        _7855 = _7803;
                        _7812 = _7813;
                        break;
                    }
                    float _4196;
                    float _4198;
                    float2 _7804;
                    bool _7805;
                    do
                    {
                        _4196 = _7803.x;
                        _4198 = _7803.y;
                        float _4199 = 1.0f - _4198;
                        uint _4262_dummy_parameter;
                        float4 _4211 = mul(float4((float2(_4196, _4199) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_7803 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4262_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _4213 = _4211.w;
                        bool _4214 = _4213 > 9.9999999747524270787835121154785e-07f;
                        if (!_4214)
                        {
                            _7805 = _4214;
                            _7804 = 0.0f.xx;
                            break;
                        }
                        float2 _4227 = ((_4211.xy / _4213.xx) + 1.0f.xx) * 0.5f;
                        float2 _4238 = float2(_4227.x - _4196, _4199 - _4227.y);
                        bool _4241 = any(isnan(_4238));
                        bool _4248;
                        if (!_4241)
                        {
                            _4248 = any(isinf(_4238));
                        }
                        else
                        {
                            _4248 = _4241;
                        }
                        bool _4249 = !_4248;
                        bool2 _4252 = _4249.xx;
                        _7805 = _4249;
                        _7804 = float2(_4252.x ? _4238.x : 0.0f.xx.x, _4252.y ? _4238.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7805)
                    {
                        _7885 = _7804;
                        _7855 = _7803;
                        _7812 = 3u;
                        break;
                    }
                    float2 _4281 = _7803 + _7804;
                    bool _4310 = (_2493 & 1073741824u) != 0u;
                    float2 _7808;
                    if (_4310)
                    {
                        float _4323 = ((2.0f * _4281.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4335 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4347 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4371 = ((2.0f * _4196) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _7808 = (float2(atan(_4323) / _4335, atan((((2.0f * _4281.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4323 * _4323))) / _4347) + 0.5f.xx) - (float2(atan(_4371) / _4335, atan((((2.0f * _4198) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4371 * _4371))) / _4347) + 0.5f.xx);
                    }
                    else
                    {
                        _7808 = _4281 - _7803;
                    }
                    float2 _7809;
                    if (_4310)
                    {
                        float _4447 = ((2.0f * _4196) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _4496 = clamp(((((float2(atan(_4447) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4198) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4447 * _4447))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7808 * _2513)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _4499 = tan(_4496.x);
                        _7809 = (float2(_4499 / cbFI_DeviceToViewDepth.z, (tan(_4496.y) * sqrt(1.0f + (_4499 * _4499))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _7809 = _7803 + (_7808 * _2513);
                    }
                    if (length((_7809 - _2369) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _7885 = _7804;
                        _7855 = _7803;
                        _7812 = 2u;
                        break;
                    }
                    bool _3048 = all(bool2(_7803.x > cbFI_MvDepthLaneSizeRcp.x, _7803.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _3057;
                    if (_3048)
                    {
                        float2 _3053 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _3057 = all(bool2(_7803.x < _3053.x, _7803.y < _3053.y));
                    }
                    else
                    {
                        _3057 = _3048;
                    }
                    _7885 = _7804;
                    _7855 = _7803;
                    _7812 = _3057 ? 0u : 1u;
                    break;
                } while(false);
                if (_7812 == 0u)
                {
                    if ((_2493 & 512u) != 0u)
                    {
                        uint _4544;
                        rw_nfru_diagnostics.InterlockedAdd(4, 1u, _4544);
                    }
                    float2 _2524 = _7855 + _7885;
                    float2 _8179;
                    if ((_2493 & 1073741824u) != 0u)
                    {
                        float _4582 = ((2.0f * _2524.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4594 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4606 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4630 = ((2.0f * _7855.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8179 = (float2(atan(_4582) / _4594, atan((((2.0f * _2524.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4582 * _4582))) / _4606) + 0.5f.xx) - (float2(atan(_4630) / _4594, atan((((2.0f * _7855.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4630 * _4630))) / _4606) + 0.5f.xx);
                    }
                    else
                    {
                        _8179 = _2524 - _7855;
                    }
                    _8181 = 2u;
                    _8180 = _8179;
                    break;
                }
                uint _7970;
                float2 _8034;
                float2 _8085;
                do
                {
                    float2 _7897;
                    bool _7898;
                    do
                    {
                        uint _4973_dummy_parameter;
                        float4 _4922 = mul(float4(_3084, _3085, r_depth_tp1.Load(int3(int2(floor(_2369 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4973_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _4924 = _4922.w;
                        bool _4925 = _4924 > 9.9999999747524270787835121154785e-07f;
                        if (!_4925)
                        {
                            _7898 = _4925;
                            _7897 = 0.0f.xx;
                            break;
                        }
                        float2 _4938 = ((_4922.xy / _4924.xx) + 1.0f.xx) * 0.5f;
                        float2 _4949 = float2(_4938.x - _3072, _3075 - _4938.y);
                        bool _4952 = any(isnan(_4949));
                        bool _4959;
                        if (!_4952)
                        {
                            _4959 = any(isinf(_4949));
                        }
                        else
                        {
                            _4959 = _4952;
                        }
                        bool _4960 = !_4959;
                        bool2 _4963 = _4960.xx;
                        _7898 = _4960;
                        _7897 = float2(_4963.x ? _4949.x : 0.0f.xx.x, _4963.y ? _4949.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7898)
                    {
                        _8085 = _7897;
                        _8034 = _7871;
                        _7970 = 3u;
                        break;
                    }
                    float2 _7900;
                    float2 _8087;
                    _7900 = _2369 - (_7897 * cbFI_Timestep);
                    _8087 = _7897;
                    float2 _4851;
                    float2 _7901;
                    bool _7945;
                    float2 _7961;
                    uint _7971;
                    float2 _8086;
                    int _7899 = 0;
                    for (;;)
                    {
                        if (_7899 < 8)
                        {
                            float _4998;
                            float _5000;
                            float2 _4735 = clamp(_7900, (-1.0f).xx, 2.0f.xx);
                            bool _7902;
                            do
                            {
                                _4998 = _4735.x;
                                _5000 = _4735.y;
                                float _5001 = 1.0f - _5000;
                                uint _5064_dummy_parameter;
                                float4 _5013 = mul(float4((float2(_4998, _5001) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4735 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5064_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5015 = _5013.w;
                                bool _5016 = _5015 > 9.9999999747524270787835121154785e-07f;
                                if (!_5016)
                                {
                                    _7902 = _5016;
                                    _7901 = 0.0f.xx;
                                    break;
                                }
                                float2 _5029 = ((_5013.xy / _5015.xx) + 1.0f.xx) * 0.5f;
                                float2 _5040 = float2(_5029.x - _4998, _5001 - _5029.y);
                                bool _5043 = any(isnan(_5040));
                                bool _5050;
                                if (!_5043)
                                {
                                    _5050 = any(isinf(_5040));
                                }
                                else
                                {
                                    _5050 = _5043;
                                }
                                bool _5051 = !_5050;
                                bool2 _5054 = _5051.xx;
                                _7902 = _5051;
                                _7901 = float2(_5054.x ? _5040.x : 0.0f.xx.x, _5054.y ? _5040.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5085;
                            float _5087;
                            float2 _4744 = _4735 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _7905;
                            bool _7906;
                            do
                            {
                                _5085 = _4744.x;
                                _5087 = _4744.y;
                                float _5088 = 1.0f - _5087;
                                uint _5151_dummy_parameter;
                                float4 _5100 = mul(float4((float2(_5085, _5088) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5151_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5102 = _5100.w;
                                bool _5103 = _5102 > 9.9999999747524270787835121154785e-07f;
                                if (!_5103)
                                {
                                    _7906 = _5103;
                                    _7905 = 0.0f.xx;
                                    break;
                                }
                                float2 _5116 = ((_5100.xy / _5102.xx) + 1.0f.xx) * 0.5f;
                                float2 _5127 = float2(_5116.x - _5085, _5088 - _5116.y);
                                bool _5130 = any(isnan(_5127));
                                bool _5137;
                                if (!_5130)
                                {
                                    _5137 = any(isinf(_5127));
                                }
                                else
                                {
                                    _5137 = _5130;
                                }
                                bool _5138 = !_5137;
                                bool2 _5141 = _5138.xx;
                                _7906 = _5138;
                                _7905 = float2(_5141.x ? _5127.x : 0.0f.xx.x, _5141.y ? _5127.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5172;
                            float _5174;
                            float2 _4752 = _4735 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _7909;
                            bool _7910;
                            do
                            {
                                _5172 = _4752.x;
                                _5174 = _4752.y;
                                float _5175 = 1.0f - _5174;
                                uint _5238_dummy_parameter;
                                float4 _5187 = mul(float4((float2(_5172, _5175) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5238_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5189 = _5187.w;
                                bool _5190 = _5189 > 9.9999999747524270787835121154785e-07f;
                                if (!_5190)
                                {
                                    _7910 = _5190;
                                    _7909 = 0.0f.xx;
                                    break;
                                }
                                float2 _5203 = ((_5187.xy / _5189.xx) + 1.0f.xx) * 0.5f;
                                float2 _5214 = float2(_5203.x - _5172, _5175 - _5203.y);
                                bool _5217 = any(isnan(_5214));
                                bool _5224;
                                if (!_5217)
                                {
                                    _5224 = any(isinf(_5214));
                                }
                                else
                                {
                                    _5224 = _5217;
                                }
                                bool _5225 = !_5224;
                                bool2 _5228 = _5225.xx;
                                _7910 = _5225;
                                _7909 = float2(_5228.x ? _5214.x : 0.0f.xx.x, _5228.y ? _5214.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_7902 && _7906) && _7910))
                            {
                                _8086 = _7901;
                                _7971 = 3u;
                                _7961 = _4735;
                                _7945 = true;
                                break;
                            }
                            float2 _5257 = _4735 + _7901;
                            bool _5286 = (_2493 & 1073741824u) != 0u;
                            float2 _7921;
                            if (_5286)
                            {
                                float _5299 = ((2.0f * _5257.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5311 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5323 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5347 = ((2.0f * _4998) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7921 = (float2(atan(_5299) / _5311, atan((((2.0f * _5257.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5299 * _5299))) / _5323) + 0.5f.xx) - (float2(atan(_5347) / _5311, atan((((2.0f * _5000) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5347 * _5347))) / _5323) + 0.5f.xx);
                            }
                            else
                            {
                                _7921 = _5257 - _4735;
                            }
                            float2 _7922;
                            if (_5286)
                            {
                                float _5423 = ((2.0f * _4998) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5472 = clamp(((((float2(atan(_5423) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5000) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5423 * _5423))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7921 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5475 = tan(_5472.x);
                                _7922 = (float2(_5475 / cbFI_DeviceToViewDepth.z, (tan(_5472.y) * sqrt(1.0f + (_5475 * _5475))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7922 = _4735 + (_7921 * cbFI_Timestep);
                            }
                            float2 _4770 = _7922 - _2369;
                            if (length(_4770 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8086 = _7901;
                                _7971 = _7830;
                                _7961 = _4735;
                                _7945 = false;
                                break;
                            }
                            float2 _5517 = _4744 + _7905;
                            float2 _7925;
                            if (_5286)
                            {
                                float _5559 = ((2.0f * _5517.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5571 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5583 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5607 = ((2.0f * _5085) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7925 = (float2(atan(_5559) / _5571, atan((((2.0f * _5517.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5559 * _5559))) / _5583) + 0.5f.xx) - (float2(atan(_5607) / _5571, atan((((2.0f * _5087) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5607 * _5607))) / _5583) + 0.5f.xx);
                            }
                            else
                            {
                                _7925 = _5517 - _4744;
                            }
                            float2 _7926;
                            if (_5286)
                            {
                                float _5683 = ((2.0f * _5085) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5732 = clamp(((((float2(atan(_5683) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5087) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5683 * _5683))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7925 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5735 = tan(_5732.x);
                                _7926 = (float2(_5735 / cbFI_DeviceToViewDepth.z, (tan(_5732.y) * sqrt(1.0f + (_5735 * _5735))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7926 = _4744 + (_7925 * cbFI_Timestep);
                            }
                            float2 _4792 = (_7926 - _7922) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _5773 = _4752 + _7909;
                            float2 _7929;
                            if (_5286)
                            {
                                float _5815 = ((2.0f * _5773.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5827 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5839 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5863 = ((2.0f * _5172) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7929 = (float2(atan(_5815) / _5827, atan((((2.0f * _5773.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5815 * _5815))) / _5839) + 0.5f.xx) - (float2(atan(_5863) / _5827, atan((((2.0f * _5174) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5863 * _5863))) / _5839) + 0.5f.xx);
                            }
                            else
                            {
                                _7929 = _5773 - _4752;
                            }
                            float2 _7930;
                            if (_5286)
                            {
                                float _5939 = ((2.0f * _5172) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5988 = clamp(((((float2(atan(_5939) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5174) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5939 * _5939))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7929 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5991 = tan(_5988.x);
                                _7930 = (float2(_5991 / cbFI_DeviceToViewDepth.z, (tan(_5988.y) * sqrt(1.0f + (_5991 * _5991))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7930 = _4752 + (_7929 * cbFI_Timestep);
                            }
                            float2 _4806 = (_7930 - _7922) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _4808 = _4792.x;
                            float _4810 = _4806.y;
                            float _4813 = _4806.x;
                            float _4815 = _4792.y;
                            float _4817 = (_4808 * _4810) - (_4813 * _4815);
                            if (abs(_4817) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8086 = _7901;
                                _7971 = 3u;
                                _7961 = _4735;
                                _7945 = true;
                                break;
                            }
                            float _4826 = _4770.x;
                            float _4831 = _4770.y;
                            _4851 = _4735 - (float2((_4810 * _4826) - (_4813 * _4831), ((-_4815) * _4826) + (_4808 * _4831)) / _4817.xx);
                            _7900 = _4851;
                            _7899++;
                            _8087 = _7901;
                            continue;
                        }
                        else
                        {
                            _8086 = _8087;
                            _7971 = _7830;
                            _7961 = _7900;
                            _7945 = false;
                            break;
                        }
                    }
                    if (_7945)
                    {
                        _8085 = _8086;
                        _8034 = _7961;
                        _7970 = _7971;
                        break;
                    }
                    float _6031;
                    float _6033;
                    float2 _7962;
                    bool _7963;
                    do
                    {
                        _6031 = _7961.x;
                        _6033 = _7961.y;
                        float _6034 = 1.0f - _6033;
                        uint _6097_dummy_parameter;
                        float4 _6046 = mul(float4((float2(_6031, _6034) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_7961 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6097_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6048 = _6046.w;
                        bool _6049 = _6048 > 9.9999999747524270787835121154785e-07f;
                        if (!_6049)
                        {
                            _7963 = _6049;
                            _7962 = 0.0f.xx;
                            break;
                        }
                        float2 _6062 = ((_6046.xy / _6048.xx) + 1.0f.xx) * 0.5f;
                        float2 _6073 = float2(_6062.x - _6031, _6034 - _6062.y);
                        bool _6076 = any(isnan(_6073));
                        bool _6083;
                        if (!_6076)
                        {
                            _6083 = any(isinf(_6073));
                        }
                        else
                        {
                            _6083 = _6076;
                        }
                        bool _6084 = !_6083;
                        bool2 _6087 = _6084.xx;
                        _7963 = _6084;
                        _7962 = float2(_6087.x ? _6073.x : 0.0f.xx.x, _6087.y ? _6073.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7963)
                    {
                        _8085 = _7962;
                        _8034 = _7961;
                        _7970 = 3u;
                        break;
                    }
                    float2 _6116 = _7961 + _7962;
                    bool _6145 = (_2493 & 1073741824u) != 0u;
                    float2 _7966;
                    if (_6145)
                    {
                        float _6158 = ((2.0f * _6116.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6170 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6182 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6206 = ((2.0f * _6031) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _7966 = (float2(atan(_6158) / _6170, atan((((2.0f * _6116.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6158 * _6158))) / _6182) + 0.5f.xx) - (float2(atan(_6206) / _6170, atan((((2.0f * _6033) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6206 * _6206))) / _6182) + 0.5f.xx);
                    }
                    else
                    {
                        _7966 = _6116 - _7961;
                    }
                    float2 _7967;
                    if (_6145)
                    {
                        float _6282 = ((2.0f * _6031) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _6331 = clamp(((((float2(atan(_6282) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _6033) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6282 * _6282))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7966 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6334 = tan(_6331.x);
                        _7967 = (float2(_6334 / cbFI_DeviceToViewDepth.z, (tan(_6331.y) * sqrt(1.0f + (_6334 * _6334))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _7967 = _7961 + (_7966 * cbFI_Timestep);
                    }
                    if (length((_7967 - _2369) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8085 = _7962;
                        _8034 = _7961;
                        _7970 = 2u;
                        break;
                    }
                    bool _4883 = all(bool2(_7961.x > cbFI_MvDepthLaneSizeRcp.x, _7961.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _4892;
                    if (_4883)
                    {
                        float2 _4888 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _4892 = all(bool2(_7961.x < _4888.x, _7961.y < _4888.y));
                    }
                    else
                    {
                        _4892 = _4883;
                    }
                    _8085 = _7962;
                    _8034 = _7961;
                    _7970 = _4892 ? 0u : 1u;
                    break;
                } while(false);
                if (_7970 == 0u)
                {
                    if ((_2493 & 512u) != 0u)
                    {
                        uint _6379;
                        rw_nfru_diagnostics.InterlockedAdd(8, 1u, _6379);
                    }
                    float2 _2540 = _8034 + _8085;
                    float2 _8176;
                    if ((_2493 & 1073741824u) != 0u)
                    {
                        float _6417 = ((2.0f * _2540.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6429 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6441 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6465 = ((2.0f * _8034.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8176 = (float2(atan(_6417) / _6429, atan((((2.0f * _2540.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6417 * _6417))) / _6441) + 0.5f.xx) - (float2(atan(_6465) / _6429, atan((((2.0f * _8034.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6465 * _6465))) / _6441) + 0.5f.xx);
                    }
                    else
                    {
                        _8176 = _2540 - _8034;
                    }
                    _8181 = 2u;
                    _8180 = -_8176;
                    break;
                }
                bool _6505 = (_2493 & 512u) != 0u;
                if (_6505)
                {
                    uint _6509;
                    rw_nfru_diagnostics.InterlockedAdd(20, 1u, _6509);
                }
                if (_7970 == 1u)
                {
                    if (_6505)
                    {
                        uint _6519;
                        rw_nfru_diagnostics.InterlockedAdd(116, 1u, _6519);
                    }
                }
                else
                {
                    if (_7970 == 2u)
                    {
                        if (_6505)
                        {
                            uint _6529;
                            rw_nfru_diagnostics.InterlockedAdd(248, 1u, _6529);
                        }
                    }
                }
            }
            if (_2081 > 0.25f)
            {
                _8181 = 0u;
                _8180 = _2068;
                break;
            }
            bool _6539 = (_2493 & 512u) != 0u;
            if (_6539)
            {
                uint _6543;
                rw_nfru_diagnostics.InterlockedAdd(216, 1u, _6543);
            }
            if (_2071)
            {
                if (_6539)
                {
                    uint _6553;
                    rw_nfru_diagnostics.InterlockedAdd(212, 1u, _6553);
                }
            }
            float _8098;
            _8098 = 0.0f;
            for (int _8097 = 0; _8097 < 5; )
            {
                float2 _6578 = _2369 + (float2(_527[_8097]) * cbFI_MvDepthLaneSizeRcp);
                _8098 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _6578, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _6578, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                _8097++;
                continue;
            }
            float _6596 = _8098 * 0.20000000298023223876953125f;
            if (_6596 < 0.0199999995529651641845703125f)
            {
                _8181 = 1u;
                _8180 = _2068;
                break;
            }
            float _2583 = _2369.x;
            float _2585 = _2369.y;
            float _2586 = 1.0f - _2585;
            uint _6623_dummy_parameter;
            float4 _2599 = mul(float4((float2(_2583, _2586) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2369 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6623_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
            float _2601 = _2599.w;
            bool _2602 = _2601 > 9.9999999747524270787835121154785e-07f;
            float2 _8100;
            if (_2602)
            {
                float2 _2612 = ((_2599.xy / _2601.xx) + 1.0f.xx) * 0.5f;
                _8100 = float2(_2612.x - _2583, _2586 - _2612.y);
            }
            else
            {
                _8100 = 0.0f.xx;
            }
            if (!_2602)
            {
                if (_6539)
                {
                    uint _6645;
                    rw_nfru_diagnostics.InterlockedAdd(208, 1u, _6645);
                }
            }
            float2 _2634 = _2369 + _8100;
            bool _6670 = (_2493 & 1073741824u) != 0u;
            float2 _8102;
            if (_6670)
            {
                float _6683 = ((2.0f * _2634.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float _6695 = 2.0f * cbFI_DeviceToViewDepth.z;
                float _6707 = 2.0f * cbFI_DeviceToViewDepth.w;
                float _6731 = ((2.0f * _2583) - 1.0f) * cbFI_DeviceToViewDepth.z;
                _8102 = (float2(atan(_6683) / _6695, atan((((2.0f * _2634.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6683 * _6683))) / _6707) + 0.5f.xx) - (float2(atan(_6731) / _6695, atan((((2.0f * _2585) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6731 * _6731))) / _6707) + 0.5f.xx);
            }
            else
            {
                _8102 = _2634 - _2369;
            }
            bool2 _8384 = ((cbFI_NfruT2Flags & 8192u) != 0u).xx;
            float2 _2646[2] = { float2(_8384.x ? 0.0f.xx.x : _8102.x, _8384.y ? 0.0f.xx.y : _8102.y), -r_warped_filled_flow_tm1.Load(int3(clamp(int2(_2369 * float2(cbFI_FlowLaneSize)), int2(0, 0), cbFI_FlowLaneSize - int2(1, 1)), 0)).xy };
            float2 _2450[2] = _2646;
            uint _8105;
            bool _8112;
            bool _8117;
            bool _8122;
            float2 _8130;
            _8130 = _2068;
            _8122 = false;
            _8117 = false;
            _8112 = false;
            _8105 = 0u;
            uint _8272;
            bool _8293;
            bool _8311;
            bool _8332;
            float2 _8353;
            float _8374;
            int _8104 = 0;
            float _8150 = _6596;
            for (; _8104 < 2; _8150 = _8374, _8130 = _8353, _8122 = _8332, _8117 = _8311, _8112 = _8293, _8105 = _8272, _8104++)
            {
                bool _2655 = _8104 == 0;
                uint _2656 = _2655 ? 32u : 42u;
                uint _2659 = _2655 ? 8u : 12u;
                if (_6539)
                {
                    uint _6775;
                    rw_nfru_diagnostics.InterlockedAdd(_2656 * 4 + 0, 1u, _6775);
                }
                bool _2667 = any(isnan(_2450[_8104]));
                bool _2674;
                if (!_2667)
                {
                    _2674 = any(isinf(_2450[_8104]));
                }
                else
                {
                    _2674 = _2667;
                }
                if (_2674)
                {
                    if (_6539)
                    {
                        uint _6785;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 1u) * 4 + 0, 1u, _6785);
                    }
                    nfruCandidateFlags |= (1u << _2659);
                    _8374 = _8150;
                    _8353 = _8130;
                    _8332 = true;
                    _8311 = _8117;
                    _8293 = _8112;
                    _8272 = _8105;
                    continue;
                }
                float _2688 = length(_2450[_8104] * _2079);
                if (_2688 < 1.0f)
                {
                    if (_6539)
                    {
                        uint _6799;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 2u) * 4 + 0, 1u, _6799);
                    }
                    nfruCandidateFlags |= (2u << _2659);
                    _8374 = _8150;
                    _8353 = _8130;
                    _8332 = _8122;
                    _8311 = _8117;
                    _8293 = _8112;
                    _8272 = _8105;
                    continue;
                }
                if (_2688 > 256.0f)
                {
                    if (_6539)
                    {
                        uint _6809;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 8u) * 4 + 0, 1u, _6809);
                    }
                }
                if (_2688 > float(max(cbFI_DisplaySize.x, cbFI_DisplaySize.y)))
                {
                    if (_6539)
                    {
                        uint _6827;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 9u) * 4 + 0, 1u, _6827);
                    }
                }
                float2 _8135;
                if (_6670)
                {
                    float _6873 = ((2.0f * _2583) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _6922 = clamp(((((float2(atan(_6873) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2585) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6873 * _6873))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2450[_8104] * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _6925 = tan(_6922.x);
                    _8135 = (float2(_6925 / cbFI_DeviceToViewDepth.z, (tan(_6922.y) * sqrt(1.0f + (_6925 * _6925))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8135 = _2369 + (_2450[_8104] * cbFI_Timestep);
                }
                float _2726 = cbFI_Timestep - 1.0f;
                float2 _8136;
                if (_6670)
                {
                    float _6998 = ((2.0f * _2583) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7047 = clamp(((((float2(atan(_6998) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2585) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6998 * _6998))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2450[_8104] * _2726)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7050 = tan(_7047.x);
                    _8136 = (float2(_7050 / cbFI_DeviceToViewDepth.z, (tan(_7047.y) * sqrt(1.0f + (_7050 * _7050))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8136 = _2369 + (_2450[_8104] * _2726);
                }
                bool _7086 = all(bool2(_8135.x > cbFI_MvDepthLaneSizeRcp.x, _8135.y > cbFI_MvDepthLaneSizeRcp.y));
                bool _7095;
                if (_7086)
                {
                    float2 _7091 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7095 = all(bool2(_8135.x < _7091.x, _8135.y < _7091.y));
                }
                else
                {
                    _7095 = _7086;
                }
                bool _7102;
                if (_7095)
                {
                    _7102 = all(bool2(_8136.x > cbFI_MvDepthLaneSizeRcp.x, _8136.y > cbFI_MvDepthLaneSizeRcp.y));
                }
                else
                {
                    _7102 = _7095;
                }
                bool _7111;
                if (_7102)
                {
                    float2 _7107 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7111 = all(bool2(_8136.x < _7107.x, _8136.y < _7107.y));
                }
                else
                {
                    _7111 = _7102;
                }
                if (!_7111)
                {
                    if (_6539)
                    {
                        uint _7124;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 3u) * 4 + 0, 1u, _7124);
                    }
                    nfruCandidateFlags |= (3u << _2659);
                    _8374 = _8150;
                    _8353 = _8130;
                    _8332 = _8122;
                    _8311 = _8117;
                    _8293 = true;
                    _8272 = _8105;
                    continue;
                }
                if (_6539)
                {
                    uint _7134;
                    rw_nfru_diagnostics.InterlockedAdd((_2656 + 4u) * 4 + 0, 1u, _7134);
                }
                float _8138;
                _8138 = 0.0f;
                for (int _8137 = 0; _8137 < 5; )
                {
                    float2 _7156 = float2(_527[_8137]) * cbFI_MvDepthLaneSizeRcp;
                    _8138 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8135 + _7156, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _8136 + _7156, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                    _8137++;
                    continue;
                }
                float _7177 = _8138 * 0.20000000298023223876953125f;
                bool _2751 = _7177 < _8150;
                bool _2758;
                if (_2751)
                {
                    _2758 = _7177 < (_8098 * 0.12000000476837158203125f);
                }
                else
                {
                    _2758 = _2751;
                }
                bool _2765;
                if (_2758)
                {
                    _2765 = (_6596 - _7177) > 0.0199999995529651641845703125f;
                }
                else
                {
                    _2765 = _2758;
                }
                bool _2768 = _2765 && (_7177 < 0.119999997317790985107421875f);
                uint _8287;
                if (_2768)
                {
                    if (_6539)
                    {
                        uint _7206;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 6u) * 4 + 0, 1u, _7206);
                    }
                    nfruCandidateFlags |= (5u << _2659);
                    _8287 = uint(_8104) + 2u;
                }
                else
                {
                    if (_6539)
                    {
                        uint _7216;
                        rw_nfru_diagnostics.InterlockedAdd((_2656 + 5u) * 4 + 0, 1u, _7216);
                    }
                    nfruCandidateFlags |= (4u << _2659);
                    _8287 = _8105;
                }
                bool2 _8387 = _2768.xx;
                _8374 = _2768 ? _7177 : _8150;
                _8353 = float2(_8387.x ? _2450[_8104].x : _8130.x, _8387.y ? _2450[_8104].y : _8130.y);
                _8332 = _8122;
                _8311 = true;
                _8293 = true;
                _8272 = _8287;
            }
            if (_8105 == 2u)
            {
                if (_6539)
                {
                    uint _7226;
                    rw_nfru_diagnostics.InterlockedAdd(156, 1u, _7226);
                }
            }
            else
            {
                if (_8105 == 3u)
                {
                    if (_6539)
                    {
                        uint _7236;
                        rw_nfru_diagnostics.InterlockedAdd(196, 1u, _7236);
                    }
                }
            }
            uint _8126;
            if (_8105 != 0u)
            {
                _8126 = _8105;
            }
            else
            {
                uint _8125;
                if (!_8112)
                {
                    _8125 = _8122 ? 7u : 4u;
                }
                else
                {
                    _8125 = (!_8117) ? 5u : 6u;
                }
                _8126 = _8125;
            }
            _8181 = _8126;
            _8180 = _8130;
            break;
        } while(false);
        bool _7311 = (_2493 & 512u) != 0u;
        if (_7311)
        {
            uint _7315;
            rw_nfru_diagnostics.InterlockedAdd(24, 1u, _7315);
        }
        if (_7311)
        {
            uint _7325;
            rw_nfru_diagnostics.InterlockedAdd((7u + _8181) * 4 + 0, 1u, _7325);
        }
        if ((nfruHoleFlags & 32u) != 0u)
        {
            if (_7311)
            {
                uint _7335;
                rw_nfru_diagnostics.InterlockedAdd((((_8181 == 2u) || (_8181 == 3u)) ? 30u : 31u) * 4 + 0, 1u, _7335);
            }
        }
        uint _7263 = (_2493 >> 16u) & 255u;
        bool _7267 = (_2493 & 1024u) != 0u;
        bool _7276;
        if (!_7267)
        {
            _7276 = (_7263 >= 9u) && (_7263 <= 11u);
        }
        else
        {
            _7276 = _7267;
        }
        if (_7276)
        {
            rw_nfru_diagnostics.Store<uint>((64u + uint((_1774.y * cbFI_MvDepthLaneSize.x) + _2007)) * 4 + 0, ((_8181 | nfruHoleFlags) | nfruCandidateFlags) | (((((nfruHoleFlags & 32u) == 0u) || (_8181 == 2u)) || (_8181 == 3u)) ? 65536u : 0u));
        }
        rw_warped_filled_motion_tp1[_1774] = float4(_8180, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
