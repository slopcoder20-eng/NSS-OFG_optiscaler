static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3006[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3293 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3293.x >= cbFI_DisplaySize.x, _3293.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3293] = float4(r_present_backbuffer.Load(int3(_3293, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3639 = (float2(_3293) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3650 = int2(floor(_3639 * float2(cbFI_MvDepthLaneSize)));
        int2 _3655 = int2(floor(_3639 * float2(cbFI_FlowLaneSize)));
        float4 _5313 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3639 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5319 = r_warped_filled_flow_tm1.Load(int3(_3655, 0)).xy;
        float2 _5325 = r_warped_filled_motion_tp1.Load(int3(_3650, 0)).xy;
        bool _5347 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8673;
        if (_5347)
        {
            float _5360 = ((2.0f * _3639.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8673 = float2(atan(_5360) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3639.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5360 * _5360))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8673 = _3639;
        }
        bool _3676 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8694;
        bool _8715;
        int2 _8726;
        float3 _9617;
        if (_3676)
        {
            float _8675;
            float _8677;
            _8677 = 2.0f;
            _8675 = -1.0f;
            uint _3355[9];
            float _10070;
            float _10073;
            for (int _8674 = 0; _8674 < 9; _8677 = _10073, _8675 = _10070, _8674++)
            {
                _3355[_8674] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3650 + int2((_8674 % 3) - 1, (_8674 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3355[_8674] != 0u)
                {
                    float _10065;
                    if (_3355[_8674] == 0u)
                    {
                        _10065 = -1.0f;
                    }
                    else
                    {
                        _10065 = float((_3355[_8674] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10073 = min(_8677, _10065);
                    _10070 = max(_8675, _10065);
                }
                else
                {
                    _10073 = _8677;
                    _10070 = _8675;
                }
            }
            float _3722 = float(_8675 >= 0.0f);
            float3 _8488 = 0.0f.xxx;
            _8488.y = _3722;
            float2 _8695;
            bool _8716;
            int2 _8727;
            float3 _9618;
            if ((_8675 - _8677) > 0.0199999995529651641845703125f)
            {
                float _8683;
                int2 _8684;
                float2 _8685;
                int2 _8687;
                float2 _8693;
                _8693 = _5325;
                _8687 = _3650;
                _8685 = _5325;
                _8684 = _3650;
                _8683 = -1.0f;
                float _10078;
                int2 _10082;
                float2 _10093;
                int2 _10104;
                float2 _10137;
                float _10185;
                int _8682 = 0;
                float _10046 = 1000000000.0f;
                for (; _8682 < 9; _10046 = _10185, _8693 = _10137, _8687 = _10104, _8685 = _10093, _8684 = _10082, _8683 = _10078, _8682++)
                {
                    if (_3355[_8682] == 0u)
                    {
                        _10185 = _10046;
                        _10137 = _8693;
                        _10104 = _8687;
                        _10093 = _8685;
                        _10082 = _8684;
                        _10078 = _8683;
                        continue;
                    }
                    int2 _3757 = clamp(_3650 + int2((_8682 % 3) - 1, (_8682 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5435 = _3355[_8682] & 2147483647u;
                    uint _5467 = uint(max((int((_5435 >> 16u) & 15u) - 6), 0));
                    float2 _3763 = (float2(float((1 - (2 * int((_5435 >> 15u) & 1u))) * int(((_5435 >> uint(7)) & 127u) << _5467)), float((1 - (2 * int((_5435 >> 14u) & 1u))) * int((_5435 & 127u) << _5467))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10032;
                    if (_3355[_8682] == 0u)
                    {
                        _10032 = -1.0f;
                    }
                    else
                    {
                        _10032 = float((_3355[_8682] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3768 = _10032 - 0.100000001490116119384765625f;
                    float2 _10033;
                    if (_5347)
                    {
                        float2 _5544 = clamp((((_8673 + (_3763 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5547 = tan(_5544.x);
                        _10033 = (float2(_5547 / cbFI_DeviceToViewDepth.z, (tan(_5544.y) * sqrt(1.0f + (_5547 * _5547))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10033 = _8673 + (_3763 * cbFI_Timestep);
                    }
                    float _3775 = cbFI_Timestep - 1.0f;
                    float2 _10034;
                    if (_5347)
                    {
                        float2 _5615 = clamp((((_8673 + (_3763 * _3775)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5618 = tan(_5615.x);
                        _10034 = (float2(_5618 / cbFI_DeviceToViewDepth.z, (tan(_5615.y) * sqrt(1.0f + (_5618 * _5618))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10034 = _8673 + (_3763 * _3775);
                    }
                    bool _5651 = all(bool2(_10033.x > 0.0f.xx.x, _10033.y > 0.0f.xx.y));
                    bool _5657;
                    if (_5651)
                    {
                        _5657 = all(bool2(_10033.x < 1.0f.xx.x, _10033.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5657 = _5651;
                    }
                    float _10037;
                    if (_5657)
                    {
                        uint _5664_dummy_parameter;
                        _10037 = max((_3768 - (log(((r_depth_tm1.Load(int3(int2(floor(_10033 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5664_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10037 = 0.0f;
                    }
                    bool _5694 = all(bool2(_10034.x > 0.0f.xx.x, _10034.y > 0.0f.xx.y));
                    bool _5700;
                    if (_5694)
                    {
                        _5700 = all(bool2(_10034.x < 1.0f.xx.x, _10034.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5700 = _5694;
                    }
                    float _10038;
                    if (_5700)
                    {
                        uint _5707_dummy_parameter;
                        _10038 = _10037 + max((_3768 - (log(((r_depth_tp1.Load(int3(int2(floor(_10034 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5707_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10038 = _10037;
                    }
                    float _10079;
                    int2 _10083;
                    float2 _10094;
                    int2 _10105;
                    float2 _10138;
                    float _10186;
                    if (_10038 == 0.0f)
                    {
                        bool _3810 = _3768 > _8683;
                        bool2 _10194 = _3810.xx;
                        _10186 = _10046;
                        _10138 = float2(_10194.x ? _3763.x : _8693.x, _10194.y ? _3763.y : _8693.y);
                        _10105 = int2(_10194.x ? _3757.x : _8687.x, _10194.y ? _3757.y : _8687.y);
                        _10094 = _8685;
                        _10083 = _8684;
                        _10079 = _3810 ? _3768 : _8683;
                    }
                    else
                    {
                        bool _3819 = _10038 < _10046;
                        bool2 _10190 = _3819.xx;
                        _10186 = _3819 ? _10038 : _10046;
                        _10138 = _8693;
                        _10105 = _8687;
                        _10094 = float2(_10190.x ? _3763.x : _8685.x, _10190.y ? _3763.y : _8685.y);
                        _10083 = int2(_10190.x ? _3757.x : _8684.x, _10190.y ? _3757.y : _8684.y);
                        _10079 = _8683;
                    }
                    _10185 = _10186;
                    _10137 = _10138;
                    _10104 = _10105;
                    _10093 = _10094;
                    _10082 = _10083;
                    _10078 = _10079;
                }
                bool _3831 = _8683 < 0.0f;
                bool2 _10200 = _3831.xx;
                int2 _10203 = int2(_10200.x ? _8684.x : _8687.x, _10200.y ? _8684.y : _8687.y);
                _9618 = float3(1.0f, _3722, float(any(bool2(_10203.x != _3650.x, _10203.y != _3650.y))));
                _8727 = _10203;
                _8716 = _3831 ? false : true;
                _8695 = float2(_10200.x ? _8685.x : _8693.x, _10200.y ? _8685.y : _8693.y);
            }
            else
            {
                _9618 = _8488;
                _8727 = _3650;
                _8716 = false;
                _8695 = _5325;
            }
            _9617 = _9618;
            _8726 = _8727;
            _8715 = _8716;
            _8694 = _8695;
        }
        else
        {
            _9617 = 0.0f.xxx;
            _8726 = _3650;
            _8715 = false;
            _8694 = _5325;
        }
        float2 _8696;
        if (_5347)
        {
            float2 _5772 = clamp((((_8673 + (_8694 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5775 = tan(_5772.x);
            _8696 = (float2(_5775 / cbFI_DeviceToViewDepth.z, (tan(_5772.y) * sqrt(1.0f + (_5775 * _5775))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8696 = _8673 + (_8694 * cbFI_Timestep);
        }
        float _3854 = cbFI_Timestep - 1.0f;
        float2 _8698;
        if (_5347)
        {
            float2 _5843 = clamp((((_8673 + (_8694 * _3854)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5846 = tan(_5843.x);
            _8698 = (float2(_5846 / cbFI_DeviceToViewDepth.z, (tan(_5843.y) * sqrt(1.0f + (_5846 * _5846))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8698 = _8673 + (_8694 * _3854);
        }
        float _3859 = -cbFI_Timestep;
        float2 _8699;
        if (_5347)
        {
            float2 _5914 = clamp((((_8673 + (_5319 * _3859)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5917 = tan(_5914.x);
            _8699 = (float2(_5917 / cbFI_DeviceToViewDepth.z, (tan(_5914.y) * sqrt(1.0f + (_5917 * _5917))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8699 = _8673 + (_5319 * _3859);
        }
        float _3864 = 1.0f - cbFI_Timestep;
        float2 _8700;
        if (_5347)
        {
            float2 _5985 = clamp((((_8673 + (_5319 * _3864)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5988 = tan(_5985.x);
            _8700 = (float2(_5988 / cbFI_DeviceToViewDepth.z, (tan(_5985.y) * sqrt(1.0f + (_5988 * _5988))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8700 = _8673 + (_5319 * _3864);
        }
        float4 _6023 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8696, 0.0f);
        float3 _6024 = _6023.xyz;
        float4 _6031 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8698, 0.0f);
        float3 _6032 = _6031.xyz;
        float4 _6039 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8699, 0.0f);
        float3 _6040 = _6039.xyz;
        float4 _6047 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8700, 0.0f);
        float3 _6048 = _6047.xyz;
        float4 _6062 = exp(_5313 - max(max(max(_5313.x, _5313.y), _5313.z), _5313.w).xxxx);
        float4 _6069 = _6062 / (dot(_6062, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3883 = _3676 && (!_8715);
        bool _3892;
        if (_3883)
        {
            _3892 = (_6069.z + _6069.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3892 = _3883;
        }
        bool _3903;
        if (_3892)
        {
            _3903 = length((_8699 - _8696) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3903 = _3892;
        }
        bool _8739;
        if (_3903)
        {
            uint4 _6088 = r_warped_motion_qdata_tp1.Load(int3(_8726, 0));
            uint _6089 = _6088.x;
            bool _8742;
            if (_6089 != 0u)
            {
                float _8728;
                if (_6089 == 0u)
                {
                    _8728 = -1.0f;
                }
                else
                {
                    _8728 = float((_6089 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3913 = _8728 - 0.12000000476837158203125f;
                bool _6108 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
                bool _6114;
                if (_6108)
                {
                    _6114 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
                }
                else
                {
                    _6114 = _6108;
                }
                bool _3923;
                if (_6114)
                {
                    uint _6121_dummy_parameter;
                    _3923 = (log(((r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6121_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3913;
                }
                else
                {
                    _3923 = _6114;
                }
                bool _3937;
                if (!_3923)
                {
                    bool _6151 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
                    bool _6157;
                    if (_6151)
                    {
                        _6157 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6157 = _6151;
                    }
                    bool _3935;
                    if (_6157)
                    {
                        uint _6164_dummy_parameter;
                        _3935 = (log(((r_depth_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6164_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3913;
                    }
                    else
                    {
                        _3935 = _6157;
                    }
                    _3937 = _3935;
                }
                else
                {
                    _3937 = _3923;
                }
                _8742 = _3937;
            }
            else
            {
                _8742 = false;
            }
            _8739 = _8742;
        }
        else
        {
            _8739 = false;
        }
        bool _3942 = _8715 || _8739;
        bool _3947;
        if (_3942)
        {
            bool _6194 = all(bool2(_8696.x > 0.0f.xx.x, _8696.y > 0.0f.xx.y));
            bool _6200;
            if (_6194)
            {
                _6200 = all(bool2(_8696.x < 1.0f.xx.x, _8696.y < 1.0f.xx.y));
            }
            else
            {
                _6200 = _6194;
            }
            _3947 = _6200;
        }
        else
        {
            _3947 = _3942;
        }
        bool _3952;
        if (_3947)
        {
            bool _6205 = all(bool2(_8698.x > 0.0f.xx.x, _8698.y > 0.0f.xx.y));
            bool _6211;
            if (_6205)
            {
                _6211 = all(bool2(_8698.x < 1.0f.xx.x, _8698.y < 1.0f.xx.y));
            }
            else
            {
                _6211 = _6205;
            }
            _3952 = _6211;
        }
        else
        {
            _3952 = _3947;
        }
        float4 _8833;
        if (_3952)
        {
            float _3955 = _6069.x;
            float _3957 = _6069.y;
            float _3958 = _3955 + _3957;
            float _3963 = _6069.z + _6069.w;
            float _8757;
            if (_3958 > 0.001000000047497451305389404296875f)
            {
                _8757 = _3955 / _3958;
            }
            else
            {
                _8757 = _3864;
            }
            _8833 = float4(_3955 + (_3963 * _8757), _3957 + (_3963 * (1.0f - _8757)), 0.0f, 0.0f);
        }
        else
        {
            _8833 = _6069;
        }
        bool _6239 = (cbFI_pad0 & 1024u) != 0u;
        bool _6215 = !_6239;
        bool _6216 = !_6215;
        bool _6233;
        if (_6216)
        {
            _6233 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8726.y * cbFI_MvDepthLaneSize.x) + _8726.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6233 = _6215;
        }
        bool _6265;
        if (_6216)
        {
            _6265 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3655.y * cbFI_FlowLaneSize.x) + _3655.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6265 = _6215;
        }
        float _3998 = float(_6265);
        bool _8845;
        float4 _8875;
        float3 _9477;
        if (_6239)
        {
            bool _4008;
            if (_6233)
            {
                _4008 = all(bool2(_8696.x > 0.0f.xx.x, _8696.y > 0.0f.xx.y));
            }
            else
            {
                _4008 = _6233;
            }
            bool _4014;
            if (_4008)
            {
                _4014 = all(bool2(_8696.x < 1.0f.xx.x, _8696.y < 1.0f.xx.y));
            }
            else
            {
                _4014 = _4008;
            }
            bool _4021;
            if (_6233)
            {
                _4021 = all(bool2(_8698.x > 0.0f.xx.x, _8698.y > 0.0f.xx.y));
            }
            else
            {
                _4021 = _6233;
            }
            bool _4027;
            if (_4021)
            {
                _4027 = all(bool2(_8698.x < 1.0f.xx.x, _8698.y < 1.0f.xx.y));
            }
            else
            {
                _4027 = _4021;
            }
            bool _4034;
            if (_6265)
            {
                _4034 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
            }
            else
            {
                _4034 = _6265;
            }
            bool _4040;
            if (_4034)
            {
                _4040 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
            }
            else
            {
                _4040 = _4034;
            }
            bool _4047;
            if (_6265)
            {
                _4047 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
            }
            else
            {
                _4047 = _6265;
            }
            bool _4053;
            if (_4047)
            {
                _4053 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
            }
            else
            {
                _4053 = _4047;
            }
            bool _4055 = !_6233;
            if (_4055)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6307;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6307);
                }
            }
            bool _4060 = !_6265;
            if (_4060)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6317;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6317);
                }
            }
            if (_6233 && _4060)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6327;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6327);
                }
            }
            if (_4055 && _6265)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6337;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6337);
                }
            }
            float _4079 = float(_4014);
            float _4081 = float(_4027);
            bool _4084 = _4040 && _4053;
            float _8791;
            if (_4084)
            {
                _8791 = 1.0f;
            }
            else
            {
                _8791 = (_4040 || _4053) ? 0.5f : 0.0f;
            }
            bool _8796;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4014)) && (!_4027))
            {
                bool _4114;
                if (_4084)
                {
                    float _8794;
                    do
                    {
                        bool _6421 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
                        bool _6427;
                        if (_6421)
                        {
                            _6427 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6427 = _6421;
                        }
                        bool _6358 = !_6427;
                        bool _6365;
                        if (!_6358)
                        {
                            bool _6432 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
                            bool _6438;
                            if (_6432)
                            {
                                _6438 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6438 = _6432;
                            }
                            _6365 = !_6438;
                        }
                        else
                        {
                            _6365 = _6358;
                        }
                        if (_6365)
                        {
                            _8794 = 0.0f;
                            break;
                        }
                        uint _6445_dummy_parameter;
                        uint _6461_dummy_parameter;
                        float4 _6386 = mul(float4((float2(_8699.x, 1.0f - _8699.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6445_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6388 = _6386.w;
                        if (abs(_6388) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8794 = 0.0f;
                            break;
                        }
                        float _6399 = abs(cbFI_DeviceToViewDepth.y / ((_6386.z / _6388) - cbFI_DeviceToViewDepth.x));
                        float _6402 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6461_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8794 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6399 - _6402) / max(max(_6399, _6402), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4114 = _8794 >= 0.5f;
                }
                else
                {
                    _4114 = _4084;
                }
                bool _8797;
                if (_4114)
                {
                    uint _6511_dummy_parameter;
                    float2 _8795;
                    do
                    {
                        float _6537 = 1.0f - _8699.y;
                        float4 _6548 = mul(float4((float2(_8699.x, _6537) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6511_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6550 = _6548.w;
                        if (!(_6550 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8795 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6563 = ((_6548.xy / _6550.xx) + 1.0f.xx) * 0.5f;
                        _8795 = float2(_6563.x - _8699.x, _6537 - _6563.y);
                        break;
                    } while(false);
                    float2 _4128 = float2(cbFI_DisplaySize);
                    _8797 = length(((_8699 + _8795) - _8700) * _4128) <= ((0.100000001490116119384765625f * length(_8795 * _4128)) + 8.0f);
                }
                else
                {
                    _8797 = _4114;
                }
                _8796 = _8797;
            }
            else
            {
                _8796 = true;
            }
            bool _4142 = !_8796;
            bool _10204 = _4142 ? false : _4053;
            bool _10205 = _4142 ? false : _4040;
            bool _8846;
            float4 _8876;
            if (!(((_4014 && _4027) && _10205) && _10204))
            {
                float4 _4164 = _8833 * float4(_4079, _4081, float(_10205), float(_10204));
                float _4166 = dot(_4164, 1.0f.xxxx);
                bool _4169 = !(_4166 > 0.0f);
                float4 _8877;
                if (!_4169)
                {
                    _8877 = _4164 / _4166.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6585;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6585);
                    }
                    _8877 = 0.0f.xxxx;
                }
                _8876 = _8877;
                _8846 = _4169;
            }
            else
            {
                _8876 = _8833;
                _8846 = false;
            }
            _9477 = float3(_4079, _4081, _8791);
            _8875 = _8876;
            _8845 = _8846;
        }
        else
        {
            _9477 = float3(float(_6233), _3998, 0.0f);
            _8875 = _8833;
            _8845 = false;
        }
        float4 _9347;
        bool _9367;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_8845))
        {
            bool _4192 = _8875.x > 0.00999999977648258209228515625f;
            bool _4195 = _8875.y > 0.00999999977648258209228515625f;
            bool _4204 = (_8875.z + _8875.w) > 0.0199999995529651641845703125f;
            bool _4210;
            if (_4204)
            {
                bool _6591 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
                bool _6597;
                if (_6591)
                {
                    _6597 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
                }
                else
                {
                    _6597 = _6591;
                }
                _4210 = _6597;
            }
            else
            {
                _4210 = _4204;
            }
            bool _4215;
            if (_4210)
            {
                bool _6602 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
                bool _6608;
                if (_6602)
                {
                    _6608 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
                }
                else
                {
                    _6608 = _6602;
                }
                _4215 = _6608;
            }
            else
            {
                _4215 = _4210;
            }
            bool _4222;
            if (_4215)
            {
                float _8879;
                do
                {
                    bool _6691 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
                    bool _6697;
                    if (_6691)
                    {
                        _6697 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6697 = _6691;
                    }
                    bool _6628 = !_6697;
                    bool _6635;
                    if (!_6628)
                    {
                        bool _6702 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
                        bool _6708;
                        if (_6702)
                        {
                            _6708 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6708 = _6702;
                        }
                        _6635 = !_6708;
                    }
                    else
                    {
                        _6635 = _6628;
                    }
                    if (_6635)
                    {
                        _8879 = 0.0f;
                        break;
                    }
                    uint _6715_dummy_parameter;
                    uint _6731_dummy_parameter;
                    float4 _6656 = mul(float4((float2(_8699.x, 1.0f - _8699.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6715_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6658 = _6656.w;
                    if (abs(_6658) < 9.9999999747524270787835121154785e-07f)
                    {
                        _8879 = 0.0f;
                        break;
                    }
                    float _6669 = abs(cbFI_DeviceToViewDepth.y / ((_6656.z / _6658) - cbFI_DeviceToViewDepth.x));
                    float _6672 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6731_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _8879 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6669 - _6672) / max(max(_6669, _6672), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4222 = _8879 < 0.5f;
            }
            else
            {
                _4222 = _4215;
            }
            float4 _8894;
            if (_4222)
            {
                uint _6781_dummy_parameter;
                uint _6812_dummy_parameter;
                float4 _8895;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6781_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6812_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _8895 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _8895 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _8894 = _8895;
            }
            else
            {
                _8894 = 1.0f.xxxx;
            }
            bool _4246;
            if (_6233)
            {
                bool _6841 = all(bool2(_8696.x > 0.0f.xx.x, _8696.y > 0.0f.xx.y));
                bool _6847;
                if (_6841)
                {
                    _6847 = all(bool2(_8696.x < 1.0f.xx.x, _8696.y < 1.0f.xx.y));
                }
                else
                {
                    _6847 = _6841;
                }
                _4246 = _6847;
            }
            else
            {
                _4246 = _6233;
            }
            bool _4252;
            if (_6233)
            {
                bool _6852 = all(bool2(_8698.x > 0.0f.xx.x, _8698.y > 0.0f.xx.y));
                bool _6858;
                if (_6852)
                {
                    _6858 = all(bool2(_8698.x < 1.0f.xx.x, _8698.y < 1.0f.xx.y));
                }
                else
                {
                    _6858 = _6852;
                }
                _4252 = _6858;
            }
            else
            {
                _4252 = _6233;
            }
            bool _4258;
            if (_6265)
            {
                bool _6863 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
                bool _6869;
                if (_6863)
                {
                    _6869 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
                }
                else
                {
                    _6869 = _6863;
                }
                _4258 = _6869;
            }
            else
            {
                _4258 = _6265;
            }
            bool _4264;
            if (_6265)
            {
                bool _6874 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
                bool _6880;
                if (_6874)
                {
                    _6880 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
                }
                else
                {
                    _6880 = _6874;
                }
                _4264 = _6880;
            }
            else
            {
                _4264 = _6265;
            }
            bool _4267 = _4258 != _4264;
            bool _4273;
            if (_4267)
            {
                _4273 = _4246 || _4252;
            }
            else
            {
                _4273 = _4267;
            }
            float4 _8997;
            if (_4273)
            {
                float4 _8573 = _8894;
                _8573.z = 0.0f;
                _8573.w = 0.0f;
                _8997 = _8573;
            }
            else
            {
                _8997 = _8894;
            }
            bool _4280 = _4246 && _4192;
            bool _4283 = _4252 && _4195;
            float4 _9072;
            if (_4280 || _4283)
            {
                float _8971;
                do
                {
                    uint4 _7019 = r_warped_motion_qdata_tp1.Load(int3(_8726, 0));
                    uint _7020 = _7019.x;
                    if (_7020 != 0u)
                    {
                        float _8970;
                        if (_7020 == 0u)
                        {
                            _8970 = -1.0f;
                        }
                        else
                        {
                            _8970 = float((_7020 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _8971 = _8970;
                        break;
                    }
                    int _8953;
                    uint _8954;
                    _8954 = _7020;
                    _8953 = -1;
                    uint _8969;
                    for (; _8953 <= 1; _8954 = _8969, _8953++)
                    {
                        _8969 = _8954;
                        for (int _8967 = -1; _8967 <= 1; )
                        {
                            _8969 = max(_8969, r_warped_motion_qdata_tp1.Load(int3(clamp(_8726 + int2(_8967, _8953), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _8967++;
                            continue;
                        }
                    }
                    if (_8954 != 0u)
                    {
                        float _8966;
                        if (_8954 == 0u)
                        {
                            _8966 = -1.0f;
                        }
                        else
                        {
                            _8966 = float((_8954 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _8971 = _8966;
                        break;
                    }
                    uint _8956;
                    _8956 = 4294967295u;
                    uint _10174;
                    for (int _8955 = 0; _8955 < 8; _8956 = _10174, _8955++)
                    {
                        int _8959 = 0;
                        for (;;)
                        {
                            if (_8959 < 5)
                            {
                                int2 _6970 = _8726 + (_1085[_8955] * _1094[_8959].xx);
                                bool _6973 = any(bool2(_6970.x < int2(0, 0).x, _6970.y < int2(0, 0).y));
                                bool _6981;
                                if (!_6973)
                                {
                                    _6981 = any(bool2(_6970.x >= cbFI_MvDepthLaneSize.x, _6970.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _6981 = _6973;
                                }
                                if (_6981)
                                {
                                    _10174 = _8956;
                                    break;
                                }
                                uint4 _7059 = r_warped_motion_qdata_tp1.Load(int3(_6970, 0));
                                uint _7060 = _7059.x;
                                if (_7060 != 0u)
                                {
                                    _10174 = min(_8956, _7060);
                                    break;
                                }
                                _8959++;
                                continue;
                            }
                            else
                            {
                                _10174 = _8956;
                                break;
                            }
                        }
                    }
                    float _8958;
                    if (_8956 == 4294967295u)
                    {
                        _8958 = -1.0f;
                    }
                    else
                    {
                        float _8957;
                        if (_8956 == 0u)
                        {
                            _8957 = -1.0f;
                        }
                        else
                        {
                            _8957 = float((_8956 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _8958 = _8957;
                    }
                    _8971 = _8958;
                    break;
                } while(false);
                float _4294 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4296 = _8971 >= 0.0f;
                float _8978;
                if (_4296)
                {
                    _8978 = _8971 - _4294;
                }
                else
                {
                    float _8974;
                    if (_4280)
                    {
                        float _8973;
                        _8973 = 2.0f;
                        float _7131;
                        for (int _8972 = 0; _8972 < 24; _8973 = _7131, _8972++)
                        {
                            float _7095 = float(_8972 & 7) * 0.785398185253143310546875f;
                            int _7097 = _8972 >> 3;
                            int _8975;
                            if (_7097 == 0)
                            {
                                _8975 = 16;
                            }
                            else
                            {
                                _8975 = (_7097 == 1) ? 48 : 96;
                            }
                            uint _7147_dummy_parameter;
                            _7131 = min(_8973, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_8696 + ((cbFI_MvDepthLaneSizeRcp * float(_8975)) * float2(cos(_7095), sin(_7095))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7147_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _8974 = _8973;
                    }
                    else
                    {
                        _8974 = 0.0f;
                    }
                    _8978 = _8974;
                }
                float _8985;
                if (_4296)
                {
                    _8985 = _8971 - _4294;
                }
                else
                {
                    float _8981;
                    if (_4283)
                    {
                        float _8980;
                        _8980 = 2.0f;
                        float _7245;
                        for (int _8979 = 0; _8979 < 24; _8980 = _7245, _8979++)
                        {
                            float _7209 = float(_8979 & 7) * 0.785398185253143310546875f;
                            int _7211 = _8979 >> 3;
                            int _8982;
                            if (_7211 == 0)
                            {
                                _8982 = 16;
                            }
                            else
                            {
                                _8982 = (_7211 == 1) ? 48 : 96;
                            }
                            uint _7277_dummy_parameter;
                            _7245 = min(_8980, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_8698 + ((cbFI_MvDepthLaneSizeRcp * float(_8982)) * float2(cos(_7209), sin(_7209))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7277_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _8981 = _8980;
                    }
                    else
                    {
                        _8981 = 0.0f;
                    }
                    _8985 = _8981;
                }
                float _8986;
                if (_4280)
                {
                    uint _7309_dummy_parameter;
                    _8986 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_8696 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7309_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _8986 = 0.0f;
                }
                float _8987;
                if (_4283)
                {
                    uint _7329_dummy_parameter;
                    _8987 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_8698 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7329_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _8987 = 0.0f;
                }
                bool _4351;
                if (_4280)
                {
                    _4351 = _8986 > ((exp((_8978 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4351 = _4280;
                }
                float4 _9012;
                if (_4351)
                {
                    float4 _8577 = _8997;
                    _8577.x = 0.0f;
                    _9012 = _8577;
                }
                else
                {
                    _9012 = _8997;
                }
                bool _4363;
                if (_4283)
                {
                    _4363 = _8987 > ((exp((_8985 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4363 = _4283;
                }
                float4 _9014;
                if (_4363)
                {
                    float4 _8579 = _9012;
                    _8579.y = 0.0f;
                    _9014 = _8579;
                }
                else
                {
                    _9014 = _9012;
                }
                float4 _9073;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4296)
                {
                    bool _4383;
                    if (_4280)
                    {
                        _4383 = _8986 < ((exp((_8978 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4383 = _4280;
                    }
                    float4 _9016;
                    if (_4383)
                    {
                        float4 _8581 = _9014;
                        _8581.x = 0.0f;
                        _9016 = _8581;
                    }
                    else
                    {
                        _9016 = _9014;
                    }
                    bool _4395;
                    if (_4283)
                    {
                        _4395 = _8987 < ((exp((_8985 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4395 = _4283;
                    }
                    float4 _9074;
                    if (_4395)
                    {
                        float4 _8583 = _9016;
                        _8583.y = 0.0f;
                        _9074 = _8583;
                    }
                    else
                    {
                        _9074 = _9016;
                    }
                    _9073 = _9074;
                }
                else
                {
                    _9073 = _9014;
                }
                _9072 = _9073;
            }
            else
            {
                _9072 = _8997;
            }
            bool _4406 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4204;
            bool _4412;
            if (_4406)
            {
                _4412 = _4258 || _4264;
            }
            else
            {
                _4412 = _4406;
            }
            float4 _9094;
            if (_4412)
            {
                float _9067;
                do
                {
                    uint4 _7509 = r_warped_motion_qdata_tp1.Load(int3(_8726, 0));
                    uint _7510 = _7509.x;
                    if (_7510 != 0u)
                    {
                        float _9066;
                        if (_7510 == 0u)
                        {
                            _9066 = -1.0f;
                        }
                        else
                        {
                            _9066 = float((_7510 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9067 = _9066;
                        break;
                    }
                    int _9049;
                    uint _9050;
                    _9050 = _7510;
                    _9049 = -1;
                    uint _9065;
                    for (; _9049 <= 1; _9050 = _9065, _9049++)
                    {
                        _9065 = _9050;
                        for (int _9063 = -1; _9063 <= 1; )
                        {
                            _9065 = max(_9065, r_warped_motion_qdata_tp1.Load(int3(clamp(_8726 + int2(_9063, _9049), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9063++;
                            continue;
                        }
                    }
                    if (_9050 != 0u)
                    {
                        float _9062;
                        if (_9050 == 0u)
                        {
                            _9062 = -1.0f;
                        }
                        else
                        {
                            _9062 = float((_9050 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9067 = _9062;
                        break;
                    }
                    uint _9052;
                    _9052 = 4294967295u;
                    uint _10175;
                    for (int _9051 = 0; _9051 < 8; _9052 = _10175, _9051++)
                    {
                        int _9055 = 0;
                        for (;;)
                        {
                            if (_9055 < 5)
                            {
                                int2 _7460 = _8726 + (_1085[_9051] * _1094[_9055].xx);
                                bool _7463 = any(bool2(_7460.x < int2(0, 0).x, _7460.y < int2(0, 0).y));
                                bool _7471;
                                if (!_7463)
                                {
                                    _7471 = any(bool2(_7460.x >= cbFI_MvDepthLaneSize.x, _7460.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7471 = _7463;
                                }
                                if (_7471)
                                {
                                    _10175 = _9052;
                                    break;
                                }
                                uint4 _7549 = r_warped_motion_qdata_tp1.Load(int3(_7460, 0));
                                uint _7550 = _7549.x;
                                if (_7550 != 0u)
                                {
                                    _10175 = min(_9052, _7550);
                                    break;
                                }
                                _9055++;
                                continue;
                            }
                            else
                            {
                                _10175 = _9052;
                                break;
                            }
                        }
                    }
                    float _9054;
                    if (_9052 == 4294967295u)
                    {
                        _9054 = -1.0f;
                    }
                    else
                    {
                        float _9053;
                        if (_9052 == 0u)
                        {
                            _9053 = -1.0f;
                        }
                        else
                        {
                            _9053 = float((_9052 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9054 = _9053;
                    }
                    _9067 = _9054;
                    break;
                } while(false);
                float4 _9095;
                if (_9067 >= 0.0f)
                {
                    float _7571 = (exp((_9067 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4431;
                    if (_4258)
                    {
                        uint _7578_dummy_parameter;
                        _4431 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7578_dummy_parameter))))), 0)).x) > _7571;
                    }
                    else
                    {
                        _4431 = _4258;
                    }
                    float4 _9085;
                    if (_4431)
                    {
                        float4 _8585 = _9072;
                        _8585.z = 0.0f;
                        _9085 = _8585;
                    }
                    else
                    {
                        _9085 = _9072;
                    }
                    bool _4443;
                    if (_4264)
                    {
                        uint _7598_dummy_parameter;
                        _4443 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7598_dummy_parameter))))), 0)).x) > _7571;
                    }
                    else
                    {
                        _4443 = _4264;
                    }
                    float4 _9096;
                    if (_4443)
                    {
                        float4 _8587 = _9085;
                        _8587.w = 0.0f;
                        _9096 = _8587;
                    }
                    else
                    {
                        _9096 = _9085;
                    }
                    _9095 = _9096;
                }
                else
                {
                    _9095 = _9072;
                }
                _9094 = _9095;
            }
            else
            {
                _9094 = _9072;
            }
            bool _4451 = _4246 != _4252;
            bool _4458;
            if (_4451)
            {
                _4458 = _4246 ? _4192 : _4195;
            }
            else
            {
                _4458 = _4451;
            }
            float4 _9174;
            if (_4458)
            {
                bool2 _4463 = _4246.xx;
                float2 _4464 = float2(_4463.x ? _8696.x : _8698.x, _4463.y ? _8696.y : _8698.y);
                float _9087;
                if (_4246)
                {
                    uint _7618_dummy_parameter;
                    _9087 = r_depth_tm1.Load(int3(int2(floor(_4464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7618_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7634_dummy_parameter;
                    _9087 = r_depth_tp1.Load(int3(int2(floor(_4464 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7634_dummy_parameter))))), 0)).x;
                }
                float4x4 _9088;
                if (_4246)
                {
                    _9088 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9088 = cbFI_MotionTP1ToTM1;
                }
                float2 _9089;
                do
                {
                    float _7661 = _4464.x;
                    float _7664 = 1.0f - _4464.y;
                    float4 _7675 = mul(float4((float2(_7661, _7664) * 2.0f) - 1.0f.xx, _9087, 1.0f), _9088);
                    float _7677 = _7675.w;
                    if (!(_7677 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9089 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7690 = ((_7675.xy / _7677.xx) + 1.0f.xx) * 0.5f;
                    _9089 = float2(_7690.x - _7661, _7664 - _7690.y);
                    break;
                } while(false);
                float2 _4494 = float2(cbFI_DisplaySize);
                float4 _9175;
                if (!(length(((_4464 + _9089) - float2(_4463.x ? _8698.x : _8696.x, _4463.y ? _8698.y : _8696.y)) * _4494) <= ((0.100000001490116119384765625f * length(_9089 * _4494)) + 8.0f)))
                {
                    float4 _9176;
                    if (_4246)
                    {
                        float4 _8597 = _9094;
                        _8597.x = 0.0f;
                        _9176 = _8597;
                    }
                    else
                    {
                        float4 _8599 = _9094;
                        _8599.y = 0.0f;
                        _9176 = _8599;
                    }
                    _9175 = _9176;
                }
                else
                {
                    _9175 = _9094;
                }
                _9174 = _9175;
            }
            else
            {
                _9174 = _9094;
            }
            float4 _4519 = _8875 * _9174;
            float _4521 = dot(_4519, 1.0f.xxxx);
            float4 _9348;
            bool _9368;
            if (_4521 > 0.0f)
            {
                _9368 = _8845;
                _9348 = _4519 / _4521.xxxx;
            }
            else
            {
                bool _4532 = any(bool4(_9174.x < 1.0f.xxxx.x, _9174.y < 1.0f.xxxx.y, _9174.z < 1.0f.xxxx.z, _9174.w < 1.0f.xxxx.w));
                if (_4532)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7712;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7712);
                    }
                }
                bool4 _10207 = _4532.xxxx;
                _9368 = _4532 ? true : _8845;
                _9348 = float4(_10207.x ? 0.0f.xxxx.x : _8875.x, _10207.y ? 0.0f.xxxx.y : _8875.y, _10207.z ? 0.0f.xxxx.z : _8875.z, _10207.w ? 0.0f.xxxx.w : _8875.w);
            }
            _9367 = _9368;
            _9347 = _9348;
        }
        else
        {
            _9367 = _8845;
            _9347 = _8875;
        }
        uint _4541 = (cbFI_pad0 >> 24u) & 31u;
        uint _4545 = (cbFI_pad0 >> 16u) & 255u;
        bool _4547 = _4541 != 0u;
        bool _4549 = _4545 == 12u;
        bool _4552 = _4545 == 13u;
        float4 _9364;
        float _9770;
        float _9797;
        float _9823;
        if ((_4547 || _4549) || _4552)
        {
            float _9177;
            do
            {
                bool _7796 = all(bool2(_8699.x > 0.0f.xx.x, _8699.y > 0.0f.xx.y));
                bool _7802;
                if (_7796)
                {
                    _7802 = all(bool2(_8699.x < 1.0f.xx.x, _8699.y < 1.0f.xx.y));
                }
                else
                {
                    _7802 = _7796;
                }
                bool _7733 = !_7802;
                bool _7740;
                if (!_7733)
                {
                    bool _7807 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
                    bool _7813;
                    if (_7807)
                    {
                        _7813 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7813 = _7807;
                    }
                    _7740 = !_7813;
                }
                else
                {
                    _7740 = _7733;
                }
                if (_7740)
                {
                    _9177 = 0.0f;
                    break;
                }
                uint _7820_dummy_parameter;
                uint _7836_dummy_parameter;
                float4 _7761 = mul(float4((float2(_8699.x, 1.0f - _8699.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8699 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7820_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7763 = _7761.w;
                if (abs(_7763) < 9.9999999747524270787835121154785e-07f)
                {
                    _9177 = 0.0f;
                    break;
                }
                float _7774 = abs(cbFI_DeviceToViewDepth.y / ((_7761.z / _7763) - cbFI_DeviceToViewDepth.x));
                float _7777 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7836_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9177 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7774 - _7777) / max(max(_7774, _7777), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7884 = all(bool2(_8700.x > 0.0f.xx.x, _8700.y > 0.0f.xx.y));
            bool _7890;
            if (_7884)
            {
                _7890 = all(bool2(_8700.x < 1.0f.xx.x, _8700.y < 1.0f.xx.y));
            }
            else
            {
                _7890 = _7884;
            }
            float _9178;
            if (_7890)
            {
                uint _7897_dummy_parameter;
                _9178 = length((_5319 + (r_motion_tp1.Load(int3(int2(floor(_8700 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7897_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9178 = 1000000.0f;
            }
            float _4572 = 1.0f - smoothstep(2.0f, 8.0f, _9178);
            float _9189;
            if ((_4541 & 1u) != 0u)
            {
                _9189 = _9177;
            }
            else
            {
                _9189 = 1.0f;
            }
            float _9190;
            if ((_4541 & 2u) != 0u)
            {
                _9190 = _9189 * _4572;
            }
            else
            {
                _9190 = _9189;
            }
            float _9191;
            if ((_4541 & 4u) != 0u)
            {
                _9191 = _9190 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6040 - _6048) - length(_6024 - _6032))));
            }
            else
            {
                _9191 = _9190;
            }
            float _9358;
            if ((_4541 & 8u) != 0u)
            {
                _9358 = lerp(1.0f, _9191, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6024 - _6032)));
            }
            else
            {
                _9358 = _9191;
            }
            bool _4627 = (_4541 & 16u) != 0u;
            bool _4636;
            if (_4627)
            {
                _4636 = length(_8694 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4636 = _4627;
            }
            float _10209 = _4636 ? 1.0f : _9358;
            bool _4642 = _4547 && _6233;
            bool _4647;
            if (_4642)
            {
                bool _7922 = all(bool2(_8696.x > 0.0f.xx.x, _8696.y > 0.0f.xx.y));
                bool _7928;
                if (_7922)
                {
                    _7928 = all(bool2(_8696.x < 1.0f.xx.x, _8696.y < 1.0f.xx.y));
                }
                else
                {
                    _7928 = _7922;
                }
                _4647 = _7928;
            }
            else
            {
                _4647 = _4642;
            }
            bool _4652;
            if (_4647)
            {
                bool _7933 = all(bool2(_8698.x > 0.0f.xx.x, _8698.y > 0.0f.xx.y));
                bool _7939;
                if (_7933)
                {
                    _7939 = all(bool2(_8698.x < 1.0f.xx.x, _8698.y < 1.0f.xx.y));
                }
                else
                {
                    _7939 = _7933;
                }
                _4652 = _7939;
            }
            else
            {
                _4652 = _4647;
            }
            float4 _9365;
            if (_4652)
            {
                float _4658 = _9347.x + _9347.y;
                float _4667 = (_9347.z + _9347.w) * (1.0f - _10209);
                float _9361;
                if (_4658 > 9.9999997473787516355514526367188e-06f)
                {
                    _9361 = _9347.x / _4658;
                }
                else
                {
                    _9361 = _3864;
                }
                _9365 = float4(_9347.x + (_4667 * _9361), _9347.y + (_4667 * (1.0f - _9361)), _9347.zw * _10209);
            }
            else
            {
                _9365 = _9347;
            }
            _9823 = _10209;
            _9797 = _4572;
            _9770 = _9177;
            _9364 = _9365;
        }
        else
        {
            _9823 = 1.0f;
            _9797 = 1.0f;
            _9770 = 1.0f;
            _9364 = _9347;
        }
        float3 _9979;
        if (_9367)
        {
            float3 _7945 = r_current_interpolation_source.Load(int3(_3293, 0)).xyz;
            float3 _9980;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6233)
            {
                uint _7952_dummy_parameter;
                float _9467;
                _9467 = r_depth_tm1.Load(int3(int2(floor(_8696 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7952_dummy_parameter))))), 0)).x;
                float _4779;
                for (int _9466 = 0; _9466 < 24; _9467 = _4779, _9466++)
                {
                    float _4751 = float(_9466 & 7) * 0.785398185253143310546875f;
                    int _4753 = _9466 >> 3;
                    int _10029;
                    if (_4753 == 0)
                    {
                        _10029 = 16;
                    }
                    else
                    {
                        _10029 = (_4753 == 1) ? 48 : 96;
                    }
                    uint _7972_dummy_parameter;
                    _4779 = max(_9467, r_depth_tm1.Load(int3(int2(floor(clamp(_8696 + ((cbFI_MvDepthLaneSizeRcp * float(_10029)) * float2(cos(_4751), sin(_4751))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7972_dummy_parameter))))), 0)).x);
                }
                float2 _9468;
                do
                {
                    float _7994 = 1.0f - _8696.y;
                    float4 _8005 = mul(float4((float2(_8696.x, _7994) * 2.0f) - 1.0f.xx, _9467, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8007 = _8005.w;
                    if (!(_8007 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9468 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8020 = ((_8005.xy / _8007.xx) + 1.0f.xx) * 0.5f;
                    _9468 = float2(_8020.x - _8696.x, _7994 - _8020.y);
                    break;
                } while(false);
                float2 _4790 = _8696 + _9468;
                bool _8038 = all(bool2(_4790.x > 0.0f.xx.x, _4790.y > 0.0f.xx.y));
                bool _8044;
                if (_8038)
                {
                    _8044 = all(bool2(_4790.x < 1.0f.xx.x, _4790.y < 1.0f.xx.y));
                }
                else
                {
                    _8044 = _8038;
                }
                float3 _9981;
                if (_8044)
                {
                    float _4796 = abs(cbFI_DeviceToViewDepth.y / (_9467 - cbFI_DeviceToViewDepth.x));
                    uint _8064_dummy_parameter;
                    int2 _8064 = int2(spvTextureSize(r_depth_m2, uint(0), _8064_dummy_parameter));
                    float _4800 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4790 * float2(_8064))), int2(0, 0), _8064 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _9986;
                    if (abs(_4800 - _4796) <= (0.20000000298023223876953125f * max(_4800, _4796)))
                    {
                        uint _8098_dummy_parameter;
                        int2 _8098 = int2(spvTextureSize(r_colour_m2, uint(0), _8098_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8121;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8121);
                        }
                        _9986 = r_colour_m2.Load(int3(clamp(int2(floor(_4790 * float2(_8098))), int2(0, 0), _8098 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8131;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8131);
                        }
                        _9986 = _7945;
                    }
                    _9981 = _9986;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8141;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8141);
                    }
                    _9981 = _7945;
                }
                _9980 = _9981;
            }
            else
            {
                _9980 = _7945;
            }
            _9979 = _9980;
        }
        else
        {
            _9979 = (((_6024 * _9364.x) + (_6032 * _9364.y)) + (_6040 * _9364.z)) + (_6048 * _9364.w);
        }
        uint _4828 = cbFI_pad0 & 255u;
        bool _9874;
        float3 _9978;
        if (_4828 != 0u)
        {
            float3 _4833 = r_present_backbuffer.Load(int3(_3293, 0)).xyz;
            float3 _4837 = r_current_interpolation_source.Load(int3(_3293, 0)).xyz;
            float3 _4841 = abs(_4833 - _4837);
            float3 _9471;
            if (_4828 == 2u)
            {
                _9471 = (abs(_4837) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9471 = 0.000244140625f.xxx;
            }
            bool _4857 = any(bool3(_4841.x > _9471.x, _4841.y > _9471.y, _4841.z > _9471.z));
            bool3 _10210 = _4857.xxx;
            _9978 = float3(_10210.x ? _4833.x : _9979.x, _10210.y ? _4833.y : _9979.y, _10210.z ? _4833.z : _9979.z);
            _9874 = _4857;
        }
        else
        {
            _9978 = _9979;
            _9874 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8156;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8156);
        }
        float3 _9962;
        if (_4545 == 1u)
        {
            _9962 = lerp(_6024, _6032, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _9963;
            if (_4545 == 2u)
            {
                _9963 = lerp(_6040, _6048, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _9964;
                if (_4545 == 3u)
                {
                    _9964 = float(_9874).xxx;
                }
                else
                {
                    float3 _9965;
                    if (_4545 == 4u)
                    {
                        _9965 = float3(((_8694 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _9966;
                        if (_4545 == 5u)
                        {
                            _9966 = float3(((_5319 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _9967;
                            if (_4545 == 6u)
                            {
                                _9967 = float3(_9364.xy, _9364.z + _9364.w);
                            }
                            else
                            {
                                float3 _9968;
                                if (_4545 == 7u)
                                {
                                    _9968 = r_current_interpolation_source.Load(int3(_3293, 0)).xyz;
                                }
                                else
                                {
                                    float3 _9969;
                                    if (_4545 == 8u)
                                    {
                                        _9969 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3639, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _9970;
                                        if (_4549)
                                        {
                                            _9970 = float3(_9770, _9797, _9823);
                                        }
                                        else
                                        {
                                            float3 _9971;
                                            if (_4552)
                                            {
                                                _9971 = _6040;
                                            }
                                            else
                                            {
                                                float3 _9972;
                                                if (_4545 == 20u)
                                                {
                                                    _9972 = _6024;
                                                }
                                                else
                                                {
                                                    float3 _9973;
                                                    if (_4545 == 21u)
                                                    {
                                                        _9973 = _6032;
                                                    }
                                                    else
                                                    {
                                                        float3 _9974;
                                                        if (_4545 == 22u)
                                                        {
                                                            _9974 = _6048;
                                                        }
                                                        else
                                                        {
                                                            float3 _9975;
                                                            if (_4545 == 18u)
                                                            {
                                                                _9975 = _9617;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10212 = (_4545 == 19u).xxx;
                                                                _9975 = float3(_10212.x ? _9477.x : _9978.x, _10212.y ? _9477.y : _9978.y, _10212.z ? _9477.z : _9978.z);
                                                            }
                                                            _9974 = _9975;
                                                        }
                                                        _9973 = _9974;
                                                    }
                                                    _9972 = _9973;
                                                }
                                                _9971 = _9972;
                                            }
                                            _9970 = _9971;
                                        }
                                        _9969 = _9970;
                                    }
                                    _9968 = _9969;
                                }
                                _9967 = _9968;
                            }
                            _9966 = _9967;
                        }
                        _9965 = _9966;
                    }
                    _9964 = _9965;
                }
                _9963 = _9964;
            }
            _9962 = _9963;
        }
        float3 _9961;
        if ((_4545 >= 9u) && (_4545 <= 11u))
        {
            uint _5012 = 64u + uint((_8726.y * cbFI_MvDepthLaneSize.x) + _8726.x);
            uint _5016 = rw_nfru_diagnostics.Load<uint>(_5012 * 4 + 0) & 15u;
            float3 _9991;
            if (_4545 == 10u)
            {
                float3 _9960;
                if ((rw_nfru_diagnostics.Load<uint>(_5012 * 4 + 0) & 32u) != 0u)
                {
                    _9960 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _9959;
                    if ((rw_nfru_diagnostics.Load<uint>(_5012 * 4 + 0) & 16u) != 0u)
                    {
                        _9959 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5037 = ((rw_nfru_diagnostics.Load<uint>(_5012 * 4 + 0) & 64u) != 0u).xxx;
                        _9959 = float3(_5037.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5037.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5037.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _9960 = _9959;
                }
                _9991 = _9960;
            }
            else
            {
                float3 _9992;
                if (_4545 == 11u)
                {
                    uint _5050 = (rw_nfru_diagnostics.Load<uint>(_5012 * 4 + 0) >> 8u) & 15u;
                    uint _5053 = (rw_nfru_diagnostics.Load<uint>(_5012 * 4 + 0) >> 12u) & 15u;
                    float3 _9952;
                    if ((_5016 == 2u) || (_5016 == 3u))
                    {
                        _9952 = _3006[_5016];
                    }
                    else
                    {
                        bool _5065 = _5050 == 3u;
                        bool _5067 = _5053 == 3u;
                        float3 _9953;
                        if (_5065 && _5067)
                        {
                            _9953 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _9954;
                            if (_5065)
                            {
                                _9954 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _9955;
                                if (_5067)
                                {
                                    _9955 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _9956;
                                    if ((_5050 == 4u) || (_5053 == 4u))
                                    {
                                        _9956 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _9957;
                                        if ((_5050 == 1u) || (_5053 == 1u))
                                        {
                                            _9957 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10214 = (_5016 == 1u).xxx;
                                            _9957 = float3(_10214.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10214.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10214.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _9956 = _9957;
                                    }
                                    _9955 = _9956;
                                }
                                _9954 = _9955;
                            }
                            _9953 = _9954;
                        }
                        _9952 = _9953;
                    }
                    _9992 = _9952;
                }
                else
                {
                    _9992 = _3006[min(_5016, 7u)];
                }
                _9991 = _9992;
            }
            _9961 = _9991;
        }
        else
        {
            _9961 = _9962;
        }
        float4 _9995;
        if ((_4545 >= 14u) && (_4545 <= 16u))
        {
            float2 _9993;
            if (_4545 == 14u)
            {
                uint _5123_dummy_parameter;
                uint _5129_dummy_parameter;
                _9993 = r_flow_tm1.Load(int3(clamp(int2(floor(_3639 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5123_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5129_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _9994;
                if (_4545 == 16u)
                {
                    uint _8197 = r_warped_flow_qdata_tm1.Load(int3(_3655, 0)).x & 2147483647u;
                    uint _8229 = uint(max((int((_8197 >> 16u) & 15u) - 6), 0));
                    _9994 = ((float2(float((1 - (2 * int((_8197 >> 15u) & 1u))) * int(((_8197 >> uint(7)) & 127u) << _8229)), float((1 - (2 * int((_8197 >> 14u) & 1u))) * int((_8197 & 127u) << _8229))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _9994 = _5319 * float2(cbFI_DisplaySize);
                }
                _9993 = _9994;
            }
            uint2 _5162 = uint2(clamp(round(_9993 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5164 = _5162.x;
            uint _5171 = _5162.y;
            _9995 = float4(float(_5164 & 255u), float((_5164 >> 8u) | ((_5171 & 15u) << 4u)), float(_5171 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _9996;
            if (_4545 == 17u)
            {
                _9996 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3655, 0)).x != 0u), _3998, 0.0f, 1.0f);
            }
            else
            {
                _9996 = float4(_9961, 1.0f);
            }
            _9995 = _9996;
        }
        rw_output[_3293] = _9995.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5215 = ((uint(_3293.y) * uint(cbFI_DisplaySize.x)) + uint(_3293.x)) * 6u;
            uint _8275 = spvPackHalf2x16(clamp(_6023.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5215 * 4 + 0, (((_8275 & 32767u) >> 4u) | ((((_8275 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6023.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8310 = spvPackHalf2x16(clamp(_6031.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5215 + 1u) * 4 + 0, (((_8310 & 32767u) >> 4u) | ((((_8310 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6031.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8345 = spvPackHalf2x16(clamp(_6039.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5215 + 2u) * 4 + 0, (((_8345 & 32767u) >> 4u) | ((((_8345 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6039.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8380 = spvPackHalf2x16(clamp(_6047.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5215 + 3u) * 4 + 0, (((_8380 & 32767u) >> 4u) | ((((_8380 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6047.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8407 = r_current_interpolation_source.Load(int3(_3293, 0));
            uint _8421 = spvPackHalf2x16(clamp(_8407.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5215 + 4u) * 4 + 0, (((_8421 & 32767u) >> 4u) | ((((_8421 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8407.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10028;
            if (_9874 || (_4545 != 0u))
            {
                _10028 = 4294967295u;
            }
            else
            {
                uint _8456 = spvPackHalf2x16(clamp(_9995.xy, 0.0f.xx, 65000.0f.xx));
                _10028 = (((_8456 & 32767u) >> 4u) | ((((_8456 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9995.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5215 + 5u) * 4 + 0, _10028);
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
