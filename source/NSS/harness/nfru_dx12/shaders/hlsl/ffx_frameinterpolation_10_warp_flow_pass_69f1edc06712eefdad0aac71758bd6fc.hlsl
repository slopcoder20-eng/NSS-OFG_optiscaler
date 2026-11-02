static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1322[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1536[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
    int2 _1909 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1909.x >= cbFI_MvDepthLaneSize.x, _1909.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2193 = _1909.x + (_1909.y * cbFI_MvDepthLaneSize.x);
        float _2200 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2202 = float2(_1909);
        float2 _2206 = (_2202 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2660 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5208;
        if (_2660)
        {
            float _2673 = ((2.0f * _2206.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5208 = float2(atan(_2673) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2206.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2673 * _2673))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5208 = _2206;
        }
        uint _2715_dummy_parameter;
        float4 _2722 = r_depth_tp1.Load(int3(int2(floor(_2206 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2715_dummy_parameter))))), 0));
        float _2723 = _2722.x;
        uint _2731_dummy_parameter;
        float4 _2738 = r_depth_tp1.Load(int3(int2(floor(_2206 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2731_dummy_parameter))))), 0));
        float _2739 = _2738.x;
        rw_depth_tm1_next[_1909] = float4(_2723, 0.0f, 0.0f, 0.0f).x;
        float2 _2763 = float2(_2206.x, 1.0f - _2206.y);
        float2 _2767 = (_2763 * 2.0f) - 1.0f.xx;
        float _2769 = _2767.x;
        float4 _2774 = mul(float4(_2769, _2767.y, _2723, 1.0f), cbFI_MotionTP1ToTM1);
        float _2776 = _2774.w;
        float _2778 = float(_2776 < 0.0f);
        float2 _2790 = _2763 - (((_2774.xy / _2776.xx) + 1.0f.xx) * 0.5f);
        float2 _2792 = abs(_2790);
        bool2 _2798 = all(bool2(_2792.x < 9.9999997473787516355514526367188e-06f.xx.x, _2792.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2799 = float2(_2798.x ? 0.0f.xx.x : _2790.x, _2798.y ? 0.0f.xx.y : _2790.y);
        bool2 _2804 = any(isnan(_2799)).xx;
        float2 _2805 = float2(_2804.x ? 0.0f.xx.x : _2799.x, _2804.y ? 0.0f.xx.y : _2799.y);
        bool2 _2810 = any(isinf(_2805)).xx;
        float2 _2811 = float2(_2810.x ? 0.0f.xx.x : _2805.x, _2810.y ? 0.0f.xx.y : _2805.y);
        float _2849 = 1.0f - (log(((_2723 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5209;
        if (_2849 == 1.0f)
        {
            _5209 = _2849 + ((float(_2193) * _2200) * 0.100000001490116119384765625f);
        }
        else
        {
            _5209 = _2849;
        }
        float _2839 = 1.10000002384185791015625f - _5209;
        uint _2856_dummy_parameter;
        float2 _2871 = r_motion_tp1.Load(int3(int2(floor(_2206 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2856_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2881 = (cbFI_pad0 & 512u) != 0u;
        if (_2881)
        {
            uint _2885;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2885);
        }
        bool _2898;
        float _2230 = 1.0f - cbFI_Timestep;
        float2 _5210;
        float2 _5211;
        do
        {
            _2898 = !_2660;
            if (_2898)
            {
                _5211 = _2871;
                _5210 = _2871;
                break;
            }
            float2 _2905 = _2206 + _2871;
            float _2941 = ((2.0f * _2905.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2908 = (float2(atan(_2941) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2905.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2941 * _2941))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5208;
            float2 _2990 = clamp((((_5208 + (_2908 * _2230)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2993 = tan(_2990.x);
            _5211 = _2908;
            _5210 = (((float2(_2993 / cbFI_DeviceToViewDepth.z, (tan(_2990.y) * sqrt(1.0f + (_2993 * _2993))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2206) / max(_2230, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3039;
        bool _5214;
        int2 _5215;
        uint _5223;
        do
        {
            _3039 = float2(cbFI_MvDepthLaneSize);
            float2 _3040 = _5210 * _3039;
            float2 _3044 = _5211 * _3039;
            bool _3047 = any(isnan(_3040));
            bool _3054;
            if (!_3047)
            {
                _3054 = any(isinf(_3040));
            }
            else
            {
                _3054 = _3047;
            }
            bool _3061;
            if (!_3054)
            {
                _3061 = any(isnan(_3044));
            }
            else
            {
                _3061 = _3054;
            }
            bool _3068;
            if (!_3061)
            {
                _3068 = any(isinf(_3044));
            }
            else
            {
                _3068 = _3061;
            }
            bool _3074;
            if (!_3068)
            {
                _3074 = isnan(_2839);
            }
            else
            {
                _3074 = _3068;
            }
            bool _3080;
            if (!_3074)
            {
                _3080 = isinf(_2839);
            }
            else
            {
                _3080 = _3074;
            }
            if (_3080)
            {
                _5223 = 0u;
                _5215 = int2(0, 0);
                _5214 = false;
                break;
            }
            float2 _3085 = _3040 * _2230;
            bool _3088 = any(isnan(_3085));
            bool _3095;
            if (!_3088)
            {
                _3095 = any(isinf(_3085));
            }
            else
            {
                _3095 = _3088;
            }
            if (_3095)
            {
                _5223 = 0u;
                _5215 = int2(0, 0);
                _5214 = false;
                break;
            }
            float2 _3102 = _2202 + floor(_3085);
            bool _3105 = any(bool2(_3102.x < 0.0f.xx.x, _3102.y < 0.0f.xx.y));
            bool _3114;
            if (!_3105)
            {
                _3114 = any(bool2(_3102.x >= _3039.x, _3102.y >= _3039.y));
            }
            else
            {
                _3114 = _3105;
            }
            if (_3114)
            {
                _5223 = 0u;
                _5215 = int2(0, 0);
                _5214 = false;
                break;
            }
            float2 _3121 = _3044 * 1.0f;
            float _3168 = _3121.x * 16.0146636962890625f;
            int _3176 = int(clamp(sign(_3168) * ceil(abs(_3168)), -16383.0f, 16383.0f));
            float _3180 = _3121.y * 16.0146636962890625f;
            int _3188 = int(clamp(sign(_3180) * ceil(abs(_3180)), -16383.0f, 16383.0f));
            int _3195 = abs(_3176);
            int _3197 = abs(_3188);
            int _3201 = clamp(firstbithigh(max(_3195, _3197)), 0, 15);
            int _3204 = max((_3201 - 6), 0);
            _5223 = (((((uint((int(round(_2839 * 1860.9090576171875f)) & 2047) << 20) | uint((_3201 & 15) << 16)) | uint(int(_3176 < 0) << 15)) | uint(int(_3188 < 0) << 14)) | uint((clamp(_3195 >> _3204, 0, 127) & 127) << 7)) | uint(clamp(_3197 >> _3204, 0, 127) & 127)) & 2147483647u;
            _5215 = int2(_3102);
            _5214 = true;
            break;
        } while(false);
        if (_5214)
        {
            if (_2881)
            {
                uint _3290;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3290);
            }
            uint _3296;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5215], _5223, _3296);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5233 = 0; _5233 < 3; _5233++)
                {
                    int2 _2265 = _5215 + _1322[_5233];
                    if (all(bool2(_2265.x < cbFI_MvDepthLaneSize.x, _2265.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3301;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2265], _5223, _3301);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2287 = _2206 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2292 = _2206 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2297 = _2287.x < 1.0f;
                bool _2304;
                if (_2297)
                {
                    uint _3322_dummy_parameter;
                    float4 _3329 = r_depth_tp1.Load(int3(int2(floor(_2287 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3322_dummy_parameter))))), 0));
                    float _3330 = _3329.x;
                    _2304 = abs(_2739 - _3330) <= ((0.0500000007450580596923828125f * max(abs(_2739), abs(_3330))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2304 = _2297;
                }
                bool _2307 = _2292.y < 1.0f;
                bool _2314;
                if (_2307)
                {
                    uint _3352_dummy_parameter;
                    float4 _3359 = r_depth_tp1.Load(int3(int2(floor(_2292 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3352_dummy_parameter))))), 0));
                    float _3360 = _3359.x;
                    _2314 = abs(_2739 - _3360) <= ((0.0500000007450580596923828125f * max(abs(_2739), abs(_3360))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2314 = _2307;
                }
                float2 _3385 = (_2206 + (_2871 * _2230)) * _3039;
                uint _3392_dummy_parameter;
                uint _3429_dummy_parameter;
                float2 _5234;
                if (_2304)
                {
                    _5234 = ((_2287 + ((r_motion_tp1.Load(int3(int2(floor(_2287 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3392_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2230)) * _3039) - _3385;
                }
                else
                {
                    _5234 = float2(1.0f, 0.0f);
                }
                float2 _5235;
                if (_2314)
                {
                    _5235 = ((_2292 + ((r_motion_tp1.Load(int3(int2(floor(_2292 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3429_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2230)) * _3039) - _3385;
                }
                else
                {
                    _5235 = float2(0.0f, 1.0f);
                }
                bool _3485 = any(isnan(_5234));
                bool _3492;
                if (!_3485)
                {
                    _3492 = any(isinf(_5234));
                }
                else
                {
                    _3492 = _3485;
                }
                bool2 _5363 = _3492.xx;
                float2 _5364 = float2(_5363.x ? float2(1.0f, 0.0f).x : _5234.x, _5363.y ? float2(1.0f, 0.0f).y : _5234.y);
                bool _3497 = any(isnan(_5235));
                bool _3504;
                if (!_3497)
                {
                    _3504 = any(isinf(_5235));
                }
                else
                {
                    _3504 = _3497;
                }
                bool2 _5365 = _3504.xx;
                float2 _5366 = float2(_5365.x ? float2(0.0f, 1.0f).x : _5235.x, _5365.y ? float2(0.0f, 1.0f).y : _5235.y);
                int2 _3520 = int2(clamp(floor(min(0.0f.xx, _5364) + min(0.0f.xx, _5366)), (-3.0f).xx, 0.0f.xx));
                int2 _3526 = int2(clamp(ceil(max(0.0f.xx, _5364) + max(0.0f.xx, _5366)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3534 = _3520.y;
                for (int _5265 = _3534; _5265 <= _3526.y; _5265++)
                {
                    int _3543 = _3520.x;
                    for (int _5345 = _3543; _5345 <= _3526.x; _5345++)
                    {
                        if ((_5345 == 0) && (_5265 == 0))
                        {
                            continue;
                        }
                        int2 _3562 = _5215 + int2(_5345, _5265);
                        bool _3565 = all(bool2(_3562.x >= int2(0, 0).x, _3562.y >= int2(0, 0).y));
                        bool _3572;
                        if (_3565)
                        {
                            _3572 = all(bool2(_3562.x < cbFI_MvDepthLaneSize.x, _3562.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3572 = _3565;
                        }
                        if (_3572)
                        {
                            uint _3590;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3562], _5223, _3590);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2881)
            {
                uint _3599;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3599);
            }
        }
        uint _3608_dummy_parameter;
        int2 _3608 = int2(spvTextureSize(r_depth_tp1, uint(0), _3608_dummy_parameter));
        float _2035[9];
        _2035[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3608))), int2(0, 0), _3608 - int2(1, 1)), 0)).x;
        uint _3633_dummy_parameter;
        int2 _3633 = int2(spvTextureSize(r_depth_tp1, uint(0), _3633_dummy_parameter));
        _2035[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3633))) + int2(1, 0), int2(0, 0), _3633 - int2(1, 1)), 0)).x;
        uint _3658_dummy_parameter;
        int2 _3658 = int2(spvTextureSize(r_depth_tp1, uint(0), _3658_dummy_parameter));
        _2035[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3658))) + int2(0, 1), int2(0, 0), _3658 - int2(1, 1)), 0)).x;
        uint _3683_dummy_parameter;
        int2 _3683 = int2(spvTextureSize(r_depth_tp1, uint(0), _3683_dummy_parameter));
        _2035[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3683))) + int2(0, -1), int2(0, 0), _3683 - int2(1, 1)), 0)).x;
        uint _3708_dummy_parameter;
        int2 _3708 = int2(spvTextureSize(r_depth_tp1, uint(0), _3708_dummy_parameter));
        _2035[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3708))) + int2(-1, 0), int2(0, 0), _3708 - int2(1, 1)), 0)).x;
        uint _3733_dummy_parameter;
        int2 _3733 = int2(spvTextureSize(r_depth_tp1, uint(0), _3733_dummy_parameter));
        _2035[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3733))) + int2(-1, 1), int2(0, 0), _3733 - int2(1, 1)), 0)).x;
        uint _3758_dummy_parameter;
        int2 _3758 = int2(spvTextureSize(r_depth_tp1, uint(0), _3758_dummy_parameter));
        _2035[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3758))) + int2(1, 1), int2(0, 0), _3758 - int2(1, 1)), 0)).x;
        uint _3783_dummy_parameter;
        int2 _3783 = int2(spvTextureSize(r_depth_tp1, uint(0), _3783_dummy_parameter));
        _2035[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3783))) + int2(-1, -1), int2(0, 0), _3783 - int2(1, 1)), 0)).x;
        uint _3808_dummy_parameter;
        int2 _3808 = int2(spvTextureSize(r_depth_tp1, uint(0), _3808_dummy_parameter));
        _2035[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3808))) + int2(1, -1), int2(0, 0), _3808 - int2(1, 1)), 0)).x;
        int _5267;
        _5267 = 0;
        float _5367;
        int _5368;
        int _5266 = 1;
        float _5343 = _2035[0];
        for (; _5266 < 9; _5343 = _5367, _5267 = _5368, _5266++)
        {
            bool _2387 = _2035[_5266] < _5343;
            _5367 = _2387 ? _2035[_5266] : _5343;
            _5368 = _2387 ? _5266 : _5267;
        }
        uint _3833_dummy_parameter;
        int2 _3833 = int2(spvTextureSize(r_motion_tp1, uint(0), _3833_dummy_parameter));
        float2 _3851 = r_motion_tp1.Load(int3(clamp(int2(floor(_2206 * float2(_3833))) + _1536[_5267], int2(0, 0), _3833 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5268;
        do
        {
            if (_2898)
            {
                _5268 = _3851;
                break;
            }
            float2 _3875 = _2206 + _3851;
            float _3911 = ((2.0f * _3875.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3960 = clamp((((_5208 + (((float2(atan(_3911) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3875.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3911 * _3911))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5208) * _2230)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3963 = tan(_3960.x);
            _5268 = (((float2(_3963 / cbFI_DeviceToViewDepth.z, (tan(_3960.y) * sqrt(1.0f + (_3963 * _3963))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2206) / max(_2230, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1909 + int2(floor((_5268 * _3039) * _2230))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1909 + int2(floor(_3851 * _3039))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4033_dummy_parameter;
        float4 _4040 = r_depth_tm1.Load(int3(int2(floor(_2206 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4033_dummy_parameter))))), 0));
        float _4041 = _4040.x;
        float4 _4071 = mul(float4(_2769, _2767.y, _4041, 1.0f), cbFI_MotionTM1ToTP1);
        float _4073 = _4071.w;
        float2 _4087 = _2763 - (((_4071.xy / _4073.xx) + 1.0f.xx) * 0.5f);
        float2 _4089 = abs(_4087);
        bool2 _4095 = all(bool2(_4089.x < 9.9999997473787516355514526367188e-06f.xx.x, _4089.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4096 = float2(_4095.x ? 0.0f.xx.x : _4087.x, _4095.y ? 0.0f.xx.y : _4087.y);
        bool2 _4101 = any(isnan(_4096)).xx;
        float2 _4102 = float2(_4101.x ? 0.0f.xx.x : _4096.x, _4101.y ? 0.0f.xx.y : _4096.y);
        bool2 _4107 = any(isinf(_4102)).xx;
        float2 _4108 = float2(_4107.x ? 0.0f.xx.x : _4102.x, _4107.y ? 0.0f.xx.y : _4102.y);
        float2 _4114 = float2(-_4108.x, _4108.y);
        float2 _2428 = float2(-_2811.x, _2811.y) * _3039;
        float2 _2432 = _2871 * _3039;
        float2 _4169 = _2428 * 16.0146636962890625f;
        float2 _4179 = float2(int2(clamp(sign(_4169) * ceil(abs(_4169)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4195 = _2432 * 16.0146636962890625f;
        float2 _4205 = float2(int2(clamp(sign(_4195) * ceil(abs(_4195)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5269;
        if (max(max(length(_4179), length(_4205)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5269 = 0.0f;
        }
        else
        {
            _5269 = float(length(_4179 - _4205) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2437 = uint(_5269 > 0.0f);
        float _2449 = length(_2432);
        if (_2449 > 4.0f)
        {
            if (_2881)
            {
                uint _4222;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4222);
            }
        }
        bool _2461 = ((cbFI_pad0 & 2048u) != 0u) && (_2437 != 0u);
        bool _2473;
        if (_2461)
        {
            _2473 = length(_2428 - _2432) < (0.07999999821186065673828125f * max(length(_2428), _2449));
        }
        else
        {
            _2473 = _2461;
        }
        uint _5369 = _2473 ? 0u : _2437;
        rw_dynamic_mask_tp1[_1909] = float4(clamp(float(_5369 + uint(_2778)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5369 != 0u)
        {
            if (_2881)
            {
                uint _4241;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4241);
            }
        }
        if (_2778 > 0.0f)
        {
            if (_2881)
            {
                uint _4251;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4251);
            }
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1909, 0)).x) + uint(float(_4073 < 0.0f))) > 0u)
        {
            if (_2881)
            {
                uint _4261;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4261);
            }
            break;
        }
        float _4294 = 1.0f - (log(((_4041 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5283;
        if (_4294 == 1.0f)
        {
            _5283 = _4294 + ((float(_2193) * _2200) * 0.100000001490116119384765625f);
        }
        else
        {
            _5283 = _4294;
        }
        float _4284 = 1.10000002384185791015625f - _5283;
        float2 _5284;
        float2 _5285;
        do
        {
            if (_2898)
            {
                _5285 = _4114;
                _5284 = _4114;
                break;
            }
            float2 _4313 = _2206 + _4114;
            float _4349 = ((2.0f * _4313.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4316 = (float2(atan(_4349) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4313.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4349 * _4349))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5208;
            float2 _4398 = clamp((((_5208 + (_4316 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4401 = tan(_4398.x);
            _5285 = _4316;
            _5284 = (((float2(_4401 / cbFI_DeviceToViewDepth.z, (tan(_4398.y) * sqrt(1.0f + (_4401 * _4401))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2206) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5287;
        int2 _5288;
        uint _5296;
        do
        {
            float2 _4448 = _5284 * _3039;
            float2 _4452 = _5285 * _3039;
            bool _4455 = any(isnan(_4448));
            bool _4462;
            if (!_4455)
            {
                _4462 = any(isinf(_4448));
            }
            else
            {
                _4462 = _4455;
            }
            bool _4469;
            if (!_4462)
            {
                _4469 = any(isnan(_4452));
            }
            else
            {
                _4469 = _4462;
            }
            bool _4476;
            if (!_4469)
            {
                _4476 = any(isinf(_4452));
            }
            else
            {
                _4476 = _4469;
            }
            bool _4482;
            if (!_4476)
            {
                _4482 = isnan(_4284);
            }
            else
            {
                _4482 = _4476;
            }
            bool _4488;
            if (!_4482)
            {
                _4488 = isinf(_4284);
            }
            else
            {
                _4488 = _4482;
            }
            if (_4488)
            {
                _5296 = 0u;
                _5288 = int2(0, 0);
                _5287 = false;
                break;
            }
            float2 _4493 = _4448 * cbFI_Timestep;
            bool _4496 = any(isnan(_4493));
            bool _4503;
            if (!_4496)
            {
                _4503 = any(isinf(_4493));
            }
            else
            {
                _4503 = _4496;
            }
            if (_4503)
            {
                _5296 = 0u;
                _5288 = int2(0, 0);
                _5287 = false;
                break;
            }
            float2 _4510 = _2202 + floor(_4493);
            bool _4513 = any(bool2(_4510.x < 0.0f.xx.x, _4510.y < 0.0f.xx.y));
            bool _4522;
            if (!_4513)
            {
                _4522 = any(bool2(_4510.x >= _3039.x, _4510.y >= _3039.y));
            }
            else
            {
                _4522 = _4513;
            }
            if (_4522)
            {
                _5296 = 0u;
                _5288 = int2(0, 0);
                _5287 = false;
                break;
            }
            float2 _4529 = _4452 * (-1.0f);
            float _4576 = _4529.x * 16.0146636962890625f;
            int _4584 = int(clamp(sign(_4576) * ceil(abs(_4576)), -16383.0f, 16383.0f));
            float _4588 = _4529.y * 16.0146636962890625f;
            int _4596 = int(clamp(sign(_4588) * ceil(abs(_4588)), -16383.0f, 16383.0f));
            int _4603 = abs(_4584);
            int _4605 = abs(_4596);
            int _4609 = clamp(firstbithigh(max(_4603, _4605)), 0, 15);
            int _4612 = max((_4609 - 6), 0);
            _5296 = (((((uint((int(round(_4284 * 1860.9090576171875f)) & 2047) << 20) | uint((_4609 & 15) << 16)) | uint(int(_4584 < 0) << 15)) | uint(int(_4596 < 0) << 14)) | uint((clamp(_4603 >> _4612, 0, 127) & 127) << 7)) | uint(clamp(_4605 >> _4612, 0, 127) & 127)) & 2147483647u;
            _5288 = int2(_4510);
            _5287 = true;
            break;
        } while(false);
        if (_5287)
        {
            uint _4694;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5288], _5296, _4694);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5304 = 0; _5304 < 3; _5304++)
                {
                    int2 _2538 = _5288 + _1322[_5304];
                    if (all(bool2(_2538.x < cbFI_MvDepthLaneSize.x, _2538.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4699;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2538], _5296, _4699);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2560 = _2206 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2565 = _2206 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4716_dummy_parameter;
                float4 _4723 = r_depth_tm1.Load(int3(int2(floor(_2206 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4716_dummy_parameter))))), 0));
                float _4724 = _4723.x;
                uint _4732_dummy_parameter;
                float4 _4739 = r_depth_tm1.Load(int3(int2(floor(_2560 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4732_dummy_parameter))))), 0));
                float _4740 = _4739.x;
                uint _4748_dummy_parameter;
                float4 _4755 = r_depth_tm1.Load(int3(int2(floor(_2565 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4748_dummy_parameter))))), 0));
                float _4756 = _4755.x;
                float _4771 = _2560.x;
                float2 _4775 = float2(_4771, 1.0f - _2560.y);
                float4 _4786 = mul(float4((_4775 * 2.0f) - 1.0f.xx, _4740, 1.0f), cbFI_MotionTM1ToTP1);
                float _4788 = _4786.w;
                float2 _4802 = _4775 - (((_4786.xy / _4788.xx) + 1.0f.xx) * 0.5f);
                float2 _4804 = abs(_4802);
                bool2 _4810 = all(bool2(_4804.x < 9.9999997473787516355514526367188e-06f.xx.x, _4804.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4811 = float2(_4810.x ? 0.0f.xx.x : _4802.x, _4810.y ? 0.0f.xx.y : _4802.y);
                bool2 _4816 = any(isnan(_4811)).xx;
                float2 _4817 = float2(_4816.x ? 0.0f.xx.x : _4811.x, _4816.y ? 0.0f.xx.y : _4811.y);
                bool2 _4822 = any(isinf(_4817)).xx;
                float2 _4823 = float2(_4822.x ? 0.0f.xx.x : _4817.x, _4822.y ? 0.0f.xx.y : _4817.y);
                float _4845 = _2565.y;
                float2 _4847 = float2(_2565.x, 1.0f - _4845);
                float4 _4858 = mul(float4((_4847 * 2.0f) - 1.0f.xx, _4756, 1.0f), cbFI_MotionTM1ToTP1);
                float _4860 = _4858.w;
                float2 _4874 = _4847 - (((_4858.xy / _4860.xx) + 1.0f.xx) * 0.5f);
                float2 _4876 = abs(_4874);
                bool2 _4882 = all(bool2(_4876.x < 9.9999997473787516355514526367188e-06f.xx.x, _4876.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4883 = float2(_4882.x ? 0.0f.xx.x : _4874.x, _4882.y ? 0.0f.xx.y : _4874.y);
                bool2 _4888 = any(isnan(_4883)).xx;
                float2 _4889 = float2(_4888.x ? 0.0f.xx.x : _4883.x, _4888.y ? 0.0f.xx.y : _4883.y);
                bool2 _4894 = any(isinf(_4889)).xx;
                float2 _4895 = float2(_4894.x ? 0.0f.xx.x : _4889.x, _4894.y ? 0.0f.xx.y : _4889.y);
                bool _2587 = (_4771 < 1.0f) && (float(_4788 < 0.0f) == 0.0f);
                bool _2593;
                if (_2587)
                {
                    _2593 = abs(_4724 - _4740) <= ((0.0500000007450580596923828125f * max(abs(_4724), abs(_4740))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2593 = _2587;
                }
                bool _2599 = (_4845 < 1.0f) && (float(_4860 < 0.0f) == 0.0f);
                bool _2605;
                if (_2599)
                {
                    _2605 = abs(_4724 - _4756) <= ((0.0500000007450580596923828125f * max(abs(_4724), abs(_4756))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2605 = _2599;
                }
                float2 _4943 = (_2206 + (_4114 * cbFI_Timestep)) * _3039;
                float2 _5305;
                if (_2593)
                {
                    _5305 = ((_2560 + (float2(-_4823.x, _4823.y) * cbFI_Timestep)) * _3039) - _4943;
                }
                else
                {
                    _5305 = float2(1.0f, 0.0f);
                }
                float2 _5306;
                if (_2605)
                {
                    _5306 = ((_2565 + (float2(-_4895.x, _4895.y) * cbFI_Timestep)) * _3039) - _4943;
                }
                else
                {
                    _5306 = float2(0.0f, 1.0f);
                }
                bool _4997 = any(isnan(_5305));
                bool _5004;
                if (!_4997)
                {
                    _5004 = any(isinf(_5305));
                }
                else
                {
                    _5004 = _4997;
                }
                bool2 _5370 = _5004.xx;
                float2 _5371 = float2(_5370.x ? float2(1.0f, 0.0f).x : _5305.x, _5370.y ? float2(1.0f, 0.0f).y : _5305.y);
                bool _5009 = any(isnan(_5306));
                bool _5016;
                if (!_5009)
                {
                    _5016 = any(isinf(_5306));
                }
                else
                {
                    _5016 = _5009;
                }
                bool2 _5372 = _5016.xx;
                float2 _5373 = float2(_5372.x ? float2(0.0f, 1.0f).x : _5306.x, _5372.y ? float2(0.0f, 1.0f).y : _5306.y);
                int2 _5032 = int2(clamp(floor(min(0.0f.xx, _5371) + min(0.0f.xx, _5373)), (-3.0f).xx, 0.0f.xx));
                int2 _5038 = int2(clamp(ceil(max(0.0f.xx, _5371) + max(0.0f.xx, _5373)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5046 = _5032.y;
                for (int _5336 = _5046; _5336 <= _5038.y; _5336++)
                {
                    int _5055 = _5032.x;
                    for (int _5337 = _5055; _5337 <= _5038.x; _5337++)
                    {
                        if ((_5337 == 0) && (_5336 == 0))
                        {
                            continue;
                        }
                        int2 _5074 = _5288 + int2(_5337, _5336);
                        bool _5077 = all(bool2(_5074.x >= int2(0, 0).x, _5074.y >= int2(0, 0).y));
                        bool _5084;
                        if (_5077)
                        {
                            _5084 = all(bool2(_5074.x < cbFI_MvDepthLaneSize.x, _5074.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5084 = _5077;
                        }
                        if (_5084)
                        {
                            uint _5102;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5074], _5296, _5102);
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
