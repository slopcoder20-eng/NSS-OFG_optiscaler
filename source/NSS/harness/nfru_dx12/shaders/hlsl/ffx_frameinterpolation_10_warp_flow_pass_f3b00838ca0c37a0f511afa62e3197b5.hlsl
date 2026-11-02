static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1305[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1519[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
    int2 _1916 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1916.x >= cbFI_MvDepthLaneSize.x, _1916.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2199 = _1916.x + (_1916.y * cbFI_MvDepthLaneSize.x);
        float _2206 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2208 = float2(_1916);
        float2 _2212 = (_2208 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2681 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5234;
        if (_2681)
        {
            float _2694 = ((2.0f * _2212.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5234 = float2(atan(_2694) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2212.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2694 * _2694))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5234 = _2212;
        }
        uint _2736_dummy_parameter;
        float4 _2743 = r_depth_tp1.Load(int3(int2(floor(_2212 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2736_dummy_parameter))))), 0));
        float _2744 = _2743.x;
        uint _2752_dummy_parameter;
        float4 _2759 = r_depth_tp1.Load(int3(int2(floor(_2212 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2752_dummy_parameter))))), 0));
        float _2760 = _2759.x;
        float2 _2779 = float2(_2212.x, 1.0f - _2212.y);
        float2 _2783 = (_2779 * 2.0f) - 1.0f.xx;
        float _2785 = _2783.x;
        float4 _2790 = mul(float4(_2785, _2783.y, _2744, 1.0f), cbFI_MotionTP1ToTM1);
        float _2792 = _2790.w;
        float _2794 = float(_2792 < 0.0f);
        float2 _2806 = _2779 - (((_2790.xy / _2792.xx) + 1.0f.xx) * 0.5f);
        float2 _2808 = abs(_2806);
        bool2 _2814 = all(bool2(_2808.x < 9.9999997473787516355514526367188e-06f.xx.x, _2808.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2815 = float2(_2814.x ? 0.0f.xx.x : _2806.x, _2814.y ? 0.0f.xx.y : _2806.y);
        bool2 _2820 = any(isnan(_2815)).xx;
        float2 _2821 = float2(_2820.x ? 0.0f.xx.x : _2815.x, _2820.y ? 0.0f.xx.y : _2815.y);
        bool2 _2826 = any(isinf(_2821)).xx;
        float2 _2827 = float2(_2826.x ? 0.0f.xx.x : _2821.x, _2826.y ? 0.0f.xx.y : _2821.y);
        float _2865 = 1.0f - (log((_2744 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5235;
        if (_2865 == 1.0f)
        {
            _5235 = _2865 + ((float(_2199) * _2206) * 0.100000001490116119384765625f);
        }
        else
        {
            _5235 = _2865;
        }
        float _2855 = 1.10000002384185791015625f - _5235;
        uint _2872_dummy_parameter;
        float2 _2887 = r_motion_tp1.Load(int3(int2(floor(_2212 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2872_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2897 = (cbFI_pad0 & 512u) != 0u;
        if (_2897)
        {
            uint _2901;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2901);
        }
        bool _2914;
        float _2233 = 1.0f - cbFI_Timestep;
        float2 _5236;
        float2 _5237;
        do
        {
            _2914 = !_2681;
            if (_2914)
            {
                _5237 = _2887;
                _5236 = _2887;
                break;
            }
            float2 _2921 = _2212 + _2887;
            float _2957 = ((2.0f * _2921.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2924 = (float2(atan(_2957) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2921.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2957 * _2957))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5234;
            float2 _3006 = clamp((((_5234 + (_2924 * _2233)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3009 = tan(_3006.x);
            _5237 = _2924;
            _5236 = (((float2(_3009 / cbFI_DeviceToViewDepth.z, (tan(_3006.y) * sqrt(1.0f + (_3009 * _3009))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2212) / max(_2233, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3055;
        bool _5240;
        int2 _5241;
        uint _5249;
        do
        {
            _3055 = float2(cbFI_MvDepthLaneSize);
            float2 _3056 = _5236 * _3055;
            float2 _3060 = _5237 * _3055;
            bool _3063 = any(isnan(_3056));
            bool _3070;
            if (!_3063)
            {
                _3070 = any(isinf(_3056));
            }
            else
            {
                _3070 = _3063;
            }
            bool _3077;
            if (!_3070)
            {
                _3077 = any(isnan(_3060));
            }
            else
            {
                _3077 = _3070;
            }
            bool _3084;
            if (!_3077)
            {
                _3084 = any(isinf(_3060));
            }
            else
            {
                _3084 = _3077;
            }
            bool _3090;
            if (!_3084)
            {
                _3090 = isnan(_2855);
            }
            else
            {
                _3090 = _3084;
            }
            bool _3096;
            if (!_3090)
            {
                _3096 = isinf(_2855);
            }
            else
            {
                _3096 = _3090;
            }
            if (_3096)
            {
                _5249 = 0u;
                _5241 = int2(0, 0);
                _5240 = false;
                break;
            }
            float2 _3101 = _3056 * _2233;
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
            if (_3111)
            {
                _5249 = 0u;
                _5241 = int2(0, 0);
                _5240 = false;
                break;
            }
            float2 _3118 = _2208 + floor(_3101);
            bool _3121 = any(bool2(_3118.x < 0.0f.xx.x, _3118.y < 0.0f.xx.y));
            bool _3130;
            if (!_3121)
            {
                _3130 = any(bool2(_3118.x >= _3055.x, _3118.y >= _3055.y));
            }
            else
            {
                _3130 = _3121;
            }
            if (_3130)
            {
                _5249 = 0u;
                _5241 = int2(0, 0);
                _5240 = false;
                break;
            }
            float2 _3137 = _3060 * 1.0f;
            float _3184 = _3137.x * 16.0146636962890625f;
            int _3192 = int(clamp(sign(_3184) * ceil(abs(_3184)), -16383.0f, 16383.0f));
            float _3196 = _3137.y * 16.0146636962890625f;
            int _3204 = int(clamp(sign(_3196) * ceil(abs(_3196)), -16383.0f, 16383.0f));
            int _3211 = abs(_3192);
            int _3213 = abs(_3204);
            int _3217 = clamp(firstbithigh(max(_3211, _3213)), 0, 15);
            int _3220 = max((_3217 - 6), 0);
            _5249 = (((((uint((int(round(_2855 * 1860.9090576171875f)) & 2047) << 20) | uint((_3217 & 15) << 16)) | uint(int(_3192 < 0) << 15)) | uint(int(_3204 < 0) << 14)) | uint((clamp(_3211 >> _3220, 0, 127) & 127) << 7)) | uint(clamp(_3213 >> _3220, 0, 127) & 127)) & 2147483647u;
            _5241 = int2(_3118);
            _5240 = true;
            break;
        } while(false);
        if (_5240)
        {
            if (_2897)
            {
                uint _3306;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3306);
            }
            uint _3312;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5241], _5249, _3312);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5259 = 0; _5259 < 3; _5259++)
                {
                    int2 _2268 = _5241 + _1305[_5259];
                    if (all(bool2(_2268.x < cbFI_MvDepthLaneSize.x, _2268.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3317;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2268], _5249, _3317);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2290 = _2212 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2295 = _2212 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2300 = _2290.x < 1.0f;
                bool _2307;
                if (_2300)
                {
                    uint _3338_dummy_parameter;
                    float4 _3345 = r_depth_tp1.Load(int3(int2(floor(_2290 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3338_dummy_parameter))))), 0));
                    float _3346 = _3345.x;
                    _2307 = abs(_2760 - _3346) <= ((0.0500000007450580596923828125f * max(abs(_2760), abs(_3346))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2307 = _2300;
                }
                bool _2310 = _2295.y < 1.0f;
                bool _2317;
                if (_2310)
                {
                    uint _3368_dummy_parameter;
                    float4 _3375 = r_depth_tp1.Load(int3(int2(floor(_2295 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3368_dummy_parameter))))), 0));
                    float _3376 = _3375.x;
                    _2317 = abs(_2760 - _3376) <= ((0.0500000007450580596923828125f * max(abs(_2760), abs(_3376))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2317 = _2310;
                }
                float2 _3401 = (_2212 + (_2887 * _2233)) * _3055;
                uint _3408_dummy_parameter;
                uint _3445_dummy_parameter;
                float2 _5260;
                if (_2307)
                {
                    _5260 = ((_2290 + ((r_motion_tp1.Load(int3(int2(floor(_2290 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3408_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2233)) * _3055) - _3401;
                }
                else
                {
                    _5260 = float2(1.0f, 0.0f);
                }
                float2 _5261;
                if (_2317)
                {
                    _5261 = ((_2295 + ((r_motion_tp1.Load(int3(int2(floor(_2295 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3445_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2233)) * _3055) - _3401;
                }
                else
                {
                    _5261 = float2(0.0f, 1.0f);
                }
                bool _3501 = any(isnan(_5260));
                bool _3508;
                if (!_3501)
                {
                    _3508 = any(isinf(_5260));
                }
                else
                {
                    _3508 = _3501;
                }
                bool2 _5390 = _3508.xx;
                float2 _5391 = float2(_5390.x ? float2(1.0f, 0.0f).x : _5260.x, _5390.y ? float2(1.0f, 0.0f).y : _5260.y);
                bool _3513 = any(isnan(_5261));
                bool _3520;
                if (!_3513)
                {
                    _3520 = any(isinf(_5261));
                }
                else
                {
                    _3520 = _3513;
                }
                bool2 _5392 = _3520.xx;
                float2 _5393 = float2(_5392.x ? float2(0.0f, 1.0f).x : _5261.x, _5392.y ? float2(0.0f, 1.0f).y : _5261.y);
                int2 _3536 = int2(clamp(floor(min(0.0f.xx, _5391) + min(0.0f.xx, _5393)), (-3.0f).xx, 0.0f.xx));
                int2 _3542 = int2(clamp(ceil(max(0.0f.xx, _5391) + max(0.0f.xx, _5393)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3550 = _3536.y;
                for (int _5291 = _3550; _5291 <= _3542.y; _5291++)
                {
                    int _3559 = _3536.x;
                    for (int _5372 = _3559; _5372 <= _3542.x; _5372++)
                    {
                        if ((_5372 == 0) && (_5291 == 0))
                        {
                            continue;
                        }
                        int2 _3578 = _5241 + int2(_5372, _5291);
                        bool _3581 = all(bool2(_3578.x >= int2(0, 0).x, _3578.y >= int2(0, 0).y));
                        bool _3588;
                        if (_3581)
                        {
                            _3588 = all(bool2(_3578.x < cbFI_MvDepthLaneSize.x, _3578.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3588 = _3581;
                        }
                        if (_3588)
                        {
                            uint _3606;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3578], _5249, _3606);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2897)
            {
                uint _3615;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3615);
            }
        }
        uint _3624_dummy_parameter;
        int2 _3624 = int2(spvTextureSize(r_depth_tp1, uint(0), _3624_dummy_parameter));
        float _2040[9];
        _2040[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3624))), int2(0, 0), _3624 - int2(1, 1)), 0)).x;
        uint _3649_dummy_parameter;
        int2 _3649 = int2(spvTextureSize(r_depth_tp1, uint(0), _3649_dummy_parameter));
        _2040[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3649))) + int2(1, 0), int2(0, 0), _3649 - int2(1, 1)), 0)).x;
        uint _3674_dummy_parameter;
        int2 _3674 = int2(spvTextureSize(r_depth_tp1, uint(0), _3674_dummy_parameter));
        _2040[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3674))) + int2(0, 1), int2(0, 0), _3674 - int2(1, 1)), 0)).x;
        uint _3699_dummy_parameter;
        int2 _3699 = int2(spvTextureSize(r_depth_tp1, uint(0), _3699_dummy_parameter));
        _2040[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3699))) + int2(0, -1), int2(0, 0), _3699 - int2(1, 1)), 0)).x;
        uint _3724_dummy_parameter;
        int2 _3724 = int2(spvTextureSize(r_depth_tp1, uint(0), _3724_dummy_parameter));
        _2040[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3724))) + int2(-1, 0), int2(0, 0), _3724 - int2(1, 1)), 0)).x;
        uint _3749_dummy_parameter;
        int2 _3749 = int2(spvTextureSize(r_depth_tp1, uint(0), _3749_dummy_parameter));
        _2040[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3749))) + int2(-1, 1), int2(0, 0), _3749 - int2(1, 1)), 0)).x;
        uint _3774_dummy_parameter;
        int2 _3774 = int2(spvTextureSize(r_depth_tp1, uint(0), _3774_dummy_parameter));
        _2040[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3774))) + int2(1, 1), int2(0, 0), _3774 - int2(1, 1)), 0)).x;
        uint _3799_dummy_parameter;
        int2 _3799 = int2(spvTextureSize(r_depth_tp1, uint(0), _3799_dummy_parameter));
        _2040[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3799))) + int2(-1, -1), int2(0, 0), _3799 - int2(1, 1)), 0)).x;
        uint _3824_dummy_parameter;
        int2 _3824 = int2(spvTextureSize(r_depth_tp1, uint(0), _3824_dummy_parameter));
        _2040[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3824))) + int2(1, -1), int2(0, 0), _3824 - int2(1, 1)), 0)).x;
        int _5293;
        _5293 = 0;
        float _5394;
        int _5395;
        int _5292 = 1;
        float _5370 = _2040[0];
        for (; _5292 < 9; _5370 = _5394, _5293 = _5395, _5292++)
        {
            bool _2390 = _2040[_5292] > _5370;
            _5394 = _2390 ? _2040[_5292] : _5370;
            _5395 = _2390 ? _5292 : _5293;
        }
        uint _3849_dummy_parameter;
        int2 _3849 = int2(spvTextureSize(r_motion_tp1, uint(0), _3849_dummy_parameter));
        float2 _3867 = r_motion_tp1.Load(int3(clamp(int2(floor(_2212 * float2(_3849))) + _1519[_5293], int2(0, 0), _3849 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5294;
        do
        {
            if (_2914)
            {
                _5294 = _3867;
                break;
            }
            float2 _3891 = _2212 + _3867;
            float _3927 = ((2.0f * _3891.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3976 = clamp((((_5234 + (((float2(atan(_3927) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3891.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3927 * _3927))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5234) * _2233)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3979 = tan(_3976.x);
            _5294 = (((float2(_3979 / cbFI_DeviceToViewDepth.z, (tan(_3976.y) * sqrt(1.0f + (_3979 * _3979))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2212) / max(_2233, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1916 + int2(floor((_5294 * _3055) * _2233))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1916 + int2(floor(_3867 * _3055))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4049_dummy_parameter;
        float4 _4056 = r_depth_tm1.Load(int3(int2(floor(_2212 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4049_dummy_parameter))))), 0));
        float _4057 = _4056.x;
        float4 _4087 = mul(float4(_2785, _2783.y, _4057, 1.0f), cbFI_MotionTM1ToTP1);
        float _4089 = _4087.w;
        float2 _4103 = _2779 - (((_4087.xy / _4089.xx) + 1.0f.xx) * 0.5f);
        float2 _4105 = abs(_4103);
        bool2 _4111 = all(bool2(_4105.x < 9.9999997473787516355514526367188e-06f.xx.x, _4105.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4112 = float2(_4111.x ? 0.0f.xx.x : _4103.x, _4111.y ? 0.0f.xx.y : _4103.y);
        bool2 _4117 = any(isnan(_4112)).xx;
        float2 _4118 = float2(_4117.x ? 0.0f.xx.x : _4112.x, _4117.y ? 0.0f.xx.y : _4112.y);
        bool2 _4123 = any(isinf(_4118)).xx;
        float2 _4124 = float2(_4123.x ? 0.0f.xx.x : _4118.x, _4123.y ? 0.0f.xx.y : _4118.y);
        float2 _4130 = float2(-_4124.x, _4124.y);
        float2 _2431 = float2(-_2827.x, _2827.y) * _3055;
        float2 _2435 = _2887 * _3055;
        float2 _4185 = _2431 * 16.0146636962890625f;
        float2 _4195 = float2(int2(clamp(sign(_4185) * ceil(abs(_4185)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4211 = _2435 * 16.0146636962890625f;
        float2 _4221 = float2(int2(clamp(sign(_4211) * ceil(abs(_4211)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5295;
        if (max(max(length(_4195), length(_4221)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5295 = 0.0f;
        }
        else
        {
            _5295 = float(length(_4195 - _4221) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2440 = uint(_5295 > 0.0f);
        float _2452 = length(_2435);
        if (_2452 > 4.0f)
        {
            if (_2897)
            {
                uint _4238;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4238);
            }
        }
        bool _2464 = ((cbFI_pad0 & 2048u) != 0u) && (_2440 != 0u);
        bool _2476;
        if (_2464)
        {
            _2476 = length(_2431 - _2435) < (0.07999999821186065673828125f * max(length(_2431), _2452));
        }
        else
        {
            _2476 = _2464;
        }
        uint _5396 = _2476 ? 0u : _2440;
        rw_dynamic_mask_tp1[_1916] = float4(clamp(float(_5396 + uint(_2794)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5396 != 0u)
        {
            if (_2897)
            {
                uint _4257;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4257);
            }
        }
        if (_2794 > 0.0f)
        {
            if (_2897)
            {
                uint _4267;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4267);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2504 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2510;
        if (_2504)
        {
            _2510 = (1.0f - (log((_4057 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2510 = _2504;
        }
        if (_2510)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1916, 0)).x) + uint(float(_4089 < 0.0f))) > 0u)
        {
            if (_2897)
            {
                uint _4287;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4287);
            }
            break;
        }
        float _4320 = 1.0f - (log((_4057 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5310;
        if (_4320 == 1.0f)
        {
            _5310 = _4320 + ((float(_2199) * _2206) * 0.100000001490116119384765625f);
        }
        else
        {
            _5310 = _4320;
        }
        float _4310 = 1.10000002384185791015625f - _5310;
        float2 _5311;
        float2 _5312;
        do
        {
            if (_2914)
            {
                _5312 = _4130;
                _5311 = _4130;
                break;
            }
            float2 _4339 = _2212 + _4130;
            float _4375 = ((2.0f * _4339.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4342 = (float2(atan(_4375) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4339.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4375 * _4375))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5234;
            float2 _4424 = clamp((((_5234 + (_4342 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4427 = tan(_4424.x);
            _5312 = _4342;
            _5311 = (((float2(_4427 / cbFI_DeviceToViewDepth.z, (tan(_4424.y) * sqrt(1.0f + (_4427 * _4427))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2212) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5314;
        int2 _5315;
        uint _5323;
        do
        {
            float2 _4474 = _5311 * _3055;
            float2 _4478 = _5312 * _3055;
            bool _4481 = any(isnan(_4474));
            bool _4488;
            if (!_4481)
            {
                _4488 = any(isinf(_4474));
            }
            else
            {
                _4488 = _4481;
            }
            bool _4495;
            if (!_4488)
            {
                _4495 = any(isnan(_4478));
            }
            else
            {
                _4495 = _4488;
            }
            bool _4502;
            if (!_4495)
            {
                _4502 = any(isinf(_4478));
            }
            else
            {
                _4502 = _4495;
            }
            bool _4508;
            if (!_4502)
            {
                _4508 = isnan(_4310);
            }
            else
            {
                _4508 = _4502;
            }
            bool _4514;
            if (!_4508)
            {
                _4514 = isinf(_4310);
            }
            else
            {
                _4514 = _4508;
            }
            if (_4514)
            {
                _5323 = 0u;
                _5315 = int2(0, 0);
                _5314 = false;
                break;
            }
            float2 _4519 = _4474 * cbFI_Timestep;
            bool _4522 = any(isnan(_4519));
            bool _4529;
            if (!_4522)
            {
                _4529 = any(isinf(_4519));
            }
            else
            {
                _4529 = _4522;
            }
            if (_4529)
            {
                _5323 = 0u;
                _5315 = int2(0, 0);
                _5314 = false;
                break;
            }
            float2 _4536 = _2208 + floor(_4519);
            bool _4539 = any(bool2(_4536.x < 0.0f.xx.x, _4536.y < 0.0f.xx.y));
            bool _4548;
            if (!_4539)
            {
                _4548 = any(bool2(_4536.x >= _3055.x, _4536.y >= _3055.y));
            }
            else
            {
                _4548 = _4539;
            }
            if (_4548)
            {
                _5323 = 0u;
                _5315 = int2(0, 0);
                _5314 = false;
                break;
            }
            float2 _4555 = _4478 * (-1.0f);
            float _4602 = _4555.x * 16.0146636962890625f;
            int _4610 = int(clamp(sign(_4602) * ceil(abs(_4602)), -16383.0f, 16383.0f));
            float _4614 = _4555.y * 16.0146636962890625f;
            int _4622 = int(clamp(sign(_4614) * ceil(abs(_4614)), -16383.0f, 16383.0f));
            int _4629 = abs(_4610);
            int _4631 = abs(_4622);
            int _4635 = clamp(firstbithigh(max(_4629, _4631)), 0, 15);
            int _4638 = max((_4635 - 6), 0);
            _5323 = (((((uint((int(round(_4310 * 1860.9090576171875f)) & 2047) << 20) | uint((_4635 & 15) << 16)) | uint(int(_4610 < 0) << 15)) | uint(int(_4622 < 0) << 14)) | uint((clamp(_4629 >> _4638, 0, 127) & 127) << 7)) | uint(clamp(_4631 >> _4638, 0, 127) & 127)) & 2147483647u;
            _5315 = int2(_4536);
            _5314 = true;
            break;
        } while(false);
        if (_5314)
        {
            uint _4720;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5315], _5323, _4720);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5331 = 0; _5331 < 3; _5331++)
                {
                    int2 _2559 = _5315 + _1305[_5331];
                    if (all(bool2(_2559.x < cbFI_MvDepthLaneSize.x, _2559.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4725;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2559], _5323, _4725);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2581 = _2212 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2586 = _2212 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4742_dummy_parameter;
                float4 _4749 = r_depth_tm1.Load(int3(int2(floor(_2212 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4742_dummy_parameter))))), 0));
                float _4750 = _4749.x;
                uint _4758_dummy_parameter;
                float4 _4765 = r_depth_tm1.Load(int3(int2(floor(_2581 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4758_dummy_parameter))))), 0));
                float _4766 = _4765.x;
                uint _4774_dummy_parameter;
                float4 _4781 = r_depth_tm1.Load(int3(int2(floor(_2586 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4774_dummy_parameter))))), 0));
                float _4782 = _4781.x;
                float _4797 = _2581.x;
                float2 _4801 = float2(_4797, 1.0f - _2581.y);
                float4 _4812 = mul(float4((_4801 * 2.0f) - 1.0f.xx, _4766, 1.0f), cbFI_MotionTM1ToTP1);
                float _4814 = _4812.w;
                float2 _4828 = _4801 - (((_4812.xy / _4814.xx) + 1.0f.xx) * 0.5f);
                float2 _4830 = abs(_4828);
                bool2 _4836 = all(bool2(_4830.x < 9.9999997473787516355514526367188e-06f.xx.x, _4830.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4837 = float2(_4836.x ? 0.0f.xx.x : _4828.x, _4836.y ? 0.0f.xx.y : _4828.y);
                bool2 _4842 = any(isnan(_4837)).xx;
                float2 _4843 = float2(_4842.x ? 0.0f.xx.x : _4837.x, _4842.y ? 0.0f.xx.y : _4837.y);
                bool2 _4848 = any(isinf(_4843)).xx;
                float2 _4849 = float2(_4848.x ? 0.0f.xx.x : _4843.x, _4848.y ? 0.0f.xx.y : _4843.y);
                float _4871 = _2586.y;
                float2 _4873 = float2(_2586.x, 1.0f - _4871);
                float4 _4884 = mul(float4((_4873 * 2.0f) - 1.0f.xx, _4782, 1.0f), cbFI_MotionTM1ToTP1);
                float _4886 = _4884.w;
                float2 _4900 = _4873 - (((_4884.xy / _4886.xx) + 1.0f.xx) * 0.5f);
                float2 _4902 = abs(_4900);
                bool2 _4908 = all(bool2(_4902.x < 9.9999997473787516355514526367188e-06f.xx.x, _4902.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4909 = float2(_4908.x ? 0.0f.xx.x : _4900.x, _4908.y ? 0.0f.xx.y : _4900.y);
                bool2 _4914 = any(isnan(_4909)).xx;
                float2 _4915 = float2(_4914.x ? 0.0f.xx.x : _4909.x, _4914.y ? 0.0f.xx.y : _4909.y);
                bool2 _4920 = any(isinf(_4915)).xx;
                float2 _4921 = float2(_4920.x ? 0.0f.xx.x : _4915.x, _4920.y ? 0.0f.xx.y : _4915.y);
                bool _2608 = (_4797 < 1.0f) && (float(_4814 < 0.0f) == 0.0f);
                bool _2614;
                if (_2608)
                {
                    _2614 = abs(_4750 - _4766) <= ((0.0500000007450580596923828125f * max(abs(_4750), abs(_4766))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2614 = _2608;
                }
                bool _2620 = (_4871 < 1.0f) && (float(_4886 < 0.0f) == 0.0f);
                bool _2626;
                if (_2620)
                {
                    _2626 = abs(_4750 - _4782) <= ((0.0500000007450580596923828125f * max(abs(_4750), abs(_4782))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2626 = _2620;
                }
                float2 _4969 = (_2212 + (_4130 * cbFI_Timestep)) * _3055;
                float2 _5332;
                if (_2614)
                {
                    _5332 = ((_2581 + (float2(-_4849.x, _4849.y) * cbFI_Timestep)) * _3055) - _4969;
                }
                else
                {
                    _5332 = float2(1.0f, 0.0f);
                }
                float2 _5333;
                if (_2626)
                {
                    _5333 = ((_2586 + (float2(-_4921.x, _4921.y) * cbFI_Timestep)) * _3055) - _4969;
                }
                else
                {
                    _5333 = float2(0.0f, 1.0f);
                }
                bool _5023 = any(isnan(_5332));
                bool _5030;
                if (!_5023)
                {
                    _5030 = any(isinf(_5332));
                }
                else
                {
                    _5030 = _5023;
                }
                bool2 _5397 = _5030.xx;
                float2 _5398 = float2(_5397.x ? float2(1.0f, 0.0f).x : _5332.x, _5397.y ? float2(1.0f, 0.0f).y : _5332.y);
                bool _5035 = any(isnan(_5333));
                bool _5042;
                if (!_5035)
                {
                    _5042 = any(isinf(_5333));
                }
                else
                {
                    _5042 = _5035;
                }
                bool2 _5399 = _5042.xx;
                float2 _5400 = float2(_5399.x ? float2(0.0f, 1.0f).x : _5333.x, _5399.y ? float2(0.0f, 1.0f).y : _5333.y);
                int2 _5058 = int2(clamp(floor(min(0.0f.xx, _5398) + min(0.0f.xx, _5400)), (-3.0f).xx, 0.0f.xx));
                int2 _5064 = int2(clamp(ceil(max(0.0f.xx, _5398) + max(0.0f.xx, _5400)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5072 = _5058.y;
                for (int _5363 = _5072; _5363 <= _5064.y; _5363++)
                {
                    int _5081 = _5058.x;
                    for (int _5364 = _5081; _5364 <= _5064.x; _5364++)
                    {
                        if ((_5364 == 0) && (_5363 == 0))
                        {
                            continue;
                        }
                        int2 _5100 = _5315 + int2(_5364, _5363);
                        bool _5103 = all(bool2(_5100.x >= int2(0, 0).x, _5100.y >= int2(0, 0).y));
                        bool _5110;
                        if (_5103)
                        {
                            _5110 = all(bool2(_5100.x < cbFI_MvDepthLaneSize.x, _5100.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5110 = _5103;
                        }
                        if (_5110)
                        {
                            uint _5128;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5100], _5323, _5128);
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
