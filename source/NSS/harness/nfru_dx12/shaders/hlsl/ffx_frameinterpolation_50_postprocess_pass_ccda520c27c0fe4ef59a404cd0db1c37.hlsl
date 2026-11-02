static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3089[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3393 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3393.x >= cbFI_DisplaySize.x, _3393.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3393] = float4(r_present_backbuffer.Load(int3(_3393, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3393] = float4(r_current_interpolation_source.Load(int3(_3393, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3767 = (float2(_3393) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3778 = int2(floor(_3767 * float2(cbFI_MvDepthLaneSize)));
        int2 _3783 = int2(floor(_3767 * float2(cbFI_FlowLaneSize)));
        float4 _5513 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3767 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5519 = r_warped_filled_flow_tm1.Load(int3(_3783, 0)).xy;
        float2 _5525 = r_warped_filled_motion_tp1.Load(int3(_3778, 0)).xy;
        bool _5547 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9075;
        if (_5547)
        {
            float _5560 = ((2.0f * _3767.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9075 = float2(atan(_5560) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3767.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5560 * _5560))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9075 = _3767;
        }
        bool _3804 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9096;
        bool _9117;
        int2 _9128;
        float3 _10173;
        if (_3804)
        {
            float _9077;
            float _9079;
            _9079 = 2.0f;
            _9077 = -1.0f;
            uint _3457[9];
            float _10563;
            float _10566;
            for (int _9076 = 0; _9076 < 9; _9079 = _10566, _9077 = _10563, _9076++)
            {
                _3457[_9076] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3778 + int2((_9076 % 3) - 1, (_9076 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3457[_9076] != 0u)
                {
                    float _10558;
                    if (_3457[_9076] == 0u)
                    {
                        _10558 = -1.0f;
                    }
                    else
                    {
                        _10558 = float((_3457[_9076] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10566 = min(_9079, _10558);
                    _10563 = max(_9077, _10558);
                }
                else
                {
                    _10566 = _9079;
                    _10563 = _9077;
                }
            }
            float _3850 = float(_9077 >= 0.0f);
            float3 _8886 = 0.0f.xxx;
            _8886.y = _3850;
            float2 _9097;
            bool _9118;
            int2 _9129;
            float3 _10174;
            if ((_9077 - _9079) > 0.0199999995529651641845703125f)
            {
                float _9085;
                int2 _9086;
                float2 _9087;
                int2 _9089;
                float2 _9095;
                _9095 = _5525;
                _9089 = _3778;
                _9087 = _5525;
                _9086 = _3778;
                _9085 = -1.0f;
                float _10571;
                int2 _10575;
                float2 _10586;
                int2 _10597;
                float2 _10630;
                float _10676;
                int _9084 = 0;
                float _10539 = 1000000000.0f;
                for (; _9084 < 9; _10539 = _10676, _9095 = _10630, _9089 = _10597, _9087 = _10586, _9086 = _10575, _9085 = _10571, _9084++)
                {
                    if (_3457[_9084] == 0u)
                    {
                        _10676 = _10539;
                        _10630 = _9095;
                        _10597 = _9089;
                        _10586 = _9087;
                        _10575 = _9086;
                        _10571 = _9085;
                        continue;
                    }
                    int2 _3885 = clamp(_3778 + int2((_9084 % 3) - 1, (_9084 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5635 = _3457[_9084] & 2147483647u;
                    uint _5667 = uint(max((int((_5635 >> 16u) & 15u) - 6), 0));
                    float2 _3891 = (float2(float((1 - (2 * int((_5635 >> 15u) & 1u))) * int(((_5635 >> uint(7)) & 127u) << _5667)), float((1 - (2 * int((_5635 >> 14u) & 1u))) * int((_5635 & 127u) << _5667))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10525;
                    if (_3457[_9084] == 0u)
                    {
                        _10525 = -1.0f;
                    }
                    else
                    {
                        _10525 = float((_3457[_9084] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3896 = _10525 - 0.100000001490116119384765625f;
                    float2 _10526;
                    if (_5547)
                    {
                        float2 _5744 = clamp((((_9075 + (_3891 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5747 = tan(_5744.x);
                        _10526 = (float2(_5747 / cbFI_DeviceToViewDepth.z, (tan(_5744.y) * sqrt(1.0f + (_5747 * _5747))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10526 = _9075 + (_3891 * cbFI_Timestep);
                    }
                    float _3903 = cbFI_Timestep - 1.0f;
                    float2 _10527;
                    if (_5547)
                    {
                        float2 _5815 = clamp((((_9075 + (_3891 * _3903)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5818 = tan(_5815.x);
                        _10527 = (float2(_5818 / cbFI_DeviceToViewDepth.z, (tan(_5815.y) * sqrt(1.0f + (_5818 * _5818))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10527 = _9075 + (_3891 * _3903);
                    }
                    bool _5851 = all(bool2(_10526.x > 0.0f.xx.x, _10526.y > 0.0f.xx.y));
                    bool _5857;
                    if (_5851)
                    {
                        _5857 = all(bool2(_10526.x < 1.0f.xx.x, _10526.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5857 = _5851;
                    }
                    float _10530;
                    if (_5857)
                    {
                        uint _5864_dummy_parameter;
                        _10530 = max((_3896 - (log((r_depth_tm1.Load(int3(int2(floor(_10526 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5864_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10530 = 0.0f;
                    }
                    bool _5894 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
                    bool _5900;
                    if (_5894)
                    {
                        _5900 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5900 = _5894;
                    }
                    float _10531;
                    if (_5900)
                    {
                        uint _5907_dummy_parameter;
                        _10531 = _10530 + max((_3896 - (log((r_depth_tp1.Load(int3(int2(floor(_10527 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5907_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10531 = _10530;
                    }
                    float _10572;
                    int2 _10576;
                    float2 _10587;
                    int2 _10598;
                    float2 _10631;
                    float _10677;
                    if (_10531 == 0.0f)
                    {
                        bool _3938 = _3896 > _9085;
                        bool2 _10685 = _3938.xx;
                        _10677 = _10539;
                        _10631 = float2(_10685.x ? _3891.x : _9095.x, _10685.y ? _3891.y : _9095.y);
                        _10598 = int2(_10685.x ? _3885.x : _9089.x, _10685.y ? _3885.y : _9089.y);
                        _10587 = _9087;
                        _10576 = _9086;
                        _10572 = _3938 ? _3896 : _9085;
                    }
                    else
                    {
                        bool _3947 = _10531 < _10539;
                        bool2 _10681 = _3947.xx;
                        _10677 = _3947 ? _10531 : _10539;
                        _10631 = _9095;
                        _10598 = _9089;
                        _10587 = float2(_10681.x ? _3891.x : _9087.x, _10681.y ? _3891.y : _9087.y);
                        _10576 = int2(_10681.x ? _3885.x : _9086.x, _10681.y ? _3885.y : _9086.y);
                        _10572 = _9085;
                    }
                    _10676 = _10677;
                    _10630 = _10631;
                    _10597 = _10598;
                    _10586 = _10587;
                    _10575 = _10576;
                    _10571 = _10572;
                }
                bool _3959 = _9085 < 0.0f;
                bool2 _10691 = _3959.xx;
                int2 _10694 = int2(_10691.x ? _9086.x : _9089.x, _10691.y ? _9086.y : _9089.y);
                _10174 = float3(1.0f, _3850, float(any(bool2(_10694.x != _3778.x, _10694.y != _3778.y))));
                _9129 = _10694;
                _9118 = _3959 ? false : true;
                _9097 = float2(_10691.x ? _9087.x : _9095.x, _10691.y ? _9087.y : _9095.y);
            }
            else
            {
                _10174 = _8886;
                _9129 = _3778;
                _9118 = false;
                _9097 = _5525;
            }
            _10173 = _10174;
            _9128 = _9129;
            _9117 = _9118;
            _9096 = _9097;
        }
        else
        {
            _10173 = 0.0f.xxx;
            _9128 = _3778;
            _9117 = false;
            _9096 = _5525;
        }
        float2 _9098;
        if (_5547)
        {
            float2 _5972 = clamp((((_9075 + (_9096 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5975 = tan(_5972.x);
            _9098 = (float2(_5975 / cbFI_DeviceToViewDepth.z, (tan(_5972.y) * sqrt(1.0f + (_5975 * _5975))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9098 = _9075 + (_9096 * cbFI_Timestep);
        }
        float _3982 = cbFI_Timestep - 1.0f;
        float2 _9100;
        if (_5547)
        {
            float2 _6043 = clamp((((_9075 + (_9096 * _3982)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6046 = tan(_6043.x);
            _9100 = (float2(_6046 / cbFI_DeviceToViewDepth.z, (tan(_6043.y) * sqrt(1.0f + (_6046 * _6046))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9100 = _9075 + (_9096 * _3982);
        }
        float _3987 = -cbFI_Timestep;
        float2 _9101;
        if (_5547)
        {
            float2 _6114 = clamp((((_9075 + (_5519 * _3987)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6117 = tan(_6114.x);
            _9101 = (float2(_6117 / cbFI_DeviceToViewDepth.z, (tan(_6114.y) * sqrt(1.0f + (_6117 * _6117))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9101 = _9075 + (_5519 * _3987);
        }
        float _3992 = 1.0f - cbFI_Timestep;
        float2 _9102;
        if (_5547)
        {
            float2 _6185 = clamp((((_9075 + (_5519 * _3992)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6188 = tan(_6185.x);
            _9102 = (float2(_6188 / cbFI_DeviceToViewDepth.z, (tan(_6185.y) * sqrt(1.0f + (_6188 * _6188))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9102 = _9075 + (_5519 * _3992);
        }
        float4 _6223 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9098, 0.0f);
        float3 _6224 = _6223.xyz;
        float4 _6231 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9100, 0.0f);
        float3 _6232 = _6231.xyz;
        float4 _6239 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9101, 0.0f);
        float3 _6240 = _6239.xyz;
        float4 _6247 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9102, 0.0f);
        float3 _6248 = _6247.xyz;
        float4 _6262 = exp(_5513 - max(max(max(_5513.x, _5513.y), _5513.z), _5513.w).xxxx);
        float4 _6269 = _6262 / (dot(_6262, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4011 = _3804 && (!_9117);
        bool _4020;
        if (_4011)
        {
            _4020 = (_6269.z + _6269.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4020 = _4011;
        }
        bool _4031;
        if (_4020)
        {
            _4031 = length((_9101 - _9098) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4031 = _4020;
        }
        bool _9141;
        if (_4031)
        {
            uint4 _6288 = r_warped_motion_qdata_tp1.Load(int3(_9128, 0));
            uint _6289 = _6288.x;
            bool _9144;
            if (_6289 != 0u)
            {
                float _9130;
                if (_6289 == 0u)
                {
                    _9130 = -1.0f;
                }
                else
                {
                    _9130 = float((_6289 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4041 = _9130 - 0.12000000476837158203125f;
                bool _6308 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
                bool _6314;
                if (_6308)
                {
                    _6314 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
                }
                else
                {
                    _6314 = _6308;
                }
                bool _4051;
                if (_6314)
                {
                    uint _6321_dummy_parameter;
                    _4051 = (log((r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6321_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4041;
                }
                else
                {
                    _4051 = _6314;
                }
                bool _4065;
                if (!_4051)
                {
                    bool _6351 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
                    bool _6357;
                    if (_6351)
                    {
                        _6357 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6357 = _6351;
                    }
                    bool _4063;
                    if (_6357)
                    {
                        uint _6364_dummy_parameter;
                        _4063 = (log((r_depth_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6364_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4041;
                    }
                    else
                    {
                        _4063 = _6357;
                    }
                    _4065 = _4063;
                }
                else
                {
                    _4065 = _4051;
                }
                _9144 = _4065;
            }
            else
            {
                _9144 = false;
            }
            _9141 = _9144;
        }
        else
        {
            _9141 = false;
        }
        bool _4070 = _9117 || _9141;
        bool _4075;
        if (_4070)
        {
            bool _6394 = all(bool2(_9098.x > 0.0f.xx.x, _9098.y > 0.0f.xx.y));
            bool _6400;
            if (_6394)
            {
                _6400 = all(bool2(_9098.x < 1.0f.xx.x, _9098.y < 1.0f.xx.y));
            }
            else
            {
                _6400 = _6394;
            }
            _4075 = _6400;
        }
        else
        {
            _4075 = _4070;
        }
        bool _4080;
        if (_4075)
        {
            bool _6405 = all(bool2(_9100.x > 0.0f.xx.x, _9100.y > 0.0f.xx.y));
            bool _6411;
            if (_6405)
            {
                _6411 = all(bool2(_9100.x < 1.0f.xx.x, _9100.y < 1.0f.xx.y));
            }
            else
            {
                _6411 = _6405;
            }
            _4080 = _6411;
        }
        else
        {
            _4080 = _4075;
        }
        float4 _9235;
        if (_4080)
        {
            float _4083 = _6269.x;
            float _4085 = _6269.y;
            float _4086 = _4083 + _4085;
            float _4091 = _6269.z + _6269.w;
            float _9159;
            if (_4086 > 0.001000000047497451305389404296875f)
            {
                _9159 = _4083 / _4086;
            }
            else
            {
                _9159 = _3992;
            }
            _9235 = float4(_4083 + (_4091 * _9159), _4085 + (_4091 * (1.0f - _9159)), 0.0f, 0.0f);
        }
        else
        {
            _9235 = _6269;
        }
        bool _6439 = (cbFI_pad0 & 1024u) != 0u;
        bool _6415 = !_6439;
        bool _6416 = !_6415;
        bool _6433;
        if (_6416)
        {
            _6433 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9128.y * cbFI_MvDepthLaneSize.x) + _9128.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6433 = _6415;
        }
        bool _6465;
        if (_6416)
        {
            _6465 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3783.y * cbFI_FlowLaneSize.x) + _3783.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6465 = _6415;
        }
        float _4126 = float(_6465);
        bool _9247;
        float4 _9277;
        float3 _10030;
        if (_6439)
        {
            bool _4136;
            if (_6433)
            {
                _4136 = all(bool2(_9098.x > 0.0f.xx.x, _9098.y > 0.0f.xx.y));
            }
            else
            {
                _4136 = _6433;
            }
            bool _4142;
            if (_4136)
            {
                _4142 = all(bool2(_9098.x < 1.0f.xx.x, _9098.y < 1.0f.xx.y));
            }
            else
            {
                _4142 = _4136;
            }
            bool _4149;
            if (_6433)
            {
                _4149 = all(bool2(_9100.x > 0.0f.xx.x, _9100.y > 0.0f.xx.y));
            }
            else
            {
                _4149 = _6433;
            }
            bool _4155;
            if (_4149)
            {
                _4155 = all(bool2(_9100.x < 1.0f.xx.x, _9100.y < 1.0f.xx.y));
            }
            else
            {
                _4155 = _4149;
            }
            bool _4162;
            if (_6465)
            {
                _4162 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
            }
            else
            {
                _4162 = _6465;
            }
            bool _4168;
            if (_4162)
            {
                _4168 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
            }
            else
            {
                _4168 = _4162;
            }
            bool _4175;
            if (_6465)
            {
                _4175 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
            }
            else
            {
                _4175 = _6465;
            }
            bool _4181;
            if (_4175)
            {
                _4181 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
            }
            else
            {
                _4181 = _4175;
            }
            bool _4183 = !_6433;
            if (_4183)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6507;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6507);
                }
            }
            bool _4188 = !_6465;
            if (_4188)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6517;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6517);
                }
            }
            if (_6433 && _4188)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6527;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6527);
                }
            }
            if (_4183 && _6465)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6537;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6537);
                }
            }
            float _4207 = float(_4142);
            float _4209 = float(_4155);
            bool _4212 = _4168 && _4181;
            float _9193;
            if (_4212)
            {
                _9193 = 1.0f;
            }
            else
            {
                _9193 = (_4168 || _4181) ? 0.5f : 0.0f;
            }
            bool _9198;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4142)) && (!_4155))
            {
                bool _4242;
                if (_4212)
                {
                    float _9196;
                    do
                    {
                        bool _6621 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
                        bool _6627;
                        if (_6621)
                        {
                            _6627 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6627 = _6621;
                        }
                        bool _6558 = !_6627;
                        bool _6565;
                        if (!_6558)
                        {
                            bool _6632 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
                            bool _6638;
                            if (_6632)
                            {
                                _6638 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6638 = _6632;
                            }
                            _6565 = !_6638;
                        }
                        else
                        {
                            _6565 = _6558;
                        }
                        if (_6565)
                        {
                            _9196 = 0.0f;
                            break;
                        }
                        uint _6645_dummy_parameter;
                        uint _6661_dummy_parameter;
                        float4 _6586 = mul(float4((float2(_9101.x, 1.0f - _9101.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6645_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6588 = _6586.w;
                        if (abs(_6588) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9196 = 0.0f;
                            break;
                        }
                        float _6599 = abs(cbFI_DeviceToViewDepth.y / ((_6586.z / _6588) - cbFI_DeviceToViewDepth.x));
                        float _6602 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6661_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9196 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6599 - _6602) / max(max(_6599, _6602), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4242 = _9196 >= 0.5f;
                }
                else
                {
                    _4242 = _4212;
                }
                bool _9199;
                if (_4242)
                {
                    uint _6711_dummy_parameter;
                    float2 _9197;
                    do
                    {
                        float _6737 = 1.0f - _9101.y;
                        float4 _6748 = mul(float4((float2(_9101.x, _6737) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6711_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6750 = _6748.w;
                        if (!(_6750 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9197 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6763 = ((_6748.xy / _6750.xx) + 1.0f.xx) * 0.5f;
                        _9197 = float2(_6763.x - _9101.x, _6737 - _6763.y);
                        break;
                    } while(false);
                    float2 _4256 = float2(cbFI_DisplaySize);
                    _9199 = length(((_9101 + _9197) - _9102) * _4256) <= ((0.100000001490116119384765625f * length(_9197 * _4256)) + 8.0f);
                }
                else
                {
                    _9199 = _4242;
                }
                _9198 = _9199;
            }
            else
            {
                _9198 = true;
            }
            bool _4270 = !_9198;
            bool _10695 = _4270 ? false : _4181;
            bool _10696 = _4270 ? false : _4168;
            bool _9248;
            float4 _9278;
            if (!(((_4142 && _4155) && _10696) && _10695))
            {
                float4 _4292 = _9235 * float4(_4207, _4209, float(_10696), float(_10695));
                float _4294 = dot(_4292, 1.0f.xxxx);
                bool _4297 = !(_4294 > 0.0f);
                float4 _9279;
                if (!_4297)
                {
                    _9279 = _4292 / _4294.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6785;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6785);
                    }
                    _9279 = 0.0f.xxxx;
                }
                _9278 = _9279;
                _9248 = _4297;
            }
            else
            {
                _9278 = _9235;
                _9248 = false;
            }
            _10030 = float3(_4207, _4209, _9193);
            _9277 = _9278;
            _9247 = _9248;
        }
        else
        {
            _10030 = float3(float(_6433), _4126, 0.0f);
            _9277 = _9235;
            _9247 = false;
        }
        float4 _9761;
        bool _9781;
        float3 _9893;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9247))
        {
            bool _4320 = _9277.x > 0.00999999977648258209228515625f;
            bool _4323 = _9277.y > 0.00999999977648258209228515625f;
            bool _4332 = (_9277.z + _9277.w) > 0.0199999995529651641845703125f;
            bool _4338;
            if (_4332)
            {
                bool _6791 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
                bool _6797;
                if (_6791)
                {
                    _6797 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
                }
                else
                {
                    _6797 = _6791;
                }
                _4338 = _6797;
            }
            else
            {
                _4338 = _4332;
            }
            bool _4343;
            if (_4338)
            {
                bool _6802 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
                bool _6808;
                if (_6802)
                {
                    _6808 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
                }
                else
                {
                    _6808 = _6802;
                }
                _4343 = _6808;
            }
            else
            {
                _4343 = _4338;
            }
            bool _4350;
            if (_4343)
            {
                float _9281;
                do
                {
                    bool _6891 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
                    bool _6897;
                    if (_6891)
                    {
                        _6897 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6897 = _6891;
                    }
                    bool _6828 = !_6897;
                    bool _6835;
                    if (!_6828)
                    {
                        bool _6902 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
                        bool _6908;
                        if (_6902)
                        {
                            _6908 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6908 = _6902;
                        }
                        _6835 = !_6908;
                    }
                    else
                    {
                        _6835 = _6828;
                    }
                    if (_6835)
                    {
                        _9281 = 0.0f;
                        break;
                    }
                    uint _6915_dummy_parameter;
                    uint _6931_dummy_parameter;
                    float4 _6856 = mul(float4((float2(_9101.x, 1.0f - _9101.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6915_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6858 = _6856.w;
                    if (abs(_6858) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9281 = 0.0f;
                        break;
                    }
                    float _6869 = abs(cbFI_DeviceToViewDepth.y / ((_6856.z / _6858) - cbFI_DeviceToViewDepth.x));
                    float _6872 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6931_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9281 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6869 - _6872) / max(max(_6869, _6872), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4350 = _9281 < 0.5f;
            }
            else
            {
                _4350 = _4343;
            }
            float4 _9296;
            if (_4350)
            {
                uint _6981_dummy_parameter;
                uint _7012_dummy_parameter;
                float4 _9297;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6981_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7012_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9297 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9297 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9296 = _9297;
            }
            else
            {
                _9296 = 1.0f.xxxx;
            }
            bool _4374;
            if (_6433)
            {
                bool _7041 = all(bool2(_9098.x > 0.0f.xx.x, _9098.y > 0.0f.xx.y));
                bool _7047;
                if (_7041)
                {
                    _7047 = all(bool2(_9098.x < 1.0f.xx.x, _9098.y < 1.0f.xx.y));
                }
                else
                {
                    _7047 = _7041;
                }
                _4374 = _7047;
            }
            else
            {
                _4374 = _6433;
            }
            bool _4380;
            if (_6433)
            {
                bool _7052 = all(bool2(_9100.x > 0.0f.xx.x, _9100.y > 0.0f.xx.y));
                bool _7058;
                if (_7052)
                {
                    _7058 = all(bool2(_9100.x < 1.0f.xx.x, _9100.y < 1.0f.xx.y));
                }
                else
                {
                    _7058 = _7052;
                }
                _4380 = _7058;
            }
            else
            {
                _4380 = _6433;
            }
            bool _4386;
            if (_6465)
            {
                bool _7063 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
                bool _7069;
                if (_7063)
                {
                    _7069 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
                }
                else
                {
                    _7069 = _7063;
                }
                _4386 = _7069;
            }
            else
            {
                _4386 = _6465;
            }
            bool _4392;
            if (_6465)
            {
                bool _7074 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
                bool _7080;
                if (_7074)
                {
                    _7080 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
                }
                else
                {
                    _7080 = _7074;
                }
                _4392 = _7080;
            }
            else
            {
                _4392 = _6465;
            }
            bool _4395 = _4386 != _4392;
            bool _4401;
            if (_4395)
            {
                _4401 = _4374 || _4380;
            }
            else
            {
                _4401 = _4395;
            }
            float4 _9376;
            if (_4401)
            {
                float4 _8971 = _9296;
                _8971.z = 0.0f;
                _8971.w = 0.0f;
                _9376 = _8971;
            }
            else
            {
                _9376 = _9296;
            }
            bool _4408 = _4374 && _4320;
            bool _4411 = _4380 && _4323;
            float4 _9480;
            float3 _9930;
            if (_4408 || _4411)
            {
                float _9373;
                do
                {
                    uint4 _7219 = r_warped_motion_qdata_tp1.Load(int3(_9128, 0));
                    uint _7220 = _7219.x;
                    if (_7220 != 0u)
                    {
                        float _9372;
                        if (_7220 == 0u)
                        {
                            _9372 = -1.0f;
                        }
                        else
                        {
                            _9372 = float((_7220 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9373 = _9372;
                        break;
                    }
                    int _9355;
                    uint _9356;
                    _9356 = _7220;
                    _9355 = -1;
                    uint _9371;
                    for (; _9355 <= 1; _9356 = _9371, _9355++)
                    {
                        _9371 = _9356;
                        for (int _9369 = -1; _9369 <= 1; )
                        {
                            _9371 = max(_9371, r_warped_motion_qdata_tp1.Load(int3(clamp(_9128 + int2(_9369, _9355), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9369++;
                            continue;
                        }
                    }
                    if (_9356 != 0u)
                    {
                        float _9368;
                        if (_9356 == 0u)
                        {
                            _9368 = -1.0f;
                        }
                        else
                        {
                            _9368 = float((_9356 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9373 = _9368;
                        break;
                    }
                    uint _9358;
                    _9358 = 4294967295u;
                    uint _10667;
                    for (int _9357 = 0; _9357 < 8; _9358 = _10667, _9357++)
                    {
                        int _9361 = 0;
                        for (;;)
                        {
                            if (_9361 < 5)
                            {
                                int2 _7170 = _9128 + (_1093[_9357] * _1102[_9361].xx);
                                bool _7173 = any(bool2(_7170.x < int2(0, 0).x, _7170.y < int2(0, 0).y));
                                bool _7181;
                                if (!_7173)
                                {
                                    _7181 = any(bool2(_7170.x >= cbFI_MvDepthLaneSize.x, _7170.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7181 = _7173;
                                }
                                if (_7181)
                                {
                                    _10667 = _9358;
                                    break;
                                }
                                uint4 _7259 = r_warped_motion_qdata_tp1.Load(int3(_7170, 0));
                                uint _7260 = _7259.x;
                                if (_7260 != 0u)
                                {
                                    _10667 = min(_9358, _7260);
                                    break;
                                }
                                _9361++;
                                continue;
                            }
                            else
                            {
                                _10667 = _9358;
                                break;
                            }
                        }
                    }
                    float _9360;
                    if (_9358 == 4294967295u)
                    {
                        _9360 = -1.0f;
                    }
                    else
                    {
                        float _9359;
                        if (_9358 == 0u)
                        {
                            _9359 = -1.0f;
                        }
                        else
                        {
                            _9359 = float((_9358 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9360 = _9359;
                    }
                    _9373 = _9360;
                    break;
                } while(false);
                bool _4419 = _9373 < 0.0f;
                uint _7281_dummy_parameter;
                uint _7313_dummy_parameter;
                float4 _9409;
                if ((_4419 && _4408) && _4411)
                {
                    uint _7345_dummy_parameter;
                    float _7369 = log((r_depth_tm1.Load(int3(int2(floor(_9098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7345_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7377_dummy_parameter;
                    float _7401 = log((r_depth_tp1.Load(int3(int2(floor(_9100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7377_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9410;
                    if (_7369 > (_7401 + 0.07999999821186065673828125f))
                    {
                        float4 _8975 = _9376;
                        _8975.x = 0.0f;
                        _9410 = _8975;
                    }
                    else
                    {
                        float4 _9411;
                        if (_7401 > (_7369 + 0.07999999821186065673828125f))
                        {
                            float4 _8977 = _9376;
                            _8977.y = 0.0f;
                            _9411 = _8977;
                        }
                        else
                        {
                            _9411 = _9376;
                        }
                        _9410 = _9411;
                    }
                    _9409 = _9410;
                }
                else
                {
                    _9409 = _9376;
                }
                float _4461 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4463 = _9373 >= 0.0f;
                float _9392;
                if (_4463)
                {
                    _9392 = _9373 - _4461;
                }
                else
                {
                    float _9388;
                    if (_4408)
                    {
                        float _9387;
                        _9387 = 2.0f;
                        float _7459;
                        for (int _9386 = 0; _9386 < 24; _9387 = _7459, _9386++)
                        {
                            float _7423 = float(_9386 & 7) * 0.785398185253143310546875f;
                            int _7425 = _9386 >> 3;
                            int _9389;
                            if (_7425 == 0)
                            {
                                _9389 = 16;
                            }
                            else
                            {
                                _9389 = (_7425 == 1) ? 48 : 96;
                            }
                            uint _7475_dummy_parameter;
                            _7459 = min(_9387, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9098 + ((cbFI_MvDepthLaneSizeRcp * float(_9389)) * float2(cos(_7423), sin(_7423))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7475_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9388 = _9387;
                    }
                    else
                    {
                        _9388 = 0.0f;
                    }
                    _9392 = _9388;
                }
                float _9399;
                if (_4463)
                {
                    _9399 = _9373 - _4461;
                }
                else
                {
                    float _9395;
                    if (_4411)
                    {
                        float _9394;
                        _9394 = 2.0f;
                        float _7573;
                        for (int _9393 = 0; _9393 < 24; _9394 = _7573, _9393++)
                        {
                            float _7537 = float(_9393 & 7) * 0.785398185253143310546875f;
                            int _7539 = _9393 >> 3;
                            int _9396;
                            if (_7539 == 0)
                            {
                                _9396 = 16;
                            }
                            else
                            {
                                _9396 = (_7539 == 1) ? 48 : 96;
                            }
                            uint _7605_dummy_parameter;
                            _7573 = min(_9394, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9100 + ((cbFI_MvDepthLaneSizeRcp * float(_9396)) * float2(cos(_7537), sin(_7537))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7605_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9395 = _9394;
                    }
                    else
                    {
                        _9395 = 0.0f;
                    }
                    _9399 = _9395;
                }
                float _9400;
                if (_4408)
                {
                    uint _7637_dummy_parameter;
                    _9400 = r_depth_tm1.Load(int3(int2(floor(_9098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7637_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9400 = 0.0f;
                }
                float _9401;
                if (_4411)
                {
                    uint _7656_dummy_parameter;
                    _9401 = r_depth_tp1.Load(int3(int2(floor(_9100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7656_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9401 = 0.0f;
                }
                bool _4518;
                if (_4408)
                {
                    _4518 = _9400 > ((exp((_9392 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4518 = _4408;
                }
                float4 _9417;
                if (_4518)
                {
                    float4 _8979 = _9409;
                    _8979.x = 0.0f;
                    _9417 = _8979;
                }
                else
                {
                    _9417 = _9409;
                }
                bool _4530;
                if (_4411)
                {
                    _4530 = _9401 > ((exp((_9399 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4530 = _4411;
                }
                float4 _9419;
                if (_4530)
                {
                    float4 _8981 = _9417;
                    _8981.y = 0.0f;
                    _9419 = _8981;
                }
                else
                {
                    _9419 = _9417;
                }
                float4 _9481;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4463)
                {
                    bool _4550;
                    if (_4408)
                    {
                        _4550 = _9400 < ((exp((_9392 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4550 = _4408;
                    }
                    float4 _9421;
                    if (_4550)
                    {
                        float4 _8983 = _9419;
                        _8983.x = 0.0f;
                        _9421 = _8983;
                    }
                    else
                    {
                        _9421 = _9419;
                    }
                    bool _4562;
                    if (_4411)
                    {
                        _4562 = _9401 < ((exp((_9399 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4562 = _4411;
                    }
                    float4 _9482;
                    if (_4562)
                    {
                        float4 _8985 = _9421;
                        _8985.y = 0.0f;
                        _9482 = _8985;
                    }
                    else
                    {
                        _9482 = _9421;
                    }
                    _9481 = _9482;
                }
                else
                {
                    _9481 = _9419;
                }
                _9930 = float3(float(_4419), log((r_depth_tm1.Load(int3(int2(floor(_9098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7281_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7313_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _9480 = _9481;
            }
            else
            {
                _9930 = float3(0.0f, 0.0f, 0.5f);
                _9480 = _9376;
            }
            bool _4573 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4332;
            bool _4579;
            if (_4573)
            {
                _4579 = _4386 || _4392;
            }
            else
            {
                _4579 = _4573;
            }
            float4 _9502;
            if (_4579)
            {
                float _9475;
                do
                {
                    uint4 _7835 = r_warped_motion_qdata_tp1.Load(int3(_9128, 0));
                    uint _7836 = _7835.x;
                    if (_7836 != 0u)
                    {
                        float _9474;
                        if (_7836 == 0u)
                        {
                            _9474 = -1.0f;
                        }
                        else
                        {
                            _9474 = float((_7836 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9475 = _9474;
                        break;
                    }
                    int _9457;
                    uint _9458;
                    _9458 = _7836;
                    _9457 = -1;
                    uint _9473;
                    for (; _9457 <= 1; _9458 = _9473, _9457++)
                    {
                        _9473 = _9458;
                        for (int _9471 = -1; _9471 <= 1; )
                        {
                            _9473 = max(_9473, r_warped_motion_qdata_tp1.Load(int3(clamp(_9128 + int2(_9471, _9457), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9471++;
                            continue;
                        }
                    }
                    if (_9458 != 0u)
                    {
                        float _9470;
                        if (_9458 == 0u)
                        {
                            _9470 = -1.0f;
                        }
                        else
                        {
                            _9470 = float((_9458 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9475 = _9470;
                        break;
                    }
                    uint _9460;
                    _9460 = 4294967295u;
                    uint _10668;
                    for (int _9459 = 0; _9459 < 8; _9460 = _10668, _9459++)
                    {
                        int _9463 = 0;
                        for (;;)
                        {
                            if (_9463 < 5)
                            {
                                int2 _7786 = _9128 + (_1093[_9459] * _1102[_9463].xx);
                                bool _7789 = any(bool2(_7786.x < int2(0, 0).x, _7786.y < int2(0, 0).y));
                                bool _7797;
                                if (!_7789)
                                {
                                    _7797 = any(bool2(_7786.x >= cbFI_MvDepthLaneSize.x, _7786.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7797 = _7789;
                                }
                                if (_7797)
                                {
                                    _10668 = _9460;
                                    break;
                                }
                                uint4 _7875 = r_warped_motion_qdata_tp1.Load(int3(_7786, 0));
                                uint _7876 = _7875.x;
                                if (_7876 != 0u)
                                {
                                    _10668 = min(_9460, _7876);
                                    break;
                                }
                                _9463++;
                                continue;
                            }
                            else
                            {
                                _10668 = _9460;
                                break;
                            }
                        }
                    }
                    float _9462;
                    if (_9460 == 4294967295u)
                    {
                        _9462 = -1.0f;
                    }
                    else
                    {
                        float _9461;
                        if (_9460 == 0u)
                        {
                            _9461 = -1.0f;
                        }
                        else
                        {
                            _9461 = float((_9460 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9462 = _9461;
                    }
                    _9475 = _9462;
                    break;
                } while(false);
                float4 _9503;
                if (_9475 >= 0.0f)
                {
                    float _7897 = (exp((_9475 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4598;
                    if (_4386)
                    {
                        uint _7904_dummy_parameter;
                        _4598 = r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7904_dummy_parameter))))), 0)).x > _7897;
                    }
                    else
                    {
                        _4598 = _4386;
                    }
                    float4 _9493;
                    if (_4598)
                    {
                        float4 _8987 = _9480;
                        _8987.z = 0.0f;
                        _9493 = _8987;
                    }
                    else
                    {
                        _9493 = _9480;
                    }
                    bool _4610;
                    if (_4392)
                    {
                        uint _7923_dummy_parameter;
                        _4610 = r_depth_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7923_dummy_parameter))))), 0)).x > _7897;
                    }
                    else
                    {
                        _4610 = _4392;
                    }
                    float4 _9504;
                    if (_4610)
                    {
                        float4 _8989 = _9493;
                        _8989.w = 0.0f;
                        _9504 = _8989;
                    }
                    else
                    {
                        _9504 = _9493;
                    }
                    _9503 = _9504;
                }
                else
                {
                    _9503 = _9480;
                }
                _9502 = _9503;
            }
            else
            {
                _9502 = _9480;
            }
            bool _4618 = _4374 != _4380;
            bool _4625;
            if (_4618)
            {
                _4625 = _4374 ? _4320 : _4323;
            }
            else
            {
                _4625 = _4618;
            }
            float4 _9585;
            if (_4625)
            {
                bool2 _4630 = _4374.xx;
                float2 _4631 = float2(_4630.x ? _9098.x : _9100.x, _4630.y ? _9098.y : _9100.y);
                float _9495;
                if (_4374)
                {
                    uint _7942_dummy_parameter;
                    _9495 = r_depth_tm1.Load(int3(int2(floor(_4631 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7942_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7958_dummy_parameter;
                    _9495 = r_depth_tp1.Load(int3(int2(floor(_4631 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7958_dummy_parameter))))), 0)).x;
                }
                float4x4 _9496;
                if (_4374)
                {
                    _9496 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9496 = cbFI_MotionTP1ToTM1;
                }
                float2 _9497;
                do
                {
                    float _7985 = _4631.x;
                    float _7988 = 1.0f - _4631.y;
                    float4 _7999 = mul(float4((float2(_7985, _7988) * 2.0f) - 1.0f.xx, _9495, 1.0f), _9496);
                    float _8001 = _7999.w;
                    if (!(_8001 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9497 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8014 = ((_7999.xy / _8001.xx) + 1.0f.xx) * 0.5f;
                    _9497 = float2(_8014.x - _7985, _7988 - _8014.y);
                    break;
                } while(false);
                float2 _4661 = float2(cbFI_DisplaySize);
                float4 _9586;
                if (!(length(((_4631 + _9497) - float2(_4630.x ? _9100.x : _9098.x, _4630.y ? _9100.y : _9098.y)) * _4661) <= ((0.100000001490116119384765625f * length(_9497 * _4661)) + 8.0f)))
                {
                    float4 _9587;
                    if (_4374)
                    {
                        float4 _8999 = _9502;
                        _8999.x = 0.0f;
                        _9587 = _8999;
                    }
                    else
                    {
                        float4 _9001 = _9502;
                        _9001.y = 0.0f;
                        _9587 = _9001;
                    }
                    _9586 = _9587;
                }
                else
                {
                    _9586 = _9502;
                }
                _9585 = _9586;
            }
            else
            {
                _9585 = _9502;
            }
            float4 _4686 = _9277 * _9585;
            float _4688 = dot(_4686, 1.0f.xxxx);
            float4 _9762;
            bool _9782;
            if (_4688 > 0.0f)
            {
                _9782 = _9247;
                _9762 = _4686 / _4688.xxxx;
            }
            else
            {
                bool _4699 = any(bool4(_9585.x < 1.0f.xxxx.x, _9585.y < 1.0f.xxxx.y, _9585.z < 1.0f.xxxx.z, _9585.w < 1.0f.xxxx.w));
                if (_4699)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8036;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8036);
                    }
                }
                bool4 _10698 = _4699.xxxx;
                _9782 = _4699 ? true : _9247;
                _9762 = float4(_10698.x ? 0.0f.xxxx.x : _9277.x, _10698.y ? 0.0f.xxxx.y : _9277.y, _10698.z ? 0.0f.xxxx.z : _9277.z, _10698.w ? 0.0f.xxxx.w : _9277.w);
            }
            _9893 = _9930;
            _9781 = _9782;
            _9761 = _9762;
        }
        else
        {
            _9893 = float3(0.0f, 0.0f, 0.5f);
            _9781 = _9247;
            _9761 = _9277;
        }
        uint _4708 = (cbFI_pad0 >> 24u) & 31u;
        uint _4712 = (cbFI_pad0 >> 16u) & 255u;
        bool _4714 = _4708 != 0u;
        bool _4716 = _4712 == 12u;
        bool _4719 = _4712 == 13u;
        float4 _9778;
        if ((_4714 || _4716) || _4719)
        {
            float _9588;
            do
            {
                bool _8120 = all(bool2(_9101.x > 0.0f.xx.x, _9101.y > 0.0f.xx.y));
                bool _8126;
                if (_8120)
                {
                    _8126 = all(bool2(_9101.x < 1.0f.xx.x, _9101.y < 1.0f.xx.y));
                }
                else
                {
                    _8126 = _8120;
                }
                bool _8057 = !_8126;
                bool _8064;
                if (!_8057)
                {
                    bool _8131 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
                    bool _8137;
                    if (_8131)
                    {
                        _8137 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8137 = _8131;
                    }
                    _8064 = !_8137;
                }
                else
                {
                    _8064 = _8057;
                }
                if (_8064)
                {
                    _9588 = 0.0f;
                    break;
                }
                uint _8144_dummy_parameter;
                uint _8160_dummy_parameter;
                float4 _8085 = mul(float4((float2(_9101.x, 1.0f - _9101.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8144_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8087 = _8085.w;
                if (abs(_8087) < 9.9999999747524270787835121154785e-07f)
                {
                    _9588 = 0.0f;
                    break;
                }
                float _8098 = abs(cbFI_DeviceToViewDepth.y / ((_8085.z / _8087) - cbFI_DeviceToViewDepth.x));
                float _8101 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8160_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9588 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8098 - _8101) / max(max(_8098, _8101), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8208 = all(bool2(_9102.x > 0.0f.xx.x, _9102.y > 0.0f.xx.y));
            bool _8214;
            if (_8208)
            {
                _8214 = all(bool2(_9102.x < 1.0f.xx.x, _9102.y < 1.0f.xx.y));
            }
            else
            {
                _8214 = _8208;
            }
            float _9589;
            if (_8214)
            {
                uint _8221_dummy_parameter;
                _9589 = length((_5519 + (r_motion_tp1.Load(int3(int2(floor(_9102 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8221_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9589 = 1000000.0f;
            }
            float _9600;
            if ((_4708 & 1u) != 0u)
            {
                _9600 = _9588;
            }
            else
            {
                _9600 = 1.0f;
            }
            float _9601;
            if ((_4708 & 2u) != 0u)
            {
                _9601 = _9600 * (1.0f - smoothstep(2.0f, 8.0f, _9589));
            }
            else
            {
                _9601 = _9600;
            }
            float _9602;
            if ((_4708 & 4u) != 0u)
            {
                _9602 = _9601 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6240 - _6248) - length(_6224 - _6232))));
            }
            else
            {
                _9602 = _9601;
            }
            float _9772;
            if ((_4708 & 8u) != 0u)
            {
                _9772 = lerp(1.0f, _9602, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6224 - _6232)));
            }
            else
            {
                _9772 = _9602;
            }
            bool _4794 = (_4708 & 16u) != 0u;
            bool _4803;
            if (_4794)
            {
                _4803 = length(_9096 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4803 = _4794;
            }
            float _10700 = _4803 ? 1.0f : _9772;
            bool _4809 = _4714 && _6433;
            bool _4814;
            if (_4809)
            {
                bool _8246 = all(bool2(_9098.x > 0.0f.xx.x, _9098.y > 0.0f.xx.y));
                bool _8252;
                if (_8246)
                {
                    _8252 = all(bool2(_9098.x < 1.0f.xx.x, _9098.y < 1.0f.xx.y));
                }
                else
                {
                    _8252 = _8246;
                }
                _4814 = _8252;
            }
            else
            {
                _4814 = _4809;
            }
            bool _4819;
            if (_4814)
            {
                bool _8257 = all(bool2(_9100.x > 0.0f.xx.x, _9100.y > 0.0f.xx.y));
                bool _8263;
                if (_8257)
                {
                    _8263 = all(bool2(_9100.x < 1.0f.xx.x, _9100.y < 1.0f.xx.y));
                }
                else
                {
                    _8263 = _8257;
                }
                _4819 = _8263;
            }
            else
            {
                _4819 = _4814;
            }
            float4 _9779;
            if (_4819)
            {
                float _4825 = _9761.x + _9761.y;
                float _4834 = (_9761.z + _9761.w) * (1.0f - _10700);
                float _9775;
                if (_4825 > 9.9999997473787516355514526367188e-06f)
                {
                    _9775 = _9761.x / _4825;
                }
                else
                {
                    _9775 = _3992;
                }
                _9779 = float4(_9761.x + (_4834 * _9775), _9761.y + (_4834 * (1.0f - _9775)), _9761.zw * _10700);
            }
            else
            {
                _9779 = _9761;
            }
            _9778 = _9779;
        }
        else
        {
            _9778 = _9761;
        }
        float3 _10471;
        if (_9781)
        {
            float3 _8269 = r_current_interpolation_source.Load(int3(_3393, 0)).xyz;
            float3 _10472;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6433)
            {
                uint _8276_dummy_parameter;
                float _9884;
                _9884 = r_depth_tm1.Load(int3(int2(floor(_9098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8276_dummy_parameter))))), 0)).x;
                float _4946;
                for (int _9883 = 0; _9883 < 24; _9884 = _4946, _9883++)
                {
                    float _4918 = float(_9883 & 7) * 0.785398185253143310546875f;
                    int _4920 = _9883 >> 3;
                    int _10522;
                    if (_4920 == 0)
                    {
                        _10522 = 16;
                    }
                    else
                    {
                        _10522 = (_4920 == 1) ? 48 : 96;
                    }
                    uint _8296_dummy_parameter;
                    _4946 = min(_9884, r_depth_tm1.Load(int3(int2(floor(clamp(_9098 + ((cbFI_MvDepthLaneSizeRcp * float(_10522)) * float2(cos(_4918), sin(_4918))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8296_dummy_parameter))))), 0)).x);
                }
                float2 _9885;
                do
                {
                    float _8318 = 1.0f - _9098.y;
                    float4 _8329 = mul(float4((float2(_9098.x, _8318) * 2.0f) - 1.0f.xx, _9884, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8331 = _8329.w;
                    if (!(_8331 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9885 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8344 = ((_8329.xy / _8331.xx) + 1.0f.xx) * 0.5f;
                    _9885 = float2(_8344.x - _9098.x, _8318 - _8344.y);
                    break;
                } while(false);
                float2 _4957 = _9098 + _9885;
                bool _8362 = all(bool2(_4957.x > 0.0f.xx.x, _4957.y > 0.0f.xx.y));
                bool _8368;
                if (_8362)
                {
                    _8368 = all(bool2(_4957.x < 1.0f.xx.x, _4957.y < 1.0f.xx.y));
                }
                else
                {
                    _8368 = _8362;
                }
                float3 _10473;
                if (_8368)
                {
                    float _4963 = abs(cbFI_DeviceToViewDepth.y / (_9884 - cbFI_DeviceToViewDepth.x));
                    uint _8388_dummy_parameter;
                    int2 _8388 = int2(spvTextureSize(r_depth_m2, uint(0), _8388_dummy_parameter));
                    float _4967 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4957 * float2(_8388))), int2(0, 0), _8388 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10478;
                    if (abs(_4967 - _4963) <= (0.20000000298023223876953125f * max(_4967, _4963)))
                    {
                        uint _8422_dummy_parameter;
                        int2 _8422 = int2(spvTextureSize(r_colour_m2, uint(0), _8422_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8445;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8445);
                        }
                        _10478 = r_colour_m2.Load(int3(clamp(int2(floor(_4957 * float2(_8422))), int2(0, 0), _8422 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8455;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8455);
                        }
                        _10478 = _8269;
                    }
                    _10473 = _10478;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8465;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8465);
                    }
                    _10473 = _8269;
                }
                _10472 = _10473;
            }
            else
            {
                _10472 = _8269;
            }
            _10471 = _10472;
        }
        else
        {
            _10471 = (((_6224 * _9778.x) + (_6232 * _9778.y)) + (_6240 * _9778.z)) + (_6248 * _9778.w);
        }
        uint _4995 = cbFI_pad0 & 255u;
        bool _10364;
        float3 _10470;
        if (_4995 != 0u)
        {
            float3 _5000 = r_present_backbuffer.Load(int3(_3393, 0)).xyz;
            float3 _5004 = r_current_interpolation_source.Load(int3(_3393, 0)).xyz;
            float3 _5008 = abs(_5000 - _5004);
            float3 _9888;
            if (_4995 == 2u)
            {
                _9888 = (abs(_5004) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9888 = 0.000244140625f.xxx;
            }
            bool _5024 = any(bool3(_5008.x > _9888.x, _5008.y > _9888.y, _5008.z > _9888.z));
            bool3 _10701 = _5024.xxx;
            _10470 = float3(_10701.x ? _5000.x : _10471.x, _10701.y ? _5000.y : _10471.y, _10701.z ? _5000.z : _10471.z);
            _10364 = _5024;
        }
        else
        {
            _10470 = _10471;
            _10364 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8480;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8480);
        }
        float3 _10453;
        if (_4712 == 1u)
        {
            _10453 = lerp(_6224, _6232, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10454;
            if (_4712 == 2u)
            {
                _10454 = lerp(_6240, _6248, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10455;
                if (_4712 == 3u)
                {
                    _10455 = float(_10364).xxx;
                }
                else
                {
                    float3 _10456;
                    if (_4712 == 4u)
                    {
                        _10456 = float3(((_9096 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10457;
                        if (_4712 == 5u)
                        {
                            _10457 = float3(((_5519 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10458;
                            if (_4712 == 6u)
                            {
                                _10458 = float3(_9778.xy, _9778.z + _9778.w);
                            }
                            else
                            {
                                float3 _10459;
                                if (_4712 == 7u)
                                {
                                    _10459 = r_current_interpolation_source.Load(int3(_3393, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10460;
                                    if (_4712 == 8u)
                                    {
                                        _10460 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3767, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10461;
                                        if (_4716)
                                        {
                                            uint _8502_dummy_parameter;
                                            uint _8534_dummy_parameter;
                                            _10461 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3767 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8502_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8534_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10462;
                                            if (_4719)
                                            {
                                                _10462 = _6240;
                                            }
                                            else
                                            {
                                                float3 _10463;
                                                if (_4712 == 20u)
                                                {
                                                    _10463 = _6224;
                                                }
                                                else
                                                {
                                                    float3 _10464;
                                                    if (_4712 == 21u)
                                                    {
                                                        _10464 = _6232;
                                                    }
                                                    else
                                                    {
                                                        float3 _10465;
                                                        if (_4712 == 22u)
                                                        {
                                                            _10465 = _6248;
                                                        }
                                                        else
                                                        {
                                                            float3 _10466;
                                                            if (_4712 == 18u)
                                                            {
                                                                _10466 = _10173;
                                                            }
                                                            else
                                                            {
                                                                float3 _10467;
                                                                if (_4712 == 19u)
                                                                {
                                                                    _10467 = _10030;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10703 = (_4712 == 23u).xxx;
                                                                    _10467 = float3(_10703.x ? _9893.x : _10470.x, _10703.y ? _9893.y : _10470.y, _10703.z ? _9893.z : _10470.z);
                                                                }
                                                                _10466 = _10467;
                                                            }
                                                            _10465 = _10466;
                                                        }
                                                        _10464 = _10465;
                                                    }
                                                    _10463 = _10464;
                                                }
                                                _10462 = _10463;
                                            }
                                            _10461 = _10462;
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
        float3 _10452;
        if ((_4712 >= 9u) && (_4712 <= 11u))
        {
            uint _5188 = 64u + uint((_9128.y * cbFI_MvDepthLaneSize.x) + _9128.x);
            uint _5192 = rw_nfru_diagnostics.Load<uint>(_5188 * 4 + 0) & 15u;
            float3 _10483;
            if (_4712 == 10u)
            {
                float3 _10451;
                if ((rw_nfru_diagnostics.Load<uint>(_5188 * 4 + 0) & 32u) != 0u)
                {
                    _10451 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10450;
                    if ((rw_nfru_diagnostics.Load<uint>(_5188 * 4 + 0) & 16u) != 0u)
                    {
                        _10450 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5213 = ((rw_nfru_diagnostics.Load<uint>(_5188 * 4 + 0) & 64u) != 0u).xxx;
                        _10450 = float3(_5213.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5213.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5213.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10451 = _10450;
                }
                _10483 = _10451;
            }
            else
            {
                float3 _10484;
                if (_4712 == 11u)
                {
                    uint _5226 = (rw_nfru_diagnostics.Load<uint>(_5188 * 4 + 0) >> 8u) & 15u;
                    uint _5229 = (rw_nfru_diagnostics.Load<uint>(_5188 * 4 + 0) >> 12u) & 15u;
                    float3 _10443;
                    if ((_5192 == 2u) || (_5192 == 3u))
                    {
                        _10443 = _3089[_5192];
                    }
                    else
                    {
                        bool _5241 = _5226 == 3u;
                        bool _5243 = _5229 == 3u;
                        float3 _10444;
                        if (_5241 && _5243)
                        {
                            _10444 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10445;
                            if (_5241)
                            {
                                _10445 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10446;
                                if (_5243)
                                {
                                    _10446 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10447;
                                    if ((_5226 == 4u) || (_5229 == 4u))
                                    {
                                        _10447 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10448;
                                        if ((_5226 == 1u) || (_5229 == 1u))
                                        {
                                            _10448 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10705 = (_5192 == 1u).xxx;
                                            _10448 = float3(_10705.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10705.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10705.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10447 = _10448;
                                    }
                                    _10446 = _10447;
                                }
                                _10445 = _10446;
                            }
                            _10444 = _10445;
                        }
                        _10443 = _10444;
                    }
                    _10484 = _10443;
                }
                else
                {
                    _10484 = _3089[min(_5192, 7u)];
                }
                _10483 = _10484;
            }
            _10452 = _10483;
        }
        else
        {
            _10452 = _10453;
        }
        float4 _10487;
        if ((_4712 >= 14u) && (_4712 <= 16u))
        {
            float2 _10485;
            if (_4712 == 14u)
            {
                uint _5299_dummy_parameter;
                uint _5305_dummy_parameter;
                _10485 = r_flow_tm1.Load(int3(clamp(int2(floor(_3767 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5299_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5305_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10486;
                if (_4712 == 16u)
                {
                    uint _8585 = r_warped_flow_qdata_tm1.Load(int3(_3783, 0)).x & 2147483647u;
                    uint _8617 = uint(max((int((_8585 >> 16u) & 15u) - 6), 0));
                    _10486 = ((float2(float((1 - (2 * int((_8585 >> 15u) & 1u))) * int(((_8585 >> uint(7)) & 127u) << _8617)), float((1 - (2 * int((_8585 >> 14u) & 1u))) * int((_8585 & 127u) << _8617))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10486 = _5519 * float2(cbFI_DisplaySize);
                }
                _10485 = _10486;
            }
            uint2 _5338 = uint2(clamp(round(_10485 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5340 = _5338.x;
            uint _5347 = _5338.y;
            _10487 = float4(float(_5340 & 255u), float((_5340 >> 8u) | ((_5347 & 15u) << 4u)), float(_5347 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10488;
            if (_4712 == 17u)
            {
                _10488 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3783, 0)).x != 0u), _4126, 0.0f, 1.0f);
            }
            else
            {
                _10488 = float4(_10452, 1.0f);
            }
            _10487 = _10488;
        }
        rw_output[_3393] = _10487.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5391 = ((uint(_3393.y) * uint(cbFI_DisplaySize.x)) + uint(_3393.x)) * 6u;
            uint _8663 = spvPackHalf2x16(clamp(_6223.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5391 * 4 + 0, (((_8663 & 32767u) >> 4u) | ((((_8663 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6223.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8698 = spvPackHalf2x16(clamp(_6231.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5391 + 1u) * 4 + 0, (((_8698 & 32767u) >> 4u) | ((((_8698 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6231.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8733 = spvPackHalf2x16(clamp(_6239.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5391 + 2u) * 4 + 0, (((_8733 & 32767u) >> 4u) | ((((_8733 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6239.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8768 = spvPackHalf2x16(clamp(_6247.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5391 + 3u) * 4 + 0, (((_8768 & 32767u) >> 4u) | ((((_8768 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6247.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8795 = r_current_interpolation_source.Load(int3(_3393, 0));
            uint _8809 = spvPackHalf2x16(clamp(_8795.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5391 + 4u) * 4 + 0, (((_8809 & 32767u) >> 4u) | ((((_8809 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8795.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10521;
            if (_10364 || (_4712 != 0u))
            {
                _10521 = 4294967295u;
            }
            else
            {
                uint _8844 = spvPackHalf2x16(clamp(_10487.xy, 0.0f.xx, 65000.0f.xx));
                _10521 = (((_8844 & 32767u) >> 4u) | ((((_8844 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10487.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5391 + 5u) * 4 + 0, _10521);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3393] = float4(r_current_interpolation_source.Load(int3(_3393, 0)).xyz, 1.0f).xyz;
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
