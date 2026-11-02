static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static int2 _5956;
static uint _5969;

static const int2 _1474[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1687[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
RWTexture2D<float> rw_depth_tm1_next : register(u8, space0);
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
    int2 _2102 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_2102.x >= cbFI_MvDepthLaneSize.x, _2102.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2404 = _2102.x + (_2102.y * cbFI_MvDepthLaneSize.x);
        int _2409 = cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y;
        float _2411 = 1.0f / float(_2409);
        float2 _2413 = float2(_2102);
        float2 _2417 = (_2413 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2942 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5908;
        if (_2942)
        {
            float _2955 = ((2.0f * _2417.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5908 = float2(atan(_2955) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2417.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2955 * _2955))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5908 = _2417;
        }
        uint _3054;
        bool _3056;
        uint _2997_dummy_parameter;
        float4 _3004 = r_depth_tp1.Load(int3(int2(floor(_2417 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2997_dummy_parameter))))), 0));
        float _3005 = _3004.x;
        uint _3013_dummy_parameter;
        float4 _3020 = r_depth_tp1.Load(int3(int2(floor(_2417 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3013_dummy_parameter))))), 0));
        float _3021 = _3020.x;
        rw_depth_tm1_next[_2102] = float4(_3005, 0.0f, 0.0f, 0.0f).x;
        float4x4 _5913;
        do
        {
            float4x4 _3032;
            bool _5912;
            do
            {
                _3032 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                _3054 = cbFI_NfruT2Flags;
                _3056 = (_3054 & 524288u) == 0u;
                if (_3056)
                {
                    _5912 = false;
                    break;
                }
                uint _3066 = (64u + uint(_2409)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                if (rw_nfru_diagnostics.Load<uint>((_3066 + 32u) * 4 + 0) != 1u)
                {
                    _5912 = false;
                    break;
                }
                uint _5909;
                _5909 = 0u;
                for (; _5909 < 4u; _5909++)
                {
                    for (uint _5910 = 0u; _5910 < 4u; )
                    {
                        _3032[_5909][_5910] = asfloat(rw_nfru_diagnostics.Load<uint>(((_3066 + (_5909 * 4u)) + _5910) * 4 + 0));
                        _5910++;
                        continue;
                    }
                }
                _5912 = true;
                break;
            } while(false);
            if (_5912)
            {
                _5913 = _3032;
                break;
            }
            _5913 = cbFI_MotionTP1ToTM1;
            break;
        } while(false);
        float2 _3147 = float2(_2417.x, 1.0f - _2417.y);
        float2 _3151 = (_3147 * 2.0f) - 1.0f.xx;
        float _3153 = _3151.x;
        float4 _3158 = mul(float4(_3153, _3151.y, _3005, 1.0f), _5913);
        float _3160 = _3158.w;
        float _3162 = float(_3160 < 0.0f);
        float2 _3174 = _3147 - (((_3158.xy / _3160.xx) + 1.0f.xx) * 0.5f);
        float2 _3176 = abs(_3174);
        bool2 _3182 = all(bool2(_3176.x < 9.9999997473787516355514526367188e-06f.xx.x, _3176.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _3183 = float2(_3182.x ? 0.0f.xx.x : _3174.x, _3182.y ? 0.0f.xx.y : _3174.y);
        bool2 _3188 = any(isnan(_3183)).xx;
        float2 _3189 = float2(_3188.x ? 0.0f.xx.x : _3183.x, _3188.y ? 0.0f.xx.y : _3183.y);
        bool2 _3194 = any(isinf(_3189)).xx;
        float2 _3195 = float2(_3194.x ? 0.0f.xx.x : _3189.x, _3194.y ? 0.0f.xx.y : _3189.y);
        float2 _3201 = float2(-_3195.x, _3195.y);
        float _3233 = 1.0f - (log((_3005 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5918;
        if (_3233 == 1.0f)
        {
            _5918 = _3233 + ((float(_2404) * _2411) * 0.100000001490116119384765625f);
        }
        else
        {
            _5918 = _3233;
        }
        float _3223 = 1.10000002384185791015625f - _5918;
        uint _3240_dummy_parameter;
        float2 _3255 = r_motion_tp1.Load(int3(int2(floor(_2417 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3240_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _3265 = (cbFI_pad0 & 512u) != 0u;
        if (_3265)
        {
            uint _3269;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _3269);
        }
        bool _3282;
        float _2441 = 1.0f - cbFI_Timestep;
        float2 _5919;
        float2 _5920;
        do
        {
            _3282 = !_2942;
            if (_3282)
            {
                _5920 = _3255;
                _5919 = _3255;
                break;
            }
            float2 _3289 = _2417 + _3255;
            float _3325 = ((2.0f * _3289.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3292 = (float2(atan(_3325) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3289.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3325 * _3325))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5908;
            float2 _3374 = clamp((((_5908 + (_3292 * _2441)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3377 = tan(_3374.x);
            _5920 = _3292;
            _5919 = (((float2(_3377 / cbFI_DeviceToViewDepth.z, (tan(_3374.y) * sqrt(1.0f + (_3377 * _3377))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2417) / max(_2441, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5921;
        if ((_3054 & 262144u) != 0u)
        {
            float2 _2454 = float2(cbFI_MvDepthLaneSize);
            float _2456 = length(_3201 * _2454);
            bool _2466 = (_3162 == 0.0f) && (_2456 > 8.0f);
            bool _2473;
            if (_2466)
            {
                _2473 = length(_3255 * _2454) < (0.20000000298023223876953125f * _2456);
            }
            else
            {
                _2473 = _2466;
            }
            _5921 = _2473;
        }
        else
        {
            _5921 = false;
        }
        bool _2476 = !_5921;
        bool _2489;
        int2 _5948;
        uint _5961;
        if (_2476)
        {
            bool _5930;
            int2 _5931;
            uint _5939;
            do
            {
                float2 _3423 = float2(cbFI_MvDepthLaneSize);
                float2 _3424 = _5919 * _3423;
                float2 _3428 = _5920 * _3423;
                bool _3431 = any(isnan(_3424));
                bool _3438;
                if (!_3431)
                {
                    _3438 = any(isinf(_3424));
                }
                else
                {
                    _3438 = _3431;
                }
                bool _3445;
                if (!_3438)
                {
                    _3445 = any(isnan(_3428));
                }
                else
                {
                    _3445 = _3438;
                }
                bool _3452;
                if (!_3445)
                {
                    _3452 = any(isinf(_3428));
                }
                else
                {
                    _3452 = _3445;
                }
                bool _3458;
                if (!_3452)
                {
                    _3458 = isnan(_3223);
                }
                else
                {
                    _3458 = _3452;
                }
                bool _3464;
                if (!_3458)
                {
                    _3464 = isinf(_3223);
                }
                else
                {
                    _3464 = _3458;
                }
                if (_3464)
                {
                    _5939 = 0u;
                    _5931 = int2(0, 0);
                    _5930 = false;
                    break;
                }
                float2 _3469 = _3424 * _2441;
                bool _3472 = any(isnan(_3469));
                bool _3479;
                if (!_3472)
                {
                    _3479 = any(isinf(_3469));
                }
                else
                {
                    _3479 = _3472;
                }
                if (_3479)
                {
                    _5939 = 0u;
                    _5931 = int2(0, 0);
                    _5930 = false;
                    break;
                }
                float2 _3486 = _2413 + floor(_3469);
                bool _3489 = any(bool2(_3486.x < 0.0f.xx.x, _3486.y < 0.0f.xx.y));
                bool _3498;
                if (!_3489)
                {
                    _3498 = any(bool2(_3486.x >= _3423.x, _3486.y >= _3423.y));
                }
                else
                {
                    _3498 = _3489;
                }
                if (_3498)
                {
                    _5939 = 0u;
                    _5931 = int2(0, 0);
                    _5930 = false;
                    break;
                }
                float2 _3505 = _3428 * 1.0f;
                float _3552 = _3505.x * 16.0146636962890625f;
                int _3560 = int(clamp(sign(_3552) * ceil(abs(_3552)), -16383.0f, 16383.0f));
                float _3564 = _3505.y * 16.0146636962890625f;
                int _3572 = int(clamp(sign(_3564) * ceil(abs(_3564)), -16383.0f, 16383.0f));
                int _3579 = abs(_3560);
                int _3581 = abs(_3572);
                int _3585 = clamp(firstbithigh(max(_3579, _3581)), 0, 15);
                int _3588 = max((_3585 - 6), 0);
                _5939 = (((((uint((int(round(_3223 * 1860.9090576171875f)) & 2047) << 20) | uint((_3585 & 15) << 16)) | uint(int(_3560 < 0) << 15)) | uint(int(_3572 < 0) << 14)) | uint((clamp(_3579 >> _3588, 0, 127) & 127) << 7)) | uint(clamp(_3581 >> _3588, 0, 127) & 127)) & 2147483647u;
                _5931 = int2(_3486);
                _5930 = true;
                break;
            } while(false);
            _5961 = _5939;
            _5948 = _5931;
            _2489 = _5930;
        }
        else
        {
            _5961 = _5969;
            _5948 = _5956;
            _2489 = _2476;
        }
        if (_2489)
        {
            if (_3265)
            {
                uint _3674;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3674);
            }
            uint _3680;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5948], _5961, _3680);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5973 = 0; _5973 < 3; _5973++)
                {
                    int2 _2509 = _5948 + _1474[_5973];
                    if (all(bool2(_2509.x < cbFI_MvDepthLaneSize.x, _2509.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3685;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2509], _5961, _3685);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2531 = _2417 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2536 = _2417 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2541 = _2531.x < 1.0f;
                bool _2548;
                if (_2541)
                {
                    uint _3706_dummy_parameter;
                    float4 _3713 = r_depth_tp1.Load(int3(int2(floor(_2531 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3706_dummy_parameter))))), 0));
                    float _3714 = _3713.x;
                    _2548 = abs(_3021 - _3714) <= ((0.0500000007450580596923828125f * max(abs(_3021), abs(_3714))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2548 = _2541;
                }
                bool _2551 = _2536.y < 1.0f;
                bool _2558;
                if (_2551)
                {
                    uint _3736_dummy_parameter;
                    float4 _3743 = r_depth_tp1.Load(int3(int2(floor(_2536 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3736_dummy_parameter))))), 0));
                    float _3744 = _3743.x;
                    _2558 = abs(_3021 - _3744) <= ((0.0500000007450580596923828125f * max(abs(_3021), abs(_3744))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2558 = _2551;
                }
                float2 _3768 = float2(cbFI_MvDepthLaneSize);
                float2 _3769 = (_2417 + (_3255 * _2441)) * _3768;
                uint _3776_dummy_parameter;
                uint _3813_dummy_parameter;
                float2 _5974;
                if (_2548)
                {
                    _5974 = ((_2531 + ((r_motion_tp1.Load(int3(int2(floor(_2531 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3776_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2441)) * _3768) - _3769;
                }
                else
                {
                    _5974 = float2(1.0f, 0.0f);
                }
                float2 _5975;
                if (_2558)
                {
                    _5975 = ((_2536 + ((r_motion_tp1.Load(int3(int2(floor(_2536 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3813_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2441)) * _3768) - _3769;
                }
                else
                {
                    _5975 = float2(0.0f, 1.0f);
                }
                bool _3869 = any(isnan(_5974));
                bool _3876;
                if (!_3869)
                {
                    _3876 = any(isinf(_5974));
                }
                else
                {
                    _3876 = _3869;
                }
                bool2 _6145 = _3876.xx;
                float2 _6146 = float2(_6145.x ? float2(1.0f, 0.0f).x : _5974.x, _6145.y ? float2(1.0f, 0.0f).y : _5974.y);
                bool _3881 = any(isnan(_5975));
                bool _3888;
                if (!_3881)
                {
                    _3888 = any(isinf(_5975));
                }
                else
                {
                    _3888 = _3881;
                }
                bool2 _6147 = _3888.xx;
                float2 _6148 = float2(_6147.x ? float2(0.0f, 1.0f).x : _5975.x, _6147.y ? float2(0.0f, 1.0f).y : _5975.y);
                int2 _3904 = int2(clamp(floor(min(0.0f.xx, _6146) + min(0.0f.xx, _6148)), (-3.0f).xx, 0.0f.xx));
                int2 _3910 = int2(clamp(ceil(max(0.0f.xx, _6146) + max(0.0f.xx, _6148)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3918 = _3904.y;
                for (int _6005 = _3918; _6005 <= _3910.y; _6005++)
                {
                    int _3927 = _3904.x;
                    for (int _6127 = _3927; _6127 <= _3910.x; _6127++)
                    {
                        if ((_6127 == 0) && (_6005 == 0))
                        {
                            continue;
                        }
                        int2 _3946 = _5948 + int2(_6127, _6005);
                        bool _3949 = all(bool2(_3946.x >= int2(0, 0).x, _3946.y >= int2(0, 0).y));
                        bool _3956;
                        if (_3949)
                        {
                            _3956 = all(bool2(_3946.x < cbFI_MvDepthLaneSize.x, _3946.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3956 = _3949;
                        }
                        if (_3956)
                        {
                            uint _3974;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3946], _5961, _3974);
                        }
                    }
                }
            }
        }
        else
        {
            if (_3265)
            {
                uint _3983;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3983);
            }
        }
        uint _3992_dummy_parameter;
        int2 _3992 = int2(spvTextureSize(r_depth_tp1, uint(0), _3992_dummy_parameter));
        float _2245[9];
        _2245[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_3992))), int2(0, 0), _3992 - int2(1, 1)), 0)).x;
        uint _4017_dummy_parameter;
        int2 _4017 = int2(spvTextureSize(r_depth_tp1, uint(0), _4017_dummy_parameter));
        _2245[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4017))) + int2(1, 0), int2(0, 0), _4017 - int2(1, 1)), 0)).x;
        uint _4042_dummy_parameter;
        int2 _4042 = int2(spvTextureSize(r_depth_tp1, uint(0), _4042_dummy_parameter));
        _2245[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4042))) + int2(0, 1), int2(0, 0), _4042 - int2(1, 1)), 0)).x;
        uint _4067_dummy_parameter;
        int2 _4067 = int2(spvTextureSize(r_depth_tp1, uint(0), _4067_dummy_parameter));
        _2245[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4067))) + int2(0, -1), int2(0, 0), _4067 - int2(1, 1)), 0)).x;
        uint _4092_dummy_parameter;
        int2 _4092 = int2(spvTextureSize(r_depth_tp1, uint(0), _4092_dummy_parameter));
        _2245[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4092))) + int2(-1, 0), int2(0, 0), _4092 - int2(1, 1)), 0)).x;
        uint _4117_dummy_parameter;
        int2 _4117 = int2(spvTextureSize(r_depth_tp1, uint(0), _4117_dummy_parameter));
        _2245[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4117))) + int2(-1, 1), int2(0, 0), _4117 - int2(1, 1)), 0)).x;
        uint _4142_dummy_parameter;
        int2 _4142 = int2(spvTextureSize(r_depth_tp1, uint(0), _4142_dummy_parameter));
        _2245[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4142))) + int2(1, 1), int2(0, 0), _4142 - int2(1, 1)), 0)).x;
        uint _4167_dummy_parameter;
        int2 _4167 = int2(spvTextureSize(r_depth_tp1, uint(0), _4167_dummy_parameter));
        _2245[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4167))) + int2(-1, -1), int2(0, 0), _4167 - int2(1, 1)), 0)).x;
        uint _4192_dummy_parameter;
        int2 _4192 = int2(spvTextureSize(r_depth_tp1, uint(0), _4192_dummy_parameter));
        _2245[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4192))) + int2(1, -1), int2(0, 0), _4192 - int2(1, 1)), 0)).x;
        int _6007;
        _6007 = 0;
        float _6149;
        int _6150;
        int _6006 = 1;
        float _6125 = _2245[0];
        for (; _6006 < 9; _6125 = _6149, _6007 = _6150, _6006++)
        {
            bool _2631 = _2245[_6006] > _6125;
            _6149 = _2631 ? _2245[_6006] : _6125;
            _6150 = _2631 ? _6006 : _6007;
        }
        uint _4217_dummy_parameter;
        int2 _4217 = int2(spvTextureSize(r_motion_tp1, uint(0), _4217_dummy_parameter));
        float2 _4235 = r_motion_tp1.Load(int3(clamp(int2(floor(_2417 * float2(_4217))) + _1687[_6007], int2(0, 0), _4217 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _6008;
        do
        {
            if (_3282)
            {
                _6008 = _4235;
                break;
            }
            float2 _4259 = _2417 + _4235;
            float _4295 = ((2.0f * _4259.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4344 = clamp((((_5908 + (((float2(atan(_4295) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4259.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4295 * _4295))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5908) * _2441)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4347 = tan(_4344.x);
            _6008 = (((float2(_4347 / cbFI_DeviceToViewDepth.z, (tan(_4344.y) * sqrt(1.0f + (_4347 * _4347))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2417) / max(_2441, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _4381 = float2(cbFI_MvDepthLaneSize);
        rw_mv_holes_tp1[_2102 + int2(floor((_6008 * _4381) * _2441))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_2102 + int2(floor(_4235 * _4381))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4417_dummy_parameter;
        float4 _4424 = r_depth_tm1.Load(int3(int2(floor(_2417 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4417_dummy_parameter))))), 0));
        float _4425 = _4424.x;
        float4x4 _6013;
        do
        {
            float4x4 _4431;
            bool _6012;
            do
            {
                _4431 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                if (_3056)
                {
                    _6012 = false;
                    break;
                }
                uint _4465 = (64u + uint(_2409)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                if (rw_nfru_diagnostics.Load<uint>((_4465 + 32u) * 4 + 0) != 1u)
                {
                    _6012 = false;
                    break;
                }
                uint _6009;
                _6009 = 0u;
                for (; _6009 < 4u; _6009++)
                {
                    for (uint _6010 = 0u; _6010 < 4u; )
                    {
                        _4431[_6009][_6010] = asfloat(rw_nfru_diagnostics.Load<uint>((((_4465 + 16u) + (_6009 * 4u)) + _6010) * 4 + 0));
                        _6010++;
                        continue;
                    }
                }
                _6012 = true;
                break;
            } while(false);
            if (_6012)
            {
                _6013 = _4431;
                break;
            }
            _6013 = cbFI_MotionTM1ToTP1;
            break;
        } while(false);
        float4 _4557 = mul(float4(_3153, _3151.y, _4425, 1.0f), _6013);
        float _4559 = _4557.w;
        float2 _4573 = _3147 - (((_4557.xy / _4559.xx) + 1.0f.xx) * 0.5f);
        float2 _4575 = abs(_4573);
        bool2 _4581 = all(bool2(_4575.x < 9.9999997473787516355514526367188e-06f.xx.x, _4575.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4582 = float2(_4581.x ? 0.0f.xx.x : _4573.x, _4581.y ? 0.0f.xx.y : _4573.y);
        bool2 _4587 = any(isnan(_4582)).xx;
        float2 _4588 = float2(_4587.x ? 0.0f.xx.x : _4582.x, _4587.y ? 0.0f.xx.y : _4582.y);
        bool2 _4593 = any(isinf(_4588)).xx;
        float2 _4594 = float2(_4593.x ? 0.0f.xx.x : _4588.x, _4593.y ? 0.0f.xx.y : _4588.y);
        float2 _4600 = float2(-_4594.x, _4594.y);
        float2 _2672 = _3201 * _4381;
        float2 _2676 = _3255 * _4381;
        float2 _4655 = _2672 * 16.0146636962890625f;
        float2 _4665 = float2(int2(clamp(sign(_4655) * ceil(abs(_4655)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4681 = _2676 * 16.0146636962890625f;
        float2 _4691 = float2(int2(clamp(sign(_4681) * ceil(abs(_4681)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _6018;
        if (max(max(length(_4665), length(_4691)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _6018 = 0.0f;
        }
        else
        {
            _6018 = float(length(_4665 - _4691) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2681 = uint(_6018 > 0.0f);
        float _2693 = length(_2676);
        if (_2693 > 4.0f)
        {
            if (_3265)
            {
                uint _4708;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4708);
            }
        }
        bool _2705 = ((cbFI_pad0 & 2048u) != 0u) && (_2681 != 0u);
        bool _2717;
        if (_2705)
        {
            _2717 = length(_2672 - _2676) < (0.07999999821186065673828125f * max(length(_2672), _2693));
        }
        else
        {
            _2717 = _2705;
        }
        bool _2723 = (_3054 & 2048u) != 0u;
        bool _2731;
        if (_2723)
        {
            _2731 = length(_2672 - _2676) > 2.0f;
        }
        else
        {
            _2731 = _2723;
        }
        uint _6153 = ((_3054 & 4096u) != 0u) ? 1u : (_2731 ? 1u : (_2717 ? 0u : _2681));
        rw_dynamic_mask_tp1[_2102] = float4(clamp(float(_6153 + uint(_3162)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_6153 != 0u)
        {
            if (_3265)
            {
                uint _4727;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4727);
            }
        }
        if (_3162 > 0.0f)
        {
            if (_3265)
            {
                uint _4737;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4737);
            }
        }
        if ((_3054 & 512u) != 0u)
        {
            break;
        }
        bool _2765 = (_3054 & 1024u) != 0u;
        bool _2771;
        if (_2765)
        {
            _2771 = (1.0f - (log((_4425 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2771 = _2765;
        }
        if (_2771)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_2102, 0)).x) + uint(float(_4559 < 0.0f))) > 0u)
        {
            if (_3265)
            {
                uint _4757;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4757);
            }
            break;
        }
        float _4790 = 1.0f - (log((_4425 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _6039;
        if (_4790 == 1.0f)
        {
            _6039 = _4790 + ((float(_2404) * _2411) * 0.100000001490116119384765625f);
        }
        else
        {
            _6039 = _4790;
        }
        float _4780 = 1.10000002384185791015625f - _6039;
        float2 _6040;
        float2 _6041;
        do
        {
            if (_3282)
            {
                _6041 = _4600;
                _6040 = _4600;
                break;
            }
            float2 _4809 = _2417 + _4600;
            float _4845 = ((2.0f * _4809.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4812 = (float2(atan(_4845) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4809.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4845 * _4845))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5908;
            float2 _4894 = clamp((((_5908 + (_4812 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4897 = tan(_4894.x);
            _6041 = _4812;
            _6040 = (((float2(_4897 / cbFI_DeviceToViewDepth.z, (tan(_4894.y) * sqrt(1.0f + (_4897 * _4897))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2417) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _6043;
        int2 _6044;
        uint _6052;
        do
        {
            float2 _4944 = _6040 * _4381;
            float2 _4948 = _6041 * _4381;
            bool _4951 = any(isnan(_4944));
            bool _4958;
            if (!_4951)
            {
                _4958 = any(isinf(_4944));
            }
            else
            {
                _4958 = _4951;
            }
            bool _4965;
            if (!_4958)
            {
                _4965 = any(isnan(_4948));
            }
            else
            {
                _4965 = _4958;
            }
            bool _4972;
            if (!_4965)
            {
                _4972 = any(isinf(_4948));
            }
            else
            {
                _4972 = _4965;
            }
            bool _4978;
            if (!_4972)
            {
                _4978 = isnan(_4780);
            }
            else
            {
                _4978 = _4972;
            }
            bool _4984;
            if (!_4978)
            {
                _4984 = isinf(_4780);
            }
            else
            {
                _4984 = _4978;
            }
            if (_4984)
            {
                _6052 = 0u;
                _6044 = int2(0, 0);
                _6043 = false;
                break;
            }
            float2 _4989 = _4944 * cbFI_Timestep;
            bool _4992 = any(isnan(_4989));
            bool _4999;
            if (!_4992)
            {
                _4999 = any(isinf(_4989));
            }
            else
            {
                _4999 = _4992;
            }
            if (_4999)
            {
                _6052 = 0u;
                _6044 = int2(0, 0);
                _6043 = false;
                break;
            }
            float2 _5006 = _2413 + floor(_4989);
            bool _5009 = any(bool2(_5006.x < 0.0f.xx.x, _5006.y < 0.0f.xx.y));
            bool _5018;
            if (!_5009)
            {
                _5018 = any(bool2(_5006.x >= _4381.x, _5006.y >= _4381.y));
            }
            else
            {
                _5018 = _5009;
            }
            if (_5018)
            {
                _6052 = 0u;
                _6044 = int2(0, 0);
                _6043 = false;
                break;
            }
            float2 _5025 = _4948 * (-1.0f);
            float _5072 = _5025.x * 16.0146636962890625f;
            int _5080 = int(clamp(sign(_5072) * ceil(abs(_5072)), -16383.0f, 16383.0f));
            float _5084 = _5025.y * 16.0146636962890625f;
            int _5092 = int(clamp(sign(_5084) * ceil(abs(_5084)), -16383.0f, 16383.0f));
            int _5099 = abs(_5080);
            int _5101 = abs(_5092);
            int _5105 = clamp(firstbithigh(max(_5099, _5101)), 0, 15);
            int _5108 = max((_5105 - 6), 0);
            _6052 = (((((uint((int(round(_4780 * 1860.9090576171875f)) & 2047) << 20) | uint((_5105 & 15) << 16)) | uint(int(_5080 < 0) << 15)) | uint(int(_5092 < 0) << 14)) | uint((clamp(_5099 >> _5108, 0, 127) & 127) << 7)) | uint(clamp(_5101 >> _5108, 0, 127) & 127)) & 2147483647u;
            _6044 = int2(_5006);
            _6043 = true;
            break;
        } while(false);
        if (_6043)
        {
            uint _5190;
            InterlockedMax(rw_warped_motion_qdata_tp1[_6044], _6052, _5190);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _6060 = 0; _6060 < 3; _6060++)
                {
                    int2 _2820 = _6044 + _1474[_6060];
                    if (all(bool2(_2820.x < cbFI_MvDepthLaneSize.x, _2820.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _5195;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2820], _6052, _5195);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2842 = _2417 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2847 = _2417 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _5212_dummy_parameter;
                float4 _5219 = r_depth_tm1.Load(int3(int2(floor(_2417 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5212_dummy_parameter))))), 0));
                float _5220 = _5219.x;
                uint _5228_dummy_parameter;
                float4 _5235 = r_depth_tm1.Load(int3(int2(floor(_2842 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5228_dummy_parameter))))), 0));
                float _5236 = _5235.x;
                uint _5244_dummy_parameter;
                float4 _5251 = r_depth_tm1.Load(int3(int2(floor(_2847 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5244_dummy_parameter))))), 0));
                float _5252 = _5251.x;
                float4x4 _6065;
                do
                {
                    float4x4 _5258;
                    bool _6064;
                    do
                    {
                        _5258 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3056)
                        {
                            _6064 = false;
                            break;
                        }
                        uint _5292 = (64u + uint(_2409)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_5292 + 32u) * 4 + 0) != 1u)
                        {
                            _6064 = false;
                            break;
                        }
                        uint _6061;
                        _6061 = 0u;
                        for (; _6061 < 4u; _6061++)
                        {
                            for (uint _6062 = 0u; _6062 < 4u; )
                            {
                                _5258[_6061][_6062] = asfloat(rw_nfru_diagnostics.Load<uint>((((_5292 + 16u) + (_6061 * 4u)) + _6062) * 4 + 0));
                                _6062++;
                                continue;
                            }
                        }
                        _6064 = true;
                        break;
                    } while(false);
                    if (_6064)
                    {
                        _6065 = _5258;
                        break;
                    }
                    _6065 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float _5369 = _2842.x;
                float2 _5373 = float2(_5369, 1.0f - _2842.y);
                float4 _5384 = mul(float4((_5373 * 2.0f) - 1.0f.xx, _5236, 1.0f), _6065);
                float _5386 = _5384.w;
                float2 _5400 = _5373 - (((_5384.xy / _5386.xx) + 1.0f.xx) * 0.5f);
                float2 _5402 = abs(_5400);
                bool2 _5408 = all(bool2(_5402.x < 9.9999997473787516355514526367188e-06f.xx.x, _5402.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _5409 = float2(_5408.x ? 0.0f.xx.x : _5400.x, _5408.y ? 0.0f.xx.y : _5400.y);
                bool2 _5414 = any(isnan(_5409)).xx;
                float2 _5415 = float2(_5414.x ? 0.0f.xx.x : _5409.x, _5414.y ? 0.0f.xx.y : _5409.y);
                bool2 _5420 = any(isinf(_5415)).xx;
                float2 _5421 = float2(_5420.x ? 0.0f.xx.x : _5415.x, _5420.y ? 0.0f.xx.y : _5415.y);
                float4x4 _6070;
                do
                {
                    float4x4 _5432;
                    bool _6069;
                    do
                    {
                        _5432 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3056)
                        {
                            _6069 = false;
                            break;
                        }
                        uint _5466 = (64u + uint(_2409)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_5466 + 32u) * 4 + 0) != 1u)
                        {
                            _6069 = false;
                            break;
                        }
                        uint _6066;
                        _6066 = 0u;
                        for (; _6066 < 4u; _6066++)
                        {
                            for (uint _6067 = 0u; _6067 < 4u; )
                            {
                                _5432[_6066][_6067] = asfloat(rw_nfru_diagnostics.Load<uint>((((_5466 + 16u) + (_6066 * 4u)) + _6067) * 4 + 0));
                                _6067++;
                                continue;
                            }
                        }
                        _6069 = true;
                        break;
                    } while(false);
                    if (_6069)
                    {
                        _6070 = _5432;
                        break;
                    }
                    _6070 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float _5545 = _2847.y;
                float2 _5547 = float2(_2847.x, 1.0f - _5545);
                float4 _5558 = mul(float4((_5547 * 2.0f) - 1.0f.xx, _5252, 1.0f), _6070);
                float _5560 = _5558.w;
                float2 _5574 = _5547 - (((_5558.xy / _5560.xx) + 1.0f.xx) * 0.5f);
                float2 _5576 = abs(_5574);
                bool2 _5582 = all(bool2(_5576.x < 9.9999997473787516355514526367188e-06f.xx.x, _5576.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _5583 = float2(_5582.x ? 0.0f.xx.x : _5574.x, _5582.y ? 0.0f.xx.y : _5574.y);
                bool2 _5588 = any(isnan(_5583)).xx;
                float2 _5589 = float2(_5588.x ? 0.0f.xx.x : _5583.x, _5588.y ? 0.0f.xx.y : _5583.y);
                bool2 _5594 = any(isinf(_5589)).xx;
                float2 _5595 = float2(_5594.x ? 0.0f.xx.x : _5589.x, _5594.y ? 0.0f.xx.y : _5589.y);
                bool _2869 = (_5369 < 1.0f) && (float(_5386 < 0.0f) == 0.0f);
                bool _2875;
                if (_2869)
                {
                    _2875 = abs(_5220 - _5236) <= ((0.0500000007450580596923828125f * max(abs(_5220), abs(_5236))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2875 = _2869;
                }
                bool _2881 = (_5545 < 1.0f) && (float(_5560 < 0.0f) == 0.0f);
                bool _2887;
                if (_2881)
                {
                    _2887 = abs(_5220 - _5252) <= ((0.0500000007450580596923828125f * max(abs(_5220), abs(_5252))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2887 = _2881;
                }
                float2 _5643 = (_2417 + (_4600 * cbFI_Timestep)) * _4381;
                float2 _6071;
                if (_2875)
                {
                    _6071 = ((_2842 + (float2(-_5421.x, _5421.y) * cbFI_Timestep)) * _4381) - _5643;
                }
                else
                {
                    _6071 = float2(1.0f, 0.0f);
                }
                float2 _6072;
                if (_2887)
                {
                    _6072 = ((_2847 + (float2(-_5595.x, _5595.y) * cbFI_Timestep)) * _4381) - _5643;
                }
                else
                {
                    _6072 = float2(0.0f, 1.0f);
                }
                bool _5697 = any(isnan(_6071));
                bool _5704;
                if (!_5697)
                {
                    _5704 = any(isinf(_6071));
                }
                else
                {
                    _5704 = _5697;
                }
                bool2 _6154 = _5704.xx;
                float2 _6155 = float2(_6154.x ? float2(1.0f, 0.0f).x : _6071.x, _6154.y ? float2(1.0f, 0.0f).y : _6071.y);
                bool _5709 = any(isnan(_6072));
                bool _5716;
                if (!_5709)
                {
                    _5716 = any(isinf(_6072));
                }
                else
                {
                    _5716 = _5709;
                }
                bool2 _6156 = _5716.xx;
                float2 _6157 = float2(_6156.x ? float2(0.0f, 1.0f).x : _6072.x, _6156.y ? float2(0.0f, 1.0f).y : _6072.y);
                int2 _5732 = int2(clamp(floor(min(0.0f.xx, _6155) + min(0.0f.xx, _6157)), (-3.0f).xx, 0.0f.xx));
                int2 _5738 = int2(clamp(ceil(max(0.0f.xx, _6155) + max(0.0f.xx, _6157)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5746 = _5732.y;
                for (int _6118 = _5746; _6118 <= _5738.y; _6118++)
                {
                    int _5755 = _5732.x;
                    for (int _6119 = _5755; _6119 <= _5738.x; _6119++)
                    {
                        if ((_6119 == 0) && (_6118 == 0))
                        {
                            continue;
                        }
                        int2 _5774 = _6044 + int2(_6119, _6118);
                        bool _5777 = all(bool2(_5774.x >= int2(0, 0).x, _5774.y >= int2(0, 0).y));
                        bool _5784;
                        if (_5777)
                        {
                            _5784 = all(bool2(_5774.x < cbFI_MvDepthLaneSize.x, _5774.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5784 = _5777;
                        }
                        if (_5784)
                        {
                            uint _5802;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5774], _6052, _5802);
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
