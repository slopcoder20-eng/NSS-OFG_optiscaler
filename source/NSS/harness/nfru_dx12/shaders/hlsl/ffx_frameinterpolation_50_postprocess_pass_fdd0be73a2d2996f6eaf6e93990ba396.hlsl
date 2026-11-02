static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3303[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3590 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3590.x >= cbFI_DisplaySize.x, _3590.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3590] = float4(r_present_backbuffer.Load(int3(_3590, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3977 = (float2(_3590) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3988 = int2(floor(_3977 * float2(cbFI_MvDepthLaneSize)));
        int2 _3993 = int2(floor(_3977 * float2(cbFI_FlowLaneSize)));
        float4 _5901 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3977 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5907 = r_warped_filled_flow_tm1.Load(int3(_3993, 0)).xy;
        float2 _5913 = r_warped_filled_motion_tp1.Load(int3(_3988, 0)).xy;
        bool _5935 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9985;
        if (_5935)
        {
            float _5948 = ((2.0f * _3977.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9985 = float2(atan(_5948) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3977.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5948 * _5948))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9985 = _3977;
        }
        bool _4014 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10006;
        bool _10027;
        int2 _10038;
        float3 _11397;
        if (_4014)
        {
            float _9987;
            float _9989;
            _9989 = 2.0f;
            _9987 = -1.0f;
            uint _3652[9];
            float _11829;
            float _11832;
            for (int _9986 = 0; _9986 < 9; _9989 = _11832, _9987 = _11829, _9986++)
            {
                _3652[_9986] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3988 + int2((_9986 % 3) - 1, (_9986 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3652[_9986] != 0u)
                {
                    float _11824;
                    if (_3652[_9986] == 0u)
                    {
                        _11824 = -1.0f;
                    }
                    else
                    {
                        _11824 = float((_3652[_9986] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11832 = min(_9989, _11824);
                    _11829 = max(_9987, _11824);
                }
                else
                {
                    _11832 = _9989;
                    _11829 = _9987;
                }
            }
            float _4060 = float(_9987 >= 0.0f);
            float3 _9782 = 0.0f.xxx;
            _9782.y = _4060;
            float2 _10007;
            bool _10028;
            int2 _10039;
            float3 _11398;
            if ((_9987 - _9989) > 0.0199999995529651641845703125f)
            {
                float _9995;
                int2 _9996;
                float2 _9997;
                int2 _9999;
                float2 _10005;
                _10005 = _5913;
                _9999 = _3988;
                _9997 = _5913;
                _9996 = _3988;
                _9995 = -1.0f;
                float _11837;
                int2 _11841;
                float2 _11852;
                int2 _11863;
                float2 _11896;
                float _11943;
                int _9994 = 0;
                float _11805 = 1000000000.0f;
                for (; _9994 < 9; _11805 = _11943, _10005 = _11896, _9999 = _11863, _9997 = _11852, _9996 = _11841, _9995 = _11837, _9994++)
                {
                    if (_3652[_9994] == 0u)
                    {
                        _11943 = _11805;
                        _11896 = _10005;
                        _11863 = _9999;
                        _11852 = _9997;
                        _11841 = _9996;
                        _11837 = _9995;
                        continue;
                    }
                    int2 _4095 = clamp(_3988 + int2((_9994 % 3) - 1, (_9994 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6023 = _3652[_9994] & 2147483647u;
                    uint _6055 = uint(max((int((_6023 >> 16u) & 15u) - 6), 0));
                    float2 _4101 = (float2(float((1 - (2 * int((_6023 >> 15u) & 1u))) * int(((_6023 >> uint(7)) & 127u) << _6055)), float((1 - (2 * int((_6023 >> 14u) & 1u))) * int((_6023 & 127u) << _6055))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11791;
                    if (_3652[_9994] == 0u)
                    {
                        _11791 = -1.0f;
                    }
                    else
                    {
                        _11791 = float((_3652[_9994] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4106 = _11791 - 0.100000001490116119384765625f;
                    float2 _11792;
                    if (_5935)
                    {
                        float2 _6132 = clamp((((_9985 + (_4101 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6135 = tan(_6132.x);
                        _11792 = (float2(_6135 / cbFI_DeviceToViewDepth.z, (tan(_6132.y) * sqrt(1.0f + (_6135 * _6135))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11792 = _9985 + (_4101 * cbFI_Timestep);
                    }
                    float _4113 = cbFI_Timestep - 1.0f;
                    float2 _11793;
                    if (_5935)
                    {
                        float2 _6203 = clamp((((_9985 + (_4101 * _4113)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6206 = tan(_6203.x);
                        _11793 = (float2(_6206 / cbFI_DeviceToViewDepth.z, (tan(_6203.y) * sqrt(1.0f + (_6206 * _6206))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11793 = _9985 + (_4101 * _4113);
                    }
                    bool _6239 = all(bool2(_11792.x > 0.0f.xx.x, _11792.y > 0.0f.xx.y));
                    bool _6245;
                    if (_6239)
                    {
                        _6245 = all(bool2(_11792.x < 1.0f.xx.x, _11792.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6245 = _6239;
                    }
                    float _11796;
                    if (_6245)
                    {
                        uint _6252_dummy_parameter;
                        _11796 = max((_4106 - (log((r_depth_tm1.Load(int3(int2(floor(_11792 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6252_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11796 = 0.0f;
                    }
                    bool _6282 = all(bool2(_11793.x > 0.0f.xx.x, _11793.y > 0.0f.xx.y));
                    bool _6288;
                    if (_6282)
                    {
                        _6288 = all(bool2(_11793.x < 1.0f.xx.x, _11793.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6288 = _6282;
                    }
                    float _11797;
                    if (_6288)
                    {
                        uint _6295_dummy_parameter;
                        _11797 = _11796 + max((_4106 - (log((r_depth_tp1.Load(int3(int2(floor(_11793 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6295_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11797 = _11796;
                    }
                    float _11838;
                    int2 _11842;
                    float2 _11853;
                    int2 _11864;
                    float2 _11897;
                    float _11944;
                    if (_11797 == 0.0f)
                    {
                        bool _4148 = _4106 > _9995;
                        bool2 _11952 = _4148.xx;
                        _11944 = _11805;
                        _11897 = float2(_11952.x ? _4101.x : _10005.x, _11952.y ? _4101.y : _10005.y);
                        _11864 = int2(_11952.x ? _4095.x : _9999.x, _11952.y ? _4095.y : _9999.y);
                        _11853 = _9997;
                        _11842 = _9996;
                        _11838 = _4148 ? _4106 : _9995;
                    }
                    else
                    {
                        bool _4157 = _11797 < _11805;
                        bool2 _11948 = _4157.xx;
                        _11944 = _4157 ? _11797 : _11805;
                        _11897 = _10005;
                        _11864 = _9999;
                        _11853 = float2(_11948.x ? _4101.x : _9997.x, _11948.y ? _4101.y : _9997.y);
                        _11842 = int2(_11948.x ? _4095.x : _9996.x, _11948.y ? _4095.y : _9996.y);
                        _11838 = _9995;
                    }
                    _11943 = _11944;
                    _11896 = _11897;
                    _11863 = _11864;
                    _11852 = _11853;
                    _11841 = _11842;
                    _11837 = _11838;
                }
                bool _4169 = _9995 < 0.0f;
                bool2 _11958 = _4169.xx;
                int2 _11961 = int2(_11958.x ? _9996.x : _9999.x, _11958.y ? _9996.y : _9999.y);
                _11398 = float3(1.0f, _4060, float(any(bool2(_11961.x != _3988.x, _11961.y != _3988.y))));
                _10039 = _11961;
                _10028 = _4169 ? false : true;
                _10007 = float2(_11958.x ? _9997.x : _10005.x, _11958.y ? _9997.y : _10005.y);
            }
            else
            {
                _11398 = _9782;
                _10039 = _3988;
                _10028 = false;
                _10007 = _5913;
            }
            _11397 = _11398;
            _10038 = _10039;
            _10027 = _10028;
            _10006 = _10007;
        }
        else
        {
            _11397 = 0.0f.xxx;
            _10038 = _3988;
            _10027 = false;
            _10006 = _5913;
        }
        float2 _10008;
        if (_5935)
        {
            float2 _6360 = clamp((((_9985 + (_10006 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6363 = tan(_6360.x);
            _10008 = (float2(_6363 / cbFI_DeviceToViewDepth.z, (tan(_6360.y) * sqrt(1.0f + (_6363 * _6363))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10008 = _9985 + (_10006 * cbFI_Timestep);
        }
        float _4192 = cbFI_Timestep - 1.0f;
        float2 _10010;
        if (_5935)
        {
            float2 _6431 = clamp((((_9985 + (_10006 * _4192)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6434 = tan(_6431.x);
            _10010 = (float2(_6434 / cbFI_DeviceToViewDepth.z, (tan(_6431.y) * sqrt(1.0f + (_6434 * _6434))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10010 = _9985 + (_10006 * _4192);
        }
        float _4197 = -cbFI_Timestep;
        float2 _10011;
        if (_5935)
        {
            float2 _6502 = clamp((((_9985 + (_5907 * _4197)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6505 = tan(_6502.x);
            _10011 = (float2(_6505 / cbFI_DeviceToViewDepth.z, (tan(_6502.y) * sqrt(1.0f + (_6505 * _6505))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10011 = _9985 + (_5907 * _4197);
        }
        float _4202 = 1.0f - cbFI_Timestep;
        float2 _10012;
        if (_5935)
        {
            float2 _6573 = clamp((((_9985 + (_5907 * _4202)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6576 = tan(_6573.x);
            _10012 = (float2(_6576 / cbFI_DeviceToViewDepth.z, (tan(_6573.y) * sqrt(1.0f + (_6576 * _6576))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10012 = _9985 + (_5907 * _4202);
        }
        float4 _6611 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10008, 0.0f);
        float3 _6612 = _6611.xyz;
        float4 _6619 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10010, 0.0f);
        float3 _6620 = _6619.xyz;
        float4 _6627 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10011, 0.0f);
        float3 _6628 = _6627.xyz;
        float4 _6635 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10012, 0.0f);
        float3 _6636 = _6635.xyz;
        float4 _6650 = exp(_5901 - max(max(max(_5901.x, _5901.y), _5901.z), _5901.w).xxxx);
        float4 _6657 = _6650 / (dot(_6650, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4221 = _4014 && (!_10027);
        bool _4230;
        if (_4221)
        {
            _4230 = (_6657.z + _6657.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4230 = _4221;
        }
        bool _4241;
        if (_4230)
        {
            _4241 = length((_10011 - _10008) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4241 = _4230;
        }
        bool _10051;
        if (_4241)
        {
            uint4 _6676 = r_warped_motion_qdata_tp1.Load(int3(_10038, 0));
            uint _6677 = _6676.x;
            bool _10054;
            if (_6677 != 0u)
            {
                float _10040;
                if (_6677 == 0u)
                {
                    _10040 = -1.0f;
                }
                else
                {
                    _10040 = float((_6677 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4251 = _10040 - 0.12000000476837158203125f;
                bool _6696 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
                bool _6702;
                if (_6696)
                {
                    _6702 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
                }
                else
                {
                    _6702 = _6696;
                }
                bool _4261;
                if (_6702)
                {
                    uint _6709_dummy_parameter;
                    _4261 = (log((r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6709_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4251;
                }
                else
                {
                    _4261 = _6702;
                }
                bool _4275;
                if (!_4261)
                {
                    bool _6739 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
                    bool _6745;
                    if (_6739)
                    {
                        _6745 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6745 = _6739;
                    }
                    bool _4273;
                    if (_6745)
                    {
                        uint _6752_dummy_parameter;
                        _4273 = (log((r_depth_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6752_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4251;
                    }
                    else
                    {
                        _4273 = _6745;
                    }
                    _4275 = _4273;
                }
                else
                {
                    _4275 = _4261;
                }
                _10054 = _4275;
            }
            else
            {
                _10054 = false;
            }
            _10051 = _10054;
        }
        else
        {
            _10051 = false;
        }
        bool _4280 = _10027 || _10051;
        bool _4285;
        if (_4280)
        {
            bool _6782 = all(bool2(_10008.x > 0.0f.xx.x, _10008.y > 0.0f.xx.y));
            bool _6788;
            if (_6782)
            {
                _6788 = all(bool2(_10008.x < 1.0f.xx.x, _10008.y < 1.0f.xx.y));
            }
            else
            {
                _6788 = _6782;
            }
            _4285 = _6788;
        }
        else
        {
            _4285 = _4280;
        }
        bool _4290;
        if (_4285)
        {
            bool _6793 = all(bool2(_10010.x > 0.0f.xx.x, _10010.y > 0.0f.xx.y));
            bool _6799;
            if (_6793)
            {
                _6799 = all(bool2(_10010.x < 1.0f.xx.x, _10010.y < 1.0f.xx.y));
            }
            else
            {
                _6799 = _6793;
            }
            _4290 = _6799;
        }
        else
        {
            _4290 = _4285;
        }
        float4 _10148;
        if (_4290)
        {
            float _4293 = _6657.x;
            float _4295 = _6657.y;
            float _4296 = _4293 + _4295;
            float _4301 = _6657.z + _6657.w;
            float _10069;
            if (_4296 > 0.001000000047497451305389404296875f)
            {
                _10069 = _4293 / _4296;
            }
            else
            {
                _10069 = _4202;
            }
            _10148 = float4(_4293 + (_4301 * _10069), _4295 + (_4301 * (1.0f - _10069)), 0.0f, 0.0f);
        }
        else
        {
            _10148 = _6657;
        }
        bool _6827 = (cbFI_pad0 & 1024u) != 0u;
        bool _6803 = !_6827;
        bool _6804 = !_6803;
        bool _6821;
        if (_6804)
        {
            _6821 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10038.y * cbFI_MvDepthLaneSize.x) + _10038.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6821 = _6803;
        }
        bool _6853;
        if (_6804)
        {
            _6853 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3993.y * cbFI_FlowLaneSize.x) + _3993.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6853 = _6803;
        }
        float _4336 = float(_6853);
        bool _10161;
        float4 _10192;
        float3 _11211;
        if (_6827)
        {
            bool _4346;
            if (_6821)
            {
                _4346 = all(bool2(_10008.x > 0.0f.xx.x, _10008.y > 0.0f.xx.y));
            }
            else
            {
                _4346 = _6821;
            }
            bool _4352;
            if (_4346)
            {
                _4352 = all(bool2(_10008.x < 1.0f.xx.x, _10008.y < 1.0f.xx.y));
            }
            else
            {
                _4352 = _4346;
            }
            bool _4359;
            if (_6821)
            {
                _4359 = all(bool2(_10010.x > 0.0f.xx.x, _10010.y > 0.0f.xx.y));
            }
            else
            {
                _4359 = _6821;
            }
            bool _4365;
            if (_4359)
            {
                _4365 = all(bool2(_10010.x < 1.0f.xx.x, _10010.y < 1.0f.xx.y));
            }
            else
            {
                _4365 = _4359;
            }
            bool _4372;
            if (_6853)
            {
                _4372 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
            }
            else
            {
                _4372 = _6853;
            }
            bool _4378;
            if (_4372)
            {
                _4378 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
            }
            else
            {
                _4378 = _4372;
            }
            bool _4385;
            if (_6853)
            {
                _4385 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
            }
            else
            {
                _4385 = _6853;
            }
            bool _4391;
            if (_4385)
            {
                _4391 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
            }
            else
            {
                _4391 = _4385;
            }
            bool _4393 = !_6821;
            if (_4393)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6895;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6895);
                }
            }
            bool _4398 = !_6853;
            if (_4398)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6905;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6905);
                }
            }
            if (_6821 && _4398)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6915;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6915);
                }
            }
            if (_4393 && _6853)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6925;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6925);
                }
            }
            float _4417 = float(_4352);
            float _4419 = float(_4365);
            bool _4422 = _4378 && _4391;
            float _10103;
            if (_4422)
            {
                _10103 = 1.0f;
            }
            else
            {
                _10103 = (_4378 || _4391) ? 0.5f : 0.0f;
            }
            bool _10108;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4352)) && (!_4365))
            {
                bool _4452;
                if (_4422)
                {
                    float _10106;
                    do
                    {
                        bool _7009 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
                        bool _7015;
                        if (_7009)
                        {
                            _7015 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7015 = _7009;
                        }
                        bool _6946 = !_7015;
                        bool _6953;
                        if (!_6946)
                        {
                            bool _7020 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
                            bool _7026;
                            if (_7020)
                            {
                                _7026 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7026 = _7020;
                            }
                            _6953 = !_7026;
                        }
                        else
                        {
                            _6953 = _6946;
                        }
                        if (_6953)
                        {
                            _10106 = 0.0f;
                            break;
                        }
                        uint _7033_dummy_parameter;
                        uint _7049_dummy_parameter;
                        float4 _6974 = mul(float4((float2(_10011.x, 1.0f - _10011.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7033_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6976 = _6974.w;
                        if (abs(_6976) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10106 = 0.0f;
                            break;
                        }
                        float _6987 = abs(cbFI_DeviceToViewDepth.y / ((_6974.z / _6976) - cbFI_DeviceToViewDepth.x));
                        float _6990 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7049_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10106 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6987 - _6990) / max(max(_6987, _6990), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4452 = _10106 >= 0.5f;
                }
                else
                {
                    _4452 = _4422;
                }
                bool _4460;
                if (_4452)
                {
                    _4460 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4460 = _4452;
                }
                bool _10109;
                if (_4460)
                {
                    uint _7099_dummy_parameter;
                    float2 _10107;
                    do
                    {
                        float _7125 = 1.0f - _10011.y;
                        float4 _7136 = mul(float4((float2(_10011.x, _7125) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7099_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7138 = _7136.w;
                        if (!(_7138 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10107 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7151 = ((_7136.xy / _7138.xx) + 1.0f.xx) * 0.5f;
                        _10107 = float2(_7151.x - _10011.x, _7125 - _7151.y);
                        break;
                    } while(false);
                    float2 _4473 = float2(cbFI_DisplaySize);
                    _10109 = length(((_10011 + _10107) - _10012) * _4473) <= ((0.100000001490116119384765625f * length(_10107 * _4473)) + 8.0f);
                }
                else
                {
                    _10109 = _4452;
                }
                _10108 = _10109;
            }
            else
            {
                _10108 = true;
            }
            bool _4487 = !_10108;
            bool _11962 = _4487 ? false : _4391;
            bool _11963 = _4487 ? false : _4378;
            bool _10162;
            float4 _10193;
            if (!(((_4352 && _4365) && _11963) && _11962))
            {
                float4 _4509 = _10148 * float4(_4417, _4419, float(_11963), float(_11962));
                float _4511 = dot(_4509, 1.0f.xxxx);
                bool _4514 = !(_4511 > 0.0f);
                float4 _10194;
                if (!_4514)
                {
                    _10194 = _4509 / _4511.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7173;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7173);
                    }
                    _10194 = 0.0f.xxxx;
                }
                _10193 = _10194;
                _10162 = _4514;
            }
            else
            {
                _10193 = _10148;
                _10162 = false;
            }
            _11211 = float3(_4417, _4419, _10103);
            _10192 = _10193;
            _10161 = _10162;
        }
        else
        {
            _11211 = float3(float(_6821), _4336, 0.0f);
            _10192 = _10148;
            _10161 = false;
        }
        bool _4532 = !_10161;
        float4 _10254;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4532)
        {
            float _4539 = _10192.x + _10192.y;
            float4 _10255;
            if (_4539 > 0.001000000047497451305389404296875f)
            {
                _10255 = float4(_10192.x / _4539, _10192.y / _4539, 0.0f, 0.0f);
            }
            else
            {
                _10255 = float4(_4202, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10254 = _10255;
        }
        else
        {
            _10254 = _10192;
        }
        float4 _10350;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4532) && _6821)
        {
            float _10251;
            do
            {
                uint4 _7313 = r_warped_motion_qdata_tp1.Load(int3(_10038, 0));
                uint _7314 = _7313.x;
                if (_7314 != 0u)
                {
                    float _10250;
                    if (_7314 == 0u)
                    {
                        _10250 = -1.0f;
                    }
                    else
                    {
                        _10250 = float((_7314 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10251 = _10250;
                    break;
                }
                int _10233;
                uint _10234;
                _10234 = _7314;
                _10233 = -1;
                uint _10249;
                for (; _10233 <= 1; _10234 = _10249, _10233++)
                {
                    _10249 = _10234;
                    for (int _10247 = -1; _10247 <= 1; )
                    {
                        _10249 = max(_10249, r_warped_motion_qdata_tp1.Load(int3(clamp(_10038 + int2(_10247, _10233), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10247++;
                        continue;
                    }
                }
                if (_10234 != 0u)
                {
                    float _10246;
                    if (_10234 == 0u)
                    {
                        _10246 = -1.0f;
                    }
                    else
                    {
                        _10246 = float((_10234 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10251 = _10246;
                    break;
                }
                uint _10236;
                _10236 = 4294967295u;
                uint _11933;
                for (int _10235 = 0; _10235 < 8; _10236 = _11933, _10235++)
                {
                    int _10239 = 0;
                    for (;;)
                    {
                        if (_10239 < 5)
                        {
                            int2 _7264 = _10038 + (_1085[_10235] * _1094[_10239].xx);
                            bool _7267 = any(bool2(_7264.x < int2(0, 0).x, _7264.y < int2(0, 0).y));
                            bool _7275;
                            if (!_7267)
                            {
                                _7275 = any(bool2(_7264.x >= cbFI_MvDepthLaneSize.x, _7264.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7275 = _7267;
                            }
                            if (_7275)
                            {
                                _11933 = _10236;
                                break;
                            }
                            uint4 _7353 = r_warped_motion_qdata_tp1.Load(int3(_7264, 0));
                            uint _7354 = _7353.x;
                            if (_7354 != 0u)
                            {
                                _11933 = min(_10236, _7354);
                                break;
                            }
                            _10239++;
                            continue;
                        }
                        else
                        {
                            _11933 = _10236;
                            break;
                        }
                    }
                }
                float _10238;
                if (_10236 == 4294967295u)
                {
                    _10238 = -1.0f;
                }
                else
                {
                    float _10237;
                    if (_10236 == 0u)
                    {
                        _10237 = -1.0f;
                    }
                    else
                    {
                        _10237 = float((_10236 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10238 = _10237;
                }
                _10251 = _10238;
                break;
            } while(false);
            float _4575 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4579 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4585;
            if (_4579)
            {
                _4585 = _10254.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4585 = _4579;
            }
            bool _4590;
            if (_4585)
            {
                bool _7373 = all(bool2(_10010.x > 0.0f.xx.x, _10010.y > 0.0f.xx.y));
                bool _7379;
                if (_7373)
                {
                    _7379 = all(bool2(_10010.x < 1.0f.xx.x, _10010.y < 1.0f.xx.y));
                }
                else
                {
                    _7379 = _7373;
                }
                _4590 = _7379;
            }
            else
            {
                _4590 = _4585;
            }
            float4 _10295;
            if (_4590)
            {
                float _10270;
                if (_10251 >= 0.0f)
                {
                    _10270 = _10251 - _4575;
                }
                else
                {
                    float _10266;
                    _10266 = 2.0f;
                    float _7436;
                    for (int _10265 = 0; _10265 < 24; _10266 = _7436, _10265++)
                    {
                        float _7400 = float(_10265 & 7) * 0.785398185253143310546875f;
                        int _7402 = _10265 >> 3;
                        int _10267;
                        if (_7402 == 0)
                        {
                            _10267 = 16;
                        }
                        else
                        {
                            _10267 = (_7402 == 1) ? 48 : 96;
                        }
                        uint _7468_dummy_parameter;
                        _7436 = min(_10266, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10010 + ((cbFI_MvDepthLaneSizeRcp * float(_10267)) * float2(cos(_7400), sin(_7400))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7468_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10270 = _10266;
                }
                uint _7500_dummy_parameter;
                float4 _10296;
                if (r_depth_tp1.Load(int3(int2(floor(_10010 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7500_dummy_parameter))))), 0)).x > ((exp((_10270 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10296 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10296 = 1.0f.xxxx;
                }
                _10295 = _10296;
            }
            else
            {
                _10295 = 1.0f.xxxx;
            }
            bool _4617 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4623;
            if (_4617)
            {
                _4623 = _10254.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4623 = _4617;
            }
            bool _4628;
            if (_4623)
            {
                bool _7524 = all(bool2(_10008.x > 0.0f.xx.x, _10008.y > 0.0f.xx.y));
                bool _7530;
                if (_7524)
                {
                    _7530 = all(bool2(_10008.x < 1.0f.xx.x, _10008.y < 1.0f.xx.y));
                }
                else
                {
                    _7530 = _7524;
                }
                _4628 = _7530;
            }
            else
            {
                _4628 = _4623;
            }
            float4 _10299;
            if (_4628)
            {
                float _10290;
                if (_10251 >= 0.0f)
                {
                    _10290 = _10251 - _4575;
                }
                else
                {
                    float _10286;
                    _10286 = 2.0f;
                    float _7587;
                    for (int _10285 = 0; _10285 < 24; _10286 = _7587, _10285++)
                    {
                        float _7551 = float(_10285 & 7) * 0.785398185253143310546875f;
                        int _7553 = _10285 >> 3;
                        int _10287;
                        if (_7553 == 0)
                        {
                            _10287 = 16;
                        }
                        else
                        {
                            _10287 = (_7553 == 1) ? 48 : 96;
                        }
                        uint _7603_dummy_parameter;
                        _7587 = min(_10286, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10008 + ((cbFI_MvDepthLaneSizeRcp * float(_10287)) * float2(cos(_7551), sin(_7551))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7603_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10290 = _10286;
                }
                uint _7651_dummy_parameter;
                float4 _10300;
                if (r_depth_tm1.Load(int3(int2(floor(_10008 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7651_dummy_parameter))))), 0)).x > ((exp((_10290 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9854 = _10295;
                    _9854.x = 0.0f;
                    _10300 = _9854;
                }
                else
                {
                    _10300 = _10295;
                }
                _10299 = _10300;
            }
            else
            {
                _10299 = _10295;
            }
            float4 _10351;
            if (any(bool4(_10299.x < 1.0f.xxxx.x, _10299.y < 1.0f.xxxx.y, _10299.z < 1.0f.xxxx.z, _10299.w < 1.0f.xxxx.w)))
            {
                float4 _4658 = _10254 * _10299;
                float _4660 = dot(_4658, 1.0f.xxxx);
                float4 _10352;
                if (_4660 > 0.0f)
                {
                    _10352 = _4658 / _4660.xxxx;
                }
                else
                {
                    bool _4671 = _10299.y == 0.0f;
                    bool _4677;
                    if (_4671)
                    {
                        _4677 = _10299.x > 0.0f;
                    }
                    else
                    {
                        _4677 = _4671;
                    }
                    bool _4682;
                    if (_4677)
                    {
                        bool _7675 = all(bool2(_10008.x > 0.0f.xx.x, _10008.y > 0.0f.xx.y));
                        bool _7681;
                        if (_7675)
                        {
                            _7681 = all(bool2(_10008.x < 1.0f.xx.x, _10008.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7681 = _7675;
                        }
                        _4682 = _7681;
                    }
                    else
                    {
                        _4682 = _4677;
                    }
                    float4 _10353;
                    if (_4682)
                    {
                        _10353 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4687 = _10299.x == 0.0f;
                        bool _4693;
                        if (_4687)
                        {
                            _4693 = _10299.y > 0.0f;
                        }
                        else
                        {
                            _4693 = _4687;
                        }
                        bool _4698;
                        if (_4693)
                        {
                            bool _7686 = all(bool2(_10010.x > 0.0f.xx.x, _10010.y > 0.0f.xx.y));
                            bool _7692;
                            if (_7686)
                            {
                                _7692 = all(bool2(_10010.x < 1.0f.xx.x, _10010.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7692 = _7686;
                            }
                            _4698 = _7692;
                        }
                        else
                        {
                            _4698 = _4693;
                        }
                        bool4 _11964 = _4698.xxxx;
                        _10353 = float4(_11964.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10254.x, _11964.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10254.y, _11964.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10254.z, _11964.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10254.w);
                    }
                    _10352 = _10353;
                }
                _10351 = _10352;
            }
            else
            {
                _10351 = _10254;
            }
            _10350 = _10351;
        }
        else
        {
            _10350 = _10254;
        }
        float4 _10896;
        bool _10916;
        float3 _11030;
        if (((cbFI_pad0 & 32768u) != 0u) && _4532)
        {
            bool _4715 = _10350.x > 0.00999999977648258209228515625f;
            bool _4718 = _10350.y > 0.00999999977648258209228515625f;
            bool _4727 = (_10350.z + _10350.w) > 0.0199999995529651641845703125f;
            bool _4733;
            if (_4727)
            {
                bool _7697 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
                bool _7703;
                if (_7697)
                {
                    _7703 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
                }
                else
                {
                    _7703 = _7697;
                }
                _4733 = _7703;
            }
            else
            {
                _4733 = _4727;
            }
            bool _4738;
            if (_4733)
            {
                bool _7708 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
                bool _7714;
                if (_7708)
                {
                    _7714 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
                }
                else
                {
                    _7714 = _7708;
                }
                _4738 = _7714;
            }
            else
            {
                _4738 = _4733;
            }
            bool _4745;
            if (_4738)
            {
                float _10361;
                do
                {
                    bool _7797 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
                    bool _7803;
                    if (_7797)
                    {
                        _7803 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7803 = _7797;
                    }
                    bool _7734 = !_7803;
                    bool _7741;
                    if (!_7734)
                    {
                        bool _7808 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
                        bool _7814;
                        if (_7808)
                        {
                            _7814 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7814 = _7808;
                        }
                        _7741 = !_7814;
                    }
                    else
                    {
                        _7741 = _7734;
                    }
                    if (_7741)
                    {
                        _10361 = 0.0f;
                        break;
                    }
                    uint _7821_dummy_parameter;
                    uint _7837_dummy_parameter;
                    float4 _7762 = mul(float4((float2(_10011.x, 1.0f - _10011.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7821_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7764 = _7762.w;
                    if (abs(_7764) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10361 = 0.0f;
                        break;
                    }
                    float _7775 = abs(cbFI_DeviceToViewDepth.y / ((_7762.z / _7764) - cbFI_DeviceToViewDepth.x));
                    float _7778 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7837_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10361 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7775 - _7778) / max(max(_7775, _7778), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4745 = _10361 < 0.5f;
            }
            else
            {
                _4745 = _4738;
            }
            float4 _10376;
            if (_4745)
            {
                uint _7887_dummy_parameter;
                uint _7918_dummy_parameter;
                float4 _10377;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7887_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7918_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10377 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10377 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10376 = _10377;
            }
            else
            {
                _10376 = 1.0f.xxxx;
            }
            bool _4769;
            if (_6821)
            {
                bool _7947 = all(bool2(_10008.x > 0.0f.xx.x, _10008.y > 0.0f.xx.y));
                bool _7953;
                if (_7947)
                {
                    _7953 = all(bool2(_10008.x < 1.0f.xx.x, _10008.y < 1.0f.xx.y));
                }
                else
                {
                    _7953 = _7947;
                }
                _4769 = _7953;
            }
            else
            {
                _4769 = _6821;
            }
            bool _4775;
            if (_6821)
            {
                bool _7958 = all(bool2(_10010.x > 0.0f.xx.x, _10010.y > 0.0f.xx.y));
                bool _7964;
                if (_7958)
                {
                    _7964 = all(bool2(_10010.x < 1.0f.xx.x, _10010.y < 1.0f.xx.y));
                }
                else
                {
                    _7964 = _7958;
                }
                _4775 = _7964;
            }
            else
            {
                _4775 = _6821;
            }
            bool _4781;
            if (_6853)
            {
                bool _7969 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
                bool _7975;
                if (_7969)
                {
                    _7975 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
                }
                else
                {
                    _7975 = _7969;
                }
                _4781 = _7975;
            }
            else
            {
                _4781 = _6853;
            }
            bool _4787;
            if (_6853)
            {
                bool _7980 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
                bool _7986;
                if (_7980)
                {
                    _7986 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
                }
                else
                {
                    _7986 = _7980;
                }
                _4787 = _7986;
            }
            else
            {
                _4787 = _6853;
            }
            bool _4790 = _4781 != _4787;
            bool _4796;
            if (_4790)
            {
                _4796 = _4769 || _4775;
            }
            else
            {
                _4796 = _4790;
            }
            float4 _10464;
            if (_4796)
            {
                float4 _9881 = _10376;
                _9881.z = 0.0f;
                _9881.w = 0.0f;
                _10464 = _9881;
            }
            else
            {
                _10464 = _10376;
            }
            bool _4803 = _4769 && _4715;
            bool _4806 = _4775 && _4718;
            float4 _10569;
            float3 _11109;
            if (_4803 || _4806)
            {
                float _10459;
                do
                {
                    uint4 _8125 = r_warped_motion_qdata_tp1.Load(int3(_10038, 0));
                    uint _8126 = _8125.x;
                    if (_8126 != 0u)
                    {
                        float _10458;
                        if (_8126 == 0u)
                        {
                            _10458 = -1.0f;
                        }
                        else
                        {
                            _10458 = float((_8126 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10459 = _10458;
                        break;
                    }
                    int _10441;
                    uint _10442;
                    _10442 = _8126;
                    _10441 = -1;
                    uint _10457;
                    for (; _10441 <= 1; _10442 = _10457, _10441++)
                    {
                        _10457 = _10442;
                        for (int _10455 = -1; _10455 <= 1; )
                        {
                            _10457 = max(_10457, r_warped_motion_qdata_tp1.Load(int3(clamp(_10038 + int2(_10455, _10441), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10455++;
                            continue;
                        }
                    }
                    if (_10442 != 0u)
                    {
                        float _10454;
                        if (_10442 == 0u)
                        {
                            _10454 = -1.0f;
                        }
                        else
                        {
                            _10454 = float((_10442 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10459 = _10454;
                        break;
                    }
                    uint _10444;
                    _10444 = 4294967295u;
                    uint _11934;
                    for (int _10443 = 0; _10443 < 8; _10444 = _11934, _10443++)
                    {
                        int _10447 = 0;
                        for (;;)
                        {
                            if (_10447 < 5)
                            {
                                int2 _8076 = _10038 + (_1085[_10443] * _1094[_10447].xx);
                                bool _8079 = any(bool2(_8076.x < int2(0, 0).x, _8076.y < int2(0, 0).y));
                                bool _8087;
                                if (!_8079)
                                {
                                    _8087 = any(bool2(_8076.x >= cbFI_MvDepthLaneSize.x, _8076.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8087 = _8079;
                                }
                                if (_8087)
                                {
                                    _11934 = _10444;
                                    break;
                                }
                                uint4 _8165 = r_warped_motion_qdata_tp1.Load(int3(_8076, 0));
                                uint _8166 = _8165.x;
                                if (_8166 != 0u)
                                {
                                    _11934 = min(_10444, _8166);
                                    break;
                                }
                                _10447++;
                                continue;
                            }
                            else
                            {
                                _11934 = _10444;
                                break;
                            }
                        }
                    }
                    float _10446;
                    if (_10444 == 4294967295u)
                    {
                        _10446 = -1.0f;
                    }
                    else
                    {
                        float _10445;
                        if (_10444 == 0u)
                        {
                            _10445 = -1.0f;
                        }
                        else
                        {
                            _10445 = float((_10444 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10446 = _10445;
                    }
                    _10459 = _10446;
                    break;
                } while(false);
                bool _4814 = _10459 < 0.0f;
                float _10460;
                if (_4814)
                {
                    _10460 = 0.0f;
                }
                else
                {
                    _10460 = _10459 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8187_dummy_parameter;
                uint _8219_dummy_parameter;
                float4 _10497;
                if ((_4814 && _4803) && _4806)
                {
                    uint _8251_dummy_parameter;
                    float _8275 = log((r_depth_tm1.Load(int3(int2(floor(_10008 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8251_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8283_dummy_parameter;
                    float _8307 = log((r_depth_tp1.Load(int3(int2(floor(_10010 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8283_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10498;
                    if (_8275 > (_8307 + 0.07999999821186065673828125f))
                    {
                        float4 _9885 = _10464;
                        _9885.x = 0.0f;
                        _10498 = _9885;
                    }
                    else
                    {
                        float4 _10499;
                        if (_8307 > (_8275 + 0.07999999821186065673828125f))
                        {
                            float4 _9887 = _10464;
                            _9887.y = 0.0f;
                            _10499 = _9887;
                        }
                        else
                        {
                            _10499 = _10464;
                        }
                        _10498 = _10499;
                    }
                    _10497 = _10498;
                }
                else
                {
                    _10497 = _10464;
                }
                float _4866 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4868 = _10459 >= 0.0f;
                float _10480;
                if (_4868)
                {
                    _10480 = _10459 - _4866;
                }
                else
                {
                    float _10476;
                    if (_4803)
                    {
                        float _10475;
                        _10475 = 2.0f;
                        float _8365;
                        for (int _10474 = 0; _10474 < 24; _10475 = _8365, _10474++)
                        {
                            float _8329 = float(_10474 & 7) * 0.785398185253143310546875f;
                            int _8331 = _10474 >> 3;
                            int _10477;
                            if (_8331 == 0)
                            {
                                _10477 = 16;
                            }
                            else
                            {
                                _10477 = (_8331 == 1) ? 48 : 96;
                            }
                            uint _8381_dummy_parameter;
                            _8365 = min(_10475, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10008 + ((cbFI_MvDepthLaneSizeRcp * float(_10477)) * float2(cos(_8329), sin(_8329))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8381_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10476 = _10475;
                    }
                    else
                    {
                        _10476 = 0.0f;
                    }
                    _10480 = _10476;
                }
                float _10487;
                if (_4868)
                {
                    _10487 = _10459 - _4866;
                }
                else
                {
                    float _10483;
                    if (_4806)
                    {
                        float _10482;
                        _10482 = 2.0f;
                        float _8479;
                        for (int _10481 = 0; _10481 < 24; _10482 = _8479, _10481++)
                        {
                            float _8443 = float(_10481 & 7) * 0.785398185253143310546875f;
                            int _8445 = _10481 >> 3;
                            int _10484;
                            if (_8445 == 0)
                            {
                                _10484 = 16;
                            }
                            else
                            {
                                _10484 = (_8445 == 1) ? 48 : 96;
                            }
                            uint _8511_dummy_parameter;
                            _8479 = min(_10482, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10010 + ((cbFI_MvDepthLaneSizeRcp * float(_10484)) * float2(cos(_8443), sin(_8443))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8511_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10483 = _10482;
                    }
                    else
                    {
                        _10483 = 0.0f;
                    }
                    _10487 = _10483;
                }
                float _10488;
                if (_4803)
                {
                    uint _8543_dummy_parameter;
                    _10488 = r_depth_tm1.Load(int3(int2(floor(_10008 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8543_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10488 = 0.0f;
                }
                float _10489;
                if (_4806)
                {
                    uint _8562_dummy_parameter;
                    _10489 = r_depth_tp1.Load(int3(int2(floor(_10010 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8562_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10489 = 0.0f;
                }
                bool _4923;
                if (_4803)
                {
                    _4923 = _10488 > ((exp((_10480 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4923 = _4803;
                }
                float4 _10505;
                if (_4923)
                {
                    float4 _9889 = _10497;
                    _9889.x = 0.0f;
                    _10505 = _9889;
                }
                else
                {
                    _10505 = _10497;
                }
                bool _4935;
                if (_4806)
                {
                    _4935 = _10489 > ((exp((_10487 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4935 = _4806;
                }
                float4 _10507;
                if (_4935)
                {
                    float4 _9891 = _10505;
                    _9891.y = 0.0f;
                    _10507 = _9891;
                }
                else
                {
                    _10507 = _10505;
                }
                float4 _10570;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4868)
                {
                    bool _4955;
                    if (_4803)
                    {
                        _4955 = _10488 < ((exp((_10480 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4955 = _4803;
                    }
                    float4 _10509;
                    if (_4955)
                    {
                        float4 _9893 = _10507;
                        _9893.x = 0.0f;
                        _10509 = _9893;
                    }
                    else
                    {
                        _10509 = _10507;
                    }
                    bool _4967;
                    if (_4806)
                    {
                        _4967 = _10489 < ((exp((_10487 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4967 = _4806;
                    }
                    float4 _10571;
                    if (_4967)
                    {
                        float4 _9895 = _10509;
                        _9895.y = 0.0f;
                        _10571 = _9895;
                    }
                    else
                    {
                        _10571 = _10509;
                    }
                    _10570 = _10571;
                }
                else
                {
                    _10570 = _10507;
                }
                _11109 = float3(_10460, log((r_depth_tm1.Load(int3(int2(floor(_10008 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8187_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10010 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8219_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10569 = _10570;
            }
            else
            {
                _11109 = float3(0.0f, 0.0f, 0.5f);
                _10569 = _10464;
            }
            bool _4978 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4727;
            bool _4984;
            if (_4978)
            {
                _4984 = _4781 || _4787;
            }
            else
            {
                _4984 = _4978;
            }
            float4 _10592;
            if (_4984)
            {
                float _10564;
                do
                {
                    uint4 _8741 = r_warped_motion_qdata_tp1.Load(int3(_10038, 0));
                    uint _8742 = _8741.x;
                    if (_8742 != 0u)
                    {
                        float _10563;
                        if (_8742 == 0u)
                        {
                            _10563 = -1.0f;
                        }
                        else
                        {
                            _10563 = float((_8742 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10564 = _10563;
                        break;
                    }
                    int _10546;
                    uint _10547;
                    _10547 = _8742;
                    _10546 = -1;
                    uint _10562;
                    for (; _10546 <= 1; _10547 = _10562, _10546++)
                    {
                        _10562 = _10547;
                        for (int _10560 = -1; _10560 <= 1; )
                        {
                            _10562 = max(_10562, r_warped_motion_qdata_tp1.Load(int3(clamp(_10038 + int2(_10560, _10546), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10560++;
                            continue;
                        }
                    }
                    if (_10547 != 0u)
                    {
                        float _10559;
                        if (_10547 == 0u)
                        {
                            _10559 = -1.0f;
                        }
                        else
                        {
                            _10559 = float((_10547 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10564 = _10559;
                        break;
                    }
                    uint _10549;
                    _10549 = 4294967295u;
                    uint _11935;
                    for (int _10548 = 0; _10548 < 8; _10549 = _11935, _10548++)
                    {
                        int _10552 = 0;
                        for (;;)
                        {
                            if (_10552 < 5)
                            {
                                int2 _8692 = _10038 + (_1085[_10548] * _1094[_10552].xx);
                                bool _8695 = any(bool2(_8692.x < int2(0, 0).x, _8692.y < int2(0, 0).y));
                                bool _8703;
                                if (!_8695)
                                {
                                    _8703 = any(bool2(_8692.x >= cbFI_MvDepthLaneSize.x, _8692.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8703 = _8695;
                                }
                                if (_8703)
                                {
                                    _11935 = _10549;
                                    break;
                                }
                                uint4 _8781 = r_warped_motion_qdata_tp1.Load(int3(_8692, 0));
                                uint _8782 = _8781.x;
                                if (_8782 != 0u)
                                {
                                    _11935 = min(_10549, _8782);
                                    break;
                                }
                                _10552++;
                                continue;
                            }
                            else
                            {
                                _11935 = _10549;
                                break;
                            }
                        }
                    }
                    float _10551;
                    if (_10549 == 4294967295u)
                    {
                        _10551 = -1.0f;
                    }
                    else
                    {
                        float _10550;
                        if (_10549 == 0u)
                        {
                            _10550 = -1.0f;
                        }
                        else
                        {
                            _10550 = float((_10549 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10551 = _10550;
                    }
                    _10564 = _10551;
                    break;
                } while(false);
                float4 _10593;
                if (_10564 >= 0.0f)
                {
                    float _8803 = (exp((_10564 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5003;
                    if (_4781)
                    {
                        uint _8810_dummy_parameter;
                        _5003 = r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8810_dummy_parameter))))), 0)).x > _8803;
                    }
                    else
                    {
                        _5003 = _4781;
                    }
                    float4 _10582;
                    if (_5003)
                    {
                        float4 _9897 = _10569;
                        _9897.z = 0.0f;
                        _10582 = _9897;
                    }
                    else
                    {
                        _10582 = _10569;
                    }
                    bool _5015;
                    if (_4787)
                    {
                        uint _8829_dummy_parameter;
                        _5015 = r_depth_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8829_dummy_parameter))))), 0)).x > _8803;
                    }
                    else
                    {
                        _5015 = _4787;
                    }
                    float4 _10594;
                    if (_5015)
                    {
                        float4 _9899 = _10582;
                        _9899.w = 0.0f;
                        _10594 = _9899;
                    }
                    else
                    {
                        _10594 = _10582;
                    }
                    _10593 = _10594;
                }
                else
                {
                    _10593 = _10569;
                }
                _10592 = _10593;
            }
            else
            {
                _10592 = _10569;
            }
            bool _5023 = _4769 != _4775;
            bool _5030;
            if (_5023)
            {
                _5030 = _4769 ? _4715 : _4718;
            }
            else
            {
                _5030 = _5023;
            }
            bool _5037;
            if (_5030)
            {
                _5037 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5037 = _5030;
            }
            float4 _10677;
            if (_5037)
            {
                bool2 _5042 = _4769.xx;
                float2 _5043 = float2(_5042.x ? _10008.x : _10010.x, _5042.y ? _10008.y : _10010.y);
                float _10584;
                if (_4769)
                {
                    uint _8848_dummy_parameter;
                    _10584 = r_depth_tm1.Load(int3(int2(floor(_5043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8848_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8864_dummy_parameter;
                    _10584 = r_depth_tp1.Load(int3(int2(floor(_5043 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8864_dummy_parameter))))), 0)).x;
                }
                float4x4 _10585;
                if (_4769)
                {
                    _10585 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10585 = cbFI_MotionTP1ToTM1;
                }
                float2 _10586;
                do
                {
                    float _8891 = _5043.x;
                    float _8894 = 1.0f - _5043.y;
                    float4 _8905 = mul(float4((float2(_8891, _8894) * 2.0f) - 1.0f.xx, _10584, 1.0f), _10585);
                    float _8907 = _8905.w;
                    if (!(_8907 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10586 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8920 = ((_8905.xy / _8907.xx) + 1.0f.xx) * 0.5f;
                    _10586 = float2(_8920.x - _8891, _8894 - _8920.y);
                    break;
                } while(false);
                float2 _5073 = float2(cbFI_DisplaySize);
                float4 _10678;
                if (!(length(((_5043 + _10586) - float2(_5042.x ? _10010.x : _10008.x, _5042.y ? _10010.y : _10008.y)) * _5073) <= ((0.100000001490116119384765625f * length(_10586 * _5073)) + 8.0f)))
                {
                    float4 _10679;
                    if (_4769)
                    {
                        float4 _9909 = _10592;
                        _9909.x = 0.0f;
                        _10679 = _9909;
                    }
                    else
                    {
                        float4 _9911 = _10592;
                        _9911.y = 0.0f;
                        _10679 = _9911;
                    }
                    _10678 = _10679;
                }
                else
                {
                    _10678 = _10592;
                }
                _10677 = _10678;
            }
            else
            {
                _10677 = _10592;
            }
            float4 _5098 = _10350 * _10677;
            float _5100 = dot(_5098, 1.0f.xxxx);
            float4 _10897;
            bool _10917;
            if (_5100 > 0.0f)
            {
                _10917 = _10161;
                _10897 = _5098 / _5100.xxxx;
            }
            else
            {
                bool _5111 = any(bool4(_10677.x < 1.0f.xxxx.x, _10677.y < 1.0f.xxxx.y, _10677.z < 1.0f.xxxx.z, _10677.w < 1.0f.xxxx.w));
                if (_5111)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8942;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8942);
                    }
                }
                bool4 _11967 = _5111.xxxx;
                _10917 = _5111 ? true : _10161;
                _10897 = float4(_11967.x ? 0.0f.xxxx.x : _10350.x, _11967.y ? 0.0f.xxxx.y : _10350.y, _11967.z ? 0.0f.xxxx.z : _10350.z, _11967.w ? 0.0f.xxxx.w : _10350.w);
            }
            _11030 = _11109;
            _10916 = _10917;
            _10896 = _10897;
        }
        else
        {
            _11030 = float3(0.0f, 0.0f, 0.5f);
            _10916 = _10161;
            _10896 = _10350;
        }
        uint _5120 = (cbFI_pad0 >> 24u) & 31u;
        uint _5124 = (cbFI_pad0 >> 16u) & 255u;
        bool _5126 = _5120 != 0u;
        bool _5128 = _5124 == 12u;
        bool _5131 = _5124 == 13u;
        float4 _10913;
        if ((_5126 || _5128) || _5131)
        {
            float _10680;
            do
            {
                bool _9026 = all(bool2(_10011.x > 0.0f.xx.x, _10011.y > 0.0f.xx.y));
                bool _9032;
                if (_9026)
                {
                    _9032 = all(bool2(_10011.x < 1.0f.xx.x, _10011.y < 1.0f.xx.y));
                }
                else
                {
                    _9032 = _9026;
                }
                bool _8963 = !_9032;
                bool _8970;
                if (!_8963)
                {
                    bool _9037 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
                    bool _9043;
                    if (_9037)
                    {
                        _9043 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9043 = _9037;
                    }
                    _8970 = !_9043;
                }
                else
                {
                    _8970 = _8963;
                }
                if (_8970)
                {
                    _10680 = 0.0f;
                    break;
                }
                uint _9050_dummy_parameter;
                uint _9066_dummy_parameter;
                float4 _8991 = mul(float4((float2(_10011.x, 1.0f - _10011.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10011 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9050_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8993 = _8991.w;
                if (abs(_8993) < 9.9999999747524270787835121154785e-07f)
                {
                    _10680 = 0.0f;
                    break;
                }
                float _9004 = abs(cbFI_DeviceToViewDepth.y / ((_8991.z / _8993) - cbFI_DeviceToViewDepth.x));
                float _9007 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9066_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10680 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9004 - _9007) / max(max(_9004, _9007), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9114 = all(bool2(_10012.x > 0.0f.xx.x, _10012.y > 0.0f.xx.y));
            bool _9120;
            if (_9114)
            {
                _9120 = all(bool2(_10012.x < 1.0f.xx.x, _10012.y < 1.0f.xx.y));
            }
            else
            {
                _9120 = _9114;
            }
            float _10681;
            if (_9120)
            {
                uint _9127_dummy_parameter;
                _10681 = length((_5907 + (r_motion_tp1.Load(int3(int2(floor(_10012 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9127_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10681 = 1000000.0f;
            }
            float _10692;
            if ((_5120 & 1u) != 0u)
            {
                _10692 = _10680;
            }
            else
            {
                _10692 = 1.0f;
            }
            float _10693;
            if ((_5120 & 2u) != 0u)
            {
                _10693 = _10692 * (1.0f - smoothstep(2.0f, 8.0f, _10681));
            }
            else
            {
                _10693 = _10692;
            }
            float _10694;
            if ((_5120 & 4u) != 0u)
            {
                _10694 = _10693 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6628 - _6636) - length(_6612 - _6620))));
            }
            else
            {
                _10694 = _10693;
            }
            float _10907;
            if ((_5120 & 8u) != 0u)
            {
                _10907 = lerp(1.0f, _10694, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6612 - _6620)));
            }
            else
            {
                _10907 = _10694;
            }
            bool _5206 = (_5120 & 16u) != 0u;
            bool _5215;
            if (_5206)
            {
                _5215 = length(_10006 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5215 = _5206;
            }
            float _11969 = _5215 ? 1.0f : _10907;
            bool _5221 = _5126 && _6821;
            bool _5226;
            if (_5221)
            {
                bool _9152 = all(bool2(_10008.x > 0.0f.xx.x, _10008.y > 0.0f.xx.y));
                bool _9158;
                if (_9152)
                {
                    _9158 = all(bool2(_10008.x < 1.0f.xx.x, _10008.y < 1.0f.xx.y));
                }
                else
                {
                    _9158 = _9152;
                }
                _5226 = _9158;
            }
            else
            {
                _5226 = _5221;
            }
            bool _5231;
            if (_5226)
            {
                bool _9163 = all(bool2(_10010.x > 0.0f.xx.x, _10010.y > 0.0f.xx.y));
                bool _9169;
                if (_9163)
                {
                    _9169 = all(bool2(_10010.x < 1.0f.xx.x, _10010.y < 1.0f.xx.y));
                }
                else
                {
                    _9169 = _9163;
                }
                _5231 = _9169;
            }
            else
            {
                _5231 = _5226;
            }
            float4 _10914;
            if (_5231)
            {
                float _5237 = _10896.x + _10896.y;
                float _5246 = (_10896.z + _10896.w) * (1.0f - _11969);
                float _10910;
                if (_5237 > 9.9999997473787516355514526367188e-06f)
                {
                    _10910 = _10896.x / _5237;
                }
                else
                {
                    _10910 = _4202;
                }
                _10914 = float4(_10896.x + (_5246 * _10910), _10896.y + (_5246 * (1.0f - _10910)), _10896.zw * _11969);
            }
            else
            {
                _10914 = _10896;
            }
            _10913 = _10914;
        }
        else
        {
            _10913 = _10896;
        }
        float3 _11737;
        if (_10916)
        {
            float3 _9175 = r_current_interpolation_source.Load(int3(_3590, 0)).xyz;
            float3 _11738;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6821)
            {
                uint _9182_dummy_parameter;
                float _11021;
                _11021 = r_depth_tm1.Load(int3(int2(floor(_10008 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9182_dummy_parameter))))), 0)).x;
                float _5358;
                for (int _11020 = 0; _11020 < 24; _11021 = _5358, _11020++)
                {
                    float _5330 = float(_11020 & 7) * 0.785398185253143310546875f;
                    int _5332 = _11020 >> 3;
                    int _11788;
                    if (_5332 == 0)
                    {
                        _11788 = 16;
                    }
                    else
                    {
                        _11788 = (_5332 == 1) ? 48 : 96;
                    }
                    uint _9202_dummy_parameter;
                    _5358 = min(_11021, r_depth_tm1.Load(int3(int2(floor(clamp(_10008 + ((cbFI_MvDepthLaneSizeRcp * float(_11788)) * float2(cos(_5330), sin(_5330))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9202_dummy_parameter))))), 0)).x);
                }
                float2 _11022;
                do
                {
                    float _9224 = 1.0f - _10008.y;
                    float4 _9235 = mul(float4((float2(_10008.x, _9224) * 2.0f) - 1.0f.xx, _11021, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9237 = _9235.w;
                    if (!(_9237 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11022 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9250 = ((_9235.xy / _9237.xx) + 1.0f.xx) * 0.5f;
                    _11022 = float2(_9250.x - _10008.x, _9224 - _9250.y);
                    break;
                } while(false);
                float2 _5369 = _10008 + _11022;
                bool _9268 = all(bool2(_5369.x > 0.0f.xx.x, _5369.y > 0.0f.xx.y));
                bool _9274;
                if (_9268)
                {
                    _9274 = all(bool2(_5369.x < 1.0f.xx.x, _5369.y < 1.0f.xx.y));
                }
                else
                {
                    _9274 = _9268;
                }
                float3 _11739;
                if (_9274)
                {
                    float _5375 = abs(cbFI_DeviceToViewDepth.y / (_11021 - cbFI_DeviceToViewDepth.x));
                    uint _9294_dummy_parameter;
                    int2 _9294 = int2(spvTextureSize(r_depth_m2, uint(0), _9294_dummy_parameter));
                    float _5379 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5369 * float2(_9294))), int2(0, 0), _9294 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11744;
                    if (abs(_5379 - _5375) <= (0.20000000298023223876953125f * max(_5379, _5375)))
                    {
                        uint _9328_dummy_parameter;
                        int2 _9328 = int2(spvTextureSize(r_colour_m2, uint(0), _9328_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9351;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9351);
                        }
                        _11744 = r_colour_m2.Load(int3(clamp(int2(floor(_5369 * float2(_9328))), int2(0, 0), _9328 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9361;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9361);
                        }
                        _11744 = _9175;
                    }
                    _11739 = _11744;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9371;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9371);
                    }
                    _11739 = _9175;
                }
                _11738 = _11739;
            }
            else
            {
                _11738 = _9175;
            }
            _11737 = _11738;
        }
        else
        {
            _11737 = (((_6612 * _10913.x) + (_6620 * _10913.y)) + (_6628 * _10913.z)) + (_6636 * _10913.w);
        }
        uint _5407 = cbFI_pad0 & 255u;
        bool _11629;
        float3 _11736;
        if (_5407 != 0u)
        {
            float3 _5412 = r_present_backbuffer.Load(int3(_3590, 0)).xyz;
            float3 _5416 = r_current_interpolation_source.Load(int3(_3590, 0)).xyz;
            float3 _5420 = abs(_5412 - _5416);
            float3 _11025;
            if (_5407 == 2u)
            {
                _11025 = (abs(_5416) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11025 = 0.000244140625f.xxx;
            }
            bool _5436 = any(bool3(_5420.x > _11025.x, _5420.y > _11025.y, _5420.z > _11025.z));
            bool3 _11970 = _5436.xxx;
            _11736 = float3(_11970.x ? _5412.x : _11737.x, _11970.y ? _5412.y : _11737.y, _11970.z ? _5412.z : _11737.z);
            _11629 = _5436;
        }
        else
        {
            _11736 = _11737;
            _11629 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9386;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9386);
        }
        float3 _11719;
        if (_5124 == 1u)
        {
            _11719 = lerp(_6612, _6620, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11720;
            if (_5124 == 2u)
            {
                _11720 = lerp(_6628, _6636, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11721;
                if (_5124 == 3u)
                {
                    _11721 = float(_11629).xxx;
                }
                else
                {
                    float3 _11722;
                    if (_5124 == 4u)
                    {
                        _11722 = float3(((_10006 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11723;
                        if (_5124 == 5u)
                        {
                            _11723 = float3(((_5907 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11724;
                            if (_5124 == 6u)
                            {
                                _11724 = float3(_10913.xy, _10913.z + _10913.w);
                            }
                            else
                            {
                                float3 _11725;
                                if (_5124 == 7u)
                                {
                                    _11725 = r_current_interpolation_source.Load(int3(_3590, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11726;
                                    if (_5124 == 8u)
                                    {
                                        _11726 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3977, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11727;
                                        if (_5128)
                                        {
                                            uint _9408_dummy_parameter;
                                            uint _9440_dummy_parameter;
                                            _11727 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3977 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9408_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3977 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9440_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11728;
                                            if (_5131)
                                            {
                                                _11728 = _6628;
                                            }
                                            else
                                            {
                                                float3 _11729;
                                                if (_5124 == 20u)
                                                {
                                                    _11729 = _6612;
                                                }
                                                else
                                                {
                                                    float3 _11730;
                                                    if (_5124 == 21u)
                                                    {
                                                        _11730 = _6620;
                                                    }
                                                    else
                                                    {
                                                        float3 _11731;
                                                        if (_5124 == 22u)
                                                        {
                                                            _11731 = _6636;
                                                        }
                                                        else
                                                        {
                                                            float3 _11732;
                                                            if (_5124 == 18u)
                                                            {
                                                                _11732 = _11397;
                                                            }
                                                            else
                                                            {
                                                                float3 _11733;
                                                                if (_5124 == 19u)
                                                                {
                                                                    _11733 = _11211;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11972 = (_5124 == 23u).xxx;
                                                                    _11733 = float3(_11972.x ? _11030.x : _11736.x, _11972.y ? _11030.y : _11736.y, _11972.z ? _11030.z : _11736.z);
                                                                }
                                                                _11732 = _11733;
                                                            }
                                                            _11731 = _11732;
                                                        }
                                                        _11730 = _11731;
                                                    }
                                                    _11729 = _11730;
                                                }
                                                _11728 = _11729;
                                            }
                                            _11727 = _11728;
                                        }
                                        _11726 = _11727;
                                    }
                                    _11725 = _11726;
                                }
                                _11724 = _11725;
                            }
                            _11723 = _11724;
                        }
                        _11722 = _11723;
                    }
                    _11721 = _11722;
                }
                _11720 = _11721;
            }
            _11719 = _11720;
        }
        float3 _11718;
        if ((_5124 >= 9u) && (_5124 <= 11u))
        {
            uint _5600 = 64u + uint((_10038.y * cbFI_MvDepthLaneSize.x) + _10038.x);
            uint _5604 = rw_nfru_diagnostics.Load<uint>(_5600 * 4 + 0) & 15u;
            float3 _11749;
            if (_5124 == 10u)
            {
                float3 _11717;
                if ((rw_nfru_diagnostics.Load<uint>(_5600 * 4 + 0) & 32u) != 0u)
                {
                    _11717 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11716;
                    if ((rw_nfru_diagnostics.Load<uint>(_5600 * 4 + 0) & 16u) != 0u)
                    {
                        _11716 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5625 = ((rw_nfru_diagnostics.Load<uint>(_5600 * 4 + 0) & 64u) != 0u).xxx;
                        _11716 = float3(_5625.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5625.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5625.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11717 = _11716;
                }
                _11749 = _11717;
            }
            else
            {
                float3 _11750;
                if (_5124 == 11u)
                {
                    uint _5638 = (rw_nfru_diagnostics.Load<uint>(_5600 * 4 + 0) >> 8u) & 15u;
                    uint _5641 = (rw_nfru_diagnostics.Load<uint>(_5600 * 4 + 0) >> 12u) & 15u;
                    float3 _11709;
                    if ((_5604 == 2u) || (_5604 == 3u))
                    {
                        _11709 = _3303[_5604];
                    }
                    else
                    {
                        bool _5653 = _5638 == 3u;
                        bool _5655 = _5641 == 3u;
                        float3 _11710;
                        if (_5653 && _5655)
                        {
                            _11710 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11711;
                            if (_5653)
                            {
                                _11711 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11712;
                                if (_5655)
                                {
                                    _11712 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11713;
                                    if ((_5638 == 4u) || (_5641 == 4u))
                                    {
                                        _11713 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11714;
                                        if ((_5638 == 1u) || (_5641 == 1u))
                                        {
                                            _11714 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11974 = (_5604 == 1u).xxx;
                                            _11714 = float3(_11974.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11974.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11974.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11713 = _11714;
                                    }
                                    _11712 = _11713;
                                }
                                _11711 = _11712;
                            }
                            _11710 = _11711;
                        }
                        _11709 = _11710;
                    }
                    _11750 = _11709;
                }
                else
                {
                    _11750 = _3303[min(_5604, 7u)];
                }
                _11749 = _11750;
            }
            _11718 = _11749;
        }
        else
        {
            _11718 = _11719;
        }
        float4 _11753;
        if ((_5124 >= 14u) && (_5124 <= 16u))
        {
            float2 _11751;
            if (_5124 == 14u)
            {
                uint _5711_dummy_parameter;
                uint _5717_dummy_parameter;
                _11751 = r_flow_tm1.Load(int3(clamp(int2(floor(_3977 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5711_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5717_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11752;
                if (_5124 == 16u)
                {
                    uint _9491 = r_warped_flow_qdata_tm1.Load(int3(_3993, 0)).x & 2147483647u;
                    uint _9523 = uint(max((int((_9491 >> 16u) & 15u) - 6), 0));
                    _11752 = ((float2(float((1 - (2 * int((_9491 >> 15u) & 1u))) * int(((_9491 >> uint(7)) & 127u) << _9523)), float((1 - (2 * int((_9491 >> 14u) & 1u))) * int((_9491 & 127u) << _9523))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11752 = _5907 * float2(cbFI_DisplaySize);
                }
                _11751 = _11752;
            }
            uint2 _5750 = uint2(clamp(round(_11751 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5752 = _5750.x;
            uint _5759 = _5750.y;
            _11753 = float4(float(_5752 & 255u), float((_5752 >> 8u) | ((_5759 & 15u) << 4u)), float(_5759 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11754;
            if (_5124 == 17u)
            {
                _11754 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3993, 0)).x != 0u), _4336, 0.0f, 1.0f);
            }
            else
            {
                _11754 = float4(_11718, 1.0f);
            }
            _11753 = _11754;
        }
        rw_output[_3590] = _11753.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5803 = ((uint(_3590.y) * uint(cbFI_DisplaySize.x)) + uint(_3590.x)) * 6u;
            uint _9569 = spvPackHalf2x16(clamp(_6611.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5803 * 4 + 0, (((_9569 & 32767u) >> 4u) | ((((_9569 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6611.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9604 = spvPackHalf2x16(clamp(_6619.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5803 + 1u) * 4 + 0, (((_9604 & 32767u) >> 4u) | ((((_9604 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6619.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9639 = spvPackHalf2x16(clamp(_6627.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5803 + 2u) * 4 + 0, (((_9639 & 32767u) >> 4u) | ((((_9639 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6627.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9674 = spvPackHalf2x16(clamp(_6635.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5803 + 3u) * 4 + 0, (((_9674 & 32767u) >> 4u) | ((((_9674 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6635.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9701 = r_current_interpolation_source.Load(int3(_3590, 0));
            uint _9715 = spvPackHalf2x16(clamp(_9701.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5803 + 4u) * 4 + 0, (((_9715 & 32767u) >> 4u) | ((((_9715 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9701.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11787;
            if (_11629 || (_5124 != 0u))
            {
                _11787 = 4294967295u;
            }
            else
            {
                uint _9750 = spvPackHalf2x16(clamp(_11753.xy, 0.0f.xx, 65000.0f.xx));
                _11787 = (((_9750 & 32767u) >> 4u) | ((((_9750 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11753.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5803 + 5u) * 4 + 0, _11787);
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
