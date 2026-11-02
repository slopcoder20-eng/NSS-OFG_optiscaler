static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static int2 _5386;
static uint _5395;

static const int2 _1345[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1559[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

cbuffer cbFI_t : register(b9, space0)
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

RWByteAddressBuffer rw_nfru_diagnostics : register(u10, space0);
Texture2D<float4> r_motion_tp1 : register(t0, space0);
Texture2D<float4> r_depth_tp1 : register(t1, space0);
Texture2D<float4> r_depth_tm1 : register(t2, space0);
Texture2D<float4> r_dynamic_mask_tm1 : register(t3, space0);
RWTexture2D<unorm float> rw_dynamic_mask_tp1 : register(u4, space0);
RWTexture2D<uint> rw_warped_motion_qdata_tp1 : register(u5, space0);
RWTexture2D<unorm float> rw_mv_holes_tp1 : register(u6, space0);
RWTexture2D<unorm float> rw_mv_holes_tm1 : register(u7, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

uint2 spvTextureSize(Texture2D<float4> Tex, uint Level, out uint Param)
{
    uint2 ret;
    Tex.GetDimensions(Level, ret.x, ret.y, Param);
    return ret;
}

void comp_main()
{
    int2 _1975 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1975.x >= cbFI_MvDepthLaneSize.x, _1975.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2261 = _1975.x + (_1975.y * cbFI_MvDepthLaneSize.x);
        float _2268 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2270 = float2(_1975);
        float2 _2274 = (_2270 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2796 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5349;
        if (_2796)
        {
            float _2809 = ((2.0f * _2274.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5349 = float2(atan(_2809) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2274.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2809 * _2809))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5349 = _2274;
        }
        uint _2851_dummy_parameter;
        float4 _2858 = r_depth_tp1.Load(int3(int2(floor(_2274 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2851_dummy_parameter))))), 0));
        float _2859 = _2858.x;
        uint _2867_dummy_parameter;
        float4 _2874 = r_depth_tp1.Load(int3(int2(floor(_2274 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2867_dummy_parameter))))), 0));
        float _2875 = _2874.x;
        float2 _2894 = float2(_2274.x, 1.0f - _2274.y);
        float2 _2898 = (_2894 * 2.0f) - 1.0f.xx;
        float _2900 = _2898.x;
        float4 _2905 = mul(float4(_2900, _2898.y, _2859, 1.0f), cbFI_MotionTP1ToTM1);
        float _2907 = _2905.w;
        float _2909 = float(_2907 < 0.0f);
        float2 _2921 = _2894 - (((_2905.xy / _2907.xx) + 1.0f.xx) * 0.5f);
        float2 _2923 = abs(_2921);
        bool2 _2929 = all(bool2(_2923.x < 9.9999997473787516355514526367188e-06f.xx.x, _2923.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2930 = float2(_2929.x ? 0.0f.xx.x : _2921.x, _2929.y ? 0.0f.xx.y : _2921.y);
        bool2 _2935 = any(isnan(_2930)).xx;
        float2 _2936 = float2(_2935.x ? 0.0f.xx.x : _2930.x, _2935.y ? 0.0f.xx.y : _2930.y);
        bool2 _2941 = any(isinf(_2936)).xx;
        float2 _2942 = float2(_2941.x ? 0.0f.xx.x : _2936.x, _2941.y ? 0.0f.xx.y : _2936.y);
        float2 _2948 = float2(-_2942.x, _2942.y);
        float _2980 = 1.0f - (log(((_2859 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5350;
        if (_2980 == 1.0f)
        {
            _5350 = _2980 + ((float(_2261) * _2268) * 0.100000001490116119384765625f);
        }
        else
        {
            _5350 = _2980;
        }
        float _2970 = 1.10000002384185791015625f - _5350;
        uint _2987_dummy_parameter;
        float2 _3002 = r_motion_tp1.Load(int3(int2(floor(_2274 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2987_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _3012 = (cbFI_pad0 & 512u) != 0u;
        if (_3012)
        {
            uint _3016;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _3016);
        }
        bool _3029;
        float _2295 = 1.0f - cbFI_Timestep;
        float2 _5351;
        float2 _5352;
        do
        {
            _3029 = !_2796;
            if (_3029)
            {
                _5352 = _3002;
                _5351 = _3002;
                break;
            }
            float2 _3036 = _2274 + _3002;
            float _3072 = ((2.0f * _3036.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3039 = (float2(atan(_3072) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3036.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3072 * _3072))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5349;
            float2 _3121 = clamp((((_5349 + (_3039 * _2295)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3124 = tan(_3121.x);
            _5352 = _3039;
            _5351 = (((float2(_3124 / cbFI_DeviceToViewDepth.z, (tan(_3121.y) * sqrt(1.0f + (_3124 * _3124))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2274) / max(_2295, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5353;
        if ((cbFI_NfruT2Flags & 262144u) != 0u)
        {
            float2 _2308 = float2(cbFI_MvDepthLaneSize);
            float _2310 = length(_2948 * _2308);
            bool _2320 = (_2909 == 0.0f) && (_2310 > 8.0f);
            bool _2327;
            if (_2320)
            {
                _2327 = length(_3002 * _2308) < (0.20000000298023223876953125f * _2310);
            }
            else
            {
                _2327 = _2320;
            }
            _5353 = _2327;
        }
        else
        {
            _5353 = false;
        }
        bool _2330 = !_5353;
        bool _2343;
        int2 _5380;
        uint _5389;
        if (_2330)
        {
            bool _5362;
            int2 _5363;
            uint _5371;
            do
            {
                float2 _3170 = float2(cbFI_MvDepthLaneSize);
                float2 _3171 = _5351 * _3170;
                float2 _3175 = _5352 * _3170;
                bool _3178 = any(isnan(_3171));
                bool _3185;
                if (!_3178)
                {
                    _3185 = any(isinf(_3171));
                }
                else
                {
                    _3185 = _3178;
                }
                bool _3192;
                if (!_3185)
                {
                    _3192 = any(isnan(_3175));
                }
                else
                {
                    _3192 = _3185;
                }
                bool _3199;
                if (!_3192)
                {
                    _3199 = any(isinf(_3175));
                }
                else
                {
                    _3199 = _3192;
                }
                bool _3205;
                if (!_3199)
                {
                    _3205 = isnan(_2970);
                }
                else
                {
                    _3205 = _3199;
                }
                bool _3211;
                if (!_3205)
                {
                    _3211 = isinf(_2970);
                }
                else
                {
                    _3211 = _3205;
                }
                if (_3211)
                {
                    _5371 = 0u;
                    _5363 = int2(0, 0);
                    _5362 = false;
                    break;
                }
                float2 _3216 = _3171 * _2295;
                bool _3219 = any(isnan(_3216));
                bool _3226;
                if (!_3219)
                {
                    _3226 = any(isinf(_3216));
                }
                else
                {
                    _3226 = _3219;
                }
                if (_3226)
                {
                    _5371 = 0u;
                    _5363 = int2(0, 0);
                    _5362 = false;
                    break;
                }
                float2 _3233 = _2270 + floor(_3216);
                bool _3236 = any(bool2(_3233.x < 0.0f.xx.x, _3233.y < 0.0f.xx.y));
                bool _3245;
                if (!_3236)
                {
                    _3245 = any(bool2(_3233.x >= _3170.x, _3233.y >= _3170.y));
                }
                else
                {
                    _3245 = _3236;
                }
                if (_3245)
                {
                    _5371 = 0u;
                    _5363 = int2(0, 0);
                    _5362 = false;
                    break;
                }
                float2 _3252 = _3175 * 1.0f;
                float _3299 = _3252.x * 16.0146636962890625f;
                int _3307 = int(clamp(sign(_3299) * ceil(abs(_3299)), -16383.0f, 16383.0f));
                float _3311 = _3252.y * 16.0146636962890625f;
                int _3319 = int(clamp(sign(_3311) * ceil(abs(_3311)), -16383.0f, 16383.0f));
                int _3326 = abs(_3307);
                int _3328 = abs(_3319);
                int _3332 = clamp(firstbithigh(max(_3326, _3328)), 0, 15);
                int _3335 = max((_3332 - 6), 0);
                _5371 = (((((uint((int(round(_2970 * 1860.9090576171875f)) & 2047) << 20) | uint((_3332 & 15) << 16)) | uint(int(_3307 < 0) << 15)) | uint(int(_3319 < 0) << 14)) | uint((clamp(_3326 >> _3335, 0, 127) & 127) << 7)) | uint(clamp(_3328 >> _3335, 0, 127) & 127)) & 2147483647u;
                _5363 = int2(_3233);
                _5362 = true;
                break;
            } while(false);
            _5389 = _5371;
            _5380 = _5363;
            _2343 = _5362;
        }
        else
        {
            _5389 = _5395;
            _5380 = _5386;
            _2343 = _2330;
        }
        if (_2343)
        {
            if (_3012)
            {
                uint _3421;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3421);
            }
            uint _3427;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5380], _5389, _3427);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5397 = 0; _5397 < 3; _5397++)
                {
                    int2 _2363 = _5380 + _1345[_5397];
                    if (all(bool2(_2363.x < cbFI_MvDepthLaneSize.x, _2363.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3432;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2363], _5389, _3432);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2385 = _2274 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2390 = _2274 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2395 = _2385.x < 1.0f;
                bool _2402;
                if (_2395)
                {
                    uint _3453_dummy_parameter;
                    float4 _3460 = r_depth_tp1.Load(int3(int2(floor(_2385 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3453_dummy_parameter))))), 0));
                    float _3461 = _3460.x;
                    _2402 = abs(_2875 - _3461) <= ((0.0500000007450580596923828125f * max(abs(_2875), abs(_3461))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2402 = _2395;
                }
                bool _2405 = _2390.y < 1.0f;
                bool _2412;
                if (_2405)
                {
                    uint _3483_dummy_parameter;
                    float4 _3490 = r_depth_tp1.Load(int3(int2(floor(_2390 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3483_dummy_parameter))))), 0));
                    float _3491 = _3490.x;
                    _2412 = abs(_2875 - _3491) <= ((0.0500000007450580596923828125f * max(abs(_2875), abs(_3491))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2412 = _2405;
                }
                float2 _3515 = float2(cbFI_MvDepthLaneSize);
                float2 _3516 = (_2274 + (_3002 * _2295)) * _3515;
                uint _3523_dummy_parameter;
                uint _3560_dummy_parameter;
                float2 _5398;
                if (_2402)
                {
                    _5398 = ((_2385 + ((r_motion_tp1.Load(int3(int2(floor(_2385 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3523_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2295)) * _3515) - _3516;
                }
                else
                {
                    _5398 = float2(1.0f, 0.0f);
                }
                float2 _5399;
                if (_2412)
                {
                    _5399 = ((_2390 + ((r_motion_tp1.Load(int3(int2(floor(_2390 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3560_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2295)) * _3515) - _3516;
                }
                else
                {
                    _5399 = float2(0.0f, 1.0f);
                }
                bool _3616 = any(isnan(_5398));
                bool _3623;
                if (!_3616)
                {
                    _3623 = any(isinf(_5398));
                }
                else
                {
                    _3623 = _3616;
                }
                bool2 _5534 = _3623.xx;
                float2 _5535 = float2(_5534.x ? float2(1.0f, 0.0f).x : _5398.x, _5534.y ? float2(1.0f, 0.0f).y : _5398.y);
                bool _3628 = any(isnan(_5399));
                bool _3635;
                if (!_3628)
                {
                    _3635 = any(isinf(_5399));
                }
                else
                {
                    _3635 = _3628;
                }
                bool2 _5536 = _3635.xx;
                float2 _5537 = float2(_5536.x ? float2(0.0f, 1.0f).x : _5399.x, _5536.y ? float2(0.0f, 1.0f).y : _5399.y);
                int2 _3651 = int2(clamp(floor(min(0.0f.xx, _5535) + min(0.0f.xx, _5537)), (-3.0f).xx, 0.0f.xx));
                int2 _3657 = int2(clamp(ceil(max(0.0f.xx, _5535) + max(0.0f.xx, _5537)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3665 = _3651.y;
                for (int _5429 = _3665; _5429 <= _3657.y; _5429++)
                {
                    int _3674 = _3651.x;
                    for (int _5516 = _3674; _5516 <= _3657.x; _5516++)
                    {
                        if ((_5516 == 0) && (_5429 == 0))
                        {
                            continue;
                        }
                        int2 _3693 = _5380 + int2(_5516, _5429);
                        bool _3696 = all(bool2(_3693.x >= int2(0, 0).x, _3693.y >= int2(0, 0).y));
                        bool _3703;
                        if (_3696)
                        {
                            _3703 = all(bool2(_3693.x < cbFI_MvDepthLaneSize.x, _3693.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3703 = _3696;
                        }
                        if (_3703)
                        {
                            uint _3721;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3693], _5389, _3721);
                        }
                    }
                }
            }
        }
        else
        {
            if (_3012)
            {
                uint _3730;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3730);
            }
        }
        uint _3739_dummy_parameter;
        int2 _3739 = int2(spvTextureSize(r_depth_tp1, uint(0), _3739_dummy_parameter));
        float _2102[9];
        _2102[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3739))), int2(0, 0), _3739 - int2(1, 1)), 0)).x;
        uint _3764_dummy_parameter;
        int2 _3764 = int2(spvTextureSize(r_depth_tp1, uint(0), _3764_dummy_parameter));
        _2102[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3764))) + int2(1, 0), int2(0, 0), _3764 - int2(1, 1)), 0)).x;
        uint _3789_dummy_parameter;
        int2 _3789 = int2(spvTextureSize(r_depth_tp1, uint(0), _3789_dummy_parameter));
        _2102[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3789))) + int2(0, 1), int2(0, 0), _3789 - int2(1, 1)), 0)).x;
        uint _3814_dummy_parameter;
        int2 _3814 = int2(spvTextureSize(r_depth_tp1, uint(0), _3814_dummy_parameter));
        _2102[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3814))) + int2(0, -1), int2(0, 0), _3814 - int2(1, 1)), 0)).x;
        uint _3839_dummy_parameter;
        int2 _3839 = int2(spvTextureSize(r_depth_tp1, uint(0), _3839_dummy_parameter));
        _2102[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3839))) + int2(-1, 0), int2(0, 0), _3839 - int2(1, 1)), 0)).x;
        uint _3864_dummy_parameter;
        int2 _3864 = int2(spvTextureSize(r_depth_tp1, uint(0), _3864_dummy_parameter));
        _2102[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3864))) + int2(-1, 1), int2(0, 0), _3864 - int2(1, 1)), 0)).x;
        uint _3889_dummy_parameter;
        int2 _3889 = int2(spvTextureSize(r_depth_tp1, uint(0), _3889_dummy_parameter));
        _2102[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3889))) + int2(1, 1), int2(0, 0), _3889 - int2(1, 1)), 0)).x;
        uint _3914_dummy_parameter;
        int2 _3914 = int2(spvTextureSize(r_depth_tp1, uint(0), _3914_dummy_parameter));
        _2102[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3914))) + int2(-1, -1), int2(0, 0), _3914 - int2(1, 1)), 0)).x;
        uint _3939_dummy_parameter;
        int2 _3939 = int2(spvTextureSize(r_depth_tp1, uint(0), _3939_dummy_parameter));
        _2102[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3939))) + int2(1, -1), int2(0, 0), _3939 - int2(1, 1)), 0)).x;
        int _5431;
        _5431 = 0;
        float _5538;
        int _5539;
        int _5430 = 1;
        float _5514 = _2102[0];
        for (; _5430 < 9; _5514 = _5538, _5431 = _5539, _5430++)
        {
            bool _2485 = _2102[_5430] < _5514;
            _5538 = _2485 ? _2102[_5430] : _5514;
            _5539 = _2485 ? _5430 : _5431;
        }
        uint _3964_dummy_parameter;
        int2 _3964 = int2(spvTextureSize(r_motion_tp1, uint(0), _3964_dummy_parameter));
        float2 _3982 = r_motion_tp1.Load(int3(clamp(int2(floor(_2274 * float2(_3964))) + _1559[_5431], int2(0, 0), _3964 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5432;
        do
        {
            if (_3029)
            {
                _5432 = _3982;
                break;
            }
            float2 _4006 = _2274 + _3982;
            float _4042 = ((2.0f * _4006.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4091 = clamp((((_5349 + (((float2(atan(_4042) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4006.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4042 * _4042))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5349) * _2295)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4094 = tan(_4091.x);
            _5432 = (((float2(_4094 / cbFI_DeviceToViewDepth.z, (tan(_4091.y) * sqrt(1.0f + (_4094 * _4094))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2274) / max(_2295, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _4128 = float2(cbFI_MvDepthLaneSize);
        rw_mv_holes_tp1[_1975 + int2(floor((_5432 * _4128) * _2295))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1975 + int2(floor(_3982 * _4128))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4164_dummy_parameter;
        float4 _4171 = r_depth_tm1.Load(int3(int2(floor(_2274 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4164_dummy_parameter))))), 0));
        float _4172 = _4171.x;
        float4 _4202 = mul(float4(_2900, _2898.y, _4172, 1.0f), cbFI_MotionTM1ToTP1);
        float _4204 = _4202.w;
        float2 _4218 = _2894 - (((_4202.xy / _4204.xx) + 1.0f.xx) * 0.5f);
        float2 _4220 = abs(_4218);
        bool2 _4226 = all(bool2(_4220.x < 9.9999997473787516355514526367188e-06f.xx.x, _4220.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4227 = float2(_4226.x ? 0.0f.xx.x : _4218.x, _4226.y ? 0.0f.xx.y : _4218.y);
        bool2 _4232 = any(isnan(_4227)).xx;
        float2 _4233 = float2(_4232.x ? 0.0f.xx.x : _4227.x, _4232.y ? 0.0f.xx.y : _4227.y);
        bool2 _4238 = any(isinf(_4233)).xx;
        float2 _4239 = float2(_4238.x ? 0.0f.xx.x : _4233.x, _4238.y ? 0.0f.xx.y : _4233.y);
        float2 _4245 = float2(-_4239.x, _4239.y);
        float2 _2526 = _2948 * _4128;
        float2 _2530 = _3002 * _4128;
        float2 _4300 = _2526 * 16.0146636962890625f;
        float2 _4310 = float2(int2(clamp(sign(_4300) * ceil(abs(_4300)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4326 = _2530 * 16.0146636962890625f;
        float2 _4336 = float2(int2(clamp(sign(_4326) * ceil(abs(_4326)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5433;
        if (max(max(length(_4310), length(_4336)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5433 = 0.0f;
        }
        else
        {
            _5433 = float(length(_4310 - _4336) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2535 = uint(_5433 > 0.0f);
        float _2547 = length(_2530);
        if (_2547 > 4.0f)
        {
            if (_3012)
            {
                uint _4353;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4353);
            }
        }
        bool _2559 = ((cbFI_pad0 & 2048u) != 0u) && (_2535 != 0u);
        bool _2571;
        if (_2559)
        {
            _2571 = length(_2526 - _2530) < (0.07999999821186065673828125f * max(length(_2526), _2547));
        }
        else
        {
            _2571 = _2559;
        }
        bool _2577 = (cbFI_NfruT2Flags & 2048u) != 0u;
        bool _2585;
        if (_2577)
        {
            _2585 = length(_2526 - _2530) > 2.0f;
        }
        else
        {
            _2585 = _2577;
        }
        uint _5542 = ((cbFI_NfruT2Flags & 4096u) != 0u) ? 1u : (_2585 ? 1u : (_2571 ? 0u : _2535));
        rw_dynamic_mask_tp1[_1975] = float4(clamp(float(_5542 + uint(_2909)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5542 != 0u)
        {
            if (_3012)
            {
                uint _4372;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4372);
            }
        }
        if (_2909 > 0.0f)
        {
            if (_3012)
            {
                uint _4382;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4382);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2619 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2625;
        if (_2619)
        {
            _2625 = (1.0f - (log(((_4172 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2625 = _2619;
        }
        if (_2625)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1975, 0)).x) + uint(float(_4204 < 0.0f))) > 0u)
        {
            if (_3012)
            {
                uint _4402;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4402);
            }
            break;
        }
        float _4435 = 1.0f - (log(((_4172 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5454;
        if (_4435 == 1.0f)
        {
            _5454 = _4435 + ((float(_2261) * _2268) * 0.100000001490116119384765625f);
        }
        else
        {
            _5454 = _4435;
        }
        float _4425 = 1.10000002384185791015625f - _5454;
        float2 _5455;
        float2 _5456;
        do
        {
            if (_3029)
            {
                _5456 = _4245;
                _5455 = _4245;
                break;
            }
            float2 _4454 = _2274 + _4245;
            float _4490 = ((2.0f * _4454.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4457 = (float2(atan(_4490) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4454.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4490 * _4490))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5349;
            float2 _4539 = clamp((((_5349 + (_4457 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4542 = tan(_4539.x);
            _5456 = _4457;
            _5455 = (((float2(_4542 / cbFI_DeviceToViewDepth.z, (tan(_4539.y) * sqrt(1.0f + (_4542 * _4542))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2274) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5458;
        int2 _5459;
        uint _5467;
        do
        {
            float2 _4589 = _5455 * _4128;
            float2 _4593 = _5456 * _4128;
            bool _4596 = any(isnan(_4589));
            bool _4603;
            if (!_4596)
            {
                _4603 = any(isinf(_4589));
            }
            else
            {
                _4603 = _4596;
            }
            bool _4610;
            if (!_4603)
            {
                _4610 = any(isnan(_4593));
            }
            else
            {
                _4610 = _4603;
            }
            bool _4617;
            if (!_4610)
            {
                _4617 = any(isinf(_4593));
            }
            else
            {
                _4617 = _4610;
            }
            bool _4623;
            if (!_4617)
            {
                _4623 = isnan(_4425);
            }
            else
            {
                _4623 = _4617;
            }
            bool _4629;
            if (!_4623)
            {
                _4629 = isinf(_4425);
            }
            else
            {
                _4629 = _4623;
            }
            if (_4629)
            {
                _5467 = 0u;
                _5459 = int2(0, 0);
                _5458 = false;
                break;
            }
            float2 _4634 = _4589 * cbFI_Timestep;
            bool _4637 = any(isnan(_4634));
            bool _4644;
            if (!_4637)
            {
                _4644 = any(isinf(_4634));
            }
            else
            {
                _4644 = _4637;
            }
            if (_4644)
            {
                _5467 = 0u;
                _5459 = int2(0, 0);
                _5458 = false;
                break;
            }
            float2 _4651 = _2270 + floor(_4634);
            bool _4654 = any(bool2(_4651.x < 0.0f.xx.x, _4651.y < 0.0f.xx.y));
            bool _4663;
            if (!_4654)
            {
                _4663 = any(bool2(_4651.x >= _4128.x, _4651.y >= _4128.y));
            }
            else
            {
                _4663 = _4654;
            }
            if (_4663)
            {
                _5467 = 0u;
                _5459 = int2(0, 0);
                _5458 = false;
                break;
            }
            float2 _4670 = _4593 * (-1.0f);
            float _4717 = _4670.x * 16.0146636962890625f;
            int _4725 = int(clamp(sign(_4717) * ceil(abs(_4717)), -16383.0f, 16383.0f));
            float _4729 = _4670.y * 16.0146636962890625f;
            int _4737 = int(clamp(sign(_4729) * ceil(abs(_4729)), -16383.0f, 16383.0f));
            int _4744 = abs(_4725);
            int _4746 = abs(_4737);
            int _4750 = clamp(firstbithigh(max(_4744, _4746)), 0, 15);
            int _4753 = max((_4750 - 6), 0);
            _5467 = (((((uint((int(round(_4425 * 1860.9090576171875f)) & 2047) << 20) | uint((_4750 & 15) << 16)) | uint(int(_4725 < 0) << 15)) | uint(int(_4737 < 0) << 14)) | uint((clamp(_4744 >> _4753, 0, 127) & 127) << 7)) | uint(clamp(_4746 >> _4753, 0, 127) & 127)) & 2147483647u;
            _5459 = int2(_4651);
            _5458 = true;
            break;
        } while(false);
        if (_5458)
        {
            uint _4835;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5459], _5467, _4835);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5475 = 0; _5475 < 3; _5475++)
                {
                    int2 _2674 = _5459 + _1345[_5475];
                    if (all(bool2(_2674.x < cbFI_MvDepthLaneSize.x, _2674.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4840;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2674], _5467, _4840);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2696 = _2274 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2701 = _2274 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4857_dummy_parameter;
                float4 _4864 = r_depth_tm1.Load(int3(int2(floor(_2274 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4857_dummy_parameter))))), 0));
                float _4865 = _4864.x;
                uint _4873_dummy_parameter;
                float4 _4880 = r_depth_tm1.Load(int3(int2(floor(_2696 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4873_dummy_parameter))))), 0));
                float _4881 = _4880.x;
                uint _4889_dummy_parameter;
                float4 _4896 = r_depth_tm1.Load(int3(int2(floor(_2701 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4889_dummy_parameter))))), 0));
                float _4897 = _4896.x;
                float _4912 = _2696.x;
                float2 _4916 = float2(_4912, 1.0f - _2696.y);
                float4 _4927 = mul(float4((_4916 * 2.0f) - 1.0f.xx, _4881, 1.0f), cbFI_MotionTM1ToTP1);
                float _4929 = _4927.w;
                float2 _4943 = _4916 - (((_4927.xy / _4929.xx) + 1.0f.xx) * 0.5f);
                float2 _4945 = abs(_4943);
                bool2 _4951 = all(bool2(_4945.x < 9.9999997473787516355514526367188e-06f.xx.x, _4945.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4952 = float2(_4951.x ? 0.0f.xx.x : _4943.x, _4951.y ? 0.0f.xx.y : _4943.y);
                bool2 _4957 = any(isnan(_4952)).xx;
                float2 _4958 = float2(_4957.x ? 0.0f.xx.x : _4952.x, _4957.y ? 0.0f.xx.y : _4952.y);
                bool2 _4963 = any(isinf(_4958)).xx;
                float2 _4964 = float2(_4963.x ? 0.0f.xx.x : _4958.x, _4963.y ? 0.0f.xx.y : _4958.y);
                float _4986 = _2701.y;
                float2 _4988 = float2(_2701.x, 1.0f - _4986);
                float4 _4999 = mul(float4((_4988 * 2.0f) - 1.0f.xx, _4897, 1.0f), cbFI_MotionTM1ToTP1);
                float _5001 = _4999.w;
                float2 _5015 = _4988 - (((_4999.xy / _5001.xx) + 1.0f.xx) * 0.5f);
                float2 _5017 = abs(_5015);
                bool2 _5023 = all(bool2(_5017.x < 9.9999997473787516355514526367188e-06f.xx.x, _5017.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _5024 = float2(_5023.x ? 0.0f.xx.x : _5015.x, _5023.y ? 0.0f.xx.y : _5015.y);
                bool2 _5029 = any(isnan(_5024)).xx;
                float2 _5030 = float2(_5029.x ? 0.0f.xx.x : _5024.x, _5029.y ? 0.0f.xx.y : _5024.y);
                bool2 _5035 = any(isinf(_5030)).xx;
                float2 _5036 = float2(_5035.x ? 0.0f.xx.x : _5030.x, _5035.y ? 0.0f.xx.y : _5030.y);
                bool _2723 = (_4912 < 1.0f) && (float(_4929 < 0.0f) == 0.0f);
                bool _2729;
                if (_2723)
                {
                    _2729 = abs(_4865 - _4881) <= ((0.0500000007450580596923828125f * max(abs(_4865), abs(_4881))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2729 = _2723;
                }
                bool _2735 = (_4986 < 1.0f) && (float(_5001 < 0.0f) == 0.0f);
                bool _2741;
                if (_2735)
                {
                    _2741 = abs(_4865 - _4897) <= ((0.0500000007450580596923828125f * max(abs(_4865), abs(_4897))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2741 = _2735;
                }
                float2 _5084 = (_2274 + (_4245 * cbFI_Timestep)) * _4128;
                float2 _5476;
                if (_2729)
                {
                    _5476 = ((_2696 + (float2(-_4964.x, _4964.y) * cbFI_Timestep)) * _4128) - _5084;
                }
                else
                {
                    _5476 = float2(1.0f, 0.0f);
                }
                float2 _5477;
                if (_2741)
                {
                    _5477 = ((_2701 + (float2(-_5036.x, _5036.y) * cbFI_Timestep)) * _4128) - _5084;
                }
                else
                {
                    _5477 = float2(0.0f, 1.0f);
                }
                bool _5138 = any(isnan(_5476));
                bool _5145;
                if (!_5138)
                {
                    _5145 = any(isinf(_5476));
                }
                else
                {
                    _5145 = _5138;
                }
                bool2 _5543 = _5145.xx;
                float2 _5544 = float2(_5543.x ? float2(1.0f, 0.0f).x : _5476.x, _5543.y ? float2(1.0f, 0.0f).y : _5476.y);
                bool _5150 = any(isnan(_5477));
                bool _5157;
                if (!_5150)
                {
                    _5157 = any(isinf(_5477));
                }
                else
                {
                    _5157 = _5150;
                }
                bool2 _5545 = _5157.xx;
                float2 _5546 = float2(_5545.x ? float2(0.0f, 1.0f).x : _5477.x, _5545.y ? float2(0.0f, 1.0f).y : _5477.y);
                int2 _5173 = int2(clamp(floor(min(0.0f.xx, _5544) + min(0.0f.xx, _5546)), (-3.0f).xx, 0.0f.xx));
                int2 _5179 = int2(clamp(ceil(max(0.0f.xx, _5544) + max(0.0f.xx, _5546)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5187 = _5173.y;
                for (int _5507 = _5187; _5507 <= _5179.y; _5507++)
                {
                    int _5196 = _5173.x;
                    for (int _5508 = _5196; _5508 <= _5179.x; _5508++)
                    {
                        if ((_5508 == 0) && (_5507 == 0))
                        {
                            continue;
                        }
                        int2 _5215 = _5459 + int2(_5508, _5507);
                        bool _5218 = all(bool2(_5215.x >= int2(0, 0).x, _5215.y >= int2(0, 0).y));
                        bool _5225;
                        if (_5218)
                        {
                            _5225 = all(bool2(_5215.x < cbFI_MvDepthLaneSize.x, _5215.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5225 = _5218;
                        }
                        if (_5225)
                        {
                            uint _5243;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5215], _5467, _5243);
                        }
                    }
                }
            }
        }
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
