static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1184[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1193[5] = { 2, 4, 7, 11, 16 };
static const float3 _3763[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4050 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4050.x >= cbFI_DisplaySize.x, _4050.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4050] = float4(r_present_backbuffer.Load(int3(_4050, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4511 = (float2(_4050) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4513 = float2(cbFI_MvDepthLaneSize);
        int2 _4522 = int2(floor(_4511 * _4513));
        int2 _4527 = int2(floor(_4511 * float2(cbFI_FlowLaneSize)));
        float4 _6691 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4511 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6697 = r_warped_filled_flow_tm1.Load(int3(_4527, 0)).xy;
        float2 _6703 = r_warped_filled_motion_tp1.Load(int3(_4522, 0)).xy;
        bool _6725 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14013;
        if (_6725)
        {
            float _6738 = ((2.0f * _4511.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14013 = float2(atan(_6738) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4511.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6738 * _6738))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14013 = _4511;
        }
        bool _4548 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14034;
        bool _14176;
        int2 _14257;
        float3 _16424;
        if (_4548)
        {
            float _14015;
            float _14017;
            _14017 = 2.0f;
            _14015 = -1.0f;
            uint _4132[9];
            float _16992;
            float _16995;
            for (int _14014 = 0; _14014 < 9; _14017 = _16995, _14015 = _16992, _14014++)
            {
                _4132[_14014] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4522 + int2((_14014 % 3) - 1, (_14014 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4132[_14014] != 0u)
                {
                    float _16987;
                    if (_4132[_14014] == 0u)
                    {
                        _16987 = -1.0f;
                    }
                    else
                    {
                        _16987 = float((_4132[_14014] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _16995 = min(_14017, _16987);
                    _16992 = max(_14015, _16987);
                }
                else
                {
                    _16995 = _14017;
                    _16992 = _14015;
                }
            }
            float _4594 = float(_14015 >= 0.0f);
            float3 _13716 = 0.0f.xxx;
            _13716.y = _4594;
            float2 _14035;
            bool _14177;
            int2 _14258;
            float3 _16425;
            if ((_14015 - _14017) > 0.0199999995529651641845703125f)
            {
                float _14023;
                int2 _14024;
                float2 _14025;
                int2 _14027;
                float2 _14033;
                _14033 = _6703;
                _14027 = _4522;
                _14025 = _6703;
                _14024 = _4522;
                _14023 = -1.0f;
                float _17000;
                int2 _17004;
                float2 _17015;
                int2 _17026;
                float2 _17059;
                float _17106;
                int _14022 = 0;
                float _16968 = 1000000000.0f;
                for (; _14022 < 9; _16968 = _17106, _14033 = _17059, _14027 = _17026, _14025 = _17015, _14024 = _17004, _14023 = _17000, _14022++)
                {
                    if (_4132[_14022] == 0u)
                    {
                        _17106 = _16968;
                        _17059 = _14033;
                        _17026 = _14027;
                        _17015 = _14025;
                        _17004 = _14024;
                        _17000 = _14023;
                        continue;
                    }
                    int2 _4629 = clamp(_4522 + int2((_14022 % 3) - 1, (_14022 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6813 = _4132[_14022] & 2147483647u;
                    uint _6845 = uint(max((int((_6813 >> 16u) & 15u) - 6), 0));
                    float2 _4635 = (float2(float((1 - (2 * int((_6813 >> 15u) & 1u))) * int(((_6813 >> uint(7)) & 127u) << _6845)), float((1 - (2 * int((_6813 >> 14u) & 1u))) * int((_6813 & 127u) << _6845))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _16954;
                    if (_4132[_14022] == 0u)
                    {
                        _16954 = -1.0f;
                    }
                    else
                    {
                        _16954 = float((_4132[_14022] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4640 = _16954 - 0.100000001490116119384765625f;
                    float2 _16955;
                    if (_6725)
                    {
                        float2 _6922 = clamp((((_14013 + (_4635 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6925 = tan(_6922.x);
                        _16955 = (float2(_6925 / cbFI_DeviceToViewDepth.z, (tan(_6922.y) * sqrt(1.0f + (_6925 * _6925))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _16955 = _14013 + (_4635 * cbFI_Timestep);
                    }
                    float _4647 = cbFI_Timestep - 1.0f;
                    float2 _16956;
                    if (_6725)
                    {
                        float2 _6993 = clamp((((_14013 + (_4635 * _4647)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6996 = tan(_6993.x);
                        _16956 = (float2(_6996 / cbFI_DeviceToViewDepth.z, (tan(_6993.y) * sqrt(1.0f + (_6996 * _6996))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _16956 = _14013 + (_4635 * _4647);
                    }
                    bool _7029 = all(bool2(_16955.x > 0.0f.xx.x, _16955.y > 0.0f.xx.y));
                    bool _7035;
                    if (_7029)
                    {
                        _7035 = all(bool2(_16955.x < 1.0f.xx.x, _16955.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7035 = _7029;
                    }
                    float _16959;
                    if (_7035)
                    {
                        uint _7042_dummy_parameter;
                        _16959 = max((_4640 - (log((r_depth_tm1.Load(int3(int2(floor(_16955 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7042_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _16959 = 0.0f;
                    }
                    bool _7072 = all(bool2(_16956.x > 0.0f.xx.x, _16956.y > 0.0f.xx.y));
                    bool _7078;
                    if (_7072)
                    {
                        _7078 = all(bool2(_16956.x < 1.0f.xx.x, _16956.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7078 = _7072;
                    }
                    float _16960;
                    if (_7078)
                    {
                        uint _7085_dummy_parameter;
                        _16960 = _16959 + max((_4640 - (log((r_depth_tp1.Load(int3(int2(floor(_16956 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7085_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _16960 = _16959;
                    }
                    float _17001;
                    int2 _17005;
                    float2 _17016;
                    int2 _17027;
                    float2 _17060;
                    float _17107;
                    if (_16960 == 0.0f)
                    {
                        bool _4682 = _4640 > _14023;
                        bool2 _17115 = _4682.xx;
                        _17107 = _16968;
                        _17060 = float2(_17115.x ? _4635.x : _14033.x, _17115.y ? _4635.y : _14033.y);
                        _17027 = int2(_17115.x ? _4629.x : _14027.x, _17115.y ? _4629.y : _14027.y);
                        _17016 = _14025;
                        _17005 = _14024;
                        _17001 = _4682 ? _4640 : _14023;
                    }
                    else
                    {
                        bool _4691 = _16960 < _16968;
                        bool2 _17111 = _4691.xx;
                        _17107 = _4691 ? _16960 : _16968;
                        _17060 = _14033;
                        _17027 = _14027;
                        _17016 = float2(_17111.x ? _4635.x : _14025.x, _17111.y ? _4635.y : _14025.y);
                        _17005 = int2(_17111.x ? _4629.x : _14024.x, _17111.y ? _4629.y : _14024.y);
                        _17001 = _14023;
                    }
                    _17106 = _17107;
                    _17059 = _17060;
                    _17026 = _17027;
                    _17015 = _17016;
                    _17004 = _17005;
                    _17000 = _17001;
                }
                bool _4703 = _14023 < 0.0f;
                bool2 _17121 = _4703.xx;
                int2 _17124 = int2(_17121.x ? _14024.x : _14027.x, _17121.y ? _14024.y : _14027.y);
                _16425 = float3(1.0f, _4594, float(any(bool2(_17124.x != _4522.x, _17124.y != _4522.y))));
                _14258 = _17124;
                _14177 = _4703 ? false : true;
                _14035 = float2(_17121.x ? _14025.x : _14033.x, _17121.y ? _14025.y : _14033.y);
            }
            else
            {
                _16425 = _13716;
                _14258 = _4522;
                _14177 = false;
                _14035 = _6703;
            }
            _16424 = _16425;
            _14257 = _14258;
            _14176 = _14177;
            _14034 = _14035;
        }
        else
        {
            _16424 = 0.0f.xxx;
            _14257 = _4522;
            _14176 = false;
            _14034 = _6703;
        }
        float2 _14036;
        if (_6725)
        {
            float2 _7150 = clamp((((_14013 + (_14034 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7153 = tan(_7150.x);
            _14036 = (float2(_7153 / cbFI_DeviceToViewDepth.z, (tan(_7150.y) * sqrt(1.0f + (_7153 * _7153))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14036 = _14013 + (_14034 * cbFI_Timestep);
        }
        float _4726 = cbFI_Timestep - 1.0f;
        float2 _14038;
        if (_6725)
        {
            float2 _7221 = clamp((((_14013 + (_14034 * _4726)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7224 = tan(_7221.x);
            _14038 = (float2(_7224 / cbFI_DeviceToViewDepth.z, (tan(_7221.y) * sqrt(1.0f + (_7224 * _7224))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14038 = _14013 + (_14034 * _4726);
        }
        float _4731 = -cbFI_Timestep;
        float2 _14039;
        if (_6725)
        {
            float2 _7292 = clamp((((_14013 + (_6697 * _4731)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7295 = tan(_7292.x);
            _14039 = (float2(_7295 / cbFI_DeviceToViewDepth.z, (tan(_7292.y) * sqrt(1.0f + (_7295 * _7295))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14039 = _14013 + (_6697 * _4731);
        }
        float _4736 = 1.0f - cbFI_Timestep;
        float2 _14040;
        if (_6725)
        {
            float2 _7363 = clamp((((_14013 + (_6697 * _4736)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7366 = tan(_7363.x);
            _14040 = (float2(_7366 / cbFI_DeviceToViewDepth.z, (tan(_7363.y) * sqrt(1.0f + (_7366 * _7366))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14040 = _14013 + (_6697 * _4736);
        }
        float4 _7401 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14036, 0.0f);
        float3 _7402 = _7401.xyz;
        float4 _7409 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14038, 0.0f);
        float3 _7410 = _7409.xyz;
        float4 _7417 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14039, 0.0f);
        float3 _7418 = _7417.xyz;
        float4 _7425 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14040, 0.0f);
        float3 _7426 = _7425.xyz;
        float4 _7440 = exp(_6691 - max(max(max(_6691.x, _6691.y), _6691.z), _6691.w).xxxx);
        float4 _7447 = _7440 / (dot(_7440, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4752 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14247;
        float _15555;
        if (_4752)
        {
            float2 _4758 = 0.5f.xx / _4513;
            float _4761 = _4758.x;
            float _4762 = -_4761;
            float _4764 = _4758.y;
            float _4765 = -_4764;
            float2 _4767 = _4511 + float2(_4762, _4765);
            float2 _4769 = float2(cbFI_DisplaySize);
            bool _14057;
            do
            {
                bool _7527 = all(bool2(_4767.x > 0.0f.xx.x, _4767.y > 0.0f.xx.y));
                bool _7533;
                if (_7527)
                {
                    _7533 = all(bool2(_4767.x < 1.0f.xx.x, _4767.y < 1.0f.xx.y));
                }
                else
                {
                    _7533 = _7527;
                }
                if (!_7533)
                {
                    _14057 = false;
                    break;
                }
                uint _7540_dummy_parameter;
                float4x4 _14055;
                do
                {
                    float4x4 _7554;
                    bool _14054;
                    do
                    {
                        _7554 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14054 = false;
                            break;
                        }
                        uint _7588 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7588 + 32u) * 4 + 0) != 1u)
                        {
                            _14054 = false;
                            break;
                        }
                        uint _14051;
                        _14051 = 0u;
                        for (; _14051 < 4u; _14051++)
                        {
                            for (uint _14052 = 0u; _14052 < 4u; )
                            {
                                _7554[_14051][_14052] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7588 + (_14051 * 4u)) + _14052) * 4 + 0));
                                _14052++;
                                continue;
                            }
                        }
                        _14054 = true;
                        break;
                    } while(false);
                    if (_14054)
                    {
                        _14055 = _7554;
                        break;
                    }
                    _14055 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14056;
                do
                {
                    float _7665 = _4767.x;
                    float _7668 = 1.0f - _4767.y;
                    float4 _7679 = mul(float4((float2(_7665, _7668) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4767 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7540_dummy_parameter))))), 0)).x, 1.0f), _14055);
                    float _7681 = _7679.w;
                    if (!(_7681 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14056 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7694 = ((_7679.xy / _7681.xx) + 1.0f.xx) * 0.5f;
                    _14056 = float2(_7694.x - _7665, _7668 - _7694.y);
                    break;
                } while(false);
                float2 _7491 = abs(_14056);
                if (any(bool2(_7491.x > 100000.0f.xx.x, _7491.y > 100000.0f.xx.y)))
                {
                    _14057 = false;
                    break;
                }
                float _7499 = length(_14056 * _4769);
                uint _7714_dummy_parameter;
                bool _7513 = _7499 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7520;
                if (_7513)
                {
                    _7520 = length((r_motion_tp1.Load(int3(int2(floor(_4767 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7714_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _7499);
                }
                else
                {
                    _7520 = _7513;
                }
                _14057 = _7520;
                break;
            } while(false);
            float2 _4779 = _4511 + float2(_4761, _4765);
            bool _14064;
            do
            {
                bool _7800 = all(bool2(_4779.x > 0.0f.xx.x, _4779.y > 0.0f.xx.y));
                bool _7806;
                if (_7800)
                {
                    _7806 = all(bool2(_4779.x < 1.0f.xx.x, _4779.y < 1.0f.xx.y));
                }
                else
                {
                    _7806 = _7800;
                }
                if (!_7806)
                {
                    _14064 = false;
                    break;
                }
                uint _7813_dummy_parameter;
                float4x4 _14062;
                do
                {
                    float4x4 _7827;
                    bool _14061;
                    do
                    {
                        _7827 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14061 = false;
                            break;
                        }
                        uint _7861 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7861 + 32u) * 4 + 0) != 1u)
                        {
                            _14061 = false;
                            break;
                        }
                        uint _14058;
                        _14058 = 0u;
                        for (; _14058 < 4u; _14058++)
                        {
                            for (uint _14059 = 0u; _14059 < 4u; )
                            {
                                _7827[_14058][_14059] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7861 + (_14058 * 4u)) + _14059) * 4 + 0));
                                _14059++;
                                continue;
                            }
                        }
                        _14061 = true;
                        break;
                    } while(false);
                    if (_14061)
                    {
                        _14062 = _7827;
                        break;
                    }
                    _14062 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14063;
                do
                {
                    float _7938 = _4779.x;
                    float _7941 = 1.0f - _4779.y;
                    float4 _7952 = mul(float4((float2(_7938, _7941) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4779 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7813_dummy_parameter))))), 0)).x, 1.0f), _14062);
                    float _7954 = _7952.w;
                    if (!(_7954 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14063 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7967 = ((_7952.xy / _7954.xx) + 1.0f.xx) * 0.5f;
                    _14063 = float2(_7967.x - _7938, _7941 - _7967.y);
                    break;
                } while(false);
                float2 _7764 = abs(_14063);
                if (any(bool2(_7764.x > 100000.0f.xx.x, _7764.y > 100000.0f.xx.y)))
                {
                    _14064 = false;
                    break;
                }
                float _7772 = length(_14063 * _4769);
                uint _7987_dummy_parameter;
                bool _7786 = _7772 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7793;
                if (_7786)
                {
                    _7793 = length((r_motion_tp1.Load(int3(int2(floor(_4779 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7987_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _7772);
                }
                else
                {
                    _7793 = _7786;
                }
                _14064 = _7793;
                break;
            } while(false);
            float2 _4792 = _4511 + float2(_4762, _4764);
            bool _14071;
            do
            {
                bool _8073 = all(bool2(_4792.x > 0.0f.xx.x, _4792.y > 0.0f.xx.y));
                bool _8079;
                if (_8073)
                {
                    _8079 = all(bool2(_4792.x < 1.0f.xx.x, _4792.y < 1.0f.xx.y));
                }
                else
                {
                    _8079 = _8073;
                }
                if (!_8079)
                {
                    _14071 = false;
                    break;
                }
                uint _8086_dummy_parameter;
                float4x4 _14069;
                do
                {
                    float4x4 _8100;
                    bool _14068;
                    do
                    {
                        _8100 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14068 = false;
                            break;
                        }
                        uint _8134 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8134 + 32u) * 4 + 0) != 1u)
                        {
                            _14068 = false;
                            break;
                        }
                        uint _14065;
                        _14065 = 0u;
                        for (; _14065 < 4u; _14065++)
                        {
                            for (uint _14066 = 0u; _14066 < 4u; )
                            {
                                _8100[_14065][_14066] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8134 + (_14065 * 4u)) + _14066) * 4 + 0));
                                _14066++;
                                continue;
                            }
                        }
                        _14068 = true;
                        break;
                    } while(false);
                    if (_14068)
                    {
                        _14069 = _8100;
                        break;
                    }
                    _14069 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14070;
                do
                {
                    float _8211 = _4792.x;
                    float _8214 = 1.0f - _4792.y;
                    float4 _8225 = mul(float4((float2(_8211, _8214) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4792 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8086_dummy_parameter))))), 0)).x, 1.0f), _14069);
                    float _8227 = _8225.w;
                    if (!(_8227 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14070 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8240 = ((_8225.xy / _8227.xx) + 1.0f.xx) * 0.5f;
                    _14070 = float2(_8240.x - _8211, _8214 - _8240.y);
                    break;
                } while(false);
                float2 _8037 = abs(_14070);
                if (any(bool2(_8037.x > 100000.0f.xx.x, _8037.y > 100000.0f.xx.y)))
                {
                    _14071 = false;
                    break;
                }
                float _8045 = length(_14070 * _4769);
                uint _8260_dummy_parameter;
                bool _8059 = _8045 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8066;
                if (_8059)
                {
                    _8066 = length((r_motion_tp1.Load(int3(int2(floor(_4792 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8260_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _8045);
                }
                else
                {
                    _8066 = _8059;
                }
                _14071 = _8066;
                break;
            } while(false);
            float2 _4804 = _4511 + _4758;
            bool _14078;
            do
            {
                bool _8346 = all(bool2(_4804.x > 0.0f.xx.x, _4804.y > 0.0f.xx.y));
                bool _8352;
                if (_8346)
                {
                    _8352 = all(bool2(_4804.x < 1.0f.xx.x, _4804.y < 1.0f.xx.y));
                }
                else
                {
                    _8352 = _8346;
                }
                if (!_8352)
                {
                    _14078 = false;
                    break;
                }
                uint _8359_dummy_parameter;
                float4x4 _14076;
                do
                {
                    float4x4 _8373;
                    bool _14075;
                    do
                    {
                        _8373 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14075 = false;
                            break;
                        }
                        uint _8407 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8407 + 32u) * 4 + 0) != 1u)
                        {
                            _14075 = false;
                            break;
                        }
                        uint _14072;
                        _14072 = 0u;
                        for (; _14072 < 4u; _14072++)
                        {
                            for (uint _14073 = 0u; _14073 < 4u; )
                            {
                                _8373[_14072][_14073] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8407 + (_14072 * 4u)) + _14073) * 4 + 0));
                                _14073++;
                                continue;
                            }
                        }
                        _14075 = true;
                        break;
                    } while(false);
                    if (_14075)
                    {
                        _14076 = _8373;
                        break;
                    }
                    _14076 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14077;
                do
                {
                    float _8484 = _4804.x;
                    float _8487 = 1.0f - _4804.y;
                    float4 _8498 = mul(float4((float2(_8484, _8487) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4804 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8359_dummy_parameter))))), 0)).x, 1.0f), _14076);
                    float _8500 = _8498.w;
                    if (!(_8500 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14077 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8513 = ((_8498.xy / _8500.xx) + 1.0f.xx) * 0.5f;
                    _14077 = float2(_8513.x - _8484, _8487 - _8513.y);
                    break;
                } while(false);
                float2 _8310 = abs(_14077);
                if (any(bool2(_8310.x > 100000.0f.xx.x, _8310.y > 100000.0f.xx.y)))
                {
                    _14078 = false;
                    break;
                }
                float _8318 = length(_14077 * _4769);
                uint _8533_dummy_parameter;
                bool _8332 = _8318 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8339;
                if (_8332)
                {
                    _8339 = length((r_motion_tp1.Load(int3(int2(floor(_4804 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8533_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _8318);
                }
                else
                {
                    _8339 = _8332;
                }
                _14078 = _8339;
                break;
            } while(false);
            float _4810 = 0.25f * (((float(_14057) + float(_14064)) + float(_14071)) + float(_14078));
            float4 _14248;
            if (_4810 < 1.0f)
            {
                bool _14085;
                do
                {
                    bool _8619 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
                    bool _8625;
                    if (_8619)
                    {
                        _8625 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8625 = _8619;
                    }
                    if (!_8625)
                    {
                        _14085 = false;
                        break;
                    }
                    uint _8632_dummy_parameter;
                    float4x4 _14083;
                    do
                    {
                        float4x4 _8646;
                        bool _14082;
                        do
                        {
                            _8646 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14082 = false;
                                break;
                            }
                            uint _8680 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8680 + 32u) * 4 + 0) != 1u)
                            {
                                _14082 = false;
                                break;
                            }
                            uint _14079;
                            _14079 = 0u;
                            for (; _14079 < 4u; _14079++)
                            {
                                for (uint _14080 = 0u; _14080 < 4u; )
                                {
                                    _8646[_14079][_14080] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8680 + (_14079 * 4u)) + _14080) * 4 + 0));
                                    _14080++;
                                    continue;
                                }
                            }
                            _14082 = true;
                            break;
                        } while(false);
                        if (_14082)
                        {
                            _14083 = _8646;
                            break;
                        }
                        _14083 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14084;
                    do
                    {
                        float _8760 = 1.0f - _14036.y;
                        float4 _8771 = mul(float4((float2(_14036.x, _8760) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8632_dummy_parameter))))), 0)).x, 1.0f), _14083);
                        float _8773 = _8771.w;
                        if (!(_8773 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14084 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8786 = ((_8771.xy / _8773.xx) + 1.0f.xx) * 0.5f;
                        _14084 = float2(_8786.x - _14036.x, _8760 - _8786.y);
                        break;
                    } while(false);
                    float2 _8583 = abs(_14084);
                    if (any(bool2(_8583.x > 100000.0f.xx.x, _8583.y > 100000.0f.xx.y)))
                    {
                        _14085 = false;
                        break;
                    }
                    float _8591 = length(_14084 * _4769);
                    uint _8806_dummy_parameter;
                    bool _8605 = _8591 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8612;
                    if (_8605)
                    {
                        _8612 = length((r_motion_tp1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8806_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _8591);
                    }
                    else
                    {
                        _8612 = _8605;
                    }
                    _14085 = _8612;
                    break;
                } while(false);
                bool _14092;
                do
                {
                    bool _8892 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
                    bool _8898;
                    if (_8892)
                    {
                        _8898 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8898 = _8892;
                    }
                    if (!_8898)
                    {
                        _14092 = false;
                        break;
                    }
                    uint _8905_dummy_parameter;
                    float4x4 _14090;
                    do
                    {
                        float4x4 _8919;
                        bool _14089;
                        do
                        {
                            _8919 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14089 = false;
                                break;
                            }
                            uint _8953 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8953 + 32u) * 4 + 0) != 1u)
                            {
                                _14089 = false;
                                break;
                            }
                            uint _14086;
                            _14086 = 0u;
                            for (; _14086 < 4u; _14086++)
                            {
                                for (uint _14087 = 0u; _14087 < 4u; )
                                {
                                    _8919[_14086][_14087] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8953 + (_14086 * 4u)) + _14087) * 4 + 0));
                                    _14087++;
                                    continue;
                                }
                            }
                            _14089 = true;
                            break;
                        } while(false);
                        if (_14089)
                        {
                            _14090 = _8919;
                            break;
                        }
                        _14090 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14091;
                    do
                    {
                        float _9033 = 1.0f - _14038.y;
                        float4 _9044 = mul(float4((float2(_14038.x, _9033) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8905_dummy_parameter))))), 0)).x, 1.0f), _14090);
                        float _9046 = _9044.w;
                        if (!(_9046 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14091 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9059 = ((_9044.xy / _9046.xx) + 1.0f.xx) * 0.5f;
                        _14091 = float2(_9059.x - _14038.x, _9033 - _9059.y);
                        break;
                    } while(false);
                    float2 _8856 = abs(_14091);
                    if (any(bool2(_8856.x > 100000.0f.xx.x, _8856.y > 100000.0f.xx.y)))
                    {
                        _14092 = false;
                        break;
                    }
                    float _8864 = length(_14091 * _4769);
                    uint _9079_dummy_parameter;
                    bool _8878 = _8864 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8885;
                    if (_8878)
                    {
                        _8885 = length((r_motion_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9079_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _8864);
                    }
                    else
                    {
                        _8885 = _8878;
                    }
                    _14092 = _8885;
                    break;
                } while(false);
                bool _14099;
                do
                {
                    bool _9165 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                    bool _9171;
                    if (_9165)
                    {
                        _9171 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9171 = _9165;
                    }
                    if (!_9171)
                    {
                        _14099 = false;
                        break;
                    }
                    uint _9178_dummy_parameter;
                    float4x4 _14097;
                    do
                    {
                        float4x4 _9192;
                        bool _14096;
                        do
                        {
                            _9192 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14096 = false;
                                break;
                            }
                            uint _9226 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9226 + 32u) * 4 + 0) != 1u)
                            {
                                _14096 = false;
                                break;
                            }
                            uint _14093;
                            _14093 = 0u;
                            for (; _14093 < 4u; _14093++)
                            {
                                for (uint _14094 = 0u; _14094 < 4u; )
                                {
                                    _9192[_14093][_14094] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9226 + (_14093 * 4u)) + _14094) * 4 + 0));
                                    _14094++;
                                    continue;
                                }
                            }
                            _14096 = true;
                            break;
                        } while(false);
                        if (_14096)
                        {
                            _14097 = _9192;
                            break;
                        }
                        _14097 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14098;
                    do
                    {
                        float _9306 = 1.0f - _14039.y;
                        float4 _9317 = mul(float4((float2(_14039.x, _9306) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9178_dummy_parameter))))), 0)).x, 1.0f), _14097);
                        float _9319 = _9317.w;
                        if (!(_9319 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14098 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9332 = ((_9317.xy / _9319.xx) + 1.0f.xx) * 0.5f;
                        _14098 = float2(_9332.x - _14039.x, _9306 - _9332.y);
                        break;
                    } while(false);
                    float2 _9129 = abs(_14098);
                    if (any(bool2(_9129.x > 100000.0f.xx.x, _9129.y > 100000.0f.xx.y)))
                    {
                        _14099 = false;
                        break;
                    }
                    float _9137 = length(_14098 * _4769);
                    uint _9352_dummy_parameter;
                    bool _9151 = _9137 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9158;
                    if (_9151)
                    {
                        _9158 = length((r_motion_tp1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9352_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _9137);
                    }
                    else
                    {
                        _9158 = _9151;
                    }
                    _14099 = _9158;
                    break;
                } while(false);
                bool _14106;
                do
                {
                    bool _9438 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                    bool _9444;
                    if (_9438)
                    {
                        _9444 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9444 = _9438;
                    }
                    if (!_9444)
                    {
                        _14106 = false;
                        break;
                    }
                    uint _9451_dummy_parameter;
                    float4x4 _14104;
                    do
                    {
                        float4x4 _9465;
                        bool _14103;
                        do
                        {
                            _9465 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14103 = false;
                                break;
                            }
                            uint _9499 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9499 + 32u) * 4 + 0) != 1u)
                            {
                                _14103 = false;
                                break;
                            }
                            uint _14100;
                            _14100 = 0u;
                            for (; _14100 < 4u; _14100++)
                            {
                                for (uint _14101 = 0u; _14101 < 4u; )
                                {
                                    _9465[_14100][_14101] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9499 + (_14100 * 4u)) + _14101) * 4 + 0));
                                    _14101++;
                                    continue;
                                }
                            }
                            _14103 = true;
                            break;
                        } while(false);
                        if (_14103)
                        {
                            _14104 = _9465;
                            break;
                        }
                        _14104 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14105;
                    do
                    {
                        float _9579 = 1.0f - _14040.y;
                        float4 _9590 = mul(float4((float2(_14040.x, _9579) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9451_dummy_parameter))))), 0)).x, 1.0f), _14104);
                        float _9592 = _9590.w;
                        if (!(_9592 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14105 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9605 = ((_9590.xy / _9592.xx) + 1.0f.xx) * 0.5f;
                        _14105 = float2(_9605.x - _14040.x, _9579 - _9605.y);
                        break;
                    } while(false);
                    float2 _9402 = abs(_14105);
                    if (any(bool2(_9402.x > 100000.0f.xx.x, _9402.y > 100000.0f.xx.y)))
                    {
                        _14106 = false;
                        break;
                    }
                    float _9410 = length(_14105 * _4769);
                    uint _9625_dummy_parameter;
                    bool _9424 = _9410 > ((8.0f * _4769.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9431;
                    if (_9424)
                    {
                        _9431 = length((r_motion_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9625_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4769) < (0.20000000298023223876953125f * _9410);
                    }
                    else
                    {
                        _9431 = _9424;
                    }
                    _14106 = _9431;
                    break;
                } while(false);
                float4 _4837 = _7447 * float4(_14085 ? 0.0f : 1.0f, _14092 ? 0.0f : 1.0f, _14099 ? 0.0f : 1.0f, _14106 ? 0.0f : 1.0f);
                float _4839 = dot(_4837, 1.0f.xxxx);
                float4 _14249;
                if (_4839 > 0.001000000047497451305389404296875f)
                {
                    _14249 = _4837 / _4839.xxxx;
                }
                else
                {
                    _14249 = _7447;
                }
                _14248 = _14249;
            }
            else
            {
                _14248 = _7447;
            }
            _15555 = _4810;
            _14247 = _14248;
        }
        else
        {
            _15555 = 0.0f;
            _14247 = _7447;
        }
        bool _4856 = _4548 && (!_14176);
        bool _4865;
        if (_4856)
        {
            _4865 = (_14247.z + _14247.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4865 = _4856;
        }
        bool _4876;
        if (_4865)
        {
            _4876 = length((_14039 - _14036) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4876 = _4865;
        }
        bool _14336;
        if (_4876)
        {
            uint4 _9654 = r_warped_motion_qdata_tp1.Load(int3(_14257, 0));
            uint _9655 = _9654.x;
            bool _14339;
            if (_9655 != 0u)
            {
                float _14325;
                if (_9655 == 0u)
                {
                    _14325 = -1.0f;
                }
                else
                {
                    _14325 = float((_9655 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4886 = _14325 - 0.12000000476837158203125f;
                bool _9674 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                bool _9680;
                if (_9674)
                {
                    _9680 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                }
                else
                {
                    _9680 = _9674;
                }
                bool _4896;
                if (_9680)
                {
                    uint _9687_dummy_parameter;
                    _4896 = (log((r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9687_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4886;
                }
                else
                {
                    _4896 = _9680;
                }
                bool _4910;
                if (!_4896)
                {
                    bool _9717 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                    bool _9723;
                    if (_9717)
                    {
                        _9723 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9723 = _9717;
                    }
                    bool _4908;
                    if (_9723)
                    {
                        uint _9730_dummy_parameter;
                        _4908 = (log((r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9730_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4886;
                    }
                    else
                    {
                        _4908 = _9723;
                    }
                    _4910 = _4908;
                }
                else
                {
                    _4910 = _4896;
                }
                _14339 = _4910;
            }
            else
            {
                _14339 = false;
            }
            _14336 = _14339;
        }
        else
        {
            _14336 = false;
        }
        bool _4915 = _14176 || _14336;
        bool _4920;
        if (_4915)
        {
            bool _9760 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
            bool _9766;
            if (_9760)
            {
                _9766 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
            }
            else
            {
                _9766 = _9760;
            }
            _4920 = _9766;
        }
        else
        {
            _4920 = _4915;
        }
        bool _4925;
        if (_4920)
        {
            bool _9771 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
            bool _9777;
            if (_9771)
            {
                _9777 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
            }
            else
            {
                _9777 = _9771;
            }
            _4925 = _9777;
        }
        else
        {
            _4925 = _4920;
        }
        float4 _14459;
        if (_4925)
        {
            float _4931 = _14247.x + _14247.y;
            float _4936 = _14247.z + _14247.w;
            float _14354;
            if (_4931 > 0.001000000047497451305389404296875f)
            {
                _14354 = _14247.x / _4931;
            }
            else
            {
                _14354 = _4736;
            }
            _14459 = float4(_14247.x + (_4936 * _14354), _14247.y + (_4936 * (1.0f - _14354)), 0.0f, 0.0f);
        }
        else
        {
            _14459 = _14247;
        }
        bool _9805 = (cbFI_pad0 & 1024u) != 0u;
        bool _9781 = !_9805;
        bool _9782 = !_9781;
        bool _9799;
        if (_9782)
        {
            _9799 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14257.y * cbFI_MvDepthLaneSize.x) + _14257.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9799 = _9781;
        }
        bool _9831;
        if (_9782)
        {
            _9831 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4527.y * cbFI_FlowLaneSize.x) + _4527.x)) * 4 + 0) != 0u;
        }
        else
        {
            _9831 = _9781;
        }
        float _4971 = float(_9831);
        bool _14480;
        float4 _14519;
        float3 _16188;
        if (_9805)
        {
            bool _4981;
            if (_9799)
            {
                _4981 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
            }
            else
            {
                _4981 = _9799;
            }
            bool _4987;
            if (_4981)
            {
                _4987 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
            }
            else
            {
                _4987 = _4981;
            }
            bool _4994;
            if (_9799)
            {
                _4994 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
            }
            else
            {
                _4994 = _9799;
            }
            bool _5000;
            if (_4994)
            {
                _5000 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
            }
            else
            {
                _5000 = _4994;
            }
            bool _5007;
            if (_9831)
            {
                _5007 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
            }
            else
            {
                _5007 = _9831;
            }
            bool _5013;
            if (_5007)
            {
                _5013 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
            }
            else
            {
                _5013 = _5007;
            }
            bool _5020;
            if (_9831)
            {
                _5020 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
            }
            else
            {
                _5020 = _9831;
            }
            bool _5026;
            if (_5020)
            {
                _5026 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
            }
            else
            {
                _5026 = _5020;
            }
            bool _5028 = !_9799;
            if (_5028)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9873;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9873);
                }
            }
            bool _5033 = !_9831;
            if (_5033)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9883;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9883);
                }
            }
            if (_9799 && _5033)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9893;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9893);
                }
            }
            if (_5028 && _9831)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9903;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _9903);
                }
            }
            float _5052 = float(_4987);
            float _5054 = float(_5000);
            bool _5057 = _5013 && _5026;
            float _14388;
            if (_5057)
            {
                _14388 = 1.0f;
            }
            else
            {
                _14388 = (_5013 || _5026) ? 0.5f : 0.0f;
            }
            bool _14403;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4987)) && (!_5000))
            {
                bool _5087;
                if (_5057)
                {
                    float _14396;
                    do
                    {
                        bool _9987 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                        bool _9993;
                        if (_9987)
                        {
                            _9993 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9993 = _9987;
                        }
                        bool _9924 = !_9993;
                        bool _9931;
                        if (!_9924)
                        {
                            bool _9998 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                            bool _10004;
                            if (_9998)
                            {
                                _10004 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10004 = _9998;
                            }
                            _9931 = !_10004;
                        }
                        else
                        {
                            _9931 = _9924;
                        }
                        if (_9931)
                        {
                            _14396 = 0.0f;
                            break;
                        }
                        uint _10011_dummy_parameter;
                        uint _10027_dummy_parameter;
                        float4x4 _14395;
                        do
                        {
                            float4x4 _10041;
                            bool _14394;
                            do
                            {
                                _10041 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14394 = false;
                                    break;
                                }
                                uint _10075 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10075 + 32u) * 4 + 0) != 1u)
                                {
                                    _14394 = false;
                                    break;
                                }
                                uint _14391;
                                _14391 = 0u;
                                for (; _14391 < 4u; _14391++)
                                {
                                    for (uint _14392 = 0u; _14392 < 4u; )
                                    {
                                        _10041[_14391][_14392] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10075 + 16u) + (_14391 * 4u)) + _14392) * 4 + 0));
                                        _14392++;
                                        continue;
                                    }
                                }
                                _14394 = true;
                                break;
                            } while(false);
                            if (_14394)
                            {
                                _14395 = _10041;
                                break;
                            }
                            _14395 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _9952 = mul(float4((float2(_14039.x, 1.0f - _14039.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10011_dummy_parameter))))), 0)).x, 1.0f), _14395);
                        float _9954 = _9952.w;
                        if (abs(_9954) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14396 = 0.0f;
                            break;
                        }
                        float _9965 = abs(cbFI_DeviceToViewDepth.y / ((_9952.z / _9954) - cbFI_DeviceToViewDepth.x));
                        float _9968 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10027_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14396 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9965 - _9968) / max(max(_9965, _9968), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5087 = _14396 >= 0.5f;
                }
                else
                {
                    _5087 = _5057;
                }
                bool _5095;
                if (_5087)
                {
                    _5095 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5095 = _5087;
                }
                bool _14404;
                if (_5095)
                {
                    uint _10179_dummy_parameter;
                    float4x4 _14401;
                    do
                    {
                        float4x4 _10193;
                        bool _14400;
                        do
                        {
                            _10193 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14400 = false;
                                break;
                            }
                            uint _10227 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10227 + 32u) * 4 + 0) != 1u)
                            {
                                _14400 = false;
                                break;
                            }
                            uint _14397;
                            _14397 = 0u;
                            for (; _14397 < 4u; _14397++)
                            {
                                for (uint _14398 = 0u; _14398 < 4u; )
                                {
                                    _10193[_14397][_14398] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10227 + 16u) + (_14397 * 4u)) + _14398) * 4 + 0));
                                    _14398++;
                                    continue;
                                }
                            }
                            _14400 = true;
                            break;
                        } while(false);
                        if (_14400)
                        {
                            _14401 = _10193;
                            break;
                        }
                        _14401 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14402;
                    do
                    {
                        float _10307 = 1.0f - _14039.y;
                        float4 _10318 = mul(float4((float2(_14039.x, _10307) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10179_dummy_parameter))))), 0)).x, 1.0f), _14401);
                        float _10320 = _10318.w;
                        if (!(_10320 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14402 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10333 = ((_10318.xy / _10320.xx) + 1.0f.xx) * 0.5f;
                        _14402 = float2(_10333.x - _14039.x, _10307 - _10333.y);
                        break;
                    } while(false);
                    float2 _5108 = float2(cbFI_DisplaySize);
                    _14404 = length(((_14039 + _14402) - _14040) * _5108) <= ((0.100000001490116119384765625f * length(_14402 * _5108)) + 8.0f);
                }
                else
                {
                    _14404 = _5087;
                }
                _14403 = _14404;
            }
            else
            {
                _14403 = true;
            }
            bool _5122 = !_14403;
            bool _17125 = _5122 ? false : _5026;
            bool _17126 = _5122 ? false : _5013;
            bool _14481;
            float4 _14520;
            if (!(((_4987 && _5000) && _17126) && _17125))
            {
                float4 _5144 = _14459 * float4(_5052, _5054, float(_17126), float(_17125));
                float _5146 = dot(_5144, 1.0f.xxxx);
                bool _5149 = !(_5146 > 0.0f);
                float4 _14521;
                if (!_5149)
                {
                    _14521 = _5144 / _5146.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10355;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10355);
                    }
                    _14521 = 0.0f.xxxx;
                }
                _14520 = _14521;
                _14481 = _5149;
            }
            else
            {
                _14520 = _14459;
                _14481 = false;
            }
            _16188 = float3(_5052, _5054, _14388);
            _14519 = _14520;
            _14480 = _14481;
        }
        else
        {
            _16188 = float3(float(_9799), _4971, 0.0f);
            _14519 = _14459;
            _14480 = false;
        }
        bool _5167 = !_14480;
        float4 _14612;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5167)
        {
            float _5174 = _14519.x + _14519.y;
            float4 _14613;
            if (_5174 > 0.001000000047497451305389404296875f)
            {
                _14613 = float4(_14519.x / _5174, _14519.y / _5174, 0.0f, 0.0f);
            }
            else
            {
                _14613 = float4(_4736, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14612 = _14613;
        }
        else
        {
            _14612 = _14519;
        }
        float4 _14789;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5167) && _9799)
        {
            float _14586;
            do
            {
                uint4 _10495 = r_warped_motion_qdata_tp1.Load(int3(_14257, 0));
                uint _10496 = _10495.x;
                if (_10496 != 0u)
                {
                    float _14585;
                    if (_10496 == 0u)
                    {
                        _14585 = -1.0f;
                    }
                    else
                    {
                        _14585 = float((_10496 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14586 = _14585;
                    break;
                }
                int _14568;
                uint _14569;
                _14569 = _10496;
                _14568 = -1;
                uint _14584;
                for (; _14568 <= 1; _14569 = _14584, _14568++)
                {
                    _14584 = _14569;
                    for (int _14582 = -1; _14582 <= 1; )
                    {
                        _14584 = max(_14584, r_warped_motion_qdata_tp1.Load(int3(clamp(_14257 + int2(_14582, _14568), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14582++;
                        continue;
                    }
                }
                if (_14569 != 0u)
                {
                    float _14581;
                    if (_14569 == 0u)
                    {
                        _14581 = -1.0f;
                    }
                    else
                    {
                        _14581 = float((_14569 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14586 = _14581;
                    break;
                }
                uint _14571;
                _14571 = 4294967295u;
                uint _17096;
                for (int _14570 = 0; _14570 < 8; _14571 = _17096, _14570++)
                {
                    int _14574 = 0;
                    for (;;)
                    {
                        if (_14574 < 5)
                        {
                            int2 _10446 = _14257 + (_1184[_14570] * _1193[_14574].xx);
                            bool _10449 = any(bool2(_10446.x < int2(0, 0).x, _10446.y < int2(0, 0).y));
                            bool _10457;
                            if (!_10449)
                            {
                                _10457 = any(bool2(_10446.x >= cbFI_MvDepthLaneSize.x, _10446.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10457 = _10449;
                            }
                            if (_10457)
                            {
                                _17096 = _14571;
                                break;
                            }
                            uint4 _10535 = r_warped_motion_qdata_tp1.Load(int3(_10446, 0));
                            uint _10536 = _10535.x;
                            if (_10536 != 0u)
                            {
                                _17096 = min(_14571, _10536);
                                break;
                            }
                            _14574++;
                            continue;
                        }
                        else
                        {
                            _17096 = _14571;
                            break;
                        }
                    }
                }
                float _14573;
                if (_14571 == 4294967295u)
                {
                    _14573 = -1.0f;
                }
                else
                {
                    float _14572;
                    if (_14571 == 0u)
                    {
                        _14572 = -1.0f;
                    }
                    else
                    {
                        _14572 = float((_14571 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14573 = _14572;
                }
                _14586 = _14573;
                break;
            } while(false);
            float _5210 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5213 = r_warped_motion_qdata_tp1.Load(int3(_14257, 0)).x == 0u;
            bool _5219;
            if (_5213)
            {
                bool _10561 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
                bool _10567;
                if (_10561)
                {
                    _10567 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
                }
                else
                {
                    _10567 = _10561;
                }
                _5219 = _10567;
            }
            else
            {
                _5219 = _5213;
            }
            bool _5224;
            if (_5219)
            {
                bool _10572 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
                bool _10578;
                if (_10572)
                {
                    _10578 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
                }
                else
                {
                    _10578 = _10572;
                }
                _5224 = _10578;
            }
            else
            {
                _5224 = _5219;
            }
            bool _14598;
            float4 _14607;
            if (_5224)
            {
                uint _10585_dummy_parameter;
                float _10609 = log((r_depth_tm1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10585_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _10617_dummy_parameter;
                float _10641 = log((r_depth_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10617_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _5235 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5242;
                if (_5235)
                {
                    _5242 = _10641 > (_10609 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5242 = _5235;
                }
                bool _14603;
                float4 _14625;
                if (_5242)
                {
                    _14625 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14603 = true;
                }
                else
                {
                    bool _5248 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5255;
                    if (_5248)
                    {
                        _5255 = _10609 > (_10641 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5255 = _5248;
                    }
                    bool4 _17127 = _5255.xxxx;
                    _14625 = float4(_17127.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14612.x, _17127.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14612.y, _17127.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14612.z, _17127.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14612.w);
                    _14603 = _5255 ? true : false;
                }
                _14607 = _14625;
                _14598 = _14603;
            }
            else
            {
                _14607 = _14612;
                _14598 = false;
            }
            float4 _14680;
            if (_14598)
            {
                _14680 = 1.0f.xxxx;
            }
            else
            {
                bool _5266 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5272;
                if (_5266)
                {
                    _5272 = _14607.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5272 = _5266;
                }
                bool _5277;
                if (_5272)
                {
                    bool _10647 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
                    bool _10653;
                    if (_10647)
                    {
                        _10653 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10653 = _10647;
                    }
                    _5277 = _10653;
                }
                else
                {
                    _5277 = _5272;
                }
                float4 _14681;
                if (_5277)
                {
                    float _14634;
                    if (_14586 >= 0.0f)
                    {
                        _14634 = _14586 - _5210;
                    }
                    else
                    {
                        float _14630;
                        _14630 = 2.0f;
                        float _10710;
                        for (int _14629 = 0; _14629 < 24; _14630 = _10710, _14629++)
                        {
                            float _10674 = float(_14629 & 7) * 0.785398185253143310546875f;
                            int _10676 = _14629 >> 3;
                            int _14631;
                            if (_10676 == 0)
                            {
                                _14631 = 16;
                            }
                            else
                            {
                                _14631 = (_10676 == 1) ? 48 : 96;
                            }
                            uint _10742_dummy_parameter;
                            _10710 = min(_14630, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14038 + ((cbFI_MvDepthLaneSizeRcp * float(_14631)) * float2(cos(_10674), sin(_10674))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10742_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14634 = _14630;
                    }
                    uint _10774_dummy_parameter;
                    float4 _14682;
                    if (r_depth_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10774_dummy_parameter))))), 0)).x > ((exp((_14634 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14682 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14682 = 1.0f.xxxx;
                    }
                    _14681 = _14682;
                }
                else
                {
                    _14681 = 1.0f.xxxx;
                }
                _14680 = _14681;
            }
            bool _5305 = _14586 >= 0.0f;
            bool _5306 = (!_14598) && _5305;
            bool _5313;
            if (_5306)
            {
                _5313 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5313 = _5306;
            }
            bool _5319;
            if (_5313)
            {
                _5319 = _14607.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5319 = _5313;
            }
            bool _5324;
            if (_5319)
            {
                bool _10798 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
                bool _10804;
                if (_10798)
                {
                    _10804 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
                }
                else
                {
                    _10804 = _10798;
                }
                _5324 = _10804;
            }
            else
            {
                _5324 = _5319;
            }
            float4 _14705;
            if (_5324)
            {
                float _14674;
                if (_5305)
                {
                    _14674 = _14586 - _5210;
                }
                else
                {
                    float _14670;
                    _14670 = 2.0f;
                    float _10861;
                    for (int _14669 = 0; _14669 < 24; _14670 = _10861, _14669++)
                    {
                        float _10825 = float(_14669 & 7) * 0.785398185253143310546875f;
                        int _10827 = _14669 >> 3;
                        int _14671;
                        if (_10827 == 0)
                        {
                            _14671 = 16;
                        }
                        else
                        {
                            _14671 = (_10827 == 1) ? 48 : 96;
                        }
                        uint _10877_dummy_parameter;
                        _10861 = min(_14670, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14036 + ((cbFI_MvDepthLaneSizeRcp * float(_14671)) * float2(cos(_10825), sin(_10825))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10877_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14674 = _14670;
                }
                uint _10925_dummy_parameter;
                float4 _14706;
                if (r_depth_tm1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10925_dummy_parameter))))), 0)).x > ((exp((_14674 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _13868 = _14680;
                    _13868.x = 0.0f;
                    _14706 = _13868;
                }
                else
                {
                    _14706 = _14680;
                }
                _14705 = _14706;
            }
            else
            {
                _14705 = _14680;
            }
            float4 _14718;
            if (_5306)
            {
                float _10951 = (exp(((_14586 - _5210) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5362 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5368;
                if (_5362)
                {
                    _5368 = _14607.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5368 = _5362;
                }
                bool _5373;
                if (_5368)
                {
                    bool _10956 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                    bool _10962;
                    if (_10956)
                    {
                        _10962 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10962 = _10956;
                    }
                    _5373 = _10962;
                }
                else
                {
                    _5373 = _5368;
                }
                bool _5381;
                if (_5373)
                {
                    uint _10969_dummy_parameter;
                    _5381 = r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10969_dummy_parameter))))), 0)).x > _10951;
                }
                else
                {
                    _5381 = _5373;
                }
                float4 _14716;
                if (_5381)
                {
                    float4 _13871 = _14705;
                    _13871.w = 0.0f;
                    _14716 = _13871;
                }
                else
                {
                    _14716 = _14705;
                }
                bool _5388 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5394;
                if (_5388)
                {
                    _5394 = _14607.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5394 = _5388;
                }
                bool _5399;
                if (_5394)
                {
                    bool _10986 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                    bool _10992;
                    if (_10986)
                    {
                        _10992 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10992 = _10986;
                    }
                    _5399 = _10992;
                }
                else
                {
                    _5399 = _5394;
                }
                bool _5407;
                if (_5399)
                {
                    uint _10999_dummy_parameter;
                    _5407 = r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10999_dummy_parameter))))), 0)).x > _10951;
                }
                else
                {
                    _5407 = _5399;
                }
                float4 _14719;
                if (_5407)
                {
                    float4 _13874 = _14716;
                    _13874.z = 0.0f;
                    _14719 = _13874;
                }
                else
                {
                    _14719 = _14716;
                }
                _14718 = _14719;
            }
            else
            {
                _14718 = _14705;
            }
            float4 _14790;
            if (any(bool4(_14718.x < 1.0f.xxxx.x, _14718.y < 1.0f.xxxx.y, _14718.z < 1.0f.xxxx.z, _14718.w < 1.0f.xxxx.w)))
            {
                float4 _5418 = _14607 * _14718;
                float _5420 = dot(_5418, 1.0f.xxxx);
                float4 _14791;
                if (_5420 > 0.0f)
                {
                    _14791 = _5418 / _5420.xxxx;
                }
                else
                {
                    bool _5431 = _14718.y == 0.0f;
                    bool _5437;
                    if (_5431)
                    {
                        _5437 = _14718.x > 0.0f;
                    }
                    else
                    {
                        _5437 = _5431;
                    }
                    bool _5442;
                    if (_5437)
                    {
                        bool _11016 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
                        bool _11022;
                        if (_11016)
                        {
                            _11022 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11022 = _11016;
                        }
                        _5442 = _11022;
                    }
                    else
                    {
                        _5442 = _5437;
                    }
                    float4 _14792;
                    if (_5442)
                    {
                        _14792 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5447 = _14718.x == 0.0f;
                        bool _5453;
                        if (_5447)
                        {
                            _5453 = _14718.y > 0.0f;
                        }
                        else
                        {
                            _5453 = _5447;
                        }
                        bool _5458;
                        if (_5453)
                        {
                            bool _11027 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
                            bool _11033;
                            if (_11027)
                            {
                                _11033 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11033 = _11027;
                            }
                            _5458 = _11033;
                        }
                        else
                        {
                            _5458 = _5453;
                        }
                        bool4 _17130 = _5458.xxxx;
                        _14792 = float4(_17130.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14607.x, _17130.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14607.y, _17130.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14607.z, _17130.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14607.w);
                    }
                    _14791 = _14792;
                }
                _14790 = _14791;
            }
            else
            {
                _14790 = _14607;
            }
            _14789 = _14790;
        }
        else
        {
            _14789 = _14612;
        }
        float4 _15519;
        bool _15825;
        float3 _15958;
        if (((cbFI_pad0 & 32768u) != 0u) && _5167)
        {
            bool _5475 = _14789.x > 0.00999999977648258209228515625f;
            bool _5478 = _14789.y > 0.00999999977648258209228515625f;
            bool _5487 = (_14789.z + _14789.w) > 0.0199999995529651641845703125f;
            bool _5493;
            if (_5487)
            {
                bool _11038 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                bool _11044;
                if (_11038)
                {
                    _11044 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                }
                else
                {
                    _11044 = _11038;
                }
                _5493 = _11044;
            }
            else
            {
                _5493 = _5487;
            }
            bool _5498;
            if (_5493)
            {
                bool _11049 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                bool _11055;
                if (_11049)
                {
                    _11055 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                }
                else
                {
                    _11055 = _11049;
                }
                _5498 = _11055;
            }
            else
            {
                _5498 = _5493;
            }
            bool _5505;
            if (_5498)
            {
                float _14805;
                do
                {
                    bool _11138 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                    bool _11144;
                    if (_11138)
                    {
                        _11144 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11144 = _11138;
                    }
                    bool _11075 = !_11144;
                    bool _11082;
                    if (!_11075)
                    {
                        bool _11149 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                        bool _11155;
                        if (_11149)
                        {
                            _11155 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11155 = _11149;
                        }
                        _11082 = !_11155;
                    }
                    else
                    {
                        _11082 = _11075;
                    }
                    if (_11082)
                    {
                        _14805 = 0.0f;
                        break;
                    }
                    uint _11162_dummy_parameter;
                    uint _11178_dummy_parameter;
                    float4x4 _14804;
                    do
                    {
                        float4x4 _11192;
                        bool _14803;
                        do
                        {
                            _11192 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14803 = false;
                                break;
                            }
                            uint _11226 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11226 + 32u) * 4 + 0) != 1u)
                            {
                                _14803 = false;
                                break;
                            }
                            uint _14800;
                            _14800 = 0u;
                            for (; _14800 < 4u; _14800++)
                            {
                                for (uint _14801 = 0u; _14801 < 4u; )
                                {
                                    _11192[_14800][_14801] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11226 + 16u) + (_14800 * 4u)) + _14801) * 4 + 0));
                                    _14801++;
                                    continue;
                                }
                            }
                            _14803 = true;
                            break;
                        } while(false);
                        if (_14803)
                        {
                            _14804 = _11192;
                            break;
                        }
                        _14804 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11103 = mul(float4((float2(_14039.x, 1.0f - _14039.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11162_dummy_parameter))))), 0)).x, 1.0f), _14804);
                    float _11105 = _11103.w;
                    if (abs(_11105) < 9.9999999747524270787835121154785e-07f)
                    {
                        _14805 = 0.0f;
                        break;
                    }
                    float _11116 = abs(cbFI_DeviceToViewDepth.y / ((_11103.z / _11105) - cbFI_DeviceToViewDepth.x));
                    float _11119 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11178_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _14805 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11116 - _11119) / max(max(_11116, _11119), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5505 = _14805 < 0.5f;
            }
            else
            {
                _5505 = _5498;
            }
            float4 _14824;
            if (_5505)
            {
                uint _11330_dummy_parameter;
                uint _11361_dummy_parameter;
                float4 _14825;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11330_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11361_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _14825 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _14825 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _14824 = _14825;
            }
            else
            {
                _14824 = 1.0f.xxxx;
            }
            bool _5529;
            if (_9799)
            {
                bool _11390 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
                bool _11396;
                if (_11390)
                {
                    _11396 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
                }
                else
                {
                    _11396 = _11390;
                }
                _5529 = _11396;
            }
            else
            {
                _5529 = _9799;
            }
            bool _5535;
            if (_9799)
            {
                bool _11401 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
                bool _11407;
                if (_11401)
                {
                    _11407 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
                }
                else
                {
                    _11407 = _11401;
                }
                _5535 = _11407;
            }
            else
            {
                _5535 = _9799;
            }
            bool _5541;
            if (_9831)
            {
                bool _11412 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                bool _11418;
                if (_11412)
                {
                    _11418 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                }
                else
                {
                    _11418 = _11412;
                }
                _5541 = _11418;
            }
            else
            {
                _5541 = _9831;
            }
            bool _5547;
            if (_9831)
            {
                bool _11423 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                bool _11429;
                if (_11423)
                {
                    _11429 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                }
                else
                {
                    _11429 = _11423;
                }
                _5547 = _11429;
            }
            else
            {
                _5547 = _9831;
            }
            bool _5550 = _5541 != _5547;
            bool _5556;
            if (_5550)
            {
                _5556 = _5529 || _5535;
            }
            else
            {
                _5556 = _5550;
            }
            float4 _14927;
            if (_5556)
            {
                float4 _13901 = _14824;
                _13901.z = 0.0f;
                _13901.w = 0.0f;
                _14927 = _13901;
            }
            else
            {
                _14927 = _14824;
            }
            bool _5563 = _5529 && _5475;
            bool _5566 = _5535 && _5478;
            float4 _15032;
            float3 _16067;
            if (_5563 || _5566)
            {
                float _14922;
                do
                {
                    uint4 _11568 = r_warped_motion_qdata_tp1.Load(int3(_14257, 0));
                    uint _11569 = _11568.x;
                    if (_11569 != 0u)
                    {
                        float _14921;
                        if (_11569 == 0u)
                        {
                            _14921 = -1.0f;
                        }
                        else
                        {
                            _14921 = float((_11569 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14922 = _14921;
                        break;
                    }
                    int _14904;
                    uint _14905;
                    _14905 = _11569;
                    _14904 = -1;
                    uint _14920;
                    for (; _14904 <= 1; _14905 = _14920, _14904++)
                    {
                        _14920 = _14905;
                        for (int _14918 = -1; _14918 <= 1; )
                        {
                            _14920 = max(_14920, r_warped_motion_qdata_tp1.Load(int3(clamp(_14257 + int2(_14918, _14904), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _14918++;
                            continue;
                        }
                    }
                    if (_14905 != 0u)
                    {
                        float _14917;
                        if (_14905 == 0u)
                        {
                            _14917 = -1.0f;
                        }
                        else
                        {
                            _14917 = float((_14905 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14922 = _14917;
                        break;
                    }
                    uint _14907;
                    _14907 = 4294967295u;
                    uint _17097;
                    for (int _14906 = 0; _14906 < 8; _14907 = _17097, _14906++)
                    {
                        int _14910 = 0;
                        for (;;)
                        {
                            if (_14910 < 5)
                            {
                                int2 _11519 = _14257 + (_1184[_14906] * _1193[_14910].xx);
                                bool _11522 = any(bool2(_11519.x < int2(0, 0).x, _11519.y < int2(0, 0).y));
                                bool _11530;
                                if (!_11522)
                                {
                                    _11530 = any(bool2(_11519.x >= cbFI_MvDepthLaneSize.x, _11519.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11530 = _11522;
                                }
                                if (_11530)
                                {
                                    _17097 = _14907;
                                    break;
                                }
                                uint4 _11608 = r_warped_motion_qdata_tp1.Load(int3(_11519, 0));
                                uint _11609 = _11608.x;
                                if (_11609 != 0u)
                                {
                                    _17097 = min(_14907, _11609);
                                    break;
                                }
                                _14910++;
                                continue;
                            }
                            else
                            {
                                _17097 = _14907;
                                break;
                            }
                        }
                    }
                    float _14909;
                    if (_14907 == 4294967295u)
                    {
                        _14909 = -1.0f;
                    }
                    else
                    {
                        float _14908;
                        if (_14907 == 0u)
                        {
                            _14908 = -1.0f;
                        }
                        else
                        {
                            _14908 = float((_14907 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14909 = _14908;
                    }
                    _14922 = _14909;
                    break;
                } while(false);
                bool _5574 = _14922 < 0.0f;
                float _14923;
                if (_5574)
                {
                    _14923 = 0.0f;
                }
                else
                {
                    _14923 = _14922 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11630_dummy_parameter;
                uint _11662_dummy_parameter;
                float4 _14960;
                if ((_5574 && _5563) && _5566)
                {
                    uint _11694_dummy_parameter;
                    float _11718 = log((r_depth_tm1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11694_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11726_dummy_parameter;
                    float _11750 = log((r_depth_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11726_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _14961;
                    if (_11718 > (_11750 + 0.07999999821186065673828125f))
                    {
                        float4 _13905 = _14927;
                        _13905.x = 0.0f;
                        _14961 = _13905;
                    }
                    else
                    {
                        float4 _14962;
                        if (_11750 > (_11718 + 0.07999999821186065673828125f))
                        {
                            float4 _13907 = _14927;
                            _13907.y = 0.0f;
                            _14962 = _13907;
                        }
                        else
                        {
                            _14962 = _14927;
                        }
                        _14961 = _14962;
                    }
                    _14960 = _14961;
                }
                else
                {
                    _14960 = _14927;
                }
                float _5626 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5628 = _14922 >= 0.0f;
                float _14943;
                if (_5628)
                {
                    _14943 = _14922 - _5626;
                }
                else
                {
                    float _14939;
                    if (_5563)
                    {
                        float _14938;
                        _14938 = 2.0f;
                        float _11808;
                        for (int _14937 = 0; _14937 < 24; _14938 = _11808, _14937++)
                        {
                            float _11772 = float(_14937 & 7) * 0.785398185253143310546875f;
                            int _11774 = _14937 >> 3;
                            int _14940;
                            if (_11774 == 0)
                            {
                                _14940 = 16;
                            }
                            else
                            {
                                _14940 = (_11774 == 1) ? 48 : 96;
                            }
                            uint _11824_dummy_parameter;
                            _11808 = min(_14938, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14036 + ((cbFI_MvDepthLaneSizeRcp * float(_14940)) * float2(cos(_11772), sin(_11772))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11824_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14939 = _14938;
                    }
                    else
                    {
                        _14939 = 0.0f;
                    }
                    _14943 = _14939;
                }
                float _14950;
                if (_5628)
                {
                    _14950 = _14922 - _5626;
                }
                else
                {
                    float _14946;
                    if (_5566)
                    {
                        float _14945;
                        _14945 = 2.0f;
                        float _11922;
                        for (int _14944 = 0; _14944 < 24; _14945 = _11922, _14944++)
                        {
                            float _11886 = float(_14944 & 7) * 0.785398185253143310546875f;
                            int _11888 = _14944 >> 3;
                            int _14947;
                            if (_11888 == 0)
                            {
                                _14947 = 16;
                            }
                            else
                            {
                                _14947 = (_11888 == 1) ? 48 : 96;
                            }
                            uint _11954_dummy_parameter;
                            _11922 = min(_14945, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14038 + ((cbFI_MvDepthLaneSizeRcp * float(_14947)) * float2(cos(_11886), sin(_11886))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11954_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14946 = _14945;
                    }
                    else
                    {
                        _14946 = 0.0f;
                    }
                    _14950 = _14946;
                }
                float _14951;
                if (_5563)
                {
                    uint _11986_dummy_parameter;
                    _14951 = r_depth_tm1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11986_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _14951 = 0.0f;
                }
                float _14952;
                if (_5566)
                {
                    uint _12005_dummy_parameter;
                    _14952 = r_depth_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12005_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _14952 = 0.0f;
                }
                bool _5683;
                if (_5563)
                {
                    _5683 = _14951 > ((exp((_14943 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5683 = _5563;
                }
                float4 _14968;
                if (_5683)
                {
                    float4 _13909 = _14960;
                    _13909.x = 0.0f;
                    _14968 = _13909;
                }
                else
                {
                    _14968 = _14960;
                }
                bool _5695;
                if (_5566)
                {
                    _5695 = _14952 > ((exp((_14950 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5695 = _5566;
                }
                float4 _14970;
                if (_5695)
                {
                    float4 _13911 = _14968;
                    _13911.y = 0.0f;
                    _14970 = _13911;
                }
                else
                {
                    _14970 = _14968;
                }
                float4 _15033;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5628)
                {
                    bool _5715;
                    if (_5563)
                    {
                        _5715 = _14951 < ((exp((_14943 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5715 = _5563;
                    }
                    float4 _14972;
                    if (_5715)
                    {
                        float4 _13913 = _14970;
                        _13913.x = 0.0f;
                        _14972 = _13913;
                    }
                    else
                    {
                        _14972 = _14970;
                    }
                    bool _5727;
                    if (_5566)
                    {
                        _5727 = _14952 < ((exp((_14950 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5727 = _5566;
                    }
                    float4 _15034;
                    if (_5727)
                    {
                        float4 _13915 = _14972;
                        _13915.y = 0.0f;
                        _15034 = _13915;
                    }
                    else
                    {
                        _15034 = _14972;
                    }
                    _15033 = _15034;
                }
                else
                {
                    _15033 = _14970;
                }
                _16067 = float3(_14923, log((r_depth_tm1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11630_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_14038 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11662_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _15032 = _15033;
            }
            else
            {
                _16067 = float3(0.0f, 0.0f, 0.5f);
                _15032 = _14927;
            }
            bool _5738 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5487;
            bool _5744;
            if (_5738)
            {
                _5744 = _5541 || _5547;
            }
            else
            {
                _5744 = _5738;
            }
            float4 _15075;
            if (_5744)
            {
                float _15027;
                do
                {
                    uint4 _12184 = r_warped_motion_qdata_tp1.Load(int3(_14257, 0));
                    uint _12185 = _12184.x;
                    if (_12185 != 0u)
                    {
                        float _15026;
                        if (_12185 == 0u)
                        {
                            _15026 = -1.0f;
                        }
                        else
                        {
                            _15026 = float((_12185 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15027 = _15026;
                        break;
                    }
                    int _15009;
                    uint _15010;
                    _15010 = _12185;
                    _15009 = -1;
                    uint _15025;
                    for (; _15009 <= 1; _15010 = _15025, _15009++)
                    {
                        _15025 = _15010;
                        for (int _15023 = -1; _15023 <= 1; )
                        {
                            _15025 = max(_15025, r_warped_motion_qdata_tp1.Load(int3(clamp(_14257 + int2(_15023, _15009), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15023++;
                            continue;
                        }
                    }
                    if (_15010 != 0u)
                    {
                        float _15022;
                        if (_15010 == 0u)
                        {
                            _15022 = -1.0f;
                        }
                        else
                        {
                            _15022 = float((_15010 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15027 = _15022;
                        break;
                    }
                    uint _15012;
                    _15012 = 4294967295u;
                    uint _17098;
                    for (int _15011 = 0; _15011 < 8; _15012 = _17098, _15011++)
                    {
                        int _15015 = 0;
                        for (;;)
                        {
                            if (_15015 < 5)
                            {
                                int2 _12135 = _14257 + (_1184[_15011] * _1193[_15015].xx);
                                bool _12138 = any(bool2(_12135.x < int2(0, 0).x, _12135.y < int2(0, 0).y));
                                bool _12146;
                                if (!_12138)
                                {
                                    _12146 = any(bool2(_12135.x >= cbFI_MvDepthLaneSize.x, _12135.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12146 = _12138;
                                }
                                if (_12146)
                                {
                                    _17098 = _15012;
                                    break;
                                }
                                uint4 _12224 = r_warped_motion_qdata_tp1.Load(int3(_12135, 0));
                                uint _12225 = _12224.x;
                                if (_12225 != 0u)
                                {
                                    _17098 = min(_15012, _12225);
                                    break;
                                }
                                _15015++;
                                continue;
                            }
                            else
                            {
                                _17098 = _15012;
                                break;
                            }
                        }
                    }
                    float _15014;
                    if (_15012 == 4294967295u)
                    {
                        _15014 = -1.0f;
                    }
                    else
                    {
                        float _15013;
                        if (_15012 == 0u)
                        {
                            _15013 = -1.0f;
                        }
                        else
                        {
                            _15013 = float((_15012 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15014 = _15013;
                    }
                    _15027 = _15014;
                    break;
                } while(false);
                float4 _15076;
                if (_15027 >= 0.0f)
                {
                    float _12246 = (exp((_15027 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5763;
                    if (_5541)
                    {
                        uint _12253_dummy_parameter;
                        _5763 = r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12253_dummy_parameter))))), 0)).x > _12246;
                    }
                    else
                    {
                        _5763 = _5541;
                    }
                    float4 _15045;
                    if (_5763)
                    {
                        float4 _13917 = _15032;
                        _13917.z = 0.0f;
                        _15045 = _13917;
                    }
                    else
                    {
                        _15045 = _15032;
                    }
                    bool _5775;
                    if (_5547)
                    {
                        uint _12272_dummy_parameter;
                        _5775 = r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12272_dummy_parameter))))), 0)).x > _12246;
                    }
                    else
                    {
                        _5775 = _5547;
                    }
                    float4 _15077;
                    if (_5775)
                    {
                        float4 _13919 = _15045;
                        _13919.w = 0.0f;
                        _15077 = _13919;
                    }
                    else
                    {
                        _15077 = _15045;
                    }
                    _15076 = _15077;
                }
                else
                {
                    _15076 = _15032;
                }
                _15075 = _15076;
            }
            else
            {
                _15075 = _15032;
            }
            bool _5783 = _5529 != _5535;
            bool _5790;
            if (_5783)
            {
                _5790 = _5529 ? _5475 : _5478;
            }
            else
            {
                _5790 = _5783;
            }
            bool _5797;
            if (_5790)
            {
                _5797 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5797 = _5790;
            }
            float4 _15178;
            if (_5797)
            {
                bool2 _5802 = _5529.xx;
                float2 _5803 = float2(_5802.x ? _14036.x : _14038.x, _5802.y ? _14036.y : _14038.y);
                float _15059;
                if (_5529)
                {
                    uint _12291_dummy_parameter;
                    _15059 = r_depth_tm1.Load(int3(int2(floor(_5803 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12291_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12307_dummy_parameter;
                    _15059 = r_depth_tp1.Load(int3(int2(floor(_5803 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12307_dummy_parameter))))), 0)).x;
                }
                float4x4 _15066;
                if (_5529)
                {
                    float4x4 _15055;
                    do
                    {
                        float4x4 _12321;
                        bool _15054;
                        do
                        {
                            _12321 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15054 = false;
                                break;
                            }
                            uint _12355 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12355 + 32u) * 4 + 0) != 1u)
                            {
                                _15054 = false;
                                break;
                            }
                            uint _15051;
                            _15051 = 0u;
                            for (; _15051 < 4u; _15051++)
                            {
                                for (uint _15052 = 0u; _15052 < 4u; )
                                {
                                    _12321[_15051][_15052] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12355 + 16u) + (_15051 * 4u)) + _15052) * 4 + 0));
                                    _15052++;
                                    continue;
                                }
                            }
                            _15054 = true;
                            break;
                        } while(false);
                        if (_15054)
                        {
                            _15055 = _12321;
                            break;
                        }
                        _15055 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15066 = _15055;
                }
                else
                {
                    float4x4 _15050;
                    do
                    {
                        float4x4 _12427;
                        bool _15049;
                        do
                        {
                            _12427 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15049 = false;
                                break;
                            }
                            uint _12461 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12461 + 32u) * 4 + 0) != 1u)
                            {
                                _15049 = false;
                                break;
                            }
                            uint _15046;
                            _15046 = 0u;
                            for (; _15046 < 4u; _15046++)
                            {
                                for (uint _15047 = 0u; _15047 < 4u; )
                                {
                                    _12427[_15046][_15047] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12461 + (_15046 * 4u)) + _15047) * 4 + 0));
                                    _15047++;
                                    continue;
                                }
                            }
                            _15049 = true;
                            break;
                        } while(false);
                        if (_15049)
                        {
                            _15050 = _12427;
                            break;
                        }
                        _15050 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15066 = _15050;
                }
                float2 _15067;
                do
                {
                    float _12538 = _5803.x;
                    float _12541 = 1.0f - _5803.y;
                    float4 _12552 = mul(float4((float2(_12538, _12541) * 2.0f) - 1.0f.xx, _15059, 1.0f), _15066);
                    float _12554 = _12552.w;
                    if (!(_12554 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15067 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12567 = ((_12552.xy / _12554.xx) + 1.0f.xx) * 0.5f;
                    _15067 = float2(_12567.x - _12538, _12541 - _12567.y);
                    break;
                } while(false);
                float2 _5833 = float2(cbFI_DisplaySize);
                float4 _15179;
                if (!(length(((_5803 + _15067) - float2(_5802.x ? _14038.x : _14036.x, _5802.y ? _14038.y : _14036.y)) * _5833) <= ((0.100000001490116119384765625f * length(_15067 * _5833)) + 8.0f)))
                {
                    float4 _15180;
                    if (_5529)
                    {
                        float4 _13929 = _15075;
                        _13929.x = 0.0f;
                        _15180 = _13929;
                    }
                    else
                    {
                        float4 _13931 = _15075;
                        _13931.y = 0.0f;
                        _15180 = _13931;
                    }
                    _15179 = _15180;
                }
                else
                {
                    _15179 = _15075;
                }
                _15178 = _15179;
            }
            else
            {
                _15178 = _15075;
            }
            float4 _5858 = _14789 * _15178;
            float _5860 = dot(_5858, 1.0f.xxxx);
            float4 _15520;
            bool _15826;
            if (_5860 > 0.0f)
            {
                _15826 = _14480;
                _15520 = _5858 / _5860.xxxx;
            }
            else
            {
                bool _5871 = any(bool4(_15178.x < 1.0f.xxxx.x, _15178.y < 1.0f.xxxx.y, _15178.z < 1.0f.xxxx.z, _15178.w < 1.0f.xxxx.w));
                if (_5871)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12589;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12589);
                    }
                }
                bool4 _17133 = _5871.xxxx;
                _15826 = _5871 ? true : _14480;
                _15520 = float4(_17133.x ? 0.0f.xxxx.x : _14789.x, _17133.y ? 0.0f.xxxx.y : _14789.y, _17133.z ? 0.0f.xxxx.z : _14789.z, _17133.w ? 0.0f.xxxx.w : _14789.w);
            }
            _15958 = _16067;
            _15825 = _15826;
            _15519 = _15520;
        }
        else
        {
            _15958 = float3(0.0f, 0.0f, 0.5f);
            _15825 = _14480;
            _15519 = _14789;
        }
        uint _5880 = (cbFI_pad0 >> 24u) & 31u;
        uint _5884 = (cbFI_pad0 >> 16u) & 255u;
        bool _5886 = _5880 != 0u;
        bool _5888 = _5884 == 12u;
        bool _5891 = _5884 == 13u;
        float4 _15540;
        if ((_5886 || _5888) || _5891)
        {
            float _15186;
            do
            {
                bool _12673 = all(bool2(_14039.x > 0.0f.xx.x, _14039.y > 0.0f.xx.y));
                bool _12679;
                if (_12673)
                {
                    _12679 = all(bool2(_14039.x < 1.0f.xx.x, _14039.y < 1.0f.xx.y));
                }
                else
                {
                    _12679 = _12673;
                }
                bool _12610 = !_12679;
                bool _12617;
                if (!_12610)
                {
                    bool _12684 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
                    bool _12690;
                    if (_12684)
                    {
                        _12690 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12690 = _12684;
                    }
                    _12617 = !_12690;
                }
                else
                {
                    _12617 = _12610;
                }
                if (_12617)
                {
                    _15186 = 0.0f;
                    break;
                }
                uint _12697_dummy_parameter;
                uint _12713_dummy_parameter;
                float4x4 _15185;
                do
                {
                    float4x4 _12727;
                    bool _15184;
                    do
                    {
                        _12727 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15184 = false;
                            break;
                        }
                        uint _12761 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12761 + 32u) * 4 + 0) != 1u)
                        {
                            _15184 = false;
                            break;
                        }
                        uint _15181;
                        _15181 = 0u;
                        for (; _15181 < 4u; _15181++)
                        {
                            for (uint _15182 = 0u; _15182 < 4u; )
                            {
                                _12727[_15181][_15182] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12761 + 16u) + (_15181 * 4u)) + _15182) * 4 + 0));
                                _15182++;
                                continue;
                            }
                        }
                        _15184 = true;
                        break;
                    } while(false);
                    if (_15184)
                    {
                        _15185 = _12727;
                        break;
                    }
                    _15185 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12638 = mul(float4((float2(_14039.x, 1.0f - _14039.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14039 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12697_dummy_parameter))))), 0)).x, 1.0f), _15185);
                float _12640 = _12638.w;
                if (abs(_12640) < 9.9999999747524270787835121154785e-07f)
                {
                    _15186 = 0.0f;
                    break;
                }
                float _12651 = abs(cbFI_DeviceToViewDepth.y / ((_12638.z / _12640) - cbFI_DeviceToViewDepth.x));
                float _12654 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12713_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15186 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12651 - _12654) / max(max(_12651, _12654), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _12863 = all(bool2(_14040.x > 0.0f.xx.x, _14040.y > 0.0f.xx.y));
            bool _12869;
            if (_12863)
            {
                _12869 = all(bool2(_14040.x < 1.0f.xx.x, _14040.y < 1.0f.xx.y));
            }
            else
            {
                _12869 = _12863;
            }
            float _15187;
            if (_12869)
            {
                uint _12876_dummy_parameter;
                _15187 = length((_6697 + (r_motion_tp1.Load(int3(int2(floor(_14040 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12876_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15187 = 1000000.0f;
            }
            float _15202;
            if ((_5880 & 1u) != 0u)
            {
                _15202 = _15186;
            }
            else
            {
                _15202 = 1.0f;
            }
            float _15203;
            if ((_5880 & 2u) != 0u)
            {
                _15203 = _15202 * (1.0f - smoothstep(2.0f, 8.0f, _15187));
            }
            else
            {
                _15203 = _15202;
            }
            float _15204;
            if ((_5880 & 4u) != 0u)
            {
                _15204 = _15203 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7418 - _7426) - length(_7402 - _7410))));
            }
            else
            {
                _15204 = _15203;
            }
            float _15534;
            if ((_5880 & 8u) != 0u)
            {
                _15534 = lerp(1.0f, _15204, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7402 - _7410)));
            }
            else
            {
                _15534 = _15204;
            }
            bool _5966 = (_5880 & 16u) != 0u;
            bool _5975;
            if (_5966)
            {
                _5975 = length(_14034 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5975 = _5966;
            }
            float _17135 = _5975 ? 1.0f : _15534;
            bool _5981 = _5886 && _9799;
            bool _5986;
            if (_5981)
            {
                bool _12901 = all(bool2(_14036.x > 0.0f.xx.x, _14036.y > 0.0f.xx.y));
                bool _12907;
                if (_12901)
                {
                    _12907 = all(bool2(_14036.x < 1.0f.xx.x, _14036.y < 1.0f.xx.y));
                }
                else
                {
                    _12907 = _12901;
                }
                _5986 = _12907;
            }
            else
            {
                _5986 = _5981;
            }
            bool _5991;
            if (_5986)
            {
                bool _12912 = all(bool2(_14038.x > 0.0f.xx.x, _14038.y > 0.0f.xx.y));
                bool _12918;
                if (_12912)
                {
                    _12918 = all(bool2(_14038.x < 1.0f.xx.x, _14038.y < 1.0f.xx.y));
                }
                else
                {
                    _12918 = _12912;
                }
                _5991 = _12918;
            }
            else
            {
                _5991 = _5986;
            }
            float4 _15541;
            if (_5991)
            {
                float _5997 = _15519.x + _15519.y;
                float _6006 = (_15519.z + _15519.w) * (1.0f - _17135);
                float _15537;
                if (_5997 > 9.9999997473787516355514526367188e-06f)
                {
                    _15537 = _15519.x / _5997;
                }
                else
                {
                    _15537 = _4736;
                }
                _15541 = float4(_15519.x + (_6006 * _15537), _15519.y + (_6006 * (1.0f - _15537)), _15519.zw * _17135);
            }
            else
            {
                _15541 = _15519;
            }
            _15540 = _15541;
        }
        else
        {
            _15540 = _15519;
        }
        float3 _6067 = (((_7402 * _15540.x) + (_7410 * _15540.y)) + (_7418 * _15540.z)) + (_7426 * _15540.w);
        float3 _16900;
        if (_4752 && (_15555 > 0.0f))
        {
            uint _12925_dummy_parameter;
            float2 _12940 = r_motion_tp1.Load(int3(int2(floor(_4511 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12925_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _15817;
            if (_6725)
            {
                float2 _12985 = clamp((((_14013 + (_12940 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _12988 = tan(_12985.x);
                _15817 = (float2(_12988 / cbFI_DeviceToViewDepth.z, (tan(_12985.y) * sqrt(1.0f + (_12988 * _12988))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15817 = _14013 + (_12940 * cbFI_Timestep);
            }
            float2 _15818;
            if (_6725)
            {
                float2 _13064 = clamp((((_14013 + (_12940 * _4726)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13067 = tan(_13064.x);
                _15818 = (float2(_13067 / cbFI_DeviceToViewDepth.z, (tan(_13064.y) * sqrt(1.0f + (_13067 * _13067))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15818 = _14013 + (_12940 * _4726);
            }
            _16900 = lerp(_6067, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _15817, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _15818, 0.0f).xyz, cbFI_Timestep.xxx), _15555.xxx);
        }
        else
        {
            _16900 = _6067;
        }
        float3 _16899;
        if (_15825)
        {
            float3 _13109 = r_current_interpolation_source.Load(int3(_4050, 0)).xyz;
            float3 _16901;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9799)
            {
                uint _13116_dummy_parameter;
                float _15948;
                _15948 = r_depth_tm1.Load(int3(int2(floor(_14036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13116_dummy_parameter))))), 0)).x;
                float _6148;
                for (int _15947 = 0; _15947 < 24; _15948 = _6148, _15947++)
                {
                    float _6120 = float(_15947 & 7) * 0.785398185253143310546875f;
                    int _6122 = _15947 >> 3;
                    int _16951;
                    if (_6122 == 0)
                    {
                        _16951 = 16;
                    }
                    else
                    {
                        _16951 = (_6122 == 1) ? 48 : 96;
                    }
                    uint _13136_dummy_parameter;
                    _6148 = min(_15948, r_depth_tm1.Load(int3(int2(floor(clamp(_14036 + ((cbFI_MvDepthLaneSizeRcp * float(_16951)) * float2(cos(_6120), sin(_6120))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13136_dummy_parameter))))), 0)).x);
                }
                float2 _15949;
                do
                {
                    float _13158 = 1.0f - _14036.y;
                    float4 _13169 = mul(float4((float2(_14036.x, _13158) * 2.0f) - 1.0f.xx, _15948, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13171 = _13169.w;
                    if (!(_13171 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15949 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13184 = ((_13169.xy / _13171.xx) + 1.0f.xx) * 0.5f;
                    _15949 = float2(_13184.x - _14036.x, _13158 - _13184.y);
                    break;
                } while(false);
                float2 _6159 = _14036 + _15949;
                bool _13202 = all(bool2(_6159.x > 0.0f.xx.x, _6159.y > 0.0f.xx.y));
                bool _13208;
                if (_13202)
                {
                    _13208 = all(bool2(_6159.x < 1.0f.xx.x, _6159.y < 1.0f.xx.y));
                }
                else
                {
                    _13208 = _13202;
                }
                float3 _16902;
                if (_13208)
                {
                    float _6165 = abs(cbFI_DeviceToViewDepth.y / (_15948 - cbFI_DeviceToViewDepth.x));
                    uint _13228_dummy_parameter;
                    int2 _13228 = int2(spvTextureSize(r_depth_m2, uint(0), _13228_dummy_parameter));
                    float _6169 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6159 * float2(_13228))), int2(0, 0), _13228 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _16907;
                    if (abs(_6169 - _6165) <= (0.20000000298023223876953125f * max(_6169, _6165)))
                    {
                        uint _13262_dummy_parameter;
                        int2 _13262 = int2(spvTextureSize(r_colour_m2, uint(0), _13262_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13285;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13285);
                        }
                        _16907 = r_colour_m2.Load(int3(clamp(int2(floor(_6159 * float2(_13262))), int2(0, 0), _13262 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13295;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13295);
                        }
                        _16907 = _13109;
                    }
                    _16902 = _16907;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13305;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13305);
                    }
                    _16902 = _13109;
                }
                _16901 = _16902;
            }
            else
            {
                _16901 = _13109;
            }
            _16899 = _16901;
        }
        else
        {
            _16899 = _16900;
        }
        uint _6197 = cbFI_pad0 & 255u;
        bool _16776;
        float3 _16898;
        if (_6197 != 0u)
        {
            float3 _6202 = r_present_backbuffer.Load(int3(_4050, 0)).xyz;
            float3 _6206 = r_current_interpolation_source.Load(int3(_4050, 0)).xyz;
            float3 _6210 = abs(_6202 - _6206);
            float3 _15952;
            if (_6197 == 2u)
            {
                _15952 = (abs(_6206) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _15952 = 0.000244140625f.xxx;
            }
            bool _6226 = any(bool3(_6210.x > _15952.x, _6210.y > _15952.y, _6210.z > _15952.z));
            bool3 _17136 = _6226.xxx;
            _16898 = float3(_17136.x ? _6202.x : _16899.x, _17136.y ? _6202.y : _16899.y, _17136.z ? _6202.z : _16899.z);
            _16776 = _6226;
        }
        else
        {
            _16898 = _16899;
            _16776 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13320;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13320);
        }
        float3 _16881;
        if (_5884 == 1u)
        {
            _16881 = lerp(_7402, _7410, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _16882;
            if (_5884 == 2u)
            {
                _16882 = lerp(_7418, _7426, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _16883;
                if (_5884 == 3u)
                {
                    _16883 = float(_16776).xxx;
                }
                else
                {
                    float3 _16884;
                    if (_5884 == 4u)
                    {
                        _16884 = float3(((_14034 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _16885;
                        if (_5884 == 5u)
                        {
                            _16885 = float3(((_6697 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _16886;
                            if (_5884 == 6u)
                            {
                                _16886 = float3(_15540.xy, _15540.z + _15540.w);
                            }
                            else
                            {
                                float3 _16887;
                                if (_5884 == 7u)
                                {
                                    _16887 = r_current_interpolation_source.Load(int3(_4050, 0)).xyz;
                                }
                                else
                                {
                                    float3 _16888;
                                    if (_5884 == 8u)
                                    {
                                        _16888 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4511, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _16889;
                                        if (_5888)
                                        {
                                            uint _13342_dummy_parameter;
                                            uint _13374_dummy_parameter;
                                            _16889 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4511 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13342_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4511 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13374_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _16890;
                                            if (_5891)
                                            {
                                                _16890 = _7418;
                                            }
                                            else
                                            {
                                                float3 _16891;
                                                if (_5884 == 20u)
                                                {
                                                    _16891 = _7402;
                                                }
                                                else
                                                {
                                                    float3 _16892;
                                                    if (_5884 == 21u)
                                                    {
                                                        _16892 = _7410;
                                                    }
                                                    else
                                                    {
                                                        float3 _16893;
                                                        if (_5884 == 22u)
                                                        {
                                                            _16893 = _7426;
                                                        }
                                                        else
                                                        {
                                                            float3 _16894;
                                                            if (_5884 == 18u)
                                                            {
                                                                _16894 = _16424;
                                                            }
                                                            else
                                                            {
                                                                float3 _16895;
                                                                if (_5884 == 19u)
                                                                {
                                                                    _16895 = _16188;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _17138 = (_5884 == 23u).xxx;
                                                                    _16895 = float3(_17138.x ? _15958.x : _16898.x, _17138.y ? _15958.y : _16898.y, _17138.z ? _15958.z : _16898.z);
                                                                }
                                                                _16894 = _16895;
                                                            }
                                                            _16893 = _16894;
                                                        }
                                                        _16892 = _16893;
                                                    }
                                                    _16891 = _16892;
                                                }
                                                _16890 = _16891;
                                            }
                                            _16889 = _16890;
                                        }
                                        _16888 = _16889;
                                    }
                                    _16887 = _16888;
                                }
                                _16886 = _16887;
                            }
                            _16885 = _16886;
                        }
                        _16884 = _16885;
                    }
                    _16883 = _16884;
                }
                _16882 = _16883;
            }
            _16881 = _16882;
        }
        float3 _16880;
        if ((_5884 >= 9u) && (_5884 <= 11u))
        {
            uint _6390 = 64u + uint((_14257.y * cbFI_MvDepthLaneSize.x) + _14257.x);
            uint _6394 = rw_nfru_diagnostics.Load<uint>(_6390 * 4 + 0) & 15u;
            float3 _16912;
            if (_5884 == 10u)
            {
                float3 _16879;
                if ((rw_nfru_diagnostics.Load<uint>(_6390 * 4 + 0) & 32u) != 0u)
                {
                    _16879 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _16878;
                    if ((rw_nfru_diagnostics.Load<uint>(_6390 * 4 + 0) & 16u) != 0u)
                    {
                        _16878 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6415 = ((rw_nfru_diagnostics.Load<uint>(_6390 * 4 + 0) & 64u) != 0u).xxx;
                        _16878 = float3(_6415.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6415.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6415.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _16879 = _16878;
                }
                _16912 = _16879;
            }
            else
            {
                float3 _16913;
                if (_5884 == 11u)
                {
                    uint _6428 = (rw_nfru_diagnostics.Load<uint>(_6390 * 4 + 0) >> 8u) & 15u;
                    uint _6431 = (rw_nfru_diagnostics.Load<uint>(_6390 * 4 + 0) >> 12u) & 15u;
                    float3 _16871;
                    if ((_6394 == 2u) || (_6394 == 3u))
                    {
                        _16871 = _3763[_6394];
                    }
                    else
                    {
                        bool _6443 = _6428 == 3u;
                        bool _6445 = _6431 == 3u;
                        float3 _16872;
                        if (_6443 && _6445)
                        {
                            _16872 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _16873;
                            if (_6443)
                            {
                                _16873 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _16874;
                                if (_6445)
                                {
                                    _16874 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _16875;
                                    if ((_6428 == 4u) || (_6431 == 4u))
                                    {
                                        _16875 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _16876;
                                        if ((_6428 == 1u) || (_6431 == 1u))
                                        {
                                            _16876 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17140 = (_6394 == 1u).xxx;
                                            _16876 = float3(_17140.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17140.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17140.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _16875 = _16876;
                                    }
                                    _16874 = _16875;
                                }
                                _16873 = _16874;
                            }
                            _16872 = _16873;
                        }
                        _16871 = _16872;
                    }
                    _16913 = _16871;
                }
                else
                {
                    _16913 = _3763[min(_6394, 7u)];
                }
                _16912 = _16913;
            }
            _16880 = _16912;
        }
        else
        {
            _16880 = _16881;
        }
        float4 _16916;
        if ((_5884 >= 14u) && (_5884 <= 16u))
        {
            float2 _16914;
            if (_5884 == 14u)
            {
                uint _6501_dummy_parameter;
                uint _6507_dummy_parameter;
                _16914 = r_flow_tm1.Load(int3(clamp(int2(floor(_4511 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6501_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6507_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _16915;
                if (_5884 == 16u)
                {
                    uint _13425 = r_warped_flow_qdata_tm1.Load(int3(_4527, 0)).x & 2147483647u;
                    uint _13457 = uint(max((int((_13425 >> 16u) & 15u) - 6), 0));
                    _16915 = ((float2(float((1 - (2 * int((_13425 >> 15u) & 1u))) * int(((_13425 >> uint(7)) & 127u) << _13457)), float((1 - (2 * int((_13425 >> 14u) & 1u))) * int((_13425 & 127u) << _13457))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _16915 = _6697 * float2(cbFI_DisplaySize);
                }
                _16914 = _16915;
            }
            uint2 _6540 = uint2(clamp(round(_16914 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6542 = _6540.x;
            uint _6549 = _6540.y;
            _16916 = float4(float(_6542 & 255u), float((_6542 >> 8u) | ((_6549 & 15u) << 4u)), float(_6549 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _16917;
            if (_5884 == 17u)
            {
                _16917 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4527, 0)).x != 0u), _4971, 0.0f, 1.0f);
            }
            else
            {
                _16917 = float4(_16880, 1.0f);
            }
            _16916 = _16917;
        }
        rw_output[_4050] = _16916.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6593 = ((uint(_4050.y) * uint(cbFI_DisplaySize.x)) + uint(_4050.x)) * 6u;
            uint _13503 = spvPackHalf2x16(clamp(_7401.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6593 * 4 + 0, (((_13503 & 32767u) >> 4u) | ((((_13503 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7401.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13538 = spvPackHalf2x16(clamp(_7409.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6593 + 1u) * 4 + 0, (((_13538 & 32767u) >> 4u) | ((((_13538 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7409.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13573 = spvPackHalf2x16(clamp(_7417.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6593 + 2u) * 4 + 0, (((_13573 & 32767u) >> 4u) | ((((_13573 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7417.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13608 = spvPackHalf2x16(clamp(_7425.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6593 + 3u) * 4 + 0, (((_13608 & 32767u) >> 4u) | ((((_13608 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7425.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13635 = r_current_interpolation_source.Load(int3(_4050, 0));
            uint _13649 = spvPackHalf2x16(clamp(_13635.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6593 + 4u) * 4 + 0, (((_13649 & 32767u) >> 4u) | ((((_13649 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13635.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _16950;
            if (_16776 || (_5884 != 0u))
            {
                _16950 = 4294967295u;
            }
            else
            {
                uint _13684 = spvPackHalf2x16(clamp(_16916.xy, 0.0f.xx, 65000.0f.xx));
                _16950 = (((_13684 & 32767u) >> 4u) | ((((_13684 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_16916.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6593 + 5u) * 4 + 0, _16950);
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
