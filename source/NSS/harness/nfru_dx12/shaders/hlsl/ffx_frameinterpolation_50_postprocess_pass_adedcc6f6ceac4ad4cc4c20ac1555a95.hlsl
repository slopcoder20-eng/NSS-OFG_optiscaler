static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1184[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1193[5] = { 2, 4, 7, 11, 16 };
static const float3 _3814[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4101 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4101.x >= cbFI_DisplaySize.x, _4101.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4101] = float4(r_present_backbuffer.Load(int3(_4101, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4565 = (float2(_4101) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4567 = float2(cbFI_MvDepthLaneSize);
        int2 _4576 = int2(floor(_4565 * _4567));
        int2 _4581 = int2(floor(_4565 * float2(cbFI_FlowLaneSize)));
        float4 _6790 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4565 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6796 = r_warped_filled_flow_tm1.Load(int3(_4581, 0)).xy;
        float2 _6802 = r_warped_filled_motion_tp1.Load(int3(_4576, 0)).xy;
        bool _6824 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14137;
        if (_6824)
        {
            float _6837 = ((2.0f * _4565.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14137 = float2(atan(_6837) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4565.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6837 * _6837))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14137 = _4565;
        }
        bool _4602 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14158;
        bool _14300;
        int2 _14381;
        float3 _16549;
        if (_4602)
        {
            float _14139;
            float _14141;
            _14141 = 2.0f;
            _14139 = -1.0f;
            uint _4183[9];
            float _17122;
            float _17125;
            for (int _14138 = 0; _14138 < 9; _14141 = _17125, _14139 = _17122, _14138++)
            {
                _4183[_14138] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4576 + int2((_14138 % 3) - 1, (_14138 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4183[_14138] != 0u)
                {
                    float _17117;
                    if (_4183[_14138] == 0u)
                    {
                        _17117 = -1.0f;
                    }
                    else
                    {
                        _17117 = float((_4183[_14138] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17125 = min(_14141, _17117);
                    _17122 = max(_14139, _17117);
                }
                else
                {
                    _17125 = _14141;
                    _17122 = _14139;
                }
            }
            float _4648 = float(_14139 >= 0.0f);
            float3 _13840 = 0.0f.xxx;
            _13840.y = _4648;
            float2 _14159;
            bool _14301;
            int2 _14382;
            float3 _16550;
            if ((_14139 - _14141) > 0.0199999995529651641845703125f)
            {
                float _14147;
                int2 _14148;
                float2 _14149;
                int2 _14151;
                float2 _14157;
                _14157 = _6802;
                _14151 = _4576;
                _14149 = _6802;
                _14148 = _4576;
                _14147 = -1.0f;
                float _17130;
                int2 _17134;
                float2 _17145;
                int2 _17156;
                float2 _17189;
                float _17236;
                int _14146 = 0;
                float _17098 = 1000000000.0f;
                for (; _14146 < 9; _17098 = _17236, _14157 = _17189, _14151 = _17156, _14149 = _17145, _14148 = _17134, _14147 = _17130, _14146++)
                {
                    if (_4183[_14146] == 0u)
                    {
                        _17236 = _17098;
                        _17189 = _14157;
                        _17156 = _14151;
                        _17145 = _14149;
                        _17134 = _14148;
                        _17130 = _14147;
                        continue;
                    }
                    int2 _4683 = clamp(_4576 + int2((_14146 % 3) - 1, (_14146 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6912 = _4183[_14146] & 2147483647u;
                    uint _6944 = uint(max((int((_6912 >> 16u) & 15u) - 6), 0));
                    float2 _4689 = (float2(float((1 - (2 * int((_6912 >> 15u) & 1u))) * int(((_6912 >> uint(7)) & 127u) << _6944)), float((1 - (2 * int((_6912 >> 14u) & 1u))) * int((_6912 & 127u) << _6944))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _17084;
                    if (_4183[_14146] == 0u)
                    {
                        _17084 = -1.0f;
                    }
                    else
                    {
                        _17084 = float((_4183[_14146] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4694 = _17084 - 0.100000001490116119384765625f;
                    float2 _17085;
                    if (_6824)
                    {
                        float2 _7021 = clamp((((_14137 + (_4689 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7024 = tan(_7021.x);
                        _17085 = (float2(_7024 / cbFI_DeviceToViewDepth.z, (tan(_7021.y) * sqrt(1.0f + (_7024 * _7024))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17085 = _14137 + (_4689 * cbFI_Timestep);
                    }
                    float _4701 = cbFI_Timestep - 1.0f;
                    float2 _17086;
                    if (_6824)
                    {
                        float2 _7092 = clamp((((_14137 + (_4689 * _4701)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7095 = tan(_7092.x);
                        _17086 = (float2(_7095 / cbFI_DeviceToViewDepth.z, (tan(_7092.y) * sqrt(1.0f + (_7095 * _7095))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17086 = _14137 + (_4689 * _4701);
                    }
                    bool _7128 = all(bool2(_17085.x > 0.0f.xx.x, _17085.y > 0.0f.xx.y));
                    bool _7134;
                    if (_7128)
                    {
                        _7134 = all(bool2(_17085.x < 1.0f.xx.x, _17085.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7134 = _7128;
                    }
                    float _17089;
                    if (_7134)
                    {
                        uint _7141_dummy_parameter;
                        _17089 = max((_4694 - (log((r_depth_tm1.Load(int3(int2(floor(_17085 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7141_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17089 = 0.0f;
                    }
                    bool _7171 = all(bool2(_17086.x > 0.0f.xx.x, _17086.y > 0.0f.xx.y));
                    bool _7177;
                    if (_7171)
                    {
                        _7177 = all(bool2(_17086.x < 1.0f.xx.x, _17086.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7177 = _7171;
                    }
                    float _17090;
                    if (_7177)
                    {
                        uint _7184_dummy_parameter;
                        _17090 = _17089 + max((_4694 - (log((r_depth_tp1.Load(int3(int2(floor(_17086 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7184_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17090 = _17089;
                    }
                    float _17131;
                    int2 _17135;
                    float2 _17146;
                    int2 _17157;
                    float2 _17190;
                    float _17237;
                    if (_17090 == 0.0f)
                    {
                        bool _4736 = _4694 > _14147;
                        bool2 _17245 = _4736.xx;
                        _17237 = _17098;
                        _17190 = float2(_17245.x ? _4689.x : _14157.x, _17245.y ? _4689.y : _14157.y);
                        _17157 = int2(_17245.x ? _4683.x : _14151.x, _17245.y ? _4683.y : _14151.y);
                        _17146 = _14149;
                        _17135 = _14148;
                        _17131 = _4736 ? _4694 : _14147;
                    }
                    else
                    {
                        bool _4745 = _17090 < _17098;
                        bool2 _17241 = _4745.xx;
                        _17237 = _4745 ? _17090 : _17098;
                        _17190 = _14157;
                        _17157 = _14151;
                        _17146 = float2(_17241.x ? _4689.x : _14149.x, _17241.y ? _4689.y : _14149.y);
                        _17135 = int2(_17241.x ? _4683.x : _14148.x, _17241.y ? _4683.y : _14148.y);
                        _17131 = _14147;
                    }
                    _17236 = _17237;
                    _17189 = _17190;
                    _17156 = _17157;
                    _17145 = _17146;
                    _17134 = _17135;
                    _17130 = _17131;
                }
                bool _4757 = _14147 < 0.0f;
                bool2 _17251 = _4757.xx;
                int2 _17254 = int2(_17251.x ? _14148.x : _14151.x, _17251.y ? _14148.y : _14151.y);
                _16550 = float3(1.0f, _4648, float(any(bool2(_17254.x != _4576.x, _17254.y != _4576.y))));
                _14382 = _17254;
                _14301 = _4757 ? false : true;
                _14159 = float2(_17251.x ? _14149.x : _14157.x, _17251.y ? _14149.y : _14157.y);
            }
            else
            {
                _16550 = _13840;
                _14382 = _4576;
                _14301 = false;
                _14159 = _6802;
            }
            _16549 = _16550;
            _14381 = _14382;
            _14300 = _14301;
            _14158 = _14159;
        }
        else
        {
            _16549 = 0.0f.xxx;
            _14381 = _4576;
            _14300 = false;
            _14158 = _6802;
        }
        float2 _14160;
        if (_6824)
        {
            float2 _7249 = clamp((((_14137 + (_14158 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7252 = tan(_7249.x);
            _14160 = (float2(_7252 / cbFI_DeviceToViewDepth.z, (tan(_7249.y) * sqrt(1.0f + (_7252 * _7252))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14160 = _14137 + (_14158 * cbFI_Timestep);
        }
        float _4780 = cbFI_Timestep - 1.0f;
        float2 _14162;
        if (_6824)
        {
            float2 _7320 = clamp((((_14137 + (_14158 * _4780)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7323 = tan(_7320.x);
            _14162 = (float2(_7323 / cbFI_DeviceToViewDepth.z, (tan(_7320.y) * sqrt(1.0f + (_7323 * _7323))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14162 = _14137 + (_14158 * _4780);
        }
        float _4785 = -cbFI_Timestep;
        float2 _14163;
        if (_6824)
        {
            float2 _7391 = clamp((((_14137 + (_6796 * _4785)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7394 = tan(_7391.x);
            _14163 = (float2(_7394 / cbFI_DeviceToViewDepth.z, (tan(_7391.y) * sqrt(1.0f + (_7394 * _7394))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14163 = _14137 + (_6796 * _4785);
        }
        float _4790 = 1.0f - cbFI_Timestep;
        float2 _14164;
        if (_6824)
        {
            float2 _7462 = clamp((((_14137 + (_6796 * _4790)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7465 = tan(_7462.x);
            _14164 = (float2(_7465 / cbFI_DeviceToViewDepth.z, (tan(_7462.y) * sqrt(1.0f + (_7465 * _7465))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14164 = _14137 + (_6796 * _4790);
        }
        float4 _7500 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14160, 0.0f);
        float3 _7501 = _7500.xyz;
        float4 _7508 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14162, 0.0f);
        float3 _7509 = _7508.xyz;
        float4 _7516 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14163, 0.0f);
        float3 _7517 = _7516.xyz;
        float4 _7524 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14164, 0.0f);
        float3 _7525 = _7524.xyz;
        float4 _7539 = exp(_6790 - max(max(max(_6790.x, _6790.y), _6790.z), _6790.w).xxxx);
        float4 _7546 = _7539 / (dot(_7539, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4806 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14371;
        float _15679;
        if (_4806)
        {
            float2 _4812 = 0.5f.xx / _4567;
            float _4815 = _4812.x;
            float _4816 = -_4815;
            float _4818 = _4812.y;
            float _4819 = -_4818;
            float2 _4821 = _4565 + float2(_4816, _4819);
            float2 _4823 = float2(cbFI_DisplaySize);
            bool _14181;
            do
            {
                bool _7626 = all(bool2(_4821.x > 0.0f.xx.x, _4821.y > 0.0f.xx.y));
                bool _7632;
                if (_7626)
                {
                    _7632 = all(bool2(_4821.x < 1.0f.xx.x, _4821.y < 1.0f.xx.y));
                }
                else
                {
                    _7632 = _7626;
                }
                if (!_7632)
                {
                    _14181 = false;
                    break;
                }
                uint _7639_dummy_parameter;
                float4x4 _14179;
                do
                {
                    float4x4 _7653;
                    bool _14178;
                    do
                    {
                        _7653 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14178 = false;
                            break;
                        }
                        uint _7687 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7687 + 32u) * 4 + 0) != 1u)
                        {
                            _14178 = false;
                            break;
                        }
                        uint _14175;
                        _14175 = 0u;
                        for (; _14175 < 4u; _14175++)
                        {
                            for (uint _14176 = 0u; _14176 < 4u; )
                            {
                                _7653[_14175][_14176] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7687 + (_14175 * 4u)) + _14176) * 4 + 0));
                                _14176++;
                                continue;
                            }
                        }
                        _14178 = true;
                        break;
                    } while(false);
                    if (_14178)
                    {
                        _14179 = _7653;
                        break;
                    }
                    _14179 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14180;
                do
                {
                    float _7764 = _4821.x;
                    float _7767 = 1.0f - _4821.y;
                    float4 _7778 = mul(float4((float2(_7764, _7767) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4821 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7639_dummy_parameter))))), 0)).x, 1.0f), _14179);
                    float _7780 = _7778.w;
                    if (!(_7780 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14180 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7793 = ((_7778.xy / _7780.xx) + 1.0f.xx) * 0.5f;
                    _14180 = float2(_7793.x - _7764, _7767 - _7793.y);
                    break;
                } while(false);
                float2 _7590 = abs(_14180);
                if (any(bool2(_7590.x > 100000.0f.xx.x, _7590.y > 100000.0f.xx.y)))
                {
                    _14181 = false;
                    break;
                }
                float _7598 = length(_14180 * _4823);
                uint _7813_dummy_parameter;
                bool _7612 = _7598 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7619;
                if (_7612)
                {
                    _7619 = length((r_motion_tp1.Load(int3(int2(floor(_4821 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7813_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _7598);
                }
                else
                {
                    _7619 = _7612;
                }
                _14181 = _7619;
                break;
            } while(false);
            float2 _4833 = _4565 + float2(_4815, _4819);
            bool _14188;
            do
            {
                bool _7899 = all(bool2(_4833.x > 0.0f.xx.x, _4833.y > 0.0f.xx.y));
                bool _7905;
                if (_7899)
                {
                    _7905 = all(bool2(_4833.x < 1.0f.xx.x, _4833.y < 1.0f.xx.y));
                }
                else
                {
                    _7905 = _7899;
                }
                if (!_7905)
                {
                    _14188 = false;
                    break;
                }
                uint _7912_dummy_parameter;
                float4x4 _14186;
                do
                {
                    float4x4 _7926;
                    bool _14185;
                    do
                    {
                        _7926 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14185 = false;
                            break;
                        }
                        uint _7960 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7960 + 32u) * 4 + 0) != 1u)
                        {
                            _14185 = false;
                            break;
                        }
                        uint _14182;
                        _14182 = 0u;
                        for (; _14182 < 4u; _14182++)
                        {
                            for (uint _14183 = 0u; _14183 < 4u; )
                            {
                                _7926[_14182][_14183] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7960 + (_14182 * 4u)) + _14183) * 4 + 0));
                                _14183++;
                                continue;
                            }
                        }
                        _14185 = true;
                        break;
                    } while(false);
                    if (_14185)
                    {
                        _14186 = _7926;
                        break;
                    }
                    _14186 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14187;
                do
                {
                    float _8037 = _4833.x;
                    float _8040 = 1.0f - _4833.y;
                    float4 _8051 = mul(float4((float2(_8037, _8040) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4833 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7912_dummy_parameter))))), 0)).x, 1.0f), _14186);
                    float _8053 = _8051.w;
                    if (!(_8053 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14187 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8066 = ((_8051.xy / _8053.xx) + 1.0f.xx) * 0.5f;
                    _14187 = float2(_8066.x - _8037, _8040 - _8066.y);
                    break;
                } while(false);
                float2 _7863 = abs(_14187);
                if (any(bool2(_7863.x > 100000.0f.xx.x, _7863.y > 100000.0f.xx.y)))
                {
                    _14188 = false;
                    break;
                }
                float _7871 = length(_14187 * _4823);
                uint _8086_dummy_parameter;
                bool _7885 = _7871 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7892;
                if (_7885)
                {
                    _7892 = length((r_motion_tp1.Load(int3(int2(floor(_4833 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8086_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _7871);
                }
                else
                {
                    _7892 = _7885;
                }
                _14188 = _7892;
                break;
            } while(false);
            float2 _4846 = _4565 + float2(_4816, _4818);
            bool _14195;
            do
            {
                bool _8172 = all(bool2(_4846.x > 0.0f.xx.x, _4846.y > 0.0f.xx.y));
                bool _8178;
                if (_8172)
                {
                    _8178 = all(bool2(_4846.x < 1.0f.xx.x, _4846.y < 1.0f.xx.y));
                }
                else
                {
                    _8178 = _8172;
                }
                if (!_8178)
                {
                    _14195 = false;
                    break;
                }
                uint _8185_dummy_parameter;
                float4x4 _14193;
                do
                {
                    float4x4 _8199;
                    bool _14192;
                    do
                    {
                        _8199 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14192 = false;
                            break;
                        }
                        uint _8233 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8233 + 32u) * 4 + 0) != 1u)
                        {
                            _14192 = false;
                            break;
                        }
                        uint _14189;
                        _14189 = 0u;
                        for (; _14189 < 4u; _14189++)
                        {
                            for (uint _14190 = 0u; _14190 < 4u; )
                            {
                                _8199[_14189][_14190] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8233 + (_14189 * 4u)) + _14190) * 4 + 0));
                                _14190++;
                                continue;
                            }
                        }
                        _14192 = true;
                        break;
                    } while(false);
                    if (_14192)
                    {
                        _14193 = _8199;
                        break;
                    }
                    _14193 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14194;
                do
                {
                    float _8310 = _4846.x;
                    float _8313 = 1.0f - _4846.y;
                    float4 _8324 = mul(float4((float2(_8310, _8313) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4846 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8185_dummy_parameter))))), 0)).x, 1.0f), _14193);
                    float _8326 = _8324.w;
                    if (!(_8326 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14194 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8339 = ((_8324.xy / _8326.xx) + 1.0f.xx) * 0.5f;
                    _14194 = float2(_8339.x - _8310, _8313 - _8339.y);
                    break;
                } while(false);
                float2 _8136 = abs(_14194);
                if (any(bool2(_8136.x > 100000.0f.xx.x, _8136.y > 100000.0f.xx.y)))
                {
                    _14195 = false;
                    break;
                }
                float _8144 = length(_14194 * _4823);
                uint _8359_dummy_parameter;
                bool _8158 = _8144 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8165;
                if (_8158)
                {
                    _8165 = length((r_motion_tp1.Load(int3(int2(floor(_4846 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8359_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _8144);
                }
                else
                {
                    _8165 = _8158;
                }
                _14195 = _8165;
                break;
            } while(false);
            float2 _4858 = _4565 + _4812;
            bool _14202;
            do
            {
                bool _8445 = all(bool2(_4858.x > 0.0f.xx.x, _4858.y > 0.0f.xx.y));
                bool _8451;
                if (_8445)
                {
                    _8451 = all(bool2(_4858.x < 1.0f.xx.x, _4858.y < 1.0f.xx.y));
                }
                else
                {
                    _8451 = _8445;
                }
                if (!_8451)
                {
                    _14202 = false;
                    break;
                }
                uint _8458_dummy_parameter;
                float4x4 _14200;
                do
                {
                    float4x4 _8472;
                    bool _14199;
                    do
                    {
                        _8472 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14199 = false;
                            break;
                        }
                        uint _8506 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8506 + 32u) * 4 + 0) != 1u)
                        {
                            _14199 = false;
                            break;
                        }
                        uint _14196;
                        _14196 = 0u;
                        for (; _14196 < 4u; _14196++)
                        {
                            for (uint _14197 = 0u; _14197 < 4u; )
                            {
                                _8472[_14196][_14197] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8506 + (_14196 * 4u)) + _14197) * 4 + 0));
                                _14197++;
                                continue;
                            }
                        }
                        _14199 = true;
                        break;
                    } while(false);
                    if (_14199)
                    {
                        _14200 = _8472;
                        break;
                    }
                    _14200 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14201;
                do
                {
                    float _8583 = _4858.x;
                    float _8586 = 1.0f - _4858.y;
                    float4 _8597 = mul(float4((float2(_8583, _8586) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4858 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8458_dummy_parameter))))), 0)).x, 1.0f), _14200);
                    float _8599 = _8597.w;
                    if (!(_8599 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14201 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8612 = ((_8597.xy / _8599.xx) + 1.0f.xx) * 0.5f;
                    _14201 = float2(_8612.x - _8583, _8586 - _8612.y);
                    break;
                } while(false);
                float2 _8409 = abs(_14201);
                if (any(bool2(_8409.x > 100000.0f.xx.x, _8409.y > 100000.0f.xx.y)))
                {
                    _14202 = false;
                    break;
                }
                float _8417 = length(_14201 * _4823);
                uint _8632_dummy_parameter;
                bool _8431 = _8417 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8438;
                if (_8431)
                {
                    _8438 = length((r_motion_tp1.Load(int3(int2(floor(_4858 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8632_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _8417);
                }
                else
                {
                    _8438 = _8431;
                }
                _14202 = _8438;
                break;
            } while(false);
            float _4864 = 0.25f * (((float(_14181) + float(_14188)) + float(_14195)) + float(_14202));
            float4 _14372;
            if (_4864 < 1.0f)
            {
                bool _14209;
                do
                {
                    bool _8718 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
                    bool _8724;
                    if (_8718)
                    {
                        _8724 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8724 = _8718;
                    }
                    if (!_8724)
                    {
                        _14209 = false;
                        break;
                    }
                    uint _8731_dummy_parameter;
                    float4x4 _14207;
                    do
                    {
                        float4x4 _8745;
                        bool _14206;
                        do
                        {
                            _8745 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14206 = false;
                                break;
                            }
                            uint _8779 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8779 + 32u) * 4 + 0) != 1u)
                            {
                                _14206 = false;
                                break;
                            }
                            uint _14203;
                            _14203 = 0u;
                            for (; _14203 < 4u; _14203++)
                            {
                                for (uint _14204 = 0u; _14204 < 4u; )
                                {
                                    _8745[_14203][_14204] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8779 + (_14203 * 4u)) + _14204) * 4 + 0));
                                    _14204++;
                                    continue;
                                }
                            }
                            _14206 = true;
                            break;
                        } while(false);
                        if (_14206)
                        {
                            _14207 = _8745;
                            break;
                        }
                        _14207 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14208;
                    do
                    {
                        float _8859 = 1.0f - _14160.y;
                        float4 _8870 = mul(float4((float2(_14160.x, _8859) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8731_dummy_parameter))))), 0)).x, 1.0f), _14207);
                        float _8872 = _8870.w;
                        if (!(_8872 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14208 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8885 = ((_8870.xy / _8872.xx) + 1.0f.xx) * 0.5f;
                        _14208 = float2(_8885.x - _14160.x, _8859 - _8885.y);
                        break;
                    } while(false);
                    float2 _8682 = abs(_14208);
                    if (any(bool2(_8682.x > 100000.0f.xx.x, _8682.y > 100000.0f.xx.y)))
                    {
                        _14209 = false;
                        break;
                    }
                    float _8690 = length(_14208 * _4823);
                    uint _8905_dummy_parameter;
                    bool _8704 = _8690 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8711;
                    if (_8704)
                    {
                        _8711 = length((r_motion_tp1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8905_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _8690);
                    }
                    else
                    {
                        _8711 = _8704;
                    }
                    _14209 = _8711;
                    break;
                } while(false);
                bool _14216;
                do
                {
                    bool _8991 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
                    bool _8997;
                    if (_8991)
                    {
                        _8997 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8997 = _8991;
                    }
                    if (!_8997)
                    {
                        _14216 = false;
                        break;
                    }
                    uint _9004_dummy_parameter;
                    float4x4 _14214;
                    do
                    {
                        float4x4 _9018;
                        bool _14213;
                        do
                        {
                            _9018 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14213 = false;
                                break;
                            }
                            uint _9052 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9052 + 32u) * 4 + 0) != 1u)
                            {
                                _14213 = false;
                                break;
                            }
                            uint _14210;
                            _14210 = 0u;
                            for (; _14210 < 4u; _14210++)
                            {
                                for (uint _14211 = 0u; _14211 < 4u; )
                                {
                                    _9018[_14210][_14211] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9052 + (_14210 * 4u)) + _14211) * 4 + 0));
                                    _14211++;
                                    continue;
                                }
                            }
                            _14213 = true;
                            break;
                        } while(false);
                        if (_14213)
                        {
                            _14214 = _9018;
                            break;
                        }
                        _14214 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14215;
                    do
                    {
                        float _9132 = 1.0f - _14162.y;
                        float4 _9143 = mul(float4((float2(_14162.x, _9132) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9004_dummy_parameter))))), 0)).x, 1.0f), _14214);
                        float _9145 = _9143.w;
                        if (!(_9145 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14215 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9158 = ((_9143.xy / _9145.xx) + 1.0f.xx) * 0.5f;
                        _14215 = float2(_9158.x - _14162.x, _9132 - _9158.y);
                        break;
                    } while(false);
                    float2 _8955 = abs(_14215);
                    if (any(bool2(_8955.x > 100000.0f.xx.x, _8955.y > 100000.0f.xx.y)))
                    {
                        _14216 = false;
                        break;
                    }
                    float _8963 = length(_14215 * _4823);
                    uint _9178_dummy_parameter;
                    bool _8977 = _8963 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8984;
                    if (_8977)
                    {
                        _8984 = length((r_motion_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9178_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _8963);
                    }
                    else
                    {
                        _8984 = _8977;
                    }
                    _14216 = _8984;
                    break;
                } while(false);
                bool _14223;
                do
                {
                    bool _9264 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                    bool _9270;
                    if (_9264)
                    {
                        _9270 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9270 = _9264;
                    }
                    if (!_9270)
                    {
                        _14223 = false;
                        break;
                    }
                    uint _9277_dummy_parameter;
                    float4x4 _14221;
                    do
                    {
                        float4x4 _9291;
                        bool _14220;
                        do
                        {
                            _9291 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14220 = false;
                                break;
                            }
                            uint _9325 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9325 + 32u) * 4 + 0) != 1u)
                            {
                                _14220 = false;
                                break;
                            }
                            uint _14217;
                            _14217 = 0u;
                            for (; _14217 < 4u; _14217++)
                            {
                                for (uint _14218 = 0u; _14218 < 4u; )
                                {
                                    _9291[_14217][_14218] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9325 + (_14217 * 4u)) + _14218) * 4 + 0));
                                    _14218++;
                                    continue;
                                }
                            }
                            _14220 = true;
                            break;
                        } while(false);
                        if (_14220)
                        {
                            _14221 = _9291;
                            break;
                        }
                        _14221 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14222;
                    do
                    {
                        float _9405 = 1.0f - _14163.y;
                        float4 _9416 = mul(float4((float2(_14163.x, _9405) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9277_dummy_parameter))))), 0)).x, 1.0f), _14221);
                        float _9418 = _9416.w;
                        if (!(_9418 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14222 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9431 = ((_9416.xy / _9418.xx) + 1.0f.xx) * 0.5f;
                        _14222 = float2(_9431.x - _14163.x, _9405 - _9431.y);
                        break;
                    } while(false);
                    float2 _9228 = abs(_14222);
                    if (any(bool2(_9228.x > 100000.0f.xx.x, _9228.y > 100000.0f.xx.y)))
                    {
                        _14223 = false;
                        break;
                    }
                    float _9236 = length(_14222 * _4823);
                    uint _9451_dummy_parameter;
                    bool _9250 = _9236 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9257;
                    if (_9250)
                    {
                        _9257 = length((r_motion_tp1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9451_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _9236);
                    }
                    else
                    {
                        _9257 = _9250;
                    }
                    _14223 = _9257;
                    break;
                } while(false);
                bool _14230;
                do
                {
                    bool _9537 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                    bool _9543;
                    if (_9537)
                    {
                        _9543 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9543 = _9537;
                    }
                    if (!_9543)
                    {
                        _14230 = false;
                        break;
                    }
                    uint _9550_dummy_parameter;
                    float4x4 _14228;
                    do
                    {
                        float4x4 _9564;
                        bool _14227;
                        do
                        {
                            _9564 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14227 = false;
                                break;
                            }
                            uint _9598 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9598 + 32u) * 4 + 0) != 1u)
                            {
                                _14227 = false;
                                break;
                            }
                            uint _14224;
                            _14224 = 0u;
                            for (; _14224 < 4u; _14224++)
                            {
                                for (uint _14225 = 0u; _14225 < 4u; )
                                {
                                    _9564[_14224][_14225] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9598 + (_14224 * 4u)) + _14225) * 4 + 0));
                                    _14225++;
                                    continue;
                                }
                            }
                            _14227 = true;
                            break;
                        } while(false);
                        if (_14227)
                        {
                            _14228 = _9564;
                            break;
                        }
                        _14228 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14229;
                    do
                    {
                        float _9678 = 1.0f - _14164.y;
                        float4 _9689 = mul(float4((float2(_14164.x, _9678) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9550_dummy_parameter))))), 0)).x, 1.0f), _14228);
                        float _9691 = _9689.w;
                        if (!(_9691 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14229 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9704 = ((_9689.xy / _9691.xx) + 1.0f.xx) * 0.5f;
                        _14229 = float2(_9704.x - _14164.x, _9678 - _9704.y);
                        break;
                    } while(false);
                    float2 _9501 = abs(_14229);
                    if (any(bool2(_9501.x > 100000.0f.xx.x, _9501.y > 100000.0f.xx.y)))
                    {
                        _14230 = false;
                        break;
                    }
                    float _9509 = length(_14229 * _4823);
                    uint _9724_dummy_parameter;
                    bool _9523 = _9509 > ((8.0f * _4823.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9530;
                    if (_9523)
                    {
                        _9530 = length((r_motion_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9724_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4823) < (0.20000000298023223876953125f * _9509);
                    }
                    else
                    {
                        _9530 = _9523;
                    }
                    _14230 = _9530;
                    break;
                } while(false);
                float4 _4891 = _7546 * float4(_14209 ? 0.0f : 1.0f, _14216 ? 0.0f : 1.0f, _14223 ? 0.0f : 1.0f, _14230 ? 0.0f : 1.0f);
                float _4893 = dot(_4891, 1.0f.xxxx);
                float4 _14373;
                if (_4893 > 0.001000000047497451305389404296875f)
                {
                    _14373 = _4891 / _4893.xxxx;
                }
                else
                {
                    _14373 = _7546;
                }
                _14372 = _14373;
            }
            else
            {
                _14372 = _7546;
            }
            _15679 = _4864;
            _14371 = _14372;
        }
        else
        {
            _15679 = 0.0f;
            _14371 = _7546;
        }
        bool _4910 = _4602 && (!_14300);
        bool _4919;
        if (_4910)
        {
            _4919 = (_14371.z + _14371.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4919 = _4910;
        }
        bool _4930;
        if (_4919)
        {
            _4930 = length((_14163 - _14160) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4930 = _4919;
        }
        bool _14460;
        if (_4930)
        {
            uint4 _9753 = r_warped_motion_qdata_tp1.Load(int3(_14381, 0));
            uint _9754 = _9753.x;
            bool _14463;
            if (_9754 != 0u)
            {
                float _14449;
                if (_9754 == 0u)
                {
                    _14449 = -1.0f;
                }
                else
                {
                    _14449 = float((_9754 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4940 = _14449 - 0.12000000476837158203125f;
                bool _9773 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                bool _9779;
                if (_9773)
                {
                    _9779 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                }
                else
                {
                    _9779 = _9773;
                }
                bool _4950;
                if (_9779)
                {
                    uint _9786_dummy_parameter;
                    _4950 = (log((r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9786_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4940;
                }
                else
                {
                    _4950 = _9779;
                }
                bool _4964;
                if (!_4950)
                {
                    bool _9816 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                    bool _9822;
                    if (_9816)
                    {
                        _9822 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9822 = _9816;
                    }
                    bool _4962;
                    if (_9822)
                    {
                        uint _9829_dummy_parameter;
                        _4962 = (log((r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9829_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4940;
                    }
                    else
                    {
                        _4962 = _9822;
                    }
                    _4964 = _4962;
                }
                else
                {
                    _4964 = _4950;
                }
                _14463 = _4964;
            }
            else
            {
                _14463 = false;
            }
            _14460 = _14463;
        }
        else
        {
            _14460 = false;
        }
        bool _4969 = _14300 || _14460;
        bool _4974;
        if (_4969)
        {
            bool _9859 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
            bool _9865;
            if (_9859)
            {
                _9865 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
            }
            else
            {
                _9865 = _9859;
            }
            _4974 = _9865;
        }
        else
        {
            _4974 = _4969;
        }
        bool _4979;
        if (_4974)
        {
            bool _9870 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
            bool _9876;
            if (_9870)
            {
                _9876 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
            }
            else
            {
                _9876 = _9870;
            }
            _4979 = _9876;
        }
        else
        {
            _4979 = _4974;
        }
        float4 _14583;
        if (_4979)
        {
            float _4985 = _14371.x + _14371.y;
            float _4990 = _14371.z + _14371.w;
            float _14478;
            if (_4985 > 0.001000000047497451305389404296875f)
            {
                _14478 = _14371.x / _4985;
            }
            else
            {
                _14478 = _4790;
            }
            _14583 = float4(_14371.x + (_4990 * _14478), _14371.y + (_4990 * (1.0f - _14478)), 0.0f, 0.0f);
        }
        else
        {
            _14583 = _14371;
        }
        bool _9904 = (cbFI_pad0 & 1024u) != 0u;
        bool _9880 = !_9904;
        bool _9881 = !_9880;
        bool _9898;
        if (_9881)
        {
            _9898 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14381.y * cbFI_MvDepthLaneSize.x) + _14381.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9898 = _9880;
        }
        bool _9930;
        if (_9881)
        {
            _9930 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4581.y * cbFI_FlowLaneSize.x) + _4581.x)) * 4 + 0) != 0u;
        }
        else
        {
            _9930 = _9880;
        }
        float _5025 = float(_9930);
        bool _14604;
        float4 _14643;
        float3 _16313;
        if (_9904)
        {
            bool _5035;
            if (_9898)
            {
                _5035 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
            }
            else
            {
                _5035 = _9898;
            }
            bool _5041;
            if (_5035)
            {
                _5041 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
            }
            else
            {
                _5041 = _5035;
            }
            bool _5048;
            if (_9898)
            {
                _5048 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
            }
            else
            {
                _5048 = _9898;
            }
            bool _5054;
            if (_5048)
            {
                _5054 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
            }
            else
            {
                _5054 = _5048;
            }
            bool _5061;
            if (_9930)
            {
                _5061 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
            }
            else
            {
                _5061 = _9930;
            }
            bool _5067;
            if (_5061)
            {
                _5067 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
            }
            else
            {
                _5067 = _5061;
            }
            bool _5074;
            if (_9930)
            {
                _5074 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
            }
            else
            {
                _5074 = _9930;
            }
            bool _5080;
            if (_5074)
            {
                _5080 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
            }
            else
            {
                _5080 = _5074;
            }
            bool _5082 = !_9898;
            if (_5082)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9972;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9972);
                }
            }
            bool _5087 = !_9930;
            if (_5087)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9982;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9982);
                }
            }
            if (_9898 && _5087)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9992;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9992);
                }
            }
            if (_5082 && _9930)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10002;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _10002);
                }
            }
            float _5106 = float(_5041);
            float _5108 = float(_5054);
            bool _5111 = _5067 && _5080;
            float _14512;
            if (_5111)
            {
                _14512 = 1.0f;
            }
            else
            {
                _14512 = (_5067 || _5080) ? 0.5f : 0.0f;
            }
            bool _14527;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5041)) && (!_5054))
            {
                bool _5141;
                if (_5111)
                {
                    float _14520;
                    do
                    {
                        bool _10086 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                        bool _10092;
                        if (_10086)
                        {
                            _10092 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10092 = _10086;
                        }
                        bool _10023 = !_10092;
                        bool _10030;
                        if (!_10023)
                        {
                            bool _10097 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                            bool _10103;
                            if (_10097)
                            {
                                _10103 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10103 = _10097;
                            }
                            _10030 = !_10103;
                        }
                        else
                        {
                            _10030 = _10023;
                        }
                        if (_10030)
                        {
                            _14520 = 0.0f;
                            break;
                        }
                        uint _10110_dummy_parameter;
                        uint _10126_dummy_parameter;
                        float4x4 _14519;
                        do
                        {
                            float4x4 _10140;
                            bool _14518;
                            do
                            {
                                _10140 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14518 = false;
                                    break;
                                }
                                uint _10174 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10174 + 32u) * 4 + 0) != 1u)
                                {
                                    _14518 = false;
                                    break;
                                }
                                uint _14515;
                                _14515 = 0u;
                                for (; _14515 < 4u; _14515++)
                                {
                                    for (uint _14516 = 0u; _14516 < 4u; )
                                    {
                                        _10140[_14515][_14516] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10174 + 16u) + (_14515 * 4u)) + _14516) * 4 + 0));
                                        _14516++;
                                        continue;
                                    }
                                }
                                _14518 = true;
                                break;
                            } while(false);
                            if (_14518)
                            {
                                _14519 = _10140;
                                break;
                            }
                            _14519 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _10051 = mul(float4((float2(_14163.x, 1.0f - _14163.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10110_dummy_parameter))))), 0)).x, 1.0f), _14519);
                        float _10053 = _10051.w;
                        if (abs(_10053) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14520 = 0.0f;
                            break;
                        }
                        float _10064 = abs(cbFI_DeviceToViewDepth.y / ((_10051.z / _10053) - cbFI_DeviceToViewDepth.x));
                        float _10067 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10126_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14520 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10064 - _10067) / max(max(_10064, _10067), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5141 = _14520 >= 0.5f;
                }
                else
                {
                    _5141 = _5111;
                }
                bool _5149;
                if (_5141)
                {
                    _5149 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5149 = _5141;
                }
                bool _14528;
                if (_5149)
                {
                    uint _10278_dummy_parameter;
                    float4x4 _14525;
                    do
                    {
                        float4x4 _10292;
                        bool _14524;
                        do
                        {
                            _10292 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14524 = false;
                                break;
                            }
                            uint _10326 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10326 + 32u) * 4 + 0) != 1u)
                            {
                                _14524 = false;
                                break;
                            }
                            uint _14521;
                            _14521 = 0u;
                            for (; _14521 < 4u; _14521++)
                            {
                                for (uint _14522 = 0u; _14522 < 4u; )
                                {
                                    _10292[_14521][_14522] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10326 + 16u) + (_14521 * 4u)) + _14522) * 4 + 0));
                                    _14522++;
                                    continue;
                                }
                            }
                            _14524 = true;
                            break;
                        } while(false);
                        if (_14524)
                        {
                            _14525 = _10292;
                            break;
                        }
                        _14525 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14526;
                    do
                    {
                        float _10406 = 1.0f - _14163.y;
                        float4 _10417 = mul(float4((float2(_14163.x, _10406) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10278_dummy_parameter))))), 0)).x, 1.0f), _14525);
                        float _10419 = _10417.w;
                        if (!(_10419 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14526 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10432 = ((_10417.xy / _10419.xx) + 1.0f.xx) * 0.5f;
                        _14526 = float2(_10432.x - _14163.x, _10406 - _10432.y);
                        break;
                    } while(false);
                    float2 _5162 = float2(cbFI_DisplaySize);
                    _14528 = length(((_14163 + _14526) - _14164) * _5162) <= ((0.100000001490116119384765625f * length(_14526 * _5162)) + 8.0f);
                }
                else
                {
                    _14528 = _5141;
                }
                _14527 = _14528;
            }
            else
            {
                _14527 = true;
            }
            bool _5176 = !_14527;
            bool _17255 = _5176 ? false : _5080;
            bool _17256 = _5176 ? false : _5067;
            bool _14605;
            float4 _14644;
            if (!(((_5041 && _5054) && _17256) && _17255))
            {
                float4 _5198 = _14583 * float4(_5106, _5108, float(_17256), float(_17255));
                float _5200 = dot(_5198, 1.0f.xxxx);
                bool _5203 = !(_5200 > 0.0f);
                float4 _14645;
                if (!_5203)
                {
                    _14645 = _5198 / _5200.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10454;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10454);
                    }
                    _14645 = 0.0f.xxxx;
                }
                _14644 = _14645;
                _14605 = _5203;
            }
            else
            {
                _14644 = _14583;
                _14605 = false;
            }
            _16313 = float3(_5106, _5108, _14512);
            _14643 = _14644;
            _14604 = _14605;
        }
        else
        {
            _16313 = float3(float(_9898), _5025, 0.0f);
            _14643 = _14583;
            _14604 = false;
        }
        bool _5221 = !_14604;
        float4 _14736;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5221)
        {
            float _5228 = _14643.x + _14643.y;
            float4 _14737;
            if (_5228 > 0.001000000047497451305389404296875f)
            {
                _14737 = float4(_14643.x / _5228, _14643.y / _5228, 0.0f, 0.0f);
            }
            else
            {
                _14737 = float4(_4790, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14736 = _14737;
        }
        else
        {
            _14736 = _14643;
        }
        float4 _14913;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5221) && _9898)
        {
            float _14710;
            do
            {
                uint4 _10594 = r_warped_motion_qdata_tp1.Load(int3(_14381, 0));
                uint _10595 = _10594.x;
                if (_10595 != 0u)
                {
                    float _14709;
                    if (_10595 == 0u)
                    {
                        _14709 = -1.0f;
                    }
                    else
                    {
                        _14709 = float((_10595 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14710 = _14709;
                    break;
                }
                int _14692;
                uint _14693;
                _14693 = _10595;
                _14692 = -1;
                uint _14708;
                for (; _14692 <= 1; _14693 = _14708, _14692++)
                {
                    _14708 = _14693;
                    for (int _14706 = -1; _14706 <= 1; )
                    {
                        _14708 = max(_14708, r_warped_motion_qdata_tp1.Load(int3(clamp(_14381 + int2(_14706, _14692), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14706++;
                        continue;
                    }
                }
                if (_14693 != 0u)
                {
                    float _14705;
                    if (_14693 == 0u)
                    {
                        _14705 = -1.0f;
                    }
                    else
                    {
                        _14705 = float((_14693 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14710 = _14705;
                    break;
                }
                uint _14695;
                _14695 = 4294967295u;
                uint _17226;
                for (int _14694 = 0; _14694 < 8; _14695 = _17226, _14694++)
                {
                    int _14698 = 0;
                    for (;;)
                    {
                        if (_14698 < 5)
                        {
                            int2 _10545 = _14381 + (_1184[_14694] * _1193[_14698].xx);
                            bool _10548 = any(bool2(_10545.x < int2(0, 0).x, _10545.y < int2(0, 0).y));
                            bool _10556;
                            if (!_10548)
                            {
                                _10556 = any(bool2(_10545.x >= cbFI_MvDepthLaneSize.x, _10545.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10556 = _10548;
                            }
                            if (_10556)
                            {
                                _17226 = _14695;
                                break;
                            }
                            uint4 _10634 = r_warped_motion_qdata_tp1.Load(int3(_10545, 0));
                            uint _10635 = _10634.x;
                            if (_10635 != 0u)
                            {
                                _17226 = min(_14695, _10635);
                                break;
                            }
                            _14698++;
                            continue;
                        }
                        else
                        {
                            _17226 = _14695;
                            break;
                        }
                    }
                }
                float _14697;
                if (_14695 == 4294967295u)
                {
                    _14697 = -1.0f;
                }
                else
                {
                    float _14696;
                    if (_14695 == 0u)
                    {
                        _14696 = -1.0f;
                    }
                    else
                    {
                        _14696 = float((_14695 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14697 = _14696;
                }
                _14710 = _14697;
                break;
            } while(false);
            float _5264 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5267 = r_warped_motion_qdata_tp1.Load(int3(_14381, 0)).x == 0u;
            bool _5273;
            if (_5267)
            {
                bool _10660 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
                bool _10666;
                if (_10660)
                {
                    _10666 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
                }
                else
                {
                    _10666 = _10660;
                }
                _5273 = _10666;
            }
            else
            {
                _5273 = _5267;
            }
            bool _5278;
            if (_5273)
            {
                bool _10671 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
                bool _10677;
                if (_10671)
                {
                    _10677 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
                }
                else
                {
                    _10677 = _10671;
                }
                _5278 = _10677;
            }
            else
            {
                _5278 = _5273;
            }
            bool _14722;
            float4 _14731;
            if (_5278)
            {
                uint _10684_dummy_parameter;
                float _10708 = log((r_depth_tm1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10684_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _10716_dummy_parameter;
                float _10740 = log((r_depth_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10716_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _5289 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5296;
                if (_5289)
                {
                    _5296 = _10740 > (_10708 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5296 = _5289;
                }
                bool _14727;
                float4 _14749;
                if (_5296)
                {
                    _14749 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14727 = true;
                }
                else
                {
                    bool _5302 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5309;
                    if (_5302)
                    {
                        _5309 = _10708 > (_10740 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5309 = _5302;
                    }
                    bool4 _17257 = _5309.xxxx;
                    _14749 = float4(_17257.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14736.x, _17257.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14736.y, _17257.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14736.z, _17257.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14736.w);
                    _14727 = _5309 ? true : false;
                }
                _14731 = _14749;
                _14722 = _14727;
            }
            else
            {
                _14731 = _14736;
                _14722 = false;
            }
            float4 _14804;
            if (_14722)
            {
                _14804 = 1.0f.xxxx;
            }
            else
            {
                bool _5320 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5326;
                if (_5320)
                {
                    _5326 = _14731.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5326 = _5320;
                }
                bool _5331;
                if (_5326)
                {
                    bool _10746 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
                    bool _10752;
                    if (_10746)
                    {
                        _10752 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10752 = _10746;
                    }
                    _5331 = _10752;
                }
                else
                {
                    _5331 = _5326;
                }
                float4 _14805;
                if (_5331)
                {
                    float _14758;
                    if (_14710 >= 0.0f)
                    {
                        _14758 = _14710 - _5264;
                    }
                    else
                    {
                        float _14754;
                        _14754 = 2.0f;
                        float _10809;
                        for (int _14753 = 0; _14753 < 24; _14754 = _10809, _14753++)
                        {
                            float _10773 = float(_14753 & 7) * 0.785398185253143310546875f;
                            int _10775 = _14753 >> 3;
                            int _14755;
                            if (_10775 == 0)
                            {
                                _14755 = 16;
                            }
                            else
                            {
                                _14755 = (_10775 == 1) ? 48 : 96;
                            }
                            uint _10841_dummy_parameter;
                            _10809 = min(_14754, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14162 + ((cbFI_MvDepthLaneSizeRcp * float(_14755)) * float2(cos(_10773), sin(_10773))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10841_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14758 = _14754;
                    }
                    uint _10873_dummy_parameter;
                    float4 _14806;
                    if (r_depth_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10873_dummy_parameter))))), 0)).x > ((exp((_14758 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14806 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14806 = 1.0f.xxxx;
                    }
                    _14805 = _14806;
                }
                else
                {
                    _14805 = 1.0f.xxxx;
                }
                _14804 = _14805;
            }
            bool _5359 = _14710 >= 0.0f;
            bool _5360 = (!_14722) && _5359;
            bool _5367;
            if (_5360)
            {
                _5367 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5367 = _5360;
            }
            bool _5373;
            if (_5367)
            {
                _5373 = _14731.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5373 = _5367;
            }
            bool _5378;
            if (_5373)
            {
                bool _10897 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
                bool _10903;
                if (_10897)
                {
                    _10903 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
                }
                else
                {
                    _10903 = _10897;
                }
                _5378 = _10903;
            }
            else
            {
                _5378 = _5373;
            }
            float4 _14829;
            if (_5378)
            {
                float _14798;
                if (_5359)
                {
                    _14798 = _14710 - _5264;
                }
                else
                {
                    float _14794;
                    _14794 = 2.0f;
                    float _10960;
                    for (int _14793 = 0; _14793 < 24; _14794 = _10960, _14793++)
                    {
                        float _10924 = float(_14793 & 7) * 0.785398185253143310546875f;
                        int _10926 = _14793 >> 3;
                        int _14795;
                        if (_10926 == 0)
                        {
                            _14795 = 16;
                        }
                        else
                        {
                            _14795 = (_10926 == 1) ? 48 : 96;
                        }
                        uint _10976_dummy_parameter;
                        _10960 = min(_14794, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14160 + ((cbFI_MvDepthLaneSizeRcp * float(_14795)) * float2(cos(_10924), sin(_10924))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10976_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14798 = _14794;
                }
                uint _11024_dummy_parameter;
                float4 _14830;
                if (r_depth_tm1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11024_dummy_parameter))))), 0)).x > ((exp((_14798 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _13992 = _14804;
                    _13992.x = 0.0f;
                    _14830 = _13992;
                }
                else
                {
                    _14830 = _14804;
                }
                _14829 = _14830;
            }
            else
            {
                _14829 = _14804;
            }
            float4 _14842;
            if (_5360)
            {
                float _11050 = (exp(((_14710 - _5264) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5416 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5422;
                if (_5416)
                {
                    _5422 = _14731.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5422 = _5416;
                }
                bool _5427;
                if (_5422)
                {
                    bool _11055 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                    bool _11061;
                    if (_11055)
                    {
                        _11061 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11061 = _11055;
                    }
                    _5427 = _11061;
                }
                else
                {
                    _5427 = _5422;
                }
                bool _5435;
                if (_5427)
                {
                    uint _11068_dummy_parameter;
                    _5435 = r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11068_dummy_parameter))))), 0)).x > _11050;
                }
                else
                {
                    _5435 = _5427;
                }
                float4 _14840;
                if (_5435)
                {
                    float4 _13995 = _14829;
                    _13995.w = 0.0f;
                    _14840 = _13995;
                }
                else
                {
                    _14840 = _14829;
                }
                bool _5442 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5448;
                if (_5442)
                {
                    _5448 = _14731.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5448 = _5442;
                }
                bool _5453;
                if (_5448)
                {
                    bool _11085 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                    bool _11091;
                    if (_11085)
                    {
                        _11091 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11091 = _11085;
                    }
                    _5453 = _11091;
                }
                else
                {
                    _5453 = _5448;
                }
                bool _5461;
                if (_5453)
                {
                    uint _11098_dummy_parameter;
                    _5461 = r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11098_dummy_parameter))))), 0)).x > _11050;
                }
                else
                {
                    _5461 = _5453;
                }
                float4 _14843;
                if (_5461)
                {
                    float4 _13998 = _14840;
                    _13998.z = 0.0f;
                    _14843 = _13998;
                }
                else
                {
                    _14843 = _14840;
                }
                _14842 = _14843;
            }
            else
            {
                _14842 = _14829;
            }
            float4 _14914;
            if (any(bool4(_14842.x < 1.0f.xxxx.x, _14842.y < 1.0f.xxxx.y, _14842.z < 1.0f.xxxx.z, _14842.w < 1.0f.xxxx.w)))
            {
                float4 _5472 = _14731 * _14842;
                float _5474 = dot(_5472, 1.0f.xxxx);
                float4 _14915;
                if (_5474 > 0.0f)
                {
                    _14915 = _5472 / _5474.xxxx;
                }
                else
                {
                    bool _5485 = _14842.y == 0.0f;
                    bool _5491;
                    if (_5485)
                    {
                        _5491 = _14842.x > 0.0f;
                    }
                    else
                    {
                        _5491 = _5485;
                    }
                    bool _5496;
                    if (_5491)
                    {
                        bool _11115 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
                        bool _11121;
                        if (_11115)
                        {
                            _11121 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11121 = _11115;
                        }
                        _5496 = _11121;
                    }
                    else
                    {
                        _5496 = _5491;
                    }
                    float4 _14916;
                    if (_5496)
                    {
                        _14916 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5501 = _14842.x == 0.0f;
                        bool _5507;
                        if (_5501)
                        {
                            _5507 = _14842.y > 0.0f;
                        }
                        else
                        {
                            _5507 = _5501;
                        }
                        bool _5512;
                        if (_5507)
                        {
                            bool _11126 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
                            bool _11132;
                            if (_11126)
                            {
                                _11132 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11132 = _11126;
                            }
                            _5512 = _11132;
                        }
                        else
                        {
                            _5512 = _5507;
                        }
                        bool4 _17260 = _5512.xxxx;
                        _14916 = float4(_17260.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14731.x, _17260.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14731.y, _17260.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14731.z, _17260.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14731.w);
                    }
                    _14915 = _14916;
                }
                _14914 = _14915;
            }
            else
            {
                _14914 = _14731;
            }
            _14913 = _14914;
        }
        else
        {
            _14913 = _14736;
        }
        float4 _15643;
        bool _15949;
        float3 _16083;
        if (((cbFI_pad0 & 32768u) != 0u) && _5221)
        {
            bool _5529 = _14913.x > 0.00999999977648258209228515625f;
            bool _5532 = _14913.y > 0.00999999977648258209228515625f;
            bool _5541 = (_14913.z + _14913.w) > 0.0199999995529651641845703125f;
            bool _5547;
            if (_5541)
            {
                bool _11137 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                bool _11143;
                if (_11137)
                {
                    _11143 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                }
                else
                {
                    _11143 = _11137;
                }
                _5547 = _11143;
            }
            else
            {
                _5547 = _5541;
            }
            bool _5552;
            if (_5547)
            {
                bool _11148 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                bool _11154;
                if (_11148)
                {
                    _11154 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                }
                else
                {
                    _11154 = _11148;
                }
                _5552 = _11154;
            }
            else
            {
                _5552 = _5547;
            }
            bool _5559;
            if (_5552)
            {
                float _14929;
                do
                {
                    bool _11237 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                    bool _11243;
                    if (_11237)
                    {
                        _11243 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11243 = _11237;
                    }
                    bool _11174 = !_11243;
                    bool _11181;
                    if (!_11174)
                    {
                        bool _11248 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                        bool _11254;
                        if (_11248)
                        {
                            _11254 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11254 = _11248;
                        }
                        _11181 = !_11254;
                    }
                    else
                    {
                        _11181 = _11174;
                    }
                    if (_11181)
                    {
                        _14929 = 0.0f;
                        break;
                    }
                    uint _11261_dummy_parameter;
                    uint _11277_dummy_parameter;
                    float4x4 _14928;
                    do
                    {
                        float4x4 _11291;
                        bool _14927;
                        do
                        {
                            _11291 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14927 = false;
                                break;
                            }
                            uint _11325 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11325 + 32u) * 4 + 0) != 1u)
                            {
                                _14927 = false;
                                break;
                            }
                            uint _14924;
                            _14924 = 0u;
                            for (; _14924 < 4u; _14924++)
                            {
                                for (uint _14925 = 0u; _14925 < 4u; )
                                {
                                    _11291[_14924][_14925] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11325 + 16u) + (_14924 * 4u)) + _14925) * 4 + 0));
                                    _14925++;
                                    continue;
                                }
                            }
                            _14927 = true;
                            break;
                        } while(false);
                        if (_14927)
                        {
                            _14928 = _11291;
                            break;
                        }
                        _14928 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11202 = mul(float4((float2(_14163.x, 1.0f - _14163.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11261_dummy_parameter))))), 0)).x, 1.0f), _14928);
                    float _11204 = _11202.w;
                    if (abs(_11204) < 9.9999999747524270787835121154785e-07f)
                    {
                        _14929 = 0.0f;
                        break;
                    }
                    float _11215 = abs(cbFI_DeviceToViewDepth.y / ((_11202.z / _11204) - cbFI_DeviceToViewDepth.x));
                    float _11218 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11277_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _14929 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11215 - _11218) / max(max(_11215, _11218), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5559 = _14929 < 0.5f;
            }
            else
            {
                _5559 = _5552;
            }
            float4 _14948;
            if (_5559)
            {
                uint _11429_dummy_parameter;
                uint _11460_dummy_parameter;
                float4 _14949;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11429_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11460_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _14949 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _14949 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _14948 = _14949;
            }
            else
            {
                _14948 = 1.0f.xxxx;
            }
            bool _5583;
            if (_9898)
            {
                bool _11489 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
                bool _11495;
                if (_11489)
                {
                    _11495 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
                }
                else
                {
                    _11495 = _11489;
                }
                _5583 = _11495;
            }
            else
            {
                _5583 = _9898;
            }
            bool _5589;
            if (_9898)
            {
                bool _11500 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
                bool _11506;
                if (_11500)
                {
                    _11506 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
                }
                else
                {
                    _11506 = _11500;
                }
                _5589 = _11506;
            }
            else
            {
                _5589 = _9898;
            }
            bool _5595;
            if (_9930)
            {
                bool _11511 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                bool _11517;
                if (_11511)
                {
                    _11517 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                }
                else
                {
                    _11517 = _11511;
                }
                _5595 = _11517;
            }
            else
            {
                _5595 = _9930;
            }
            bool _5601;
            if (_9930)
            {
                bool _11522 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                bool _11528;
                if (_11522)
                {
                    _11528 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                }
                else
                {
                    _11528 = _11522;
                }
                _5601 = _11528;
            }
            else
            {
                _5601 = _9930;
            }
            bool _5604 = _5595 != _5601;
            bool _5610;
            if (_5604)
            {
                _5610 = _5583 || _5589;
            }
            else
            {
                _5610 = _5604;
            }
            float4 _15051;
            if (_5610)
            {
                float4 _14025 = _14948;
                _14025.z = 0.0f;
                _14025.w = 0.0f;
                _15051 = _14025;
            }
            else
            {
                _15051 = _14948;
            }
            bool _5617 = _5583 && _5529;
            bool _5620 = _5589 && _5532;
            float4 _15156;
            float3 _16192;
            if (_5617 || _5620)
            {
                float _15046;
                do
                {
                    uint4 _11667 = r_warped_motion_qdata_tp1.Load(int3(_14381, 0));
                    uint _11668 = _11667.x;
                    if (_11668 != 0u)
                    {
                        float _15045;
                        if (_11668 == 0u)
                        {
                            _15045 = -1.0f;
                        }
                        else
                        {
                            _15045 = float((_11668 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15046 = _15045;
                        break;
                    }
                    int _15028;
                    uint _15029;
                    _15029 = _11668;
                    _15028 = -1;
                    uint _15044;
                    for (; _15028 <= 1; _15029 = _15044, _15028++)
                    {
                        _15044 = _15029;
                        for (int _15042 = -1; _15042 <= 1; )
                        {
                            _15044 = max(_15044, r_warped_motion_qdata_tp1.Load(int3(clamp(_14381 + int2(_15042, _15028), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15042++;
                            continue;
                        }
                    }
                    if (_15029 != 0u)
                    {
                        float _15041;
                        if (_15029 == 0u)
                        {
                            _15041 = -1.0f;
                        }
                        else
                        {
                            _15041 = float((_15029 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15046 = _15041;
                        break;
                    }
                    uint _15031;
                    _15031 = 4294967295u;
                    uint _17227;
                    for (int _15030 = 0; _15030 < 8; _15031 = _17227, _15030++)
                    {
                        int _15034 = 0;
                        for (;;)
                        {
                            if (_15034 < 5)
                            {
                                int2 _11618 = _14381 + (_1184[_15030] * _1193[_15034].xx);
                                bool _11621 = any(bool2(_11618.x < int2(0, 0).x, _11618.y < int2(0, 0).y));
                                bool _11629;
                                if (!_11621)
                                {
                                    _11629 = any(bool2(_11618.x >= cbFI_MvDepthLaneSize.x, _11618.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11629 = _11621;
                                }
                                if (_11629)
                                {
                                    _17227 = _15031;
                                    break;
                                }
                                uint4 _11707 = r_warped_motion_qdata_tp1.Load(int3(_11618, 0));
                                uint _11708 = _11707.x;
                                if (_11708 != 0u)
                                {
                                    _17227 = min(_15031, _11708);
                                    break;
                                }
                                _15034++;
                                continue;
                            }
                            else
                            {
                                _17227 = _15031;
                                break;
                            }
                        }
                    }
                    float _15033;
                    if (_15031 == 4294967295u)
                    {
                        _15033 = -1.0f;
                    }
                    else
                    {
                        float _15032;
                        if (_15031 == 0u)
                        {
                            _15032 = -1.0f;
                        }
                        else
                        {
                            _15032 = float((_15031 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15033 = _15032;
                    }
                    _15046 = _15033;
                    break;
                } while(false);
                bool _5628 = _15046 < 0.0f;
                float _15047;
                if (_5628)
                {
                    _15047 = 0.0f;
                }
                else
                {
                    _15047 = _15046 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11729_dummy_parameter;
                uint _11761_dummy_parameter;
                float4 _15084;
                if ((_5628 && _5617) && _5620)
                {
                    uint _11793_dummy_parameter;
                    float _11817 = log((r_depth_tm1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11793_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11825_dummy_parameter;
                    float _11849 = log((r_depth_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11825_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _15085;
                    if (_11817 > (_11849 + 0.07999999821186065673828125f))
                    {
                        float4 _14029 = _15051;
                        _14029.x = 0.0f;
                        _15085 = _14029;
                    }
                    else
                    {
                        float4 _15086;
                        if (_11849 > (_11817 + 0.07999999821186065673828125f))
                        {
                            float4 _14031 = _15051;
                            _14031.y = 0.0f;
                            _15086 = _14031;
                        }
                        else
                        {
                            _15086 = _15051;
                        }
                        _15085 = _15086;
                    }
                    _15084 = _15085;
                }
                else
                {
                    _15084 = _15051;
                }
                float _5680 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5682 = _15046 >= 0.0f;
                float _15067;
                if (_5682)
                {
                    _15067 = _15046 - _5680;
                }
                else
                {
                    float _15063;
                    if (_5617)
                    {
                        float _15062;
                        _15062 = 2.0f;
                        float _11907;
                        for (int _15061 = 0; _15061 < 24; _15062 = _11907, _15061++)
                        {
                            float _11871 = float(_15061 & 7) * 0.785398185253143310546875f;
                            int _11873 = _15061 >> 3;
                            int _15064;
                            if (_11873 == 0)
                            {
                                _15064 = 16;
                            }
                            else
                            {
                                _15064 = (_11873 == 1) ? 48 : 96;
                            }
                            uint _11923_dummy_parameter;
                            _11907 = min(_15062, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14160 + ((cbFI_MvDepthLaneSizeRcp * float(_15064)) * float2(cos(_11871), sin(_11871))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11923_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15063 = _15062;
                    }
                    else
                    {
                        _15063 = 0.0f;
                    }
                    _15067 = _15063;
                }
                float _15074;
                if (_5682)
                {
                    _15074 = _15046 - _5680;
                }
                else
                {
                    float _15070;
                    if (_5620)
                    {
                        float _15069;
                        _15069 = 2.0f;
                        float _12021;
                        for (int _15068 = 0; _15068 < 24; _15069 = _12021, _15068++)
                        {
                            float _11985 = float(_15068 & 7) * 0.785398185253143310546875f;
                            int _11987 = _15068 >> 3;
                            int _15071;
                            if (_11987 == 0)
                            {
                                _15071 = 16;
                            }
                            else
                            {
                                _15071 = (_11987 == 1) ? 48 : 96;
                            }
                            uint _12053_dummy_parameter;
                            _12021 = min(_15069, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14162 + ((cbFI_MvDepthLaneSizeRcp * float(_15071)) * float2(cos(_11985), sin(_11985))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12053_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15070 = _15069;
                    }
                    else
                    {
                        _15070 = 0.0f;
                    }
                    _15074 = _15070;
                }
                float _15075;
                if (_5617)
                {
                    uint _12085_dummy_parameter;
                    _15075 = r_depth_tm1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12085_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15075 = 0.0f;
                }
                float _15076;
                if (_5620)
                {
                    uint _12104_dummy_parameter;
                    _15076 = r_depth_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12104_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15076 = 0.0f;
                }
                bool _5737;
                if (_5617)
                {
                    _5737 = _15075 > ((exp((_15067 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5737 = _5617;
                }
                float4 _15092;
                if (_5737)
                {
                    float4 _14033 = _15084;
                    _14033.x = 0.0f;
                    _15092 = _14033;
                }
                else
                {
                    _15092 = _15084;
                }
                bool _5749;
                if (_5620)
                {
                    _5749 = _15076 > ((exp((_15074 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5749 = _5620;
                }
                float4 _15094;
                if (_5749)
                {
                    float4 _14035 = _15092;
                    _14035.y = 0.0f;
                    _15094 = _14035;
                }
                else
                {
                    _15094 = _15092;
                }
                float4 _15157;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5682)
                {
                    bool _5769;
                    if (_5617)
                    {
                        _5769 = _15075 < ((exp((_15067 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5769 = _5617;
                    }
                    float4 _15096;
                    if (_5769)
                    {
                        float4 _14037 = _15094;
                        _14037.x = 0.0f;
                        _15096 = _14037;
                    }
                    else
                    {
                        _15096 = _15094;
                    }
                    bool _5781;
                    if (_5620)
                    {
                        _5781 = _15076 < ((exp((_15074 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5781 = _5620;
                    }
                    float4 _15158;
                    if (_5781)
                    {
                        float4 _14039 = _15096;
                        _14039.y = 0.0f;
                        _15158 = _14039;
                    }
                    else
                    {
                        _15158 = _15096;
                    }
                    _15157 = _15158;
                }
                else
                {
                    _15157 = _15094;
                }
                _16192 = float3(_15047, log((r_depth_tm1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11729_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_14162 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11761_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _15156 = _15157;
            }
            else
            {
                _16192 = float3(0.0f, 0.0f, 0.5f);
                _15156 = _15051;
            }
            bool _5792 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5541;
            bool _5798;
            if (_5792)
            {
                _5798 = _5595 || _5601;
            }
            else
            {
                _5798 = _5792;
            }
            float4 _15199;
            if (_5798)
            {
                float _15151;
                do
                {
                    uint4 _12283 = r_warped_motion_qdata_tp1.Load(int3(_14381, 0));
                    uint _12284 = _12283.x;
                    if (_12284 != 0u)
                    {
                        float _15150;
                        if (_12284 == 0u)
                        {
                            _15150 = -1.0f;
                        }
                        else
                        {
                            _15150 = float((_12284 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15151 = _15150;
                        break;
                    }
                    int _15133;
                    uint _15134;
                    _15134 = _12284;
                    _15133 = -1;
                    uint _15149;
                    for (; _15133 <= 1; _15134 = _15149, _15133++)
                    {
                        _15149 = _15134;
                        for (int _15147 = -1; _15147 <= 1; )
                        {
                            _15149 = max(_15149, r_warped_motion_qdata_tp1.Load(int3(clamp(_14381 + int2(_15147, _15133), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15147++;
                            continue;
                        }
                    }
                    if (_15134 != 0u)
                    {
                        float _15146;
                        if (_15134 == 0u)
                        {
                            _15146 = -1.0f;
                        }
                        else
                        {
                            _15146 = float((_15134 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15151 = _15146;
                        break;
                    }
                    uint _15136;
                    _15136 = 4294967295u;
                    uint _17228;
                    for (int _15135 = 0; _15135 < 8; _15136 = _17228, _15135++)
                    {
                        int _15139 = 0;
                        for (;;)
                        {
                            if (_15139 < 5)
                            {
                                int2 _12234 = _14381 + (_1184[_15135] * _1193[_15139].xx);
                                bool _12237 = any(bool2(_12234.x < int2(0, 0).x, _12234.y < int2(0, 0).y));
                                bool _12245;
                                if (!_12237)
                                {
                                    _12245 = any(bool2(_12234.x >= cbFI_MvDepthLaneSize.x, _12234.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12245 = _12237;
                                }
                                if (_12245)
                                {
                                    _17228 = _15136;
                                    break;
                                }
                                uint4 _12323 = r_warped_motion_qdata_tp1.Load(int3(_12234, 0));
                                uint _12324 = _12323.x;
                                if (_12324 != 0u)
                                {
                                    _17228 = min(_15136, _12324);
                                    break;
                                }
                                _15139++;
                                continue;
                            }
                            else
                            {
                                _17228 = _15136;
                                break;
                            }
                        }
                    }
                    float _15138;
                    if (_15136 == 4294967295u)
                    {
                        _15138 = -1.0f;
                    }
                    else
                    {
                        float _15137;
                        if (_15136 == 0u)
                        {
                            _15137 = -1.0f;
                        }
                        else
                        {
                            _15137 = float((_15136 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15138 = _15137;
                    }
                    _15151 = _15138;
                    break;
                } while(false);
                float4 _15200;
                if (_15151 >= 0.0f)
                {
                    float _12345 = (exp((_15151 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5817;
                    if (_5595)
                    {
                        uint _12352_dummy_parameter;
                        _5817 = r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12352_dummy_parameter))))), 0)).x > _12345;
                    }
                    else
                    {
                        _5817 = _5595;
                    }
                    float4 _15169;
                    if (_5817)
                    {
                        float4 _14041 = _15156;
                        _14041.z = 0.0f;
                        _15169 = _14041;
                    }
                    else
                    {
                        _15169 = _15156;
                    }
                    bool _5829;
                    if (_5601)
                    {
                        uint _12371_dummy_parameter;
                        _5829 = r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12371_dummy_parameter))))), 0)).x > _12345;
                    }
                    else
                    {
                        _5829 = _5601;
                    }
                    float4 _15201;
                    if (_5829)
                    {
                        float4 _14043 = _15169;
                        _14043.w = 0.0f;
                        _15201 = _14043;
                    }
                    else
                    {
                        _15201 = _15169;
                    }
                    _15200 = _15201;
                }
                else
                {
                    _15200 = _15156;
                }
                _15199 = _15200;
            }
            else
            {
                _15199 = _15156;
            }
            bool _5837 = _5583 != _5589;
            bool _5844;
            if (_5837)
            {
                _5844 = _5583 ? _5529 : _5532;
            }
            else
            {
                _5844 = _5837;
            }
            bool _5851;
            if (_5844)
            {
                _5851 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5851 = _5844;
            }
            float4 _15302;
            if (_5851)
            {
                bool2 _5856 = _5583.xx;
                float2 _5857 = float2(_5856.x ? _14160.x : _14162.x, _5856.y ? _14160.y : _14162.y);
                float _15183;
                if (_5583)
                {
                    uint _12390_dummy_parameter;
                    _15183 = r_depth_tm1.Load(int3(int2(floor(_5857 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12390_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12406_dummy_parameter;
                    _15183 = r_depth_tp1.Load(int3(int2(floor(_5857 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12406_dummy_parameter))))), 0)).x;
                }
                float4x4 _15190;
                if (_5583)
                {
                    float4x4 _15179;
                    do
                    {
                        float4x4 _12420;
                        bool _15178;
                        do
                        {
                            _12420 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15178 = false;
                                break;
                            }
                            uint _12454 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12454 + 32u) * 4 + 0) != 1u)
                            {
                                _15178 = false;
                                break;
                            }
                            uint _15175;
                            _15175 = 0u;
                            for (; _15175 < 4u; _15175++)
                            {
                                for (uint _15176 = 0u; _15176 < 4u; )
                                {
                                    _12420[_15175][_15176] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12454 + 16u) + (_15175 * 4u)) + _15176) * 4 + 0));
                                    _15176++;
                                    continue;
                                }
                            }
                            _15178 = true;
                            break;
                        } while(false);
                        if (_15178)
                        {
                            _15179 = _12420;
                            break;
                        }
                        _15179 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15190 = _15179;
                }
                else
                {
                    float4x4 _15174;
                    do
                    {
                        float4x4 _12526;
                        bool _15173;
                        do
                        {
                            _12526 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15173 = false;
                                break;
                            }
                            uint _12560 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12560 + 32u) * 4 + 0) != 1u)
                            {
                                _15173 = false;
                                break;
                            }
                            uint _15170;
                            _15170 = 0u;
                            for (; _15170 < 4u; _15170++)
                            {
                                for (uint _15171 = 0u; _15171 < 4u; )
                                {
                                    _12526[_15170][_15171] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12560 + (_15170 * 4u)) + _15171) * 4 + 0));
                                    _15171++;
                                    continue;
                                }
                            }
                            _15173 = true;
                            break;
                        } while(false);
                        if (_15173)
                        {
                            _15174 = _12526;
                            break;
                        }
                        _15174 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15190 = _15174;
                }
                float2 _15191;
                do
                {
                    float _12637 = _5857.x;
                    float _12640 = 1.0f - _5857.y;
                    float4 _12651 = mul(float4((float2(_12637, _12640) * 2.0f) - 1.0f.xx, _15183, 1.0f), _15190);
                    float _12653 = _12651.w;
                    if (!(_12653 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15191 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12666 = ((_12651.xy / _12653.xx) + 1.0f.xx) * 0.5f;
                    _15191 = float2(_12666.x - _12637, _12640 - _12666.y);
                    break;
                } while(false);
                float2 _5887 = float2(cbFI_DisplaySize);
                float4 _15303;
                if (!(length(((_5857 + _15191) - float2(_5856.x ? _14162.x : _14160.x, _5856.y ? _14162.y : _14160.y)) * _5887) <= ((0.100000001490116119384765625f * length(_15191 * _5887)) + 8.0f)))
                {
                    float4 _15304;
                    if (_5583)
                    {
                        float4 _14053 = _15199;
                        _14053.x = 0.0f;
                        _15304 = _14053;
                    }
                    else
                    {
                        float4 _14055 = _15199;
                        _14055.y = 0.0f;
                        _15304 = _14055;
                    }
                    _15303 = _15304;
                }
                else
                {
                    _15303 = _15199;
                }
                _15302 = _15303;
            }
            else
            {
                _15302 = _15199;
            }
            float4 _5912 = _14913 * _15302;
            float _5914 = dot(_5912, 1.0f.xxxx);
            float4 _15644;
            bool _15950;
            if (_5914 > 0.0f)
            {
                _15950 = _14604;
                _15644 = _5912 / _5914.xxxx;
            }
            else
            {
                bool _5925 = any(bool4(_15302.x < 1.0f.xxxx.x, _15302.y < 1.0f.xxxx.y, _15302.z < 1.0f.xxxx.z, _15302.w < 1.0f.xxxx.w));
                if (_5925)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12688;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12688);
                    }
                }
                bool4 _17263 = _5925.xxxx;
                _15950 = _5925 ? true : _14604;
                _15644 = float4(_17263.x ? 0.0f.xxxx.x : _14913.x, _17263.y ? 0.0f.xxxx.y : _14913.y, _17263.z ? 0.0f.xxxx.z : _14913.z, _17263.w ? 0.0f.xxxx.w : _14913.w);
            }
            _16083 = _16192;
            _15949 = _15950;
            _15643 = _15644;
        }
        else
        {
            _16083 = float3(0.0f, 0.0f, 0.5f);
            _15949 = _14604;
            _15643 = _14913;
        }
        uint _5934 = (cbFI_pad0 >> 24u) & 31u;
        uint _5938 = (cbFI_pad0 >> 16u) & 255u;
        bool _5940 = _5934 != 0u;
        bool _5942 = _5938 == 12u;
        bool _5945 = _5938 == 13u;
        float4 _15664;
        if ((_5940 || _5942) || _5945)
        {
            float _15310;
            do
            {
                bool _12772 = all(bool2(_14163.x > 0.0f.xx.x, _14163.y > 0.0f.xx.y));
                bool _12778;
                if (_12772)
                {
                    _12778 = all(bool2(_14163.x < 1.0f.xx.x, _14163.y < 1.0f.xx.y));
                }
                else
                {
                    _12778 = _12772;
                }
                bool _12709 = !_12778;
                bool _12716;
                if (!_12709)
                {
                    bool _12783 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
                    bool _12789;
                    if (_12783)
                    {
                        _12789 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12789 = _12783;
                    }
                    _12716 = !_12789;
                }
                else
                {
                    _12716 = _12709;
                }
                if (_12716)
                {
                    _15310 = 0.0f;
                    break;
                }
                uint _12796_dummy_parameter;
                uint _12812_dummy_parameter;
                float4x4 _15309;
                do
                {
                    float4x4 _12826;
                    bool _15308;
                    do
                    {
                        _12826 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15308 = false;
                            break;
                        }
                        uint _12860 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12860 + 32u) * 4 + 0) != 1u)
                        {
                            _15308 = false;
                            break;
                        }
                        uint _15305;
                        _15305 = 0u;
                        for (; _15305 < 4u; _15305++)
                        {
                            for (uint _15306 = 0u; _15306 < 4u; )
                            {
                                _12826[_15305][_15306] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12860 + 16u) + (_15305 * 4u)) + _15306) * 4 + 0));
                                _15306++;
                                continue;
                            }
                        }
                        _15308 = true;
                        break;
                    } while(false);
                    if (_15308)
                    {
                        _15309 = _12826;
                        break;
                    }
                    _15309 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12737 = mul(float4((float2(_14163.x, 1.0f - _14163.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14163 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12796_dummy_parameter))))), 0)).x, 1.0f), _15309);
                float _12739 = _12737.w;
                if (abs(_12739) < 9.9999999747524270787835121154785e-07f)
                {
                    _15310 = 0.0f;
                    break;
                }
                float _12750 = abs(cbFI_DeviceToViewDepth.y / ((_12737.z / _12739) - cbFI_DeviceToViewDepth.x));
                float _12753 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12812_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15310 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12750 - _12753) / max(max(_12750, _12753), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _12962 = all(bool2(_14164.x > 0.0f.xx.x, _14164.y > 0.0f.xx.y));
            bool _12968;
            if (_12962)
            {
                _12968 = all(bool2(_14164.x < 1.0f.xx.x, _14164.y < 1.0f.xx.y));
            }
            else
            {
                _12968 = _12962;
            }
            float _15311;
            if (_12968)
            {
                uint _12975_dummy_parameter;
                _15311 = length((_6796 + (r_motion_tp1.Load(int3(int2(floor(_14164 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12975_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15311 = 1000000.0f;
            }
            float _15326;
            if ((_5934 & 1u) != 0u)
            {
                _15326 = _15310;
            }
            else
            {
                _15326 = 1.0f;
            }
            float _15327;
            if ((_5934 & 2u) != 0u)
            {
                _15327 = _15326 * (1.0f - smoothstep(2.0f, 8.0f, _15311));
            }
            else
            {
                _15327 = _15326;
            }
            float _15328;
            if ((_5934 & 4u) != 0u)
            {
                _15328 = _15327 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7517 - _7525) - length(_7501 - _7509))));
            }
            else
            {
                _15328 = _15327;
            }
            float _15658;
            if ((_5934 & 8u) != 0u)
            {
                _15658 = lerp(1.0f, _15328, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7501 - _7509)));
            }
            else
            {
                _15658 = _15328;
            }
            bool _6020 = (_5934 & 16u) != 0u;
            bool _6029;
            if (_6020)
            {
                _6029 = length(_14158 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6029 = _6020;
            }
            float _17265 = _6029 ? 1.0f : _15658;
            bool _6035 = _5940 && _9898;
            bool _6040;
            if (_6035)
            {
                bool _13000 = all(bool2(_14160.x > 0.0f.xx.x, _14160.y > 0.0f.xx.y));
                bool _13006;
                if (_13000)
                {
                    _13006 = all(bool2(_14160.x < 1.0f.xx.x, _14160.y < 1.0f.xx.y));
                }
                else
                {
                    _13006 = _13000;
                }
                _6040 = _13006;
            }
            else
            {
                _6040 = _6035;
            }
            bool _6045;
            if (_6040)
            {
                bool _13011 = all(bool2(_14162.x > 0.0f.xx.x, _14162.y > 0.0f.xx.y));
                bool _13017;
                if (_13011)
                {
                    _13017 = all(bool2(_14162.x < 1.0f.xx.x, _14162.y < 1.0f.xx.y));
                }
                else
                {
                    _13017 = _13011;
                }
                _6045 = _13017;
            }
            else
            {
                _6045 = _6040;
            }
            float4 _15665;
            if (_6045)
            {
                float _6051 = _15643.x + _15643.y;
                float _6060 = (_15643.z + _15643.w) * (1.0f - _17265);
                float _15661;
                if (_6051 > 9.9999997473787516355514526367188e-06f)
                {
                    _15661 = _15643.x / _6051;
                }
                else
                {
                    _15661 = _4790;
                }
                _15665 = float4(_15643.x + (_6060 * _15661), _15643.y + (_6060 * (1.0f - _15661)), _15643.zw * _17265);
            }
            else
            {
                _15665 = _15643;
            }
            _15664 = _15665;
        }
        else
        {
            _15664 = _15643;
        }
        float3 _6121 = (((_7501 * _15664.x) + (_7509 * _15664.y)) + (_7517 * _15664.z)) + (_7525 * _15664.w);
        float3 _17028;
        if (_4806 && (_15679 > 0.0f))
        {
            uint _13024_dummy_parameter;
            float2 _13039 = r_motion_tp1.Load(int3(int2(floor(_4565 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13024_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _15941;
            if (_6824)
            {
                float2 _13084 = clamp((((_14137 + (_13039 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13087 = tan(_13084.x);
                _15941 = (float2(_13087 / cbFI_DeviceToViewDepth.z, (tan(_13084.y) * sqrt(1.0f + (_13087 * _13087))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15941 = _14137 + (_13039 * cbFI_Timestep);
            }
            float2 _15942;
            if (_6824)
            {
                float2 _13163 = clamp((((_14137 + (_13039 * _4780)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13166 = tan(_13163.x);
                _15942 = (float2(_13166 / cbFI_DeviceToViewDepth.z, (tan(_13163.y) * sqrt(1.0f + (_13166 * _13166))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15942 = _14137 + (_13039 * _4780);
            }
            _17028 = lerp(_6121, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _15941, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _15942, 0.0f).xyz, cbFI_Timestep.xxx), _15679.xxx);
        }
        else
        {
            _17028 = _6121;
        }
        float3 _17027;
        if (_15949)
        {
            float3 _13208 = r_current_interpolation_source.Load(int3(_4101, 0)).xyz;
            float3 _17029;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9898)
            {
                uint _13215_dummy_parameter;
                float _16072;
                _16072 = r_depth_tm1.Load(int3(int2(floor(_14160 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13215_dummy_parameter))))), 0)).x;
                float _6202;
                for (int _16071 = 0; _16071 < 24; _16072 = _6202, _16071++)
                {
                    float _6174 = float(_16071 & 7) * 0.785398185253143310546875f;
                    int _6176 = _16071 >> 3;
                    int _17081;
                    if (_6176 == 0)
                    {
                        _17081 = 16;
                    }
                    else
                    {
                        _17081 = (_6176 == 1) ? 48 : 96;
                    }
                    uint _13235_dummy_parameter;
                    _6202 = min(_16072, r_depth_tm1.Load(int3(int2(floor(clamp(_14160 + ((cbFI_MvDepthLaneSizeRcp * float(_17081)) * float2(cos(_6174), sin(_6174))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13235_dummy_parameter))))), 0)).x);
                }
                float2 _16073;
                do
                {
                    float _13257 = 1.0f - _14160.y;
                    float4 _13268 = mul(float4((float2(_14160.x, _13257) * 2.0f) - 1.0f.xx, _16072, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13270 = _13268.w;
                    if (!(_13270 > 9.9999999747524270787835121154785e-07f))
                    {
                        _16073 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13283 = ((_13268.xy / _13270.xx) + 1.0f.xx) * 0.5f;
                    _16073 = float2(_13283.x - _14160.x, _13257 - _13283.y);
                    break;
                } while(false);
                float2 _6213 = _14160 + _16073;
                bool _13301 = all(bool2(_6213.x > 0.0f.xx.x, _6213.y > 0.0f.xx.y));
                bool _13307;
                if (_13301)
                {
                    _13307 = all(bool2(_6213.x < 1.0f.xx.x, _6213.y < 1.0f.xx.y));
                }
                else
                {
                    _13307 = _13301;
                }
                float3 _17030;
                if (_13307)
                {
                    float _6219 = abs(cbFI_DeviceToViewDepth.y / (_16072 - cbFI_DeviceToViewDepth.x));
                    uint _13327_dummy_parameter;
                    int2 _13327 = int2(spvTextureSize(r_depth_m2, uint(0), _13327_dummy_parameter));
                    float _6223 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6213 * float2(_13327))), int2(0, 0), _13327 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _17035;
                    if (abs(_6223 - _6219) <= (0.20000000298023223876953125f * max(_6223, _6219)))
                    {
                        uint _13361_dummy_parameter;
                        int2 _13361 = int2(spvTextureSize(r_colour_m2, uint(0), _13361_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13384;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13384);
                        }
                        _17035 = r_colour_m2.Load(int3(clamp(int2(floor(_6213 * float2(_13361))), int2(0, 0), _13361 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13394;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13394);
                        }
                        _17035 = _13208;
                    }
                    _17030 = _17035;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13404;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13404);
                    }
                    _17030 = _13208;
                }
                _17029 = _17030;
            }
            else
            {
                _17029 = _13208;
            }
            _17027 = _17029;
        }
        else
        {
            _17027 = _17028;
        }
        uint _6251 = cbFI_pad0 & 255u;
        bool _16901;
        float3 _17026;
        if (_6251 != 0u)
        {
            float3 _6256 = r_present_backbuffer.Load(int3(_4101, 0)).xyz;
            float3 _6260 = r_current_interpolation_source.Load(int3(_4101, 0)).xyz;
            float3 _6264 = abs(_6256 - _6260);
            float3 _16076;
            if (_6251 == 2u)
            {
                _16076 = (abs(_6260) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _16076 = 0.000244140625f.xxx;
            }
            bool _6280 = any(bool3(_6264.x > _16076.x, _6264.y > _16076.y, _6264.z > _16076.z));
            bool3 _17266 = _6280.xxx;
            _17026 = float3(_17266.x ? _6256.x : _17027.x, _17266.y ? _6256.y : _17027.y, _17266.z ? _6256.z : _17027.z);
            _16901 = _6280;
        }
        else
        {
            _17026 = _17027;
            _16901 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13419;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13419);
        }
        float3 _17008;
        if (_5938 == 1u)
        {
            _17008 = lerp(_7501, _7509, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _17009;
            if (_5938 == 2u)
            {
                _17009 = lerp(_7517, _7525, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _17010;
                if (_5938 == 3u)
                {
                    _17010 = float(_16901).xxx;
                }
                else
                {
                    float3 _17011;
                    if (_5938 == 4u)
                    {
                        _17011 = float3(((_14158 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _17012;
                        if (_5938 == 5u)
                        {
                            _17012 = float3(((_6796 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _17013;
                            if (_5938 == 6u)
                            {
                                _17013 = float3(_15664.xy, _15664.z + _15664.w);
                            }
                            else
                            {
                                float3 _17014;
                                if (_5938 == 7u)
                                {
                                    _17014 = r_current_interpolation_source.Load(int3(_4101, 0)).xyz;
                                }
                                else
                                {
                                    float3 _17015;
                                    if (_5938 == 8u)
                                    {
                                        _17015 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4565, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _17016;
                                        if (_5942)
                                        {
                                            uint _13441_dummy_parameter;
                                            uint _13473_dummy_parameter;
                                            _17016 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4565 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13441_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4565 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13473_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _17017;
                                            if (_5945)
                                            {
                                                _17017 = _7517;
                                            }
                                            else
                                            {
                                                float3 _17018;
                                                if (_5938 == 20u)
                                                {
                                                    _17018 = _7501;
                                                }
                                                else
                                                {
                                                    float3 _17019;
                                                    if (_5938 == 21u)
                                                    {
                                                        _17019 = _7509;
                                                    }
                                                    else
                                                    {
                                                        float3 _17020;
                                                        if (_5938 == 22u)
                                                        {
                                                            _17020 = _7525;
                                                        }
                                                        else
                                                        {
                                                            float3 _17021;
                                                            if (_5938 == 18u)
                                                            {
                                                                _17021 = _16549;
                                                            }
                                                            else
                                                            {
                                                                float3 _17022;
                                                                if (_5938 == 19u)
                                                                {
                                                                    _17022 = _16313;
                                                                }
                                                                else
                                                                {
                                                                    float3 _17023;
                                                                    if (_5938 == 23u)
                                                                    {
                                                                        _17023 = _16083;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _17024;
                                                                        if (_5938 == 24u)
                                                                        {
                                                                            uint _6424 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _6429 = float(rw_nfru_diagnostics.Load<uint>((_6424 + 35u) * 4 + 0));
                                                                            float _16077;
                                                                            if (_6429 > 0.0f)
                                                                            {
                                                                                _16077 = float(rw_nfru_diagnostics.Load<uint>((_6424 + 34u) * 4 + 0)) / _6429;
                                                                            }
                                                                            else
                                                                            {
                                                                                _16077 = 0.0f;
                                                                            }
                                                                            _17024 = float3(float(rw_nfru_diagnostics.Load<uint>((_6424 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_6424 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _16077);
                                                                        }
                                                                        else
                                                                        {
                                                                            _17024 = _17026;
                                                                        }
                                                                        _17023 = _17024;
                                                                    }
                                                                    _17022 = _17023;
                                                                }
                                                                _17021 = _17022;
                                                            }
                                                            _17020 = _17021;
                                                        }
                                                        _17019 = _17020;
                                                    }
                                                    _17018 = _17019;
                                                }
                                                _17017 = _17018;
                                            }
                                            _17016 = _17017;
                                        }
                                        _17015 = _17016;
                                    }
                                    _17014 = _17015;
                                }
                                _17013 = _17014;
                            }
                            _17012 = _17013;
                        }
                        _17011 = _17012;
                    }
                    _17010 = _17011;
                }
                _17009 = _17010;
            }
            _17008 = _17009;
        }
        float3 _17007;
        if ((_5938 >= 9u) && (_5938 <= 11u))
        {
            uint _6489 = 64u + uint((_14381.y * cbFI_MvDepthLaneSize.x) + _14381.x);
            uint _6493 = rw_nfru_diagnostics.Load<uint>(_6489 * 4 + 0) & 15u;
            float3 _17040;
            if (_5938 == 10u)
            {
                float3 _17006;
                if ((rw_nfru_diagnostics.Load<uint>(_6489 * 4 + 0) & 32u) != 0u)
                {
                    _17006 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _17005;
                    if ((rw_nfru_diagnostics.Load<uint>(_6489 * 4 + 0) & 16u) != 0u)
                    {
                        _17005 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6514 = ((rw_nfru_diagnostics.Load<uint>(_6489 * 4 + 0) & 64u) != 0u).xxx;
                        _17005 = float3(_6514.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6514.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6514.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _17006 = _17005;
                }
                _17040 = _17006;
            }
            else
            {
                float3 _17041;
                if (_5938 == 11u)
                {
                    uint _6527 = (rw_nfru_diagnostics.Load<uint>(_6489 * 4 + 0) >> 8u) & 15u;
                    uint _6530 = (rw_nfru_diagnostics.Load<uint>(_6489 * 4 + 0) >> 12u) & 15u;
                    float3 _16998;
                    if ((_6493 == 2u) || (_6493 == 3u))
                    {
                        _16998 = _3814[_6493];
                    }
                    else
                    {
                        bool _6542 = _6527 == 3u;
                        bool _6544 = _6530 == 3u;
                        float3 _16999;
                        if (_6542 && _6544)
                        {
                            _16999 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _17000;
                            if (_6542)
                            {
                                _17000 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _17001;
                                if (_6544)
                                {
                                    _17001 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _17002;
                                    if ((_6527 == 4u) || (_6530 == 4u))
                                    {
                                        _17002 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _17003;
                                        if ((_6527 == 1u) || (_6530 == 1u))
                                        {
                                            _17003 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17268 = (_6493 == 1u).xxx;
                                            _17003 = float3(_17268.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17268.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17268.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _17002 = _17003;
                                    }
                                    _17001 = _17002;
                                }
                                _17000 = _17001;
                            }
                            _16999 = _17000;
                        }
                        _16998 = _16999;
                    }
                    _17041 = _16998;
                }
                else
                {
                    _17041 = _3814[min(_6493, 7u)];
                }
                _17040 = _17041;
            }
            _17007 = _17040;
        }
        else
        {
            _17007 = _17008;
        }
        float4 _17044;
        if ((_5938 >= 14u) && (_5938 <= 16u))
        {
            float2 _17042;
            if (_5938 == 14u)
            {
                uint _6600_dummy_parameter;
                uint _6606_dummy_parameter;
                _17042 = r_flow_tm1.Load(int3(clamp(int2(floor(_4565 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6600_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6606_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _17043;
                if (_5938 == 16u)
                {
                    uint _13549 = r_warped_flow_qdata_tm1.Load(int3(_4581, 0)).x & 2147483647u;
                    uint _13581 = uint(max((int((_13549 >> 16u) & 15u) - 6), 0));
                    _17043 = ((float2(float((1 - (2 * int((_13549 >> 15u) & 1u))) * int(((_13549 >> uint(7)) & 127u) << _13581)), float((1 - (2 * int((_13549 >> 14u) & 1u))) * int((_13549 & 127u) << _13581))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _17043 = _6796 * float2(cbFI_DisplaySize);
                }
                _17042 = _17043;
            }
            uint2 _6639 = uint2(clamp(round(_17042 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6641 = _6639.x;
            uint _6648 = _6639.y;
            _17044 = float4(float(_6641 & 255u), float((_6641 >> 8u) | ((_6648 & 15u) << 4u)), float(_6648 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _17045;
            if (_5938 == 17u)
            {
                _17045 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4581, 0)).x != 0u), _5025, 0.0f, 1.0f);
            }
            else
            {
                _17045 = float4(_17007, 1.0f);
            }
            _17044 = _17045;
        }
        rw_output[_4101] = _17044.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6692 = ((uint(_4101.y) * uint(cbFI_DisplaySize.x)) + uint(_4101.x)) * 6u;
            uint _13627 = spvPackHalf2x16(clamp(_7500.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6692 * 4 + 0, (((_13627 & 32767u) >> 4u) | ((((_13627 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7500.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13662 = spvPackHalf2x16(clamp(_7508.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6692 + 1u) * 4 + 0, (((_13662 & 32767u) >> 4u) | ((((_13662 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7508.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13697 = spvPackHalf2x16(clamp(_7516.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6692 + 2u) * 4 + 0, (((_13697 & 32767u) >> 4u) | ((((_13697 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7516.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13732 = spvPackHalf2x16(clamp(_7524.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6692 + 3u) * 4 + 0, (((_13732 & 32767u) >> 4u) | ((((_13732 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7524.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13759 = r_current_interpolation_source.Load(int3(_4101, 0));
            uint _13773 = spvPackHalf2x16(clamp(_13759.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6692 + 4u) * 4 + 0, (((_13773 & 32767u) >> 4u) | ((((_13773 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13759.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _17080;
            if (_16901 || (_5938 != 0u))
            {
                _17080 = 4294967295u;
            }
            else
            {
                uint _13808 = spvPackHalf2x16(clamp(_17044.xy, 0.0f.xx, 65000.0f.xx));
                _17080 = (((_13808 & 32767u) >> 4u) | ((((_13808 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_17044.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6692 + 5u) * 4 + 0, _17080);
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
