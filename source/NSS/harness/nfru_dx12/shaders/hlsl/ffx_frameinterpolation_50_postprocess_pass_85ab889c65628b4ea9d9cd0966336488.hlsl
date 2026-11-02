static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3031[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

cbuffer cbFI_t : register(b7, space0)
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
RWByteAddressBuffer rw_nfru_select : register(u19, space0);
Texture2D<float4> r_depth_m2 : register(t17, space0);
Texture2D<float4> r_colour_m2 : register(t16, space0);
Texture2D<float4> r_present_backbuffer : register(t9, space0);
Texture2D<float4> r_motion_tp1 : register(t13, space0);
Texture2D<float4> r_depth_tp1 : register(t11, space0);
Texture2D<float4> r_depth_tm1 : register(t12, space0);
Texture2D<uint4> r_warped_motion_qdata_tp1 : register(t18, space0);
Texture2D<uint4> r_warped_flow_qdata_tm1 : register(t15, space0);
Texture2D<float4> r_warped_filled_motion_tp1 : register(t1, space0);
Texture2D<float4> r_warped_filled_flow_tm1 : register(t2, space0);
Texture2D<float4> r_previous_interpolation_source : register(t4, space0);
SamplerState s_LinearClamp : register(s1001, space0);
Texture2D<float4> r_current_interpolation_source : register(t5, space0);
Texture2D<float4> r_out_params_tensor : register(t0, space0);
RWTexture2D<float3> rw_output : register(u6, space0);
RWTexture2D<float3> rw_previous_interpolation_source : register(u8, space0);
Texture2D<float4> r_flow_tm1 : register(t14, space0);

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

uint spvPackHalf2x16(float2 value)
{
    uint2 Packed = f32tof16(value);
    return Packed.x | (Packed.y << 16);
}

float2 spvUnpackHalf2x16(uint value)
{
    return f16tof32(uint2(value & 0xffff, value >> 16));
}

void comp_main()
{
    int2 _3335 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3335.x >= cbFI_DisplaySize.x, _3335.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3335] = float4(r_present_backbuffer.Load(int3(_3335, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3335] = float4(r_current_interpolation_source.Load(int3(_3335, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3698 = (float2(_3335) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3709 = int2(floor(_3698 * float2(cbFI_MvDepthLaneSize)));
        int2 _3714 = int2(floor(_3698 * float2(cbFI_FlowLaneSize)));
        float4 _5399 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3698 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5405 = r_warped_filled_flow_tm1.Load(int3(_3714, 0)).xy;
        float2 _5411 = r_warped_filled_motion_tp1.Load(int3(_3709, 0)).xy;
        bool _5433 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8829;
        if (_5433)
        {
            float _5446 = ((2.0f * _3698.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8829 = float2(atan(_5446) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3698.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5446 * _5446))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8829 = _3698;
        }
        bool _3735 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8850;
        bool _8871;
        int2 _8882;
        float3 _9773;
        if (_3735)
        {
            float _8831;
            float _8833;
            _8833 = 2.0f;
            _8831 = -1.0f;
            uint _3399[9];
            float _10157;
            float _10160;
            for (int _8830 = 0; _8830 < 9; _8833 = _10160, _8831 = _10157, _8830++)
            {
                _3399[_8830] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3709 + int2((_8830 % 3) - 1, (_8830 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3399[_8830] != 0u)
                {
                    float _10152;
                    if (_3399[_8830] == 0u)
                    {
                        _10152 = -1.0f;
                    }
                    else
                    {
                        _10152 = float((_3399[_8830] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10160 = min(_8833, _10152);
                    _10157 = max(_8831, _10152);
                }
                else
                {
                    _10160 = _8833;
                    _10157 = _8831;
                }
            }
            float _3781 = float(_8831 >= 0.0f);
            float3 _8644 = 0.0f.xxx;
            _8644.y = _3781;
            float2 _8851;
            bool _8872;
            int2 _8883;
            float3 _9774;
            if ((_8831 - _8833) > 0.0199999995529651641845703125f)
            {
                float _8839;
                int2 _8840;
                float2 _8841;
                int2 _8843;
                float2 _8849;
                _8849 = _5411;
                _8843 = _3709;
                _8841 = _5411;
                _8840 = _3709;
                _8839 = -1.0f;
                float _10165;
                int2 _10169;
                float2 _10180;
                int2 _10191;
                float2 _10224;
                float _10269;
                int _8838 = 0;
                float _10133 = 1000000000.0f;
                for (; _8838 < 9; _10133 = _10269, _8849 = _10224, _8843 = _10191, _8841 = _10180, _8840 = _10169, _8839 = _10165, _8838++)
                {
                    if (_3399[_8838] == 0u)
                    {
                        _10269 = _10133;
                        _10224 = _8849;
                        _10191 = _8843;
                        _10180 = _8841;
                        _10169 = _8840;
                        _10165 = _8839;
                        continue;
                    }
                    int2 _3816 = clamp(_3709 + int2((_8838 % 3) - 1, (_8838 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5521 = _3399[_8838] & 2147483647u;
                    uint _5553 = uint(max((int((_5521 >> 16u) & 15u) - 6), 0));
                    float2 _3822 = (float2(float((1 - (2 * int((_5521 >> 15u) & 1u))) * int(((_5521 >> uint(7)) & 127u) << _5553)), float((1 - (2 * int((_5521 >> 14u) & 1u))) * int((_5521 & 127u) << _5553))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10119;
                    if (_3399[_8838] == 0u)
                    {
                        _10119 = -1.0f;
                    }
                    else
                    {
                        _10119 = float((_3399[_8838] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3827 = _10119 - 0.100000001490116119384765625f;
                    float2 _10120;
                    if (_5433)
                    {
                        float2 _5630 = clamp((((_8829 + (_3822 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5633 = tan(_5630.x);
                        _10120 = (float2(_5633 / cbFI_DeviceToViewDepth.z, (tan(_5630.y) * sqrt(1.0f + (_5633 * _5633))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10120 = _8829 + (_3822 * cbFI_Timestep);
                    }
                    float _3834 = cbFI_Timestep - 1.0f;
                    float2 _10121;
                    if (_5433)
                    {
                        float2 _5701 = clamp((((_8829 + (_3822 * _3834)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5704 = tan(_5701.x);
                        _10121 = (float2(_5704 / cbFI_DeviceToViewDepth.z, (tan(_5701.y) * sqrt(1.0f + (_5704 * _5704))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10121 = _8829 + (_3822 * _3834);
                    }
                    bool _5737 = all(bool2(_10120.x > 0.0f.xx.x, _10120.y > 0.0f.xx.y));
                    bool _5743;
                    if (_5737)
                    {
                        _5743 = all(bool2(_10120.x < 1.0f.xx.x, _10120.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5743 = _5737;
                    }
                    float _10124;
                    if (_5743)
                    {
                        uint _5750_dummy_parameter;
                        _10124 = max((_3827 - (log((r_depth_tm1.Load(int3(int2(floor(_10120 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5750_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10124 = 0.0f;
                    }
                    bool _5780 = all(bool2(_10121.x > 0.0f.xx.x, _10121.y > 0.0f.xx.y));
                    bool _5786;
                    if (_5780)
                    {
                        _5786 = all(bool2(_10121.x < 1.0f.xx.x, _10121.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5786 = _5780;
                    }
                    float _10125;
                    if (_5786)
                    {
                        uint _5793_dummy_parameter;
                        _10125 = _10124 + max((_3827 - (log((r_depth_tp1.Load(int3(int2(floor(_10121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5793_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10125 = _10124;
                    }
                    float _10166;
                    int2 _10170;
                    float2 _10181;
                    int2 _10192;
                    float2 _10225;
                    float _10270;
                    if (_10125 == 0.0f)
                    {
                        bool _3869 = _3827 > _8839;
                        bool2 _10278 = _3869.xx;
                        _10270 = _10133;
                        _10225 = float2(_10278.x ? _3822.x : _8849.x, _10278.y ? _3822.y : _8849.y);
                        _10192 = int2(_10278.x ? _3816.x : _8843.x, _10278.y ? _3816.y : _8843.y);
                        _10181 = _8841;
                        _10170 = _8840;
                        _10166 = _3869 ? _3827 : _8839;
                    }
                    else
                    {
                        bool _3878 = _10125 < _10133;
                        bool2 _10274 = _3878.xx;
                        _10270 = _3878 ? _10125 : _10133;
                        _10225 = _8849;
                        _10192 = _8843;
                        _10181 = float2(_10274.x ? _3822.x : _8841.x, _10274.y ? _3822.y : _8841.y);
                        _10170 = int2(_10274.x ? _3816.x : _8840.x, _10274.y ? _3816.y : _8840.y);
                        _10166 = _8839;
                    }
                    _10269 = _10270;
                    _10224 = _10225;
                    _10191 = _10192;
                    _10180 = _10181;
                    _10169 = _10170;
                    _10165 = _10166;
                }
                bool _3890 = _8839 < 0.0f;
                bool2 _10284 = _3890.xx;
                int2 _10287 = int2(_10284.x ? _8840.x : _8843.x, _10284.y ? _8840.y : _8843.y);
                _9774 = float3(1.0f, _3781, float(any(bool2(_10287.x != _3709.x, _10287.y != _3709.y))));
                _8883 = _10287;
                _8872 = _3890 ? false : true;
                _8851 = float2(_10284.x ? _8841.x : _8849.x, _10284.y ? _8841.y : _8849.y);
            }
            else
            {
                _9774 = _8644;
                _8883 = _3709;
                _8872 = false;
                _8851 = _5411;
            }
            _9773 = _9774;
            _8882 = _8883;
            _8871 = _8872;
            _8850 = _8851;
        }
        else
        {
            _9773 = 0.0f.xxx;
            _8882 = _3709;
            _8871 = false;
            _8850 = _5411;
        }
        float2 _8852;
        if (_5433)
        {
            float2 _5858 = clamp((((_8829 + (_8850 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5861 = tan(_5858.x);
            _8852 = (float2(_5861 / cbFI_DeviceToViewDepth.z, (tan(_5858.y) * sqrt(1.0f + (_5861 * _5861))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8852 = _8829 + (_8850 * cbFI_Timestep);
        }
        float _3913 = cbFI_Timestep - 1.0f;
        float2 _8854;
        if (_5433)
        {
            float2 _5929 = clamp((((_8829 + (_8850 * _3913)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5932 = tan(_5929.x);
            _8854 = (float2(_5932 / cbFI_DeviceToViewDepth.z, (tan(_5929.y) * sqrt(1.0f + (_5932 * _5932))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8854 = _8829 + (_8850 * _3913);
        }
        float _3918 = -cbFI_Timestep;
        float2 _8855;
        if (_5433)
        {
            float2 _6000 = clamp((((_8829 + (_5405 * _3918)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6003 = tan(_6000.x);
            _8855 = (float2(_6003 / cbFI_DeviceToViewDepth.z, (tan(_6000.y) * sqrt(1.0f + (_6003 * _6003))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8855 = _8829 + (_5405 * _3918);
        }
        float _3923 = 1.0f - cbFI_Timestep;
        float2 _8856;
        if (_5433)
        {
            float2 _6071 = clamp((((_8829 + (_5405 * _3923)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6074 = tan(_6071.x);
            _8856 = (float2(_6074 / cbFI_DeviceToViewDepth.z, (tan(_6071.y) * sqrt(1.0f + (_6074 * _6074))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8856 = _8829 + (_5405 * _3923);
        }
        float4 _6109 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8852, 0.0f);
        float3 _6110 = _6109.xyz;
        float4 _6117 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8854, 0.0f);
        float3 _6118 = _6117.xyz;
        float4 _6125 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8855, 0.0f);
        float3 _6126 = _6125.xyz;
        float4 _6133 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8856, 0.0f);
        float3 _6134 = _6133.xyz;
        float4 _6148 = exp(_5399 - max(max(max(_5399.x, _5399.y), _5399.z), _5399.w).xxxx);
        float4 _6155 = _6148 / (dot(_6148, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3942 = _3735 && (!_8871);
        bool _3951;
        if (_3942)
        {
            _3951 = (_6155.z + _6155.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3951 = _3942;
        }
        bool _3962;
        if (_3951)
        {
            _3962 = length((_8855 - _8852) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3962 = _3951;
        }
        bool _8895;
        if (_3962)
        {
            uint4 _6174 = r_warped_motion_qdata_tp1.Load(int3(_8882, 0));
            uint _6175 = _6174.x;
            bool _8898;
            if (_6175 != 0u)
            {
                float _8884;
                if (_6175 == 0u)
                {
                    _8884 = -1.0f;
                }
                else
                {
                    _8884 = float((_6175 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3972 = _8884 - 0.12000000476837158203125f;
                bool _6194 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
                bool _6200;
                if (_6194)
                {
                    _6200 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
                }
                else
                {
                    _6200 = _6194;
                }
                bool _3982;
                if (_6200)
                {
                    uint _6207_dummy_parameter;
                    _3982 = (log((r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6207_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3972;
                }
                else
                {
                    _3982 = _6200;
                }
                bool _3996;
                if (!_3982)
                {
                    bool _6237 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
                    bool _6243;
                    if (_6237)
                    {
                        _6243 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6243 = _6237;
                    }
                    bool _3994;
                    if (_6243)
                    {
                        uint _6250_dummy_parameter;
                        _3994 = (log((r_depth_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6250_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3972;
                    }
                    else
                    {
                        _3994 = _6243;
                    }
                    _3996 = _3994;
                }
                else
                {
                    _3996 = _3982;
                }
                _8898 = _3996;
            }
            else
            {
                _8898 = false;
            }
            _8895 = _8898;
        }
        else
        {
            _8895 = false;
        }
        bool _4001 = _8871 || _8895;
        bool _4006;
        if (_4001)
        {
            bool _6280 = all(bool2(_8852.x > 0.0f.xx.x, _8852.y > 0.0f.xx.y));
            bool _6286;
            if (_6280)
            {
                _6286 = all(bool2(_8852.x < 1.0f.xx.x, _8852.y < 1.0f.xx.y));
            }
            else
            {
                _6286 = _6280;
            }
            _4006 = _6286;
        }
        else
        {
            _4006 = _4001;
        }
        bool _4011;
        if (_4006)
        {
            bool _6291 = all(bool2(_8854.x > 0.0f.xx.x, _8854.y > 0.0f.xx.y));
            bool _6297;
            if (_6291)
            {
                _6297 = all(bool2(_8854.x < 1.0f.xx.x, _8854.y < 1.0f.xx.y));
            }
            else
            {
                _6297 = _6291;
            }
            _4011 = _6297;
        }
        else
        {
            _4011 = _4006;
        }
        float4 _8989;
        if (_4011)
        {
            float _4014 = _6155.x;
            float _4016 = _6155.y;
            float _4017 = _4014 + _4016;
            float _4022 = _6155.z + _6155.w;
            float _8913;
            if (_4017 > 0.001000000047497451305389404296875f)
            {
                _8913 = _4014 / _4017;
            }
            else
            {
                _8913 = _3923;
            }
            _8989 = float4(_4014 + (_4022 * _8913), _4016 + (_4022 * (1.0f - _8913)), 0.0f, 0.0f);
        }
        else
        {
            _8989 = _6155;
        }
        bool _6325 = (cbFI_pad0 & 1024u) != 0u;
        bool _6301 = !_6325;
        bool _6302 = !_6301;
        bool _6319;
        if (_6302)
        {
            _6319 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8882.y * cbFI_MvDepthLaneSize.x) + _8882.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6319 = _6301;
        }
        bool _6351;
        if (_6302)
        {
            _6351 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3714.y * cbFI_FlowLaneSize.x) + _3714.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6351 = _6301;
        }
        float _4057 = float(_6351);
        bool _9001;
        float4 _9031;
        float3 _9633;
        if (_6325)
        {
            bool _4067;
            if (_6319)
            {
                _4067 = all(bool2(_8852.x > 0.0f.xx.x, _8852.y > 0.0f.xx.y));
            }
            else
            {
                _4067 = _6319;
            }
            bool _4073;
            if (_4067)
            {
                _4073 = all(bool2(_8852.x < 1.0f.xx.x, _8852.y < 1.0f.xx.y));
            }
            else
            {
                _4073 = _4067;
            }
            bool _4080;
            if (_6319)
            {
                _4080 = all(bool2(_8854.x > 0.0f.xx.x, _8854.y > 0.0f.xx.y));
            }
            else
            {
                _4080 = _6319;
            }
            bool _4086;
            if (_4080)
            {
                _4086 = all(bool2(_8854.x < 1.0f.xx.x, _8854.y < 1.0f.xx.y));
            }
            else
            {
                _4086 = _4080;
            }
            bool _4093;
            if (_6351)
            {
                _4093 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
            }
            else
            {
                _4093 = _6351;
            }
            bool _4099;
            if (_4093)
            {
                _4099 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
            }
            else
            {
                _4099 = _4093;
            }
            bool _4106;
            if (_6351)
            {
                _4106 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
            }
            else
            {
                _4106 = _6351;
            }
            bool _4112;
            if (_4106)
            {
                _4112 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
            }
            else
            {
                _4112 = _4106;
            }
            bool _4114 = !_6319;
            if (_4114)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6393;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6393);
                }
            }
            bool _4119 = !_6351;
            if (_4119)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6403;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6403);
                }
            }
            if (_6319 && _4119)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6413;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6413);
                }
            }
            if (_4114 && _6351)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6423;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6423);
                }
            }
            float _4138 = float(_4073);
            float _4140 = float(_4086);
            bool _4143 = _4099 && _4112;
            float _8947;
            if (_4143)
            {
                _8947 = 1.0f;
            }
            else
            {
                _8947 = (_4099 || _4112) ? 0.5f : 0.0f;
            }
            bool _8952;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4073)) && (!_4086))
            {
                bool _4173;
                if (_4143)
                {
                    float _8950;
                    do
                    {
                        bool _6507 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
                        bool _6513;
                        if (_6507)
                        {
                            _6513 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6513 = _6507;
                        }
                        bool _6444 = !_6513;
                        bool _6451;
                        if (!_6444)
                        {
                            bool _6518 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
                            bool _6524;
                            if (_6518)
                            {
                                _6524 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6524 = _6518;
                            }
                            _6451 = !_6524;
                        }
                        else
                        {
                            _6451 = _6444;
                        }
                        if (_6451)
                        {
                            _8950 = 0.0f;
                            break;
                        }
                        uint _6531_dummy_parameter;
                        uint _6547_dummy_parameter;
                        float4 _6472 = mul(float4((float2(_8855.x, 1.0f - _8855.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6531_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6474 = _6472.w;
                        if (abs(_6474) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8950 = 0.0f;
                            break;
                        }
                        float _6485 = abs(cbFI_DeviceToViewDepth.y / ((_6472.z / _6474) - cbFI_DeviceToViewDepth.x));
                        float _6488 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6547_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8950 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6485 - _6488) / max(max(_6485, _6488), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4173 = _8950 >= 0.5f;
                }
                else
                {
                    _4173 = _4143;
                }
                bool _8953;
                if (_4173)
                {
                    uint _6597_dummy_parameter;
                    float2 _8951;
                    do
                    {
                        float _6623 = 1.0f - _8855.y;
                        float4 _6634 = mul(float4((float2(_8855.x, _6623) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6597_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6636 = _6634.w;
                        if (!(_6636 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8951 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6649 = ((_6634.xy / _6636.xx) + 1.0f.xx) * 0.5f;
                        _8951 = float2(_6649.x - _8855.x, _6623 - _6649.y);
                        break;
                    } while(false);
                    float2 _4187 = float2(cbFI_DisplaySize);
                    _8953 = length(((_8855 + _8951) - _8856) * _4187) <= ((0.100000001490116119384765625f * length(_8951 * _4187)) + 8.0f);
                }
                else
                {
                    _8953 = _4173;
                }
                _8952 = _8953;
            }
            else
            {
                _8952 = true;
            }
            bool _4201 = !_8952;
            bool _10288 = _4201 ? false : _4112;
            bool _10289 = _4201 ? false : _4099;
            bool _9002;
            float4 _9032;
            if (!(((_4073 && _4086) && _10289) && _10288))
            {
                float4 _4223 = _8989 * float4(_4138, _4140, float(_10289), float(_10288));
                float _4225 = dot(_4223, 1.0f.xxxx);
                bool _4228 = !(_4225 > 0.0f);
                float4 _9033;
                if (!_4228)
                {
                    _9033 = _4223 / _4225.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6671;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6671);
                    }
                    _9033 = 0.0f.xxxx;
                }
                _9032 = _9033;
                _9002 = _4228;
            }
            else
            {
                _9032 = _8989;
                _9002 = false;
            }
            _9633 = float3(_4138, _4140, _8947);
            _9031 = _9032;
            _9001 = _9002;
        }
        else
        {
            _9633 = float3(float(_6319), _4057, 0.0f);
            _9031 = _8989;
            _9001 = false;
        }
        float4 _9503;
        bool _9523;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9001))
        {
            bool _4251 = _9031.x > 0.00999999977648258209228515625f;
            bool _4254 = _9031.y > 0.00999999977648258209228515625f;
            bool _4263 = (_9031.z + _9031.w) > 0.0199999995529651641845703125f;
            bool _4269;
            if (_4263)
            {
                bool _6677 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
                bool _6683;
                if (_6677)
                {
                    _6683 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
                }
                else
                {
                    _6683 = _6677;
                }
                _4269 = _6683;
            }
            else
            {
                _4269 = _4263;
            }
            bool _4274;
            if (_4269)
            {
                bool _6688 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
                bool _6694;
                if (_6688)
                {
                    _6694 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
                }
                else
                {
                    _6694 = _6688;
                }
                _4274 = _6694;
            }
            else
            {
                _4274 = _4269;
            }
            bool _4281;
            if (_4274)
            {
                float _9035;
                do
                {
                    bool _6777 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
                    bool _6783;
                    if (_6777)
                    {
                        _6783 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6783 = _6777;
                    }
                    bool _6714 = !_6783;
                    bool _6721;
                    if (!_6714)
                    {
                        bool _6788 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
                        bool _6794;
                        if (_6788)
                        {
                            _6794 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6794 = _6788;
                        }
                        _6721 = !_6794;
                    }
                    else
                    {
                        _6721 = _6714;
                    }
                    if (_6721)
                    {
                        _9035 = 0.0f;
                        break;
                    }
                    uint _6801_dummy_parameter;
                    uint _6817_dummy_parameter;
                    float4 _6742 = mul(float4((float2(_8855.x, 1.0f - _8855.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6801_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6744 = _6742.w;
                    if (abs(_6744) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9035 = 0.0f;
                        break;
                    }
                    float _6755 = abs(cbFI_DeviceToViewDepth.y / ((_6742.z / _6744) - cbFI_DeviceToViewDepth.x));
                    float _6758 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6817_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9035 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6755 - _6758) / max(max(_6755, _6758), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4281 = _9035 < 0.5f;
            }
            else
            {
                _4281 = _4274;
            }
            float4 _9050;
            if (_4281)
            {
                uint _6867_dummy_parameter;
                uint _6898_dummy_parameter;
                float4 _9051;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6867_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6898_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9051 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9051 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9050 = _9051;
            }
            else
            {
                _9050 = 1.0f.xxxx;
            }
            bool _4305;
            if (_6319)
            {
                bool _6927 = all(bool2(_8852.x > 0.0f.xx.x, _8852.y > 0.0f.xx.y));
                bool _6933;
                if (_6927)
                {
                    _6933 = all(bool2(_8852.x < 1.0f.xx.x, _8852.y < 1.0f.xx.y));
                }
                else
                {
                    _6933 = _6927;
                }
                _4305 = _6933;
            }
            else
            {
                _4305 = _6319;
            }
            bool _4311;
            if (_6319)
            {
                bool _6938 = all(bool2(_8854.x > 0.0f.xx.x, _8854.y > 0.0f.xx.y));
                bool _6944;
                if (_6938)
                {
                    _6944 = all(bool2(_8854.x < 1.0f.xx.x, _8854.y < 1.0f.xx.y));
                }
                else
                {
                    _6944 = _6938;
                }
                _4311 = _6944;
            }
            else
            {
                _4311 = _6319;
            }
            bool _4317;
            if (_6351)
            {
                bool _6949 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
                bool _6955;
                if (_6949)
                {
                    _6955 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
                }
                else
                {
                    _6955 = _6949;
                }
                _4317 = _6955;
            }
            else
            {
                _4317 = _6351;
            }
            bool _4323;
            if (_6351)
            {
                bool _6960 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
                bool _6966;
                if (_6960)
                {
                    _6966 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
                }
                else
                {
                    _6966 = _6960;
                }
                _4323 = _6966;
            }
            else
            {
                _4323 = _6351;
            }
            bool _4326 = _4317 != _4323;
            bool _4332;
            if (_4326)
            {
                _4332 = _4305 || _4311;
            }
            else
            {
                _4332 = _4326;
            }
            float4 _9153;
            if (_4332)
            {
                float4 _8729 = _9050;
                _8729.z = 0.0f;
                _8729.w = 0.0f;
                _9153 = _8729;
            }
            else
            {
                _9153 = _9050;
            }
            bool _4339 = _4305 && _4251;
            bool _4342 = _4311 && _4254;
            float4 _9228;
            if (_4339 || _4342)
            {
                float _9127;
                do
                {
                    uint4 _7105 = r_warped_motion_qdata_tp1.Load(int3(_8882, 0));
                    uint _7106 = _7105.x;
                    if (_7106 != 0u)
                    {
                        float _9126;
                        if (_7106 == 0u)
                        {
                            _9126 = -1.0f;
                        }
                        else
                        {
                            _9126 = float((_7106 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9127 = _9126;
                        break;
                    }
                    int _9109;
                    uint _9110;
                    _9110 = _7106;
                    _9109 = -1;
                    uint _9125;
                    for (; _9109 <= 1; _9110 = _9125, _9109++)
                    {
                        _9125 = _9110;
                        for (int _9123 = -1; _9123 <= 1; )
                        {
                            _9125 = max(_9125, r_warped_motion_qdata_tp1.Load(int3(clamp(_8882 + int2(_9123, _9109), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9123++;
                            continue;
                        }
                    }
                    if (_9110 != 0u)
                    {
                        float _9122;
                        if (_9110 == 0u)
                        {
                            _9122 = -1.0f;
                        }
                        else
                        {
                            _9122 = float((_9110 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9127 = _9122;
                        break;
                    }
                    uint _9112;
                    _9112 = 4294967295u;
                    uint _10261;
                    for (int _9111 = 0; _9111 < 8; _9112 = _10261, _9111++)
                    {
                        int _9115 = 0;
                        for (;;)
                        {
                            if (_9115 < 5)
                            {
                                int2 _7056 = _8882 + (_1093[_9111] * _1102[_9115].xx);
                                bool _7059 = any(bool2(_7056.x < int2(0, 0).x, _7056.y < int2(0, 0).y));
                                bool _7067;
                                if (!_7059)
                                {
                                    _7067 = any(bool2(_7056.x >= cbFI_MvDepthLaneSize.x, _7056.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7067 = _7059;
                                }
                                if (_7067)
                                {
                                    _10261 = _9112;
                                    break;
                                }
                                uint4 _7145 = r_warped_motion_qdata_tp1.Load(int3(_7056, 0));
                                uint _7146 = _7145.x;
                                if (_7146 != 0u)
                                {
                                    _10261 = min(_9112, _7146);
                                    break;
                                }
                                _9115++;
                                continue;
                            }
                            else
                            {
                                _10261 = _9112;
                                break;
                            }
                        }
                    }
                    float _9114;
                    if (_9112 == 4294967295u)
                    {
                        _9114 = -1.0f;
                    }
                    else
                    {
                        float _9113;
                        if (_9112 == 0u)
                        {
                            _9113 = -1.0f;
                        }
                        else
                        {
                            _9113 = float((_9112 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9114 = _9113;
                    }
                    _9127 = _9114;
                    break;
                } while(false);
                float _4353 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4355 = _9127 >= 0.0f;
                float _9134;
                if (_4355)
                {
                    _9134 = _9127 - _4353;
                }
                else
                {
                    float _9130;
                    if (_4339)
                    {
                        float _9129;
                        _9129 = 2.0f;
                        float _7217;
                        for (int _9128 = 0; _9128 < 24; _9129 = _7217, _9128++)
                        {
                            float _7181 = float(_9128 & 7) * 0.785398185253143310546875f;
                            int _7183 = _9128 >> 3;
                            int _9131;
                            if (_7183 == 0)
                            {
                                _9131 = 16;
                            }
                            else
                            {
                                _9131 = (_7183 == 1) ? 48 : 96;
                            }
                            uint _7233_dummy_parameter;
                            _7217 = min(_9129, log((r_depth_tm1.Load(int3(int2(floor(clamp(_8852 + ((cbFI_MvDepthLaneSizeRcp * float(_9131)) * float2(cos(_7181), sin(_7181))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7233_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9130 = _9129;
                    }
                    else
                    {
                        _9130 = 0.0f;
                    }
                    _9134 = _9130;
                }
                float _9141;
                if (_4355)
                {
                    _9141 = _9127 - _4353;
                }
                else
                {
                    float _9137;
                    if (_4342)
                    {
                        float _9136;
                        _9136 = 2.0f;
                        float _7331;
                        for (int _9135 = 0; _9135 < 24; _9136 = _7331, _9135++)
                        {
                            float _7295 = float(_9135 & 7) * 0.785398185253143310546875f;
                            int _7297 = _9135 >> 3;
                            int _9138;
                            if (_7297 == 0)
                            {
                                _9138 = 16;
                            }
                            else
                            {
                                _9138 = (_7297 == 1) ? 48 : 96;
                            }
                            uint _7363_dummy_parameter;
                            _7331 = min(_9136, log((r_depth_tp1.Load(int3(int2(floor(clamp(_8854 + ((cbFI_MvDepthLaneSizeRcp * float(_9138)) * float2(cos(_7295), sin(_7295))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7363_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9137 = _9136;
                    }
                    else
                    {
                        _9137 = 0.0f;
                    }
                    _9141 = _9137;
                }
                float _9142;
                if (_4339)
                {
                    uint _7395_dummy_parameter;
                    _9142 = r_depth_tm1.Load(int3(int2(floor(_8852 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7395_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9142 = 0.0f;
                }
                float _9143;
                if (_4342)
                {
                    uint _7414_dummy_parameter;
                    _9143 = r_depth_tp1.Load(int3(int2(floor(_8854 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7414_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9143 = 0.0f;
                }
                bool _4410;
                if (_4339)
                {
                    _4410 = _9142 > ((exp((_9134 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4410 = _4339;
                }
                float4 _9168;
                if (_4410)
                {
                    float4 _8733 = _9153;
                    _8733.x = 0.0f;
                    _9168 = _8733;
                }
                else
                {
                    _9168 = _9153;
                }
                bool _4422;
                if (_4342)
                {
                    _4422 = _9143 > ((exp((_9141 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4422 = _4342;
                }
                float4 _9170;
                if (_4422)
                {
                    float4 _8735 = _9168;
                    _8735.y = 0.0f;
                    _9170 = _8735;
                }
                else
                {
                    _9170 = _9168;
                }
                float4 _9229;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4355)
                {
                    bool _4442;
                    if (_4339)
                    {
                        _4442 = _9142 < ((exp((_9134 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4442 = _4339;
                    }
                    float4 _9172;
                    if (_4442)
                    {
                        float4 _8737 = _9170;
                        _8737.x = 0.0f;
                        _9172 = _8737;
                    }
                    else
                    {
                        _9172 = _9170;
                    }
                    bool _4454;
                    if (_4342)
                    {
                        _4454 = _9143 < ((exp((_9141 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4454 = _4342;
                    }
                    float4 _9230;
                    if (_4454)
                    {
                        float4 _8739 = _9172;
                        _8739.y = 0.0f;
                        _9230 = _8739;
                    }
                    else
                    {
                        _9230 = _9172;
                    }
                    _9229 = _9230;
                }
                else
                {
                    _9229 = _9170;
                }
                _9228 = _9229;
            }
            else
            {
                _9228 = _9153;
            }
            bool _4465 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4263;
            bool _4471;
            if (_4465)
            {
                _4471 = _4317 || _4323;
            }
            else
            {
                _4471 = _4465;
            }
            float4 _9250;
            if (_4471)
            {
                float _9223;
                do
                {
                    uint4 _7593 = r_warped_motion_qdata_tp1.Load(int3(_8882, 0));
                    uint _7594 = _7593.x;
                    if (_7594 != 0u)
                    {
                        float _9222;
                        if (_7594 == 0u)
                        {
                            _9222 = -1.0f;
                        }
                        else
                        {
                            _9222 = float((_7594 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9223 = _9222;
                        break;
                    }
                    int _9205;
                    uint _9206;
                    _9206 = _7594;
                    _9205 = -1;
                    uint _9221;
                    for (; _9205 <= 1; _9206 = _9221, _9205++)
                    {
                        _9221 = _9206;
                        for (int _9219 = -1; _9219 <= 1; )
                        {
                            _9221 = max(_9221, r_warped_motion_qdata_tp1.Load(int3(clamp(_8882 + int2(_9219, _9205), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9219++;
                            continue;
                        }
                    }
                    if (_9206 != 0u)
                    {
                        float _9218;
                        if (_9206 == 0u)
                        {
                            _9218 = -1.0f;
                        }
                        else
                        {
                            _9218 = float((_9206 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9223 = _9218;
                        break;
                    }
                    uint _9208;
                    _9208 = 4294967295u;
                    uint _10262;
                    for (int _9207 = 0; _9207 < 8; _9208 = _10262, _9207++)
                    {
                        int _9211 = 0;
                        for (;;)
                        {
                            if (_9211 < 5)
                            {
                                int2 _7544 = _8882 + (_1093[_9207] * _1102[_9211].xx);
                                bool _7547 = any(bool2(_7544.x < int2(0, 0).x, _7544.y < int2(0, 0).y));
                                bool _7555;
                                if (!_7547)
                                {
                                    _7555 = any(bool2(_7544.x >= cbFI_MvDepthLaneSize.x, _7544.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7555 = _7547;
                                }
                                if (_7555)
                                {
                                    _10262 = _9208;
                                    break;
                                }
                                uint4 _7633 = r_warped_motion_qdata_tp1.Load(int3(_7544, 0));
                                uint _7634 = _7633.x;
                                if (_7634 != 0u)
                                {
                                    _10262 = min(_9208, _7634);
                                    break;
                                }
                                _9211++;
                                continue;
                            }
                            else
                            {
                                _10262 = _9208;
                                break;
                            }
                        }
                    }
                    float _9210;
                    if (_9208 == 4294967295u)
                    {
                        _9210 = -1.0f;
                    }
                    else
                    {
                        float _9209;
                        if (_9208 == 0u)
                        {
                            _9209 = -1.0f;
                        }
                        else
                        {
                            _9209 = float((_9208 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9210 = _9209;
                    }
                    _9223 = _9210;
                    break;
                } while(false);
                float4 _9251;
                if (_9223 >= 0.0f)
                {
                    float _7655 = (exp((_9223 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4490;
                    if (_4317)
                    {
                        uint _7662_dummy_parameter;
                        _4490 = r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7662_dummy_parameter))))), 0)).x > _7655;
                    }
                    else
                    {
                        _4490 = _4317;
                    }
                    float4 _9241;
                    if (_4490)
                    {
                        float4 _8741 = _9228;
                        _8741.z = 0.0f;
                        _9241 = _8741;
                    }
                    else
                    {
                        _9241 = _9228;
                    }
                    bool _4502;
                    if (_4323)
                    {
                        uint _7681_dummy_parameter;
                        _4502 = r_depth_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7681_dummy_parameter))))), 0)).x > _7655;
                    }
                    else
                    {
                        _4502 = _4323;
                    }
                    float4 _9252;
                    if (_4502)
                    {
                        float4 _8743 = _9241;
                        _8743.w = 0.0f;
                        _9252 = _8743;
                    }
                    else
                    {
                        _9252 = _9241;
                    }
                    _9251 = _9252;
                }
                else
                {
                    _9251 = _9228;
                }
                _9250 = _9251;
            }
            else
            {
                _9250 = _9228;
            }
            bool _4510 = _4305 != _4311;
            bool _4517;
            if (_4510)
            {
                _4517 = _4305 ? _4251 : _4254;
            }
            else
            {
                _4517 = _4510;
            }
            float4 _9330;
            if (_4517)
            {
                bool2 _4522 = _4305.xx;
                float2 _4523 = float2(_4522.x ? _8852.x : _8854.x, _4522.y ? _8852.y : _8854.y);
                float _9243;
                if (_4305)
                {
                    uint _7700_dummy_parameter;
                    _9243 = r_depth_tm1.Load(int3(int2(floor(_4523 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7700_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7716_dummy_parameter;
                    _9243 = r_depth_tp1.Load(int3(int2(floor(_4523 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7716_dummy_parameter))))), 0)).x;
                }
                float4x4 _9244;
                if (_4305)
                {
                    _9244 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9244 = cbFI_MotionTP1ToTM1;
                }
                float2 _9245;
                do
                {
                    float _7743 = _4523.x;
                    float _7746 = 1.0f - _4523.y;
                    float4 _7757 = mul(float4((float2(_7743, _7746) * 2.0f) - 1.0f.xx, _9243, 1.0f), _9244);
                    float _7759 = _7757.w;
                    if (!(_7759 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9245 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7772 = ((_7757.xy / _7759.xx) + 1.0f.xx) * 0.5f;
                    _9245 = float2(_7772.x - _7743, _7746 - _7772.y);
                    break;
                } while(false);
                float2 _4553 = float2(cbFI_DisplaySize);
                float4 _9331;
                if (!(length(((_4523 + _9245) - float2(_4522.x ? _8854.x : _8852.x, _4522.y ? _8854.y : _8852.y)) * _4553) <= ((0.100000001490116119384765625f * length(_9245 * _4553)) + 8.0f)))
                {
                    float4 _9332;
                    if (_4305)
                    {
                        float4 _8753 = _9250;
                        _8753.x = 0.0f;
                        _9332 = _8753;
                    }
                    else
                    {
                        float4 _8755 = _9250;
                        _8755.y = 0.0f;
                        _9332 = _8755;
                    }
                    _9331 = _9332;
                }
                else
                {
                    _9331 = _9250;
                }
                _9330 = _9331;
            }
            else
            {
                _9330 = _9250;
            }
            float4 _4578 = _9031 * _9330;
            float _4580 = dot(_4578, 1.0f.xxxx);
            float4 _9504;
            bool _9524;
            if (_4580 > 0.0f)
            {
                _9524 = _9001;
                _9504 = _4578 / _4580.xxxx;
            }
            else
            {
                bool _4591 = any(bool4(_9330.x < 1.0f.xxxx.x, _9330.y < 1.0f.xxxx.y, _9330.z < 1.0f.xxxx.z, _9330.w < 1.0f.xxxx.w));
                if (_4591)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7794;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7794);
                    }
                }
                bool4 _10291 = _4591.xxxx;
                _9524 = _4591 ? true : _9001;
                _9504 = float4(_10291.x ? 0.0f.xxxx.x : _9031.x, _10291.y ? 0.0f.xxxx.y : _9031.y, _10291.z ? 0.0f.xxxx.z : _9031.z, _10291.w ? 0.0f.xxxx.w : _9031.w);
            }
            _9523 = _9524;
            _9503 = _9504;
        }
        else
        {
            _9523 = _9001;
            _9503 = _9031;
        }
        uint _4600 = (cbFI_pad0 >> 24u) & 31u;
        uint _4604 = (cbFI_pad0 >> 16u) & 255u;
        bool _4606 = _4600 != 0u;
        bool _4608 = _4604 == 12u;
        bool _4611 = _4604 == 13u;
        float4 _9520;
        if ((_4606 || _4608) || _4611)
        {
            float _9333;
            do
            {
                bool _7878 = all(bool2(_8855.x > 0.0f.xx.x, _8855.y > 0.0f.xx.y));
                bool _7884;
                if (_7878)
                {
                    _7884 = all(bool2(_8855.x < 1.0f.xx.x, _8855.y < 1.0f.xx.y));
                }
                else
                {
                    _7884 = _7878;
                }
                bool _7815 = !_7884;
                bool _7822;
                if (!_7815)
                {
                    bool _7889 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
                    bool _7895;
                    if (_7889)
                    {
                        _7895 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7895 = _7889;
                    }
                    _7822 = !_7895;
                }
                else
                {
                    _7822 = _7815;
                }
                if (_7822)
                {
                    _9333 = 0.0f;
                    break;
                }
                uint _7902_dummy_parameter;
                uint _7918_dummy_parameter;
                float4 _7843 = mul(float4((float2(_8855.x, 1.0f - _8855.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8855 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7902_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7845 = _7843.w;
                if (abs(_7845) < 9.9999999747524270787835121154785e-07f)
                {
                    _9333 = 0.0f;
                    break;
                }
                float _7856 = abs(cbFI_DeviceToViewDepth.y / ((_7843.z / _7845) - cbFI_DeviceToViewDepth.x));
                float _7859 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7918_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9333 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7856 - _7859) / max(max(_7856, _7859), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7966 = all(bool2(_8856.x > 0.0f.xx.x, _8856.y > 0.0f.xx.y));
            bool _7972;
            if (_7966)
            {
                _7972 = all(bool2(_8856.x < 1.0f.xx.x, _8856.y < 1.0f.xx.y));
            }
            else
            {
                _7972 = _7966;
            }
            float _9334;
            if (_7972)
            {
                uint _7979_dummy_parameter;
                _9334 = length((_5405 + (r_motion_tp1.Load(int3(int2(floor(_8856 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7979_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9334 = 1000000.0f;
            }
            float _9345;
            if ((_4600 & 1u) != 0u)
            {
                _9345 = _9333;
            }
            else
            {
                _9345 = 1.0f;
            }
            float _9346;
            if ((_4600 & 2u) != 0u)
            {
                _9346 = _9345 * (1.0f - smoothstep(2.0f, 8.0f, _9334));
            }
            else
            {
                _9346 = _9345;
            }
            float _9347;
            if ((_4600 & 4u) != 0u)
            {
                _9347 = _9346 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6126 - _6134) - length(_6110 - _6118))));
            }
            else
            {
                _9347 = _9346;
            }
            float _9514;
            if ((_4600 & 8u) != 0u)
            {
                _9514 = lerp(1.0f, _9347, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6110 - _6118)));
            }
            else
            {
                _9514 = _9347;
            }
            bool _4686 = (_4600 & 16u) != 0u;
            bool _4695;
            if (_4686)
            {
                _4695 = length(_8850 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4695 = _4686;
            }
            float _10293 = _4695 ? 1.0f : _9514;
            bool _4701 = _4606 && _6319;
            bool _4706;
            if (_4701)
            {
                bool _8004 = all(bool2(_8852.x > 0.0f.xx.x, _8852.y > 0.0f.xx.y));
                bool _8010;
                if (_8004)
                {
                    _8010 = all(bool2(_8852.x < 1.0f.xx.x, _8852.y < 1.0f.xx.y));
                }
                else
                {
                    _8010 = _8004;
                }
                _4706 = _8010;
            }
            else
            {
                _4706 = _4701;
            }
            bool _4711;
            if (_4706)
            {
                bool _8015 = all(bool2(_8854.x > 0.0f.xx.x, _8854.y > 0.0f.xx.y));
                bool _8021;
                if (_8015)
                {
                    _8021 = all(bool2(_8854.x < 1.0f.xx.x, _8854.y < 1.0f.xx.y));
                }
                else
                {
                    _8021 = _8015;
                }
                _4711 = _8021;
            }
            else
            {
                _4711 = _4706;
            }
            float4 _9521;
            if (_4711)
            {
                float _4717 = _9503.x + _9503.y;
                float _4726 = (_9503.z + _9503.w) * (1.0f - _10293);
                float _9517;
                if (_4717 > 9.9999997473787516355514526367188e-06f)
                {
                    _9517 = _9503.x / _4717;
                }
                else
                {
                    _9517 = _3923;
                }
                _9521 = float4(_9503.x + (_4726 * _9517), _9503.y + (_4726 * (1.0f - _9517)), _9503.zw * _10293);
            }
            else
            {
                _9521 = _9503;
            }
            _9520 = _9521;
        }
        else
        {
            _9520 = _9503;
        }
        float3 _10066;
        if (_9523)
        {
            float3 _8027 = r_current_interpolation_source.Load(int3(_3335, 0)).xyz;
            float3 _10067;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6319)
            {
                uint _8034_dummy_parameter;
                float _9623;
                _9623 = r_depth_tm1.Load(int3(int2(floor(_8852 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8034_dummy_parameter))))), 0)).x;
                float _4838;
                for (int _9622 = 0; _9622 < 24; _9623 = _4838, _9622++)
                {
                    float _4810 = float(_9622 & 7) * 0.785398185253143310546875f;
                    int _4812 = _9622 >> 3;
                    int _10116;
                    if (_4812 == 0)
                    {
                        _10116 = 16;
                    }
                    else
                    {
                        _10116 = (_4812 == 1) ? 48 : 96;
                    }
                    uint _8054_dummy_parameter;
                    _4838 = min(_9623, r_depth_tm1.Load(int3(int2(floor(clamp(_8852 + ((cbFI_MvDepthLaneSizeRcp * float(_10116)) * float2(cos(_4810), sin(_4810))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8054_dummy_parameter))))), 0)).x);
                }
                float2 _9624;
                do
                {
                    float _8076 = 1.0f - _8852.y;
                    float4 _8087 = mul(float4((float2(_8852.x, _8076) * 2.0f) - 1.0f.xx, _9623, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8089 = _8087.w;
                    if (!(_8089 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9624 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8102 = ((_8087.xy / _8089.xx) + 1.0f.xx) * 0.5f;
                    _9624 = float2(_8102.x - _8852.x, _8076 - _8102.y);
                    break;
                } while(false);
                float2 _4849 = _8852 + _9624;
                bool _8120 = all(bool2(_4849.x > 0.0f.xx.x, _4849.y > 0.0f.xx.y));
                bool _8126;
                if (_8120)
                {
                    _8126 = all(bool2(_4849.x < 1.0f.xx.x, _4849.y < 1.0f.xx.y));
                }
                else
                {
                    _8126 = _8120;
                }
                float3 _10068;
                if (_8126)
                {
                    float _4855 = abs(cbFI_DeviceToViewDepth.y / (_9623 - cbFI_DeviceToViewDepth.x));
                    uint _8146_dummy_parameter;
                    int2 _8146 = int2(spvTextureSize(r_depth_m2, uint(0), _8146_dummy_parameter));
                    float _4859 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4849 * float2(_8146))), int2(0, 0), _8146 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10073;
                    if (abs(_4859 - _4855) <= (0.20000000298023223876953125f * max(_4859, _4855)))
                    {
                        uint _8180_dummy_parameter;
                        int2 _8180 = int2(spvTextureSize(r_colour_m2, uint(0), _8180_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8203;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8203);
                        }
                        _10073 = r_colour_m2.Load(int3(clamp(int2(floor(_4849 * float2(_8180))), int2(0, 0), _8180 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8213;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8213);
                        }
                        _10073 = _8027;
                    }
                    _10068 = _10073;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8223;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8223);
                    }
                    _10068 = _8027;
                }
                _10067 = _10068;
            }
            else
            {
                _10067 = _8027;
            }
            _10066 = _10067;
        }
        else
        {
            _10066 = (((_6110 * _9520.x) + (_6118 * _9520.y)) + (_6126 * _9520.z)) + (_6134 * _9520.w);
        }
        uint _4887 = cbFI_pad0 & 255u;
        bool _9961;
        float3 _10065;
        if (_4887 != 0u)
        {
            float3 _4892 = r_present_backbuffer.Load(int3(_3335, 0)).xyz;
            float3 _4896 = r_current_interpolation_source.Load(int3(_3335, 0)).xyz;
            float3 _4900 = abs(_4892 - _4896);
            float3 _9627;
            if (_4887 == 2u)
            {
                _9627 = (abs(_4896) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9627 = 0.000244140625f.xxx;
            }
            bool _4916 = any(bool3(_4900.x > _9627.x, _4900.y > _9627.y, _4900.z > _9627.z));
            bool3 _10294 = _4916.xxx;
            _10065 = float3(_10294.x ? _4892.x : _10066.x, _10294.y ? _4892.y : _10066.y, _10294.z ? _4892.z : _10066.z);
            _9961 = _4916;
        }
        else
        {
            _10065 = _10066;
            _9961 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8238;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8238);
        }
        float3 _10049;
        if (_4604 == 1u)
        {
            _10049 = lerp(_6110, _6118, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10050;
            if (_4604 == 2u)
            {
                _10050 = lerp(_6126, _6134, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10051;
                if (_4604 == 3u)
                {
                    _10051 = float(_9961).xxx;
                }
                else
                {
                    float3 _10052;
                    if (_4604 == 4u)
                    {
                        _10052 = float3(((_8850 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10053;
                        if (_4604 == 5u)
                        {
                            _10053 = float3(((_5405 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10054;
                            if (_4604 == 6u)
                            {
                                _10054 = float3(_9520.xy, _9520.z + _9520.w);
                            }
                            else
                            {
                                float3 _10055;
                                if (_4604 == 7u)
                                {
                                    _10055 = r_current_interpolation_source.Load(int3(_3335, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10056;
                                    if (_4604 == 8u)
                                    {
                                        _10056 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3698, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10057;
                                        if (_4608)
                                        {
                                            uint _8260_dummy_parameter;
                                            uint _8292_dummy_parameter;
                                            _10057 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3698 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8260_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3698 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8292_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10058;
                                            if (_4611)
                                            {
                                                _10058 = _6126;
                                            }
                                            else
                                            {
                                                float3 _10059;
                                                if (_4604 == 20u)
                                                {
                                                    _10059 = _6110;
                                                }
                                                else
                                                {
                                                    float3 _10060;
                                                    if (_4604 == 21u)
                                                    {
                                                        _10060 = _6118;
                                                    }
                                                    else
                                                    {
                                                        float3 _10061;
                                                        if (_4604 == 22u)
                                                        {
                                                            _10061 = _6134;
                                                        }
                                                        else
                                                        {
                                                            float3 _10062;
                                                            if (_4604 == 18u)
                                                            {
                                                                _10062 = _9773;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10296 = (_4604 == 19u).xxx;
                                                                _10062 = float3(_10296.x ? _9633.x : _10065.x, _10296.y ? _9633.y : _10065.y, _10296.z ? _9633.z : _10065.z);
                                                            }
                                                            _10061 = _10062;
                                                        }
                                                        _10060 = _10061;
                                                    }
                                                    _10059 = _10060;
                                                }
                                                _10058 = _10059;
                                            }
                                            _10057 = _10058;
                                        }
                                        _10056 = _10057;
                                    }
                                    _10055 = _10056;
                                }
                                _10054 = _10055;
                            }
                            _10053 = _10054;
                        }
                        _10052 = _10053;
                    }
                    _10051 = _10052;
                }
                _10050 = _10051;
            }
            _10049 = _10050;
        }
        float3 _10048;
        if ((_4604 >= 9u) && (_4604 <= 11u))
        {
            uint _5074 = 64u + uint((_8882.y * cbFI_MvDepthLaneSize.x) + _8882.x);
            uint _5078 = rw_nfru_diagnostics.Load<uint>(_5074 * 4 + 0) & 15u;
            float3 _10078;
            if (_4604 == 10u)
            {
                float3 _10047;
                if ((rw_nfru_diagnostics.Load<uint>(_5074 * 4 + 0) & 32u) != 0u)
                {
                    _10047 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10046;
                    if ((rw_nfru_diagnostics.Load<uint>(_5074 * 4 + 0) & 16u) != 0u)
                    {
                        _10046 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5099 = ((rw_nfru_diagnostics.Load<uint>(_5074 * 4 + 0) & 64u) != 0u).xxx;
                        _10046 = float3(_5099.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5099.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5099.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10047 = _10046;
                }
                _10078 = _10047;
            }
            else
            {
                float3 _10079;
                if (_4604 == 11u)
                {
                    uint _5112 = (rw_nfru_diagnostics.Load<uint>(_5074 * 4 + 0) >> 8u) & 15u;
                    uint _5115 = (rw_nfru_diagnostics.Load<uint>(_5074 * 4 + 0) >> 12u) & 15u;
                    float3 _10039;
                    if ((_5078 == 2u) || (_5078 == 3u))
                    {
                        _10039 = _3031[_5078];
                    }
                    else
                    {
                        bool _5127 = _5112 == 3u;
                        bool _5129 = _5115 == 3u;
                        float3 _10040;
                        if (_5127 && _5129)
                        {
                            _10040 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10041;
                            if (_5127)
                            {
                                _10041 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10042;
                                if (_5129)
                                {
                                    _10042 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10043;
                                    if ((_5112 == 4u) || (_5115 == 4u))
                                    {
                                        _10043 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10044;
                                        if ((_5112 == 1u) || (_5115 == 1u))
                                        {
                                            _10044 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10298 = (_5078 == 1u).xxx;
                                            _10044 = float3(_10298.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10298.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10298.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10043 = _10044;
                                    }
                                    _10042 = _10043;
                                }
                                _10041 = _10042;
                            }
                            _10040 = _10041;
                        }
                        _10039 = _10040;
                    }
                    _10079 = _10039;
                }
                else
                {
                    _10079 = _3031[min(_5078, 7u)];
                }
                _10078 = _10079;
            }
            _10048 = _10078;
        }
        else
        {
            _10048 = _10049;
        }
        float4 _10082;
        if ((_4604 >= 14u) && (_4604 <= 16u))
        {
            float2 _10080;
            if (_4604 == 14u)
            {
                uint _5185_dummy_parameter;
                uint _5191_dummy_parameter;
                _10080 = r_flow_tm1.Load(int3(clamp(int2(floor(_3698 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5185_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5191_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10081;
                if (_4604 == 16u)
                {
                    uint _8343 = r_warped_flow_qdata_tm1.Load(int3(_3714, 0)).x & 2147483647u;
                    uint _8375 = uint(max((int((_8343 >> 16u) & 15u) - 6), 0));
                    _10081 = ((float2(float((1 - (2 * int((_8343 >> 15u) & 1u))) * int(((_8343 >> uint(7)) & 127u) << _8375)), float((1 - (2 * int((_8343 >> 14u) & 1u))) * int((_8343 & 127u) << _8375))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10081 = _5405 * float2(cbFI_DisplaySize);
                }
                _10080 = _10081;
            }
            uint2 _5224 = uint2(clamp(round(_10080 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5226 = _5224.x;
            uint _5233 = _5224.y;
            _10082 = float4(float(_5226 & 255u), float((_5226 >> 8u) | ((_5233 & 15u) << 4u)), float(_5233 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10083;
            if (_4604 == 17u)
            {
                _10083 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3714, 0)).x != 0u), _4057, 0.0f, 1.0f);
            }
            else
            {
                _10083 = float4(_10048, 1.0f);
            }
            _10082 = _10083;
        }
        rw_output[_3335] = _10082.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5277 = ((uint(_3335.y) * uint(cbFI_DisplaySize.x)) + uint(_3335.x)) * 6u;
            uint _8421 = spvPackHalf2x16(clamp(_6109.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5277 * 4 + 0, (((_8421 & 32767u) >> 4u) | ((((_8421 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6109.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8456 = spvPackHalf2x16(clamp(_6117.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5277 + 1u) * 4 + 0, (((_8456 & 32767u) >> 4u) | ((((_8456 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6117.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8491 = spvPackHalf2x16(clamp(_6125.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5277 + 2u) * 4 + 0, (((_8491 & 32767u) >> 4u) | ((((_8491 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6125.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8526 = spvPackHalf2x16(clamp(_6133.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5277 + 3u) * 4 + 0, (((_8526 & 32767u) >> 4u) | ((((_8526 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6133.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8553 = r_current_interpolation_source.Load(int3(_3335, 0));
            uint _8567 = spvPackHalf2x16(clamp(_8553.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5277 + 4u) * 4 + 0, (((_8567 & 32767u) >> 4u) | ((((_8567 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8553.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10115;
            if (_9961 || (_4604 != 0u))
            {
                _10115 = 4294967295u;
            }
            else
            {
                uint _8602 = spvPackHalf2x16(clamp(_10082.xy, 0.0f.xx, 65000.0f.xx));
                _10115 = (((_8602 & 32767u) >> 4u) | ((((_8602 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10082.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5277 + 5u) * 4 + 0, _10115);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3335] = float4(r_current_interpolation_source.Load(int3(_3335, 0)).xyz, 1.0f).xyz;
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
