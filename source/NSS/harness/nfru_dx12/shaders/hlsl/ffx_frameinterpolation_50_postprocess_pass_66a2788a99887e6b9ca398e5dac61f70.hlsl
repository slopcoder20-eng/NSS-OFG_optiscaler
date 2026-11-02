static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1192[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1201[5] = { 2, 4, 7, 11, 16 };
static const float3 _3833[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4137 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4137.x >= cbFI_DisplaySize.x, _4137.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4137] = float4(r_present_backbuffer.Load(int3(_4137, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4137] = float4(r_current_interpolation_source.Load(int3(_4137, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4614 = (float2(_4137) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4616 = float2(cbFI_MvDepthLaneSize);
        int2 _4625 = int2(floor(_4614 * _4616));
        int2 _4630 = int2(floor(_4614 * float2(cbFI_FlowLaneSize)));
        float4 _6863 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4614 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6869 = r_warped_filled_flow_tm1.Load(int3(_4630, 0)).xy;
        float2 _6875 = r_warped_filled_motion_tp1.Load(int3(_4625, 0)).xy;
        bool _6897 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14220;
        if (_6897)
        {
            float _6910 = ((2.0f * _4614.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14220 = float2(atan(_6910) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4614.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6910 * _6910))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14220 = _4614;
        }
        bool _4651 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14241;
        bool _14383;
        int2 _14464;
        float3 _16632;
        if (_4651)
        {
            float _14222;
            float _14224;
            _14224 = 2.0f;
            _14222 = -1.0f;
            uint _4221[9];
            float _17205;
            float _17208;
            for (int _14221 = 0; _14221 < 9; _14224 = _17208, _14222 = _17205, _14221++)
            {
                _4221[_14221] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4625 + int2((_14221 % 3) - 1, (_14221 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4221[_14221] != 0u)
                {
                    float _17200;
                    if (_4221[_14221] == 0u)
                    {
                        _17200 = -1.0f;
                    }
                    else
                    {
                        _17200 = float((_4221[_14221] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17208 = min(_14224, _17200);
                    _17205 = max(_14222, _17200);
                }
                else
                {
                    _17208 = _14224;
                    _17205 = _14222;
                }
            }
            float _4697 = float(_14222 >= 0.0f);
            float3 _13923 = 0.0f.xxx;
            _13923.y = _4697;
            float2 _14242;
            bool _14384;
            int2 _14465;
            float3 _16633;
            if ((_14222 - _14224) > 0.0199999995529651641845703125f)
            {
                float _14230;
                int2 _14231;
                float2 _14232;
                int2 _14234;
                float2 _14240;
                _14240 = _6875;
                _14234 = _4625;
                _14232 = _6875;
                _14231 = _4625;
                _14230 = -1.0f;
                float _17213;
                int2 _17217;
                float2 _17228;
                int2 _17239;
                float2 _17272;
                float _17319;
                int _14229 = 0;
                float _17181 = 1000000000.0f;
                for (; _14229 < 9; _17181 = _17319, _14240 = _17272, _14234 = _17239, _14232 = _17228, _14231 = _17217, _14230 = _17213, _14229++)
                {
                    if (_4221[_14229] == 0u)
                    {
                        _17319 = _17181;
                        _17272 = _14240;
                        _17239 = _14234;
                        _17228 = _14232;
                        _17217 = _14231;
                        _17213 = _14230;
                        continue;
                    }
                    int2 _4732 = clamp(_4625 + int2((_14229 % 3) - 1, (_14229 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6985 = _4221[_14229] & 2147483647u;
                    uint _7017 = uint(max((int((_6985 >> 16u) & 15u) - 6), 0));
                    float2 _4738 = (float2(float((1 - (2 * int((_6985 >> 15u) & 1u))) * int(((_6985 >> uint(7)) & 127u) << _7017)), float((1 - (2 * int((_6985 >> 14u) & 1u))) * int((_6985 & 127u) << _7017))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _17167;
                    if (_4221[_14229] == 0u)
                    {
                        _17167 = -1.0f;
                    }
                    else
                    {
                        _17167 = float((_4221[_14229] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4743 = _17167 - 0.100000001490116119384765625f;
                    float2 _17168;
                    if (_6897)
                    {
                        float2 _7094 = clamp((((_14220 + (_4738 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7097 = tan(_7094.x);
                        _17168 = (float2(_7097 / cbFI_DeviceToViewDepth.z, (tan(_7094.y) * sqrt(1.0f + (_7097 * _7097))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17168 = _14220 + (_4738 * cbFI_Timestep);
                    }
                    float _4750 = cbFI_Timestep - 1.0f;
                    float2 _17169;
                    if (_6897)
                    {
                        float2 _7165 = clamp((((_14220 + (_4738 * _4750)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7168 = tan(_7165.x);
                        _17169 = (float2(_7168 / cbFI_DeviceToViewDepth.z, (tan(_7165.y) * sqrt(1.0f + (_7168 * _7168))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17169 = _14220 + (_4738 * _4750);
                    }
                    bool _7201 = all(bool2(_17168.x > 0.0f.xx.x, _17168.y > 0.0f.xx.y));
                    bool _7207;
                    if (_7201)
                    {
                        _7207 = all(bool2(_17168.x < 1.0f.xx.x, _17168.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7207 = _7201;
                    }
                    float _17172;
                    if (_7207)
                    {
                        uint _7214_dummy_parameter;
                        _17172 = max((_4743 - (log((r_depth_tm1.Load(int3(int2(floor(_17168 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7214_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17172 = 0.0f;
                    }
                    bool _7244 = all(bool2(_17169.x > 0.0f.xx.x, _17169.y > 0.0f.xx.y));
                    bool _7250;
                    if (_7244)
                    {
                        _7250 = all(bool2(_17169.x < 1.0f.xx.x, _17169.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7250 = _7244;
                    }
                    float _17173;
                    if (_7250)
                    {
                        uint _7257_dummy_parameter;
                        _17173 = _17172 + max((_4743 - (log((r_depth_tp1.Load(int3(int2(floor(_17169 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7257_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17173 = _17172;
                    }
                    float _17214;
                    int2 _17218;
                    float2 _17229;
                    int2 _17240;
                    float2 _17273;
                    float _17320;
                    if (_17173 == 0.0f)
                    {
                        bool _4785 = _4743 > _14230;
                        bool2 _17328 = _4785.xx;
                        _17320 = _17181;
                        _17273 = float2(_17328.x ? _4738.x : _14240.x, _17328.y ? _4738.y : _14240.y);
                        _17240 = int2(_17328.x ? _4732.x : _14234.x, _17328.y ? _4732.y : _14234.y);
                        _17229 = _14232;
                        _17218 = _14231;
                        _17214 = _4785 ? _4743 : _14230;
                    }
                    else
                    {
                        bool _4794 = _17173 < _17181;
                        bool2 _17324 = _4794.xx;
                        _17320 = _4794 ? _17173 : _17181;
                        _17273 = _14240;
                        _17240 = _14234;
                        _17229 = float2(_17324.x ? _4738.x : _14232.x, _17324.y ? _4738.y : _14232.y);
                        _17218 = int2(_17324.x ? _4732.x : _14231.x, _17324.y ? _4732.y : _14231.y);
                        _17214 = _14230;
                    }
                    _17319 = _17320;
                    _17272 = _17273;
                    _17239 = _17240;
                    _17228 = _17229;
                    _17217 = _17218;
                    _17213 = _17214;
                }
                bool _4806 = _14230 < 0.0f;
                bool2 _17334 = _4806.xx;
                int2 _17337 = int2(_17334.x ? _14231.x : _14234.x, _17334.y ? _14231.y : _14234.y);
                _16633 = float3(1.0f, _4697, float(any(bool2(_17337.x != _4625.x, _17337.y != _4625.y))));
                _14465 = _17337;
                _14384 = _4806 ? false : true;
                _14242 = float2(_17334.x ? _14232.x : _14240.x, _17334.y ? _14232.y : _14240.y);
            }
            else
            {
                _16633 = _13923;
                _14465 = _4625;
                _14384 = false;
                _14242 = _6875;
            }
            _16632 = _16633;
            _14464 = _14465;
            _14383 = _14384;
            _14241 = _14242;
        }
        else
        {
            _16632 = 0.0f.xxx;
            _14464 = _4625;
            _14383 = false;
            _14241 = _6875;
        }
        float2 _14243;
        if (_6897)
        {
            float2 _7322 = clamp((((_14220 + (_14241 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7325 = tan(_7322.x);
            _14243 = (float2(_7325 / cbFI_DeviceToViewDepth.z, (tan(_7322.y) * sqrt(1.0f + (_7325 * _7325))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14243 = _14220 + (_14241 * cbFI_Timestep);
        }
        float _4829 = cbFI_Timestep - 1.0f;
        float2 _14245;
        if (_6897)
        {
            float2 _7393 = clamp((((_14220 + (_14241 * _4829)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7396 = tan(_7393.x);
            _14245 = (float2(_7396 / cbFI_DeviceToViewDepth.z, (tan(_7393.y) * sqrt(1.0f + (_7396 * _7396))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14245 = _14220 + (_14241 * _4829);
        }
        float _4834 = -cbFI_Timestep;
        float2 _14246;
        if (_6897)
        {
            float2 _7464 = clamp((((_14220 + (_6869 * _4834)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7467 = tan(_7464.x);
            _14246 = (float2(_7467 / cbFI_DeviceToViewDepth.z, (tan(_7464.y) * sqrt(1.0f + (_7467 * _7467))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14246 = _14220 + (_6869 * _4834);
        }
        float _4839 = 1.0f - cbFI_Timestep;
        float2 _14247;
        if (_6897)
        {
            float2 _7535 = clamp((((_14220 + (_6869 * _4839)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7538 = tan(_7535.x);
            _14247 = (float2(_7538 / cbFI_DeviceToViewDepth.z, (tan(_7535.y) * sqrt(1.0f + (_7538 * _7538))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14247 = _14220 + (_6869 * _4839);
        }
        float4 _7573 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14243, 0.0f);
        float3 _7574 = _7573.xyz;
        float4 _7581 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14245, 0.0f);
        float3 _7582 = _7581.xyz;
        float4 _7589 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14246, 0.0f);
        float3 _7590 = _7589.xyz;
        float4 _7597 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14247, 0.0f);
        float3 _7598 = _7597.xyz;
        float4 _7612 = exp(_6863 - max(max(max(_6863.x, _6863.y), _6863.z), _6863.w).xxxx);
        float4 _7619 = _7612 / (dot(_7612, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4855 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14454;
        float _15762;
        if (_4855)
        {
            float2 _4861 = 0.5f.xx / _4616;
            float _4864 = _4861.x;
            float _4865 = -_4864;
            float _4867 = _4861.y;
            float _4868 = -_4867;
            float2 _4870 = _4614 + float2(_4865, _4868);
            float2 _4872 = float2(cbFI_DisplaySize);
            bool _14264;
            do
            {
                bool _7699 = all(bool2(_4870.x > 0.0f.xx.x, _4870.y > 0.0f.xx.y));
                bool _7705;
                if (_7699)
                {
                    _7705 = all(bool2(_4870.x < 1.0f.xx.x, _4870.y < 1.0f.xx.y));
                }
                else
                {
                    _7705 = _7699;
                }
                if (!_7705)
                {
                    _14264 = false;
                    break;
                }
                uint _7712_dummy_parameter;
                float4x4 _14262;
                do
                {
                    float4x4 _7726;
                    bool _14261;
                    do
                    {
                        _7726 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14261 = false;
                            break;
                        }
                        uint _7760 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7760 + 32u) * 4 + 0) != 1u)
                        {
                            _14261 = false;
                            break;
                        }
                        uint _14258;
                        _14258 = 0u;
                        for (; _14258 < 4u; _14258++)
                        {
                            for (uint _14259 = 0u; _14259 < 4u; )
                            {
                                _7726[_14258][_14259] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7760 + (_14258 * 4u)) + _14259) * 4 + 0));
                                _14259++;
                                continue;
                            }
                        }
                        _14261 = true;
                        break;
                    } while(false);
                    if (_14261)
                    {
                        _14262 = _7726;
                        break;
                    }
                    _14262 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14263;
                do
                {
                    float _7837 = _4870.x;
                    float _7840 = 1.0f - _4870.y;
                    float4 _7851 = mul(float4((float2(_7837, _7840) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4870 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7712_dummy_parameter))))), 0)).x, 1.0f), _14262);
                    float _7853 = _7851.w;
                    if (!(_7853 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14263 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7866 = ((_7851.xy / _7853.xx) + 1.0f.xx) * 0.5f;
                    _14263 = float2(_7866.x - _7837, _7840 - _7866.y);
                    break;
                } while(false);
                float2 _7663 = abs(_14263);
                if (any(bool2(_7663.x > 100000.0f.xx.x, _7663.y > 100000.0f.xx.y)))
                {
                    _14264 = false;
                    break;
                }
                float _7671 = length(_14263 * _4872);
                uint _7886_dummy_parameter;
                bool _7685 = _7671 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7692;
                if (_7685)
                {
                    _7692 = length((r_motion_tp1.Load(int3(int2(floor(_4870 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7886_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _7671);
                }
                else
                {
                    _7692 = _7685;
                }
                _14264 = _7692;
                break;
            } while(false);
            float2 _4882 = _4614 + float2(_4864, _4868);
            bool _14271;
            do
            {
                bool _7972 = all(bool2(_4882.x > 0.0f.xx.x, _4882.y > 0.0f.xx.y));
                bool _7978;
                if (_7972)
                {
                    _7978 = all(bool2(_4882.x < 1.0f.xx.x, _4882.y < 1.0f.xx.y));
                }
                else
                {
                    _7978 = _7972;
                }
                if (!_7978)
                {
                    _14271 = false;
                    break;
                }
                uint _7985_dummy_parameter;
                float4x4 _14269;
                do
                {
                    float4x4 _7999;
                    bool _14268;
                    do
                    {
                        _7999 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14268 = false;
                            break;
                        }
                        uint _8033 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8033 + 32u) * 4 + 0) != 1u)
                        {
                            _14268 = false;
                            break;
                        }
                        uint _14265;
                        _14265 = 0u;
                        for (; _14265 < 4u; _14265++)
                        {
                            for (uint _14266 = 0u; _14266 < 4u; )
                            {
                                _7999[_14265][_14266] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8033 + (_14265 * 4u)) + _14266) * 4 + 0));
                                _14266++;
                                continue;
                            }
                        }
                        _14268 = true;
                        break;
                    } while(false);
                    if (_14268)
                    {
                        _14269 = _7999;
                        break;
                    }
                    _14269 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14270;
                do
                {
                    float _8110 = _4882.x;
                    float _8113 = 1.0f - _4882.y;
                    float4 _8124 = mul(float4((float2(_8110, _8113) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4882 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7985_dummy_parameter))))), 0)).x, 1.0f), _14269);
                    float _8126 = _8124.w;
                    if (!(_8126 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14270 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8139 = ((_8124.xy / _8126.xx) + 1.0f.xx) * 0.5f;
                    _14270 = float2(_8139.x - _8110, _8113 - _8139.y);
                    break;
                } while(false);
                float2 _7936 = abs(_14270);
                if (any(bool2(_7936.x > 100000.0f.xx.x, _7936.y > 100000.0f.xx.y)))
                {
                    _14271 = false;
                    break;
                }
                float _7944 = length(_14270 * _4872);
                uint _8159_dummy_parameter;
                bool _7958 = _7944 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7965;
                if (_7958)
                {
                    _7965 = length((r_motion_tp1.Load(int3(int2(floor(_4882 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8159_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _7944);
                }
                else
                {
                    _7965 = _7958;
                }
                _14271 = _7965;
                break;
            } while(false);
            float2 _4895 = _4614 + float2(_4865, _4867);
            bool _14278;
            do
            {
                bool _8245 = all(bool2(_4895.x > 0.0f.xx.x, _4895.y > 0.0f.xx.y));
                bool _8251;
                if (_8245)
                {
                    _8251 = all(bool2(_4895.x < 1.0f.xx.x, _4895.y < 1.0f.xx.y));
                }
                else
                {
                    _8251 = _8245;
                }
                if (!_8251)
                {
                    _14278 = false;
                    break;
                }
                uint _8258_dummy_parameter;
                float4x4 _14276;
                do
                {
                    float4x4 _8272;
                    bool _14275;
                    do
                    {
                        _8272 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14275 = false;
                            break;
                        }
                        uint _8306 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8306 + 32u) * 4 + 0) != 1u)
                        {
                            _14275 = false;
                            break;
                        }
                        uint _14272;
                        _14272 = 0u;
                        for (; _14272 < 4u; _14272++)
                        {
                            for (uint _14273 = 0u; _14273 < 4u; )
                            {
                                _8272[_14272][_14273] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8306 + (_14272 * 4u)) + _14273) * 4 + 0));
                                _14273++;
                                continue;
                            }
                        }
                        _14275 = true;
                        break;
                    } while(false);
                    if (_14275)
                    {
                        _14276 = _8272;
                        break;
                    }
                    _14276 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14277;
                do
                {
                    float _8383 = _4895.x;
                    float _8386 = 1.0f - _4895.y;
                    float4 _8397 = mul(float4((float2(_8383, _8386) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4895 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8258_dummy_parameter))))), 0)).x, 1.0f), _14276);
                    float _8399 = _8397.w;
                    if (!(_8399 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14277 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8412 = ((_8397.xy / _8399.xx) + 1.0f.xx) * 0.5f;
                    _14277 = float2(_8412.x - _8383, _8386 - _8412.y);
                    break;
                } while(false);
                float2 _8209 = abs(_14277);
                if (any(bool2(_8209.x > 100000.0f.xx.x, _8209.y > 100000.0f.xx.y)))
                {
                    _14278 = false;
                    break;
                }
                float _8217 = length(_14277 * _4872);
                uint _8432_dummy_parameter;
                bool _8231 = _8217 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8238;
                if (_8231)
                {
                    _8238 = length((r_motion_tp1.Load(int3(int2(floor(_4895 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8432_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _8217);
                }
                else
                {
                    _8238 = _8231;
                }
                _14278 = _8238;
                break;
            } while(false);
            float2 _4907 = _4614 + _4861;
            bool _14285;
            do
            {
                bool _8518 = all(bool2(_4907.x > 0.0f.xx.x, _4907.y > 0.0f.xx.y));
                bool _8524;
                if (_8518)
                {
                    _8524 = all(bool2(_4907.x < 1.0f.xx.x, _4907.y < 1.0f.xx.y));
                }
                else
                {
                    _8524 = _8518;
                }
                if (!_8524)
                {
                    _14285 = false;
                    break;
                }
                uint _8531_dummy_parameter;
                float4x4 _14283;
                do
                {
                    float4x4 _8545;
                    bool _14282;
                    do
                    {
                        _8545 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14282 = false;
                            break;
                        }
                        uint _8579 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8579 + 32u) * 4 + 0) != 1u)
                        {
                            _14282 = false;
                            break;
                        }
                        uint _14279;
                        _14279 = 0u;
                        for (; _14279 < 4u; _14279++)
                        {
                            for (uint _14280 = 0u; _14280 < 4u; )
                            {
                                _8545[_14279][_14280] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8579 + (_14279 * 4u)) + _14280) * 4 + 0));
                                _14280++;
                                continue;
                            }
                        }
                        _14282 = true;
                        break;
                    } while(false);
                    if (_14282)
                    {
                        _14283 = _8545;
                        break;
                    }
                    _14283 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14284;
                do
                {
                    float _8656 = _4907.x;
                    float _8659 = 1.0f - _4907.y;
                    float4 _8670 = mul(float4((float2(_8656, _8659) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4907 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8531_dummy_parameter))))), 0)).x, 1.0f), _14283);
                    float _8672 = _8670.w;
                    if (!(_8672 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14284 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8685 = ((_8670.xy / _8672.xx) + 1.0f.xx) * 0.5f;
                    _14284 = float2(_8685.x - _8656, _8659 - _8685.y);
                    break;
                } while(false);
                float2 _8482 = abs(_14284);
                if (any(bool2(_8482.x > 100000.0f.xx.x, _8482.y > 100000.0f.xx.y)))
                {
                    _14285 = false;
                    break;
                }
                float _8490 = length(_14284 * _4872);
                uint _8705_dummy_parameter;
                bool _8504 = _8490 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8511;
                if (_8504)
                {
                    _8511 = length((r_motion_tp1.Load(int3(int2(floor(_4907 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8705_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _8490);
                }
                else
                {
                    _8511 = _8504;
                }
                _14285 = _8511;
                break;
            } while(false);
            float _4913 = 0.25f * (((float(_14264) + float(_14271)) + float(_14278)) + float(_14285));
            float4 _14455;
            if (_4913 < 1.0f)
            {
                bool _14292;
                do
                {
                    bool _8791 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
                    bool _8797;
                    if (_8791)
                    {
                        _8797 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8797 = _8791;
                    }
                    if (!_8797)
                    {
                        _14292 = false;
                        break;
                    }
                    uint _8804_dummy_parameter;
                    float4x4 _14290;
                    do
                    {
                        float4x4 _8818;
                        bool _14289;
                        do
                        {
                            _8818 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14289 = false;
                                break;
                            }
                            uint _8852 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8852 + 32u) * 4 + 0) != 1u)
                            {
                                _14289 = false;
                                break;
                            }
                            uint _14286;
                            _14286 = 0u;
                            for (; _14286 < 4u; _14286++)
                            {
                                for (uint _14287 = 0u; _14287 < 4u; )
                                {
                                    _8818[_14286][_14287] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8852 + (_14286 * 4u)) + _14287) * 4 + 0));
                                    _14287++;
                                    continue;
                                }
                            }
                            _14289 = true;
                            break;
                        } while(false);
                        if (_14289)
                        {
                            _14290 = _8818;
                            break;
                        }
                        _14290 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14291;
                    do
                    {
                        float _8932 = 1.0f - _14243.y;
                        float4 _8943 = mul(float4((float2(_14243.x, _8932) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8804_dummy_parameter))))), 0)).x, 1.0f), _14290);
                        float _8945 = _8943.w;
                        if (!(_8945 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14291 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8958 = ((_8943.xy / _8945.xx) + 1.0f.xx) * 0.5f;
                        _14291 = float2(_8958.x - _14243.x, _8932 - _8958.y);
                        break;
                    } while(false);
                    float2 _8755 = abs(_14291);
                    if (any(bool2(_8755.x > 100000.0f.xx.x, _8755.y > 100000.0f.xx.y)))
                    {
                        _14292 = false;
                        break;
                    }
                    float _8763 = length(_14291 * _4872);
                    uint _8978_dummy_parameter;
                    bool _8777 = _8763 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8784;
                    if (_8777)
                    {
                        _8784 = length((r_motion_tp1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8978_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _8763);
                    }
                    else
                    {
                        _8784 = _8777;
                    }
                    _14292 = _8784;
                    break;
                } while(false);
                bool _14299;
                do
                {
                    bool _9064 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
                    bool _9070;
                    if (_9064)
                    {
                        _9070 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9070 = _9064;
                    }
                    if (!_9070)
                    {
                        _14299 = false;
                        break;
                    }
                    uint _9077_dummy_parameter;
                    float4x4 _14297;
                    do
                    {
                        float4x4 _9091;
                        bool _14296;
                        do
                        {
                            _9091 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14296 = false;
                                break;
                            }
                            uint _9125 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9125 + 32u) * 4 + 0) != 1u)
                            {
                                _14296 = false;
                                break;
                            }
                            uint _14293;
                            _14293 = 0u;
                            for (; _14293 < 4u; _14293++)
                            {
                                for (uint _14294 = 0u; _14294 < 4u; )
                                {
                                    _9091[_14293][_14294] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9125 + (_14293 * 4u)) + _14294) * 4 + 0));
                                    _14294++;
                                    continue;
                                }
                            }
                            _14296 = true;
                            break;
                        } while(false);
                        if (_14296)
                        {
                            _14297 = _9091;
                            break;
                        }
                        _14297 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14298;
                    do
                    {
                        float _9205 = 1.0f - _14245.y;
                        float4 _9216 = mul(float4((float2(_14245.x, _9205) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9077_dummy_parameter))))), 0)).x, 1.0f), _14297);
                        float _9218 = _9216.w;
                        if (!(_9218 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14298 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9231 = ((_9216.xy / _9218.xx) + 1.0f.xx) * 0.5f;
                        _14298 = float2(_9231.x - _14245.x, _9205 - _9231.y);
                        break;
                    } while(false);
                    float2 _9028 = abs(_14298);
                    if (any(bool2(_9028.x > 100000.0f.xx.x, _9028.y > 100000.0f.xx.y)))
                    {
                        _14299 = false;
                        break;
                    }
                    float _9036 = length(_14298 * _4872);
                    uint _9251_dummy_parameter;
                    bool _9050 = _9036 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9057;
                    if (_9050)
                    {
                        _9057 = length((r_motion_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9251_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _9036);
                    }
                    else
                    {
                        _9057 = _9050;
                    }
                    _14299 = _9057;
                    break;
                } while(false);
                bool _14306;
                do
                {
                    bool _9337 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                    bool _9343;
                    if (_9337)
                    {
                        _9343 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9343 = _9337;
                    }
                    if (!_9343)
                    {
                        _14306 = false;
                        break;
                    }
                    uint _9350_dummy_parameter;
                    float4x4 _14304;
                    do
                    {
                        float4x4 _9364;
                        bool _14303;
                        do
                        {
                            _9364 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14303 = false;
                                break;
                            }
                            uint _9398 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9398 + 32u) * 4 + 0) != 1u)
                            {
                                _14303 = false;
                                break;
                            }
                            uint _14300;
                            _14300 = 0u;
                            for (; _14300 < 4u; _14300++)
                            {
                                for (uint _14301 = 0u; _14301 < 4u; )
                                {
                                    _9364[_14300][_14301] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9398 + (_14300 * 4u)) + _14301) * 4 + 0));
                                    _14301++;
                                    continue;
                                }
                            }
                            _14303 = true;
                            break;
                        } while(false);
                        if (_14303)
                        {
                            _14304 = _9364;
                            break;
                        }
                        _14304 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14305;
                    do
                    {
                        float _9478 = 1.0f - _14246.y;
                        float4 _9489 = mul(float4((float2(_14246.x, _9478) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9350_dummy_parameter))))), 0)).x, 1.0f), _14304);
                        float _9491 = _9489.w;
                        if (!(_9491 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14305 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9504 = ((_9489.xy / _9491.xx) + 1.0f.xx) * 0.5f;
                        _14305 = float2(_9504.x - _14246.x, _9478 - _9504.y);
                        break;
                    } while(false);
                    float2 _9301 = abs(_14305);
                    if (any(bool2(_9301.x > 100000.0f.xx.x, _9301.y > 100000.0f.xx.y)))
                    {
                        _14306 = false;
                        break;
                    }
                    float _9309 = length(_14305 * _4872);
                    uint _9524_dummy_parameter;
                    bool _9323 = _9309 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9330;
                    if (_9323)
                    {
                        _9330 = length((r_motion_tp1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9524_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _9309);
                    }
                    else
                    {
                        _9330 = _9323;
                    }
                    _14306 = _9330;
                    break;
                } while(false);
                bool _14313;
                do
                {
                    bool _9610 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                    bool _9616;
                    if (_9610)
                    {
                        _9616 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9616 = _9610;
                    }
                    if (!_9616)
                    {
                        _14313 = false;
                        break;
                    }
                    uint _9623_dummy_parameter;
                    float4x4 _14311;
                    do
                    {
                        float4x4 _9637;
                        bool _14310;
                        do
                        {
                            _9637 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14310 = false;
                                break;
                            }
                            uint _9671 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9671 + 32u) * 4 + 0) != 1u)
                            {
                                _14310 = false;
                                break;
                            }
                            uint _14307;
                            _14307 = 0u;
                            for (; _14307 < 4u; _14307++)
                            {
                                for (uint _14308 = 0u; _14308 < 4u; )
                                {
                                    _9637[_14307][_14308] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9671 + (_14307 * 4u)) + _14308) * 4 + 0));
                                    _14308++;
                                    continue;
                                }
                            }
                            _14310 = true;
                            break;
                        } while(false);
                        if (_14310)
                        {
                            _14311 = _9637;
                            break;
                        }
                        _14311 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14312;
                    do
                    {
                        float _9751 = 1.0f - _14247.y;
                        float4 _9762 = mul(float4((float2(_14247.x, _9751) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9623_dummy_parameter))))), 0)).x, 1.0f), _14311);
                        float _9764 = _9762.w;
                        if (!(_9764 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14312 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9777 = ((_9762.xy / _9764.xx) + 1.0f.xx) * 0.5f;
                        _14312 = float2(_9777.x - _14247.x, _9751 - _9777.y);
                        break;
                    } while(false);
                    float2 _9574 = abs(_14312);
                    if (any(bool2(_9574.x > 100000.0f.xx.x, _9574.y > 100000.0f.xx.y)))
                    {
                        _14313 = false;
                        break;
                    }
                    float _9582 = length(_14312 * _4872);
                    uint _9797_dummy_parameter;
                    bool _9596 = _9582 > ((8.0f * _4872.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9603;
                    if (_9596)
                    {
                        _9603 = length((r_motion_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9797_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4872) < (0.20000000298023223876953125f * _9582);
                    }
                    else
                    {
                        _9603 = _9596;
                    }
                    _14313 = _9603;
                    break;
                } while(false);
                float4 _4940 = _7619 * float4(_14292 ? 0.0f : 1.0f, _14299 ? 0.0f : 1.0f, _14306 ? 0.0f : 1.0f, _14313 ? 0.0f : 1.0f);
                float _4942 = dot(_4940, 1.0f.xxxx);
                float4 _14456;
                if (_4942 > 0.001000000047497451305389404296875f)
                {
                    _14456 = _4940 / _4942.xxxx;
                }
                else
                {
                    _14456 = _7619;
                }
                _14455 = _14456;
            }
            else
            {
                _14455 = _7619;
            }
            _15762 = _4913;
            _14454 = _14455;
        }
        else
        {
            _15762 = 0.0f;
            _14454 = _7619;
        }
        bool _4959 = _4651 && (!_14383);
        bool _4968;
        if (_4959)
        {
            _4968 = (_14454.z + _14454.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4968 = _4959;
        }
        bool _4979;
        if (_4968)
        {
            _4979 = length((_14246 - _14243) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4979 = _4968;
        }
        bool _14543;
        if (_4979)
        {
            uint4 _9826 = r_warped_motion_qdata_tp1.Load(int3(_14464, 0));
            uint _9827 = _9826.x;
            bool _14546;
            if (_9827 != 0u)
            {
                float _14532;
                if (_9827 == 0u)
                {
                    _14532 = -1.0f;
                }
                else
                {
                    _14532 = float((_9827 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4989 = _14532 - 0.12000000476837158203125f;
                bool _9846 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                bool _9852;
                if (_9846)
                {
                    _9852 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                }
                else
                {
                    _9852 = _9846;
                }
                bool _4999;
                if (_9852)
                {
                    uint _9859_dummy_parameter;
                    _4999 = (log((r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9859_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4989;
                }
                else
                {
                    _4999 = _9852;
                }
                bool _5013;
                if (!_4999)
                {
                    bool _9889 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                    bool _9895;
                    if (_9889)
                    {
                        _9895 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9895 = _9889;
                    }
                    bool _5011;
                    if (_9895)
                    {
                        uint _9902_dummy_parameter;
                        _5011 = (log((r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9902_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4989;
                    }
                    else
                    {
                        _5011 = _9895;
                    }
                    _5013 = _5011;
                }
                else
                {
                    _5013 = _4999;
                }
                _14546 = _5013;
            }
            else
            {
                _14546 = false;
            }
            _14543 = _14546;
        }
        else
        {
            _14543 = false;
        }
        bool _5018 = _14383 || _14543;
        bool _5023;
        if (_5018)
        {
            bool _9932 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
            bool _9938;
            if (_9932)
            {
                _9938 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
            }
            else
            {
                _9938 = _9932;
            }
            _5023 = _9938;
        }
        else
        {
            _5023 = _5018;
        }
        bool _5028;
        if (_5023)
        {
            bool _9943 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
            bool _9949;
            if (_9943)
            {
                _9949 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
            }
            else
            {
                _9949 = _9943;
            }
            _5028 = _9949;
        }
        else
        {
            _5028 = _5023;
        }
        float4 _14666;
        if (_5028)
        {
            float _5034 = _14454.x + _14454.y;
            float _5039 = _14454.z + _14454.w;
            float _14561;
            if (_5034 > 0.001000000047497451305389404296875f)
            {
                _14561 = _14454.x / _5034;
            }
            else
            {
                _14561 = _4839;
            }
            _14666 = float4(_14454.x + (_5039 * _14561), _14454.y + (_5039 * (1.0f - _14561)), 0.0f, 0.0f);
        }
        else
        {
            _14666 = _14454;
        }
        bool _9977 = (cbFI_pad0 & 1024u) != 0u;
        bool _9953 = !_9977;
        bool _9954 = !_9953;
        bool _9971;
        if (_9954)
        {
            _9971 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14464.y * cbFI_MvDepthLaneSize.x) + _14464.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9971 = _9953;
        }
        bool _10003;
        if (_9954)
        {
            _10003 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4630.y * cbFI_FlowLaneSize.x) + _4630.x)) * 4 + 0) != 0u;
        }
        else
        {
            _10003 = _9953;
        }
        float _5074 = float(_10003);
        bool _14687;
        float4 _14726;
        float3 _16396;
        if (_9977)
        {
            bool _5084;
            if (_9971)
            {
                _5084 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
            }
            else
            {
                _5084 = _9971;
            }
            bool _5090;
            if (_5084)
            {
                _5090 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
            }
            else
            {
                _5090 = _5084;
            }
            bool _5097;
            if (_9971)
            {
                _5097 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
            }
            else
            {
                _5097 = _9971;
            }
            bool _5103;
            if (_5097)
            {
                _5103 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
            }
            else
            {
                _5103 = _5097;
            }
            bool _5110;
            if (_10003)
            {
                _5110 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
            }
            else
            {
                _5110 = _10003;
            }
            bool _5116;
            if (_5110)
            {
                _5116 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
            }
            else
            {
                _5116 = _5110;
            }
            bool _5123;
            if (_10003)
            {
                _5123 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
            }
            else
            {
                _5123 = _10003;
            }
            bool _5129;
            if (_5123)
            {
                _5129 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
            }
            else
            {
                _5129 = _5123;
            }
            bool _5131 = !_9971;
            if (_5131)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10045;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _10045);
                }
            }
            bool _5136 = !_10003;
            if (_5136)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10055;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _10055);
                }
            }
            if (_9971 && _5136)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10065;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _10065);
                }
            }
            if (_5131 && _10003)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10075;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _10075);
                }
            }
            float _5155 = float(_5090);
            float _5157 = float(_5103);
            bool _5160 = _5116 && _5129;
            float _14595;
            if (_5160)
            {
                _14595 = 1.0f;
            }
            else
            {
                _14595 = (_5116 || _5129) ? 0.5f : 0.0f;
            }
            bool _14610;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5090)) && (!_5103))
            {
                bool _5190;
                if (_5160)
                {
                    float _14603;
                    do
                    {
                        bool _10159 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                        bool _10165;
                        if (_10159)
                        {
                            _10165 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10165 = _10159;
                        }
                        bool _10096 = !_10165;
                        bool _10103;
                        if (!_10096)
                        {
                            bool _10170 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                            bool _10176;
                            if (_10170)
                            {
                                _10176 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10176 = _10170;
                            }
                            _10103 = !_10176;
                        }
                        else
                        {
                            _10103 = _10096;
                        }
                        if (_10103)
                        {
                            _14603 = 0.0f;
                            break;
                        }
                        uint _10183_dummy_parameter;
                        uint _10199_dummy_parameter;
                        float4x4 _14602;
                        do
                        {
                            float4x4 _10213;
                            bool _14601;
                            do
                            {
                                _10213 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14601 = false;
                                    break;
                                }
                                uint _10247 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10247 + 32u) * 4 + 0) != 1u)
                                {
                                    _14601 = false;
                                    break;
                                }
                                uint _14598;
                                _14598 = 0u;
                                for (; _14598 < 4u; _14598++)
                                {
                                    for (uint _14599 = 0u; _14599 < 4u; )
                                    {
                                        _10213[_14598][_14599] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10247 + 16u) + (_14598 * 4u)) + _14599) * 4 + 0));
                                        _14599++;
                                        continue;
                                    }
                                }
                                _14601 = true;
                                break;
                            } while(false);
                            if (_14601)
                            {
                                _14602 = _10213;
                                break;
                            }
                            _14602 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _10124 = mul(float4((float2(_14246.x, 1.0f - _14246.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10183_dummy_parameter))))), 0)).x, 1.0f), _14602);
                        float _10126 = _10124.w;
                        if (abs(_10126) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14603 = 0.0f;
                            break;
                        }
                        float _10137 = abs(cbFI_DeviceToViewDepth.y / ((_10124.z / _10126) - cbFI_DeviceToViewDepth.x));
                        float _10140 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10199_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14603 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10137 - _10140) / max(max(_10137, _10140), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5190 = _14603 >= 0.5f;
                }
                else
                {
                    _5190 = _5160;
                }
                bool _5198;
                if (_5190)
                {
                    _5198 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5198 = _5190;
                }
                bool _14611;
                if (_5198)
                {
                    uint _10351_dummy_parameter;
                    float4x4 _14608;
                    do
                    {
                        float4x4 _10365;
                        bool _14607;
                        do
                        {
                            _10365 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14607 = false;
                                break;
                            }
                            uint _10399 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10399 + 32u) * 4 + 0) != 1u)
                            {
                                _14607 = false;
                                break;
                            }
                            uint _14604;
                            _14604 = 0u;
                            for (; _14604 < 4u; _14604++)
                            {
                                for (uint _14605 = 0u; _14605 < 4u; )
                                {
                                    _10365[_14604][_14605] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10399 + 16u) + (_14604 * 4u)) + _14605) * 4 + 0));
                                    _14605++;
                                    continue;
                                }
                            }
                            _14607 = true;
                            break;
                        } while(false);
                        if (_14607)
                        {
                            _14608 = _10365;
                            break;
                        }
                        _14608 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14609;
                    do
                    {
                        float _10479 = 1.0f - _14246.y;
                        float4 _10490 = mul(float4((float2(_14246.x, _10479) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10351_dummy_parameter))))), 0)).x, 1.0f), _14608);
                        float _10492 = _10490.w;
                        if (!(_10492 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14609 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10505 = ((_10490.xy / _10492.xx) + 1.0f.xx) * 0.5f;
                        _14609 = float2(_10505.x - _14246.x, _10479 - _10505.y);
                        break;
                    } while(false);
                    float2 _5211 = float2(cbFI_DisplaySize);
                    _14611 = length(((_14246 + _14609) - _14247) * _5211) <= ((0.100000001490116119384765625f * length(_14609 * _5211)) + 8.0f);
                }
                else
                {
                    _14611 = _5190;
                }
                _14610 = _14611;
            }
            else
            {
                _14610 = true;
            }
            bool _5225 = !_14610;
            bool _17338 = _5225 ? false : _5129;
            bool _17339 = _5225 ? false : _5116;
            bool _14688;
            float4 _14727;
            if (!(((_5090 && _5103) && _17339) && _17338))
            {
                float4 _5247 = _14666 * float4(_5155, _5157, float(_17339), float(_17338));
                float _5249 = dot(_5247, 1.0f.xxxx);
                bool _5252 = !(_5249 > 0.0f);
                float4 _14728;
                if (!_5252)
                {
                    _14728 = _5247 / _5249.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10527;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10527);
                    }
                    _14728 = 0.0f.xxxx;
                }
                _14727 = _14728;
                _14688 = _5252;
            }
            else
            {
                _14727 = _14666;
                _14688 = false;
            }
            _16396 = float3(_5155, _5157, _14595);
            _14726 = _14727;
            _14687 = _14688;
        }
        else
        {
            _16396 = float3(float(_9971), _5074, 0.0f);
            _14726 = _14666;
            _14687 = false;
        }
        bool _5270 = !_14687;
        float4 _14819;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5270)
        {
            float _5277 = _14726.x + _14726.y;
            float4 _14820;
            if (_5277 > 0.001000000047497451305389404296875f)
            {
                _14820 = float4(_14726.x / _5277, _14726.y / _5277, 0.0f, 0.0f);
            }
            else
            {
                _14820 = float4(_4839, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14819 = _14820;
        }
        else
        {
            _14819 = _14726;
        }
        float4 _14996;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5270) && _9971)
        {
            float _14793;
            do
            {
                uint4 _10667 = r_warped_motion_qdata_tp1.Load(int3(_14464, 0));
                uint _10668 = _10667.x;
                if (_10668 != 0u)
                {
                    float _14792;
                    if (_10668 == 0u)
                    {
                        _14792 = -1.0f;
                    }
                    else
                    {
                        _14792 = float((_10668 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14793 = _14792;
                    break;
                }
                int _14775;
                uint _14776;
                _14776 = _10668;
                _14775 = -1;
                uint _14791;
                for (; _14775 <= 1; _14776 = _14791, _14775++)
                {
                    _14791 = _14776;
                    for (int _14789 = -1; _14789 <= 1; )
                    {
                        _14791 = max(_14791, r_warped_motion_qdata_tp1.Load(int3(clamp(_14464 + int2(_14789, _14775), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14789++;
                        continue;
                    }
                }
                if (_14776 != 0u)
                {
                    float _14788;
                    if (_14776 == 0u)
                    {
                        _14788 = -1.0f;
                    }
                    else
                    {
                        _14788 = float((_14776 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14793 = _14788;
                    break;
                }
                uint _14778;
                _14778 = 4294967295u;
                uint _17309;
                for (int _14777 = 0; _14777 < 8; _14778 = _17309, _14777++)
                {
                    int _14781 = 0;
                    for (;;)
                    {
                        if (_14781 < 5)
                        {
                            int2 _10618 = _14464 + (_1192[_14777] * _1201[_14781].xx);
                            bool _10621 = any(bool2(_10618.x < int2(0, 0).x, _10618.y < int2(0, 0).y));
                            bool _10629;
                            if (!_10621)
                            {
                                _10629 = any(bool2(_10618.x >= cbFI_MvDepthLaneSize.x, _10618.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10629 = _10621;
                            }
                            if (_10629)
                            {
                                _17309 = _14778;
                                break;
                            }
                            uint4 _10707 = r_warped_motion_qdata_tp1.Load(int3(_10618, 0));
                            uint _10708 = _10707.x;
                            if (_10708 != 0u)
                            {
                                _17309 = min(_14778, _10708);
                                break;
                            }
                            _14781++;
                            continue;
                        }
                        else
                        {
                            _17309 = _14778;
                            break;
                        }
                    }
                }
                float _14780;
                if (_14778 == 4294967295u)
                {
                    _14780 = -1.0f;
                }
                else
                {
                    float _14779;
                    if (_14778 == 0u)
                    {
                        _14779 = -1.0f;
                    }
                    else
                    {
                        _14779 = float((_14778 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14780 = _14779;
                }
                _14793 = _14780;
                break;
            } while(false);
            float _5313 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5316 = r_warped_motion_qdata_tp1.Load(int3(_14464, 0)).x == 0u;
            bool _5322;
            if (_5316)
            {
                bool _10733 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
                bool _10739;
                if (_10733)
                {
                    _10739 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
                }
                else
                {
                    _10739 = _10733;
                }
                _5322 = _10739;
            }
            else
            {
                _5322 = _5316;
            }
            bool _5327;
            if (_5322)
            {
                bool _10744 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
                bool _10750;
                if (_10744)
                {
                    _10750 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
                }
                else
                {
                    _10750 = _10744;
                }
                _5327 = _10750;
            }
            else
            {
                _5327 = _5322;
            }
            bool _14805;
            float4 _14814;
            if (_5327)
            {
                uint _10757_dummy_parameter;
                float _10781 = log((r_depth_tm1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10757_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _10789_dummy_parameter;
                float _10813 = log((r_depth_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10789_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _5338 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5345;
                if (_5338)
                {
                    _5345 = _10813 > (_10781 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5345 = _5338;
                }
                bool _14810;
                float4 _14832;
                if (_5345)
                {
                    _14832 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14810 = true;
                }
                else
                {
                    bool _5351 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5358;
                    if (_5351)
                    {
                        _5358 = _10781 > (_10813 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5358 = _5351;
                    }
                    bool4 _17340 = _5358.xxxx;
                    _14832 = float4(_17340.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14819.x, _17340.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14819.y, _17340.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14819.z, _17340.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14819.w);
                    _14810 = _5358 ? true : false;
                }
                _14814 = _14832;
                _14805 = _14810;
            }
            else
            {
                _14814 = _14819;
                _14805 = false;
            }
            float4 _14887;
            if (_14805)
            {
                _14887 = 1.0f.xxxx;
            }
            else
            {
                bool _5369 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5375;
                if (_5369)
                {
                    _5375 = _14814.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5375 = _5369;
                }
                bool _5380;
                if (_5375)
                {
                    bool _10819 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
                    bool _10825;
                    if (_10819)
                    {
                        _10825 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10825 = _10819;
                    }
                    _5380 = _10825;
                }
                else
                {
                    _5380 = _5375;
                }
                float4 _14888;
                if (_5380)
                {
                    float _14841;
                    if (_14793 >= 0.0f)
                    {
                        _14841 = _14793 - _5313;
                    }
                    else
                    {
                        float _14837;
                        _14837 = 2.0f;
                        float _10882;
                        for (int _14836 = 0; _14836 < 24; _14837 = _10882, _14836++)
                        {
                            float _10846 = float(_14836 & 7) * 0.785398185253143310546875f;
                            int _10848 = _14836 >> 3;
                            int _14838;
                            if (_10848 == 0)
                            {
                                _14838 = 16;
                            }
                            else
                            {
                                _14838 = (_10848 == 1) ? 48 : 96;
                            }
                            uint _10914_dummy_parameter;
                            _10882 = min(_14837, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14245 + ((cbFI_MvDepthLaneSizeRcp * float(_14838)) * float2(cos(_10846), sin(_10846))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10914_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14841 = _14837;
                    }
                    uint _10946_dummy_parameter;
                    float4 _14889;
                    if (r_depth_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10946_dummy_parameter))))), 0)).x > ((exp((_14841 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14889 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14889 = 1.0f.xxxx;
                    }
                    _14888 = _14889;
                }
                else
                {
                    _14888 = 1.0f.xxxx;
                }
                _14887 = _14888;
            }
            bool _5408 = _14793 >= 0.0f;
            bool _5409 = (!_14805) && _5408;
            bool _5416;
            if (_5409)
            {
                _5416 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5416 = _5409;
            }
            bool _5422;
            if (_5416)
            {
                _5422 = _14814.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5422 = _5416;
            }
            bool _5427;
            if (_5422)
            {
                bool _10970 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
                bool _10976;
                if (_10970)
                {
                    _10976 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
                }
                else
                {
                    _10976 = _10970;
                }
                _5427 = _10976;
            }
            else
            {
                _5427 = _5422;
            }
            float4 _14912;
            if (_5427)
            {
                float _14881;
                if (_5408)
                {
                    _14881 = _14793 - _5313;
                }
                else
                {
                    float _14877;
                    _14877 = 2.0f;
                    float _11033;
                    for (int _14876 = 0; _14876 < 24; _14877 = _11033, _14876++)
                    {
                        float _10997 = float(_14876 & 7) * 0.785398185253143310546875f;
                        int _10999 = _14876 >> 3;
                        int _14878;
                        if (_10999 == 0)
                        {
                            _14878 = 16;
                        }
                        else
                        {
                            _14878 = (_10999 == 1) ? 48 : 96;
                        }
                        uint _11049_dummy_parameter;
                        _11033 = min(_14877, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14243 + ((cbFI_MvDepthLaneSizeRcp * float(_14878)) * float2(cos(_10997), sin(_10997))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11049_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14881 = _14877;
                }
                uint _11097_dummy_parameter;
                float4 _14913;
                if (r_depth_tm1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11097_dummy_parameter))))), 0)).x > ((exp((_14881 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _14075 = _14887;
                    _14075.x = 0.0f;
                    _14913 = _14075;
                }
                else
                {
                    _14913 = _14887;
                }
                _14912 = _14913;
            }
            else
            {
                _14912 = _14887;
            }
            float4 _14925;
            if (_5409)
            {
                float _11123 = (exp(((_14793 - _5313) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5465 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5471;
                if (_5465)
                {
                    _5471 = _14814.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5471 = _5465;
                }
                bool _5476;
                if (_5471)
                {
                    bool _11128 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                    bool _11134;
                    if (_11128)
                    {
                        _11134 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11134 = _11128;
                    }
                    _5476 = _11134;
                }
                else
                {
                    _5476 = _5471;
                }
                bool _5484;
                if (_5476)
                {
                    uint _11141_dummy_parameter;
                    _5484 = r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11141_dummy_parameter))))), 0)).x > _11123;
                }
                else
                {
                    _5484 = _5476;
                }
                float4 _14923;
                if (_5484)
                {
                    float4 _14078 = _14912;
                    _14078.w = 0.0f;
                    _14923 = _14078;
                }
                else
                {
                    _14923 = _14912;
                }
                bool _5491 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5497;
                if (_5491)
                {
                    _5497 = _14814.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5497 = _5491;
                }
                bool _5502;
                if (_5497)
                {
                    bool _11158 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                    bool _11164;
                    if (_11158)
                    {
                        _11164 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11164 = _11158;
                    }
                    _5502 = _11164;
                }
                else
                {
                    _5502 = _5497;
                }
                bool _5510;
                if (_5502)
                {
                    uint _11171_dummy_parameter;
                    _5510 = r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11171_dummy_parameter))))), 0)).x > _11123;
                }
                else
                {
                    _5510 = _5502;
                }
                float4 _14926;
                if (_5510)
                {
                    float4 _14081 = _14923;
                    _14081.z = 0.0f;
                    _14926 = _14081;
                }
                else
                {
                    _14926 = _14923;
                }
                _14925 = _14926;
            }
            else
            {
                _14925 = _14912;
            }
            float4 _14997;
            if (any(bool4(_14925.x < 1.0f.xxxx.x, _14925.y < 1.0f.xxxx.y, _14925.z < 1.0f.xxxx.z, _14925.w < 1.0f.xxxx.w)))
            {
                float4 _5521 = _14814 * _14925;
                float _5523 = dot(_5521, 1.0f.xxxx);
                float4 _14998;
                if (_5523 > 0.0f)
                {
                    _14998 = _5521 / _5523.xxxx;
                }
                else
                {
                    bool _5534 = _14925.y == 0.0f;
                    bool _5540;
                    if (_5534)
                    {
                        _5540 = _14925.x > 0.0f;
                    }
                    else
                    {
                        _5540 = _5534;
                    }
                    bool _5545;
                    if (_5540)
                    {
                        bool _11188 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
                        bool _11194;
                        if (_11188)
                        {
                            _11194 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11194 = _11188;
                        }
                        _5545 = _11194;
                    }
                    else
                    {
                        _5545 = _5540;
                    }
                    float4 _14999;
                    if (_5545)
                    {
                        _14999 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5550 = _14925.x == 0.0f;
                        bool _5556;
                        if (_5550)
                        {
                            _5556 = _14925.y > 0.0f;
                        }
                        else
                        {
                            _5556 = _5550;
                        }
                        bool _5561;
                        if (_5556)
                        {
                            bool _11199 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
                            bool _11205;
                            if (_11199)
                            {
                                _11205 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11205 = _11199;
                            }
                            _5561 = _11205;
                        }
                        else
                        {
                            _5561 = _5556;
                        }
                        bool4 _17343 = _5561.xxxx;
                        _14999 = float4(_17343.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14814.x, _17343.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14814.y, _17343.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14814.z, _17343.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14814.w);
                    }
                    _14998 = _14999;
                }
                _14997 = _14998;
            }
            else
            {
                _14997 = _14814;
            }
            _14996 = _14997;
        }
        else
        {
            _14996 = _14819;
        }
        float4 _15726;
        bool _16032;
        float3 _16166;
        if (((cbFI_pad0 & 32768u) != 0u) && _5270)
        {
            bool _5578 = _14996.x > 0.00999999977648258209228515625f;
            bool _5581 = _14996.y > 0.00999999977648258209228515625f;
            bool _5590 = (_14996.z + _14996.w) > 0.0199999995529651641845703125f;
            bool _5596;
            if (_5590)
            {
                bool _11210 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                bool _11216;
                if (_11210)
                {
                    _11216 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                }
                else
                {
                    _11216 = _11210;
                }
                _5596 = _11216;
            }
            else
            {
                _5596 = _5590;
            }
            bool _5601;
            if (_5596)
            {
                bool _11221 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                bool _11227;
                if (_11221)
                {
                    _11227 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                }
                else
                {
                    _11227 = _11221;
                }
                _5601 = _11227;
            }
            else
            {
                _5601 = _5596;
            }
            bool _5608;
            if (_5601)
            {
                float _15012;
                do
                {
                    bool _11310 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                    bool _11316;
                    if (_11310)
                    {
                        _11316 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11316 = _11310;
                    }
                    bool _11247 = !_11316;
                    bool _11254;
                    if (!_11247)
                    {
                        bool _11321 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                        bool _11327;
                        if (_11321)
                        {
                            _11327 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11327 = _11321;
                        }
                        _11254 = !_11327;
                    }
                    else
                    {
                        _11254 = _11247;
                    }
                    if (_11254)
                    {
                        _15012 = 0.0f;
                        break;
                    }
                    uint _11334_dummy_parameter;
                    uint _11350_dummy_parameter;
                    float4x4 _15011;
                    do
                    {
                        float4x4 _11364;
                        bool _15010;
                        do
                        {
                            _11364 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15010 = false;
                                break;
                            }
                            uint _11398 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11398 + 32u) * 4 + 0) != 1u)
                            {
                                _15010 = false;
                                break;
                            }
                            uint _15007;
                            _15007 = 0u;
                            for (; _15007 < 4u; _15007++)
                            {
                                for (uint _15008 = 0u; _15008 < 4u; )
                                {
                                    _11364[_15007][_15008] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11398 + 16u) + (_15007 * 4u)) + _15008) * 4 + 0));
                                    _15008++;
                                    continue;
                                }
                            }
                            _15010 = true;
                            break;
                        } while(false);
                        if (_15010)
                        {
                            _15011 = _11364;
                            break;
                        }
                        _15011 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11275 = mul(float4((float2(_14246.x, 1.0f - _14246.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11334_dummy_parameter))))), 0)).x, 1.0f), _15011);
                    float _11277 = _11275.w;
                    if (abs(_11277) < 9.9999999747524270787835121154785e-07f)
                    {
                        _15012 = 0.0f;
                        break;
                    }
                    float _11288 = abs(cbFI_DeviceToViewDepth.y / ((_11275.z / _11277) - cbFI_DeviceToViewDepth.x));
                    float _11291 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11350_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _15012 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11288 - _11291) / max(max(_11288, _11291), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5608 = _15012 < 0.5f;
            }
            else
            {
                _5608 = _5601;
            }
            float4 _15031;
            if (_5608)
            {
                uint _11502_dummy_parameter;
                uint _11533_dummy_parameter;
                float4 _15032;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11502_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11533_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _15032 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _15032 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _15031 = _15032;
            }
            else
            {
                _15031 = 1.0f.xxxx;
            }
            bool _5632;
            if (_9971)
            {
                bool _11562 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
                bool _11568;
                if (_11562)
                {
                    _11568 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
                }
                else
                {
                    _11568 = _11562;
                }
                _5632 = _11568;
            }
            else
            {
                _5632 = _9971;
            }
            bool _5638;
            if (_9971)
            {
                bool _11573 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
                bool _11579;
                if (_11573)
                {
                    _11579 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
                }
                else
                {
                    _11579 = _11573;
                }
                _5638 = _11579;
            }
            else
            {
                _5638 = _9971;
            }
            bool _5644;
            if (_10003)
            {
                bool _11584 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                bool _11590;
                if (_11584)
                {
                    _11590 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                }
                else
                {
                    _11590 = _11584;
                }
                _5644 = _11590;
            }
            else
            {
                _5644 = _10003;
            }
            bool _5650;
            if (_10003)
            {
                bool _11595 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                bool _11601;
                if (_11595)
                {
                    _11601 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                }
                else
                {
                    _11601 = _11595;
                }
                _5650 = _11601;
            }
            else
            {
                _5650 = _10003;
            }
            bool _5653 = _5644 != _5650;
            bool _5659;
            if (_5653)
            {
                _5659 = _5632 || _5638;
            }
            else
            {
                _5659 = _5653;
            }
            float4 _15134;
            if (_5659)
            {
                float4 _14108 = _15031;
                _14108.z = 0.0f;
                _14108.w = 0.0f;
                _15134 = _14108;
            }
            else
            {
                _15134 = _15031;
            }
            bool _5666 = _5632 && _5578;
            bool _5669 = _5638 && _5581;
            float4 _15239;
            float3 _16275;
            if (_5666 || _5669)
            {
                float _15129;
                do
                {
                    uint4 _11740 = r_warped_motion_qdata_tp1.Load(int3(_14464, 0));
                    uint _11741 = _11740.x;
                    if (_11741 != 0u)
                    {
                        float _15128;
                        if (_11741 == 0u)
                        {
                            _15128 = -1.0f;
                        }
                        else
                        {
                            _15128 = float((_11741 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15129 = _15128;
                        break;
                    }
                    int _15111;
                    uint _15112;
                    _15112 = _11741;
                    _15111 = -1;
                    uint _15127;
                    for (; _15111 <= 1; _15112 = _15127, _15111++)
                    {
                        _15127 = _15112;
                        for (int _15125 = -1; _15125 <= 1; )
                        {
                            _15127 = max(_15127, r_warped_motion_qdata_tp1.Load(int3(clamp(_14464 + int2(_15125, _15111), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15125++;
                            continue;
                        }
                    }
                    if (_15112 != 0u)
                    {
                        float _15124;
                        if (_15112 == 0u)
                        {
                            _15124 = -1.0f;
                        }
                        else
                        {
                            _15124 = float((_15112 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15129 = _15124;
                        break;
                    }
                    uint _15114;
                    _15114 = 4294967295u;
                    uint _17310;
                    for (int _15113 = 0; _15113 < 8; _15114 = _17310, _15113++)
                    {
                        int _15117 = 0;
                        for (;;)
                        {
                            if (_15117 < 5)
                            {
                                int2 _11691 = _14464 + (_1192[_15113] * _1201[_15117].xx);
                                bool _11694 = any(bool2(_11691.x < int2(0, 0).x, _11691.y < int2(0, 0).y));
                                bool _11702;
                                if (!_11694)
                                {
                                    _11702 = any(bool2(_11691.x >= cbFI_MvDepthLaneSize.x, _11691.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11702 = _11694;
                                }
                                if (_11702)
                                {
                                    _17310 = _15114;
                                    break;
                                }
                                uint4 _11780 = r_warped_motion_qdata_tp1.Load(int3(_11691, 0));
                                uint _11781 = _11780.x;
                                if (_11781 != 0u)
                                {
                                    _17310 = min(_15114, _11781);
                                    break;
                                }
                                _15117++;
                                continue;
                            }
                            else
                            {
                                _17310 = _15114;
                                break;
                            }
                        }
                    }
                    float _15116;
                    if (_15114 == 4294967295u)
                    {
                        _15116 = -1.0f;
                    }
                    else
                    {
                        float _15115;
                        if (_15114 == 0u)
                        {
                            _15115 = -1.0f;
                        }
                        else
                        {
                            _15115 = float((_15114 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15116 = _15115;
                    }
                    _15129 = _15116;
                    break;
                } while(false);
                bool _5677 = _15129 < 0.0f;
                float _15130;
                if (_5677)
                {
                    _15130 = 0.0f;
                }
                else
                {
                    _15130 = _15129 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11802_dummy_parameter;
                uint _11834_dummy_parameter;
                float4 _15167;
                if ((_5677 && _5666) && _5669)
                {
                    uint _11866_dummy_parameter;
                    float _11890 = log((r_depth_tm1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11866_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11898_dummy_parameter;
                    float _11922 = log((r_depth_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11898_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _15168;
                    if (_11890 > (_11922 + 0.07999999821186065673828125f))
                    {
                        float4 _14112 = _15134;
                        _14112.x = 0.0f;
                        _15168 = _14112;
                    }
                    else
                    {
                        float4 _15169;
                        if (_11922 > (_11890 + 0.07999999821186065673828125f))
                        {
                            float4 _14114 = _15134;
                            _14114.y = 0.0f;
                            _15169 = _14114;
                        }
                        else
                        {
                            _15169 = _15134;
                        }
                        _15168 = _15169;
                    }
                    _15167 = _15168;
                }
                else
                {
                    _15167 = _15134;
                }
                float _5729 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5731 = _15129 >= 0.0f;
                float _15150;
                if (_5731)
                {
                    _15150 = _15129 - _5729;
                }
                else
                {
                    float _15146;
                    if (_5666)
                    {
                        float _15145;
                        _15145 = 2.0f;
                        float _11980;
                        for (int _15144 = 0; _15144 < 24; _15145 = _11980, _15144++)
                        {
                            float _11944 = float(_15144 & 7) * 0.785398185253143310546875f;
                            int _11946 = _15144 >> 3;
                            int _15147;
                            if (_11946 == 0)
                            {
                                _15147 = 16;
                            }
                            else
                            {
                                _15147 = (_11946 == 1) ? 48 : 96;
                            }
                            uint _11996_dummy_parameter;
                            _11980 = min(_15145, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14243 + ((cbFI_MvDepthLaneSizeRcp * float(_15147)) * float2(cos(_11944), sin(_11944))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11996_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15146 = _15145;
                    }
                    else
                    {
                        _15146 = 0.0f;
                    }
                    _15150 = _15146;
                }
                float _15157;
                if (_5731)
                {
                    _15157 = _15129 - _5729;
                }
                else
                {
                    float _15153;
                    if (_5669)
                    {
                        float _15152;
                        _15152 = 2.0f;
                        float _12094;
                        for (int _15151 = 0; _15151 < 24; _15152 = _12094, _15151++)
                        {
                            float _12058 = float(_15151 & 7) * 0.785398185253143310546875f;
                            int _12060 = _15151 >> 3;
                            int _15154;
                            if (_12060 == 0)
                            {
                                _15154 = 16;
                            }
                            else
                            {
                                _15154 = (_12060 == 1) ? 48 : 96;
                            }
                            uint _12126_dummy_parameter;
                            _12094 = min(_15152, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14245 + ((cbFI_MvDepthLaneSizeRcp * float(_15154)) * float2(cos(_12058), sin(_12058))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12126_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15153 = _15152;
                    }
                    else
                    {
                        _15153 = 0.0f;
                    }
                    _15157 = _15153;
                }
                float _15158;
                if (_5666)
                {
                    uint _12158_dummy_parameter;
                    _15158 = r_depth_tm1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12158_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15158 = 0.0f;
                }
                float _15159;
                if (_5669)
                {
                    uint _12177_dummy_parameter;
                    _15159 = r_depth_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12177_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15159 = 0.0f;
                }
                bool _5786;
                if (_5666)
                {
                    _5786 = _15158 > ((exp((_15150 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5786 = _5666;
                }
                float4 _15175;
                if (_5786)
                {
                    float4 _14116 = _15167;
                    _14116.x = 0.0f;
                    _15175 = _14116;
                }
                else
                {
                    _15175 = _15167;
                }
                bool _5798;
                if (_5669)
                {
                    _5798 = _15159 > ((exp((_15157 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5798 = _5669;
                }
                float4 _15177;
                if (_5798)
                {
                    float4 _14118 = _15175;
                    _14118.y = 0.0f;
                    _15177 = _14118;
                }
                else
                {
                    _15177 = _15175;
                }
                float4 _15240;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5731)
                {
                    bool _5818;
                    if (_5666)
                    {
                        _5818 = _15158 < ((exp((_15150 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5818 = _5666;
                    }
                    float4 _15179;
                    if (_5818)
                    {
                        float4 _14120 = _15177;
                        _14120.x = 0.0f;
                        _15179 = _14120;
                    }
                    else
                    {
                        _15179 = _15177;
                    }
                    bool _5830;
                    if (_5669)
                    {
                        _5830 = _15159 < ((exp((_15157 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5830 = _5669;
                    }
                    float4 _15241;
                    if (_5830)
                    {
                        float4 _14122 = _15179;
                        _14122.y = 0.0f;
                        _15241 = _14122;
                    }
                    else
                    {
                        _15241 = _15179;
                    }
                    _15240 = _15241;
                }
                else
                {
                    _15240 = _15177;
                }
                _16275 = float3(_15130, log((r_depth_tm1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11802_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_14245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11834_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _15239 = _15240;
            }
            else
            {
                _16275 = float3(0.0f, 0.0f, 0.5f);
                _15239 = _15134;
            }
            bool _5841 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5590;
            bool _5847;
            if (_5841)
            {
                _5847 = _5644 || _5650;
            }
            else
            {
                _5847 = _5841;
            }
            float4 _15282;
            if (_5847)
            {
                float _15234;
                do
                {
                    uint4 _12356 = r_warped_motion_qdata_tp1.Load(int3(_14464, 0));
                    uint _12357 = _12356.x;
                    if (_12357 != 0u)
                    {
                        float _15233;
                        if (_12357 == 0u)
                        {
                            _15233 = -1.0f;
                        }
                        else
                        {
                            _15233 = float((_12357 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15234 = _15233;
                        break;
                    }
                    int _15216;
                    uint _15217;
                    _15217 = _12357;
                    _15216 = -1;
                    uint _15232;
                    for (; _15216 <= 1; _15217 = _15232, _15216++)
                    {
                        _15232 = _15217;
                        for (int _15230 = -1; _15230 <= 1; )
                        {
                            _15232 = max(_15232, r_warped_motion_qdata_tp1.Load(int3(clamp(_14464 + int2(_15230, _15216), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15230++;
                            continue;
                        }
                    }
                    if (_15217 != 0u)
                    {
                        float _15229;
                        if (_15217 == 0u)
                        {
                            _15229 = -1.0f;
                        }
                        else
                        {
                            _15229 = float((_15217 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15234 = _15229;
                        break;
                    }
                    uint _15219;
                    _15219 = 4294967295u;
                    uint _17311;
                    for (int _15218 = 0; _15218 < 8; _15219 = _17311, _15218++)
                    {
                        int _15222 = 0;
                        for (;;)
                        {
                            if (_15222 < 5)
                            {
                                int2 _12307 = _14464 + (_1192[_15218] * _1201[_15222].xx);
                                bool _12310 = any(bool2(_12307.x < int2(0, 0).x, _12307.y < int2(0, 0).y));
                                bool _12318;
                                if (!_12310)
                                {
                                    _12318 = any(bool2(_12307.x >= cbFI_MvDepthLaneSize.x, _12307.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12318 = _12310;
                                }
                                if (_12318)
                                {
                                    _17311 = _15219;
                                    break;
                                }
                                uint4 _12396 = r_warped_motion_qdata_tp1.Load(int3(_12307, 0));
                                uint _12397 = _12396.x;
                                if (_12397 != 0u)
                                {
                                    _17311 = min(_15219, _12397);
                                    break;
                                }
                                _15222++;
                                continue;
                            }
                            else
                            {
                                _17311 = _15219;
                                break;
                            }
                        }
                    }
                    float _15221;
                    if (_15219 == 4294967295u)
                    {
                        _15221 = -1.0f;
                    }
                    else
                    {
                        float _15220;
                        if (_15219 == 0u)
                        {
                            _15220 = -1.0f;
                        }
                        else
                        {
                            _15220 = float((_15219 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15221 = _15220;
                    }
                    _15234 = _15221;
                    break;
                } while(false);
                float4 _15283;
                if (_15234 >= 0.0f)
                {
                    float _12418 = (exp((_15234 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5866;
                    if (_5644)
                    {
                        uint _12425_dummy_parameter;
                        _5866 = r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12425_dummy_parameter))))), 0)).x > _12418;
                    }
                    else
                    {
                        _5866 = _5644;
                    }
                    float4 _15252;
                    if (_5866)
                    {
                        float4 _14124 = _15239;
                        _14124.z = 0.0f;
                        _15252 = _14124;
                    }
                    else
                    {
                        _15252 = _15239;
                    }
                    bool _5878;
                    if (_5650)
                    {
                        uint _12444_dummy_parameter;
                        _5878 = r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12444_dummy_parameter))))), 0)).x > _12418;
                    }
                    else
                    {
                        _5878 = _5650;
                    }
                    float4 _15284;
                    if (_5878)
                    {
                        float4 _14126 = _15252;
                        _14126.w = 0.0f;
                        _15284 = _14126;
                    }
                    else
                    {
                        _15284 = _15252;
                    }
                    _15283 = _15284;
                }
                else
                {
                    _15283 = _15239;
                }
                _15282 = _15283;
            }
            else
            {
                _15282 = _15239;
            }
            bool _5886 = _5632 != _5638;
            bool _5893;
            if (_5886)
            {
                _5893 = _5632 ? _5578 : _5581;
            }
            else
            {
                _5893 = _5886;
            }
            bool _5900;
            if (_5893)
            {
                _5900 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5900 = _5893;
            }
            float4 _15385;
            if (_5900)
            {
                bool2 _5905 = _5632.xx;
                float2 _5906 = float2(_5905.x ? _14243.x : _14245.x, _5905.y ? _14243.y : _14245.y);
                float _15266;
                if (_5632)
                {
                    uint _12463_dummy_parameter;
                    _15266 = r_depth_tm1.Load(int3(int2(floor(_5906 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12463_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12479_dummy_parameter;
                    _15266 = r_depth_tp1.Load(int3(int2(floor(_5906 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12479_dummy_parameter))))), 0)).x;
                }
                float4x4 _15273;
                if (_5632)
                {
                    float4x4 _15262;
                    do
                    {
                        float4x4 _12493;
                        bool _15261;
                        do
                        {
                            _12493 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15261 = false;
                                break;
                            }
                            uint _12527 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12527 + 32u) * 4 + 0) != 1u)
                            {
                                _15261 = false;
                                break;
                            }
                            uint _15258;
                            _15258 = 0u;
                            for (; _15258 < 4u; _15258++)
                            {
                                for (uint _15259 = 0u; _15259 < 4u; )
                                {
                                    _12493[_15258][_15259] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12527 + 16u) + (_15258 * 4u)) + _15259) * 4 + 0));
                                    _15259++;
                                    continue;
                                }
                            }
                            _15261 = true;
                            break;
                        } while(false);
                        if (_15261)
                        {
                            _15262 = _12493;
                            break;
                        }
                        _15262 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15273 = _15262;
                }
                else
                {
                    float4x4 _15257;
                    do
                    {
                        float4x4 _12599;
                        bool _15256;
                        do
                        {
                            _12599 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15256 = false;
                                break;
                            }
                            uint _12633 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12633 + 32u) * 4 + 0) != 1u)
                            {
                                _15256 = false;
                                break;
                            }
                            uint _15253;
                            _15253 = 0u;
                            for (; _15253 < 4u; _15253++)
                            {
                                for (uint _15254 = 0u; _15254 < 4u; )
                                {
                                    _12599[_15253][_15254] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12633 + (_15253 * 4u)) + _15254) * 4 + 0));
                                    _15254++;
                                    continue;
                                }
                            }
                            _15256 = true;
                            break;
                        } while(false);
                        if (_15256)
                        {
                            _15257 = _12599;
                            break;
                        }
                        _15257 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15273 = _15257;
                }
                float2 _15274;
                do
                {
                    float _12710 = _5906.x;
                    float _12713 = 1.0f - _5906.y;
                    float4 _12724 = mul(float4((float2(_12710, _12713) * 2.0f) - 1.0f.xx, _15266, 1.0f), _15273);
                    float _12726 = _12724.w;
                    if (!(_12726 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15274 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12739 = ((_12724.xy / _12726.xx) + 1.0f.xx) * 0.5f;
                    _15274 = float2(_12739.x - _12710, _12713 - _12739.y);
                    break;
                } while(false);
                float2 _5936 = float2(cbFI_DisplaySize);
                float4 _15386;
                if (!(length(((_5906 + _15274) - float2(_5905.x ? _14245.x : _14243.x, _5905.y ? _14245.y : _14243.y)) * _5936) <= ((0.100000001490116119384765625f * length(_15274 * _5936)) + 8.0f)))
                {
                    float4 _15387;
                    if (_5632)
                    {
                        float4 _14136 = _15282;
                        _14136.x = 0.0f;
                        _15387 = _14136;
                    }
                    else
                    {
                        float4 _14138 = _15282;
                        _14138.y = 0.0f;
                        _15387 = _14138;
                    }
                    _15386 = _15387;
                }
                else
                {
                    _15386 = _15282;
                }
                _15385 = _15386;
            }
            else
            {
                _15385 = _15282;
            }
            float4 _5961 = _14996 * _15385;
            float _5963 = dot(_5961, 1.0f.xxxx);
            float4 _15727;
            bool _16033;
            if (_5963 > 0.0f)
            {
                _16033 = _14687;
                _15727 = _5961 / _5963.xxxx;
            }
            else
            {
                bool _5974 = any(bool4(_15385.x < 1.0f.xxxx.x, _15385.y < 1.0f.xxxx.y, _15385.z < 1.0f.xxxx.z, _15385.w < 1.0f.xxxx.w));
                if (_5974)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12761;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12761);
                    }
                }
                bool4 _17346 = _5974.xxxx;
                _16033 = _5974 ? true : _14687;
                _15727 = float4(_17346.x ? 0.0f.xxxx.x : _14996.x, _17346.y ? 0.0f.xxxx.y : _14996.y, _17346.z ? 0.0f.xxxx.z : _14996.z, _17346.w ? 0.0f.xxxx.w : _14996.w);
            }
            _16166 = _16275;
            _16032 = _16033;
            _15726 = _15727;
        }
        else
        {
            _16166 = float3(0.0f, 0.0f, 0.5f);
            _16032 = _14687;
            _15726 = _14996;
        }
        uint _5983 = (cbFI_pad0 >> 24u) & 31u;
        uint _5987 = (cbFI_pad0 >> 16u) & 255u;
        bool _5989 = _5983 != 0u;
        bool _5991 = _5987 == 12u;
        bool _5994 = _5987 == 13u;
        float4 _15747;
        if ((_5989 || _5991) || _5994)
        {
            float _15393;
            do
            {
                bool _12845 = all(bool2(_14246.x > 0.0f.xx.x, _14246.y > 0.0f.xx.y));
                bool _12851;
                if (_12845)
                {
                    _12851 = all(bool2(_14246.x < 1.0f.xx.x, _14246.y < 1.0f.xx.y));
                }
                else
                {
                    _12851 = _12845;
                }
                bool _12782 = !_12851;
                bool _12789;
                if (!_12782)
                {
                    bool _12856 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
                    bool _12862;
                    if (_12856)
                    {
                        _12862 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12862 = _12856;
                    }
                    _12789 = !_12862;
                }
                else
                {
                    _12789 = _12782;
                }
                if (_12789)
                {
                    _15393 = 0.0f;
                    break;
                }
                uint _12869_dummy_parameter;
                uint _12885_dummy_parameter;
                float4x4 _15392;
                do
                {
                    float4x4 _12899;
                    bool _15391;
                    do
                    {
                        _12899 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15391 = false;
                            break;
                        }
                        uint _12933 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12933 + 32u) * 4 + 0) != 1u)
                        {
                            _15391 = false;
                            break;
                        }
                        uint _15388;
                        _15388 = 0u;
                        for (; _15388 < 4u; _15388++)
                        {
                            for (uint _15389 = 0u; _15389 < 4u; )
                            {
                                _12899[_15388][_15389] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12933 + 16u) + (_15388 * 4u)) + _15389) * 4 + 0));
                                _15389++;
                                continue;
                            }
                        }
                        _15391 = true;
                        break;
                    } while(false);
                    if (_15391)
                    {
                        _15392 = _12899;
                        break;
                    }
                    _15392 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12810 = mul(float4((float2(_14246.x, 1.0f - _14246.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14246 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12869_dummy_parameter))))), 0)).x, 1.0f), _15392);
                float _12812 = _12810.w;
                if (abs(_12812) < 9.9999999747524270787835121154785e-07f)
                {
                    _15393 = 0.0f;
                    break;
                }
                float _12823 = abs(cbFI_DeviceToViewDepth.y / ((_12810.z / _12812) - cbFI_DeviceToViewDepth.x));
                float _12826 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12885_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15393 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12823 - _12826) / max(max(_12823, _12826), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _13035 = all(bool2(_14247.x > 0.0f.xx.x, _14247.y > 0.0f.xx.y));
            bool _13041;
            if (_13035)
            {
                _13041 = all(bool2(_14247.x < 1.0f.xx.x, _14247.y < 1.0f.xx.y));
            }
            else
            {
                _13041 = _13035;
            }
            float _15394;
            if (_13041)
            {
                uint _13048_dummy_parameter;
                _15394 = length((_6869 + (r_motion_tp1.Load(int3(int2(floor(_14247 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13048_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15394 = 1000000.0f;
            }
            float _15409;
            if ((_5983 & 1u) != 0u)
            {
                _15409 = _15393;
            }
            else
            {
                _15409 = 1.0f;
            }
            float _15410;
            if ((_5983 & 2u) != 0u)
            {
                _15410 = _15409 * (1.0f - smoothstep(2.0f, 8.0f, _15394));
            }
            else
            {
                _15410 = _15409;
            }
            float _15411;
            if ((_5983 & 4u) != 0u)
            {
                _15411 = _15410 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7590 - _7598) - length(_7574 - _7582))));
            }
            else
            {
                _15411 = _15410;
            }
            float _15741;
            if ((_5983 & 8u) != 0u)
            {
                _15741 = lerp(1.0f, _15411, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7574 - _7582)));
            }
            else
            {
                _15741 = _15411;
            }
            bool _6069 = (_5983 & 16u) != 0u;
            bool _6078;
            if (_6069)
            {
                _6078 = length(_14241 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6078 = _6069;
            }
            float _17348 = _6078 ? 1.0f : _15741;
            bool _6084 = _5989 && _9971;
            bool _6089;
            if (_6084)
            {
                bool _13073 = all(bool2(_14243.x > 0.0f.xx.x, _14243.y > 0.0f.xx.y));
                bool _13079;
                if (_13073)
                {
                    _13079 = all(bool2(_14243.x < 1.0f.xx.x, _14243.y < 1.0f.xx.y));
                }
                else
                {
                    _13079 = _13073;
                }
                _6089 = _13079;
            }
            else
            {
                _6089 = _6084;
            }
            bool _6094;
            if (_6089)
            {
                bool _13084 = all(bool2(_14245.x > 0.0f.xx.x, _14245.y > 0.0f.xx.y));
                bool _13090;
                if (_13084)
                {
                    _13090 = all(bool2(_14245.x < 1.0f.xx.x, _14245.y < 1.0f.xx.y));
                }
                else
                {
                    _13090 = _13084;
                }
                _6094 = _13090;
            }
            else
            {
                _6094 = _6089;
            }
            float4 _15748;
            if (_6094)
            {
                float _6100 = _15726.x + _15726.y;
                float _6109 = (_15726.z + _15726.w) * (1.0f - _17348);
                float _15744;
                if (_6100 > 9.9999997473787516355514526367188e-06f)
                {
                    _15744 = _15726.x / _6100;
                }
                else
                {
                    _15744 = _4839;
                }
                _15748 = float4(_15726.x + (_6109 * _15744), _15726.y + (_6109 * (1.0f - _15744)), _15726.zw * _17348);
            }
            else
            {
                _15748 = _15726;
            }
            _15747 = _15748;
        }
        else
        {
            _15747 = _15726;
        }
        float3 _6170 = (((_7574 * _15747.x) + (_7582 * _15747.y)) + (_7590 * _15747.z)) + (_7598 * _15747.w);
        float3 _17111;
        if (_4855 && (_15762 > 0.0f))
        {
            uint _13097_dummy_parameter;
            float2 _13112 = r_motion_tp1.Load(int3(int2(floor(_4614 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13097_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _16024;
            if (_6897)
            {
                float2 _13157 = clamp((((_14220 + (_13112 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13160 = tan(_13157.x);
                _16024 = (float2(_13160 / cbFI_DeviceToViewDepth.z, (tan(_13157.y) * sqrt(1.0f + (_13160 * _13160))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _16024 = _14220 + (_13112 * cbFI_Timestep);
            }
            float2 _16025;
            if (_6897)
            {
                float2 _13236 = clamp((((_14220 + (_13112 * _4829)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13239 = tan(_13236.x);
                _16025 = (float2(_13239 / cbFI_DeviceToViewDepth.z, (tan(_13236.y) * sqrt(1.0f + (_13239 * _13239))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _16025 = _14220 + (_13112 * _4829);
            }
            _17111 = lerp(_6170, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _16024, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _16025, 0.0f).xyz, cbFI_Timestep.xxx), _15762.xxx);
        }
        else
        {
            _17111 = _6170;
        }
        float3 _17110;
        if (_16032)
        {
            float3 _13281 = r_current_interpolation_source.Load(int3(_4137, 0)).xyz;
            float3 _17112;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9971)
            {
                uint _13288_dummy_parameter;
                float _16155;
                _16155 = r_depth_tm1.Load(int3(int2(floor(_14243 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13288_dummy_parameter))))), 0)).x;
                float _6251;
                for (int _16154 = 0; _16154 < 24; _16155 = _6251, _16154++)
                {
                    float _6223 = float(_16154 & 7) * 0.785398185253143310546875f;
                    int _6225 = _16154 >> 3;
                    int _17164;
                    if (_6225 == 0)
                    {
                        _17164 = 16;
                    }
                    else
                    {
                        _17164 = (_6225 == 1) ? 48 : 96;
                    }
                    uint _13308_dummy_parameter;
                    _6251 = min(_16155, r_depth_tm1.Load(int3(int2(floor(clamp(_14243 + ((cbFI_MvDepthLaneSizeRcp * float(_17164)) * float2(cos(_6223), sin(_6223))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13308_dummy_parameter))))), 0)).x);
                }
                float2 _16156;
                do
                {
                    float _13330 = 1.0f - _14243.y;
                    float4 _13341 = mul(float4((float2(_14243.x, _13330) * 2.0f) - 1.0f.xx, _16155, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13343 = _13341.w;
                    if (!(_13343 > 9.9999999747524270787835121154785e-07f))
                    {
                        _16156 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13356 = ((_13341.xy / _13343.xx) + 1.0f.xx) * 0.5f;
                    _16156 = float2(_13356.x - _14243.x, _13330 - _13356.y);
                    break;
                } while(false);
                float2 _6262 = _14243 + _16156;
                bool _13374 = all(bool2(_6262.x > 0.0f.xx.x, _6262.y > 0.0f.xx.y));
                bool _13380;
                if (_13374)
                {
                    _13380 = all(bool2(_6262.x < 1.0f.xx.x, _6262.y < 1.0f.xx.y));
                }
                else
                {
                    _13380 = _13374;
                }
                float3 _17113;
                if (_13380)
                {
                    float _6268 = abs(cbFI_DeviceToViewDepth.y / (_16155 - cbFI_DeviceToViewDepth.x));
                    uint _13400_dummy_parameter;
                    int2 _13400 = int2(spvTextureSize(r_depth_m2, uint(0), _13400_dummy_parameter));
                    float _6272 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6262 * float2(_13400))), int2(0, 0), _13400 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _17118;
                    if (abs(_6272 - _6268) <= (0.20000000298023223876953125f * max(_6272, _6268)))
                    {
                        uint _13434_dummy_parameter;
                        int2 _13434 = int2(spvTextureSize(r_colour_m2, uint(0), _13434_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13457;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13457);
                        }
                        _17118 = r_colour_m2.Load(int3(clamp(int2(floor(_6262 * float2(_13434))), int2(0, 0), _13434 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13467;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13467);
                        }
                        _17118 = _13281;
                    }
                    _17113 = _17118;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13477;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13477);
                    }
                    _17113 = _13281;
                }
                _17112 = _17113;
            }
            else
            {
                _17112 = _13281;
            }
            _17110 = _17112;
        }
        else
        {
            _17110 = _17111;
        }
        uint _6300 = cbFI_pad0 & 255u;
        bool _16984;
        float3 _17109;
        if (_6300 != 0u)
        {
            float3 _6305 = r_present_backbuffer.Load(int3(_4137, 0)).xyz;
            float3 _6309 = r_current_interpolation_source.Load(int3(_4137, 0)).xyz;
            float3 _6313 = abs(_6305 - _6309);
            float3 _16159;
            if (_6300 == 2u)
            {
                _16159 = (abs(_6309) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _16159 = 0.000244140625f.xxx;
            }
            bool _6329 = any(bool3(_6313.x > _16159.x, _6313.y > _16159.y, _6313.z > _16159.z));
            bool3 _17349 = _6329.xxx;
            _17109 = float3(_17349.x ? _6305.x : _17110.x, _17349.y ? _6305.y : _17110.y, _17349.z ? _6305.z : _17110.z);
            _16984 = _6329;
        }
        else
        {
            _17109 = _17110;
            _16984 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13492;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13492);
        }
        float3 _17091;
        if (_5987 == 1u)
        {
            _17091 = lerp(_7574, _7582, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _17092;
            if (_5987 == 2u)
            {
                _17092 = lerp(_7590, _7598, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _17093;
                if (_5987 == 3u)
                {
                    _17093 = float(_16984).xxx;
                }
                else
                {
                    float3 _17094;
                    if (_5987 == 4u)
                    {
                        _17094 = float3(((_14241 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _17095;
                        if (_5987 == 5u)
                        {
                            _17095 = float3(((_6869 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _17096;
                            if (_5987 == 6u)
                            {
                                _17096 = float3(_15747.xy, _15747.z + _15747.w);
                            }
                            else
                            {
                                float3 _17097;
                                if (_5987 == 7u)
                                {
                                    _17097 = r_current_interpolation_source.Load(int3(_4137, 0)).xyz;
                                }
                                else
                                {
                                    float3 _17098;
                                    if (_5987 == 8u)
                                    {
                                        _17098 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4614, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _17099;
                                        if (_5991)
                                        {
                                            uint _13514_dummy_parameter;
                                            uint _13546_dummy_parameter;
                                            _17099 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4614 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13514_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4614 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13546_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _17100;
                                            if (_5994)
                                            {
                                                _17100 = _7590;
                                            }
                                            else
                                            {
                                                float3 _17101;
                                                if (_5987 == 20u)
                                                {
                                                    _17101 = _7574;
                                                }
                                                else
                                                {
                                                    float3 _17102;
                                                    if (_5987 == 21u)
                                                    {
                                                        _17102 = _7582;
                                                    }
                                                    else
                                                    {
                                                        float3 _17103;
                                                        if (_5987 == 22u)
                                                        {
                                                            _17103 = _7598;
                                                        }
                                                        else
                                                        {
                                                            float3 _17104;
                                                            if (_5987 == 18u)
                                                            {
                                                                _17104 = _16632;
                                                            }
                                                            else
                                                            {
                                                                float3 _17105;
                                                                if (_5987 == 19u)
                                                                {
                                                                    _17105 = _16396;
                                                                }
                                                                else
                                                                {
                                                                    float3 _17106;
                                                                    if (_5987 == 23u)
                                                                    {
                                                                        _17106 = _16166;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _17107;
                                                                        if (_5987 == 24u)
                                                                        {
                                                                            uint _6473 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _6478 = float(rw_nfru_diagnostics.Load<uint>((_6473 + 35u) * 4 + 0));
                                                                            float _16160;
                                                                            if (_6478 > 0.0f)
                                                                            {
                                                                                _16160 = float(rw_nfru_diagnostics.Load<uint>((_6473 + 34u) * 4 + 0)) / _6478;
                                                                            }
                                                                            else
                                                                            {
                                                                                _16160 = 0.0f;
                                                                            }
                                                                            _17107 = float3(float(rw_nfru_diagnostics.Load<uint>((_6473 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_6473 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _16160);
                                                                        }
                                                                        else
                                                                        {
                                                                            _17107 = _17109;
                                                                        }
                                                                        _17106 = _17107;
                                                                    }
                                                                    _17105 = _17106;
                                                                }
                                                                _17104 = _17105;
                                                            }
                                                            _17103 = _17104;
                                                        }
                                                        _17102 = _17103;
                                                    }
                                                    _17101 = _17102;
                                                }
                                                _17100 = _17101;
                                            }
                                            _17099 = _17100;
                                        }
                                        _17098 = _17099;
                                    }
                                    _17097 = _17098;
                                }
                                _17096 = _17097;
                            }
                            _17095 = _17096;
                        }
                        _17094 = _17095;
                    }
                    _17093 = _17094;
                }
                _17092 = _17093;
            }
            _17091 = _17092;
        }
        float3 _17090;
        if ((_5987 >= 9u) && (_5987 <= 11u))
        {
            uint _6538 = 64u + uint((_14464.y * cbFI_MvDepthLaneSize.x) + _14464.x);
            uint _6542 = rw_nfru_diagnostics.Load<uint>(_6538 * 4 + 0) & 15u;
            float3 _17123;
            if (_5987 == 10u)
            {
                float3 _17089;
                if ((rw_nfru_diagnostics.Load<uint>(_6538 * 4 + 0) & 32u) != 0u)
                {
                    _17089 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _17088;
                    if ((rw_nfru_diagnostics.Load<uint>(_6538 * 4 + 0) & 16u) != 0u)
                    {
                        _17088 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6563 = ((rw_nfru_diagnostics.Load<uint>(_6538 * 4 + 0) & 64u) != 0u).xxx;
                        _17088 = float3(_6563.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6563.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6563.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _17089 = _17088;
                }
                _17123 = _17089;
            }
            else
            {
                float3 _17124;
                if (_5987 == 11u)
                {
                    uint _6576 = (rw_nfru_diagnostics.Load<uint>(_6538 * 4 + 0) >> 8u) & 15u;
                    uint _6579 = (rw_nfru_diagnostics.Load<uint>(_6538 * 4 + 0) >> 12u) & 15u;
                    float3 _17081;
                    if ((_6542 == 2u) || (_6542 == 3u))
                    {
                        _17081 = _3833[_6542];
                    }
                    else
                    {
                        bool _6591 = _6576 == 3u;
                        bool _6593 = _6579 == 3u;
                        float3 _17082;
                        if (_6591 && _6593)
                        {
                            _17082 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _17083;
                            if (_6591)
                            {
                                _17083 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _17084;
                                if (_6593)
                                {
                                    _17084 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _17085;
                                    if ((_6576 == 4u) || (_6579 == 4u))
                                    {
                                        _17085 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _17086;
                                        if ((_6576 == 1u) || (_6579 == 1u))
                                        {
                                            _17086 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17351 = (_6542 == 1u).xxx;
                                            _17086 = float3(_17351.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17351.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17351.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _17085 = _17086;
                                    }
                                    _17084 = _17085;
                                }
                                _17083 = _17084;
                            }
                            _17082 = _17083;
                        }
                        _17081 = _17082;
                    }
                    _17124 = _17081;
                }
                else
                {
                    _17124 = _3833[min(_6542, 7u)];
                }
                _17123 = _17124;
            }
            _17090 = _17123;
        }
        else
        {
            _17090 = _17091;
        }
        float4 _17127;
        if ((_5987 >= 14u) && (_5987 <= 16u))
        {
            float2 _17125;
            if (_5987 == 14u)
            {
                uint _6649_dummy_parameter;
                uint _6655_dummy_parameter;
                _17125 = r_flow_tm1.Load(int3(clamp(int2(floor(_4614 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6649_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6655_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _17126;
                if (_5987 == 16u)
                {
                    uint _13622 = r_warped_flow_qdata_tm1.Load(int3(_4630, 0)).x & 2147483647u;
                    uint _13654 = uint(max((int((_13622 >> 16u) & 15u) - 6), 0));
                    _17126 = ((float2(float((1 - (2 * int((_13622 >> 15u) & 1u))) * int(((_13622 >> uint(7)) & 127u) << _13654)), float((1 - (2 * int((_13622 >> 14u) & 1u))) * int((_13622 & 127u) << _13654))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _17126 = _6869 * float2(cbFI_DisplaySize);
                }
                _17125 = _17126;
            }
            uint2 _6688 = uint2(clamp(round(_17125 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6690 = _6688.x;
            uint _6697 = _6688.y;
            _17127 = float4(float(_6690 & 255u), float((_6690 >> 8u) | ((_6697 & 15u) << 4u)), float(_6697 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _17128;
            if (_5987 == 17u)
            {
                _17128 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4630, 0)).x != 0u), _5074, 0.0f, 1.0f);
            }
            else
            {
                _17128 = float4(_17090, 1.0f);
            }
            _17127 = _17128;
        }
        rw_output[_4137] = _17127.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6741 = ((uint(_4137.y) * uint(cbFI_DisplaySize.x)) + uint(_4137.x)) * 6u;
            uint _13700 = spvPackHalf2x16(clamp(_7573.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6741 * 4 + 0, (((_13700 & 32767u) >> 4u) | ((((_13700 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7573.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13735 = spvPackHalf2x16(clamp(_7581.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6741 + 1u) * 4 + 0, (((_13735 & 32767u) >> 4u) | ((((_13735 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7581.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13770 = spvPackHalf2x16(clamp(_7589.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6741 + 2u) * 4 + 0, (((_13770 & 32767u) >> 4u) | ((((_13770 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7589.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13805 = spvPackHalf2x16(clamp(_7597.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6741 + 3u) * 4 + 0, (((_13805 & 32767u) >> 4u) | ((((_13805 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7597.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13832 = r_current_interpolation_source.Load(int3(_4137, 0));
            uint _13846 = spvPackHalf2x16(clamp(_13832.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6741 + 4u) * 4 + 0, (((_13846 & 32767u) >> 4u) | ((((_13846 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13832.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _17163;
            if (_16984 || (_5987 != 0u))
            {
                _17163 = 4294967295u;
            }
            else
            {
                uint _13881 = spvPackHalf2x16(clamp(_17127.xy, 0.0f.xx, 65000.0f.xx));
                _17163 = (((_13881 & 32767u) >> 4u) | ((((_13881 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_17127.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6741 + 5u) * 4 + 0, _17163);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4137] = float4(r_current_interpolation_source.Load(int3(_4137, 0)).xyz, 1.0f).xyz;
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
