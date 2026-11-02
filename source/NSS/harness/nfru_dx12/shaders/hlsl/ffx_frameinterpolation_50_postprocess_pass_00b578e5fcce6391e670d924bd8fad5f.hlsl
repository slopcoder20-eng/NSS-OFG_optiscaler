static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1184[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1193[5] = { 2, 4, 7, 11, 16 };
static const float3 _3815[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4102 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4102.x >= cbFI_DisplaySize.x, _4102.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4102] = float4(r_present_backbuffer.Load(int3(_4102, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4566 = (float2(_4102) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4568 = float2(cbFI_MvDepthLaneSize);
        int2 _4577 = int2(floor(_4566 * _4568));
        int2 _4582 = int2(floor(_4566 * float2(cbFI_FlowLaneSize)));
        float4 _6791 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4566 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6797 = r_warped_filled_flow_tm1.Load(int3(_4582, 0)).xy;
        float2 _6803 = r_warped_filled_motion_tp1.Load(int3(_4577, 0)).xy;
        bool _6825 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14146;
        if (_6825)
        {
            float _6838 = ((2.0f * _4566.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14146 = float2(atan(_6838) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4566.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6838 * _6838))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14146 = _4566;
        }
        bool _4603 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14167;
        bool _14309;
        int2 _14390;
        float3 _16558;
        if (_4603)
        {
            float _14148;
            float _14150;
            _14150 = 2.0f;
            _14148 = -1.0f;
            uint _4184[9];
            float _17131;
            float _17134;
            for (int _14147 = 0; _14147 < 9; _14150 = _17134, _14148 = _17131, _14147++)
            {
                _4184[_14147] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4577 + int2((_14147 % 3) - 1, (_14147 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4184[_14147] != 0u)
                {
                    float _17126;
                    if (_4184[_14147] == 0u)
                    {
                        _17126 = -1.0f;
                    }
                    else
                    {
                        _17126 = float((_4184[_14147] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17134 = min(_14150, _17126);
                    _17131 = max(_14148, _17126);
                }
                else
                {
                    _17134 = _14150;
                    _17131 = _14148;
                }
            }
            float _4649 = float(_14148 >= 0.0f);
            float3 _13849 = 0.0f.xxx;
            _13849.y = _4649;
            float2 _14168;
            bool _14310;
            int2 _14391;
            float3 _16559;
            if ((_14148 - _14150) > 0.0199999995529651641845703125f)
            {
                float _14156;
                int2 _14157;
                float2 _14158;
                int2 _14160;
                float2 _14166;
                _14166 = _6803;
                _14160 = _4577;
                _14158 = _6803;
                _14157 = _4577;
                _14156 = -1.0f;
                float _17139;
                int2 _17143;
                float2 _17154;
                int2 _17165;
                float2 _17198;
                float _17245;
                int _14155 = 0;
                float _17107 = 1000000000.0f;
                for (; _14155 < 9; _17107 = _17245, _14166 = _17198, _14160 = _17165, _14158 = _17154, _14157 = _17143, _14156 = _17139, _14155++)
                {
                    if (_4184[_14155] == 0u)
                    {
                        _17245 = _17107;
                        _17198 = _14166;
                        _17165 = _14160;
                        _17154 = _14158;
                        _17143 = _14157;
                        _17139 = _14156;
                        continue;
                    }
                    int2 _4684 = clamp(_4577 + int2((_14155 % 3) - 1, (_14155 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6913 = _4184[_14155] & 2147483647u;
                    uint _6945 = uint(max((int((_6913 >> 16u) & 15u) - 6), 0));
                    float2 _4690 = (float2(float((1 - (2 * int((_6913 >> 15u) & 1u))) * int(((_6913 >> uint(7)) & 127u) << _6945)), float((1 - (2 * int((_6913 >> 14u) & 1u))) * int((_6913 & 127u) << _6945))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _17093;
                    if (_4184[_14155] == 0u)
                    {
                        _17093 = -1.0f;
                    }
                    else
                    {
                        _17093 = float((_4184[_14155] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4695 = _17093 - 0.100000001490116119384765625f;
                    float2 _17094;
                    if (_6825)
                    {
                        float2 _7022 = clamp((((_14146 + (_4690 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7025 = tan(_7022.x);
                        _17094 = (float2(_7025 / cbFI_DeviceToViewDepth.z, (tan(_7022.y) * sqrt(1.0f + (_7025 * _7025))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17094 = _14146 + (_4690 * cbFI_Timestep);
                    }
                    float _4702 = cbFI_Timestep - 1.0f;
                    float2 _17095;
                    if (_6825)
                    {
                        float2 _7093 = clamp((((_14146 + (_4690 * _4702)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7096 = tan(_7093.x);
                        _17095 = (float2(_7096 / cbFI_DeviceToViewDepth.z, (tan(_7093.y) * sqrt(1.0f + (_7096 * _7096))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17095 = _14146 + (_4690 * _4702);
                    }
                    bool _7129 = all(bool2(_17094.x > 0.0f.xx.x, _17094.y > 0.0f.xx.y));
                    bool _7135;
                    if (_7129)
                    {
                        _7135 = all(bool2(_17094.x < 1.0f.xx.x, _17094.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7135 = _7129;
                    }
                    float _17098;
                    if (_7135)
                    {
                        uint _7142_dummy_parameter;
                        _17098 = max((_4695 - (log(((r_depth_tm1.Load(int3(int2(floor(_17094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7142_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17098 = 0.0f;
                    }
                    bool _7172 = all(bool2(_17095.x > 0.0f.xx.x, _17095.y > 0.0f.xx.y));
                    bool _7178;
                    if (_7172)
                    {
                        _7178 = all(bool2(_17095.x < 1.0f.xx.x, _17095.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7178 = _7172;
                    }
                    float _17099;
                    if (_7178)
                    {
                        uint _7185_dummy_parameter;
                        _17099 = _17098 + max((_4695 - (log(((r_depth_tp1.Load(int3(int2(floor(_17095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7185_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17099 = _17098;
                    }
                    float _17140;
                    int2 _17144;
                    float2 _17155;
                    int2 _17166;
                    float2 _17199;
                    float _17246;
                    if (_17099 == 0.0f)
                    {
                        bool _4737 = _4695 > _14156;
                        bool2 _17254 = _4737.xx;
                        _17246 = _17107;
                        _17199 = float2(_17254.x ? _4690.x : _14166.x, _17254.y ? _4690.y : _14166.y);
                        _17166 = int2(_17254.x ? _4684.x : _14160.x, _17254.y ? _4684.y : _14160.y);
                        _17155 = _14158;
                        _17144 = _14157;
                        _17140 = _4737 ? _4695 : _14156;
                    }
                    else
                    {
                        bool _4746 = _17099 < _17107;
                        bool2 _17250 = _4746.xx;
                        _17246 = _4746 ? _17099 : _17107;
                        _17199 = _14166;
                        _17166 = _14160;
                        _17155 = float2(_17250.x ? _4690.x : _14158.x, _17250.y ? _4690.y : _14158.y);
                        _17144 = int2(_17250.x ? _4684.x : _14157.x, _17250.y ? _4684.y : _14157.y);
                        _17140 = _14156;
                    }
                    _17245 = _17246;
                    _17198 = _17199;
                    _17165 = _17166;
                    _17154 = _17155;
                    _17143 = _17144;
                    _17139 = _17140;
                }
                bool _4758 = _14156 < 0.0f;
                bool2 _17260 = _4758.xx;
                int2 _17263 = int2(_17260.x ? _14157.x : _14160.x, _17260.y ? _14157.y : _14160.y);
                _16559 = float3(1.0f, _4649, float(any(bool2(_17263.x != _4577.x, _17263.y != _4577.y))));
                _14391 = _17263;
                _14310 = _4758 ? false : true;
                _14168 = float2(_17260.x ? _14158.x : _14166.x, _17260.y ? _14158.y : _14166.y);
            }
            else
            {
                _16559 = _13849;
                _14391 = _4577;
                _14310 = false;
                _14168 = _6803;
            }
            _16558 = _16559;
            _14390 = _14391;
            _14309 = _14310;
            _14167 = _14168;
        }
        else
        {
            _16558 = 0.0f.xxx;
            _14390 = _4577;
            _14309 = false;
            _14167 = _6803;
        }
        float2 _14169;
        if (_6825)
        {
            float2 _7250 = clamp((((_14146 + (_14167 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7253 = tan(_7250.x);
            _14169 = (float2(_7253 / cbFI_DeviceToViewDepth.z, (tan(_7250.y) * sqrt(1.0f + (_7253 * _7253))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14169 = _14146 + (_14167 * cbFI_Timestep);
        }
        float _4781 = cbFI_Timestep - 1.0f;
        float2 _14171;
        if (_6825)
        {
            float2 _7321 = clamp((((_14146 + (_14167 * _4781)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7324 = tan(_7321.x);
            _14171 = (float2(_7324 / cbFI_DeviceToViewDepth.z, (tan(_7321.y) * sqrt(1.0f + (_7324 * _7324))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14171 = _14146 + (_14167 * _4781);
        }
        float _4786 = -cbFI_Timestep;
        float2 _14172;
        if (_6825)
        {
            float2 _7392 = clamp((((_14146 + (_6797 * _4786)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7395 = tan(_7392.x);
            _14172 = (float2(_7395 / cbFI_DeviceToViewDepth.z, (tan(_7392.y) * sqrt(1.0f + (_7395 * _7395))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14172 = _14146 + (_6797 * _4786);
        }
        float _4791 = 1.0f - cbFI_Timestep;
        float2 _14173;
        if (_6825)
        {
            float2 _7463 = clamp((((_14146 + (_6797 * _4791)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7466 = tan(_7463.x);
            _14173 = (float2(_7466 / cbFI_DeviceToViewDepth.z, (tan(_7463.y) * sqrt(1.0f + (_7466 * _7466))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14173 = _14146 + (_6797 * _4791);
        }
        float4 _7501 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14169, 0.0f);
        float3 _7502 = _7501.xyz;
        float4 _7509 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14171, 0.0f);
        float3 _7510 = _7509.xyz;
        float4 _7517 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14172, 0.0f);
        float3 _7518 = _7517.xyz;
        float4 _7525 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14173, 0.0f);
        float3 _7526 = _7525.xyz;
        float4 _7540 = exp(_6791 - max(max(max(_6791.x, _6791.y), _6791.z), _6791.w).xxxx);
        float4 _7547 = _7540 / (dot(_7540, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4807 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14380;
        float _15688;
        if (_4807)
        {
            float2 _4813 = 0.5f.xx / _4568;
            float _4816 = _4813.x;
            float _4817 = -_4816;
            float _4819 = _4813.y;
            float _4820 = -_4819;
            float2 _4822 = _4566 + float2(_4817, _4820);
            float2 _4824 = float2(cbFI_DisplaySize);
            bool _14190;
            do
            {
                bool _7627 = all(bool2(_4822.x > 0.0f.xx.x, _4822.y > 0.0f.xx.y));
                bool _7633;
                if (_7627)
                {
                    _7633 = all(bool2(_4822.x < 1.0f.xx.x, _4822.y < 1.0f.xx.y));
                }
                else
                {
                    _7633 = _7627;
                }
                if (!_7633)
                {
                    _14190 = false;
                    break;
                }
                uint _7640_dummy_parameter;
                float4x4 _14188;
                do
                {
                    float4x4 _7654;
                    bool _14187;
                    do
                    {
                        _7654 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14187 = false;
                            break;
                        }
                        uint _7688 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7688 + 32u) * 4 + 0) != 1u)
                        {
                            _14187 = false;
                            break;
                        }
                        uint _14184;
                        _14184 = 0u;
                        for (; _14184 < 4u; _14184++)
                        {
                            for (uint _14185 = 0u; _14185 < 4u; )
                            {
                                _7654[_14184][_14185] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7688 + (_14184 * 4u)) + _14185) * 4 + 0));
                                _14185++;
                                continue;
                            }
                        }
                        _14187 = true;
                        break;
                    } while(false);
                    if (_14187)
                    {
                        _14188 = _7654;
                        break;
                    }
                    _14188 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14189;
                do
                {
                    float _7765 = _4822.x;
                    float _7768 = 1.0f - _4822.y;
                    float4 _7779 = mul(float4((float2(_7765, _7768) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4822 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7640_dummy_parameter))))), 0)).x, 1.0f), _14188);
                    float _7781 = _7779.w;
                    if (!(_7781 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14189 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7794 = ((_7779.xy / _7781.xx) + 1.0f.xx) * 0.5f;
                    _14189 = float2(_7794.x - _7765, _7768 - _7794.y);
                    break;
                } while(false);
                float2 _7591 = abs(_14189);
                if (any(bool2(_7591.x > 100000.0f.xx.x, _7591.y > 100000.0f.xx.y)))
                {
                    _14190 = false;
                    break;
                }
                float _7599 = length(_14189 * _4824);
                uint _7814_dummy_parameter;
                bool _7613 = _7599 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7620;
                if (_7613)
                {
                    _7620 = length((r_motion_tp1.Load(int3(int2(floor(_4822 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7814_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _7599);
                }
                else
                {
                    _7620 = _7613;
                }
                _14190 = _7620;
                break;
            } while(false);
            float2 _4834 = _4566 + float2(_4816, _4820);
            bool _14197;
            do
            {
                bool _7900 = all(bool2(_4834.x > 0.0f.xx.x, _4834.y > 0.0f.xx.y));
                bool _7906;
                if (_7900)
                {
                    _7906 = all(bool2(_4834.x < 1.0f.xx.x, _4834.y < 1.0f.xx.y));
                }
                else
                {
                    _7906 = _7900;
                }
                if (!_7906)
                {
                    _14197 = false;
                    break;
                }
                uint _7913_dummy_parameter;
                float4x4 _14195;
                do
                {
                    float4x4 _7927;
                    bool _14194;
                    do
                    {
                        _7927 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14194 = false;
                            break;
                        }
                        uint _7961 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7961 + 32u) * 4 + 0) != 1u)
                        {
                            _14194 = false;
                            break;
                        }
                        uint _14191;
                        _14191 = 0u;
                        for (; _14191 < 4u; _14191++)
                        {
                            for (uint _14192 = 0u; _14192 < 4u; )
                            {
                                _7927[_14191][_14192] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7961 + (_14191 * 4u)) + _14192) * 4 + 0));
                                _14192++;
                                continue;
                            }
                        }
                        _14194 = true;
                        break;
                    } while(false);
                    if (_14194)
                    {
                        _14195 = _7927;
                        break;
                    }
                    _14195 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14196;
                do
                {
                    float _8038 = _4834.x;
                    float _8041 = 1.0f - _4834.y;
                    float4 _8052 = mul(float4((float2(_8038, _8041) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4834 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7913_dummy_parameter))))), 0)).x, 1.0f), _14195);
                    float _8054 = _8052.w;
                    if (!(_8054 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14196 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8067 = ((_8052.xy / _8054.xx) + 1.0f.xx) * 0.5f;
                    _14196 = float2(_8067.x - _8038, _8041 - _8067.y);
                    break;
                } while(false);
                float2 _7864 = abs(_14196);
                if (any(bool2(_7864.x > 100000.0f.xx.x, _7864.y > 100000.0f.xx.y)))
                {
                    _14197 = false;
                    break;
                }
                float _7872 = length(_14196 * _4824);
                uint _8087_dummy_parameter;
                bool _7886 = _7872 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7893;
                if (_7886)
                {
                    _7893 = length((r_motion_tp1.Load(int3(int2(floor(_4834 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8087_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _7872);
                }
                else
                {
                    _7893 = _7886;
                }
                _14197 = _7893;
                break;
            } while(false);
            float2 _4847 = _4566 + float2(_4817, _4819);
            bool _14204;
            do
            {
                bool _8173 = all(bool2(_4847.x > 0.0f.xx.x, _4847.y > 0.0f.xx.y));
                bool _8179;
                if (_8173)
                {
                    _8179 = all(bool2(_4847.x < 1.0f.xx.x, _4847.y < 1.0f.xx.y));
                }
                else
                {
                    _8179 = _8173;
                }
                if (!_8179)
                {
                    _14204 = false;
                    break;
                }
                uint _8186_dummy_parameter;
                float4x4 _14202;
                do
                {
                    float4x4 _8200;
                    bool _14201;
                    do
                    {
                        _8200 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14201 = false;
                            break;
                        }
                        uint _8234 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8234 + 32u) * 4 + 0) != 1u)
                        {
                            _14201 = false;
                            break;
                        }
                        uint _14198;
                        _14198 = 0u;
                        for (; _14198 < 4u; _14198++)
                        {
                            for (uint _14199 = 0u; _14199 < 4u; )
                            {
                                _8200[_14198][_14199] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8234 + (_14198 * 4u)) + _14199) * 4 + 0));
                                _14199++;
                                continue;
                            }
                        }
                        _14201 = true;
                        break;
                    } while(false);
                    if (_14201)
                    {
                        _14202 = _8200;
                        break;
                    }
                    _14202 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14203;
                do
                {
                    float _8311 = _4847.x;
                    float _8314 = 1.0f - _4847.y;
                    float4 _8325 = mul(float4((float2(_8311, _8314) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4847 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8186_dummy_parameter))))), 0)).x, 1.0f), _14202);
                    float _8327 = _8325.w;
                    if (!(_8327 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14203 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8340 = ((_8325.xy / _8327.xx) + 1.0f.xx) * 0.5f;
                    _14203 = float2(_8340.x - _8311, _8314 - _8340.y);
                    break;
                } while(false);
                float2 _8137 = abs(_14203);
                if (any(bool2(_8137.x > 100000.0f.xx.x, _8137.y > 100000.0f.xx.y)))
                {
                    _14204 = false;
                    break;
                }
                float _8145 = length(_14203 * _4824);
                uint _8360_dummy_parameter;
                bool _8159 = _8145 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8166;
                if (_8159)
                {
                    _8166 = length((r_motion_tp1.Load(int3(int2(floor(_4847 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8360_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _8145);
                }
                else
                {
                    _8166 = _8159;
                }
                _14204 = _8166;
                break;
            } while(false);
            float2 _4859 = _4566 + _4813;
            bool _14211;
            do
            {
                bool _8446 = all(bool2(_4859.x > 0.0f.xx.x, _4859.y > 0.0f.xx.y));
                bool _8452;
                if (_8446)
                {
                    _8452 = all(bool2(_4859.x < 1.0f.xx.x, _4859.y < 1.0f.xx.y));
                }
                else
                {
                    _8452 = _8446;
                }
                if (!_8452)
                {
                    _14211 = false;
                    break;
                }
                uint _8459_dummy_parameter;
                float4x4 _14209;
                do
                {
                    float4x4 _8473;
                    bool _14208;
                    do
                    {
                        _8473 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14208 = false;
                            break;
                        }
                        uint _8507 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8507 + 32u) * 4 + 0) != 1u)
                        {
                            _14208 = false;
                            break;
                        }
                        uint _14205;
                        _14205 = 0u;
                        for (; _14205 < 4u; _14205++)
                        {
                            for (uint _14206 = 0u; _14206 < 4u; )
                            {
                                _8473[_14205][_14206] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8507 + (_14205 * 4u)) + _14206) * 4 + 0));
                                _14206++;
                                continue;
                            }
                        }
                        _14208 = true;
                        break;
                    } while(false);
                    if (_14208)
                    {
                        _14209 = _8473;
                        break;
                    }
                    _14209 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14210;
                do
                {
                    float _8584 = _4859.x;
                    float _8587 = 1.0f - _4859.y;
                    float4 _8598 = mul(float4((float2(_8584, _8587) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4859 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8459_dummy_parameter))))), 0)).x, 1.0f), _14209);
                    float _8600 = _8598.w;
                    if (!(_8600 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14210 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8613 = ((_8598.xy / _8600.xx) + 1.0f.xx) * 0.5f;
                    _14210 = float2(_8613.x - _8584, _8587 - _8613.y);
                    break;
                } while(false);
                float2 _8410 = abs(_14210);
                if (any(bool2(_8410.x > 100000.0f.xx.x, _8410.y > 100000.0f.xx.y)))
                {
                    _14211 = false;
                    break;
                }
                float _8418 = length(_14210 * _4824);
                uint _8633_dummy_parameter;
                bool _8432 = _8418 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8439;
                if (_8432)
                {
                    _8439 = length((r_motion_tp1.Load(int3(int2(floor(_4859 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8633_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _8418);
                }
                else
                {
                    _8439 = _8432;
                }
                _14211 = _8439;
                break;
            } while(false);
            float _4865 = 0.25f * (((float(_14190) + float(_14197)) + float(_14204)) + float(_14211));
            float4 _14381;
            if (_4865 < 1.0f)
            {
                bool _14218;
                do
                {
                    bool _8719 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
                    bool _8725;
                    if (_8719)
                    {
                        _8725 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8725 = _8719;
                    }
                    if (!_8725)
                    {
                        _14218 = false;
                        break;
                    }
                    uint _8732_dummy_parameter;
                    float4x4 _14216;
                    do
                    {
                        float4x4 _8746;
                        bool _14215;
                        do
                        {
                            _8746 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14215 = false;
                                break;
                            }
                            uint _8780 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8780 + 32u) * 4 + 0) != 1u)
                            {
                                _14215 = false;
                                break;
                            }
                            uint _14212;
                            _14212 = 0u;
                            for (; _14212 < 4u; _14212++)
                            {
                                for (uint _14213 = 0u; _14213 < 4u; )
                                {
                                    _8746[_14212][_14213] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8780 + (_14212 * 4u)) + _14213) * 4 + 0));
                                    _14213++;
                                    continue;
                                }
                            }
                            _14215 = true;
                            break;
                        } while(false);
                        if (_14215)
                        {
                            _14216 = _8746;
                            break;
                        }
                        _14216 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14217;
                    do
                    {
                        float _8860 = 1.0f - _14169.y;
                        float4 _8871 = mul(float4((float2(_14169.x, _8860) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8732_dummy_parameter))))), 0)).x, 1.0f), _14216);
                        float _8873 = _8871.w;
                        if (!(_8873 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14217 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8886 = ((_8871.xy / _8873.xx) + 1.0f.xx) * 0.5f;
                        _14217 = float2(_8886.x - _14169.x, _8860 - _8886.y);
                        break;
                    } while(false);
                    float2 _8683 = abs(_14217);
                    if (any(bool2(_8683.x > 100000.0f.xx.x, _8683.y > 100000.0f.xx.y)))
                    {
                        _14218 = false;
                        break;
                    }
                    float _8691 = length(_14217 * _4824);
                    uint _8906_dummy_parameter;
                    bool _8705 = _8691 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8712;
                    if (_8705)
                    {
                        _8712 = length((r_motion_tp1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8906_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _8691);
                    }
                    else
                    {
                        _8712 = _8705;
                    }
                    _14218 = _8712;
                    break;
                } while(false);
                bool _14225;
                do
                {
                    bool _8992 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
                    bool _8998;
                    if (_8992)
                    {
                        _8998 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8998 = _8992;
                    }
                    if (!_8998)
                    {
                        _14225 = false;
                        break;
                    }
                    uint _9005_dummy_parameter;
                    float4x4 _14223;
                    do
                    {
                        float4x4 _9019;
                        bool _14222;
                        do
                        {
                            _9019 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14222 = false;
                                break;
                            }
                            uint _9053 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9053 + 32u) * 4 + 0) != 1u)
                            {
                                _14222 = false;
                                break;
                            }
                            uint _14219;
                            _14219 = 0u;
                            for (; _14219 < 4u; _14219++)
                            {
                                for (uint _14220 = 0u; _14220 < 4u; )
                                {
                                    _9019[_14219][_14220] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9053 + (_14219 * 4u)) + _14220) * 4 + 0));
                                    _14220++;
                                    continue;
                                }
                            }
                            _14222 = true;
                            break;
                        } while(false);
                        if (_14222)
                        {
                            _14223 = _9019;
                            break;
                        }
                        _14223 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14224;
                    do
                    {
                        float _9133 = 1.0f - _14171.y;
                        float4 _9144 = mul(float4((float2(_14171.x, _9133) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9005_dummy_parameter))))), 0)).x, 1.0f), _14223);
                        float _9146 = _9144.w;
                        if (!(_9146 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14224 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9159 = ((_9144.xy / _9146.xx) + 1.0f.xx) * 0.5f;
                        _14224 = float2(_9159.x - _14171.x, _9133 - _9159.y);
                        break;
                    } while(false);
                    float2 _8956 = abs(_14224);
                    if (any(bool2(_8956.x > 100000.0f.xx.x, _8956.y > 100000.0f.xx.y)))
                    {
                        _14225 = false;
                        break;
                    }
                    float _8964 = length(_14224 * _4824);
                    uint _9179_dummy_parameter;
                    bool _8978 = _8964 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8985;
                    if (_8978)
                    {
                        _8985 = length((r_motion_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9179_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _8964);
                    }
                    else
                    {
                        _8985 = _8978;
                    }
                    _14225 = _8985;
                    break;
                } while(false);
                bool _14232;
                do
                {
                    bool _9265 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                    bool _9271;
                    if (_9265)
                    {
                        _9271 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9271 = _9265;
                    }
                    if (!_9271)
                    {
                        _14232 = false;
                        break;
                    }
                    uint _9278_dummy_parameter;
                    float4x4 _14230;
                    do
                    {
                        float4x4 _9292;
                        bool _14229;
                        do
                        {
                            _9292 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14229 = false;
                                break;
                            }
                            uint _9326 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9326 + 32u) * 4 + 0) != 1u)
                            {
                                _14229 = false;
                                break;
                            }
                            uint _14226;
                            _14226 = 0u;
                            for (; _14226 < 4u; _14226++)
                            {
                                for (uint _14227 = 0u; _14227 < 4u; )
                                {
                                    _9292[_14226][_14227] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9326 + (_14226 * 4u)) + _14227) * 4 + 0));
                                    _14227++;
                                    continue;
                                }
                            }
                            _14229 = true;
                            break;
                        } while(false);
                        if (_14229)
                        {
                            _14230 = _9292;
                            break;
                        }
                        _14230 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14231;
                    do
                    {
                        float _9406 = 1.0f - _14172.y;
                        float4 _9417 = mul(float4((float2(_14172.x, _9406) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9278_dummy_parameter))))), 0)).x, 1.0f), _14230);
                        float _9419 = _9417.w;
                        if (!(_9419 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14231 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9432 = ((_9417.xy / _9419.xx) + 1.0f.xx) * 0.5f;
                        _14231 = float2(_9432.x - _14172.x, _9406 - _9432.y);
                        break;
                    } while(false);
                    float2 _9229 = abs(_14231);
                    if (any(bool2(_9229.x > 100000.0f.xx.x, _9229.y > 100000.0f.xx.y)))
                    {
                        _14232 = false;
                        break;
                    }
                    float _9237 = length(_14231 * _4824);
                    uint _9452_dummy_parameter;
                    bool _9251 = _9237 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9258;
                    if (_9251)
                    {
                        _9258 = length((r_motion_tp1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9452_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _9237);
                    }
                    else
                    {
                        _9258 = _9251;
                    }
                    _14232 = _9258;
                    break;
                } while(false);
                bool _14239;
                do
                {
                    bool _9538 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                    bool _9544;
                    if (_9538)
                    {
                        _9544 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9544 = _9538;
                    }
                    if (!_9544)
                    {
                        _14239 = false;
                        break;
                    }
                    uint _9551_dummy_parameter;
                    float4x4 _14237;
                    do
                    {
                        float4x4 _9565;
                        bool _14236;
                        do
                        {
                            _9565 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14236 = false;
                                break;
                            }
                            uint _9599 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9599 + 32u) * 4 + 0) != 1u)
                            {
                                _14236 = false;
                                break;
                            }
                            uint _14233;
                            _14233 = 0u;
                            for (; _14233 < 4u; _14233++)
                            {
                                for (uint _14234 = 0u; _14234 < 4u; )
                                {
                                    _9565[_14233][_14234] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9599 + (_14233 * 4u)) + _14234) * 4 + 0));
                                    _14234++;
                                    continue;
                                }
                            }
                            _14236 = true;
                            break;
                        } while(false);
                        if (_14236)
                        {
                            _14237 = _9565;
                            break;
                        }
                        _14237 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14238;
                    do
                    {
                        float _9679 = 1.0f - _14173.y;
                        float4 _9690 = mul(float4((float2(_14173.x, _9679) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9551_dummy_parameter))))), 0)).x, 1.0f), _14237);
                        float _9692 = _9690.w;
                        if (!(_9692 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14238 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9705 = ((_9690.xy / _9692.xx) + 1.0f.xx) * 0.5f;
                        _14238 = float2(_9705.x - _14173.x, _9679 - _9705.y);
                        break;
                    } while(false);
                    float2 _9502 = abs(_14238);
                    if (any(bool2(_9502.x > 100000.0f.xx.x, _9502.y > 100000.0f.xx.y)))
                    {
                        _14239 = false;
                        break;
                    }
                    float _9510 = length(_14238 * _4824);
                    uint _9725_dummy_parameter;
                    bool _9524 = _9510 > ((8.0f * _4824.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9531;
                    if (_9524)
                    {
                        _9531 = length((r_motion_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9725_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4824) < (0.20000000298023223876953125f * _9510);
                    }
                    else
                    {
                        _9531 = _9524;
                    }
                    _14239 = _9531;
                    break;
                } while(false);
                float4 _4892 = _7547 * float4(_14218 ? 0.0f : 1.0f, _14225 ? 0.0f : 1.0f, _14232 ? 0.0f : 1.0f, _14239 ? 0.0f : 1.0f);
                float _4894 = dot(_4892, 1.0f.xxxx);
                float4 _14382;
                if (_4894 > 0.001000000047497451305389404296875f)
                {
                    _14382 = _4892 / _4894.xxxx;
                }
                else
                {
                    _14382 = _7547;
                }
                _14381 = _14382;
            }
            else
            {
                _14381 = _7547;
            }
            _15688 = _4865;
            _14380 = _14381;
        }
        else
        {
            _15688 = 0.0f;
            _14380 = _7547;
        }
        bool _4911 = _4603 && (!_14309);
        bool _4920;
        if (_4911)
        {
            _4920 = (_14380.z + _14380.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4920 = _4911;
        }
        bool _4931;
        if (_4920)
        {
            _4931 = length((_14172 - _14169) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4931 = _4920;
        }
        bool _14469;
        if (_4931)
        {
            uint4 _9754 = r_warped_motion_qdata_tp1.Load(int3(_14390, 0));
            uint _9755 = _9754.x;
            bool _14472;
            if (_9755 != 0u)
            {
                float _14458;
                if (_9755 == 0u)
                {
                    _14458 = -1.0f;
                }
                else
                {
                    _14458 = float((_9755 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4941 = _14458 - 0.12000000476837158203125f;
                bool _9774 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                bool _9780;
                if (_9774)
                {
                    _9780 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                }
                else
                {
                    _9780 = _9774;
                }
                bool _4951;
                if (_9780)
                {
                    uint _9787_dummy_parameter;
                    _4951 = (log(((r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9787_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4941;
                }
                else
                {
                    _4951 = _9780;
                }
                bool _4965;
                if (!_4951)
                {
                    bool _9817 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                    bool _9823;
                    if (_9817)
                    {
                        _9823 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9823 = _9817;
                    }
                    bool _4963;
                    if (_9823)
                    {
                        uint _9830_dummy_parameter;
                        _4963 = (log(((r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9830_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4941;
                    }
                    else
                    {
                        _4963 = _9823;
                    }
                    _4965 = _4963;
                }
                else
                {
                    _4965 = _4951;
                }
                _14472 = _4965;
            }
            else
            {
                _14472 = false;
            }
            _14469 = _14472;
        }
        else
        {
            _14469 = false;
        }
        bool _4970 = _14309 || _14469;
        bool _4975;
        if (_4970)
        {
            bool _9860 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
            bool _9866;
            if (_9860)
            {
                _9866 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
            }
            else
            {
                _9866 = _9860;
            }
            _4975 = _9866;
        }
        else
        {
            _4975 = _4970;
        }
        bool _4980;
        if (_4975)
        {
            bool _9871 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
            bool _9877;
            if (_9871)
            {
                _9877 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
            }
            else
            {
                _9877 = _9871;
            }
            _4980 = _9877;
        }
        else
        {
            _4980 = _4975;
        }
        float4 _14592;
        if (_4980)
        {
            float _4986 = _14380.x + _14380.y;
            float _4991 = _14380.z + _14380.w;
            float _14487;
            if (_4986 > 0.001000000047497451305389404296875f)
            {
                _14487 = _14380.x / _4986;
            }
            else
            {
                _14487 = _4791;
            }
            _14592 = float4(_14380.x + (_4991 * _14487), _14380.y + (_4991 * (1.0f - _14487)), 0.0f, 0.0f);
        }
        else
        {
            _14592 = _14380;
        }
        bool _9905 = (cbFI_pad0 & 1024u) != 0u;
        bool _9881 = !_9905;
        bool _9882 = !_9881;
        bool _9899;
        if (_9882)
        {
            _9899 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14390.y * cbFI_MvDepthLaneSize.x) + _14390.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9899 = _9881;
        }
        bool _9931;
        if (_9882)
        {
            _9931 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4582.y * cbFI_FlowLaneSize.x) + _4582.x)) * 4 + 0) != 0u;
        }
        else
        {
            _9931 = _9881;
        }
        float _5026 = float(_9931);
        bool _14613;
        float4 _14652;
        float3 _16322;
        if (_9905)
        {
            bool _5036;
            if (_9899)
            {
                _5036 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
            }
            else
            {
                _5036 = _9899;
            }
            bool _5042;
            if (_5036)
            {
                _5042 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
            }
            else
            {
                _5042 = _5036;
            }
            bool _5049;
            if (_9899)
            {
                _5049 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
            }
            else
            {
                _5049 = _9899;
            }
            bool _5055;
            if (_5049)
            {
                _5055 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
            }
            else
            {
                _5055 = _5049;
            }
            bool _5062;
            if (_9931)
            {
                _5062 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
            }
            else
            {
                _5062 = _9931;
            }
            bool _5068;
            if (_5062)
            {
                _5068 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
            }
            else
            {
                _5068 = _5062;
            }
            bool _5075;
            if (_9931)
            {
                _5075 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
            }
            else
            {
                _5075 = _9931;
            }
            bool _5081;
            if (_5075)
            {
                _5081 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
            }
            else
            {
                _5081 = _5075;
            }
            bool _5083 = !_9899;
            if (_5083)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9973;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9973);
                }
            }
            bool _5088 = !_9931;
            if (_5088)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9983;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9983);
                }
            }
            if (_9899 && _5088)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9993;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9993);
                }
            }
            if (_5083 && _9931)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10003;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _10003);
                }
            }
            float _5107 = float(_5042);
            float _5109 = float(_5055);
            bool _5112 = _5068 && _5081;
            float _14521;
            if (_5112)
            {
                _14521 = 1.0f;
            }
            else
            {
                _14521 = (_5068 || _5081) ? 0.5f : 0.0f;
            }
            bool _14536;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5042)) && (!_5055))
            {
                bool _5142;
                if (_5112)
                {
                    float _14529;
                    do
                    {
                        bool _10087 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                        bool _10093;
                        if (_10087)
                        {
                            _10093 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10093 = _10087;
                        }
                        bool _10024 = !_10093;
                        bool _10031;
                        if (!_10024)
                        {
                            bool _10098 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                            bool _10104;
                            if (_10098)
                            {
                                _10104 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10104 = _10098;
                            }
                            _10031 = !_10104;
                        }
                        else
                        {
                            _10031 = _10024;
                        }
                        if (_10031)
                        {
                            _14529 = 0.0f;
                            break;
                        }
                        uint _10111_dummy_parameter;
                        uint _10127_dummy_parameter;
                        float4x4 _14528;
                        do
                        {
                            float4x4 _10141;
                            bool _14527;
                            do
                            {
                                _10141 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14527 = false;
                                    break;
                                }
                                uint _10175 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10175 + 32u) * 4 + 0) != 1u)
                                {
                                    _14527 = false;
                                    break;
                                }
                                uint _14524;
                                _14524 = 0u;
                                for (; _14524 < 4u; _14524++)
                                {
                                    for (uint _14525 = 0u; _14525 < 4u; )
                                    {
                                        _10141[_14524][_14525] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10175 + 16u) + (_14524 * 4u)) + _14525) * 4 + 0));
                                        _14525++;
                                        continue;
                                    }
                                }
                                _14527 = true;
                                break;
                            } while(false);
                            if (_14527)
                            {
                                _14528 = _10141;
                                break;
                            }
                            _14528 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _10052 = mul(float4((float2(_14172.x, 1.0f - _14172.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10111_dummy_parameter))))), 0)).x, 1.0f), _14528);
                        float _10054 = _10052.w;
                        if (abs(_10054) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14529 = 0.0f;
                            break;
                        }
                        float _10065 = abs(cbFI_DeviceToViewDepth.y / ((_10052.z / _10054) - cbFI_DeviceToViewDepth.x));
                        float _10068 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10127_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14529 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10065 - _10068) / max(max(_10065, _10068), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5142 = _14529 >= 0.5f;
                }
                else
                {
                    _5142 = _5112;
                }
                bool _5150;
                if (_5142)
                {
                    _5150 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5150 = _5142;
                }
                bool _14537;
                if (_5150)
                {
                    uint _10279_dummy_parameter;
                    float4x4 _14534;
                    do
                    {
                        float4x4 _10293;
                        bool _14533;
                        do
                        {
                            _10293 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14533 = false;
                                break;
                            }
                            uint _10327 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10327 + 32u) * 4 + 0) != 1u)
                            {
                                _14533 = false;
                                break;
                            }
                            uint _14530;
                            _14530 = 0u;
                            for (; _14530 < 4u; _14530++)
                            {
                                for (uint _14531 = 0u; _14531 < 4u; )
                                {
                                    _10293[_14530][_14531] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10327 + 16u) + (_14530 * 4u)) + _14531) * 4 + 0));
                                    _14531++;
                                    continue;
                                }
                            }
                            _14533 = true;
                            break;
                        } while(false);
                        if (_14533)
                        {
                            _14534 = _10293;
                            break;
                        }
                        _14534 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14535;
                    do
                    {
                        float _10407 = 1.0f - _14172.y;
                        float4 _10418 = mul(float4((float2(_14172.x, _10407) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10279_dummy_parameter))))), 0)).x, 1.0f), _14534);
                        float _10420 = _10418.w;
                        if (!(_10420 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14535 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10433 = ((_10418.xy / _10420.xx) + 1.0f.xx) * 0.5f;
                        _14535 = float2(_10433.x - _14172.x, _10407 - _10433.y);
                        break;
                    } while(false);
                    float2 _5163 = float2(cbFI_DisplaySize);
                    _14537 = length(((_14172 + _14535) - _14173) * _5163) <= ((0.100000001490116119384765625f * length(_14535 * _5163)) + 8.0f);
                }
                else
                {
                    _14537 = _5142;
                }
                _14536 = _14537;
            }
            else
            {
                _14536 = true;
            }
            bool _5177 = !_14536;
            bool _17264 = _5177 ? false : _5081;
            bool _17265 = _5177 ? false : _5068;
            bool _14614;
            float4 _14653;
            if (!(((_5042 && _5055) && _17265) && _17264))
            {
                float4 _5199 = _14592 * float4(_5107, _5109, float(_17265), float(_17264));
                float _5201 = dot(_5199, 1.0f.xxxx);
                bool _5204 = !(_5201 > 0.0f);
                float4 _14654;
                if (!_5204)
                {
                    _14654 = _5199 / _5201.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10455;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10455);
                    }
                    _14654 = 0.0f.xxxx;
                }
                _14653 = _14654;
                _14614 = _5204;
            }
            else
            {
                _14653 = _14592;
                _14614 = false;
            }
            _16322 = float3(_5107, _5109, _14521);
            _14652 = _14653;
            _14613 = _14614;
        }
        else
        {
            _16322 = float3(float(_9899), _5026, 0.0f);
            _14652 = _14592;
            _14613 = false;
        }
        bool _5222 = !_14613;
        float4 _14745;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5222)
        {
            float _5229 = _14652.x + _14652.y;
            float4 _14746;
            if (_5229 > 0.001000000047497451305389404296875f)
            {
                _14746 = float4(_14652.x / _5229, _14652.y / _5229, 0.0f, 0.0f);
            }
            else
            {
                _14746 = float4(_4791, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14745 = _14746;
        }
        else
        {
            _14745 = _14652;
        }
        float4 _14922;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5222) && _9899)
        {
            float _14719;
            do
            {
                uint4 _10595 = r_warped_motion_qdata_tp1.Load(int3(_14390, 0));
                uint _10596 = _10595.x;
                if (_10596 != 0u)
                {
                    float _14718;
                    if (_10596 == 0u)
                    {
                        _14718 = -1.0f;
                    }
                    else
                    {
                        _14718 = float((_10596 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14719 = _14718;
                    break;
                }
                int _14701;
                uint _14702;
                _14702 = _10596;
                _14701 = -1;
                uint _14717;
                for (; _14701 <= 1; _14702 = _14717, _14701++)
                {
                    _14717 = _14702;
                    for (int _14715 = -1; _14715 <= 1; )
                    {
                        _14717 = max(_14717, r_warped_motion_qdata_tp1.Load(int3(clamp(_14390 + int2(_14715, _14701), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14715++;
                        continue;
                    }
                }
                if (_14702 != 0u)
                {
                    float _14714;
                    if (_14702 == 0u)
                    {
                        _14714 = -1.0f;
                    }
                    else
                    {
                        _14714 = float((_14702 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14719 = _14714;
                    break;
                }
                uint _14704;
                _14704 = 4294967295u;
                uint _17235;
                for (int _14703 = 0; _14703 < 8; _14704 = _17235, _14703++)
                {
                    int _14707 = 0;
                    for (;;)
                    {
                        if (_14707 < 5)
                        {
                            int2 _10546 = _14390 + (_1184[_14703] * _1193[_14707].xx);
                            bool _10549 = any(bool2(_10546.x < int2(0, 0).x, _10546.y < int2(0, 0).y));
                            bool _10557;
                            if (!_10549)
                            {
                                _10557 = any(bool2(_10546.x >= cbFI_MvDepthLaneSize.x, _10546.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10557 = _10549;
                            }
                            if (_10557)
                            {
                                _17235 = _14704;
                                break;
                            }
                            uint4 _10635 = r_warped_motion_qdata_tp1.Load(int3(_10546, 0));
                            uint _10636 = _10635.x;
                            if (_10636 != 0u)
                            {
                                _17235 = min(_14704, _10636);
                                break;
                            }
                            _14707++;
                            continue;
                        }
                        else
                        {
                            _17235 = _14704;
                            break;
                        }
                    }
                }
                float _14706;
                if (_14704 == 4294967295u)
                {
                    _14706 = -1.0f;
                }
                else
                {
                    float _14705;
                    if (_14704 == 0u)
                    {
                        _14705 = -1.0f;
                    }
                    else
                    {
                        _14705 = float((_14704 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14706 = _14705;
                }
                _14719 = _14706;
                break;
            } while(false);
            float _5265 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5268 = r_warped_motion_qdata_tp1.Load(int3(_14390, 0)).x == 0u;
            bool _5274;
            if (_5268)
            {
                bool _10661 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
                bool _10667;
                if (_10661)
                {
                    _10667 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
                }
                else
                {
                    _10667 = _10661;
                }
                _5274 = _10667;
            }
            else
            {
                _5274 = _5268;
            }
            bool _5279;
            if (_5274)
            {
                bool _10672 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
                bool _10678;
                if (_10672)
                {
                    _10678 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
                }
                else
                {
                    _10678 = _10672;
                }
                _5279 = _10678;
            }
            else
            {
                _5279 = _5274;
            }
            bool _14731;
            float4 _14740;
            if (_5279)
            {
                uint _10685_dummy_parameter;
                float _10709 = log(((r_depth_tm1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10685_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _10717_dummy_parameter;
                float _10741 = log(((r_depth_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10717_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _5290 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5297;
                if (_5290)
                {
                    _5297 = _10741 > (_10709 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5297 = _5290;
                }
                bool _14736;
                float4 _14758;
                if (_5297)
                {
                    _14758 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14736 = true;
                }
                else
                {
                    bool _5303 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5310;
                    if (_5303)
                    {
                        _5310 = _10709 > (_10741 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5310 = _5303;
                    }
                    bool4 _17266 = _5310.xxxx;
                    _14758 = float4(_17266.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14745.x, _17266.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14745.y, _17266.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14745.z, _17266.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14745.w);
                    _14736 = _5310 ? true : false;
                }
                _14740 = _14758;
                _14731 = _14736;
            }
            else
            {
                _14740 = _14745;
                _14731 = false;
            }
            float4 _14813;
            if (_14731)
            {
                _14813 = 1.0f.xxxx;
            }
            else
            {
                bool _5321 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5327;
                if (_5321)
                {
                    _5327 = _14740.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5327 = _5321;
                }
                bool _5332;
                if (_5327)
                {
                    bool _10747 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
                    bool _10753;
                    if (_10747)
                    {
                        _10753 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10753 = _10747;
                    }
                    _5332 = _10753;
                }
                else
                {
                    _5332 = _5327;
                }
                float4 _14814;
                if (_5332)
                {
                    float _14767;
                    if (_14719 >= 0.0f)
                    {
                        _14767 = _14719 - _5265;
                    }
                    else
                    {
                        float _14763;
                        _14763 = 2.0f;
                        float _10810;
                        for (int _14762 = 0; _14762 < 24; _14763 = _10810, _14762++)
                        {
                            float _10774 = float(_14762 & 7) * 0.785398185253143310546875f;
                            int _10776 = _14762 >> 3;
                            int _14764;
                            if (_10776 == 0)
                            {
                                _14764 = 16;
                            }
                            else
                            {
                                _14764 = (_10776 == 1) ? 48 : 96;
                            }
                            uint _10842_dummy_parameter;
                            _10810 = min(_14763, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14171 + ((cbFI_MvDepthLaneSizeRcp * float(_14764)) * float2(cos(_10774), sin(_10774))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10842_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14767 = _14763;
                    }
                    uint _10874_dummy_parameter;
                    float4 _14815;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10874_dummy_parameter))))), 0)).x) > ((exp((_14767 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14815 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14815 = 1.0f.xxxx;
                    }
                    _14814 = _14815;
                }
                else
                {
                    _14814 = 1.0f.xxxx;
                }
                _14813 = _14814;
            }
            bool _5360 = _14719 >= 0.0f;
            bool _5361 = (!_14731) && _5360;
            bool _5368;
            if (_5361)
            {
                _5368 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5368 = _5361;
            }
            bool _5374;
            if (_5368)
            {
                _5374 = _14740.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5374 = _5368;
            }
            bool _5379;
            if (_5374)
            {
                bool _10899 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
                bool _10905;
                if (_10899)
                {
                    _10905 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
                }
                else
                {
                    _10905 = _10899;
                }
                _5379 = _10905;
            }
            else
            {
                _5379 = _5374;
            }
            float4 _14838;
            if (_5379)
            {
                float _14807;
                if (_5360)
                {
                    _14807 = _14719 - _5265;
                }
                else
                {
                    float _14803;
                    _14803 = 2.0f;
                    float _10962;
                    for (int _14802 = 0; _14802 < 24; _14803 = _10962, _14802++)
                    {
                        float _10926 = float(_14802 & 7) * 0.785398185253143310546875f;
                        int _10928 = _14802 >> 3;
                        int _14804;
                        if (_10928 == 0)
                        {
                            _14804 = 16;
                        }
                        else
                        {
                            _14804 = (_10928 == 1) ? 48 : 96;
                        }
                        uint _10978_dummy_parameter;
                        _10962 = min(_14803, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14169 + ((cbFI_MvDepthLaneSizeRcp * float(_14804)) * float2(cos(_10926), sin(_10926))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10978_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14807 = _14803;
                }
                uint _11026_dummy_parameter;
                float4 _14839;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11026_dummy_parameter))))), 0)).x) > ((exp((_14807 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _14001 = _14813;
                    _14001.x = 0.0f;
                    _14839 = _14001;
                }
                else
                {
                    _14839 = _14813;
                }
                _14838 = _14839;
            }
            else
            {
                _14838 = _14813;
            }
            float4 _14851;
            if (_5361)
            {
                float _11053 = (exp(((_14719 - _5265) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5417 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5423;
                if (_5417)
                {
                    _5423 = _14740.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5423 = _5417;
                }
                bool _5428;
                if (_5423)
                {
                    bool _11058 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                    bool _11064;
                    if (_11058)
                    {
                        _11064 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11064 = _11058;
                    }
                    _5428 = _11064;
                }
                else
                {
                    _5428 = _5423;
                }
                bool _5436;
                if (_5428)
                {
                    uint _11071_dummy_parameter;
                    _5436 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11071_dummy_parameter))))), 0)).x) > _11053;
                }
                else
                {
                    _5436 = _5428;
                }
                float4 _14849;
                if (_5436)
                {
                    float4 _14004 = _14838;
                    _14004.w = 0.0f;
                    _14849 = _14004;
                }
                else
                {
                    _14849 = _14838;
                }
                bool _5443 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5449;
                if (_5443)
                {
                    _5449 = _14740.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5449 = _5443;
                }
                bool _5454;
                if (_5449)
                {
                    bool _11089 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                    bool _11095;
                    if (_11089)
                    {
                        _11095 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11095 = _11089;
                    }
                    _5454 = _11095;
                }
                else
                {
                    _5454 = _5449;
                }
                bool _5462;
                if (_5454)
                {
                    uint _11102_dummy_parameter;
                    _5462 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11102_dummy_parameter))))), 0)).x) > _11053;
                }
                else
                {
                    _5462 = _5454;
                }
                float4 _14852;
                if (_5462)
                {
                    float4 _14007 = _14849;
                    _14007.z = 0.0f;
                    _14852 = _14007;
                }
                else
                {
                    _14852 = _14849;
                }
                _14851 = _14852;
            }
            else
            {
                _14851 = _14838;
            }
            float4 _14923;
            if (any(bool4(_14851.x < 1.0f.xxxx.x, _14851.y < 1.0f.xxxx.y, _14851.z < 1.0f.xxxx.z, _14851.w < 1.0f.xxxx.w)))
            {
                float4 _5473 = _14740 * _14851;
                float _5475 = dot(_5473, 1.0f.xxxx);
                float4 _14924;
                if (_5475 > 0.0f)
                {
                    _14924 = _5473 / _5475.xxxx;
                }
                else
                {
                    bool _5486 = _14851.y == 0.0f;
                    bool _5492;
                    if (_5486)
                    {
                        _5492 = _14851.x > 0.0f;
                    }
                    else
                    {
                        _5492 = _5486;
                    }
                    bool _5497;
                    if (_5492)
                    {
                        bool _11120 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
                        bool _11126;
                        if (_11120)
                        {
                            _11126 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11126 = _11120;
                        }
                        _5497 = _11126;
                    }
                    else
                    {
                        _5497 = _5492;
                    }
                    float4 _14925;
                    if (_5497)
                    {
                        _14925 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5502 = _14851.x == 0.0f;
                        bool _5508;
                        if (_5502)
                        {
                            _5508 = _14851.y > 0.0f;
                        }
                        else
                        {
                            _5508 = _5502;
                        }
                        bool _5513;
                        if (_5508)
                        {
                            bool _11131 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
                            bool _11137;
                            if (_11131)
                            {
                                _11137 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11137 = _11131;
                            }
                            _5513 = _11137;
                        }
                        else
                        {
                            _5513 = _5508;
                        }
                        bool4 _17269 = _5513.xxxx;
                        _14925 = float4(_17269.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14740.x, _17269.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14740.y, _17269.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14740.z, _17269.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14740.w);
                    }
                    _14924 = _14925;
                }
                _14923 = _14924;
            }
            else
            {
                _14923 = _14740;
            }
            _14922 = _14923;
        }
        else
        {
            _14922 = _14745;
        }
        float4 _15652;
        bool _15958;
        float3 _16092;
        if (((cbFI_pad0 & 32768u) != 0u) && _5222)
        {
            bool _5530 = _14922.x > 0.00999999977648258209228515625f;
            bool _5533 = _14922.y > 0.00999999977648258209228515625f;
            bool _5542 = (_14922.z + _14922.w) > 0.0199999995529651641845703125f;
            bool _5548;
            if (_5542)
            {
                bool _11142 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                bool _11148;
                if (_11142)
                {
                    _11148 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                }
                else
                {
                    _11148 = _11142;
                }
                _5548 = _11148;
            }
            else
            {
                _5548 = _5542;
            }
            bool _5553;
            if (_5548)
            {
                bool _11153 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                bool _11159;
                if (_11153)
                {
                    _11159 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                }
                else
                {
                    _11159 = _11153;
                }
                _5553 = _11159;
            }
            else
            {
                _5553 = _5548;
            }
            bool _5560;
            if (_5553)
            {
                float _14938;
                do
                {
                    bool _11242 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                    bool _11248;
                    if (_11242)
                    {
                        _11248 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11248 = _11242;
                    }
                    bool _11179 = !_11248;
                    bool _11186;
                    if (!_11179)
                    {
                        bool _11253 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                        bool _11259;
                        if (_11253)
                        {
                            _11259 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11259 = _11253;
                        }
                        _11186 = !_11259;
                    }
                    else
                    {
                        _11186 = _11179;
                    }
                    if (_11186)
                    {
                        _14938 = 0.0f;
                        break;
                    }
                    uint _11266_dummy_parameter;
                    uint _11282_dummy_parameter;
                    float4x4 _14937;
                    do
                    {
                        float4x4 _11296;
                        bool _14936;
                        do
                        {
                            _11296 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14936 = false;
                                break;
                            }
                            uint _11330 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11330 + 32u) * 4 + 0) != 1u)
                            {
                                _14936 = false;
                                break;
                            }
                            uint _14933;
                            _14933 = 0u;
                            for (; _14933 < 4u; _14933++)
                            {
                                for (uint _14934 = 0u; _14934 < 4u; )
                                {
                                    _11296[_14933][_14934] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11330 + 16u) + (_14933 * 4u)) + _14934) * 4 + 0));
                                    _14934++;
                                    continue;
                                }
                            }
                            _14936 = true;
                            break;
                        } while(false);
                        if (_14936)
                        {
                            _14937 = _11296;
                            break;
                        }
                        _14937 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11207 = mul(float4((float2(_14172.x, 1.0f - _14172.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11266_dummy_parameter))))), 0)).x, 1.0f), _14937);
                    float _11209 = _11207.w;
                    if (abs(_11209) < 9.9999999747524270787835121154785e-07f)
                    {
                        _14938 = 0.0f;
                        break;
                    }
                    float _11220 = abs(cbFI_DeviceToViewDepth.y / ((_11207.z / _11209) - cbFI_DeviceToViewDepth.x));
                    float _11223 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11282_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _14938 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11220 - _11223) / max(max(_11220, _11223), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5560 = _14938 < 0.5f;
            }
            else
            {
                _5560 = _5553;
            }
            float4 _14957;
            if (_5560)
            {
                uint _11434_dummy_parameter;
                uint _11465_dummy_parameter;
                float4 _14958;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11434_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11465_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _14958 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _14958 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _14957 = _14958;
            }
            else
            {
                _14957 = 1.0f.xxxx;
            }
            bool _5584;
            if (_9899)
            {
                bool _11494 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
                bool _11500;
                if (_11494)
                {
                    _11500 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
                }
                else
                {
                    _11500 = _11494;
                }
                _5584 = _11500;
            }
            else
            {
                _5584 = _9899;
            }
            bool _5590;
            if (_9899)
            {
                bool _11505 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
                bool _11511;
                if (_11505)
                {
                    _11511 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
                }
                else
                {
                    _11511 = _11505;
                }
                _5590 = _11511;
            }
            else
            {
                _5590 = _9899;
            }
            bool _5596;
            if (_9931)
            {
                bool _11516 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                bool _11522;
                if (_11516)
                {
                    _11522 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                }
                else
                {
                    _11522 = _11516;
                }
                _5596 = _11522;
            }
            else
            {
                _5596 = _9931;
            }
            bool _5602;
            if (_9931)
            {
                bool _11527 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                bool _11533;
                if (_11527)
                {
                    _11533 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                }
                else
                {
                    _11533 = _11527;
                }
                _5602 = _11533;
            }
            else
            {
                _5602 = _9931;
            }
            bool _5605 = _5596 != _5602;
            bool _5611;
            if (_5605)
            {
                _5611 = _5584 || _5590;
            }
            else
            {
                _5611 = _5605;
            }
            float4 _15060;
            if (_5611)
            {
                float4 _14034 = _14957;
                _14034.z = 0.0f;
                _14034.w = 0.0f;
                _15060 = _14034;
            }
            else
            {
                _15060 = _14957;
            }
            bool _5618 = _5584 && _5530;
            bool _5621 = _5590 && _5533;
            float4 _15165;
            float3 _16201;
            if (_5618 || _5621)
            {
                float _15055;
                do
                {
                    uint4 _11672 = r_warped_motion_qdata_tp1.Load(int3(_14390, 0));
                    uint _11673 = _11672.x;
                    if (_11673 != 0u)
                    {
                        float _15054;
                        if (_11673 == 0u)
                        {
                            _15054 = -1.0f;
                        }
                        else
                        {
                            _15054 = float((_11673 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15055 = _15054;
                        break;
                    }
                    int _15037;
                    uint _15038;
                    _15038 = _11673;
                    _15037 = -1;
                    uint _15053;
                    for (; _15037 <= 1; _15038 = _15053, _15037++)
                    {
                        _15053 = _15038;
                        for (int _15051 = -1; _15051 <= 1; )
                        {
                            _15053 = max(_15053, r_warped_motion_qdata_tp1.Load(int3(clamp(_14390 + int2(_15051, _15037), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15051++;
                            continue;
                        }
                    }
                    if (_15038 != 0u)
                    {
                        float _15050;
                        if (_15038 == 0u)
                        {
                            _15050 = -1.0f;
                        }
                        else
                        {
                            _15050 = float((_15038 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15055 = _15050;
                        break;
                    }
                    uint _15040;
                    _15040 = 4294967295u;
                    uint _17236;
                    for (int _15039 = 0; _15039 < 8; _15040 = _17236, _15039++)
                    {
                        int _15043 = 0;
                        for (;;)
                        {
                            if (_15043 < 5)
                            {
                                int2 _11623 = _14390 + (_1184[_15039] * _1193[_15043].xx);
                                bool _11626 = any(bool2(_11623.x < int2(0, 0).x, _11623.y < int2(0, 0).y));
                                bool _11634;
                                if (!_11626)
                                {
                                    _11634 = any(bool2(_11623.x >= cbFI_MvDepthLaneSize.x, _11623.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11634 = _11626;
                                }
                                if (_11634)
                                {
                                    _17236 = _15040;
                                    break;
                                }
                                uint4 _11712 = r_warped_motion_qdata_tp1.Load(int3(_11623, 0));
                                uint _11713 = _11712.x;
                                if (_11713 != 0u)
                                {
                                    _17236 = min(_15040, _11713);
                                    break;
                                }
                                _15043++;
                                continue;
                            }
                            else
                            {
                                _17236 = _15040;
                                break;
                            }
                        }
                    }
                    float _15042;
                    if (_15040 == 4294967295u)
                    {
                        _15042 = -1.0f;
                    }
                    else
                    {
                        float _15041;
                        if (_15040 == 0u)
                        {
                            _15041 = -1.0f;
                        }
                        else
                        {
                            _15041 = float((_15040 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15042 = _15041;
                    }
                    _15055 = _15042;
                    break;
                } while(false);
                bool _5629 = _15055 < 0.0f;
                float _15056;
                if (_5629)
                {
                    _15056 = 0.0f;
                }
                else
                {
                    _15056 = _15055 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11734_dummy_parameter;
                uint _11766_dummy_parameter;
                float4 _15093;
                if ((_5629 && _5618) && _5621)
                {
                    uint _11798_dummy_parameter;
                    float _11822 = log(((r_depth_tm1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11798_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11830_dummy_parameter;
                    float _11854 = log(((r_depth_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11830_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _15094;
                    if (_11822 > (_11854 + 0.07999999821186065673828125f))
                    {
                        float4 _14038 = _15060;
                        _14038.x = 0.0f;
                        _15094 = _14038;
                    }
                    else
                    {
                        float4 _15095;
                        if (_11854 > (_11822 + 0.07999999821186065673828125f))
                        {
                            float4 _14040 = _15060;
                            _14040.y = 0.0f;
                            _15095 = _14040;
                        }
                        else
                        {
                            _15095 = _15060;
                        }
                        _15094 = _15095;
                    }
                    _15093 = _15094;
                }
                else
                {
                    _15093 = _15060;
                }
                float _5681 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5683 = _15055 >= 0.0f;
                float _15076;
                if (_5683)
                {
                    _15076 = _15055 - _5681;
                }
                else
                {
                    float _15072;
                    if (_5618)
                    {
                        float _15071;
                        _15071 = 2.0f;
                        float _11912;
                        for (int _15070 = 0; _15070 < 24; _15071 = _11912, _15070++)
                        {
                            float _11876 = float(_15070 & 7) * 0.785398185253143310546875f;
                            int _11878 = _15070 >> 3;
                            int _15073;
                            if (_11878 == 0)
                            {
                                _15073 = 16;
                            }
                            else
                            {
                                _15073 = (_11878 == 1) ? 48 : 96;
                            }
                            uint _11928_dummy_parameter;
                            _11912 = min(_15071, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14169 + ((cbFI_MvDepthLaneSizeRcp * float(_15073)) * float2(cos(_11876), sin(_11876))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11928_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15072 = _15071;
                    }
                    else
                    {
                        _15072 = 0.0f;
                    }
                    _15076 = _15072;
                }
                float _15083;
                if (_5683)
                {
                    _15083 = _15055 - _5681;
                }
                else
                {
                    float _15079;
                    if (_5621)
                    {
                        float _15078;
                        _15078 = 2.0f;
                        float _12026;
                        for (int _15077 = 0; _15077 < 24; _15078 = _12026, _15077++)
                        {
                            float _11990 = float(_15077 & 7) * 0.785398185253143310546875f;
                            int _11992 = _15077 >> 3;
                            int _15080;
                            if (_11992 == 0)
                            {
                                _15080 = 16;
                            }
                            else
                            {
                                _15080 = (_11992 == 1) ? 48 : 96;
                            }
                            uint _12058_dummy_parameter;
                            _12026 = min(_15078, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14171 + ((cbFI_MvDepthLaneSizeRcp * float(_15080)) * float2(cos(_11990), sin(_11990))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12058_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15079 = _15078;
                    }
                    else
                    {
                        _15079 = 0.0f;
                    }
                    _15083 = _15079;
                }
                float _15084;
                if (_5618)
                {
                    uint _12090_dummy_parameter;
                    _15084 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12090_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15084 = 0.0f;
                }
                float _15085;
                if (_5621)
                {
                    uint _12110_dummy_parameter;
                    _15085 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12110_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15085 = 0.0f;
                }
                bool _5738;
                if (_5618)
                {
                    _5738 = _15084 > ((exp((_15076 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5738 = _5618;
                }
                float4 _15101;
                if (_5738)
                {
                    float4 _14042 = _15093;
                    _14042.x = 0.0f;
                    _15101 = _14042;
                }
                else
                {
                    _15101 = _15093;
                }
                bool _5750;
                if (_5621)
                {
                    _5750 = _15085 > ((exp((_15083 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5750 = _5621;
                }
                float4 _15103;
                if (_5750)
                {
                    float4 _14044 = _15101;
                    _14044.y = 0.0f;
                    _15103 = _14044;
                }
                else
                {
                    _15103 = _15101;
                }
                float4 _15166;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5683)
                {
                    bool _5770;
                    if (_5618)
                    {
                        _5770 = _15084 < ((exp((_15076 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5770 = _5618;
                    }
                    float4 _15105;
                    if (_5770)
                    {
                        float4 _14046 = _15103;
                        _14046.x = 0.0f;
                        _15105 = _14046;
                    }
                    else
                    {
                        _15105 = _15103;
                    }
                    bool _5782;
                    if (_5621)
                    {
                        _5782 = _15085 < ((exp((_15083 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5782 = _5621;
                    }
                    float4 _15167;
                    if (_5782)
                    {
                        float4 _14048 = _15105;
                        _14048.y = 0.0f;
                        _15167 = _14048;
                    }
                    else
                    {
                        _15167 = _15105;
                    }
                    _15166 = _15167;
                }
                else
                {
                    _15166 = _15103;
                }
                _16201 = float3(_15056, log(((r_depth_tm1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11734_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_14171 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11766_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _15165 = _15166;
            }
            else
            {
                _16201 = float3(0.0f, 0.0f, 0.5f);
                _15165 = _15060;
            }
            bool _5793 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5542;
            bool _5799;
            if (_5793)
            {
                _5799 = _5596 || _5602;
            }
            else
            {
                _5799 = _5793;
            }
            float4 _15208;
            if (_5799)
            {
                float _15160;
                do
                {
                    uint4 _12290 = r_warped_motion_qdata_tp1.Load(int3(_14390, 0));
                    uint _12291 = _12290.x;
                    if (_12291 != 0u)
                    {
                        float _15159;
                        if (_12291 == 0u)
                        {
                            _15159 = -1.0f;
                        }
                        else
                        {
                            _15159 = float((_12291 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15160 = _15159;
                        break;
                    }
                    int _15142;
                    uint _15143;
                    _15143 = _12291;
                    _15142 = -1;
                    uint _15158;
                    for (; _15142 <= 1; _15143 = _15158, _15142++)
                    {
                        _15158 = _15143;
                        for (int _15156 = -1; _15156 <= 1; )
                        {
                            _15158 = max(_15158, r_warped_motion_qdata_tp1.Load(int3(clamp(_14390 + int2(_15156, _15142), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15156++;
                            continue;
                        }
                    }
                    if (_15143 != 0u)
                    {
                        float _15155;
                        if (_15143 == 0u)
                        {
                            _15155 = -1.0f;
                        }
                        else
                        {
                            _15155 = float((_15143 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15160 = _15155;
                        break;
                    }
                    uint _15145;
                    _15145 = 4294967295u;
                    uint _17237;
                    for (int _15144 = 0; _15144 < 8; _15145 = _17237, _15144++)
                    {
                        int _15148 = 0;
                        for (;;)
                        {
                            if (_15148 < 5)
                            {
                                int2 _12241 = _14390 + (_1184[_15144] * _1193[_15148].xx);
                                bool _12244 = any(bool2(_12241.x < int2(0, 0).x, _12241.y < int2(0, 0).y));
                                bool _12252;
                                if (!_12244)
                                {
                                    _12252 = any(bool2(_12241.x >= cbFI_MvDepthLaneSize.x, _12241.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12252 = _12244;
                                }
                                if (_12252)
                                {
                                    _17237 = _15145;
                                    break;
                                }
                                uint4 _12330 = r_warped_motion_qdata_tp1.Load(int3(_12241, 0));
                                uint _12331 = _12330.x;
                                if (_12331 != 0u)
                                {
                                    _17237 = min(_15145, _12331);
                                    break;
                                }
                                _15148++;
                                continue;
                            }
                            else
                            {
                                _17237 = _15145;
                                break;
                            }
                        }
                    }
                    float _15147;
                    if (_15145 == 4294967295u)
                    {
                        _15147 = -1.0f;
                    }
                    else
                    {
                        float _15146;
                        if (_15145 == 0u)
                        {
                            _15146 = -1.0f;
                        }
                        else
                        {
                            _15146 = float((_15145 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15147 = _15146;
                    }
                    _15160 = _15147;
                    break;
                } while(false);
                float4 _15209;
                if (_15160 >= 0.0f)
                {
                    float _12352 = (exp((_15160 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5818;
                    if (_5596)
                    {
                        uint _12359_dummy_parameter;
                        _5818 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12359_dummy_parameter))))), 0)).x) > _12352;
                    }
                    else
                    {
                        _5818 = _5596;
                    }
                    float4 _15178;
                    if (_5818)
                    {
                        float4 _14050 = _15165;
                        _14050.z = 0.0f;
                        _15178 = _14050;
                    }
                    else
                    {
                        _15178 = _15165;
                    }
                    bool _5830;
                    if (_5602)
                    {
                        uint _12379_dummy_parameter;
                        _5830 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12379_dummy_parameter))))), 0)).x) > _12352;
                    }
                    else
                    {
                        _5830 = _5602;
                    }
                    float4 _15210;
                    if (_5830)
                    {
                        float4 _14052 = _15178;
                        _14052.w = 0.0f;
                        _15210 = _14052;
                    }
                    else
                    {
                        _15210 = _15178;
                    }
                    _15209 = _15210;
                }
                else
                {
                    _15209 = _15165;
                }
                _15208 = _15209;
            }
            else
            {
                _15208 = _15165;
            }
            bool _5838 = _5584 != _5590;
            bool _5845;
            if (_5838)
            {
                _5845 = _5584 ? _5530 : _5533;
            }
            else
            {
                _5845 = _5838;
            }
            bool _5852;
            if (_5845)
            {
                _5852 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5852 = _5845;
            }
            float4 _15311;
            if (_5852)
            {
                bool2 _5857 = _5584.xx;
                float2 _5858 = float2(_5857.x ? _14169.x : _14171.x, _5857.y ? _14169.y : _14171.y);
                float _15192;
                if (_5584)
                {
                    uint _12399_dummy_parameter;
                    _15192 = r_depth_tm1.Load(int3(int2(floor(_5858 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12399_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12415_dummy_parameter;
                    _15192 = r_depth_tp1.Load(int3(int2(floor(_5858 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12415_dummy_parameter))))), 0)).x;
                }
                float4x4 _15199;
                if (_5584)
                {
                    float4x4 _15188;
                    do
                    {
                        float4x4 _12429;
                        bool _15187;
                        do
                        {
                            _12429 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15187 = false;
                                break;
                            }
                            uint _12463 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12463 + 32u) * 4 + 0) != 1u)
                            {
                                _15187 = false;
                                break;
                            }
                            uint _15184;
                            _15184 = 0u;
                            for (; _15184 < 4u; _15184++)
                            {
                                for (uint _15185 = 0u; _15185 < 4u; )
                                {
                                    _12429[_15184][_15185] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12463 + 16u) + (_15184 * 4u)) + _15185) * 4 + 0));
                                    _15185++;
                                    continue;
                                }
                            }
                            _15187 = true;
                            break;
                        } while(false);
                        if (_15187)
                        {
                            _15188 = _12429;
                            break;
                        }
                        _15188 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15199 = _15188;
                }
                else
                {
                    float4x4 _15183;
                    do
                    {
                        float4x4 _12535;
                        bool _15182;
                        do
                        {
                            _12535 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15182 = false;
                                break;
                            }
                            uint _12569 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12569 + 32u) * 4 + 0) != 1u)
                            {
                                _15182 = false;
                                break;
                            }
                            uint _15179;
                            _15179 = 0u;
                            for (; _15179 < 4u; _15179++)
                            {
                                for (uint _15180 = 0u; _15180 < 4u; )
                                {
                                    _12535[_15179][_15180] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12569 + (_15179 * 4u)) + _15180) * 4 + 0));
                                    _15180++;
                                    continue;
                                }
                            }
                            _15182 = true;
                            break;
                        } while(false);
                        if (_15182)
                        {
                            _15183 = _12535;
                            break;
                        }
                        _15183 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15199 = _15183;
                }
                float2 _15200;
                do
                {
                    float _12646 = _5858.x;
                    float _12649 = 1.0f - _5858.y;
                    float4 _12660 = mul(float4((float2(_12646, _12649) * 2.0f) - 1.0f.xx, _15192, 1.0f), _15199);
                    float _12662 = _12660.w;
                    if (!(_12662 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15200 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12675 = ((_12660.xy / _12662.xx) + 1.0f.xx) * 0.5f;
                    _15200 = float2(_12675.x - _12646, _12649 - _12675.y);
                    break;
                } while(false);
                float2 _5888 = float2(cbFI_DisplaySize);
                float4 _15312;
                if (!(length(((_5858 + _15200) - float2(_5857.x ? _14171.x : _14169.x, _5857.y ? _14171.y : _14169.y)) * _5888) <= ((0.100000001490116119384765625f * length(_15200 * _5888)) + 8.0f)))
                {
                    float4 _15313;
                    if (_5584)
                    {
                        float4 _14062 = _15208;
                        _14062.x = 0.0f;
                        _15313 = _14062;
                    }
                    else
                    {
                        float4 _14064 = _15208;
                        _14064.y = 0.0f;
                        _15313 = _14064;
                    }
                    _15312 = _15313;
                }
                else
                {
                    _15312 = _15208;
                }
                _15311 = _15312;
            }
            else
            {
                _15311 = _15208;
            }
            float4 _5913 = _14922 * _15311;
            float _5915 = dot(_5913, 1.0f.xxxx);
            float4 _15653;
            bool _15959;
            if (_5915 > 0.0f)
            {
                _15959 = _14613;
                _15653 = _5913 / _5915.xxxx;
            }
            else
            {
                bool _5926 = any(bool4(_15311.x < 1.0f.xxxx.x, _15311.y < 1.0f.xxxx.y, _15311.z < 1.0f.xxxx.z, _15311.w < 1.0f.xxxx.w));
                if (_5926)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12697;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12697);
                    }
                }
                bool4 _17272 = _5926.xxxx;
                _15959 = _5926 ? true : _14613;
                _15653 = float4(_17272.x ? 0.0f.xxxx.x : _14922.x, _17272.y ? 0.0f.xxxx.y : _14922.y, _17272.z ? 0.0f.xxxx.z : _14922.z, _17272.w ? 0.0f.xxxx.w : _14922.w);
            }
            _16092 = _16201;
            _15958 = _15959;
            _15652 = _15653;
        }
        else
        {
            _16092 = float3(0.0f, 0.0f, 0.5f);
            _15958 = _14613;
            _15652 = _14922;
        }
        uint _5935 = (cbFI_pad0 >> 24u) & 31u;
        uint _5939 = (cbFI_pad0 >> 16u) & 255u;
        bool _5941 = _5935 != 0u;
        bool _5943 = _5939 == 12u;
        bool _5946 = _5939 == 13u;
        float4 _15673;
        if ((_5941 || _5943) || _5946)
        {
            float _15319;
            do
            {
                bool _12781 = all(bool2(_14172.x > 0.0f.xx.x, _14172.y > 0.0f.xx.y));
                bool _12787;
                if (_12781)
                {
                    _12787 = all(bool2(_14172.x < 1.0f.xx.x, _14172.y < 1.0f.xx.y));
                }
                else
                {
                    _12787 = _12781;
                }
                bool _12718 = !_12787;
                bool _12725;
                if (!_12718)
                {
                    bool _12792 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
                    bool _12798;
                    if (_12792)
                    {
                        _12798 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12798 = _12792;
                    }
                    _12725 = !_12798;
                }
                else
                {
                    _12725 = _12718;
                }
                if (_12725)
                {
                    _15319 = 0.0f;
                    break;
                }
                uint _12805_dummy_parameter;
                uint _12821_dummy_parameter;
                float4x4 _15318;
                do
                {
                    float4x4 _12835;
                    bool _15317;
                    do
                    {
                        _12835 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15317 = false;
                            break;
                        }
                        uint _12869 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12869 + 32u) * 4 + 0) != 1u)
                        {
                            _15317 = false;
                            break;
                        }
                        uint _15314;
                        _15314 = 0u;
                        for (; _15314 < 4u; _15314++)
                        {
                            for (uint _15315 = 0u; _15315 < 4u; )
                            {
                                _12835[_15314][_15315] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12869 + 16u) + (_15314 * 4u)) + _15315) * 4 + 0));
                                _15315++;
                                continue;
                            }
                        }
                        _15317 = true;
                        break;
                    } while(false);
                    if (_15317)
                    {
                        _15318 = _12835;
                        break;
                    }
                    _15318 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12746 = mul(float4((float2(_14172.x, 1.0f - _14172.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14172 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12805_dummy_parameter))))), 0)).x, 1.0f), _15318);
                float _12748 = _12746.w;
                if (abs(_12748) < 9.9999999747524270787835121154785e-07f)
                {
                    _15319 = 0.0f;
                    break;
                }
                float _12759 = abs(cbFI_DeviceToViewDepth.y / ((_12746.z / _12748) - cbFI_DeviceToViewDepth.x));
                float _12762 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12821_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15319 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12759 - _12762) / max(max(_12759, _12762), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _12971 = all(bool2(_14173.x > 0.0f.xx.x, _14173.y > 0.0f.xx.y));
            bool _12977;
            if (_12971)
            {
                _12977 = all(bool2(_14173.x < 1.0f.xx.x, _14173.y < 1.0f.xx.y));
            }
            else
            {
                _12977 = _12971;
            }
            float _15320;
            if (_12977)
            {
                uint _12984_dummy_parameter;
                _15320 = length((_6797 + (r_motion_tp1.Load(int3(int2(floor(_14173 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12984_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15320 = 1000000.0f;
            }
            float _15335;
            if ((_5935 & 1u) != 0u)
            {
                _15335 = _15319;
            }
            else
            {
                _15335 = 1.0f;
            }
            float _15336;
            if ((_5935 & 2u) != 0u)
            {
                _15336 = _15335 * (1.0f - smoothstep(2.0f, 8.0f, _15320));
            }
            else
            {
                _15336 = _15335;
            }
            float _15337;
            if ((_5935 & 4u) != 0u)
            {
                _15337 = _15336 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7518 - _7526) - length(_7502 - _7510))));
            }
            else
            {
                _15337 = _15336;
            }
            float _15667;
            if ((_5935 & 8u) != 0u)
            {
                _15667 = lerp(1.0f, _15337, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7502 - _7510)));
            }
            else
            {
                _15667 = _15337;
            }
            bool _6021 = (_5935 & 16u) != 0u;
            bool _6030;
            if (_6021)
            {
                _6030 = length(_14167 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6030 = _6021;
            }
            float _17274 = _6030 ? 1.0f : _15667;
            bool _6036 = _5941 && _9899;
            bool _6041;
            if (_6036)
            {
                bool _13009 = all(bool2(_14169.x > 0.0f.xx.x, _14169.y > 0.0f.xx.y));
                bool _13015;
                if (_13009)
                {
                    _13015 = all(bool2(_14169.x < 1.0f.xx.x, _14169.y < 1.0f.xx.y));
                }
                else
                {
                    _13015 = _13009;
                }
                _6041 = _13015;
            }
            else
            {
                _6041 = _6036;
            }
            bool _6046;
            if (_6041)
            {
                bool _13020 = all(bool2(_14171.x > 0.0f.xx.x, _14171.y > 0.0f.xx.y));
                bool _13026;
                if (_13020)
                {
                    _13026 = all(bool2(_14171.x < 1.0f.xx.x, _14171.y < 1.0f.xx.y));
                }
                else
                {
                    _13026 = _13020;
                }
                _6046 = _13026;
            }
            else
            {
                _6046 = _6041;
            }
            float4 _15674;
            if (_6046)
            {
                float _6052 = _15652.x + _15652.y;
                float _6061 = (_15652.z + _15652.w) * (1.0f - _17274);
                float _15670;
                if (_6052 > 9.9999997473787516355514526367188e-06f)
                {
                    _15670 = _15652.x / _6052;
                }
                else
                {
                    _15670 = _4791;
                }
                _15674 = float4(_15652.x + (_6061 * _15670), _15652.y + (_6061 * (1.0f - _15670)), _15652.zw * _17274);
            }
            else
            {
                _15674 = _15652;
            }
            _15673 = _15674;
        }
        else
        {
            _15673 = _15652;
        }
        float3 _6122 = (((_7502 * _15673.x) + (_7510 * _15673.y)) + (_7518 * _15673.z)) + (_7526 * _15673.w);
        float3 _17037;
        if (_4807 && (_15688 > 0.0f))
        {
            uint _13033_dummy_parameter;
            float2 _13048 = r_motion_tp1.Load(int3(int2(floor(_4566 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13033_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _15950;
            if (_6825)
            {
                float2 _13093 = clamp((((_14146 + (_13048 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13096 = tan(_13093.x);
                _15950 = (float2(_13096 / cbFI_DeviceToViewDepth.z, (tan(_13093.y) * sqrt(1.0f + (_13096 * _13096))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15950 = _14146 + (_13048 * cbFI_Timestep);
            }
            float2 _15951;
            if (_6825)
            {
                float2 _13172 = clamp((((_14146 + (_13048 * _4781)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13175 = tan(_13172.x);
                _15951 = (float2(_13175 / cbFI_DeviceToViewDepth.z, (tan(_13172.y) * sqrt(1.0f + (_13175 * _13175))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15951 = _14146 + (_13048 * _4781);
            }
            _17037 = lerp(_6122, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _15950, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _15951, 0.0f).xyz, cbFI_Timestep.xxx), _15688.xxx);
        }
        else
        {
            _17037 = _6122;
        }
        float3 _17036;
        if (_15958)
        {
            float3 _13217 = r_current_interpolation_source.Load(int3(_4102, 0)).xyz;
            float3 _17038;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9899)
            {
                uint _13224_dummy_parameter;
                float _16081;
                _16081 = r_depth_tm1.Load(int3(int2(floor(_14169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13224_dummy_parameter))))), 0)).x;
                float _6203;
                for (int _16080 = 0; _16080 < 24; _16081 = _6203, _16080++)
                {
                    float _6175 = float(_16080 & 7) * 0.785398185253143310546875f;
                    int _6177 = _16080 >> 3;
                    int _17090;
                    if (_6177 == 0)
                    {
                        _17090 = 16;
                    }
                    else
                    {
                        _17090 = (_6177 == 1) ? 48 : 96;
                    }
                    uint _13244_dummy_parameter;
                    _6203 = max(_16081, r_depth_tm1.Load(int3(int2(floor(clamp(_14169 + ((cbFI_MvDepthLaneSizeRcp * float(_17090)) * float2(cos(_6175), sin(_6175))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13244_dummy_parameter))))), 0)).x);
                }
                float2 _16082;
                do
                {
                    float _13266 = 1.0f - _14169.y;
                    float4 _13277 = mul(float4((float2(_14169.x, _13266) * 2.0f) - 1.0f.xx, _16081, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13279 = _13277.w;
                    if (!(_13279 > 9.9999999747524270787835121154785e-07f))
                    {
                        _16082 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13292 = ((_13277.xy / _13279.xx) + 1.0f.xx) * 0.5f;
                    _16082 = float2(_13292.x - _14169.x, _13266 - _13292.y);
                    break;
                } while(false);
                float2 _6214 = _14169 + _16082;
                bool _13310 = all(bool2(_6214.x > 0.0f.xx.x, _6214.y > 0.0f.xx.y));
                bool _13316;
                if (_13310)
                {
                    _13316 = all(bool2(_6214.x < 1.0f.xx.x, _6214.y < 1.0f.xx.y));
                }
                else
                {
                    _13316 = _13310;
                }
                float3 _17039;
                if (_13316)
                {
                    float _6220 = abs(cbFI_DeviceToViewDepth.y / (_16081 - cbFI_DeviceToViewDepth.x));
                    uint _13336_dummy_parameter;
                    int2 _13336 = int2(spvTextureSize(r_depth_m2, uint(0), _13336_dummy_parameter));
                    float _6224 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6214 * float2(_13336))), int2(0, 0), _13336 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _17044;
                    if (abs(_6224 - _6220) <= (0.20000000298023223876953125f * max(_6224, _6220)))
                    {
                        uint _13370_dummy_parameter;
                        int2 _13370 = int2(spvTextureSize(r_colour_m2, uint(0), _13370_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13393;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13393);
                        }
                        _17044 = r_colour_m2.Load(int3(clamp(int2(floor(_6214 * float2(_13370))), int2(0, 0), _13370 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13403;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13403);
                        }
                        _17044 = _13217;
                    }
                    _17039 = _17044;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13413;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13413);
                    }
                    _17039 = _13217;
                }
                _17038 = _17039;
            }
            else
            {
                _17038 = _13217;
            }
            _17036 = _17038;
        }
        else
        {
            _17036 = _17037;
        }
        uint _6252 = cbFI_pad0 & 255u;
        bool _16910;
        float3 _17035;
        if (_6252 != 0u)
        {
            float3 _6257 = r_present_backbuffer.Load(int3(_4102, 0)).xyz;
            float3 _6261 = r_current_interpolation_source.Load(int3(_4102, 0)).xyz;
            float3 _6265 = abs(_6257 - _6261);
            float3 _16085;
            if (_6252 == 2u)
            {
                _16085 = (abs(_6261) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _16085 = 0.000244140625f.xxx;
            }
            bool _6281 = any(bool3(_6265.x > _16085.x, _6265.y > _16085.y, _6265.z > _16085.z));
            bool3 _17275 = _6281.xxx;
            _17035 = float3(_17275.x ? _6257.x : _17036.x, _17275.y ? _6257.y : _17036.y, _17275.z ? _6257.z : _17036.z);
            _16910 = _6281;
        }
        else
        {
            _17035 = _17036;
            _16910 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13428;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13428);
        }
        float3 _17017;
        if (_5939 == 1u)
        {
            _17017 = lerp(_7502, _7510, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _17018;
            if (_5939 == 2u)
            {
                _17018 = lerp(_7518, _7526, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _17019;
                if (_5939 == 3u)
                {
                    _17019 = float(_16910).xxx;
                }
                else
                {
                    float3 _17020;
                    if (_5939 == 4u)
                    {
                        _17020 = float3(((_14167 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _17021;
                        if (_5939 == 5u)
                        {
                            _17021 = float3(((_6797 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _17022;
                            if (_5939 == 6u)
                            {
                                _17022 = float3(_15673.xy, _15673.z + _15673.w);
                            }
                            else
                            {
                                float3 _17023;
                                if (_5939 == 7u)
                                {
                                    _17023 = r_current_interpolation_source.Load(int3(_4102, 0)).xyz;
                                }
                                else
                                {
                                    float3 _17024;
                                    if (_5939 == 8u)
                                    {
                                        _17024 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4566, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _17025;
                                        if (_5943)
                                        {
                                            uint _13450_dummy_parameter;
                                            uint _13482_dummy_parameter;
                                            _17025 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4566 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13450_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4566 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13482_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _17026;
                                            if (_5946)
                                            {
                                                _17026 = _7518;
                                            }
                                            else
                                            {
                                                float3 _17027;
                                                if (_5939 == 20u)
                                                {
                                                    _17027 = _7502;
                                                }
                                                else
                                                {
                                                    float3 _17028;
                                                    if (_5939 == 21u)
                                                    {
                                                        _17028 = _7510;
                                                    }
                                                    else
                                                    {
                                                        float3 _17029;
                                                        if (_5939 == 22u)
                                                        {
                                                            _17029 = _7526;
                                                        }
                                                        else
                                                        {
                                                            float3 _17030;
                                                            if (_5939 == 18u)
                                                            {
                                                                _17030 = _16558;
                                                            }
                                                            else
                                                            {
                                                                float3 _17031;
                                                                if (_5939 == 19u)
                                                                {
                                                                    _17031 = _16322;
                                                                }
                                                                else
                                                                {
                                                                    float3 _17032;
                                                                    if (_5939 == 23u)
                                                                    {
                                                                        _17032 = _16092;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _17033;
                                                                        if (_5939 == 24u)
                                                                        {
                                                                            uint _6425 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _6430 = float(rw_nfru_diagnostics.Load<uint>((_6425 + 35u) * 4 + 0));
                                                                            float _16086;
                                                                            if (_6430 > 0.0f)
                                                                            {
                                                                                _16086 = float(rw_nfru_diagnostics.Load<uint>((_6425 + 34u) * 4 + 0)) / _6430;
                                                                            }
                                                                            else
                                                                            {
                                                                                _16086 = 0.0f;
                                                                            }
                                                                            _17033 = float3(float(rw_nfru_diagnostics.Load<uint>((_6425 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_6425 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _16086);
                                                                        }
                                                                        else
                                                                        {
                                                                            _17033 = _17035;
                                                                        }
                                                                        _17032 = _17033;
                                                                    }
                                                                    _17031 = _17032;
                                                                }
                                                                _17030 = _17031;
                                                            }
                                                            _17029 = _17030;
                                                        }
                                                        _17028 = _17029;
                                                    }
                                                    _17027 = _17028;
                                                }
                                                _17026 = _17027;
                                            }
                                            _17025 = _17026;
                                        }
                                        _17024 = _17025;
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
        float3 _17016;
        if ((_5939 >= 9u) && (_5939 <= 11u))
        {
            uint _6490 = 64u + uint((_14390.y * cbFI_MvDepthLaneSize.x) + _14390.x);
            uint _6494 = rw_nfru_diagnostics.Load<uint>(_6490 * 4 + 0) & 15u;
            float3 _17049;
            if (_5939 == 10u)
            {
                float3 _17015;
                if ((rw_nfru_diagnostics.Load<uint>(_6490 * 4 + 0) & 32u) != 0u)
                {
                    _17015 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _17014;
                    if ((rw_nfru_diagnostics.Load<uint>(_6490 * 4 + 0) & 16u) != 0u)
                    {
                        _17014 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6515 = ((rw_nfru_diagnostics.Load<uint>(_6490 * 4 + 0) & 64u) != 0u).xxx;
                        _17014 = float3(_6515.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6515.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6515.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _17015 = _17014;
                }
                _17049 = _17015;
            }
            else
            {
                float3 _17050;
                if (_5939 == 11u)
                {
                    uint _6528 = (rw_nfru_diagnostics.Load<uint>(_6490 * 4 + 0) >> 8u) & 15u;
                    uint _6531 = (rw_nfru_diagnostics.Load<uint>(_6490 * 4 + 0) >> 12u) & 15u;
                    float3 _17007;
                    if ((_6494 == 2u) || (_6494 == 3u))
                    {
                        _17007 = _3815[_6494];
                    }
                    else
                    {
                        bool _6543 = _6528 == 3u;
                        bool _6545 = _6531 == 3u;
                        float3 _17008;
                        if (_6543 && _6545)
                        {
                            _17008 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _17009;
                            if (_6543)
                            {
                                _17009 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _17010;
                                if (_6545)
                                {
                                    _17010 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _17011;
                                    if ((_6528 == 4u) || (_6531 == 4u))
                                    {
                                        _17011 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _17012;
                                        if ((_6528 == 1u) || (_6531 == 1u))
                                        {
                                            _17012 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17277 = (_6494 == 1u).xxx;
                                            _17012 = float3(_17277.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17277.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17277.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _17011 = _17012;
                                    }
                                    _17010 = _17011;
                                }
                                _17009 = _17010;
                            }
                            _17008 = _17009;
                        }
                        _17007 = _17008;
                    }
                    _17050 = _17007;
                }
                else
                {
                    _17050 = _3815[min(_6494, 7u)];
                }
                _17049 = _17050;
            }
            _17016 = _17049;
        }
        else
        {
            _17016 = _17017;
        }
        float4 _17053;
        if ((_5939 >= 14u) && (_5939 <= 16u))
        {
            float2 _17051;
            if (_5939 == 14u)
            {
                uint _6601_dummy_parameter;
                uint _6607_dummy_parameter;
                _17051 = r_flow_tm1.Load(int3(clamp(int2(floor(_4566 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6601_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6607_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _17052;
                if (_5939 == 16u)
                {
                    uint _13558 = r_warped_flow_qdata_tm1.Load(int3(_4582, 0)).x & 2147483647u;
                    uint _13590 = uint(max((int((_13558 >> 16u) & 15u) - 6), 0));
                    _17052 = ((float2(float((1 - (2 * int((_13558 >> 15u) & 1u))) * int(((_13558 >> uint(7)) & 127u) << _13590)), float((1 - (2 * int((_13558 >> 14u) & 1u))) * int((_13558 & 127u) << _13590))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _17052 = _6797 * float2(cbFI_DisplaySize);
                }
                _17051 = _17052;
            }
            uint2 _6640 = uint2(clamp(round(_17051 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6642 = _6640.x;
            uint _6649 = _6640.y;
            _17053 = float4(float(_6642 & 255u), float((_6642 >> 8u) | ((_6649 & 15u) << 4u)), float(_6649 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _17054;
            if (_5939 == 17u)
            {
                _17054 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4582, 0)).x != 0u), _5026, 0.0f, 1.0f);
            }
            else
            {
                _17054 = float4(_17016, 1.0f);
            }
            _17053 = _17054;
        }
        rw_output[_4102] = _17053.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6693 = ((uint(_4102.y) * uint(cbFI_DisplaySize.x)) + uint(_4102.x)) * 6u;
            uint _13636 = spvPackHalf2x16(clamp(_7501.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6693 * 4 + 0, (((_13636 & 32767u) >> 4u) | ((((_13636 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7501.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13671 = spvPackHalf2x16(clamp(_7509.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6693 + 1u) * 4 + 0, (((_13671 & 32767u) >> 4u) | ((((_13671 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7509.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13706 = spvPackHalf2x16(clamp(_7517.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6693 + 2u) * 4 + 0, (((_13706 & 32767u) >> 4u) | ((((_13706 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7517.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13741 = spvPackHalf2x16(clamp(_7525.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6693 + 3u) * 4 + 0, (((_13741 & 32767u) >> 4u) | ((((_13741 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7525.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13768 = r_current_interpolation_source.Load(int3(_4102, 0));
            uint _13782 = spvPackHalf2x16(clamp(_13768.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6693 + 4u) * 4 + 0, (((_13782 & 32767u) >> 4u) | ((((_13782 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13768.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _17089;
            if (_16910 || (_5939 != 0u))
            {
                _17089 = 4294967295u;
            }
            else
            {
                uint _13817 = spvPackHalf2x16(clamp(_17053.xy, 0.0f.xx, 65000.0f.xx));
                _17089 = (((_13817 & 32767u) >> 4u) | ((((_13817 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_17053.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6693 + 5u) * 4 + 0, _17089);
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
