static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3096[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3383 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3383.x >= cbFI_DisplaySize.x, _3383.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3383] = float4(r_present_backbuffer.Load(int3(_3383, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3745 = (float2(_3383) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3756 = int2(floor(_3745 * float2(cbFI_MvDepthLaneSize)));
        int2 _3761 = int2(floor(_3745 * float2(cbFI_FlowLaneSize)));
        float4 _5491 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3745 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5497 = r_warped_filled_flow_tm1.Load(int3(_3761, 0)).xy;
        float2 _5503 = r_warped_filled_motion_tp1.Load(int3(_3756, 0)).xy;
        bool _5525 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9043;
        if (_5525)
        {
            float _5538 = ((2.0f * _3745.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9043 = float2(atan(_5538) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3745.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5538 * _5538))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9043 = _3745;
        }
        bool _3782 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9064;
        bool _9085;
        int2 _9096;
        float3 _10163;
        if (_3782)
        {
            float _9045;
            float _9047;
            _9047 = 2.0f;
            _9045 = -1.0f;
            uint _3445[9];
            float _10557;
            float _10560;
            for (int _9044 = 0; _9044 < 9; _9047 = _10560, _9045 = _10557, _9044++)
            {
                _3445[_9044] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3756 + int2((_9044 % 3) - 1, (_9044 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3445[_9044] != 0u)
                {
                    float _10552;
                    if (_3445[_9044] == 0u)
                    {
                        _10552 = -1.0f;
                    }
                    else
                    {
                        _10552 = float((_3445[_9044] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10560 = min(_9047, _10552);
                    _10557 = max(_9045, _10552);
                }
                else
                {
                    _10560 = _9047;
                    _10557 = _9045;
                }
            }
            float _3828 = float(_9045 >= 0.0f);
            float3 _8854 = 0.0f.xxx;
            _8854.y = _3828;
            float2 _9065;
            bool _9086;
            int2 _9097;
            float3 _10164;
            if ((_9045 - _9047) > 0.0199999995529651641845703125f)
            {
                float _9053;
                int2 _9054;
                float2 _9055;
                int2 _9057;
                float2 _9063;
                _9063 = _5503;
                _9057 = _3756;
                _9055 = _5503;
                _9054 = _3756;
                _9053 = -1.0f;
                float _10565;
                int2 _10569;
                float2 _10580;
                int2 _10591;
                float2 _10624;
                float _10670;
                int _9052 = 0;
                float _10533 = 1000000000.0f;
                for (; _9052 < 9; _10533 = _10670, _9063 = _10624, _9057 = _10591, _9055 = _10580, _9054 = _10569, _9053 = _10565, _9052++)
                {
                    if (_3445[_9052] == 0u)
                    {
                        _10670 = _10533;
                        _10624 = _9063;
                        _10591 = _9057;
                        _10580 = _9055;
                        _10569 = _9054;
                        _10565 = _9053;
                        continue;
                    }
                    int2 _3863 = clamp(_3756 + int2((_9052 % 3) - 1, (_9052 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5613 = _3445[_9052] & 2147483647u;
                    uint _5645 = uint(max((int((_5613 >> 16u) & 15u) - 6), 0));
                    float2 _3869 = (float2(float((1 - (2 * int((_5613 >> 15u) & 1u))) * int(((_5613 >> uint(7)) & 127u) << _5645)), float((1 - (2 * int((_5613 >> 14u) & 1u))) * int((_5613 & 127u) << _5645))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10519;
                    if (_3445[_9052] == 0u)
                    {
                        _10519 = -1.0f;
                    }
                    else
                    {
                        _10519 = float((_3445[_9052] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3874 = _10519 - 0.100000001490116119384765625f;
                    float2 _10520;
                    if (_5525)
                    {
                        float2 _5722 = clamp((((_9043 + (_3869 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5725 = tan(_5722.x);
                        _10520 = (float2(_5725 / cbFI_DeviceToViewDepth.z, (tan(_5722.y) * sqrt(1.0f + (_5725 * _5725))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10520 = _9043 + (_3869 * cbFI_Timestep);
                    }
                    float _3881 = cbFI_Timestep - 1.0f;
                    float2 _10521;
                    if (_5525)
                    {
                        float2 _5793 = clamp((((_9043 + (_3869 * _3881)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5796 = tan(_5793.x);
                        _10521 = (float2(_5796 / cbFI_DeviceToViewDepth.z, (tan(_5793.y) * sqrt(1.0f + (_5796 * _5796))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10521 = _9043 + (_3869 * _3881);
                    }
                    bool _5829 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                    bool _5835;
                    if (_5829)
                    {
                        _5835 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5835 = _5829;
                    }
                    float _10524;
                    if (_5835)
                    {
                        uint _5842_dummy_parameter;
                        _10524 = max((_3874 - (log((r_depth_tm1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5842_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10524 = 0.0f;
                    }
                    bool _5872 = all(bool2(_10521.x > 0.0f.xx.x, _10521.y > 0.0f.xx.y));
                    bool _5878;
                    if (_5872)
                    {
                        _5878 = all(bool2(_10521.x < 1.0f.xx.x, _10521.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5878 = _5872;
                    }
                    float _10525;
                    if (_5878)
                    {
                        uint _5885_dummy_parameter;
                        _10525 = _10524 + max((_3874 - (log((r_depth_tp1.Load(int3(int2(floor(_10521 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5885_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10525 = _10524;
                    }
                    float _10566;
                    int2 _10570;
                    float2 _10581;
                    int2 _10592;
                    float2 _10625;
                    float _10671;
                    if (_10525 == 0.0f)
                    {
                        bool _3916 = _3874 > _9053;
                        bool2 _10679 = _3916.xx;
                        _10671 = _10533;
                        _10625 = float2(_10679.x ? _3869.x : _9063.x, _10679.y ? _3869.y : _9063.y);
                        _10592 = int2(_10679.x ? _3863.x : _9057.x, _10679.y ? _3863.y : _9057.y);
                        _10581 = _9055;
                        _10570 = _9054;
                        _10566 = _3916 ? _3874 : _9053;
                    }
                    else
                    {
                        bool _3925 = _10525 < _10533;
                        bool2 _10675 = _3925.xx;
                        _10671 = _3925 ? _10525 : _10533;
                        _10625 = _9063;
                        _10592 = _9057;
                        _10581 = float2(_10675.x ? _3869.x : _9055.x, _10675.y ? _3869.y : _9055.y);
                        _10570 = int2(_10675.x ? _3863.x : _9054.x, _10675.y ? _3863.y : _9054.y);
                        _10566 = _9053;
                    }
                    _10670 = _10671;
                    _10624 = _10625;
                    _10591 = _10592;
                    _10580 = _10581;
                    _10569 = _10570;
                    _10565 = _10566;
                }
                bool _3937 = _9053 < 0.0f;
                bool2 _10685 = _3937.xx;
                int2 _10688 = int2(_10685.x ? _9054.x : _9057.x, _10685.y ? _9054.y : _9057.y);
                _10164 = float3(1.0f, _3828, float(any(bool2(_10688.x != _3756.x, _10688.y != _3756.y))));
                _9097 = _10688;
                _9086 = _3937 ? false : true;
                _9065 = float2(_10685.x ? _9055.x : _9063.x, _10685.y ? _9055.y : _9063.y);
            }
            else
            {
                _10164 = _8854;
                _9097 = _3756;
                _9086 = false;
                _9065 = _5503;
            }
            _10163 = _10164;
            _9096 = _9097;
            _9085 = _9086;
            _9064 = _9065;
        }
        else
        {
            _10163 = 0.0f.xxx;
            _9096 = _3756;
            _9085 = false;
            _9064 = _5503;
        }
        float2 _9066;
        if (_5525)
        {
            float2 _5950 = clamp((((_9043 + (_9064 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5953 = tan(_5950.x);
            _9066 = (float2(_5953 / cbFI_DeviceToViewDepth.z, (tan(_5950.y) * sqrt(1.0f + (_5953 * _5953))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9066 = _9043 + (_9064 * cbFI_Timestep);
        }
        float _3960 = cbFI_Timestep - 1.0f;
        float2 _9068;
        if (_5525)
        {
            float2 _6021 = clamp((((_9043 + (_9064 * _3960)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6024 = tan(_6021.x);
            _9068 = (float2(_6024 / cbFI_DeviceToViewDepth.z, (tan(_6021.y) * sqrt(1.0f + (_6024 * _6024))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9068 = _9043 + (_9064 * _3960);
        }
        float _3965 = -cbFI_Timestep;
        float2 _9069;
        if (_5525)
        {
            float2 _6092 = clamp((((_9043 + (_5497 * _3965)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6095 = tan(_6092.x);
            _9069 = (float2(_6095 / cbFI_DeviceToViewDepth.z, (tan(_6092.y) * sqrt(1.0f + (_6095 * _6095))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9069 = _9043 + (_5497 * _3965);
        }
        float _3970 = 1.0f - cbFI_Timestep;
        float2 _9070;
        if (_5525)
        {
            float2 _6163 = clamp((((_9043 + (_5497 * _3970)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6166 = tan(_6163.x);
            _9070 = (float2(_6166 / cbFI_DeviceToViewDepth.z, (tan(_6163.y) * sqrt(1.0f + (_6166 * _6166))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9070 = _9043 + (_5497 * _3970);
        }
        float4 _6201 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9066, 0.0f);
        float3 _6202 = _6201.xyz;
        float4 _6209 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9068, 0.0f);
        float3 _6210 = _6209.xyz;
        float4 _6217 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9069, 0.0f);
        float3 _6218 = _6217.xyz;
        float4 _6225 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9070, 0.0f);
        float3 _6226 = _6225.xyz;
        float4 _6240 = exp(_5491 - max(max(max(_5491.x, _5491.y), _5491.z), _5491.w).xxxx);
        float4 _6247 = _6240 / (dot(_6240, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3989 = _3782 && (!_9085);
        bool _3998;
        if (_3989)
        {
            _3998 = (_6247.z + _6247.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3998 = _3989;
        }
        bool _4009;
        if (_3998)
        {
            _4009 = length((_9069 - _9066) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4009 = _3998;
        }
        bool _9109;
        if (_4009)
        {
            uint4 _6266 = r_warped_motion_qdata_tp1.Load(int3(_9096, 0));
            uint _6267 = _6266.x;
            bool _9112;
            if (_6267 != 0u)
            {
                float _9098;
                if (_6267 == 0u)
                {
                    _9098 = -1.0f;
                }
                else
                {
                    _9098 = float((_6267 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4019 = _9098 - 0.12000000476837158203125f;
                bool _6286 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
                bool _6292;
                if (_6286)
                {
                    _6292 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
                }
                else
                {
                    _6292 = _6286;
                }
                bool _4029;
                if (_6292)
                {
                    uint _6299_dummy_parameter;
                    _4029 = (log((r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6299_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4019;
                }
                else
                {
                    _4029 = _6292;
                }
                bool _4043;
                if (!_4029)
                {
                    bool _6329 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
                    bool _6335;
                    if (_6329)
                    {
                        _6335 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6335 = _6329;
                    }
                    bool _4041;
                    if (_6335)
                    {
                        uint _6342_dummy_parameter;
                        _4041 = (log((r_depth_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6342_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4019;
                    }
                    else
                    {
                        _4041 = _6335;
                    }
                    _4043 = _4041;
                }
                else
                {
                    _4043 = _4029;
                }
                _9112 = _4043;
            }
            else
            {
                _9112 = false;
            }
            _9109 = _9112;
        }
        else
        {
            _9109 = false;
        }
        bool _4048 = _9085 || _9109;
        bool _4053;
        if (_4048)
        {
            bool _6372 = all(bool2(_9066.x > 0.0f.xx.x, _9066.y > 0.0f.xx.y));
            bool _6378;
            if (_6372)
            {
                _6378 = all(bool2(_9066.x < 1.0f.xx.x, _9066.y < 1.0f.xx.y));
            }
            else
            {
                _6378 = _6372;
            }
            _4053 = _6378;
        }
        else
        {
            _4053 = _4048;
        }
        bool _4058;
        if (_4053)
        {
            bool _6383 = all(bool2(_9068.x > 0.0f.xx.x, _9068.y > 0.0f.xx.y));
            bool _6389;
            if (_6383)
            {
                _6389 = all(bool2(_9068.x < 1.0f.xx.x, _9068.y < 1.0f.xx.y));
            }
            else
            {
                _6389 = _6383;
            }
            _4058 = _6389;
        }
        else
        {
            _4058 = _4053;
        }
        float4 _9206;
        if (_4058)
        {
            float _4061 = _6247.x;
            float _4063 = _6247.y;
            float _4064 = _4061 + _4063;
            float _4069 = _6247.z + _6247.w;
            float _9127;
            if (_4064 > 0.001000000047497451305389404296875f)
            {
                _9127 = _4061 / _4064;
            }
            else
            {
                _9127 = _3970;
            }
            _9206 = float4(_4061 + (_4069 * _9127), _4063 + (_4069 * (1.0f - _9127)), 0.0f, 0.0f);
        }
        else
        {
            _9206 = _6247;
        }
        bool _6417 = (cbFI_pad0 & 1024u) != 0u;
        bool _6393 = !_6417;
        bool _6394 = !_6393;
        bool _6411;
        if (_6394)
        {
            _6411 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9096.y * cbFI_MvDepthLaneSize.x) + _9096.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6411 = _6393;
        }
        bool _6443;
        if (_6394)
        {
            _6443 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3761.y * cbFI_FlowLaneSize.x) + _3761.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6443 = _6393;
        }
        float _4104 = float(_6443);
        bool _9219;
        float4 _9250;
        float3 _10017;
        if (_6417)
        {
            bool _4114;
            if (_6411)
            {
                _4114 = all(bool2(_9066.x > 0.0f.xx.x, _9066.y > 0.0f.xx.y));
            }
            else
            {
                _4114 = _6411;
            }
            bool _4120;
            if (_4114)
            {
                _4120 = all(bool2(_9066.x < 1.0f.xx.x, _9066.y < 1.0f.xx.y));
            }
            else
            {
                _4120 = _4114;
            }
            bool _4127;
            if (_6411)
            {
                _4127 = all(bool2(_9068.x > 0.0f.xx.x, _9068.y > 0.0f.xx.y));
            }
            else
            {
                _4127 = _6411;
            }
            bool _4133;
            if (_4127)
            {
                _4133 = all(bool2(_9068.x < 1.0f.xx.x, _9068.y < 1.0f.xx.y));
            }
            else
            {
                _4133 = _4127;
            }
            bool _4140;
            if (_6443)
            {
                _4140 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
            }
            else
            {
                _4140 = _6443;
            }
            bool _4146;
            if (_4140)
            {
                _4146 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
            }
            else
            {
                _4146 = _4140;
            }
            bool _4153;
            if (_6443)
            {
                _4153 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
            }
            else
            {
                _4153 = _6443;
            }
            bool _4159;
            if (_4153)
            {
                _4159 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
            }
            else
            {
                _4159 = _4153;
            }
            bool _4161 = !_6411;
            if (_4161)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6485;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6485);
                }
            }
            bool _4166 = !_6443;
            if (_4166)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6495;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6495);
                }
            }
            if (_6411 && _4166)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6505;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6505);
                }
            }
            if (_4161 && _6443)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6515;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6515);
                }
            }
            float _4185 = float(_4120);
            float _4187 = float(_4133);
            bool _4190 = _4146 && _4159;
            float _9161;
            if (_4190)
            {
                _9161 = 1.0f;
            }
            else
            {
                _9161 = (_4146 || _4159) ? 0.5f : 0.0f;
            }
            bool _9166;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4120)) && (!_4133))
            {
                bool _4220;
                if (_4190)
                {
                    float _9164;
                    do
                    {
                        bool _6599 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
                        bool _6605;
                        if (_6599)
                        {
                            _6605 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6605 = _6599;
                        }
                        bool _6536 = !_6605;
                        bool _6543;
                        if (!_6536)
                        {
                            bool _6610 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
                            bool _6616;
                            if (_6610)
                            {
                                _6616 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6616 = _6610;
                            }
                            _6543 = !_6616;
                        }
                        else
                        {
                            _6543 = _6536;
                        }
                        if (_6543)
                        {
                            _9164 = 0.0f;
                            break;
                        }
                        uint _6623_dummy_parameter;
                        uint _6639_dummy_parameter;
                        float4 _6564 = mul(float4((float2(_9069.x, 1.0f - _9069.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6623_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6566 = _6564.w;
                        if (abs(_6566) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9164 = 0.0f;
                            break;
                        }
                        float _6577 = abs(cbFI_DeviceToViewDepth.y / ((_6564.z / _6566) - cbFI_DeviceToViewDepth.x));
                        float _6580 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6639_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9164 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6577 - _6580) / max(max(_6577, _6580), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4220 = _9164 >= 0.5f;
                }
                else
                {
                    _4220 = _4190;
                }
                bool _4228;
                if (_4220)
                {
                    _4228 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4228 = _4220;
                }
                bool _9167;
                if (_4228)
                {
                    uint _6689_dummy_parameter;
                    float2 _9165;
                    do
                    {
                        float _6715 = 1.0f - _9069.y;
                        float4 _6726 = mul(float4((float2(_9069.x, _6715) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6689_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6728 = _6726.w;
                        if (!(_6728 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9165 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6741 = ((_6726.xy / _6728.xx) + 1.0f.xx) * 0.5f;
                        _9165 = float2(_6741.x - _9069.x, _6715 - _6741.y);
                        break;
                    } while(false);
                    float2 _4241 = float2(cbFI_DisplaySize);
                    _9167 = length(((_9069 + _9165) - _9070) * _4241) <= ((0.100000001490116119384765625f * length(_9165 * _4241)) + 8.0f);
                }
                else
                {
                    _9167 = _4220;
                }
                _9166 = _9167;
            }
            else
            {
                _9166 = true;
            }
            bool _4255 = !_9166;
            bool _10689 = _4255 ? false : _4159;
            bool _10690 = _4255 ? false : _4146;
            bool _9220;
            float4 _9251;
            if (!(((_4120 && _4133) && _10690) && _10689))
            {
                float4 _4277 = _9206 * float4(_4185, _4187, float(_10690), float(_10689));
                float _4279 = dot(_4277, 1.0f.xxxx);
                bool _4282 = !(_4279 > 0.0f);
                float4 _9252;
                if (!_4282)
                {
                    _9252 = _4277 / _4279.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6763;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6763);
                    }
                    _9252 = 0.0f.xxxx;
                }
                _9251 = _9252;
                _9220 = _4282;
            }
            else
            {
                _9251 = _9206;
                _9220 = false;
            }
            _10017 = float3(_4185, _4187, _9161);
            _9250 = _9251;
            _9219 = _9220;
        }
        else
        {
            _10017 = float3(float(_6411), _4104, 0.0f);
            _9250 = _9206;
            _9219 = false;
        }
        float4 _9744;
        bool _9764;
        float3 _9878;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9219))
        {
            bool _4305 = _9250.x > 0.00999999977648258209228515625f;
            bool _4308 = _9250.y > 0.00999999977648258209228515625f;
            bool _4317 = (_9250.z + _9250.w) > 0.0199999995529651641845703125f;
            bool _4323;
            if (_4317)
            {
                bool _6769 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
                bool _6775;
                if (_6769)
                {
                    _6775 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
                }
                else
                {
                    _6775 = _6769;
                }
                _4323 = _6775;
            }
            else
            {
                _4323 = _4317;
            }
            bool _4328;
            if (_4323)
            {
                bool _6780 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
                bool _6786;
                if (_6780)
                {
                    _6786 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
                }
                else
                {
                    _6786 = _6780;
                }
                _4328 = _6786;
            }
            else
            {
                _4328 = _4323;
            }
            bool _4335;
            if (_4328)
            {
                float _9254;
                do
                {
                    bool _6869 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
                    bool _6875;
                    if (_6869)
                    {
                        _6875 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6875 = _6869;
                    }
                    bool _6806 = !_6875;
                    bool _6813;
                    if (!_6806)
                    {
                        bool _6880 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
                        bool _6886;
                        if (_6880)
                        {
                            _6886 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6886 = _6880;
                        }
                        _6813 = !_6886;
                    }
                    else
                    {
                        _6813 = _6806;
                    }
                    if (_6813)
                    {
                        _9254 = 0.0f;
                        break;
                    }
                    uint _6893_dummy_parameter;
                    uint _6909_dummy_parameter;
                    float4 _6834 = mul(float4((float2(_9069.x, 1.0f - _9069.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6893_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6836 = _6834.w;
                    if (abs(_6836) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9254 = 0.0f;
                        break;
                    }
                    float _6847 = abs(cbFI_DeviceToViewDepth.y / ((_6834.z / _6836) - cbFI_DeviceToViewDepth.x));
                    float _6850 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6909_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9254 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6847 - _6850) / max(max(_6847, _6850), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4335 = _9254 < 0.5f;
            }
            else
            {
                _4335 = _4328;
            }
            float4 _9269;
            if (_4335)
            {
                uint _6959_dummy_parameter;
                uint _6990_dummy_parameter;
                float4 _9270;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6959_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6990_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9270 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9270 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9269 = _9270;
            }
            else
            {
                _9269 = 1.0f.xxxx;
            }
            bool _4359;
            if (_6411)
            {
                bool _7019 = all(bool2(_9066.x > 0.0f.xx.x, _9066.y > 0.0f.xx.y));
                bool _7025;
                if (_7019)
                {
                    _7025 = all(bool2(_9066.x < 1.0f.xx.x, _9066.y < 1.0f.xx.y));
                }
                else
                {
                    _7025 = _7019;
                }
                _4359 = _7025;
            }
            else
            {
                _4359 = _6411;
            }
            bool _4365;
            if (_6411)
            {
                bool _7030 = all(bool2(_9068.x > 0.0f.xx.x, _9068.y > 0.0f.xx.y));
                bool _7036;
                if (_7030)
                {
                    _7036 = all(bool2(_9068.x < 1.0f.xx.x, _9068.y < 1.0f.xx.y));
                }
                else
                {
                    _7036 = _7030;
                }
                _4365 = _7036;
            }
            else
            {
                _4365 = _6411;
            }
            bool _4371;
            if (_6443)
            {
                bool _7041 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
                bool _7047;
                if (_7041)
                {
                    _7047 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
                }
                else
                {
                    _7047 = _7041;
                }
                _4371 = _7047;
            }
            else
            {
                _4371 = _6443;
            }
            bool _4377;
            if (_6443)
            {
                bool _7052 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
                bool _7058;
                if (_7052)
                {
                    _7058 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
                }
                else
                {
                    _7058 = _7052;
                }
                _4377 = _7058;
            }
            else
            {
                _4377 = _6443;
            }
            bool _4380 = _4371 != _4377;
            bool _4386;
            if (_4380)
            {
                _4386 = _4359 || _4365;
            }
            else
            {
                _4386 = _4380;
            }
            float4 _9352;
            if (_4386)
            {
                float4 _8939 = _9269;
                _8939.z = 0.0f;
                _8939.w = 0.0f;
                _9352 = _8939;
            }
            else
            {
                _9352 = _9269;
            }
            bool _4393 = _4359 && _4305;
            bool _4396 = _4365 && _4308;
            float4 _9457;
            float3 _9917;
            if (_4393 || _4396)
            {
                float _9347;
                do
                {
                    uint4 _7197 = r_warped_motion_qdata_tp1.Load(int3(_9096, 0));
                    uint _7198 = _7197.x;
                    if (_7198 != 0u)
                    {
                        float _9346;
                        if (_7198 == 0u)
                        {
                            _9346 = -1.0f;
                        }
                        else
                        {
                            _9346 = float((_7198 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9347 = _9346;
                        break;
                    }
                    int _9329;
                    uint _9330;
                    _9330 = _7198;
                    _9329 = -1;
                    uint _9345;
                    for (; _9329 <= 1; _9330 = _9345, _9329++)
                    {
                        _9345 = _9330;
                        for (int _9343 = -1; _9343 <= 1; )
                        {
                            _9345 = max(_9345, r_warped_motion_qdata_tp1.Load(int3(clamp(_9096 + int2(_9343, _9329), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9343++;
                            continue;
                        }
                    }
                    if (_9330 != 0u)
                    {
                        float _9342;
                        if (_9330 == 0u)
                        {
                            _9342 = -1.0f;
                        }
                        else
                        {
                            _9342 = float((_9330 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9347 = _9342;
                        break;
                    }
                    uint _9332;
                    _9332 = 4294967295u;
                    uint _10661;
                    for (int _9331 = 0; _9331 < 8; _9332 = _10661, _9331++)
                    {
                        int _9335 = 0;
                        for (;;)
                        {
                            if (_9335 < 5)
                            {
                                int2 _7148 = _9096 + (_1085[_9331] * _1094[_9335].xx);
                                bool _7151 = any(bool2(_7148.x < int2(0, 0).x, _7148.y < int2(0, 0).y));
                                bool _7159;
                                if (!_7151)
                                {
                                    _7159 = any(bool2(_7148.x >= cbFI_MvDepthLaneSize.x, _7148.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7159 = _7151;
                                }
                                if (_7159)
                                {
                                    _10661 = _9332;
                                    break;
                                }
                                uint4 _7237 = r_warped_motion_qdata_tp1.Load(int3(_7148, 0));
                                uint _7238 = _7237.x;
                                if (_7238 != 0u)
                                {
                                    _10661 = min(_9332, _7238);
                                    break;
                                }
                                _9335++;
                                continue;
                            }
                            else
                            {
                                _10661 = _9332;
                                break;
                            }
                        }
                    }
                    float _9334;
                    if (_9332 == 4294967295u)
                    {
                        _9334 = -1.0f;
                    }
                    else
                    {
                        float _9333;
                        if (_9332 == 0u)
                        {
                            _9333 = -1.0f;
                        }
                        else
                        {
                            _9333 = float((_9332 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9334 = _9333;
                    }
                    _9347 = _9334;
                    break;
                } while(false);
                bool _4404 = _9347 < 0.0f;
                float _9348;
                if (_4404)
                {
                    _9348 = 0.0f;
                }
                else
                {
                    _9348 = _9347 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7259_dummy_parameter;
                uint _7291_dummy_parameter;
                float4 _9385;
                if ((_4404 && _4393) && _4396)
                {
                    uint _7323_dummy_parameter;
                    float _7347 = log((r_depth_tm1.Load(int3(int2(floor(_9066 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7323_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7355_dummy_parameter;
                    float _7379 = log((r_depth_tp1.Load(int3(int2(floor(_9068 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7355_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9386;
                    if (_7347 > (_7379 + 0.07999999821186065673828125f))
                    {
                        float4 _8943 = _9352;
                        _8943.x = 0.0f;
                        _9386 = _8943;
                    }
                    else
                    {
                        float4 _9387;
                        if (_7379 > (_7347 + 0.07999999821186065673828125f))
                        {
                            float4 _8945 = _9352;
                            _8945.y = 0.0f;
                            _9387 = _8945;
                        }
                        else
                        {
                            _9387 = _9352;
                        }
                        _9386 = _9387;
                    }
                    _9385 = _9386;
                }
                else
                {
                    _9385 = _9352;
                }
                float _4456 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4458 = _9347 >= 0.0f;
                float _9368;
                if (_4458)
                {
                    _9368 = _9347 - _4456;
                }
                else
                {
                    float _9364;
                    if (_4393)
                    {
                        float _9363;
                        _9363 = 2.0f;
                        float _7437;
                        for (int _9362 = 0; _9362 < 24; _9363 = _7437, _9362++)
                        {
                            float _7401 = float(_9362 & 7) * 0.785398185253143310546875f;
                            int _7403 = _9362 >> 3;
                            int _9365;
                            if (_7403 == 0)
                            {
                                _9365 = 16;
                            }
                            else
                            {
                                _9365 = (_7403 == 1) ? 48 : 96;
                            }
                            uint _7453_dummy_parameter;
                            _7437 = min(_9363, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9066 + ((cbFI_MvDepthLaneSizeRcp * float(_9365)) * float2(cos(_7401), sin(_7401))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7453_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9364 = _9363;
                    }
                    else
                    {
                        _9364 = 0.0f;
                    }
                    _9368 = _9364;
                }
                float _9375;
                if (_4458)
                {
                    _9375 = _9347 - _4456;
                }
                else
                {
                    float _9371;
                    if (_4396)
                    {
                        float _9370;
                        _9370 = 2.0f;
                        float _7551;
                        for (int _9369 = 0; _9369 < 24; _9370 = _7551, _9369++)
                        {
                            float _7515 = float(_9369 & 7) * 0.785398185253143310546875f;
                            int _7517 = _9369 >> 3;
                            int _9372;
                            if (_7517 == 0)
                            {
                                _9372 = 16;
                            }
                            else
                            {
                                _9372 = (_7517 == 1) ? 48 : 96;
                            }
                            uint _7583_dummy_parameter;
                            _7551 = min(_9370, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9068 + ((cbFI_MvDepthLaneSizeRcp * float(_9372)) * float2(cos(_7515), sin(_7515))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7583_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9371 = _9370;
                    }
                    else
                    {
                        _9371 = 0.0f;
                    }
                    _9375 = _9371;
                }
                float _9376;
                if (_4393)
                {
                    uint _7615_dummy_parameter;
                    _9376 = r_depth_tm1.Load(int3(int2(floor(_9066 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7615_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9376 = 0.0f;
                }
                float _9377;
                if (_4396)
                {
                    uint _7634_dummy_parameter;
                    _9377 = r_depth_tp1.Load(int3(int2(floor(_9068 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7634_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9377 = 0.0f;
                }
                bool _4513;
                if (_4393)
                {
                    _4513 = _9376 > ((exp((_9368 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4513 = _4393;
                }
                float4 _9393;
                if (_4513)
                {
                    float4 _8947 = _9385;
                    _8947.x = 0.0f;
                    _9393 = _8947;
                }
                else
                {
                    _9393 = _9385;
                }
                bool _4525;
                if (_4396)
                {
                    _4525 = _9377 > ((exp((_9375 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4525 = _4396;
                }
                float4 _9395;
                if (_4525)
                {
                    float4 _8949 = _9393;
                    _8949.y = 0.0f;
                    _9395 = _8949;
                }
                else
                {
                    _9395 = _9393;
                }
                float4 _9458;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4458)
                {
                    bool _4545;
                    if (_4393)
                    {
                        _4545 = _9376 < ((exp((_9368 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4545 = _4393;
                    }
                    float4 _9397;
                    if (_4545)
                    {
                        float4 _8951 = _9395;
                        _8951.x = 0.0f;
                        _9397 = _8951;
                    }
                    else
                    {
                        _9397 = _9395;
                    }
                    bool _4557;
                    if (_4396)
                    {
                        _4557 = _9377 < ((exp((_9375 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4557 = _4396;
                    }
                    float4 _9459;
                    if (_4557)
                    {
                        float4 _8953 = _9397;
                        _8953.y = 0.0f;
                        _9459 = _8953;
                    }
                    else
                    {
                        _9459 = _9397;
                    }
                    _9458 = _9459;
                }
                else
                {
                    _9458 = _9395;
                }
                _9917 = float3(_9348, log((r_depth_tm1.Load(int3(int2(floor(_9066 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7259_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9068 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7291_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _9457 = _9458;
            }
            else
            {
                _9917 = float3(0.0f, 0.0f, 0.5f);
                _9457 = _9352;
            }
            bool _4568 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4317;
            bool _4574;
            if (_4568)
            {
                _4574 = _4371 || _4377;
            }
            else
            {
                _4574 = _4568;
            }
            float4 _9480;
            if (_4574)
            {
                float _9452;
                do
                {
                    uint4 _7813 = r_warped_motion_qdata_tp1.Load(int3(_9096, 0));
                    uint _7814 = _7813.x;
                    if (_7814 != 0u)
                    {
                        float _9451;
                        if (_7814 == 0u)
                        {
                            _9451 = -1.0f;
                        }
                        else
                        {
                            _9451 = float((_7814 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9452 = _9451;
                        break;
                    }
                    int _9434;
                    uint _9435;
                    _9435 = _7814;
                    _9434 = -1;
                    uint _9450;
                    for (; _9434 <= 1; _9435 = _9450, _9434++)
                    {
                        _9450 = _9435;
                        for (int _9448 = -1; _9448 <= 1; )
                        {
                            _9450 = max(_9450, r_warped_motion_qdata_tp1.Load(int3(clamp(_9096 + int2(_9448, _9434), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9448++;
                            continue;
                        }
                    }
                    if (_9435 != 0u)
                    {
                        float _9447;
                        if (_9435 == 0u)
                        {
                            _9447 = -1.0f;
                        }
                        else
                        {
                            _9447 = float((_9435 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9452 = _9447;
                        break;
                    }
                    uint _9437;
                    _9437 = 4294967295u;
                    uint _10662;
                    for (int _9436 = 0; _9436 < 8; _9437 = _10662, _9436++)
                    {
                        int _9440 = 0;
                        for (;;)
                        {
                            if (_9440 < 5)
                            {
                                int2 _7764 = _9096 + (_1085[_9436] * _1094[_9440].xx);
                                bool _7767 = any(bool2(_7764.x < int2(0, 0).x, _7764.y < int2(0, 0).y));
                                bool _7775;
                                if (!_7767)
                                {
                                    _7775 = any(bool2(_7764.x >= cbFI_MvDepthLaneSize.x, _7764.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7775 = _7767;
                                }
                                if (_7775)
                                {
                                    _10662 = _9437;
                                    break;
                                }
                                uint4 _7853 = r_warped_motion_qdata_tp1.Load(int3(_7764, 0));
                                uint _7854 = _7853.x;
                                if (_7854 != 0u)
                                {
                                    _10662 = min(_9437, _7854);
                                    break;
                                }
                                _9440++;
                                continue;
                            }
                            else
                            {
                                _10662 = _9437;
                                break;
                            }
                        }
                    }
                    float _9439;
                    if (_9437 == 4294967295u)
                    {
                        _9439 = -1.0f;
                    }
                    else
                    {
                        float _9438;
                        if (_9437 == 0u)
                        {
                            _9438 = -1.0f;
                        }
                        else
                        {
                            _9438 = float((_9437 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9439 = _9438;
                    }
                    _9452 = _9439;
                    break;
                } while(false);
                float4 _9481;
                if (_9452 >= 0.0f)
                {
                    float _7875 = (exp((_9452 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4593;
                    if (_4371)
                    {
                        uint _7882_dummy_parameter;
                        _4593 = r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7882_dummy_parameter))))), 0)).x > _7875;
                    }
                    else
                    {
                        _4593 = _4371;
                    }
                    float4 _9470;
                    if (_4593)
                    {
                        float4 _8955 = _9457;
                        _8955.z = 0.0f;
                        _9470 = _8955;
                    }
                    else
                    {
                        _9470 = _9457;
                    }
                    bool _4605;
                    if (_4377)
                    {
                        uint _7901_dummy_parameter;
                        _4605 = r_depth_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7901_dummy_parameter))))), 0)).x > _7875;
                    }
                    else
                    {
                        _4605 = _4377;
                    }
                    float4 _9482;
                    if (_4605)
                    {
                        float4 _8957 = _9470;
                        _8957.w = 0.0f;
                        _9482 = _8957;
                    }
                    else
                    {
                        _9482 = _9470;
                    }
                    _9481 = _9482;
                }
                else
                {
                    _9481 = _9457;
                }
                _9480 = _9481;
            }
            else
            {
                _9480 = _9457;
            }
            bool _4613 = _4359 != _4365;
            bool _4620;
            if (_4613)
            {
                _4620 = _4359 ? _4305 : _4308;
            }
            else
            {
                _4620 = _4613;
            }
            bool _4627;
            if (_4620)
            {
                _4627 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4627 = _4620;
            }
            float4 _9565;
            if (_4627)
            {
                bool2 _4632 = _4359.xx;
                float2 _4633 = float2(_4632.x ? _9066.x : _9068.x, _4632.y ? _9066.y : _9068.y);
                float _9472;
                if (_4359)
                {
                    uint _7920_dummy_parameter;
                    _9472 = r_depth_tm1.Load(int3(int2(floor(_4633 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7920_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7936_dummy_parameter;
                    _9472 = r_depth_tp1.Load(int3(int2(floor(_4633 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7936_dummy_parameter))))), 0)).x;
                }
                float4x4 _9473;
                if (_4359)
                {
                    _9473 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9473 = cbFI_MotionTP1ToTM1;
                }
                float2 _9474;
                do
                {
                    float _7963 = _4633.x;
                    float _7966 = 1.0f - _4633.y;
                    float4 _7977 = mul(float4((float2(_7963, _7966) * 2.0f) - 1.0f.xx, _9472, 1.0f), _9473);
                    float _7979 = _7977.w;
                    if (!(_7979 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9474 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7992 = ((_7977.xy / _7979.xx) + 1.0f.xx) * 0.5f;
                    _9474 = float2(_7992.x - _7963, _7966 - _7992.y);
                    break;
                } while(false);
                float2 _4663 = float2(cbFI_DisplaySize);
                float4 _9566;
                if (!(length(((_4633 + _9474) - float2(_4632.x ? _9068.x : _9066.x, _4632.y ? _9068.y : _9066.y)) * _4663) <= ((0.100000001490116119384765625f * length(_9474 * _4663)) + 8.0f)))
                {
                    float4 _9567;
                    if (_4359)
                    {
                        float4 _8967 = _9480;
                        _8967.x = 0.0f;
                        _9567 = _8967;
                    }
                    else
                    {
                        float4 _8969 = _9480;
                        _8969.y = 0.0f;
                        _9567 = _8969;
                    }
                    _9566 = _9567;
                }
                else
                {
                    _9566 = _9480;
                }
                _9565 = _9566;
            }
            else
            {
                _9565 = _9480;
            }
            float4 _4688 = _9250 * _9565;
            float _4690 = dot(_4688, 1.0f.xxxx);
            float4 _9745;
            bool _9765;
            if (_4690 > 0.0f)
            {
                _9765 = _9219;
                _9745 = _4688 / _4690.xxxx;
            }
            else
            {
                bool _4701 = any(bool4(_9565.x < 1.0f.xxxx.x, _9565.y < 1.0f.xxxx.y, _9565.z < 1.0f.xxxx.z, _9565.w < 1.0f.xxxx.w));
                if (_4701)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8014;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8014);
                    }
                }
                bool4 _10692 = _4701.xxxx;
                _9765 = _4701 ? true : _9219;
                _9745 = float4(_10692.x ? 0.0f.xxxx.x : _9250.x, _10692.y ? 0.0f.xxxx.y : _9250.y, _10692.z ? 0.0f.xxxx.z : _9250.z, _10692.w ? 0.0f.xxxx.w : _9250.w);
            }
            _9878 = _9917;
            _9764 = _9765;
            _9744 = _9745;
        }
        else
        {
            _9878 = float3(0.0f, 0.0f, 0.5f);
            _9764 = _9219;
            _9744 = _9250;
        }
        uint _4710 = (cbFI_pad0 >> 24u) & 31u;
        uint _4714 = (cbFI_pad0 >> 16u) & 255u;
        bool _4716 = _4710 != 0u;
        bool _4718 = _4714 == 12u;
        bool _4721 = _4714 == 13u;
        float4 _9761;
        if ((_4716 || _4718) || _4721)
        {
            float _9568;
            do
            {
                bool _8098 = all(bool2(_9069.x > 0.0f.xx.x, _9069.y > 0.0f.xx.y));
                bool _8104;
                if (_8098)
                {
                    _8104 = all(bool2(_9069.x < 1.0f.xx.x, _9069.y < 1.0f.xx.y));
                }
                else
                {
                    _8104 = _8098;
                }
                bool _8035 = !_8104;
                bool _8042;
                if (!_8035)
                {
                    bool _8109 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
                    bool _8115;
                    if (_8109)
                    {
                        _8115 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8115 = _8109;
                    }
                    _8042 = !_8115;
                }
                else
                {
                    _8042 = _8035;
                }
                if (_8042)
                {
                    _9568 = 0.0f;
                    break;
                }
                uint _8122_dummy_parameter;
                uint _8138_dummy_parameter;
                float4 _8063 = mul(float4((float2(_9069.x, 1.0f - _9069.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9069 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8122_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8065 = _8063.w;
                if (abs(_8065) < 9.9999999747524270787835121154785e-07f)
                {
                    _9568 = 0.0f;
                    break;
                }
                float _8076 = abs(cbFI_DeviceToViewDepth.y / ((_8063.z / _8065) - cbFI_DeviceToViewDepth.x));
                float _8079 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8138_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9568 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8076 - _8079) / max(max(_8076, _8079), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8186 = all(bool2(_9070.x > 0.0f.xx.x, _9070.y > 0.0f.xx.y));
            bool _8192;
            if (_8186)
            {
                _8192 = all(bool2(_9070.x < 1.0f.xx.x, _9070.y < 1.0f.xx.y));
            }
            else
            {
                _8192 = _8186;
            }
            float _9569;
            if (_8192)
            {
                uint _8199_dummy_parameter;
                _9569 = length((_5497 + (r_motion_tp1.Load(int3(int2(floor(_9070 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8199_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9569 = 1000000.0f;
            }
            float _9580;
            if ((_4710 & 1u) != 0u)
            {
                _9580 = _9568;
            }
            else
            {
                _9580 = 1.0f;
            }
            float _9581;
            if ((_4710 & 2u) != 0u)
            {
                _9581 = _9580 * (1.0f - smoothstep(2.0f, 8.0f, _9569));
            }
            else
            {
                _9581 = _9580;
            }
            float _9582;
            if ((_4710 & 4u) != 0u)
            {
                _9582 = _9581 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6218 - _6226) - length(_6202 - _6210))));
            }
            else
            {
                _9582 = _9581;
            }
            float _9755;
            if ((_4710 & 8u) != 0u)
            {
                _9755 = lerp(1.0f, _9582, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6202 - _6210)));
            }
            else
            {
                _9755 = _9582;
            }
            bool _4796 = (_4710 & 16u) != 0u;
            bool _4805;
            if (_4796)
            {
                _4805 = length(_9064 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4805 = _4796;
            }
            float _10694 = _4805 ? 1.0f : _9755;
            bool _4811 = _4716 && _6411;
            bool _4816;
            if (_4811)
            {
                bool _8224 = all(bool2(_9066.x > 0.0f.xx.x, _9066.y > 0.0f.xx.y));
                bool _8230;
                if (_8224)
                {
                    _8230 = all(bool2(_9066.x < 1.0f.xx.x, _9066.y < 1.0f.xx.y));
                }
                else
                {
                    _8230 = _8224;
                }
                _4816 = _8230;
            }
            else
            {
                _4816 = _4811;
            }
            bool _4821;
            if (_4816)
            {
                bool _8235 = all(bool2(_9068.x > 0.0f.xx.x, _9068.y > 0.0f.xx.y));
                bool _8241;
                if (_8235)
                {
                    _8241 = all(bool2(_9068.x < 1.0f.xx.x, _9068.y < 1.0f.xx.y));
                }
                else
                {
                    _8241 = _8235;
                }
                _4821 = _8241;
            }
            else
            {
                _4821 = _4816;
            }
            float4 _9762;
            if (_4821)
            {
                float _4827 = _9744.x + _9744.y;
                float _4836 = (_9744.z + _9744.w) * (1.0f - _10694);
                float _9758;
                if (_4827 > 9.9999997473787516355514526367188e-06f)
                {
                    _9758 = _9744.x / _4827;
                }
                else
                {
                    _9758 = _3970;
                }
                _9762 = float4(_9744.x + (_4836 * _9758), _9744.y + (_4836 * (1.0f - _9758)), _9744.zw * _10694);
            }
            else
            {
                _9762 = _9744;
            }
            _9761 = _9762;
        }
        else
        {
            _9761 = _9744;
        }
        float3 _10465;
        if (_9764)
        {
            float3 _8247 = r_current_interpolation_source.Load(int3(_3383, 0)).xyz;
            float3 _10466;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6411)
            {
                uint _8254_dummy_parameter;
                float _9869;
                _9869 = r_depth_tm1.Load(int3(int2(floor(_9066 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8254_dummy_parameter))))), 0)).x;
                float _4948;
                for (int _9868 = 0; _9868 < 24; _9869 = _4948, _9868++)
                {
                    float _4920 = float(_9868 & 7) * 0.785398185253143310546875f;
                    int _4922 = _9868 >> 3;
                    int _10516;
                    if (_4922 == 0)
                    {
                        _10516 = 16;
                    }
                    else
                    {
                        _10516 = (_4922 == 1) ? 48 : 96;
                    }
                    uint _8274_dummy_parameter;
                    _4948 = min(_9869, r_depth_tm1.Load(int3(int2(floor(clamp(_9066 + ((cbFI_MvDepthLaneSizeRcp * float(_10516)) * float2(cos(_4920), sin(_4920))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8274_dummy_parameter))))), 0)).x);
                }
                float2 _9870;
                do
                {
                    float _8296 = 1.0f - _9066.y;
                    float4 _8307 = mul(float4((float2(_9066.x, _8296) * 2.0f) - 1.0f.xx, _9869, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8309 = _8307.w;
                    if (!(_8309 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9870 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8322 = ((_8307.xy / _8309.xx) + 1.0f.xx) * 0.5f;
                    _9870 = float2(_8322.x - _9066.x, _8296 - _8322.y);
                    break;
                } while(false);
                float2 _4959 = _9066 + _9870;
                bool _8340 = all(bool2(_4959.x > 0.0f.xx.x, _4959.y > 0.0f.xx.y));
                bool _8346;
                if (_8340)
                {
                    _8346 = all(bool2(_4959.x < 1.0f.xx.x, _4959.y < 1.0f.xx.y));
                }
                else
                {
                    _8346 = _8340;
                }
                float3 _10467;
                if (_8346)
                {
                    float _4965 = abs(cbFI_DeviceToViewDepth.y / (_9869 - cbFI_DeviceToViewDepth.x));
                    uint _8366_dummy_parameter;
                    int2 _8366 = int2(spvTextureSize(r_depth_m2, uint(0), _8366_dummy_parameter));
                    float _4969 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4959 * float2(_8366))), int2(0, 0), _8366 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10472;
                    if (abs(_4969 - _4965) <= (0.20000000298023223876953125f * max(_4969, _4965)))
                    {
                        uint _8400_dummy_parameter;
                        int2 _8400 = int2(spvTextureSize(r_colour_m2, uint(0), _8400_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8423;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8423);
                        }
                        _10472 = r_colour_m2.Load(int3(clamp(int2(floor(_4959 * float2(_8400))), int2(0, 0), _8400 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8433;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8433);
                        }
                        _10472 = _8247;
                    }
                    _10467 = _10472;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8443;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8443);
                    }
                    _10467 = _8247;
                }
                _10466 = _10467;
            }
            else
            {
                _10466 = _8247;
            }
            _10465 = _10466;
        }
        else
        {
            _10465 = (((_6202 * _9761.x) + (_6210 * _9761.y)) + (_6218 * _9761.z)) + (_6226 * _9761.w);
        }
        uint _4997 = cbFI_pad0 & 255u;
        bool _10357;
        float3 _10464;
        if (_4997 != 0u)
        {
            float3 _5002 = r_present_backbuffer.Load(int3(_3383, 0)).xyz;
            float3 _5006 = r_current_interpolation_source.Load(int3(_3383, 0)).xyz;
            float3 _5010 = abs(_5002 - _5006);
            float3 _9873;
            if (_4997 == 2u)
            {
                _9873 = (abs(_5006) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9873 = 0.000244140625f.xxx;
            }
            bool _5026 = any(bool3(_5010.x > _9873.x, _5010.y > _9873.y, _5010.z > _9873.z));
            bool3 _10695 = _5026.xxx;
            _10464 = float3(_10695.x ? _5002.x : _10465.x, _10695.y ? _5002.y : _10465.y, _10695.z ? _5002.z : _10465.z);
            _10357 = _5026;
        }
        else
        {
            _10464 = _10465;
            _10357 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8458;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8458);
        }
        float3 _10447;
        if (_4714 == 1u)
        {
            _10447 = lerp(_6202, _6210, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10448;
            if (_4714 == 2u)
            {
                _10448 = lerp(_6218, _6226, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10449;
                if (_4714 == 3u)
                {
                    _10449 = float(_10357).xxx;
                }
                else
                {
                    float3 _10450;
                    if (_4714 == 4u)
                    {
                        _10450 = float3(((_9064 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10451;
                        if (_4714 == 5u)
                        {
                            _10451 = float3(((_5497 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10452;
                            if (_4714 == 6u)
                            {
                                _10452 = float3(_9761.xy, _9761.z + _9761.w);
                            }
                            else
                            {
                                float3 _10453;
                                if (_4714 == 7u)
                                {
                                    _10453 = r_current_interpolation_source.Load(int3(_3383, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10454;
                                    if (_4714 == 8u)
                                    {
                                        _10454 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3745, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10455;
                                        if (_4718)
                                        {
                                            uint _8480_dummy_parameter;
                                            uint _8512_dummy_parameter;
                                            _10455 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8480_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3745 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8512_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10456;
                                            if (_4721)
                                            {
                                                _10456 = _6218;
                                            }
                                            else
                                            {
                                                float3 _10457;
                                                if (_4714 == 20u)
                                                {
                                                    _10457 = _6202;
                                                }
                                                else
                                                {
                                                    float3 _10458;
                                                    if (_4714 == 21u)
                                                    {
                                                        _10458 = _6210;
                                                    }
                                                    else
                                                    {
                                                        float3 _10459;
                                                        if (_4714 == 22u)
                                                        {
                                                            _10459 = _6226;
                                                        }
                                                        else
                                                        {
                                                            float3 _10460;
                                                            if (_4714 == 18u)
                                                            {
                                                                _10460 = _10163;
                                                            }
                                                            else
                                                            {
                                                                float3 _10461;
                                                                if (_4714 == 19u)
                                                                {
                                                                    _10461 = _10017;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10697 = (_4714 == 23u).xxx;
                                                                    _10461 = float3(_10697.x ? _9878.x : _10464.x, _10697.y ? _9878.y : _10464.y, _10697.z ? _9878.z : _10464.z);
                                                                }
                                                                _10460 = _10461;
                                                            }
                                                            _10459 = _10460;
                                                        }
                                                        _10458 = _10459;
                                                    }
                                                    _10457 = _10458;
                                                }
                                                _10456 = _10457;
                                            }
                                            _10455 = _10456;
                                        }
                                        _10454 = _10455;
                                    }
                                    _10453 = _10454;
                                }
                                _10452 = _10453;
                            }
                            _10451 = _10452;
                        }
                        _10450 = _10451;
                    }
                    _10449 = _10450;
                }
                _10448 = _10449;
            }
            _10447 = _10448;
        }
        float3 _10446;
        if ((_4714 >= 9u) && (_4714 <= 11u))
        {
            uint _5190 = 64u + uint((_9096.y * cbFI_MvDepthLaneSize.x) + _9096.x);
            uint _5194 = rw_nfru_diagnostics.Load<uint>(_5190 * 4 + 0) & 15u;
            float3 _10477;
            if (_4714 == 10u)
            {
                float3 _10445;
                if ((rw_nfru_diagnostics.Load<uint>(_5190 * 4 + 0) & 32u) != 0u)
                {
                    _10445 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10444;
                    if ((rw_nfru_diagnostics.Load<uint>(_5190 * 4 + 0) & 16u) != 0u)
                    {
                        _10444 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5215 = ((rw_nfru_diagnostics.Load<uint>(_5190 * 4 + 0) & 64u) != 0u).xxx;
                        _10444 = float3(_5215.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5215.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5215.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10445 = _10444;
                }
                _10477 = _10445;
            }
            else
            {
                float3 _10478;
                if (_4714 == 11u)
                {
                    uint _5228 = (rw_nfru_diagnostics.Load<uint>(_5190 * 4 + 0) >> 8u) & 15u;
                    uint _5231 = (rw_nfru_diagnostics.Load<uint>(_5190 * 4 + 0) >> 12u) & 15u;
                    float3 _10437;
                    if ((_5194 == 2u) || (_5194 == 3u))
                    {
                        _10437 = _3096[_5194];
                    }
                    else
                    {
                        bool _5243 = _5228 == 3u;
                        bool _5245 = _5231 == 3u;
                        float3 _10438;
                        if (_5243 && _5245)
                        {
                            _10438 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10439;
                            if (_5243)
                            {
                                _10439 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10440;
                                if (_5245)
                                {
                                    _10440 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10441;
                                    if ((_5228 == 4u) || (_5231 == 4u))
                                    {
                                        _10441 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10442;
                                        if ((_5228 == 1u) || (_5231 == 1u))
                                        {
                                            _10442 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10699 = (_5194 == 1u).xxx;
                                            _10442 = float3(_10699.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10699.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10699.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10441 = _10442;
                                    }
                                    _10440 = _10441;
                                }
                                _10439 = _10440;
                            }
                            _10438 = _10439;
                        }
                        _10437 = _10438;
                    }
                    _10478 = _10437;
                }
                else
                {
                    _10478 = _3096[min(_5194, 7u)];
                }
                _10477 = _10478;
            }
            _10446 = _10477;
        }
        else
        {
            _10446 = _10447;
        }
        float4 _10481;
        if ((_4714 >= 14u) && (_4714 <= 16u))
        {
            float2 _10479;
            if (_4714 == 14u)
            {
                uint _5301_dummy_parameter;
                uint _5307_dummy_parameter;
                _10479 = r_flow_tm1.Load(int3(clamp(int2(floor(_3745 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5301_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5307_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10480;
                if (_4714 == 16u)
                {
                    uint _8563 = r_warped_flow_qdata_tm1.Load(int3(_3761, 0)).x & 2147483647u;
                    uint _8595 = uint(max((int((_8563 >> 16u) & 15u) - 6), 0));
                    _10480 = ((float2(float((1 - (2 * int((_8563 >> 15u) & 1u))) * int(((_8563 >> uint(7)) & 127u) << _8595)), float((1 - (2 * int((_8563 >> 14u) & 1u))) * int((_8563 & 127u) << _8595))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10480 = _5497 * float2(cbFI_DisplaySize);
                }
                _10479 = _10480;
            }
            uint2 _5340 = uint2(clamp(round(_10479 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5342 = _5340.x;
            uint _5349 = _5340.y;
            _10481 = float4(float(_5342 & 255u), float((_5342 >> 8u) | ((_5349 & 15u) << 4u)), float(_5349 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10482;
            if (_4714 == 17u)
            {
                _10482 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3761, 0)).x != 0u), _4104, 0.0f, 1.0f);
            }
            else
            {
                _10482 = float4(_10446, 1.0f);
            }
            _10481 = _10482;
        }
        rw_output[_3383] = _10481.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5393 = ((uint(_3383.y) * uint(cbFI_DisplaySize.x)) + uint(_3383.x)) * 6u;
            uint _8641 = spvPackHalf2x16(clamp(_6201.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5393 * 4 + 0, (((_8641 & 32767u) >> 4u) | ((((_8641 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6201.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8676 = spvPackHalf2x16(clamp(_6209.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5393 + 1u) * 4 + 0, (((_8676 & 32767u) >> 4u) | ((((_8676 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6209.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8711 = spvPackHalf2x16(clamp(_6217.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5393 + 2u) * 4 + 0, (((_8711 & 32767u) >> 4u) | ((((_8711 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6217.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8746 = spvPackHalf2x16(clamp(_6225.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5393 + 3u) * 4 + 0, (((_8746 & 32767u) >> 4u) | ((((_8746 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6225.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8773 = r_current_interpolation_source.Load(int3(_3383, 0));
            uint _8787 = spvPackHalf2x16(clamp(_8773.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5393 + 4u) * 4 + 0, (((_8787 & 32767u) >> 4u) | ((((_8787 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8773.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10515;
            if (_10357 || (_4714 != 0u))
            {
                _10515 = 4294967295u;
            }
            else
            {
                uint _8822 = spvPackHalf2x16(clamp(_10481.xy, 0.0f.xx, 65000.0f.xx));
                _10515 = (((_8822 & 32767u) >> 4u) | ((((_8822 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10481.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5393 + 5u) * 4 + 0, _10515);
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
