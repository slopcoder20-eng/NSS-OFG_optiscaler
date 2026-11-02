static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3116[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3420 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3420.x >= cbFI_DisplaySize.x, _3420.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3420] = float4(r_present_backbuffer.Load(int3(_3420, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3420] = float4(r_current_interpolation_source.Load(int3(_3420, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3795 = (float2(_3420) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3806 = int2(floor(_3795 * float2(cbFI_MvDepthLaneSize)));
        int2 _3811 = int2(floor(_3795 * float2(cbFI_FlowLaneSize)));
        float4 _5565 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3795 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5571 = r_warped_filled_flow_tm1.Load(int3(_3811, 0)).xy;
        float2 _5577 = r_warped_filled_motion_tp1.Load(int3(_3806, 0)).xy;
        bool _5599 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9131;
        if (_5599)
        {
            float _5612 = ((2.0f * _3795.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9131 = float2(atan(_5612) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3795.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5612 * _5612))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9131 = _3795;
        }
        bool _3832 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9152;
        bool _9173;
        int2 _9184;
        float3 _10251;
        if (_3832)
        {
            float _9133;
            float _9135;
            _9135 = 2.0f;
            _9133 = -1.0f;
            uint _3484[9];
            float _10645;
            float _10648;
            for (int _9132 = 0; _9132 < 9; _9135 = _10648, _9133 = _10645, _9132++)
            {
                _3484[_9132] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3806 + int2((_9132 % 3) - 1, (_9132 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3484[_9132] != 0u)
                {
                    float _10640;
                    if (_3484[_9132] == 0u)
                    {
                        _10640 = -1.0f;
                    }
                    else
                    {
                        _10640 = float((_3484[_9132] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10648 = min(_9135, _10640);
                    _10645 = max(_9133, _10640);
                }
                else
                {
                    _10648 = _9135;
                    _10645 = _9133;
                }
            }
            float _3878 = float(_9133 >= 0.0f);
            float3 _8942 = 0.0f.xxx;
            _8942.y = _3878;
            float2 _9153;
            bool _9174;
            int2 _9185;
            float3 _10252;
            if ((_9133 - _9135) > 0.0199999995529651641845703125f)
            {
                float _9141;
                int2 _9142;
                float2 _9143;
                int2 _9145;
                float2 _9151;
                _9151 = _5577;
                _9145 = _3806;
                _9143 = _5577;
                _9142 = _3806;
                _9141 = -1.0f;
                float _10653;
                int2 _10657;
                float2 _10668;
                int2 _10679;
                float2 _10712;
                float _10758;
                int _9140 = 0;
                float _10621 = 1000000000.0f;
                for (; _9140 < 9; _10621 = _10758, _9151 = _10712, _9145 = _10679, _9143 = _10668, _9142 = _10657, _9141 = _10653, _9140++)
                {
                    if (_3484[_9140] == 0u)
                    {
                        _10758 = _10621;
                        _10712 = _9151;
                        _10679 = _9145;
                        _10668 = _9143;
                        _10657 = _9142;
                        _10653 = _9141;
                        continue;
                    }
                    int2 _3913 = clamp(_3806 + int2((_9140 % 3) - 1, (_9140 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5687 = _3484[_9140] & 2147483647u;
                    uint _5719 = uint(max((int((_5687 >> 16u) & 15u) - 6), 0));
                    float2 _3919 = (float2(float((1 - (2 * int((_5687 >> 15u) & 1u))) * int(((_5687 >> uint(7)) & 127u) << _5719)), float((1 - (2 * int((_5687 >> 14u) & 1u))) * int((_5687 & 127u) << _5719))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10607;
                    if (_3484[_9140] == 0u)
                    {
                        _10607 = -1.0f;
                    }
                    else
                    {
                        _10607 = float((_3484[_9140] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3924 = _10607 - 0.100000001490116119384765625f;
                    float2 _10608;
                    if (_5599)
                    {
                        float2 _5796 = clamp((((_9131 + (_3919 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5799 = tan(_5796.x);
                        _10608 = (float2(_5799 / cbFI_DeviceToViewDepth.z, (tan(_5796.y) * sqrt(1.0f + (_5799 * _5799))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10608 = _9131 + (_3919 * cbFI_Timestep);
                    }
                    float _3931 = cbFI_Timestep - 1.0f;
                    float2 _10609;
                    if (_5599)
                    {
                        float2 _5867 = clamp((((_9131 + (_3919 * _3931)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5870 = tan(_5867.x);
                        _10609 = (float2(_5870 / cbFI_DeviceToViewDepth.z, (tan(_5867.y) * sqrt(1.0f + (_5870 * _5870))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10609 = _9131 + (_3919 * _3931);
                    }
                    bool _5903 = all(bool2(_10608.x > 0.0f.xx.x, _10608.y > 0.0f.xx.y));
                    bool _5909;
                    if (_5903)
                    {
                        _5909 = all(bool2(_10608.x < 1.0f.xx.x, _10608.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5909 = _5903;
                    }
                    float _10612;
                    if (_5909)
                    {
                        uint _5916_dummy_parameter;
                        _10612 = max((_3924 - (log(((r_depth_tm1.Load(int3(int2(floor(_10608 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5916_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10612 = 0.0f;
                    }
                    bool _5946 = all(bool2(_10609.x > 0.0f.xx.x, _10609.y > 0.0f.xx.y));
                    bool _5952;
                    if (_5946)
                    {
                        _5952 = all(bool2(_10609.x < 1.0f.xx.x, _10609.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5952 = _5946;
                    }
                    float _10613;
                    if (_5952)
                    {
                        uint _5959_dummy_parameter;
                        _10613 = _10612 + max((_3924 - (log(((r_depth_tp1.Load(int3(int2(floor(_10609 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5959_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10613 = _10612;
                    }
                    float _10654;
                    int2 _10658;
                    float2 _10669;
                    int2 _10680;
                    float2 _10713;
                    float _10759;
                    if (_10613 == 0.0f)
                    {
                        bool _3966 = _3924 > _9141;
                        bool2 _10767 = _3966.xx;
                        _10759 = _10621;
                        _10713 = float2(_10767.x ? _3919.x : _9151.x, _10767.y ? _3919.y : _9151.y);
                        _10680 = int2(_10767.x ? _3913.x : _9145.x, _10767.y ? _3913.y : _9145.y);
                        _10669 = _9143;
                        _10658 = _9142;
                        _10654 = _3966 ? _3924 : _9141;
                    }
                    else
                    {
                        bool _3975 = _10613 < _10621;
                        bool2 _10763 = _3975.xx;
                        _10759 = _3975 ? _10613 : _10621;
                        _10713 = _9151;
                        _10680 = _9145;
                        _10669 = float2(_10763.x ? _3919.x : _9143.x, _10763.y ? _3919.y : _9143.y);
                        _10658 = int2(_10763.x ? _3913.x : _9142.x, _10763.y ? _3913.y : _9142.y);
                        _10654 = _9141;
                    }
                    _10758 = _10759;
                    _10712 = _10713;
                    _10679 = _10680;
                    _10668 = _10669;
                    _10657 = _10658;
                    _10653 = _10654;
                }
                bool _3987 = _9141 < 0.0f;
                bool2 _10773 = _3987.xx;
                int2 _10776 = int2(_10773.x ? _9142.x : _9145.x, _10773.y ? _9142.y : _9145.y);
                _10252 = float3(1.0f, _3878, float(any(bool2(_10776.x != _3806.x, _10776.y != _3806.y))));
                _9185 = _10776;
                _9174 = _3987 ? false : true;
                _9153 = float2(_10773.x ? _9143.x : _9151.x, _10773.y ? _9143.y : _9151.y);
            }
            else
            {
                _10252 = _8942;
                _9185 = _3806;
                _9174 = false;
                _9153 = _5577;
            }
            _10251 = _10252;
            _9184 = _9185;
            _9173 = _9174;
            _9152 = _9153;
        }
        else
        {
            _10251 = 0.0f.xxx;
            _9184 = _3806;
            _9173 = false;
            _9152 = _5577;
        }
        float2 _9154;
        if (_5599)
        {
            float2 _6024 = clamp((((_9131 + (_9152 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6027 = tan(_6024.x);
            _9154 = (float2(_6027 / cbFI_DeviceToViewDepth.z, (tan(_6024.y) * sqrt(1.0f + (_6027 * _6027))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9154 = _9131 + (_9152 * cbFI_Timestep);
        }
        float _4010 = cbFI_Timestep - 1.0f;
        float2 _9156;
        if (_5599)
        {
            float2 _6095 = clamp((((_9131 + (_9152 * _4010)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6098 = tan(_6095.x);
            _9156 = (float2(_6098 / cbFI_DeviceToViewDepth.z, (tan(_6095.y) * sqrt(1.0f + (_6098 * _6098))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9156 = _9131 + (_9152 * _4010);
        }
        float _4015 = -cbFI_Timestep;
        float2 _9157;
        if (_5599)
        {
            float2 _6166 = clamp((((_9131 + (_5571 * _4015)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6169 = tan(_6166.x);
            _9157 = (float2(_6169 / cbFI_DeviceToViewDepth.z, (tan(_6166.y) * sqrt(1.0f + (_6169 * _6169))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9157 = _9131 + (_5571 * _4015);
        }
        float _4020 = 1.0f - cbFI_Timestep;
        float2 _9158;
        if (_5599)
        {
            float2 _6237 = clamp((((_9131 + (_5571 * _4020)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6240 = tan(_6237.x);
            _9158 = (float2(_6240 / cbFI_DeviceToViewDepth.z, (tan(_6237.y) * sqrt(1.0f + (_6240 * _6240))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9158 = _9131 + (_5571 * _4020);
        }
        float4 _6275 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9154, 0.0f);
        float3 _6276 = _6275.xyz;
        float4 _6283 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9156, 0.0f);
        float3 _6284 = _6283.xyz;
        float4 _6291 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9157, 0.0f);
        float3 _6292 = _6291.xyz;
        float4 _6299 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9158, 0.0f);
        float3 _6300 = _6299.xyz;
        float4 _6314 = exp(_5565 - max(max(max(_5565.x, _5565.y), _5565.z), _5565.w).xxxx);
        float4 _6321 = _6314 / (dot(_6314, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4039 = _3832 && (!_9173);
        bool _4048;
        if (_4039)
        {
            _4048 = (_6321.z + _6321.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4048 = _4039;
        }
        bool _4059;
        if (_4048)
        {
            _4059 = length((_9157 - _9154) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4059 = _4048;
        }
        bool _9197;
        if (_4059)
        {
            uint4 _6340 = r_warped_motion_qdata_tp1.Load(int3(_9184, 0));
            uint _6341 = _6340.x;
            bool _9200;
            if (_6341 != 0u)
            {
                float _9186;
                if (_6341 == 0u)
                {
                    _9186 = -1.0f;
                }
                else
                {
                    _9186 = float((_6341 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4069 = _9186 - 0.12000000476837158203125f;
                bool _6360 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
                bool _6366;
                if (_6360)
                {
                    _6366 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
                }
                else
                {
                    _6366 = _6360;
                }
                bool _4079;
                if (_6366)
                {
                    uint _6373_dummy_parameter;
                    _4079 = (log(((r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6373_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4069;
                }
                else
                {
                    _4079 = _6366;
                }
                bool _4093;
                if (!_4079)
                {
                    bool _6403 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
                    bool _6409;
                    if (_6403)
                    {
                        _6409 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6409 = _6403;
                    }
                    bool _4091;
                    if (_6409)
                    {
                        uint _6416_dummy_parameter;
                        _4091 = (log(((r_depth_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6416_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4069;
                    }
                    else
                    {
                        _4091 = _6409;
                    }
                    _4093 = _4091;
                }
                else
                {
                    _4093 = _4079;
                }
                _9200 = _4093;
            }
            else
            {
                _9200 = false;
            }
            _9197 = _9200;
        }
        else
        {
            _9197 = false;
        }
        bool _4098 = _9173 || _9197;
        bool _4103;
        if (_4098)
        {
            bool _6446 = all(bool2(_9154.x > 0.0f.xx.x, _9154.y > 0.0f.xx.y));
            bool _6452;
            if (_6446)
            {
                _6452 = all(bool2(_9154.x < 1.0f.xx.x, _9154.y < 1.0f.xx.y));
            }
            else
            {
                _6452 = _6446;
            }
            _4103 = _6452;
        }
        else
        {
            _4103 = _4098;
        }
        bool _4108;
        if (_4103)
        {
            bool _6457 = all(bool2(_9156.x > 0.0f.xx.x, _9156.y > 0.0f.xx.y));
            bool _6463;
            if (_6457)
            {
                _6463 = all(bool2(_9156.x < 1.0f.xx.x, _9156.y < 1.0f.xx.y));
            }
            else
            {
                _6463 = _6457;
            }
            _4108 = _6463;
        }
        else
        {
            _4108 = _4103;
        }
        float4 _9294;
        if (_4108)
        {
            float _4111 = _6321.x;
            float _4113 = _6321.y;
            float _4114 = _4111 + _4113;
            float _4119 = _6321.z + _6321.w;
            float _9215;
            if (_4114 > 0.001000000047497451305389404296875f)
            {
                _9215 = _4111 / _4114;
            }
            else
            {
                _9215 = _4020;
            }
            _9294 = float4(_4111 + (_4119 * _9215), _4113 + (_4119 * (1.0f - _9215)), 0.0f, 0.0f);
        }
        else
        {
            _9294 = _6321;
        }
        bool _6491 = (cbFI_pad0 & 1024u) != 0u;
        bool _6467 = !_6491;
        bool _6468 = !_6467;
        bool _6485;
        if (_6468)
        {
            _6485 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9184.y * cbFI_MvDepthLaneSize.x) + _9184.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6485 = _6467;
        }
        bool _6517;
        if (_6468)
        {
            _6517 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3811.y * cbFI_FlowLaneSize.x) + _3811.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6517 = _6467;
        }
        float _4154 = float(_6517);
        bool _9307;
        float4 _9338;
        float3 _10105;
        if (_6491)
        {
            bool _4164;
            if (_6485)
            {
                _4164 = all(bool2(_9154.x > 0.0f.xx.x, _9154.y > 0.0f.xx.y));
            }
            else
            {
                _4164 = _6485;
            }
            bool _4170;
            if (_4164)
            {
                _4170 = all(bool2(_9154.x < 1.0f.xx.x, _9154.y < 1.0f.xx.y));
            }
            else
            {
                _4170 = _4164;
            }
            bool _4177;
            if (_6485)
            {
                _4177 = all(bool2(_9156.x > 0.0f.xx.x, _9156.y > 0.0f.xx.y));
            }
            else
            {
                _4177 = _6485;
            }
            bool _4183;
            if (_4177)
            {
                _4183 = all(bool2(_9156.x < 1.0f.xx.x, _9156.y < 1.0f.xx.y));
            }
            else
            {
                _4183 = _4177;
            }
            bool _4190;
            if (_6517)
            {
                _4190 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
            }
            else
            {
                _4190 = _6517;
            }
            bool _4196;
            if (_4190)
            {
                _4196 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
            }
            else
            {
                _4196 = _4190;
            }
            bool _4203;
            if (_6517)
            {
                _4203 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
            }
            else
            {
                _4203 = _6517;
            }
            bool _4209;
            if (_4203)
            {
                _4209 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
            }
            else
            {
                _4209 = _4203;
            }
            bool _4211 = !_6485;
            if (_4211)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6559;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6559);
                }
            }
            bool _4216 = !_6517;
            if (_4216)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6569;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6569);
                }
            }
            if (_6485 && _4216)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6579;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6579);
                }
            }
            if (_4211 && _6517)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6589;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6589);
                }
            }
            float _4235 = float(_4170);
            float _4237 = float(_4183);
            bool _4240 = _4196 && _4209;
            float _9249;
            if (_4240)
            {
                _9249 = 1.0f;
            }
            else
            {
                _9249 = (_4196 || _4209) ? 0.5f : 0.0f;
            }
            bool _9254;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4170)) && (!_4183))
            {
                bool _4270;
                if (_4240)
                {
                    float _9252;
                    do
                    {
                        bool _6673 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
                        bool _6679;
                        if (_6673)
                        {
                            _6679 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6679 = _6673;
                        }
                        bool _6610 = !_6679;
                        bool _6617;
                        if (!_6610)
                        {
                            bool _6684 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
                            bool _6690;
                            if (_6684)
                            {
                                _6690 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6690 = _6684;
                            }
                            _6617 = !_6690;
                        }
                        else
                        {
                            _6617 = _6610;
                        }
                        if (_6617)
                        {
                            _9252 = 0.0f;
                            break;
                        }
                        uint _6697_dummy_parameter;
                        uint _6713_dummy_parameter;
                        float4 _6638 = mul(float4((float2(_9157.x, 1.0f - _9157.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6697_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6640 = _6638.w;
                        if (abs(_6640) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9252 = 0.0f;
                            break;
                        }
                        float _6651 = abs(cbFI_DeviceToViewDepth.y / ((_6638.z / _6640) - cbFI_DeviceToViewDepth.x));
                        float _6654 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6713_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9252 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6651 - _6654) / max(max(_6651, _6654), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4270 = _9252 >= 0.5f;
                }
                else
                {
                    _4270 = _4240;
                }
                bool _4278;
                if (_4270)
                {
                    _4278 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4278 = _4270;
                }
                bool _9255;
                if (_4278)
                {
                    uint _6763_dummy_parameter;
                    float2 _9253;
                    do
                    {
                        float _6789 = 1.0f - _9157.y;
                        float4 _6800 = mul(float4((float2(_9157.x, _6789) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6763_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6802 = _6800.w;
                        if (!(_6802 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9253 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6815 = ((_6800.xy / _6802.xx) + 1.0f.xx) * 0.5f;
                        _9253 = float2(_6815.x - _9157.x, _6789 - _6815.y);
                        break;
                    } while(false);
                    float2 _4291 = float2(cbFI_DisplaySize);
                    _9255 = length(((_9157 + _9253) - _9158) * _4291) <= ((0.100000001490116119384765625f * length(_9253 * _4291)) + 8.0f);
                }
                else
                {
                    _9255 = _4270;
                }
                _9254 = _9255;
            }
            else
            {
                _9254 = true;
            }
            bool _4305 = !_9254;
            bool _10777 = _4305 ? false : _4209;
            bool _10778 = _4305 ? false : _4196;
            bool _9308;
            float4 _9339;
            if (!(((_4170 && _4183) && _10778) && _10777))
            {
                float4 _4327 = _9294 * float4(_4235, _4237, float(_10778), float(_10777));
                float _4329 = dot(_4327, 1.0f.xxxx);
                bool _4332 = !(_4329 > 0.0f);
                float4 _9340;
                if (!_4332)
                {
                    _9340 = _4327 / _4329.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6837;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6837);
                    }
                    _9340 = 0.0f.xxxx;
                }
                _9339 = _9340;
                _9308 = _4332;
            }
            else
            {
                _9339 = _9294;
                _9308 = false;
            }
            _10105 = float3(_4235, _4237, _9249);
            _9338 = _9339;
            _9307 = _9308;
        }
        else
        {
            _10105 = float3(float(_6485), _4154, 0.0f);
            _9338 = _9294;
            _9307 = false;
        }
        float4 _9832;
        bool _9852;
        float3 _9966;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9307))
        {
            bool _4355 = _9338.x > 0.00999999977648258209228515625f;
            bool _4358 = _9338.y > 0.00999999977648258209228515625f;
            bool _4367 = (_9338.z + _9338.w) > 0.0199999995529651641845703125f;
            bool _4373;
            if (_4367)
            {
                bool _6843 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
                bool _6849;
                if (_6843)
                {
                    _6849 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
                }
                else
                {
                    _6849 = _6843;
                }
                _4373 = _6849;
            }
            else
            {
                _4373 = _4367;
            }
            bool _4378;
            if (_4373)
            {
                bool _6854 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
                bool _6860;
                if (_6854)
                {
                    _6860 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
                }
                else
                {
                    _6860 = _6854;
                }
                _4378 = _6860;
            }
            else
            {
                _4378 = _4373;
            }
            bool _4385;
            if (_4378)
            {
                float _9342;
                do
                {
                    bool _6943 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
                    bool _6949;
                    if (_6943)
                    {
                        _6949 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6949 = _6943;
                    }
                    bool _6880 = !_6949;
                    bool _6887;
                    if (!_6880)
                    {
                        bool _6954 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
                        bool _6960;
                        if (_6954)
                        {
                            _6960 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6960 = _6954;
                        }
                        _6887 = !_6960;
                    }
                    else
                    {
                        _6887 = _6880;
                    }
                    if (_6887)
                    {
                        _9342 = 0.0f;
                        break;
                    }
                    uint _6967_dummy_parameter;
                    uint _6983_dummy_parameter;
                    float4 _6908 = mul(float4((float2(_9157.x, 1.0f - _9157.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6967_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6910 = _6908.w;
                    if (abs(_6910) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9342 = 0.0f;
                        break;
                    }
                    float _6921 = abs(cbFI_DeviceToViewDepth.y / ((_6908.z / _6910) - cbFI_DeviceToViewDepth.x));
                    float _6924 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6983_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9342 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6921 - _6924) / max(max(_6921, _6924), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4385 = _9342 < 0.5f;
            }
            else
            {
                _4385 = _4378;
            }
            float4 _9357;
            if (_4385)
            {
                uint _7033_dummy_parameter;
                uint _7064_dummy_parameter;
                float4 _9358;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7033_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7064_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9358 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9358 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9357 = _9358;
            }
            else
            {
                _9357 = 1.0f.xxxx;
            }
            bool _4409;
            if (_6485)
            {
                bool _7093 = all(bool2(_9154.x > 0.0f.xx.x, _9154.y > 0.0f.xx.y));
                bool _7099;
                if (_7093)
                {
                    _7099 = all(bool2(_9154.x < 1.0f.xx.x, _9154.y < 1.0f.xx.y));
                }
                else
                {
                    _7099 = _7093;
                }
                _4409 = _7099;
            }
            else
            {
                _4409 = _6485;
            }
            bool _4415;
            if (_6485)
            {
                bool _7104 = all(bool2(_9156.x > 0.0f.xx.x, _9156.y > 0.0f.xx.y));
                bool _7110;
                if (_7104)
                {
                    _7110 = all(bool2(_9156.x < 1.0f.xx.x, _9156.y < 1.0f.xx.y));
                }
                else
                {
                    _7110 = _7104;
                }
                _4415 = _7110;
            }
            else
            {
                _4415 = _6485;
            }
            bool _4421;
            if (_6517)
            {
                bool _7115 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
                bool _7121;
                if (_7115)
                {
                    _7121 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
                }
                else
                {
                    _7121 = _7115;
                }
                _4421 = _7121;
            }
            else
            {
                _4421 = _6517;
            }
            bool _4427;
            if (_6517)
            {
                bool _7126 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
                bool _7132;
                if (_7126)
                {
                    _7132 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
                }
                else
                {
                    _7132 = _7126;
                }
                _4427 = _7132;
            }
            else
            {
                _4427 = _6517;
            }
            bool _4430 = _4421 != _4427;
            bool _4436;
            if (_4430)
            {
                _4436 = _4409 || _4415;
            }
            else
            {
                _4436 = _4430;
            }
            float4 _9440;
            if (_4436)
            {
                float4 _9027 = _9357;
                _9027.z = 0.0f;
                _9027.w = 0.0f;
                _9440 = _9027;
            }
            else
            {
                _9440 = _9357;
            }
            bool _4443 = _4409 && _4355;
            bool _4446 = _4415 && _4358;
            float4 _9545;
            float3 _10005;
            if (_4443 || _4446)
            {
                float _9435;
                do
                {
                    uint4 _7271 = r_warped_motion_qdata_tp1.Load(int3(_9184, 0));
                    uint _7272 = _7271.x;
                    if (_7272 != 0u)
                    {
                        float _9434;
                        if (_7272 == 0u)
                        {
                            _9434 = -1.0f;
                        }
                        else
                        {
                            _9434 = float((_7272 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9435 = _9434;
                        break;
                    }
                    int _9417;
                    uint _9418;
                    _9418 = _7272;
                    _9417 = -1;
                    uint _9433;
                    for (; _9417 <= 1; _9418 = _9433, _9417++)
                    {
                        _9433 = _9418;
                        for (int _9431 = -1; _9431 <= 1; )
                        {
                            _9433 = max(_9433, r_warped_motion_qdata_tp1.Load(int3(clamp(_9184 + int2(_9431, _9417), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9431++;
                            continue;
                        }
                    }
                    if (_9418 != 0u)
                    {
                        float _9430;
                        if (_9418 == 0u)
                        {
                            _9430 = -1.0f;
                        }
                        else
                        {
                            _9430 = float((_9418 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9435 = _9430;
                        break;
                    }
                    uint _9420;
                    _9420 = 4294967295u;
                    uint _10749;
                    for (int _9419 = 0; _9419 < 8; _9420 = _10749, _9419++)
                    {
                        int _9423 = 0;
                        for (;;)
                        {
                            if (_9423 < 5)
                            {
                                int2 _7222 = _9184 + (_1093[_9419] * _1102[_9423].xx);
                                bool _7225 = any(bool2(_7222.x < int2(0, 0).x, _7222.y < int2(0, 0).y));
                                bool _7233;
                                if (!_7225)
                                {
                                    _7233 = any(bool2(_7222.x >= cbFI_MvDepthLaneSize.x, _7222.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7233 = _7225;
                                }
                                if (_7233)
                                {
                                    _10749 = _9420;
                                    break;
                                }
                                uint4 _7311 = r_warped_motion_qdata_tp1.Load(int3(_7222, 0));
                                uint _7312 = _7311.x;
                                if (_7312 != 0u)
                                {
                                    _10749 = min(_9420, _7312);
                                    break;
                                }
                                _9423++;
                                continue;
                            }
                            else
                            {
                                _10749 = _9420;
                                break;
                            }
                        }
                    }
                    float _9422;
                    if (_9420 == 4294967295u)
                    {
                        _9422 = -1.0f;
                    }
                    else
                    {
                        float _9421;
                        if (_9420 == 0u)
                        {
                            _9421 = -1.0f;
                        }
                        else
                        {
                            _9421 = float((_9420 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9422 = _9421;
                    }
                    _9435 = _9422;
                    break;
                } while(false);
                bool _4454 = _9435 < 0.0f;
                float _9436;
                if (_4454)
                {
                    _9436 = 0.0f;
                }
                else
                {
                    _9436 = _9435 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7333_dummy_parameter;
                uint _7365_dummy_parameter;
                float4 _9473;
                if ((_4454 && _4443) && _4446)
                {
                    uint _7397_dummy_parameter;
                    float _7421 = log(((r_depth_tm1.Load(int3(int2(floor(_9154 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7397_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7429_dummy_parameter;
                    float _7453 = log(((r_depth_tp1.Load(int3(int2(floor(_9156 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7429_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9474;
                    if (_7421 > (_7453 + 0.07999999821186065673828125f))
                    {
                        float4 _9031 = _9440;
                        _9031.x = 0.0f;
                        _9474 = _9031;
                    }
                    else
                    {
                        float4 _9475;
                        if (_7453 > (_7421 + 0.07999999821186065673828125f))
                        {
                            float4 _9033 = _9440;
                            _9033.y = 0.0f;
                            _9475 = _9033;
                        }
                        else
                        {
                            _9475 = _9440;
                        }
                        _9474 = _9475;
                    }
                    _9473 = _9474;
                }
                else
                {
                    _9473 = _9440;
                }
                float _4506 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4508 = _9435 >= 0.0f;
                float _9456;
                if (_4508)
                {
                    _9456 = _9435 - _4506;
                }
                else
                {
                    float _9452;
                    if (_4443)
                    {
                        float _9451;
                        _9451 = 2.0f;
                        float _7511;
                        for (int _9450 = 0; _9450 < 24; _9451 = _7511, _9450++)
                        {
                            float _7475 = float(_9450 & 7) * 0.785398185253143310546875f;
                            int _7477 = _9450 >> 3;
                            int _9453;
                            if (_7477 == 0)
                            {
                                _9453 = 16;
                            }
                            else
                            {
                                _9453 = (_7477 == 1) ? 48 : 96;
                            }
                            uint _7527_dummy_parameter;
                            _7511 = min(_9451, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9154 + ((cbFI_MvDepthLaneSizeRcp * float(_9453)) * float2(cos(_7475), sin(_7475))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7527_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9452 = _9451;
                    }
                    else
                    {
                        _9452 = 0.0f;
                    }
                    _9456 = _9452;
                }
                float _9463;
                if (_4508)
                {
                    _9463 = _9435 - _4506;
                }
                else
                {
                    float _9459;
                    if (_4446)
                    {
                        float _9458;
                        _9458 = 2.0f;
                        float _7625;
                        for (int _9457 = 0; _9457 < 24; _9458 = _7625, _9457++)
                        {
                            float _7589 = float(_9457 & 7) * 0.785398185253143310546875f;
                            int _7591 = _9457 >> 3;
                            int _9460;
                            if (_7591 == 0)
                            {
                                _9460 = 16;
                            }
                            else
                            {
                                _9460 = (_7591 == 1) ? 48 : 96;
                            }
                            uint _7657_dummy_parameter;
                            _7625 = min(_9458, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9156 + ((cbFI_MvDepthLaneSizeRcp * float(_9460)) * float2(cos(_7589), sin(_7589))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7657_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9459 = _9458;
                    }
                    else
                    {
                        _9459 = 0.0f;
                    }
                    _9463 = _9459;
                }
                float _9464;
                if (_4443)
                {
                    uint _7689_dummy_parameter;
                    _9464 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9154 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7689_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9464 = 0.0f;
                }
                float _9465;
                if (_4446)
                {
                    uint _7709_dummy_parameter;
                    _9465 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9156 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7709_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9465 = 0.0f;
                }
                bool _4563;
                if (_4443)
                {
                    _4563 = _9464 > ((exp((_9456 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4563 = _4443;
                }
                float4 _9481;
                if (_4563)
                {
                    float4 _9035 = _9473;
                    _9035.x = 0.0f;
                    _9481 = _9035;
                }
                else
                {
                    _9481 = _9473;
                }
                bool _4575;
                if (_4446)
                {
                    _4575 = _9465 > ((exp((_9463 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4575 = _4446;
                }
                float4 _9483;
                if (_4575)
                {
                    float4 _9037 = _9481;
                    _9037.y = 0.0f;
                    _9483 = _9037;
                }
                else
                {
                    _9483 = _9481;
                }
                float4 _9546;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4508)
                {
                    bool _4595;
                    if (_4443)
                    {
                        _4595 = _9464 < ((exp((_9456 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4595 = _4443;
                    }
                    float4 _9485;
                    if (_4595)
                    {
                        float4 _9039 = _9483;
                        _9039.x = 0.0f;
                        _9485 = _9039;
                    }
                    else
                    {
                        _9485 = _9483;
                    }
                    bool _4607;
                    if (_4446)
                    {
                        _4607 = _9465 < ((exp((_9463 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4607 = _4446;
                    }
                    float4 _9547;
                    if (_4607)
                    {
                        float4 _9041 = _9485;
                        _9041.y = 0.0f;
                        _9547 = _9041;
                    }
                    else
                    {
                        _9547 = _9485;
                    }
                    _9546 = _9547;
                }
                else
                {
                    _9546 = _9483;
                }
                _10005 = float3(_9436, log(((r_depth_tm1.Load(int3(int2(floor(_9154 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7333_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9156 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7365_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _9545 = _9546;
            }
            else
            {
                _10005 = float3(0.0f, 0.0f, 0.5f);
                _9545 = _9440;
            }
            bool _4618 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4367;
            bool _4624;
            if (_4618)
            {
                _4624 = _4421 || _4427;
            }
            else
            {
                _4624 = _4618;
            }
            float4 _9568;
            if (_4624)
            {
                float _9540;
                do
                {
                    uint4 _7889 = r_warped_motion_qdata_tp1.Load(int3(_9184, 0));
                    uint _7890 = _7889.x;
                    if (_7890 != 0u)
                    {
                        float _9539;
                        if (_7890 == 0u)
                        {
                            _9539 = -1.0f;
                        }
                        else
                        {
                            _9539 = float((_7890 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9540 = _9539;
                        break;
                    }
                    int _9522;
                    uint _9523;
                    _9523 = _7890;
                    _9522 = -1;
                    uint _9538;
                    for (; _9522 <= 1; _9523 = _9538, _9522++)
                    {
                        _9538 = _9523;
                        for (int _9536 = -1; _9536 <= 1; )
                        {
                            _9538 = max(_9538, r_warped_motion_qdata_tp1.Load(int3(clamp(_9184 + int2(_9536, _9522), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9536++;
                            continue;
                        }
                    }
                    if (_9523 != 0u)
                    {
                        float _9535;
                        if (_9523 == 0u)
                        {
                            _9535 = -1.0f;
                        }
                        else
                        {
                            _9535 = float((_9523 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9540 = _9535;
                        break;
                    }
                    uint _9525;
                    _9525 = 4294967295u;
                    uint _10750;
                    for (int _9524 = 0; _9524 < 8; _9525 = _10750, _9524++)
                    {
                        int _9528 = 0;
                        for (;;)
                        {
                            if (_9528 < 5)
                            {
                                int2 _7840 = _9184 + (_1093[_9524] * _1102[_9528].xx);
                                bool _7843 = any(bool2(_7840.x < int2(0, 0).x, _7840.y < int2(0, 0).y));
                                bool _7851;
                                if (!_7843)
                                {
                                    _7851 = any(bool2(_7840.x >= cbFI_MvDepthLaneSize.x, _7840.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7851 = _7843;
                                }
                                if (_7851)
                                {
                                    _10750 = _9525;
                                    break;
                                }
                                uint4 _7929 = r_warped_motion_qdata_tp1.Load(int3(_7840, 0));
                                uint _7930 = _7929.x;
                                if (_7930 != 0u)
                                {
                                    _10750 = min(_9525, _7930);
                                    break;
                                }
                                _9528++;
                                continue;
                            }
                            else
                            {
                                _10750 = _9525;
                                break;
                            }
                        }
                    }
                    float _9527;
                    if (_9525 == 4294967295u)
                    {
                        _9527 = -1.0f;
                    }
                    else
                    {
                        float _9526;
                        if (_9525 == 0u)
                        {
                            _9526 = -1.0f;
                        }
                        else
                        {
                            _9526 = float((_9525 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9527 = _9526;
                    }
                    _9540 = _9527;
                    break;
                } while(false);
                float4 _9569;
                if (_9540 >= 0.0f)
                {
                    float _7951 = (exp((_9540 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4643;
                    if (_4421)
                    {
                        uint _7958_dummy_parameter;
                        _4643 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7958_dummy_parameter))))), 0)).x) > _7951;
                    }
                    else
                    {
                        _4643 = _4421;
                    }
                    float4 _9558;
                    if (_4643)
                    {
                        float4 _9043 = _9545;
                        _9043.z = 0.0f;
                        _9558 = _9043;
                    }
                    else
                    {
                        _9558 = _9545;
                    }
                    bool _4655;
                    if (_4427)
                    {
                        uint _7978_dummy_parameter;
                        _4655 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7978_dummy_parameter))))), 0)).x) > _7951;
                    }
                    else
                    {
                        _4655 = _4427;
                    }
                    float4 _9570;
                    if (_4655)
                    {
                        float4 _9045 = _9558;
                        _9045.w = 0.0f;
                        _9570 = _9045;
                    }
                    else
                    {
                        _9570 = _9558;
                    }
                    _9569 = _9570;
                }
                else
                {
                    _9569 = _9545;
                }
                _9568 = _9569;
            }
            else
            {
                _9568 = _9545;
            }
            bool _4663 = _4409 != _4415;
            bool _4670;
            if (_4663)
            {
                _4670 = _4409 ? _4355 : _4358;
            }
            else
            {
                _4670 = _4663;
            }
            bool _4677;
            if (_4670)
            {
                _4677 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4677 = _4670;
            }
            float4 _9653;
            if (_4677)
            {
                bool2 _4682 = _4409.xx;
                float2 _4683 = float2(_4682.x ? _9154.x : _9156.x, _4682.y ? _9154.y : _9156.y);
                float _9560;
                if (_4409)
                {
                    uint _7998_dummy_parameter;
                    _9560 = r_depth_tm1.Load(int3(int2(floor(_4683 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7998_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8014_dummy_parameter;
                    _9560 = r_depth_tp1.Load(int3(int2(floor(_4683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8014_dummy_parameter))))), 0)).x;
                }
                float4x4 _9561;
                if (_4409)
                {
                    _9561 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9561 = cbFI_MotionTP1ToTM1;
                }
                float2 _9562;
                do
                {
                    float _8041 = _4683.x;
                    float _8044 = 1.0f - _4683.y;
                    float4 _8055 = mul(float4((float2(_8041, _8044) * 2.0f) - 1.0f.xx, _9560, 1.0f), _9561);
                    float _8057 = _8055.w;
                    if (!(_8057 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9562 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8070 = ((_8055.xy / _8057.xx) + 1.0f.xx) * 0.5f;
                    _9562 = float2(_8070.x - _8041, _8044 - _8070.y);
                    break;
                } while(false);
                float2 _4713 = float2(cbFI_DisplaySize);
                float4 _9654;
                if (!(length(((_4683 + _9562) - float2(_4682.x ? _9156.x : _9154.x, _4682.y ? _9156.y : _9154.y)) * _4713) <= ((0.100000001490116119384765625f * length(_9562 * _4713)) + 8.0f)))
                {
                    float4 _9655;
                    if (_4409)
                    {
                        float4 _9055 = _9568;
                        _9055.x = 0.0f;
                        _9655 = _9055;
                    }
                    else
                    {
                        float4 _9057 = _9568;
                        _9057.y = 0.0f;
                        _9655 = _9057;
                    }
                    _9654 = _9655;
                }
                else
                {
                    _9654 = _9568;
                }
                _9653 = _9654;
            }
            else
            {
                _9653 = _9568;
            }
            float4 _4738 = _9338 * _9653;
            float _4740 = dot(_4738, 1.0f.xxxx);
            float4 _9833;
            bool _9853;
            if (_4740 > 0.0f)
            {
                _9853 = _9307;
                _9833 = _4738 / _4740.xxxx;
            }
            else
            {
                bool _4751 = any(bool4(_9653.x < 1.0f.xxxx.x, _9653.y < 1.0f.xxxx.y, _9653.z < 1.0f.xxxx.z, _9653.w < 1.0f.xxxx.w));
                if (_4751)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8092;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8092);
                    }
                }
                bool4 _10780 = _4751.xxxx;
                _9853 = _4751 ? true : _9307;
                _9833 = float4(_10780.x ? 0.0f.xxxx.x : _9338.x, _10780.y ? 0.0f.xxxx.y : _9338.y, _10780.z ? 0.0f.xxxx.z : _9338.z, _10780.w ? 0.0f.xxxx.w : _9338.w);
            }
            _9966 = _10005;
            _9852 = _9853;
            _9832 = _9833;
        }
        else
        {
            _9966 = float3(0.0f, 0.0f, 0.5f);
            _9852 = _9307;
            _9832 = _9338;
        }
        uint _4760 = (cbFI_pad0 >> 24u) & 31u;
        uint _4764 = (cbFI_pad0 >> 16u) & 255u;
        bool _4766 = _4760 != 0u;
        bool _4768 = _4764 == 12u;
        bool _4771 = _4764 == 13u;
        float4 _9849;
        if ((_4766 || _4768) || _4771)
        {
            float _9656;
            do
            {
                bool _8176 = all(bool2(_9157.x > 0.0f.xx.x, _9157.y > 0.0f.xx.y));
                bool _8182;
                if (_8176)
                {
                    _8182 = all(bool2(_9157.x < 1.0f.xx.x, _9157.y < 1.0f.xx.y));
                }
                else
                {
                    _8182 = _8176;
                }
                bool _8113 = !_8182;
                bool _8120;
                if (!_8113)
                {
                    bool _8187 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
                    bool _8193;
                    if (_8187)
                    {
                        _8193 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8193 = _8187;
                    }
                    _8120 = !_8193;
                }
                else
                {
                    _8120 = _8113;
                }
                if (_8120)
                {
                    _9656 = 0.0f;
                    break;
                }
                uint _8200_dummy_parameter;
                uint _8216_dummy_parameter;
                float4 _8141 = mul(float4((float2(_9157.x, 1.0f - _9157.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9157 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8200_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8143 = _8141.w;
                if (abs(_8143) < 9.9999999747524270787835121154785e-07f)
                {
                    _9656 = 0.0f;
                    break;
                }
                float _8154 = abs(cbFI_DeviceToViewDepth.y / ((_8141.z / _8143) - cbFI_DeviceToViewDepth.x));
                float _8157 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8216_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9656 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8154 - _8157) / max(max(_8154, _8157), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8264 = all(bool2(_9158.x > 0.0f.xx.x, _9158.y > 0.0f.xx.y));
            bool _8270;
            if (_8264)
            {
                _8270 = all(bool2(_9158.x < 1.0f.xx.x, _9158.y < 1.0f.xx.y));
            }
            else
            {
                _8270 = _8264;
            }
            float _9657;
            if (_8270)
            {
                uint _8277_dummy_parameter;
                _9657 = length((_5571 + (r_motion_tp1.Load(int3(int2(floor(_9158 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8277_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9657 = 1000000.0f;
            }
            float _9668;
            if ((_4760 & 1u) != 0u)
            {
                _9668 = _9656;
            }
            else
            {
                _9668 = 1.0f;
            }
            float _9669;
            if ((_4760 & 2u) != 0u)
            {
                _9669 = _9668 * (1.0f - smoothstep(2.0f, 8.0f, _9657));
            }
            else
            {
                _9669 = _9668;
            }
            float _9670;
            if ((_4760 & 4u) != 0u)
            {
                _9670 = _9669 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6292 - _6300) - length(_6276 - _6284))));
            }
            else
            {
                _9670 = _9669;
            }
            float _9843;
            if ((_4760 & 8u) != 0u)
            {
                _9843 = lerp(1.0f, _9670, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6276 - _6284)));
            }
            else
            {
                _9843 = _9670;
            }
            bool _4846 = (_4760 & 16u) != 0u;
            bool _4855;
            if (_4846)
            {
                _4855 = length(_9152 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4855 = _4846;
            }
            float _10782 = _4855 ? 1.0f : _9843;
            bool _4861 = _4766 && _6485;
            bool _4866;
            if (_4861)
            {
                bool _8302 = all(bool2(_9154.x > 0.0f.xx.x, _9154.y > 0.0f.xx.y));
                bool _8308;
                if (_8302)
                {
                    _8308 = all(bool2(_9154.x < 1.0f.xx.x, _9154.y < 1.0f.xx.y));
                }
                else
                {
                    _8308 = _8302;
                }
                _4866 = _8308;
            }
            else
            {
                _4866 = _4861;
            }
            bool _4871;
            if (_4866)
            {
                bool _8313 = all(bool2(_9156.x > 0.0f.xx.x, _9156.y > 0.0f.xx.y));
                bool _8319;
                if (_8313)
                {
                    _8319 = all(bool2(_9156.x < 1.0f.xx.x, _9156.y < 1.0f.xx.y));
                }
                else
                {
                    _8319 = _8313;
                }
                _4871 = _8319;
            }
            else
            {
                _4871 = _4866;
            }
            float4 _9850;
            if (_4871)
            {
                float _4877 = _9832.x + _9832.y;
                float _4886 = (_9832.z + _9832.w) * (1.0f - _10782);
                float _9846;
                if (_4877 > 9.9999997473787516355514526367188e-06f)
                {
                    _9846 = _9832.x / _4877;
                }
                else
                {
                    _9846 = _4020;
                }
                _9850 = float4(_9832.x + (_4886 * _9846), _9832.y + (_4886 * (1.0f - _9846)), _9832.zw * _10782);
            }
            else
            {
                _9850 = _9832;
            }
            _9849 = _9850;
        }
        else
        {
            _9849 = _9832;
        }
        float3 _10553;
        if (_9852)
        {
            float3 _8325 = r_current_interpolation_source.Load(int3(_3420, 0)).xyz;
            float3 _10554;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6485)
            {
                uint _8332_dummy_parameter;
                float _9957;
                _9957 = r_depth_tm1.Load(int3(int2(floor(_9154 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8332_dummy_parameter))))), 0)).x;
                float _4998;
                for (int _9956 = 0; _9956 < 24; _9957 = _4998, _9956++)
                {
                    float _4970 = float(_9956 & 7) * 0.785398185253143310546875f;
                    int _4972 = _9956 >> 3;
                    int _10604;
                    if (_4972 == 0)
                    {
                        _10604 = 16;
                    }
                    else
                    {
                        _10604 = (_4972 == 1) ? 48 : 96;
                    }
                    uint _8352_dummy_parameter;
                    _4998 = max(_9957, r_depth_tm1.Load(int3(int2(floor(clamp(_9154 + ((cbFI_MvDepthLaneSizeRcp * float(_10604)) * float2(cos(_4970), sin(_4970))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8352_dummy_parameter))))), 0)).x);
                }
                float2 _9958;
                do
                {
                    float _8374 = 1.0f - _9154.y;
                    float4 _8385 = mul(float4((float2(_9154.x, _8374) * 2.0f) - 1.0f.xx, _9957, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8387 = _8385.w;
                    if (!(_8387 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9958 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8400 = ((_8385.xy / _8387.xx) + 1.0f.xx) * 0.5f;
                    _9958 = float2(_8400.x - _9154.x, _8374 - _8400.y);
                    break;
                } while(false);
                float2 _5009 = _9154 + _9958;
                bool _8418 = all(bool2(_5009.x > 0.0f.xx.x, _5009.y > 0.0f.xx.y));
                bool _8424;
                if (_8418)
                {
                    _8424 = all(bool2(_5009.x < 1.0f.xx.x, _5009.y < 1.0f.xx.y));
                }
                else
                {
                    _8424 = _8418;
                }
                float3 _10555;
                if (_8424)
                {
                    float _5015 = abs(cbFI_DeviceToViewDepth.y / (_9957 - cbFI_DeviceToViewDepth.x));
                    uint _8444_dummy_parameter;
                    int2 _8444 = int2(spvTextureSize(r_depth_m2, uint(0), _8444_dummy_parameter));
                    float _5019 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5009 * float2(_8444))), int2(0, 0), _8444 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10560;
                    if (abs(_5019 - _5015) <= (0.20000000298023223876953125f * max(_5019, _5015)))
                    {
                        uint _8478_dummy_parameter;
                        int2 _8478 = int2(spvTextureSize(r_colour_m2, uint(0), _8478_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8501;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8501);
                        }
                        _10560 = r_colour_m2.Load(int3(clamp(int2(floor(_5009 * float2(_8478))), int2(0, 0), _8478 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8511;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8511);
                        }
                        _10560 = _8325;
                    }
                    _10555 = _10560;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8521;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8521);
                    }
                    _10555 = _8325;
                }
                _10554 = _10555;
            }
            else
            {
                _10554 = _8325;
            }
            _10553 = _10554;
        }
        else
        {
            _10553 = (((_6276 * _9849.x) + (_6284 * _9849.y)) + (_6292 * _9849.z)) + (_6300 * _9849.w);
        }
        uint _5047 = cbFI_pad0 & 255u;
        bool _10445;
        float3 _10552;
        if (_5047 != 0u)
        {
            float3 _5052 = r_present_backbuffer.Load(int3(_3420, 0)).xyz;
            float3 _5056 = r_current_interpolation_source.Load(int3(_3420, 0)).xyz;
            float3 _5060 = abs(_5052 - _5056);
            float3 _9961;
            if (_5047 == 2u)
            {
                _9961 = (abs(_5056) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9961 = 0.000244140625f.xxx;
            }
            bool _5076 = any(bool3(_5060.x > _9961.x, _5060.y > _9961.y, _5060.z > _9961.z));
            bool3 _10783 = _5076.xxx;
            _10552 = float3(_10783.x ? _5052.x : _10553.x, _10783.y ? _5052.y : _10553.y, _10783.z ? _5052.z : _10553.z);
            _10445 = _5076;
        }
        else
        {
            _10552 = _10553;
            _10445 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8536;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8536);
        }
        float3 _10535;
        if (_4764 == 1u)
        {
            _10535 = lerp(_6276, _6284, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10536;
            if (_4764 == 2u)
            {
                _10536 = lerp(_6292, _6300, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10537;
                if (_4764 == 3u)
                {
                    _10537 = float(_10445).xxx;
                }
                else
                {
                    float3 _10538;
                    if (_4764 == 4u)
                    {
                        _10538 = float3(((_9152 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10539;
                        if (_4764 == 5u)
                        {
                            _10539 = float3(((_5571 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10540;
                            if (_4764 == 6u)
                            {
                                _10540 = float3(_9849.xy, _9849.z + _9849.w);
                            }
                            else
                            {
                                float3 _10541;
                                if (_4764 == 7u)
                                {
                                    _10541 = r_current_interpolation_source.Load(int3(_3420, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10542;
                                    if (_4764 == 8u)
                                    {
                                        _10542 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3795, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10543;
                                        if (_4768)
                                        {
                                            uint _8558_dummy_parameter;
                                            uint _8590_dummy_parameter;
                                            _10543 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3795 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8558_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3795 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8590_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10544;
                                            if (_4771)
                                            {
                                                _10544 = _6292;
                                            }
                                            else
                                            {
                                                float3 _10545;
                                                if (_4764 == 20u)
                                                {
                                                    _10545 = _6276;
                                                }
                                                else
                                                {
                                                    float3 _10546;
                                                    if (_4764 == 21u)
                                                    {
                                                        _10546 = _6284;
                                                    }
                                                    else
                                                    {
                                                        float3 _10547;
                                                        if (_4764 == 22u)
                                                        {
                                                            _10547 = _6300;
                                                        }
                                                        else
                                                        {
                                                            float3 _10548;
                                                            if (_4764 == 18u)
                                                            {
                                                                _10548 = _10251;
                                                            }
                                                            else
                                                            {
                                                                float3 _10549;
                                                                if (_4764 == 19u)
                                                                {
                                                                    _10549 = _10105;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10785 = (_4764 == 23u).xxx;
                                                                    _10549 = float3(_10785.x ? _9966.x : _10552.x, _10785.y ? _9966.y : _10552.y, _10785.z ? _9966.z : _10552.z);
                                                                }
                                                                _10548 = _10549;
                                                            }
                                                            _10547 = _10548;
                                                        }
                                                        _10546 = _10547;
                                                    }
                                                    _10545 = _10546;
                                                }
                                                _10544 = _10545;
                                            }
                                            _10543 = _10544;
                                        }
                                        _10542 = _10543;
                                    }
                                    _10541 = _10542;
                                }
                                _10540 = _10541;
                            }
                            _10539 = _10540;
                        }
                        _10538 = _10539;
                    }
                    _10537 = _10538;
                }
                _10536 = _10537;
            }
            _10535 = _10536;
        }
        float3 _10534;
        if ((_4764 >= 9u) && (_4764 <= 11u))
        {
            uint _5240 = 64u + uint((_9184.y * cbFI_MvDepthLaneSize.x) + _9184.x);
            uint _5244 = rw_nfru_diagnostics.Load<uint>(_5240 * 4 + 0) & 15u;
            float3 _10565;
            if (_4764 == 10u)
            {
                float3 _10533;
                if ((rw_nfru_diagnostics.Load<uint>(_5240 * 4 + 0) & 32u) != 0u)
                {
                    _10533 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10532;
                    if ((rw_nfru_diagnostics.Load<uint>(_5240 * 4 + 0) & 16u) != 0u)
                    {
                        _10532 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5265 = ((rw_nfru_diagnostics.Load<uint>(_5240 * 4 + 0) & 64u) != 0u).xxx;
                        _10532 = float3(_5265.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5265.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5265.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10533 = _10532;
                }
                _10565 = _10533;
            }
            else
            {
                float3 _10566;
                if (_4764 == 11u)
                {
                    uint _5278 = (rw_nfru_diagnostics.Load<uint>(_5240 * 4 + 0) >> 8u) & 15u;
                    uint _5281 = (rw_nfru_diagnostics.Load<uint>(_5240 * 4 + 0) >> 12u) & 15u;
                    float3 _10525;
                    if ((_5244 == 2u) || (_5244 == 3u))
                    {
                        _10525 = _3116[_5244];
                    }
                    else
                    {
                        bool _5293 = _5278 == 3u;
                        bool _5295 = _5281 == 3u;
                        float3 _10526;
                        if (_5293 && _5295)
                        {
                            _10526 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10527;
                            if (_5293)
                            {
                                _10527 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10528;
                                if (_5295)
                                {
                                    _10528 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10529;
                                    if ((_5278 == 4u) || (_5281 == 4u))
                                    {
                                        _10529 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10530;
                                        if ((_5278 == 1u) || (_5281 == 1u))
                                        {
                                            _10530 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10787 = (_5244 == 1u).xxx;
                                            _10530 = float3(_10787.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10787.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10787.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10529 = _10530;
                                    }
                                    _10528 = _10529;
                                }
                                _10527 = _10528;
                            }
                            _10526 = _10527;
                        }
                        _10525 = _10526;
                    }
                    _10566 = _10525;
                }
                else
                {
                    _10566 = _3116[min(_5244, 7u)];
                }
                _10565 = _10566;
            }
            _10534 = _10565;
        }
        else
        {
            _10534 = _10535;
        }
        float4 _10569;
        if ((_4764 >= 14u) && (_4764 <= 16u))
        {
            float2 _10567;
            if (_4764 == 14u)
            {
                uint _5351_dummy_parameter;
                uint _5357_dummy_parameter;
                _10567 = r_flow_tm1.Load(int3(clamp(int2(floor(_3795 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5351_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5357_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10568;
                if (_4764 == 16u)
                {
                    uint _8641 = r_warped_flow_qdata_tm1.Load(int3(_3811, 0)).x & 2147483647u;
                    uint _8673 = uint(max((int((_8641 >> 16u) & 15u) - 6), 0));
                    _10568 = ((float2(float((1 - (2 * int((_8641 >> 15u) & 1u))) * int(((_8641 >> uint(7)) & 127u) << _8673)), float((1 - (2 * int((_8641 >> 14u) & 1u))) * int((_8641 & 127u) << _8673))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10568 = _5571 * float2(cbFI_DisplaySize);
                }
                _10567 = _10568;
            }
            uint2 _5390 = uint2(clamp(round(_10567 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5392 = _5390.x;
            uint _5399 = _5390.y;
            _10569 = float4(float(_5392 & 255u), float((_5392 >> 8u) | ((_5399 & 15u) << 4u)), float(_5399 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10570;
            if (_4764 == 17u)
            {
                _10570 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3811, 0)).x != 0u), _4154, 0.0f, 1.0f);
            }
            else
            {
                _10570 = float4(_10534, 1.0f);
            }
            _10569 = _10570;
        }
        rw_output[_3420] = _10569.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5443 = ((uint(_3420.y) * uint(cbFI_DisplaySize.x)) + uint(_3420.x)) * 6u;
            uint _8719 = spvPackHalf2x16(clamp(_6275.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5443 * 4 + 0, (((_8719 & 32767u) >> 4u) | ((((_8719 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6275.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8754 = spvPackHalf2x16(clamp(_6283.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5443 + 1u) * 4 + 0, (((_8754 & 32767u) >> 4u) | ((((_8754 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6283.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8789 = spvPackHalf2x16(clamp(_6291.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5443 + 2u) * 4 + 0, (((_8789 & 32767u) >> 4u) | ((((_8789 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6291.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8824 = spvPackHalf2x16(clamp(_6299.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5443 + 3u) * 4 + 0, (((_8824 & 32767u) >> 4u) | ((((_8824 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6299.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8851 = r_current_interpolation_source.Load(int3(_3420, 0));
            uint _8865 = spvPackHalf2x16(clamp(_8851.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5443 + 4u) * 4 + 0, (((_8865 & 32767u) >> 4u) | ((((_8865 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8851.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10603;
            if (_10445 || (_4764 != 0u))
            {
                _10603 = 4294967295u;
            }
            else
            {
                uint _8900 = spvPackHalf2x16(clamp(_10569.xy, 0.0f.xx, 65000.0f.xx));
                _10603 = (((_8900 & 32767u) >> 4u) | ((((_8900 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10569.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5443 + 5u) * 4 + 0, _10603);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3420] = float4(r_current_interpolation_source.Load(int3(_3420, 0)).xyz, 1.0f).xyz;
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
