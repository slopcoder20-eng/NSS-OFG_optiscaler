static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3270[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3557 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3557.x >= cbFI_DisplaySize.x, _3557.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3557] = float4(r_present_backbuffer.Load(int3(_3557, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3943 = (float2(_3557) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3954 = int2(floor(_3943 * float2(cbFI_MvDepthLaneSize)));
        int2 _3959 = int2(floor(_3943 * float2(cbFI_FlowLaneSize)));
        float4 _5835 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3943 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5841 = r_warped_filled_flow_tm1.Load(int3(_3959, 0)).xy;
        float2 _5847 = r_warped_filled_motion_tp1.Load(int3(_3954, 0)).xy;
        bool _5869 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9915;
        if (_5869)
        {
            float _5882 = ((2.0f * _3943.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9915 = float2(atan(_5882) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3943.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5882 * _5882))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9915 = _3943;
        }
        bool _3980 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9936;
        bool _9957;
        int2 _9968;
        float3 _11314;
        if (_3980)
        {
            float _9917;
            float _9919;
            _9919 = 2.0f;
            _9917 = -1.0f;
            uint _3619[9];
            float _11745;
            float _11748;
            for (int _9916 = 0; _9916 < 9; _9919 = _11748, _9917 = _11745, _9916++)
            {
                _3619[_9916] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3954 + int2((_9916 % 3) - 1, (_9916 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3619[_9916] != 0u)
                {
                    float _11740;
                    if (_3619[_9916] == 0u)
                    {
                        _11740 = -1.0f;
                    }
                    else
                    {
                        _11740 = float((_3619[_9916] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11748 = min(_9919, _11740);
                    _11745 = max(_9917, _11740);
                }
                else
                {
                    _11748 = _9919;
                    _11745 = _9917;
                }
            }
            float _4026 = float(_9917 >= 0.0f);
            float3 _9716 = 0.0f.xxx;
            _9716.y = _4026;
            float2 _9937;
            bool _9958;
            int2 _9969;
            float3 _11315;
            if ((_9917 - _9919) > 0.0199999995529651641845703125f)
            {
                float _9925;
                int2 _9926;
                float2 _9927;
                int2 _9929;
                float2 _9935;
                _9935 = _5847;
                _9929 = _3954;
                _9927 = _5847;
                _9926 = _3954;
                _9925 = -1.0f;
                float _11753;
                int2 _11757;
                float2 _11768;
                int2 _11779;
                float2 _11812;
                float _11859;
                int _9924 = 0;
                float _11721 = 1000000000.0f;
                for (; _9924 < 9; _11721 = _11859, _9935 = _11812, _9929 = _11779, _9927 = _11768, _9926 = _11757, _9925 = _11753, _9924++)
                {
                    if (_3619[_9924] == 0u)
                    {
                        _11859 = _11721;
                        _11812 = _9935;
                        _11779 = _9929;
                        _11768 = _9927;
                        _11757 = _9926;
                        _11753 = _9925;
                        continue;
                    }
                    int2 _4061 = clamp(_3954 + int2((_9924 % 3) - 1, (_9924 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5957 = _3619[_9924] & 2147483647u;
                    uint _5989 = uint(max((int((_5957 >> 16u) & 15u) - 6), 0));
                    float2 _4067 = (float2(float((1 - (2 * int((_5957 >> 15u) & 1u))) * int(((_5957 >> uint(7)) & 127u) << _5989)), float((1 - (2 * int((_5957 >> 14u) & 1u))) * int((_5957 & 127u) << _5989))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11707;
                    if (_3619[_9924] == 0u)
                    {
                        _11707 = -1.0f;
                    }
                    else
                    {
                        _11707 = float((_3619[_9924] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4072 = _11707 - 0.100000001490116119384765625f;
                    float2 _11708;
                    if (_5869)
                    {
                        float2 _6066 = clamp((((_9915 + (_4067 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6069 = tan(_6066.x);
                        _11708 = (float2(_6069 / cbFI_DeviceToViewDepth.z, (tan(_6066.y) * sqrt(1.0f + (_6069 * _6069))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11708 = _9915 + (_4067 * cbFI_Timestep);
                    }
                    float _4079 = cbFI_Timestep - 1.0f;
                    float2 _11709;
                    if (_5869)
                    {
                        float2 _6137 = clamp((((_9915 + (_4067 * _4079)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6140 = tan(_6137.x);
                        _11709 = (float2(_6140 / cbFI_DeviceToViewDepth.z, (tan(_6137.y) * sqrt(1.0f + (_6140 * _6140))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11709 = _9915 + (_4067 * _4079);
                    }
                    bool _6173 = all(bool2(_11708.x > 0.0f.xx.x, _11708.y > 0.0f.xx.y));
                    bool _6179;
                    if (_6173)
                    {
                        _6179 = all(bool2(_11708.x < 1.0f.xx.x, _11708.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6179 = _6173;
                    }
                    float _11712;
                    if (_6179)
                    {
                        uint _6186_dummy_parameter;
                        _11712 = max((_4072 - (log((r_depth_tm1.Load(int3(int2(floor(_11708 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6186_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11712 = 0.0f;
                    }
                    bool _6216 = all(bool2(_11709.x > 0.0f.xx.x, _11709.y > 0.0f.xx.y));
                    bool _6222;
                    if (_6216)
                    {
                        _6222 = all(bool2(_11709.x < 1.0f.xx.x, _11709.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6222 = _6216;
                    }
                    float _11713;
                    if (_6222)
                    {
                        uint _6229_dummy_parameter;
                        _11713 = _11712 + max((_4072 - (log((r_depth_tp1.Load(int3(int2(floor(_11709 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6229_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11713 = _11712;
                    }
                    float _11754;
                    int2 _11758;
                    float2 _11769;
                    int2 _11780;
                    float2 _11813;
                    float _11860;
                    if (_11713 == 0.0f)
                    {
                        bool _4114 = _4072 > _9925;
                        bool2 _11868 = _4114.xx;
                        _11860 = _11721;
                        _11813 = float2(_11868.x ? _4067.x : _9935.x, _11868.y ? _4067.y : _9935.y);
                        _11780 = int2(_11868.x ? _4061.x : _9929.x, _11868.y ? _4061.y : _9929.y);
                        _11769 = _9927;
                        _11758 = _9926;
                        _11754 = _4114 ? _4072 : _9925;
                    }
                    else
                    {
                        bool _4123 = _11713 < _11721;
                        bool2 _11864 = _4123.xx;
                        _11860 = _4123 ? _11713 : _11721;
                        _11813 = _9935;
                        _11780 = _9929;
                        _11769 = float2(_11864.x ? _4067.x : _9927.x, _11864.y ? _4067.y : _9927.y);
                        _11758 = int2(_11864.x ? _4061.x : _9926.x, _11864.y ? _4061.y : _9926.y);
                        _11754 = _9925;
                    }
                    _11859 = _11860;
                    _11812 = _11813;
                    _11779 = _11780;
                    _11768 = _11769;
                    _11757 = _11758;
                    _11753 = _11754;
                }
                bool _4135 = _9925 < 0.0f;
                bool2 _11874 = _4135.xx;
                int2 _11877 = int2(_11874.x ? _9926.x : _9929.x, _11874.y ? _9926.y : _9929.y);
                _11315 = float3(1.0f, _4026, float(any(bool2(_11877.x != _3954.x, _11877.y != _3954.y))));
                _9969 = _11877;
                _9958 = _4135 ? false : true;
                _9937 = float2(_11874.x ? _9927.x : _9935.x, _11874.y ? _9927.y : _9935.y);
            }
            else
            {
                _11315 = _9716;
                _9969 = _3954;
                _9958 = false;
                _9937 = _5847;
            }
            _11314 = _11315;
            _9968 = _9969;
            _9957 = _9958;
            _9936 = _9937;
        }
        else
        {
            _11314 = 0.0f.xxx;
            _9968 = _3954;
            _9957 = false;
            _9936 = _5847;
        }
        float2 _9938;
        if (_5869)
        {
            float2 _6294 = clamp((((_9915 + (_9936 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6297 = tan(_6294.x);
            _9938 = (float2(_6297 / cbFI_DeviceToViewDepth.z, (tan(_6294.y) * sqrt(1.0f + (_6297 * _6297))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9938 = _9915 + (_9936 * cbFI_Timestep);
        }
        float _4158 = cbFI_Timestep - 1.0f;
        float2 _9940;
        if (_5869)
        {
            float2 _6365 = clamp((((_9915 + (_9936 * _4158)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6368 = tan(_6365.x);
            _9940 = (float2(_6368 / cbFI_DeviceToViewDepth.z, (tan(_6365.y) * sqrt(1.0f + (_6368 * _6368))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9940 = _9915 + (_9936 * _4158);
        }
        float _4163 = -cbFI_Timestep;
        float2 _9941;
        if (_5869)
        {
            float2 _6436 = clamp((((_9915 + (_5841 * _4163)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6439 = tan(_6436.x);
            _9941 = (float2(_6439 / cbFI_DeviceToViewDepth.z, (tan(_6436.y) * sqrt(1.0f + (_6439 * _6439))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9941 = _9915 + (_5841 * _4163);
        }
        float _4168 = 1.0f - cbFI_Timestep;
        float2 _9942;
        if (_5869)
        {
            float2 _6507 = clamp((((_9915 + (_5841 * _4168)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6510 = tan(_6507.x);
            _9942 = (float2(_6510 / cbFI_DeviceToViewDepth.z, (tan(_6507.y) * sqrt(1.0f + (_6510 * _6510))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9942 = _9915 + (_5841 * _4168);
        }
        float4 _6545 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9938, 0.0f);
        float3 _6546 = _6545.xyz;
        float4 _6553 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9940, 0.0f);
        float3 _6554 = _6553.xyz;
        float4 _6561 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9941, 0.0f);
        float3 _6562 = _6561.xyz;
        float4 _6569 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9942, 0.0f);
        float3 _6570 = _6569.xyz;
        float4 _6584 = exp(_5835 - max(max(max(_5835.x, _5835.y), _5835.z), _5835.w).xxxx);
        float4 _6591 = _6584 / (dot(_6584, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4187 = _3980 && (!_9957);
        bool _4196;
        if (_4187)
        {
            _4196 = (_6591.z + _6591.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4196 = _4187;
        }
        bool _4207;
        if (_4196)
        {
            _4207 = length((_9941 - _9938) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4207 = _4196;
        }
        bool _9981;
        if (_4207)
        {
            uint4 _6610 = r_warped_motion_qdata_tp1.Load(int3(_9968, 0));
            uint _6611 = _6610.x;
            bool _9984;
            if (_6611 != 0u)
            {
                float _9970;
                if (_6611 == 0u)
                {
                    _9970 = -1.0f;
                }
                else
                {
                    _9970 = float((_6611 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4217 = _9970 - 0.12000000476837158203125f;
                bool _6630 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
                bool _6636;
                if (_6630)
                {
                    _6636 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
                }
                else
                {
                    _6636 = _6630;
                }
                bool _4227;
                if (_6636)
                {
                    uint _6643_dummy_parameter;
                    _4227 = (log((r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6643_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4217;
                }
                else
                {
                    _4227 = _6636;
                }
                bool _4241;
                if (!_4227)
                {
                    bool _6673 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
                    bool _6679;
                    if (_6673)
                    {
                        _6679 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6679 = _6673;
                    }
                    bool _4239;
                    if (_6679)
                    {
                        uint _6686_dummy_parameter;
                        _4239 = (log((r_depth_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6686_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4217;
                    }
                    else
                    {
                        _4239 = _6679;
                    }
                    _4241 = _4239;
                }
                else
                {
                    _4241 = _4227;
                }
                _9984 = _4241;
            }
            else
            {
                _9984 = false;
            }
            _9981 = _9984;
        }
        else
        {
            _9981 = false;
        }
        bool _4246 = _9957 || _9981;
        bool _4251;
        if (_4246)
        {
            bool _6716 = all(bool2(_9938.x > 0.0f.xx.x, _9938.y > 0.0f.xx.y));
            bool _6722;
            if (_6716)
            {
                _6722 = all(bool2(_9938.x < 1.0f.xx.x, _9938.y < 1.0f.xx.y));
            }
            else
            {
                _6722 = _6716;
            }
            _4251 = _6722;
        }
        else
        {
            _4251 = _4246;
        }
        bool _4256;
        if (_4251)
        {
            bool _6727 = all(bool2(_9940.x > 0.0f.xx.x, _9940.y > 0.0f.xx.y));
            bool _6733;
            if (_6727)
            {
                _6733 = all(bool2(_9940.x < 1.0f.xx.x, _9940.y < 1.0f.xx.y));
            }
            else
            {
                _6733 = _6727;
            }
            _4256 = _6733;
        }
        else
        {
            _4256 = _4251;
        }
        float4 _10078;
        if (_4256)
        {
            float _4259 = _6591.x;
            float _4261 = _6591.y;
            float _4262 = _4259 + _4261;
            float _4267 = _6591.z + _6591.w;
            float _9999;
            if (_4262 > 0.001000000047497451305389404296875f)
            {
                _9999 = _4259 / _4262;
            }
            else
            {
                _9999 = _4168;
            }
            _10078 = float4(_4259 + (_4267 * _9999), _4261 + (_4267 * (1.0f - _9999)), 0.0f, 0.0f);
        }
        else
        {
            _10078 = _6591;
        }
        bool _6761 = (cbFI_pad0 & 1024u) != 0u;
        bool _6737 = !_6761;
        bool _6738 = !_6737;
        bool _6755;
        if (_6738)
        {
            _6755 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9968.y * cbFI_MvDepthLaneSize.x) + _9968.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6755 = _6737;
        }
        bool _6787;
        if (_6738)
        {
            _6787 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3959.y * cbFI_FlowLaneSize.x) + _3959.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6787 = _6737;
        }
        float _4302 = float(_6787);
        bool _10091;
        float4 _10176;
        float3 _11130;
        if (_6761)
        {
            bool _4312;
            if (_6755)
            {
                _4312 = all(bool2(_9938.x > 0.0f.xx.x, _9938.y > 0.0f.xx.y));
            }
            else
            {
                _4312 = _6755;
            }
            bool _4318;
            if (_4312)
            {
                _4318 = all(bool2(_9938.x < 1.0f.xx.x, _9938.y < 1.0f.xx.y));
            }
            else
            {
                _4318 = _4312;
            }
            bool _4325;
            if (_6755)
            {
                _4325 = all(bool2(_9940.x > 0.0f.xx.x, _9940.y > 0.0f.xx.y));
            }
            else
            {
                _4325 = _6755;
            }
            bool _4331;
            if (_4325)
            {
                _4331 = all(bool2(_9940.x < 1.0f.xx.x, _9940.y < 1.0f.xx.y));
            }
            else
            {
                _4331 = _4325;
            }
            bool _4338;
            if (_6787)
            {
                _4338 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
            }
            else
            {
                _4338 = _6787;
            }
            bool _4344;
            if (_4338)
            {
                _4344 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
            }
            else
            {
                _4344 = _4338;
            }
            bool _4351;
            if (_6787)
            {
                _4351 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
            }
            else
            {
                _4351 = _6787;
            }
            bool _4357;
            if (_4351)
            {
                _4357 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
            }
            else
            {
                _4357 = _4351;
            }
            bool _4359 = !_6755;
            if (_4359)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6829;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6829);
                }
            }
            bool _4364 = !_6787;
            if (_4364)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6839;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6839);
                }
            }
            if (_6755 && _4364)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6849;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6849);
                }
            }
            if (_4359 && _6787)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6859;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6859);
                }
            }
            float _4383 = float(_4318);
            float _4385 = float(_4331);
            bool _4388 = _4344 && _4357;
            float _10033;
            if (_4388)
            {
                _10033 = 1.0f;
            }
            else
            {
                _10033 = (_4344 || _4357) ? 0.5f : 0.0f;
            }
            bool _10038;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4318)) && (!_4331))
            {
                bool _4418;
                if (_4388)
                {
                    float _10036;
                    do
                    {
                        bool _6943 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
                        bool _6949;
                        if (_6943)
                        {
                            _6949 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6949 = _6943;
                        }
                        bool _6880 = !_6949;
                        bool _6887;
                        if (!_6880)
                        {
                            bool _6954 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
                            bool _6960;
                            if (_6954)
                            {
                                _6960 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
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
                            _10036 = 0.0f;
                            break;
                        }
                        uint _6967_dummy_parameter;
                        uint _6983_dummy_parameter;
                        float4 _6908 = mul(float4((float2(_9941.x, 1.0f - _9941.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6967_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6910 = _6908.w;
                        if (abs(_6910) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10036 = 0.0f;
                            break;
                        }
                        float _6921 = abs(cbFI_DeviceToViewDepth.y / ((_6908.z / _6910) - cbFI_DeviceToViewDepth.x));
                        float _6924 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6983_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10036 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6921 - _6924) / max(max(_6921, _6924), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4418 = _10036 >= 0.5f;
                }
                else
                {
                    _4418 = _4388;
                }
                bool _4426;
                if (_4418)
                {
                    _4426 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4426 = _4418;
                }
                bool _10039;
                if (_4426)
                {
                    uint _7033_dummy_parameter;
                    float2 _10037;
                    do
                    {
                        float _7059 = 1.0f - _9941.y;
                        float4 _7070 = mul(float4((float2(_9941.x, _7059) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7033_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7072 = _7070.w;
                        if (!(_7072 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10037 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7085 = ((_7070.xy / _7072.xx) + 1.0f.xx) * 0.5f;
                        _10037 = float2(_7085.x - _9941.x, _7059 - _7085.y);
                        break;
                    } while(false);
                    float2 _4439 = float2(cbFI_DisplaySize);
                    _10039 = length(((_9941 + _10037) - _9942) * _4439) <= ((0.100000001490116119384765625f * length(_10037 * _4439)) + 8.0f);
                }
                else
                {
                    _10039 = _4418;
                }
                _10038 = _10039;
            }
            else
            {
                _10038 = true;
            }
            bool _4453 = !_10038;
            bool _11878 = _4453 ? false : _4357;
            bool _11879 = _4453 ? false : _4344;
            bool _10092;
            float4 _10177;
            if (!(((_4318 && _4331) && _11879) && _11878))
            {
                float4 _4475 = _10078 * float4(_4383, _4385, float(_11879), float(_11878));
                float _4477 = dot(_4475, 1.0f.xxxx);
                bool _4480 = !(_4477 > 0.0f);
                float4 _10178;
                if (!_4480)
                {
                    _10178 = _4475 / _4477.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7107;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7107);
                    }
                    _10178 = 0.0f.xxxx;
                }
                _10177 = _10178;
                _10092 = _4480;
            }
            else
            {
                _10177 = _10078;
                _10092 = false;
            }
            _11130 = float3(_4383, _4385, _10033);
            _10176 = _10177;
            _10091 = _10092;
        }
        else
        {
            _11130 = float3(float(_6755), _4302, 0.0f);
            _10176 = _10078;
            _10091 = false;
        }
        bool _4498 = !_10091;
        float4 _10274;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4498) && _6755)
        {
            float _10173;
            do
            {
                uint4 _7247 = r_warped_motion_qdata_tp1.Load(int3(_9968, 0));
                uint _7248 = _7247.x;
                if (_7248 != 0u)
                {
                    float _10172;
                    if (_7248 == 0u)
                    {
                        _10172 = -1.0f;
                    }
                    else
                    {
                        _10172 = float((_7248 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10173 = _10172;
                    break;
                }
                int _10155;
                uint _10156;
                _10156 = _7248;
                _10155 = -1;
                uint _10171;
                for (; _10155 <= 1; _10156 = _10171, _10155++)
                {
                    _10171 = _10156;
                    for (int _10169 = -1; _10169 <= 1; )
                    {
                        _10171 = max(_10171, r_warped_motion_qdata_tp1.Load(int3(clamp(_9968 + int2(_10169, _10155), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10169++;
                        continue;
                    }
                }
                if (_10156 != 0u)
                {
                    float _10168;
                    if (_10156 == 0u)
                    {
                        _10168 = -1.0f;
                    }
                    else
                    {
                        _10168 = float((_10156 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10173 = _10168;
                    break;
                }
                uint _10158;
                _10158 = 4294967295u;
                uint _11849;
                for (int _10157 = 0; _10157 < 8; _10158 = _11849, _10157++)
                {
                    int _10161 = 0;
                    for (;;)
                    {
                        if (_10161 < 5)
                        {
                            int2 _7198 = _9968 + (_1085[_10157] * _1094[_10161].xx);
                            bool _7201 = any(bool2(_7198.x < int2(0, 0).x, _7198.y < int2(0, 0).y));
                            bool _7209;
                            if (!_7201)
                            {
                                _7209 = any(bool2(_7198.x >= cbFI_MvDepthLaneSize.x, _7198.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7209 = _7201;
                            }
                            if (_7209)
                            {
                                _11849 = _10158;
                                break;
                            }
                            uint4 _7287 = r_warped_motion_qdata_tp1.Load(int3(_7198, 0));
                            uint _7288 = _7287.x;
                            if (_7288 != 0u)
                            {
                                _11849 = min(_10158, _7288);
                                break;
                            }
                            _10161++;
                            continue;
                        }
                        else
                        {
                            _11849 = _10158;
                            break;
                        }
                    }
                }
                float _10160;
                if (_10158 == 4294967295u)
                {
                    _10160 = -1.0f;
                }
                else
                {
                    float _10159;
                    if (_10158 == 0u)
                    {
                        _10159 = -1.0f;
                    }
                    else
                    {
                        _10159 = float((_10158 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10160 = _10159;
                }
                _10173 = _10160;
                break;
            } while(false);
            float _4509 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4513 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4519;
            if (_4513)
            {
                _4519 = _10176.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4519 = _4513;
            }
            bool _4524;
            if (_4519)
            {
                bool _7307 = all(bool2(_9940.x > 0.0f.xx.x, _9940.y > 0.0f.xx.y));
                bool _7313;
                if (_7307)
                {
                    _7313 = all(bool2(_9940.x < 1.0f.xx.x, _9940.y < 1.0f.xx.y));
                }
                else
                {
                    _7313 = _7307;
                }
                _4524 = _7313;
            }
            else
            {
                _4524 = _4519;
            }
            float4 _10219;
            if (_4524)
            {
                float _10194;
                if (_10173 >= 0.0f)
                {
                    _10194 = _10173 - _4509;
                }
                else
                {
                    float _10190;
                    _10190 = 2.0f;
                    float _7370;
                    for (int _10189 = 0; _10189 < 24; _10190 = _7370, _10189++)
                    {
                        float _7334 = float(_10189 & 7) * 0.785398185253143310546875f;
                        int _7336 = _10189 >> 3;
                        int _10191;
                        if (_7336 == 0)
                        {
                            _10191 = 16;
                        }
                        else
                        {
                            _10191 = (_7336 == 1) ? 48 : 96;
                        }
                        uint _7402_dummy_parameter;
                        _7370 = min(_10190, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9940 + ((cbFI_MvDepthLaneSizeRcp * float(_10191)) * float2(cos(_7334), sin(_7334))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7402_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10194 = _10190;
                }
                uint _7434_dummy_parameter;
                float4 _10220;
                if (r_depth_tp1.Load(int3(int2(floor(_9940 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7434_dummy_parameter))))), 0)).x > ((exp((_10194 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10220 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10220 = 1.0f.xxxx;
                }
                _10219 = _10220;
            }
            else
            {
                _10219 = 1.0f.xxxx;
            }
            bool _4551 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4557;
            if (_4551)
            {
                _4557 = _10176.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4557 = _4551;
            }
            bool _4562;
            if (_4557)
            {
                bool _7458 = all(bool2(_9938.x > 0.0f.xx.x, _9938.y > 0.0f.xx.y));
                bool _7464;
                if (_7458)
                {
                    _7464 = all(bool2(_9938.x < 1.0f.xx.x, _9938.y < 1.0f.xx.y));
                }
                else
                {
                    _7464 = _7458;
                }
                _4562 = _7464;
            }
            else
            {
                _4562 = _4557;
            }
            float4 _10223;
            if (_4562)
            {
                float _10214;
                if (_10173 >= 0.0f)
                {
                    _10214 = _10173 - _4509;
                }
                else
                {
                    float _10210;
                    _10210 = 2.0f;
                    float _7521;
                    for (int _10209 = 0; _10209 < 24; _10210 = _7521, _10209++)
                    {
                        float _7485 = float(_10209 & 7) * 0.785398185253143310546875f;
                        int _7487 = _10209 >> 3;
                        int _10211;
                        if (_7487 == 0)
                        {
                            _10211 = 16;
                        }
                        else
                        {
                            _10211 = (_7487 == 1) ? 48 : 96;
                        }
                        uint _7537_dummy_parameter;
                        _7521 = min(_10210, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9938 + ((cbFI_MvDepthLaneSizeRcp * float(_10211)) * float2(cos(_7485), sin(_7485))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7537_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10214 = _10210;
                }
                uint _7585_dummy_parameter;
                float4 _10224;
                if (r_depth_tm1.Load(int3(int2(floor(_9938 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7585_dummy_parameter))))), 0)).x > ((exp((_10214 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9784 = _10219;
                    _9784.x = 0.0f;
                    _10224 = _9784;
                }
                else
                {
                    _10224 = _10219;
                }
                _10223 = _10224;
            }
            else
            {
                _10223 = _10219;
            }
            float4 _10275;
            if (any(bool4(_10223.x < 1.0f.xxxx.x, _10223.y < 1.0f.xxxx.y, _10223.z < 1.0f.xxxx.z, _10223.w < 1.0f.xxxx.w)))
            {
                float4 _4592 = _10176 * _10223;
                float _4594 = dot(_4592, 1.0f.xxxx);
                float4 _10276;
                if (_4594 > 0.0f)
                {
                    _10276 = _4592 / _4594.xxxx;
                }
                else
                {
                    bool _4605 = _10223.y == 0.0f;
                    bool _4611;
                    if (_4605)
                    {
                        _4611 = _10223.x > 0.0f;
                    }
                    else
                    {
                        _4611 = _4605;
                    }
                    bool _4616;
                    if (_4611)
                    {
                        bool _7609 = all(bool2(_9938.x > 0.0f.xx.x, _9938.y > 0.0f.xx.y));
                        bool _7615;
                        if (_7609)
                        {
                            _7615 = all(bool2(_9938.x < 1.0f.xx.x, _9938.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7615 = _7609;
                        }
                        _4616 = _7615;
                    }
                    else
                    {
                        _4616 = _4611;
                    }
                    float4 _10277;
                    if (_4616)
                    {
                        _10277 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4621 = _10223.x == 0.0f;
                        bool _4627;
                        if (_4621)
                        {
                            _4627 = _10223.y > 0.0f;
                        }
                        else
                        {
                            _4627 = _4621;
                        }
                        bool _4632;
                        if (_4627)
                        {
                            bool _7620 = all(bool2(_9940.x > 0.0f.xx.x, _9940.y > 0.0f.xx.y));
                            bool _7626;
                            if (_7620)
                            {
                                _7626 = all(bool2(_9940.x < 1.0f.xx.x, _9940.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7626 = _7620;
                            }
                            _4632 = _7626;
                        }
                        else
                        {
                            _4632 = _4627;
                        }
                        bool4 _11880 = _4632.xxxx;
                        _10277 = float4(_11880.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10176.x, _11880.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10176.y, _11880.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10176.z, _11880.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10176.w);
                    }
                    _10276 = _10277;
                }
                _10275 = _10276;
            }
            else
            {
                _10275 = _10176;
            }
            _10274 = _10275;
        }
        else
        {
            _10274 = _10176;
        }
        float4 _10818;
        bool _10838;
        float3 _10952;
        if (((cbFI_pad0 & 32768u) != 0u) && _4498)
        {
            bool _4649 = _10274.x > 0.00999999977648258209228515625f;
            bool _4652 = _10274.y > 0.00999999977648258209228515625f;
            bool _4661 = (_10274.z + _10274.w) > 0.0199999995529651641845703125f;
            bool _4667;
            if (_4661)
            {
                bool _7631 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
                bool _7637;
                if (_7631)
                {
                    _7637 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
                }
                else
                {
                    _7637 = _7631;
                }
                _4667 = _7637;
            }
            else
            {
                _4667 = _4661;
            }
            bool _4672;
            if (_4667)
            {
                bool _7642 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
                bool _7648;
                if (_7642)
                {
                    _7648 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
                }
                else
                {
                    _7648 = _7642;
                }
                _4672 = _7648;
            }
            else
            {
                _4672 = _4667;
            }
            bool _4679;
            if (_4672)
            {
                float _10285;
                do
                {
                    bool _7731 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
                    bool _7737;
                    if (_7731)
                    {
                        _7737 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7737 = _7731;
                    }
                    bool _7668 = !_7737;
                    bool _7675;
                    if (!_7668)
                    {
                        bool _7742 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
                        bool _7748;
                        if (_7742)
                        {
                            _7748 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7748 = _7742;
                        }
                        _7675 = !_7748;
                    }
                    else
                    {
                        _7675 = _7668;
                    }
                    if (_7675)
                    {
                        _10285 = 0.0f;
                        break;
                    }
                    uint _7755_dummy_parameter;
                    uint _7771_dummy_parameter;
                    float4 _7696 = mul(float4((float2(_9941.x, 1.0f - _9941.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7755_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7698 = _7696.w;
                    if (abs(_7698) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10285 = 0.0f;
                        break;
                    }
                    float _7709 = abs(cbFI_DeviceToViewDepth.y / ((_7696.z / _7698) - cbFI_DeviceToViewDepth.x));
                    float _7712 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7771_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10285 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7709 - _7712) / max(max(_7709, _7712), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4679 = _10285 < 0.5f;
            }
            else
            {
                _4679 = _4672;
            }
            float4 _10300;
            if (_4679)
            {
                uint _7821_dummy_parameter;
                uint _7852_dummy_parameter;
                float4 _10301;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7821_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7852_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10301 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10301 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10300 = _10301;
            }
            else
            {
                _10300 = 1.0f.xxxx;
            }
            bool _4703;
            if (_6755)
            {
                bool _7881 = all(bool2(_9938.x > 0.0f.xx.x, _9938.y > 0.0f.xx.y));
                bool _7887;
                if (_7881)
                {
                    _7887 = all(bool2(_9938.x < 1.0f.xx.x, _9938.y < 1.0f.xx.y));
                }
                else
                {
                    _7887 = _7881;
                }
                _4703 = _7887;
            }
            else
            {
                _4703 = _6755;
            }
            bool _4709;
            if (_6755)
            {
                bool _7892 = all(bool2(_9940.x > 0.0f.xx.x, _9940.y > 0.0f.xx.y));
                bool _7898;
                if (_7892)
                {
                    _7898 = all(bool2(_9940.x < 1.0f.xx.x, _9940.y < 1.0f.xx.y));
                }
                else
                {
                    _7898 = _7892;
                }
                _4709 = _7898;
            }
            else
            {
                _4709 = _6755;
            }
            bool _4715;
            if (_6787)
            {
                bool _7903 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
                bool _7909;
                if (_7903)
                {
                    _7909 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
                }
                else
                {
                    _7909 = _7903;
                }
                _4715 = _7909;
            }
            else
            {
                _4715 = _6787;
            }
            bool _4721;
            if (_6787)
            {
                bool _7914 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
                bool _7920;
                if (_7914)
                {
                    _7920 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
                }
                else
                {
                    _7920 = _7914;
                }
                _4721 = _7920;
            }
            else
            {
                _4721 = _6787;
            }
            bool _4724 = _4715 != _4721;
            bool _4730;
            if (_4724)
            {
                _4730 = _4703 || _4709;
            }
            else
            {
                _4730 = _4724;
            }
            float4 _10388;
            if (_4730)
            {
                float4 _9811 = _10300;
                _9811.z = 0.0f;
                _9811.w = 0.0f;
                _10388 = _9811;
            }
            else
            {
                _10388 = _10300;
            }
            bool _4737 = _4703 && _4649;
            bool _4740 = _4709 && _4652;
            float4 _10493;
            float3 _11029;
            if (_4737 || _4740)
            {
                float _10383;
                do
                {
                    uint4 _8059 = r_warped_motion_qdata_tp1.Load(int3(_9968, 0));
                    uint _8060 = _8059.x;
                    if (_8060 != 0u)
                    {
                        float _10382;
                        if (_8060 == 0u)
                        {
                            _10382 = -1.0f;
                        }
                        else
                        {
                            _10382 = float((_8060 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10383 = _10382;
                        break;
                    }
                    int _10365;
                    uint _10366;
                    _10366 = _8060;
                    _10365 = -1;
                    uint _10381;
                    for (; _10365 <= 1; _10366 = _10381, _10365++)
                    {
                        _10381 = _10366;
                        for (int _10379 = -1; _10379 <= 1; )
                        {
                            _10381 = max(_10381, r_warped_motion_qdata_tp1.Load(int3(clamp(_9968 + int2(_10379, _10365), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10379++;
                            continue;
                        }
                    }
                    if (_10366 != 0u)
                    {
                        float _10378;
                        if (_10366 == 0u)
                        {
                            _10378 = -1.0f;
                        }
                        else
                        {
                            _10378 = float((_10366 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10383 = _10378;
                        break;
                    }
                    uint _10368;
                    _10368 = 4294967295u;
                    uint _11850;
                    for (int _10367 = 0; _10367 < 8; _10368 = _11850, _10367++)
                    {
                        int _10371 = 0;
                        for (;;)
                        {
                            if (_10371 < 5)
                            {
                                int2 _8010 = _9968 + (_1085[_10367] * _1094[_10371].xx);
                                bool _8013 = any(bool2(_8010.x < int2(0, 0).x, _8010.y < int2(0, 0).y));
                                bool _8021;
                                if (!_8013)
                                {
                                    _8021 = any(bool2(_8010.x >= cbFI_MvDepthLaneSize.x, _8010.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8021 = _8013;
                                }
                                if (_8021)
                                {
                                    _11850 = _10368;
                                    break;
                                }
                                uint4 _8099 = r_warped_motion_qdata_tp1.Load(int3(_8010, 0));
                                uint _8100 = _8099.x;
                                if (_8100 != 0u)
                                {
                                    _11850 = min(_10368, _8100);
                                    break;
                                }
                                _10371++;
                                continue;
                            }
                            else
                            {
                                _11850 = _10368;
                                break;
                            }
                        }
                    }
                    float _10370;
                    if (_10368 == 4294967295u)
                    {
                        _10370 = -1.0f;
                    }
                    else
                    {
                        float _10369;
                        if (_10368 == 0u)
                        {
                            _10369 = -1.0f;
                        }
                        else
                        {
                            _10369 = float((_10368 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10370 = _10369;
                    }
                    _10383 = _10370;
                    break;
                } while(false);
                bool _4748 = _10383 < 0.0f;
                float _10384;
                if (_4748)
                {
                    _10384 = 0.0f;
                }
                else
                {
                    _10384 = _10383 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8121_dummy_parameter;
                uint _8153_dummy_parameter;
                float4 _10421;
                if ((_4748 && _4737) && _4740)
                {
                    uint _8185_dummy_parameter;
                    float _8209 = log((r_depth_tm1.Load(int3(int2(floor(_9938 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8185_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8217_dummy_parameter;
                    float _8241 = log((r_depth_tp1.Load(int3(int2(floor(_9940 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8217_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10422;
                    if (_8209 > (_8241 + 0.07999999821186065673828125f))
                    {
                        float4 _9815 = _10388;
                        _9815.x = 0.0f;
                        _10422 = _9815;
                    }
                    else
                    {
                        float4 _10423;
                        if (_8241 > (_8209 + 0.07999999821186065673828125f))
                        {
                            float4 _9817 = _10388;
                            _9817.y = 0.0f;
                            _10423 = _9817;
                        }
                        else
                        {
                            _10423 = _10388;
                        }
                        _10422 = _10423;
                    }
                    _10421 = _10422;
                }
                else
                {
                    _10421 = _10388;
                }
                float _4800 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4802 = _10383 >= 0.0f;
                float _10404;
                if (_4802)
                {
                    _10404 = _10383 - _4800;
                }
                else
                {
                    float _10400;
                    if (_4737)
                    {
                        float _10399;
                        _10399 = 2.0f;
                        float _8299;
                        for (int _10398 = 0; _10398 < 24; _10399 = _8299, _10398++)
                        {
                            float _8263 = float(_10398 & 7) * 0.785398185253143310546875f;
                            int _8265 = _10398 >> 3;
                            int _10401;
                            if (_8265 == 0)
                            {
                                _10401 = 16;
                            }
                            else
                            {
                                _10401 = (_8265 == 1) ? 48 : 96;
                            }
                            uint _8315_dummy_parameter;
                            _8299 = min(_10399, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9938 + ((cbFI_MvDepthLaneSizeRcp * float(_10401)) * float2(cos(_8263), sin(_8263))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8315_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10400 = _10399;
                    }
                    else
                    {
                        _10400 = 0.0f;
                    }
                    _10404 = _10400;
                }
                float _10411;
                if (_4802)
                {
                    _10411 = _10383 - _4800;
                }
                else
                {
                    float _10407;
                    if (_4740)
                    {
                        float _10406;
                        _10406 = 2.0f;
                        float _8413;
                        for (int _10405 = 0; _10405 < 24; _10406 = _8413, _10405++)
                        {
                            float _8377 = float(_10405 & 7) * 0.785398185253143310546875f;
                            int _8379 = _10405 >> 3;
                            int _10408;
                            if (_8379 == 0)
                            {
                                _10408 = 16;
                            }
                            else
                            {
                                _10408 = (_8379 == 1) ? 48 : 96;
                            }
                            uint _8445_dummy_parameter;
                            _8413 = min(_10406, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9940 + ((cbFI_MvDepthLaneSizeRcp * float(_10408)) * float2(cos(_8377), sin(_8377))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8445_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10407 = _10406;
                    }
                    else
                    {
                        _10407 = 0.0f;
                    }
                    _10411 = _10407;
                }
                float _10412;
                if (_4737)
                {
                    uint _8477_dummy_parameter;
                    _10412 = r_depth_tm1.Load(int3(int2(floor(_9938 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8477_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10412 = 0.0f;
                }
                float _10413;
                if (_4740)
                {
                    uint _8496_dummy_parameter;
                    _10413 = r_depth_tp1.Load(int3(int2(floor(_9940 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8496_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10413 = 0.0f;
                }
                bool _4857;
                if (_4737)
                {
                    _4857 = _10412 > ((exp((_10404 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4857 = _4737;
                }
                float4 _10429;
                if (_4857)
                {
                    float4 _9819 = _10421;
                    _9819.x = 0.0f;
                    _10429 = _9819;
                }
                else
                {
                    _10429 = _10421;
                }
                bool _4869;
                if (_4740)
                {
                    _4869 = _10413 > ((exp((_10411 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4869 = _4740;
                }
                float4 _10431;
                if (_4869)
                {
                    float4 _9821 = _10429;
                    _9821.y = 0.0f;
                    _10431 = _9821;
                }
                else
                {
                    _10431 = _10429;
                }
                float4 _10494;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4802)
                {
                    bool _4889;
                    if (_4737)
                    {
                        _4889 = _10412 < ((exp((_10404 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4889 = _4737;
                    }
                    float4 _10433;
                    if (_4889)
                    {
                        float4 _9823 = _10431;
                        _9823.x = 0.0f;
                        _10433 = _9823;
                    }
                    else
                    {
                        _10433 = _10431;
                    }
                    bool _4901;
                    if (_4740)
                    {
                        _4901 = _10413 < ((exp((_10411 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4901 = _4740;
                    }
                    float4 _10495;
                    if (_4901)
                    {
                        float4 _9825 = _10433;
                        _9825.y = 0.0f;
                        _10495 = _9825;
                    }
                    else
                    {
                        _10495 = _10433;
                    }
                    _10494 = _10495;
                }
                else
                {
                    _10494 = _10431;
                }
                _11029 = float3(_10384, log((r_depth_tm1.Load(int3(int2(floor(_9938 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8121_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9940 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8153_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10493 = _10494;
            }
            else
            {
                _11029 = float3(0.0f, 0.0f, 0.5f);
                _10493 = _10388;
            }
            bool _4912 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4661;
            bool _4918;
            if (_4912)
            {
                _4918 = _4715 || _4721;
            }
            else
            {
                _4918 = _4912;
            }
            float4 _10516;
            if (_4918)
            {
                float _10488;
                do
                {
                    uint4 _8675 = r_warped_motion_qdata_tp1.Load(int3(_9968, 0));
                    uint _8676 = _8675.x;
                    if (_8676 != 0u)
                    {
                        float _10487;
                        if (_8676 == 0u)
                        {
                            _10487 = -1.0f;
                        }
                        else
                        {
                            _10487 = float((_8676 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10488 = _10487;
                        break;
                    }
                    int _10470;
                    uint _10471;
                    _10471 = _8676;
                    _10470 = -1;
                    uint _10486;
                    for (; _10470 <= 1; _10471 = _10486, _10470++)
                    {
                        _10486 = _10471;
                        for (int _10484 = -1; _10484 <= 1; )
                        {
                            _10486 = max(_10486, r_warped_motion_qdata_tp1.Load(int3(clamp(_9968 + int2(_10484, _10470), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10484++;
                            continue;
                        }
                    }
                    if (_10471 != 0u)
                    {
                        float _10483;
                        if (_10471 == 0u)
                        {
                            _10483 = -1.0f;
                        }
                        else
                        {
                            _10483 = float((_10471 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10488 = _10483;
                        break;
                    }
                    uint _10473;
                    _10473 = 4294967295u;
                    uint _11851;
                    for (int _10472 = 0; _10472 < 8; _10473 = _11851, _10472++)
                    {
                        int _10476 = 0;
                        for (;;)
                        {
                            if (_10476 < 5)
                            {
                                int2 _8626 = _9968 + (_1085[_10472] * _1094[_10476].xx);
                                bool _8629 = any(bool2(_8626.x < int2(0, 0).x, _8626.y < int2(0, 0).y));
                                bool _8637;
                                if (!_8629)
                                {
                                    _8637 = any(bool2(_8626.x >= cbFI_MvDepthLaneSize.x, _8626.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8637 = _8629;
                                }
                                if (_8637)
                                {
                                    _11851 = _10473;
                                    break;
                                }
                                uint4 _8715 = r_warped_motion_qdata_tp1.Load(int3(_8626, 0));
                                uint _8716 = _8715.x;
                                if (_8716 != 0u)
                                {
                                    _11851 = min(_10473, _8716);
                                    break;
                                }
                                _10476++;
                                continue;
                            }
                            else
                            {
                                _11851 = _10473;
                                break;
                            }
                        }
                    }
                    float _10475;
                    if (_10473 == 4294967295u)
                    {
                        _10475 = -1.0f;
                    }
                    else
                    {
                        float _10474;
                        if (_10473 == 0u)
                        {
                            _10474 = -1.0f;
                        }
                        else
                        {
                            _10474 = float((_10473 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10475 = _10474;
                    }
                    _10488 = _10475;
                    break;
                } while(false);
                float4 _10517;
                if (_10488 >= 0.0f)
                {
                    float _8737 = (exp((_10488 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4937;
                    if (_4715)
                    {
                        uint _8744_dummy_parameter;
                        _4937 = r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8744_dummy_parameter))))), 0)).x > _8737;
                    }
                    else
                    {
                        _4937 = _4715;
                    }
                    float4 _10506;
                    if (_4937)
                    {
                        float4 _9827 = _10493;
                        _9827.z = 0.0f;
                        _10506 = _9827;
                    }
                    else
                    {
                        _10506 = _10493;
                    }
                    bool _4949;
                    if (_4721)
                    {
                        uint _8763_dummy_parameter;
                        _4949 = r_depth_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8763_dummy_parameter))))), 0)).x > _8737;
                    }
                    else
                    {
                        _4949 = _4721;
                    }
                    float4 _10518;
                    if (_4949)
                    {
                        float4 _9829 = _10506;
                        _9829.w = 0.0f;
                        _10518 = _9829;
                    }
                    else
                    {
                        _10518 = _10506;
                    }
                    _10517 = _10518;
                }
                else
                {
                    _10517 = _10493;
                }
                _10516 = _10517;
            }
            else
            {
                _10516 = _10493;
            }
            bool _4957 = _4703 != _4709;
            bool _4964;
            if (_4957)
            {
                _4964 = _4703 ? _4649 : _4652;
            }
            else
            {
                _4964 = _4957;
            }
            bool _4971;
            if (_4964)
            {
                _4971 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4971 = _4964;
            }
            float4 _10601;
            if (_4971)
            {
                bool2 _4976 = _4703.xx;
                float2 _4977 = float2(_4976.x ? _9938.x : _9940.x, _4976.y ? _9938.y : _9940.y);
                float _10508;
                if (_4703)
                {
                    uint _8782_dummy_parameter;
                    _10508 = r_depth_tm1.Load(int3(int2(floor(_4977 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8782_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8798_dummy_parameter;
                    _10508 = r_depth_tp1.Load(int3(int2(floor(_4977 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8798_dummy_parameter))))), 0)).x;
                }
                float4x4 _10509;
                if (_4703)
                {
                    _10509 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10509 = cbFI_MotionTP1ToTM1;
                }
                float2 _10510;
                do
                {
                    float _8825 = _4977.x;
                    float _8828 = 1.0f - _4977.y;
                    float4 _8839 = mul(float4((float2(_8825, _8828) * 2.0f) - 1.0f.xx, _10508, 1.0f), _10509);
                    float _8841 = _8839.w;
                    if (!(_8841 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10510 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8854 = ((_8839.xy / _8841.xx) + 1.0f.xx) * 0.5f;
                    _10510 = float2(_8854.x - _8825, _8828 - _8854.y);
                    break;
                } while(false);
                float2 _5007 = float2(cbFI_DisplaySize);
                float4 _10602;
                if (!(length(((_4977 + _10510) - float2(_4976.x ? _9940.x : _9938.x, _4976.y ? _9940.y : _9938.y)) * _5007) <= ((0.100000001490116119384765625f * length(_10510 * _5007)) + 8.0f)))
                {
                    float4 _10603;
                    if (_4703)
                    {
                        float4 _9839 = _10516;
                        _9839.x = 0.0f;
                        _10603 = _9839;
                    }
                    else
                    {
                        float4 _9841 = _10516;
                        _9841.y = 0.0f;
                        _10603 = _9841;
                    }
                    _10602 = _10603;
                }
                else
                {
                    _10602 = _10516;
                }
                _10601 = _10602;
            }
            else
            {
                _10601 = _10516;
            }
            float4 _5032 = _10274 * _10601;
            float _5034 = dot(_5032, 1.0f.xxxx);
            float4 _10819;
            bool _10839;
            if (_5034 > 0.0f)
            {
                _10839 = _10091;
                _10819 = _5032 / _5034.xxxx;
            }
            else
            {
                bool _5045 = any(bool4(_10601.x < 1.0f.xxxx.x, _10601.y < 1.0f.xxxx.y, _10601.z < 1.0f.xxxx.z, _10601.w < 1.0f.xxxx.w));
                if (_5045)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8876;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8876);
                    }
                }
                bool4 _11883 = _5045.xxxx;
                _10839 = _5045 ? true : _10091;
                _10819 = float4(_11883.x ? 0.0f.xxxx.x : _10274.x, _11883.y ? 0.0f.xxxx.y : _10274.y, _11883.z ? 0.0f.xxxx.z : _10274.z, _11883.w ? 0.0f.xxxx.w : _10274.w);
            }
            _10952 = _11029;
            _10838 = _10839;
            _10818 = _10819;
        }
        else
        {
            _10952 = float3(0.0f, 0.0f, 0.5f);
            _10838 = _10091;
            _10818 = _10274;
        }
        uint _5054 = (cbFI_pad0 >> 24u) & 31u;
        uint _5058 = (cbFI_pad0 >> 16u) & 255u;
        bool _5060 = _5054 != 0u;
        bool _5062 = _5058 == 12u;
        bool _5065 = _5058 == 13u;
        float4 _10835;
        if ((_5060 || _5062) || _5065)
        {
            float _10604;
            do
            {
                bool _8960 = all(bool2(_9941.x > 0.0f.xx.x, _9941.y > 0.0f.xx.y));
                bool _8966;
                if (_8960)
                {
                    _8966 = all(bool2(_9941.x < 1.0f.xx.x, _9941.y < 1.0f.xx.y));
                }
                else
                {
                    _8966 = _8960;
                }
                bool _8897 = !_8966;
                bool _8904;
                if (!_8897)
                {
                    bool _8971 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
                    bool _8977;
                    if (_8971)
                    {
                        _8977 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8977 = _8971;
                    }
                    _8904 = !_8977;
                }
                else
                {
                    _8904 = _8897;
                }
                if (_8904)
                {
                    _10604 = 0.0f;
                    break;
                }
                uint _8984_dummy_parameter;
                uint _9000_dummy_parameter;
                float4 _8925 = mul(float4((float2(_9941.x, 1.0f - _9941.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9941 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8984_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8927 = _8925.w;
                if (abs(_8927) < 9.9999999747524270787835121154785e-07f)
                {
                    _10604 = 0.0f;
                    break;
                }
                float _8938 = abs(cbFI_DeviceToViewDepth.y / ((_8925.z / _8927) - cbFI_DeviceToViewDepth.x));
                float _8941 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9000_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10604 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8938 - _8941) / max(max(_8938, _8941), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9048 = all(bool2(_9942.x > 0.0f.xx.x, _9942.y > 0.0f.xx.y));
            bool _9054;
            if (_9048)
            {
                _9054 = all(bool2(_9942.x < 1.0f.xx.x, _9942.y < 1.0f.xx.y));
            }
            else
            {
                _9054 = _9048;
            }
            float _10605;
            if (_9054)
            {
                uint _9061_dummy_parameter;
                _10605 = length((_5841 + (r_motion_tp1.Load(int3(int2(floor(_9942 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9061_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10605 = 1000000.0f;
            }
            float _10616;
            if ((_5054 & 1u) != 0u)
            {
                _10616 = _10604;
            }
            else
            {
                _10616 = 1.0f;
            }
            float _10617;
            if ((_5054 & 2u) != 0u)
            {
                _10617 = _10616 * (1.0f - smoothstep(2.0f, 8.0f, _10605));
            }
            else
            {
                _10617 = _10616;
            }
            float _10618;
            if ((_5054 & 4u) != 0u)
            {
                _10618 = _10617 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6562 - _6570) - length(_6546 - _6554))));
            }
            else
            {
                _10618 = _10617;
            }
            float _10829;
            if ((_5054 & 8u) != 0u)
            {
                _10829 = lerp(1.0f, _10618, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6546 - _6554)));
            }
            else
            {
                _10829 = _10618;
            }
            bool _5140 = (_5054 & 16u) != 0u;
            bool _5149;
            if (_5140)
            {
                _5149 = length(_9936 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5149 = _5140;
            }
            float _11885 = _5149 ? 1.0f : _10829;
            bool _5155 = _5060 && _6755;
            bool _5160;
            if (_5155)
            {
                bool _9086 = all(bool2(_9938.x > 0.0f.xx.x, _9938.y > 0.0f.xx.y));
                bool _9092;
                if (_9086)
                {
                    _9092 = all(bool2(_9938.x < 1.0f.xx.x, _9938.y < 1.0f.xx.y));
                }
                else
                {
                    _9092 = _9086;
                }
                _5160 = _9092;
            }
            else
            {
                _5160 = _5155;
            }
            bool _5165;
            if (_5160)
            {
                bool _9097 = all(bool2(_9940.x > 0.0f.xx.x, _9940.y > 0.0f.xx.y));
                bool _9103;
                if (_9097)
                {
                    _9103 = all(bool2(_9940.x < 1.0f.xx.x, _9940.y < 1.0f.xx.y));
                }
                else
                {
                    _9103 = _9097;
                }
                _5165 = _9103;
            }
            else
            {
                _5165 = _5160;
            }
            float4 _10836;
            if (_5165)
            {
                float _5171 = _10818.x + _10818.y;
                float _5180 = (_10818.z + _10818.w) * (1.0f - _11885);
                float _10832;
                if (_5171 > 9.9999997473787516355514526367188e-06f)
                {
                    _10832 = _10818.x / _5171;
                }
                else
                {
                    _10832 = _4168;
                }
                _10836 = float4(_10818.x + (_5180 * _10832), _10818.y + (_5180 * (1.0f - _10832)), _10818.zw * _11885);
            }
            else
            {
                _10836 = _10818;
            }
            _10835 = _10836;
        }
        else
        {
            _10835 = _10818;
        }
        float3 _11653;
        if (_10838)
        {
            float3 _9109 = r_current_interpolation_source.Load(int3(_3557, 0)).xyz;
            float3 _11654;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6755)
            {
                uint _9116_dummy_parameter;
                float _10943;
                _10943 = r_depth_tm1.Load(int3(int2(floor(_9938 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9116_dummy_parameter))))), 0)).x;
                float _5292;
                for (int _10942 = 0; _10942 < 24; _10943 = _5292, _10942++)
                {
                    float _5264 = float(_10942 & 7) * 0.785398185253143310546875f;
                    int _5266 = _10942 >> 3;
                    int _11704;
                    if (_5266 == 0)
                    {
                        _11704 = 16;
                    }
                    else
                    {
                        _11704 = (_5266 == 1) ? 48 : 96;
                    }
                    uint _9136_dummy_parameter;
                    _5292 = min(_10943, r_depth_tm1.Load(int3(int2(floor(clamp(_9938 + ((cbFI_MvDepthLaneSizeRcp * float(_11704)) * float2(cos(_5264), sin(_5264))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9136_dummy_parameter))))), 0)).x);
                }
                float2 _10944;
                do
                {
                    float _9158 = 1.0f - _9938.y;
                    float4 _9169 = mul(float4((float2(_9938.x, _9158) * 2.0f) - 1.0f.xx, _10943, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9171 = _9169.w;
                    if (!(_9171 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10944 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9184 = ((_9169.xy / _9171.xx) + 1.0f.xx) * 0.5f;
                    _10944 = float2(_9184.x - _9938.x, _9158 - _9184.y);
                    break;
                } while(false);
                float2 _5303 = _9938 + _10944;
                bool _9202 = all(bool2(_5303.x > 0.0f.xx.x, _5303.y > 0.0f.xx.y));
                bool _9208;
                if (_9202)
                {
                    _9208 = all(bool2(_5303.x < 1.0f.xx.x, _5303.y < 1.0f.xx.y));
                }
                else
                {
                    _9208 = _9202;
                }
                float3 _11655;
                if (_9208)
                {
                    float _5309 = abs(cbFI_DeviceToViewDepth.y / (_10943 - cbFI_DeviceToViewDepth.x));
                    uint _9228_dummy_parameter;
                    int2 _9228 = int2(spvTextureSize(r_depth_m2, uint(0), _9228_dummy_parameter));
                    float _5313 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5303 * float2(_9228))), int2(0, 0), _9228 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11660;
                    if (abs(_5313 - _5309) <= (0.20000000298023223876953125f * max(_5313, _5309)))
                    {
                        uint _9262_dummy_parameter;
                        int2 _9262 = int2(spvTextureSize(r_colour_m2, uint(0), _9262_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9285;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9285);
                        }
                        _11660 = r_colour_m2.Load(int3(clamp(int2(floor(_5303 * float2(_9262))), int2(0, 0), _9262 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9295;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9295);
                        }
                        _11660 = _9109;
                    }
                    _11655 = _11660;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9305;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9305);
                    }
                    _11655 = _9109;
                }
                _11654 = _11655;
            }
            else
            {
                _11654 = _9109;
            }
            _11653 = _11654;
        }
        else
        {
            _11653 = (((_6546 * _10835.x) + (_6554 * _10835.y)) + (_6562 * _10835.z)) + (_6570 * _10835.w);
        }
        uint _5341 = cbFI_pad0 & 255u;
        bool _11545;
        float3 _11652;
        if (_5341 != 0u)
        {
            float3 _5346 = r_present_backbuffer.Load(int3(_3557, 0)).xyz;
            float3 _5350 = r_current_interpolation_source.Load(int3(_3557, 0)).xyz;
            float3 _5354 = abs(_5346 - _5350);
            float3 _10947;
            if (_5341 == 2u)
            {
                _10947 = (abs(_5350) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _10947 = 0.000244140625f.xxx;
            }
            bool _5370 = any(bool3(_5354.x > _10947.x, _5354.y > _10947.y, _5354.z > _10947.z));
            bool3 _11886 = _5370.xxx;
            _11652 = float3(_11886.x ? _5346.x : _11653.x, _11886.y ? _5346.y : _11653.y, _11886.z ? _5346.z : _11653.z);
            _11545 = _5370;
        }
        else
        {
            _11652 = _11653;
            _11545 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9320;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9320);
        }
        float3 _11635;
        if (_5058 == 1u)
        {
            _11635 = lerp(_6546, _6554, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11636;
            if (_5058 == 2u)
            {
                _11636 = lerp(_6562, _6570, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11637;
                if (_5058 == 3u)
                {
                    _11637 = float(_11545).xxx;
                }
                else
                {
                    float3 _11638;
                    if (_5058 == 4u)
                    {
                        _11638 = float3(((_9936 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11639;
                        if (_5058 == 5u)
                        {
                            _11639 = float3(((_5841 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11640;
                            if (_5058 == 6u)
                            {
                                _11640 = float3(_10835.xy, _10835.z + _10835.w);
                            }
                            else
                            {
                                float3 _11641;
                                if (_5058 == 7u)
                                {
                                    _11641 = r_current_interpolation_source.Load(int3(_3557, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11642;
                                    if (_5058 == 8u)
                                    {
                                        _11642 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3943, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11643;
                                        if (_5062)
                                        {
                                            uint _9342_dummy_parameter;
                                            uint _9374_dummy_parameter;
                                            _11643 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3943 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9342_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3943 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9374_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11644;
                                            if (_5065)
                                            {
                                                _11644 = _6562;
                                            }
                                            else
                                            {
                                                float3 _11645;
                                                if (_5058 == 20u)
                                                {
                                                    _11645 = _6546;
                                                }
                                                else
                                                {
                                                    float3 _11646;
                                                    if (_5058 == 21u)
                                                    {
                                                        _11646 = _6554;
                                                    }
                                                    else
                                                    {
                                                        float3 _11647;
                                                        if (_5058 == 22u)
                                                        {
                                                            _11647 = _6570;
                                                        }
                                                        else
                                                        {
                                                            float3 _11648;
                                                            if (_5058 == 18u)
                                                            {
                                                                _11648 = _11314;
                                                            }
                                                            else
                                                            {
                                                                float3 _11649;
                                                                if (_5058 == 19u)
                                                                {
                                                                    _11649 = _11130;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11888 = (_5058 == 23u).xxx;
                                                                    _11649 = float3(_11888.x ? _10952.x : _11652.x, _11888.y ? _10952.y : _11652.y, _11888.z ? _10952.z : _11652.z);
                                                                }
                                                                _11648 = _11649;
                                                            }
                                                            _11647 = _11648;
                                                        }
                                                        _11646 = _11647;
                                                    }
                                                    _11645 = _11646;
                                                }
                                                _11644 = _11645;
                                            }
                                            _11643 = _11644;
                                        }
                                        _11642 = _11643;
                                    }
                                    _11641 = _11642;
                                }
                                _11640 = _11641;
                            }
                            _11639 = _11640;
                        }
                        _11638 = _11639;
                    }
                    _11637 = _11638;
                }
                _11636 = _11637;
            }
            _11635 = _11636;
        }
        float3 _11634;
        if ((_5058 >= 9u) && (_5058 <= 11u))
        {
            uint _5534 = 64u + uint((_9968.y * cbFI_MvDepthLaneSize.x) + _9968.x);
            uint _5538 = rw_nfru_diagnostics.Load<uint>(_5534 * 4 + 0) & 15u;
            float3 _11665;
            if (_5058 == 10u)
            {
                float3 _11633;
                if ((rw_nfru_diagnostics.Load<uint>(_5534 * 4 + 0) & 32u) != 0u)
                {
                    _11633 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11632;
                    if ((rw_nfru_diagnostics.Load<uint>(_5534 * 4 + 0) & 16u) != 0u)
                    {
                        _11632 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5559 = ((rw_nfru_diagnostics.Load<uint>(_5534 * 4 + 0) & 64u) != 0u).xxx;
                        _11632 = float3(_5559.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5559.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5559.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11633 = _11632;
                }
                _11665 = _11633;
            }
            else
            {
                float3 _11666;
                if (_5058 == 11u)
                {
                    uint _5572 = (rw_nfru_diagnostics.Load<uint>(_5534 * 4 + 0) >> 8u) & 15u;
                    uint _5575 = (rw_nfru_diagnostics.Load<uint>(_5534 * 4 + 0) >> 12u) & 15u;
                    float3 _11625;
                    if ((_5538 == 2u) || (_5538 == 3u))
                    {
                        _11625 = _3270[_5538];
                    }
                    else
                    {
                        bool _5587 = _5572 == 3u;
                        bool _5589 = _5575 == 3u;
                        float3 _11626;
                        if (_5587 && _5589)
                        {
                            _11626 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11627;
                            if (_5587)
                            {
                                _11627 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11628;
                                if (_5589)
                                {
                                    _11628 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11629;
                                    if ((_5572 == 4u) || (_5575 == 4u))
                                    {
                                        _11629 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11630;
                                        if ((_5572 == 1u) || (_5575 == 1u))
                                        {
                                            _11630 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11890 = (_5538 == 1u).xxx;
                                            _11630 = float3(_11890.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11890.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11890.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11629 = _11630;
                                    }
                                    _11628 = _11629;
                                }
                                _11627 = _11628;
                            }
                            _11626 = _11627;
                        }
                        _11625 = _11626;
                    }
                    _11666 = _11625;
                }
                else
                {
                    _11666 = _3270[min(_5538, 7u)];
                }
                _11665 = _11666;
            }
            _11634 = _11665;
        }
        else
        {
            _11634 = _11635;
        }
        float4 _11669;
        if ((_5058 >= 14u) && (_5058 <= 16u))
        {
            float2 _11667;
            if (_5058 == 14u)
            {
                uint _5645_dummy_parameter;
                uint _5651_dummy_parameter;
                _11667 = r_flow_tm1.Load(int3(clamp(int2(floor(_3943 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5645_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5651_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11668;
                if (_5058 == 16u)
                {
                    uint _9425 = r_warped_flow_qdata_tm1.Load(int3(_3959, 0)).x & 2147483647u;
                    uint _9457 = uint(max((int((_9425 >> 16u) & 15u) - 6), 0));
                    _11668 = ((float2(float((1 - (2 * int((_9425 >> 15u) & 1u))) * int(((_9425 >> uint(7)) & 127u) << _9457)), float((1 - (2 * int((_9425 >> 14u) & 1u))) * int((_9425 & 127u) << _9457))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11668 = _5841 * float2(cbFI_DisplaySize);
                }
                _11667 = _11668;
            }
            uint2 _5684 = uint2(clamp(round(_11667 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5686 = _5684.x;
            uint _5693 = _5684.y;
            _11669 = float4(float(_5686 & 255u), float((_5686 >> 8u) | ((_5693 & 15u) << 4u)), float(_5693 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11670;
            if (_5058 == 17u)
            {
                _11670 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3959, 0)).x != 0u), _4302, 0.0f, 1.0f);
            }
            else
            {
                _11670 = float4(_11634, 1.0f);
            }
            _11669 = _11670;
        }
        rw_output[_3557] = _11669.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5737 = ((uint(_3557.y) * uint(cbFI_DisplaySize.x)) + uint(_3557.x)) * 6u;
            uint _9503 = spvPackHalf2x16(clamp(_6545.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5737 * 4 + 0, (((_9503 & 32767u) >> 4u) | ((((_9503 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6545.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9538 = spvPackHalf2x16(clamp(_6553.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5737 + 1u) * 4 + 0, (((_9538 & 32767u) >> 4u) | ((((_9538 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6553.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9573 = spvPackHalf2x16(clamp(_6561.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5737 + 2u) * 4 + 0, (((_9573 & 32767u) >> 4u) | ((((_9573 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6561.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9608 = spvPackHalf2x16(clamp(_6569.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5737 + 3u) * 4 + 0, (((_9608 & 32767u) >> 4u) | ((((_9608 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6569.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9635 = r_current_interpolation_source.Load(int3(_3557, 0));
            uint _9649 = spvPackHalf2x16(clamp(_9635.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5737 + 4u) * 4 + 0, (((_9649 & 32767u) >> 4u) | ((((_9649 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9635.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11703;
            if (_11545 || (_5058 != 0u))
            {
                _11703 = 4294967295u;
            }
            else
            {
                uint _9684 = spvPackHalf2x16(clamp(_11669.xy, 0.0f.xx, 65000.0f.xx));
                _11703 = (((_9684 & 32767u) >> 4u) | ((((_9684 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11669.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5737 + 5u) * 4 + 0, _11703);
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
