static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3322[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3626 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3626.x >= cbFI_DisplaySize.x, _3626.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3626] = float4(r_present_backbuffer.Load(int3(_3626, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3626] = float4(r_current_interpolation_source.Load(int3(_3626, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4026 = (float2(_3626) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4037 = int2(floor(_4026 * float2(cbFI_MvDepthLaneSize)));
        int2 _4042 = int2(floor(_4026 * float2(cbFI_FlowLaneSize)));
        float4 _5974 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4026 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5980 = r_warped_filled_flow_tm1.Load(int3(_4042, 0)).xy;
        float2 _5986 = r_warped_filled_motion_tp1.Load(int3(_4037, 0)).xy;
        bool _6008 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10068;
        if (_6008)
        {
            float _6021 = ((2.0f * _4026.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10068 = float2(atan(_6021) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4026.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6021 * _6021))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10068 = _4026;
        }
        bool _4063 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10089;
        bool _10110;
        int2 _10121;
        float3 _11480;
        if (_4063)
        {
            float _10070;
            float _10072;
            _10072 = 2.0f;
            _10070 = -1.0f;
            uint _3690[9];
            float _11912;
            float _11915;
            for (int _10069 = 0; _10069 < 9; _10072 = _11915, _10070 = _11912, _10069++)
            {
                _3690[_10069] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4037 + int2((_10069 % 3) - 1, (_10069 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3690[_10069] != 0u)
                {
                    float _11907;
                    if (_3690[_10069] == 0u)
                    {
                        _11907 = -1.0f;
                    }
                    else
                    {
                        _11907 = float((_3690[_10069] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11915 = min(_10072, _11907);
                    _11912 = max(_10070, _11907);
                }
                else
                {
                    _11915 = _10072;
                    _11912 = _10070;
                }
            }
            float _4109 = float(_10070 >= 0.0f);
            float3 _9865 = 0.0f.xxx;
            _9865.y = _4109;
            float2 _10090;
            bool _10111;
            int2 _10122;
            float3 _11481;
            if ((_10070 - _10072) > 0.0199999995529651641845703125f)
            {
                float _10078;
                int2 _10079;
                float2 _10080;
                int2 _10082;
                float2 _10088;
                _10088 = _5986;
                _10082 = _4037;
                _10080 = _5986;
                _10079 = _4037;
                _10078 = -1.0f;
                float _11920;
                int2 _11924;
                float2 _11935;
                int2 _11946;
                float2 _11979;
                float _12026;
                int _10077 = 0;
                float _11888 = 1000000000.0f;
                for (; _10077 < 9; _11888 = _12026, _10088 = _11979, _10082 = _11946, _10080 = _11935, _10079 = _11924, _10078 = _11920, _10077++)
                {
                    if (_3690[_10077] == 0u)
                    {
                        _12026 = _11888;
                        _11979 = _10088;
                        _11946 = _10082;
                        _11935 = _10080;
                        _11924 = _10079;
                        _11920 = _10078;
                        continue;
                    }
                    int2 _4144 = clamp(_4037 + int2((_10077 % 3) - 1, (_10077 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6096 = _3690[_10077] & 2147483647u;
                    uint _6128 = uint(max((int((_6096 >> 16u) & 15u) - 6), 0));
                    float2 _4150 = (float2(float((1 - (2 * int((_6096 >> 15u) & 1u))) * int(((_6096 >> uint(7)) & 127u) << _6128)), float((1 - (2 * int((_6096 >> 14u) & 1u))) * int((_6096 & 127u) << _6128))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11874;
                    if (_3690[_10077] == 0u)
                    {
                        _11874 = -1.0f;
                    }
                    else
                    {
                        _11874 = float((_3690[_10077] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4155 = _11874 - 0.100000001490116119384765625f;
                    float2 _11875;
                    if (_6008)
                    {
                        float2 _6205 = clamp((((_10068 + (_4150 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6208 = tan(_6205.x);
                        _11875 = (float2(_6208 / cbFI_DeviceToViewDepth.z, (tan(_6205.y) * sqrt(1.0f + (_6208 * _6208))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11875 = _10068 + (_4150 * cbFI_Timestep);
                    }
                    float _4162 = cbFI_Timestep - 1.0f;
                    float2 _11876;
                    if (_6008)
                    {
                        float2 _6276 = clamp((((_10068 + (_4150 * _4162)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6279 = tan(_6276.x);
                        _11876 = (float2(_6279 / cbFI_DeviceToViewDepth.z, (tan(_6276.y) * sqrt(1.0f + (_6279 * _6279))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11876 = _10068 + (_4150 * _4162);
                    }
                    bool _6312 = all(bool2(_11875.x > 0.0f.xx.x, _11875.y > 0.0f.xx.y));
                    bool _6318;
                    if (_6312)
                    {
                        _6318 = all(bool2(_11875.x < 1.0f.xx.x, _11875.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6318 = _6312;
                    }
                    float _11879;
                    if (_6318)
                    {
                        uint _6325_dummy_parameter;
                        _11879 = max((_4155 - (log((r_depth_tm1.Load(int3(int2(floor(_11875 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6325_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11879 = 0.0f;
                    }
                    bool _6355 = all(bool2(_11876.x > 0.0f.xx.x, _11876.y > 0.0f.xx.y));
                    bool _6361;
                    if (_6355)
                    {
                        _6361 = all(bool2(_11876.x < 1.0f.xx.x, _11876.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6361 = _6355;
                    }
                    float _11880;
                    if (_6361)
                    {
                        uint _6368_dummy_parameter;
                        _11880 = _11879 + max((_4155 - (log((r_depth_tp1.Load(int3(int2(floor(_11876 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6368_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11880 = _11879;
                    }
                    float _11921;
                    int2 _11925;
                    float2 _11936;
                    int2 _11947;
                    float2 _11980;
                    float _12027;
                    if (_11880 == 0.0f)
                    {
                        bool _4197 = _4155 > _10078;
                        bool2 _12035 = _4197.xx;
                        _12027 = _11888;
                        _11980 = float2(_12035.x ? _4150.x : _10088.x, _12035.y ? _4150.y : _10088.y);
                        _11947 = int2(_12035.x ? _4144.x : _10082.x, _12035.y ? _4144.y : _10082.y);
                        _11936 = _10080;
                        _11925 = _10079;
                        _11921 = _4197 ? _4155 : _10078;
                    }
                    else
                    {
                        bool _4206 = _11880 < _11888;
                        bool2 _12031 = _4206.xx;
                        _12027 = _4206 ? _11880 : _11888;
                        _11980 = _10088;
                        _11947 = _10082;
                        _11936 = float2(_12031.x ? _4150.x : _10080.x, _12031.y ? _4150.y : _10080.y);
                        _11925 = int2(_12031.x ? _4144.x : _10079.x, _12031.y ? _4144.y : _10079.y);
                        _11921 = _10078;
                    }
                    _12026 = _12027;
                    _11979 = _11980;
                    _11946 = _11947;
                    _11935 = _11936;
                    _11924 = _11925;
                    _11920 = _11921;
                }
                bool _4218 = _10078 < 0.0f;
                bool2 _12041 = _4218.xx;
                int2 _12044 = int2(_12041.x ? _10079.x : _10082.x, _12041.y ? _10079.y : _10082.y);
                _11481 = float3(1.0f, _4109, float(any(bool2(_12044.x != _4037.x, _12044.y != _4037.y))));
                _10122 = _12044;
                _10111 = _4218 ? false : true;
                _10090 = float2(_12041.x ? _10080.x : _10088.x, _12041.y ? _10080.y : _10088.y);
            }
            else
            {
                _11481 = _9865;
                _10122 = _4037;
                _10111 = false;
                _10090 = _5986;
            }
            _11480 = _11481;
            _10121 = _10122;
            _10110 = _10111;
            _10089 = _10090;
        }
        else
        {
            _11480 = 0.0f.xxx;
            _10121 = _4037;
            _10110 = false;
            _10089 = _5986;
        }
        float2 _10091;
        if (_6008)
        {
            float2 _6433 = clamp((((_10068 + (_10089 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6436 = tan(_6433.x);
            _10091 = (float2(_6436 / cbFI_DeviceToViewDepth.z, (tan(_6433.y) * sqrt(1.0f + (_6436 * _6436))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10091 = _10068 + (_10089 * cbFI_Timestep);
        }
        float _4241 = cbFI_Timestep - 1.0f;
        float2 _10093;
        if (_6008)
        {
            float2 _6504 = clamp((((_10068 + (_10089 * _4241)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6507 = tan(_6504.x);
            _10093 = (float2(_6507 / cbFI_DeviceToViewDepth.z, (tan(_6504.y) * sqrt(1.0f + (_6507 * _6507))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10093 = _10068 + (_10089 * _4241);
        }
        float _4246 = -cbFI_Timestep;
        float2 _10094;
        if (_6008)
        {
            float2 _6575 = clamp((((_10068 + (_5980 * _4246)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6578 = tan(_6575.x);
            _10094 = (float2(_6578 / cbFI_DeviceToViewDepth.z, (tan(_6575.y) * sqrt(1.0f + (_6578 * _6578))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10094 = _10068 + (_5980 * _4246);
        }
        float _4251 = 1.0f - cbFI_Timestep;
        float2 _10095;
        if (_6008)
        {
            float2 _6646 = clamp((((_10068 + (_5980 * _4251)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6649 = tan(_6646.x);
            _10095 = (float2(_6649 / cbFI_DeviceToViewDepth.z, (tan(_6646.y) * sqrt(1.0f + (_6649 * _6649))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10095 = _10068 + (_5980 * _4251);
        }
        float4 _6684 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10091, 0.0f);
        float3 _6685 = _6684.xyz;
        float4 _6692 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10093, 0.0f);
        float3 _6693 = _6692.xyz;
        float4 _6700 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10094, 0.0f);
        float3 _6701 = _6700.xyz;
        float4 _6708 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10095, 0.0f);
        float3 _6709 = _6708.xyz;
        float4 _6723 = exp(_5974 - max(max(max(_5974.x, _5974.y), _5974.z), _5974.w).xxxx);
        float4 _6730 = _6723 / (dot(_6723, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4270 = _4063 && (!_10110);
        bool _4279;
        if (_4270)
        {
            _4279 = (_6730.z + _6730.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4279 = _4270;
        }
        bool _4290;
        if (_4279)
        {
            _4290 = length((_10094 - _10091) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4290 = _4279;
        }
        bool _10134;
        if (_4290)
        {
            uint4 _6749 = r_warped_motion_qdata_tp1.Load(int3(_10121, 0));
            uint _6750 = _6749.x;
            bool _10137;
            if (_6750 != 0u)
            {
                float _10123;
                if (_6750 == 0u)
                {
                    _10123 = -1.0f;
                }
                else
                {
                    _10123 = float((_6750 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4300 = _10123 - 0.12000000476837158203125f;
                bool _6769 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
                bool _6775;
                if (_6769)
                {
                    _6775 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
                }
                else
                {
                    _6775 = _6769;
                }
                bool _4310;
                if (_6775)
                {
                    uint _6782_dummy_parameter;
                    _4310 = (log((r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6782_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4300;
                }
                else
                {
                    _4310 = _6775;
                }
                bool _4324;
                if (!_4310)
                {
                    bool _6812 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
                    bool _6818;
                    if (_6812)
                    {
                        _6818 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6818 = _6812;
                    }
                    bool _4322;
                    if (_6818)
                    {
                        uint _6825_dummy_parameter;
                        _4322 = (log((r_depth_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6825_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4300;
                    }
                    else
                    {
                        _4322 = _6818;
                    }
                    _4324 = _4322;
                }
                else
                {
                    _4324 = _4310;
                }
                _10137 = _4324;
            }
            else
            {
                _10137 = false;
            }
            _10134 = _10137;
        }
        else
        {
            _10134 = false;
        }
        bool _4329 = _10110 || _10134;
        bool _4334;
        if (_4329)
        {
            bool _6855 = all(bool2(_10091.x > 0.0f.xx.x, _10091.y > 0.0f.xx.y));
            bool _6861;
            if (_6855)
            {
                _6861 = all(bool2(_10091.x < 1.0f.xx.x, _10091.y < 1.0f.xx.y));
            }
            else
            {
                _6861 = _6855;
            }
            _4334 = _6861;
        }
        else
        {
            _4334 = _4329;
        }
        bool _4339;
        if (_4334)
        {
            bool _6866 = all(bool2(_10093.x > 0.0f.xx.x, _10093.y > 0.0f.xx.y));
            bool _6872;
            if (_6866)
            {
                _6872 = all(bool2(_10093.x < 1.0f.xx.x, _10093.y < 1.0f.xx.y));
            }
            else
            {
                _6872 = _6866;
            }
            _4339 = _6872;
        }
        else
        {
            _4339 = _4334;
        }
        float4 _10231;
        if (_4339)
        {
            float _4342 = _6730.x;
            float _4344 = _6730.y;
            float _4345 = _4342 + _4344;
            float _4350 = _6730.z + _6730.w;
            float _10152;
            if (_4345 > 0.001000000047497451305389404296875f)
            {
                _10152 = _4342 / _4345;
            }
            else
            {
                _10152 = _4251;
            }
            _10231 = float4(_4342 + (_4350 * _10152), _4344 + (_4350 * (1.0f - _10152)), 0.0f, 0.0f);
        }
        else
        {
            _10231 = _6730;
        }
        bool _6900 = (cbFI_pad0 & 1024u) != 0u;
        bool _6876 = !_6900;
        bool _6877 = !_6876;
        bool _6894;
        if (_6877)
        {
            _6894 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10121.y * cbFI_MvDepthLaneSize.x) + _10121.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6894 = _6876;
        }
        bool _6926;
        if (_6877)
        {
            _6926 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4042.y * cbFI_FlowLaneSize.x) + _4042.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6926 = _6876;
        }
        float _4385 = float(_6926);
        bool _10244;
        float4 _10275;
        float3 _11294;
        if (_6900)
        {
            bool _4395;
            if (_6894)
            {
                _4395 = all(bool2(_10091.x > 0.0f.xx.x, _10091.y > 0.0f.xx.y));
            }
            else
            {
                _4395 = _6894;
            }
            bool _4401;
            if (_4395)
            {
                _4401 = all(bool2(_10091.x < 1.0f.xx.x, _10091.y < 1.0f.xx.y));
            }
            else
            {
                _4401 = _4395;
            }
            bool _4408;
            if (_6894)
            {
                _4408 = all(bool2(_10093.x > 0.0f.xx.x, _10093.y > 0.0f.xx.y));
            }
            else
            {
                _4408 = _6894;
            }
            bool _4414;
            if (_4408)
            {
                _4414 = all(bool2(_10093.x < 1.0f.xx.x, _10093.y < 1.0f.xx.y));
            }
            else
            {
                _4414 = _4408;
            }
            bool _4421;
            if (_6926)
            {
                _4421 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
            }
            else
            {
                _4421 = _6926;
            }
            bool _4427;
            if (_4421)
            {
                _4427 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
            }
            else
            {
                _4427 = _4421;
            }
            bool _4434;
            if (_6926)
            {
                _4434 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
            }
            else
            {
                _4434 = _6926;
            }
            bool _4440;
            if (_4434)
            {
                _4440 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
            }
            else
            {
                _4440 = _4434;
            }
            bool _4442 = !_6894;
            if (_4442)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6968;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6968);
                }
            }
            bool _4447 = !_6926;
            if (_4447)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6978;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6978);
                }
            }
            if (_6894 && _4447)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6988;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6988);
                }
            }
            if (_4442 && _6926)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6998;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6998);
                }
            }
            float _4466 = float(_4401);
            float _4468 = float(_4414);
            bool _4471 = _4427 && _4440;
            float _10186;
            if (_4471)
            {
                _10186 = 1.0f;
            }
            else
            {
                _10186 = (_4427 || _4440) ? 0.5f : 0.0f;
            }
            bool _10191;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4401)) && (!_4414))
            {
                bool _4501;
                if (_4471)
                {
                    float _10189;
                    do
                    {
                        bool _7082 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
                        bool _7088;
                        if (_7082)
                        {
                            _7088 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7088 = _7082;
                        }
                        bool _7019 = !_7088;
                        bool _7026;
                        if (!_7019)
                        {
                            bool _7093 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
                            bool _7099;
                            if (_7093)
                            {
                                _7099 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7099 = _7093;
                            }
                            _7026 = !_7099;
                        }
                        else
                        {
                            _7026 = _7019;
                        }
                        if (_7026)
                        {
                            _10189 = 0.0f;
                            break;
                        }
                        uint _7106_dummy_parameter;
                        uint _7122_dummy_parameter;
                        float4 _7047 = mul(float4((float2(_10094.x, 1.0f - _10094.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7106_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7049 = _7047.w;
                        if (abs(_7049) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10189 = 0.0f;
                            break;
                        }
                        float _7060 = abs(cbFI_DeviceToViewDepth.y / ((_7047.z / _7049) - cbFI_DeviceToViewDepth.x));
                        float _7063 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7122_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10189 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7060 - _7063) / max(max(_7060, _7063), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4501 = _10189 >= 0.5f;
                }
                else
                {
                    _4501 = _4471;
                }
                bool _4509;
                if (_4501)
                {
                    _4509 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4509 = _4501;
                }
                bool _10192;
                if (_4509)
                {
                    uint _7172_dummy_parameter;
                    float2 _10190;
                    do
                    {
                        float _7198 = 1.0f - _10094.y;
                        float4 _7209 = mul(float4((float2(_10094.x, _7198) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7172_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7211 = _7209.w;
                        if (!(_7211 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10190 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7224 = ((_7209.xy / _7211.xx) + 1.0f.xx) * 0.5f;
                        _10190 = float2(_7224.x - _10094.x, _7198 - _7224.y);
                        break;
                    } while(false);
                    float2 _4522 = float2(cbFI_DisplaySize);
                    _10192 = length(((_10094 + _10190) - _10095) * _4522) <= ((0.100000001490116119384765625f * length(_10190 * _4522)) + 8.0f);
                }
                else
                {
                    _10192 = _4501;
                }
                _10191 = _10192;
            }
            else
            {
                _10191 = true;
            }
            bool _4536 = !_10191;
            bool _12045 = _4536 ? false : _4440;
            bool _12046 = _4536 ? false : _4427;
            bool _10245;
            float4 _10276;
            if (!(((_4401 && _4414) && _12046) && _12045))
            {
                float4 _4558 = _10231 * float4(_4466, _4468, float(_12046), float(_12045));
                float _4560 = dot(_4558, 1.0f.xxxx);
                bool _4563 = !(_4560 > 0.0f);
                float4 _10277;
                if (!_4563)
                {
                    _10277 = _4558 / _4560.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7246;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7246);
                    }
                    _10277 = 0.0f.xxxx;
                }
                _10276 = _10277;
                _10245 = _4563;
            }
            else
            {
                _10276 = _10231;
                _10245 = false;
            }
            _11294 = float3(_4466, _4468, _10186);
            _10275 = _10276;
            _10244 = _10245;
        }
        else
        {
            _11294 = float3(float(_6894), _4385, 0.0f);
            _10275 = _10231;
            _10244 = false;
        }
        bool _4581 = !_10244;
        float4 _10337;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4581)
        {
            float _4588 = _10275.x + _10275.y;
            float4 _10338;
            if (_4588 > 0.001000000047497451305389404296875f)
            {
                _10338 = float4(_10275.x / _4588, _10275.y / _4588, 0.0f, 0.0f);
            }
            else
            {
                _10338 = float4(_4251, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10337 = _10338;
        }
        else
        {
            _10337 = _10275;
        }
        float4 _10433;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4581) && _6894)
        {
            float _10334;
            do
            {
                uint4 _7386 = r_warped_motion_qdata_tp1.Load(int3(_10121, 0));
                uint _7387 = _7386.x;
                if (_7387 != 0u)
                {
                    float _10333;
                    if (_7387 == 0u)
                    {
                        _10333 = -1.0f;
                    }
                    else
                    {
                        _10333 = float((_7387 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10334 = _10333;
                    break;
                }
                int _10316;
                uint _10317;
                _10317 = _7387;
                _10316 = -1;
                uint _10332;
                for (; _10316 <= 1; _10317 = _10332, _10316++)
                {
                    _10332 = _10317;
                    for (int _10330 = -1; _10330 <= 1; )
                    {
                        _10332 = max(_10332, r_warped_motion_qdata_tp1.Load(int3(clamp(_10121 + int2(_10330, _10316), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10330++;
                        continue;
                    }
                }
                if (_10317 != 0u)
                {
                    float _10329;
                    if (_10317 == 0u)
                    {
                        _10329 = -1.0f;
                    }
                    else
                    {
                        _10329 = float((_10317 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10334 = _10329;
                    break;
                }
                uint _10319;
                _10319 = 4294967295u;
                uint _12016;
                for (int _10318 = 0; _10318 < 8; _10319 = _12016, _10318++)
                {
                    int _10322 = 0;
                    for (;;)
                    {
                        if (_10322 < 5)
                        {
                            int2 _7337 = _10121 + (_1093[_10318] * _1102[_10322].xx);
                            bool _7340 = any(bool2(_7337.x < int2(0, 0).x, _7337.y < int2(0, 0).y));
                            bool _7348;
                            if (!_7340)
                            {
                                _7348 = any(bool2(_7337.x >= cbFI_MvDepthLaneSize.x, _7337.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7348 = _7340;
                            }
                            if (_7348)
                            {
                                _12016 = _10319;
                                break;
                            }
                            uint4 _7426 = r_warped_motion_qdata_tp1.Load(int3(_7337, 0));
                            uint _7427 = _7426.x;
                            if (_7427 != 0u)
                            {
                                _12016 = min(_10319, _7427);
                                break;
                            }
                            _10322++;
                            continue;
                        }
                        else
                        {
                            _12016 = _10319;
                            break;
                        }
                    }
                }
                float _10321;
                if (_10319 == 4294967295u)
                {
                    _10321 = -1.0f;
                }
                else
                {
                    float _10320;
                    if (_10319 == 0u)
                    {
                        _10320 = -1.0f;
                    }
                    else
                    {
                        _10320 = float((_10319 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10321 = _10320;
                }
                _10334 = _10321;
                break;
            } while(false);
            float _4624 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4628 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4634;
            if (_4628)
            {
                _4634 = _10337.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4634 = _4628;
            }
            bool _4639;
            if (_4634)
            {
                bool _7446 = all(bool2(_10093.x > 0.0f.xx.x, _10093.y > 0.0f.xx.y));
                bool _7452;
                if (_7446)
                {
                    _7452 = all(bool2(_10093.x < 1.0f.xx.x, _10093.y < 1.0f.xx.y));
                }
                else
                {
                    _7452 = _7446;
                }
                _4639 = _7452;
            }
            else
            {
                _4639 = _4634;
            }
            float4 _10378;
            if (_4639)
            {
                float _10353;
                if (_10334 >= 0.0f)
                {
                    _10353 = _10334 - _4624;
                }
                else
                {
                    float _10349;
                    _10349 = 2.0f;
                    float _7509;
                    for (int _10348 = 0; _10348 < 24; _10349 = _7509, _10348++)
                    {
                        float _7473 = float(_10348 & 7) * 0.785398185253143310546875f;
                        int _7475 = _10348 >> 3;
                        int _10350;
                        if (_7475 == 0)
                        {
                            _10350 = 16;
                        }
                        else
                        {
                            _10350 = (_7475 == 1) ? 48 : 96;
                        }
                        uint _7541_dummy_parameter;
                        _7509 = min(_10349, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10093 + ((cbFI_MvDepthLaneSizeRcp * float(_10350)) * float2(cos(_7473), sin(_7473))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7541_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10353 = _10349;
                }
                uint _7573_dummy_parameter;
                float4 _10379;
                if (r_depth_tp1.Load(int3(int2(floor(_10093 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7573_dummy_parameter))))), 0)).x > ((exp((_10353 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10379 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10379 = 1.0f.xxxx;
                }
                _10378 = _10379;
            }
            else
            {
                _10378 = 1.0f.xxxx;
            }
            bool _4666 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4672;
            if (_4666)
            {
                _4672 = _10337.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4672 = _4666;
            }
            bool _4677;
            if (_4672)
            {
                bool _7597 = all(bool2(_10091.x > 0.0f.xx.x, _10091.y > 0.0f.xx.y));
                bool _7603;
                if (_7597)
                {
                    _7603 = all(bool2(_10091.x < 1.0f.xx.x, _10091.y < 1.0f.xx.y));
                }
                else
                {
                    _7603 = _7597;
                }
                _4677 = _7603;
            }
            else
            {
                _4677 = _4672;
            }
            float4 _10382;
            if (_4677)
            {
                float _10373;
                if (_10334 >= 0.0f)
                {
                    _10373 = _10334 - _4624;
                }
                else
                {
                    float _10369;
                    _10369 = 2.0f;
                    float _7660;
                    for (int _10368 = 0; _10368 < 24; _10369 = _7660, _10368++)
                    {
                        float _7624 = float(_10368 & 7) * 0.785398185253143310546875f;
                        int _7626 = _10368 >> 3;
                        int _10370;
                        if (_7626 == 0)
                        {
                            _10370 = 16;
                        }
                        else
                        {
                            _10370 = (_7626 == 1) ? 48 : 96;
                        }
                        uint _7676_dummy_parameter;
                        _7660 = min(_10369, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10091 + ((cbFI_MvDepthLaneSizeRcp * float(_10370)) * float2(cos(_7624), sin(_7624))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7676_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10373 = _10369;
                }
                uint _7724_dummy_parameter;
                float4 _10383;
                if (r_depth_tm1.Load(int3(int2(floor(_10091 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7724_dummy_parameter))))), 0)).x > ((exp((_10373 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9937 = _10378;
                    _9937.x = 0.0f;
                    _10383 = _9937;
                }
                else
                {
                    _10383 = _10378;
                }
                _10382 = _10383;
            }
            else
            {
                _10382 = _10378;
            }
            float4 _10434;
            if (any(bool4(_10382.x < 1.0f.xxxx.x, _10382.y < 1.0f.xxxx.y, _10382.z < 1.0f.xxxx.z, _10382.w < 1.0f.xxxx.w)))
            {
                float4 _4707 = _10337 * _10382;
                float _4709 = dot(_4707, 1.0f.xxxx);
                float4 _10435;
                if (_4709 > 0.0f)
                {
                    _10435 = _4707 / _4709.xxxx;
                }
                else
                {
                    bool _4720 = _10382.y == 0.0f;
                    bool _4726;
                    if (_4720)
                    {
                        _4726 = _10382.x > 0.0f;
                    }
                    else
                    {
                        _4726 = _4720;
                    }
                    bool _4731;
                    if (_4726)
                    {
                        bool _7748 = all(bool2(_10091.x > 0.0f.xx.x, _10091.y > 0.0f.xx.y));
                        bool _7754;
                        if (_7748)
                        {
                            _7754 = all(bool2(_10091.x < 1.0f.xx.x, _10091.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7754 = _7748;
                        }
                        _4731 = _7754;
                    }
                    else
                    {
                        _4731 = _4726;
                    }
                    float4 _10436;
                    if (_4731)
                    {
                        _10436 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4736 = _10382.x == 0.0f;
                        bool _4742;
                        if (_4736)
                        {
                            _4742 = _10382.y > 0.0f;
                        }
                        else
                        {
                            _4742 = _4736;
                        }
                        bool _4747;
                        if (_4742)
                        {
                            bool _7759 = all(bool2(_10093.x > 0.0f.xx.x, _10093.y > 0.0f.xx.y));
                            bool _7765;
                            if (_7759)
                            {
                                _7765 = all(bool2(_10093.x < 1.0f.xx.x, _10093.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7765 = _7759;
                            }
                            _4747 = _7765;
                        }
                        else
                        {
                            _4747 = _4742;
                        }
                        bool4 _12047 = _4747.xxxx;
                        _10436 = float4(_12047.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10337.x, _12047.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10337.y, _12047.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10337.z, _12047.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10337.w);
                    }
                    _10435 = _10436;
                }
                _10434 = _10435;
            }
            else
            {
                _10434 = _10337;
            }
            _10433 = _10434;
        }
        else
        {
            _10433 = _10337;
        }
        float4 _10979;
        bool _10999;
        float3 _11113;
        if (((cbFI_pad0 & 32768u) != 0u) && _4581)
        {
            bool _4764 = _10433.x > 0.00999999977648258209228515625f;
            bool _4767 = _10433.y > 0.00999999977648258209228515625f;
            bool _4776 = (_10433.z + _10433.w) > 0.0199999995529651641845703125f;
            bool _4782;
            if (_4776)
            {
                bool _7770 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
                bool _7776;
                if (_7770)
                {
                    _7776 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
                }
                else
                {
                    _7776 = _7770;
                }
                _4782 = _7776;
            }
            else
            {
                _4782 = _4776;
            }
            bool _4787;
            if (_4782)
            {
                bool _7781 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
                bool _7787;
                if (_7781)
                {
                    _7787 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
                }
                else
                {
                    _7787 = _7781;
                }
                _4787 = _7787;
            }
            else
            {
                _4787 = _4782;
            }
            bool _4794;
            if (_4787)
            {
                float _10444;
                do
                {
                    bool _7870 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
                    bool _7876;
                    if (_7870)
                    {
                        _7876 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7876 = _7870;
                    }
                    bool _7807 = !_7876;
                    bool _7814;
                    if (!_7807)
                    {
                        bool _7881 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
                        bool _7887;
                        if (_7881)
                        {
                            _7887 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7887 = _7881;
                        }
                        _7814 = !_7887;
                    }
                    else
                    {
                        _7814 = _7807;
                    }
                    if (_7814)
                    {
                        _10444 = 0.0f;
                        break;
                    }
                    uint _7894_dummy_parameter;
                    uint _7910_dummy_parameter;
                    float4 _7835 = mul(float4((float2(_10094.x, 1.0f - _10094.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7894_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7837 = _7835.w;
                    if (abs(_7837) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10444 = 0.0f;
                        break;
                    }
                    float _7848 = abs(cbFI_DeviceToViewDepth.y / ((_7835.z / _7837) - cbFI_DeviceToViewDepth.x));
                    float _7851 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7910_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10444 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7848 - _7851) / max(max(_7848, _7851), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4794 = _10444 < 0.5f;
            }
            else
            {
                _4794 = _4787;
            }
            float4 _10459;
            if (_4794)
            {
                uint _7960_dummy_parameter;
                uint _7991_dummy_parameter;
                float4 _10460;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7960_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7991_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10460 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10460 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10459 = _10460;
            }
            else
            {
                _10459 = 1.0f.xxxx;
            }
            bool _4818;
            if (_6894)
            {
                bool _8020 = all(bool2(_10091.x > 0.0f.xx.x, _10091.y > 0.0f.xx.y));
                bool _8026;
                if (_8020)
                {
                    _8026 = all(bool2(_10091.x < 1.0f.xx.x, _10091.y < 1.0f.xx.y));
                }
                else
                {
                    _8026 = _8020;
                }
                _4818 = _8026;
            }
            else
            {
                _4818 = _6894;
            }
            bool _4824;
            if (_6894)
            {
                bool _8031 = all(bool2(_10093.x > 0.0f.xx.x, _10093.y > 0.0f.xx.y));
                bool _8037;
                if (_8031)
                {
                    _8037 = all(bool2(_10093.x < 1.0f.xx.x, _10093.y < 1.0f.xx.y));
                }
                else
                {
                    _8037 = _8031;
                }
                _4824 = _8037;
            }
            else
            {
                _4824 = _6894;
            }
            bool _4830;
            if (_6926)
            {
                bool _8042 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
                bool _8048;
                if (_8042)
                {
                    _8048 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
                }
                else
                {
                    _8048 = _8042;
                }
                _4830 = _8048;
            }
            else
            {
                _4830 = _6926;
            }
            bool _4836;
            if (_6926)
            {
                bool _8053 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
                bool _8059;
                if (_8053)
                {
                    _8059 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
                }
                else
                {
                    _8059 = _8053;
                }
                _4836 = _8059;
            }
            else
            {
                _4836 = _6926;
            }
            bool _4839 = _4830 != _4836;
            bool _4845;
            if (_4839)
            {
                _4845 = _4818 || _4824;
            }
            else
            {
                _4845 = _4839;
            }
            float4 _10547;
            if (_4845)
            {
                float4 _9964 = _10459;
                _9964.z = 0.0f;
                _9964.w = 0.0f;
                _10547 = _9964;
            }
            else
            {
                _10547 = _10459;
            }
            bool _4852 = _4818 && _4764;
            bool _4855 = _4824 && _4767;
            float4 _10652;
            float3 _11192;
            if (_4852 || _4855)
            {
                float _10542;
                do
                {
                    uint4 _8198 = r_warped_motion_qdata_tp1.Load(int3(_10121, 0));
                    uint _8199 = _8198.x;
                    if (_8199 != 0u)
                    {
                        float _10541;
                        if (_8199 == 0u)
                        {
                            _10541 = -1.0f;
                        }
                        else
                        {
                            _10541 = float((_8199 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10542 = _10541;
                        break;
                    }
                    int _10524;
                    uint _10525;
                    _10525 = _8199;
                    _10524 = -1;
                    uint _10540;
                    for (; _10524 <= 1; _10525 = _10540, _10524++)
                    {
                        _10540 = _10525;
                        for (int _10538 = -1; _10538 <= 1; )
                        {
                            _10540 = max(_10540, r_warped_motion_qdata_tp1.Load(int3(clamp(_10121 + int2(_10538, _10524), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10538++;
                            continue;
                        }
                    }
                    if (_10525 != 0u)
                    {
                        float _10537;
                        if (_10525 == 0u)
                        {
                            _10537 = -1.0f;
                        }
                        else
                        {
                            _10537 = float((_10525 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10542 = _10537;
                        break;
                    }
                    uint _10527;
                    _10527 = 4294967295u;
                    uint _12017;
                    for (int _10526 = 0; _10526 < 8; _10527 = _12017, _10526++)
                    {
                        int _10530 = 0;
                        for (;;)
                        {
                            if (_10530 < 5)
                            {
                                int2 _8149 = _10121 + (_1093[_10526] * _1102[_10530].xx);
                                bool _8152 = any(bool2(_8149.x < int2(0, 0).x, _8149.y < int2(0, 0).y));
                                bool _8160;
                                if (!_8152)
                                {
                                    _8160 = any(bool2(_8149.x >= cbFI_MvDepthLaneSize.x, _8149.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8160 = _8152;
                                }
                                if (_8160)
                                {
                                    _12017 = _10527;
                                    break;
                                }
                                uint4 _8238 = r_warped_motion_qdata_tp1.Load(int3(_8149, 0));
                                uint _8239 = _8238.x;
                                if (_8239 != 0u)
                                {
                                    _12017 = min(_10527, _8239);
                                    break;
                                }
                                _10530++;
                                continue;
                            }
                            else
                            {
                                _12017 = _10527;
                                break;
                            }
                        }
                    }
                    float _10529;
                    if (_10527 == 4294967295u)
                    {
                        _10529 = -1.0f;
                    }
                    else
                    {
                        float _10528;
                        if (_10527 == 0u)
                        {
                            _10528 = -1.0f;
                        }
                        else
                        {
                            _10528 = float((_10527 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10529 = _10528;
                    }
                    _10542 = _10529;
                    break;
                } while(false);
                bool _4863 = _10542 < 0.0f;
                float _10543;
                if (_4863)
                {
                    _10543 = 0.0f;
                }
                else
                {
                    _10543 = _10542 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8260_dummy_parameter;
                uint _8292_dummy_parameter;
                float4 _10580;
                if ((_4863 && _4852) && _4855)
                {
                    uint _8324_dummy_parameter;
                    float _8348 = log((r_depth_tm1.Load(int3(int2(floor(_10091 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8324_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8356_dummy_parameter;
                    float _8380 = log((r_depth_tp1.Load(int3(int2(floor(_10093 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8356_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10581;
                    if (_8348 > (_8380 + 0.07999999821186065673828125f))
                    {
                        float4 _9968 = _10547;
                        _9968.x = 0.0f;
                        _10581 = _9968;
                    }
                    else
                    {
                        float4 _10582;
                        if (_8380 > (_8348 + 0.07999999821186065673828125f))
                        {
                            float4 _9970 = _10547;
                            _9970.y = 0.0f;
                            _10582 = _9970;
                        }
                        else
                        {
                            _10582 = _10547;
                        }
                        _10581 = _10582;
                    }
                    _10580 = _10581;
                }
                else
                {
                    _10580 = _10547;
                }
                float _4915 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4917 = _10542 >= 0.0f;
                float _10563;
                if (_4917)
                {
                    _10563 = _10542 - _4915;
                }
                else
                {
                    float _10559;
                    if (_4852)
                    {
                        float _10558;
                        _10558 = 2.0f;
                        float _8438;
                        for (int _10557 = 0; _10557 < 24; _10558 = _8438, _10557++)
                        {
                            float _8402 = float(_10557 & 7) * 0.785398185253143310546875f;
                            int _8404 = _10557 >> 3;
                            int _10560;
                            if (_8404 == 0)
                            {
                                _10560 = 16;
                            }
                            else
                            {
                                _10560 = (_8404 == 1) ? 48 : 96;
                            }
                            uint _8454_dummy_parameter;
                            _8438 = min(_10558, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10091 + ((cbFI_MvDepthLaneSizeRcp * float(_10560)) * float2(cos(_8402), sin(_8402))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8454_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10559 = _10558;
                    }
                    else
                    {
                        _10559 = 0.0f;
                    }
                    _10563 = _10559;
                }
                float _10570;
                if (_4917)
                {
                    _10570 = _10542 - _4915;
                }
                else
                {
                    float _10566;
                    if (_4855)
                    {
                        float _10565;
                        _10565 = 2.0f;
                        float _8552;
                        for (int _10564 = 0; _10564 < 24; _10565 = _8552, _10564++)
                        {
                            float _8516 = float(_10564 & 7) * 0.785398185253143310546875f;
                            int _8518 = _10564 >> 3;
                            int _10567;
                            if (_8518 == 0)
                            {
                                _10567 = 16;
                            }
                            else
                            {
                                _10567 = (_8518 == 1) ? 48 : 96;
                            }
                            uint _8584_dummy_parameter;
                            _8552 = min(_10565, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10093 + ((cbFI_MvDepthLaneSizeRcp * float(_10567)) * float2(cos(_8516), sin(_8516))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8584_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10566 = _10565;
                    }
                    else
                    {
                        _10566 = 0.0f;
                    }
                    _10570 = _10566;
                }
                float _10571;
                if (_4852)
                {
                    uint _8616_dummy_parameter;
                    _10571 = r_depth_tm1.Load(int3(int2(floor(_10091 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8616_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10571 = 0.0f;
                }
                float _10572;
                if (_4855)
                {
                    uint _8635_dummy_parameter;
                    _10572 = r_depth_tp1.Load(int3(int2(floor(_10093 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8635_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10572 = 0.0f;
                }
                bool _4972;
                if (_4852)
                {
                    _4972 = _10571 > ((exp((_10563 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4972 = _4852;
                }
                float4 _10588;
                if (_4972)
                {
                    float4 _9972 = _10580;
                    _9972.x = 0.0f;
                    _10588 = _9972;
                }
                else
                {
                    _10588 = _10580;
                }
                bool _4984;
                if (_4855)
                {
                    _4984 = _10572 > ((exp((_10570 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4984 = _4855;
                }
                float4 _10590;
                if (_4984)
                {
                    float4 _9974 = _10588;
                    _9974.y = 0.0f;
                    _10590 = _9974;
                }
                else
                {
                    _10590 = _10588;
                }
                float4 _10653;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4917)
                {
                    bool _5004;
                    if (_4852)
                    {
                        _5004 = _10571 < ((exp((_10563 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5004 = _4852;
                    }
                    float4 _10592;
                    if (_5004)
                    {
                        float4 _9976 = _10590;
                        _9976.x = 0.0f;
                        _10592 = _9976;
                    }
                    else
                    {
                        _10592 = _10590;
                    }
                    bool _5016;
                    if (_4855)
                    {
                        _5016 = _10572 < ((exp((_10570 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5016 = _4855;
                    }
                    float4 _10654;
                    if (_5016)
                    {
                        float4 _9978 = _10592;
                        _9978.y = 0.0f;
                        _10654 = _9978;
                    }
                    else
                    {
                        _10654 = _10592;
                    }
                    _10653 = _10654;
                }
                else
                {
                    _10653 = _10590;
                }
                _11192 = float3(_10543, log((r_depth_tm1.Load(int3(int2(floor(_10091 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8260_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10093 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8292_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10652 = _10653;
            }
            else
            {
                _11192 = float3(0.0f, 0.0f, 0.5f);
                _10652 = _10547;
            }
            bool _5027 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4776;
            bool _5033;
            if (_5027)
            {
                _5033 = _4830 || _4836;
            }
            else
            {
                _5033 = _5027;
            }
            float4 _10675;
            if (_5033)
            {
                float _10647;
                do
                {
                    uint4 _8814 = r_warped_motion_qdata_tp1.Load(int3(_10121, 0));
                    uint _8815 = _8814.x;
                    if (_8815 != 0u)
                    {
                        float _10646;
                        if (_8815 == 0u)
                        {
                            _10646 = -1.0f;
                        }
                        else
                        {
                            _10646 = float((_8815 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10647 = _10646;
                        break;
                    }
                    int _10629;
                    uint _10630;
                    _10630 = _8815;
                    _10629 = -1;
                    uint _10645;
                    for (; _10629 <= 1; _10630 = _10645, _10629++)
                    {
                        _10645 = _10630;
                        for (int _10643 = -1; _10643 <= 1; )
                        {
                            _10645 = max(_10645, r_warped_motion_qdata_tp1.Load(int3(clamp(_10121 + int2(_10643, _10629), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10643++;
                            continue;
                        }
                    }
                    if (_10630 != 0u)
                    {
                        float _10642;
                        if (_10630 == 0u)
                        {
                            _10642 = -1.0f;
                        }
                        else
                        {
                            _10642 = float((_10630 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10647 = _10642;
                        break;
                    }
                    uint _10632;
                    _10632 = 4294967295u;
                    uint _12018;
                    for (int _10631 = 0; _10631 < 8; _10632 = _12018, _10631++)
                    {
                        int _10635 = 0;
                        for (;;)
                        {
                            if (_10635 < 5)
                            {
                                int2 _8765 = _10121 + (_1093[_10631] * _1102[_10635].xx);
                                bool _8768 = any(bool2(_8765.x < int2(0, 0).x, _8765.y < int2(0, 0).y));
                                bool _8776;
                                if (!_8768)
                                {
                                    _8776 = any(bool2(_8765.x >= cbFI_MvDepthLaneSize.x, _8765.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8776 = _8768;
                                }
                                if (_8776)
                                {
                                    _12018 = _10632;
                                    break;
                                }
                                uint4 _8854 = r_warped_motion_qdata_tp1.Load(int3(_8765, 0));
                                uint _8855 = _8854.x;
                                if (_8855 != 0u)
                                {
                                    _12018 = min(_10632, _8855);
                                    break;
                                }
                                _10635++;
                                continue;
                            }
                            else
                            {
                                _12018 = _10632;
                                break;
                            }
                        }
                    }
                    float _10634;
                    if (_10632 == 4294967295u)
                    {
                        _10634 = -1.0f;
                    }
                    else
                    {
                        float _10633;
                        if (_10632 == 0u)
                        {
                            _10633 = -1.0f;
                        }
                        else
                        {
                            _10633 = float((_10632 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10634 = _10633;
                    }
                    _10647 = _10634;
                    break;
                } while(false);
                float4 _10676;
                if (_10647 >= 0.0f)
                {
                    float _8876 = (exp((_10647 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5052;
                    if (_4830)
                    {
                        uint _8883_dummy_parameter;
                        _5052 = r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8883_dummy_parameter))))), 0)).x > _8876;
                    }
                    else
                    {
                        _5052 = _4830;
                    }
                    float4 _10665;
                    if (_5052)
                    {
                        float4 _9980 = _10652;
                        _9980.z = 0.0f;
                        _10665 = _9980;
                    }
                    else
                    {
                        _10665 = _10652;
                    }
                    bool _5064;
                    if (_4836)
                    {
                        uint _8902_dummy_parameter;
                        _5064 = r_depth_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8902_dummy_parameter))))), 0)).x > _8876;
                    }
                    else
                    {
                        _5064 = _4836;
                    }
                    float4 _10677;
                    if (_5064)
                    {
                        float4 _9982 = _10665;
                        _9982.w = 0.0f;
                        _10677 = _9982;
                    }
                    else
                    {
                        _10677 = _10665;
                    }
                    _10676 = _10677;
                }
                else
                {
                    _10676 = _10652;
                }
                _10675 = _10676;
            }
            else
            {
                _10675 = _10652;
            }
            bool _5072 = _4818 != _4824;
            bool _5079;
            if (_5072)
            {
                _5079 = _4818 ? _4764 : _4767;
            }
            else
            {
                _5079 = _5072;
            }
            bool _5086;
            if (_5079)
            {
                _5086 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5086 = _5079;
            }
            float4 _10760;
            if (_5086)
            {
                bool2 _5091 = _4818.xx;
                float2 _5092 = float2(_5091.x ? _10091.x : _10093.x, _5091.y ? _10091.y : _10093.y);
                float _10667;
                if (_4818)
                {
                    uint _8921_dummy_parameter;
                    _10667 = r_depth_tm1.Load(int3(int2(floor(_5092 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8921_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8937_dummy_parameter;
                    _10667 = r_depth_tp1.Load(int3(int2(floor(_5092 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8937_dummy_parameter))))), 0)).x;
                }
                float4x4 _10668;
                if (_4818)
                {
                    _10668 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10668 = cbFI_MotionTP1ToTM1;
                }
                float2 _10669;
                do
                {
                    float _8964 = _5092.x;
                    float _8967 = 1.0f - _5092.y;
                    float4 _8978 = mul(float4((float2(_8964, _8967) * 2.0f) - 1.0f.xx, _10667, 1.0f), _10668);
                    float _8980 = _8978.w;
                    if (!(_8980 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10669 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8993 = ((_8978.xy / _8980.xx) + 1.0f.xx) * 0.5f;
                    _10669 = float2(_8993.x - _8964, _8967 - _8993.y);
                    break;
                } while(false);
                float2 _5122 = float2(cbFI_DisplaySize);
                float4 _10761;
                if (!(length(((_5092 + _10669) - float2(_5091.x ? _10093.x : _10091.x, _5091.y ? _10093.y : _10091.y)) * _5122) <= ((0.100000001490116119384765625f * length(_10669 * _5122)) + 8.0f)))
                {
                    float4 _10762;
                    if (_4818)
                    {
                        float4 _9992 = _10675;
                        _9992.x = 0.0f;
                        _10762 = _9992;
                    }
                    else
                    {
                        float4 _9994 = _10675;
                        _9994.y = 0.0f;
                        _10762 = _9994;
                    }
                    _10761 = _10762;
                }
                else
                {
                    _10761 = _10675;
                }
                _10760 = _10761;
            }
            else
            {
                _10760 = _10675;
            }
            float4 _5147 = _10433 * _10760;
            float _5149 = dot(_5147, 1.0f.xxxx);
            float4 _10980;
            bool _11000;
            if (_5149 > 0.0f)
            {
                _11000 = _10244;
                _10980 = _5147 / _5149.xxxx;
            }
            else
            {
                bool _5160 = any(bool4(_10760.x < 1.0f.xxxx.x, _10760.y < 1.0f.xxxx.y, _10760.z < 1.0f.xxxx.z, _10760.w < 1.0f.xxxx.w));
                if (_5160)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9015;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9015);
                    }
                }
                bool4 _12050 = _5160.xxxx;
                _11000 = _5160 ? true : _10244;
                _10980 = float4(_12050.x ? 0.0f.xxxx.x : _10433.x, _12050.y ? 0.0f.xxxx.y : _10433.y, _12050.z ? 0.0f.xxxx.z : _10433.z, _12050.w ? 0.0f.xxxx.w : _10433.w);
            }
            _11113 = _11192;
            _10999 = _11000;
            _10979 = _10980;
        }
        else
        {
            _11113 = float3(0.0f, 0.0f, 0.5f);
            _10999 = _10244;
            _10979 = _10433;
        }
        uint _5169 = (cbFI_pad0 >> 24u) & 31u;
        uint _5173 = (cbFI_pad0 >> 16u) & 255u;
        bool _5175 = _5169 != 0u;
        bool _5177 = _5173 == 12u;
        bool _5180 = _5173 == 13u;
        float4 _10996;
        if ((_5175 || _5177) || _5180)
        {
            float _10763;
            do
            {
                bool _9099 = all(bool2(_10094.x > 0.0f.xx.x, _10094.y > 0.0f.xx.y));
                bool _9105;
                if (_9099)
                {
                    _9105 = all(bool2(_10094.x < 1.0f.xx.x, _10094.y < 1.0f.xx.y));
                }
                else
                {
                    _9105 = _9099;
                }
                bool _9036 = !_9105;
                bool _9043;
                if (!_9036)
                {
                    bool _9110 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
                    bool _9116;
                    if (_9110)
                    {
                        _9116 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9116 = _9110;
                    }
                    _9043 = !_9116;
                }
                else
                {
                    _9043 = _9036;
                }
                if (_9043)
                {
                    _10763 = 0.0f;
                    break;
                }
                uint _9123_dummy_parameter;
                uint _9139_dummy_parameter;
                float4 _9064 = mul(float4((float2(_10094.x, 1.0f - _10094.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10094 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9123_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9066 = _9064.w;
                if (abs(_9066) < 9.9999999747524270787835121154785e-07f)
                {
                    _10763 = 0.0f;
                    break;
                }
                float _9077 = abs(cbFI_DeviceToViewDepth.y / ((_9064.z / _9066) - cbFI_DeviceToViewDepth.x));
                float _9080 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9139_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10763 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9077 - _9080) / max(max(_9077, _9080), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9187 = all(bool2(_10095.x > 0.0f.xx.x, _10095.y > 0.0f.xx.y));
            bool _9193;
            if (_9187)
            {
                _9193 = all(bool2(_10095.x < 1.0f.xx.x, _10095.y < 1.0f.xx.y));
            }
            else
            {
                _9193 = _9187;
            }
            float _10764;
            if (_9193)
            {
                uint _9200_dummy_parameter;
                _10764 = length((_5980 + (r_motion_tp1.Load(int3(int2(floor(_10095 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9200_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10764 = 1000000.0f;
            }
            float _10775;
            if ((_5169 & 1u) != 0u)
            {
                _10775 = _10763;
            }
            else
            {
                _10775 = 1.0f;
            }
            float _10776;
            if ((_5169 & 2u) != 0u)
            {
                _10776 = _10775 * (1.0f - smoothstep(2.0f, 8.0f, _10764));
            }
            else
            {
                _10776 = _10775;
            }
            float _10777;
            if ((_5169 & 4u) != 0u)
            {
                _10777 = _10776 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6701 - _6709) - length(_6685 - _6693))));
            }
            else
            {
                _10777 = _10776;
            }
            float _10990;
            if ((_5169 & 8u) != 0u)
            {
                _10990 = lerp(1.0f, _10777, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6685 - _6693)));
            }
            else
            {
                _10990 = _10777;
            }
            bool _5255 = (_5169 & 16u) != 0u;
            bool _5264;
            if (_5255)
            {
                _5264 = length(_10089 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5264 = _5255;
            }
            float _12052 = _5264 ? 1.0f : _10990;
            bool _5270 = _5175 && _6894;
            bool _5275;
            if (_5270)
            {
                bool _9225 = all(bool2(_10091.x > 0.0f.xx.x, _10091.y > 0.0f.xx.y));
                bool _9231;
                if (_9225)
                {
                    _9231 = all(bool2(_10091.x < 1.0f.xx.x, _10091.y < 1.0f.xx.y));
                }
                else
                {
                    _9231 = _9225;
                }
                _5275 = _9231;
            }
            else
            {
                _5275 = _5270;
            }
            bool _5280;
            if (_5275)
            {
                bool _9236 = all(bool2(_10093.x > 0.0f.xx.x, _10093.y > 0.0f.xx.y));
                bool _9242;
                if (_9236)
                {
                    _9242 = all(bool2(_10093.x < 1.0f.xx.x, _10093.y < 1.0f.xx.y));
                }
                else
                {
                    _9242 = _9236;
                }
                _5280 = _9242;
            }
            else
            {
                _5280 = _5275;
            }
            float4 _10997;
            if (_5280)
            {
                float _5286 = _10979.x + _10979.y;
                float _5295 = (_10979.z + _10979.w) * (1.0f - _12052);
                float _10993;
                if (_5286 > 9.9999997473787516355514526367188e-06f)
                {
                    _10993 = _10979.x / _5286;
                }
                else
                {
                    _10993 = _4251;
                }
                _10997 = float4(_10979.x + (_5295 * _10993), _10979.y + (_5295 * (1.0f - _10993)), _10979.zw * _12052);
            }
            else
            {
                _10997 = _10979;
            }
            _10996 = _10997;
        }
        else
        {
            _10996 = _10979;
        }
        float3 _11820;
        if (_10999)
        {
            float3 _9248 = r_current_interpolation_source.Load(int3(_3626, 0)).xyz;
            float3 _11821;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6894)
            {
                uint _9255_dummy_parameter;
                float _11104;
                _11104 = r_depth_tm1.Load(int3(int2(floor(_10091 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9255_dummy_parameter))))), 0)).x;
                float _5407;
                for (int _11103 = 0; _11103 < 24; _11104 = _5407, _11103++)
                {
                    float _5379 = float(_11103 & 7) * 0.785398185253143310546875f;
                    int _5381 = _11103 >> 3;
                    int _11871;
                    if (_5381 == 0)
                    {
                        _11871 = 16;
                    }
                    else
                    {
                        _11871 = (_5381 == 1) ? 48 : 96;
                    }
                    uint _9275_dummy_parameter;
                    _5407 = min(_11104, r_depth_tm1.Load(int3(int2(floor(clamp(_10091 + ((cbFI_MvDepthLaneSizeRcp * float(_11871)) * float2(cos(_5379), sin(_5379))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9275_dummy_parameter))))), 0)).x);
                }
                float2 _11105;
                do
                {
                    float _9297 = 1.0f - _10091.y;
                    float4 _9308 = mul(float4((float2(_10091.x, _9297) * 2.0f) - 1.0f.xx, _11104, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9310 = _9308.w;
                    if (!(_9310 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11105 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9323 = ((_9308.xy / _9310.xx) + 1.0f.xx) * 0.5f;
                    _11105 = float2(_9323.x - _10091.x, _9297 - _9323.y);
                    break;
                } while(false);
                float2 _5418 = _10091 + _11105;
                bool _9341 = all(bool2(_5418.x > 0.0f.xx.x, _5418.y > 0.0f.xx.y));
                bool _9347;
                if (_9341)
                {
                    _9347 = all(bool2(_5418.x < 1.0f.xx.x, _5418.y < 1.0f.xx.y));
                }
                else
                {
                    _9347 = _9341;
                }
                float3 _11822;
                if (_9347)
                {
                    float _5424 = abs(cbFI_DeviceToViewDepth.y / (_11104 - cbFI_DeviceToViewDepth.x));
                    uint _9367_dummy_parameter;
                    int2 _9367 = int2(spvTextureSize(r_depth_m2, uint(0), _9367_dummy_parameter));
                    float _5428 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5418 * float2(_9367))), int2(0, 0), _9367 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11827;
                    if (abs(_5428 - _5424) <= (0.20000000298023223876953125f * max(_5428, _5424)))
                    {
                        uint _9401_dummy_parameter;
                        int2 _9401 = int2(spvTextureSize(r_colour_m2, uint(0), _9401_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9424;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9424);
                        }
                        _11827 = r_colour_m2.Load(int3(clamp(int2(floor(_5418 * float2(_9401))), int2(0, 0), _9401 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9434;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9434);
                        }
                        _11827 = _9248;
                    }
                    _11822 = _11827;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9444;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9444);
                    }
                    _11822 = _9248;
                }
                _11821 = _11822;
            }
            else
            {
                _11821 = _9248;
            }
            _11820 = _11821;
        }
        else
        {
            _11820 = (((_6685 * _10996.x) + (_6693 * _10996.y)) + (_6701 * _10996.z)) + (_6709 * _10996.w);
        }
        uint _5456 = cbFI_pad0 & 255u;
        bool _11712;
        float3 _11819;
        if (_5456 != 0u)
        {
            float3 _5461 = r_present_backbuffer.Load(int3(_3626, 0)).xyz;
            float3 _5465 = r_current_interpolation_source.Load(int3(_3626, 0)).xyz;
            float3 _5469 = abs(_5461 - _5465);
            float3 _11108;
            if (_5456 == 2u)
            {
                _11108 = (abs(_5465) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11108 = 0.000244140625f.xxx;
            }
            bool _5485 = any(bool3(_5469.x > _11108.x, _5469.y > _11108.y, _5469.z > _11108.z));
            bool3 _12053 = _5485.xxx;
            _11819 = float3(_12053.x ? _5461.x : _11820.x, _12053.y ? _5461.y : _11820.y, _12053.z ? _5461.z : _11820.z);
            _11712 = _5485;
        }
        else
        {
            _11819 = _11820;
            _11712 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9459;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9459);
        }
        float3 _11802;
        if (_5173 == 1u)
        {
            _11802 = lerp(_6685, _6693, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11803;
            if (_5173 == 2u)
            {
                _11803 = lerp(_6701, _6709, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11804;
                if (_5173 == 3u)
                {
                    _11804 = float(_11712).xxx;
                }
                else
                {
                    float3 _11805;
                    if (_5173 == 4u)
                    {
                        _11805 = float3(((_10089 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11806;
                        if (_5173 == 5u)
                        {
                            _11806 = float3(((_5980 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11807;
                            if (_5173 == 6u)
                            {
                                _11807 = float3(_10996.xy, _10996.z + _10996.w);
                            }
                            else
                            {
                                float3 _11808;
                                if (_5173 == 7u)
                                {
                                    _11808 = r_current_interpolation_source.Load(int3(_3626, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11809;
                                    if (_5173 == 8u)
                                    {
                                        _11809 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4026, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11810;
                                        if (_5177)
                                        {
                                            uint _9481_dummy_parameter;
                                            uint _9513_dummy_parameter;
                                            _11810 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4026 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9481_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4026 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9513_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11811;
                                            if (_5180)
                                            {
                                                _11811 = _6701;
                                            }
                                            else
                                            {
                                                float3 _11812;
                                                if (_5173 == 20u)
                                                {
                                                    _11812 = _6685;
                                                }
                                                else
                                                {
                                                    float3 _11813;
                                                    if (_5173 == 21u)
                                                    {
                                                        _11813 = _6693;
                                                    }
                                                    else
                                                    {
                                                        float3 _11814;
                                                        if (_5173 == 22u)
                                                        {
                                                            _11814 = _6709;
                                                        }
                                                        else
                                                        {
                                                            float3 _11815;
                                                            if (_5173 == 18u)
                                                            {
                                                                _11815 = _11480;
                                                            }
                                                            else
                                                            {
                                                                float3 _11816;
                                                                if (_5173 == 19u)
                                                                {
                                                                    _11816 = _11294;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12055 = (_5173 == 23u).xxx;
                                                                    _11816 = float3(_12055.x ? _11113.x : _11819.x, _12055.y ? _11113.y : _11819.y, _12055.z ? _11113.z : _11819.z);
                                                                }
                                                                _11815 = _11816;
                                                            }
                                                            _11814 = _11815;
                                                        }
                                                        _11813 = _11814;
                                                    }
                                                    _11812 = _11813;
                                                }
                                                _11811 = _11812;
                                            }
                                            _11810 = _11811;
                                        }
                                        _11809 = _11810;
                                    }
                                    _11808 = _11809;
                                }
                                _11807 = _11808;
                            }
                            _11806 = _11807;
                        }
                        _11805 = _11806;
                    }
                    _11804 = _11805;
                }
                _11803 = _11804;
            }
            _11802 = _11803;
        }
        float3 _11801;
        if ((_5173 >= 9u) && (_5173 <= 11u))
        {
            uint _5649 = 64u + uint((_10121.y * cbFI_MvDepthLaneSize.x) + _10121.x);
            uint _5653 = rw_nfru_diagnostics.Load<uint>(_5649 * 4 + 0) & 15u;
            float3 _11832;
            if (_5173 == 10u)
            {
                float3 _11800;
                if ((rw_nfru_diagnostics.Load<uint>(_5649 * 4 + 0) & 32u) != 0u)
                {
                    _11800 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11799;
                    if ((rw_nfru_diagnostics.Load<uint>(_5649 * 4 + 0) & 16u) != 0u)
                    {
                        _11799 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5674 = ((rw_nfru_diagnostics.Load<uint>(_5649 * 4 + 0) & 64u) != 0u).xxx;
                        _11799 = float3(_5674.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5674.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5674.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11800 = _11799;
                }
                _11832 = _11800;
            }
            else
            {
                float3 _11833;
                if (_5173 == 11u)
                {
                    uint _5687 = (rw_nfru_diagnostics.Load<uint>(_5649 * 4 + 0) >> 8u) & 15u;
                    uint _5690 = (rw_nfru_diagnostics.Load<uint>(_5649 * 4 + 0) >> 12u) & 15u;
                    float3 _11792;
                    if ((_5653 == 2u) || (_5653 == 3u))
                    {
                        _11792 = _3322[_5653];
                    }
                    else
                    {
                        bool _5702 = _5687 == 3u;
                        bool _5704 = _5690 == 3u;
                        float3 _11793;
                        if (_5702 && _5704)
                        {
                            _11793 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11794;
                            if (_5702)
                            {
                                _11794 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11795;
                                if (_5704)
                                {
                                    _11795 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11796;
                                    if ((_5687 == 4u) || (_5690 == 4u))
                                    {
                                        _11796 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11797;
                                        if ((_5687 == 1u) || (_5690 == 1u))
                                        {
                                            _11797 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12057 = (_5653 == 1u).xxx;
                                            _11797 = float3(_12057.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12057.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12057.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11796 = _11797;
                                    }
                                    _11795 = _11796;
                                }
                                _11794 = _11795;
                            }
                            _11793 = _11794;
                        }
                        _11792 = _11793;
                    }
                    _11833 = _11792;
                }
                else
                {
                    _11833 = _3322[min(_5653, 7u)];
                }
                _11832 = _11833;
            }
            _11801 = _11832;
        }
        else
        {
            _11801 = _11802;
        }
        float4 _11836;
        if ((_5173 >= 14u) && (_5173 <= 16u))
        {
            float2 _11834;
            if (_5173 == 14u)
            {
                uint _5760_dummy_parameter;
                uint _5766_dummy_parameter;
                _11834 = r_flow_tm1.Load(int3(clamp(int2(floor(_4026 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5760_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5766_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11835;
                if (_5173 == 16u)
                {
                    uint _9564 = r_warped_flow_qdata_tm1.Load(int3(_4042, 0)).x & 2147483647u;
                    uint _9596 = uint(max((int((_9564 >> 16u) & 15u) - 6), 0));
                    _11835 = ((float2(float((1 - (2 * int((_9564 >> 15u) & 1u))) * int(((_9564 >> uint(7)) & 127u) << _9596)), float((1 - (2 * int((_9564 >> 14u) & 1u))) * int((_9564 & 127u) << _9596))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11835 = _5980 * float2(cbFI_DisplaySize);
                }
                _11834 = _11835;
            }
            uint2 _5799 = uint2(clamp(round(_11834 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5801 = _5799.x;
            uint _5808 = _5799.y;
            _11836 = float4(float(_5801 & 255u), float((_5801 >> 8u) | ((_5808 & 15u) << 4u)), float(_5808 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11837;
            if (_5173 == 17u)
            {
                _11837 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4042, 0)).x != 0u), _4385, 0.0f, 1.0f);
            }
            else
            {
                _11837 = float4(_11801, 1.0f);
            }
            _11836 = _11837;
        }
        rw_output[_3626] = _11836.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5852 = ((uint(_3626.y) * uint(cbFI_DisplaySize.x)) + uint(_3626.x)) * 6u;
            uint _9642 = spvPackHalf2x16(clamp(_6684.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5852 * 4 + 0, (((_9642 & 32767u) >> 4u) | ((((_9642 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6684.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9677 = spvPackHalf2x16(clamp(_6692.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5852 + 1u) * 4 + 0, (((_9677 & 32767u) >> 4u) | ((((_9677 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6692.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9712 = spvPackHalf2x16(clamp(_6700.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5852 + 2u) * 4 + 0, (((_9712 & 32767u) >> 4u) | ((((_9712 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6700.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9747 = spvPackHalf2x16(clamp(_6708.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5852 + 3u) * 4 + 0, (((_9747 & 32767u) >> 4u) | ((((_9747 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6708.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9774 = r_current_interpolation_source.Load(int3(_3626, 0));
            uint _9788 = spvPackHalf2x16(clamp(_9774.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5852 + 4u) * 4 + 0, (((_9788 & 32767u) >> 4u) | ((((_9788 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9774.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11870;
            if (_11712 || (_5173 != 0u))
            {
                _11870 = 4294967295u;
            }
            else
            {
                uint _9823 = spvPackHalf2x16(clamp(_11836.xy, 0.0f.xx, 65000.0f.xx));
                _11870 = (((_9823 & 32767u) >> 4u) | ((((_9823 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11836.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5852 + 5u) * 4 + 0, _11870);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3626] = float4(r_current_interpolation_source.Load(int3(_3626, 0)).xyz, 1.0f).xyz;
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
