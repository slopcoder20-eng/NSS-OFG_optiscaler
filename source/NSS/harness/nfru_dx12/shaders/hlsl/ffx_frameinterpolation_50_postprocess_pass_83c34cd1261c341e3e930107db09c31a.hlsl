static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1192[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1201[5] = { 2, 4, 7, 11, 16 };
static const float3 _3834[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4138 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4138.x >= cbFI_DisplaySize.x, _4138.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4138] = float4(r_present_backbuffer.Load(int3(_4138, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4138] = float4(r_current_interpolation_source.Load(int3(_4138, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4615 = (float2(_4138) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4617 = float2(cbFI_MvDepthLaneSize);
        int2 _4626 = int2(floor(_4615 * _4617));
        int2 _4631 = int2(floor(_4615 * float2(cbFI_FlowLaneSize)));
        float4 _6864 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4615 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6870 = r_warped_filled_flow_tm1.Load(int3(_4631, 0)).xy;
        float2 _6876 = r_warped_filled_motion_tp1.Load(int3(_4626, 0)).xy;
        bool _6898 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14229;
        if (_6898)
        {
            float _6911 = ((2.0f * _4615.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14229 = float2(atan(_6911) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4615.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6911 * _6911))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14229 = _4615;
        }
        bool _4652 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14250;
        bool _14392;
        int2 _14473;
        float3 _16641;
        if (_4652)
        {
            float _14231;
            float _14233;
            _14233 = 2.0f;
            _14231 = -1.0f;
            uint _4222[9];
            float _17214;
            float _17217;
            for (int _14230 = 0; _14230 < 9; _14233 = _17217, _14231 = _17214, _14230++)
            {
                _4222[_14230] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4626 + int2((_14230 % 3) - 1, (_14230 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4222[_14230] != 0u)
                {
                    float _17209;
                    if (_4222[_14230] == 0u)
                    {
                        _17209 = -1.0f;
                    }
                    else
                    {
                        _17209 = float((_4222[_14230] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17217 = min(_14233, _17209);
                    _17214 = max(_14231, _17209);
                }
                else
                {
                    _17217 = _14233;
                    _17214 = _14231;
                }
            }
            float _4698 = float(_14231 >= 0.0f);
            float3 _13932 = 0.0f.xxx;
            _13932.y = _4698;
            float2 _14251;
            bool _14393;
            int2 _14474;
            float3 _16642;
            if ((_14231 - _14233) > 0.0199999995529651641845703125f)
            {
                float _14239;
                int2 _14240;
                float2 _14241;
                int2 _14243;
                float2 _14249;
                _14249 = _6876;
                _14243 = _4626;
                _14241 = _6876;
                _14240 = _4626;
                _14239 = -1.0f;
                float _17222;
                int2 _17226;
                float2 _17237;
                int2 _17248;
                float2 _17281;
                float _17328;
                int _14238 = 0;
                float _17190 = 1000000000.0f;
                for (; _14238 < 9; _17190 = _17328, _14249 = _17281, _14243 = _17248, _14241 = _17237, _14240 = _17226, _14239 = _17222, _14238++)
                {
                    if (_4222[_14238] == 0u)
                    {
                        _17328 = _17190;
                        _17281 = _14249;
                        _17248 = _14243;
                        _17237 = _14241;
                        _17226 = _14240;
                        _17222 = _14239;
                        continue;
                    }
                    int2 _4733 = clamp(_4626 + int2((_14238 % 3) - 1, (_14238 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6986 = _4222[_14238] & 2147483647u;
                    uint _7018 = uint(max((int((_6986 >> 16u) & 15u) - 6), 0));
                    float2 _4739 = (float2(float((1 - (2 * int((_6986 >> 15u) & 1u))) * int(((_6986 >> uint(7)) & 127u) << _7018)), float((1 - (2 * int((_6986 >> 14u) & 1u))) * int((_6986 & 127u) << _7018))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _17176;
                    if (_4222[_14238] == 0u)
                    {
                        _17176 = -1.0f;
                    }
                    else
                    {
                        _17176 = float((_4222[_14238] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4744 = _17176 - 0.100000001490116119384765625f;
                    float2 _17177;
                    if (_6898)
                    {
                        float2 _7095 = clamp((((_14229 + (_4739 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7098 = tan(_7095.x);
                        _17177 = (float2(_7098 / cbFI_DeviceToViewDepth.z, (tan(_7095.y) * sqrt(1.0f + (_7098 * _7098))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17177 = _14229 + (_4739 * cbFI_Timestep);
                    }
                    float _4751 = cbFI_Timestep - 1.0f;
                    float2 _17178;
                    if (_6898)
                    {
                        float2 _7166 = clamp((((_14229 + (_4739 * _4751)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7169 = tan(_7166.x);
                        _17178 = (float2(_7169 / cbFI_DeviceToViewDepth.z, (tan(_7166.y) * sqrt(1.0f + (_7169 * _7169))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17178 = _14229 + (_4739 * _4751);
                    }
                    bool _7202 = all(bool2(_17177.x > 0.0f.xx.x, _17177.y > 0.0f.xx.y));
                    bool _7208;
                    if (_7202)
                    {
                        _7208 = all(bool2(_17177.x < 1.0f.xx.x, _17177.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7208 = _7202;
                    }
                    float _17181;
                    if (_7208)
                    {
                        uint _7215_dummy_parameter;
                        _17181 = max((_4744 - (log(((r_depth_tm1.Load(int3(int2(floor(_17177 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7215_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17181 = 0.0f;
                    }
                    bool _7245 = all(bool2(_17178.x > 0.0f.xx.x, _17178.y > 0.0f.xx.y));
                    bool _7251;
                    if (_7245)
                    {
                        _7251 = all(bool2(_17178.x < 1.0f.xx.x, _17178.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7251 = _7245;
                    }
                    float _17182;
                    if (_7251)
                    {
                        uint _7258_dummy_parameter;
                        _17182 = _17181 + max((_4744 - (log(((r_depth_tp1.Load(int3(int2(floor(_17178 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7258_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17182 = _17181;
                    }
                    float _17223;
                    int2 _17227;
                    float2 _17238;
                    int2 _17249;
                    float2 _17282;
                    float _17329;
                    if (_17182 == 0.0f)
                    {
                        bool _4786 = _4744 > _14239;
                        bool2 _17337 = _4786.xx;
                        _17329 = _17190;
                        _17282 = float2(_17337.x ? _4739.x : _14249.x, _17337.y ? _4739.y : _14249.y);
                        _17249 = int2(_17337.x ? _4733.x : _14243.x, _17337.y ? _4733.y : _14243.y);
                        _17238 = _14241;
                        _17227 = _14240;
                        _17223 = _4786 ? _4744 : _14239;
                    }
                    else
                    {
                        bool _4795 = _17182 < _17190;
                        bool2 _17333 = _4795.xx;
                        _17329 = _4795 ? _17182 : _17190;
                        _17282 = _14249;
                        _17249 = _14243;
                        _17238 = float2(_17333.x ? _4739.x : _14241.x, _17333.y ? _4739.y : _14241.y);
                        _17227 = int2(_17333.x ? _4733.x : _14240.x, _17333.y ? _4733.y : _14240.y);
                        _17223 = _14239;
                    }
                    _17328 = _17329;
                    _17281 = _17282;
                    _17248 = _17249;
                    _17237 = _17238;
                    _17226 = _17227;
                    _17222 = _17223;
                }
                bool _4807 = _14239 < 0.0f;
                bool2 _17343 = _4807.xx;
                int2 _17346 = int2(_17343.x ? _14240.x : _14243.x, _17343.y ? _14240.y : _14243.y);
                _16642 = float3(1.0f, _4698, float(any(bool2(_17346.x != _4626.x, _17346.y != _4626.y))));
                _14474 = _17346;
                _14393 = _4807 ? false : true;
                _14251 = float2(_17343.x ? _14241.x : _14249.x, _17343.y ? _14241.y : _14249.y);
            }
            else
            {
                _16642 = _13932;
                _14474 = _4626;
                _14393 = false;
                _14251 = _6876;
            }
            _16641 = _16642;
            _14473 = _14474;
            _14392 = _14393;
            _14250 = _14251;
        }
        else
        {
            _16641 = 0.0f.xxx;
            _14473 = _4626;
            _14392 = false;
            _14250 = _6876;
        }
        float2 _14252;
        if (_6898)
        {
            float2 _7323 = clamp((((_14229 + (_14250 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7326 = tan(_7323.x);
            _14252 = (float2(_7326 / cbFI_DeviceToViewDepth.z, (tan(_7323.y) * sqrt(1.0f + (_7326 * _7326))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14252 = _14229 + (_14250 * cbFI_Timestep);
        }
        float _4830 = cbFI_Timestep - 1.0f;
        float2 _14254;
        if (_6898)
        {
            float2 _7394 = clamp((((_14229 + (_14250 * _4830)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7397 = tan(_7394.x);
            _14254 = (float2(_7397 / cbFI_DeviceToViewDepth.z, (tan(_7394.y) * sqrt(1.0f + (_7397 * _7397))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14254 = _14229 + (_14250 * _4830);
        }
        float _4835 = -cbFI_Timestep;
        float2 _14255;
        if (_6898)
        {
            float2 _7465 = clamp((((_14229 + (_6870 * _4835)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7468 = tan(_7465.x);
            _14255 = (float2(_7468 / cbFI_DeviceToViewDepth.z, (tan(_7465.y) * sqrt(1.0f + (_7468 * _7468))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14255 = _14229 + (_6870 * _4835);
        }
        float _4840 = 1.0f - cbFI_Timestep;
        float2 _14256;
        if (_6898)
        {
            float2 _7536 = clamp((((_14229 + (_6870 * _4840)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7539 = tan(_7536.x);
            _14256 = (float2(_7539 / cbFI_DeviceToViewDepth.z, (tan(_7536.y) * sqrt(1.0f + (_7539 * _7539))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14256 = _14229 + (_6870 * _4840);
        }
        float4 _7574 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14252, 0.0f);
        float3 _7575 = _7574.xyz;
        float4 _7582 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14254, 0.0f);
        float3 _7583 = _7582.xyz;
        float4 _7590 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14255, 0.0f);
        float3 _7591 = _7590.xyz;
        float4 _7598 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14256, 0.0f);
        float3 _7599 = _7598.xyz;
        float4 _7613 = exp(_6864 - max(max(max(_6864.x, _6864.y), _6864.z), _6864.w).xxxx);
        float4 _7620 = _7613 / (dot(_7613, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4856 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14463;
        float _15771;
        if (_4856)
        {
            float2 _4862 = 0.5f.xx / _4617;
            float _4865 = _4862.x;
            float _4866 = -_4865;
            float _4868 = _4862.y;
            float _4869 = -_4868;
            float2 _4871 = _4615 + float2(_4866, _4869);
            float2 _4873 = float2(cbFI_DisplaySize);
            bool _14273;
            do
            {
                bool _7700 = all(bool2(_4871.x > 0.0f.xx.x, _4871.y > 0.0f.xx.y));
                bool _7706;
                if (_7700)
                {
                    _7706 = all(bool2(_4871.x < 1.0f.xx.x, _4871.y < 1.0f.xx.y));
                }
                else
                {
                    _7706 = _7700;
                }
                if (!_7706)
                {
                    _14273 = false;
                    break;
                }
                uint _7713_dummy_parameter;
                float4x4 _14271;
                do
                {
                    float4x4 _7727;
                    bool _14270;
                    do
                    {
                        _7727 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14270 = false;
                            break;
                        }
                        uint _7761 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7761 + 32u) * 4 + 0) != 1u)
                        {
                            _14270 = false;
                            break;
                        }
                        uint _14267;
                        _14267 = 0u;
                        for (; _14267 < 4u; _14267++)
                        {
                            for (uint _14268 = 0u; _14268 < 4u; )
                            {
                                _7727[_14267][_14268] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7761 + (_14267 * 4u)) + _14268) * 4 + 0));
                                _14268++;
                                continue;
                            }
                        }
                        _14270 = true;
                        break;
                    } while(false);
                    if (_14270)
                    {
                        _14271 = _7727;
                        break;
                    }
                    _14271 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14272;
                do
                {
                    float _7838 = _4871.x;
                    float _7841 = 1.0f - _4871.y;
                    float4 _7852 = mul(float4((float2(_7838, _7841) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4871 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7713_dummy_parameter))))), 0)).x, 1.0f), _14271);
                    float _7854 = _7852.w;
                    if (!(_7854 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14272 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7867 = ((_7852.xy / _7854.xx) + 1.0f.xx) * 0.5f;
                    _14272 = float2(_7867.x - _7838, _7841 - _7867.y);
                    break;
                } while(false);
                float2 _7664 = abs(_14272);
                if (any(bool2(_7664.x > 100000.0f.xx.x, _7664.y > 100000.0f.xx.y)))
                {
                    _14273 = false;
                    break;
                }
                float _7672 = length(_14272 * _4873);
                uint _7887_dummy_parameter;
                bool _7686 = _7672 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7693;
                if (_7686)
                {
                    _7693 = length((r_motion_tp1.Load(int3(int2(floor(_4871 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7887_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _7672);
                }
                else
                {
                    _7693 = _7686;
                }
                _14273 = _7693;
                break;
            } while(false);
            float2 _4883 = _4615 + float2(_4865, _4869);
            bool _14280;
            do
            {
                bool _7973 = all(bool2(_4883.x > 0.0f.xx.x, _4883.y > 0.0f.xx.y));
                bool _7979;
                if (_7973)
                {
                    _7979 = all(bool2(_4883.x < 1.0f.xx.x, _4883.y < 1.0f.xx.y));
                }
                else
                {
                    _7979 = _7973;
                }
                if (!_7979)
                {
                    _14280 = false;
                    break;
                }
                uint _7986_dummy_parameter;
                float4x4 _14278;
                do
                {
                    float4x4 _8000;
                    bool _14277;
                    do
                    {
                        _8000 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14277 = false;
                            break;
                        }
                        uint _8034 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8034 + 32u) * 4 + 0) != 1u)
                        {
                            _14277 = false;
                            break;
                        }
                        uint _14274;
                        _14274 = 0u;
                        for (; _14274 < 4u; _14274++)
                        {
                            for (uint _14275 = 0u; _14275 < 4u; )
                            {
                                _8000[_14274][_14275] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8034 + (_14274 * 4u)) + _14275) * 4 + 0));
                                _14275++;
                                continue;
                            }
                        }
                        _14277 = true;
                        break;
                    } while(false);
                    if (_14277)
                    {
                        _14278 = _8000;
                        break;
                    }
                    _14278 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14279;
                do
                {
                    float _8111 = _4883.x;
                    float _8114 = 1.0f - _4883.y;
                    float4 _8125 = mul(float4((float2(_8111, _8114) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4883 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7986_dummy_parameter))))), 0)).x, 1.0f), _14278);
                    float _8127 = _8125.w;
                    if (!(_8127 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14279 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8140 = ((_8125.xy / _8127.xx) + 1.0f.xx) * 0.5f;
                    _14279 = float2(_8140.x - _8111, _8114 - _8140.y);
                    break;
                } while(false);
                float2 _7937 = abs(_14279);
                if (any(bool2(_7937.x > 100000.0f.xx.x, _7937.y > 100000.0f.xx.y)))
                {
                    _14280 = false;
                    break;
                }
                float _7945 = length(_14279 * _4873);
                uint _8160_dummy_parameter;
                bool _7959 = _7945 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7966;
                if (_7959)
                {
                    _7966 = length((r_motion_tp1.Load(int3(int2(floor(_4883 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8160_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _7945);
                }
                else
                {
                    _7966 = _7959;
                }
                _14280 = _7966;
                break;
            } while(false);
            float2 _4896 = _4615 + float2(_4866, _4868);
            bool _14287;
            do
            {
                bool _8246 = all(bool2(_4896.x > 0.0f.xx.x, _4896.y > 0.0f.xx.y));
                bool _8252;
                if (_8246)
                {
                    _8252 = all(bool2(_4896.x < 1.0f.xx.x, _4896.y < 1.0f.xx.y));
                }
                else
                {
                    _8252 = _8246;
                }
                if (!_8252)
                {
                    _14287 = false;
                    break;
                }
                uint _8259_dummy_parameter;
                float4x4 _14285;
                do
                {
                    float4x4 _8273;
                    bool _14284;
                    do
                    {
                        _8273 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14284 = false;
                            break;
                        }
                        uint _8307 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8307 + 32u) * 4 + 0) != 1u)
                        {
                            _14284 = false;
                            break;
                        }
                        uint _14281;
                        _14281 = 0u;
                        for (; _14281 < 4u; _14281++)
                        {
                            for (uint _14282 = 0u; _14282 < 4u; )
                            {
                                _8273[_14281][_14282] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8307 + (_14281 * 4u)) + _14282) * 4 + 0));
                                _14282++;
                                continue;
                            }
                        }
                        _14284 = true;
                        break;
                    } while(false);
                    if (_14284)
                    {
                        _14285 = _8273;
                        break;
                    }
                    _14285 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14286;
                do
                {
                    float _8384 = _4896.x;
                    float _8387 = 1.0f - _4896.y;
                    float4 _8398 = mul(float4((float2(_8384, _8387) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4896 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8259_dummy_parameter))))), 0)).x, 1.0f), _14285);
                    float _8400 = _8398.w;
                    if (!(_8400 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14286 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8413 = ((_8398.xy / _8400.xx) + 1.0f.xx) * 0.5f;
                    _14286 = float2(_8413.x - _8384, _8387 - _8413.y);
                    break;
                } while(false);
                float2 _8210 = abs(_14286);
                if (any(bool2(_8210.x > 100000.0f.xx.x, _8210.y > 100000.0f.xx.y)))
                {
                    _14287 = false;
                    break;
                }
                float _8218 = length(_14286 * _4873);
                uint _8433_dummy_parameter;
                bool _8232 = _8218 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8239;
                if (_8232)
                {
                    _8239 = length((r_motion_tp1.Load(int3(int2(floor(_4896 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8433_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _8218);
                }
                else
                {
                    _8239 = _8232;
                }
                _14287 = _8239;
                break;
            } while(false);
            float2 _4908 = _4615 + _4862;
            bool _14294;
            do
            {
                bool _8519 = all(bool2(_4908.x > 0.0f.xx.x, _4908.y > 0.0f.xx.y));
                bool _8525;
                if (_8519)
                {
                    _8525 = all(bool2(_4908.x < 1.0f.xx.x, _4908.y < 1.0f.xx.y));
                }
                else
                {
                    _8525 = _8519;
                }
                if (!_8525)
                {
                    _14294 = false;
                    break;
                }
                uint _8532_dummy_parameter;
                float4x4 _14292;
                do
                {
                    float4x4 _8546;
                    bool _14291;
                    do
                    {
                        _8546 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14291 = false;
                            break;
                        }
                        uint _8580 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8580 + 32u) * 4 + 0) != 1u)
                        {
                            _14291 = false;
                            break;
                        }
                        uint _14288;
                        _14288 = 0u;
                        for (; _14288 < 4u; _14288++)
                        {
                            for (uint _14289 = 0u; _14289 < 4u; )
                            {
                                _8546[_14288][_14289] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8580 + (_14288 * 4u)) + _14289) * 4 + 0));
                                _14289++;
                                continue;
                            }
                        }
                        _14291 = true;
                        break;
                    } while(false);
                    if (_14291)
                    {
                        _14292 = _8546;
                        break;
                    }
                    _14292 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14293;
                do
                {
                    float _8657 = _4908.x;
                    float _8660 = 1.0f - _4908.y;
                    float4 _8671 = mul(float4((float2(_8657, _8660) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4908 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8532_dummy_parameter))))), 0)).x, 1.0f), _14292);
                    float _8673 = _8671.w;
                    if (!(_8673 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14293 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8686 = ((_8671.xy / _8673.xx) + 1.0f.xx) * 0.5f;
                    _14293 = float2(_8686.x - _8657, _8660 - _8686.y);
                    break;
                } while(false);
                float2 _8483 = abs(_14293);
                if (any(bool2(_8483.x > 100000.0f.xx.x, _8483.y > 100000.0f.xx.y)))
                {
                    _14294 = false;
                    break;
                }
                float _8491 = length(_14293 * _4873);
                uint _8706_dummy_parameter;
                bool _8505 = _8491 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8512;
                if (_8505)
                {
                    _8512 = length((r_motion_tp1.Load(int3(int2(floor(_4908 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8706_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _8491);
                }
                else
                {
                    _8512 = _8505;
                }
                _14294 = _8512;
                break;
            } while(false);
            float _4914 = 0.25f * (((float(_14273) + float(_14280)) + float(_14287)) + float(_14294));
            float4 _14464;
            if (_4914 < 1.0f)
            {
                bool _14301;
                do
                {
                    bool _8792 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
                    bool _8798;
                    if (_8792)
                    {
                        _8798 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8798 = _8792;
                    }
                    if (!_8798)
                    {
                        _14301 = false;
                        break;
                    }
                    uint _8805_dummy_parameter;
                    float4x4 _14299;
                    do
                    {
                        float4x4 _8819;
                        bool _14298;
                        do
                        {
                            _8819 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14298 = false;
                                break;
                            }
                            uint _8853 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8853 + 32u) * 4 + 0) != 1u)
                            {
                                _14298 = false;
                                break;
                            }
                            uint _14295;
                            _14295 = 0u;
                            for (; _14295 < 4u; _14295++)
                            {
                                for (uint _14296 = 0u; _14296 < 4u; )
                                {
                                    _8819[_14295][_14296] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8853 + (_14295 * 4u)) + _14296) * 4 + 0));
                                    _14296++;
                                    continue;
                                }
                            }
                            _14298 = true;
                            break;
                        } while(false);
                        if (_14298)
                        {
                            _14299 = _8819;
                            break;
                        }
                        _14299 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14300;
                    do
                    {
                        float _8933 = 1.0f - _14252.y;
                        float4 _8944 = mul(float4((float2(_14252.x, _8933) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8805_dummy_parameter))))), 0)).x, 1.0f), _14299);
                        float _8946 = _8944.w;
                        if (!(_8946 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14300 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8959 = ((_8944.xy / _8946.xx) + 1.0f.xx) * 0.5f;
                        _14300 = float2(_8959.x - _14252.x, _8933 - _8959.y);
                        break;
                    } while(false);
                    float2 _8756 = abs(_14300);
                    if (any(bool2(_8756.x > 100000.0f.xx.x, _8756.y > 100000.0f.xx.y)))
                    {
                        _14301 = false;
                        break;
                    }
                    float _8764 = length(_14300 * _4873);
                    uint _8979_dummy_parameter;
                    bool _8778 = _8764 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8785;
                    if (_8778)
                    {
                        _8785 = length((r_motion_tp1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8979_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _8764);
                    }
                    else
                    {
                        _8785 = _8778;
                    }
                    _14301 = _8785;
                    break;
                } while(false);
                bool _14308;
                do
                {
                    bool _9065 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
                    bool _9071;
                    if (_9065)
                    {
                        _9071 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9071 = _9065;
                    }
                    if (!_9071)
                    {
                        _14308 = false;
                        break;
                    }
                    uint _9078_dummy_parameter;
                    float4x4 _14306;
                    do
                    {
                        float4x4 _9092;
                        bool _14305;
                        do
                        {
                            _9092 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14305 = false;
                                break;
                            }
                            uint _9126 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9126 + 32u) * 4 + 0) != 1u)
                            {
                                _14305 = false;
                                break;
                            }
                            uint _14302;
                            _14302 = 0u;
                            for (; _14302 < 4u; _14302++)
                            {
                                for (uint _14303 = 0u; _14303 < 4u; )
                                {
                                    _9092[_14302][_14303] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9126 + (_14302 * 4u)) + _14303) * 4 + 0));
                                    _14303++;
                                    continue;
                                }
                            }
                            _14305 = true;
                            break;
                        } while(false);
                        if (_14305)
                        {
                            _14306 = _9092;
                            break;
                        }
                        _14306 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14307;
                    do
                    {
                        float _9206 = 1.0f - _14254.y;
                        float4 _9217 = mul(float4((float2(_14254.x, _9206) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9078_dummy_parameter))))), 0)).x, 1.0f), _14306);
                        float _9219 = _9217.w;
                        if (!(_9219 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14307 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9232 = ((_9217.xy / _9219.xx) + 1.0f.xx) * 0.5f;
                        _14307 = float2(_9232.x - _14254.x, _9206 - _9232.y);
                        break;
                    } while(false);
                    float2 _9029 = abs(_14307);
                    if (any(bool2(_9029.x > 100000.0f.xx.x, _9029.y > 100000.0f.xx.y)))
                    {
                        _14308 = false;
                        break;
                    }
                    float _9037 = length(_14307 * _4873);
                    uint _9252_dummy_parameter;
                    bool _9051 = _9037 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9058;
                    if (_9051)
                    {
                        _9058 = length((r_motion_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9252_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _9037);
                    }
                    else
                    {
                        _9058 = _9051;
                    }
                    _14308 = _9058;
                    break;
                } while(false);
                bool _14315;
                do
                {
                    bool _9338 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                    bool _9344;
                    if (_9338)
                    {
                        _9344 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9344 = _9338;
                    }
                    if (!_9344)
                    {
                        _14315 = false;
                        break;
                    }
                    uint _9351_dummy_parameter;
                    float4x4 _14313;
                    do
                    {
                        float4x4 _9365;
                        bool _14312;
                        do
                        {
                            _9365 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14312 = false;
                                break;
                            }
                            uint _9399 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9399 + 32u) * 4 + 0) != 1u)
                            {
                                _14312 = false;
                                break;
                            }
                            uint _14309;
                            _14309 = 0u;
                            for (; _14309 < 4u; _14309++)
                            {
                                for (uint _14310 = 0u; _14310 < 4u; )
                                {
                                    _9365[_14309][_14310] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9399 + (_14309 * 4u)) + _14310) * 4 + 0));
                                    _14310++;
                                    continue;
                                }
                            }
                            _14312 = true;
                            break;
                        } while(false);
                        if (_14312)
                        {
                            _14313 = _9365;
                            break;
                        }
                        _14313 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14314;
                    do
                    {
                        float _9479 = 1.0f - _14255.y;
                        float4 _9490 = mul(float4((float2(_14255.x, _9479) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9351_dummy_parameter))))), 0)).x, 1.0f), _14313);
                        float _9492 = _9490.w;
                        if (!(_9492 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14314 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9505 = ((_9490.xy / _9492.xx) + 1.0f.xx) * 0.5f;
                        _14314 = float2(_9505.x - _14255.x, _9479 - _9505.y);
                        break;
                    } while(false);
                    float2 _9302 = abs(_14314);
                    if (any(bool2(_9302.x > 100000.0f.xx.x, _9302.y > 100000.0f.xx.y)))
                    {
                        _14315 = false;
                        break;
                    }
                    float _9310 = length(_14314 * _4873);
                    uint _9525_dummy_parameter;
                    bool _9324 = _9310 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9331;
                    if (_9324)
                    {
                        _9331 = length((r_motion_tp1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9525_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _9310);
                    }
                    else
                    {
                        _9331 = _9324;
                    }
                    _14315 = _9331;
                    break;
                } while(false);
                bool _14322;
                do
                {
                    bool _9611 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                    bool _9617;
                    if (_9611)
                    {
                        _9617 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9617 = _9611;
                    }
                    if (!_9617)
                    {
                        _14322 = false;
                        break;
                    }
                    uint _9624_dummy_parameter;
                    float4x4 _14320;
                    do
                    {
                        float4x4 _9638;
                        bool _14319;
                        do
                        {
                            _9638 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14319 = false;
                                break;
                            }
                            uint _9672 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9672 + 32u) * 4 + 0) != 1u)
                            {
                                _14319 = false;
                                break;
                            }
                            uint _14316;
                            _14316 = 0u;
                            for (; _14316 < 4u; _14316++)
                            {
                                for (uint _14317 = 0u; _14317 < 4u; )
                                {
                                    _9638[_14316][_14317] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9672 + (_14316 * 4u)) + _14317) * 4 + 0));
                                    _14317++;
                                    continue;
                                }
                            }
                            _14319 = true;
                            break;
                        } while(false);
                        if (_14319)
                        {
                            _14320 = _9638;
                            break;
                        }
                        _14320 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14321;
                    do
                    {
                        float _9752 = 1.0f - _14256.y;
                        float4 _9763 = mul(float4((float2(_14256.x, _9752) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9624_dummy_parameter))))), 0)).x, 1.0f), _14320);
                        float _9765 = _9763.w;
                        if (!(_9765 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14321 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9778 = ((_9763.xy / _9765.xx) + 1.0f.xx) * 0.5f;
                        _14321 = float2(_9778.x - _14256.x, _9752 - _9778.y);
                        break;
                    } while(false);
                    float2 _9575 = abs(_14321);
                    if (any(bool2(_9575.x > 100000.0f.xx.x, _9575.y > 100000.0f.xx.y)))
                    {
                        _14322 = false;
                        break;
                    }
                    float _9583 = length(_14321 * _4873);
                    uint _9798_dummy_parameter;
                    bool _9597 = _9583 > ((8.0f * _4873.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9604;
                    if (_9597)
                    {
                        _9604 = length((r_motion_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9798_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4873) < (0.20000000298023223876953125f * _9583);
                    }
                    else
                    {
                        _9604 = _9597;
                    }
                    _14322 = _9604;
                    break;
                } while(false);
                float4 _4941 = _7620 * float4(_14301 ? 0.0f : 1.0f, _14308 ? 0.0f : 1.0f, _14315 ? 0.0f : 1.0f, _14322 ? 0.0f : 1.0f);
                float _4943 = dot(_4941, 1.0f.xxxx);
                float4 _14465;
                if (_4943 > 0.001000000047497451305389404296875f)
                {
                    _14465 = _4941 / _4943.xxxx;
                }
                else
                {
                    _14465 = _7620;
                }
                _14464 = _14465;
            }
            else
            {
                _14464 = _7620;
            }
            _15771 = _4914;
            _14463 = _14464;
        }
        else
        {
            _15771 = 0.0f;
            _14463 = _7620;
        }
        bool _4960 = _4652 && (!_14392);
        bool _4969;
        if (_4960)
        {
            _4969 = (_14463.z + _14463.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4969 = _4960;
        }
        bool _4980;
        if (_4969)
        {
            _4980 = length((_14255 - _14252) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4980 = _4969;
        }
        bool _14552;
        if (_4980)
        {
            uint4 _9827 = r_warped_motion_qdata_tp1.Load(int3(_14473, 0));
            uint _9828 = _9827.x;
            bool _14555;
            if (_9828 != 0u)
            {
                float _14541;
                if (_9828 == 0u)
                {
                    _14541 = -1.0f;
                }
                else
                {
                    _14541 = float((_9828 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4990 = _14541 - 0.12000000476837158203125f;
                bool _9847 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                bool _9853;
                if (_9847)
                {
                    _9853 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                }
                else
                {
                    _9853 = _9847;
                }
                bool _5000;
                if (_9853)
                {
                    uint _9860_dummy_parameter;
                    _5000 = (log(((r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9860_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4990;
                }
                else
                {
                    _5000 = _9853;
                }
                bool _5014;
                if (!_5000)
                {
                    bool _9890 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                    bool _9896;
                    if (_9890)
                    {
                        _9896 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9896 = _9890;
                    }
                    bool _5012;
                    if (_9896)
                    {
                        uint _9903_dummy_parameter;
                        _5012 = (log(((r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9903_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4990;
                    }
                    else
                    {
                        _5012 = _9896;
                    }
                    _5014 = _5012;
                }
                else
                {
                    _5014 = _5000;
                }
                _14555 = _5014;
            }
            else
            {
                _14555 = false;
            }
            _14552 = _14555;
        }
        else
        {
            _14552 = false;
        }
        bool _5019 = _14392 || _14552;
        bool _5024;
        if (_5019)
        {
            bool _9933 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
            bool _9939;
            if (_9933)
            {
                _9939 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
            }
            else
            {
                _9939 = _9933;
            }
            _5024 = _9939;
        }
        else
        {
            _5024 = _5019;
        }
        bool _5029;
        if (_5024)
        {
            bool _9944 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
            bool _9950;
            if (_9944)
            {
                _9950 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
            }
            else
            {
                _9950 = _9944;
            }
            _5029 = _9950;
        }
        else
        {
            _5029 = _5024;
        }
        float4 _14675;
        if (_5029)
        {
            float _5035 = _14463.x + _14463.y;
            float _5040 = _14463.z + _14463.w;
            float _14570;
            if (_5035 > 0.001000000047497451305389404296875f)
            {
                _14570 = _14463.x / _5035;
            }
            else
            {
                _14570 = _4840;
            }
            _14675 = float4(_14463.x + (_5040 * _14570), _14463.y + (_5040 * (1.0f - _14570)), 0.0f, 0.0f);
        }
        else
        {
            _14675 = _14463;
        }
        bool _9978 = (cbFI_pad0 & 1024u) != 0u;
        bool _9954 = !_9978;
        bool _9955 = !_9954;
        bool _9972;
        if (_9955)
        {
            _9972 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14473.y * cbFI_MvDepthLaneSize.x) + _14473.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9972 = _9954;
        }
        bool _10004;
        if (_9955)
        {
            _10004 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4631.y * cbFI_FlowLaneSize.x) + _4631.x)) * 4 + 0) != 0u;
        }
        else
        {
            _10004 = _9954;
        }
        float _5075 = float(_10004);
        bool _14696;
        float4 _14735;
        float3 _16405;
        if (_9978)
        {
            bool _5085;
            if (_9972)
            {
                _5085 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
            }
            else
            {
                _5085 = _9972;
            }
            bool _5091;
            if (_5085)
            {
                _5091 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
            }
            else
            {
                _5091 = _5085;
            }
            bool _5098;
            if (_9972)
            {
                _5098 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
            }
            else
            {
                _5098 = _9972;
            }
            bool _5104;
            if (_5098)
            {
                _5104 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
            }
            else
            {
                _5104 = _5098;
            }
            bool _5111;
            if (_10004)
            {
                _5111 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
            }
            else
            {
                _5111 = _10004;
            }
            bool _5117;
            if (_5111)
            {
                _5117 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
            }
            else
            {
                _5117 = _5111;
            }
            bool _5124;
            if (_10004)
            {
                _5124 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
            }
            else
            {
                _5124 = _10004;
            }
            bool _5130;
            if (_5124)
            {
                _5130 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
            }
            else
            {
                _5130 = _5124;
            }
            bool _5132 = !_9972;
            if (_5132)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10046;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _10046);
                }
            }
            bool _5137 = !_10004;
            if (_5137)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10056;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _10056);
                }
            }
            if (_9972 && _5137)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10066;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _10066);
                }
            }
            if (_5132 && _10004)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10076;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _10076);
                }
            }
            float _5156 = float(_5091);
            float _5158 = float(_5104);
            bool _5161 = _5117 && _5130;
            float _14604;
            if (_5161)
            {
                _14604 = 1.0f;
            }
            else
            {
                _14604 = (_5117 || _5130) ? 0.5f : 0.0f;
            }
            bool _14619;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5091)) && (!_5104))
            {
                bool _5191;
                if (_5161)
                {
                    float _14612;
                    do
                    {
                        bool _10160 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                        bool _10166;
                        if (_10160)
                        {
                            _10166 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10166 = _10160;
                        }
                        bool _10097 = !_10166;
                        bool _10104;
                        if (!_10097)
                        {
                            bool _10171 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                            bool _10177;
                            if (_10171)
                            {
                                _10177 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10177 = _10171;
                            }
                            _10104 = !_10177;
                        }
                        else
                        {
                            _10104 = _10097;
                        }
                        if (_10104)
                        {
                            _14612 = 0.0f;
                            break;
                        }
                        uint _10184_dummy_parameter;
                        uint _10200_dummy_parameter;
                        float4x4 _14611;
                        do
                        {
                            float4x4 _10214;
                            bool _14610;
                            do
                            {
                                _10214 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14610 = false;
                                    break;
                                }
                                uint _10248 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10248 + 32u) * 4 + 0) != 1u)
                                {
                                    _14610 = false;
                                    break;
                                }
                                uint _14607;
                                _14607 = 0u;
                                for (; _14607 < 4u; _14607++)
                                {
                                    for (uint _14608 = 0u; _14608 < 4u; )
                                    {
                                        _10214[_14607][_14608] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10248 + 16u) + (_14607 * 4u)) + _14608) * 4 + 0));
                                        _14608++;
                                        continue;
                                    }
                                }
                                _14610 = true;
                                break;
                            } while(false);
                            if (_14610)
                            {
                                _14611 = _10214;
                                break;
                            }
                            _14611 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _10125 = mul(float4((float2(_14255.x, 1.0f - _14255.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10184_dummy_parameter))))), 0)).x, 1.0f), _14611);
                        float _10127 = _10125.w;
                        if (abs(_10127) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14612 = 0.0f;
                            break;
                        }
                        float _10138 = abs(cbFI_DeviceToViewDepth.y / ((_10125.z / _10127) - cbFI_DeviceToViewDepth.x));
                        float _10141 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10200_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14612 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10138 - _10141) / max(max(_10138, _10141), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5191 = _14612 >= 0.5f;
                }
                else
                {
                    _5191 = _5161;
                }
                bool _5199;
                if (_5191)
                {
                    _5199 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5199 = _5191;
                }
                bool _14620;
                if (_5199)
                {
                    uint _10352_dummy_parameter;
                    float4x4 _14617;
                    do
                    {
                        float4x4 _10366;
                        bool _14616;
                        do
                        {
                            _10366 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14616 = false;
                                break;
                            }
                            uint _10400 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10400 + 32u) * 4 + 0) != 1u)
                            {
                                _14616 = false;
                                break;
                            }
                            uint _14613;
                            _14613 = 0u;
                            for (; _14613 < 4u; _14613++)
                            {
                                for (uint _14614 = 0u; _14614 < 4u; )
                                {
                                    _10366[_14613][_14614] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10400 + 16u) + (_14613 * 4u)) + _14614) * 4 + 0));
                                    _14614++;
                                    continue;
                                }
                            }
                            _14616 = true;
                            break;
                        } while(false);
                        if (_14616)
                        {
                            _14617 = _10366;
                            break;
                        }
                        _14617 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14618;
                    do
                    {
                        float _10480 = 1.0f - _14255.y;
                        float4 _10491 = mul(float4((float2(_14255.x, _10480) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10352_dummy_parameter))))), 0)).x, 1.0f), _14617);
                        float _10493 = _10491.w;
                        if (!(_10493 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14618 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10506 = ((_10491.xy / _10493.xx) + 1.0f.xx) * 0.5f;
                        _14618 = float2(_10506.x - _14255.x, _10480 - _10506.y);
                        break;
                    } while(false);
                    float2 _5212 = float2(cbFI_DisplaySize);
                    _14620 = length(((_14255 + _14618) - _14256) * _5212) <= ((0.100000001490116119384765625f * length(_14618 * _5212)) + 8.0f);
                }
                else
                {
                    _14620 = _5191;
                }
                _14619 = _14620;
            }
            else
            {
                _14619 = true;
            }
            bool _5226 = !_14619;
            bool _17347 = _5226 ? false : _5130;
            bool _17348 = _5226 ? false : _5117;
            bool _14697;
            float4 _14736;
            if (!(((_5091 && _5104) && _17348) && _17347))
            {
                float4 _5248 = _14675 * float4(_5156, _5158, float(_17348), float(_17347));
                float _5250 = dot(_5248, 1.0f.xxxx);
                bool _5253 = !(_5250 > 0.0f);
                float4 _14737;
                if (!_5253)
                {
                    _14737 = _5248 / _5250.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10528;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10528);
                    }
                    _14737 = 0.0f.xxxx;
                }
                _14736 = _14737;
                _14697 = _5253;
            }
            else
            {
                _14736 = _14675;
                _14697 = false;
            }
            _16405 = float3(_5156, _5158, _14604);
            _14735 = _14736;
            _14696 = _14697;
        }
        else
        {
            _16405 = float3(float(_9972), _5075, 0.0f);
            _14735 = _14675;
            _14696 = false;
        }
        bool _5271 = !_14696;
        float4 _14828;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5271)
        {
            float _5278 = _14735.x + _14735.y;
            float4 _14829;
            if (_5278 > 0.001000000047497451305389404296875f)
            {
                _14829 = float4(_14735.x / _5278, _14735.y / _5278, 0.0f, 0.0f);
            }
            else
            {
                _14829 = float4(_4840, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14828 = _14829;
        }
        else
        {
            _14828 = _14735;
        }
        float4 _15005;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5271) && _9972)
        {
            float _14802;
            do
            {
                uint4 _10668 = r_warped_motion_qdata_tp1.Load(int3(_14473, 0));
                uint _10669 = _10668.x;
                if (_10669 != 0u)
                {
                    float _14801;
                    if (_10669 == 0u)
                    {
                        _14801 = -1.0f;
                    }
                    else
                    {
                        _14801 = float((_10669 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14802 = _14801;
                    break;
                }
                int _14784;
                uint _14785;
                _14785 = _10669;
                _14784 = -1;
                uint _14800;
                for (; _14784 <= 1; _14785 = _14800, _14784++)
                {
                    _14800 = _14785;
                    for (int _14798 = -1; _14798 <= 1; )
                    {
                        _14800 = max(_14800, r_warped_motion_qdata_tp1.Load(int3(clamp(_14473 + int2(_14798, _14784), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14798++;
                        continue;
                    }
                }
                if (_14785 != 0u)
                {
                    float _14797;
                    if (_14785 == 0u)
                    {
                        _14797 = -1.0f;
                    }
                    else
                    {
                        _14797 = float((_14785 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14802 = _14797;
                    break;
                }
                uint _14787;
                _14787 = 4294967295u;
                uint _17318;
                for (int _14786 = 0; _14786 < 8; _14787 = _17318, _14786++)
                {
                    int _14790 = 0;
                    for (;;)
                    {
                        if (_14790 < 5)
                        {
                            int2 _10619 = _14473 + (_1192[_14786] * _1201[_14790].xx);
                            bool _10622 = any(bool2(_10619.x < int2(0, 0).x, _10619.y < int2(0, 0).y));
                            bool _10630;
                            if (!_10622)
                            {
                                _10630 = any(bool2(_10619.x >= cbFI_MvDepthLaneSize.x, _10619.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10630 = _10622;
                            }
                            if (_10630)
                            {
                                _17318 = _14787;
                                break;
                            }
                            uint4 _10708 = r_warped_motion_qdata_tp1.Load(int3(_10619, 0));
                            uint _10709 = _10708.x;
                            if (_10709 != 0u)
                            {
                                _17318 = min(_14787, _10709);
                                break;
                            }
                            _14790++;
                            continue;
                        }
                        else
                        {
                            _17318 = _14787;
                            break;
                        }
                    }
                }
                float _14789;
                if (_14787 == 4294967295u)
                {
                    _14789 = -1.0f;
                }
                else
                {
                    float _14788;
                    if (_14787 == 0u)
                    {
                        _14788 = -1.0f;
                    }
                    else
                    {
                        _14788 = float((_14787 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14789 = _14788;
                }
                _14802 = _14789;
                break;
            } while(false);
            float _5314 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5317 = r_warped_motion_qdata_tp1.Load(int3(_14473, 0)).x == 0u;
            bool _5323;
            if (_5317)
            {
                bool _10734 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
                bool _10740;
                if (_10734)
                {
                    _10740 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
                }
                else
                {
                    _10740 = _10734;
                }
                _5323 = _10740;
            }
            else
            {
                _5323 = _5317;
            }
            bool _5328;
            if (_5323)
            {
                bool _10745 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
                bool _10751;
                if (_10745)
                {
                    _10751 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
                }
                else
                {
                    _10751 = _10745;
                }
                _5328 = _10751;
            }
            else
            {
                _5328 = _5323;
            }
            bool _14814;
            float4 _14823;
            if (_5328)
            {
                uint _10758_dummy_parameter;
                float _10782 = log(((r_depth_tm1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10758_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _10790_dummy_parameter;
                float _10814 = log(((r_depth_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10790_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _5339 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5346;
                if (_5339)
                {
                    _5346 = _10814 > (_10782 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5346 = _5339;
                }
                bool _14819;
                float4 _14841;
                if (_5346)
                {
                    _14841 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14819 = true;
                }
                else
                {
                    bool _5352 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5359;
                    if (_5352)
                    {
                        _5359 = _10782 > (_10814 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5359 = _5352;
                    }
                    bool4 _17349 = _5359.xxxx;
                    _14841 = float4(_17349.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14828.x, _17349.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14828.y, _17349.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14828.z, _17349.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14828.w);
                    _14819 = _5359 ? true : false;
                }
                _14823 = _14841;
                _14814 = _14819;
            }
            else
            {
                _14823 = _14828;
                _14814 = false;
            }
            float4 _14896;
            if (_14814)
            {
                _14896 = 1.0f.xxxx;
            }
            else
            {
                bool _5370 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5376;
                if (_5370)
                {
                    _5376 = _14823.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5376 = _5370;
                }
                bool _5381;
                if (_5376)
                {
                    bool _10820 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
                    bool _10826;
                    if (_10820)
                    {
                        _10826 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10826 = _10820;
                    }
                    _5381 = _10826;
                }
                else
                {
                    _5381 = _5376;
                }
                float4 _14897;
                if (_5381)
                {
                    float _14850;
                    if (_14802 >= 0.0f)
                    {
                        _14850 = _14802 - _5314;
                    }
                    else
                    {
                        float _14846;
                        _14846 = 2.0f;
                        float _10883;
                        for (int _14845 = 0; _14845 < 24; _14846 = _10883, _14845++)
                        {
                            float _10847 = float(_14845 & 7) * 0.785398185253143310546875f;
                            int _10849 = _14845 >> 3;
                            int _14847;
                            if (_10849 == 0)
                            {
                                _14847 = 16;
                            }
                            else
                            {
                                _14847 = (_10849 == 1) ? 48 : 96;
                            }
                            uint _10915_dummy_parameter;
                            _10883 = min(_14846, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14254 + ((cbFI_MvDepthLaneSizeRcp * float(_14847)) * float2(cos(_10847), sin(_10847))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10915_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14850 = _14846;
                    }
                    uint _10947_dummy_parameter;
                    float4 _14898;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10947_dummy_parameter))))), 0)).x) > ((exp((_14850 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14898 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14898 = 1.0f.xxxx;
                    }
                    _14897 = _14898;
                }
                else
                {
                    _14897 = 1.0f.xxxx;
                }
                _14896 = _14897;
            }
            bool _5409 = _14802 >= 0.0f;
            bool _5410 = (!_14814) && _5409;
            bool _5417;
            if (_5410)
            {
                _5417 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5417 = _5410;
            }
            bool _5423;
            if (_5417)
            {
                _5423 = _14823.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5423 = _5417;
            }
            bool _5428;
            if (_5423)
            {
                bool _10972 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
                bool _10978;
                if (_10972)
                {
                    _10978 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
                }
                else
                {
                    _10978 = _10972;
                }
                _5428 = _10978;
            }
            else
            {
                _5428 = _5423;
            }
            float4 _14921;
            if (_5428)
            {
                float _14890;
                if (_5409)
                {
                    _14890 = _14802 - _5314;
                }
                else
                {
                    float _14886;
                    _14886 = 2.0f;
                    float _11035;
                    for (int _14885 = 0; _14885 < 24; _14886 = _11035, _14885++)
                    {
                        float _10999 = float(_14885 & 7) * 0.785398185253143310546875f;
                        int _11001 = _14885 >> 3;
                        int _14887;
                        if (_11001 == 0)
                        {
                            _14887 = 16;
                        }
                        else
                        {
                            _14887 = (_11001 == 1) ? 48 : 96;
                        }
                        uint _11051_dummy_parameter;
                        _11035 = min(_14886, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14252 + ((cbFI_MvDepthLaneSizeRcp * float(_14887)) * float2(cos(_10999), sin(_10999))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11051_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14890 = _14886;
                }
                uint _11099_dummy_parameter;
                float4 _14922;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11099_dummy_parameter))))), 0)).x) > ((exp((_14890 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _14084 = _14896;
                    _14084.x = 0.0f;
                    _14922 = _14084;
                }
                else
                {
                    _14922 = _14896;
                }
                _14921 = _14922;
            }
            else
            {
                _14921 = _14896;
            }
            float4 _14934;
            if (_5410)
            {
                float _11126 = (exp(((_14802 - _5314) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5466 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5472;
                if (_5466)
                {
                    _5472 = _14823.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5472 = _5466;
                }
                bool _5477;
                if (_5472)
                {
                    bool _11131 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                    bool _11137;
                    if (_11131)
                    {
                        _11137 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11137 = _11131;
                    }
                    _5477 = _11137;
                }
                else
                {
                    _5477 = _5472;
                }
                bool _5485;
                if (_5477)
                {
                    uint _11144_dummy_parameter;
                    _5485 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11144_dummy_parameter))))), 0)).x) > _11126;
                }
                else
                {
                    _5485 = _5477;
                }
                float4 _14932;
                if (_5485)
                {
                    float4 _14087 = _14921;
                    _14087.w = 0.0f;
                    _14932 = _14087;
                }
                else
                {
                    _14932 = _14921;
                }
                bool _5492 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5498;
                if (_5492)
                {
                    _5498 = _14823.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5498 = _5492;
                }
                bool _5503;
                if (_5498)
                {
                    bool _11162 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                    bool _11168;
                    if (_11162)
                    {
                        _11168 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11168 = _11162;
                    }
                    _5503 = _11168;
                }
                else
                {
                    _5503 = _5498;
                }
                bool _5511;
                if (_5503)
                {
                    uint _11175_dummy_parameter;
                    _5511 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11175_dummy_parameter))))), 0)).x) > _11126;
                }
                else
                {
                    _5511 = _5503;
                }
                float4 _14935;
                if (_5511)
                {
                    float4 _14090 = _14932;
                    _14090.z = 0.0f;
                    _14935 = _14090;
                }
                else
                {
                    _14935 = _14932;
                }
                _14934 = _14935;
            }
            else
            {
                _14934 = _14921;
            }
            float4 _15006;
            if (any(bool4(_14934.x < 1.0f.xxxx.x, _14934.y < 1.0f.xxxx.y, _14934.z < 1.0f.xxxx.z, _14934.w < 1.0f.xxxx.w)))
            {
                float4 _5522 = _14823 * _14934;
                float _5524 = dot(_5522, 1.0f.xxxx);
                float4 _15007;
                if (_5524 > 0.0f)
                {
                    _15007 = _5522 / _5524.xxxx;
                }
                else
                {
                    bool _5535 = _14934.y == 0.0f;
                    bool _5541;
                    if (_5535)
                    {
                        _5541 = _14934.x > 0.0f;
                    }
                    else
                    {
                        _5541 = _5535;
                    }
                    bool _5546;
                    if (_5541)
                    {
                        bool _11193 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
                        bool _11199;
                        if (_11193)
                        {
                            _11199 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11199 = _11193;
                        }
                        _5546 = _11199;
                    }
                    else
                    {
                        _5546 = _5541;
                    }
                    float4 _15008;
                    if (_5546)
                    {
                        _15008 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5551 = _14934.x == 0.0f;
                        bool _5557;
                        if (_5551)
                        {
                            _5557 = _14934.y > 0.0f;
                        }
                        else
                        {
                            _5557 = _5551;
                        }
                        bool _5562;
                        if (_5557)
                        {
                            bool _11204 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
                            bool _11210;
                            if (_11204)
                            {
                                _11210 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11210 = _11204;
                            }
                            _5562 = _11210;
                        }
                        else
                        {
                            _5562 = _5557;
                        }
                        bool4 _17352 = _5562.xxxx;
                        _15008 = float4(_17352.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14823.x, _17352.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14823.y, _17352.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14823.z, _17352.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14823.w);
                    }
                    _15007 = _15008;
                }
                _15006 = _15007;
            }
            else
            {
                _15006 = _14823;
            }
            _15005 = _15006;
        }
        else
        {
            _15005 = _14828;
        }
        float4 _15735;
        bool _16041;
        float3 _16175;
        if (((cbFI_pad0 & 32768u) != 0u) && _5271)
        {
            bool _5579 = _15005.x > 0.00999999977648258209228515625f;
            bool _5582 = _15005.y > 0.00999999977648258209228515625f;
            bool _5591 = (_15005.z + _15005.w) > 0.0199999995529651641845703125f;
            bool _5597;
            if (_5591)
            {
                bool _11215 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                bool _11221;
                if (_11215)
                {
                    _11221 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                }
                else
                {
                    _11221 = _11215;
                }
                _5597 = _11221;
            }
            else
            {
                _5597 = _5591;
            }
            bool _5602;
            if (_5597)
            {
                bool _11226 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                bool _11232;
                if (_11226)
                {
                    _11232 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                }
                else
                {
                    _11232 = _11226;
                }
                _5602 = _11232;
            }
            else
            {
                _5602 = _5597;
            }
            bool _5609;
            if (_5602)
            {
                float _15021;
                do
                {
                    bool _11315 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                    bool _11321;
                    if (_11315)
                    {
                        _11321 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11321 = _11315;
                    }
                    bool _11252 = !_11321;
                    bool _11259;
                    if (!_11252)
                    {
                        bool _11326 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                        bool _11332;
                        if (_11326)
                        {
                            _11332 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11332 = _11326;
                        }
                        _11259 = !_11332;
                    }
                    else
                    {
                        _11259 = _11252;
                    }
                    if (_11259)
                    {
                        _15021 = 0.0f;
                        break;
                    }
                    uint _11339_dummy_parameter;
                    uint _11355_dummy_parameter;
                    float4x4 _15020;
                    do
                    {
                        float4x4 _11369;
                        bool _15019;
                        do
                        {
                            _11369 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15019 = false;
                                break;
                            }
                            uint _11403 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11403 + 32u) * 4 + 0) != 1u)
                            {
                                _15019 = false;
                                break;
                            }
                            uint _15016;
                            _15016 = 0u;
                            for (; _15016 < 4u; _15016++)
                            {
                                for (uint _15017 = 0u; _15017 < 4u; )
                                {
                                    _11369[_15016][_15017] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11403 + 16u) + (_15016 * 4u)) + _15017) * 4 + 0));
                                    _15017++;
                                    continue;
                                }
                            }
                            _15019 = true;
                            break;
                        } while(false);
                        if (_15019)
                        {
                            _15020 = _11369;
                            break;
                        }
                        _15020 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11280 = mul(float4((float2(_14255.x, 1.0f - _14255.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11339_dummy_parameter))))), 0)).x, 1.0f), _15020);
                    float _11282 = _11280.w;
                    if (abs(_11282) < 9.9999999747524270787835121154785e-07f)
                    {
                        _15021 = 0.0f;
                        break;
                    }
                    float _11293 = abs(cbFI_DeviceToViewDepth.y / ((_11280.z / _11282) - cbFI_DeviceToViewDepth.x));
                    float _11296 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11355_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _15021 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11293 - _11296) / max(max(_11293, _11296), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5609 = _15021 < 0.5f;
            }
            else
            {
                _5609 = _5602;
            }
            float4 _15040;
            if (_5609)
            {
                uint _11507_dummy_parameter;
                uint _11538_dummy_parameter;
                float4 _15041;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11507_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11538_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _15041 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _15041 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _15040 = _15041;
            }
            else
            {
                _15040 = 1.0f.xxxx;
            }
            bool _5633;
            if (_9972)
            {
                bool _11567 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
                bool _11573;
                if (_11567)
                {
                    _11573 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
                }
                else
                {
                    _11573 = _11567;
                }
                _5633 = _11573;
            }
            else
            {
                _5633 = _9972;
            }
            bool _5639;
            if (_9972)
            {
                bool _11578 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
                bool _11584;
                if (_11578)
                {
                    _11584 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
                }
                else
                {
                    _11584 = _11578;
                }
                _5639 = _11584;
            }
            else
            {
                _5639 = _9972;
            }
            bool _5645;
            if (_10004)
            {
                bool _11589 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                bool _11595;
                if (_11589)
                {
                    _11595 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                }
                else
                {
                    _11595 = _11589;
                }
                _5645 = _11595;
            }
            else
            {
                _5645 = _10004;
            }
            bool _5651;
            if (_10004)
            {
                bool _11600 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                bool _11606;
                if (_11600)
                {
                    _11606 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                }
                else
                {
                    _11606 = _11600;
                }
                _5651 = _11606;
            }
            else
            {
                _5651 = _10004;
            }
            bool _5654 = _5645 != _5651;
            bool _5660;
            if (_5654)
            {
                _5660 = _5633 || _5639;
            }
            else
            {
                _5660 = _5654;
            }
            float4 _15143;
            if (_5660)
            {
                float4 _14117 = _15040;
                _14117.z = 0.0f;
                _14117.w = 0.0f;
                _15143 = _14117;
            }
            else
            {
                _15143 = _15040;
            }
            bool _5667 = _5633 && _5579;
            bool _5670 = _5639 && _5582;
            float4 _15248;
            float3 _16284;
            if (_5667 || _5670)
            {
                float _15138;
                do
                {
                    uint4 _11745 = r_warped_motion_qdata_tp1.Load(int3(_14473, 0));
                    uint _11746 = _11745.x;
                    if (_11746 != 0u)
                    {
                        float _15137;
                        if (_11746 == 0u)
                        {
                            _15137 = -1.0f;
                        }
                        else
                        {
                            _15137 = float((_11746 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15138 = _15137;
                        break;
                    }
                    int _15120;
                    uint _15121;
                    _15121 = _11746;
                    _15120 = -1;
                    uint _15136;
                    for (; _15120 <= 1; _15121 = _15136, _15120++)
                    {
                        _15136 = _15121;
                        for (int _15134 = -1; _15134 <= 1; )
                        {
                            _15136 = max(_15136, r_warped_motion_qdata_tp1.Load(int3(clamp(_14473 + int2(_15134, _15120), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15134++;
                            continue;
                        }
                    }
                    if (_15121 != 0u)
                    {
                        float _15133;
                        if (_15121 == 0u)
                        {
                            _15133 = -1.0f;
                        }
                        else
                        {
                            _15133 = float((_15121 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15138 = _15133;
                        break;
                    }
                    uint _15123;
                    _15123 = 4294967295u;
                    uint _17319;
                    for (int _15122 = 0; _15122 < 8; _15123 = _17319, _15122++)
                    {
                        int _15126 = 0;
                        for (;;)
                        {
                            if (_15126 < 5)
                            {
                                int2 _11696 = _14473 + (_1192[_15122] * _1201[_15126].xx);
                                bool _11699 = any(bool2(_11696.x < int2(0, 0).x, _11696.y < int2(0, 0).y));
                                bool _11707;
                                if (!_11699)
                                {
                                    _11707 = any(bool2(_11696.x >= cbFI_MvDepthLaneSize.x, _11696.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11707 = _11699;
                                }
                                if (_11707)
                                {
                                    _17319 = _15123;
                                    break;
                                }
                                uint4 _11785 = r_warped_motion_qdata_tp1.Load(int3(_11696, 0));
                                uint _11786 = _11785.x;
                                if (_11786 != 0u)
                                {
                                    _17319 = min(_15123, _11786);
                                    break;
                                }
                                _15126++;
                                continue;
                            }
                            else
                            {
                                _17319 = _15123;
                                break;
                            }
                        }
                    }
                    float _15125;
                    if (_15123 == 4294967295u)
                    {
                        _15125 = -1.0f;
                    }
                    else
                    {
                        float _15124;
                        if (_15123 == 0u)
                        {
                            _15124 = -1.0f;
                        }
                        else
                        {
                            _15124 = float((_15123 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15125 = _15124;
                    }
                    _15138 = _15125;
                    break;
                } while(false);
                bool _5678 = _15138 < 0.0f;
                float _15139;
                if (_5678)
                {
                    _15139 = 0.0f;
                }
                else
                {
                    _15139 = _15138 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11807_dummy_parameter;
                uint _11839_dummy_parameter;
                float4 _15176;
                if ((_5678 && _5667) && _5670)
                {
                    uint _11871_dummy_parameter;
                    float _11895 = log(((r_depth_tm1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11871_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11903_dummy_parameter;
                    float _11927 = log(((r_depth_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11903_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _15177;
                    if (_11895 > (_11927 + 0.07999999821186065673828125f))
                    {
                        float4 _14121 = _15143;
                        _14121.x = 0.0f;
                        _15177 = _14121;
                    }
                    else
                    {
                        float4 _15178;
                        if (_11927 > (_11895 + 0.07999999821186065673828125f))
                        {
                            float4 _14123 = _15143;
                            _14123.y = 0.0f;
                            _15178 = _14123;
                        }
                        else
                        {
                            _15178 = _15143;
                        }
                        _15177 = _15178;
                    }
                    _15176 = _15177;
                }
                else
                {
                    _15176 = _15143;
                }
                float _5730 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5732 = _15138 >= 0.0f;
                float _15159;
                if (_5732)
                {
                    _15159 = _15138 - _5730;
                }
                else
                {
                    float _15155;
                    if (_5667)
                    {
                        float _15154;
                        _15154 = 2.0f;
                        float _11985;
                        for (int _15153 = 0; _15153 < 24; _15154 = _11985, _15153++)
                        {
                            float _11949 = float(_15153 & 7) * 0.785398185253143310546875f;
                            int _11951 = _15153 >> 3;
                            int _15156;
                            if (_11951 == 0)
                            {
                                _15156 = 16;
                            }
                            else
                            {
                                _15156 = (_11951 == 1) ? 48 : 96;
                            }
                            uint _12001_dummy_parameter;
                            _11985 = min(_15154, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14252 + ((cbFI_MvDepthLaneSizeRcp * float(_15156)) * float2(cos(_11949), sin(_11949))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12001_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15155 = _15154;
                    }
                    else
                    {
                        _15155 = 0.0f;
                    }
                    _15159 = _15155;
                }
                float _15166;
                if (_5732)
                {
                    _15166 = _15138 - _5730;
                }
                else
                {
                    float _15162;
                    if (_5670)
                    {
                        float _15161;
                        _15161 = 2.0f;
                        float _12099;
                        for (int _15160 = 0; _15160 < 24; _15161 = _12099, _15160++)
                        {
                            float _12063 = float(_15160 & 7) * 0.785398185253143310546875f;
                            int _12065 = _15160 >> 3;
                            int _15163;
                            if (_12065 == 0)
                            {
                                _15163 = 16;
                            }
                            else
                            {
                                _15163 = (_12065 == 1) ? 48 : 96;
                            }
                            uint _12131_dummy_parameter;
                            _12099 = min(_15161, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14254 + ((cbFI_MvDepthLaneSizeRcp * float(_15163)) * float2(cos(_12063), sin(_12063))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12131_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15162 = _15161;
                    }
                    else
                    {
                        _15162 = 0.0f;
                    }
                    _15166 = _15162;
                }
                float _15167;
                if (_5667)
                {
                    uint _12163_dummy_parameter;
                    _15167 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12163_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15167 = 0.0f;
                }
                float _15168;
                if (_5670)
                {
                    uint _12183_dummy_parameter;
                    _15168 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12183_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15168 = 0.0f;
                }
                bool _5787;
                if (_5667)
                {
                    _5787 = _15167 > ((exp((_15159 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5787 = _5667;
                }
                float4 _15184;
                if (_5787)
                {
                    float4 _14125 = _15176;
                    _14125.x = 0.0f;
                    _15184 = _14125;
                }
                else
                {
                    _15184 = _15176;
                }
                bool _5799;
                if (_5670)
                {
                    _5799 = _15168 > ((exp((_15166 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5799 = _5670;
                }
                float4 _15186;
                if (_5799)
                {
                    float4 _14127 = _15184;
                    _14127.y = 0.0f;
                    _15186 = _14127;
                }
                else
                {
                    _15186 = _15184;
                }
                float4 _15249;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5732)
                {
                    bool _5819;
                    if (_5667)
                    {
                        _5819 = _15167 < ((exp((_15159 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5819 = _5667;
                    }
                    float4 _15188;
                    if (_5819)
                    {
                        float4 _14129 = _15186;
                        _14129.x = 0.0f;
                        _15188 = _14129;
                    }
                    else
                    {
                        _15188 = _15186;
                    }
                    bool _5831;
                    if (_5670)
                    {
                        _5831 = _15168 < ((exp((_15166 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5831 = _5670;
                    }
                    float4 _15250;
                    if (_5831)
                    {
                        float4 _14131 = _15188;
                        _14131.y = 0.0f;
                        _15250 = _14131;
                    }
                    else
                    {
                        _15250 = _15188;
                    }
                    _15249 = _15250;
                }
                else
                {
                    _15249 = _15186;
                }
                _16284 = float3(_15139, log(((r_depth_tm1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11807_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_14254 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11839_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _15248 = _15249;
            }
            else
            {
                _16284 = float3(0.0f, 0.0f, 0.5f);
                _15248 = _15143;
            }
            bool _5842 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5591;
            bool _5848;
            if (_5842)
            {
                _5848 = _5645 || _5651;
            }
            else
            {
                _5848 = _5842;
            }
            float4 _15291;
            if (_5848)
            {
                float _15243;
                do
                {
                    uint4 _12363 = r_warped_motion_qdata_tp1.Load(int3(_14473, 0));
                    uint _12364 = _12363.x;
                    if (_12364 != 0u)
                    {
                        float _15242;
                        if (_12364 == 0u)
                        {
                            _15242 = -1.0f;
                        }
                        else
                        {
                            _15242 = float((_12364 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15243 = _15242;
                        break;
                    }
                    int _15225;
                    uint _15226;
                    _15226 = _12364;
                    _15225 = -1;
                    uint _15241;
                    for (; _15225 <= 1; _15226 = _15241, _15225++)
                    {
                        _15241 = _15226;
                        for (int _15239 = -1; _15239 <= 1; )
                        {
                            _15241 = max(_15241, r_warped_motion_qdata_tp1.Load(int3(clamp(_14473 + int2(_15239, _15225), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15239++;
                            continue;
                        }
                    }
                    if (_15226 != 0u)
                    {
                        float _15238;
                        if (_15226 == 0u)
                        {
                            _15238 = -1.0f;
                        }
                        else
                        {
                            _15238 = float((_15226 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15243 = _15238;
                        break;
                    }
                    uint _15228;
                    _15228 = 4294967295u;
                    uint _17320;
                    for (int _15227 = 0; _15227 < 8; _15228 = _17320, _15227++)
                    {
                        int _15231 = 0;
                        for (;;)
                        {
                            if (_15231 < 5)
                            {
                                int2 _12314 = _14473 + (_1192[_15227] * _1201[_15231].xx);
                                bool _12317 = any(bool2(_12314.x < int2(0, 0).x, _12314.y < int2(0, 0).y));
                                bool _12325;
                                if (!_12317)
                                {
                                    _12325 = any(bool2(_12314.x >= cbFI_MvDepthLaneSize.x, _12314.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12325 = _12317;
                                }
                                if (_12325)
                                {
                                    _17320 = _15228;
                                    break;
                                }
                                uint4 _12403 = r_warped_motion_qdata_tp1.Load(int3(_12314, 0));
                                uint _12404 = _12403.x;
                                if (_12404 != 0u)
                                {
                                    _17320 = min(_15228, _12404);
                                    break;
                                }
                                _15231++;
                                continue;
                            }
                            else
                            {
                                _17320 = _15228;
                                break;
                            }
                        }
                    }
                    float _15230;
                    if (_15228 == 4294967295u)
                    {
                        _15230 = -1.0f;
                    }
                    else
                    {
                        float _15229;
                        if (_15228 == 0u)
                        {
                            _15229 = -1.0f;
                        }
                        else
                        {
                            _15229 = float((_15228 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15230 = _15229;
                    }
                    _15243 = _15230;
                    break;
                } while(false);
                float4 _15292;
                if (_15243 >= 0.0f)
                {
                    float _12425 = (exp((_15243 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5867;
                    if (_5645)
                    {
                        uint _12432_dummy_parameter;
                        _5867 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12432_dummy_parameter))))), 0)).x) > _12425;
                    }
                    else
                    {
                        _5867 = _5645;
                    }
                    float4 _15261;
                    if (_5867)
                    {
                        float4 _14133 = _15248;
                        _14133.z = 0.0f;
                        _15261 = _14133;
                    }
                    else
                    {
                        _15261 = _15248;
                    }
                    bool _5879;
                    if (_5651)
                    {
                        uint _12452_dummy_parameter;
                        _5879 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12452_dummy_parameter))))), 0)).x) > _12425;
                    }
                    else
                    {
                        _5879 = _5651;
                    }
                    float4 _15293;
                    if (_5879)
                    {
                        float4 _14135 = _15261;
                        _14135.w = 0.0f;
                        _15293 = _14135;
                    }
                    else
                    {
                        _15293 = _15261;
                    }
                    _15292 = _15293;
                }
                else
                {
                    _15292 = _15248;
                }
                _15291 = _15292;
            }
            else
            {
                _15291 = _15248;
            }
            bool _5887 = _5633 != _5639;
            bool _5894;
            if (_5887)
            {
                _5894 = _5633 ? _5579 : _5582;
            }
            else
            {
                _5894 = _5887;
            }
            bool _5901;
            if (_5894)
            {
                _5901 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5901 = _5894;
            }
            float4 _15394;
            if (_5901)
            {
                bool2 _5906 = _5633.xx;
                float2 _5907 = float2(_5906.x ? _14252.x : _14254.x, _5906.y ? _14252.y : _14254.y);
                float _15275;
                if (_5633)
                {
                    uint _12472_dummy_parameter;
                    _15275 = r_depth_tm1.Load(int3(int2(floor(_5907 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12472_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12488_dummy_parameter;
                    _15275 = r_depth_tp1.Load(int3(int2(floor(_5907 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12488_dummy_parameter))))), 0)).x;
                }
                float4x4 _15282;
                if (_5633)
                {
                    float4x4 _15271;
                    do
                    {
                        float4x4 _12502;
                        bool _15270;
                        do
                        {
                            _12502 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15270 = false;
                                break;
                            }
                            uint _12536 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12536 + 32u) * 4 + 0) != 1u)
                            {
                                _15270 = false;
                                break;
                            }
                            uint _15267;
                            _15267 = 0u;
                            for (; _15267 < 4u; _15267++)
                            {
                                for (uint _15268 = 0u; _15268 < 4u; )
                                {
                                    _12502[_15267][_15268] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12536 + 16u) + (_15267 * 4u)) + _15268) * 4 + 0));
                                    _15268++;
                                    continue;
                                }
                            }
                            _15270 = true;
                            break;
                        } while(false);
                        if (_15270)
                        {
                            _15271 = _12502;
                            break;
                        }
                        _15271 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15282 = _15271;
                }
                else
                {
                    float4x4 _15266;
                    do
                    {
                        float4x4 _12608;
                        bool _15265;
                        do
                        {
                            _12608 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15265 = false;
                                break;
                            }
                            uint _12642 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12642 + 32u) * 4 + 0) != 1u)
                            {
                                _15265 = false;
                                break;
                            }
                            uint _15262;
                            _15262 = 0u;
                            for (; _15262 < 4u; _15262++)
                            {
                                for (uint _15263 = 0u; _15263 < 4u; )
                                {
                                    _12608[_15262][_15263] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12642 + (_15262 * 4u)) + _15263) * 4 + 0));
                                    _15263++;
                                    continue;
                                }
                            }
                            _15265 = true;
                            break;
                        } while(false);
                        if (_15265)
                        {
                            _15266 = _12608;
                            break;
                        }
                        _15266 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15282 = _15266;
                }
                float2 _15283;
                do
                {
                    float _12719 = _5907.x;
                    float _12722 = 1.0f - _5907.y;
                    float4 _12733 = mul(float4((float2(_12719, _12722) * 2.0f) - 1.0f.xx, _15275, 1.0f), _15282);
                    float _12735 = _12733.w;
                    if (!(_12735 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15283 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12748 = ((_12733.xy / _12735.xx) + 1.0f.xx) * 0.5f;
                    _15283 = float2(_12748.x - _12719, _12722 - _12748.y);
                    break;
                } while(false);
                float2 _5937 = float2(cbFI_DisplaySize);
                float4 _15395;
                if (!(length(((_5907 + _15283) - float2(_5906.x ? _14254.x : _14252.x, _5906.y ? _14254.y : _14252.y)) * _5937) <= ((0.100000001490116119384765625f * length(_15283 * _5937)) + 8.0f)))
                {
                    float4 _15396;
                    if (_5633)
                    {
                        float4 _14145 = _15291;
                        _14145.x = 0.0f;
                        _15396 = _14145;
                    }
                    else
                    {
                        float4 _14147 = _15291;
                        _14147.y = 0.0f;
                        _15396 = _14147;
                    }
                    _15395 = _15396;
                }
                else
                {
                    _15395 = _15291;
                }
                _15394 = _15395;
            }
            else
            {
                _15394 = _15291;
            }
            float4 _5962 = _15005 * _15394;
            float _5964 = dot(_5962, 1.0f.xxxx);
            float4 _15736;
            bool _16042;
            if (_5964 > 0.0f)
            {
                _16042 = _14696;
                _15736 = _5962 / _5964.xxxx;
            }
            else
            {
                bool _5975 = any(bool4(_15394.x < 1.0f.xxxx.x, _15394.y < 1.0f.xxxx.y, _15394.z < 1.0f.xxxx.z, _15394.w < 1.0f.xxxx.w));
                if (_5975)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12770;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12770);
                    }
                }
                bool4 _17355 = _5975.xxxx;
                _16042 = _5975 ? true : _14696;
                _15736 = float4(_17355.x ? 0.0f.xxxx.x : _15005.x, _17355.y ? 0.0f.xxxx.y : _15005.y, _17355.z ? 0.0f.xxxx.z : _15005.z, _17355.w ? 0.0f.xxxx.w : _15005.w);
            }
            _16175 = _16284;
            _16041 = _16042;
            _15735 = _15736;
        }
        else
        {
            _16175 = float3(0.0f, 0.0f, 0.5f);
            _16041 = _14696;
            _15735 = _15005;
        }
        uint _5984 = (cbFI_pad0 >> 24u) & 31u;
        uint _5988 = (cbFI_pad0 >> 16u) & 255u;
        bool _5990 = _5984 != 0u;
        bool _5992 = _5988 == 12u;
        bool _5995 = _5988 == 13u;
        float4 _15756;
        if ((_5990 || _5992) || _5995)
        {
            float _15402;
            do
            {
                bool _12854 = all(bool2(_14255.x > 0.0f.xx.x, _14255.y > 0.0f.xx.y));
                bool _12860;
                if (_12854)
                {
                    _12860 = all(bool2(_14255.x < 1.0f.xx.x, _14255.y < 1.0f.xx.y));
                }
                else
                {
                    _12860 = _12854;
                }
                bool _12791 = !_12860;
                bool _12798;
                if (!_12791)
                {
                    bool _12865 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
                    bool _12871;
                    if (_12865)
                    {
                        _12871 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12871 = _12865;
                    }
                    _12798 = !_12871;
                }
                else
                {
                    _12798 = _12791;
                }
                if (_12798)
                {
                    _15402 = 0.0f;
                    break;
                }
                uint _12878_dummy_parameter;
                uint _12894_dummy_parameter;
                float4x4 _15401;
                do
                {
                    float4x4 _12908;
                    bool _15400;
                    do
                    {
                        _12908 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15400 = false;
                            break;
                        }
                        uint _12942 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12942 + 32u) * 4 + 0) != 1u)
                        {
                            _15400 = false;
                            break;
                        }
                        uint _15397;
                        _15397 = 0u;
                        for (; _15397 < 4u; _15397++)
                        {
                            for (uint _15398 = 0u; _15398 < 4u; )
                            {
                                _12908[_15397][_15398] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12942 + 16u) + (_15397 * 4u)) + _15398) * 4 + 0));
                                _15398++;
                                continue;
                            }
                        }
                        _15400 = true;
                        break;
                    } while(false);
                    if (_15400)
                    {
                        _15401 = _12908;
                        break;
                    }
                    _15401 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12819 = mul(float4((float2(_14255.x, 1.0f - _14255.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12878_dummy_parameter))))), 0)).x, 1.0f), _15401);
                float _12821 = _12819.w;
                if (abs(_12821) < 9.9999999747524270787835121154785e-07f)
                {
                    _15402 = 0.0f;
                    break;
                }
                float _12832 = abs(cbFI_DeviceToViewDepth.y / ((_12819.z / _12821) - cbFI_DeviceToViewDepth.x));
                float _12835 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12894_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15402 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12832 - _12835) / max(max(_12832, _12835), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _13044 = all(bool2(_14256.x > 0.0f.xx.x, _14256.y > 0.0f.xx.y));
            bool _13050;
            if (_13044)
            {
                _13050 = all(bool2(_14256.x < 1.0f.xx.x, _14256.y < 1.0f.xx.y));
            }
            else
            {
                _13050 = _13044;
            }
            float _15403;
            if (_13050)
            {
                uint _13057_dummy_parameter;
                _15403 = length((_6870 + (r_motion_tp1.Load(int3(int2(floor(_14256 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13057_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15403 = 1000000.0f;
            }
            float _15418;
            if ((_5984 & 1u) != 0u)
            {
                _15418 = _15402;
            }
            else
            {
                _15418 = 1.0f;
            }
            float _15419;
            if ((_5984 & 2u) != 0u)
            {
                _15419 = _15418 * (1.0f - smoothstep(2.0f, 8.0f, _15403));
            }
            else
            {
                _15419 = _15418;
            }
            float _15420;
            if ((_5984 & 4u) != 0u)
            {
                _15420 = _15419 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7591 - _7599) - length(_7575 - _7583))));
            }
            else
            {
                _15420 = _15419;
            }
            float _15750;
            if ((_5984 & 8u) != 0u)
            {
                _15750 = lerp(1.0f, _15420, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7575 - _7583)));
            }
            else
            {
                _15750 = _15420;
            }
            bool _6070 = (_5984 & 16u) != 0u;
            bool _6079;
            if (_6070)
            {
                _6079 = length(_14250 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6079 = _6070;
            }
            float _17357 = _6079 ? 1.0f : _15750;
            bool _6085 = _5990 && _9972;
            bool _6090;
            if (_6085)
            {
                bool _13082 = all(bool2(_14252.x > 0.0f.xx.x, _14252.y > 0.0f.xx.y));
                bool _13088;
                if (_13082)
                {
                    _13088 = all(bool2(_14252.x < 1.0f.xx.x, _14252.y < 1.0f.xx.y));
                }
                else
                {
                    _13088 = _13082;
                }
                _6090 = _13088;
            }
            else
            {
                _6090 = _6085;
            }
            bool _6095;
            if (_6090)
            {
                bool _13093 = all(bool2(_14254.x > 0.0f.xx.x, _14254.y > 0.0f.xx.y));
                bool _13099;
                if (_13093)
                {
                    _13099 = all(bool2(_14254.x < 1.0f.xx.x, _14254.y < 1.0f.xx.y));
                }
                else
                {
                    _13099 = _13093;
                }
                _6095 = _13099;
            }
            else
            {
                _6095 = _6090;
            }
            float4 _15757;
            if (_6095)
            {
                float _6101 = _15735.x + _15735.y;
                float _6110 = (_15735.z + _15735.w) * (1.0f - _17357);
                float _15753;
                if (_6101 > 9.9999997473787516355514526367188e-06f)
                {
                    _15753 = _15735.x / _6101;
                }
                else
                {
                    _15753 = _4840;
                }
                _15757 = float4(_15735.x + (_6110 * _15753), _15735.y + (_6110 * (1.0f - _15753)), _15735.zw * _17357);
            }
            else
            {
                _15757 = _15735;
            }
            _15756 = _15757;
        }
        else
        {
            _15756 = _15735;
        }
        float3 _6171 = (((_7575 * _15756.x) + (_7583 * _15756.y)) + (_7591 * _15756.z)) + (_7599 * _15756.w);
        float3 _17120;
        if (_4856 && (_15771 > 0.0f))
        {
            uint _13106_dummy_parameter;
            float2 _13121 = r_motion_tp1.Load(int3(int2(floor(_4615 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13106_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _16033;
            if (_6898)
            {
                float2 _13166 = clamp((((_14229 + (_13121 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13169 = tan(_13166.x);
                _16033 = (float2(_13169 / cbFI_DeviceToViewDepth.z, (tan(_13166.y) * sqrt(1.0f + (_13169 * _13169))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _16033 = _14229 + (_13121 * cbFI_Timestep);
            }
            float2 _16034;
            if (_6898)
            {
                float2 _13245 = clamp((((_14229 + (_13121 * _4830)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13248 = tan(_13245.x);
                _16034 = (float2(_13248 / cbFI_DeviceToViewDepth.z, (tan(_13245.y) * sqrt(1.0f + (_13248 * _13248))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _16034 = _14229 + (_13121 * _4830);
            }
            _17120 = lerp(_6171, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _16033, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _16034, 0.0f).xyz, cbFI_Timestep.xxx), _15771.xxx);
        }
        else
        {
            _17120 = _6171;
        }
        float3 _17119;
        if (_16041)
        {
            float3 _13290 = r_current_interpolation_source.Load(int3(_4138, 0)).xyz;
            float3 _17121;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9972)
            {
                uint _13297_dummy_parameter;
                float _16164;
                _16164 = r_depth_tm1.Load(int3(int2(floor(_14252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13297_dummy_parameter))))), 0)).x;
                float _6252;
                for (int _16163 = 0; _16163 < 24; _16164 = _6252, _16163++)
                {
                    float _6224 = float(_16163 & 7) * 0.785398185253143310546875f;
                    int _6226 = _16163 >> 3;
                    int _17173;
                    if (_6226 == 0)
                    {
                        _17173 = 16;
                    }
                    else
                    {
                        _17173 = (_6226 == 1) ? 48 : 96;
                    }
                    uint _13317_dummy_parameter;
                    _6252 = max(_16164, r_depth_tm1.Load(int3(int2(floor(clamp(_14252 + ((cbFI_MvDepthLaneSizeRcp * float(_17173)) * float2(cos(_6224), sin(_6224))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13317_dummy_parameter))))), 0)).x);
                }
                float2 _16165;
                do
                {
                    float _13339 = 1.0f - _14252.y;
                    float4 _13350 = mul(float4((float2(_14252.x, _13339) * 2.0f) - 1.0f.xx, _16164, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13352 = _13350.w;
                    if (!(_13352 > 9.9999999747524270787835121154785e-07f))
                    {
                        _16165 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13365 = ((_13350.xy / _13352.xx) + 1.0f.xx) * 0.5f;
                    _16165 = float2(_13365.x - _14252.x, _13339 - _13365.y);
                    break;
                } while(false);
                float2 _6263 = _14252 + _16165;
                bool _13383 = all(bool2(_6263.x > 0.0f.xx.x, _6263.y > 0.0f.xx.y));
                bool _13389;
                if (_13383)
                {
                    _13389 = all(bool2(_6263.x < 1.0f.xx.x, _6263.y < 1.0f.xx.y));
                }
                else
                {
                    _13389 = _13383;
                }
                float3 _17122;
                if (_13389)
                {
                    float _6269 = abs(cbFI_DeviceToViewDepth.y / (_16164 - cbFI_DeviceToViewDepth.x));
                    uint _13409_dummy_parameter;
                    int2 _13409 = int2(spvTextureSize(r_depth_m2, uint(0), _13409_dummy_parameter));
                    float _6273 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6263 * float2(_13409))), int2(0, 0), _13409 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _17127;
                    if (abs(_6273 - _6269) <= (0.20000000298023223876953125f * max(_6273, _6269)))
                    {
                        uint _13443_dummy_parameter;
                        int2 _13443 = int2(spvTextureSize(r_colour_m2, uint(0), _13443_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13466;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13466);
                        }
                        _17127 = r_colour_m2.Load(int3(clamp(int2(floor(_6263 * float2(_13443))), int2(0, 0), _13443 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13476;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13476);
                        }
                        _17127 = _13290;
                    }
                    _17122 = _17127;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13486;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13486);
                    }
                    _17122 = _13290;
                }
                _17121 = _17122;
            }
            else
            {
                _17121 = _13290;
            }
            _17119 = _17121;
        }
        else
        {
            _17119 = _17120;
        }
        uint _6301 = cbFI_pad0 & 255u;
        bool _16993;
        float3 _17118;
        if (_6301 != 0u)
        {
            float3 _6306 = r_present_backbuffer.Load(int3(_4138, 0)).xyz;
            float3 _6310 = r_current_interpolation_source.Load(int3(_4138, 0)).xyz;
            float3 _6314 = abs(_6306 - _6310);
            float3 _16168;
            if (_6301 == 2u)
            {
                _16168 = (abs(_6310) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _16168 = 0.000244140625f.xxx;
            }
            bool _6330 = any(bool3(_6314.x > _16168.x, _6314.y > _16168.y, _6314.z > _16168.z));
            bool3 _17358 = _6330.xxx;
            _17118 = float3(_17358.x ? _6306.x : _17119.x, _17358.y ? _6306.y : _17119.y, _17358.z ? _6306.z : _17119.z);
            _16993 = _6330;
        }
        else
        {
            _17118 = _17119;
            _16993 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13501;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13501);
        }
        float3 _17100;
        if (_5988 == 1u)
        {
            _17100 = lerp(_7575, _7583, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _17101;
            if (_5988 == 2u)
            {
                _17101 = lerp(_7591, _7599, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _17102;
                if (_5988 == 3u)
                {
                    _17102 = float(_16993).xxx;
                }
                else
                {
                    float3 _17103;
                    if (_5988 == 4u)
                    {
                        _17103 = float3(((_14250 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _17104;
                        if (_5988 == 5u)
                        {
                            _17104 = float3(((_6870 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _17105;
                            if (_5988 == 6u)
                            {
                                _17105 = float3(_15756.xy, _15756.z + _15756.w);
                            }
                            else
                            {
                                float3 _17106;
                                if (_5988 == 7u)
                                {
                                    _17106 = r_current_interpolation_source.Load(int3(_4138, 0)).xyz;
                                }
                                else
                                {
                                    float3 _17107;
                                    if (_5988 == 8u)
                                    {
                                        _17107 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4615, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _17108;
                                        if (_5992)
                                        {
                                            uint _13523_dummy_parameter;
                                            uint _13555_dummy_parameter;
                                            _17108 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4615 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13523_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4615 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13555_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _17109;
                                            if (_5995)
                                            {
                                                _17109 = _7591;
                                            }
                                            else
                                            {
                                                float3 _17110;
                                                if (_5988 == 20u)
                                                {
                                                    _17110 = _7575;
                                                }
                                                else
                                                {
                                                    float3 _17111;
                                                    if (_5988 == 21u)
                                                    {
                                                        _17111 = _7583;
                                                    }
                                                    else
                                                    {
                                                        float3 _17112;
                                                        if (_5988 == 22u)
                                                        {
                                                            _17112 = _7599;
                                                        }
                                                        else
                                                        {
                                                            float3 _17113;
                                                            if (_5988 == 18u)
                                                            {
                                                                _17113 = _16641;
                                                            }
                                                            else
                                                            {
                                                                float3 _17114;
                                                                if (_5988 == 19u)
                                                                {
                                                                    _17114 = _16405;
                                                                }
                                                                else
                                                                {
                                                                    float3 _17115;
                                                                    if (_5988 == 23u)
                                                                    {
                                                                        _17115 = _16175;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _17116;
                                                                        if (_5988 == 24u)
                                                                        {
                                                                            uint _6474 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _6479 = float(rw_nfru_diagnostics.Load<uint>((_6474 + 35u) * 4 + 0));
                                                                            float _16169;
                                                                            if (_6479 > 0.0f)
                                                                            {
                                                                                _16169 = float(rw_nfru_diagnostics.Load<uint>((_6474 + 34u) * 4 + 0)) / _6479;
                                                                            }
                                                                            else
                                                                            {
                                                                                _16169 = 0.0f;
                                                                            }
                                                                            _17116 = float3(float(rw_nfru_diagnostics.Load<uint>((_6474 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_6474 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _16169);
                                                                        }
                                                                        else
                                                                        {
                                                                            _17116 = _17118;
                                                                        }
                                                                        _17115 = _17116;
                                                                    }
                                                                    _17114 = _17115;
                                                                }
                                                                _17113 = _17114;
                                                            }
                                                            _17112 = _17113;
                                                        }
                                                        _17111 = _17112;
                                                    }
                                                    _17110 = _17111;
                                                }
                                                _17109 = _17110;
                                            }
                                            _17108 = _17109;
                                        }
                                        _17107 = _17108;
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
        float3 _17099;
        if ((_5988 >= 9u) && (_5988 <= 11u))
        {
            uint _6539 = 64u + uint((_14473.y * cbFI_MvDepthLaneSize.x) + _14473.x);
            uint _6543 = rw_nfru_diagnostics.Load<uint>(_6539 * 4 + 0) & 15u;
            float3 _17132;
            if (_5988 == 10u)
            {
                float3 _17098;
                if ((rw_nfru_diagnostics.Load<uint>(_6539 * 4 + 0) & 32u) != 0u)
                {
                    _17098 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _17097;
                    if ((rw_nfru_diagnostics.Load<uint>(_6539 * 4 + 0) & 16u) != 0u)
                    {
                        _17097 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6564 = ((rw_nfru_diagnostics.Load<uint>(_6539 * 4 + 0) & 64u) != 0u).xxx;
                        _17097 = float3(_6564.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6564.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6564.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _17098 = _17097;
                }
                _17132 = _17098;
            }
            else
            {
                float3 _17133;
                if (_5988 == 11u)
                {
                    uint _6577 = (rw_nfru_diagnostics.Load<uint>(_6539 * 4 + 0) >> 8u) & 15u;
                    uint _6580 = (rw_nfru_diagnostics.Load<uint>(_6539 * 4 + 0) >> 12u) & 15u;
                    float3 _17090;
                    if ((_6543 == 2u) || (_6543 == 3u))
                    {
                        _17090 = _3834[_6543];
                    }
                    else
                    {
                        bool _6592 = _6577 == 3u;
                        bool _6594 = _6580 == 3u;
                        float3 _17091;
                        if (_6592 && _6594)
                        {
                            _17091 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _17092;
                            if (_6592)
                            {
                                _17092 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _17093;
                                if (_6594)
                                {
                                    _17093 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _17094;
                                    if ((_6577 == 4u) || (_6580 == 4u))
                                    {
                                        _17094 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _17095;
                                        if ((_6577 == 1u) || (_6580 == 1u))
                                        {
                                            _17095 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17360 = (_6543 == 1u).xxx;
                                            _17095 = float3(_17360.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17360.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17360.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _17094 = _17095;
                                    }
                                    _17093 = _17094;
                                }
                                _17092 = _17093;
                            }
                            _17091 = _17092;
                        }
                        _17090 = _17091;
                    }
                    _17133 = _17090;
                }
                else
                {
                    _17133 = _3834[min(_6543, 7u)];
                }
                _17132 = _17133;
            }
            _17099 = _17132;
        }
        else
        {
            _17099 = _17100;
        }
        float4 _17136;
        if ((_5988 >= 14u) && (_5988 <= 16u))
        {
            float2 _17134;
            if (_5988 == 14u)
            {
                uint _6650_dummy_parameter;
                uint _6656_dummy_parameter;
                _17134 = r_flow_tm1.Load(int3(clamp(int2(floor(_4615 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6650_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6656_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _17135;
                if (_5988 == 16u)
                {
                    uint _13631 = r_warped_flow_qdata_tm1.Load(int3(_4631, 0)).x & 2147483647u;
                    uint _13663 = uint(max((int((_13631 >> 16u) & 15u) - 6), 0));
                    _17135 = ((float2(float((1 - (2 * int((_13631 >> 15u) & 1u))) * int(((_13631 >> uint(7)) & 127u) << _13663)), float((1 - (2 * int((_13631 >> 14u) & 1u))) * int((_13631 & 127u) << _13663))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _17135 = _6870 * float2(cbFI_DisplaySize);
                }
                _17134 = _17135;
            }
            uint2 _6689 = uint2(clamp(round(_17134 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6691 = _6689.x;
            uint _6698 = _6689.y;
            _17136 = float4(float(_6691 & 255u), float((_6691 >> 8u) | ((_6698 & 15u) << 4u)), float(_6698 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _17137;
            if (_5988 == 17u)
            {
                _17137 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4631, 0)).x != 0u), _5075, 0.0f, 1.0f);
            }
            else
            {
                _17137 = float4(_17099, 1.0f);
            }
            _17136 = _17137;
        }
        rw_output[_4138] = _17136.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6742 = ((uint(_4138.y) * uint(cbFI_DisplaySize.x)) + uint(_4138.x)) * 6u;
            uint _13709 = spvPackHalf2x16(clamp(_7574.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6742 * 4 + 0, (((_13709 & 32767u) >> 4u) | ((((_13709 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7574.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13744 = spvPackHalf2x16(clamp(_7582.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6742 + 1u) * 4 + 0, (((_13744 & 32767u) >> 4u) | ((((_13744 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7582.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13779 = spvPackHalf2x16(clamp(_7590.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6742 + 2u) * 4 + 0, (((_13779 & 32767u) >> 4u) | ((((_13779 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7590.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13814 = spvPackHalf2x16(clamp(_7598.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6742 + 3u) * 4 + 0, (((_13814 & 32767u) >> 4u) | ((((_13814 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7598.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13841 = r_current_interpolation_source.Load(int3(_4138, 0));
            uint _13855 = spvPackHalf2x16(clamp(_13841.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6742 + 4u) * 4 + 0, (((_13855 & 32767u) >> 4u) | ((((_13855 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13841.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _17172;
            if (_16993 || (_5988 != 0u))
            {
                _17172 = 4294967295u;
            }
            else
            {
                uint _13890 = spvPackHalf2x16(clamp(_17136.xy, 0.0f.xx, 65000.0f.xx));
                _17172 = (((_13890 & 32767u) >> 4u) | ((((_13890 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_17136.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6742 + 5u) * 4 + 0, _17172);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4138] = float4(r_current_interpolation_source.Load(int3(_4138, 0)).xyz, 1.0f).xyz;
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
