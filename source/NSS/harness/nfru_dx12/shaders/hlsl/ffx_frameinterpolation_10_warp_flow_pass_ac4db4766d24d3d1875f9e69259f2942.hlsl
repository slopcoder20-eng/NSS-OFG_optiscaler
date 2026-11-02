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
    int2 _1917 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1917.x >= cbFI_MvDepthLaneSize.x, _1917.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2201 = _1917.x + (_1917.y * cbFI_MvDepthLaneSize.x);
        float _2208 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2210 = float2(_1917);
        float2 _2214 = (_2210 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2674 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5222;
        if (_2674)
        {
            float _2687 = ((2.0f * _2214.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5222 = float2(atan(_2687) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2214.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2687 * _2687))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5222 = _2214;
        }
        uint _2729_dummy_parameter;
        float4 _2736 = r_depth_tp1.Load(int3(int2(floor(_2214 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2729_dummy_parameter))))), 0));
        float _2737 = _2736.x;
        uint _2745_dummy_parameter;
        float4 _2752 = r_depth_tp1.Load(int3(int2(floor(_2214 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2745_dummy_parameter))))), 0));
        float _2753 = _2752.x;
        rw_depth_tm1_next[_1917] = float4(_2737, 0.0f, 0.0f, 0.0f).x;
        float2 _2777 = float2(_2214.x, 1.0f - _2214.y);
        float2 _2781 = (_2777 * 2.0f) - 1.0f.xx;
        float _2783 = _2781.x;
        float4 _2788 = mul(float4(_2783, _2781.y, _2737, 1.0f), cbFI_MotionTP1ToTM1);
        float _2790 = _2788.w;
        float _2792 = float(_2790 < 0.0f);
        float2 _2804 = _2777 - (((_2788.xy / _2790.xx) + 1.0f.xx) * 0.5f);
        float2 _2806 = abs(_2804);
        bool2 _2812 = all(bool2(_2806.x < 9.9999997473787516355514526367188e-06f.xx.x, _2806.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2813 = float2(_2812.x ? 0.0f.xx.x : _2804.x, _2812.y ? 0.0f.xx.y : _2804.y);
        bool2 _2818 = any(isnan(_2813)).xx;
        float2 _2819 = float2(_2818.x ? 0.0f.xx.x : _2813.x, _2818.y ? 0.0f.xx.y : _2813.y);
        bool2 _2824 = any(isinf(_2819)).xx;
        float2 _2825 = float2(_2824.x ? 0.0f.xx.x : _2819.x, _2824.y ? 0.0f.xx.y : _2819.y);
        float _2863 = 1.0f - (log(((_2737 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5223;
        if (_2863 == 1.0f)
        {
            _5223 = _2863 + ((float(_2201) * _2208) * 0.100000001490116119384765625f);
        }
        else
        {
            _5223 = _2863;
        }
        float _2853 = 1.10000002384185791015625f - _5223;
        uint _2870_dummy_parameter;
        float2 _2885 = r_motion_tp1.Load(int3(int2(floor(_2214 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2870_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2895 = (cbFI_pad0 & 512u) != 0u;
        if (_2895)
        {
            uint _2899;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2899);
        }
        bool _2912;
        float _2238 = 1.0f - cbFI_Timestep;
        float2 _5224;
        float2 _5225;
        do
        {
            _2912 = !_2674;
            if (_2912)
            {
                _5225 = _2885;
                _5224 = _2885;
                break;
            }
            float2 _2919 = _2214 + _2885;
            float _2955 = ((2.0f * _2919.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2922 = (float2(atan(_2955) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2919.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2955 * _2955))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5222;
            float2 _3004 = clamp((((_5222 + (_2922 * _2238)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3007 = tan(_3004.x);
            _5225 = _2922;
            _5224 = (((float2(_3007 / cbFI_DeviceToViewDepth.z, (tan(_3004.y) * sqrt(1.0f + (_3007 * _3007))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2214) / max(_2238, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3053;
        bool _5228;
        int2 _5229;
        uint _5237;
        do
        {
            _3053 = float2(cbFI_MvDepthLaneSize);
            float2 _3054 = _5224 * _3053;
            float2 _3058 = _5225 * _3053;
            bool _3061 = any(isnan(_3054));
            bool _3068;
            if (!_3061)
            {
                _3068 = any(isinf(_3054));
            }
            else
            {
                _3068 = _3061;
            }
            bool _3075;
            if (!_3068)
            {
                _3075 = any(isnan(_3058));
            }
            else
            {
                _3075 = _3068;
            }
            bool _3082;
            if (!_3075)
            {
                _3082 = any(isinf(_3058));
            }
            else
            {
                _3082 = _3075;
            }
            bool _3088;
            if (!_3082)
            {
                _3088 = isnan(_2853);
            }
            else
            {
                _3088 = _3082;
            }
            bool _3094;
            if (!_3088)
            {
                _3094 = isinf(_2853);
            }
            else
            {
                _3094 = _3088;
            }
            if (_3094)
            {
                _5237 = 0u;
                _5229 = int2(0, 0);
                _5228 = false;
                break;
            }
            float2 _3099 = _3054 * _2238;
            bool _3102 = any(isnan(_3099));
            bool _3109;
            if (!_3102)
            {
                _3109 = any(isinf(_3099));
            }
            else
            {
                _3109 = _3102;
            }
            if (_3109)
            {
                _5237 = 0u;
                _5229 = int2(0, 0);
                _5228 = false;
                break;
            }
            float2 _3116 = _2210 + floor(_3099);
            bool _3119 = any(bool2(_3116.x < 0.0f.xx.x, _3116.y < 0.0f.xx.y));
            bool _3128;
            if (!_3119)
            {
                _3128 = any(bool2(_3116.x >= _3053.x, _3116.y >= _3053.y));
            }
            else
            {
                _3128 = _3119;
            }
            if (_3128)
            {
                _5237 = 0u;
                _5229 = int2(0, 0);
                _5228 = false;
                break;
            }
            float2 _3135 = _3058 * 1.0f;
            float _3182 = _3135.x * 16.0146636962890625f;
            int _3190 = int(clamp(sign(_3182) * ceil(abs(_3182)), -16383.0f, 16383.0f));
            float _3194 = _3135.y * 16.0146636962890625f;
            int _3202 = int(clamp(sign(_3194) * ceil(abs(_3194)), -16383.0f, 16383.0f));
            int _3209 = abs(_3190);
            int _3211 = abs(_3202);
            int _3215 = clamp(firstbithigh(max(_3209, _3211)), 0, 15);
            int _3218 = max((_3215 - 6), 0);
            _5237 = (((((uint((int(round(_2853 * 1860.9090576171875f)) & 2047) << 20) | uint((_3215 & 15) << 16)) | uint(int(_3190 < 0) << 15)) | uint(int(_3202 < 0) << 14)) | uint((clamp(_3209 >> _3218, 0, 127) & 127) << 7)) | uint(clamp(_3211 >> _3218, 0, 127) & 127)) & 2147483647u;
            _5229 = int2(_3116);
            _5228 = true;
            break;
        } while(false);
        if (_5228)
        {
            if (_2895)
            {
                uint _3304;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3304);
            }
            uint _3310;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5229], _5237, _3310);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5247 = 0; _5247 < 3; _5247++)
                {
                    int2 _2273 = _5229 + _1322[_5247];
                    if (all(bool2(_2273.x < cbFI_MvDepthLaneSize.x, _2273.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3315;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2273], _5237, _3315);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2295 = _2214 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2300 = _2214 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2305 = _2295.x < 1.0f;
                bool _2312;
                if (_2305)
                {
                    uint _3336_dummy_parameter;
                    float4 _3343 = r_depth_tp1.Load(int3(int2(floor(_2295 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3336_dummy_parameter))))), 0));
                    float _3344 = _3343.x;
                    _2312 = abs(_2753 - _3344) <= ((0.0500000007450580596923828125f * max(abs(_2753), abs(_3344))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2312 = _2305;
                }
                bool _2315 = _2300.y < 1.0f;
                bool _2322;
                if (_2315)
                {
                    uint _3366_dummy_parameter;
                    float4 _3373 = r_depth_tp1.Load(int3(int2(floor(_2300 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3366_dummy_parameter))))), 0));
                    float _3374 = _3373.x;
                    _2322 = abs(_2753 - _3374) <= ((0.0500000007450580596923828125f * max(abs(_2753), abs(_3374))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2322 = _2315;
                }
                float2 _3399 = (_2214 + (_2885 * _2238)) * _3053;
                uint _3406_dummy_parameter;
                uint _3443_dummy_parameter;
                float2 _5248;
                if (_2312)
                {
                    _5248 = ((_2295 + ((r_motion_tp1.Load(int3(int2(floor(_2295 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3406_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2238)) * _3053) - _3399;
                }
                else
                {
                    _5248 = float2(1.0f, 0.0f);
                }
                float2 _5249;
                if (_2322)
                {
                    _5249 = ((_2300 + ((r_motion_tp1.Load(int3(int2(floor(_2300 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3443_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2238)) * _3053) - _3399;
                }
                else
                {
                    _5249 = float2(0.0f, 1.0f);
                }
                bool _3499 = any(isnan(_5248));
                bool _3506;
                if (!_3499)
                {
                    _3506 = any(isinf(_5248));
                }
                else
                {
                    _3506 = _3499;
                }
                bool2 _5377 = _3506.xx;
                float2 _5378 = float2(_5377.x ? float2(1.0f, 0.0f).x : _5248.x, _5377.y ? float2(1.0f, 0.0f).y : _5248.y);
                bool _3511 = any(isnan(_5249));
                bool _3518;
                if (!_3511)
                {
                    _3518 = any(isinf(_5249));
                }
                else
                {
                    _3518 = _3511;
                }
                bool2 _5379 = _3518.xx;
                float2 _5380 = float2(_5379.x ? float2(0.0f, 1.0f).x : _5249.x, _5379.y ? float2(0.0f, 1.0f).y : _5249.y);
                int2 _3534 = int2(clamp(floor(min(0.0f.xx, _5378) + min(0.0f.xx, _5380)), (-3.0f).xx, 0.0f.xx));
                int2 _3540 = int2(clamp(ceil(max(0.0f.xx, _5378) + max(0.0f.xx, _5380)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3548 = _3534.y;
                for (int _5279 = _3548; _5279 <= _3540.y; _5279++)
                {
                    int _3557 = _3534.x;
                    for (int _5359 = _3557; _5359 <= _3540.x; _5359++)
                    {
                        if ((_5359 == 0) && (_5279 == 0))
                        {
                            continue;
                        }
                        int2 _3576 = _5229 + int2(_5359, _5279);
                        bool _3579 = all(bool2(_3576.x >= int2(0, 0).x, _3576.y >= int2(0, 0).y));
                        bool _3586;
                        if (_3579)
                        {
                            _3586 = all(bool2(_3576.x < cbFI_MvDepthLaneSize.x, _3576.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3586 = _3579;
                        }
                        if (_3586)
                        {
                            uint _3604;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3576], _5237, _3604);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2895)
            {
                uint _3613;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3613);
            }
        }
        uint _3622_dummy_parameter;
        int2 _3622 = int2(spvTextureSize(r_depth_tp1, uint(0), _3622_dummy_parameter));
        float _2043[9];
        _2043[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3622))), int2(0, 0), _3622 - int2(1, 1)), 0)).x;
        uint _3647_dummy_parameter;
        int2 _3647 = int2(spvTextureSize(r_depth_tp1, uint(0), _3647_dummy_parameter));
        _2043[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3647))) + int2(1, 0), int2(0, 0), _3647 - int2(1, 1)), 0)).x;
        uint _3672_dummy_parameter;
        int2 _3672 = int2(spvTextureSize(r_depth_tp1, uint(0), _3672_dummy_parameter));
        _2043[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3672))) + int2(0, 1), int2(0, 0), _3672 - int2(1, 1)), 0)).x;
        uint _3697_dummy_parameter;
        int2 _3697 = int2(spvTextureSize(r_depth_tp1, uint(0), _3697_dummy_parameter));
        _2043[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3697))) + int2(0, -1), int2(0, 0), _3697 - int2(1, 1)), 0)).x;
        uint _3722_dummy_parameter;
        int2 _3722 = int2(spvTextureSize(r_depth_tp1, uint(0), _3722_dummy_parameter));
        _2043[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3722))) + int2(-1, 0), int2(0, 0), _3722 - int2(1, 1)), 0)).x;
        uint _3747_dummy_parameter;
        int2 _3747 = int2(spvTextureSize(r_depth_tp1, uint(0), _3747_dummy_parameter));
        _2043[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3747))) + int2(-1, 1), int2(0, 0), _3747 - int2(1, 1)), 0)).x;
        uint _3772_dummy_parameter;
        int2 _3772 = int2(spvTextureSize(r_depth_tp1, uint(0), _3772_dummy_parameter));
        _2043[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3772))) + int2(1, 1), int2(0, 0), _3772 - int2(1, 1)), 0)).x;
        uint _3797_dummy_parameter;
        int2 _3797 = int2(spvTextureSize(r_depth_tp1, uint(0), _3797_dummy_parameter));
        _2043[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3797))) + int2(-1, -1), int2(0, 0), _3797 - int2(1, 1)), 0)).x;
        uint _3822_dummy_parameter;
        int2 _3822 = int2(spvTextureSize(r_depth_tp1, uint(0), _3822_dummy_parameter));
        _2043[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3822))) + int2(1, -1), int2(0, 0), _3822 - int2(1, 1)), 0)).x;
        int _5281;
        _5281 = 0;
        float _5381;
        int _5382;
        int _5280 = 1;
        float _5357 = _2043[0];
        for (; _5280 < 9; _5357 = _5381, _5281 = _5382, _5280++)
        {
            bool _2395 = _2043[_5280] < _5357;
            _5381 = _2395 ? _2043[_5280] : _5357;
            _5382 = _2395 ? _5280 : _5281;
        }
        uint _3847_dummy_parameter;
        int2 _3847 = int2(spvTextureSize(r_motion_tp1, uint(0), _3847_dummy_parameter));
        float2 _3865 = r_motion_tp1.Load(int3(clamp(int2(floor(_2214 * float2(_3847))) + _1536[_5281], int2(0, 0), _3847 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5282;
        do
        {
            if (_2912)
            {
                _5282 = _3865;
                break;
            }
            float2 _3889 = _2214 + _3865;
            float _3925 = ((2.0f * _3889.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3974 = clamp((((_5222 + (((float2(atan(_3925) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3889.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3925 * _3925))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5222) * _2238)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3977 = tan(_3974.x);
            _5282 = (((float2(_3977 / cbFI_DeviceToViewDepth.z, (tan(_3974.y) * sqrt(1.0f + (_3977 * _3977))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2214) / max(_2238, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1917 + int2(floor((_5282 * _3053) * _2238))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1917 + int2(floor(_3865 * _3053))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4047_dummy_parameter;
        float4 _4054 = r_depth_tm1.Load(int3(int2(floor(_2214 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4047_dummy_parameter))))), 0));
        float _4055 = _4054.x;
        float4 _4085 = mul(float4(_2783, _2781.y, _4055, 1.0f), cbFI_MotionTM1ToTP1);
        float _4087 = _4085.w;
        float2 _4101 = _2777 - (((_4085.xy / _4087.xx) + 1.0f.xx) * 0.5f);
        float2 _4103 = abs(_4101);
        bool2 _4109 = all(bool2(_4103.x < 9.9999997473787516355514526367188e-06f.xx.x, _4103.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4110 = float2(_4109.x ? 0.0f.xx.x : _4101.x, _4109.y ? 0.0f.xx.y : _4101.y);
        bool2 _4115 = any(isnan(_4110)).xx;
        float2 _4116 = float2(_4115.x ? 0.0f.xx.x : _4110.x, _4115.y ? 0.0f.xx.y : _4110.y);
        bool2 _4121 = any(isinf(_4116)).xx;
        float2 _4122 = float2(_4121.x ? 0.0f.xx.x : _4116.x, _4121.y ? 0.0f.xx.y : _4116.y);
        float2 _4128 = float2(-_4122.x, _4122.y);
        float2 _2436 = float2(-_2825.x, _2825.y) * _3053;
        float2 _2440 = _2885 * _3053;
        float2 _4183 = _2436 * 16.0146636962890625f;
        float2 _4193 = float2(int2(clamp(sign(_4183) * ceil(abs(_4183)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4209 = _2440 * 16.0146636962890625f;
        float2 _4219 = float2(int2(clamp(sign(_4209) * ceil(abs(_4209)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5283;
        if (max(max(length(_4193), length(_4219)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5283 = 0.0f;
        }
        else
        {
            _5283 = float(length(_4193 - _4219) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2445 = uint(_5283 > 0.0f);
        float _2457 = length(_2440);
        if (_2457 > 4.0f)
        {
            if (_2895)
            {
                uint _4236;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4236);
            }
        }
        bool _2469 = ((cbFI_pad0 & 2048u) != 0u) && (_2445 != 0u);
        bool _2481;
        if (_2469)
        {
            _2481 = length(_2436 - _2440) < (0.07999999821186065673828125f * max(length(_2436), _2457));
        }
        else
        {
            _2481 = _2469;
        }
        uint _5383 = _2481 ? 0u : _2445;
        rw_dynamic_mask_tp1[_1917] = float4(clamp(float(_5383 + uint(_2792)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5383 != 0u)
        {
            if (_2895)
            {
                uint _4255;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4255);
            }
        }
        if (_2792 > 0.0f)
        {
            if (_2895)
            {
                uint _4265;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4265);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1917, 0)).x) + uint(float(_4087 < 0.0f))) > 0u)
        {
            if (_2895)
            {
                uint _4275;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4275);
            }
            break;
        }
        float _4308 = 1.0f - (log(((_4055 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5297;
        if (_4308 == 1.0f)
        {
            _5297 = _4308 + ((float(_2201) * _2208) * 0.100000001490116119384765625f);
        }
        else
        {
            _5297 = _4308;
        }
        float _4298 = 1.10000002384185791015625f - _5297;
        float2 _5298;
        float2 _5299;
        do
        {
            if (_2912)
            {
                _5299 = _4128;
                _5298 = _4128;
                break;
            }
            float2 _4327 = _2214 + _4128;
            float _4363 = ((2.0f * _4327.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4330 = (float2(atan(_4363) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4327.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4363 * _4363))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5222;
            float2 _4412 = clamp((((_5222 + (_4330 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4415 = tan(_4412.x);
            _5299 = _4330;
            _5298 = (((float2(_4415 / cbFI_DeviceToViewDepth.z, (tan(_4412.y) * sqrt(1.0f + (_4415 * _4415))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2214) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5301;
        int2 _5302;
        uint _5310;
        do
        {
            float2 _4462 = _5298 * _3053;
            float2 _4466 = _5299 * _3053;
            bool _4469 = any(isnan(_4462));
            bool _4476;
            if (!_4469)
            {
                _4476 = any(isinf(_4462));
            }
            else
            {
                _4476 = _4469;
            }
            bool _4483;
            if (!_4476)
            {
                _4483 = any(isnan(_4466));
            }
            else
            {
                _4483 = _4476;
            }
            bool _4490;
            if (!_4483)
            {
                _4490 = any(isinf(_4466));
            }
            else
            {
                _4490 = _4483;
            }
            bool _4496;
            if (!_4490)
            {
                _4496 = isnan(_4298);
            }
            else
            {
                _4496 = _4490;
            }
            bool _4502;
            if (!_4496)
            {
                _4502 = isinf(_4298);
            }
            else
            {
                _4502 = _4496;
            }
            if (_4502)
            {
                _5310 = 0u;
                _5302 = int2(0, 0);
                _5301 = false;
                break;
            }
            float2 _4507 = _4462 * cbFI_Timestep;
            bool _4510 = any(isnan(_4507));
            bool _4517;
            if (!_4510)
            {
                _4517 = any(isinf(_4507));
            }
            else
            {
                _4517 = _4510;
            }
            if (_4517)
            {
                _5310 = 0u;
                _5302 = int2(0, 0);
                _5301 = false;
                break;
            }
            float2 _4524 = _2210 + floor(_4507);
            bool _4527 = any(bool2(_4524.x < 0.0f.xx.x, _4524.y < 0.0f.xx.y));
            bool _4536;
            if (!_4527)
            {
                _4536 = any(bool2(_4524.x >= _3053.x, _4524.y >= _3053.y));
            }
            else
            {
                _4536 = _4527;
            }
            if (_4536)
            {
                _5310 = 0u;
                _5302 = int2(0, 0);
                _5301 = false;
                break;
            }
            float2 _4543 = _4466 * (-1.0f);
            float _4590 = _4543.x * 16.0146636962890625f;
            int _4598 = int(clamp(sign(_4590) * ceil(abs(_4590)), -16383.0f, 16383.0f));
            float _4602 = _4543.y * 16.0146636962890625f;
            int _4610 = int(clamp(sign(_4602) * ceil(abs(_4602)), -16383.0f, 16383.0f));
            int _4617 = abs(_4598);
            int _4619 = abs(_4610);
            int _4623 = clamp(firstbithigh(max(_4617, _4619)), 0, 15);
            int _4626 = max((_4623 - 6), 0);
            _5310 = (((((uint((int(round(_4298 * 1860.9090576171875f)) & 2047) << 20) | uint((_4623 & 15) << 16)) | uint(int(_4598 < 0) << 15)) | uint(int(_4610 < 0) << 14)) | uint((clamp(_4617 >> _4626, 0, 127) & 127) << 7)) | uint(clamp(_4619 >> _4626, 0, 127) & 127)) & 2147483647u;
            _5302 = int2(_4524);
            _5301 = true;
            break;
        } while(false);
        if (_5301)
        {
            uint _4708;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5302], _5310, _4708);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5318 = 0; _5318 < 3; _5318++)
                {
                    int2 _2552 = _5302 + _1322[_5318];
                    if (all(bool2(_2552.x < cbFI_MvDepthLaneSize.x, _2552.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4713;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2552], _5310, _4713);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2574 = _2214 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2579 = _2214 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4730_dummy_parameter;
                float4 _4737 = r_depth_tm1.Load(int3(int2(floor(_2214 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4730_dummy_parameter))))), 0));
                float _4738 = _4737.x;
                uint _4746_dummy_parameter;
                float4 _4753 = r_depth_tm1.Load(int3(int2(floor(_2574 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4746_dummy_parameter))))), 0));
                float _4754 = _4753.x;
                uint _4762_dummy_parameter;
                float4 _4769 = r_depth_tm1.Load(int3(int2(floor(_2579 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4762_dummy_parameter))))), 0));
                float _4770 = _4769.x;
                float _4785 = _2574.x;
                float2 _4789 = float2(_4785, 1.0f - _2574.y);
                float4 _4800 = mul(float4((_4789 * 2.0f) - 1.0f.xx, _4754, 1.0f), cbFI_MotionTM1ToTP1);
                float _4802 = _4800.w;
                float2 _4816 = _4789 - (((_4800.xy / _4802.xx) + 1.0f.xx) * 0.5f);
                float2 _4818 = abs(_4816);
                bool2 _4824 = all(bool2(_4818.x < 9.9999997473787516355514526367188e-06f.xx.x, _4818.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4825 = float2(_4824.x ? 0.0f.xx.x : _4816.x, _4824.y ? 0.0f.xx.y : _4816.y);
                bool2 _4830 = any(isnan(_4825)).xx;
                float2 _4831 = float2(_4830.x ? 0.0f.xx.x : _4825.x, _4830.y ? 0.0f.xx.y : _4825.y);
                bool2 _4836 = any(isinf(_4831)).xx;
                float2 _4837 = float2(_4836.x ? 0.0f.xx.x : _4831.x, _4836.y ? 0.0f.xx.y : _4831.y);
                float _4859 = _2579.y;
                float2 _4861 = float2(_2579.x, 1.0f - _4859);
                float4 _4872 = mul(float4((_4861 * 2.0f) - 1.0f.xx, _4770, 1.0f), cbFI_MotionTM1ToTP1);
                float _4874 = _4872.w;
                float2 _4888 = _4861 - (((_4872.xy / _4874.xx) + 1.0f.xx) * 0.5f);
                float2 _4890 = abs(_4888);
                bool2 _4896 = all(bool2(_4890.x < 9.9999997473787516355514526367188e-06f.xx.x, _4890.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4897 = float2(_4896.x ? 0.0f.xx.x : _4888.x, _4896.y ? 0.0f.xx.y : _4888.y);
                bool2 _4902 = any(isnan(_4897)).xx;
                float2 _4903 = float2(_4902.x ? 0.0f.xx.x : _4897.x, _4902.y ? 0.0f.xx.y : _4897.y);
                bool2 _4908 = any(isinf(_4903)).xx;
                float2 _4909 = float2(_4908.x ? 0.0f.xx.x : _4903.x, _4908.y ? 0.0f.xx.y : _4903.y);
                bool _2601 = (_4785 < 1.0f) && (float(_4802 < 0.0f) == 0.0f);
                bool _2607;
                if (_2601)
                {
                    _2607 = abs(_4738 - _4754) <= ((0.0500000007450580596923828125f * max(abs(_4738), abs(_4754))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2607 = _2601;
                }
                bool _2613 = (_4859 < 1.0f) && (float(_4874 < 0.0f) == 0.0f);
                bool _2619;
                if (_2613)
                {
                    _2619 = abs(_4738 - _4770) <= ((0.0500000007450580596923828125f * max(abs(_4738), abs(_4770))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2619 = _2613;
                }
                float2 _4957 = (_2214 + (_4128 * cbFI_Timestep)) * _3053;
                float2 _5319;
                if (_2607)
                {
                    _5319 = ((_2574 + (float2(-_4837.x, _4837.y) * cbFI_Timestep)) * _3053) - _4957;
                }
                else
                {
                    _5319 = float2(1.0f, 0.0f);
                }
                float2 _5320;
                if (_2619)
                {
                    _5320 = ((_2579 + (float2(-_4909.x, _4909.y) * cbFI_Timestep)) * _3053) - _4957;
                }
                else
                {
                    _5320 = float2(0.0f, 1.0f);
                }
                bool _5011 = any(isnan(_5319));
                bool _5018;
                if (!_5011)
                {
                    _5018 = any(isinf(_5319));
                }
                else
                {
                    _5018 = _5011;
                }
                bool2 _5384 = _5018.xx;
                float2 _5385 = float2(_5384.x ? float2(1.0f, 0.0f).x : _5319.x, _5384.y ? float2(1.0f, 0.0f).y : _5319.y);
                bool _5023 = any(isnan(_5320));
                bool _5030;
                if (!_5023)
                {
                    _5030 = any(isinf(_5320));
                }
                else
                {
                    _5030 = _5023;
                }
                bool2 _5386 = _5030.xx;
                float2 _5387 = float2(_5386.x ? float2(0.0f, 1.0f).x : _5320.x, _5386.y ? float2(0.0f, 1.0f).y : _5320.y);
                int2 _5046 = int2(clamp(floor(min(0.0f.xx, _5385) + min(0.0f.xx, _5387)), (-3.0f).xx, 0.0f.xx));
                int2 _5052 = int2(clamp(ceil(max(0.0f.xx, _5385) + max(0.0f.xx, _5387)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5060 = _5046.y;
                for (int _5350 = _5060; _5350 <= _5052.y; _5350++)
                {
                    int _5069 = _5046.x;
                    for (int _5351 = _5069; _5351 <= _5052.x; _5351++)
                    {
                        if ((_5351 == 0) && (_5350 == 0))
                        {
                            continue;
                        }
                        int2 _5088 = _5302 + int2(_5351, _5350);
                        bool _5091 = all(bool2(_5088.x >= int2(0, 0).x, _5088.y >= int2(0, 0).y));
                        bool _5098;
                        if (_5091)
                        {
                            _5098 = all(bool2(_5088.x < cbFI_MvDepthLaneSize.x, _5088.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5098 = _5091;
                        }
                        if (_5098)
                        {
                            uint _5116;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5088], _5310, _5116);
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
