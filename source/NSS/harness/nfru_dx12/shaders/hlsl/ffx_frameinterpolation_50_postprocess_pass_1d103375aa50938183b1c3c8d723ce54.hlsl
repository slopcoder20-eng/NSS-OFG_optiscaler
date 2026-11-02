static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3047[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3334 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3334.x >= cbFI_DisplaySize.x, _3334.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3334] = float4(r_present_backbuffer.Load(int3(_3334, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3690 = (float2(_3334) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3701 = int2(floor(_3690 * float2(cbFI_MvDepthLaneSize)));
        int2 _3706 = int2(floor(_3690 * float2(cbFI_FlowLaneSize)));
        float4 _5396 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3690 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5402 = r_warped_filled_flow_tm1.Load(int3(_3706, 0)).xy;
        float2 _5408 = r_warped_filled_motion_tp1.Load(int3(_3701, 0)).xy;
        bool _5430 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8884;
        if (_5430)
        {
            float _5443 = ((2.0f * _3690.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8884 = float2(atan(_5443) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3690.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5443 * _5443))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8884 = _3690;
        }
        bool _3727 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8905;
        bool _8926;
        int2 _8937;
        float3 _9846;
        if (_3727)
        {
            float _8886;
            float _8888;
            _8888 = 2.0f;
            _8886 = -1.0f;
            uint _3396[9];
            float _10233;
            float _10236;
            for (int _8885 = 0; _8885 < 9; _8888 = _10236, _8886 = _10233, _8885++)
            {
                _3396[_8885] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3701 + int2((_8885 % 3) - 1, (_8885 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3396[_8885] != 0u)
                {
                    float _10228;
                    if (_3396[_8885] == 0u)
                    {
                        _10228 = -1.0f;
                    }
                    else
                    {
                        _10228 = float((_3396[_8885] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10236 = min(_8888, _10228);
                    _10233 = max(_8886, _10228);
                }
                else
                {
                    _10236 = _8888;
                    _10233 = _8886;
                }
            }
            float _3773 = float(_8886 >= 0.0f);
            float3 _8695 = 0.0f.xxx;
            _8695.y = _3773;
            float2 _8906;
            bool _8927;
            int2 _8938;
            float3 _9847;
            if ((_8886 - _8888) > 0.0199999995529651641845703125f)
            {
                float _8894;
                int2 _8895;
                float2 _8896;
                int2 _8898;
                float2 _8904;
                _8904 = _5408;
                _8898 = _3701;
                _8896 = _5408;
                _8895 = _3701;
                _8894 = -1.0f;
                float _10241;
                int2 _10245;
                float2 _10256;
                int2 _10267;
                float2 _10300;
                float _10345;
                int _8893 = 0;
                float _10209 = 1000000000.0f;
                for (; _8893 < 9; _10209 = _10345, _8904 = _10300, _8898 = _10267, _8896 = _10256, _8895 = _10245, _8894 = _10241, _8893++)
                {
                    if (_3396[_8893] == 0u)
                    {
                        _10345 = _10209;
                        _10300 = _8904;
                        _10267 = _8898;
                        _10256 = _8896;
                        _10245 = _8895;
                        _10241 = _8894;
                        continue;
                    }
                    int2 _3808 = clamp(_3701 + int2((_8893 % 3) - 1, (_8893 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5518 = _3396[_8893] & 2147483647u;
                    uint _5550 = uint(max((int((_5518 >> 16u) & 15u) - 6), 0));
                    float2 _3814 = (float2(float((1 - (2 * int((_5518 >> 15u) & 1u))) * int(((_5518 >> uint(7)) & 127u) << _5550)), float((1 - (2 * int((_5518 >> 14u) & 1u))) * int((_5518 & 127u) << _5550))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10195;
                    if (_3396[_8893] == 0u)
                    {
                        _10195 = -1.0f;
                    }
                    else
                    {
                        _10195 = float((_3396[_8893] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3819 = _10195 - 0.100000001490116119384765625f;
                    float2 _10196;
                    if (_5430)
                    {
                        float2 _5627 = clamp((((_8884 + (_3814 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5630 = tan(_5627.x);
                        _10196 = (float2(_5630 / cbFI_DeviceToViewDepth.z, (tan(_5627.y) * sqrt(1.0f + (_5630 * _5630))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10196 = _8884 + (_3814 * cbFI_Timestep);
                    }
                    float _3826 = cbFI_Timestep - 1.0f;
                    float2 _10197;
                    if (_5430)
                    {
                        float2 _5698 = clamp((((_8884 + (_3814 * _3826)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5701 = tan(_5698.x);
                        _10197 = (float2(_5701 / cbFI_DeviceToViewDepth.z, (tan(_5698.y) * sqrt(1.0f + (_5701 * _5701))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10197 = _8884 + (_3814 * _3826);
                    }
                    bool _5734 = all(bool2(_10196.x > 0.0f.xx.x, _10196.y > 0.0f.xx.y));
                    bool _5740;
                    if (_5734)
                    {
                        _5740 = all(bool2(_10196.x < 1.0f.xx.x, _10196.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5740 = _5734;
                    }
                    float _10200;
                    if (_5740)
                    {
                        uint _5747_dummy_parameter;
                        _10200 = max((_3819 - (log((r_depth_tm1.Load(int3(int2(floor(_10196 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5747_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10200 = 0.0f;
                    }
                    bool _5777 = all(bool2(_10197.x > 0.0f.xx.x, _10197.y > 0.0f.xx.y));
                    bool _5783;
                    if (_5777)
                    {
                        _5783 = all(bool2(_10197.x < 1.0f.xx.x, _10197.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5783 = _5777;
                    }
                    float _10201;
                    if (_5783)
                    {
                        uint _5790_dummy_parameter;
                        _10201 = _10200 + max((_3819 - (log((r_depth_tp1.Load(int3(int2(floor(_10197 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5790_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10201 = _10200;
                    }
                    float _10242;
                    int2 _10246;
                    float2 _10257;
                    int2 _10268;
                    float2 _10301;
                    float _10346;
                    if (_10201 == 0.0f)
                    {
                        bool _3861 = _3819 > _8894;
                        bool2 _10354 = _3861.xx;
                        _10346 = _10209;
                        _10301 = float2(_10354.x ? _3814.x : _8904.x, _10354.y ? _3814.y : _8904.y);
                        _10268 = int2(_10354.x ? _3808.x : _8898.x, _10354.y ? _3808.y : _8898.y);
                        _10257 = _8896;
                        _10246 = _8895;
                        _10242 = _3861 ? _3819 : _8894;
                    }
                    else
                    {
                        bool _3870 = _10201 < _10209;
                        bool2 _10350 = _3870.xx;
                        _10346 = _3870 ? _10201 : _10209;
                        _10301 = _8904;
                        _10268 = _8898;
                        _10257 = float2(_10350.x ? _3814.x : _8896.x, _10350.y ? _3814.y : _8896.y);
                        _10246 = int2(_10350.x ? _3808.x : _8895.x, _10350.y ? _3808.y : _8895.y);
                        _10242 = _8894;
                    }
                    _10345 = _10346;
                    _10300 = _10301;
                    _10267 = _10268;
                    _10256 = _10257;
                    _10245 = _10246;
                    _10241 = _10242;
                }
                bool _3882 = _8894 < 0.0f;
                bool2 _10360 = _3882.xx;
                int2 _10363 = int2(_10360.x ? _8895.x : _8898.x, _10360.y ? _8895.y : _8898.y);
                _9847 = float3(1.0f, _3773, float(any(bool2(_10363.x != _3701.x, _10363.y != _3701.y))));
                _8938 = _10363;
                _8927 = _3882 ? false : true;
                _8906 = float2(_10360.x ? _8896.x : _8904.x, _10360.y ? _8896.y : _8904.y);
            }
            else
            {
                _9847 = _8695;
                _8938 = _3701;
                _8927 = false;
                _8906 = _5408;
            }
            _9846 = _9847;
            _8937 = _8938;
            _8926 = _8927;
            _8905 = _8906;
        }
        else
        {
            _9846 = 0.0f.xxx;
            _8937 = _3701;
            _8926 = false;
            _8905 = _5408;
        }
        float2 _8907;
        if (_5430)
        {
            float2 _5855 = clamp((((_8884 + (_8905 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5858 = tan(_5855.x);
            _8907 = (float2(_5858 / cbFI_DeviceToViewDepth.z, (tan(_5855.y) * sqrt(1.0f + (_5858 * _5858))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8907 = _8884 + (_8905 * cbFI_Timestep);
        }
        float _3905 = cbFI_Timestep - 1.0f;
        float2 _8909;
        if (_5430)
        {
            float2 _5926 = clamp((((_8884 + (_8905 * _3905)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5929 = tan(_5926.x);
            _8909 = (float2(_5929 / cbFI_DeviceToViewDepth.z, (tan(_5926.y) * sqrt(1.0f + (_5929 * _5929))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8909 = _8884 + (_8905 * _3905);
        }
        float _3910 = -cbFI_Timestep;
        float2 _8910;
        if (_5430)
        {
            float2 _5997 = clamp((((_8884 + (_5402 * _3910)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6000 = tan(_5997.x);
            _8910 = (float2(_6000 / cbFI_DeviceToViewDepth.z, (tan(_5997.y) * sqrt(1.0f + (_6000 * _6000))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8910 = _8884 + (_5402 * _3910);
        }
        float _3915 = 1.0f - cbFI_Timestep;
        float2 _8911;
        if (_5430)
        {
            float2 _6068 = clamp((((_8884 + (_5402 * _3915)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6071 = tan(_6068.x);
            _8911 = (float2(_6071 / cbFI_DeviceToViewDepth.z, (tan(_6068.y) * sqrt(1.0f + (_6071 * _6071))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8911 = _8884 + (_5402 * _3915);
        }
        float4 _6106 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8907, 0.0f);
        float3 _6107 = _6106.xyz;
        float4 _6114 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8909, 0.0f);
        float3 _6115 = _6114.xyz;
        float4 _6122 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8910, 0.0f);
        float3 _6123 = _6122.xyz;
        float4 _6130 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8911, 0.0f);
        float3 _6131 = _6130.xyz;
        float4 _6145 = exp(_5396 - max(max(max(_5396.x, _5396.y), _5396.z), _5396.w).xxxx);
        float4 _6152 = _6145 / (dot(_6145, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3934 = _3727 && (!_8926);
        bool _3943;
        if (_3934)
        {
            _3943 = (_6152.z + _6152.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3943 = _3934;
        }
        bool _3954;
        if (_3943)
        {
            _3954 = length((_8910 - _8907) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3954 = _3943;
        }
        bool _8950;
        if (_3954)
        {
            uint4 _6171 = r_warped_motion_qdata_tp1.Load(int3(_8937, 0));
            uint _6172 = _6171.x;
            bool _8953;
            if (_6172 != 0u)
            {
                float _8939;
                if (_6172 == 0u)
                {
                    _8939 = -1.0f;
                }
                else
                {
                    _8939 = float((_6172 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3964 = _8939 - 0.12000000476837158203125f;
                bool _6191 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
                bool _6197;
                if (_6191)
                {
                    _6197 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
                }
                else
                {
                    _6197 = _6191;
                }
                bool _3974;
                if (_6197)
                {
                    uint _6204_dummy_parameter;
                    _3974 = (log((r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6204_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3964;
                }
                else
                {
                    _3974 = _6197;
                }
                bool _3988;
                if (!_3974)
                {
                    bool _6234 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
                    bool _6240;
                    if (_6234)
                    {
                        _6240 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6240 = _6234;
                    }
                    bool _3986;
                    if (_6240)
                    {
                        uint _6247_dummy_parameter;
                        _3986 = (log((r_depth_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6247_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3964;
                    }
                    else
                    {
                        _3986 = _6240;
                    }
                    _3988 = _3986;
                }
                else
                {
                    _3988 = _3974;
                }
                _8953 = _3988;
            }
            else
            {
                _8953 = false;
            }
            _8950 = _8953;
        }
        else
        {
            _8950 = false;
        }
        bool _3993 = _8926 || _8950;
        bool _3998;
        if (_3993)
        {
            bool _6277 = all(bool2(_8907.x > 0.0f.xx.x, _8907.y > 0.0f.xx.y));
            bool _6283;
            if (_6277)
            {
                _6283 = all(bool2(_8907.x < 1.0f.xx.x, _8907.y < 1.0f.xx.y));
            }
            else
            {
                _6283 = _6277;
            }
            _3998 = _6283;
        }
        else
        {
            _3998 = _3993;
        }
        bool _4003;
        if (_3998)
        {
            bool _6288 = all(bool2(_8909.x > 0.0f.xx.x, _8909.y > 0.0f.xx.y));
            bool _6294;
            if (_6288)
            {
                _6294 = all(bool2(_8909.x < 1.0f.xx.x, _8909.y < 1.0f.xx.y));
            }
            else
            {
                _6294 = _6288;
            }
            _4003 = _6294;
        }
        else
        {
            _4003 = _3998;
        }
        float4 _9044;
        if (_4003)
        {
            float _4006 = _6152.x;
            float _4008 = _6152.y;
            float _4009 = _4006 + _4008;
            float _4014 = _6152.z + _6152.w;
            float _8968;
            if (_4009 > 0.001000000047497451305389404296875f)
            {
                _8968 = _4006 / _4009;
            }
            else
            {
                _8968 = _3915;
            }
            _9044 = float4(_4006 + (_4014 * _8968), _4008 + (_4014 * (1.0f - _8968)), 0.0f, 0.0f);
        }
        else
        {
            _9044 = _6152;
        }
        bool _6322 = (cbFI_pad0 & 1024u) != 0u;
        bool _6298 = !_6322;
        bool _6299 = !_6298;
        bool _6316;
        if (_6299)
        {
            _6316 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8937.y * cbFI_MvDepthLaneSize.x) + _8937.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6316 = _6298;
        }
        bool _6348;
        if (_6299)
        {
            _6348 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3706.y * cbFI_FlowLaneSize.x) + _3706.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6348 = _6298;
        }
        float _4049 = float(_6348);
        bool _9056;
        float4 _9086;
        float3 _9703;
        if (_6322)
        {
            bool _4059;
            if (_6316)
            {
                _4059 = all(bool2(_8907.x > 0.0f.xx.x, _8907.y > 0.0f.xx.y));
            }
            else
            {
                _4059 = _6316;
            }
            bool _4065;
            if (_4059)
            {
                _4065 = all(bool2(_8907.x < 1.0f.xx.x, _8907.y < 1.0f.xx.y));
            }
            else
            {
                _4065 = _4059;
            }
            bool _4072;
            if (_6316)
            {
                _4072 = all(bool2(_8909.x > 0.0f.xx.x, _8909.y > 0.0f.xx.y));
            }
            else
            {
                _4072 = _6316;
            }
            bool _4078;
            if (_4072)
            {
                _4078 = all(bool2(_8909.x < 1.0f.xx.x, _8909.y < 1.0f.xx.y));
            }
            else
            {
                _4078 = _4072;
            }
            bool _4085;
            if (_6348)
            {
                _4085 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
            }
            else
            {
                _4085 = _6348;
            }
            bool _4091;
            if (_4085)
            {
                _4091 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
            }
            else
            {
                _4091 = _4085;
            }
            bool _4098;
            if (_6348)
            {
                _4098 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
            }
            else
            {
                _4098 = _6348;
            }
            bool _4104;
            if (_4098)
            {
                _4104 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
            }
            else
            {
                _4104 = _4098;
            }
            bool _4106 = !_6316;
            if (_4106)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6390;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6390);
                }
            }
            bool _4111 = !_6348;
            if (_4111)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6400;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6400);
                }
            }
            if (_6316 && _4111)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6410;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6410);
                }
            }
            if (_4106 && _6348)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6420;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6420);
                }
            }
            float _4130 = float(_4065);
            float _4132 = float(_4078);
            bool _4135 = _4091 && _4104;
            float _9002;
            if (_4135)
            {
                _9002 = 1.0f;
            }
            else
            {
                _9002 = (_4091 || _4104) ? 0.5f : 0.0f;
            }
            bool _9007;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4065)) && (!_4078))
            {
                bool _4165;
                if (_4135)
                {
                    float _9005;
                    do
                    {
                        bool _6504 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
                        bool _6510;
                        if (_6504)
                        {
                            _6510 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6510 = _6504;
                        }
                        bool _6441 = !_6510;
                        bool _6448;
                        if (!_6441)
                        {
                            bool _6515 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
                            bool _6521;
                            if (_6515)
                            {
                                _6521 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6521 = _6515;
                            }
                            _6448 = !_6521;
                        }
                        else
                        {
                            _6448 = _6441;
                        }
                        if (_6448)
                        {
                            _9005 = 0.0f;
                            break;
                        }
                        uint _6528_dummy_parameter;
                        uint _6544_dummy_parameter;
                        float4 _6469 = mul(float4((float2(_8910.x, 1.0f - _8910.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6528_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6471 = _6469.w;
                        if (abs(_6471) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9005 = 0.0f;
                            break;
                        }
                        float _6482 = abs(cbFI_DeviceToViewDepth.y / ((_6469.z / _6471) - cbFI_DeviceToViewDepth.x));
                        float _6485 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6544_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9005 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6482 - _6485) / max(max(_6482, _6485), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4165 = _9005 >= 0.5f;
                }
                else
                {
                    _4165 = _4135;
                }
                bool _9008;
                if (_4165)
                {
                    uint _6594_dummy_parameter;
                    float2 _9006;
                    do
                    {
                        float _6620 = 1.0f - _8910.y;
                        float4 _6631 = mul(float4((float2(_8910.x, _6620) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6594_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6633 = _6631.w;
                        if (!(_6633 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9006 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6646 = ((_6631.xy / _6633.xx) + 1.0f.xx) * 0.5f;
                        _9006 = float2(_6646.x - _8910.x, _6620 - _6646.y);
                        break;
                    } while(false);
                    float2 _4179 = float2(cbFI_DisplaySize);
                    _9008 = length(((_8910 + _9006) - _8911) * _4179) <= ((0.100000001490116119384765625f * length(_9006 * _4179)) + 8.0f);
                }
                else
                {
                    _9008 = _4165;
                }
                _9007 = _9008;
            }
            else
            {
                _9007 = true;
            }
            bool _4193 = !_9007;
            bool _10364 = _4193 ? false : _4104;
            bool _10365 = _4193 ? false : _4091;
            bool _9057;
            float4 _9087;
            if (!(((_4065 && _4078) && _10365) && _10364))
            {
                float4 _4215 = _9044 * float4(_4130, _4132, float(_10365), float(_10364));
                float _4217 = dot(_4215, 1.0f.xxxx);
                bool _4220 = !(_4217 > 0.0f);
                float4 _9088;
                if (!_4220)
                {
                    _9088 = _4215 / _4217.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6668;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6668);
                    }
                    _9088 = 0.0f.xxxx;
                }
                _9087 = _9088;
                _9057 = _4220;
            }
            else
            {
                _9087 = _9044;
                _9057 = false;
            }
            _9703 = float3(_4130, _4132, _9002);
            _9086 = _9087;
            _9056 = _9057;
        }
        else
        {
            _9703 = float3(float(_6316), _4049, 0.0f);
            _9086 = _9044;
            _9056 = false;
        }
        float4 _9570;
        bool _9590;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9056))
        {
            bool _4243 = _9086.x > 0.00999999977648258209228515625f;
            bool _4246 = _9086.y > 0.00999999977648258209228515625f;
            bool _4255 = (_9086.z + _9086.w) > 0.0199999995529651641845703125f;
            bool _4261;
            if (_4255)
            {
                bool _6674 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
                bool _6680;
                if (_6674)
                {
                    _6680 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
                }
                else
                {
                    _6680 = _6674;
                }
                _4261 = _6680;
            }
            else
            {
                _4261 = _4255;
            }
            bool _4266;
            if (_4261)
            {
                bool _6685 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
                bool _6691;
                if (_6685)
                {
                    _6691 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
                }
                else
                {
                    _6691 = _6685;
                }
                _4266 = _6691;
            }
            else
            {
                _4266 = _4261;
            }
            bool _4273;
            if (_4266)
            {
                float _9090;
                do
                {
                    bool _6774 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
                    bool _6780;
                    if (_6774)
                    {
                        _6780 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6780 = _6774;
                    }
                    bool _6711 = !_6780;
                    bool _6718;
                    if (!_6711)
                    {
                        bool _6785 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
                        bool _6791;
                        if (_6785)
                        {
                            _6791 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6791 = _6785;
                        }
                        _6718 = !_6791;
                    }
                    else
                    {
                        _6718 = _6711;
                    }
                    if (_6718)
                    {
                        _9090 = 0.0f;
                        break;
                    }
                    uint _6798_dummy_parameter;
                    uint _6814_dummy_parameter;
                    float4 _6739 = mul(float4((float2(_8910.x, 1.0f - _8910.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6798_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6741 = _6739.w;
                    if (abs(_6741) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9090 = 0.0f;
                        break;
                    }
                    float _6752 = abs(cbFI_DeviceToViewDepth.y / ((_6739.z / _6741) - cbFI_DeviceToViewDepth.x));
                    float _6755 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6814_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9090 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6752 - _6755) / max(max(_6752, _6755), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4273 = _9090 < 0.5f;
            }
            else
            {
                _4273 = _4266;
            }
            float4 _9105;
            if (_4273)
            {
                uint _6864_dummy_parameter;
                uint _6895_dummy_parameter;
                float4 _9106;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6864_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6895_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9106 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9106 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9105 = _9106;
            }
            else
            {
                _9105 = 1.0f.xxxx;
            }
            bool _4297;
            if (_6316)
            {
                bool _6924 = all(bool2(_8907.x > 0.0f.xx.x, _8907.y > 0.0f.xx.y));
                bool _6930;
                if (_6924)
                {
                    _6930 = all(bool2(_8907.x < 1.0f.xx.x, _8907.y < 1.0f.xx.y));
                }
                else
                {
                    _6930 = _6924;
                }
                _4297 = _6930;
            }
            else
            {
                _4297 = _6316;
            }
            bool _4303;
            if (_6316)
            {
                bool _6935 = all(bool2(_8909.x > 0.0f.xx.x, _8909.y > 0.0f.xx.y));
                bool _6941;
                if (_6935)
                {
                    _6941 = all(bool2(_8909.x < 1.0f.xx.x, _8909.y < 1.0f.xx.y));
                }
                else
                {
                    _6941 = _6935;
                }
                _4303 = _6941;
            }
            else
            {
                _4303 = _6316;
            }
            bool _4309;
            if (_6348)
            {
                bool _6946 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
                bool _6952;
                if (_6946)
                {
                    _6952 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
                }
                else
                {
                    _6952 = _6946;
                }
                _4309 = _6952;
            }
            else
            {
                _4309 = _6348;
            }
            bool _4315;
            if (_6348)
            {
                bool _6957 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
                bool _6963;
                if (_6957)
                {
                    _6963 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
                }
                else
                {
                    _6963 = _6957;
                }
                _4315 = _6963;
            }
            else
            {
                _4315 = _6348;
            }
            bool _4318 = _4309 != _4315;
            bool _4324;
            if (_4318)
            {
                _4324 = _4297 || _4303;
            }
            else
            {
                _4324 = _4318;
            }
            float4 _9185;
            if (_4324)
            {
                float4 _8780 = _9105;
                _8780.z = 0.0f;
                _8780.w = 0.0f;
                _9185 = _8780;
            }
            else
            {
                _9185 = _9105;
            }
            bool _4331 = _4297 && _4243;
            bool _4334 = _4303 && _4246;
            float4 _9289;
            if (_4331 || _4334)
            {
                float _9182;
                do
                {
                    uint4 _7102 = r_warped_motion_qdata_tp1.Load(int3(_8937, 0));
                    uint _7103 = _7102.x;
                    if (_7103 != 0u)
                    {
                        float _9181;
                        if (_7103 == 0u)
                        {
                            _9181 = -1.0f;
                        }
                        else
                        {
                            _9181 = float((_7103 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9182 = _9181;
                        break;
                    }
                    int _9164;
                    uint _9165;
                    _9165 = _7103;
                    _9164 = -1;
                    uint _9180;
                    for (; _9164 <= 1; _9165 = _9180, _9164++)
                    {
                        _9180 = _9165;
                        for (int _9178 = -1; _9178 <= 1; )
                        {
                            _9180 = max(_9180, r_warped_motion_qdata_tp1.Load(int3(clamp(_8937 + int2(_9178, _9164), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9178++;
                            continue;
                        }
                    }
                    if (_9165 != 0u)
                    {
                        float _9177;
                        if (_9165 == 0u)
                        {
                            _9177 = -1.0f;
                        }
                        else
                        {
                            _9177 = float((_9165 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9182 = _9177;
                        break;
                    }
                    uint _9167;
                    _9167 = 4294967295u;
                    uint _10337;
                    for (int _9166 = 0; _9166 < 8; _9167 = _10337, _9166++)
                    {
                        int _9170 = 0;
                        for (;;)
                        {
                            if (_9170 < 5)
                            {
                                int2 _7053 = _8937 + (_1085[_9166] * _1094[_9170].xx);
                                bool _7056 = any(bool2(_7053.x < int2(0, 0).x, _7053.y < int2(0, 0).y));
                                bool _7064;
                                if (!_7056)
                                {
                                    _7064 = any(bool2(_7053.x >= cbFI_MvDepthLaneSize.x, _7053.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7064 = _7056;
                                }
                                if (_7064)
                                {
                                    _10337 = _9167;
                                    break;
                                }
                                uint4 _7142 = r_warped_motion_qdata_tp1.Load(int3(_7053, 0));
                                uint _7143 = _7142.x;
                                if (_7143 != 0u)
                                {
                                    _10337 = min(_9167, _7143);
                                    break;
                                }
                                _9170++;
                                continue;
                            }
                            else
                            {
                                _10337 = _9167;
                                break;
                            }
                        }
                    }
                    float _9169;
                    if (_9167 == 4294967295u)
                    {
                        _9169 = -1.0f;
                    }
                    else
                    {
                        float _9168;
                        if (_9167 == 0u)
                        {
                            _9168 = -1.0f;
                        }
                        else
                        {
                            _9168 = float((_9167 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9169 = _9168;
                    }
                    _9182 = _9169;
                    break;
                } while(false);
                float4 _9218;
                if (((_9182 < 0.0f) && _4331) && _4334)
                {
                    uint _7164_dummy_parameter;
                    float _7188 = log((r_depth_tm1.Load(int3(int2(floor(_8907 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7164_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7196_dummy_parameter;
                    float _7220 = log((r_depth_tp1.Load(int3(int2(floor(_8909 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7196_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9219;
                    if (_7188 > (_7220 + 0.07999999821186065673828125f))
                    {
                        float4 _8784 = _9185;
                        _8784.x = 0.0f;
                        _9219 = _8784;
                    }
                    else
                    {
                        float4 _9220;
                        if (_7220 > (_7188 + 0.07999999821186065673828125f))
                        {
                            float4 _8786 = _9185;
                            _8786.y = 0.0f;
                            _9220 = _8786;
                        }
                        else
                        {
                            _9220 = _9185;
                        }
                        _9219 = _9220;
                    }
                    _9218 = _9219;
                }
                else
                {
                    _9218 = _9185;
                }
                float _4374 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4376 = _9182 >= 0.0f;
                float _9201;
                if (_4376)
                {
                    _9201 = _9182 - _4374;
                }
                else
                {
                    float _9197;
                    if (_4331)
                    {
                        float _9196;
                        _9196 = 2.0f;
                        float _7278;
                        for (int _9195 = 0; _9195 < 24; _9196 = _7278, _9195++)
                        {
                            float _7242 = float(_9195 & 7) * 0.785398185253143310546875f;
                            int _7244 = _9195 >> 3;
                            int _9198;
                            if (_7244 == 0)
                            {
                                _9198 = 16;
                            }
                            else
                            {
                                _9198 = (_7244 == 1) ? 48 : 96;
                            }
                            uint _7294_dummy_parameter;
                            _7278 = min(_9196, log((r_depth_tm1.Load(int3(int2(floor(clamp(_8907 + ((cbFI_MvDepthLaneSizeRcp * float(_9198)) * float2(cos(_7242), sin(_7242))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7294_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9197 = _9196;
                    }
                    else
                    {
                        _9197 = 0.0f;
                    }
                    _9201 = _9197;
                }
                float _9208;
                if (_4376)
                {
                    _9208 = _9182 - _4374;
                }
                else
                {
                    float _9204;
                    if (_4334)
                    {
                        float _9203;
                        _9203 = 2.0f;
                        float _7392;
                        for (int _9202 = 0; _9202 < 24; _9203 = _7392, _9202++)
                        {
                            float _7356 = float(_9202 & 7) * 0.785398185253143310546875f;
                            int _7358 = _9202 >> 3;
                            int _9205;
                            if (_7358 == 0)
                            {
                                _9205 = 16;
                            }
                            else
                            {
                                _9205 = (_7358 == 1) ? 48 : 96;
                            }
                            uint _7424_dummy_parameter;
                            _7392 = min(_9203, log((r_depth_tp1.Load(int3(int2(floor(clamp(_8909 + ((cbFI_MvDepthLaneSizeRcp * float(_9205)) * float2(cos(_7356), sin(_7356))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7424_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9204 = _9203;
                    }
                    else
                    {
                        _9204 = 0.0f;
                    }
                    _9208 = _9204;
                }
                float _9209;
                if (_4331)
                {
                    uint _7456_dummy_parameter;
                    _9209 = r_depth_tm1.Load(int3(int2(floor(_8907 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7456_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9209 = 0.0f;
                }
                float _9210;
                if (_4334)
                {
                    uint _7475_dummy_parameter;
                    _9210 = r_depth_tp1.Load(int3(int2(floor(_8909 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7475_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9210 = 0.0f;
                }
                bool _4431;
                if (_4331)
                {
                    _4431 = _9209 > ((exp((_9201 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4431 = _4331;
                }
                float4 _9226;
                if (_4431)
                {
                    float4 _8788 = _9218;
                    _8788.x = 0.0f;
                    _9226 = _8788;
                }
                else
                {
                    _9226 = _9218;
                }
                bool _4443;
                if (_4334)
                {
                    _4443 = _9210 > ((exp((_9208 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4443 = _4334;
                }
                float4 _9228;
                if (_4443)
                {
                    float4 _8790 = _9226;
                    _8790.y = 0.0f;
                    _9228 = _8790;
                }
                else
                {
                    _9228 = _9226;
                }
                float4 _9290;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4376)
                {
                    bool _4463;
                    if (_4331)
                    {
                        _4463 = _9209 < ((exp((_9201 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4463 = _4331;
                    }
                    float4 _9230;
                    if (_4463)
                    {
                        float4 _8792 = _9228;
                        _8792.x = 0.0f;
                        _9230 = _8792;
                    }
                    else
                    {
                        _9230 = _9228;
                    }
                    bool _4475;
                    if (_4334)
                    {
                        _4475 = _9210 < ((exp((_9208 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4475 = _4334;
                    }
                    float4 _9291;
                    if (_4475)
                    {
                        float4 _8794 = _9230;
                        _8794.y = 0.0f;
                        _9291 = _8794;
                    }
                    else
                    {
                        _9291 = _9230;
                    }
                    _9290 = _9291;
                }
                else
                {
                    _9290 = _9228;
                }
                _9289 = _9290;
            }
            else
            {
                _9289 = _9185;
            }
            bool _4486 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4255;
            bool _4492;
            if (_4486)
            {
                _4492 = _4309 || _4315;
            }
            else
            {
                _4492 = _4486;
            }
            float4 _9311;
            if (_4492)
            {
                float _9284;
                do
                {
                    uint4 _7654 = r_warped_motion_qdata_tp1.Load(int3(_8937, 0));
                    uint _7655 = _7654.x;
                    if (_7655 != 0u)
                    {
                        float _9283;
                        if (_7655 == 0u)
                        {
                            _9283 = -1.0f;
                        }
                        else
                        {
                            _9283 = float((_7655 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9284 = _9283;
                        break;
                    }
                    int _9266;
                    uint _9267;
                    _9267 = _7655;
                    _9266 = -1;
                    uint _9282;
                    for (; _9266 <= 1; _9267 = _9282, _9266++)
                    {
                        _9282 = _9267;
                        for (int _9280 = -1; _9280 <= 1; )
                        {
                            _9282 = max(_9282, r_warped_motion_qdata_tp1.Load(int3(clamp(_8937 + int2(_9280, _9266), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9280++;
                            continue;
                        }
                    }
                    if (_9267 != 0u)
                    {
                        float _9279;
                        if (_9267 == 0u)
                        {
                            _9279 = -1.0f;
                        }
                        else
                        {
                            _9279 = float((_9267 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9284 = _9279;
                        break;
                    }
                    uint _9269;
                    _9269 = 4294967295u;
                    uint _10338;
                    for (int _9268 = 0; _9268 < 8; _9269 = _10338, _9268++)
                    {
                        int _9272 = 0;
                        for (;;)
                        {
                            if (_9272 < 5)
                            {
                                int2 _7605 = _8937 + (_1085[_9268] * _1094[_9272].xx);
                                bool _7608 = any(bool2(_7605.x < int2(0, 0).x, _7605.y < int2(0, 0).y));
                                bool _7616;
                                if (!_7608)
                                {
                                    _7616 = any(bool2(_7605.x >= cbFI_MvDepthLaneSize.x, _7605.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7616 = _7608;
                                }
                                if (_7616)
                                {
                                    _10338 = _9269;
                                    break;
                                }
                                uint4 _7694 = r_warped_motion_qdata_tp1.Load(int3(_7605, 0));
                                uint _7695 = _7694.x;
                                if (_7695 != 0u)
                                {
                                    _10338 = min(_9269, _7695);
                                    break;
                                }
                                _9272++;
                                continue;
                            }
                            else
                            {
                                _10338 = _9269;
                                break;
                            }
                        }
                    }
                    float _9271;
                    if (_9269 == 4294967295u)
                    {
                        _9271 = -1.0f;
                    }
                    else
                    {
                        float _9270;
                        if (_9269 == 0u)
                        {
                            _9270 = -1.0f;
                        }
                        else
                        {
                            _9270 = float((_9269 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9271 = _9270;
                    }
                    _9284 = _9271;
                    break;
                } while(false);
                float4 _9312;
                if (_9284 >= 0.0f)
                {
                    float _7716 = (exp((_9284 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4511;
                    if (_4309)
                    {
                        uint _7723_dummy_parameter;
                        _4511 = r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7723_dummy_parameter))))), 0)).x > _7716;
                    }
                    else
                    {
                        _4511 = _4309;
                    }
                    float4 _9302;
                    if (_4511)
                    {
                        float4 _8796 = _9289;
                        _8796.z = 0.0f;
                        _9302 = _8796;
                    }
                    else
                    {
                        _9302 = _9289;
                    }
                    bool _4523;
                    if (_4315)
                    {
                        uint _7742_dummy_parameter;
                        _4523 = r_depth_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7742_dummy_parameter))))), 0)).x > _7716;
                    }
                    else
                    {
                        _4523 = _4315;
                    }
                    float4 _9313;
                    if (_4523)
                    {
                        float4 _8798 = _9302;
                        _8798.w = 0.0f;
                        _9313 = _8798;
                    }
                    else
                    {
                        _9313 = _9302;
                    }
                    _9312 = _9313;
                }
                else
                {
                    _9312 = _9289;
                }
                _9311 = _9312;
            }
            else
            {
                _9311 = _9289;
            }
            bool _4531 = _4297 != _4303;
            bool _4538;
            if (_4531)
            {
                _4538 = _4297 ? _4243 : _4246;
            }
            else
            {
                _4538 = _4531;
            }
            float4 _9394;
            if (_4538)
            {
                bool2 _4543 = _4297.xx;
                float2 _4544 = float2(_4543.x ? _8907.x : _8909.x, _4543.y ? _8907.y : _8909.y);
                float _9304;
                if (_4297)
                {
                    uint _7761_dummy_parameter;
                    _9304 = r_depth_tm1.Load(int3(int2(floor(_4544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7761_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7777_dummy_parameter;
                    _9304 = r_depth_tp1.Load(int3(int2(floor(_4544 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7777_dummy_parameter))))), 0)).x;
                }
                float4x4 _9305;
                if (_4297)
                {
                    _9305 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9305 = cbFI_MotionTP1ToTM1;
                }
                float2 _9306;
                do
                {
                    float _7804 = _4544.x;
                    float _7807 = 1.0f - _4544.y;
                    float4 _7818 = mul(float4((float2(_7804, _7807) * 2.0f) - 1.0f.xx, _9304, 1.0f), _9305);
                    float _7820 = _7818.w;
                    if (!(_7820 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9306 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7833 = ((_7818.xy / _7820.xx) + 1.0f.xx) * 0.5f;
                    _9306 = float2(_7833.x - _7804, _7807 - _7833.y);
                    break;
                } while(false);
                float2 _4574 = float2(cbFI_DisplaySize);
                float4 _9395;
                if (!(length(((_4544 + _9306) - float2(_4543.x ? _8909.x : _8907.x, _4543.y ? _8909.y : _8907.y)) * _4574) <= ((0.100000001490116119384765625f * length(_9306 * _4574)) + 8.0f)))
                {
                    float4 _9396;
                    if (_4297)
                    {
                        float4 _8808 = _9311;
                        _8808.x = 0.0f;
                        _9396 = _8808;
                    }
                    else
                    {
                        float4 _8810 = _9311;
                        _8810.y = 0.0f;
                        _9396 = _8810;
                    }
                    _9395 = _9396;
                }
                else
                {
                    _9395 = _9311;
                }
                _9394 = _9395;
            }
            else
            {
                _9394 = _9311;
            }
            float4 _4599 = _9086 * _9394;
            float _4601 = dot(_4599, 1.0f.xxxx);
            float4 _9571;
            bool _9591;
            if (_4601 > 0.0f)
            {
                _9591 = _9056;
                _9571 = _4599 / _4601.xxxx;
            }
            else
            {
                bool _4612 = any(bool4(_9394.x < 1.0f.xxxx.x, _9394.y < 1.0f.xxxx.y, _9394.z < 1.0f.xxxx.z, _9394.w < 1.0f.xxxx.w));
                if (_4612)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7855;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7855);
                    }
                }
                bool4 _10367 = _4612.xxxx;
                _9591 = _4612 ? true : _9056;
                _9571 = float4(_10367.x ? 0.0f.xxxx.x : _9086.x, _10367.y ? 0.0f.xxxx.y : _9086.y, _10367.z ? 0.0f.xxxx.z : _9086.z, _10367.w ? 0.0f.xxxx.w : _9086.w);
            }
            _9590 = _9591;
            _9570 = _9571;
        }
        else
        {
            _9590 = _9056;
            _9570 = _9086;
        }
        uint _4621 = (cbFI_pad0 >> 24u) & 31u;
        uint _4625 = (cbFI_pad0 >> 16u) & 255u;
        bool _4627 = _4621 != 0u;
        bool _4629 = _4625 == 12u;
        bool _4632 = _4625 == 13u;
        float4 _9587;
        if ((_4627 || _4629) || _4632)
        {
            float _9397;
            do
            {
                bool _7939 = all(bool2(_8910.x > 0.0f.xx.x, _8910.y > 0.0f.xx.y));
                bool _7945;
                if (_7939)
                {
                    _7945 = all(bool2(_8910.x < 1.0f.xx.x, _8910.y < 1.0f.xx.y));
                }
                else
                {
                    _7945 = _7939;
                }
                bool _7876 = !_7945;
                bool _7883;
                if (!_7876)
                {
                    bool _7950 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
                    bool _7956;
                    if (_7950)
                    {
                        _7956 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7956 = _7950;
                    }
                    _7883 = !_7956;
                }
                else
                {
                    _7883 = _7876;
                }
                if (_7883)
                {
                    _9397 = 0.0f;
                    break;
                }
                uint _7963_dummy_parameter;
                uint _7979_dummy_parameter;
                float4 _7904 = mul(float4((float2(_8910.x, 1.0f - _8910.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8910 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7963_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7906 = _7904.w;
                if (abs(_7906) < 9.9999999747524270787835121154785e-07f)
                {
                    _9397 = 0.0f;
                    break;
                }
                float _7917 = abs(cbFI_DeviceToViewDepth.y / ((_7904.z / _7906) - cbFI_DeviceToViewDepth.x));
                float _7920 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7979_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9397 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7917 - _7920) / max(max(_7917, _7920), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8027 = all(bool2(_8911.x > 0.0f.xx.x, _8911.y > 0.0f.xx.y));
            bool _8033;
            if (_8027)
            {
                _8033 = all(bool2(_8911.x < 1.0f.xx.x, _8911.y < 1.0f.xx.y));
            }
            else
            {
                _8033 = _8027;
            }
            float _9398;
            if (_8033)
            {
                uint _8040_dummy_parameter;
                _9398 = length((_5402 + (r_motion_tp1.Load(int3(int2(floor(_8911 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8040_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9398 = 1000000.0f;
            }
            float _9409;
            if ((_4621 & 1u) != 0u)
            {
                _9409 = _9397;
            }
            else
            {
                _9409 = 1.0f;
            }
            float _9410;
            if ((_4621 & 2u) != 0u)
            {
                _9410 = _9409 * (1.0f - smoothstep(2.0f, 8.0f, _9398));
            }
            else
            {
                _9410 = _9409;
            }
            float _9411;
            if ((_4621 & 4u) != 0u)
            {
                _9411 = _9410 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6123 - _6131) - length(_6107 - _6115))));
            }
            else
            {
                _9411 = _9410;
            }
            float _9581;
            if ((_4621 & 8u) != 0u)
            {
                _9581 = lerp(1.0f, _9411, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6107 - _6115)));
            }
            else
            {
                _9581 = _9411;
            }
            bool _4707 = (_4621 & 16u) != 0u;
            bool _4716;
            if (_4707)
            {
                _4716 = length(_8905 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4716 = _4707;
            }
            float _10369 = _4716 ? 1.0f : _9581;
            bool _4722 = _4627 && _6316;
            bool _4727;
            if (_4722)
            {
                bool _8065 = all(bool2(_8907.x > 0.0f.xx.x, _8907.y > 0.0f.xx.y));
                bool _8071;
                if (_8065)
                {
                    _8071 = all(bool2(_8907.x < 1.0f.xx.x, _8907.y < 1.0f.xx.y));
                }
                else
                {
                    _8071 = _8065;
                }
                _4727 = _8071;
            }
            else
            {
                _4727 = _4722;
            }
            bool _4732;
            if (_4727)
            {
                bool _8076 = all(bool2(_8909.x > 0.0f.xx.x, _8909.y > 0.0f.xx.y));
                bool _8082;
                if (_8076)
                {
                    _8082 = all(bool2(_8909.x < 1.0f.xx.x, _8909.y < 1.0f.xx.y));
                }
                else
                {
                    _8082 = _8076;
                }
                _4732 = _8082;
            }
            else
            {
                _4732 = _4727;
            }
            float4 _9588;
            if (_4732)
            {
                float _4738 = _9570.x + _9570.y;
                float _4747 = (_9570.z + _9570.w) * (1.0f - _10369);
                float _9584;
                if (_4738 > 9.9999997473787516355514526367188e-06f)
                {
                    _9584 = _9570.x / _4738;
                }
                else
                {
                    _9584 = _3915;
                }
                _9588 = float4(_9570.x + (_4747 * _9584), _9570.y + (_4747 * (1.0f - _9584)), _9570.zw * _10369);
            }
            else
            {
                _9588 = _9570;
            }
            _9587 = _9588;
        }
        else
        {
            _9587 = _9570;
        }
        float3 _10142;
        if (_9590)
        {
            float3 _8088 = r_current_interpolation_source.Load(int3(_3334, 0)).xyz;
            float3 _10143;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6316)
            {
                uint _8095_dummy_parameter;
                float _9693;
                _9693 = r_depth_tm1.Load(int3(int2(floor(_8907 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8095_dummy_parameter))))), 0)).x;
                float _4859;
                for (int _9692 = 0; _9692 < 24; _9693 = _4859, _9692++)
                {
                    float _4831 = float(_9692 & 7) * 0.785398185253143310546875f;
                    int _4833 = _9692 >> 3;
                    int _10192;
                    if (_4833 == 0)
                    {
                        _10192 = 16;
                    }
                    else
                    {
                        _10192 = (_4833 == 1) ? 48 : 96;
                    }
                    uint _8115_dummy_parameter;
                    _4859 = min(_9693, r_depth_tm1.Load(int3(int2(floor(clamp(_8907 + ((cbFI_MvDepthLaneSizeRcp * float(_10192)) * float2(cos(_4831), sin(_4831))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8115_dummy_parameter))))), 0)).x);
                }
                float2 _9694;
                do
                {
                    float _8137 = 1.0f - _8907.y;
                    float4 _8148 = mul(float4((float2(_8907.x, _8137) * 2.0f) - 1.0f.xx, _9693, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8150 = _8148.w;
                    if (!(_8150 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9694 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8163 = ((_8148.xy / _8150.xx) + 1.0f.xx) * 0.5f;
                    _9694 = float2(_8163.x - _8907.x, _8137 - _8163.y);
                    break;
                } while(false);
                float2 _4870 = _8907 + _9694;
                bool _8181 = all(bool2(_4870.x > 0.0f.xx.x, _4870.y > 0.0f.xx.y));
                bool _8187;
                if (_8181)
                {
                    _8187 = all(bool2(_4870.x < 1.0f.xx.x, _4870.y < 1.0f.xx.y));
                }
                else
                {
                    _8187 = _8181;
                }
                float3 _10144;
                if (_8187)
                {
                    float _4876 = abs(cbFI_DeviceToViewDepth.y / (_9693 - cbFI_DeviceToViewDepth.x));
                    uint _8207_dummy_parameter;
                    int2 _8207 = int2(spvTextureSize(r_depth_m2, uint(0), _8207_dummy_parameter));
                    float _4880 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4870 * float2(_8207))), int2(0, 0), _8207 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10149;
                    if (abs(_4880 - _4876) <= (0.20000000298023223876953125f * max(_4880, _4876)))
                    {
                        uint _8241_dummy_parameter;
                        int2 _8241 = int2(spvTextureSize(r_colour_m2, uint(0), _8241_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8264;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8264);
                        }
                        _10149 = r_colour_m2.Load(int3(clamp(int2(floor(_4870 * float2(_8241))), int2(0, 0), _8241 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8274;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8274);
                        }
                        _10149 = _8088;
                    }
                    _10144 = _10149;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8284;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8284);
                    }
                    _10144 = _8088;
                }
                _10143 = _10144;
            }
            else
            {
                _10143 = _8088;
            }
            _10142 = _10143;
        }
        else
        {
            _10142 = (((_6107 * _9587.x) + (_6115 * _9587.y)) + (_6123 * _9587.z)) + (_6131 * _9587.w);
        }
        uint _4908 = cbFI_pad0 & 255u;
        bool _10037;
        float3 _10141;
        if (_4908 != 0u)
        {
            float3 _4913 = r_present_backbuffer.Load(int3(_3334, 0)).xyz;
            float3 _4917 = r_current_interpolation_source.Load(int3(_3334, 0)).xyz;
            float3 _4921 = abs(_4913 - _4917);
            float3 _9697;
            if (_4908 == 2u)
            {
                _9697 = (abs(_4917) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9697 = 0.000244140625f.xxx;
            }
            bool _4937 = any(bool3(_4921.x > _9697.x, _4921.y > _9697.y, _4921.z > _9697.z));
            bool3 _10370 = _4937.xxx;
            _10141 = float3(_10370.x ? _4913.x : _10142.x, _10370.y ? _4913.y : _10142.y, _10370.z ? _4913.z : _10142.z);
            _10037 = _4937;
        }
        else
        {
            _10141 = _10142;
            _10037 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8299;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8299);
        }
        float3 _10125;
        if (_4625 == 1u)
        {
            _10125 = lerp(_6107, _6115, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10126;
            if (_4625 == 2u)
            {
                _10126 = lerp(_6123, _6131, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10127;
                if (_4625 == 3u)
                {
                    _10127 = float(_10037).xxx;
                }
                else
                {
                    float3 _10128;
                    if (_4625 == 4u)
                    {
                        _10128 = float3(((_8905 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10129;
                        if (_4625 == 5u)
                        {
                            _10129 = float3(((_5402 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10130;
                            if (_4625 == 6u)
                            {
                                _10130 = float3(_9587.xy, _9587.z + _9587.w);
                            }
                            else
                            {
                                float3 _10131;
                                if (_4625 == 7u)
                                {
                                    _10131 = r_current_interpolation_source.Load(int3(_3334, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10132;
                                    if (_4625 == 8u)
                                    {
                                        _10132 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3690, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10133;
                                        if (_4629)
                                        {
                                            uint _8321_dummy_parameter;
                                            uint _8353_dummy_parameter;
                                            _10133 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3690 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8321_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8353_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10134;
                                            if (_4632)
                                            {
                                                _10134 = _6123;
                                            }
                                            else
                                            {
                                                float3 _10135;
                                                if (_4625 == 20u)
                                                {
                                                    _10135 = _6107;
                                                }
                                                else
                                                {
                                                    float3 _10136;
                                                    if (_4625 == 21u)
                                                    {
                                                        _10136 = _6115;
                                                    }
                                                    else
                                                    {
                                                        float3 _10137;
                                                        if (_4625 == 22u)
                                                        {
                                                            _10137 = _6131;
                                                        }
                                                        else
                                                        {
                                                            float3 _10138;
                                                            if (_4625 == 18u)
                                                            {
                                                                _10138 = _9846;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10372 = (_4625 == 19u).xxx;
                                                                _10138 = float3(_10372.x ? _9703.x : _10141.x, _10372.y ? _9703.y : _10141.y, _10372.z ? _9703.z : _10141.z);
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
                            _10129 = _10130;
                        }
                        _10128 = _10129;
                    }
                    _10127 = _10128;
                }
                _10126 = _10127;
            }
            _10125 = _10126;
        }
        float3 _10124;
        if ((_4625 >= 9u) && (_4625 <= 11u))
        {
            uint _5095 = 64u + uint((_8937.y * cbFI_MvDepthLaneSize.x) + _8937.x);
            uint _5099 = rw_nfru_diagnostics.Load<uint>(_5095 * 4 + 0) & 15u;
            float3 _10154;
            if (_4625 == 10u)
            {
                float3 _10123;
                if ((rw_nfru_diagnostics.Load<uint>(_5095 * 4 + 0) & 32u) != 0u)
                {
                    _10123 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10122;
                    if ((rw_nfru_diagnostics.Load<uint>(_5095 * 4 + 0) & 16u) != 0u)
                    {
                        _10122 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5120 = ((rw_nfru_diagnostics.Load<uint>(_5095 * 4 + 0) & 64u) != 0u).xxx;
                        _10122 = float3(_5120.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5120.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5120.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10123 = _10122;
                }
                _10154 = _10123;
            }
            else
            {
                float3 _10155;
                if (_4625 == 11u)
                {
                    uint _5133 = (rw_nfru_diagnostics.Load<uint>(_5095 * 4 + 0) >> 8u) & 15u;
                    uint _5136 = (rw_nfru_diagnostics.Load<uint>(_5095 * 4 + 0) >> 12u) & 15u;
                    float3 _10115;
                    if ((_5099 == 2u) || (_5099 == 3u))
                    {
                        _10115 = _3047[_5099];
                    }
                    else
                    {
                        bool _5148 = _5133 == 3u;
                        bool _5150 = _5136 == 3u;
                        float3 _10116;
                        if (_5148 && _5150)
                        {
                            _10116 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10117;
                            if (_5148)
                            {
                                _10117 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10118;
                                if (_5150)
                                {
                                    _10118 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10119;
                                    if ((_5133 == 4u) || (_5136 == 4u))
                                    {
                                        _10119 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10120;
                                        if ((_5133 == 1u) || (_5136 == 1u))
                                        {
                                            _10120 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10374 = (_5099 == 1u).xxx;
                                            _10120 = float3(_10374.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10374.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10374.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10119 = _10120;
                                    }
                                    _10118 = _10119;
                                }
                                _10117 = _10118;
                            }
                            _10116 = _10117;
                        }
                        _10115 = _10116;
                    }
                    _10155 = _10115;
                }
                else
                {
                    _10155 = _3047[min(_5099, 7u)];
                }
                _10154 = _10155;
            }
            _10124 = _10154;
        }
        else
        {
            _10124 = _10125;
        }
        float4 _10158;
        if ((_4625 >= 14u) && (_4625 <= 16u))
        {
            float2 _10156;
            if (_4625 == 14u)
            {
                uint _5206_dummy_parameter;
                uint _5212_dummy_parameter;
                _10156 = r_flow_tm1.Load(int3(clamp(int2(floor(_3690 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5206_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5212_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10157;
                if (_4625 == 16u)
                {
                    uint _8404 = r_warped_flow_qdata_tm1.Load(int3(_3706, 0)).x & 2147483647u;
                    uint _8436 = uint(max((int((_8404 >> 16u) & 15u) - 6), 0));
                    _10157 = ((float2(float((1 - (2 * int((_8404 >> 15u) & 1u))) * int(((_8404 >> uint(7)) & 127u) << _8436)), float((1 - (2 * int((_8404 >> 14u) & 1u))) * int((_8404 & 127u) << _8436))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10157 = _5402 * float2(cbFI_DisplaySize);
                }
                _10156 = _10157;
            }
            uint2 _5245 = uint2(clamp(round(_10156 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5247 = _5245.x;
            uint _5254 = _5245.y;
            _10158 = float4(float(_5247 & 255u), float((_5247 >> 8u) | ((_5254 & 15u) << 4u)), float(_5254 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10159;
            if (_4625 == 17u)
            {
                _10159 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3706, 0)).x != 0u), _4049, 0.0f, 1.0f);
            }
            else
            {
                _10159 = float4(_10124, 1.0f);
            }
            _10158 = _10159;
        }
        rw_output[_3334] = _10158.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5298 = ((uint(_3334.y) * uint(cbFI_DisplaySize.x)) + uint(_3334.x)) * 6u;
            uint _8482 = spvPackHalf2x16(clamp(_6106.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5298 * 4 + 0, (((_8482 & 32767u) >> 4u) | ((((_8482 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6106.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8517 = spvPackHalf2x16(clamp(_6114.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5298 + 1u) * 4 + 0, (((_8517 & 32767u) >> 4u) | ((((_8517 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6114.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8552 = spvPackHalf2x16(clamp(_6122.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5298 + 2u) * 4 + 0, (((_8552 & 32767u) >> 4u) | ((((_8552 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6122.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8587 = spvPackHalf2x16(clamp(_6130.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5298 + 3u) * 4 + 0, (((_8587 & 32767u) >> 4u) | ((((_8587 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6130.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8614 = r_current_interpolation_source.Load(int3(_3334, 0));
            uint _8628 = spvPackHalf2x16(clamp(_8614.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5298 + 4u) * 4 + 0, (((_8628 & 32767u) >> 4u) | ((((_8628 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8614.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10191;
            if (_10037 || (_4625 != 0u))
            {
                _10191 = 4294967295u;
            }
            else
            {
                uint _8663 = spvPackHalf2x16(clamp(_10158.xy, 0.0f.xx, 65000.0f.xx));
                _10191 = (((_8663 & 32767u) >> 4u) | ((((_8663 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10158.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5298 + 5u) * 4 + 0, _10191);
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
