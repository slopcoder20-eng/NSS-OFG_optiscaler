static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3304[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3591 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3591.x >= cbFI_DisplaySize.x, _3591.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3591] = float4(r_present_backbuffer.Load(int3(_3591, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3978 = (float2(_3591) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3989 = int2(floor(_3978 * float2(cbFI_MvDepthLaneSize)));
        int2 _3994 = int2(floor(_3978 * float2(cbFI_FlowLaneSize)));
        float4 _5902 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3978 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5908 = r_warped_filled_flow_tm1.Load(int3(_3994, 0)).xy;
        float2 _5914 = r_warped_filled_motion_tp1.Load(int3(_3989, 0)).xy;
        bool _5936 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9992;
        if (_5936)
        {
            float _5949 = ((2.0f * _3978.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9992 = float2(atan(_5949) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3978.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5949 * _5949))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9992 = _3978;
        }
        bool _4015 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10013;
        bool _10034;
        int2 _10045;
        float3 _11404;
        if (_4015)
        {
            float _9994;
            float _9996;
            _9996 = 2.0f;
            _9994 = -1.0f;
            uint _3653[9];
            float _11836;
            float _11839;
            for (int _9993 = 0; _9993 < 9; _9996 = _11839, _9994 = _11836, _9993++)
            {
                _3653[_9993] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3989 + int2((_9993 % 3) - 1, (_9993 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3653[_9993] != 0u)
                {
                    float _11831;
                    if (_3653[_9993] == 0u)
                    {
                        _11831 = -1.0f;
                    }
                    else
                    {
                        _11831 = float((_3653[_9993] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11839 = min(_9996, _11831);
                    _11836 = max(_9994, _11831);
                }
                else
                {
                    _11839 = _9996;
                    _11836 = _9994;
                }
            }
            float _4061 = float(_9994 >= 0.0f);
            float3 _9789 = 0.0f.xxx;
            _9789.y = _4061;
            float2 _10014;
            bool _10035;
            int2 _10046;
            float3 _11405;
            if ((_9994 - _9996) > 0.0199999995529651641845703125f)
            {
                float _10002;
                int2 _10003;
                float2 _10004;
                int2 _10006;
                float2 _10012;
                _10012 = _5914;
                _10006 = _3989;
                _10004 = _5914;
                _10003 = _3989;
                _10002 = -1.0f;
                float _11844;
                int2 _11848;
                float2 _11859;
                int2 _11870;
                float2 _11903;
                float _11950;
                int _10001 = 0;
                float _11812 = 1000000000.0f;
                for (; _10001 < 9; _11812 = _11950, _10012 = _11903, _10006 = _11870, _10004 = _11859, _10003 = _11848, _10002 = _11844, _10001++)
                {
                    if (_3653[_10001] == 0u)
                    {
                        _11950 = _11812;
                        _11903 = _10012;
                        _11870 = _10006;
                        _11859 = _10004;
                        _11848 = _10003;
                        _11844 = _10002;
                        continue;
                    }
                    int2 _4096 = clamp(_3989 + int2((_10001 % 3) - 1, (_10001 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6024 = _3653[_10001] & 2147483647u;
                    uint _6056 = uint(max((int((_6024 >> 16u) & 15u) - 6), 0));
                    float2 _4102 = (float2(float((1 - (2 * int((_6024 >> 15u) & 1u))) * int(((_6024 >> uint(7)) & 127u) << _6056)), float((1 - (2 * int((_6024 >> 14u) & 1u))) * int((_6024 & 127u) << _6056))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11798;
                    if (_3653[_10001] == 0u)
                    {
                        _11798 = -1.0f;
                    }
                    else
                    {
                        _11798 = float((_3653[_10001] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4107 = _11798 - 0.100000001490116119384765625f;
                    float2 _11799;
                    if (_5936)
                    {
                        float2 _6133 = clamp((((_9992 + (_4102 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6136 = tan(_6133.x);
                        _11799 = (float2(_6136 / cbFI_DeviceToViewDepth.z, (tan(_6133.y) * sqrt(1.0f + (_6136 * _6136))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11799 = _9992 + (_4102 * cbFI_Timestep);
                    }
                    float _4114 = cbFI_Timestep - 1.0f;
                    float2 _11800;
                    if (_5936)
                    {
                        float2 _6204 = clamp((((_9992 + (_4102 * _4114)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6207 = tan(_6204.x);
                        _11800 = (float2(_6207 / cbFI_DeviceToViewDepth.z, (tan(_6204.y) * sqrt(1.0f + (_6207 * _6207))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11800 = _9992 + (_4102 * _4114);
                    }
                    bool _6240 = all(bool2(_11799.x > 0.0f.xx.x, _11799.y > 0.0f.xx.y));
                    bool _6246;
                    if (_6240)
                    {
                        _6246 = all(bool2(_11799.x < 1.0f.xx.x, _11799.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6246 = _6240;
                    }
                    float _11803;
                    if (_6246)
                    {
                        uint _6253_dummy_parameter;
                        _11803 = max((_4107 - (log(((r_depth_tm1.Load(int3(int2(floor(_11799 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6253_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11803 = 0.0f;
                    }
                    bool _6283 = all(bool2(_11800.x > 0.0f.xx.x, _11800.y > 0.0f.xx.y));
                    bool _6289;
                    if (_6283)
                    {
                        _6289 = all(bool2(_11800.x < 1.0f.xx.x, _11800.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6289 = _6283;
                    }
                    float _11804;
                    if (_6289)
                    {
                        uint _6296_dummy_parameter;
                        _11804 = _11803 + max((_4107 - (log(((r_depth_tp1.Load(int3(int2(floor(_11800 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6296_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11804 = _11803;
                    }
                    float _11845;
                    int2 _11849;
                    float2 _11860;
                    int2 _11871;
                    float2 _11904;
                    float _11951;
                    if (_11804 == 0.0f)
                    {
                        bool _4149 = _4107 > _10002;
                        bool2 _11959 = _4149.xx;
                        _11951 = _11812;
                        _11904 = float2(_11959.x ? _4102.x : _10012.x, _11959.y ? _4102.y : _10012.y);
                        _11871 = int2(_11959.x ? _4096.x : _10006.x, _11959.y ? _4096.y : _10006.y);
                        _11860 = _10004;
                        _11849 = _10003;
                        _11845 = _4149 ? _4107 : _10002;
                    }
                    else
                    {
                        bool _4158 = _11804 < _11812;
                        bool2 _11955 = _4158.xx;
                        _11951 = _4158 ? _11804 : _11812;
                        _11904 = _10012;
                        _11871 = _10006;
                        _11860 = float2(_11955.x ? _4102.x : _10004.x, _11955.y ? _4102.y : _10004.y);
                        _11849 = int2(_11955.x ? _4096.x : _10003.x, _11955.y ? _4096.y : _10003.y);
                        _11845 = _10002;
                    }
                    _11950 = _11951;
                    _11903 = _11904;
                    _11870 = _11871;
                    _11859 = _11860;
                    _11848 = _11849;
                    _11844 = _11845;
                }
                bool _4170 = _10002 < 0.0f;
                bool2 _11965 = _4170.xx;
                int2 _11968 = int2(_11965.x ? _10003.x : _10006.x, _11965.y ? _10003.y : _10006.y);
                _11405 = float3(1.0f, _4061, float(any(bool2(_11968.x != _3989.x, _11968.y != _3989.y))));
                _10046 = _11968;
                _10035 = _4170 ? false : true;
                _10014 = float2(_11965.x ? _10004.x : _10012.x, _11965.y ? _10004.y : _10012.y);
            }
            else
            {
                _11405 = _9789;
                _10046 = _3989;
                _10035 = false;
                _10014 = _5914;
            }
            _11404 = _11405;
            _10045 = _10046;
            _10034 = _10035;
            _10013 = _10014;
        }
        else
        {
            _11404 = 0.0f.xxx;
            _10045 = _3989;
            _10034 = false;
            _10013 = _5914;
        }
        float2 _10015;
        if (_5936)
        {
            float2 _6361 = clamp((((_9992 + (_10013 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6364 = tan(_6361.x);
            _10015 = (float2(_6364 / cbFI_DeviceToViewDepth.z, (tan(_6361.y) * sqrt(1.0f + (_6364 * _6364))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10015 = _9992 + (_10013 * cbFI_Timestep);
        }
        float _4193 = cbFI_Timestep - 1.0f;
        float2 _10017;
        if (_5936)
        {
            float2 _6432 = clamp((((_9992 + (_10013 * _4193)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6435 = tan(_6432.x);
            _10017 = (float2(_6435 / cbFI_DeviceToViewDepth.z, (tan(_6432.y) * sqrt(1.0f + (_6435 * _6435))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10017 = _9992 + (_10013 * _4193);
        }
        float _4198 = -cbFI_Timestep;
        float2 _10018;
        if (_5936)
        {
            float2 _6503 = clamp((((_9992 + (_5908 * _4198)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6506 = tan(_6503.x);
            _10018 = (float2(_6506 / cbFI_DeviceToViewDepth.z, (tan(_6503.y) * sqrt(1.0f + (_6506 * _6506))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10018 = _9992 + (_5908 * _4198);
        }
        float _4203 = 1.0f - cbFI_Timestep;
        float2 _10019;
        if (_5936)
        {
            float2 _6574 = clamp((((_9992 + (_5908 * _4203)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6577 = tan(_6574.x);
            _10019 = (float2(_6577 / cbFI_DeviceToViewDepth.z, (tan(_6574.y) * sqrt(1.0f + (_6577 * _6577))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10019 = _9992 + (_5908 * _4203);
        }
        float4 _6612 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10015, 0.0f);
        float3 _6613 = _6612.xyz;
        float4 _6620 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10017, 0.0f);
        float3 _6621 = _6620.xyz;
        float4 _6628 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10018, 0.0f);
        float3 _6629 = _6628.xyz;
        float4 _6636 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10019, 0.0f);
        float3 _6637 = _6636.xyz;
        float4 _6651 = exp(_5902 - max(max(max(_5902.x, _5902.y), _5902.z), _5902.w).xxxx);
        float4 _6658 = _6651 / (dot(_6651, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4222 = _4015 && (!_10034);
        bool _4231;
        if (_4222)
        {
            _4231 = (_6658.z + _6658.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4231 = _4222;
        }
        bool _4242;
        if (_4231)
        {
            _4242 = length((_10018 - _10015) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4242 = _4231;
        }
        bool _10058;
        if (_4242)
        {
            uint4 _6677 = r_warped_motion_qdata_tp1.Load(int3(_10045, 0));
            uint _6678 = _6677.x;
            bool _10061;
            if (_6678 != 0u)
            {
                float _10047;
                if (_6678 == 0u)
                {
                    _10047 = -1.0f;
                }
                else
                {
                    _10047 = float((_6678 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4252 = _10047 - 0.12000000476837158203125f;
                bool _6697 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
                bool _6703;
                if (_6697)
                {
                    _6703 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
                }
                else
                {
                    _6703 = _6697;
                }
                bool _4262;
                if (_6703)
                {
                    uint _6710_dummy_parameter;
                    _4262 = (log(((r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6710_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4252;
                }
                else
                {
                    _4262 = _6703;
                }
                bool _4276;
                if (!_4262)
                {
                    bool _6740 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
                    bool _6746;
                    if (_6740)
                    {
                        _6746 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6746 = _6740;
                    }
                    bool _4274;
                    if (_6746)
                    {
                        uint _6753_dummy_parameter;
                        _4274 = (log(((r_depth_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6753_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4252;
                    }
                    else
                    {
                        _4274 = _6746;
                    }
                    _4276 = _4274;
                }
                else
                {
                    _4276 = _4262;
                }
                _10061 = _4276;
            }
            else
            {
                _10061 = false;
            }
            _10058 = _10061;
        }
        else
        {
            _10058 = false;
        }
        bool _4281 = _10034 || _10058;
        bool _4286;
        if (_4281)
        {
            bool _6783 = all(bool2(_10015.x > 0.0f.xx.x, _10015.y > 0.0f.xx.y));
            bool _6789;
            if (_6783)
            {
                _6789 = all(bool2(_10015.x < 1.0f.xx.x, _10015.y < 1.0f.xx.y));
            }
            else
            {
                _6789 = _6783;
            }
            _4286 = _6789;
        }
        else
        {
            _4286 = _4281;
        }
        bool _4291;
        if (_4286)
        {
            bool _6794 = all(bool2(_10017.x > 0.0f.xx.x, _10017.y > 0.0f.xx.y));
            bool _6800;
            if (_6794)
            {
                _6800 = all(bool2(_10017.x < 1.0f.xx.x, _10017.y < 1.0f.xx.y));
            }
            else
            {
                _6800 = _6794;
            }
            _4291 = _6800;
        }
        else
        {
            _4291 = _4286;
        }
        float4 _10155;
        if (_4291)
        {
            float _4294 = _6658.x;
            float _4296 = _6658.y;
            float _4297 = _4294 + _4296;
            float _4302 = _6658.z + _6658.w;
            float _10076;
            if (_4297 > 0.001000000047497451305389404296875f)
            {
                _10076 = _4294 / _4297;
            }
            else
            {
                _10076 = _4203;
            }
            _10155 = float4(_4294 + (_4302 * _10076), _4296 + (_4302 * (1.0f - _10076)), 0.0f, 0.0f);
        }
        else
        {
            _10155 = _6658;
        }
        bool _6828 = (cbFI_pad0 & 1024u) != 0u;
        bool _6804 = !_6828;
        bool _6805 = !_6804;
        bool _6822;
        if (_6805)
        {
            _6822 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10045.y * cbFI_MvDepthLaneSize.x) + _10045.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6822 = _6804;
        }
        bool _6854;
        if (_6805)
        {
            _6854 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3994.y * cbFI_FlowLaneSize.x) + _3994.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6854 = _6804;
        }
        float _4337 = float(_6854);
        bool _10168;
        float4 _10199;
        float3 _11218;
        if (_6828)
        {
            bool _4347;
            if (_6822)
            {
                _4347 = all(bool2(_10015.x > 0.0f.xx.x, _10015.y > 0.0f.xx.y));
            }
            else
            {
                _4347 = _6822;
            }
            bool _4353;
            if (_4347)
            {
                _4353 = all(bool2(_10015.x < 1.0f.xx.x, _10015.y < 1.0f.xx.y));
            }
            else
            {
                _4353 = _4347;
            }
            bool _4360;
            if (_6822)
            {
                _4360 = all(bool2(_10017.x > 0.0f.xx.x, _10017.y > 0.0f.xx.y));
            }
            else
            {
                _4360 = _6822;
            }
            bool _4366;
            if (_4360)
            {
                _4366 = all(bool2(_10017.x < 1.0f.xx.x, _10017.y < 1.0f.xx.y));
            }
            else
            {
                _4366 = _4360;
            }
            bool _4373;
            if (_6854)
            {
                _4373 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
            }
            else
            {
                _4373 = _6854;
            }
            bool _4379;
            if (_4373)
            {
                _4379 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
            }
            else
            {
                _4379 = _4373;
            }
            bool _4386;
            if (_6854)
            {
                _4386 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
            }
            else
            {
                _4386 = _6854;
            }
            bool _4392;
            if (_4386)
            {
                _4392 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
            }
            else
            {
                _4392 = _4386;
            }
            bool _4394 = !_6822;
            if (_4394)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6896;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6896);
                }
            }
            bool _4399 = !_6854;
            if (_4399)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6906;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6906);
                }
            }
            if (_6822 && _4399)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6916;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6916);
                }
            }
            if (_4394 && _6854)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6926;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6926);
                }
            }
            float _4418 = float(_4353);
            float _4420 = float(_4366);
            bool _4423 = _4379 && _4392;
            float _10110;
            if (_4423)
            {
                _10110 = 1.0f;
            }
            else
            {
                _10110 = (_4379 || _4392) ? 0.5f : 0.0f;
            }
            bool _10115;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4353)) && (!_4366))
            {
                bool _4453;
                if (_4423)
                {
                    float _10113;
                    do
                    {
                        bool _7010 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
                        bool _7016;
                        if (_7010)
                        {
                            _7016 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7016 = _7010;
                        }
                        bool _6947 = !_7016;
                        bool _6954;
                        if (!_6947)
                        {
                            bool _7021 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
                            bool _7027;
                            if (_7021)
                            {
                                _7027 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7027 = _7021;
                            }
                            _6954 = !_7027;
                        }
                        else
                        {
                            _6954 = _6947;
                        }
                        if (_6954)
                        {
                            _10113 = 0.0f;
                            break;
                        }
                        uint _7034_dummy_parameter;
                        uint _7050_dummy_parameter;
                        float4 _6975 = mul(float4((float2(_10018.x, 1.0f - _10018.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7034_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6977 = _6975.w;
                        if (abs(_6977) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10113 = 0.0f;
                            break;
                        }
                        float _6988 = abs(cbFI_DeviceToViewDepth.y / ((_6975.z / _6977) - cbFI_DeviceToViewDepth.x));
                        float _6991 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7050_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10113 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6988 - _6991) / max(max(_6988, _6991), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4453 = _10113 >= 0.5f;
                }
                else
                {
                    _4453 = _4423;
                }
                bool _4461;
                if (_4453)
                {
                    _4461 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4461 = _4453;
                }
                bool _10116;
                if (_4461)
                {
                    uint _7100_dummy_parameter;
                    float2 _10114;
                    do
                    {
                        float _7126 = 1.0f - _10018.y;
                        float4 _7137 = mul(float4((float2(_10018.x, _7126) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7100_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7139 = _7137.w;
                        if (!(_7139 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10114 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7152 = ((_7137.xy / _7139.xx) + 1.0f.xx) * 0.5f;
                        _10114 = float2(_7152.x - _10018.x, _7126 - _7152.y);
                        break;
                    } while(false);
                    float2 _4474 = float2(cbFI_DisplaySize);
                    _10116 = length(((_10018 + _10114) - _10019) * _4474) <= ((0.100000001490116119384765625f * length(_10114 * _4474)) + 8.0f);
                }
                else
                {
                    _10116 = _4453;
                }
                _10115 = _10116;
            }
            else
            {
                _10115 = true;
            }
            bool _4488 = !_10115;
            bool _11969 = _4488 ? false : _4392;
            bool _11970 = _4488 ? false : _4379;
            bool _10169;
            float4 _10200;
            if (!(((_4353 && _4366) && _11970) && _11969))
            {
                float4 _4510 = _10155 * float4(_4418, _4420, float(_11970), float(_11969));
                float _4512 = dot(_4510, 1.0f.xxxx);
                bool _4515 = !(_4512 > 0.0f);
                float4 _10201;
                if (!_4515)
                {
                    _10201 = _4510 / _4512.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7174;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7174);
                    }
                    _10201 = 0.0f.xxxx;
                }
                _10200 = _10201;
                _10169 = _4515;
            }
            else
            {
                _10200 = _10155;
                _10169 = false;
            }
            _11218 = float3(_4418, _4420, _10110);
            _10199 = _10200;
            _10168 = _10169;
        }
        else
        {
            _11218 = float3(float(_6822), _4337, 0.0f);
            _10199 = _10155;
            _10168 = false;
        }
        bool _4533 = !_10168;
        float4 _10261;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4533)
        {
            float _4540 = _10199.x + _10199.y;
            float4 _10262;
            if (_4540 > 0.001000000047497451305389404296875f)
            {
                _10262 = float4(_10199.x / _4540, _10199.y / _4540, 0.0f, 0.0f);
            }
            else
            {
                _10262 = float4(_4203, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10261 = _10262;
        }
        else
        {
            _10261 = _10199;
        }
        float4 _10357;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4533) && _6822)
        {
            float _10258;
            do
            {
                uint4 _7314 = r_warped_motion_qdata_tp1.Load(int3(_10045, 0));
                uint _7315 = _7314.x;
                if (_7315 != 0u)
                {
                    float _10257;
                    if (_7315 == 0u)
                    {
                        _10257 = -1.0f;
                    }
                    else
                    {
                        _10257 = float((_7315 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10258 = _10257;
                    break;
                }
                int _10240;
                uint _10241;
                _10241 = _7315;
                _10240 = -1;
                uint _10256;
                for (; _10240 <= 1; _10241 = _10256, _10240++)
                {
                    _10256 = _10241;
                    for (int _10254 = -1; _10254 <= 1; )
                    {
                        _10256 = max(_10256, r_warped_motion_qdata_tp1.Load(int3(clamp(_10045 + int2(_10254, _10240), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10254++;
                        continue;
                    }
                }
                if (_10241 != 0u)
                {
                    float _10253;
                    if (_10241 == 0u)
                    {
                        _10253 = -1.0f;
                    }
                    else
                    {
                        _10253 = float((_10241 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10258 = _10253;
                    break;
                }
                uint _10243;
                _10243 = 4294967295u;
                uint _11940;
                for (int _10242 = 0; _10242 < 8; _10243 = _11940, _10242++)
                {
                    int _10246 = 0;
                    for (;;)
                    {
                        if (_10246 < 5)
                        {
                            int2 _7265 = _10045 + (_1085[_10242] * _1094[_10246].xx);
                            bool _7268 = any(bool2(_7265.x < int2(0, 0).x, _7265.y < int2(0, 0).y));
                            bool _7276;
                            if (!_7268)
                            {
                                _7276 = any(bool2(_7265.x >= cbFI_MvDepthLaneSize.x, _7265.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7276 = _7268;
                            }
                            if (_7276)
                            {
                                _11940 = _10243;
                                break;
                            }
                            uint4 _7354 = r_warped_motion_qdata_tp1.Load(int3(_7265, 0));
                            uint _7355 = _7354.x;
                            if (_7355 != 0u)
                            {
                                _11940 = min(_10243, _7355);
                                break;
                            }
                            _10246++;
                            continue;
                        }
                        else
                        {
                            _11940 = _10243;
                            break;
                        }
                    }
                }
                float _10245;
                if (_10243 == 4294967295u)
                {
                    _10245 = -1.0f;
                }
                else
                {
                    float _10244;
                    if (_10243 == 0u)
                    {
                        _10244 = -1.0f;
                    }
                    else
                    {
                        _10244 = float((_10243 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10245 = _10244;
                }
                _10258 = _10245;
                break;
            } while(false);
            float _4576 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4580 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4586;
            if (_4580)
            {
                _4586 = _10261.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4586 = _4580;
            }
            bool _4591;
            if (_4586)
            {
                bool _7374 = all(bool2(_10017.x > 0.0f.xx.x, _10017.y > 0.0f.xx.y));
                bool _7380;
                if (_7374)
                {
                    _7380 = all(bool2(_10017.x < 1.0f.xx.x, _10017.y < 1.0f.xx.y));
                }
                else
                {
                    _7380 = _7374;
                }
                _4591 = _7380;
            }
            else
            {
                _4591 = _4586;
            }
            float4 _10302;
            if (_4591)
            {
                float _10277;
                if (_10258 >= 0.0f)
                {
                    _10277 = _10258 - _4576;
                }
                else
                {
                    float _10273;
                    _10273 = 2.0f;
                    float _7437;
                    for (int _10272 = 0; _10272 < 24; _10273 = _7437, _10272++)
                    {
                        float _7401 = float(_10272 & 7) * 0.785398185253143310546875f;
                        int _7403 = _10272 >> 3;
                        int _10274;
                        if (_7403 == 0)
                        {
                            _10274 = 16;
                        }
                        else
                        {
                            _10274 = (_7403 == 1) ? 48 : 96;
                        }
                        uint _7469_dummy_parameter;
                        _7437 = min(_10273, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10017 + ((cbFI_MvDepthLaneSizeRcp * float(_10274)) * float2(cos(_7401), sin(_7401))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7469_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10277 = _10273;
                }
                uint _7501_dummy_parameter;
                float4 _10303;
                if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7501_dummy_parameter))))), 0)).x) > ((exp((_10277 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10303 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10303 = 1.0f.xxxx;
                }
                _10302 = _10303;
            }
            else
            {
                _10302 = 1.0f.xxxx;
            }
            bool _4618 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4624;
            if (_4618)
            {
                _4624 = _10261.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4624 = _4618;
            }
            bool _4629;
            if (_4624)
            {
                bool _7526 = all(bool2(_10015.x > 0.0f.xx.x, _10015.y > 0.0f.xx.y));
                bool _7532;
                if (_7526)
                {
                    _7532 = all(bool2(_10015.x < 1.0f.xx.x, _10015.y < 1.0f.xx.y));
                }
                else
                {
                    _7532 = _7526;
                }
                _4629 = _7532;
            }
            else
            {
                _4629 = _4624;
            }
            float4 _10306;
            if (_4629)
            {
                float _10297;
                if (_10258 >= 0.0f)
                {
                    _10297 = _10258 - _4576;
                }
                else
                {
                    float _10293;
                    _10293 = 2.0f;
                    float _7589;
                    for (int _10292 = 0; _10292 < 24; _10293 = _7589, _10292++)
                    {
                        float _7553 = float(_10292 & 7) * 0.785398185253143310546875f;
                        int _7555 = _10292 >> 3;
                        int _10294;
                        if (_7555 == 0)
                        {
                            _10294 = 16;
                        }
                        else
                        {
                            _10294 = (_7555 == 1) ? 48 : 96;
                        }
                        uint _7605_dummy_parameter;
                        _7589 = min(_10293, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10015 + ((cbFI_MvDepthLaneSizeRcp * float(_10294)) * float2(cos(_7553), sin(_7553))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7605_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10297 = _10293;
                }
                uint _7653_dummy_parameter;
                float4 _10307;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7653_dummy_parameter))))), 0)).x) > ((exp((_10297 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9861 = _10302;
                    _9861.x = 0.0f;
                    _10307 = _9861;
                }
                else
                {
                    _10307 = _10302;
                }
                _10306 = _10307;
            }
            else
            {
                _10306 = _10302;
            }
            float4 _10358;
            if (any(bool4(_10306.x < 1.0f.xxxx.x, _10306.y < 1.0f.xxxx.y, _10306.z < 1.0f.xxxx.z, _10306.w < 1.0f.xxxx.w)))
            {
                float4 _4659 = _10261 * _10306;
                float _4661 = dot(_4659, 1.0f.xxxx);
                float4 _10359;
                if (_4661 > 0.0f)
                {
                    _10359 = _4659 / _4661.xxxx;
                }
                else
                {
                    bool _4672 = _10306.y == 0.0f;
                    bool _4678;
                    if (_4672)
                    {
                        _4678 = _10306.x > 0.0f;
                    }
                    else
                    {
                        _4678 = _4672;
                    }
                    bool _4683;
                    if (_4678)
                    {
                        bool _7678 = all(bool2(_10015.x > 0.0f.xx.x, _10015.y > 0.0f.xx.y));
                        bool _7684;
                        if (_7678)
                        {
                            _7684 = all(bool2(_10015.x < 1.0f.xx.x, _10015.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7684 = _7678;
                        }
                        _4683 = _7684;
                    }
                    else
                    {
                        _4683 = _4678;
                    }
                    float4 _10360;
                    if (_4683)
                    {
                        _10360 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4688 = _10306.x == 0.0f;
                        bool _4694;
                        if (_4688)
                        {
                            _4694 = _10306.y > 0.0f;
                        }
                        else
                        {
                            _4694 = _4688;
                        }
                        bool _4699;
                        if (_4694)
                        {
                            bool _7689 = all(bool2(_10017.x > 0.0f.xx.x, _10017.y > 0.0f.xx.y));
                            bool _7695;
                            if (_7689)
                            {
                                _7695 = all(bool2(_10017.x < 1.0f.xx.x, _10017.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7695 = _7689;
                            }
                            _4699 = _7695;
                        }
                        else
                        {
                            _4699 = _4694;
                        }
                        bool4 _11971 = _4699.xxxx;
                        _10360 = float4(_11971.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10261.x, _11971.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10261.y, _11971.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10261.z, _11971.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10261.w);
                    }
                    _10359 = _10360;
                }
                _10358 = _10359;
            }
            else
            {
                _10358 = _10261;
            }
            _10357 = _10358;
        }
        else
        {
            _10357 = _10261;
        }
        float4 _10903;
        bool _10923;
        float3 _11037;
        if (((cbFI_pad0 & 32768u) != 0u) && _4533)
        {
            bool _4716 = _10357.x > 0.00999999977648258209228515625f;
            bool _4719 = _10357.y > 0.00999999977648258209228515625f;
            bool _4728 = (_10357.z + _10357.w) > 0.0199999995529651641845703125f;
            bool _4734;
            if (_4728)
            {
                bool _7700 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
                bool _7706;
                if (_7700)
                {
                    _7706 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
                }
                else
                {
                    _7706 = _7700;
                }
                _4734 = _7706;
            }
            else
            {
                _4734 = _4728;
            }
            bool _4739;
            if (_4734)
            {
                bool _7711 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
                bool _7717;
                if (_7711)
                {
                    _7717 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
                }
                else
                {
                    _7717 = _7711;
                }
                _4739 = _7717;
            }
            else
            {
                _4739 = _4734;
            }
            bool _4746;
            if (_4739)
            {
                float _10368;
                do
                {
                    bool _7800 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
                    bool _7806;
                    if (_7800)
                    {
                        _7806 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7806 = _7800;
                    }
                    bool _7737 = !_7806;
                    bool _7744;
                    if (!_7737)
                    {
                        bool _7811 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
                        bool _7817;
                        if (_7811)
                        {
                            _7817 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7817 = _7811;
                        }
                        _7744 = !_7817;
                    }
                    else
                    {
                        _7744 = _7737;
                    }
                    if (_7744)
                    {
                        _10368 = 0.0f;
                        break;
                    }
                    uint _7824_dummy_parameter;
                    uint _7840_dummy_parameter;
                    float4 _7765 = mul(float4((float2(_10018.x, 1.0f - _10018.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7824_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7767 = _7765.w;
                    if (abs(_7767) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10368 = 0.0f;
                        break;
                    }
                    float _7778 = abs(cbFI_DeviceToViewDepth.y / ((_7765.z / _7767) - cbFI_DeviceToViewDepth.x));
                    float _7781 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7840_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10368 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7778 - _7781) / max(max(_7778, _7781), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4746 = _10368 < 0.5f;
            }
            else
            {
                _4746 = _4739;
            }
            float4 _10383;
            if (_4746)
            {
                uint _7890_dummy_parameter;
                uint _7921_dummy_parameter;
                float4 _10384;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7890_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7921_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10384 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10384 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10383 = _10384;
            }
            else
            {
                _10383 = 1.0f.xxxx;
            }
            bool _4770;
            if (_6822)
            {
                bool _7950 = all(bool2(_10015.x > 0.0f.xx.x, _10015.y > 0.0f.xx.y));
                bool _7956;
                if (_7950)
                {
                    _7956 = all(bool2(_10015.x < 1.0f.xx.x, _10015.y < 1.0f.xx.y));
                }
                else
                {
                    _7956 = _7950;
                }
                _4770 = _7956;
            }
            else
            {
                _4770 = _6822;
            }
            bool _4776;
            if (_6822)
            {
                bool _7961 = all(bool2(_10017.x > 0.0f.xx.x, _10017.y > 0.0f.xx.y));
                bool _7967;
                if (_7961)
                {
                    _7967 = all(bool2(_10017.x < 1.0f.xx.x, _10017.y < 1.0f.xx.y));
                }
                else
                {
                    _7967 = _7961;
                }
                _4776 = _7967;
            }
            else
            {
                _4776 = _6822;
            }
            bool _4782;
            if (_6854)
            {
                bool _7972 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
                bool _7978;
                if (_7972)
                {
                    _7978 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
                }
                else
                {
                    _7978 = _7972;
                }
                _4782 = _7978;
            }
            else
            {
                _4782 = _6854;
            }
            bool _4788;
            if (_6854)
            {
                bool _7983 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
                bool _7989;
                if (_7983)
                {
                    _7989 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
                }
                else
                {
                    _7989 = _7983;
                }
                _4788 = _7989;
            }
            else
            {
                _4788 = _6854;
            }
            bool _4791 = _4782 != _4788;
            bool _4797;
            if (_4791)
            {
                _4797 = _4770 || _4776;
            }
            else
            {
                _4797 = _4791;
            }
            float4 _10471;
            if (_4797)
            {
                float4 _9888 = _10383;
                _9888.z = 0.0f;
                _9888.w = 0.0f;
                _10471 = _9888;
            }
            else
            {
                _10471 = _10383;
            }
            bool _4804 = _4770 && _4716;
            bool _4807 = _4776 && _4719;
            float4 _10576;
            float3 _11116;
            if (_4804 || _4807)
            {
                float _10466;
                do
                {
                    uint4 _8128 = r_warped_motion_qdata_tp1.Load(int3(_10045, 0));
                    uint _8129 = _8128.x;
                    if (_8129 != 0u)
                    {
                        float _10465;
                        if (_8129 == 0u)
                        {
                            _10465 = -1.0f;
                        }
                        else
                        {
                            _10465 = float((_8129 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10466 = _10465;
                        break;
                    }
                    int _10448;
                    uint _10449;
                    _10449 = _8129;
                    _10448 = -1;
                    uint _10464;
                    for (; _10448 <= 1; _10449 = _10464, _10448++)
                    {
                        _10464 = _10449;
                        for (int _10462 = -1; _10462 <= 1; )
                        {
                            _10464 = max(_10464, r_warped_motion_qdata_tp1.Load(int3(clamp(_10045 + int2(_10462, _10448), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10462++;
                            continue;
                        }
                    }
                    if (_10449 != 0u)
                    {
                        float _10461;
                        if (_10449 == 0u)
                        {
                            _10461 = -1.0f;
                        }
                        else
                        {
                            _10461 = float((_10449 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10466 = _10461;
                        break;
                    }
                    uint _10451;
                    _10451 = 4294967295u;
                    uint _11941;
                    for (int _10450 = 0; _10450 < 8; _10451 = _11941, _10450++)
                    {
                        int _10454 = 0;
                        for (;;)
                        {
                            if (_10454 < 5)
                            {
                                int2 _8079 = _10045 + (_1085[_10450] * _1094[_10454].xx);
                                bool _8082 = any(bool2(_8079.x < int2(0, 0).x, _8079.y < int2(0, 0).y));
                                bool _8090;
                                if (!_8082)
                                {
                                    _8090 = any(bool2(_8079.x >= cbFI_MvDepthLaneSize.x, _8079.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8090 = _8082;
                                }
                                if (_8090)
                                {
                                    _11941 = _10451;
                                    break;
                                }
                                uint4 _8168 = r_warped_motion_qdata_tp1.Load(int3(_8079, 0));
                                uint _8169 = _8168.x;
                                if (_8169 != 0u)
                                {
                                    _11941 = min(_10451, _8169);
                                    break;
                                }
                                _10454++;
                                continue;
                            }
                            else
                            {
                                _11941 = _10451;
                                break;
                            }
                        }
                    }
                    float _10453;
                    if (_10451 == 4294967295u)
                    {
                        _10453 = -1.0f;
                    }
                    else
                    {
                        float _10452;
                        if (_10451 == 0u)
                        {
                            _10452 = -1.0f;
                        }
                        else
                        {
                            _10452 = float((_10451 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10453 = _10452;
                    }
                    _10466 = _10453;
                    break;
                } while(false);
                bool _4815 = _10466 < 0.0f;
                float _10467;
                if (_4815)
                {
                    _10467 = 0.0f;
                }
                else
                {
                    _10467 = _10466 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8190_dummy_parameter;
                uint _8222_dummy_parameter;
                float4 _10504;
                if ((_4815 && _4804) && _4807)
                {
                    uint _8254_dummy_parameter;
                    float _8278 = log(((r_depth_tm1.Load(int3(int2(floor(_10015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8254_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8286_dummy_parameter;
                    float _8310 = log(((r_depth_tp1.Load(int3(int2(floor(_10017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8286_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10505;
                    if (_8278 > (_8310 + 0.07999999821186065673828125f))
                    {
                        float4 _9892 = _10471;
                        _9892.x = 0.0f;
                        _10505 = _9892;
                    }
                    else
                    {
                        float4 _10506;
                        if (_8310 > (_8278 + 0.07999999821186065673828125f))
                        {
                            float4 _9894 = _10471;
                            _9894.y = 0.0f;
                            _10506 = _9894;
                        }
                        else
                        {
                            _10506 = _10471;
                        }
                        _10505 = _10506;
                    }
                    _10504 = _10505;
                }
                else
                {
                    _10504 = _10471;
                }
                float _4867 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4869 = _10466 >= 0.0f;
                float _10487;
                if (_4869)
                {
                    _10487 = _10466 - _4867;
                }
                else
                {
                    float _10483;
                    if (_4804)
                    {
                        float _10482;
                        _10482 = 2.0f;
                        float _8368;
                        for (int _10481 = 0; _10481 < 24; _10482 = _8368, _10481++)
                        {
                            float _8332 = float(_10481 & 7) * 0.785398185253143310546875f;
                            int _8334 = _10481 >> 3;
                            int _10484;
                            if (_8334 == 0)
                            {
                                _10484 = 16;
                            }
                            else
                            {
                                _10484 = (_8334 == 1) ? 48 : 96;
                            }
                            uint _8384_dummy_parameter;
                            _8368 = min(_10482, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10015 + ((cbFI_MvDepthLaneSizeRcp * float(_10484)) * float2(cos(_8332), sin(_8332))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8384_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10483 = _10482;
                    }
                    else
                    {
                        _10483 = 0.0f;
                    }
                    _10487 = _10483;
                }
                float _10494;
                if (_4869)
                {
                    _10494 = _10466 - _4867;
                }
                else
                {
                    float _10490;
                    if (_4807)
                    {
                        float _10489;
                        _10489 = 2.0f;
                        float _8482;
                        for (int _10488 = 0; _10488 < 24; _10489 = _8482, _10488++)
                        {
                            float _8446 = float(_10488 & 7) * 0.785398185253143310546875f;
                            int _8448 = _10488 >> 3;
                            int _10491;
                            if (_8448 == 0)
                            {
                                _10491 = 16;
                            }
                            else
                            {
                                _10491 = (_8448 == 1) ? 48 : 96;
                            }
                            uint _8514_dummy_parameter;
                            _8482 = min(_10489, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10017 + ((cbFI_MvDepthLaneSizeRcp * float(_10491)) * float2(cos(_8446), sin(_8446))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8514_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10490 = _10489;
                    }
                    else
                    {
                        _10490 = 0.0f;
                    }
                    _10494 = _10490;
                }
                float _10495;
                if (_4804)
                {
                    uint _8546_dummy_parameter;
                    _10495 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8546_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10495 = 0.0f;
                }
                float _10496;
                if (_4807)
                {
                    uint _8566_dummy_parameter;
                    _10496 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8566_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10496 = 0.0f;
                }
                bool _4924;
                if (_4804)
                {
                    _4924 = _10495 > ((exp((_10487 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4924 = _4804;
                }
                float4 _10512;
                if (_4924)
                {
                    float4 _9896 = _10504;
                    _9896.x = 0.0f;
                    _10512 = _9896;
                }
                else
                {
                    _10512 = _10504;
                }
                bool _4936;
                if (_4807)
                {
                    _4936 = _10496 > ((exp((_10494 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4936 = _4807;
                }
                float4 _10514;
                if (_4936)
                {
                    float4 _9898 = _10512;
                    _9898.y = 0.0f;
                    _10514 = _9898;
                }
                else
                {
                    _10514 = _10512;
                }
                float4 _10577;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4869)
                {
                    bool _4956;
                    if (_4804)
                    {
                        _4956 = _10495 < ((exp((_10487 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4956 = _4804;
                    }
                    float4 _10516;
                    if (_4956)
                    {
                        float4 _9900 = _10514;
                        _9900.x = 0.0f;
                        _10516 = _9900;
                    }
                    else
                    {
                        _10516 = _10514;
                    }
                    bool _4968;
                    if (_4807)
                    {
                        _4968 = _10496 < ((exp((_10494 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4968 = _4807;
                    }
                    float4 _10578;
                    if (_4968)
                    {
                        float4 _9902 = _10516;
                        _9902.y = 0.0f;
                        _10578 = _9902;
                    }
                    else
                    {
                        _10578 = _10516;
                    }
                    _10577 = _10578;
                }
                else
                {
                    _10577 = _10514;
                }
                _11116 = float3(_10467, log(((r_depth_tm1.Load(int3(int2(floor(_10015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8190_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10017 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8222_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10576 = _10577;
            }
            else
            {
                _11116 = float3(0.0f, 0.0f, 0.5f);
                _10576 = _10471;
            }
            bool _4979 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4728;
            bool _4985;
            if (_4979)
            {
                _4985 = _4782 || _4788;
            }
            else
            {
                _4985 = _4979;
            }
            float4 _10599;
            if (_4985)
            {
                float _10571;
                do
                {
                    uint4 _8746 = r_warped_motion_qdata_tp1.Load(int3(_10045, 0));
                    uint _8747 = _8746.x;
                    if (_8747 != 0u)
                    {
                        float _10570;
                        if (_8747 == 0u)
                        {
                            _10570 = -1.0f;
                        }
                        else
                        {
                            _10570 = float((_8747 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10571 = _10570;
                        break;
                    }
                    int _10553;
                    uint _10554;
                    _10554 = _8747;
                    _10553 = -1;
                    uint _10569;
                    for (; _10553 <= 1; _10554 = _10569, _10553++)
                    {
                        _10569 = _10554;
                        for (int _10567 = -1; _10567 <= 1; )
                        {
                            _10569 = max(_10569, r_warped_motion_qdata_tp1.Load(int3(clamp(_10045 + int2(_10567, _10553), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10567++;
                            continue;
                        }
                    }
                    if (_10554 != 0u)
                    {
                        float _10566;
                        if (_10554 == 0u)
                        {
                            _10566 = -1.0f;
                        }
                        else
                        {
                            _10566 = float((_10554 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10571 = _10566;
                        break;
                    }
                    uint _10556;
                    _10556 = 4294967295u;
                    uint _11942;
                    for (int _10555 = 0; _10555 < 8; _10556 = _11942, _10555++)
                    {
                        int _10559 = 0;
                        for (;;)
                        {
                            if (_10559 < 5)
                            {
                                int2 _8697 = _10045 + (_1085[_10555] * _1094[_10559].xx);
                                bool _8700 = any(bool2(_8697.x < int2(0, 0).x, _8697.y < int2(0, 0).y));
                                bool _8708;
                                if (!_8700)
                                {
                                    _8708 = any(bool2(_8697.x >= cbFI_MvDepthLaneSize.x, _8697.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8708 = _8700;
                                }
                                if (_8708)
                                {
                                    _11942 = _10556;
                                    break;
                                }
                                uint4 _8786 = r_warped_motion_qdata_tp1.Load(int3(_8697, 0));
                                uint _8787 = _8786.x;
                                if (_8787 != 0u)
                                {
                                    _11942 = min(_10556, _8787);
                                    break;
                                }
                                _10559++;
                                continue;
                            }
                            else
                            {
                                _11942 = _10556;
                                break;
                            }
                        }
                    }
                    float _10558;
                    if (_10556 == 4294967295u)
                    {
                        _10558 = -1.0f;
                    }
                    else
                    {
                        float _10557;
                        if (_10556 == 0u)
                        {
                            _10557 = -1.0f;
                        }
                        else
                        {
                            _10557 = float((_10556 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10558 = _10557;
                    }
                    _10571 = _10558;
                    break;
                } while(false);
                float4 _10600;
                if (_10571 >= 0.0f)
                {
                    float _8808 = (exp((_10571 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5004;
                    if (_4782)
                    {
                        uint _8815_dummy_parameter;
                        _5004 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8815_dummy_parameter))))), 0)).x) > _8808;
                    }
                    else
                    {
                        _5004 = _4782;
                    }
                    float4 _10589;
                    if (_5004)
                    {
                        float4 _9904 = _10576;
                        _9904.z = 0.0f;
                        _10589 = _9904;
                    }
                    else
                    {
                        _10589 = _10576;
                    }
                    bool _5016;
                    if (_4788)
                    {
                        uint _8835_dummy_parameter;
                        _5016 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8835_dummy_parameter))))), 0)).x) > _8808;
                    }
                    else
                    {
                        _5016 = _4788;
                    }
                    float4 _10601;
                    if (_5016)
                    {
                        float4 _9906 = _10589;
                        _9906.w = 0.0f;
                        _10601 = _9906;
                    }
                    else
                    {
                        _10601 = _10589;
                    }
                    _10600 = _10601;
                }
                else
                {
                    _10600 = _10576;
                }
                _10599 = _10600;
            }
            else
            {
                _10599 = _10576;
            }
            bool _5024 = _4770 != _4776;
            bool _5031;
            if (_5024)
            {
                _5031 = _4770 ? _4716 : _4719;
            }
            else
            {
                _5031 = _5024;
            }
            bool _5038;
            if (_5031)
            {
                _5038 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5038 = _5031;
            }
            float4 _10684;
            if (_5038)
            {
                bool2 _5043 = _4770.xx;
                float2 _5044 = float2(_5043.x ? _10015.x : _10017.x, _5043.y ? _10015.y : _10017.y);
                float _10591;
                if (_4770)
                {
                    uint _8855_dummy_parameter;
                    _10591 = r_depth_tm1.Load(int3(int2(floor(_5044 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8855_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8871_dummy_parameter;
                    _10591 = r_depth_tp1.Load(int3(int2(floor(_5044 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8871_dummy_parameter))))), 0)).x;
                }
                float4x4 _10592;
                if (_4770)
                {
                    _10592 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10592 = cbFI_MotionTP1ToTM1;
                }
                float2 _10593;
                do
                {
                    float _8898 = _5044.x;
                    float _8901 = 1.0f - _5044.y;
                    float4 _8912 = mul(float4((float2(_8898, _8901) * 2.0f) - 1.0f.xx, _10591, 1.0f), _10592);
                    float _8914 = _8912.w;
                    if (!(_8914 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10593 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8927 = ((_8912.xy / _8914.xx) + 1.0f.xx) * 0.5f;
                    _10593 = float2(_8927.x - _8898, _8901 - _8927.y);
                    break;
                } while(false);
                float2 _5074 = float2(cbFI_DisplaySize);
                float4 _10685;
                if (!(length(((_5044 + _10593) - float2(_5043.x ? _10017.x : _10015.x, _5043.y ? _10017.y : _10015.y)) * _5074) <= ((0.100000001490116119384765625f * length(_10593 * _5074)) + 8.0f)))
                {
                    float4 _10686;
                    if (_4770)
                    {
                        float4 _9916 = _10599;
                        _9916.x = 0.0f;
                        _10686 = _9916;
                    }
                    else
                    {
                        float4 _9918 = _10599;
                        _9918.y = 0.0f;
                        _10686 = _9918;
                    }
                    _10685 = _10686;
                }
                else
                {
                    _10685 = _10599;
                }
                _10684 = _10685;
            }
            else
            {
                _10684 = _10599;
            }
            float4 _5099 = _10357 * _10684;
            float _5101 = dot(_5099, 1.0f.xxxx);
            float4 _10904;
            bool _10924;
            if (_5101 > 0.0f)
            {
                _10924 = _10168;
                _10904 = _5099 / _5101.xxxx;
            }
            else
            {
                bool _5112 = any(bool4(_10684.x < 1.0f.xxxx.x, _10684.y < 1.0f.xxxx.y, _10684.z < 1.0f.xxxx.z, _10684.w < 1.0f.xxxx.w));
                if (_5112)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8949;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8949);
                    }
                }
                bool4 _11974 = _5112.xxxx;
                _10924 = _5112 ? true : _10168;
                _10904 = float4(_11974.x ? 0.0f.xxxx.x : _10357.x, _11974.y ? 0.0f.xxxx.y : _10357.y, _11974.z ? 0.0f.xxxx.z : _10357.z, _11974.w ? 0.0f.xxxx.w : _10357.w);
            }
            _11037 = _11116;
            _10923 = _10924;
            _10903 = _10904;
        }
        else
        {
            _11037 = float3(0.0f, 0.0f, 0.5f);
            _10923 = _10168;
            _10903 = _10357;
        }
        uint _5121 = (cbFI_pad0 >> 24u) & 31u;
        uint _5125 = (cbFI_pad0 >> 16u) & 255u;
        bool _5127 = _5121 != 0u;
        bool _5129 = _5125 == 12u;
        bool _5132 = _5125 == 13u;
        float4 _10920;
        if ((_5127 || _5129) || _5132)
        {
            float _10687;
            do
            {
                bool _9033 = all(bool2(_10018.x > 0.0f.xx.x, _10018.y > 0.0f.xx.y));
                bool _9039;
                if (_9033)
                {
                    _9039 = all(bool2(_10018.x < 1.0f.xx.x, _10018.y < 1.0f.xx.y));
                }
                else
                {
                    _9039 = _9033;
                }
                bool _8970 = !_9039;
                bool _8977;
                if (!_8970)
                {
                    bool _9044 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
                    bool _9050;
                    if (_9044)
                    {
                        _9050 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9050 = _9044;
                    }
                    _8977 = !_9050;
                }
                else
                {
                    _8977 = _8970;
                }
                if (_8977)
                {
                    _10687 = 0.0f;
                    break;
                }
                uint _9057_dummy_parameter;
                uint _9073_dummy_parameter;
                float4 _8998 = mul(float4((float2(_10018.x, 1.0f - _10018.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10018 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9057_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9000 = _8998.w;
                if (abs(_9000) < 9.9999999747524270787835121154785e-07f)
                {
                    _10687 = 0.0f;
                    break;
                }
                float _9011 = abs(cbFI_DeviceToViewDepth.y / ((_8998.z / _9000) - cbFI_DeviceToViewDepth.x));
                float _9014 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9073_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10687 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9011 - _9014) / max(max(_9011, _9014), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9121 = all(bool2(_10019.x > 0.0f.xx.x, _10019.y > 0.0f.xx.y));
            bool _9127;
            if (_9121)
            {
                _9127 = all(bool2(_10019.x < 1.0f.xx.x, _10019.y < 1.0f.xx.y));
            }
            else
            {
                _9127 = _9121;
            }
            float _10688;
            if (_9127)
            {
                uint _9134_dummy_parameter;
                _10688 = length((_5908 + (r_motion_tp1.Load(int3(int2(floor(_10019 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9134_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10688 = 1000000.0f;
            }
            float _10699;
            if ((_5121 & 1u) != 0u)
            {
                _10699 = _10687;
            }
            else
            {
                _10699 = 1.0f;
            }
            float _10700;
            if ((_5121 & 2u) != 0u)
            {
                _10700 = _10699 * (1.0f - smoothstep(2.0f, 8.0f, _10688));
            }
            else
            {
                _10700 = _10699;
            }
            float _10701;
            if ((_5121 & 4u) != 0u)
            {
                _10701 = _10700 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6629 - _6637) - length(_6613 - _6621))));
            }
            else
            {
                _10701 = _10700;
            }
            float _10914;
            if ((_5121 & 8u) != 0u)
            {
                _10914 = lerp(1.0f, _10701, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6613 - _6621)));
            }
            else
            {
                _10914 = _10701;
            }
            bool _5207 = (_5121 & 16u) != 0u;
            bool _5216;
            if (_5207)
            {
                _5216 = length(_10013 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5216 = _5207;
            }
            float _11976 = _5216 ? 1.0f : _10914;
            bool _5222 = _5127 && _6822;
            bool _5227;
            if (_5222)
            {
                bool _9159 = all(bool2(_10015.x > 0.0f.xx.x, _10015.y > 0.0f.xx.y));
                bool _9165;
                if (_9159)
                {
                    _9165 = all(bool2(_10015.x < 1.0f.xx.x, _10015.y < 1.0f.xx.y));
                }
                else
                {
                    _9165 = _9159;
                }
                _5227 = _9165;
            }
            else
            {
                _5227 = _5222;
            }
            bool _5232;
            if (_5227)
            {
                bool _9170 = all(bool2(_10017.x > 0.0f.xx.x, _10017.y > 0.0f.xx.y));
                bool _9176;
                if (_9170)
                {
                    _9176 = all(bool2(_10017.x < 1.0f.xx.x, _10017.y < 1.0f.xx.y));
                }
                else
                {
                    _9176 = _9170;
                }
                _5232 = _9176;
            }
            else
            {
                _5232 = _5227;
            }
            float4 _10921;
            if (_5232)
            {
                float _5238 = _10903.x + _10903.y;
                float _5247 = (_10903.z + _10903.w) * (1.0f - _11976);
                float _10917;
                if (_5238 > 9.9999997473787516355514526367188e-06f)
                {
                    _10917 = _10903.x / _5238;
                }
                else
                {
                    _10917 = _4203;
                }
                _10921 = float4(_10903.x + (_5247 * _10917), _10903.y + (_5247 * (1.0f - _10917)), _10903.zw * _11976);
            }
            else
            {
                _10921 = _10903;
            }
            _10920 = _10921;
        }
        else
        {
            _10920 = _10903;
        }
        float3 _11744;
        if (_10923)
        {
            float3 _9182 = r_current_interpolation_source.Load(int3(_3591, 0)).xyz;
            float3 _11745;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6822)
            {
                uint _9189_dummy_parameter;
                float _11028;
                _11028 = r_depth_tm1.Load(int3(int2(floor(_10015 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9189_dummy_parameter))))), 0)).x;
                float _5359;
                for (int _11027 = 0; _11027 < 24; _11028 = _5359, _11027++)
                {
                    float _5331 = float(_11027 & 7) * 0.785398185253143310546875f;
                    int _5333 = _11027 >> 3;
                    int _11795;
                    if (_5333 == 0)
                    {
                        _11795 = 16;
                    }
                    else
                    {
                        _11795 = (_5333 == 1) ? 48 : 96;
                    }
                    uint _9209_dummy_parameter;
                    _5359 = max(_11028, r_depth_tm1.Load(int3(int2(floor(clamp(_10015 + ((cbFI_MvDepthLaneSizeRcp * float(_11795)) * float2(cos(_5331), sin(_5331))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9209_dummy_parameter))))), 0)).x);
                }
                float2 _11029;
                do
                {
                    float _9231 = 1.0f - _10015.y;
                    float4 _9242 = mul(float4((float2(_10015.x, _9231) * 2.0f) - 1.0f.xx, _11028, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9244 = _9242.w;
                    if (!(_9244 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11029 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9257 = ((_9242.xy / _9244.xx) + 1.0f.xx) * 0.5f;
                    _11029 = float2(_9257.x - _10015.x, _9231 - _9257.y);
                    break;
                } while(false);
                float2 _5370 = _10015 + _11029;
                bool _9275 = all(bool2(_5370.x > 0.0f.xx.x, _5370.y > 0.0f.xx.y));
                bool _9281;
                if (_9275)
                {
                    _9281 = all(bool2(_5370.x < 1.0f.xx.x, _5370.y < 1.0f.xx.y));
                }
                else
                {
                    _9281 = _9275;
                }
                float3 _11746;
                if (_9281)
                {
                    float _5376 = abs(cbFI_DeviceToViewDepth.y / (_11028 - cbFI_DeviceToViewDepth.x));
                    uint _9301_dummy_parameter;
                    int2 _9301 = int2(spvTextureSize(r_depth_m2, uint(0), _9301_dummy_parameter));
                    float _5380 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5370 * float2(_9301))), int2(0, 0), _9301 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11751;
                    if (abs(_5380 - _5376) <= (0.20000000298023223876953125f * max(_5380, _5376)))
                    {
                        uint _9335_dummy_parameter;
                        int2 _9335 = int2(spvTextureSize(r_colour_m2, uint(0), _9335_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9358;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9358);
                        }
                        _11751 = r_colour_m2.Load(int3(clamp(int2(floor(_5370 * float2(_9335))), int2(0, 0), _9335 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9368;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9368);
                        }
                        _11751 = _9182;
                    }
                    _11746 = _11751;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9378;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9378);
                    }
                    _11746 = _9182;
                }
                _11745 = _11746;
            }
            else
            {
                _11745 = _9182;
            }
            _11744 = _11745;
        }
        else
        {
            _11744 = (((_6613 * _10920.x) + (_6621 * _10920.y)) + (_6629 * _10920.z)) + (_6637 * _10920.w);
        }
        uint _5408 = cbFI_pad0 & 255u;
        bool _11636;
        float3 _11743;
        if (_5408 != 0u)
        {
            float3 _5413 = r_present_backbuffer.Load(int3(_3591, 0)).xyz;
            float3 _5417 = r_current_interpolation_source.Load(int3(_3591, 0)).xyz;
            float3 _5421 = abs(_5413 - _5417);
            float3 _11032;
            if (_5408 == 2u)
            {
                _11032 = (abs(_5417) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11032 = 0.000244140625f.xxx;
            }
            bool _5437 = any(bool3(_5421.x > _11032.x, _5421.y > _11032.y, _5421.z > _11032.z));
            bool3 _11977 = _5437.xxx;
            _11743 = float3(_11977.x ? _5413.x : _11744.x, _11977.y ? _5413.y : _11744.y, _11977.z ? _5413.z : _11744.z);
            _11636 = _5437;
        }
        else
        {
            _11743 = _11744;
            _11636 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9393;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9393);
        }
        float3 _11726;
        if (_5125 == 1u)
        {
            _11726 = lerp(_6613, _6621, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11727;
            if (_5125 == 2u)
            {
                _11727 = lerp(_6629, _6637, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11728;
                if (_5125 == 3u)
                {
                    _11728 = float(_11636).xxx;
                }
                else
                {
                    float3 _11729;
                    if (_5125 == 4u)
                    {
                        _11729 = float3(((_10013 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11730;
                        if (_5125 == 5u)
                        {
                            _11730 = float3(((_5908 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11731;
                            if (_5125 == 6u)
                            {
                                _11731 = float3(_10920.xy, _10920.z + _10920.w);
                            }
                            else
                            {
                                float3 _11732;
                                if (_5125 == 7u)
                                {
                                    _11732 = r_current_interpolation_source.Load(int3(_3591, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11733;
                                    if (_5125 == 8u)
                                    {
                                        _11733 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3978, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11734;
                                        if (_5129)
                                        {
                                            uint _9415_dummy_parameter;
                                            uint _9447_dummy_parameter;
                                            _11734 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3978 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9415_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9447_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11735;
                                            if (_5132)
                                            {
                                                _11735 = _6629;
                                            }
                                            else
                                            {
                                                float3 _11736;
                                                if (_5125 == 20u)
                                                {
                                                    _11736 = _6613;
                                                }
                                                else
                                                {
                                                    float3 _11737;
                                                    if (_5125 == 21u)
                                                    {
                                                        _11737 = _6621;
                                                    }
                                                    else
                                                    {
                                                        float3 _11738;
                                                        if (_5125 == 22u)
                                                        {
                                                            _11738 = _6637;
                                                        }
                                                        else
                                                        {
                                                            float3 _11739;
                                                            if (_5125 == 18u)
                                                            {
                                                                _11739 = _11404;
                                                            }
                                                            else
                                                            {
                                                                float3 _11740;
                                                                if (_5125 == 19u)
                                                                {
                                                                    _11740 = _11218;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11979 = (_5125 == 23u).xxx;
                                                                    _11740 = float3(_11979.x ? _11037.x : _11743.x, _11979.y ? _11037.y : _11743.y, _11979.z ? _11037.z : _11743.z);
                                                                }
                                                                _11739 = _11740;
                                                            }
                                                            _11738 = _11739;
                                                        }
                                                        _11737 = _11738;
                                                    }
                                                    _11736 = _11737;
                                                }
                                                _11735 = _11736;
                                            }
                                            _11734 = _11735;
                                        }
                                        _11733 = _11734;
                                    }
                                    _11732 = _11733;
                                }
                                _11731 = _11732;
                            }
                            _11730 = _11731;
                        }
                        _11729 = _11730;
                    }
                    _11728 = _11729;
                }
                _11727 = _11728;
            }
            _11726 = _11727;
        }
        float3 _11725;
        if ((_5125 >= 9u) && (_5125 <= 11u))
        {
            uint _5601 = 64u + uint((_10045.y * cbFI_MvDepthLaneSize.x) + _10045.x);
            uint _5605 = rw_nfru_diagnostics.Load<uint>(_5601 * 4 + 0) & 15u;
            float3 _11756;
            if (_5125 == 10u)
            {
                float3 _11724;
                if ((rw_nfru_diagnostics.Load<uint>(_5601 * 4 + 0) & 32u) != 0u)
                {
                    _11724 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11723;
                    if ((rw_nfru_diagnostics.Load<uint>(_5601 * 4 + 0) & 16u) != 0u)
                    {
                        _11723 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5626 = ((rw_nfru_diagnostics.Load<uint>(_5601 * 4 + 0) & 64u) != 0u).xxx;
                        _11723 = float3(_5626.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5626.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5626.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11724 = _11723;
                }
                _11756 = _11724;
            }
            else
            {
                float3 _11757;
                if (_5125 == 11u)
                {
                    uint _5639 = (rw_nfru_diagnostics.Load<uint>(_5601 * 4 + 0) >> 8u) & 15u;
                    uint _5642 = (rw_nfru_diagnostics.Load<uint>(_5601 * 4 + 0) >> 12u) & 15u;
                    float3 _11716;
                    if ((_5605 == 2u) || (_5605 == 3u))
                    {
                        _11716 = _3304[_5605];
                    }
                    else
                    {
                        bool _5654 = _5639 == 3u;
                        bool _5656 = _5642 == 3u;
                        float3 _11717;
                        if (_5654 && _5656)
                        {
                            _11717 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11718;
                            if (_5654)
                            {
                                _11718 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11719;
                                if (_5656)
                                {
                                    _11719 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11720;
                                    if ((_5639 == 4u) || (_5642 == 4u))
                                    {
                                        _11720 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11721;
                                        if ((_5639 == 1u) || (_5642 == 1u))
                                        {
                                            _11721 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11981 = (_5605 == 1u).xxx;
                                            _11721 = float3(_11981.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11981.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11981.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11720 = _11721;
                                    }
                                    _11719 = _11720;
                                }
                                _11718 = _11719;
                            }
                            _11717 = _11718;
                        }
                        _11716 = _11717;
                    }
                    _11757 = _11716;
                }
                else
                {
                    _11757 = _3304[min(_5605, 7u)];
                }
                _11756 = _11757;
            }
            _11725 = _11756;
        }
        else
        {
            _11725 = _11726;
        }
        float4 _11760;
        if ((_5125 >= 14u) && (_5125 <= 16u))
        {
            float2 _11758;
            if (_5125 == 14u)
            {
                uint _5712_dummy_parameter;
                uint _5718_dummy_parameter;
                _11758 = r_flow_tm1.Load(int3(clamp(int2(floor(_3978 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5712_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5718_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11759;
                if (_5125 == 16u)
                {
                    uint _9498 = r_warped_flow_qdata_tm1.Load(int3(_3994, 0)).x & 2147483647u;
                    uint _9530 = uint(max((int((_9498 >> 16u) & 15u) - 6), 0));
                    _11759 = ((float2(float((1 - (2 * int((_9498 >> 15u) & 1u))) * int(((_9498 >> uint(7)) & 127u) << _9530)), float((1 - (2 * int((_9498 >> 14u) & 1u))) * int((_9498 & 127u) << _9530))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11759 = _5908 * float2(cbFI_DisplaySize);
                }
                _11758 = _11759;
            }
            uint2 _5751 = uint2(clamp(round(_11758 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5753 = _5751.x;
            uint _5760 = _5751.y;
            _11760 = float4(float(_5753 & 255u), float((_5753 >> 8u) | ((_5760 & 15u) << 4u)), float(_5760 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11761;
            if (_5125 == 17u)
            {
                _11761 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3994, 0)).x != 0u), _4337, 0.0f, 1.0f);
            }
            else
            {
                _11761 = float4(_11725, 1.0f);
            }
            _11760 = _11761;
        }
        rw_output[_3591] = _11760.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5804 = ((uint(_3591.y) * uint(cbFI_DisplaySize.x)) + uint(_3591.x)) * 6u;
            uint _9576 = spvPackHalf2x16(clamp(_6612.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5804 * 4 + 0, (((_9576 & 32767u) >> 4u) | ((((_9576 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6612.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9611 = spvPackHalf2x16(clamp(_6620.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5804 + 1u) * 4 + 0, (((_9611 & 32767u) >> 4u) | ((((_9611 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6620.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9646 = spvPackHalf2x16(clamp(_6628.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5804 + 2u) * 4 + 0, (((_9646 & 32767u) >> 4u) | ((((_9646 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6628.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9681 = spvPackHalf2x16(clamp(_6636.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5804 + 3u) * 4 + 0, (((_9681 & 32767u) >> 4u) | ((((_9681 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6636.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9708 = r_current_interpolation_source.Load(int3(_3591, 0));
            uint _9722 = spvPackHalf2x16(clamp(_9708.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5804 + 4u) * 4 + 0, (((_9722 & 32767u) >> 4u) | ((((_9722 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9708.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11794;
            if (_11636 || (_5125 != 0u))
            {
                _11794 = 4294967295u;
            }
            else
            {
                uint _9757 = spvPackHalf2x16(clamp(_11760.xy, 0.0f.xx, 65000.0f.xx));
                _11794 = (((_9757 & 32767u) >> 4u) | ((((_9757 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11760.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5804 + 5u) * 4 + 0, _11794);
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
