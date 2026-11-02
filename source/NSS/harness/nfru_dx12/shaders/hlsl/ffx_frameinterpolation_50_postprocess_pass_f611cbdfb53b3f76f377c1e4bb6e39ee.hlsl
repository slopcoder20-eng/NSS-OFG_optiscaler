static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3090[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3394 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3394.x >= cbFI_DisplaySize.x, _3394.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3394] = float4(r_present_backbuffer.Load(int3(_3394, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3394] = float4(r_current_interpolation_source.Load(int3(_3394, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3768 = (float2(_3394) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3779 = int2(floor(_3768 * float2(cbFI_MvDepthLaneSize)));
        int2 _3784 = int2(floor(_3768 * float2(cbFI_FlowLaneSize)));
        float4 _5514 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3768 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5520 = r_warped_filled_flow_tm1.Load(int3(_3784, 0)).xy;
        float2 _5526 = r_warped_filled_motion_tp1.Load(int3(_3779, 0)).xy;
        bool _5548 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9080;
        if (_5548)
        {
            float _5561 = ((2.0f * _3768.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9080 = float2(atan(_5561) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3768.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5561 * _5561))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9080 = _3768;
        }
        bool _3805 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9101;
        bool _9122;
        int2 _9133;
        float3 _10178;
        if (_3805)
        {
            float _9082;
            float _9084;
            _9084 = 2.0f;
            _9082 = -1.0f;
            uint _3458[9];
            float _10568;
            float _10571;
            for (int _9081 = 0; _9081 < 9; _9084 = _10571, _9082 = _10568, _9081++)
            {
                _3458[_9081] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3779 + int2((_9081 % 3) - 1, (_9081 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3458[_9081] != 0u)
                {
                    float _10563;
                    if (_3458[_9081] == 0u)
                    {
                        _10563 = -1.0f;
                    }
                    else
                    {
                        _10563 = float((_3458[_9081] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10571 = min(_9084, _10563);
                    _10568 = max(_9082, _10563);
                }
                else
                {
                    _10571 = _9084;
                    _10568 = _9082;
                }
            }
            float _3851 = float(_9082 >= 0.0f);
            float3 _8891 = 0.0f.xxx;
            _8891.y = _3851;
            float2 _9102;
            bool _9123;
            int2 _9134;
            float3 _10179;
            if ((_9082 - _9084) > 0.0199999995529651641845703125f)
            {
                float _9090;
                int2 _9091;
                float2 _9092;
                int2 _9094;
                float2 _9100;
                _9100 = _5526;
                _9094 = _3779;
                _9092 = _5526;
                _9091 = _3779;
                _9090 = -1.0f;
                float _10576;
                int2 _10580;
                float2 _10591;
                int2 _10602;
                float2 _10635;
                float _10681;
                int _9089 = 0;
                float _10544 = 1000000000.0f;
                for (; _9089 < 9; _10544 = _10681, _9100 = _10635, _9094 = _10602, _9092 = _10591, _9091 = _10580, _9090 = _10576, _9089++)
                {
                    if (_3458[_9089] == 0u)
                    {
                        _10681 = _10544;
                        _10635 = _9100;
                        _10602 = _9094;
                        _10591 = _9092;
                        _10580 = _9091;
                        _10576 = _9090;
                        continue;
                    }
                    int2 _3886 = clamp(_3779 + int2((_9089 % 3) - 1, (_9089 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5636 = _3458[_9089] & 2147483647u;
                    uint _5668 = uint(max((int((_5636 >> 16u) & 15u) - 6), 0));
                    float2 _3892 = (float2(float((1 - (2 * int((_5636 >> 15u) & 1u))) * int(((_5636 >> uint(7)) & 127u) << _5668)), float((1 - (2 * int((_5636 >> 14u) & 1u))) * int((_5636 & 127u) << _5668))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10530;
                    if (_3458[_9089] == 0u)
                    {
                        _10530 = -1.0f;
                    }
                    else
                    {
                        _10530 = float((_3458[_9089] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3897 = _10530 - 0.100000001490116119384765625f;
                    float2 _10531;
                    if (_5548)
                    {
                        float2 _5745 = clamp((((_9080 + (_3892 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5748 = tan(_5745.x);
                        _10531 = (float2(_5748 / cbFI_DeviceToViewDepth.z, (tan(_5745.y) * sqrt(1.0f + (_5748 * _5748))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10531 = _9080 + (_3892 * cbFI_Timestep);
                    }
                    float _3904 = cbFI_Timestep - 1.0f;
                    float2 _10532;
                    if (_5548)
                    {
                        float2 _5816 = clamp((((_9080 + (_3892 * _3904)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5819 = tan(_5816.x);
                        _10532 = (float2(_5819 / cbFI_DeviceToViewDepth.z, (tan(_5816.y) * sqrt(1.0f + (_5819 * _5819))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10532 = _9080 + (_3892 * _3904);
                    }
                    bool _5852 = all(bool2(_10531.x > 0.0f.xx.x, _10531.y > 0.0f.xx.y));
                    bool _5858;
                    if (_5852)
                    {
                        _5858 = all(bool2(_10531.x < 1.0f.xx.x, _10531.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5858 = _5852;
                    }
                    float _10535;
                    if (_5858)
                    {
                        uint _5865_dummy_parameter;
                        _10535 = max((_3897 - (log(((r_depth_tm1.Load(int3(int2(floor(_10531 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5865_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10535 = 0.0f;
                    }
                    bool _5895 = all(bool2(_10532.x > 0.0f.xx.x, _10532.y > 0.0f.xx.y));
                    bool _5901;
                    if (_5895)
                    {
                        _5901 = all(bool2(_10532.x < 1.0f.xx.x, _10532.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5901 = _5895;
                    }
                    float _10536;
                    if (_5901)
                    {
                        uint _5908_dummy_parameter;
                        _10536 = _10535 + max((_3897 - (log(((r_depth_tp1.Load(int3(int2(floor(_10532 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5908_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10536 = _10535;
                    }
                    float _10577;
                    int2 _10581;
                    float2 _10592;
                    int2 _10603;
                    float2 _10636;
                    float _10682;
                    if (_10536 == 0.0f)
                    {
                        bool _3939 = _3897 > _9090;
                        bool2 _10690 = _3939.xx;
                        _10682 = _10544;
                        _10636 = float2(_10690.x ? _3892.x : _9100.x, _10690.y ? _3892.y : _9100.y);
                        _10603 = int2(_10690.x ? _3886.x : _9094.x, _10690.y ? _3886.y : _9094.y);
                        _10592 = _9092;
                        _10581 = _9091;
                        _10577 = _3939 ? _3897 : _9090;
                    }
                    else
                    {
                        bool _3948 = _10536 < _10544;
                        bool2 _10686 = _3948.xx;
                        _10682 = _3948 ? _10536 : _10544;
                        _10636 = _9100;
                        _10603 = _9094;
                        _10592 = float2(_10686.x ? _3892.x : _9092.x, _10686.y ? _3892.y : _9092.y);
                        _10581 = int2(_10686.x ? _3886.x : _9091.x, _10686.y ? _3886.y : _9091.y);
                        _10577 = _9090;
                    }
                    _10681 = _10682;
                    _10635 = _10636;
                    _10602 = _10603;
                    _10591 = _10592;
                    _10580 = _10581;
                    _10576 = _10577;
                }
                bool _3960 = _9090 < 0.0f;
                bool2 _10696 = _3960.xx;
                int2 _10699 = int2(_10696.x ? _9091.x : _9094.x, _10696.y ? _9091.y : _9094.y);
                _10179 = float3(1.0f, _3851, float(any(bool2(_10699.x != _3779.x, _10699.y != _3779.y))));
                _9134 = _10699;
                _9123 = _3960 ? false : true;
                _9102 = float2(_10696.x ? _9092.x : _9100.x, _10696.y ? _9092.y : _9100.y);
            }
            else
            {
                _10179 = _8891;
                _9134 = _3779;
                _9123 = false;
                _9102 = _5526;
            }
            _10178 = _10179;
            _9133 = _9134;
            _9122 = _9123;
            _9101 = _9102;
        }
        else
        {
            _10178 = 0.0f.xxx;
            _9133 = _3779;
            _9122 = false;
            _9101 = _5526;
        }
        float2 _9103;
        if (_5548)
        {
            float2 _5973 = clamp((((_9080 + (_9101 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5976 = tan(_5973.x);
            _9103 = (float2(_5976 / cbFI_DeviceToViewDepth.z, (tan(_5973.y) * sqrt(1.0f + (_5976 * _5976))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9103 = _9080 + (_9101 * cbFI_Timestep);
        }
        float _3983 = cbFI_Timestep - 1.0f;
        float2 _9105;
        if (_5548)
        {
            float2 _6044 = clamp((((_9080 + (_9101 * _3983)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6047 = tan(_6044.x);
            _9105 = (float2(_6047 / cbFI_DeviceToViewDepth.z, (tan(_6044.y) * sqrt(1.0f + (_6047 * _6047))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9105 = _9080 + (_9101 * _3983);
        }
        float _3988 = -cbFI_Timestep;
        float2 _9106;
        if (_5548)
        {
            float2 _6115 = clamp((((_9080 + (_5520 * _3988)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6118 = tan(_6115.x);
            _9106 = (float2(_6118 / cbFI_DeviceToViewDepth.z, (tan(_6115.y) * sqrt(1.0f + (_6118 * _6118))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9106 = _9080 + (_5520 * _3988);
        }
        float _3993 = 1.0f - cbFI_Timestep;
        float2 _9107;
        if (_5548)
        {
            float2 _6186 = clamp((((_9080 + (_5520 * _3993)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6189 = tan(_6186.x);
            _9107 = (float2(_6189 / cbFI_DeviceToViewDepth.z, (tan(_6186.y) * sqrt(1.0f + (_6189 * _6189))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9107 = _9080 + (_5520 * _3993);
        }
        float4 _6224 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9103, 0.0f);
        float3 _6225 = _6224.xyz;
        float4 _6232 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9105, 0.0f);
        float3 _6233 = _6232.xyz;
        float4 _6240 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9106, 0.0f);
        float3 _6241 = _6240.xyz;
        float4 _6248 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9107, 0.0f);
        float3 _6249 = _6248.xyz;
        float4 _6263 = exp(_5514 - max(max(max(_5514.x, _5514.y), _5514.z), _5514.w).xxxx);
        float4 _6270 = _6263 / (dot(_6263, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4012 = _3805 && (!_9122);
        bool _4021;
        if (_4012)
        {
            _4021 = (_6270.z + _6270.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4021 = _4012;
        }
        bool _4032;
        if (_4021)
        {
            _4032 = length((_9106 - _9103) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4032 = _4021;
        }
        bool _9146;
        if (_4032)
        {
            uint4 _6289 = r_warped_motion_qdata_tp1.Load(int3(_9133, 0));
            uint _6290 = _6289.x;
            bool _9149;
            if (_6290 != 0u)
            {
                float _9135;
                if (_6290 == 0u)
                {
                    _9135 = -1.0f;
                }
                else
                {
                    _9135 = float((_6290 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4042 = _9135 - 0.12000000476837158203125f;
                bool _6309 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
                bool _6315;
                if (_6309)
                {
                    _6315 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
                }
                else
                {
                    _6315 = _6309;
                }
                bool _4052;
                if (_6315)
                {
                    uint _6322_dummy_parameter;
                    _4052 = (log(((r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6322_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4042;
                }
                else
                {
                    _4052 = _6315;
                }
                bool _4066;
                if (!_4052)
                {
                    bool _6352 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
                    bool _6358;
                    if (_6352)
                    {
                        _6358 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6358 = _6352;
                    }
                    bool _4064;
                    if (_6358)
                    {
                        uint _6365_dummy_parameter;
                        _4064 = (log(((r_depth_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6365_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4042;
                    }
                    else
                    {
                        _4064 = _6358;
                    }
                    _4066 = _4064;
                }
                else
                {
                    _4066 = _4052;
                }
                _9149 = _4066;
            }
            else
            {
                _9149 = false;
            }
            _9146 = _9149;
        }
        else
        {
            _9146 = false;
        }
        bool _4071 = _9122 || _9146;
        bool _4076;
        if (_4071)
        {
            bool _6395 = all(bool2(_9103.x > 0.0f.xx.x, _9103.y > 0.0f.xx.y));
            bool _6401;
            if (_6395)
            {
                _6401 = all(bool2(_9103.x < 1.0f.xx.x, _9103.y < 1.0f.xx.y));
            }
            else
            {
                _6401 = _6395;
            }
            _4076 = _6401;
        }
        else
        {
            _4076 = _4071;
        }
        bool _4081;
        if (_4076)
        {
            bool _6406 = all(bool2(_9105.x > 0.0f.xx.x, _9105.y > 0.0f.xx.y));
            bool _6412;
            if (_6406)
            {
                _6412 = all(bool2(_9105.x < 1.0f.xx.x, _9105.y < 1.0f.xx.y));
            }
            else
            {
                _6412 = _6406;
            }
            _4081 = _6412;
        }
        else
        {
            _4081 = _4076;
        }
        float4 _9240;
        if (_4081)
        {
            float _4084 = _6270.x;
            float _4086 = _6270.y;
            float _4087 = _4084 + _4086;
            float _4092 = _6270.z + _6270.w;
            float _9164;
            if (_4087 > 0.001000000047497451305389404296875f)
            {
                _9164 = _4084 / _4087;
            }
            else
            {
                _9164 = _3993;
            }
            _9240 = float4(_4084 + (_4092 * _9164), _4086 + (_4092 * (1.0f - _9164)), 0.0f, 0.0f);
        }
        else
        {
            _9240 = _6270;
        }
        bool _6440 = (cbFI_pad0 & 1024u) != 0u;
        bool _6416 = !_6440;
        bool _6417 = !_6416;
        bool _6434;
        if (_6417)
        {
            _6434 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9133.y * cbFI_MvDepthLaneSize.x) + _9133.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6434 = _6416;
        }
        bool _6466;
        if (_6417)
        {
            _6466 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3784.y * cbFI_FlowLaneSize.x) + _3784.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6466 = _6416;
        }
        float _4127 = float(_6466);
        bool _9252;
        float4 _9282;
        float3 _10035;
        if (_6440)
        {
            bool _4137;
            if (_6434)
            {
                _4137 = all(bool2(_9103.x > 0.0f.xx.x, _9103.y > 0.0f.xx.y));
            }
            else
            {
                _4137 = _6434;
            }
            bool _4143;
            if (_4137)
            {
                _4143 = all(bool2(_9103.x < 1.0f.xx.x, _9103.y < 1.0f.xx.y));
            }
            else
            {
                _4143 = _4137;
            }
            bool _4150;
            if (_6434)
            {
                _4150 = all(bool2(_9105.x > 0.0f.xx.x, _9105.y > 0.0f.xx.y));
            }
            else
            {
                _4150 = _6434;
            }
            bool _4156;
            if (_4150)
            {
                _4156 = all(bool2(_9105.x < 1.0f.xx.x, _9105.y < 1.0f.xx.y));
            }
            else
            {
                _4156 = _4150;
            }
            bool _4163;
            if (_6466)
            {
                _4163 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
            }
            else
            {
                _4163 = _6466;
            }
            bool _4169;
            if (_4163)
            {
                _4169 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
            }
            else
            {
                _4169 = _4163;
            }
            bool _4176;
            if (_6466)
            {
                _4176 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
            }
            else
            {
                _4176 = _6466;
            }
            bool _4182;
            if (_4176)
            {
                _4182 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
            }
            else
            {
                _4182 = _4176;
            }
            bool _4184 = !_6434;
            if (_4184)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6508;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6508);
                }
            }
            bool _4189 = !_6466;
            if (_4189)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6518;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6518);
                }
            }
            if (_6434 && _4189)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6528;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6528);
                }
            }
            if (_4184 && _6466)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6538;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6538);
                }
            }
            float _4208 = float(_4143);
            float _4210 = float(_4156);
            bool _4213 = _4169 && _4182;
            float _9198;
            if (_4213)
            {
                _9198 = 1.0f;
            }
            else
            {
                _9198 = (_4169 || _4182) ? 0.5f : 0.0f;
            }
            bool _9203;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4143)) && (!_4156))
            {
                bool _4243;
                if (_4213)
                {
                    float _9201;
                    do
                    {
                        bool _6622 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
                        bool _6628;
                        if (_6622)
                        {
                            _6628 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6628 = _6622;
                        }
                        bool _6559 = !_6628;
                        bool _6566;
                        if (!_6559)
                        {
                            bool _6633 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
                            bool _6639;
                            if (_6633)
                            {
                                _6639 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6639 = _6633;
                            }
                            _6566 = !_6639;
                        }
                        else
                        {
                            _6566 = _6559;
                        }
                        if (_6566)
                        {
                            _9201 = 0.0f;
                            break;
                        }
                        uint _6646_dummy_parameter;
                        uint _6662_dummy_parameter;
                        float4 _6587 = mul(float4((float2(_9106.x, 1.0f - _9106.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6646_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6589 = _6587.w;
                        if (abs(_6589) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9201 = 0.0f;
                            break;
                        }
                        float _6600 = abs(cbFI_DeviceToViewDepth.y / ((_6587.z / _6589) - cbFI_DeviceToViewDepth.x));
                        float _6603 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6662_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9201 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6600 - _6603) / max(max(_6600, _6603), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4243 = _9201 >= 0.5f;
                }
                else
                {
                    _4243 = _4213;
                }
                bool _9204;
                if (_4243)
                {
                    uint _6712_dummy_parameter;
                    float2 _9202;
                    do
                    {
                        float _6738 = 1.0f - _9106.y;
                        float4 _6749 = mul(float4((float2(_9106.x, _6738) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6712_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6751 = _6749.w;
                        if (!(_6751 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9202 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6764 = ((_6749.xy / _6751.xx) + 1.0f.xx) * 0.5f;
                        _9202 = float2(_6764.x - _9106.x, _6738 - _6764.y);
                        break;
                    } while(false);
                    float2 _4257 = float2(cbFI_DisplaySize);
                    _9204 = length(((_9106 + _9202) - _9107) * _4257) <= ((0.100000001490116119384765625f * length(_9202 * _4257)) + 8.0f);
                }
                else
                {
                    _9204 = _4243;
                }
                _9203 = _9204;
            }
            else
            {
                _9203 = true;
            }
            bool _4271 = !_9203;
            bool _10700 = _4271 ? false : _4182;
            bool _10701 = _4271 ? false : _4169;
            bool _9253;
            float4 _9283;
            if (!(((_4143 && _4156) && _10701) && _10700))
            {
                float4 _4293 = _9240 * float4(_4208, _4210, float(_10701), float(_10700));
                float _4295 = dot(_4293, 1.0f.xxxx);
                bool _4298 = !(_4295 > 0.0f);
                float4 _9284;
                if (!_4298)
                {
                    _9284 = _4293 / _4295.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6786;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6786);
                    }
                    _9284 = 0.0f.xxxx;
                }
                _9283 = _9284;
                _9253 = _4298;
            }
            else
            {
                _9283 = _9240;
                _9253 = false;
            }
            _10035 = float3(_4208, _4210, _9198);
            _9282 = _9283;
            _9252 = _9253;
        }
        else
        {
            _10035 = float3(float(_6434), _4127, 0.0f);
            _9282 = _9240;
            _9252 = false;
        }
        float4 _9766;
        bool _9786;
        float3 _9898;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9252))
        {
            bool _4321 = _9282.x > 0.00999999977648258209228515625f;
            bool _4324 = _9282.y > 0.00999999977648258209228515625f;
            bool _4333 = (_9282.z + _9282.w) > 0.0199999995529651641845703125f;
            bool _4339;
            if (_4333)
            {
                bool _6792 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
                bool _6798;
                if (_6792)
                {
                    _6798 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
                }
                else
                {
                    _6798 = _6792;
                }
                _4339 = _6798;
            }
            else
            {
                _4339 = _4333;
            }
            bool _4344;
            if (_4339)
            {
                bool _6803 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
                bool _6809;
                if (_6803)
                {
                    _6809 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
                }
                else
                {
                    _6809 = _6803;
                }
                _4344 = _6809;
            }
            else
            {
                _4344 = _4339;
            }
            bool _4351;
            if (_4344)
            {
                float _9286;
                do
                {
                    bool _6892 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
                    bool _6898;
                    if (_6892)
                    {
                        _6898 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6898 = _6892;
                    }
                    bool _6829 = !_6898;
                    bool _6836;
                    if (!_6829)
                    {
                        bool _6903 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
                        bool _6909;
                        if (_6903)
                        {
                            _6909 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6909 = _6903;
                        }
                        _6836 = !_6909;
                    }
                    else
                    {
                        _6836 = _6829;
                    }
                    if (_6836)
                    {
                        _9286 = 0.0f;
                        break;
                    }
                    uint _6916_dummy_parameter;
                    uint _6932_dummy_parameter;
                    float4 _6857 = mul(float4((float2(_9106.x, 1.0f - _9106.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6916_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6859 = _6857.w;
                    if (abs(_6859) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9286 = 0.0f;
                        break;
                    }
                    float _6870 = abs(cbFI_DeviceToViewDepth.y / ((_6857.z / _6859) - cbFI_DeviceToViewDepth.x));
                    float _6873 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6932_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9286 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6870 - _6873) / max(max(_6870, _6873), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4351 = _9286 < 0.5f;
            }
            else
            {
                _4351 = _4344;
            }
            float4 _9301;
            if (_4351)
            {
                uint _6982_dummy_parameter;
                uint _7013_dummy_parameter;
                float4 _9302;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6982_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7013_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9302 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9302 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9301 = _9302;
            }
            else
            {
                _9301 = 1.0f.xxxx;
            }
            bool _4375;
            if (_6434)
            {
                bool _7042 = all(bool2(_9103.x > 0.0f.xx.x, _9103.y > 0.0f.xx.y));
                bool _7048;
                if (_7042)
                {
                    _7048 = all(bool2(_9103.x < 1.0f.xx.x, _9103.y < 1.0f.xx.y));
                }
                else
                {
                    _7048 = _7042;
                }
                _4375 = _7048;
            }
            else
            {
                _4375 = _6434;
            }
            bool _4381;
            if (_6434)
            {
                bool _7053 = all(bool2(_9105.x > 0.0f.xx.x, _9105.y > 0.0f.xx.y));
                bool _7059;
                if (_7053)
                {
                    _7059 = all(bool2(_9105.x < 1.0f.xx.x, _9105.y < 1.0f.xx.y));
                }
                else
                {
                    _7059 = _7053;
                }
                _4381 = _7059;
            }
            else
            {
                _4381 = _6434;
            }
            bool _4387;
            if (_6466)
            {
                bool _7064 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
                bool _7070;
                if (_7064)
                {
                    _7070 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
                }
                else
                {
                    _7070 = _7064;
                }
                _4387 = _7070;
            }
            else
            {
                _4387 = _6466;
            }
            bool _4393;
            if (_6466)
            {
                bool _7075 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
                bool _7081;
                if (_7075)
                {
                    _7081 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
                }
                else
                {
                    _7081 = _7075;
                }
                _4393 = _7081;
            }
            else
            {
                _4393 = _6466;
            }
            bool _4396 = _4387 != _4393;
            bool _4402;
            if (_4396)
            {
                _4402 = _4375 || _4381;
            }
            else
            {
                _4402 = _4396;
            }
            float4 _9381;
            if (_4402)
            {
                float4 _8976 = _9301;
                _8976.z = 0.0f;
                _8976.w = 0.0f;
                _9381 = _8976;
            }
            else
            {
                _9381 = _9301;
            }
            bool _4409 = _4375 && _4321;
            bool _4412 = _4381 && _4324;
            float4 _9485;
            float3 _9935;
            if (_4409 || _4412)
            {
                float _9378;
                do
                {
                    uint4 _7220 = r_warped_motion_qdata_tp1.Load(int3(_9133, 0));
                    uint _7221 = _7220.x;
                    if (_7221 != 0u)
                    {
                        float _9377;
                        if (_7221 == 0u)
                        {
                            _9377 = -1.0f;
                        }
                        else
                        {
                            _9377 = float((_7221 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9378 = _9377;
                        break;
                    }
                    int _9360;
                    uint _9361;
                    _9361 = _7221;
                    _9360 = -1;
                    uint _9376;
                    for (; _9360 <= 1; _9361 = _9376, _9360++)
                    {
                        _9376 = _9361;
                        for (int _9374 = -1; _9374 <= 1; )
                        {
                            _9376 = max(_9376, r_warped_motion_qdata_tp1.Load(int3(clamp(_9133 + int2(_9374, _9360), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9374++;
                            continue;
                        }
                    }
                    if (_9361 != 0u)
                    {
                        float _9373;
                        if (_9361 == 0u)
                        {
                            _9373 = -1.0f;
                        }
                        else
                        {
                            _9373 = float((_9361 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9378 = _9373;
                        break;
                    }
                    uint _9363;
                    _9363 = 4294967295u;
                    uint _10672;
                    for (int _9362 = 0; _9362 < 8; _9363 = _10672, _9362++)
                    {
                        int _9366 = 0;
                        for (;;)
                        {
                            if (_9366 < 5)
                            {
                                int2 _7171 = _9133 + (_1093[_9362] * _1102[_9366].xx);
                                bool _7174 = any(bool2(_7171.x < int2(0, 0).x, _7171.y < int2(0, 0).y));
                                bool _7182;
                                if (!_7174)
                                {
                                    _7182 = any(bool2(_7171.x >= cbFI_MvDepthLaneSize.x, _7171.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7182 = _7174;
                                }
                                if (_7182)
                                {
                                    _10672 = _9363;
                                    break;
                                }
                                uint4 _7260 = r_warped_motion_qdata_tp1.Load(int3(_7171, 0));
                                uint _7261 = _7260.x;
                                if (_7261 != 0u)
                                {
                                    _10672 = min(_9363, _7261);
                                    break;
                                }
                                _9366++;
                                continue;
                            }
                            else
                            {
                                _10672 = _9363;
                                break;
                            }
                        }
                    }
                    float _9365;
                    if (_9363 == 4294967295u)
                    {
                        _9365 = -1.0f;
                    }
                    else
                    {
                        float _9364;
                        if (_9363 == 0u)
                        {
                            _9364 = -1.0f;
                        }
                        else
                        {
                            _9364 = float((_9363 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9365 = _9364;
                    }
                    _9378 = _9365;
                    break;
                } while(false);
                bool _4420 = _9378 < 0.0f;
                uint _7282_dummy_parameter;
                uint _7314_dummy_parameter;
                float4 _9414;
                if ((_4420 && _4409) && _4412)
                {
                    uint _7346_dummy_parameter;
                    float _7370 = log(((r_depth_tm1.Load(int3(int2(floor(_9103 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7346_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7378_dummy_parameter;
                    float _7402 = log(((r_depth_tp1.Load(int3(int2(floor(_9105 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7378_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9415;
                    if (_7370 > (_7402 + 0.07999999821186065673828125f))
                    {
                        float4 _8980 = _9381;
                        _8980.x = 0.0f;
                        _9415 = _8980;
                    }
                    else
                    {
                        float4 _9416;
                        if (_7402 > (_7370 + 0.07999999821186065673828125f))
                        {
                            float4 _8982 = _9381;
                            _8982.y = 0.0f;
                            _9416 = _8982;
                        }
                        else
                        {
                            _9416 = _9381;
                        }
                        _9415 = _9416;
                    }
                    _9414 = _9415;
                }
                else
                {
                    _9414 = _9381;
                }
                float _4462 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4464 = _9378 >= 0.0f;
                float _9397;
                if (_4464)
                {
                    _9397 = _9378 - _4462;
                }
                else
                {
                    float _9393;
                    if (_4409)
                    {
                        float _9392;
                        _9392 = 2.0f;
                        float _7460;
                        for (int _9391 = 0; _9391 < 24; _9392 = _7460, _9391++)
                        {
                            float _7424 = float(_9391 & 7) * 0.785398185253143310546875f;
                            int _7426 = _9391 >> 3;
                            int _9394;
                            if (_7426 == 0)
                            {
                                _9394 = 16;
                            }
                            else
                            {
                                _9394 = (_7426 == 1) ? 48 : 96;
                            }
                            uint _7476_dummy_parameter;
                            _7460 = min(_9392, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9103 + ((cbFI_MvDepthLaneSizeRcp * float(_9394)) * float2(cos(_7424), sin(_7424))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7476_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9393 = _9392;
                    }
                    else
                    {
                        _9393 = 0.0f;
                    }
                    _9397 = _9393;
                }
                float _9404;
                if (_4464)
                {
                    _9404 = _9378 - _4462;
                }
                else
                {
                    float _9400;
                    if (_4412)
                    {
                        float _9399;
                        _9399 = 2.0f;
                        float _7574;
                        for (int _9398 = 0; _9398 < 24; _9399 = _7574, _9398++)
                        {
                            float _7538 = float(_9398 & 7) * 0.785398185253143310546875f;
                            int _7540 = _9398 >> 3;
                            int _9401;
                            if (_7540 == 0)
                            {
                                _9401 = 16;
                            }
                            else
                            {
                                _9401 = (_7540 == 1) ? 48 : 96;
                            }
                            uint _7606_dummy_parameter;
                            _7574 = min(_9399, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9105 + ((cbFI_MvDepthLaneSizeRcp * float(_9401)) * float2(cos(_7538), sin(_7538))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7606_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9400 = _9399;
                    }
                    else
                    {
                        _9400 = 0.0f;
                    }
                    _9404 = _9400;
                }
                float _9405;
                if (_4409)
                {
                    uint _7638_dummy_parameter;
                    _9405 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9103 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7638_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9405 = 0.0f;
                }
                float _9406;
                if (_4412)
                {
                    uint _7658_dummy_parameter;
                    _9406 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9105 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7658_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9406 = 0.0f;
                }
                bool _4519;
                if (_4409)
                {
                    _4519 = _9405 > ((exp((_9397 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4519 = _4409;
                }
                float4 _9422;
                if (_4519)
                {
                    float4 _8984 = _9414;
                    _8984.x = 0.0f;
                    _9422 = _8984;
                }
                else
                {
                    _9422 = _9414;
                }
                bool _4531;
                if (_4412)
                {
                    _4531 = _9406 > ((exp((_9404 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4531 = _4412;
                }
                float4 _9424;
                if (_4531)
                {
                    float4 _8986 = _9422;
                    _8986.y = 0.0f;
                    _9424 = _8986;
                }
                else
                {
                    _9424 = _9422;
                }
                float4 _9486;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4464)
                {
                    bool _4551;
                    if (_4409)
                    {
                        _4551 = _9405 < ((exp((_9397 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4551 = _4409;
                    }
                    float4 _9426;
                    if (_4551)
                    {
                        float4 _8988 = _9424;
                        _8988.x = 0.0f;
                        _9426 = _8988;
                    }
                    else
                    {
                        _9426 = _9424;
                    }
                    bool _4563;
                    if (_4412)
                    {
                        _4563 = _9406 < ((exp((_9404 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4563 = _4412;
                    }
                    float4 _9487;
                    if (_4563)
                    {
                        float4 _8990 = _9426;
                        _8990.y = 0.0f;
                        _9487 = _8990;
                    }
                    else
                    {
                        _9487 = _9426;
                    }
                    _9486 = _9487;
                }
                else
                {
                    _9486 = _9424;
                }
                _9935 = float3(float(_4420), log(((r_depth_tm1.Load(int3(int2(floor(_9103 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7282_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9105 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7314_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _9485 = _9486;
            }
            else
            {
                _9935 = float3(0.0f, 0.0f, 0.5f);
                _9485 = _9381;
            }
            bool _4574 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4333;
            bool _4580;
            if (_4574)
            {
                _4580 = _4387 || _4393;
            }
            else
            {
                _4580 = _4574;
            }
            float4 _9507;
            if (_4580)
            {
                float _9480;
                do
                {
                    uint4 _7838 = r_warped_motion_qdata_tp1.Load(int3(_9133, 0));
                    uint _7839 = _7838.x;
                    if (_7839 != 0u)
                    {
                        float _9479;
                        if (_7839 == 0u)
                        {
                            _9479 = -1.0f;
                        }
                        else
                        {
                            _9479 = float((_7839 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9480 = _9479;
                        break;
                    }
                    int _9462;
                    uint _9463;
                    _9463 = _7839;
                    _9462 = -1;
                    uint _9478;
                    for (; _9462 <= 1; _9463 = _9478, _9462++)
                    {
                        _9478 = _9463;
                        for (int _9476 = -1; _9476 <= 1; )
                        {
                            _9478 = max(_9478, r_warped_motion_qdata_tp1.Load(int3(clamp(_9133 + int2(_9476, _9462), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9476++;
                            continue;
                        }
                    }
                    if (_9463 != 0u)
                    {
                        float _9475;
                        if (_9463 == 0u)
                        {
                            _9475 = -1.0f;
                        }
                        else
                        {
                            _9475 = float((_9463 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9480 = _9475;
                        break;
                    }
                    uint _9465;
                    _9465 = 4294967295u;
                    uint _10673;
                    for (int _9464 = 0; _9464 < 8; _9465 = _10673, _9464++)
                    {
                        int _9468 = 0;
                        for (;;)
                        {
                            if (_9468 < 5)
                            {
                                int2 _7789 = _9133 + (_1093[_9464] * _1102[_9468].xx);
                                bool _7792 = any(bool2(_7789.x < int2(0, 0).x, _7789.y < int2(0, 0).y));
                                bool _7800;
                                if (!_7792)
                                {
                                    _7800 = any(bool2(_7789.x >= cbFI_MvDepthLaneSize.x, _7789.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7800 = _7792;
                                }
                                if (_7800)
                                {
                                    _10673 = _9465;
                                    break;
                                }
                                uint4 _7878 = r_warped_motion_qdata_tp1.Load(int3(_7789, 0));
                                uint _7879 = _7878.x;
                                if (_7879 != 0u)
                                {
                                    _10673 = min(_9465, _7879);
                                    break;
                                }
                                _9468++;
                                continue;
                            }
                            else
                            {
                                _10673 = _9465;
                                break;
                            }
                        }
                    }
                    float _9467;
                    if (_9465 == 4294967295u)
                    {
                        _9467 = -1.0f;
                    }
                    else
                    {
                        float _9466;
                        if (_9465 == 0u)
                        {
                            _9466 = -1.0f;
                        }
                        else
                        {
                            _9466 = float((_9465 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9467 = _9466;
                    }
                    _9480 = _9467;
                    break;
                } while(false);
                float4 _9508;
                if (_9480 >= 0.0f)
                {
                    float _7900 = (exp((_9480 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4599;
                    if (_4387)
                    {
                        uint _7907_dummy_parameter;
                        _4599 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7907_dummy_parameter))))), 0)).x) > _7900;
                    }
                    else
                    {
                        _4599 = _4387;
                    }
                    float4 _9498;
                    if (_4599)
                    {
                        float4 _8992 = _9485;
                        _8992.z = 0.0f;
                        _9498 = _8992;
                    }
                    else
                    {
                        _9498 = _9485;
                    }
                    bool _4611;
                    if (_4393)
                    {
                        uint _7927_dummy_parameter;
                        _4611 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7927_dummy_parameter))))), 0)).x) > _7900;
                    }
                    else
                    {
                        _4611 = _4393;
                    }
                    float4 _9509;
                    if (_4611)
                    {
                        float4 _8994 = _9498;
                        _8994.w = 0.0f;
                        _9509 = _8994;
                    }
                    else
                    {
                        _9509 = _9498;
                    }
                    _9508 = _9509;
                }
                else
                {
                    _9508 = _9485;
                }
                _9507 = _9508;
            }
            else
            {
                _9507 = _9485;
            }
            bool _4619 = _4375 != _4381;
            bool _4626;
            if (_4619)
            {
                _4626 = _4375 ? _4321 : _4324;
            }
            else
            {
                _4626 = _4619;
            }
            float4 _9590;
            if (_4626)
            {
                bool2 _4631 = _4375.xx;
                float2 _4632 = float2(_4631.x ? _9103.x : _9105.x, _4631.y ? _9103.y : _9105.y);
                float _9500;
                if (_4375)
                {
                    uint _7947_dummy_parameter;
                    _9500 = r_depth_tm1.Load(int3(int2(floor(_4632 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7947_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7963_dummy_parameter;
                    _9500 = r_depth_tp1.Load(int3(int2(floor(_4632 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7963_dummy_parameter))))), 0)).x;
                }
                float4x4 _9501;
                if (_4375)
                {
                    _9501 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9501 = cbFI_MotionTP1ToTM1;
                }
                float2 _9502;
                do
                {
                    float _7990 = _4632.x;
                    float _7993 = 1.0f - _4632.y;
                    float4 _8004 = mul(float4((float2(_7990, _7993) * 2.0f) - 1.0f.xx, _9500, 1.0f), _9501);
                    float _8006 = _8004.w;
                    if (!(_8006 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9502 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8019 = ((_8004.xy / _8006.xx) + 1.0f.xx) * 0.5f;
                    _9502 = float2(_8019.x - _7990, _7993 - _8019.y);
                    break;
                } while(false);
                float2 _4662 = float2(cbFI_DisplaySize);
                float4 _9591;
                if (!(length(((_4632 + _9502) - float2(_4631.x ? _9105.x : _9103.x, _4631.y ? _9105.y : _9103.y)) * _4662) <= ((0.100000001490116119384765625f * length(_9502 * _4662)) + 8.0f)))
                {
                    float4 _9592;
                    if (_4375)
                    {
                        float4 _9004 = _9507;
                        _9004.x = 0.0f;
                        _9592 = _9004;
                    }
                    else
                    {
                        float4 _9006 = _9507;
                        _9006.y = 0.0f;
                        _9592 = _9006;
                    }
                    _9591 = _9592;
                }
                else
                {
                    _9591 = _9507;
                }
                _9590 = _9591;
            }
            else
            {
                _9590 = _9507;
            }
            float4 _4687 = _9282 * _9590;
            float _4689 = dot(_4687, 1.0f.xxxx);
            float4 _9767;
            bool _9787;
            if (_4689 > 0.0f)
            {
                _9787 = _9252;
                _9767 = _4687 / _4689.xxxx;
            }
            else
            {
                bool _4700 = any(bool4(_9590.x < 1.0f.xxxx.x, _9590.y < 1.0f.xxxx.y, _9590.z < 1.0f.xxxx.z, _9590.w < 1.0f.xxxx.w));
                if (_4700)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8041;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8041);
                    }
                }
                bool4 _10703 = _4700.xxxx;
                _9787 = _4700 ? true : _9252;
                _9767 = float4(_10703.x ? 0.0f.xxxx.x : _9282.x, _10703.y ? 0.0f.xxxx.y : _9282.y, _10703.z ? 0.0f.xxxx.z : _9282.z, _10703.w ? 0.0f.xxxx.w : _9282.w);
            }
            _9898 = _9935;
            _9786 = _9787;
            _9766 = _9767;
        }
        else
        {
            _9898 = float3(0.0f, 0.0f, 0.5f);
            _9786 = _9252;
            _9766 = _9282;
        }
        uint _4709 = (cbFI_pad0 >> 24u) & 31u;
        uint _4713 = (cbFI_pad0 >> 16u) & 255u;
        bool _4715 = _4709 != 0u;
        bool _4717 = _4713 == 12u;
        bool _4720 = _4713 == 13u;
        float4 _9783;
        if ((_4715 || _4717) || _4720)
        {
            float _9593;
            do
            {
                bool _8125 = all(bool2(_9106.x > 0.0f.xx.x, _9106.y > 0.0f.xx.y));
                bool _8131;
                if (_8125)
                {
                    _8131 = all(bool2(_9106.x < 1.0f.xx.x, _9106.y < 1.0f.xx.y));
                }
                else
                {
                    _8131 = _8125;
                }
                bool _8062 = !_8131;
                bool _8069;
                if (!_8062)
                {
                    bool _8136 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
                    bool _8142;
                    if (_8136)
                    {
                        _8142 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8142 = _8136;
                    }
                    _8069 = !_8142;
                }
                else
                {
                    _8069 = _8062;
                }
                if (_8069)
                {
                    _9593 = 0.0f;
                    break;
                }
                uint _8149_dummy_parameter;
                uint _8165_dummy_parameter;
                float4 _8090 = mul(float4((float2(_9106.x, 1.0f - _9106.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8149_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8092 = _8090.w;
                if (abs(_8092) < 9.9999999747524270787835121154785e-07f)
                {
                    _9593 = 0.0f;
                    break;
                }
                float _8103 = abs(cbFI_DeviceToViewDepth.y / ((_8090.z / _8092) - cbFI_DeviceToViewDepth.x));
                float _8106 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8165_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9593 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8103 - _8106) / max(max(_8103, _8106), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8213 = all(bool2(_9107.x > 0.0f.xx.x, _9107.y > 0.0f.xx.y));
            bool _8219;
            if (_8213)
            {
                _8219 = all(bool2(_9107.x < 1.0f.xx.x, _9107.y < 1.0f.xx.y));
            }
            else
            {
                _8219 = _8213;
            }
            float _9594;
            if (_8219)
            {
                uint _8226_dummy_parameter;
                _9594 = length((_5520 + (r_motion_tp1.Load(int3(int2(floor(_9107 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8226_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9594 = 1000000.0f;
            }
            float _9605;
            if ((_4709 & 1u) != 0u)
            {
                _9605 = _9593;
            }
            else
            {
                _9605 = 1.0f;
            }
            float _9606;
            if ((_4709 & 2u) != 0u)
            {
                _9606 = _9605 * (1.0f - smoothstep(2.0f, 8.0f, _9594));
            }
            else
            {
                _9606 = _9605;
            }
            float _9607;
            if ((_4709 & 4u) != 0u)
            {
                _9607 = _9606 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6241 - _6249) - length(_6225 - _6233))));
            }
            else
            {
                _9607 = _9606;
            }
            float _9777;
            if ((_4709 & 8u) != 0u)
            {
                _9777 = lerp(1.0f, _9607, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6225 - _6233)));
            }
            else
            {
                _9777 = _9607;
            }
            bool _4795 = (_4709 & 16u) != 0u;
            bool _4804;
            if (_4795)
            {
                _4804 = length(_9101 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4804 = _4795;
            }
            float _10705 = _4804 ? 1.0f : _9777;
            bool _4810 = _4715 && _6434;
            bool _4815;
            if (_4810)
            {
                bool _8251 = all(bool2(_9103.x > 0.0f.xx.x, _9103.y > 0.0f.xx.y));
                bool _8257;
                if (_8251)
                {
                    _8257 = all(bool2(_9103.x < 1.0f.xx.x, _9103.y < 1.0f.xx.y));
                }
                else
                {
                    _8257 = _8251;
                }
                _4815 = _8257;
            }
            else
            {
                _4815 = _4810;
            }
            bool _4820;
            if (_4815)
            {
                bool _8262 = all(bool2(_9105.x > 0.0f.xx.x, _9105.y > 0.0f.xx.y));
                bool _8268;
                if (_8262)
                {
                    _8268 = all(bool2(_9105.x < 1.0f.xx.x, _9105.y < 1.0f.xx.y));
                }
                else
                {
                    _8268 = _8262;
                }
                _4820 = _8268;
            }
            else
            {
                _4820 = _4815;
            }
            float4 _9784;
            if (_4820)
            {
                float _4826 = _9766.x + _9766.y;
                float _4835 = (_9766.z + _9766.w) * (1.0f - _10705);
                float _9780;
                if (_4826 > 9.9999997473787516355514526367188e-06f)
                {
                    _9780 = _9766.x / _4826;
                }
                else
                {
                    _9780 = _3993;
                }
                _9784 = float4(_9766.x + (_4835 * _9780), _9766.y + (_4835 * (1.0f - _9780)), _9766.zw * _10705);
            }
            else
            {
                _9784 = _9766;
            }
            _9783 = _9784;
        }
        else
        {
            _9783 = _9766;
        }
        float3 _10476;
        if (_9786)
        {
            float3 _8274 = r_current_interpolation_source.Load(int3(_3394, 0)).xyz;
            float3 _10477;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6434)
            {
                uint _8281_dummy_parameter;
                float _9889;
                _9889 = r_depth_tm1.Load(int3(int2(floor(_9103 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8281_dummy_parameter))))), 0)).x;
                float _4947;
                for (int _9888 = 0; _9888 < 24; _9889 = _4947, _9888++)
                {
                    float _4919 = float(_9888 & 7) * 0.785398185253143310546875f;
                    int _4921 = _9888 >> 3;
                    int _10527;
                    if (_4921 == 0)
                    {
                        _10527 = 16;
                    }
                    else
                    {
                        _10527 = (_4921 == 1) ? 48 : 96;
                    }
                    uint _8301_dummy_parameter;
                    _4947 = max(_9889, r_depth_tm1.Load(int3(int2(floor(clamp(_9103 + ((cbFI_MvDepthLaneSizeRcp * float(_10527)) * float2(cos(_4919), sin(_4919))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8301_dummy_parameter))))), 0)).x);
                }
                float2 _9890;
                do
                {
                    float _8323 = 1.0f - _9103.y;
                    float4 _8334 = mul(float4((float2(_9103.x, _8323) * 2.0f) - 1.0f.xx, _9889, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8336 = _8334.w;
                    if (!(_8336 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9890 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8349 = ((_8334.xy / _8336.xx) + 1.0f.xx) * 0.5f;
                    _9890 = float2(_8349.x - _9103.x, _8323 - _8349.y);
                    break;
                } while(false);
                float2 _4958 = _9103 + _9890;
                bool _8367 = all(bool2(_4958.x > 0.0f.xx.x, _4958.y > 0.0f.xx.y));
                bool _8373;
                if (_8367)
                {
                    _8373 = all(bool2(_4958.x < 1.0f.xx.x, _4958.y < 1.0f.xx.y));
                }
                else
                {
                    _8373 = _8367;
                }
                float3 _10478;
                if (_8373)
                {
                    float _4964 = abs(cbFI_DeviceToViewDepth.y / (_9889 - cbFI_DeviceToViewDepth.x));
                    uint _8393_dummy_parameter;
                    int2 _8393 = int2(spvTextureSize(r_depth_m2, uint(0), _8393_dummy_parameter));
                    float _4968 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4958 * float2(_8393))), int2(0, 0), _8393 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10483;
                    if (abs(_4968 - _4964) <= (0.20000000298023223876953125f * max(_4968, _4964)))
                    {
                        uint _8427_dummy_parameter;
                        int2 _8427 = int2(spvTextureSize(r_colour_m2, uint(0), _8427_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8450;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8450);
                        }
                        _10483 = r_colour_m2.Load(int3(clamp(int2(floor(_4958 * float2(_8427))), int2(0, 0), _8427 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8460;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8460);
                        }
                        _10483 = _8274;
                    }
                    _10478 = _10483;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8470;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8470);
                    }
                    _10478 = _8274;
                }
                _10477 = _10478;
            }
            else
            {
                _10477 = _8274;
            }
            _10476 = _10477;
        }
        else
        {
            _10476 = (((_6225 * _9783.x) + (_6233 * _9783.y)) + (_6241 * _9783.z)) + (_6249 * _9783.w);
        }
        uint _4996 = cbFI_pad0 & 255u;
        bool _10369;
        float3 _10475;
        if (_4996 != 0u)
        {
            float3 _5001 = r_present_backbuffer.Load(int3(_3394, 0)).xyz;
            float3 _5005 = r_current_interpolation_source.Load(int3(_3394, 0)).xyz;
            float3 _5009 = abs(_5001 - _5005);
            float3 _9893;
            if (_4996 == 2u)
            {
                _9893 = (abs(_5005) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9893 = 0.000244140625f.xxx;
            }
            bool _5025 = any(bool3(_5009.x > _9893.x, _5009.y > _9893.y, _5009.z > _9893.z));
            bool3 _10706 = _5025.xxx;
            _10475 = float3(_10706.x ? _5001.x : _10476.x, _10706.y ? _5001.y : _10476.y, _10706.z ? _5001.z : _10476.z);
            _10369 = _5025;
        }
        else
        {
            _10475 = _10476;
            _10369 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8485;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8485);
        }
        float3 _10458;
        if (_4713 == 1u)
        {
            _10458 = lerp(_6225, _6233, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10459;
            if (_4713 == 2u)
            {
                _10459 = lerp(_6241, _6249, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10460;
                if (_4713 == 3u)
                {
                    _10460 = float(_10369).xxx;
                }
                else
                {
                    float3 _10461;
                    if (_4713 == 4u)
                    {
                        _10461 = float3(((_9101 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10462;
                        if (_4713 == 5u)
                        {
                            _10462 = float3(((_5520 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10463;
                            if (_4713 == 6u)
                            {
                                _10463 = float3(_9783.xy, _9783.z + _9783.w);
                            }
                            else
                            {
                                float3 _10464;
                                if (_4713 == 7u)
                                {
                                    _10464 = r_current_interpolation_source.Load(int3(_3394, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10465;
                                    if (_4713 == 8u)
                                    {
                                        _10465 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3768, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10466;
                                        if (_4717)
                                        {
                                            uint _8507_dummy_parameter;
                                            uint _8539_dummy_parameter;
                                            _10466 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8507_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3768 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8539_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10467;
                                            if (_4720)
                                            {
                                                _10467 = _6241;
                                            }
                                            else
                                            {
                                                float3 _10468;
                                                if (_4713 == 20u)
                                                {
                                                    _10468 = _6225;
                                                }
                                                else
                                                {
                                                    float3 _10469;
                                                    if (_4713 == 21u)
                                                    {
                                                        _10469 = _6233;
                                                    }
                                                    else
                                                    {
                                                        float3 _10470;
                                                        if (_4713 == 22u)
                                                        {
                                                            _10470 = _6249;
                                                        }
                                                        else
                                                        {
                                                            float3 _10471;
                                                            if (_4713 == 18u)
                                                            {
                                                                _10471 = _10178;
                                                            }
                                                            else
                                                            {
                                                                float3 _10472;
                                                                if (_4713 == 19u)
                                                                {
                                                                    _10472 = _10035;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10708 = (_4713 == 23u).xxx;
                                                                    _10472 = float3(_10708.x ? _9898.x : _10475.x, _10708.y ? _9898.y : _10475.y, _10708.z ? _9898.z : _10475.z);
                                                                }
                                                                _10471 = _10472;
                                                            }
                                                            _10470 = _10471;
                                                        }
                                                        _10469 = _10470;
                                                    }
                                                    _10468 = _10469;
                                                }
                                                _10467 = _10468;
                                            }
                                            _10466 = _10467;
                                        }
                                        _10465 = _10466;
                                    }
                                    _10464 = _10465;
                                }
                                _10463 = _10464;
                            }
                            _10462 = _10463;
                        }
                        _10461 = _10462;
                    }
                    _10460 = _10461;
                }
                _10459 = _10460;
            }
            _10458 = _10459;
        }
        float3 _10457;
        if ((_4713 >= 9u) && (_4713 <= 11u))
        {
            uint _5189 = 64u + uint((_9133.y * cbFI_MvDepthLaneSize.x) + _9133.x);
            uint _5193 = rw_nfru_diagnostics.Load<uint>(_5189 * 4 + 0) & 15u;
            float3 _10488;
            if (_4713 == 10u)
            {
                float3 _10456;
                if ((rw_nfru_diagnostics.Load<uint>(_5189 * 4 + 0) & 32u) != 0u)
                {
                    _10456 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10455;
                    if ((rw_nfru_diagnostics.Load<uint>(_5189 * 4 + 0) & 16u) != 0u)
                    {
                        _10455 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5214 = ((rw_nfru_diagnostics.Load<uint>(_5189 * 4 + 0) & 64u) != 0u).xxx;
                        _10455 = float3(_5214.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5214.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5214.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10456 = _10455;
                }
                _10488 = _10456;
            }
            else
            {
                float3 _10489;
                if (_4713 == 11u)
                {
                    uint _5227 = (rw_nfru_diagnostics.Load<uint>(_5189 * 4 + 0) >> 8u) & 15u;
                    uint _5230 = (rw_nfru_diagnostics.Load<uint>(_5189 * 4 + 0) >> 12u) & 15u;
                    float3 _10448;
                    if ((_5193 == 2u) || (_5193 == 3u))
                    {
                        _10448 = _3090[_5193];
                    }
                    else
                    {
                        bool _5242 = _5227 == 3u;
                        bool _5244 = _5230 == 3u;
                        float3 _10449;
                        if (_5242 && _5244)
                        {
                            _10449 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10450;
                            if (_5242)
                            {
                                _10450 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10451;
                                if (_5244)
                                {
                                    _10451 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10452;
                                    if ((_5227 == 4u) || (_5230 == 4u))
                                    {
                                        _10452 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10453;
                                        if ((_5227 == 1u) || (_5230 == 1u))
                                        {
                                            _10453 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10710 = (_5193 == 1u).xxx;
                                            _10453 = float3(_10710.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10710.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10710.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10452 = _10453;
                                    }
                                    _10451 = _10452;
                                }
                                _10450 = _10451;
                            }
                            _10449 = _10450;
                        }
                        _10448 = _10449;
                    }
                    _10489 = _10448;
                }
                else
                {
                    _10489 = _3090[min(_5193, 7u)];
                }
                _10488 = _10489;
            }
            _10457 = _10488;
        }
        else
        {
            _10457 = _10458;
        }
        float4 _10492;
        if ((_4713 >= 14u) && (_4713 <= 16u))
        {
            float2 _10490;
            if (_4713 == 14u)
            {
                uint _5300_dummy_parameter;
                uint _5306_dummy_parameter;
                _10490 = r_flow_tm1.Load(int3(clamp(int2(floor(_3768 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5300_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5306_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10491;
                if (_4713 == 16u)
                {
                    uint _8590 = r_warped_flow_qdata_tm1.Load(int3(_3784, 0)).x & 2147483647u;
                    uint _8622 = uint(max((int((_8590 >> 16u) & 15u) - 6), 0));
                    _10491 = ((float2(float((1 - (2 * int((_8590 >> 15u) & 1u))) * int(((_8590 >> uint(7)) & 127u) << _8622)), float((1 - (2 * int((_8590 >> 14u) & 1u))) * int((_8590 & 127u) << _8622))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10491 = _5520 * float2(cbFI_DisplaySize);
                }
                _10490 = _10491;
            }
            uint2 _5339 = uint2(clamp(round(_10490 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5341 = _5339.x;
            uint _5348 = _5339.y;
            _10492 = float4(float(_5341 & 255u), float((_5341 >> 8u) | ((_5348 & 15u) << 4u)), float(_5348 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10493;
            if (_4713 == 17u)
            {
                _10493 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3784, 0)).x != 0u), _4127, 0.0f, 1.0f);
            }
            else
            {
                _10493 = float4(_10457, 1.0f);
            }
            _10492 = _10493;
        }
        rw_output[_3394] = _10492.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5392 = ((uint(_3394.y) * uint(cbFI_DisplaySize.x)) + uint(_3394.x)) * 6u;
            uint _8668 = spvPackHalf2x16(clamp(_6224.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5392 * 4 + 0, (((_8668 & 32767u) >> 4u) | ((((_8668 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6224.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8703 = spvPackHalf2x16(clamp(_6232.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5392 + 1u) * 4 + 0, (((_8703 & 32767u) >> 4u) | ((((_8703 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6232.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8738 = spvPackHalf2x16(clamp(_6240.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5392 + 2u) * 4 + 0, (((_8738 & 32767u) >> 4u) | ((((_8738 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6240.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8773 = spvPackHalf2x16(clamp(_6248.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5392 + 3u) * 4 + 0, (((_8773 & 32767u) >> 4u) | ((((_8773 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6248.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8800 = r_current_interpolation_source.Load(int3(_3394, 0));
            uint _8814 = spvPackHalf2x16(clamp(_8800.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5392 + 4u) * 4 + 0, (((_8814 & 32767u) >> 4u) | ((((_8814 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8800.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10526;
            if (_10369 || (_4713 != 0u))
            {
                _10526 = 4294967295u;
            }
            else
            {
                uint _8849 = spvPackHalf2x16(clamp(_10492.xy, 0.0f.xx, 65000.0f.xx));
                _10526 = (((_8849 & 32767u) >> 4u) | ((((_8849 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10492.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5392 + 5u) * 4 + 0, _10526);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3394] = float4(r_current_interpolation_source.Load(int3(_3394, 0)).xyz, 1.0f).xyz;
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
