static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static uint _7817;
static float2 _7858;

static const int2 _527[5] = { int2(0, 0), int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
static const int2 _1578[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1587[5] = { 2, 4, 7, 11, 16 };

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
    int2 _1767 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1767.x >= cbFI_MvDepthLaneSize.x, _1767.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        uint _1834[9];
        _1834[0] = r_warped_motion_qdata_tp1.Load(int3(_1767, 0)).x;
        _1834[1] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(1, 0), 0)).x;
        _1834[2] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(0, 1), 0)).x;
        _1834[3] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(0, -1), 0)).x;
        _1834[4] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(-1, 0), 0)).x;
        _1834[5] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(-1, 1), 0)).x;
        _1834[6] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(1, 1), 0)).x;
        _1834[7] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(-1, -1), 0)).x;
        _1834[8] = r_warped_motion_qdata_tp1.Load(int3(_1767 + int2(1, -1), 0)).x;
        uint _7705;
        _7705 = _1834[0];
        uint _8368;
        for (int _7704 = 1; _7704 < 9; _7705 = _8368, _7704++)
        {
            _8368 = (_1834[_7704] > _7705) ? _1834[_7704] : _7705;
        }
        bool _1928 = _7705 == 0u;
        bool _1935;
        if (_1928)
        {
            _1935 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _1935 = _1928;
        }
        uint _7708;
        if (_1935)
        {
            uint _7707;
            _7707 = 4294967295u;
            uint _8238;
            for (int _7706 = 0; _7706 < 8; _7707 = _8238, _7706++)
            {
                int _8229 = 0;
                for (;;)
                {
                    if (_8229 < 5)
                    {
                        int2 _1956 = _1767 + (_1578[_7706] * _1587[_8229].xx);
                        bool _1959 = any(bool2(_1956.x < int2(0, 0).x, _1956.y < int2(0, 0).y));
                        bool _1967;
                        if (!_1959)
                        {
                            _1967 = any(bool2(_1956.x >= cbFI_MvDepthLaneSize.x, _1956.y >= cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _1967 = _1959;
                        }
                        if (_1967)
                        {
                            _8238 = _7707;
                            break;
                        }
                        uint4 _2190 = r_warped_motion_qdata_tp1.Load(int3(_1956, 0));
                        uint _2191 = _2190.x;
                        if (_2191 != 0u)
                        {
                            _8238 = min(_7707, _2191);
                            break;
                        }
                        _8229++;
                        continue;
                    }
                    else
                    {
                        _8238 = _7707;
                        break;
                    }
                }
            }
            bool _1988 = _7707 != 4294967295u;
            if (_1988)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _2200;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _2200);
                }
            }
            _7708 = _1988 ? _7707 : _7705;
        }
        else
        {
            _7708 = _7705;
        }
        nfruHoleFlags = 0u;
        bool _1996 = _1834[0] == 0u;
        bool _1998 = _7708 == 0u;
        int _2000 = _1767.x;
        bool _2001 = _2000 == 0;
        bool _2008;
        if (!_2001)
        {
            _2008 = _1767.y == 0;
        }
        else
        {
            _2008 = _2001;
        }
        bool _2018;
        if (!_2008)
        {
            _2018 = _2000 == (cbFI_MvDepthLaneSize.x - 1);
        }
        else
        {
            _2018 = _2008;
        }
        bool _2028;
        if (!_2018)
        {
            _2028 = _1767.y == (cbFI_MvDepthLaneSize.y - 1);
        }
        else
        {
            _2028 = _2018;
        }
        if (_1996)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2210;
                rw_nfru_diagnostics.InterlockedAdd(88, 1u, _2210);
            }
            nfruHoleFlags |= 16u;
        }
        if (_1998)
        {
            bool _2216 = (cbFI_pad0 & 512u) != 0u;
            if (_2216)
            {
                uint _2220;
                rw_nfru_diagnostics.InterlockedAdd(92, 1u, _2220);
            }
            nfruHoleFlags |= 32u;
            if (!_2028)
            {
                if (_2216)
                {
                    uint _2230;
                    rw_nfru_diagnostics.InterlockedAdd(96, 1u, _2230);
                }
            }
        }
        if (_2028)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2240;
                rw_nfru_diagnostics.InterlockedAdd(108, 1u, _2240);
            }
        }
        if (_1996 && (!_1998))
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2250;
                rw_nfru_diagnostics.InterlockedAdd(112, 1u, _2250);
            }
        }
        uint _2267 = _7708 & 2147483647u;
        uint _2299 = uint(max((int((_2267 >> 16u) & 15u) - 6), 0));
        float2 _2061 = (float2(float((1 - (2 * int((_2267 >> 15u) & 1u))) * int(((_2267 >> uint(7)) & 127u) << _2299)), float((1 - (2 * int((_2267 >> 14u) & 1u))) * int((_2267 & 127u) << _2299))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
        bool _2064 = all(bool2(_2061.x == 0.0f.xx.x, _2061.y == 0.0f.xx.y));
        if (_2064)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2327;
                rw_nfru_diagnostics.InterlockedAdd(100, 1u, _2327);
            }
            nfruHoleFlags |= 64u;
        }
        float2 _2072 = float2(cbFI_DisplaySize);
        float _2074 = length(_2061 * _2072);
        if (_2074 <= 0.25f)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2341;
                rw_nfru_diagnostics.InterlockedAdd(104, 1u, _2341);
            }
        }
        uint _2486;
        float2 _2362 = (float2(_1767) + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        float2 _8166;
        uint _8167;
        do
        {
            nfruCandidateFlags = 0u;
            _2486 = cbFI_pad0;
            bool _2488 = (_2486 & 536870912u) != 0u;
            bool _2494;
            if (_2488)
            {
                _2494 = (nfruHoleFlags & 32u) != 0u;
            }
            else
            {
                _2494 = _2488;
            }
            bool _2501;
            if (_2494)
            {
                _2501 = (cbFI_NfruT2Flags & 2u) == 0u;
            }
            else
            {
                _2501 = _2494;
            }
            if (_2501)
            {
                float _3059;
                float _3062;
                float _3071;
                float _3072;
                float _2506 = 1.0f - cbFI_Timestep;
                uint _7799;
                float2 _7842;
                float2 _7872;
                do
                {
                    float2 _7726;
                    bool _7727;
                    do
                    {
                        _3059 = _2362.x;
                        _3062 = 1.0f - _2362.y;
                        float2 _3068 = (float2(_3059, _3062) * 2.0f) - 1.0f.xx;
                        uint _3125_dummy_parameter;
                        _3071 = _3068.x;
                        _3072 = _3068.y;
                        float4 _3074 = mul(float4(_3071, _3072, r_depth_tp1.Load(int3(int2(floor(_2362 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3125_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _3076 = _3074.w;
                        bool _3077 = _3076 > 9.9999999747524270787835121154785e-07f;
                        if (!_3077)
                        {
                            _7727 = _3077;
                            _7726 = 0.0f.xx;
                            break;
                        }
                        float2 _3090 = ((_3074.xy / _3076.xx) + 1.0f.xx) * 0.5f;
                        float2 _3101 = float2(_3090.x - _3059, _3062 - _3090.y);
                        bool _3104 = any(isnan(_3101));
                        bool _3111;
                        if (!_3104)
                        {
                            _3111 = any(isinf(_3101));
                        }
                        else
                        {
                            _3111 = _3104;
                        }
                        bool _3112 = !_3111;
                        bool2 _3115 = _3112.xx;
                        _7727 = _3112;
                        _7726 = float2(_3115.x ? _3101.x : 0.0f.xx.x, _3115.y ? _3101.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7727)
                    {
                        _7872 = _7726;
                        _7842 = _7858;
                        _7799 = 3u;
                        break;
                    }
                    float2 _7729;
                    float2 _7874;
                    _7729 = _2362 - (_7726 * _2506);
                    _7874 = _7726;
                    float2 _3003;
                    float2 _7730;
                    bool _7774;
                    float2 _7790;
                    uint _7800;
                    float2 _7873;
                    int _7728 = 0;
                    for (;;)
                    {
                        if (_7728 < 8)
                        {
                            float _3150;
                            float _3152;
                            float2 _2887 = clamp(_7729, (-1.0f).xx, 2.0f.xx);
                            bool _7731;
                            do
                            {
                                _3150 = _2887.x;
                                _3152 = _2887.y;
                                float _3153 = 1.0f - _3152;
                                uint _3216_dummy_parameter;
                                float4 _3165 = mul(float4((float2(_3150, _3153) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2887 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3216_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3167 = _3165.w;
                                bool _3168 = _3167 > 9.9999999747524270787835121154785e-07f;
                                if (!_3168)
                                {
                                    _7731 = _3168;
                                    _7730 = 0.0f.xx;
                                    break;
                                }
                                float2 _3181 = ((_3165.xy / _3167.xx) + 1.0f.xx) * 0.5f;
                                float2 _3192 = float2(_3181.x - _3150, _3153 - _3181.y);
                                bool _3195 = any(isnan(_3192));
                                bool _3202;
                                if (!_3195)
                                {
                                    _3202 = any(isinf(_3192));
                                }
                                else
                                {
                                    _3202 = _3195;
                                }
                                bool _3203 = !_3202;
                                bool2 _3206 = _3203.xx;
                                _7731 = _3203;
                                _7730 = float2(_3206.x ? _3192.x : 0.0f.xx.x, _3206.y ? _3192.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3237;
                            float _3239;
                            float2 _2896 = _2887 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _7734;
                            bool _7735;
                            do
                            {
                                _3237 = _2896.x;
                                _3239 = _2896.y;
                                float _3240 = 1.0f - _3239;
                                uint _3303_dummy_parameter;
                                float4 _3252 = mul(float4((float2(_3237, _3240) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2896 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3303_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3254 = _3252.w;
                                bool _3255 = _3254 > 9.9999999747524270787835121154785e-07f;
                                if (!_3255)
                                {
                                    _7735 = _3255;
                                    _7734 = 0.0f.xx;
                                    break;
                                }
                                float2 _3268 = ((_3252.xy / _3254.xx) + 1.0f.xx) * 0.5f;
                                float2 _3279 = float2(_3268.x - _3237, _3240 - _3268.y);
                                bool _3282 = any(isnan(_3279));
                                bool _3289;
                                if (!_3282)
                                {
                                    _3289 = any(isinf(_3279));
                                }
                                else
                                {
                                    _3289 = _3282;
                                }
                                bool _3290 = !_3289;
                                bool2 _3293 = _3290.xx;
                                _7735 = _3290;
                                _7734 = float2(_3293.x ? _3279.x : 0.0f.xx.x, _3293.y ? _3279.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _3324;
                            float _3326;
                            float2 _2904 = _2887 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _7738;
                            bool _7739;
                            do
                            {
                                _3324 = _2904.x;
                                _3326 = _2904.y;
                                float _3327 = 1.0f - _3326;
                                uint _3390_dummy_parameter;
                                float4 _3339 = mul(float4((float2(_3324, _3327) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2904 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3390_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                                float _3341 = _3339.w;
                                bool _3342 = _3341 > 9.9999999747524270787835121154785e-07f;
                                if (!_3342)
                                {
                                    _7739 = _3342;
                                    _7738 = 0.0f.xx;
                                    break;
                                }
                                float2 _3355 = ((_3339.xy / _3341.xx) + 1.0f.xx) * 0.5f;
                                float2 _3366 = float2(_3355.x - _3324, _3327 - _3355.y);
                                bool _3369 = any(isnan(_3366));
                                bool _3376;
                                if (!_3369)
                                {
                                    _3376 = any(isinf(_3366));
                                }
                                else
                                {
                                    _3376 = _3369;
                                }
                                bool _3377 = !_3376;
                                bool2 _3380 = _3377.xx;
                                _7739 = _3377;
                                _7738 = float2(_3380.x ? _3366.x : 0.0f.xx.x, _3380.y ? _3366.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_7731 && _7735) && _7739))
                            {
                                _7873 = _7730;
                                _7800 = 3u;
                                _7790 = _2887;
                                _7774 = true;
                                break;
                            }
                            float2 _3409 = _2887 + _7730;
                            bool _3438 = (_2486 & 1073741824u) != 0u;
                            float2 _7750;
                            if (_3438)
                            {
                                float _3451 = ((2.0f * _3409.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3463 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3475 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3499 = ((2.0f * _3150) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7750 = (float2(atan(_3451) / _3463, atan((((2.0f * _3409.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3451 * _3451))) / _3475) + 0.5f.xx) - (float2(atan(_3499) / _3463, atan((((2.0f * _3152) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3499 * _3499))) / _3475) + 0.5f.xx);
                            }
                            else
                            {
                                _7750 = _3409 - _2887;
                            }
                            float2 _7751;
                            if (_3438)
                            {
                                float _3575 = ((2.0f * _3150) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _3624 = clamp(((((float2(atan(_3575) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3152) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3575 * _3575))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7750 * _2506)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _3627 = tan(_3624.x);
                                _7751 = (float2(_3627 / cbFI_DeviceToViewDepth.z, (tan(_3624.y) * sqrt(1.0f + (_3627 * _3627))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7751 = _2887 + (_7750 * _2506);
                            }
                            float2 _2922 = _7751 - _2362;
                            if (length(_2922 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _7873 = _7730;
                                _7800 = _7817;
                                _7790 = _2887;
                                _7774 = false;
                                break;
                            }
                            float2 _3669 = _2896 + _7734;
                            float2 _7754;
                            if (_3438)
                            {
                                float _3711 = ((2.0f * _3669.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3723 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3735 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _3759 = ((2.0f * _3237) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7754 = (float2(atan(_3711) / _3723, atan((((2.0f * _3669.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3711 * _3711))) / _3735) + 0.5f.xx) - (float2(atan(_3759) / _3723, atan((((2.0f * _3239) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3759 * _3759))) / _3735) + 0.5f.xx);
                            }
                            else
                            {
                                _7754 = _3669 - _2896;
                            }
                            float2 _7755;
                            if (_3438)
                            {
                                float _3835 = ((2.0f * _3237) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _3884 = clamp(((((float2(atan(_3835) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3239) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3835 * _3835))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7754 * _2506)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _3887 = tan(_3884.x);
                                _7755 = (float2(_3887 / cbFI_DeviceToViewDepth.z, (tan(_3884.y) * sqrt(1.0f + (_3887 * _3887))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7755 = _2896 + (_7754 * _2506);
                            }
                            float2 _2944 = (_7755 - _7751) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _3925 = _2904 + _7738;
                            float2 _7758;
                            if (_3438)
                            {
                                float _3967 = ((2.0f * _3925.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _3979 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _3991 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _4015 = ((2.0f * _3324) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7758 = (float2(atan(_3967) / _3979, atan((((2.0f * _3925.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3967 * _3967))) / _3991) + 0.5f.xx) - (float2(atan(_4015) / _3979, atan((((2.0f * _3326) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4015 * _4015))) / _3991) + 0.5f.xx);
                            }
                            else
                            {
                                _7758 = _3925 - _2904;
                            }
                            float2 _7759;
                            if (_3438)
                            {
                                float _4091 = ((2.0f * _3324) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _4140 = clamp(((((float2(atan(_4091) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3326) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4091 * _4091))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7758 * _2506)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _4143 = tan(_4140.x);
                                _7759 = (float2(_4143 / cbFI_DeviceToViewDepth.z, (tan(_4140.y) * sqrt(1.0f + (_4143 * _4143))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7759 = _2904 + (_7758 * _2506);
                            }
                            float2 _2958 = (_7759 - _7751) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _2960 = _2944.x;
                            float _2962 = _2958.y;
                            float _2965 = _2958.x;
                            float _2967 = _2944.y;
                            float _2969 = (_2960 * _2962) - (_2965 * _2967);
                            if (abs(_2969) < 9.9999997473787516355514526367188e-05f)
                            {
                                _7873 = _7730;
                                _7800 = 3u;
                                _7790 = _2887;
                                _7774 = true;
                                break;
                            }
                            float _2978 = _2922.x;
                            float _2983 = _2922.y;
                            _3003 = _2887 - (float2((_2962 * _2978) - (_2965 * _2983), ((-_2967) * _2978) + (_2960 * _2983)) / _2969.xx);
                            _7729 = _3003;
                            _7728++;
                            _7874 = _7730;
                            continue;
                        }
                        else
                        {
                            _7873 = _7874;
                            _7800 = _7817;
                            _7790 = _7729;
                            _7774 = false;
                            break;
                        }
                    }
                    if (_7774)
                    {
                        _7872 = _7873;
                        _7842 = _7790;
                        _7799 = _7800;
                        break;
                    }
                    float _4183;
                    float _4185;
                    float2 _7791;
                    bool _7792;
                    do
                    {
                        _4183 = _7790.x;
                        _4185 = _7790.y;
                        float _4186 = 1.0f - _4185;
                        uint _4249_dummy_parameter;
                        float4 _4198 = mul(float4((float2(_4183, _4186) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_7790 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4249_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _4200 = _4198.w;
                        bool _4201 = _4200 > 9.9999999747524270787835121154785e-07f;
                        if (!_4201)
                        {
                            _7792 = _4201;
                            _7791 = 0.0f.xx;
                            break;
                        }
                        float2 _4214 = ((_4198.xy / _4200.xx) + 1.0f.xx) * 0.5f;
                        float2 _4225 = float2(_4214.x - _4183, _4186 - _4214.y);
                        bool _4228 = any(isnan(_4225));
                        bool _4235;
                        if (!_4228)
                        {
                            _4235 = any(isinf(_4225));
                        }
                        else
                        {
                            _4235 = _4228;
                        }
                        bool _4236 = !_4235;
                        bool2 _4239 = _4236.xx;
                        _7792 = _4236;
                        _7791 = float2(_4239.x ? _4225.x : 0.0f.xx.x, _4239.y ? _4225.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7792)
                    {
                        _7872 = _7791;
                        _7842 = _7790;
                        _7799 = 3u;
                        break;
                    }
                    float2 _4268 = _7790 + _7791;
                    bool _4297 = (_2486 & 1073741824u) != 0u;
                    float2 _7795;
                    if (_4297)
                    {
                        float _4310 = ((2.0f * _4268.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4322 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4334 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4358 = ((2.0f * _4183) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _7795 = (float2(atan(_4310) / _4322, atan((((2.0f * _4268.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4310 * _4310))) / _4334) + 0.5f.xx) - (float2(atan(_4358) / _4322, atan((((2.0f * _4185) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4358 * _4358))) / _4334) + 0.5f.xx);
                    }
                    else
                    {
                        _7795 = _4268 - _7790;
                    }
                    float2 _7796;
                    if (_4297)
                    {
                        float _4434 = ((2.0f * _4183) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _4483 = clamp(((((float2(atan(_4434) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4185) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4434 * _4434))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7795 * _2506)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _4486 = tan(_4483.x);
                        _7796 = (float2(_4486 / cbFI_DeviceToViewDepth.z, (tan(_4483.y) * sqrt(1.0f + (_4486 * _4486))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _7796 = _7790 + (_7795 * _2506);
                    }
                    if (length((_7796 - _2362) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _7872 = _7791;
                        _7842 = _7790;
                        _7799 = 2u;
                        break;
                    }
                    bool _3035 = all(bool2(_7790.x > cbFI_MvDepthLaneSizeRcp.x, _7790.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _3044;
                    if (_3035)
                    {
                        float2 _3040 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _3044 = all(bool2(_7790.x < _3040.x, _7790.y < _3040.y));
                    }
                    else
                    {
                        _3044 = _3035;
                    }
                    _7872 = _7791;
                    _7842 = _7790;
                    _7799 = _3044 ? 0u : 1u;
                    break;
                } while(false);
                if (_7799 == 0u)
                {
                    if ((_2486 & 512u) != 0u)
                    {
                        uint _4531;
                        rw_nfru_diagnostics.InterlockedAdd(4, 1u, _4531);
                    }
                    float2 _2517 = _7842 + _7872;
                    float2 _8165;
                    if ((_2486 & 1073741824u) != 0u)
                    {
                        float _4569 = ((2.0f * _2517.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _4581 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _4593 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _4617 = ((2.0f * _7842.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8165 = (float2(atan(_4569) / _4581, atan((((2.0f * _2517.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4569 * _4569))) / _4593) + 0.5f.xx) - (float2(atan(_4617) / _4581, atan((((2.0f * _7842.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4617 * _4617))) / _4593) + 0.5f.xx);
                    }
                    else
                    {
                        _8165 = _2517 - _7842;
                    }
                    _8167 = 2u;
                    _8166 = _8165;
                    break;
                }
                uint _7957;
                float2 _8021;
                float2 _8072;
                do
                {
                    float2 _7884;
                    bool _7885;
                    do
                    {
                        uint _4960_dummy_parameter;
                        float4 _4909 = mul(float4(_3071, _3072, r_depth_tp1.Load(int3(int2(floor(_2362 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _4960_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _4911 = _4909.w;
                        bool _4912 = _4911 > 9.9999999747524270787835121154785e-07f;
                        if (!_4912)
                        {
                            _7885 = _4912;
                            _7884 = 0.0f.xx;
                            break;
                        }
                        float2 _4925 = ((_4909.xy / _4911.xx) + 1.0f.xx) * 0.5f;
                        float2 _4936 = float2(_4925.x - _3059, _3062 - _4925.y);
                        bool _4939 = any(isnan(_4936));
                        bool _4946;
                        if (!_4939)
                        {
                            _4946 = any(isinf(_4936));
                        }
                        else
                        {
                            _4946 = _4939;
                        }
                        bool _4947 = !_4946;
                        bool2 _4950 = _4947.xx;
                        _7885 = _4947;
                        _7884 = float2(_4950.x ? _4936.x : 0.0f.xx.x, _4950.y ? _4936.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7885)
                    {
                        _8072 = _7884;
                        _8021 = _7858;
                        _7957 = 3u;
                        break;
                    }
                    float2 _7887;
                    float2 _8074;
                    _7887 = _2362 - (_7884 * cbFI_Timestep);
                    _8074 = _7884;
                    float2 _4838;
                    float2 _7888;
                    bool _7932;
                    float2 _7948;
                    uint _7958;
                    float2 _8073;
                    int _7886 = 0;
                    for (;;)
                    {
                        if (_7886 < 8)
                        {
                            float _4985;
                            float _4987;
                            float2 _4722 = clamp(_7887, (-1.0f).xx, 2.0f.xx);
                            bool _7889;
                            do
                            {
                                _4985 = _4722.x;
                                _4987 = _4722.y;
                                float _4988 = 1.0f - _4987;
                                uint _5051_dummy_parameter;
                                float4 _5000 = mul(float4((float2(_4985, _4988) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4722 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5051_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5002 = _5000.w;
                                bool _5003 = _5002 > 9.9999999747524270787835121154785e-07f;
                                if (!_5003)
                                {
                                    _7889 = _5003;
                                    _7888 = 0.0f.xx;
                                    break;
                                }
                                float2 _5016 = ((_5000.xy / _5002.xx) + 1.0f.xx) * 0.5f;
                                float2 _5027 = float2(_5016.x - _4985, _4988 - _5016.y);
                                bool _5030 = any(isnan(_5027));
                                bool _5037;
                                if (!_5030)
                                {
                                    _5037 = any(isinf(_5027));
                                }
                                else
                                {
                                    _5037 = _5030;
                                }
                                bool _5038 = !_5037;
                                bool2 _5041 = _5038.xx;
                                _7889 = _5038;
                                _7888 = float2(_5041.x ? _5027.x : 0.0f.xx.x, _5041.y ? _5027.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5072;
                            float _5074;
                            float2 _4731 = _4722 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                            float2 _7892;
                            bool _7893;
                            do
                            {
                                _5072 = _4731.x;
                                _5074 = _4731.y;
                                float _5075 = 1.0f - _5074;
                                uint _5138_dummy_parameter;
                                float4 _5087 = mul(float4((float2(_5072, _5075) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4731 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5138_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5089 = _5087.w;
                                bool _5090 = _5089 > 9.9999999747524270787835121154785e-07f;
                                if (!_5090)
                                {
                                    _7893 = _5090;
                                    _7892 = 0.0f.xx;
                                    break;
                                }
                                float2 _5103 = ((_5087.xy / _5089.xx) + 1.0f.xx) * 0.5f;
                                float2 _5114 = float2(_5103.x - _5072, _5075 - _5103.y);
                                bool _5117 = any(isnan(_5114));
                                bool _5124;
                                if (!_5117)
                                {
                                    _5124 = any(isinf(_5114));
                                }
                                else
                                {
                                    _5124 = _5117;
                                }
                                bool _5125 = !_5124;
                                bool2 _5128 = _5125.xx;
                                _7893 = _5125;
                                _7892 = float2(_5128.x ? _5114.x : 0.0f.xx.x, _5128.y ? _5114.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            float _5159;
                            float _5161;
                            float2 _4739 = _4722 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                            float2 _7896;
                            bool _7897;
                            do
                            {
                                _5159 = _4739.x;
                                _5161 = _4739.y;
                                float _5162 = 1.0f - _5161;
                                uint _5225_dummy_parameter;
                                float4 _5174 = mul(float4((float2(_5159, _5162) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4739 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5225_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                                float _5176 = _5174.w;
                                bool _5177 = _5176 > 9.9999999747524270787835121154785e-07f;
                                if (!_5177)
                                {
                                    _7897 = _5177;
                                    _7896 = 0.0f.xx;
                                    break;
                                }
                                float2 _5190 = ((_5174.xy / _5176.xx) + 1.0f.xx) * 0.5f;
                                float2 _5201 = float2(_5190.x - _5159, _5162 - _5190.y);
                                bool _5204 = any(isnan(_5201));
                                bool _5211;
                                if (!_5204)
                                {
                                    _5211 = any(isinf(_5201));
                                }
                                else
                                {
                                    _5211 = _5204;
                                }
                                bool _5212 = !_5211;
                                bool2 _5215 = _5212.xx;
                                _7897 = _5212;
                                _7896 = float2(_5215.x ? _5201.x : 0.0f.xx.x, _5215.y ? _5201.y : 0.0f.xx.y);
                                break;
                            } while(false);
                            if (!((_7889 && _7893) && _7897))
                            {
                                _8073 = _7888;
                                _7958 = 3u;
                                _7948 = _4722;
                                _7932 = true;
                                break;
                            }
                            float2 _5244 = _4722 + _7888;
                            bool _5273 = (_2486 & 1073741824u) != 0u;
                            float2 _7908;
                            if (_5273)
                            {
                                float _5286 = ((2.0f * _5244.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5298 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5310 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5334 = ((2.0f * _4985) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7908 = (float2(atan(_5286) / _5298, atan((((2.0f * _5244.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5286 * _5286))) / _5310) + 0.5f.xx) - (float2(atan(_5334) / _5298, atan((((2.0f * _4987) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5334 * _5334))) / _5310) + 0.5f.xx);
                            }
                            else
                            {
                                _7908 = _5244 - _4722;
                            }
                            float2 _7909;
                            if (_5273)
                            {
                                float _5410 = ((2.0f * _4985) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5459 = clamp(((((float2(atan(_5410) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4987) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5410 * _5410))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7908 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5462 = tan(_5459.x);
                                _7909 = (float2(_5462 / cbFI_DeviceToViewDepth.z, (tan(_5459.y) * sqrt(1.0f + (_5462 * _5462))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7909 = _4722 + (_7908 * cbFI_Timestep);
                            }
                            float2 _4757 = _7909 - _2362;
                            if (length(_4757 * float2(cbFI_MvDepthLaneSize)) < 0.25f)
                            {
                                _8073 = _7888;
                                _7958 = _7817;
                                _7948 = _4722;
                                _7932 = false;
                                break;
                            }
                            float2 _5504 = _4731 + _7892;
                            float2 _7912;
                            if (_5273)
                            {
                                float _5546 = ((2.0f * _5504.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5558 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5570 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5594 = ((2.0f * _5072) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7912 = (float2(atan(_5546) / _5558, atan((((2.0f * _5504.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5546 * _5546))) / _5570) + 0.5f.xx) - (float2(atan(_5594) / _5558, atan((((2.0f * _5074) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5594 * _5594))) / _5570) + 0.5f.xx);
                            }
                            else
                            {
                                _7912 = _5504 - _4731;
                            }
                            float2 _7913;
                            if (_5273)
                            {
                                float _5670 = ((2.0f * _5072) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5719 = clamp(((((float2(atan(_5670) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5074) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5670 * _5670))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7912 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5722 = tan(_5719.x);
                                _7913 = (float2(_5722 / cbFI_DeviceToViewDepth.z, (tan(_5719.y) * sqrt(1.0f + (_5722 * _5722))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7913 = _4731 + (_7912 * cbFI_Timestep);
                            }
                            float2 _4779 = (_7913 - _7909) / cbFI_MvDepthLaneSizeRcp.x.xx;
                            float2 _5760 = _4739 + _7896;
                            float2 _7916;
                            if (_5273)
                            {
                                float _5802 = ((2.0f * _5760.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float _5814 = 2.0f * cbFI_DeviceToViewDepth.z;
                                float _5826 = 2.0f * cbFI_DeviceToViewDepth.w;
                                float _5850 = ((2.0f * _5159) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                _7916 = (float2(atan(_5802) / _5814, atan((((2.0f * _5760.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5802 * _5802))) / _5826) + 0.5f.xx) - (float2(atan(_5850) / _5814, atan((((2.0f * _5161) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5850 * _5850))) / _5826) + 0.5f.xx);
                            }
                            else
                            {
                                _7916 = _5760 - _4739;
                            }
                            float2 _7917;
                            if (_5273)
                            {
                                float _5926 = ((2.0f * _5159) - 1.0f) * cbFI_DeviceToViewDepth.z;
                                float2 _5975 = clamp(((((float2(atan(_5926) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5161) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5926 * _5926))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7916 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                                float _5978 = tan(_5975.x);
                                _7917 = (float2(_5978 / cbFI_DeviceToViewDepth.z, (tan(_5975.y) * sqrt(1.0f + (_5978 * _5978))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                            }
                            else
                            {
                                _7917 = _4739 + (_7916 * cbFI_Timestep);
                            }
                            float2 _4793 = (_7917 - _7909) / cbFI_MvDepthLaneSizeRcp.y.xx;
                            float _4795 = _4779.x;
                            float _4797 = _4793.y;
                            float _4800 = _4793.x;
                            float _4802 = _4779.y;
                            float _4804 = (_4795 * _4797) - (_4800 * _4802);
                            if (abs(_4804) < 9.9999997473787516355514526367188e-05f)
                            {
                                _8073 = _7888;
                                _7958 = 3u;
                                _7948 = _4722;
                                _7932 = true;
                                break;
                            }
                            float _4813 = _4757.x;
                            float _4818 = _4757.y;
                            _4838 = _4722 - (float2((_4797 * _4813) - (_4800 * _4818), ((-_4802) * _4813) + (_4795 * _4818)) / _4804.xx);
                            _7887 = _4838;
                            _7886++;
                            _8074 = _7888;
                            continue;
                        }
                        else
                        {
                            _8073 = _8074;
                            _7958 = _7817;
                            _7948 = _7887;
                            _7932 = false;
                            break;
                        }
                    }
                    if (_7932)
                    {
                        _8072 = _8073;
                        _8021 = _7948;
                        _7957 = _7958;
                        break;
                    }
                    float _6018;
                    float _6020;
                    float2 _7949;
                    bool _7950;
                    do
                    {
                        _6018 = _7948.x;
                        _6020 = _7948.y;
                        float _6021 = 1.0f - _6020;
                        uint _6084_dummy_parameter;
                        float4 _6033 = mul(float4((float2(_6018, _6021) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_7948 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6084_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6035 = _6033.w;
                        bool _6036 = _6035 > 9.9999999747524270787835121154785e-07f;
                        if (!_6036)
                        {
                            _7950 = _6036;
                            _7949 = 0.0f.xx;
                            break;
                        }
                        float2 _6049 = ((_6033.xy / _6035.xx) + 1.0f.xx) * 0.5f;
                        float2 _6060 = float2(_6049.x - _6018, _6021 - _6049.y);
                        bool _6063 = any(isnan(_6060));
                        bool _6070;
                        if (!_6063)
                        {
                            _6070 = any(isinf(_6060));
                        }
                        else
                        {
                            _6070 = _6063;
                        }
                        bool _6071 = !_6070;
                        bool2 _6074 = _6071.xx;
                        _7950 = _6071;
                        _7949 = float2(_6074.x ? _6060.x : 0.0f.xx.x, _6074.y ? _6060.y : 0.0f.xx.y);
                        break;
                    } while(false);
                    if (!_7950)
                    {
                        _8072 = _7949;
                        _8021 = _7948;
                        _7957 = 3u;
                        break;
                    }
                    float2 _6103 = _7948 + _7949;
                    bool _6132 = (_2486 & 1073741824u) != 0u;
                    float2 _7953;
                    if (_6132)
                    {
                        float _6145 = ((2.0f * _6103.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6157 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6169 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6193 = ((2.0f * _6018) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _7953 = (float2(atan(_6145) / _6157, atan((((2.0f * _6103.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6145 * _6145))) / _6169) + 0.5f.xx) - (float2(atan(_6193) / _6157, atan((((2.0f * _6020) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6193 * _6193))) / _6169) + 0.5f.xx);
                    }
                    else
                    {
                        _7953 = _6103 - _7948;
                    }
                    float2 _7954;
                    if (_6132)
                    {
                        float _6269 = ((2.0f * _6018) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float2 _6318 = clamp(((((float2(atan(_6269) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _6020) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6269 * _6269))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_7953 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6321 = tan(_6318.x);
                        _7954 = (float2(_6321 / cbFI_DeviceToViewDepth.z, (tan(_6318.y) * sqrt(1.0f + (_6321 * _6321))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _7954 = _7948 + (_7953 * cbFI_Timestep);
                    }
                    if (length((_7954 - _2362) * float2(cbFI_MvDepthLaneSize)) >= 0.5f)
                    {
                        _8072 = _7949;
                        _8021 = _7948;
                        _7957 = 2u;
                        break;
                    }
                    bool _4870 = all(bool2(_7948.x > cbFI_MvDepthLaneSizeRcp.x, _7948.y > cbFI_MvDepthLaneSizeRcp.y));
                    bool _4879;
                    if (_4870)
                    {
                        float2 _4875 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                        _4879 = all(bool2(_7948.x < _4875.x, _7948.y < _4875.y));
                    }
                    else
                    {
                        _4879 = _4870;
                    }
                    _8072 = _7949;
                    _8021 = _7948;
                    _7957 = _4879 ? 0u : 1u;
                    break;
                } while(false);
                if (_7957 == 0u)
                {
                    if ((_2486 & 512u) != 0u)
                    {
                        uint _6366;
                        rw_nfru_diagnostics.InterlockedAdd(8, 1u, _6366);
                    }
                    float2 _2533 = _8021 + _8072;
                    float2 _8162;
                    if ((_2486 & 1073741824u) != 0u)
                    {
                        float _6404 = ((2.0f * _2533.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        float _6416 = 2.0f * cbFI_DeviceToViewDepth.z;
                        float _6428 = 2.0f * cbFI_DeviceToViewDepth.w;
                        float _6452 = ((2.0f * _8021.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                        _8162 = (float2(atan(_6404) / _6416, atan((((2.0f * _2533.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6404 * _6404))) / _6428) + 0.5f.xx) - (float2(atan(_6452) / _6416, atan((((2.0f * _8021.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6452 * _6452))) / _6428) + 0.5f.xx);
                    }
                    else
                    {
                        _8162 = _2533 - _8021;
                    }
                    _8167 = 2u;
                    _8166 = -_8162;
                    break;
                }
                bool _6492 = (_2486 & 512u) != 0u;
                if (_6492)
                {
                    uint _6496;
                    rw_nfru_diagnostics.InterlockedAdd(20, 1u, _6496);
                }
                if (_7957 == 1u)
                {
                    if (_6492)
                    {
                        uint _6506;
                        rw_nfru_diagnostics.InterlockedAdd(116, 1u, _6506);
                    }
                }
                else
                {
                    if (_7957 == 2u)
                    {
                        if (_6492)
                        {
                            uint _6516;
                            rw_nfru_diagnostics.InterlockedAdd(248, 1u, _6516);
                        }
                    }
                }
            }
            if (_2074 > 0.25f)
            {
                _8167 = 0u;
                _8166 = _2061;
                break;
            }
            bool _6526 = (_2486 & 512u) != 0u;
            if (_6526)
            {
                uint _6530;
                rw_nfru_diagnostics.InterlockedAdd(216, 1u, _6530);
            }
            if (_2064)
            {
                if (_6526)
                {
                    uint _6540;
                    rw_nfru_diagnostics.InterlockedAdd(212, 1u, _6540);
                }
            }
            float _8085;
            _8085 = 0.0f;
            for (int _8084 = 0; _8084 < 5; )
            {
                float2 _6565 = _2362 + (float2(_527[_8084]) * cbFI_MvDepthLaneSizeRcp);
                _8085 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _6565, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _6565, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                _8084++;
                continue;
            }
            float _6583 = _8085 * 0.20000000298023223876953125f;
            if (_6583 < 0.0199999995529651641845703125f)
            {
                _8167 = 1u;
                _8166 = _2061;
                break;
            }
            float _2576 = _2362.x;
            float _2578 = _2362.y;
            float _2579 = 1.0f - _2578;
            uint _6610_dummy_parameter;
            float4 _2592 = mul(float4((float2(_2576, _2579) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_2362 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6610_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
            float _2594 = _2592.w;
            bool _2595 = _2594 > 9.9999999747524270787835121154785e-07f;
            float2 _8087;
            if (_2595)
            {
                float2 _2605 = ((_2592.xy / _2594.xx) + 1.0f.xx) * 0.5f;
                _8087 = float2(_2605.x - _2576, _2579 - _2605.y);
            }
            else
            {
                _8087 = 0.0f.xx;
            }
            if (!_2595)
            {
                if (_6526)
                {
                    uint _6632;
                    rw_nfru_diagnostics.InterlockedAdd(208, 1u, _6632);
                }
            }
            float2 _2627 = _2362 + _8087;
            bool _6657 = (_2486 & 1073741824u) != 0u;
            float2 _8089;
            if (_6657)
            {
                float _6670 = ((2.0f * _2627.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float _6682 = 2.0f * cbFI_DeviceToViewDepth.z;
                float _6694 = 2.0f * cbFI_DeviceToViewDepth.w;
                float _6718 = ((2.0f * _2576) - 1.0f) * cbFI_DeviceToViewDepth.z;
                _8089 = (float2(atan(_6670) / _6682, atan((((2.0f * _2627.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6670 * _6670))) / _6694) + 0.5f.xx) - (float2(atan(_6718) / _6682, atan((((2.0f * _2578) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6718 * _6718))) / _6694) + 0.5f.xx);
            }
            else
            {
                _8089 = _2627 - _2362;
            }
            float2 _2633[2] = { _8089, -r_warped_filled_flow_tm1.Load(int3(clamp(int2(_2362 * float2(cbFI_FlowLaneSize)), int2(0, 0), cbFI_FlowLaneSize - int2(1, 1)), 0)).xy };
            float2 _2443[2] = _2633;
            uint _8091;
            bool _8098;
            bool _8103;
            bool _8108;
            float2 _8116;
            _8116 = _2061;
            _8108 = false;
            _8103 = false;
            _8098 = false;
            _8091 = 0u;
            uint _8258;
            bool _8279;
            bool _8297;
            bool _8318;
            float2 _8339;
            float _8360;
            int _8090 = 0;
            float _8136 = _6583;
            for (; _8090 < 2; _8136 = _8360, _8116 = _8339, _8108 = _8318, _8103 = _8297, _8098 = _8279, _8091 = _8258, _8090++)
            {
                bool _2642 = _8090 == 0;
                uint _2643 = _2642 ? 32u : 42u;
                uint _2646 = _2642 ? 8u : 12u;
                if (_6526)
                {
                    uint _6762;
                    rw_nfru_diagnostics.InterlockedAdd(_2643 * 4 + 0, 1u, _6762);
                }
                bool _2654 = any(isnan(_2443[_8090]));
                bool _2661;
                if (!_2654)
                {
                    _2661 = any(isinf(_2443[_8090]));
                }
                else
                {
                    _2661 = _2654;
                }
                if (_2661)
                {
                    if (_6526)
                    {
                        uint _6772;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 1u) * 4 + 0, 1u, _6772);
                    }
                    nfruCandidateFlags |= (1u << _2646);
                    _8360 = _8136;
                    _8339 = _8116;
                    _8318 = true;
                    _8297 = _8103;
                    _8279 = _8098;
                    _8258 = _8091;
                    continue;
                }
                float _2675 = length(_2443[_8090] * _2072);
                if (_2675 < 1.0f)
                {
                    if (_6526)
                    {
                        uint _6786;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 2u) * 4 + 0, 1u, _6786);
                    }
                    nfruCandidateFlags |= (2u << _2646);
                    _8360 = _8136;
                    _8339 = _8116;
                    _8318 = _8108;
                    _8297 = _8103;
                    _8279 = _8098;
                    _8258 = _8091;
                    continue;
                }
                if (_2675 > 256.0f)
                {
                    if (_6526)
                    {
                        uint _6796;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 8u) * 4 + 0, 1u, _6796);
                    }
                }
                if (_2675 > float(max(cbFI_DisplaySize.x, cbFI_DisplaySize.y)))
                {
                    if (_6526)
                    {
                        uint _6814;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 9u) * 4 + 0, 1u, _6814);
                    }
                }
                float2 _8121;
                if (_6657)
                {
                    float _6860 = ((2.0f * _2576) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _6909 = clamp(((((float2(atan(_6860) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2578) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6860 * _6860))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2443[_8090] * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _6912 = tan(_6909.x);
                    _8121 = (float2(_6912 / cbFI_DeviceToViewDepth.z, (tan(_6909.y) * sqrt(1.0f + (_6912 * _6912))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8121 = _2362 + (_2443[_8090] * cbFI_Timestep);
                }
                float _2713 = cbFI_Timestep - 1.0f;
                float2 _8122;
                if (_6657)
                {
                    float _6985 = ((2.0f * _2576) - 1.0f) * cbFI_DeviceToViewDepth.z;
                    float2 _7034 = clamp(((((float2(atan(_6985) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2578) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6985 * _6985))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2443[_8090] * _2713)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                    float _7037 = tan(_7034.x);
                    _8122 = (float2(_7037 / cbFI_DeviceToViewDepth.z, (tan(_7034.y) * sqrt(1.0f + (_7037 * _7037))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                }
                else
                {
                    _8122 = _2362 + (_2443[_8090] * _2713);
                }
                bool _7073 = all(bool2(_8121.x > cbFI_MvDepthLaneSizeRcp.x, _8121.y > cbFI_MvDepthLaneSizeRcp.y));
                bool _7082;
                if (_7073)
                {
                    float2 _7078 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7082 = all(bool2(_8121.x < _7078.x, _8121.y < _7078.y));
                }
                else
                {
                    _7082 = _7073;
                }
                bool _7089;
                if (_7082)
                {
                    _7089 = all(bool2(_8122.x > cbFI_MvDepthLaneSizeRcp.x, _8122.y > cbFI_MvDepthLaneSizeRcp.y));
                }
                else
                {
                    _7089 = _7082;
                }
                bool _7098;
                if (_7089)
                {
                    float2 _7094 = 1.0f.xx - cbFI_MvDepthLaneSizeRcp;
                    _7098 = all(bool2(_8122.x < _7094.x, _8122.y < _7094.y));
                }
                else
                {
                    _7098 = _7089;
                }
                if (!_7098)
                {
                    if (_6526)
                    {
                        uint _7111;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 3u) * 4 + 0, 1u, _7111);
                    }
                    nfruCandidateFlags |= (3u << _2646);
                    _8360 = _8136;
                    _8339 = _8116;
                    _8318 = _8108;
                    _8297 = _8103;
                    _8279 = true;
                    _8258 = _8091;
                    continue;
                }
                if (_6526)
                {
                    uint _7121;
                    rw_nfru_diagnostics.InterlockedAdd((_2643 + 4u) * 4 + 0, 1u, _7121);
                }
                float _8124;
                _8124 = 0.0f;
                for (int _8123 = 0; _8123 < 5; )
                {
                    float2 _7143 = float2(_527[_8123]) * cbFI_MvDepthLaneSizeRcp;
                    _8124 += dot(abs(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8121 + _7143, 0.0f).xyz - r_current_interpolation_source.SampleLevel(s_LinearClamp, _8122 + _7143, 0.0f).xyz), 0.3333333432674407958984375f.xxx);
                    _8123++;
                    continue;
                }
                float _7164 = _8124 * 0.20000000298023223876953125f;
                bool _2738 = _7164 < _8136;
                bool _2745;
                if (_2738)
                {
                    _2745 = _7164 < (_8085 * 0.12000000476837158203125f);
                }
                else
                {
                    _2745 = _2738;
                }
                bool _2752;
                if (_2745)
                {
                    _2752 = (_6583 - _7164) > 0.0199999995529651641845703125f;
                }
                else
                {
                    _2752 = _2745;
                }
                bool _2755 = _2752 && (_7164 < 0.119999997317790985107421875f);
                uint _8273;
                if (_2755)
                {
                    if (_6526)
                    {
                        uint _7193;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 6u) * 4 + 0, 1u, _7193);
                    }
                    nfruCandidateFlags |= (5u << _2646);
                    _8273 = uint(_8090) + 2u;
                }
                else
                {
                    if (_6526)
                    {
                        uint _7203;
                        rw_nfru_diagnostics.InterlockedAdd((_2643 + 5u) * 4 + 0, 1u, _7203);
                    }
                    nfruCandidateFlags |= (4u << _2646);
                    _8273 = _8091;
                }
                bool2 _8371 = _2755.xx;
                _8360 = _2755 ? _7164 : _8136;
                _8339 = float2(_8371.x ? _2443[_8090].x : _8116.x, _8371.y ? _2443[_8090].y : _8116.y);
                _8318 = _8108;
                _8297 = true;
                _8279 = true;
                _8258 = _8273;
            }
            if (_8091 == 2u)
            {
                if (_6526)
                {
                    uint _7213;
                    rw_nfru_diagnostics.InterlockedAdd(156, 1u, _7213);
                }
            }
            else
            {
                if (_8091 == 3u)
                {
                    if (_6526)
                    {
                        uint _7223;
                        rw_nfru_diagnostics.InterlockedAdd(196, 1u, _7223);
                    }
                }
            }
            uint _8112;
            if (_8091 != 0u)
            {
                _8112 = _8091;
            }
            else
            {
                uint _8111;
                if (!_8098)
                {
                    _8111 = _8108 ? 7u : 4u;
                }
                else
                {
                    _8111 = (!_8103) ? 5u : 6u;
                }
                _8112 = _8111;
            }
            _8167 = _8112;
            _8166 = _8116;
            break;
        } while(false);
        bool _7298 = (_2486 & 512u) != 0u;
        if (_7298)
        {
            uint _7302;
            rw_nfru_diagnostics.InterlockedAdd(24, 1u, _7302);
        }
        if (_7298)
        {
            uint _7312;
            rw_nfru_diagnostics.InterlockedAdd((7u + _8167) * 4 + 0, 1u, _7312);
        }
        if ((nfruHoleFlags & 32u) != 0u)
        {
            if (_7298)
            {
                uint _7322;
                rw_nfru_diagnostics.InterlockedAdd((((_8167 == 2u) || (_8167 == 3u)) ? 30u : 31u) * 4 + 0, 1u, _7322);
            }
        }
        uint _7250 = (_2486 >> 16u) & 255u;
        bool _7254 = (_2486 & 1024u) != 0u;
        bool _7263;
        if (!_7254)
        {
            _7263 = (_7250 >= 9u) && (_7250 <= 11u);
        }
        else
        {
            _7263 = _7254;
        }
        if (_7263)
        {
            rw_nfru_diagnostics.Store<uint>((64u + uint((_1767.y * cbFI_MvDepthLaneSize.x) + _2000)) * 4 + 0, ((_8167 | nfruHoleFlags) | nfruCandidateFlags) | (((((nfruHoleFlags & 32u) == 0u) || (_8167 == 2u)) || (_8167 == 3u)) ? 65536u : 0u));
        }
        rw_warped_filled_motion_tp1[_1767] = float4(_8166, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
