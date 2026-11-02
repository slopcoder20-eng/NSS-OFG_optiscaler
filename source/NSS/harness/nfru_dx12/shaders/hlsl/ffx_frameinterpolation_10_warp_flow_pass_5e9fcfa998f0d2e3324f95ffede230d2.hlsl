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
    int2 _1900 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1900.x >= cbFI_MvDepthLaneSize.x, _1900.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2182 = _1900.x + (_1900.y * cbFI_MvDepthLaneSize.x);
        float _2189 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2191 = float2(_1900);
        float2 _2195 = (_2191 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2652 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5195;
        if (_2652)
        {
            float _2665 = ((2.0f * _2195.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5195 = float2(atan(_2665) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2195.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2665 * _2665))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5195 = _2195;
        }
        uint _2707_dummy_parameter;
        float4 _2714 = r_depth_tp1.Load(int3(int2(floor(_2195 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2707_dummy_parameter))))), 0));
        float _2715 = _2714.x;
        uint _2723_dummy_parameter;
        float4 _2730 = r_depth_tp1.Load(int3(int2(floor(_2195 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2723_dummy_parameter))))), 0));
        float _2731 = _2730.x;
        float2 _2750 = float2(_2195.x, 1.0f - _2195.y);
        float2 _2754 = (_2750 * 2.0f) - 1.0f.xx;
        float _2756 = _2754.x;
        float4 _2761 = mul(float4(_2756, _2754.y, _2715, 1.0f), cbFI_MotionTP1ToTM1);
        float _2763 = _2761.w;
        float _2765 = float(_2763 < 0.0f);
        float2 _2777 = _2750 - (((_2761.xy / _2763.xx) + 1.0f.xx) * 0.5f);
        float2 _2779 = abs(_2777);
        bool2 _2785 = all(bool2(_2779.x < 9.9999997473787516355514526367188e-06f.xx.x, _2779.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2786 = float2(_2785.x ? 0.0f.xx.x : _2777.x, _2785.y ? 0.0f.xx.y : _2777.y);
        bool2 _2791 = any(isnan(_2786)).xx;
        float2 _2792 = float2(_2791.x ? 0.0f.xx.x : _2786.x, _2791.y ? 0.0f.xx.y : _2786.y);
        bool2 _2797 = any(isinf(_2792)).xx;
        float2 _2798 = float2(_2797.x ? 0.0f.xx.x : _2792.x, _2797.y ? 0.0f.xx.y : _2792.y);
        float _2836 = 1.0f - (log((_2715 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5196;
        if (_2836 == 1.0f)
        {
            _5196 = _2836 + ((float(_2182) * _2189) * 0.100000001490116119384765625f);
        }
        else
        {
            _5196 = _2836;
        }
        float _2826 = 1.10000002384185791015625f - _5196;
        uint _2843_dummy_parameter;
        float2 _2858 = r_motion_tp1.Load(int3(int2(floor(_2195 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2843_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2868 = (cbFI_pad0 & 512u) != 0u;
        if (_2868)
        {
            uint _2872;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2872);
        }
        bool _2885;
        float _2216 = 1.0f - cbFI_Timestep;
        float2 _5197;
        float2 _5198;
        do
        {
            _2885 = !_2652;
            if (_2885)
            {
                _5198 = _2858;
                _5197 = _2858;
                break;
            }
            float2 _2892 = _2195 + _2858;
            float _2928 = ((2.0f * _2892.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2895 = (float2(atan(_2928) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2892.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2928 * _2928))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5195;
            float2 _2977 = clamp((((_5195 + (_2895 * _2216)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2980 = tan(_2977.x);
            _5198 = _2895;
            _5197 = (((float2(_2980 / cbFI_DeviceToViewDepth.z, (tan(_2977.y) * sqrt(1.0f + (_2980 * _2980))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2195) / max(_2216, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3026;
        bool _5201;
        int2 _5202;
        uint _5210;
        do
        {
            _3026 = float2(cbFI_MvDepthLaneSize);
            float2 _3027 = _5197 * _3026;
            float2 _3031 = _5198 * _3026;
            bool _3034 = any(isnan(_3027));
            bool _3041;
            if (!_3034)
            {
                _3041 = any(isinf(_3027));
            }
            else
            {
                _3041 = _3034;
            }
            bool _3048;
            if (!_3041)
            {
                _3048 = any(isnan(_3031));
            }
            else
            {
                _3048 = _3041;
            }
            bool _3055;
            if (!_3048)
            {
                _3055 = any(isinf(_3031));
            }
            else
            {
                _3055 = _3048;
            }
            bool _3061;
            if (!_3055)
            {
                _3061 = isnan(_2826);
            }
            else
            {
                _3061 = _3055;
            }
            bool _3067;
            if (!_3061)
            {
                _3067 = isinf(_2826);
            }
            else
            {
                _3067 = _3061;
            }
            if (_3067)
            {
                _5210 = 0u;
                _5202 = int2(0, 0);
                _5201 = false;
                break;
            }
            float2 _3072 = _3027 * _2216;
            bool _3075 = any(isnan(_3072));
            bool _3082;
            if (!_3075)
            {
                _3082 = any(isinf(_3072));
            }
            else
            {
                _3082 = _3075;
            }
            if (_3082)
            {
                _5210 = 0u;
                _5202 = int2(0, 0);
                _5201 = false;
                break;
            }
            float2 _3089 = _2191 + floor(_3072);
            bool _3092 = any(bool2(_3089.x < 0.0f.xx.x, _3089.y < 0.0f.xx.y));
            bool _3101;
            if (!_3092)
            {
                _3101 = any(bool2(_3089.x >= _3026.x, _3089.y >= _3026.y));
            }
            else
            {
                _3101 = _3092;
            }
            if (_3101)
            {
                _5210 = 0u;
                _5202 = int2(0, 0);
                _5201 = false;
                break;
            }
            float2 _3108 = _3031 * 1.0f;
            float _3155 = _3108.x * 16.0146636962890625f;
            int _3163 = int(clamp(sign(_3155) * ceil(abs(_3155)), -16383.0f, 16383.0f));
            float _3167 = _3108.y * 16.0146636962890625f;
            int _3175 = int(clamp(sign(_3167) * ceil(abs(_3167)), -16383.0f, 16383.0f));
            int _3182 = abs(_3163);
            int _3184 = abs(_3175);
            int _3188 = clamp(firstbithigh(max(_3182, _3184)), 0, 15);
            int _3191 = max((_3188 - 6), 0);
            _5210 = (((((uint((int(round(_2826 * 1860.9090576171875f)) & 2047) << 20) | uint((_3188 & 15) << 16)) | uint(int(_3163 < 0) << 15)) | uint(int(_3175 < 0) << 14)) | uint((clamp(_3182 >> _3191, 0, 127) & 127) << 7)) | uint(clamp(_3184 >> _3191, 0, 127) & 127)) & 2147483647u;
            _5202 = int2(_3089);
            _5201 = true;
            break;
        } while(false);
        if (_5201)
        {
            if (_2868)
            {
                uint _3277;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3277);
            }
            uint _3283;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5202], _5210, _3283);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5220 = 0; _5220 < 3; _5220++)
                {
                    int2 _2251 = _5202 + _1305[_5220];
                    if (all(bool2(_2251.x < cbFI_MvDepthLaneSize.x, _2251.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3288;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2251], _5210, _3288);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2273 = _2195 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2278 = _2195 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2283 = _2273.x < 1.0f;
                bool _2290;
                if (_2283)
                {
                    uint _3309_dummy_parameter;
                    float4 _3316 = r_depth_tp1.Load(int3(int2(floor(_2273 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3309_dummy_parameter))))), 0));
                    float _3317 = _3316.x;
                    _2290 = abs(_2731 - _3317) <= ((0.0500000007450580596923828125f * max(abs(_2731), abs(_3317))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2290 = _2283;
                }
                bool _2293 = _2278.y < 1.0f;
                bool _2300;
                if (_2293)
                {
                    uint _3339_dummy_parameter;
                    float4 _3346 = r_depth_tp1.Load(int3(int2(floor(_2278 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3339_dummy_parameter))))), 0));
                    float _3347 = _3346.x;
                    _2300 = abs(_2731 - _3347) <= ((0.0500000007450580596923828125f * max(abs(_2731), abs(_3347))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2300 = _2293;
                }
                float2 _3372 = (_2195 + (_2858 * _2216)) * _3026;
                uint _3379_dummy_parameter;
                uint _3416_dummy_parameter;
                float2 _5221;
                if (_2290)
                {
                    _5221 = ((_2273 + ((r_motion_tp1.Load(int3(int2(floor(_2273 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3379_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2216)) * _3026) - _3372;
                }
                else
                {
                    _5221 = float2(1.0f, 0.0f);
                }
                float2 _5222;
                if (_2300)
                {
                    _5222 = ((_2278 + ((r_motion_tp1.Load(int3(int2(floor(_2278 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3416_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2216)) * _3026) - _3372;
                }
                else
                {
                    _5222 = float2(0.0f, 1.0f);
                }
                bool _3472 = any(isnan(_5221));
                bool _3479;
                if (!_3472)
                {
                    _3479 = any(isinf(_5221));
                }
                else
                {
                    _3479 = _3472;
                }
                bool2 _5350 = _3479.xx;
                float2 _5351 = float2(_5350.x ? float2(1.0f, 0.0f).x : _5221.x, _5350.y ? float2(1.0f, 0.0f).y : _5221.y);
                bool _3484 = any(isnan(_5222));
                bool _3491;
                if (!_3484)
                {
                    _3491 = any(isinf(_5222));
                }
                else
                {
                    _3491 = _3484;
                }
                bool2 _5352 = _3491.xx;
                float2 _5353 = float2(_5352.x ? float2(0.0f, 1.0f).x : _5222.x, _5352.y ? float2(0.0f, 1.0f).y : _5222.y);
                int2 _3507 = int2(clamp(floor(min(0.0f.xx, _5351) + min(0.0f.xx, _5353)), (-3.0f).xx, 0.0f.xx));
                int2 _3513 = int2(clamp(ceil(max(0.0f.xx, _5351) + max(0.0f.xx, _5353)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3521 = _3507.y;
                for (int _5252 = _3521; _5252 <= _3513.y; _5252++)
                {
                    int _3530 = _3507.x;
                    for (int _5332 = _3530; _5332 <= _3513.x; _5332++)
                    {
                        if ((_5332 == 0) && (_5252 == 0))
                        {
                            continue;
                        }
                        int2 _3549 = _5202 + int2(_5332, _5252);
                        bool _3552 = all(bool2(_3549.x >= int2(0, 0).x, _3549.y >= int2(0, 0).y));
                        bool _3559;
                        if (_3552)
                        {
                            _3559 = all(bool2(_3549.x < cbFI_MvDepthLaneSize.x, _3549.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3559 = _3552;
                        }
                        if (_3559)
                        {
                            uint _3577;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3549], _5210, _3577);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2868)
            {
                uint _3586;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3586);
            }
        }
        uint _3595_dummy_parameter;
        int2 _3595 = int2(spvTextureSize(r_depth_tp1, uint(0), _3595_dummy_parameter));
        float _2024[9];
        _2024[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3595))), int2(0, 0), _3595 - int2(1, 1)), 0)).x;
        uint _3620_dummy_parameter;
        int2 _3620 = int2(spvTextureSize(r_depth_tp1, uint(0), _3620_dummy_parameter));
        _2024[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3620))) + int2(1, 0), int2(0, 0), _3620 - int2(1, 1)), 0)).x;
        uint _3645_dummy_parameter;
        int2 _3645 = int2(spvTextureSize(r_depth_tp1, uint(0), _3645_dummy_parameter));
        _2024[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3645))) + int2(0, 1), int2(0, 0), _3645 - int2(1, 1)), 0)).x;
        uint _3670_dummy_parameter;
        int2 _3670 = int2(spvTextureSize(r_depth_tp1, uint(0), _3670_dummy_parameter));
        _2024[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3670))) + int2(0, -1), int2(0, 0), _3670 - int2(1, 1)), 0)).x;
        uint _3695_dummy_parameter;
        int2 _3695 = int2(spvTextureSize(r_depth_tp1, uint(0), _3695_dummy_parameter));
        _2024[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3695))) + int2(-1, 0), int2(0, 0), _3695 - int2(1, 1)), 0)).x;
        uint _3720_dummy_parameter;
        int2 _3720 = int2(spvTextureSize(r_depth_tp1, uint(0), _3720_dummy_parameter));
        _2024[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3720))) + int2(-1, 1), int2(0, 0), _3720 - int2(1, 1)), 0)).x;
        uint _3745_dummy_parameter;
        int2 _3745 = int2(spvTextureSize(r_depth_tp1, uint(0), _3745_dummy_parameter));
        _2024[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3745))) + int2(1, 1), int2(0, 0), _3745 - int2(1, 1)), 0)).x;
        uint _3770_dummy_parameter;
        int2 _3770 = int2(spvTextureSize(r_depth_tp1, uint(0), _3770_dummy_parameter));
        _2024[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3770))) + int2(-1, -1), int2(0, 0), _3770 - int2(1, 1)), 0)).x;
        uint _3795_dummy_parameter;
        int2 _3795 = int2(spvTextureSize(r_depth_tp1, uint(0), _3795_dummy_parameter));
        _2024[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3795))) + int2(1, -1), int2(0, 0), _3795 - int2(1, 1)), 0)).x;
        int _5254;
        _5254 = 0;
        float _5354;
        int _5355;
        int _5253 = 1;
        float _5330 = _2024[0];
        for (; _5253 < 9; _5330 = _5354, _5254 = _5355, _5253++)
        {
            bool _2373 = _2024[_5253] > _5330;
            _5354 = _2373 ? _2024[_5253] : _5330;
            _5355 = _2373 ? _5253 : _5254;
        }
        uint _3820_dummy_parameter;
        int2 _3820 = int2(spvTextureSize(r_motion_tp1, uint(0), _3820_dummy_parameter));
        float2 _3838 = r_motion_tp1.Load(int3(clamp(int2(floor(_2195 * float2(_3820))) + _1519[_5254], int2(0, 0), _3820 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5255;
        do
        {
            if (_2885)
            {
                _5255 = _3838;
                break;
            }
            float2 _3862 = _2195 + _3838;
            float _3898 = ((2.0f * _3862.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3947 = clamp((((_5195 + (((float2(atan(_3898) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3862.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3898 * _3898))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5195) * _2216)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3950 = tan(_3947.x);
            _5255 = (((float2(_3950 / cbFI_DeviceToViewDepth.z, (tan(_3947.y) * sqrt(1.0f + (_3950 * _3950))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2195) / max(_2216, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1900 + int2(floor((_5255 * _3026) * _2216))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1900 + int2(floor(_3838 * _3026))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4020_dummy_parameter;
        float4 _4027 = r_depth_tm1.Load(int3(int2(floor(_2195 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4020_dummy_parameter))))), 0));
        float _4028 = _4027.x;
        float4 _4058 = mul(float4(_2756, _2754.y, _4028, 1.0f), cbFI_MotionTM1ToTP1);
        float _4060 = _4058.w;
        float2 _4074 = _2750 - (((_4058.xy / _4060.xx) + 1.0f.xx) * 0.5f);
        float2 _4076 = abs(_4074);
        bool2 _4082 = all(bool2(_4076.x < 9.9999997473787516355514526367188e-06f.xx.x, _4076.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4083 = float2(_4082.x ? 0.0f.xx.x : _4074.x, _4082.y ? 0.0f.xx.y : _4074.y);
        bool2 _4088 = any(isnan(_4083)).xx;
        float2 _4089 = float2(_4088.x ? 0.0f.xx.x : _4083.x, _4088.y ? 0.0f.xx.y : _4083.y);
        bool2 _4094 = any(isinf(_4089)).xx;
        float2 _4095 = float2(_4094.x ? 0.0f.xx.x : _4089.x, _4094.y ? 0.0f.xx.y : _4089.y);
        float2 _4101 = float2(-_4095.x, _4095.y);
        float2 _2414 = float2(-_2798.x, _2798.y) * _3026;
        float2 _2418 = _2858 * _3026;
        float2 _4156 = _2414 * 16.0146636962890625f;
        float2 _4166 = float2(int2(clamp(sign(_4156) * ceil(abs(_4156)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4182 = _2418 * 16.0146636962890625f;
        float2 _4192 = float2(int2(clamp(sign(_4182) * ceil(abs(_4182)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5256;
        if (max(max(length(_4166), length(_4192)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5256 = 0.0f;
        }
        else
        {
            _5256 = float(length(_4166 - _4192) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2423 = uint(_5256 > 0.0f);
        float _2435 = length(_2418);
        if (_2435 > 4.0f)
        {
            if (_2868)
            {
                uint _4209;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4209);
            }
        }
        bool _2447 = ((cbFI_pad0 & 2048u) != 0u) && (_2423 != 0u);
        bool _2459;
        if (_2447)
        {
            _2459 = length(_2414 - _2418) < (0.07999999821186065673828125f * max(length(_2414), _2435));
        }
        else
        {
            _2459 = _2447;
        }
        uint _5356 = _2459 ? 0u : _2423;
        rw_dynamic_mask_tp1[_1900] = float4(clamp(float(_5356 + uint(_2765)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5356 != 0u)
        {
            if (_2868)
            {
                uint _4228;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4228);
            }
        }
        if (_2765 > 0.0f)
        {
            if (_2868)
            {
                uint _4238;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4238);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1900, 0)).x) + uint(float(_4060 < 0.0f))) > 0u)
        {
            if (_2868)
            {
                uint _4248;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4248);
            }
            break;
        }
        float _4281 = 1.0f - (log((_4028 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5270;
        if (_4281 == 1.0f)
        {
            _5270 = _4281 + ((float(_2182) * _2189) * 0.100000001490116119384765625f);
        }
        else
        {
            _5270 = _4281;
        }
        float _4271 = 1.10000002384185791015625f - _5270;
        float2 _5271;
        float2 _5272;
        do
        {
            if (_2885)
            {
                _5272 = _4101;
                _5271 = _4101;
                break;
            }
            float2 _4300 = _2195 + _4101;
            float _4336 = ((2.0f * _4300.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4303 = (float2(atan(_4336) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4300.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4336 * _4336))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5195;
            float2 _4385 = clamp((((_5195 + (_4303 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4388 = tan(_4385.x);
            _5272 = _4303;
            _5271 = (((float2(_4388 / cbFI_DeviceToViewDepth.z, (tan(_4385.y) * sqrt(1.0f + (_4388 * _4388))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2195) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5274;
        int2 _5275;
        uint _5283;
        do
        {
            float2 _4435 = _5271 * _3026;
            float2 _4439 = _5272 * _3026;
            bool _4442 = any(isnan(_4435));
            bool _4449;
            if (!_4442)
            {
                _4449 = any(isinf(_4435));
            }
            else
            {
                _4449 = _4442;
            }
            bool _4456;
            if (!_4449)
            {
                _4456 = any(isnan(_4439));
            }
            else
            {
                _4456 = _4449;
            }
            bool _4463;
            if (!_4456)
            {
                _4463 = any(isinf(_4439));
            }
            else
            {
                _4463 = _4456;
            }
            bool _4469;
            if (!_4463)
            {
                _4469 = isnan(_4271);
            }
            else
            {
                _4469 = _4463;
            }
            bool _4475;
            if (!_4469)
            {
                _4475 = isinf(_4271);
            }
            else
            {
                _4475 = _4469;
            }
            if (_4475)
            {
                _5283 = 0u;
                _5275 = int2(0, 0);
                _5274 = false;
                break;
            }
            float2 _4480 = _4435 * cbFI_Timestep;
            bool _4483 = any(isnan(_4480));
            bool _4490;
            if (!_4483)
            {
                _4490 = any(isinf(_4480));
            }
            else
            {
                _4490 = _4483;
            }
            if (_4490)
            {
                _5283 = 0u;
                _5275 = int2(0, 0);
                _5274 = false;
                break;
            }
            float2 _4497 = _2191 + floor(_4480);
            bool _4500 = any(bool2(_4497.x < 0.0f.xx.x, _4497.y < 0.0f.xx.y));
            bool _4509;
            if (!_4500)
            {
                _4509 = any(bool2(_4497.x >= _3026.x, _4497.y >= _3026.y));
            }
            else
            {
                _4509 = _4500;
            }
            if (_4509)
            {
                _5283 = 0u;
                _5275 = int2(0, 0);
                _5274 = false;
                break;
            }
            float2 _4516 = _4439 * (-1.0f);
            float _4563 = _4516.x * 16.0146636962890625f;
            int _4571 = int(clamp(sign(_4563) * ceil(abs(_4563)), -16383.0f, 16383.0f));
            float _4575 = _4516.y * 16.0146636962890625f;
            int _4583 = int(clamp(sign(_4575) * ceil(abs(_4575)), -16383.0f, 16383.0f));
            int _4590 = abs(_4571);
            int _4592 = abs(_4583);
            int _4596 = clamp(firstbithigh(max(_4590, _4592)), 0, 15);
            int _4599 = max((_4596 - 6), 0);
            _5283 = (((((uint((int(round(_4271 * 1860.9090576171875f)) & 2047) << 20) | uint((_4596 & 15) << 16)) | uint(int(_4571 < 0) << 15)) | uint(int(_4583 < 0) << 14)) | uint((clamp(_4590 >> _4599, 0, 127) & 127) << 7)) | uint(clamp(_4592 >> _4599, 0, 127) & 127)) & 2147483647u;
            _5275 = int2(_4497);
            _5274 = true;
            break;
        } while(false);
        if (_5274)
        {
            uint _4681;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5275], _5283, _4681);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5291 = 0; _5291 < 3; _5291++)
                {
                    int2 _2530 = _5275 + _1305[_5291];
                    if (all(bool2(_2530.x < cbFI_MvDepthLaneSize.x, _2530.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4686;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2530], _5283, _4686);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2552 = _2195 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2557 = _2195 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4703_dummy_parameter;
                float4 _4710 = r_depth_tm1.Load(int3(int2(floor(_2195 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4703_dummy_parameter))))), 0));
                float _4711 = _4710.x;
                uint _4719_dummy_parameter;
                float4 _4726 = r_depth_tm1.Load(int3(int2(floor(_2552 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4719_dummy_parameter))))), 0));
                float _4727 = _4726.x;
                uint _4735_dummy_parameter;
                float4 _4742 = r_depth_tm1.Load(int3(int2(floor(_2557 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4735_dummy_parameter))))), 0));
                float _4743 = _4742.x;
                float _4758 = _2552.x;
                float2 _4762 = float2(_4758, 1.0f - _2552.y);
                float4 _4773 = mul(float4((_4762 * 2.0f) - 1.0f.xx, _4727, 1.0f), cbFI_MotionTM1ToTP1);
                float _4775 = _4773.w;
                float2 _4789 = _4762 - (((_4773.xy / _4775.xx) + 1.0f.xx) * 0.5f);
                float2 _4791 = abs(_4789);
                bool2 _4797 = all(bool2(_4791.x < 9.9999997473787516355514526367188e-06f.xx.x, _4791.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4798 = float2(_4797.x ? 0.0f.xx.x : _4789.x, _4797.y ? 0.0f.xx.y : _4789.y);
                bool2 _4803 = any(isnan(_4798)).xx;
                float2 _4804 = float2(_4803.x ? 0.0f.xx.x : _4798.x, _4803.y ? 0.0f.xx.y : _4798.y);
                bool2 _4809 = any(isinf(_4804)).xx;
                float2 _4810 = float2(_4809.x ? 0.0f.xx.x : _4804.x, _4809.y ? 0.0f.xx.y : _4804.y);
                float _4832 = _2557.y;
                float2 _4834 = float2(_2557.x, 1.0f - _4832);
                float4 _4845 = mul(float4((_4834 * 2.0f) - 1.0f.xx, _4743, 1.0f), cbFI_MotionTM1ToTP1);
                float _4847 = _4845.w;
                float2 _4861 = _4834 - (((_4845.xy / _4847.xx) + 1.0f.xx) * 0.5f);
                float2 _4863 = abs(_4861);
                bool2 _4869 = all(bool2(_4863.x < 9.9999997473787516355514526367188e-06f.xx.x, _4863.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4870 = float2(_4869.x ? 0.0f.xx.x : _4861.x, _4869.y ? 0.0f.xx.y : _4861.y);
                bool2 _4875 = any(isnan(_4870)).xx;
                float2 _4876 = float2(_4875.x ? 0.0f.xx.x : _4870.x, _4875.y ? 0.0f.xx.y : _4870.y);
                bool2 _4881 = any(isinf(_4876)).xx;
                float2 _4882 = float2(_4881.x ? 0.0f.xx.x : _4876.x, _4881.y ? 0.0f.xx.y : _4876.y);
                bool _2579 = (_4758 < 1.0f) && (float(_4775 < 0.0f) == 0.0f);
                bool _2585;
                if (_2579)
                {
                    _2585 = abs(_4711 - _4727) <= ((0.0500000007450580596923828125f * max(abs(_4711), abs(_4727))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2585 = _2579;
                }
                bool _2591 = (_4832 < 1.0f) && (float(_4847 < 0.0f) == 0.0f);
                bool _2597;
                if (_2591)
                {
                    _2597 = abs(_4711 - _4743) <= ((0.0500000007450580596923828125f * max(abs(_4711), abs(_4743))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2597 = _2591;
                }
                float2 _4930 = (_2195 + (_4101 * cbFI_Timestep)) * _3026;
                float2 _5292;
                if (_2585)
                {
                    _5292 = ((_2552 + (float2(-_4810.x, _4810.y) * cbFI_Timestep)) * _3026) - _4930;
                }
                else
                {
                    _5292 = float2(1.0f, 0.0f);
                }
                float2 _5293;
                if (_2597)
                {
                    _5293 = ((_2557 + (float2(-_4882.x, _4882.y) * cbFI_Timestep)) * _3026) - _4930;
                }
                else
                {
                    _5293 = float2(0.0f, 1.0f);
                }
                bool _4984 = any(isnan(_5292));
                bool _4991;
                if (!_4984)
                {
                    _4991 = any(isinf(_5292));
                }
                else
                {
                    _4991 = _4984;
                }
                bool2 _5357 = _4991.xx;
                float2 _5358 = float2(_5357.x ? float2(1.0f, 0.0f).x : _5292.x, _5357.y ? float2(1.0f, 0.0f).y : _5292.y);
                bool _4996 = any(isnan(_5293));
                bool _5003;
                if (!_4996)
                {
                    _5003 = any(isinf(_5293));
                }
                else
                {
                    _5003 = _4996;
                }
                bool2 _5359 = _5003.xx;
                float2 _5360 = float2(_5359.x ? float2(0.0f, 1.0f).x : _5293.x, _5359.y ? float2(0.0f, 1.0f).y : _5293.y);
                int2 _5019 = int2(clamp(floor(min(0.0f.xx, _5358) + min(0.0f.xx, _5360)), (-3.0f).xx, 0.0f.xx));
                int2 _5025 = int2(clamp(ceil(max(0.0f.xx, _5358) + max(0.0f.xx, _5360)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5033 = _5019.y;
                for (int _5323 = _5033; _5323 <= _5025.y; _5323++)
                {
                    int _5042 = _5019.x;
                    for (int _5324 = _5042; _5324 <= _5025.x; _5324++)
                    {
                        if ((_5324 == 0) && (_5323 == 0))
                        {
                            continue;
                        }
                        int2 _5061 = _5275 + int2(_5324, _5323);
                        bool _5064 = all(bool2(_5061.x >= int2(0, 0).x, _5061.y >= int2(0, 0).y));
                        bool _5071;
                        if (_5064)
                        {
                            _5071 = all(bool2(_5061.x < cbFI_MvDepthLaneSize.x, _5061.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5071 = _5064;
                        }
                        if (_5071)
                        {
                            uint _5089;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5061], _5283, _5089);
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
