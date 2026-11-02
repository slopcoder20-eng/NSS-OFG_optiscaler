static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3070[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3357 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3357.x >= cbFI_DisplaySize.x, _3357.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3357] = float4(r_present_backbuffer.Load(int3(_3357, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3718 = (float2(_3357) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3729 = int2(floor(_3718 * float2(cbFI_MvDepthLaneSize)));
        int2 _3734 = int2(floor(_3718 * float2(cbFI_FlowLaneSize)));
        float4 _5440 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3718 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5446 = r_warped_filled_flow_tm1.Load(int3(_3734, 0)).xy;
        float2 _5452 = r_warped_filled_motion_tp1.Load(int3(_3729, 0)).xy;
        bool _5474 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8992;
        if (_5474)
        {
            float _5487 = ((2.0f * _3718.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8992 = float2(atan(_5487) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3718.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5487 * _5487))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8992 = _3718;
        }
        bool _3755 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9013;
        bool _9034;
        int2 _9045;
        float3 _10090;
        if (_3755)
        {
            float _8994;
            float _8996;
            _8996 = 2.0f;
            _8994 = -1.0f;
            uint _3419[9];
            float _10480;
            float _10483;
            for (int _8993 = 0; _8993 < 9; _8996 = _10483, _8994 = _10480, _8993++)
            {
                _3419[_8993] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3729 + int2((_8993 % 3) - 1, (_8993 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3419[_8993] != 0u)
                {
                    float _10475;
                    if (_3419[_8993] == 0u)
                    {
                        _10475 = -1.0f;
                    }
                    else
                    {
                        _10475 = float((_3419[_8993] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10483 = min(_8996, _10475);
                    _10480 = max(_8994, _10475);
                }
                else
                {
                    _10483 = _8996;
                    _10480 = _8994;
                }
            }
            float _3801 = float(_8994 >= 0.0f);
            float3 _8803 = 0.0f.xxx;
            _8803.y = _3801;
            float2 _9014;
            bool _9035;
            int2 _9046;
            float3 _10091;
            if ((_8994 - _8996) > 0.0199999995529651641845703125f)
            {
                float _9002;
                int2 _9003;
                float2 _9004;
                int2 _9006;
                float2 _9012;
                _9012 = _5452;
                _9006 = _3729;
                _9004 = _5452;
                _9003 = _3729;
                _9002 = -1.0f;
                float _10488;
                int2 _10492;
                float2 _10503;
                int2 _10514;
                float2 _10547;
                float _10593;
                int _9001 = 0;
                float _10456 = 1000000000.0f;
                for (; _9001 < 9; _10456 = _10593, _9012 = _10547, _9006 = _10514, _9004 = _10503, _9003 = _10492, _9002 = _10488, _9001++)
                {
                    if (_3419[_9001] == 0u)
                    {
                        _10593 = _10456;
                        _10547 = _9012;
                        _10514 = _9006;
                        _10503 = _9004;
                        _10492 = _9003;
                        _10488 = _9002;
                        continue;
                    }
                    int2 _3836 = clamp(_3729 + int2((_9001 % 3) - 1, (_9001 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5562 = _3419[_9001] & 2147483647u;
                    uint _5594 = uint(max((int((_5562 >> 16u) & 15u) - 6), 0));
                    float2 _3842 = (float2(float((1 - (2 * int((_5562 >> 15u) & 1u))) * int(((_5562 >> uint(7)) & 127u) << _5594)), float((1 - (2 * int((_5562 >> 14u) & 1u))) * int((_5562 & 127u) << _5594))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10442;
                    if (_3419[_9001] == 0u)
                    {
                        _10442 = -1.0f;
                    }
                    else
                    {
                        _10442 = float((_3419[_9001] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3847 = _10442 - 0.100000001490116119384765625f;
                    float2 _10443;
                    if (_5474)
                    {
                        float2 _5671 = clamp((((_8992 + (_3842 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5674 = tan(_5671.x);
                        _10443 = (float2(_5674 / cbFI_DeviceToViewDepth.z, (tan(_5671.y) * sqrt(1.0f + (_5674 * _5674))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10443 = _8992 + (_3842 * cbFI_Timestep);
                    }
                    float _3854 = cbFI_Timestep - 1.0f;
                    float2 _10444;
                    if (_5474)
                    {
                        float2 _5742 = clamp((((_8992 + (_3842 * _3854)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5745 = tan(_5742.x);
                        _10444 = (float2(_5745 / cbFI_DeviceToViewDepth.z, (tan(_5742.y) * sqrt(1.0f + (_5745 * _5745))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10444 = _8992 + (_3842 * _3854);
                    }
                    bool _5778 = all(bool2(_10443.x > 0.0f.xx.x, _10443.y > 0.0f.xx.y));
                    bool _5784;
                    if (_5778)
                    {
                        _5784 = all(bool2(_10443.x < 1.0f.xx.x, _10443.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5784 = _5778;
                    }
                    float _10447;
                    if (_5784)
                    {
                        uint _5791_dummy_parameter;
                        _10447 = max((_3847 - (log((r_depth_tm1.Load(int3(int2(floor(_10443 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5791_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10447 = 0.0f;
                    }
                    bool _5821 = all(bool2(_10444.x > 0.0f.xx.x, _10444.y > 0.0f.xx.y));
                    bool _5827;
                    if (_5821)
                    {
                        _5827 = all(bool2(_10444.x < 1.0f.xx.x, _10444.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5827 = _5821;
                    }
                    float _10448;
                    if (_5827)
                    {
                        uint _5834_dummy_parameter;
                        _10448 = _10447 + max((_3847 - (log((r_depth_tp1.Load(int3(int2(floor(_10444 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5834_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10448 = _10447;
                    }
                    float _10489;
                    int2 _10493;
                    float2 _10504;
                    int2 _10515;
                    float2 _10548;
                    float _10594;
                    if (_10448 == 0.0f)
                    {
                        bool _3889 = _3847 > _9002;
                        bool2 _10602 = _3889.xx;
                        _10594 = _10456;
                        _10548 = float2(_10602.x ? _3842.x : _9012.x, _10602.y ? _3842.y : _9012.y);
                        _10515 = int2(_10602.x ? _3836.x : _9006.x, _10602.y ? _3836.y : _9006.y);
                        _10504 = _9004;
                        _10493 = _9003;
                        _10489 = _3889 ? _3847 : _9002;
                    }
                    else
                    {
                        bool _3898 = _10448 < _10456;
                        bool2 _10598 = _3898.xx;
                        _10594 = _3898 ? _10448 : _10456;
                        _10548 = _9012;
                        _10515 = _9006;
                        _10504 = float2(_10598.x ? _3842.x : _9004.x, _10598.y ? _3842.y : _9004.y);
                        _10493 = int2(_10598.x ? _3836.x : _9003.x, _10598.y ? _3836.y : _9003.y);
                        _10489 = _9002;
                    }
                    _10593 = _10594;
                    _10547 = _10548;
                    _10514 = _10515;
                    _10503 = _10504;
                    _10492 = _10493;
                    _10488 = _10489;
                }
                bool _3910 = _9002 < 0.0f;
                bool2 _10608 = _3910.xx;
                int2 _10611 = int2(_10608.x ? _9003.x : _9006.x, _10608.y ? _9003.y : _9006.y);
                _10091 = float3(1.0f, _3801, float(any(bool2(_10611.x != _3729.x, _10611.y != _3729.y))));
                _9046 = _10611;
                _9035 = _3910 ? false : true;
                _9014 = float2(_10608.x ? _9004.x : _9012.x, _10608.y ? _9004.y : _9012.y);
            }
            else
            {
                _10091 = _8803;
                _9046 = _3729;
                _9035 = false;
                _9014 = _5452;
            }
            _10090 = _10091;
            _9045 = _9046;
            _9034 = _9035;
            _9013 = _9014;
        }
        else
        {
            _10090 = 0.0f.xxx;
            _9045 = _3729;
            _9034 = false;
            _9013 = _5452;
        }
        float2 _9015;
        if (_5474)
        {
            float2 _5899 = clamp((((_8992 + (_9013 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5902 = tan(_5899.x);
            _9015 = (float2(_5902 / cbFI_DeviceToViewDepth.z, (tan(_5899.y) * sqrt(1.0f + (_5902 * _5902))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9015 = _8992 + (_9013 * cbFI_Timestep);
        }
        float _3933 = cbFI_Timestep - 1.0f;
        float2 _9017;
        if (_5474)
        {
            float2 _5970 = clamp((((_8992 + (_9013 * _3933)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5973 = tan(_5970.x);
            _9017 = (float2(_5973 / cbFI_DeviceToViewDepth.z, (tan(_5970.y) * sqrt(1.0f + (_5973 * _5973))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9017 = _8992 + (_9013 * _3933);
        }
        float _3938 = -cbFI_Timestep;
        float2 _9018;
        if (_5474)
        {
            float2 _6041 = clamp((((_8992 + (_5446 * _3938)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6044 = tan(_6041.x);
            _9018 = (float2(_6044 / cbFI_DeviceToViewDepth.z, (tan(_6041.y) * sqrt(1.0f + (_6044 * _6044))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9018 = _8992 + (_5446 * _3938);
        }
        float _3943 = 1.0f - cbFI_Timestep;
        float2 _9019;
        if (_5474)
        {
            float2 _6112 = clamp((((_8992 + (_5446 * _3943)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6115 = tan(_6112.x);
            _9019 = (float2(_6115 / cbFI_DeviceToViewDepth.z, (tan(_6112.y) * sqrt(1.0f + (_6115 * _6115))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9019 = _8992 + (_5446 * _3943);
        }
        float4 _6150 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9015, 0.0f);
        float3 _6151 = _6150.xyz;
        float4 _6158 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9017, 0.0f);
        float3 _6159 = _6158.xyz;
        float4 _6166 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9018, 0.0f);
        float3 _6167 = _6166.xyz;
        float4 _6174 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9019, 0.0f);
        float3 _6175 = _6174.xyz;
        float4 _6189 = exp(_5440 - max(max(max(_5440.x, _5440.y), _5440.z), _5440.w).xxxx);
        float4 _6196 = _6189 / (dot(_6189, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3962 = _3755 && (!_9034);
        bool _3971;
        if (_3962)
        {
            _3971 = (_6196.z + _6196.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3971 = _3962;
        }
        bool _3982;
        if (_3971)
        {
            _3982 = length((_9018 - _9015) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3982 = _3971;
        }
        bool _9058;
        if (_3982)
        {
            uint4 _6215 = r_warped_motion_qdata_tp1.Load(int3(_9045, 0));
            uint _6216 = _6215.x;
            bool _9061;
            if (_6216 != 0u)
            {
                float _9047;
                if (_6216 == 0u)
                {
                    _9047 = -1.0f;
                }
                else
                {
                    _9047 = float((_6216 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3992 = _9047 - 0.12000000476837158203125f;
                bool _6235 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
                bool _6241;
                if (_6235)
                {
                    _6241 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
                }
                else
                {
                    _6241 = _6235;
                }
                bool _4002;
                if (_6241)
                {
                    uint _6248_dummy_parameter;
                    _4002 = (log((r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6248_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3992;
                }
                else
                {
                    _4002 = _6241;
                }
                bool _4016;
                if (!_4002)
                {
                    bool _6278 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
                    bool _6284;
                    if (_6278)
                    {
                        _6284 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6284 = _6278;
                    }
                    bool _4014;
                    if (_6284)
                    {
                        uint _6291_dummy_parameter;
                        _4014 = (log((r_depth_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6291_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3992;
                    }
                    else
                    {
                        _4014 = _6284;
                    }
                    _4016 = _4014;
                }
                else
                {
                    _4016 = _4002;
                }
                _9061 = _4016;
            }
            else
            {
                _9061 = false;
            }
            _9058 = _9061;
        }
        else
        {
            _9058 = false;
        }
        bool _4021 = _9034 || _9058;
        bool _4026;
        if (_4021)
        {
            bool _6321 = all(bool2(_9015.x > 0.0f.xx.x, _9015.y > 0.0f.xx.y));
            bool _6327;
            if (_6321)
            {
                _6327 = all(bool2(_9015.x < 1.0f.xx.x, _9015.y < 1.0f.xx.y));
            }
            else
            {
                _6327 = _6321;
            }
            _4026 = _6327;
        }
        else
        {
            _4026 = _4021;
        }
        bool _4031;
        if (_4026)
        {
            bool _6332 = all(bool2(_9017.x > 0.0f.xx.x, _9017.y > 0.0f.xx.y));
            bool _6338;
            if (_6332)
            {
                _6338 = all(bool2(_9017.x < 1.0f.xx.x, _9017.y < 1.0f.xx.y));
            }
            else
            {
                _6338 = _6332;
            }
            _4031 = _6338;
        }
        else
        {
            _4031 = _4026;
        }
        float4 _9152;
        if (_4031)
        {
            float _4034 = _6196.x;
            float _4036 = _6196.y;
            float _4037 = _4034 + _4036;
            float _4042 = _6196.z + _6196.w;
            float _9076;
            if (_4037 > 0.001000000047497451305389404296875f)
            {
                _9076 = _4034 / _4037;
            }
            else
            {
                _9076 = _3943;
            }
            _9152 = float4(_4034 + (_4042 * _9076), _4036 + (_4042 * (1.0f - _9076)), 0.0f, 0.0f);
        }
        else
        {
            _9152 = _6196;
        }
        bool _6366 = (cbFI_pad0 & 1024u) != 0u;
        bool _6342 = !_6366;
        bool _6343 = !_6342;
        bool _6360;
        if (_6343)
        {
            _6360 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9045.y * cbFI_MvDepthLaneSize.x) + _9045.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6360 = _6342;
        }
        bool _6392;
        if (_6343)
        {
            _6392 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3734.y * cbFI_FlowLaneSize.x) + _3734.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6392 = _6342;
        }
        float _4077 = float(_6392);
        bool _9164;
        float4 _9194;
        float3 _9947;
        if (_6366)
        {
            bool _4087;
            if (_6360)
            {
                _4087 = all(bool2(_9015.x > 0.0f.xx.x, _9015.y > 0.0f.xx.y));
            }
            else
            {
                _4087 = _6360;
            }
            bool _4093;
            if (_4087)
            {
                _4093 = all(bool2(_9015.x < 1.0f.xx.x, _9015.y < 1.0f.xx.y));
            }
            else
            {
                _4093 = _4087;
            }
            bool _4100;
            if (_6360)
            {
                _4100 = all(bool2(_9017.x > 0.0f.xx.x, _9017.y > 0.0f.xx.y));
            }
            else
            {
                _4100 = _6360;
            }
            bool _4106;
            if (_4100)
            {
                _4106 = all(bool2(_9017.x < 1.0f.xx.x, _9017.y < 1.0f.xx.y));
            }
            else
            {
                _4106 = _4100;
            }
            bool _4113;
            if (_6392)
            {
                _4113 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
            }
            else
            {
                _4113 = _6392;
            }
            bool _4119;
            if (_4113)
            {
                _4119 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
            }
            else
            {
                _4119 = _4113;
            }
            bool _4126;
            if (_6392)
            {
                _4126 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
            }
            else
            {
                _4126 = _6392;
            }
            bool _4132;
            if (_4126)
            {
                _4132 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
            }
            else
            {
                _4132 = _4126;
            }
            bool _4134 = !_6360;
            if (_4134)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6434;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6434);
                }
            }
            bool _4139 = !_6392;
            if (_4139)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6444;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6444);
                }
            }
            if (_6360 && _4139)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6454;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6454);
                }
            }
            if (_4134 && _6392)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6464;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6464);
                }
            }
            float _4158 = float(_4093);
            float _4160 = float(_4106);
            bool _4163 = _4119 && _4132;
            float _9110;
            if (_4163)
            {
                _9110 = 1.0f;
            }
            else
            {
                _9110 = (_4119 || _4132) ? 0.5f : 0.0f;
            }
            bool _9115;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4093)) && (!_4106))
            {
                bool _4193;
                if (_4163)
                {
                    float _9113;
                    do
                    {
                        bool _6548 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
                        bool _6554;
                        if (_6548)
                        {
                            _6554 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6554 = _6548;
                        }
                        bool _6485 = !_6554;
                        bool _6492;
                        if (!_6485)
                        {
                            bool _6559 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
                            bool _6565;
                            if (_6559)
                            {
                                _6565 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6565 = _6559;
                            }
                            _6492 = !_6565;
                        }
                        else
                        {
                            _6492 = _6485;
                        }
                        if (_6492)
                        {
                            _9113 = 0.0f;
                            break;
                        }
                        uint _6572_dummy_parameter;
                        uint _6588_dummy_parameter;
                        float4 _6513 = mul(float4((float2(_9018.x, 1.0f - _9018.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6572_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6515 = _6513.w;
                        if (abs(_6515) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9113 = 0.0f;
                            break;
                        }
                        float _6526 = abs(cbFI_DeviceToViewDepth.y / ((_6513.z / _6515) - cbFI_DeviceToViewDepth.x));
                        float _6529 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6588_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9113 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6526 - _6529) / max(max(_6526, _6529), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4193 = _9113 >= 0.5f;
                }
                else
                {
                    _4193 = _4163;
                }
                bool _9116;
                if (_4193)
                {
                    uint _6638_dummy_parameter;
                    float2 _9114;
                    do
                    {
                        float _6664 = 1.0f - _9018.y;
                        float4 _6675 = mul(float4((float2(_9018.x, _6664) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6638_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6677 = _6675.w;
                        if (!(_6677 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9114 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6690 = ((_6675.xy / _6677.xx) + 1.0f.xx) * 0.5f;
                        _9114 = float2(_6690.x - _9018.x, _6664 - _6690.y);
                        break;
                    } while(false);
                    float2 _4207 = float2(cbFI_DisplaySize);
                    _9116 = length(((_9018 + _9114) - _9019) * _4207) <= ((0.100000001490116119384765625f * length(_9114 * _4207)) + 8.0f);
                }
                else
                {
                    _9116 = _4193;
                }
                _9115 = _9116;
            }
            else
            {
                _9115 = true;
            }
            bool _4221 = !_9115;
            bool _10612 = _4221 ? false : _4132;
            bool _10613 = _4221 ? false : _4119;
            bool _9165;
            float4 _9195;
            if (!(((_4093 && _4106) && _10613) && _10612))
            {
                float4 _4243 = _9152 * float4(_4158, _4160, float(_10613), float(_10612));
                float _4245 = dot(_4243, 1.0f.xxxx);
                bool _4248 = !(_4245 > 0.0f);
                float4 _9196;
                if (!_4248)
                {
                    _9196 = _4243 / _4245.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6712;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6712);
                    }
                    _9196 = 0.0f.xxxx;
                }
                _9195 = _9196;
                _9165 = _4248;
            }
            else
            {
                _9195 = _9152;
                _9165 = false;
            }
            _9947 = float3(_4158, _4160, _9110);
            _9194 = _9195;
            _9164 = _9165;
        }
        else
        {
            _9947 = float3(float(_6360), _4077, 0.0f);
            _9194 = _9152;
            _9164 = false;
        }
        float4 _9678;
        bool _9698;
        float3 _9810;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9164))
        {
            bool _4271 = _9194.x > 0.00999999977648258209228515625f;
            bool _4274 = _9194.y > 0.00999999977648258209228515625f;
            bool _4283 = (_9194.z + _9194.w) > 0.0199999995529651641845703125f;
            bool _4289;
            if (_4283)
            {
                bool _6718 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
                bool _6724;
                if (_6718)
                {
                    _6724 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
                }
                else
                {
                    _6724 = _6718;
                }
                _4289 = _6724;
            }
            else
            {
                _4289 = _4283;
            }
            bool _4294;
            if (_4289)
            {
                bool _6729 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
                bool _6735;
                if (_6729)
                {
                    _6735 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
                }
                else
                {
                    _6735 = _6729;
                }
                _4294 = _6735;
            }
            else
            {
                _4294 = _4289;
            }
            bool _4301;
            if (_4294)
            {
                float _9198;
                do
                {
                    bool _6818 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
                    bool _6824;
                    if (_6818)
                    {
                        _6824 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6824 = _6818;
                    }
                    bool _6755 = !_6824;
                    bool _6762;
                    if (!_6755)
                    {
                        bool _6829 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
                        bool _6835;
                        if (_6829)
                        {
                            _6835 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6835 = _6829;
                        }
                        _6762 = !_6835;
                    }
                    else
                    {
                        _6762 = _6755;
                    }
                    if (_6762)
                    {
                        _9198 = 0.0f;
                        break;
                    }
                    uint _6842_dummy_parameter;
                    uint _6858_dummy_parameter;
                    float4 _6783 = mul(float4((float2(_9018.x, 1.0f - _9018.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6842_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6785 = _6783.w;
                    if (abs(_6785) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9198 = 0.0f;
                        break;
                    }
                    float _6796 = abs(cbFI_DeviceToViewDepth.y / ((_6783.z / _6785) - cbFI_DeviceToViewDepth.x));
                    float _6799 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6858_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9198 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6796 - _6799) / max(max(_6796, _6799), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4301 = _9198 < 0.5f;
            }
            else
            {
                _4301 = _4294;
            }
            float4 _9213;
            if (_4301)
            {
                uint _6908_dummy_parameter;
                uint _6939_dummy_parameter;
                float4 _9214;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6908_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6939_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9214 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9214 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9213 = _9214;
            }
            else
            {
                _9213 = 1.0f.xxxx;
            }
            bool _4325;
            if (_6360)
            {
                bool _6968 = all(bool2(_9015.x > 0.0f.xx.x, _9015.y > 0.0f.xx.y));
                bool _6974;
                if (_6968)
                {
                    _6974 = all(bool2(_9015.x < 1.0f.xx.x, _9015.y < 1.0f.xx.y));
                }
                else
                {
                    _6974 = _6968;
                }
                _4325 = _6974;
            }
            else
            {
                _4325 = _6360;
            }
            bool _4331;
            if (_6360)
            {
                bool _6979 = all(bool2(_9017.x > 0.0f.xx.x, _9017.y > 0.0f.xx.y));
                bool _6985;
                if (_6979)
                {
                    _6985 = all(bool2(_9017.x < 1.0f.xx.x, _9017.y < 1.0f.xx.y));
                }
                else
                {
                    _6985 = _6979;
                }
                _4331 = _6985;
            }
            else
            {
                _4331 = _6360;
            }
            bool _4337;
            if (_6392)
            {
                bool _6990 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
                bool _6996;
                if (_6990)
                {
                    _6996 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
                }
                else
                {
                    _6996 = _6990;
                }
                _4337 = _6996;
            }
            else
            {
                _4337 = _6392;
            }
            bool _4343;
            if (_6392)
            {
                bool _7001 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
                bool _7007;
                if (_7001)
                {
                    _7007 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
                }
                else
                {
                    _7007 = _7001;
                }
                _4343 = _7007;
            }
            else
            {
                _4343 = _6392;
            }
            bool _4346 = _4337 != _4343;
            bool _4352;
            if (_4346)
            {
                _4352 = _4325 || _4331;
            }
            else
            {
                _4352 = _4346;
            }
            float4 _9293;
            if (_4352)
            {
                float4 _8888 = _9213;
                _8888.z = 0.0f;
                _8888.w = 0.0f;
                _9293 = _8888;
            }
            else
            {
                _9293 = _9213;
            }
            bool _4359 = _4325 && _4271;
            bool _4362 = _4331 && _4274;
            float4 _9397;
            float3 _9847;
            if (_4359 || _4362)
            {
                float _9290;
                do
                {
                    uint4 _7146 = r_warped_motion_qdata_tp1.Load(int3(_9045, 0));
                    uint _7147 = _7146.x;
                    if (_7147 != 0u)
                    {
                        float _9289;
                        if (_7147 == 0u)
                        {
                            _9289 = -1.0f;
                        }
                        else
                        {
                            _9289 = float((_7147 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9290 = _9289;
                        break;
                    }
                    int _9272;
                    uint _9273;
                    _9273 = _7147;
                    _9272 = -1;
                    uint _9288;
                    for (; _9272 <= 1; _9273 = _9288, _9272++)
                    {
                        _9288 = _9273;
                        for (int _9286 = -1; _9286 <= 1; )
                        {
                            _9288 = max(_9288, r_warped_motion_qdata_tp1.Load(int3(clamp(_9045 + int2(_9286, _9272), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9286++;
                            continue;
                        }
                    }
                    if (_9273 != 0u)
                    {
                        float _9285;
                        if (_9273 == 0u)
                        {
                            _9285 = -1.0f;
                        }
                        else
                        {
                            _9285 = float((_9273 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9290 = _9285;
                        break;
                    }
                    uint _9275;
                    _9275 = 4294967295u;
                    uint _10584;
                    for (int _9274 = 0; _9274 < 8; _9275 = _10584, _9274++)
                    {
                        int _9278 = 0;
                        for (;;)
                        {
                            if (_9278 < 5)
                            {
                                int2 _7097 = _9045 + (_1085[_9274] * _1094[_9278].xx);
                                bool _7100 = any(bool2(_7097.x < int2(0, 0).x, _7097.y < int2(0, 0).y));
                                bool _7108;
                                if (!_7100)
                                {
                                    _7108 = any(bool2(_7097.x >= cbFI_MvDepthLaneSize.x, _7097.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7108 = _7100;
                                }
                                if (_7108)
                                {
                                    _10584 = _9275;
                                    break;
                                }
                                uint4 _7186 = r_warped_motion_qdata_tp1.Load(int3(_7097, 0));
                                uint _7187 = _7186.x;
                                if (_7187 != 0u)
                                {
                                    _10584 = min(_9275, _7187);
                                    break;
                                }
                                _9278++;
                                continue;
                            }
                            else
                            {
                                _10584 = _9275;
                                break;
                            }
                        }
                    }
                    float _9277;
                    if (_9275 == 4294967295u)
                    {
                        _9277 = -1.0f;
                    }
                    else
                    {
                        float _9276;
                        if (_9275 == 0u)
                        {
                            _9276 = -1.0f;
                        }
                        else
                        {
                            _9276 = float((_9275 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9277 = _9276;
                    }
                    _9290 = _9277;
                    break;
                } while(false);
                bool _4370 = _9290 < 0.0f;
                uint _7208_dummy_parameter;
                uint _7240_dummy_parameter;
                float4 _9326;
                if ((_4370 && _4359) && _4362)
                {
                    uint _7272_dummy_parameter;
                    float _7296 = log((r_depth_tm1.Load(int3(int2(floor(_9015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7272_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7304_dummy_parameter;
                    float _7328 = log((r_depth_tp1.Load(int3(int2(floor(_9017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7304_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9327;
                    if (_7296 > (_7328 + 0.07999999821186065673828125f))
                    {
                        float4 _8892 = _9293;
                        _8892.x = 0.0f;
                        _9327 = _8892;
                    }
                    else
                    {
                        float4 _9328;
                        if (_7328 > (_7296 + 0.07999999821186065673828125f))
                        {
                            float4 _8894 = _9293;
                            _8894.y = 0.0f;
                            _9328 = _8894;
                        }
                        else
                        {
                            _9328 = _9293;
                        }
                        _9327 = _9328;
                    }
                    _9326 = _9327;
                }
                else
                {
                    _9326 = _9293;
                }
                float _4412 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4414 = _9290 >= 0.0f;
                float _9309;
                if (_4414)
                {
                    _9309 = _9290 - _4412;
                }
                else
                {
                    float _9305;
                    if (_4359)
                    {
                        float _9304;
                        _9304 = 2.0f;
                        float _7386;
                        for (int _9303 = 0; _9303 < 24; _9304 = _7386, _9303++)
                        {
                            float _7350 = float(_9303 & 7) * 0.785398185253143310546875f;
                            int _7352 = _9303 >> 3;
                            int _9306;
                            if (_7352 == 0)
                            {
                                _9306 = 16;
                            }
                            else
                            {
                                _9306 = (_7352 == 1) ? 48 : 96;
                            }
                            uint _7402_dummy_parameter;
                            _7386 = min(_9304, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9015 + ((cbFI_MvDepthLaneSizeRcp * float(_9306)) * float2(cos(_7350), sin(_7350))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7402_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9305 = _9304;
                    }
                    else
                    {
                        _9305 = 0.0f;
                    }
                    _9309 = _9305;
                }
                float _9316;
                if (_4414)
                {
                    _9316 = _9290 - _4412;
                }
                else
                {
                    float _9312;
                    if (_4362)
                    {
                        float _9311;
                        _9311 = 2.0f;
                        float _7500;
                        for (int _9310 = 0; _9310 < 24; _9311 = _7500, _9310++)
                        {
                            float _7464 = float(_9310 & 7) * 0.785398185253143310546875f;
                            int _7466 = _9310 >> 3;
                            int _9313;
                            if (_7466 == 0)
                            {
                                _9313 = 16;
                            }
                            else
                            {
                                _9313 = (_7466 == 1) ? 48 : 96;
                            }
                            uint _7532_dummy_parameter;
                            _7500 = min(_9311, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9017 + ((cbFI_MvDepthLaneSizeRcp * float(_9313)) * float2(cos(_7464), sin(_7464))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7532_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9312 = _9311;
                    }
                    else
                    {
                        _9312 = 0.0f;
                    }
                    _9316 = _9312;
                }
                float _9317;
                if (_4359)
                {
                    uint _7564_dummy_parameter;
                    _9317 = r_depth_tm1.Load(int3(int2(floor(_9015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7564_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9317 = 0.0f;
                }
                float _9318;
                if (_4362)
                {
                    uint _7583_dummy_parameter;
                    _9318 = r_depth_tp1.Load(int3(int2(floor(_9017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7583_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9318 = 0.0f;
                }
                bool _4469;
                if (_4359)
                {
                    _4469 = _9317 > ((exp((_9309 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4469 = _4359;
                }
                float4 _9334;
                if (_4469)
                {
                    float4 _8896 = _9326;
                    _8896.x = 0.0f;
                    _9334 = _8896;
                }
                else
                {
                    _9334 = _9326;
                }
                bool _4481;
                if (_4362)
                {
                    _4481 = _9318 > ((exp((_9316 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4481 = _4362;
                }
                float4 _9336;
                if (_4481)
                {
                    float4 _8898 = _9334;
                    _8898.y = 0.0f;
                    _9336 = _8898;
                }
                else
                {
                    _9336 = _9334;
                }
                float4 _9398;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4414)
                {
                    bool _4501;
                    if (_4359)
                    {
                        _4501 = _9317 < ((exp((_9309 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4501 = _4359;
                    }
                    float4 _9338;
                    if (_4501)
                    {
                        float4 _8900 = _9336;
                        _8900.x = 0.0f;
                        _9338 = _8900;
                    }
                    else
                    {
                        _9338 = _9336;
                    }
                    bool _4513;
                    if (_4362)
                    {
                        _4513 = _9318 < ((exp((_9316 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4513 = _4362;
                    }
                    float4 _9399;
                    if (_4513)
                    {
                        float4 _8902 = _9338;
                        _8902.y = 0.0f;
                        _9399 = _8902;
                    }
                    else
                    {
                        _9399 = _9338;
                    }
                    _9398 = _9399;
                }
                else
                {
                    _9398 = _9336;
                }
                _9847 = float3(float(_4370), log((r_depth_tm1.Load(int3(int2(floor(_9015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7208_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7240_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _9397 = _9398;
            }
            else
            {
                _9847 = float3(0.0f, 0.0f, 0.5f);
                _9397 = _9293;
            }
            bool _4524 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4283;
            bool _4530;
            if (_4524)
            {
                _4530 = _4337 || _4343;
            }
            else
            {
                _4530 = _4524;
            }
            float4 _9419;
            if (_4530)
            {
                float _9392;
                do
                {
                    uint4 _7762 = r_warped_motion_qdata_tp1.Load(int3(_9045, 0));
                    uint _7763 = _7762.x;
                    if (_7763 != 0u)
                    {
                        float _9391;
                        if (_7763 == 0u)
                        {
                            _9391 = -1.0f;
                        }
                        else
                        {
                            _9391 = float((_7763 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9392 = _9391;
                        break;
                    }
                    int _9374;
                    uint _9375;
                    _9375 = _7763;
                    _9374 = -1;
                    uint _9390;
                    for (; _9374 <= 1; _9375 = _9390, _9374++)
                    {
                        _9390 = _9375;
                        for (int _9388 = -1; _9388 <= 1; )
                        {
                            _9390 = max(_9390, r_warped_motion_qdata_tp1.Load(int3(clamp(_9045 + int2(_9388, _9374), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9388++;
                            continue;
                        }
                    }
                    if (_9375 != 0u)
                    {
                        float _9387;
                        if (_9375 == 0u)
                        {
                            _9387 = -1.0f;
                        }
                        else
                        {
                            _9387 = float((_9375 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9392 = _9387;
                        break;
                    }
                    uint _9377;
                    _9377 = 4294967295u;
                    uint _10585;
                    for (int _9376 = 0; _9376 < 8; _9377 = _10585, _9376++)
                    {
                        int _9380 = 0;
                        for (;;)
                        {
                            if (_9380 < 5)
                            {
                                int2 _7713 = _9045 + (_1085[_9376] * _1094[_9380].xx);
                                bool _7716 = any(bool2(_7713.x < int2(0, 0).x, _7713.y < int2(0, 0).y));
                                bool _7724;
                                if (!_7716)
                                {
                                    _7724 = any(bool2(_7713.x >= cbFI_MvDepthLaneSize.x, _7713.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7724 = _7716;
                                }
                                if (_7724)
                                {
                                    _10585 = _9377;
                                    break;
                                }
                                uint4 _7802 = r_warped_motion_qdata_tp1.Load(int3(_7713, 0));
                                uint _7803 = _7802.x;
                                if (_7803 != 0u)
                                {
                                    _10585 = min(_9377, _7803);
                                    break;
                                }
                                _9380++;
                                continue;
                            }
                            else
                            {
                                _10585 = _9377;
                                break;
                            }
                        }
                    }
                    float _9379;
                    if (_9377 == 4294967295u)
                    {
                        _9379 = -1.0f;
                    }
                    else
                    {
                        float _9378;
                        if (_9377 == 0u)
                        {
                            _9378 = -1.0f;
                        }
                        else
                        {
                            _9378 = float((_9377 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9379 = _9378;
                    }
                    _9392 = _9379;
                    break;
                } while(false);
                float4 _9420;
                if (_9392 >= 0.0f)
                {
                    float _7824 = (exp((_9392 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4549;
                    if (_4337)
                    {
                        uint _7831_dummy_parameter;
                        _4549 = r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7831_dummy_parameter))))), 0)).x > _7824;
                    }
                    else
                    {
                        _4549 = _4337;
                    }
                    float4 _9410;
                    if (_4549)
                    {
                        float4 _8904 = _9397;
                        _8904.z = 0.0f;
                        _9410 = _8904;
                    }
                    else
                    {
                        _9410 = _9397;
                    }
                    bool _4561;
                    if (_4343)
                    {
                        uint _7850_dummy_parameter;
                        _4561 = r_depth_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7850_dummy_parameter))))), 0)).x > _7824;
                    }
                    else
                    {
                        _4561 = _4343;
                    }
                    float4 _9421;
                    if (_4561)
                    {
                        float4 _8906 = _9410;
                        _8906.w = 0.0f;
                        _9421 = _8906;
                    }
                    else
                    {
                        _9421 = _9410;
                    }
                    _9420 = _9421;
                }
                else
                {
                    _9420 = _9397;
                }
                _9419 = _9420;
            }
            else
            {
                _9419 = _9397;
            }
            bool _4569 = _4325 != _4331;
            bool _4576;
            if (_4569)
            {
                _4576 = _4325 ? _4271 : _4274;
            }
            else
            {
                _4576 = _4569;
            }
            float4 _9502;
            if (_4576)
            {
                bool2 _4581 = _4325.xx;
                float2 _4582 = float2(_4581.x ? _9015.x : _9017.x, _4581.y ? _9015.y : _9017.y);
                float _9412;
                if (_4325)
                {
                    uint _7869_dummy_parameter;
                    _9412 = r_depth_tm1.Load(int3(int2(floor(_4582 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7869_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7885_dummy_parameter;
                    _9412 = r_depth_tp1.Load(int3(int2(floor(_4582 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7885_dummy_parameter))))), 0)).x;
                }
                float4x4 _9413;
                if (_4325)
                {
                    _9413 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9413 = cbFI_MotionTP1ToTM1;
                }
                float2 _9414;
                do
                {
                    float _7912 = _4582.x;
                    float _7915 = 1.0f - _4582.y;
                    float4 _7926 = mul(float4((float2(_7912, _7915) * 2.0f) - 1.0f.xx, _9412, 1.0f), _9413);
                    float _7928 = _7926.w;
                    if (!(_7928 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9414 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7941 = ((_7926.xy / _7928.xx) + 1.0f.xx) * 0.5f;
                    _9414 = float2(_7941.x - _7912, _7915 - _7941.y);
                    break;
                } while(false);
                float2 _4612 = float2(cbFI_DisplaySize);
                float4 _9503;
                if (!(length(((_4582 + _9414) - float2(_4581.x ? _9017.x : _9015.x, _4581.y ? _9017.y : _9015.y)) * _4612) <= ((0.100000001490116119384765625f * length(_9414 * _4612)) + 8.0f)))
                {
                    float4 _9504;
                    if (_4325)
                    {
                        float4 _8916 = _9419;
                        _8916.x = 0.0f;
                        _9504 = _8916;
                    }
                    else
                    {
                        float4 _8918 = _9419;
                        _8918.y = 0.0f;
                        _9504 = _8918;
                    }
                    _9503 = _9504;
                }
                else
                {
                    _9503 = _9419;
                }
                _9502 = _9503;
            }
            else
            {
                _9502 = _9419;
            }
            float4 _4637 = _9194 * _9502;
            float _4639 = dot(_4637, 1.0f.xxxx);
            float4 _9679;
            bool _9699;
            if (_4639 > 0.0f)
            {
                _9699 = _9164;
                _9679 = _4637 / _4639.xxxx;
            }
            else
            {
                bool _4650 = any(bool4(_9502.x < 1.0f.xxxx.x, _9502.y < 1.0f.xxxx.y, _9502.z < 1.0f.xxxx.z, _9502.w < 1.0f.xxxx.w));
                if (_4650)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7963;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7963);
                    }
                }
                bool4 _10615 = _4650.xxxx;
                _9699 = _4650 ? true : _9164;
                _9679 = float4(_10615.x ? 0.0f.xxxx.x : _9194.x, _10615.y ? 0.0f.xxxx.y : _9194.y, _10615.z ? 0.0f.xxxx.z : _9194.z, _10615.w ? 0.0f.xxxx.w : _9194.w);
            }
            _9810 = _9847;
            _9698 = _9699;
            _9678 = _9679;
        }
        else
        {
            _9810 = float3(0.0f, 0.0f, 0.5f);
            _9698 = _9164;
            _9678 = _9194;
        }
        uint _4659 = (cbFI_pad0 >> 24u) & 31u;
        uint _4663 = (cbFI_pad0 >> 16u) & 255u;
        bool _4665 = _4659 != 0u;
        bool _4667 = _4663 == 12u;
        bool _4670 = _4663 == 13u;
        float4 _9695;
        if ((_4665 || _4667) || _4670)
        {
            float _9505;
            do
            {
                bool _8047 = all(bool2(_9018.x > 0.0f.xx.x, _9018.y > 0.0f.xx.y));
                bool _8053;
                if (_8047)
                {
                    _8053 = all(bool2(_9018.x < 1.0f.xx.x, _9018.y < 1.0f.xx.y));
                }
                else
                {
                    _8053 = _8047;
                }
                bool _7984 = !_8053;
                bool _7991;
                if (!_7984)
                {
                    bool _8058 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
                    bool _8064;
                    if (_8058)
                    {
                        _8064 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8064 = _8058;
                    }
                    _7991 = !_8064;
                }
                else
                {
                    _7991 = _7984;
                }
                if (_7991)
                {
                    _9505 = 0.0f;
                    break;
                }
                uint _8071_dummy_parameter;
                uint _8087_dummy_parameter;
                float4 _8012 = mul(float4((float2(_9018.x, 1.0f - _9018.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8071_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8014 = _8012.w;
                if (abs(_8014) < 9.9999999747524270787835121154785e-07f)
                {
                    _9505 = 0.0f;
                    break;
                }
                float _8025 = abs(cbFI_DeviceToViewDepth.y / ((_8012.z / _8014) - cbFI_DeviceToViewDepth.x));
                float _8028 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8087_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9505 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8025 - _8028) / max(max(_8025, _8028), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8135 = all(bool2(_9019.x > 0.0f.xx.x, _9019.y > 0.0f.xx.y));
            bool _8141;
            if (_8135)
            {
                _8141 = all(bool2(_9019.x < 1.0f.xx.x, _9019.y < 1.0f.xx.y));
            }
            else
            {
                _8141 = _8135;
            }
            float _9506;
            if (_8141)
            {
                uint _8148_dummy_parameter;
                _9506 = length((_5446 + (r_motion_tp1.Load(int3(int2(floor(_9019 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8148_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9506 = 1000000.0f;
            }
            float _9517;
            if ((_4659 & 1u) != 0u)
            {
                _9517 = _9505;
            }
            else
            {
                _9517 = 1.0f;
            }
            float _9518;
            if ((_4659 & 2u) != 0u)
            {
                _9518 = _9517 * (1.0f - smoothstep(2.0f, 8.0f, _9506));
            }
            else
            {
                _9518 = _9517;
            }
            float _9519;
            if ((_4659 & 4u) != 0u)
            {
                _9519 = _9518 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6167 - _6175) - length(_6151 - _6159))));
            }
            else
            {
                _9519 = _9518;
            }
            float _9689;
            if ((_4659 & 8u) != 0u)
            {
                _9689 = lerp(1.0f, _9519, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6151 - _6159)));
            }
            else
            {
                _9689 = _9519;
            }
            bool _4745 = (_4659 & 16u) != 0u;
            bool _4754;
            if (_4745)
            {
                _4754 = length(_9013 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4754 = _4745;
            }
            float _10617 = _4754 ? 1.0f : _9689;
            bool _4760 = _4665 && _6360;
            bool _4765;
            if (_4760)
            {
                bool _8173 = all(bool2(_9015.x > 0.0f.xx.x, _9015.y > 0.0f.xx.y));
                bool _8179;
                if (_8173)
                {
                    _8179 = all(bool2(_9015.x < 1.0f.xx.x, _9015.y < 1.0f.xx.y));
                }
                else
                {
                    _8179 = _8173;
                }
                _4765 = _8179;
            }
            else
            {
                _4765 = _4760;
            }
            bool _4770;
            if (_4765)
            {
                bool _8184 = all(bool2(_9017.x > 0.0f.xx.x, _9017.y > 0.0f.xx.y));
                bool _8190;
                if (_8184)
                {
                    _8190 = all(bool2(_9017.x < 1.0f.xx.x, _9017.y < 1.0f.xx.y));
                }
                else
                {
                    _8190 = _8184;
                }
                _4770 = _8190;
            }
            else
            {
                _4770 = _4765;
            }
            float4 _9696;
            if (_4770)
            {
                float _4776 = _9678.x + _9678.y;
                float _4785 = (_9678.z + _9678.w) * (1.0f - _10617);
                float _9692;
                if (_4776 > 9.9999997473787516355514526367188e-06f)
                {
                    _9692 = _9678.x / _4776;
                }
                else
                {
                    _9692 = _3943;
                }
                _9696 = float4(_9678.x + (_4785 * _9692), _9678.y + (_4785 * (1.0f - _9692)), _9678.zw * _10617);
            }
            else
            {
                _9696 = _9678;
            }
            _9695 = _9696;
        }
        else
        {
            _9695 = _9678;
        }
        float3 _10388;
        if (_9698)
        {
            float3 _8196 = r_current_interpolation_source.Load(int3(_3357, 0)).xyz;
            float3 _10389;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6360)
            {
                uint _8203_dummy_parameter;
                float _9801;
                _9801 = r_depth_tm1.Load(int3(int2(floor(_9015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8203_dummy_parameter))))), 0)).x;
                float _4897;
                for (int _9800 = 0; _9800 < 24; _9801 = _4897, _9800++)
                {
                    float _4869 = float(_9800 & 7) * 0.785398185253143310546875f;
                    int _4871 = _9800 >> 3;
                    int _10439;
                    if (_4871 == 0)
                    {
                        _10439 = 16;
                    }
                    else
                    {
                        _10439 = (_4871 == 1) ? 48 : 96;
                    }
                    uint _8223_dummy_parameter;
                    _4897 = min(_9801, r_depth_tm1.Load(int3(int2(floor(clamp(_9015 + ((cbFI_MvDepthLaneSizeRcp * float(_10439)) * float2(cos(_4869), sin(_4869))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8223_dummy_parameter))))), 0)).x);
                }
                float2 _9802;
                do
                {
                    float _8245 = 1.0f - _9015.y;
                    float4 _8256 = mul(float4((float2(_9015.x, _8245) * 2.0f) - 1.0f.xx, _9801, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8258 = _8256.w;
                    if (!(_8258 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9802 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8271 = ((_8256.xy / _8258.xx) + 1.0f.xx) * 0.5f;
                    _9802 = float2(_8271.x - _9015.x, _8245 - _8271.y);
                    break;
                } while(false);
                float2 _4908 = _9015 + _9802;
                bool _8289 = all(bool2(_4908.x > 0.0f.xx.x, _4908.y > 0.0f.xx.y));
                bool _8295;
                if (_8289)
                {
                    _8295 = all(bool2(_4908.x < 1.0f.xx.x, _4908.y < 1.0f.xx.y));
                }
                else
                {
                    _8295 = _8289;
                }
                float3 _10390;
                if (_8295)
                {
                    float _4914 = abs(cbFI_DeviceToViewDepth.y / (_9801 - cbFI_DeviceToViewDepth.x));
                    uint _8315_dummy_parameter;
                    int2 _8315 = int2(spvTextureSize(r_depth_m2, uint(0), _8315_dummy_parameter));
                    float _4918 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4908 * float2(_8315))), int2(0, 0), _8315 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10395;
                    if (abs(_4918 - _4914) <= (0.20000000298023223876953125f * max(_4918, _4914)))
                    {
                        uint _8349_dummy_parameter;
                        int2 _8349 = int2(spvTextureSize(r_colour_m2, uint(0), _8349_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8372;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8372);
                        }
                        _10395 = r_colour_m2.Load(int3(clamp(int2(floor(_4908 * float2(_8349))), int2(0, 0), _8349 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8382;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8382);
                        }
                        _10395 = _8196;
                    }
                    _10390 = _10395;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8392;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8392);
                    }
                    _10390 = _8196;
                }
                _10389 = _10390;
            }
            else
            {
                _10389 = _8196;
            }
            _10388 = _10389;
        }
        else
        {
            _10388 = (((_6151 * _9695.x) + (_6159 * _9695.y)) + (_6167 * _9695.z)) + (_6175 * _9695.w);
        }
        uint _4946 = cbFI_pad0 & 255u;
        bool _10281;
        float3 _10387;
        if (_4946 != 0u)
        {
            float3 _4951 = r_present_backbuffer.Load(int3(_3357, 0)).xyz;
            float3 _4955 = r_current_interpolation_source.Load(int3(_3357, 0)).xyz;
            float3 _4959 = abs(_4951 - _4955);
            float3 _9805;
            if (_4946 == 2u)
            {
                _9805 = (abs(_4955) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9805 = 0.000244140625f.xxx;
            }
            bool _4975 = any(bool3(_4959.x > _9805.x, _4959.y > _9805.y, _4959.z > _9805.z));
            bool3 _10618 = _4975.xxx;
            _10387 = float3(_10618.x ? _4951.x : _10388.x, _10618.y ? _4951.y : _10388.y, _10618.z ? _4951.z : _10388.z);
            _10281 = _4975;
        }
        else
        {
            _10387 = _10388;
            _10281 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8407;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8407);
        }
        float3 _10370;
        if (_4663 == 1u)
        {
            _10370 = lerp(_6151, _6159, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10371;
            if (_4663 == 2u)
            {
                _10371 = lerp(_6167, _6175, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10372;
                if (_4663 == 3u)
                {
                    _10372 = float(_10281).xxx;
                }
                else
                {
                    float3 _10373;
                    if (_4663 == 4u)
                    {
                        _10373 = float3(((_9013 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10374;
                        if (_4663 == 5u)
                        {
                            _10374 = float3(((_5446 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10375;
                            if (_4663 == 6u)
                            {
                                _10375 = float3(_9695.xy, _9695.z + _9695.w);
                            }
                            else
                            {
                                float3 _10376;
                                if (_4663 == 7u)
                                {
                                    _10376 = r_current_interpolation_source.Load(int3(_3357, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10377;
                                    if (_4663 == 8u)
                                    {
                                        _10377 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3718, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10378;
                                        if (_4667)
                                        {
                                            uint _8429_dummy_parameter;
                                            uint _8461_dummy_parameter;
                                            _10378 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3718 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8429_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3718 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8461_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10379;
                                            if (_4670)
                                            {
                                                _10379 = _6167;
                                            }
                                            else
                                            {
                                                float3 _10380;
                                                if (_4663 == 20u)
                                                {
                                                    _10380 = _6151;
                                                }
                                                else
                                                {
                                                    float3 _10381;
                                                    if (_4663 == 21u)
                                                    {
                                                        _10381 = _6159;
                                                    }
                                                    else
                                                    {
                                                        float3 _10382;
                                                        if (_4663 == 22u)
                                                        {
                                                            _10382 = _6175;
                                                        }
                                                        else
                                                        {
                                                            float3 _10383;
                                                            if (_4663 == 18u)
                                                            {
                                                                _10383 = _10090;
                                                            }
                                                            else
                                                            {
                                                                float3 _10384;
                                                                if (_4663 == 19u)
                                                                {
                                                                    _10384 = _9947;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10620 = (_4663 == 23u).xxx;
                                                                    _10384 = float3(_10620.x ? _9810.x : _10387.x, _10620.y ? _9810.y : _10387.y, _10620.z ? _9810.z : _10387.z);
                                                                }
                                                                _10383 = _10384;
                                                            }
                                                            _10382 = _10383;
                                                        }
                                                        _10381 = _10382;
                                                    }
                                                    _10380 = _10381;
                                                }
                                                _10379 = _10380;
                                            }
                                            _10378 = _10379;
                                        }
                                        _10377 = _10378;
                                    }
                                    _10376 = _10377;
                                }
                                _10375 = _10376;
                            }
                            _10374 = _10375;
                        }
                        _10373 = _10374;
                    }
                    _10372 = _10373;
                }
                _10371 = _10372;
            }
            _10370 = _10371;
        }
        float3 _10369;
        if ((_4663 >= 9u) && (_4663 <= 11u))
        {
            uint _5139 = 64u + uint((_9045.y * cbFI_MvDepthLaneSize.x) + _9045.x);
            uint _5143 = rw_nfru_diagnostics.Load<uint>(_5139 * 4 + 0) & 15u;
            float3 _10400;
            if (_4663 == 10u)
            {
                float3 _10368;
                if ((rw_nfru_diagnostics.Load<uint>(_5139 * 4 + 0) & 32u) != 0u)
                {
                    _10368 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10367;
                    if ((rw_nfru_diagnostics.Load<uint>(_5139 * 4 + 0) & 16u) != 0u)
                    {
                        _10367 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5164 = ((rw_nfru_diagnostics.Load<uint>(_5139 * 4 + 0) & 64u) != 0u).xxx;
                        _10367 = float3(_5164.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5164.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5164.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10368 = _10367;
                }
                _10400 = _10368;
            }
            else
            {
                float3 _10401;
                if (_4663 == 11u)
                {
                    uint _5177 = (rw_nfru_diagnostics.Load<uint>(_5139 * 4 + 0) >> 8u) & 15u;
                    uint _5180 = (rw_nfru_diagnostics.Load<uint>(_5139 * 4 + 0) >> 12u) & 15u;
                    float3 _10360;
                    if ((_5143 == 2u) || (_5143 == 3u))
                    {
                        _10360 = _3070[_5143];
                    }
                    else
                    {
                        bool _5192 = _5177 == 3u;
                        bool _5194 = _5180 == 3u;
                        float3 _10361;
                        if (_5192 && _5194)
                        {
                            _10361 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10362;
                            if (_5192)
                            {
                                _10362 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10363;
                                if (_5194)
                                {
                                    _10363 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10364;
                                    if ((_5177 == 4u) || (_5180 == 4u))
                                    {
                                        _10364 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10365;
                                        if ((_5177 == 1u) || (_5180 == 1u))
                                        {
                                            _10365 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10622 = (_5143 == 1u).xxx;
                                            _10365 = float3(_10622.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10622.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10622.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10364 = _10365;
                                    }
                                    _10363 = _10364;
                                }
                                _10362 = _10363;
                            }
                            _10361 = _10362;
                        }
                        _10360 = _10361;
                    }
                    _10401 = _10360;
                }
                else
                {
                    _10401 = _3070[min(_5143, 7u)];
                }
                _10400 = _10401;
            }
            _10369 = _10400;
        }
        else
        {
            _10369 = _10370;
        }
        float4 _10404;
        if ((_4663 >= 14u) && (_4663 <= 16u))
        {
            float2 _10402;
            if (_4663 == 14u)
            {
                uint _5250_dummy_parameter;
                uint _5256_dummy_parameter;
                _10402 = r_flow_tm1.Load(int3(clamp(int2(floor(_3718 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5250_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5256_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10403;
                if (_4663 == 16u)
                {
                    uint _8512 = r_warped_flow_qdata_tm1.Load(int3(_3734, 0)).x & 2147483647u;
                    uint _8544 = uint(max((int((_8512 >> 16u) & 15u) - 6), 0));
                    _10403 = ((float2(float((1 - (2 * int((_8512 >> 15u) & 1u))) * int(((_8512 >> uint(7)) & 127u) << _8544)), float((1 - (2 * int((_8512 >> 14u) & 1u))) * int((_8512 & 127u) << _8544))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10403 = _5446 * float2(cbFI_DisplaySize);
                }
                _10402 = _10403;
            }
            uint2 _5289 = uint2(clamp(round(_10402 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5291 = _5289.x;
            uint _5298 = _5289.y;
            _10404 = float4(float(_5291 & 255u), float((_5291 >> 8u) | ((_5298 & 15u) << 4u)), float(_5298 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10405;
            if (_4663 == 17u)
            {
                _10405 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3734, 0)).x != 0u), _4077, 0.0f, 1.0f);
            }
            else
            {
                _10405 = float4(_10369, 1.0f);
            }
            _10404 = _10405;
        }
        rw_output[_3357] = _10404.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5342 = ((uint(_3357.y) * uint(cbFI_DisplaySize.x)) + uint(_3357.x)) * 6u;
            uint _8590 = spvPackHalf2x16(clamp(_6150.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5342 * 4 + 0, (((_8590 & 32767u) >> 4u) | ((((_8590 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6150.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8625 = spvPackHalf2x16(clamp(_6158.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5342 + 1u) * 4 + 0, (((_8625 & 32767u) >> 4u) | ((((_8625 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6158.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8660 = spvPackHalf2x16(clamp(_6166.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5342 + 2u) * 4 + 0, (((_8660 & 32767u) >> 4u) | ((((_8660 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6166.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8695 = spvPackHalf2x16(clamp(_6174.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5342 + 3u) * 4 + 0, (((_8695 & 32767u) >> 4u) | ((((_8695 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6174.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8722 = r_current_interpolation_source.Load(int3(_3357, 0));
            uint _8736 = spvPackHalf2x16(clamp(_8722.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5342 + 4u) * 4 + 0, (((_8736 & 32767u) >> 4u) | ((((_8736 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8722.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10438;
            if (_10281 || (_4663 != 0u))
            {
                _10438 = 4294967295u;
            }
            else
            {
                uint _8771 = spvPackHalf2x16(clamp(_10404.xy, 0.0f.xx, 65000.0f.xx));
                _10438 = (((_8771 & 32767u) >> 4u) | ((((_8771 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10404.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5342 + 5u) * 4 + 0, _10438);
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
