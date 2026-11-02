static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3048[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3335 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3335.x >= cbFI_DisplaySize.x, _3335.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3335] = float4(r_present_backbuffer.Load(int3(_3335, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3691 = (float2(_3335) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3702 = int2(floor(_3691 * float2(cbFI_MvDepthLaneSize)));
        int2 _3707 = int2(floor(_3691 * float2(cbFI_FlowLaneSize)));
        float4 _5397 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3691 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5403 = r_warped_filled_flow_tm1.Load(int3(_3707, 0)).xy;
        float2 _5409 = r_warped_filled_motion_tp1.Load(int3(_3702, 0)).xy;
        bool _5431 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8889;
        if (_5431)
        {
            float _5444 = ((2.0f * _3691.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8889 = float2(atan(_5444) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3691.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5444 * _5444))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8889 = _3691;
        }
        bool _3728 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8910;
        bool _8931;
        int2 _8942;
        float3 _9851;
        if (_3728)
        {
            float _8891;
            float _8893;
            _8893 = 2.0f;
            _8891 = -1.0f;
            uint _3397[9];
            float _10238;
            float _10241;
            for (int _8890 = 0; _8890 < 9; _8893 = _10241, _8891 = _10238, _8890++)
            {
                _3397[_8890] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3702 + int2((_8890 % 3) - 1, (_8890 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3397[_8890] != 0u)
                {
                    float _10233;
                    if (_3397[_8890] == 0u)
                    {
                        _10233 = -1.0f;
                    }
                    else
                    {
                        _10233 = float((_3397[_8890] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10241 = min(_8893, _10233);
                    _10238 = max(_8891, _10233);
                }
                else
                {
                    _10241 = _8893;
                    _10238 = _8891;
                }
            }
            float _3774 = float(_8891 >= 0.0f);
            float3 _8700 = 0.0f.xxx;
            _8700.y = _3774;
            float2 _8911;
            bool _8932;
            int2 _8943;
            float3 _9852;
            if ((_8891 - _8893) > 0.0199999995529651641845703125f)
            {
                float _8899;
                int2 _8900;
                float2 _8901;
                int2 _8903;
                float2 _8909;
                _8909 = _5409;
                _8903 = _3702;
                _8901 = _5409;
                _8900 = _3702;
                _8899 = -1.0f;
                float _10246;
                int2 _10250;
                float2 _10261;
                int2 _10272;
                float2 _10305;
                float _10350;
                int _8898 = 0;
                float _10214 = 1000000000.0f;
                for (; _8898 < 9; _10214 = _10350, _8909 = _10305, _8903 = _10272, _8901 = _10261, _8900 = _10250, _8899 = _10246, _8898++)
                {
                    if (_3397[_8898] == 0u)
                    {
                        _10350 = _10214;
                        _10305 = _8909;
                        _10272 = _8903;
                        _10261 = _8901;
                        _10250 = _8900;
                        _10246 = _8899;
                        continue;
                    }
                    int2 _3809 = clamp(_3702 + int2((_8898 % 3) - 1, (_8898 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5519 = _3397[_8898] & 2147483647u;
                    uint _5551 = uint(max((int((_5519 >> 16u) & 15u) - 6), 0));
                    float2 _3815 = (float2(float((1 - (2 * int((_5519 >> 15u) & 1u))) * int(((_5519 >> uint(7)) & 127u) << _5551)), float((1 - (2 * int((_5519 >> 14u) & 1u))) * int((_5519 & 127u) << _5551))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10200;
                    if (_3397[_8898] == 0u)
                    {
                        _10200 = -1.0f;
                    }
                    else
                    {
                        _10200 = float((_3397[_8898] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3820 = _10200 - 0.100000001490116119384765625f;
                    float2 _10201;
                    if (_5431)
                    {
                        float2 _5628 = clamp((((_8889 + (_3815 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5631 = tan(_5628.x);
                        _10201 = (float2(_5631 / cbFI_DeviceToViewDepth.z, (tan(_5628.y) * sqrt(1.0f + (_5631 * _5631))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10201 = _8889 + (_3815 * cbFI_Timestep);
                    }
                    float _3827 = cbFI_Timestep - 1.0f;
                    float2 _10202;
                    if (_5431)
                    {
                        float2 _5699 = clamp((((_8889 + (_3815 * _3827)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5702 = tan(_5699.x);
                        _10202 = (float2(_5702 / cbFI_DeviceToViewDepth.z, (tan(_5699.y) * sqrt(1.0f + (_5702 * _5702))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10202 = _8889 + (_3815 * _3827);
                    }
                    bool _5735 = all(bool2(_10201.x > 0.0f.xx.x, _10201.y > 0.0f.xx.y));
                    bool _5741;
                    if (_5735)
                    {
                        _5741 = all(bool2(_10201.x < 1.0f.xx.x, _10201.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5741 = _5735;
                    }
                    float _10205;
                    if (_5741)
                    {
                        uint _5748_dummy_parameter;
                        _10205 = max((_3820 - (log(((r_depth_tm1.Load(int3(int2(floor(_10201 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5748_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10205 = 0.0f;
                    }
                    bool _5778 = all(bool2(_10202.x > 0.0f.xx.x, _10202.y > 0.0f.xx.y));
                    bool _5784;
                    if (_5778)
                    {
                        _5784 = all(bool2(_10202.x < 1.0f.xx.x, _10202.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5784 = _5778;
                    }
                    float _10206;
                    if (_5784)
                    {
                        uint _5791_dummy_parameter;
                        _10206 = _10205 + max((_3820 - (log(((r_depth_tp1.Load(int3(int2(floor(_10202 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5791_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10206 = _10205;
                    }
                    float _10247;
                    int2 _10251;
                    float2 _10262;
                    int2 _10273;
                    float2 _10306;
                    float _10351;
                    if (_10206 == 0.0f)
                    {
                        bool _3862 = _3820 > _8899;
                        bool2 _10359 = _3862.xx;
                        _10351 = _10214;
                        _10306 = float2(_10359.x ? _3815.x : _8909.x, _10359.y ? _3815.y : _8909.y);
                        _10273 = int2(_10359.x ? _3809.x : _8903.x, _10359.y ? _3809.y : _8903.y);
                        _10262 = _8901;
                        _10251 = _8900;
                        _10247 = _3862 ? _3820 : _8899;
                    }
                    else
                    {
                        bool _3871 = _10206 < _10214;
                        bool2 _10355 = _3871.xx;
                        _10351 = _3871 ? _10206 : _10214;
                        _10306 = _8909;
                        _10273 = _8903;
                        _10262 = float2(_10355.x ? _3815.x : _8901.x, _10355.y ? _3815.y : _8901.y);
                        _10251 = int2(_10355.x ? _3809.x : _8900.x, _10355.y ? _3809.y : _8900.y);
                        _10247 = _8899;
                    }
                    _10350 = _10351;
                    _10305 = _10306;
                    _10272 = _10273;
                    _10261 = _10262;
                    _10250 = _10251;
                    _10246 = _10247;
                }
                bool _3883 = _8899 < 0.0f;
                bool2 _10365 = _3883.xx;
                int2 _10368 = int2(_10365.x ? _8900.x : _8903.x, _10365.y ? _8900.y : _8903.y);
                _9852 = float3(1.0f, _3774, float(any(bool2(_10368.x != _3702.x, _10368.y != _3702.y))));
                _8943 = _10368;
                _8932 = _3883 ? false : true;
                _8911 = float2(_10365.x ? _8901.x : _8909.x, _10365.y ? _8901.y : _8909.y);
            }
            else
            {
                _9852 = _8700;
                _8943 = _3702;
                _8932 = false;
                _8911 = _5409;
            }
            _9851 = _9852;
            _8942 = _8943;
            _8931 = _8932;
            _8910 = _8911;
        }
        else
        {
            _9851 = 0.0f.xxx;
            _8942 = _3702;
            _8931 = false;
            _8910 = _5409;
        }
        float2 _8912;
        if (_5431)
        {
            float2 _5856 = clamp((((_8889 + (_8910 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5859 = tan(_5856.x);
            _8912 = (float2(_5859 / cbFI_DeviceToViewDepth.z, (tan(_5856.y) * sqrt(1.0f + (_5859 * _5859))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8912 = _8889 + (_8910 * cbFI_Timestep);
        }
        float _3906 = cbFI_Timestep - 1.0f;
        float2 _8914;
        if (_5431)
        {
            float2 _5927 = clamp((((_8889 + (_8910 * _3906)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5930 = tan(_5927.x);
            _8914 = (float2(_5930 / cbFI_DeviceToViewDepth.z, (tan(_5927.y) * sqrt(1.0f + (_5930 * _5930))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8914 = _8889 + (_8910 * _3906);
        }
        float _3911 = -cbFI_Timestep;
        float2 _8915;
        if (_5431)
        {
            float2 _5998 = clamp((((_8889 + (_5403 * _3911)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6001 = tan(_5998.x);
            _8915 = (float2(_6001 / cbFI_DeviceToViewDepth.z, (tan(_5998.y) * sqrt(1.0f + (_6001 * _6001))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8915 = _8889 + (_5403 * _3911);
        }
        float _3916 = 1.0f - cbFI_Timestep;
        float2 _8916;
        if (_5431)
        {
            float2 _6069 = clamp((((_8889 + (_5403 * _3916)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6072 = tan(_6069.x);
            _8916 = (float2(_6072 / cbFI_DeviceToViewDepth.z, (tan(_6069.y) * sqrt(1.0f + (_6072 * _6072))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8916 = _8889 + (_5403 * _3916);
        }
        float4 _6107 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8912, 0.0f);
        float3 _6108 = _6107.xyz;
        float4 _6115 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8914, 0.0f);
        float3 _6116 = _6115.xyz;
        float4 _6123 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8915, 0.0f);
        float3 _6124 = _6123.xyz;
        float4 _6131 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8916, 0.0f);
        float3 _6132 = _6131.xyz;
        float4 _6146 = exp(_5397 - max(max(max(_5397.x, _5397.y), _5397.z), _5397.w).xxxx);
        float4 _6153 = _6146 / (dot(_6146, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3935 = _3728 && (!_8931);
        bool _3944;
        if (_3935)
        {
            _3944 = (_6153.z + _6153.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3944 = _3935;
        }
        bool _3955;
        if (_3944)
        {
            _3955 = length((_8915 - _8912) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3955 = _3944;
        }
        bool _8955;
        if (_3955)
        {
            uint4 _6172 = r_warped_motion_qdata_tp1.Load(int3(_8942, 0));
            uint _6173 = _6172.x;
            bool _8958;
            if (_6173 != 0u)
            {
                float _8944;
                if (_6173 == 0u)
                {
                    _8944 = -1.0f;
                }
                else
                {
                    _8944 = float((_6173 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3965 = _8944 - 0.12000000476837158203125f;
                bool _6192 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
                bool _6198;
                if (_6192)
                {
                    _6198 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
                }
                else
                {
                    _6198 = _6192;
                }
                bool _3975;
                if (_6198)
                {
                    uint _6205_dummy_parameter;
                    _3975 = (log(((r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6205_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3965;
                }
                else
                {
                    _3975 = _6198;
                }
                bool _3989;
                if (!_3975)
                {
                    bool _6235 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
                    bool _6241;
                    if (_6235)
                    {
                        _6241 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6241 = _6235;
                    }
                    bool _3987;
                    if (_6241)
                    {
                        uint _6248_dummy_parameter;
                        _3987 = (log(((r_depth_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6248_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3965;
                    }
                    else
                    {
                        _3987 = _6241;
                    }
                    _3989 = _3987;
                }
                else
                {
                    _3989 = _3975;
                }
                _8958 = _3989;
            }
            else
            {
                _8958 = false;
            }
            _8955 = _8958;
        }
        else
        {
            _8955 = false;
        }
        bool _3994 = _8931 || _8955;
        bool _3999;
        if (_3994)
        {
            bool _6278 = all(bool2(_8912.x > 0.0f.xx.x, _8912.y > 0.0f.xx.y));
            bool _6284;
            if (_6278)
            {
                _6284 = all(bool2(_8912.x < 1.0f.xx.x, _8912.y < 1.0f.xx.y));
            }
            else
            {
                _6284 = _6278;
            }
            _3999 = _6284;
        }
        else
        {
            _3999 = _3994;
        }
        bool _4004;
        if (_3999)
        {
            bool _6289 = all(bool2(_8914.x > 0.0f.xx.x, _8914.y > 0.0f.xx.y));
            bool _6295;
            if (_6289)
            {
                _6295 = all(bool2(_8914.x < 1.0f.xx.x, _8914.y < 1.0f.xx.y));
            }
            else
            {
                _6295 = _6289;
            }
            _4004 = _6295;
        }
        else
        {
            _4004 = _3999;
        }
        float4 _9049;
        if (_4004)
        {
            float _4007 = _6153.x;
            float _4009 = _6153.y;
            float _4010 = _4007 + _4009;
            float _4015 = _6153.z + _6153.w;
            float _8973;
            if (_4010 > 0.001000000047497451305389404296875f)
            {
                _8973 = _4007 / _4010;
            }
            else
            {
                _8973 = _3916;
            }
            _9049 = float4(_4007 + (_4015 * _8973), _4009 + (_4015 * (1.0f - _8973)), 0.0f, 0.0f);
        }
        else
        {
            _9049 = _6153;
        }
        bool _6323 = (cbFI_pad0 & 1024u) != 0u;
        bool _6299 = !_6323;
        bool _6300 = !_6299;
        bool _6317;
        if (_6300)
        {
            _6317 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8942.y * cbFI_MvDepthLaneSize.x) + _8942.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6317 = _6299;
        }
        bool _6349;
        if (_6300)
        {
            _6349 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3707.y * cbFI_FlowLaneSize.x) + _3707.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6349 = _6299;
        }
        float _4050 = float(_6349);
        bool _9061;
        float4 _9091;
        float3 _9708;
        if (_6323)
        {
            bool _4060;
            if (_6317)
            {
                _4060 = all(bool2(_8912.x > 0.0f.xx.x, _8912.y > 0.0f.xx.y));
            }
            else
            {
                _4060 = _6317;
            }
            bool _4066;
            if (_4060)
            {
                _4066 = all(bool2(_8912.x < 1.0f.xx.x, _8912.y < 1.0f.xx.y));
            }
            else
            {
                _4066 = _4060;
            }
            bool _4073;
            if (_6317)
            {
                _4073 = all(bool2(_8914.x > 0.0f.xx.x, _8914.y > 0.0f.xx.y));
            }
            else
            {
                _4073 = _6317;
            }
            bool _4079;
            if (_4073)
            {
                _4079 = all(bool2(_8914.x < 1.0f.xx.x, _8914.y < 1.0f.xx.y));
            }
            else
            {
                _4079 = _4073;
            }
            bool _4086;
            if (_6349)
            {
                _4086 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
            }
            else
            {
                _4086 = _6349;
            }
            bool _4092;
            if (_4086)
            {
                _4092 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
            }
            else
            {
                _4092 = _4086;
            }
            bool _4099;
            if (_6349)
            {
                _4099 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
            }
            else
            {
                _4099 = _6349;
            }
            bool _4105;
            if (_4099)
            {
                _4105 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
            }
            else
            {
                _4105 = _4099;
            }
            bool _4107 = !_6317;
            if (_4107)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6391;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6391);
                }
            }
            bool _4112 = !_6349;
            if (_4112)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6401;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6401);
                }
            }
            if (_6317 && _4112)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6411;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6411);
                }
            }
            if (_4107 && _6349)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6421;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6421);
                }
            }
            float _4131 = float(_4066);
            float _4133 = float(_4079);
            bool _4136 = _4092 && _4105;
            float _9007;
            if (_4136)
            {
                _9007 = 1.0f;
            }
            else
            {
                _9007 = (_4092 || _4105) ? 0.5f : 0.0f;
            }
            bool _9012;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4066)) && (!_4079))
            {
                bool _4166;
                if (_4136)
                {
                    float _9010;
                    do
                    {
                        bool _6505 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
                        bool _6511;
                        if (_6505)
                        {
                            _6511 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6511 = _6505;
                        }
                        bool _6442 = !_6511;
                        bool _6449;
                        if (!_6442)
                        {
                            bool _6516 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
                            bool _6522;
                            if (_6516)
                            {
                                _6522 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6522 = _6516;
                            }
                            _6449 = !_6522;
                        }
                        else
                        {
                            _6449 = _6442;
                        }
                        if (_6449)
                        {
                            _9010 = 0.0f;
                            break;
                        }
                        uint _6529_dummy_parameter;
                        uint _6545_dummy_parameter;
                        float4 _6470 = mul(float4((float2(_8915.x, 1.0f - _8915.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6529_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6472 = _6470.w;
                        if (abs(_6472) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9010 = 0.0f;
                            break;
                        }
                        float _6483 = abs(cbFI_DeviceToViewDepth.y / ((_6470.z / _6472) - cbFI_DeviceToViewDepth.x));
                        float _6486 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6545_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9010 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6483 - _6486) / max(max(_6483, _6486), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4166 = _9010 >= 0.5f;
                }
                else
                {
                    _4166 = _4136;
                }
                bool _9013;
                if (_4166)
                {
                    uint _6595_dummy_parameter;
                    float2 _9011;
                    do
                    {
                        float _6621 = 1.0f - _8915.y;
                        float4 _6632 = mul(float4((float2(_8915.x, _6621) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6595_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6634 = _6632.w;
                        if (!(_6634 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9011 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6647 = ((_6632.xy / _6634.xx) + 1.0f.xx) * 0.5f;
                        _9011 = float2(_6647.x - _8915.x, _6621 - _6647.y);
                        break;
                    } while(false);
                    float2 _4180 = float2(cbFI_DisplaySize);
                    _9013 = length(((_8915 + _9011) - _8916) * _4180) <= ((0.100000001490116119384765625f * length(_9011 * _4180)) + 8.0f);
                }
                else
                {
                    _9013 = _4166;
                }
                _9012 = _9013;
            }
            else
            {
                _9012 = true;
            }
            bool _4194 = !_9012;
            bool _10369 = _4194 ? false : _4105;
            bool _10370 = _4194 ? false : _4092;
            bool _9062;
            float4 _9092;
            if (!(((_4066 && _4079) && _10370) && _10369))
            {
                float4 _4216 = _9049 * float4(_4131, _4133, float(_10370), float(_10369));
                float _4218 = dot(_4216, 1.0f.xxxx);
                bool _4221 = !(_4218 > 0.0f);
                float4 _9093;
                if (!_4221)
                {
                    _9093 = _4216 / _4218.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6669;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6669);
                    }
                    _9093 = 0.0f.xxxx;
                }
                _9092 = _9093;
                _9062 = _4221;
            }
            else
            {
                _9092 = _9049;
                _9062 = false;
            }
            _9708 = float3(_4131, _4133, _9007);
            _9091 = _9092;
            _9061 = _9062;
        }
        else
        {
            _9708 = float3(float(_6317), _4050, 0.0f);
            _9091 = _9049;
            _9061 = false;
        }
        float4 _9575;
        bool _9595;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9061))
        {
            bool _4244 = _9091.x > 0.00999999977648258209228515625f;
            bool _4247 = _9091.y > 0.00999999977648258209228515625f;
            bool _4256 = (_9091.z + _9091.w) > 0.0199999995529651641845703125f;
            bool _4262;
            if (_4256)
            {
                bool _6675 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
                bool _6681;
                if (_6675)
                {
                    _6681 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
                }
                else
                {
                    _6681 = _6675;
                }
                _4262 = _6681;
            }
            else
            {
                _4262 = _4256;
            }
            bool _4267;
            if (_4262)
            {
                bool _6686 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
                bool _6692;
                if (_6686)
                {
                    _6692 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
                }
                else
                {
                    _6692 = _6686;
                }
                _4267 = _6692;
            }
            else
            {
                _4267 = _4262;
            }
            bool _4274;
            if (_4267)
            {
                float _9095;
                do
                {
                    bool _6775 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
                    bool _6781;
                    if (_6775)
                    {
                        _6781 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6781 = _6775;
                    }
                    bool _6712 = !_6781;
                    bool _6719;
                    if (!_6712)
                    {
                        bool _6786 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
                        bool _6792;
                        if (_6786)
                        {
                            _6792 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6792 = _6786;
                        }
                        _6719 = !_6792;
                    }
                    else
                    {
                        _6719 = _6712;
                    }
                    if (_6719)
                    {
                        _9095 = 0.0f;
                        break;
                    }
                    uint _6799_dummy_parameter;
                    uint _6815_dummy_parameter;
                    float4 _6740 = mul(float4((float2(_8915.x, 1.0f - _8915.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6799_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6742 = _6740.w;
                    if (abs(_6742) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9095 = 0.0f;
                        break;
                    }
                    float _6753 = abs(cbFI_DeviceToViewDepth.y / ((_6740.z / _6742) - cbFI_DeviceToViewDepth.x));
                    float _6756 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6815_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9095 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6753 - _6756) / max(max(_6753, _6756), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4274 = _9095 < 0.5f;
            }
            else
            {
                _4274 = _4267;
            }
            float4 _9110;
            if (_4274)
            {
                uint _6865_dummy_parameter;
                uint _6896_dummy_parameter;
                float4 _9111;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6865_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6896_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9111 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9111 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9110 = _9111;
            }
            else
            {
                _9110 = 1.0f.xxxx;
            }
            bool _4298;
            if (_6317)
            {
                bool _6925 = all(bool2(_8912.x > 0.0f.xx.x, _8912.y > 0.0f.xx.y));
                bool _6931;
                if (_6925)
                {
                    _6931 = all(bool2(_8912.x < 1.0f.xx.x, _8912.y < 1.0f.xx.y));
                }
                else
                {
                    _6931 = _6925;
                }
                _4298 = _6931;
            }
            else
            {
                _4298 = _6317;
            }
            bool _4304;
            if (_6317)
            {
                bool _6936 = all(bool2(_8914.x > 0.0f.xx.x, _8914.y > 0.0f.xx.y));
                bool _6942;
                if (_6936)
                {
                    _6942 = all(bool2(_8914.x < 1.0f.xx.x, _8914.y < 1.0f.xx.y));
                }
                else
                {
                    _6942 = _6936;
                }
                _4304 = _6942;
            }
            else
            {
                _4304 = _6317;
            }
            bool _4310;
            if (_6349)
            {
                bool _6947 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
                bool _6953;
                if (_6947)
                {
                    _6953 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
                }
                else
                {
                    _6953 = _6947;
                }
                _4310 = _6953;
            }
            else
            {
                _4310 = _6349;
            }
            bool _4316;
            if (_6349)
            {
                bool _6958 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
                bool _6964;
                if (_6958)
                {
                    _6964 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
                }
                else
                {
                    _6964 = _6958;
                }
                _4316 = _6964;
            }
            else
            {
                _4316 = _6349;
            }
            bool _4319 = _4310 != _4316;
            bool _4325;
            if (_4319)
            {
                _4325 = _4298 || _4304;
            }
            else
            {
                _4325 = _4319;
            }
            float4 _9190;
            if (_4325)
            {
                float4 _8785 = _9110;
                _8785.z = 0.0f;
                _8785.w = 0.0f;
                _9190 = _8785;
            }
            else
            {
                _9190 = _9110;
            }
            bool _4332 = _4298 && _4244;
            bool _4335 = _4304 && _4247;
            float4 _9294;
            if (_4332 || _4335)
            {
                float _9187;
                do
                {
                    uint4 _7103 = r_warped_motion_qdata_tp1.Load(int3(_8942, 0));
                    uint _7104 = _7103.x;
                    if (_7104 != 0u)
                    {
                        float _9186;
                        if (_7104 == 0u)
                        {
                            _9186 = -1.0f;
                        }
                        else
                        {
                            _9186 = float((_7104 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9187 = _9186;
                        break;
                    }
                    int _9169;
                    uint _9170;
                    _9170 = _7104;
                    _9169 = -1;
                    uint _9185;
                    for (; _9169 <= 1; _9170 = _9185, _9169++)
                    {
                        _9185 = _9170;
                        for (int _9183 = -1; _9183 <= 1; )
                        {
                            _9185 = max(_9185, r_warped_motion_qdata_tp1.Load(int3(clamp(_8942 + int2(_9183, _9169), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9183++;
                            continue;
                        }
                    }
                    if (_9170 != 0u)
                    {
                        float _9182;
                        if (_9170 == 0u)
                        {
                            _9182 = -1.0f;
                        }
                        else
                        {
                            _9182 = float((_9170 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9187 = _9182;
                        break;
                    }
                    uint _9172;
                    _9172 = 4294967295u;
                    uint _10342;
                    for (int _9171 = 0; _9171 < 8; _9172 = _10342, _9171++)
                    {
                        int _9175 = 0;
                        for (;;)
                        {
                            if (_9175 < 5)
                            {
                                int2 _7054 = _8942 + (_1085[_9171] * _1094[_9175].xx);
                                bool _7057 = any(bool2(_7054.x < int2(0, 0).x, _7054.y < int2(0, 0).y));
                                bool _7065;
                                if (!_7057)
                                {
                                    _7065 = any(bool2(_7054.x >= cbFI_MvDepthLaneSize.x, _7054.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7065 = _7057;
                                }
                                if (_7065)
                                {
                                    _10342 = _9172;
                                    break;
                                }
                                uint4 _7143 = r_warped_motion_qdata_tp1.Load(int3(_7054, 0));
                                uint _7144 = _7143.x;
                                if (_7144 != 0u)
                                {
                                    _10342 = min(_9172, _7144);
                                    break;
                                }
                                _9175++;
                                continue;
                            }
                            else
                            {
                                _10342 = _9172;
                                break;
                            }
                        }
                    }
                    float _9174;
                    if (_9172 == 4294967295u)
                    {
                        _9174 = -1.0f;
                    }
                    else
                    {
                        float _9173;
                        if (_9172 == 0u)
                        {
                            _9173 = -1.0f;
                        }
                        else
                        {
                            _9173 = float((_9172 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9174 = _9173;
                    }
                    _9187 = _9174;
                    break;
                } while(false);
                float4 _9223;
                if (((_9187 < 0.0f) && _4332) && _4335)
                {
                    uint _7165_dummy_parameter;
                    float _7189 = log(((r_depth_tm1.Load(int3(int2(floor(_8912 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7165_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7197_dummy_parameter;
                    float _7221 = log(((r_depth_tp1.Load(int3(int2(floor(_8914 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7197_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9224;
                    if (_7189 > (_7221 + 0.07999999821186065673828125f))
                    {
                        float4 _8789 = _9190;
                        _8789.x = 0.0f;
                        _9224 = _8789;
                    }
                    else
                    {
                        float4 _9225;
                        if (_7221 > (_7189 + 0.07999999821186065673828125f))
                        {
                            float4 _8791 = _9190;
                            _8791.y = 0.0f;
                            _9225 = _8791;
                        }
                        else
                        {
                            _9225 = _9190;
                        }
                        _9224 = _9225;
                    }
                    _9223 = _9224;
                }
                else
                {
                    _9223 = _9190;
                }
                float _4375 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4377 = _9187 >= 0.0f;
                float _9206;
                if (_4377)
                {
                    _9206 = _9187 - _4375;
                }
                else
                {
                    float _9202;
                    if (_4332)
                    {
                        float _9201;
                        _9201 = 2.0f;
                        float _7279;
                        for (int _9200 = 0; _9200 < 24; _9201 = _7279, _9200++)
                        {
                            float _7243 = float(_9200 & 7) * 0.785398185253143310546875f;
                            int _7245 = _9200 >> 3;
                            int _9203;
                            if (_7245 == 0)
                            {
                                _9203 = 16;
                            }
                            else
                            {
                                _9203 = (_7245 == 1) ? 48 : 96;
                            }
                            uint _7295_dummy_parameter;
                            _7279 = min(_9201, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_8912 + ((cbFI_MvDepthLaneSizeRcp * float(_9203)) * float2(cos(_7243), sin(_7243))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7295_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9202 = _9201;
                    }
                    else
                    {
                        _9202 = 0.0f;
                    }
                    _9206 = _9202;
                }
                float _9213;
                if (_4377)
                {
                    _9213 = _9187 - _4375;
                }
                else
                {
                    float _9209;
                    if (_4335)
                    {
                        float _9208;
                        _9208 = 2.0f;
                        float _7393;
                        for (int _9207 = 0; _9207 < 24; _9208 = _7393, _9207++)
                        {
                            float _7357 = float(_9207 & 7) * 0.785398185253143310546875f;
                            int _7359 = _9207 >> 3;
                            int _9210;
                            if (_7359 == 0)
                            {
                                _9210 = 16;
                            }
                            else
                            {
                                _9210 = (_7359 == 1) ? 48 : 96;
                            }
                            uint _7425_dummy_parameter;
                            _7393 = min(_9208, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_8914 + ((cbFI_MvDepthLaneSizeRcp * float(_9210)) * float2(cos(_7357), sin(_7357))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7425_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9209 = _9208;
                    }
                    else
                    {
                        _9209 = 0.0f;
                    }
                    _9213 = _9209;
                }
                float _9214;
                if (_4332)
                {
                    uint _7457_dummy_parameter;
                    _9214 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_8912 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7457_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9214 = 0.0f;
                }
                float _9215;
                if (_4335)
                {
                    uint _7477_dummy_parameter;
                    _9215 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_8914 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7477_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9215 = 0.0f;
                }
                bool _4432;
                if (_4332)
                {
                    _4432 = _9214 > ((exp((_9206 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4432 = _4332;
                }
                float4 _9231;
                if (_4432)
                {
                    float4 _8793 = _9223;
                    _8793.x = 0.0f;
                    _9231 = _8793;
                }
                else
                {
                    _9231 = _9223;
                }
                bool _4444;
                if (_4335)
                {
                    _4444 = _9215 > ((exp((_9213 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4444 = _4335;
                }
                float4 _9233;
                if (_4444)
                {
                    float4 _8795 = _9231;
                    _8795.y = 0.0f;
                    _9233 = _8795;
                }
                else
                {
                    _9233 = _9231;
                }
                float4 _9295;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4377)
                {
                    bool _4464;
                    if (_4332)
                    {
                        _4464 = _9214 < ((exp((_9206 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4464 = _4332;
                    }
                    float4 _9235;
                    if (_4464)
                    {
                        float4 _8797 = _9233;
                        _8797.x = 0.0f;
                        _9235 = _8797;
                    }
                    else
                    {
                        _9235 = _9233;
                    }
                    bool _4476;
                    if (_4335)
                    {
                        _4476 = _9215 < ((exp((_9213 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4476 = _4335;
                    }
                    float4 _9296;
                    if (_4476)
                    {
                        float4 _8799 = _9235;
                        _8799.y = 0.0f;
                        _9296 = _8799;
                    }
                    else
                    {
                        _9296 = _9235;
                    }
                    _9295 = _9296;
                }
                else
                {
                    _9295 = _9233;
                }
                _9294 = _9295;
            }
            else
            {
                _9294 = _9190;
            }
            bool _4487 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4256;
            bool _4493;
            if (_4487)
            {
                _4493 = _4310 || _4316;
            }
            else
            {
                _4493 = _4487;
            }
            float4 _9316;
            if (_4493)
            {
                float _9289;
                do
                {
                    uint4 _7657 = r_warped_motion_qdata_tp1.Load(int3(_8942, 0));
                    uint _7658 = _7657.x;
                    if (_7658 != 0u)
                    {
                        float _9288;
                        if (_7658 == 0u)
                        {
                            _9288 = -1.0f;
                        }
                        else
                        {
                            _9288 = float((_7658 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9289 = _9288;
                        break;
                    }
                    int _9271;
                    uint _9272;
                    _9272 = _7658;
                    _9271 = -1;
                    uint _9287;
                    for (; _9271 <= 1; _9272 = _9287, _9271++)
                    {
                        _9287 = _9272;
                        for (int _9285 = -1; _9285 <= 1; )
                        {
                            _9287 = max(_9287, r_warped_motion_qdata_tp1.Load(int3(clamp(_8942 + int2(_9285, _9271), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9285++;
                            continue;
                        }
                    }
                    if (_9272 != 0u)
                    {
                        float _9284;
                        if (_9272 == 0u)
                        {
                            _9284 = -1.0f;
                        }
                        else
                        {
                            _9284 = float((_9272 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9289 = _9284;
                        break;
                    }
                    uint _9274;
                    _9274 = 4294967295u;
                    uint _10343;
                    for (int _9273 = 0; _9273 < 8; _9274 = _10343, _9273++)
                    {
                        int _9277 = 0;
                        for (;;)
                        {
                            if (_9277 < 5)
                            {
                                int2 _7608 = _8942 + (_1085[_9273] * _1094[_9277].xx);
                                bool _7611 = any(bool2(_7608.x < int2(0, 0).x, _7608.y < int2(0, 0).y));
                                bool _7619;
                                if (!_7611)
                                {
                                    _7619 = any(bool2(_7608.x >= cbFI_MvDepthLaneSize.x, _7608.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7619 = _7611;
                                }
                                if (_7619)
                                {
                                    _10343 = _9274;
                                    break;
                                }
                                uint4 _7697 = r_warped_motion_qdata_tp1.Load(int3(_7608, 0));
                                uint _7698 = _7697.x;
                                if (_7698 != 0u)
                                {
                                    _10343 = min(_9274, _7698);
                                    break;
                                }
                                _9277++;
                                continue;
                            }
                            else
                            {
                                _10343 = _9274;
                                break;
                            }
                        }
                    }
                    float _9276;
                    if (_9274 == 4294967295u)
                    {
                        _9276 = -1.0f;
                    }
                    else
                    {
                        float _9275;
                        if (_9274 == 0u)
                        {
                            _9275 = -1.0f;
                        }
                        else
                        {
                            _9275 = float((_9274 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9276 = _9275;
                    }
                    _9289 = _9276;
                    break;
                } while(false);
                float4 _9317;
                if (_9289 >= 0.0f)
                {
                    float _7719 = (exp((_9289 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4512;
                    if (_4310)
                    {
                        uint _7726_dummy_parameter;
                        _4512 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7726_dummy_parameter))))), 0)).x) > _7719;
                    }
                    else
                    {
                        _4512 = _4310;
                    }
                    float4 _9307;
                    if (_4512)
                    {
                        float4 _8801 = _9294;
                        _8801.z = 0.0f;
                        _9307 = _8801;
                    }
                    else
                    {
                        _9307 = _9294;
                    }
                    bool _4524;
                    if (_4316)
                    {
                        uint _7746_dummy_parameter;
                        _4524 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7746_dummy_parameter))))), 0)).x) > _7719;
                    }
                    else
                    {
                        _4524 = _4316;
                    }
                    float4 _9318;
                    if (_4524)
                    {
                        float4 _8803 = _9307;
                        _8803.w = 0.0f;
                        _9318 = _8803;
                    }
                    else
                    {
                        _9318 = _9307;
                    }
                    _9317 = _9318;
                }
                else
                {
                    _9317 = _9294;
                }
                _9316 = _9317;
            }
            else
            {
                _9316 = _9294;
            }
            bool _4532 = _4298 != _4304;
            bool _4539;
            if (_4532)
            {
                _4539 = _4298 ? _4244 : _4247;
            }
            else
            {
                _4539 = _4532;
            }
            float4 _9399;
            if (_4539)
            {
                bool2 _4544 = _4298.xx;
                float2 _4545 = float2(_4544.x ? _8912.x : _8914.x, _4544.y ? _8912.y : _8914.y);
                float _9309;
                if (_4298)
                {
                    uint _7766_dummy_parameter;
                    _9309 = r_depth_tm1.Load(int3(int2(floor(_4545 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7766_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7782_dummy_parameter;
                    _9309 = r_depth_tp1.Load(int3(int2(floor(_4545 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7782_dummy_parameter))))), 0)).x;
                }
                float4x4 _9310;
                if (_4298)
                {
                    _9310 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9310 = cbFI_MotionTP1ToTM1;
                }
                float2 _9311;
                do
                {
                    float _7809 = _4545.x;
                    float _7812 = 1.0f - _4545.y;
                    float4 _7823 = mul(float4((float2(_7809, _7812) * 2.0f) - 1.0f.xx, _9309, 1.0f), _9310);
                    float _7825 = _7823.w;
                    if (!(_7825 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9311 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7838 = ((_7823.xy / _7825.xx) + 1.0f.xx) * 0.5f;
                    _9311 = float2(_7838.x - _7809, _7812 - _7838.y);
                    break;
                } while(false);
                float2 _4575 = float2(cbFI_DisplaySize);
                float4 _9400;
                if (!(length(((_4545 + _9311) - float2(_4544.x ? _8914.x : _8912.x, _4544.y ? _8914.y : _8912.y)) * _4575) <= ((0.100000001490116119384765625f * length(_9311 * _4575)) + 8.0f)))
                {
                    float4 _9401;
                    if (_4298)
                    {
                        float4 _8813 = _9316;
                        _8813.x = 0.0f;
                        _9401 = _8813;
                    }
                    else
                    {
                        float4 _8815 = _9316;
                        _8815.y = 0.0f;
                        _9401 = _8815;
                    }
                    _9400 = _9401;
                }
                else
                {
                    _9400 = _9316;
                }
                _9399 = _9400;
            }
            else
            {
                _9399 = _9316;
            }
            float4 _4600 = _9091 * _9399;
            float _4602 = dot(_4600, 1.0f.xxxx);
            float4 _9576;
            bool _9596;
            if (_4602 > 0.0f)
            {
                _9596 = _9061;
                _9576 = _4600 / _4602.xxxx;
            }
            else
            {
                bool _4613 = any(bool4(_9399.x < 1.0f.xxxx.x, _9399.y < 1.0f.xxxx.y, _9399.z < 1.0f.xxxx.z, _9399.w < 1.0f.xxxx.w));
                if (_4613)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7860;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7860);
                    }
                }
                bool4 _10372 = _4613.xxxx;
                _9596 = _4613 ? true : _9061;
                _9576 = float4(_10372.x ? 0.0f.xxxx.x : _9091.x, _10372.y ? 0.0f.xxxx.y : _9091.y, _10372.z ? 0.0f.xxxx.z : _9091.z, _10372.w ? 0.0f.xxxx.w : _9091.w);
            }
            _9595 = _9596;
            _9575 = _9576;
        }
        else
        {
            _9595 = _9061;
            _9575 = _9091;
        }
        uint _4622 = (cbFI_pad0 >> 24u) & 31u;
        uint _4626 = (cbFI_pad0 >> 16u) & 255u;
        bool _4628 = _4622 != 0u;
        bool _4630 = _4626 == 12u;
        bool _4633 = _4626 == 13u;
        float4 _9592;
        if ((_4628 || _4630) || _4633)
        {
            float _9402;
            do
            {
                bool _7944 = all(bool2(_8915.x > 0.0f.xx.x, _8915.y > 0.0f.xx.y));
                bool _7950;
                if (_7944)
                {
                    _7950 = all(bool2(_8915.x < 1.0f.xx.x, _8915.y < 1.0f.xx.y));
                }
                else
                {
                    _7950 = _7944;
                }
                bool _7881 = !_7950;
                bool _7888;
                if (!_7881)
                {
                    bool _7955 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
                    bool _7961;
                    if (_7955)
                    {
                        _7961 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7961 = _7955;
                    }
                    _7888 = !_7961;
                }
                else
                {
                    _7888 = _7881;
                }
                if (_7888)
                {
                    _9402 = 0.0f;
                    break;
                }
                uint _7968_dummy_parameter;
                uint _7984_dummy_parameter;
                float4 _7909 = mul(float4((float2(_8915.x, 1.0f - _8915.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8915 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7968_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7911 = _7909.w;
                if (abs(_7911) < 9.9999999747524270787835121154785e-07f)
                {
                    _9402 = 0.0f;
                    break;
                }
                float _7922 = abs(cbFI_DeviceToViewDepth.y / ((_7909.z / _7911) - cbFI_DeviceToViewDepth.x));
                float _7925 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7984_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9402 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7922 - _7925) / max(max(_7922, _7925), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8032 = all(bool2(_8916.x > 0.0f.xx.x, _8916.y > 0.0f.xx.y));
            bool _8038;
            if (_8032)
            {
                _8038 = all(bool2(_8916.x < 1.0f.xx.x, _8916.y < 1.0f.xx.y));
            }
            else
            {
                _8038 = _8032;
            }
            float _9403;
            if (_8038)
            {
                uint _8045_dummy_parameter;
                _9403 = length((_5403 + (r_motion_tp1.Load(int3(int2(floor(_8916 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8045_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9403 = 1000000.0f;
            }
            float _9414;
            if ((_4622 & 1u) != 0u)
            {
                _9414 = _9402;
            }
            else
            {
                _9414 = 1.0f;
            }
            float _9415;
            if ((_4622 & 2u) != 0u)
            {
                _9415 = _9414 * (1.0f - smoothstep(2.0f, 8.0f, _9403));
            }
            else
            {
                _9415 = _9414;
            }
            float _9416;
            if ((_4622 & 4u) != 0u)
            {
                _9416 = _9415 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6124 - _6132) - length(_6108 - _6116))));
            }
            else
            {
                _9416 = _9415;
            }
            float _9586;
            if ((_4622 & 8u) != 0u)
            {
                _9586 = lerp(1.0f, _9416, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6108 - _6116)));
            }
            else
            {
                _9586 = _9416;
            }
            bool _4708 = (_4622 & 16u) != 0u;
            bool _4717;
            if (_4708)
            {
                _4717 = length(_8910 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4717 = _4708;
            }
            float _10374 = _4717 ? 1.0f : _9586;
            bool _4723 = _4628 && _6317;
            bool _4728;
            if (_4723)
            {
                bool _8070 = all(bool2(_8912.x > 0.0f.xx.x, _8912.y > 0.0f.xx.y));
                bool _8076;
                if (_8070)
                {
                    _8076 = all(bool2(_8912.x < 1.0f.xx.x, _8912.y < 1.0f.xx.y));
                }
                else
                {
                    _8076 = _8070;
                }
                _4728 = _8076;
            }
            else
            {
                _4728 = _4723;
            }
            bool _4733;
            if (_4728)
            {
                bool _8081 = all(bool2(_8914.x > 0.0f.xx.x, _8914.y > 0.0f.xx.y));
                bool _8087;
                if (_8081)
                {
                    _8087 = all(bool2(_8914.x < 1.0f.xx.x, _8914.y < 1.0f.xx.y));
                }
                else
                {
                    _8087 = _8081;
                }
                _4733 = _8087;
            }
            else
            {
                _4733 = _4728;
            }
            float4 _9593;
            if (_4733)
            {
                float _4739 = _9575.x + _9575.y;
                float _4748 = (_9575.z + _9575.w) * (1.0f - _10374);
                float _9589;
                if (_4739 > 9.9999997473787516355514526367188e-06f)
                {
                    _9589 = _9575.x / _4739;
                }
                else
                {
                    _9589 = _3916;
                }
                _9593 = float4(_9575.x + (_4748 * _9589), _9575.y + (_4748 * (1.0f - _9589)), _9575.zw * _10374);
            }
            else
            {
                _9593 = _9575;
            }
            _9592 = _9593;
        }
        else
        {
            _9592 = _9575;
        }
        float3 _10147;
        if (_9595)
        {
            float3 _8093 = r_current_interpolation_source.Load(int3(_3335, 0)).xyz;
            float3 _10148;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6317)
            {
                uint _8100_dummy_parameter;
                float _9698;
                _9698 = r_depth_tm1.Load(int3(int2(floor(_8912 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8100_dummy_parameter))))), 0)).x;
                float _4860;
                for (int _9697 = 0; _9697 < 24; _9698 = _4860, _9697++)
                {
                    float _4832 = float(_9697 & 7) * 0.785398185253143310546875f;
                    int _4834 = _9697 >> 3;
                    int _10197;
                    if (_4834 == 0)
                    {
                        _10197 = 16;
                    }
                    else
                    {
                        _10197 = (_4834 == 1) ? 48 : 96;
                    }
                    uint _8120_dummy_parameter;
                    _4860 = max(_9698, r_depth_tm1.Load(int3(int2(floor(clamp(_8912 + ((cbFI_MvDepthLaneSizeRcp * float(_10197)) * float2(cos(_4832), sin(_4832))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8120_dummy_parameter))))), 0)).x);
                }
                float2 _9699;
                do
                {
                    float _8142 = 1.0f - _8912.y;
                    float4 _8153 = mul(float4((float2(_8912.x, _8142) * 2.0f) - 1.0f.xx, _9698, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8155 = _8153.w;
                    if (!(_8155 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9699 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8168 = ((_8153.xy / _8155.xx) + 1.0f.xx) * 0.5f;
                    _9699 = float2(_8168.x - _8912.x, _8142 - _8168.y);
                    break;
                } while(false);
                float2 _4871 = _8912 + _9699;
                bool _8186 = all(bool2(_4871.x > 0.0f.xx.x, _4871.y > 0.0f.xx.y));
                bool _8192;
                if (_8186)
                {
                    _8192 = all(bool2(_4871.x < 1.0f.xx.x, _4871.y < 1.0f.xx.y));
                }
                else
                {
                    _8192 = _8186;
                }
                float3 _10149;
                if (_8192)
                {
                    float _4877 = abs(cbFI_DeviceToViewDepth.y / (_9698 - cbFI_DeviceToViewDepth.x));
                    uint _8212_dummy_parameter;
                    int2 _8212 = int2(spvTextureSize(r_depth_m2, uint(0), _8212_dummy_parameter));
                    float _4881 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4871 * float2(_8212))), int2(0, 0), _8212 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10154;
                    if (abs(_4881 - _4877) <= (0.20000000298023223876953125f * max(_4881, _4877)))
                    {
                        uint _8246_dummy_parameter;
                        int2 _8246 = int2(spvTextureSize(r_colour_m2, uint(0), _8246_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8269;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8269);
                        }
                        _10154 = r_colour_m2.Load(int3(clamp(int2(floor(_4871 * float2(_8246))), int2(0, 0), _8246 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8279;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8279);
                        }
                        _10154 = _8093;
                    }
                    _10149 = _10154;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8289;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8289);
                    }
                    _10149 = _8093;
                }
                _10148 = _10149;
            }
            else
            {
                _10148 = _8093;
            }
            _10147 = _10148;
        }
        else
        {
            _10147 = (((_6108 * _9592.x) + (_6116 * _9592.y)) + (_6124 * _9592.z)) + (_6132 * _9592.w);
        }
        uint _4909 = cbFI_pad0 & 255u;
        bool _10042;
        float3 _10146;
        if (_4909 != 0u)
        {
            float3 _4914 = r_present_backbuffer.Load(int3(_3335, 0)).xyz;
            float3 _4918 = r_current_interpolation_source.Load(int3(_3335, 0)).xyz;
            float3 _4922 = abs(_4914 - _4918);
            float3 _9702;
            if (_4909 == 2u)
            {
                _9702 = (abs(_4918) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9702 = 0.000244140625f.xxx;
            }
            bool _4938 = any(bool3(_4922.x > _9702.x, _4922.y > _9702.y, _4922.z > _9702.z));
            bool3 _10375 = _4938.xxx;
            _10146 = float3(_10375.x ? _4914.x : _10147.x, _10375.y ? _4914.y : _10147.y, _10375.z ? _4914.z : _10147.z);
            _10042 = _4938;
        }
        else
        {
            _10146 = _10147;
            _10042 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8304;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8304);
        }
        float3 _10130;
        if (_4626 == 1u)
        {
            _10130 = lerp(_6108, _6116, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10131;
            if (_4626 == 2u)
            {
                _10131 = lerp(_6124, _6132, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10132;
                if (_4626 == 3u)
                {
                    _10132 = float(_10042).xxx;
                }
                else
                {
                    float3 _10133;
                    if (_4626 == 4u)
                    {
                        _10133 = float3(((_8910 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10134;
                        if (_4626 == 5u)
                        {
                            _10134 = float3(((_5403 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10135;
                            if (_4626 == 6u)
                            {
                                _10135 = float3(_9592.xy, _9592.z + _9592.w);
                            }
                            else
                            {
                                float3 _10136;
                                if (_4626 == 7u)
                                {
                                    _10136 = r_current_interpolation_source.Load(int3(_3335, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10137;
                                    if (_4626 == 8u)
                                    {
                                        _10137 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3691, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10138;
                                        if (_4630)
                                        {
                                            uint _8326_dummy_parameter;
                                            uint _8358_dummy_parameter;
                                            _10138 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3691 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8326_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3691 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8358_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10139;
                                            if (_4633)
                                            {
                                                _10139 = _6124;
                                            }
                                            else
                                            {
                                                float3 _10140;
                                                if (_4626 == 20u)
                                                {
                                                    _10140 = _6108;
                                                }
                                                else
                                                {
                                                    float3 _10141;
                                                    if (_4626 == 21u)
                                                    {
                                                        _10141 = _6116;
                                                    }
                                                    else
                                                    {
                                                        float3 _10142;
                                                        if (_4626 == 22u)
                                                        {
                                                            _10142 = _6132;
                                                        }
                                                        else
                                                        {
                                                            float3 _10143;
                                                            if (_4626 == 18u)
                                                            {
                                                                _10143 = _9851;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10377 = (_4626 == 19u).xxx;
                                                                _10143 = float3(_10377.x ? _9708.x : _10146.x, _10377.y ? _9708.y : _10146.y, _10377.z ? _9708.z : _10146.z);
                                                            }
                                                            _10142 = _10143;
                                                        }
                                                        _10141 = _10142;
                                                    }
                                                    _10140 = _10141;
                                                }
                                                _10139 = _10140;
                                            }
                                            _10138 = _10139;
                                        }
                                        _10137 = _10138;
                                    }
                                    _10136 = _10137;
                                }
                                _10135 = _10136;
                            }
                            _10134 = _10135;
                        }
                        _10133 = _10134;
                    }
                    _10132 = _10133;
                }
                _10131 = _10132;
            }
            _10130 = _10131;
        }
        float3 _10129;
        if ((_4626 >= 9u) && (_4626 <= 11u))
        {
            uint _5096 = 64u + uint((_8942.y * cbFI_MvDepthLaneSize.x) + _8942.x);
            uint _5100 = rw_nfru_diagnostics.Load<uint>(_5096 * 4 + 0) & 15u;
            float3 _10159;
            if (_4626 == 10u)
            {
                float3 _10128;
                if ((rw_nfru_diagnostics.Load<uint>(_5096 * 4 + 0) & 32u) != 0u)
                {
                    _10128 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10127;
                    if ((rw_nfru_diagnostics.Load<uint>(_5096 * 4 + 0) & 16u) != 0u)
                    {
                        _10127 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5121 = ((rw_nfru_diagnostics.Load<uint>(_5096 * 4 + 0) & 64u) != 0u).xxx;
                        _10127 = float3(_5121.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5121.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5121.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10128 = _10127;
                }
                _10159 = _10128;
            }
            else
            {
                float3 _10160;
                if (_4626 == 11u)
                {
                    uint _5134 = (rw_nfru_diagnostics.Load<uint>(_5096 * 4 + 0) >> 8u) & 15u;
                    uint _5137 = (rw_nfru_diagnostics.Load<uint>(_5096 * 4 + 0) >> 12u) & 15u;
                    float3 _10120;
                    if ((_5100 == 2u) || (_5100 == 3u))
                    {
                        _10120 = _3048[_5100];
                    }
                    else
                    {
                        bool _5149 = _5134 == 3u;
                        bool _5151 = _5137 == 3u;
                        float3 _10121;
                        if (_5149 && _5151)
                        {
                            _10121 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10122;
                            if (_5149)
                            {
                                _10122 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10123;
                                if (_5151)
                                {
                                    _10123 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10124;
                                    if ((_5134 == 4u) || (_5137 == 4u))
                                    {
                                        _10124 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10125;
                                        if ((_5134 == 1u) || (_5137 == 1u))
                                        {
                                            _10125 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10379 = (_5100 == 1u).xxx;
                                            _10125 = float3(_10379.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10379.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10379.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10124 = _10125;
                                    }
                                    _10123 = _10124;
                                }
                                _10122 = _10123;
                            }
                            _10121 = _10122;
                        }
                        _10120 = _10121;
                    }
                    _10160 = _10120;
                }
                else
                {
                    _10160 = _3048[min(_5100, 7u)];
                }
                _10159 = _10160;
            }
            _10129 = _10159;
        }
        else
        {
            _10129 = _10130;
        }
        float4 _10163;
        if ((_4626 >= 14u) && (_4626 <= 16u))
        {
            float2 _10161;
            if (_4626 == 14u)
            {
                uint _5207_dummy_parameter;
                uint _5213_dummy_parameter;
                _10161 = r_flow_tm1.Load(int3(clamp(int2(floor(_3691 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5207_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5213_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10162;
                if (_4626 == 16u)
                {
                    uint _8409 = r_warped_flow_qdata_tm1.Load(int3(_3707, 0)).x & 2147483647u;
                    uint _8441 = uint(max((int((_8409 >> 16u) & 15u) - 6), 0));
                    _10162 = ((float2(float((1 - (2 * int((_8409 >> 15u) & 1u))) * int(((_8409 >> uint(7)) & 127u) << _8441)), float((1 - (2 * int((_8409 >> 14u) & 1u))) * int((_8409 & 127u) << _8441))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10162 = _5403 * float2(cbFI_DisplaySize);
                }
                _10161 = _10162;
            }
            uint2 _5246 = uint2(clamp(round(_10161 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5248 = _5246.x;
            uint _5255 = _5246.y;
            _10163 = float4(float(_5248 & 255u), float((_5248 >> 8u) | ((_5255 & 15u) << 4u)), float(_5255 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10164;
            if (_4626 == 17u)
            {
                _10164 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3707, 0)).x != 0u), _4050, 0.0f, 1.0f);
            }
            else
            {
                _10164 = float4(_10129, 1.0f);
            }
            _10163 = _10164;
        }
        rw_output[_3335] = _10163.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5299 = ((uint(_3335.y) * uint(cbFI_DisplaySize.x)) + uint(_3335.x)) * 6u;
            uint _8487 = spvPackHalf2x16(clamp(_6107.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5299 * 4 + 0, (((_8487 & 32767u) >> 4u) | ((((_8487 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6107.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8522 = spvPackHalf2x16(clamp(_6115.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5299 + 1u) * 4 + 0, (((_8522 & 32767u) >> 4u) | ((((_8522 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6115.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8557 = spvPackHalf2x16(clamp(_6123.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5299 + 2u) * 4 + 0, (((_8557 & 32767u) >> 4u) | ((((_8557 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6123.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8592 = spvPackHalf2x16(clamp(_6131.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5299 + 3u) * 4 + 0, (((_8592 & 32767u) >> 4u) | ((((_8592 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6131.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8619 = r_current_interpolation_source.Load(int3(_3335, 0));
            uint _8633 = spvPackHalf2x16(clamp(_8619.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5299 + 4u) * 4 + 0, (((_8633 & 32767u) >> 4u) | ((((_8633 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8619.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10196;
            if (_10042 || (_4626 != 0u))
            {
                _10196 = 4294967295u;
            }
            else
            {
                uint _8668 = spvPackHalf2x16(clamp(_10163.xy, 0.0f.xx, 65000.0f.xx));
                _10196 = (((_8668 & 32767u) >> 4u) | ((((_8668 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10163.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5299 + 5u) * 4 + 0, _10196);
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
