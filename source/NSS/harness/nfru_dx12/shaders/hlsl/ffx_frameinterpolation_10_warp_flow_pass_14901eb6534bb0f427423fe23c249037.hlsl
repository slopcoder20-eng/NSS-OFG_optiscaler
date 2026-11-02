static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static int2 _5413;
static uint _5422;

static const int2 _1362[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1576[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
    int2 _1992 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1992.x >= cbFI_MvDepthLaneSize.x, _1992.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2280 = _1992.x + (_1992.y * cbFI_MvDepthLaneSize.x);
        float _2287 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2289 = float2(_1992);
        float2 _2293 = (_2289 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2818 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5376;
        if (_2818)
        {
            float _2831 = ((2.0f * _2293.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5376 = float2(atan(_2831) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2293.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2831 * _2831))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5376 = _2293;
        }
        uint _2873_dummy_parameter;
        float4 _2880 = r_depth_tp1.Load(int3(int2(floor(_2293 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2873_dummy_parameter))))), 0));
        float _2881 = _2880.x;
        uint _2889_dummy_parameter;
        float4 _2896 = r_depth_tp1.Load(int3(int2(floor(_2293 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2889_dummy_parameter))))), 0));
        float _2897 = _2896.x;
        rw_depth_tm1_next[_1992] = float4(_2881, 0.0f, 0.0f, 0.0f).x;
        float2 _2921 = float2(_2293.x, 1.0f - _2293.y);
        float2 _2925 = (_2921 * 2.0f) - 1.0f.xx;
        float _2927 = _2925.x;
        float4 _2932 = mul(float4(_2927, _2925.y, _2881, 1.0f), cbFI_MotionTP1ToTM1);
        float _2934 = _2932.w;
        float _2936 = float(_2934 < 0.0f);
        float2 _2948 = _2921 - (((_2932.xy / _2934.xx) + 1.0f.xx) * 0.5f);
        float2 _2950 = abs(_2948);
        bool2 _2956 = all(bool2(_2950.x < 9.9999997473787516355514526367188e-06f.xx.x, _2950.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2957 = float2(_2956.x ? 0.0f.xx.x : _2948.x, _2956.y ? 0.0f.xx.y : _2948.y);
        bool2 _2962 = any(isnan(_2957)).xx;
        float2 _2963 = float2(_2962.x ? 0.0f.xx.x : _2957.x, _2962.y ? 0.0f.xx.y : _2957.y);
        bool2 _2968 = any(isinf(_2963)).xx;
        float2 _2969 = float2(_2968.x ? 0.0f.xx.x : _2963.x, _2968.y ? 0.0f.xx.y : _2963.y);
        float2 _2975 = float2(-_2969.x, _2969.y);
        float _3007 = 1.0f - (log(((_2881 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5377;
        if (_3007 == 1.0f)
        {
            _5377 = _3007 + ((float(_2280) * _2287) * 0.100000001490116119384765625f);
        }
        else
        {
            _5377 = _3007;
        }
        float _2997 = 1.10000002384185791015625f - _5377;
        uint _3014_dummy_parameter;
        float2 _3029 = r_motion_tp1.Load(int3(int2(floor(_2293 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3014_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _3039 = (cbFI_pad0 & 512u) != 0u;
        if (_3039)
        {
            uint _3043;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _3043);
        }
        bool _3056;
        float _2317 = 1.0f - cbFI_Timestep;
        float2 _5378;
        float2 _5379;
        do
        {
            _3056 = !_2818;
            if (_3056)
            {
                _5379 = _3029;
                _5378 = _3029;
                break;
            }
            float2 _3063 = _2293 + _3029;
            float _3099 = ((2.0f * _3063.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3066 = (float2(atan(_3099) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3063.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3099 * _3099))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5376;
            float2 _3148 = clamp((((_5376 + (_3066 * _2317)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3151 = tan(_3148.x);
            _5379 = _3066;
            _5378 = (((float2(_3151 / cbFI_DeviceToViewDepth.z, (tan(_3148.y) * sqrt(1.0f + (_3151 * _3151))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2293) / max(_2317, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5380;
        if ((cbFI_NfruT2Flags & 262144u) != 0u)
        {
            float2 _2330 = float2(cbFI_MvDepthLaneSize);
            float _2332 = length(_2975 * _2330);
            bool _2342 = (_2936 == 0.0f) && (_2332 > 8.0f);
            bool _2349;
            if (_2342)
            {
                _2349 = length(_3029 * _2330) < (0.20000000298023223876953125f * _2332);
            }
            else
            {
                _2349 = _2342;
            }
            _5380 = _2349;
        }
        else
        {
            _5380 = false;
        }
        bool _2352 = !_5380;
        bool _2365;
        int2 _5407;
        uint _5416;
        if (_2352)
        {
            bool _5389;
            int2 _5390;
            uint _5398;
            do
            {
                float2 _3197 = float2(cbFI_MvDepthLaneSize);
                float2 _3198 = _5378 * _3197;
                float2 _3202 = _5379 * _3197;
                bool _3205 = any(isnan(_3198));
                bool _3212;
                if (!_3205)
                {
                    _3212 = any(isinf(_3198));
                }
                else
                {
                    _3212 = _3205;
                }
                bool _3219;
                if (!_3212)
                {
                    _3219 = any(isnan(_3202));
                }
                else
                {
                    _3219 = _3212;
                }
                bool _3226;
                if (!_3219)
                {
                    _3226 = any(isinf(_3202));
                }
                else
                {
                    _3226 = _3219;
                }
                bool _3232;
                if (!_3226)
                {
                    _3232 = isnan(_2997);
                }
                else
                {
                    _3232 = _3226;
                }
                bool _3238;
                if (!_3232)
                {
                    _3238 = isinf(_2997);
                }
                else
                {
                    _3238 = _3232;
                }
                if (_3238)
                {
                    _5398 = 0u;
                    _5390 = int2(0, 0);
                    _5389 = false;
                    break;
                }
                float2 _3243 = _3198 * _2317;
                bool _3246 = any(isnan(_3243));
                bool _3253;
                if (!_3246)
                {
                    _3253 = any(isinf(_3243));
                }
                else
                {
                    _3253 = _3246;
                }
                if (_3253)
                {
                    _5398 = 0u;
                    _5390 = int2(0, 0);
                    _5389 = false;
                    break;
                }
                float2 _3260 = _2289 + floor(_3243);
                bool _3263 = any(bool2(_3260.x < 0.0f.xx.x, _3260.y < 0.0f.xx.y));
                bool _3272;
                if (!_3263)
                {
                    _3272 = any(bool2(_3260.x >= _3197.x, _3260.y >= _3197.y));
                }
                else
                {
                    _3272 = _3263;
                }
                if (_3272)
                {
                    _5398 = 0u;
                    _5390 = int2(0, 0);
                    _5389 = false;
                    break;
                }
                float2 _3279 = _3202 * 1.0f;
                float _3326 = _3279.x * 16.0146636962890625f;
                int _3334 = int(clamp(sign(_3326) * ceil(abs(_3326)), -16383.0f, 16383.0f));
                float _3338 = _3279.y * 16.0146636962890625f;
                int _3346 = int(clamp(sign(_3338) * ceil(abs(_3338)), -16383.0f, 16383.0f));
                int _3353 = abs(_3334);
                int _3355 = abs(_3346);
                int _3359 = clamp(firstbithigh(max(_3353, _3355)), 0, 15);
                int _3362 = max((_3359 - 6), 0);
                _5398 = (((((uint((int(round(_2997 * 1860.9090576171875f)) & 2047) << 20) | uint((_3359 & 15) << 16)) | uint(int(_3334 < 0) << 15)) | uint(int(_3346 < 0) << 14)) | uint((clamp(_3353 >> _3362, 0, 127) & 127) << 7)) | uint(clamp(_3355 >> _3362, 0, 127) & 127)) & 2147483647u;
                _5390 = int2(_3260);
                _5389 = true;
                break;
            } while(false);
            _5416 = _5398;
            _5407 = _5390;
            _2365 = _5389;
        }
        else
        {
            _5416 = _5422;
            _5407 = _5413;
            _2365 = _2352;
        }
        if (_2365)
        {
            if (_3039)
            {
                uint _3448;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3448);
            }
            uint _3454;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5407], _5416, _3454);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5424 = 0; _5424 < 3; _5424++)
                {
                    int2 _2385 = _5407 + _1362[_5424];
                    if (all(bool2(_2385.x < cbFI_MvDepthLaneSize.x, _2385.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3459;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2385], _5416, _3459);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2407 = _2293 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2412 = _2293 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2417 = _2407.x < 1.0f;
                bool _2424;
                if (_2417)
                {
                    uint _3480_dummy_parameter;
                    float4 _3487 = r_depth_tp1.Load(int3(int2(floor(_2407 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3480_dummy_parameter))))), 0));
                    float _3488 = _3487.x;
                    _2424 = abs(_2897 - _3488) <= ((0.0500000007450580596923828125f * max(abs(_2897), abs(_3488))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2424 = _2417;
                }
                bool _2427 = _2412.y < 1.0f;
                bool _2434;
                if (_2427)
                {
                    uint _3510_dummy_parameter;
                    float4 _3517 = r_depth_tp1.Load(int3(int2(floor(_2412 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3510_dummy_parameter))))), 0));
                    float _3518 = _3517.x;
                    _2434 = abs(_2897 - _3518) <= ((0.0500000007450580596923828125f * max(abs(_2897), abs(_3518))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2434 = _2427;
                }
                float2 _3542 = float2(cbFI_MvDepthLaneSize);
                float2 _3543 = (_2293 + (_3029 * _2317)) * _3542;
                uint _3550_dummy_parameter;
                uint _3587_dummy_parameter;
                float2 _5425;
                if (_2424)
                {
                    _5425 = ((_2407 + ((r_motion_tp1.Load(int3(int2(floor(_2407 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3550_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2317)) * _3542) - _3543;
                }
                else
                {
                    _5425 = float2(1.0f, 0.0f);
                }
                float2 _5426;
                if (_2434)
                {
                    _5426 = ((_2412 + ((r_motion_tp1.Load(int3(int2(floor(_2412 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3587_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2317)) * _3542) - _3543;
                }
                else
                {
                    _5426 = float2(0.0f, 1.0f);
                }
                bool _3643 = any(isnan(_5425));
                bool _3650;
                if (!_3643)
                {
                    _3650 = any(isinf(_5425));
                }
                else
                {
                    _3650 = _3643;
                }
                bool2 _5561 = _3650.xx;
                float2 _5562 = float2(_5561.x ? float2(1.0f, 0.0f).x : _5425.x, _5561.y ? float2(1.0f, 0.0f).y : _5425.y);
                bool _3655 = any(isnan(_5426));
                bool _3662;
                if (!_3655)
                {
                    _3662 = any(isinf(_5426));
                }
                else
                {
                    _3662 = _3655;
                }
                bool2 _5563 = _3662.xx;
                float2 _5564 = float2(_5563.x ? float2(0.0f, 1.0f).x : _5426.x, _5563.y ? float2(0.0f, 1.0f).y : _5426.y);
                int2 _3678 = int2(clamp(floor(min(0.0f.xx, _5562) + min(0.0f.xx, _5564)), (-3.0f).xx, 0.0f.xx));
                int2 _3684 = int2(clamp(ceil(max(0.0f.xx, _5562) + max(0.0f.xx, _5564)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3692 = _3678.y;
                for (int _5456 = _3692; _5456 <= _3684.y; _5456++)
                {
                    int _3701 = _3678.x;
                    for (int _5543 = _3701; _5543 <= _3684.x; _5543++)
                    {
                        if ((_5543 == 0) && (_5456 == 0))
                        {
                            continue;
                        }
                        int2 _3720 = _5407 + int2(_5543, _5456);
                        bool _3723 = all(bool2(_3720.x >= int2(0, 0).x, _3720.y >= int2(0, 0).y));
                        bool _3730;
                        if (_3723)
                        {
                            _3730 = all(bool2(_3720.x < cbFI_MvDepthLaneSize.x, _3720.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3730 = _3723;
                        }
                        if (_3730)
                        {
                            uint _3748;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3720], _5416, _3748);
                        }
                    }
                }
            }
        }
        else
        {
            if (_3039)
            {
                uint _3757;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3757);
            }
        }
        uint _3766_dummy_parameter;
        int2 _3766 = int2(spvTextureSize(r_depth_tp1, uint(0), _3766_dummy_parameter));
        float _2121[9];
        _2121[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3766))), int2(0, 0), _3766 - int2(1, 1)), 0)).x;
        uint _3791_dummy_parameter;
        int2 _3791 = int2(spvTextureSize(r_depth_tp1, uint(0), _3791_dummy_parameter));
        _2121[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3791))) + int2(1, 0), int2(0, 0), _3791 - int2(1, 1)), 0)).x;
        uint _3816_dummy_parameter;
        int2 _3816 = int2(spvTextureSize(r_depth_tp1, uint(0), _3816_dummy_parameter));
        _2121[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3816))) + int2(0, 1), int2(0, 0), _3816 - int2(1, 1)), 0)).x;
        uint _3841_dummy_parameter;
        int2 _3841 = int2(spvTextureSize(r_depth_tp1, uint(0), _3841_dummy_parameter));
        _2121[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3841))) + int2(0, -1), int2(0, 0), _3841 - int2(1, 1)), 0)).x;
        uint _3866_dummy_parameter;
        int2 _3866 = int2(spvTextureSize(r_depth_tp1, uint(0), _3866_dummy_parameter));
        _2121[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3866))) + int2(-1, 0), int2(0, 0), _3866 - int2(1, 1)), 0)).x;
        uint _3891_dummy_parameter;
        int2 _3891 = int2(spvTextureSize(r_depth_tp1, uint(0), _3891_dummy_parameter));
        _2121[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3891))) + int2(-1, 1), int2(0, 0), _3891 - int2(1, 1)), 0)).x;
        uint _3916_dummy_parameter;
        int2 _3916 = int2(spvTextureSize(r_depth_tp1, uint(0), _3916_dummy_parameter));
        _2121[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3916))) + int2(1, 1), int2(0, 0), _3916 - int2(1, 1)), 0)).x;
        uint _3941_dummy_parameter;
        int2 _3941 = int2(spvTextureSize(r_depth_tp1, uint(0), _3941_dummy_parameter));
        _2121[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3941))) + int2(-1, -1), int2(0, 0), _3941 - int2(1, 1)), 0)).x;
        uint _3966_dummy_parameter;
        int2 _3966 = int2(spvTextureSize(r_depth_tp1, uint(0), _3966_dummy_parameter));
        _2121[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3966))) + int2(1, -1), int2(0, 0), _3966 - int2(1, 1)), 0)).x;
        int _5458;
        _5458 = 0;
        float _5565;
        int _5566;
        int _5457 = 1;
        float _5541 = _2121[0];
        for (; _5457 < 9; _5541 = _5565, _5458 = _5566, _5457++)
        {
            bool _2507 = _2121[_5457] < _5541;
            _5565 = _2507 ? _2121[_5457] : _5541;
            _5566 = _2507 ? _5457 : _5458;
        }
        uint _3991_dummy_parameter;
        int2 _3991 = int2(spvTextureSize(r_motion_tp1, uint(0), _3991_dummy_parameter));
        float2 _4009 = r_motion_tp1.Load(int3(clamp(int2(floor(_2293 * float2(_3991))) + _1576[_5458], int2(0, 0), _3991 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5459;
        do
        {
            if (_3056)
            {
                _5459 = _4009;
                break;
            }
            float2 _4033 = _2293 + _4009;
            float _4069 = ((2.0f * _4033.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4118 = clamp((((_5376 + (((float2(atan(_4069) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4033.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4069 * _4069))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5376) * _2317)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4121 = tan(_4118.x);
            _5459 = (((float2(_4121 / cbFI_DeviceToViewDepth.z, (tan(_4118.y) * sqrt(1.0f + (_4121 * _4121))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2293) / max(_2317, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _4155 = float2(cbFI_MvDepthLaneSize);
        rw_mv_holes_tp1[_1992 + int2(floor((_5459 * _4155) * _2317))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1992 + int2(floor(_4009 * _4155))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4191_dummy_parameter;
        float4 _4198 = r_depth_tm1.Load(int3(int2(floor(_2293 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4191_dummy_parameter))))), 0));
        float _4199 = _4198.x;
        float4 _4229 = mul(float4(_2927, _2925.y, _4199, 1.0f), cbFI_MotionTM1ToTP1);
        float _4231 = _4229.w;
        float2 _4245 = _2921 - (((_4229.xy / _4231.xx) + 1.0f.xx) * 0.5f);
        float2 _4247 = abs(_4245);
        bool2 _4253 = all(bool2(_4247.x < 9.9999997473787516355514526367188e-06f.xx.x, _4247.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4254 = float2(_4253.x ? 0.0f.xx.x : _4245.x, _4253.y ? 0.0f.xx.y : _4245.y);
        bool2 _4259 = any(isnan(_4254)).xx;
        float2 _4260 = float2(_4259.x ? 0.0f.xx.x : _4254.x, _4259.y ? 0.0f.xx.y : _4254.y);
        bool2 _4265 = any(isinf(_4260)).xx;
        float2 _4266 = float2(_4265.x ? 0.0f.xx.x : _4260.x, _4265.y ? 0.0f.xx.y : _4260.y);
        float2 _4272 = float2(-_4266.x, _4266.y);
        float2 _2548 = _2975 * _4155;
        float2 _2552 = _3029 * _4155;
        float2 _4327 = _2548 * 16.0146636962890625f;
        float2 _4337 = float2(int2(clamp(sign(_4327) * ceil(abs(_4327)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4353 = _2552 * 16.0146636962890625f;
        float2 _4363 = float2(int2(clamp(sign(_4353) * ceil(abs(_4353)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5460;
        if (max(max(length(_4337), length(_4363)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5460 = 0.0f;
        }
        else
        {
            _5460 = float(length(_4337 - _4363) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2557 = uint(_5460 > 0.0f);
        float _2569 = length(_2552);
        if (_2569 > 4.0f)
        {
            if (_3039)
            {
                uint _4380;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4380);
            }
        }
        bool _2581 = ((cbFI_pad0 & 2048u) != 0u) && (_2557 != 0u);
        bool _2593;
        if (_2581)
        {
            _2593 = length(_2548 - _2552) < (0.07999999821186065673828125f * max(length(_2548), _2569));
        }
        else
        {
            _2593 = _2581;
        }
        bool _2599 = (cbFI_NfruT2Flags & 2048u) != 0u;
        bool _2607;
        if (_2599)
        {
            _2607 = length(_2548 - _2552) > 2.0f;
        }
        else
        {
            _2607 = _2599;
        }
        uint _5569 = ((cbFI_NfruT2Flags & 4096u) != 0u) ? 1u : (_2607 ? 1u : (_2593 ? 0u : _2557));
        rw_dynamic_mask_tp1[_1992] = float4(clamp(float(_5569 + uint(_2936)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5569 != 0u)
        {
            if (_3039)
            {
                uint _4399;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4399);
            }
        }
        if (_2936 > 0.0f)
        {
            if (_3039)
            {
                uint _4409;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4409);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2641 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2647;
        if (_2641)
        {
            _2647 = (1.0f - (log(((_4199 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2647 = _2641;
        }
        if (_2647)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1992, 0)).x) + uint(float(_4231 < 0.0f))) > 0u)
        {
            if (_3039)
            {
                uint _4429;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4429);
            }
            break;
        }
        float _4462 = 1.0f - (log(((_4199 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5481;
        if (_4462 == 1.0f)
        {
            _5481 = _4462 + ((float(_2280) * _2287) * 0.100000001490116119384765625f);
        }
        else
        {
            _5481 = _4462;
        }
        float _4452 = 1.10000002384185791015625f - _5481;
        float2 _5482;
        float2 _5483;
        do
        {
            if (_3056)
            {
                _5483 = _4272;
                _5482 = _4272;
                break;
            }
            float2 _4481 = _2293 + _4272;
            float _4517 = ((2.0f * _4481.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4484 = (float2(atan(_4517) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4481.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4517 * _4517))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5376;
            float2 _4566 = clamp((((_5376 + (_4484 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4569 = tan(_4566.x);
            _5483 = _4484;
            _5482 = (((float2(_4569 / cbFI_DeviceToViewDepth.z, (tan(_4566.y) * sqrt(1.0f + (_4569 * _4569))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2293) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5485;
        int2 _5486;
        uint _5494;
        do
        {
            float2 _4616 = _5482 * _4155;
            float2 _4620 = _5483 * _4155;
            bool _4623 = any(isnan(_4616));
            bool _4630;
            if (!_4623)
            {
                _4630 = any(isinf(_4616));
            }
            else
            {
                _4630 = _4623;
            }
            bool _4637;
            if (!_4630)
            {
                _4637 = any(isnan(_4620));
            }
            else
            {
                _4637 = _4630;
            }
            bool _4644;
            if (!_4637)
            {
                _4644 = any(isinf(_4620));
            }
            else
            {
                _4644 = _4637;
            }
            bool _4650;
            if (!_4644)
            {
                _4650 = isnan(_4452);
            }
            else
            {
                _4650 = _4644;
            }
            bool _4656;
            if (!_4650)
            {
                _4656 = isinf(_4452);
            }
            else
            {
                _4656 = _4650;
            }
            if (_4656)
            {
                _5494 = 0u;
                _5486 = int2(0, 0);
                _5485 = false;
                break;
            }
            float2 _4661 = _4616 * cbFI_Timestep;
            bool _4664 = any(isnan(_4661));
            bool _4671;
            if (!_4664)
            {
                _4671 = any(isinf(_4661));
            }
            else
            {
                _4671 = _4664;
            }
            if (_4671)
            {
                _5494 = 0u;
                _5486 = int2(0, 0);
                _5485 = false;
                break;
            }
            float2 _4678 = _2289 + floor(_4661);
            bool _4681 = any(bool2(_4678.x < 0.0f.xx.x, _4678.y < 0.0f.xx.y));
            bool _4690;
            if (!_4681)
            {
                _4690 = any(bool2(_4678.x >= _4155.x, _4678.y >= _4155.y));
            }
            else
            {
                _4690 = _4681;
            }
            if (_4690)
            {
                _5494 = 0u;
                _5486 = int2(0, 0);
                _5485 = false;
                break;
            }
            float2 _4697 = _4620 * (-1.0f);
            float _4744 = _4697.x * 16.0146636962890625f;
            int _4752 = int(clamp(sign(_4744) * ceil(abs(_4744)), -16383.0f, 16383.0f));
            float _4756 = _4697.y * 16.0146636962890625f;
            int _4764 = int(clamp(sign(_4756) * ceil(abs(_4756)), -16383.0f, 16383.0f));
            int _4771 = abs(_4752);
            int _4773 = abs(_4764);
            int _4777 = clamp(firstbithigh(max(_4771, _4773)), 0, 15);
            int _4780 = max((_4777 - 6), 0);
            _5494 = (((((uint((int(round(_4452 * 1860.9090576171875f)) & 2047) << 20) | uint((_4777 & 15) << 16)) | uint(int(_4752 < 0) << 15)) | uint(int(_4764 < 0) << 14)) | uint((clamp(_4771 >> _4780, 0, 127) & 127) << 7)) | uint(clamp(_4773 >> _4780, 0, 127) & 127)) & 2147483647u;
            _5486 = int2(_4678);
            _5485 = true;
            break;
        } while(false);
        if (_5485)
        {
            uint _4862;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5486], _5494, _4862);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5502 = 0; _5502 < 3; _5502++)
                {
                    int2 _2696 = _5486 + _1362[_5502];
                    if (all(bool2(_2696.x < cbFI_MvDepthLaneSize.x, _2696.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4867;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2696], _5494, _4867);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2718 = _2293 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2723 = _2293 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4884_dummy_parameter;
                float4 _4891 = r_depth_tm1.Load(int3(int2(floor(_2293 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4884_dummy_parameter))))), 0));
                float _4892 = _4891.x;
                uint _4900_dummy_parameter;
                float4 _4907 = r_depth_tm1.Load(int3(int2(floor(_2718 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4900_dummy_parameter))))), 0));
                float _4908 = _4907.x;
                uint _4916_dummy_parameter;
                float4 _4923 = r_depth_tm1.Load(int3(int2(floor(_2723 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4916_dummy_parameter))))), 0));
                float _4924 = _4923.x;
                float _4939 = _2718.x;
                float2 _4943 = float2(_4939, 1.0f - _2718.y);
                float4 _4954 = mul(float4((_4943 * 2.0f) - 1.0f.xx, _4908, 1.0f), cbFI_MotionTM1ToTP1);
                float _4956 = _4954.w;
                float2 _4970 = _4943 - (((_4954.xy / _4956.xx) + 1.0f.xx) * 0.5f);
                float2 _4972 = abs(_4970);
                bool2 _4978 = all(bool2(_4972.x < 9.9999997473787516355514526367188e-06f.xx.x, _4972.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4979 = float2(_4978.x ? 0.0f.xx.x : _4970.x, _4978.y ? 0.0f.xx.y : _4970.y);
                bool2 _4984 = any(isnan(_4979)).xx;
                float2 _4985 = float2(_4984.x ? 0.0f.xx.x : _4979.x, _4984.y ? 0.0f.xx.y : _4979.y);
                bool2 _4990 = any(isinf(_4985)).xx;
                float2 _4991 = float2(_4990.x ? 0.0f.xx.x : _4985.x, _4990.y ? 0.0f.xx.y : _4985.y);
                float _5013 = _2723.y;
                float2 _5015 = float2(_2723.x, 1.0f - _5013);
                float4 _5026 = mul(float4((_5015 * 2.0f) - 1.0f.xx, _4924, 1.0f), cbFI_MotionTM1ToTP1);
                float _5028 = _5026.w;
                float2 _5042 = _5015 - (((_5026.xy / _5028.xx) + 1.0f.xx) * 0.5f);
                float2 _5044 = abs(_5042);
                bool2 _5050 = all(bool2(_5044.x < 9.9999997473787516355514526367188e-06f.xx.x, _5044.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _5051 = float2(_5050.x ? 0.0f.xx.x : _5042.x, _5050.y ? 0.0f.xx.y : _5042.y);
                bool2 _5056 = any(isnan(_5051)).xx;
                float2 _5057 = float2(_5056.x ? 0.0f.xx.x : _5051.x, _5056.y ? 0.0f.xx.y : _5051.y);
                bool2 _5062 = any(isinf(_5057)).xx;
                float2 _5063 = float2(_5062.x ? 0.0f.xx.x : _5057.x, _5062.y ? 0.0f.xx.y : _5057.y);
                bool _2745 = (_4939 < 1.0f) && (float(_4956 < 0.0f) == 0.0f);
                bool _2751;
                if (_2745)
                {
                    _2751 = abs(_4892 - _4908) <= ((0.0500000007450580596923828125f * max(abs(_4892), abs(_4908))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2751 = _2745;
                }
                bool _2757 = (_5013 < 1.0f) && (float(_5028 < 0.0f) == 0.0f);
                bool _2763;
                if (_2757)
                {
                    _2763 = abs(_4892 - _4924) <= ((0.0500000007450580596923828125f * max(abs(_4892), abs(_4924))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2763 = _2757;
                }
                float2 _5111 = (_2293 + (_4272 * cbFI_Timestep)) * _4155;
                float2 _5503;
                if (_2751)
                {
                    _5503 = ((_2718 + (float2(-_4991.x, _4991.y) * cbFI_Timestep)) * _4155) - _5111;
                }
                else
                {
                    _5503 = float2(1.0f, 0.0f);
                }
                float2 _5504;
                if (_2763)
                {
                    _5504 = ((_2723 + (float2(-_5063.x, _5063.y) * cbFI_Timestep)) * _4155) - _5111;
                }
                else
                {
                    _5504 = float2(0.0f, 1.0f);
                }
                bool _5165 = any(isnan(_5503));
                bool _5172;
                if (!_5165)
                {
                    _5172 = any(isinf(_5503));
                }
                else
                {
                    _5172 = _5165;
                }
                bool2 _5570 = _5172.xx;
                float2 _5571 = float2(_5570.x ? float2(1.0f, 0.0f).x : _5503.x, _5570.y ? float2(1.0f, 0.0f).y : _5503.y);
                bool _5177 = any(isnan(_5504));
                bool _5184;
                if (!_5177)
                {
                    _5184 = any(isinf(_5504));
                }
                else
                {
                    _5184 = _5177;
                }
                bool2 _5572 = _5184.xx;
                float2 _5573 = float2(_5572.x ? float2(0.0f, 1.0f).x : _5504.x, _5572.y ? float2(0.0f, 1.0f).y : _5504.y);
                int2 _5200 = int2(clamp(floor(min(0.0f.xx, _5571) + min(0.0f.xx, _5573)), (-3.0f).xx, 0.0f.xx));
                int2 _5206 = int2(clamp(ceil(max(0.0f.xx, _5571) + max(0.0f.xx, _5573)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5214 = _5200.y;
                for (int _5534 = _5214; _5534 <= _5206.y; _5534++)
                {
                    int _5223 = _5200.x;
                    for (int _5535 = _5223; _5535 <= _5206.x; _5535++)
                    {
                        if ((_5535 == 0) && (_5534 == 0))
                        {
                            continue;
                        }
                        int2 _5242 = _5486 + int2(_5535, _5534);
                        bool _5245 = all(bool2(_5242.x >= int2(0, 0).x, _5242.y >= int2(0, 0).y));
                        bool _5252;
                        if (_5245)
                        {
                            _5252 = all(bool2(_5242.x < cbFI_MvDepthLaneSize.x, _5242.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5252 = _5245;
                        }
                        if (_5252)
                        {
                            uint _5270;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5242], _5494, _5270);
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
