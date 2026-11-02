static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1192[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1201[5] = { 2, 4, 7, 11, 16 };
static const float3 _3783[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4087 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4087.x >= cbFI_DisplaySize.x, _4087.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4087] = float4(r_present_backbuffer.Load(int3(_4087, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4087] = float4(r_current_interpolation_source.Load(int3(_4087, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4561 = (float2(_4087) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4563 = float2(cbFI_MvDepthLaneSize);
        int2 _4572 = int2(floor(_4561 * _4563));
        int2 _4577 = int2(floor(_4561 * float2(cbFI_FlowLaneSize)));
        float4 _6765 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4561 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6771 = r_warped_filled_flow_tm1.Load(int3(_4577, 0)).xy;
        float2 _6777 = r_warped_filled_motion_tp1.Load(int3(_4572, 0)).xy;
        bool _6799 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14105;
        if (_6799)
        {
            float _6812 = ((2.0f * _4561.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14105 = float2(atan(_6812) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4561.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6812 * _6812))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14105 = _4561;
        }
        bool _4598 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14126;
        bool _14268;
        int2 _14349;
        float3 _16516;
        if (_4598)
        {
            float _14107;
            float _14109;
            _14109 = 2.0f;
            _14107 = -1.0f;
            uint _4171[9];
            float _17084;
            float _17087;
            for (int _14106 = 0; _14106 < 9; _14109 = _17087, _14107 = _17084, _14106++)
            {
                _4171[_14106] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4572 + int2((_14106 % 3) - 1, (_14106 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4171[_14106] != 0u)
                {
                    float _17079;
                    if (_4171[_14106] == 0u)
                    {
                        _17079 = -1.0f;
                    }
                    else
                    {
                        _17079 = float((_4171[_14106] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17087 = min(_14109, _17079);
                    _17084 = max(_14107, _17079);
                }
                else
                {
                    _17087 = _14109;
                    _17084 = _14107;
                }
            }
            float _4644 = float(_14107 >= 0.0f);
            float3 _13808 = 0.0f.xxx;
            _13808.y = _4644;
            float2 _14127;
            bool _14269;
            int2 _14350;
            float3 _16517;
            if ((_14107 - _14109) > 0.0199999995529651641845703125f)
            {
                float _14115;
                int2 _14116;
                float2 _14117;
                int2 _14119;
                float2 _14125;
                _14125 = _6777;
                _14119 = _4572;
                _14117 = _6777;
                _14116 = _4572;
                _14115 = -1.0f;
                float _17092;
                int2 _17096;
                float2 _17107;
                int2 _17118;
                float2 _17151;
                float _17198;
                int _14114 = 0;
                float _17060 = 1000000000.0f;
                for (; _14114 < 9; _17060 = _17198, _14125 = _17151, _14119 = _17118, _14117 = _17107, _14116 = _17096, _14115 = _17092, _14114++)
                {
                    if (_4171[_14114] == 0u)
                    {
                        _17198 = _17060;
                        _17151 = _14125;
                        _17118 = _14119;
                        _17107 = _14117;
                        _17096 = _14116;
                        _17092 = _14115;
                        continue;
                    }
                    int2 _4679 = clamp(_4572 + int2((_14114 % 3) - 1, (_14114 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6887 = _4171[_14114] & 2147483647u;
                    uint _6919 = uint(max((int((_6887 >> 16u) & 15u) - 6), 0));
                    float2 _4685 = (float2(float((1 - (2 * int((_6887 >> 15u) & 1u))) * int(((_6887 >> uint(7)) & 127u) << _6919)), float((1 - (2 * int((_6887 >> 14u) & 1u))) * int((_6887 & 127u) << _6919))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _17046;
                    if (_4171[_14114] == 0u)
                    {
                        _17046 = -1.0f;
                    }
                    else
                    {
                        _17046 = float((_4171[_14114] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4690 = _17046 - 0.100000001490116119384765625f;
                    float2 _17047;
                    if (_6799)
                    {
                        float2 _6996 = clamp((((_14105 + (_4685 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6999 = tan(_6996.x);
                        _17047 = (float2(_6999 / cbFI_DeviceToViewDepth.z, (tan(_6996.y) * sqrt(1.0f + (_6999 * _6999))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17047 = _14105 + (_4685 * cbFI_Timestep);
                    }
                    float _4697 = cbFI_Timestep - 1.0f;
                    float2 _17048;
                    if (_6799)
                    {
                        float2 _7067 = clamp((((_14105 + (_4685 * _4697)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7070 = tan(_7067.x);
                        _17048 = (float2(_7070 / cbFI_DeviceToViewDepth.z, (tan(_7067.y) * sqrt(1.0f + (_7070 * _7070))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17048 = _14105 + (_4685 * _4697);
                    }
                    bool _7103 = all(bool2(_17047.x > 0.0f.xx.x, _17047.y > 0.0f.xx.y));
                    bool _7109;
                    if (_7103)
                    {
                        _7109 = all(bool2(_17047.x < 1.0f.xx.x, _17047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7109 = _7103;
                    }
                    float _17051;
                    if (_7109)
                    {
                        uint _7116_dummy_parameter;
                        _17051 = max((_4690 - (log(((r_depth_tm1.Load(int3(int2(floor(_17047 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7116_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17051 = 0.0f;
                    }
                    bool _7146 = all(bool2(_17048.x > 0.0f.xx.x, _17048.y > 0.0f.xx.y));
                    bool _7152;
                    if (_7146)
                    {
                        _7152 = all(bool2(_17048.x < 1.0f.xx.x, _17048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7152 = _7146;
                    }
                    float _17052;
                    if (_7152)
                    {
                        uint _7159_dummy_parameter;
                        _17052 = _17051 + max((_4690 - (log(((r_depth_tp1.Load(int3(int2(floor(_17048 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7159_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17052 = _17051;
                    }
                    float _17093;
                    int2 _17097;
                    float2 _17108;
                    int2 _17119;
                    float2 _17152;
                    float _17199;
                    if (_17052 == 0.0f)
                    {
                        bool _4732 = _4690 > _14115;
                        bool2 _17207 = _4732.xx;
                        _17199 = _17060;
                        _17152 = float2(_17207.x ? _4685.x : _14125.x, _17207.y ? _4685.y : _14125.y);
                        _17119 = int2(_17207.x ? _4679.x : _14119.x, _17207.y ? _4679.y : _14119.y);
                        _17108 = _14117;
                        _17097 = _14116;
                        _17093 = _4732 ? _4690 : _14115;
                    }
                    else
                    {
                        bool _4741 = _17052 < _17060;
                        bool2 _17203 = _4741.xx;
                        _17199 = _4741 ? _17052 : _17060;
                        _17152 = _14125;
                        _17119 = _14119;
                        _17108 = float2(_17203.x ? _4685.x : _14117.x, _17203.y ? _4685.y : _14117.y);
                        _17097 = int2(_17203.x ? _4679.x : _14116.x, _17203.y ? _4679.y : _14116.y);
                        _17093 = _14115;
                    }
                    _17198 = _17199;
                    _17151 = _17152;
                    _17118 = _17119;
                    _17107 = _17108;
                    _17096 = _17097;
                    _17092 = _17093;
                }
                bool _4753 = _14115 < 0.0f;
                bool2 _17213 = _4753.xx;
                int2 _17216 = int2(_17213.x ? _14116.x : _14119.x, _17213.y ? _14116.y : _14119.y);
                _16517 = float3(1.0f, _4644, float(any(bool2(_17216.x != _4572.x, _17216.y != _4572.y))));
                _14350 = _17216;
                _14269 = _4753 ? false : true;
                _14127 = float2(_17213.x ? _14117.x : _14125.x, _17213.y ? _14117.y : _14125.y);
            }
            else
            {
                _16517 = _13808;
                _14350 = _4572;
                _14269 = false;
                _14127 = _6777;
            }
            _16516 = _16517;
            _14349 = _14350;
            _14268 = _14269;
            _14126 = _14127;
        }
        else
        {
            _16516 = 0.0f.xxx;
            _14349 = _4572;
            _14268 = false;
            _14126 = _6777;
        }
        float2 _14128;
        if (_6799)
        {
            float2 _7224 = clamp((((_14105 + (_14126 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7227 = tan(_7224.x);
            _14128 = (float2(_7227 / cbFI_DeviceToViewDepth.z, (tan(_7224.y) * sqrt(1.0f + (_7227 * _7227))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14128 = _14105 + (_14126 * cbFI_Timestep);
        }
        float _4776 = cbFI_Timestep - 1.0f;
        float2 _14130;
        if (_6799)
        {
            float2 _7295 = clamp((((_14105 + (_14126 * _4776)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7298 = tan(_7295.x);
            _14130 = (float2(_7298 / cbFI_DeviceToViewDepth.z, (tan(_7295.y) * sqrt(1.0f + (_7298 * _7298))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14130 = _14105 + (_14126 * _4776);
        }
        float _4781 = -cbFI_Timestep;
        float2 _14131;
        if (_6799)
        {
            float2 _7366 = clamp((((_14105 + (_6771 * _4781)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7369 = tan(_7366.x);
            _14131 = (float2(_7369 / cbFI_DeviceToViewDepth.z, (tan(_7366.y) * sqrt(1.0f + (_7369 * _7369))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14131 = _14105 + (_6771 * _4781);
        }
        float _4786 = 1.0f - cbFI_Timestep;
        float2 _14132;
        if (_6799)
        {
            float2 _7437 = clamp((((_14105 + (_6771 * _4786)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7440 = tan(_7437.x);
            _14132 = (float2(_7440 / cbFI_DeviceToViewDepth.z, (tan(_7437.y) * sqrt(1.0f + (_7440 * _7440))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14132 = _14105 + (_6771 * _4786);
        }
        float4 _7475 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14128, 0.0f);
        float3 _7476 = _7475.xyz;
        float4 _7483 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14130, 0.0f);
        float3 _7484 = _7483.xyz;
        float4 _7491 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14131, 0.0f);
        float3 _7492 = _7491.xyz;
        float4 _7499 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14132, 0.0f);
        float3 _7500 = _7499.xyz;
        float4 _7514 = exp(_6765 - max(max(max(_6765.x, _6765.y), _6765.z), _6765.w).xxxx);
        float4 _7521 = _7514 / (dot(_7514, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4802 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14339;
        float _15647;
        if (_4802)
        {
            float2 _4808 = 0.5f.xx / _4563;
            float _4811 = _4808.x;
            float _4812 = -_4811;
            float _4814 = _4808.y;
            float _4815 = -_4814;
            float2 _4817 = _4561 + float2(_4812, _4815);
            float2 _4819 = float2(cbFI_DisplaySize);
            bool _14149;
            do
            {
                bool _7601 = all(bool2(_4817.x > 0.0f.xx.x, _4817.y > 0.0f.xx.y));
                bool _7607;
                if (_7601)
                {
                    _7607 = all(bool2(_4817.x < 1.0f.xx.x, _4817.y < 1.0f.xx.y));
                }
                else
                {
                    _7607 = _7601;
                }
                if (!_7607)
                {
                    _14149 = false;
                    break;
                }
                uint _7614_dummy_parameter;
                float4x4 _14147;
                do
                {
                    float4x4 _7628;
                    bool _14146;
                    do
                    {
                        _7628 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14146 = false;
                            break;
                        }
                        uint _7662 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7662 + 32u) * 4 + 0) != 1u)
                        {
                            _14146 = false;
                            break;
                        }
                        uint _14143;
                        _14143 = 0u;
                        for (; _14143 < 4u; _14143++)
                        {
                            for (uint _14144 = 0u; _14144 < 4u; )
                            {
                                _7628[_14143][_14144] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7662 + (_14143 * 4u)) + _14144) * 4 + 0));
                                _14144++;
                                continue;
                            }
                        }
                        _14146 = true;
                        break;
                    } while(false);
                    if (_14146)
                    {
                        _14147 = _7628;
                        break;
                    }
                    _14147 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14148;
                do
                {
                    float _7739 = _4817.x;
                    float _7742 = 1.0f - _4817.y;
                    float4 _7753 = mul(float4((float2(_7739, _7742) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4817 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7614_dummy_parameter))))), 0)).x, 1.0f), _14147);
                    float _7755 = _7753.w;
                    if (!(_7755 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14148 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7768 = ((_7753.xy / _7755.xx) + 1.0f.xx) * 0.5f;
                    _14148 = float2(_7768.x - _7739, _7742 - _7768.y);
                    break;
                } while(false);
                float2 _7565 = abs(_14148);
                if (any(bool2(_7565.x > 100000.0f.xx.x, _7565.y > 100000.0f.xx.y)))
                {
                    _14149 = false;
                    break;
                }
                float _7573 = length(_14148 * _4819);
                uint _7788_dummy_parameter;
                bool _7587 = _7573 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7594;
                if (_7587)
                {
                    _7594 = length((r_motion_tp1.Load(int3(int2(floor(_4817 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7788_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _7573);
                }
                else
                {
                    _7594 = _7587;
                }
                _14149 = _7594;
                break;
            } while(false);
            float2 _4829 = _4561 + float2(_4811, _4815);
            bool _14156;
            do
            {
                bool _7874 = all(bool2(_4829.x > 0.0f.xx.x, _4829.y > 0.0f.xx.y));
                bool _7880;
                if (_7874)
                {
                    _7880 = all(bool2(_4829.x < 1.0f.xx.x, _4829.y < 1.0f.xx.y));
                }
                else
                {
                    _7880 = _7874;
                }
                if (!_7880)
                {
                    _14156 = false;
                    break;
                }
                uint _7887_dummy_parameter;
                float4x4 _14154;
                do
                {
                    float4x4 _7901;
                    bool _14153;
                    do
                    {
                        _7901 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14153 = false;
                            break;
                        }
                        uint _7935 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7935 + 32u) * 4 + 0) != 1u)
                        {
                            _14153 = false;
                            break;
                        }
                        uint _14150;
                        _14150 = 0u;
                        for (; _14150 < 4u; _14150++)
                        {
                            for (uint _14151 = 0u; _14151 < 4u; )
                            {
                                _7901[_14150][_14151] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7935 + (_14150 * 4u)) + _14151) * 4 + 0));
                                _14151++;
                                continue;
                            }
                        }
                        _14153 = true;
                        break;
                    } while(false);
                    if (_14153)
                    {
                        _14154 = _7901;
                        break;
                    }
                    _14154 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14155;
                do
                {
                    float _8012 = _4829.x;
                    float _8015 = 1.0f - _4829.y;
                    float4 _8026 = mul(float4((float2(_8012, _8015) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7887_dummy_parameter))))), 0)).x, 1.0f), _14154);
                    float _8028 = _8026.w;
                    if (!(_8028 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14155 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8041 = ((_8026.xy / _8028.xx) + 1.0f.xx) * 0.5f;
                    _14155 = float2(_8041.x - _8012, _8015 - _8041.y);
                    break;
                } while(false);
                float2 _7838 = abs(_14155);
                if (any(bool2(_7838.x > 100000.0f.xx.x, _7838.y > 100000.0f.xx.y)))
                {
                    _14156 = false;
                    break;
                }
                float _7846 = length(_14155 * _4819);
                uint _8061_dummy_parameter;
                bool _7860 = _7846 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7867;
                if (_7860)
                {
                    _7867 = length((r_motion_tp1.Load(int3(int2(floor(_4829 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8061_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _7846);
                }
                else
                {
                    _7867 = _7860;
                }
                _14156 = _7867;
                break;
            } while(false);
            float2 _4842 = _4561 + float2(_4812, _4814);
            bool _14163;
            do
            {
                bool _8147 = all(bool2(_4842.x > 0.0f.xx.x, _4842.y > 0.0f.xx.y));
                bool _8153;
                if (_8147)
                {
                    _8153 = all(bool2(_4842.x < 1.0f.xx.x, _4842.y < 1.0f.xx.y));
                }
                else
                {
                    _8153 = _8147;
                }
                if (!_8153)
                {
                    _14163 = false;
                    break;
                }
                uint _8160_dummy_parameter;
                float4x4 _14161;
                do
                {
                    float4x4 _8174;
                    bool _14160;
                    do
                    {
                        _8174 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14160 = false;
                            break;
                        }
                        uint _8208 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8208 + 32u) * 4 + 0) != 1u)
                        {
                            _14160 = false;
                            break;
                        }
                        uint _14157;
                        _14157 = 0u;
                        for (; _14157 < 4u; _14157++)
                        {
                            for (uint _14158 = 0u; _14158 < 4u; )
                            {
                                _8174[_14157][_14158] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8208 + (_14157 * 4u)) + _14158) * 4 + 0));
                                _14158++;
                                continue;
                            }
                        }
                        _14160 = true;
                        break;
                    } while(false);
                    if (_14160)
                    {
                        _14161 = _8174;
                        break;
                    }
                    _14161 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14162;
                do
                {
                    float _8285 = _4842.x;
                    float _8288 = 1.0f - _4842.y;
                    float4 _8299 = mul(float4((float2(_8285, _8288) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4842 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8160_dummy_parameter))))), 0)).x, 1.0f), _14161);
                    float _8301 = _8299.w;
                    if (!(_8301 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14162 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8314 = ((_8299.xy / _8301.xx) + 1.0f.xx) * 0.5f;
                    _14162 = float2(_8314.x - _8285, _8288 - _8314.y);
                    break;
                } while(false);
                float2 _8111 = abs(_14162);
                if (any(bool2(_8111.x > 100000.0f.xx.x, _8111.y > 100000.0f.xx.y)))
                {
                    _14163 = false;
                    break;
                }
                float _8119 = length(_14162 * _4819);
                uint _8334_dummy_parameter;
                bool _8133 = _8119 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8140;
                if (_8133)
                {
                    _8140 = length((r_motion_tp1.Load(int3(int2(floor(_4842 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8334_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _8119);
                }
                else
                {
                    _8140 = _8133;
                }
                _14163 = _8140;
                break;
            } while(false);
            float2 _4854 = _4561 + _4808;
            bool _14170;
            do
            {
                bool _8420 = all(bool2(_4854.x > 0.0f.xx.x, _4854.y > 0.0f.xx.y));
                bool _8426;
                if (_8420)
                {
                    _8426 = all(bool2(_4854.x < 1.0f.xx.x, _4854.y < 1.0f.xx.y));
                }
                else
                {
                    _8426 = _8420;
                }
                if (!_8426)
                {
                    _14170 = false;
                    break;
                }
                uint _8433_dummy_parameter;
                float4x4 _14168;
                do
                {
                    float4x4 _8447;
                    bool _14167;
                    do
                    {
                        _8447 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14167 = false;
                            break;
                        }
                        uint _8481 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8481 + 32u) * 4 + 0) != 1u)
                        {
                            _14167 = false;
                            break;
                        }
                        uint _14164;
                        _14164 = 0u;
                        for (; _14164 < 4u; _14164++)
                        {
                            for (uint _14165 = 0u; _14165 < 4u; )
                            {
                                _8447[_14164][_14165] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8481 + (_14164 * 4u)) + _14165) * 4 + 0));
                                _14165++;
                                continue;
                            }
                        }
                        _14167 = true;
                        break;
                    } while(false);
                    if (_14167)
                    {
                        _14168 = _8447;
                        break;
                    }
                    _14168 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14169;
                do
                {
                    float _8558 = _4854.x;
                    float _8561 = 1.0f - _4854.y;
                    float4 _8572 = mul(float4((float2(_8558, _8561) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4854 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8433_dummy_parameter))))), 0)).x, 1.0f), _14168);
                    float _8574 = _8572.w;
                    if (!(_8574 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14169 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8587 = ((_8572.xy / _8574.xx) + 1.0f.xx) * 0.5f;
                    _14169 = float2(_8587.x - _8558, _8561 - _8587.y);
                    break;
                } while(false);
                float2 _8384 = abs(_14169);
                if (any(bool2(_8384.x > 100000.0f.xx.x, _8384.y > 100000.0f.xx.y)))
                {
                    _14170 = false;
                    break;
                }
                float _8392 = length(_14169 * _4819);
                uint _8607_dummy_parameter;
                bool _8406 = _8392 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8413;
                if (_8406)
                {
                    _8413 = length((r_motion_tp1.Load(int3(int2(floor(_4854 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8607_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _8392);
                }
                else
                {
                    _8413 = _8406;
                }
                _14170 = _8413;
                break;
            } while(false);
            float _4860 = 0.25f * (((float(_14149) + float(_14156)) + float(_14163)) + float(_14170));
            float4 _14340;
            if (_4860 < 1.0f)
            {
                bool _14177;
                do
                {
                    bool _8693 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
                    bool _8699;
                    if (_8693)
                    {
                        _8699 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8699 = _8693;
                    }
                    if (!_8699)
                    {
                        _14177 = false;
                        break;
                    }
                    uint _8706_dummy_parameter;
                    float4x4 _14175;
                    do
                    {
                        float4x4 _8720;
                        bool _14174;
                        do
                        {
                            _8720 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14174 = false;
                                break;
                            }
                            uint _8754 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8754 + 32u) * 4 + 0) != 1u)
                            {
                                _14174 = false;
                                break;
                            }
                            uint _14171;
                            _14171 = 0u;
                            for (; _14171 < 4u; _14171++)
                            {
                                for (uint _14172 = 0u; _14172 < 4u; )
                                {
                                    _8720[_14171][_14172] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8754 + (_14171 * 4u)) + _14172) * 4 + 0));
                                    _14172++;
                                    continue;
                                }
                            }
                            _14174 = true;
                            break;
                        } while(false);
                        if (_14174)
                        {
                            _14175 = _8720;
                            break;
                        }
                        _14175 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14176;
                    do
                    {
                        float _8834 = 1.0f - _14128.y;
                        float4 _8845 = mul(float4((float2(_14128.x, _8834) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8706_dummy_parameter))))), 0)).x, 1.0f), _14175);
                        float _8847 = _8845.w;
                        if (!(_8847 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14176 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8860 = ((_8845.xy / _8847.xx) + 1.0f.xx) * 0.5f;
                        _14176 = float2(_8860.x - _14128.x, _8834 - _8860.y);
                        break;
                    } while(false);
                    float2 _8657 = abs(_14176);
                    if (any(bool2(_8657.x > 100000.0f.xx.x, _8657.y > 100000.0f.xx.y)))
                    {
                        _14177 = false;
                        break;
                    }
                    float _8665 = length(_14176 * _4819);
                    uint _8880_dummy_parameter;
                    bool _8679 = _8665 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8686;
                    if (_8679)
                    {
                        _8686 = length((r_motion_tp1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8880_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _8665);
                    }
                    else
                    {
                        _8686 = _8679;
                    }
                    _14177 = _8686;
                    break;
                } while(false);
                bool _14184;
                do
                {
                    bool _8966 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
                    bool _8972;
                    if (_8966)
                    {
                        _8972 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8972 = _8966;
                    }
                    if (!_8972)
                    {
                        _14184 = false;
                        break;
                    }
                    uint _8979_dummy_parameter;
                    float4x4 _14182;
                    do
                    {
                        float4x4 _8993;
                        bool _14181;
                        do
                        {
                            _8993 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14181 = false;
                                break;
                            }
                            uint _9027 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9027 + 32u) * 4 + 0) != 1u)
                            {
                                _14181 = false;
                                break;
                            }
                            uint _14178;
                            _14178 = 0u;
                            for (; _14178 < 4u; _14178++)
                            {
                                for (uint _14179 = 0u; _14179 < 4u; )
                                {
                                    _8993[_14178][_14179] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9027 + (_14178 * 4u)) + _14179) * 4 + 0));
                                    _14179++;
                                    continue;
                                }
                            }
                            _14181 = true;
                            break;
                        } while(false);
                        if (_14181)
                        {
                            _14182 = _8993;
                            break;
                        }
                        _14182 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14183;
                    do
                    {
                        float _9107 = 1.0f - _14130.y;
                        float4 _9118 = mul(float4((float2(_14130.x, _9107) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8979_dummy_parameter))))), 0)).x, 1.0f), _14182);
                        float _9120 = _9118.w;
                        if (!(_9120 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14183 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9133 = ((_9118.xy / _9120.xx) + 1.0f.xx) * 0.5f;
                        _14183 = float2(_9133.x - _14130.x, _9107 - _9133.y);
                        break;
                    } while(false);
                    float2 _8930 = abs(_14183);
                    if (any(bool2(_8930.x > 100000.0f.xx.x, _8930.y > 100000.0f.xx.y)))
                    {
                        _14184 = false;
                        break;
                    }
                    float _8938 = length(_14183 * _4819);
                    uint _9153_dummy_parameter;
                    bool _8952 = _8938 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8959;
                    if (_8952)
                    {
                        _8959 = length((r_motion_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9153_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _8938);
                    }
                    else
                    {
                        _8959 = _8952;
                    }
                    _14184 = _8959;
                    break;
                } while(false);
                bool _14191;
                do
                {
                    bool _9239 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                    bool _9245;
                    if (_9239)
                    {
                        _9245 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9245 = _9239;
                    }
                    if (!_9245)
                    {
                        _14191 = false;
                        break;
                    }
                    uint _9252_dummy_parameter;
                    float4x4 _14189;
                    do
                    {
                        float4x4 _9266;
                        bool _14188;
                        do
                        {
                            _9266 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14188 = false;
                                break;
                            }
                            uint _9300 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9300 + 32u) * 4 + 0) != 1u)
                            {
                                _14188 = false;
                                break;
                            }
                            uint _14185;
                            _14185 = 0u;
                            for (; _14185 < 4u; _14185++)
                            {
                                for (uint _14186 = 0u; _14186 < 4u; )
                                {
                                    _9266[_14185][_14186] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9300 + (_14185 * 4u)) + _14186) * 4 + 0));
                                    _14186++;
                                    continue;
                                }
                            }
                            _14188 = true;
                            break;
                        } while(false);
                        if (_14188)
                        {
                            _14189 = _9266;
                            break;
                        }
                        _14189 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14190;
                    do
                    {
                        float _9380 = 1.0f - _14131.y;
                        float4 _9391 = mul(float4((float2(_14131.x, _9380) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9252_dummy_parameter))))), 0)).x, 1.0f), _14189);
                        float _9393 = _9391.w;
                        if (!(_9393 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14190 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9406 = ((_9391.xy / _9393.xx) + 1.0f.xx) * 0.5f;
                        _14190 = float2(_9406.x - _14131.x, _9380 - _9406.y);
                        break;
                    } while(false);
                    float2 _9203 = abs(_14190);
                    if (any(bool2(_9203.x > 100000.0f.xx.x, _9203.y > 100000.0f.xx.y)))
                    {
                        _14191 = false;
                        break;
                    }
                    float _9211 = length(_14190 * _4819);
                    uint _9426_dummy_parameter;
                    bool _9225 = _9211 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9232;
                    if (_9225)
                    {
                        _9232 = length((r_motion_tp1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9426_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _9211);
                    }
                    else
                    {
                        _9232 = _9225;
                    }
                    _14191 = _9232;
                    break;
                } while(false);
                bool _14198;
                do
                {
                    bool _9512 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                    bool _9518;
                    if (_9512)
                    {
                        _9518 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9518 = _9512;
                    }
                    if (!_9518)
                    {
                        _14198 = false;
                        break;
                    }
                    uint _9525_dummy_parameter;
                    float4x4 _14196;
                    do
                    {
                        float4x4 _9539;
                        bool _14195;
                        do
                        {
                            _9539 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14195 = false;
                                break;
                            }
                            uint _9573 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9573 + 32u) * 4 + 0) != 1u)
                            {
                                _14195 = false;
                                break;
                            }
                            uint _14192;
                            _14192 = 0u;
                            for (; _14192 < 4u; _14192++)
                            {
                                for (uint _14193 = 0u; _14193 < 4u; )
                                {
                                    _9539[_14192][_14193] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9573 + (_14192 * 4u)) + _14193) * 4 + 0));
                                    _14193++;
                                    continue;
                                }
                            }
                            _14195 = true;
                            break;
                        } while(false);
                        if (_14195)
                        {
                            _14196 = _9539;
                            break;
                        }
                        _14196 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14197;
                    do
                    {
                        float _9653 = 1.0f - _14132.y;
                        float4 _9664 = mul(float4((float2(_14132.x, _9653) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9525_dummy_parameter))))), 0)).x, 1.0f), _14196);
                        float _9666 = _9664.w;
                        if (!(_9666 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14197 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9679 = ((_9664.xy / _9666.xx) + 1.0f.xx) * 0.5f;
                        _14197 = float2(_9679.x - _14132.x, _9653 - _9679.y);
                        break;
                    } while(false);
                    float2 _9476 = abs(_14197);
                    if (any(bool2(_9476.x > 100000.0f.xx.x, _9476.y > 100000.0f.xx.y)))
                    {
                        _14198 = false;
                        break;
                    }
                    float _9484 = length(_14197 * _4819);
                    uint _9699_dummy_parameter;
                    bool _9498 = _9484 > ((8.0f * _4819.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9505;
                    if (_9498)
                    {
                        _9505 = length((r_motion_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9699_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4819) < (0.20000000298023223876953125f * _9484);
                    }
                    else
                    {
                        _9505 = _9498;
                    }
                    _14198 = _9505;
                    break;
                } while(false);
                float4 _4887 = _7521 * float4(_14177 ? 0.0f : 1.0f, _14184 ? 0.0f : 1.0f, _14191 ? 0.0f : 1.0f, _14198 ? 0.0f : 1.0f);
                float _4889 = dot(_4887, 1.0f.xxxx);
                float4 _14341;
                if (_4889 > 0.001000000047497451305389404296875f)
                {
                    _14341 = _4887 / _4889.xxxx;
                }
                else
                {
                    _14341 = _7521;
                }
                _14340 = _14341;
            }
            else
            {
                _14340 = _7521;
            }
            _15647 = _4860;
            _14339 = _14340;
        }
        else
        {
            _15647 = 0.0f;
            _14339 = _7521;
        }
        bool _4906 = _4598 && (!_14268);
        bool _4915;
        if (_4906)
        {
            _4915 = (_14339.z + _14339.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4915 = _4906;
        }
        bool _4926;
        if (_4915)
        {
            _4926 = length((_14131 - _14128) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4926 = _4915;
        }
        bool _14428;
        if (_4926)
        {
            uint4 _9728 = r_warped_motion_qdata_tp1.Load(int3(_14349, 0));
            uint _9729 = _9728.x;
            bool _14431;
            if (_9729 != 0u)
            {
                float _14417;
                if (_9729 == 0u)
                {
                    _14417 = -1.0f;
                }
                else
                {
                    _14417 = float((_9729 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4936 = _14417 - 0.12000000476837158203125f;
                bool _9748 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                bool _9754;
                if (_9748)
                {
                    _9754 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                }
                else
                {
                    _9754 = _9748;
                }
                bool _4946;
                if (_9754)
                {
                    uint _9761_dummy_parameter;
                    _4946 = (log(((r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9761_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4936;
                }
                else
                {
                    _4946 = _9754;
                }
                bool _4960;
                if (!_4946)
                {
                    bool _9791 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                    bool _9797;
                    if (_9791)
                    {
                        _9797 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9797 = _9791;
                    }
                    bool _4958;
                    if (_9797)
                    {
                        uint _9804_dummy_parameter;
                        _4958 = (log(((r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9804_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4936;
                    }
                    else
                    {
                        _4958 = _9797;
                    }
                    _4960 = _4958;
                }
                else
                {
                    _4960 = _4946;
                }
                _14431 = _4960;
            }
            else
            {
                _14431 = false;
            }
            _14428 = _14431;
        }
        else
        {
            _14428 = false;
        }
        bool _4965 = _14268 || _14428;
        bool _4970;
        if (_4965)
        {
            bool _9834 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
            bool _9840;
            if (_9834)
            {
                _9840 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
            }
            else
            {
                _9840 = _9834;
            }
            _4970 = _9840;
        }
        else
        {
            _4970 = _4965;
        }
        bool _4975;
        if (_4970)
        {
            bool _9845 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
            bool _9851;
            if (_9845)
            {
                _9851 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
            }
            else
            {
                _9851 = _9845;
            }
            _4975 = _9851;
        }
        else
        {
            _4975 = _4970;
        }
        float4 _14551;
        if (_4975)
        {
            float _4981 = _14339.x + _14339.y;
            float _4986 = _14339.z + _14339.w;
            float _14446;
            if (_4981 > 0.001000000047497451305389404296875f)
            {
                _14446 = _14339.x / _4981;
            }
            else
            {
                _14446 = _4786;
            }
            _14551 = float4(_14339.x + (_4986 * _14446), _14339.y + (_4986 * (1.0f - _14446)), 0.0f, 0.0f);
        }
        else
        {
            _14551 = _14339;
        }
        bool _9879 = (cbFI_pad0 & 1024u) != 0u;
        bool _9855 = !_9879;
        bool _9856 = !_9855;
        bool _9873;
        if (_9856)
        {
            _9873 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14349.y * cbFI_MvDepthLaneSize.x) + _14349.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9873 = _9855;
        }
        bool _9905;
        if (_9856)
        {
            _9905 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4577.y * cbFI_FlowLaneSize.x) + _4577.x)) * 4 + 0) != 0u;
        }
        else
        {
            _9905 = _9855;
        }
        float _5021 = float(_9905);
        bool _14572;
        float4 _14611;
        float3 _16280;
        if (_9879)
        {
            bool _5031;
            if (_9873)
            {
                _5031 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
            }
            else
            {
                _5031 = _9873;
            }
            bool _5037;
            if (_5031)
            {
                _5037 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
            }
            else
            {
                _5037 = _5031;
            }
            bool _5044;
            if (_9873)
            {
                _5044 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
            }
            else
            {
                _5044 = _9873;
            }
            bool _5050;
            if (_5044)
            {
                _5050 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
            }
            else
            {
                _5050 = _5044;
            }
            bool _5057;
            if (_9905)
            {
                _5057 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
            }
            else
            {
                _5057 = _9905;
            }
            bool _5063;
            if (_5057)
            {
                _5063 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
            }
            else
            {
                _5063 = _5057;
            }
            bool _5070;
            if (_9905)
            {
                _5070 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
            }
            else
            {
                _5070 = _9905;
            }
            bool _5076;
            if (_5070)
            {
                _5076 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
            }
            else
            {
                _5076 = _5070;
            }
            bool _5078 = !_9873;
            if (_5078)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9947;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9947);
                }
            }
            bool _5083 = !_9905;
            if (_5083)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9957;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9957);
                }
            }
            if (_9873 && _5083)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9967;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9967);
                }
            }
            if (_5078 && _9905)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9977;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _9977);
                }
            }
            float _5102 = float(_5037);
            float _5104 = float(_5050);
            bool _5107 = _5063 && _5076;
            float _14480;
            if (_5107)
            {
                _14480 = 1.0f;
            }
            else
            {
                _14480 = (_5063 || _5076) ? 0.5f : 0.0f;
            }
            bool _14495;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5037)) && (!_5050))
            {
                bool _5137;
                if (_5107)
                {
                    float _14488;
                    do
                    {
                        bool _10061 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                        bool _10067;
                        if (_10061)
                        {
                            _10067 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10067 = _10061;
                        }
                        bool _9998 = !_10067;
                        bool _10005;
                        if (!_9998)
                        {
                            bool _10072 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                            bool _10078;
                            if (_10072)
                            {
                                _10078 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10078 = _10072;
                            }
                            _10005 = !_10078;
                        }
                        else
                        {
                            _10005 = _9998;
                        }
                        if (_10005)
                        {
                            _14488 = 0.0f;
                            break;
                        }
                        uint _10085_dummy_parameter;
                        uint _10101_dummy_parameter;
                        float4x4 _14487;
                        do
                        {
                            float4x4 _10115;
                            bool _14486;
                            do
                            {
                                _10115 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14486 = false;
                                    break;
                                }
                                uint _10149 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10149 + 32u) * 4 + 0) != 1u)
                                {
                                    _14486 = false;
                                    break;
                                }
                                uint _14483;
                                _14483 = 0u;
                                for (; _14483 < 4u; _14483++)
                                {
                                    for (uint _14484 = 0u; _14484 < 4u; )
                                    {
                                        _10115[_14483][_14484] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10149 + 16u) + (_14483 * 4u)) + _14484) * 4 + 0));
                                        _14484++;
                                        continue;
                                    }
                                }
                                _14486 = true;
                                break;
                            } while(false);
                            if (_14486)
                            {
                                _14487 = _10115;
                                break;
                            }
                            _14487 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _10026 = mul(float4((float2(_14131.x, 1.0f - _14131.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10085_dummy_parameter))))), 0)).x, 1.0f), _14487);
                        float _10028 = _10026.w;
                        if (abs(_10028) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14488 = 0.0f;
                            break;
                        }
                        float _10039 = abs(cbFI_DeviceToViewDepth.y / ((_10026.z / _10028) - cbFI_DeviceToViewDepth.x));
                        float _10042 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10101_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14488 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10039 - _10042) / max(max(_10039, _10042), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5137 = _14488 >= 0.5f;
                }
                else
                {
                    _5137 = _5107;
                }
                bool _5145;
                if (_5137)
                {
                    _5145 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5145 = _5137;
                }
                bool _14496;
                if (_5145)
                {
                    uint _10253_dummy_parameter;
                    float4x4 _14493;
                    do
                    {
                        float4x4 _10267;
                        bool _14492;
                        do
                        {
                            _10267 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14492 = false;
                                break;
                            }
                            uint _10301 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10301 + 32u) * 4 + 0) != 1u)
                            {
                                _14492 = false;
                                break;
                            }
                            uint _14489;
                            _14489 = 0u;
                            for (; _14489 < 4u; _14489++)
                            {
                                for (uint _14490 = 0u; _14490 < 4u; )
                                {
                                    _10267[_14489][_14490] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10301 + 16u) + (_14489 * 4u)) + _14490) * 4 + 0));
                                    _14490++;
                                    continue;
                                }
                            }
                            _14492 = true;
                            break;
                        } while(false);
                        if (_14492)
                        {
                            _14493 = _10267;
                            break;
                        }
                        _14493 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14494;
                    do
                    {
                        float _10381 = 1.0f - _14131.y;
                        float4 _10392 = mul(float4((float2(_14131.x, _10381) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10253_dummy_parameter))))), 0)).x, 1.0f), _14493);
                        float _10394 = _10392.w;
                        if (!(_10394 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14494 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10407 = ((_10392.xy / _10394.xx) + 1.0f.xx) * 0.5f;
                        _14494 = float2(_10407.x - _14131.x, _10381 - _10407.y);
                        break;
                    } while(false);
                    float2 _5158 = float2(cbFI_DisplaySize);
                    _14496 = length(((_14131 + _14494) - _14132) * _5158) <= ((0.100000001490116119384765625f * length(_14494 * _5158)) + 8.0f);
                }
                else
                {
                    _14496 = _5137;
                }
                _14495 = _14496;
            }
            else
            {
                _14495 = true;
            }
            bool _5172 = !_14495;
            bool _17217 = _5172 ? false : _5076;
            bool _17218 = _5172 ? false : _5063;
            bool _14573;
            float4 _14612;
            if (!(((_5037 && _5050) && _17218) && _17217))
            {
                float4 _5194 = _14551 * float4(_5102, _5104, float(_17218), float(_17217));
                float _5196 = dot(_5194, 1.0f.xxxx);
                bool _5199 = !(_5196 > 0.0f);
                float4 _14613;
                if (!_5199)
                {
                    _14613 = _5194 / _5196.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10429;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10429);
                    }
                    _14613 = 0.0f.xxxx;
                }
                _14612 = _14613;
                _14573 = _5199;
            }
            else
            {
                _14612 = _14551;
                _14573 = false;
            }
            _16280 = float3(_5102, _5104, _14480);
            _14611 = _14612;
            _14572 = _14573;
        }
        else
        {
            _16280 = float3(float(_9873), _5021, 0.0f);
            _14611 = _14551;
            _14572 = false;
        }
        bool _5217 = !_14572;
        float4 _14704;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5217)
        {
            float _5224 = _14611.x + _14611.y;
            float4 _14705;
            if (_5224 > 0.001000000047497451305389404296875f)
            {
                _14705 = float4(_14611.x / _5224, _14611.y / _5224, 0.0f, 0.0f);
            }
            else
            {
                _14705 = float4(_4786, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14704 = _14705;
        }
        else
        {
            _14704 = _14611;
        }
        float4 _14881;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5217) && _9873)
        {
            float _14678;
            do
            {
                uint4 _10569 = r_warped_motion_qdata_tp1.Load(int3(_14349, 0));
                uint _10570 = _10569.x;
                if (_10570 != 0u)
                {
                    float _14677;
                    if (_10570 == 0u)
                    {
                        _14677 = -1.0f;
                    }
                    else
                    {
                        _14677 = float((_10570 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14678 = _14677;
                    break;
                }
                int _14660;
                uint _14661;
                _14661 = _10570;
                _14660 = -1;
                uint _14676;
                for (; _14660 <= 1; _14661 = _14676, _14660++)
                {
                    _14676 = _14661;
                    for (int _14674 = -1; _14674 <= 1; )
                    {
                        _14676 = max(_14676, r_warped_motion_qdata_tp1.Load(int3(clamp(_14349 + int2(_14674, _14660), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14674++;
                        continue;
                    }
                }
                if (_14661 != 0u)
                {
                    float _14673;
                    if (_14661 == 0u)
                    {
                        _14673 = -1.0f;
                    }
                    else
                    {
                        _14673 = float((_14661 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14678 = _14673;
                    break;
                }
                uint _14663;
                _14663 = 4294967295u;
                uint _17188;
                for (int _14662 = 0; _14662 < 8; _14663 = _17188, _14662++)
                {
                    int _14666 = 0;
                    for (;;)
                    {
                        if (_14666 < 5)
                        {
                            int2 _10520 = _14349 + (_1192[_14662] * _1201[_14666].xx);
                            bool _10523 = any(bool2(_10520.x < int2(0, 0).x, _10520.y < int2(0, 0).y));
                            bool _10531;
                            if (!_10523)
                            {
                                _10531 = any(bool2(_10520.x >= cbFI_MvDepthLaneSize.x, _10520.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10531 = _10523;
                            }
                            if (_10531)
                            {
                                _17188 = _14663;
                                break;
                            }
                            uint4 _10609 = r_warped_motion_qdata_tp1.Load(int3(_10520, 0));
                            uint _10610 = _10609.x;
                            if (_10610 != 0u)
                            {
                                _17188 = min(_14663, _10610);
                                break;
                            }
                            _14666++;
                            continue;
                        }
                        else
                        {
                            _17188 = _14663;
                            break;
                        }
                    }
                }
                float _14665;
                if (_14663 == 4294967295u)
                {
                    _14665 = -1.0f;
                }
                else
                {
                    float _14664;
                    if (_14663 == 0u)
                    {
                        _14664 = -1.0f;
                    }
                    else
                    {
                        _14664 = float((_14663 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14665 = _14664;
                }
                _14678 = _14665;
                break;
            } while(false);
            float _5260 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5263 = r_warped_motion_qdata_tp1.Load(int3(_14349, 0)).x == 0u;
            bool _5269;
            if (_5263)
            {
                bool _10635 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
                bool _10641;
                if (_10635)
                {
                    _10641 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
                }
                else
                {
                    _10641 = _10635;
                }
                _5269 = _10641;
            }
            else
            {
                _5269 = _5263;
            }
            bool _5274;
            if (_5269)
            {
                bool _10646 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
                bool _10652;
                if (_10646)
                {
                    _10652 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
                }
                else
                {
                    _10652 = _10646;
                }
                _5274 = _10652;
            }
            else
            {
                _5274 = _5269;
            }
            bool _14690;
            float4 _14699;
            if (_5274)
            {
                uint _10659_dummy_parameter;
                float _10683 = log(((r_depth_tm1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10659_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _10691_dummy_parameter;
                float _10715 = log(((r_depth_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10691_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _5285 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5292;
                if (_5285)
                {
                    _5292 = _10715 > (_10683 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5292 = _5285;
                }
                bool _14695;
                float4 _14717;
                if (_5292)
                {
                    _14717 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14695 = true;
                }
                else
                {
                    bool _5298 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5305;
                    if (_5298)
                    {
                        _5305 = _10683 > (_10715 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5305 = _5298;
                    }
                    bool4 _17219 = _5305.xxxx;
                    _14717 = float4(_17219.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14704.x, _17219.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14704.y, _17219.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14704.z, _17219.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14704.w);
                    _14695 = _5305 ? true : false;
                }
                _14699 = _14717;
                _14690 = _14695;
            }
            else
            {
                _14699 = _14704;
                _14690 = false;
            }
            float4 _14772;
            if (_14690)
            {
                _14772 = 1.0f.xxxx;
            }
            else
            {
                bool _5316 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5322;
                if (_5316)
                {
                    _5322 = _14699.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5322 = _5316;
                }
                bool _5327;
                if (_5322)
                {
                    bool _10721 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
                    bool _10727;
                    if (_10721)
                    {
                        _10727 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10727 = _10721;
                    }
                    _5327 = _10727;
                }
                else
                {
                    _5327 = _5322;
                }
                float4 _14773;
                if (_5327)
                {
                    float _14726;
                    if (_14678 >= 0.0f)
                    {
                        _14726 = _14678 - _5260;
                    }
                    else
                    {
                        float _14722;
                        _14722 = 2.0f;
                        float _10784;
                        for (int _14721 = 0; _14721 < 24; _14722 = _10784, _14721++)
                        {
                            float _10748 = float(_14721 & 7) * 0.785398185253143310546875f;
                            int _10750 = _14721 >> 3;
                            int _14723;
                            if (_10750 == 0)
                            {
                                _14723 = 16;
                            }
                            else
                            {
                                _14723 = (_10750 == 1) ? 48 : 96;
                            }
                            uint _10816_dummy_parameter;
                            _10784 = min(_14722, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14130 + ((cbFI_MvDepthLaneSizeRcp * float(_14723)) * float2(cos(_10748), sin(_10748))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10816_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14726 = _14722;
                    }
                    uint _10848_dummy_parameter;
                    float4 _14774;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10848_dummy_parameter))))), 0)).x) > ((exp((_14726 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14774 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14774 = 1.0f.xxxx;
                    }
                    _14773 = _14774;
                }
                else
                {
                    _14773 = 1.0f.xxxx;
                }
                _14772 = _14773;
            }
            bool _5355 = _14678 >= 0.0f;
            bool _5356 = (!_14690) && _5355;
            bool _5363;
            if (_5356)
            {
                _5363 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5363 = _5356;
            }
            bool _5369;
            if (_5363)
            {
                _5369 = _14699.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5369 = _5363;
            }
            bool _5374;
            if (_5369)
            {
                bool _10873 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
                bool _10879;
                if (_10873)
                {
                    _10879 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
                }
                else
                {
                    _10879 = _10873;
                }
                _5374 = _10879;
            }
            else
            {
                _5374 = _5369;
            }
            float4 _14797;
            if (_5374)
            {
                float _14766;
                if (_5355)
                {
                    _14766 = _14678 - _5260;
                }
                else
                {
                    float _14762;
                    _14762 = 2.0f;
                    float _10936;
                    for (int _14761 = 0; _14761 < 24; _14762 = _10936, _14761++)
                    {
                        float _10900 = float(_14761 & 7) * 0.785398185253143310546875f;
                        int _10902 = _14761 >> 3;
                        int _14763;
                        if (_10902 == 0)
                        {
                            _14763 = 16;
                        }
                        else
                        {
                            _14763 = (_10902 == 1) ? 48 : 96;
                        }
                        uint _10952_dummy_parameter;
                        _10936 = min(_14762, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14128 + ((cbFI_MvDepthLaneSizeRcp * float(_14763)) * float2(cos(_10900), sin(_10900))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10952_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14766 = _14762;
                }
                uint _11000_dummy_parameter;
                float4 _14798;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11000_dummy_parameter))))), 0)).x) > ((exp((_14766 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _13960 = _14772;
                    _13960.x = 0.0f;
                    _14798 = _13960;
                }
                else
                {
                    _14798 = _14772;
                }
                _14797 = _14798;
            }
            else
            {
                _14797 = _14772;
            }
            float4 _14810;
            if (_5356)
            {
                float _11027 = (exp(((_14678 - _5260) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5412 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5418;
                if (_5412)
                {
                    _5418 = _14699.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5418 = _5412;
                }
                bool _5423;
                if (_5418)
                {
                    bool _11032 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                    bool _11038;
                    if (_11032)
                    {
                        _11038 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11038 = _11032;
                    }
                    _5423 = _11038;
                }
                else
                {
                    _5423 = _5418;
                }
                bool _5431;
                if (_5423)
                {
                    uint _11045_dummy_parameter;
                    _5431 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11045_dummy_parameter))))), 0)).x) > _11027;
                }
                else
                {
                    _5431 = _5423;
                }
                float4 _14808;
                if (_5431)
                {
                    float4 _13963 = _14797;
                    _13963.w = 0.0f;
                    _14808 = _13963;
                }
                else
                {
                    _14808 = _14797;
                }
                bool _5438 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5444;
                if (_5438)
                {
                    _5444 = _14699.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5444 = _5438;
                }
                bool _5449;
                if (_5444)
                {
                    bool _11063 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                    bool _11069;
                    if (_11063)
                    {
                        _11069 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11069 = _11063;
                    }
                    _5449 = _11069;
                }
                else
                {
                    _5449 = _5444;
                }
                bool _5457;
                if (_5449)
                {
                    uint _11076_dummy_parameter;
                    _5457 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11076_dummy_parameter))))), 0)).x) > _11027;
                }
                else
                {
                    _5457 = _5449;
                }
                float4 _14811;
                if (_5457)
                {
                    float4 _13966 = _14808;
                    _13966.z = 0.0f;
                    _14811 = _13966;
                }
                else
                {
                    _14811 = _14808;
                }
                _14810 = _14811;
            }
            else
            {
                _14810 = _14797;
            }
            float4 _14882;
            if (any(bool4(_14810.x < 1.0f.xxxx.x, _14810.y < 1.0f.xxxx.y, _14810.z < 1.0f.xxxx.z, _14810.w < 1.0f.xxxx.w)))
            {
                float4 _5468 = _14699 * _14810;
                float _5470 = dot(_5468, 1.0f.xxxx);
                float4 _14883;
                if (_5470 > 0.0f)
                {
                    _14883 = _5468 / _5470.xxxx;
                }
                else
                {
                    bool _5481 = _14810.y == 0.0f;
                    bool _5487;
                    if (_5481)
                    {
                        _5487 = _14810.x > 0.0f;
                    }
                    else
                    {
                        _5487 = _5481;
                    }
                    bool _5492;
                    if (_5487)
                    {
                        bool _11094 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
                        bool _11100;
                        if (_11094)
                        {
                            _11100 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11100 = _11094;
                        }
                        _5492 = _11100;
                    }
                    else
                    {
                        _5492 = _5487;
                    }
                    float4 _14884;
                    if (_5492)
                    {
                        _14884 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5497 = _14810.x == 0.0f;
                        bool _5503;
                        if (_5497)
                        {
                            _5503 = _14810.y > 0.0f;
                        }
                        else
                        {
                            _5503 = _5497;
                        }
                        bool _5508;
                        if (_5503)
                        {
                            bool _11105 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
                            bool _11111;
                            if (_11105)
                            {
                                _11111 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11111 = _11105;
                            }
                            _5508 = _11111;
                        }
                        else
                        {
                            _5508 = _5503;
                        }
                        bool4 _17222 = _5508.xxxx;
                        _14884 = float4(_17222.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14699.x, _17222.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14699.y, _17222.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14699.z, _17222.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14699.w);
                    }
                    _14883 = _14884;
                }
                _14882 = _14883;
            }
            else
            {
                _14882 = _14699;
            }
            _14881 = _14882;
        }
        else
        {
            _14881 = _14704;
        }
        float4 _15611;
        bool _15917;
        float3 _16050;
        if (((cbFI_pad0 & 32768u) != 0u) && _5217)
        {
            bool _5525 = _14881.x > 0.00999999977648258209228515625f;
            bool _5528 = _14881.y > 0.00999999977648258209228515625f;
            bool _5537 = (_14881.z + _14881.w) > 0.0199999995529651641845703125f;
            bool _5543;
            if (_5537)
            {
                bool _11116 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                bool _11122;
                if (_11116)
                {
                    _11122 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                }
                else
                {
                    _11122 = _11116;
                }
                _5543 = _11122;
            }
            else
            {
                _5543 = _5537;
            }
            bool _5548;
            if (_5543)
            {
                bool _11127 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                bool _11133;
                if (_11127)
                {
                    _11133 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                }
                else
                {
                    _11133 = _11127;
                }
                _5548 = _11133;
            }
            else
            {
                _5548 = _5543;
            }
            bool _5555;
            if (_5548)
            {
                float _14897;
                do
                {
                    bool _11216 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                    bool _11222;
                    if (_11216)
                    {
                        _11222 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11222 = _11216;
                    }
                    bool _11153 = !_11222;
                    bool _11160;
                    if (!_11153)
                    {
                        bool _11227 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                        bool _11233;
                        if (_11227)
                        {
                            _11233 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11233 = _11227;
                        }
                        _11160 = !_11233;
                    }
                    else
                    {
                        _11160 = _11153;
                    }
                    if (_11160)
                    {
                        _14897 = 0.0f;
                        break;
                    }
                    uint _11240_dummy_parameter;
                    uint _11256_dummy_parameter;
                    float4x4 _14896;
                    do
                    {
                        float4x4 _11270;
                        bool _14895;
                        do
                        {
                            _11270 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14895 = false;
                                break;
                            }
                            uint _11304 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11304 + 32u) * 4 + 0) != 1u)
                            {
                                _14895 = false;
                                break;
                            }
                            uint _14892;
                            _14892 = 0u;
                            for (; _14892 < 4u; _14892++)
                            {
                                for (uint _14893 = 0u; _14893 < 4u; )
                                {
                                    _11270[_14892][_14893] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11304 + 16u) + (_14892 * 4u)) + _14893) * 4 + 0));
                                    _14893++;
                                    continue;
                                }
                            }
                            _14895 = true;
                            break;
                        } while(false);
                        if (_14895)
                        {
                            _14896 = _11270;
                            break;
                        }
                        _14896 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11181 = mul(float4((float2(_14131.x, 1.0f - _14131.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11240_dummy_parameter))))), 0)).x, 1.0f), _14896);
                    float _11183 = _11181.w;
                    if (abs(_11183) < 9.9999999747524270787835121154785e-07f)
                    {
                        _14897 = 0.0f;
                        break;
                    }
                    float _11194 = abs(cbFI_DeviceToViewDepth.y / ((_11181.z / _11183) - cbFI_DeviceToViewDepth.x));
                    float _11197 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11256_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _14897 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11194 - _11197) / max(max(_11194, _11197), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5555 = _14897 < 0.5f;
            }
            else
            {
                _5555 = _5548;
            }
            float4 _14916;
            if (_5555)
            {
                uint _11408_dummy_parameter;
                uint _11439_dummy_parameter;
                float4 _14917;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11408_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11439_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _14917 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _14917 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _14916 = _14917;
            }
            else
            {
                _14916 = 1.0f.xxxx;
            }
            bool _5579;
            if (_9873)
            {
                bool _11468 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
                bool _11474;
                if (_11468)
                {
                    _11474 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
                }
                else
                {
                    _11474 = _11468;
                }
                _5579 = _11474;
            }
            else
            {
                _5579 = _9873;
            }
            bool _5585;
            if (_9873)
            {
                bool _11479 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
                bool _11485;
                if (_11479)
                {
                    _11485 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
                }
                else
                {
                    _11485 = _11479;
                }
                _5585 = _11485;
            }
            else
            {
                _5585 = _9873;
            }
            bool _5591;
            if (_9905)
            {
                bool _11490 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                bool _11496;
                if (_11490)
                {
                    _11496 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                }
                else
                {
                    _11496 = _11490;
                }
                _5591 = _11496;
            }
            else
            {
                _5591 = _9905;
            }
            bool _5597;
            if (_9905)
            {
                bool _11501 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                bool _11507;
                if (_11501)
                {
                    _11507 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                }
                else
                {
                    _11507 = _11501;
                }
                _5597 = _11507;
            }
            else
            {
                _5597 = _9905;
            }
            bool _5600 = _5591 != _5597;
            bool _5606;
            if (_5600)
            {
                _5606 = _5579 || _5585;
            }
            else
            {
                _5606 = _5600;
            }
            float4 _15019;
            if (_5606)
            {
                float4 _13993 = _14916;
                _13993.z = 0.0f;
                _13993.w = 0.0f;
                _15019 = _13993;
            }
            else
            {
                _15019 = _14916;
            }
            bool _5613 = _5579 && _5525;
            bool _5616 = _5585 && _5528;
            float4 _15124;
            float3 _16159;
            if (_5613 || _5616)
            {
                float _15014;
                do
                {
                    uint4 _11646 = r_warped_motion_qdata_tp1.Load(int3(_14349, 0));
                    uint _11647 = _11646.x;
                    if (_11647 != 0u)
                    {
                        float _15013;
                        if (_11647 == 0u)
                        {
                            _15013 = -1.0f;
                        }
                        else
                        {
                            _15013 = float((_11647 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15014 = _15013;
                        break;
                    }
                    int _14996;
                    uint _14997;
                    _14997 = _11647;
                    _14996 = -1;
                    uint _15012;
                    for (; _14996 <= 1; _14997 = _15012, _14996++)
                    {
                        _15012 = _14997;
                        for (int _15010 = -1; _15010 <= 1; )
                        {
                            _15012 = max(_15012, r_warped_motion_qdata_tp1.Load(int3(clamp(_14349 + int2(_15010, _14996), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15010++;
                            continue;
                        }
                    }
                    if (_14997 != 0u)
                    {
                        float _15009;
                        if (_14997 == 0u)
                        {
                            _15009 = -1.0f;
                        }
                        else
                        {
                            _15009 = float((_14997 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15014 = _15009;
                        break;
                    }
                    uint _14999;
                    _14999 = 4294967295u;
                    uint _17189;
                    for (int _14998 = 0; _14998 < 8; _14999 = _17189, _14998++)
                    {
                        int _15002 = 0;
                        for (;;)
                        {
                            if (_15002 < 5)
                            {
                                int2 _11597 = _14349 + (_1192[_14998] * _1201[_15002].xx);
                                bool _11600 = any(bool2(_11597.x < int2(0, 0).x, _11597.y < int2(0, 0).y));
                                bool _11608;
                                if (!_11600)
                                {
                                    _11608 = any(bool2(_11597.x >= cbFI_MvDepthLaneSize.x, _11597.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11608 = _11600;
                                }
                                if (_11608)
                                {
                                    _17189 = _14999;
                                    break;
                                }
                                uint4 _11686 = r_warped_motion_qdata_tp1.Load(int3(_11597, 0));
                                uint _11687 = _11686.x;
                                if (_11687 != 0u)
                                {
                                    _17189 = min(_14999, _11687);
                                    break;
                                }
                                _15002++;
                                continue;
                            }
                            else
                            {
                                _17189 = _14999;
                                break;
                            }
                        }
                    }
                    float _15001;
                    if (_14999 == 4294967295u)
                    {
                        _15001 = -1.0f;
                    }
                    else
                    {
                        float _15000;
                        if (_14999 == 0u)
                        {
                            _15000 = -1.0f;
                        }
                        else
                        {
                            _15000 = float((_14999 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15001 = _15000;
                    }
                    _15014 = _15001;
                    break;
                } while(false);
                bool _5624 = _15014 < 0.0f;
                float _15015;
                if (_5624)
                {
                    _15015 = 0.0f;
                }
                else
                {
                    _15015 = _15014 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11708_dummy_parameter;
                uint _11740_dummy_parameter;
                float4 _15052;
                if ((_5624 && _5613) && _5616)
                {
                    uint _11772_dummy_parameter;
                    float _11796 = log(((r_depth_tm1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11772_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11804_dummy_parameter;
                    float _11828 = log(((r_depth_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11804_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _15053;
                    if (_11796 > (_11828 + 0.07999999821186065673828125f))
                    {
                        float4 _13997 = _15019;
                        _13997.x = 0.0f;
                        _15053 = _13997;
                    }
                    else
                    {
                        float4 _15054;
                        if (_11828 > (_11796 + 0.07999999821186065673828125f))
                        {
                            float4 _13999 = _15019;
                            _13999.y = 0.0f;
                            _15054 = _13999;
                        }
                        else
                        {
                            _15054 = _15019;
                        }
                        _15053 = _15054;
                    }
                    _15052 = _15053;
                }
                else
                {
                    _15052 = _15019;
                }
                float _5676 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5678 = _15014 >= 0.0f;
                float _15035;
                if (_5678)
                {
                    _15035 = _15014 - _5676;
                }
                else
                {
                    float _15031;
                    if (_5613)
                    {
                        float _15030;
                        _15030 = 2.0f;
                        float _11886;
                        for (int _15029 = 0; _15029 < 24; _15030 = _11886, _15029++)
                        {
                            float _11850 = float(_15029 & 7) * 0.785398185253143310546875f;
                            int _11852 = _15029 >> 3;
                            int _15032;
                            if (_11852 == 0)
                            {
                                _15032 = 16;
                            }
                            else
                            {
                                _15032 = (_11852 == 1) ? 48 : 96;
                            }
                            uint _11902_dummy_parameter;
                            _11886 = min(_15030, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14128 + ((cbFI_MvDepthLaneSizeRcp * float(_15032)) * float2(cos(_11850), sin(_11850))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11902_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15031 = _15030;
                    }
                    else
                    {
                        _15031 = 0.0f;
                    }
                    _15035 = _15031;
                }
                float _15042;
                if (_5678)
                {
                    _15042 = _15014 - _5676;
                }
                else
                {
                    float _15038;
                    if (_5616)
                    {
                        float _15037;
                        _15037 = 2.0f;
                        float _12000;
                        for (int _15036 = 0; _15036 < 24; _15037 = _12000, _15036++)
                        {
                            float _11964 = float(_15036 & 7) * 0.785398185253143310546875f;
                            int _11966 = _15036 >> 3;
                            int _15039;
                            if (_11966 == 0)
                            {
                                _15039 = 16;
                            }
                            else
                            {
                                _15039 = (_11966 == 1) ? 48 : 96;
                            }
                            uint _12032_dummy_parameter;
                            _12000 = min(_15037, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14130 + ((cbFI_MvDepthLaneSizeRcp * float(_15039)) * float2(cos(_11964), sin(_11964))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12032_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15038 = _15037;
                    }
                    else
                    {
                        _15038 = 0.0f;
                    }
                    _15042 = _15038;
                }
                float _15043;
                if (_5613)
                {
                    uint _12064_dummy_parameter;
                    _15043 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12064_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15043 = 0.0f;
                }
                float _15044;
                if (_5616)
                {
                    uint _12084_dummy_parameter;
                    _15044 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12084_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15044 = 0.0f;
                }
                bool _5733;
                if (_5613)
                {
                    _5733 = _15043 > ((exp((_15035 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5733 = _5613;
                }
                float4 _15060;
                if (_5733)
                {
                    float4 _14001 = _15052;
                    _14001.x = 0.0f;
                    _15060 = _14001;
                }
                else
                {
                    _15060 = _15052;
                }
                bool _5745;
                if (_5616)
                {
                    _5745 = _15044 > ((exp((_15042 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5745 = _5616;
                }
                float4 _15062;
                if (_5745)
                {
                    float4 _14003 = _15060;
                    _14003.y = 0.0f;
                    _15062 = _14003;
                }
                else
                {
                    _15062 = _15060;
                }
                float4 _15125;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5678)
                {
                    bool _5765;
                    if (_5613)
                    {
                        _5765 = _15043 < ((exp((_15035 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5765 = _5613;
                    }
                    float4 _15064;
                    if (_5765)
                    {
                        float4 _14005 = _15062;
                        _14005.x = 0.0f;
                        _15064 = _14005;
                    }
                    else
                    {
                        _15064 = _15062;
                    }
                    bool _5777;
                    if (_5616)
                    {
                        _5777 = _15044 < ((exp((_15042 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5777 = _5616;
                    }
                    float4 _15126;
                    if (_5777)
                    {
                        float4 _14007 = _15064;
                        _14007.y = 0.0f;
                        _15126 = _14007;
                    }
                    else
                    {
                        _15126 = _15064;
                    }
                    _15125 = _15126;
                }
                else
                {
                    _15125 = _15062;
                }
                _16159 = float3(_15015, log(((r_depth_tm1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11708_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_14130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11740_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _15124 = _15125;
            }
            else
            {
                _16159 = float3(0.0f, 0.0f, 0.5f);
                _15124 = _15019;
            }
            bool _5788 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5537;
            bool _5794;
            if (_5788)
            {
                _5794 = _5591 || _5597;
            }
            else
            {
                _5794 = _5788;
            }
            float4 _15167;
            if (_5794)
            {
                float _15119;
                do
                {
                    uint4 _12264 = r_warped_motion_qdata_tp1.Load(int3(_14349, 0));
                    uint _12265 = _12264.x;
                    if (_12265 != 0u)
                    {
                        float _15118;
                        if (_12265 == 0u)
                        {
                            _15118 = -1.0f;
                        }
                        else
                        {
                            _15118 = float((_12265 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15119 = _15118;
                        break;
                    }
                    int _15101;
                    uint _15102;
                    _15102 = _12265;
                    _15101 = -1;
                    uint _15117;
                    for (; _15101 <= 1; _15102 = _15117, _15101++)
                    {
                        _15117 = _15102;
                        for (int _15115 = -1; _15115 <= 1; )
                        {
                            _15117 = max(_15117, r_warped_motion_qdata_tp1.Load(int3(clamp(_14349 + int2(_15115, _15101), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15115++;
                            continue;
                        }
                    }
                    if (_15102 != 0u)
                    {
                        float _15114;
                        if (_15102 == 0u)
                        {
                            _15114 = -1.0f;
                        }
                        else
                        {
                            _15114 = float((_15102 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15119 = _15114;
                        break;
                    }
                    uint _15104;
                    _15104 = 4294967295u;
                    uint _17190;
                    for (int _15103 = 0; _15103 < 8; _15104 = _17190, _15103++)
                    {
                        int _15107 = 0;
                        for (;;)
                        {
                            if (_15107 < 5)
                            {
                                int2 _12215 = _14349 + (_1192[_15103] * _1201[_15107].xx);
                                bool _12218 = any(bool2(_12215.x < int2(0, 0).x, _12215.y < int2(0, 0).y));
                                bool _12226;
                                if (!_12218)
                                {
                                    _12226 = any(bool2(_12215.x >= cbFI_MvDepthLaneSize.x, _12215.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12226 = _12218;
                                }
                                if (_12226)
                                {
                                    _17190 = _15104;
                                    break;
                                }
                                uint4 _12304 = r_warped_motion_qdata_tp1.Load(int3(_12215, 0));
                                uint _12305 = _12304.x;
                                if (_12305 != 0u)
                                {
                                    _17190 = min(_15104, _12305);
                                    break;
                                }
                                _15107++;
                                continue;
                            }
                            else
                            {
                                _17190 = _15104;
                                break;
                            }
                        }
                    }
                    float _15106;
                    if (_15104 == 4294967295u)
                    {
                        _15106 = -1.0f;
                    }
                    else
                    {
                        float _15105;
                        if (_15104 == 0u)
                        {
                            _15105 = -1.0f;
                        }
                        else
                        {
                            _15105 = float((_15104 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15106 = _15105;
                    }
                    _15119 = _15106;
                    break;
                } while(false);
                float4 _15168;
                if (_15119 >= 0.0f)
                {
                    float _12326 = (exp((_15119 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5813;
                    if (_5591)
                    {
                        uint _12333_dummy_parameter;
                        _5813 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12333_dummy_parameter))))), 0)).x) > _12326;
                    }
                    else
                    {
                        _5813 = _5591;
                    }
                    float4 _15137;
                    if (_5813)
                    {
                        float4 _14009 = _15124;
                        _14009.z = 0.0f;
                        _15137 = _14009;
                    }
                    else
                    {
                        _15137 = _15124;
                    }
                    bool _5825;
                    if (_5597)
                    {
                        uint _12353_dummy_parameter;
                        _5825 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12353_dummy_parameter))))), 0)).x) > _12326;
                    }
                    else
                    {
                        _5825 = _5597;
                    }
                    float4 _15169;
                    if (_5825)
                    {
                        float4 _14011 = _15137;
                        _14011.w = 0.0f;
                        _15169 = _14011;
                    }
                    else
                    {
                        _15169 = _15137;
                    }
                    _15168 = _15169;
                }
                else
                {
                    _15168 = _15124;
                }
                _15167 = _15168;
            }
            else
            {
                _15167 = _15124;
            }
            bool _5833 = _5579 != _5585;
            bool _5840;
            if (_5833)
            {
                _5840 = _5579 ? _5525 : _5528;
            }
            else
            {
                _5840 = _5833;
            }
            bool _5847;
            if (_5840)
            {
                _5847 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5847 = _5840;
            }
            float4 _15270;
            if (_5847)
            {
                bool2 _5852 = _5579.xx;
                float2 _5853 = float2(_5852.x ? _14128.x : _14130.x, _5852.y ? _14128.y : _14130.y);
                float _15151;
                if (_5579)
                {
                    uint _12373_dummy_parameter;
                    _15151 = r_depth_tm1.Load(int3(int2(floor(_5853 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12373_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12389_dummy_parameter;
                    _15151 = r_depth_tp1.Load(int3(int2(floor(_5853 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12389_dummy_parameter))))), 0)).x;
                }
                float4x4 _15158;
                if (_5579)
                {
                    float4x4 _15147;
                    do
                    {
                        float4x4 _12403;
                        bool _15146;
                        do
                        {
                            _12403 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15146 = false;
                                break;
                            }
                            uint _12437 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12437 + 32u) * 4 + 0) != 1u)
                            {
                                _15146 = false;
                                break;
                            }
                            uint _15143;
                            _15143 = 0u;
                            for (; _15143 < 4u; _15143++)
                            {
                                for (uint _15144 = 0u; _15144 < 4u; )
                                {
                                    _12403[_15143][_15144] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12437 + 16u) + (_15143 * 4u)) + _15144) * 4 + 0));
                                    _15144++;
                                    continue;
                                }
                            }
                            _15146 = true;
                            break;
                        } while(false);
                        if (_15146)
                        {
                            _15147 = _12403;
                            break;
                        }
                        _15147 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15158 = _15147;
                }
                else
                {
                    float4x4 _15142;
                    do
                    {
                        float4x4 _12509;
                        bool _15141;
                        do
                        {
                            _12509 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15141 = false;
                                break;
                            }
                            uint _12543 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12543 + 32u) * 4 + 0) != 1u)
                            {
                                _15141 = false;
                                break;
                            }
                            uint _15138;
                            _15138 = 0u;
                            for (; _15138 < 4u; _15138++)
                            {
                                for (uint _15139 = 0u; _15139 < 4u; )
                                {
                                    _12509[_15138][_15139] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12543 + (_15138 * 4u)) + _15139) * 4 + 0));
                                    _15139++;
                                    continue;
                                }
                            }
                            _15141 = true;
                            break;
                        } while(false);
                        if (_15141)
                        {
                            _15142 = _12509;
                            break;
                        }
                        _15142 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15158 = _15142;
                }
                float2 _15159;
                do
                {
                    float _12620 = _5853.x;
                    float _12623 = 1.0f - _5853.y;
                    float4 _12634 = mul(float4((float2(_12620, _12623) * 2.0f) - 1.0f.xx, _15151, 1.0f), _15158);
                    float _12636 = _12634.w;
                    if (!(_12636 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15159 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12649 = ((_12634.xy / _12636.xx) + 1.0f.xx) * 0.5f;
                    _15159 = float2(_12649.x - _12620, _12623 - _12649.y);
                    break;
                } while(false);
                float2 _5883 = float2(cbFI_DisplaySize);
                float4 _15271;
                if (!(length(((_5853 + _15159) - float2(_5852.x ? _14130.x : _14128.x, _5852.y ? _14130.y : _14128.y)) * _5883) <= ((0.100000001490116119384765625f * length(_15159 * _5883)) + 8.0f)))
                {
                    float4 _15272;
                    if (_5579)
                    {
                        float4 _14021 = _15167;
                        _14021.x = 0.0f;
                        _15272 = _14021;
                    }
                    else
                    {
                        float4 _14023 = _15167;
                        _14023.y = 0.0f;
                        _15272 = _14023;
                    }
                    _15271 = _15272;
                }
                else
                {
                    _15271 = _15167;
                }
                _15270 = _15271;
            }
            else
            {
                _15270 = _15167;
            }
            float4 _5908 = _14881 * _15270;
            float _5910 = dot(_5908, 1.0f.xxxx);
            float4 _15612;
            bool _15918;
            if (_5910 > 0.0f)
            {
                _15918 = _14572;
                _15612 = _5908 / _5910.xxxx;
            }
            else
            {
                bool _5921 = any(bool4(_15270.x < 1.0f.xxxx.x, _15270.y < 1.0f.xxxx.y, _15270.z < 1.0f.xxxx.z, _15270.w < 1.0f.xxxx.w));
                if (_5921)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12671;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12671);
                    }
                }
                bool4 _17225 = _5921.xxxx;
                _15918 = _5921 ? true : _14572;
                _15612 = float4(_17225.x ? 0.0f.xxxx.x : _14881.x, _17225.y ? 0.0f.xxxx.y : _14881.y, _17225.z ? 0.0f.xxxx.z : _14881.z, _17225.w ? 0.0f.xxxx.w : _14881.w);
            }
            _16050 = _16159;
            _15917 = _15918;
            _15611 = _15612;
        }
        else
        {
            _16050 = float3(0.0f, 0.0f, 0.5f);
            _15917 = _14572;
            _15611 = _14881;
        }
        uint _5930 = (cbFI_pad0 >> 24u) & 31u;
        uint _5934 = (cbFI_pad0 >> 16u) & 255u;
        bool _5936 = _5930 != 0u;
        bool _5938 = _5934 == 12u;
        bool _5941 = _5934 == 13u;
        float4 _15632;
        if ((_5936 || _5938) || _5941)
        {
            float _15278;
            do
            {
                bool _12755 = all(bool2(_14131.x > 0.0f.xx.x, _14131.y > 0.0f.xx.y));
                bool _12761;
                if (_12755)
                {
                    _12761 = all(bool2(_14131.x < 1.0f.xx.x, _14131.y < 1.0f.xx.y));
                }
                else
                {
                    _12761 = _12755;
                }
                bool _12692 = !_12761;
                bool _12699;
                if (!_12692)
                {
                    bool _12766 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
                    bool _12772;
                    if (_12766)
                    {
                        _12772 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12772 = _12766;
                    }
                    _12699 = !_12772;
                }
                else
                {
                    _12699 = _12692;
                }
                if (_12699)
                {
                    _15278 = 0.0f;
                    break;
                }
                uint _12779_dummy_parameter;
                uint _12795_dummy_parameter;
                float4x4 _15277;
                do
                {
                    float4x4 _12809;
                    bool _15276;
                    do
                    {
                        _12809 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15276 = false;
                            break;
                        }
                        uint _12843 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12843 + 32u) * 4 + 0) != 1u)
                        {
                            _15276 = false;
                            break;
                        }
                        uint _15273;
                        _15273 = 0u;
                        for (; _15273 < 4u; _15273++)
                        {
                            for (uint _15274 = 0u; _15274 < 4u; )
                            {
                                _12809[_15273][_15274] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12843 + 16u) + (_15273 * 4u)) + _15274) * 4 + 0));
                                _15274++;
                                continue;
                            }
                        }
                        _15276 = true;
                        break;
                    } while(false);
                    if (_15276)
                    {
                        _15277 = _12809;
                        break;
                    }
                    _15277 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12720 = mul(float4((float2(_14131.x, 1.0f - _14131.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12779_dummy_parameter))))), 0)).x, 1.0f), _15277);
                float _12722 = _12720.w;
                if (abs(_12722) < 9.9999999747524270787835121154785e-07f)
                {
                    _15278 = 0.0f;
                    break;
                }
                float _12733 = abs(cbFI_DeviceToViewDepth.y / ((_12720.z / _12722) - cbFI_DeviceToViewDepth.x));
                float _12736 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12795_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15278 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12733 - _12736) / max(max(_12733, _12736), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _12945 = all(bool2(_14132.x > 0.0f.xx.x, _14132.y > 0.0f.xx.y));
            bool _12951;
            if (_12945)
            {
                _12951 = all(bool2(_14132.x < 1.0f.xx.x, _14132.y < 1.0f.xx.y));
            }
            else
            {
                _12951 = _12945;
            }
            float _15279;
            if (_12951)
            {
                uint _12958_dummy_parameter;
                _15279 = length((_6771 + (r_motion_tp1.Load(int3(int2(floor(_14132 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12958_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15279 = 1000000.0f;
            }
            float _15294;
            if ((_5930 & 1u) != 0u)
            {
                _15294 = _15278;
            }
            else
            {
                _15294 = 1.0f;
            }
            float _15295;
            if ((_5930 & 2u) != 0u)
            {
                _15295 = _15294 * (1.0f - smoothstep(2.0f, 8.0f, _15279));
            }
            else
            {
                _15295 = _15294;
            }
            float _15296;
            if ((_5930 & 4u) != 0u)
            {
                _15296 = _15295 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7492 - _7500) - length(_7476 - _7484))));
            }
            else
            {
                _15296 = _15295;
            }
            float _15626;
            if ((_5930 & 8u) != 0u)
            {
                _15626 = lerp(1.0f, _15296, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7476 - _7484)));
            }
            else
            {
                _15626 = _15296;
            }
            bool _6016 = (_5930 & 16u) != 0u;
            bool _6025;
            if (_6016)
            {
                _6025 = length(_14126 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6025 = _6016;
            }
            float _17227 = _6025 ? 1.0f : _15626;
            bool _6031 = _5936 && _9873;
            bool _6036;
            if (_6031)
            {
                bool _12983 = all(bool2(_14128.x > 0.0f.xx.x, _14128.y > 0.0f.xx.y));
                bool _12989;
                if (_12983)
                {
                    _12989 = all(bool2(_14128.x < 1.0f.xx.x, _14128.y < 1.0f.xx.y));
                }
                else
                {
                    _12989 = _12983;
                }
                _6036 = _12989;
            }
            else
            {
                _6036 = _6031;
            }
            bool _6041;
            if (_6036)
            {
                bool _12994 = all(bool2(_14130.x > 0.0f.xx.x, _14130.y > 0.0f.xx.y));
                bool _13000;
                if (_12994)
                {
                    _13000 = all(bool2(_14130.x < 1.0f.xx.x, _14130.y < 1.0f.xx.y));
                }
                else
                {
                    _13000 = _12994;
                }
                _6041 = _13000;
            }
            else
            {
                _6041 = _6036;
            }
            float4 _15633;
            if (_6041)
            {
                float _6047 = _15611.x + _15611.y;
                float _6056 = (_15611.z + _15611.w) * (1.0f - _17227);
                float _15629;
                if (_6047 > 9.9999997473787516355514526367188e-06f)
                {
                    _15629 = _15611.x / _6047;
                }
                else
                {
                    _15629 = _4786;
                }
                _15633 = float4(_15611.x + (_6056 * _15629), _15611.y + (_6056 * (1.0f - _15629)), _15611.zw * _17227);
            }
            else
            {
                _15633 = _15611;
            }
            _15632 = _15633;
        }
        else
        {
            _15632 = _15611;
        }
        float3 _6117 = (((_7476 * _15632.x) + (_7484 * _15632.y)) + (_7492 * _15632.z)) + (_7500 * _15632.w);
        float3 _16992;
        if (_4802 && (_15647 > 0.0f))
        {
            uint _13007_dummy_parameter;
            float2 _13022 = r_motion_tp1.Load(int3(int2(floor(_4561 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13007_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _15909;
            if (_6799)
            {
                float2 _13067 = clamp((((_14105 + (_13022 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13070 = tan(_13067.x);
                _15909 = (float2(_13070 / cbFI_DeviceToViewDepth.z, (tan(_13067.y) * sqrt(1.0f + (_13070 * _13070))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15909 = _14105 + (_13022 * cbFI_Timestep);
            }
            float2 _15910;
            if (_6799)
            {
                float2 _13146 = clamp((((_14105 + (_13022 * _4776)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13149 = tan(_13146.x);
                _15910 = (float2(_13149 / cbFI_DeviceToViewDepth.z, (tan(_13146.y) * sqrt(1.0f + (_13149 * _13149))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15910 = _14105 + (_13022 * _4776);
            }
            _16992 = lerp(_6117, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _15909, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _15910, 0.0f).xyz, cbFI_Timestep.xxx), _15647.xxx);
        }
        else
        {
            _16992 = _6117;
        }
        float3 _16991;
        if (_15917)
        {
            float3 _13191 = r_current_interpolation_source.Load(int3(_4087, 0)).xyz;
            float3 _16993;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9873)
            {
                uint _13198_dummy_parameter;
                float _16040;
                _16040 = r_depth_tm1.Load(int3(int2(floor(_14128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13198_dummy_parameter))))), 0)).x;
                float _6198;
                for (int _16039 = 0; _16039 < 24; _16040 = _6198, _16039++)
                {
                    float _6170 = float(_16039 & 7) * 0.785398185253143310546875f;
                    int _6172 = _16039 >> 3;
                    int _17043;
                    if (_6172 == 0)
                    {
                        _17043 = 16;
                    }
                    else
                    {
                        _17043 = (_6172 == 1) ? 48 : 96;
                    }
                    uint _13218_dummy_parameter;
                    _6198 = max(_16040, r_depth_tm1.Load(int3(int2(floor(clamp(_14128 + ((cbFI_MvDepthLaneSizeRcp * float(_17043)) * float2(cos(_6170), sin(_6170))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13218_dummy_parameter))))), 0)).x);
                }
                float2 _16041;
                do
                {
                    float _13240 = 1.0f - _14128.y;
                    float4 _13251 = mul(float4((float2(_14128.x, _13240) * 2.0f) - 1.0f.xx, _16040, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13253 = _13251.w;
                    if (!(_13253 > 9.9999999747524270787835121154785e-07f))
                    {
                        _16041 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13266 = ((_13251.xy / _13253.xx) + 1.0f.xx) * 0.5f;
                    _16041 = float2(_13266.x - _14128.x, _13240 - _13266.y);
                    break;
                } while(false);
                float2 _6209 = _14128 + _16041;
                bool _13284 = all(bool2(_6209.x > 0.0f.xx.x, _6209.y > 0.0f.xx.y));
                bool _13290;
                if (_13284)
                {
                    _13290 = all(bool2(_6209.x < 1.0f.xx.x, _6209.y < 1.0f.xx.y));
                }
                else
                {
                    _13290 = _13284;
                }
                float3 _16994;
                if (_13290)
                {
                    float _6215 = abs(cbFI_DeviceToViewDepth.y / (_16040 - cbFI_DeviceToViewDepth.x));
                    uint _13310_dummy_parameter;
                    int2 _13310 = int2(spvTextureSize(r_depth_m2, uint(0), _13310_dummy_parameter));
                    float _6219 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6209 * float2(_13310))), int2(0, 0), _13310 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _16999;
                    if (abs(_6219 - _6215) <= (0.20000000298023223876953125f * max(_6219, _6215)))
                    {
                        uint _13344_dummy_parameter;
                        int2 _13344 = int2(spvTextureSize(r_colour_m2, uint(0), _13344_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13367;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13367);
                        }
                        _16999 = r_colour_m2.Load(int3(clamp(int2(floor(_6209 * float2(_13344))), int2(0, 0), _13344 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13377;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13377);
                        }
                        _16999 = _13191;
                    }
                    _16994 = _16999;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13387;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13387);
                    }
                    _16994 = _13191;
                }
                _16993 = _16994;
            }
            else
            {
                _16993 = _13191;
            }
            _16991 = _16993;
        }
        else
        {
            _16991 = _16992;
        }
        uint _6247 = cbFI_pad0 & 255u;
        bool _16868;
        float3 _16990;
        if (_6247 != 0u)
        {
            float3 _6252 = r_present_backbuffer.Load(int3(_4087, 0)).xyz;
            float3 _6256 = r_current_interpolation_source.Load(int3(_4087, 0)).xyz;
            float3 _6260 = abs(_6252 - _6256);
            float3 _16044;
            if (_6247 == 2u)
            {
                _16044 = (abs(_6256) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _16044 = 0.000244140625f.xxx;
            }
            bool _6276 = any(bool3(_6260.x > _16044.x, _6260.y > _16044.y, _6260.z > _16044.z));
            bool3 _17228 = _6276.xxx;
            _16990 = float3(_17228.x ? _6252.x : _16991.x, _17228.y ? _6252.y : _16991.y, _17228.z ? _6252.z : _16991.z);
            _16868 = _6276;
        }
        else
        {
            _16990 = _16991;
            _16868 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13402;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13402);
        }
        float3 _16973;
        if (_5934 == 1u)
        {
            _16973 = lerp(_7476, _7484, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _16974;
            if (_5934 == 2u)
            {
                _16974 = lerp(_7492, _7500, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _16975;
                if (_5934 == 3u)
                {
                    _16975 = float(_16868).xxx;
                }
                else
                {
                    float3 _16976;
                    if (_5934 == 4u)
                    {
                        _16976 = float3(((_14126 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _16977;
                        if (_5934 == 5u)
                        {
                            _16977 = float3(((_6771 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _16978;
                            if (_5934 == 6u)
                            {
                                _16978 = float3(_15632.xy, _15632.z + _15632.w);
                            }
                            else
                            {
                                float3 _16979;
                                if (_5934 == 7u)
                                {
                                    _16979 = r_current_interpolation_source.Load(int3(_4087, 0)).xyz;
                                }
                                else
                                {
                                    float3 _16980;
                                    if (_5934 == 8u)
                                    {
                                        _16980 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4561, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _16981;
                                        if (_5938)
                                        {
                                            uint _13424_dummy_parameter;
                                            uint _13456_dummy_parameter;
                                            _16981 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4561 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13424_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4561 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13456_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _16982;
                                            if (_5941)
                                            {
                                                _16982 = _7492;
                                            }
                                            else
                                            {
                                                float3 _16983;
                                                if (_5934 == 20u)
                                                {
                                                    _16983 = _7476;
                                                }
                                                else
                                                {
                                                    float3 _16984;
                                                    if (_5934 == 21u)
                                                    {
                                                        _16984 = _7484;
                                                    }
                                                    else
                                                    {
                                                        float3 _16985;
                                                        if (_5934 == 22u)
                                                        {
                                                            _16985 = _7500;
                                                        }
                                                        else
                                                        {
                                                            float3 _16986;
                                                            if (_5934 == 18u)
                                                            {
                                                                _16986 = _16516;
                                                            }
                                                            else
                                                            {
                                                                float3 _16987;
                                                                if (_5934 == 19u)
                                                                {
                                                                    _16987 = _16280;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _17230 = (_5934 == 23u).xxx;
                                                                    _16987 = float3(_17230.x ? _16050.x : _16990.x, _17230.y ? _16050.y : _16990.y, _17230.z ? _16050.z : _16990.z);
                                                                }
                                                                _16986 = _16987;
                                                            }
                                                            _16985 = _16986;
                                                        }
                                                        _16984 = _16985;
                                                    }
                                                    _16983 = _16984;
                                                }
                                                _16982 = _16983;
                                            }
                                            _16981 = _16982;
                                        }
                                        _16980 = _16981;
                                    }
                                    _16979 = _16980;
                                }
                                _16978 = _16979;
                            }
                            _16977 = _16978;
                        }
                        _16976 = _16977;
                    }
                    _16975 = _16976;
                }
                _16974 = _16975;
            }
            _16973 = _16974;
        }
        float3 _16972;
        if ((_5934 >= 9u) && (_5934 <= 11u))
        {
            uint _6440 = 64u + uint((_14349.y * cbFI_MvDepthLaneSize.x) + _14349.x);
            uint _6444 = rw_nfru_diagnostics.Load<uint>(_6440 * 4 + 0) & 15u;
            float3 _17004;
            if (_5934 == 10u)
            {
                float3 _16971;
                if ((rw_nfru_diagnostics.Load<uint>(_6440 * 4 + 0) & 32u) != 0u)
                {
                    _16971 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _16970;
                    if ((rw_nfru_diagnostics.Load<uint>(_6440 * 4 + 0) & 16u) != 0u)
                    {
                        _16970 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6465 = ((rw_nfru_diagnostics.Load<uint>(_6440 * 4 + 0) & 64u) != 0u).xxx;
                        _16970 = float3(_6465.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6465.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6465.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _16971 = _16970;
                }
                _17004 = _16971;
            }
            else
            {
                float3 _17005;
                if (_5934 == 11u)
                {
                    uint _6478 = (rw_nfru_diagnostics.Load<uint>(_6440 * 4 + 0) >> 8u) & 15u;
                    uint _6481 = (rw_nfru_diagnostics.Load<uint>(_6440 * 4 + 0) >> 12u) & 15u;
                    float3 _16963;
                    if ((_6444 == 2u) || (_6444 == 3u))
                    {
                        _16963 = _3783[_6444];
                    }
                    else
                    {
                        bool _6493 = _6478 == 3u;
                        bool _6495 = _6481 == 3u;
                        float3 _16964;
                        if (_6493 && _6495)
                        {
                            _16964 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _16965;
                            if (_6493)
                            {
                                _16965 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _16966;
                                if (_6495)
                                {
                                    _16966 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _16967;
                                    if ((_6478 == 4u) || (_6481 == 4u))
                                    {
                                        _16967 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _16968;
                                        if ((_6478 == 1u) || (_6481 == 1u))
                                        {
                                            _16968 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17232 = (_6444 == 1u).xxx;
                                            _16968 = float3(_17232.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17232.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17232.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _16967 = _16968;
                                    }
                                    _16966 = _16967;
                                }
                                _16965 = _16966;
                            }
                            _16964 = _16965;
                        }
                        _16963 = _16964;
                    }
                    _17005 = _16963;
                }
                else
                {
                    _17005 = _3783[min(_6444, 7u)];
                }
                _17004 = _17005;
            }
            _16972 = _17004;
        }
        else
        {
            _16972 = _16973;
        }
        float4 _17008;
        if ((_5934 >= 14u) && (_5934 <= 16u))
        {
            float2 _17006;
            if (_5934 == 14u)
            {
                uint _6551_dummy_parameter;
                uint _6557_dummy_parameter;
                _17006 = r_flow_tm1.Load(int3(clamp(int2(floor(_4561 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6551_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6557_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _17007;
                if (_5934 == 16u)
                {
                    uint _13507 = r_warped_flow_qdata_tm1.Load(int3(_4577, 0)).x & 2147483647u;
                    uint _13539 = uint(max((int((_13507 >> 16u) & 15u) - 6), 0));
                    _17007 = ((float2(float((1 - (2 * int((_13507 >> 15u) & 1u))) * int(((_13507 >> uint(7)) & 127u) << _13539)), float((1 - (2 * int((_13507 >> 14u) & 1u))) * int((_13507 & 127u) << _13539))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _17007 = _6771 * float2(cbFI_DisplaySize);
                }
                _17006 = _17007;
            }
            uint2 _6590 = uint2(clamp(round(_17006 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6592 = _6590.x;
            uint _6599 = _6590.y;
            _17008 = float4(float(_6592 & 255u), float((_6592 >> 8u) | ((_6599 & 15u) << 4u)), float(_6599 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _17009;
            if (_5934 == 17u)
            {
                _17009 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4577, 0)).x != 0u), _5021, 0.0f, 1.0f);
            }
            else
            {
                _17009 = float4(_16972, 1.0f);
            }
            _17008 = _17009;
        }
        rw_output[_4087] = _17008.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6643 = ((uint(_4087.y) * uint(cbFI_DisplaySize.x)) + uint(_4087.x)) * 6u;
            uint _13585 = spvPackHalf2x16(clamp(_7475.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6643 * 4 + 0, (((_13585 & 32767u) >> 4u) | ((((_13585 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7475.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13620 = spvPackHalf2x16(clamp(_7483.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6643 + 1u) * 4 + 0, (((_13620 & 32767u) >> 4u) | ((((_13620 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7483.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13655 = spvPackHalf2x16(clamp(_7491.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6643 + 2u) * 4 + 0, (((_13655 & 32767u) >> 4u) | ((((_13655 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7491.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13690 = spvPackHalf2x16(clamp(_7499.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6643 + 3u) * 4 + 0, (((_13690 & 32767u) >> 4u) | ((((_13690 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7499.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13717 = r_current_interpolation_source.Load(int3(_4087, 0));
            uint _13731 = spvPackHalf2x16(clamp(_13717.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6643 + 4u) * 4 + 0, (((_13731 & 32767u) >> 4u) | ((((_13731 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13717.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _17042;
            if (_16868 || (_5934 != 0u))
            {
                _17042 = 4294967295u;
            }
            else
            {
                uint _13766 = spvPackHalf2x16(clamp(_17008.xy, 0.0f.xx, 65000.0f.xx));
                _17042 = (((_13766 & 32767u) >> 4u) | ((((_13766 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_17008.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6643 + 5u) * 4 + 0, _17042);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4087] = float4(r_current_interpolation_source.Load(int3(_4087, 0)).xyz, 1.0f).xyz;
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
