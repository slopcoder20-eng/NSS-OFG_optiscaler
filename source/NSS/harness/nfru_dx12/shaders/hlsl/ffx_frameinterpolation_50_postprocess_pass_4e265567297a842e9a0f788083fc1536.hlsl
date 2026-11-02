static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3323[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3627 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3627.x >= cbFI_DisplaySize.x, _3627.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3627] = float4(r_present_backbuffer.Load(int3(_3627, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3627] = float4(r_current_interpolation_source.Load(int3(_3627, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4027 = (float2(_3627) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4038 = int2(floor(_4027 * float2(cbFI_MvDepthLaneSize)));
        int2 _4043 = int2(floor(_4027 * float2(cbFI_FlowLaneSize)));
        float4 _5975 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4027 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5981 = r_warped_filled_flow_tm1.Load(int3(_4043, 0)).xy;
        float2 _5987 = r_warped_filled_motion_tp1.Load(int3(_4038, 0)).xy;
        bool _6009 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10075;
        if (_6009)
        {
            float _6022 = ((2.0f * _4027.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10075 = float2(atan(_6022) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4027.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6022 * _6022))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10075 = _4027;
        }
        bool _4064 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10096;
        bool _10117;
        int2 _10128;
        float3 _11487;
        if (_4064)
        {
            float _10077;
            float _10079;
            _10079 = 2.0f;
            _10077 = -1.0f;
            uint _3691[9];
            float _11919;
            float _11922;
            for (int _10076 = 0; _10076 < 9; _10079 = _11922, _10077 = _11919, _10076++)
            {
                _3691[_10076] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4038 + int2((_10076 % 3) - 1, (_10076 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3691[_10076] != 0u)
                {
                    float _11914;
                    if (_3691[_10076] == 0u)
                    {
                        _11914 = -1.0f;
                    }
                    else
                    {
                        _11914 = float((_3691[_10076] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11922 = min(_10079, _11914);
                    _11919 = max(_10077, _11914);
                }
                else
                {
                    _11922 = _10079;
                    _11919 = _10077;
                }
            }
            float _4110 = float(_10077 >= 0.0f);
            float3 _9872 = 0.0f.xxx;
            _9872.y = _4110;
            float2 _10097;
            bool _10118;
            int2 _10129;
            float3 _11488;
            if ((_10077 - _10079) > 0.0199999995529651641845703125f)
            {
                float _10085;
                int2 _10086;
                float2 _10087;
                int2 _10089;
                float2 _10095;
                _10095 = _5987;
                _10089 = _4038;
                _10087 = _5987;
                _10086 = _4038;
                _10085 = -1.0f;
                float _11927;
                int2 _11931;
                float2 _11942;
                int2 _11953;
                float2 _11986;
                float _12033;
                int _10084 = 0;
                float _11895 = 1000000000.0f;
                for (; _10084 < 9; _11895 = _12033, _10095 = _11986, _10089 = _11953, _10087 = _11942, _10086 = _11931, _10085 = _11927, _10084++)
                {
                    if (_3691[_10084] == 0u)
                    {
                        _12033 = _11895;
                        _11986 = _10095;
                        _11953 = _10089;
                        _11942 = _10087;
                        _11931 = _10086;
                        _11927 = _10085;
                        continue;
                    }
                    int2 _4145 = clamp(_4038 + int2((_10084 % 3) - 1, (_10084 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6097 = _3691[_10084] & 2147483647u;
                    uint _6129 = uint(max((int((_6097 >> 16u) & 15u) - 6), 0));
                    float2 _4151 = (float2(float((1 - (2 * int((_6097 >> 15u) & 1u))) * int(((_6097 >> uint(7)) & 127u) << _6129)), float((1 - (2 * int((_6097 >> 14u) & 1u))) * int((_6097 & 127u) << _6129))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11881;
                    if (_3691[_10084] == 0u)
                    {
                        _11881 = -1.0f;
                    }
                    else
                    {
                        _11881 = float((_3691[_10084] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4156 = _11881 - 0.100000001490116119384765625f;
                    float2 _11882;
                    if (_6009)
                    {
                        float2 _6206 = clamp((((_10075 + (_4151 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6209 = tan(_6206.x);
                        _11882 = (float2(_6209 / cbFI_DeviceToViewDepth.z, (tan(_6206.y) * sqrt(1.0f + (_6209 * _6209))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11882 = _10075 + (_4151 * cbFI_Timestep);
                    }
                    float _4163 = cbFI_Timestep - 1.0f;
                    float2 _11883;
                    if (_6009)
                    {
                        float2 _6277 = clamp((((_10075 + (_4151 * _4163)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6280 = tan(_6277.x);
                        _11883 = (float2(_6280 / cbFI_DeviceToViewDepth.z, (tan(_6277.y) * sqrt(1.0f + (_6280 * _6280))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11883 = _10075 + (_4151 * _4163);
                    }
                    bool _6313 = all(bool2(_11882.x > 0.0f.xx.x, _11882.y > 0.0f.xx.y));
                    bool _6319;
                    if (_6313)
                    {
                        _6319 = all(bool2(_11882.x < 1.0f.xx.x, _11882.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6319 = _6313;
                    }
                    float _11886;
                    if (_6319)
                    {
                        uint _6326_dummy_parameter;
                        _11886 = max((_4156 - (log(((r_depth_tm1.Load(int3(int2(floor(_11882 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6326_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11886 = 0.0f;
                    }
                    bool _6356 = all(bool2(_11883.x > 0.0f.xx.x, _11883.y > 0.0f.xx.y));
                    bool _6362;
                    if (_6356)
                    {
                        _6362 = all(bool2(_11883.x < 1.0f.xx.x, _11883.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6362 = _6356;
                    }
                    float _11887;
                    if (_6362)
                    {
                        uint _6369_dummy_parameter;
                        _11887 = _11886 + max((_4156 - (log(((r_depth_tp1.Load(int3(int2(floor(_11883 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6369_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11887 = _11886;
                    }
                    float _11928;
                    int2 _11932;
                    float2 _11943;
                    int2 _11954;
                    float2 _11987;
                    float _12034;
                    if (_11887 == 0.0f)
                    {
                        bool _4198 = _4156 > _10085;
                        bool2 _12042 = _4198.xx;
                        _12034 = _11895;
                        _11987 = float2(_12042.x ? _4151.x : _10095.x, _12042.y ? _4151.y : _10095.y);
                        _11954 = int2(_12042.x ? _4145.x : _10089.x, _12042.y ? _4145.y : _10089.y);
                        _11943 = _10087;
                        _11932 = _10086;
                        _11928 = _4198 ? _4156 : _10085;
                    }
                    else
                    {
                        bool _4207 = _11887 < _11895;
                        bool2 _12038 = _4207.xx;
                        _12034 = _4207 ? _11887 : _11895;
                        _11987 = _10095;
                        _11954 = _10089;
                        _11943 = float2(_12038.x ? _4151.x : _10087.x, _12038.y ? _4151.y : _10087.y);
                        _11932 = int2(_12038.x ? _4145.x : _10086.x, _12038.y ? _4145.y : _10086.y);
                        _11928 = _10085;
                    }
                    _12033 = _12034;
                    _11986 = _11987;
                    _11953 = _11954;
                    _11942 = _11943;
                    _11931 = _11932;
                    _11927 = _11928;
                }
                bool _4219 = _10085 < 0.0f;
                bool2 _12048 = _4219.xx;
                int2 _12051 = int2(_12048.x ? _10086.x : _10089.x, _12048.y ? _10086.y : _10089.y);
                _11488 = float3(1.0f, _4110, float(any(bool2(_12051.x != _4038.x, _12051.y != _4038.y))));
                _10129 = _12051;
                _10118 = _4219 ? false : true;
                _10097 = float2(_12048.x ? _10087.x : _10095.x, _12048.y ? _10087.y : _10095.y);
            }
            else
            {
                _11488 = _9872;
                _10129 = _4038;
                _10118 = false;
                _10097 = _5987;
            }
            _11487 = _11488;
            _10128 = _10129;
            _10117 = _10118;
            _10096 = _10097;
        }
        else
        {
            _11487 = 0.0f.xxx;
            _10128 = _4038;
            _10117 = false;
            _10096 = _5987;
        }
        float2 _10098;
        if (_6009)
        {
            float2 _6434 = clamp((((_10075 + (_10096 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6437 = tan(_6434.x);
            _10098 = (float2(_6437 / cbFI_DeviceToViewDepth.z, (tan(_6434.y) * sqrt(1.0f + (_6437 * _6437))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10098 = _10075 + (_10096 * cbFI_Timestep);
        }
        float _4242 = cbFI_Timestep - 1.0f;
        float2 _10100;
        if (_6009)
        {
            float2 _6505 = clamp((((_10075 + (_10096 * _4242)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6508 = tan(_6505.x);
            _10100 = (float2(_6508 / cbFI_DeviceToViewDepth.z, (tan(_6505.y) * sqrt(1.0f + (_6508 * _6508))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10100 = _10075 + (_10096 * _4242);
        }
        float _4247 = -cbFI_Timestep;
        float2 _10101;
        if (_6009)
        {
            float2 _6576 = clamp((((_10075 + (_5981 * _4247)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6579 = tan(_6576.x);
            _10101 = (float2(_6579 / cbFI_DeviceToViewDepth.z, (tan(_6576.y) * sqrt(1.0f + (_6579 * _6579))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10101 = _10075 + (_5981 * _4247);
        }
        float _4252 = 1.0f - cbFI_Timestep;
        float2 _10102;
        if (_6009)
        {
            float2 _6647 = clamp((((_10075 + (_5981 * _4252)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6650 = tan(_6647.x);
            _10102 = (float2(_6650 / cbFI_DeviceToViewDepth.z, (tan(_6647.y) * sqrt(1.0f + (_6650 * _6650))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10102 = _10075 + (_5981 * _4252);
        }
        float4 _6685 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10098, 0.0f);
        float3 _6686 = _6685.xyz;
        float4 _6693 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10100, 0.0f);
        float3 _6694 = _6693.xyz;
        float4 _6701 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10101, 0.0f);
        float3 _6702 = _6701.xyz;
        float4 _6709 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10102, 0.0f);
        float3 _6710 = _6709.xyz;
        float4 _6724 = exp(_5975 - max(max(max(_5975.x, _5975.y), _5975.z), _5975.w).xxxx);
        float4 _6731 = _6724 / (dot(_6724, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4271 = _4064 && (!_10117);
        bool _4280;
        if (_4271)
        {
            _4280 = (_6731.z + _6731.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4280 = _4271;
        }
        bool _4291;
        if (_4280)
        {
            _4291 = length((_10101 - _10098) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4291 = _4280;
        }
        bool _10141;
        if (_4291)
        {
            uint4 _6750 = r_warped_motion_qdata_tp1.Load(int3(_10128, 0));
            uint _6751 = _6750.x;
            bool _10144;
            if (_6751 != 0u)
            {
                float _10130;
                if (_6751 == 0u)
                {
                    _10130 = -1.0f;
                }
                else
                {
                    _10130 = float((_6751 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4301 = _10130 - 0.12000000476837158203125f;
                bool _6770 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
                bool _6776;
                if (_6770)
                {
                    _6776 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
                }
                else
                {
                    _6776 = _6770;
                }
                bool _4311;
                if (_6776)
                {
                    uint _6783_dummy_parameter;
                    _4311 = (log(((r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6783_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4301;
                }
                else
                {
                    _4311 = _6776;
                }
                bool _4325;
                if (!_4311)
                {
                    bool _6813 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
                    bool _6819;
                    if (_6813)
                    {
                        _6819 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6819 = _6813;
                    }
                    bool _4323;
                    if (_6819)
                    {
                        uint _6826_dummy_parameter;
                        _4323 = (log(((r_depth_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6826_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4301;
                    }
                    else
                    {
                        _4323 = _6819;
                    }
                    _4325 = _4323;
                }
                else
                {
                    _4325 = _4311;
                }
                _10144 = _4325;
            }
            else
            {
                _10144 = false;
            }
            _10141 = _10144;
        }
        else
        {
            _10141 = false;
        }
        bool _4330 = _10117 || _10141;
        bool _4335;
        if (_4330)
        {
            bool _6856 = all(bool2(_10098.x > 0.0f.xx.x, _10098.y > 0.0f.xx.y));
            bool _6862;
            if (_6856)
            {
                _6862 = all(bool2(_10098.x < 1.0f.xx.x, _10098.y < 1.0f.xx.y));
            }
            else
            {
                _6862 = _6856;
            }
            _4335 = _6862;
        }
        else
        {
            _4335 = _4330;
        }
        bool _4340;
        if (_4335)
        {
            bool _6867 = all(bool2(_10100.x > 0.0f.xx.x, _10100.y > 0.0f.xx.y));
            bool _6873;
            if (_6867)
            {
                _6873 = all(bool2(_10100.x < 1.0f.xx.x, _10100.y < 1.0f.xx.y));
            }
            else
            {
                _6873 = _6867;
            }
            _4340 = _6873;
        }
        else
        {
            _4340 = _4335;
        }
        float4 _10238;
        if (_4340)
        {
            float _4343 = _6731.x;
            float _4345 = _6731.y;
            float _4346 = _4343 + _4345;
            float _4351 = _6731.z + _6731.w;
            float _10159;
            if (_4346 > 0.001000000047497451305389404296875f)
            {
                _10159 = _4343 / _4346;
            }
            else
            {
                _10159 = _4252;
            }
            _10238 = float4(_4343 + (_4351 * _10159), _4345 + (_4351 * (1.0f - _10159)), 0.0f, 0.0f);
        }
        else
        {
            _10238 = _6731;
        }
        bool _6901 = (cbFI_pad0 & 1024u) != 0u;
        bool _6877 = !_6901;
        bool _6878 = !_6877;
        bool _6895;
        if (_6878)
        {
            _6895 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10128.y * cbFI_MvDepthLaneSize.x) + _10128.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6895 = _6877;
        }
        bool _6927;
        if (_6878)
        {
            _6927 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4043.y * cbFI_FlowLaneSize.x) + _4043.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6927 = _6877;
        }
        float _4386 = float(_6927);
        bool _10251;
        float4 _10282;
        float3 _11301;
        if (_6901)
        {
            bool _4396;
            if (_6895)
            {
                _4396 = all(bool2(_10098.x > 0.0f.xx.x, _10098.y > 0.0f.xx.y));
            }
            else
            {
                _4396 = _6895;
            }
            bool _4402;
            if (_4396)
            {
                _4402 = all(bool2(_10098.x < 1.0f.xx.x, _10098.y < 1.0f.xx.y));
            }
            else
            {
                _4402 = _4396;
            }
            bool _4409;
            if (_6895)
            {
                _4409 = all(bool2(_10100.x > 0.0f.xx.x, _10100.y > 0.0f.xx.y));
            }
            else
            {
                _4409 = _6895;
            }
            bool _4415;
            if (_4409)
            {
                _4415 = all(bool2(_10100.x < 1.0f.xx.x, _10100.y < 1.0f.xx.y));
            }
            else
            {
                _4415 = _4409;
            }
            bool _4422;
            if (_6927)
            {
                _4422 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
            }
            else
            {
                _4422 = _6927;
            }
            bool _4428;
            if (_4422)
            {
                _4428 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
            }
            else
            {
                _4428 = _4422;
            }
            bool _4435;
            if (_6927)
            {
                _4435 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
            }
            else
            {
                _4435 = _6927;
            }
            bool _4441;
            if (_4435)
            {
                _4441 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
            }
            else
            {
                _4441 = _4435;
            }
            bool _4443 = !_6895;
            if (_4443)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6969;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6969);
                }
            }
            bool _4448 = !_6927;
            if (_4448)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6979;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6979);
                }
            }
            if (_6895 && _4448)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6989;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6989);
                }
            }
            if (_4443 && _6927)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6999;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6999);
                }
            }
            float _4467 = float(_4402);
            float _4469 = float(_4415);
            bool _4472 = _4428 && _4441;
            float _10193;
            if (_4472)
            {
                _10193 = 1.0f;
            }
            else
            {
                _10193 = (_4428 || _4441) ? 0.5f : 0.0f;
            }
            bool _10198;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4402)) && (!_4415))
            {
                bool _4502;
                if (_4472)
                {
                    float _10196;
                    do
                    {
                        bool _7083 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
                        bool _7089;
                        if (_7083)
                        {
                            _7089 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7089 = _7083;
                        }
                        bool _7020 = !_7089;
                        bool _7027;
                        if (!_7020)
                        {
                            bool _7094 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
                            bool _7100;
                            if (_7094)
                            {
                                _7100 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7100 = _7094;
                            }
                            _7027 = !_7100;
                        }
                        else
                        {
                            _7027 = _7020;
                        }
                        if (_7027)
                        {
                            _10196 = 0.0f;
                            break;
                        }
                        uint _7107_dummy_parameter;
                        uint _7123_dummy_parameter;
                        float4 _7048 = mul(float4((float2(_10101.x, 1.0f - _10101.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7107_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7050 = _7048.w;
                        if (abs(_7050) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10196 = 0.0f;
                            break;
                        }
                        float _7061 = abs(cbFI_DeviceToViewDepth.y / ((_7048.z / _7050) - cbFI_DeviceToViewDepth.x));
                        float _7064 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7123_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10196 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7061 - _7064) / max(max(_7061, _7064), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4502 = _10196 >= 0.5f;
                }
                else
                {
                    _4502 = _4472;
                }
                bool _4510;
                if (_4502)
                {
                    _4510 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4510 = _4502;
                }
                bool _10199;
                if (_4510)
                {
                    uint _7173_dummy_parameter;
                    float2 _10197;
                    do
                    {
                        float _7199 = 1.0f - _10101.y;
                        float4 _7210 = mul(float4((float2(_10101.x, _7199) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7173_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7212 = _7210.w;
                        if (!(_7212 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10197 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7225 = ((_7210.xy / _7212.xx) + 1.0f.xx) * 0.5f;
                        _10197 = float2(_7225.x - _10101.x, _7199 - _7225.y);
                        break;
                    } while(false);
                    float2 _4523 = float2(cbFI_DisplaySize);
                    _10199 = length(((_10101 + _10197) - _10102) * _4523) <= ((0.100000001490116119384765625f * length(_10197 * _4523)) + 8.0f);
                }
                else
                {
                    _10199 = _4502;
                }
                _10198 = _10199;
            }
            else
            {
                _10198 = true;
            }
            bool _4537 = !_10198;
            bool _12052 = _4537 ? false : _4441;
            bool _12053 = _4537 ? false : _4428;
            bool _10252;
            float4 _10283;
            if (!(((_4402 && _4415) && _12053) && _12052))
            {
                float4 _4559 = _10238 * float4(_4467, _4469, float(_12053), float(_12052));
                float _4561 = dot(_4559, 1.0f.xxxx);
                bool _4564 = !(_4561 > 0.0f);
                float4 _10284;
                if (!_4564)
                {
                    _10284 = _4559 / _4561.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7247;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7247);
                    }
                    _10284 = 0.0f.xxxx;
                }
                _10283 = _10284;
                _10252 = _4564;
            }
            else
            {
                _10283 = _10238;
                _10252 = false;
            }
            _11301 = float3(_4467, _4469, _10193);
            _10282 = _10283;
            _10251 = _10252;
        }
        else
        {
            _11301 = float3(float(_6895), _4386, 0.0f);
            _10282 = _10238;
            _10251 = false;
        }
        bool _4582 = !_10251;
        float4 _10344;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4582)
        {
            float _4589 = _10282.x + _10282.y;
            float4 _10345;
            if (_4589 > 0.001000000047497451305389404296875f)
            {
                _10345 = float4(_10282.x / _4589, _10282.y / _4589, 0.0f, 0.0f);
            }
            else
            {
                _10345 = float4(_4252, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10344 = _10345;
        }
        else
        {
            _10344 = _10282;
        }
        float4 _10440;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4582) && _6895)
        {
            float _10341;
            do
            {
                uint4 _7387 = r_warped_motion_qdata_tp1.Load(int3(_10128, 0));
                uint _7388 = _7387.x;
                if (_7388 != 0u)
                {
                    float _10340;
                    if (_7388 == 0u)
                    {
                        _10340 = -1.0f;
                    }
                    else
                    {
                        _10340 = float((_7388 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10341 = _10340;
                    break;
                }
                int _10323;
                uint _10324;
                _10324 = _7388;
                _10323 = -1;
                uint _10339;
                for (; _10323 <= 1; _10324 = _10339, _10323++)
                {
                    _10339 = _10324;
                    for (int _10337 = -1; _10337 <= 1; )
                    {
                        _10339 = max(_10339, r_warped_motion_qdata_tp1.Load(int3(clamp(_10128 + int2(_10337, _10323), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10337++;
                        continue;
                    }
                }
                if (_10324 != 0u)
                {
                    float _10336;
                    if (_10324 == 0u)
                    {
                        _10336 = -1.0f;
                    }
                    else
                    {
                        _10336 = float((_10324 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10341 = _10336;
                    break;
                }
                uint _10326;
                _10326 = 4294967295u;
                uint _12023;
                for (int _10325 = 0; _10325 < 8; _10326 = _12023, _10325++)
                {
                    int _10329 = 0;
                    for (;;)
                    {
                        if (_10329 < 5)
                        {
                            int2 _7338 = _10128 + (_1093[_10325] * _1102[_10329].xx);
                            bool _7341 = any(bool2(_7338.x < int2(0, 0).x, _7338.y < int2(0, 0).y));
                            bool _7349;
                            if (!_7341)
                            {
                                _7349 = any(bool2(_7338.x >= cbFI_MvDepthLaneSize.x, _7338.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7349 = _7341;
                            }
                            if (_7349)
                            {
                                _12023 = _10326;
                                break;
                            }
                            uint4 _7427 = r_warped_motion_qdata_tp1.Load(int3(_7338, 0));
                            uint _7428 = _7427.x;
                            if (_7428 != 0u)
                            {
                                _12023 = min(_10326, _7428);
                                break;
                            }
                            _10329++;
                            continue;
                        }
                        else
                        {
                            _12023 = _10326;
                            break;
                        }
                    }
                }
                float _10328;
                if (_10326 == 4294967295u)
                {
                    _10328 = -1.0f;
                }
                else
                {
                    float _10327;
                    if (_10326 == 0u)
                    {
                        _10327 = -1.0f;
                    }
                    else
                    {
                        _10327 = float((_10326 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10328 = _10327;
                }
                _10341 = _10328;
                break;
            } while(false);
            float _4625 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4629 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4635;
            if (_4629)
            {
                _4635 = _10344.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4635 = _4629;
            }
            bool _4640;
            if (_4635)
            {
                bool _7447 = all(bool2(_10100.x > 0.0f.xx.x, _10100.y > 0.0f.xx.y));
                bool _7453;
                if (_7447)
                {
                    _7453 = all(bool2(_10100.x < 1.0f.xx.x, _10100.y < 1.0f.xx.y));
                }
                else
                {
                    _7453 = _7447;
                }
                _4640 = _7453;
            }
            else
            {
                _4640 = _4635;
            }
            float4 _10385;
            if (_4640)
            {
                float _10360;
                if (_10341 >= 0.0f)
                {
                    _10360 = _10341 - _4625;
                }
                else
                {
                    float _10356;
                    _10356 = 2.0f;
                    float _7510;
                    for (int _10355 = 0; _10355 < 24; _10356 = _7510, _10355++)
                    {
                        float _7474 = float(_10355 & 7) * 0.785398185253143310546875f;
                        int _7476 = _10355 >> 3;
                        int _10357;
                        if (_7476 == 0)
                        {
                            _10357 = 16;
                        }
                        else
                        {
                            _10357 = (_7476 == 1) ? 48 : 96;
                        }
                        uint _7542_dummy_parameter;
                        _7510 = min(_10356, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10100 + ((cbFI_MvDepthLaneSizeRcp * float(_10357)) * float2(cos(_7474), sin(_7474))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7542_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10360 = _10356;
                }
                uint _7574_dummy_parameter;
                float4 _10386;
                if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7574_dummy_parameter))))), 0)).x) > ((exp((_10360 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10386 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10386 = 1.0f.xxxx;
                }
                _10385 = _10386;
            }
            else
            {
                _10385 = 1.0f.xxxx;
            }
            bool _4667 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4673;
            if (_4667)
            {
                _4673 = _10344.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4673 = _4667;
            }
            bool _4678;
            if (_4673)
            {
                bool _7599 = all(bool2(_10098.x > 0.0f.xx.x, _10098.y > 0.0f.xx.y));
                bool _7605;
                if (_7599)
                {
                    _7605 = all(bool2(_10098.x < 1.0f.xx.x, _10098.y < 1.0f.xx.y));
                }
                else
                {
                    _7605 = _7599;
                }
                _4678 = _7605;
            }
            else
            {
                _4678 = _4673;
            }
            float4 _10389;
            if (_4678)
            {
                float _10380;
                if (_10341 >= 0.0f)
                {
                    _10380 = _10341 - _4625;
                }
                else
                {
                    float _10376;
                    _10376 = 2.0f;
                    float _7662;
                    for (int _10375 = 0; _10375 < 24; _10376 = _7662, _10375++)
                    {
                        float _7626 = float(_10375 & 7) * 0.785398185253143310546875f;
                        int _7628 = _10375 >> 3;
                        int _10377;
                        if (_7628 == 0)
                        {
                            _10377 = 16;
                        }
                        else
                        {
                            _10377 = (_7628 == 1) ? 48 : 96;
                        }
                        uint _7678_dummy_parameter;
                        _7662 = min(_10376, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10098 + ((cbFI_MvDepthLaneSizeRcp * float(_10377)) * float2(cos(_7626), sin(_7626))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7678_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10380 = _10376;
                }
                uint _7726_dummy_parameter;
                float4 _10390;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7726_dummy_parameter))))), 0)).x) > ((exp((_10380 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9944 = _10385;
                    _9944.x = 0.0f;
                    _10390 = _9944;
                }
                else
                {
                    _10390 = _10385;
                }
                _10389 = _10390;
            }
            else
            {
                _10389 = _10385;
            }
            float4 _10441;
            if (any(bool4(_10389.x < 1.0f.xxxx.x, _10389.y < 1.0f.xxxx.y, _10389.z < 1.0f.xxxx.z, _10389.w < 1.0f.xxxx.w)))
            {
                float4 _4708 = _10344 * _10389;
                float _4710 = dot(_4708, 1.0f.xxxx);
                float4 _10442;
                if (_4710 > 0.0f)
                {
                    _10442 = _4708 / _4710.xxxx;
                }
                else
                {
                    bool _4721 = _10389.y == 0.0f;
                    bool _4727;
                    if (_4721)
                    {
                        _4727 = _10389.x > 0.0f;
                    }
                    else
                    {
                        _4727 = _4721;
                    }
                    bool _4732;
                    if (_4727)
                    {
                        bool _7751 = all(bool2(_10098.x > 0.0f.xx.x, _10098.y > 0.0f.xx.y));
                        bool _7757;
                        if (_7751)
                        {
                            _7757 = all(bool2(_10098.x < 1.0f.xx.x, _10098.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7757 = _7751;
                        }
                        _4732 = _7757;
                    }
                    else
                    {
                        _4732 = _4727;
                    }
                    float4 _10443;
                    if (_4732)
                    {
                        _10443 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4737 = _10389.x == 0.0f;
                        bool _4743;
                        if (_4737)
                        {
                            _4743 = _10389.y > 0.0f;
                        }
                        else
                        {
                            _4743 = _4737;
                        }
                        bool _4748;
                        if (_4743)
                        {
                            bool _7762 = all(bool2(_10100.x > 0.0f.xx.x, _10100.y > 0.0f.xx.y));
                            bool _7768;
                            if (_7762)
                            {
                                _7768 = all(bool2(_10100.x < 1.0f.xx.x, _10100.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7768 = _7762;
                            }
                            _4748 = _7768;
                        }
                        else
                        {
                            _4748 = _4743;
                        }
                        bool4 _12054 = _4748.xxxx;
                        _10443 = float4(_12054.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10344.x, _12054.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10344.y, _12054.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10344.z, _12054.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10344.w);
                    }
                    _10442 = _10443;
                }
                _10441 = _10442;
            }
            else
            {
                _10441 = _10344;
            }
            _10440 = _10441;
        }
        else
        {
            _10440 = _10344;
        }
        float4 _10986;
        bool _11006;
        float3 _11120;
        if (((cbFI_pad0 & 32768u) != 0u) && _4582)
        {
            bool _4765 = _10440.x > 0.00999999977648258209228515625f;
            bool _4768 = _10440.y > 0.00999999977648258209228515625f;
            bool _4777 = (_10440.z + _10440.w) > 0.0199999995529651641845703125f;
            bool _4783;
            if (_4777)
            {
                bool _7773 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
                bool _7779;
                if (_7773)
                {
                    _7779 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
                }
                else
                {
                    _7779 = _7773;
                }
                _4783 = _7779;
            }
            else
            {
                _4783 = _4777;
            }
            bool _4788;
            if (_4783)
            {
                bool _7784 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
                bool _7790;
                if (_7784)
                {
                    _7790 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
                }
                else
                {
                    _7790 = _7784;
                }
                _4788 = _7790;
            }
            else
            {
                _4788 = _4783;
            }
            bool _4795;
            if (_4788)
            {
                float _10451;
                do
                {
                    bool _7873 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
                    bool _7879;
                    if (_7873)
                    {
                        _7879 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7879 = _7873;
                    }
                    bool _7810 = !_7879;
                    bool _7817;
                    if (!_7810)
                    {
                        bool _7884 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
                        bool _7890;
                        if (_7884)
                        {
                            _7890 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7890 = _7884;
                        }
                        _7817 = !_7890;
                    }
                    else
                    {
                        _7817 = _7810;
                    }
                    if (_7817)
                    {
                        _10451 = 0.0f;
                        break;
                    }
                    uint _7897_dummy_parameter;
                    uint _7913_dummy_parameter;
                    float4 _7838 = mul(float4((float2(_10101.x, 1.0f - _10101.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7897_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7840 = _7838.w;
                    if (abs(_7840) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10451 = 0.0f;
                        break;
                    }
                    float _7851 = abs(cbFI_DeviceToViewDepth.y / ((_7838.z / _7840) - cbFI_DeviceToViewDepth.x));
                    float _7854 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7913_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10451 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7851 - _7854) / max(max(_7851, _7854), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4795 = _10451 < 0.5f;
            }
            else
            {
                _4795 = _4788;
            }
            float4 _10466;
            if (_4795)
            {
                uint _7963_dummy_parameter;
                uint _7994_dummy_parameter;
                float4 _10467;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7963_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7994_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10467 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10467 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10466 = _10467;
            }
            else
            {
                _10466 = 1.0f.xxxx;
            }
            bool _4819;
            if (_6895)
            {
                bool _8023 = all(bool2(_10098.x > 0.0f.xx.x, _10098.y > 0.0f.xx.y));
                bool _8029;
                if (_8023)
                {
                    _8029 = all(bool2(_10098.x < 1.0f.xx.x, _10098.y < 1.0f.xx.y));
                }
                else
                {
                    _8029 = _8023;
                }
                _4819 = _8029;
            }
            else
            {
                _4819 = _6895;
            }
            bool _4825;
            if (_6895)
            {
                bool _8034 = all(bool2(_10100.x > 0.0f.xx.x, _10100.y > 0.0f.xx.y));
                bool _8040;
                if (_8034)
                {
                    _8040 = all(bool2(_10100.x < 1.0f.xx.x, _10100.y < 1.0f.xx.y));
                }
                else
                {
                    _8040 = _8034;
                }
                _4825 = _8040;
            }
            else
            {
                _4825 = _6895;
            }
            bool _4831;
            if (_6927)
            {
                bool _8045 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
                bool _8051;
                if (_8045)
                {
                    _8051 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
                }
                else
                {
                    _8051 = _8045;
                }
                _4831 = _8051;
            }
            else
            {
                _4831 = _6927;
            }
            bool _4837;
            if (_6927)
            {
                bool _8056 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
                bool _8062;
                if (_8056)
                {
                    _8062 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
                }
                else
                {
                    _8062 = _8056;
                }
                _4837 = _8062;
            }
            else
            {
                _4837 = _6927;
            }
            bool _4840 = _4831 != _4837;
            bool _4846;
            if (_4840)
            {
                _4846 = _4819 || _4825;
            }
            else
            {
                _4846 = _4840;
            }
            float4 _10554;
            if (_4846)
            {
                float4 _9971 = _10466;
                _9971.z = 0.0f;
                _9971.w = 0.0f;
                _10554 = _9971;
            }
            else
            {
                _10554 = _10466;
            }
            bool _4853 = _4819 && _4765;
            bool _4856 = _4825 && _4768;
            float4 _10659;
            float3 _11199;
            if (_4853 || _4856)
            {
                float _10549;
                do
                {
                    uint4 _8201 = r_warped_motion_qdata_tp1.Load(int3(_10128, 0));
                    uint _8202 = _8201.x;
                    if (_8202 != 0u)
                    {
                        float _10548;
                        if (_8202 == 0u)
                        {
                            _10548 = -1.0f;
                        }
                        else
                        {
                            _10548 = float((_8202 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10549 = _10548;
                        break;
                    }
                    int _10531;
                    uint _10532;
                    _10532 = _8202;
                    _10531 = -1;
                    uint _10547;
                    for (; _10531 <= 1; _10532 = _10547, _10531++)
                    {
                        _10547 = _10532;
                        for (int _10545 = -1; _10545 <= 1; )
                        {
                            _10547 = max(_10547, r_warped_motion_qdata_tp1.Load(int3(clamp(_10128 + int2(_10545, _10531), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10545++;
                            continue;
                        }
                    }
                    if (_10532 != 0u)
                    {
                        float _10544;
                        if (_10532 == 0u)
                        {
                            _10544 = -1.0f;
                        }
                        else
                        {
                            _10544 = float((_10532 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10549 = _10544;
                        break;
                    }
                    uint _10534;
                    _10534 = 4294967295u;
                    uint _12024;
                    for (int _10533 = 0; _10533 < 8; _10534 = _12024, _10533++)
                    {
                        int _10537 = 0;
                        for (;;)
                        {
                            if (_10537 < 5)
                            {
                                int2 _8152 = _10128 + (_1093[_10533] * _1102[_10537].xx);
                                bool _8155 = any(bool2(_8152.x < int2(0, 0).x, _8152.y < int2(0, 0).y));
                                bool _8163;
                                if (!_8155)
                                {
                                    _8163 = any(bool2(_8152.x >= cbFI_MvDepthLaneSize.x, _8152.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8163 = _8155;
                                }
                                if (_8163)
                                {
                                    _12024 = _10534;
                                    break;
                                }
                                uint4 _8241 = r_warped_motion_qdata_tp1.Load(int3(_8152, 0));
                                uint _8242 = _8241.x;
                                if (_8242 != 0u)
                                {
                                    _12024 = min(_10534, _8242);
                                    break;
                                }
                                _10537++;
                                continue;
                            }
                            else
                            {
                                _12024 = _10534;
                                break;
                            }
                        }
                    }
                    float _10536;
                    if (_10534 == 4294967295u)
                    {
                        _10536 = -1.0f;
                    }
                    else
                    {
                        float _10535;
                        if (_10534 == 0u)
                        {
                            _10535 = -1.0f;
                        }
                        else
                        {
                            _10535 = float((_10534 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10536 = _10535;
                    }
                    _10549 = _10536;
                    break;
                } while(false);
                bool _4864 = _10549 < 0.0f;
                float _10550;
                if (_4864)
                {
                    _10550 = 0.0f;
                }
                else
                {
                    _10550 = _10549 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8263_dummy_parameter;
                uint _8295_dummy_parameter;
                float4 _10587;
                if ((_4864 && _4853) && _4856)
                {
                    uint _8327_dummy_parameter;
                    float _8351 = log(((r_depth_tm1.Load(int3(int2(floor(_10098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8327_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8359_dummy_parameter;
                    float _8383 = log(((r_depth_tp1.Load(int3(int2(floor(_10100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8359_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10588;
                    if (_8351 > (_8383 + 0.07999999821186065673828125f))
                    {
                        float4 _9975 = _10554;
                        _9975.x = 0.0f;
                        _10588 = _9975;
                    }
                    else
                    {
                        float4 _10589;
                        if (_8383 > (_8351 + 0.07999999821186065673828125f))
                        {
                            float4 _9977 = _10554;
                            _9977.y = 0.0f;
                            _10589 = _9977;
                        }
                        else
                        {
                            _10589 = _10554;
                        }
                        _10588 = _10589;
                    }
                    _10587 = _10588;
                }
                else
                {
                    _10587 = _10554;
                }
                float _4916 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4918 = _10549 >= 0.0f;
                float _10570;
                if (_4918)
                {
                    _10570 = _10549 - _4916;
                }
                else
                {
                    float _10566;
                    if (_4853)
                    {
                        float _10565;
                        _10565 = 2.0f;
                        float _8441;
                        for (int _10564 = 0; _10564 < 24; _10565 = _8441, _10564++)
                        {
                            float _8405 = float(_10564 & 7) * 0.785398185253143310546875f;
                            int _8407 = _10564 >> 3;
                            int _10567;
                            if (_8407 == 0)
                            {
                                _10567 = 16;
                            }
                            else
                            {
                                _10567 = (_8407 == 1) ? 48 : 96;
                            }
                            uint _8457_dummy_parameter;
                            _8441 = min(_10565, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10098 + ((cbFI_MvDepthLaneSizeRcp * float(_10567)) * float2(cos(_8405), sin(_8405))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8457_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10566 = _10565;
                    }
                    else
                    {
                        _10566 = 0.0f;
                    }
                    _10570 = _10566;
                }
                float _10577;
                if (_4918)
                {
                    _10577 = _10549 - _4916;
                }
                else
                {
                    float _10573;
                    if (_4856)
                    {
                        float _10572;
                        _10572 = 2.0f;
                        float _8555;
                        for (int _10571 = 0; _10571 < 24; _10572 = _8555, _10571++)
                        {
                            float _8519 = float(_10571 & 7) * 0.785398185253143310546875f;
                            int _8521 = _10571 >> 3;
                            int _10574;
                            if (_8521 == 0)
                            {
                                _10574 = 16;
                            }
                            else
                            {
                                _10574 = (_8521 == 1) ? 48 : 96;
                            }
                            uint _8587_dummy_parameter;
                            _8555 = min(_10572, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10100 + ((cbFI_MvDepthLaneSizeRcp * float(_10574)) * float2(cos(_8519), sin(_8519))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8587_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10573 = _10572;
                    }
                    else
                    {
                        _10573 = 0.0f;
                    }
                    _10577 = _10573;
                }
                float _10578;
                if (_4853)
                {
                    uint _8619_dummy_parameter;
                    _10578 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8619_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10578 = 0.0f;
                }
                float _10579;
                if (_4856)
                {
                    uint _8639_dummy_parameter;
                    _10579 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8639_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10579 = 0.0f;
                }
                bool _4973;
                if (_4853)
                {
                    _4973 = _10578 > ((exp((_10570 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4973 = _4853;
                }
                float4 _10595;
                if (_4973)
                {
                    float4 _9979 = _10587;
                    _9979.x = 0.0f;
                    _10595 = _9979;
                }
                else
                {
                    _10595 = _10587;
                }
                bool _4985;
                if (_4856)
                {
                    _4985 = _10579 > ((exp((_10577 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4985 = _4856;
                }
                float4 _10597;
                if (_4985)
                {
                    float4 _9981 = _10595;
                    _9981.y = 0.0f;
                    _10597 = _9981;
                }
                else
                {
                    _10597 = _10595;
                }
                float4 _10660;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4918)
                {
                    bool _5005;
                    if (_4853)
                    {
                        _5005 = _10578 < ((exp((_10570 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5005 = _4853;
                    }
                    float4 _10599;
                    if (_5005)
                    {
                        float4 _9983 = _10597;
                        _9983.x = 0.0f;
                        _10599 = _9983;
                    }
                    else
                    {
                        _10599 = _10597;
                    }
                    bool _5017;
                    if (_4856)
                    {
                        _5017 = _10579 < ((exp((_10577 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5017 = _4856;
                    }
                    float4 _10661;
                    if (_5017)
                    {
                        float4 _9985 = _10599;
                        _9985.y = 0.0f;
                        _10661 = _9985;
                    }
                    else
                    {
                        _10661 = _10599;
                    }
                    _10660 = _10661;
                }
                else
                {
                    _10660 = _10597;
                }
                _11199 = float3(_10550, log(((r_depth_tm1.Load(int3(int2(floor(_10098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8263_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10100 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8295_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10659 = _10660;
            }
            else
            {
                _11199 = float3(0.0f, 0.0f, 0.5f);
                _10659 = _10554;
            }
            bool _5028 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4777;
            bool _5034;
            if (_5028)
            {
                _5034 = _4831 || _4837;
            }
            else
            {
                _5034 = _5028;
            }
            float4 _10682;
            if (_5034)
            {
                float _10654;
                do
                {
                    uint4 _8819 = r_warped_motion_qdata_tp1.Load(int3(_10128, 0));
                    uint _8820 = _8819.x;
                    if (_8820 != 0u)
                    {
                        float _10653;
                        if (_8820 == 0u)
                        {
                            _10653 = -1.0f;
                        }
                        else
                        {
                            _10653 = float((_8820 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10654 = _10653;
                        break;
                    }
                    int _10636;
                    uint _10637;
                    _10637 = _8820;
                    _10636 = -1;
                    uint _10652;
                    for (; _10636 <= 1; _10637 = _10652, _10636++)
                    {
                        _10652 = _10637;
                        for (int _10650 = -1; _10650 <= 1; )
                        {
                            _10652 = max(_10652, r_warped_motion_qdata_tp1.Load(int3(clamp(_10128 + int2(_10650, _10636), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10650++;
                            continue;
                        }
                    }
                    if (_10637 != 0u)
                    {
                        float _10649;
                        if (_10637 == 0u)
                        {
                            _10649 = -1.0f;
                        }
                        else
                        {
                            _10649 = float((_10637 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10654 = _10649;
                        break;
                    }
                    uint _10639;
                    _10639 = 4294967295u;
                    uint _12025;
                    for (int _10638 = 0; _10638 < 8; _10639 = _12025, _10638++)
                    {
                        int _10642 = 0;
                        for (;;)
                        {
                            if (_10642 < 5)
                            {
                                int2 _8770 = _10128 + (_1093[_10638] * _1102[_10642].xx);
                                bool _8773 = any(bool2(_8770.x < int2(0, 0).x, _8770.y < int2(0, 0).y));
                                bool _8781;
                                if (!_8773)
                                {
                                    _8781 = any(bool2(_8770.x >= cbFI_MvDepthLaneSize.x, _8770.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8781 = _8773;
                                }
                                if (_8781)
                                {
                                    _12025 = _10639;
                                    break;
                                }
                                uint4 _8859 = r_warped_motion_qdata_tp1.Load(int3(_8770, 0));
                                uint _8860 = _8859.x;
                                if (_8860 != 0u)
                                {
                                    _12025 = min(_10639, _8860);
                                    break;
                                }
                                _10642++;
                                continue;
                            }
                            else
                            {
                                _12025 = _10639;
                                break;
                            }
                        }
                    }
                    float _10641;
                    if (_10639 == 4294967295u)
                    {
                        _10641 = -1.0f;
                    }
                    else
                    {
                        float _10640;
                        if (_10639 == 0u)
                        {
                            _10640 = -1.0f;
                        }
                        else
                        {
                            _10640 = float((_10639 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10641 = _10640;
                    }
                    _10654 = _10641;
                    break;
                } while(false);
                float4 _10683;
                if (_10654 >= 0.0f)
                {
                    float _8881 = (exp((_10654 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5053;
                    if (_4831)
                    {
                        uint _8888_dummy_parameter;
                        _5053 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8888_dummy_parameter))))), 0)).x) > _8881;
                    }
                    else
                    {
                        _5053 = _4831;
                    }
                    float4 _10672;
                    if (_5053)
                    {
                        float4 _9987 = _10659;
                        _9987.z = 0.0f;
                        _10672 = _9987;
                    }
                    else
                    {
                        _10672 = _10659;
                    }
                    bool _5065;
                    if (_4837)
                    {
                        uint _8908_dummy_parameter;
                        _5065 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8908_dummy_parameter))))), 0)).x) > _8881;
                    }
                    else
                    {
                        _5065 = _4837;
                    }
                    float4 _10684;
                    if (_5065)
                    {
                        float4 _9989 = _10672;
                        _9989.w = 0.0f;
                        _10684 = _9989;
                    }
                    else
                    {
                        _10684 = _10672;
                    }
                    _10683 = _10684;
                }
                else
                {
                    _10683 = _10659;
                }
                _10682 = _10683;
            }
            else
            {
                _10682 = _10659;
            }
            bool _5073 = _4819 != _4825;
            bool _5080;
            if (_5073)
            {
                _5080 = _4819 ? _4765 : _4768;
            }
            else
            {
                _5080 = _5073;
            }
            bool _5087;
            if (_5080)
            {
                _5087 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5087 = _5080;
            }
            float4 _10767;
            if (_5087)
            {
                bool2 _5092 = _4819.xx;
                float2 _5093 = float2(_5092.x ? _10098.x : _10100.x, _5092.y ? _10098.y : _10100.y);
                float _10674;
                if (_4819)
                {
                    uint _8928_dummy_parameter;
                    _10674 = r_depth_tm1.Load(int3(int2(floor(_5093 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8928_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8944_dummy_parameter;
                    _10674 = r_depth_tp1.Load(int3(int2(floor(_5093 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8944_dummy_parameter))))), 0)).x;
                }
                float4x4 _10675;
                if (_4819)
                {
                    _10675 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10675 = cbFI_MotionTP1ToTM1;
                }
                float2 _10676;
                do
                {
                    float _8971 = _5093.x;
                    float _8974 = 1.0f - _5093.y;
                    float4 _8985 = mul(float4((float2(_8971, _8974) * 2.0f) - 1.0f.xx, _10674, 1.0f), _10675);
                    float _8987 = _8985.w;
                    if (!(_8987 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10676 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9000 = ((_8985.xy / _8987.xx) + 1.0f.xx) * 0.5f;
                    _10676 = float2(_9000.x - _8971, _8974 - _9000.y);
                    break;
                } while(false);
                float2 _5123 = float2(cbFI_DisplaySize);
                float4 _10768;
                if (!(length(((_5093 + _10676) - float2(_5092.x ? _10100.x : _10098.x, _5092.y ? _10100.y : _10098.y)) * _5123) <= ((0.100000001490116119384765625f * length(_10676 * _5123)) + 8.0f)))
                {
                    float4 _10769;
                    if (_4819)
                    {
                        float4 _9999 = _10682;
                        _9999.x = 0.0f;
                        _10769 = _9999;
                    }
                    else
                    {
                        float4 _10001 = _10682;
                        _10001.y = 0.0f;
                        _10769 = _10001;
                    }
                    _10768 = _10769;
                }
                else
                {
                    _10768 = _10682;
                }
                _10767 = _10768;
            }
            else
            {
                _10767 = _10682;
            }
            float4 _5148 = _10440 * _10767;
            float _5150 = dot(_5148, 1.0f.xxxx);
            float4 _10987;
            bool _11007;
            if (_5150 > 0.0f)
            {
                _11007 = _10251;
                _10987 = _5148 / _5150.xxxx;
            }
            else
            {
                bool _5161 = any(bool4(_10767.x < 1.0f.xxxx.x, _10767.y < 1.0f.xxxx.y, _10767.z < 1.0f.xxxx.z, _10767.w < 1.0f.xxxx.w));
                if (_5161)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9022;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9022);
                    }
                }
                bool4 _12057 = _5161.xxxx;
                _11007 = _5161 ? true : _10251;
                _10987 = float4(_12057.x ? 0.0f.xxxx.x : _10440.x, _12057.y ? 0.0f.xxxx.y : _10440.y, _12057.z ? 0.0f.xxxx.z : _10440.z, _12057.w ? 0.0f.xxxx.w : _10440.w);
            }
            _11120 = _11199;
            _11006 = _11007;
            _10986 = _10987;
        }
        else
        {
            _11120 = float3(0.0f, 0.0f, 0.5f);
            _11006 = _10251;
            _10986 = _10440;
        }
        uint _5170 = (cbFI_pad0 >> 24u) & 31u;
        uint _5174 = (cbFI_pad0 >> 16u) & 255u;
        bool _5176 = _5170 != 0u;
        bool _5178 = _5174 == 12u;
        bool _5181 = _5174 == 13u;
        float4 _11003;
        if ((_5176 || _5178) || _5181)
        {
            float _10770;
            do
            {
                bool _9106 = all(bool2(_10101.x > 0.0f.xx.x, _10101.y > 0.0f.xx.y));
                bool _9112;
                if (_9106)
                {
                    _9112 = all(bool2(_10101.x < 1.0f.xx.x, _10101.y < 1.0f.xx.y));
                }
                else
                {
                    _9112 = _9106;
                }
                bool _9043 = !_9112;
                bool _9050;
                if (!_9043)
                {
                    bool _9117 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
                    bool _9123;
                    if (_9117)
                    {
                        _9123 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9123 = _9117;
                    }
                    _9050 = !_9123;
                }
                else
                {
                    _9050 = _9043;
                }
                if (_9050)
                {
                    _10770 = 0.0f;
                    break;
                }
                uint _9130_dummy_parameter;
                uint _9146_dummy_parameter;
                float4 _9071 = mul(float4((float2(_10101.x, 1.0f - _10101.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10101 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9130_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9073 = _9071.w;
                if (abs(_9073) < 9.9999999747524270787835121154785e-07f)
                {
                    _10770 = 0.0f;
                    break;
                }
                float _9084 = abs(cbFI_DeviceToViewDepth.y / ((_9071.z / _9073) - cbFI_DeviceToViewDepth.x));
                float _9087 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9146_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10770 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9084 - _9087) / max(max(_9084, _9087), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9194 = all(bool2(_10102.x > 0.0f.xx.x, _10102.y > 0.0f.xx.y));
            bool _9200;
            if (_9194)
            {
                _9200 = all(bool2(_10102.x < 1.0f.xx.x, _10102.y < 1.0f.xx.y));
            }
            else
            {
                _9200 = _9194;
            }
            float _10771;
            if (_9200)
            {
                uint _9207_dummy_parameter;
                _10771 = length((_5981 + (r_motion_tp1.Load(int3(int2(floor(_10102 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9207_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10771 = 1000000.0f;
            }
            float _10782;
            if ((_5170 & 1u) != 0u)
            {
                _10782 = _10770;
            }
            else
            {
                _10782 = 1.0f;
            }
            float _10783;
            if ((_5170 & 2u) != 0u)
            {
                _10783 = _10782 * (1.0f - smoothstep(2.0f, 8.0f, _10771));
            }
            else
            {
                _10783 = _10782;
            }
            float _10784;
            if ((_5170 & 4u) != 0u)
            {
                _10784 = _10783 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6702 - _6710) - length(_6686 - _6694))));
            }
            else
            {
                _10784 = _10783;
            }
            float _10997;
            if ((_5170 & 8u) != 0u)
            {
                _10997 = lerp(1.0f, _10784, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6686 - _6694)));
            }
            else
            {
                _10997 = _10784;
            }
            bool _5256 = (_5170 & 16u) != 0u;
            bool _5265;
            if (_5256)
            {
                _5265 = length(_10096 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5265 = _5256;
            }
            float _12059 = _5265 ? 1.0f : _10997;
            bool _5271 = _5176 && _6895;
            bool _5276;
            if (_5271)
            {
                bool _9232 = all(bool2(_10098.x > 0.0f.xx.x, _10098.y > 0.0f.xx.y));
                bool _9238;
                if (_9232)
                {
                    _9238 = all(bool2(_10098.x < 1.0f.xx.x, _10098.y < 1.0f.xx.y));
                }
                else
                {
                    _9238 = _9232;
                }
                _5276 = _9238;
            }
            else
            {
                _5276 = _5271;
            }
            bool _5281;
            if (_5276)
            {
                bool _9243 = all(bool2(_10100.x > 0.0f.xx.x, _10100.y > 0.0f.xx.y));
                bool _9249;
                if (_9243)
                {
                    _9249 = all(bool2(_10100.x < 1.0f.xx.x, _10100.y < 1.0f.xx.y));
                }
                else
                {
                    _9249 = _9243;
                }
                _5281 = _9249;
            }
            else
            {
                _5281 = _5276;
            }
            float4 _11004;
            if (_5281)
            {
                float _5287 = _10986.x + _10986.y;
                float _5296 = (_10986.z + _10986.w) * (1.0f - _12059);
                float _11000;
                if (_5287 > 9.9999997473787516355514526367188e-06f)
                {
                    _11000 = _10986.x / _5287;
                }
                else
                {
                    _11000 = _4252;
                }
                _11004 = float4(_10986.x + (_5296 * _11000), _10986.y + (_5296 * (1.0f - _11000)), _10986.zw * _12059);
            }
            else
            {
                _11004 = _10986;
            }
            _11003 = _11004;
        }
        else
        {
            _11003 = _10986;
        }
        float3 _11827;
        if (_11006)
        {
            float3 _9255 = r_current_interpolation_source.Load(int3(_3627, 0)).xyz;
            float3 _11828;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6895)
            {
                uint _9262_dummy_parameter;
                float _11111;
                _11111 = r_depth_tm1.Load(int3(int2(floor(_10098 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9262_dummy_parameter))))), 0)).x;
                float _5408;
                for (int _11110 = 0; _11110 < 24; _11111 = _5408, _11110++)
                {
                    float _5380 = float(_11110 & 7) * 0.785398185253143310546875f;
                    int _5382 = _11110 >> 3;
                    int _11878;
                    if (_5382 == 0)
                    {
                        _11878 = 16;
                    }
                    else
                    {
                        _11878 = (_5382 == 1) ? 48 : 96;
                    }
                    uint _9282_dummy_parameter;
                    _5408 = max(_11111, r_depth_tm1.Load(int3(int2(floor(clamp(_10098 + ((cbFI_MvDepthLaneSizeRcp * float(_11878)) * float2(cos(_5380), sin(_5380))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9282_dummy_parameter))))), 0)).x);
                }
                float2 _11112;
                do
                {
                    float _9304 = 1.0f - _10098.y;
                    float4 _9315 = mul(float4((float2(_10098.x, _9304) * 2.0f) - 1.0f.xx, _11111, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9317 = _9315.w;
                    if (!(_9317 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11112 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9330 = ((_9315.xy / _9317.xx) + 1.0f.xx) * 0.5f;
                    _11112 = float2(_9330.x - _10098.x, _9304 - _9330.y);
                    break;
                } while(false);
                float2 _5419 = _10098 + _11112;
                bool _9348 = all(bool2(_5419.x > 0.0f.xx.x, _5419.y > 0.0f.xx.y));
                bool _9354;
                if (_9348)
                {
                    _9354 = all(bool2(_5419.x < 1.0f.xx.x, _5419.y < 1.0f.xx.y));
                }
                else
                {
                    _9354 = _9348;
                }
                float3 _11829;
                if (_9354)
                {
                    float _5425 = abs(cbFI_DeviceToViewDepth.y / (_11111 - cbFI_DeviceToViewDepth.x));
                    uint _9374_dummy_parameter;
                    int2 _9374 = int2(spvTextureSize(r_depth_m2, uint(0), _9374_dummy_parameter));
                    float _5429 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5419 * float2(_9374))), int2(0, 0), _9374 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11834;
                    if (abs(_5429 - _5425) <= (0.20000000298023223876953125f * max(_5429, _5425)))
                    {
                        uint _9408_dummy_parameter;
                        int2 _9408 = int2(spvTextureSize(r_colour_m2, uint(0), _9408_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9431;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9431);
                        }
                        _11834 = r_colour_m2.Load(int3(clamp(int2(floor(_5419 * float2(_9408))), int2(0, 0), _9408 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9441;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9441);
                        }
                        _11834 = _9255;
                    }
                    _11829 = _11834;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9451;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9451);
                    }
                    _11829 = _9255;
                }
                _11828 = _11829;
            }
            else
            {
                _11828 = _9255;
            }
            _11827 = _11828;
        }
        else
        {
            _11827 = (((_6686 * _11003.x) + (_6694 * _11003.y)) + (_6702 * _11003.z)) + (_6710 * _11003.w);
        }
        uint _5457 = cbFI_pad0 & 255u;
        bool _11719;
        float3 _11826;
        if (_5457 != 0u)
        {
            float3 _5462 = r_present_backbuffer.Load(int3(_3627, 0)).xyz;
            float3 _5466 = r_current_interpolation_source.Load(int3(_3627, 0)).xyz;
            float3 _5470 = abs(_5462 - _5466);
            float3 _11115;
            if (_5457 == 2u)
            {
                _11115 = (abs(_5466) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11115 = 0.000244140625f.xxx;
            }
            bool _5486 = any(bool3(_5470.x > _11115.x, _5470.y > _11115.y, _5470.z > _11115.z));
            bool3 _12060 = _5486.xxx;
            _11826 = float3(_12060.x ? _5462.x : _11827.x, _12060.y ? _5462.y : _11827.y, _12060.z ? _5462.z : _11827.z);
            _11719 = _5486;
        }
        else
        {
            _11826 = _11827;
            _11719 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9466;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9466);
        }
        float3 _11809;
        if (_5174 == 1u)
        {
            _11809 = lerp(_6686, _6694, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11810;
            if (_5174 == 2u)
            {
                _11810 = lerp(_6702, _6710, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11811;
                if (_5174 == 3u)
                {
                    _11811 = float(_11719).xxx;
                }
                else
                {
                    float3 _11812;
                    if (_5174 == 4u)
                    {
                        _11812 = float3(((_10096 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11813;
                        if (_5174 == 5u)
                        {
                            _11813 = float3(((_5981 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11814;
                            if (_5174 == 6u)
                            {
                                _11814 = float3(_11003.xy, _11003.z + _11003.w);
                            }
                            else
                            {
                                float3 _11815;
                                if (_5174 == 7u)
                                {
                                    _11815 = r_current_interpolation_source.Load(int3(_3627, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11816;
                                    if (_5174 == 8u)
                                    {
                                        _11816 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4027, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11817;
                                        if (_5178)
                                        {
                                            uint _9488_dummy_parameter;
                                            uint _9520_dummy_parameter;
                                            _11817 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4027 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9488_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4027 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9520_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11818;
                                            if (_5181)
                                            {
                                                _11818 = _6702;
                                            }
                                            else
                                            {
                                                float3 _11819;
                                                if (_5174 == 20u)
                                                {
                                                    _11819 = _6686;
                                                }
                                                else
                                                {
                                                    float3 _11820;
                                                    if (_5174 == 21u)
                                                    {
                                                        _11820 = _6694;
                                                    }
                                                    else
                                                    {
                                                        float3 _11821;
                                                        if (_5174 == 22u)
                                                        {
                                                            _11821 = _6710;
                                                        }
                                                        else
                                                        {
                                                            float3 _11822;
                                                            if (_5174 == 18u)
                                                            {
                                                                _11822 = _11487;
                                                            }
                                                            else
                                                            {
                                                                float3 _11823;
                                                                if (_5174 == 19u)
                                                                {
                                                                    _11823 = _11301;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12062 = (_5174 == 23u).xxx;
                                                                    _11823 = float3(_12062.x ? _11120.x : _11826.x, _12062.y ? _11120.y : _11826.y, _12062.z ? _11120.z : _11826.z);
                                                                }
                                                                _11822 = _11823;
                                                            }
                                                            _11821 = _11822;
                                                        }
                                                        _11820 = _11821;
                                                    }
                                                    _11819 = _11820;
                                                }
                                                _11818 = _11819;
                                            }
                                            _11817 = _11818;
                                        }
                                        _11816 = _11817;
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
        float3 _11808;
        if ((_5174 >= 9u) && (_5174 <= 11u))
        {
            uint _5650 = 64u + uint((_10128.y * cbFI_MvDepthLaneSize.x) + _10128.x);
            uint _5654 = rw_nfru_diagnostics.Load<uint>(_5650 * 4 + 0) & 15u;
            float3 _11839;
            if (_5174 == 10u)
            {
                float3 _11807;
                if ((rw_nfru_diagnostics.Load<uint>(_5650 * 4 + 0) & 32u) != 0u)
                {
                    _11807 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11806;
                    if ((rw_nfru_diagnostics.Load<uint>(_5650 * 4 + 0) & 16u) != 0u)
                    {
                        _11806 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5675 = ((rw_nfru_diagnostics.Load<uint>(_5650 * 4 + 0) & 64u) != 0u).xxx;
                        _11806 = float3(_5675.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5675.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5675.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11807 = _11806;
                }
                _11839 = _11807;
            }
            else
            {
                float3 _11840;
                if (_5174 == 11u)
                {
                    uint _5688 = (rw_nfru_diagnostics.Load<uint>(_5650 * 4 + 0) >> 8u) & 15u;
                    uint _5691 = (rw_nfru_diagnostics.Load<uint>(_5650 * 4 + 0) >> 12u) & 15u;
                    float3 _11799;
                    if ((_5654 == 2u) || (_5654 == 3u))
                    {
                        _11799 = _3323[_5654];
                    }
                    else
                    {
                        bool _5703 = _5688 == 3u;
                        bool _5705 = _5691 == 3u;
                        float3 _11800;
                        if (_5703 && _5705)
                        {
                            _11800 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11801;
                            if (_5703)
                            {
                                _11801 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11802;
                                if (_5705)
                                {
                                    _11802 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11803;
                                    if ((_5688 == 4u) || (_5691 == 4u))
                                    {
                                        _11803 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11804;
                                        if ((_5688 == 1u) || (_5691 == 1u))
                                        {
                                            _11804 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12064 = (_5654 == 1u).xxx;
                                            _11804 = float3(_12064.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12064.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12064.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11803 = _11804;
                                    }
                                    _11802 = _11803;
                                }
                                _11801 = _11802;
                            }
                            _11800 = _11801;
                        }
                        _11799 = _11800;
                    }
                    _11840 = _11799;
                }
                else
                {
                    _11840 = _3323[min(_5654, 7u)];
                }
                _11839 = _11840;
            }
            _11808 = _11839;
        }
        else
        {
            _11808 = _11809;
        }
        float4 _11843;
        if ((_5174 >= 14u) && (_5174 <= 16u))
        {
            float2 _11841;
            if (_5174 == 14u)
            {
                uint _5761_dummy_parameter;
                uint _5767_dummy_parameter;
                _11841 = r_flow_tm1.Load(int3(clamp(int2(floor(_4027 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5761_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5767_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11842;
                if (_5174 == 16u)
                {
                    uint _9571 = r_warped_flow_qdata_tm1.Load(int3(_4043, 0)).x & 2147483647u;
                    uint _9603 = uint(max((int((_9571 >> 16u) & 15u) - 6), 0));
                    _11842 = ((float2(float((1 - (2 * int((_9571 >> 15u) & 1u))) * int(((_9571 >> uint(7)) & 127u) << _9603)), float((1 - (2 * int((_9571 >> 14u) & 1u))) * int((_9571 & 127u) << _9603))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11842 = _5981 * float2(cbFI_DisplaySize);
                }
                _11841 = _11842;
            }
            uint2 _5800 = uint2(clamp(round(_11841 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5802 = _5800.x;
            uint _5809 = _5800.y;
            _11843 = float4(float(_5802 & 255u), float((_5802 >> 8u) | ((_5809 & 15u) << 4u)), float(_5809 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11844;
            if (_5174 == 17u)
            {
                _11844 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4043, 0)).x != 0u), _4386, 0.0f, 1.0f);
            }
            else
            {
                _11844 = float4(_11808, 1.0f);
            }
            _11843 = _11844;
        }
        rw_output[_3627] = _11843.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5853 = ((uint(_3627.y) * uint(cbFI_DisplaySize.x)) + uint(_3627.x)) * 6u;
            uint _9649 = spvPackHalf2x16(clamp(_6685.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5853 * 4 + 0, (((_9649 & 32767u) >> 4u) | ((((_9649 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6685.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9684 = spvPackHalf2x16(clamp(_6693.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5853 + 1u) * 4 + 0, (((_9684 & 32767u) >> 4u) | ((((_9684 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6693.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9719 = spvPackHalf2x16(clamp(_6701.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5853 + 2u) * 4 + 0, (((_9719 & 32767u) >> 4u) | ((((_9719 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6701.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9754 = spvPackHalf2x16(clamp(_6709.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5853 + 3u) * 4 + 0, (((_9754 & 32767u) >> 4u) | ((((_9754 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6709.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9781 = r_current_interpolation_source.Load(int3(_3627, 0));
            uint _9795 = spvPackHalf2x16(clamp(_9781.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5853 + 4u) * 4 + 0, (((_9795 & 32767u) >> 4u) | ((((_9795 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9781.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11877;
            if (_11719 || (_5174 != 0u))
            {
                _11877 = 4294967295u;
            }
            else
            {
                uint _9830 = spvPackHalf2x16(clamp(_11843.xy, 0.0f.xx, 65000.0f.xx));
                _11877 = (((_9830 & 32767u) >> 4u) | ((((_9830 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11843.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5853 + 5u) * 4 + 0, _11877);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3627] = float4(r_current_interpolation_source.Load(int3(_3627, 0)).xyz, 1.0f).xyz;
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
