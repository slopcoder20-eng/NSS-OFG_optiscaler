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
    int2 _1936 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1936.x >= cbFI_MvDepthLaneSize.x, _1936.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2219 = _1936.x + (_1936.y * cbFI_MvDepthLaneSize.x);
        float _2226 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2228 = float2(_1936);
        float2 _2232 = (_2228 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2721 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5274;
        if (_2721)
        {
            float _2734 = ((2.0f * _2232.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5274 = float2(atan(_2734) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2232.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2734 * _2734))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5274 = _2232;
        }
        uint _2776_dummy_parameter;
        float4 _2783 = r_depth_tp1.Load(int3(int2(floor(_2232 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2776_dummy_parameter))))), 0));
        float _2784 = _2783.x;
        uint _2792_dummy_parameter;
        float4 _2799 = r_depth_tp1.Load(int3(int2(floor(_2232 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2792_dummy_parameter))))), 0));
        float _2800 = _2799.x;
        float2 _2819 = float2(_2232.x, 1.0f - _2232.y);
        float2 _2823 = (_2819 * 2.0f) - 1.0f.xx;
        float _2825 = _2823.x;
        float4 _2830 = mul(float4(_2825, _2823.y, _2784, 1.0f), cbFI_MotionTP1ToTM1);
        float _2832 = _2830.w;
        float _2834 = float(_2832 < 0.0f);
        float2 _2846 = _2819 - (((_2830.xy / _2832.xx) + 1.0f.xx) * 0.5f);
        float2 _2848 = abs(_2846);
        bool2 _2854 = all(bool2(_2848.x < 9.9999997473787516355514526367188e-06f.xx.x, _2848.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2855 = float2(_2854.x ? 0.0f.xx.x : _2846.x, _2854.y ? 0.0f.xx.y : _2846.y);
        bool2 _2860 = any(isnan(_2855)).xx;
        float2 _2861 = float2(_2860.x ? 0.0f.xx.x : _2855.x, _2860.y ? 0.0f.xx.y : _2855.y);
        bool2 _2866 = any(isinf(_2861)).xx;
        float2 _2867 = float2(_2866.x ? 0.0f.xx.x : _2861.x, _2866.y ? 0.0f.xx.y : _2861.y);
        float _2905 = 1.0f - (log((_2784 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5275;
        if (_2905 == 1.0f)
        {
            _5275 = _2905 + ((float(_2219) * _2226) * 0.100000001490116119384765625f);
        }
        else
        {
            _5275 = _2905;
        }
        float _2895 = 1.10000002384185791015625f - _5275;
        uint _2912_dummy_parameter;
        float2 _2927 = r_motion_tp1.Load(int3(int2(floor(_2232 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2912_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2937 = (cbFI_pad0 & 512u) != 0u;
        if (_2937)
        {
            uint _2941;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2941);
        }
        bool _2954;
        float _2253 = 1.0f - cbFI_Timestep;
        float2 _5276;
        float2 _5277;
        do
        {
            _2954 = !_2721;
            if (_2954)
            {
                _5277 = _2927;
                _5276 = _2927;
                break;
            }
            float2 _2961 = _2232 + _2927;
            float _2997 = ((2.0f * _2961.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2964 = (float2(atan(_2997) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2961.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2997 * _2997))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5274;
            float2 _3046 = clamp((((_5274 + (_2964 * _2253)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3049 = tan(_3046.x);
            _5277 = _2964;
            _5276 = (((float2(_3049 / cbFI_DeviceToViewDepth.z, (tan(_3046.y) * sqrt(1.0f + (_3049 * _3049))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2232) / max(_2253, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3095;
        bool _5280;
        int2 _5281;
        uint _5289;
        do
        {
            _3095 = float2(cbFI_MvDepthLaneSize);
            float2 _3096 = _5276 * _3095;
            float2 _3100 = _5277 * _3095;
            bool _3103 = any(isnan(_3096));
            bool _3110;
            if (!_3103)
            {
                _3110 = any(isinf(_3096));
            }
            else
            {
                _3110 = _3103;
            }
            bool _3117;
            if (!_3110)
            {
                _3117 = any(isnan(_3100));
            }
            else
            {
                _3117 = _3110;
            }
            bool _3124;
            if (!_3117)
            {
                _3124 = any(isinf(_3100));
            }
            else
            {
                _3124 = _3117;
            }
            bool _3130;
            if (!_3124)
            {
                _3130 = isnan(_2895);
            }
            else
            {
                _3130 = _3124;
            }
            bool _3136;
            if (!_3130)
            {
                _3136 = isinf(_2895);
            }
            else
            {
                _3136 = _3130;
            }
            if (_3136)
            {
                _5289 = 0u;
                _5281 = int2(0, 0);
                _5280 = false;
                break;
            }
            float2 _3141 = _3096 * _2253;
            bool _3144 = any(isnan(_3141));
            bool _3151;
            if (!_3144)
            {
                _3151 = any(isinf(_3141));
            }
            else
            {
                _3151 = _3144;
            }
            if (_3151)
            {
                _5289 = 0u;
                _5281 = int2(0, 0);
                _5280 = false;
                break;
            }
            float2 _3158 = _2228 + floor(_3141);
            bool _3161 = any(bool2(_3158.x < 0.0f.xx.x, _3158.y < 0.0f.xx.y));
            bool _3170;
            if (!_3161)
            {
                _3170 = any(bool2(_3158.x >= _3095.x, _3158.y >= _3095.y));
            }
            else
            {
                _3170 = _3161;
            }
            if (_3170)
            {
                _5289 = 0u;
                _5281 = int2(0, 0);
                _5280 = false;
                break;
            }
            float2 _3177 = _3100 * 1.0f;
            float _3224 = _3177.x * 16.0146636962890625f;
            int _3232 = int(clamp(sign(_3224) * ceil(abs(_3224)), -16383.0f, 16383.0f));
            float _3236 = _3177.y * 16.0146636962890625f;
            int _3244 = int(clamp(sign(_3236) * ceil(abs(_3236)), -16383.0f, 16383.0f));
            int _3251 = abs(_3232);
            int _3253 = abs(_3244);
            int _3257 = clamp(firstbithigh(max(_3251, _3253)), 0, 15);
            int _3260 = max((_3257 - 6), 0);
            _5289 = (((((uint((int(round(_2895 * 1860.9090576171875f)) & 2047) << 20) | uint((_3257 & 15) << 16)) | uint(int(_3232 < 0) << 15)) | uint(int(_3244 < 0) << 14)) | uint((clamp(_3251 >> _3260, 0, 127) & 127) << 7)) | uint(clamp(_3253 >> _3260, 0, 127) & 127)) & 2147483647u;
            _5281 = int2(_3158);
            _5280 = true;
            break;
        } while(false);
        if (_5280)
        {
            if (_2937)
            {
                uint _3346;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3346);
            }
            uint _3352;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5281], _5289, _3352);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5299 = 0; _5299 < 3; _5299++)
                {
                    int2 _2288 = _5281 + _1305[_5299];
                    if (all(bool2(_2288.x < cbFI_MvDepthLaneSize.x, _2288.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3357;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2288], _5289, _3357);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2310 = _2232 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2315 = _2232 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2320 = _2310.x < 1.0f;
                bool _2327;
                if (_2320)
                {
                    uint _3378_dummy_parameter;
                    float4 _3385 = r_depth_tp1.Load(int3(int2(floor(_2310 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3378_dummy_parameter))))), 0));
                    float _3386 = _3385.x;
                    _2327 = abs(_2800 - _3386) <= ((0.0500000007450580596923828125f * max(abs(_2800), abs(_3386))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2327 = _2320;
                }
                bool _2330 = _2315.y < 1.0f;
                bool _2337;
                if (_2330)
                {
                    uint _3408_dummy_parameter;
                    float4 _3415 = r_depth_tp1.Load(int3(int2(floor(_2315 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3408_dummy_parameter))))), 0));
                    float _3416 = _3415.x;
                    _2337 = abs(_2800 - _3416) <= ((0.0500000007450580596923828125f * max(abs(_2800), abs(_3416))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2337 = _2330;
                }
                float2 _3441 = (_2232 + (_2927 * _2253)) * _3095;
                uint _3448_dummy_parameter;
                uint _3485_dummy_parameter;
                float2 _5300;
                if (_2327)
                {
                    _5300 = ((_2310 + ((r_motion_tp1.Load(int3(int2(floor(_2310 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3448_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2253)) * _3095) - _3441;
                }
                else
                {
                    _5300 = float2(1.0f, 0.0f);
                }
                float2 _5301;
                if (_2337)
                {
                    _5301 = ((_2315 + ((r_motion_tp1.Load(int3(int2(floor(_2315 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3485_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2253)) * _3095) - _3441;
                }
                else
                {
                    _5301 = float2(0.0f, 1.0f);
                }
                bool _3541 = any(isnan(_5300));
                bool _3548;
                if (!_3541)
                {
                    _3548 = any(isinf(_5300));
                }
                else
                {
                    _3548 = _3541;
                }
                bool2 _5436 = _3548.xx;
                float2 _5437 = float2(_5436.x ? float2(1.0f, 0.0f).x : _5300.x, _5436.y ? float2(1.0f, 0.0f).y : _5300.y);
                bool _3553 = any(isnan(_5301));
                bool _3560;
                if (!_3553)
                {
                    _3560 = any(isinf(_5301));
                }
                else
                {
                    _3560 = _3553;
                }
                bool2 _5438 = _3560.xx;
                float2 _5439 = float2(_5438.x ? float2(0.0f, 1.0f).x : _5301.x, _5438.y ? float2(0.0f, 1.0f).y : _5301.y);
                int2 _3576 = int2(clamp(floor(min(0.0f.xx, _5437) + min(0.0f.xx, _5439)), (-3.0f).xx, 0.0f.xx));
                int2 _3582 = int2(clamp(ceil(max(0.0f.xx, _5437) + max(0.0f.xx, _5439)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3590 = _3576.y;
                for (int _5331 = _3590; _5331 <= _3582.y; _5331++)
                {
                    int _3599 = _3576.x;
                    for (int _5418 = _3599; _5418 <= _3582.x; _5418++)
                    {
                        if ((_5418 == 0) && (_5331 == 0))
                        {
                            continue;
                        }
                        int2 _3618 = _5281 + int2(_5418, _5331);
                        bool _3621 = all(bool2(_3618.x >= int2(0, 0).x, _3618.y >= int2(0, 0).y));
                        bool _3628;
                        if (_3621)
                        {
                            _3628 = all(bool2(_3618.x < cbFI_MvDepthLaneSize.x, _3618.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3628 = _3621;
                        }
                        if (_3628)
                        {
                            uint _3646;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3618], _5289, _3646);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2937)
            {
                uint _3655;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3655);
            }
        }
        uint _3664_dummy_parameter;
        int2 _3664 = int2(spvTextureSize(r_depth_tp1, uint(0), _3664_dummy_parameter));
        float _2060[9];
        _2060[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3664))), int2(0, 0), _3664 - int2(1, 1)), 0)).x;
        uint _3689_dummy_parameter;
        int2 _3689 = int2(spvTextureSize(r_depth_tp1, uint(0), _3689_dummy_parameter));
        _2060[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3689))) + int2(1, 0), int2(0, 0), _3689 - int2(1, 1)), 0)).x;
        uint _3714_dummy_parameter;
        int2 _3714 = int2(spvTextureSize(r_depth_tp1, uint(0), _3714_dummy_parameter));
        _2060[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3714))) + int2(0, 1), int2(0, 0), _3714 - int2(1, 1)), 0)).x;
        uint _3739_dummy_parameter;
        int2 _3739 = int2(spvTextureSize(r_depth_tp1, uint(0), _3739_dummy_parameter));
        _2060[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3739))) + int2(0, -1), int2(0, 0), _3739 - int2(1, 1)), 0)).x;
        uint _3764_dummy_parameter;
        int2 _3764 = int2(spvTextureSize(r_depth_tp1, uint(0), _3764_dummy_parameter));
        _2060[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3764))) + int2(-1, 0), int2(0, 0), _3764 - int2(1, 1)), 0)).x;
        uint _3789_dummy_parameter;
        int2 _3789 = int2(spvTextureSize(r_depth_tp1, uint(0), _3789_dummy_parameter));
        _2060[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3789))) + int2(-1, 1), int2(0, 0), _3789 - int2(1, 1)), 0)).x;
        uint _3814_dummy_parameter;
        int2 _3814 = int2(spvTextureSize(r_depth_tp1, uint(0), _3814_dummy_parameter));
        _2060[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3814))) + int2(1, 1), int2(0, 0), _3814 - int2(1, 1)), 0)).x;
        uint _3839_dummy_parameter;
        int2 _3839 = int2(spvTextureSize(r_depth_tp1, uint(0), _3839_dummy_parameter));
        _2060[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3839))) + int2(-1, -1), int2(0, 0), _3839 - int2(1, 1)), 0)).x;
        uint _3864_dummy_parameter;
        int2 _3864 = int2(spvTextureSize(r_depth_tp1, uint(0), _3864_dummy_parameter));
        _2060[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3864))) + int2(1, -1), int2(0, 0), _3864 - int2(1, 1)), 0)).x;
        int _5333;
        _5333 = 0;
        float _5440;
        int _5441;
        int _5332 = 1;
        float _5416 = _2060[0];
        for (; _5332 < 9; _5416 = _5440, _5333 = _5441, _5332++)
        {
            bool _2410 = _2060[_5332] > _5416;
            _5440 = _2410 ? _2060[_5332] : _5416;
            _5441 = _2410 ? _5332 : _5333;
        }
        uint _3889_dummy_parameter;
        int2 _3889 = int2(spvTextureSize(r_motion_tp1, uint(0), _3889_dummy_parameter));
        float2 _3907 = r_motion_tp1.Load(int3(clamp(int2(floor(_2232 * float2(_3889))) + _1519[_5333], int2(0, 0), _3889 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5334;
        do
        {
            if (_2954)
            {
                _5334 = _3907;
                break;
            }
            float2 _3931 = _2232 + _3907;
            float _3967 = ((2.0f * _3931.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4016 = clamp((((_5274 + (((float2(atan(_3967) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3931.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3967 * _3967))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5274) * _2253)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4019 = tan(_4016.x);
            _5334 = (((float2(_4019 / cbFI_DeviceToViewDepth.z, (tan(_4016.y) * sqrt(1.0f + (_4019 * _4019))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2232) / max(_2253, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1936 + int2(floor((_5334 * _3095) * _2253))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1936 + int2(floor(_3907 * _3095))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4089_dummy_parameter;
        float4 _4096 = r_depth_tm1.Load(int3(int2(floor(_2232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4089_dummy_parameter))))), 0));
        float _4097 = _4096.x;
        float4 _4127 = mul(float4(_2825, _2823.y, _4097, 1.0f), cbFI_MotionTM1ToTP1);
        float _4129 = _4127.w;
        float2 _4143 = _2819 - (((_4127.xy / _4129.xx) + 1.0f.xx) * 0.5f);
        float2 _4145 = abs(_4143);
        bool2 _4151 = all(bool2(_4145.x < 9.9999997473787516355514526367188e-06f.xx.x, _4145.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4152 = float2(_4151.x ? 0.0f.xx.x : _4143.x, _4151.y ? 0.0f.xx.y : _4143.y);
        bool2 _4157 = any(isnan(_4152)).xx;
        float2 _4158 = float2(_4157.x ? 0.0f.xx.x : _4152.x, _4157.y ? 0.0f.xx.y : _4152.y);
        bool2 _4163 = any(isinf(_4158)).xx;
        float2 _4164 = float2(_4163.x ? 0.0f.xx.x : _4158.x, _4163.y ? 0.0f.xx.y : _4158.y);
        float2 _4170 = float2(-_4164.x, _4164.y);
        float2 _2451 = float2(-_2867.x, _2867.y) * _3095;
        float2 _2455 = _2927 * _3095;
        float2 _4225 = _2451 * 16.0146636962890625f;
        float2 _4235 = float2(int2(clamp(sign(_4225) * ceil(abs(_4225)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4251 = _2455 * 16.0146636962890625f;
        float2 _4261 = float2(int2(clamp(sign(_4251) * ceil(abs(_4251)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5335;
        if (max(max(length(_4235), length(_4261)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5335 = 0.0f;
        }
        else
        {
            _5335 = float(length(_4235 - _4261) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2460 = uint(_5335 > 0.0f);
        float _2472 = length(_2455);
        if (_2472 > 4.0f)
        {
            if (_2937)
            {
                uint _4278;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4278);
            }
        }
        bool _2484 = ((cbFI_pad0 & 2048u) != 0u) && (_2460 != 0u);
        bool _2496;
        if (_2484)
        {
            _2496 = length(_2451 - _2455) < (0.07999999821186065673828125f * max(length(_2451), _2472));
        }
        else
        {
            _2496 = _2484;
        }
        bool _2502 = (cbFI_NfruT2Flags & 2048u) != 0u;
        bool _2510;
        if (_2502)
        {
            _2510 = length(_2451 - _2455) > 2.0f;
        }
        else
        {
            _2510 = _2502;
        }
        uint _5444 = ((cbFI_NfruT2Flags & 4096u) != 0u) ? 1u : (_2510 ? 1u : (_2496 ? 0u : _2460));
        rw_dynamic_mask_tp1[_1936] = float4(clamp(float(_5444 + uint(_2834)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5444 != 0u)
        {
            if (_2937)
            {
                uint _4297;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4297);
            }
        }
        if (_2834 > 0.0f)
        {
            if (_2937)
            {
                uint _4307;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4307);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2544 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2550;
        if (_2544)
        {
            _2550 = (1.0f - (log((_4097 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2550 = _2544;
        }
        if (_2550)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1936, 0)).x) + uint(float(_4129 < 0.0f))) > 0u)
        {
            if (_2937)
            {
                uint _4327;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4327);
            }
            break;
        }
        float _4360 = 1.0f - (log((_4097 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5356;
        if (_4360 == 1.0f)
        {
            _5356 = _4360 + ((float(_2219) * _2226) * 0.100000001490116119384765625f);
        }
        else
        {
            _5356 = _4360;
        }
        float _4350 = 1.10000002384185791015625f - _5356;
        float2 _5357;
        float2 _5358;
        do
        {
            if (_2954)
            {
                _5358 = _4170;
                _5357 = _4170;
                break;
            }
            float2 _4379 = _2232 + _4170;
            float _4415 = ((2.0f * _4379.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4382 = (float2(atan(_4415) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4379.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4415 * _4415))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5274;
            float2 _4464 = clamp((((_5274 + (_4382 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4467 = tan(_4464.x);
            _5358 = _4382;
            _5357 = (((float2(_4467 / cbFI_DeviceToViewDepth.z, (tan(_4464.y) * sqrt(1.0f + (_4467 * _4467))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2232) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5360;
        int2 _5361;
        uint _5369;
        do
        {
            float2 _4514 = _5357 * _3095;
            float2 _4518 = _5358 * _3095;
            bool _4521 = any(isnan(_4514));
            bool _4528;
            if (!_4521)
            {
                _4528 = any(isinf(_4514));
            }
            else
            {
                _4528 = _4521;
            }
            bool _4535;
            if (!_4528)
            {
                _4535 = any(isnan(_4518));
            }
            else
            {
                _4535 = _4528;
            }
            bool _4542;
            if (!_4535)
            {
                _4542 = any(isinf(_4518));
            }
            else
            {
                _4542 = _4535;
            }
            bool _4548;
            if (!_4542)
            {
                _4548 = isnan(_4350);
            }
            else
            {
                _4548 = _4542;
            }
            bool _4554;
            if (!_4548)
            {
                _4554 = isinf(_4350);
            }
            else
            {
                _4554 = _4548;
            }
            if (_4554)
            {
                _5369 = 0u;
                _5361 = int2(0, 0);
                _5360 = false;
                break;
            }
            float2 _4559 = _4514 * cbFI_Timestep;
            bool _4562 = any(isnan(_4559));
            bool _4569;
            if (!_4562)
            {
                _4569 = any(isinf(_4559));
            }
            else
            {
                _4569 = _4562;
            }
            if (_4569)
            {
                _5369 = 0u;
                _5361 = int2(0, 0);
                _5360 = false;
                break;
            }
            float2 _4576 = _2228 + floor(_4559);
            bool _4579 = any(bool2(_4576.x < 0.0f.xx.x, _4576.y < 0.0f.xx.y));
            bool _4588;
            if (!_4579)
            {
                _4588 = any(bool2(_4576.x >= _3095.x, _4576.y >= _3095.y));
            }
            else
            {
                _4588 = _4579;
            }
            if (_4588)
            {
                _5369 = 0u;
                _5361 = int2(0, 0);
                _5360 = false;
                break;
            }
            float2 _4595 = _4518 * (-1.0f);
            float _4642 = _4595.x * 16.0146636962890625f;
            int _4650 = int(clamp(sign(_4642) * ceil(abs(_4642)), -16383.0f, 16383.0f));
            float _4654 = _4595.y * 16.0146636962890625f;
            int _4662 = int(clamp(sign(_4654) * ceil(abs(_4654)), -16383.0f, 16383.0f));
            int _4669 = abs(_4650);
            int _4671 = abs(_4662);
            int _4675 = clamp(firstbithigh(max(_4669, _4671)), 0, 15);
            int _4678 = max((_4675 - 6), 0);
            _5369 = (((((uint((int(round(_4350 * 1860.9090576171875f)) & 2047) << 20) | uint((_4675 & 15) << 16)) | uint(int(_4650 < 0) << 15)) | uint(int(_4662 < 0) << 14)) | uint((clamp(_4669 >> _4678, 0, 127) & 127) << 7)) | uint(clamp(_4671 >> _4678, 0, 127) & 127)) & 2147483647u;
            _5361 = int2(_4576);
            _5360 = true;
            break;
        } while(false);
        if (_5360)
        {
            uint _4760;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5361], _5369, _4760);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5377 = 0; _5377 < 3; _5377++)
                {
                    int2 _2599 = _5361 + _1305[_5377];
                    if (all(bool2(_2599.x < cbFI_MvDepthLaneSize.x, _2599.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4765;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2599], _5369, _4765);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2621 = _2232 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2626 = _2232 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4782_dummy_parameter;
                float4 _4789 = r_depth_tm1.Load(int3(int2(floor(_2232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4782_dummy_parameter))))), 0));
                float _4790 = _4789.x;
                uint _4798_dummy_parameter;
                float4 _4805 = r_depth_tm1.Load(int3(int2(floor(_2621 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4798_dummy_parameter))))), 0));
                float _4806 = _4805.x;
                uint _4814_dummy_parameter;
                float4 _4821 = r_depth_tm1.Load(int3(int2(floor(_2626 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4814_dummy_parameter))))), 0));
                float _4822 = _4821.x;
                float _4837 = _2621.x;
                float2 _4841 = float2(_4837, 1.0f - _2621.y);
                float4 _4852 = mul(float4((_4841 * 2.0f) - 1.0f.xx, _4806, 1.0f), cbFI_MotionTM1ToTP1);
                float _4854 = _4852.w;
                float2 _4868 = _4841 - (((_4852.xy / _4854.xx) + 1.0f.xx) * 0.5f);
                float2 _4870 = abs(_4868);
                bool2 _4876 = all(bool2(_4870.x < 9.9999997473787516355514526367188e-06f.xx.x, _4870.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4877 = float2(_4876.x ? 0.0f.xx.x : _4868.x, _4876.y ? 0.0f.xx.y : _4868.y);
                bool2 _4882 = any(isnan(_4877)).xx;
                float2 _4883 = float2(_4882.x ? 0.0f.xx.x : _4877.x, _4882.y ? 0.0f.xx.y : _4877.y);
                bool2 _4888 = any(isinf(_4883)).xx;
                float2 _4889 = float2(_4888.x ? 0.0f.xx.x : _4883.x, _4888.y ? 0.0f.xx.y : _4883.y);
                float _4911 = _2626.y;
                float2 _4913 = float2(_2626.x, 1.0f - _4911);
                float4 _4924 = mul(float4((_4913 * 2.0f) - 1.0f.xx, _4822, 1.0f), cbFI_MotionTM1ToTP1);
                float _4926 = _4924.w;
                float2 _4940 = _4913 - (((_4924.xy / _4926.xx) + 1.0f.xx) * 0.5f);
                float2 _4942 = abs(_4940);
                bool2 _4948 = all(bool2(_4942.x < 9.9999997473787516355514526367188e-06f.xx.x, _4942.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4949 = float2(_4948.x ? 0.0f.xx.x : _4940.x, _4948.y ? 0.0f.xx.y : _4940.y);
                bool2 _4954 = any(isnan(_4949)).xx;
                float2 _4955 = float2(_4954.x ? 0.0f.xx.x : _4949.x, _4954.y ? 0.0f.xx.y : _4949.y);
                bool2 _4960 = any(isinf(_4955)).xx;
                float2 _4961 = float2(_4960.x ? 0.0f.xx.x : _4955.x, _4960.y ? 0.0f.xx.y : _4955.y);
                bool _2648 = (_4837 < 1.0f) && (float(_4854 < 0.0f) == 0.0f);
                bool _2654;
                if (_2648)
                {
                    _2654 = abs(_4790 - _4806) <= ((0.0500000007450580596923828125f * max(abs(_4790), abs(_4806))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2654 = _2648;
                }
                bool _2660 = (_4911 < 1.0f) && (float(_4926 < 0.0f) == 0.0f);
                bool _2666;
                if (_2660)
                {
                    _2666 = abs(_4790 - _4822) <= ((0.0500000007450580596923828125f * max(abs(_4790), abs(_4822))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2666 = _2660;
                }
                float2 _5009 = (_2232 + (_4170 * cbFI_Timestep)) * _3095;
                float2 _5378;
                if (_2654)
                {
                    _5378 = ((_2621 + (float2(-_4889.x, _4889.y) * cbFI_Timestep)) * _3095) - _5009;
                }
                else
                {
                    _5378 = float2(1.0f, 0.0f);
                }
                float2 _5379;
                if (_2666)
                {
                    _5379 = ((_2626 + (float2(-_4961.x, _4961.y) * cbFI_Timestep)) * _3095) - _5009;
                }
                else
                {
                    _5379 = float2(0.0f, 1.0f);
                }
                bool _5063 = any(isnan(_5378));
                bool _5070;
                if (!_5063)
                {
                    _5070 = any(isinf(_5378));
                }
                else
                {
                    _5070 = _5063;
                }
                bool2 _5445 = _5070.xx;
                float2 _5446 = float2(_5445.x ? float2(1.0f, 0.0f).x : _5378.x, _5445.y ? float2(1.0f, 0.0f).y : _5378.y);
                bool _5075 = any(isnan(_5379));
                bool _5082;
                if (!_5075)
                {
                    _5082 = any(isinf(_5379));
                }
                else
                {
                    _5082 = _5075;
                }
                bool2 _5447 = _5082.xx;
                float2 _5448 = float2(_5447.x ? float2(0.0f, 1.0f).x : _5379.x, _5447.y ? float2(0.0f, 1.0f).y : _5379.y);
                int2 _5098 = int2(clamp(floor(min(0.0f.xx, _5446) + min(0.0f.xx, _5448)), (-3.0f).xx, 0.0f.xx));
                int2 _5104 = int2(clamp(ceil(max(0.0f.xx, _5446) + max(0.0f.xx, _5448)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5112 = _5098.y;
                for (int _5409 = _5112; _5409 <= _5104.y; _5409++)
                {
                    int _5121 = _5098.x;
                    for (int _5410 = _5121; _5410 <= _5104.x; _5410++)
                    {
                        if ((_5410 == 0) && (_5409 == 0))
                        {
                            continue;
                        }
                        int2 _5140 = _5361 + int2(_5410, _5409);
                        bool _5143 = all(bool2(_5140.x >= int2(0, 0).x, _5140.y >= int2(0, 0).y));
                        bool _5150;
                        if (_5143)
                        {
                            _5150 = all(bool2(_5140.x < cbFI_MvDepthLaneSize.x, _5140.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5150 = _5143;
                        }
                        if (_5150)
                        {
                            uint _5168;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5140], _5369, _5168);
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
