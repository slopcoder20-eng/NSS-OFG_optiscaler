static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3032[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3336 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3336.x >= cbFI_DisplaySize.x, _3336.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3336] = float4(r_present_backbuffer.Load(int3(_3336, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3336] = float4(r_current_interpolation_source.Load(int3(_3336, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3699 = (float2(_3336) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3710 = int2(floor(_3699 * float2(cbFI_MvDepthLaneSize)));
        int2 _3715 = int2(floor(_3699 * float2(cbFI_FlowLaneSize)));
        float4 _5400 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3699 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5406 = r_warped_filled_flow_tm1.Load(int3(_3715, 0)).xy;
        float2 _5412 = r_warped_filled_motion_tp1.Load(int3(_3710, 0)).xy;
        bool _5434 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8834;
        if (_5434)
        {
            float _5447 = ((2.0f * _3699.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8834 = float2(atan(_5447) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3699.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5447 * _5447))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8834 = _3699;
        }
        bool _3736 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8855;
        bool _8876;
        int2 _8887;
        float3 _9778;
        if (_3736)
        {
            float _8836;
            float _8838;
            _8838 = 2.0f;
            _8836 = -1.0f;
            uint _3400[9];
            float _10162;
            float _10165;
            for (int _8835 = 0; _8835 < 9; _8838 = _10165, _8836 = _10162, _8835++)
            {
                _3400[_8835] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3710 + int2((_8835 % 3) - 1, (_8835 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3400[_8835] != 0u)
                {
                    float _10157;
                    if (_3400[_8835] == 0u)
                    {
                        _10157 = -1.0f;
                    }
                    else
                    {
                        _10157 = float((_3400[_8835] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10165 = min(_8838, _10157);
                    _10162 = max(_8836, _10157);
                }
                else
                {
                    _10165 = _8838;
                    _10162 = _8836;
                }
            }
            float _3782 = float(_8836 >= 0.0f);
            float3 _8649 = 0.0f.xxx;
            _8649.y = _3782;
            float2 _8856;
            bool _8877;
            int2 _8888;
            float3 _9779;
            if ((_8836 - _8838) > 0.0199999995529651641845703125f)
            {
                float _8844;
                int2 _8845;
                float2 _8846;
                int2 _8848;
                float2 _8854;
                _8854 = _5412;
                _8848 = _3710;
                _8846 = _5412;
                _8845 = _3710;
                _8844 = -1.0f;
                float _10170;
                int2 _10174;
                float2 _10185;
                int2 _10196;
                float2 _10229;
                float _10274;
                int _8843 = 0;
                float _10138 = 1000000000.0f;
                for (; _8843 < 9; _10138 = _10274, _8854 = _10229, _8848 = _10196, _8846 = _10185, _8845 = _10174, _8844 = _10170, _8843++)
                {
                    if (_3400[_8843] == 0u)
                    {
                        _10274 = _10138;
                        _10229 = _8854;
                        _10196 = _8848;
                        _10185 = _8846;
                        _10174 = _8845;
                        _10170 = _8844;
                        continue;
                    }
                    int2 _3817 = clamp(_3710 + int2((_8843 % 3) - 1, (_8843 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5522 = _3400[_8843] & 2147483647u;
                    uint _5554 = uint(max((int((_5522 >> 16u) & 15u) - 6), 0));
                    float2 _3823 = (float2(float((1 - (2 * int((_5522 >> 15u) & 1u))) * int(((_5522 >> uint(7)) & 127u) << _5554)), float((1 - (2 * int((_5522 >> 14u) & 1u))) * int((_5522 & 127u) << _5554))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10124;
                    if (_3400[_8843] == 0u)
                    {
                        _10124 = -1.0f;
                    }
                    else
                    {
                        _10124 = float((_3400[_8843] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3828 = _10124 - 0.100000001490116119384765625f;
                    float2 _10125;
                    if (_5434)
                    {
                        float2 _5631 = clamp((((_8834 + (_3823 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5634 = tan(_5631.x);
                        _10125 = (float2(_5634 / cbFI_DeviceToViewDepth.z, (tan(_5631.y) * sqrt(1.0f + (_5634 * _5634))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10125 = _8834 + (_3823 * cbFI_Timestep);
                    }
                    float _3835 = cbFI_Timestep - 1.0f;
                    float2 _10126;
                    if (_5434)
                    {
                        float2 _5702 = clamp((((_8834 + (_3823 * _3835)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5705 = tan(_5702.x);
                        _10126 = (float2(_5705 / cbFI_DeviceToViewDepth.z, (tan(_5702.y) * sqrt(1.0f + (_5705 * _5705))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10126 = _8834 + (_3823 * _3835);
                    }
                    bool _5738 = all(bool2(_10125.x > 0.0f.xx.x, _10125.y > 0.0f.xx.y));
                    bool _5744;
                    if (_5738)
                    {
                        _5744 = all(bool2(_10125.x < 1.0f.xx.x, _10125.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5744 = _5738;
                    }
                    float _10129;
                    if (_5744)
                    {
                        uint _5751_dummy_parameter;
                        _10129 = max((_3828 - (log(((r_depth_tm1.Load(int3(int2(floor(_10125 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5751_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10129 = 0.0f;
                    }
                    bool _5781 = all(bool2(_10126.x > 0.0f.xx.x, _10126.y > 0.0f.xx.y));
                    bool _5787;
                    if (_5781)
                    {
                        _5787 = all(bool2(_10126.x < 1.0f.xx.x, _10126.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5787 = _5781;
                    }
                    float _10130;
                    if (_5787)
                    {
                        uint _5794_dummy_parameter;
                        _10130 = _10129 + max((_3828 - (log(((r_depth_tp1.Load(int3(int2(floor(_10126 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5794_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10130 = _10129;
                    }
                    float _10171;
                    int2 _10175;
                    float2 _10186;
                    int2 _10197;
                    float2 _10230;
                    float _10275;
                    if (_10130 == 0.0f)
                    {
                        bool _3870 = _3828 > _8844;
                        bool2 _10283 = _3870.xx;
                        _10275 = _10138;
                        _10230 = float2(_10283.x ? _3823.x : _8854.x, _10283.y ? _3823.y : _8854.y);
                        _10197 = int2(_10283.x ? _3817.x : _8848.x, _10283.y ? _3817.y : _8848.y);
                        _10186 = _8846;
                        _10175 = _8845;
                        _10171 = _3870 ? _3828 : _8844;
                    }
                    else
                    {
                        bool _3879 = _10130 < _10138;
                        bool2 _10279 = _3879.xx;
                        _10275 = _3879 ? _10130 : _10138;
                        _10230 = _8854;
                        _10197 = _8848;
                        _10186 = float2(_10279.x ? _3823.x : _8846.x, _10279.y ? _3823.y : _8846.y);
                        _10175 = int2(_10279.x ? _3817.x : _8845.x, _10279.y ? _3817.y : _8845.y);
                        _10171 = _8844;
                    }
                    _10274 = _10275;
                    _10229 = _10230;
                    _10196 = _10197;
                    _10185 = _10186;
                    _10174 = _10175;
                    _10170 = _10171;
                }
                bool _3891 = _8844 < 0.0f;
                bool2 _10289 = _3891.xx;
                int2 _10292 = int2(_10289.x ? _8845.x : _8848.x, _10289.y ? _8845.y : _8848.y);
                _9779 = float3(1.0f, _3782, float(any(bool2(_10292.x != _3710.x, _10292.y != _3710.y))));
                _8888 = _10292;
                _8877 = _3891 ? false : true;
                _8856 = float2(_10289.x ? _8846.x : _8854.x, _10289.y ? _8846.y : _8854.y);
            }
            else
            {
                _9779 = _8649;
                _8888 = _3710;
                _8877 = false;
                _8856 = _5412;
            }
            _9778 = _9779;
            _8887 = _8888;
            _8876 = _8877;
            _8855 = _8856;
        }
        else
        {
            _9778 = 0.0f.xxx;
            _8887 = _3710;
            _8876 = false;
            _8855 = _5412;
        }
        float2 _8857;
        if (_5434)
        {
            float2 _5859 = clamp((((_8834 + (_8855 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5862 = tan(_5859.x);
            _8857 = (float2(_5862 / cbFI_DeviceToViewDepth.z, (tan(_5859.y) * sqrt(1.0f + (_5862 * _5862))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8857 = _8834 + (_8855 * cbFI_Timestep);
        }
        float _3914 = cbFI_Timestep - 1.0f;
        float2 _8859;
        if (_5434)
        {
            float2 _5930 = clamp((((_8834 + (_8855 * _3914)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5933 = tan(_5930.x);
            _8859 = (float2(_5933 / cbFI_DeviceToViewDepth.z, (tan(_5930.y) * sqrt(1.0f + (_5933 * _5933))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8859 = _8834 + (_8855 * _3914);
        }
        float _3919 = -cbFI_Timestep;
        float2 _8860;
        if (_5434)
        {
            float2 _6001 = clamp((((_8834 + (_5406 * _3919)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6004 = tan(_6001.x);
            _8860 = (float2(_6004 / cbFI_DeviceToViewDepth.z, (tan(_6001.y) * sqrt(1.0f + (_6004 * _6004))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8860 = _8834 + (_5406 * _3919);
        }
        float _3924 = 1.0f - cbFI_Timestep;
        float2 _8861;
        if (_5434)
        {
            float2 _6072 = clamp((((_8834 + (_5406 * _3924)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6075 = tan(_6072.x);
            _8861 = (float2(_6075 / cbFI_DeviceToViewDepth.z, (tan(_6072.y) * sqrt(1.0f + (_6075 * _6075))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8861 = _8834 + (_5406 * _3924);
        }
        float4 _6110 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8857, 0.0f);
        float3 _6111 = _6110.xyz;
        float4 _6118 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8859, 0.0f);
        float3 _6119 = _6118.xyz;
        float4 _6126 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8860, 0.0f);
        float3 _6127 = _6126.xyz;
        float4 _6134 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8861, 0.0f);
        float3 _6135 = _6134.xyz;
        float4 _6149 = exp(_5400 - max(max(max(_5400.x, _5400.y), _5400.z), _5400.w).xxxx);
        float4 _6156 = _6149 / (dot(_6149, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3943 = _3736 && (!_8876);
        bool _3952;
        if (_3943)
        {
            _3952 = (_6156.z + _6156.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3952 = _3943;
        }
        bool _3963;
        if (_3952)
        {
            _3963 = length((_8860 - _8857) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3963 = _3952;
        }
        bool _8900;
        if (_3963)
        {
            uint4 _6175 = r_warped_motion_qdata_tp1.Load(int3(_8887, 0));
            uint _6176 = _6175.x;
            bool _8903;
            if (_6176 != 0u)
            {
                float _8889;
                if (_6176 == 0u)
                {
                    _8889 = -1.0f;
                }
                else
                {
                    _8889 = float((_6176 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3973 = _8889 - 0.12000000476837158203125f;
                bool _6195 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
                bool _6201;
                if (_6195)
                {
                    _6201 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
                }
                else
                {
                    _6201 = _6195;
                }
                bool _3983;
                if (_6201)
                {
                    uint _6208_dummy_parameter;
                    _3983 = (log(((r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6208_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3973;
                }
                else
                {
                    _3983 = _6201;
                }
                bool _3997;
                if (!_3983)
                {
                    bool _6238 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
                    bool _6244;
                    if (_6238)
                    {
                        _6244 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6244 = _6238;
                    }
                    bool _3995;
                    if (_6244)
                    {
                        uint _6251_dummy_parameter;
                        _3995 = (log(((r_depth_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6251_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3973;
                    }
                    else
                    {
                        _3995 = _6244;
                    }
                    _3997 = _3995;
                }
                else
                {
                    _3997 = _3983;
                }
                _8903 = _3997;
            }
            else
            {
                _8903 = false;
            }
            _8900 = _8903;
        }
        else
        {
            _8900 = false;
        }
        bool _4002 = _8876 || _8900;
        bool _4007;
        if (_4002)
        {
            bool _6281 = all(bool2(_8857.x > 0.0f.xx.x, _8857.y > 0.0f.xx.y));
            bool _6287;
            if (_6281)
            {
                _6287 = all(bool2(_8857.x < 1.0f.xx.x, _8857.y < 1.0f.xx.y));
            }
            else
            {
                _6287 = _6281;
            }
            _4007 = _6287;
        }
        else
        {
            _4007 = _4002;
        }
        bool _4012;
        if (_4007)
        {
            bool _6292 = all(bool2(_8859.x > 0.0f.xx.x, _8859.y > 0.0f.xx.y));
            bool _6298;
            if (_6292)
            {
                _6298 = all(bool2(_8859.x < 1.0f.xx.x, _8859.y < 1.0f.xx.y));
            }
            else
            {
                _6298 = _6292;
            }
            _4012 = _6298;
        }
        else
        {
            _4012 = _4007;
        }
        float4 _8994;
        if (_4012)
        {
            float _4015 = _6156.x;
            float _4017 = _6156.y;
            float _4018 = _4015 + _4017;
            float _4023 = _6156.z + _6156.w;
            float _8918;
            if (_4018 > 0.001000000047497451305389404296875f)
            {
                _8918 = _4015 / _4018;
            }
            else
            {
                _8918 = _3924;
            }
            _8994 = float4(_4015 + (_4023 * _8918), _4017 + (_4023 * (1.0f - _8918)), 0.0f, 0.0f);
        }
        else
        {
            _8994 = _6156;
        }
        bool _6326 = (cbFI_pad0 & 1024u) != 0u;
        bool _6302 = !_6326;
        bool _6303 = !_6302;
        bool _6320;
        if (_6303)
        {
            _6320 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8887.y * cbFI_MvDepthLaneSize.x) + _8887.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6320 = _6302;
        }
        bool _6352;
        if (_6303)
        {
            _6352 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3715.y * cbFI_FlowLaneSize.x) + _3715.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6352 = _6302;
        }
        float _4058 = float(_6352);
        bool _9006;
        float4 _9036;
        float3 _9638;
        if (_6326)
        {
            bool _4068;
            if (_6320)
            {
                _4068 = all(bool2(_8857.x > 0.0f.xx.x, _8857.y > 0.0f.xx.y));
            }
            else
            {
                _4068 = _6320;
            }
            bool _4074;
            if (_4068)
            {
                _4074 = all(bool2(_8857.x < 1.0f.xx.x, _8857.y < 1.0f.xx.y));
            }
            else
            {
                _4074 = _4068;
            }
            bool _4081;
            if (_6320)
            {
                _4081 = all(bool2(_8859.x > 0.0f.xx.x, _8859.y > 0.0f.xx.y));
            }
            else
            {
                _4081 = _6320;
            }
            bool _4087;
            if (_4081)
            {
                _4087 = all(bool2(_8859.x < 1.0f.xx.x, _8859.y < 1.0f.xx.y));
            }
            else
            {
                _4087 = _4081;
            }
            bool _4094;
            if (_6352)
            {
                _4094 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
            }
            else
            {
                _4094 = _6352;
            }
            bool _4100;
            if (_4094)
            {
                _4100 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
            }
            else
            {
                _4100 = _4094;
            }
            bool _4107;
            if (_6352)
            {
                _4107 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
            }
            else
            {
                _4107 = _6352;
            }
            bool _4113;
            if (_4107)
            {
                _4113 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
            }
            else
            {
                _4113 = _4107;
            }
            bool _4115 = !_6320;
            if (_4115)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6394;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6394);
                }
            }
            bool _4120 = !_6352;
            if (_4120)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6404;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6404);
                }
            }
            if (_6320 && _4120)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6414;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6414);
                }
            }
            if (_4115 && _6352)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6424;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6424);
                }
            }
            float _4139 = float(_4074);
            float _4141 = float(_4087);
            bool _4144 = _4100 && _4113;
            float _8952;
            if (_4144)
            {
                _8952 = 1.0f;
            }
            else
            {
                _8952 = (_4100 || _4113) ? 0.5f : 0.0f;
            }
            bool _8957;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4074)) && (!_4087))
            {
                bool _4174;
                if (_4144)
                {
                    float _8955;
                    do
                    {
                        bool _6508 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
                        bool _6514;
                        if (_6508)
                        {
                            _6514 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6514 = _6508;
                        }
                        bool _6445 = !_6514;
                        bool _6452;
                        if (!_6445)
                        {
                            bool _6519 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
                            bool _6525;
                            if (_6519)
                            {
                                _6525 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6525 = _6519;
                            }
                            _6452 = !_6525;
                        }
                        else
                        {
                            _6452 = _6445;
                        }
                        if (_6452)
                        {
                            _8955 = 0.0f;
                            break;
                        }
                        uint _6532_dummy_parameter;
                        uint _6548_dummy_parameter;
                        float4 _6473 = mul(float4((float2(_8860.x, 1.0f - _8860.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6532_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6475 = _6473.w;
                        if (abs(_6475) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8955 = 0.0f;
                            break;
                        }
                        float _6486 = abs(cbFI_DeviceToViewDepth.y / ((_6473.z / _6475) - cbFI_DeviceToViewDepth.x));
                        float _6489 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6548_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8955 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6486 - _6489) / max(max(_6486, _6489), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4174 = _8955 >= 0.5f;
                }
                else
                {
                    _4174 = _4144;
                }
                bool _8958;
                if (_4174)
                {
                    uint _6598_dummy_parameter;
                    float2 _8956;
                    do
                    {
                        float _6624 = 1.0f - _8860.y;
                        float4 _6635 = mul(float4((float2(_8860.x, _6624) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6598_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6637 = _6635.w;
                        if (!(_6637 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8956 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6650 = ((_6635.xy / _6637.xx) + 1.0f.xx) * 0.5f;
                        _8956 = float2(_6650.x - _8860.x, _6624 - _6650.y);
                        break;
                    } while(false);
                    float2 _4188 = float2(cbFI_DisplaySize);
                    _8958 = length(((_8860 + _8956) - _8861) * _4188) <= ((0.100000001490116119384765625f * length(_8956 * _4188)) + 8.0f);
                }
                else
                {
                    _8958 = _4174;
                }
                _8957 = _8958;
            }
            else
            {
                _8957 = true;
            }
            bool _4202 = !_8957;
            bool _10293 = _4202 ? false : _4113;
            bool _10294 = _4202 ? false : _4100;
            bool _9007;
            float4 _9037;
            if (!(((_4074 && _4087) && _10294) && _10293))
            {
                float4 _4224 = _8994 * float4(_4139, _4141, float(_10294), float(_10293));
                float _4226 = dot(_4224, 1.0f.xxxx);
                bool _4229 = !(_4226 > 0.0f);
                float4 _9038;
                if (!_4229)
                {
                    _9038 = _4224 / _4226.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6672;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6672);
                    }
                    _9038 = 0.0f.xxxx;
                }
                _9037 = _9038;
                _9007 = _4229;
            }
            else
            {
                _9037 = _8994;
                _9007 = false;
            }
            _9638 = float3(_4139, _4141, _8952);
            _9036 = _9037;
            _9006 = _9007;
        }
        else
        {
            _9638 = float3(float(_6320), _4058, 0.0f);
            _9036 = _8994;
            _9006 = false;
        }
        float4 _9508;
        bool _9528;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9006))
        {
            bool _4252 = _9036.x > 0.00999999977648258209228515625f;
            bool _4255 = _9036.y > 0.00999999977648258209228515625f;
            bool _4264 = (_9036.z + _9036.w) > 0.0199999995529651641845703125f;
            bool _4270;
            if (_4264)
            {
                bool _6678 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
                bool _6684;
                if (_6678)
                {
                    _6684 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
                }
                else
                {
                    _6684 = _6678;
                }
                _4270 = _6684;
            }
            else
            {
                _4270 = _4264;
            }
            bool _4275;
            if (_4270)
            {
                bool _6689 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
                bool _6695;
                if (_6689)
                {
                    _6695 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
                }
                else
                {
                    _6695 = _6689;
                }
                _4275 = _6695;
            }
            else
            {
                _4275 = _4270;
            }
            bool _4282;
            if (_4275)
            {
                float _9040;
                do
                {
                    bool _6778 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
                    bool _6784;
                    if (_6778)
                    {
                        _6784 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6784 = _6778;
                    }
                    bool _6715 = !_6784;
                    bool _6722;
                    if (!_6715)
                    {
                        bool _6789 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
                        bool _6795;
                        if (_6789)
                        {
                            _6795 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6795 = _6789;
                        }
                        _6722 = !_6795;
                    }
                    else
                    {
                        _6722 = _6715;
                    }
                    if (_6722)
                    {
                        _9040 = 0.0f;
                        break;
                    }
                    uint _6802_dummy_parameter;
                    uint _6818_dummy_parameter;
                    float4 _6743 = mul(float4((float2(_8860.x, 1.0f - _8860.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6802_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6745 = _6743.w;
                    if (abs(_6745) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9040 = 0.0f;
                        break;
                    }
                    float _6756 = abs(cbFI_DeviceToViewDepth.y / ((_6743.z / _6745) - cbFI_DeviceToViewDepth.x));
                    float _6759 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6818_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9040 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6756 - _6759) / max(max(_6756, _6759), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4282 = _9040 < 0.5f;
            }
            else
            {
                _4282 = _4275;
            }
            float4 _9055;
            if (_4282)
            {
                uint _6868_dummy_parameter;
                uint _6899_dummy_parameter;
                float4 _9056;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6868_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6899_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9056 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9056 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9055 = _9056;
            }
            else
            {
                _9055 = 1.0f.xxxx;
            }
            bool _4306;
            if (_6320)
            {
                bool _6928 = all(bool2(_8857.x > 0.0f.xx.x, _8857.y > 0.0f.xx.y));
                bool _6934;
                if (_6928)
                {
                    _6934 = all(bool2(_8857.x < 1.0f.xx.x, _8857.y < 1.0f.xx.y));
                }
                else
                {
                    _6934 = _6928;
                }
                _4306 = _6934;
            }
            else
            {
                _4306 = _6320;
            }
            bool _4312;
            if (_6320)
            {
                bool _6939 = all(bool2(_8859.x > 0.0f.xx.x, _8859.y > 0.0f.xx.y));
                bool _6945;
                if (_6939)
                {
                    _6945 = all(bool2(_8859.x < 1.0f.xx.x, _8859.y < 1.0f.xx.y));
                }
                else
                {
                    _6945 = _6939;
                }
                _4312 = _6945;
            }
            else
            {
                _4312 = _6320;
            }
            bool _4318;
            if (_6352)
            {
                bool _6950 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
                bool _6956;
                if (_6950)
                {
                    _6956 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
                }
                else
                {
                    _6956 = _6950;
                }
                _4318 = _6956;
            }
            else
            {
                _4318 = _6352;
            }
            bool _4324;
            if (_6352)
            {
                bool _6961 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
                bool _6967;
                if (_6961)
                {
                    _6967 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
                }
                else
                {
                    _6967 = _6961;
                }
                _4324 = _6967;
            }
            else
            {
                _4324 = _6352;
            }
            bool _4327 = _4318 != _4324;
            bool _4333;
            if (_4327)
            {
                _4333 = _4306 || _4312;
            }
            else
            {
                _4333 = _4327;
            }
            float4 _9158;
            if (_4333)
            {
                float4 _8734 = _9055;
                _8734.z = 0.0f;
                _8734.w = 0.0f;
                _9158 = _8734;
            }
            else
            {
                _9158 = _9055;
            }
            bool _4340 = _4306 && _4252;
            bool _4343 = _4312 && _4255;
            float4 _9233;
            if (_4340 || _4343)
            {
                float _9132;
                do
                {
                    uint4 _7106 = r_warped_motion_qdata_tp1.Load(int3(_8887, 0));
                    uint _7107 = _7106.x;
                    if (_7107 != 0u)
                    {
                        float _9131;
                        if (_7107 == 0u)
                        {
                            _9131 = -1.0f;
                        }
                        else
                        {
                            _9131 = float((_7107 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9132 = _9131;
                        break;
                    }
                    int _9114;
                    uint _9115;
                    _9115 = _7107;
                    _9114 = -1;
                    uint _9130;
                    for (; _9114 <= 1; _9115 = _9130, _9114++)
                    {
                        _9130 = _9115;
                        for (int _9128 = -1; _9128 <= 1; )
                        {
                            _9130 = max(_9130, r_warped_motion_qdata_tp1.Load(int3(clamp(_8887 + int2(_9128, _9114), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9128++;
                            continue;
                        }
                    }
                    if (_9115 != 0u)
                    {
                        float _9127;
                        if (_9115 == 0u)
                        {
                            _9127 = -1.0f;
                        }
                        else
                        {
                            _9127 = float((_9115 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9132 = _9127;
                        break;
                    }
                    uint _9117;
                    _9117 = 4294967295u;
                    uint _10266;
                    for (int _9116 = 0; _9116 < 8; _9117 = _10266, _9116++)
                    {
                        int _9120 = 0;
                        for (;;)
                        {
                            if (_9120 < 5)
                            {
                                int2 _7057 = _8887 + (_1093[_9116] * _1102[_9120].xx);
                                bool _7060 = any(bool2(_7057.x < int2(0, 0).x, _7057.y < int2(0, 0).y));
                                bool _7068;
                                if (!_7060)
                                {
                                    _7068 = any(bool2(_7057.x >= cbFI_MvDepthLaneSize.x, _7057.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7068 = _7060;
                                }
                                if (_7068)
                                {
                                    _10266 = _9117;
                                    break;
                                }
                                uint4 _7146 = r_warped_motion_qdata_tp1.Load(int3(_7057, 0));
                                uint _7147 = _7146.x;
                                if (_7147 != 0u)
                                {
                                    _10266 = min(_9117, _7147);
                                    break;
                                }
                                _9120++;
                                continue;
                            }
                            else
                            {
                                _10266 = _9117;
                                break;
                            }
                        }
                    }
                    float _9119;
                    if (_9117 == 4294967295u)
                    {
                        _9119 = -1.0f;
                    }
                    else
                    {
                        float _9118;
                        if (_9117 == 0u)
                        {
                            _9118 = -1.0f;
                        }
                        else
                        {
                            _9118 = float((_9117 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9119 = _9118;
                    }
                    _9132 = _9119;
                    break;
                } while(false);
                float _4354 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4356 = _9132 >= 0.0f;
                float _9139;
                if (_4356)
                {
                    _9139 = _9132 - _4354;
                }
                else
                {
                    float _9135;
                    if (_4340)
                    {
                        float _9134;
                        _9134 = 2.0f;
                        float _7218;
                        for (int _9133 = 0; _9133 < 24; _9134 = _7218, _9133++)
                        {
                            float _7182 = float(_9133 & 7) * 0.785398185253143310546875f;
                            int _7184 = _9133 >> 3;
                            int _9136;
                            if (_7184 == 0)
                            {
                                _9136 = 16;
                            }
                            else
                            {
                                _9136 = (_7184 == 1) ? 48 : 96;
                            }
                            uint _7234_dummy_parameter;
                            _7218 = min(_9134, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_8857 + ((cbFI_MvDepthLaneSizeRcp * float(_9136)) * float2(cos(_7182), sin(_7182))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7234_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9135 = _9134;
                    }
                    else
                    {
                        _9135 = 0.0f;
                    }
                    _9139 = _9135;
                }
                float _9146;
                if (_4356)
                {
                    _9146 = _9132 - _4354;
                }
                else
                {
                    float _9142;
                    if (_4343)
                    {
                        float _9141;
                        _9141 = 2.0f;
                        float _7332;
                        for (int _9140 = 0; _9140 < 24; _9141 = _7332, _9140++)
                        {
                            float _7296 = float(_9140 & 7) * 0.785398185253143310546875f;
                            int _7298 = _9140 >> 3;
                            int _9143;
                            if (_7298 == 0)
                            {
                                _9143 = 16;
                            }
                            else
                            {
                                _9143 = (_7298 == 1) ? 48 : 96;
                            }
                            uint _7364_dummy_parameter;
                            _7332 = min(_9141, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_8859 + ((cbFI_MvDepthLaneSizeRcp * float(_9143)) * float2(cos(_7296), sin(_7296))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7364_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9142 = _9141;
                    }
                    else
                    {
                        _9142 = 0.0f;
                    }
                    _9146 = _9142;
                }
                float _9147;
                if (_4340)
                {
                    uint _7396_dummy_parameter;
                    _9147 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_8857 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7396_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9147 = 0.0f;
                }
                float _9148;
                if (_4343)
                {
                    uint _7416_dummy_parameter;
                    _9148 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_8859 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7416_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9148 = 0.0f;
                }
                bool _4411;
                if (_4340)
                {
                    _4411 = _9147 > ((exp((_9139 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4411 = _4340;
                }
                float4 _9173;
                if (_4411)
                {
                    float4 _8738 = _9158;
                    _8738.x = 0.0f;
                    _9173 = _8738;
                }
                else
                {
                    _9173 = _9158;
                }
                bool _4423;
                if (_4343)
                {
                    _4423 = _9148 > ((exp((_9146 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4423 = _4343;
                }
                float4 _9175;
                if (_4423)
                {
                    float4 _8740 = _9173;
                    _8740.y = 0.0f;
                    _9175 = _8740;
                }
                else
                {
                    _9175 = _9173;
                }
                float4 _9234;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4356)
                {
                    bool _4443;
                    if (_4340)
                    {
                        _4443 = _9147 < ((exp((_9139 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4443 = _4340;
                    }
                    float4 _9177;
                    if (_4443)
                    {
                        float4 _8742 = _9175;
                        _8742.x = 0.0f;
                        _9177 = _8742;
                    }
                    else
                    {
                        _9177 = _9175;
                    }
                    bool _4455;
                    if (_4343)
                    {
                        _4455 = _9148 < ((exp((_9146 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4455 = _4343;
                    }
                    float4 _9235;
                    if (_4455)
                    {
                        float4 _8744 = _9177;
                        _8744.y = 0.0f;
                        _9235 = _8744;
                    }
                    else
                    {
                        _9235 = _9177;
                    }
                    _9234 = _9235;
                }
                else
                {
                    _9234 = _9175;
                }
                _9233 = _9234;
            }
            else
            {
                _9233 = _9158;
            }
            bool _4466 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4264;
            bool _4472;
            if (_4466)
            {
                _4472 = _4318 || _4324;
            }
            else
            {
                _4472 = _4466;
            }
            float4 _9255;
            if (_4472)
            {
                float _9228;
                do
                {
                    uint4 _7596 = r_warped_motion_qdata_tp1.Load(int3(_8887, 0));
                    uint _7597 = _7596.x;
                    if (_7597 != 0u)
                    {
                        float _9227;
                        if (_7597 == 0u)
                        {
                            _9227 = -1.0f;
                        }
                        else
                        {
                            _9227 = float((_7597 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9228 = _9227;
                        break;
                    }
                    int _9210;
                    uint _9211;
                    _9211 = _7597;
                    _9210 = -1;
                    uint _9226;
                    for (; _9210 <= 1; _9211 = _9226, _9210++)
                    {
                        _9226 = _9211;
                        for (int _9224 = -1; _9224 <= 1; )
                        {
                            _9226 = max(_9226, r_warped_motion_qdata_tp1.Load(int3(clamp(_8887 + int2(_9224, _9210), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9224++;
                            continue;
                        }
                    }
                    if (_9211 != 0u)
                    {
                        float _9223;
                        if (_9211 == 0u)
                        {
                            _9223 = -1.0f;
                        }
                        else
                        {
                            _9223 = float((_9211 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9228 = _9223;
                        break;
                    }
                    uint _9213;
                    _9213 = 4294967295u;
                    uint _10267;
                    for (int _9212 = 0; _9212 < 8; _9213 = _10267, _9212++)
                    {
                        int _9216 = 0;
                        for (;;)
                        {
                            if (_9216 < 5)
                            {
                                int2 _7547 = _8887 + (_1093[_9212] * _1102[_9216].xx);
                                bool _7550 = any(bool2(_7547.x < int2(0, 0).x, _7547.y < int2(0, 0).y));
                                bool _7558;
                                if (!_7550)
                                {
                                    _7558 = any(bool2(_7547.x >= cbFI_MvDepthLaneSize.x, _7547.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7558 = _7550;
                                }
                                if (_7558)
                                {
                                    _10267 = _9213;
                                    break;
                                }
                                uint4 _7636 = r_warped_motion_qdata_tp1.Load(int3(_7547, 0));
                                uint _7637 = _7636.x;
                                if (_7637 != 0u)
                                {
                                    _10267 = min(_9213, _7637);
                                    break;
                                }
                                _9216++;
                                continue;
                            }
                            else
                            {
                                _10267 = _9213;
                                break;
                            }
                        }
                    }
                    float _9215;
                    if (_9213 == 4294967295u)
                    {
                        _9215 = -1.0f;
                    }
                    else
                    {
                        float _9214;
                        if (_9213 == 0u)
                        {
                            _9214 = -1.0f;
                        }
                        else
                        {
                            _9214 = float((_9213 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9215 = _9214;
                    }
                    _9228 = _9215;
                    break;
                } while(false);
                float4 _9256;
                if (_9228 >= 0.0f)
                {
                    float _7658 = (exp((_9228 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4491;
                    if (_4318)
                    {
                        uint _7665_dummy_parameter;
                        _4491 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7665_dummy_parameter))))), 0)).x) > _7658;
                    }
                    else
                    {
                        _4491 = _4318;
                    }
                    float4 _9246;
                    if (_4491)
                    {
                        float4 _8746 = _9233;
                        _8746.z = 0.0f;
                        _9246 = _8746;
                    }
                    else
                    {
                        _9246 = _9233;
                    }
                    bool _4503;
                    if (_4324)
                    {
                        uint _7685_dummy_parameter;
                        _4503 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7685_dummy_parameter))))), 0)).x) > _7658;
                    }
                    else
                    {
                        _4503 = _4324;
                    }
                    float4 _9257;
                    if (_4503)
                    {
                        float4 _8748 = _9246;
                        _8748.w = 0.0f;
                        _9257 = _8748;
                    }
                    else
                    {
                        _9257 = _9246;
                    }
                    _9256 = _9257;
                }
                else
                {
                    _9256 = _9233;
                }
                _9255 = _9256;
            }
            else
            {
                _9255 = _9233;
            }
            bool _4511 = _4306 != _4312;
            bool _4518;
            if (_4511)
            {
                _4518 = _4306 ? _4252 : _4255;
            }
            else
            {
                _4518 = _4511;
            }
            float4 _9335;
            if (_4518)
            {
                bool2 _4523 = _4306.xx;
                float2 _4524 = float2(_4523.x ? _8857.x : _8859.x, _4523.y ? _8857.y : _8859.y);
                float _9248;
                if (_4306)
                {
                    uint _7705_dummy_parameter;
                    _9248 = r_depth_tm1.Load(int3(int2(floor(_4524 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7705_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7721_dummy_parameter;
                    _9248 = r_depth_tp1.Load(int3(int2(floor(_4524 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7721_dummy_parameter))))), 0)).x;
                }
                float4x4 _9249;
                if (_4306)
                {
                    _9249 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9249 = cbFI_MotionTP1ToTM1;
                }
                float2 _9250;
                do
                {
                    float _7748 = _4524.x;
                    float _7751 = 1.0f - _4524.y;
                    float4 _7762 = mul(float4((float2(_7748, _7751) * 2.0f) - 1.0f.xx, _9248, 1.0f), _9249);
                    float _7764 = _7762.w;
                    if (!(_7764 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9250 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7777 = ((_7762.xy / _7764.xx) + 1.0f.xx) * 0.5f;
                    _9250 = float2(_7777.x - _7748, _7751 - _7777.y);
                    break;
                } while(false);
                float2 _4554 = float2(cbFI_DisplaySize);
                float4 _9336;
                if (!(length(((_4524 + _9250) - float2(_4523.x ? _8859.x : _8857.x, _4523.y ? _8859.y : _8857.y)) * _4554) <= ((0.100000001490116119384765625f * length(_9250 * _4554)) + 8.0f)))
                {
                    float4 _9337;
                    if (_4306)
                    {
                        float4 _8758 = _9255;
                        _8758.x = 0.0f;
                        _9337 = _8758;
                    }
                    else
                    {
                        float4 _8760 = _9255;
                        _8760.y = 0.0f;
                        _9337 = _8760;
                    }
                    _9336 = _9337;
                }
                else
                {
                    _9336 = _9255;
                }
                _9335 = _9336;
            }
            else
            {
                _9335 = _9255;
            }
            float4 _4579 = _9036 * _9335;
            float _4581 = dot(_4579, 1.0f.xxxx);
            float4 _9509;
            bool _9529;
            if (_4581 > 0.0f)
            {
                _9529 = _9006;
                _9509 = _4579 / _4581.xxxx;
            }
            else
            {
                bool _4592 = any(bool4(_9335.x < 1.0f.xxxx.x, _9335.y < 1.0f.xxxx.y, _9335.z < 1.0f.xxxx.z, _9335.w < 1.0f.xxxx.w));
                if (_4592)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7799;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7799);
                    }
                }
                bool4 _10296 = _4592.xxxx;
                _9529 = _4592 ? true : _9006;
                _9509 = float4(_10296.x ? 0.0f.xxxx.x : _9036.x, _10296.y ? 0.0f.xxxx.y : _9036.y, _10296.z ? 0.0f.xxxx.z : _9036.z, _10296.w ? 0.0f.xxxx.w : _9036.w);
            }
            _9528 = _9529;
            _9508 = _9509;
        }
        else
        {
            _9528 = _9006;
            _9508 = _9036;
        }
        uint _4601 = (cbFI_pad0 >> 24u) & 31u;
        uint _4605 = (cbFI_pad0 >> 16u) & 255u;
        bool _4607 = _4601 != 0u;
        bool _4609 = _4605 == 12u;
        bool _4612 = _4605 == 13u;
        float4 _9525;
        if ((_4607 || _4609) || _4612)
        {
            float _9338;
            do
            {
                bool _7883 = all(bool2(_8860.x > 0.0f.xx.x, _8860.y > 0.0f.xx.y));
                bool _7889;
                if (_7883)
                {
                    _7889 = all(bool2(_8860.x < 1.0f.xx.x, _8860.y < 1.0f.xx.y));
                }
                else
                {
                    _7889 = _7883;
                }
                bool _7820 = !_7889;
                bool _7827;
                if (!_7820)
                {
                    bool _7894 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
                    bool _7900;
                    if (_7894)
                    {
                        _7900 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7900 = _7894;
                    }
                    _7827 = !_7900;
                }
                else
                {
                    _7827 = _7820;
                }
                if (_7827)
                {
                    _9338 = 0.0f;
                    break;
                }
                uint _7907_dummy_parameter;
                uint _7923_dummy_parameter;
                float4 _7848 = mul(float4((float2(_8860.x, 1.0f - _8860.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8860 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7907_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7850 = _7848.w;
                if (abs(_7850) < 9.9999999747524270787835121154785e-07f)
                {
                    _9338 = 0.0f;
                    break;
                }
                float _7861 = abs(cbFI_DeviceToViewDepth.y / ((_7848.z / _7850) - cbFI_DeviceToViewDepth.x));
                float _7864 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7923_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9338 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7861 - _7864) / max(max(_7861, _7864), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7971 = all(bool2(_8861.x > 0.0f.xx.x, _8861.y > 0.0f.xx.y));
            bool _7977;
            if (_7971)
            {
                _7977 = all(bool2(_8861.x < 1.0f.xx.x, _8861.y < 1.0f.xx.y));
            }
            else
            {
                _7977 = _7971;
            }
            float _9339;
            if (_7977)
            {
                uint _7984_dummy_parameter;
                _9339 = length((_5406 + (r_motion_tp1.Load(int3(int2(floor(_8861 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7984_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9339 = 1000000.0f;
            }
            float _9350;
            if ((_4601 & 1u) != 0u)
            {
                _9350 = _9338;
            }
            else
            {
                _9350 = 1.0f;
            }
            float _9351;
            if ((_4601 & 2u) != 0u)
            {
                _9351 = _9350 * (1.0f - smoothstep(2.0f, 8.0f, _9339));
            }
            else
            {
                _9351 = _9350;
            }
            float _9352;
            if ((_4601 & 4u) != 0u)
            {
                _9352 = _9351 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6127 - _6135) - length(_6111 - _6119))));
            }
            else
            {
                _9352 = _9351;
            }
            float _9519;
            if ((_4601 & 8u) != 0u)
            {
                _9519 = lerp(1.0f, _9352, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6111 - _6119)));
            }
            else
            {
                _9519 = _9352;
            }
            bool _4687 = (_4601 & 16u) != 0u;
            bool _4696;
            if (_4687)
            {
                _4696 = length(_8855 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4696 = _4687;
            }
            float _10298 = _4696 ? 1.0f : _9519;
            bool _4702 = _4607 && _6320;
            bool _4707;
            if (_4702)
            {
                bool _8009 = all(bool2(_8857.x > 0.0f.xx.x, _8857.y > 0.0f.xx.y));
                bool _8015;
                if (_8009)
                {
                    _8015 = all(bool2(_8857.x < 1.0f.xx.x, _8857.y < 1.0f.xx.y));
                }
                else
                {
                    _8015 = _8009;
                }
                _4707 = _8015;
            }
            else
            {
                _4707 = _4702;
            }
            bool _4712;
            if (_4707)
            {
                bool _8020 = all(bool2(_8859.x > 0.0f.xx.x, _8859.y > 0.0f.xx.y));
                bool _8026;
                if (_8020)
                {
                    _8026 = all(bool2(_8859.x < 1.0f.xx.x, _8859.y < 1.0f.xx.y));
                }
                else
                {
                    _8026 = _8020;
                }
                _4712 = _8026;
            }
            else
            {
                _4712 = _4707;
            }
            float4 _9526;
            if (_4712)
            {
                float _4718 = _9508.x + _9508.y;
                float _4727 = (_9508.z + _9508.w) * (1.0f - _10298);
                float _9522;
                if (_4718 > 9.9999997473787516355514526367188e-06f)
                {
                    _9522 = _9508.x / _4718;
                }
                else
                {
                    _9522 = _3924;
                }
                _9526 = float4(_9508.x + (_4727 * _9522), _9508.y + (_4727 * (1.0f - _9522)), _9508.zw * _10298);
            }
            else
            {
                _9526 = _9508;
            }
            _9525 = _9526;
        }
        else
        {
            _9525 = _9508;
        }
        float3 _10071;
        if (_9528)
        {
            float3 _8032 = r_current_interpolation_source.Load(int3(_3336, 0)).xyz;
            float3 _10072;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6320)
            {
                uint _8039_dummy_parameter;
                float _9628;
                _9628 = r_depth_tm1.Load(int3(int2(floor(_8857 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8039_dummy_parameter))))), 0)).x;
                float _4839;
                for (int _9627 = 0; _9627 < 24; _9628 = _4839, _9627++)
                {
                    float _4811 = float(_9627 & 7) * 0.785398185253143310546875f;
                    int _4813 = _9627 >> 3;
                    int _10121;
                    if (_4813 == 0)
                    {
                        _10121 = 16;
                    }
                    else
                    {
                        _10121 = (_4813 == 1) ? 48 : 96;
                    }
                    uint _8059_dummy_parameter;
                    _4839 = max(_9628, r_depth_tm1.Load(int3(int2(floor(clamp(_8857 + ((cbFI_MvDepthLaneSizeRcp * float(_10121)) * float2(cos(_4811), sin(_4811))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8059_dummy_parameter))))), 0)).x);
                }
                float2 _9629;
                do
                {
                    float _8081 = 1.0f - _8857.y;
                    float4 _8092 = mul(float4((float2(_8857.x, _8081) * 2.0f) - 1.0f.xx, _9628, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8094 = _8092.w;
                    if (!(_8094 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9629 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8107 = ((_8092.xy / _8094.xx) + 1.0f.xx) * 0.5f;
                    _9629 = float2(_8107.x - _8857.x, _8081 - _8107.y);
                    break;
                } while(false);
                float2 _4850 = _8857 + _9629;
                bool _8125 = all(bool2(_4850.x > 0.0f.xx.x, _4850.y > 0.0f.xx.y));
                bool _8131;
                if (_8125)
                {
                    _8131 = all(bool2(_4850.x < 1.0f.xx.x, _4850.y < 1.0f.xx.y));
                }
                else
                {
                    _8131 = _8125;
                }
                float3 _10073;
                if (_8131)
                {
                    float _4856 = abs(cbFI_DeviceToViewDepth.y / (_9628 - cbFI_DeviceToViewDepth.x));
                    uint _8151_dummy_parameter;
                    int2 _8151 = int2(spvTextureSize(r_depth_m2, uint(0), _8151_dummy_parameter));
                    float _4860 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4850 * float2(_8151))), int2(0, 0), _8151 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10078;
                    if (abs(_4860 - _4856) <= (0.20000000298023223876953125f * max(_4860, _4856)))
                    {
                        uint _8185_dummy_parameter;
                        int2 _8185 = int2(spvTextureSize(r_colour_m2, uint(0), _8185_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8208;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8208);
                        }
                        _10078 = r_colour_m2.Load(int3(clamp(int2(floor(_4850 * float2(_8185))), int2(0, 0), _8185 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8218;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8218);
                        }
                        _10078 = _8032;
                    }
                    _10073 = _10078;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8228;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8228);
                    }
                    _10073 = _8032;
                }
                _10072 = _10073;
            }
            else
            {
                _10072 = _8032;
            }
            _10071 = _10072;
        }
        else
        {
            _10071 = (((_6111 * _9525.x) + (_6119 * _9525.y)) + (_6127 * _9525.z)) + (_6135 * _9525.w);
        }
        uint _4888 = cbFI_pad0 & 255u;
        bool _9966;
        float3 _10070;
        if (_4888 != 0u)
        {
            float3 _4893 = r_present_backbuffer.Load(int3(_3336, 0)).xyz;
            float3 _4897 = r_current_interpolation_source.Load(int3(_3336, 0)).xyz;
            float3 _4901 = abs(_4893 - _4897);
            float3 _9632;
            if (_4888 == 2u)
            {
                _9632 = (abs(_4897) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9632 = 0.000244140625f.xxx;
            }
            bool _4917 = any(bool3(_4901.x > _9632.x, _4901.y > _9632.y, _4901.z > _9632.z));
            bool3 _10299 = _4917.xxx;
            _10070 = float3(_10299.x ? _4893.x : _10071.x, _10299.y ? _4893.y : _10071.y, _10299.z ? _4893.z : _10071.z);
            _9966 = _4917;
        }
        else
        {
            _10070 = _10071;
            _9966 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8243;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8243);
        }
        float3 _10054;
        if (_4605 == 1u)
        {
            _10054 = lerp(_6111, _6119, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10055;
            if (_4605 == 2u)
            {
                _10055 = lerp(_6127, _6135, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10056;
                if (_4605 == 3u)
                {
                    _10056 = float(_9966).xxx;
                }
                else
                {
                    float3 _10057;
                    if (_4605 == 4u)
                    {
                        _10057 = float3(((_8855 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10058;
                        if (_4605 == 5u)
                        {
                            _10058 = float3(((_5406 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10059;
                            if (_4605 == 6u)
                            {
                                _10059 = float3(_9525.xy, _9525.z + _9525.w);
                            }
                            else
                            {
                                float3 _10060;
                                if (_4605 == 7u)
                                {
                                    _10060 = r_current_interpolation_source.Load(int3(_3336, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10061;
                                    if (_4605 == 8u)
                                    {
                                        _10061 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3699, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10062;
                                        if (_4609)
                                        {
                                            uint _8265_dummy_parameter;
                                            uint _8297_dummy_parameter;
                                            _10062 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3699 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8265_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8297_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10063;
                                            if (_4612)
                                            {
                                                _10063 = _6127;
                                            }
                                            else
                                            {
                                                float3 _10064;
                                                if (_4605 == 20u)
                                                {
                                                    _10064 = _6111;
                                                }
                                                else
                                                {
                                                    float3 _10065;
                                                    if (_4605 == 21u)
                                                    {
                                                        _10065 = _6119;
                                                    }
                                                    else
                                                    {
                                                        float3 _10066;
                                                        if (_4605 == 22u)
                                                        {
                                                            _10066 = _6135;
                                                        }
                                                        else
                                                        {
                                                            float3 _10067;
                                                            if (_4605 == 18u)
                                                            {
                                                                _10067 = _9778;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10301 = (_4605 == 19u).xxx;
                                                                _10067 = float3(_10301.x ? _9638.x : _10070.x, _10301.y ? _9638.y : _10070.y, _10301.z ? _9638.z : _10070.z);
                                                            }
                                                            _10066 = _10067;
                                                        }
                                                        _10065 = _10066;
                                                    }
                                                    _10064 = _10065;
                                                }
                                                _10063 = _10064;
                                            }
                                            _10062 = _10063;
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
        float3 _10053;
        if ((_4605 >= 9u) && (_4605 <= 11u))
        {
            uint _5075 = 64u + uint((_8887.y * cbFI_MvDepthLaneSize.x) + _8887.x);
            uint _5079 = rw_nfru_diagnostics.Load<uint>(_5075 * 4 + 0) & 15u;
            float3 _10083;
            if (_4605 == 10u)
            {
                float3 _10052;
                if ((rw_nfru_diagnostics.Load<uint>(_5075 * 4 + 0) & 32u) != 0u)
                {
                    _10052 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10051;
                    if ((rw_nfru_diagnostics.Load<uint>(_5075 * 4 + 0) & 16u) != 0u)
                    {
                        _10051 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5100 = ((rw_nfru_diagnostics.Load<uint>(_5075 * 4 + 0) & 64u) != 0u).xxx;
                        _10051 = float3(_5100.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5100.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5100.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10052 = _10051;
                }
                _10083 = _10052;
            }
            else
            {
                float3 _10084;
                if (_4605 == 11u)
                {
                    uint _5113 = (rw_nfru_diagnostics.Load<uint>(_5075 * 4 + 0) >> 8u) & 15u;
                    uint _5116 = (rw_nfru_diagnostics.Load<uint>(_5075 * 4 + 0) >> 12u) & 15u;
                    float3 _10044;
                    if ((_5079 == 2u) || (_5079 == 3u))
                    {
                        _10044 = _3032[_5079];
                    }
                    else
                    {
                        bool _5128 = _5113 == 3u;
                        bool _5130 = _5116 == 3u;
                        float3 _10045;
                        if (_5128 && _5130)
                        {
                            _10045 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10046;
                            if (_5128)
                            {
                                _10046 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10047;
                                if (_5130)
                                {
                                    _10047 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10048;
                                    if ((_5113 == 4u) || (_5116 == 4u))
                                    {
                                        _10048 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10049;
                                        if ((_5113 == 1u) || (_5116 == 1u))
                                        {
                                            _10049 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10303 = (_5079 == 1u).xxx;
                                            _10049 = float3(_10303.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10303.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10303.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10048 = _10049;
                                    }
                                    _10047 = _10048;
                                }
                                _10046 = _10047;
                            }
                            _10045 = _10046;
                        }
                        _10044 = _10045;
                    }
                    _10084 = _10044;
                }
                else
                {
                    _10084 = _3032[min(_5079, 7u)];
                }
                _10083 = _10084;
            }
            _10053 = _10083;
        }
        else
        {
            _10053 = _10054;
        }
        float4 _10087;
        if ((_4605 >= 14u) && (_4605 <= 16u))
        {
            float2 _10085;
            if (_4605 == 14u)
            {
                uint _5186_dummy_parameter;
                uint _5192_dummy_parameter;
                _10085 = r_flow_tm1.Load(int3(clamp(int2(floor(_3699 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5186_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5192_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10086;
                if (_4605 == 16u)
                {
                    uint _8348 = r_warped_flow_qdata_tm1.Load(int3(_3715, 0)).x & 2147483647u;
                    uint _8380 = uint(max((int((_8348 >> 16u) & 15u) - 6), 0));
                    _10086 = ((float2(float((1 - (2 * int((_8348 >> 15u) & 1u))) * int(((_8348 >> uint(7)) & 127u) << _8380)), float((1 - (2 * int((_8348 >> 14u) & 1u))) * int((_8348 & 127u) << _8380))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10086 = _5406 * float2(cbFI_DisplaySize);
                }
                _10085 = _10086;
            }
            uint2 _5225 = uint2(clamp(round(_10085 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5227 = _5225.x;
            uint _5234 = _5225.y;
            _10087 = float4(float(_5227 & 255u), float((_5227 >> 8u) | ((_5234 & 15u) << 4u)), float(_5234 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10088;
            if (_4605 == 17u)
            {
                _10088 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3715, 0)).x != 0u), _4058, 0.0f, 1.0f);
            }
            else
            {
                _10088 = float4(_10053, 1.0f);
            }
            _10087 = _10088;
        }
        rw_output[_3336] = _10087.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5278 = ((uint(_3336.y) * uint(cbFI_DisplaySize.x)) + uint(_3336.x)) * 6u;
            uint _8426 = spvPackHalf2x16(clamp(_6110.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5278 * 4 + 0, (((_8426 & 32767u) >> 4u) | ((((_8426 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6110.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8461 = spvPackHalf2x16(clamp(_6118.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5278 + 1u) * 4 + 0, (((_8461 & 32767u) >> 4u) | ((((_8461 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6118.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8496 = spvPackHalf2x16(clamp(_6126.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5278 + 2u) * 4 + 0, (((_8496 & 32767u) >> 4u) | ((((_8496 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6126.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8531 = spvPackHalf2x16(clamp(_6134.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5278 + 3u) * 4 + 0, (((_8531 & 32767u) >> 4u) | ((((_8531 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6134.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8558 = r_current_interpolation_source.Load(int3(_3336, 0));
            uint _8572 = spvPackHalf2x16(clamp(_8558.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5278 + 4u) * 4 + 0, (((_8572 & 32767u) >> 4u) | ((((_8572 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8558.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10120;
            if (_9966 || (_4605 != 0u))
            {
                _10120 = 4294967295u;
            }
            else
            {
                uint _8607 = spvPackHalf2x16(clamp(_10087.xy, 0.0f.xx, 65000.0f.xx));
                _10120 = (((_8607 & 32767u) >> 4u) | ((((_8607 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10087.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5278 + 5u) * 4 + 0, _10120);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3336] = float4(r_current_interpolation_source.Load(int3(_3336, 0)).xyz, 1.0f).xyz;
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
